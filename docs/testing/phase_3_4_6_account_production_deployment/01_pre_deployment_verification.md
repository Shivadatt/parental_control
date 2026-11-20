# Phase 3.4.6 — Report 01: Pre-Deployment Verification Gate & Package Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Organization ID:** `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`)  
**Region:** `ap-northeast-2` (Seoul / Northeast Asia)  
**Target Function:** `account`  
**Staging Directory:** `docs/testing/phase_3_4_3_browser_package/staging/account/`  
**Audit Date:** 2026-11-20  

---

## 1. Project & Scope Boundary Verification

| Property | Required Value | Verified Value | Gate Status |
|---|---|---|---|
| **Organization ID** | `symqztrmaziuwdibcfrq` | `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`) | **PASS** |
| **Project Name** | `parent-control-prod` | `parent-control-prod` | **PASS** |
| **Project Ref** | `hhqgreaoqulmfwfwarhc` | `hhqgreaoqulmfwfwarhc` | **PASS** |
| **Region** | `ap-northeast-2` | `ap-northeast-2` (Seoul) | **PASS** |
| **Target Function** | `account` | `account` | **PASS** |
| **Deployment Method** | Dashboard Browser Editor | Monaco Editor at `/functions/new` | **PASS** |

---

## 2. Staged Package File Integrity (Local SHA-256 Gate)

All nine staged files in `docs/testing/phase_3_4_3_browser_package/staging/account/` were hashed via SHA-256 and compared against the Phase 3.4.3 baseline manifest:

| # | Filename | Bytes | Lines | Expected SHA-256 | Actual SHA-256 | Match |
|---|---|---|---|---|---|---|
| 1 | `index.ts` | 15,868 | 480 | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | `31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723` | **PASS** |
| 2 | `deletion.ts` | 19,699 | 641 | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | `64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8` | **PASS** |
| 3 | `retention.ts` | 10,537 | 300 | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | `0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed` | **PASS** |
| 4 | `validation.ts` | 3,908 | 117 | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | `5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde` | **PASS** |
| 5 | `shared-audit.ts` | 1,145 | 37 | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | `b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0` | **PASS** |
| 6 | `shared-envelope.ts` | 3,637 | 111 | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | `f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd` | **PASS** |
| 7 | `shared-cors.ts` | 502 | 12 | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | `1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9` | **PASS** |
| 8 | `shared-auth.ts` | 10,818 | 353 | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | `f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5` | **PASS** |
| 9 | `shared-validation.ts` | 13,067 | 418 | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | `263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3` | **PASS** |

Result: **9 / 9 files match expected baseline SHA-256 hashes.**

---

## 3. Local Test Suite Baseline Execution

Prior to authorizing deployment, both the staged package suite and full backend test suite were executed:

1. **Staged Test Suite:**
   - Command: `deno test --allow-read docs/testing/phase_3_4_3_browser_package/staging/account/`
   - Files tested: `deletion_test.ts`, `handler_wiring_test.ts`, `retention_test.ts`, `scope_test.ts`, `validation_test.ts`
   - Result: **46 passed, 0 failed** in 411ms.

2. **Full Backend Test Suite:**
   - Command: `deno test -A supabase/functions/`
   - Result: **199 passed, 0 failed** in 1.0s.

---

## 4. Editor Buffer Completeness & Import Resolution Audit

1. **Flat Sibling Architecture:**
   - Exactly nine files present in the editor tree.
   - Zero nested directories or `_shared/` references.
   - All imports resolve to `./shared-*.ts` or external Deno/npm packages.
2. **`shared-envelope.ts` Integrity:**
   - Verified 111 lines in the buffer.
   - Intact export functions: `readJson`, `requireAction`, and `ensureNoError`.
   - Verified visually via screenshot `01_shared_envelope_ts_complete_lines_90_111.png`.

---

## 5. Pre-Deployment Function State in Supabase Dashboard

Edge Functions list verified prior to deployment:
- 9 active functions: `apply-policies`, `check-app-uninstall`, `device-ack`, `device-command`, `family-admin`, `pairing`, `realtime-token`, `remote-session`, `report-usage`.
- `account` is undeployed.

**All Pre-Deployment Gates: PASSED.**
