# PHASE 3 — Security Hardening & Deployment Readiness: report

**Project:** `D:\parentcontrol_app` · **Branch:** `main` · **Phase 2 HEAD baseline:** `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2`
**Flutter:** FVM 3.44.6 (`.fvm/flutter_sdk`) · **Deno:** 2.9.4 (WinGet link) · **SQL:** disposable repo-local PostgreSQL 16.9 (`.tools/pgsql16`)
**Date:** 2026-11-02 · **Phase 3 controller:** the coordinator session that owned the tree throughout.

---

## 0. Status vocabulary and how to read this report

| Label | Means |
|---|---|
| **PASS** | A command was executed in this environment and its recorded output proves the claim. |
| **PASS (scoped)** | The claim that is labelled is proven; a wider claim in the same gap ID is separately listed as open. |
| **MITIGATED** | Behaviour changed to reduce the exposure; the ideal (atomic) fix is blocked on an owner decision. |
| **BLOCKED** | Not executed because the environment or an owner decision prevents it. No expected result is reported as observed. |
| **NOT RUN** | Deliberately not executed in this phase. |
| **STOPPED** | The brief's own STOP condition fired; analysis delivered, no behaviour changed. |

Severity bands used (unchanged from Phase 1/2): P1 = wrong data or a live authorization exposure; P2 = honest but
misleading, or an unproven claim; P3 = hygiene. **No Phase 3 claim rests on a hosted system.** Every hosted statement is
either a read-only dashboard observation (§7) or explicitly labelled as such.

Sub-agent note (disclosure, not a finding): the phase was opened with a 7-agent fan-out. Several agents died on
credit/queue failures, so the coordinator completed or re-executed their workstreams directly. Everything below was
re-verified by the coordinator against the tree and against executed commands; where an agent's note survived, it is
cited and was re-checked (two citation-drift defects were found and fixed that way — `_work/p3-privacy-decisions.md`
line references, and `_work/p3-followups.md` WORD-01/UX-01 claims).

**Final proofread pass (after the last suite run).** Two read-only verification agents audited these deliverables
line-by-line against the tree and reported 20 defects: stale `file:line` ranges inside section 8 of
`20261030000200_phase1_authorization.sql` (the file grew during Phase 3, so pre-Phase-3 numbers no longer pointed at
the duplicate guard / skip-notice / index assertion), the matching `tests/70`/`tests/71` assertion ranges, an
`_work/p3-async-guards.md §7` reference to a section that does not exist, `tests/74` tripwires attributed to §3
instead of §4e/§4f, a `device-command` wiring site described as the `ack` path when it is the `create`/enqueue path,
a marker list that showed seven of the eight `AUTHORIZATION_MARKERS`, SQL-04 timings with the selectivities swapped
(`43 %` is `webrtc_signals`; the `audit_logs` case is `12.4 %`) and the `audit_logs` batch-SELECT pair attributed to
`webrtc_signals`, the in-file privilege matrix cited as `30-47` instead of `36-47`, a doc-comment range `3-5` → `3-6`,
a self-referential deliverable hash, the `19 public tables` number attributed to a log that never prints it,
`lifecycle_test.ts:138` described as injecting a fake `db` when it injects a fake `rpc`, a
`phase-2-governance.md:106` "contradiction" that is actually an uncorrected Phase 2 claim, DOC-01 listed as both open
and closed inside one file, and two Phase 1/2 citations that Phase 3 itself invalidated (filed as **DOC-03**).
**All twenty are corrected in these four files and in the `_work/` notes they cite. None of them was a code, migration
or test defect**, so the suites were **not** re-run for a docs-only delta and no re-run is claimed — see the
"Delivered tree identity" row in §2 for the resulting digest pair.

---

## 1. Exact starting Git state (measured at preflight, 2026-11-02)

| Item | Value | Command |
|---|---|---|
| Branch | `main` | `git branch --show-current` |
| HEAD | `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2` | `git rev-parse HEAD` |
| `git status --short` | 47 entries — 5 `A`, 4 `AM`, 38 `M`; **no untracked files** | `git status --short` |
| `git diff HEAD --stat` | **47 files changed, +2660 / −154** | worktree vs HEAD |
| `git diff --cached --stat` | 47 files changed, +2645 / −154 | index vs HEAD |
| `git diff --stat` | 4 files changed, +28 / −13 | the four Phase 2 docs, re-edited after the index caught up |
| Phase 2 baseline | Phase 2's own work is **uncommitted** — HEAD predates it, so `git diff HEAD` mixes Phase 2 and Phase 3 content | `docs/implementation/phase-2-report.md:32-36` |

