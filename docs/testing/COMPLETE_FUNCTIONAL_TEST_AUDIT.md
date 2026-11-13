# Complete Functional Test Audit — Parent Control Application

- **Project:** `D:\parentcontrol_app` (pubspec `parent_control`, package `com.parentcontrol.parent_control`)
- **Audit type:** Read-only functional audit (AUDIT ONLY — no fixes applied)
- **Date:** 2026-11-13
- **Method:** 4 parallel subagents (architecture/inventory, automated tests+build, parent runtime, child+backend+integration)
- **Prepared by:** orchestrator, grounded in subagent evidence (no fabricated results)

---

## 1. Executive Summary

The application is a **single dual-role Flutter codebase** (parent + child roles branch at runtime) with a **substantial, genuine native Android enforcement layer** (~4,100 LOC Kotlin) and a **Supabase backend** (18 tables, 22 RLS policies, 10 Edge Functions). It is **not** a UI demo: real backend auth, real telemetry, real WebRTC signaling, and real `DevicePolicyManager` enforcement code all exist.

Evidence-backed results:
- **Automated suites are green:** `flutter analyze` 0 issues; `flutter test` **482/482 pass**; Kotlin JVM unit tests pass; Deno backend tests **181/181 pass**; debug APK builds (232.6 MiB).
- **Parent runtime largely works** on `emulator-5554` with a **live authenticated Supabase session** (family "demo", parent `ankit@gmail.com`, role Owner, email verified). Dashboard, device detail, alerts, settings, navigation, and refresh all render real backend data (last-seen advanced live, battery 100% charging from a real enrolled device).
- **Backend/RLS is sound** (static audit): all 18 tables RLS-enabled, multi-tenant family isolation via pinned-`search_path` SECURITY DEFINER helpers, column grants hide `secret_hash`/`installation_id`, device auth is constant-time/enumeration-resistant, WebRTC is consent-gated, no secrets in client.

However, the audit found **real gaps and defects**:
- **Push notifications (FCM) are NOT implemented** (no `google-services.json`, no `firebase_messaging`); the parent "Show local notifications" toggle is **decorative** (stored preference, no consumer).
- **Device-Owner enforcement is BLOCKED in this environment**: `dpm list-owners` = "no owners" on the RMX2161; the in-scope child build is **not installed** there (the installed `com.supereagleeye.child` is a different `applicationId`); `android_dpc/` is empty. So app-suspension/quota/telemetry enforcement cannot run.
- **Two-device integration (pairing E2E, WebRTC media) is BLOCKED** — only one physical child device, no in-scope child build, TURN not configured.
- **Runtime defects D-1..D-5** (missing Edge Function, realtime recovery, missing form validation, navigation flakiness, layout overlap).

**Overall verdict: PARTIALLY FUNCTIONAL.** Core parent flows + backend + automated quality genuinely pass; enforcement, push, and two-device runtime are blocked by environment/missing implementation; several UI defects exist.

---

## 2. Audit Scope

Complete functional audit across categories A–L (startup, auth, dashboard, child onboarding, pairing, monitoring, policies/enforcement, notifications, remote assistance, settings, backend/data, UI) plus automated testing, on two devices. Strict no-modification policy observed. Fixes are **out of scope** (deferred to a separate authorized phase).

## 3. Project Architecture Discovered

