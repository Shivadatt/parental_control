# 04 — Traceability and Count Reconciliation

## Source comparison

Compared `01_complete_functionality_inventory.md` against `01_master_qa_test_matrix.md` and `10_matrix_coverage_and_traceability.md`.

| Check | Result |
|---|---|
| Original functionality IDs | 80 |
| Unique IDs in matrix | 80 |
| Missing IDs | 0 |
| Extra functionality IDs | 0 |
| SEC-001 counted as functionality | No |
| Absent M01–M10 counted as functionality | No |
| Role mismatches | 0 |
| Category mismatches | 0 |
| Classification mismatches | 0 |
| Exact-name mismatches | 0 |
| Case IDs | 98, all unique |
| Orphaned case references | 0 |
| Approval references unresolved | 0 |

## Verified ID distribution

| Group | IDs | Covered |
|---|---:|---:|
| Parent-only | 35 | 35 / 35 |
| Child-only | 19 | 19 / 19 |
| Shared | 14 | 14 / 14 |
| Interconnected | 10 | 10 / 10 |
| Backend-only | 2 | 2 / 2 |
| **Total** | **80** | **80 / 80** |

Classification totals remain: 69 IMPLEMENTED, 7 PARTIAL, 2 UI ONLY, 2 BACKEND ONLY, 0 PLANNED, 0 UNVERIFIED.

## Case-count reconciliation

The corrected documents claim and the actual rows support:

| Case group | Count |
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

Arithmetic: 39 + 21 + 16 + 10 + 7 + 2 + 2 + 1 = **98**.

This includes the eight added cases and excludes cross-listing duplication. The raw Role column contains 44 Parent, 25 Child, 12 Interconnected, and 16 Shared rows because limitation, UI-only, backend-only, and state cases reuse role labels; the case-type accounting above separates those groups.

## New cases and traceability

| Case | Inventory trace |
|---|---|
| P6-PAR-036 | FAM04 |
| P6-PAR-037 | LOC10 |
| P6-CHD-020 | CHD04 |
| P6-SHR-015 | A01 |
| P6-SHR-016 | SYS02 |
| P6-STATE-001 | MON01; MON02; SYS01 |
| P6-STATE-002 | FAM09; USE01; LOC01; LOC10; AUD01 |
| P6-STATE-003 | CHD01; CHD02; SYS01 |

State cases are cross-cutting and are not additional functionality IDs. They are documented as such in report 10.

## Split traceability

- `P6-PAR-004` → `P6-PAR-004` (list/empty) + `P6-PAR-036` (cancel). No ID reused.
- `P6-PAR-028` → `P6-PAR-028` (list/filter) + `P6-PAR-037` (acknowledge). No ID reused.
- `P6-CHD-016` → `P6-CHD-016` (read-only status) + `P6-CHD-020` (restart). No ID reused.

## Document inconsistencies

1. `12_post_correction_summary.md` says “L-03 names checked; abbreviations remain faithful,” while reports 01–03 now use exact names.
2. `12_post_correction_summary.md` says the six review reports remain unedited, but `git status` shows `AM docs/testing/phase6_master_matrix_review/04_security_and_approval_gate_audit.md`, indicating a working-tree change after staging.
3. `12_post_correction_summary.md` says “No review finding was left uncorrected,” but M-03, M-04, and I-03 remain partially corrected.
4. The master table has a blank line before the eight added rows, which may break Markdown rendering.

None of these changes the 80-ID traceability result. They are documentation-integrity defects.
