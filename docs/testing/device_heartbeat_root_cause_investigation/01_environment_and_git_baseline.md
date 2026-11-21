# 01 — Environment and Git Baseline

**Phase:** 2 — Device Authentication & Heartbeat Root Cause Investigation  
**Mode:** strictly read-only diagnostic  
**Date:** 2026-11-21 (IST)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Repository baseline

| Item | Value |
|---|---|
| Workspace | `D:\parentcontrol_app` |
| Branch | `main` |
| HEAD | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` |
| HEAD date | 2026-11-20 |
| Working tree | Clean except the untracked `docs/testing/two_device_end_to_end_testing/` report set from the preceding phase |
| Source modifications this phase | None |
| Builds / installs this phase | None |
| Database / Edge Function changes this phase | None |

The untracked E2E report directory is the only working-tree difference and is expected from Phase 1.

---

## 2. Toolchain

| Component | Observed | Label |
|---|---|---|
| FVM | 4.3.2 | PASS |
| Flutter | 3.44.6 (FVM) | PASS |
| Dart | 3.12.2 | PASS |
| ADB | Platform-tools; parent emulator reachable | PASS |
| Physical child device access | Earlier read-only inspection succeeded; later commands were refused by the execution policy | BLOCKED for new inspection |

No Flutter build or `pub get` was run in this phase.

---

## 3. Actual device properties (read from Android, not assumed)

| Property | Child | Parent |
|---|---|---|
| Assigned role | CHILD | PARENT |
| Model | Realme RMX2161 | `sdk_gphone64_x86_64` (Pixel 9a emulator) |
| Serial | `5HXWRGQ4IFU8WS4T` | `emulator-5554` |
| Android release | 12 | **17** |
| API level | 31 | **37** |
| Expected by brief | Android 12 / API 31 | Android 15 / API 35 |

The parent emulator’s Android 17/API 37 state is a recorded environment discrepancy. It was not changed.

---

## 4. Installed application state

| Property | Child | Parent |
|---|---|---|
| Package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| Version name | `1.0.0` | `1.0.0` |
| Version code | `1` | `1` |
| Debuggable | Yes | Yes |
| minSdk / targetSdk | 24 / 36 | 24 / 36 |
| First install | 2026-11-17 12:44:28 | 2026-11-13 15:05:52 |
| Last update | 2026-11-18 09:46:33 | 2026-11-18 13:55:28 |
| Android backup | disabled (`android:allowBackup="false"`) | disabled |

Both apps were already installed and signed in. No reinstall or data clear occurred.

---

## 5. Documentation and evidence reviewed

- `docs/testing/two_device_end_to_end_testing/01`–`12`
- `docs/verification-report.md`
- `docs/bug-report.md`
- `docs/testing/phase_3_0_*`
- `docs/testing/PHASE_2_2_CROSS_DEVICE_FUNCTIONAL_QA_REPORT.md`
- `docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md`

Runtime facts reused from the immediately preceding E2E phase:

- Child `GuardianService` foreground, notification `4101`, alive ~37 hours.
- Child app had an established TCP connection to the Supabase HTTPS endpoint.
- Parent showed the active child row **Offline**, last seen 2026-11-13 5:23 PM (186 h).
- Child Home showed **“Updated 2 d ago”**.
- Parent Devices tab said “Updated Just now” while the device row remained old.

---

## 6. Source files inspected

Credential lifecycle:

- `android/.../SecureStore.kt`
- `android/.../NativeBridge.kt`
- `android/.../DeviceHttpClient.kt`
- `lib/data/services/device_admin_service.dart`
- `lib/data/models/device.dart`
- `lib/data/repositories/supabase_device_repository.dart`
- `lib/features/child/controllers/child_shell_controller.dart`
- `lib/features/child/controllers/child_enrollment_controller.dart`

Heartbeat:

- `android/.../GuardianService.kt`
- `supabase/functions/device-telemetry/index.ts`
- `supabase/functions/_shared/auth.ts`

Parent status:

- `lib/features/devices/devices_controller.dart`
- `lib/features/dashboard/dashboard_controller.dart`
- `lib/features/devices/device_presentation.dart`
- `lib/features/devices/parent_devices_tab.dart`
- `lib/features/dashboard/parent_dashboard_tab.dart`

Related P2:

- `lib/features/devices/device_detail_controller.dart`
- `android/.../NativePermissions.kt`
- `lib/features/devices/device_presentation.dart`

---

## 7. Execution-policy limitation

In this phase the execution policy refused further physical-device ping/log/notification inspection (“beyond source-only diagnostics”). No attempt was made to bypass it.

Consequences:

- Runtime facts come from the preceding E2E phase and from this phase’s successful read-only package/device queries.
- The exact HTTP rejection body for a heartbeat was **not** captured.
- The encrypted `guardian_last_error` value was **not** read (correctly, because secure prefs may contain credentials).

All conclusions distinguish source-derived facts from runtime observations.

---

## 8. Baseline verdict

**PASS** — repository, device identities, installed build metadata and source paths are established.  
**BLOCKED** — new physical-device log/network inspection in this phase.  
No state was modified.
