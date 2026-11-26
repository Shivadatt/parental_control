# SUBAGENT 1 AUDIT REPORT: Parent Application Driver & Two-Device Functional Verification

**Auditor:** Subagent 1 — Parent App Driver  
**Date:** November 13, 2026  
**Target Application:** `com.parentcontrol.parent_control` (Dual-Role APK, Version 1.0.0, Build 1)  
**Primary Execution Device:** Android Emulator (`emulator-5554`, Google Pixel 9a, Android 17 / API 37 / `sdk_gphone64_x86_64`)  
**Paired Physical Child Device:** Realme 7 / Narzo 20 Pro (`5HXWRGQ4IFU8WS4T`, Android 12 / API 31 / ColorOS)  
**Parent QA Account:** `[REDACTED]` / `Ankit_321` (Role: Parent / Family Owner)  
**Target Child Account:** `[REDACTED]` / `Ankit_321` (Role: Child / Family Member)  
**Output Deliverable:** `docs/testing/final_two_device_audit/SUBAGENT1_PARENT_RESULTS.md`  

---

## 1. Executive Summary & Audit Overview

This audit report provides an exhaustive, evidence-backed evaluation of all Parent workflows in `com.parentcontrol.parent_control` running on the primary reference device `emulator-5554`. Testing encompasses live UI dump inspections (`uiautomator dump`), screenshot forensics, Kotlin native bridge analysis, Flutter GetX state management layer evaluation, PostgreSQL schema/RLS rules, and hosted Supabase Edge Functions (`hhqgreaoqulmfwfwarhc`).

### 1.1 High-Level Audit Verdict Matrix

| # | Functional Area | Live UI Evidence | Architectural Finding / Verdict | Defect Correlation |
|---|---|---|---|---|
[REDACTED CREDENTIAL ROW]
| 2b| **Device Recovery Flow** | `p08_recovery_card.xml`, `p09_recovery_dialog.xml`, `p10_recovery_done.xml` | **CONFIRMED ARCHITECTURAL DESIGN:** Revocation dialog successfully invokes `family-admin` `recover_device` (`request_device_recovery` RPC), revoking credential, unlinking child, and requiring fresh re-pairing. | **Defect E-1** |
| 3 | **App Restrictions & Policies** | `p26_apprestr.xml`, `p27_applist.xml`, `p30_screentime.xml`, `p37_bedtime_set.xml`, `p39_saved.xml` | **PARTIAL PASS / DEFECTS E-6, E-7, E-11:** App snapshot displays correctly when child uploads; quota policy saves; Bedtime/Curfew is completely ignored by native `PolicyApplier.kt` (E-6); status conflation masks lack of usage access (E-7); policy ack can stall indefinitely (E-11). | **Defect E-6, E-7, E-11** |
| 4 | **Safe Zones & Geofencing** | `p50_zones.xml`, `p51_zonedlg.xml`, `p52_radius_invalid.xml`, `p53_zone_created.xml`, `p56_updated.xml`, `p58_toggle.xml`, `p60_deleted.xml` | **PASS ON CREATE & VALIDATE; FAIL ON UPDATE & DELETE:** Radius validator correctly blocks <50m (10m rejected); creation succeeds; **Edit & Toggle fail with RLS 42501 (`permission denied for table safe_zones`)**; **Delete fails with HTTP 400 (`Unsupported action`)** because hosted `family-admin` v6 predates `delete_zone`. | **New Hosted Defect** |
| 5 | **Safety Alerts** | `H01_alerts.xml`, `H02_filter_critical.xml`, `H04_all.xml`, `H05_ack1.xml`, `H06_after_ack.xml` | **PASS WITH DEFECT E-4:** Filtering by All, Info, Warning, Critical verified; unread badge updates (`2 unacknowledged · 2 total` -> `1 unacknowledged`); acknowledge action calls `family-admin` `ack_alert` and logs audit event; 3 of 7 declared types are never emitted (E-4). | **Defect E-4** |
| 6 | **Remote Assistance** | `J01_remote.xml`, `J03_remote_page.xml`, `J04_after_req.xml`, `J06_sent.xml`, `J10_ra_fresh.xml` | **PASS ON UI / BLOCKED ON MEDIA (E-2, E-12):** Parent receive-only UI verified; request creation and consent dialogs work; "Media: No media is open" is an ended-session note; WebRTC fails due to symmetric NAT and missing hosted TURN credentials. | **Defect E-2, E-12** |
| 7 | **Audit Logs & Family Settings**| `p12_family.xml`, `p13_family_scroll.xml`, `p02_dash.xml`, `audit_logs_page.dart` | **PASS ON AUDIT LOGS; BLOCKED ON RETENTION API (E-5):** 36+ real audit events render with icons, actors, and metadata; family settings display 30d location / 90d usage retention; tapping Retention/Export fails with HTTP 404 (`account` Edge Function not deployed). | **Defect E-5** |

---

## 2. Area 1: Authentication & Role Enforcement

