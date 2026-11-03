# PHASE 4 — Deployment Gate Closure & Android Validation Readiness: report

Executed 2026-11-03 on branch `main`. Companion documents: `phase-4-regression-matrix.md`,
`phase-4-open-gaps.md`, `phase-4-owner-approval-register.md`, `phase-4-android-validation-plan.md`.

**This was not a deployment phase.** No migration was applied anywhere, no Edge Function was deployed,
no Supabase setting was changed, no cron job was installed, no production data was read for modification
or written, and no APK was built or installed. The hosted project was touched **read-only**, through the
dashboard SQL editor with `SELECT`-only statements. **The answer to "was any hosted system changed" is NO.**

---

## 0. Status vocabulary and how to read this report

| Token | Meaning used here |
|---|---|
| **PASS** | The required verification was executed in this phase and produced the expected observation, with a named artifact. |
| **PASS (SCOPED)** | Executed and green, but only over the stated surface. Anything outside the scope is not claimed. |
| **MITIGATED** | A compensating behaviour exists; the primary assertion is still unproven. |
| **BLOCKED** | Cannot be executed — a prerequisite is missing or unreachable (owner input, toolchain, or platform reality). |
| **NOT RUN** | Not executed. Includes every device row in the validation plan. |
| **STOPPED** | Work was deliberately not performed because authorization for it is absent. |
| **AWAITING OWNER** | A decision exists in written form and needs the owner's ruling; nothing was self-approved. |

**Expected results are never reported as observed results.** Where a number is quoted it comes from a
captured log under `.tools/` (gitignored scratch), and the command that produced it is printed next to it.
Where a claim could not be measured, the row says so instead of asserting it.

One structural caveat applies to the whole report: five of the six sub-agents fanned out at the start of the
phase died before reporting (§6). Every artifact attributed to them below was **re-derived or independently
re-run by the coordinator**, not accepted from a partial transcript. The only sub-agent output adopted as-is
is a screenshot, which is a hosted *read* and is described in §6.

---

## 1. Exact starting Git state (measured at preflight, 2026-11-03)

Full capture: `.tools/p4-preflight.txt`.

| Item | Value | Command |
|---|---|---|
| Branch | `main` | `git branch --show-current` |
| HEAD | `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` | `git rev-parse HEAD` |
| Brief's expected HEAD | `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2` — **DEVIATION** | brief §"Starting HEAD expected" |
| `git status --short` | **0 entries — a clean tree** (no staged, no unstaged, no untracked) | `git status --short \| wc -l` |
| `git diff HEAD --stat` / `--cached` / unstaged | all empty; `git diff HEAD \| sha256sum` = `e3b0c442…b855` (the digest of empty input) | measured |

The deviation is not a loss. `953b337` is `8da1de7` **plus** the owner's own commit
"feat: add Phase 1-3 implementation documentation, features, and tests", i.e. the owner committed the whole
Phase 2 + Phase 3 tree between the Phase 3 delivery and this phase. Preservation was proved, not assumed:

- `git diff 8da1de7 953b337 --stat` → **80 files changed, +9120 / −221**, which closes exactly against Phase 3's
  delivered tree: 73 tracked files at +7584/−221 **plus** the 7 then-untracked files at 1536 lines = 80 files,
  +9120, −221.
- `git show 953b337:docs/implementation/phase-3-report.md` contains the *final* Phase 3 delivery edit
  ("+7584 / −221" at `:74` and `:77`), so the commit captured delivered content, not an earlier draft.
- Author-date caveat recorded: `git show -s 953b337` reports author date Mon Nov 2 17:51:17 2026 while the blob
  content is post-delivery — the recorded author date is **not** reliable as the commit time, which is why
  content equality is the proof used above.

