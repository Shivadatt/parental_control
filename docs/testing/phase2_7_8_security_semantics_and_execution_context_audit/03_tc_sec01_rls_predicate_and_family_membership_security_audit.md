# HAVEN PARENT CONTROL — PHASE 2.7.8
## DELIVERABLE 03: TC-SEC01 RLS PREDICATE & FAMILY MEMBERSHIP SECURITY AUDIT

**Document ID:** `HAVEN-GOV-PHASE2-7-8-DOC03`  
**Phase:** Phase 2.7.8 — Final Classification Semantics, RLS Predicate & Privileged Execution Context Verification  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Git HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Parent Commit:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** Forensic PostgreSQL Row-Level Security & Membership Predicate Analysis  
**Test Reference:** `TC-SEC01` (Functionality ID: `A01` / RLS)  

---

### 1. ORIGINAL TEST SPECIFICATION & OBJECTIVE

From `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md` (lines 376–394):
- **Test ID:** `TC-SEC01`
- **Title:** `Cross-Family Unauthorized Data Access Boundary`
- **Target Architecture:** PostgreSQL Row-Level Security (RLS) Tenant Isolation
- **Preconditions:** Two distinct family accounts created (`Family A` and `Family B`).
- **Required Credentials:** Authenticated `Parent A` JWT.
- **Execution Steps:**
  1. Authenticate as `Parent A`.
  2. Attempt to query `devices` or `location_events` using `device_id` belonging to `Family B`.
- **Expected Result:** PostgreSQL RLS policies return 0 rows or HTTP 403 Forbidden; zero data leakage across family boundaries.

---

### 2. IDENTIFIER RELATIONSHIPS & SHORTHAND CORRECTION

In Phase 2.7.7, the summary text described the RLS predicate using the shorthand:
> `auth.uid() = family_id`

#### 2.1 Technical Flaw of the Shorthand Description
1. `auth.uid()` returns the UUID of the authenticated user from `auth.users` (matching `public.profiles.id`).
2. `family_id` is the UUID of a family group in `public.families.id`.
3. A user UUID and a family UUID represent completely distinct entity classes. A direct equality comparison (`auth.uid() = family_id`) would evaluate to `FALSE` in virtually all circumstances, breaking legitimate family access.

#### 2.2 Actual Architectural Membership Relationship
The Haven database architecture mediates all family-level authorization through the join table `public.family_members`:
```
+-------------------+             +-----------------------+             +-------------------+
|  auth.users (JWT) |             | public.family_members |             |  public.families  |
+-------------------+             +-----------------------+             +-------------------+
| id = auth.uid()   | <=========> | user_id (UUID)        |             | id (UUID)         |
+-------------------+             | family_id (UUID)      | <=========> +-------------------+
                                  | role ('parent'/'child'|
                                  | status ('active')     |
                                  +-----------------------+
```

---

### 3. FORENSIC AUDIT OF RLS HELPER FUNCTIONS

In `supabase/migrations/20260101000000_core.sql` (lines 566–630), PostgreSQL `SECURITY DEFINER` helper functions are defined to encapsulate all tenant-boundary checks:

