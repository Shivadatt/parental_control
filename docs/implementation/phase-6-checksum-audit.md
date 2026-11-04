# Phase 6 Checksum & Evidence Integrity Audit Report

**Audit Date**: 2026-11-04  
**Auditor**: Subagent 1 (Checksum & Evidence Auditor, Phase 6)  
**Repository**: `D:\parentcontrol_app`  
**Branch / Git Head**: `main` @ `b12659b9795ba69499483a84750a33897dd7e08a` (`nothing to commit, working tree clean`)  

---

## 1. Executive Summary

This independent audit establishes the cryptographic integrity and provenance of all evidence artifacts, deliverables, and source files delivered at the close of Phase 5, in preparation for Phase 6 QA and gate decisions.

### Key Audit Outcomes

1. **100% Verification of Final Delivered Tree (69 paths)**:  
   Every single one of the 69 paths listed in `docs/evidence/phase5/tree-digest-final.txt` exists on disk and its SHA-256 checksum in the current worktree **matches the expected hash with 0 mismatches** (69/69 OK).
2. **Aggregate Self-Hash Verification**:  
   The self-verifying SHA-256 hash of `docs/evidence/phase5/tree-digest-final.txt` is exactly:
   ```
   2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b
   ```
   This matches the aggregate quoted in `docs/evidence/phase5/MANIFEST.md` §5, §8, and `docs/implementation/phase-5-report.md` §2a.
3. **100% Verification of Evidence Pack Manifest (20 files)**:  
   All 20 files cataloged in `docs/evidence/phase5/MANIFEST.md` §8 (6 JUnit XMLs, 12 test/execution logs, and 2 digest files) were independently verified against disk bytes and SHA-256 hashes. All 20 files match both byte size and cryptographic digest exactly.
4. **Excluded Self-Referential Deliverables (§8a)**:  
   `docs/implementation/phase-5-report.md` was measured at 49,273 bytes with SHA-256 `541628bb96e3a26ca17dd39ef19dbb20ef845d263d254200424bd80ecabd8dfc`, matching `MANIFEST.md` §8a exactly. `docs/evidence/phase5/MANIFEST.md` is measured at 16,225 bytes with SHA-256 `84fa9b3fe2325cbbcfbd8f0a4ebbd1ee5e818dd08c1ffa45e3a87623e645cba9`.
5. **CRLF vs LF Line-Ending Normalization (GAP-EOL-01)**:  
   Due to Windows environment configuration (`core.autocrlf=true` and no repository `.gitattributes`), exactly **7 of the 69 files** contain CRLF in the worktree (`docs/implementation/api-contract.md` and the 6 `docs/evidence/phase5/gradle-junit/*.xml` files). `git ls-files --eol` reports `i/lf w/crlf` for these 7 files. When normalized to LF, their hashes match git blob SHA-256 bit-for-bit. The other 62 files are pure LF on disk (`i/lf w/lf`), matching git blobs directly.
   If re-evaluated in a pure-LF environment (e.g. Linux CI or POSIX checkout), the aggregate of all 69 files across their Git blobs is:
   ```
   7397f79b84466243479f210d05c4410f4890b13529ebe3c18b9e60159d85379b
   ```
6. **Baseline (`tree-digest.txt`, 57 paths) Drift Analysis**:  
   The 57-path baseline represents the codebase state when unit tests were executed mid-phase (aggregate `4ee854c2119eee1264f38e41dd575634d97c7e396e2ceb4a8cbcfed3205725e0`). Exactly 55 paths remain byte-for-byte identical. Exactly 2 paths were updated prior to the final freeze: `docs/implementation/phase-4-owner-approval-register.md` (recording Phase 5 owner decisions) and `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql` (header citation fix). 12 files were added (6 JUnit XMLs, 1 Deno run log, and 5 Phase 5 deliverables), bringing the final total to 69 paths.

---

## 2. CRLF / LF Line-Ending Analysis & Cross-Platform Integrity