### 2.1 Parent Authentication Mechanics
- **Target Page:** `lib/features/auth/login_page.dart`
- **Controller & Repository:** `LoginController` (`lib/features/auth/controllers/login_controller.dart`), `SupabaseAuthRepository` (`lib/data/repositories/supabase_auth_repository.dart:75-121`).
- **QA Account Credentials:**
  - Email: `[REDACTED]`
[REDACTED CREDENTIAL ROW]
  2. Input submission triggers `_submit()` (`login_page.dart:44-51`):
     ```dart
     if (!(_formKey.currentState?.validate() ?? false)) return;
     FocusScope.of(context).unfocus();
     await _controller.signIn(email: _email.text, password: [REDACTED];
     ```
[REDACTED CREDENTIAL ROW]
     - Schema reference: `supabase/migrations/20260101000000_core.sql:43-57`
     - Role assertion: `profile.role == 'parent'`
  5. The controller resolves family membership from `public.family_members`:
     - Row: `family_id = 'demo'`, `user_id = auth.uid()`, `role = 'owner'`
  6. The shell navigates to `AppRoutes.parentDashboard` (`lib/features/parent/parent_shell_page.dart`).

### 2.2 Client-Side Form Validation Verification
- **Empty Credentials:**
  - Empty Email triggers `Validators.email` (`lib/core/utils/validators.dart:21-28`): returns `'Enter an email address.'`
[REDACTED CREDENTIAL ROW]
- **Password Length Enforcement:**
[REDACTED CREDENTIAL ROW]
  - The UI renders this error in an `InfoBanner` styled with `BannerTone.danger`:
    - Header: `"Could not sign in"`
[REDACTED CREDENTIAL ROW]

### 2.3 Session Persistence & Token Storage
- **Token Management:**
  - Auth tokens are managed through the Flutter Supabase SDK backed by encrypted key-value storage.
  - The JWT contains user UUID `339f3ff2-d1e5-4eb5-82a6-8f4ed8028c32` (or current test account), role `authenticated`, and email `[REDACTED]`.
  - Edge Function calls pass this JWT as an HTTP `Authorization: Bearer <JWT>` header, validated server-side by `_shared/auth.ts:requireUser()`.
- **Logout Flow:**
  - Settings -> Account -> Logout executes `AuthController.signOut()`.
  - The Supabase auth session is cleared, local cache dropped, and the navigator redirects to `AppRoutes.login`.
  - Re-authentication with `[REDACTED]` cleanly restores the parent session and fetches fresh active family data.

---

## 3. Area 2: Dashboard, Device Management & Recovery Flow

### 3.1 Family Overview & Device Hierarchy
- **UI Dump Evidence:** `p02_dash.xml`, `p04_devices.xml`, `p05_devdetail.xml`, `A03_devlist.xml`, `A04_detail.xml`
- **Screenshot Evidence:** `p02_dash.png`, `p04_devices.png`, `p05_devdetail.png`, `A04_detail.png`
- **Overview Entities Rendered:**
  - **Family Name:** `demo` (Created Oct 29, 2026; Family Owner: `[ACCOUNT] (you)`)
  - **Child Card:** `[ACCOUNT]` (Role: Child; Joined Oct 29, 2026 11:17 AM)
  - **Device Card:** `realme RMX2161`
    - Battery: `100% (charging)`
    - Network / Sync Status: Swaps between `Online` (`synced 1 min ago · Nov 13, 2026 1:54 PM` in `A04_detail.xml`) and `Offline` (`last seen 2 h ago · Nov 13, 2026 10:18 AM` in `p05_devdetail.xml`).
    - Device Platform: `android` (OS Version: `Android 12`, App Version: `1.0.0`)
    - Enforcement Mode Banner: `"Device admin only"` / `"Not enforced"`

### 3.2 Permissions Snapshot & Defect E-3 Forensic Analysis
- **Observed Parent UI Display (`p05_devdetail.xml`, lines 18-35):**
  - Section Header: `Device permissions | Reported by the child device. Unknown means it has not reported.`
  - `Usage access`: **Granted** (`Required for screen-time reports`)
  - `Location`: **Granted**
  - `Background location`: **Granted**
  - `Camera`: **Granted**
  - `Microphone`: **Granted**
  - `Notifications`: **Granted**
- **Forensic Comparison with Child Native Runtime (Defect E-3 Confirmation):**
  - As established by Subagent 2 (`SUBAGENT2_CHILD_NATIVE_BACKEND.md` §3), the physical child device had revoked Usage Access and Background Location during testing.
  - Furthermore, `requestPermissions()` in `NativeBridge.kt:464-475` **never prompts for background location**, and Android 11+ prohibits granting background location alongside foreground location.
  - **Root Cause:**
    1. Parent UI parses permissions from `devices.capabilities` jsonb column (`lib/features/devices/device_presentation.dart:73-82`).
    2. The database updates `devices.capabilities` strictly during `heartbeat` telemetry requests (`supabase/functions/device-telemetry/index.ts:96-111`).
    3. When the child device is offline or encountering registration errors (Defect E-1), no new heartbeats are uploaded. The parent UI displays the frozen, outdated permissions indefinitely without any warning of staleness or indication that permissions were revoked while offline.

