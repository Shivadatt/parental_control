# 01 — Complete Functionality Inventory

Audit date: 2026-11-23  
Checkout: `80375f518139bf922bc1b66c998691bee912af44`  
Mode: read-only source and backend inspection

## Status legend

- **IMPLEMENTED** — real logic, connected to UI and backend where applicable.
- **PARTIAL** — meaningful implementation exists, but the complete user outcome is not available.
- **UI ONLY** — a control exists but does not drive real behaviour.
- **BACKEND ONLY** — server capability exists without an application entry point.
- **PLANNED** — explicitly planned but not implemented (none found in source).
- **UNVERIFIED** — evidence insufficient (none in this inventory).

## Inventory

| ID | Category | Functionality | Role | Entry screen | Status | Backend dependency | Source evidence | Test evidence |
|---|---|---|---|---|---|---|---|---|
| A01 | Authentication | Email/password sign-in | Shared | `/auth/login` | IMPLEMENTED | Supabase Auth `signInWithPassword` | `login_controller.dart`; `supabase_auth_repository.dart` | `login_controller_test.dart` |
| A02 | Authentication | Account registration | Shared | `/auth/register` | IMPLEMENTED | Supabase Auth `signUp`; `auth-bootstrap` | `register_controller.dart`; `supabase_auth_repository.dart` | auth controller tests |
| A03 | Authentication | Email verification, resend, refresh | Shared | `/auth/verify-email` | IMPLEMENTED | Supabase Auth email confirmation | `verify_email_controller.dart` | `auth_session_flow_test.dart` |
| A04 | Authentication | Persisted session restore | Shared | `/` splash | IMPLEMENTED | Supabase session persistence | `splash_controller.dart`; `session_service.dart` | `auth_session_flow_test.dart` |
| A05 | Authentication | Sign out | Shared | Parent/Child settings | IMPLEMENTED | Supabase Auth sign-out | `parent_settings_controller.dart:326`; `child_shell_controller.dart:1071` | settings/child shell tests |
| A06 | Authentication | Role selection and initial role assignment | Shared | `/role-selection` | IMPLEMENTED | `auth-bootstrap set_role` | `role_selection_controller.dart`; `auth-bootstrap/index.ts` | `role_selection_controller_test.dart` |
| A07 | Account | Account/profile display | Shared | Settings | IMPLEMENTED | `profiles` via Supabase | `settings_body.dart`; `session_service.dart` | settings tests |
| A08 | Account | Account data export | Shared | Settings → Privacy & data | IMPLEMENTED | `account export` | `parent_settings_controller.dart:196`; `account/index.ts` | `account_privacy_controller_test.dart` |
| A09 | Account | Account deletion with confirmation | Shared | Settings → Privacy & data | IMPLEMENTED | `account delete`; `private.*` | `parent_settings_controller.dart:247`; `delete_account_dialog.dart`; `account/index.ts` | `account_privacy_controller_test.dart` |
| A10 | Account | Backend configuration/error screen | Shared | `/configuration` | IMPLEMENTED | Compile-time Supabase config | `configuration_page.dart`; `env.dart` | `widget_test.dart`; `env_test.dart` |
| FAM01 | Pairing | Link child by QR scan | Parent | Link a child | IMPLEMENTED | `pairing invite` | `pairing_redeem_page.dart:142`; `pairing_redeem_controller.dart` | `pairing_redeem_controller_test.dart` |
| FAM02 | Pairing | Link child by Child ID/linking code | Parent | Link a child | IMPLEMENTED | `pairing invite/redeem` | `pairing_redeem_page.dart:175`; `supabase_pairing_repository.dart` | `pairing_redeem_controller_test.dart` |
| FAM03 | Pairing | Send pairing request | Parent | Link a child | IMPLEMENTED | `pairing create/invite` | `pairing_redeem_controller.dart:69`; `pairing/index.ts` | `pairing_redeem_controller_test.dart` |
| FAM04 | Pairing | Pairing request list and cancel | Parent | `/parent/pairing/requests` | IMPLEMENTED | `pairing list_family/cancel` | `pairing_requests_controller.dart` | pairing tests |
| FAM05 | Pairing | Child approves/declines pairing | Child | Requests | IMPLEMENTED | `pairing respond` | `child_requests_controller.dart:112` | `child_requests_controller_test.dart` |
| FAM06 | Pairing | Child ID/contact ID and QR display | Child | Enrollment | IMPLEMENTED | `pairing get_contact_id`; `child_contact_ids` | `child_enrollment_controller.dart:140`; `child_enrollment_page.dart` | `child_enrollment_controller_test.dart` |
| FAM07 | Device registration | Child enrollment/device registration | Child | Enrollment | IMPLEMENTED | `device-register register` | `child_enrollment_controller.dart:264`; `device-register/index.ts` | `child_enrollment_controller_test.dart` |
| FAM08 | Family | Create family | Parent | Family setup | IMPLEMENTED | `auth-bootstrap create_family` | `family_setup_controller.dart:34`; `auth-bootstrap/index.ts` | auth/family tests |
| FAM09 | Family | Family details, members, roles | Parent | Family details | IMPLEMENTED | `families`, `family_members` RLS | `family_controller.dart`; `family_page.dart` | `family_controller_test.dart` |
| FAM10 | Family | Unlink child account/device | Parent | Family details | IMPLEMENTED | `unlink_child` RPC / Edge | `family_controller.dart:207`; `pairing/index.ts:945` | family/pairing tests |
| FAM11 | Family | Child self-unlink | Child | Child settings | IMPLEMENTED | `pairing unlink` | `child_shell_controller.dart:1012` | `child_shell_controller_test.dart` |
| FAM12 | Device control | Revoke device | Parent | Device detail | IMPLEMENTED | `revoke_device` RPC / `family-admin` | `device_detail_controller.dart:123`; `family-admin/index.ts:57` | `device_detail_controller_test.dart` |
| FAM13 | Device control | Device recovery for lost/reinstalled phone | Parent | Device detail | IMPLEMENTED | `request_device_recovery` | `device_detail_controller.dart:150`; `device_recovery.sql` | device detail tests |
| FAM14 | Family settings | Update family settings API | Parent | None | BACKEND ONLY | `FamilyRepository.updateSettings` | `repository_contracts.dart:32`; `supabase_family_repository.dart:150` | none found |
| MON01 | Parent dashboard | Family/dashboard overview | Parent | Dashboard | IMPLEMENTED | `families`, `devices`, `device_policies` | `dashboard_controller.dart`; `parent_dashboard_tab.dart` | `dashboard_controller_test.dart` |
| MON02 | Devices | Device list with policy/status cards | Parent | Devices | IMPLEMENTED | `devices` query | `devices_controller.dart`; `parent_devices_tab.dart` | `devices_controller_test.dart` |
| MON03 | Devices | Device detail: identity, battery, enforcement, last seen | Parent | Device detail | IMPLEMENTED | `devices`, `device_commands` | `device_detail_controller.dart`; `device_detail_page.dart` | `device_detail_controller_test.dart` |
| MON04 | Devices | Heartbeat-derived online/offline and last-seen status | Parent–Child | Dashboard/Device detail | PARTIAL | `device-telemetry heartbeat`; `last_seen_at` | `device.dart:394-458`; `device-telemetry/index.ts:68`; `child_shell_controller.dart` sync | presence tests; live E2E failed (E2E-001) |
| MON05 | Devices | Child permission summary | Parent–Child | Device detail | PARTIAL | `devices` permission columns reported by telemetry | `device_detail_page.dart`; `device-telemetry/index.ts:96-146` | UI tests; live notification mismatch |
| MON06 | Devices | Recent command history | Parent | Device detail | IMPLEMENTED | `device_commands` | `device_detail_controller.dart:100`; `fetchRecentCommands` | `device_detail_controller_test.dart` |
| MON07 | Devices | Installed-app snapshot | Parent–Child | App restrictions | IMPLEMENTED | `device_apps`; telemetry `apps_upload` | `app_restrictions_controller.dart:load`; `device-telemetry/index.ts:357` | app restrictions tests |
| USE01 | Usage | Daily usage history | Parent | Screen time | IMPLEMENTED | `usage_daily` | `screen_time_controller.dart`; `supabase_usage_repository.dart` | `screen_time_controller_test.dart` |
| USE02 | Usage | App usage breakdown | Parent | Screen time | IMPLEMENTED | `usage_daily` app rows | `screen_time_controller.dart` `appBreakdown` | `screen_time_controller_test.dart` |
| USE03 | Usage | Usage Access status and guidance | Parent | Screen time | IMPLEMENTED | Child-reported permission | `screen_time_controller.dart`; `child_shell_controller.dart` capabilities | `screen_time_controller_test.dart` |
| USE04 | Usage | Child usage collection/upload | Child | Background service | PARTIAL | `device-telemetry usage_upload`; `usage_daily` | `UsageReporter.kt`; `child_shell_controller.dart` upload | Kotlin usage tests; live upload failed (credential) |
| USE05 | Screen time | Daily screen-time limit configuration/save | Parent | Screen time | IMPLEMENTED | `device-policy update`; `device_policies` | `screen_time_controller.dart:savePolicy` | `screen_time_controller_test.dart` |
| USE06 | Screen time | Bedtime configuration and state | Parent | Screen time/Rules | PARTIAL | `device_policies`; policy apply | `screen_time_controller.dart`; `PolicyApplier.kt:502` reports only | `screen_time_quota_test.dart`; Kotlin quota tests |
| USE07 | Screen time | Remaining-time/limit-reached display | Parent | Screen time | IMPLEMENTED | Computed from policy + usage | `screen_time_controller.dart` getters | `screen_time_controller_test.dart` |
| USE08 | Screen time | OS-level daily-limit enforcement | Child | Guardian service | PARTIAL | Device Owner + `UsageStatsManager` | `PolicyApplier.kt` `quotaPlan`; `QuotaEvaluator.kt` | `QuotaEvaluatorTest.kt`; not enforced without Device Owner |
| APP01 | App blocking | Block selected apps | Parent | App restrictions | IMPLEMENTED | `device-policy update`; `device_commands` | `app_restrictions_controller.dart`; `PolicyApplier.kt` | `app_restrictions_controller_test.dart` |
| APP02 | App blocking | Block all except allowed list | Parent | App restrictions | IMPLEMENTED | `device_policies` flags | `app_restrictions_controller.dart:setBlockAllExceptAllowed` | `app_restrictions_controller_test.dart` |
| APP03 | App blocking | Allowed-app list management | Parent | App restrictions | IMPLEMENTED | `device_policies` payload | `app_restrictions_controller.dart:setAllowed` | app restrictions tests |
| APP04 | App blocking | Per-app schedule windows | Parent | App restrictions | IMPLEMENTED | Policy `app_rules.windows` | `app_restrictions_controller.dart:addWindow/updateWindow`; `PolicyEvaluator.kt` | `PolicyEvaluatorTest.kt`; app restriction tests |
| APP05 | App blocking | Enforcement acknowledgement and applied counts | Parent–Child | App restrictions/Device detail | IMPLEMENTED | `device_commands` ack result | `app_restrictions_controller.dart:_loadEnforcementReport` | enforcement correlation tests |
| APP06 | App blocking | Request policy sync command | Parent | App restrictions | IMPLEMENTED | `device-command create sync` | `app_restrictions_controller.dart:requestSync` | app restrictions tests |
| APP07 | App blocking | OS app suspension | Child | Guardian service | PARTIAL | `DevicePolicyManager.setPackagesSuspended` | `PolicyApplier.kt:suspendPackages`; requires Device Owner | `EnforcementModeTest.kt`; live device not Device Owner |
| LOC01 | Location | Latest child location | Parent | Location | IMPLEMENTED | `location_events` | `location_controller.dart`; `supabase_location_repository.dart` | `location_controller_test.dart` |
| LOC02 | Location | 24-hour/7-day location history | Parent | Location | IMPLEMENTED | `location_events` query | `location_controller.dart:loadHistory` | `location_controller_test.dart` |
| LOC03 | Location | Child location-sharing toggle | Child | Child home/settings | IMPLEMENTED | `location_upload`; native service | `child_shell_controller.dart:910` | child shell tests |
| LOC04 | Location | Child location tracking/upload | Child | Foreground service | PARTIAL | `device-telemetry location_upload` | `LocationTrackingService.kt`; `NativeBridge.kt` | Android service; live upload failed (credential) |
| LOC05 | Location | Safe-zone create/edit/delete/active | Parent | Safe zones | IMPLEMENTED | `safe_zones`; `delete_safe_zone_audited` | `safe_zones_controller.dart`; `family-admin/index.ts:177` | safe-zone tests |
| LOC06 | Alerts | Geofence enter/exit alerts | Parent–Child | Alerts | IMPLEMENTED | `safe_zone_states`; telemetry | `device-telemetry/index.ts:278-350` | Edge tests; live alerts |
| LOC07 | Alerts | Low-battery alerts | Parent–Child | Alerts | IMPLEMENTED | heartbeat alert insert | `device-telemetry/index.ts:118-146` | Edge tests; live alerts |
| LOC08 | Alerts | Offline alerts | Parent–Child | Alerts | IMPLEMENTED | `detect_offline_devices` | `functions.sql:531`; cron | Edge/SQL tests |
| LOC09 | Alerts | Permission-degradation alerts | Parent–Child | Alerts | IMPLEMENTED | heartbeat permission map | `device-telemetry/index.ts:96-146` | Edge tests |
| LOC10 | Alerts | Alert list, severity filter, acknowledge | Parent | Alerts | IMPLEMENTED | `safety_alerts`; `family-admin ack_alert` | `safety_alerts_controller.dart`; `alerts_body.dart` | `safety_alerts_controller_test.dart` |
| REM01 | Remote assistance | Parent requests audio/video session | Parent | Remote assistance | IMPLEMENTED | `remote-session request` | `remote_assistance_controller.dart:68`; `remote-session/index.ts:111` | remote assistance tests |
| REM02 | Remote assistance | Child accepts/declines session | Child | Requests | IMPLEMENTED | `remote-session respond` | `child_requests_controller.dart:158` | `remote_child_session_test.dart` |
| REM03 | Remote assistance | WebRTC audio/video session | Parent–Child | Remote session | IMPLEMENTED | `remote-session start/ice`; WebRTC | `remote_session_controller.dart:1080`; `remote-session/index.ts` | remote session tests; Kotlin audio tests |
| REM04 | Remote assistance | Session history/status detail | Parent | Remote assistance | IMPLEMENTED | `remote_sessions` query | `remote_assistance_controller.dart`; `remote_session_page.dart` | remote assistance tests |
| REM05 | Remote assistance | End session and cleanup | Parent–Child | Session screen | IMPLEMENTED | `remote-session end`; native service | `remote_session_controller.dart`; `child_shell_controller.dart:425` | remote session/reliability tests |
| AUD01 | Audit | Paginated audit log | Parent | Audit & retention | IMPLEMENTED | `audit_logs`; RLS | `audit_logs_controller.dart`; `supabase_audit_repository.dart` | `audit_logs_controller_test.dart` |
| AUD02 | Audit | Retention settings view/update | Parent | Audit & retention | IMPLEMENTED | `update_retention` | `audit_logs_controller.dart:178`; `family-admin/index.ts:347` | audit tests |
| AUD03 | Audit | Purge old data | Parent | Audit & retention | IMPLEMENTED | `purge_data` | `audit_logs_controller.dart:239`; `family-admin/index.ts:265` | audit tests |
| AUD04 | Audit | Scheduled retention sweep | Parent | None | BACKEND ONLY | `run_retention_sweep`; cron | `20261030000300_retention_sweep.sql`; `cron/index.ts` | SQL/Edge tests |
| SET01 | Settings | Local notification preference | Parent | Settings | UI ONLY | Local SharedPreferences | `parent_settings_controller.dart:147`; no scheduler uses it | settings tests |
| SET02 | Settings | Location-sharing reminder preference | Parent | Settings | UI ONLY | Local SharedPreferences | `parent_settings_controller.dart:164`; no reminder consumer | settings tests |
| SET03 | Settings | App version display | Shared | Settings | IMPLEMENTED | Android PackageInfo | `parent_settings_controller.dart:130`; `NativeBridge.kt` | settings tests |
| SET04 | Permissions | Runtime permission requests | Shared | Settings/onboarding | IMPLEMENTED | Android runtime permissions | `NativeBridge.kt:455`; `device_admin_service.dart` | child settings gating tests |
| SET05 | Permissions | Device-admin activation | Child | Child settings | IMPLEMENTED | `DevicePolicyManager` | `NativeBridge.kt:398`; `ParentControlDeviceAdminReceiver.kt` | `EnforcementModeTest.kt` |
| SET06 | Permissions | Background-location settings launcher | Child | Child settings | IMPLEMENTED | Android app settings intent | `NativeBridge.kt:424` | child settings tests |
| CHD01 | Child | Child home summary | Child | Child Home | IMPLEMENTED | family/device/policy queries | `child_home_tab.dart`; `child_shell_controller.dart` | child shell/page tests |
| CHD02 | Child | Rules/policy display | Child | Rules | IMPLEMENTED | `device_policies` | `child_rules_tab.dart`; `child_shell_controller.dart:476` | child rules tests |
| CHD03 | Child | Pairing/assistance requests inbox | Child | Requests | IMPLEMENTED | pairing/remote-session | `child_requests_controller.dart`; `child_requests_tab.dart` | `child_requests_controller_test.dart` |
| CHD04 | Child | Guardian foreground service | Child | Background protection | IMPLEMENTED | Native service | `GuardianService.kt`; `NativeBridge.kt` | Kotlin service tests |
| CHD05 | Child | Camera/microphone self-test | Child | Child settings | IMPLEMENTED | Camera/mic permission | `media_self_test_sheet.dart`; `NativeBridge.kt` | `media_self_test_sheet_test.dart` |
| CHD06 | Child | Native enforcement verification | Child | Child rules | IMPLEMENTED | `isPackageSuspended` | `child_shell_controller.dart:502`; `NativeBridge.kt:125` | child shell tests |
| CHD07 | Child | Background sync retry | Child | Child settings | IMPLEMENTED | `configureBackgroundSync` | `child_shell_controller.dart:839`; `NativeBridge.kt:357` | child shell tests |
| SYS01 | Synchronization | Offline detection and cached-state handling | Shared | All shells | IMPLEMENTED | Connectivity + repositories | `connectivity_service.dart`; dashboards/devices controllers | dashboard/devices async guard tests |
| SYS02 | Synchronization | Manual and periodic refresh | Shared | All lists | IMPLEMENTED | Repository queries | dashboard/devices/screen-time controllers | controller tests |
