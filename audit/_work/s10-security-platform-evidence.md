# Security, privacy, reliability & platform feasibility findings (subagent 10/10)

Audit-only. No repo file was modified; Supabase CLI was not run.

## 1. Scope actually covered

Read: `audit/_work/AUDIT_BRIEF.md`; `docs/runtime-failure-analysis.md` (all);
`docs/runtime-mic-test-report.md` §4–§6; all 10 files in `supabase/migrations/`
(core schema, functions, RLS, grants, lifetime/concurrency/signaling);
`supabase/functions/{remote-session,family-admin,device-command,device-policy,device-telemetry,device-register,auth-bootstrap,cron}/index.ts`
and `_shared/auth.ts`; `supabase/tests/` inventory;
`android/app/src/main/AndroidManifest.xml`, `PolicyApplier.kt`, `GuardianService.kt`
(error paths); `lib/core/config/env.dart`, `lib/data/services/{supabase_service,edge_api}.dart`,
`supabase_auth_repository.dart`, `supabase_remote_session_repository.dart`,
`remote_session_controller.dart`, `child_restrictions_page.dart`; test/deno/kotlin
suite inventory.

Skipped: hosted project state (dashboard only), full Kotlin/Dart body reads,
`lib/features` beyond the files listed (peer summaries used where cited).

## 2. Findings

