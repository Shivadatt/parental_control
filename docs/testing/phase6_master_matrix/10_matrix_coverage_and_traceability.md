# 10 — Matrix Coverage and Traceability

Source of truth: `docs/testing/functionality_inventory/01_complete_functionality_inventory.md` at checkout `80375f518139bf922bc1b66c998691bee912af44`.

## Reconciliation summary

| Check | Result |
|---|---|
| Original functionality IDs | 80 |
| Unique functionality IDs represented | 80 |
| Missing IDs | 0 |
| Extra non-inventory IDs | 1 (`SEC-001`, intentionally separate) |
| Planned test cases | 98 |
| All test statuses | NOT TESTED |
| Parent-role cases | 39 |
| Child-role cases | 21 |
| Shared cases | 16 |
| Interconnected cases | 10 |
| Partial limitation cases | 7 |
| UI-only cases | 2 |
| Backend-only cases | 2 |
| Security cases | 1 |
| Parent-only IDs | 35 |
| Child-only IDs | 19 |
| Shared IDs | 14 |
| Interconnected IDs | 10 |
| Backend-only IDs | 2 |
| Partial IDs | 7 |
| UI-only IDs | 2 |
| Absent capabilities | 10, separate |
| Approval-gated scenarios | 14 |

## Parent-only (35)

| Functionality ID | Name | Inventory classification | Case IDs |
|---|---|---|---|
| FAM01 | Link child by QR scan | Link a child | P6-PAR-001 |
| FAM02 | Link child by Child ID/linking code | Link a child | P6-PAR-002 |
| FAM03 | Send pairing request | Link a child | P6-PAR-003 |
| FAM04 | Pairing request list and cancel | `/parent/pairing/requests` | P6-PAR-004, P6-PAR-036 |
| FAM08 | Create family | Family setup | P6-PAR-005 |
| FAM09 | Family details, members, roles | Family details | P6-PAR-006 |
| FAM10 | Unlink child account/device | Family details | P6-PAR-007 |
| FAM12 | Revoke device | Device detail | P6-PAR-008 |
| FAM13 | Device recovery for lost/reinstalled phone | Device detail | P6-PAR-009 |
| MON01 | Family/dashboard overview | Dashboard | P6-PAR-010 |
| MON02 | Device list with policy/status cards | Devices | P6-PAR-011 |
| MON03 | Device detail: identity, battery, enforcement, last seen | Device detail | P6-PAR-012 |
| MON06 | Recent command history | Device detail | P6-PAR-013 |
| USE01 | Daily usage history | Screen time | P6-PAR-014 |
| USE02 | App usage breakdown | Screen time | P6-PAR-015 |
| USE03 | Usage Access status and guidance | Screen time | P6-PAR-016 |
| USE05 | Daily screen-time limit configuration/save | Screen time | P6-PAR-017 |
| USE06 | Bedtime configuration and state | Screen time/Rules | P6-PAR-018, P6-LIM-004 |
| USE07 | Remaining-time/limit-reached display | Screen time | P6-PAR-019 |
| APP01 | Block selected apps | App restrictions | P6-PAR-020 |
| APP02 | Block all except allowed list | App restrictions | P6-PAR-021 |
| APP03 | Allowed-app list management | App restrictions | P6-PAR-022 |
| APP04 | Per-app schedule windows | App restrictions | P6-PAR-023 |
| APP06 | Request policy sync command | App restrictions | P6-PAR-024 |
| LOC01 | Latest child location | Location | P6-PAR-025 |
| LOC02 | 24-hour/7-day location history | Location | P6-PAR-026 |
| LOC05 | Safe-zone create/edit/delete/active | Safe zones | P6-PAR-027 |
| LOC10 | Alert list, severity filter, acknowledge | Alerts | P6-PAR-028, P6-PAR-037 |
| REM01 | Parent requests audio/video session | Remote assistance | P6-PAR-029 |
| REM04 | Session history/status detail | Remote assistance | P6-PAR-030 |
| AUD01 | Paginated audit log | Audit & retention | P6-PAR-031 |
| AUD02 | Retention settings view/update | Audit & retention | P6-PAR-032 |
| AUD03 | Purge old data | Audit & retention | P6-PAR-033 |
| SET01 | Local notification preference | Settings | P6-PAR-034, P6-UI-001 |
| SET02 | Location-sharing reminder preference | Settings | P6-PAR-035, P6-UI-002 |

