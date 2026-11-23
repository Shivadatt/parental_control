# 04 — Shared and Interconnected Test Plan

All cases are **NOT TESTED**; actual results are **NOT EXECUTED**. Full fields and steps are in `01_master_qa_test_matrix.md`.

## Coverage

| Measure | Count |
|---|---:|
| Shared + interconnected unique functionalities | 24 |
| Shared | 14 |
| Parent–Child interconnected | 10 |
| Shared cases requiring both roles | 16 |
| Paired-device cases | 10 |

## Shared functionality (14 IDs / 16 cases)

Run each shared case independently on Parent (Pixel_9a) and Child (Realme). Identical UI does not imply identical permissions, persistence, or backend behavior.

| Case | Functionality ID | Functionality | Role variants | Expected | Risk | Approval gate |
|---|---|---|---|---|---|---|
| P6-SHR-001 | A01 | Email/password sign-in | Parent and Child separately | Read-only session/identity observation; no sign-out/in. | Low | NONE for read-only; positive sign-in is BLOCKED — SEPARATE OWNER-APPROVED SESSION-SAFE STRATEGY REQUIRED. |
| P6-SHR-002 | A02 | Account registration | Parent and Child separately | Safe validation; no account created. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for account creation. |
| P6-SHR-003 | A03 | Email verification, resend, refresh | Parent and Child separately | Verified state correct; no email sent. | Low | NONE |
| P6-SHR-004 | A04 | Persisted session restore | Parent and Child separately | Both restore authenticated without re-login. | Medium | NONE |
| P6-SHR-005 | A05 | Sign out | Parent and Child separately | Read-only observation of the visible sign-out affordance; current session remains intact; no sign-out. | Low | NONE for read-only; behavioral sign-out validation is BLOCKED — SEPARATE ISOLATED AUTHENTICATION ENVIRONMENT AND EXPLICIT OWNER APPROVAL REQUIRED. |
| P6-SHR-006 | A06 | Role selection and initial role assignment | Parent and Child separately | Existing role preserved. | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for role change. |
| P6-SHR-007 | A07 | Account/profile display | Parent and Child separately | Identity correct; no cross-account leak. | Low | NONE |
| P6-SHR-008 | A08 | Account data export | Parent and Child separately | Truthful completion/failure; authorized data only. | Medium | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for export. |
| P6-SHR-009 | A09 | Account deletion with confirmation | Parent and Child separately | Destructive and confirmed; cancel preserves account. | Destructive | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| P6-SHR-010 | A10 | Backend configuration/error screen | Parent and Child separately | No false error; guidance clear. | Low | NONE |
| P6-SHR-011 | SET03 | App version display | Parent and Child separately | Version matches. | Low | NONE |
| P6-SHR-012 | SET04 | Runtime permission requests | Parent and Child separately | Observe existing permission state/guidance; no prompt or change. | Low | NONE. |
| P6-SHR-013 | SYS01 | Offline detection and cached-state handling | Parent and Child separately | Observe naturally occurring offline/cached state; no network change. | Low | BLOCKED — NATURAL OFFLINE CONDITION NOT OBSERVED if absent. |
| P6-SHR-014 | SYS02 | Manual and periodic refresh | Parent and Child separately | No duplicates or context loss; successful refresh is truthful. | Low | NONE |
| P6-SHR-015 | A01 | Invalid-credential error handling | Parent and Child separately | Generic safe error; no real account used; no lockout/rate-limit abuse. | High | BLOCKED — REQUIRES SEPARATE AUTHENTICATION TEST ENVIRONMENT APPROVAL. |
| P6-SHR-016 | SYS02 | Refresh with cached/backend/auth error | Parent and Child separately | Success, cached, and error states distinguishable; retry truthful; otherwise INCONCLUSIVE. | Medium | BLOCKED — REQUIRES SEPARATE SAFE TEST ENVIRONMENT. |

## Parent–Child interconnected scenarios (10)

Each case requires both devices. A failure is only a synchronization defect when both independent baselines pass and the child is demonstrably online. Otherwise the result is blocked or inconclusive.

| Case | Functionality ID | Parent action | Child action | Expected backend/sync event | Parent observation | Child observation | Timeout / failure distinction | Evidence |
|---|---|---|---|---|---|---|---|---|
| P6-INT-001 | MON04 | Record presence and refresh | Leave heartbeat/service state unchanged | Heartbeat updates `last_seen_at` | Status matches heartbeat age | Service reports last heartbeat | If child offline and no fresh heartbeat, do not call it a sync defect | Both screenshots; redacted logs |
| P6-INT-002 | MON05 | Open permission summary | Open permission/status screen | Permission fields reported by telemetry | Summary matches child state | Child/system state is source of truth | System permission dump read-only; mismatch = known limitation, not automatic app failure | Both screenshots; system dump |
| P6-INT-003 | MON07 | Open app-restriction picker | Leave installed apps unchanged | Uploaded `device_apps` snapshot | Picker reflects snapshot | Installed list unchanged | If snapshot stale, distinguish upload failure from picker defect | Both screenshots; timestamp |
| P6-INT-004 | APP05 | Open enforcement evidence | Leave policy unchanged | Command ack/applied counts | Applied/failed counts visible | Native applied/suspended state visible | Do not change policy to force a result | Both screenshots; command evidence |
| P6-INT-005 | LOC06 | Observe Alerts after an approved transition | Generate movement only with approval | Location upload evaluates zone state; alert insert | Correct geofence alert appears | Zone state/transition visible | Do not induce movement without approval; absence without transition is not a failure | Both screenshots; payload |
| P6-INT-006 | LOC07 | Observe low-battery alert if present | Do not drain battery | Heartbeat evaluates threshold and dedupe | One correct alert | Battery/charging state visible | Do not force discharge; no alert above threshold is expected | Both screenshots; payload |
| P6-INT-007 | LOC08 | Observe offline alert if threshold exceeded | Do not disconnect intentionally | Sweep compares `last_seen_at` to threshold | Alert references correct device/threshold | Last heartbeat time visible | If child is online, absence is expected; do not force offline | Screenshot; payload |
| P6-INT-008 | LOC09 | Observe permission-degradation alerts | Do not revoke permissions | Heartbeat reports permission map | Alert matches real degradation | Permission state visible | No alert without degradation; do not manufacture degradation | Both screenshots; payload |
| P6-INT-009 | REM03 | Request session | Accept consent only with approval | Session signaling and consent state | Parent sees connected media state | Child sees active session | No media before consent; timeout alone is not proof of signaling defect | Both screenshots; logs |
| P6-INT-010 | REM05 | End session | Confirm child media stops | Session terminal state and service cleanup | Status closes | Audio/camera service stops | If parent ends but child remains active, capture both states before retry | Both screenshots; logs |

