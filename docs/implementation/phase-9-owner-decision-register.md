# Phase 9 Owner Decision Register & Governance Framework

**Document ID:** `PHASE-9-OWNER-DECISION-REGISTER`  
**Companion Mirror:** [`docs/implementation/phase-9-owner-decision-register.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md)  
**Date:** 2026-11-04  
**Active Branch:** `main`  
**Current HEAD Commit:** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`)  
**Core Governance Rule:** **Never assume owner approval. DEC-01, DEC-02, DEC-03, and DEC-05 are strictly independent decisions.**

---

## 1. Executive Governance Summary

This register formalizes the operational and architectural boundaries governing the production release gate of the Parental Control App. In strict compliance with core governance rules:
1. **Zero Presumption of Approval:** Recommendations presented by subagents or coordinators do **not** constitute approval. Every operational mutation requires explicit, active, written instruction from the project owner.
2. **Strict Decision Independence:** Approval of one decision (e.g. DEC-01 for Git evidence durability) does **not** grant or imply authorization for any other decision (e.g. DEC-02 for hosted deployment or DEC-03 for Android device QA).
3. **Negative Operational Boundaries:** Zero Git pushes, zero force-adds, zero remote database migrations, zero Edge Function deployments, zero APK builds, zero device interactions, and zero scheduler configurations have been or will be executed without prior sign-off.

---

## 2. Master Owner Decision Status Register (DEC-01 through DEC-11)

| Decision ID | Decision Title | Scope & Technical Summary | Evaluated Status | Gating Severity | Required Action for Progression |
|---|---|---|:---:|:---:|---|
| **DEC-01** | **Evidence Durability Policy** | Trapping of 11 Phase 5 run logs (`docs/evidence/phase5/logs/*.log`, 201,441 B, 4,195 lines) by `.gitignore:22:*.log`. Commit `b12659b` tracked only `p5-coord-deno-full3.txt`. | **PENDING OWNER DECISION / BLOCKED** | **P2** (Soft Gate) | Owner must select **Choice A** (force-add logs / update gitignore) or **Choice B** (retain local-only evidence). |
| **DEC-02** | **Hosted Migration & Function Deployment Readiness** | Authorizing execution of 5 Preflight Queries, applying Migrations 1–4, and deploying Edge Functions (`account`, `family-admin`, `device-command`) to hosted Supabase (`hhqgreaoqulmfwfwarhc`). Closes GAP HOST-01. | **STRICTLY PROHIBITED / BLOCKED** | **P1** (Release Blocker) | Explicit written approval to execute Dashboard SQL preflights, apply migrations sequentially, and deploy Edge Functions. |
| **DEC-03** | **Android QA Hardware Execution Readiness** | Building APKs, connecting via ADB, and executing the 75-row QA matrix on physical Realme 7 (`RMX2161`, API 31) and Pixel 9a AVD (`emulator-5554`, API 37). Closes GAP AND-01. | **STRICTLY PROHIBITED / BLOCKED** | **P1** (Release Blocker) | Explicit written approval to pair hardware devices and dispatch live Android QA execution. |
| **DEC-05** | **Retention Sweep Scheduler Policy** | Installing `pg_cron`, Supabase scheduled triggers, or background cron webhooks for `run_retention_sweep()` and `expire_abandoned_sessions()`. | **STOPPED BY POLICY / PENDING** | **P2** (Operational) | Owner election to either (A) configure automated cron trigger, or (B) maintain sweeps strictly on-demand. |
| **DEC-04** | **Hosted WebRTC Signaling Replay Pre-Check** | Mandatory execution of Preflight Query 1 (`SELECT session_id, sequence ... HAVING count(*) > 1`) before Migration 2 to guarantee zero duplicate sequence rows. | **PREFLIGHT FORMULATED / READY** | **P2** (Prerequisite) | Executed as Step 1 of DEC-02 hosted deployment playbook. |
| **DEC-06** | **Legacy Signaling Index Retirement** | Harmless coexistence of non-unique index `webrtc_signals_session_idx` and unique index `webrtc_signals_session_sequence_uniq`. | **PRESERVED ADDITIVELY / DEFERRED** | **P3** (Hygiene) | Deferred to post-release cleanup; zero schema churn before launch. |
| **DEC-07** | **Safe Zone Fallback Module Retirement** | Retaining `delete_zone_atomicity.ts` and unused `ZoneSnapshot` import in `family-admin` as reviewed rollback safety net per Owner Ruling #2. | **RETAINED AS REVIEWED FALLBACK** | **P2 / P3** (Safety Net) | Keep module intact until hosted Migration 4 is proven in production. |
| **DEC-08** | **Repository Line-Ending Normalization** | Normalizing repository line endings (62 LF files, 7 CRLF files) via proposed `.gitattributes` (`* text=auto eol=lf`). | **SPECIFICATION DRAFTED / READY** | **P3** (Hygiene) | Commit `.gitattributes` during future authorized commit window. |
| **DEC-09** | **PostgreSQL Cluster Decommissioning** | Status of 8 retained cluster directories in `.tools/` (~1.03 GB disk footprint) with postmasters stopped. | **PRESERVED ON STANDBY** | **P3** (Hygiene) | Retain for local offline re-verification; decommission post-release. |
| **DEC-10** | **Retention Sweep Query Plan Verification** | Measuring hosted PostgreSQL buffer hit rates via read-only `EXPLAIN (ANALYZE, BUFFERS)` post-apply. | **PREPARED FOR POST-APPLY** | **P2** (Verification) | Execute immediately following Migration 3 application. |
| **DEC-11** | **Device Command Replay TTL Horizon** | 10s command TTL horizon and Phase 4 digest correction documented. | **DOCUMENTED SPECIFICATION / RATIFIED** | **P2** (Contract) | Specification finalized and verified in Kotlin/Deno test suites. |

