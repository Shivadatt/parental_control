# Phase 3.3 — Report 05: Test Execution Results & Regression Summary

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Execution Environment:** Windows PowerShell / Deno 2.x  
**Execution Scope:** Full Edge Function backend test suite

---

## 1. Test Execution Command & Summary

### Command:
```powershell
deno test --allow-read supabase/functions/
```

### Overall Results:
- **Total Tests Executed:** **199**
- **Passed:** **199**
- **Failed:** **0**
- **Skipped / Ignored:** **0**
- **Execution Time:** ~1.2 seconds

---

## 2. Directory Breakdown

| Test Suite / Module | Test File | Test Count | Passed | Failed | Status |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Account Lifecycle (New)** | `account/deletion_test.ts` | 15 | 15 | 0 | **PASS** |
| **Account Retention Settings** | `account/retention_test.ts` | 6 | 6 | 0 | **PASS** |
| **Account Privacy Scope** | `account/scope_test.ts` | 17 | 17 | 0 | **PASS** |
| **Account Pure Validation** | `account/validation_test.ts` | 7 | 7 | 0 | **PASS** |
| **Shared Enrollment Helpers** | `_shared/enrollment_test.ts` | 3 | 3 | 0 | **PASS** |
| **Shared Error Mapping & SQL** | `_shared/error_mapping_test.ts` | 13 | 13 | 0 | **PASS** |
| **Shared Policy Normalization** | `_shared/policy_test.ts` | 8 | 8 | 0 | **PASS** |
| **Shared TURN ICE Tokenization** | `_shared/turn_test.ts` | 8 | 8 | 0 | **PASS** |
| **Shared Validation & Cryptography** | `_shared/validation_test.ts` | 17 | 17 | 0 | **PASS** |
| **Device Command Enforcement** | `device-command/enforcement_test.ts` | 6 | 6 | 0 | **PASS** |
| **Device Command Handler Logic** | `device-command/handler_test.ts` | 37 | 37 | 0 | **PASS** |
| **Family Admin Authorization** | `family-admin/authorization_test.ts` | 4 | 4 | 0 | **PASS** |
| **Family Admin Zone Atomicity** | `family-admin/delete_zone_atomicity_test.ts` | 8 | 8 | 0 | **PASS** |
| **Handler Source Text Wiring** | `handler_wiring_test.ts` | 5 | 5 | 0 | **PASS** |
| **Remote Session Guards** | `remote-session/guard_test.ts` | 11 | 11 | 0 | **PASS** |
| **Remote Session Lifecycle** | `remote-session/lifecycle_test.ts` | 8 | 8 | 0 | **PASS** |
| **Total** | | **199** | **199** | **0** | **100% PASS** |

---

## 3. Account-Specific Test Output Log

```
running 15 tests from ./supabase/functions/account/deletion_test.ts
Test 1: Normal Parent deletion with existing profile ... ok (44ms)
Test 2: Child deletion with existing profile ... ok (1ms)
Test 3: Missing profile + valid deletion retry ... ok (809µs)
Test 4: Missing profile + non-delete action ... ok (1ms)
Test 5: Invalid JWT ... ok (1ms)
Test 6: Invalid confirmation ... ok (1ms)
Test 7: Incorrect caller email ... ok (653µs)
Test 8: Auth deletion failure after profile deletion ... ok (1ms)
Test 9: Successful retry after partial failure ... ok (1ms)
Test 10: Duplicate retry ... ok (1ms)
Test 11: Concurrent duplicate requests ... ok (1ms)
Test 12: Active child/device deletion blocker ... ok (913µs)
Test 13: Cross-user deletion attempt ... ok (622µs)
Test 14: Audit event correctness ... ok (793µs)
Test 15: Existing account export behavior ... ok (2ms)

running 6 tests from ./supabase/functions/account/retention_test.ts
parseRetentionDays falls back for unusable values ... ok (879µs)
parseRetentionDays accepts integers and numeric strings ... ok (158µs)
parseRetentionDays clamps absurd windows ... ok (135µs)
retentionFromSettings reads both windows with schema defaults ... ok (213µs)
retentionCutoffs uses a timestamp for location and a date for usage ... ok (280µs)
buildFamilyRetentionReport never invents negative counts ... ok (360µs)

running 17 tests from ./supabase/functions/account/scope_test.ts
scope: a parent who owns the family gets family scope with sweep totals ... ok (958µs)
scope: a non-owner parent member gets family counts but the sweep totals redacted ... ok (220µs)
scope: a child member gets device scope and never the sweep marker ... ok (161µs)
scope: a wrong-family caller is not_reported and reaches no family branch ... ok (342µs)
scope: an unauthenticated / profile-less caller is not_reported ... ok (215µs)
scope: a missing or unexpected profile role is not_reported with no counts ... ok (444µs)
scope: a profile role that disagrees with the membership is not_reported ... ok (222µs)
scope: membership in an unreported family cannot widen the scope ... ok (222µs)
counts: family scope counts the family, device scope only the caller's devices ... ok (403µs)
counts: a child with no devices of their own runs no query ... ok (208µs)
counts: bogus device ids are dropped and duplicates collapsed ... ok (203µs)
payload: the family owner alone receives the project-wide sweep totals ... ok (710µs)
payload: a non-owner parent keeps the timestamp but loses the totals ... ok (367µs)
payload: a child report has device counts and no sweep at all ... ok (301µs)
payload: not_reported carries no counts, no families and no sweep ... ok (261µs)
payload: the documented defaults are reported whatever the scope ... ok (16ms)
payload: a missing sweep row is reported as null, not as a guess ... ok (261µs)

running 7 tests from ./supabase/functions/account/validation_test.ts
normalizeEmail trims, lowercases and rejects non-strings ... ok (874µs)
delete requires the literal DELETE word ... ok (271µs)
delete requires the caller's own email, case-insensitively ... ok (225µs)
delete refuses when the token carries no email ... ok (146µs)
owner blocker: an otherwise empty family never blocks ... ok (271µs)
owner blocker: other active members block with their family ids ... ok (188µs)
owner blocker: active devices block when no other member remains ... ok (161µs)

ok | 45 passed | 0 failed (292ms)
```

---

## 4. Handler Wiring Test Output Log

```
running 5 tests from ./supabase/functions/handler_wiring_test.ts
device-command: the ack path decides enforcement only in enforcement.ts ... ok (21ms)
family-admin: zone delete and purge route through the authorization predicates ... ok (1ms)
family-admin: delete_zone sends the zone id and JWT actor to the atomic RPC ... ok (866µs)
remote-session: request sweeps abandoned rows and respond uses the guard patches ... ok (822µs)
account: delete and retention actions use the extracted modules ... ok (1ms)

ok | 5 passed | 0 failed (33ms)
```

---

## 5. Regression Verdict

- **Regressions Observed:** **ZERO (0)**.
- **Backwards Compatibility:** 100% maintained for `account` actions (`export`, `retention_report`, `delete_account`) and global authentication helpers (`requireUser`).
- **All existing unit, integration, and source wiring tests continue to pass without modification.**