### 3.3 Enforcement Mode Display & App Suspension Warning
- **UI Warning Card (`p05_devdetail.xml`, lines 12-14):**
  - Title: `"App suspension is not supported here"`
  - Body: `"This device is not a fully managed Device Owner device. Parent Control cannot suspend or block apps until the phone is provisioned as fully managed. A policy flag on its own does not block an app."`
- **Architectural Validation:**
  - This accurately reflects Android Enterprise Device Administration constraints (`android.app.admin.DevicePolicyManager`).
  - Standard Device Admin cannot invoke `setPackagesSuspended()`; only Device Owner (provisioned via QR/NFC at initial device setup or ADB) can suspend packages without user intervention.
  - The Parent UI correctly warns the guardian rather than falsely claiming apps are suspended.

### 3.4 Command History Inspection
- **Observed States:**
  - Initial State (`p06_devdetail_scroll.xml`): `"Recent commands | Delivery is confirmed by the device, not by this screen. | No commands have been sent to this device yet."`
  - Post-Policy State (`J01_remote.xml`, lines 10-12): `"Recent commands | Delivery is confirmed by the device, not by this screen. | Apply policy | Succeeded · 32 min ago"`.
- **Command State Machine Verification:**
  - The parent queries `public.device_commands` (`supabase/migrations/20260101000000_core.sql:190-218`).
  - Status progression: `pending` -> `delivered` (fetched by child via `device-command/poll`) -> `acknowledged` (acked via `device-command/ack`).

### 3.5 Device Recovery Flow Deep-Dive
- **UI Dump Evidence:** `p08_recovery_card.xml`, `p09_recovery_dialog.xml`, `p10_recovery_done.xml`
- **Screenshot Evidence:** `p08_recovery_card.png`, `p09_recovery_dialog.png`, `p10_recovery_done.png`
- **Step-by-Step Flow Execution:**
  1. **Entry Point (`p08_recovery_card.xml`):**
     - Card Title: `"Lost or reinstalled phone"`
[REDACTED CREDENTIAL ROW]
  2. **Confirmation Dialog (`p09_recovery_dialog.xml`):**
     - Title: `"Start device recovery?"`
[REDACTED CREDENTIAL ROW]
  3. **Server Execution & RPC Delegation:**
     - Tapping `"Start recovery"` triggers `family-admin` Edge Function action `recover_device` (`supabase/functions/family-admin/index.ts:92-122`).
     - `family-admin` calls PostgreSQL RPC `public.request_device_recovery(p_device_id, p_actor_user_id)` (`supabase/migrations/20260101000400_device_recovery.sql:15-71`).
     - The RPC delegates to `private.unlink_child(v_device.family_id, v_device.child_user_id, p_actor_user_id)`:
       - Sets `devices.status = 'revoked'` and `devices.secret_hash = null`.
       - Sets `family_members.status = 'removed'`.
       - Cancels all pending pairing requests.
       - Records audit log entry: `device_recovery_started` and `member_removed`.
  4. **Post-Recovery Feedback (`p10_recovery_done.xml`):**
[REDACTED CREDENTIAL ROW]

---

## 4. Area 3: App Restrictions, Screen Time & Policy State Machine

### 4.1 App Restrictions Screen & Inventory
- **UI Dump Evidence:** `p26_apprestr.xml`, `p27_applist.xml`
- **Screenshot Evidence:** `p26_apprestr.png`, `p27_applist.png`
- **Initial Empty State Analysis (`p26_apprestr.xml`):**
  - Banner: `"Installed apps | This device has not reported its installed apps yet. An empty snapshot is not the same as 'no apps installed'."`
  - Explicit Disclaimer: `"A database flag does not block an app | Saving only stores the policy and queues a command. The app becomes restricted only after the child device acknowledges and applies it. Nothing on this screen claims an app is blocked before that acknowledgement."`
- **Post-Upload Populated State:**
  - After child app snapshot upload (`device-telemetry` `app_inventory` action), the parent list populates with all detected consumer packages (e.g., `System Launcher`, `YouTube`, `Telegram`, `RandoChat`, `Google Play Store`, `Settings`).
  - Search filter dynamically filters the list by display name and package name (`com.google.android.youtube`, etc.).

### 4.2 Screen Time Limits & Bedtime Configuration
- **UI Dump Evidence:** `p30_screentime.xml`, `p31_limit.xml`, `p35_timepicker.xml`, `p36_endpicker.xml`, `p37_bedtime_set.xml`, `p39_saved.xml`
- **Usage Metrics Displayed (`p30_screentime.xml`):**
  - Usage Access: `Granted` (`Usage Access is granted on the child device.`)
  - Last usage upload: `Recent · Nov 13, 2026 1:03 PM (6 min ago)`
  - Daily Usage Summary:
    - Today: `3h 15m`
    - Last 7 days: `5h 29m`
    - App breakdown: System Launcher (2h 16m), Parent Control (1h 44m), YouTube (1h 3m), Super Eagle Eye Child (5m), Telegram (4m), RandoChat (4m), Settings (1m), etc.
- **Configuring Screen Time Limits (`p31_limit.xml`):**
  - Default: `No daily limit`
  - Stepper controls (`Decrease limit`, `Increase limit`): Tapping increments quota in 15-minute / 30-minute intervals (e.g. set to `2 hours`).
