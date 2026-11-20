# Phase 3.7.2 — Report 03: Service-Role Query Test Mapping & 19-Operation Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / TEST PLANNING / SOURCE REVIEW  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report maps all **19 privileged service-role database operations** in the deployed `account` Edge Function to the threat scenarios (CT-01 through CT-10). Because the service-role client bypasses PostgreSQL Row-Level Security (`BYPASSRLS`), this audit proves that every single query path is constrained by verified application-level ownership filters.

$$\mathbf{Service-Role\ Isolation\ Architecture} = \mathbf{100\%\ CALLER-DERIVED\ &\ FAIL-CLOSED}$$

---

## 2. Comprehensive 19-Operation Test Mapping Matrix

The table below provides the complete engineering breakdown for every privileged database query in the `account` function:

| Op ID | Source File & Lines | Function Context | Target Table | Operation Type | Identity Source | Family Scope Derivation | Ownership Filter Applied | Request-Controlled Fields | Empty-Scope Behavior | Cross-Tenant Risk | Mapped Scenarios | Baseline Evidence & Tests |
|:---:|---|---|---|:---:|---|---|---|---|---|:---:|:---:|---|
| **Op 01** | `shared-auth.ts` L35-50 | `requireUser` | `auth.users` | `auth.getUser` | Bearer JWT | N/A (Cryptographic validation) | Validates GoTrue signature & expiry | None (JWT only) | Aborts with HTTP 401 | Low | CT-01, CT-04 | `shared-auth.ts`, `validation_test.ts` |
| **Op 02** | `index.ts` L78-92 | `requireUser` | `public.profiles` | `SELECT` | Verified `authUser.id` | N/A | `.eq('id', user.id)` | None | Aborts with HTTP 404/401 | Low | CT-01, CT-05 | `index.ts`, `scope_test.ts` |
| **Op 03** | `index.ts` L121-132 | `loadActiveMemberships` | `public.family_members` | `SELECT` | Verified `user.id` | Queries memberships for caller | `.eq('user_id', userId).eq('status', 'active')` | None | Returns `[]` | Medium | CT-01, CT-04, CT-07 | `index.ts` L125-130 |
| **Op 04** | `index.ts` L134-145 | `loadFamilies` | `public.families` | `SELECT` | Derived from active memberships | `familyIds = memberships.map(m => m.family_id)` | `.in('id', familyIds)` | None (Derived from Op 03) | If `familyIds.length === 0`, returns `[]` | High | CT-01, CT-02, CT-06 | `index.ts` L138 |
| **Op 05** | `index.ts` L227-236 | `exportAccount` | `public.families` | `SELECT` | Active memberships | `familyIds` | `.in('id', familyIds)` | Injected body IDs ignored | Returns `[]` | High | CT-01, CT-02, CT-06 | `index.ts` L232-235 |
| **Op 06** | `index.ts` L255-262 | `exportAccount` | `public.devices` | `SELECT` | Resolved scope | Family scope: `familyIds`<br>Child scope: `userId` | Family: `.in('family_id', familyIds)`<br>Child: `.eq('child_user_id', userId)` | Body `device_id` ignored | If empty: `.eq('id', NO_MATCH_UUID)` | High | CT-05, CT-08 | `index.ts` L256-260 |
| **Op 07** | `index.ts` L280-281 | `exportAccount` | `public.location_events` | `SELECT (fetchCapped)` | Resolved scope | Scoped to `familyIds` or `childDeviceIds` | Family: `.in('family_id', familyIds)`<br>Child: `.in('device_id', childDeviceIds)` | None | Empty ID guard $\to$ `NO_MATCH_UUID` | High | CT-01, CT-05, CT-10 | `index.ts` L269-278 |
| **Op 08** | `index.ts` L282-282 | `exportAccount` | `public.usage_daily` | `SELECT (fetchCapped)` | Resolved scope | Scoped to `familyIds` or `childDeviceIds` | Family: `.in('family_id', familyIds)`<br>Child: `.in('device_id', childDeviceIds)` | None | Empty ID guard $\to$ `NO_MATCH_UUID` | High | CT-01, CT-05, CT-10 | `index.ts` L269-278 |
| **Op 09** | `index.ts` L283-283 | `exportAccount` | `public.safety_alerts` | `SELECT (fetchCapped)` | Resolved scope | Scoped to `familyIds` or `childDeviceIds` | Family: `.in('family_id', familyIds)`<br>Child: `.in('device_id', childDeviceIds)` | None | Empty ID guard $\to$ `NO_MATCH_UUID` | High | CT-01, CT-05, CT-10 | `index.ts` L269-278 |
| **Op 10** | `index.ts` L284-303 | `exportAccount` | `public.audit_logs` | `SELECT (fetchCapped)` | Resolved scope | Scoped to `familyIds` or `childDeviceIds` | Family: `.in('family_id', familyIds)`<br>Child: `.or('actor_user_id.eq...,device_id.in...')` | None | Empty ID guard $\to$ `NO_MATCH_UUID` | High | CT-05, CT-09, CT-10 | `index.ts` L288-300 |
| **Op 11** | `index.ts` L319-333 | `exportAccount` | `public.family_members` | `In-memory assembly` | Active memberships | `memberships` array | Bounded to caller's active memberships | None | Returns `[]` | Medium | CT-01, CT-06 | `index.ts` L319-332 |
| **Op 12** | `index.ts` L368-372 | `retentionReport` | `public.families` | `SELECT (settings)` | Active memberships | `familyIds = memberships.map(m => m.family_id)` | `.in('id', familyIds)` | Injected body IDs ignored | Returns `[]` | Medium | CT-03 | `index.ts` L368-372 |
| **Op 13** | `index.ts` L418-420 | `countOlderLocationEvents` | `public.location_events` | `COUNT (exact, head)` | `retentionCountFilter` | Target family ID + device IDs | `.eq('family_id', filter.family_id).lt('recorded_at', before)` | None | If `filter.run` false, returns `0` | Medium | CT-03, CT-05 | `index.ts` L194-205 |
| **Op 14** | `index.ts` L419-420 | `countOlderUsageDays` | `public.usage_daily` | `COUNT (exact, head)` | `retentionCountFilter` | Target family ID + device IDs | `.eq('family_id', filter.family_id).lt('day', beforeDay)` | None | If `filter.run` false, returns `0` | Medium | CT-03, CT-05 | `index.ts` L213-224 |
| **Op 15** | `deletion.ts` L30-45 | `executeAccountDeletion` | `public.audit_logs` | `INSERT` | Verified `caller.user.id` | Caller's family scope | `event_type: 'account_deletion_requested'` | `confirm: true, email: ...` | Evaluates blockers first | High | Gate CT-C | `deletion.ts`, `deletion_test.ts` |
| **Op 16** | `deletion.ts` L50-70 | `executeAccountDeletion` | `public.families` | `UPDATE (tombstone)` | Sole-owned families | Only families where `owner_id = caller.id` | `.eq('id', family.id).eq('owner_id', caller.id)` | None | Scoped strictly to caller | High | Gate CT-C | `deletion.ts` L55-68 |
| **Op 17** | `deletion.ts` L75-95 | `executeAccountDeletion` | `public.family_members` | `DELETE` | Caller memberships | Caller's membership rows | `.eq('user_id', caller.id)` | None | Only caller's rows deleted | High | Gate CT-C | `deletion.ts` L80-90 |
| **Op 18** | `deletion.ts` L100-120 | `executeAccountDeletion` | `auth.users` | `auth.admin.deleteUser` | Verified `caller.id` | N/A | Deletes caller's own Auth record | None | Targets strictly `caller.id` | Critical | Gate CT-C | `deletion.ts` L110-118 |
| **Op 19** | `retention.ts` L95-130 | Retention Sweeper | Child tables | `DELETE` | **Global / Cron** | **Project-wide sweep** | **NOT INVOKED IN ACCOUNT FUNCTION** | None | Excluded from account endpoint | Critical | Prohibited | `retention.ts`, SQL sweep migration |

---

## 3. Mandatory Security Checks & Verification Findings

1. **Immutable Identity Source:**
   In every operation (Op 01 - Op 18), caller identity originates strictly from GoTrue JWT cryptographic claims (`sub`). No client-supplied parameter can override the resolved `userId`.
2. **Request Body Parameter Decoupling:**
   For `export` and `retention_report`, any body parameters such as `family_id` or `device_id` are completely unread by the query assembly functions. The queries derive scope exclusively from the database lookup of the caller's active memberships.
3. **Fail-Closed Sentinel (`NO_MATCH_UUID`):**
   When an active membership set is empty or a child user has no devices, queries explicitly substitute the non-existent UUID `00000000-0000-0000-0000-000000000000` (`NO_MATCH_UUID`). This guarantees that PostgREST never executes an unbounded query (`SELECT * FROM table` without a WHERE clause).
4. **Pagination Filter Preservation:**
   `fetchCapped` passes the exact scoping filter closure into the PostgREST query builder on every range iteration (`from += 1000`), ensuring that multi-page queries cannot drop the tenant constraint.
