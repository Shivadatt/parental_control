# 05 — Android Native Functionality Inventory

**Document ID:** `HAVEN-INV-005`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Platform:** Android Native Layer (Kotlin, AndroidX, Android OS Integration)  

---

## 1. Executive Summary

This document provides a comprehensive audit of the native Android components residing within `android/app/src/main/kotlin/com/parentcontrol/parent_control/` and `AndroidManifest.xml`. It details the background daemons, native hardware bridges, system receivers, cryptographic storage, and operating-system-level privilege boundaries that power the child device enforcement engine.

Crucially, this audit documents the sharp technical boundary between **Device Administrator** and **Device Owner** modes, explaining why certain OS-level capabilities (such as package suspension) behave differently depending on device provisioning.

---

## 2. Android Manifest & Privilege Inventory

### 2.1 Manifest Permissions Declared (`AndroidManifest.xml`)

| Permission String | Protection Level | Purpose in HAVEN | User Grant Flow |
|---|---|---|---|
| `android.permission.INTERNET` | Normal | Network communication with Supabase Edge Functions & WebRTC | Automatic at install |
| `android.permission.ACCESS_NETWORK_STATE` | Normal | Monitoring Wi-Fi/cellular connection state | Automatic at install |
| `android.permission.FOREGROUND_SERVICE` | Normal | Running continuous background monitoring daemon | Automatic at install |
| `android.permission.FOREGROUND_SERVICE_DATA_SYNC` | Normal | Declaring data-sync foreground service type (Android 14+) | Automatic at install |
| `android.permission.FOREGROUND_SERVICE_LOCATION` | Normal | Declaring location foreground service type (Android 14+) | Automatic at install |
| `android.permission.FOREGROUND_SERVICE_MICROPHONE` | Normal | Live audio assistance streaming (Android 14+) | Automatic at install |
| `android.permission.POST_NOTIFICATIONS` | Dangerous (API 33+) | Displaying persistent protection status notification | Runtime permission prompt |
| `android.permission.ACCESS_FINE_LOCATION` | Dangerous | High-accuracy GPS location tracking for child device | Runtime permission prompt |
| `android.permission.ACCESS_COARSE_LOCATION` | Dangerous | Cellular/Wi-Fi cell tower triangulation | Runtime permission prompt |
| `android.permission.ACCESS_BACKGROUND_LOCATION` | Dangerous (API 29+) | Continuous location tracking when application is closed | System settings prompt |
| `android.permission.CAMERA` | Dangerous | Live WebRTC remote assistance video feed & QR scan | Runtime permission prompt |
| `android.permission.RECORD_AUDIO` | Dangerous | Live WebRTC remote assistance two-way voice call | Runtime permission prompt |
| `android.permission.PACKAGE_USAGE_STATS` | AppOps Special | Tracking daily application usage time via `UsageStatsManager` | Launched via system settings intent |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Normal | Re-launching background services automatically on device reboot | Automatic at install |

---

## 3. Native Kotlin Component Architecture

```
+--------------------------------------------------------------------------------------------------+
|                                  ANDROID NATIVE SUBSYSTEMS                                       |
|                                                                                                  |
|  +------------------------+  MethodChannel   +------------------------------------------------+  |
|  |     Flutter Layer      |<---------------->|                NativeBridge.kt                 |  |
|  | (Controllers/Services) |                  | - Method call dispatcher                       |  |
|  +------------------------+                  | - Event streaming & permission queries         |  |
|                                              +------------------------------------------------+  |
|                                                       |              |             |             |
|                                                       v              v             v             |
|  +------------------------+                  +---------------+ +------------+ +---------------+  |
|  |    GuardianService     |                  | SecureStore   | | Policy     | | Location      |  |
|  | - 10s Main Tick        |                  | - AES-256-GCM | | Applier    | | Service       |  |
|  | - 20s Command Poll     |                  | - Hardware    | | - Package  | | - GPS Tracking|  |
|  | - 5m Heartbeat         |                  |   KeyStore    | |   Suspend  | | - Geofence Fix|  |
|  | - 30m App Upload       |                  | - Credentials | | - Quotas   | +---------------+  |
|  | - 60m Usage Upload     |                  +---------------+ +------------+                    |
|  +------------------------+                         |                                            |
|            ^                                        v                                            |
|            |                          +-------------------------------+                          |
|  +------------------------+           | DevicePolicyManager Integration|                          |
|  |     BootReceiver       |           | - Device Admin vs Device Owner|                          |
|  | - Auto-restart on boot |           | - Receiver event callbacks    |                          |
|  +------------------------+           +-------------------------------+                          |
+--------------------------------------------------------------------------------------------------+
```

