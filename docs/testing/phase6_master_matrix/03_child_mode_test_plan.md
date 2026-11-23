# 03 — Child-Mode Test Plan

All cases are **NOT TESTED**; actual results are **NOT EXECUTED**. Full fields and steps are in `01_master_qa_test_matrix.md`.

## Coverage

| Measure | Count |
|---|---:|
| Child-mode functionalities | 43 |
| Child-only cases | 20 |
| Shared cases with Child variant | 16 |
| Interconnected paired cases | 10 |
| Child-side cross-cutting state cases | 1 |
| Child-side planned cases | 47 |

Child-mode covered IDs: 19 child-only + 14 shared + 10 interconnected = **43**. The 47 child-side cases include one additional Child-only correction case, two shared correction cases, and one cross-cutting state case; cases are not functionality IDs.

## Child-only test cases (20)

| Case | Functionality ID | Functionality | Objective | Expected | Risk | Approval gate |
|---|---|---|---|---|---|---|
| P6-CHD-001 | FAM05 | Child approves/declines pairing | Verify request display and gated response. | Request explained; response explicit; no auto-accept. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-CHD-002 | FAM06 | Child ID/contact ID and QR display | Validate ID/QR display and non-secret content. | ID stable; QR documented; no credential exposed. | Low | NONE |
| P6-CHD-003 | FAM07 | Child enrollment/device registration | Verify existing identity mapping without re-registering. | Identity matches existing row; no new registration. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for re-registration. |
| P6-CHD-004 | FAM11 | Child self-unlink | Verify self-unlink safeguards without executing. | Warning clear; cancel preserves link. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-CHD-005 | USE04 | Child usage collection/upload | Observe collection and last successful upload. | Current consistent data or documented credential failure; no fabricated total. | Medium | NONE |
| P6-CHD-006 | USE08 | OS-level daily-limit enforcement | Verify enforcement mode and quota state. | Mode accurately disclosed; limitation explicit. | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. |
| P6-CHD-007 | APP07 | OS app suspension | Verify suspension state and Device Owner dependency. | Suspension matches capability; no false success without Device Owner. | High | BLOCKED — DEPENDENCY NOT VERIFIED if Device Owner absent. |
| P6-CHD-008 | LOC03 | Child location-sharing toggle | Validate toggle controls service and restore state. | Toggle controls actual service; baseline restored. | Medium | NONE |
| P6-CHD-009 | LOC04 | Child location tracking/upload | Observe service and last upload. | Truthful status; no fresh location claimed on failure. | Low | NONE |
| P6-CHD-010 | REM02 | Child accepts/declines session | Verify informed consent prompt. | Consent explicit; decline prevents media. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-CHD-011 | SET05 | Device-admin activation | Verify status and activation entry point without activating. | Status accurate; no change. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for activation. |
| P6-CHD-012 | SET06 | Background-location settings launcher | Validate settings launcher without changing permission. | Correct page opens; permission unchanged. | Medium | NONE |
| P6-CHD-013 | CHD01 | Child home summary | Validate summary and navigation. | Summary matches; tabs load; no role confusion. | Low | NONE |
| P6-CHD-014 | CHD02 | Rules/policy display | Validate policy fields and refresh. | Matches parent policy; stale state explicit. | Low | NONE |
| P6-CHD-015 | CHD03 | Pairing/assistance requests inbox | Validate empty and populated inbox states. | Coherent inbox; no expired actionable items. | Low | NONE |
| P6-CHD-016 | CHD04 | Guardian foreground service | Observe guardian service state read-only. | Reported state truthful; no restart or stop. | Low | NONE; restart is P6-CHD-020 and gated. |
| P6-CHD-017 | CHD05 | Camera/microphone self-test | Validate media self-test without retaining media. | Permission/capture reported truthfully; no media retained. | Medium | NONE |
| P6-CHD-018 | CHD06 | Native enforcement verification | Validate applied/suspended counts against policy. | Actual state reported; mismatch visible. | Low | NONE |
| P6-CHD-019 | CHD07 | Background sync retry | Observe existing retry/status information read-only; do not trigger retry. | Existing status only; no service or permission change. | Low | NONE for read-only; behavioral retry validation is BLOCKED — RETRY IDEMPOTENCY AND PERSISTENCE SEMANTICS NOT VERIFIED. |
| P6-CHD-020 | CHD04 | Guardian foreground service | Verify restart only after explicit approval. | Service returns without identity loss; state truthful. | Medium | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED. |

## Child-side shared scenarios (16)

Each shared case must be run on both roles. Child-side expectations can differ in permission prompts, navigation, and available settings.

| Case | Functionality ID | Functionality | Child-side expected | Risk | Approval gate |
|---|---|---|---|---|---|
| P6-SHR-001 | A01 | Email/password sign-in | Read-only session/identity observation; no sign-out/in. | Low | NONE for read-only; positive sign-in is BLOCKED — SEPARATE OWNER-APPROVED SESSION-SAFE STRATEGY REQUIRED. |
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

| Case | Functionality ID | Functionality | Child-side observation | Parent/backend dependency | Risk | Approval gate |
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

## Cross-cutting Child state case (1)

| Case | Functionality IDs | Purpose | Risk | Approval gate |
|---|---|---|---|---|
| P6-STATE-003 | CHD01; CHD02; SYS01 | Observe naturally occurring permission-denied, offline, cached, or error states without changing permissions or network | Low | NONE |

## Child-mode notes

- No test may reinstall, clear data, reset secure storage, re-register, or rotate credentials.
- No Phase 6 case may sign out, replace, invalidate, or modify the preserved Parent or Child QA session. Sign-out execution is absolutely prohibited; read-only observation of the affordance is permitted. No approval gate may override this rule. Future authentication testing requiring a session change is BLOCKED pending a separately approved isolated environment.
- Device Owner scenarios remain blocked if Device Owner is absent; do not provision the device.
- Child screenshots must redact Child ID, installation IDs, coordinates, and personal content.
- Known partials: USE04, USE08, APP07, LOC04; limitation cases are in `05_partial_ui_backend_test_plan.md`.
- Child-mode coverage is 19 child-only + 14 shared + 10 interconnected = 43; every row is NOT TESTED.
