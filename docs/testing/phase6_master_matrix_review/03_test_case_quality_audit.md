# 03 — Test Case Quality Audit

All 90 cases were checked for required fields, unique IDs, correct functionality ID, role/category, objective, preconditions, reproducible steps, observable expected results, actual result, status, evidence, dependency, risk, cleanup, and limitations.

## Result

| Check | Result |
|---|---|
| Cases audited | 90 |
| Unique case IDs | 90 |
| Missing required fields | 0 |
| Actual result not NOT EXECUTED | 0 |
| Status not NOT TESTED | 0 |
| Incorrect functionality IDs | 0 |
| High/Destructive cases without any approval gate | 0 |
| Cases needing clarification | 10 |
| Intentional duplicate-coverage pairs | 2 |

No runtime result is claimed. Quality verdicts below are documentation assessments only.

## Findings affecting case quality

- **P6-SHR-001** expects invalid-credential handling but steps only cover valid sign-in.
- **P6-INT-001, 005, 006, 007, 008, 009, 010** lack a numeric observation window or polling cadence; failure distinction is qualitative.
- **P6-SEC-001** does not explain how to reach Parent Sign-in without disturbing the preserved session, and its gate is security review rather than explicit session approval.
- **P6-PAR-004** depends on an existing pending request but has no clean fallback when none exists.
- **P6-PAR-028 and P6-CHD-016** contain steps saying “if approved” while the Approval Gate column says NONE.
- **P6-SHR-014** has no backend-unavailable/error scenario.
- Loading, empty, offline, and permission-denied coverage is thin outside SYS01/SET04/USE01.

## Per-case audit

