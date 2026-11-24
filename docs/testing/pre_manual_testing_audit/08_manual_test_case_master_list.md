# 08 — Manual Test Case Master List

**Document ID:** `HAVEN-INV-008`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Scope:** Complete Step-by-Step Manual Test Case Specifications for All Testable Functionalities  
**Execution Status:** ALL TEST CASES STRICTLY UNEXECUTED (`NOT TESTED`)  

---

## 1. Test Case Execution Protocol & Status Legend

This document contains step-by-step manual test cases designed for execution by non-developer product owners and QA testers.

> [!CRITICAL]
> **Audit Constraint**: In accordance with the pre-testing audit standard, **zero test cases have been executed**. Every entry has:
> - `Actual Result: NOT TESTED`
> - `Status: NOT TESTED`
> 
> Tests must only be executed during a separately authorized runtime QA phase.

---

## 2. Group 1: Basic App & Navigation Test Cases

### TC-A10: Backend Configuration Screen
- **Functionality ID**: `A10`
- **Test Name**: Missing Configuration Fallback Screen
- **Role**: Shared
- **Preconditions**: App launched with missing Supabase URL/Key environment flags.
- **Required Account or Device State**: Any device; clean launch without configuration.
- **Steps**:
  1. Build or launch app without compile-time environment flags.
  2. Observe the initial render screen.
- **Expected Result**: App displays `/configuration` screen with red warning icon, explaining missing backend configuration, without crashing.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of configuration diagnostic screen.
- **Dependencies**: None.
- **Risk if Failed**: Low. App crashes on bad configuration rather than failing gracefully.

---

### TC-A06: Role Selection Interface
- **Functionality ID**: `A06`
- **Test Name**: Role Selection Screen Options
- **Role**: Shared
- **Preconditions**: User registered and verified email; no server role set.
- **Required Account or Device State**: Authenticated user with `profiles.role` null.
- **Steps**:
  1. Complete registration and email verification.
  2. Observe `/role-selection` screen.
  3. Inspect Parent Mode card and Child Mode card buttons.
- **Expected Result**: Screen renders display name input and two distinct cards ("Parent" and "Child") with clear descriptions.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of role selection screen; check for button text clipping (`HAVEN-QA-001`).
- **Dependencies**: `A01`, `A02`.
- **Risk if Failed**: High. User cannot proceed past onboarding.

---

### TC-SYS01: Offline Mode Detection & Warning Banner
- **Functionality ID**: `SYS01`
- **Test Name**: Network Connectivity Disconnection Handling
- **Role**: Shared
- **Preconditions**: App open on Parent Dashboard or Child Home.
- **Required Account or Device State**: Enrolled user session.
- **Steps**:
  1. Swipe down Android notification shade and turn on "Airplane Mode".
  2. Observe top of the application screen.
  3. Tap on a cached list or tab.
- **Expected Result**: Top of screen surfaces yellow `InfoBanner` indicating "No internet connection". App continues rendering cached data without crashing.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot showing offline banner over cached dashboard.
- **Dependencies**: None.
- **Risk if Failed**: High. Network drops cause unhandled exceptions and app freeze.

---

## 3. Group 2: Authentication & Account Test Cases

### TC-A01: Parent & Child Email Sign-In
- **Functionality ID**: `A01`
- **Test Name**: Valid Email and Password Authentication
- **Role**: Shared
- **Preconditions**: User account already created and verified in Supabase Auth.
- **Required Account or Device State**: Logged out app state.
- **Steps**:
  1. Launch app to `/auth/login`.
  2. Enter valid registered email address.
  3. Enter valid password.
  4. Tap "Sign In" button.
- **Expected Result**: Loading spinner activates; session token is returned and saved; app routes to appropriate role shell (`/parent` or `/child`).
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Video or screenshots showing login transition to home shell.
- **Dependencies**: None.
- **Risk if Failed**: Critical. Complete blocker to application usage.

---

### TC-A02: Account Registration Flow
- **Functionality ID**: `A02`
- **Test Name**: New Account Registration
- **Role**: Shared
- **Preconditions**: Disposable email address available.
- **Required Account or Device State**: Logged out state.
- **Steps**:
  1. On login screen, tap "Create Account".
  2. Enter Display Name ("Test Parent"), Email, Password (8+ chars), and Confirm Password.
  3. Tap "Create Account" button.