Because HEAD now contains the previous phases, Phase 4's diff is **purely Phase 4 content** — the §2
attribution problem that Phase 3 had (mixed Phase 2 + Phase 3 in one diff) does not exist here. That makes this
phase's numbers cleaner, not better: nothing was inherited-and-mislabelled, and nothing was preserved-but-hidden.

Preflight reads required by §2 of the brief were performed before any edit: `phase-1-report.md`,
`phase-2-report.md`, `phase-2-regression-matrix.md`, `phase-2-open-gaps.md`, `phase-2-governance.md`,
`phase-3-report.md`, `phase-3-regression-matrix.md`, `phase-3-open-gaps.md`, `phase-3-security-decisions.md`,
`api-contract.md`, `_work/coordinator-contract.md`, `regression-matrix.md`, `supabase/tests/README.md`.

---

## 2. Exact ending Git state (measured after the last verification run, 2026-11-03)

Full capture: `.tools/p4-end-status.txt`.

| Item | Value |
|---|---|
| Branch / HEAD | `main` @ `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` — **identical to start; no commit, no branch, no push, no tag** |
| `git status --short` | **25 entries** — 13 `M ` (staged, clean), 2 `A ` (staged new), 2 ` M` (worktree-only), 8 `??` (untracked) |
| `git diff HEAD --stat` | **17 files changed, +586 / −33** |
| `git diff --cached --stat` | 15 files changed, +483 / −8 (the index lags the worktree: the IDE staged earlier work, later edits landed unstaged) |
| `git diff --stat` (unstaged) | 2 files changed, +103 / −25 → `app_restrictions_controller.dart` (+122/−… partial hunk view) and `supabase/tests/README.md` (+6) |
| Untracked (8 files, 1580 lines) | `_work/p4-enf-residual.md` 135 · `_work/p4-hosted.md` 88 · `_work/p4-kotlin.md` 128 · `_work/p4-perf01.md` 164 · `_work/p4-test01.md` 189 · `phase-4-android-validation-plan.md` 467 · `proposals/phase4-retention-sweep-batch-shape.sql` 114 · `test/features/app_restrictions/policy_read_supersede_test.dart` 295 |
| **Working-tree digest** | `b39d63a5377a9385199ebd9d31737e2f4884eec63b143f905774894c9efcfd11` |

Digest basis, named exactly (a bare hash is not reproducible without it):

- **Path set (25)** = the union of `git diff HEAD --name-only` (17 tracked-changed paths) and
  `git ls-files --others --exclude-standard` (8 untracked paths), deduplicated and sorted; list in
  `.tools/p4-digest-files.txt`.
- **Per-file hash** = `sha256sum` over the **working-tree bytes as stored on disk** (not the git blob, not the
  staged content, not a `git diff` rendering); table in `.tools/p4-digest-perfile.txt`.
- **Aggregate** = `sha256sum` over the 25 sorted `<hash> *<path>` lines. Re-verified by re-hashing the first 25
  lines: `b39d63a5…` both times.
- **CRLF caveat** — git printed `LF will be replaced by CRLF the next time Git touches it` for
  `lib/features/app_restrictions/app_restrictions_controller.dart` and `supabase/tests/README.md`. The digest
  therefore pins today's byte content of those two files; the next `git` operation that rewrites them can
  legitimately change the aggregate. Scope of the scan: exactly the 25 changed paths — it is **not** a
  whole-repository hash.
- **Composition caveat** — 21 of 25 paths are markdown/SQL documentation or a proposal; the only executable-behaviour
  changes are `app_restrictions_controller.dart`, `policy_read_supersede_test.dart`,
  `supabase/tests/75_signaling_replay_index_duplicate_guard.sql` and `supabase/tests/README.md`.

Docs written after the digest was measured (this file, the other three `phase-4-*.md` deliverables and
`phase-4-android-validation-plan.md` was already present): a file cannot pin the hash of the page that records
it, so the four coordinator deliverables are deliberately **outside** the quoted digest. They are documentation
only; no source, migration, test or config line changed after the suite run recorded in §4, and no suite was
re-run for a docs-only delta.

