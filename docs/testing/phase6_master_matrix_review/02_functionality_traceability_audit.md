# 02 — Functionality Traceability Audit

Source: `docs/testing/functionality_inventory/01_complete_functionality_inventory.md` and `06_functionality_count_summary.md`.
Matrix: `docs/testing/phase6_master_matrix/01_master_qa_test_matrix.md` and `10_matrix_coverage_and_traceability.md`.

## Result

| Check | Result |
|---|---|
| Original IDs | 80 |
| Represented | 80 |
| Missing | 0 |
| Renamed IDs | 0 |
| Merged or removed IDs | 0 |
| Incorrect duplicates | 0 |
| Parent-only | 35/35 |
| Child-only | 19/19 |
| Shared | 14/14 |
| Interconnected | 10/10 |
| Partial | 7/7 |
| UI-only | 2/2 |
| Backend-only | 2/2 |

Intentional duplicate cases exist for the seven partial items and the two UI-only items. They are documented in matrix report 10 and are not duplicate functionality IDs.

## Per-ID audit

| ID | Functionality | Role | Inventory category | Inventory classification | Matrix classification | Coverage |
|---|---|---|---|---|---|---|

Case IDs for each ID are recorded in `../phase6_master_matrix/10_matrix_coverage_and_traceability.md`. The matrix classification column below matches the inventory classification for all 80 IDs.
| A01 | Email/password sign-in | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A02 | Account registration | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A03 | Email verification, resend, refresh | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A04 | Persisted session restore | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A05 | Sign out | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A06 | Role selection and initial role assignment | Shared | Authentication | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A07 | Account/profile display | Shared | Account | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A08 | Account data export | Shared | Account | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A09 | Account deletion with confirmation | Shared | Account | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| A10 | Backend configuration/error screen | Shared | Account | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM01 | Link child by QR scan | Parent | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM02 | Link child by Child ID/linking code | Parent | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM03 | Send pairing request | Parent | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM04 | Pairing request list and cancel | Parent | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM05 | Child approves/declines pairing | Child | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM06 | Child ID/contact ID and QR display | Child | Pairing | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM07 | Child enrollment/device registration | Child | Device registration | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM08 | Create family | Parent | Family | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM09 | Family details, members, roles | Parent | Family | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM10 | Unlink child account/device | Parent | Family | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM11 | Child self-unlink | Child | Family | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM12 | Revoke device | Parent | Device control | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM13 | Device recovery for lost/reinstalled phone | Parent | Device control | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| FAM14 | Update family settings API | Parent | Family settings | BACKEND ONLY | BACKEND ONLY | Covered - case in 10 |
| MON01 | Family/dashboard overview | Parent | Parent dashboard | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| MON02 | Device list with policy/status cards | Parent | Devices | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| MON03 | Device detail: identity, battery, enforcement, last seen | Parent | Devices | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| MON04 | Heartbeat-derived online/offline and last-seen status | Parent–Child | Devices | PARTIAL | PARTIAL | Covered - case in 10 |
| MON05 | Child permission summary | Parent–Child | Devices | PARTIAL | PARTIAL | Covered - case in 10 |
| MON06 | Recent command history | Parent | Devices | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| MON07 | Installed-app snapshot | Parent–Child | Devices | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE01 | Daily usage history | Parent | Usage | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE02 | App usage breakdown | Parent | Usage | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE03 | Usage Access status and guidance | Parent | Usage | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE04 | Child usage collection/upload | Child | Usage | PARTIAL | PARTIAL | Covered - case in 10 |
| USE05 | Daily screen-time limit configuration/save | Parent | Screen time | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE06 | Bedtime configuration and state | Parent | Screen time | PARTIAL | PARTIAL | Covered - case in 10 |
| USE07 | Remaining-time/limit-reached display | Parent | Screen time | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| USE08 | OS-level daily-limit enforcement | Child | Screen time | PARTIAL | PARTIAL | Covered - case in 10 |
| APP01 | Block selected apps | Parent | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP02 | Block all except allowed list | Parent | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP03 | Allowed-app list management | Parent | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP04 | Per-app schedule windows | Parent | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP05 | Enforcement acknowledgement and applied counts | Parent–Child | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP06 | Request policy sync command | Parent | App blocking | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| APP07 | OS app suspension | Child | App blocking | PARTIAL | PARTIAL | Covered - case in 10 |
| LOC01 | Latest child location | Parent | Location | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC02 | 24-hour/7-day location history | Parent | Location | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC03 | Child location-sharing toggle | Child | Location | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC04 | Child location tracking/upload | Child | Location | PARTIAL | PARTIAL | Covered - case in 10 |
| LOC05 | Safe-zone create/edit/delete/active | Parent | Location | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC06 | Geofence enter/exit alerts | Parent–Child | Alerts | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC07 | Low-battery alerts | Parent–Child | Alerts | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC08 | Offline alerts | Parent–Child | Alerts | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC09 | Permission-degradation alerts | Parent–Child | Alerts | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| LOC10 | Alert list, severity filter, acknowledge | Parent | Alerts | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| REM01 | Parent requests audio/video session | Parent | Remote assistance | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| REM02 | Child accepts/declines session | Child | Remote assistance | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| REM03 | WebRTC audio/video session | Parent–Child | Remote assistance | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| REM04 | Session history/status detail | Parent | Remote assistance | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| REM05 | End session and cleanup | Parent–Child | Remote assistance | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| AUD01 | Paginated audit log | Parent | Audit | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| AUD02 | Retention settings view/update | Parent | Audit | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| AUD03 | Purge old data | Parent | Audit | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| AUD04 | Scheduled retention sweep | Parent | Audit | BACKEND ONLY | BACKEND ONLY | Covered - case in 10 |
| SET01 | Local notification preference | Parent | Settings | UI ONLY | UI ONLY | Covered - case in 10 |
| SET02 | Location-sharing reminder preference | Parent | Settings | UI ONLY | UI ONLY | Covered - case in 10 |
| SET03 | App version display | Shared | Settings | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| SET04 | Runtime permission requests | Shared | Permissions | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| SET05 | Device-admin activation | Child | Permissions | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| SET06 | Background-location settings launcher | Child | Permissions | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD01 | Child home summary | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD02 | Rules/policy display | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD03 | Pairing/assistance requests inbox | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD04 | Guardian foreground service | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD05 | Camera/microphone self-test | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD06 | Native enforcement verification | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| CHD07 | Background sync retry | Child | Child | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| SYS01 | Offline detection and cached-state handling | Shared | Synchronization | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |
| SYS02 | Manual and periodic refresh | Shared | Synchronization | IMPLEMENTED | IMPLEMENTED | Covered - case in 10 |

## Discrepancies

| ID | Original | Matrix | Severity | Assessment |
|---|---|---|---|---|
| A10 | Category: Account | Category: Authentication | Low | Category changed in `01_master_qa_test_matrix.md`; functionality, role, and classification remain correct. Documentation-only correction recommended. |

No ID is missing, misspelled, merged, removed, or incorrectly duplicated. Three names are shortened but remain faithful to the inventory: `FAM13`, `MON02`, `REM02`. They are not treated as traceability defects.

## Role reconciliation

Matrix function-role counts are 35 Parent, 19 Child, 14 Shared, 10 Interconnected, plus 2 backend-only parent-role APIs. The master has 40 Parent-role rows, 23 Child-role rows, and 12 Interconnected rows because the seven limitation cases and two UI-only duplicate cases reuse those roles. These are intentional multiple cases, not duplicate functionality IDs.

