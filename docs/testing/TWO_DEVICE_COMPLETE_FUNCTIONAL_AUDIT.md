# Two-Device Simultaneous Functional Audit — Parent Control

- **Project:** `D:\parentcontrol_app` (pubspec `parent_control`, applicationId `com.parentcontrol.parent_control`, v1.0.0)
- **Type:** Read-only functional audit. **No fixes applied.**
- **Date:** 2026-11-13
- **Topology:** Parent = Pixel 9a emulator `emulator-5554` (Android 17/API 37) → Parent Mode. Child = Realme RMX2161 `5HXWRGQ4IFU8WS4T` (Android 12/API 31) → Child Mode.
- **Method:** Orchestrator drove both devices simultaneously; 4 parallel subagents produced source, automated-suite, backend and native/security reports (`AGENT_A..D_*.md` in this evidence tree).
- **Git:** branch `main`, HEAD `5a39747bfaadc2ff79d010db97c7a154f5584f56` before and after. No source, test, manifest, Gradle, schema or Edge Function file modified.

---

## 1. Executive Summary

This audit **overturns the central blocker of the previous audit**. The earlier report declared all child-runtime tests BLOCKED on the theory that "no in-scope child build exists". That was wrong: this repository ships **one dual-role APK**, and the same `com.parentcontrol.parent_control` build is the child build. It was installed on the physical RMX2161, signed in as a real child account, and exercised live.

What genuinely works, with evidence:

- **Two-device remote assistance closed loop.** The server's append-only audit log shows the full chain on one session: *Assistance requested → Assistance accepted (actor `ankit1`, the child) → Assistance session started (child) → Assistance session ended (actor `ankit`, the parent)*. Consent is real and recorded.
- **Native background service is real.** `GuardianService` runs as a true Android foreground service (id 4101, channel `guardian_status` / "Background sync") with a visible notification.
- **Auth behaves correctly.** Empty submit yields "Email is required" / "Password is required"; bad credentials yield "Could not sign in — The email or password is incorrect." Sign-out **stops** the background service (0 service records afterwards), exactly as its confirmation dialog promises.
- **The app is honest about failure.** The child reports "Offline", "Not managed — app blocking is not available", "No rules downloaded", "No location reported yet", and surfaces the raw cause verbatim: **"Location upload failed: Device credentials are not valid."** Nothing is faked.

What does not work:

- **Telemetry is dead end-to-end in this environment.** After the child reinstall, the local device credential no longer matches the server's `secret_hash`, so every upload is rejected. The parent therefore shows stale data from 10:18 AM.
- **WebRTC media never connects.** 9 assistance sessions exist; every one shows **"Media: No media is open"**. Signalling works; media does not. TURN is not configured.
- **Policy enforcement is impossible here.** Device Owner cannot be provisioned from inside the app (no DPC exists), and Device Admin grants *nothing* — its policy file is an empty `<uses-policies/>`.
- **The QA accounts in `.tools/qa_accounts.env` do not exist in the hosted backend.** Both `CHILD_B` and `CHILD_C` logins failed, leaving exactly one usable child credential and blocking the fresh-pairing test.

**Verdict: PARTIALLY FUNCTIONAL.**

---

## 2. Architecture and Discovered Feature Inventory

Full detail: `evidence/AGENT_A_FEATURE_INVENTORY.md` (323 lines, file:line-cited).

- Single Flutter codebase, 26 named routes, GetX DI, 7 permanent services (`lib/main.dart:14-38`).
- Reads go direct to PostgREST under RLS; **all writes route through Edge Functions** (`lib/data/services/edge_api.dart:19-57`).
- ~4,100 LOC Kotlin: `GuardianService`, `PolicyApplier`, `AudioAssistanceService`, `LocationTrackingService`, `BootReceiver`, `NativeBridge`, `SecureStore`, `policy/PolicyEvaluator`, `policy/QuotaEvaluator`.
- **Dual-role confirmed at runtime:** `/role-selection` offers Parent Mode and Child Mode; the server profile — never the local choice — decides access. The role screen says so explicitly.
- Zero hardcoded demo/mock data found in `lib/`.

---

## 3. Device and Environment Details

