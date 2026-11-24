# 05 — Additional Manual Test Cases

**Document ID:** `HAVEN-GAP-005`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline Suite:** `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md` (35 Baseline Tests)  
**Expansion Scope:** 58 Granularized Manual Test Cases (`TC-EXP-01` through `TC-EXP-58`)  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Test Suite Architecture & Schema Standards

Every additional test case in this master catalog has been specified according to the rigorous 20-point enterprise testing schema. Non-developer owners and QA engineers can follow each test case sequentially.

> [!CRITICAL]
> **Zero Runtime Execution Standard**: In compliance with the Phase 2 audit scope, **zero test cases have been executed**. Every entry has:
> - `Actual Result: NOT TESTED`
> - `Status: NOT TESTED`

---

## 2. Group 1: Role Selection & Authentication Boundaries

### TC-EXP-01: Role Assignment Persistence and Immutability
- **Test ID**: `TC-EXP-01`
- **Test Name**: Role Selection Persistence and Route Redirection
- **Functionality ID(s)**: `A06`
- **Category / Subsystem**: Authentication / Onboarding
- **Target Role**: Shared
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_ACCOUNT`
- **Test Type**: Functional UI / Security Boundary
- **Purpose**: Verify that selecting a role permanently binds the profile in the database and locks the user out of role selection upon subsequent app launches.
- **Preconditions**: Freshly registered account with email verified, but role selection incomplete (`profiles.role` is NULL).
- **Required Test Fixtures**: Disposable test account `test_role_user@haven.test`.
- **Steps**:
  1. Launch app and log in as `test_role_user@haven.test`.
  2. On `/role-selection`, enter Display Name "Parent Tester".
  3. Tap the "Parent Mode" card.
  4. Tap "Confirm Selection" button.
  5. Verify routing to `/family-setup` or `/parent-dashboard`.
  6. Force close the app via Android Recents and relaunch.
  7. Press Android system back button on the dashboard.
- **Expected Result**: Relaunch lands directly on `/parent-dashboard` without showing `/role-selection`. System back button does NOT return to role selection.
- **Failure Conditions**: App shows role selection screen again, allows re-selecting role, or back button pops to role selection.
- **Evidence to Capture**: Screenshot of dashboard after relaunch; database record in `profiles` where `role = 'parent'`.
- **Cleanup / Teardown Procedure**: Delete disposable user account after test run.
- **Destructive Potential**: Yes (binds role permanently to account).
- **Dependencies**: `A01`, `A02`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-02: Authentication Negative Paths & Lockout Handling
- **Test ID**: `TC-EXP-02`
- **Test Name**: Login Invalid Password and Rate Limiting
- **Functionality ID(s)**: `A01`
- **Category / Subsystem**: Authentication
- **Target Role**: Shared
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Negative / Security Boundary
- **Purpose**: Verify client displays appropriate error messages on incorrect credentials and does not crash or expose raw backend exceptions.
- **Preconditions**: Valid parent account exists.
- **Required Test Fixtures**: Account `valid_parent@haven.test`.
- **Steps**:
  1. Open Haven app on `/login`.
  2. Enter `valid_parent@haven.test`.
  3. Enter incorrect password `WrongPassword123!`.
  4. Tap "Sign In" button.
  5. Observe error banner / snackbar.
  6. Repeat rapid invalid submissions 5 consecutive times.
- **Expected Result**: App displays clean error message: "Invalid email or password". Submit button disables briefly during network call. Consecutive failures trigger rate-limit warning without app crashing.
- **Failure Conditions**: Raw JSON exception or Supabase error stack visible in UI; app freezes or crashes.
- **Evidence to Capture**: Screenshot of error snackbar.
- **Cleanup / Teardown Procedure**: None.
- **Destructive Potential**: No.
- **Dependencies**: `A01`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-03: Registration Form Validation & Duplicate Email Handling
- **Test ID**: `TC-EXP-03`
- **Test Name**: Registration Duplicate Email Rejection
- **Functionality ID(s)**: `A02`, `A12`
- **Category / Subsystem**: Authentication / Form Validation
- **Target Role**: Shared
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Negative / Validation
- **Purpose**: Verify registration rejects an email address that is already registered.
- **Preconditions**: Existing registered user `existing_user@haven.test`.
- **Required Test Fixtures**: `existing_user@haven.test`.
- **Steps**:
  1. Navigate to `/register` screen.
  2. Enter `existing_user@haven.test`.
  3. Enter password `SecurePass123!`.
  4. Enter confirm password `SecurePass123!`.
  5. Tap "Create Account".
- **Expected Result**: System rejects registration and displays: "An account with this email already exists". Form inputs retain entered values.
- **Failure Conditions**: Screen transitions to email confirmation as if new account created; unhandled server error.
- **Evidence to Capture**: Screenshot of registration form error message.
- **Cleanup / Teardown Procedure**: None.
- **Destructive Potential**: No.
- **Dependencies**: `A02`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-04: GDPR Data Export Payload Schema Validation
- **Test ID**: `TC-EXP-04`
- **Test Name**: Account Data Export Structure Verification
- **Functionality ID(s)**: `A08`
- **Category / Subsystem**: Account Management / Privacy
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_ACCOUNT`
- **Test Type**: Data Verification / Privacy
- **Purpose**: Verify that GDPR data export contains complete JSON schema with profile, devices, location history, and audit records.
- **Preconditions**: Parent account active with at least 1 child device, 3 location events, and 5 audit logs.
- **Required Test Fixtures**: Populated test parent account.
- **Steps**:
  1. Log into Parent app.
  2. Open Settings -> Account & Privacy -> "Export My Data".
  3. Tap "Request Export" and confirm dialog.
  4. Wait for export JSON payload generation.
  5. Open or download the exported JSON file.
  6. Inspect JSON top-level keys: `profile`, `devices`, `location_history`, `audit_events`.
