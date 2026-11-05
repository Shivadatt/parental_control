# Phase 9 Owner Decision Register & Governance Framework

> _Dated reconciliation (2026-11-04 governance-consistency pass; measured 16:32 +0530): HEAD/index/tree figures in this document belong to its own execution window and are preserved verbatim as history. Current measured state: HEAD `65b39485a10b51e9a3e26f6b7f09f057b904b126` on `main` (= `origin/main`); 0 staged, 0 unstaged, 0 untracked non-ignored, 32 ignored. Chronology: `b12659b` (entry) → `75d1a52` (owner's external commit 12:23:31 +0530) → `65b3948` (owner's external commit 15:18:45 +0530, pushed). No documentation pass committed or pushed; the owner committed externally. An empty index is not a clean working tree. Authority and digests: `docs/evidence/phase9/FINAL-GOVERNANCE-CONSISTENCY-AUDIT.md`._

**Document ID:** `PHASE-9-OWNER-DECISION-REGISTER`  
**Companion Mirror:** [`docs/implementation/phase-9-owner-decision-register.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md)  
**Date:** 2026-11-04  
**Active Branch:** `main`  
**Execution-window HEAD (historical snapshot — not the repository tip):** `b12659b9795ba69499483a84750a33897dd7e08a` (`feat: implement GuardianService background sync and policy enforcement core`) _[Label corrected by the 2026-11-05 R9 pass; the value was this document's HEAD at authoring time. Current tip requires a fresh measurement — see `docs/evidence/phase9/FINAL-RESIDUAL-CORRECTION-ADDENDUM-R9.md`.]_  
**Core Governance Rule:** **Never assume owner approval. DEC-01, DEC-02, DEC-03, and DEC-05 are strictly independent decisions.**

---

## 1. Executive Governance Summary

This register formalizes the operational and architectural boundaries governing the production release gate of the Parental Control App. In strict compliance with core governance rules:
1. **Zero Presumption of Approval:** Recommendations presented by subagents or coordinators do **not** constitute approval. Every operational mutation requires explicit, active, written instruction from the project owner.
2. **Strict Decision Independence:** Approval of one decision (e.g. DEC-01 for Git evidence durability) does **not** grant or imply authorization for any other decision (e.g. DEC-02 for hosted deployment or DEC-03 for Android device QA).
3. **Negative Operational Boundaries:** Zero Git pushes, zero force-adds, zero remote database migrations, zero Edge Function deployments, zero APK builds, zero device interactions, and zero scheduler configurations have been or will be executed without prior sign-off.

---

## 2. Master Owner Decision Status Register (DEC-01 through DEC-11)

> Dated 2026-11-04: the status column below is the snapshot taken during the pre-decision execution window. DEC-01 and DEC-05 were subsequently **APPROVED - CHOICE B** by the owner; DEC-02 and DEC-03 remain **PENDING**, and DEC-04 and DEC-06 through DEC-11 retain their existing statuses with no approval inferred. §6.2 and the canonical decision wording at the end of this document carry the current statuses.

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
  During Phase 5, 11 test execution logs totaling 201,441 bytes across 4,195 lines [dated 2026-11-04 correction: byte total confirmed; line total re-measured at **4,403 lines**] were generated in `docs/evidence/phase5/logs/`. When commit `b12659b` was constructed, Git line 22 (`*.log`) ignored these files. Only `p5-coord-deno-full3.txt` (19,608 bytes) was tracked.
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
> Dated 2026-11-04: pre-decision snapshot, preserved verbatim. DEC-01 was subsequently **APPROVED - CHOICE B (LOCAL-ONLY EVIDENCE)**. The decision is resolved; DUR-01 remains **OPEN** as an accepted local-only durability risk, and no `git add -f` was ever authorized.

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
> Dated 2026-11-04: pre-decision snapshot, preserved verbatim. DEC-05 was subsequently **APPROVED - CHOICE B (ON-DEMAND EXECUTION ONLY)**. Prohibition on automation is unchanged (`pg_cron`, Supabase scheduled triggers, recurring external cron webhooks, automated scheduler activation), and any actual hosted invocation of `run_retention_sweep()` or `expire_abandoned_sessions(interval '24 hours')` still requires separate written owner authorisation.

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

**Addendum Timestamp:** 2026-11-04 (+05:30, Asia/Kolkata) - addendum written 12:08-12:14, coordinator evidence re-verification 12:00-12:24
**Recorded by:** Phase 9 documentation pass, from the project owner's written instruction dated 2026-11-04.
**Relationship to the original Phase 9 report:** This addendum is appended after the original Phase 9 sections, which are preserved verbatim. Those sections recorded DEC-01/02/03/05 as PENDING earlier on the same calendar date; the owner's written rulings supersede those PENDING entries as of this addendum.
**Reconciled Scope:** DEC-01, DEC-02, DEC-03, DEC-05, and downstream gating consequences across Gates A, B, C, and D.

### 6.1 Formal Owner Determination Record

By written instruction dated 2026-11-04, the project owner rendered the following formal determinations on 2026-11-04:

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

### 6.2 Decision Status Matrix (DEC-01 through DEC-11)

| Decision ID | Decision Title | Status (2026-11-04) | Gating Severity | Definitive Impact & Enforced Boundary |
|---|---|:---:|:---:|---|
| **DEC-01** | **Evidence Durability Policy** | **APPROVED - CHOICE B: LOCAL-ONLY EVIDENCE** | **ACCEPTED LOCAL-ONLY EVIDENCE DURABILITY RISK** (decision resolved; gap remains open - accepted, not technically eliminated) | 11 Phase 5 run logs verified bit-for-bit against manifest § 8. `.gitignore:22:*.log` unchanged; no `git add -f` permitted. Fresh clones will not have raw logs; workstation durability accepted. |
| **DEC-02** | **Hosted Migration & Function Deployment Readiness** | **PENDING OWNER AUTHORIZATION** | **P1 (Release Blocker)** | Zero hosted migrations applied; zero Edge Functions deployed; 5 preflight queries prepared but not executed. Direct client `DELETE` vulnerability on `public.safe_zones` remains live on hosted Supabase (`hhqgreaoqulmfwfwarhc`). GAP HOST-01 OPEN. |
| **DEC-03** | **Android QA Hardware Execution Readiness** | **PENDING OWNER AUTHORIZATION** | **P1 (Release Blocker)** | Zero APKs compiled; zero ADB commands executed; all 75 QA rows remain strictly `NOT RUN`. GAP AND-01 / GATE-B-01 OPEN. Physical Realme 7 and Pixel 9a AVD testing withheld. Device connectivity reported strictly as UNKNOWN. |
| **DEC-05** | **Retention Sweep Scheduler Policy** | **APPROVED: CHOICE B (On-Demand Execution Only)** | **DECIDED (standing on-demand policy)** | Zero `pg_cron` jobs; zero Supabase scheduled triggers; zero external cron webhooks. Sweeps run strictly on-demand via Dashboard SQL or authenticated Edge Function call. Operational backlog risks accepted. |
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
- **Technical Scope:** The 11 Phase 5 test execution logs located in `docs/evidence/phase5/logs/` (totaling 201,441 bytes across 4,403 lines) will **not** be force-staged into Git history.
- **Verification method:** Read-only `sha256sum` on this workstation, confirmed all 11 logs bit-for-bit against the canonical checksums in `docs/evidence/phase5/MANIFEST.md` § 8. Every file is 100% intact and uncorrupted on the local workstation disk.
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

| Gate | Description | Status | Severity | Status & Reason |
|---|---|:---:|:---:|---|
| **Gate A** | **Local Implementation & Regression Baseline** | **CLEARED** | **Green (100% Pass)** | 150 Deno unit tests pass; 12 `family-admin` tests pass; 33-file SQL regression chain passes with 0 errors; negative control caught with Exit Code 3 at line 411; 39 Android JVM tests pass; 408 Flutter tests pass (Phase 5 historical baseline reference, not a Phase 9 re-run). At the pre-edit baseline (2026-11-04, 12:00 +05:30) the index held 53 staged files with 0 unstaged modifications and 0 untracked non-ignored files. Correction pass (2026-11-04, read-only verification): current state is HEAD `75d1a5232acbd87fe1068b5000d2916892e8143d` on `main`, 0 staged, 15 unstaged modifications, 1 untracked non-ignored file (the new docs/evidence/phase9/DOCUMENTATION-CORRECTION-ADDENDUM.md). The 53 baseline files became committed history via the owner's external commit at 12:23:31 +05:30, so the documents created by the earlier documentation pass are tracked now, not untracked. Neither documentation pass ran `git add`, staging or commit; these edits remain unstaged working-tree modifications. |
| **Gate B** | **Android QA Hardware Verification** | **BLOCKED** | **P1 (Release Blocker)** | DEC-03 is PENDING OWNER AUTHORIZATION. All 75 QA matrix rows remain `NOT RUN`. GAP AND-01 is OPEN. Hardware privacy invariants unverified on physical/virtual devices. |
| **Gate C** | **Hosted Supabase Hardening** | **BLOCKED** | **P1 (Release Blocker)** | DEC-02 is PENDING OWNER AUTHORIZATION. Migrations 1–4 unapplied and Edge Functions (`account`, `family-admin`, `device-command`) undeployed on hosted Supabase `hhqgreaoqulmfwfwarhc`. GAP HOST-01 is OPEN. Direct client `DELETE` vulnerability remains live on hosted PostgreSQL. |
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

---

## DEC-02 SCOPE-SPECIFIC RECONCILIATION ADDENDUM (Dated 2026-11-05, Phase 9 Owner Decision Reconciliation)

### 0. Standing of this section

This section is **additive and dated**. Nothing above this line was edited, re-dated, reworded or deleted by the 2026-11-05 pass; the 2026-11-04 canonical decision wording is preserved verbatim immediately above. Every earlier section remains accurate as of its own capture window.

This section **authorises nothing**. It is a documentation reconciliation that compares already-recorded claims against read-only evidence collected on 2026-11-05. Evidence basis:

1. `docs/supabase-hosted-state-verification-2026-11-05.md` — live read-only inspection of hosted project `hhqgreaoqulmfwfwarhc` (`parent-control-prod`, `ap-northeast-2`), window ≈06:50–07:48 UTC, final read `2026-11-05T07:47:58Z`. Its §8 is the 18-row Stage 7 claim-by-claim matrix and §9 the new/corrected findings.
2. `docs/stage7_hosted_migration_apply_2026-10-29.md` — the historical record of the manual Stage 7 application.
3. `supabase/migrations/` (14 files) and `docs/implementation/phase-7-deployment-log.md:82,102,130,155` / `docs/implementation/phase-8-deployment-log.md:139-148`, which define the register's "Migrations 1–4" numbering.
4. `docs/p0-decision-specifications.md` — the DEC-12…DEC-16 specifications written by the same pass.

### 1. DEC-02 — reconciled **only** for the documented Stage 7 migration scope

**1.1 Registered DEC-02 scope is confirmed and remains 0% executed.** §2 row DEC-02 registers exactly three things: execution of 5 Preflight Queries, application of Migrations 1–4, and deployment of the Edge Functions `account`, `family-admin`, `device-command`. Resolving "Migrations 1–4" against the live hosted catalogue on 2026-11-05:

| Register label | File | Live hosted proof (2026-11-05) | Classification |
|---|---|---|---|
| Migration 1 | `supabase/migrations/20261030000100_abandoned_session_sweep.sql` | `public.expire_abandoned_sessions(...)` **ABSENT** | NOT APPLIED — **VERIFIED** |
| Migration 2 | `supabase/migrations/20261030000200_phase1_authorization.sql` | `private.is_parent_of_family(uuid, uuid)` **ABSENT** | NOT APPLIED — **VERIFIED** |
| Migration 3 | `supabase/migrations/20261030000300_retention_sweep.sql` | `public.run_retention_sweep()` **ABSENT** | NOT APPLIED — **VERIFIED** |
| Migration 4 | `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql` | `public.delete_safe_zone_audited(...)` **ABSENT** | NOT APPLIED — **VERIFIED** |

Preflight Queries 1–5: **not executed** — DEC-04 therefore still reads PREFLIGHT FORMULATED / READY. Edge Functions: 9 functions exist hosted, newest deployment timestamp **2026-10-27T18:07:08Z**, so none of the three registered deployments occurred after that date. **DEC-02 status is unchanged: PENDING OWNER AUTHORIZATION — BLOCKED (P1 Release Blocker).** GAP HOST-01 remains **OPEN**, and with it the direct-client `DELETE` exposure on `public.safe_zones` that Migration 2/4 were written to remediate — it is **still live on hosted** as of 2026-11-05.

**1.2 What is actually applied on hosted, and under which scope.** Exactly two repository migrations are verifiable as applied beyond the original baseline seven-file era, and both belong to the **Stage 7** operation of 2026-10-29, not to DEC-02:

| File | Live proof (hosted verification §8 items 1–8) | Classification |
|---|---|---|
| `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql` | `remote_sessions.expires_at` nullable; `remote_sessions_pending_expiry_check` present; surviving row `e84ba35e…` has `expires_at IS NULL`; `remote_sessions_transition_guard` BEFORE UPDATE FOR EACH ROW + `private.remote_session_transition_guard()`; `private.expire_stale_sessions()` body sweeps `status='requested'` only; `public.request_remote_session(uuid,uuid,text)` present, `proacl` = service-role execute only | **VERIFIED CURRENTLY** |
| `supabase/migrations/20261028000300_signaling_open_session.sql` | `webrtc_signals` SELECT/INSERT policies present without an expiry predicate; **0 policies project-wide reference `expires_at`** | **VERIFIED CURRENTLY** |

Reconciling these two files as "DEC-02 partially executed" would be wrong in both directions: it would credit DEC-02 with an operation it did not authorise, and it would hide the fact that DEC-02's own four migrations are demonstrably absent. **Stage 7 and DEC-02 are disjoint sets.**

**1.3 Wording conflict reconciled, not rewritten.** The 2026-11-04 canonical line reads "DEC-02 — PENDING OWNER AUTHORIZATION — BLOCKED. No hosted migration, no Edge Function deployment, no hosted SQL execution." That line is correct for the scope it governs: no DEC-02 migration was applied, no DEC-02 function deployed, no DEC-02 preflight executed, and this reconciliation pass itself executed no hosted mutation. It is **not** a statement about 2026-10-29, which precedes the wording and carries its own evidence trail. Both records stand as written; the correct combined reading is: *DEC-02 unexecuted; Stage 7 a separate, documented, scope-limited two-migration operation, verified still in force on 2026-11-05.*

**1.4 Explicit scope limit.** This reconciliation confers **no** hosted authority of any kind. In particular, still prohibited absent new written owner authorisation: applying any of the four migrations in 1.1; **replaying** `20261028000200` (non-idempotent — unguarded `add constraint remote_sessions_pending_expiry_check` at `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql:40-42`; a replay raises `duplicate_object`); repairing the dashboard migration history (still "No migrations"; the `supabase_migrations` schema itself is absent, `42P01`); deploying or redeploying any Edge Function; executing `run_retention_sweep()` / `expire_abandoned_sessions()`; and any SQL beyond `SELECT`.

**1.5 Documented count vs live count.** `docs/backend.md:17` states that "All **seven** files in `supabase/migrations/`" were applied. That was a true snapshot of the directory in the 2026-10-26/27 window, and its objects remain consistent with the live schema (`child_contact_ids` and the baseline function set are present). The directory now holds **14** files: **9** are consistent with live state (baseline 7 + Stage 7 2), **4** are proven not applied (1.1), and `20261028000100_remote_session_concurrency.sql` is **NOT VERIFIED (indistinguishable)** — its only object, `request_remote_session`, was later replaced by the `20261028000200` version. `docs/backend.md` was **not** modified by this pass.

### 2. Hosted findings that change the governance context (all read-only, none actionable here)

1. **The orphaned-session blocker is no longer present.** `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9` (device `fd79ee34-c6fe-4abd-a3ae-39f9b16ed628`) is now `status='expired'`, `ended_at=2026-10-29T11:21:35.671Z`, `expires_at IS NULL`; **zero** rows sit in `requested/accepted/active`. Because `request_remote_session` raises `session_in_progress` only while such a row exists, the risk flagged in the Stage 7 record does not currently apply. This pass did not end, update or delete that row; the mechanism that expired it is **NOT VERIFIED** (neither the migrated nor the baseline `expire_stale_sessions()` can produce it, since both require a non-null `expires_at`).
2. **The DEC-12 defect is observable in production data, not only in code.** `device_policies` holds 15 rows (`enforced=3, pending=11, failed=1`); exactly one `enforced` row (`d4a05b68-eff2-4dca-a794-86ced2565a48`, device `9dcadadc…`, version 1, `last_error` NULL) carries a policy with empty `blocked_packages` **and** empty `app_rules`, `block_all_except_allowed` not true, and its only substantive control is `daily_screen_time_limit_minutes = 120` plus bedtime fields. Concurrently, **0 of 17** `device_commands` rows carry `desired_count` in `result` and **0** carry `enforcement_supported`.
3. **No active production device is a Device Owner.** `devices` holds 14 rows, all `platform='android'`: `enforcement_mode='none'` 10 (revoked), `'device_owner'` 2 (**both revoked**), `'device_admin'` 2 (**the only active devices**). DEC-13 is therefore a live product question, not a documentation cleanup.
4. **DEC-14 has zero hosted footprint today:** there is **no `push_tokens` table** (or any similar table) in `public`, and no Firebase-related secret among the deployed secret *names*.
5. **DEC-05 Choice B matches reality:** `pg_cron` is not installed (absent from `pg_extension`, `cron.job` unresolved) and no scheduler objects of any kind exist. The `cron` Edge Function exists but nothing invokes it on a schedule.

### 3. DEC-01 — UNCHANGED

**APPROVED — CHOICE B (local-only evidence).** Durability of the 11 Phase 5 `.log` files was not re-tested and cannot change through documentation: `.gitignore:22` (`*.log`) still applies, `.gitignore` was not modified, no `git add -f` was performed, and **GAP DUR-01 remains OPEN** as an accepted local-workstation-only risk (not clone-durable). Checksums were not re-computed by this pass; the 12/12 MATCH result of 2026-11-04 stands as recorded above.

### 4. DEC-03 — UNCHANGED

**PENDING OWNER AUTHORIZATION — BLOCKED (P1 Release Blocker).** This pass ran no APK build, no installation, no ADB command, no pairing and no device test. The §5 matrix of `phase-8-android-qa-report.md` was re-counted on 2026-11-05: **75 rows, 75 distinct Test IDs, every row `Status = NOT RUN` and every `Actual Result = NOT RUN`**. GAP AND-01 / GATE-B-01 remains **OPEN**. Nothing in §2 above constitutes device evidence: hosted rows prove server state only, never child-device runtime behaviour, and the audio/microphone findings from Phase 8 remain exactly as recorded there (tested-build foreground-service microphone failure, candidate fix **NOT TESTED**).

**Row-count observation recorded, not repaired.** Counting the `Risk Level` column of the matrix itself yields **P0 18 / P1 39 / P2 17 / P3 1**, while the "Risk Taxonomy Breakdown" prose immediately above it at `phase-8-android-qa-report.md:223-226` states **P0 18 / P1 38 / P2 18 / P3 1**. Both sums are 75, so the matrix is complete; one row is classified differently by the prose than by the table. `phase-8-android-qa-report.md` was **not** modified by this pass (out of scope), and the DEC-03 status does not depend on which split is correct — **all 75 rows are NOT RUN under either counting.**

### 5. DEC-05 — UNCHANGED

**APPROVED — CHOICE B (on-demand only).** Confirmed consistent with hosted reality (§2.5 above). Approval of Choice B authorises **no** scheduled execution, **no** `pg_cron`, **no** Supabase scheduled trigger, **no** external cron webhook, and **no** on-demand sweep run: the on-demand SQL and `x-cron-secret` HTTP forms remain *documentation, not authorisation*. Executing either against hosted still requires separate written owner authorisation.

### 6. DEC-04 and DEC-06 through DEC-11 — CARRIED FORWARD

The owner ruled on none of these on 2026-11-05. Each **retains the §2 status recorded above verbatim** (`DEC-04` PREFLIGHT FORMULATED / READY; `DEC-06` PRESERVED ADDITIVELY / DEFERRED; `DEC-07` RETAINED AS REVIEWED FALLBACK; `DEC-08` SPECIFICATION DRAFTED / READY; `DEC-09` PRESERVED ON STANDBY; `DEC-10` PREPARED FOR POST-APPLY; `DEC-11` DOCUMENTED SPECIFICATION / RATIFIED). **No approval, closure or progression may be inferred.** Note the dependency now evidenced: DEC-04 (Preflight Query 1) and DEC-10 (post-apply `EXPLAIN (ANALYZE, BUFFERS)`) are steps *inside* DEC-02's playbook, so both remain unexecutable while DEC-02 is PENDING — this is a **VERIFIED** dependency (their registered wording names Migrations 2 and 3).

### 7. DEC-12 through DEC-16 — registered for the first time, all **PROPOSED**

The identifiers DEC-12…DEC-16 appeared in **no committed repository Markdown before this pass** (`git grep -E "DEC-1[2-6]" HEAD -- '*.md'` at HEAD `b398ab8425b256f5991aed0dd55b8ccd1d71fbe6` returns 0 files), so there was no prior register status to carry forward. They are entered here as proposals with full specifications in `docs/p0-decision-specifications.md`.

| Decision ID | Subject | Status on 2026-11-05 | Owner input required | Gating severity |
|---|---|---|---|---|
| **DEC-12** | Enforcement-status integrity (limits-only policies reported as `enforced`; honest counter fields) | **PROPOSED** | Choose the reporting semantics and whether historical hosted rows are backfilled or left as-is | P1 (trust/safety correctness) |
| **DEC-13** | Device Owner / managed-mode strategy (lab-only provisioning, factory-reset teardown, release keystore conflict) | **PROPOSED** | Choose the supported device-management mode and accept or reject the provisioning/teardown consequences | P1 (capability ceiling) |
| **DEC-14** | Push delivery / FCM (no `push_tokens` table, no Firebase project, FCM must stay non-authoritative) | **PROPOSED** | Decide whether to provision Firebase at all, and confirm FCM's non-authoritative role | P2 (reliability) |
| **DEC-15** | Website filtering scope (domain filtering only; no full-URL or HTTPS content inspection) | **PROPOSED** | Accept the stated capability boundary or authorise a materially different mechanism | P1 (privacy/claim accuracy) |
| **DEC-16** | Screen mirroring / recording scope (owner exclusion of 2026-10-27 preserved) | **PROPOSED** | Confirm the exclusion stands; resolve the 3-vs-16 N/A classification difference | P3 (scope hygiene) — must **not** block the others |

**None of DEC-12…DEC-16 is approved.** Approval of any one of them would not authorise implementation: §12/§13 of the governing brief keep Phase 10 shut, and each decision's specification lists the code, hosted and device work that would separately need authorisation.

### 8. Unresolved decision dependencies

Proposed sequencing (proposal only, not authorisation), from `docs/p0-decision-specifications.md:344`:

**DEC-13 → DEC-12 → DEC-15 → DEC-14 → runtime validation after DEC-03 → hosted deployment readiness (DEC-02) → release decision.**

- DEC-12's honest wording depends on DEC-13's chosen mode — *VERIFIED* in the sense that `enforcement_status` vocabulary and `EnforcementMode` are both consumed by the same reporting path; whether the owner wants Device Owner at all is *not* derivable from code.
- DEC-12 additionally depends on the four unapplied DEC-02 migrations only if the owner chooses a schema-affecting remedy — **INFERRED**, not verified: no DEC-12 remedy has been designed or costed.
- DEC-14 depends on Firebase provisioning that does not exist (verified absent) — the dependency is a fact; the decision to create it is the owner's.
- DEC-15's "no VPN filtering, no full-URL claim" boundary is independent of DEC-02/DEC-03 — **INFERRED** from the absence of any shared object; no evidence ties them.
- Runtime validation for every mode choice is gated by **DEC-03** (75 rows NOT RUN), and deployment readiness is gated by **DEC-02** (GAP HOST-01). Both P1 blockers are unchanged.
- **DEC-16 must not block** the sequence above; it is a scope-classification question.

### 9. Phase 10 — NOT AUTHORISED

§6.5 prohibition 6 ("NO initiation of Phase 10") stands unchanged. The 2026-11-05 pass implemented no feature, changed no Dart/Kotlin/TypeScript/SQL source, created no migration, deployed nothing, and started no Phase 10 workstream. Phase 10 requires explicit written owner authorisation.

### 10. Files written by this pass, and the mirror convention

- `phase-9-owner-decision-register.md` (this file) — the addendum above, appended.
- `docs/implementation/phase-9-owner-decision-register.md` — the identical addendum. The seven root ↔ `docs/implementation/` Phase 9 pairs were verified byte-identical before this pass (`cmp` on all seven, exit 0; this pair was 34,180 bytes on both sides), and the pair convention is maintained so the two copies cannot diverge in status wording.
- `docs/supabase-hosted-state-verification-2026-11-05.md` — new (hosted read-only evidence).
- `docs/p0-decision-specifications.md` — new (DEC-12…DEC-16).
- `docs/phase9-owner-decision-reconciliation-report.md` — new (reconciliation report).

No other file was written. No file was deleted, renamed, moved or reformatted.

### 11. Prohibited actions honoured

No `git add`, `commit`, `push`, `reset`, `clean`, `checkout`, `switch`, `restore`, `stash`, rebase, merge, cherry-pick, branch creation/switch, staging/unstaging or `git add -f`. No `.gitignore` change. No hosted mutation of any kind — `SELECT`-only, plus read-only dashboard/API reads; no migration application or replay, no Edge Function deploy, no DDL/DML, no `GRANT`/`REVOKE`, no RLS/schema/Auth/Realtime/Storage/secret/settings change, no bucket create/delete, no cron/schedule/webhook, no session ended, deleted or modified. No Supabase CLI. No secret, token, service-role key, connection string, password or credential value read into any document. No other Supabase project opened. No APK build, install, ADB, pairing or device test. No scheduler or sweep execution. No feature implementation. No Phase 10.

### 12. Verdict — UNCHANGED

Gate A CLEARED (local baseline only) | Gate B BLOCKED | Gate C BLOCKED | Gate D NO-GO. P1 release blockers remain exactly **GAP HOST-01 (DEC-02)** and **GAP AND-01 / GATE-B-01 (DEC-03)**. DEC-01 and DEC-05 remain APPROVED (Choice B). DEC-12…DEC-16 remain **PROPOSED**. **NO-GO FOR GENERAL PRODUCTION RELEASE. GO FOR LOCAL VERIFICATION BASELINE.**

*End of DEC-02 scope-specific reconciliation addendum (2026-11-05).*


---

## Phase 9.1 DEC-13 Device Owner & Managed Mode Decision Finalization Addendum (2026-11-05)

### 1. Purpose & Scope
This additive record documents completion of the decision-preparation package for **DEC-13 (Device Owner / Managed Mode Strategy)** under Phase 9.1. No implementation, provisioning, build, device test, or hosted change occurred.

### 2. Status Confirmation
- **DEC-13 Status:** **PROPOSED — Decision-Ready, Not Approved.**
- **No Option Approved:** The owner has not yet selected Option A (Standard Android first), Option B (Managed mode required for full enforcement), or Option C (Two explicit product tiers).
- **Zero Presumption of Approval:** Awaiting explicit written owner selection. DEC-13 remains P1.
- **Carried Governance Statuses Unchanged:**
  - DEC-01: APPROVED (Choice B)
  - DEC-02: PENDING/BLOCKED (P1 Release Blocker)
  - DEC-03: PENDING/BLOCKED (P1 Release Blocker; 75/75 QA rows NOT RUN)
  - DEC-05: APPROVED (Choice B)
  - DEC-12, DEC-14, DEC-15, DEC-16: PROPOSED

### 3. Deliverables Finalized
- Canonical Decision Specification: `docs/dec-13-device-owner-decision.md`
- Decision Readiness Report: `docs/dec-13-decision-readiness-report.md`

*End of Phase 9.1 DEC-13 decision finalization addendum (2026-11-05).*


---

## Phase 9.2 DEC-13 Explicit Owner Approval & DEC-12 Preparation Addendum (2026-11-05)

### 1. DEC-13 — Explicit Owner Approval Recorded

The project owner has reviewed the DEC-13 decision package and explicitly approved **DEC-13** with the following binding rulings:

| Component | Owner Ruling | Governance Status |
|---|---|---|
| **Product Architecture** | **OPTION B — Managed Mode Required for Full Enforcement** | **APPROVED** |
| **Standard Mode Baseline** | Standard Android mode remains available for monitoring and features supported by ordinary Android permissions. Full app suspension must not be promised in Standard Mode. | **APPROVED** |
| **Managed Mode Enforcement** | Full app suspension and managed enforcement strictly require Device Owner mode. If provisioning fails, the device remains in Standard Mode without claiming full enforcement. | **APPROVED** |
| **Device Owner Safe Exit** | A safe, non-destructive in-app Device Owner exit mechanism is mandatory before Managed Mode can be released to production. Factory reset must not be the only supported consumer exit mechanism. | **APPROVED REQUIREMENT / RELEASE BLOCKER** |
| **Device Administrator Mode** | Retire the Device Administrator mode and label completely. Do not present Device Administrator as a third supported management tier. | **APPROVED REQUIREMENT** |
| **Release Signing Keystore** | Deferred. Requires separate explicit owner authorization. | **DEFERRED / NOT AUTHORIZED** |
| **Implementation Scope** | Documentation and decision-preparation only. No code, build, ADB, device provisioning, hosted schema, Edge Function deployment, or Phase 10 work is authorized. | **STRICT BOUNDARY IN FORCE** |

### 2. Comprehensive Decision Governance Status Snapshot (Phase 9.2)

| Decision ID | Description | Status on 2026-11-05 (Phase 9.2) | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migration pair reconciled historical evidence only; 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **PROPOSED** | P1 Trust/Safety. Decision package prepared for owner review. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **PROPOSED** | P2 Reliability. Awaiting separate owner review. |
| **DEC-15** | Website Filtering Scope & Architecture | **PROPOSED** | P1 Claim Accuracy. Awaiting separate owner review. |
| **DEC-16** | Screen Mirroring & Recording Scope | **PROPOSED** | P3 Scope Hygiene. Exclusion confirmed; awaiting formal ruling. |

### 3. Deliverables Finalized in Phase 9.2
- **Updated DEC-13 Specification:** `docs/dec-13-device-owner-decision.md` (records explicit approval, Option B architecture, safe-exit release blocker, DA retirement, keystore deferral).
- **Canonical DEC-12 Specification:** `docs/dec-12-screen-time-bedtime-decision.md` (canonical decision package for screen-time and bedtime enforcement).
- **Updated P0 Specifications:** `docs/p0-decision-specifications.md` (reflects DEC-13 approved status and DEC-12 alignment).
- **Phase 9.2 Readiness Report:** `docs/phase9-2-dec13-approval-dec12-decision-readiness.md`.

*End of Phase 9.2 DEC-13 approval recording & DEC-12 preparation addendum (2026-11-05).*


---

## Phase 9.3 DEC-12 Explicit Owner Approval & Governance Consolidation Addendum (2026-11-05)

### 1. DEC-12 — Explicit Owner Approval Recorded

The project owner has reviewed the DEC-12 decision package and explicitly approved **DEC-12 (Screen-Time & Bedtime Enforcement)** with the following five binding rulings:

| Decision Area | Owner-Approved Choice | Governing Meaning & Scope | Governance Status |
|---|---|---|---|
| **Daily Screen-Time Limit** | **D1-B (Mode-Split)** | Standard Mode = advisory notification only; Managed Mode = hard package suspension via `setPackagesSuspended` upon quota exhaustion. Limit must not be reported as `enforced` unless physical enforcement is verified. | **APPROVED** |
| **Bedtime Enforcement** | **B1-B (Hard Suspension in Managed)** | Managed Mode = hard bedtime package suspension across scheduled overnight window; Standard Mode = advisory notification only. Bedtime must not be reported as `enforced` while evaluation is informational. | **APPROVED** |
| **Emergency Override** | **O1-C (Child Emergency Pass, 10 Minutes)** | Child-initiated emergency pass lasting exactly 10 minutes. Dialers, emergency numbers, and safety-critical system access are strictly immune. Pass auto-expires, cannot be chained silently, and is audit-logged. | **APPROVED** |
| **Per-App Daily Limits** | **P1-A (Deferred)** | Per-app duration quotas are deferred to Phase 10. Excluded from immediate DEC-12 scope to avoid premature schema changes. | **APPROVED (DEFERRED TO PHASE 10)** |
| **Production Row Remediation** | **DEFER** | No update to hosted `device_policies` row `d4a05b68…` or historical command acks. Requires separate future hosted authorization under DEC-02. | **APPROVED (DEFERRED)** |

### 2. Comprehensive Decision Governance Status Snapshot (Phase 9.3)

| Decision ID | Description | Status on 2026-11-05 (Phase 9.3) | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migration pair reconciled historical evidence only; 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **PROPOSED** | P2 Reliability. Awaiting separate owner review. |
| **DEC-15** | Website Filtering Scope & Architecture | **PROPOSED** | P1 Claim Accuracy. Awaiting separate owner review. |
| **DEC-16** | Screen Mirroring & Recording Scope | **PROPOSED (Scope Exclusion Confirmed)** | P3 Scope Hygiene. Exclusion confirmed; 3 N/A canonical vs 16 N/A parity preserved. |

### 3. Deliverables Finalized in Phase 9.3
- **Updated DEC-12 Specification:** `docs/dec-12-screen-time-bedtime-decision.md` (records APPROVED status, 5 owner choices, 10-minute emergency pass requirements, open technical design questions, and release blockers).
- **Updated P0 Specifications:** `docs/p0-decision-specifications.md` (reflects DEC-12 APPROVED, DEC-13 APPROVED, DEC-14/15 PROPOSED, DEC-16 registered status).
- **Consolidated Governance Report:** `docs/phase9-3-dec12-approval-governance-consolidation.md`.

### 4. Implementation & Execution Boundaries
Documentation and governance consolidation only. Zero application code modified, zero APKs built, zero ADB commands run, zero devices provisioned or tested, zero hosted SQL migrations or Edge Function deployments initiated.

*End of Phase 9.3 DEC-12 approval recording & governance consolidation addendum (2026-11-05).*


---

## Phase 9.5 DEC-14 Explicit Owner Approval & Architecture Ratification Addendum (2026-11-05)

### 1. DEC-14 — Explicit Owner Approval Recorded

The project owner has reviewed the DEC-14 decision package (`docs/dec-14-fcm-owner-decision.md`) and explicitly approved **DEC-14 (Push Notifications / FCM Delivery)** with the following binding ruling:

> **DEC-14 Owner Decision: APPROVED — Option B: Realtime + FCM Non-Authoritative Wake-Up Transport.**

The ten binding architectural rules approved by the owner:

1. **Dual Transport Separation:** Supabase Realtime delivers live, low-latency alert updates while the parent application is connected and running in the foreground. FCM HTTP v1 acts strictly as an out-of-band, best-effort background notification and wake-up transport.
2. **Authoritative Source of Truth:** Supabase remains the single authoritative source for alerts, permissions, family membership, and authorization. FCM is strictly a non-authoritative notification pipe.
3. **Opaque Payloads (Privacy Enforcement):** FCM payloads must remain completely opaque and contain only the minimum identifiers required:
   - `alert_id` (UUID)
   - `family_id` (UUID)
4. **Zero PII or Telemetry in Transit:** No child personally identifiable information (PII), child names, GPS coordinates, application package names, device telemetry details, or human-readable alert text may ever be placed in push payloads. Google and intermediary push networks see only opaque UUID metadata.
5. **Mandatory Authenticated Re-fetch:** Receiving or tapping a push notification must launch the parent application into an authenticated state. The application must present its valid Supabase JWT to retrieve authoritative alert details directly from `public.safety_alerts` via Row-Level Security (RLS).
6. **No Proof of Action:** FCM delivery, push receipt, or lock-screen display must never be treated as proof that an alert was seen, read, or acted upon by a guardian. Alert acknowledgement requires an explicit, authenticated mutation in Supabase.
7. **Failure Non-Destructiveness:** Delivery failure, FCM push throttling, or token expiration must never delete, invalidate, drop, or alter the enforcement status of an alert.
8. **Reconnection Reconciliation:** Missed alerts must be reconciled directly from Supabase upon app reconnect or foreground resume via authenticated REST/Realtime queries.
9. **Zero Authorization Authority:** FCM is not an authorization channel and must never execute privileged actions or alter device policy states.
10. **Scope Limitation:** The approved architecture is strictly limited to out-of-band alert delivery to parent devices. Child-side push notifications remain excluded.

### 2. Comprehensive Decision Governance Status Snapshot (Phase 9.5)

| Decision ID | Description | Status on 2026-11-05 (Phase 9.5) | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migration pair reconciled historical evidence only; 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Implementation gated. |
| **DEC-15** | Website Filtering Scope & Architecture | **PROPOSED** | P1 Claim Accuracy. Awaiting separate owner review. |
| **DEC-16** | Screen Mirroring & Recording Scope | **PROPOSED (Scope Exclusion Confirmed)** | P3 Scope Hygiene. Exclusion confirmed; 3 N/A canonical vs 16 N/A parity preserved. |

### 3. Deliverables Finalized in Phase 9.5
- **Ratified DEC-14 Specification:** `docs/dec-14-fcm-owner-decision.md` (records APPROVED status, Option B architecture, opaque payload constraints, and acceptance criteria).
- **Consolidated Approval Report:** `docs/phase9-5-dec14-owner-approval-record.md`.
- **Updated P0 Specifications:** `docs/p0-decision-specifications.md` (reflects DEC-14 APPROVED — Option B status).

### 4. Implementation & Execution Boundaries
Documentation and governance consolidation only. The owner approval of DEC-14 authorizes architecture and requirements only. Zero application code modified, zero Firebase projects created, zero credentials provisioned, zero APKs built, zero ADB commands run, zero devices tested, and zero hosted SQL migrations or Edge Function deployments initiated.

*End of Phase 9.5 DEC-14 approval recording & architecture ratification addendum (2026-11-05).*


---

## Phase 9.7 DEC-15 Explicit Owner Approval & Scope Exclusion Addendum (2026-11-05)

### 1. DEC-15 — Explicit Owner Approval Recorded

The project owner has reviewed the DEC-15 decision package (`docs/dec-15-website-filtering-owner-decision.md`) and explicitly approved **DEC-15 (Website Filtering Scope & Architecture)** with the following binding ruling:

> **DEC-15 Owner Decision: APPROVED — Option D: Defer website filtering for the current release.**

The approved interpretation and binding constraints:

1. **Current Release Scope Exclusion:** Website filtering (including URL filtering, domain blocking, website categorization, safe search enforcement, and browsing history collection) is formally excluded from the scope of the current release.
2. **Options A, B, and C Not Selected:**
   - **Option A (DNS-based filtering):** Not selected; no DNS resolver or Private DNS implementation authorized.
   - **Option B (Local VPN-based filtering):** Not selected; no Android `VpnService` or local packet-filtering implementation authorized.
   - **Option C (Managed browser-only filtering):** Not selected; no dedicated browser or WebView wrapper authorized.
3. **No Implementation Authorization:** This ruling authorizes documentation and governance updates only. It does NOT authorize writing code, creating database tables, modifying policies, altering AndroidManifest, adding permissions, building APKs, or testing on hardware.
4. **Product Claim Restrictions:** Existing product claims, documentation, and user interfaces must accurately reflect that website filtering is not implemented. No device-wide website filtering capability may be claimed, and no URL blocking, domain blocking, safe browsing, or HTTPS content inspection may be advertised as available.
5. **App Suspension Distinction:** Existing application package suspension (`PolicyApplier.kt` via Device Owner) must not be represented as website filtering.
6. **Future Reconsideration Requirements:** Website filtering may be reconsidered in a future milestone only through a separate explicit owner decision with dedicated scope, threat modelling, and risk analysis.
7. **Phase 10 Boundary:** This decision does not authorize Phase 10 or any subsequent development phase.

### 2. Comprehensive Decision Governance Status Snapshot (Phase 9.7)

| Decision ID | Description | Status on 2026-11-05 (Phase 9.7) | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migration pair reconciled historical evidence only; 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Implementation gated. |
| **DEC-15** | Website Filtering Scope & Architecture | **APPROVED (Option D: Deferred)** | Website filtering excluded from current release. Options A, B, C not selected. No implementation authorized. |
| **DEC-16** | Screen Mirroring & Recording Scope | **PROPOSED (Scope Exclusion Confirmed)** | P3 Scope Hygiene. Exclusion confirmed; 3 N/A canonical vs 16 N/A parity preserved. |

### 3. Deliverables Finalized in Phase 9.7
- **Ratified DEC-15 Specification:** `docs/dec-15-website-filtering-owner-decision.md` (records APPROVED — Option D status, scope exclusion, technical comparison of unselected alternatives, and product claim constraints).
- **Consolidated Approval Report:** `docs/phase9-7-dec15-owner-approval-record.md`.
- **Updated P0 Specifications:** `docs/p0-decision-specifications.md` (reflects DEC-15 APPROVED — Option D status).
- **Corrected Regression/Gaps Documentation:** Minimal documentation corrections in `phase-8-open-gaps.md` and `phase-8-regression-matrix.md` clarifying web filtering as deferred.

### 4. Implementation & Execution Boundaries
Documentation and governance consolidation only. Zero application code modified, zero Android services added, zero database mutations executed, zero APKs built, zero ADB commands run, zero devices tested, and zero hosted deployments initiated.

*End of Phase 9.7 DEC-15 approval recording & scope exclusion addendum (2026-11-05).*


---

## Phase 9.9 DEC-16 Explicit Owner Approval & Formal Scope Exclusion Addendum (2026-11-05)

### 1. DEC-16 — Explicit Owner Approval Recorded

The project owner has reviewed the DEC-16 decision package (`docs/dec-16-screen-mirroring-recording-owner-decision.md`) and explicitly approved **DEC-16 (Screen Mirroring & Screen Recording Product Scope)** with the following binding ruling:

> **DEC-16 owner decision: Option A — Exclude both screen mirroring and screen recording from product scope.**

The approved interpretation and binding scope constraints:

1. **Parent-to-Child Screen Mirroring Excluded:** Remote display casting or streaming from parent to child is formally excluded from the product scope.
2. **Child-to-Parent Screen Mirroring Excluded:** Remote viewing or streaming of the child's display to the parent device is formally excluded from the product scope.
3. **Live Screen Viewing Excluded:** All real-time display capture and screen streaming mechanisms are excluded from HAVEN.
4. **Screen Recording Excluded:** Video capture, display encoding (H.264/MP4), local clip storage, and cloud video upload are formally excluded from the product scope.
5. **Screenshot Capture Excluded:** Static display captures, automated screenshot schedules, and on-demand screenshot commands are formally excluded from the product scope.
6. **Android MediaProjection Excluded:** Integration with Android's `MediaProjection`, `createVirtualDisplay`, `PixelCopy`, or `ImageReader` screen capture APIs is excluded.
7. **Screen-Capture WebRTC Tracks Excluded:** `getDisplayMedia` or screen video tracks within WebRTC are excluded.
8. **Media Storage and Export Excluded:** Creation of media storage buckets, video playback routes, clip downloading, and video export capabilities are excluded.
9. **No Covert Capture Permitted:** Hidden, automated, background, or unconsented screen capture of any kind is strictly prohibited.
10. **Existing Audio & Camera Assistance Boundary:** Existing live assistance features (one-way microphone audio assistance and optional front-camera video during active assistance sessions) remain governed separately under their established requirements. DEC-16 does not authorize modifying, expanding, or recording those features.
11. **Child Privacy Commitments Preserved:** Existing child-facing privacy guarantees (`child_settings_tab.dart:67-70`, `child_session_page.dart:144-147`, `remote_assistance_page.dart:89-91`, `remote_session_page.dart:139-142`) stating that the app never takes screenshots, records video, or captures passwords remain preserved intact in code and UI copy.
12. **Future Reconsideration Requirements:** Any future proposal to introduce screen capture or recording requires a formal product re-charter, child privacy impact assessment, threat model, legal review, and a separate explicit owner decision. Option A is a formal product-scope exclusion, not a temporary deferral.
13. **Options B, C, and D Not Selected:** Options B (live mirroring only), C (mirroring and recording), and D (milestone deferral) remain unselected.
14. **No Implementation Authorization:** This ruling authorizes governance records and documentation updates only. It does NOT authorize writing code, modifying `AndroidManifest.xml`, creating database tables, building APKs, or testing on hardware.

### 2. Comprehensive Decision Governance Status Snapshot (Phase 9.9)

| Decision ID | Description | Status on 2026-11-05 (Phase 9.9) | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migration pair reconciled historical evidence only; 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Implementation gated. |
| **DEC-15** | Website Filtering Scope & Architecture | **APPROVED (Option D: Deferred)** | Website filtering excluded from current release. Options A, B, C not selected. No implementation authorized. |
| **DEC-16** | Screen Mirroring & Recording Scope | **APPROVED (Option A: Excluded)** | Screen mirroring, recording, and screenshots formally excluded from product scope. Options B, C, D not selected. |

### 3. Deliverables Finalized in Phase 9.9
- **Ratified DEC-16 Specification:** `docs/dec-16-screen-mirroring-recording-owner-decision.md` (records APPROVED — Option A status, formal product scope exclusion, 12 approved interpretations, and privacy invariants).
- **Consolidated Approval Report:** `docs/phase9-9-dec16-owner-approval-record.md`.
- **Updated P0 Specifications:** `docs/p0-decision-specifications.md` (reflects DEC-16 APPROVED — Option A status).

### 4. Implementation & Execution Boundaries
Documentation and governance consolidation only. Zero application code modified, zero Android permissions or services added, zero Supabase migrations created, zero APKs built, zero ADB commands run, zero devices tested, and zero hosted deployments initiated.

*End of Phase 9.9 DEC-16 approval recording & scope exclusion addendum (2026-11-05).*
