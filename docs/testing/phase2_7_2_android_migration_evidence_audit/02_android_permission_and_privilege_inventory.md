# HAVEN PARENT CONTROL — PHASE 2.7.2 DELIVERABLE 02
# ANDROID PERMISSION, PRIVILEGE & CAPABILITY INVENTORY

**Document ID:** `HAVEN-GOV-PHASE2-7-2-PERM-INV`  
**Phase:** Phase 2.7.2 — Android Permission Capability & Migration Dependency Final Evidence Audit  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Source Evidence Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Runtime Execution:** PROHIBITED  
**Phase 3 Authorization:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Scope

This report provides the exhaustive, source-verified inventory of every Android permission, privileged capability, native service, and operating system interface implemented or declared in HAVEN Parent Control. 

Previous reviews established that several planned capabilities were conflated with declared permissions. This audit establishes the exact boundaries between:
1. Normal install-time permissions.
2. Dangerous runtime permissions.
3. Special app access permissions (Usage Access).
4. Device Administrator privileges.
5. Device Owner provisioning requirements.
6. Native foreground services.
7. Completely absent capabilities.

---

## 2. Complete Android Manifest & Runtime Permission Register

Source inspected: `android/app/src/main/AndroidManifest.xml` (Lines 4–30).

| Permission Identifier | Protection Level | Manifest Location | Runtime Request Mechanism | Platform Scope | Implemented Feature Purpose | Mapped Test IDs | User Privacy & Operational Risk | Owner Approval Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`android.permission.INTERNET`** | Normal | `Manifest.xml:4` | Granted at install time | All Android APIs | Core Supabase API, Edge Functions & WebRTC signaling | All network tests | Minimal (Standard web connectivity) | **PENDING (Gate 2)** |
| **`android.permission.ACCESS_NETWORK_STATE`** | Normal | `Manifest.xml:5` | Granted at install time | All Android APIs | Offline detection, connectivity change monitoring | `TC-SYS01`, `TC-EXP-56` | Minimal (Detects Wi-Fi/Cellular state) | **PENDING (Gate 2)** |
| **`android.permission.ACCESS_COARSE_LOCATION`** | Dangerous (Runtime) | `Manifest.xml:6` | `NativeBridge.kt:468` (`requestPermissions`) | All Android APIs | Network/Cell-tower based child location fix | `TC-LOC01`, `TC-EXP-35` | High (User geographical location tracking) | **PENDING (Gate 5)** |
| **`android.permission.ACCESS_FINE_LOCATION`** | Dangerous (Runtime) | `Manifest.xml:7` | `NativeBridge.kt:469` (`requestPermissions`) | All Android APIs | High-accuracy GPS child tracking & geofencing | `TC-LOC01`, `TC-LOC05`, `TC-EXP-37` | High (Precise physical tracking) | **PENDING (Gate 5)** |
| **`android.permission.ACCESS_BACKGROUND_LOCATION`** | Dangerous (Special Runtime) | `Manifest.xml:8` | `NativeBridge.kt:424` (`openBackgroundLocationSettings`) | Android 10+ (API 29+) | Periodic location telemetry when app is in background | `TC-EXP-37`, `TC-EXP-53` | Critical (Continuous background tracking) | **PENDING (Gate 5)** |
| **`android.permission.CAMERA`** | Dangerous (Runtime) | `Manifest.xml:9` | `NativeBridge.kt:465` (`requestPermissions`) | All Android APIs | QR code pairing scan & WebRTC video remote assistance | `TC-FAM01`, `TC-CHD05`, `TC-EXP-08` | High (Video capture & camera hardware control) | **PENDING (Gate 5)** |
| **`android.permission.RECORD_AUDIO`** | Dangerous (Runtime) | `Manifest.xml:10` | `NativeBridge.kt:466` (`requestPermissions`) | All Android APIs | WebRTC bidirectional audio stream during active call | `TC-CHD05`, `TC-EXP-08`, `TC-EXP-44` | High (Microphone live audio capture) | **PENDING (Gate 5)** |
| **`android.permission.POST_NOTIFICATIONS`** | Dangerous (Runtime) | `Manifest.xml:11` | `NativeBridge.kt:474` (`requestPermissions`) | Android 13+ (API 33+) | Foreground service persistence & parent alert notifications | `TC-CHD04`, `TC-EXP-49` | Medium (Notification shade alerts & persistent icon) | **PENDING (Gate 5)** |
| **`android.permission.FOREGROUND_SERVICE`** | Normal | `Manifest.xml:12` | Granted at install time | Android 9+ (API 28+) | Runs background daemons (`GuardianService`, `LocationTrackingService`) | `TC-CHD04`, `TC-EXP-37` | Medium (Persistent process execution in background) | **PENDING (Gate 5)** |
| **`android.permission.FOREGROUND_SERVICE_DATA_SYNC`** | Normal | `Manifest.xml:13` | Granted at install time | Android 14+ (API 34+) | Data synchronization type for `GuardianService` | `TC-CHD04`, `TC-EXP-56` | Medium (Background policy sync) | **PENDING (Gate 5)** |
| **`android.permission.FOREGROUND_SERVICE_LOCATION`** | Normal | `Manifest.xml:14` | Granted at install time | Android 14+ (API 34+) | Location tracking type for `LocationTrackingService` | `TC-EXP-37` | High (Background location execution) | **PENDING (Gate 5)** |
| **`android.permission.FOREGROUND_SERVICE_MICROPHONE`** | Normal | `Manifest.xml:15` | Granted at install time | Android 14+ (API 34+) | Audio assistance type for `AudioAssistanceService` | `TC-EXP-08`, `TC-EXP-44` | High (Ongoing microphone access indicator) | **PENDING (Gate 5)** |
| **`android.permission.WAKE_LOCK`** | Normal | `Manifest.xml:17` | Granted at install time | All Android APIs | Keeps CPU active during active WebRTC audio capture | `TC-EXP-08` | Medium (Battery consumption during calls) | **PENDING (Gate 5)** |
| **`android.permission.RECEIVE_BOOT_COMPLETED`** | Normal | `Manifest.xml:18` | Granted at install time | All Android APIs | Automatically restarts `GuardianService` on device boot | `TC-MON04` | Medium (Persistent restart across reboots) | **PENDING (Gate 5)** |
| **`android.permission.PACKAGE_USAGE_STATS`** | Special App Access | `Manifest.xml:21–23` | `NativeBridge.kt:412` (`openUsageAccessSettings`) | Android 5.0+ (API 21+) | Daily app screen-time tracking via `UsageStatsManager` | `TC-USE01`, `TC-USE02`, `TC-EXP-28` | High (Full app inventory usage history) | **PENDING (Gate 5)** |
| **`android.permission.QUERY_ALL_PACKAGES`** | Special Visibility | `Manifest.xml:27–29` | Granted at install time | Android 11+ (API 30+) | Queries list of installed packages for parent restriction UI | `TC-APP01`, `TC-EXP-23` | High (Full device application visibility) | **PENDING (Gate 5)** |

