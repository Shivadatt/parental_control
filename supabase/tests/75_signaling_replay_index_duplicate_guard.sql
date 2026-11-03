-- SQL-06/SQL-06a — honest duplicate-skip guard for the (session_id, sequence) replay index.
--
-- WHY THIS FILE EXISTS. Phase 3 (`docs/implementation/_work/p3-followups.md` §3) found that the
-- Phase 1 migration, test 70 and test 71 disagree about conditional creation of the unique index
-- `webrtc_signals_session_sequence_uniq` when duplicate (session_id, sequence) rows pre-exist:
--   * the migration SKIPS creation and only raises a NOTICE
--     (`20261030000200_phase1_authorization.sql`: duplicate guard :478-486, create :489-490,
--     `raise notice 'duplicate sequences exist; index skipped'` :492);
--   * `70_phase1_authorization.sql:436-451` mirrors that condition, so it passes EITHER WAY;
--   * `71_phase1_rollback_privileges.sql:194-197` asserts, with NO duplicate guard, that the
--     forward-phase snapshot value of `index|webrtc_signals_session_sequence_uniq` is not
--     'ABSENT' — so on a database with imported duplicates the apply succeeds quietly (NOTICE)
--     and the suite then fails loudly at 71. The migration's own rollback state table
--     (20261030000200:36-47, row :44) likewise records `ABSENT → PRESENT / PRESENT` as if
--     creation were unconditional.
-- This guard asserts what the migration ACTUALLY does, using the real migration text (re-applied
-- with `\i`, the same mechanism 71 uses in its RE-FORWARD phase at :543) — no copied-out DO block,
-- so it cannot drift from production SQL. It weakens NOTHING: tests 70 and 71 are untouched, and
-- the positive assertion below keeps 71's claim for the no-duplicate case it actually documents.
--
-- WHAT IS ASSERTED (and what is NOT):
--   1. FORWARD, NO DUPLICATES (the documented chain state): the unique index EXISTS, no duplicate
--      (session_id, sequence) group exists, and the legacy non-unique
--      `webrtc_signals_session_sequence_idx` is still there (the migration stays additive,
--      20261030000200:497-499).
--   2. PRE-EXISTING DUPLICATES (simulated inside one transaction, then rolled back): re-applying
--      the migration SKIPS index creation (regclass stays NULL — the index is NOT forced and the
--      apply does NOT abort), the duplicate rows SURVIVE untouched ("Duplicates are reported,
--      never deleted", 20261030000200:474 — total count grows only by the two probe rows), and
--      the exact predicate 71 uses reads 'ABSENT', which proves the disagreement is real and that
--      the pre-apply duplicate check (`remaining-gaps.md:105`) is MANDATORY hygiene, not optional.
--   3. AFTER ROLLBACK: the chain's forward state is restored (index present, no duplicates, row
--      count identical to before section 2), so later files see what the README promises.
-- This guard asserts observable outcomes, NOT the NOTICE text — psql cannot capture a server
-- NOTICE into an SQL assertion. The NOTICE itself was verified by grep of the captured run log
-- (`duplicate sequences exist; index skipped`, expected exactly once from this file): see
-- `.tools/p4a-chain.log` and `.tools/p4a-duplicate-probe.log` in `docs/implementation/_work/
-- p4-docs-sql06.md`.
--
-- Run from the repository root, AFTER the documented `psql -f` chain of `supabase/tests/README.md:32-63`
-- (append `-f supabase/tests/75_signaling_replay_index_duplicate_guard.sql` as the last file; the
-- README itself is coordinator-owned and was intentionally not edited by this workstream). Local
-- plain PostgreSQL 15+ with `00_auth_stub.sql` only; nothing here touches a Supabase project.
-- Requires 20_fixtures.sql (or any surviving remote_sessions row) for the probe inputs.

drop table if exists p4a_guard_ctx;
create temp table p4a_guard_ctx (
  session_id uuid, from_user_id uuid, dup_sequence bigint, rows_before bigint
);

