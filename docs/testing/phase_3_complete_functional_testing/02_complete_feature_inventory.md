# 02 — Complete Feature Inventory

**Date:** 2026-11-21  
**Source of truth:** repository at HEAD `bbd3c21` plus installed `1.0.0` metadata  
**Implementation labels:** IMPLEMENTED / PARTIAL / NOT_IMPLEMENTED / PLATFORM_LIMITED / UNABLE_TO_VERIFY  
**Test labels:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED

---

## 1. Parent features (64)

| ID | Feature | Implementation | Test status | Primary source |
|---|---|---|---|---|
| P01 | Splash / session restore | IMPLEMENTED | PASS | `features/auth/splash_*`, `auth_session_flow.dart` |
| P02 | Backend configuration screen | IMPLEMENTED | NOT_TESTED | `features/configuration` |
| P03 | Role selection | IMPLEMENTED | NOT_TESTED | `features/role_selection` |
| P04 | Login | IMPLEMENTED | NOT_TESTED | `features/auth/login_*` |
| P05 | Register | IMPLEMENTED | NOT_TESTED | `features/auth/register_*` |
| P06 | Verify email | IMPLEMENTED | NOT_TESTED | `features/auth/verify_email_*` |
| P07 | Parent shell / navigation | IMPLEMENTED | PASS | `features/parent_shell` |
| P08 | Dashboard family summary | IMPLEMENTED | PASS | `features/dashboard` |
| P09 | Dashboard device cards | IMPLEMENTED | PASS | `features/dashboard` |
| P10 | Dashboard presence/offline state | IMPLEMENTED | FAIL | `data/models/device.dart` |
| P11 | Dashboard quick links | IMPLEMENTED | PASS | `parent_dashboard_tab.dart` |
| P12 | Family overview | IMPLEMENTED | PASS | `features/family` |
| P13 | Family guardians | IMPLEMENTED | PASS | `family_page.dart` |
| P14 | Family children | IMPLEMENTED | PASS | `family_page.dart` |
| P15 | Family linked devices | IMPLEMENTED | PASS | `family_page.dart` |
| P16 | Family pending pairing | IMPLEMENTED | PASS | `family_page.dart` |
| P17 | Family retention display | IMPLEMENTED | PASS | `family_page.dart` |
| P18 | Link child / create pairing code | IMPLEMENTED | AUTHORIZATION_REQUIRED | `pairing_redeem_*` |
| P19 | Pairing requests list/cancel | IMPLEMENTED | NOT_TESTED | `pairing_requests_*` |
| P20 | Redeem linking code | IMPLEMENTED | AUTHORIZATION_REQUIRED | `pairing_redeem_*` |
| P21 | Unlink child | IMPLEMENTED | AUTHORIZATION_REQUIRED | `pairing.unlink` |
| P22 | Device list | IMPLEMENTED | PASS | `features/devices` |
| P23 | Device detail identity | IMPLEMENTED | PASS | `device_detail_page.dart` |
| P24 | Device online/offline | IMPLEMENTED | FAIL | `device.dart` |
| P25 | Last-seen timestamp | IMPLEMENTED | FAIL | `device.dart` |
| P26 | Device policy summary | IMPLEMENTED | FAIL | `devices_controller.dart` |
| P27 | Policy detail / ack status | IMPLEMENTED | PASS | `device_detail_controller.dart` |
| P28 | Revoke device | IMPLEMENTED | AUTHORIZATION_REQUIRED | `family-admin revoke_device` |
| P29 | Lost/reinstalled device recovery | IMPLEMENTED | AUTHORIZATION_REQUIRED | `family-admin recover_device` |
| P30 | App restrictions list | IMPLEMENTED | NOT_TESTED | `features/app_restrictions` |
| P31 | App restrictions save policy | IMPLEMENTED | AUTHORIZATION_REQUIRED | `device-policy update` |
| P32 | App restrictions sync now | IMPLEMENTED | AUTHORIZATION_REQUIRED | `device-command create` |
| P33 | Enforcement status truthfulness | IMPLEMENTED | PASS | `device_presentation.dart` |
| P34 | Quota status panel | IMPLEMENTED | NOT_TESTED | `app_restrictions_controller.dart` |
| P35 | Screen-time today | IMPLEMENTED | NOT_TESTED | `features/screen_time` |
| P36 | Screen-time 7-day history | IMPLEMENTED | NOT_TESTED | `screen_time_controller.dart` |
| P37 | Daily limit edit | IMPLEMENTED | AUTHORIZATION_REQUIRED | `screen_time_controller.dart` |
| P38 | Bedtime edit | IMPLEMENTED | AUTHORIZATION_REQUIRED | `screen_time_controller.dart` |
| P39 | Location latest | IMPLEMENTED | NOT_TESTED | `features/location` |
| P40 | Location history | IMPLEMENTED | NOT_TESTED | `location_controller.dart` |
| P41 | Location refresh/permission state | IMPLEMENTED | NOT_TESTED | `location_page.dart` |
| P42 | Safe zones list | IMPLEMENTED | NOT_TESTED | `features/safe_zones` |
| P43 | Safe-zone create/edit/delete | IMPLEMENTED | AUTHORIZATION_REQUIRED | `safe_zones_controller.dart` |
| P44 | Safe-zone alert state | IMPLEMENTED | NOT_TESTED | `safe_zone_states` |
| P45 | Safety alerts list/filter | IMPLEMENTED | PASS | `features/safety_alerts` |
| P46 | Alert acknowledge | IMPLEMENTED | NOT_TESTED | `safety_alerts_controller.dart` |
| P47 | Alert realtime updates | IMPLEMENTED | NOT_TESTED | `supabase_alert_repository.dart` |
| P48 | Remote assistance request audio | IMPLEMENTED | AUTHORIZATION_REQUIRED | `remote_assistance_*` |
| P49 | Remote assistance request video | IMPLEMENTED | AUTHORIZATION_REQUIRED | `remote_assistance_*` |
| P50 | Assistance pending state | IMPLEMENTED | NOT_TESTED | `remote_assistance_controller.dart` |
| P51 | Remote session audio playback | IMPLEMENTED | NOT_TESTED | `remote_session_*` |
| P52 | Remote session video | IMPLEMENTED | NOT_TESTED | `remote_session_*` |
| P53 | Remote session end/reconnect | IMPLEMENTED | NOT_TESTED | `remote_session_controller.dart` |
| P54 | Audit log list | IMPLEMENTED | NOT_TESTED | `features/audit_logs` |
| P55 | Audit filters/paging | IMPLEMENTED | NOT_TESTED | `audit_logs_controller.dart` |
| P56 | Parent settings/profile | IMPLEMENTED | NOT_TESTED | `features/settings` |
| P57 | Sign out | IMPLEMENTED | AUTHORIZATION_REQUIRED | `parent_settings_controller.dart` |
| P58 | Retention settings | IMPLEMENTED | AUTHORIZATION_REQUIRED | `family-admin update_retention` |
| P59 | Data export | IMPLEMENTED | AUTHORIZATION_REQUIRED | `account export` |
| P60 | Delete account | IMPLEMENTED | AUTHORIZATION_REQUIRED | `account delete_account` |
| P61 | Notification preferences | IMPLEMENTED | NOT_TESTED | `local_settings_service.dart` |
| P62 | Account/privacy screen | IMPLEMENTED | NOT_TESTED | `settings_body.dart` |
| P63 | Loading/empty/error/retry states | IMPLEMENTED | PASS | controllers/widgets |
| P64 | Route authorization | PARTIAL | NOT_TESTED | no middleware; per-call auth |

