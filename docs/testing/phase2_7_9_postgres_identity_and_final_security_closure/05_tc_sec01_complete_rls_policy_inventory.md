# HAVEN PARENT CONTROL — PHASE 2.7.9
## DELIVERABLE 05: TC-SEC01 COMPLETE RLS POLICY INVENTORY

**Document ID:** `HAVEN-GOV-PHASE2-7-9-DOC05`  
**Phase:** Phase 2.7.9 — PostgreSQL Identity Semantics, Function Ownership & Final Security Evidence Closure  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Actual Git HEAD:** `20cc0b1439ebea1b3808d769e7b91b646a9fe089`  
**Parent Commit:** `e5022531beeb7393a7a5585351af891180630216`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** Complete Database-Wide Row-Level Security Policy Forensics  
**Test Reference:** `TC-SEC01` (Functionality ID: `A01` / RLS)  

---

### 1. AUDIT OBJECTIVE & SCOPE

This deliverable establishes the complete, exhaustive inventory of every PostgreSQL Row-Level Security (RLS) policy, enabled table, and helper predicate function across the entire Haven Parent Control repository.

Every migration in `supabase/migrations/` was forensically inspected to trace the full lifecycle of policies, including additions in `20260101000200_rls.sql`, `20261028000300_signaling_open_session.sql`, and `20261030000200_phase1_authorization.sql`.

---

### 2. CORE TENANT-ISOLATION HELPER FUNCTIONS

In `supabase/migrations/20260101000000_core.sql` (lines 566–630), all tenant-boundary checks are centralized in three `SECURITY DEFINER` helper functions:

```sql
-- core.sql:566-580
create or replace function private.is_family_member(p_family_id uuid)
returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select exists (
    select 1 from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

-- core.sql:582-598
create or replace function private.is_family_parent(p_family_id uuid)
returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select exists (
    select 1 from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.role = 'parent'
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

-- core.sql:600-618
create or replace function private.shares_active_family(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select exists (
    select 1 from public.family_members mine
    join public.family_members theirs on theirs.family_id = mine.family_id
    join public.families f on f.id = mine.family_id
    where mine.user_id = auth.uid()
      and theirs.user_id = p_user_id
      and mine.status = 'active'
      and theirs.status = 'active'
      and f.deleted_at is null
  );
$$;
```

#### Security Properties:
- **Search Path Isolation:** Strictly locked to `public, private, pg_temp`.
- **Active Membership Invariant:** Requires `m.status = 'active'`.
- **Soft-Delete Invariant:** Requires `f.deleted_at is null`.
- **Grants:** `USAGE` on schema `private` and `EXECUTE` granted to `authenticated`; strictly revoked from `public` and `anon`.

---

### 3. COMPLETE DATABASE-WIDE RLS POLICY INVENTORY

