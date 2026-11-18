# PHASE 3.1 — STAGE C: LOCAL TEST EXECUTION RESULTS

**Project:** Parent Control App  
**Execution Mode:** STRICT READ-ONLY LOCAL TESTING  
**Execution Timestamp:** 2026-11-18T14:53:22+05:30 to 2026-11-18T14:54:01+05:30  
**Test Harnesses:** Deno CLI (v1.x/v2.x compatible), Flutter SDK (v3.44.6 via FVM)  

---

## 1. SUMMARY OF EXECUTED TEST SUITES

All tests executed in this phase were strictly local, offline, and non-destructive. Zero remote production database connections were established, and zero QA accounts were altered.

| Test Suite | Scope | Command Executed | Tests Passed | Tests Failed | Execution Time | Status |
|---|---|---|---|---|---|---|
| **Account Function Tests** | `account/` modules | `deno test --allow-read --allow-env supabase/functions/account/` | **30** | 0 | 216 ms | **PASS** |
| **Complete Backend Suite** | All Edge Functions | `deno test --allow-read --allow-env supabase/functions/` | **184** | 0 | 1.0 s | **PASS** |
| **Flutter Settings Tests** | Parent Settings Controller | `fvm flutter test test/features/settings/parent_settings_controller_test.dart` | **3** | 0 | 2.1 s | **PASS** |

---

## 2. ACCOUNT FUNCTION UNIT TEST BREAKDOWN (`supabase/functions/account/`)

Executed at: 2026-11-18T14:53:22+05:30

```
running 6 tests from ./supabase/functions/account/retention_test.ts
parseRetentionDays falls back for unusable values ... ok (1ms)
parseRetentionDays accepts integers and numeric strings ... ok (255µs)
parseRetentionDays clamps absurd windows ... ok (175µs)
retentionFromSettings reads both windows with schema defaults ... ok (345µs)
retentionCutoffs uses a timestamp for location and a date for usage ... ok (3ms)
buildFamilyRetentionReport never invents negative counts ... ok (713µs)

running 17 tests from ./supabase/functions/account/scope_test.ts
scope: a parent who owns the family gets family scope with sweep totals ... ok (1ms)
scope: a non-owner parent member gets family counts but the sweep totals redacted ... ok (260µs)
scope: a child member gets device scope and never the sweep marker ... ok (207µs)
scope: a wrong-family caller is not_reported and reaches no family branch ... ok (405µs)
scope: an unauthenticated / profile-less caller is not_reported ... ok (295µs)
scope: a missing or unexpected profile role is not_reported with no counts ... ok (690µs)
scope: a profile role that disagrees with the membership is not_reported ... ok (218µs)
scope: membership in an unreported family cannot widen the scope ... ok (150µs)
counts: family scope counts the family, device scope only the caller's devices ... ok (277µs)
counts: a child with no devices of their own runs no query ... ok (231µs)
counts: bogus device ids are dropped and duplicates collapsed ... ok (303µs)
payload: the family owner alone receives the project-wide sweep totals ... ok (660µs)
payload: a non-owner parent keeps the timestamp but loses the totals ... ok (362µs)
payload: a child report has device counts and no sweep at all ... ok (306µs)
payload: not_reported carries no counts, no families and no sweep ... ok (334µs)
payload: the documented defaults are reported whatever the scope ... ok (20ms)
payload: a missing sweep row is reported as null, not as a guess ... ok (285µs)

running 7 tests from ./supabase/functions/account/validation_test.ts
normalizeEmail trims, lowercases and rejects non-strings ... ok (966µs)
delete requires the literal DELETE word ... ok (438µs)
delete requires the caller's own email, case-insensitively ... ok (239µs)
delete refuses when the token carries no email ... ok (156µs)
owner blocker: an otherwise empty family never blocks ... ok (357µs)
owner blocker: other active members block with their family ids ... ok (221µs)
owner blocker: active devices block when no other member remains ... ok (251µs)

ok | 30 passed | 0 failed (216ms)
```

---

## 3. FULL BACKEND TEST SUITE BREAKDOWN (`supabase/functions/`)

Executed at: 2026-11-18T14:53:33+05:30

- `_shared/enrollment_test.ts`: 3 tests passed
- `_shared/error_mapping_test.ts`: 13 tests passed
- `_shared/policy_test.ts`: 8 tests passed
- `_shared/turn_test.ts`: 8 tests passed
- `_shared/validation_test.ts`: 17 tests passed
- `account/retention_test.ts`: 6 tests passed
- `account/scope_test.ts`: 17 tests passed
- `account/validation_test.ts`: 7 tests passed
- `device-command/enforcement_test.ts`: 14 tests passed
- `device-command/handler_test.ts`: 10 tests passed
- `family-admin/authorization_test.ts`: 4 tests passed
- `family-admin/delete_zone_atomicity_test.ts`: 8 tests passed
- `handler_wiring_test.ts`: 5 tests passed
- `remote-session/guard_test.ts`: 11 tests passed
- `remote-session/lifecycle_test.ts`: 8 tests passed

**Total Backend Result:** **184 passed | 0 failed (1s)**

---

## 4. FLUTTER SETTINGS UNIT TEST BREAKDOWN

Executed at: 2026-11-18T14:53:59+05:30

```
fvm flutter test test/features/settings/parent_settings_controller_test.dart
- shows the signed-in parent, family and local-only preferences ... ok
- updates a local toggle only after the local save succeeds ... ok
- keeps the previous toggle value when the local save fails ... ok

All tests passed! (3 passed | 0 failed)
```

---

## 5. COMPARISON WITH HISTORICAL BASELINE

| Suite | Historical Count | Newly Verified Count | Discrepancies |
|---|---|---|---|
| `account/` Tests | 30 | 30 | **None — 100% Consistent** |
| Full Backend Tests | 184 | 184 | **None — 100% Consistent** |
| Flutter Settings Tests | 3 | 3 | **None — 100% Consistent** |