```sql
-- supabase/migrations/20260101000000_core.sql:566-620
create or replace function private.is_family_member(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

create or replace function private.is_family_parent(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.role = 'parent'
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

create or replace function private.shares_active_family(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.family_members mine
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

#### 3.1 Security Properties of Helper Functions
1. **Search Path Isolation:** Every helper enforces `SET search_path = public, private, pg_temp`, preventing search-path substitution vulnerabilities.
2. **Deterministic Stability:** Marked `STABLE`, allowing PostgreSQL's query optimizer to cache results per statement.
3. **Execution Mode:** `SECURITY DEFINER` executes with creator privileges to read `public.family_members` and `public.families` without triggering recursive RLS evaluation.
4. **Active & Undeleted Invariants:** Explicitly checks `m.status = 'active'` and `f.deleted_at is null`. Revoked, pending, or soft-deleted memberships return `FALSE`.
5. **Execution Grants:**
   ```sql
   grant usage on schema private to authenticated;
   grant execute on function private.is_family_member(uuid) to authenticated;
   grant execute on function private.is_family_parent(uuid) to authenticated;
   grant execute on function private.shares_active_family(uuid) to authenticated;
   revoke all on function private.is_family_member(uuid) from public, anon;
   revoke all on function private.is_family_parent(uuid) from public, anon;
   revoke all on function private.shares_active_family(uuid) from public, anon;
   ```
   Anonymous users (`anon`) have zero execution privileges.

---

### 4. RELEVANT RLS POLICIES ACROSS TARGET TABLES

In `supabase/migrations/20260101000200_rls.sql`, RLS policies are applied across all core tables:

```
+-----------------------+----------------------------------+---------+-------------------------------------------------------+
| Table                 | Policy Name                      | Command | USING Predicate                                       |
+-----------------------+----------------------------------+---------+-------------------------------------------------------+
| public.profiles       | profiles_select_self_or_family   | SELECT  | id = auth.uid() OR private.shares_active_family(id)   |
| public.profiles       | profiles_update_self             | UPDATE  | id = auth.uid()                                       |
| public.families       | families_select_members          | SELECT  | deleted_at IS NULL AND private.is_family_member(id)   |
| public.families       | families_update_owner            | UPDATE  | owner_id = auth.uid() AND deleted_at IS NULL          |
| public.family_members | family_members_select_family     | SELECT  | private.is_family_member(family_id)                   |
| public.devices        | devices_select_parent_or_child   | SELECT  | private.is_family_parent(family_id)                   |
|                       |                                  |         |   OR child_user_id = auth.uid()                       |
| public.usage_daily    | usage_daily_select_parent_or_child| SELECT | private.is_family_parent(family_id)                   |
|                       |                                  |         |   OR private.is_family_member(family_id)              |
| public.location_events| [Service-Role Only Table]        | ALL     | RLS enabled; 0 client policies (Service key required) |
+-----------------------+----------------------------------+---------+-------------------------------------------------------+
```

#### 4.1 Evaluation of Policy Paths
1. **SELECT (Cross-Family Read):**
   - When `Parent A` queries `public.devices` where `family_id = Family B`:
     `private.is_family_parent('Family B')` evaluates to `FALSE` (since Parent A is not in Family B).
     `child_user_id = auth.uid()` evaluates to `FALSE`.
     **Result:** PostgreSQL returns an empty set (0 rows). Zero data leakage.
2. **INSERT (Cross-Family Write):**
   - No client INSERT policy exists on `public.devices` or `public.location_events`. All device registration and telemetry insertion occurs via Edge Functions (`device-register`, `location-telemetry`), which enforce caller authentication and family assertions before writing.
3. **UPDATE (Cross-Family Mutation):**
   - Restricted strictly to owned or self rows (`owner_id = auth.uid()`, `id = auth.uid()`).
4. **DELETE (Cross-Family Destruction):**
   - **`NO CLIENT DELETE POLICIES EXIST`**. In `20260101000200_rls.sql`, the fundamental rule is established: *"Rules: no client DELETE policies; service-only tables have RLS enabled and no policies; anon gets no table privilege at all."* Client roles cannot delete rows from any table via direct SQL.

---

### 5. SOURCE-LEVEL SECURITY VERDICT FOR TC-SEC01

```
========================================================================================
FINAL AUDIT VERDICT ON TC-SEC01:
SOURCE-VERIFIED TENANT PREDICATES — RUNTIME ISOLATION NOT VERIFIED
========================================================================================
1. The PostgreSQL RLS predicates correctly and safely enforce family-level tenant
   isolation via private.is_family_member() and private.is_family_parent().
2. The user UUID (auth.uid()) is compared against public.family_members.user_id in a
   secure, active-membership join. No raw auth.uid() = family_id equality exists.
3. Search path isolation, STABLE caching, and anonymous revokes are strictly in place.
4. While statically verified as architecturally sound, live runtime execution of cross-family
   adversarial queries against a deployed database remains NOT TESTED.
========================================================================================
```
