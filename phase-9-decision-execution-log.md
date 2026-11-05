# PHASE 9 — Decision Execution Log & Owner Governance Reconciliation Audit

> _Dated reconciliation (2026-11-04 governance-consistency pass; measured 16:32 +0530): the HEAD, index and tree figures in this document - including the `Current HEAD` and `Working Tree Status` header lines - belong to their own execution windows and are preserved verbatim as history. Current measured state: HEAD `65b39485a10b51e9a3e26f6b7f09f057b904b126` on `main` (= `origin/main`); 0 staged, 0 unstaged, 0 untracked non-ignored, 32 ignored. Chronology: `b12659b` (entry) → `75d1a52` (owner's external commit 12:23:31 +0530) → `65b3948` (owner's external commit 15:18:45 +0530, pushed). No documentation pass committed or pushed; the owner committed externally. An empty index is not a clean working tree. Authority and digests: `docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md`._

**Project:** Android-first Parental Control Application  
**Repository:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Execution-window HEAD (historical snapshot — not the repository tip):** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`) _[Label corrected by the 2026-11-05 R9 pass; the value was this document's HEAD at authoring time. Current tip requires a fresh measurement — see `docs/evidence/phase9/FINAL-RESIDUAL-CORRECTION-ADDENDUM-R9.md`.]_  
**Working Tree Status:** 53 staged files in index at the 2026-11-04 12:00 +05:30 pre-edit baseline (23 baseline + 14 Phase 8 + 16 Phase 9) with 0 unstaged modifications - a tree holding 53 staged files is not a clean working tree. **Correction pass (2026-11-04): HEAD `75d1a5232acbd87fe1068b5000d2916892e8143d` on `main`, 0 staged, 15 unstaged modifications, 1 untracked non-ignored file (the new docs/evidence/phase9/DOCUMENTATION-CORRECTION-ADDENDUM.md).** The owner's external commit at 12:23:31 +05:30 converted those 53 staged files into committed history. No `git add`, staging or commit was performed by either documentation pass; all edits remain unstaged.  
**Date:** 2026-11-04  
**Author / Role:** Phase 9 documentation pass - owner decision reconciliation
**Recorded by:** the project owner's written instruction dated 2026-11-04, recorded by the Phase 9 documentation pass
**Companion Documents:**
- [`docs/implementation/phase-9-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-report.md)
- [`docs/implementation/phase-9-regression-matrix.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-regression-matrix.md)
- [`docs/implementation/phase-9-open-gaps.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-open-gaps.md)
- [`docs/implementation/phase-9-owner-decision-register.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md)
- [`docs/implementation/phase-9-release-readiness.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-release-readiness.md)
- [`docs/implementation/phase-9-git-integrity-report.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-git-integrity-report.md)
- [`docs/implementation/phase-9-security-review.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-security-review.md)
- [`docs/implementation/phase-9-dec05-scheduler-retention-analysis.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-dec05-scheduler-retention-analysis.md)
- [`docs/evidence/phase9/OWNER-DECISION-ADDENDUM.md`](file:///d:/parentcontrol_app/docs/evidence/phase9/OWNER-DECISION-ADDENDUM.md)
- [`docs/evidence/phase9/MANIFEST.md`](file:///d:/parentcontrol_app/docs/evidence/phase9/MANIFEST.md)

---

## 1. Executive Governance Summary & Core Inviolable Principles

This document records the definitive execution log and governance audit for the Phase 9 Production Release Gate of the Parental Control App, reconciling all forensic investigations with formal owner determinations rendered on 2026-11-04.

### 1.1 Inviolable Governance Principles
1. **Never Assume Owner Approval:** Approval is never inferred from previous implementations, coordinator recommendations, local unit test passes, or authorizations granted in other workstreams. Operational mutations require explicit, active, written instruction from the project owner.
2. **Strict Independence of Decisions:** DEC-01 (Evidence Durability), DEC-02 (Hosted Deployment), DEC-03 (Android Hardware QA), and DEC-05 (Scheduler Policy) are strictly orthogonal, independent decisions. The resolution of DEC-01 or DEC-05 has zero bearing on the authorization posture of DEC-02 or DEC-03.
3. **Strict Negative Operational Boundaries Enforced:**
   - **Zero Unauthorized Git Mutations:** Zero `git add`, `git commit`, `git push`, `git reset`, `git clean`, or staging commands dispatched.
   - **Zero Hosted Mutations:** Zero SQL migrations applied; zero Edge Functions deployed; zero database rows modified on hosted Supabase (`hhqgreaoqulmfwfwarhc`).
   - **Zero Hardware QA Execution:** Zero APKs compiled; zero ADB commands executed; all 75 QA rows held strictly at `NOT RUN`.
   - **Zero Schedulers Activated:** Zero `pg_cron` jobs installed; zero Supabase scheduled triggers configured; retention sweeps remain strictly on-demand.
   - **Zero Log Tampering:** All 11 Phase 5 run logs in `docs/evidence/phase5/logs/` preserved untouched on disk.
   - **Zero Secrets Exposed:** Zero credentials, service-role keys, tokens, or passwords leaked.
   - **Phase 10 Not Started:** Phase 10 will not be initiated automatically.
4. **Four-Gate Sequential Release Rule:** Progression to production release (Gate D) is strictly prohibited until Gate B (Android QA) and Gate C (Hosted Hardening) have independently passed their authorized verification requirements. Local regression success must not be presented as hosted production verification.

---

## 2. Master Decision Status Register (DEC-01 through DEC-11)

The following register provides the reconciled, authoritative status of all 11 owner decisions entering the Phase 9 release gate as of 2026-11-04:

| Decision ID | Decision Title | Operational Scope | Required Action / Determination | Current Factual Evidence | Reconciled Definitive Status (2026-11-04) | Gating Severity |
|---|---|---|---|---|:---:|:---:|
| **DEC-01** | **Evidence Durability Policy** | 11 Phase 5 run logs (`docs/evidence/phase5/logs/*.log`, 201,441 B, 4,403 lines) trapped by `.gitignore:22:*.log`. | Owner determination between Choice A (force-stage logs) and Choice B (retain local-only). | All 11 logs verified bit-for-bit against `docs/evidence/phase5/MANIFEST.md` § 8. `.gitignore` line 22 active. No `git add -f` executed. | **APPROVED: CHOICE B (Local-Only Evidence)** | **DECIDED - GAP REMAINS OPEN (accepted local-only risk)** |
| **DEC-02** | **Hosted Migration & Function Deployment Readiness** | Applying Migrations 1–4, deploying Edge Functions (`account`, `family-admin`, `device-command`), and executing 5 Preflights on Supabase `hhqgreaoqulmfwfwarhc`. | Explicit written owner authorization to mutate hosted database and deploy functions. | 4 migrations unapplied; 3 functions undeployed; 5 preflight queries prepared but not executed. Client direct `DELETE` privilege on `safe_zones` remains live on hosted PostgreSQL. | **PENDING OWNER AUTHORIZATION / STRICTLY PROHIBITED** | **P1 (Critical Release Blocker)** |
| **DEC-03** | **Android QA Hardware Execution Readiness** | Compiling APKs, ADB connection, pairing ceremony, and executing 75-row QA matrix on physical Realme 7 (`RMX2161`, API 31) and Pixel 9a AVD (`emulator-5554`, API 37). | Explicit written owner authorization to build APKs, connect devices via ADB, and dispatch QA commands. | Devices isolated; ADB connectivity reported strictly as UNKNOWN. Zero APKs compiled; zero ADB commands issued. All 75 QA rows remain strictly `NOT RUN`. | **PENDING OWNER AUTHORIZATION / STRICTLY PROHIBITED** | **P1 (Critical Release Blocker)** |
| **DEC-04** | **Hosted WebRTC Replay Index Pre-Check** | Mandatory execution of Preflight Query 1 before Migration 2 to guarantee zero duplicate sequence rows. | Prerequisite gate prepared, NOT executed; DEC-02 remains PENDING OWNER AUTHORIZATION. | Preflight Query 1 formulated with strict STOP threshold (`duplicate_count > 0`). Formulated and reviewed locally; not executed against hosted. | **PREFLIGHT PREPARED / READY** | **P2 (Prerequisite to DEC-02)** |
| **DEC-05** | **Retention Sweep Scheduler Policy** | Installing `pg_cron`, Supabase scheduled triggers, or background cron webhooks for `run_retention_sweep()`. | Owner determination between Choice A (automated cron) and Choice B (on-demand only). | No `pg_cron` extension installed; no scheduled triggers configured in `config.toml`. Edge Function `cron/index.ts` guarded by 503 check. | **APPROVED: CHOICE B (On-Demand Execution Only)** | **DECIDED (standing on-demand policy)** |
| **DEC-06** | **Legacy Signaling Index Retirement** | Dropping redundant non-unique index `webrtc_signals_session_idx` following unique index creation. | Post-rollout cleanup approval. | Migration 2 retains legacy index additively; coexistence verified safe in local PostgreSQL tests; minor write amplification accepted. | **PRESERVED ADDITIVELY / DEFERRED** | **P3 (Hygiene)** |
| **DEC-07** | **Safe Zone Fallback Module Retirement** | Retaining `delete_zone_atomicity.ts` and unused `ZoneSnapshot` type import as reviewed rollback safety net per Owner Ruling #2. | Post-rollout cleanup approval after hosted Migration 4 is proven. | Module preserved untouched as reviewed safety net; production `family-admin` routes zone deletion to atomic RPC `delete_safe_zone_audited`. | **RETAINED AS REVIEWED FALLBACK** | **P2 / P3 (Safety Net)** |
| **DEC-08** | **Repository Line-Ending Normalization** | Committing `.gitattributes` locking `* text=auto eol=lf` across 62 LF files and 7 CRLF files. | Owner approval during future authorized commit window. | Specification drafted; dual aggregate checksums verified (`2bd6b310...` disk vs `7397f79b...` git index); awaiting commit window. | **SPECIFICATION DRAFTED / READY** | **P3 (Hygiene)** |
| **DEC-09** | **PostgreSQL Cluster Decommissioning** | Stopping and deleting 8 disposable PostgreSQL clusters in `.tools/` (~1.03 GB disk footprint). | Owner authorization to reclaim disk space. | All 8 clusters cataloged; postmasters stopped; data preserved intact on standby for local offline re-verification. | **PRESERVED ON STANDBY** | **P3 (Hygiene)** |
| **DEC-10** | **Retention Sweep Query Plan Verification** | Measuring hosted PostgreSQL buffer hit rates and heap access via `EXPLAIN (ANALYZE, BUFFERS)` post-apply. | Post-apply verification execution under DEC-02. | Batch delete query shape (`id = ANY (ARRAY(SELECT id ... LIMIT 10000))`) verified sub-millisecond locally; ready for hosted post-apply. | **PREPARED FOR POST-APPLY** | **P2 (Verification)** |
| **DEC-11** | **Device Command Replay TTL Horizon** | Formal ratification of 10s command TTL rejection horizon and Phase 4 audit digest correction. | Owner ratification of specification. | 10s command TTL horizon and Phase 4 digest correction documented; verified in Kotlin and Deno test suites. | **DOCUMENTED SPECIFICATION / RATIFIED** | **P2 (Contract)** |

---

## 3. Forensic Execution Analysis of Reconciled Decisions

### 3.1 DEC-01: Evidence Durability Policy — Choice B Approved
- **Background & Context:**  
  During Phase 5, 11 test execution logs totaling 201,441 bytes across 4,403 lines were generated in `docs/evidence/phase5/logs/`. Commit `b12659b` committed 73 Gate A files, but line 22 of `.gitignore` (`*.log`) silently trapped these 11 files, leaving only `p5-coord-deno-full3.txt` (19,608 bytes) tracked in Git history.
- **Forensic Verification (the 2026-11-04 documentation pass):**  
  Read-only `sha256sum` verification during the 2026-11-04 pass confirmed all 11 untracked `.log` files on the local workstation disk against the canonical manifest in `docs/evidence/phase5/MANIFEST.md` § 8. Every single file matches authoritative SHA-256 checksums with 100% bit-level fidelity:

| # | File in `docs/evidence/phase5/logs/` | Bytes (actual) | Lines (`wc -l`, actual) | SHA-256 (actual, computed read-only) | Manifest section 8 | Result |
|---|---|---:|---:|---|---|:---:|
| 1 | `p5-coord-dart-analyze-run2.log` | 48 | 2 | `9fa0431d7192e9d5a61e6274a72d6561a2554228ba491434b05498e59c614982` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 2 | `p5-coord-deno-full3.txt` | 19,608 | 200 | `9ebdaedc6b9031d4a5c0a3cd57cd5b05ddc8dcf6d30afe294b1c3a5fbec5d789` | consistent | **MATCH** (TRACKED in `b12659b`) |
| 3 | `p5-coord-deno-negative.log` | 5,672 | 79 | `d087186c2a67f3d2115115e209d21ddc63dbe0288859c4dfff4fd636079313ad` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 4 | `p5-coord-deno-restored.log` | 18,609 | 185 | `b5589dade24e2bd5ab2f9000cf3057ac6f7cd8e84b4ceb54fa66f7fdad4a24b0` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 5 | `p5-coord-deno-sql05.log` | 2,645 | 26 | `8c0e23d7ce45d507e5e184d759debf47834e89f59cb718c86ef422908b6a7295` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 6 | `p5-coord-flutter-run2.log` | 61,521 | 418 | `ca2462ccdb8a23db62205678709b1dad3ad9809785608e1f11b667238e5332f6` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 7 | `p5-coord-gradle-run1.log` | 30,685 | 458 | `6d14ac08b60553ca64f1a6b48072508dcf4c2c8c4f26df10be36e577a046eba0` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 8 | `p5coord-chain-negative3.log` | 16,844 | 647 | `e914ecaaed261bd87c3fc31c28772634d66c9c19161131dfe3cc8aaba4bb6080` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 9 | `p5coord-chain-run10.log` | 16,388 | 648 | `4638ad087731369d232512f3f62bac6b25b6b971376b0b190e55201d1f990744` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 10 | `p5coord-chain-run5.log` | 16,316 | 646 | `f22aefcdaa17666b7116930f81bbd9fcdb38adb15cf2b3088ae7ac0be6dfbc6d` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 11 | `p5coord-chain-run6.log` | 16,325 | 646 | `23c127e039967692b24202bbf5598c114334b54c8e218d7b67292fb4e853840f` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| 12 | `p5coord-chain-run9.log` | 16,388 | 648 | `4978d306e5458116a3211ad4e9bef4d0d9691381fd70c279aeba12b03397664f` | consistent | **MATCH** (ignored by `.gitignore:22` (`*.log`)) |
| **TOTAL** | **11 `.log` files (local-only)** | **201,441 B** | **4,403 lines** | *all digests verified against manifest section 8* | - | **12/12 MATCH** (12 files verified, 12 matched: 11 local-only `.log` files + 1 tracked `.txt` companion) |

- **Owner Ruling:** The owner formally selected **Choice B — Local-only evidence [APPROVED]**.
- **Consequences & Durability Boundaries:**
  1. `.gitignore` line 22 (`*.log`) remains intact and unmodified.
  2. No force-staging (`git add -f`) was or will be performed.
  3. A fresh clone from remote origin will not contain the 11 raw `.log` files.
  4. The local workstation represents an accepted single point of failure for raw test log artifacts.
  5. Gap DUR-01 is formally resolved as an accepted operational local-only evidence policy.
     > Dated clarification (2026-11-04): **DEC-01 owner decision is resolved as Choice B. GAP DUR-01 remains OPEN as an accepted local-only evidence durability risk. The 11 raw logs remain local workstation artifacts and are not included in fresh clones.** The sentence above is the pre-clarification historical record: "formally resolved" refers only to the owner decision, never to elimination of the durability gap.
- **Prohibitions:** Strictly forbidden to stage, force-add, or commit any of the 11 Phase 5 run logs.

---

### 3.2 DEC-02: Hosted Migration & Function Deployment Readiness — Pending Owner Authorization
- **Background & Operational Scope:**  
  Applying four database migrations and deploying three Edge Functions to hosted Supabase project `hhqgreaoqulmfwfwarhc` (AWS Seoul, Region `ap-northeast-2`).
- **Forensic Audit (the 2026-11-04 documentation pass):**
  - **4 Evaluated Migrations (Unapplied):**
    1. `20261030000100_abandoned_session_sweep.sql` (`aca47b44bb69c5d9ad70a95d52da314faec56217203cd0d49fa90f9085182c7b`)
    2. `20261030000200_phase1_authorization.sql` (`7558021d6aec4f9a80b16b1d401e03b4b84751ec93ea6c3dd83b9df67b1bfa38`)
    3. `20261030000300_retention_sweep.sql` (`184d8acb33090e4a587de8cad97e21c00688234f452fc50224242ba5cc1870ba`)
    4. `20261103000100_zone_delete_atomic_rpc.sql` (`a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf`)
  - **3 Edge Functions (Undeployed):**
    1. `account`
    2. `family-admin`
    3. `device-command`
  - **5 Read-Only Preflight Queries:** Prepared in `phase-9-release-readiness.md` § 3, but **zero have been executed against hosted**.
- **Live Production Security Posture:**  
  Hosted Supabase remains in the baseline schema state (`20260101000200_rls.sql`). Direct client `DELETE` privileges on `public.safe_zones` remain active for `authenticated` users on live production. Direct client deletion bypass remains possible on the remote database until Migration 2 is applied.
- **Owner Ruling:** **PENDING OWNER AUTHORIZATION / STRICTLY PROHIBITED**.
- **Consequences:** Gap HOST-01 remains **OPEN as an active P1 Release Blocker**. Gate C remains **BLOCKED**.
- **Prohibitions:** Strictly forbidden to execute migrations, deploy functions, or alter database state on hosted Supabase without explicit written owner authorization.

---

### 3.3 DEC-03: Android Controlled QA Execution — Pending Owner Authorization
- **Background & Operational Scope:**  
  Compiling APK binaries, installing packages via ADB, and executing the 75-row controlled QA validation matrix across live devices.
- **Forensic Audit (the 2026-11-04 documentation pass):**
  - **Target Device Inventory:**
    * Parent Monitor: Google Pixel 9a AVD (`emulator-5554`, Android 17 Preview API 37, x86_64).
    * Child Target: Physical Realme 7 (`RMX2161`, Android 12 API 31, ColorOS 12.1, ARM64).
    * ADB Connectivity: Reported strictly as **UNKNOWN**.
  - **QA Matrix Execution Posture:** Every single row of the 75-row controlled QA matrix carries `Status = NOT RUN` and `Actual Result = NOT RUN`. Zero tests have been conducted on real devices or emulators.
  - **Unverified Hardware Invariants:** Ten critical Android privacy and safety invariants (green dot indicator, non-dismissible ongoing notifications, 500ms immediate Stop action, native 5s permission revocation detection, 15s parent disconnect watchdog) remain unverified on live devices.
- **Owner Ruling:** **PENDING OWNER AUTHORIZATION / STRICTLY PROHIBITED**.
- **Consequences:** Gap AND-01 / GATE-B-01 remains **OPEN as an active P1 Release Blocker**. Gate B remains **BLOCKED**.
- **Prohibitions:** Strictly forbidden to compile APKs, execute ADB commands, pair hardware devices, or initiate microphone audio capture without explicit written owner authorization.

---

### 3.4 DEC-05: Retention Sweep Scheduler Policy — Choice B Approved
- **Background & Context:**  
  Automatic background schedulers (`pg_cron`, Supabase scheduled triggers, recurring webhooks) are disabled by default.
- **Forensic Audit (the 2026-11-04 documentation pass):**
  - Extension `pg_cron` is not installed on hosted Supabase or local configuration.
  - `supabase/config.toml` contains zero cron blocks or scheduled trigger webhooks.
  - Edge Function `supabase/functions/cron/index.ts` is protected by constant-time secret comparison and defensive `isMissingFunction` checks; without a secret or trigger, it returns HTTP 503 (`cron_not_configured`).
- **Owner Ruling:** The owner formally selected **Choice B — On-demand execution only [APPROVED]**.
- **Documented Operational Risks:**
  1. *Storage Backlog Accumulation:* Telemetry, location events (4,320 rows/month per device), daily usage, and WebRTC signaling payloads accumulate monotonically between manual runs, bloating table storage and indexes.
  2. *Single-Transaction Statement Timeout (SQL-04r / Owner Ruling #3):* Multi-transaction sweeps across calls were refused by Owner Ruling #3. `run_retention_sweep()` executes as a single outer database transaction. Delayed manual sweeps create massive backlogs that risk exceeding Supabase's `statement_timeout` (8–60s), triggering an all-or-nothing rollback (0 rows deleted).
  3. *Abandoned WebRTC Sessions:* Without scheduled background sweeps, abandoned WebRTC sessions remain in the database for up to 24 hours, locking child devices from initiating new audio assistance sessions.
  4. *Operational Diligence Required:* Operators must manually trigger sweeps on a regular cadence to remain compliant with declared COPPA/GDPR retention horizons (30 days for location, 7 days for signaling). **[Dated 2026-11-04: "regular cadence" here means an operator-managed manual practice. It is not a recurring schedule and authorizes no automation; each hosted sweep invocation requires separate written owner authorisation.]**
- **Authorized Invocation Protocol:**
  - *Method 1 (Dashboard SQL Editor):*
    ```sql
    SELECT public.run_retention_sweep();
    SELECT public.expire_abandoned_sessions(interval '24 hours');
    ```
  - *Method 2 (Authenticated HTTP POST):*
    ```bash
    curl -X POST "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/cron" \
      -H "x-cron-secret: $CRON_SECRET" \
      -H "Content-Type: application/json"
    ```
- **Prohibitions:** Strictly forbidden to install `pg_cron`, enable Supabase scheduled triggers, or configure recurring cloud webhooks without explicit written owner modification of DEC-05.

---

### 3.5 Status Review of Secondary Decisions (DEC-04, DEC-06 through DEC-11)

- **DEC-04 (WebRTC Replay Index Pre-Check):** Preflight Query 1 prepared with mandatory abort threshold (`duplicate_count > 0`). Prerequisite to Migration 2 under DEC-02.
- **DEC-06 (Legacy Signaling Index Retirement):** Harmless additive coexistence of non-unique and unique signaling indexes verified. Deferred to post-release cleanup.
- **DEC-07 (Safe Zone Fallback Module Retirement):** `delete_zone_atomicity.ts` and `ZoneSnapshot` type import retained as reviewed rollback safety net per Owner Ruling #2 until hosted Migration 4 is proven in production.
- **DEC-08 (Repository Line-Ending Normalization):** Dual aggregate verified (62 LF files, 7 CRLF files). Specification for `.gitattributes` drafted and awaiting future authorized commit window.
- **DEC-09 (PostgreSQL Cluster Decommissioning):** 8 cluster directories in `.tools/` (~1.03 GB disk footprint) preserved on standby with postmasters stopped for clean offline fallback.
- **DEC-10 (Retention Sweep Query Plan Verification):** Read-only `EXPLAIN (ANALYZE, BUFFERS)` prepared for execution immediately post-apply of Migration 3.
- **DEC-11 (Device Command Replay TTL Horizon):** 10s command TTL horizon and Phase 4 digest correction documented and verified in test suites.

---

## 4. Operational Boundaries Matrix: Permitted vs. Strictly Prohibited

| Operational Domain | Permitted Actions in Phase 9 (Green Light) | Strictly Prohibited Actions (Red Light — Owner Auth Required) |
|---|---|---|
| **Git & Version Control** | • Read-only inspection (`git status`, `git diff`, `git log`)<br/>• Local file edits/creation for Phase 9 reports and evidence manifests<br/>• Bit-for-bit checksum and hash verification | • `git add` or `git add -f` (excluded logs)<br/>• `git commit`<br/>• `git push`<br/>• `git reset`, `git clean`, `git checkout` |
| **Hosted Production Environment** | • Formulating read-only preflight queries for Dashboard SQL Editor<br/>• Inspecting local migration files and checksums<br/>• Documenting rollback procedures | • Applying SQL migrations to hosted Supabase<br/>• Deploying Edge Functions via Supabase CLI or API<br/>• Mutating live database records<br/>• Configuring cron or background triggers |
| **Android Physical & Virtual Hardware** | • Static analysis of Kotlin and Flutter source code<br/>• Sandboxed JVM Robolectric tests (39/39 passed)<br/>• Flutter widget and unit tests (408/408 passed)<br/>• Mapping device architecture and privacy invariants | • Compiling APK binaries (`flutter build apk`, `gradlew`)<br/>• Executing ADB commands against devices<br/>• Installing packages or modifying OS permissions<br/>• Initiating microphone audio capture |
| **Database Schedulers & Daemons** | • Documenting on-demand SQL and HTTP curl invocation runbooks<br/>• Inspecting `isMissingFunction` and `CRON_SECRET` defensive guards | • Installing `pg_cron` extension<br/>• Creating Supabase scheduled HTTP webhooks<br/>• Launching background scheduler daemon processes |

---

## 5. Four-Gate Release Readiness Framework Assessment

The production release gating evaluation following owner decision reconciliation stands as follows:

```
[ Gate A: Local Baseline ] ===> CLEARED (100% Hermetic Pass)
          |
          v
[ Gate B: Android Hardware QA ] ===> BLOCKED (DEC-03 Pending / 75 Rows NOT RUN)
          |
          v
[ Gate C: Hosted Backend Deployment ] ===> BLOCKED (DEC-02 Pending / Migrations 1-4 Unapplied)
          |
          v
[ Gate D: Production Release & Schedulers ] ===> HARD STOP (NO-GO / Prereqs Gates B & C Unmet)
```

| Gate | Description | Status | Severity | Factual Assessment & Evidence |
|---|---|:---:|:---:|---|
| **Gate A** | **Local Implementation & Regression Baseline** | **CLEARED** | **Green (100% Pass)** | All 150 Deno unit tests pass; 12 `family-admin` tests pass; 33-file SQL regression chain passes with 0 errors; negative control caught with Exit Code 3 at line 411; 39 Android JVM tests pass; 408 Flutter tests pass (Phase 5 historical baseline reference, not a Phase 9 re-run). At the pre-edit baseline (2026-11-04, 12:00 +05:30) the index held 53 staged files with 0 unstaged modifications and 0 untracked non-ignored files. Correction pass (2026-11-04, read-only verification): current state is HEAD `75d1a5232acbd87fe1068b5000d2916892e8143d` on `main`, 0 staged, 15 unstaged modifications, 1 untracked non-ignored file (the new docs/evidence/phase9/DOCUMENTATION-CORRECTION-ADDENDUM.md). The 53 baseline files became committed history via the owner's external commit at 12:23:31 +05:30, so the documents created by the earlier documentation pass are tracked now, not untracked. Neither documentation pass ran `git add`, staging or commit; these edits remain unstaged working-tree modifications. |
| **Gate B** | **Android QA Hardware Verification** | **BLOCKED** | **P1 (Release Blocker)** | Governed by DEC-03 (Pending Owner Authorization). All 75 QA matrix rows remain `NOT RUN`. GAP AND-01 / GATE-B-01 is OPEN. Hardware privacy invariants unverified on live devices. |
| **Gate C** | **Hosted Supabase Hardening** | **BLOCKED** | **P1 (Release Blocker)** | Governed by DEC-02 (Pending Owner Authorization). Migrations 1–4 unapplied and Edge Functions (`account`, `family-admin`, `device-command`) undeployed on hosted Supabase `hhqgreaoqulmfwfwarhc`. GAP HOST-01 is OPEN. Direct client `DELETE` vulnerability remains live on hosted PostgreSQL. |
| **Gate D** | **General Production Release** | **NO-GO** | **CRITICAL RELEASE STOP** | **HARD STOP**. Inviolable Release Rule: General production release is strictly prohibited until Gates B and C have independently passed their authorized verification requirements. Local regression success must not be presented as hosted production verification. |

---

> **Dated R9 evidence classification note (2026-11-05 09:17 +0530).** The Gate A row above aggregates results from **two different execution windows**. Per `phase-9-regression-matrix.md` §2.1: the Deno 150-test suite, the targeted `family-admin` 12-test suite, the local CI Stage 3 run, the 33-file PostgreSQL chain and the SQL-05 negative control are **PHASE 9 EXECUTION** artifacts (local logs dated 2026-11-04 09:51–11:09 +0530). The 39 Robolectric/JVM tests and the 408 Flutter widget/unit tests are **HISTORICAL BASELINE** artifacts from the Phase 5 window (2026-11-03 15:10 and 16:21:40) and were **not re-run in Phase 9** — the Kotlin figure cited here as "39/39 passed" is that historical run, not a fresh Phase 9 execution. S6–S8 (checksum digest audit, Phase 5 manifest table audit, documentation path scan) are **verification audits of evidence, not software test execution**, and must not be counted toward the test totals. Everything in this register remains a **local hermetic baseline**; hosted production behaviour is unverified and Gate C stays BLOCKED. No suite was re-run by the R9 pass.

---

## 6. Owner Decision Reconciliation Addendum & Next Steps

### 6.1 Summary of Status
- **DEC-01:** Resolved as **Choice B — Local-only evidence [APPROVED]**. No Git mutations performed; 11 Phase 5 run logs preserved bit-for-bit on disk; DUR-01 accepted.
- **DEC-05:** Resolved as **Choice B — On-demand execution only [APPROVED]**. Schedulers disabled; operational risks documented; on-demand execution runbook established.
- **DEC-02:** Recorded as **PENDING OWNER AUTHORIZATION [BLOCKED]**. GAP HOST-01 remains an active P1 blocker.
- **DEC-03:** Recorded as **PENDING OWNER AUTHORIZATION [BLOCKED]**. GAP AND-01 remains an active P1 blocker.
- **Production Release Verdict:** **NO-GO FOR GENERAL PRODUCTION RELEASE**.

### 6.2 Stand-Down Condition
Phase 9 is complete. All investigations, audits, and documentation reconciliations are concluded. The repository stands down cleanly at HEAD commit `b12659b9795ba69499483a84750a33897dd7e08a` awaiting explicit owner authorization before initiating any staging or deployment activity. [Dated 2026-11-04 reconciliation: the HEAD named above is this log's execution-window value, preserved verbatim. Since then the owner externally committed `75d1a52` and `65b3948` and pushed `main`; "stands down cleanly" was never equivalent to a verified clean working tree - at the time of writing 53 files were staged. Current measured state: HEAD `65b3948`, 0 staged / 0 unstaged / 0 untracked non-ignored, 32 ignored.]

*End of Decision Execution Log.*


---

## ADDENDUM VERIFICATION NOTES (2026-11-04)

These notes are part of the dated owner-decision addendum and apply to every Phase 9 addendum document.

1. **Verification method.** Read-only `sha256sum`, `wc`, `git ls-files`, `git cat-file -e`, `git check-ignore -v`, `git status` and `git diff` were used. No file other than the Phase 9 addendum documents was written. No test suite, build, device command or hosted operation was run.
2. **Line-total correction.** `wc -l` over the 11 ignored `*.log` files in `docs/evidence/phase5/logs/` totals **4,403 lines**, not the 4,195 lines carried in the original Phase 9 sections. The byte total (**201,441**) reproduces exactly, and all 12 SHA-256 digests in the directory match `docs/evidence/phase5/MANIFEST.md` section 8 (Pack contents, lines 203-214). The original 4,195 figure is preserved unaltered in the historical sections.
3. **Staged-file count reconciliation.** The original Phase 9 report's "37 staged files" was accurate at the time it was captured. As of the 2026-11-04 pre-edit baseline the index holds **53** staged files. Nothing was staged or unstaged by this documentation pass.
4. **DUR-01 status.** DEC-01 Choice B was approved. The consequence is that **GAP DUR-01 REMAINS OPEN** as an accepted local-only durability risk: a fresh `git clone` will not contain the 11 raw execution logs, which are preserved on this workstation only. This evidence is **not clone-durable**.
5. **Decisions NOT ruled on 2026-11-04.** The owner ruled only on DEC-01, DEC-02, DEC-03 and DEC-05. DEC-04 and DEC-06 through DEC-11, and the gaps governed by them, simply **carry forward their original register statuses** and await a future ruling. No approval or closure should be inferred.
6. **On-demand invocation is documentation, not authorisation.** The `run_retention_sweep()` / `expire_abandoned_sessions()` SQL and the `x-cron-secret` HTTP form describe the authenticated on-demand procedure only. Executing either against hosted Supabase is a production mutation requiring separate written owner authorisation; DEC-05 Choice B authorises no scheduled execution and no deployment. `pg_cron`, scheduled triggers and external cron webhooks remain prohibited.
7. **Gate posture is unchanged.** Gate A CLEARED (local baseline only), Gate B BLOCKED, Gate C BLOCKED, Gate D NO-GO. P1 blockers remain exactly GAP HOST-01 and GAP AND-01 / GATE-B-01. Verdict: **NO-GO FOR GENERAL PRODUCTION RELEASE. GO FOR LOCAL VERIFICATION BASELINE.**
8. **Digest detail.** The full per-file SHA-256 table is recorded once in `docs/evidence/phase9/OWNER-DECISION-ADDENDUM.md` and is referenced, not duplicated, by the other Phase 9 addenda. `docs/evidence/phase9/MANIFEST.md` was left unchanged.
9. **Repository state during the addendum window.** The addendum text above records entry HEAD `b12659b9795ba69499483a84750a33897dd7e08a`, which was the checked-out commit when the Phase 9 documents were authored and when this addendum's evidence was verified (12:00-12:16 +05:30). During that same window, at **12:23:31 +05:30, the project owner - not this documentation pass - committed the 53 previously staged files** as `75d1a5232acbd87fe1068b5000d2916892e8143d` ("docs: add phase 6-9 evidence packs, implementation reports, and CI test runner scripts"). Those assets are therefore committed history rather than staged content, and this addendum's own edits are unstaged working-tree modifications. The documentation pass executed no `git add`, `commit`, `push`, `reset`, `restore`, `checkout` or `stash`.
10. **Correction sub-pass, 12:36-12:52 +05:30.** A follow-up read-only audit corrected the addenda: the per-file SHA-256 tables in `docs/implementation/phase-9-decision-execution-log.md` and `docs/evidence/phase9/OWNER-DECISION-ADDENDUM.md` were rebuilt from digests computed directly from the files, because the first drafts listed five log filenames that do not exist (`p5-coord-sqlchain-*.log`) and eleven SHA-256 values matching no file on disk; attributions of this pass's verification work to numbered subagents were replaced with the recording method and the original Phase 9 sections were left untouched; present-tense working-tree claims were replaced with the two-stage baseline statement in note 3; and DEC-04 and DEC-06 through DEC-11 were relabelled as carried-forward, not ruled.


## Canonical Decision Wording (Dated 2026-11-04, Documentation Correction Pass)

- DEC-01 - APPROVED - CHOICE B: LOCAL-ONLY EVIDENCE. The owner decision is resolved.
- DUR-01 - ACCEPTED LOCAL-ONLY EVIDENCE DURABILITY RISK. The 11 raw Phase 5 `.log` files stay ignored by `.gitignore:22` (`*.log`), remain local-workstation artifacts, and are absent from fresh clones. No `git add -f` is authorised and `.gitignore` is unchanged. The decision is resolved; the durability limitation is accepted, not technically eliminated.
- DEC-02 - PENDING OWNER AUTHORIZATION - BLOCKED. No hosted migration, no Edge Function deployment, no hosted SQL execution. Five read-only preflight queries are prepared and none has been executed against hosted. HOST-01 remains a P1 release blocker.
- DEC-03 - PENDING OWNER AUTHORIZATION - BLOCKED. No APK build or installation, no ADB, no device pairing. All 75 QA rows remain NOT RUN. AND-01 / GATE-B-01 remains a P1 release blocker.
- DEC-05 - APPROVED - CHOICE B: ON-DEMAND ONLY. No pg_cron, no Supabase scheduled trigger, no external cron webhook.
- Approval of DEC-01 or DEC-05 never implies approval of DEC-02 or DEC-03.
- Evidence checksums re-verified read-only on 2026-11-04: 12/12 MATCH (11 local-only logs = 201,441 bytes / 4,403 lines; tracked `p5-coord-deno-full3.txt` = 19,608 bytes / 200 lines).
- Verdict: NO-GO FOR GENERAL PRODUCTION RELEASE. GO FOR LOCAL VERIFICATION BASELINE.
