# HAVEN PARENT CONTROL — PHASE 2.7.4 DELIVERABLE 04
# AUDIT C & D: TC-EXP-47 & TC-EXP-48 OPERATION-LEVEL TRACEABILITY AUDIT

**Document ID:** `HAVEN-GOV-PHASE2-7-5-AUD-TRACE`  
**Phase:** Phase 2.7.5 — Test Case Identity Integrity & AUD03/AUD04 Operation-Level Traceability Audit  
**Audit Standard:** Independent Adversarial AST & Code Call-Chain Verification  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Status:** BOTH TESTS REMAIN NOT TESTED  

---

## 1. Executive Summary & Scope

Previous audit phases established a high-level policy distinction between:
- **`AUD03`**: User-initiated, family-scoped data purge.
- **`AUD04`**: Automated, global multi-tenant database retention sweep.

However, Phase 2.7.4 identified ambiguities regarding the exact Edge Function call chains, SQL routines, and database tables affected by `TC-EXP-47` and `TC-EXP-48`.

This Phase 2.7.5 audit conducts an operation-level code trace from the Flutter UI and repositories through Edge Functions down to the SQL engine, resolving the exact operational scope and execution boundaries for both tests.

---

## 2. Operation-Level Traceability for TC-EXP-47 (AUD03)

### 2.1 Authoritative Specification Record
- **Specification Source:** `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:1151`
- **Title:** `TC-EXP-47: Manual Audit Log Purge with Confirmation`
- **Target Role:** Parent Mode (Authenticated Family Owner)
- **Functional Tag:** `AUD03` (On-Demand Historical Data Purge)
- **Documented Steps:**
  1. In Audit Logs settings, tap "Purge Old Logs".
  2. Enter confirmation keyword "PURGE".
  3. Tap "Confirm Purge".
- **Expected Result:** Backend deletes historical logs older than 60 days while retaining recent logs.

### 2.2 End-to-End Implementation Call Chain
Tracing the source code reveals the actual execution pipeline:

```
+----------------------------------------------------------------------------------------------------+
|                               TC-EXP-47 OPERATION-LEVEL EXECUTION CHAIN                           |
+------------------------------------+----------------------------------+----------------------------+
| Execution Layer                    | Source Code File & Symbol        | Concrete Operation         |
+------------------------------------+----------------------------------+----------------------------+
| 1. Flutter UI View                 | audit_logs_page.dart:180         | Dialog prompt for purge    |
| 2. Flutter State Controller        | audit_logs_controller.dart:239   | Calls purgeOldData(days)   |
| 3. Data Repository                 | supabase_audit_repository.dart:64| Invokes Edge Function:     |
|                                    |                                  | family-admin (purge_data)  |
| 4. Supabase Edge Function          | family-admin/index.ts:265-345    | case "purge_data":         |
|                                    |                                  | - Verified caller JWT      |
|                                    |                                  | - Owner check: canPurge()  |
| 5. Database DML Execution          | family-admin/index.ts:305-317    | DELETE location_events     |
|                                    |                                  | DELETE usage_daily         |
| 6. Audit Trail Recording           | family-admin/index.ts:323-335    | INSERT audit_logs (event:  |
|                                    |                                  | "data_purged")             |
+------------------------------------+----------------------------------+----------------------------+
```

### 2.3 Critical Source Findings for TC-EXP-47
1. **Target Tables:**
   `family-admin` `purge_data` deletes rows from **`public.location_events`** and **`public.usage_daily`** older than `Math.max(olderThanDays, retention_days)`.
2. **Audit Logs are Intentionally Preserved:**
   The function does **NOT** delete rows from `public.audit_logs`. Instead, it appends a new audit row (`eventType: 'data_purged'`) documenting the purge. This design satisfies compliance invariants: the audit trail of administrative actions must remain append-only (`private.audit_logs_append_only()`).
3. **Strict Family Scoping:**
   All deletions are hard-scoped to `family_id = familyId`. Under zero conditions can `purge_data` impact records belonging to another family.
4. **Correction of Previous Documentary Citation:**
   In Phase 2.7.4 Deliverable 04, `TC-EXP-47` was cited alongside `supabase/functions/account/deletion.ts:418`. This was an error in previous reports: `account/deletion.ts` is `executeAccountDeletion` (`A09` / `TC-A09`), which deletes user auth rows and owned families, whereas `TC-EXP-47` invokes `family-admin` `purge_data`.

### 2.4 Audit C Mapping Verdict
> **VERDICT: `TC-EXP-47 PARTIALLY MAPS TO AUD03`**  
> *TC-EXP-47 tests on-demand historical data purging (`AUD03`). However, the implementation purges historical location and app usage telemetry, not the append-only audit logs themselves. Execution remains: **`PROPOSED CONTROLLED TEST — NOT AUTHORIZED FOR EXECUTION UNDER THE CURRENT GOVERNANCE BASELINE`**.*

---

## 3. Operation-Level Traceability for TC-EXP-48 (AUD04)

