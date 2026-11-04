# Phase 9 Production Release Readiness & Controlled Deployment Playbook

**Document ID:** `PHASE-9-RELEASE-READINESS`  
**Companion Mirror:** [`docs/implementation/phase-9-release-readiness.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-release-readiness.md)  
**Date:** 2026-11-04  
**Target Commit:** `b12659b9795ba69499483a84750a33897dd7e08a` (`main`)  
**Target Environment:** Supabase Project `hhqgreaoqulmfwfwarhc` (AWS Seoul, `ap-northeast-2`)  
**Production Release Verdict:** **NO-GO FOR GENERAL RELEASE** / **GO FOR LOCAL VERIFICATION BASELINE**

---

## 1. Executive Release Verdict & Gating Summary

A controlled production release gate evaluation was performed across all software, database, infrastructure, and hardware components of the Parental Control App.

### Core Release Verdict:
- **General Production Release:** **NO-GO / HARD STOP**. Progression to production release (Gate D) is strictly blocked by two critical release blockers:
  1. **Gate B Blocked (DEC-03):** 0 of 75 rows in the controlled Android QA matrix have been run on real hardware or emulators (GAP AND-01).
  2. **Gate C Blocked (DEC-02):** Migrations 1–4 and Edge Functions have not been applied to the hosted Supabase environment, leaving the safe zone client `DELETE` vulnerability active on the live database (GAP HOST-01).
- **Local Implementation Baseline:** **GO / 100% PASS (HERMETIC SCOPE)**. All 150 Deno tests pass; 12 `family-admin` tests pass; 33-file SQL chain passes with 0 errors; negative control caught with Exit Code 3 at line 411; Android JVM tests pass (39/39); Flutter tests pass (408/408).

---

## 2. Four-Gate Release Evaluation Framework

The project enforces an inviolable sequential gating model:

```
[ Gate A: Local Baseline ] ===> CLEARED (100% Pass)
          |
          v
[ Gate B: Android Hardware QA ] ===> BLOCKED (DEC-03 Pending / 75 Rows NOT RUN)
          |
          v
[ Gate C: Hosted Backend Deployment ] ===> BLOCKED (DEC-02 Pending / Migrations 1-4 Unapplied)
          |
          v
[ Gate D: Production Release & Schedulers ] ===> HARD STOP (Prerequisites Gates B & C Unmet)
```

### Detailed Gate Audit:
1. **Gate A — Local Implementation & Test Verification:** **CLEARED (GO)**.
   - 100% offline test suite passage across Deno, local PostgreSQL 16.9, Android JVM, and Flutter.
   - Clean working tree with 0 unstaged modifications.
   - 37 staged files verified; zero secrets exposed.
2. **Gate B — Android Hardware & Mobile Subsystem QA:** **BLOCKED (NO-GO)**.
   - Governed by Owner Ruling #9 and DEC-03.
   - ADB connectivity reported as UNKNOWN. Zero APKs compiled or installed.
   - All 75 hardware QA matrix rows held strictly at `NOT RUN`.
3. **Gate C — Hosted Supabase Backend Hardening:** **BLOCKED (NO-GO)**.
   - Governed by DEC-02.
   - Migrations 1–4 withheld. Edge Functions unapplied.
   - Direct client `DELETE` privilege on `public.safe_zones` remains live on hosted PostgreSQL.
   - Preflight Queries 1–5 prepared and validated.
4. **Gate D — Production Release & Public Distribution:** **BLOCKED (HARD STOP)**.
   - Blocked by negative operational boundaries pending resolution of Gates B and C.

---

## 3. Staged Deployment Playbook (For Future Authorized Execution)

> [!IMPORTANT]
> **GOVERNANCE DIRECTIVE:** The following playbook is **FROZEN ON STANDBY**. No step may be executed until explicit written approval for DEC-02 and DEC-03 is recorded.

### Stage 1: Supabase Dashboard SQL Editor Preflights (Read-Only)
Execute the 5 Preflight Queries in the Supabase Dashboard SQL Editor for project `hhqgreaoqulmfwfwarhc`:

#### Preflight Query 1: WebRTC Duplicate Session Groups Check (DEC-04)
```sql
SELECT session_id, sequence, count(*) AS duplicate_count
FROM public.webrtc_signals
GROUP BY session_id, sequence
HAVING count(*) > 1;
```
- *Pass Criterion:* Exactly `0 rows returned`.
- *Mandatory Abort:* Any rows returned. (Indicates signaling corruption; abort to prevent unique index skip).

#### Preflight Query 2: Function Catalog & Security Definer Integrity
```sql
SELECT 
  n.nspname AS routine_schema,
  p.proname AS routine_name,
  pg_get_function_identity_arguments(p.oid) AS identity_arguments,
  p.prosecdef AS is_security_definer,
  (p.prosrc LIKE '%is_parent_of_family%') AS calls_auth_helper
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'private')
  AND p.proname IN (
    'expire_abandoned_sessions', 'is_parent_of_family', 'run_retention_sweep',
    'delete_safe_zone_audited', 'request_remote_session', 'revoke_device'
  )