## Child-only (19)

| Functionality ID | Name | Inventory classification | Case IDs |
|---|---|---|---|
| FAM05 | Child approves/declines pairing | Requests | P6-CHD-001 |
| FAM06 | Child ID/contact ID and QR display | Enrollment | P6-CHD-002 |
| FAM07 | Child enrollment/device registration | Enrollment | P6-CHD-003 |
| FAM11 | Child self-unlink | Child settings | P6-CHD-004 |
| USE04 | Child usage collection/upload | Background service | P6-CHD-005, P6-LIM-003 |
| USE08 | OS-level daily-limit enforcement | Guardian service | P6-CHD-006, P6-LIM-005 |
| APP07 | OS app suspension | Guardian service | P6-CHD-007, P6-LIM-006 |
| LOC03 | Child location-sharing toggle | Child home/settings | P6-CHD-008 |
| LOC04 | Child location tracking/upload | Foreground service | P6-CHD-009, P6-LIM-007 |
| REM02 | Child accepts/declines session | Requests | P6-CHD-010 |
| SET05 | Device-admin activation | Child settings | P6-CHD-011 |
| SET06 | Background-location settings launcher | Child settings | P6-CHD-012 |
| CHD01 | Child home summary | Child Home | P6-CHD-013 |
| CHD02 | Rules/policy display | Rules | P6-CHD-014 |
| CHD03 | Pairing/assistance requests inbox | Requests | P6-CHD-015 |
| CHD04 | Guardian foreground service | Background protection | P6-CHD-016, P6-CHD-020 |
| CHD05 | Camera/microphone self-test | Child settings | P6-CHD-017 |
| CHD06 | Native enforcement verification | Child rules | P6-CHD-018 |
| CHD07 | Background sync retry | Child settings | P6-CHD-019 |

## Shared (14)

| Functionality ID | Name | Inventory classification | Case IDs |
|---|---|---|---|
| A01 | Email/password sign-in | `/auth/login` | P6-SHR-001, P6-SHR-015 |
| A02 | Account registration | `/auth/register` | P6-SHR-002 |
| A03 | Email verification, resend, refresh | `/auth/verify-email` | P6-SHR-003 |
| A04 | Persisted session restore | `/` splash | P6-SHR-004 |
| A05 | Sign out | Parent/Child settings | P6-SHR-005 |
| A06 | Role selection and initial role assignment | `/role-selection` | P6-SHR-006 |
| A07 | Account/profile display | Settings | P6-SHR-007 |
| A08 | Account data export | Settings → Privacy & data | P6-SHR-008 |
| A09 | Account deletion with confirmation | Settings → Privacy & data | P6-SHR-009 |
| A10 | Backend configuration/error screen | `/configuration` | P6-SHR-010 |
| SET03 | App version display | Settings | P6-SHR-011 |
| SET04 | Runtime permission requests | Settings/onboarding | P6-SHR-012 |
| SYS01 | Offline detection and cached-state handling | All shells | P6-SHR-013 |
| SYS02 | Manual and periodic refresh | All lists | P6-SHR-014, P6-SHR-016 |

## Interconnected (10)

