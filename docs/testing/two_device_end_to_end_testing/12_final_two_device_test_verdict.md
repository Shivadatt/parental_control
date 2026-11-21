# 12 — Final Two-Device Test Verdict

**Date:** 2026-11-21  
**Repository:** `D:\parentcontrol_app`, `main`, HEAD `bbd3c21`  
**Installed build tested:** `1.0.0` debug (`versionCode 1`), last updated 2026-11-18  
**Child:** Realme RMX2161, Android 12 / API 31, `ankit1@gmail.com`  
**Parent:** Pixel 9a emulator, Android 17 / API 37, `ankit@gmail.com`  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Final verdict

# D. FAILED — CRITICAL FUNCTIONAL ISSUE (P1)

The authentication and existing parent/child relationship are intact, and both apps run without crashing. However, the core two-device objective — the parent seeing the current state of the running child device — **fails**:

- The child is running with a foreground `GuardianService`.
- The child has an established TLS connection to Supabase.
- The parent still shows the child **Offline**, last seen **Nov 13, 2026 5:23 PM (186 h ago)**.
- The child Home shows **“Updated 2 d ago.”**

This is a confirmed P1 synchronization/monitoring failure. Under the verdict rules, a confirmed P1 prevents a pass.

The build/install phase was also not executable because the environment refused the APK build, so the result is additionally incomplete for a fresh HEAD artifact.

---

## 2. Result counts

| Label | Count | Notes |
|---|---:|---|
| PASS | 33 | Environment, static tests, sessions, roles, family, UI rendering, service, stability, safety |
| FAIL | 4 | Live sync, duplicate revoked row, policy-version inconsistency, permission warning |
| BLOCKED | 8 | Build/install, Kotlin tests, child UI interaction, Settings/control screens, location |
| NOT TESTED | 6 | Fresh password login, usage/screen time, alert generation, network loss, lock screen, Realtime delivery |
| NOT MEASURED | 2 | Cold/warm start, battery drain |
| NOT IMPLEMENTED | 0 | In the tested scope (Device Owner suspension is implemented but hardware-blocked) |

Additional environment/lifecycle rows are recorded in reports 01–10.

---

## 3. What passed

- FVM Flutter 3.44.6 / Dart 3.12.2 toolchain.
- `flutter pub get`, `flutter analyze` (0 issues), Flutter **493/493**, Deno **209/209**.
- Both devices online; correct dual-role package; no flavors or separate child package.
- Existing sessions on both devices; parent and child shells resolve correctly.
- Family `demo` intact: owner `ankit`, child `ankit1` active, linked device `realme RMX2161`.
- No pairing, unlink, revoke, role, credential or account changes.
- Child `GuardianService` foreground with visible notification.
- Device Owner absence is reported honestly; no false “apps blocked” claim.
- Parent Dashboard, Devices, Device detail, Family and Alerts render without crash, overflow or infinite spinner.
- No app crash or ANR during the test.
- Logs collected and redacted; no secrets or tokens written into reports.

---

## 4. What failed

| ID | Priority | Failure |
|---|---|---|
| E2E-001 | **P1** | Child running and connected, but parent shows Offline and days-old data. Most likely device-credential desync after the prior debug install. |
| E2E-002 | P2 | Revoked device still listed as a current device (duplicate `realme RMX2161` rows). |
| E2E-003 | P2 | Policy version shown as v2 on Devices list and v4 on detail/dashboard for the same device. |
| E2E-004 | P2 | Child location warning says a permission is missing although Android reports fine/background location granted. |
| E2E-005 | P2 | Child data stays “Updated 2 d ago” with no visible sync-failure reason. |

No P0 security/data-exposure issue was found.

---

## 5. What is blocked and must not be counted as a pass

- Fresh APK build and install on both devices.
- Kotlin JVM unit tests (Gradle mixed-drive failure).
- Child Rules/Settings and parent Settings screens (UI interaction policy).
- Parent Location, Screen time and App restrictions screens.
- Location service start/verification.
- Device Owner suspension and hardware enforcement.
- Deliberate network-loss/reconnect test.
- Lock-screen lifecycle.

---

## 6. Recommended next remediation phase

1. **Repair device synchronization first.** Use an owner-approved device-recovery/credential-preserving procedure, then confirm a fresh `last_seen` on the parent and a recent child “Updated” value. Do not pair, unlink or reset the family.
2. **Surface the real sync failure.** Child UI should distinguish “device credential rejected” from “request list timed out.” Parent device detail should show the last successful heartbeat and the safe failure reason.
3. **Fix the P2 consistency defects.** Filter revoked devices from current lists; unify policy version across list/detail/dashboard; correct the API-31 permission warning.
4. **Build a fresh artifact with FVM** using the documented config, record SHA-256, install with `adb install -r`, and re-run this entire matrix. The current evidence applies to the 2026-11-18 installed build, not HEAD.
5. **Then run the untested coverage**: usage/screen time, alert generation, network loss/reconnect, lock-screen lifecycle, Realtime delivery, remote assistance, safe zones, and Device Owner enforcement on a provisioned device.
6. **Do not treat the family relationship as the blocker.** It is intact; the blocker is device-authenticated telemetry/synchronization.

---

## 7. Executive summary

This test did **not** pass. The two-device relationship and authentication are healthy, and the app is honest about missing Device Owner enforcement. But the most important real-world behavior — a parent seeing a live child — is broken on the currently installed build: the child is online and running, while the parent shows it offline with data from eight days earlier. That P1 must be resolved and re-verified on a fresh build before this app can be considered two-device functional.
