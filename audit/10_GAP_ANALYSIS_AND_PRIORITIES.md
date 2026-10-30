# 10 — Gap analysis and priorities

Derived from the 242-row inventory (`01_COMPLETE_FEATURE_INVENTORY.md`): **17 rows carry P0**, 79 P1, 107 P2, 37 P3, 2 unprioritized. The 17 P0 rows collapse into four root causes below, which is why this document lists four P0 items rather than 17. Reasons and evidence are given for each.

## P0 — Critical (security, truthfulness, core lifecycle)

### P0-1 · Hosted `remote-session` still enforces a 30-minute deadline
- **Why:** a live audio session is silently killed 30 minutes after consent, while the parent UI says "Until you end the session". This is a broken core session lifecycle.
- **Evidence:** deployed bundle writes `expires_at = accepted + 30 min` and throws 410 `session_expired` on `active`/`ice` (`audit/_work/s5-hosted-supabase.md` §2.10); session `1bd26a84` flipped to `expired` at 12:16:38.393Z, media torn down 144 ms later (`docs/evidence/stage8/f1-expiry-12-16Z.txt`); all 35 `ended` hosted sessions carry a 30-minute deadline.
- **Fix state:** fixed at HEAD (`supabase/functions/remote-session/index.ts:229` sets `expires_at: null`; parent-only end). **Not deployed** — requires owner approval. No code change was made in this audit.
- **Covers inventory rows:** FB-046 (BROKEN), plus the J2/15-minute endurance failure.

### P0-2 · "Enforced" can be reported while zero apps are suspended
- **Why:** the parent can be shown a green enforcement state on a phone where nothing is blocked — an incorrect enforcement claim for a critical restriction.
- **Evidence:** `PolicyApplier.apply()` clears the target set when not Device Owner and only appends an error (`PolicyApplier.kt:94-101`); success is `errors.isEmpty()` (`:137`); `device-command` marks `enforcement_status = enforced` on any successful ack (`supabase/functions/device-command/index.ts:318-351`). Runtime: a v2 policy was acked `failed` with the Device Owner error (`docs/verification-report.md:575`), yet the ack path above allows the inverse.
- **Needed:** ack must carry "suspended N of M" and the server must only set `enforced` when the applied set matches the policy (or when the device is DO).
- **Covers inventory rows:** FC-001, FC-004, FC-005, FC-011, FC-029, FC-036.

### P0-3 · Blocking, downtime and limits require Device Owner, and there is no in-app provisioning path
- **Why:** the product's core restrictions are inert on every normal install, and the UI still offers them.
- **Evidence:** only `DevicePolicyManager.setPackagesSuspended`, DO-gated (`PolicyApplier.kt:236-244`); `device_admin.xml` requests no policies; `dpm list-owners` = none on the test device (`docs/read_only_audit_2026-10-27.md:505`); bedtime "informational only" (`PolicyApplier.kt:296-299`); daily limit parsed but never read (`PolicyJson.kt:16`); child UI admits limits are not enforced (`child_restrictions_page.dart:295-301`).
- **Options:** (a) ship a Device-Owner provisioning flow (factory reset or adb) and make it a hard prerequisite; (b) add an Accessibility/overlay enforcement path (Play-policy sensitive); (c) descope blocking/downtime from Android for normal installs and say so in the UI.
- **Covers inventory rows:** FC-005, FC-007, FC-011, FC-012, FC-014, FC-029, FC-036, FD-052.

### P0-4 · Authorization asymmetry on destructive operations
- **Why:** data the schema intends to protect can be deleted or changed by a broader set of actors than intended.
- **Evidence:** `family-admin purge_data` accepts any family parent and irreversibly deletes `location_events`/`usage_daily`, while retention change is owner-only (`supabase/functions/family-admin/index.ts:157-227`); `safe_zones` has a client DELETE policy (`20260101000200_rls.sql:162-166`) despite the file's own "no client DELETE" rule (`:2`); service-only RPCs trust caller-supplied parent/actor ids without re-verifying membership (`s4` §2); immutability triggers treat any SECURITY DEFINER write as privileged (`core.sql:502-505,525-529,549-553`).
- **Needed:** owner-only purge, drop the client DELETE, re-check membership inside the four RPCs, and key immutability on session role rather than `current_user`.

## P1 — Core functionality and reliability

