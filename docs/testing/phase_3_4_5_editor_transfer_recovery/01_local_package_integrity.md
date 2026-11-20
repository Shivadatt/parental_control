# Phase 3.4.5 — Report 01: Local Source Package Integrity & Baseline Gate

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project Name:** `parent-control-prod`  
**Supabase Project Ref:** `hhqgreaoqulmfwfwarhc`  
**Organization ID:** `symqztrmaziuwdibcfrq`  
**Target Function:** `account`  
**Source Staging Directory:** `docs/testing/phase_3_4_3_browser_package/staging/account/`  
**Audit Timestamp:** 2026-11-20T08:02:00Z  

---

## 1. Objective

Independently measure and verify the cryptographic integrity, byte count, line count, and test suite pass rate of all nine local staged files prior to transferring them into the Supabase Dashboard web editor.

---

## 2. Nine-File Integrity & SHA-256 Audit

Every file in the staging directory was read from local disk and verified against the established Phase 3.4.3 / Phase 3.4.4 baseline hashes:

| File Name | Byte Count | Line Count | Expected SHA-256 Baseline | Measured SHA-256 Checksum | Match Status |
| :--- | :---: | :---: | :--- | :--- | :---: |
| **`index.ts`** | 15,868 | 480 | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | **PASS (100%)** |
| **`deletion.ts`** | 19,699 | 641 | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | **PASS (100%)** |
| **`retention.ts`** | 10,537 | 300 | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | **PASS (100%)** |
| **`validation.ts`** | 3,908 | 117 | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | **PASS (100%)** |
| **`shared-audit.ts`** | 1,145 | 37 | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | **PASS (100%)** |
| **`shared-envelope.ts`** | 3,637 | 111 | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | **PASS (100%)** |
| **`shared-cors.ts`** | 502 | 12 | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | **PASS (100%)** |
| **`shared-auth.ts`** | 10,818 | 353 | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | **PASS (100%)** |
| **`shared-validation.ts`** | 13,067 | 418 | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | **PASS (100%)** |

- **Total Staged Files:** Exactly 9 files.
- **Cryptographic Mismatches:** 0 (Zero).
- **Corrupted / Truncated Local Files:** 0 (Zero).
- **Special Verification of `shared-envelope.ts`:** Confirmed complete at 111 lines (3,637 bytes), containing all exports (`ApiError`, `ok`, `errorResponse`, `readJson`, `requireAction`, `ensureNoError`).

---

## 3. Automated Test Suite Validation

The local staged package and the entire workspace backend baseline were executed via `deno test`:

1. **Staged Package Test Suite:**
   ```bash
   deno test --allow-read docs/testing/phase_3_4_3_browser_package/staging/account/
   ```
   - **Result:** **46 passed, 0 failed** (411ms).
   - Tests cover: `deletion_test.ts` (15 tests), `handler_wiring_test.ts` (1 test), `retention_test.ts` (6 tests), `scope_test.ts` (17 tests), `validation_test.ts` (7 tests).

2. **Full Workspace Backend Baseline:**
   ```bash
   deno test -A supabase/functions/
   ```
   - **Result:** **199 passed, 0 failed** (1s).
   - Zero regressions across existing functions (`auth-bootstrap`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`, `_shared`).

---

## 4. Integrity Gate Verdict

**LOCAL PACKAGE INTEGRITY GATE: PASSED**  
The local staging directory `docs/testing/phase_3_4_3_browser_package/staging/account/` is 100% verified, cryptographically intact, and represents the authoritative single source of truth for all subsequent editor transfer operations.