### 2a. Delivered-tree re-measure (taken after the four deliverables were written, 2026-11-03)

The state above is the **tested** tree. Re-measured at delivery:

| Item | Value |
|---|---|
| Branch / HEAD | `main` @ `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` — **still identical to start** |
| `git status --short` | **29 entries** — 15 `M `, 9 `A `, 1 `AM`, 4 `??` |
| `git diff HEAD --stat` | **25 files changed, +2181 / −33** |
| `git diff --cached --stat` | 25 files changed, +2166 / −33 |
| `git diff --stat` (unstaged) | 1 file changed, **+15 / −0** — only the coordinator's dated correction inside `phase-4-android-validation-plan.md` §6A |
| Untracked (4) | `phase-4-report.md`, `phase-4-regression-matrix.md`, `phase-4-open-gaps.md`, `phase-4-owner-approval-register.md` |
| **Delivered-tree digest** | `c33bb5e9026c92e5b3d0c290d495db9443a688d0b89be960edb8d270360cc847` over **29** paths, same basis and method as §2 (`.tools/p4-digest-perfile-delivered.txt`) |

**Index movement the coordinator did not cause, and therefore records rather than explains:** between the §2
capture and this one, the 8 previously-untracked Phase 4 files (and `75_…sql`, already listed as `A ` earlier)
appeared in the index — staged entries went 15 → 25 and `??` went 8 → 4 — with **no `git add` run by this
phase**. The staging is attributed to the editing environment, not to a workstream, and is flagged because it
changes what a later "commit Phase 4" means: 25 paths are already in the index, and only the four deliverables
plus 15 unstaged lines would be new. The delta between the two digests is exactly those 4 files plus the 15-line
plan annotation — verified by comparing the two per-file tables (`b39d63a5…` 25 paths ⊂ `c33bb5e9…` 29 paths;
the 4 added hashes are the deliverables, and the one changed hash is the plan).

Preservation: no `git reset`, `git clean`, `git stash`, `git checkout`, `git restore`, commit, branch, tag or
push was run at any point in this phase. `git add` was not run by the coordinator; the 15 staged entries were
staged by the IDE before/during the phase (recorded as observed, not attributed to a workstream). The Supabase
CLI binary exists at `C:/Users/ASUS/AppData/Roaming/npm/supabase` and was **never invoked** — hosted inspection
went through the dashboard browser session only, per the project rule.

---

## 3. Files changed, by workstream