- **Expected Result**: Export generates a valid JSON file. Top-level keys contain non-empty arrays matching test account activity.
- **Failure Conditions**: JSON generation fails with 500 error; exported file is empty or missing required schema keys.
- **Evidence to Capture**: Exported JSON file content snippet (redacting sensitive hashes).
- **Cleanup / Teardown Procedure**: Delete exported file from device storage.
- **Destructive Potential**: No.
- **Dependencies**: `A08`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-05: Child Device Hardware Metadata Capture
- **Test ID**: `TC-EXP-05`
- **Test Name**: Child Device Model and OS Metadata Registration
- **Functionality ID(s)**: `FAM07`
- **Category / Subsystem**: Pairing / Hardware Discovery
- **Target Role**: Child / Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_DEVICE`
- **Test Type**: Distributed Hardware Validation
- **Purpose**: Verify that during pairing, child device hardware model, Android SDK level, and manufacturer are accurately recorded and displayed to parent.
- **Preconditions**: Parent app open; child device on pairing screen.
- **Required Test Fixtures**: Physical Android test device (e.g., Pixel 6, Android 13).
- **Steps**:
  1. Complete pairing handshake via QR or manual code.
  2. On Parent device, navigate to Parent Dashboard -> Devices tab.
  3. Tap the newly paired child device card to open Device Details.
  4. Inspect "Hardware Information" tile.
- **Expected Result**: Device detail page displays accurate Manufacturer (e.g., "Google"), Model (e.g., "Pixel 6"), and OS Version (e.g., "Android 13 / API 33").
- **Failure Conditions**: Hardware fields display "Unknown", "Generic Android", or blank.
- **Evidence to Capture**: Screenshot of Parent Device Details hardware tile alongside Android "About Phone" settings on child device.
- **Cleanup / Teardown Procedure**: Unlink device.
- **Destructive Potential**: Yes (device enrollment).
- **Dependencies**: `FAM01` or `FAM02`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-06: Whitelist Mode Emergency App Bypass
- **Test ID**: `TC-EXP-06`
- **Test Name**: Whitelist Mode Emergency Phone Bypass Verification
- **Functionality ID(s)**: `APP02`, `CHD09`
- **Category / Subsystem**: App Management / Child Safety
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Safety Critical / Boundary
- **Purpose**: Verify that when Whitelist Mode is active, native phone dialer and emergency dialer are NEVER blocked.
- **Preconditions**: Child device enrolled; Parent enables "Whitelist Mode" (blocking all non-whitelisted apps).
- **Required Test Fixtures**: Paired child device.
- **Steps**:
  1. Parent enables Whitelist Mode with only 1 allowed app (e.g., Calculator).
  2. Save policy and confirm child status is "Synced".
  3. On Child device, attempt to open YouTube (should be blocked).
  4. On Child device, tap the native Phone app icon or tap "Call Parent" emergency button.
- **Expected Result**: YouTube displays Haven block overlay. Native Phone dialer opens immediately without being intercepted or blocked.
- **Failure Conditions**: Native dialer is intercepted by Haven block overlay, preventing emergency outgoing call.
- **Evidence to Capture**: Screenshot of block screen on YouTube followed by screenshot of open dialer.
- **Cleanup / Teardown Procedure**: Disable Whitelist Mode on parent app.
- **Destructive Potential**: No.
- **Dependencies**: `APP02`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-07: Child Remote Assistance Incoming Call Dialog
- **Test ID**: `TC-EXP-07`
- **Test Name**: Child Incoming Remote Call Notification & Dialog
- **Functionality ID(s)**: `REM02`
- **Category / Subsystem**: Remote Assistance
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Real-Time Interconnected / Media
- **Purpose**: Verify child device receives incoming call prompt with Parent name, ringing audio/vibration, and Accept/Decline options.
- **Preconditions**: Parent and Child devices online and paired. Child app in foreground or background.
- **Required Test Fixtures**: Two physical test devices.
- **Steps**:
  1. Parent taps "Start Remote Session" on Child device card.
  2. Observe Child device screen within 5 seconds.
  3. Inspect incoming call dialog: Displays Parent name, camera icon, "Accept" (green button) and "Decline" (red button).
  4. Tap "Decline" button on Child device.
- **Expected Result**: Dialog renders immediately on Child screen. Tapping "Decline" closes dialog, sends rejection signaling to parent, and parent screen displays "Call Declined by Child".
- **Failure Conditions**: Child never receives call; dialog fails to render; parent screen hangs on "Calling..." indefinitely.
- **Evidence to Capture**: Screenshots of Child incoming call dialog and Parent call declined notification.
- **Cleanup / Teardown Procedure**: None.
- **Destructive Potential**: No.
- **Dependencies**: `REM01`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

### TC-EXP-08: WebRTC Live Audio/Video Bidirectional Streaming
- **Test ID**: `TC-EXP-08`
- **Test Name**: WebRTC Two-Way Audio and Video Streaming
- **Functionality ID(s)**: `REM03`
- **Category / Subsystem**: Remote Assistance / WebRTC
- **Target Role**: Interconnected
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Hardware / Network Streaming
- **Purpose**: Verify that accepting a remote assistance call establishes a WebRTC peer connection with live bidirectional video and audio.
- **Preconditions**: Both devices grant Camera and Mic permissions; Parent initiates call; Child receives call.
- **Required Test Fixtures**: Two physical devices with working cameras/mics.
- **Steps**:
  1. Parent initiates remote call.
  2. Child taps "Accept".
  3. Wait 3–5 seconds for ICE candidates exchange and peer connection handshake.
  4. Parent inspects video feed from Child device.
  5. Child inspects video feed from Parent device.
  6. Speak into Child microphone and verify audio on Parent speaker.
- **Expected Result**: Live video streams render in real time on both devices without freezing; audio is audible in both directions.
- **Failure Conditions**: Black screen; WebRTC state stays "Connecting"; audio feedback loop or silent stream.
- **Evidence to Capture**: Screenshots of active video call on both parent and child screens.
- **Cleanup / Teardown Procedure**: End call.
- **Destructive Potential**: No.
- **Dependencies**: `REM01`, `REM02`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`

---

## 3. Group 2: Outgoing Pairing, Consent & Family Oversight

### TC-EXP-09: Email Verification Resend Throttling
- **Test ID**: `TC-EXP-09`
- **Test Name**: Email Verification Resend and Rate Throttling
- **Functionality ID(s)**: `A03`
- **Category / Subsystem**: Authentication
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_ACCOUNT`
- **Test Type**: Negative / Functional UI
- **Purpose**: Verify resend button sends a fresh verification email and prevents spamming via a 60-second cooldown timer.
- **Preconditions**: Freshly registered unverified account on `/verify-email`.
- **Steps**:
  1. On email verification screen, observe "Resend Email" button.
  2. Tap "Resend Email".
  3. Verify snackbar: "Verification email resent".
  4. Observe button disabled with countdown timer (e.g. "Resend in 59s...").
  5. Attempt to tap button again during countdown.
- **Expected Result**: Button cannot be tapped during countdown; fresh verification email received.
- **Failure Conditions**: Button can be spammed repeatedly; timer missing.
- **Evidence to Capture**: Screenshot of verification screen showing countdown timer.
- **Cleanup / Teardown Procedure**: Delete unverified account.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-10: Account Profile Display and Display Name Update
- **Test ID**: `TC-EXP-10`
- **Test Name**: Update Parent Display Name in Settings
- **Functionality ID(s)**: `A07`
- **Category / Subsystem**: Account Management
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Functional UI / Persistence
- **Purpose**: Verify parent can view and update their profile display name and that it updates across the application.
- **Preconditions**: Signed in as Parent.
- **Steps**:
  1. Open Settings -> Profile.
  2. Inspect current display name and email (email should be read-only).
  3. Tap "Edit Name", change name to "Guardian One", tap Save.
  4. Return to Dashboard tab.
- **Expected Result**: Snackbar confirms name updated. Dashboard greeting displays "Welcome, Guardian One".
- **Failure Conditions**: Name reverts after reload; save fails.
- **Evidence to Capture**: Screenshot of updated profile in settings.
- **Cleanup / Teardown Procedure**: Restore original display name.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-11: Registration & Login Form Real-Time Validation
- **Test ID**: `TC-EXP-11`
- **Test Name**: Input Validation Feedback on Auth Forms
- **Functionality ID(s)**: `A12`
- **Category / Subsystem**: Core Widgets / Validators
- **Target Role**: Shared
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Validation UI
- **Purpose**: Verify inline field validation displays red helper text when inputs are invalid.
- **Preconditions**: App on `/login` or `/register`.
- **Steps**:
  1. On `/login`, type `invalid-email-format` into email field and unfocus.
  2. Type `123` into password field and unfocus.
  3. On `/register`, leave Display Name blank, enter mismatched passwords.
- **Expected Result**: Red error text displays: "Please enter a valid email", "Password must be at least 8 characters", "Passwords do not match". Submit button disabled or validation blocks submission.
- **Failure Conditions**: Form submits malformed email to backend; errors fail to render.
- **Evidence to Capture**: Screenshots of invalid field states with red validation labels.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-12: Outgoing Pairing Requests List Rendering
- **Test ID**: `TC-EXP-12`
- **Test Name**: Pending Pairing Invitations Roster
- **Functionality ID(s)**: `FAM03`
- **Category / Subsystem**: Pairing
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can view active pending pairing invitations with created timestamps and expiration status.
- **Preconditions**: Parent has generated at least one pairing code within 15 minutes.
- **Steps**:
  1. Open Family Settings -> "Pending Pairing Requests".
  2. Inspect table/list of active codes.
- **Expected Result**: Displays list of pending invitations showing child nickname, 6-digit code, status "Active", and expiration timer.
- **Failure Conditions**: List blank; expired codes show as active.
- **Evidence to Capture**: Screenshot of Pending Pairing Requests page.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-13: Cancel Outgoing Pairing Request
- **Test ID**: `TC-EXP-13`
- **Test Name**: Revoke Pending Pairing Code Before Redemption
- **Functionality ID(s)**: `FAM04`
- **Category / Subsystem**: Pairing
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Functional UI / Security
- **Purpose**: Verify parent can cancel an unredeemed pairing invitation so child device cannot redeem it.
- **Preconditions**: Pending pairing invitation generated.
- **Steps**:
  1. In Pending Pairing Requests, tap "Cancel" / "Revoke" icon next to code.
  2. Confirm cancellation dialog.
  3. On Child device, attempt to redeem the canceled 6-digit code.
- **Expected Result**: Code status changes to "Revoked" or row removed from parent list. Child device displays: "Invalid or expired pairing code".
- **Failure Conditions**: Child successfully redeems revoked code.
- **Evidence to Capture**: Screenshot of parent revoked state and child rejection message.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-14: Child Pairing Enrollment Consent and Cancellation
- **Test ID**: `TC-EXP-14`
- **Test Name**: Child Enrollment Consent Screen Cancel Action
- **Functionality ID(s)**: `FAM05`
- **Category / Subsystem**: Pairing / Consent
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_DEVICE`
- **Test Type**: Functional UI / Workflow
- **Purpose**: Verify child can review pairing details (Family Name, Parent Name) and cancel before enrollment completes.
- **Preconditions**: Child enters valid code; lands on "Confirm Family Pairing" consent dialog.
- **Steps**:
  1. Scan QR code or enter code on child app.
  2. On consent screen, inspect Family Name and Parent Name.
  3. Tap "Cancel" button.
