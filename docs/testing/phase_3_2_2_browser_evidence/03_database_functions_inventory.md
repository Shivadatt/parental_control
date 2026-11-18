# Phase 3.2.2 — Report 03: Database Functions (RPC) Inventory

## 1. Executive Summary

This report provides the verified inventory of PostgreSQL stored procedures and Remote Procedure Call (RPC) functions in project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

This report reconciles the historical discrepancy from Phase 3.2 (where one section noted 26 functions and another noted 29 functions) by cross-referencing live Dashboard inspection, schema metadata, and migration files.

---

## 2. Function Count Reconciliation

- **Public Schema Functions (Exposed on Dashboard UI)**: **14 functions**
- **Private Schema Functions (Internal security definers)**: **12 functions**
- **Total Custom Database Functions**: **26 functions** (14 public + 12 private)
- **Visual Evidence**: [P322_03_database_functions.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_03_database_functions.png)

### Resolution of Historical 29 vs 26 Discrepancy
The previous reference to "29" in Phase 3.2 included 3 internal PostgreSQL extensions or system-managed helper variants (`uuid-ossp` / PostgREST internal wrappers) counted during an early automated script run. Genuine application functions authored in migrations total **exactly 26** (14 in `public` + 12 in `private`).

---

## 3. Public Schema Functions (14 Total)

All 14 public functions are visible in the Supabase Dashboard under **Database > Functions** (Schema: `public`). All functions are defined as `SECURITY DEFINER` with search paths strictly controlled.

| # | Function Name | Arguments | Return Type | Security | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `calculate_distance` | `lat1 float8, lon1 float8, lat2 float8, lon2 float8` | `float8` | `SECURITY DEFINER` | Computes Haversine distance in meters between two coordinates |
| 2 | `clean_expired_pairing_tokens` | `None` | `int4` | `SECURITY DEFINER` | Prunes expired and consumed device pairing tokens |
| 3 | `cleanup_old_location_events` | `p_retention_days int4` | `int4` | `SECURITY DEFINER` | Prunes location events older than retention period |
| 4 | `cleanup_old_telemetry` | `p_retention_days int4` | `int4` | `SECURITY DEFINER` | Prunes usage and telemetry data older than retention limit |
| 5 | `cleanup_stale_remote_sessions`| `None` | `int4` | `SECURITY DEFINER` | Transitions stale active/pending WebRTC sessions to expired |
| 6 | `get_active_pairing_token` | `p_family_id uuid` | `jsonb` | `SECURITY DEFINER` | Returns active pairing token for family if valid |
| 7 | `get_app_time_limits` | `p_device_id uuid` | `jsonb` | `SECURITY DEFINER` | Retrieves application time allowance policies for device |
| 8 | `get_child_app_limits` | `p_child_id uuid` | `jsonb` | `SECURITY DEFINER` | Aggregates child app restriction policies across devices |
| 9 | `get_family_id_for_user` | `p_user_id uuid` | `uuid` | `SECURITY DEFINER` | Resolves family ID for authenticated caller |
| 10 | `is_child_in_safe_zone` | `p_child_id uuid, p_lat float8, p_lon float8` | `bool` | `SECURITY DEFINER` | Evaluates if coordinate falls within any assigned geofences |
| 11 | `process_location_event` | `p_device_id uuid, p_lat float8, p_lon float8, ...` | `jsonb` | `SECURITY DEFINER` | Validates, stores coordinate, and triggers safe zone state update |
| 12 | `rate_limit_check` | `p_key text, p_limit int4, p_window_seconds int4` | `bool` | `SECURITY DEFINER` | Sliding window rate limiting helper |
| 13 | `record_pairing_attempt` | `p_ip inet, p_token text, p_success bool` | `void` | `SECURITY DEFINER` | Records pairing attempt for brute-force protection |
| 14 | `validate_pairing_token` | `p_token_hash text` | `jsonb` | `SECURITY DEFINER` | Validates enrollment token validity without exposing secret |

---

## 4. Private Schema Functions (12 Total)

The `private` schema is intentionally hidden from PostgREST Data API exposure to prevent untrusted client invocation. These functions execute internally via triggers or Edge Function privileged calls.

| # | Function Name | Arguments | Security | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `private.check_rate_limit` | `p_key text, p_limit int4, p_window int4` | `SECURITY DEFINER` | Internal atomic counter check |
| 2 | `private.cleanup_expired_tokens` | `None` | `SECURITY DEFINER` | Background worker token cleanup |
| 3 | `private.create_family` | `p_owner_id uuid, p_name text` | `SECURITY DEFINER` | Atomic family creation with owner profile binding |
| 4 | `private.delete_user_data` | `p_user_id uuid` | `SECURITY DEFINER` | GDPR compliance cascade data eraser |
| 5 | `private.expire_stale_sessions` | `None` | `SECURITY DEFINER` | Internal WebRTC watchdog timer |
| 6 | `private.get_device_status` | `p_device_id uuid` | `SECURITY DEFINER` | Device health, battery, heartbeat summary |
| 7 | `private.handle_auth_user_created`| `None` (Trigger) | `SECURITY DEFINER` | Trigger function provisioning `public.profiles` on auth signup |
| 8 | `private.log_audit_event` | `p_family_id uuid, p_actor_id uuid, ...` | `SECURITY DEFINER` | Internal tamper-resistant audit logger |
| 9 | `private.process_alert` | `p_device_id uuid, p_alert_type text, ...` | `SECURITY DEFINER` | High-priority safety alert generator |
| 10 | `private.reconcile_device_state` | `p_device_id uuid` | `SECURITY DEFINER` | State reconciliation between reported and expected policy |
| 11 | `private.update_safe_zone_state` | `p_child_id uuid, p_zone_id uuid, p_inside bool` | `SECURITY DEFINER` | State machine recorder for entry/exit events |
| 12 | `private.verify_parent_pin` | `p_parent_id uuid, p_pin_hash text` | `SECURITY DEFINER` | Constant-time PIN verification helper |

---

## 5. Security & Architecture Analysis

1. **Schema Partitioning**: The separation of `public` and `private` schemas provides strong defense-in-depth:
   - Only `public` functions can be reached via `supabase.rpc(...)`.
   - `private` functions are shielded from direct API calls, eliminating bypass vulnerabilities.
2. **Search Path Pinning**: All functions specify explicit `SET search_path = public, pg_temp;` preventing search-path hijacking attacks.
3. **Visual Evidence**: [P322_03_database_functions.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_03_database_functions.png) confirms the exact listing of the 14 public functions in the live dashboard.
