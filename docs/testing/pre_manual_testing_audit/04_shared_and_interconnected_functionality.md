# 04 — Shared and Interconnected Functionality Inventory

**Document ID:** `HAVEN-INV-004`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Scope:** Shared Architecture (17 Features) & Interconnected Workflows (10 Workflows)  

---

## 1. Executive Summary

This document details the shared infrastructure and interconnected workflows that bridge the Parent and Child roles in HAVEN Parent Control. 

While shared features provide common authentication, local persistence, and error handling for either role, **interconnected features represent distributed workflows** where an action initiated on one device (or the background daemon) traverses the Supabase network boundary to produce an observable state change or security outcome on the counterpart device.

---

## 2. Shared Functionality Inventory (17 Features)

Shared functionalities are built on common core widgets, services, and repositories that operate identically regardless of the authenticated role:

| Functionality ID | Feature Name | Primary Layer | Operational Trigger | System Response & Outcome | Implementation Status | Core Source Files |
|---|---|---|---|---|---|---|
| **A01** | Email/Password Sign-In | Shared Auth | User submits email & password on login screen | Verifies credentials with Supabase Auth; caches JWT in local storage | `IMPLEMENTED` | `login_page.dart`<br/>`supabase_auth_repository.dart` |
| **A02** | Account Registration | Shared Auth | User submits registration form | Registers auth user; invokes `auth-bootstrap`; sends verification email | `IMPLEMENTED` | `register_page.dart`<br/>`auth-bootstrap/index.ts` |
| **A03** | Email Verification Handling | Shared Auth | User clicks verification link or taps resend | Refreshes auth session; transitions account to verified state | `IMPLEMENTED` | `verify_email_page.dart`<br/>`verify_email_controller.dart` |
| **A04** | Persisted Session Restoration | Shared Core | Application cold start | Inspects `SharedPreferences`; restores session; routes to role shell | `IMPLEMENTED` | `splash_page.dart`<br/>`session_service.dart` |
| **A05** | Sign Out & Session Cleardown | Shared Auth | User confirms "Sign Out" in settings | Revokes auth session; wipes local cache; routes to `/auth/login` | `IMPLEMENTED` | `parent_settings_controller.dart`<br/>`child_shell_controller.dart` |
| **A06** | Role Selection & Assignment | Shared Auth | User selects role on first login | Submits role to `auth-bootstrap`; locks account role in `profiles` | `IMPLEMENTED` | `role_selection_page.dart`<br/>`auth-bootstrap/index.ts` |
| **A07** | Account Profile Overview | Shared Settings | User opens Settings tab | Renders display name, email, family ID, and assigned role badge | `IMPLEMENTED` | `settings_body.dart`<br/>`session_service.dart` |
| **A08** | Account Data Export (GDPR) | Shared Settings | User requests data export in settings | Invokes Edge Function `account export`; displays JSON payload dialog | `IMPLEMENTED` | `parent_settings_controller.dart`<br/>`export_result_dialog.dart` |
| **A09** | Account Deletion with Purge | Shared Settings | User types "DELETE" and password | Cascades deletion of profile, family, pairings, and auth user | `IMPLEMENTED` | `delete_account_dialog.dart`<br/>`account/index.ts` |
| **A10** | Backend Configuration Screen | Shared Core | Missing or invalid Supabase env flags | Displays error screen explaining missing URL or Publishable Key | `IMPLEMENTED` | `configuration_page.dart`<br/>`env.dart` |
| **A11** | Password Visibility Toggle | Shared UI | User taps eye icon on password input | Toggles `obscureText` between masked (`*`) and plain text | `IMPLEMENTED` | `app_text_field.dart`<br/>`login_page.dart` |
| **A12** | Form Validation Feedback | Shared UI | User types invalid format in text input | Renders inline red helper banner below field in real-time | `IMPLEMENTED` | `validators.dart`<br/>`app_text_field.dart` |
| **SET03** | App Version & Build Display | Shared Settings | User views bottom of Settings | Queries native `PackageInfo`; renders version string (`v1.0.0+1`) | `IMPLEMENTED` | `settings_body.dart`<br/>`NativeBridge.kt` |
| **SET04** | Runtime Permission Launcher | Shared Native | User taps "Grant Permission" tile | Dispatches Android native runtime permission prompt via MethodChannel | `IMPLEMENTED` | `permission_status_tile.dart`<br/>`NativeBridge.kt` |
| **SET07** | Permission Status Tile | Shared UI | User views permissions list | Displays icon, title, description, and status chip (Granted/Denied) | `IMPLEMENTED` | `permission_status_tile.dart`<br/>`NativePermissions.kt` |
| **SYS01** | Offline Detection & Caching | Shared System | Device loses internet connectivity | Surfaces global offline warning banner; serves cached state safely | `IMPLEMENTED` | `connectivity_service.dart`<br/>`info_banner.dart` |
| **SYS02** | Background Polling Timer | Shared System | Application remains active in foreground | Silently re-queries device status and alerts on fixed timer interval | `IMPLEMENTED` | `dashboard_controller.dart`<br/>`devices_controller.dart` |

