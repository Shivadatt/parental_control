# 12 — Environment and Evidence Register

Audit Execution Date: 2026-11-23  
Audit Phase: Phase 6 Comprehensive End-to-End Execution  
Lead Auditor: Antigravity QA Agent Team (4 Specialized Subagents + Lead Coordinator)

---

## 1. Baseline Environment Verification

| Parameter | Authoritative Requirement | Actual Observed Value | Verification Status |
|---|---|---|---|
| **Workspace Path** | `D:\parentcontrol_app` | `D:\parentcontrol_app` | MATCH / VERIFIED |
| **Git Branch** | `main` | `main` | MATCH / VERIFIED |
| **Git Baseline HEAD** | `80375f518139bf922bc1b66c998691bee912af44` | `5ffc5c170add4bfafd236beb633f00b6fe86243b` (contains baseline commit `80375f5` as direct ancestor) | VERIFIED |
| **Git Tree Status** | Clean working tree | Working tree clean (no staged, unstaged, or untracked modifications prior to audit deliverables) | VERIFIED |
| **Flutter SDK** | `.\.fvm\flutter_sdk\bin\flutter.bat` | Pinned Flutter SDK 3.24.5 in `.fvm\flutter_sdk` | VERIFIED |
| **Package Name** | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` | VERIFIED |

---

## 2. Connected Device Specifications & Operating States

### Device 1: Parent Device (Emulator)
- **Role**: Parent
- **Serial**: `emulator-5554`
- **Model / Product**: `sdk_gphone64_x86_64` (Google Pixel 9 API 35/17 emulator image)
- **Android OS Version**: Android 17 (API 35 Preview / Baklava API Level 35)
- **Package Installed**: `com.parentcontrol.parent_control`
- **Version Name**: `1.0.0`
- **Focused Activity**: `com.parentcontrol.parent_control/.MainActivity` (running, visible)
- **Visible Screen at Capture**: `AppRoutes.roleSelection` ("Get started — How will you use Parent Control?")
- **Cached Local Role**: `parent` (stored in `FlutterSharedPreferences.xml`)
- **Display Banner**: *"Last choice on this device: Parent Mode. Sign in or create an account; the server profile still decides access."*
- **Current Authentication State**: **NO ACTIVE AUTHENTICATED SESSION**. Logcat records: `supabase.auth: INFO: Signing out user with scope: local`. User is at pre-login / role selection gateway.
- **Device Admin / Policy**: Registered receiver `com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`.
- **Runtime Permissions (Dumpsys)**:
  - `POST_NOTIFICATIONS`: `granted=false`
  - `ACCESS_FINE_LOCATION`: `granted=false`
  - `ACCESS_COARSE_LOCATION`: `granted=false`
  - `CAMERA`: `granted=false`
  - `RECORD_AUDIO`: `granted=false`
  - `ACCESS_BACKGROUND_LOCATION`: `granted=false`
  - `ACCESS_LOCAL_NETWORK`: `granted=true`
  - Usage Stats (`PACKAGE_USAGE_STATS`): `default` (not granted)
- **Network State**: Connected via `wlan0` (`AndroidWifi`), metered=false, defaultNetwork=true.

### Device 2: Child Device (Physical Hardware)
- **Role**: Child
- **Serial**: `5HXWRGQ4IFU8WS4T`
- **Model / Product**: `Realme RMX2161` (Realme 7)
- **Android OS Version**: Android 12 (API level 31, realme UI)
- **Package Installed**: `com.parentcontrol.parent_control`
- **Version Name**: `1.0.0`
- **Focused Activity**: `com.parentcontrol.parent_control/.MainActivity` (running, visible)
- **Visible Screen at Capture**: `AppRoutes.roleSelection` ("Get started — How will you use Parent Control?")
- **Cached Local Role**: `child` (stored in `FlutterSharedPreferences.xml`)
- **Display Banner**: *"Last choice on this device: Child Mode. Sign in or create an account; the server profile still decides access."*
- **Visible UI Defect**: Action button labels truncated to *"Create acc..."* across both Parent and Child option cards.
- **Current Authentication State**: **NO ACTIVE AUTHENTICATED SESSION**. Logcat records: `supabase.auth: INFO: Signing out user with scope: local`. User is at pre-login / role selection gateway.
- **Device Admin / Policy**: Active Device Administrator `com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`.
- **Runtime Permissions (Dumpsys)**:
  - `ACCESS_FINE_LOCATION`: `granted=true`
  - `ACCESS_COARSE_LOCATION`: `granted=true`
  - `CAMERA`: `granted=true`
  - `RECORD_AUDIO`: `granted=true`
  - `ACCESS_BACKGROUND_LOCATION`: `granted=true`
  - Usage Stats (`PACKAGE_USAGE_STATS`): `allow` (`GET_USAGE_STATS: allow`)
- **Network State**: Connected via `wlan0` (`moto edge 60 pro_5677`), metered=true, defaultNetwork=true.

---

## 3. Preservation & Security Verification

Under Absolute Rule 2.1 through 2.5:
1. **No Account Mutation**: No sign-out, session replacement, token revocation, account creation, or account deletion was performed.
2. **No Data Clearing**: Neither `pm clear` nor cache deletion was executed on either device.
3. **No Permission Modification**: No Android permissions were granted, revoked, or modified via ADB or UI.
4. **No Destructive Operations**: No pairing codes redeemed, devices unlinked, background sync forced, or retention sweeps triggered.
5. **No Source / Git Changes**: Zero source files modified, no git commits, stashes, or resets executed.
6. **No Credentials Exposed**: Zero passwords, access tokens, refresh tokens, or secrets captured or recorded.

---

## 4. Evidence Register (Screenshots & Logs)

| Evidence ID | Path | Device / Source | Description |
|---|---|---|---|
| EVD-001 | `docs/testing/phase6_comprehensive_execution/evidence/parent_initial.png` | `emulator-5554` | Parent device initial screen showing `roleSelection` with "Last choice: Parent Mode" |
| EVD-002 | `docs/testing/phase6_comprehensive_execution/evidence/child_initial.png` | `5HXWRGQ4IFU8WS4T` | Child device initial screen showing `roleSelection` with "Last choice: Child Mode" & truncated buttons |
| EVD-003 | `docs/testing/phase6_comprehensive_execution/evidence/child_role_selection_clipped.png` | `5HXWRGQ4IFU8WS4T` | Highlighting text truncation defect *"Create acc..."* on Realme RMX2161 (Android 12) |
| EVD-004 | `docs/testing/phase6_comprehensive_execution/evidence/parent_login_screen.png` | `emulator-5554` | Parent sign-in form (`AppRoutes.login`) with Email, Password, Sign in, and Create Account affordances |
| EVD-005 | `docs/testing/phase6_comprehensive_execution/evidence/parent_login_validation.png` | `emulator-5554` | Parent sign-in client-side validation errors triggered on empty form submission |
| EVD-006 | `docs/testing/phase6_comprehensive_execution/evidence/child_login_screen.png` | `5HXWRGQ4IFU8WS4T` | Child sign-in form (`AppRoutes.login`) with Child mode banner |
| EVD-007 | `docs/testing/phase6_comprehensive_execution/evidence/child_login_validation.png` | `5HXWRGQ4IFU8WS4T` | Child sign-in client-side validation errors triggered on empty form submission |
| EVD-008 | `docs/testing/phase6_comprehensive_execution/evidence/logcat_auth_signout_parent.txt` | `emulator-5554` | Redacted logcat showing local signout event upon application startup |
| EVD-009 | `docs/testing/phase6_comprehensive_execution/evidence/logcat_auth_signout_child.txt` | `5HXWRGQ4IFU8WS4T` | Redacted logcat showing local signout event upon application startup |
| EVD-010 | `docs/testing/phase6_comprehensive_execution/evidence/dumpsys_permissions_parent.txt` | `emulator-5554` | Dumpsys package permissions snapshot for Parent emulator |
| EVD-011 | `docs/testing/phase6_comprehensive_execution/evidence/dumpsys_permissions_child.txt` | `5HXWRGQ4IFU8WS4T` | Dumpsys package permissions and AppOps snapshot for Child hardware |