| Item | Parent | Child |
|---|---|---|
| Device | `emulator-5554` Pixel 9a | `5HXWRGQ4IFU8WS4T` RMX2161 |
| OS | Android 17 / API 37 | Android 12 / API 31 |
| Package | `com.parentcontrol.parent_control` 1.0.0 | same, installed this audit |
| Role | Parent Mode, signed in (`ankit`, family "demo", Owner) | Child Mode, signed in as `ankit1` |
| ABI | x86_64 | arm64-v8a |

Toolchain: `fvm` is not on PATH; the pinned SDK was invoked directly at `C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter`. Backend defines supplied via `--dart-define-from-file=.tools/live_config.env`.

---

## 4. Build and Installation Results

| Step | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter analyze` | PASS — 0 errors / 0 warnings / 0 info |
| `flutter build apk --debug` (pre-existing artifact) | PASS — 243,954,904 B, sha1 matches sidecar |
| `adb install -r` on RMX2161 | PASS — "Success" |
| Launch on both | PASS — `.MainActivity` focused on both simultaneously |

`com.supereagleeye.child` was correctly excluded: it requests no location/usage/camera/audio permission and is a different product.

---

## 5. Parent-Side Results (emulator-5554)

| ID | Test | Status | Evidence |
|---|---|---|---|
| P-01 | Role selection screen | PASS | `child/20261113_113700_02_launch.png` |
| P-02 | Dashboard renders real backend data | PASS | `parent/20261113_112109_06_dashboard.png` |
| P-03 | Device detail identity/battery/last-seen | PASS (stale) | `parent/p03.xml` |
| P-04 | Device permissions card | **FAIL** | Shows all Granted; child reports otherwise — stale snapshot indistinguishable from current |
| P-05 | App restrictions screen + honest disclaimers | PASS | `parent/p04_apprestrictions.png` |
| P-06 | Recent commands panel | PASS | "No commands have been sent to this device yet." |
| P-07 | Location screen empty state | PASS | `parent/p08_location.png` |
| P-08 | Safe zones empty + create form validation | PASS | `parent/p11..p15.xml` |
| P-09 | Safety alerts from real DB rows | PASS | `parent/p18_alerts.png` — 2 unacknowledged low-battery |
| P-10 | Remote assistance list | PARTIAL | 9 sessions, all "Media: No media is open" |
| P-11 | Audit log (server events) | PASS | `parent/p21..p24.xml` — 36 events |
| P-12 | Retention values | PASS | Location 30 d / Usage 90 d read from server |
| P-13 | Device recovery entry point | PASS | "Lost or reinstalled phone" + `Start device recovery` |

---

## 6. Child-Side Results (RMX2161)

| ID | Test | Status | Evidence |
|---|---|---|---|
| C-01 | Cold launch of in-scope build on physical device | PASS | `child/20261113_113700_02_launch.png` |
| C-02 | Child Mode sign-in form + empty validation | PASS | `child/s18_empty_validation.png` — "Email is required", "Password is required" |
| C-03 | Invalid credential handling | PASS | `child/s26_childB_login_result.png` — "Could not sign in / The email or password is incorrect." |
| C-04 | Child session resolves to child shell | PASS | Home tab: "This account is linked as a child", `ankit1`, family "demo", Device setup **Registered** |
| C-05 | Child shell 4-tab nav (Home/Rules/Requests/Settings) | PASS | `child/s09.xml` |
| C-06 | GuardianService foreground service | **PASS** | `dumpsys activity services` → `isForeground=true foregroundId=4101 channel=guardian_status` |
| C-07 | Visible awareness notification | PASS | `dumpsys notification` → channel "Background sync", id 4101 |
| C-08 | Telemetry upload | **FAIL** | Child UI verbatim: "Last error \| Location upload failed: **Device credentials are not valid.**" |
| C-09 | Command polling | FAIL | "Last command check \| No check yet" — same credential cause |
| C-10 | Device status reporting | PASS (correct) | Reports **Offline**, last seen 10:18 AM — honest, not fabricated |
| C-11 | Enforcement-mode self-report | PASS | "Android control: Not managed — app blocking is not available" |
| C-12 | Policy state self-report | PASS | "Policy version: No rules downloaded" |
| C-13 | Permission states read from Android | PASS | Camera/Microphone/Notifications **Granted**; Usage access/Background location/Device admin **not granted** |
| C-14 | App-blocking disclaimer | PASS | "A normal app install cannot suspend other apps." |
| C-15 | Sign-out stops background protection | **PASS** | After confirm: `dumpsys activity services` → **0 ServiceRecords** |
| C-16 | Location sharing toggle surfaced with honest copy | PASS | "Your choice. The parent app can only request a location while this is on." |

---

## 7. Simultaneous Integration Test Log

Both apps were alive and focused at the same time throughout. Times are device-local.

| # | Time | Parent action | Backend event | Child action | Parent observed | Child observed | Status |
|---|---|---|---|---|---|---|---|
| INT-1 | 11:47 | Request video assistance | `remote_sessions` row + audit "Assistance requested" | Consent dialog shown, **child accepted** | Session card "Requested 11:47, Child consent Recorded, Accepted 11:47" | Consent UI | **PASS (signalling)** |
| INT-2 | 11:48 | — | audit "Assistance session started" (actor `ankit1`) | Joined | — | — | **PASS** |
| INT-3 | 11:49 | End session | audit "Assistance session ended" (actor `ankit`) | Stopped | "Session ended — This session is over." | — | **PASS** |
| INT-4 | 11:49+ | Read media state | — | — | **"Media: No media is open"** on all 9 sessions | — | **FAIL (media)** |
| INT-5 | 12:05 | Refresh dashboard | read `devices` | GuardianService running | Device **Offline**, last seen 10:18 AM | Upload rejected: invalid device credential | **FAIL (telemetry)** |
| INT-6 | 12:10 | Open device detail | read `device_permissions` | permissions differ | Shows all Granted (stale) | Usage access + background location NOT granted | **FAIL (staleness)** |
| INT-7 | 12:12 | Open app restrictions | read `device_policies` | — | "Version: No version yet"; "Enforcement: Device admin only" | "No rules downloaded" | **PARTIAL** |
| INT-8 | 12:15 | Open location | read `location_fixes` | service running | "No location reported yet" | upload failing | **BLOCKED** |
| INT-9 | 12:18 | Safe-zone create form | — | — | Validation rejects bad lat/long/radius | — | **PASS (validation)**, write NOT TESTED |
| INT-10 | 12:22 | Read alerts | `safety_alerts` | — | 2 real rows (Oct 30, Nov 3) | — | **PASS (read)** |
| INT-11 | 12:25 | Read audit log | `audit_logs` | — | 36 events incl. INT-1..3 chain | — | **PASS** |

---

## 8. Pairing Results

**NOT TESTED end-to-end — genuinely blocked, with a documented cause.**

Pairing requires a child session that can be signed in and re-linked. Two independent blockers converged:

1. **No spare provisioned child account.** `.tools/qa_accounts.env` defines CHILD_A/B/C, but `CHILD_B` (`qa.6child.b.20261@example.com`) and the CHILD_A env value (`qa.c102.6@example.com`) both return *"The email or password is incorrect"* against the hosted project. The only credential that actually works is `ankit1@gmail.com`, supplied by `.tools/test-child-pw.txt`.
2. **Text entry on the RMX2161 is not automatable here.** The device's autofill picker repeatedly intercepted `adb input text` and injected the **owner's personal Google accounts** into the email field, corrupting input and leaking personal data into evidence (redacted — see §17).

The existing link was therefore exercised read-only, and it is real: the child reports "Linked", family "demo", Device setup "Registered", and the parent lists the enrolled device.

**Correct remediation path exists and was verified present:** parent device detail → "Lost or reinstalled phone" → `Start device recovery`, whose copy correctly states the server revokes the old credential and that a fresh one-time code plus child approval is required.

---

## 9. Monitoring Results

| Capability | Parent view | Child reality | Status |
|---|---|---|---|
| Battery | 100% (charging) | stale, from 10:18 AM | PARTIAL |
| Last seen | advancing minute counter on a frozen timestamp | service running, uploads rejected | PARTIAL |
| Presence | Offline | correct | PASS |
| Installed apps | "This device has not reported its installed apps yet. An empty snapshot is not the same as 'no apps installed'." | not uploading | PASS (honest) |
| Usage stats | n/a | Usage access **not granted** | BLOCKED |
| Location | "No location reported yet" | upload failing | BLOCKED |
| Screen status / foreground app | — | not implemented | NOT IMPLEMENTED |

---

## 10. Permission Results

Observed on the child device via its own "read from Android" panel:

| Permission | Granted | Consequence when absent (verified in UI) |
|---|---|---|
| Notifications | Yes | FGS allowed to run — it is running |
| Camera | Yes | only used in accepted assistance sessions |
| Microphone | Yes | only in accepted sessions |
| Precise location | Yes | — |
| Usage access | **No** | screen-time reports unavailable |
| Background location | **No** | tracking stops when screen off |
| Device admin | **No** | and grants nothing anyway (see §11) |

**Code-level findings (Agent D):** `ACCESS_BACKGROUND_LOCATION` is **never actually requested** — the Dart flag is dropped in `NativeBridge.kt:464-475`; the app opens generic App-info instead. Battery-optimisation exemption is **not implemented at all** (zero references to `IGNORE_BATTERY_OPTIMIZATIONS`), which will kill heartbeat cadence under Doze on real phones.

---

## 11. Policy Synchronization and Enforcement

- **Save path:** real, but untested end-to-end because the child cannot poll.
- **Delivery is pull-only.** `GuardianService` polls every 20 s; `device_commands` / `device_policies` are **not** in the realtime publication, so nothing is pushed.
- **Device Owner is mandatory for app suspension and cannot be obtained in-app.** `android_dpc/` is empty, `settings.gradle.kts:26` includes only `:app`, and the sole DPM intent is `ACTION_ADD_DEVICE_ADMIN`. Only four DPM calls exist in 4,100 LOC.
- **Device Admin grants literally nothing.** `device_admin.xml:5` is an empty `<uses-policies/>` and the receiver is an empty subclass; admin state only relabels `enforcement_mode` to `"device_admin"`.
- Without DO, `PolicyApplier.kt:135-142` reports `desired=N, applied=0, enforcement_supported=false` → server writes `unsupported` / `device_owner_required` → parent banner. **This chain is honest and correct.**
- **Bedtime/curfew does nothing.** Its only write site, `PolicyApplier.kt:503` (`result.bedtime_active`), is read by nobody in `lib/` or `supabase/`. A bedtime-only policy is **permanently pending**.
- **Near-false-success:** a mixed app-block + screen-time policy is stored as `enforced` while the quota half is only advisory (`enforcement.ts:490-494`), so the parent can show a green banner for something not actually enforced.
- **Dead wiring:** `applyPolicy`, `getBatteryStatus`, `getLastKnownLocation`, `getDailyUsage` have Kotlin handlers and **zero Dart callers**; `location_update` and `guardian_stall_recovered` events are unconsumed.

---

## 12. Notification Results

- **FCM/push: NOT IMPLEMENTED.** No `google-services.json`, no Firebase plugin, no `firebase_messaging`.
- **Native foreground notifications: REAL and verified running** (child, id 4101).
- **Parent "Show local notifications" and "Location sharing reminder" switches: DEMO ONLY** — persisted with no consumer.
- **`app_blocked` and `permission_missing` alerts are never generated** by any code path, so the alert surface can never reflect enforcement.

---

## 13. Remote Assistance Results

**Signalling, consent and lifecycle: PASS** — proven by INT-1..3 and the server audit trail.

**Media: FAIL.** All 9 sessions report "Media: No media is open". Causes: TURN is not configured (STUN-only), and the two devices sit behind different NATs. `remote_sessions` rows with `expires_at NULL` can also strand a device's ability to accept new requests, because the sweep that closes them lives in an **undeployed** function.

**Consent model verified sound:** child must accept before capture; the parent screen states "This phone's camera and microphone are never used"; parent is receive-only. Caveat from Agent D: the **native** mic-service start has no consent check of its own — consent is enforced only in Dart.

---

## 14. Backend and Database Results

From `evidence/AGENT_C_BACKEND_AUDIT.md`. The Supabase CLI is **not authenticated** in this environment, so live state is reconstructed from the repo's own 2026-11-05 hosted-state verification and is **UNVERIFIED after that date**.

| Edge Function | Deployed |
|---|---|
| auth-bootstrap, pairing, device-register, device-policy, device-telemetry | DEPLOYED |
| device-command, family-admin, remote-session | DEPLOYED but **STALE** (later fixes undeployed) |
| **account** | **NOT DEPLOYED** — this is the "Requested function was not found" behind retention-report/export/delete |
| cron | DEPLOYED but **NEVER SCHEDULED** (no `pg_cron`, no `[cron_jobs]`) |

- Migrations `20261030000100/000200/000300` and `20261103000100` are **NOT APPLIED** to the hosted DB.
- Because `20261030000200` is undeployed, the hosted `authenticated` role **still has an unrestricted DELETE policy on `safe_zones`** — unaudited direct deletes. **Confirmed exposure.**
- RLS is deny-by-default and family isolation is sound; `secret_hash` / `installation_id` are service-only columns.
- **Realtime:** only `remote_sessions`, `webrtc_signals`, `safety_alerts` are published, gated by `realtime_topic_allowed`. Policy and command traffic is poll-only.

---

## 15. UI and Navigation Results

Parent shell, child shell, device detail, restrictions, screen time, location, safe zones, alerts, assistance, audit and settings all rendered and navigated correctly under ADB driving. Empty states are consistently informative rather than blank. Form validation fires on login and safe-zone fields.

Defects: stale permission snapshot (§5 P-04); settings "Account" header overlap at scroll offset (carried over from the prior audit, not re-confirmed this run).

---

## 16. Automated Test Results

Reproduced exactly against baseline (full detail in `AGENT_B_AUTOMATED_RESULTS.md`):

| Suite | Result |
|---|---|
| `flutter analyze` | 0 / 0 / 0 |
| `flutter test` | **482 passed / 0 failed / 0 skipped** (59 files) |
| `gradlew :app:testDebugUnitTest` | **7 suites / 57 tests / 0 failures** |
| `deno test supabase/functions/` | **181 passed / 0 failed** (15 files) |
| Debug APK | sha1 matches sidecar; minSdk 24, targetSdk 36 |
| `integration_test/` (4 journeys) | NOT EXECUTED — needs device transport + live credentials; one is state-mutating with a 30-min timeout |
| SQL/RLS chain (33 files) | NOT EXECUTED — creates/drops disposable databases |

No test was weakened, skipped or rewritten. `local-ci.ps1` header counts are stale versus reality (Dart 408→482, Deno 150→181, Kotlin 39→57).

---

## 17. Security and Privacy Findings

**Positive:** no secrets in the client; service-role keys only server-side; `allowBackup=false`; HTTPS-only, no cleartext; zero `Log.*` in Kotlin and zero `print`/`debugPrint` in Dart (so no token or PII leakage through logcat); EncryptedSharedPreferences; all services `exported=false`; RLS family isolation sound.

**Risks:**
1. **No certificate pinning** (explicit TODO).
2. **`parentcontrol://` custom-scheme callback is stealable** by any app registering it.
3. **`QUERY_ALL_PACKAGES`** uploads a full installed-app inventory every 30 minutes.
4. **Native mic-service start lacks its own consent gate** — consent lives only in Dart.
5. **Hosted `safe_zones` DELETE policy is still permissive** (§14) — confirmed.
6. `.tools/` credential files are correctly gitignored (`.gitignore:16`).