- **Expected Result**: User created in Supabase Auth; `auth-bootstrap` initializes row; app routes to `/auth/verify-email`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of verification prompt screen.
- **Dependencies**: Supabase Auth SMTP service.
- **Risk if Failed**: Critical. New users cannot sign up.

---

### TC-A04: Cold App Launch Session Restoration
- **Functionality ID**: `A04`
- **Test Name**: Automatic Session Restoration on Splash
- **Role**: Shared
- **Preconditions**: User successfully logged in during previous app launch.
- **Required Account or Device State**: Valid JWT in `SharedPreferences`.
- **Steps**:
  1. Force-close the application via Android Recent Apps.
  2. Re-open application from app icon.
  3. Observe splash screen behavior.
- **Expected Result**: Splash screen renders briefly (< 2 seconds), restores session, and transitions directly to Parent or Child shell without showing login screen.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screen recording of cold start.
- **Dependencies**: `A01`.
- **Risk if Failed**: High. Users forced to enter password on every app launch.

---

### TC-A05: Sign Out & Token Revocation
- **Functionality ID**: `A05`
- **Test Name**: Complete User Sign-Out
- **Role**: Shared
- **Preconditions**: User logged into Parent or Child shell.
- **Required Account or Device State**: Active authenticated session.
- **Steps**:
  1. Open Settings tab.
  2. Tap "Sign Out" button at bottom of settings.
  3. In confirmation dialog, tap "Sign Out".
- **Expected Result**: Auth token revoked; local session cache purged; app routes immediately to `/auth/login`. Pressing Android Back does not return to shell.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Video of sign-out and back-button press.
- **Dependencies**: `A01`.
- **Risk if Failed**: High. Residual session allows unauthorized access after logout.

---

### TC-A08: Account Data Export (GDPR)
- **Functionality ID**: `A08`
- **Test Name**: Personal Data Export Dialog
- **Role**: Shared
- **Preconditions**: User logged into Parent or Child shell.
- **Required Account or Device State**: Enrolled family account.
- **Steps**:
  1. Open Settings → Privacy & Data.
  2. Tap "Export Personal Data".
  3. Confirm export prompt.
- **Expected Result**: Edge Function aggregates profile, family, and device data; displays `ExportResultDialog` with JSON preview and "Copy to Clipboard" button.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of JSON export result dialog.
- **Dependencies**: Edge Function `account`.
- **Risk if Failed**: Medium. GDPR compliance failure.

---

### TC-A09: Account Deletion with Confirmation
- **Functionality ID**: `A09`
- **Test Name**: Permanent Account Deletion
- **Role**: Shared
- **Preconditions**: Dedicated disposable test account logged in.
- **Required Account or Device State**: Disposable test account only.
- **Steps**:
  1. Open Settings → Privacy & Data.
  2. Tap "Delete Account" button.
  3. In `DeleteAccountDialog`, type uppercase word "DELETE" and account password.
  4. Tap "Permanently Delete".
- **Expected Result**: Edge Function deletes user auth row, cascades deletion to profiles, families, and pairings; logs out user and returns to login.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of deletion dialog and post-deletion login screen.
- **Dependencies**: Edge Function `account`.
- **Risk if Failed**: Critical. Orphaned records or deletion failure.

---

### TC-A11: Password Reveal & Masking Toggle
- **Functionality ID**: `A11`
- **Test Name**: Password Field ObscureText Toggle
- **Role**: Shared
- **Preconditions**: User on `/auth/login` or `/auth/register`.
- **Required Account or Device State**: Any state.
- **Steps**:
  1. Type "SecretPass123" into Password field.
  2. Observe characters masked as dots (`••••••••`).
  3. Tap the eye icon suffix button.
  4. Observe text revealed as "SecretPass123".
  5. Tap eye icon again.
- **Expected Result**: Password masks and reveals cleanly without altering cursor position or submitting form.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Video of toggle in action.
- **Dependencies**: None.
- **Risk if Failed**: Medium. User cannot verify complex typed passwords.

---

## 4. Group 3: Parent-Child Connection Test Cases

