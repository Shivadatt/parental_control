# 06 — New Findings and Recommendations

## N-09 — Sign-out remains executable with an approval gate

**Severity: HIGH**

**References:**

- `docs/testing/phase6_master_matrix/01_master_qa_test_matrix.md`, P6-SHR-005: steps “Sign out only with approval”; expected “session clears”; cleanup “Re-authenticate via owner.”
- `docs/testing/phase6_master_matrix/02_parent_mode_test_plan.md`, P6-SHR-005 and “Parent-mode notes.”
- `docs/testing/phase6_master_matrix/03_child_mode_test_plan.md`, P6-SHR-005.
- `docs/testing/phase6_master_matrix/04_shared_and_interconnected_test_plan.md`, P6-SHR-005.
- `docs/testing/phase6_master_matrix/07_security_and_approval_required_register.md`, section 3.
- `docs/testing/phase6_master_matrix/08_test_environment_and_dependency_register.md`, section 3.
- `docs/testing/phase6_master_matrix/10_matrix_coverage_and_traceability.md`, A05 row.

**Evidence:** The case explicitly clears the session and requires re-authentication. The approval policy states that session-changing actions may be approved. The environment register lists sign-out as merely “prohibited without approval.”

**Why it matters:** The review requirement is absolute: no approval gate may permit sign-out. The current Parent session is the Run 8 baseline and the precondition for most matrix cases. A documentation path that authorizes session destruction is unsafe even if not executed today.

**Required correction:**

1. Convert P6-SHR-005 to a read-only observation of the sign-out control and confirmation dialog. Do not confirm, do not clear the session, and do not re-authenticate.
2. Remove “session clears” and “Re-authenticate via owner” from all four plans.
3. Change report 02’s note to an absolute prohibition: no case may sign out.
4. Change report 07’s policy to exclude sessions from approval-authorized changes.
5. Change report 08’s table to list sign-out as absolutely prohibited, not “prohibited without approval.”
6. Add the correction to report 11 and report 12.

**Blocks execution authorization: YES.**

## N-10 — Correction log overstates N-01 closure

**Severity: MEDIUM**

**References:**

- `docs/testing/phase6_master_matrix/11_correction_change_log.md`, `## Third correction pass`, N-01 row: “State after third pass: Corrected.”
- `docs/testing/phase6_master_matrix/12_post_correction_summary.md`, `## 5a`: states P6-SHR-001 is read-only but does not disclose P6-SHR-005.

**Evidence:** N-01 required removal of all sign-out/sign-in instructions and absolute session preservation across the matrix. P6-SHR-005 and the policy wording still authorize sign-out.

**Why it matters:** The correction log is an audit record. Marking N-01 fully corrected when a destructive path remains creates a false closure and can mislead the next reviewer or owner.

**Required correction:** Mark N-01 partially corrected until N-09 is fixed; record the P6-SHR-005 and policy changes; do not claim global correction based only on P6-SHR-001.

**Blocks execution authorization: YES, indirectly, because it conceals N-09.**

## N-11 — Stale review-stage statement in traceability report

**Severity: LOW**

**Reference:** `docs/testing/phase6_master_matrix/10_matrix_coverage_and_traceability.md`, `## Completion condition`: “The matrix is ready for second independent review, not execution.”

**Evidence:** The third correction pass and third review have occurred.

**Why it matters:** It is a stale document-state statement, not a safety defect. It can confuse the next reviewer about which review stage is current.

**Required correction:** Replace with “ready for the next independent documentation review” or the current review stage.

**Blocks execution authorization: NO.**

## N-12 — Correction-pass chronology is inconsistent

**Severity: LOW**

**Reference:** `docs/testing/phase6_master_matrix/11_correction_change_log.md`, heading `## Third correction pass — 2026-11-21`.

**Evidence:** The first and second review reports are dated `2026-11-23`. The third correction pass cannot precede the second review it responds to if those dates are accurate.

**Why it matters:** It undermines audit chronology and makes it harder to establish which document state was reviewed. It does not create an executable safety path.

**Required correction:** Correct the date or state explicitly that the date is a draft/logical date and not a chronological execution date.

**Blocks execution authorization: NO.**

## N-13 — P6-CHD-019 retry action is ambiguous

**Severity: INFORMATIONAL**

**Reference:** `docs/testing/phase6_master_matrix/01_master_qa_test_matrix.md`, P6-CHD-019: “Trigger retry once”; Risk Medium; Approval Gate `NONE`.

**Evidence:** The case performs a background sync retry. It is not clearly stated whether the retry is idempotent, whether it can create a backend command, or whether it can change identity. The expected result says “no credential/registration change,” but the action itself is not described as read-only.

**Why it matters:** This is not a confirmed destructive action; it is an ambiguity. It should be clarified before execution so a retry cannot be mistaken for authorization to create persistent state.

**Required correction:** State that the retry is idempotent, does not create a policy command, does not rotate credentials, and does not change registration. If any of those cannot be guaranteed, gate the case.

**Blocks execution authorization: NO.**

## Earlier findings status

| Finding | Status |
|---|---|
| M-01 Risk definitions | VERIFIED CORRECTED |
| M-02 Observation windows | VERIFIED CORRECTED |
| M-03 Auth/backend negatives and session safety | **PARTIALLY CORRECTED** — negative coverage is present, but session safety fails via N-09 |
| M-04 State coverage | VERIFIED CORRECTED |
| M-05 SEC-001 safe route | VERIFIED CORRECTED |
| M-06 Split read-only/action cases | VERIFIED CORRECTED |
| L-01 A10 category | VERIFIED CORRECTED |
| L-02 Report 05 count wording | VERIFIED CORRECTED |
| L-03 Exact names | VERIFIED CORRECTED |
| I-01 UI duplicates | VERIFIED |
| I-02 Register vs case gates | VERIFIED |
| I-03 High-risk writes gated | VERIFIED, with N-09 caveat for sessions |

## Recommendation

Do not authorize runtime QA. Correct N-09 first, then N-10, N-11, N-12, and clarify N-13. After those documentation changes, request a fourth independent review. No owner approval for execution should be inferred from the third correction pass or this review.
