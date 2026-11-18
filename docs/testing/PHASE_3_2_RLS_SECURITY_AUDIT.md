# PHASE 3.2 — ROW LEVEL SECURITY (RLS) SECURITY AUDIT

**Project:** Parent Control System (`parentcontrol_app`)  
**Target Project Name:** `parent-control-prod`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Target Cloud Region:** `ap-south-1`  
**Audit Execution Timestamp:** 2026-11-18T15:15:00+05:30  
**Audit Scope:** Database RLS Policies, Grant Catalogs, Client Mutation Boundaries, Schema Privilege Separation  
**Execution Mode:** STRICT READ-ONLY AUDIT  

---

## 1. ROW LEVEL SECURITY ARCHITECTURAL MODEL

The security model of the Parent Control backend adheres to the principle of least privilege, employing strict multi-tenant isolation through PostgreSQL Row-Level Security:

1. **Deny-by-Default Foundation:** Every table in the `public` schema has Row-Level Security enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`). PostgREST clients (`anon` and `authenticated`) can execute queries only when an explicit, evaluated policy evaluates to `TRUE`.
2. **Role Separation (`parent` vs `child`):**
   - The user's role is bound to `public.profiles.role` (`'parent'` or `'child'`).
   - Parents have read-only visibility into their family's aggregated telemetry, alerts, and enrolled devices, and write access limited to declarative configurations (`safe_zones`).
   - Children have read access restricted strictly to their own assigned devices and policies; they have zero visibility into other children's devices, location telemetry, or family administration.
3. **Mediation Tier for Sensitive Mutations:**
   - Critical domain mutations—including device enrollment, policy assignment, pairing negotiation, account deletion, unlinking, and hardware revocation—are **strictly blocked from direct PostgREST client execution**.
   - These operations must traverse Deno Edge Functions using the `service_role` key, where business validation, multi-factor consent checks, and audit logging are enforced prior to database writes.

---

## 2. TABLE-BY-TABLE RLS POLICY MATRIX

The table below catalogs every Row-Level Security policy defined across the database schema:

| # | Target Table | Policy Name | Command | Target Roles | `USING` Clause Logic | `WITH CHECK` Clause Logic | Direct Write Permitted? |
|---|---|---|---|---|---|---|---|
| 1 | `profiles` | `profiles_select_self_or_family` | `SELECT` | `authenticated` | `id = auth.uid() OR private.shares_active_family(id)` | N/A | **NO** |
| 2 | `profiles` | `profiles_update_self` | `UPDATE` | `authenticated` | `id = auth.uid()` | `id = auth.uid()` (Trigger forbids changing `role`) | **YES** (Display Name only) |
| 3 | `families` | `families_select_members` | `SELECT` | `authenticated` | `private.is_family_member(id)` | N/A | **NO** |
| 4 | `families` | `families_update_owner` | `UPDATE` | `authenticated` | `owner_id = auth.uid()` | `owner_id = auth.uid()` | **YES** (Settings only) |
| 5 | `family_members` | `family_members_select_family` | `SELECT` | `authenticated` | `private.is_family_member(family_id)` | N/A | **NO** (Writes via Edge Functions) |
| 6 | `devices` | `devices_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR child_user_id = auth.uid()` | N/A | **NO** (Writes via Edge Functions) |
| 7 | `device_pairing_tokens`| *(No client policy)* | N/A | *(None)* | **BLOCKED** — Service role only | **BLOCKED** | **NO** (Strict Service Role) |
| 8 | `pairing_requests` | `pairing_requests_select_participants` | `SELECT` | `authenticated` | `parent_user_id = auth.uid() OR child_user_id = auth.uid()` | N/A | **NO** (Writes via Edge Functions) |
| 9 | `device_policies` | `device_policies_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = device_policies.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Writes via Edge Functions) |
| 10 | `device_commands` | `device_commands_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = device_commands.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Writes via Edge Functions) |
| 11 | `usage_daily` | `usage_daily_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = usage_daily.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Child Daemons write via HMAC Edge) |
| 12 | `location_events` | `location_events_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = location_events.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Child Daemons write via HMAC Edge) |
| 13 | `device_apps` | `device_apps_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = device_apps.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Uploaded via Edge Telemetry) |
| 14 | `safe_zones` | `safe_zones_select_family` | `SELECT` | `authenticated` | `private.is_family_member(family_id)` | N/A | **NO** |
| 15 | `safe_zones` | `safe_zones_insert_parent` | `INSERT` | `authenticated` | N/A | `private.is_family_parent(family_id)` | **YES** (Parent direct insert) |
| 16 | `safe_zones` | `safe_zones_update_parent` | `UPDATE` | `authenticated` | `private.is_family_parent(family_id)` | `private.is_family_parent(family_id)` | **YES** (Parent direct update) |
| 17 | `safe_zones` | *(DELETE policy revoked in Phase 1)* | `DELETE` | *(None)* | **BLOCKED** — Direct DELETE revoked. Must use `delete_safe_zone_audited` RPC. | N/A | **NO** (Audited RPC Required) |
| 18 | `safe_zone_states` | *(No client write policy)* | `SELECT` | `authenticated` | Inherits parent family check | N/A | **NO** (Updated via backend engine) |
| 19 | `safety_alerts` | `safety_alerts_select_parent_or_child` | `SELECT` | `authenticated` | `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = safety_alerts.device_id AND d.child_user_id = auth.uid())` | N/A | **NO** (Generated via backend/Edge) |
| 20 | `remote_sessions` | `remote_sessions_select_participants` | `SELECT` | `authenticated` | `parent_user_id = auth.uid() OR child_user_id = auth.uid()` | N/A | **NO** (Managed via Edge RPCs) |
| 21 | `webrtc_signals` | `webrtc_signals_select_participant` | `SELECT` | `authenticated` | Session participant check (`parent_user_id = auth.uid() OR child_user_id = auth.uid()`) | N/A | **NO** |
| 22 | `webrtc_signals` | `webrtc_signals_insert_participant` | `INSERT` | `authenticated` | N/A | Caller must be verified session participant and session must be in `accepted` or `active` state | **YES** (Signaling exchange) |
| 23 | `audit_logs` | `audit_logs_select_family_parent` | `SELECT` | `authenticated` | `private.is_family_parent(family_id)` | N/A | **NO** (Trigger/Service Role Only) |
| 24 | `pairing_attempts` | *(No client policy)* | N/A | *(None)* | **BLOCKED** — Service role only | **BLOCKED** | **NO** (Service Role Only) |
| 25 | `child_contact_ids`| `child_contact_ids_select_all` | `SELECT` | `authenticated` | `TRUE` (Public directory for lookup) | N/A | **NO** (Insert via Pairing RPC only) |

