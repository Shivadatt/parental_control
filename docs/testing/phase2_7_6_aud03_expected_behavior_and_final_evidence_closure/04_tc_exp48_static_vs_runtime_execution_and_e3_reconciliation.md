# HAVEN PARENT CONTROL — PHASE 2.7.6
## DELIVERABLE 04: TC-EXP-48 STATIC VS RUNTIME EXECUTION & E3 RECONCILIATION

**Document ID:** `HAVEN-GOV-PHASE2-7-6-DOC04`  
**Phase:** Phase 2.7.6 — AUD03 Expected Behavior, TC-EXP-48 Execution Separation & Final Evidence Closure  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Git HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Parent Commit:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Case Reference:** `TC-EXP-48` (Functionality ID: `AUD04`)  

---

### 1. EXECUTIVE OBJECTIVE

This deliverable establishes the rigorous technical separation between static SQL inspection and live runtime execution for test case `TC-EXP-48` (`AUD04`), and provides definitive mathematical and documentary reconciliation for the two test cases moved from `E3` to `E2` in Phase 2.7.4 Deliverable 06.

---

### 2. TC-EXP-48: STATIC INSPECTION VS RUNTIME EXECUTION

#### 2.1 Original Test Case Specification
From `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md` (lines 1170–1188):
- **Title:** `TC-EXP-48: PostgreSQL Audit Retention Sweep Function`
- **Target Component:** `supabase/migrations/20261030000300_retention_sweep.sql`
- **Steps:**
  1. Connect to PostgreSQL via Supabase SQL Editor.
  2. Inspect function definition for `execute_retention_sweep()`.
  3. Verify function deletes records older than retention threshold.
  4. Verify function is protected against unauthorized execution (SECURITY DEFINER / service_role only).
  5. Test function with mock expired data: insert expired audit record, run sweep, verify record is purged.
- **Original Classification Ambiguity:**
  Steps 1–4 describe read-only schema/DDL analysis, whereas Step 5 describes live multi-tenant runtime database manipulation.

#### 2.2 Implementation Evidence (`supabase/migrations/20261030000300_retention_sweep.sql`)
Source inspection of `supabase/migrations/20261030000300_retention_sweep.sql` (lines 113–185) reveals the actual function signature and destructive scope:

```sql
-- Function signature in migration:
CREATE OR REPLACE FUNCTION public.run_retention_sweep()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_webrtc_count integer := 0;
  v_audit_count integer := 0;
  v_loc_count integer := 0;
  v_usage_count integer := 0;
BEGIN
  -- 1. Global un-scoped deletion of expired WebRTC signaling records (>7 days)
  DELETE FROM public.webrtc_signals
  WHERE created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_webrtc_count = ROW_COUNT;

  -- 2. Global un-scoped deletion of expired audit logs (>365 days)
  -- Bypasses trigger because function executes as owner/SECURITY DEFINER
  DELETE FROM public.audit_logs
  WHERE created_at < NOW() - INTERVAL '365 days';
  GET DIAGNOSTICS v_audit_count = ROW_COUNT;

  -- 3. Global retention sweep across all family location & usage data
  -- ... iterates or executes multi-tenant sweep ...

  RETURN jsonb_build_object(
    'webrtc_purged', v_webrtc_count,
    'audit_purged', v_audit_count,
    'sweep_completed_at', NOW()
  );
END;
$$;
```

#### 2.3 Separation of Validation Modes

```
+---------------------------------------------------------------------------------------+
|                       TC-EXP-48 VALIDATION MODE SEPARATION                            |
+---------------------------------------------------------------------------------------+
|  MODE 1: STATIC DDL & PERMISSION INSPECTION (TC-EXP-48-STATIC)                        |
|  - Classification: M2 (Static Code Review) + E0 (No Live Environment)                 |
|  - Operations: Inspect migration script lines 113-185, verify SECURITY DEFINER,       |
|    search_path isolation, parameter validation, and syntax.                           |
|  - Blast Radius: ZERO. Safe in any phase, including read-only governance audits.      |
|  - Status: PERMITTED & FULLY COMPLETED IN READ-ONLY AUDIT.                            |
|                                                                                       |
|  MODE 2: RUNTIME DATABASE EXECUTION (TC-EXP-48-RUNTIME)                               |
|  - Classification: M4 (Database State Manipulation) + E3 (Dedicated Isolated DB)      |
|  - Operations: Invoke SELECT public.run_retention_sweep(); against live database.     |
|  - Blast Radius: GLOBAL / MULTI-TENANT DESTRUCTIVE. Deletes WebRTC signals, audit     |
|    records older than 365 days, and telemetry across ALL families.                    |
|  - Environment Requirement: Requires dedicated standalone database instance (E3).     |
|  - Status: PROHIBITED ON SHARED/PRODUCTION BACKENDS UNDER CURRENT BASELINE.           |
+---------------------------------------------------------------------------------------+
```

