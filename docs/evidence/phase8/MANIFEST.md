# Phase 8 Evidence Pack & Verification Manifest

**Prepared:** 2026-11-04 by Subagent 8 (Phase 8 Master Deliverables & Release Readiness Synthesizer)  
**Coordinator & Subagents:** Coordinator + 8 Autonomous Subagents  
**Not committed** — Per strict Git safety rules, Phase 8 makes zero commits, pushes, or branch manipulations without explicit separate owner authorization.  
**Repository:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Entry & Current HEAD:** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`)  
**Phase 5 Reference HEAD:** `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d`  

---

## 1. Toolchain Actually Used

| Tool | Version Line as Measured | Location on System |
|---|---|---|
| **Flutter** | `Flutter 3.44.6 • channel [user-branch]` | `.fvm/flutter_sdk` (target `C:\Users\ASUS\fvm\versions\3.44.6`) |
| **Dart** | `Dart SDK version: 3.12.2 (stable)` | In FVM Flutter 3.44.6 SDK |
| **Deno** | `deno 2.9.4 (stable, release, x86_64-pc-windows-msvc)` / `v8 15.0.245.2-rusty` / `typescript 6.0.3` | `C:\Users\ASUS\AppData\Local\Microsoft\WinGet\Links\deno.exe` |
| **Gradle** | Gradle Wrapper `9.1.0` (`https://docs.gradle.org/9.1.0/...`) | `android/gradlew.bat` |
| **PostgreSQL** | `psql (PostgreSQL) 16.9` / `postgres (PostgreSQL) 16.9` | `.tools/pgsql16/pgsql/bin` |

---

## 2. Executed Suites, Exit Codes & Results