---

## 3. Device Administration: Device Admin vs Device Owner

### 3.1 Device Admin Implementation (`ParentControlDeviceAdminReceiver`)
- **Class Reference**: `android/app/src/main/kotlin/com/parentcontrol/parent_control/ParentControlDeviceAdminReceiver.kt`
- **Superclass**: `android.app.admin.DeviceAdminReceiver`
- **Manifest Declaration**: `AndroidManifest.xml:95–105`
  ```xml
  <receiver
      android:name=".ParentControlDeviceAdminReceiver"
      android:exported="true"
      android:permission="android.permission.BIND_DEVICE_ADMIN">
      <meta-data
          android:name="android.app.device_admin"
          android:resource="@xml/device_admin" />
      <intent-filter>
          <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
      </intent-filter>
  </receiver>
  ```
- **Metadata Inspection (`res/xml/device_admin.xml`)**:
  ```xml
  <device-admin xmlns:android="http://schemas.android.com/apk/res/android">
      <!-- No legacy password/lock policies are requested. App suspension is a
           Device Owner capability and must never be applied without it. -->
      <uses-policies />
  </device-admin>
  ```
- **Critical Architectural Finding**: `<uses-policies />` is **completely empty**! HAVEN requests **zero legacy DeviceAdmin policies** (no password quality, no wipe data, no force lock).
- **Activation Request Flow**: Launched via `NativeBridge.kt:398` using `DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN`.
- **Operating Capability under Device Admin Alone**: When active, `devicePolicyManager.isAdminActive(admin)` returns `true`, and the device reports `enforcement_mode = "device_admin"`. However, **ordinary Device Admin grants NO power to suspend packages, block applications, or prevent uninstallation**.

