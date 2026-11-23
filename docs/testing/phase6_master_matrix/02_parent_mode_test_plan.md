# 02 — Parent-Mode Test Plan

All cases are **NOT TESTED**; actual results are **NOT EXECUTED**. Full fields and steps are in `01_master_qa_test_matrix.md`.

## Coverage

| Measure | Count |
|---|---:|
| Parent-mode functionalities | 59 |
| Parent-only cases | 37 |
| Shared cases with Parent variant | 16 |
| Interconnected paired cases | 10 |
| Parent-side cross-cutting state cases | 2 |
| Parent-side planned cases | 65 |
| Backend-only parent-role capabilities | 2 (excluded; see 05) |

Parent-mode covered IDs: 35 parent-only + 14 shared + 10 interconnected = **59**. The 65 parent-side cases include two additional Parent-only correction cases, two shared correction cases, and two cross-cutting state cases; cases are not functionality IDs.

## Parent-only test cases (37)

| Case | Functionality ID | Functionality | Objective | Expected | Risk | Approval gate |
|---|---|---|---|---|---|---|
| P6-PAR-001 | FAM01 | Link child by QR scan | Validate scanner payload handling without submitting. | Non-pairing rejected; valid scheme recognized; no request created. | Medium | Send requires owner approval. |
| P6-PAR-002 | FAM02 | Link child by Child ID/linking code | Validate ID normalisation and validation without sending. | Malformed values rejected; no request sent. | Low | NONE |
| P6-PAR-003 | FAM03 | Send pairing request | Send one request and confirm pending state. | One pending request; no auto-link. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-004 | FAM04 | Pairing request list and cancel | Verify read-only list/empty observation. | List or explicit empty state; no cancellation. | Low | NONE; cancellation is P6-PAR-036 and gated. |
| P6-PAR-005 | FAM08 | Create family | Verify create-family guard when a family exists. | Existing membership preserved; no second family. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-006 | FAM09 | Family details, members, roles | Validate member roles and owner marker. | Members/roles match; owner marked. | Low | NONE |
| P6-PAR-007 | FAM10 | Unlink child account/device | Verify unlink safeguards without executing. | Destructive action labelled; cancel preserves link. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-008 | FAM12 | Revoke device | Verify revoke safeguards without executing. | Cancel preserves device. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-009 | FAM13 | Device recovery for lost/reinstalled phone | Verify recovery entry point without starting it. | No recovery on cancel; guidance clear. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-010 | MON01 | Family/dashboard overview | Validate identity, family context, summary cards. | Identity and family correct; refresh preserves context. | Low | NONE |
| P6-PAR-011 | MON02 | Device list with policy/status cards | Validate rows, status, last-seen, policy version. | Rows stable and consistent; no duplicates. | Low | NONE |
| P6-PAR-012 | MON03 | Device detail: identity, battery, enforcement, last seen | Validate detail fields and read-only actions. | Identity persists; unknown values explicit; no crash. | Low | NONE |
| P6-PAR-013 | MON06 | Recent command history | Validate command rendering and status. | Rows readable; statuses match backend. | Low | NONE |
| P6-PAR-014 | USE01 | Daily usage history | Validate daily totals and date scoping. | Totals numeric, stable, date-scoped. | Low | NONE |
| P6-PAR-015 | USE02 | App usage breakdown | Validate package labels and minutes. | Rows coherent; discrepancy recorded. | Low | NONE |
| P6-PAR-016 | USE03 | Usage Access status and guidance | Validate status and settings launcher without changing permission. | Correct status; settings opens; permission unchanged. | Medium | NONE |
| P6-PAR-017 | USE05 | Daily screen-time limit configuration/save | Validate save and reload with reversible value. | Value saves and reloads; restoration succeeds. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-018 | USE06 | Bedtime configuration and state | Validate configuration/display and known non-enforcement. | Window persists; no bedtime suspension; restoration succeeds. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-019 | USE07 | Remaining-time/limit-reached display | Validate remaining calculation and styling. | Remaining equals limit minus used within rounding. | Low | NONE |
| P6-PAR-020 | APP01 | Block selected apps | Validate selecting/saving one blocked app and restoring. | Rule saves; sync queued; restoration works. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-021 | APP02 | Block all except allowed list | Validate mode change and restoration. | Mode persists; restoration returns baseline. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-022 | APP03 | Allowed-app list management | Validate add/remove and restoration. | Changes explicit and persistent; baseline restored. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-023 | APP04 | Per-app schedule windows | Validate window create/edit and removal. | Window persists; edit applies; test data removed. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-024 | APP06 | Request policy sync command | Validate read-only existing command history/status. | Existing history/status only; no new command. | Low | NONE. |
| P6-PAR-025 | LOC01 | Latest child location | Validate latest location and freshness. | Latest or explicit stale/empty state; no fabricated fresh value. | Low | NONE |
| P6-PAR-026 | LOC02 | 24-hour/7-day location history | Validate range bounds and chronology. | Bounded chronological points; empty ranges explicit. | Low | NONE |
| P6-PAR-027 | LOC05 | Safe-zone create/edit/delete/active | Validate CRUD with synthetic reversible zone. | CRUD succeeds; delete audited; baseline restored. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-028 | LOC10 | Alert list, severity filter, acknowledge | Validate read-only filtering/detail. | Filter/detail correct; no state change. | Low | NONE; acknowledgement is P6-PAR-037 and gated. |
| P6-PAR-029 | REM01 | Parent requests audio/video session | Verify request and child consent gate. | One request; waits for consent; no unilateral media. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-030 | REM04 | Session history/status detail | Validate history and detail. | Rows match known sessions; no fabricated completion. | Low | NONE |
| P6-PAR-031 | AUD01 | Paginated audit log | Validate pagination and family scope. | No duplicate pages; fields coherent; family scoped. | Low | NONE |
| P6-PAR-032 | AUD02 | Retention settings view/update | Verify display and gated save. | Values shown; cancel leaves unchanged. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for save. |
| P6-PAR-033 | AUD03 | Purge old data | Verify purge safeguards without executing. | Destructive and confirmed; cancel performs no deletion. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-PAR-034 | SET01 | Local notification preference | Verify UI, persistence, and absent notification delivery. | Preference persists; no notification is scheduled or delivered. | Medium | NONE |
| P6-PAR-035 | SET02 | Location-sharing reminder preference | Verify UI, persistence, and absent reminder. | Preference persists; no reminder consumer. | Medium | NONE |
| P6-PAR-036 | FAM04 | Pairing request list and cancel | Verify cancellation only after explicit approval. | Only the approved request is cancelled; no other pairing state changes. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED. |
| P6-PAR-037 | LOC10 | Alert list, severity filter, acknowledge | Verify acknowledgement only after explicit approval. | Acknowledged state persists; other alerts unchanged. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED. |