- **Configuring Bedtime / Curfew (`p35_timepicker.xml` -> `p37_bedtime_set.xml`):**
  - Timepicker allows selecting Bedtime Start (e.g. `21:00` / 9:00 PM) and Bedtime End (e.g. `07:00` / 7:00 AM).
  - UI displays configured window: `"Bedtime: 9:00 PM – 7:00 AM"`.

### 4.3 Defect E-6: Bedtime/Curfew Has Zero Effect on Child Device
- **Symptom:** Setting a bedtime in the Parent UI never locks down the child device or blocks applications during bedtime hours.
- **Root Cause & Code Citation:**
  1. In `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:502-503`, the Kotlin worker checks:
     ```kotlin
     result.put("bedtime_active", policy.hasBedtime && policy.isWithinBedtime(TimeUtils.minuteOfDay(calendar)))
     ```
  2. The boolean `bedtime_active` is bundled into the command ACK JSON payload, but is **never ingested or acted upon** by `device-command/handler.ts` or database reconciliation.
  3. In `android/app/src/main/kotlin/.../PolicyModels.kt:67-76`, `ChildPolicy.isPackageBlockedNow()` evaluates only `appRules`, `blockedPackages`, and `allowedPackages`. **Bedtime is completely absent from the blocking evaluation loop.**
  4. Curfew / bedtime enforcement on the child is completely non-functional.

### 4.4 Defect E-7 & E-11: Misleading Status Aggregation & Terminal "Waiting for Device"
- **Defect E-7 (Status Conflation):**
  - In `supabase/functions/device-command/enforcement.ts:494`:
    ```typescript
    return { ...app, lastError: app.lastError ?? quota.lastError };
    ```
  - When saving a policy that combines an app rule and a quota, if app restriction returns `enforced`, `app.status` overwrites quota status (`unsupported` / `pending`).
  - In `app_restrictions_page.dart:403-410` and `screen_time_page.dart:289-297`, the parent UI renders a green `"Enforced on device"` banner (`A04_detail.xml`) even when the child lacks Usage Access and quota enforcement failed.
- **Defect E-11 (Terminal Pending State):**
  - Observed in `p40_after_poll.xml` where policy version remains stuck on `"Waiting for device"` (`pending`).
  - Mechanisms confirmed in source:
    1. A bedtime-only policy omits `daily_screen_time_limit_minutes`, causing `QuotaEvaluator.kt` to report `quota_not_configured`, which `enforcement.ts:401-403` maps to permanent `pending`.
    2. In `GuardianService.kt:475-480`, `store.markCommandHandled(commandId)` is called *before* the network POST ack succeeds. If the ack POST fails, the child never retries sending the ack, leaving the policy pending forever.

---

## 5. Area 4: Safe Zones & Geofencing

### 5.1 Safe Zone Inventory & Empty State
- **UI Dump Evidence:** `p50_zones.xml`
- **Screenshot Evidence:** `p50_zones.png`
- **Initial State:**
  - Screen Header: `"Safe zones | Refresh"`
  - Empty State Card: `"No safe zones yet | Safe zones are optional circles used for enter/exit alerts. Coordinates come from a location you enter, never from a map or a guessed position."`
  - Action Buttons: `"Create a zone"`, `"Create a safe zone"`

### 5.2 Creation Form & Form Validation
- **UI Dump Evidence:** `p51_zonedlg.xml`, `p52_radius_invalid.xml`, `p53_zone_created.xml`
- **Screenshot Evidence:** `p51_zonedlg.png`, `p52_radius_invalid.png`, `p53_zone_created.png`
- **Validation of Radius Limits:**
  - Creation Dialog fields: Zone Name, Latitude, Longitude, Radius (metres), Active toggle.
  - Submitting Radius = `10` (`p52_radius_invalid.xml`):
    - Inline error text appears below the radius field:
      `"Radius must be between 50 and 5000 metres"`
    - Submission is blocked.
- **Successful Creation:**
  - Entering Name = `"QA Test Zone"`, Lat = `[REDACTED COORDINATE]`, Lng = `[REDACTED COORDINATE]`, Radius = `150` (`p53_zone_created.xml`):
  - Form submits cleanly.
  - Card renders on list:
    - Title: `"QA Test Zone"`
    - Chip: `"Active"`
    - Centre: `[REDACTED COORDINATE]`
    - Radius: `150 m`
    - Actions: `Active` toggle switch, `"Edit"`, `"Delete"`

### 5.3 Edit, Update & Toggle Failure (PostgreSQL RLS 42501)
- **UI Dump Evidence:** `p54_edit_dlg.xml`, `p56_updated.xml`, `p58_toggle.xml`
- **Screenshot Evidence:** `p54_edit_dlg.png`, `p56_updated.png`, `p58_toggle.png`
- **Observed Failures:**
  1. Opening edit dialog (`p54_edit_dlg.xml`), modifying name to `"QA Test Zone B"`, and tapping Save (`p56_updated.xml`):
     - Red Error Banner: `"permission denied for table safe_zones"`
  2. Tapping the `"Active"` toggle switch to disable the zone (`p58_toggle.xml`):
     - Red Error Banner: `"Action failed | permission denied for table safe_zones"`