### 3.2 Device Owner Capability & Boundaries
- **Source Truth**: `PolicyApplier.kt:20–23` states:
  > *"Suspension is only possible for a Device Owner (fully managed provisioning); every other state is reported as unsupported instead of pretending that an app was blocked."*
- **Call-Site Inspection (`PolicyApplier.kt:135–153`)**:
  ```kotlin
  if (desiredCount > 0 && !isOwner) {
      errors.add(
          "Device Owner provisioning is required to suspend apps on this device. " +
          "No apps were suspended."
      )
      unsupported.addAll(appDesired)
  } else if (isOwner) {
      val toSuspend = desired - previous
      if (toSuspend.isNotEmpty()) {
          suspendCallSucceeded = suspendPackages(toSuspend, errors)
      }
  }
  ```
- **Method Execution (`PolicyApplier.kt:348–360`)**:
  `devicePolicyManager.setPackagesSuspended(admin, packages.toTypedArray(), true)` is invoked inside a try/catch block. If the app is not Device Owner, the OS throws `SecurityException: "The system refused to suspend apps: Device Owner access is missing."`
- **Provisioning Reality**: Device Owner CANNOT be provisioned via user UI dialogs or runtime prompts. It strictly requires:
  1. Factory-resetting the device with zero Google/user accounts.
  2. Executing an external ADB command:
     `adb shell dpm set-device-owner com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`
     (or using enterprise QR provisioning).
- **Summary Boundary**:
  - `Device Admin` $\neq$ `Device Owner`.
  - Activating Device Admin does **NOT** enable application suspension (`TC-APP07`).
  - Device Owner is an unprovisioned enterprise deployment state, not an ordinary user permission.

---

## 4. Usage Access Special App Access Integration

- **Manifest Declaration**: `<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />`
- **Detection Logic (`NativePermissions.kt:34–55`)**:
  Uses `AppOpsManager.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED`.
- **User Prompt Flow (`NativeBridge.kt:412–422`)**:
  Launches `Settings.ACTION_USAGE_ACCESS_SETTINGS`. If intent fails, falls back to `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`.
- **Data Collection Path (`UsageReporter.kt`)**:
  Invokes `UsageStatsManager.queryUsageStats()` to aggregate daily minutes per package (`TC-USE01`, `TC-USE02`, `TC-EXP-28`).
- **Classification**: **SPECIAL APP ACCESS**. Cannot be granted via normal runtime permission popups.

---

## 5. Background Location, Battery Optimization, Camera & Microphone

