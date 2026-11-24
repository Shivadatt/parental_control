# 02 — Phase 2.1 Discrepancy Reconciliation Plan

**Document ID:** `HAVEN-GOV-002`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Audited Input:** `docs/testing/phase2_1_independent_verification/09_cross_document_discrepancy_register.md`  
**Audit Standard:** Actionable, Evidence-Based Discrepancy Resolution Plan  
**Execution Posture:** STRICTLY READ-ONLY — PROPOSED CORRECTIONS PREPARED AS DOCUMENTATION ONLY  

---

## 1. Governance Protocol for Document Modifications

In strict compliance with the Phase 2.2 read-only governance standard, **no existing Phase 2 or Phase 2.1 documents have been modified**.

This document outlines the **exact text, table, and metric corrections** required to resolve all 8 discrepancies identified in Phase 2.1. These corrections are presented for formal Product Owner review and will be applied to the master records upon owner authorization.

---

## 2. Master Discrepancy Resolution Register

```
+----------------------------------------------------------------------------------------------------+
|                                 DISCREPANCY RESOLUTION SUMMARY                                     |
|  Total Tracked Findings: 8                                                                         |
|  - VERIFIED & RESOLUTION PLANNED: 8 (100.0%)                                                       |
|  - UNRESOLVED / BLOCKED:          0 (  0.0%)                                                       |
+----------------------------------------------------------------------------------------------------+
```

---

### DISC-01: Staging Environment Non-Existence & Decision 4 Revision
- **Finding ID**: `DISC-01`
- **Verified Status**: `VERIFIED`
- **Severity**: `CRITICAL`
- **Evidence**: `docs/backend.md:327` (*"No staging project exists: the only project reachable by this workstation's CLI login is `irlqctcddjmkwqdvsdsm`, while the app targets `hhqgreaoqulmfwfwarhc`. The owner directed on 2026-10-27 that the reviewed change set be deployed to that existing production project and that no second project be created."*)
- **Flaw Description**: Phase 2 recommended Decision 4: *"DESIGNATE Staging Supabase Environment as the authoritative execution target"*, assuming a staging project was operational. In reality, no staging project exists.
- **Execution Risk if Uncorrected**: Testers attempt to configure nonexistent credentials, or worse, execute destructive tests against the production project `hhqgreaoqulmfwfwarhc` believing it is staging.
- **Proposed Correction**:  
  Revoke Decision 4 as drafted. Replace with a neutral choice between **Pathway A (Provision Staging)** and **Pathway B (In-Project QA Quarantine)**.
- **Owner Approval Needed**: YES (Decision B in Phase 2.2 Owner Framework).

---

### DISC-02: Consolidated Test Case Suite Sizing Ambiguity ("85+" vs 99)
- **Finding ID**: `DISC-02`
- **Verified Status**: `VERIFIED`
- **Severity**: `HIGH`
- **Evidence**: `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md` (41 headings) and `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md` (58 headings).
- **Flaw Description**: Phase 2 repeatedly claimed "85 Master Test Cases" and "85+" based on an obsolete $35 + 50 = 85$ estimate, under-counting the actual suite by 14 test cases.
- **Execution Risk if Uncorrected**: Distorts QA resource planning, duration estimation, and coverage tracking.
- **Proposed Correction**:  
  Update all summary tables in `01_phase2_executive_summary.md`, `10_test_safety_and_prerequisite_register.md`, and `12_phase2_final_coverage_and_owner_readiness.md` to state:  
  **`Consolidated Master Manual Test Suite: 99 Unique Test Cases`** (41 Baseline + 58 Expansion).
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-03: Four Valid Test Cases Omitted from Execution Roadmap
- **Finding ID**: `DISC-03`
- **Verified Status**: `VERIFIED`
- **Severity**: `HIGH`
- **Evidence**: Cross-reference between `05_additional_manual_test_cases.md`, `08_manual_test_case_master_list.md`, and `11_final_testing_execution_roadmap.md`.
- **Flaw Description**: Four fully specified, valid test cases were omitted from the 7-phase roadmap:
  1. `TC-MON04` (Heartbeat Presence Transmission)
  2. `TC-EXP-23` (Installed Apps Snapshot Upload)
  3. `TC-EXP-49` (Notification Preferences Toggle)
  4. `TC-EXP-50` (Location Reminder Interval Dropdown)