## Interconnected timing and outcome policy

The values below are **PROPOSED — OWNER REVIEW REQUIRED** and **PROVISIONAL QA OBSERVATION PARAMETERS — NOT APPLICATION SLAs**. They are proposed, not approved, not application SLAs, and not validated by runtime QA; owner acceptance or revision is pending. Source documentation establishes a five-minute heartbeat, a twelve-minute online window, a thirty-minute stalled window, and a fifteen-minute offline-alert sweep. These are planning references only; do not treat expiry as proof of product failure or as an approved test threshold.

| Case | Observation start | Maximum window | Poll/refresh cadence | Expected propagation | Delayed synchronization | INCONCLUSIVE when | Approval |
|---|---|---|---|---|---|---|---|
| P6-INT-001 | Both baselines pass and child heartbeat timestamp is recorded | 15 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 60 seconds | Next heartbeat within 5 minutes; presence within 12-minute online window | Fresh heartbeat missing beyond one 5-minute cycle but less than 12 minutes | 15 minutes elapse without evidence separating delay from failure | None |
| P6-INT-005 | Existing zone/transition state recorded; induced movement only with approval | 30 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 60 seconds | Next location upload or heartbeat reflects transition and creates one alert | Alert not visible after one upload cycle but within 15 minutes | 30 minutes elapse without transition evidence | Required for induced movement |
| P6-INT-006 | Battery and charging state recorded | 30 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 60 seconds | Next heartbeat evaluates threshold and dedupe | Alert not visible after one heartbeat cycle but within 15 minutes | 30 minutes elapse without threshold/dedupe evidence | None; do not drain battery |
| P6-INT-007 | Last heartbeat and alert state recorded | 30 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 60 seconds | Offline sweep after 15-minute threshold | Alert not visible after 15-minute sweep plus one refresh | 30 minutes elapse without stale/offline evidence | None; do not disconnect |
| P6-INT-008 | Permission map and existing alerts recorded | 30 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 60 seconds | Next heartbeat reports degradation and alert appears | Alert not visible after one heartbeat cycle but within 15 minutes | 30 minutes elapse without degradation evidence | None; do not revoke |
| P6-INT-009 | Parent request visible and child consent state recorded | 5 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 10 seconds | Signaling connects and both media states update | Media not connected after 60 seconds but before 5 minutes | 5 minutes elapse without signaling evidence | Required for session |
| P6-INT-010 | Active session and both media states recorded | 5 minutes — **PROPOSED — OWNER REVIEW REQUIRED** | 10 seconds | Terminal state propagates and child media stops | Child state not terminal after 60 seconds but before 5 minutes | 5 minutes elapse without terminal evidence | Required for session |

### Outcome distinctions

- **Child device offline** — no fresh child heartbeat/upload; parent-side absence is expected, not a synchronization defect.
- **Parent device offline** — parent cannot observe fresh data; result is blocked/inconclusive.
- **Backend unavailable** — both sides fail consistently; record backend dependency, not UI failure.
- **Authentication failure** — session invalid or unauthorized; do not classify as sync failure.
- **Device credential failure** — child upload rejected despite valid session; known MON04/LOC04/USE04 limitation.
- **Delayed synchronization** — expected event arrives after the normal cycle but within the maximum window; mark delayed, not FAIL.
- **Genuine functionality failure** — both baselines pass, child is online, expected event does not arrive within the maximum window, and evidence excludes the other causes.
- **Insufficient evidence** — none of the above can be separated; status **INCONCLUSIVE**.

## Notes

- Paired tests are **High** risk when they create sessions, induce movement, or alter persistent state.
- No case may sign out, replace, invalidate, or modify the preserved Parent or Child QA session. Sign-out execution is absolutely prohibited; read-only observation of the affordance is permitted. No approval gate may override this rule. Future authentication testing requiring a session change is BLOCKED pending a separately approved isolated environment.
- Do not change pairing, unlink, revoke, re-register, or credentials for any interconnected case.
- A Parent-only or Child-only failure must be resolved or blocked before treating a paired failure as synchronization evidence.
- Shared cases are counted once in the 80-item inventory even when executed on both roles.
