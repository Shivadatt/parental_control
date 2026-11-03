# Phase 4 — Workstream A: DOC-01 sweep + SQL-06/SQL-06a guard (notes)

Workstream A of the Phase 4 fan-out. Date **2026-11-03**. Tree: current working tree (shared with
six concurrent workstreams; every file below was re-read at edit time). Status vocabulary per the
brief: PASS / PASS (SCOPED) / MITIGATED / BLOCKED / NOT RUN / STOPPED / AWAITING OWNER. No `git`
mutation, no Supabase CLI, no hosted access, no `flutter build`, no cron. All work executed against
**my own** disposable cluster `.tools/pgdata_p4a` (port **55462**); `.tools/pgdata_p2`,
`.tools/pgdata_p3a`, `.tools/pgdata_p3b` were never opened or touched.

## 1. DOC-01 — stale flagless Deno command

### 1.1 Verified root cause (re-read, 2026-11-03)

The brief's hypothesis was that "the function tests read migration/SQL source files from disk".
**That is not the real reason, and the docs do not say it.** What the tests actually read are
**Edge Function TypeScript handler sources**, via `Deno.readTextFile` / `readTextFileSync`:

| Test file | Reads | Evidence (read this session) |
|---|---|---|
| `supabase/functions/handler_wiring_test.ts` | six `.ts` sources: `./device-command/index.ts`, `./family-admin/index.ts`, `./_shared/auth.ts`, `./remote-session/index.ts`, `./account/index.ts` | `:24-29` helper (`Deno.readTextFile`), call sites `:73, :107, :163, :175, :203, :235`; header `:11-14` states the flag is required so failures are loud, not silent |
| `supabase/functions/_shared/error_mapping_test.ts` | `../device-policy/index.ts`, `../device-command/index.ts`, `../pairing/index.ts` | `:50-52` (`source()` → `Deno.readTextFile`), `:545-550` (`Deno.readTextFileSync` loop) |
| `supabase/functions/family-admin/delete_zone_atomicity_test.ts` | `./index.ts` | `:241` |

A grep for `readTextFile|Deno.open|readDir` over `supabase/functions/**` returns exactly these three
test files — **no function test opens a `.sql`/migration file**. Without `--allow-read` Deno denies
filesystem reads by default, so the source-pinning tests throw instead of silently skipping.

### 1.2 Primary fix — `docs/implementation/regression-matrix.md:24`

- Exact command cell changed `deno test supabase/functions` → **`deno test --allow-read supabase/functions/`**.
- The recorded negative control is **preserved verbatim**: `FAILED \| 83 passed \| 5 failed`, exit 1
  without the flag / `88 passed \| 0 failed` with it, and the original 2026-10-30 PASS row
  (`83 passed, 0 failed`, exit 0, per-directory breakdown, log path) — now explicitly labelled
  "as executed 2026-10-30 with the then-documented flagless command".
- The in-cell explanation now names the real reason (table above) and states the migration/SQL-file
  claim is false.
- **Status: PASS (doc edit landed).** The 83/88 numbers are historical records, not re-measured here;
  my re-measurements are in §1.4.

### 1.3 Full sweep — every `deno test` hit in `docs/**.md` and its disposition

Grep `deno test` over `docs/` (all `*.md`, run 2026-11-03): 30+ hits. Policy applied here:
commands presented as **runnable/recommended** get the flag rewritten in; **historical
as-executed evidence** keeps its original command (rewriting an executed command would falsify the
record) and gets a dated `(2026-11-03 DOC-01)` note with the corrected invocation; **negative-control
records of the flagless failure are kept intact everywhere** (they are the measurement itself);
invocations that provably need no flag are left and verified.

