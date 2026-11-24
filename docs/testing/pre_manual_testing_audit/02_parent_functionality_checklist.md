# 02 — Parent Functionality Checklist

**Document ID:** `HAVEN-INV-002`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Target Role:** Parent Mode  
**Coverage:** 68 Total Accessible Functionalities (41 Parent-Only + 17 Shared + 10 Interconnected)  

---

## 1. Overview & Verification Protocol

This document provides a systematic, step-by-step testing checklist for every capability accessible from the **Parent role** in HAVEN Parent Control. 

> [!IMPORTANT]
> **Pre-Testing State**: In accordance with the audit protocol, **all items are marked `[ ] NOT TESTED`**. No runtime tests have been executed. This checklist serves as the authoritative guide for the future authorized QA execution phase.

---

## 2. Parent Testing Checklist by Screen & Module

### 2.1 Parent Authentication, Role & Session Initialization
- [ ] **A01 — Email/Password Sign-In**: Navigate to `/auth/login`. Enter registered parent credentials. Tap "Sign In". Assert session created, token stored, and routes to `/parent`. Status: `IMPLEMENTED`.
- [ ] **A02 — Parent Account Registration**: Navigate to `/auth/register`. Enter name, parent email, password, confirm password. Tap "Create Account". Assert user created in Supabase Auth and routes to verify email. Status: `IMPLEMENTED`.
- [ ] **A03 — Email Verification Flow**: Navigate to `/auth/verify-email`. Tap "Resend confirmation". Confirm resend banner. On email link click, assert session updates. Status: `IMPLEMENTED`.
- [ ] **A04 — Persisted Session Restoration**: Cold-launch app with existing parent session. Assert splash screen (`/`) bypasses login and routes directly to `/parent` within 2 seconds. Status: `IMPLEMENTED`.
- [ ] **A05 — Parent Sign Out**: From Settings tab, tap "Sign Out". Confirm prompt. Assert tokens cleared, local cache purged, and routed to `/auth/login`. Status: `IMPLEMENTED`.
- [ ] **A06 — Set Parent Role**: On `/role-selection`, enter display name, tap "Set parent role". Assert `profiles.role` set to `'parent'` in backend and routes to family setup. Status: `IMPLEMENTED`.
- [ ] **A11 — Password Masking Toggle**: On login/register screens, tap eye icon on password input. Assert text toggles between obscured `*` and plain text. Status: `IMPLEMENTED`.
- [ ] **A12 — Real-Time Form Validation**: Type invalid email format in email field. Assert inline validation error appears immediately. Type valid email; assert error disappears. Status: `IMPLEMENTED`.

### 2.2 Family Creation & Management
- [ ] **FAM08 — Create Family Group**: Navigate to `/parent/family-setup`. Enter family name (e.g. "Smith Family"). Tap "Create Family". Assert row inserted in `families` with parent as owner. Status: `IMPLEMENTED`.
- [ ] **FAM09 — View Family Members & Roles**: Navigate to Settings → Family (`/parent/family`). Assert screen lists family name, parent accounts, and all linked child devices with counts. Status: `IMPLEMENTED`.
- [ ] **FAM10 — Unlink Child from Family**: On Family page, tap "Unlink Child" on child card. Confirm dialog. Assert child device unlinked, sessions ended, and child removed from active list. Status: `IMPLEMENTED`.

### 2.3 Child Linking & Pairing (Parent Side)
- [ ] **FAM01 — Link Child via QR Code Scanner**: Navigate to `/parent/pairing/redeem`. Tap "Scan QR Code". Point camera at Child enrollment QR. Assert code scanned, pairing validated, and child added. Status: `IMPLEMENTED`.
- [ ] **FAM02 — Link Child via 6-Digit Code**: Navigate to `/parent/pairing/redeem`. Enter child's 6-character linking code. Tap "Connect". Assert pairing redeemed and family relationship linked. Status: `IMPLEMENTED`.
- [ ] **FAM03 — Send Outgoing Pairing Request**: On `/parent/pairing/redeem`, enter child ID and submit. Assert request created with status `'pending'` in `pairing_requests`. Status: `IMPLEMENTED`.
- [ ] **FAM04 — View & Cancel Outgoing Pairing Requests**: Navigate to `/parent/pairing/requests`. Assert pending requests displayed. Tap "Cancel". Assert request marked `'cancelled'`. Status: `IMPLEMENTED`.

