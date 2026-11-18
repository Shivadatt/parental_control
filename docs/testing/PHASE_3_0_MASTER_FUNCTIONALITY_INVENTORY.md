# PHASE 3.0 — MASTER APPLICATION FUNCTIONALITY INVENTORY

**Project:** `D:\parentcontrol_app`  
**Package:** `com.parentcontrol.parent_control`  
**Target Backend:** Supabase Project `hhqgreaoqulmfwfwarhc`  
**Execution Mode:** STRICT READ-ONLY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. INVENTORY METHODOLOGY & CLASSIFICATION RULES

This inventory covers every functional capability discovered across the Flutter UI, Dart repositories/controllers, Android Kotlin layer, Supabase PostgreSQL database schema, RLS policies, and Edge Functions.

### Status Definitions (Strict Classification)
- **VERIFIED:** Code exists and runtime execution has been verified with live device/test evidence.
- **IMPLEMENTED:** Complete source code and execution path exist, but pending live hardware verification.
- **PARTIAL:** Implementation exists but execution path is incomplete or lacks essential UI/backend links.
- **UI ONLY:** User interface widget/screen exists, but underlying service or backend calls are stubbed.
- **BACKEND ONLY:** Database table, RPC, or Edge Function exists, but no client UI integration exists.
- **NOT IMPLEMENTED:** Capability is expected/referenced in architecture or requirements but has zero code.
- **BLOCKED:** Verification is blocked by OS restrictions (e.g. non-Device Owner mode on physical device).
- **ADVISORY:** Client reports status accurately but OS-level hard enforcement cannot be guaranteed.

---

## 2. COMPREHENSIVE FUNCTIONALITY INVENTORY TABLE