```
+---------------------------+------------+------------------------------------+---------+---------------+-----------------------------------------------+-----------------------------------------------+
| Table Name                | RLS State  | Policy Name                        | Command | Target Roles  | USING Predicate                               | WITH CHECK Predicate                          |
+---------------------------+------------+------------------------------------+---------+---------------+-----------------------------------------------+-----------------------------------------------+
| 1. public.profiles        | ENABLED    | profiles_select_self_or_family     | SELECT  | authenticated | id = auth.uid() OR                            | [NONE]                                        |
|                           |            |                                    |         |               |   private.shares_active_family(id)             |                                               |
|                           |            | profiles_update_self               | UPDATE  | authenticated | id = auth.uid()                               | id = auth.uid()                               |
|                           |            |                                    |         |               |                                               |                                               |
| 2. public.families        | ENABLED    | families_select_members            | SELECT  | authenticated | deleted_at IS NULL AND                        | [NONE]                                        |
|                           |            |                                    |         |               |   private.is_family_member(id)                |                                               |
|                           |            | families_update_owner              | UPDATE  | authenticated | owner_id = auth.uid() AND deleted_at IS NULL  | owner_id = auth.uid()                         |
|                           |            |                                    |         |               |                                               |                                               |
| 3. public.family_members  | ENABLED    | family_members_select_family       | SELECT  | authenticated | private.is_family_member(family_id)           | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 4. public.devices         | ENABLED    | devices_select_parent_or_child     | SELECT  | authenticated | private.is_family_parent(family_id) OR        | [NONE]                                        |
|                           |            |                                    |         |               |   child_user_id = auth.uid()                  |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 5. device_pairing_tokens  | ENABLED    | [Service-Role Only Table]          | ALL     | service_role  | [NO CLIENT POLICIES - Service Key Required]   | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 6. public.pairing_requests| ENABLED    | pairing_requests_select_partic     | SELECT  | authenticated | parent_user_id = auth.uid() OR                | [NONE]                                        |
|                           |            |                                    |         |               |   child_user_id = auth.uid()                  |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 7. public.device_policies | ENABLED    | device_policies_select_parent_child| SELECT  | authenticated | private.is_family_parent(family_id) OR        | [NONE]                                        |
|                           |            |                                    |         |               |   private.is_family_member(family_id)         |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 8. public.device_commands | ENABLED    | device_commands_select_parent_child| SELECT  | authenticated | private.is_family_parent(family_id) OR        | [NONE]                                        |
|                           |            |                                    |         |               |   EXISTS(SELECT 1 FROM devices d WHERE        |                                               |
|                           |            |                                    |         |               |     d.id = device_id AND child_user_id=auth.uid) |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 9. public.usage_daily     | ENABLED    | usage_daily_select_parent_or_child | SELECT  | authenticated | private.is_family_parent(family_id) OR        | [NONE]                                        |
|                           |            |                                    |         |               |   private.is_family_member(family_id)         |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 10. public.location_events| ENABLED    | [Service-Role Only Table]          | ALL     | service_role  | [NO CLIENT POLICIES - Service Key Required]   | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 11. public.safe_zones     | ENABLED    | safe_zones_select_members          | SELECT  | authenticated | private.is_family_member(family_id)           | [NONE]                                        |
|                           |            | safe_zones_delete_parent           | DELETE  | authenticated | private.is_family_parent(family_id)           | [NONE] (Added 20261030000200)                 |
|                           |            |                                    |         |               |                                               |                                               |
| 12. public.safe_zone_state| ENABLED    | safe_zone_states_select_members    | SELECT  | authenticated | private.is_family_member(family_id)           | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 13. public.safety_alerts  | ENABLED    | safety_alerts_select_parent        | SELECT  | authenticated | private.is_family_parent(family_id)           | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 14. public.remote_sessions| ENABLED    | remote_sessions_select_participants| SELECT  | authenticated | private.is_family_parent(family_id) OR        | [NONE]                                        |
|                           |            |                                    |         |               |   child_user_id = auth.uid()                  |                                               |
|                           |            |                                    |         |               |                                               |                                               |
| 15. public.webrtc_signals | ENABLED    | webrtc_signals_select_participant  | SELECT  | authenticated | session_id IN (SELECT id FROM remote_sessions)| [NONE] (Added 20261028000300)                 |
|                           |            | webrtc_signals_insert_participant | INSERT  | authenticated | [CHECK ONLY]                                  | session_id IN (SELECT id FROM remote_sessions) |
|                           |            |                                    |         |               |                                               |                                               |
| 16. public.audit_logs     | ENABLED    | audit_logs_select_parent           | SELECT  | authenticated | private.is_family_parent(family_id)           | [NONE] (Protected by append-only trigger)      |
|                           |            |                                    |         |               |                                               |                                               |
| 17. public.device_apps    | ENABLED    | [Service-Role Only Table]          | ALL     | service_role  | [NO CLIENT POLICIES - Service Key Required]   | [NONE]                                        |
|                           |            |                                    |         |               |                                               |                                               |
| 18. pairing_attempts      | ENABLED    | [Service-Role Only Table]          | ALL     | service_role  | [NO CLIENT POLICIES - Service Key Required]   | [NONE]                                        |
+---------------------------+------------+------------------------------------+---------+---------------+-----------------------------------------------+-----------------------------------------------+
```

---

### 4. CRITICAL TENANT-BOUNDARY ARCHITECTURAL RULES

1. **The "No Client Deletes" Paradigm:** In `20260101000200_rls.sql`, the platform enforces an explicit architectural rule: *"no client DELETE policies; service-only tables have RLS enabled and no policies; anon gets no table privilege at all."* The only client-executable DELETE policy across the entire database is `safe_zones_delete_parent` (added in `20261030000200`). All other deletions must occur via service-role Edge Functions or `SECURITY DEFINER` stored procedures.
2. **Service-Role Only Tables:** `location_events`, `device_pairing_tokens`, `device_apps`, and `pairing_attempts` have RLS enabled with zero client policies. Authenticated parents and children cannot query these tables directly via PostgREST; all access must flow through validated Edge Functions.
3. **Cross-Tenant Boundary Strength:** When `Parent A` queries `public.devices` or `public.usage_daily` with a `family_id` belonging to `Family B`, `private.is_family_parent('Family B')` returns `FALSE`. PostgreSQL returns an empty set (`0 rows`).

---

### 5. CLASSIFICATION & FINAL VERDICT FOR TC-SEC01

```
========================================================================================
FINAL AUDIT CLASSIFICATION:
SOURCE POLICY INVENTORY COMPLETE
DEPLOYED POLICY STATE NOT VERIFIED
RUNTIME CROSS-TENANT ISOLATION NOT VERIFIED
========================================================================================
1. The static RLS policy inventory across all 18 tables is 100% complete and verified.
2. Direct user UUID vs family UUID equality is nowhere present; authorization is strictly
   mediated by active-membership joins in private.is_family_member().
3. However, catalog verification on the deployed remote PostgreSQL instance and live
   adversarial penetration testing of cross-family queries remain NOT TESTED.
========================================================================================
```