### 2.4 Parent Dashboard Overview
- [ ] **MON01 — Dashboard Overview Cards**: Open Dashboard tab (`/parent`). Assert top family banner, child summary cards, battery levels, online status badges, and quick action tiles render. Status: `IMPLEMENTED`.
- [ ] **MON08 — Dashboard Pull-to-Refresh**: Pull down on dashboard scroll view. Assert refresh spinner activates and data re-queries without layout flicker. Status: `IMPLEMENTED`.
- [ ] **MON09 — Policy & Sync Status Display**: Inspect child device card on dashboard. Assert badge displays "Active Protection" when synced or "Sync Delayed" when telemetry stale. Status: `IMPLEMENTED`.

### 2.5 Connected Devices & Device Detail
- [ ] **MON02 — Connected Devices List**: Open Devices tab (`/parent`). Assert all paired devices render with OS version, battery percentage, and enforcement status chips. Status: `IMPLEMENTED`.
- [ ] **MON03 — Device Detail Telemetry**: Tap a device card to open `/parent/devices/detail`. Assert device identity, battery status, charging indicator, last seen timestamp, and Android SDK version render. Status: `IMPLEMENTED`.
- [ ] **MON04 — Online / Offline Presence Indicator**: On Device Detail, observe status badge. Assert "Online" if heartbeat < 5m ago; "Offline" if > 5m ago. Status: `PARTIALLY_IMPLEMENTED` (Breaks after child reinstall).
- [ ] **MON05 — Child Permissions Diagnostic Summary**: On Device Detail, scroll to Permissions card. Assert status chips for Camera, Mic, Fine Location, Background Location, Notifications. Status: `PARTIALLY_IMPLEMENTED` (Android 12 false-positive).
- [ ] **MON06 — Command Delivery History**: On Device Detail, expand "Command History". Assert table of recent commands (`apply_policy`, `sync_policy`) shows status (`delivered`, `succeeded`, `failed`). Status: `IMPLEMENTED`.
- [ ] **MON10 — Filter Active vs Revoked Devices**: On Devices tab, tap the filter icon. Assert view toggles between active enrolled devices and historical revoked devices. Status: `IMPLEMENTED`.
- [ ] **FAM12 — Revoke Device**: On Device Detail, tap "Revoke Device". Confirm dialog. Assert device status set to `'revoked'`, removed from active list, and commands rejected. Status: `IMPLEMENTED`.
- [ ] **FAM13 — Initiate Device Recovery**: On Device Detail for unlinked device, tap "Recover Credentials". Assert recovery challenge dispatched. Status: `IMPLEMENTED` (Legacy) / Target of Wave 3 (`HAVEN-QA-003`).

### 2.6 Screen Time & Usage Oversight
- [ ] **USE01 — Daily Screen Time Usage Graph**: Navigate to `/parent/screen-time`. Assert 7-day bar chart renders with daily screen time totals in hours/minutes. Status: `IMPLEMENTED`.
- [ ] **USE02 — Per-App Daily Usage Breakdown**: On Screen Time page, select a date bar. Assert app list displays apps used, duration, and percentage of daily total. Status: `IMPLEMENTED`.
- [ ] **USE03 — Usage Access Diagnostic Banner**: On Screen Time page, check top banner. If child missing Usage Access, assert warning banner displays guidance. Status: `IMPLEMENTED`.
- [ ] **USE05 — Set Daily Screen Time Limit**: On Screen Time page, adjust daily limit slider to 2h 30m. Tap "Save Limit". Assert policy updated and sync command dispatched. Status: `IMPLEMENTED`.
- [ ] **USE06 — Configure Bedtime Hours**: On Screen Time page, set bedtime start (21:00) and end (07:00). Tap "Save". Assert bedtime rule saved in `device_policies`. Status: `PARTIALLY_IMPLEMENTED` (Informational only; no auto-lock).
- [ ] **USE07 — Remaining Daily Quota Calculation**: On Screen Time page, inspect "Remaining Time" gauge. Assert calculation correctly displays `daily_limit - usage_today`. Status: `IMPLEMENTED`.

