# Phase 3.7.4 — Report 11: Test Execution Telemetry & Results

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Test Suite:** `supabase/functions/account/`  
**Execution Command:** `deno test --allow-read supabase/functions/account/`  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report documents the official execution telemetry of the expanded test suite for the `account` Edge Function following Phase 3.7.4 harness enhancements.

$$\mathbf{Test\ Results} = \mathbf{55\ PASSED\ |\ 0\ FAILED\ |\ 0\ SKIPPED\ (649ms)}$$

---

## 2. Test File Breakdown

| Test File | Tests Run | Passed | Failed | Duration | Status |
|---|:---:|:---:|:---:|:---:|:---:|
| `supabase/functions/account/cross_tenant_isolation_test.ts` | 10 | 10 | 0 | 81ms | **PASS** |
| `supabase/functions/account/deletion_test.ts` | 15 | 15 | 0 | 62ms | **PASS** |
| `supabase/functions/account/retention_test.ts` | 6 | 6 | 0 | 3ms | **PASS** |
| `supabase/functions/account/scope_test.ts` | 17 | 17 | 0 | 22ms | **PASS** |
| `supabase/functions/account/validation_test.ts` | 7 | 7 | 0 | 3ms | **PASS** |
| **Total Test Suite** | **55** | **55** | **0** | **649ms** | **100% PASS** |

---

## 3. Adversarial Test Telemetry (CT-01 through CT-10)

| Scenario ID | Test Name | Assertion Highlights | Result |
|---|---|---|:---:|
| **CT-01** | Baseline Isolation (Export) | Zero Tenant B rows in User A export | **ok (49ms)** |
| **CT-02** | Injected Family ID in Export | Injected body parameter ignored; 0 foreign leaks | **ok (2ms)** |
| **CT-03** | Injected Family ID in Retention Report | Injected parameter ignored; Family B excluded | **ok (3ms)** |
| **CT-04** | Inactive / Revoked Membership Isolation | Suspended user receives `not_reported`, 0 rows | **ok (1ms)** |
| **CT-05** | Child Role Isolation & Audit Partitioning | Scope is `device`; parent-only logs excluded | **ok (2ms)** |
| **CT-06** | Multi-Membership Scope Isolation | Sees Family A and C; Family B hidden | **ok (1ms)** |
| **CT-07** | Empty Scope Fail-Closed Verification | Stranger triggers `NO_MATCH_UUID`; 0 rows | **ok (1ms)** |
| **CT-08** | Injected Device ID in Export | Injected device param ignored; bounds to own | **ok (2ms)** |
| **CT-09** | Audit Log & Sweep Marker Isolation | Sweep marker (`family_id: null`) excluded | **ok (1ms)** |
| **CT-10** | Pagination & Row-Cap Isolation | 1,050 rows paged (1000 + 50); 0 foreign leaks | **ok (17ms)** |

---

## 4. Execution Log Artifact

```text
Check supabase/functions/account/cross_tenant_isolation_test.ts
Check supabase/functions/account/deletion_test.ts
Check supabase/functions/account/retention_test.ts
Check supabase/functions/account/scope_test.ts
Check supabase/functions/account/validation_test.ts
running 10 tests from ./supabase/functions/account/cross_tenant_isolation_test.ts
CT-01: Baseline Isolation — User A export strictly isolates Tenant A data from Tenant B ... ok (49ms)
CT-02: Adversarial Injected Family ID in Export — Injected family_id is ignored ... ok (2ms)
CT-03: Adversarial Injected Family ID in Retention Report — Injected family_id is ignored ... ok (3ms)
CT-04: Inactive / Revoked Membership Isolation — Suspended user receives empty scope ... ok (1ms)
CT-05: Child Role Isolation — Scope is device, parent audit logs excluded ... ok (2ms)
CT-06: Multi-Membership Scope Isolation — Multi-family parent sees own families only ... ok (1ms)
CT-07: Empty Scope Fail-Closed Verification — Stranger with 0 memberships gets 0 rows ... ok (1ms)
CT-08: Adversarial Injected Device ID in Export — Injected device_id is ignored ... ok (2ms)
CT-09: Audit Log Query Isolation — Global sweep marker with family_id=null is not leaked ... ok (1ms)
CT-10: Pagination & Row-Cap Isolation — Multi-page fetch preserves tenant isolation ... ok (17ms)
running 15 tests from ./supabase/functions/account/deletion_test.ts
... (15 tests passed)
running 6 tests from ./supabase/functions/account/retention_test.ts
... (6 tests passed)
running 17 tests from ./supabase/functions/account/scope_test.ts
... (17 tests passed)
running 7 tests from ./supabase/functions/account/validation_test.ts
... (7 tests passed)

ok | 55 passed | 0 failed (649ms)
```
