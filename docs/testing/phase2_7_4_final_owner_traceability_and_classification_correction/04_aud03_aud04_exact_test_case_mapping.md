# HAVEN PARENT CONTROL — PHASE 2.7.4 DELIVERABLE 04
# AUDIT C: TC-EXP-47 & TC-EXP-48 TO AUD03 & AUD04 EXACT TRACEABILITY

**Document ID:** `HAVEN-GOV-PHASE2-7-4-AUDIT-C`  
**Phase:** Phase 2.7.4 — Final Owner Decision Traceability & Test Classification Correction Audit  
**Audit Dimension:** Destructive Operation Boundaries & Test Specification Traceability  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Source Evidence Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Status:** ALL TESTS REMAIN NOT TESTED  

---

## 1. Executive Summary & Purpose

A critical vulnerability in past testing roadmaps was the potential for conflating **family-scoped, user-authorized deletions (`AUD03`)** with **global, multi-tenant automated retention sweeps (`AUD04`)**.

If a global sweep were triggered in a shared or pre-production environment, it could permanently wipe telemetry, signaling data, or audit logs across unrelated families or tenants.

This Phase 2.7.4 Audit C inspects the authoritative test specifications for `TC-EXP-47` and `TC-EXP-48`, traces their exact implementation across Edge Functions and SQL migrations, and establishes strict governance boundaries for each.

---

## 2. Exhaustive Traceability Matrix: TC-EXP-47 vs TC-EXP-48

```
+----------------------------------------------------------------------------------------------------+
|                               DESTRUCTIVE MAINTENANCE TRACEABILITY COMPARISON                      |
+------------------------------------+----------------------------------+----------------------------+
| Architectural Property             | TC-EXP-47                        | TC-EXP-48                  |
+------------------------------------+----------------------------------+----------------------------+
| Authoritative Test ID              | TC-EXP-47                        | TC-EXP-48                  |
| Authoritative Spec Reference       | 05_additional_...md:1485         | 05_additional_...md:1515   |
| Functional Tag                     | AUD03                            | AUD04                      |
| Test Name                          | On-Demand Audit Log Purge        | Database Retention Sweep   |
| Invocation Layer                   | Client UI -> Edge Function / RPC | SQL Engine / Cron Trigger  |
| Target Symbol                      | executeAccountDeletion / RPC     | public.run_retention_sweep |
| Source File                        | deletion.ts:418 / retention.sql  | retention_sweep.sql:113    |
| Caller Authentication Required     | YES (End-user JWT)               | NO (Service Role / Definer)|
| Confirmation Keyword Required      | YES ("PURGE" / "DELETE")         | NO (Zero confirmation)     |
| Multi-Tenant Scope                 | STRICTLY FAMILY-SCOPED           | UNRESTRICTED GLOBAL SWEEP  |
| Destructive Radius                 | Caller's own family rows only    | ALL FAMILIES & SYSTEM ROWS |
| Database Dependency Class          | M4 (Destructive Operation)       | M2 (Static DDL Inspection) |
| Environment Dependency Class       | E2 (Isolated Tenant Required)    | E3 (Fresh Provisioning)    |
| Governance Status                  | PROPOSED CONTROLLED TEST         | PROHIBITED ON SHARED DB    |
+------------------------------------+----------------------------------+----------------------------+
```

---

## 3. Detailed Source-Level Audit of TC-EXP-47 (AUD03)

### 3.1 Test Specification Audit
- **Authoritative Location:** `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:1485`
- **Test Title:** Manual Audit Log Purge with Confirmation
- **Target Role:** Parent Mode (Authenticated Family Owner)
- **Documented Steps:**
  1. In Audit Logs settings, tap "Purge Old Logs".
  2. Enter confirmation keyword "PURGE".
  3. Tap "Confirm Purge".
- **Expected Result:** Backend deletes historical logs older than 60 days belonging to the caller's family while retaining recent logs. Snackbar confirms count of purged records.

### 3.2 Implementation Evidence & Scoping Invariants
Source inspection of `supabase/functions/account/deletion.ts` and `supabase/migrations/20261030000300_retention_sweep.sql` demonstrates the following security controls:
1. **JWT Caller Binding:**
   The function extracts `userId = caller.user.id` strictly from the cryptographically verified JWT gateway context.
2. **Confirmation Enforcement:**
   Requires the exact confirmation string (`confirm == "PURGE"` or `confirm == "DELETE"`) and verifies caller identity before issuing database statements.
