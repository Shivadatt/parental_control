# HAVEN PARENT CONTROL — PHASE 2.7.9
## DELIVERABLE 02: POSTGRESQL IDENTITY & SECURITY DEFINER SEMANTICS

**Document ID:** `HAVEN-GOV-PHASE2-7-9-DOC02`  
**Phase:** Phase 2.7.9 — PostgreSQL Identity Semantics, Function Ownership & Final Security Evidence Closure  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Actual Git HEAD:** `20cc0b1439ebea1b3808d769e7b91b646a9fe089`  
**Parent Commit:** `e5022531beeb7393a7a5585351af891180630216`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** Forensic PostgreSQL Identity, Privilege & Execution-Context Analysis  

---

### 1. OBJECTIVE & TECHNICAL MOTIVATION

In PostgreSQL database security, determining whether a query or function call will succeed or be blocked by a trigger or Row-Level Security (RLS) policy requires precision regarding the active database identity. 

Previous audit reports frequently conflated `current_user`, `session_user`, connection roles, function owners, and JWT role claims. This deliverable provides the authoritative, standards-compliant definition of PostgreSQL execution identities as they operate within the Haven database architecture.

---

### 2. CORE POSTGRESQL IDENTITY CONCEPTS

#### 2.1 `current_user` (The Effective Execution Role)
- **Definition:** The active role identity evaluated by PostgreSQL for all object permission checks, table privilege enforcement, trigger execution, and Row-Level Security policy evaluation.
- **Dynamic Behavior:** `current_user` can change within a session:
  1. Explicitly via the SQL command `SET ROLE <role_name>`.
  2. Automatically when executing a function marked `SECURITY DEFINER`. Inside the function body, `current_user` becomes the function's owning role.
- **Relevance to Haven:** The trigger function `private.audit_logs_append_only()` explicitly checks `current_user in ('service_role', 'postgres', ...)`. Thus, `current_user` is the sole database role evaluated by the append-only trigger.

#### 2.2 `session_user` (The Original Connection Identity)
- **Definition:** The identity of the authenticated database user who established the physical database connection.
- **Invariance:** `session_user` **never changes** when entering a `SECURITY DEFINER` function, and never changes under `SET ROLE`.
- **Alteration:** Can only be altered via `SET SESSION AUTHORIZATION <role_name>`, which strictly requires superuser privileges.
- **Relevance to Haven:** Neither the RLS policies in `supabase/migrations/20260101000200_rls.sql` nor the trigger in `20260101000000_core.sql` evaluate `session_user`. Asserting that `session_user` causes a trigger exception is technically false.

#### 2.3 `SET ROLE` Semantics
- **Operation:** Executes `SET ROLE <target_role>` or `SET LOCAL ROLE <target_role>`.
- **Behavior:** Changes `current_user` to `<target_role>`, provided that the current `session_user` is a member of that target role.
- **Scope:** Leaves `session_user` completely untouched.

#### 2.4 `SECURITY INVOKER` vs `SECURITY DEFINER`
- **`SECURITY INVOKER` (PostgreSQL Default):**
  The function body executes with the privileges of the calling user. `current_user` and `session_user` remain unchanged. All queries inside the function are subject to the caller's RLS policies and table grants.
- **`SECURITY DEFINER`:**
  The function body executes with the privileges of the role that **owns** the function (recorded in `pg_proc.proowner`).
  - Upon entry, PostgreSQL automatically sets `current_user = function_owner`.
  - Queries inside the function bypass RLS unless `security_invoker = true` is set (PostgreSQL 15+).
  - Upon function exit (or rollback), PostgreSQL restores `current_user` to the calling role.
  - `session_user` remains the client connection identity throughout execution.

#### 2.5 Function Owner (`pg_proc.proowner`)
- **Definition:** The database role that owns the function object.
- **Assignment:** Defaults to the role that executed the `CREATE FUNCTION` statement. Can be reassigned only via an explicit SQL statement: `ALTER FUNCTION <name> OWNER TO <new_owner>`.
- **Search Path Invariant:** `SECURITY DEFINER` functions in Haven strictly enforce `SET search_path = public, private, pg_temp` to prevent malicious object substitution.