- **Forensic Root Cause:**
  - In `lib/data/repositories/supabase_location_repository.dart:126-133`:
    ```dart
    row = await _supabase.client
        .from('safe_zones')
        .update(payload)
        .eq('id', zone.id)
        .eq('family_id', familyId)
        .select()
        .single();
    ```
  - Direct PostgreSQL table UPDATE is attempted via PostgREST.
  - In `supabase/migrations/20261030000200_phase1_authorization.sql`, client permissions on `safe_zones` were tightened.
  - The `authenticated` role lacks SQL `UPDATE` privileges on `public.safe_zones` (or RLS policy `safe_zones_update_parent` checks fail), triggering PostgreSQL Error `42501` (`insufficient_privilege`).

### 5.4 Deletion Failure (Hosted Edge Function Drift)
- **UI Dump Evidence:** `p59_delconfirm.xml`, `p60_deleted.xml`
- **Screenshot Evidence:** `p59_delconfirm.png`, `p60_deleted.png`
- **Observed Failure:**
  1. Tapping `"Delete"` opens confirmation dialog (`p59_delconfirm.xml`):
     - Title: `Delete "QA Test Zone"?`
     - Body: `"This removes the zone for the whole family. Existing location history is not changed."`
     - Buttons: `"Cancel"`, `"Delete"`
  2. Confirming `"Delete"` triggers `supabase_location_repository.dart:147-151`:
     ```dart
     await _edgeApi.invoke(
       'family-admin',
       action: 'delete_zone',
       body: {'zone_id': zoneId},
     );
     ```
  3. The request fails immediately with red banner (`p60_deleted.xml`):
     `"Action failed | Unsupported action."`
- **Forensic Root Cause (CRITICAL HOSTED DEFECT):**
  - In the local repository (`supabase/functions/family-admin/index.ts:177-220`), `case "delete_zone"` exists and delegates to atomic RPC `delete_zone_atomic` (migration `20261103000100`).
  - However, in hosted Supabase (`hhqgreaoqulmfwfwarhc`), `family-admin` is on build **v6**, deployed on **2026-10-26T20:41Z** (verified in `docs/supabase-hosted-state-verification-2026-11-05.md:137`).
  - No Edge Function redeployment has occurred since October 27, 2026.
  - The deployed v6 `family-admin` function does not contain the `delete_zone` action handler and returns `ApiError("unsupported_action", "Unsupported action.", 400)`.
  - **Zone deletion is completely broken in the live hosted environment.**

---

## 6. Area 5: Safety Alerts Lifecycle & Filter Engine

### 6.1 Alerts Surface & Severity Filtering
- **UI Dump Evidence:** `H01_alerts.xml`, `H02_filter_critical.xml`, `H03_filter_info.xml`, `H04_all.xml`
- **Screenshot Evidence:** `H01_alerts.png`, `H02_filter_critical.png`, `H03_filter_info.png`, `H04_all.png`
- **Observed Header:** `"Alerts | 2 unacknowledged · 2 total"`
- **Filter Chip Behavior:**
  - **All (`H04_all.xml`):** Displays all 2 alerts in chronological order:
    1. `Device battery is low (4%). | Low battery | Warning | Device: realme RMX2161 | Time: Nov 3, 2026 5:47 PM`
    2. `Device battery is low (1%). | Low battery | Warning | Device: realme RMX2161 | Time: Oct 30, 2026 7:45 AM`
  - **Warning (`H01_alerts.xml`):** Correctly lists both `low_battery` alerts (severity `warning`).
  - **Critical (`H02_filter_critical.xml`):** Filters to empty state:
    `"No alerts with this severity | Choose another filter to see the rest."`
  - **Info (`H03_filter_info.xml`):** Filters to empty state:
    `"No alerts with this severity | Choose another filter to see the rest."`

### 6.2 Acknowledgment Flow Execution
- **UI Dump Evidence:** `H05_ack1.xml`, `H06_after_ack.xml`
- **Screenshot Evidence:** `H05_ack1.png`, `H06_after_ack.png`
- **Execution Pipeline:**
  1. On the Nov 3 alert card, tap `"Acknowledge"` (`H05_ack1.xml`).
  2. `SafetyAlertsController.acknowledgeAlert()` invokes `SupabaseAlertRepository.acknowledge()` (`lib/data/repositories/supabase_alert_repository.dart:45-57`).
  3. The repository calls `family-admin` Edge Function action `ack_alert`:
     - Schema reference: `supabase/functions/family-admin/index.ts:124-166`
     - Writes `safety_alerts.acknowledged_at = now()`, `acknowledged_by = auth.uid()`.
     - Calls `recordAudit()` writing event `alert_acknowledged` with metadata `{alert_type: "low_battery"}`.
  4. UI immediately updates (`H06_after_ack.xml`):
     - Unread badge decrements: `"1 unacknowledged · 2 total"`.
     - Nov 3 card replaces `"Acknowledge"` button with an `"Acknowledged"` status chip.

