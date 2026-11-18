# Phase 3.2.4 — Report 01: Database RPC Function EXECUTE Privilege Matrix

## 1. Executive Summary

This report delivers the verified privilege matrix of Remote Procedure Call (RPC) functions in `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

The evaluation was conducted by cross-referencing:
1. Live accessibility snapshots of the Supabase Functions dashboard (`/database/functions`).
2. Schema migration definitions (`20260101000100_functions.sql`, `20260101000400_device_recovery.sql`, `20260101000600_atomic_pairing_invite.sql`, `20261028000200_parent_controlled_session_lifetime.sql`).
3. Explicit PostgreSQL `REVOKE` and `GRANT` DDL directives.

---

## 2. Public Schema Functions Privilege Matrix (14 Functions)

All 14 functions residing in the `public` schema were created as wrappers to allow PostgREST execution. However, PostgreSQL grants `EXECUTE` to `PUBLIC` by default. The migration scripts explicitly revoke all execution privileges from unprivileged roles.

| # | Function Signature | PUBLIC | anon | authenticated | service_role | PostgREST Client Exposure |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 1 | `public.apply_policy_version(uuid, jsonb, uuid, text)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 2 | `public.create_family_with_owner(uuid, text)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 3 | `public.create_pairing_invite(uuid, uuid, uuid, text, timestamptz)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 4 | `public.create_pairing_request(uuid, uuid, uuid, uuid, timestamptz)`| **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 5 | `public.detect_offline_devices()` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 6 | `public.expire_stale_commands(uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 7 | `public.expire_stale_sessions()` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 8 | `public.poll_device_commands(uuid, integer)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 9 | `public.replace_device_apps(uuid, uuid, jsonb)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 10 | `public.request_device_recovery(uuid, uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 11 | `public.request_remote_session(uuid, uuid, text)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 12 | `public.respond_pairing_request(uuid, uuid, boolean)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 13 | `public.revoke_device(uuid, uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |
| 14 | `public.unlink_child(uuid, uuid, uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | **BLOCKED (401/403)** |

---

## 3. Private Schema Functions Privilege Matrix (12 Functions)

The `private` schema is **NOT exposed** to PostgREST at the API gateway layer (`db-schemas = "public"`).

| # | Function Signature | PUBLIC | anon | authenticated | service_role | Purpose & Direct Reachability |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 1 | `private.set_updated_at()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Trigger function (synchronous row update) |
| 2 | `private.handle_new_user()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Auth trigger function on `auth.users` |
| 3 | `private.profiles_before_update()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Trigger function preventing role escalation |
| 4 | `private.families_before_update()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Trigger function protecting family ownership |
| 5 | `private.audit_logs_append_only()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Trigger function preventing audit modification |
| 6 | `private.is_family_member(uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | RLS policy helper (called internally by Postgres) |
| 7 | `private.is_family_parent(uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | RLS policy helper (called internally by Postgres) |
| 8 | `private.shares_active_family(uuid)` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | RLS policy helper (called internally by Postgres) |
| 9 | `private.record_audit(...)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | Internal audit logging engine |
| 10 | `private.create_family_with_owner(uuid, text)` | **REVOKED** | **REVOKED** | **REVOKED** | **GRANTED** | Core family provisioning transaction |
| 11 | `private.realtime_topic_allowed(text)` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Realtime subscription authorization guard |
| 12 | `private.remote_session_transition_guard()` | **REVOKED** | **REVOKED** | **REVOKED** | **EXECUTE** | Trigger function protecting WebRTC session state |

---

## 4. Key Security Invariants & Audit Findings

1. **Zero Client PostgREST Exposure:**
   - None of the 14 public RPC functions can be executed directly by mobile clients using their standard user JWT or anon key.
   - Any client attempt to call `/rest/v1/rpc/<function_name>` produces an immediate PostgreSQL exception: `permission denied for function <function_name>`.
2. **Strict Mediation via Edge Functions:**
   - All state-changing operations (pairing, policy application, remote session request, unlinking) are mediated exclusively through Supabase Edge Functions.
   - Edge Functions authenticate callers using `requireUser(req)` or `requireFamilyParent(...)`, validate the business payload, and then invoke the RPC using `service_role` credentials.
3. **No Unintended Public Grants:**
   - Explicit `REVOKE ALL ON FUNCTION ... FROM public, anon, authenticated;` was verified for all application procedures, eliminating PostgreSQL's default public execution vulnerability.
