# HAVEN PARENT CONTROL — PHASE 2.7.7
## DELIVERABLE 04: AUDIT_LOGS APPEND-ONLY TRIGGER & PRIVILEGED-ROLE INTEGRITY AUDIT

**Document ID:** `HAVEN-GOV-PHASE2-7-7-DOC04`  
**Phase:** Phase 2.7.7 — Final Inventory Arithmetic, Environment Classification & Audit Log Integrity Reconciliation  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Git HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Parent Commit:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** Forensic SQL DDL & Execution-Role Security Analysis  

---

### 1. OBJECTIVE & CONTEXT

In software security and regulatory compliance, labeling an audit logging mechanism as *"100% immutable"* asserts that no actor, process, role, or administrative interface can alter or delete logged records (akin to physical WORM optical storage).

Phase 2.7.6 reported that `private.audit_logs_append_only()` raises SQLSTATE `42501` to protect `audit_logs`, but also noted that privileged exceptions exist. This deliverable performs a rigorous forensic analysis of the PostgreSQL triggers, execution roles, Edge Functions, and retention sweep functions to determine the exact security boundaries and establish technically accurate compliance terminology.

---

### 2. FORENSIC INSPECTION OF THE APPEND-ONLY TRIGGER

The trigger function protecting `public.audit_logs` is defined in `supabase/migrations/20260101000000_core.sql` at lines 543–565:

```sql
-- supabase/migrations/20260101000000_core.sql:543-565
create or replace function private.audit_logs_append_only()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if tg_op in ('UPDATE', 'DELETE')
     and not (
       current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')
       or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
     ) then
    raise exception 'audit_logs is append-only' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger audit_logs_append_only
  before update or delete on public.audit_logs
  for each row execute function private.audit_logs_append_only();
```

#### 2.1 Trigger Characteristics
- **Target Table:** `public.audit_logs`
- **Timing & Event:** `BEFORE UPDATE OR DELETE`
- **Granularity:** `FOR EACH ROW`
- **Enforcement Action:** Raises exception `'audit_logs is append-only'` with SQLSTATE `42501` (`insufficient_privilege`).

#### 2.2 Privileged Role Exceptions
The conditional block explicitly exempts the following security contexts:
1. `current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')`
2. `coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'`

**Security Consequence:**  
When executed by any standard database user (such as `authenticated` or `anon`), any `UPDATE` or `DELETE` statement is rejected with SQLSTATE `42501`. However, if the query executes under a privileged database role (`postgres`, `service_role`, etc.) or carries the service-role JWT claim, the trigger bypasses the exception and returns `OLD` (for `DELETE`) or `NEW` (for `UPDATE`), **permitting the operation to complete without error**.

---

### 3. AUD04 RETENTION FUNCTION FORENSICS (`public.run_retention_sweep()`)

The authoritative implementation of the global retention sweep is located in `supabase/migrations/20261030000300_retention_sweep.sql`:

```sql
-- supabase/migrations/20261030000300_retention_sweep.sql:110-165
create or replace function public.run_retention_sweep()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
-- ...
  -- 2. Audit history: 365 days. The service-role guard in
  --    private.audit_logs_append_only() permits this SECURITY DEFINER context.
  loop
    delete from public.audit_logs a
    where a.id = any (array(
      select id
      from public.audit_logs
      where created_at < v_now - interval '365 days'
      limit v_batch
    ));
    get diagnostics v_deleted = row_count;
    v_audit := v_audit + v_deleted;
    exit when v_deleted < v_batch;
  end loop;
-- ...
$$;

revoke all on function public.run_retention_sweep() from public, anon, authenticated;
grant execute on function public.run_retention_sweep() to service_role;
```

#### 3.1 Function Execution Context & Trigger Interaction
1. **Security Mode:** `SECURITY DEFINER`. When called, the function executes with the database privileges of its owning user (`postgres`).
2. **Trigger Evaluation:** Inside `run_retention_sweep()`, `current_user` evaluates to `postgres`. When the `DELETE FROM public.audit_logs` executes, the trigger evaluates:
   `current_user in ('service_role', 'postgres', ...)` $\rightarrow$ **`TRUE`**.