## Parent-side shared scenarios (16)

Each shared case must be run on both roles; this table records the Parent-side expectation. Shared cases are not counted as parent-only.

| Case | Functionality ID | Functionality | Parent-side expected | Risk | Approval gate |
|---|---|---|---|---|---|
| P6-SHR-001 | A01 | Email/password sign-in | Read-only existing-session and identity observation; no sign-out/in. | Low | NONE for read-only; positive sign-in is BLOCKED — SEPARATE OWNER-APPROVED SESSION-SAFE STRATEGY REQUIRED. |
| P6-SHR-002 | A02 | Account registration | Safe validation; no account created. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for account creation. |
| P6-SHR-003 | A03 | Email verification, resend, refresh | Verified state correct; no email sent. | Low | NONE |
| P6-SHR-004 | A04 | Persisted session restore | Both restore authenticated without re-login. | Medium | NONE |
| P6-SHR-005 | A05 | Sign out | Read-only observation of the visible sign-out affordance; current session remains intact; no sign-out. | Low | NONE for read-only; behavioral sign-out validation is BLOCKED — SEPARATE ISOLATED AUTHENTICATION ENVIRONMENT AND EXPLICIT OWNER APPROVAL REQUIRED. |
| P6-SHR-006 | A06 | Role selection and initial role assignment | Existing role preserved. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for role change. |
| P6-SHR-007 | A07 | Account/profile display | Identity correct; no cross-account leak. | Low | NONE |
| P6-SHR-008 | A08 | Account data export | Truthful completion/failure; authorized data only. | Medium | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for export. |
| P6-SHR-009 | A09 | Account deletion with confirmation | Destructive and confirmed; cancel preserves account. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-SHR-010 | A10 | Backend configuration/error screen | No false error; guidance clear. | Low | NONE |
| P6-SHR-011 | SET03 | App version display | Version matches. | Low | NONE |
| P6-SHR-012 | SET04 | Runtime permission requests | Observe existing permission state/guidance; no prompt or change. | Low | NONE. |
| P6-SHR-013 | SYS01 | Offline detection and cached-state handling | Observe naturally occurring offline/cached state; no network change. | Low | BLOCKED — NATURAL OFFLINE CONDITION NOT OBSERVED if absent. |
| P6-SHR-014 | SYS02 | Manual and periodic refresh | No duplicates or context loss; successful refresh is truthful. | Low | NONE |
| P6-SHR-015 | A01 | Invalid-credential error handling | Generic safe error; no real account used; no lockout abuse. | High | BLOCKED — REQUIRES SEPARATE AUTHENTICATION TEST ENVIRONMENT APPROVAL. |
| P6-SHR-016 | SYS02 | Refresh with cached/backend/auth error | Success, cached, and error states distinguishable; retry truthful; otherwise INCONCLUSIVE. | Medium | BLOCKED — REQUIRES SEPARATE SAFE TEST ENVIRONMENT. |