#### 2.6 PostgREST & Supabase Request Context (`request.jwt.claim.role`)
- **Architecture:** PostgREST establishes pooled database connections as a connection role (typically `authenticator`).
- **Transaction Initialization:** For each incoming HTTP request carrying an `Authorization: Bearer <JWT>` header, PostgREST executes:
  ```sql
  SET LOCAL ROLE <jwt_role>; -- e.g. 'authenticated', 'anon', or 'service_role'
  SET LOCAL "request.jwt.claim.role" = '<jwt_role>';
  SET LOCAL "request.jwt.claim.sub" = '<user_uuid>';
  ```
- **Distinction from PostgreSQL Native Roles:** The JWT claim `request.jwt.claim.role` is an application-level configuration parameter accessed via `current_setting('request.jwt.claim.role', true)`. It is distinct from native PostgreSQL catalog roles, although PostgREST aligns `current_user` with the claim via `SET LOCAL ROLE`.

---

### 3. AUTHORITATIVE EXECUTION IDENTITY MATRIX

```
+-----------------------------------+-----------------------------------+-----------------------------------+-------------------------------+---------------------------+
| Execution Context                 | current_user                      | session_user                      | request.jwt.claim.role        | Evidence Status           |
+-----------------------------------+-----------------------------------+-----------------------------------+-------------------------------+---------------------------+
| 1. Ordinary Client RPC Invocation | authenticated (or anon)           | authenticator (connection user)   | 'authenticated' (from JWT)    | SOURCE-VERIFIED (PostgREST|
| 2. Inside Helper (SECURITY DEFINER| Function Owner (postgres)         | authenticator (connection user)   | 'authenticated' (from JWT)    | SOURCE-VERIFIED (core.sql)|
| 3. Inside Function (SEC INVOKER)  | authenticated (caller role)       | authenticator (connection user)   | 'authenticated' (from JWT)    | SOURCE-VERIFIED (PG Spec) |
| 4. Execution After SET ROLE       | target_role                       | Unchanged (original connection)   | Depends on caller context     | SOURCE-VERIFIED (PG Spec) |
| 5. Service-Role Edge Function SDK | service_role                      | authenticator (or postgres)       | 'service_role' (from key JWT) | SOURCE-VERIFIED (auth.ts) |
| 6. AUD04 run_retention_sweep()    | Function Owner (deployed postgres)| authenticator (or service_role)   | 'service_role' (from cron call| DEPLOYED OWNER REQ VERIF  |
+-----------------------------------+-----------------------------------+-----------------------------------+-------------------------------+---------------------------+
```

---

### 4. RELEVANCE TO AUD04 AND TRIGGER SECURITY

In `supabase/migrations/20260101000000_core.sql:543-565`, `private.audit_logs_append_only()` defines its security check:

```sql
if tg_op in ('UPDATE', 'DELETE')
   and not (
     current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')
     or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
   ) then
  raise exception 'audit_logs is append-only' using errcode = '42501';
end if;
```

#### Precise Identity Deduction:
1. When `public.run_retention_sweep()` executes, it runs as `SECURITY DEFINER`.
2. Inside its execution block, PostgreSQL sets `current_user` to the function's owner.
3. If the deployed function owner is `postgres`, `current_user` evaluates to `'postgres'`.
4. The trigger condition evaluates:
   `'postgres' in ('service_role', 'postgres', ...)` $\rightarrow$ **`TRUE`**.
5. The exception is **bypassed**, and the `DELETE FROM public.audit_logs` statement succeeds.
6. If the function owner were instead a non-privileged role, `current_user` would not match, and the trigger would abort the retention sweep with SQLSTATE `42501`.
7. **Conclusion:** The trigger bypass in AUD04 is fundamentally mediated by **`current_user` (the function owner)**, NOT by `session_user`.
