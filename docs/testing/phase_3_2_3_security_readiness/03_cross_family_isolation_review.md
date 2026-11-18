# Phase 3.2.3 — Report 03: Multi-Tenant Cross-Family Isolation & Data Leakage Review

## 1. Executive Summary

This report evaluates cross-family isolation in the multi-tenant architecture of `parent-control-prod`.

Because Supabase hosts all family data in a shared PostgreSQL database, multi-tenant safety relies on strict tenant boundary enforcement across queries, RLS policies, RPC functions, and Edge Functions.

---

## 2. Multi-Tenant Architectural Model

Every family in Parent Control forms an isolated cryptographic and relational domain:
- **Tenant Root:** `families.id` (UUIDv4)
- **Membership Junction:** `family_members(family_id, user_id, role, status)`
- **Identity Source of Truth:** `auth.uid()` from signed Supabase Auth JWT.

### Key Boundary Helper Functions:
1. `private.is_family_member(p_family_id uuid)`:
   - Verifies that `auth.uid()` possesses an active membership (`status = 'active'`) in `p_family_id`.
2. `private.is_family_parent(p_family_id uuid)`:
   - Verifies that `auth.uid()` is an active member with `role = 'parent'`.
3. `private.shares_active_family(p_other_user_id uuid)`:
   - Verifies that `auth.uid()` and `p_other_user_id` share at least one common active family.

All three helper functions are `SECURITY DEFINER` procedures with `search_path` strictly pinned to `public, private, pg_temp`, preventing schema hijacking.

---

## 3. Potential Attack Vector Analysis

### Vector A: Parameter Tampering on `family_id` (In-Band API Calls)
- **Scenario:** A parent in Family A sends a REST request to `/rest/v1/devices?family_id=eq.<Family_B_UUID>`.
- **Defense Mechanism:**
  - Policy `devices_select_parent_or_child` evaluates `private.is_family_parent(family_id)`.
  - Postgres evaluates `private.is_family_parent(Family_B_UUID)` using `auth.uid()` (Parent in Family A).
  - The function returns `FALSE`.
  - PostgREST filters out all rows, returning an empty array `[]`.
- **Verdict:** **IMMUNE (Zero data leakage)**.

### Vector B: Device Command Injection Across Families
- **Scenario:** Parent in Family A attempts to send a `wipe` or `lock` command to a device in Family B via `device-command` Edge Function.
- **Defense Mechanism:**
  - `device-command` validates the caller's JWT using `requireUser(req)`.
  - The function verifies that the target device belongs to a family where the caller is an active parent.
  - If `device.family_id != caller.family_id`, an HTTP 403 / 404 is thrown, and zero command rows are written.
- **Verdict:** **IMMUNE**.

### Vector C: Location Telemetry Harvesting
- **Scenario:** Attacker with a child token attempts to query historical location coordinates of other devices.
- **Defense Mechanism:**
  - Policy `location_events_select_parent_or_child` requires:
    `private.is_family_parent(family_id) OR EXISTS (SELECT 1 FROM devices d WHERE d.id = device_id AND d.child_user_id = auth.uid())`.
  - A child account is not a parent, so the first condition fails.
  - For the second condition, `d.child_user_id` must match `auth.uid()`, preventing a child from seeing any location events other than their own device.
- **Verdict:** **IMMUNE**.

### Vector D: WebRTC Signaling Cross-Session Snooping
- **Scenario:** Attacker monitors `webrtc_signals` to intercept live streaming SDP offers or ICE candidates of another family.
- **Defense Mechanism:**
  - Policy `webrtc_signals_select_participant` requires the caller to be either `parent_user_id` or `child_user_id` of the active, unexpired session referenced by `session_id`.
  - Random UUIDs on sessions make guessing IDs computationally infeasible.
  - Even if a session UUID was known, third-party callers receive 0 signal rows.
- **Verdict:** **IMMUNE**.

---

## 4. Edge Function Tenant Boundary Verification

Review of shared authentication library `supabase/functions/_shared/auth.ts`:
1. `requireUser(req)`: Validates JWT signature, expiration, and resolves `user.id`.
2. `requireFamilyParent(db, userId, familyId)`: Explicitly asserts that `userId` is an active parent of `familyId`.
3. Service Role Client Usage: Edge Functions only switch to privileged `getServiceClient()` after caller identity and authorization checks have fully succeeded.

---

## 5. Multi-Tenant Isolation Verdict

- **Cross-Family Leakage Risk:** **NONE IDENTIFIED**
- **Boundary Verification Status:** **PASSED**
- All family boundaries are enforced at both the database RLS layer and the Edge Function validation layer.