- **Entry/init:** `lib/main.dart:14-38` boots 7 permanent GetX services (LocalSettings, Supabase, EdgeApi, Session, Connectivity, DeviceAdmin, RemoteSessionRegistry) then `GetMaterialApp` (`lib/app/app.dart:14-22`), `initialRoute = splash`, **26 named routes** (`lib/app/routes/app_pages.dart:56-186`).
- **State/DI:** GetX controllers+bindings per feature; repository contracts (`lib/data/repositories/repository_contracts.dart`) with Supabase implementations (`lib/app/bindings/repository_binding.dart:22-70`).
- **Backend pattern:** reads go direct to PostgREST (RLS-enforced); **all writes route through Edge Functions** (`lib/data/services/edge_api.dart:19-57`, envelope `{ok,data}`): pairing, device-policy, device-command, device-telemetry, device-register, remote-session, family-admin, auth-bootstrap, account, cron.
- **Native (Kotlin, `android/app/src/main/kotlin/com/parentcontrol/parent_control/`):** `NativeBridge.kt` (method+event channel), `GuardianService.kt` (763 LOC visible dataSync FG service: heartbeat/battery/app-list/usage uploads + policy polling), `PolicyApplier.kt` (562 LOC real `DevicePolicyManager` suspend/quota), `AudioAssistanceService.kt` (779 LOC mic FG service + watchdog), `LocationTrackingService.kt`, `BootReceiver.kt`, `SecureStore.kt`, `ParentControlDeviceAdminReceiver.kt`, `policy/PolicyEvaluator.kt` + `QuotaEvaluator.kt`.
- **Dual-role note (correction to baseline):** the child role IS present in this repo (`lib/features/child/`), and the enforcement native layer runs in the child role. `android_dpc/` is **empty** (no separate DPC/profile-owner app). There is **no separately-built child APK in scope**; the same `com.parentcontrol.parent_control` build serves both roles.
- **Dart/SDK:** Dart `^3.12.2`; pinned Flutter **3.44.6** via `.fvmrc`.

## 4. Environment and Device Details

- **Toolchain deviation:** `fvm` is **not on PATH**; the pinned SDK `C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter` was used directly for all Flutter commands. `flutter doctor` warns that PATH `flutter`/`dart` resolve to a **different, older SDK (3.38.8)** — bypassed via full path. VS C++ components missing (Windows-target only; irrelevant for Android).
- **Parent device:** `emulator-5554` (Pixel 9a, Android 17/API 37), package `com.parentcontrol.parent_control`, PID 28756, activity `.MainActivity`.
- **Child device:** `5HXWRGQ4IFU8WS4T` (Realme RMX2161, Android 12/API 31). Installed child package is `com.supereagleeye.child` v0.1.0 (different `applicationId`, **not** built from this repo). No `com.parentcontrol.*` on it. `dpm list-owners` = **no owners**.
- **Environment config:** `.tools/live_config.env` present; defines `SUPABASE_URL` + `SUPABASE_ANON_KEY`, both non-empty (values never printed). `STUN_URL` absent → Google STUN default. `env.dart:50-55` actively rejects `sb_secret_`/service_role JWTs client-side.

## 5. Build and Installation Results

- `flutter pub get`: **success**.
- `flutter analyze`: **No issues found** (0 errors/warnings/info, 114.6s).
- `flutter test`: **482 passed / 0 failed / 0 skipped** (~41s, 59 test files). No tests modified.
- Kotlin `./gradlew :app:testDebugUnitTest`: **BUILD SUCCESSFUL**, 7 suites, 0 failures.
- Deno `deno test --allow-read supabase/functions/`: **181 passed / 0 failed**.
- `flutter build apk --debug --dart-define-from-file=.tools/live_config.env`: **success** → `build/app/outputs/flutter-apk/app-debug.apk`, **243,954,904 bytes (~232.6 MiB)**, 44.9s.
- **Warning (future-compat):** `flutter_webrtc` (1.6.2+hotfix.4) still applies Kotlin Gradle Plugin; future Flutter versions will fail to build unless it migrates to Built-in Kotlin. Build succeeded on 3.44.6.
- Parent build was already installed/running on `emulator-5554` with backend defines baked in (backend init works at runtime — see §7).

## 6. Complete Feature Inventory (source-level)

