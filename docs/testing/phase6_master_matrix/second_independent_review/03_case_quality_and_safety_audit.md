# 03 — Case Quality and Safety Audit

## Scope

- 98 planned cases in `01_master_qa_test_matrix.md`.
- 8 new cases.
- 3 split relationships.
- 7 partial, 2 UI-only, 2 backend-only, 1 security.
- All cases checked for status, actual result, role, risk, gate, evidence, and unsafe action language.

## Count verification

| Case type | Count |
|---|---:|
| Parent-role | 39 |
| Child-role | 21 |
| Shared | 16 |
| Interconnected | 10 |
| Partial limitation | 7 |
| UI-only | 2 |
| Backend-only | 2 |
| Security | 1 |
| **Total** | **98** |

All 98 rows show `NOT EXECUTED` and `NOT TESTED`. No PASS, FAIL, or runtime evidence is claimed.

## New cases

| Case | Purpose | Role | Risk | Gate | Quality |
|---|---|---|---|---|---|
| P6-PAR-036 | Gated pairing cancellation | Parent | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate; explicit cancellation only |
| P6-PAR-037 | Gated alert acknowledgement | Parent | High | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate; persistent state acknowledged |
| P6-CHD-020 | Gated guardian service restart | Child | Medium | BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED | Adequate; no battery-optimization change |
| P6-SHR-015 | Isolated invalid-credential test | Shared | High | BLOCKED — REQUIRES SEPARATE AUTHENTICATION TEST ENVIRONMENT APPROVAL | Adequate; synthetic only |
| P6-SHR-016 | Backend/auth error refresh | Shared | Medium | BLOCKED — REQUIRES SEPARATE SAFE TEST ENVIRONMENT | Adequate; no forced outage |
| P6-STATE-001 | Parent loading/empty/cached states | Parent | Low | NONE | Adequate; no forced state |
| P6-STATE-002 | Parent empty/error/retry states | Parent | Low | NONE | Adequate; read-only |
| P6-STATE-003 | Child permission/offline/error states | Child | Low | NONE | Adequate; no permission/network change |

## Split cases

- `P6-PAR-004` preserves the list/empty observation; cancellation moved to `P6-PAR-036`. No ID reused.
- `P6-PAR-028` preserves read-only alert filtering; acknowledgement moved to `P6-PAR-037`. No ID reused.
- `P6-CHD-016` preserves read-only service status; restart moved to `P6-CHD-020`. No ID reused.

The split cases do not silently remove the original behaviours; each new case references the same inventory ID.

## Safety defects found

### 1. P6-SHR-001—sign-out instruction contradicts preservation requirement

**High.** The case says: “If approved, sign out and sign in with owner-entered credentials.” M-03 required that the existing Parent/Child accounts never be signed out. The approval gate does not cure an absolute prohibition. The case should be read-only session observation, with valid sign-in separately blocked or removed until an owner-approved session strategy exists.

### 2. P6-PAR-024—persistent sync command has no gate

**High.** The case records risk `Medium`, Approval Gate `NONE`, and steps “Tap Request sync once” and “One command queued.” This writes a persistent backend command. Section 7 of the review brief explicitly says this case must not authorize execution of a persistent sync command. It should be read-only history observation, or gated as an approval-required persistent action.

### 3. P6-SHR-012—permission prompt not explicitly dismiss/deny-only

**High/Medium.** The case says “Trigger a safe re-request” and expects “Correct permission; denial guidance.” It does not explicitly instruct denial/dismissal and has no gate. This could change Android permission state in an unapproved test. It should observe existing permission state only or explicitly require dismissal/denial.

### 4. P6-SHR-013—network toggle remains executable

**Medium.** The case still says “network toggle allowed” and “Disable network briefly,” risk Medium, gate NONE. This is a controlled offline test, but it changes device network state. It should be explicitly future-owner-approved or converted to naturally occurring offline observation.

### 5. Master table formatting break

**Low.** A blank line appears between `P6-SEC-001` and `P6-PAR-036` in `01_master_qa_test_matrix.md`. The eight added rows follow without a table header, so Markdown renderers may show them as plain text rather than table rows. Data is present, but presentation is defective.

## Read-only split cases verified

`P6-PAR-028` and `P6-CHD-016` contain no action authorization; both explicitly say not to acknowledge/restart. The gated variants are separate. `P6-SEC-001` is blocked and does not instruct sign-out.

## Evidence and status

- All cases have evidence requirements and dependencies.
- All new cases are unexecuted.
- No case contains a real password, token, or secret.
- No case was executed during this review.