- **Expected Result**: Enrollment stops. No device keys registered in Keystore. App returns to enrollment welcome screen.
- **Failure Conditions**: Device silently registers in background despite tapping Cancel.
- **Evidence to Capture**: Screenshot of consent dialog and return to welcome screen.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-15: Family Roster and Role Hierarchy View
- **Test ID**: `TC-EXP-15`
- **Test Name**: Family Management Members and Roles List
- **Functionality ID(s)**: `FAM09`
- **Category / Subsystem**: Family Management
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can view all members belonging to the family, distinguishing Primary Guardian, Secondary Guardian, and Children.
- **Preconditions**: Family created with at least 1 parent and 1 child.
- **Steps**:
  1. Navigate to Settings -> Family Members.
  2. Inspect member cards.
- **Expected Result**: Renders list of family members with avatars, display names, email, and role badges ("Admin", "Child").
- **Failure Conditions**: Member list crashes or missing paired children.
- **Evidence to Capture**: Screenshot of Family Members list.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-16: Child App Self-Unlink Guard and PIN Gate
- **Test ID**: `TC-EXP-16`
- **Test Name**: Child Self-Unlink Prevention and Parent PIN Challenge
- **Functionality ID(s)**: `FAM11`
- **Category / Subsystem**: Child Protection / Anti-Tamper
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Security Guard / Anti-Tamper
- **Purpose**: Verify child cannot unlink device or clear app data without entering the Parent Security PIN.
- **Preconditions**: Paired child device running Haven.
- **Steps**:
  1. On Child app, navigate to Settings tab.
  2. Locate "Unlink Device" or "Reset Haven" button.
  3. If present, tap the button.
  4. If Parent PIN modal appears, enter incorrect PIN `0000`.
- **Expected Result**: Unlink button is either completely hidden in Child mode, or requires Parent PIN. Entering incorrect PIN denies action and logs tamper attempt.
- **Failure Conditions**: Child can unlink device with single tap without parental authorization.
- **Evidence to Capture**: Screenshot of PIN challenge or settings screen without unlink option.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-17: Parent Device Revocation and Child Session Invalidation
- **Test ID**: `TC-EXP-17`
- **Test Name**: Revoke Child Device from Dashboard
- **Functionality ID(s)**: `FAM12`
- **Category / Subsystem**: Device Management / Security
- **Target Role**: Parent
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `REQUIRES_DISPOSABLE_DEVICE`
- **Test Type**: Distributed Security Revocation
- **Purpose**: Verify revoking a child device updates status to `revoked` in Supabase and terminates child daemon sync.
- **Preconditions**: Paired child device online.
- **Steps**:
  1. On Parent app, open Device Details.
  2. Tap "Revoke Device Access" in danger zone.
  3. Enter confirmation phrase "REVOKE" and confirm.
  4. Observe Parent UI status transitions to "Revoked".
  5. On Child device, observe app within 15 seconds.
- **Expected Result**: Child app receives revocation push, revokes Keystore credentials, displays "Device Access Revoked by Parent", and halts background services.
- **Failure Conditions**: Child app continues running in protected mode; background daemons continue transmitting heartbeats.
- **Evidence to Capture**: Screenshots of Parent revoked badge and Child revocation screen.
- **Cleanup / Teardown Procedure**: Re-enroll device for future tests.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-18: Device Re-Credentialing Recovery Challenge Flow
- **Test ID**: `TC-EXP-18`
- **Test Name**: Re-Credential Child Device via Recovery Challenge
- **Functionality ID(s)**: `FAM13`
- **Category / Subsystem**: Recovery / Cryptography
- **Target Role**: Interconnected
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `REQUIRES_ISOLATED_BACKEND`
- **Test Type**: Recovery Flow
- **Purpose**: Verify a paired child device that lost local keystore credentials can restore connection via parent recovery challenge without re-registering as a new device.
- **Preconditions**: Existing device in `devices` table; app reinstalled on child phone.
- **Steps**:
  1. On Parent app, open Device Details -> "Generate Recovery Code".
  2. Note 6-character recovery token.
  3. On Child app, tap "Recover Existing Device", enter Device ID and recovery token.
  4. Submit recovery form.
- **Expected Result**: Backend validates challenge, binds new device public key, and child device resumes supervision under existing `device_id` without duplicating device records.
- **Failure Conditions**: Re-credentialing fails or creates duplicate device record in database.
- **Evidence to Capture**: Database verification showing same `device_id` with updated public key and status `active`.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-19: Family Settings Update Backend API Verification
- **Test ID**: `TC-EXP-19`
- **Test Name**: Family Settings API Configuration Update
- **Functionality ID(s)**: `FAM14`
- **Category / Subsystem**: Family Backend
- **Target Role**: Backend
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `REQUIRES_ISOLATED_BACKEND`
- **Test Type**: Backend API Integration
- **Purpose**: Verify `updateSettings()` in `supabase_family_repository.dart` correctly updates JSONB `settings` in Supabase `families` table.
- **Preconditions**: Authenticated Parent session.
- **Steps**:
  1. Dispatch API call or repository method to update family timezone or alert preferences.
  2. Query `families.settings` column in database.
- **Expected Result**: Database row updates with new settings JSON; timestamp `updated_at` refreshed.
- **Failure Conditions**: 403 Forbidden or SQL constraint violation.
- **Evidence to Capture**: Database query result.
- **Cleanup / Teardown Procedure**: Restore default settings.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 4. Group 3: Parent Monitoring, Telemetry & Diagnostics

### TC-EXP-20: Connected Devices List and Status Cards
- **Test ID**: `TC-EXP-20`
- **Test Name**: Multi-Device List Rendering on Parent App
- **Functionality ID(s)**: `MON02`
- **Category / Subsystem**: Devices
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can view multiple connected child devices with individual status cards, battery level, and sync badges.
- **Preconditions**: At least two child devices paired.
- **Steps**:
  1. Open Parent app -> Devices tab.
  2. Inspect devices list.