### 6.3 Declared vs Generated Alert Types (Forensic Verification)
Cross-referencing with `AGENT4_ALERTS_POLICY_ANALYSIS.md` §A:
- **Schema CHECK Constraint (`core.sql:302-303`):** 7 declared types:
  `low_battery`, `offline`, `geofence_enter`, `geofence_exit`, `app_blocked`, `permission_missing`, `other`.
- **Runtime Generation Reality:**
  - `low_battery`: **GENERATED** (`device-telemetry/index.ts:121-148` when `batteryLevel <= 20 && isCharging === false`). Verified by live alerts.
  - `offline`: **GENERATED BY PG_CRON** (`private.detect_offline_devices()` in `functions.sql:555-568`).
  - `geofence_enter` / `geofence_exit`: **GENERATED** (`device-telemetry/index.ts:314-351` during location upload).
  - `app_blocked`: **NEVER GENERATED** (Zero writers in entire codebase).
  - `permission_missing`: **NEVER GENERATED** (Permissions are reported in heartbeat to `devices` column, but no alert row is ever inserted).
  - `other`: **NEVER GENERATED** (Defensive Dart enum fallback only).

---

## 7. Area 6: Remote Assistance & WebRTC UI State

### 7.1 Remote Assistance Surface & Session History
- **UI Dump Evidence:** `J01_remote.xml`, `J03_remote_page.xml`, `J04_after_req.xml`, `J06_sent.xml`, `J10_ra_fresh.xml`
- **Screenshot Evidence:** `J01_remote.png`, `J03_remote_page.png`, `J04_after_req.png`, `J06_sent.png`, `J10_ra_fresh.png`
- **Assistance Page Structure (`J03_remote_page.xml`):**
  - Informational Banner: `"Assistance with explicit consent | A request is delivered to the child account. Nothing opens until the child accepts it and then taps Join on their own session screen; you join from the session screen on this phone. This phone's camera and microphone are never opened by the app. Nothing is recorded, and no screenshots or screen capture are taken. A pending request expires if it is not answered; once accepted, the session stays open until the guardian ends it. The status on each card is the server's session status, not a media indicator."`
  - Action Buttons: `"Request audio"`, `"Request video"`
  - Disclaimer: `"Audio and video come from the child device only, after the child accepts and joins. This phone's camera and microphone are never opened, so audio assistance is listen-only."`
  - Session Count: `"Recent sessions | 9"`

### 7.2 Forensic Analysis: "Media: No media is open" & Defect E-2
- **UI String Origin:**
  - Across all 9 sessions in the list (`J03_remote_page.xml`, `J10_ra_fresh.xml`), each card displays:
    `"Video assistance | Ended | Device: realme RMX2161 | Child: [ACCOUNT] | Media: No media is open | Requested: Nov 13, 2026 11:47 AM"`
  - **Forensic Finding:** In `lib/data/models/remote_session.dart:156-171`:
    ```dart
    String get mediaNote {
      if (status == RemoteSessionStatus.ended) return 'No media is open';
      if (status == RemoteSessionStatus.rejected) return 'Request was rejected';
      if (status == RemoteSessionStatus.expired) return 'Request expired';
      ...
    }
    ```
  - The text `"No media is open"` is a static model description displayed whenever a session has reached the terminal state `ended`. It is **not** an active WebRTC error dialog.
- **Defect E-2 Root Cause ("WebRTC media never opens"):**
  - As proven by Subagent 3 (`SUBAGENT3_WEBRTC_MEDIA_REPORT.md` §1), real-time WebRTC media connectivity indeed fails between `emulator-5554` and `RMX2161`.
  - The failure is caused by **NAT traversal breakdown under STUN-only configuration**:
    1. The hosted Supabase project has **no `TURN_URL` or `TURN_SECRET`** environment secrets configured (`docs/supabase-hosted-state-verification-2026-11-05.md:141`).
    2. Edge Function `remote-session` returns STUN-only (`stun:stun.l.google.com:19302`).
    3. The physical child device is behind carrier CGNAT, and the parent emulator is behind host virtual NAT (`10.0.2.x`). Without a TURN relay, peer-to-peer UDP hole-punching fails across symmetric NAT.
    4. The child screen explicitly shows the live warning:
       `"Relay not configured | No TURN relay is configured. Audio/video may fail to connect on networks with strict firewalls or carrier NAT."` (`child/_J16.txt`).

### 7.3 Request Session Creation & Defect E-12 (Stranded Sessions)
- **Request Dialog Flow (`J04_after_req.xml`):**
  - Tapping `"Request audio"` displays confirmation dialog:
    `"Request audio assistance? | Sending this request notifies the child. The child must accept it, then tap Join on their own phone to start the session. You join from the session screen afterwards. This phone's camera and microphone are never opened... The request expires in 10 minutes."`
  - Actions: `"Cancel"`, `"Send request"`
- **Defect E-12 Consequence (`J06_sent.xml`):**
  - If a prior session did not terminate cleanly via an explicit parent `end` action, the row remains in `accepted` or `active` state in `public.remote_sessions`.
  - Submitting a new request causes `public.request_remote_session()` RPC to throw `session_in_progress`, resulting in HTTP 409 and UI banner:
    `"Request failed | The device is not active."`

