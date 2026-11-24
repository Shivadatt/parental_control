# 09 — Cross-Document Discrepancy Register

**Document ID:** `HAVEN-VER-009`  
**Phase:** Phase 2.1 — Independent Consistency & Coverage Verification  
**Workspace:** `D:\parentcontrol_app`  
**Audit Standard:** Comprehensive Adversarial Cross-Document Discrepancy Register  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Register Overview & Severity Taxonomy

This register catalogs all contradictions, mathematical errors, omissions, and architectural discrepancies identified across the 12 deliverables in `docs/testing/phase2_coverage_gap_audit/`.

### Severity Taxonomy:
- **`CRITICAL`**: Severe architectural contradiction that could cause data loss, environment corruption, or immediate operational failure if acted upon.
- **`HIGH`**: Missing test cases, suite sizing ambiguities, or substantial reporting inaccuracies that distort QA planning.
- **`MEDIUM`**: Mathematical miscalculations, table formatting omissions, or phantom test case references that do not block execution but introduce confusion.
- **`LOW`**: Minor typographical under-counts or informational discrepancies that have zero operational impact.

---

## 2. Master Discrepancy Register

```
+----------------------------------------------------------------------------------------------------+
|                                    PHASE 2 DISCREPANCY REGISTER                                    |
|                                                                                                    |
|  Total Identified Discrepancies: 8                                                                 |
|  - CRITICAL:    1 (12.5%)                                                                          |
|  - HIGH:        3 (37.5%)                                                                          |
|  - MEDIUM:      3 (37.5%)                                                                          |
|  - LOW:         1 (12.5%)                                                                          |
+----------------------------------------------------------------------------------------------------+
```

---

### DISC-01: Designation of Non-Existent Staging Supabase Project
- **Finding ID**: `DISC-01`
- **Severity**: `CRITICAL`
- **Affected Documents**:
  - `01_phase2_executive_summary.md` (§3.2, §5)
  - `10_test_safety_and_prerequisite_register.md` (§2.1, §4)
  - `12_phase2_final_coverage_and_owner_readiness.md` (§5, Decision 4)
- **Claimed Value**: Staging Supabase project is the designated target (`STAGE_SUPABASE_URL`) for Phase 3 execution and isolated destructive testing.
- **Verified Value**: **NO STAGING PROJECT EXISTS.** `docs/backend.md:327` confirms that the only CLI-reachable project is `irlqctcddjmkwqdvsdsm`, the app targets production `hhqgreaoqulmfwfwarhc`, and the owner directed that no second project be created.
- **Evidence**: `docs/backend.md:327–332`.
- **Operational Risk**: Testers may execute destructive tests (`TC-EXP-47`, `TC-A09`, `TC-FAM10`, `TC-EXP-17`) against the live production database believing it is a safe staging sandbox.
- **Required Correction**: Revoke Decision 4. The owner must choose between **Pathway A (Provision Real Staging)** or **Pathway B (In-Project QA Quarantine)**.

---

### DISC-02: Consolidated Test Case Suite Sizing Ambiguity ("85+" vs 99)
- **Finding ID**: `DISC-02`
- **Severity**: `HIGH`
- **Affected Documents**:
  - `01_phase2_executive_summary.md` (Table 2.3, §3.1)
  - `02_existing_35_test_case_quality_audit.md` (Title, §3)
  - `10_test_safety_and_prerequisite_register.md` (§2)
  - `11_final_testing_execution_roadmap.md` (§1)
  - `12_phase2_final_coverage_and_owner_readiness.md` (§2.2)
- **Claimed Value**: "85 Master Test Cases" / "85+ Consolidated Test Cases" (based on 35 Baseline + 50 Expansion = 85).
- **Verified Value**: **99 UNIQUE TEST CASES** (41 Baseline Test Cases + 58 Expansion Test Cases).
- **Evidence**: Automated parsing of `08_manual_test_case_master_list.md` (41 test headings) and `05_additional_manual_test_cases.md` (58 test headings).
- **Operational Risk**: Sizing ambiguity creates confusion in QA staffing, duration estimation, and test tracking.
- **Required Correction**: Formally amend all summary documents to reflect the exact integer **99 Unique Test Cases**.

---

### DISC-03: Four Valid Test Cases Omitted from Execution Roadmap
- **Finding ID**: `DISC-03`
- **Severity**: `HIGH`
- **Affected Documents**:
  - `11_final_testing_execution_roadmap.md` (§2)
- **Claimed Value**: Roadmap covers the full manual testing suite across 7 phases.
- **Verified Value**: **Four valid test cases were omitted from all roadmap phases**:
  1. `TC-MON04` (*Background Heartbeat Presence Transmission*)
  2. `TC-EXP-23` (*Native Installed Applications List Snapshot*)
  3. `TC-EXP-49` (*Local Notification Preferences Toggle*)
  4. `TC-EXP-50` (*Location Reminder Frequency Preference*)
- **Evidence**: Cross-reference between `05_additional_manual_test_cases.md`, `08_manual_test_case_master_list.md`, and `11_final_testing_execution_roadmap.md`.
- **Operational Risk**: Testers following the roadmap sequentially will miss 4 valid capabilities.
- **Required Correction**: Assign `TC-MON04` to Phase 3.5, `TC-EXP-23` to Phase 3.4, `TC-EXP-49` to Phase 3.2, and `TC-EXP-50` to Phase 3.5.

---