- **Expected Result**: Renders distinct cards for each child device displaying child nickname, device model, battery percentage icon, and last seen timestamp.
- **Failure Conditions**: Devices overlap or only first device renders.
- **Evidence to Capture**: Screenshot of Devices tab showing multiple device cards.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-21: Child Permission Diagnostics Remote View
- **Test ID**: `TC-EXP-21`
- **Test Name**: Remote Inspection of Child Android OS Permissions
- **Functionality ID(s)**: `MON05`
- **Category / Subsystem**: Diagnostics / Telemetry
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Telemetry Presentation
- **Purpose**: Verify parent can inspect the current status of all 4 required child permissions (Accessibility, Device Admin, Usage Stats, Location).
- **Preconditions**: Paired child device has uploaded telemetry.
- **Steps**:
  1. Open Device Details -> Permissions Diagnostics tab.
  2. Inspect status indicators for: Device Admin, Usage Access, Location Permission, Battery Optimization Ignored.
- **Expected Result**: Each permission displays an individual green check ("Granted") or amber/red alert ("Revoked/Missing") with explanatory text.
- **Failure Conditions**: All permissions show "Unknown" or UI fails to reflect actual device state.
- **Evidence to Capture**: Screenshot of Permission Diagnostics tab.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-22: Command Delivery and ACK History Log
- **Test ID**: `TC-EXP-22`
- **Test Name**: Inspect Device Remote Command Audit Trail
- **Functionality ID(s)**: `MON06`
- **Category / Subsystem**: Command & Control
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Telemetry Audit
- **Purpose**: Verify parent can view historical commands sent to child device (e.g. `SYNC_POLICIES`, `LOCK_DEVICE`) and their delivery/ACK status.
- **Preconditions**: At least 2 commands dispatched to child device.
- **Steps**:
  1. Open Device Details -> Command History.
  2. Inspect chronological command entries.
- **Expected Result**: Renders list of commands with Command Type, Dispatched Timestamp, Acknowledged Timestamp, and Status Badge ("Delivered", "Acknowledged", "Failed").
- **Failure Conditions**: Commands missing or timestamps invalid.
- **Evidence to Capture**: Screenshot of Command History page.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-23: Installed Apps Snapshot Upload Verification
- **Test ID**: `TC-EXP-23`
- **Test Name**: Native Installed Applications List Snapshot
- **Functionality ID(s)**: `MON07`
- **Category / Subsystem**: Monitoring / Native Android
- **Target Role**: Child / Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Native Data Flow
- **Purpose**: Verify child native module (`InstalledApps.kt`) queries PackageManager, filters system packages, and uploads user apps to backend.
- **Preconditions**: Child device enrolled with 5+ third-party apps installed.
- **Steps**:
  1. Launch child app to trigger installed apps sync.
  2. On Parent device, open App Restrictions page for this child.
  3. Compare displayed apps with apps installed on child phone.
- **Expected Result**: All user-installed apps (e.g., YouTube, Chrome, Games) appear in parent app list with correct display names and package icons.
- **Failure Conditions**: Installed apps list empty or shows only core Android OS packages.
- **Evidence to Capture**: Screenshot of parent App Restrictions list matching child launcher icons.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-24: Parent Dashboard Pull-to-Refresh
- **Test ID**: `TC-EXP-24`
- **Test Name**: Dashboard Manual Refresh via Swipe Gesture
- **Functionality ID(s)**: `MON08`
- **Category / Subsystem**: Dashboard
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify swiping down on the parent dashboard triggers a manual data refresh and updates timestamps.
- **Preconditions**: Parent dashboard open.
- **Steps**:
  1. Swipe down from top of Parent Dashboard.
  2. Observe pull-to-refresh spinner.
  3. Wait for spinner to complete.
- **Expected Result**: Spinner appears, fetches latest summary metrics, and dismisses smoothly without layout jumps.
- **Failure Conditions**: Pull gesture unresponsive or spinner spins indefinitely.
- **Evidence to Capture**: Screen recording or sequential screenshots.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-25: Policy Sync Health Badge Transitions
- **Test ID**: `TC-EXP-25`
- **Test Name**: Visual Policy Sync Status Badge Updates
- **Functionality ID(s)**: `MON09`
- **Category / Subsystem**: Presentation
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Presentation State
- **Purpose**: Verify device card displays Amber "Sync Pending" immediately after a policy change and transitions to Green "In Sync" once ACK is received.
- **Preconditions**: Paired child device online.
- **Steps**:
  1. Change app restriction rule on Parent app and tap Save.
  2. Immediately navigate to Device Card on Dashboard.
  3. Observe sync badge: Verify Amber "Sync Pending".
  4. Wait 5–10 seconds for child ACK.
  5. Observe sync badge: Verify Green "In Sync".
- **Expected Result**: Badge updates smoothly through state transitions without requiring manual app restart.
- **Failure Conditions**: Badge remains Amber indefinitely or fails to show pending state.
- **Evidence to Capture**: Screenshots of Amber pending and Green synced badge states.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-26: Device Filter Toggle: Active vs Revoked
- **Test ID**: `TC-EXP-26`
- **Test Name**: Filter Devices Tab by Status
- **Functionality ID(s)**: `MON10`
- **Category / Subsystem**: Devices
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify toggle filter switches between Active devices and Revoked/Historical devices.
- **Preconditions**: Family has at least 1 active device and 1 revoked device.
- **Steps**:
  1. Open Devices tab.
  2. Tap filter chip "Revoked".
  3. Inspect list.
  4. Tap filter chip "Active".
- **Expected Result**: "Revoked" filter shows only revoked devices with revocation date. "Active" shows only online/enrolled devices.
- **Failure Conditions**: Filter chips unresponsive or mix active and revoked devices together.
- **Evidence to Capture**: Screenshots of filtered list views.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 5. Group 4: Screen Time, Bedtime & App Restrictions

### TC-EXP-27: Child Usage Access Permission Guidance Banner
- **Test ID**: `TC-EXP-27`
- **Test Name**: Usage Access Guidance Prompt on Child Device
- **Functionality ID(s)**: `USE03`
- **Category / Subsystem**: Permissions / Child UI
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Permission Guidance
- **Purpose**: Verify that when `PACKAGE_USAGE_STATS` is missing, child app displays prominent warning banner and button leading directly to Android Settings.
- **Preconditions**: Fresh child install with Usage Access disabled.
- **Steps**:
  1. Launch Child app.
  2. Observe warning banner on Rules tab: "Usage Access Permission Required".
  3. Tap "Enable Usage Access" button.
- **Expected Result**: Directly opens Android system "Usage Access" settings screen highlighting Haven app. Granting permission removes banner upon return.
- **Failure Conditions**: Button does not open Settings; banner persists after permission is granted.
- **Evidence to Capture**: Screenshot of guidance banner and native Settings transition.
- **Cleanup / Teardown Procedure**: Keep permission enabled.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-28: Native Usage Stats Collection and Background Upload
- **Test ID**: `TC-EXP-28`
- **Test Name**: Hourly Usage Reporter Daemon Verification
- **Functionality ID(s)**: `USE04`
- **Category / Subsystem**: Usage Reporter / Native
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Background Daemon
- **Purpose**: Verify `UsageReporter.kt` queries `UsageStatsManager` and uploads aggregated app usage durations to Supabase `app_usage_events`.
- **Preconditions**: Usage Access granted; child uses an app (e.g. Chrome) for 5 minutes.
- **Steps**:
  1. Open and use Chrome on child phone for 5 minutes.
  2. Trigger usage sync or wait for hourly background task.
  3. Query database table `app_usage_events` for this device.