**Audit-process privacy incident:** the RMX2161's autofill picker injected the **device owner's personal Gmail addresses** into the login field, and they were captured in two evidence XML files. These have been redacted in place (`s22.xml`, `s23.xml`). No personal address remains in the evidence tree.

---

## 18. Performance and Stability

No crashes or `FATAL EXCEPTION` on either device across the session. The child sustained a foreground service for ~40 minutes. Startup jank (Davey ~6.2 s) was recorded previously and was not re-measured here. Debug APK is 232.6 MiB; release/split-per-ABI is the recommendation.

---

## 19. Every Discovered Error

| ID | Error | Where | Root cause | Layer |
|---|---|---|---|---|
| E-1 | "Location upload failed: Device credentials are not valid." | child Home | reinstall invalidated device secret; server hash mismatch | backend/client state |
| E-2 | "Media: No media is open" on all 9 sessions | parent assistance list | TURN unconfigured + NAT; signalling-only success | config/infra |
| E-3 | Parent shows all permissions Granted while child reports otherwise | `parent/p03.xml` vs `child/s08.xml` | stale `device_permissions` snapshot indistinguishable from live | frontend |
| E-4 | QA child accounts rejected | `qa_accounts.env` | accounts never provisioned in hosted project | configuration |
| E-5 | "Requested function was not found" (retention/export/delete) | prior audit, re-confirmed by Agent C | `account` Edge Function **not deployed** | backend deployment |
| E-6 | Bedtime/curfew has no effect | `PolicyApplier.kt:503` | `bedtime_active` written, read by nobody | client |
| E-7 | Mixed policy reports `enforced` while quota is advisory | `enforcement.ts:490-494` | status conflates two enforcement halves | backend |
| E-8 | `ACCESS_BACKGROUND_LOCATION` never requested | `NativeBridge.kt:464-475` | Dart flag silently dropped | Android |
| E-9 | No battery-optimisation exemption | repo-wide | not implemented | Android |
| E-10 | Empty pairing-code submit gives no feedback | prior audit D-3 | missing client validation (login forms are fine) | frontend |
| E-11 | Permanently pending policies | `enforcement.ts:401-403` | non-advancing `policy_version`, no requeue | backend |
| E-12 | Stranded `remote_sessions` | undeployed sweep | `expires_at NULL` never reaped | backend deployment |