3. **Rigid Family Scoping:**
   ```sql
   DELETE FROM public.audit_logs
   WHERE family_id = v_caller_family_id
     AND created_at < now() - (v_retention_days || ' days')::interval;
   ```
   Under no circumstances can `executeAccountDeletion` or the scoped purge delete audit logs, device records, or location events belonging to any other `family_id`.

### 3.3 Governance Classification & Execution Restrictions
- **Confirmation:** `TC-EXP-47` conclusively tests **`AUD03` (Family-Scoped On-Demand Deletion)**.
- **Execution Status:**  
  > **`PROPOSED CONTROLLED TEST — NOT AUTHORIZED FOR EXECUTION UNDER THE CURRENT GOVERNANCE BASELINE`**
- **Prerequisite Requirements for Future Execution:**
  - Explicit Project Owner approval under Gate `P25-OWNER-03` (Option 3-A).
  - Allocation of a dedicated disposable QA account fixture (`qa-destroy-*@haven.internal`).
  - Strict containment to disposable test family data.
  - Phase 3 master execution authorization.

---

## 4. Detailed Source-Level Audit of TC-EXP-48 (AUD04)

### 4.1 Test Specification Audit
- **Authoritative Location:** `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:1515`
- **Test Title:** PostgreSQL Audit Retention Sweep Function
- **Target Role:** Backend Maintenance / Database Administrator
- **Documented Steps:**
  1. Execute `SELECT execute_retention_sweep();` (or `SELECT public.run_retention_sweep();`) via Supabase SQL Editor.
  2. Verify deleted row counts returned in JSON summary.

### 4.2 Implementation Evidence & Multi-Tenant Threat Analysis
Inspection of `supabase/migrations/20261030000300_retention_sweep.sql:113-175` exposes the unrestricted multi-tenant nature of this database routine:

```sql
create or replace function public.run_retention_sweep()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare ...
begin
  -- 1. Signaling payloads: 7 days, GLOBAL (no per-family window exists)
  loop
    delete from public.webrtc_signals w
    where w.id = any (array(
      select id from public.webrtc_signals
      where created_at < v_now - interval '7 days'
      limit v_batch
    ));
    ...
  end loop;

  -- 2. Audit history: 365 days, GLOBAL across all tenants
  loop
    delete from public.audit_logs a
    where a.id = any (array(
      select id from public.audit_logs
      where created_at < v_now - interval '365 days'
      limit v_batch
    ));
    ...
  end loop;

  -- 3. Location and Usage: Iterates EVERY family in the database!
  for v_family in
    select id, retention_days from public.families where deleted_at is null
  loop
    delete from public.location_events ...;
    delete from public.usage_daily ...;
  end loop;
...
```

### 4.3 Hazard Identification on Shared Environments
- **Zero Family Parameter:** The function takes zero arguments (`public.run_retention_sweep()`). It cannot be scoped to an isolated test family.
- **Cross-Tenant Destruction:** It executes `DELETE` statements across the entire multi-tenant table space for `webrtc_signals`, `audit_logs`, `location_events`, and `usage_daily`.
- **Compliance Violation Risk:** If executed in an environment containing live or shared data, it irreversibly purges records older than cutoff windows, potentially destroying compliance audit logs (>365 days).

### 4.4 Governance Classification & Execution Restrictions
- **Confirmation:** `TC-EXP-48` conclusively tests **`AUD04` (Global Automated Retention Sweep)**.
- **Execution Status:**  
  > **`PROHIBITED FOR TEST EXECUTION ON THE SHARED BACKEND UNDER THE CURRENT GOVERNANCE BASELINE`**
- **Approved Audit Procedure:**
  - `TC-EXP-48` is classified exclusively as **`M2` (Static Migration Inspection Required)**.
  - Verification is performed by inspecting SQL migration DDL, indexing structures, batch loops (`v_batch constant integer := 10000;`), and trigger guards.
  - **Mandatory Epistemological Standard:** Static source inspection of the SQL artifact must NEVER be represented as successful runtime validation of the retention sweep function. Runtime execution is strictly prohibited unless conducted within an isolated dedicated backend (Pathway A or Pathway C) under explicit owner authorization.

---

## 5. Architectural Summary of AUD03 vs AUD04 Governance Policies

The boundary between AUD03 and AUD04 is formally defined as:

1. **`AUD03` is a Permissible Controlled Test** when executed against dedicated disposable fixtures (`qa-destroy-*`) under Gate 3 Option 3-A. It operates exclusively on caller data and cannot impact other tenants.
2. **`AUD04` is an Un-Scoped System Routine** that sweeps all families in the database. It is strictly prohibited from execution on any shared backend.
3. Neither operation may be invoked during Phase 2.7.4. Both remain marked **`NOT TESTED`**.
