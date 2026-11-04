# PHASE 7 — Regression Matrix

**Project:** Android-first Parental Control Application  
**Repository:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Phase 5 Reference HEAD:** `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d`  
**Phase 6/7 HEAD:** `b12659b9795ba69499483a84750a33897dd7e08a`  
**Date:** 2026-11-04  
**Companion Documents:**
- [`docs/implementation/phase-7-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-report.md)
- [`docs/implementation/phase-7-owner-decision-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-owner-decision-log.md)
- [`docs/implementation/phase-7-android-qa-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-android-qa-report.md)
- [`docs/implementation/phase-7-deployment-log.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-deployment-log.md)
- [`docs/implementation/phase-7-open-gaps.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-open-gaps.md)

---

## 1. Status Vocabulary & Verification Integrity Rules

This matrix enforces the strict, non-vacuous status vocabulary established across Phases 1–6:

- **IMPLEMENTED**: Code or documentation change exists in the repository working tree / git history.
- **TESTED**: Explicit automated test suite or diagnostic harness executed and verified on this machine.
- **PASS (SCOPED)**: Automated suite passed with exit code 0; scope limitation explicitly stated (e.g., local PostgreSQL / fake PostgREST vs hosted production).
- **BLOCKED**: Progress halted by an explicit technical, architectural, or environmental prerequisite.
- **NOT RUN**: Required test or matrix row was deliberately **not executed** (e.g., physical device testing halted under Owner Decision Gate DEC-03 / Ruling #9). Never described as passing.
- **STOPPED**: Workstream halted by an explicit owner policy or ruling.
- **AWAITING OWNER**: Architectural decision, preflight query execution, or authorization strictly requires owner action.

---

## 2. Authoritative Automated Suites Executed & Audited in Phase 7

| # | Suite / Command (Exact) | Exit | Observed Result | Scope & Coverage | Evidence Artifact | Status |
|---|---|---:|---|---|---|---|
| **S1** | `deno test --allow-read supabase/functions/` (with `$env:DENO_DIR="C:\Users\ASUS\AppData\Local\deno"`) | 0 | `ok \| 150 passed \| 0 failed (5s)` | All Edge Function suites: `account/` (23), `_shared/` (49), `device-command/` (24), `family-admin/` (12), `remote-session/` (19), `handler_wiring_test.ts` (5), plus pre-existing | Live execution in session; hermetic offline execution | **PASS (SCOPED)** |
| **S2** | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed (222ms)` | Targeted SQL-05 safe zone atomic delete, authorization predicates, and handler wiring isolation | Live execution in session; 17/17 passed | **PASS (SCOPED)** |
| **S3** | **PostgreSQL 33-File SQL Regression Chain (CHAIN-01 Positive Run):** `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112` | 0 | `CHAIN p6chain_20261104_095112 EXIT=0 FILES=33 LINES=621 ASSERT_FAILED=0 ERRORS=0` | All 14 migrations, 2 local stubs, 17 test suites (incl. 70, 71, 72, 74, 75, 76) executed sequentially into disposable PG 16.9 database | `.tools/chain_p6chain_20261104_095112.log` | **PASS (SCOPED)** |
| **S4** | **Negative Control (SQL-05 Atomic RPC Audit Rollback):** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527` | 3 | `EXIT=3 ASSERT_FAILED=1 ERRORS=1` (`psql:.../76_zone_delete_atomic_rpc.sql:411: ERROR: ASSERTION FAILED`) | Deliberate injection of `supabase/tests/fixtures/sql05_lossy_negative.sql` before test 76. Verified test 76 catches non-atomic RPC | `.tools/chain_p6chain_neg_20261104_095527.log` | **PASS (SCOPED - Verified Red)** |
| **S5** | **Evidence & Checksum Integrity Suite (Workstream A):** Verification script against `docs/evidence/phase5/tree-digest-final.txt` | 0 | `69/69 paths verified match (0 mismatches, 0 missing)` | All 69 delivered Phase 5 paths hashed on disk; aggregate `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/implementation/phase-6-checksum-audit.md` | **PASS** |
| **S6** | **Evidence Manifest Table Audit:** Verification of all 20 artifacts in `docs/evidence/phase5/MANIFEST.md` §8 | 0 | `20/20 files match exact byte sizes and SHA-256 hashes` | 6 JUnit XMLs, 12 logs, 2 digest tables; self-referential exclusions (§8a) confirmed | `docs/implementation/phase-6-checksum-audit.md` §3 | **PASS** |
| **S7** | **Documentation Path Validation (GAP-EV-06):** Automated regex and existence scan of 108 ellipsis instances across markdown | 0 | `108 scanned: 3 invalid paths corrected, 105 verified safe/illustrative` | `README.md`, `_work/p4-enf-residual.md`, `phase-2-regression-matrix.md` corrected | `docs/implementation/phase-6-doc-path-validation.md` | **PASS** |
| **S8** | **Gradle Android JVM Tests (Historical Baseline Verification):** 6 test classes, 39 tests | 0 | XML results verified: 39 tests, 0 failures, 0 errors | `AudioAssistanceRecreationTest` (8), `SessionWatchdogTest` (7), `StartGateTest` (4), `StopIdempotenceTest` (3), `EnforcementModeTest` (4), `PolicyEvaluatorTest` (13) | `docs/evidence/phase5/gradle-junit/*.xml` | **PASS (SCOPED - Historical Baseline)** |
| **S9** | **Flutter / Dart Test Suites (Historical Baseline Verification):** Whole `lib/` and `test/` tree | 0 | Phase 5 baseline: 408 tests passed, 0 issues found | App restrictions, account privacy, retention scope disclosure (11 cases), export result dialog | `docs/evidence/phase5/logs/p5-coord-flutter-run2.log`, `p5-coord-dart-analyze-run2.log` | **PASS (SCOPED - Historical Baseline)** |
| **S10** | **Local CI Pipeline Runner (Stage 3 Live Execution):** `powershell -ExecutionPolicy Bypass -File scripts/local-ci.ps1 -SkipSql -SkipGradle -SkipFlutter` | 0 | `Stage 3: Deno Edge Function Tests PASSED (2.1s)` | Orchestrated execution of 150 Deno tests with individual log capture | `.tools/ci-logs/stage3-deno-test-20261104-101911.log` | **PASS (SCOPED)** |

---

## 3. SQL Chain Detailed Run Metrics (CHAIN-01)

### 3.1 Positive Run (Database `p6chain_20261104_095112`)
- **Cluster:** Local disposable PostgreSQL 16.9 (`.tools/pgsql16/pgsql/bin`), port 55584.
- **Command:** `.\supabase\tests\run_sql_chain.ps1 -Database p6chain_20261104_095112 -Port 55584`
- **Files executed:** 33 files (14 migrations + 2 stubs + 17 test scripts in documented sequence).
- **Exit code:** `0`
- **Assertion failures:** `0`
- **Errors:** `0`
- **Log lines:** `621`
- **Key assertions observed:**
  * `tests/74: ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED`
  * `tests/75: ALL SIGNALING REPLAY-INDEX DUPLICATE GUARD TESTS PASSED`
  * `tests/76: ALL ZONE DELETE ATOMIC RPC TESTS PASSED` (773 lines of atomic RPC validation)
  * `tests/71: ALL PHASE 1 ROLLBACK PRIVILEGE TESTS PASSED`

### 3.2 Negative Control Run (Database `p6chain_neg_20261104_095527`)
- **Command:** `.\supabase\tests\run_sql_chain.ps1 -NegativeControl -Database p6chain_neg_20261104_095527 -Port 55584`
- **Injected fixture:** `supabase/tests/fixtures/sql05_lossy_negative.sql` injected immediately before `tests/76_zone_delete_atomic_rpc.sql`.
- **Exit code:** `3`
- **Assertion failures:** `1`
- **Errors:** `1`
- **Failure point:** `supabase/tests/76_zone_delete_atomic_rpc.sql:411`
- **Error message:** `ERROR: ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded`
- **Significance:** Empirically proves that Test 76 is a sensitive, non-vacuous negative control that detects any break in atomic rollback behavior.

---

## 4. Controlled Android QA Preparation Matrix (GATE-B-01 / AND-01)

Per **Owner Decision Gate DEC-03** and **Phase 5 Owner Ruling #9**, physical device execution is **STRICTLY PROHIBITED / NOT AUTHORIZED** in Phase 7. Zero APKs were built, zero APKs installed, zero ADB commands run, and zero microphone captures initiated.

All 75 test rows are maintained in an execution-ready state, cataloged in [`docs/implementation/phase-7-android-qa-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-7-android-qa-report.md). Summary of status across all 75 rows:

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

### 4.1 Master 75-Row Test Specification

| ID | Domain | Test Scenario | Preconditions | Verification Steps | Expected Result | Status |
|---|---|---|---|---|---|---|
| `AUTH-01` | Auth | Email/password sign-in as Parent | Parent account exists in Supabase | Sign in on Parent device | Home dashboard displayed, JWT saved | **NOT RUN** |
| `AUTH-02` | Auth | Parent token refresh during active session | Parent signed in, token near expiry | Idle app for refresh interval | Access token refreshed via Supabase Auth without logout | **NOT RUN** |
| `AUTH-03` | Auth | Child sign-in attempt via Parent UI | Parent login screen displayed | Enter child credentials | Rejected or blocked; parent role enforced | **NOT RUN** |
| `AUTH-04` | Auth | Sign-out clears local parent tokens | Parent logged in | Tap sign out in settings | Tokens wiped from SecureStorage, routed to login | **NOT RUN** |
| `AUTH-05` | Auth | Invalid parent credentials | App at login screen | Submit bad password | Clear error message displayed, 0 tokens stored | **NOT RUN** |
| `AUTH-06` | Auth | Network loss during login | Offline state | Attempt login | Graceful network error message, no app crash | **NOT RUN** |
| `PAIR-01` | Pairing | 6-digit pairing code generation | Parent signed in | Tap "Add Child Device" | Generates 6-digit alphanumeric code with 15m TTL | **NOT RUN** |
| `PAIR-02` | Pairing | Child pairs using valid code | Child app at fresh onboarding | Enter 6-digit code | Device enrolled, paired device record created in DB | **NOT RUN** |
| `PAIR-03` | Pairing | Expired pairing code rejection | Code generated > 15m ago | Enter expired code on child | Pairing rejected with 410 / code expired error | **NOT RUN** |
| `PAIR-04` | Pairing | Concurrency race on single pairing code | Single code active | Submit from two child devices simultaneously | Exactly one device succeeds; second rejected with 409 | **NOT RUN** |
| `PAIR-05` | Pairing | Parent unlinks paired child device | Paired child active | Parent taps "Unlink Child" in family admin | Child status becomes unlinked; permissions revoked | **NOT RUN** |
| `PAIR-06` | Pairing | Unlinked child attempts to fetch policy | Child was unlinked | Child triggers policy sync | Sync rejected with 403 / unlinked status | **NOT RUN** |
| `PAIR-07` | Pairing | Re-pairing previously unlinked child | Child unlinked | Generate new code and pair child | New enrollment record created; old block cleared | **NOT RUN** |
| `PAIR-08` | Pairing | Re-link cleared approval token | Device revoked, re-approved | Trigger enrollment check | `enrollment_test.ts` scenario verified on device | **NOT RUN** |
| `PRES-01` | Presence | Heartbeat transmission from child | Child app in foreground | Inspect DB presence table | `last_seen_at` updated every 60s | **NOT RUN** |
| `PRES-02` | Presence | Heartbeat background transmission | Child app backgrounded | Monitor presence table for 15m | Periodic heartbeat sent via WorkManager | **NOT RUN** |
| `PRES-03` | Presence | Child offline detection | Disconnect network on child | Wait for heartbeat TTL (5m) | Parent UI displays child status as "Offline" | **NOT RUN** |
| `PRES-04` | Presence | Child reconnect recovers presence | Child reconnected to Wi-Fi | Wait 60s | Status immediately transitions to "Online" | **NOT RUN** |
| `PRES-05` | Presence | Battery & device stats reporting | Child battery changes | Trigger status update | Battery level and charging state accurately reported | **NOT RUN** |
| `PRES-06` | Presence | High-frequency heartbeat flood protection | Rapid sync triggers | Fire 10 syncs in 5s | Throttled gracefully; database load protected | **NOT RUN** |
| `CMD-01` | Command | Lock device command delivery | Child online | Parent sends "Lock Device" | Lock screen overlay activates immediately | **NOT RUN** |
| `CMD-02` | Command | Lock screen cannot be dismissed by child | Lock active | Tap Home, Back, Recents | System navigation intercepted or overlay restored | **NOT RUN** |
| `CMD-03` | Command | Unlock device command delivery | Lock active | Parent sends "Unlock Device" | Overlay dismissed; normal device usage restored | **NOT RUN** |
| `CMD-04` | Command | Remote wipe / app data clear | Child online | Parent sends wipe command | Local child database cleared; device reset | **NOT RUN** |
| `CMD-05` | Command | Command delivery over FCM high-priority | Child app in Doze mode | Parent sends lock command | FCM wakes device; command processed < 5s | **NOT RUN** |
| `CMD-06` | Command | Offline command queue delivery | Child offline | Parent sends lock command; child comes online | Lock command received and executed on reconnection | **NOT RUN** |
| `CMD-07` | Command | Stale command expiration | Child offline > 24h | Bring child online | Stale commands older than TTL discarded without execution | **NOT RUN** |
| `ENF-01` | Enforcement | Policy push updates app restrictions | Parent updates blocklist | Push policy version N+1 | Blocklist active on child; blocked app closes on launch | **NOT RUN** |
| `ENF-02` | Enforcement | Policy version mismatch detection | Child holds policy v1 | Edge function rejects old version | Enforcement logs mismatch; triggers policy fetch | **NOT RUN** |
| `ENF-03` | Enforcement | Un-correlated policy green-badge rejection | Policy without valid signature/token | Child evaluates policy | Rejected; falls back to strict default mode | **NOT RUN** |
| `ENF-04` | Enforcement | Usage limit exhaustion enforcement | 1h daily YouTube limit reached | Child uses YouTube for 60m | YouTube blocked with usage limit exceeded warning | **NOT RUN** |
| `ENF-05` | Enforcement | Bedtime schedule lockout | Bedtime scheduled for 21:00 | Clock reaches 21:00 | Device enters bedtime mode; non-emergency apps blocked | **NOT RUN** |
| `ENF-06` | Enforcement | Bedtime morning unlock | Bedtime ends at 07:00 | Clock reaches 07:00 | Device returns to daytime policy mode | **NOT RUN** |
| `ENF-07` | Enforcement | Offline policy persistence | Child rebooted while offline | Verify blocked apps | Enforcement remains active using local cache | **NOT RUN** |
| `ENF-08` | Enforcement | Shared `EnforcementMode.of()` equivalence | Android native service running | Compare Kotlin & Dart evaluation | Identical enforcement decision rendered | **NOT RUN** |
| `SESS-01` | Audio | Remote audio request triggers child prompt | Parent initiates audio | Check child device | Full-screen consent dialog displayed; 0 mic access | **NOT RUN** |
| `SESS-02` | Audio | Child consent grants mic access | Child taps "Accept" | WebRTC session establishes | Microphone FGS starts; green privacy indicator appears | **NOT RUN** |
| `SESS-03` | Audio | Child decline terminates session | Child taps "Decline" | Check audio stream | Session marked declined; zero audio captured | **NOT RUN** |
| `SESS-04` | Audio | Mic FGS notification shows persistent indicator | Audio active | Pull down Android notification shade | Persistent Foreground Service notification displayed | **NOT RUN** |
| `SESS-05` | Audio | Parent stops audio session | Audio active | Parent taps "End Session" | WebRTC peer closed; child Mic FGS terminated < 2s | **NOT RUN** |
| `SESS-06` | Audio | Child stops audio session | Audio active | Child taps "Stop Audio" in notification | Session ends immediately; parent notified | **NOT RUN** |
| `SESS-07` | Audio | Parent background watchdog audio termination | Audio active, parent backgrounded | Parent remains backgrounded > 15s | Watchdog triggers session teardown; mic released | **NOT RUN** |
| `SESS-08` | Audio | Abandoned session sweep cleanup | Session pending consent > 30s | Cron / sweep RPC runs | Session marked abandoned; prompt dismissed on child | **NOT RUN** |
| `SESS-09` | Audio | Mic hardware release verification | Session terminated | Inspect Android AudioRecord state | AudioRecord released completely; no OS mic lock | **NOT RUN** |
| `NET-01` | Network | WebRTC connection over Wi-Fi LAN | Both devices on same Wi-Fi | Establish audio session | Direct p2p host candidate connected | **NOT RUN** |
| `NET-02` | Network | WebRTC connection across separate mobile networks | Parent on 4G, Child on 5G | Establish audio session | TURN relay candidate connected cleanly | **NOT RUN** |
| `NET-03` | Network | Temporary Wi-Fi drop reconnect (ICE restart) | Audio active | Toggle child Wi-Fi off and on | ICE restarts and reconnects audio within 5s | **NOT RUN** |
| `NET-04` | Network | Prolonged network loss session termination | Audio active | Put child in Airplane Mode for 30s | Session terminates cleanly; mic released | **NOT RUN** |
| `NET-05` | Network | Signaling replay attack protection | Capture signaling packet | Replay packet with identical sequence | Replay rejected by unique sequence constraint | **NOT RUN** |
| `NET-06` | Network | High-packet-loss audio degradation | Degrade network (30% loss) | Verify audio | Audio degrades gracefully; app remains stable | **NOT RUN** |
| `NET-07` | Network | Premature 30-minute expiry on accepted sessions | Consented session active | Run for 35 minutes | Session remains active without premature 30m cutoff | **NOT RUN** |
| `PERM-01` | Permissions | Child revokes `RECORD_AUDIO` permission | Audio active | Revoke mic permission in Android Settings | App detects revocation; terminates session gracefully | **NOT RUN** |
| `PERM-02` | Permissions | Child revokes Usage Stats permission | Normal monitoring | Revoke Usage Access | Persistent notification displayed requesting re-grant | **NOT RUN** |
| `PERM-03` | Permissions | Child revokes Device Admin | Device Admin active | Attempt deactivate | Intercepted or alerts parent immediately | **NOT RUN** |
| `PERM-04` | Permissions | Notification permission gating | Child on Android 13+ | Revoke `POST_NOTIFICATIONS` | Foreground service enforces foreground indicator rules | **NOT RUN** |
| `PERM-05` | Permissions | Location permission revocation | Geofencing active | Revoke `ACCESS_FINE_LOCATION` | Safe zone monitoring pauses; parent notified | **NOT RUN** |
| `PERM-06` | Permissions | Battery optimization exemption check | Device in Doze | Trigger policy sync | WorkManager wakes app on schedule | **NOT RUN** |
| `PERM-07` | Permissions | Full permission restoration flow | Permissions missing | Parent initiates permission audit | Step-by-step setup guide shown on child | **NOT RUN** |
| `ZONE-01` | Safe Zones | Safe zone creation by parent | Parent on map UI | Create 500m home zone | Zone saved to DB with coordinates and radius | **NOT RUN** |
| `ZONE-02` | Safe Zones | Child entry event detection | Child outside zone | Mock location inside zone | `zone_entered` event logged and parent notified | **NOT RUN** |
| `ZONE-03` | Safe Zones | Child exit event detection | Child inside zone | Mock location outside zone | `zone_exited` event logged and parent notified | **NOT RUN** |
| `ZONE-04` | Safe Zones | Atomic safe zone deletion by parent | Parent on zones list | Delete safe zone | Atomic RPC deletes zone + logs audit row in single TX | **NOT RUN** |
| `ZONE-05` | Safe Zones | Non-parent safe zone deletion rejection | Malicious child caller | Call `delete_safe_zone_audited` directly | Rejected with 42501 `not_family_parent` | **NOT RUN** |
| `ZONE-06` | Safe Zones | Direct client DELETE on safe_zones blocked | Authenticated parent client | Execute direct SQL `DELETE FROM safe_zones` | Blocked by lack of DELETE privilege | **NOT RUN** |
| `ZONE-07` | Safe Zones | Multi-zone overlap handling | Two overlapping zones | Move child into intersection | Both zone memberships accurately maintained | **NOT RUN** |
| `ZONE-08` | Safe Zones | GPS jitter filter test | Child at zone boundary | Jitter location +/- 10m rapidly | Hysteresis prevents rapid enter/exit flapping | **NOT RUN** |
| `LIFE-01` | Lifecycle | Child app cold start performance | App closed | Launch app | Cold start < 1.5s; background service active | **NOT RUN** |
| `LIFE-02` | Lifecycle | Android boot completion auto-restart | Device rebooted | System sends `BOOT_COMPLETED` | GuardianService starts automatically in background | **NOT RUN** |
| `LIFE-03` | Lifecycle | Low-memory OS kill recovery | OS under heavy RAM load | Android kills background process | Process restarts via sticky service / WorkManager | **NOT RUN** |
| `LIFE-04` | Lifecycle | Realme ColorOS task-kill (Recents swipe) | App on Realme device | Child swipes away app in Recents | Auto-restart triggered via manufacturer whitelist/alarm | **NOT RUN** |
| `LIFE-05` | Lifecycle | OS force-stop termination handling | Child enters Settings | Child taps "Force Stop" | Watchdog / Device Admin alerts parent of tampering | **NOT RUN** |
| `LIFE-06` | Lifecycle | App update migration | v1.0.0 installed | Install v1.1.0 update APK | Local SQLite schema migrates without data loss | **NOT RUN** |
| `LIFE-07` | Lifecycle | Doze mode deep maintenance window | Device motionless on table | Device enters Deep Doze | Batch sync executes during maintenance window | **NOT RUN** |
| `LIFE-08` | Lifecycle | Multiple child profiles on single parent | Single parent account | Switch between 3 children | UI displays correct metrics and policies per child | **NOT RUN** |
| `LIFE-09` | Lifecycle | Offline data synchronization on reconnect | Child offline for 12 hours | Reconnect to internet | All queued usage and location events uploaded | **NOT RUN** |

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