| Feature ID | Module | Feature Name | Role | Location / Screen | Source Files (Dart / Kotlin / SQL / TS) | Implementation Status | Test Coverage |
|---|---|---|---|---|---|---|---|
| **F-001** | Mod A: Foundation | Cold App Startup & DI | Both | Native Launch -> Splash | `main.dart`, `app.dart`, `repository_binding.dart`, `MainActivity.kt` | **VERIFIED** | Unit + Live Device |
| **F-002** | Mod A: Foundation | Deep Link / Auth Callback Routing | Both | Intent Filter -> AppPages | `MainActivity.kt`, `app_pages.dart`, `Env.dart` | **VERIFIED** | Unit + Android Intent |
| **F-003** | Mod A: Foundation | Role Selection Screen | Both | `/role-selection` | `role_selection_page.dart`, `role_selection_controller.dart`, `local_settings_service.dart` | **VERIFIED** | Widget + Live Device |
| **F-004** | Mod A: Foundation | Theme Mode (Light / Dark / System) | Both | App-wide & Settings | `app_theme.dart`, `parent_settings_controller.dart`, `local_settings_service.dart` | **VERIFIED** | Unit + Live Device |
| **F-005** | Mod A: Foundation | Connectivity Monitoring | Both | App-wide service | `connectivity_service.dart`, `connectivity_plus` | **IMPLEMENTED** | Unit |
| **F-006** | Mod A: Foundation | Global Error Mapping & UI Banners | Both | App-wide | `app_exception.dart`, `info_banner.dart`, `async_state_view.dart` | **VERIFIED** | Unit + Live Device |
| **F-007** | Mod A: Foundation | Native Platform Bridge Binding | Child | App Engine | `NativeBridge.kt`, `device_admin_service.dart` | **VERIFIED** | Unit + Live Device |
| **F-008** | Mod B: Authentication | Parent Account Registration | Parent | `/auth/register` (Parent) | `register_page.dart`, `register_controller.dart`, `supabase_auth_repository.dart` | **VERIFIED** | Unit + Live Device |
| **F-009** | Mod B: Authentication | Child Account Registration | Child | `/auth/register` (Child) | `register_page.dart`, `register_controller.dart`, `supabase_auth_repository.dart` | **VERIFIED** | Unit + Live Device |
| **F-010** | Mod B: Authentication | Email Verification Gating | Both | `/auth/verify-email` | `verify_email_page.dart`, `verify_email_controller.dart`, `auth_session_flow.dart` | **VERIFIED** | Unit + Live Device |
| **F-011** | Mod B: Authentication | Resend Verification Email | Both | `/auth/verify-email` | `verify_email_controller.dart`, `supabase_auth_repository.dart` | **VERIFIED** | Unit + Live Device |
| **F-012** | Mod B: Authentication | Email & Password Sign-In | Both | `/auth/login` | `login_page.dart`, `login_controller.dart`, `supabase_auth_repository.dart` | **VERIFIED** | Unit + Live Device |
| **F-013** | Mod B: Authentication | Server-Side Profile Role Resolution | Both | Splash -> Shell Route | `splash_controller.dart`, `supabase_auth_repository.dart`, `profiles` table | **VERIFIED** | Unit + Live Device |
| **F-014** | Mod B: Authentication | Initial Role Assignment RPC | Both | Auth Bootstrap | `edge_api.dart`, `auth-bootstrap/index.ts` (`set_role`) | **VERIFIED** | Unit + Backend Deno |
| **F-015** | Mod B: Authentication | Password Validation Rules | Both | Register / Login Form | `validators.dart` (min 8 chars, mixed case, numbers) | **VERIFIED** | Unit (7 tests) |
| **F-016** | Mod B: Authentication | Sign Out (Session Cleanup) | Both | Settings -> Splash | `parent_settings_controller.dart`, `child_shell_controller.dart`, `supabase_service.dart` | **VERIFIED** | Unit + Live Device |
| **F-017** | Mod B: Authentication | Session Auto-Restore & Refresh | Both | App Startup | `supabase_service.dart`, `session_service.dart` | **VERIFIED** | Unit + Live Device |
| **F-018** | Mod B: Authentication | Forgot Password / Password Reset | Both | Missing in UI | `LoginPage.dart` (no link), `supabase_auth_repository.dart` | **NOT IMPLEMENTED** | None |
| **F-019** | Mod C: Family | Family Creation Onboarding | Parent | `/parent/family-setup` | `family_setup_page.dart`, `family_setup_controller.dart`, `auth-bootstrap/index.ts` | **VERIFIED** | Unit + Backend Deno |
| **F-020** | Mod C: Family | Active Family Fetch & Switch | Parent | Parent Shell | `parent_shell_controller.dart`, `supabase_family_repository.dart`, `family_members` | **VERIFIED** | Unit + Live Device |
| **F-021** | Mod C: Family | Family Member Directory | Parent | `/parent/family` | `family_page.dart`, `family_controller.dart`, `family_members` table | **VERIFIED** | Unit + Live Device |
| **F-022** | Mod C: Family | Child ID Generation (Canonical) | Child | `/child/enrollment` | `child_enrollment_controller.dart`, `pairing/index.ts` (`get_contact_id`) | **VERIFIED** | Unit + Live Device |
| **F-023** | Mod C: Family | Child ID Pairing Invitation | Parent | `/parent/pairing/redeem` | `pairing_redeem_controller.dart`, `pairing/index.ts` (`invite`) | **VERIFIED** | Unit + Backend Deno |
| **F-024** | Mod C: Family | Pairing Code Generation (8-char) | Child | `/child/enrollment` | `child_enrollment_controller.dart`, `pairing/index.ts` (`create`) | **VERIFIED** | Unit + Backend Deno |
| **F-025** | Mod C: Family | Pairing Code Redemption | Parent | `/parent/pairing/redeem` | `pairing_redeem_controller.dart`, `pairing/index.ts` (`redeem`) | **VERIFIED** | Unit + Backend Deno |
| **F-026** | Mod C: Family | Child Pairing Request Approval | Child | `/child/requests` | `child_requests_controller.dart`, `pairing/index.ts` (`respond`) | **VERIFIED** | Unit + Live Device |
| **F-027** | Mod C: Family | Child Pairing Request Rejection | Child | `/child/requests` | `child_requests_controller.dart`, `pairing/index.ts` (`respond`) | **IMPLEMENTED** | Unit + Backend Deno |
| **F-028** | Mod C: Family | Parent Outgoing Request Cancel | Parent | `/parent/pairing/requests` | `pairing_requests_controller.dart`, `pairing/index.ts` (`cancel`) | **IMPLEMENTED** | Unit + Backend Deno |
| **F-029** | Mod C: Family | Unlink Child Member from Family | Parent | `/parent/family` | `family_controller.dart`, `pairing/index.ts` (`unlink`) | **IMPLEMENTED** | Unit + Backend Deno |
| **F-030** | Mod C: Family | Retention Policy Configuration | Parent | Family Settings | `supabase_family_repository.dart`, `family-admin/index.ts` (`update_retention`) | **IMPLEMENTED** | Backend Deno |
| **F-031** | Mod D: Device Management | Android Keystore Hardware Root | Child | Native Kotlin | `SecureStore.kt` (`AndroidKeyStore`, AES-256 GCM) | **VERIFIED** | Unit + Live Hardware |
| **F-032** | Mod D: Device Management | Installation ID & Secret Generation | Child | Native Kotlin | `SecureStore.kt` (UUIDv4 + 32-byte CSPRNG secret) | **VERIFIED** | Unit + Live Hardware |
| **F-033** | Mod D: Device Management | Device Registration in Family | Child | `/child/enrollment` | `child_enrollment_controller.dart`, `device-register/index.ts` | **VERIFIED** | Unit + Backend Deno |
| **F-034** | Mod D: Device Management | SHA-256 Secret Hash Device Auth | Child | Device Telemetry / Poll | `NativeBridge.kt`, `DeviceHttpClient.kt`, `_shared/auth.ts` | **VERIFIED** | Backend Deno (17 tests) |
| **F-035** | Mod D: Device Management | Device Heartbeat & Battery Status | Child | Native Service -> Edge | `GuardianService.kt`, `device-telemetry/index.ts` (`heartbeat`) | **VERIFIED** | Live Device Logs |
| **F-036** | Mod D: Device Management | Device Capabilities Reporting | Child | MethodChannel | `NativeBridge.kt` (`getCapabilities`), `device_admin_service.dart` | **VERIFIED** | Live Device (Realme) |
| **F-037** | Mod D: Device Management | Enrolled Device Detail Card | Parent | `/parent/devices/detail` | `device_detail_page.dart`, `device_detail_controller.dart` | **VERIFIED** | Live Device (Pixel 9a) |
| **F-038** | Mod D: Device Management | Device Revocation | Parent | `/parent/devices/detail` | `device_detail_controller.dart`, `family-admin/index.ts` (`revoke_device`) | **IMPLEMENTED** | Backend Deno |
| **F-039** | Mod D: Device Management | Device Recovery Request | Parent | Backend RPC | `family-admin/index.ts` (`recover_device`), `request_device_recovery` RPC | **BACKEND ONLY** | Backend Deno |
| **F-040** | Mod E: Parent Dashboard | Family Summary Card | Parent | `/parent` (Tab 0) | `dashboard_controller.dart`, `dashboard_page.dart` | **VERIFIED** | Live Device |
| **F-041** | Mod E: Parent Dashboard | Child Online / Offline Badge | Parent | `/parent` (Tab 0) | `dashboard_controller.dart`, `detect_offline_devices` RPC | **VERIFIED** | Live Device |
| **F-042** | Mod E: Parent Dashboard | Battery Level & Charging Indicator | Parent | `/parent` (Tab 0) | `dashboard_controller.dart`, `devices` table | **VERIFIED** | Live Device |
| **F-043** | Mod E: Parent Dashboard | Screen Time Daily Total Metric | Parent | `/parent` (Tab 0) | `dashboard_controller.dart`, `usage_daily` table | **VERIFIED** | Live Device |
| **F-044** | Mod E: Parent Dashboard | Quick Safety Alerts Banner | Parent | `/parent` (Tab 0) | `dashboard_controller.dart`, `safety_alerts` table | **VERIFIED** | Live Device |
| **F-045** | Mod F: Child Dashboard | Child Home Status Card | Child | `/child` (Tab 0) | `child_shell_page.dart`, `child_shell_controller.dart`, `child_home_tab.dart` | **VERIFIED** | Live Device |
| **F-046** | Mod F: Child Dashboard | Active Policy Version Indicator | Child | `/child` (Tab 0) | `child_home_tab.dart`, `devices.policy_version` | **VERIFIED** | Live Device |
| **F-047** | Mod F: Child Dashboard | Guardian Background Service Card | Child | `/child` (Tab 0) | `child_home_tab.dart`, `GuardianService.isRunning` | **VERIFIED** | Live Device |
| **F-048** | Mod F: Child Dashboard | Permission Audit Tiles | Child | `/child` (Tab 0) | `child_home_tab.dart`, `NativePermissions.kt` | **VERIFIED** | Live Device |
| **F-049** | Mod F: Child Dashboard | Child Rules & App Restrictions Tab | Child | `/child` (Tab 1) | `child_restrictions_tab.dart`, `device_policies` table | **VERIFIED** | Live Device |
| **F-050** | Mod F: Child Dashboard | Pending Requests Badge & List | Child | `/child/requests` | `child_requests_page.dart`, `child_requests_controller.dart` | **VERIFIED** | Live Device |
| **F-051** | Mod G: Screen Time | Screen Time Schedule Editor | Parent | `/parent/screen-time` | `screen_time_page.dart`, `screen_time_controller.dart` | **VERIFIED** | Live Device |
| **F-052** | Mod G: Screen Time | Daily Quota Limit (Minutes) | Parent | `/parent/screen-time` | `screen_time_controller.dart`, `device-policy/index.ts` | **VERIFIED** | Live Device |
| **F-053** | Mod G: Screen Time | Bedtime Curfew Range Picker | Parent | `/parent/screen-time` | `screen_time_controller.dart`, `device_policies.policy` | **VERIFIED** | Live Device |
| **F-054** | Mod G: Screen Time | Usage Stats Synchronization | Child | Native Kotlin -> Edge | `UsageReporter.kt`, `device-telemetry/index.ts` (`usage_upload`) | **IMPLEMENTED** | Backend Deno |
| **F-055** | Mod G: Screen Time | Quota Evaluator (Local Engine) | Child | Native Kotlin | `QuotaEvaluator.kt`, `PolicyEvaluator.kt` | **VERIFIED** | Kotlin Unit Tests |
| **F-056** | Mod G: Screen Time | Policy Ack & Enforcement Status | Child | Native -> Edge Command | `PolicyApplier.kt`, `device-command/enforcement.ts` | **VERIFIED** | Kotlin + Deno Tests |
| **F-057** | Mod G: Screen Time | Advisory Mode Fallback (Non-Owner) | Child | Device Status Banner | `PolicyApplier.kt`, `app_restrictions_controller.dart` | **VERIFIED** | Flutter + Kotlin Tests |
| **F-058** | Mod H: App Restrictions | Query Installed Android Apps | Child | Native MethodChannel | `InstalledApps.kt` (`QUERY_ALL_PACKAGES`), `device_admin_service.dart` | **VERIFIED** | Live Hardware |
| **F-059** | Mod H: App Restrictions | Upload Discovered Apps to Backend | Child | Telemetry Edge Call | `supabase_device_repository.dart`, `device-telemetry/index.ts` (`apps_upload`) | **VERIFIED** | Backend Deno |
| **F-060** | Mod H: App Restrictions | Parent App Restriction Manager UI | Parent | `/parent/app-restrictions` | `app_restrictions_page.dart`, `app_restrictions_controller.dart` | **VERIFIED** | Live Device |
| **F-061** | Mod H: App Restrictions | Per-App Block / Allow Toggle | Parent | `/parent/app-restrictions` | `app_restrictions_controller.dart`, `device_policies` | **VERIFIED** | Live Device |
| **F-062** | Mod H: App Restrictions | Command Generation (`apply_policy`) | Parent | Edge Function | `device-policy/index.ts`, `device_commands` table | **VERIFIED** | Backend Deno |
| **F-063** | Mod H: App Restrictions | Hard Package Suspension (`setPackagesSuspended`)| Child | Native DPM | `PolicyApplier.kt` (`DevicePolicyManager`) | **BLOCKED** | Non-DO Device (Advisory) |
| **F-064** | Mod I: Remote Assistance | Parent Assistance Request Creation | Parent | `/parent/assistance` | `remote_assistance_controller.dart`, `remote-session/index.ts` (`request`) | **VERIFIED** | Backend Deno (19 tests) |
| **F-065** | Mod I: Remote Assistance | Child Explicit Consent Sheet | Child | Native Modal Overlay | `media_self_test_sheet.dart`, `child_requests_controller.dart` | **VERIFIED** | Live Device |
| **F-066** | Mod I: Remote Assistance | WebRTC One-Way Audio Publishing | Child | flutter_webrtc + Service | `AudioAssistanceService.kt`, `remote_session_controller.dart` | **IMPLEMENTED** | Native Service Unit |
| **F-067** | Mod I: Remote Assistance | WebRTC Receive-Only Audio Playout | Parent | `/parent/assistance/session`| `remote_session_controller.dart`, `remote_session_page.dart` | **IMPLEMENTED** | Flutter Unit Tests |
| **F-068** | Mod I: Remote Assistance | STUN / TURN Credentials API | Both | Edge Function | `remote-session/index.ts` (`ice`), `_shared/turn.ts` | **VERIFIED** | Backend Deno (8 tests) |
| **F-069** | Mod I: Remote Assistance | WebRTC Signaling Exchange | Both | Postgres Realtime | `webrtc_signals` table, `supabase_remote_session_repository.dart` | **IMPLEMENTED** | Backend Schema |
| **F-070** | Mod I: Remote Assistance | Audio Foreground Service Lock | Child | Native Service | `AudioAssistanceService.kt` (`FOREGROUND_SERVICE_MICROPHONE`, `WAKE_LOCK`)| **VERIFIED** | Android Manifest + Unit |
| **F-071** | Mod I: Remote Assistance | Session Lifecycle State Machine | Both | RPC + Guard | `remote_sessions` table, `remote_session_transition_guard` Trigger | **VERIFIED** | Backend Deno (11 tests) |
| **F-072** | Mod I: Remote Assistance | Abandoned Session Auto-Sweeper | Backend | Scheduled Job | `cron/index.ts`, `expire_abandoned_sessions` RPC | **VERIFIED** | Backend Deno |
| **F-073** | Mod J: Location & Geofence | Foreground GPS Location Fix | Child | Native Location Service | `LocationTrackingService.kt`, `NativePermissions.kt` | **VERIFIED** | Live Hardware |
| **F-074** | Mod J: Location & Geofence | Background Location Tracking | Child | Android Service | `LocationTrackingService.kt` (`FOREGROUND_SERVICE_LOCATION`) | **IMPLEMENTED** | Android Manifest |
| **F-075** | Mod J: Location & Geofence | Location Upload with Device HMAC | Child | Edge Telemetry Call | `supabase_location_repository.dart`, `device-telemetry/index.ts` (`location_upload`) | **VERIFIED** | Backend Deno |
| **F-076** | Mod J: Location & Geofence | Parent Map Location Viewer | Parent | `/parent/location` | `location_page.dart`, `location_controller.dart` | **VERIFIED** | Live Device |
| **F-077** | Mod J: Location & Geofence | Safe Zone Geofence Creator | Parent | `/parent/safe-zones` | `safe_zones_page.dart`, `safe_zones_controller.dart`, `safe_zones` table | **VERIFIED** | Live Device |
| **F-078** | Mod J: Location & Geofence | Safe Zone Atomic Delete RPC | Parent | RPC Migration | `delete_safe_zone_audited` RPC, `family-admin/index.ts` (`delete_zone`) | **VERIFIED** | Backend Deno (8 tests) |
| **F-079** | Mod J: Location & Geofence | Geofence Boundary Transition Engine| Backend | SQL Trigger / Telemetry | `safe_zone_states` table, `location_events` trigger | **IMPLEMENTED** | Backend Migration |
| **F-080** | Mod K: Safety Alerts | Alerts Dashboard List (Tab 2) | Parent | `/parent/alerts` | `safety_alerts_page.dart`, `safety_alerts_controller.dart` | **VERIFIED** | Live Device |
| **F-081** | Mod K: Safety Alerts | Low Battery Alert Dispatch | Backend | Telemetry Trigger | `safety_alerts` (`type = 'battery_low'`), `device-telemetry` | **VERIFIED** | Live Device Logs |
| **F-082** | Mod K: Safety Alerts | Safe Zone Exit Alert Dispatch | Backend | Geofence Trigger | `safety_alerts` (`type = 'zone_exit'`) | **IMPLEMENTED** | Backend Schema |
| **F-083** | Mod K: Safety Alerts | Alert Parent Acknowledgement | Parent | `/parent/alerts` | `safety_alerts_controller.dart`, `family-admin/index.ts` (`ack_alert`) | **VERIFIED** | Live Device |
| **F-084** | Mod K: Safety Alerts | Realtime WebSocket Auto-Reconnect | Parent | App Lifecycle Observer | `safety_alerts_controller.dart` (WidgetsBindingObserver backoff) | **VERIFIED** | Flutter Unit Tests (5/5) |
| **F-085** | Mod K: Safety Alerts | Firebase Push Notifications (FCM) | Both | Push Service | Not integrated (Local foreground notifications only) | **NOT IMPLEMENTED** | None |
| **F-086** | Mod L: Settings & Privacy | Parent Settings Screen | Parent | `/parent/settings` | `parent_settings_page.dart`, `parent_settings_controller.dart` | **VERIFIED** | Live Device |
| **F-087** | Mod L: Settings & Privacy | Account Retention Report Card | Parent | `/parent/settings` | `parent_settings_controller.dart`, `account/index.ts` (`retention_report`) | **IMPLEMENTED** | Backend Deno (23 tests) |
| **F-088** | Mod L: Settings & Privacy | Full Account Data Export (GDPR) | Both | `/parent/settings` | `account_privacy_repository.dart`, `account/index.ts` (`export`) | **IMPLEMENTED** | Backend Deno |
| **F-089** | Mod L: Settings & Privacy | Cascading Account Deletion | Both | `/parent/settings` | `account_privacy_repository.dart`, `account/index.ts` (`delete_account`) | **IMPLEMENTED** | Backend Deno (7 tests) |
| **F-090** | Mod L: Settings & Privacy | Child Settings & Permissions Sheet | Child | `/child` (Tab 2) | `child_settings_tab.dart`, `child_shell_controller.dart` | **VERIFIED** | Live Device |
| **F-091** | Mod M: Audit & Compliance | Immutable Audit Log Viewer | Parent | `/parent/audit` | `audit_logs_page.dart`, `audit_logs_controller.dart`, `audit_logs` table | **VERIFIED** | Live Device |
| **F-092** | Mod M: Audit & Compliance | Append-Only DB Trigger Protection | Backend | PostgreSQL Trigger | `private.audit_logs_append_only()` (Blocks UPDATE/DELETE on audit_logs) | **VERIFIED** | Backend Schema |
| **F-093** | Mod M: Audit & Compliance | Old Data Purge Operation | Parent | Audit Actions | `audit_logs_controller.dart`, `family-admin/index.ts` (`purge_data`) | **IMPLEMENTED** | Backend Deno (4 tests) |
| **F-094** | Mod N: Native Android | Guardian Foreground Service | Child | Android System | `GuardianService.kt`, `ic_stat_guardian.xml` | **VERIFIED** | Live Hardware |
| **F-095** | Mod N: Native Android | Boot Auto-Start Receiver | Child | Android System | `BootReceiver.kt` (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`) | **IMPLEMENTED** | Android Manifest |
| **F-096** | Mod N: Native Android | Device Admin Policy Receiver | Child | Android System | `ParentControlDeviceAdminReceiver.kt`, `device_admin.xml` | **VERIFIED** | Live Hardware |
| **F-097** | Mod N: Native Android | UsageStats Query Integration | Child | Native Kotlin | `UsageReporter.kt` (`UsageStatsManager`) | **VERIFIED** | Kotlin Unit Tests |
| **F-098** | Mod N: Native Android | Native Event Bus (Dart Stream) | Child | EventChannel | `NativeEventBus.kt`, `NativeBridge.kt`, `DeviceAdminService.dart` | **VERIFIED** | Live Hardware |
| **F-099** | Mod O: Supabase Backend | 19 Relational PostgreSQL Tables | Backend | Database Schema | `supabase/migrations/*.sql` (Core, Functions, RLS, Recovery, etc.) | **VERIFIED** | Backend Schema |
| **F-100** | Mod O: Supabase Backend | Row Level Security (RLS) Policies | Backend | PostgreSQL Policies | `20260101000200_rls.sql`, `20261030000200_phase1_authorization.sql` | **VERIFIED** | Backend Deno (184 tests) |
| **F-101** | Mod O: Supabase Backend | 10 Supabase Edge Functions | Backend | Deno Runtime | `supabase/functions/` (account, auth-bootstrap, cron, device-command, etc.) | **IMPLEMENTED** | Backend Deno (184 tests) |
| **F-102** | Mod P: Network & Sync | Edge API Response Envelope Validator | Both | HTTP Client | `edge_api.dart` (`{ok, data}` / `{ok, error}` standard) | **VERIFIED** | Flutter + Deno Tests |
| **F-103** | Mod P: Network & Sync | Command Polling & Ack Loop | Child | Background Loop | `DeviceHttpClient.kt`, `device-command/index.ts` (`poll`, `ack`) | **VERIFIED** | Backend Deno (24 tests) |
| **F-104** | Mod Q: Security & Privacy | Service Role Credential Isolation | Backend | Edge Functions | Service role key strictly confined to backend Deno; zero exposure to client | **VERIFIED** | Code Audit |
| **F-105** | Mod Q: Security & Privacy | Device Secret Keystore Protection | Child | Native Keystore | Private device secrets never leave Android EncryptedSharedPreferences | **VERIFIED** | Code Audit + Live Keystore |
| **F-106** | Mod Q: Security & Privacy | Microphone Explicit Consent Gate | Child | Remote Assistance | `remote_session_transition_guard`, `media_self_test_sheet.dart` | **VERIFIED** | Flutter + Backend Deno |
| **F-107** | Mod Q: Security & Privacy | Camera Surveillance Prevention | Both | System Policy | Zero background camera capture code; `android.hardware.camera` optional | **VERIFIED** | Source Code Audit |
| **F-108** | Mod Q: Security & Privacy | Account Deletion Cascading Safety | Backend | Edge Function | `account/index.ts` (`delete_account`), owner blocker `findDeletionBlocker` | **VERIFIED** | Deno Tests (30/30) |
