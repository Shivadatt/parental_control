# HAVEN PARENT CONTROL — PHASE 2.7.3 DELIVERABLE 05
# AUD03 AND AUD04 SCOPE, ISOLATION & AUTHORIZATION RECONCILIATION

**Document ID:** `HAVEN-GOV-PHASE2-7-3-AUD-RECON`  
**Phase:** Phase 2.7.3 — Final Dependency Orthogonality & Governance Closure Audit  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Security & Policy Governance Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Runtime Execution:** PROHIBITED  
**Phase 3 Authorization:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Scope

Previous governance audits established strict restrictions on destructive database routines. However, technical confusion persisted regarding the exact architectural boundaries between two distinct capabilities:
- **`AUD03`**: Family-scoped account deletion and on-demand historical log purging.
- **`AUD04`**: Global, system-wide scheduled database retention sweeps.

This report independently audits the PostgreSQL migrations and Deno Edge Function source code to provide the definitive reconciliation of scopes, authorization mechanisms, service-role privileges, and test case mappings.

---

## 2. Technical Comparison: AUD03 vs AUD04

The table below contrasts the actual source implementations of AUD03 and AUD04:

| Architectural Dimension | Scoped Purge: `AUD03` (`account` Edge Function) | Global Retention Sweep: `AUD04` (`public.run_retention_sweep`) |
| :--- | :--- | :--- |
| **Primary Code Artifact** | `supabase/functions/account/deletion.ts:418` | `supabase/migrations/20261030000300_retention_sweep.sql:113` |
| **Invocation Channel** | Authenticated HTTPS POST to `/account` | Authenticated HTTPS POST to `/cron` (or direct SQL RPC) |
| **Caller Authorization** | **Verified End-User JWT** (`caller.user.id`) | **CRON_SECRET / Service-Role Key Only** |
| **Target Filter Scope** | **Strictly Scoped to Caller's Family**: `eq("owner_id", userId)` | **GLOBAL**: Loops across `public.families` and sweeps all tenants |
| **Tables Deleted** | Caller's `family_members`, owned `families`, profile, auth user | Global `webrtc_signals` (>7d), global `audit_logs` (>365d), per-family `location_events` & `usage_daily` |
| **Safety Guards** | Requires confirmation word "DELETE" + caller email match + checks for active child device blockers | Hardcoded time intervals; no interactive confirmation keyword |
| **RLS Impact** | Uses service client inside Deno, but strictly confines operations using caller's verified `user.id` | Declared `SECURITY DEFINER` with `set search_path = public`; bypasses RLS across all tables |
| **Shared Backend Risk** | **Low-Medium** (Confined to dedicated disposable QA account) | **CATASTROPHIC** (May purge production or staging data across all families) |
| **Current Baseline Rule** | Permitted under controlled conditions with disposable QA accounts | **PROHIBITED FOR TEST EXECUTION ON THE SHARED BACKEND UNDER THE CURRENT GOVERNANCE BASELINE** |

---

## 3. Deep Dive into Implementation Truth

### 3.1 AUD03 Source Verification (`deletion.ts`)
Source code inspection of `supabase/functions/account/deletion.ts` demonstrates that AUD03 enforces rigorous isolation:
```typescript
// deletion.ts lines 407, 426-433:
// Invariant 1: Caller identity strictly comes from the verified JWT (UserIdentity.user.id).
// Invariant 3: Exact confirmation word "DELETE" and typed email matching caller are verified.
const failure = validateDeleteAccountInput({
  confirm: body.confirm,
  email: body.email,
  callerEmail: caller.user.email,
});
...
// deletion.ts lines 454-458:
const ownedResult = await db
  .from("families")
  .select("id, name, owner_id")
  .eq("owner_id", userId)
  .is("deleted_at", null);
```
- **Conclusion**: AUD03 is technically incapable of deleting data belonging to other families because every SQL query is filtered by `eq("owner_id", userId)`. As long as testing is conducted with a disposable QA account (`qa-destroy-*@haven.internal`), AUD03 poses zero threat to adjacent test tenants.