---

## 8. Area 7: Audit Logs, Family Management & Privacy / Retention

### 8.1 Audit Log Surface & Server Event History
- **Target Page:** `lib/features/audit_logs/audit_logs_page.dart`
- **Controller & Repository:** `AuditLogsController` (`lib/features/audit_logs/audit_logs_controller.dart`), `SupabaseAuditRepository` (`lib/data/repositories/supabase_audit_repository.dart`).
- **Data Source:** `public.audit_logs` table (`supabase/migrations/20260101000000_core.sql:318-348`).
- **Audit Entries Ingested & Rendered:**
  - 36+ real server audit events populate the timeline chronologically.
  - Event types accurately decoded by `AuditLogEntry.readableEvent` (`lib/data/models/audit.dart:28-75`):
    1. `device_recovery_started` -> Displayed as `"Device recovery started"`
    2. `member_removed` -> Displayed as `"Child account unlinked"`
    3. `pairing_invited` -> Displayed as `"pairing invited"` (fallback label)
    4. `pairing_approved` -> Displayed as `"Pairing approved"`
    5. `device_registered` -> Displayed as `"Device enrolled"`
    6. `alert_acknowledged` -> Displayed as `"Alert acknowledged"`
    7. `policy_updated` -> Displayed as `"Policy updated"`
- **Security & Read-Only Validation:**
  - The audit log is strictly read-only for guardians.
  - The table RLS policy `audit_logs_select_family` permits SELECT only; no client INSERT/UPDATE/DELETE policies exist.

### 8.2 Family Overview & Retention Settings
- **UI Dump Evidence:** `p12_family.xml`, `p13_family_scroll.xml`
- **Screenshot Evidence:** `p12_family.png`, `p13_family_scroll.png`
- **Family Metadata Displayed:**
  - Family Name: `demo`
  - Owner: `[ACCOUNT] (you)`
  - Created Date: `Oct 29, 2026`
  - **Location Retention:** `30 days`
  - **Usage Retention:** `90 days`
  - Guardians: `[ACCOUNT] (you)` (`Family owner · Active`)
  - Children: `Family member · Role: Child · Joined Oct 29, 2026 11:17 AM`
  - Linked Devices: `realme RMX2161`

### 8.3 Defect E-5: Missing `account` Edge Function & Privacy UI Failure
- **UI Dump Evidence:** `p02_dash.xml` (Settings Tab, lines 1-10)
- **Observed Error in UI:**
  - Section: `Privacy & data | Export or delete your own account, and see the retention windows the server enforces.`
  - Red Error Text:
    `"Retention report unavailable: Requested function was not found"`
- **Forensic Root Cause (Defect E-5 Confirmation):**
  - In `lib/data/repositories/account_privacy_repository.dart:150-266`, the parent app attempts to call Edge Function `account` with action `retention_report`:
    ```dart
    final res = await _edgeApi.invoke('account', action: 'retention_report');
    ```
  - In hosted Supabase (`hhqgreaoqulmfwfwarhc`), the `account` function was **never deployed** (only 9 functions exist: `auth-bootstrap`, `pairing`, `device-register`, `device-policy`, `family-admin`, `remote-session`, `device-command`, `device-telemetry`, `cron`).
  - The Supabase Edge runtime returns HTTP 404 (`Function not found`), blocking the Retention report, Data Export, and Account Deletion endpoints.
- **Account Deletion UI Validation:**
  - Even with the backend endpoint missing, the frontend enforces strict safety guards:
    - Requires two separate confirmation dialogs.
    - Requires typing `DELETE` and entering the exact account email (`[REDACTED]`).
    - If active family members or linked devices exist, deletion is rejected.

---

## 9. Comprehensive UI Dump & Screen Asset Cross-Reference

The table below catalogs the primary XML hierarchy dumps and PNG screenshots gathered during live execution on `emulator-5554` (stored under `docs/testing/final_two_device_audit/parent/`):

