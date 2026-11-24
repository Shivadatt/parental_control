# HAVEN PARENT CONTROL — PHASE 2.7.8
## DELIVERABLE 05: AUD04 SECURITY DEFINER, TRIGGER & SCHEDULER EXECUTION CONTEXT

**Document ID:** `HAVEN-GOV-PHASE2-7-8-DOC05`  
**Phase:** Phase 2.7.8 — Final Classification Semantics, RLS Predicate & Privileged Execution Context Verification  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Git HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Parent Commit:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** PostgreSQL Privileged Identity & Lifecycle Invocation Analysis  
**Function Reference:** `public.run_retention_sweep()` (`AUD04` / `TC-EXP-48`)  

---

### 1. FUNCTION DEFINITION & PRIVILEGED ATTRIBUTES

The authoritative SQL definition of `public.run_retention_sweep()` is located in `supabase/migrations/20261030000300_retention_sweep.sql` (lines 110–282):

```sql
-- 20261030000300_retention_sweep.sql:110-125
create or replace function public.run_retention_sweep()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
-- ...
$$;

revoke all on function public.run_retention_sweep() from public, anon, authenticated;
grant execute on function public.run_retention_sweep() to service_role;
```

#### 1.1 Structural Security Attributes
- **Function Owner:** In PostgreSQL and Supabase migration execution, functions defined without an explicit `ALTER FUNCTION ... OWNER TO` statement are owned by the session role executing the migration, which is `postgres`.
- **Security Mode:** `SECURITY DEFINER`. Under PostgreSQL semantics, the function executes with the privileges of its owner (`postgres`) rather than the calling user.
- **Search Path Isolation:** Explicitly enforced: `SET search_path = public, private, pg_temp`. Prevents search-path substitution or privilege-escalation attacks.
- **Execution Grants:**
  - `REVOKE ALL` from `public`, `anon`, and `authenticated`.
  - `GRANT EXECUTE` exclusively to `service_role`.
  - Clients, authenticated parents, and child devices have **zero direct execution privileges** on this function.

---

### 2. POSTGRESQL IDENTITY SEMANTICS & TRIGGER INTERACTION

In PostgreSQL execution environments, multiple identity concepts operate simultaneously:
1. `session_user`: The physical role that authenticated the client connection (e.g., `service_role` or `authenticator`).
2. `current_user`: The effective role evaluated for permissions. When a `SECURITY DEFINER` function executes, PostgreSQL switches `current_user` to the function's owner (`postgres`).
3. `request.jwt.claim.role`: The application-level role claim extracted from the caller's JWT.

#### 2.1 Interaction with `private.audit_logs_append_only()`
In `supabase/migrations/20260101000000_core.sql` (lines 543–565), the append-only trigger evaluates:

```sql
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
```

#### 2.2 Forensic Evaluation of AUD04 Trigger Bypass
Inside `public.run_retention_sweep()`, when the statement:
`DELETE FROM public.audit_logs WHERE created_at < v_now - interval '365 days';`
is executed:
1. Because the function is `SECURITY DEFINER` owned by `postgres`, `current_user` evaluates to `'postgres'`.
2. The trigger evaluates `current_user in ('service_role', 'postgres', ...)`. This expression evaluates to **`TRUE`**.
3. The exception is **NOT RAISED**. The trigger returns `OLD`, allowing the deletion of audit logs older than 365 days to proceed.
4. **Conclusion:** Source evidence conclusively confirms that `public.run_retention_sweep()` is architecturally designed to bypass the append-only trigger and delete historical audit records older than 365 days.

---

### 3. AFFECTED TABLES & GLOBAL DESTRUCTIVE BLAST RADIUS

`public.run_retention_sweep()` executes five discrete operations across the database:

```
+---------------------------+-----------------------------------+--------------------+---------------------------------------+
| Table                     | Delete Condition                  | Tenant Scope       | Architectural Description             |
+---------------------------+-----------------------------------+--------------------+---------------------------------------+
| 1. public.webrtc_signals  | created_at < now - 7 days         | GLOBAL (Un-scoped) | Hard-deletes signaling packets.       |
| 2. public.audit_logs      | created_at < now - 365 days       | GLOBAL (Un-scoped) | Hard-deletes historical audit logs.   |
| 3. public.location_events | recorded_at < now - family_window | Per-Family Loop    | Hard-deletes location telemetry.      |
| 4. public.usage_daily     | day < now - family_window         | Per-Family Loop    | Hard-deletes daily app screen time.   |
| 5. public.audit_logs      | [INSERT OPERATION]                | System Event       | Appends summary 'retention_sweep' log.|
+---------------------------+-----------------------------------+--------------------+---------------------------------------+
```

