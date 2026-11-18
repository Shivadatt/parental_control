# PHASE 3.0 — DEVICE CAPABILITY & HARDWARE COMPATIBILITY MATRIX

**Project:** `D:\parentcontrol_app`  
**Execution Mode:** STRICT READ-ONLY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. TARGET DEVICE SPECIFICATIONS

| Specification Attribute | Physical Child Device | Virtual Parent Device |
|---|---|---|
| **Hardware Model** | Realme RMX2161 (Narzo 20 Pro / 7) | Google Pixel 9a Emulator |
| **Android Version** | Android 12 (Snow Cone) | Android 15 (Vanilla Ice Cream) |
| **API Level** | API 31 | API 35 |
| **ADB Serial** | `5HXWRGQ4IFU8WS4T` | `emulator-5554` |
| **Architecture** | ARM64-v8a | x86_64 |
| **Active App Role** | Child Mode (`ankit1@gmail.com`) | Parent Mode (`ankit@gmail.com`) |
| **Primary Test Workload** | Background Services, Location, Telemetry, WebRTC Publishing | Dashboard, Realtime Alerts, Policy Authoring, WebRTC Playout |

---

## 2. HARDWARE & PLATFORM CAPABILITY COMPARISON

| Capability Domain | Realme RMX2161 (Child Device) | Pixel 9a Emulator (Parent Device) | Technical Architecture Notes |
|---|---|---|---|
| **Device Owner (DO) Provisioning** | ❌ **NOT PROVISIONED (Advisory)** | ❌ **NOT PROVISIONED** | Physical package suspension (`setPackagesSuspended`) requires factory wipe and ADB provisioning (`dpm set-device-owner`). On standard devices, `PolicyApplier.kt` honestly operates in Advisory mode. |
| **Device Admin (DA) Status** | ✅ **ACTIVE** (`ParentControlDeviceAdminReceiver`)| ⚪ **INACTIVE** (Parent mode does not require DA)| Activated via Android Settings > Device Admin. Enables screen lock management and status monitoring. |
| **Usage Access (`PACKAGE_USAGE_STATS`)** | ✅ **GRANTED** | ⚪ **NOT REQUIRED** | Enabled via Special App Access > Usage Access. Queried by `UsageReporter.kt` via `UsageStatsManager.queryUsageStats()`. |
| **Foreground Service Types** | ✅ Supported (`dataSync`, `location`, `microphone`)| ✅ Supported | Complies with Android 12+ strict foreground service declaration rules. |
| **Android Keystore Hardware Root** | ✅ **STRONG (TEE / TrustZone)** | ⚠️ **EMULATED** | `SecureStore.kt` generates AES-256 GCM keys backed by hardware TEE. Survives app restarts; regenerated if debug APK is uninstalled. |
| **Location Tracking (GPS)** | ✅ **HARDWARE GPS & NETWORK** | ⚠️ **SIMULATED (Fixed Lat/Lng)** | Physical device provides genuine satellite fixes with accuracy estimates. Emulator provides static mock locations. |
| **Background Location Access** | ✅ **GRANTED ("Allow all the time")** | ⚪ **NOT APPLICABLE** | Android 12 requires two-step permission prompt (Fine location first, followed by system settings prompt for Background). |
| **Microphone Capture (`RECORD_AUDIO`)**| ✅ **FUNCTIONAL (Hardware Mic)** | ⚪ **RECEIVE-ONLY** | Captured via `flutter_webrtc` under supervision of `AudioAssistanceService.kt` with persistent notification and wake lock. |
| **Audio Playout (Speaker / Receiver)** | ✅ Functional | ✅ **FUNCTIONAL (Host Audio Routing)** | Parent app receives RTP stream and plays back via default Android audio track. |
| **Realtime WebSocket Connectivity** | ✅ Active | ✅ **ACTIVE & RESILIENT** | Parent controller uses `WidgetsBindingObserver` auto-reconnect backoff to survive emulator sleeps and network switches. |
| **Battery Optimization Exemption** | ⚠️ **OEM-SPECIFIC (Realme UI / ColorOS)** | ✅ Standard AOSP | ColorOS/Realme UI aggressively kills background processes unless manually toggled to "Don't optimize" / "Allow background activity". |
| **Notification Permission (`POST_NOTIFICATIONS`)**| ✅ **NOT REQUIRED (< API 33)** | ✅ **GRANTED (API 35 Runtime Permission)** | Android 12 automatically permits notifications; Android 15 requires runtime user grant. |

---

## 3. REALME RMX2161 (CHILD) RUNTIME BEHAVIORAL PROFILE

1. **Advisory Mode Truthfulness:**
   - When the parent pushes a policy restricting an application (e.g. YouTube), `PolicyApplier.kt` evaluates:
     ```kotlin
     if (!isDeviceOwner()) {
         return NativePolicyApplyResult(
             appliedCount = 0,
             supported = false,
             advisory = true,
             message = "App suspension requires Device Owner setup on this device."
         )
     }
     ```
   - The device never fabricates successful enforcement. Both the child rules tab and parent device detail truthfully display "Policy acknowledged (Advisory)".
2. **Keystore Desync Characteristic (Defect E-16):**
   - In debug development builds, uninstalling and reinstalling the APK clears `EncryptedSharedPreferences`, creating a new local Keystore key and secret.
   - The remote Supabase backend retains the previously paired `secret_hash`.
   - **Remediation:** In production builds, the app is never uninstalled for updates. For recovery, the backend `request_device_recovery` RPC is available.

---

## 4. PIXEL 9A EMULATOR (PARENT) RUNTIME BEHAVIORAL PROFILE

1. **WebSocket Resilience (Defect E-17 Remediation):**
   - The parent shell maintains an active Supabase Realtime channel for `safety_alerts`.
   - Upon emulator pause/resume, the connection lifecycle observer initiates exponential backoff reconnects (`1s -> 2s -> 4s`), guaranteeing that "Live updates offline" warnings clear automatically.
2. **UI Rendering Fidelity:**
   - 1080x2424 xhdpi rendering accurately reflects modern Android Material 3 layouts, cards, dialogs, and navigation flows.
