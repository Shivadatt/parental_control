# Phase 2.5 — Canonical Phase 2.1 Discrepancy Register

**Document ID:** `HAVEN-GOV-PHASE2-5-DISC`  
**Phase:** Phase 2.5 — Final Governance Traceability & Owner Authorization Consistency Audit  
**Workspace:** `D:\parentcontrol_app`  
**Audited Baseline:** `docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md`  
**Audit Standard:** Authoritative Historical Restoration & Epistemological Verification  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Executive Purpose & Governance Obligation

The primary governance mandate of Phase 2.5 is to restore and permanently freeze the **exact original Phase 2.1 discrepancy definitions** (`DISC-01` through `DISC-08`).

### 1.1 The Scrambling Problem
In Phase 2.1 deliverable `09_cross_document_discrepancy_register.md`, eight clear discrepancies were identified. However, in Phase 2.2 deliverables `01_phase2_2_executive_summary.md` and `12_phase2_2_final_governance_closure.md`, these findings were scrambled and renumbered:
- `DISC-01` was changed from *"Staging environment non-existence"* to *"Baseline count ambiguity (35 vs 41)"*.
- `DISC-03` was changed from *"Four omitted roadmap test cases"* to *"Coverage metric inconsistency (100% vs 92.4%)"*.
- `DISC-07` was changed from *"Missing TC-SEC01 mapping"* to *"Non-existent Staging target"*.
- Three valid findings (`DISC-03` omitted roadmap tests, `DISC-06` phantom TC-FAM11, and `DISC-07` missing TC-SEC01) were dropped from Phase 2.2 summary tables.

Phase 2.5 permanently invalidates the scrambled numbering and restores the **canonical Phase 2.1 definitions**.

---

## 2. Canonical Phase 2.1 Discrepancy Master Table