---

## 20. Working Functionality (explained)

**Remote-assistance consent and lifecycle** is the standout: a parent request becomes a server row, reaches the child, the child accepts, the session starts, the parent ends it, and every step is written to an append-only audit log the parent can read. This is a true closed loop across two physical devices.

**The child background service** is a real Android foreground service with a persistent visible notification, and sign-out provably stops it.

**Honest degradation** is systemic and verified in six separate places: Offline status, "Not managed", "No rules downloaded", "An empty snapshot is not the same as 'no apps installed'", "A database flag does not block an app", and the raw credential error surfaced verbatim.

**Auth validation and error mapping** work on both forms.

---

## 21. Partially Working

Policy **save** (real, unverified delivery), telemetry **read** path (works, returns stale rows), alerts (read works, push absent), WebRTC (signalling yes, media no), safe zones (validation yes, write untested).

---

## 22. Non-Working

Telemetry upload (E-1), WebRTC media (E-2), permission freshness (E-3), bedtime/curfew (E-6), retention/export/delete via the `account` function (E-5), push notifications (not implemented), screen-status/foreground-app monitoring (not implemented), dashboard realtime (poll-only).

---

## 23. Blocked and Untested

- **Pairing E2E** — no spare provisioned child account + autofill interference (§8).
- **Policy enforcement E2E** — needs a child that can poll commands (blocked by E-1) **and** Device Owner (unobtainable in-app; deliberately not forced via `dpm` on a personal phone per the safety rules).
- **App suspension, screen-time quota, usage stats** — Device Owner + Usage Access.
- **Alert acknowledgement, device revoke, account export/delete** — irreversible; skipped by policy.
- **Flutter integration tests and the SQL/RLS chain** — not executed.

