# HAVEN PARENT CONTROL — PHASE 2.7.2 DELIVERABLE 06
# PREREQ-18 FINAL CLASSIFICATION & BATCH DEPENDENCY REASSESSMENT

**Document ID:** `HAVEN-GOV-PHASE2-7-2-PREREQ18-DECISION`  
**Phase:** Phase 2.7.2 — Android Permission Capability & Migration Dependency Final Evidence Audit  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Database Dependency Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Runtime Execution:** PROHIBITED  
**Phase 3 Authorization:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Scope

In Phase 2.7.1 Deliverable 03, the operational rule for `PREREQ-18` (*Database Migration Clean-Apply Replay & Schema Verification*) was articulated at a broad batch level:
> *"PREREQ-18 is DEFERRABLE for Batches 1 through 4 under Pathway B if the existing schema is operational, but MANDATORY PRIOR TO TESTING under fresh infrastructure pathways (Pathway A or C) and before executing Batches 5 and 6 across all pathways."*

This audit report evaluates that formulation against the test-case-level data established in Deliverable 05 across all 99 manual test cases. It determines whether broad batch-level boundaries accurately reflect technical reality or whether they risk causing unexpected test failures.

---

## 2. Quantitative Distribution by Safety Tier and Batch

The 99 test cases are partitioned across six sequential execution batches corresponding to the six primary safety tiers:

```
====================================================================================================
               CROSS-TABULATION: EXECUTION BATCH vs MIGRATION CLASS (M0–M4)
====================================================================================================
Batch / Safety Category                  Total    M0 (No DB)   M1 (Exist)   M2 (Static)  M3 (Replay)  M4 (Runtime)
----------------------------------------------------------------------------------------------------
Batch 1: SAFE (Read-Only)                 45          16           29           0            0            0
Batch 2: SAFE_REVERSIBLE (Local Settings) 17           2           15           0            0            0
Batch 3: REQUIRES_DISPOSABLE_ACCOUNT       8           0            6           0            0            2
Batch 4: REQUIRES_DISPOSABLE_DEVICE        9           2            5           0            2            0
Batch 5: REQUIRES_ISOLATED_BACKEND         6           0            1           1            2            2
Batch 6: SPECIALIST_TEST                  14           6            7           0            0            1
----------------------------------------------------------------------------------------------------
TOTAL MASTER TEST SUITE                   99          26           61           1            4            7
====================================================================================================
```

### 2.1 Critical Test-Level Insight: Batch 1 is Not Schema-Free
In previous audits, it was informally assumed that Batch 1 (Safe Read-Only) had no database dependency. The granular audit in Deliverable 05 disproves this assumption:
- **16 of the 45 Batch 1 tests** are truly **`M0`** (No Database Dependency), running entirely client-side via UI rendering, local form validation, offline detection, or preferences.
- However, **29 of the 45 Batch 1 tests** are **`M1`** (Existing Schema Required). They are read-only dashboard screens, chart views, alert lists, telemetry summaries, and audit log tables that actively query Supabase tables (`profiles`, `devices`, `telemetry`, `usage_daily`, `locations`, `alerts`, `audit_logs`).
- **Conclusion**: If the backend database schema were missing or corrupted, **64.4% of Batch 1 would fail immediately**. 

### 2.2 Analysis of Batch 2 (Safe Reversible)
- **2 of 17 tests** are `M0` (local client-side toggles).
- **15 of 17 tests** are `M1` (persisting reversible settings to `families`, `policies`, or `devices`).

### 2.3 Analysis of Batch 3 (Disposable Accounts)
- **6 of 8 tests** are `M1` (standard authentication and onboarding flows).
- **2 of 8 tests** are `M4` (`TC-A08` GDPR export and `TC-A09` account deletion cascade).

### 2.4 Analysis of Batch 4 (Disposable Devices)
- **2 of 9 tests** are `M0` (Android foreground notification and Device Admin activation dialog).
- **5 of 9 tests** are `M1` (device registration, telemetry, and background tracking).
- **2 of 9 tests** are `M3` (`TC-EXP-17` device revocation and `TC-EXP-18` child record orphan cleanup, which require a clean unpolluted state to verify cascading record deletion).