Preflight reads required by §1 of the brief were performed before any edit: `phase-2-report.md`,
`phase-2-regression-matrix.md`, `phase-2-open-gaps.md`, `phase-2-governance.md`, `api-contract.md`,
`_work/coordinator-contract.md`.

Preservation: no `git reset` / `clean` / `stash` / `checkout` / `restore` was run at any point in the phase, and no
`git add`, commit, branch or push was run by the coordinator. All 47 starting changes are still present (§2).

## 2. Exact ending Git state (measured after the last edit, 2026-11-02)

| Item | Value |
|---|---|
| Branch / HEAD | `main` @ `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2` — **identical to start; no commit, no branch, no push** |
| `git status --short` | **80 entries** — 22 `A`, 3 `AM`, 48 `M` (47 `M ` staged-clean + 1 ` M` worktree-only), 7 `??` |
| `git diff HEAD --stat` | **73 files changed, +7584 / −221** (measured with the same command at the delivery re-check below) |
| `git diff --cached --stat` | 72 files changed, +7545 / −221 (the index lags the worktree — the IDE stages, later edits land unstaged) |
| `git diff --stat` | 4 files changed, +68 / −29 |
| Re-verified at delivery | After the final docs edit, `git rev-parse HEAD`, `git branch --show-current`, the entry count (80), the staged/unstaged file splits (73 / 72 / 4) and the `git diff HEAD` digest were all re-measured: HEAD, branch, entry count and the `5c6c364f…` digest are unchanged, and the only movement in the line counts is markdown in `_work/p3-followups.md` and the four §10 deliverables (+7581 → +7584 tracked, +54 → +68 unstaged). No source, migration, test or config line changed. |
| Untracked (7) | Present at the final verification run: `docs/implementation/_work/p3-sql-rollback.md` `f3452ea7…3700`, `docs/implementation/_work/p3-sql-performance.md` `0ce1ea7e…b078`, `supabase/tests/74_sweep_indexes_and_repeatability.sql` `9474fb46…23cd0`. Written **after** that run: the four §10 deliverables `phase-3-report.md`, `phase-3-regression-matrix.md`, `phase-3-open-gaps.md`, `phase-3-security-decisions.md` — documentation only, so they are deliberately **not** quoted with a pinned hash (a file cannot pin the hash of the page that records it, and these files were still being corrected when this table was written). |
| Tested tree identity | `git diff HEAD` content digest at the final verification run (17:04, `.tools/p3-final-*.log`): `be71eb55f929ad8cd566d7cc17e826bee77e57173a0fc3cbf1d1a596aae5ee6b` + the three untracked files above. |
| Delivered tree identity | `git diff HEAD` digest after the post-verification proofread: `5c6c364f9959a638066cbf94b6905d3a95ade365b912607e16ff1eb5ed57b01a`. The only tracked file that moved between the two is `docs/implementation/_work/p3-followups.md` (markdown citation fixes) — verified by mtime: no source, migration, test or config file is newer than the 17:03–17:04 suite run (`supabase/tests/README.md` 16:26 is the newest tracked non-docs edit). **The suites were not re-run for a docs-only delta, and no re-run is claimed.** |
| The full 80-entry list | `.tools/p3-end-status.txt` (gitignored scratch capture of `git status --short`) |

Attribution caveat, stated rather than smoothed over: because HEAD predates Phase 2, the entry-count delta (47 → 80)
cannot be reconciled path-for-path from git alone — Phase 2's 47 paths were never enumerated in a recorded snapshot at
Phase 3 preflight (only their counts). Path-level attribution in this report therefore comes from the workstream notes
and from the diff contents (every Phase 3 edit is marked in-source with `SQL-0n` / `ENF-01` / `UI-02` /
`Phase 3` comments), and the §3 lists are the authoritative Phase 3 file set.

---

## 3. Files changed, by workstream

### P3-A1 — SQL-01 rollback security (`_work/p3-sql-rollback.md`)

