# 04 — Shared and Parent–Child Functionalities

This report isolates the 24 functionalities that are not role-exclusive: 14 shared capabilities used by either signed-in role, and 10 capabilities that require both devices to cooperate. Each appears once in the 80-item inventory.

## Headline counts

| Measure | Count |
|---|---:|
| Shared + interconnected unique functionalities | **24** |
| Shared | 14 |
| Parent–Child interconnected | 10 |
| Fully implemented | 22 |
| Partially implemented | 2 |
| UI only | 0 |
| Backend only | 0 |

## Shared functionality (14)

| ID | Functionality | Status | Evidence |
|---|---|---|---|
| A01 | Email/password sign-in | IMPLEMENTED | `login_controller.dart`, Supabase Auth |
| A02 | Account registration | IMPLEMENTED | `register_controller.dart`, `auth-bootstrap` |
| A03 | Email verification, resend, refresh | IMPLEMENTED | `verify_email_controller.dart` |
| A04 | Persisted session restore | IMPLEMENTED | `splash_controller.dart`, `session_service.dart` |
| A05 | Sign out | IMPLEMENTED | Parent and Child settings |
| A06 | Role selection and initial role assignment | IMPLEMENTED | `role_selection_controller.dart`, `auth-bootstrap set_role` |
| A07 | Account/profile display | IMPLEMENTED | `settings_body.dart` |
| A08 | Account data export | IMPLEMENTED | `account export` Edge action |
| A09 | Account deletion with confirmation | IMPLEMENTED | `delete_account_dialog.dart`, `account delete` |
| A10 | Backend configuration/error screen | IMPLEMENTED | `configuration_page.dart` |
| SET03 | App version display | IMPLEMENTED | Android `PackageInfo` through `NativeBridge` |
| SET04 | Runtime permission requests | IMPLEMENTED | `NativeBridge.requestPermissions` |
| SYS01 | Offline detection and cached-state handling | IMPLEMENTED | `connectivity_service.dart`; async-guard tests |
| SYS02 | Manual and periodic refresh | IMPLEMENTED | Dashboard/devices/screen-time controllers |

## Parent–Child interconnected functionality (10)

| ID | Functionality | Status | Parent side | Child side |
|---|---|---|---|---|
| MON04 | Heartbeat-derived online/offline and last-seen status | PARTIAL | Device cards/detail derive presence from `last_seen_at` | Heartbeat upload is rejected after credential rotation |
| MON05 | Child permission summary | PARTIAL | Device detail displays reported permissions | Telemetry reports permission map; notification value was false on live device |
| MON07 | Installed-app snapshot | IMPLEMENTED | App restrictions picker | Guardian service uploads installed packages |
| APP05 | Enforcement acknowledgement and applied counts | IMPLEMENTED | Enforcement evidence screen | Policy applier reports applied/suspended packages |
| LOC06 | Geofence enter/exit alerts | IMPLEMENTED | Alerts list | Location upload evaluated against `safe_zones` |
| LOC07 | Low-battery alerts | IMPLEMENTED | Alerts list | Heartbeat supplies battery level/charging |
| LOC08 | Offline alerts | IMPLEMENTED | Alerts list | Server sweep uses stale `last_seen_at` |
| LOC09 | Permission-degradation alerts | IMPLEMENTED | Alerts list | Heartbeat reports missing permissions |
| REM03 | WebRTC audio/video session | IMPLEMENTED | Session controller joins signaling | Child consent and audio service join |
| REM05 | End session and cleanup | IMPLEMENTED | Parent can end session | Child stops service and releases session |

## Interaction paths

- **Pairing:** FAM01/FAM02 → FAM03 → FAM05 → FAM07. The parent creates the request; the child approves; registration completes. These are counted separately, not as one interconnected item.
- **Policy:** USE05/USE06/APP01–APP04 → `device-policy` → child apply → APP05 evidence.
- **Monitoring:** child heartbeat/usage/location upload → server tables → parent MON01–MON07, USE01/USE02, LOC01/LOC02, LOC10.
- **Remote assistance:** REM01 → REM02 → REM03 → REM05, with REM04 as history.

## Notes

- `MON04` and `MON05` are the only partial items in this group.
- There is no separate heartbeat row; heartbeat is the transport behind `MON04`.
- Shared authentication is counted once even though both roles can use it.