| Case | Functionality ID | Functionality | Risk | Approval gate | Quality verdict |
|---|---|---|---|---|---|
| P6-PAR-001 | FAM01 | Link child by QR scan | Medium | Send requires owner approval. | Adequate - see findings |
| P6-PAR-002 | FAM02 | Link child by Child ID/linking code | Low | NONE | Adequate - see findings |
| P6-PAR-003 | FAM03 | Send pairing request | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-004 | FAM04 | Pairing request list and cancel | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for cancel. | Adequate - see findings |
| P6-PAR-005 | FAM08 | Create family | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-006 | FAM09 | Family details, members, roles | Low | NONE | Adequate - see findings |
| P6-PAR-007 | FAM10 | Unlink child account/device | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-008 | FAM12 | Revoke device | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-009 | FAM13 | Device recovery | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-010 | MON01 | Family/dashboard overview | Low | NONE | Adequate - see findings |
| P6-PAR-011 | MON02 | Device list with status cards | Low | NONE | Adequate - see findings |
| P6-PAR-012 | MON03 | Device detail: identity, battery, enforcement, last seen | Low | NONE | Adequate - see findings |
| P6-PAR-013 | MON06 | Recent command history | Low | NONE | Adequate - see findings |
| P6-PAR-014 | USE01 | Daily usage history | Low | NONE | Adequate - see findings |
| P6-PAR-015 | USE02 | App usage breakdown | Low | NONE | Adequate - see findings |
| P6-PAR-016 | USE03 | Usage Access status and guidance | Medium | NONE | Adequate - see findings |
| P6-PAR-017 | USE05 | Daily screen-time limit configuration/save | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-018 | USE06 | Bedtime configuration and state | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-019 | USE07 | Remaining-time/limit-reached display | Low | NONE | Adequate - see findings |
| P6-PAR-020 | APP01 | Block selected apps | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-021 | APP02 | Block all except allowed list | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-022 | APP03 | Allowed-app list management | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-023 | APP04 | Per-app schedule windows | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-024 | APP06 | Request policy sync command | Medium | NONE | Adequate - see findings |
| P6-PAR-025 | LOC01 | Latest child location | Low | NONE | Adequate - see findings |
| P6-PAR-026 | LOC02 | 24-hour/7-day location history | Low | NONE | Adequate - see findings |
| P6-PAR-027 | LOC05 | Safe-zone create/edit/delete/active | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-028 | LOC10 | Alert list, severity filter, acknowledge | Medium | NONE | Adequate - see findings |
| P6-PAR-029 | REM01 | Parent requests audio/video session | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-030 | REM04 | Session history/status detail | Low | NONE | Adequate - see findings |
| P6-PAR-031 | AUD01 | Paginated audit log | Low | NONE | Adequate - see findings |
| P6-PAR-032 | AUD02 | Retention settings view/update | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for save. | Adequate - see findings |
| P6-PAR-033 | AUD03 | Purge old data | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-PAR-034 | SET01 | Local notification preference | Medium | NONE | Adequate - see findings |
| P6-PAR-035 | SET02 | Location-sharing reminder preference | Medium | NONE | Adequate - see findings |
| P6-CHD-001 | FAM05 | Child approves/declines pairing | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-CHD-002 | FAM06 | Child ID/contact ID and QR display | Low | NONE | Adequate - see findings |
| P6-CHD-003 | FAM07 | Child enrollment/device registration | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for re-registration. | Adequate - see findings |
| P6-CHD-004 | FAM11 | Child self-unlink | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-CHD-005 | USE04 | Child usage collection/upload | Medium | NONE | Adequate - see findings |
| P6-CHD-006 | USE08 | OS-level daily-limit enforcement | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. | Adequate - see findings |
| P6-CHD-007 | APP07 | OS app suspension | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. | Adequate - see findings |
| P6-CHD-008 | LOC03 | Child location-sharing toggle | Medium | NONE | Adequate - see findings |
| P6-CHD-009 | LOC04 | Child location tracking/upload | Low | NONE | Adequate - see findings |
| P6-CHD-010 | REM02 | Child accepts/declines remote session | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-CHD-011 | SET05 | Device-admin activation | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for activation. | Adequate - see findings |
| P6-CHD-012 | SET06 | Background-location settings launcher | Medium | NONE | Adequate - see findings |
| P6-CHD-013 | CHD01 | Child home summary | Low | NONE | Adequate - see findings |
| P6-CHD-014 | CHD02 | Rules/policy display | Low | NONE | Adequate - see findings |
| P6-CHD-015 | CHD03 | Pairing/assistance requests inbox | Low | NONE | Adequate - see findings |
| P6-CHD-016 | CHD04 | Guardian foreground service | Medium | NONE | Adequate - see findings |
| P6-CHD-017 | CHD05 | Camera/microphone self-test | Medium | NONE | Adequate - see findings |
| P6-CHD-018 | CHD06 | Native enforcement verification | Low | NONE | Adequate - see findings |
| P6-CHD-019 | CHD07 | Background sync retry | Medium | NONE | Adequate - see findings |
| P6-SHR-001 | A01 | Email/password sign-in | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for sign-out/sign-in. | Adequate - see findings |
| P6-SHR-002 | A02 | Account registration | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for account creation. | Adequate - see findings |
| P6-SHR-003 | A03 | Email verification, resend, refresh | Low | NONE | Adequate - see findings |
| P6-SHR-004 | A04 | Persisted session restore | Medium | NONE | Adequate - see findings |
| P6-SHR-005 | A05 | Sign out | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-SHR-006 | A06 | Role selection and initial role assignment | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for role change. | Adequate - see findings |
| P6-SHR-007 | A07 | Account/profile display | Low | NONE | Adequate - see findings |
| P6-SHR-008 | A08 | Account data export | Medium | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for export. | Adequate - see findings |
| P6-SHR-009 | A09 | Account deletion with confirmation | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-SHR-010 | A10 | Backend configuration/error screen | Low | NONE | Adequate - see findings |
| P6-SHR-011 | SET03 | App version display | Low | NONE | Adequate - see findings |
| P6-SHR-012 | SET04 | Runtime permission requests | Medium | NONE | Adequate - see findings |
| P6-SHR-013 | SYS01 | Offline detection and cached-state handling | Medium | NONE | Adequate - see findings |
| P6-SHR-014 | SYS02 | Manual and periodic refresh | Low | NONE | Adequate - see findings |
| P6-INT-001 | MON04 | Heartbeat-derived online/offline and last-seen status | Low | NONE | Adequate - see findings |
| P6-INT-002 | MON05 | Child permission summary | Low | NONE | Adequate - see findings |
| P6-INT-003 | MON07 | Installed-app snapshot | Low | NONE | Adequate - see findings |
| P6-INT-004 | APP05 | Enforcement acknowledgement and applied counts | Low | NONE | Adequate - see findings |
| P6-INT-005 | LOC06 | Geofence enter/exit alerts | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for induced movement. | Adequate - see findings |
| P6-INT-006 | LOC07 | Low-battery alerts | Medium | NONE | Adequate - see findings |
| P6-INT-007 | LOC08 | Offline alerts | Low | NONE | Adequate - see findings |
| P6-INT-008 | LOC09 | Permission-degradation alerts | Medium | NONE | Adequate - see findings |
| P6-INT-009 | REM03 | WebRTC audio/video session | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-INT-010 | REM05 | End session and cleanup | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate - see findings |
| P6-LIM-001 | MON04 | Heartbeat-derived online/offline and last-seen status | Destructive | BLOCKED — REQUIRES SEPARATE OWNER APPROVAL for reinstall/rotation. | Adequate - see findings |
| P6-LIM-002 | MON05 | Child permission summary | Low | NONE | Adequate - see findings |
| P6-LIM-003 | USE04 | Child usage collection/upload | Medium | NONE | Adequate - see findings |
| P6-LIM-004 | USE06 | Bedtime configuration and state | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for bedtime change. | Adequate - see findings |
| P6-LIM-005 | USE08 | OS-level daily-limit enforcement | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. | Adequate - see findings |
| P6-LIM-006 | APP07 | OS app suspension | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. | Adequate - see findings |
| P6-LIM-007 | LOC04 | Child location tracking/upload | Medium | NONE | Adequate - see findings |
| P6-UI-001 | SET01 | Local notification preference | Medium | NONE | Adequate - see findings |
| P6-UI-002 | SET02 | Location-sharing reminder preference | Medium | NONE | Adequate - see findings |
| P6-BEK-001 | FAM14 | Update family settings API | Low | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for write verification. | Adequate - see findings |
| P6-BEK-002 | AUD04 | Scheduled retention sweep | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for execution. | Adequate - see findings |
| P6-SEC-001 | SEC-001 | Password field exposes entered password in plaintext | High | OPEN SECURITY REVIEW — PROVISIONAL HIGH | Adequate - see findings |