| Path | Change |
|---|---|
| `supabase/migrations/20261030000200_phase1_authorization.sql` | Rollback section rewritten: measured privilege matrix as a comment (lines 36-47), the two facts that decide its shape (49-60), supported safe rollback **R1–R2, R4** (62-145), the unsafe de-hardening set quarantined as **R3 — NOT RUN** (115-131), and the reversibility analysis (147-166). Forward DDL unchanged. |
| `supabase/tests/71_phase1_rollback_privileges.sql` | **new** (576 lines) — in-chain rollback/re-apply test: phases `1_forward`, `2a_after_unsafe_rollback`, `3_rollback`, `4_reforward` + GUARD, a negative control that proves the unsafe rollback leaks 5 privilege cells, and `tests.assert_raises(…, 'P0001', 'rollback halted')` for the R2 guard. |
| `supabase/tests/README.md` | Chain gains `71_…` (immediately after `70_…`) and `74_…` (after `72_…`), with the ordering rationale. |
| `.tools/p3a-matrix-*.txt` (5 captures, gitignored) | Raw `proacl` / `relacl` / `pg_policies` rows per state: BEFORE 48, AFTER_FORWARD 50, AFTER_ROLLBACK_ORIG 48, AFTER_ROLLBACK_FIXED 47, AFTER_ROLLBACK_SEDEXTRACT 47. |

### P3-A2 — SQL-02 + SQL-04 performance (`_work/p3-sql-performance.md`)

| Path | Change |
|---|---|
| `supabase/migrations/20261030000100_abandoned_session_sweep.sql` | `remote_sessions_abandoned_idx` re-keyed to the expression the sweep actually compares — `COALESCE(accepted_at, requested_at)` — with the same status predicate, plus a rebuild guard that drops only a plain-column build (`pg_index.indexprs IS NULL`). |
| `supabase/migrations/20261030000300_retention_sweep.sql` | `webrtc_signals_created_idx` + `audit_logs_created_idx` created, matching `drop index` rollback lines, and the bounded-execution analysis recorded in-file (Option A `PROCEDURE` + `COMMIT` → owner approval; Option B capped overload → rejected because it would make `rpc('run_retention_sweep')` ambiguous, PGRST202). |
| `supabase/tests/74_sweep_indexes_and_repeatability.sql` | **new** (untracked) — index shape assertions, repeated-execution/empty-dataset cases, and two tripwires that fail if someone ships `commit` inside the function or silently changes the 10 000-row batch. |

### P3-B — SQL-03 authorization error mapping

| Path | Change |
|---|---|
| `supabase/functions/_shared/error_mapping.ts` | **new** — single source of truth: `isAuthorizationError`, `authorizationReason`, `authorizationError`, `denyAuthorization`; 42501 + message markers, with integrity-marker carve-out so append-only faults stay 500. Injected logger, no Supabase client, no `Deno.serve`. |
| `supabase/functions/_shared/error_mapping_test.ts` | **new** — 13 tests, incl. the four caller scenarios through the real envelope, and cross-handler agreement. |
| `supabase/functions/device-policy/index.ts` | `mapPolicyRpcError` now takes the error object; `denyAuthorization(error, "apply_policy")` before the generic 500. |
| `supabase/functions/device-command/index.ts` | same, for `apply_policy_version` on the **create/enqueue** path (`mapApplyPolicyRpcError` `:57`, used at `:143` inside `case "create"`). The `ack` path (`:250`) calls no authorization-raising RPC and gained no mapping. |
| `supabase/functions/pairing/index.ts` | 5 mapped sites: `respond_pairing_request`, `create_pairing_invite`, `create_pairing_request`, `unlink_child`, and the shared `mapResponseRpcError`. |

### P3-C — SQL-05 delete/audit atomicity (`_work/p3-audit-atomicity.md`)

| Path | Change |
|---|---|
| `supabase/functions/family-admin/delete_zone_atomicity.ts` | **new** — post-delete decision module: 3 audit attempts with injectable backoff, compensating restore of the exact pre-delete row, and a loud `zone_delete_unaudited:<code>:<zone id>` when even the restore fails. |
| `supabase/functions/family-admin/delete_zone_atomicity_test.ts` | **new** — 8 tests: 6 `[injected]` fault-injection cases, 2 `[source-level]` call-site ordering pins. |
| `supabase/functions/family-admin/index.ts` | `delete_zone` pre-read widened to the full row snapshot; module wired between `ensureNoError(deleted)` and the success response; both failure throws precede `return ok`. |
| `docs/implementation/proposals/phase3-safe-zone-audit-atomicity.sql` | **new** — the service-role-only `public.delete_safe_zone_audited()` RPC. **A proposal, not a migration: not in the applied chain, not in `supabase/tests/README.md`.** |

### P3-D — ENF-01 enforcement report correlation + WORD-01 (`_work/p3-enforcement-correlation.md`)