### Background and Diagnostic Measurement
In Phase 5, gap **GAP-EOL-01** noted that on Windows workstations without `.gitattributes`, `git checkout` / `git clone` converts line endings according to `core.autocrlf`. The repository is configured with `core.autocrlf=true`.

An exhaustive line-ending inspection (`git ls-files --eol` and binary byte analysis) of all 69 files in `tree-digest-final.txt` shows:
- **62 files** are stored as pure LF in the worktree (`w/lf`) and LF in Git index (`i/lf`). For these 62 files, `worktree_sha256 == git_blob_sha256`.
- **7 files** are stored as CRLF in the worktree (`w/crlf`) and LF in Git index (`i/lf`). For these 7 files, the worktree hash matches `tree-digest-final.txt` (which hashed worktree bytes), while the Git blob stores the LF-normalized equivalent.

### The 7 CRLF Files

| File Path | Worktree Size | CRLF Count | Worktree SHA-256 (in `tree-digest-final.txt`) | Git Blob Size | Git Blob SHA-256 (LF Normalized) |
|---|---|---|---|---|---|
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceRecreationTest.xml` | 1609 | 14 | `d5b6b9780edae3ce5e734b0c479c6812e79af797193f2e813b261ff37c9c7a1a` | 1595 | `6d863d4a0156149b47e77d9e2e7197e8271133136c22a4b6b3748f58e6b0a46c` |
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest.xml` | 1361 | 13 | `c5b9f04c46a69bc6988080f1f65afd61b55d5a7188f69079908807068e1dd574` | 1348 | `32c00adf2bcb090c4598bcc96990793b15c9d4acc13952124cfe5c0d57b7595a` |
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStartGateTest.xml` | 976 | 10 | `27487a227ba7f89ab530d65435cabc2a75406e405b7677154b0cb60115a52b5d` | 966 | `62ba0f100b966f41de0f8855868dfd48fff2f6d533bd3dab6de0f062e3dbb119` |
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest.xml` | 824 | 9 | `15068c2ca6b08597ab549b0b37c2e95df43bc30b8f24f9b1669997b0a50f1d60` | 815 | `0d394b2fc1c8c87c946ea873a6ce16366f33f0445d83f4d9759978bf23e91314` |
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.EnforcementModeTest.xml` | 945 | 10 | `9e8330d8bdc6883457f8f073033b62506a2c5aef89e14007f23a2f3d37e90467` | 935 | `affa3171af540e153bd9b3e6df72137489c52af81f4818f4981734b27d796b57` |
| `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml` | 2195 | 19 | `0e5521555b86161b4ecdbfccc86f334dde347256bbc56ec2afbae32d6e2c8c41` | 2176 | `d46fc92cbb11becf6d57ba49de64b943e8700d0b3bf42cab0f101744cc3cd74a` |
| `docs/implementation/api-contract.md` | 25309 | 275 | `295aa13de2e56eff3b0a6c17301c200a07a344401c4eb38bcd4b3144e0b997ab` | 25034 | `e44ffc131a2dc271ea181b06e0401761083860b808f2808694f1d768fde73a36` |

> **Cryptographic Verification**: For each of these 7 files, replacing `\r\n` with `\n` yields a SHA-256 digest identical to Git's stored blob SHA-256. This confirms that zero content drift occurred—only Windows EOL expansion.

### Cross-Platform Dual Aggregate Table

| Basis | Scope | SHA-256 Aggregate | Notes |
|---|---|---|---|
| **Worktree on Windows** | 69 paths | `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | As stored on disk; matches `tree-digest-final.txt` self-hash |
| **Git Blob (LF)** | 69 paths | `7397f79b84466243479f210d05c4410f4890b13529ebe3c18b9e60159d85379b` | Platform-independent Git object representation |
| **Baseline Worktree** | 57 paths | `4ee854c2119eee1264f38e41dd575634d97c7e396e2ceb4a8cbcfed3205725e0` | Historical test snapshot; matches `tree-digest.txt` self-hash |

---

## 3. Evidence Pack Verification (`docs/evidence/phase5/MANIFEST.md` §8)