### 2.1 Authentication boundaries and role enforcement

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| SC-01 | **Critical** | The hosted `remote-session` Edge Function is the OLD build while the schema is migrated. Consented rows have `expires_at = NULL`; the old build evaluates `new Date(null) <= now()` and expires the session on the next `start`/`ice`/`media` call. Reproduced end-to-end (F1). Every session therefore dies ~at the first server call after consent, mid-call, and the parent UI still says "Until you end the session". | `docs/runtime-failure-analysis.md:35-49`; old deployed bundle tracked in repo `.tools/deploy/remote-session.ts:1` (contains `Q=30*60*1e3` and `new Date(a.expires_at).getTime()<=Date.now()`); new schema `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql:35-48`; fixed HEAD `supabase/functions/remote-session/index.ts:84-95,284-296,348-372` |
| SC-02 | **High** | Server-side session lifetime now has no upper bound and no watchdog: `expire_stale_sessions()` only touches `status='requested'`, pg_cron is optional/guarded and absent on the host, and `request_remote_session()` refuses to clean up a consented row. An abandoned accepted/active row (parent app crash, network loss, child process kill — F5 leaves the row `active`) blocks every new request for that device indefinitely and can leave the child's mic FGS eligible to run. | `20261028000200_...sql:80-99,137-153`; `20260101000100_functions.sql:947-967` (cron only `if pg_cron exists`); `docs/runtime-failure-analysis.md:100-108` (F5: session stayed `active`) |
| SC-03 | **High** | "Request video" is offered and the consent sheet promises the camera opens, but the only foreground service is typed `microphone`; there is no `FOREGROUND_SERVICE_CAMERA` permission or `camera` FGS type. On Android 11+ (targetSdk from Flutter default, `android/app/build.gradle.kts:22-23`) camera capture is blocked once the app is not in the foreground, so video works only while the child keeps the session screen visible. Video has no runtime evidence (mic report covers audio only). | `android/app/src/main/AndroidManifest.xml:12-15,88-92`; `lib/features/remote_assistance/remote_assistance_page.dart:21-26,130`; video constraints `lib/features/remote_assistance/remote_session_controller.dart:1121-1133`; `docs/runtime-mic-test-report.md:216-235` |
| SC-04 | **High** | `purge_data` is destructive (deletes `location_events` and `usage_daily` for the whole family) but is authorized with `assertFamilyParent`, not owner. Any second parent can irreversibly delete history up to the retention floor; only `update_retention` requires the owner. | `supabase/functions/family-admin/index.ts:157-167,187-199,229-235`; `_shared/auth.ts:194-205,224-250` |
| SC-05 | Medium | No account-deletion or data-export path exists: the only auth teardown is `signOut()`, and no function calls `auth.admin.deleteUser` or deletes a family. Deletion is only implicit via the `profiles -> auth.users` cascade, which no client can trigger. Play/GDPR requires an in-app deletion route. | `lib/data/repositories/supabase_auth_repository.dart:82-88`; `lib/data/services/supabase_service.dart:58-61`; schema cascade `supabase/migrations/20260101000000_core.sql:17-18`; no match for `deleteUser` in `supabase/` or `lib/` |
| SC-06 | Medium | Retention is policy text, not enforcement. `purge_data` is manual and only deletes `location_events`/`usage_daily`; `safety_alerts`, `audit_logs`, `remote_sessions`, `webrtc_signals` are never purged. With no cron, raw coordinates and audit rows accumulate indefinitely on the hosted project. | `family-admin/index.ts:36-41,187-199`; default window `core.sql:37-39`; retention columns only on location/usage |
| SC-07 | Medium | Audit trail has gaps on every automatic transition: `expire_stale_sessions()` and the hosted expiry path write no `audit_logs` row, and `detect_offline_devices()` writes none. F1's session has only requested/accepted/started. A parent cannot prove when/why a session ended. | `20261028000200_...sql:89-97` (no `record_audit`); `docs/runtime-failure-analysis.md:45` ("No end/expire audit row"); audit table `core.sql:375-386`; `20260101000100_functions.sql:531-573` |
| SC-08 | Medium | Server RPCs are SECURITY DEFINER but take the acting parent as a parameter and perform no authorization of their own: `request_remote_session(p_parent_user_id)` inserts whatever id is passed (no check that it is a parent of `device.family_id`), same pattern for `revoke_device`/`unlink_child`/`apply_policy_version`. Grants are service_role-only, so this is defence-in-depth debt: one server-side bug or leaked service key yields direct impersonation. | `20261028000200_...sql:106-181` (esp. 124-135, 155-177); `20260101000100_functions.sql:863-872,895-904`; correct caller checks exist only in Edge code `_shared/auth.ts:252-275` |
| SC-09 | Medium | Permission revocation is visible on the child UI but never raises an alert: `safety_alerts.type` allows `permission_missing` but no producer exists. The parent keeps seeing a healthy device after location/mic/usage access is withdrawn. Alerts are produced only for low battery and geofence transitions (and offline in SQL). | `core.sql:301-303`; `supabase/functions/device-telemetry/index.ts:129-141,289-325`; `20260101000100_functions.sql:531-573` |
| SC-10 | Medium | Session tokens are persisted by `supabase_flutter` defaults (SharedPreferences, not encrypted); `flutter_secure_storage` is a declared dependency but unused anywhere in `lib/`. `allowBackup=false` limits extraction, but a rooted device or debug backup exposes refresh tokens. No explicit `authOptions`/`autoRefreshToken` configuration exists, so refresh behaviour is the library default. | `pubspec.yaml:38-40`; `lib/data/services/supabase_service.dart:28-31` (no `authOptions`); manifest `android/app/src/main/AndroidManifest.xml:43`; zero matches for `FlutterSecureStorage` in `lib/` |
| SC-11 | Low | `webrtc_signals` rows (SDP + ICE, up to 16 KB each, containing local/public IPs) are readable by **any** family parent, not only the two participants: `remote_sessions` SELECT is family-parent-wide and the realtime topic predicate is `is_family_parent`, relying on table RLS for row filtering. A co-parent can join `webrtc-signals:<session>`; row RLS still limits them to sessions of their own family, i.e. other parents' calls in the same family. | `20260101000200_rls.sql:185-193,202-231,321-328`; `20261028000300_signaling_open_session.sql:25-53`; payload bound `core.sql:363-364`; channel name `lib/data/repositories/supabase_remote_session_repository.dart:230-233` |
| SC-12 | Low | Secrets hygiene is mostly correct but two artefacts are tracked: `.tools/live_config.env` (SUPABASE_URL + SUPABASE_ANON_KEY only — publishable by design, but pinned to a public GitHub remote) and `.tools/deploy/remote-session.ts` (the stale production bundle). No service-role key, `TURN_SECRET` or JWT literal was found in tracked files. | `git remote -v` = `github.com/Shivadatt/parental_control.git`; `git ls-files` includes `.tools/live_config.env`; key names only at `.tools/live_config.env`; `.env.example:14` placeholder; `lib/core/config/env.dart:50-55` rejects `service_role` keys at build time |
| SC-13 | Informational | The auth surface is otherwise sound: JWT verified server-side for every user action, verified email required, role checked against `profiles.role`, device identity is `x-device-id` + `x-device-secret` compared with a constant-time SHA-256, revoked devices rejected, and `secret_hash`/`installation_id` are excluded from client column grants. Parent-only actions (`request`, `revoke_device`, `apply_policy`) correctly re-check family parent membership. | `_shared/auth.ts:80-139,252-275,281-330`; `20260101000200_rls.sql:257-266`; `device-register/index.ts:118-123`; `auth-bootstrap/index.ts:37-51` |
| SC-14 | Informational | F4 stands: no TURN relay is configured, so sessions rely on host/srflx candidates and fail on CGNAT/strict firewalls. Not a security defect, but a reliability limit for every remote-media feature. | `docs/runtime-failure-analysis.md:88-96` |

