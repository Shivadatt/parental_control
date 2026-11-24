# Phase 2.4 — Android Native Architecture & Component Reconciliation

**Document ID:** `HAVEN-GOV-PHASE2-4-ANDR`  
**Phase:** Phase 2.4 — Final Evidence Reconciliation & Governance Correction Audit  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Independent Static Native Android Architecture Verification  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Objective of the Native Android Reconciliation

Phase 2.2 claimed that two specific native services required owner permission authorization:
- `HavenAccessibilityService`
- `HavenNotificationListenerService`

This independent audit performs a forensic inspection of `android/` and `AndroidManifest.xml` to reconcile claimed components against actual compiled classes.

---

## 2. Component-by-Component Reconciliation Matrix

| Component Name | Class Exists in `android/`? | Manifest Declaration? | Native Implementation Status | Related Test Case IDs | Final Reconciliation Status | Forensic Evidence |
| :--- | :---: | :---: | :--- | :--- | :---: | :--- |
| **`HavenAccessibilityService`** | **NO** | **NO** | Completely unbuilt; absent from repository | None (Phase 2.2 cited `TC-C02`) | **NON-EXISTENT (PHANTOM NAME / ABSENT CAPABILITY M08)** | Grep returned 0 matches; `M08` confirms absent |
| **`HavenNotificationListenerService`**| **NO** | **NO** | Completely unbuilt; absent from repository | None (Phase 2.2 cited `TC-C06`) | **NON-EXISTENT (PHANTOM NAME / ABSENT CAPABILITY)** | Grep returned 0 matches |
| **`ParentControlDeviceAdminReceiver`**| **YES** | **YES** | Fully implemented (`onEnabled`, `onDisabled`) | `TC-SET05`, `TC-EXP-55` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `AndroidManifest.xml:78`, `ParentControlDeviceAdminReceiver.kt` |
| **`GuardianService`** | **YES** | **YES** | Fully implemented (`foregroundServiceType="dataSync"`) | `TC-MON04`, `TC-EXP-28` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `AndroidManifest.xml:66`, `GuardianService.kt` |
| **`LocationTrackingService`** | **YES** | **YES** | Fully implemented (`foregroundServiceType="location"`) | `TC-LOC01`, `TC-EXP-37` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `AndroidManifest.xml:70`, `LocationTrackingService.kt` |
| **`AudioAssistanceService`** | **YES** | **YES** | Fully implemented (`foregroundServiceType="microphone"`) | `TC-REM01`, `TC-EXP-44` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `AndroidManifest.xml:74`, `AudioAssistanceService.kt` |
| **`BootReceiver`** | **YES** | **YES** | Fully implemented (`action BOOT_COMPLETED`) | `TC-SYS02`, `TC-EXP-58` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `AndroidManifest.xml:88`, `BootReceiver.kt` |
| **`UsageReporter`** | **YES** | N/A | Fully implemented (queries `UsageStatsManager`) | `TC-USE02`, `TC-EXP-28` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `UsageReporter.kt:35` |
| **`NativePermissions`** | **YES** | N/A | Fully implemented (permission snapshot bridge) | `TC-SET04`, `TC-EXP-52` | **FULLY IMPLEMENTED SOURCE VERIFIED** | `NativePermissions.kt:10–55` |
| **`PolicyApplier`** | **YES** | N/A | Implemented (enforces daily quotas / bedtime) | `TC-APP07`, `TC-EXP-29` | **PARTIALLY IMPLEMENTED (DO Limit)** | `PolicyApplier.kt:140` |

---

## 3. Forensic Analysis of Phantom Components

### 3.1 The Truth About Accessibility Enforcement (`M08`)
- Phase 2.2 claimed that `HavenAccessibilityService` controls app blocking.
- **Source Truth**: In HAVEN, app usage tracking and restrictions do **not** use Android Accessibility Services. Instead, usage statistics are queried via `UsageStatsManager` (`UsageReporter.kt`), and application suspension is attempted via `DevicePolicyManager.setPackagesSuspended()` (`PolicyApplier.kt:140`).
- Pre-Testing Functional Audit Deliverable 10 explicitly confirmed that **`M08` (Accessibility Service Enforcement) is completely absent from the codebase**.

### 3.2 The Device Admin Receiver Class Name
- Phase 2.2 cited `HavenDeviceAdminReceiver`.
- **Source Truth**: The actual receiver declared in `AndroidManifest.xml:78` is **`com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver`**.

---

## 4. Reconciled Android System Permission Register

The authentic native Android subsystems requiring Owner authorization on physical test hardware are:

```
+--------------------------------------------------------------------------------------------------+
|                            RECONCILED NATIVE PERMISSION SUBSYSTEMS                               |
+--------------------------------------------------------------------------------------------------+
| 1. PACKAGE_USAGE_STATS               --> Special App Access (Usage Access toggle in Settings)    |
| 2. BIND_DEVICE_ADMIN                 --> ParentControlDeviceAdminReceiver (Device Admin toggle)  |
| 3. ACCESS_BACKGROUND_LOCATION        --> Multi-step OS flow ("Allow all the time")               |
| 4. ACCESS_FINE_LOCATION              --> Runtime popup ("While using the app")                  |
| 5. RECORD_AUDIO                      --> Runtime popup (Required for AudioAssistanceService)     |
| 6. CAMERA                            --> Runtime popup (Required for QR pairing scan)            |
| 7. POST_NOTIFICATIONS                --> Runtime popup on Android 13+ (API 33+)                  |
| 8. RECEIVE_BOOT_COMPLETED            --> Manifest permission (BootReceiver daemon restart)       |
| 9. FOREGROUND_SERVICES               --> Manifest permissions (dataSync, location, microphone)   |
+--------------------------------------------------------------------------------------------------+
```