### DISC-04: Specialist Tests Severely Under-Reported in Safety Register
- **Finding ID**: `DISC-04`
- **Severity**: `HIGH`
- **Affected Documents**:
  - `10_test_safety_and_prerequisite_register.md` (§2, §2.1)
  - `01_phase2_executive_summary.md` (§3.2)
- **Claimed Value**: `SPECIALIST_TEST` count = **5 (5.9%)** across the suite.
- **Verified Value**: **16 SPECIALIST_TEST cases (16.2%)** across the 99-test suite (4 baseline + 12 expansion).
- **Evidence**: `05_additional_manual_test_cases.md` defines 12 specialist tests (`TC-EXP-07`, `08`, `23`, `27`, `28`, `31`, `37`, `44`, `45`, `52`, `53`, `55`), and baseline defines 4 (`TC-REM01`, `TC-CHD04`, `TC-SET05`, `TC-APP07`).
- **Operational Risk**: QA staffing underestimates the need for hardware benches (camera/mic, mock GPS, ADB Device Owner provisioning), leading to test execution blockages.
- **Required Correction**: Reconcile safety table to reflect: `SPECIALIST_TEST = 16`, `SAFE = 46`, `SAFE_REVERSIBLE = 16`, `REQUIRES_DISPOSABLE_ACCOUNT = 8`, `REQUIRES_DISPOSABLE_DEVICE = 7`, `REQUIRES_ISOLATED_BACKEND = 6` (Total: 99).

---

### DISC-05: Baseline Quality Classification Arithmetic Error (6 vs 7 Incomplete)
- **Finding ID**: `DISC-05`
- **Severity**: `MEDIUM`
- **Affected Documents**:
  - `02_existing_35_test_case_quality_audit.md` (§3)
  - `01_phase2_executive_summary.md` (Table 2.3)
  - `12_phase2_final_coverage_and_owner_readiness.md` (§2.2)
- **Claimed Value**: 29 `COMPLETE` and 6 `INCOMPLETE` (Total: 35).
- **Verified Value**: **7 INCOMPLETE test cases** are explicitly named in the prose (`TC-A06`, `TC-A01`, `TC-A02`, `TC-A08`, `TC-FAM07`, `TC-APP02`, `TC-REM01`). Across all 41 baseline tests, **34 are COMPLETE and 7 are INCOMPLETE** (or across the first 35 core tests, 28 are COMPLETE and 7 are INCOMPLETE).
- **Evidence**: `02_existing_35_test_case_quality_audit.md` prose inspection.
- **Operational Risk**: Internal table math does not balance ($29 + 6 = 35$ while 7 are named).
- **Required Correction**: Correct summary table to: 34 `COMPLETE`, 7 `INCOMPLETE`, Total: 41.

---

### DISC-06: Phantom Test Case Reference `TC-FAM11` in Roadmap
- **Finding ID**: `DISC-06`
- **Severity**: `MEDIUM`
- **Affected Documents**:
  - `11_final_testing_execution_roadmap.md` (§2.7, Step 5)
- **Claimed Value**: Step 5 cites: `TC-FAM11 / TC-EXP-16: Child Self-Unlink Prevention and Parent PIN Challenge (FAM11)`.
- **Verified Value**: `TC-FAM11` does NOT exist in `08_manual_test_case_master_list.md`. The only test case for this functionality is `TC-EXP-16`.
- **Evidence**: `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md` contains only `TC-FAM10`.
- **Operational Risk**: Testers look for non-existent baseline test `TC-FAM11`.
- **Required Correction**: Remove `TC-FAM11 /` prefix and reference `TC-EXP-16` alone.

---

### DISC-07: `TC-SEC01` Omitted from 92-Row Traceability Table
- **Finding ID**: `DISC-07`
- **Severity**: `MEDIUM`
- **Affected Documents**:
  - `03_functionality_to_test_case_traceability_matrix.md` (§2, Row `A01`)
- **Claimed Value**: Row `A01` maps `TC-A01` and `TC-EXP-02`. Total unique test cases mapped = 98.
- **Verified Value**: Baseline test `TC-SEC01` (`08_manual_test_case_master_list.md:792`) was omitted from row `A01`'s text cell, causing unique mapped tests to appear as 98 instead of 99.
- **Evidence**: `03_functionality_to_test_case_traceability_matrix.md:31`.
- **Operational Risk**: Disconnect between security test inventory and functional traceability.
- **Required Correction**: Add `TC-SEC01` to row `A01` in the traceability table.

---

### DISC-08: Expansion Suite Authoring Count Under-Reported (50 vs 58)
- **Finding ID**: `DISC-08`
- **Severity**: `LOW`
- **Affected Documents**:
  - `01_phase2_executive_summary.md` (§2.2)
- **Claimed Value**: Phase 2 claims to have authored "50 new comprehensive manual test cases (TC-EXP-01 through TC-EXP-50)".
- **Verified Value**: Phase 2 actually authored **58 manual test cases** (`TC-EXP-01` through `TC-EXP-58`).
- **Evidence**: `05_additional_manual_test_cases.md` defines 58 sequential test cases.
- **Operational Risk**: Low. Under-reports the thoroughness of the expansion suite.
- **Required Correction**: Update executive summary prose to state 58 expansion test cases.

---

## 3. Discrepancy Synthesis & Governance Conclusion

None of the 8 discrepancies invalidate the underlying quality of the test specifications or the fact that 100% specification coverage was achieved. However, because `DISC-01` (Staging Environment Non-Existence) and `DISC-02` (Suite Sizing) directly impact execution planning and backend safety, **these 8 findings must be formally presented to the Product Owner for conditional sign-off**.
