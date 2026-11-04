# Phase 7 Evidence Pack & Verification Manifest

Prepared 2026-11-04 by the Coordinator & 8 Autonomous Subagents.  
**Not committed** — per Git Safety Rules, Phase 7 makes no commit, push, or branch without explicit separate owner authorization.  
Every artifact described here was produced and verified on this workstation against branch `main`, entry HEAD `b12659b9795ba69499483a84750a33897dd7e08a`.

---

## 1. Toolchain Actually Used

| Tool | Version Line as Measured | Location on System |
|---|---|---|
| Flutter | `Flutter 3.44.6 • channel [user-branch]` | `.fvm/flutter_sdk` (target `C:\Users\ASUS\fvm\versions\3.44.6`) |
| Dart | `Dart SDK version: 3.12.2 (stable)` | In FVM Flutter 3.44.6 SDK |
| Deno | `deno 2.9.4 (stable, release, x86_64-pc-windows-msvc)` / `v8 15.0.245.2-rusty` / `typescript 6.0.3` | `C:\Users\ASUS\AppData\Local\Microsoft\WinGet\Links\deno.exe` |
| Gradle | Gradle Wrapper `9.1.0` (`https://docs.gradle.org/9.1.0/...`) | `android/gradlew.bat` |
| PostgreSQL | `psql (PostgreSQL) 16.9` / `postgres (PostgreSQL) 16.9` | `.tools/pgsql16/pgsql/bin` |

---

## 2. Executed Suites, Exit Codes & Results

| # | Command / Harness | Exit | Result Summary | Coverage | Evidence Path |
|---|---|---:|---|---|---|
| **1** | `deno test --allow-read supabase/functions/` (with `$env:DENO_DIR`) | 0 | `ok \| 150 passed \| 0 failed (5s)` | All Edge Function test suites (account, device-command, family-admin, remote-session, error_mapping, turn, validation, enrollment) | Captured live in session; reproducible offline via fake PostgREST |
| **2** | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed (222ms)` | Targeted SQL-05 safe zone delete RPC atomicity, pre-checks, and handler wiring isolation | Captured live in session; 17/17 passed |
| **3** | `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112 -Port 55584` | 0 | `CHAIN p6chain_... EXIT=0 FILES=33 LINES=621 ASSERT_FAILED=0 ERRORS=0` | All 14 migrations, 2 stubs, 17 test suites executed sequentially into fresh disposable PG 16.9 database | `.tools/chain_p6chain_20261104_095112.log` |
| **4** | **Negative Control (SQL-05):** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527 -Port 55584` | 3 | `EXIT=3 ASSERT_FAILED=1 ERRORS=1` (`psql:.../76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED`) | Lossy non-atomic RPC variant injected before test 76; verifies test 76 catches audit failure without rollback | `.tools/chain_p6chain_neg_20261104_095527.log` |
| **5** | Verification of `docs/evidence/phase5/tree-digest-final.txt` | 0 | `69/69 paths match (0 mismatches, 0 missing)` | All 69 delivered Phase 5 files verified against working tree bytes; aggregate `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/implementation/phase-6-checksum-audit.md` |
| **6** | Verification of `docs/evidence/phase5/MANIFEST.md` §8 | 0 | `20/20 files match exact byte sizes and hashes` | 6 JUnit XMLs, 12 logs, 2 digest tables; self-referential reports verified | `docs/implementation/phase-6-checksum-audit.md` §3 |
| **7** | Local CI Runner (`scripts/local-ci.ps1` Stage 3 Live Execution) | 0 | `Stage 3: Deno Edge Function Tests PASSED (2.1s)` | Orchestrated execution of 150 Deno tests with individual log capture | `.tools/ci-logs/stage3-deno-test-20261104-101911.log` |
| **8** | Documentation Ellipsis Path Verification (GAP-EV-06) | 0 | `108 scanned: 3 invalid paths corrected, 105 verified safe/illustrative` | `README.md`, `_work/p4-enf-residual.md`, `phase-2-regression-matrix.md` corrected | `docs/implementation/phase-6-doc-path-validation.md` |

---

## 3. Phase 7 Delivered Assets and File Hashes

The following deliverables were authored, verified, and placed in the repository during Phase 7:

| Deliverable Path | Bytes | SHA-256 Checksum | Operational Purpose |
|---|---:|---|---|
| [`docs/implementation/phase-7-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-report.md) | 25479 | `8ae08cf9077e2b2da066a201f59ac91eb142a3460beb886be6bbfb3260d063cd` | Primary Phase 7 comprehensive synthesis, verification, and gate enforcement report |
| [`docs/implementation/phase-7-regression-matrix.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-regression-matrix.md) | 24726 | `f5d4f6524d26621c3864b7d9ec050eba27aa3be898734b309e0b142c72d0e441` | Authoritative test suite matrix, SQL chain metrics, and 75-row controlled QA specification |
| [`docs/implementation/phase-7-open-gaps.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-open-gaps.md) | 32842 | `3a0c974c8ab2684a54dce07c6bc25179cbd06ab76ddc8def75ccd358278f1551` | Complete Open Gaps Register for Phase 7 (0 P0, 2 P1, 6 P2, 6 P3) and security reviews |
| [`docs/implementation/phase-7-deployment-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-deployment-log.md) | 28561 | `c2c5fd4326cefb885af7ab020590432910c4721028a551aff8000e04dcd7eb4b` | Controlled hosted deployment package, 5 SQL preflight queries, and DEC-02 gate block |
| [`docs/implementation/phase-7-android-qa-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-android-qa-report.md) | 44145 | `305a55466315473805940af31b80e98e02a29f817a9e954cebab2813ba051db5` | Controlled Android QA report, 75-row matrix (all NOT RUN), privacy invariants, and DEC-03 block |
| [`docs/implementation/phase-7-owner-decision-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-owner-decision-log.md) | 18004 | `ee10860f4f2e5a58e5934e66c3f44d6e870093a4421fe42bfb2254008ac2bd2a` | Authoritative Owner Decision Log reconciling DEC-01 through DEC-11 and CONF-01 resolution |
| [`scripts/local-ci.ps1`](file:///d:/parentcontrol_app/scripts/local-ci.ps1) | 15643 | `ba24ac0e5c37bab76755e71f39d4958a8accbf6dd61d361969e34b48d06dc723` | Multi-stage local CI pipeline with safe symlink resolution and native command stderr isolation |
| [`supabase/tests/run_sql_chain.ps1`](file:///d:/parentcontrol_app/supabase/tests/run_sql_chain.ps1) | 11562 | `cd456ddc7bbcdf4bc4536d9ee2aa0d66bdabc6b402b8501b0192d4e1369c825e` | PowerShell disposable PostgreSQL 33-file test chain runner with negative control |
| [`supabase/tests/run_sql_chain.sh`](file:///d:/parentcontrol_app/supabase/tests/run_sql_chain.sh) | 10923 | `b262ef643049881a5c449ab2b81b1de2c41f255add0d5bed221d151276ca65b7` | Bash companion runner for Linux and Git Bash environments |
| [`supabase/tests/fixtures/sql05_lossy_negative.sql`](file:///d:/parentcontrol_app/supabase/tests/fixtures/sql05_lossy_negative.sql) | 2781 | `9fb1c023311fbf039787e70add5de7bb0cb567eb89af461300c2a53bc6e79757` | Tracked non-atomic RPC fixture for SQL-05 negative control testing |
| [`docs/evidence/phase6/MANIFEST.md`](file:///d:/parentcontrol_app/docs/evidence/phase6/MANIFEST.md) | 9190 | `825e71392a59f890c27b6ccd410dfd5d6d65a54751d131f6d0246ae02765703b` | Phase 6 evidence pack manifest verified bit-for-bit |

*Note: Self-referential exclusion applies to `docs/evidence/phase7/MANIFEST.md` itself.*

---

## 4. What Is Deliberately NOT in This Pack (Negative Boundaries)

- **No Secrets, Tokens, or Credentials:** Forensic pattern scanning confirms 0 leaked API keys, tokens, or credentials.
- **No Compiled APKs or Device Binaries:** Android Gate B (DEC-03) was NOT authorized for device execution; zero debug or release APKs were compiled or installed.
- **No Production Modifications:** DEC-02 was NOT authorized; zero migrations were applied to hosted Supabase, zero Edge Functions were deployed, and zero live database rows were written or deleted.
- **No Whole `.tools/` Binaries:** PostgreSQL 16.9 server binaries and retained data clusters remain scratch files on workstation disk.

---

## 5. How to Re-Verify This Evidence Pack Offline

From the repository root in PowerShell:

```powershell
# 1. Verify Deno test suite (150 tests)
$env:DENO_DIR = "C:\Users\ASUS\AppData\Local\deno"
deno test --allow-read supabase/functions/

# 2. Verify targeted SQL-05 Deno tests (17 tests)
deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts

# 3. Verify PostgreSQL 33-file SQL test chain (CHAIN-01)
.\supabase\tests\run_sql_chain.ps1

# 4. Verify SQL-05 negative control (expect exit code 3, assertion failed at line 411)
.\supabase\tests\run_sql_chain.ps1 -NegativeControl

# 5. Verify delivered Phase 7 file checksums
$manifestFiles = @(
    "docs/implementation/phase-7-report.md",
    "docs/implementation/phase-7-regression-matrix.md",
    "docs/implementation/phase-7-open-gaps.md",
    "docs/implementation/phase-7-deployment-log.md",
    "docs/implementation/phase-7-android-qa-report.md",
    "docs/implementation/phase-7-owner-decision-log.md",
    "scripts/local-ci.ps1",
    "supabase/tests/run_sql_chain.ps1",
    "supabase/tests/run_sql_chain.sh",
    "supabase/tests/fixtures/sql05_lossy_negative.sql"
)
foreach ($f in $manifestFiles) {
    $hash = (Get-FileHash -Path $f -Algorithm SHA256).Hash.ToLower()
    Write-Host "$hash *$f"
}
```

Every command executes deterministically offline without network calls or external hosted dependencies.