The 20 evidence files specified in `docs/evidence/phase5/MANIFEST.md` §8 were audited. All 20 exist, have identical byte sizes, and have matching SHA-256 hashes.

| Path (relative to `docs/evidence/phase5/`) | Manifest Bytes | Actual Bytes | Manifest SHA-256 | Actual SHA-256 | Status |
|---|---|---|---|---|---|
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceRecreationTest.xml` | 1609 | 1609 | `d5b6b9780edae3ce...` | `d5b6b9780edae3ce...` | **PASS** |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest.xml` | 1361 | 1361 | `c5b9f04c46a69bc6...` | `c5b9f04c46a69bc6...` | **PASS** |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStartGateTest.xml` | 976 | 976 | `27487a227ba7f89a...` | `27487a227ba7f89a...` | **PASS** |
| `gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest.xml` | 824 | 824 | `15068c2ca6b08597...` | `15068c2ca6b08597...` | **PASS** |
| `gradle-junit/TEST-com.parentcontrol.parent_control.EnforcementModeTest.xml` | 945 | 945 | `9e8330d8bdc68834...` | `9e8330d8bdc68834...` | **PASS** |
| `gradle-junit/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml` | 2195 | 2195 | `0e5521555b86161b...` | `0e5521555b86161b...` | **PASS** |
| `logs/p5-coord-dart-analyze-run2.log` | 48 | 48 | `9fa0431d7192e9d5...` | `9fa0431d7192e9d5...` | **PASS** |
| `logs/p5-coord-deno-full3.txt` | 19608 | 19608 | `9ebdaedc6b9031d4...` | `9ebdaedc6b9031d4...` | **PASS** |
| `logs/p5-coord-deno-negative.log` | 5672 | 5672 | `d087186c2a67f3d2...` | `d087186c2a67f3d2...` | **PASS** |
| `logs/p5-coord-deno-restored.log` | 18609 | 18609 | `b5589dade24e2bd5...` | `b5589dade24e2bd5...` | **PASS** |
| `logs/p5-coord-deno-sql05.log` | 2645 | 2645 | `8c0e23d7ce45d507...` | `8c0e23d7ce45d507...` | **PASS** |
| `logs/p5-coord-flutter-run2.log` | 61521 | 61521 | `ca2462ccdb8a23db...` | `ca2462ccdb8a23db...` | **PASS** |
| `logs/p5-coord-gradle-run1.log` | 30685 | 30685 | `6d14ac08b60553ca...` | `6d14ac08b60553ca...` | **PASS** |
| `logs/p5coord-chain-negative3.log` | 16844 | 16844 | `e914ecaaed261bd8...` | `e914ecaaed261bd8...` | **PASS** |
| `logs/p5coord-chain-run10.log` | 16388 | 16388 | `4638ad087731369d...` | `4638ad087731369d...` | **PASS** |
| `logs/p5coord-chain-run5.log` | 16316 | 16316 | `f22aefcdaa17666b...` | `f22aefcdaa17666b...` | **PASS** |
| `logs/p5coord-chain-run6.log` | 16325 | 16325 | `23c127e039967692...` | `23c127e039967692...` | **PASS** |
| `logs/p5coord-chain-run9.log` | 16388 | 16388 | `4978d306e5458116...` | `4978d306e5458116...` | **PASS** |
| `tree-digest.txt` | 6462 | 6462 | `4ee854c2119eee12...` | `4ee854c2119eee12...` | **PASS** |
| `tree-digest-final.txt` | 8171 | 8171 | `2bd6b310dae6a0b5...` | `2bd6b310dae6a0b5...` | **PASS** |

### Deliberately Excluded Files (§8a Audit)
- `docs/implementation/phase-5-report.md`: 49,273 bytes, SHA-256 `541628bb96e3a26ca17dd39ef19dbb20ef845d263d254200424bd80ecabd8dfc` (**VERIFIED**)
- `docs/evidence/phase5/MANIFEST.md`: 16,225 bytes, SHA-256 `84fa9b3fe2325cbbcfbd8f0a4ebbd1ee5e818dd08c1ffa45e3a87623e645cba9` (**VERIFIED**)

---

## 4. Baseline (57 paths) vs Final (69 paths) Reconciliation

The mid-phase baseline in `docs/evidence/phase5/tree-digest.txt` captured the 57 paths touched when the test suites were run.

### Updated Paths (2)
Between baseline capture and final freeze, exactly two files received modifications:
1. `docs/implementation/phase-4-owner-approval-register.md`:  
   - Baseline Hash: `4c911f21d8d3bccbf26d816e22b48af3995edd66b7e313a5e2d0582a0cca630d`
   - Final / Current Hash: `333527e01b18f52a649a5418e3614c59ccab2f96855e63405f7eb779806d1913`
   - Reason: Phase 5 annotations added to document owner approvals/decisions taken in Phase 5.
2. `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql`:  
   - Baseline Hash: `4fdf1cfb25606b6893b08738efa45b2c233ff7f6a9f9453351c9c221698bfffc`
   - Final / Current Hash: `a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf`
   - Reason: Header citation update (referencing test 76 and run 9 logs).

### Added Deliverables in Final (12)
12 files were produced during the second half of Phase 5 and included in `tree-digest-final.txt`:
- **6 JUnit Test Result XMLs**: `docs/evidence/phase5/gradle-junit/*.xml`
- **1 Full Deno Test Log**: `docs/evidence/phase5/logs/p5-coord-deno-full3.txt`
- **5 Phase 5 Deliverables**:  
  - `docs/implementation/deployment/manifest.md`
  - `docs/implementation/phase-5-deployment-readiness.md`
  - `docs/implementation/phase-5-open-gaps.md`
  - `docs/implementation/phase-5-owner-decision-log.md`
  - `docs/implementation/phase-5-regression-matrix.md`

---

## 5. Complete 69-Path Audit Table (`tree-digest-final.txt`)

Below is the complete, item-by-item verification table for all 69 entries in `tree-digest-final.txt`.

| # | Path | Worktree SHA-256 (Expected & Actual) | Git Blob SHA-256 | Bytes | EOL | Git EOL | Status |
|---|---|---|---|---|---|---|---|
| 1 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/EnforcementMode.kt` | `f17c10fe9f...` | `f17c10fe9f...` | 1107 | LF | `i/lf w/lf` | **MATCH** |
| 2 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt` | `50f1df4d66...` | `50f1df4d66...` | 29591 | LF | `i/lf w/lf` | **MATCH** |
| 3 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt` | `69297c06ce...` | `69297c06ce...` | 16230 | LF | `i/lf w/lf` | **MATCH** |
| 4 | `android/app/src/test/kotlin/com/parentcontrol/parent_control/EnforcementModeTest.kt` | `87bb510ba6...` | `87bb510ba6...` | 2378 | LF | `i/lf w/lf` | **MATCH** |
| 5 | `docs/backend.md` | `3531ff3da2...` | `3531ff3da2...` | 48155 | LF | `i/lf w/lf` | **MATCH** |
| 6 | `docs/bug-report.md` | `52f3e4845f...` | `52f3e4845f...` | 79280 | LF | `i/lf w/lf` | **MATCH** |
| 7 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceRecreationTest.xml` | `d5b6b9780e...` | `6d863d4a01...` | 1609 | CRLF | `i/lf w/crlf` | **MATCH** |
| 8 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest.xml` | `c5b9f04c46...` | `32c00adf2b...` | 1361 | CRLF | `i/lf w/crlf` | **MATCH** |
| 9 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStartGateTest.xml` | `27487a227b...` | `62ba0f100b...` | 976 | CRLF | `i/lf w/crlf` | **MATCH** |
| 10 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest.xml` | `15068c2ca6...` | `0d394b2fc1...` | 824 | CRLF | `i/lf w/crlf` | **MATCH** |
| 11 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.EnforcementModeTest.xml` | `9e8330d8bd...` | `affa3171af...` | 945 | CRLF | `i/lf w/crlf` | **MATCH** |
| 12 | `docs/evidence/phase5/gradle-junit/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml` | `0e5521555b...` | `d46fc92cbb...` | 2195 | CRLF | `i/lf w/crlf` | **MATCH** |
| 13 | `docs/evidence/phase5/logs/p5-coord-deno-full3.txt` | `9ebdaedc6b...` | `9ebdaedc6b...` | 19608 | LF | `i/lf w/lf` | **MATCH** |
| 14 | `docs/implementation/_work/p4-docs-sql06.md` | `f448d12013...` | `f448d12013...` | 18303 | LF | `i/lf w/lf` | **MATCH** |
| 15 | `docs/implementation/_work/p4-enf-residual.md` | `6f95c97234...` | `6f95c97234...` | 8986 | LF | `i/lf w/lf` | **MATCH** |
| 16 | `docs/implementation/_work/p4-hosted.md` | `34d9b57c08...` | `34d9b57c08...` | 7959 | LF | `i/lf w/lf` | **MATCH** |
| 17 | `docs/implementation/_work/p4-kotlin.md` | `4386397055...` | `4386397055...` | 7281 | LF | `i/lf w/lf` | **MATCH** |
| 18 | `docs/implementation/_work/p4-perf01.md` | `2899ac02be...` | `2899ac02be...` | 10780 | LF | `i/lf w/lf` | **MATCH** |
| 19 | `docs/implementation/_work/p4-test01.md` | `60e84c1dcd...` | `60e84c1dcd...` | 13482 | LF | `i/lf w/lf` | **MATCH** |
| 20 | `docs/implementation/_work/security.md` | `af193963ee...` | `af193963ee...` | 3855 | LF | `i/lf w/lf` | **MATCH** |
| 21 | `docs/implementation/api-contract.md` | `295aa13de2...` | `e44ffc131a...` | 25309 | CRLF | `i/lf w/crlf` | **MATCH** |
| 22 | `docs/implementation/deployment/manifest.md` | `cc154dcbdb...` | `cc154dcbdb...` | 16430 | LF | `i/lf w/lf` | **MATCH** |
| 23 | `docs/implementation/phase-1-report.md` | `436d68c46e...` | `436d68c46e...` | 31781 | LF | `i/lf w/lf` | **MATCH** |
| 24 | `docs/implementation/phase-2-report.md` | `58464d8c9e...` | `58464d8c9e...` | 16543 | LF | `i/lf w/lf` | **MATCH** |
| 25 | `docs/implementation/phase-3-regression-matrix.md` | `2e7d89eeb3...` | `2e7d89eeb3...` | 15488 | LF | `i/lf w/lf` | **MATCH** |
| 26 | `docs/implementation/phase-4-android-validation-plan.md` | `431e3d8690...` | `431e3d8690...` | 56590 | LF | `i/lf w/lf` | **MATCH** |
| 27 | `docs/implementation/phase-4-open-gaps.md` | `93ebf23714...` | `93ebf23714...` | 25079 | LF | `i/lf w/lf` | **MATCH** |
| 28 | `docs/implementation/phase-4-owner-approval-register.md` | `333527e01b...` | `333527e01b...` | 25793 | LF | `i/lf w/lf` | **MATCH** |
| 29 | `docs/implementation/phase-4-regression-matrix.md` | `2745207e4c...` | `2745207e4c...` | 19325 | LF | `i/lf w/lf` | **MATCH** |
| 30 | `docs/implementation/phase-4-report.md` | `7ca4278cef...` | `7ca4278cef...` | 26866 | LF | `i/lf w/lf` | **MATCH** |
| 31 | `docs/implementation/phase-5-deployment-readiness.md` | `f7c6fdbc0a...` | `f7c6fdbc0a...` | 15039 | LF | `i/lf w/lf` | **MATCH** |
| 32 | `docs/implementation/phase-5-open-gaps.md` | `2e40d2b925...` | `2e40d2b925...` | 15004 | LF | `i/lf w/lf` | **MATCH** |
| 33 | `docs/implementation/phase-5-owner-decision-log.md` | `fed6adb539...` | `fed6adb539...` | 15211 | LF | `i/lf w/lf` | **MATCH** |
| 34 | `docs/implementation/phase-5-regression-matrix.md` | `b701d60823...` | `b701d60823...` | 15640 | LF | `i/lf w/lf` | **MATCH** |
| 35 | `docs/implementation/proposals/phase4-retention-sweep-batch-shape.sql` | `889020c5cc...` | `889020c5cc...` | 6400 | LF | `i/lf w/lf` | **MATCH** |
| 36 | `docs/implementation/regression-matrix.md` | `e8188acd66...` | `e8188acd66...` | 16316 | LF | `i/lf w/lf` | **MATCH** |
| 37 | `docs/implementation/remaining-gaps.md` | `85d577b65b...` | `85d577b65b...` | 10239 | LF | `i/lf w/lf` | **MATCH** |
| 38 | `docs/mic_full_audit_report.md` | `e2a2cb8f06...` | `e2a2cb8f06...` | 14850 | LF | `i/lf w/lf` | **MATCH** |
| 39 | `docs/runtime-mic-test-report.md` | `efa62fe3bd...` | `efa62fe3bd...` | 17258 | LF | `i/lf w/lf` | **MATCH** |
| 40 | `docs/stage2_background_audio_report.md` | `2ef54cf277...` | `2ef54cf277...` | 15129 | LF | `i/lf w/lf` | **MATCH** |
| 41 | `docs/stage5_background_audio_survival_report.md` | `4d3c0b6f16...` | `4d3c0b6f16...` | 9671 | LF | `i/lf w/lf` | **MATCH** |
| 42 | `docs/stage6_account_and_media_recovery_report.md` | `2c65fcb5f2...` | `2c65fcb5f2...` | 14403 | LF | `i/lf w/lf` | **MATCH** |
| 43 | `docs/verification-report.md` | `12be5a5683...` | `12be5a5683...` | 73499 | LF | `i/lf w/lf` | **MATCH** |
| 44 | `lib/features/app_restrictions/app_restrictions_controller.dart` | `3b64012686...` | `3b64012686...` | 25466 | LF | `i/lf w/lf` | **MATCH** |
| 45 | `lib/features/settings/account_privacy_repository.dart` | `0ca1573b77...` | `0ca1573b77...` | 9404 | LF | `i/lf w/lf` | **MATCH** |
| 46 | `lib/features/settings/export_result_dialog.dart` | `b2cb6c7c44...` | `b2cb6c7c44...` | 4738 | LF | `i/lf w/lf` | **MATCH** |
| 47 | `lib/features/settings/settings_body.dart` | `9c2ae2703f...` | `9c2ae2703f...` | 21846 | LF | `i/lf w/lf` | **MATCH** |
| 48 | `supabase/functions/_shared/error_mapping_test.ts` | `e37c8d417e...` | `e37c8d417e...` | 25129 | LF | `i/lf w/lf` | **MATCH** |
| 49 | `supabase/functions/_shared/fake_postgrest.ts` | `a20ce6c1cc...` | `a20ce6c1cc...` | 21101 | LF | `i/lf w/lf` | **MATCH** |
| 50 | `supabase/functions/account/index.ts` | `a9fd970702...` | `a9fd970702...` | 18775 | LF | `i/lf w/lf` | **MATCH** |
| 51 | `supabase/functions/account/retention.ts` | `aa1b3b3139...` | `aa1b3b3139...` | 10238 | LF | `i/lf w/lf` | **MATCH** |
| 52 | `supabase/functions/account/scope_test.ts` | `5aca043798...` | `5aca043798...` | 15893 | LF | `i/lf w/lf` | **MATCH** |
| 53 | `supabase/functions/device-command/handler.ts` | `d1a33cc0ee...` | `d1a33cc0ee...` | 15885 | LF | `i/lf w/lf` | **MATCH** |
| 54 | `supabase/functions/device-command/handler_test.ts` | `61ccb6e6a6...` | `61ccb6e6a6...` | 21501 | LF | `i/lf w/lf` | **MATCH** |
| 55 | `supabase/functions/device-command/index.ts` | `55363d3957...` | `55363d3957...` | 596 | LF | `i/lf w/lf` | **MATCH** |
| 56 | `supabase/functions/family-admin/delete_zone_atomicity_test.ts` | `063f326589...` | `063f326589...` | 13665 | LF | `i/lf w/lf` | **MATCH** |
| 57 | `supabase/functions/family-admin/index.ts` | `6b2a762c88...` | `6b2a762c88...` | 14009 | LF | `i/lf w/lf` | **MATCH** |
| 58 | `supabase/functions/handler_wiring_test.ts` | `fecf1941a3...` | `fecf1941a3...` | 10819 | LF | `i/lf w/lf` | **MATCH** |
| 59 | `supabase/migrations/20261030000300_retention_sweep.sql` | `184d8acb33...` | `184d8acb33...` | 11853 | LF | `i/lf w/lf` | **MATCH** |
| 60 | `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql` | `a1d7d60954...` | `a1d7d60954...` | 13805 | LF | `i/lf w/lf` | **MATCH** |
| 61 | `supabase/tests/71_phase1_rollback_privileges.sql` | `cc8dd58799...` | `cc8dd58799...` | 26307 | LF | `i/lf w/lf` | **MATCH** |
| 62 | `supabase/tests/74_sweep_indexes_and_repeatability.sql` | `faeb6f3d53...` | `faeb6f3d53...` | 43793 | LF | `i/lf w/lf` | **MATCH** |
| 63 | `supabase/tests/75_signaling_replay_index_duplicate_guard.sql` | `daad50c9a5...` | `daad50c9a5...` | 11466 | LF | `i/lf w/lf` | **MATCH** |
| 64 | `supabase/tests/76_zone_delete_atomic_rpc.sql` | `5572c4ac0a...` | `5572c4ac0a...` | 33307 | LF | `i/lf w/lf` | **MATCH** |
| 65 | `supabase/tests/README.md` | `d8f91f2529...` | `d8f91f2529...` | 18880 | LF | `i/lf w/lf` | **MATCH** |
| 66 | `test/features/app_restrictions/policy_read_supersede_test.dart` | `87c6aaf022...` | `87c6aaf022...` | 10652 | LF | `i/lf w/lf` | **MATCH** |
| 67 | `test/features/settings/account_privacy_controller_test.dart` | `ae5da12830...` | `ae5da12830...` | 8191 | LF | `i/lf w/lf` | **MATCH** |
| 68 | `test/features/settings/export_result_dialog_test.dart` | `d87890c1eb...` | `d87890c1eb...` | 3963 | LF | `i/lf w/lf` | **MATCH** |
| 69 | `test/features/settings/retention_scope_disclosure_test.dart` | `9f12f81dd9...` | `9f12f81dd9...` | 9564 | LF | `i/lf w/lf` | **MATCH** |

---

## 6. Recommendations for Phase 6 QA & Deployment

1. **Repository EOL Pinning (`.gitattributes`)**:  
   To permanently eliminate CRLF vs LF drift and ensure deterministic SHA-256 verification across all operating systems (Windows, Linux, macOS), add a `.gitattributes` file configuring:
   ```gitattributes
   * text=auto eol=lf
   *.xml text eol=lf
   *.md text eol=lf
   *.ts text eol=lf
   *.sql text eol=lf
   *.dart text eol=lf
   *.kt text eol=lf
   ```
2. **Evidence Verification Tooling**:  
   When running verification in CI/CD pipelines, verify against Git blob hashes (`git cat-file blob <id> | sha256sum`) or explicitly check out with `git config core.autocrlf false` to ensure test digests match POSIX environments.
3. **Commit Integrity**:  
   Commit `b12659b9795ba69499483a84750a33897dd7e08a` clean state preserves the exact byte sequence of Phase 5. All evidence files are safely tracked and committed in Git, fully closing durability gap **EVD-01**.
