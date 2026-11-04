# Phase 9 Regression Matrix & Verification Register

**Document ID:** `PHASE-9-REGRESSION-MATRIX`  
**Companion Mirror:** [`docs/implementation/phase-9-regression-matrix.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-regression-matrix.md)  
**Date:** 2026-11-04  
**Target Commit:** `b12659b9795ba69499483a84750a33897dd7e08a` (`main`)  
**Toolchain Context:** Flutter FVM 3.44.6, Dart 3.12.2, Deno 2.9.4, PostgreSQL 16.9, Gradle 9.1.0  
**Overall Status:** **100% PASS (HERMETIC LOCAL SCOPE)** / **75/75 QA ROWS NOT RUN (DEC-03 HARD STOP)**

---

## 1. Status Vocabulary & Verification Rules

To maintain absolute evidentiary rigor, verification statuses are strictly defined:
- **`IMPLEMENTED`**: Source code, migrations, or tests exist on disk and compile cleanly.
- **`TESTED`**: Actively executed against an automated test runner with logged exit code and output.
- **`PASS (SCOPED)`**: 100% green against local/mock/ephemeral database harness. Does **not** imply hosted production execution.
- **`BLOCKED`**: Execution withheld due to an unmet prerequisite or owner authorization gate.
- **`NOT RUN`**: Test case defined with complete preconditions and steps, but intentionally not dispatched to physical or virtual hardware.
- **`STOPPED BY POLICY`**: Automated background mechanism (e.g. `pg_cron`) intentionally withheld by governance directive (e.g. DEC-05).

---

## 2. Master Automated Suites Executed

The following 10 automated verification suites establish the local hermetic baseline:

| Suite ID | Subsystem / Target | Harness / Command | Exit Code | Verified Output / Metrics | Status | Evidence Log Path |
|---|---|---|:---:|---|:---:|---|
| **S1** | Deno Edge Functions (Full Suite) | `deno test --allow-read supabase/functions/` | `0` | 15 test files, **150 passed / 0 failed** in 2.0s | **PASS (SCOPED)** | `.tools/ci-logs/deno-full-test.log` |
| **S2** | Targeted `family-admin` (SQL-05) | `deno test --allow-read supabase/functions/family-admin/` | `0` | 2 test files, **12 passed / 0 failed** in 142ms | **PASS (SCOPED)** | `.tools/ci-logs/deno-family-admin-test.log` |
| **S3** | Local CI Stage 3 (Deno) | `scripts/local-ci.ps1 -SkipFlutter -SkipGradle -SkipSql` | `0` | Stage 3 passed in 2.7s; working tree verified clean | **PASS (SCOPED)** | `.tools/ci-logs/ci-run-20261104-110917.log` |
| **S4** | PostgreSQL 33-File SQL Chain (Positive) | `supabase/tests/run_sql_chain.ps1 -Database p6chain_...` | `0` | 33 files, 621 log lines, **0 errors, 0 assertion failures** | **PASS (SCOPED)** | `.tools/chain_p6chain_20261104_095112.log` |
| **S5** | SQL-05 Negative Control (Lossy RPC) | `supabase/tests/run_sql_chain.ps1 -NegativeControl ...` | `3` | **Expected Red:** Caught failure at `76_zone_delete_atomic_rpc.sql:411` | **PASS (SCOPED)** | `.tools/chain_p6chain_neg_20261104_095527.log` |
| **S6** | Checksum Integrity Suite | SHA-256 verification of 69 delivered tree paths | `0` | 69/69 paths match byte-level digest `2bd6b310...` | **PASS (SCOPED)** | `docs/evidence/phase5/tree-digest-final.txt` |
| **S7** | Phase 5 Manifest Table Audit | PowerShell `Get-FileHash` against manifest §8 | `0` | 20/20 artifacts (logs, XMLs, digests) match exactly | **PASS (SCOPED)** | `docs/evidence/phase5/MANIFEST.md` |
| **S8** | Doc Path Ellipsis Validation | Scanned all markdown files for truncated links | `0` | 108 files scanned, 3 corrected in Phase 6, 105 verified safe | **PASS (SCOPED)** | `docs/implementation/phase-6-doc-path-validation.md` |
| **S9** | Android JVM Unit Tests | `./gradlew test` (Robolectric / JUnit 4) | `0` | 6 test classes, **39 tests passed / 0 failed** | **PASS (SCOPED)** | `reports/test-results/TEST-*.xml` |
| **S10** | Flutter Unit & Widget Tests | `flutter test` (Dart test runner) | `0` | **408 tests passed / 0 failed**; Dart analyze clean | **PASS (SCOPED)** | `docs/evidence/phase5/logs/p5-coord-flutter-run2.log` |

---

## 3. Detailed SQL Chain Execution & Negative Control Verification

### 3.1 Parameter Ordering & Windows Safety
On Windows PowerShell, executing `psql.exe` requires precise parameter sequencing. Passing flags after the database argument causes `psql` to interpret options as positional parameters.
The canonical runner `supabase/tests/run_sql_chain.ps1` strictly enforces:
```powershell
# Mandatory parameter shape: options precede database name
& psql -X -v ON_ERROR_STOP=1 -P pager=off -f $file -d $Database
```

### 3.2 SQL Chain Execution Log Evidence (Positive Control)
In `.tools/chain_p6chain_20261104_095112.log`, the 33-file sequence executed consecutively without error:
- Migration sequence: `20260101000000_core.sql` through `20261103000100_zone_delete_atomic_rpc.sql`.
- In-flight verification blocks:
  * `psql:.../60_remote_session_concurrency.sql:333: ALL CONCURRENCY TESTS PASSED`
  * `psql:.../61_parent_controlled_lifetime.sql:267: ALL PARENT-CONTROLLED LIFETIME TESTS PASSED`
  * `psql:.../62_signaling_consented_session.sql:250: ALL CONSENTED-SESSION SIGNALING TESTS PASSED`
  * `psql:.../63_abandoned_session_sweep.sql:282: ALL ABANDONED SESSION SWEEP TESTS PASSED`
  * `psql:.../70_phase1_authorization.sql:455: ALL PHASE 1 AUTHORIZATION TESTS PASSED`
  * `psql:.../71_phase1_rollback_privileges.sql:605: ALL PHASE 1 ROLLBACK PRIVILEGE TESTS PASSED`
  * `psql:.../74_sweep_indexes_and_repeatability.sql:934: ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED`
  * `psql:.../75_signaling_replay_index_duplicate_guard.sql:216: ALL SIGNALING REPLAY-INDEX DUPLICATE GUARD TESTS PASSED`
  * `psql:.../76_zone_delete_atomic_rpc.sql:773: ALL ZONE DELETE ATOMIC RPC TESTS PASSED`

### 3.3 Negative Control Proof (SQL-05 Non-Atomic RPC Rejection)
In `.tools/chain_p6chain_neg_20261104_095527.log`, fixture `supabase/tests/fixtures/sql05_lossy_negative.sql` was injected to replace `delete_safe_zone_audited` with a non-atomic procedure that deletes the safe zone but allows the audit failure to be ignored.
- **Exit Code:** `3` (Non-zero exit).
- **Assertion Failure Caught at Line 639:**
  ```text
  psql:supabase/tests/76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded
  ```
- **Architectural Proof:** Proves that our automated test harness actively detects loss of transactional atomicity and guarantees that safe zone deletion cannot occur without atomic audit trail generation.

---

## 4. Security Boundaries & Architectural Invariant Matrix

| Subsystem / Invariant | Requirement & Specification | Verification Mechanism | Local Status | Hosted Status |
|---|---|---|:---:|:---:|
| **RLS Isolation** | All 19 public tables enforce Row Level Security | PostgreSQL catalog query across all 19 tables | **PASS** | Gated (DEC-02) |
| **Service-Role Grants** | Zero public execute grants on private routines | Query on `pg_proc.proacl`; explicit `REVOKE ALL` | **PASS** | Gated (DEC-02) |
| **Append-Only Auditing** | `audit_logs` table blocks UPDATE and DELETE | Trigger `audit_logs_append_only_guard` raising `42501` | **PASS** | **PASS** |
| **Safe Zone Atomicity** | Atomic safe-zone delete + audit insert in 1 tx | `delete_safe_zone_audited` RPC + Test 76 negative control | **PASS** | Open (HOST-01) |
| **WebRTC Anti-Replay** | Unique sequence index `(session_id, sequence)` | Migration 2 DO block + Test 75 duplicate check | **PASS** | Pre-check Ready |
| **Parent Lifetime** | Consented sessions never expire via wall-clock | Migration `parent_controlled_session_lifetime` | **PASS** | Gated (DEC-02) |
| **Session Concurrency** | Max 1 active session per child device | Transaction advisory lock on `hashtext(device_id)` | **PASS** | Gated (DEC-02) |
| **3-State Retention** | Scope wire contract (`family`, `device`, `not_reported`) | `account/retention.ts` + 17 scope unit tests | **PASS** | Gated (DEC-02) |
| **Mic Privacy Indicator** | Android 12+ green dot indicator & notification | `FOREGROUND_SERVICE_TYPE_MICROPHONE` in Kotlin | **PASS (Code)** | Not Run (DEC-03) |
| **Immediate Stop** | Child can stop sharing instantly from notification/UI | `ACTION_STOP` handler in `AudioAssistanceService` | **PASS (Code)** | Not Run (DEC-03) |
| **Disconnect Watchdog** | Inactivity / parent termination drops service | 15s polling watchdog + 45s heartbeat timeout | **PASS (Code)** | Not Run (DEC-03) |

---

## 5. Android Controlled QA Matrix Holding Register (75 Rows)

In strict compliance with Owner Ruling #9 and DEC-03, zero physical or virtual Android tests were run. All 75 rows remain at status **`NOT RUN`**:

| Subsystem Group | Row Count | Target Device Profiles | Key Verification Invariants | Execution Status |
|---|:---:|---|---|:---:|
| **Subsystem 1: Enrollment & Pairing** | 12 | Pixel 9a AVD & Realme 7 | QR scanning, HMAC token exchange, credential storage | **NOT RUN** |
| **Subsystem 2: Policy Enforcement** | 14 | Realme 7 (`RMX2161`) | App suspension, time limits, safe-zone entry/exit | **NOT RUN** |
| **Subsystem 3: Audio Assistance (WebRTC)** | 18 | Pixel 9a AVD & Realme 7 | Explicit consent, green dot, notification, mic capture | **NOT RUN** |
| **Subsystem 4: Watchdogs & Teardown** | 16 | Realme 7 (`RMX2161`) | 15s watchdog, 45s heartbeat, permission revocation | **NOT RUN** |
| **Subsystem 5: Unlink & Data Hygiene** | 15 | Realme 7 (`RMX2161`) | Device unlink, credential wipe, telemetry retention | **NOT RUN** |
| **TOTAL** | **75** | **Both Devices** | **All 10 Android Privacy Invariants** | **100% NOT RUN** |

---

## 6. Summary Regression Verdict

1. **Local Offline Codebase:** **100% GREEN**. All 150 Deno tests, 33 SQL chain migrations, 39 JVM unit tests, 408 Flutter tests, and negative control assertions pass with zero failures.
2. **Physical & Hosted Environments:** **HELD AT HARD STOP**. Zero remote database mutations dispatched; zero Android QA rows executed. Release gate progression awaits explicit Owner Decisions DEC-01, DEC-02, DEC-03, and DEC-05.

