# PHASE 5 — deployment readiness

Purpose: tell the owner exactly what is deployable, what must happen in which
order, what must be checked before and after, and what is **not** ready. This
document authorises nothing. Phase 5 applied nothing and deployed nothing (brief
§12, owner ruling #11).

---

## 1. Current deployment state (measured, with its limits)

| Question | Answer | Basis |
|---|---|---|
| Is any Phase 1+ SQL applied to the hosted project? | **No** — production is pre-Phase-1. | last read-only dashboard audit 2026-10-30, `_work/p4-hosted.md`. **Four days old.** |
| Was that re-checked this phase? | **No.** Phase 5 made zero hosted calls, not even reads. | `phase-5-owner-decision-log.md` §11; GAP HOST-02 |
| Is `20261103000100` (SQL-05 RPC) applied? | **No** — it exists only on disposable local databases. | `deployment/manifest.md` §4 |
| Are the Edge Function changes deployed? | **No** — `family-admin`, `account`, `device-command` are working-tree only. | ruling #11 |
| Is anything scheduled? | **No** — no cron/pg_cron anywhere. | ruling / brief §6 |
| Has the code been run against real data? | **No.** Only against the fixtures in `supabase/tests/20_fixtures.sql` and seeded disposable tables. | `MANIFEST.md` §3 |
| Was the Supabase CLI used? | **Never.** The binary exists on this machine and was not invoked; the project rule is dashboard-only for hosted work. | standing project rule |

**Therefore HOST-01 is an open P1 blocker and is not fixed.** No sentence in this
phase may be read as "hosted policies/indexes/grants verified".

---

## 2. Closure path for HOST-01 (owner-executed, in order)

Every step below is a dashboard action; nothing here is automatable by this agent,
and the project rule forbids the CLI.

### 2.0 Pre-flight, read-only, before applying anything

Run these in the SQL Editor and **record the outputs** before touching any file.
They are the only way to know whether the documented guarantees are conditional.

```sql
-- (a) is the replay index already there, or is it pending?
select count(*) as uniq_index_present
from pg_indexes
where schemaname='public' and indexname='webrtc_signals_session_sequence_uniq';

-- (b) the mandatory duplicate pre-check that SQL-06 wording depends on
select count(*) as duplicate_sequence_groups
from (select session_id, sequence from public.webrtc_signals
      group by 1,2 having count(*) > 1) d;

-- (c) which of the four files are already applied?
select p.oid::regprocedure::text as fn
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private')
  and p.proname in ('expire_abandoned_sessions','run_retention_sweep',
                    'is_parent_of_family','delete_safe_zone_audited')
order by 1;

-- (d) the safe-zone delete revocation state (must already be revoked
--     by 20261030000200; if not, Phase 1 was never applied)
select has_table_privilege('authenticated','public.safe_zones','delete') as authed_can_delete;
```

Interpretation table:

| Observation | Meaning | Action |
|---|---|---|
| (a)=0 and (b)=0 | index simply not created yet | apply file 2; it will create the index |
| (b) > 0 | duplicates exist → file 2 will **skip** the index with a NOTICE | **stop**, escalate; deleting rows is a production data deletion and is not authorised in any phase |
| (c) returns none of the four | confirmed pre-Phase-1 | proceed with files 1→4 |
| (c) returns a subset | partial past application | **do not** re-apply blindly; diff what exists against the file first |
| (d) = `true` | the Phase 1 revocation never landed | file 2 is required before the RPC is meaningful |

### 2.1 Apply order

| Step | File | Depends on | Why this position |
|---|---|---|---|
| 1 | `20261030000100_abandoned_session_sweep.sql` | baseline | independent, additive |
| 2 | `20261030000200_phase1_authorization.sql` | baseline | creates `private.is_parent_of_family`, revokes client DELETE on `safe_zones`, conditionally creates the replay index |
| 3 | `20261030000300_retention_sweep.sql` | baseline | independent of 1–2; ships the **new batch shape** adopted under PERF-01a |
| 4 | `20261103000100_zone_delete_atomic_rpc.sql` | **file 2** | its body calls `private.is_parent_of_family`; applying it earlier fails with "function does not exist" |
| 5 | Edge Function redeploy — `family-admin` | **file 4** | the handler now calls the RPC; deploying the function first turns every `delete_zone` into a fail-closed 500 (no unaudited delete, but no delete either) |
| 6 | Edge Function redeploy — `account` | none | the scoped retention payload; the Dart client already tolerates an absent `scope` as `not_reported` (tested), so old client + new function, or new client + old function, both degrade honestly rather than lying |
| 7 | Edge Function redeploy — `device-command` | none | TEST-01 refactor is internal (same HTTP envelope); ordering is not load-bearing |

Verify each file with the queries in `deployment/manifest.md` before moving to the
next, and record file name + SHA-256 + timestamp in `docs/implementation/deployment-log.md`.

### 2.2 Hashes to apply against (measured 2026-11-03 on the uncommitted tree)

| File | SHA-256 (worktree bytes, measured 2026-11-03 at the close of Phase 5) |
|---|---|
| `20261030000100` | `aca47b44bb69c5d9ad70a95d52da314faec56217203cd0d49fa90f9085182c7b` |
| `20261030000200` | `7558021d6aec4f9a80b16b1d401e03b4b84751ec93ea6c3dd83b9df67b1bfa38` |
| `20261030000300` | `184d8acb33090e4a587de8cad97e21c00688234f452fc50224242ba5cc1870ba` (Phase 5 PERF-01a shape + comment provenance; HEAD blob is `dd734fbdcd3f3300c1f3d75f3946d5845d7e959a2aa4c9bc3e015c781abcdf0e`) |
| `20261103000100` | `a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf` (after the EV-02 header-citation fix. The earlier `4fdf1cfb…` is reproducible, not folklore: it is the **staged index blob**, `git show :supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql \| sha256sum`. Absent from HEAD — this file has never been committed.) |

**These are point-in-time numbers on an uncommitted tree, not a contract.** The
applying machine must recompute — which is why `deployment/manifest.md` §0.1 gives
the command form (`sha256sum <file>` for worktree, `git show HEAD:<file> |
sha256sum` for the committed baseline) rather than only the numbers. Two of the
four already moved during this phase for exactly that reason: file 3 because the
approved shape and the corrected SWP-01 comment landed, file 4 because a broken
citation in its own header was fixed. The Phase 1 published values
(`12f20c81…`, `f7062a84…`, `8de3cb38…`) match nothing on this tree and must not be
used.

### 2.3 Post-apply verification (read-only), and what "verified" will then mean

| Check | Query source | Pass condition |
|---|---|---|
| Four functions exist with the right signatures | `manifest.md` §1/§2/§3/§4 | 4 rows |
| RPC grants | `manifest.md` §4 | `proacl = {postgres=X/postgres,service_role=X/postgres}`, `anon`/`authenticated` absent, `prosecdef=t`, pinned `search_path` |
| Client DELETE still revoked | `manifest.md` §2 and §4 | `authenticated_can_delete = false`, `delete_policies = 0` |
| Replay index actually created | `manifest.md` §2 | `unique_sequence_index = 1`; if 0, the SQL-06 wording's condition is **not** satisfied and the contract text must be re-opened |
| Audit append-only intact | `20260101000000_core.sql:543-565` trigger present | unchanged |
| Sweep function idempotent + safe on empty | `tests/72`, `tests/74` (local proof) | hosted equivalent: one manual call, then a second, and the second must delete 0 rows — **only** if the owner chooses to execute the sweep at all |

**Independently verified through read-only ACL and policy checks** is the phrase the
brief uses for closing HOST-01. The table above is exactly that set. Until someone
runs it against the hosted project, HOST-01 stays open regardless of how green the
local chain is.

---

## 3. Rollback posture

| File | Rollback | Notes |
|---|---|---|
| `20261030000100` | documented in `manifest.md` §1: drop function + drop index | rows already closed as `expired`/`abandoned` stay closed — that is history, not corruption |
| `20261030000200` | documented in the file header: re-grant, drop helper, drop index | **this is the R3-adjacent surface.** Owner ruling #6: R3 de-hardening statements are **never sanctioned** and must not be executed, "even to test". Re-granting client DELETE on `safe_zones` is a de-hardening step and stays quarantined. |
| `20261030000300` | drop the function; the added indexes can stay (harmless) | sweeping is opt-in; nothing is scheduled |
| `20261103000100` | `revoke … from service_role; drop function if exists public.delete_safe_zone_audited(uuid, uuid);` (`20261103000100:128-129`) | **roll back the function and the handler together.** Rolling back only the function leaves `family-admin` calling a missing RPC → every `delete_zone` 500s, fail-closed, no unaudited delete. Rolling back only the handler restores the two-transaction window that SQL-05 exists to close. |
| Edge Functions | redeploy the previous bundle | the `family-admin` envelope is unchanged (`{deleted:true}`, 404 `zone_not_found`, 403 `forbidden`, 500 `audit_failed`), so a client that worked before still parses after |

No rollback of any kind was executed in Phase 5 — locally or hosted.

---

## 4. Scheduling (explicitly not configured)

Two different things are often conflated here, so they are separated by measurement.

| Layer | State | Measured where |
|---|---|---|
| **Code path that calls the sweep** | **exists and is wired.** `supabase/functions/cron/index.ts` has an action `expire_abandoned_sessions` (`:84`) and an action `retention_sweep` (`:106-107`) which calls `db.rpc("run_retention_sweep")`, and treats a missing function as a clean skip (`:109-112`) | read directly this phase |
| **Deployment of that Edge Function** | not done by Phase 5 (ruling #11) | `phase-5-owner-decision-log.md` §11 |
| **A hosted scheduler that invokes it** (Supabase Scheduled Jobs / pg_cron / external timer) | **unknown and unverified.** The only hosted observation is the 2026-10-30 read-only audit, which pre-dates this code entirely | GAP HOST-02 |

Phase 5 installed **nothing**: no pg_cron job, no scheduled function, no dashboard
scheduler change, no timer. The correct statement is therefore not "retention is
scheduled but off", but: **the callable code path exists, its deployment is
unapproved, and whether any hosted timer points at it has not been checked since
before Phase 1.** If the owner deploys `cron` and attaches a timer, the first
invocation runs `run_retention_sweep()` with the **unbounded** semantics of the
approved shape (brief §6's "do not install a cron job unless separately authorized"
is exactly the gate that decision).

That ordering matters for risk: bounded execution was **refused** (SQL-04, ruling
#3), so one call is one transaction walking the entire backlog. A first hosted run
against a real backlog is the single riskiest action in this surface, and it needs
a decision about backlog size — via the read-only counts in §2.0 plus a
`select count(*)` per doomed window — **before** it needs a scheduler.

---

## 5. Controlled-QA entry criteria — what QA can do today, with no deployment

| QA activity | Ready? | How |
|---|---|---|
| Static analysis, Dart | **yes** | `./.fvm/flutter_sdk/bin/dart analyze` → 0 issues |
| Flutter unit/widget suites (408) | **yes** | `./.fvm/flutter_sdk/bin/flutter test` |
| PRIV-01 scope disclosure behaviour, including `not_reported` | **yes** | the 11 disclosure cases render the widget tree; no device needed |
| Edge Function unit suites (150) | **yes** | `deno test --allow-read supabase/functions/` |
| SQL/RLS/function/policy suites incl. the new `76` | **yes** | the 33-file chain on a disposable PostgreSQL 16, fresh DB per run (`supabase/tests/README.md`, `MANIFEST.md` §3) |
| Kotlin enforcement rule | **yes, JVM only** | `./gradlew :app:testDebugUnitTest` (39) |
| Anything on a real phone | **no** | GATE-B-01 — owner authorization + devices |
| Anything against the hosted project | **no** | HOST-01 |

Regression-matrix rows QA can reproduce: every row of
`phase-5-regression-matrix.md` §1 and §2 except none — all eight suite rows and both
negative controls are local and reproducible with the commands in
`MANIFEST.md` §2/§7.

---

## 6. Risks if applied as-is (honest, pre-deployment)

1. **First `run_retention_sweep()` against a real hosted backlog is unmeasured.**
   The shape is faster than the previous one *on a local planner with synthetic
   data*; the function is still all-or-nothing in one transaction; the backlog size
   on hosted is unknown because nobody has queried it.
2. **`delete_zone` changes its failure mode before it changes its guarantee.** After
   step 4 + 5, an audit-insert failure surfaces as a 500 with the zone intact.
   Parents will see "the safe zone could not be deleted" in cases that previously
   deleted silently and lost the audit row. That is the intended trade, but it is a
   user-visible change and no device test has seen it (GATE-B-01).
3. **The privacy report gets narrower.** Non-owner parents lose project-wide sweep
   totals; if any support documentation or internal tool reads those fields for a
   non-owner, it will now see them absent. That is PRIV-01 A working as specified.
4. **Deploy-order trap.** Function-then-migration (step 5 before step 4) makes
   every zone delete 500. It fails closed, so it is not a data-integrity risk, but
   it is an availability risk that is entirely self-inflicted by ordering.
5. **Nothing here has been seen by the hosted planner, auth config, or PostgREST
   schema cache.** A `notify` / cache reload after applying the RPC may be needed
   for PostgREST to expose it — that is a dashboard operational step this phase
   neither performed nor verified as necessary.

---

## 7. Approval matrix for the actions this readiness document describes

| Action | Approved by? | Evidence |
|---|---|---|
| Apply any of the four SQL files | **NOT approved** (ruling #11) | `phase-5-owner-decision-log.md` §11 |
| Deploy any Edge Function | **NOT approved** | same |
| Install any scheduler | **NOT approved**, and separately requires its own authorization per brief §6 | same |
| Run the read-only pre-flight queries in §2.0 | not *executed* this phase; needs only the owner's dashboard session, no mutation | HOST-02 |
| Commit Gate A work or the evidence pack | **NOT approved** (ruling #10; conflicts with #12, see CONF-01) | `phase-5-owner-decision-log.md` §10/§12 |
| Build/install an APK on a device | **NOT approved** (ruling #9) | same §9 |
| Execute any R3 / de-hardening rollback | **NEVER approved** (ruling #6) | same §6 |

The only thing Phase 5 hands over is a **tested, ordered, checkable plan** with the
pre-apply and post-apply queries attached to it. Applying it remains the owner's
action.