- **Execution Risk if Uncorrected**: Testers following the roadmap will skip 4 critical capabilities.
- **Proposed Correction**:  
  Incorporate the 4 missing test cases into `11_final_testing_execution_roadmap.md`:
  - Add `TC-EXP-49` to **Phase 3.2** (Authentication & Account Lifecycle).
  - Add `TC-EXP-23` to **Phase 3.4** (Parent Monitoring, Screen Time & Rules).
  - Add `TC-MON04` and `TC-EXP-50` to **Phase 3.5** (Geospatial Safe Zones & Telemetry).
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-04: Specialist Tests Severely Under-Reported in Safety Register
- **Finding ID**: `DISC-04`
- **Verified Status**: `VERIFIED`
- **Severity**: `HIGH`
- **Evidence**: `05_additional_manual_test_cases.md` defines 12 specialist tests, and baseline defines 4 specialist tests (`TC-REM01`, `TC-CHD04`, `TC-SET05`, `TC-APP07`).
- **Flaw Description**: `10_test_safety_and_prerequisite_register.md` claimed only 5 `SPECIALIST_TEST` cases (5.9%), when the true count across the 99-test suite is **16 (16.2%)**.
- **Execution Risk if Uncorrected**: Test bench setup underestimates the need for hardware WebRTC benches, mock GPS injection, and ADB Device Owner provisioning.
- **Proposed Correction**:  
  Update `10_test_safety_and_prerequisite_register.md:25` table to the reconciled 99-test distribution:
  - `SAFE`: **46 (46.5%)**
  - `SAFE_REVERSIBLE`: **16 (16.2%)**
  - `REQUIRES_DISPOSABLE_ACCOUNT`: **8 (8.1%)**
  - `REQUIRES_DISPOSABLE_DEVICE`: **7 (7.1%)**
  - `REQUIRES_ISOLATED_BACKEND`: **6 (6.1%)**
  - `SPECIALIST_TEST`: **16 (16.2%)**
  - **Total**: **99 (100.0%)**
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-05: Baseline Quality Classification Arithmetic Error (6 vs 7 Incomplete)
- **Finding ID**: `DISC-05`
- **Verified Status**: `VERIFIED`
- **Severity**: `MEDIUM`
- **Evidence**: `docs/testing/phase2_coverage_gap_audit/02_existing_35_test_case_quality_audit.md` prose explicitly names 7 incomplete test cases (`TC-A06`, `TC-A01`, `TC-A02`, `TC-A08`, `TC-FAM07`, `TC-APP02`, `TC-REM01`), but §3 table stated 29 COMPLETE, 6 INCOMPLETE (Total: 35).
- **Flaw Description**: Arithmetic error in summary table omitted `TC-REM01` from the INCOMPLETE count.
- **Execution Risk if Uncorrected**: Internal mathematical inconsistency ($29 + 6 = 35$ while 7 are named).
- **Proposed Correction**:  
  Update summary table in `02_existing_35_test_case_quality_audit.md:520` to:  
  - Full Baseline (41 Tests): **34 `COMPLETE` (82.9%) \| 7 `INCOMPLETE` (17.1%) \| Total: 41**.  
  - Core Baseline (35 Tests): **28 `COMPLETE` (80.0%) \| 7 `INCOMPLETE` (20.0%) \| Total: 35**.
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-06: Phantom Test Case Reference `TC-FAM11` in Roadmap
- **Finding ID**: `DISC-06`
- **Verified Status**: `VERIFIED`
- **Severity**: `MEDIUM`
- **Evidence**: `11_final_testing_execution_roadmap.md:165` cites `5. TC-FAM11 / TC-EXP-16: Child Self-Unlink Prevention and Parent PIN Challenge (FAM11)`.
- **Flaw Description**: `TC-FAM11` does not exist in any file. The only test case for this feature is `TC-EXP-16`.
- **Execution Risk if Uncorrected**: Testers waste time searching for a non-existent baseline test case.
- **Proposed Correction**:  
  Amend line in `11_final_testing_execution_roadmap.md` to:  
  `5. TC-EXP-16: Child Self-Unlink Prevention and Parent PIN Challenge (FAM11)`.
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-07: `TC-SEC01` Omitted from Row `A01` of Traceability Matrix
- **Finding ID**: `DISC-07`
- **Verified Status**: `VERIFIED`
- **Severity**: `MEDIUM`
- **Evidence**: `03_functionality_to_test_case_traceability_matrix.md:31` mapped only `TC-A01` and `TC-EXP-02` in row `A01`, omitting baseline test `TC-SEC01` (`08_manual_test_case_master_list.md:792`).
- **Flaw Description**: Text cell omission caused unique test case count in the table to appear as 98 instead of 99.
- **Execution Risk if Uncorrected**: RLS tenant boundary verification is disconnected from authentication traceability.
- **Proposed Correction**:  
  Amend row `A01` of `03_functionality_to_test_case_traceability_matrix.md` to:  
  `| **A01** | Email & Password Sign-In | Auth | Shared | Implemented | TC-A01, TC-SEC01 | TC-EXP-02 | Complete | SAFE | lib/features/auth/login_controller.dart:65 |`
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

### DISC-08: Expansion Suite Authoring Count Under-Reported (50 vs 58)
- **Finding ID**: `DISC-08`
- **Verified Status**: `VERIFIED`
- **Severity**: `LOW`
- **Evidence**: `05_additional_manual_test_cases.md` defines 58 sequential test cases (`TC-EXP-01` through `TC-EXP-58`).
- **Flaw Description**: `01_phase2_executive_summary.md:38` claimed 50 new test cases were authored.
- **Execution Risk if Uncorrected**: Minor documentation under-count.
- **Proposed Correction**:  
  Update prose in `01_phase2_executive_summary.md` and related summaries to state:  
  *"Phase 2 designed and authored 58 new comprehensive manual test cases (TC-EXP-01 through TC-EXP-58)."*
- **Owner Approval Needed**: YES (Decision A in Phase 2.2 Owner Framework).

---

## 3. Implementation Plan for Owner Approval

Upon Product Owner authorization of **Decision A**, the QA team will apply these documented text corrections across the Phase 2 reports as a single, verified documentation update pass.