Notes on specific questions:
- **Can a child call parent-only functions?** Through Edge Functions, no: `requireRole(auth.profile,"parent")` is on `request`, `revoke_device`, `recover_device`, `ack_alert`, `purge_data`, policy writes (`family-admin/index.ts:56-57,83,115,159,231`; `device-command/index.ts:112`; `device-policy/index.ts:51`). Directly against PostgREST, no: all mutating RPCs are revoked from `authenticated` and granted only to `service_role`, and profiles only grant `update(display_name)` (`20260101000100_functions.sql:874-904`; `20260101000200_rls.sql:247-284`). This boundary holds **as configured in repo**; the hosted copy is BLOCKED — PENDING DASHBOARD AGENT.
- **Consent indicators:** `consent_recorded` is set only by the child's accept (`remote-session/index.ts:225-232`), and `ice`/`start` refuse without it (`:276-282,360-366`); the child FGS notification is the runtime consent indicator (`AndroidManifest.xml:88-92`). The UI copy for video overstates what happens (SC-03).
- **Unlinking:** server `unlink_child` ends the session with `member_unlinked` and revokes the device (`20260101000100_functions.sql:325-431`); client path `child_shell_controller.dart:1012-1036`. No runtime evidence of unlink-in-session found in stage8.
- **Duplicate/stale sessions:** duplicate requests are correctly serialized by a per-device advisory lock (`20261028000100_...sql:34-60`); stale *consented* rows are the gap (SC-02).
- **Signaling replay:** no nonce check on `webrtc_signals` inserts; `session_nonce` is stored but not validated on signal insert (`core.sql:343,358-367`; policies at `20261028000300_...sql:39-53`). Impact is low because inserts require participant identity and a live session, but a replayed offer from a compromised participant session cannot be distinguished.

### 2.2 Platform feasibility matrix (AirDroid categories)