### 3.2 AUD04 Source Verification (`retention_sweep.sql`)
Source code inspection of `supabase/migrations/20261030000300_retention_sweep.sql` demonstrates the unconstrained multi-tenant reach of AUD04:
```sql
-- Step 1: Global signaling purge (no family qualifier)
delete from public.webrtc_signals where created_at < v_now - interval '7 days';

-- Step 2: Global audit log purge (no family qualifier)
delete from public.audit_logs where created_at < v_now - interval '365 days';

-- Step 3: Unconstrained loop across ALL families in the database
for v_family in select f.id, f.settings from public.families f order by f.id loop
  delete from public.location_events where family_id = v_family.id ...;
  delete from public.usage_daily where family_id = v_family.id ...;
end loop;
```
- **Conclusion**: `run_retention_sweep()` does not accept a `family_id` parameter. It iterates through the entire database. If executed on Pathway B (shared Supabase instance), it will delete telemetry and historical records across all families in that project.

---

## 4. Test Case Mapping Reconciliation: TC-EXP-47 vs TC-EXP-48

Previous reviews questioned whether any test case conflated AUD03 and AUD04. Forensic re-verification of the test catalog establishes:

### 4.1 TC-EXP-47: Manual Historical Audit Log Purge (`AUD03`)
- **Documented Purpose**: "Verify parent can manually trigger a purge of audit logs older than the retention threshold with explicit keyword confirmation."
- **Mapped Functionality**: **`AUD03`**.
- **Scope**: **Family-Scoped**. The UI calls a scoped RPC / edge endpoint that purges only the active family's audit history older than the configured threshold.
- **Classification**: **`M4 + E2`**. Permitted to execute during Phase 3 *only* within a dedicated disposable test family, requiring explicit keyword confirmation.

### 4.2 TC-EXP-48: PostgreSQL Scheduled Retention Sweep Function (`AUD04`)
- **Documented Purpose**: "Verify database migration function execute_retention_sweep() [shipped as `public.run_retention_sweep()`] deletes expired audit records and telemetry..."
- **Mapped Functionality**: **`AUD04`**.
- **Scope**: **Global System-Wide Sweep**.
- **Classification**: **`M2 + E3`**. In Phase 2.7.2 and 2.7.3, this test is strictly classified as **Static Migration Inspection (`M2`)**. 
- **Operational Restriction**: Runtime execution of `TC-EXP-48` is **PROHIBITED ON THE SHARED BACKEND**. It may only be executed dynamically if the Project Owner mandates Pathway A (Dedicated Isolated Project) or Pathway C (Local Docker) and grants explicit affirmative written approval under Gate `P25-OWNER-03`.

---

## 5. Synthesis & Governance Declaration

```
========================================================================================
                 AUD03 vs AUD04 AUTHORIZATION BOUNDARY SUMMARY
========================================================================================

  1. AUD03 (Family-Scoped Purge / Account Deletion):
     • SCOPE: Single family / single authenticated user.
     • CONTROL: Enforces JWT caller identity and confirmation keyword.
     • TESTING: Permitted under controlled conditions using disposable QA accounts.
     • STATUS: Locked pending Owner Gate P25-OWNER-03 approval.

  2. AUD04 (Global Database Retention Sweep):
     • SCOPE: Unconstrained multi-tenant database sweep.
     • CONTROL: CRON_SECRET / Service-Role only; no family parameter.
     • TESTING: PROHIBITED on Pathway B (shared backend).
     • CURRENT BASELINE: TC-EXP-48 is approved as STATIC SQL INSPECTION ONLY (M2).
     • FUTURE RUNTIME: Strictly requires isolated Pathway A/C + explicit owner directive.

========================================================================================
```