| Path | Workstream | Change |
|---|---|---|
| `docs/implementation/_work/p4-docs-sql06.md` (new, 218 lines) | **A — DOC-01 + SQL-06a** | The measured `api-contract.md` re-wording proposal and the migration/`tests/70`/`tests/71` disagreement analysis. |
| `supabase/tests/75_signaling_replay_index_duplicate_guard.sql` (new, 218 lines) | **A** | In-chain guard for SQL-06a: asserts the pre-apply duplicate check and that a duplicate-bearing database leaves the unique index **absent** with a NOTICE instead of silently failing or deleting rows. |
| `supabase/tests/README.md` (+6, unstaged) | **A + coordinator** | Documented chain 30 → **31** `-f` files, with the ordering rule for `75` after `74`. |
| `regression-matrix.md`, `backend.md`, `bug-report.md`, `security.md`, `verification-report.md`, `phase-1-report.md`, `phase-2-report.md`, `phase-3-regression-matrix.md`, `mic_full_audit_report.md`, `runtime-mic-test-report.md`, `stage2_…`, `stage5_…`, `stage6_…` (13 files, +43/−8) | **A — DOC-01 sweep** | Every flagless `deno test …` command that is now wrong was met with an appended dated annotation naming the `--allow-read` requirement and the reason (`_shared/` gained file-reading tests in Phase 3). **No recorded historical result was rewritten** — each entry says "as executed on <date>" and leaves the original numbers untouched. |
| `lib/features/app_restrictions/app_restrictions_controller.dart` (+103/−25 unstaged) | **C — ENF residual** | Superseded-read guard for the policy/assignment path: two generation tokens, `_isClosed`, version-monotonic publish, evidence invalidation on policy switch. |
| `test/features/app_restrictions/policy_read_supersede_test.dart` (new, 295 lines) | **C** | 6 deterministic scenarios; 4 of them **fail against the pre-fix tree** (measured, `.tools/p4c-prefix-failures.log`). |
| `docs/implementation/_work/p4-enf-residual.md` (new, 135 lines) | **C** | Reachability trace, the three concrete interleavings, the fix, and why a plain owner bail-out was rejected. |
| `docs/implementation/_work/p4-perf01.md` (new, 164 lines) + `.tools/p4d_equiv.sql`, `.tools/p4d_equiv_order.sql` + logs | **D — PERF-01** | Batch-shape equivalence measured on byte-identical disposable copies. Migration **unchanged**. |
| `docs/implementation/proposals/phase4-retention-sweep-batch-shape.sql` (new, 114 lines) | **D** | The two replacement statements, the measured effect, the 4 reasons not adopted, and everything that must move with them. |
| `docs/implementation/_work/p4-kotlin.md` (new, 128 lines) | **B — KOT-01/02** | Gradle re-run evidence table + KOT-02 prerequisite proof. |
| `docs/implementation/_work/p4-test01.md` (new, 189 lines) | **E — TEST-01** | What the 5 source-level pins do *and do not* prove, plus the sequenced export/DI proposal. **Handlers untouched.** |
| `docs/implementation/_work/p4-hosted.md` (new, 88 lines) + `.tools/p4g-probe-observations.txt` | **G — HOST gate** | Read-only hosted re-check vs the Phase 3 baseline, new provenance probe, HOST-01 blocker path. |
| `docs/implementation/phase-4-android-validation-plan.md` (new, 467 lines) | **F — Workstream F** | Device validation matrix: 9 sections, blank *Actual* on every row, `NOT RUN` status throughout, §6 rows blocked even after authorization. |

No Edge Function file, no migration file, no `android/**` file, no `pubspec.yaml`/`build.gradle.kts` and no
`.env` was modified. Verified: `git diff HEAD --stat -- supabase/functions android` is empty apart from
`supabase/tests/**`.

---

## 4. Authoritative verification (coordinator-owned, executed 2026-11-03 after every edit)

Exact commands, exit codes and counts are in `phase-4-regression-matrix.md`. Summary of what was actually run:

| Suite | Result observed | Exit |
|---|---|---|
| `./.fvm/flutter_sdk/bin/dart analyze` | `No issues found!` | 0 |
| `./.fvm/flutter_sdk/bin/flutter test` | `00:33 +396: All tests passed!` (Phase 3 measured +390 → +6 new) | 0 |
| `flutter test test/features/app_restrictions` | `00:13 +49: All tests passed!` | 0 |
| `deno test --allow-read supabase/functions/` | `ok \| 109 passed \| 0 failed (3s)` — **identical count to Phase 3; Phase 4 added no Deno test** | 0 |
| `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` (KOT-01) | 5 JUnit classes, **35 tests, 0 failures, 0 errors, 0 skipped**, 182 tasks executed | 0 |
| Documented SQL chain, **31 files**, fresh cluster `.tools/pgdata_p4f` port 55471 | 604-line log, `grep -c 'ASSERTION FAILED'` = **0**, `grep -c 'ERROR'` = **0**, then **19** public tables, `webrtc_signals_session_sequence_uniq` present, **66** indexes; chain exit **0** | 0 |

Deltas are measurements, not expectations: Flutter 390 → 396 (+6, the new supersede file), chain 30 → 31 files
(`75` added), Deno 109 → 109 (+0), Gradle 35 → 35 (+0, first time actually executed).