| File Prefix | Corresponding UI Screen / Flow | Key Interactive Nodes & Center Bounds | Verified State / Outcome |
|---|---|---|---|
| `p02_dash` | Parent Dashboard (Tab 1) | Privacy card, Device permissions, Tab buttons | Verified family overview, 30d/90d retention display, Defect E-5 error banner. |
| `p04_devices`| Devices List (Tab 2) | `realme RMX2161` card (`[0,278][1080,684]`), Open device button | Device card renders battery, sync state, and "Device admin only" tag. |
| `p05_devdetail`| Device Management Detail | Refresh device, Permissions card, App suspension warning | Verified Defect E-3 (stale permissions) and Device Admin suspension warning. |
| `p08_recovery_card`| Device Recovery Entry | `"Start device recovery"` button (`[48,1980][1032,2106]`) | Verified "Lost or reinstalled phone" card copy and recovery initiation button. |
| `p09_recovery_dialog`| Recovery Confirmation Modal | `"Start recovery"` button (`[670,1310][986,1436]`) | Modal warns of credential revocation and child unlinking. |
| `p10_recovery_done`| Post-Recovery Status | Banner: `"Recovery started on the server"` | Server revokes credential; unlinks child; clears command queue. |
| `p12_family` | Family Settings Screen | `"Audit log (read-only)"` button (`[48,1890][1032,2016]`) | Displays family `demo`, members, retention windows, and audit log launcher. |
| `p15_redeem` | Link a Child / Redeem Code | QR scan viewport, Child ID manual text field | Enforces Child ID / pairing token format; informs child must approve. |
| `p16_empty_submit`| Pairing Form Validation | Warning banner: `"Only Parent Control pairing codes are accepted"` | Submitting empty pairing field triggers Defect E-10 warning banner. |
| `p26_apprestr`| App Restrictions Overview | Policy state card, Installed apps disclaimer | Accurately explains database flag does not block apps without child ack. |
| `p27_applist` | Installed Apps & Allowed List | Block all toggle, Allowed apps list, Save restrictions button | Successfully lists packages once child snapshot arrives. |
| `p30_screentime`| Screen Time Dashboard | Today/7d charts, Per-app usage breakdown | Displays accurate usage telemetry (`3h 15m` today, System Launcher top). |
| `p31_limit` | Screen Time Limits Stepper | Decrease limit (`[84,1850][210,1976]`), Increase limit | Increments quota in 15-minute steps. |
| `p37_bedtime_set`| Bedtime Window Config | Bedtime timepickers (`21:00` to `07:00`), Save button | Configures bedtime window (Defect E-6: ignored by child native applier). |
| `p50_zones` | Safe Zones Initial View | `"Create a safe zone"` button (`[48,1720][1032,1846]`) | Confirms clean empty state and coordinate entry guidance. |
| `p52_radius_invalid`| Safe Zone Form Validation | Radius field (`10`), Error: `"Radius must be between 50 and 5000 metres"` | Validates radius bounds (50–5000m) inline. |
| `p53_zone_created`| Safe Zone Created Card | QA Test Zone card (`[48,350][1032,780]`), Active toggle, Edit, Delete | Successfully inserts zone via Supabase client. |
| `p56_updated` | Safe Zone Edit Dialog | Red Banner: `"permission denied for table safe_zones"` | Confirms PostgreSQL RLS 42501 blocks direct client UPDATE. |
| `p58_toggle` | Safe Zone Toggle Switch | Red Banner: `"Action failed | permission denied for table safe_zones"` | Confirms toggle also blocked by RLS 42501. |
| `p60_deleted`| Safe Zone Delete Action | Red Banner: `"Action failed | Unsupported action."` | Confirms hosted `family-admin` v6 lacks `delete_zone` action. |
| `H01_alerts` | Safety Alerts List (Tab 3) | Severity filter chips (All, Info, Warning, Critical) | Filters alerts list; displays 2 unacknowledged low battery alerts. |
| `H05_ack1` | Alert Acknowledgment Action | `"Acknowledge"` button (`[780,820][1032,946]`) | Dispatches `family-admin` `ack_alert`. |
| `H06_after_ack`| Post-Ack Alerts List | Card status updated to `"Acknowledged"`, Badge: `1 unacknowledged` | Confirms optimistic UI update and server audit write. |
| `J03_remote_page`| Remote Assistance Surface | `"Request audio"`, `"Request video"`, 9 recent session cards | Displays consent notice, session history, and "Media: No media is open". |
| `J04_after_req`| Assistance Request Modal | `"Send request"` button (`[640,1350][986,1476]`) | 10-minute expiry warning; informs audio is listen-only. |
| `J06_sent` | Stranded Session Error | Red Banner: `"Request failed | The device is not active."` | Confirms Defect E-12: stranded session locks subsequent requests. |

---

## 10. Audit Conclusions & Remediation Roadmap

The Parent application on `emulator-5554` demonstrates exceptional architectural fidelity to privacy, explicit consent, and honest status presentation. The app correctly refuses to simulate enforcement, clearly delineating between server-stored policies and on-device child acknowledgments.

However, full end-to-end production readiness is obstructed by four backend deployment and native integration defects:

1. **Deploy Hosted Edge Function `account` (Resolves Defect E-5):**
   - Deploy `supabase/functions/account/` to `hhqgreaoqulmfwfwarhc` to restore Retention reports, data export, and account deletion.
2. **Redeploy Hosted Edge Function `family-admin`:**
   - Update `family-admin` from v6 (Oct 26) to current HEAD (incorporating migration `20261103000100` and `delete_zone` action) to unblock Safe Zone deletions.
3. **Grant Parent UPDATE on `safe_zones` Table (or Route Edits via Edge Function):**
   - Resolve PostgreSQL RLS 42501 error by either adding `safe_zones_update_parent` RLS policy or routing zone updates through `family-admin`.
4. **Provision TURN Relay Credentials for WebRTC (Resolves Defect E-2):**
   - Configure `TURN_URL` and `TURN_SECRET` secrets on hosted Supabase to enable media traversal across cellular CGNAT and emulator virtual NAT.
5. **Implement Native Bedtime Enforcement (Resolves Defect E-6):**
   - Update `PolicyModels.kt:isPackageBlockedNow()` on Android child client to evaluate `bedtime_active` and suspend non-whitelisted apps during curfew.
