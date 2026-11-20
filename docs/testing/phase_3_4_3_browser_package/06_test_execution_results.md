# Phase 3.4.3 — Report 06: Test Execution Results & Baseline Comparison

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target:** Staged Flat-Root Account Package vs. Original Source Baseline  
**Test Engine:** Deno 2.x  
**Execution Timestamp:** 2026-11-20T05:13:00Z  

---

## 1. Full Backend Test Suite Baseline Confirmation

The comprehensive workspace test suite was executed locally to establish the non-regression baseline:

- **Command:** `deno test --allow-read supabase/functions/`
- **Total Tests:** **199 passed, 0 failed, 0 skipped**
- **Execution Time:** ~6.0s
- **Status:** **100% PASS**

---

## 2. Staged Package Test Suite Execution

A dedicated test suite targeting the staged package files in `docs/testing/phase_3_4_3_browser_package/staging/account/` was executed:

- **Command:** `deno test --allow-read docs/testing/phase_3_4_3_browser_package/staging/account/`
- **Total Tests Executed:** **46 passed, 0 failed, 0 skipped**
- **Execution Time:** 631ms
- **Status:** **100% PASS**

### Granular Test Breakdown:

| Test Module | Test Suite File | Tests Passed | Tests Failed | Key Capabilities Proven |
| :--- | :--- | :---: | :---: | :--- |
| **Account Deletion Lifecycle** | `deletion_test.ts` | 15 | 0 | Parent/Child deletion, missing profile retry resumption, auth failure simulation, duplicate retry, concurrent requests, cross-user blocker, audit veracity. |
| **Retention Domain Logic** | `retention_test.ts` | 6 | 0 | Window parsing, schema defaults, cutoff boundaries, report accumulation. |
| **Retention Scope Matrix** | `scope_test.ts` | 17 | 0 | Owner vs parent vs child scope segregation, redaction of sweep totals for non-owners, unauthenticated rejection. |
| **Payload Validation** | `validation_test.ts` | 7 | 0 | Confirmation token checks, case-insensitive email normalization, empty family blockers. |
| **Handler Wiring** | `handler_wiring_test.ts` | 1 | 0 | Module wiring confirmation, flat shared module linkage, strict confirmation validation. |

---

## 3. Comparative Test Evidence Matrix

| Check Domain | Original Repository Baseline | Staged Browser Package | Regression / Discrepancy |
| :--- | :---: | :---: | :---: |
| **Backend Total Tests** | 199 / 199 PASS | 199 / 199 PASS | None (0) |
| **Account Module Coverage** | 45 / 45 PASS | 46 / 46 PASS (incl. staged wiring test) | None (0) |
| **Handler Wiring Proofs** | 5 / 5 PASS | 5 / 5 PASS | None (0) |
| **Deno Check (Type Checking)** | 0 Errors | 0 Errors | None (0) |
| **Local Test Suite Failures** | 0 | 0 | None (0) |

**Conclusion:** The staged package achieves 100% pass across all 46 targeted tests with zero regressions.