---

## 24. Recommended Fixes (prioritised, NOT applied)

1. **P0 — Recover the device-credential path.** Add an automatic re-registration/repair on "credentials not valid" instead of leaving the child silently offline with a raw error string. (E-1)
2. **P0 — Deploy the `account` Edge Function and the four undeployed migrations**, then re-run the hosted-state verification; the 2026-10-30 `safe_zones` DELETE tightening is a live exposure. (E-5, §14)
3. **P1 — Stamp every device-reported snapshot with its `reported_at` and grey it out past the presence window**, so the parent cannot mistake stale for live. (E-3)
4. **P1 — Configure TURN** and add ICE restart, then re-test media on the two devices. (E-2)
5. **P1 — Provision real QA child accounts** in the hosted project, or delete the misleading `qa_accounts.env` entries. (E-4)
6. **P2 — Implement background-location request and battery-optimisation exemption**; both are advertised by the UI but not actually obtained. (E-8, E-9)
7. **P2 — Make bedtime actually do something**, or remove it from the policy model; and split `enforced` so a quota-only half cannot report success. (E-6, E-7)
8. **P2 — Add a DPC so Device Owner is reachable**, otherwise app-blocking is permanently untestable outside a factory-provisioned device.
9. **P3 — Implement FCM push or delete both notification switches** so they stop being decorative.
10. **P3 — Add pairing-code validation feedback**; pin the `flutter_webrtc` Kotlin migration.