-- Probe inputs: any real session, its parent as signal sender, a sequence value no identity
-- draw can collide with inside this transaction, and the current row count.
insert into p4a_guard_ctx
select s.id, s.parent_user_id,
       (select coalesce(max(w.sequence), 0) + 1000 from public.webrtc_signals w),
       (select count(*) from public.webrtc_signals)
from public.remote_sessions s
order by s.id
limit 1;

-- ===========================================================================
-- 1. FORWARD, NO DUPLICATES — the state the documented chain creates.
-- ===========================================================================
do $$
declare
  v_groups integer;
begin
  perform tests.assert_true(
    (select count(*) from p4a_guard_ctx) = 1,
    'guard precondition: remote_sessions must contain at least one row (run after 20_fixtures.sql)');
  perform tests.assert_true(
    to_regclass('public.webrtc_signals_session_sequence_uniq') is not null,
    'NO-DUPLICATES CASE: the migration creates the (session_id, sequence) unique index when no '
    || 'duplicate group exists — same claim as 71_phase1_rollback_privileges.sql:194-197');
  select count(*) into v_groups from (
    select session_id, sequence
    from public.webrtc_signals
    group by 1, 2
    having count(*) > 1
  ) d;
  perform tests.assert_true(v_groups = 0,
    'NO-DUPLICATES CASE: the chain database must have zero duplicate (session_id, sequence) '
    || 'groups (sequence is GENERATED ALWAYS AS IDENTITY; the write path cannot produce one), '
    || 'found ' || v_groups);
  perform tests.assert_true(
    to_regclass('public.webrtc_signals_session_sequence_idx') is not null,
    'the pre-existing non-unique index stays in place (migration is additive, '
    || '20261030000200_phase1_authorization.sql:497-499)');
end;
$$;

-- ===========================================================================
-- 2. PRE-EXISTING DUPLICATES — what the migration REALLY does, inside one
--    transaction that is fully rolled back afterwards.
-- ===========================================================================
begin;

-- Simulate an imported/pre-identity database: no unique index yet, two rows sharing
-- (session_id, sequence). OVERRIDING SYSTEM VALUE is the documented escape hatch for
-- GENERATED ALWAYS identity columns and mirrors how such duplicates actually arrive
-- (pg_restore / import), cf. migration comment :472-474.
drop index if exists public.webrtc_signals_session_sequence_uniq;

insert into public.webrtc_signals (session_id, from_user_id, kind, payload, sequence)
  overriding system value
select c.session_id, c.from_user_id, 'offer',
       '{"p4a": "guard prerequisite probe A"}'::jsonb, c.dup_sequence
from p4a_guard_ctx c;

insert into public.webrtc_signals (session_id, from_user_id, kind, payload, sequence)
  overriding system value
select c.session_id, c.from_user_id, 'ice',
       '{"p4a": "guard prerequisite probe B"}'::jsonb, c.dup_sequence
from p4a_guard_ctx c;

do $$
declare
  v_groups integer;
begin
  -- The simulated state is real before we trust the outcome.
  select count(*) into v_groups from (
    select session_id, sequence
    from public.webrtc_signals
    group by 1, 2
    having count(*) > 1
  ) d;
  perform tests.assert_true(v_groups >= 1,
    'DUPLICATE-CASE PRECONDITION: the two OVERRIDING SYSTEM VALUE rows must actually share '
    || '(session_id, sequence), found ' || v_groups || ' duplicate groups');
  perform tests.assert_true(
    to_regclass('public.webrtc_signals_session_sequence_uniq') is null,
    'DUPLICATE-CASE PRECONDITION: the unique index must be absent before re-applying the migration');
end;
$$;

-- Re-apply the REAL migration file (not a copy of section 8), so this measures exactly what the
-- operator's pre-apply would do. Every statement in it is written to be re-runnable.
\i supabase/migrations/20261030000200_phase1_authorization.sql