| Path | Change |
|---|---|
| `lib/data/models/policy_enforcement.dart` | `PolicyReportCorrelation` enum (`matched` / `mismatched` / `uncorrelated`), correlation computed from `payload.policy_id` only, `provesEnforcement` gate, and the WORD-01 doc-comment softening (`:3-6`). |
| `lib/features/app_restrictions/app_restrictions_controller.dart` | Reports are selected per displayed policy by id; uncorrelated reports kept visible but non-proving; generation guard `_reportRequest` so a superseded response cannot assign. |
| `lib/features/app_restrictions/app_restrictions_page.dart` | Uncorrelated banner, no green badge without proof, and the WORD-01 header at `:373` — `'Apps the device could not confirm as suspended'`. |
| 3 new tests | `policy_report_correlation_test.dart` (model), `enforcement_report_correlation_controller_test.dart` (controller incl. the race), `enforcement_correlation_page_test.dart` (UI incl. pinned WORD-01 wording at `:168`, `:207`). |
| `test/features/app_restrictions/app_restrictions_page_test.dart` | one assertion updated to the new header string (wording only, count `(2)` still asserted). |

### P3-E — UI-02 async guards (`_work/p3-async-guards.md`)

| Path | Change |
|---|---|
| `lib/features/dashboard/dashboard_controller.dart` | generation counter `_generation`, `_runningFamilyId`, `_owns()`; entry `_isClosed` guard + same-family fold; **every `catch` arm and the whole `finally` now behind `_owns(generation)`**; reload preserved on the error path. |
| `lib/features/devices/devices_controller.dart` | same shape (deliberately duplicated, not abstracted — the brief's ownership map forbids a new shared module). |
| `test/features/dashboard/dashboard_async_guard_test.dart`, `test/features/devices/devices_async_guard_test.dart` | **new** — 5 deterministic scenarios each: superseded success, superseded failure (the UI-02 core case, fails on pre-fix code), family-left-during-fetch, disposal during fetch (write counter asserted `== 0`), coalesced refreshes. |
| — path correction | The brief names `lib/features/dashboard/controllers/dashboard_controller.dart` and `lib/features/devices/controllers/devices_controller.dart`; those directories do not exist. The real files are one level up. Deviation recorded in `_work/p3-async-guards.md` §0. |

### P3-F — PRIV-01 / GOV-02 / follow-up triage (analysis only, **no code changed**)

`docs/implementation/_work/p3-privacy-decisions.md` (435 lines) and `docs/implementation/_work/p3-followups.md`
(239 lines). These are the source for §5 and §6 below.

---

## 4. Authoritative verification (coordinator-owned, executed 2026-11-02 after every edit)

| Suite | Exact command | Exit | Result | Evidence |
|---|---|---|---|---|
| Dart analyzer | `./.fvm/flutter_sdk/bin/dart analyze` | **0** | `Analyzing parentcontrol_app...` / **No issues found!** | `.tools/p3-final-analyze.log` |
| Deno (all functions) | `deno test --allow-read supabase/functions/` (`/c/Users/ASUS/AppData/Local/Microsoft/WinGet/Links/deno`) | **0** | **`ok \| 109 passed \| 0 failed`** | `.tools/p3-final-deno.log` |
| Deno (SQL-03) | `deno test --allow-read supabase/functions/_shared/error_mapping_test.ts` | 0 | `ok \| 13 passed \| 0 failed` | same session |
| Deno (SQL-05 + Phase 1) | `deno test --allow-read supabase/functions/family-admin` | 0 | `ok \| 12 passed \| 0 failed` | same session |
| Deno (wiring regression) | `deno test --allow-read supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 5 passed \| 0 failed` | same session |
| Flutter (full suite) | `./.fvm/flutter_sdk/bin/flutter test` | **0** | **`+390: All tests passed!`** | `.tools/p3-final-flutter.log` |
| Flutter (Phase 3 new files) | `flutter test` over the 5 new guard/correlation files | 0 | **`+35: All tests passed!`** | same session — `355 + 35 = 390`, no existing test removed |
| SQL chain (30 `-f` files) | the full `psql -v ON_ERROR_STOP=1 -f …` chain from `supabase/tests/README.md:32-63` against a fresh DB `p3_final_chain` | **0** | 567-line log, **0 `ASSERTION FAILED`, 0 `ERROR` lines**, `PHASE 1 ROLLBACK PRIVILEGE TESTS PASSED` present. The chain's own validity criterion (`README.md:104`) is that the database ends with **19 public tables**; that count was read live after the run and the database was dropped during cleanup, so it is an **at-run observation with no retained artifact** — the log itself does not print it. | `.tools/p3-final-chain.log` |

Counts moved as expected and are stated as measurements, not assumptions: Deno **88 → 109** (+13 SQL-03, +8 SQL-05);
Flutter **+355 → +390** (+35). Nothing was deleted or weakened to get there.

**Evidence provenance, stated because the brief requires it:** the `.tools/p3-final-*.log` files hold each command's
redirected stdout/stderr only — the `CHAIN_EXIT=0` / `EXIT=0` lines were printed by the wrapper **outside** the
redirect, so they appear in the invocation output at run time and not inside the log files. The logs corroborate the
success strings (`No issues found!`, `ok | 109 passed | 0 failed`, `+390: All tests passed!`, the suite `…PASSED`
notices) and contain zero `ERROR` / `ASSERTION FAILED` lines; the numeric exit codes are at-run observations. The
digest recipe is `git diff HEAD 2>/dev/null | sha256sum` over tracked content only — untracked files are excluded by
construction, which is why the three untracked inputs are hashed individually.

Tested tree identity for all seven rows above: `main` @ `8da1de7` + the §2 worktree digest. Cluster: repo-local
PostgreSQL 16.9 on port 55441, trust auth, fresh `createdb -T template0`. **No test touched hosted data.**

**Not run:** `flutter build` (coordinator-owned, and no workstream requested it this phase); Gradle/JVM tests (§6);
any Supabase CLI command (see §7); the SQL-05 atomic RPC (proposal only).

## 5. What each gap's status actually is

| ID | Status | What is proven | What is *not* proven |
|---|---|---|---|
| SQL-01 | **PASS (safe path) + owner decision open (R3)** | The unsafe rollback really did restore `PUBLIC=EXECUTE`, `authenticated` DELETE, `safe_zones_delete_parent` and drop the unique index — measured, 5 cells. The shipped rollback keeps all hardening and is asserted in-chain (71). | That an operator will not paste R3. R3 is the true revert and is deliberately **not run**; it is an owner-approved de-hardening. |
| SQL-02 | **PASS (scoped)** | EXPLAIN A/B on identical data (`in_index=19600`, `abandoned_24h=1512`): cursor query 15.134 → **7.377 ms**, index TIDs 19 600 → 1 912, idle sweep 11.732 → **0.039 ms**. | Any end-to-end RPC speedup. Repeats: PLAIN 595/625/674 ms vs EXPR 597/609/602 ms — the single-run delta was noise. The win is the read/idle path. |
| SQL-03 | **PASS** | 42501 / `not_family_parent` → `403 forbidden` with fixed text in all four handlers; integrity raises stay 500; authorization never becomes success. 13 tests. | Hosted behaviour — the handlers are undeployed. |
| SQL-04 | **MITIGATED / partially PASS** | Selection-side wins measured (`_work/p3-sql-performance.md` §2): `audit_logs` batch SELECT 69.670 → **4.639 ms** and its shipped DELETE 169.262 → **149.615 ms** at the **12.4 %** backlog (25 000/200 800); at **0.23 %** that DELETE is **6.936 ms** because the plan flips to the PK index. `webrtc_signals` is the measured **limit**, not a win: batch SELECT 5.401 → 5.836 ms and DELETE 66.346 → 67.434 ms at **43 %** (60 000/140 000) — the index is not adopted. Repeatability + empty-dataset pinned in `tests/74` §4. | Bounded execution: `run_retention_sweep` is still **one transaction** — one call for a 134 600-row backlog measured **1 150.966 ms** with **no committed partial progress**. That needs the `PROCEDURE`+`COMMIT` owner decision. Also **PERF-01**: the delete target still `Seq Scan`s `webrtc_signals` (26.285 ms at 1.48 %). |
| SQL-05 | **MITIGATED; atomicity STOPPED for owner approval** | The failure window is documented to the line; no silent unaudited delete remains — retry, compensate, else fail loudly. 8 tests. | True cross-transaction atomicity (needs the proposed RPC + a real cluster), and real PostgREST commit-vs-lost-response faults. Residual: audit retry can **duplicate** a `zone_deleted` row. |
| ENF-01 | **PASS** | A report can only prove the policy its own `payload.policy_id` names; mismatched never shows; missing/empty is labelled uncorrelated and non-proving; late/new races generation-guarded. 3 files of tests. | Device-side behaviour (Kotlin blocked) and hosted ack payloads. |
| UI-02 | **PASS** | Superseded failure no longer paints the newest family as an error; disposed controllers write nothing; reloads preserved. 10 new scenarios. | The residual in `_work/p3-enforcement-correlation.md` §7 (`:117-122`); `_work/p3-async-guards.md` ends at §6 and records no such section: version-number assignment order can still briefly show an older version (report state is guarded, so no false proof). |
| PRIV-01 | **STOPPED — awaiting owner** | Both options fully specified with exact targets, contract deltas, backward compatibility and required tests; plus the finding that the response also leaks the **project-wide** sweep totals, which raises severity beyond what was filed. | No behaviour changed. Nothing implemented. |
| GOV-02 / D1 | **Memo prepared — awaiting owner signature** | The `ended_by=NULL` + `ended_reason='abandoned'` constraint, all consumers keyed on the pair, and the four alternatives with pre-deploy vs post-deploy cost. | Ratification. The coordinator's Phase 1 ratification is not the owner's. |

## 6. Kotlin limitations (honest state)

* **KOT-01 — `NOT EXECUTED` / `BLOCKED — not attempted by this workstream`.** The five files under
  `android/app/src/test/kotlin/**` (`AudioAssistanceRecreationTest`, `AudioAssistanceSessionWatchdogTest`,
  `AudioAssistanceStartGateTest`, `AudioAssistanceStopIdempotenceTest`, `policy/PolicyEvaluatorTest`) were **not run in
  Phase 3**. No JVM test is claimed as passing.
* Recorded cause (verified, imprecise in older docs): Kotlin incremental cache / plugin test-task configuration across
  two roots — `C:\Users\ASUS\AppData\Local\Pub\Cache` vs `D:\parentcontrol_app\android`
  (`docs/bug-report.md:196-200`). Mitigation is already committed: `android/gradle.properties:9` `kotlin.incremental=false`.
* **Precise unblock, this workstation, no new machine:**
  `cd /d/parentcontrol_app/android && ./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks`
  (recorded as `BUILD SUCCESSFUL` on 2026-10-26..28 for `:app:` only, `docs/verification-report.md:130-142`; a plain
  all-modules `testDebugUnitTest` still fails while configuring plugin test tasks). It was not run here because a Gradle
  run rewrites `build/**` that other workstreams may hold, and Phase 3's Kotlin remit was ownership-restricted.
* **KOT-02 — deferred, unchanged.** `PolicyApplier.kt:229-233` and `GuardianService.kt:668-674` still duplicate
  `enforcementMode()`, and both still agree by inspection. The prerequisite `PolicyApplierTest.kt` **does not exist** —
  contrary to the "coverage first" wording in `phase-2-governance.md:106`. Correct order: KOT-01 unblock → add the
  mapping test → collapse the duplicate.
* No Kotlin source was modified in Phase 3. `android/**` is byte-identical to HEAD.

## 7. Hosted Supabase: read-only inspection, and the confirmation nothing was applied

**Method:** only the Supabase dashboard UI (project `parent-control-prod`, ref `hhqgreaoqulmfwfwarhc`). The Supabase CLI
exists on this workstation at `C:/Users/ASUS/AppData/Roaming/npm/supabase` and was **never invoked** — no
`supabase db/migration/functions/secrets/start/links` command was run in this phase. No hosted mutation, no deployment,
no secret or Auth change, no cron job created. SQL-04's explicit "do not create a cron schedule" was honored:
`/integrations/cron/jobs` still reports **"Cron is not installed."**

Point-in-time reads, 2026-11-02:

| Surface | Observed |
|---|---|
| `/functions` | 9 Edge Functions: auth-bootstrap, cron, device-command, device-policy, device-register, device-telemetry, family-admin, pairing, remote-session. **No `account` function** (updated 6–7 days earlier). |
| `/database/functions` (schema `public`) | 14 functions. **Neither `expire_abandoned_sessions` nor `run_retention_sweep`.** |
| `/integrations/cron/jobs` | `Cron is not installed.` |
| Read-only catalog probe (dashboard SQL editor, `SELECT`s over `pg_*` only) | `1_public_table_count` = the 19 base tables · `2_phase1_public_fns` = **NONE** · `3_is_parent_of_family_any_schema` = **ABSENT** · `4_private_schema` = `private` exists · `5_private_guard_acl` = **function-absent** · `6_phase1_indexes` = **NONE** · `7_safe_zones_policies` = `safe_zones_delete_parent, safe_zones_insert_parent, safe_zones_select_family, safe_zones_update_parent` · `8_safe_zones_relacl` = `postgres=arwdDxtm/postgres, service_role=arwdDxtm/postgres, authenticated=rd/postgres` · `9_audit_logs_triggers` = `audit_logs_append_only` · `10_devices_installation_id` = `installation_id type=text` · `11_migration_table` = **ABSENT** · `12_sub_schemas` = only `private` of (`edge_functions`, `supabase_functions`, `private`, `supabase_migrations`) |

**Reading.** The hosted database is at the pre-Phase-1 schema plus the earlier committed stages
(`audit_logs_append_only` and `devices.installation_id` exist; nothing from `20261030000100/200/300` exists). Two live,
currently-reachable consequences follow directly from rows 7–8: the hosted `safe_zones` still grants **DELETE to
`authenticated`**, and the `safe_zones_delete_parent` policy (the `is_family_parent()` form Phase 1 removed) is still
present — i.e. the exposure Phase 1 closed is **still open in production** because the migration was never applied.
`11_migration_table ABSENT` corroborates that no CLI-tracked migration history exists for this project.

**Explicit confirmation required by §10 of the brief: nothing was deployed or applied to hosted Supabase in Phase 3.**
No migration was pushed, no function uploaded, no secret set, no Auth setting touched, no row written, no cron job
created. Every state change in this report lives in the local working tree and in disposable local clusters only.

Residual UI artifact, disclosed: the dashboard SQL editor now holds additional **unsaved "Untitled query" tabs**
(browser-local drafts). Two attempts to close the tab I created did not reduce the tab count; the editor content was
cleared instead. Saving a snippet, deleting a saved query, or any dashboard write was never attempted.

## 8. Environment cleanup (performed, verified)

All Phase 3 databases were synthetic fixtures created by this phase.

| Action | Result |
|---|---|
| `dropdb` on port 55441 | 12 databases dropped: `p3_final_chain`, `p3a_final`, `p3a_final2`, `p3a_full1`, `p3a_full2`, `p3a_it`, `p3a_m1`, `p3a_m2`, `p3a_m3`, `p3a_m4`, `p3a_tpl`, `p3a_v1` — `pg_database` then shows only `postgres`, `template0`, `template1` |
| `dropdb` on port 55442 | `p3b_perf` dropped |
| `pg_ctl -D .tools/pgdata_p3a -m fast stop` · `pg_ctl -D .tools/pgdata_p3b -m fast stop` | `server stopped` ×2 |
| Verification | `pg_isready -h 127.0.0.1 -p 55441` → **no response** (exit 2); same for 55442; `netstat` shows **no listener on 55441/55442** |
| Kept on purpose | The two data directories (57 MB + 392 MB, `.tools/pgdata_p3a`, `.tools/pgdata_p3b`) and all `.tools/*.log` / `.tools/*.txt` evidence captures — gitignored, and deleting them would destroy the evidence trail. Re-create-from-zero is documented in `_work/p3-sql-rollback.md` §2 if a fresh cluster is ever needed. |
| Untouched by all of the above | The workstation's own Postgres, the hosted project, and the working tree (`git status` entry count unchanged by the cleanup). |

## 9. Deployment readiness (what Phase 3 changed about the gate)

Phase 3 did not make the tree deployable end-to-end — three decisions are the owner's (§10). What it did change:

1. **The rollback is no longer a booby trap.** Applying `20261030000200` and later rolling it back by copy-paste now
   keeps every hardening (R1/R2/R4), and the in-chain test `71` fails if it does not. A true revert is only reachable
   through the explicitly-labelled R3 de-hardening, which requires an owner decision.
2. **Two deployment pre-checks became mandatory, both new:**
   * the signaling duplicate pre-check (`20261030000200_phase1_authorization.sql:478-486`) is now known to be **load
     bearing** — with duplicates present the index build is skipped quietly (`:492`) while `tests/71:194-197` asserts it exists,
     so the suite goes red after a green apply (`_work/p3-followups.md` §3);
   * `run_retention_sweep` has no cron and no bounded execution: the first hosted call on a backlog is one long
     transaction (measured 1 151 ms for 134 600 rows). Deploy the sweep only after the `PROCEDURE`+`COMMIT` decision.
3. **Two of the three "closed" Phase 1/2 claims are still not true in production** because nothing is applied
   (`account` undeployed, migrations `20261030000100/200/300` unapplied). §7 is the evidence.
4. Chain order is documented and green: `supabase/tests/README.md` now runs 30 `-f` files including `71` and `74`,
   exit 0 on a fresh database.

## 10. Remaining owner approvals (nothing below was self-approved)

| # | Decision | Status | Where |
|---|---|---|---|
| 1 | **PRIV-01** — Option A (child-scoped counts + `scope` field, redact global `last_sweep`) vs Option B (family-wide, disclosed) vs the middle path (parent-only gate). Recommendation is **A, scoped**; no behaviour changed. | **OPEN — STOPPED as instructed** | `_work/p3-privacy-decisions.md` §1.2–§1.6 |
| 2 | **GOV-02 / D1** — ratify `ended_by = NULL` + `ended_reason = 'abandoned'` as the system marker, or pick Alternative 1–4 (Alternative 4 = enforce the pair with a CHECK/trigger, no column change). | **OPEN — memo awaits signature** | `_work/p3-privacy-decisions.md` §2.1–§2.7 |
| 3 | **SQL-05 atomicity** — approve the fourth migration + `public.delete_safe_zone_audited()` RPC (`docs/implementation/proposals/phase3-safe-zone-audit-atomicity.sql`) or accept the shipped mitigation as the guarantee. | **OPEN — new RPC/migration outside approved scope** | `_work/p3-audit-atomicity.md` §2, §7 |
| 4 | **SQL-04 bounded execution** — approve `create procedure public.run_retention_sweep(p_max_rows)` with `COMMIT` (changes the RPC surface and the sweep's durability), or keep one-transaction behaviour and accept PERF-01. | **OPEN — no cron created** | `_work/p3-sql-performance.md` §3, `_work/p3-followups.md` §8 |
| 5 | **SQL-01 R3** — decide whether a full de-hardening revert is ever sanctioned, and who may run it. | **OPEN (R3 not run)** | `_work/p3-sql-rollback.md` §4 |
| 6 | **SQL-06 re-scope** — approve correcting `api-contract.md:223` (the unique index is imported-duplicate hygiene, **not** replay protection) and re-labelling the gap as a pre-apply pre-check. | **OPEN — contract wording** | `_work/p3-followups.md` §3 |
| 7 | **TEST-01** — approve the export-first refactor of four handlers (cross-ownership) so wiring proofs become executions. | **OPEN — scheduling/ownership call** | `_work/p3-followups.md` §2 |
| 8 | **Commit** — Phase 2 + Phase 3 work is still uncommitted (`main` @ `8da1de7`, 80 entries). No `git add`, commit, branch or push was performed. | **OPEN — needs approval** | §1, §2 |

## 11. §11 completion gate — self-assessment against the brief

| Gate item | Verdict | Basis |
|---|---|---|
| Unsafe rollback instructions resolved or explicitly blocked | **MET** | Safe R1/R2/R4 shipped + asserted in `tests/71`; R3 quarantined as owner-approved de-hardening |
| Authorization errors mapped correctly | **MET** | SQL-03 shipped in 4 handlers, 13 Deno tests, suite 109/0 |
| Retention sweep access paths evaluated and proven | **MET (read/selection side), bounded execution BLOCKED on owner** | EXPLAIN A/B evidence; `PROCEDURE` decision #4; PERF-01 filed |
| Safe Zone audit consistency has a documented guarantee | **MET as documentation; atomicity MITIGATED** | `_work/p3-audit-atomicity.md` §1/§3/§5 + decision #3 |
| Enforcement reports cannot falsely prove the wrong policy | **MET** | ENF-01 id-only correlation + generation guard, 3 new test files |
| Stale dashboard requests cannot overwrite newer state | **MET** | UI-02 `_owns()` over every catch/finally write, 10 new scenarios |
| Child retention scope has an explicit owner decision | **NOT MET — correctly stopped** | PRIV-01 decision #1 outstanding; brief forbade choosing |
| All changes have regression coverage | **MET for shipped code** | +21 Deno, +35 Flutter, +2 SQL files in-chain; analysis-only workstreams have no code to cover |
| Exact final tree documented | **MET** | §2 + `.tools/p3-end-status.txt`, with the attribution caveat stated |
| No hosted mutation or deployment | **MET** | §7; CLI never invoked; cron absent; catalog probe shows pre-Phase-1 state |

**Phase 3 is therefore complete except for the owner decisions in §10.** Per the brief, nothing is deployed, committed,
pushed, and Phase 4 is **not** started. Awaiting owner review.