| Feature | Cat | Source | Status | Notes |
|---|---|---|---|---|
| App boot + service init | A | `lib/main.dart:14-38` | REAL | permanent DI, runApp last |
| Splash/session resolve | A,B | `splash_controller.dart:13-60`, `auth_session_flow.dart:35-98` | REAL | destination from server profile/family only |
| Offline handling | A | `connectivity_service.dart:6-28`, `dashboard_controller.dart:67-77,110-117` | REAL | cached fallback + reconnect refresh |
| Env diagnostics screen | A,K | `configuration_page.dart` | REAL | shows key names only |
| Navigation (26 routes) | A,L | `app_pages.dart:56-186` | REAL | parent shell = 4 tabs |
| Register/login/verify email | B | `supabase_auth_repository.dart:45-121` | REAL | Supabase email/password + confirmation redirect |
| Role selection (bootstrap) | B | `supabase_auth_repository.dart:141-172` | REAL | `auth-bootstrap` EF, server-confirmed |
| Session persistence/logout | B,J | `session_service.dart:10-64` | REAL | tokens in secure storage |
| Dashboard (children/devices/policy) | C | `dashboard_controller.dart:101-185` | REAL | 60s polling, generation-guarded |
| Dashboard realtime | C | — | NOT IMPLEMENTED | poll-only |
| Device list/detail/last-seen/battery | C,F | `device_detail_controller.dart:63-170`, `models/device.dart:325-436` | REAL | presence = lastSeen vs 12-min window |
| Child enrollment (Child ID + QR) | D,E | `child/child_enrollment_page.dart:280` | REAL | child side of pairing |
| Pairing code/QR redeem | E | `pairing_redeem_page.dart:397-475`, `pairing_qr_payload.dart` | REAL | server owns expiry/approval |
| Installed-apps monitoring | F | `app_restrictions_controller.dart:322`, `device_apps` | REAL | uploaded by child GuardianService |
| Usage stats | F | `supabase_usage_repository.dart:28-75`, `NativeBridge.kt:146,558` | REAL | UsageAccess-permission dependent |
| Location history/current | F | `supabase_location_repository.dart:29-52`, `LocationTrackingService.kt` | REAL | mock-location flag surfaced |
| Screen status / activity | F | — | NOT IMPLEMENTED | only daily aggregates |
| App restrictions (block/windows) | G | `app_restrictions_controller.dart:557-675` | PARTIAL | save REAL; enforcement conditional on DO |
| Screen-time daily limit | G | `screen_time_controller.dart:307,366-394`, `QuotaEvaluator.kt` | PARTIAL | child-side local eval (offline-capable) |
| Scheduling/curfew | G | `models/device.dart:60-73`, `PolicyEvaluator.kt` | REAL (child-side) | `isActiveAt(localTime)` on device |
| Safety alerts | H | `supabase_alert_repository.dart:31-129` | PARTIAL | Realtime DB stream while open; **no push** |
| Push notifications (FCM) | H | — | NOT IMPLEMENTED | zero Firebase/FCM code |
| Native FG-service notifications | H | `GuardianService.kt:702-712` etc. | REAL | child ongoing notifications |
| Remote assistance request/consent | I | `supabase_remote_session_repository.dart:35-159` | REAL | child must accept; server guard |
| WebRTC audio session | I | `remote_session_controller.dart:959-1291` | REAL | RTCPeerConnection via `webrtc_signals`+Realtime; parent receive-only |
| Family create/manage/roles | C,J | `supabase_family_repository.dart:34-175` | REAL | `family-admin` EF |
| Safe zones (CRUD + arrival) | G,F | `supabase_location_repository.dart:99-147` | REAL | delete via atomic RPC |
| Audit log viewer | J,K | `supabase_audit_repository.dart:27-69` | REAL | reads `audit_logs` |
| Settings export/delete/sign-out | J | `account_privacy_repository.dart:150-266` | REAL | `account` EF |
| Theme | L | `core/theme/app_theme.dart` | REAL (light only) | no dark toggle |
| DPC / fully-managed wizard | — | `android_dpc/` (empty) | NOT IMPLEMENTED | no profile-owner app |

## 7. Parent Application Test Results (emulator-5554)