## Parent–Child interconnected scenarios (10)

| Case | Functionality ID | Functionality | Parent observation | Child/backend dependency | Risk | Approval gate |
|---|---|---|---|---|---|---|
| P6-INT-001 | MON04 | Heartbeat-derived online/offline and last-seen status | Status matches heartbeat age; stale/Offline explained. | Both devices; backend; credential. | Low | NONE |
| P6-INT-002 | MON05 | Child permission summary | Summary matches; false positive confirmed/refuted. | Both devices; Android. | Low | NONE |
| P6-INT-003 | MON07 | Installed-app snapshot | Picker reflects uploaded snapshot; staleness visible. | Both devices; telemetry. | Low | NONE |
| P6-INT-004 | APP05 | Enforcement acknowledgement and applied counts | Counts match; failures visible; no false success. | Both devices; policy. | Low | NONE |
| P6-INT-005 | LOC06 | Geofence enter/exit alerts | One correct alert; dedupe behaves. | Both devices; location. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for induced movement. |
| P6-INT-006 | LOC07 | Low-battery alerts | Alert only under threshold; dedupe correct. | Both devices; backend. | Medium | NONE |
| P6-INT-007 | LOC08 | Offline alerts | Alert only after threshold; correct device. | Both devices; backend. | Low | NONE |
| P6-INT-008 | LOC09 | Permission-degradation alerts | Alert matches real report; no false alert accepted. | Both devices. | Medium | NONE |
| P6-INT-009 | REM03 | WebRTC audio/video session | Both join; no media without consent. | Both devices; signaling. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-INT-010 | REM05 | End session and cleanup | Both sides close; media services stop; terminal status. | Both devices; signaling. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |

## Cross-cutting Parent state cases (2)

| Case | Functionality IDs | Purpose | Risk | Approval gate |
|---|---|---|---|---|
| P6-STATE-001 | MON01; MON02; SYS01 | Observe naturally occurring loading, empty, cached, or stale parent states without forcing them | Low | NONE |
| P6-STATE-002 | FAM09; USE01; LOC01; LOC10; AUD01 | Observe empty, error, retry, or stale states in family, usage, location, alerts, and audit | Low | NONE |

These cases do not add functionality IDs; they add state coverage using existing data and conditions.

## Parent-mode notes

- High and Destructive cases require explicit owner approval; preparation is not permission.
- No Phase 6 case may sign out, replace, invalidate, or modify the preserved Parent or Child QA session. Sign-out execution is absolutely prohibited; read-only observation of the affordance is permitted. No approval gate may override this rule. Any future authentication test requiring a session change is BLOCKED pending a separately approved isolated environment that does not use the preserved QA accounts.
- Unlink, revoke, recover, clear data, and family/role changes remain approval-gated or prohibited by their individual cases.
- Parent screenshots must redact child coordinates, IDs, and personal data.
- `FAM14` and `AUD04` are backend-only and are not part of the 59 parent-mode accessible count.
- Parent-mode coverage is 35 parent-only + 14 shared + 10 interconnected = 59; every row is NOT TESTED.