---

## 4. Deep-Dive Component Specifications

### 4.1 `GuardianService.kt` — Core Background Execution Daemon
- **Component Type**: Android `Service` (Foreground Service with persistent notification).
- **Foreground Service Type**: `ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC`.
- **Notification Channel**: `CHANNEL_ID = "guardian_status"`, `NOTIFICATION_ID = 4101`.
- **Scheduled Timers & Work Cycles**:
  - `TICK_MS = 10_000L` (10 seconds): Main watchdog tick; checks internet and service health.
  - `POLL_INTERVAL_MS = 20_000L` (20 seconds): Polls `POST /device-command` for incoming commands.
  - `POLICY_TICK_MS = 60_000L` (60 seconds): Evaluates active schedules and bedtime rules.
  - `HEARTBEAT_MS = 300_000L` (5 minutes): Posts heartbeat with battery level and permission map.
  - `APPS_UPLOAD_MS = 1_800_000L` (30 minutes): Snapshots and uploads installed user apps.
  - `USAGE_UPLOAD_MS = 3_600_000L` (60 minutes): Gathers and uploads daily app usage stats.
- **Android OS Restrictions Handled**:
  - Catches `ForegroundServiceStartNotAllowedException` on Android 12+ when started from background.
  - Stores system error messages in `SecureStore` to display actionable guidance to the user.

### 4.2 `SecureStore.kt` — Hardware-Backed Cryptographic Vault
- **Storage Implementation**: `EncryptedSharedPreferences` using Android Jetpack Security.
- **Master Key Scheme**: `MasterKey.KeyScheme.AES256_GCM` backed by hardware Android KeyStore.
- **Key Encryption**: `AES256_SIV` (keys), `AES256_GCM` (values).
- **Credentials Managed**:
  - `installation_id`: UUID generated on first boot.
  - `device_secret`: 32-byte cryptographic random secret (`SecureRandom().nextBytes(32)`).
  - Sync configuration: Supabase URL, publishable key, device ID, family ID.
  - Policy cache: `last_policy_json`, `applied_policy_version`, `suspended_packages`.

### 4.3 `NativeBridge.kt` — MethodChannel Interop Contract
- **Channel Identifier**: `"com.parentcontrol/native"`.
- **Key Methods Handled**:
  - `getAppVersion`: Returns version name and build number.
  - `getPermissionsSnapshot`: Returns JSON map of all 5 critical permissions.
  - `startGuardianService`: Starts `GuardianService` in foreground.
  - `stopGuardianService`: Stops background sync.
  - `enableDeviceAdmin`: Launches system Device Admin activation intent.
  - `openAppInfoSettings`: Deep-links directly to Android Application Details settings screen.
  - `openLocationSettings`: Deep-links to system Location settings.
  - `openUsageAccessSettings`: Deep-links to system Usage Access authorization.
  - `isPackageSuspended`: Queries whether an app package is currently suspended by OS.
  - `configureBackgroundSync`: Writes `SyncConfig` to `SecureStore` and kicks service.

### 4.4 `LocationTrackingService.kt` — Displacement-Based GPS Tracker
- **Component Type**: Foreground Service (`FOREGROUND_SERVICE_TYPE_LOCATION`).
- **Provider**: Android `LocationManager` / Fused Location API.
- **Tracking Invariants**: Tracks GPS updates on minimum displacement ($\Delta d \ge 50\text{m}$) or time interval ($\Delta t \ge 15\text{m}$).
- **Upload Flow**: Batches location fixes (lat, lng, accuracy, speed, altitude) and posts to `device-telemetry`.