---

## 2. Child features (44)

| ID | Feature | Implementation | Test status | Primary source |
|---|---|---|---|---|
| C01 | Splash/session restore | IMPLEMENTED | PASS | `child_shell_*` |
| C02 | Child role/family resolution | IMPLEMENTED | PASS | `child_shell_controller.dart` |
| C03 | Child home status | IMPLEMENTED | PASS | `child_home_tab.dart` |
| C04 | Device identity display | IMPLEMENTED | NOT_TESTED | `child_home_tab.dart` |
| C05 | Enrollment / Child ID | IMPLEMENTED | NOT_TESTED | `child_enrollment_*` |
| C06 | Child QR pairing display | IMPLEMENTED | NOT_TESTED | `pairing_qr_payload.dart` |
| C07 | Pending pairing requests | IMPLEMENTED | PASS | `child_requests_controller.dart` |
| C08 | Approve/decline pairing | IMPLEMENTED | AUTHORIZATION_REQUIRED | `child_requests_controller.dart` |
| C09 | Existing-device handling | IMPLEMENTED | FAIL | `child_enrollment_controller.dart` |
| C10 | Credential storage | IMPLEMENTED | PASS | `SecureStore.kt` |
| C11 | Re-credentialing after reinstall | NOT_IMPLEMENTED | NOT_IMPLEMENTED | no path |
| C12 | Guardian foreground service | IMPLEMENTED | PASS | `GuardianService.kt` |
| C13 | Guardian notification | IMPLEMENTED | PASS | `GuardianService.kt` |
| C14 | Heartbeat scheduling | IMPLEMENTED | PASS | `GuardianService.kt` |
| C15 | Heartbeat authentication | IMPLEMENTED | FAIL | `DeviceHttpClient.kt`, `_shared/auth.ts` |
| C16 | Heartbeat retry/backoff | IMPLEMENTED | PASS (source) | `GuardianService.kt` |
| C17 | App-list upload | IMPLEMENTED | BLOCKED | `GuardianService.kt` |
| C18 | Usage upload | IMPLEMENTED | BLOCKED | `UsageReporter.kt` |
| C19 | Location upload | IMPLEMENTED | BLOCKED | `LocationTrackingService.kt` |
| C20 | Online/offline sync | IMPLEMENTED | FAIL | heartbeat + parent |
| C21 | Location permission status | IMPLEMENTED | FAIL | `child_shell_controller.dart` |
| C22 | Location sharing toggle | IMPLEMENTED | PASS | `child_preferences.dart` |
| C23 | Location tracking service | IMPLEMENTED | FAIL | `LocationTrackingService.kt` |
| C24 | Usage access status | IMPLEMENTED | PASS | `NativePermissions.kt` |
| C25 | App inventory collection | IMPLEMENTED | BLOCKED | `InstalledApps.kt` |
| C26 | Policy download | IMPLEMENTED | BLOCKED | `device-command poll` |
| C27 | Policy presentation | IMPLEMENTED | NOT_TESTED | `child_rules_tab.dart` |
| C28 | Device Owner enforcement | IMPLEMENTED | PLATFORM_LIMITED | `PolicyApplier.kt` |
| C29 | Daily quota enforcement | IMPLEMENTED | PLATFORM_LIMITED | `QuotaEvaluator.kt` |
| C30 | Bedtime enforcement | PARTIAL (informational) | NOT_IMPLEMENTED | `PolicyApplier.kt` |
| C31 | 10-minute emergency pass | NOT_IMPLEMENTED | NOT_IMPLEMENTED | absent |
| C32 | Safety-event reporting | IMPLEMENTED | BLOCKED | telemetry |
| C33 | Notification permission | IMPLEMENTED | PASS | `NativePermissions.kt` |
| C34 | Local preference persistence | IMPLEMENTED | PASS | `child_preferences.dart` |
| C35 | Network-loss handling | IMPLEMENTED | NOT_TESTED | connectivity/service |
| C36 | Background execution | IMPLEMENTED | PASS | FGS observed |
| C37 | Battery-optimization guidance | IMPLEMENTED | NOT_TESTED | child settings |
| C38 | Reboot/process restart recovery | IMPLEMENTED | NOT_TESTED | `BootReceiver.kt` |
| C39 | Child requests inbox | IMPLEMENTED | PASS | `child_requests_*` |
| C40 | Remote-assistance consent | IMPLEMENTED | NOT_TESTED | `child_session_*` |
| C41 | Remote session join/media | IMPLEMENTED | AUTHORIZATION_REQUIRED | WebRTC controller |
| C42 | Child settings | IMPLEMENTED | NOT_TESTED | `child_settings_tab.dart` |
| C43 | Restrictions/permission screen | IMPLEMENTED | NOT_TESTED | `child_restrictions_page.dart` |
| C44 | Logout/session recovery | IMPLEMENTED | AUTHORIZATION_REQUIRED | `child_shell_controller.dart` |

