# Phase 3.2.3 — Report 04: Database Stored Procedure (RPC) Security Review

## 1. Executive Summary

This report delivers a deep security evaluation of all **26 application database functions** in `parent-control-prod` (14 in `public` schema and 12 in `private` schema).

The review focuses on:
1. `SECURITY DEFINER` vs. `SECURITY INVOKER` privileges.
2. Search path pinning against search-path injection.
3. PostgREST `EXECUTE` grants and caller authorization.
4. Input validation and SQL injection immunity.

---

## 2. Public Schema Functions Security Audit (14 Functions)

All 14 public functions are callable via PostgREST RPC (`/rest/v1/rpc/<function_name>`) by authenticated callers.

| # | Function Name | Privileges | `search_path` | Public EXECUTE Revoked | Authorization & Security Controls |
| :--- | :--- | :---: | :---: | :---: | :--- |
| 1 | `calculate_distance` | `SECURITY DEFINER` | `public, pg_temp` | YES | Pure mathematical formula (Haversine); immutable, no table reads or mutations. Zero side-effects. |
| 2 | `clean_expired_pairing_tokens` | `SECURITY DEFINER` | `public, pg_temp` | YES | Prunes pairing tokens older than TTL. Idempotent maintenance task. Restricted to service role. |
| 3 | `cleanup_old_location_events` | `SECURITY DEFINER` | `public, pg_temp` | YES | Accepts `p_retention_days int4`. Clamps parameter to positive integer. Service role caller only. |
| 4 | `cleanup_old_telemetry` | `SECURITY DEFINER` | `public, pg_temp` | YES | Prunes telemetry older than retention days. Clamped parameter. Service role caller only. |
| 5 | `cleanup_stale_remote_sessions`| `SECURITY DEFINER` | `public, pg_temp` | YES | Transitions timed-out sessions to expired. Idempotent state machine cleanup. |
| 6 | `get_active_pairing_token` | `SECURITY DEFINER` | `public, pg_temp` | YES | Verifies caller is active parent of `p_family_id` before returning active token hash. |
| 7 | `get_app_time_limits` | `SECURITY DEFINER` | `public, pg_temp` | YES | Checks that caller owns or monitors `p_device_id` before reading app limits. |
| 8 | `get_child_app_limits` | `SECURITY DEFINER` | `public, pg_temp` | YES | Checks caller is parent of child before aggregating limits. |
| 9 | `get_family_id_for_user` | `SECURITY DEFINER` | `public, pg_temp` | YES | Helper function resolving `family_id` for `auth.uid()`. Read-only. |
| 10 | `is_child_in_safe_zone` | `SECURITY DEFINER` | `public, pg_temp` | YES | Geofence distance evaluation. Reads safe zones for caller's family only. |
| 11 | `process_location_event` | `SECURITY DEFINER` | `public, pg_temp` | YES | Ingests coordinates, verifies device ownership, triggers safe zone entry/exit calculation. Parameterized queries eliminate SQL injection. |
| 12 | `rate_limit_check` | `SECURITY DEFINER` | `public, pg_temp` | YES | Sliding window rate limit check. Atomic counter; prevents DDoS. |
| 13 | `record_pairing_attempt` | `SECURITY DEFINER` | `public, pg_temp` | YES | Records pairing failure attempts for anti-brute force tracking. Parameterized inet/text. |
| 14 | `validate_pairing_token` | `SECURITY DEFINER` | `public, pg_temp` | YES | Validates token hash constant-time against active pairing tokens. Never leaks secret salt or unhashed token. |

---

## 3. Private Schema Functions Security Audit (12 Functions)

The `private` schema is **NOT exposed** to PostgREST (`db-schemas = "public"`). Functions in `private` can only be invoked internally by triggers, public RPC wrappers, or direct backend SQL connections.

| # | Function Name | Privileges | `search_path` | Purpose & Protection |
| :--- | :--- | :---: | :---: | :--- |
| 1 | `private.check_rate_limit` | `SECURITY DEFINER` | `public, private, pg_temp` | Internal rate limiter logic. |
| 2 | `private.cleanup_expired_tokens` | `SECURITY DEFINER` | `public, private, pg_temp` | Scheduled worker token purger. |
| 3 | `private.create_family` | `SECURITY DEFINER` | `public, private, pg_temp` | Atomic family creator; ensures owner is automatically added to `family_members`. |
| 4 | `private.delete_user_data` | `SECURITY DEFINER` | `public, private, pg_temp` | Cascade data wiper for user deletion. Restricted to service role. |
| 5 | `private.expire_stale_sessions` | `SECURITY DEFINER` | `public, private, pg_temp` | Internal WebRTC watchdog timer. |
| 6 | `private.get_device_status` | `SECURITY DEFINER` | `public, private, pg_temp` | Summary aggregator for device health. |
| 7 | `private.handle_auth_user_created`| `SECURITY DEFINER` | `public, private, pg_temp` | Auth trigger creating profile upon email sign-up. Reads `new.id` and `new.email`. |
| 8 | `private.log_audit_event` | `SECURITY DEFINER` | `public, private, pg_temp` | Internal audit logger. Direct INSERT into append-only `audit_logs`. |
| 9 | `private.process_alert` | `SECURITY DEFINER` | `public, private, pg_temp` | Internal emergency alert dispatcher. |
| 10 | `private.reconcile_device_state` | `SECURITY DEFINER` | `public, private, pg_temp` | Compares device reported policy version with desired policy version. |
| 11 | `private.update_safe_zone_state` | `SECURITY DEFINER` | `public, private, pg_temp` | Updates state machine when child crosses geofence boundary. |
| 12 | `private.verify_parent_pin` | `SECURITY DEFINER` | `public, private, pg_temp` | Verifies parent PIN hash; constant-time check. |

---

## 4. Key Security Findings & Defenses

1. **Search Path Hijacking Defense:**
   - Every single function explicitly executes with:
     `SET search_path = public, pg_temp;` (or `public, private, pg_temp;`).
   - This neutralizes the classic PostgreSQL `SECURITY DEFINER` vulnerability where a malicious user creates a temporary table/function in `pg_temp` or a shadowed schema to capture execution context.
2. **PostgreSQL Default EXECUTE Revocation:**
   - PostgreSQL grants `EXECUTE ON FUNCTION` to `PUBLIC` by default.
   - The migrations explicitly execute `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;`.
   - Only explicitly authorized functions are granted to `authenticated` or `service_role`.
3. **SQL Injection Analysis:**
   - Zero dynamic SQL (`EXECUTE format(...)`) is used without strict parameterization.
   - All database functions use native PL/pgSQL variable binding (`$1`, `$2`, or named parameters), rendering SQL injection impossible.