---

## 3. Deep-Dive on Core Pending Decisions

### 3.1 DEC-01: Evidence Durability Policy
- **Technical Context:**  
  During Phase 5, 11 test execution logs totaling 201,441 bytes across 4,195 lines were generated in `docs/evidence/phase5/logs/`. When commit `b12659b` was constructed, Git line 22 (`*.log`) ignored these files. Only `p5-coord-deno-full3.txt` (19,608 bytes) was tracked.
- **Current Evidence:**  
  All 11 files exist intact on the workstation disk and match the authoritative checksums in `docs/evidence/phase5/MANIFEST.md` § 8 with 100% bit-level precision.
- **The Two Explicit Choices for the Owner:**
  * **CHOICE A (Recommended): Authorize Force-Staging Evidence into Git**
    - *Mechanics:* Authorize `git add -f docs/evidence/phase5/logs/*.log` (and add exception `!docs/evidence/**/logs/*.log` to `.gitignore`). Separately authorize staging Phase 6, 7, and 8 evidence manifests.
    - *Pros:* Full evidentiary durability across fresh clones; automated manifest checks (`sha256sum -c`) pass out-of-the-box; Merkle-tree cryptographic immutability.
    - *Cons:* Adds ~201 KB of raw text logs to Git history.
  * **CHOICE B: Maintain Local-Only Workstation Evidence**
    - *Mechanics:* Leave `.gitignore` unchanged. Do not track logs in Git.
    - *Pros:* Clean repository history; zero Git packfile overhead.
    - *Cons:* A fresh `git clone` will lack the 11 logs; DUR-01 gap remains accepted; workstation single point of failure.
- **Current Status:** **PENDING OWNER DECISION / BLOCKED**. Zero Git mutations executed.

### 3.2 DEC-02: Hosted Migration & Function Deployment Readiness
- **Technical Context:**  
  The hosted Supabase database `hhqgreaoqulmfwfwarhc` (AWS Seoul, `ap-northeast-2`) is running the baseline schema where `authenticated` users possess direct client `DELETE` privileges on `public.safe_zones`.
