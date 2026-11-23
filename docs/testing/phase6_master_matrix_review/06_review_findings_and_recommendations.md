# 06 — Review Findings and Recommendations

All findings are documentation issues. No runtime result is implied. Original matrix and inventory files were not edited.

## Severity summary

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 6 |
| Low | 3 |
| Informational | 3 |

## Medium findings

### M-01 — Full risk definitions are missing

- **Affected:** `01_master_qa_test_matrix.md`, `09_test_execution_order_and_qa_criteria.md`
- **Reason:** Cases use Low/Medium/High/Destructive, but the matrix does not state the required definitions.
- **Correction:** Add the four definitions to report 01 or 09.
- **Scope:** Documentation only; no test scope change.
- **Owner decision:** No, unless the owner wants different definitions.

### M-02 — Interconnected observation windows are qualitative

- **Affected:** `P6-INT-001`, `P6-INT-005`, `P6-INT-006`, `P6-INT-007`, `P6-INT-008`, `P6-INT-009`, `P6-INT-010`; `04_shared_and_interconnected_test_plan.md`
- **Reason:** “Timeout or observation strategy” is present as a concept, but no numeric window or polling cadence is defined. Delayed sync cannot be classified consistently.
- **Correction:** Add an observation window, refresh cadence, and inconclusive threshold to each paired case.
- **Scope:** Documentation only; may affect execution duration, not functionality scope.
- **Owner decision:** Yes, for acceptable wait thresholds.

### M-03 — Negative authentication and backend-error steps are incomplete

- **Affected:** `P6-SHR-001`, `P6-SHR-014`
- **Reason:** P6-SHR-001 expects an invalid-credential error but does not include an invalid attempt. P6-SHR-014 has no backend-unavailable observation.
- **Correction:** Add a safe invalid-credential step and a read-only backend-error/retry step.
- **Scope:** Documentation-only coverage improvement.
- **Owner decision:** No.

### M-04 — Loading, empty, offline, and permission-denied states are uneven

- **Affected:** Dashboard, devices, family, usage, location, alerts, audit, and child-rules cases; `P6-PAR-004` conditional empty-list path.
- **Reason:** SYS01/SET04/USE01 cover some states, but not consistently across screens. P6-PAR-004 has no fallback when no pending request exists.
- **Correction:** Add a small cross-cutting state-check set and split P6-PAR-004 into empty-list and cancellation observations.
- **Scope:** Documentation-only expansion; adds a few cases.
- **Owner decision:** No.

### M-05 — SEC-001 route and session-preservation ambiguity

- **Affected:** `P6-SEC-001`; `07_security_and_approval_required_register.md`
- **Reason:** Opening Parent Sign-in may require signing out, which is separately approval-gated. The case does not explain a safe route.
- **Correction:** Document a non-sign-out route, or add an explicit session-change approval gate.
- **Scope:** Documentation only; no security reproduction now.
- **Owner decision:** Yes, for any session change.

### M-06 — Approval-gate inconsistencies in two cases

- **Affected:** `P6-PAR-028`, `P6-CHD-016`
- **Reason:** Steps say “if approved” but the Approval Gate column says NONE. These actions are persistent/reversible but not explicitly gated.
- **Correction:** Add an approval gate or restrict the steps to read-only observation.
- **Scope:** Documentation only; may change execution eligibility.
- **Owner decision:** Yes, if approval is retained.

## Low findings

### L-01 — A10 category mismatch

- **Affected:** `01_master_qa_test_matrix.md`, `P6-SHR-010`
- **Reason:** Matrix says `Authentication`; inventory says `Account`.
- **Correction:** Change the matrix category to `Account`.
- **Scope:** Documentation only.
- **Owner decision:** No.

### L-02 — Report 05 count wording is ambiguous

- **Affected:** `05_partial_ui_backend_test_plan.md`
- **Reason:** “11 primary items + 7 limitation cases” is not a single numeric total.
- **Correction:** State 18 referenced cases or separate primary and limitation counts explicitly.
- **Scope:** Documentation only.
- **Owner decision:** No.

### L-03 — Three names are abbreviated

- **Affected:** `FAM13`, `MON02`, `REM02`
- **Reason:** Names are faithful but not identical to inventory.
- **Correction:** Use exact inventory names or mark them as shortened.
- **Scope:** Documentation only.
- **Owner decision:** No.

## Informational findings

### I-01 — UI-only cases are intentional duplicates

`P6-PAR-034/035` and `P6-UI-001/002` test the same preferences at function and cross-cutting levels. This is documented as intentional and adds little unique coverage.

### I-02 — Send-pairing request is not in the 14-scenario approval register

`P6-PAR-003` is individually gated, but the approval register lists cancellation/decline rather than request creation. Case-level gating is sufficient for safety.

### I-03 — Some high-risk writes are gated only at case level

Policy, retention, device-admin, and other high-risk writes are gated in their cases, but not every one appears in the 14-scenario register. Report 07’s policy note covers this; a future register could list them for completeness.

## Proposed correction order

1. M-01 and L-01 (definitions and classification) — no scope change.
2. M-06 and M-05 (safety gates) — before any execution approval.
3. M-03 and M-04 (coverage) — may add cases.
4. M-02 (timing) — owner decision.
5. L-02, L-03, and informational notes.

## Correction policy

Do not silently edit the original matrix. Apply corrections only after explicit owner authorization, and re-run traceability/safety checks afterward. No correction authorizes test execution.
