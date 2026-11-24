# HAVEN PARENT CONTROL — PHASE 2.7.3 DELIVERABLE 03
# ADVERSARIAL EVIDENCE REVIEW: FOUR M3 TEST CASES

**Document ID:** `HAVEN-GOV-PHASE2-7-3-M3-REVIEW`  
**Phase:** Phase 2.7.3 — Final Dependency Orthogonality & Governance Closure Audit  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Technical Evidence Review  
**Execution Posture:** STRICTLY READ-ONLY  
**Runtime Execution:** PROHIBITED  
**Phase 3 Authorization:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Scope

In Phase 2.7.2, four test cases were assigned the primary classification **`M3`** (*Fresh Database / Clean Migration Replay Required*):
1. **`TC-SEC01`**: Cross-Family Unauthorized Data Access Boundary
2. **`TC-SEC02`**: Replay of Staged Credential Redemption
3. **`TC-EXP-17`**: Parent Device Revocation and Child Session Invalidation
4. **`TC-EXP-18`**: Child Record Removal & Orphan Cleanup

This report executes a mandatory adversarial challenge against these four classifications. It analyzes whether a full PostgreSQL database reset and clean migration replay (`supabase db reset`) is truly an intrinsic technical requirement of each test, or whether their objectives can be fully and safely satisfied by creating **disposable tenant fixtures on an existing compatible schema (`M1 + E2`)**.

---

## 2. Adversarial Inspection of the Four M3 Test Cases

### 2.1 TC-SEC01: Cross-Family Unauthorized Data Access Boundary
- **Test Objective**: Verify PostgreSQL Row-Level Security (RLS) tenant isolation between Family A and Family B by attempting to query Family B's devices and locations using Parent A's JWT.
- **Functionality Mapping**: `A01`, `FAM08`, RLS.
- **Relevant Schema Objects**: `public.devices`, `public.locations`, `public.family_members`, and RLS policies defined in `supabase/migrations/20260101000200_rls.sql`.
- **Source Inspection of RLS Policy**:
  ```sql
  create policy "family_devices_select" on public.devices
    for select using (
      family_id in (
        select family_id from public.family_members
        where user_id = auth.uid()
      )
    );
  ```
- **Adversarial Challenge**:
  - *Does the RLS logic depend on an unpolluted database?* No. PostgreSQL RLS dynamically filters rows matching `family_id in (select ...)`. It evaluates identically whether the database contains two families or ten thousand families.
  - *Why was it classified as M3?* In early governance planning, running multi-tenant security penetration tests on a shared database was considered hazardous because tester errors might expose staging data.
  - *Minimum Technical Requirement*: **`M1 + E2`** (Existing compatible schema with two dynamically created disposable families).
  - *Verdict*: While executing on a fresh, isolated database (`E3`) provides maximum isolation, a fresh migration replay is **NOT an intrinsic technical prerequisite** for the SQL engine to enforce RLS.
  - *Confidence Rating*: **Medium** (Downgraded from High to reflect that clean replay is a procedural safety preference rather than a hard SQL dependency).

---

### 2.2 TC-SEC02: Replay of Staged Credential Redemption
- **Test Objective**: Verify that replaying an already-redeemed recovery challenge payload returns HTTP 400 or 409 (`challenge_already_redeemed`) and prevents credential double-spending.
- **Functionality Mapping**: `FAM13` (Wave 3 Recovery).
- **Relevant Schema Objects**: `public.redeem_recredential_challenge` RPC, `public.device_recovery_challenges` table in `supabase/migrations/20260101000400_device_recovery.sql`.
- **Source Inspection of Replay Guard**:
  ```sql
  if v_challenge.redeemed_at is not null then
    raise exception 'challenge_already_redeemed' using errcode = 'P0001';
  end if;
  ```
- **Adversarial Challenge**:
  - *Does verifying single-use token consumption require a fresh database?* No. The RPC checks `redeemed_at is not null` on the specific challenge record being replayed.
  - *Why was it classified as M3?* Historical reports conflated "staged credential" with "staging environment provisioning".
  - *Minimum Technical Requirement*: **`M1 + E2`** (Existing compatible schema with one freshly generated recovery challenge).
  - *Verdict*: A clean migration replay is **NOT technically required**. The single-use invariant is enforced by row-level timestamps.
  - *Confidence Rating*: **Medium** (Procedural preference for isolated staging, not a database replay dependency).

