# Phase 2.3 — Android Native Permission Reconciliation & Architecture Review

**Document ID:** `HAVEN-GOV-PHASE2-3-ANDR`  
**Phase:** Phase 2.3 — Independent Adversarial Governance Closure & Backend Isolation Verification  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Independent Native Android Architecture & Security Verification  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Objective of the Native Android Audit

HAVEN Parent Control Child Mode operates as an Android device management daemon. Complete verification of the manual test suite requires interacting with high-privilege Android operating system APIs.

This adversarial audit evaluates:
1. True declarations in `android/app/src/main/AndroidManifest.xml`.
2. Actual native Kotlin service implementations in `android/app/src/main/kotlin/`.
3. Erroneous claims in Phase 2.2 regarding phantom services (`HavenAccessibilityService`, `HavenNotificationListenerService`).
4. Strict categorization across the Android Permission Privilege Taxonomy (Manifest, Runtime, Special App Access, Device Admin, Device Owner).

---

## 2. Refuting Phase 2.2 Phantom Services: Factual Corrections

Phase 2.2 Deliverable 10 asserted that two specific services required owner authorization:
- `HavenAccessibilityService` (claimed for `TC-C02`, `TC-EXP-19`, `TC-EXP-20`, `TC-EXP-21`, `TC-EXP-22`).
- `HavenNotificationListenerService` (claimed for `TC-C06`, `TC-EXP-29`, `TC-EXP-30`).

### 2.1 Adversarial Codebase Evidence
1. **Accessibility Service is Completely Absent (`M08`)**:
   - Grep search for `AccessibilityService` across all `.kt`, `.java`, and `.xml` files in `android/` returned **zero matches**.
   - Pre-Testing Functional Audit Deliverable 10 explicitly catalogs **`M08` (Accessibility Enforcement)** as an **Absent Capability** (*"Zero AccessibilityService declared or implemented in repository"*).
   - In HAVEN, app usage tracking is performed via `UsageStatsManager` (`UsageReporter.kt`), not via an Accessibility Service.
2. **Notification Listener Service is Completely Absent**:
   - Grep search for `NotificationListenerService` across `android/` returned **zero matches**.
   - No `NotificationListenerService` is declared in `AndroidManifest.xml`.
3. **Device Admin Receiver Actual Class Name**:
   - The actual receiver declared in `AndroidManifest.xml:78` and implemented in Kotlin is **`ParentControlDeviceAdminReceiver`**, not `HavenDeviceAdminReceiver`.
4. **Phantom Test IDs `TC-C01`–`TC-C08`**:
   - Phase 2.2 invented test identifiers `TC-C01` through `TC-C08`. These do not exist in the master test suite.

---

## 3. Authoritative Android Permission Privilege Taxonomy

Android permissions operate at fundamentally different privilege boundaries. Grouping them into a single generic "permission" category obscures operational risk:

```
+--------------------------------------------------------------------------------------------------+
|                            ANDROID PERMISSION PRIVILEGE TAXONOMY                                 |
+--------------------------------------------------------------------------------------------------+
|  [ PRIVILEGE 1: MANIFEST-ONLY ]        INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, BOOT_COMPLETED    |
|  [ PRIVILEGE 2: RUNTIME POPUP ]        CAMERA, RECORD_AUDIO, ACCESS_FINE_LOCATION, POST_NOTIF    |
|  [ PRIVILEGE 3: BACKGROUND LOCATION ]  ACCESS_BACKGROUND_LOCATION (Multi-step OS Settings flow)  |
|  [ PRIVILEGE 4: SPECIAL APP ACCESS ]   PACKAGE_USAGE_STATS (System Settings -> Usage Access)     |
|  [ PRIVILEGE 5: DEVICE ADMINISTRATOR ] BIND_DEVICE_ADMIN (System Settings -> Device Admin Apps)   |
|  [ PRIVILEGE 6: SYSTEM OVERLAY WINDOW] SYSTEM_ALERT_WINDOW (Display over other apps toggle)      |
|  [ PRIVILEGE 7: DEVICE OWNER (MDM) ]   setPackagesSuspended() (ADB shell dpm command required)   |
+--------------------------------------------------------------------------------------------------+
```

---

## 4. Reconciled Android Native Component & Permission Table

The following table documents every native permission, service, and receiver genuinely present in the HAVEN repository:

| Permission / Subsystem | Android API / Manifest Declaration | Native Kotlin Implementation | Privilege Tier | User Flow Required to Grant | Revocation Behavior | Mapped Test Cases | Dedicated HW Required? |
| :--- | :--- | :--- | :---: | :--- | :--- | :--- | :---: |
| **Usage Statistics** | `android.permission.PACKAGE_USAGE_STATS` | `UsageReporter.kt`, `NativePermissions.kt:33` | Special App Access | User redirected to OS Settings -> Usage Access -> Toggle ON. | Usage reporting freezes; parent sees stale data. | `TC-USE02`, `TC-EXP-27`, `TC-EXP-28` | **YES** |
| **Device Administrator** | `android.permission.BIND_DEVICE_ADMIN` | `ParentControlDeviceAdminReceiver.kt` | Device Admin | System prompt to activate Device Admin for Haven. | Triggers tamper alert to parent; allows app uninstall. | `TC-SET05`, `TC-EXP-55` | **YES** |
| **Fine GPS Location** | `Manifest.permission.ACCESS_FINE_LOCATION` | `LocationTrackingService.kt`, `NativePermissions.kt:14` | Runtime Permission | Standard OS runtime dialog: "While using the app". | GPS coordinates cease; map displays last known location. | `TC-LOC01`, `TC-EXP-37` | **YES** |
| **Background Location** | `Manifest.permission.ACCESS_BACKGROUND_LOCATION` | `LocationTrackingService.kt`, `NativePermissions.kt:20` | Background Permission | Multi-step OS flow: Settings -> Location -> "Allow all the time". | Background tracking ceases when app is minimized. | `TC-LOC04`, `TC-EXP-37`, `TC-EXP-53` | **YES** |
| **Hardware Camera** | `Manifest.permission.CAMERA` | `NativePermissions.kt:10`, QR scanner | Runtime Permission | Standard OS runtime dialog. | Cannot scan pairing QR code; must use manual code. | `TC-FAM01`, `TC-EXP-07` | **YES** (Physical camera) |
| **Hardware Microphone** | `Manifest.permission.RECORD_AUDIO` | `AudioAssistanceService.kt`, `NativePermissions.kt:12` | Runtime Permission | Standard OS runtime dialog. | WebRTC audio streaming fails silently or throws error. | `TC-REM01`, `TC-EXP-44`, `TC-EXP-45` | **YES** (Physical mic) |
| **Post Notifications** | `Manifest.permission.POST_NOTIFICATIONS` | `NativePermissions.kt:28` (API 33+) | Runtime Permission | Standard OS runtime dialog on Android 13+. | Push alerts not visible in notification shade. | `TC-LOC10`, `TC-EXP-38`, `TC-EXP-39` | Optional (Any device) |
| **Foreground Services** | `FOREGROUND_SERVICE_LOCATION`, `DATA_SYNC`, `MICROPHONE` | `GuardianService.kt`, `AudioAssistanceService.kt` | Manifest Permission | Auto-granted on install. Requires ongoing notification. | Service killed by Android OS battery manager if revoked. | `TC-MON04`, `TC-EXP-28`, `TC-EXP-37` | Optional |
| **Boot Completed** | `android.permission.RECEIVE_BOOT_COMPLETED` | `BootReceiver.kt` | Manifest Permission | Auto-granted on install. | Daemon does not auto-restart upon child device reboot. | `TC-SYS02`, `TC-EXP-58` | **YES** (Physical reboot) |
| **Device Owner (MDM)** | `dpm set-device-owner` | `EnforcementMode.kt`, `PolicyApplier.kt` | Device Owner (Root) | Requires factory reset or unmanaged device via ADB command. | Sideloaded app cannot suspend packages without this. | `TC-APP07`, `TC-EXP-31` | **YES** (Dedicated test bench) |

---

## 5. Native Testing Hardware Safeguards

1. **Daily-Driver Phone Protection**: Tests involving Device Admin activation (`TC-SET05`) and revocation (`TC-EXP-55`) must **NEVER be run on personal smartphones**. Revoking Device Admin can cause OS state locks.
2. **Device Owner Provisioning**: Package suspension tests (`TC-APP07`, `TC-EXP-31`) require a dedicated Android handset provisioned via `adb shell dpm set-device-owner com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`. Standard sideloaded installs will fail.