- **Preflight Package Ready:**  
  5 read-only SQL preflight queries and 4 migrations (`abandoned_session_sweep`, `phase1_authorization`, `retention_sweep`, `zone_delete_atomic_rpc`) are verified locally and ready for execution.
- **STOP Conditions Enforced:**  
  Preflight Query 1 duplicate sequence count > 0; unexpected function catalog state; region/ref mismatch; checksum mismatch.
- **Current Status:** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**. Zero hosted mutations executed.

### 3.3 DEC-03: Android QA Hardware Execution Readiness
- **Technical Context:**  
  10 critical Android privacy and safety invariants (foreground notifications, green dot indicator, immediate Stop action, 15s parent disconnect watchdog, permission revocation detection) require hardware validation.
- **Documented Devices:**  
  Parent: Google Pixel 9a AVD (`emulator-5554`, Android 17 API 37).  
  Child: Physical Realme 7 (`RMX2161`, Android 12 API 31).  
  ADB connectivity status: Reported strictly as **UNKNOWN**.
- **Current Status:** **STRICTLY PROHIBITED / BLOCKED (P1 Release Blocker)**. All 75 test rows held strictly at `NOT RUN`. Zero APKs compiled; zero ADB commands issued.

### 3.4 DEC-05: Retention Sweep Scheduler Policy
- **Technical Context:**  
  Automated scheduling (`pg_cron`, external webhooks) is 100% disabled by default. Edge Function `cron/index.ts` is implemented with defense-in-depth fallbacks.