### TC-FAM08: Family Group Creation
- **Functionality ID**: `FAM08`
- **Test Name**: Initial Family Group Setup
- **Role**: Parent
- **Preconditions**: New parent account logged in; no family created yet.
- **Required Account or Device State**: Parent role confirmed.
- **Steps**:
  1. App routes to `/parent/family-setup`.
  2. Enter Family Name: "Sterling Family".
  3. Tap "Create Family".
- **Expected Result**: Edge Function creates family record, binds parent as owner, and routes to Parent Shell (`/parent`).
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of dashboard displaying "Sterling Family" banner.
- **Dependencies**: `A06`.
- **Risk if Failed**: Critical. Parent cannot create family umbrella.

---

### TC-FAM06: Child Linking Code & QR Code Generation
- **Functionality ID**: `FAM06`
- **Test Name**: Child Enrollment Code Display
- **Role**: Child
- **Preconditions**: Child account authenticated on child handset.
- **Required Account or Device State**: Unpaired child account.
- **Steps**:
  1. Open `/child/enrollment` screen.
  2. Observe displayed linking information.
- **Expected Result**: Screen renders a high-contrast QR code and a prominent 6-character Base32 text code (e.g. `7K4X9M`).
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of child QR enrollment screen.
- **Dependencies**: `A06`.
- **Risk if Failed**: Critical. Child cannot present pairing credentials.

---

### TC-FAM01: Link Child via Camera QR Code Scanning
- **Functionality ID**: `FAM01`
- **Test Name**: QR Code Scanner Child Pairing
- **Role**: Parent–Child (Interconnected)
- **Preconditions**: Child phone displaying QR code (`FAM06`); Parent logged into `/parent`.
- **Required Account or Device State**: Parent and Child devices side-by-side.
- **Steps**:
  1. On Parent Dashboard, tap "Link Child Device".
  2. Tap "Scan QR Code".
  3. Grant camera permission if prompted.
  4. Point parent camera at child phone screen QR code.
- **Expected Result**: Parent scanner instantly beeps/vibrates, decodes child contact ID, submits pairing redemption, and displays "Child Linked Successfully".
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Video of QR scan and resulting success screen.
- **Dependencies**: `FAM06`, `SET04` (Camera).
- **Risk if Failed**: Critical. Primary onboarding flow broken.

---

### TC-FAM02: Link Child via Manual 6-Digit Code Entry
- **Functionality ID**: `FAM02`
- **Test Name**: Manual Code Entry Child Pairing
- **Role**: Parent–Child (Interconnected)
- **Preconditions**: Child phone displaying 6-character code (`FAM06`).
- **Required Account or Device State**: Camera unavailable or denied on parent phone.
- **Steps**:
  1. On Parent app, open `/parent/pairing/redeem`.
  2. Type the 6-character code shown on child phone into text input.
  3. Tap "Connect Device" button.
- **Expected Result**: Edge Function redeems code; links child profile to family; child phone transitions from enrollment to Home tab.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshots of code entry and child home transition.
- **Dependencies**: `FAM06`.
- **Risk if Failed**: High. Fallback pairing path broken.

---

### TC-FAM07: Child Device Hardware Registration
- **Functionality ID**: `FAM07`
- **Test Name**: Child Hardware Secret Generation & KeyStore Registration
- **Role**: Child
- **Preconditions**: Child pairing redeemed by parent.
- **Required Account or Device State**: Child device completing enrollment.
- **Steps**:
  1. On child enrollment screen, enter device name: "Pixel Child".
  2. Tap "Complete Setup".
  3. Observe transition.
- **Expected Result**: Native `SecureStore.kt` generates 32-byte secret in KeyStore; registers hardware in `devices` table; launches `GuardianService`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Android Logcat confirming `SecureStore` key generation; screenshot of Child Home.
- **Dependencies**: `FAM01` or `FAM02`.
- **Risk if Failed**: Critical. Breaks all subsequent telemetry.

---

### TC-FAM10: Unlink Child Account from Parent Dashboard
- **Functionality ID**: `FAM10`
- **Test Name**: Parent-Initiated Child Unlinking
- **Role**: Parent–Child (Interconnected)
- **Preconditions**: Parent and Child actively paired.
- **Required Account or Device State**: Active family link.
- **Steps**:
  1. On Parent app, open Settings → Family (`/parent/family`).
  2. Tap "Unlink Child" on child card.
  3. Confirm dialog: "Are you sure you want to unlink Alex?".