| TestID | Feature | Status | Notes |
|---|---|---|---|
| A-01 | Cold launch + splash | NOT TESTED | warm start only; `force-stop` prohibited by policy; process survived Recents swipe |
| A-02 | Backend configured at runtime | PASS | live authenticated session; dashboard/refresh show real backend data (init log not directly captured) |
| A-03 | Offline handling | PARTIAL | code real; runtime offline state not toggled (would change state) |
| A-04 | Navigation (4 tabs) | PASS | Dashboard/Devices/Alerts/Settings render correct content |
| A-05 | Crash/freeze | PASS | 0 FATAL EXCEPTION / 0 app crashes in logcat |
| A-06 | App resume | PASS | resumed to fully-rendered Dashboard |
| B-01 | Live authenticated session (real backend) | PASS | family "demo", parent Owner, email verified |
| B-02 | Session persistence | PASS | survives; secure-storage token backend |
| B-03 | Register screen + validation | NOT TESTED | splash routes to dashboard; logout prohibited (would destroy only working session) |
| B-04 | Login screen + validation | NOT TESTED | same |
| B-05 | Logout | NOT TESTED | no logout button located in Settings |
| C-01 | Dashboard content | PASS | child card "ankit1 / realme RMX2161 / Offline / last seen 59 min / 100% charging / Device admin only / No policy applied yet" |
| C-02 | Refresh re-fetch | PASS | "last seen" advanced 59→65 min live |
| C-03 | Device detail | PASS | real RMX2161 identity, battery, enforcement "Device admin only", 6 permissions granted |
| C-04 | Online/offline + last-seen + battery | PASS | Offline badge; battery from real telemetry upload |
| C-05 | Alerts list + filters | PASS | 2 unack/2 total; severity filter → correct empty state |
| C-06 | Alert realtime recovery | FAIL | **D-2**: "Live updates offline" banner persists; channel does not recover on tab visit |
| E-01 | Pairing screen + QR camera | PASS | reachable; emulator fake-camera preview works; manual Child-ID field present (view only) |
| E-02 | Empty-code validation feedback | FAIL | **D-3**: "Send pairing request" with empty field → no validation message/snackbar |
| E-03 | Real backend pairing (server flow) | PARTIAL | server flow real (code+EF); two-device runtime BLOCKED |
| E-04 | Pairing requests screen | NOT TESTED | **D-4**: tap did not reliably navigate |
| F-01 | Battery/last-seen (parent view) | PASS | real uploaded values shown |
| J-01 | Settings render | PASS | account/family/privacy/version sections |
| J-02 | Account/family server data | PASS | email/role/Verified from server |
| J-03 | Retention report | FAIL | **D-1**: "Requested function was not found" — Edge Function not deployed |
| J-04 | Export/delete account | NOT TESTED | destructive; not invoked |
| J-05 | Theme | PARTIAL | light only; no dark toggle |
| L-01 | Bottom nav + screens | PASS | |
| L-02 | Navigation reliability | FAIL | **D-4**: Pairing-requests/Audit-log taps flaky |
| L-03 | Form validation feedback | FAIL | **D-3** |
| L-04 | Layout overflow/clipping | PARTIAL | **D-5**: Settings "Account" header overlaps status bar at scroll offset |

## 8. Child Application Test Results (RMX2161)

**All child-runtime tests BLOCKED.** Evidence:
- In-scope build `com.parentcontrol.parent_control` is **not installed** on RMX2161; installed `com.supereagleeye.child` v0.1.0 is a **different applicationId**, not attributable to this repo. No child APK is produced from scope.
- `dpm list-owners` = **"no owners"** → Device Owner / profile owner enforcement modes cannot run.
- Only active device admin is an unrelated third-party (`com.sand.airdroidkids`); ours not present.
- `com.supereagleeye.child` requests no location/usage/camera/audio permissions — cannot be used to exercise this repo's child features.

| TestID | Feature | Status | Reason |
|---|---|---|---|
| D-01 | Child onboarding/profile | BLOCKED | no in-scope child build installed |
| F-02 | Installed-apps monitoring (child) | BLOCKED | no in-scope child running |
| F-03 | Usage stats (child) | BLOCKED | UsageAccess + child app absent |
| F-04 | Location (child) | BLOCKED | background tracking needs child app |
| G-04 | App-suspension enforcement | BLOCKED | requires Device Owner (none set) |
| G-05 | Screen-time quota enforcement | BLOCKED | requires child app + DO |
| H-03 | Native FG-service notifications | BLOCKED | child services not running |

## 9. Parent-Child Integration Results

**BLOCKED.** Two-device E2E (pairing completion, telemetry reaching parent from a live child, WebRTC media) could not be executed: only one physical child device, no in-scope child build, no Device Owner, `emulator-5554` reserved to Agent 3. Parent-side **view** of previously-enrolled device telemetry (battery/last-seen) DID work (§7 C-04), proving the read path from the backend is real.

## 10. Authentication and Session Audit

Real Supabase email/password auth with PKCE + confirmation redirect (`parentcontrol://auth-callback`, manifest intent-filter). Rich error mapping (`supabase_auth_repository.dart:184-285`). Session tokens persisted via secure storage; `SessionService` is display-only by design. **Verified indirectly** via a live authenticated parent session on the emulator. Auth *screens* (register/login/validation) NOT TESTED because the only working session must not be destroyed and no safe re-login credentials are documented in-repo.

## 11. Pairing Audit