- **Expected Result**: Database contains record for `com.android.chrome` with `duration_seconds >= 300`.
- **Failure Conditions**: Zero rows inserted; usage durations recorded as 0.
- **Evidence to Capture**: Database query result or ADB logcat trace of `UsageReporter.kt`.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-29: Bedtime Schedule Setup and Nightly Boundary Enforcement
- **Test ID**: `TC-EXP-29`
- **Test Name**: Bedtime Lockout Schedule Configuration
- **Functionality ID(s)**: `USE06`
- **Category / Subsystem**: Screen Time / Bedtime
- **Target Role**: Parent / Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Time-Boundary Enforcement
- **Purpose**: Verify parent can configure Bedtime (e.g., 21:00 to 07:00) and that child device enforces bedtime lockout during scheduled hours.
- **Preconditions**: Paired child device.
- **Steps**:
  1. On Parent app, open Screen Time -> Bedtime Schedule.
  2. Set Bedtime start to 5 minutes ahead of current time, end time 1 hour ahead.
  3. Save policy and confirm child receives policy.
  4. Wait until bedtime start time arrives on child device clock.
  5. Attempt to use child device.
- **Expected Result**: At bedtime start time, child device displays full-screen Bedtime lock overlay: "It's Bedtime. Device is locked until 07:00". Only emergency call action is accessible.
- **Failure Conditions**: Bedtime lock fails to trigger; child can bypass lock and open games.
- **Evidence to Capture**: Screenshot of Bedtime lock screen on child phone.
- **Cleanup / Teardown Procedure**: Disable bedtime schedule on parent app.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-30: Child Home Remaining Time Live Calculation
- **Test ID**: `TC-EXP-30`
- **Test Name**: Real-Time Remaining Quota Countdown
- **Functionality ID(s)**: `USE07`
- **Category / Subsystem**: Child UI
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Real-Time UI Calculation
- **Purpose**: Verify child home screen displays accurate remaining daily screen time (Daily Quota minus Today's Total Usage).
- **Preconditions**: Daily quota set to 2h 00m; recorded usage is 45m.
- **Steps**:
  1. Open Child Home tab.
  2. Inspect Screen Time card.
- **Expected Result**: Displays "1h 15m remaining today" with circular progress bar at 37.5% used.
- **Failure Conditions**: Displays negative time, NaN, or raw seconds.
- **Evidence to Capture**: Screenshot of Child Home Screen Time card.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-31: Daily Quota Expiry Full-Screen Lock Overlay
- **Test ID**: `TC-EXP-31`
- **Test Name**: Quota Exhaustion Lock Screen Trigger
- **Functionality ID(s)**: `USE08`
- **Category / Subsystem**: Screen Time / Lock Screen
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Enforcement Overlay
- **Purpose**: Verify that when daily screen time quota is completely exhausted, child phone displays an un-dismissable lock overlay with a "Request More Time" button.
- **Preconditions**: Daily quota set to 1 minute for testing purposes.
- **Steps**:
  1. Set daily quota to 1 minute on parent app.
  2. Use child device actively for 65 seconds.
  3. Observe lock overlay appearance.
  4. Attempt to press Android Home and Back buttons.
- **Expected Result**: Full-screen lock overlay appears: "Daily Screen Time Limit Reached". Home and Back gestures re-open or stay on lock screen. "Request More Time" button opens request modal.
- **Failure Conditions**: Child can swipe away lock overlay or access apps via Android Recents.
- **Evidence to Capture**: Screenshot of quota lock screen.
- **Cleanup / Teardown Procedure**: Increase daily quota to 2 hours.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-32: App Whitelist Selection and Category Filtering
- **Test ID**: `TC-EXP-32`
- **Test Name**: Whitelist Apps Selection by Category
- **Functionality ID(s)**: `APP03`
- **Category / Subsystem**: App Restrictions
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can add or remove apps from the allowed whitelist and filter apps by category (Education, Entertainment, Games).
- **Preconditions**: Child installed apps populated.
- **Steps**:
  1. Open App Restrictions -> Whitelist Mode.
  2. Filter by "Education" category.
  3. Select Duolingo and Khan Academy.
  4. Tap "Save Allowed Apps".
- **Expected Result**: Selected apps save to database policy; whitelist counter updates to "2 Apps Allowed".
- **Failure Conditions**: Selections not saved or lost on category switch.
- **Evidence to Capture**: Screenshot of Whitelist configuration screen.
- **Cleanup / Teardown Procedure**: Reset whitelist.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-33: Manual Policy Force-Sync Command
- **Test ID**: `TC-EXP-33`
- **Test Name**: Dispatch Manual Policy Force-Sync from Parent
- **Functionality ID(s)**: `APP06`
- **Category / Subsystem**: Command & Control
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Distributed Command
- **Purpose**: Verify parent can tap "Sync Policies Now" to immediately force child device to pull latest rules without waiting for next heartbeat.
- **Preconditions**: Paired child device online.
- **Steps**:
  1. Open Device Details for child device.
  2. Tap "Sync Policies Now" in action menu.
  3. Observe snackbar confirmation.
  4. Observe Child device logcat or UI within 3 seconds.
- **Expected Result**: Parent receives: "Sync command dispatched". Child immediately fetches latest policy JSON and replies with ACK.
- **Failure Conditions**: Command fails or child does not react until regular polling interval.
- **Evidence to Capture**: ADB logcat trace on child showing immediate policy fetch.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-34: App Restrictions Search and Package Filtering
- **Test ID**: `TC-EXP-34`
- **Test Name**: Search App Restrictions List by App Name
- **Functionality ID(s)**: `APP08`
- **Category / Subsystem**: App Restrictions UI
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can type an app name into the search bar on the App Restrictions page to quickly locate specific apps among 50+ items.
- **Preconditions**: At least 10 apps in restrictions list.
- **Steps**:
  1. Open App Restrictions page.
  2. Tap search bar and type "You".
  3. Inspect filtered list.
  4. Clear search bar.
- **Expected Result**: List filters dynamically to show matching apps (e.g., YouTube); clearing search restores full list.
- **Failure Conditions**: Search is case-sensitive or fails to filter list.
- **Evidence to Capture**: Screenshot of search results.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 6. Group 5: Location Breadcrumbs, Geofencing & Alerts Dispatch

### TC-EXP-35: 24-Hour Location History Route Playback
- **Test ID**: `TC-EXP-35`
- **Test Name**: View 24-Hour Location History Breadcrumb Trail
- **Functionality ID(s)**: `LOC02`
- **Category / Subsystem**: Location
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Geospatial Presentation
- **Purpose**: Verify parent can view the chronological location history polyline and tap individual breadcrumb pins to inspect timestamps and speeds.
- **Preconditions**: Child device with 5+ recorded location events over past 24 hours.
- **Steps**:
  1. Open Location tab on Parent app.
  2. Tap "History" toggle/tab.
  3. Select "Past 24 Hours".
  4. Tap an intermediate breadcrumb pin on the route.
- **Expected Result**: Map renders blue polyline connecting location points chronologically. Tapping a pin opens bottom card with Time, Speed, and reverse-geocoded address.
- **Failure Conditions**: Polyline jumps randomly or history tab shows blank map.
- **Evidence to Capture**: Screenshot of location history route and point detail card.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-36: Child Location Sharing Privacy Toggle
- **Test ID**: `TC-EXP-36`
- **Test Name**: Child Location Sharing Switch Enforcement
- **Functionality ID(s)**: `LOC03`
- **Category / Subsystem**: Location / Privacy
- **Target Role**: Child / Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Policy / Privacy Enforcement
- **Purpose**: Verify child device settings UI displays location sharing status and enforces parental override if locked by policy.
- **Preconditions**: Paired child device.
- **Steps**:
  1. Open Child app -> Settings -> Location Sharing.
  2. Observe toggle switch state.
  3. If parent policy enforces location sharing, attempt to disable toggle.
- **Expected Result**: Toggle is either locked with a padlock icon ("Required by Parent"), or disabling triggers parent alert notification.
- **Failure Conditions**: Child can silently disable location tracking without parent notification.
- **Evidence to Capture**: Screenshot of child location settings toggle.
- **Cleanup / Teardown Procedure**: Ensure sharing is active.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-37: Continuous Background Location Daemon Tracking
- **Test ID**: `TC-EXP-37`
- **Test Name**: Background Location Service Tracking and Upload
- **Functionality ID(s)**: `LOC04`
- **Category / Subsystem**: Location / Native Android
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Native Android Service
- **Purpose**: Verify `LocationTrackingService.kt` acquires GPS fixes and uploads coordinates to `location_events` when phone screen is OFF and locked.
- **Preconditions**: Child phone running Haven; location permission set to "Allow all the time".
- **Steps**:
  1. Lock child phone and leave screen OFF for 10 minutes while moving or simulating location change.
  2. Query `location_events` table in database.
- **Expected Result**: New location rows inserted with timestamps recorded while device was locked.
- **Failure Conditions**: Location fixes cease as soon as screen turns off (battery throttling unhandled).
- **Evidence to Capture**: Database timestamp log showing background events.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-38: Geofence Exit Telemetry Alert Trigger
- **Test ID**: `TC-EXP-38`
- **Test Name**: Safe Zone Geofence Breach Alert Dispatch
- **Functionality ID(s)**: `LOC06`
- **Category / Subsystem**: Geofencing / Alerts
- **Target Role**: Interconnected
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Distributed Event Trigger
- **Purpose**: Verify backend edge function evaluates telemetry location against safe zone geofence and creates an alert when child exits safe zone.
- **Preconditions**: Safe zone "Home" configured with 200m radius; child location telemetry reported outside safe zone boundary.
- **Steps**:
  1. Inject mock GPS coordinates 500m outside "Home" safe zone into child telemetry payload.
  2. Trigger telemetry upload.
  3. Inspect Parent app Alerts tab within 10 seconds.
- **Expected Result**: Parent receives push notification and alert row: "Child has left safe zone Home".
- **Failure Conditions**: Alert not generated or delayed by > 60 seconds.
- **Evidence to Capture**: Screenshot of Geofence breach alert in Parent Alerts tab.
- **Cleanup / Teardown Procedure**: Acknowledge alert.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-39: Low-Battery Telemetry Alert Dispatch
- **Test ID**: `TC-EXP-39`
- **Test Name**: Low Battery Warning Alert Under 15%
- **Functionality ID(s)**: `LOC07`
- **Category / Subsystem**: Alerts / Telemetry
- **Target Role**: Interconnected
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Telemetry Alert
- **Purpose**: Verify child telemetry with battery level <= 15% automatically triggers a low-battery alert on parent app.
- **Preconditions**: Paired child device.
- **Steps**:
  1. Transmit child heartbeat telemetry with `battery_level = 12` and `is_charging = false`.
  2. Check Parent app Alerts inbox.
- **Expected Result**: Alert inbox displays amber warning: "Child Device Low Battery: 12% remaining".
- **Failure Conditions**: No alert generated; alert generated while device is charging.
- **Evidence to Capture**: Screenshot of Low Battery alert card.
- **Cleanup / Teardown Procedure**: Acknowledge alert.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-40: Offline Heartbeat Timeout Alert
- **Test ID**: `TC-EXP-40`
- **Test Name**: Child Device Offline Detection Alert
- **Functionality ID(s)**: `LOC08`
- **Category / Subsystem**: Alerts / Heartbeat
- **Target Role**: Interconnected
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Timeout Detection
- **Purpose**: Verify that when child device misses 3 consecutive heartbeats (15+ minutes), device status becomes "Offline" and parent alert is logged.
- **Preconditions**: Child device powered off or disconnected from network.
- **Steps**:
  1. Put child device into Airplane mode for 20 minutes.
  2. Inspect Parent Dashboard and Alerts tab.
- **Expected Result**: Device card status updates to "Offline (Last seen 20m ago)"; Alerts inbox logs: "Child device has been offline for over 15 minutes".
- **Failure Conditions**: Device falsely displays "Online" indefinitely.
- **Evidence to Capture**: Screenshot of offline device badge and alert.
- **Cleanup / Teardown Procedure**: Reconnect child device to network.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-41: Child Permission Revocation Tamper Alert
- **Test ID**: `TC-EXP-41`
- **Test Name**: Tamper Alert on OS Permission Revocation
- **Functionality ID(s)**: `LOC09`, `SET08`
- **Category / Subsystem**: Anti-Tamper / Alerts
- **Target Role**: Interconnected
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Anti-Tamper Alert
- **Purpose**: Verify that if a child revokes Device Admin or Usage Access, the native receiver dispatches an immediate high-priority tamper alert to parent.
- **Preconditions**: Enrolled child phone.
- **Steps**:
  1. On child phone Android Settings, revoke Usage Access for Haven.
  2. Observe child app native broadcast handling.
  3. Open Parent Alerts tab within 10 seconds.
- **Expected Result**: Critical red alert generated: "Tamper Warning: Usage Access was disabled on Child Device".
- **Failure Conditions**: Revocation goes unnoticed; parent receives no notification.
- **Evidence to Capture**: Screenshot of Critical Tamper alert.
- **Cleanup / Teardown Procedure**: Re-grant Usage Access on child device.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-42: Safe Zone Radius Live Preview Slider
- **Test ID**: `TC-EXP-42`
- **Test Name**: Safe Zone Geofence Radius Slider Visual Resize
- **Functionality ID(s)**: `LOC11`
- **Category / Subsystem**: Safe Zones UI
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify adjusting the radius slider (50m to 1000m) smoothly resizes the circular preview overlay on the map in real time.
- **Preconditions**: Safe zone creation screen open with map center pin.
- **Steps**:
  1. Open Safe Zone creation screen.
  2. Drag radius slider from 100m to 500m.
  3. Drag radius slider to 1000m.
- **Expected Result**: Circular shaded area on map expands and contracts smoothly in sync with slider position; numerical readout updates (e.g. "500m").
- **Failure Conditions**: Map circle stutters, fails to update, or crashes on maximum value.
- **Evidence to Capture**: Screenshots of map at 100m and 500m radius settings.
- **Cleanup / Teardown Procedure**: Cancel zone creation.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 7. Group 6: Remote Assistance Lifecycle, Media & Audit Logs

### TC-EXP-43: Remote Assistance Call History Log
- **Test ID**: `TC-EXP-43`
- **Test Name**: Remote Assistance Call Log Audit Trail
- **Functionality ID(s)**: `REM04`
- **Category / Subsystem**: Remote Assistance
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Telemetry Audit
- **Purpose**: Verify completed remote assistance sessions are logged with Start Time, Duration, Status (Completed/Declined), and Child Device Name.
- **Preconditions**: At least one remote session completed or declined.
- **Steps**:
  1. Open Parent app -> Remote Assistance -> "Session History".
  2. Inspect chronological session list.
- **Expected Result**: Displays list showing date, time, duration (e.g. "3m 42s"), and outcome badge ("Completed").
- **Failure Conditions**: Session history empty or duration shows 0s.
- **Evidence to Capture**: Screenshot of Session History list.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-44: Call Hangup and Camera/Mic Resource Release
- **Test ID**: `TC-EXP-44`
- **Test Name**: Remote Call Termination and Hardware Teardown
- **Functionality ID(s)**: `REM05`
- **Category / Subsystem**: WebRTC / Hardware Release
- **Target Role**: Interconnected
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Resource Teardown
- **Purpose**: Verify that tapping "End Call" cleanly tears down WebRTC peer connection, stops media tracks, and releases Android camera/mic hardware.
- **Preconditions**: Active remote assistance call in progress.
- **Steps**:
  1. On Parent app, tap red "End Call" button.
  2. Verify call screen closes on Parent device.
  3. Verify call screen closes on Child device.
  4. On Child device, open native Android Camera app immediately.
- **Expected Result**: Both devices return cleanly to previous screens. Native Camera app opens and acquires camera without "Camera in use by another app" error.
- **Failure Conditions**: Child device screen stays stuck in call; camera hardware locked by zombie process.
- **Evidence to Capture**: Screenshot of native camera opening successfully post-call.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-45: In-Call Media Stream Controls: Mute, Video, Camera Flip
- **Test ID**: `TC-EXP-45`
- **Test Name**: In-Call Media Toggle Controls
- **Functionality ID(s)**: `REM06`
- **Category / Subsystem**: Remote Assistance / Media
- **Target Role**: Interconnected
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Interactive Media Controls
- **Purpose**: Verify in-call control buttons (Mute Audio, Video Mute, Switch Camera front/back) function correctly during live call.
- **Preconditions**: Live WebRTC remote call in progress.
- **Steps**:
  1. Tap "Mute Microphone" icon on Child device: Verify Parent cannot hear audio.
  2. Tap "Mute Microphone" again: Verify audio restored.
  3. Tap "Flip Camera" icon: Verify Child video feed switches from front-facing to rear-facing camera on Parent screen.
  4. Tap "Disable Video": Verify video placeholder displays avatar.
- **Expected Result**: All 3 media controls update track states immediately without dropping call connection.
- **Failure Conditions**: Tapping camera flip disconnects WebRTC session; mute button does not silence audio.
- **Evidence to Capture**: Screenshots of muted state and flipped camera feed.
- **Cleanup / Teardown Procedure**: End call.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-46: Audit Retention Policy Configuration Dialog
- **Test ID**: `TC-EXP-46`
- **Test Name**: Set Audit Log Retention Period in Settings
- **Functionality ID(s)**: `AUD02`
- **Category / Subsystem**: Audit Logs
- **Target Role**: Parent
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: Functional UI
- **Purpose**: Verify parent can select audit log retention period (30 days, 60 days, 90 days, 1 year) and save setting.
- **Preconditions**: Parent in Settings -> Audit Logs.
- **Steps**:
  1. Tap "Retention Settings" gear icon.
  2. Select radio button "60 Days".
  3. Tap "Save Retention Policy".
- **Expected Result**: Setting persists; dialog confirms policy updated.
- **Failure Conditions**: Radio selection does not save or crashes dialog.
- **Evidence to Capture**: Screenshot of saved retention setting.
- **Cleanup / Teardown Procedure**: Restore original retention period.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-47: Manual Audit Log Purge with Confirmation
- **Test ID**: `TC-EXP-47`
- **Test Name**: On-Demand Historical Audit Log Purge
- **Functionality ID(s)**: `AUD03`
- **Category / Subsystem**: Audit Logs
- **Target Role**: Parent
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `REQUIRES_ISOLATED_BACKEND`
- **Test Type**: Destructive Maintenance
- **Purpose**: Verify parent can manually trigger a purge of audit logs older than the retention threshold with explicit keyword confirmation.
- **Preconditions**: Test database with audit logs older than 60 days.
- **Steps**:
  1. In Audit Logs settings, tap "Purge Old Logs".
  2. Enter confirmation keyword "PURGE".
  3. Tap "Confirm Purge".
- **Expected Result**: Backend deletes historical logs older than 60 days while retaining recent logs. Snackbar confirms number of purged records.
- **Failure Conditions**: Purges all records including current day, or fails silently.
- **Evidence to Capture**: Screenshot of purge confirmation snackbar and audit log count.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-48: PostgreSQL Audit Retention Sweep Function
- **Test ID**: `TC-EXP-48`
- **Test Name**: Database Scheduled Retention Sweep RPC
- **Functionality ID(s)**: `AUD04`
- **Category / Subsystem**: Backend Maintenance
- **Target Role**: Backend
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `REQUIRES_ISOLATED_BACKEND`
- **Test Type**: SQL Function Verification
- **Purpose**: Verify database migration function `execute_retention_sweep()` deletes expired audit records and telemetry according to family retention policy.
- **Preconditions**: Staging database with expired records seeded.
- **Steps**:
  1. Execute `SELECT execute_retention_sweep();` via Supabase SQL Editor.
  2. Verify deleted row counts returned.
- **Expected Result**: Expired records deleted; non-expired records untouched; returns JSON summary of deleted counts.
- **Failure Conditions**: Function throws SQL syntax error or deletes active records.
- **Evidence to Capture**: SQL execution output JSON.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 8. Group 7: System Settings, Preferences & Native Bridges

### TC-EXP-49: Local Notification Preferences Toggle
- **Test ID**: `TC-EXP-49`
- **Test Name**: Parent App Push Notification Preferences
- **Functionality ID(s)**: `SET01`
- **Category / Subsystem**: Settings
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: UI Persistence
- **Purpose**: Verify parent can toggle notification channels (Safety Alerts, Daily Summary, Screen Time Requests) and settings persist locally.
- **Preconditions**: Parent in Settings -> Notifications.
- **Steps**:
  1. Toggle "Daily Summary Notifications" to OFF.
  2. Toggle "Safety Alerts" to ON.
  3. Close app and relaunch.
  4. Inspect notification toggles.
- **Expected Result**: Toggle states persist accurately across app restarts.
- **Failure Conditions**: Toggles revert to defaults upon relaunch.
- **Evidence to Capture**: Screenshot of notification settings toggles.
- **Cleanup / Teardown Procedure**: Restore toggles.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-50: Location Reminder Frequency Preference
- **Test ID**: `TC-EXP-50`
- **Test Name**: Location Update Interval Dropdown
- **Functionality ID(s)**: `SET02`
- **Category / Subsystem**: Settings
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE_REVERSIBLE`
- **Test Type**: UI Persistence
- **Purpose**: Verify user can select location update interval (5 min, 15 min, 30 min) in settings.
- **Preconditions**: Settings -> Location Preferences.
- **Steps**:
  1. Tap "Update Frequency" dropdown.
  2. Select "15 Minutes".
  3. Save and relaunch app.
- **Expected Result**: Selection persists as "15 Minutes".
- **Failure Conditions**: Dropdown selection lost on relaunch.
- **Evidence to Capture**: Screenshot of selected dropdown option.
- **Cleanup / Teardown Procedure**: Restore default (5 min).
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-51: App Version and Build Information Display
- **Test ID**: `TC-EXP-51`
- **Test Name**: App Version and Build Number Verification
- **Functionality ID(s)**: `SET03`
- **Category / Subsystem**: About / Settings
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Information Display
- **Purpose**: Verify Settings screen displays accurate Version and Build Number matching `pubspec.yaml`.
- **Preconditions**: Settings tab open.
- **Steps**:
  1. Scroll to bottom of Settings.
  2. Inspect version footer (e.g. "Haven v1.0.0+1").
- **Expected Result**: Displays non-empty version matching release manifest.
- **Failure Conditions**: Displays "Version: Unknown" or blank.
- **Evidence to Capture**: Screenshot of version footer.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-52: Runtime Permission Launcher Bridge
- **Test ID**: `TC-EXP-52`
- **Test Name**: Native Permission Request Dialog Launcher
- **Functionality ID(s)**: `SET04`
- **Category / Subsystem**: Native Bridge / Permissions
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Native OS Bridge
- **Purpose**: Verify `NativeBridge.kt` properly delegates permission requests to Android `ActivityCompat.requestPermissions`.
- **Preconditions**: Clean install with camera permission not yet requested.
- **Steps**:
  1. Trigger camera diagnostic in child app.
  2. Observe native system permission prompt.
  3. Tap "While using the app".
- **Expected Result**: Native dialog prompts for permission; granting immediately fulfills MethodChannel callback without crashing.
- **Failure Conditions**: MethodChannel throws `MissingPluginException` or app crashes.
- **Evidence to Capture**: Screenshot of native Android permission prompt.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-53: Background Location Launcher Bridge
- **Test ID**: `TC-EXP-53`
- **Test Name**: Launch Android Background Location Settings
- **Functionality ID(s)**: `SET06`
- **Category / Subsystem**: Native Bridge / Permissions
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Native OS Bridge
- **Purpose**: Verify child app launches Android system App Permissions screen allowing user to select "Allow all the time".
- **Preconditions**: Child device on Android 11+ with foreground location granted.
- **Steps**:
  1. On Child diagnostics, tap "Grant Background Location".
  2. Observe system navigation.
- **Expected Result**: Navigates directly to Android system "Location Permission" screen showing "Allow all the time" radio option.
- **Failure Conditions**: Fails to launch system screen or opens generic Settings home.
- **Evidence to Capture**: Screenshot of Android Location permission settings screen.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-54: Native Permission Diagnostic Status Tile
- **Test ID**: `TC-EXP-54`
- **Test Name**: Permission Status Tile Visual Indicator
- **Functionality ID(s)**: `SET07`
- **Category / Subsystem**: Core Widgets
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Widget Presentation
- **Purpose**: Verify `PermissionStatusTile` renders correct icon, color (green/red), and action button depending on permission grant status.
- **Preconditions**: Diagnostics screen open.
- **Steps**:
  1. View permission status tile when permission is granted.
  2. View permission status tile when permission is missing.
- **Expected Result**: Granted tile shows green check and "Granted"; Missing tile shows red alert, explanation, and "Enable" button.
- **Failure Conditions**: Tile remains gray or lacks action button.
- **Evidence to Capture**: Screenshots of granted and missing tile states.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-55: Device Admin Revocation Alert UI
- **Test ID**: `TC-EXP-55`
- **Test Name**: Device Admin Revocation Tamper Warning Dialog
- **Functionality ID(s)**: `SET08`
- **Category / Subsystem**: Native Android / Anti-Tamper
- **Target Role**: Child
- **Execution Priority**: `P0`
- **Safety & Risk Classification**: `SPECIALIST_TEST`
- **Test Type**: Anti-Tamper Enforcement
- **Purpose**: Verify that attempting to deactivate Device Admin via Android OS Settings shows Haven warning dialog and dispatches tamper broadcast.
- **Preconditions**: Device Admin active on child device.
- **Steps**:
  1. Go to Android Settings -> Security -> Device Admin Apps.
  2. Tap Haven Parent Control -> "Deactivate this device admin app".
  3. Observe warning dialog generated by `ParentControlDeviceAdminReceiver.kt`.
- **Expected Result**: Warning prompt informs user that deactivating Device Admin will alert parents and lock child app.
- **Failure Conditions**: Deactivation succeeds silently without warning.
- **Evidence to Capture**: Screenshot of Device Admin deactivation warning dialog.
- **Cleanup / Teardown Procedure**: Cancel deactivation.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-56: Child Background Sync Retry and Exponential Backoff
- **Test ID**: `TC-EXP-56`
- **Test Name**: Child Daemon Sync Network Reconnect
- **Functionality ID(s)**: `CHD07`
- **Category / Subsystem**: Resilience / Network
- **Target Role**: Child
- **Execution Priority**: `P1`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Resilience & Recovery
- **Purpose**: Verify child sync daemon handles temporary network loss with exponential backoff and recovers automatically upon reconnect.
- **Preconditions**: Child app running.
- **Steps**:
  1. Disconnect Wi-Fi and Cellular on child device for 3 minutes.
  2. Trigger policy check.
  3. Observe retry loop in ADB logcat.
  4. Reconnect Wi-Fi.
- **Expected Result**: Daemon backs off gracefully without battery drain or crash; immediately flushes queued telemetry upon network restoration.
- **Failure Conditions**: Daemon terminates permanently on network failure; queues never flush.
- **Evidence to Capture**: ADB logcat trace showing network reconnection and telemetry flush.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-57: Child Rules Real-Time Manual Refresh
- **Test ID**: `TC-EXP-57`
- **Test Name**: Child Rules Tab Pull-to-Refresh
- **Functionality ID(s)**: `CHD08`
- **Category / Subsystem**: Child UI
- **Target Role**: Child
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Functional UI
- **Purpose**: Verify child can swipe down on the Rules tab to manually pull latest parental rules from backend.
- **Preconditions**: Child on Rules tab.
- **Steps**:
  1. Swipe down on Child Rules tab.
  2. Observe refresh spinner and update.
- **Expected Result**: Rules tab refreshes with latest limits and time allowances.
- **Failure Conditions**: Pull gesture unsupported or screen hangs.
- **Evidence to Capture**: Screenshot of refreshed Rules tab.
- **Cleanup / Teardown Procedure**: None.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

### TC-EXP-58: Dashboard Periodic Polling Fallback
- **Test ID**: `TC-EXP-58`
- **Test Name**: Periodic Heartbeat Polling Fallback
- **Functionality ID(s)**: `SYS02`
- **Category / Subsystem**: Polling / Fallback
- **Target Role**: Shared
- **Execution Priority**: `P2`
- **Safety & Risk Classification**: `SAFE`
- **Test Type**: Resilience / Fallback
- **Purpose**: Verify that if Supabase Realtime WebSocket drops, dashboard background timer polls REST endpoint every 60 seconds to keep data fresh.
- **Preconditions**: Dashboard open; block WebSocket traffic.
- **Steps**:
  1. Simulate WebSocket disconnection.
  2. Update a device property in database directly.
  3. Observe dashboard after 65 seconds.
- **Expected Result**: Dashboard updates via periodic polling timer despite disconnected WebSocket.
- **Failure Conditions**: Dashboard remains stale indefinitely when WebSocket is down.
- **Evidence to Capture**: Network inspect trace showing REST polling request.
- **Cleanup / Teardown Procedure**: Unblock WebSocket traffic.
- **Actual Result**: `NOT TESTED` | **Status**: `NOT TESTED`

---

## 9. Expansion Suite Master Summary

```
====================================================================================================
                        EXPANSION TEST SUITE SUMMARY (HAVEN-GAP-005)
====================================================================================================
Total New Manual Test Cases Authored:       58 Granular Test Cases (TC-EXP-01 through TC-EXP-58)
P0 Execution Priority (Critical Path):       12 Test Cases (20.7%)
P1 Execution Priority (Core Functional):     28 Test Cases (48.3%)
P2 Execution Priority (UX / Maintenance):    18 Test Cases (31.0%)

Safety & Execution Risk Breakdown:
- SAFE (Non-Mutating / UI / Info):           23 Test Cases (39.7%)
- SAFE_REVERSIBLE (Mutates with Teardown):   12 Test Cases (20.7%)
- REQUIRES_DISPOSABLE_ACCOUNT:                4 Test Cases ( 6.9%)
- REQUIRES_DISPOSABLE_DEVICE:                 5 Test Cases ( 8.6%)
- REQUIRES_ISOLATED_BACKEND:                  4 Test Cases ( 6.9%)
- SPECIALIST_TEST (Hardware / Native DO):    10 Test Cases (17.2%)

Coverage Status:
- Every Inventoried Functionality Addressed: YES (100.0%)
- Total Tests Executed:                       0 (0.0% — All Marked NOT TESTED)
====================================================================================================
```
