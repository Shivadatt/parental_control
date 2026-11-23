# 06 — New Findings and Recommendations

No corrections were applied. Each finding is documentation-only unless marked otherwise. Severity is not inflated: no Critical finding was identified.

## Severity summary

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 3 |
| Medium | 4 |
| Low | 1 |
| Informational | 1 |

## Findings

### N-01 — P6-SHR-001 still authorizes sign-out

- **Severity:** High
- **File/case:** `01_master_qa_test_matrix.md`, `02_parent_mode_test_plan.md`, `03_child_mode_test_plan.md`, `04_shared_and_interconnected_test_plan.md` — `P6-SHR-001`
- **Evidence:** Steps say “If approved, sign out and sign in with owner-entered credentials.” Gate is `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED for sign-out/sign-in`.
- **Impact:** Contradicts M-03’s requirement never to sign out the preserved Parent/Child accounts. Approval does not remove the absolute preservation rule.
- **Recommended correction:** Make `P6-SHR-001` read-only session/auth-state observation. Move valid sign-in to a separately blocked controlled-session test, or remove it until a safe strategy exists.
- **Owner decision:** Required.

### N-02 — P6-PAR-024 persistent sync command is ungated

- **Severity:** High
- **File/case:** `01_master_qa_test_matrix.md`, `02_parent_mode_test_plan.md` — `P6-PAR-024`
- **Evidence:** Risk `Medium`, Approval Gate `NONE`; steps “Tap Request sync once” and “One command queued.”
- **Impact:** Creates a persistent backend command. Section 7 of the review brief explicitly says this case must not authorize a persistent sync command without separate approval.
- **Recommended correction:** Convert to read-only command-history observation, or reclassify as High and add **BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED**.
- **Owner decision:** Required.

### N-03 — P6-SHR-012 permission prompt is not deny/dismiss-only

- **Severity:** High
- **File/case:** `01_master_qa_test_matrix.md`, `02_parent_mode_test_plan.md`, `03_child_mode_test_plan.md`, `04_shared_and_interconnected_test_plan.md` — `P6-SHR-012`
- **Evidence:** Steps say “Trigger a safe re-request” and “Dismiss/restore”; expected says “Correct permission; denial guidance.” Gate is NONE.
- **Impact:** May grant or alter runtime permission state in an unapproved test.
- **Recommended correction:** Restrict to existing permission-state observation, or explicitly require dismissal/denial and add a gate.
- **Owner decision:** Required.

### N-04 — M-02 values lack the required owner-review label

- **Severity:** Medium
- **File:** `04_shared_and_interconnected_test_plan.md`; also `01_master_qa_test_matrix.md`, `08_test_environment_and_dependency_register.md`
- **Evidence:** The values are labelled “PROVISIONAL QA OBSERVATION PARAMETERS — NOT APPLICATION SLAs,” not “PROPOSED — OWNER REVIEW REQUIRED.”
- **Impact:** A reader may treat the values as approved planning thresholds. The values are otherwise clearly described as provisional.
- **Recommended correction:** Add the exact owner-review label and state that values are not approved thresholds.
- **Owner decision:** Yes, to accept or revise the windows.

### N-05 — Post-correction summary makes inaccurate integrity claims

- **Severity:** Medium
- **File:** `12_post_correction_summary.md`; `11_correction_change_log.md`; `phase6_master_matrix_review/04_security_and_approval_gate_audit.md`
- **Evidence:** Report 12 says the six review reports remain unedited, but `git status` shows `AM` for review report 04. Report 12 also says L-03 abbreviations remain faithful, while reports 01–03 now use exact names. It claims no review finding was left uncorrected, while M-03/M-04/I-03 remain partial.
- **Impact:** The completion summary is not fully accurate; historical review integrity is unclear.
- **Recommended correction:** Correct the summary claims and document the review-report working-tree change; do not rewrite historical findings silently.
- **Owner decision:** Required for history/integrity acceptance.

### N-06 — P6-SHR-013 changes network state without a gate

- **Severity:** Medium
- **File/case:** `01_master_qa_test_matrix.md`, `02_parent_mode_test_plan.md`, `03_child_mode_test_plan.md`, `04_shared_and_interconnected_test_plan.md` — `P6-SHR-013`
- **Evidence:** Risk Medium, gate NONE; steps say “network toggle allowed” and “Disable network briefly.”
- **Impact:** Changes device network state; should be a future approved controlled-offline test or naturally occurring offline observation.
- **Recommended correction:** Add explicit approval or restrict to naturally occurring offline state.
- **Owner decision:** Required.

### N-07 — Master table formatting break

- **Severity:** Low
- **File:** `01_master_qa_test_matrix.md`
- **Evidence:** A blank line appears between `P6-SEC-001` and `P6-PAR-036`; the eight added rows follow without a table header.
- **Impact:** Markdown renderers may not display the added cases as table rows.
- **Recommended correction:** Remove the blank line so all 98 rows remain one table.
- **Owner decision:** No.

### N-08 — First-review path in the prompt does not match the repository

- **Severity:** Informational
- **File:** `08_test_environment_and_dependency_register.md` and review scope
- **Evidence:** First-review reports are actually under `docs/testing/phase6_master_matrix_review/`, not under `docs/testing/phase6_master_matrix/`.
- **Impact:** No document defect; the review brief’s path is inaccurate. This review used the actual path.
- **Recommended correction:** Document the actual path if a future brief references it.
- **Owner decision:** No.

## Required owner decisions

1. Whether valid sign-in can ever be tested without disturbing the preserved session.
2. Whether to gate or remove persistent sync-command and permission-prompt tests.
3. Whether controlled network toggling is approved.
4. Whether provisional observation windows are accepted.
5. How to treat the modified first-review report and the inaccurate summary claims.
6. Whether to authorize a third correction pass.

## Verdict

Because three High safety defects remain, the matrix is not ready for execution authorization. **SECOND REVIEW FAILED — CORRECTIONS REQUIRED.**
