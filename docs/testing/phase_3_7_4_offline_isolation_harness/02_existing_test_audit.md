# Phase 3.7.4 — Report 02: Existing Test Suite & Coverage Gap Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` Edge Function  
**Execution Mode:** STRICTLY LOCAL / OFFLINE  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

Prior to Phase 3.7.4, the local test suite for the `account` function comprised 45 unit tests across four test files. While these tests provided strong coverage for single-caller semantics, retention calculations, and deletion lockout recovery, they exhibited a critical coverage gap: **multi-tenant isolation across simultaneous tenants was unexercised**.

This report inventories existing test suites, documents baseline coverage, and explains why the enhanced adversarial test suite is necessary to prove service-role query safety.

---

## 2. Existing Test Suite Inventory (Pre-Phase 3.7.4)

| Test File | Test Count | Focus Area | Verification Type |
|---|:---:|---|---|
| `supabase/functions/account/scope_test.ts` | 17 | Retention scope resolution (`resolveRetentionScope`, `retentionCountFilter`, redactions) | Pure in-memory unit tests |
| `supabase/functions/account/retention_test.ts` | 6 | Retention cutoffs, settings fallback, negative count clamping | Pure calculation unit tests |
| `supabase/functions/account/validation_test.ts` | 7 | Email normalization, confirmation phrase parsing, owner blocker heuristics | Pure validation unit tests |
| `supabase/functions/account/deletion_test.ts` | 15 | Account deletion retry lockout, partial failure recovery, base export format | In-memory `fakePostgrest` integration |
| **Total Baseline Tests** | **45** | **Single-Tenant / Pure Logic / Lifecycle Handling** | **All Passing (374ms)** |

---

## 3. Analysis of Existing Coverage Limitations

### 3.1 Single-Tenant World Limitation
In `deletion_test.ts`, the test fixture (`setupBaseWorld()`) established only a single family (`FAMILY_ID`) and a single caller (`PARENT_ID`). Cross-user deletion tests (e.g., Test 13: "Cross-user deletion attempt") verified that an email mismatch in the deletion payload rejected the request, but did not populate a concurrent victim tenant to verify that queries could not leak data from other database rows.

### 3.2 Mock Infrastructure Gaps
1. **Single Global User:** `FakePostgrest` supported only one global `authUser`. If a test needed to simulate User A invoking `export` while User B's records existed, both users shared the same auth context unless manually mutated between turns.
2. **Unsupported `.or()` Syntax:** In `deletion.ts:271`, child audit log queries use `.or("actor_user_id.eq.${userId},device_id.in.(${childDeviceIds.join(',')})")`. `FakePostgrest` previously did not parse `.or()` conditions, simply returning unfiltered rows.
3. **Compound Ordering:** `fetchCapped` in `deletion.ts:102` executes `.order(orderColumn, { ascending: false }).order("id", { ascending: false })`. `FakePostgrest` previously tracked only a single order spec.

---

## 4. Remediation Plan

To substantiate cross-tenant isolation without deploying to production:
1. Enhance `FakePostgrest` with multi-token authentication (`authTokens`, `setTokenUser`), PostgREST `.or()` evaluation, and compound sorting.
2. Implement a dedicated two-tenant adversarial test suite (`cross_tenant_isolation_test.ts`) exercising scenarios **CT-01 through CT-10**.
3. Ensure 100% backward compatibility so all 45 existing unit tests continue to pass without regression.