| Occurrence | Disposition |
|---|---|
| `implementation/regression-matrix.md:24` | **REWRITTEN** to `deno test --allow-read supabase/functions/` (§1.2) |
| `implementation/phase-2-regression-matrix.md:18, :21`; `implementation/phase-3-regression-matrix.md:12-15`; `implementation/phase-3-report.md:160-163`; `implementation/phase-2-report.md:192`; `_work/p3-audit-atomicity.md:107-108`; `_work/p3-followups.md:207` | already `--allow-read` — untouched |
| `implementation/phase-2-regression-matrix.md:22` (negative control), `implementation/phase-2-open-gaps.md:49`, `implementation/phase-3-open-gaps.md:29`, `_work/p3-followups.md:22` | **PRESERVED** — flagless text records the measured `FAILED \| 83 passed \| 5 failed` control |
| `implementation/phase-2-report.md:166-169` | negative-control paragraph preserved; appended dated "[2026-11-03, Phase 4-A: DOC-01 closed — the *Exact command* cell at `regression-matrix.md:24` now reads …]" marker |
| `implementation/phase-3-regression-matrix.md:47` (DOC-01 row) | status `OPEN (one-cell docs edit)` → `CLOSED 2026-11-03 (Phase 4-A)` appended; original Phase 3 observation text kept |
| `docs/backend.md:700` (run-it-like-this block) | command line kept as the 2026-10-27 record; **dated in-block comment added** giving the correct `--allow-read` invocation for today (result line `36 passed, 0 failed` unchanged) |
| `docs/bug-report.md:988`, `docs/verification-report.md:347 (annotated at :353)`, `:510 (annotated below block)`, `:778 (annotated after sentence)`, `docs/mic_full_audit_report.md:74`, `docs/stage2_background_audio_report.md:139`, `docs/stage5_background_audio_survival_report.md:127`, `docs/stage6_account_and_media_recovery_report.md:186`, `docs/runtime-mic-test-report.md:243` | dated DOC-01 notes added; **every recorded number byte-identical** (36/0, 47/0, exit codes, DENO_TEST_EXIT=0) |
| `implementation/phase-1-report.md:198`, `implementation/_work/security.md:43` | dated note: the `family-admin` flagless run is stale (directory gained `delete_zone_atomicity_test.ts` reading `index.ts`); "4 passed" kept; corrected invocation given (12/0 with flag is the Phase 3 measurement at `phase-3-report.md:162`) |
| `docs/stage4_parent_controlled_session_lifetime_report.md:137` (`deno test supabase/functions/remote-session/guard_test.ts`) | **LEFT AS-IS — measured today still green flagless**: `ok \| 11 passed \| 0 failed`, exit 0, `.tools/p4a-deno-guard-only.log`; `guard_test.ts` reads no files |
| `docs/pairing-recovery-fix-report.md:83` (`--allow-all --no-check`) | `--allow-all` already implies read — untouched |
| `docs/bug-report.md:882` ("`deno test` passed 36 shared tests"), `docs/verification-report.md:415` ("Local `deno test` 36/36"), `_work/coordinator-contract.md:27` ("`deno test <specific file>` is allowed") | prose/policy mentions, not invocations — untouched |

No `supabase/**` test file was edited for DOC-01 (the tests already document the flag in their own headers).

### 1.4 Fresh measurements (this session, current tree)

| Command | Exit | Observed | Log |
|---|---|---|---|
| `deno test supabase/functions` (flagless) | **1** | `FAILED \| 98 passed \| 11 failed (1s)` — the 11 are 5×`handler_wiring_test.ts`, 4×SQL-03 source-level cases in `_shared/error_mapping_test.ts`, 2×`[source-level]` cases in `family-admin/delete_zone_atomicity_test.ts` | `.tools/p4a-deno-flagless.log` |
| `deno test --allow-read supabase/functions/` | **0** | `ok \| 109 passed \| 0 failed (1s)` | `.tools/p4a-deno-flagged.log` |

(11 failing today vs Phase 2's 5 = the two Phase-3 file-reading test files; numbers for the older
runs in the docs were left untouched, as required.)

## 2. SQL-06 / SQL-06a — the (session_id, sequence) index disagreement

### 2.1 Re-derived facts (all read this session, not carried from Phase 3)