```
+----------------------------------------------------------------------------------------------------+
|                               CANONICAL PHASE 2.1 DISCREPANCY REGISTER                             |
| Source: docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md   |
+----------------------------------------------------------------------------------------------------+
| ID      | Severity | Canonical Finding Title & Definition                                          |
+---------+----------+-------------------------------------------------------------------------------+
| DISC-01 | CRITICAL | Staging environment non-existence (Decision 4 unapproved target designation)  |
| DISC-02 | HIGH     | 85+ vs 99 test count ambiguity (Consolidated suite sizing miscalculation)     |
| DISC-03 | HIGH     | Four valid test cases omitted from execution roadmap                          |
| DISC-04 | HIGH     | Safety classification count mismatch (Specialist tests severely under-reported)|
| DISC-05 | MEDIUM   | Baseline test quality count mismatch (6 vs 7 incomplete arithmetic error)     |
| DISC-06 | MEDIUM   | Phantom TC-FAM11 reference in roadmap text                                    |
| DISC-07 | MEDIUM   | TC-SEC01 omitted from 92-row functional traceability mapping                  |
| DISC-08 | LOW      | Expansion test count under-reported (50 vs 58 authored expansion tests)       |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Detailed Forensic Verification of Original Definitions

### DISC-01: Designation of Non-Existent Staging Supabase Project
- **Canonical ID**: `DISC-01` (Restored namespace: `P2-DISC-01`)
- **Severity**: `CRITICAL`
- **Source Location**: [09_cross_document_discrepancy_register.md:39–51](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L39-L51)
- **Original Claim**: Phase 2 Executive Summary (§3.2, §5) designated a staging Supabase project (`STAGE_SUPABASE_URL`) as the execution sandbox for Phase 3 testing.
- **Source Verification**: [docs/backend.md:327–332](file:///d:/parentcontrol_app/docs/backend.md#L327-L332) proves that **no staging project exists**. The workstation CLI is authenticated only to `irlqctcddjmkwqdvsdsm`, the app targets production `hhqgreaoqulmfwfwarhc`, and the Owner directed on 2026-10-27 that no second project be created.
- **Operational Risk**: Testers might execute destructive tests (`TC-EXP-47`, `TC-A09`, `TC-EXP-17`) against live production believing it to be a sandbox.
- **Phase 2.2 Handling**: Correctly cited in Deliverable 02 (§2), but scrambled to `DISC-07` in Deliverables 01 & 12.
- **Phase 2.3 Status**: Verified; Decision 4 formally revoked in planning.
- **Final Status**: **`CLOSED — SOURCE VERIFIED`**

---

### DISC-02: Consolidated Test Case Suite Sizing Ambiguity ("85+" vs 99)
- **Canonical ID**: `DISC-02` (Restored namespace: `P2-DISC-02`)
- **Severity**: `HIGH`
- **Source Location**: [09_cross_document_discrepancy_register.md:54–68](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L54-L68)
- **Original Claim**: Phase 2 repeatedly claimed "85 Master Test Cases" and "85+ Consolidated Test Cases" based on an obsolete $35 + 50 = 85$ formula.
- **Source Verification**: Machine parsing of `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md` proves 41 baseline test cases. Machine parsing of `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md` proves 58 expansion test cases. True total is $41 + 58 = 99$.
- **Operational Risk**: Severe distortion of QA staffing, timeline, and coverage metrics.
- **Phase 2.2 Handling**: Maintained as `DISC-02` across Deliverables 01, 02, and 12.
- **Phase 2.3 Status**: Verified; master suite locked at 99 unique test cases.
- **Final Status**: **`CLOSED — SOURCE VERIFIED`**

---

### DISC-03: Four Valid Test Cases Omitted from Execution Roadmap
- **Canonical ID**: `DISC-03` (Restored namespace: `P2-DISC-03`)
- **Severity**: `HIGH`
- **Source Location**: [09_cross_document_discrepancy_register.md:71–85](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L71-L85)
- **Original Claim**: Phase 2 claimed the 7-phase execution roadmap covered 100% of the manual test suite.
- **Source Verification**: Cross-referencing `11_final_testing_execution_roadmap.md` against test definitions revealed four omitted test cases:
  1. `TC-MON04` (*Background Heartbeat Presence Transmission*)
  2. `TC-EXP-23` (*Native Installed Applications List Snapshot*)
  3. `TC-EXP-49` (*Local Notification Preferences Toggle*)
  4. `TC-EXP-50` (*Location Reminder Frequency Preference*)
- **Operational Risk**: Testers following the roadmap sequentially would miss four critical capabilities.
- **Phase 2.2 Handling**: Deliverable 02 mapped them in planning (`TC-EXP-49` to Phase 3.2, `TC-EXP-23` to Phase 3.4, `TC-MON04` and `TC-EXP-50` to Phase 3.5). However, Deliverables 01 & 12 dropped `DISC-03` from summary tables.
- **Phase 2.3 Status**: Partially closed; mapping planned, but `11_final_...md` unedited due to read-only constraints.
- **Final Status**: **`PARTIALLY RESOLVED`** (Pending physical documentation update upon Owner approval).

---

### DISC-04: Specialist Tests Severely Under-Reported in Safety Register
- **Canonical ID**: `DISC-04` (Restored namespace: `P2-DISC-04`)
- **Severity**: `HIGH`
- **Source Location**: [09_cross_document_discrepancy_register.md:88–99](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L88-L99)
- **Original Claim**: Phase 2 safety register reported only 5 `SPECIALIST_TEST` cases (5.9%).
- **Source Verification**: `05_additional_manual_test_cases.md` defines 12 specialist tests, and baseline defines 4 (`TC-REM01`, `TC-CHD04`, `TC-SET05`, `TC-APP07`). True count is **16 (16.2%)** across the 99-test suite.
- **Operational Risk**: Under-provisioning of specialized hardware benches (camera/microphone testbeds, GPS injection, ADB Device Owner stations).
- **Phase 2.2 Handling**: Correctly planned in Deliverable 02 (§2), but scrambled to `DISC-05` in Deliverables 01 & 12.
- **Phase 2.3 Status**: Verified and reconciled across Deliverables 03, 05, and 07.
- **Final Status**: **`CLOSED — SOURCE VERIFIED`**

---

### DISC-05: Baseline Quality Classification Arithmetic Error (6 vs 7 Incomplete)
- **Canonical ID**: `DISC-05` (Restored namespace: `P2-DISC-05`)
- **Severity**: `MEDIUM`
- **Source Location**: [09_cross_document_discrepancy_register.md:102–114](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L102-L114)
- **Original Claim**: Phase 2 claimed 29 `COMPLETE` and 6 `INCOMPLETE` (Total: 35).
- **Source Verification**: [02_existing_35_test_case_quality_audit.md](file:///d:/parentcontrol_app/docs/testing/phase2_coverage_gap_audit/02_existing_35_test_case_quality_audit.md) explicitly names 7 incomplete test cases (`TC-A06`, `TC-A01`, `TC-A02`, `TC-A08`, `TC-FAM07`, `TC-APP02`, `TC-REM01`). Across all 41 baseline tests, the correct distribution is 34 `COMPLETE` and 7 `INCOMPLETE`.
- **Operational Risk**: Mathematical inconsistency undermines confidence in audit metrics.
- **Phase 2.2 Handling**: Correctly resolved in Deliverable 02 (§2), but scrambled to `DISC-01` in Deliverables 01 & 12.
- **Phase 2.3 Status**: Verified; arithmetic corrected in planning records.
- **Final Status**: **`CLOSED — DOCUMENTATION CORRECTION`**

---

### DISC-06: Phantom Test Case Reference `TC-FAM11` in Roadmap
- **Canonical ID**: `DISC-06` (Restored namespace: `P2-DISC-06`)
- **Severity**: `MEDIUM`
- **Source Location**: [09_cross_document_discrepancy_register.md:117–127](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L117-L127)
- **Original Claim**: Roadmap Step 5 cited `TC-FAM11 / TC-EXP-16`.
- **Source Verification**: AST/text search of `08_manual_test_case_master_list.md` confirms `TC-FAM11` does not exist; the baseline family tests end at `TC-FAM10`. `TC-EXP-16` is the sole valid test case.
- **Operational Risk**: Testers searching for nonexistent test case `TC-FAM11`.
- **Phase 2.2 Handling**: Correctly addressed in Deliverable 02 (§2), but omitted from Deliverables 01 & 12 summary tables.
- **Phase 2.3 Status**: Verified; confirmed phantom reference.
- **Final Status**: **`CLOSED — SOURCE VERIFIED`**

---

### DISC-07: `TC-SEC01` Omitted from 92-Row Traceability Table
- **Canonical ID**: `DISC-07` (Restored namespace: `P2-DISC-07`)
- **Severity**: `MEDIUM`
- **Source Location**: [09_cross_document_discrepancy_register.md:130–141](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L130-L141)
- **Original Claim**: Row `A01` in `03_functionality_to_test_case_traceability_matrix.md` mapped only `TC-A01` and `TC-EXP-02`, resulting in an apparent total of 98 unique mapped tests instead of 99.
- **Source Verification**: Baseline test `TC-SEC01` (`08_manual_test_case_master_list.md:792`) was omitted from row `A01`'s text cell.
- **Operational Risk**: Apparent deficit in security test coverage and test mapping totals.
- **Phase 2.2 Handling**: Corrected in Deliverable 02 (§2), but scrambled to `DISC-03` in Deliverables 01 & 12.
- **Phase 2.3 Status**: Verified; restored to planning matrix.
- **Final Status**: **`CLOSED — DOCUMENTATION CORRECTION`**

---

### DISC-08: Expansion Suite Authoring Count Under-Reported (50 vs 58)
- **Canonical ID**: `DISC-08` (Restored namespace: `P2-DISC-08`)
- **Severity**: `LOW`
- **Source Location**: [09_cross_document_discrepancy_register.md:143–155](file:///d:/parentcontrol_app/docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md#L143-L155)
- **Original Claim**: Phase 2 Executive Summary claimed 50 new expansion test cases (`TC-EXP-01` through `TC-EXP-50`).
- **Source Verification**: [05_additional_manual_test_cases.md](file:///d:/parentcontrol_app/docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md) authored exactly **58 sequential test cases** (`TC-EXP-01` through `TC-EXP-58`).
- **Operational Risk**: Typographical under-count creating cross-document discrepancy.
- **Phase 2.2 Handling**: Corrected in Deliverable 02 (§2), but scrambled to `DISC-04` in Deliverables 01 & 12.
- **Phase 2.3 Status**: Verified; 58 expansion test cases confirmed.
- **Final Status**: **`CLOSED — SOURCE VERIFIED`**

---

## 4. Historical Integrity Conclusion

By restoring the exact original definitions from `09_cross_document_discrepancy_register.md`, Phase 2.5 establishes complete historical continuity. The Phase 2.2 scrambling defect is permanently documented and rendered harmless.
