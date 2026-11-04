# PHASE 6 — Open Gaps Register

**Project:** Android-first Parental Control Application  
**Repository:** `D:\parentcontrol_app`  
**Branch:** `main`  
**HEAD at Phase 6 Entry:** `b12659b9795ba69499483a84750a33897dd7e08a`  
**Date:** 2026-11-04  
**Companion to:** `docs/implementation/phase-6-report.md`  

---

## 1. Severity Definitions

This register adheres to the project's established severity standards:

| Severity | Operational Meaning |
|---|---|
| **P0** | Critical defect affecting live production users or corrupting live user data **now**. |
| **P1** | Release Blocker / Controlled QA Blocker. Controlled validation or production rollout cannot proceed without resolving or authorizing. |
| **P2** | Scoped Correctness, Governance, or Performance Risk. Real technical limitation with documented safe workarounds; requires owner decision before production scale. |
| **P3** | Housekeeping, Documentation Hygiene, Maintenance, or CI Optimization. |

> [!NOTE]
> There are currently **0 P0 gaps**. This holds strictly because **no Phase 1–5 migration or Edge Function has been deployed to the live hosted environment**. The moment production deployment begins, these items must be re-evaluated against the live system.

---

## 2. Open Gaps Register

| ID | Sev | Gap Title & Description | Status at Phase 6 Close | Closing Authority | Evidence / Pointer |
|---|---|---|---|---|---|
| **HOST-01** | **P1** | **Hosted Migration & Function Deployment Gap**: The Phase 1–5 database migrations (`20261030000100`, `20261030000200`, `20261030000300`, `20261103000100`) and Edge Functions (`account`, `family-admin`, `device-command`) remain undeployed to hosted Supabase (`hhqgreaoqulmfwfwarhc`). Client-side delete vulnerability on `safe_zones` is live on production today. | **OPEN — BLOCKER**. Explicitly NOT applied per project safety policy. | Owner (via Dashboard SQL Editor) following 8-gate sequence. | `docs/implementation/phase-5-deployment-readiness.md`, `phase-6-qa-readiness.md`, `scripts/local-ci.ps1` |
| **GATE-B-01 / AND-01** | **P1** | **Physical QA Device Execution Gap**: 0 of 75 rows in the Android Controlled QA matrix have been run on real hardware or emulators. All 10 privacy invariants (silent mic capture, permission revocation, notification visibility, watchdog kill) are unverified on device. | **STOPPED by Owner Ruling #9**. Matrix 100% prepared; 75/75 rows held at `NOT RUN`. | Owner explicit authorization to execute Gate B on paired hardware. | `docs/implementation/phase-6-qa-readiness.md` (full 75-row matrix); `phase-4-android-validation-plan.md` |
| **CONF-01 / DUR-01** | **P2** | **Evidence Durability & Gitignore Hazard**: Conflicting rulings #10 (no commit) and #12 (commit evidence) were de facto resolved by commit `b12659b` on `main`. However, line 22 of `.gitignore` (`*.log`) silently excluded 11 Phase 5 execution logs from git tracking; only `logs/p5-coord-deno-full3.txt` was tracked. | **PARTIALLY RESOLVED / OPEN (P2)**. 11 logs exist on workstation disk only. | Owner approval of DEC-01 (`git add -f docs/evidence/phase5/logs/*.log`). | `docs/implementation/phase-6-owner-decision-register.md` (DEC-01); `.gitignore:22` |
| **SQL-06h** | **P2** | **Hosted Signaling Replay Index Existence Unknown**: Unique index `webrtc_signals_session_sequence_uniq` creation in migration 2 is conditional on 0 duplicate sequence groups. Duplicate count on hosted production is unmeasured. | **OPEN**. Read-only pre-apply verification query formulated. | Owner executes Query 1 in Dashboard SQL Editor prior to Migration 2. | `docs/implementation/deployment/manifest.md` §2; `phase-6-qa-readiness.md` |
| **PERF-01h** | **P2** | **Hosted Retention Sweep Performance Evidence Absent**: Batch delete shape (`id = ANY (ARRAY(SELECT id ... LIMIT 10000))`) proven locally to eliminate table scans, but no `EXPLAIN (ANALYZE, BUFFERS)` exists from hosted production. | **SCOPED PASS (Local) / OPEN (Hosted)**. Behavioral equivalence proven in test 74 §5. | Owner runs read-only `EXPLAIN` query plan on hosted database post-apply. | `supabase/tests/74_sweep_indexes_and_repeatability.sql`; `_work/p4-perf01.md` |
| **SQL-04r** | **P2** | **Unbounded Retention Transaction (Owner Ruling #3)**: Bounded multi-transaction execution across calls was explicitly refused. `run_retention_sweep()` executes as a single transaction across the entire backlog; high backlogs risk statement timeouts. | **STOPPED by Owner Ruling #3**. Disclosed honestly in migration header. | Owner accepts single-transaction limitation or authorizes procedure rewrite. | `supabase/migrations/20261030000300_retention_sweep.sql:80-96` |
| **SCHED-01** | **P2** | **Background Scheduler Deployment Unverified**: Edge Function `cron/index.ts` is fully wired for session and retention sweeps, but no automated cron trigger (pg_cron or HTTP schedule) is deployed or active on hosted. | **STOPPED**. Implementation complete with missing-function fallback; scheduling withheld. | Owner installs scheduler post-migration application (DEC-05). | `supabase/functions/cron/index.ts:84-112`; `phase-5-deployment-readiness.md` §4 |
| **GAP-RS-01** | **P2** | **Quarantined Safe Zone Fallback Module Retained**: With `family-admin` switched to the atomic RPC `delete_safe_zone_audited`, fallback module `delete_zone_atomicity.ts` (and its 8 tests) is unreachable in production. | **KNOWN RESIDUAL (Disclosed)**. Kept intentionally as reviewed rollback fallback. | Owner authorizes retiring module once hosted RPC is verified live (DEC-07). | `supabase/functions/family-admin/index.ts:221-262`; `delete_zone_atomicity.ts` |
| **GAP-EV-05** | **P2** | **Phase 4 Timestamp Inconsistency**: Delivered tree digest for Phase 4 was computed 1–2 minutes before the final write of two of its own reports. | **HISTORICAL ANOMALY (Documented)**. Reconciled in Phase 5; Phase 6 preserves historical reports without rewriting. | Owner formally ratifies correction note (DEC-11). | `docs/implementation/phase-5-report.md` §1a; `phase-6-checksum-audit.md` |
| **GAP-DEP-01** | **P3** | **Unused `ZoneSnapshot` Type Import**: `family-admin/index.ts:21` imports type `ZoneSnapshot` from the unwired fallback module; line 195 casts `existing.data as ZoneSnapshot`, but only accesses `family_id`. | **OPEN (Cosmetic)**. 100% safe to replace with `{ family_id: string }`; 13/13 Deno tests green. | Ready for Owner approval at Gate A (DEC-07). | `supabase/functions/family-admin/index.ts:21,195`; Subagent 4 report |
| **GAP-ENV-01** | **P3** | **Retained PostgreSQL Clusters in `.tools/`**: Active PostgreSQL daemons running on ports 55581 and 55571; 8 cluster directories occupy ~1.03 GB disk space. | **DISCLOSED / SAFE**. Non-disposable databases preserved. Shutdown and reclamation procedure prepared. | Owner authorizes fast shutdown and deletion of obsolete data dirs (DEC-09). | `docs/implementation/phase-6-workstream-c-env-chain.md` |
| **GAP-EOL-01** | **P3** | **Repository Line-Ending Policy Discrepancy**: 7 files in the delivered tree (`api-contract.md` and 6 JUnit XMLs) have CRLF on disk and LF in git index (`i/lf w/crlf`). No `.gitattributes` exists. | **DISCLOSED / ANALYZED**. Dual aggregate calculated; ready-to-commit `.gitattributes` drafted. | Owner approves adding `.gitattributes` (DEC-08). | `docs/implementation/phase-6-checksum-audit.md` §2; `phase-6-doc-path-validation.md` §2 |
| **IDX-01** | **P3** | **Redundant Signaling B-Tree Index**: Non-unique index `webrtc_signals_session_sequence_idx` coexists with unique index `webrtc_signals_session_sequence_uniq`. | **AWAITING OWNER DECISION**. Additive coexistence harmless; minor write amplification. | Owner approves dropping redundant index in future maintenance window (DEC-06). | `supabase/migrations/20261030000200_phase1_authorization.sql:497-499` |
| **HOST-02** | **P3** | **Hosted State Observation Staleness**: Last direct hosted catalog observation was made on 2026-10-30. | **OPEN (Staleness)**. Read-only preflight checklist prepared to re-baseline hosted state. | Owner executes 5 read-only preflight queries in Dashboard. | `docs/implementation/phase-5-deployment-readiness.md` §2.0; Subagent 8 report |

---

## 3. Gaps Closed in Phase 6

| Gap ID | Previous Severity | Closed By | Verification Evidence |
|---|---|---|---|
| **GAP-EV-06** | **P3** | **Subagent 3**: Audited 108 ellipsis occurrences across documentation. Corrected 3 non-executable / truncated paths in `README.md`, `_work/p4-enf-residual.md`, and `phase-2-regression-matrix.md`. Classified remainder as valid illustrative examples. | `docs/implementation/phase-6-doc-path-validation.md`; live git show and psql verification |
| **CHAIN-01** | **P3** | **Subagent 5**: Diagnosed non-idempotence root cause (hardcoded `auth.users` UUID fixtures). Implemented production-grade runner scripts `supabase/tests/run_sql_chain.ps1` and `run_sql_chain.sh` with automated disposable DB lifecycle and negative control injection. | `supabase/tests/run_sql_chain.ps1`; verified green run (exit 0) and negative control (exit 3) |
| **CI-01** | **P3** | **Subagent 8**: Delivered local multi-stage CI pipeline `scripts/local-ci.ps1` and `.tools/local_ci.sh` orchestrating Dart analyze, Flutter test, Deno test, Gradle test, and the 33-file SQL regression chain without hosted external dependencies. | `scripts/local-ci.ps1`; `.tools/local_ci.sh` |
| **CONF-01** | **P2** | **Subagent 2**: Reconciled conflict between Ruling #10 and #12 against git commit `b12659b` on `main`, which committed all 73 Gate A files. Formulated formal owner ratification register (DEC-01). | `docs/implementation/phase-6-owner-decision-register.md` |

---

## 4. Gaps Closed in Earlier Phases and Still Closed

| Gap / Objective | Closed In | Verification in Phase 6 |
|---|---|---|
| **TEST-01** (Untested device command handler) | Phase 5 | `supabase/functions/device-command/handler_test.ts` (24 passed); handler dependency injection intact. |
| **KOT-02** (Duplicated Kotlin enforcement logic) | Phase 5 | `EnforcementMode.kt` shared enum; 4 JVM unit tests pass in `EnforcementModeTest`. |
| **SQL-05** (Safe zone delete/audit 2-transaction window) | Phase 5 | Atomic RPC `delete_safe_zone_audited` in migration `20261103000100`; test 76 (773 lines) passes; negative control catches non-atomic RPC. |
| **PERF-01a** (Retention sweep batch delete shape) | Phase 5 | Shipped shape `id = ANY (ARRAY(SELECT id ... LIMIT 10000))` verified in test 74 §5. |
| **PRIV-01 / WORD-02** (Retention scope disclosure) | Phase 5 | 17 Deno tests in `scope_test.ts` + 11 Flutter widget tests verify 3-state disclosure. |
| **GOV-02** (Abandoned session sweeper ratification) | Phase 5 | `expire_abandoned_sessions` RPC and index contract verified in test 63. |
| **SQL-01 / R3** (Quarantined de-hardening rollback) | Phase 5 | R3 de-hardening permanently refused under Owner Ruling #6; safeguards preserved. |