---

## 25. Final Verdict

**PARTIALLY FUNCTIONAL.**

The application is genuinely real — not a UI demo — and its most delicate cross-device flow, consented remote assistance, demonstrably works end to end across two physical devices with a server-side audit trail. Its background service is real, its auth is real, and it is unusually honest about what it cannot do.

It is not production-ready. Live telemetry is broken by an unrecovered credential state, media never connects, enforcement is unreachable without Device Owner, push does not exist, and several backend artefacts are undeployed — one of which leaves a confirmed permissive DELETE policy on the hosted database.

### Summary table

| Category | Total | Pass | Partial | Fail | Blocked | Not Tested | Demo Only |
|---|---:|---:|---:|---:|---:|---:|---:|
| Startup / stability | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| Authentication | 6 | 5 | 0 | 0 | 0 | 1 | 0 |
| Session / logout | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| Child onboarding | 4 | 3 | 0 | 0 | 0 | 1 | 0 |
| Pairing | 3 | 0 | 0 | 0 | 1 | 2 | 0 |
| Monitoring / telemetry | 7 | 2 | 2 | 2 | 1 | 0 | 0 |
| Policies / enforcement | 7 | 1 | 1 | 3 | 2 | 0 | 0 |
| Notifications | 4 | 1 | 0 | 1 | 0 | 0 | 2 |
| Remote assistance | 5 | 3 | 0 | 1 | 1 | 0 | 0 |
| Backend / data | 6 | 3 | 0 | 2 | 0 | 1 | 0 |
| UI / navigation | 6 | 5 | 1 | 0 | 0 | 0 | 0 |
| Permissions | 4 | 2 | 1 | 0 | 1 | 0 | 0 |
| Automated suites | 7 | 5 | 0 | 0 | 0 | 2 | 0 |
| **TOTAL** | **70** | **37** | **5** | **9** | **6** | **7** | **2** |