Because operations 1 and 2 are **global and un-scoped across all platform families**, running this function against a shared staging backend will permanently delete customer audit records and WebRTC signals.

---

### 4. SCHEDULER & EDGE FUNCTION INVOCATION TRACE

Source code inspection confirms the invocation chain for `public.run_retention_sweep()`:

#### 4.1 Invocation Route in Edge Function (`supabase/functions/cron/index.ts`)
```typescript
// supabase/functions/cron/index.ts:103-119
case "retention_sweep": {
  const rpc = await db.rpc("run_retention_sweep");
  if (rpc.error) {
    if (isMissingFunction(rpc.error)) {
      console.warn("retention_sweep_function_missing");
      return ok({ skipped: true, reason: "function_missing" });
    }
    console.error(`retention_sweep_rpc_failed:${rpc.error.code ?? "unknown"}`);
    throw new ApiError("internal_error", "Retention could not be applied.", 500);
  }
  return ok(rpc.data);
}
```

#### 4.2 Authentication & Invocation Security
- The `cron` Edge Function requires header `x-cron-secret`.
- Evaluates `constantTimeSecretEqual(provided, Deno.env.get("CRON_SECRET"))`.
- Calls the database using a service-role client (`db = getServiceClient()`).

#### 4.3 Deployed Scheduler Status
Forensic review of the entire repository reveals:
1. **No GitHub Actions Workflow:** The directory `.github/workflows` does not exist in the repository.
2. **No PostgreSQL Cron Extension:** No `pg_cron` extension is created or configured in any migration file.
3. **Status:** The retention sweep is callable **only via external HTTPS webhooks** providing `x-cron-secret`. **No automated background scheduler is active or deployed within the repository.**

---

### 5. AUTHORITATIVE COMPARISON: AUD03 PURGE VS AUD04 SWEEP

```
+-----------------------------------+-----------------------------------+-----------------------------------+
| Architectural Dimension           | AUD03: Manual Telemetry Purge     | AUD04: Automated Retention Sweep  |
+-----------------------------------+-----------------------------------+-----------------------------------+
| 1. Invocation Path                | Flutter UI -> family-admin        | External Cron -> cron Edge Func   |
| 2. Caller Authentication          | Authenticated Parent JWT          | Secret header (x-cron-secret)     |
| 3. Execution Client               | Service Client with Family Filter | Service Client calling DB RPC     |
| 4. Database Function Mode         | Direct table DELETE queries       | SECURITY DEFINER (postgres owner) |
| 5. Affected Tables                | location_events, usage_daily      | webrtc_signals, audit_logs, loc, u|
| 6. Audit Log Action               | ZERO DELETES (Appends data_purged)| PERMANENT HARD DELETE (>365 days) |
| 7. Multi-Tenant Boundary          | Hard-scoped: WHERE family_id = id | Global / Multi-Tenant un-scoped   |
| 8. Trigger Interaction            | Trigger not invoked on audit_logs | Bypasses trigger via postgres role|
| 9. Privileged Role Behavior       | Service client only deletes telem | Function owner deletes audit rows |
| 10. Automated Scheduler           | None (User-driven)                | Un-deployed / External HTTPS only |
| 11. Static Evidence               | SOURCE-VERIFIED in index.ts       | SOURCE-VERIFIED in retention.sql  |
| 12. Runtime Evidence              | NOT TESTED                        | NOT TESTED                        |
| 13. Current Authorization         | Quarantined (Requires E2)         | Prohibited on Shared DB (Req E3)  |
+-----------------------------------+-----------------------------------+-----------------------------------+
```

---

### 6. SOURCE-LEVEL SECURITY VERDICT FOR AUD04

```
========================================================================================
FINAL AUDIT VERDICT ON AUD04:
SECURITY DEFINER AND PRIVILEGED TRIGGER INTERACTION SOURCE-VERIFIED —
DEPLOYED STATE NOT VERIFIED
========================================================================================
1. public.run_retention_sweep() is a SECURITY DEFINER function owned by postgres with
   strict search_path isolation.
2. Execution of DELETE on public.audit_logs is statically proven to bypass the append-only
   trigger via the privileged postgres role exception.
3. The cron Edge Function provides a secure webhook entry point requiring CRON_SECRET.
4. However, no automated scheduler exists in the repository, and the function's deployment
   state on remote infrastructure is NOT VERIFIED.
5. Runtime execution on shared infrastructure remains STRICTLY PROHIBITED.
========================================================================================
```