### 2.7 Application Restrictions & Blocking
- [ ] **APP01 — Block Individual Applications**: Navigate to `/parent/app-restrictions`. Find an app (e.g. YouTube). Toggle switch to "Blocked". Tap "Save". Assert policy dispatches `apply_policy`. Status: `IMPLEMENTED`.
- [ ] **APP02 — Enable Whitelist Mode**: On App Restrictions page, toggle "Block all except allowed". Tap "Save". Assert policy payload sets `block_all_except_allowed: true`. Status: `IMPLEMENTED`.
- [ ] **APP03 — Manage Allowed Apps (Whitelist)**: Under whitelist mode, toggle apps into "Always Allowed" list. Assert essential apps remain permitted. Status: `IMPLEMENTED`.
- [ ] **APP04 — Set Per-App Schedule Windows**: On an app row, tap "Add Schedule". Select start (15:00) and end (17:00). Save. Assert `app_rules.windows` saved in policy. Status: `IMPLEMENTED`.
- [ ] **APP05 — Enforcement Acknowledgment Report**: On App Restrictions page, check footer status. Assert "Enforced: X apps suspended" confirms child native execution. Status: `IMPLEMENTED`.
- [ ] **APP06 — Manual Policy Sync Trigger**: On App Restrictions page, tap "Sync Now". Assert `sync_policy` command created in queue and status updates on child poll. Status: `IMPLEMENTED`.
- [ ] **APP08 — App Restrictions Search & Filter**: On App Restrictions page, type app name in search bar. Assert app list filters dynamically in real-time. Status: `IMPLEMENTED`.

### 2.8 Location Tracking & Safe Zones
- [ ] **LOC01 — View Latest Child Location**: Navigate to `/parent/location`. Assert Google Map renders child marker pin, accuracy radius circle, and address geocode. Status: `IMPLEMENTED`.
- [ ] **LOC02 — View Historical Location Breadcrumbs**: On Location page, select "Last 24 Hours". Assert chronological breadcrumb path and event list display GPS coordinates. Status: `IMPLEMENTED`.
- [ ] **LOC05 — Create & Edit Safe Zones**: Navigate to `/parent/safe-zones`. Tap "Add Safe Zone". Set name ("Home"), center coordinates, radius (300m). Save. Assert safe zone created. Status: `IMPLEMENTED`.
- [ ] **LOC11 — Dynamic Safe Zone Radius Slider**: In safe zone editor, drag radius slider between 100m and 2000m. Assert radius label and map preview circle update live. Status: `IMPLEMENTED`.

### 2.9 Safety Alerts Management
- [ ] **LOC06 — Geofence Transition Alerts**: Trigger child crossing safe zone perimeter. Open Alerts tab (`/parent`). Assert "Child Exited Home" alert displayed. Status: `IMPLEMENTED`.
- [ ] **LOC07 — Low Battery Alerts**: Child battery drops < 15%. Open Alerts tab. Assert "Low Battery (12%)" alert appears with amber warning icon. Status: `IMPLEMENTED`.
- [ ] **LOC08 — Offline Inactivity Alerts**: Child offline > 15m. Open Alerts tab. Assert "Device Offline" alert appears. Status: `IMPLEMENTED`.
- [ ] **LOC09 — Permission Tampering Alerts**: Child disables location permission. Open Alerts tab. Assert "Permission Revoked: Location" alert appears. Status: `IMPLEMENTED`.
- [ ] **LOC10 — Filter & Acknowledge Alerts**: On Alerts tab, filter by "Critical". Tap "Acknowledge" on an alert. Assert alert moves to acknowledged history. Status: `IMPLEMENTED`.