---

## 26. Git Integrity

- HEAD before and after: `5a39747bfaadc2ff79d010db97c7a154f5584f56` (branch `main`) — **unchanged**.
- No source, test, manifest, Gradle, migration, Edge Function or config file was modified.
- Only `docs/testing/` audit artefacts and one pre-existing IDE cache (`.idea/caches/deviceStreaming.xml`) differ from the starting tree.
- **Note for the owner:** 49 audit files appear **staged** in the index (`.git/index` mtime 11:52:09 today). The orchestrator did not run `git add`; no commit was made and HEAD is unchanged. Left untouched rather than "cleaned up", per the no-Git-operations rule.
- **Device state changes made:** the in-scope APK was installed on the RMX2161, and the child account `ankit1` was **signed out** during testing and could not be restored automatically (§8). It must be signed in again manually.

## 27. Evidence Paths

- Report: `D:\parentcontrol_app\docs\testing\TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md`
- `D:\parentcontrol_app\docs\testing\evidence\parent\` (65 files)
- `D:\parentcontrol_app\docs\testing\evidence\child\` (49 files)
- `D:\parentcontrol_app\docs\testing\evidence\integration\` (2 files)
- Subagent reports: `AGENT_A_FEATURE_INVENTORY.md`, `AGENT_B_AUTOMATED_RESULTS.md`, `AGENT_C_BACKEND_AUDIT.md`, `AGENT_D_NATIVE_SECURITY_AUDIT.md`