**REAL backend flow** (`supabase/functions/pairing/index.ts` + atomic-RPC migration `20260101000600_atomic_pairing_invite.sql`): v1 short code + v2 permanent Child ID, strict QR payload parser (`parentcontrol://pair`), server-owned expiry/approval, enumeration-safe uniform errors, rate limits, repo never self-approves. Runtime two-device completion **BLOCKED**. **Defect D-3**: empty-code submit gives no validation feedback.

## 12. Device Monitoring Audit

Battery/last-seen/installed-apps/usage/location are **genuinely produced** by child native services posting to `device-telemetry` (`GuardianService.kt:501-619`); parent reads real DB rows (presence = 12-min window; `isMock`/mock-provider detection surfaced). Parent-side view of battery/last-seen **PASSED** on live data. Live child-side probes **BLOCKED** (no in-scope child running). **Not implemented:** screen-status / foreground-app live monitor.

## 13. Permissions Audit

| Permission | Manifest | Used in code | Notes |
|---|---|---|---|
| INTERNET / ACCESS_NETWORK_STATE | Yes | Yes | Supabase + connectivity_plus |
| ACCESS_COARSE/FINE_LOCATION | Yes | Yes | `NativeBridge.requestPermissions:455`, LocationTrackingService |
| ACCESS_BACKGROUND_LOCATION | Yes | Yes | child tracking; runtime-gated |
| CAMERA | Yes | Yes | used only for QR scanning (`mobile_scanner`) — not surveillance |
| RECORD_AUDIO | Yes | Yes | AudioAssistanceService; FG type=microphone |
| POST_NOTIFICATIONS | Yes | Yes | FG-service notification gate |
| FOREGROUND_SERVICE (DATA_SYNC/LOCATION/MICROPHONE) | Yes | Yes | 3 services |
| WAKE_LOCK / RECEIVE_BOOT_COMPLETED | Yes | Yes | watchdog / BootReceiver |
| PACKAGE_USAGE_STATS | Yes | Yes | settings-intent granted |
| QUERY_ALL_PACKAGES | Yes | Yes | app listing; Play-policy risk acknowledged in manifest |

No dangerous permission is requested-but-unused. Minor over-request: CAMERA on parent-role installs (single APK both roles).

## 14. Policy and Enforcement Audit

- **Save path REAL:** parent writes via `device-policy` EF → atomic `apply_policy_version` RPC, audits, requires verified-email parent JWT + active device.
- **Enforcement code REAL but conditional:** `PolicyApplier.kt` genuinely calls `DevicePolicyManager.setPackagesSuspended`, confirms via `isPackageSuspended`, uses `UsageStatsManager` quota, reports `enforcement_mode`. It **requires Device Owner** (`isDeviceOwner()` 135-161,219). On RMX2161: no owners + our app not installed → **enforcement BLOCKED**. Device detail correctly showed "Device admin only" + "App suspension not supported" advisory (honest degradation).
- **No explicit policy delete** (supersede-only, per `policy_read_supersede_test.dart`).

## 15. Notification Audit

- **FCM/push: NOT IMPLEMENTED** — no `google-services.json`, no Firebase Gradle plugin, no `firebase_messaging`. Corroborated by `docs/backend.md` ("FCM NOT CONFIGURED"). No push token table/send code.
- **In-app alerts: PARTIAL** — Supabase Realtime DB stream while app open; **D-2** recovery defect.
- **Native ongoing FG notifications (child): REAL** (awareness, not push) — runtime BLOCKED.
- **"Show local notifications" toggle: DEMO ONLY** — persists `notifications_enabled` but has **no consumer**.

## 16. Remote Assistance / Communication Audit

- **WebRTC audio: REAL** (`flutter_webrtc ^1.6.2`, `remote_session_controller.dart:959-1291`, `webrtc_signals` table + Realtime). **Consent-first**: ICE/media gated on `session.consent_recorded`; child must accept before any capture; **parent is strictly receive-only (never captures mic)**; child-side always-on non-dismissible mic notification with Stop. Screen mirroring explicitly out of scope (DEC-16).
- **Two-device media E2E: BLOCKED.**
- **Not implemented:** in-session mute/camera-off; ICE restart / reconnection after network loss.
- **TURN: NOT CONFIGURED** (STUN-only) → NAT connectivity risk.