- Migration `supabase/migrations/20261030000200_phase1_authorization.sql` section 8 (`:469-495`):
  duplicate guard `:478-486`; when **no** duplicates → `create unique index if not exists
  webrtc_signals_session_sequence_uniq` via EXECUTE (`:489-490`); when duplicates **pre-exist** →
  only `raise notice 'duplicate sequences exist; index skipped'` (`:492`). Header `:472-474`:
  duplicates are expected only from imports/pre-identity schemas; "Duplicates are reported, never
  deleted." The rollback state table `:36-47` (row `:44`) records `ABSENT → PRESENT / PRESENT`,
  i.e. it describes the **no-duplicate** path as if unconditional.
- `supabase/tests/70_phase1_authorization.sql:436-451` mirrors the same `if not exists (duplicates)`
  and asserts index presence **only in the no-duplicate branch** → passes either way.
- `supabase/tests/71_phase1_rollback_privileges.sql:194-197` asserts, **with no duplicate guard**,
  that the snapshot value of `index|webrtc_signals_session_sequence_uniq` (`<> 'ABSENT'`), where the
  captured value is `coalesce(to_regclass(...)::text, 'ABSENT')` (`:130-133`).
- `20260101000000_core.sql:358-370`: `sequence bigint generated always as identity` (`:366`),
  non-unique `webrtc_signals_session_sequence_idx (session_id, sequence)` (`:369-370`).

**What the migration actually does when duplicates pre-exist: skips creation quietly with a NOTICE;
the apply does not abort; no rows are deleted.** That is the behaviour the new guard encodes. Verdict:
**PASS (SCOPED — re-derivation)**: Phase 3 §3's finding is confirmed line-by-line.

### 2.2 Deliverable (a) — the guard

New file **`supabase/tests/75_signaling_replay_index_duplicate_guard.sql`** (my own file; README and
tests 70/71 untouched — no existing assertion was weakened or edited). It exercises the **real
migration file** (re-applied with `\i`, the same mechanism 71 uses at its RE-FORWARD `:543`), so it
cannot drift from production SQL. Sections:

1. FORWARD / no duplicates (chain state): asserts the unique index **exists**, zero duplicate
   `(session_id, sequence)` groups, and the legacy non-unique index is still present (additivity,
   migration `:497-499`). Keeps 71's claim for the case 71 actually documents.
2. PRE-EXISTING DUPLICATES, inside one transaction, fully rolled back: drops the unique index,
   inserts two rows sharing `(session_id, sequence)` via `OVERRIDING SYSTEM VALUE` (the documented
   import/restore path for `GENERATED ALWAYS` identity), asserts the precondition, re-applies the
   real migration, then asserts: (a) index **still absent** — creation was skipped, not forced, and
   the apply survived (`ON_ERROR_STOP=1` proves no abort); (b) the duplicate rows **survive** —
   row count is exactly pre-guard + 2, i.e. nothing deleted; (c) the exact 71 predicate
   `coalesce(to_regclass(...)::text,'ABSENT')` evaluates to `'ABSENT'` — the measured proof that
   71's unguarded forward assertion fails on a duplicate DB. It never claims the index exists here.
   The migration's NOTICE text cannot be captured by an SQL assertion in psql — honestly excluded;
   it was verified by grep of the run logs instead (§2.4).
3. After `ROLLBACK`: chain end-state restored — index present again, zero duplicate groups, row
   count back to the pre-guard value, so 72/74/45 and the README 19-table check keep their meaning.

Status: **PASS** (validated, below).

### 2.3 Deliverable (b) — validation on my own cluster

Cluster: `.tools/pgsql16/pgsql/bin/initdb.exe -D .tools/pgdata_p4a -U postgres --auth=trust` →
`INITDB_EXIT=0` (`.tools/p4a-initdb.log`); `pg_ctl start -o "-p 55462 -c listen_addresses=127.0.0.1"`
→ `PGCTL_EXIT=0` (`.tools/p4a-pg.log`; server banner `PostgreSQL 16.9`). Databases `p4a_chain`,
`p4a_dup` created (`createdb` exit 0/0). **No other cluster directory was opened.**

