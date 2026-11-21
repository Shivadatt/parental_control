# 11 — Bug and Risk Register

**Date:** 2026-11-21  
**Build under test:** installed `1.0.0` debug (`versionCode 1`), 2026-11-18  
**Devices:** Child = Realme RMX2161 (Android 12/API 31); Parent = Pixel 9a emulator (Android 17/API 37)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## E2E-001 — Child is running but parent sees it Offline with days-old data (P1)

| Field | Detail |
|---|---|
| **Device / role** | Child Realme RMX2161; Parent Pixel emulator |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Steps to reproduce** | 1. Launch the child app and confirm the child shell for family `demo`.<br>2. Confirm `GuardianService` is foreground (`dumpsys activity services`).<br>3. Open the parent app and refresh Dashboard/Devices.<br>4. Compare `last_seen` and child “Updated …” text. |
| **Expected** | Child shown online within the heartbeat window; recent `last_seen`; fresh child data. |
| **Actual** | Parent shows `realme RMX2161` **Offline**, last seen **Nov 13, 2026 5:23 PM (186 h)**. Child Home says **“Updated 2 d ago.”** Child has an ESTABLISHED TLS connection and its guardian service has run for ~37 h. |
| **Evidence** | Parent Dashboard/Devices/Device detail dumps; child Home dump; `dumpsys activity services`; `/proc/<pid>/net/tcp`; device install timestamps. |
| **Source** | `android/.../GuardianService.kt`, `android/.../SecureStore.kt`, `lib/data/repositories/supabase_device_repository.dart`, `supabase/functions/device-telemetry/index.ts` |
| **Root cause** | Most likely device-credential desynchronization after the prior debug reinstall (documented E-16 / credential desync). User-session reads still work; device-authenticated heartbeat/telemetry is rejected. Server response was not captured (would require credentials/backend access). |
| **Remediation** | Owner-approved device recovery or a credential-preserving update path. Add a visible child “sync failing” state with the safe error reason, and a parent-side “last successful sync / credential invalid” diagnostic. Re-run two-device sync after repair. |
| **Reproducible** | Yes, consistently across refreshes and relaunches. |
| **Status** | OPEN — not fixed, not worked around. |

---

## E2E-002 — Revoked device is still listed as a current device (P2)

| Field | Detail |
|---|---|
| **Device / role** | Parent |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Steps** | Open Dashboard or Devices tab with the existing family. |
| **Expected** | Only the active/current device row is shown; revoked devices appear only in history/recovery views. |
| **Actual** | Two rows for `realme RMX2161`: one **Revoked**, one **Offline**, both presented as current devices. |
| **Evidence** | Parent Dashboard and Devices dumps. |
| **Source** | `lib/features/devices/devices_controller.dart`, `lib/features/dashboard/dashboard_controller.dart`, `lib/data/repositories/supabase_device_repository.dart`, `supabase/functions/family-admin/index.ts` |
| **Root cause** | Current-device queries do not filter the revoked row, or the card list merges active and revoked records without a status gate. |
| **Remediation** | Filter `status != revoked` from current-device lists; show revoked devices only under an explicit history/recovery section. Add a widget test for the mixed list. |
| **Reproducible** | Yes. |
| **Status** | REPORTED as BUG-040; independently observed again. |

---

## E2E-003 — Policy version differs between Devices list and Device detail (P2)

| Field | Detail |
|---|---|
| **Device / role** | Parent |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Steps** | Open Devices tab, note the policy label on the Offline device; open the device detail. |
| **Expected** | Both screens show the same saved/acknowledged policy version. |
| **Actual** | Devices list shows **Policy v2**; Device detail and Dashboard show **Policy v4 · Waiting for device**. |
| **Evidence** | Devices tab dump: “Policy v2”; Device detail dump: “Version 4”; Dashboard dump: “Policy v4 · Waiting for device”. |
| **Source** | `lib/features/devices/parent_devices_tab.dart`, `lib/features/devices/device_detail_page.dart`, `lib/features/devices/device_presentation.dart`, `lib/features/devices/devices_controller.dart` |
| **Root cause** | List and detail derive the policy version from different fields/cached records (not established by code trace in this pass). |
| **Remediation** | Use a single latest-policy projection for all device surfaces. Add a regression test with a v2 row and a v4 latest policy. |
| **Reproducible** | Yes, on the same refresh cycle. |
| **Status** | OPEN — not fixed. |

---