- **Expected Result**: Child device status set to `'revoked'`; family membership removed; child app detects unlinking and clears local sync config.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshots of parent family list and child unlinked screen.
- **Dependencies**: `FAM01`.
- **Risk if Failed**: High. Parents unable to remove old or re-assigned devices.

---

## 5. Group 4: Parent Functionalities Test Cases

### TC-MON01: Parent Dashboard Summary Cards Rendering
- **Functionality ID**: `MON01`
- **Test Name**: Dashboard Family and Child Overview
- **Role**: Parent
- **Preconditions**: Parent logged in with at least one paired child.
- **Required Account or Device State**: Active family with enrolled child device.
- **Steps**:
  1. Open Dashboard tab (`/parent`).
  2. Inspect top section: Family name and child selector.
  3. Inspect child card: Battery level, online status, current screen time.
  4. Inspect Quick Action cards (Screen Time, App Restrictions, Location, Safe Zones).
- **Expected Result**: All cards render with live data; no infinite loading shimmers or null string errors.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Full-page screenshot of Parent Dashboard.
- **Dependencies**: `FAM08`, `FAM07`.
- **Risk if Failed**: High. Primary parent interface broken.

---

### TC-MON03: Device Detail Technical Telemetry
- **Functionality ID**: `MON03`
- **Test Name**: Device Technical Specifications & Battery Inspector
- **Role**: Parent
- **Preconditions**: At least one enrolled device in family.
- **Required Account or Device State**: Enrolled device.
- **Steps**:
  1. From Devices tab, tap on child device card.
  2. Inspect Device Detail screen (`/parent/devices/detail`).
  3. Verify: Device Model, Android OS version, Battery percentage, Charging state, Last seen.
- **Expected Result**: Accurate technical telemetry displays; battery icon reflects charging/unplugged state.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of Device Detail top cards.
- **Dependencies**: `FAM07`, `MON04`.
- **Risk if Failed**: Medium. Parent lacks hardware visibility.

---

### TC-USE01: Daily Screen Time 7-Day Usage Chart
- **Functionality ID**: `USE01`
- **Test Name**: Historical Screen Time Bar Chart
- **Role**: Parent
- **Preconditions**: Child has uploaded at least 1 day of usage stats.
- **Required Account or Device State**: `usage_daily` populated.
- **Steps**:
  1. On Dashboard, tap "Screen Time" quick action tile.
  2. Inspect 7-day bar graph on `/parent/screen-time`.
  3. Tap on different days of the week.
- **Expected Result**: Bar chart highlights selected day; daily total updates (e.g. "3h 45m"); bars scale proportionally to 24-hour axis.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of screen time graph with selected day.
- **Dependencies**: `USE04`.
- **Risk if Failed**: High. Parents cannot evaluate screen time trends.

---

### TC-USE02: Per-Application Daily Usage Breakdown
- **Functionality ID**: `USE02`
- **Test Name**: App Usage Duration Breakdown List
- **Role**: Parent
- **Preconditions**: Child device has recorded foreground app usage.
- **Required Account or Device State**: Enrolled child device with Usage Access.
- **Steps**:
  1. On `/parent/screen-time`, scroll to "App Usage Breakdown".
  2. Observe list of applications.
- **Expected Result**: Apps listed in descending order of usage duration; displays app icon, name, hours/minutes used, and percentage bar.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of app usage list.
- **Dependencies**: `USE04`.
- **Risk if Failed**: High. Parents cannot see which apps child used.

---

### TC-USE05: Daily Screen Time Quota Limit Setting
- **Functionality ID**: `USE05`
- **Test Name**: Setting Daily Screen Time Limit
- **Role**: Parent
- **Preconditions**: Child device enrolled.
- **Required Account or Device State**: Enrolled device.
- **Steps**:
  1. On `/parent/screen-time`, find "Daily Limit" slider.
  2. Drag slider to set 2 Hours 0 Minutes.
  3. Tap "Save Limit" button.
