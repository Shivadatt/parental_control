# 09 — Testing Prerequisites and Environment Requirements

**Document ID:** `HAVEN-INV-009`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Scope:** Test Harness Specifications, Account Governance & Environment Quarantine  

---

## 1. Executive Summary

This document establishes the environment specifications, account state requirements, device hardware constraints, and safety boundaries required before any manual or automated QA execution can take place. 

To protect the integrity of active QA accounts, family structures, and hardware-bound credentials, **strict data preservation rules** are enforced.

---

## 2. Reference Device Inventory & Hardware Constraints

The following devices represent the established historical QA hardware reference targets:

| Device Role | Hardware Model | Serial / Identifier | Android OS Version | Display Geometry | Native Privilege Ceiling |
|---|---|---|---|---|---|
| **Parent Device** | Google Pixel 9 Emulator | `emulator-5554` | Android 14 (API 34) | 1080×2424 px, 420 dpi | Standard User (Parent App) |
| **Child Device** | Realme RMX2161 (Realme 7) | `5HXWRGQ4IFU8WS4T` | Android 12 (API 31) | 1080×2400 px, 480 dpi | Standard Install $\to$ **Device Admin Only** |

### Critical Safety Quarantine Rule:
- **Zero Live Device Interaction**: `emulator-5554` and `5HXWRGQ4IFU8WS4T` are **STRICTLY QUARANTINED** during this pre-testing audit phase.
- No ADB commands (`adb shell`, `adb install`, `adb push`, `adb forward`) may be executed.
- No app data or cache may be cleared on these physical devices.

---

## 3. Account State & Environment Requirements Matrix

| Testing Domain | Required Account State | Required Device State | Network / Backend Prerequisites | Disposable Fixture Required? | Mutation Risk to Existing Data |
|---|---|---|---|---|---|
| **Group 1: Basic App & Navigation** | No account required (Logged out) | Any Android handset / emulator | Offline or Online | No | None (Pure local UI rendering) |
| **Group 2: Authentication & Accounts** | Disposable test email (e.g. `qa_test_parent_01@example.com`) | Clean app storage | Supabase Auth online; SMTP for verification | **YES** (Must use fresh test accounts) | Low (Do not use production accounts) |
| **Group 3: Parent-Child Connection** | 1 Parent account + 1 Child account | 2 active devices (or 1 device + 1 emulator) | Supabase Edge `pairing` & `auth-bootstrap` | **YES** (Requires disposable family) | **CRITICAL**: Never unpair or re-pair existing QA family! |
| **Group 4: Parent Functionalities** | Enrolled Parent account with linked child | Parent handset / emulator | `devices`, `device_policies`, `usage_daily` | Staging database fixture | Medium (Mutates policy version) |
| **Group 5: Child Functionalities** | Enrolled Child account with linked parent | Child handset (Realme RMX2161) | `GuardianService` running; active network | Child device fixture | Medium (Generates telemetry data) |
| **Group 6: Android Native Behavior** | Child device enrolled in family | Physical Android 12+ handset | `DevicePolicyManager` active; Usage Access granted | Physical hardware | High (Prompts system settings) |
| **Group 7: Backend & Data Sync** | Parent + Child paired | Both devices online | Supabase Edge Functions & Database active | Ephemeral staging DB | High (Mutates command queues) |
| **Group 8: Security & Failure Scenarios** | Multiple test accounts (Cross-family) | Multiple device contexts | Network simulation proxy (Charles / mitmproxy) | **YES** (Isolated staging project) | **CRITICAL**: High risk of credential corruption |

---

## 4. Hardware Permission Requirements by Role

### 4.1 Parent Handset Permissions
1. **Camera (`android.permission.CAMERA`)**: Required only for scanning Child pairing QR code (`FAM01`). Fallback to manual 6-digit linking code (`FAM02`) is fully implemented if camera is denied.
2. **Microphone (`android.permission.RECORD_AUDIO`)**: Required only during live Remote Assistance WebRTC calls (`REM03`).
3. **Internet & Network State**: Mandatory for all Supabase API and realtime queries.

### 4.2 Child Handset Permissions (Critical Enforcement Tier)
1. **Notifications (`POST_NOTIFICATIONS`)**: Mandatory on Android 13+ to maintain persistent `GuardianService` notification in status bar.
2. **Fine & Background Location (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`)**: Mandatory for continuous location tracking (`LOC04`) and safe zone geofencing (`LOC06`).
3. **Usage Access (`PACKAGE_USAGE_STATS`)**: Mandatory system authorization for tracking daily screen time and individual app launch durations (`USE04`).
4. **Device Administrator (`DeviceAdminReceiver`)**: Mandatory system authorization to lock device, prevent basic uninstallation, and monitor policy tampering (`SET05`, `SET08`).
5. **Camera & Microphone**: Required for incoming WebRTC live calls (`REM03`) and self-test sheet (`CHD05`).

---

## 5. Disposable Test Fixture Architecture

To ensure complete non-destructive manual testing in future phases, the following disposable test harness must be provisioned:

```
+--------------------------------------------------------------------------------------------------+
|                                DISPOSABLE TESTING ARCHITECTURE                                   |
|                                                                                                  |
|  [ DISPOSABLE PARENT CONTEXT ]                           [ DISPOSABLE CHILD CONTEXT ]            |
|  - Account: qa_parent_disposable@haven.test              - Account: qa_child_disposable@haven.test|
|  - Role: 'parent'                                        - Role: 'child'                         |
|  - Device: Secondary Emulator (Port 5556)                - Device: Secondary Test Handset        |
|                                                                                                  |
|                                                |                                                 |
|                                                v                                                 |
|  +--------------------------------------------------------------------------------------------+  |
|  | DISPOSABLE SUPABASE PROJECT / LOCAL DOCKER CONTAINER                                       |  |
|  | - Database: Isolated schema with clean seed data                                           |  |
|  | - Live Config: Dedicated test environment (.env.staging)                                   |  |
|  | - Preservation Guarantee: Zero impact on production tables or live QA accounts            |  |
|  +--------------------------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------------------------+
```

### Mandatory Testing Preconditions Checklist:
- [ ] Fresh, disposable Parent account created (zero reliance on existing owner sessions).
- [ ] Fresh, disposable Child account created.
- [ ] Staging database provisioned with fresh migrations applied.
- [ ] Reference devices (`emulator-5554` and `5HXWRGQ4IFU8WS4T`) remain untouched until explicitly approved.
- [ ] Production `.tools/live_config.env` remains 100% untouched and unread.