| # | Category | Classification | Justification (cited) | Status |
|---|---|---|---|---|
| P1 | Family/device management | feasible now | Family, membership, pairing code + Child-ID invite, revoke/recover all exist server- and client-side (`20260101000000_core.sql:33-74,128-171`; `_shared/auth.ts:224-275`; `pairing/index.ts:563-624`). Runtime pairing evidence only in older stages. | IMPLEMENTED — PARTIALLY VERIFIED |
| P2 | Today's event (timeline) | native work required | Only `usage_daily` aggregates exist (day × package × total_ms); no event stream, unlock count or "first pickup" (`core.sql:228-243`). Needs `UsageEvents` polling. | MISSING |
| P3 | Remote camera (video assistance) | feasible now / native work required | flutter_webrtc video constraints exist (`remote_session_controller.dart:1128-1133`) but no camera FGS type, so background video is blocked (SC-03). | CODE EXISTS — NOT TESTED |
| P4 | Screen mirroring | MediaProjection + `FOREGROUND_SERVICE_MEDIA_PROJECTION` | No `MediaProjection`, `createScreenCaptureIntent` or mediaProjection FGS anywhere; manifest has no such permission (`AndroidManifest.xml:4-29`). | MISSING |
| P5 | One-way audio | feasible now (already built) | Child mic → parent speaker, parent receive-only, consent-gated (`remote_session_controller.dart:57-62,1119-1127`); runtime proven up to 8m14s then killed by F1 (`docs/runtime-failure-analysis.md:35-49`). | IMPLEMENTED — PARTIALLY VERIFIED |
| P6 | Instant block | Device Owner only | Enforcement is `setPackagesSuspended`; with plain device-admin the code only reports "no longer Device Owner" and cannot restore (`PolicyApplier.kt:105-118,234-250`). No uninstall-block or launcher lock. | PARTIALLY IMPLEMENTED |
| P7 | Downtime / bedtime | native work required (DO scheduled suspension) | Bedtime is stored and returned as `bedtime_active` but explicitly "Informational only ... suspension follows app rules"; child UI says it is not enforced (`PolicyApplier.kt:297-298`; `lib/features/child/child_restrictions_page.dart:296`; `policy_summary_card.dart:126`). | MISSING |
| P8 | App management (install/uninstall limits) | Device Owner | Only list (`device_apps`) + suspend/unsuspend; no `setUninstallBlocked`, `setApplicationHidden` or installer policy (`core.sql:395-407`; `PolicyApplier.kt:225-250`). `QUERY_ALL_PACKAGES` is Play-restricted (`AndroidManifest.xml:24-29`). | PARTIALLY IMPLEMENTED |
| P9 | Notifications (read) | Notification Listener (`BIND_NOTIFICATION_LISTENER_SERVICE`) | No listener service, no notification table or telemetry action; only `notifications_granted` boolean is stored (`core.sql:108`; `device-telemetry/index.ts:102`). | MISSING |
| P10 | Social content detection | Accessibility + Notification Listener + external service | No accessibility service, no text capture or classifier anywhere (`grep AccessibilityService` in `android/` = none). Not reliably possible without those and a remote model. | MISSING |
| P11 | Inappropriate image detection | MediaProjection / Accessibility + external service | Requires screen capture of third-party apps (P4 absent) or on-device ML; no ML dependency in `pubspec.yaml`. Not reliably possible with current stack. | MISSING |
| P12 | Calls & SMS | default-app role (dialer/SMS) or `READ_CALL_LOG`/`READ_SMS` | No call/SMS permissions, no `CallLog`/`Telephony` code, no default-role request (`AndroidManifest.xml:4-29`). Play severely restricts these permissions. | MISSING |
| P13 | Website restrictions | VpnService (or DNS proxy) | No `VpnService`, no filter/URL model, no `website`/`browsing` symbol in `lib/`, `supabase/`, `android/` (grep empty). | MISSING |
| P14 | Web time limits | VpnService / Accessibility | Same as P13; screen-time UI only covers app usage (`lib/features/screen_time/screen_time_controller.dart:40`). | MISSING |
| P15 | Browsing history | VpnService logs / Accessibility / external service | No browser history provider query (`READ_HISTORY_BOOKMARKS` absent) and no proxy; impossible without one of those. | MISSING |
| P16 | Location | feasible now | `LocationTrackingService` FGS + `location_events` + parent map page exist (`AndroidManifest.xml:83-86`; `core.sql:251-262`; `lib/features/location/location_page.dart`); no stage-8 runtime evidence for a location fix. | CODE EXISTS — NOT TESTED |
| P17 | Route / history trail | feasible now (derive from stored fixes) | `location_events` keeps full history, but no route aggregation, polyline or playback screen exists (no route files under `lib/features`). | MISSING |
| P18 | Geofence | feasible now (server-side evaluation) | `safe_zones` + `safe_zone_states` + enter/exit comparison inside telemetry (`device-telemetry/index.ts:289-325`; `core.sql:272-292`); controller tests only, no runtime evidence. | IMPLEMENTED — PARTIALLY VERIFIED |
| P19 | Alerts | feasible now; production outages limit delivery | `safety_alerts` + realtime channel + ack exist; producers are only low battery, geofence, offline-in-SQL; `permission_missing`/`app_blocked` never emitted (`device-telemetry/index.ts:129-141,349`; `20260101000100_functions.sql:531-573`). Delivery depends on F2 scheduler stalls. | PARTIALLY IMPLEMENTED |

Cross-cutting platform constraints: OEM background policy already bit this build (F2 single-scheduler stall, ColorOS task removal in F5: `docs/runtime-failure-analysis.md:60-74,100-108`), so P16/P19 inherit "limited by OEM background policy"; `allowBackup=false` (`AndroidManifest.xml:43`) is correct for a monitoring app.

### 2.3 Test evidence ledger

Inventory (counted, not run):

| Suite | Files | Coverage |
|---|---|---|
| `test/` (Flutter unit/widget) | 38 `*_test.dart` | controllers + models across auth, child shell, devices, family, pairing, remote assistance, safe zones, alerts, screen time, app restrictions, settings, audit logs; plus `widget_test.dart` |
| `integration_test/` | 4 `*_test.dart` | child media self-test, child sign-in, device capabilities, parent UI journey |
| `supabase/functions/**/*_test.ts` (Deno) | 5 | `remote-session/guard_test.ts`, `_shared/{enrollment,policy,turn,validation}_test.ts` |
| `supabase/tests/` (SQL) | 12 `.sql` + 2 `run_*.sh` | schema, fixtures, RLS, functions, device recovery, realtime policy, pairing-invite race, session concurrency, parent-controlled lifetime, consented signaling |
| Kotlin (`android/app/src/test`) | 4 | `AudioAssistanceRecreationTest`, `AudioAssistanceSessionWatchdogTest`, `AudioAssistanceStartGateTest`, `PolicyEvaluatorTest` |
| Dart LOC under test+integration | 10,670 total | — |