- **Expected Result**: Success snackbar appears; `device_policies` table updates `daily_limit_minutes = 120`; `device_commands` receives `apply_policy`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot showing saved limit gauge.
- **Dependencies**: `FAM07`.
- **Risk if Failed**: High. Core quota management broken.

---

### TC-APP01: Blocking Individual Target Application
- **Functionality ID**: `APP01`
- **Test Name**: Individual App Blocking Toggle
- **Role**: Parent
- **Preconditions**: Child app inventory snapshotted (`MON07`).
- **Required Account or Device State**: Installed apps visible in parent app.
- **Steps**:
  1. Navigate to `/parent/app-restrictions`.
  2. Locate an installed entertainment app (e.g. YouTube).
  3. Toggle the switch to "Blocked".
  4. Tap "Save Restrictions" floating button.
- **Expected Result**: App status changes to "Blocked"; policy payload appends package name to `blocked_packages`; sync command queued.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of app restriction switch toggled.
- **Dependencies**: `MON07`.
- **Risk if Failed**: Critical. Core app restriction feature broken.

---

### TC-APP02: Whitelist Mode (Block All Except Allowed)
- **Functionality ID**: `APP02`
- **Test Name**: Whitelist Restriction Master Toggle
- **Role**: Parent
- **Preconditions**: App restrictions page open.
- **Required Account or Device State**: Enrolled child device.
- **Steps**:
  1. On `/parent/app-restrictions`, locate top card: "Block all except allowed".
  2. Toggle master switch to ON.
  3. Tap "Save Restrictions".
- **Expected Result**: Warning dialog confirms aggressive restriction; policy payload sets `block_all_except_allowed: true`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of whitelist mode enabled.
- **Dependencies**: `APP01`.
- **Risk if Failed**: High. Emergency lockdown mode fails.

---

### TC-APP04: Per-App Allowed Schedule Windows
- **Functionality ID**: `APP04`
- **Test Name**: App Time Window Schedule Configuration
- **Role**: Parent
- **Preconditions**: An app selected in App Restrictions.
- **Required Account or Device State**: Enrolled device.
- **Steps**:
  1. Tap on an app row (e.g. Minecraft).
  2. Tap "Add Allowed Schedule Window".
  3. Set Start Time: 16:00 (4:00 PM), End Time: 18:00 (6:00 PM).
  4. Tap "Save Window".
- **Expected Result**: Schedule window displays under app name; policy stores `app_rules[package].windows`.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of configured schedule window chip.
- **Dependencies**: `APP01`.
- **Risk if Failed**: Medium. Scheduled homework/leisure rules unavailable.

---

### TC-LOC01: Child Real-Time Map Location Display
- **Functionality ID**: `LOC01`
- **Test Name**: Google Map Child Location Pin
- **Role**: Parent
- **Preconditions**: Child device uploaded at least one GPS coordinate.
- **Required Account or Device State**: `location_events` populated.
- **Steps**:
  1. On Parent Dashboard, tap "Location" quick action tile.
  2. Open `/parent/location`.
  3. Inspect the Google Map view.
- **Expected Result**: Map centers on child's current latitude/longitude; renders child avatar pin, accuracy circle, address card, and fix timestamp.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of map view with child marker pin.
- **Dependencies**: `LOC04`, Google Maps API Key.
- **Risk if Failed**: High. Core child safety location tracking broken.

---

### TC-LOC05: Safe Zone Geofence Creation
- **Functionality ID**: `LOC05`
- **Test Name**: Creating New Safe Zone Boundary
- **Role**: Parent
- **Preconditions**: Parent logged in.
- **Required Account or Device State**: Enrolled family.
- **Steps**:
  1. Navigate to `/parent/safe-zones`.
  2. Tap "Add Safe Zone" floating action button.
  3. Enter Name: "Lincoln Middle School".
  4. Drag map to school coordinates.
  5. Adjust radius slider to 300 meters.
  6. Tap "Save Zone".
- **Expected Result**: Zone row inserted into `safe_zones` table; zone card renders in list with blue geofence circle preview.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of created safe zone in list.
- **Dependencies**: `LOC01`.
- **Risk if Failed**: High. Parents cannot define perimeter boundaries.

---