---

## 3. Interconnected Workflows (10 Distributed Features)

Interconnected features require active participation across both Parent and Child handsets and the backend messaging/database tier:

### 3.1 Flow 1: Child Pairing & Linking (`FAM01`, `FAM02`, `FAM03`, `FAM05`, `FAM06`, `FAM07`)
- **Initiating Role**: Child displays QR / code (`FAM06`) OR Parent dispatches invite (`FAM03`).
- **Responding Role**: Parent scans QR (`FAM01`) / enters code (`FAM02`) OR Child approves request (`FAM05`).
- **Transport Mechanism**: Supabase Edge Function `pairing` $\to$ PostgreSQL tables `pairing_requests`, `family_members`, `child_contact_ids`.
- **End-to-End Success Outcome**:
  1. Child device registers hardware secret via `FAM07`.
  2. Child profile is added to `family_members` with `role = 'child'`.
  3. Parent dashboard automatically updates to display newly linked child device card.

### 3.2 Flow 2: Heartbeat Presence & Telemetry Oversight (`MON04`)
- **Initiating Role**: Child native background daemon (`GuardianService.kt`).
- **Responding Role**: Parent Dashboard (`dashboard_controller.dart`).
- **Transport Mechanism**: Child posts `POST /device-telemetry` (action: `heartbeat`) every 5 minutes over HTTPS $\to$ Updates `devices.last_seen_at` and `devices.battery_level`.
- **Parent Evaluation**: Parent client computes $\Delta t = \text{now}() - \text{last\_seen\_at}$. If $\Delta t < 5\text{m}$, badge is "Online" (Green); if $\Delta t \ge 5\text{m}$, badge is "Offline" (Gray).
- **Known Failure Point**: If child app is reinstalled, the new local secret fails backend verification (`HAVEN-QA-003`), causing heartbeat rejection and permanent "Offline" status.

### 3.3 Flow 3: Child Permissions Remote Diagnostic (`MON05`)
- **Initiating Role**: Child `GuardianService.kt` checks `NativePermissions.kt` during heartbeat.
- **Responding Role**: Parent Device Detail page (`/parent/devices/detail`).
- **Transport Mechanism**: Heartbeat payload includes JSON map:
  ```json
  { "camera": true, "microphone": true, "location": true, "backgroundLocation": true, "notifications": true }
  ```
- **Parent Evaluation**: Parent UI displays status chips for each hardware permission.
- **Known Failure Point**: On Android 12, `hasNotifications()` returns a false-positive `true` (`HAVEN-QA-004`).

### 3.4 Flow 4: Installed Application Inventory Synchronization (`MON07`)
- **Initiating Role**: Child `GuardianService.kt` queries `InstalledApps.kt` every 30 minutes.
- **Responding Role**: Parent App Restrictions screen (`/parent/app-restrictions`).
- **Transport Mechanism**: Child posts batch to `POST /device-telemetry` (action: `apps_upload`) $\to$ Server inserts/updates rows in `device_apps`.
- **Parent Evaluation**: Parent loads `device_apps` to display full list of installed non-system apps with package names and launchable icons.

### 3.5 Flow 5: Policy Distribution & Enforcement Loop (`APP01`–`APP04`, `APP05`, `APP06`)
- **Initiating Role**: Parent configures restrictions (blocked apps, daily limits, bedtime) and taps "Save".
- **Transport Mechanism**:
  1. Parent client writes new version to `device_policies` and inserts command into `device_commands` (`type = 'apply_policy'`).
  2. Child daemon polls `POST /device-command` every 20 seconds.
  3. Child downloads policy JSON; passes payload to `PolicyApplier.kt`.
  4. Child evaluates rules; applies package suspension via `DevicePolicyManager`.
  5. Child sends ACK to `POST /device-command` with execution result (`{ "suspended_count": 3 }`).
- **Closing the Loop**: Parent App Restrictions screen loads command ACK result; displays "Enforced: 3 apps suspended".