| # | Command / Harness | Exit | Result Summary | Coverage | Evidence Path | Status |
|---|---|---:|---|---|---|---|
| **1** | `deno test --allow-read supabase/functions/` (with `$env:DENO_DIR`) | 0 | `ok \| 150 passed \| 0 failed (2.735s)` | All 15 Edge Function test files across `account/` (23), `_shared/` (49), `device-command/` (24), `family-admin/` (12), `remote-session/` (19), `handler_wiring_test.ts` (5), plus pre-existing suites | `D:\parentcontrol_app\.tools\ci-logs\deno-full-test.log` | **PASS (SCOPED)** |
| **2** | `deno test --allow-read supabase/functions/family-admin/` | 0 | `ok \| 12 passed \| 0 failed (510ms)` | Targeted SQL-05 safe zone delete RPC atomicity, pre-checks, and authorization guards | `D:\parentcontrol_app\.tools\ci-logs\deno-family-admin-test.log` | **PASS (SCOPED)** |
| **3** | **Local CI Pipeline Runner (Stage 3 Live Execution):** `powershell -ExecutionPolicy Bypass -File scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql` | 0 | `Stage 3: Deno Edge Function Tests PASSED (2.7s)` | Orchestrated execution of 150 Deno tests with individual log capture | `D:\parentcontrol_app\.tools\ci-logs\stage3-deno-test-20261104-110917.log` (37,484 B) | **PASS (SCOPED)** |
| **4** | **PostgreSQL 33-File SQL Regression Chain (CHAIN-01 Positive Run):** `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112` | 0 | `CHAIN p6chain_20261104_095112 EXIT=0 FILES=33 LINES=621 ASSERT_FAILED=0 ERRORS=0` | All 14 migrations, 2 local stubs, 17 test suites (incl. 70, 71, 72, 74, 75, 76) executed sequentially into disposable PG 16.9 database | `.tools/chain_p6chain_20261104_095112.log` | **PASS (SCOPED)** |
| **5** | **Negative Control (SQL-05 Atomic RPC Audit Rollback):** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527` | 3 | `EXIT=3 ASSERT_FAILED=1 ERRORS=1` (`psql:.../76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED`) | Deliberate injection of `supabase/tests/fixtures/sql05_lossy_negative.sql` before test 76. Verified test 76 catches non-atomic RPC | `.tools/chain_p6chain_neg_20261104_095527.log` | **PASS (SCOPED - Verified Red)** |
| **6** | **Evidence & Checksum Integrity Suite (Workstream A):** Verification script against `docs/evidence/phase5/tree-digest-final.txt` | 0 | `69/69 paths verified match (0 mismatches, 0 missing)` | All 69 delivered Phase 5 paths hashed on disk; aggregate `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/implementation/phase-6-checksum-audit.md` | **PASS** |
| **7** | **Evidence Manifest Table Audit:** Verification of all 20 artifacts in `docs/evidence/phase5/MANIFEST.md` §8 | 0 | `20/20 files match exact byte sizes and SHA-256 hashes` | 6 JUnit XMLs, 12 logs, 2 digest tables; self-referential exclusions (§8a) confirmed | `docs/implementation/phase-6-checksum-audit.md` §3 | **PASS** |
| **8** | **Documentation Path Validation (GAP-EV-06):** Automated regex and existence scan of 108 ellipsis instances across markdown | 0 | `108 scanned: 3 invalid paths corrected, 105 verified safe/illustrative` | `README.md`, `_work/p4-enf-residual.md`, `phase-2-regression-matrix.md` corrected | `docs/implementation/phase-6-doc-path-validation.md` | **PASS** |
| **9** | **Gradle Android JVM Tests (Historical Baseline Verification):** 6 test classes, 39 tests | 0 | XML results verified: 39 tests, 0 failures, 0 errors | `AudioAssistanceRecreationTest` (8), `SessionWatchdogTest` (7), `StartGateTest` (4), `StopIdempotenceTest` (3), `EnforcementModeTest` (4), `PolicyEvaluatorTest` (13) | `docs/evidence/phase5/gradle-junit/*.xml` | **PASS (SCOPED - Historical Baseline)** |
| **10** | **Flutter / Dart Test Suites (Historical Baseline Verification):** Whole `lib/` and `test/` tree | 0 | Phase 5 baseline: 408 tests passed, 0 issues found | App restrictions, account privacy, retention scope disclosure (11 cases), export result dialog | `docs/evidence/phase5/logs/p5-coord-flutter-run2.log`, `p5-coord-dart-analyze-run2.log` | **PASS (SCOPED - Historical Baseline)** |

---

## 3. Phase 8 Delivered Assets and File Hashes

The following deliverables were authored, verified, and placed in the repository during Phase 8:

| Deliverable Path | Bytes | SHA-256 Checksum | Operational Purpose |
|---|---:|---|---|
| [`docs/implementation/phase-8-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-report.md) | 22,226 | `9caaed647d38da54c4bed1ee526a7f9ade53a74ce3295786bd6d84fbeb7950c1` | Primary Phase 8 master deliverable & release readiness synthesizer report |
| [`phase-8-report.md`](file:///d:/parentcontrol_app/phase-8-report.md) | 22,226 | `9caaed647d38da54c4bed1ee526a7f9ade53a74ce3295786bd6d84fbeb7950c1` | Repository root mirror copy of Phase 8 master report |
| [`docs/implementation/phase-8-regression-matrix.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-regression-matrix.md) | 11,411 | `d4cf43b06673400f9fb00ff03645936a7d94b3d65e8a6b72d77d13186c716a02` | Comprehensive automated suite matrix, SQL chain metrics, and QA summary |
| [`phase-8-regression-matrix.md`](file:///d:/parentcontrol_app/phase-8-regression-matrix.md) | 11,411 | `d4cf43b06673400f9fb00ff03645936a7d94b3d65e8a6b72d77d13186c716a02` | Repository root mirror copy of Phase 8 regression matrix |
| [`docs/implementation/phase-8-open-gaps.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-open-gaps.md) | 14,925 | `65ca17cd8e64ee14c59adea026ca2168aa1f4a6335ba742372b45acfa9c5e15e` | Complete Open Gaps Register for Phase 8 (0 P0, 2 P1, 6 P2, 6 P3) |
| [`phase-8-open-gaps.md`](file:///d:/parentcontrol_app/phase-8-open-gaps.md) | 14,925 | `65ca17cd8e64ee14c59adea026ca2168aa1f4a6335ba742372b45acfa9c5e15e` | Repository root mirror copy of Phase 8 open gaps register |
| [`docs/implementation/phase-8-decision-execution-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-decision-execution-log.md) | 17,423 | `83ddd3e8f4fc377502b7c679f49b3dfb43156ab73143fcf2864df08419171205` | Authoritative Owner Decision Log reconciling DEC-01 through DEC-11 |
| [`phase-8-decision-execution-log.md`](file:///d:/parentcontrol_app/phase-8-decision-execution-log.md) | 17,423 | `83ddd3e8f4fc377502b7c679f49b3dfb43156ab73143fcf2864df08419171205` | Repository root mirror copy of Phase 8 decision execution log |
| [`docs/implementation/phase-8-deployment-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-deployment-log.md) | 13,012 | `a92876b281bfbb581397800c95cfabab840f24b4f941d52e840a52eebfed7e4f` | Controlled hosted deployment package, 5 SQL preflights, DEC-02 gate block |
| [`phase-8-deployment-log.md`](file:///d:/parentcontrol_app/phase-8-deployment-log.md) | 13,012 | `a92876b281bfbb581397800c95cfabab840f24b4f941d52e840a52eebfed7e4f` | Repository root mirror copy of Phase 8 deployment log |
| [`docs/implementation/phase-8-android-qa-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-android-qa-report.md) | 50,501 | `110b5a104ee6c9a7cd5ca748a3f21436d8246488a2309fa4ae5a24e27856c27f` | Comprehensive Android QA report, 75-row matrix (all NOT RUN), DEC-03 block |
| [`phase-8-android-qa-report.md`](file:///d:/parentcontrol_app/phase-8-android-qa-report.md) | 50,501 | `110b5a104ee6c9a7cd5ca748a3f21436d8246488a2309fa4ae5a24e27856c27f` | Repository root mirror copy of Phase 8 Android QA report |
| [`docs/implementation/phase-8-discrepancy-reconciliation.md`](file:///d:/parentcontrol_app/docs/implementation/phase-8-discrepancy-reconciliation.md) | 19,435 | `acc22faa1d7938424cfd1a2180d0093d458e5ca2984799292acc4da7b5169085` | Detailed discrepancy reconciliation deliverable authored by Subagent 2 |

*Note: Self-referential exclusion applies to `docs/evidence/phase8/MANIFEST.md` itself.*

---

## 4. What Is Deliberately NOT in This Pack (Negative Boundaries)

- **Zero Secrets, Tokens, or Credentials:** Scanning confirms 0 leaked API keys, tokens, passwords, or credentials.
- **Zero Compiled APKs or Device Binaries:** Android Gate B (DEC-03) was NOT authorized; zero debug or release APKs compiled.
- **Zero Production Mutations:** DEC-02 was NOT authorized; zero migrations were applied to hosted Supabase, zero Edge Functions were deployed, and zero live database records were mutated.
- **Zero Automated Schedulers:** DEC-05 was NOT authorized; zero cron jobs or automated webhook schedules were installed.
- **Zero Whole `.tools/` Binaries:** PostgreSQL 16.9 server binaries and retained cluster data directories remain scratch files on workstation disk.

---

## 5. How to Re-Verify This Evidence Pack Offline

From the repository root in PowerShell:

```powershell
# 1. Verify Deno test suite (150 tests)
$env:DENO_DIR = "C:\Users\ASUS\AppData\Local\deno"
deno test --allow-read supabase/functions/

# 2. Verify targeted SQL-05 Deno tests (12 tests)
deno test --allow-read supabase/functions/family-admin/

# 3. Verify Local CI Pipeline Stage 3
powershell -ExecutionPolicy Bypass -File scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql

# 4. Verify PostgreSQL 33-file SQL test chain (CHAIN-01)
.\supabase\tests\run_sql_chain.ps1

# 5. Verify SQL-05 negative control (expect exit code 3, assertion failed at line 411)
.\supabase\tests\run_sql_chain.ps1 -NegativeControl

# 6. Verify Phase 8 deliverable file checksums
$manifestFiles = @(
    "docs/implementation/phase-8-report.md",
    "phase-8-report.md",
    "docs/implementation/phase-8-regression-matrix.md",
    "phase-8-regression-matrix.md",
    "docs/implementation/phase-8-open-gaps.md",
    "phase-8-open-gaps.md",
    "docs/implementation/phase-8-decision-execution-log.md",
    "phase-8-decision-execution-log.md",
    "docs/implementation/phase-8-deployment-log.md",
    "phase-8-deployment-log.md",
    "docs/implementation/phase-8-android-qa-report.md",
    "phase-8-android-qa-report.md",
    "docs/implementation/phase-8-discrepancy-reconciliation.md"
)
foreach ($f in $manifestFiles) {
    $hash = (Get-FileHash -Path $f -Algorithm SHA256).Hash.ToLower()
    Write-Host "$hash *$f"
}
```