### 5.1 Background Location (`ACCESS_BACKGROUND_LOCATION`)
- **API Boundary**: On Android 10+ (API 29+), `ACCESS_BACKGROUND_LOCATION` cannot be requested in the same prompt as fine location. The user must be directed to system app settings (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`) to select "Allow all the time".
- **Source Reality (`NativeBridge.kt:424`)**: `openBackgroundLocationSettings()` opens app details settings.

### 5.2 Battery Optimization Exemption
- **Manifest Reality**: `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is **NOT declared** in `AndroidManifest.xml`.
- **Source Inspection**: There is **zero call** to `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` or `PowerManager.isIgnoringBatteryOptimizations()`.
- **Architectural Truth**: HAVEN relies entirely on foreground services with active notification channels (`GuardianService`, `LocationTrackingService`, `AudioAssistanceService`) rather than battery optimization exemptions.
- **Battery Telemetry**: `BatteryManager` is queried solely for read-only capacity and charging status in `NativeBridge.kt:222` to populate heartbeat telemetry sent to parents (`TC-EXP-39`).

### 5.3 Camera & Microphone (`CAMERA`, `RECORD_AUDIO`)
- **Scope of Use**: Inspected in `AudioAssistanceService.kt` and `NativeBridge.kt:147–159`.
- **Active WebRTC Scoping**: Microphone is active **only** while a parent-initiated remote assistance session is active.
- **Ambient Wiretapping Status**: **NOT IMPLEMENTED**. There is zero background listener or secret ambient recording daemon. The application cannot record audio without an active session ID and an ongoing foreground notification indicator.

---

## 6. Consolidated Android Capability Master Matrix

| Capability / Subsystem | Source Code Implementation | Manifest Declaration | Privilege Level Required | Available in Current Codebase | Runtime Verified | Primary Test IDs | Owner Authorization Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Internet & Network State** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Normal Install-time | **YES** | `REQUIRES_RUNTIME_VALIDATION` | Network tests | `OWNER_AUTHORIZATION_PENDING` |
| **Fine & Coarse GPS Location** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Runtime Permission | **YES** | `REQUIRES_RUNTIME_VALIDATION` | `TC-LOC01`, `TC-LOC05` | `OWNER_AUTHORIZATION_PENDING` |
| **Background Location Tracking** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Special Runtime (Settings) | **YES** | `REQUIRES_RUNTIME_VALIDATION` | `TC-EXP-37`, `TC-EXP-53` | `OWNER_AUTHORIZATION_PENDING` |
| **Usage Stats Reporting** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Special App Access (AppOps) | **YES** | `REQUIRES_RUNTIME_VALIDATION` | `TC-USE01`, `TC-EXP-28` | `OWNER_AUTHORIZATION_PENDING` |
| **WebRTC Camera & Microphone** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Runtime Permission | **YES** | `REQUIRES_RUNTIME_VALIDATION` | `TC-CHD05`, `TC-EXP-08` | `OWNER_AUTHORIZATION_PENDING` |
| **Guardian Background Service** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Foreground Service | **YES** | `REQUIRES_RUNTIME_VALIDATION` | `TC-CHD04`, `TC-MON04` | `OWNER_AUTHORIZATION_PENDING` |
| **Device Administrator** | `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | Device Admin Intent | **YES** (Reporting Only) | `REQUIRES_RUNTIME_VALIDATION` | `TC-SET05`, `TC-EXP-55` | `OWNER_AUTHORIZATION_PENDING` |
| **App Suspension (`setPackagesSuspended`)**| `SOURCE_VERIFIED` | `MANIFEST_VERIFIED` | **Device Owner Only** | **PARTIAL** (Requires ADB Provisioning) | `REQUIRES_RUNTIME_VALIDATION` | `TC-APP07` | `OWNER_AUTHORIZATION_PENDING` |
| **Accessibility Service (`M08`)** | **`NOT IMPLEMENTED`** | **`NOT DECLARED`** | Accessibility Service | **NO** | `NOT_APPLICABLE` | None (`M08` Absent) | **NOT AUTHORIZED (Absent)** |
| **Notification Listener (`M09`)** | **`NOT IMPLEMENTED`** | **`NOT DECLARED`** | Notification Listener | **NO** | `NOT_APPLICABLE` | None (`M09` Absent) | **NOT AUTHORIZED (Absent)** |
| **Battery Optimization Exemption** | **`NOT IMPLEMENTED`** | **`NOT DECLARED`** | Special Battery Intent | **NO** | `NOT_APPLICABLE` | None | **NOT AUTHORIZED (Absent)** |
| **Ambient Background Wiretapping (`M04`)**| **`NOT IMPLEMENTED`** | **`NOT DECLARED`** | Background Mic Access | **NO** | `NOT_APPLICABLE` | None (`M04` Absent) | **NOT AUTHORIZED (Absent)** |

---

## 7. Inventory Conclusion

The Android capability inventory confirms that HAVEN's native implementation is structured, honest, and fail-safe. It does not fabricate app suspension when Device Owner is missing, and it does not contain secret accessibility or background wiretapping services.