### 3.6 Flow 6: Safe Zone Geofence Alerts (`LOC06`)
- **Initiating Role**: Child `LocationTrackingService.kt` uploads GPS coordinates on displacement.
- **Transport Mechanism**:
  1. Child posts coordinates to `POST /device-telemetry` (action: `location_upload`).
  2. Server Edge Function calculates distance to active safe zone centers in `safe_zones`.
  3. Server detects state transition (inside $\leftrightarrow$ outside); updates `safe_zone_states`.
  4. Server inserts new alert row into `safety_alerts` (`type = 'geofence_exit'`).
- **Parent Observation**: Parent Alerts tab surfaces push alert "Child Exited Home Safe Zone".

### 3.7 Flow 7: Low Battery Telemetry Alerts (`LOC07`)
- **Initiating Role**: Child `GuardianService.kt` inspects `BatteryManager` during heartbeat.
- **Transport Mechanism**: If battery drops $< 15\%$, heartbeat payload sets `battery_level = 12`. Server evaluates condition; automatically inserts row into `safety_alerts` (`type = 'low_battery'`).
- **Parent Observation**: Parent Alerts tab surfaces amber warning banner "Child Device Low Battery (12%)".

### 3.8 Flow 8: Permission Revocation / Tampering Alerts (`LOC09`)
- **Initiating Role**: Child user disables Location or Usage Access in Android OS settings.
- **Transport Mechanism**: Child daemon detects permission loss in next heartbeat snapshot. Server detects delta from previous state; inserts row into `safety_alerts` (`type = 'permission_degraded'`).
- **Parent Observation**: Parent Alerts tab surfaces critical alert "Child Revoked Location Permission".

### 3.9 Flow 9: WebRTC Remote Assistance Live Calling (`REM01`, `REM02`, `REM03`, `REM05`, `REM06`)
- **Initiating Role**: Parent initiates call from `/parent/assistance` (`REM01`).
- **Transport Mechanism**:
  1. Parent creates session in `remote_sessions` (`status = 'requested'`).
  2. Child polling or realtime listener detects incoming call; displays ringing bottom sheet (`REM02`).
  3. Child taps "Accept" $\to$ Session marked `'accepted'`.
  4. Both devices connect to `remote-session` Edge Function for WebRTC signaling (exchanging SDP Offer, SDP Answer, and ICE candidates).
  5. P2P WebRTC media stream establishes live two-way audio and child camera video (`REM03`).
- **Termination**: Either party taps "End Call" (`REM05`); peer connection closes; camera released.

### 3.10 Flow 10: Usage Statistics Aggregation & Reporting (`USE04`, `USE01`, `USE02`)
- **Initiating Role**: Child `UsageReporter.kt` queries Android `UsageStatsManager` hourly.
- **Transport Mechanism**: Child aggregates foreground app time; uploads batch to `device-telemetry` (action: `usage_upload`) $\to$ Server writes to `usage_daily`.
- **Parent Observation**: Parent opens Screen Time page (`USE01`); displays daily usage graph and per-app duration breakdown (`USE02`).

---

## 4. Failure Modes and Resilience Matrix

| Interconnected Flow | Failure Scenario | System Handling & Resilience Behavior | Observable Outcome |
|---|---|---|---|
| **Pairing Handshake** | Parent submits invalid/expired code | Supabase RPC returns error `invalid_pairing_code` | Parent UI surfaces red error banner: "Code expired or invalid" |
| **Heartbeat Presence** | Child cellular radio drops | Daemon retries on next 10s tick; buffers locally | Parent dashboard transitions badge to "Offline" after 5m |
| **Policy Distribution** | Child powered off during policy update | Command remains queued in `device_commands` (`status = 'pending'`) | Applied immediately upon next device power-on and poll |
| **WebRTC Assistance** | Symmetric NAT blocks direct P2P media | Signaling exchanges Google STUN candidates; falls back to audio | Video track drops; audio stream maintained |
| **Usage Upload** | Device secret invalid (`HAVEN-QA-003`) | Server rejects upload with HTTP 401 | Child usage data stalls; parent screen time shows 0m |

---

## 5. Verification Requirements for Pre-Testing Phase

- **Account Isolation**: Interconnected testing requires exactly one authenticated Parent account and one authenticated Child account linked to the same family.
- **Hardware Pair**: Manual verification requires two simultaneous execution contexts (or two separate devices/emulators) to observe trigger and response synchronously.
- **All items remain marked `NOT TESTED`**.