do $$
declare
  v_groups integer;
  v_now    bigint;
  v_pred   text;
begin
  -- (a) The migration SKIPS creation: the index is still absent. It does not force a failing
  --     `create unique index` and it does not abort — the fact that this DO block runs at all
  --     proves the apply survived (`ON_ERROR_STOP=1` would have stopped psql otherwise).
  perform tests.assert_true(
    to_regclass('public.webrtc_signals_session_sequence_uniq') is null,
    'DUPLICATE CASE: with pre-existing duplicates the migration must SKIP index creation '
    || '(20261030000200:478-486 guard, :492 notice path); the index must not exist afterwards, '
    || 'and this guard must never claim that it does');

  -- (b) Duplicates are reported, never deleted (migration header :474).
  select count(*) into v_groups from (
    select session_id, sequence
    from public.webrtc_signals
    group by 1, 2
    having count(*) > 1
  ) d;
  perform tests.assert_true(v_groups >= 1,
    'DUPLICATE CASE: the duplicate rows must still be present (no row was deleted to satisfy '
    || 'the index), found ' || v_groups);
  select count(*) into v_now from public.webrtc_signals;
  perform tests.assert_true(
    v_now = (select c.rows_before + 2 from p4a_guard_ctx c),
    'DUPLICATE CASE: total row count must be exactly the pre-guard count plus the two probe '
    || 'rows (nothing created or destroyed beyond the simulation), got ' || v_now);

  -- (c) The disagreement, measured: the exact predicate 71_phase1_rollback_privileges.sql:194-197
  --     snapshots ('index|webrtc_signals_session_sequence_uniq') evaluates to 'ABSENT' in this
  --     state, i.e. 71's unguarded forward assertion FAILS on a duplicate database while the
  --     migration itself succeeded quietly. Do not "fix" this by weakening 71 — the resolution
  --     is the mandatory pre-apply duplicate check (supabase/migrations/20261030000200_phase1_authorization.sql:479-485).
  select coalesce(to_regclass('public.webrtc_signals_session_sequence_uniq')::text, 'ABSENT')
    into v_pred;
  perform tests.assert_true(v_pred = 'ABSENT',
    'DISAGREEMENT PROOF: the value 71 snapshots (and asserts <> ''ABSENT'' with no duplicate '
    || 'guard) reads ''' || v_pred || ''' on a duplicate database — the suite is only green here '
    || 'because the pre-apply duplicate pre-check keeps such databases out of the path');

  raise notice 'ALL SIGNALING REPLAY-INDEX DUPLICATE-CASE GUARD TESTS PASSED';
end;
$$;

-- Undo the whole simulation. Nothing below the transaction sees it.
rollback;

-- ===========================================================================
-- 3. RESTORED FORWARD STATE — the chain's documented end state is intact.
-- ===========================================================================
do $$
declare
  v_groups integer;
  v_now    bigint;
begin
  perform tests.assert_true(
    to_regclass('public.webrtc_signals_session_sequence_uniq') is not null,
    'RESTORED: after ROLLBACK the unique index must be present again (the simulation left no '
    || 'trace), so 71/72/74/45 and the README 19-table end-state check keep their meaning');
  select count(*) into v_groups from (
    select session_id, sequence
    from public.webrtc_signals
    group by 1, 2
    having count(*) > 1
  ) d;
  perform tests.assert_true(v_groups = 0,
    'RESTORED: no duplicate group may survive the rollback, found ' || v_groups);
  select count(*) into v_now from public.webrtc_signals;
  perform tests.assert_true(
    v_now = (select c.rows_before from p4a_guard_ctx c),
    'RESTORED: webrtc_signals row count must equal the pre-guard count, got ' || v_now);
  raise notice 'ALL SIGNALING REPLAY-INDEX DUPLICATE GUARD TESTS PASSED';
end;
$$;

drop table if exists p4a_guard_ctx;