## 17. Backend and Database Audit

- **Supabase init: PASS** (live session on emulator).
- **RLS: SOUND (static)** — all 18 tables `enable row level security`; read-mostly policies scoped by `private.is_family_parent/child` or `child_user_id = auth.uid()`; SECURITY DEFINER helpers with pinned `search_path`; column grants exclude `secret_hash`/`installation_id`; anon revoked; service-only tables (`device_pairing_tokens`, `safe_zone_states`, `pairing_attempts`) deny-all; realtime gated by `realtime_topic_allowed`. **No cross-family access path found.**
- **Edge Functions: PARTIAL** — 10 functions with correct `verify_jwt` (device-command/telemetry device-authenticated via constant-time SHA-256 secret; cron via `x-cron-secret`). **D-1: the retention-report function the parent calls is NOT deployed** ("Requested function was not found").
- **Direct PostgREST writes** exist only for safe zones (RLS load-bearing there); all other writes go through EFs.
- **Backend tests present:** 17 SQL/RLS chain files + Deno suite (181 pass). SQL chain not executed (heavy/stateful).

## 18. UI and Navigation Audit

26 routes; parent shell 4 tabs; screens render correctly (§7). Defects: **D-3** missing form-validation feedback, **D-4** navigation flakiness (pairing-requests/audit-log), **D-5** layout overlap at scroll offset. A screen rendering ≠ its function passing (applied throughout).

## 19. Automated Test Results

| Suite | Result |
|---|---|
| `flutter analyze` | PASS — 0 issues |
| `flutter test` (59 files) | PASS — 482/482, 0 failed, 0 skipped |
| Kotlin `testDebugUnitTest` (7) | PASS — 0 failures |
| Deno backend (`supabase/functions`) | PASS — 181/181 |
| `flutter build apk --debug` (with defines) | PASS — 232.6 MiB |
| Flutter integration (`integration_test/`, 4) | NOT EXECUTED — need device session + live backend |
| SQL/RLS chain (`supabase/tests/`) | NOT EXECUTED — heavy local-Postgres chain |

No failing test was weakened/skipped/rewritten.

## 20. Build and Runtime Errors

- **Build:** success; only forward-compat warning = `flutter_webrtc` KGP usage.
- **Runtime (emulator):** 0 app crashes/FATAL. Functional defects D-1..D-5 (§7).
- **Doctor:** PATH `flutter`/`dart` point to older 3.38.8 SDK (bypassed); VS C++ missing (Windows-target only).

## 21. Screenshots and Log Evidence Index