### 2.10 Remote Assistance & Live Calling
- [ ] **REM01 — Request Remote Assistance Call**: Navigate to `/parent/assistance`. Tap "Start Assistance Call". Assert session invite created and ringing dialog opens. Status: `IMPLEMENTED`.
- [ ] **REM03 — WebRTC Audio/Video Connection**: Child accepts call. Assert live WebRTC stream connects with two-way audio and child camera video feed. Status: `IMPLEMENTED`.
- [ ] **REM04 — Remote Session History List**: On Remote Assistance page, view history list. Assert past calls show date, duration, and status (`completed`, `declined`). Status: `IMPLEMENTED`.
- [ ] **REM05 — End Remote Session**: During active call, tap "End Call". Assert WebRTC peer connection terminates, camera hardware released, and routes to summary. Status: `IMPLEMENTED`.
- [ ] **REM06 — In-Call Audio/Video Controls**: During call, tap Mute Mic, Disable Video, or Flip Camera. Assert respective media tracks pause/flip cleanly. Status: `IMPLEMENTED`.

### 2.11 Audit Logs & Data Retention
- [ ] **AUD01 — View Paginated Audit Logs**: Navigate to `/parent/audit`. Assert table displays chronological list of actions (policy update, safe zone delete, device unlink). Status: `IMPLEMENTED`.
- [ ] **AUD02 — Update Data Retention Period**: On Audit page, change retention period from 90 to 60 days. Tap "Save". Assert `family_settings.retention_days` updated. Status: `IMPLEMENTED`.
- [ ] **AUD03 — On-Demand Historical Log Purge**: On Audit page, tap "Purge Logs Older Than Retention". Confirm. Assert expired rows deleted from `audit_logs`. Status: `IMPLEMENTED`.

### 2.12 Parent Settings & System Health
- [ ] **A07 — View Parent Profile**: Open Settings tab (`/parent`). Assert parent email, display name, family name, and role badge display accurately. Status: `IMPLEMENTED`.
- [ ] **A08 — Export Account Data**: In Settings → Privacy & Data, tap "Export Data". Confirm. Assert JSON payload generated and previewed in dialog. Status: `IMPLEMENTED`.
- [ ] **A09 — Delete Parent Account**: In Settings → Privacy & Data, tap "Delete Account". Enter password and confirm. Assert account deleted and routed to splash. Status: `IMPLEMENTED`.
- [ ] **SET01 — Local Notification Switch**: Toggle "Local notifications" switch. Assert boolean persists in local storage. Status: `UI_ONLY` (Unconsumed).
- [ ] **SET02 — Location Reminder Switch**: Toggle "Location reminder" switch. Assert boolean persists in local storage. Status: `UI_ONLY` (Unconsumed).
- [ ] **SET03 — View Application Version**: Scroll to bottom of Settings. Assert app version string matches package metadata (e.g. `1.0.0+1`). Status: `IMPLEMENTED`.
- [ ] **SET04 — Request Missing OS Permissions**: Tap permission request button if camera/mic missing. Assert Android system dialog opens. Status: `IMPLEMENTED`.
- [ ] **SET07 — Permission Status Tile Display**: Inspect permissions list in Settings. Assert clean chips showing "Granted" or "Denied". Status: `IMPLEMENTED`.
- [ ] **SYS01 — Offline State Banner**: Disconnect Wi-Fi/cellular. Assert global yellow banner "No internet connection" surfaces without app crashing. Status: `IMPLEMENTED`.
- [ ] **SYS02 — Background Polling Refresh**: Leave app open on dashboard for 60 seconds. Assert status and timestamps refresh silently in background. Status: `IMPLEMENTED`.