No pre-existing test was deleted, skipped, relaxed or re-scoped to obtain any of these numbers. The one
behaviour change shipped in this phase (`app_restrictions_controller.dart`) made 4 previously-failing new
tests pass; it did not touch an existing assertion, and the 49-test `app_restrictions` subset is green with the
Phase 3 correlation tests still in the set.

Cluster hygiene: `pgdata_p2`, `pgdata_p3a`, `pgdata_p3b` untouched; `pgdata_p4d` (agent D's, 940 MB) stopped and
removed by the coordinator after its logs were harvested; `pgdata_p4f` stopped (`pg_isready` exit 2) and its
directory kept for post-mortem. No port is still listening at delivery.

---

## 5. What each brief item's status actually is

| Brief item | Status in one line |
|---|---|
| **DOC-01** | **PASS** — the documented command now includes `--allow-read`; the recorded negative control (flagless = `FAILED \| 83 passed \| 5 failed`) is preserved; the conflicting-command sweep across the docs tree is complete and every hit is a dated annotation, not a rewrite. |
| **SQL-06 / 06a** | **PASS (SCOPED)** for the guard, **AWAITING OWNER** for the wording. The migration/`70`/`71` disagreement is now *measured* (duplicate-bearing DB: migration applies quietly with NOTICE ×1, index stays ABSENT, duplicates never deleted; `70` exits 0 either way; `71` exits 3 at its unguarded assertion). `tests/75` added and validated in-chain. The pre-apply duplicate check is preserved as mandatory; the unique index is **not** described as preventing new-sequence replay anywhere in the authorized docs scope. |
| **KOT-01** | **PASS** — Gradle genuinely executed the tests (182 tasks, `--rerun-tasks`, fresh XML timestamps `2026-11-03T05:36:52Z`, 35/0/0/0). Success is claimed because the run is evidenced, not because the exit code was 0. |
| **KOT-02** | **BLOCKED**, code left unchanged per the brief's own fallback. The "coverage first" prerequisite is unreachable in this module: junit 4.13.2 only, no Robolectric/Mockito, no `testOptions`, so neither duplicated helper can be exercised. Both stay, with 4 owner options and a recommendation. |
| **Workstream C (ENF residual)** | **PASS (SCOPED)** — a superseded read can no longer roll the displayed policy back, cannot post an older version, cannot show a stale error, cannot prove enforcement for a policy that is no longer displayed, and writes nothing after disposal. The `payload.policy_id` correlation rule is untouched. |
| **PERF-01** | **PASS (SCOPED) — equivalence demonstrated, adoption STOPPED.** Same rows, same order, same counts across both shapes (identical set digest, identical returning-order and ctid-visit digests, 12/12 pairwise diffs 0/0, 10000/10000 positional agreement, 2 reps each). Faster, but nothing was changed: batch semantics are preserved, and the change still needs an owner ruling. |
| **TEST-01** | **NOT RUN as an implementation (handlers unchanged), DELIVERED as a sequenced proposal.** Source-level pinning vs handler execution is stated explicitly, including the four things the pins cannot prove. |
| **Workstream F** | **NOT RUN** for every device row — this is a plan. No APK installed, no device executed, no build created. Some rows are additionally flagged **BLOCKED today** because they cannot be executed even once the run is authorized. |
| **HOST gate** | **PASS (SCOPED) as a re-check; the gate itself is BLOCKED.** The four read-only probes reproduce the Phase 3 observations exactly — `safe_zones` still grants DELETE to `authenticated`, `safe_zones_delete_parent` still present, no `schema_migrations` table, `account` function still 0 deployments, no cron. **HOST-01 remains a deployment blocker.** |

---

## 6. Sub-agent failure disclosure (material to how much of this is single-threaded)

The brief asked for 7 agents. The fan-out was issued; **5 of 6 background workstream agents died before
returning a report** — B and C failed at queueing, D's request failed, E and G hit a credit limit. This is
disclosed because it changes the meaning of "reviewed by an independent agent":

| Agent | Delivered | What the coordinator actually did |
|---|---|---|
| A — DOC-01/SQL-06a | landed real file edits + `_work/p4-docs-sql06.md` before dying | verified its guard in-chain, and closed its one deferred item (`README.md:31-64` chain wiring) |
| B — KOT | left `.tools/p4b-gradle*.log` only | **re-ran Gradle myself**; the 35/0/0/0 in §4 is my run, corroborated by its log |
| C — ENF residual | left `.tools/p4c-prefix-failures.log` (the 4 pre-fix failures) | did the fix myself, wrote the 6 tests, measured before/after myself |
| D — PERF-01 | left `.tools/p4d_ab.sql` + a live 940 MB cluster | rebuilt the probe (its `BEGIN…ROLLBACK` draft cannot capture deleted ids — the rollback destroys the capture), ran it, then stopped and removed the cluster |
| E — TEST-01 | left `.tools/p4e-deno.log` | re-ran `deno test --allow-read` myself (109/0); wrote the proposal from the sources, not from its notes |
| F — Android plan | returned the plan document | verified its citations against the tree |
| G — hosted gate | left `.tools/p4g-00-overview.png` + the tab inventory | performed both SQL probes and the Edge/cron reads myself; raw captures in `.tools/p4g-probe-observations.txt` |

So: every PASS in §4 and §5 is a **coordinator-executed** measurement. The only claims inherited from a dead
agent are its raw logs, and each of those was re-executed before being quoted.

---

## 7. Hosted Supabase: read-only inspection (nothing applied)

Method and the four disclosed limitations are in `_work/p4-hosted.md`. In short: dashboard SQL editor,
`SELECT`-only, executed via page automation on a hidden viewport, so **no screenshots were obtainable** and
results were read from the DOM; the grid virtualises, so a 13-row answer had to be re-issued as two queries;
14 unsaved "Untitled query" tabs are retained in the owner's dashboard session and were not closed.

The 14-row comparison against the Phase 3 (2026-11-02) baseline shows **no change** in 24 hours: same privileges,
same policies, same function inventory, same absence of a version table. One new decisive probe was added: the
four Phase 1/2/3 RPCs are `create or replace` targets, so the mere presence of some of them proves nothing —
but `prosrc like '%is_parent_of_family%'` returns **NONE**, which is a positive signal that
`20261030000200_phase1_authorization.sql` has never been applied. Consistent with `phase-1-report.md`'s own
"nothing deployed" state, and with memory `project-phase1-hosted-state`.

**HOST-01 stays open**: an authenticated caller can still `DELETE FROM safe_zones` for a family they do not own
at the database level, which is exactly what the Phase 1 migration closes. No fix was applied or attempted —
the brief forbids hosted mutation, and the fix is a migration apply, which is an owner act.

---

## 8. Deployment readiness — what Phase 4 changed about the gate

Nothing moved from blocked to clear. What Phase 4 added is **evidence** for the gate and a **runnable path**
through it:

1. The rollback path and the duplicate-index guard are both asserted **in the documented chain**, so a
   pre-apply rehearsal on a disposable cluster now catches the two states that used to be inferred.
2. The retention sweep batch-shape question is answered on the merits (equivalence proven), so the owner can
   decide on a measured trade rather than an unproven optimisation.
3. The Android validation plan exists with blank *Actual* columns and an explicit preflight (§1 of that file),
   so device execution has a defined starting line instead of an ad-hoc run.
4. KOT-01 is closed, which removes "the JVM tests may not run here" from the risk list — and KOT-02's blocker
   is now precisely characterised (test stack, not machine).

The gate still needs, in order: PRIV-01 scope decision → GOV-02/D1 signature → SQL-01/R3 ruling → SQL-04
procedure decision → SQL-05 atomicity decision → SQL-06 wording approval → TEST-01 scheduling → **then**
migration apply through the authorized process → **then** the read-only verification that closes HOST-01.
None of these was performed or self-approved here.

---

## 9. Remaining owner approvals

Eight items, each with options, consequences, recommendation, affected files and status, are in
`phase-4-owner-approval-register.md`. Summary: PRIV-01, GOV-02/D1, SQL-01/R3, SQL-04 (procedure + schedule),
SQL-05 (atomic RPC), SQL-06 (contract wording), TEST-01 (handler export/DI), and commit/push/apply.
**All are AWAITING OWNER.** `git add`, commit, branch and push were not run by the coordinator, and no hosted
object was created, altered or dropped.

---

## 10. Completion-gate self-assessment against the brief

| Brief § | Requirement | Met? |
|---|---|---|
| 1 | Not a deployment phase; no migrations/functions/settings/cron/data writes | **Met** — §7 + §9; only `SELECT` executed against hosted. |
| 2 | Read prior-phase docs, record branch/HEAD/status/diffs/untracked, preserve everything, attribute by phase | **Met** — §1 and §2; tree was clean at entry so Phase 4's diff is Phase 4's alone. |
| 2 | Forbidden commands not run | **Met** — no reset/clean/stash/checkout/restore, no commit/branch/push, no Supabase CLI, no Flutter **build**, no Gradle assemble. Gradle **test** was run because KOT-01 explicitly requires it. |
| 3 | DOC-01 (flag + negative control + sweep); SQL-06/06a (no over-claim, resolve disagreement, accurate guard, keep pre-check mandatory, don't weaken tests) | **Met** — §5 rows 1–2. |
| 4 | KOT-01 re-run with full capture; KOT-02 coverage-first, leave unchanged if prerequisite unmet | **Met** — KOT-01 PASS with XML evidence; KOT-02 left unchanged with the reason recorded. |
| 5 | Superseded-read fix on the existing generation strategy; deterministic tests; `payload.policy_id` rule untouched | **Met** — §5 row 4; correlation rule verified unchanged in the diff. |
| 6 | Reproduce the seq-scan, evaluate the alternative, compare rows/order/repeatability/plans; don't adopt if semantics move; no procedure/COMMIT/cron/RPC change | **Met** — equivalence proven, **nothing adopted**, migration byte-identical to HEAD. |
| 7 | Document handler export + DI changes; don't implement without authorization; distinguish source-level from executed tests | **Met** — proposal only, explicit separation in `_work/p4-test01.md`. |
| 8 | Android matrix with preconditions/steps/expected/blank actual/evidence/status; no APK install, no device run, no build; no bypass of privacy controls | **Met** — plan delivered, every status `NOT RUN`, no bypass anywhere. |
| 9 | OWNER-ONLY register with decision/options/consequences/recommendation/files/status | **Met** — register file, 8 rows. |
| 10 | Read-only re-checks of the 4 production gate items; no fix; HOST-01 stays a blocker | **Met** — §7; blocker wording kept verbatim in the matrix. |
| 11 | Five deliverables, approved labels only, no expected-as-observed | **Met** — 4 files written here + `phase-4-android-validation-plan.md`. |
| 12 | Re-run suites for code actually changed; verify no Phase 2/3 loss; re-measure state incl. **working-tree digest**; state whether hosted changed | **Met** — §2, §4, §6; **hosted changed: NO**. |
| 13 | Nine-part final response, then wait | Delivered in the closing reply. |

Two things are worth stating plainly rather than grading as met: the fan-out did not produce 7 independent
reviews (§6), and "deployment gate closure" is a misnomer for what is permitted here — the gate was
**characterised and its path made executable**, not closed. Closing it requires a migration apply, which is
the owner's act.
