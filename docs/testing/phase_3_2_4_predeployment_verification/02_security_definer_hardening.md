# Phase 3.2.4 — Report 02: SECURITY DEFINER Hardening & Privilege Escalation Audit

## 1. Executive Summary

This report evaluates the `SECURITY DEFINER` implementation across all 26 application functions in `parent-control-prod`.

### Why `SECURITY DEFINER` Hardening Matters
Functions defined with `SECURITY DEFINER` execute with the privileges of the user that owns the function (typically `postgres` or `supabase_admin`). In PostgreSQL, an improperly hardened `SECURITY DEFINER` function represents a severe privilege escalation risk if:
1. The `search_path` is mutable or unpinned, allowing schema poisoning via malicious `pg_temp` objects.
2. Unprivileged roles possess `EXECUTE` privileges.
3. Unprivileged roles have `CREATE` privileges on schemas in the `search_path`.
4. Functions construct and execute unparameterized dynamic SQL.

---

## 2. Hardening Audit Parameters across All 26 Functions

### 1. Exact `search_path` Configuration
Every function in both `public` and `private` schemas enforces an explicit, immutable `search_path` parameter pinned at definition time:

- **Public Wrapper Functions (14):**
  ```sql
  SET search_path = public, private, pg_temp;
  ```
  *(or `SET search_path = public, pg_temp;`)*
- **Private Schema Functions (12):**
  ```sql
  SET search_path = public, private, pg_temp;
  ```

### 2. Schema `CREATE` Privileges Verification
- **PostgreSQL 15+ Default Posture:** In PostgreSQL 15 and 17 (the hosted version is `17.11`), the default `CREATE` privilege on the `public` schema was removed from `PUBLIC`.
- **Database Grants Audit:**
  - Neither `anon` nor `authenticated` has `CREATE` privileges on schema `public` or `private`.
  - An attacker cannot inject a malicious table, function, or view into `public` or `private` to shadow legitimate database objects.

### 3. Temporary Schema Exposure (`pg_temp`)
- In all definitions, `pg_temp` is placed **at the very end** of the search path:
  `SET search_path = public, private, pg_temp;`
- Because PostgreSQL searches schemas strictly from left to right, any temporary table or function created by a caller in `pg_temp` cannot shadow objects in `public` or `private`.

### 4. Object Qualification & Dynamic SQL Audit
- **Full Qualification:** All table and view references inside function bodies are fully qualified with their schema namespace (e.g., `FROM public.devices`, `FROM public.family_members`, `FROM public.audit_logs`).
- **Dynamic SQL:** Zero functions utilize `EXECUTE format(...)` with untrusted string concatenation. All SQL execution is statically planned and uses native PL/pgSQL variable binding (`$1`, `$2`), eliminating SQL injection.

---

## 3. Comprehensive Function Hardening Matrix

| # | Function | Schema | Security Mode | `search_path` | Dynamic SQL? | Public Execute? | Risk Level |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | `apply_policy_version` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 2 | `create_family_with_owner` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 3 | `create_pairing_invite` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 4 | `create_pairing_request` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 5 | `detect_offline_devices` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 6 | `expire_stale_commands` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 7 | `expire_stale_sessions` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 8 | `poll_device_commands` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 9 | `replace_device_apps` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 10 | `request_device_recovery` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 11 | `request_remote_session` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 12 | `respond_pairing_request` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 13 | `revoke_device` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 14 | `unlink_child` | `public` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 15 | `set_updated_at` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 16 | `handle_new_user` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 17 | `profiles_before_update` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 18 | `families_before_update` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 19 | `audit_logs_append_only` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 20 | `is_family_member` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 21 | `is_family_parent` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 22 | `shares_active_family` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 23 | `record_audit` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 24 | `create_family_with_owner` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 25 | `realtime_topic_allowed` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |
| 26 | `remote_session_transition_guard` | `private` | `SECURITY DEFINER` | `public, private, pg_temp` | NO | REVOKED | **SECURE** |

---

## 4. Privilege Escalation Assessment

### Threat Modeling Scenario:
Could an untrusted mobile client exploit any `SECURITY DEFINER` function to gain unauthorized superuser or cross-family access?
1. **Direct PostgREST Invocation:** **BLOCKED**. PostgREST checks function privileges before invoking. Since `EXECUTE` is revoked from `anon` and `authenticated`, the caller receives a 403 Forbidden error immediately.
2. **Schema Poisoning Attack:** **BLOCKED**. `search_path` is pinned; neither `anon` nor `authenticated` has schema `CREATE` privileges; and `pg_temp` is placed after `public` and `private`.
3. **Trigger Bypassing:** **BLOCKED**. Trigger functions are invoked by Postgres internals during row lifecycle events, not through PostgREST endpoints.

## 5. Security Verdict
All 26 application functions meet strict defense-in-depth criteria for `SECURITY DEFINER` hardening.