| # | Gap | Evidence | Consequence |
|---|---|---|---|
| P1-1 | No TURN relay; ICE `relay 0` | `docs/runtime-mic-test-report.md` §1; parent banner | Audio fails on carrier-grade NAT; recovery across networks unproven |
| P1-2 | Guardian single-scheduler stall (F2) | `docs/runtime-failure-analysis.md` F2 | Presence, commands and heartbeat freeze together while the FGS still reports running; only a restart recovers |
| P1-3 | No push transport (no FCM/local delivery) | `pubspec.yaml`; `settings_body.dart:108-144` | Alerts/commands depend on app open or a polling FGS being alive |
| P1-4 | No durable scheduler (no WorkManager/AlarmManager; boot refused on API ≥ 35) | `BootReceiver.kt:31-37`; `s3` §2.8 | Nothing recovers after force stop/reboot until the user opens the app |
| P1-5 | Policy delivery can lose a saved policy when the child is offline | 900 s command TTL; `sync_policy` replays stale local JSON; `device-policy` has no device-side fetch (`s8`) | A limit/block may never reach the child |
| P1-6 | Location uploads discard all but the newest offline fix | `GuardianService.kt:458-467` | Permanent holes in route/location history |
| P1-7 | Remote camera path never executed on hardware; front camera only; no rear/torch/background camera | `s7`; `remote_session_controller.dart:1127-1133` | "Request video" is unverified and limited |
| P1-8 | No scheduled maintenance: no pg_cron, no visible external caller | `s5` §2.7 | `expire_stale_sessions`/`detect_offline_devices` never run; offline alerts unreachable |
| P1-9 | Session expiry is not audited; deployed `end` is participant-only | `audit_logs` has no `session_expired`; `s5` §2.10 | Clock expiry leaves no trail; a child can end a session server-side |
| P1-10 | `webrtc_signals` lacks unique `(session_id, sequence)`; `session_nonce` never verified | `s4` | Duplicate/replayed signaling is only prevented client-side |

## P2 — AirDroid parity

| # | Missing capability | Rows | Why it matters |
|---|---|---|---|
| P2-1 | Website restrictions (blacklist/whitelist/modes/browser/VPN enforcement) | 14 | Entire category absent; needs VpnService |
| P2-2 | Browsing history | 10 | Depends on browser integration that does not exist |
| P2-3 | Notifications monitoring | 10 | Needs NotificationListenerService |
| P2-4 | Social content detection | 13 | No content source; Accessibility/screen capture required; privacy-risky |
| P2-5 | Inappropriate image detection | 10 | Needs gallery observer + on-device ML |
| P2-6 | Calls & SMS | 9 | Default-role / restricted permissions only |
| P2-7 | Screen mirroring | 12 | MediaProjection + consent + FGS type |
| P2-8 | Today's Event feed, trends, weekly reports | 6 | Data exists (`usage_daily`) but no feed/analytics UI |
| P2-9 | Route history and map visualization | 4 + 4 | No map SDK, no trip reconstruction |
| P2-10 | Geofence UX (map picker, dwell/accuracy buffer, push) | 2 + partial | Manual coordinates and boundary flapping |
| P2-11 | Bedtime/limit enforcement parity | 7 | Covered by P0-3 technically; parity gap remains |
| P2-12 | Account deletion, profile edit, data export, language | several | Required for a consumer release |

## P3 — Product polish

- 37 P3 rows: navigation duplicates and dead routes (`/parent/settings`, child Requests duplication), vocabulary drift (pair/link, Child ID/code, phone/device), three Alerts entry points, settings tab without a header.
- Misleading copy: "Live updates interrupted — End the session and retry" during healthy media (F6); "Showing the last data loaded" with no cache.
- Accessibility: zero `Semantics`, no l10n, no dark theme, fixed widths, no tablet layout.
- Status vocabulary inconsistency ("STALE" vs "Stale"); duplicated card/empty-state implementations.

## Recommended implementation order

1. **Deploy the `remote-session` fix** (P0-1) — one deploy, removes the only reproduced session-killing defect. Requires owner approval.
2. **Enforcement truthfulness** (P0-2/P0-3): make acks prove the applied set; decide Device Owner vs Accessibility vs descope; remove enforcement claims where nothing is enforced.
3. **Destructive-authorization fixes** (P0-4): owner-only purge, drop `safe_zones` client DELETE, membership re-checks.
4. **Reliability**: TURN, push (or explicit "no push" limitation), watchdog for the guardian tick (P1-2), durable scheduling, offline queues (P1-5/P1-6).
5. **Parity wave 1**: website restrictions (VPN), notifications listener, Today's Event feed, map/route.
6. **Parity wave 2**: screen mirroring, camera completion, image detection, calls/SMS (subject to Play policy).
7. **Polish**: navigation cleanup, copy, l10n, accessibility.

Each step requires its own authorization; none was implemented in this audit.