### 4.5 `AudioAssistanceService.kt` — WebRTC Media Daemon
- **Component Type**: Foreground Service (`FOREGROUND_SERVICE_TYPE_MICROPHONE`).
- **Function**: Maintains hardware microphone focus, manages Android audio routing (speakerphone vs earpiece), and prevents OS process termination during live assistance calls.

### 4.6 `BootReceiver.kt` — Auto-Start Broadcast Receiver
- **Action Handled**: `Intent.ACTION_BOOT_COMPLETED`.
- **Behavior**: Inspects `SecureStore.get(context).hasConfig()`. If enrolled, restarts `GuardianService` and `LocationTrackingService` immediately upon phone boot.
- **Android 15 Consideration**: Note that Android 15 imposes restrictions on starting data-sync services from boot receivers; HAVEN delegates to `JobScheduler` as a resilience fallback.

### 4.7 `ParentControlDeviceAdminReceiver.kt` — Device Admin Integration
- **Receiver**: Subclasses Android `DeviceAdminReceiver`.
- **Policy Configured**: Defined in `res/xml/device_admin_policies.xml`.
- **Events Intercepted**:
  - `onEnabled`: Confirms administrative authority granted.
  - `onDisableRequested`: Intercepts child attempting to deactivate admin; returns localized warning banner: *"HAVEN protection is active. Deactivating will alert your parent."*
  - `onDisabled`: Logs revocation event; triggers permission degradation alert.

---

## 5. Device Administrator vs. Device Owner: Architectural Clarification

A critical finding of this audit is the distinction between **Device Administrator** and **Device Owner** modes:

```
+--------------------------------------------------------------------------------------------------+
|                               PRIVILEGE TIER COMPARISON MATRIX                                   |
|                                                                                                  |
|  CAPABILITY                             DEVICE ADMINISTRATOR        DEVICE OWNER (Provisioned)   |
|  -----------------------------------    --------------------        --------------------------   |
|  Screen Lock / Password Rules           SUPPORTED                   SUPPORTED                    |
|  Camera Disable Globally                SUPPORTED                   SUPPORTED                    |
|  App Suspension (setPackagesSuspended)  NOT SUPPORTED (FAILS)       FULLY SUPPORTED              |
|  Silent App Installation                NOT SUPPORTED               FULLY SUPPORTED              |
|  Zero-Interaction Uninstall Block       NOT SUPPORTED               FULLY SUPPORTED              |
|  Play Store Standard Installation       SUPPORTED (Normal Install)  REQUIRES FACTORY RESET/QR    |
+--------------------------------------------------------------------------------------------------+
```

### Source Code Reality:
1. `ParentControlDeviceAdminReceiver.kt` explicitly comments that Device Owner provisioning is **NOT supported** from within the app.
2. When `PolicyApplier.kt` calls `devicePolicyManager.setPackagesSuspended()`, Android OS requires the caller to be a **Device Owner** or **Profile Owner**.
3. On a standard Play Store / sideloaded APK install, the app reaches **Device Administrator only**.
4. Consequently, `APP07` (OS App Suspension) and `USE08` (Daily Quota Enforcement) are classified as **`PARTIALLY_IMPLEMENTED`** on standard hardware.

---

## 6. Android Version Compatibility & Verification Matrix

| Android Version | API Level | Key Architectural Behavior in HAVEN | Potential Testing Trap |
|---|---|---|---|
| **Android 11 & Below** | API $\le 30$ | Foreground service starts freely from background; permissions standard. | Full background reliability. |
| **Android 12 / 12L** | API 31–32 | Background foreground service starts restricted; `POST_NOTIFICATIONS` absent. | **`HAVEN-QA-004` false-positive occurs here** if naive SDK check is used. |
| **Android 13** | API 33 | `Manifest.permission.POST_NOTIFICATIONS` required at runtime. | Child must explicitly tap "Allow" on notification dialog. |
| **Android 14** | API 34 | Strict `foregroundServiceType` validation; dataSync timeout limits. | Must declare `dataSync` in manifest and service tag. |
| **Android 15** | API 35 | Boot receiver cannot launch dataSync foreground services directly. | Must be launched via JobScheduler / user click. |