- Folder: `D:\parentcontrol_app\docs\testing\evidence\parent\` (37 files) — timestamped PNGs + matching uiautomator XML for current_state, devices, alerts, settings(+scroll), dashboard, family, pairing_requests, auditlog, linkchild_empty, devicedetail(+scroll), refresh; plus `raw_logcat_20261113_111846.txt` and token-redacted `redacted_logcat_20261113_111846.txt` (113 lines, 0 exceptions).
- `D:\parentcontrol_app\docs\testing\evidence\backend_connected.png` — earlier backend-config fix verification.
- No credentials/tokens/keys included (redacted).

## 22. Working Functionalities — Detailed Explanation

- **Backend auth + session (B-01/B-02):** live authenticated parent session with verified email and server-derived role; tokens in secure storage.
- **Dashboard + device detail + telemetry read path (C-01..C-04, F-01):** real child data (battery 100% charging, last-seen advancing live on refresh) read from Supabase; presence window 12 min.
- **Navigation/tabs/alerts filters (A-04, C-05, L-01):** all render correct content; severity filter produces correct empty state.
- **Settings/account/privacy (J-01/J-02):** server account/family data; export/delete flows described; version screen correctly hides backend keys.
- **RLS/family isolation + device auth + consent-gated WebRTC (K-02/K-04/I-02, static):** sound by inspection.
- **Automated quality (analyze/test/kotlin/deno/build):** all green.

## 23. Partially Working Functionalities

- **Offline handling (A-03):** real code, runtime offline not exercised.
- **Real backend pairing (E-03):** server flow real; two-device completion blocked.
- **App restrictions / screen-time (G-02/G-03):** save real; enforcement conditional on Device Owner.
- **In-app alerts (H-02):** works while open but **D-2** recovery defect.
- **WebRTC (I-01):** real signaling/consent; media E2E blocked; TURN/mute/ICE-restart gaps.
- **Theme (J-05):** light only.
- **Layout (L-04):** **D-5** overlap.

## 24. Non-Working Functionalities (with root cause)

- **Push notifications / FCM (H-01)** — expected: push delivery. Actual: none. Cause: **feature not implemented** (no Firebase project/`google-services.json`/`firebase_messaging`). Layer: backend+client. Next action: create Firebase app, add Gradle/Dart, token table + send path (owner-authorized).
- **Alert realtime recovery (C-06 / D-2)** — banner "Live updates offline" persists, channel doesn't recover on tab visit. Cause: **suspected** realtime reconnect not triggered on tab focus (frontend). Next: verify reconnect logic in alert controller.
- **Retention report (J-03 / D-1)** — "Requested function was not found". Cause: **confirmed** referenced Edge Function not deployed (backend/config). Next: deploy the retention EF or point client to existing route.
- **Empty-code pairing submit (E-02 / D-3)** — no validation feedback. Cause: **suspected** missing client-side validation/snackbar (frontend). Next: add validation feedback.
- **Navigation to Pairing-requests/Audit-log (L-02 / D-4)** — taps didn't reliably navigate. Cause: **suspected** route/tap-target issue (frontend) — needs reproduction.
- **Dashboard realtime (C-06 category)** — poll-only; screen-status/foreground-app monitor, in-session mute/camera-off, ICE restart, DPC wizard: **not implemented**.

## 25. Demo/Mock Functionalities

- **"Show local notifications" toggle (H-04):** persists a preference with **no consumer** → decorative. The app is otherwise notably honest (config screen asserts "nothing is simulated"; enforcement degrades to "monitor-only"/"Device admin only" rather than faking).

## 26. Blocked and Untested Functionalities

- **Blocked (environment):** all child-runtime tests (D-01, F-02..F-04, G-04/G-05, H-03) — no in-scope child build on RMX2161, `dpm` = no owners; two-device integration (§9); WebRTC media E2E; TURN relay.
- **Not tested (policy/state-preservation):** cold launch/splash (force-stop prohibited), register/login screens + validation, logout, token expiry/re-auth, offline toggle, destructive flows (export/delete/unpair/acknowledge), pairing-requests/audit-log screens (D-4).
- **Not executed (heavy):** Flutter integration tests, SQL/RLS chain.

## 27. Security and Privacy Findings

- **Positive:** no secrets in client (env-only; service_role/`sb_secret_` rejected client-side); service-role only in Edge; RLS family isolation sound; column grants hide secrets; device auth constant-time/enumeration-resistant; WebRTC consent-first with receive-only parent + visible child mic notification; mock-location surfaced; `allowBackup=false`; network_security_config present.
- **Risks/gaps:** `QUERY_ALL_PACKAGES` full app list leaves device (Play-policy/privacy); telemetry pipeline is covert-capable in principle but mitigated by child-side visible FG notifications — **verify consent UX is non-skippable at runtime** (needs two-device test); `.tools/` contains plaintext-looking credential files (`test-parent-pw.txt`, `staging-db-password.txt`, `qa_accounts.env`, etc.) — **confirm they are gitignored** (not shown in `git status` untracked → likely ignored; verify); CAMERA requested on parent-role installs though used only for QR; safe-zone direct writes rely solely on RLS.

## 28. Performance and Stability Findings

- No crashes/FATAL during parent session. Choreographer frame skips + a Davey (~6.2s) observed at cold-ish start (main-thread work during init) — startup jank worth watching. APK is large (~232.6 MiB debug) — expected for debug+split; release/split-per-ABI recommended. Heartbeat cadence under Doze indeterminate without child device.

## 29. Known Limitations

- Single physical child device + policy prohibition on state changes → no live child/enforcement/two-device verification.
- `fvm` unavailable → pinned SDK used directly.
- No safe re-login credentials → auth screens not exercised.
- SQL chain + integration tests not run (heavy/stateful).

## 30. Prioritized Recommended Fixes (for a separate authorized phase — NOT applied here)

1. **Deploy missing retention Edge Function** (or fix client route) → clears D-1. (P1, backend/config)
2. **Implement FCM push** end-to-end (Firebase app, token table, send path) or remove/label the notification toggle. (P1, feature)
3. **Fix realtime alert recovery** on tab focus (D-2). (P2, frontend)
4. **Add pairing empty-code validation feedback** (D-3) and **fix navigation** to Pairing-requests/Audit-log (D-4). (P2, frontend)
5. **Fix Settings layout overlap** (D-5). (P3, UI)
6. **Provision Device Owner on a test child device** (or build/ship the in-scope child role) to exercise enforcement/pairing/two-device paths. (P1, environment)
7. **Migrate `flutter_webrtc`** to a Built-in-Kotlin version before it breaks future builds. (P2, dependency)
8. **Verify `.tools/` credential files are gitignored**; consider moving to OS keychain. (P2, security hygiene)
9. **Configure TURN** for NAT traversal; implement ICE restart + in-session mute/camera-off. (P3, remote assistance)

## 31. Final Audit Verdict

**PARTIALLY FUNCTIONAL.**

Basis (evidence, not assumption): automated quality is fully green (analyze 0, Dart 482/482, Kotlin pass, Deno 181/181, APK builds); the parent application genuinely works against a live Supabase backend (real auth session, real telemetry read path, real dashboard/alerts/settings/navigation); backend RLS/security is sound by inspection. Against that: push notifications are not implemented, device-owner enforcement and all child/two-device runtime paths are BLOCKED in this environment (no in-scope child build, no Device Owner), and five runtime defects (D-1..D-5) were observed. Core functionality is real and working; significant subsystems are blocked or missing.

---

## Overall Summary Table

| Category | Total | Pass | Partial | Fail | Blocked | Not Tested | Demo Only |
|---|---:|---:|---:|---:|---:|---:|---:|
| A. Startup/Stability | 6 | 4 | 1 | 0 | 0 | 1 | 0 |
| B. Authentication | 5 | 2 | 0 | 0 | 0 | 3 | 0 |
| C. Parent Dashboard | 6 | 5 | 0 | 1 | 0 | 0 | 0 |
| D. Child Onboarding | 1 | 0 | 0 | 0 | 1 | 0 | 0 |
| E. Device Pairing | 4 | 1 | 1 | 1 | 0 | 1 | 0 |
| F. Device Monitoring | 5 | 1 | 0 | 0 | 3 | 1 | 0 |
| G. Policies/Enforcement | 5 | 1 | 2 | 0 | 2 | 0 | 0 |
| H. Notifications | 4 | 0 | 1 | 1 | 1 | 0 | 1 |
| I. Remote Assistance | 4 | 1 | 1 | 0 | 1 | 1 | 0 |
| J. Settings/Account | 5 | 2 | 1 | 1 | 0 | 1 | 0 |
| K. Backend/Data | 5 | 4 | 0 | 1 | 0 | 0 | 0 |
| L. UI/Navigation | 4 | 1 | 1 | 2 | 0 | 0 | 0 |
| Automated | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| **TOTAL** | **59** | **27** | **8** | **7** | **8** | **8** | **1** |

---

## Completion Summary

1. **Report path:** `D:\parentcontrol_app\docs\testing\COMPLETE_FUNCTIONAL_TEST_AUDIT.md`
2. **Evidence folder:** `D:\parentcontrol_app\docs\testing\evidence\` (parent/ subfolder: 37 files)
3. **Test cases executed/classified:** 59
4. **Counts:** PASS 27 · PARTIAL 8 · FAIL 7 · BLOCKED 8 · NOT TESTED 8 · DEMO ONLY 1
5. **Build/analysis:** analyze 0 issues; Dart 482/482; Kotlin pass; Deno 181/181; debug APK 232.6 MiB
6. **Major errors:** D-1 retention Edge Function not deployed; D-2 realtime alert recovery; D-3 missing pairing validation; D-4 navigation flakiness; D-5 layout overlap; FCM/push not implemented; Device-Owner enforcement blocked (no owners / no in-scope child build); `flutter_webrtc` KGP future-compat warning
7. **Final verdict:** PARTIALLY FUNCTIONAL

**Git integrity:** pre- and post-audit state identical (branch `main`, HEAD `5a39747bfaadc2ff79d010db97c7a154f5584f56`); no source/config/test/schema modified; only `build/`, `.dart_tool/`, and new `docs/testing/` evidence added. No fixes applied (audit-only, per final instruction).