### TC-LOC10: Safety Alerts Inbox & Acknowledgment
- **Functionality ID**: `LOC10`
- **Test Name**: Reviewing and Acknowledging Alerts
- **Role**: Parent
- **Preconditions**: At least one alert triggered in `safety_alerts`.
- **Required Account or Device State**: Populated alerts table.
- **Steps**:
  1. Open Alerts tab (`/parent`).
  2. Inspect alert cards (e.g. "Low Battery", "Geofence Exit").
  3. Tap "Acknowledge" button on the top alert card.
- **Expected Result**: Alert moves from active list to acknowledged archive; unacknowledged badge count decreases.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot before and after acknowledgment.
- **Dependencies**: `LOC06` or `LOC07`.
- **Risk if Failed**: Medium. Alert clutter and missing incident tracking.

---

### TC-REM01: Initiating Remote Assistance Call
- **Functionality ID**: `REM01`
- **Test Name**: Requesting Live Remote Assistance Session
- **Role**: Parent
- **Preconditions**: Child device online in parent dashboard.
- **Required Account or Device State**: Paired, active child device.
- **Steps**:
  1. Navigate to `/parent/assistance`.
  2. Tap "Start Remote Call" button.
  3. Observe parent screen state.
- **Expected Result**: Screen transitions to `/parent/assistance/session`; ringing tone starts; session created in `remote_sessions` (`status = 'requested'`).
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of ringing outgoing call screen.
- **Dependencies**: `MON04`, `SET04` (Mic/Camera).
- **Risk if Failed**: High. Remote assistance initiation broken.

---

### TC-AUD01: Administrative Audit Log Viewer
- **Functionality ID**: `AUD01`
- **Test Name**: Audit Trail Event History
- **Role**: Parent
- **Preconditions**: At least 3 administrative actions performed (e.g. policy saved, alert acked).
- **Required Account or Device State**: Populated `audit_logs` table.
- **Steps**:
  1. On Dashboard, tap "Audit & Retention" quick action tile.
  2. Inspect table on `/parent/audit`.
  3. Tap on an audit row to inspect JSON details.
- **Expected Result**: Table lists events with exact timestamp, acting user email, action name (`policy_updated`), and affected target.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of audit log table.
- **Dependencies**: `FAM08`.
- **Risk if Failed**: Medium. Lack of regulatory compliance and accountability.

---

## 6. Group 5: Child Functionalities Test Cases

### TC-CHD01: Child Home Protection Status Overview
- **Functionality ID**: `CHD01`
- **Test Name**: Child Home Screen Rendering
- **Role**: Child
- **Preconditions**: Child app paired and enrolled.
- **Required Account or Device State**: Active child session.
- **Steps**:
  1. Open Child app to Home tab (`/child`).
  2. Observe top shield banner and status text.
  3. Inspect family card and active rules summary.
- **Expected Result**: Large shield icon displays with green banner: "HAVEN Protection Active"; shows family name and quick-call button.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Full screenshot of Child Home tab.
- **Dependencies**: `FAM07`.
- **Risk if Failed**: High. Child has no visibility into protection status.

---

### TC-CHD02: Child Rules & Policy Oversight View
- **Functionality ID**: `CHD02`
- **Test Name**: Child Rules Tab Restriction List
- **Role**: Child
- **Preconditions**: Parent configured blocked apps and screen time limits.
- **Required Account or Device State**: Enrolled child device with active policy.
- **Steps**:
  1. In Child app, tap "Rules" tab in bottom navigation.
  2. Inspect "Blocked Applications" section.
  3. Inspect "Daily Limit & Remaining Time" gauge.
  4. Inspect "Bedtime Schedule" card.
- **Expected Result**: Screen transparently lists all apps blocked by parent and accurately reflects remaining screen time for today.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of Child Rules tab.
- **Dependencies**: `APP01`, `USE05`.
- **Risk if Failed**: Medium. Child cannot understand their daily restrictions.

---

### TC-CHD03: Child Requests Inbox & Notifications Badge
- **Functionality ID**: `CHD03`
- **Test Name**: Inbound Requests Badge & List
- **Role**: Child
- **Preconditions**: Parent dispatched remote call or pairing invite.
- **Required Account or Device State**: Incoming pending request in database.
- **Steps**:
  1. Observe Child bottom navigation bar.
  2. Check "Requests" tab icon.
  3. Tap "Requests" tab to view `/child/requests`.
