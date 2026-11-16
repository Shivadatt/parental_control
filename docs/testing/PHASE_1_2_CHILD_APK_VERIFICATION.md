# PHASE 1.2 — CHILD APK BUILD & PACKAGE IDENTITY VERIFICATION

**Execution Timestamp:** 2026-11-16T16:25:00+05:30  
**Project Path:** `D:\parentcontrol_app`  
**Target Package:** `com.parentcontrol.parent_control` (Single Dual-Role APK)  
**Target Device:** Realme RMX2161 (`5HXWRGQ4IFU8WS4T`, Android 12 / API 31, arm64-v8a)  

---

## 1. Android Package Configuration Inspection

From `android/app/build.gradle.kts` and `android/app/src/main/AndroidManifest.xml`:
- **Namespace:** `com.parentcontrol.parent_control`
- **Application ID:** `com.parentcontrol.parent_control` (Exact match; no discrepancy with namespace)
- **Min SDK:** 24 (Android 7.0)
- **Target SDK:** 36
- **Compile SDK:** 36
- **Version Code:** 1
- **Version Name:** `1.0.0`
- **Build Flavors / Variants:** None configured; single dual-role architecture.
- **Main Activity:** `com.parentcontrol.parent_control.MainActivity`
- **Native Services Declared:**
  - `com.parentcontrol.parent_control.GuardianService` (Foreground DataSync)
  - `com.parentcontrol.parent_control.LocationTrackingService` (Foreground Location)
  - `com.parentcontrol.parent_control.AudioAssistanceService` (Foreground Microphone)
  - `com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver` (Device Admin)
- **Role Selection Architecture:** Authoritatively loaded from authenticated Supabase profile at runtime (`AuthSessionFlow.resolve()`):
  - `profile.role.isChild` -> `childShell`
  - `profile.role.isParent` -> `parentShell`

---

## 2. Generated APK Details

- **File Path:** `D:\parentcontrol_app\build\app\outputs\flutter-apk\app-debug.apk`
- **File Size:** 243,958,409 bytes (~232.6 MiB)
- **Build Timestamp:** 2026-11-16 15:10:35 IST
- **Build Invocation:** `.fvm\versions\3.44.6\bin\flutter.bat build apk --debug --dart-define-from-file=.tools/live_config.env`
- **Backend Configuration:** Baked-in via `--dart-define-from-file=.tools/live_config.env` (hosted Supabase URL and publishable anon key).

---

## 3. APK Package Identity & Signing Verification

Verified directly with Android SDK build-tools `aapt` (35.0.0) and `apksigner`:
- **Package Name:** `com.parentcontrol.parent_control`
- **Version Code:** `1`
- **Version Name:** `1.0.0`
- **Application Label:** `'Parent Control'`
- **Launchable Activity:** `com.parentcontrol.parent_control.MainActivity`
- **ABI Architectures Included:** `arm64-v8a`, `armeabi-v7a`, `x86_64`
- **Signing Scheme:** APK Signature Scheme v2 (`true`)
- **Signer DN:** `C=US, O=Android, CN=Android Debug`
- **Certificate SHA-256 Digest:** `1c9268d57ebe5f5e15eb3738eed96e57f776c298e9e44d75a51937cda70720a5`
- **Certificate SHA-1 Digest:** `1051368ef712a4225a31c50a6ecfb4d2c3261881`

---

## 4. Realme Pre-Installation Device Inspection

- **ADB Transport Status:**
  ```text
  5HXWRGQ4IFU8WS4T       device product:RMX2161 model:RMX2161 device:RMX2161L1 transport_id:13
  ```
- **Installed Packages Check:**
  - `com.supereagleeye.child`: Present (`/data/app/~~NkClIKipNIuVZvUr0kPmTA==/com.supereagleeye.child-AjrvaVI2EfittV23I1SB2Q==/base.apk`)
  - `com.coloros.childrenspace`: Present (OEM pre-installed system package)
  - `com.parentcontrol.parent_control`: **NOT INSTALLED**
- **Existing App Preservation:** `com.supereagleeye.child` was left untouched and intact.

---

## 5. Compatibility Assessment

- **Device Model:** Realme RMX2161 (Realme 7 / Narzo 20 Pro)
- **OS Version:** Android 12 / API 31
- **CPU Architecture:** `arm64-v8a` (Supported by APK native binaries `libflutter.so`, `libdartjni.so`, `libbarhopper_v3.so`)
- **Available Storage:** `62 GB` free on `/data` partition (108 GB total, 42% used)
- **Compatibility Verdict:** **100% COMPATIBLE**. No SDK, ABI, or storage blockers exist.

---

## 6. Installation Status

- **Action Taken:** In strict compliance with Step 5, **no installation was executed**.
- **Data State:** No local data was wiped, no pairing records were reset, no accounts were altered, and no Supabase production records were touched.
- **Awaiting User Action:** Awaiting explicit approval to execute:
  `adb -s 5HXWRGQ4IFU8WS4T install build\app\outputs\flutter-apk\app-debug.apk`