Chain run (documented `supabase/tests/README.md:32-63` order — every option before the `-d`
connection argument per `README:100-105` — plus my guard as the last `-f`), fresh DB `p4a_chain`,
from the repository root:

- `psql -v ON_ERROR_STOP=1 -f …(30 README files)… -f supabase/tests/75_signaling_replay_index_duplicate_guard.sql -d postgresql://postgres@127.0.0.1:55462/p4a_chain`
- **CHAIN_EXIT=0**; log `.tools/p4a-chain.log` (604 lines); `grep -c "ASSERTION FAILED"` = **0**;
  `grep -c "ERROR"` = **0**; `grep -c "duplicate sequences exist; index skipped"` = **1** (the
  guard's in-transaction re-apply — the NOTICE fired as predicted); guard banners at log `:599`
  `ALL SIGNALING REPLAY-INDEX DUPLICATE-CASE GUARD TESTS PASSED` and `:602`
  `ALL SIGNALING REPLAY-INDEX DUPLICATE GUARD TESTS PASSED`.
- Final public table count read live: `select count(*) from pg_tables where schemaname='public'` →
  **19**, exit 0 (`TABLECOUNT_EXIT=0`).

### 2.4 Negative proof (separate throwaway DB `p4a_dup`, script `.tools/p4a-duplicate-probe.sh`, log `.tools/p4a-duplicate-probe.log`)

| Step | Exit | Observed |
|---|---|---|
| 1. stubs + migrations through `20261030000100` + `20_fixtures.sql` | 0 | pre-migration-200 state |
| 2. BEFORE | 0 | `uniq_index=ABSENT`, `dup_groups=0`, `total_rows=1` |
| 3. insert 2 duplicate `(session_id, sequence)` rows (`OVERRIDING SYSTEM VALUE`) | 0 | duplicates exist |
| 4. apply `20261030000200_phase1_authorization.sql` with `ON_ERROR_STOP=1` | **0** | apply **succeeds quietly**; NOTICE `duplicate sequences exist; index skipped` count = 1 |
| 5. AFTER | 0 | `uniq_index=ABSENT`, `dup_groups=1`, `total_rows=3` — creation skipped, **duplicates never deleted** |
| 6. `tests/70_phase1_authorization.sql` | **0** | passes either way (its own NOTICE `duplicate signals exist; unique index correctly skipped` present ×1) — confirms the "mirrors the condition" claim |
| 7. `tests/71_phase1_rollback_privileges.sql` | **3** | `psql:supabase/tests/71_phase1_rollback_privileges.sql:212: ERROR: ASSERTION FAILED: FORWARD: the (session_id, sequence) unique index must exist` — the suite fails loudly where the migration stayed quiet |
| 8. final state after failed 71 | 0 | index still ABSENT, duplicate group still present |

The migration/70/71 disagreement is therefore **measured, not inferred**. PASS.

### 2.5 Out-of-boundary items (deliberately NOT done)

- `supabase/tests/README.md:32-63` should gain `-f supabase/tests/75_signaling_replay_index_duplicate_guard.sql`
  (natural slot: after `:61` / before `45_device_recovery.sql`; any position works since the guard
  mutates nothing). README is **not owned by this workstream** → **AWAITING OWNER/coordinator**;
  the guard header documents the append.
- The migration's rollback state table row `:44` (`ABSENT → PRESENT / PRESENT`) could read
  `PRESENT (skipped with NOTICE on pre-existing duplicates)`; Phase 3 offered the same option. Migrations
  are security-workstream-owned and frozen pre-deploy → **NOT RUN** (proposal on record only).
- The host-side pre-apply duplicate pre-check (`remaining-gaps.md:105`, query shape
  `20261030000200:479-485`) — hosted inspection is coordinator-owned; nothing hosted was touched →
  **NOT RUN (not this workstream)**.

## 3. Contract wording — proposed, NOT applied (api-contract.md is not owned by this workstream)

Real over-claim (confirmed by §2): the unique index cannot stop replay, because a replayed signal is
a **new insert with a new identity sequence** and never collides; and the index itself is conditional
(§2.1/§2.4). What actually mitigates replay today is client-side (read this session): dedupe by row
`id` with `kind:sequence` fallback (`lib/features/remote_assistance/remote_session_controller.dart:911-914`)
plus horizon rejection of stored pre-negotiation rows (`:915-921`).

- **Before — `docs/implementation/api-contract.md:222-224` (verbatim):**
  ```
  `remote_sessions.session_nonce` is **written but never validated** — it is a reserved field, not a
  replay control. Signal replay protection is the unique `(session_id, sequence)` index added in
  `20261030000200_phase1_authorization.sql`. Do not depend on the nonce until a validation path exists.
  ```
- **After — proposed replacement:**
  ```
  `remote_sessions.session_nonce` is **written but never validated** — it is a reserved field, not a
  replay control. Signal replay mitigation is **client-side**: dedupe by row `id` with a
  `kind:sequence` fallback when the id is missing, plus a time horizon that rejects stored
  pre-negotiation rows (`lib/features/remote_assistance/remote_session_controller.dart:911-921`). The
  unique `(session_id, sequence)` index in `20261030000200_phase1_authorization.sql:476-495` is
  hygiene against **imported/restored duplicates only — not replay protection**: `sequence` is
  `GENERATED ALWAYS AS IDENTITY` (`20260101000000_core.sql:366`), so a replayed signal arrives as a
  new row with a new sequence and never violates it. The index is created **conditionally**: with
  pre-existing duplicate `(session_id, sequence)` groups the migration skips creation with a NOTICE
  (`:492`) and deletes nothing — hence the mandatory pre-apply duplicate check. Do not depend on the
  nonce until a validation path exists.
  ```
- `api-contract.md` was **NOT edited** (contract wording needs owner approval). **AWAITING OWNER.**

## 4. Cleanup (my cluster only)

After all runs: `pg_ctl -D .tools/pgdata_p4a stop -m fast` (server stopped, port 55462 listener
gone), then the `.tools/pgdata_p4a` directory — created by this workstream — removed. Databases
`p4a_chain`/`p4a_dup` die with it. `.tools/pgdata_p2`, `.tools/pgdata_p3a`, `.tools/pgdata_p3b`
untouched. Retained gitignored evidence (`.tools/` per project convention): `p4a-initdb.log`,
`p4a-pg.log`, `p4a-chain.log`, `p4a-duplicate-probe.log`, `p4a-duplicate-probe.sh`,
`p4a-deno-flagless.log`, `p4a-deno-flagged.log`, `p4a-deno-guard-only.log`.

## 5. Files changed by this workstream

1. `docs/implementation/regression-matrix.md` — §1 cell :24 rewritten (command + verified reason; negative control preserved).
2. `docs/implementation/phase-3-regression-matrix.md` — DOC-01 row CLOSED-with-date; SQL-06 row Phase-4 status appended.
3. `docs/implementation/phase-2-report.md` — dated DOC-01 closure marker after the negative-control paragraph.
4. `docs/implementation/phase-1-report.md`, `docs/implementation/_work/security.md` — dated DOC-01 notes on the stale `family-admin` record.
5. `docs/backend.md`, `docs/bug-report.md`, `docs/verification-report.md` (×3 sites), `docs/mic_full_audit_report.md`, `docs/stage2_background_audio_report.md`, `docs/stage5_background_audio_survival_report.md`, `docs/stage6_account_and_media_recovery_report.md`, `docs/runtime-mic-test-report.md` — dated DOC-01 notes; every recorded number untouched.
6. `supabase/tests/75_signaling_replay_index_duplicate_guard.sql` — NEW guard (validated; not yet in README, §2.5).
7. This file. No source, migration, `api-contract.md`, README, or non-owned file was modified.