- **Expected Result**: Tab icon displays red badge with number `1`; list shows incoming request card with Accept and Decline buttons.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot showing badge on Requests tab and request card.
- **Dependencies**: `REM01` or `FAM03`.
- **Risk if Failed**: High. Child unaware of incoming parent requests.

---

### TC-CHD05: Camera & Microphone Hardware Self-Test
- **Functionality ID**: `CHD05`
- **Test Name**: Child Media Hardware Diagnostic Sheet
- **Role**: Child
- **Preconditions**: Camera and microphone permissions granted on child handset.
- **Required Account or Device State**: Physical Android handset.
- **Steps**:
  1. In Child app, open Settings tab.
  2. Tap "Camera & Microphone Test".
  3. Observe bottom sheet preview.
  4. Speak into microphone.
- **Expected Result**: Bottom sheet opens displaying live front-camera video feed and dynamic audio volume level bar responding to voice.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of media self-test sheet with active camera feed.
- **Dependencies**: `SET04` (Camera/Mic).
- **Risk if Failed**: Low. Diagnostic utility failure.

---

### TC-CHD09: Emergency Parent Quick-Call Action
- **Functionality ID**: `CHD09`
- **Test Name**: Child Emergency Dial Action
- **Role**: Child
- **Preconditions**: Parent registered with a valid phone number.
- **Required Account or Device State**: Phone dialer app installed on device.
- **Steps**:
  1. On Child Home tab, locate "Call Parent" emergency button.
  2. Tap "Call Parent".
- **Expected Result**: App dispatches `android.intent.action.DIAL`; Android system phone dialer launches with parent phone number pre-filled.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of launched system dialer.
- **Dependencies**: None.
- **Risk if Failed**: High. Child cannot reach parent in urgent emergency.

---

## 7. Group 6: Android Native Behavior Test Cases

### TC-CHD04: Guardian Foreground Service Persistent Notification
- **Functionality ID**: `CHD04`
- **Test Name**: Persistent Status Notification & Service Daemon
- **Role**: Child
- **Preconditions**: Child app enrolled and configured.
- **Required Account or Device State**: Android 12+ handset (Realme RMX2161).
- **Steps**:
  1. Launch child app and ensure background sync is active.
  2. Pull down Android system notification drawer.
  3. Inspect HAVEN status notification.
  4. Attempt to swipe notification away to dismiss it.
- **Expected Result**: Persistent notification is pinned to status bar with channel `"guardian_status"`, text "HAVEN Protection Active", and cannot be swiped away.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Photo or screenshot of Android notification drawer.
- **Dependencies**: `FAM07`, Notification Permission.
- **Risk if Failed**: Critical. OS terminates background worker without persistent notification.

---

### TC-SET05: Android Device Administrator Activation
- **Functionality ID**: `SET05`
- **Test Name**: Device Admin System Enrollment
- **Role**: Child
- **Preconditions**: Child app freshly installed; Device Admin not yet active.
- **Required Account or Device State**: Physical Android device.
- **Steps**:
  1. In Child Settings, tap "Enable Device Administrator".
  2. Observe system screen that appears.
  3. Tap "Activate this device admin app".
- **Expected Result**: Android system Device Admin activation screen launches; confirms privileges; returns to app with status "Device Admin Active".
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of Android system Device Admin activation prompt.
- **Dependencies**: `ParentControlDeviceAdminReceiver.kt`.
- **Risk if Failed**: Critical. Device admin authority required for basic management.

---

### TC-APP07: Native OS App Suspension Under Device Owner
- **Functionality ID**: `APP07`
- **Test Name**: Operating System Package Suspension Verification
- **Role**: Child
- **Preconditions**: Device provisioned as Device Owner (if available); parent blocked target app.
- **Required Account or Device State**: Target app installed on child phone.
- **Steps**:
  1. Verify target app (e.g. YouTube) is marked blocked in parent policy.
  2. On child handset home screen, tap on YouTube app icon to launch it.
- **Expected Result**: If Device Owner: Android OS displays system dialog "App is paused by IT admin" and blocks launch. If Device Admin only: Native suspension fails gracefully and logs unsupported status.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Screenshot of child home screen and OS block dialog.
- **Dependencies**: `APP01`, `APP05`, Device Owner provisioning.
- **Risk if Failed**: Critical. Child can bypass app blocking.