---

## 3. CRITICAL SECURITY INVARIANTS & ACCESS RESTRICTIONS

### 3.1 Hardened Invariants
1. **Schema-Level Isolation (`private` schema):**
   - Direct PostgREST execution of functions inside `private` is completely blocked:
     ```sql
     REVOKE ALL ON SCHEMA private FROM public, anon, authenticated;
     GRANT USAGE ON SCHEMA private TO service_role;
     ```
   - Malicious HTTP clients cannot call internal helpers such as `private.is_parent_of_family()` or `private.record_audit()` over REST.

2. **Audit Ledger Immutability (`public.audit_logs`):**
   - The `audit_logs` table is append-only.
   - Enforced by PostgreSQL trigger `audit_logs_append_only`:
     ```sql
     CREATE TRIGGER audit_logs_append_only
     BEFORE UPDATE OR DELETE ON public.audit_logs
     FOR EACH ROW EXECUTE FUNCTION private.audit_logs_append_only();
     ```
   - Attempted updates or deletions by any role raise exception code `27000` (`audit_logs are immutable; updates and deletes are forbidden`).

3. **Safe Zone Deletion Audit Gap Closure (Phase 1 Hardening):**
   - Migration `20261030000200_phase1_authorization.sql` permanently revoked direct table-level `DELETE` on `public.safe_zones` for `authenticated` and removed `safe_zones_delete_parent`.
   - Safe zone deletions are strictly channeled through the `family-admin` Edge Function and `delete_safe_zone_audited` RPC, ensuring zero unaudited geofence deletions can occur.

4. **WebRTC State Machine Guard (`public.remote_sessions`):**
   - Trigger `remote_sessions_transition_guard` validates legal state transitions (`requested` -> `accepted` / `rejected` -> `active` -> `ended`). Illegal jumps directly from `requested` to `ended` without child consent or invalid state rollbacks are rejected by the database.

---

## 4. RLS GAP ANALYSIS & HOSTED OBSERVATION

A comparison between local migration specifications and hosted database state:

| Security Vector | Expected Baseline | Hosted Status | Audit Result |
|---|---|---|---|
| **RLS Status on 19 Tables** | Enabled on 100% of tables | Enabled on all 19 tables in `public` | **PASS** |
| **Anonymous Access** | Zero access to tables without auth | PostgREST blocks all unauthenticated SELECT/INSERT/UPDATE/DELETE | **PASS** |
| **Child Data Isolation** | Children cannot read sibling data | Child queries filtered strictly to `auth.uid()` or own `device_id` | **PASS** |
| **Audit Immutability** | Append-only; triggers active | Append-only trigger active on `audit_logs` | **PASS** |
| **Safe Zone Unaudited Delete** | Direct DELETE revoked | Direct DELETE revoked on `safe_zones` | **PASS** |

---

## 5. MANDATORY SAFETY ASSERTIONS

```
TARGET_PROJECT_NAME = parent-control-prod
TARGET_PROJECT_REF = hhqgreaoqulmfwfwarhc
OTHER_PROJECTS_ACCESSED = NO
SOURCE_MODIFICATIONS = NONE
DATABASE_MUTATIONS = NONE
RLS_CHANGES = NONE
EDGE_FUNCTION_DEPLOYMENTS = NONE
AUTH_SETTINGS_CHANGED = NONE
STORAGE_CHANGES = NONE
REALTIME_CONFIGURATION_CHANGED = NONE
RPC_OR_TRIGGER_CHANGES = NONE
SECRETS_CHANGED = NONE
USERS_MODIFIED = NONE
DEVICE_RECOVERY_EXECUTED = NO
ACCOUNT_DELETION_EXECUTED = NO
PRODUCTION_DATA_EXPORTED = NO
BACKUP_RESTORE_EXECUTED = NO
```