---

## 3. Shared/backend features (18)

| ID | Feature | Implementation | Test status | Primary source |
|---|---|---|---|---|
| S01 | Auth bootstrap `set_role` | IMPLEMENTED | PASS (offline) | `auth-bootstrap` |
| S02 | Family create | IMPLEMENTED | PASS (offline) | `create_family` |
| S03 | Pairing lifecycle | IMPLEMENTED | PASS (offline) | `pairing` |
| S04 | Device register | IMPLEMENTED | PASS (offline) | `device-register` |
| S05 | Device policy update | IMPLEMENTED | PASS (offline) | `device-policy` |
| S06 | Device command create/poll/ack | IMPLEMENTED | PASS (offline) | `device-command` |
| S07 | Telemetry heartbeat | IMPLEMENTED | PASS (offline) | `device-telemetry` |
| S08 | Telemetry usage/location/apps | IMPLEMENTED | PASS (offline) | `device-telemetry` |
| S09 | Family admin actions | IMPLEMENTED | PASS (offline) | `family-admin` |
| S10 | Remote session lifecycle | IMPLEMENTED | PASS (offline) | `remote-session` |
| S11 | Account export/delete/retention | IMPLEMENTED | PASS (offline) | `account` |
| S12 | Cron sweeps | IMPLEMENTED | PASS (offline) | `cron` |
| S13 | RLS / tenant isolation | IMPLEMENTED | PASS (SQL) | migrations/tests |
| S14 | Realtime channels | IMPLEMENTED | NOT_TESTED | live subscription |
| S15 | Error envelope/validation | IMPLEMENTED | PASS (unit) | `_shared/envelope.ts` |
| S16 | Device credential auth | IMPLEMENTED | PASS (unit) | `_shared/auth.ts` |
| S17 | Retry/backoff | IMPLEMENTED | PASS (source) | service/repositories |
| S18 | Audit logging | IMPLEMENTED | PASS (schema) | `audit_logs` |

---

## 4. Discovery totals

| Group | Count |
|---|---:|
| Parent features | 64 |
| Child features | 44 |
| Shared/backend features | 18 |
| **Total** | **126** |
| NOT_IMPLEMENTED | 3 (C11, C30, C31) |
| **Implemented** | **123** |

Additional implemented capabilities discovered beyond the prompt’s minimum list: family retention display, audit retention/purge, safe-zone activation state, quota panel, enforcement-report correlation, remote-session registry, child enforced-app verification, support for 1/7-day usage ranges, and the configuration/setup screen.