---

## 8. Group 7: Backend & Data Synchronization Test Cases

### TC-MON04: Background Heartbeat Presence Transmission
- **Functionality ID**: `MON04`
- **Test Name**: 5-Minute Heartbeat Telemetry Ingress
- **Role**: Child–Parent (Interconnected)
- **Preconditions**: Child handset enrolled; `GuardianService` active.
- **Required Account or Device State**: Active network connection.
- **Steps**:
  1. Leave child handset idle on Wi-Fi for 6 minutes.
  2. Check Supabase database table `devices` column `last_seen_at`.
  3. Check Parent Dashboard child card presence indicator.
- **Expected Result**: Database `last_seen_at` updates to current timestamp; Parent Dashboard displays green "Online" badge.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Database SQL query output showing updated timestamp; parent screenshot.
- **Dependencies**: `FAM07`, `CHD04`.
- **Risk if Failed**: Critical. Parent cannot monitor child connectivity (`HAVEN-QA-003`).

---

### TC-APP05: Policy Command Delivery & Acknowledgment Loop
- **Functionality ID**: `APP05`
- **Test Name**: Full-Circle Command ACK Verification
- **Role**: Parent–Child (Interconnected)
- **Preconditions**: Parent and child connected; child service running.
- **Required Account or Device State**: Enrolled family.
- **Steps**:
  1. On Parent app, change daily limit and tap Save.
  2. Observe `device_commands` table status (`pending`).
  3. Wait up to 25 seconds for child poll cycle.
  4. Observe `device_commands` status update.
- **Expected Result**: Child polls command; applies policy; posts ACK; command updates to `status = 'succeeded'`; parent UI displays "Active Protection".
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: Database command table dump and parent UI badge.
- **Dependencies**: `APP01`, `APP06`, `CHD04`.
- **Risk if Failed**: Critical. Policy changes never take effect on child device.

---

## 9. Group 8: Security & Failure Scenarios Test Cases

### TC-SEC01: Cross-Family Unauthorized Data Access Boundary
- **Functionality ID**: `A01` / RLS
- **Test Name**: PostgreSQL Row-Level Security Tenant Isolation
- **Role**: Security / Adversarial
- **Preconditions**: Two distinct family accounts created (Family A and Family B).
- **Required Account or Device State**: Authenticated Parent A JWT.
- **Steps**:
  1. Authenticate as Parent A.
  2. Attempt to query `devices` or `location_events` using `device_id` belonging to Family B.
- **Expected Result**: PostgreSQL RLS policies return 0 rows or HTTP 403 Forbidden; zero data leakage across family boundaries.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: API test response logs showing 403/empty set.
- **Dependencies**: Supabase RLS.
- **Risk if Failed**: Critical. Severe cross-tenant privacy breach.

---

### TC-SEC02: Replay of Staged Credential Redemption
- **Functionality ID**: `FAM13` / Wave 3
- **Test Name**: Redemption Replay Attack Prevention
- **Role**: Security / Adversarial
- **Preconditions**: A recovery challenge generated and redeemed once.
- **Required Account or Device State**: Staging database.
- **Steps**:
  1. Redeem recovery challenge with valid 6-char token.
  2. Capture raw HTTP POST payload of `redeem_recredential_challenge`.
  3. Replay exact same HTTP POST payload 1 second later.
- **Expected Result**: Server rejects replayed request with HTTP 400 or 409 (`challenge_already_redeemed`); database credentials remain intact.
- **Actual Result**: `NOT TESTED`
- **Status**: `NOT TESTED`
- **Evidence to Capture**: HTTP response header and body trace.
- **Dependencies**: Gate 6 Staging Environment.
- **Risk if Failed**: Critical. Token double-spend or credential hijacking.

---

## 10. Master Test Case Summary

- **Total Manual Test Cases Prepared**: **35 Core End-to-End Test Cases** (spanning all 92 inventoried functionalities).
- **Total Test Cases Executed**: **0 (0.0%)**.
- **Total Test Cases Marked NOT TESTED**: **35 (100.0%)**.
- **Ready for Future Execution**: Yes, upon separate owner authorization.
