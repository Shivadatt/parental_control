# PHASE 6 — Regression Matrix

**Project:** Android-first Parental Control Application  
**Repository:** `D:\parentcontrol_app`  
**Branch:** `main`  
**HEAD at Phase 6 Entry:** `b12659b9795ba69499483a84750a33897dd7e08a`  
**Date:** 2026-11-04  
**Companion to:** `docs/implementation/phase-6-report.md`  

---

## 1. Status Vocabulary & Verification Integrity Rules

This matrix uses the rigorous, non-vacuous status vocabulary mandated across Phases 1–6:

- **IMPLEMENTED**: Code or documentation change exists in the repository working tree / git history.
- **TESTED**: Explicit automated test suite or diagnostic harness executed and verified on this machine.
- **PASS (SCOPED)**: Automated suite passed with exit code 0; scope limitation explicitly stated (e.g. local fake PostgREST vs hosted production).
- **BLOCKED**: Progress halted by an explicit technical, architectural, or environmental prerequisite.
- **NOT RUN**: Required test or matrix row was deliberately **not executed** (e.g., physical device testing halted under owner ruling #9). Never described as passing.
- **STOPPED**: Workstream halted by an explicit owner policy or ruling.
- **AWAITING OWNER**: Architectural decision, preflight query execution, or authorization strictly requires owner action.

---

## 2. Authoritative Automated Suites Executed in Phase 6

| # | Suite / Command (Exact) | Exit | Observed Result | Scope & Coverage | Evidence Artifact | Status |
|---|---|---:|---|---|---|---|
| **S1** | `deno test --allow-read supabase/functions/` (with `$env:DENO_DIR`) | 0 | `ok \| 150 passed \| 0 failed (5s)` | All Edge Function suites: `account/` (23), `_shared/` (49), `device-command/` (24), `family-admin/` (12), `remote-session/` (19), `handler_wiring_test.ts` (5), plus pre-existing | Captured live; reproducible offline via fake PostgREST | **PASS (SCOPED)** |
| **S2** | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed (277ms)` | Targeted SQL-05 safe zone atomic delete, authorization predicates, and handler wiring isolation | Captured live; 17/17 passed | **PASS (SCOPED)** |
| **S3** | **PostgreSQL 33-File SQL Regression Chain (CHAIN-01 Positive Run):** `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112` | 0 | `CHAIN p6chain_20261104_095112 EXIT=0 FILES=33 LINES=621 ASSERT_FAILED=0 ERRORS=0` | All 14 migrations, 2 local stubs, 17 test suites (incl. 70, 71, 72, 74, 75, 76) executed sequentially into disposable PG 16.9 database | `.tools/chain_p6chain_20261104_095112.log` | **PASS (SCOPED)** |
| **S4** | **Negative Control (SQL-05 Atomic RPC Audit Rollback):** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527` | 3 | `EXIT=3 ASSERT_FAILED=1 ERRORS=1` (`psql:.../76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED`) | Deliberate injection of `supabase/tests/fixtures/sql05_lossy_negative.sql` before test 76. Verified test 76 catches non-atomic RPC | `.tools/chain_p6chain_neg_20261104_095527.log` | **PASS (SCOPED - Verified Red)** |
| **S5** | **Evidence & Checksum Integrity Suite (Workstream A):** Verification script against `docs/evidence/phase5/tree-digest-final.txt` | 0 | `69/69 paths verified match (0 mismatches, 0 missing)` | All 69 delivered Phase 5 paths hashed on disk; aggregate `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/implementation/phase-6-checksum-audit.md` | **PASS** |
| **S6** | **Evidence Manifest Table Audit:** Verification of all 20 artifacts in `docs/evidence/phase5/MANIFEST.md` §8 | 0 | `20/20 files match exact byte sizes and SHA-256 hashes` | 6 JUnit XMLs, 12 logs, 2 digest tables; self-referential exclusions (§8a) confirmed | `docs/implementation/phase-6-checksum-audit.md` §3 | **PASS** |
| **S7** | **Documentation Path Validation (GAP-EV-06):** Automated regex and existence scan of 108 ellipsis instances across markdown | 0 | `108 scanned: 3 invalid paths corrected, 105 verified safe/illustrative` | `README.md`, `_work/p4-enf-residual.md`, `phase-2-regression-matrix.md` corrected | `docs/implementation/phase-6-doc-path-validation.md` | **PASS** |
| **S8** | **Gradle Android JVM Tests (Historical Baseline Verification):** 6 test classes, 39 tests | 0 | XML results verified: 39 tests, 0 failures, 0 errors | `AudioAssistanceRecreationTest` (8), `SessionWatchdogTest` (7), `StartGateTest` (4), `StopIdempotenceTest` (3), `EnforcementModeTest` (4), `PolicyEvaluatorTest` (13) | `docs/evidence/phase5/gradle-junit/*.xml` | **PASS (SCOPED - Historical Baseline)** |
| **S9** | **Flutter / Dart Test Suites (Historical Baseline Verification):** Whole `lib/` and `test/` tree | 0 | Phase 5 baseline: 408 tests passed, 0 issues found | App restrictions, account privacy, retention scope disclosure (11 cases), export result dialog | `docs/evidence/phase5/logs/p5-coord-flutter-run2.log`, `p5-coord-dart-analyze-run2.log` | **PASS (SCOPED - Historical Baseline)** |

---

## 3. SQL Chain Detailed Run Metrics (CHAIN-01)

### 3.1 Positive Run (Database `p6chain_20261104_095112`)
- **Cluster:** Local disposable PostgreSQL 16.9 (`.tools/pgsql16/pgsql/bin`), port 55584.
- **Command:** `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112 -PgPort 55584`
- **Files executed:** 33 files (14 migrations + 2 stubs + 17 test scripts in documented sequence).
- **Exit code:** `0`
- **Assertion failures:** `0`
- **Errors:** `0`
- **Log lines:** `621`
- **Key assertions observed:**
  * `tests/74: ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED`
  * `tests/75: UNIQUE REPLAY INDEX CREATED CLEANLY` (positive path)
  * `tests/76: ALL ZONE DELETE ATOMIC RPC TESTS PASSED` (773 lines of atomic RPC validation)
  * `tests/71: PHASE 1 ROLLBACK PRIVILEGES TESTS PASSED`

### 3.2 Negative Control Run (Database `p6chain_neg_20261104_095527`)
- **Command:** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527 -PgPort 55584`
- **Injected fixture:** `supabase/tests/fixtures/sql05_lossy_negative.sql` injected immediately before `tests/76_zone_delete_atomic_rpc.sql`.
- **Exit code:** `3`
- **Assertion failures:** `1`
- **Errors:** `1`
- **Failure point:** `supabase/tests/76_zone_delete_atomic_rpc.sql:411`
- **Error message:** `ERROR: ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded`
- **Significance:** Empirically demonstrates that Test 76 is a sensitive, non-vacuous negative control that detects any break in atomic rollback behavior.

---

## 4. Controlled Android QA Preparation Matrix (GATE-B-01 / AND-01)

Per **Phase 5 Owner Ruling #9**, physical device execution remained strictly prohibited in Phase 6. No APK was built, no APK installed, no ADB commands run, and no microphone capture initiated. 

The full 75-row specification is cataloged in [`docs/implementation/phase-6-qa-readiness.md`](file:///d:/parentcontrol_app/docs/implementation/phase-6-qa-readiness.md). Summary of status across all 75 rows:

| Domain | Row Range | Total Rows | Risk Distribution | Actual Result | Status |
|---|---|---:|---|---|---|
| **§A: Authentication & Family Association** | `AUTH-01` to `AUTH-06` | 6 | 4 P1, 2 P2 | `NOT RUN` | **NOT RUN** |
| **§B: Pairing & Device Unlinking** | `PAIR-01` to `PAIR-08` | 8 | 2 P0, 2 P1, 4 P2 | `NOT RUN` | **NOT RUN** |
| **§C: Device Presence & Sync Health** | `PRES-01` to `PRES-06` | 6 | 3 P1, 2 P2, 1 P3 | `NOT RUN` | **NOT RUN** |
| **§D: Device Commands & Policy Enforcement** | `CMD-01`..`07`, `ENF-01`..`08` | 15 | 3 P0, 10 P1, 2 P2 | `NOT RUN` | **NOT RUN** |
| **§E: Remote Audio Consent & Microphone FGS** | `SESS-01` to `SESS-09` | 9 | 5 P0, 4 P1 | `NOT RUN` | **NOT RUN** |
| **§F: Network Outages, Reconnect & TURN Relay** | `NET-01` to `NET-07` | 7 | 1 P0, 3 P1, 3 P2 | `NOT RUN` | **NOT RUN** |
| **§G: Permission Revocation & Child User Stop** | `PERM-01` to `PERM-07` | 7 | 4 P0, 3 P1 | `NOT RUN` | **NOT RUN** |
| **§H: Safe Zones & Audited Deletion** | `ZONE-01` to `ZONE-08` | 8 | 4 P1, 4 P2 | `NOT RUN` | **NOT RUN** |
| **§I: Backgrounding, Task Kill & Reboot** | `LIFE-01` to `LIFE-09` | 9 | 2 P0, 6 P1, 1 P2 | `NOT RUN` | **NOT RUN** |
| **TOTAL** | — | **75** | **17 P0, 39 P1, 18 P2, 1 P3** | **75 NOT RUN** | **100% NOT RUN** |

### Priority High-Risk Rows Staged for Execution:
1. `ENF-02` / `ENF-03`: Policy version mismatch and un-correlated policy green-badge rejection (**P0**).
2. `NET-07`: Premature 30-minute expiry on accepted sessions (Defect F1) (**P0**).
3. `LIFE-04` / `LIFE-05`: Realme ColorOS task-kill (Recents swipe) and OS force-stop termination (**P0**).
4. `SESS-07`: Parent background watchdog audio termination within 15 seconds (**P0**).
5. `SESS-01`–`SESS-03`: Zero microphone access prior to explicit child consent (**P0**).
6. `PERM-01` / `PERM-04`: Instant capture teardown on `RECORD_AUDIO` revocation and notification permission gating (**P0**).

---

## 5. Hosted Deployment Readiness Matrix (HOST-01)

| Asset Name | Asset Type | Status on Hosted (`hhqgreaoqulmfwfwarhc`) | Pre-requisites Verified | Blocking Issues |
|---|---|---|---|---|
| `20261030000100_abandoned_session_sweep.sql` | Migration 1 | **NOT APPLIED** | Backlog query drafted | Awaiting Owner authorization (DEC-02) |
| `20261030000200_phase1_authorization.sql` | Migration 2 | **NOT APPLIED** | Duplicate pre-check query drafted | Requires duplicate check count = 0 (DEC-04) |
| `20261030000300_retention_sweep.sql` | Migration 3 | **NOT APPLIED** | Batch shape proven locally | Unbounded execution risk accepted (DEC-02) |
| `20261103000100_zone_delete_atomic_rpc.sql` | Migration 4 | **NOT APPLIED** | Depends on Migration 2 helper | Must follow Migration 2 (DEC-02) |
| `family-admin` | Edge Function | **PRE-PHASE-1 CODE LIVE** | Unit tests 13/13 pass | Must deploy AFTER Migration 4 (DEC-02) |
| `account` | Edge Function | **ABSENT (0 DEPLOYMENTS)** | Unit tests 23/23 pass | Independent deployment ready (DEC-02) |
| `device-command` | Edge Function | **PRE-PHASE-5 CODE LIVE** | Unit tests 24/24 pass | Independent deployment ready (DEC-02) |

---

## 6. Summary of Regression Matrix Verification

- **Code Quality & Units:** 150 Deno tests passed, 17 targeted SQL-05 Deno tests passed.
- **Database Architecture:** 33-file PostgreSQL 16 regression chain passed with 0 errors and 0 assertion failures. Negative control verified red at line 411.
- **Evidence Integrity:** 69/69 tree digest paths match, 20/20 evidence pack files match.
- **Controlled QA:** 75-row matrix completely structured, prioritized, and held at `NOT RUN`.
- **Safety Posture:** Zero unauthorized production mutations; zero unauthorized device interactions.