| Functionality ID | Name | Inventory classification | Case IDs |
|---|---|---|---|
| MON04 | Heartbeat-derived online/offline and last-seen status | Dashboard/Device detail | P6-INT-001, P6-LIM-001 |
| MON05 | Child permission summary | Device detail | P6-INT-002, P6-LIM-002 |
| MON07 | Installed-app snapshot | App restrictions | P6-INT-003 |
| APP05 | Enforcement acknowledgement and applied counts | App restrictions/Device detail | P6-INT-004 |
| LOC06 | Geofence enter/exit alerts | Alerts | P6-INT-005 |
| LOC07 | Low-battery alerts | Alerts | P6-INT-006 |
| LOC08 | Offline alerts | Alerts | P6-INT-007 |
| LOC09 | Permission-degradation alerts | Alerts | P6-INT-008 |
| REM03 | WebRTC audio/video session | Remote session | P6-INT-009 |
| REM05 | End session and cleanup | Session screen | P6-INT-010 |

## Cross-cutting state cases (3)

| Case | Functionality IDs | Role | Purpose |
|---|---|---|---|
| P6-STATE-001 | MON01; MON02; SYS01 | Parent | Loading, empty, cached, or stale states when naturally present |
| P6-STATE-002 | FAM09; USE01; LOC01; LOC10; AUD01 | Parent | Empty, error, retry, or stale states |
| P6-STATE-003 | CHD01; CHD02; SYS01 | Child | Permission-denied, offline, cached, or error states |

## Backend-only (2)

| Functionality ID | Name | Inventory classification | Case IDs |
|---|---|---|---|
| FAM14 | Update family settings API | BACKEND ONLY | P6-BEK-001 |
| AUD04 | Scheduled retention sweep | BACKEND ONLY | P6-BEK-002 |

## Intentional multiple cases

| Functionality ID | Cases | Rationale |
|---|---|---|
| MON04 | P6-INT-001, P6-LIM-001 | Positive paired check + limitation |
| MON05 | P6-INT-002, P6-LIM-002 | Positive paired check + limitation |
| USE04 | P6-CHD-005, P6-LIM-003 | Positive child check + limitation |
| USE06 | P6-PAR-018, P6-LIM-004 | Positive configuration + limitation |
| USE08 | P6-CHD-006, P6-LIM-005 | Positive check + limitation |
| APP07 | P6-CHD-007, P6-LIM-006 | Positive check + limitation |
| LOC04 | P6-CHD-009, P6-LIM-007 | Positive check + limitation |
| SET01 | P6-PAR-034, P6-UI-001 | Parent-only functional check + UI-only verification |
| SET02 | P6-PAR-035, P6-UI-002 | Parent-only functional check + UI-only verification |
| FAM04 | P6-PAR-004, P6-PAR-036 | Read-only list + gated cancellation |
| LOC10 | P6-PAR-028, P6-PAR-037 | Read-only list/filter + gated acknowledgement |
| CHD04 | P6-CHD-016, P6-CHD-020 | Read-only service state + gated restart |
| A01 | P6-SHR-001, P6-SHR-015 | Read-only existing-session/identity observation + isolated invalid-credential test; positive sign-in is separately blocked |
| SYS02 | P6-SHR-014, P6-SHR-016 | Successful refresh + gated backend/error scenario |

## Classification preservation

No inventory ID was renamed, merged, removed, or silently reclassified. The master matrix preserves the original inventory classification in a dedicated column. Test status is independent and always NOT TESTED. The seven partial IDs remain partial; the two UI-only and two backend-only IDs remain as classified.

## Discrepancies

- The task brief cites `docs/testing/phase6/21_run8_ai_parent_login_result.md`; the actual existing report is `docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md`. Documented, not silently replaced.
- The master includes `SEC-001` as a security issue outside the 80; it is not counted as functionality.
- Parent, Child, and paired reports include shared/interconnected cases by design; they do not change the unique 80-item count.

## Completion condition

All 80 original IDs have at least one traceable case. The revised matrix has 98 cases. No PASS is claimed. No test was executed.

CURRENT STATUS: FOURTH DOCUMENTATION CORRECTION IN PROGRESS — RUNTIME QA NOT AUTHORIZED. The third independent review returned **THIRD REVIEW FAILED — CORRECTIONS REQUIRED**. A FURTHER INDEPENDENT REVIEW IS REQUIRED AFTER CORRECTIONS. No owner approval has been granted. The matrix is not ready for runtime execution.
