# PHASE 1.3 — CONTROLLED CHILD APK INSTALLATION REPORT

**Execution Timestamp:** 2026-11-16T16:49:00+05:30  
**Project Path:** `D:\parentcontrol_app`  
**Target Device:** Realme RMX2161 (`5HXWRGQ4IFU8WS4T`, Android 12 / API 31)  
**Target Application ID:** `com.parentcontrol.parent_control`  

---

## 1. APK Path and SHA-256 Checksum

- **APK File Path:** `D:\parentcontrol_app\build\app\outputs\flutter-apk\app-debug.apk`
- **File Size:** `243,958,409 bytes` (~232.6 MiB)
- **SHA-256 Checksum:** `8FAE3E9F5DB450CB758F595C5AC5F7CB33EB769433C86B89E7E1F9E5E1815120`

---

## 2. Verified `applicationId`

- **Package Identifier:** `com.parentcontrol.parent_control`
- **Application Label:** `'Parent Control'`
- **Launchable Activity:** `com.parentcontrol.parent_control.MainActivity`
- **Verification Tool:** Android SDK `aapt` (35.0.0) badging inspection.

---

## 3. Version and Signing Details

- **Version Code:** `1`
- **Version Name:** `1.0.0`
- **Min SDK:** `24` (Android 7.0)
- **Target SDK:** `36`
- **Signing Scheme:** APK Signature Scheme v2 (`true`)
- **Signer DN:** `C=US, O=Android, CN=Android Debug`
- **Certificate SHA-256 Digest:** `1c9268d57ebe5f5e15eb3738eed96e57f776c298e9e44d75a51937cda70720a5`
- **Certificate SHA-1 Digest:** `1051368ef712a4225a31c50a6ecfb4d2c3261881`

---

## 4. ADB Device Detection

```text
List of devices attached
5HXWRGQ4IFU8WS4T       device product:RMX2161 model:RMX2161 device:RMX2161L1 transport_id:18
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:3
```
- **Target Device Serial:** `5HXWRGQ4IFU8WS4T`
- **Status:** Online, authorized, battery 100%.

---

## 5. Installation Command and Result

```powershell
adb -s 5HXWRGQ4IFU8WS4T install D:\parentcontrol_app\build\app\outputs\flutter-apk\app-debug.apk
```
**Output:**
```text
Performing Streamed Install
Success
```
**Result:** **INSTALL SUCCESSFUL**.

---

## 6. Installed Package Verification

Package path on device:
```powershell
adb -s 5HXWRGQ4IFU8WS4T shell pm path com.parentcontrol.parent_control
```
**Output:**
```text
package:/data/app/~~VpgBBRLgz5E0UoeL9L1HSg==/com.parentcontrol.parent_control-MEsarmcNL7QYToIQyLbUow==/base.apk
```

Package dumpsys details:
```text
versionCode=1 minSdk=24 targetSdk=36
versionName=1.0.0
firstInstallTime=2026-11-16 16:44:16
lastUpdateTime=2026-11-16 16:44:16
```

---

## 7. Launch Result

Command executed:
```powershell
adb -s 5HXWRGQ4IFU8WS4T shell monkey -p com.parentcontrol.parent_control -c android.intent.category.LAUNCHER 1
```
- **Process Status:** Launched cleanly as PID `5018`.
- **Crashes:** `0` (Zero ANRs, zero FATAL exceptions, zero runtime aborts).
- **Current State:** Stopped at the **Onboarding / Mode Selection Screen** (`/role-selection`) per Step 5 instructions.

---

## 8. Screen Display & Sanitized Startup Logs

### 8.1 Active UI Hierarchy (Captured via UI Automator Dump)
```xml
<node content-desc="Get started" ... />
<node content-desc="How will you use Parent Control?" ... />
<node content-desc="This choice only opens the matching sign-in or sign-up flow and is stored on this device. It never grants parent or child permissions." ... />
<node content-desc="Parent Mode" ... />
<node content-desc="Create a family, link a child device with a consent-based pairing request, and manage that family’s policies." ... />
<node class="android.widget.Button" content-desc="Sign in" ... />
<node class="android.widget.Button" content-desc="Create account" ... />
<node content-desc="Child Mode" ... />
<node content-desc="Join a family with a linking code, review what is shared and approve pairing or assistance requests on the device." ... />
<node class="android.widget.Button" content-desc="Sign in" ... />
<node class="android.widget.Button" content-desc="Create account" ... />
<node content-desc="A device role is a server-side decision. Local choices are never used to authorize device data or family access." ... />
```

### 8.2 Evidence Artifacts
- **Screenshot:** [child_app_launch.png](file:///d:/parentcontrol_app/docs/testing/evidence/child_app_launch.png)
- **UI Dump:** [child_app_launch.xml](file:///d:/parentcontrol_app/docs/testing/evidence/child_app_launch.xml)

### 8.3 Sanitized Logcat Excerpt
```text
11-16 16:48:15.519 13893 13893 I AndroidRuntime: VM exiting with result code 0, cleanup skipped.
11-16 16:48:17.316  2850  2850 I Quality-UserEventsCenter: Send jank info: Event{id=228, type=BLOCK, cost=1533, time=1794827867238, subject=com.parentcontrol.parent_control/.MainActivity, pid=5018, jankInfo=3e94fb0089d1}
```

---

## 9. Untouched State of Unrelated Applications

Verification command:
```powershell
adb -s 5HXWRGQ4IFU8WS4T shell pm path com.supereagleeye.child
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys package com.supereagleeye.child | Select-String "versionCode|versionName|firstInstallTime|lastUpdateTime"
```
**Output:**
```text
package:/data/app/~~NkClIKipNIuVZvUr0kPmTA==/com.supereagleeye.child-AjrvaVI2EfittV23I1SB2Q==/base.apk
versionCode=1 minSdk=24 targetSdk=36
versionName=0.1.0
firstInstallTime=2026-11-16 10:06:02
lastUpdateTime=2026-11-16 10:06:02
```
- **Confirmation:** `com.supereagleeye.child` was not uninstalled, overwritten, modified, or cleared. Its installation timestamp (`10:06:02`) remains unchanged.

---

## 10. Compliance & Blockers

- **Safety Compliance:**
  - No source-code changes.
  - No database or backend records modified.
  - No Supabase deployment.
  - No accounts or credentials modified.
  - No pairing reset.
  - No app data wiped.
  - No permissions altered manually.
  - Execution strictly halted at the onboarding screen per Step 5.
- **Blockers:** None. The physical Child device is now equipped with the verified dual-role Parent Control application, open and ready for authenticated Child sign-in / live testing under an approved plan.
