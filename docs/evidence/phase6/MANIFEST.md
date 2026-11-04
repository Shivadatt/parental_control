# Phase 6 Evidence Pack & Verification Manifest (EVD-02)

Prepared 2026-11-04 by the Coordinator & 8 Autonomous Subagents.  
**Not committed** — per Git Safety Rules, Phase 6 makes no commit, push, or branch.  
Every artifact described here was produced on this workstation against branch `main`, entry HEAD `b12659b9795ba69499483a84750a33897dd7e08a`.

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
| **1** | `deno test --allow-read supabase/functions/` (with `$env:DENO_DIR`) | 0 | `ok \| 150 passed \| 0 failed (5s)` | All Edge Function test suites (account, device-command, family-admin, remote-session, error_mapping, turn, validation, enrollment) | Captured live; reproducible offline via fake PostgREST |
| **2** | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed (277ms)` | Targeted SQL-05 safe zone delete RPC atomicity, pre-checks, and handler wiring isolation | Captured live; 17/17 passed |
| **3** | `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112` | 0 | `CHAIN p6chain_... EXIT=0 FILES=33 LINES=621 ASSERT_FAILED=0 ERRORS=0` | All 14 migrations, 2 stubs, 17 test suites executed into fresh disposable PG 16.9 database | `.tools/chain_p6chain_20261104_095112.log` |
| **4** | **Negative Control (SQL-05):** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527` | 3 | `EXIT=3 ASSERT_FAILED=1 ERRORS=1` (`psql:.../76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED`) | Lossy non-atomic RPC variant injected before test 76; verifies test 76 catches audit failure without rollback | `.tools/chain_p6chain_neg_20261104_095527.log` |
| **5** | Verification of `docs/evidence/phase5/tree-digest-final.txt` | 0 | `69/69 paths match (0 mismatches, 0 missing)` | All 69 delivered Phase 5 files verified against working tree bytes; aggregate `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/implementation/phase-6-checksum-audit.md` |
| **6** | Verification of `docs/evidence/phase5/MANIFEST.md` §8 | 0 | `20/20 files match exact byte sizes and hashes` | 6 JUnit XMLs, 12 logs, 2 digest tables; self-referential reports verified | `docs/implementation/phase-6-checksum-audit.md` §3 |
| **7** | Documentation Ellipsis Path Verification (GAP-EV-06) | 0 | `108 scanned: 3 invalid paths corrected, 105 verified safe/illustrative` | `README.md`, `_work/p4-enf-residual.md`, `phase-2-regression-matrix.md` corrected | `docs/implementation/phase-6-doc-path-validation.md` |

---

## 3. The CHAIN-01 SQL Test Runner

`supabase/tests/run_sql_chain.ps1` (and companion `run_sql_chain.sh`) provides turn-key, reproducible execution of the authoritative 33-file SQL regression chain on Windows and Linux:
- **Automatic Lifecycle:** Connects to or launches local PostgreSQL 16.9 on `$PgPort` (default 55584), creates an isolated disposable database, runs all 33 files with `ON_ERROR_STOP=1`, parses logs for errors and failed assertions, and safely drops the disposable database.
- **Negative Control Mode:** Passing `-NegativeControl` (or `--negative`) injects `supabase/tests/fixtures/sql05_lossy_negative.sql` immediately prior to test 76, expecting exit code 3 and assertion failure at line 411.
- **Whitelist Protection:** Database names are regex-constrained (`^(p6chain_|p5rpc_|ci_|test_|disposable_)`); system or production databases can never be dropped.

---

## 4. Phase 6 Delivered Assets and File Hashes

The following deliverables were produced, verified, and placed in the repository during Phase 6:

| Deliverable Path | Bytes | SHA-256 Checksum | Operational Purpose |
|---|---:|---|---|
| `docs/implementation/phase-6-report.md` | 19247 | `f706845588cff903ff50de6e0054194e92d255c6629e8cc831a8531c6f9d025e` | Primary Phase 6 comprehensive audit, verification, and closure report |
| `docs/implementation/phase-6-regression-matrix.md` | 10750 | `d0689ba96e39ea08aff1c5a49380dd733cfcc9bff735080bbc545db9c19b7569` | Authoritative test suite matrix, SQL chain metrics, and 75-row QA summary |
| `docs/implementation/phase-6-open-gaps.md` | 10919 | `08ca4bbc830f5cba1b543abf6fc8d1b5b1d7f25e1fe94058ca9c4be6234cdfdc` | Full open gap register, severity classification (P0–P3), closures, and status |
| `docs/implementation/phase-6-checksum-audit.md` | 22873 | `6fcba5f64a22e23a906059131016afbcbaf27b4ec881691ca6f30a953ece921f` | Forensic checksum audit of 69 paths, CRLF findings, and dual aggregate proof |
| `docs/implementation/phase-6-qa-readiness.md` | 38607 | `74acbe4587b8b5e28736c6e07de6cc3c456cbaa61c824d8a57d78a59e604fa9c` | Controlled Android QA execution package with full 75-row matrix (all NOT RUN) |
| `docs/implementation/phase-6-owner-decision-register.md` | 29687 | `d90e5aaaa8ee951840bea2d9c07b4cc7bc4c8c712883fb7150bae7174905be27` | Reconciled owner decision register, CONF-01 resolution, and DEC-01..11 |
| `docs/implementation/phase-6-doc-path-validation.md` | 32082 | `5cc07c1b6158442088cac150860697b39735fbdfc3875b3020cc5ed6083f4682` | GAP-EV-06 scan of 108 ellipsis instances, GAP-EOL-01 options, and link audit |
| `docs/implementation/phase-6-workstream-c-env-chain.md` | 22242 | `2e0f5262473c5b1be0fb6cdf57dccf9b73286a68660cb654257887d102bdfef6` | GAP-ENV-01 cluster audit (~1.03 GB) and CHAIN-01 technical specification |
| `scripts/local-ci.ps1` | 13937 | `7fa15740342b3e8d41731a675ec4f8f7b562321884fc9a9ce45714acb80ff534` | Multi-stage local CI pipeline orchestrating Dart, Flutter, Deno, Gradle, and SQL |
| `supabase/tests/run_sql_chain.ps1` | 11562 | `cd456ddc7bbcdf4bc4536d9ee2aa0d66bdabc6b402b8501b0192d4e1369c825e` | PowerShell disposable PostgreSQL 33-file test chain runner with negative control |
| `supabase/tests/run_sql_chain.sh` | 10923 | `b262ef643049881a5c449ab2b81b1de2c41f255add0d5bed221d151276ca65b7` | Bash companion runner for Linux and Git Bash environments |
| `supabase/tests/fixtures/sql05_lossy_negative.sql` | 2781 | `9fb1c023311fbf039787e70add5de7bb0cb567eb89af461300c2a53bc6e79757` | Tracked non-atomic RPC fixture for SQL-05 negative control testing |

*Note: Self-referential exclusion applies to `docs/evidence/phase6/MANIFEST.md` itself, which cannot include its own hash.*

---

## 5. What Is Deliberately NOT in This Pack

- **No Secrets, Tokens, or Credentials:** Forensic pattern scanning (`Bearer `, `eyJ[A-Za-z0-9_-]{20,}`, `service_role_key`, `SUPABASE_KEY`, `password`) confirms 0 credential leaks.
- **No Compiled APKs or Device Binaries:** Android Gate B was not authorized for device execution; no QA APK was built or installed.
- **No Production Modifications:** 0 migrations applied to hosted Supabase, 0 Edge Functions deployed, 0 live database rows written or deleted.
- **No Whole `.tools/` Binaries:** PostgreSQL 16.9 server binaries (~200 MB) and retained data clusters (~1.03 GB) remain local scratch artifacts.

---

## 6. How to Re-Verify This Evidence Pack

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

# 5. Verify delivered Phase 6 file checksums
$manifestFiles = @(
    "docs/implementation/phase-6-report.md",
    "docs/implementation/phase-6-regression-matrix.md",
    "docs/implementation/phase-6-open-gaps.md",
    "docs/implementation/phase-6-checksum-audit.md",
    "docs/implementation/phase-6-qa-readiness.md",
    "docs/implementation/phase-6-owner-decision-register.md",
    "docs/implementation/phase-6-doc-path-validation.md",
    "docs/implementation/phase-6-workstream-c-env-chain.md",
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