3. **Trigger Bypass:** The exception is NOT raised. The trigger returns `OLD`, allowing rows older than 365 days to be permanently deleted.
4. **Authoritative Comment:** The SQL migration itself explicitly confirms this architectural design:  
   > `"-- The service-role guard in private.audit_logs_append_only() permits this SECURITY DEFINER context."`

---

### 4. AUD03 EDGE FUNCTION FORENSICS (`family-admin` `purge_data`)

The client-facing manual purge is implemented in `supabase/functions/family-admin/index.ts` lines 265–345:

#### 4.1 Client Authentication & Execution Role
- In `index.ts`, `const db = getServiceClient();` initializes a Supabase client using `SUPABASE_SERVICE_ROLE_KEY`.
- In PostgreSQL, queries from this client run with `request.jwt.claim.role = 'service_role'`.

#### 4.2 Application-Level Data Scope
Even though the client *technically possesses* the service-role privilege that could bypass the trigger, the TypeScript code **strictly confines its destructive operations to telemetry**:
1. `db.from("location_events").delete().eq("family_id", familyId).lt("recorded_at", locationCutoff)`
2. `db.from("usage_daily").delete().eq("family_id", familyId).lt("day", usageCutoff)`
3. `recordAudit(db, { familyId, actorUserId: auth.user.id, eventType: "data_purged", ... })`

**Critical Finding:**  
`family-admin` `purge_data` contains **zero SQL `DELETE` calls on `public.audit_logs`**. It only issues an `INSERT` into `public.audit_logs`.

---

### 5. MANDATORY INTEGRITY & EXECUTION MATRIX

| Operation | Target Database Table | SQL Action | Family Scoped? | Trigger Applies? | Privileged Exception Triggered? | Static Evidence Conclusion |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **AUD03 (`purge_data`)** | `public.location_events` | `DELETE` | **YES** (`eq("family_id")`) | NOT APPLICABLE | NOT APPLICABLE | Permanently deletes caller's location events older than cutoff. |
| **AUD03 (`purge_data`)** | `public.usage_daily` | `DELETE` | **YES** (`eq("family_id")`) | NOT APPLICABLE | NOT APPLICABLE | Permanently deletes caller's usage records older than cutoff. |
| **AUD03 (`purge_data`)** | `public.audit_logs` | **`INSERT`** | **YES** (`familyId`) | NO (`INSERT` only) | NOT APPLICABLE | **ZERO DELETIONS**. Inserts immutable `data_purged` compliance record. |
| **AUD04 (`retention_sweep`)**| `public.audit_logs` | **`DELETE`** | **NO** (Global / All Families) | **YES** | **YES** (`SECURITY DEFINER` postgres) | **DELETES AUDIT LOGS > 365 DAYS GLOBALLY**. Trigger permits deletion. |
| **AUD04 (`retention_sweep`)**| `public.location_events` | `DELETE` | **YES** (Per-family loop) | NOT APPLICABLE | NOT APPLICABLE | Deletes location telemetry older than family retention setting. |
| **AUD04 (`retention_sweep`)**| `public.usage_daily` | `DELETE` | **YES** (Per-family loop) | NOT APPLICABLE | NOT APPLICABLE | Deletes usage telemetry older than family retention setting. |
| **AUD04 (`retention_sweep`)**| `public.webrtc_signals` | `DELETE` | **NO** (Global / All Families) | NOT APPLICABLE | NOT APPLICABLE | Deletes WebRTC signaling records older than 7 days globally. |

---

### 6. DEFINITIVE COMPLIANCE TERMINOLOGY RULING

```
========================================================================================
COMPLIANCE TERMINOLOGY RULING:
========================================================================================
1. The description "100% IMMUTABLE AUDIT LOG" is TECHNICALLY INACCURATE and WITHDRAWN.
2. In PostgreSQL, audit log records can be deleted by privileged roles, and are actively
   deleted by the system retention sweep after 365 days.
3. The authoritative, legally defensible, and technically accurate term is:
   "APPEND-ONLY AGAINST ORDINARY APPLICATION OPERATIONS WITH PRIVILEGED-ROLE
    EXCEPTIONS FOR SYSTEM RETENTION SWEEPS"
========================================================================================
```
