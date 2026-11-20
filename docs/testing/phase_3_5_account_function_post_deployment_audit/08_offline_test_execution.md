# Phase 3.5 — Report 08: Offline Test Execution & Test Coverage Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Execution Environment:** Deno 1.46+ / Windows x64  
**Audit Date:** 2026-11-20  

---

## 1. Executive Test Summary

In Phase 3.5, offline testing was conducted using the local Deno test harness to comprehensively exercise all functions, error branches, and edge cases without performing any mutations against the production database.

### Test Suite Scorecard

| Suite Name | Target Path | Total Tests | Passed | Failed | Duration | Verdict |
|---|---|---|---|---|---|---|
| **Staged Package Suite** | `docs/testing/phase_3_4_3_browser_package/staging/account/` | 46 | 46 | 0 | 401ms | **PASS** |
| **Full Backend Suite** | `supabase/functions/` | 199 | 199 | 0 | 2.0s | **PASS** |

---

## 2. Staged Package Test Suite Breakdown (46 Tests)

Command executed:
```powershell
deno test --allow-read docs/testing/phase_3_4_3_browser_package/staging/account/
```

### 1. `deletion_test.ts` (15 Tests)
- `Test 1: Normal Parent deletion with existing profile` — **ok (49ms)**
- `Test 2: Child deletion with existing profile` — **ok (1ms)**
- `Test 3: Missing profile + valid deletion retry` (Verifies retry recovery path) — **ok (811µs)**
- `Test 4: Missing profile + non-delete action` (Verifies non-delete lockout) — **ok (1ms)**
- `Test 5: Invalid JWT` — **ok (1ms)**
- `Test 6: Invalid confirmation` (Requires literal "DELETE") — **ok (1ms)**
- `Test 7: Incorrect caller email` (Rejects email mismatch) — **ok (679µs)**
- `Test 8: Auth deletion failure after profile deletion` (Verifies 500 error reporting) — **ok (1ms)**
- `Test 9: Successful retry after partial failure` (Verifies subsequent retry recovery) — **ok (1ms)**
- `Test 10: Duplicate retry` (Verifies idempotency on repeated delete calls) — **ok (1ms)**
- `Test 11: Concurrent duplicate requests` (Verifies concurrency race safety) — **ok (1ms)**
- `Test 12: Active child/device deletion blocker` (Verifies 409 when devices/members exist) — **ok (1ms)**
- `Test 13: Cross-user deletion attempt` (Verifies caller cannot delete another user) — **ok (639µs)**
- `Test 14: Audit event correctness` (Verifies sequence of audit logs) — **ok (899µs)**
- `Test 15: Existing account export behavior` — **ok (2ms)**

### 2. `handler_wiring_test.ts` (1 Test)
- `staged account: delete and retention actions use the extracted modules` — **ok (2ms)**

### 3. `retention_test.ts` (6 Tests)
- `parseRetentionDays falls back for unusable values` — **ok (968µs)**
- `parseRetentionDays accepts integers and numeric strings` — **ok (198µs)**
- `parseRetentionDays clamps absurd windows` (Defensive clamping to 3650 days) — **ok (112µs)**
- `retentionFromSettings reads both windows with schema defaults` — **ok (200µs)**
- `retentionCutoffs uses a timestamp for location and a date for usage` — **ok (295µs)**
- `buildFamilyRetentionReport never invents negative counts` — **ok (341µs)**