---

### 2.3 TC-EXP-17: Parent Device Revocation and Child Session Invalidation
- **Test Objective**: Verify that revoking a child device transitions `devices.is_revoked` to `true`, invalidates child Keystore credentials, and stops background sync.
- **Functionality Mapping**: `FAM10`, `FAM12`.
- **Relevant Schema Objects**: `public.devices.is_revoked`, `device-command` edge function, Android `SecureStore.kt`.
- **Adversarial Challenge**:
  - *Does revoking a device require a fresh database?* Absolutely not. It is an `UPDATE public.devices SET is_revoked = true WHERE id = ?`.
  - *What does the test actually require?* It requires a **dedicated physical Android test handset (`E4` / `A8`)** with an active Keystore, so the tester can observe the native daemon halt.
  - *Minimum Technical Requirement*: **`M1 + E2 + A8`** (Existing database schema, isolated test device record, and dedicated test phone).
  - *Verdict*: Classifying `TC-EXP-17` as M3 was an architectural error in Phase 2.7.2. Its primary dependency is **native hardware and device state**, not database migration replay.
  - *Confidence Rating*: **Low as M3; High as M1 + E2 + A8**.

---

### 2.4 TC-EXP-18: Child Record Removal & Orphan Cleanup
- **Test Objective**: Verify that deleting a child record cascades cleanly through foreign keys, leaving zero orphaned records in `locations`, `usage_daily`, `commands`, or `command_acks`.
- **Functionality Mapping**: `FAM10`.
- **Relevant Schema Objects**: Foreign key constraints in `supabase/migrations/20260101000000_core.sql:75` (`ON DELETE CASCADE`).
- **Adversarial Challenge**:
  - *Why was fresh replay considered necessary?* If a shared database contains hundreds of pre-existing orphan rows from earlier failed runs, running `SELECT count(*) FROM locations WHERE child_id = ?` is still 100% accurate because the foreign key predicate scopes the query to the specific child being tested.
  - *Is clean replay mandatory?* Clean replay is only mandatory if the tester uses naive, un-scoped queries (e.g. counting global table rows). If the test uses scoped queries (`WHERE device_id = target_device_id`), an existing schema is completely sufficient.
  - *Minimum Technical Requirement*: **`M1 + E2`** (Scoped query verification) or **`M3 + E3`** (Whole-table un-scoped count verification).
  - *Verdict*: Fresh migration replay is optional if tests use scoped assertions; retained as M3 only under the strict un-scoped verification standard.
  - *Confidence Rating*: **Medium**.

---

## 3. Synthesis & Governance Recommendation

The adversarial challenge proves that **none of the four M3 test cases intrinsically require a full PostgreSQL database reset (`supabase db reset`) to execute their logic**:

| Test ID | Current Class | True Database Requirement | True Environment Requirement | True Android Requirement | Minimum Viable Test Configuration |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **`TC-SEC01`** | `M3` | **`M1`** (Existing Schema) | **`E2`** (Isolated Tenant) | `A0` (Standard UI) | Two disposable families in QA tenant |
| **`TC-SEC02`** | `M3` | **`M1`** (Existing Schema) | **`E2`** (Isolated Tenant) | `A0` (Standard UI) | One fresh recovery challenge fixture |
| **`TC-EXP-17`**| `M3` | **`M1`** (Existing Schema) | **`E2`** (Isolated Tenant) | **`A8`** (Test Phone + Keystore)| One dedicated Android phone + QA family |
| **`TC-EXP-18`**| `M3` | **`M1`** (Existing Schema) | **`E2`** (Isolated Tenant) | `A0` (Standard UI) | One disposable child fixture + scoped SQL |

> [!TIP]
> **GOVERNANCE RESOLUTION**  
> To preserve strict historical comparability with Phase 2.7.2, these four tests are retained under the M3 heading in master registers, but their confidence ratings are explicitly downgraded from High to **Medium/Low**. Test teams are advised that **all four tests can safely execute on an existing compatible schema (`M1`) provided that disposable tenant quarantine (`E2`) is enforced.**