## E2E-004 — Location warning contradicts Android’s granted permission state (P2)

| Field | Detail |
|---|---|
| **Device / role** | Child |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Steps** | Open child Home with location sharing enabled; read the location card; compare with Android permission state. |
| **Expected** | Warning only when a required permission is actually missing; no warning when fine/background location is granted. |
| **Actual** | UI says “Android location or notification permission is missing”, while `dumpsys package` reports fine location and background location **granted** and the device is API 31 (source treats notifications as granted below API 33). `LocationTrackingService` is not running. |
| **Evidence** | Child Home dump; `dumpsys package`; `appops get`; `dumpsys activity services`; `NativePermissions.kt:31-34`; `child_shell_controller.dart:641-647`. |
| **Source** | `NativePermissions.kt`, `NativeBridge.kt`, `lib/features/child/controllers/child_shell_controller.dart` |
| **Root cause** | Not established. Possible stale capability snapshot, service-start failure mapped to the permission message, or installed-build/source mismatch. |
| **Remediation** | Report the actual start failure separately from permission state; read capabilities immediately before the check; add an API-31 device test. |
| **Reproducible** | Observed repeatedly on the current child session. |
| **Status** | OPEN — not fixed, not worked around. |

---

## E2E-005 — Child data remains stale with no visible sync failure reason (P2)

| Field | Detail |
|---|---|
| **Device / role** | Child |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Steps** | Launch child app and leave it running; observe Home. |
| **Expected** | Automatic refresh or an explicit “sync failed because …” state with retry. |
| **Actual** | Home shows “Updated 2 d ago” and a location warning; no device-credential/sync error is surfaced. A transient “request timed out” appeared once, then cleared. |
| **Evidence** | Child Home dumps at 11:48 and 11:56. |
| **Source** | `lib/features/child/controllers/child_shell_controller.dart`, `lib/features/child/tabs/child_home_tab.dart` |
| **Root cause** | Same underlying sync/credential failure as E2E-001; the UI does not distinguish “read cache” from “device upload rejected.” |
| **Remediation** | Surface heartbeat/telemetry failure separately from request-list errors; retry with backoff; keep stale labels visible. |
| **Reproducible** | Yes. |
| **Status** | OPEN — symptom of E2E-001. |

---

## E2E-006 — Parent launch jank on emulator (P3)

| Field | Detail |
|---|---|
| **Device / role** | Parent Pixel emulator |
| **Build** | `1.0.0` debug, 2026-11-18 |
| **Observation** | `Choreographer: Skipped 139 frames!` during launch. |
| **Impact** | Visible startup jank on the debug emulator; production impact unknown. |
| **Source** | Flutter startup / debug build. |
| **Remediation** | Profile a release build on real hardware before treating as a defect. |
| **Reproducible** | Not re-measured. |
| **Status** | OPEN (observation only). |

---

## E2E-007 — Pixel emulator OS differs from the test brief (P4, environment)

| Field | Detail |
|---|---|
| **Expected** | Android 15 / API 35 |
| **Actual** | Android 17 / API 37 |
| **Impact** | Android-version-specific behavior may differ from the intended test matrix. Device identity is otherwise unambiguous. |
| **Remediation** | Record the actual API level in evidence; repeat on an API 35 image if strict version parity is required. |
| **Status** | ACCEPTED environment discrepancy. |

---

## E2E-008 — Fresh build and install could not be executed (P2, process risk)

| Field | Detail |
|---|---|
| **Steps** | Attempt the documented FVM debug build with `.tools/live_config.env`, then install with `adb install -r`. |
| **Expected** | Fresh Child and Parent artifacts installed without clearing data. |
| **Actual** | Execution policy refused the build (secret-bearing config) and the build-script wrapper. No APK was produced; no install occurred. |
| **Impact** | Findings apply to the installed 2026-11-18 build, not to HEAD `bbd3c21`. |
| **Remediation** | Owner-run build using the documented FVM command, or an environment that permits the validated build wrapper. Record artifact SHA-256 and re-run this test set. |
| **Status** | BLOCKED — not an app defect. |

---

## 9. Risk summary

| Priority | Count | Items |
|---|---:|---|
| P1 | 1 | E2E-001 |
| P2 | 5 | E2E-002, E2E-003, E2E-004, E2E-005, E2E-008 |
| P3 | 1 | E2E-006 |
| P4 | 1 | E2E-007 |

No P0 security or data-exposure defect was observed. No credentials were exposed, changed or reset.