### 3.1 Authoritative Specification Record
- **Specification Source:** `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:1174`
- **Title:** `TC-EXP-48: PostgreSQL Audit Retention Sweep Function`
- **Target Role:** Backend Maintenance / Database Administrator
- **Functional Tag:** `AUD04` (Scheduled Database Retention Sweep)
- **Documented Steps:**
  1. Execute `SELECT execute_retention_sweep();` (or `SELECT public.run_retention_sweep();`) via Supabase SQL Editor.
  2. Verify deleted row counts returned in JSON summary.

### 3.2 SQL Implementation & Multi-Tenant Threat Analysis
Inspection of `supabase/migrations/20261030000300_retention_sweep.sql:113-280` establishes the concrete database operation:

```sql
create or replace function public.run_retention_sweep()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
...
begin
  -- 1. Signaling payloads: 7 days, GLOBAL across all tenants
  loop
    delete from public.webrtc_signals ... where created_at < v_now - interval '7 days';
    ...
  end loop;

  -- 2. Audit history: 365 days, GLOBAL across all tenants
  loop
    delete from public.audit_logs ... where created_at < v_now - interval '365 days';
    ...
  end loop;

  -- 3. Location and Usage: Iterates ALL families in the database
  for v_family in
    select id, retention_days from public.families where deleted_at is null
  loop
    delete from public.location_events where family_id = v_family.id ...;
    delete from public.usage_daily where family_id = v_family.id ...;
  end loop;
...
```

### 3.3 Critical Source Findings for TC-EXP-48
1. **Unrestricted Global Sweep:**
   `public.run_retention_sweep()` takes zero parameters. It does not possess family filtering at the function signature level.
2. **Multi-Tenant Destructive Radius:**
   It permanently deletes records across all families and tenants in the database.
3. **Execution Context:**
   Granted exclusively to `service_role`. Invoked periodically by the `cron` Edge Function (`supabase/functions/cron/index.ts`).
4. **Shared Backend Hazard:**
   Executing `run_retention_sweep()` in a shared environment (Pathway B) destroys real telemetry and signaling data across all accounts.

### 3.4 Audit D Mapping Verdict
> **VERDICT: `RUNTIME EXECUTION REQUIRED BY ORIGINAL TEST SPEC — CURRENTLY PROHIBITED`**  
> *The original test specification explicitly requires running the SQL function and verifying deleted row counts. However, because it executes globally across all tenants, runtime execution is **`PROHIBITED FOR TEST EXECUTION ON THE SHARED BACKEND UNDER THE CURRENT GOVERNANCE BASELINE`**. Under the current baseline, verification is strictly restricted to **Static SQL DDL Inspection (`M2`)**.*

---

## 4. Disambiguation of Environment E3 for TC-EXP-48 (Audit F)

In Phase 2.7.3 and Phase 2.7.4, `TC-EXP-48` was associated with classification **`E3`**:
- **Historical E3 Meaning (Phase 2.7.3):**
  `E3: Fresh infrastructure and schema provisioning required (clean project / Docker spin-up)`.
- **E3 Clarification:**
  - If `TC-EXP-48` is evaluated as a **Static SQL Review (`M2`)**, it does not require a running backend at all (**`E0`**).
  - If `TC-EXP-48` is evaluated against its **Original Runtime Test Steps**, it strictly requires an isolated, dedicated database (**`E3`**) to prevent multi-tenant data corruption.
  - However, because Phase 3 execution is currently **LOCKED**, and because Pathway B prohibits global sweeps, `E3` represents a **conditional future requirement**, NOT an authorized runtime activity.
  - To prevent misunderstanding, `TC-EXP-48` is classified as **`M2 + E0`** under the current read-only static review baseline, with **`E3`** noted as the prerequisite if runtime execution is ever authorized by the Owner under Gate 3 Option 3-C.

---

## 5. Comparative Architectural Matrix: AUD03 vs AUD04

| Property | AUD03 (`TC-EXP-47`) | AUD04 (`TC-EXP-48`) |
| :--- | :--- | :--- |
| **Functional Name** | On-Demand Historical Purge | Scheduled Database Retention Sweep |
| **Trigger Mechanism** | User Action (Parent Settings UI) | Automated Cron / DBA SQL Editor |
| **Invoked Component** | `family-admin` (`action: "purge_data"`) | `public.run_retention_sweep()` |
| **Enforcing Authority** | Verified End-User JWT (Family Owner) | Service Role (`SECURITY DEFINER`) |
| **Confirmation Required** | Keyword `"PURGE"` in UI dialog | None |
| **Tables Deleted** | `location_events`, `usage_daily` | `webrtc_signals`, `audit_logs`, `location_events`, `usage_daily` |
| **Audit Logs Affected?** | **NO** (Appends `data_purged` record) | **YES** (Hard deletes logs > 365 days) |
| **Tenant Isolation** | **STRICTLY FAMILY-SCOPED** | **UNRESTRICTED MULTI-TENANT GLOBAL** |
| **Shared Backend Policy** | Controlled Test on Disposable Acct | **STRICTLY PROHIBITED ON SHARED BACKEND** |
| **Current Test Posture** | NOT TESTED | NOT TESTED (Static Review Only) |
