# 04 — Traceability and Count Reconciliation

## 1. Case count

`01_master_qa_test_matrix.md` case table begins at P6-PAR-001 (line 33) and ends at P6-STATE-003 (line 130). The sequence is contiguous, with no blank line inside the table. That is **98 case rows**.

The eight added cases are present:

- P6-PAR-036
- P6-PAR-037
- P6-CHD-020
- P6-SHR-015
- P6-SHR-016
- P6-STATE-001
- P6-STATE-002
- P6-STATE-003

No duplicate Test Case ID was found. No added case was lost.

## 2. Functionality ID reconciliation

`10_matrix_coverage_and_traceability.md` states 80 original IDs and 80 represented IDs. The role tables reconcile as:

| Group | Inventory count | Matrix count |
|---|---:|---:|
| Parent-only IDs | 35 | 35 |
| Child-only IDs | 19 | 19 |
| Shared IDs | 14 | 14 |
| Interconnected IDs | 10 | 10 |
| Backend-only IDs | 2 | 2 |
| Partial IDs (subset) | 7 | 7 |
| UI-only IDs (subset) | 2 | 2 |
| **Total unique** | **80** | **80** |

The 35 parent-only + 19 child-only + 14 shared + 10 interconnected = 78 accessible IDs; adding the 2 backend-only IDs gives 80. Partial and UI-only items are included within those role groups, not added again. This matches `docs/testing/functionality_inventory/06_functionality_count_summary.md`.

Absent capabilities M01–M10 are recorded separately in `06_absent_capability_gap_register.md`; they are not counted in the 80. SEC-001 is recorded separately in `07_security_and_approval_required_register.md`; it is not counted in the 80.

## 3. Case-type breakdown

| Case group | Count |
|---|---:|
| Parent-role cases | 39 |
| Child-role cases | 21 |
| Shared cases | 16 |
| Interconnected cases | 10 |
| Partial limitation cases | 7 |
| UI-only cases | 2 |
| Backend-only cases | 2 |
| Security case | 1 |
| **Total** | **98** |

The Parent-role count is 37 P6-PAR cases plus P6-STATE-001 and P6-STATE-002. The Child-role count is 20 P6-CHD cases plus P6-STATE-003. Shared is P6-SHR-001 through -016. Interconnected is P6-INT-001 through -010. Limitation is P6-LIM-001 through -007.

## 4. Status verification

All 98 rows carry:

- Actual Result: `NOT EXECUTED`
- Status: `NOT TESTED`

Static `IMPLEMENTED`, `PARTIAL`, `UI ONLY`, `BACKEND ONLY`, and `SECURITY ISSUE` classifications are inventory/matrix classifications only. No row presents a static implementation as runtime PASS.

## 5. Approval-register reconciliation

`07_security_and_approval_required_register.md` lists APR-01 through APR-14, exactly 14 scenarios. The matrix also has case-level gates. The register is explicitly described as a minimum category register, not blanket authorization and not exhaustive.

## 6. Traceability defects

- No missing functionality ID was found.
- No duplicate case ID was found.
- No untraceable case was found.
- **Documentation inconsistency:** `10_matrix_coverage_and_traceability.md`, `## Completion condition`, still says “The matrix is ready for second independent review, not execution.” This is stale after the third correction pass and third review. It does not affect case counts.

## 7. Conclusion

Counts reconcile to **98 cases / 80 IDs**. The traceability structure is intact. The only count-adjacent defect is the stale review-stage sentence in report 10, which is Low severity.