- **Consequences of On-Demand Policy:**  
  Storage accumulates between manual sweeps; risk of single-transaction query timeouts on large backlogs (Owner Ruling #3); abandoned WebRTC sessions lock devices for up to 24 hours until swept.
- **Current Status:** **STOPPED BY POLICY / PENDING (P2)**. Sweeps remain strictly on-demand.

---

## 4. Operational Boundaries Matrix

| Subsystem / Operation | Standard / Local Development | Staging / Remote Mutation | Production Release |
|---|:---:|:---:|:---:|
| **Git Read Commands (`status`, `diff`, `log`, `rev-parse`)** | **PERMITTED (Green)** | **PERMITTED (Green)** | **PERMITTED (Green)** |
| **Git Write Commands (`commit`, `push`, `reset`, `clean`)** | **STRICTLY PROHIBITED** | **STRICTLY PROHIBITED** | Requires Explicit Approval |
| **Force-Adding Ignored Files (`git add -f`)** | **STRICTLY PROHIBITED** | **STRICTLY PROHIBITED** | Requires DEC-01 Approval |
| **Offline Test Execution (Deno, local SQL, JVM, Flutter)** | **PERMITTED (Green)** | **PERMITTED (Green)** | **PERMITTED (Green)** |
| **Executing Read-Only Dashboard Preflights (Queries 1–5)** | N/A | **PERMITTED (Green)** | **PERMITTED (Green)** |
| **Applying Hosted SQL Migrations (1–4)** | **STRICTLY PROHIBITED** | Requires DEC-02 Approval | Requires DEC-02 Approval |
| **Deploying Edge Functions to Hosted Supabase** | **STRICTLY PROHIBITED** | Requires DEC-02 Approval | Requires DEC-02 Approval |
| **Compiling Android APKs (`flutter build`, `gradlew`)** | **STRICTLY PROHIBITED** | Requires DEC-03 Approval | Requires DEC-03 Approval |
| **Dispatching ADB Commands to Connected Devices** | **STRICTLY PROHIBITED** | Requires DEC-03 Approval | Requires DEC-03 Approval |
| **Enabling `pg_cron` or Background Scheduler Webhooks** | **STRICTLY PROHIBITED** | Requires DEC-05 Approval | Requires DEC-05 Approval |

---

## 5. Actionable Owner Decision Sign-Off Matrix

Please review each decision independently and record your formal determination:

```markdown
### OWNER SIGN-OFF FORM (PHASE 9 PRODUCTION RELEASE GATE)

[ ] DEC-01: Evidence Durability Policy
    ( ) CHOICE A: Authorize force-staging the 11 Phase 5 run logs and unignoring evidence logs.
    ( ) CHOICE B: Maintain current .gitignore; retain logs as local-only workstation artifacts.

[ ] DEC-02: Hosted Migration & Edge Function Deployment Readiness
    ( ) APPROVED: Authorize execution of Preflight Queries 1-5, Migrations 1-4, and Edge Functions.
    ( ) REJECTED: Maintain hosted Supabase backend at current baseline.

[ ] DEC-03: Android QA Hardware Execution Readiness
    ( ) APPROVED: Authorize APK compilation, ADB connection, and 75-row hardware QA matrix execution.
    ( ) REJECTED: Withhold physical/virtual device testing.

[ ] DEC-05: Retention Sweep Scheduler Policy
    ( ) APPROVED: Authorize configuration of automated background cron trigger for sweeps.
    ( ) REJECTED: Maintain retention sweeps and session expiry strictly on-demand.
```

---

## 6. Owner Decision Reconciliation Addendum (Dated 2026-11-04)

**Addendum Timestamp:** `2026-11-04T12:00:00Z`  
**Governing Coordinator ID:** `2cf4d2a8-bc94-44c4-96d3-10edfe3e10ea`  
**Synthesizing Subagent:** Subagent 6 (Master Documentation Synthesizer for Phase 9 Owner Decision Reconciliation)  
**Reconciled Scope:** DEC-01, DEC-02, DEC-03, DEC-05, and downstream gating consequences across Gates A, B, C, and D.

### 6.1 Formal Owner Determination Record

Following forensic audits conducted by Subagents 1 through 5, the project owner rendered the following formal determinations on 2026-11-04:

```markdown
### RECORDED OWNER DETERMINATIONS (2026-11-04)

[X] DEC-01: Evidence Durability Policy
    (*) CHOICE B: Maintain current .gitignore; retain logs as local-only workstation artifacts. [APPROVED]
    ( ) CHOICE A: Authorize force-staging the 11 Phase 5 run logs and unignoring evidence logs. [REJECTED]

[ ] DEC-02: Hosted Migration & Edge Function Deployment Readiness
    ( ) APPROVED: Authorize execution of Preflight Queries 1-5, Migrations 1-4, and Edge Functions.
    (*) PENDING OWNER AUTHORIZATION: Withhold all hosted mutations. [STRICTLY PROHIBITED / BLOCKED]

[ ] DEC-03: Android QA Hardware Execution Readiness
    ( ) APPROVED: Authorize APK compilation, ADB connection, and 75-row hardware QA matrix execution.
    (*) PENDING OWNER AUTHORIZATION: Withhold physical/virtual device testing. [STRICTLY PROHIBITED / BLOCKED]

[X] DEC-05: Retention Sweep Scheduler Policy
    ( ) CHOICE A: Authorize configuration of automated background cron trigger for sweeps. [REJECTED]
    (*) CHOICE B: Maintain retention sweeps and session expiry strictly on-demand. [APPROVED]
```

---

### 6.2 Reconciled Status Matrix (DEC-01 through DEC-11)

| Decision ID | Decision Title | Reconciled Status (2026-11-04) | Gating Severity | Definitive Impact & Enforced Boundary |
|---|---|:---:|:---:|---|
| **DEC-01** | **Evidence Durability Policy** | **APPROVED: CHOICE B (Local-Only Evidence)** | **RESOLVED (Accepted Risk)** | 11 Phase 5 run logs verified bit-for-bit against manifest § 8. `.gitignore:22:*.log` unchanged; no `git add -f` permitted. Fresh clones will not have raw logs; workstation durability accepted. |
| **DEC-02** | **Hosted Migration & Function Deployment Readiness** | **PENDING OWNER AUTHORIZATION** | **P1 (Release Blocker)** | Zero hosted migrations applied; zero Edge Functions deployed; 5 preflight queries prepared but not executed. Direct client `DELETE` vulnerability on `public.safe_zones` remains live on hosted Supabase (`hhqgreaoqulmfwfwarhc`). GAP HOST-01 OPEN. |
| **DEC-03** | **Android QA Hardware Execution Readiness** | **PENDING OWNER AUTHORIZATION** | **P1 (Release Blocker)** | Zero APKs compiled; zero ADB commands executed; all 75 QA rows remain strictly `NOT RUN`. GAP AND-01 / GATE-B-01 OPEN. Physical Realme 7 and Pixel 9a AVD testing withheld. Device connectivity reported strictly as UNKNOWN. |
| **DEC-05** | **Retention Sweep Scheduler Policy** | **APPROVED: CHOICE B (On-Demand Execution Only)** | **RESOLVED (Operational Mode)** | Zero `pg_cron` jobs; zero Supabase scheduled triggers; zero external cron webhooks. Sweeps run strictly on-demand via Dashboard SQL or authenticated Edge Function call. Operational backlog risks accepted. |
| **DEC-04** | **Hosted WebRTC Signaling Replay Pre-Check** | **PREFLIGHT PREPARED / READY** | **P2 (Prerequisite to DEC-02)** | Preflight Query 1 prepared with mandatory stop threshold (`count > 0`). Prerequisite to Migration 2 when DEC-02 is authorized. |
| **DEC-06** | **Legacy Signaling Index Retirement** | **PRESERVED ADDITIVELY / DEFERRED** | **P3 (Hygiene)** | Legacy non-unique index and unique index coexist additively. Harmless minor write amplification accepted; deferred post-release. |
| **DEC-07** | **Safe Zone Fallback Module Retirement** | **RETAINED AS REVIEWED FALLBACK** | **P2 / P3 (Safety Net)** | `delete_zone_atomicity.ts` retained as reviewed rollback safety net per Owner Ruling #2 until hosted Migration 4 is proven in production. |
| **DEC-08** | **Repository Line-Ending Normalization** | **SPECIFICATION DRAFTED / READY** | **P3 (Hygiene)** | 62 LF files, 7 CRLF files on Windows. Specification drafted; awaiting future authorized commit window. |
| **DEC-09** | **PostgreSQL Cluster Decommissioning** | **PRESERVED ON STANDBY** | **P3 (Hygiene)** | 8 cluster directories in `.tools/` (~1.03 GB disk footprint) preserved on standby with postmasters stopped. Clean offline fallback. |
| **DEC-10** | **Retention Sweep Query Plan Verification** | **PREPARED FOR POST-APPLY** | **P2 (Verification)** | `EXPLAIN (ANALYZE, BUFFERS)` prepared for execution immediately post-apply of Migration 3 under DEC-02. |
| **DEC-11** | **Device Command Replay TTL Horizon** | **DOCUMENTED SPECIFICATION / RATIFIED** | **P2 (Contract)** | 10s command TTL horizon and Phase 4 digest correction documented and verified in test suites. |

---

### 6.3 Detailed Reconciled Rulings & Enforced Boundaries

#### 1. DEC-01: Evidence Durability Policy — Choice B Approved
- **Owner Ruling:** The project owner formally approved **Choice B — Local-only evidence**.
- **Technical Scope:** The 11 Phase 5 test execution logs located in `docs/evidence/phase5/logs/` (totaling 201,441 bytes across 4,195 lines) will **not** be force-staged into Git history.
- **Evidence Verification:** Subagent 2 verified all 11 logs bit-for-bit against the canonical checksums in `docs/evidence/phase5/MANIFEST.md` § 8. Every file is 100% intact and uncorrupted on the local workstation disk.
- **Consequences:** 
  1. Line 22 of `.gitignore` (`*.log`) remains in effect and unchanged.
  2. Fresh clones of the repository from remote origin will not contain the 11 raw `.log` files; only `p5-coord-deno-full3.txt` is tracked in Git commit `b12659b`.
  3. The local workstation represents a single point of failure for raw test log artifacts.
  4. Gap DUR-01 is formally accepted by the owner as an intentional local-only evidence durability policy.
- **Prohibited Actions:** Strictly forbidden to execute `git add -f docs/evidence/phase5/logs/*.log`, modify `.gitignore`, or stage evidence logs into the Git index.

#### 2. DEC-02: Hosted Migration & Function Deployment — Pending Owner Authorization
- **Owner Ruling:** **PENDING OWNER AUTHORIZATION**. Zero hosted mutations are authorized.
- **Technical Scope:** Four pending migrations (`20261030000100_abandoned_session_sweep.sql`, `20261030000200_phase1_authorization.sql`, `20261030000300_retention_sweep.sql`, `20261103000100_zone_delete_atomic_rpc.sql`) and three Edge Functions (`account`, `family-admin`, `device-command`).
- **Hosted Vulnerability Posture:** Hosted Supabase project `hhqgreaoqulmfwfwarhc` (AWS Seoul, `ap-northeast-2`) remains at baseline schema. Direct client `DELETE` privilege on `public.safe_zones` remains live on hosted PostgreSQL. Direct client deletion bypass remains possible on the remote backend until Migration 2 is applied.
- **Preflight Preparation:** Five read-only preflight queries are fully prepared and validated locally, but **none have been executed against hosted**.
- **Consequences:** Gap HOST-01 remains **OPEN as an active P1 Release Blocker**. Gate C remains **BLOCKED**.
- **Prohibited Actions:** Zero remote migrations applied via Supabase CLI, Dashboard SQL Editor, or REST API; zero Edge Functions deployed; zero remote database rows altered.

#### 3. DEC-03: Android QA Hardware Execution — Pending Owner Authorization
- **Owner Ruling:** **PENDING OWNER AUTHORIZATION**. Hardware testing is withheld.
- **Technical Scope:** Building APK binaries, ADB installation, pairing ceremonies, and executing the 75-row controlled QA matrix across physical Realme 7 (`RMX2161`, Android 12, API 31) and Pixel 9a AVD (`emulator-5554`, Android 17 Preview, API 37).
- **QA Execution Posture:** All 75 test rows across 5 subsystems remain strictly at `NOT RUN`. Device connectivity status remains reported strictly as **UNKNOWN**. Zero test APKs have been compiled; zero ADB commands have been dispatched.
- **Consequences:** Gap AND-01 / GATE-B-01 remains **OPEN as an active P1 Release Blocker**. Gate B remains **BLOCKED**. Ten critical Android privacy and safety invariants (green dot indicator, persistent foreground notification, 500ms immediate Stop action, 15s parent disconnect watchdog) remain unverified on live devices.
- **Prohibited Actions:** Zero APK compilation (`flutter build apk`, `./gradlew assembleDebug`), zero ADB commands (`adb connect`, `adb install`, `adb shell`), zero hardware pairing handshakes.

#### 4. DEC-05: Retention Sweep Scheduler Policy — Choice B Approved
- **Owner Ruling:** The project owner formally approved **Choice B — On-demand execution only**.
- **Technical Scope:** Automatic background schedulers (`pg_cron`, Supabase scheduled HTTP webhooks, external cron daemons) are **prohibited**.
- **Operational Architecture:**
  - Sweeps for expired WebRTC signaling (7-day window), audit logs (365-day window), location events (30-day window), and daily usage (90-day window) will run **exclusively on-demand**.
  - `supabase/functions/cron/index.ts` is implemented with defensive guards (`isMissingFunction` and `CRON_SECRET` validation) but has no automated trigger configured.
- **Documented Operational Risks:**
  1. *Backlog Accumulation:* Telemetry, location events, and signaling payloads accumulate monotonically on disk between manual sweeps, increasing table and index sizes.
  2. *Single-Transaction Statement Timeout (SQL-04r):* Per Owner Ruling #3, `run_retention_sweep()` executes as a single transaction across all tables and batches. Delayed sweeps result in massive backlogs that risk exceeding Supabase's `statement_timeout` (8–60s), causing the entire sweep to roll back.
  3. *Abandoned WebRTC Sessions:* Without scheduled sweeps, abandoned WebRTC sessions remain in the database for up to 24 hours, locking child devices from initiating new sessions until swept or cleared by reactive opportunistic triggers.
  4. *Manual Diligence Required:* Operators must manually execute sweeps according to an operational schedule to maintain compliance with declared COPPA/GDPR data retention windows.
- **Authenticated On-Demand Invocation Protocol:**
  - *Method 1 (Dashboard SQL Editor):*
    ```sql
    -- Run full retention sweep across all tables
    SELECT public.run_retention_sweep();
    -- Expire abandoned sessions older than 24 hours
    SELECT public.expire_abandoned_sessions(interval '24 hours');
    ```
  - *Method 2 (Authenticated HTTP POST via curl):*
    ```bash
    curl -X POST "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/cron" \
      -H "x-cron-secret: $CRON_SECRET" \
      -H "Content-Type: application/json"
    ```
- **Prohibited Actions:** Strictly forbidden to install `pg_cron`, enable Supabase scheduled triggers, or configure recurring cloud cron jobs without explicit written owner modification of DEC-05.

---

### 6.4 Release Readiness Gates Posture

The definitive four-gate release evaluation following owner reconciliation stands as follows:

| Gate | Description | Status | Severity | Reconciled Posture & Reason |
|---|---|:---:|:---:|---|
| **Gate A** | **Local Implementation & Regression Baseline** | **CLEARED** | **Green (100% Pass)** | 150 Deno unit tests pass; 12 `family-admin` tests pass; 33-file SQL regression chain passes with 0 errors; negative control caught with Exit Code 3 at line 411; 39 Android JVM tests pass; 408 Flutter tests pass. Clean working tree with 0 unstaged modifications. |
| **Gate B** | **Android QA Hardware Verification** | **BLOCKED** | **P1 (Release Blocker)** | DEC-03 is PENDING OWNER AUTHORIZATION. All 75 QA matrix rows remain `NOT RUN`. GAP AND-01 is OPEN. Hardware privacy invariants unverified on physical/virtual devices. |
| **Gate C** | **Hosted Supabase Hardening** | **BLOCKED** | **P1 (Release Blocker)** | DEC-02 is PENDING OWNER AUTHORIZATION. Migrations 1–4 and Edge Functions unapplied to hosted Supabase `hhqgreaoqulmfwfwarhc`. GAP HOST-01 is OPEN. Direct client `DELETE` vulnerability remains live on hosted PostgreSQL. |
| **Gate D** | **General Production Release** | **NO-GO** | **CRITICAL RELEASE STOP** | **HARD STOP**. Inviolable Release Rule: General production release is strictly prohibited until Gates B and C have independently passed their authorized verification requirements. Local regression success must not be presented as hosted production verification. |

---

### 6.5 Strictly Prohibited Operational Actions

The following actions are strictly prohibited in the current operational state:
1. **NO `git add`, `git commit`, `git push`, `git reset`, `git clean` or staging operations.** (Files are maintained on disk without index modifications).
2. **NO modification or tampering with any of the 11 Phase 5 run logs** in `docs/evidence/phase5/logs/`.
3. **NO hosted Supabase mutations** (zero migrations, zero function deployments, zero table updates).
4. **NO Android APK compilation, ADB execution, or device pairing.**
5. **NO automated scheduler activation or `pg_cron` installation.**
6. **NO initiation of Phase 10.**

*End of Owner Decision Register.*
