# PHASE 5 — Owner Decision Implementation & Controlled QA Readiness: report

Phase entry point: branch `main`, HEAD `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d`.
Phase executed: 2026-11-03, coordinator-only (see §10 for why the brief's "use 8
subagents" instruction could not be honoured and what replaced it).

**End state: no commit, no push, no branch, no migration applied, no Edge Function
deployed, no cron installed, no hosted write of any kind, no device execution.**
Everything Phase 5 produced is in the index and the worktree, uncommitted, exactly
as the owner ruled.

---

## 0. Status vocabulary used in this report and in the other four deliverables

| Token | Meaning |
|---|---|
| **IMPLEMENTED** | The approved change exists in the working tree of this phase. |
| **TESTED** | Executed in this phase against a named artifact, with the command and exit code printed. |
| **IMPLEMENTED — UNAPPLIED** | Code/SQL written and locally tested; **nothing has run against the hosted project.** Used for every SQL and Edge Function item, because §12 forbids application. |
| **PASS (SCOPED)** | Green, but only over the stated surface; anything outside is not claimed. |
| **BLOCKED** | Cannot be executed — a prerequisite (owner input, toolchain, platform reality) is missing. |
| **NOT RUN** | Not executed. Every Android device row is this. |
| **STOPPED** | Deliberately not performed because authorization is absent (owner refused). |
| **AWAITING OWNER** | A decision exists in writing and needs a ruling; nothing was self-approved. |

**Expected results are never reported as observed results.** Every number below
comes from a captured log (`.tools/` scratch or `docs/evidence/phase5/logs/`) with
the command that produced it printed next to it. Where a claim could not be
measured, the row says so instead of asserting it.

A word used deliberately throughout: **unapplied**. In this phase "the RPC is
implemented and tested" means "it ran on a disposable PostgreSQL 16.9 cluster on
port 55581 on this machine". It has never been seen by the hosted project.

---

## 1. Exact starting Git state (measured at preflight, 2026-11-03)

| Item | Value (measured) |
|---|---|
| Branch / HEAD | `main` @ `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` — identical to the Phase 4 entry point; Phase 4 committed nothing, so HEAD is still the pre-Phase-1 tree. |
| Changed paths vs HEAD at preflight | **29** (`.tools/p5-pathset.txt`, captured 11:55–12:09), i.e. the whole Phase 4 delivered tree is still uncommitted. |
| Staged / unstaged / untracked inspected separately | yes — method in §2 of `phase-4-report.md`; this phase re-ran `git status --short`, `git diff HEAD --name-only`, `git ls-files --others --exclude-standard` and hashed per path. |
| Phase 4 delivered digest as published | `c33bb5e9026c92e5b3d0c290d495db9443a688d0b89be960edb8d270360cc847` over 29 paths |
| That digest re-measured on this tree | **3 of the 29 paths did not match at preflight; 4 do not match at close** (the 4th is a Phase 5 edit, see §1a). Today's aggregate over the same 29 paths, in the published order, is `6d717835e1a1a3fb162a332e08d5213b333ec6b65032e6e4138fd5d20defacd1` |

### 1a. Phase 4 digest reconciliation — resolved, with the mechanism measured

Phase 4 §2a asserted its delivered-tree digest was "taken after the four
deliverables were written". Four of its 29 paths disagree with that when
re-measured at the close of Phase 5 — three of them already at preflight. Each
was traced, and the two kinds are not the same defect:

| Path | Phase 4 value | Value at close | Attribution |
|---|---|---|---|
| `docs/implementation/phase-4-report.md` | `0c3f0282…` | `7ca4278c…` | **Phase 4 sequencing defect, not a Phase 5 change.** The file's mtime is `11-03T11:56:23`; the digest table `.tools/p4-digest-perfile-delivered.txt` has mtime `11-03T11:55`. The digest was computed **before** the last write of this file. |
| `docs/implementation/phase-4-regression-matrix.md` | `dc39df36…` | `2745207e…` | Same mechanism: file mtime `11-03T11:56:45` vs digest-table mtime `11:55`. |
| `supabase/tests/README.md` | `a6d1725a…` | `d8f91f25…` | **Phase 5 change, expected.** The chain grew from 31 to 33 `-f` entries (`75_…` was already there; `76_zone_delete_atomic_rpc.sql` and the SQL-05 migration were added), and the README documents that chain. Attributable, documented in §4. |
| `docs/implementation/phase-4-owner-approval-register.md` | `4c911f21…` | `333527e0…` | **Phase 5 change, expected, and it appeared after preflight** (file mtime `11-03T17:03:47`): the two dated corrections to that register's KOT-02 block (§12 of this report). Preflight measured 3 drifts; close measures 4. Reporting 3 at close would have been a stale number. |

**Re-hash basis, stated so the number is checkable.** `xargs -a
.tools/p4-digest-files-delivered.txt sha256sum` over the published 29-path list,
whose order was verified to be C-locale sorted already
(`diff <(cut -c67- .tools/p4-digest-perfile-delivered.txt) .tools/p4-digest-files-delivered.txt`
→ empty), table saved as `.tools/p4-rehash-inorder-20261103.txt`; `sha256sum <`
that file → `6d717835e1a1a3fb162a332e08d5213b333ec6b65032e6e4138fd5d20defacd1`.
`c33bb5e9…` reproduces from the Phase 4 table the same way, so the two aggregates
differ only by the 4 changed per-file lines.

An earlier draft of this section quoted `587a197eb51ca92b59dedc652dd2a3b4269f879e539d8ae89bbd248463f1f4e2`
for the same re-hash. That value **cannot be reproduced under any basis tried**
(two-space separator `a7853b6a…`, hash-column-only `209a5b75…`, path-column-only
`45e408b6…`, single-space separator `d21612da…`, hash-sorted lines `969a05ba…`,
the 28 paths that exclude the README `e184a761…`). Its generating command is not
recoverable from the scratch files that survive, so no mechanism is claimed; the
number is withdrawn and `6d717835…` replaces it — same treatment as Phase 4's
`06ec4b10…` further down.

Line-ending normalization was tested and **rejected** as the cause: `tr -d '\r' < f | sha256sum`
equals `sha256sum f` for all four drifted paths (they are LF-only on disk; git's
`LF will be replaced by CRLF the next time Git touches it` warning describes a
future checkout, not the current bytes).

Staged vs worktree (`git show :path | sha256sum` compared with `sha256sum < path`)
separates the four into two kinds, measured:

| Path | staged | worktree | reading |
|---|---|---|---|
| `supabase/tests/README.md` | `d8f91f25…` | `d8f91f25…` | staged content == tested content |
| `docs/implementation/phase-4-report.md` | `7ca4278c…` | `7ca4278c…` | same |
| `docs/implementation/phase-4-regression-matrix.md` | `2745207e…` | `2745207e…` | same |
| `docs/implementation/phase-4-owner-approval-register.md` | `4c911f21…` | `333527e0…` | **staged == the Phase 4 published hash, worktree ≠ staged** — the 17:03 correction is unstaged. This is one of the two `AM` rows in §2. |

So the register is the only one of the four where "modified after staging" is
true, and the other three differ from Phase 4's table because Phase 4 hashed
before writing, not because the index is stale. None of the three Phase 4
documents exists in HEAD (`fatal: … exists on disk, but not in 'HEAD'`), so a
HEAD-vs-worktree comparison is not available for them at all.

Consequence recorded in `phase-5-open-gaps.md` as **GAP-EV-05**: a digest taken
before the last edit of the files it describes cannot be a delivery digest. Phase 5's
own digest (§2) is therefore taken as the **last action of the phase**, and the
five deliverables are inside the hashed set, which is possible because the digest
file itself is excluded from its own table.

Also retired: the inherited suspicion that Phase 4 mispublished the value
`06ec4b10…`. `c33bb5e9…` reproduces exactly from its own per-file table
(`sha256sum .tools/p4-digest-perfile-delivered.txt` → 29 lines → same aggregate),
and `06ec4b10…` could not be reproduced under any basis tried. That suspicion is
withdrawn as unfounded; the real defect is the ordering above, not a fabricated number.

---

## 2. Exact ending Git state (measured after the final verification runs)

| Item | Value |
|---|---|
| Branch / HEAD | `main` @ `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` — **unchanged from start; no commit was made** (owner ruling). |
| `git status --short` composition, **re-measured as the last action of the phase** | 29 `A `, 3 `AM`, 1 ` M`, 34 `M `, 6 `??` = 73 status lines. Named, because the codes alone are not the finding. `git diff --name-only` (worktree vs index) returns **exactly 3** paths — `AM` = `docs/implementation/phase-4-owner-approval-register.md`, `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql`, `docs/evidence/phase5/MANIFEST.md` (this phase's closing edits to files the IDE had already staged); ` M` = `docs/implementation/deployment/manifest.md` (present in HEAD, absent from `git diff --cached`, so every Phase 5 edit to it is unstaged). The six `??` are the five `phase-5-*.md` deliverables plus `docs/evidence/phase5/tree-digest-final.txt`, all untracked because ruling #10 forbids staging or committing — including a file this phase created itself, which is why an earlier row in this table read 5. |
| Same measurement mid-phase, after the toolchain runs but before the deliverables existed | 31 `A `, 1 `AM`, 34 `M `, 0 `??` over **66** tracked paths |
| Changed tracked paths vs HEAD at close | **67** (+6 untracked = **73** delivered paths; the hashed set is 69 after the four self-referential exclusions) |
| `git diff HEAD --shortstat` at the 57-path baseline | `57 files changed, 7590 insertions(+), 689 deletions(-)` |
| `git diff HEAD --shortstat`, scoped to `supabase lib android test docs/implementation` (excludes `docs/evidence/`) | **`50 files changed, 7720 insertions(+), 686 deletions(-)`** — chosen deliberately as the closing figure: the evidence pack is excluded from the digest (§2a), and it is also excluded here, so this number does not move when `MANIFEST.md` is edited. That matters, because the report's §2a text and `MANIFEST.md` §8a form a two-way citation (the manifest quotes this report's hash, this table quotes a count that includes the manifest's bytes) and only a scoped measurement has a fixed point. |
| `git diff HEAD --shortstat`, whole delivered diff | `67 files changed, 8312 insertions(+), 690 deletions(-)` as last measured — **expected to be stale by a few lines**: it counts `MANIFEST.md`, which was still being written when it was taken. Earlier readings of the same command were 7590 (57-path baseline) and 8236. |
| Final delivered-tree digest | §2a — computed as the **last** action of the phase, over the exclusion set defined there, with the per-file table saved as `docs/evidence/phase5/tree-digest-final.txt`. |

**Index movement the coordinator did not cause, and records rather than explains:**
between the preflight capture and the 57-path digest, two previously-untracked
files entered the index with no `git add` run by this phase (same behaviour already
disclosed in Phase 4 §2a). Status entries are reported as observed. Nothing was
committed, pushed, branched, tagged, stashed, reset, cleaned, checked out or
restored at any point in this phase — the brief's §2 prohibition list was honoured
literally, including "never use restore".

## 2a. Final delivered-tree digest (re-measured after the last edit)

**Basis, named exactly, because the number is meaningless without it:**

- **Path set** = union of `git diff HEAD --name-only` and
  `git ls-files --others --exclude-standard`, sorted and deduplicated,
  **minus four exclusions**:
  1. `docs/evidence/phase5/tree-digest.txt` and
     `docs/evidence/phase5/tree-digest-final.txt` — a digest table cannot appear
     in the set it hashes;
  2. `docs/evidence/phase5/MANIFEST.md` and `docs/implementation/phase-5-report.md`
     — these two files **quote the aggregate value**. Including them makes the
     number depend on its own text, and no fixed point exists: hashing, then
     writing the value in, changes the bytes the value describes. Excluding them
     is the only self-consistent option, and it is stated here rather than left
     for a reader to rediscover.
- **Per-file hash** = `sha256sum` over the **working-tree bytes as stored on
  disk** — not the git blob, not the staged content, not a diff rendering.
- **Aggregate** = `sha256sum` over the `<hash> *<path>` lines, in sorted path
  order.
- **Reproduction**: `sha256sum docs/evidence/phase5/tree-digest-final.txt` prints
  the same value, because that file *is* those lines (`cut -c67-` recovers the
  path list, `sha256sum` over them recovers the aggregate).

| Snapshot | Paths | Aggregate | Where the table lives |
|---|---|---|---|
| Baseline, frozen mid-phase (before the evidence pack existed; **includes** every file the five suites compile) | 57 | `4ee854c2119eee1264f38e41dd575634d97c7e396e2ceb4a8cbcfed3205725e0` | `docs/evidence/phase5/tree-digest.txt` |
| Same 29 paths re-hashed from the Phase 4 delivered table (for §1a drift analysis) | 29 | `6d717835e1a1a3fb162a332e08d5213b333ec6b65032e6e4138fd5d20defacd1` | `.tools/p4-rehash-inorder-20261103.txt` |
| Draft of the final digest, before the last documentation edits | 69 | `0eebf9e722df2464c522b94728f6c6e94c9661cbd6ce85bba47d7905898105d7` | superseded; moved lines: `deployment/manifest.md`, `phase-5-open-gaps.md` |
| Second draft, before the §2.2 hash-provenance correction | 69 | `6f4336edd93c51ab444e9e27ecc53d50b6e0e96ac5fe818ceb24171aa4bc6ca2` | superseded; 1 moved line (`phase-5-deployment-readiness.md`) |
| Third draft, before the line-ending finding was registered and the matrix header named both digests | 69 | `102d27013f6d14bf8533289bb35ffa8b3e5778a7561a6ee1c3e0d098583a1f52` | superseded; 2 moved lines (`phase-5-open-gaps.md`, `phase-5-regression-matrix.md`) |
| **Final delivered tree at close of Phase 5 — frozen** | **69** | `2bd6b310dae6a0b516dbb60f6bc27b6ccc24f20df20e36491834568cb3aa4e4b` | `docs/evidence/phase5/tree-digest-final.txt` (69 lines, 8171 bytes). **Nothing in this set is edited after this row was written**; the only writes that followed were `MANIFEST.md` and this report, both outside the set. |

**Why a 69-path number moved four times, stated plainly.** Each move is this
phase's own documentation edit made *after* the previous reading: two, then one,
then one. The path set never changed — a `diff` of the successive per-file tables
shows only hash lines differing, and the exclusion-adjusted union re-measured
after every step is still the same 69 paths (`73` from git minus the `4`
exclusions). This is GAP-EV-05 happening to Phase 5 repeatedly, and the fix is
procedural rather than editorial: `tree-digest-final.txt` is written **last**, no
hashed file is touched afterwards, and the two documents that quote the aggregate
(this report and the evidence `MANIFEST.md`) sit outside the set so that writing
the number down cannot invalidate it. The value above is the value in that file;
re-verify with `sha256sum < docs/evidence/phase5/tree-digest-final.txt`.

Two caveats that belong with the number, not in a footnote:

- **CRLF** — `core.autocrlf=true` with no `.gitattributes`, so git normalises
  text on check-in. Measured directly over the 69 hashed paths
  (`wc -c` vs `tr -d '\r' | wc -c`): **7 contain CRLF in the worktree** — the six
  `docs/evidence/phase5/gradle-junit/*.xml` and
  `docs/implementation/api-contract.md` — and `git ls-files --eol` shows all
  seven as `i/lf w/crlf`, meaning the digest pins bytes that differ from the blob
  git would store. The other 62 are LF on disk, so worktree bytes and blob agree.
  A 15-path warning count inherited from Phase 4's manifest could not be
  reproduced under any measurement and is withdrawn in `MANIFEST.md` §5. Because
  `git add` would normalise those seven, this is registered as an open gap for the
  owner (**GAP-EOL-01**, `phase-5-open-gaps.md` §1) rather than silently absorbed.
- **Scope** — this is a digest of the *changed* paths (the delivered diff), **not**
  a whole-repository hash and not a git tree object id. A reader who wants to
  verify "these bytes and no others were tested" must use it together with §4b's
  run-order table, because the suites ran at different times: the 57-path baseline
  is the tree the **code** suites tested, and the 69-path final value is the tree
  this phase delivers. The difference between them is evidence-pack and
  documentation bytes, plus the SQL-05 header citation fix — which is why the chain
  was re-run afterwards (§4c).

---

## 3. What the owner decided, and what was therefore done

Twelve decisions were taken in this phase (all through explicit answers, none
inferred — the brief's §3 rule). Full text, and what each one forbade, in
`phase-5-owner-decision-log.md`. Short form:

| # | Item | Ruling | Phase 5 action |
|---|---|---|---|
| 1 | PRIV-01 | **A** — child/device-scoped retention report | implemented + tested (§5) |
| 2 | SQL-05 | **approve the atomic RPC** | implemented + tested (§6) |
| 3 | SQL-04 / PERF-01a | **faster batch shape only, keep the function**; bounded execution **refused** | shape implemented; the refused half is STOPPED and quarantined (§7) |
| 4 | TEST-01 | **approve**, device-command first | implemented + tested (§8) |
| 5 | GOV-02 | **ratify the pair as-is** | documentation only; no code change (§9) |
| 6 | SQL-01 / R3 | **never sanction R3** | rollback statements remain quarantined; none executed (§9) |
| 7 | SQL-06 | **approve the drafted wording** | wording applied + re-verified against source (§5b) |
| 8 | KOT-02 | **A — extract a pure function** | implemented + tested (§10-workstream-F row in §5) |
| 9 | AND-01 / Gate B | **no device execution** | STOPPED; no device row is marked PASS anywhere (§11) |
| 10 | Gate A git action | **no commit — leave everything uncommitted** | obeyed; conflicts with #12, resolved in favour of the prohibition (§12) |
| 11 | Hosted deployment | **none** | obeyed; zero hosted calls of any kind (§12) |
| 12 | EVD-01 | commit selected evidence | **conflicts with #10.** Prepared the evidence pack, did not commit it, and recorded the conflict rather than choosing silently (§12). |

---

## 4. Authoritative verification (coordinator-owned, executed on the final tree)

Toolchain version lines were re-printed, not assumed (full text in
`docs/evidence/phase5/MANIFEST.md` §1): Flutter `3.44.6` framework `ee80f08bbf`;
Dart `3.12.2`; Deno `2.9.4`; Gradle wrapper `9.1.0`; PostgreSQL client/server
`16.9`.

| # | Command (exact) | Exit | Result line as printed | Log |
|---|---|---|---|---|
| 1 | `./.fvm/flutter_sdk/bin/dart analyze` | 0 | `No issues found!` | `.tools/p5-coord-dart-analyze-run2.log` → packed `logs/p5-coord-dart-analyze-run2.log` |
| 2 | `./.fvm/flutter_sdk/bin/flutter test` | 0 | `00:30 +408: All tests passed!` | `.tools/p5-coord-flutter-run2.log` |
| 3 | `deno test --allow-read supabase/functions/` | 0 | `ok \| 150 passed \| 0 failed` | `.tools/p5-coord-deno-full3.txt` and, after restoring the mutated file, `.tools/p5-coord-deno-restored.log` (both 150/0) |
| 4 | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed` | `.tools/p5-coord-deno-sql05.log` |
| 5 | `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` (from `android/`) | 0 | `BUILD SUCCESSFUL in 50s`, `182 actionable tasks: 182 executed` | `.tools/p5-coord-gradle-run1.log` |
| 6 | `bash .tools/p5coord_chain.sh p5rpc_full9 <log>` — the documented `psql -f` chain, 33 files, fresh database | 0 | `CHAIN p5rpc_full9 … EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0` | `docs/evidence/phase5/logs/p5coord-chain-run9.log` |
| 6b | same chain, re-run as the **last** action of the phase, after the SQL-05 header citation fix and the manifest corrections | (see §4c) | (see §4c) | `docs/evidence/phase5/logs/p5coord-chain-run10.log` |

### 4b. Why these are "current" results and not history (brief §13)

Each suite was re-run **after** the last change to the sources it exercises. The
ordering was measured, not assumed (`ls -l --time-style` on every changed path vs
the log mtimes):

| Suite | Newest change to a source it compiles | Run time | Margin |
|---|---|---|---|
| Deno | `supabase/functions/device-command/handler_test.ts` 14:12 | 15:00 / 15:09 | ≥ 48 min |
| Flutter + `dart analyze` | `test/features/settings/export_result_dialog_test.dart` 14:26 | 15:23 / 15:26 | ≥ 57 min |
| Gradle | `android/app/src/test/kotlin/…/EnforcementModeTest.kt` 13:47 | 15:10 | ≥ 83 min |
| SQL chain | `supabase/migrations/20261030000300_retention_sweep.sql` 15:48 | 15:51 | 3 min |
| SQL chain (final) | SQL-05 header citation edit (this section's own phase) | run10, last action | see §4c |

What changed **after** those runs is documentation only (`docs/implementation/**`,
the SQL-05 file header comment, and this pack). The chain is re-run at the close
precisely because one of those "documentation only" edits is inside a migration
file that the chain executes — a comment cannot change behaviour, but "cannot" is
not evidence, and run10 is.

### 4c. Final chain re-run (the closing measurement)

`PGPORT=55581 bash .tools/p5coord_chain.sh p5rpc_final1 docs/evidence/phase5/logs/p5coord-chain-run10.log`
→ harness exit 0, and inside it
`CHAIN p5rpc_final1 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0`,
with the pass NOTICEs now at their true positions (`74…:934`, `75…:185` and `:216`,
`71…:605`, `76…:773`). Re-checked on that fresh database: 19 public tables, 66
public indexes, `webrtc_signals_session_sequence_uniq` present, and
`delete_safe_zone_audited(uuid,uuid)` reporting `secdef=true`,
`cfg=search_path=public, private, pg_temp`, `anon=false`, `authed=false`,
`srv=true`, `acl={postgres=X/postgres,service_role=X/postgres}`.

Each chain run needs a **freshly created database** — the chain is not
re-runnable into one, because `tests/74` re-inserts fixed `auth.users` ids and
violates `users_pkey` on the second pass. That is a property of the test fixtures,
not of the migrations.

### 4d. Counts, cross-checked two ways

- Deno: **150** declared `Deno.test(` cases across `supabase/functions/**/*_test.ts`
  == **150** reported passed by the runner. Static and executed counts agree.
- Flutter: the runner reports **408** passed. A static count of line-initial
  `test(`/`testWidgets(` under `test/` gives **387**; the gap is cases generated
  inside loops/`group` bodies that the line-anchored grep cannot see. **The runner
  number is the one quoted**; the 387 is disclosed so nobody re-derives it and
  calls the difference a discrepancy.
- Gradle: 6 result classes, **39** tests, 0 failures, 0 errors, 0 skipped, read out
  of the JUnit XML itself (`docs/evidence/phase5/gradle-junit/`), not from the
  console summary. Note that Gradle writes this project's test results to the
  repo-root `build/app/test-results/testDebugUnitTest/`, not `android/app/build/`.
- SQL: 33 `-f` entries = 14 migrations + 19 test files (including the two local
  `auth` / `realtime` stubs the chain needs on a bare PostgreSQL). Final green
  database: 19 public tables, 66 public indexes.

---

## 5. Workstream-by-workstream: what was implemented and what was tested

### 5a. PRIV-01 (A) — child/device-scoped retention report · IMPLEMENTED + TESTED — UNAPPLIED

Server (`supabase/functions/account/retention.ts`, `index.ts`):

- every payload carries an explicit `scope` token — `family`, `device` or
  `not_reported`; the three states are declared, not inferred from absent fields;
- **project-wide sweep totals are returned to the family-owner parent only**; a
  non-owner parent gets the per-family counts and the `last_sweep` timestamp but
  **no** global totals, a child gets device-scoped counts and **no** sweep object
  at all, and a wrong-family / unauthenticated / profile-less / role-mismatch
  caller lands in `not_reported` with no counts;
- service-role access stays server-side: the client never receives a service-role
  token and the sweep read is not exposed through any new RPC.

Tests: `supabase/functions/account/scope_test.ts`, **17 cases**, all executed green
inside row 3 above. Their names are the requirement list, so they are quoted rather
than paraphrased: owner / non-owner-parent redaction / child device scope /
wrong-family caller / unauthenticated / missing-or-unexpected profile role /
profile-role-vs-membership disagreement / unreported-family widening attempt, then
count and payload assertions (`payload: the family owner alone receives the
project-wide sweep totals`, `payload: a child report has device counts and no
sweep at all`, `payload: not_reported carries no counts, no families and no
sweep`).

UI (`lib/features/settings/*`, `test/features/settings/retention_scope_disclosure_test.dart`,
**11 cases**): the disclosure renders the scope in words — a family scope claims
the family and shows the sweep marker, a family scope without a marker says it was
never recorded, a device scope limits the counts and withholds the marker,
`not_reported` says the server reported nothing, "no report yet" is its own state
and never reads as a family claim, and an account with no family linked says so
instead of showing empty counts. `DataScope.parse` treats absent, malformed and
non-string tokens as `not_reported` (three dedicated cases) and the token survives
the `fromJson` round trip.

Status: **IMPLEMENTED, TESTED, UNAPPLIED** (Edge Function code is not deployed —
§12).

### 5b. SQL-06 — contract wording · IMPLEMENTED (doc) + re-verified against source

`docs/implementation/api-contract.md` §5 carries the owner-approved wording, and
every citation in it was re-opened and checked rather than copied from the draft:
the duplicate pre-check is `20261030000200_phase1_authorization.sql:478-486`, the
skip NOTICE is `:492`, and the "reported, never deleted" contract is `:474`.
`tests/75_signaling_replay_index_duplicate_guard.sql` (218 lines) stays in the
chain and still asserts the duplicate case leaves the unique index **absent**; it
was not weakened. `tests/71_phase1_rollback_privileges.sql` was **not** weakened —
see §6 for how it was extended instead.

`docs/implementation/remaining-gaps.md` got two dated corrections, not rewrites:
the `session_nonce documentation` row is now CLOSED with the earlier over-claim
explicitly retracted, and the `webrtc_signals unique index effectiveness` row now
cites the real lines instead of a guessed range.

### 5c. SQL-05 — atomic audited zone delete · IMPLEMENTED + TESTED — UNAPPLIED

New migration `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql`
(263 lines; SHA-256 `4fdf1cfb25606b6893b08738efa45b2c233ff7f6a9f9453351c9c221698bfffc`
as frozen in the 57-path baseline digest and as the staged index blob today —
the **worktree file at the close of the phase hashes `a1d7d60954bc61dc…`**, after
the EV-02 header-citation fix; re-measure before use, see §8a) defining
`public.delete_safe_zone_audited(uuid zone, uuid actor) → jsonb`.

- **Trusted actor attribution preserved**: the actor arrives as a parameter filled
  from server-side JWT validation (`_shared/auth.ts:80-127 requireUser`), and the
  function never reads `current_setting('request.jwt.claim.sub')`, which is
  client-settable over PostgREST. Authorization goes through
  `private.is_parent_of_family(uuid, uuid)` (created by the Phase 1 migration at
  `:186-206`), the same pattern `revoke_device` uses.
- Delete + audit in **one function body** → one statement → one transaction. Guard
  order: NULL actor → `not_family_parent` (42501); zone resolution `for update`;
  soft-deleted family → `family_unavailable` (42501); zero rows → returns
  `{status:"already_gone", audited:false}` **before** any audit write.
- Privileges: `revoke … from public, anon, authenticated` + `grant … to
  service_role`. Measured on the green disposable database:
  `proacl = {postgres=X/postgres,service_role=X/postgres}`,
  `prosecdef = t`, `proconfig = {"search_path=public, private, pg_temp"}`,
  `anon_execute = f`, `authenticated_execute = f`, `service_role_execute = t`.
  Not client-callable, so `api-contract.md` §7's no-new-client-RPC rule is
  unchanged; §6 of that file now documents the RPC.
- `family-admin/index.ts:214-262` calls the RPC and maps `zone_not_found`→404,
  `not_family_parent`/`family_unavailable`→403, anything else→500
  `internal_error` with the zone kept; `deleted` and `already_gone` both return
  `{deleted:true}`. **No client-visible envelope change.**
- The Phase 3 stopgap `delete_zone_atomicity.ts` is no longer wired into the
  handler (only its `ZoneSnapshot` type is still imported, `index.ts:21,195`); the
  module and its 8 tests stay in the tree as the quarantined fallback. Three
  outcomes it used to produce — `audit_failed` compensation, `zone_restored`,
  `delete_unaudited` — are now unreachable from the `delete_zone` path; recorded
  as a residual in `phase-5-open-gaps.md` (GAP-RS-01).

Tests: `supabase/tests/76_zone_delete_atomic_rpc.sql` (773 lines) — success, audit
failure, authorization failure, zero-row/`already_gone`, plus privilege and
envelope pins; executed green inside the chain (run9 NOTICE at `tests/76…:773`).

Chain integration, and the reason `tests/71` changed: test 71 §5 re-forwards the
real RPC migration as part of its rollback-privilege checks, so a *variant* passed
as the chain's migration is silently re-created back to the correct body before
76 ever runs — the first lossy-RPC negative control therefore came back **green**,
which would have been a false PASS. Test 71's forward-reference name list was
extended (five names, step R1' drop, body count pin 4→5) and the harness was
rewritten to inject the variant immediately before `tests/76`. Test 71 was not
weakened: it still asserts the same privilege and rollback properties, and the
body-count pin got stricter.

### 5d. TEST-01 — handler extraction + dependency injection · IMPLEMENTED + TESTED

Six-step refactor executed as written up in `_work/p4-test01.md`:
`supabase/functions/device-command/handler.ts` (449 lines) now takes explicit
injected dependencies (RPC client, audit writer, clock, UUID generator) instead of
reading environment globals; `index.ts` is a thin adapter;
`supabase/functions/_shared/fake_postgrest.ts` (643 lines) is the fake used by the
tests. No environment-flag shortcuts were added. Authorization checks and the
response envelope are behaviour-preserved — the tests, not the diff, are the
evidence.

Tests: `device-command/handler_test.ts` **24 cases** (green in row 3), covering the
authorization matrix and the write ordering, including two cases that only fail if
the authorization call is actually executed: `a parent of another family cannot
command this device, and nothing is written` (`:219`) and `a soft-deleted family is
forbidden before the membership read` (`:239`). Wiring pins are in
`supabase/functions/handler_wiring_test.ts` (5 cases), which assert that the real
`index.ts` is built on the extracted handler rather than a parallel copy.

### 5e. PERF-01a / SQL-04 — retention sweep batch shape · IMPLEMENTED + TESTED; bounded execution STOPPED

`supabase/migrations/20261030000300_retention_sweep.sql` now uses, for
`webrtc_signals` and `audit_logs`:

```sql
delete from t a
where a.id = any (array(select id from t
                       where created_at < v_now - interval '…'
                       limit v_batch))
```

The `id = any (array(select … limit v_batch))` shape is the point: the previous
`using (…) doomed` form deleted the same rows but hash-joined the target against a
**full sequential scan** of the table (measured in Phase 4: rows=140 006 /
rows=200 026), so the old comment's claim that "at most 10 000 rows are looked up
and deleted per DELETE" over-described the lookup side. SWP-01's comment is
corrected in place and now carries the provenance of the numbers it quotes
(Phase 4 A/B probe, `_work/p4-perf01.md` §2-§3, `.tools/p4d-ab-backlog.log`,
`.tools/p4d-equiv.log`, disposable PostgreSQL 16 — **not** the hosted planner) and
states plainly that what Phase 5 re-measured is behaviour, not timing.

Behavioural assertions replaced text matching. `supabase/tests/74_sweep_indexes_and_repeatability.sql`
§5 captures the deleted **row set** of both shapes into `p574_cap` and asserts they
are identical, in the same batch **order**, and repeatable. Two findings here
matter more than the green run:

1. **Section 5 had never executed before this phase.** The pre-Phase-5 chain logs
   print the pass NOTICE as raised from `tests/74…:440`, while the shipped file is
   934 lines — i.e. the file "passed" while ending at line 440 of its own log
   reference; today the NOTICE is printed at `:934`. Section 5 contained two real
   syntax errors that would have aborted any execution: a table alias carrying
   type definitions (`) as t(run_a integer, run_b integer, lbl text)` → bare
   column names), and a data-modifying `WITH` nested inside an `INSERT`'s own
   `SELECT` (must be hoisted above the `INSERT`). Both were proven in `psql`
   before and after the fix.
2. Fixing them is the difference between "the approved shape is asserted" and
   "an assertion existed and never ran".

The **bounded-execution half of SQL-04 stays refused** (owner ruled "faster shape
only, keep the function"). Nothing in this phase commits partial progress: one
call is still one transaction over the whole backlog, all-or-nothing, and the
migration comment says so instead of implying otherwise. **No cron job was
installed** — not locally, not hosted; the brief forbids it without separate
authorization and none was given.

### 5f. KOT-02 (A) — pure enforcement-mode function · IMPLEMENTED + TESTED

`android/app/src/main/kotlin/com/parentcontrol/parent_control/EnforcementMode.kt`
(new) exposes `EnforcementMode.of(isDeviceOwner: Boolean, isAdminActive: Boolean): String`.
Both former copies now delegate to it — `PolicyApplier.kt:228-234` (`enforcementMode()`
for the policy ack) and `GuardianService.kt:668-670`, whose call site is the
heartbeat capability object at `GuardianService.kt:503` — so the ack and the
heartbeat cannot drift. `EnforcementModeTest.kt` (4 JVM cases) pins the truth
table. No Robolectric and no Mockito were added (option B was not approved);
`android/app/build.gradle.kts` is unchanged. Full `:app:testDebugUnitTest` green:
6 classes / 39 tests / 0 failures.

### 5g. GOV-02 — abandoned-session representation · RATIFIED, no code change

The owner ratified the existing pair as-is, so **nothing was implemented**. What
Phase 5 did was check the consumers, because "ratified" without a consumer list is
an unverifiable claim: `ended_by` / `ended_reason` are written by
`20261030000100:26-29,127,148`; read server-side by
`supabase/functions/remote-session/guard.ts:133,150,153`; and in Dart by
`remote_session.dart:88,110,189,209`, the display-only
`child_session_page.dart:737-738` and `remote_session_controller.dart:715`. **No
Dart consumer reads `endedBy` for logic** — display only. Recorded in the decision
log with those citations.

### 5h. SQL-01 / R3 — de-hardening rollback statements · STOPPED, quarantined

The owner ruled R3 is never sanctioned. The unsafe rollback statements remain
quarantined in the proposals/notes layer, none was executed, and none was executed
"to see what happens" against hosted data — the brief's §5 prohibition is absolute
and is recorded as obeyed by non-action. The only rollback text this phase touched
is documentation of what must **not** be run (`deployment/manifest.md` §4, whose
rollback is a `drop function` on a locally-tested-only object).

### 5i. EVD-01 — evidence pack · PREPARED, NOT COMMITTED

`docs/evidence/phase5/` — `MANIFEST.md` plus 11 logs, 6 Gradle JUnit XML files and
the per-file digest table. Gradle JUnit XML preserved verbatim (not summarised),
SHA-256 for every packed artifact (§8 of the manifest), exact commands with exit
codes (§2 of the manifest). A pattern scan for `eyJ…`, `service_role_key`,
`SUPABASE_KEY`, `password` and long `Bearer` strings over every log found **zero**
matches before packing, so no credential is in the pack. It was **not committed**:
the owner's Gate A ruling (#10, "no commit") outranks ruling #12, and the conflict
is disclosed instead of resolved silently.

---

## 6. Negative controls actually measured

A green suite is not evidence unless red is reachable. Both controls were executed
on this tree, and one of them exposed a harness defect that would otherwise have
made a Phase 5 claim false:

| Mutation | Where | Result |
|---|---|---|
| `await assertFamilyParent(…)` commented out in `supabase/functions/_shared/auth.ts:270` | `deno test --allow-read supabase/functions/device-command/handler_test.ts` | **FAILED \| 22 passed \| 2 failed**, failing exactly the two cross-family / soft-deleted-family cases (`handler_test.ts:219`, `:239`). File restored byte-identical afterwards (`git diff --stat` clean on that path), then the full Deno suite re-run green. |
| RPC body made lossy (audit insert moved outside the atomic path) and injected into the chain immediately before `tests/76` | full 33-file chain | **EXIT=3, `ASSERT_FAILED=1`** at `supabase/tests/76_zone_delete_atomic_rpc.sql:411` — `ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded`. |

The first attempt at the SQL-05 control ran the variant **as the chain's migration
argument** and came back green — because `tests/71` §5 re-forwards the real
migration and silently overwrote the variant before `tests/76` executed. That
false PASS was caught, the harness was changed to inject immediately before `76`,
and the control was then measured red. This is disclosed because it means an
earlier "green" chain log of that shape proves nothing; `logs/p5coord-chain-negative3.log`
is the one that counts.

---

## 7. Gate B: Android device execution · STOPPED (not authorised)

The owner declined device execution for this phase. Therefore:

- no APK was built for testing, no emulator or physical device was booted for
  validation, no `adb` command was run against a QA device;
- **no device row is marked PASS** in `phase-5-regression-matrix.md` — every
  Android/device row is `NOT RUN`, with the reason;
- force-stop, permission revocation, notification visibility and child-consent
  behaviours remain unverified by execution; none was bypassed, because none was
  attempted.

The Phase 4 validation plan (`phase-4-android-validation-plan.md`) remains the
ready-to-execute artifact for whoever authorises Gate B; Phase 5 changed the
Kotlin enforcement-mode source, which is a reason to re-run the enforcement rows
of that plan, not a reason to claim they were run.

---

## 8. Evidence-integrity defects found and fixed in this phase

Found by checking citations rather than trusting them. Each is fixed in the tree;
none is a silent rewrite of history — corrections are dated and keep the earlier
text visible.

| ID | Defect | Fix |
|---|---|---|
| EV-01 | `tests/74` §5 — the approved-shape behavioural assertions had never executed (NOTICE `:440` vs a 934-line file), and contained two syntax errors. | Both errors fixed and proven in `psql`; §5 now executes; run9 NOTICE at `:934`. |
| EV-02 | `20261103000100` header cited `docs/implementation/_work/p5-sql05.md`, a file that does not exist. | Citation repointed to the real artifacts: `docs/evidence/phase5/MANIFEST.md` §2 rows 9-10 and §3, with the log names. |
| EV-03 | `deployment/manifest.md` published three migration SHA-256 values, none of which matches anything on this tree. Measured both bases: worktree and HEAD blob. Files 1–2 hash identically on both bases (so this is stale content, not a line-ending artifact); file 3 differs from HEAD because of Phase 5's PERF-01a edit. | §0.1 dated re-measure table added with the actual values and the exact command form; the Phase 1 table kept visibly in place. |
| EV-04 | The manifest only ever checked the replay-protection index **after** applying, and treated a `0` as a curiosity. A `0` is produced by two different paths (duplicate-guard skip, or the file never running). | §2 gained a mandatory **pre-apply** duplicate-count query (`deployment/manifest.md` §2) with stop-and-escalate instructions, matching the approved SQL-06 wording. |
| EV-05 | Phase 4's delivered digest was computed 1–2 minutes **before** the last write of two of the files it describes (§1a). | Attributed with mtimes, and Phase 5's own digest is taken as the closing action (§2a). Logged as GAP-EV-05. |
| EV-06 | `phase-4-owner-approval-register.md` cited `android/app/src/main/java/…` (the real tree is `src/main/kotlin/…`) and still said `git diff HEAD --stat -- android/` is empty and KOT-02 is "AWAITING OWNER" — true in Phase 4, false on this tree. | Dated corrections appended in place; the original sentences remain visible. |
| EV-07 | `docs/implementation/_work/p4-enf-residual.md:14` contains a runnable-looking `git show HEAD:lib/…/app_restrictions_controller.dart` whose path uses an ellipsis and would fail if pasted. | Left as-is (it is a scratch note, not a deliverable) and recorded as GAP-EV-06 so it cannot be mistaken for a command that works. |

| EV-08 | **Two numbers this phase itself published were not reproducible.** (a) An early draft of §1/§1a quoted `587a197eb51ca92b59dedc652dd2a3b4269f879e539d8ae89bbd248463f1f4e2` for the 29-path Phase 4 re-hash; it matches none of the six bases tried (§1a). (b) The evidence `MANIFEST.md` §5 carried forward Phase 4's "CRLF warned for 15 of these paths"; CR-byte counting gives **1** on the baseline set, **7** on the final set, and `i/lf w/lf` gives 56 — no basis yields 15. | Both withdrawn in place, with the alternative-basis numbers printed next to the withdrawal so a reader can re-run them; replaced by the measured `6d717835…` and by the counted CRLF bullets in `MANIFEST.md` §5. |
| EV-09 | `MANIFEST.md` §2 rows 3–5 embedded runner output containing raw `\|` characters inside Markdown table cells, so the commands column rendered as a broken table — the exact evidence a reviewer would read first. | Cells escaped and the table re-rendered; row 11 (the closing chain re-run) added in the same pass. |

Residual scan result, stated rather than hidden: a mechanical check of every
`docs/ supabase/ lib/ android/ test/ .tools/` path cited inside the changed files
(284 distinct references) still reports non-existent paths, and all of them are
either ellipsis placeholders (`android/…/GuardianService.kt`) or Phase 1–3 era
citations to test files that have since moved. Those predate this phase; the ones
this phase introduced (EV-02, EV-06) are fixed above.

---

## 9. Controlled QA readiness — what a QA tester can actually run today

Nothing here is deployed. The honest state is "the repository is testable, the
service is not reachable":

| Can be run now, locally, by anyone with the toolchain | Cannot be run without owner action |
|---|---|
| `dart analyze`, `flutter test` (408), `deno test --allow-read supabase/functions/` (150) | Any Edge Function call against a real project |
| `./gradlew :app:testDebugUnitTest` (39) | Any device behaviour (Gate B) |
| the 33-file SQL chain on a disposable PostgreSQL 16 (`supabase/tests/README.md`) | Any assertion about hosted indexes, grants or rows (HOST-01) |
| `tests/76` atomicity proof and its negative control | Applying `20261030000300` / `20261103000100` to the hosted project |

---

## 10. Deviations from the brief, stated plainly

1. **"use 8 subagents" was not satisfiable.** The session's sub-agent credit was
   exhausted; every workstream in §5 is coordinator-executed and single-threaded.
   The Phase 4 fan-out failure (`phase-4-report.md` §6) repeated here in a
   different form: less parallelism, but no unreviewed agent output was adopted.
2. **Ruling #12 (commit the evidence) was not executed** because ruling #10 forbids
   committing anything. Silence would have been the worse option; the conflict is
   recorded in `phase-5-owner-decision-log.md` and the artifacts are prepared so a
   single `git add docs/evidence/phase5 && git commit` by the owner completes it.
3. **One more chain re-run than strictly needed** (§4 row 6b), because a comment
   edit inside an executed migration file is exactly the kind of change a "it's
   only a comment" argument would wave through.
4. **Phase 5 touched files Phase 4 owned** (`tests/71`, `tests/README.md`,
   `deployment/manifest.md`, `phase-4-owner-approval-register.md`). All four were
   required by approved decisions (SQL-05 chain integration, SQL-06 pre-apply
   check, the manifest's own stale hashes, and a status that had become false), and
   all were annotated rather than rewritten.
5. **The phase's own digest procedure failed three times before it worked** (§2a:
   four readings of a 69-path aggregate, the last one frozen). Nothing outside the
   report and the evidence manifest depended on the intermediate values, and no
   hashed file was edited after the final table was written — but the correct
   behaviour was reached by iteration, not by design on the first pass, and §2a
   publishes every superseded value rather than only the last one.
6. **Two numbers this phase published had to be withdrawn** as
   non-reproducible (§1a's `587a197e…`, `MANIFEST.md` §5's inherited 15-path CRLF
   count), each replaced by a counted value with the command shown.

---

## 11. Completion-gate self-assessment against the brief

| Brief requirement | Status |
|---|---|
| §2 never use reset/clean/stash/destructive checkout/restore | **OBEYED** — none run; §2 records the observed index movement instead of "fixing" it |
| §2 no commit/push/branch/stage without explicit approval | **OBEYED** — no commit, no push, no branch; no `git add` run by this phase |
| §3 stop if an approval is missing | **OBEYED** — refused items were stopped, not approximated (SQL-04 bounded execution, Gate B, option B for KOT-02, R3) |
| §4 PRIV-01 A + WORD-02 + server/UI tests | **DONE** (§5a) |
| §5 GOV-02 approved representation only; SQL-01/R3 quarantined; SQL-06 wording + duplicate pre-check kept; `tests/75` kept; `tests/71` not weakened; disposable DBs only | **DONE** (§5b, §5g, §5h, §6) — `tests/71` extended, not weakened |
| §6 approved DELETE shape, SWP-01 comment corrected, behavioural assertions, plans/order/repeatability; RPC signature untouched; **no cron** | **DONE** (§5e) — signature unchanged, no cron installed anywhere |
| §7 reviewed migration, trusted actor attribution, atomic delete+audit, `family-admin`, four executable test classes, handler wiring tests | **DONE** (§5c) |
| §8 six-step refactor, explicit DI, real handler tests, no env-flag shortcuts, envelope preserved | **DONE** (§5d) |
| §9 pure `EnforcementMode.of`, JVM tests, both call sites, full `:app:testDebugUnitTest`, **no Robolectric/Mockito** | **DONE** (§5f) |
| §10 Gradle XML preserved, digests, exact commands, **no credentials**, no wholesale `.tools`/build-output commit | **DONE** (§5i) — nothing committed at all |
| §11 Gate B only with AND-01; no device row PASS without evidence | **OBEYED** (§7) — no device row PASSes |
| §12 no migration apply / deploy / Supabase setting change / cron / production write or deletion | **OBEYED** — zero hosted calls; HOST-01 remains open |
| §13 re-run every relevant suite with exact commands and exit codes; don't pass off history as current | **DONE** (§4, §4b, §4c) |
| §14 five deliverables, each item labelled | **DONE** — the five files named in §12 below |
| §15 HOST-01 not falsely reported as fixed; no auto-commit/push/deploy/next phase | **OBEYED** — HOST-01 is open in all five deliverables; phase stops here pending authorization |

---

## 12. Where everything lives

| Deliverable | Path |
|---|---|
| This report | `docs/implementation/phase-5-report.md` |
| Regression matrix | `docs/implementation/phase-5-regression-matrix.md` |
| Open gaps | `docs/implementation/phase-5-open-gaps.md` |
| Owner decision log (all 12 rulings + the two conflicts) | `docs/implementation/phase-5-owner-decision-log.md` |
| Deployment readiness | `docs/implementation/phase-5-deployment-readiness.md` |
| Evidence pack | `docs/evidence/phase5/MANIFEST.md` (+ `logs/`, `gradle-junit/`, `tree-digest.txt` = the 57-path baseline, `tree-digest-final.txt` = the 69-path close) |
| Deployment manifest corrections | `docs/implementation/deployment/manifest.md` §0.1, §2 pre-apply check, §4 |
| Phase 4 register, dated corrections only | `docs/implementation/phase-4-owner-approval-register.md` (KOT-02 block — see §1a for why its hash moved) |

**Phase 5 stops here.** No deploy, no commit, no push, no next phase without
explicit owner authorization.