Historical results (2026-10-29, **not re-run in this audit**), from `docs/runtime-mic-test-report.md:237-246`:

- Flutter `flutter test`: **275 passed, 0 failed**, exit 0 (`:241`).
- `flutter analyze`: **No issues found** (`:242`).
- Deno: **47 passed, 0 failed** (`:243`).
- Kotlin `testDebugUnitTest`: **BLOCKED (environment)** — cross-drive Gradle roots, no test executed, suite **not** counted as passing (`:244`; also `docs/runtime-failure-analysis.md:124-142`).
- SQL suites: no historical pass/fail row in §6; `.tools/sql-*.log` exist but were not re-opened here, so SQL test status is **unverified** (assumption if claimed green).

Features with **neither runtime evidence nor tests**:

- Video assistance / remote camera (no stage-8 video run; test coverage only through generic controller tests).
- Screen mirroring, notifications read, social/text detection, image detection, calls/SMS, website restrictions, web time limits, browsing history — no code, so no tests either (P4, P9–P15).
- Route/history trail and location map rendering (P16–P17).
- Real Device Owner provisioning end-to-end (setPackagesSuspended path) — Kotlin `PolicyEvaluatorTest` covers decision logic only and cannot run here; F2 shows enforcement commands stalling at runtime.
- Account deletion/data export (absent), retention/purge job scheduling (absent), and `permission_missing` alerting (absent).
- Hosted Edge Function parity with repo HEAD — **BLOCKED — PENDING DASHBOARD AGENT** (F1 is direct evidence of drift).

### 2.4 Evidence gaps / BLOCKED

- **BLOCKED — PENDING DASHBOARD AGENT**: deployed `remote-session`/`cron` versions, pg_cron job state, project auth settings (leaked-password protection, JWT expiry, redirect allowlist), and whether `.tools/live_config.env`'s anon key is still live.
- Kotlin suite unverifiable on this workstation (E1).
- SQL pgTAP-style suites not executed; their green status is unverified.
- Human audibility of the audio session was never verified (`docs/runtime-mic-test-report.md:216-221`); media evidence is packet/track counters.
- No runtime evidence for location, geofence, app suspension, unlink, or video in `docs/evidence/stage8/` (stage8 is remote-session and permission-revocation focused).

## 3. Summary a reviewer can trust

The repository's security design is materially better than its runtime: RLS is on for all 19 tables, client grants are column-scoped so `secret_hash` never leaves the server, all mutating RPCs are service-role-only, device auth is constant-time, and parent-only actions re-check family membership. The failures are in deployment drift and lifetime semantics (SC-01/SC-02), in claims the Android build cannot honour (SC-03 video, P7 downtime, P8 app policy), and in privacy lifecycle gaps (no account deletion, no enforced retention, no automatic audit rows — SC-05/06/07). Feasibility-wise, roughly half of the AirDroid surface (notifications, web filtering/history, calls/SMS, content and image detection, screen mirroring) is entirely absent and each needs a named special capability plus OEM-defeating work; the present build is an audio-assistance + location + usage + app-suspension product, not a general parental-control suite.

output: `D:\parentcontrol_app\audit\_work\s10-security-platform-evidence.md`
counts by severity: Critical=1, High=3, Medium=6, Low=2, Informational=2 (14 findings, SC-01…SC-14)

The 5 most serious findings:

1. **SC-01 (Critical)** — hosted `remote-session` is the stale 30-min build against a nullable-`expires_at` schema; consented calls are expired mid-session and the UI denies it. Reproduced (F1). Fix written, deployment blocked.
2. **SC-02 (High)** — no server-side bound or watchdog for accepted/active sessions and no cron; an orphaned session blocks the device forever and can leave the child mic service eligible.
3. **SC-03 (High)** — "Request video" promises the camera, but there is no camera FGS type/permission; background video is blocked by Android while-in-use rules and has zero runtime evidence.
4. **SC-04 (High)** — any non-owner family parent can irreversibly purge family location/usage history.
5. **SC-05/SC-06 (Medium)** — no account deletion or export, and retention is manual, cron-less and covers only two tables, so raw location and audit history are kept indefinitely.