### 4. `scope_test.ts` (17 Tests)
- `scope: a parent who owns the family gets family scope with sweep totals` — **ok (962µs)**
- `scope: a non-owner parent member gets family counts but the sweep totals redacted` — **ok (241µs)**
- `scope: a child member gets device scope and never the sweep marker` — **ok (162µs)**
- `scope: a wrong-family caller is not_reported and reaches no family branch` — **ok (296µs)**
- `scope: an unauthenticated / profile-less caller is not_reported` — **ok (191µs)**
- `scope: a missing or unexpected profile role is not_reported with no counts` — **ok (439µs)**
- `scope: a profile role that disagrees with the membership is not_reported` — **ok (294µs)**
- `scope: membership in an unreported family cannot widen the scope` — **ok (279µs)**
- `counts: family scope counts the family, device scope only the caller's devices` — **ok (314µs)**
- `counts: a child with no devices of their own runs no query` — **ok (198µs)**
- `counts: bogus device ids are dropped and duplicates collapsed` — **ok (211µs)**
- `payload: the family owner alone receives the project-wide sweep totals` — **ok (901µs)**
- `payload: a non-owner parent keeps the timestamp but loses the totals` — **ok (290µs)**
- `payload: a child report has device counts and no sweep at all` — **ok (275µs)**
- `payload: not_reported carries no counts, no families and no sweep` — **ok (261µs)**
- `payload: the documented defaults are reported whatever the scope` — **ok (16ms)**
- `payload: a missing sweep row is reported as null, not as a guess` — **ok (274µs)**

### 5. `validation_test.ts` (7 Tests)
- `normalizeEmail trims, lowercases and rejects non-strings` — **ok (1ms)**
- `delete requires the literal DELETE word` — **ok (712µs)**
- `delete requires the caller's own email, case-insensitively` — **ok (273µs)**
- `delete refuses when the token carries no email` — **ok (159µs)**
- `owner blocker: an otherwise empty family never blocks` — **ok (288µs)**
- `owner blocker: other active members block with their family ids` — **ok (191µs)**
- `owner blocker: active devices block when no other member remains` — **ok (159µs)**

---

## 3. Full Backend Functions Test Suite Breakdown (199 Tests)

Command executed:
```powershell
deno test -A supabase/functions/
```

- `supabase/functions/_shared/enrollment_test.ts`: 3 passed
- `supabase/functions/_shared/error_mapping_test.ts`: 13 passed
- `supabase/functions/_shared/policy_test.ts`: 8 passed
- `supabase/functions/_shared/turn_test.ts`: 8 passed
- `supabase/functions/_shared/validation_test.ts`: 17 passed
- `supabase/functions/account/deletion_test.ts`: 15 passed
- `supabase/functions/account/handler_wiring_test.ts`: 1 passed
- `supabase/functions/account/retention_test.ts`: 6 passed
- `supabase/functions/account/scope_test.ts`: 17 passed
- `supabase/functions/account/validation_test.ts`: 7 passed
- `supabase/functions/auth-bootstrap/bootstrap_test.ts`: 7 passed
- `supabase/functions/device-command/enforcement_test.ts`: 8 passed
- `supabase/functions/device-command/handler_test.ts`: 13 passed
- `supabase/functions/family-admin/authorization_test.ts`: 4 passed
- `supabase/functions/family-admin/delete_zone_atomicity_test.ts`: 8 passed
- `supabase/functions/handler_wiring_test.ts`: 5 passed
- `supabase/functions/remote-session/guard_test.ts`: 11 passed
- `supabase/functions/remote-session/lifecycle_test.ts`: 8 passed
- (Plus device-policy, device-register, device-telemetry, pairing suites)
- **Total: 199 passed, 0 failed in 2 seconds.**

---

## 4. Test Coverage Verification & Branch Analysis

The test suite provides comprehensive verification across all mission-critical branches:
1. **Normal vs Abnormal Deletion Paths:** Tested for parent, child, owner with empty family, owner with populated family (blocked), and owner with active devices (blocked).
2. **Partial-Failure & Retry Recovery:** Explicitly mocks GoTrue timeout and failure after profile deletion, then verifies subsequent retry succeeds.
3. **Privilege Escalation Barriers:** Verifies that a user in retry state (without profile) is rejected with `403 profile_missing` when attempting `export` or `retention_report`.
4. **Scope Partitioning:** Full coverage of three-state scoping for parent owner, parent member, child, and invalid profiles.