### 2.5 Analysis of Batch 5 (Isolated Backend)
- **1 of 6 tests** is `M1` (`TC-EXP-19` family settings API).
- **1 of 6 tests** is `M2` (`TC-EXP-48` static SQL retention sweep review).
- **2 of 6 tests** are `M3` (`TC-SEC01` multi-tenant RLS isolation and `TC-SEC02` pairing token replay attack resistance, requiring a fresh unpolluted database).
- **2 of 6 tests** are `M4` (`TC-APP05` command delivery trigger pipeline and `TC-EXP-47` manual audit log purge).

### 2.6 Analysis of Batch 6 (Specialist Tests)
- **6 of 14 tests** are `M0` (local hardware self-tests, WebRTC camera/mic track release, UI permission bridges).
- **7 of 14 tests** are `M1` (active WebRTC signaling via `remote_sessions` and background heartbeat alerts).
- **1 of 14 tests** is `M4` (`TC-APP07` Device Owner app suspension with server ACK recording).

---

## 3. Evaluation of PREREQ-18 Across Execution Pathways

The operational meaning of `PREREQ-18` differs radically depending on the backend infrastructure selected by the Project Owner in Gate `P25-OWNER-02`:

| Backend Execution Pathway | Status of Fresh Migration Replay (`supabase db reset`) | Requirement for Existing Compatible Schema (`M1`) | Treatment of PREREQ-18 |
| :--- | :--- | :--- | :--- |
| **Pathway A: Dedicated Cloud Project** | **MANDATORY PRIOR TO ANY TESTING** | Created by fresh migration replay | **Provisioning Blocker**: Cannot run even Batch 1 without full initial migration replay. |
| **Pathway B: Shared QA Tenant Quarantine** | **PROHIBITED / DEFERRED** | **MANDATORY**: Must verify tables exist before testing | **Runtime Compatibility Gate**: Clean replay is deferred to avoid wiping shared data; schema presence must be verified. |
| **Pathway C: Local Docker Container** | **MANDATORY PRIOR TO ANY TESTING** | Created by fresh migration replay | **Provisioning Blocker**: Container initial spin-up requires clean migration replay before tests start. |

---

## 4. Reassessment & Final Classification Decision

Four options for classifying `PREREQ-18` were evaluated:
- **Option A**: *Retain Current PREREQ-18 Batch Rule* (Deferrable for Batches 1–4, Mandatory for Batches 5–6).
- **Option B**: *Retain PREREQ-18 but Replace Batch Rule with Test-Case-Level Requirements* (**SELECTED**).
- **Option C**: *Reclassify PREREQ-18 as a Category-Specific Prerequisite*.
- **Option D**: *Insufficient Source Evidence — Keep All AffectedTests Blocked*.

```
========================================================================================
                     FINAL PREREQ-18 CLASSIFICATION DECISION
========================================================================================

  SELECTED DECISION: B. RETAIN PREREQ-18 BUT REPLACE BATCH RULE WITH TEST-CASE-LEVEL 
                        REQUIREMENTS

========================================================================================
```

### Rationale for Selecting Option B:
1. **Eliminates False Assumptions**: Labeling PREREQ-18 as "deferrable for Batches 1 to 4" created the misleading impression that Batches 1 to 4 do not depend on the database. In reality, 55 of the 71 tests in Batches 1 to 4 require an operational database schema (`M1`).
2. **Pathway-Specific Precision**: Under Pathway A or C, PREREQ-18 is an **initial infrastructure provisioning prerequisite** that must be completed before any testing begins. Under Pathway B, clean replay is prohibited, but schema compatibility is mandatory.
3. **Exact Test-Case Enforcement**:
   - For all **26 `M0` tests**: PREREQ-18 is **NOT REQUIRED**. These tests can execute in mock or offline mode.
   - For all **61 `M1` tests**: PREREQ-18 clean replay is **DEFERRABLE**, but **existing schema compatibility is MANDATORY**.
   - For the **1 `M2` test**: PREREQ-18 clean replay is **NOT REQUIRED**; static file inspection only.
   - For all **4 `M3` tests**: PREREQ-18 clean migration replay is **MANDATORY**.
   - For all **7 `M4` tests**: Runtime schema and RPC verification is **MANDATORY**.

---

## 5. Audit Conclusion

The broad batch-level rule has been formally replaced by the definitive 99-test-case dependency classification. Test operators now have exact, unambiguous requirements for every test case across all three infrastructure pathways.