ORDER BY n.nspname, p.proname;
```
- *Pass Criterion:* 0 rows for target functions (`expire_abandoned_sessions`, `is_parent_of_family`, etc.); baseline wrapper RPCs have `is_security_definer = true` and `calls_auth_helper = false`.

#### Preflight Query 3: Target Environment Identity & Region Verification
```sql
SELECT 
  current_database() AS db_name,
  current_user AS session_user,
  version() AS pg_version_string,
  (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') AS public_tables_count,
  current_setting('server_version', true) AS server_version;
```
- *Pass Criterion:* `db_name = 'postgres'`, PostgreSQL version contains `17`, `public_tables_count = 19`.

#### Preflight Query 4: Migration Checksum & Baseline Schema Markers
```sql
SELECT 
  (to_regclass('supabase_migrations.schema_migrations') IS NOT NULL) AS has_schema_migrations_table,
  (to_regclass('public.remote_sessions') IS NOT NULL) AS has_core_schema,
  (to_regprocedure('private.record_audit(uuid,uuid,uuid,text,text,text,jsonb)') IS NOT NULL) AS has_functions_schema,
  (to_regclass('public.safe_zones') IS NOT NULL) AS has_safe_zones_table;
```
- *Pass Criterion:* Target migration versions absent from version table; baseline markers all `true`.

#### Preflight Query 5: Authorization & safe_zones Privilege Audit
```sql
-- 5A: Tables with RLS disabled (MUST BE 0)
SELECT c.relname AS table_without_rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity = false;

-- 5B: safe_zones DELETE privileges
SELECT 
  has_table_privilege('anon', 'public.safe_zones', 'DELETE') AS anon_can_delete,
  has_table_privilege('authenticated', 'public.safe_zones', 'DELETE') AS auth_can_delete;
```
- *Pass Criterion:* 5A returns 0 rows; 5B returns `anon = false`, `authenticated = true` (confirming pre-Phase-1 state awaiting Migration 2).

---

### Stage 2: Ordered Database Migration Execution
Apply the 4 migrations sequentially in the Dashboard SQL Editor, verifying SHA-256 hashes:

| Step | Migration File | SHA-256 Checksum | Verification Query |
|---|---|---|---|
| **2.1** | `20261030000100_abandoned_session_sweep.sql` | `aca47b44bb69c5d9ad70a95d52da314faec56217203cd0d49fa90f9085182c7b` | `SELECT to_regprocedure('public.expire_abandoned_sessions(interval)');` |
| **2.2** | `20261030000200_phase1_authorization.sql` | `7558021d6aec4f9a80b16b1d401e03b4b84751ec93ea6c3dd83b9df67b1bfa38` | `SELECT has_table_privilege('authenticated', 'public.safe_zones', 'DELETE');` *(Must return `false`)* |
| **2.3** | `20261030000300_retention_sweep.sql` | `184d8acb33090e4a587de8cad97e21c00688234f452fc50224242ba5cc1870ba` | `SELECT to_regprocedure('public.run_retention_sweep()');` |
| **2.4** | `20261103000100_zone_delete_atomic_rpc.sql` | `a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf` | `SELECT to_regprocedure('public.delete_safe_zone_audited(uuid, uuid)');` |

---

### Stage 3: Edge Function Staged Deployment Sequence

1. **Deploy `account` Function:**
   ```bash
   supabase functions deploy account --project-ref hhqgreaoqulmfwfwarhc --no-verify-jwt=false
   ```
2. **Deploy `device-command` Function:**
   ```bash
   supabase functions deploy device-command --project-ref hhqgreaoqulmfwfwarhc --no-verify-jwt=true
   ```
3. **Deploy `family-admin` Function (STRICT: After Migration 4 is committed):**
   ```bash
   supabase functions deploy family-admin --project-ref hhqgreaoqulmfwfwarhc --no-verify-jwt=false
   ```
4. **Deploy `remote-session` Function:**
   ```bash
   supabase functions deploy remote-session --project-ref hhqgreaoqulmfwfwarhc --no-verify-jwt=false
   ```

---

### Stage 4: Post-Deployment Hosted Verification
1. **Verify Safe Zone Revocation:** Re-run Preflight 5B. Confirm `auth_can_delete` is now `false`.
2. **Smoke Test Safe Zone Deletion:** Issue a test deletion via `family-admin` Edge Function; confirm single atomic `audit_logs` record is created.
3. **Run On-Demand Retention Sweep:** Execute `SELECT public.run_retention_sweep();` and confirm 0 errors.

---

### Stage 5: Android Hardware QA Execution (Gated Under DEC-03)
1. Pair Realme 7 (`RMX2161`, API 31) and Pixel 9a AVD (`emulator-5554`, API 37).
2. Execute the 75-row QA matrix (Subsystems 1–5).
3. Validate all 10 Android privacy invariants (green dot, ongoing notification, 500ms Stop action, 15s watchdog).

---

### Stage 6: Rollback & Quarantine Protocol
- **R1 (Function Bodies):** Restore 4 wrapper function bodies from baseline migrations.
- **R2 (Auth Helper):** Drop `private.is_parent_of_family` ONLY if `pg_proc` proves no function references it.
- **R3 (QUARANTINED):** Strictly forbidden from execution. Re-granting PUBLIC execute on private RPCs, re-granting DELETE on safe_zones, and dropping the unique index is quarantined.
- **R4 (ACL Verification):** Verify `pg_proc.proacl` for zero PUBLIC leakage.

---

## 4. Blast Radius & Failure Mode Matrix

| Failure Mode | Blast Radius | Detection Mechanism | Automated Mitigation |
|---|---|---|---|
| **WebRTC Sequence Duplicates Present** | Replay protection index creation skipped | Preflight Query 1 | Preflight aborts deployment before schema changes |
| **Safe Zone Deletion Non-Atomicity** | Unaudited safe zone deletions | SQL-05 negative control | Atomic RPC rolls back delete if audit fails |
| **Retention Sweep Statement Timeout** | Telemetry accumulation, query abort | Gap SQL-04r monitoring | Batched execution (10k rows) + on-demand runbook |
| **Android Background Process Survives Call** | Battery drain, unauthorized mic access | 45s heartbeat + 15s watchdog | `onDestroy` terminates services and wakelocks |
| **Edge Function Secrets Missing** | 503 error on cron / pairing / TURN | Gateway error mapping (SQL-03) | Fallback defensive headers and error envelopes |

---

## 5. Release Sign-Off Protocol

To advance from **NO-GO** to **GO**, the following stakeholder approvals must be fulfilled:

- [ ] **Owner Sign-Off on DEC-01** (Evidence Durability Policy resolved).
- [ ] **Owner Sign-Off on DEC-02** (Hosted Database Migrations 1–4 approved).
- [ ] **Owner Sign-Off on DEC-03** (Physical/AVD Android Hardware QA approved).
- [ ] **Owner Sign-Off on DEC-05** (Scheduler Policy resolved).
- [ ] **Gate B Cleared** (75/75 Android QA rows executed and passing).
- [ ] **Gate C Cleared** (Migrations 1–4 applied; GAP HOST-01 closed).
- [ ] **Gate D Progression Authorized** (Production release unblocked).

---

## 6. Owner Decision Reconciliation Addendum (Dated 2026-11-04)

**Addendum Timestamp:** `2026-11-04T12:00:00Z`  
**Governing Coordinator ID:** `2cf4d2a8-bc94-44c4-96d3-10edfe3e10ea`  
**Synthesizing Subagent:** Subagent 6: Master Documentation Synthesizer for Phase 9 Owner Decision Reconciliation  
**Target HEAD Commit:** `b12659b9795ba69499483a84750a33897dd7e08a` (`main`)  
**Target Environment:** Supabase Project `hhqgreaoqulmfwfwarhc` (AWS Seoul, Region: `ap-northeast-2`)

### 6.1 Formal Owner Rulings Synthesis (2026-11-04)

Following the forensic audits conducted by Subagents 1 through 5, the project owner rendered formal determinations on DEC-01 and DEC-05, while confirming that DEC-02 and DEC-03 remain pending authorization:

1. **DEC-01: Evidence Durability Policy — Choice B Approved [RESOLVED / ACCEPTED RISK]**
   - *Owner Ruling:* The owner approved **Choice B — Local-only evidence**.
   - *Implementation:* Line 22 of `.gitignore` (`*.log`) remains in effect and unchanged. No `git add -f` was or will be performed.
   - *Evidence Verification:* Subagent 2 verified all 11 Phase 5 test run logs (`docs/evidence/phase5/logs/*.log`, 201,441 bytes, 4,195 lines) bit-for-bit against canonical `docs/evidence/phase5/MANIFEST.md` § 8.
   - *Durability Consequences:* Fresh repository clones will lack raw run logs; only `p5-coord-deno-full3.txt` is tracked in Git commit `b12659b`. The workstation represents an accepted single point of failure. GAP DUR-01 is formally accepted as an operational local-only evidence policy.

2. **DEC-05: Retention Sweep Scheduler Policy — Choice B Approved [RESOLVED / OPERATIONAL MODE]**
   - *Owner Ruling:* The owner approved **Choice B — On-demand execution only**.
   - *Implementation:* All automated scheduling is disabled. No `pg_cron` extension installed; no Supabase scheduled triggers configured; no external cron webhooks active.
   - *Documented Operational Risks:*
     * *Backlog Accumulation:* Telemetry (`location_events`), signaling (`webrtc_signals`), and daily usage (`usage_daily`) accumulate monotonically on disk between manual sweeps.
     * *Single-Transaction Statement Timeout (SQL-04r):* Per Owner Ruling #3, `run_retention_sweep()` executes as a single outer database transaction across all tables and batches. Delayed sweeps result in massive backlogs that risk exceeding Supabase's `statement_timeout` (8–60s), triggering an all-or-nothing rollback (0 rows deleted).
     * *Abandoned WebRTC Sessions:* Without scheduled background sweeps, abandoned WebRTC sessions remain in the database for up to 24 hours, locking child devices from initiating new audio assistance sessions.
     * *Manual Diligence Required:* Operators must manually execute sweeps according to an operational schedule to maintain compliance with declared COPPA/GDPR retention horizons (30 days for location, 7 days for signaling).
   - *Operational Invocation Runbook:*
     * *SQL Editor:* `SELECT public.run_retention_sweep();` and `SELECT public.expire_abandoned_sessions(interval '24 hours');`
     * *HTTP POST:* `POST https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/cron` with `x-cron-secret: $CRON_SECRET` or service-role Bearer token.

3. **DEC-02: Hosted Migration & Function Deployment Readiness — Pending Owner Authorization [STRICTLY PROHIBITED / BLOCKED]**
   - *Owner Ruling:* **PENDING OWNER AUTHORIZATION**. Zero hosted mutations are permitted.
   - *Implementation:* Migrations 1–4 unapplied; Edge Functions (`account`, `family-admin`, `device-command`) undeployed; 5 read-only preflight queries prepared but unexecuted.
   - *Vulnerability Status:* On hosted Supabase `hhqgreaoqulmfwfwarhc`, the baseline schema remains active. `authenticated` users retain direct client `DELETE` privileges on `public.safe_zones`. GAP HOST-01 remains **OPEN as an active P1 Release Blocker**. Gate C remains **BLOCKED**.

4. **DEC-03: Android QA Hardware Execution Readiness — Pending Owner Authorization [STRICTLY PROHIBITED / BLOCKED]**
   - *Owner Ruling:* **PENDING OWNER AUTHORIZATION**. Physical/virtual hardware testing is withheld.
   - *Implementation:* Zero APKs compiled; zero ADB commands executed; all 75 QA matrix rows held strictly at `NOT RUN`. Device connectivity reported strictly as **UNKNOWN**.
   - *Invariant Verification Status:* Ten critical Android privacy and safety invariants (green dot indicator, persistent notification, 500ms Stop action, 15s watchdog) remain unverified on live hardware. GAP AND-01 / GATE-B-01 remains **OPEN as an active P1 Release Blocker**. Gate B remains **BLOCKED**.

---

### 6.2 Reconciled Release Sign-Off Matrix

```markdown
### RECONCILED RELEASE SIGN-OFF MATRIX (2026-11-04)

[X] Owner Sign-Off on DEC-01: RESOLVED — Choice B (Local-Only Evidence) Approved.
[ ] Owner Sign-Off on DEC-02: PENDING OWNER AUTHORIZATION — Zero hosted mutations permitted.
[ ] Owner Sign-Off on DEC-03: PENDING OWNER AUTHORIZATION — Zero hardware QA permitted.
[X] Owner Sign-Off on DEC-05: RESOLVED — Choice B (On-Demand Execution Only) Approved.
[ ] Gate B Cleared: BLOCKED (0 of 75 Android QA rows run on live hardware).
[ ] Gate C Cleared: BLOCKED (Migrations 1-4 unapplied; safe_zones client DELETE live).
[ ] Gate D Progression Authorized: HARD STOP (NO-GO FOR GENERAL RELEASE).
```

---

### 6.3 Definitive Four-Gate Release Readiness Verdict

| Gate | Scope | Status | Severity | Reconciled Posture |
|---|---|:---:|:---:|---|
| **Gate A** | **Local Implementation & Regression Baseline** | **CLEARED** | **Green (100% Pass)** | 150 Deno unit tests pass; 12 `family-admin` tests pass; 33-file SQL regression chain passes with 0 errors; negative control caught with Exit Code 3 at line 411; 39 Android JVM tests pass; 408 Flutter tests pass. Clean working tree with 0 unstaged modifications. |
| **Gate B** | **Android QA Hardware Verification** | **BLOCKED** | **P1 (Release Blocker)** | DEC-03 is PENDING OWNER AUTHORIZATION. All 75 QA matrix rows remain `NOT RUN`. GAP AND-01 / GATE-B-01 is OPEN. Hardware privacy invariants unverified on live devices. |
| **Gate C** | **Hosted Supabase Hardening** | **BLOCKED** | **P1 (Release Blocker)** | DEC-02 is PENDING OWNER AUTHORIZATION. Migrations 1–4 and Edge Functions unapplied to hosted Supabase `hhqgreaoqulmfwfwarhc`. GAP HOST-01 is OPEN. Direct client `DELETE` vulnerability remains live on hosted PostgreSQL. |
| **Gate D** | **General Production Release** | **NO-GO** | **CRITICAL RELEASE STOP** | **HARD STOP**. **Inviolable Release Rule:** General production release is strictly prohibited until Gates B and C have independently passed their authorized verification requirements. Local regression success must not be presented as hosted production verification. |

---

### 6.4 Negative Operational Boundaries & Prohibitions

The following negative operational boundaries are strictly enforced:
1. **NO `git add`, `git commit`, `git push`, `git reset`, `git clean` or staging commands.** (Files are edited/written on disk without staging).
2. **NO modification or tampering with any of the 11 Phase 5 run logs** in `docs/evidence/phase5/logs/`.
3. **NO remote database mutations or Edge Function deployments on hosted Supabase.**
4. **NO APK compilation, ADB execution, or device pairing ceremonies.**
5. **NO `pg_cron` installation or background scheduler activation.**
6. **NO initiation of Phase 10.**

*End of Release Readiness Playbook.*