## Specific quality findings

| Case(s) | Issue | Proposed documentation-only correction | Severity |
|---|---|---|---|
| P6-SHR-001 | Expected result mentions invalid credentials, but steps do not include an invalid-credential attempt | Add an explicit invalid-credential step that does not lock the account, or narrow the expected result | Medium |
| P6-INT-001, 005, 006, 007, 008, 009, 010 | No numeric observation window or polling cadence; “timeout” is qualitative | State the observation window, refresh cadence, and what delay is considered inconclusive | Medium |
| P6-SEC-001 | Does not explain how to reach Parent Sign-in while preserving the active session; gate is security review, not explicit session-change approval | Document a safe route that does not sign out, or add an explicit session-preservation approval gate | Medium |
| P6-PAR-004 | Conditional on a pending request; no fallback expected result if none exists | Split into empty-list observation and pending-request cancellation cases | Medium |
| P6-PAR-028 | Step says “if reversible and approved”; gate says NONE | Either add approval gate or remove the approval condition and restrict to reversible acknowledge | Medium |
| P6-CHD-016 | Step says restart “only if safe and approved”; gate says NONE | Add explicit approval gate or limit to read-only status observation | Medium |
| P6-SHR-014 | No backend-unavailable or error-state scenario | Add a read-only error/retry observation without changing backend | Medium |
| Multiple screens | Loading, empty, offline, and permission-denied states are not consistently represented | Add a small cross-cutting set of state checks for dashboard, devices, usage, location, alerts, audit, and child rules | Medium |
| P6-PAR-034/035 and P6-UI-001/002 | UI-only cases duplicate the same preference behavior | Retain as intentional function-level duplicate or consolidate in a future revision | Low |
| P6-PAR-005 | Create-family case cannot be executed positively while preserving the existing family | Keep blocked; explicitly label as guard-only observation | Low |

## Positive quality observations

- All 90 cases have unique IDs, objective, preconditions, test data, numbered steps, observable expected result, evidence, dependency, risk, approval gate, and cleanup/notes.
- Every case records `NOT EXECUTED` and `NOT TESTED`.
- High and Destructive cases have an approval or dependency gate.
- Known partial and UI-only limitations are represented rather than hidden.
- Backend-only cases prohibit write verification and deletion.