**Verdict:** `STATIC INSPECTION AND RUNTIME EXECUTION ARE DISTINCT VALIDATION MODES`.

---

### 3. RECONCILIATION OF THE TWO E3-TO-E2 MOVEMENTS IN PHASE 2.7.4

#### 3.1 Historical Baseline: Phase 2.7.3 Environment Classification
In Phase 2.7.3 (`docs/testing/phase2_7_3_dependency_orthogonality/02_three_dimensional_test_dependency_master_matrix.md`), exactly **3 test cases** were assigned to Environment Tier `E3` (Isolated Dedicated Backend Instance):
1. `TC-SEC01`: Cross-Family Unauthorized Access Boundary
2. `TC-SEC02`: Replay of Staged Credential Redemption
3. `TC-EXP-48`: PostgreSQL Audit Retention Sweep Function

#### 3.2 Phase 2.7.4 Deliverable 06 Reclassification Analysis
In Phase 2.7.4 Deliverable 06 (`docs/testing/phase2_7_4_owner_decision_traceability/06_99_test_cases_master_traceability_matrix.md`), two of these three test cases were moved from `E3` down to `E2` (Disposable Tenant-Level Test Fixture):

```
+-----------+--------------------+--------------------+-----------------------------------+
| Test ID   | Phase 2.7.3 Env    | Phase 2.7.4 Env    | Technical Justification           |
+-----------+--------------------+--------------------+-----------------------------------+
| TC-SEC01  | E3 (Dedicated DB)  | E2 (Disposable Fixt)| Cross-tenant access boundaries are|
|           |                    |                    | validated between two disposable  |
|           |                    |                    | families on a shared backend; no  |
|           |                    |                    | database wipe/reset required.     |
+-----------+--------------------+--------------------+-----------------------------------+
| TC-SEC02  | E3 (Dedicated DB)  | E2 (Disposable Fixt)| Credential replay tests token/code|
|           |                    |                    | reuse within a specific family or |
|           |                    |                    | pairing session; disposable test  |
|           |                    |                    | fixture provides full isolation.  |
+-----------+--------------------+--------------------+-----------------------------------+
| TC-EXP-48 | E3 (Dedicated DB)  | E3 (Dedicated DB)  | RETAINED IN E3. Retention sweep   |
|           |                    |                    | runs globally across all tenants. |
|           |                    |                    | Destructive blast radius requires |
|           |                    |                    | isolated throwaway DB instance.   |
+-----------+--------------------+--------------------+-----------------------------------+
```

#### 3.3 Historical vs Current Environment Tier Totals

The resulting reconciliation across the 99 manual test cases across audit milestones is:

| Environment Classification Tier | Phase 2.7.3 Baseline | Phase 2.7.4 Final | Phase 2.7.6 Audit Baseline | Net Movement / Status |
| :--- | :---: | :---: | :---: | :--- |
| **E0** (Pure Mock / No Backend) | 38 | 38 | 38 | Stable |
| **E1** (Shared Live Backend — Read/Write) | 48 | 48 | 48 | Stable |
| **E2** (Disposable Tenant Fixture) | 10 | **12** | **12** | **+2** (`TC-SEC01`, `TC-SEC02`) |
| **E3** (Dedicated Isolated DB Instance) | 3 | **1** | **1** | **-2** (Only `TC-EXP-48` retained) |
| **Total Test Cases** | **99** | **99** | **99** | **100% Reconciled** |

---

### 4. SUMMARY CONCLUSION

1. The exact two test cases moved from `E3` to `E2` in Phase 2.7.4 are definitively identified as **`TC-SEC01`** and **`TC-SEC02`**.
2. Their movement to `E2` is technically sound, as tenant-level row isolation safeguards shared backend data for both test cases.
3. `TC-EXP-48` runtime execution remains the **sole test case requiring `E3`**, due to its un-scoped global multi-tenant deletion semantics.
4. Static inspection of `TC-EXP-48` is decoupled as `M2 + E0`, safe for read-only audits.
