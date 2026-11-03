-- Sweep access-path and repeatability tests (SQL-02 and SQL-04).
--
-- Covers the two performance defects Phase 2 recorded as unverifiable-by-reading:
--
--   SQL-02  migration 20261030000100 built `remote_sessions_abandoned_idx` on
--           the plain `accepted_at` column while the sweep filters on
--           `coalesce(accepted_at, requested_at)`. The index could not serve the
--           age predicate and left NULL-`accepted_at` rows unreachable.
--   SQL-04  migration 20261030000300 filtered `webrtc_signals` and `audit_logs`
--           on a bare `created_at` that no index led with, so every 10 000-row
--           batch re-scanned the table inside one transaction.
--
-- Run AFTER 72_retention_sweep.sql and BEFORE 45_device_recovery.sql, from the
-- repository root, in the documented `psql -f` chain (see supabase/tests/README.md).
-- Self-contained: its own accounts, family, device, sessions, signals, audit,
-- location and usage rows (a7../b7../c7../d7../e7../f7.. UUIDs). The global
-- sweeps it invokes are the same ones 72 already invokes, so running this file
-- after 72 deletes nothing that another test file still needs.
--
-- Scope note: plan-shape evidence (Bitmap Heap Scan -> bounded range scan, the
-- "Rows Removed by Filter" collapse) is a planner decision and is NOT asserted
-- here; it is measured and captured in docs/implementation/_work/p3-sql-performance.md.
-- What this file pins is the catalog state the planner needs, the behaviour the
-- old index could not reach, and the repeat/empty-dataset contract.
--
-- Section 5 adds behavioural coverage of the PERF-01a batch shape (owner-
-- approved Phase 5 adoption of `id = any(array(select ... limit ...))` for the
-- webrtc_signals/audit_logs deletes): deleted-id SET equality against the
-- previous `using (...)` shape, batch-ORDER stability with per-arm ordinals
-- across identical runs, repeatability and the empty-dataset exit. It is
-- method-for-method the Phase 4 p4d_equiv proof (docs/implementation/_work/
-- p4-perf01.md section 2: a BEGIN..ROLLBACK probe cannot work because the
-- rollback destroys the capture, so every reference arm deletes from its OWN
-- pre-taken copy), kept as a local helper in this test file - the migration
-- contains only the shipped shape.

-- ===========================================================================
-- 1. SQL-02: the abandoned-session index is keyed on the sweep's own expression.
-- ===========================================================================
do $$
declare
  v_def text;
  v_expr text;
  v_pred text;
begin
  perform tests.assert_true(
    to_regclass('public.remote_sessions_abandoned_idx') is not null,
    'remote_sessions_abandoned_idx must exist after 20261030000100'
  );

  -- An expression index, not a plain column build: pg_index stores key
  -- expressions in indexprs and plain columns only in indkey.
  select pg_get_indexdef(i.oid),
         coalesce(pg_get_expr(x.indexprs, x.indrelid), ''),
         coalesce(pg_get_expr(x.indpred, x.indrelid), '')
    into v_def, v_expr, v_pred
  from pg_class i
  join pg_index x on x.indexrelid = i.oid
  where i.oid = to_regclass('public.remote_sessions_abandoned_idx');

  perform tests.assert_true(
    v_expr ~* 'coalesce\s*\(\s*accepted_at,\s*requested_at\s*\)',
    'SQL-02: the index key must be COALESCE(accepted_at, requested_at), got: '
    || v_expr
  );
  -- The predicate must match the statuses the cursor scans: consented rows only.
  perform tests.assert_true(
    v_pred <> '' and v_pred ~* 'status'
      and v_pred ~* 'accepted' and v_pred ~* 'active',
    'SQL-02: the index predicate must cover exactly the swept statuses, got: '
    || v_pred
  );
  perform tests.assert_true(
    v_pred not like '%requested%',
    'SQL-02: pending rows belong to the pending-expiry job and must stay out of '
    || 'the partial index, got: ' || v_pred
  );
  perform tests.assert_true(
    v_def ~* 'where',
    'SQL-02: the index must stay partial, not cover the whole table'
  );

  -- No second index may reintroduce the plain (accepted_at) build: it cannot
  -- serve the age filter and would let the defect return unnoticed.
  perform tests.assert_true(
    not exists (
      select 1
      from pg_class i
      join pg_namespace n on n.oid = i.relnamespace
      join pg_index x on x.indexrelid = i.oid
      join pg_attribute a on a.attrelid = x.indrelid
        and a.attnum = x.indkey[0]
      where n.nspname = 'public'
        and i.relname <> 'remote_sessions_abandoned_idx'
        and i.relkind = 'i'
        and x.indexprs is null
        and x.indpred is null
        and a.attname = 'accepted_at'
    ),
    'SQL-02: no plain (accepted_at) index may exist on remote_sessions'
  );
end;
$$;

-- Re-running the migration must be a no-op, not a rebuild into the old shape.
\i supabase/migrations/20261030000100_abandoned_session_sweep.sql

do $$
declare
  v_expr text;
begin
  select coalesce(pg_get_expr(x.indexprs, x.indrelid), '')
    into v_expr
  from pg_class i
  join pg_index x on x.indexrelid = i.oid
  where i.oid = to_regclass('public.remote_sessions_abandoned_idx');
  perform tests.assert_true(
    v_expr ~* 'coalesce\s*\(\s*accepted_at,\s*requested_at\s*\)',
    'SQL-02: re-applying 20261030000100 must keep the expression build, got: '
    || v_expr
  );
end;
$$;

-- ===========================================================================
-- 2. SQL-04: the retention sweep's global `created_at` filters are indexed.
-- ===========================================================================
do $$
declare
  v_rec text;
begin
  for v_rec in
    select idx
    from unnest(array[
      'public.webrtc_signals_created_idx',
      'public.audit_logs_created_idx'
    ]) as t(idx)
  loop
    perform tests.assert_true(
      to_regclass(v_rec) is not null,
      'SQL-04: missing index ' || v_rec
    );
    perform tests.assert_true(
      (
        select x.indisvalid and x.indnatts = 1
               and a.attname = 'created_at'
               and am.amname = 'btree'
        from pg_class i
        join pg_index x on x.indexrelid = i.oid
        join pg_attribute a on a.attrelid = x.indrelid and a.attnum = x.indkey[0]
        join pg_am am on am.oid = i.relam
        where i.oid = to_regclass(v_rec)
      ),
      'SQL-04: ' || v_rec
      || ' must be a valid single-column btree led by created_at'
    );
  end loop;

  -- The two per-family steps already match an index; pin that claim so a future
  -- schema change that drops them is caught here rather than in a slow sweep.
  perform tests.assert_true(
    to_regclass('public.location_events_family_recorded_idx') is not null
      and to_regclass('public.usage_daily_family_day_idx') is not null,
    'SQL-04: the per-family steps rely on location_events_family_recorded_idx and '
    || 'usage_daily_family_day_idx; both must still exist'
  );
end;
$$;

-- ===========================================================================
-- 3. Behaviour the old plain index could not reach: a consented session whose
--    accepted_at is NULL is anchored on requested_at and IS swept.
-- ===========================================================================
do $$
declare
  v_parent uuid := 'a7000000-0000-4000-8000-0000000000a1';
  v_child uuid := 'b7000000-0000-4000-8000-0000000000c1';
  v_family uuid := 'c7000000-0000-4000-8000-000000000001';
  v_device uuid := 'd7000000-0000-4000-8000-000000000001';
  v_null_accepted uuid := 'e7000000-0000-4000-8000-000000000001';
  v_anchored uuid := 'e7000000-0000-4000-8000-000000000002';
  v_young uuid := 'e7000000-0000-4000-8000-000000000003';
  v_pending uuid := 'e7000000-0000-4000-8000-000000000004';
  v_closed integer;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'sql02-parent@example.test', now()),
    (v_child, 'sql02-child@example.test', now());
  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child' where id = v_child;

  insert into public.families (id, name, owner_id, settings)
  values (v_family, 'Index Family', v_parent,
          '{"location_retention_days":30,"usage_retention_days":90}'::jsonb);
  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child, 'child', 'active');
  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values (
    v_device, v_family, v_child, 'sql02-device', 'Index Phone', 'active'
  );

  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, expires_at, consent_recorded
  ) values
    -- consented but accepted_at never recorded: requested_at is the anchor
    (v_null_accepted, v_family, v_device, v_parent, v_child, 'audio',
     'active', now() - interval '9 days', null, null, true),
    -- old and consented, anchor is accepted_at
    (v_anchored, v_family, v_device, v_parent, v_child, 'audio',
     'accepted', now() - interval '9 days', now() - interval '8 days',
     null, true),
    -- live: 20 minutes old, must survive
    (v_young, v_family, v_device, v_parent, v_child, 'audio',
     'active', now() - interval '20 minutes', now() - interval '20 minutes',
     null, true),
    -- pending: owned by the pending-expiry job, untouched by this sweep
    (v_pending, v_family, v_device, v_parent, v_child, 'audio',
     'requested', now() - interval '9 days', null,
     now() - interval '9 days' + interval '10 minutes', false);

  v_closed := public.expire_abandoned_sessions(interval '24 hours');

  perform tests.assert_true(
    (select status from public.remote_sessions where id = v_null_accepted)
      = 'expired',
    'SQL-02: a consented row with accepted_at IS NULL must be swept on its '
    || 'requested_at anchor (the plain index could not reach it)'
  );
  perform tests.assert_true(
    (select ended_reason from public.remote_sessions where id = v_null_accepted)
      = 'abandoned'
      and (select ended_by from public.remote_sessions where id = v_null_accepted)
      is null,
    'SQL-02: the abandoned representation must stay ended_reason=abandoned with '
    || 'ended_by NULL (D1)'
  );
  perform tests.assert_true(
    (select status from public.remote_sessions where id = v_anchored) = 'expired',
    'SQL-02: an accepted row past the window must be swept'
  );
  perform tests.assert_true(
    (select status from public.remote_sessions where id = v_young) = 'active',
    'SQL-02: a live row inside the window must not be swept'
  );
  perform tests.assert_true(
    (select status from public.remote_sessions where id = v_pending) = 'requested',
    'SQL-02: the sweep must not touch pending rows'
  );
  perform tests.assert_true(v_closed >= 2,
    'SQL-02: the sweep must report the rows it closed, got ' || v_closed);

  -- Repeating it must leave nothing open in this family: terminal states are
  -- final. Scoped to this family because the counter is global.
  v_closed := public.expire_abandoned_sessions(interval '24 hours');
  perform tests.assert_true(
    (select count(*) from public.remote_sessions
      where family_id = v_family
        and status in ('accepted', 'active')
        and coalesce(accepted_at, requested_at) < now() - interval '24 hours') = 0,
    'SQL-02: a second abandoned sweep must leave no past-window consented row '
    || 'open in this family'
  );
end;
$$;

-- ===========================================================================
-- 4. Retention sweep: repeated execution, idempotence, empty dataset, and the
--    privilege contract the new indexes must not disturb.
-- ===========================================================================
do $$
declare
  v_parent uuid := 'a7000000-0000-4000-8000-0000000000a2';
  v_child uuid := 'b7000000-0000-4000-8000-0000000000c2';
  v_family uuid := 'c7000000-0000-4000-8000-000000000002';
  v_device uuid := 'd7000000-0000-4000-8000-000000000002';
  v_session uuid := 'e7000000-0000-4000-8000-000000000011';
  v_old_signal uuid := 'f7000000-0000-4000-8000-000000000001';
  v_new_signal uuid := 'f7000000-0000-4000-8000-000000000002';
  v_old_audit uuid := 'f7000000-0000-4000-8000-000000000003';
  v_new_audit uuid := 'f7000000-0000-4000-8000-000000000004';
  v_old_location uuid := 'f7000000-0000-4000-8000-000000000005';
  v_new_location uuid := 'f7000000-0000-4000-8000-000000000006';
  v_old_usage uuid := 'f7000000-0000-4000-8000-000000000007';
  v_new_usage uuid := 'f7000000-0000-4000-8000-000000000008';
  v_first jsonb;
  v_second jsonb;
  v_third jsonb;
  v_markers integer;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'sql04-parent@example.test', now()),
    (v_child, 'sql04-child@example.test', now());
  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child' where id = v_child;

  insert into public.families (id, name, owner_id, settings)
  values (v_family, 'Sweep Family', v_parent,
          '{"location_retention_days":30,"usage_retention_days":90}'::jsonb);
  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child, 'child', 'active');
  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values (
    v_device, v_family, v_child, 'sql04-device', 'Sweep Phone', 'active'
  );
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, expires_at
  ) values (
    v_session, v_family, v_device, v_parent, v_child, 'audio',
    'ended', now() - interval '1 day'
  );

  insert into public.webrtc_signals (
    id, session_id, from_user_id, kind, payload, created_at
  ) values
    (v_old_signal, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '30 days'),
    (v_new_signal, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '1 day');

  insert into public.audit_logs (
    id, family_id, actor_user_id, event_type, metadata, created_at
  ) values
    (v_old_audit, v_family, v_parent, 'test_sql04_old', '{}'::jsonb, now() - interval '500 days'),
    (v_new_audit, v_family, v_parent, 'test_sql04_new', '{}'::jsonb, now());

  insert into public.location_events (
    id, device_id, family_id, lat, lng, accuracy_m, recorded_at
  ) values
    (v_old_location, v_device, v_family, 51.5, -0.12, 10, now() - interval '45 days'),
    (v_new_location, v_device, v_family, 51.5, -0.12, 10, now() - interval '2 days');

  insert into public.usage_daily (
    id, device_id, family_id, day, package_name, total_ms
  ) values
    (v_old_usage, v_device, v_family, (now() - interval '150 days')::date, 'com.example.old', 1000),
    (v_new_usage, v_device, v_family, (now() - interval '5 days')::date, 'com.example.new', 1000);

  select count(*) into v_markers
  from public.audit_logs where event_type = 'retention_sweep';

  -- 4a. First call clears exactly the out-of-window rows it owns.
  select public.run_retention_sweep() into v_first;
  perform tests.assert_true(
    (v_first ->> 'webrtc_signals')::integer >= 1
      and (v_first ->> 'audit_logs')::integer >= 1
      and (v_first ->> 'location_events')::integer >= 1
      and (v_first ->> 'usage_daily')::integer >= 1,
    'SQL-04: first sweep must report progress on all four tables, got '
    || v_first::text
  );
  perform tests.assert_true(
    not exists (select 1 from public.webrtc_signals where id = v_old_signal)
      and not exists (select 1 from public.audit_logs where id = v_old_audit)
      and not exists (select 1 from public.location_events where id = v_old_location)
      and not exists (select 1 from public.usage_daily where id = v_old_usage),
    'SQL-04: out-of-window rows must be gone after the first sweep'
  );
  perform tests.assert_true(
    exists (select 1 from public.webrtc_signals where id = v_new_signal)
      and exists (select 1 from public.audit_logs where id = v_new_audit)
      and exists (select 1 from public.location_events where id = v_new_location)
      and exists (select 1 from public.usage_daily where id = v_new_usage),
    'SQL-04: in-window rows must survive; the boundaries are unchanged'
  );

  -- 4b. Second call is a no-op on the same data, and still appends its marker.
  select public.run_retention_sweep() into v_second;
  perform tests.assert_true(
    coalesce((v_second ->> 'webrtc_signals')::integer, 0) = 0
      and coalesce((v_second ->> 'audit_logs')::integer, 0) = 0,
    'SQL-04: a repeated sweep must delete nothing, got ' || v_second::text
  );
  perform tests.assert_true(
    (select count(*) from public.audit_logs where event_type = 'retention_sweep')
      > v_markers,
    'SQL-04: every call must append its own audit marker (account reads it as '
    || '"last sweep")'
  );

  -- 4c. Empty dataset: a third call must neither error nor report progress.
  delete from public.webrtc_signals where session_id = v_session;
  delete from public.location_events where device_id = v_device;
  delete from public.usage_daily where device_id = v_device;
  delete from public.audit_logs
  where family_id = v_family and event_type <> 'retention_sweep';
  select public.run_retention_sweep() into v_third;
  perform tests.assert_true(
    coalesce((v_third ->> 'webrtc_signals')::integer, 0) = 0
      and coalesce((v_third ->> 'location_events')::integer, 0) = 0
      and coalesce((v_third ->> 'usage_daily')::integer, 0) = 0,
    'SQL-04: an empty dataset must be safe and report zero, got ' || v_third::text
  );

  -- 4d. Authorisation is unchanged by the new indexes.
  perform tests.assert_true(
    has_function_privilege('service_role', 'public.run_retention_sweep()', 'execute')
      and not has_function_privilege('anon', 'public.run_retention_sweep()', 'execute')
      and not has_function_privilege(
        'authenticated', 'public.run_retention_sweep()', 'execute'),
    'SQL-04: run_retention_sweep must stay service-role-only'
  );
  perform tests.assert_true(
    (
      select p.prosecdef
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'run_retention_sweep'
    ),
    'SQL-04: run_retention_sweep must stay SECURITY DEFINER'
  );

  -- 4e. Pins the documented limit of "batched": a PL/pgSQL function cannot
  -- COMMIT, so one call is one transaction and partial progress is impossible.
  -- If a future change adds COMMIT it must become a PROCEDURE and this
  -- assertion is the tripwire that forces the documentation to be re-read.
  perform tests.assert_true(
    (
      select p.prosrc not like '%commit%'
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'run_retention_sweep'
    ),
    'SQL-04: run_retention_sweep is still a function with no internal COMMIT, so '
    || 'one call is one transaction. If this fails, re-read the bounded-execution '
    || 'section of 20261030000300 and option A of the Phase 3 decision.'
  );

  -- 4f. The batch size is still what the header claims (10 000 per statement).
  -- This deliberately pins only the v_batch LITERAL, not the DELETE's syntax:
  -- the shipped shape itself is covered behaviourally in section 5 (PERF-01a).
  perform tests.assert_true(
    (
      select p.prosrc like '%10000%'
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'run_retention_sweep'
    ),
    'SQL-04: the 10 000-row statement bound must still be present'
  );
end;
$$;

-- ===========================================================================
-- 5. PERF-01a: behavioural coverage of the shipped batch shape.
--
-- The migration deletes the webrtc_signals/audit_logs backlog with
--   delete from t a where a.id = any (array(
--     select id from t where created_at < v_now - interval '...'
--     limit v_batch ));
-- This section asserts what the shape must guarantee - not its spelling:
--   (a) the deleted-id SET equals the set the previous `using (...) doomed`
--       shape deletes, run as a local reference helper (p574_shape_pass) over
--       an identical snapshot taken before the live run;
--   (b) batch ORDER stability: every deleted id is captured with a per-arm
--       ordinal (the executor's delivery order, the p4d_cap(ord, tag, id, tid)
--       column of Phase 4) and compared positionally across two identical
--       runs and against the previous shape on byte-identical copies;
--   (c) repeatability: after re-seeding identical rows, live run 2 deletes the
--       same set; the back-to-back run 3 deletes zero;
--   (d) the empty-dataset path still exits immediately: a call against zero
--       backlog rows deletes nothing at all (capture fires zero times) and
--       returns - the `exit when v_deleted < v_batch` end-of-loop is what
--       makes the first zero-row batch terminate.
--
-- Method: p4d_equiv per-arm copies (docs/implementation/_work/p4-perf01.md
-- section 2). A BEGIN..ROLLBACK probe cannot prove deleted-row identity
-- because the rollback destroys the capture, and leaves dead tuples that make
-- the next arm physically unequal; here each reference arm deletes from its
-- OWN temp copy, so only the live sweep calls ever touch the real tables.
-- Cutoffs are frozen from the live run's returned swept_at so the reference
-- and the copies evaluate exactly the same predicate. Live run 2 is compared
-- by SET only: re-inserted rows may land on different heap ctids (page reuse
-- after mass deletes), which is physical layout, not batch semantics; ordinal
-- stability is asserted on the identical copies instead.
-- ===========================================================================

create temp table p574_run (run_id integer not null);
insert into p574_run values (0);

-- Persistent capture of every deleted id with the executor's delivery ordinal
-- (p4d_cap-style). Written by the live-table triggers AND by the shape helper.
create temp table p574_cap (
  ord bigserial primary key,
  run_id integer not null,
  tbl text not null,
  id uuid not null
);

-- Deterministic backlog spec: absolute ids and timestamps, so run 2 re-seeds
-- identical rows. webrtc: 12 050 rows aged 8-30 days plus one boundary row at
-- 7 days 12 hours; audit: 12 000 rows aged 370-482 days plus one at 366 days.
-- Both counts exceed v_batch, so every arm runs the multi-batch loop
-- (10 000 + tail) rather than a single short batch.
create temp table p574_spec_w (id uuid primary key, created_at timestamptz not null);
create temp table p574_spec_a (id uuid primary key, created_at timestamptz not null);

insert into p574_spec_w
select ('a5740000-0000-4000-8000-' || lpad(g.x::text, 12, '0'))::uuid,
       now() - ((8 + (g.x % 23)) * interval '1 day')
from generate_series(1, 12050) as g(x)
union all
select 'a5740000-0000-4000-8000-000000019001'::uuid,
       now() - interval '7 days 12 hours';

insert into p574_spec_a
select ('b5740000-0000-4000-8000-' || lpad(g.x::text, 12, '0'))::uuid,
       now() - ((370 + (g.x % 113)) * interval '1 day')
from generate_series(1, 12000) as g(x)
union all
select 'b5740000-0000-4000-8000-000000019001'::uuid,
       now() - interval '366 days';

-- Row-level capture trigger for the LIVE sweep runs (ids only exist while
-- this file runs; the trigger is dropped at the end of section 5).
create or replace function p574_capture_delete()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  insert into p574_cap (run_id, tbl, id)
  select r.run_id, tg_table_name, old.id
  from p574_run r;
  return old;
end;
$$;

-- Local reference implementation of BOTH shapes inside one loop that mirrors
-- the shipped one (v_batch = 10000, `exit when v_deleted < v_batch`). Runs
-- against a caller-named copy and captures every deleted id with its
-- RETURNING ordinal. The previous `using (...)` shape lives HERE, in the test,
-- never in the migration.
create or replace function p574_shape_pass(
  p_snap text,
  p_label text,
  p_old boolean,
  p_run integer,
  p_now timestamptz,
  p_window interval
)
returns integer
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_batch constant integer := 10000;
  v_deleted integer;
  v_total integer := 0;
begin
  loop
    if p_old then
      -- the WITH must sit ABOVE the INSERT: a data-modifying CTE nested inside
      -- an INSERT's own SELECT is rejected ("must be at the top level").
      execute format(
        'with del as (
           delete from %1$s s
           using (
             select id from %1$s
             where created_at < $1 - $5
             limit $4
           ) doomed
           where s.id = doomed.id
           returning s.id
         )
         insert into p574_cap (run_id, tbl, id)
         select $2, $3, del.id from del', p_snap)
      using p_now, p_run, p_label, v_batch, p_window;
    else
      execute format(
        'with del as (
           delete from %1$s s
           where s.id = any (array(
             select id from %1$s
             where created_at < $1 - $5
             limit $4
           ))
           returning s.id
         )
         insert into p574_cap (run_id, tbl, id)
         select $2, $3, del.id from del', p_snap)
      using p_now, p_run, p_label, v_batch, p_window;
    end if;
    get diagnostics v_deleted = row_count;
    v_total := v_total + v_deleted;
    exit when v_deleted < v_batch;
  end loop;
  return v_total;
end;
$$;

create trigger p574_cap_w
  after delete on public.webrtc_signals
  for each row execute function p574_capture_delete();
create trigger p574_cap_a
  after delete on public.audit_logs
  for each row execute function p574_capture_delete();

do $$
declare
  v_session uuid := 'e7000000-0000-4000-8000-000000000011';
  v_parent uuid := 'a7000000-0000-4000-8000-0000000000a2';
  v_family uuid := 'c7000000-0000-4000-8000-000000000002';
  v_fresh_w1 uuid := 'a5740000-0000-4000-8000-000000019002';
  v_fresh_w2 uuid := 'a5740000-0000-4000-8000-000000019003';
  v_fresh_a1 uuid := 'b5740000-0000-4000-8000-000000019002';
  v_n_w integer;
  v_n_a integer;
  v_r1 jsonb;
  v_r2 jsonb;
  v_r3 jsonb;
  v_r4 jsonb;
  v_cut timestamptz;
  v_cnt integer;
  v_groups integer;
  v_pair record;
  v_name text;
  v_w_l1 text; v_w_l2 text; v_w_ref text;
  v_w_n1 text; v_w_n2 text; v_w_o1 text;
  v_a_l1 text; v_a_l2 text; v_a_ref text;
  v_a_n1 text; v_a_n2 text; v_a_o1 text;
  v_wo_n1 text; v_wo_n2 text; v_wo_old text;
  v_ao_n1 text; v_ao_n2 text; v_ao_old text;
begin
  -- 5a. Seed the fixture (run-1 copy). No aged webrtc/audit rows exist at
  -- this point of the chain: 72 and section 4 above each swept their own.
  insert into public.webrtc_signals (
    id, session_id, from_user_id, kind, payload, created_at
  )
  select s.id, v_session, v_parent, 'ice', '{}'::jsonb, s.created_at
  from p574_spec_w s;
  insert into public.webrtc_signals (
    id, session_id, from_user_id, kind, payload, created_at
  ) values
    (v_fresh_w1, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '6 days'),
    (v_fresh_w2, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '1 minute');
  insert into public.audit_logs (
    id, family_id, actor_user_id, event_type, metadata, created_at
  )
  select s.id, v_family, v_parent, 'p574_backlog', '{}'::jsonb, s.created_at
  from p574_spec_a s;
  insert into public.audit_logs (
    id, family_id, actor_user_id, event_type, metadata, created_at
  ) values
    (v_fresh_a1, v_family, v_parent, 'p574_fresh', '{}'::jsonb, now() - interval '100 days');

  select count(*) into v_n_w from p574_spec_w;
  select count(*) into v_n_a from p574_spec_a;
  perform tests.assert_true(v_n_w = 12051 and v_n_a = 12001,
    'PERF-01a fixture must be 12 051 aged signals / 12 001 aged audit rows, got '
    || v_n_w || '/' || v_n_a);
  perform tests.assert_true(
    (select count(*) from public.webrtc_signals
      where created_at < now() - interval '7 days') = v_n_w
      and (select count(*) from public.audit_logs
        where created_at < now() - interval '365 days') = v_n_a,
    'PERF-01a precondition: the fixture must be the ONLY aged backlog, else the '
    || 'exact-count assertions below compare against a moving base');

  -- 5b. Pre-live copies: one snapshot for the reference arm and three
  -- structurally identical copies per table for the order-stability reps
  -- (same CTAS from the same heap state = same rows in the same ctid order).
  create temp table p574_snap_w as select id, created_at from public.webrtc_signals;
  create temp table p574_snap_a as select id, created_at from public.audit_logs;
  create temp table p574_c1w as select id, created_at from public.webrtc_signals;
  create temp table p574_c2w as select id, created_at from public.webrtc_signals;
  create temp table p574_c3w as select id, created_at from public.webrtc_signals;
  create temp table p574_c1a as select id, created_at from public.audit_logs;
  create temp table p574_c2a as select id, created_at from public.audit_logs;
  create temp table p574_c3a as select id, created_at from public.audit_logs;

  -- Same two access paths the real tables carry (p4d_snapshot() method), then
  -- ANALYZE, so every copy is planned with the same statistics.
  for v_name in
    select unnest(array['p574_snap_w', 'p574_snap_a', 'p574_c1w', 'p574_c2w',
                        'p574_c3w', 'p574_c1a', 'p574_c2a', 'p574_c3a'])
  loop
    execute format('create index on %s (id)', v_name);
    execute format('create index on %s (created_at)', v_name);
    execute format('analyze %s', v_name);
  end loop;

  -- (a1) LIVE run 1 through the shipped function, row-captured by trigger.
  update p574_run set run_id = 1;
  select public.run_retention_sweep() into v_r1;
  v_cut := (v_r1 ->> 'swept_at')::timestamptz;
  perform tests.assert_true(
    (v_r1 ->> 'webrtc_signals')::integer = v_n_w
      and (v_r1 ->> 'audit_logs')::integer = v_n_a
      and coalesce((v_r1 ->> 'location_events')::integer, 0) = 0
      and coalesce((v_r1 ->> 'usage_daily')::integer, 0) = 0,
    'PERF-01a: live run 1 must delete the whole backlog via the shipped shape, got '
    || v_r1::text);

  -- (a2) reference arm: the PREVIOUS `using (...)` shape over the identical
  -- snapshot, same frozen cutoff (swept_at reported by the live call).
  v_cnt := p574_shape_pass('p574_snap_w', 'webrtc_signals', true, 10, v_cut, interval '7 days');
  perform tests.assert_true(v_cnt = v_n_w,
    'PERF-01a(a): reference using-shape deleted ' || v_cnt || ' signals, expected ' || v_n_w);
  v_cnt := p574_shape_pass('p574_snap_a', 'audit_logs', true, 20, v_cut, interval '365 days');
  perform tests.assert_true(v_cnt = v_n_a,
    'PERF-01a(a): reference using-shape deleted ' || v_cnt || ' audit rows, expected ' || v_n_a);

  select md5(string_agg(id::text, ',' order by id)) into v_w_l1
    from p574_cap where run_id = 1 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by id)) into v_w_ref
    from p574_cap where run_id = 10 and tbl = 'webrtc_signals';
  perform tests.assert_true(v_w_l1 = v_w_ref,
    'PERF-01a(a): deleted-id SET of the shipped shape differs from the previous using-shape on webrtc_signals: live='
    || v_w_l1 || ' reference=' || v_w_ref);
  select md5(string_agg(id::text, ',' order by id)) into v_a_l1
    from p574_cap where run_id = 1 and tbl = 'audit_logs';
  select md5(string_agg(id::text, ',' order by id)) into v_a_ref
    from p574_cap where run_id = 20 and tbl = 'audit_logs';
  perform tests.assert_true(v_a_l1 = v_a_ref,
    'PERF-01a(a): deleted-id SET of the shipped shape differs from the previous using-shape on audit_logs: live='
    || v_a_l1 || ' reference=' || v_a_ref);

  -- in both directions, count-based (mirrors p4d_equiv pairwise diff = 0/0)
  perform tests.assert_true(
    (select count(*) from p574_cap l where l.run_id = 1 and l.tbl = 'webrtc_signals'
       and not exists (select 1 from p574_cap r
                        where r.run_id = 10 and r.tbl = 'webrtc_signals' and r.id = l.id)) = 0
      and (select count(*) from p574_cap r where r.run_id = 10 and r.tbl = 'webrtc_signals'
       and not exists (select 1 from p574_cap l
                        where l.run_id = 1 and l.tbl = 'webrtc_signals' and l.id = r.id)) = 0
      and (select count(*) from p574_cap l where l.run_id = 1 and l.tbl = 'audit_logs'
       and not exists (select 1 from p574_cap r
                        where r.run_id = 20 and r.tbl = 'audit_logs' and r.id = l.id)) = 0
      and (select count(*) from p574_cap r where r.run_id = 20 and r.tbl = 'audit_logs'
       and not exists (select 1 from p574_cap l
                        where l.run_id = 1 and l.tbl = 'audit_logs' and l.id = r.id)) = 0,
    'PERF-01a(a): pairwise set difference live-run-1 vs reference shape must be 0/0 in both directions');

  perform tests.assert_true(
    exists (select 1 from public.webrtc_signals where id in (v_fresh_w1, v_fresh_w2))
      and exists (select 1 from public.audit_logs where id = v_fresh_a1),
    'PERF-01a: in-window rows (6d, 1min, 100d) must survive the shipped shape');

  -- (b) ORDER stability: two identical reps of the shipped shape on the
  -- identical copies, plus one rep of the previous shape, all captured with
  -- ordinals. Compared positionally and by digest, exactly like
  -- p4d_equiv_order.sql (row_number re-ranked per arm; raw ordinals are a
  -- session-wide serial and never match across arms).
  v_cnt := p574_shape_pass('p574_c1w', 'webrtc_signals', false, 11, v_cut, interval '7 days');
  perform tests.assert_true(v_cnt = v_n_w, 'PERF-01a(b): new-shape rep1 on webrtc deleted ' || v_cnt);
  v_cnt := p574_shape_pass('p574_c2w', 'webrtc_signals', false, 12, v_cut, interval '7 days');
  perform tests.assert_true(v_cnt = v_n_w, 'PERF-01a(b): new-shape rep2 on webrtc deleted ' || v_cnt);
  v_cnt := p574_shape_pass('p574_c3w', 'webrtc_signals', true, 13, v_cut, interval '7 days');
  perform tests.assert_true(v_cnt = v_n_w, 'PERF-01a(b): old-shape rep on webrtc deleted ' || v_cnt);
  v_cnt := p574_shape_pass('p574_c1a', 'audit_logs', false, 21, v_cut, interval '365 days');
  perform tests.assert_true(v_cnt = v_n_a, 'PERF-01a(b): new-shape rep1 on audit deleted ' || v_cnt);
  v_cnt := p574_shape_pass('p574_c2a', 'audit_logs', false, 22, v_cut, interval '365 days');
  perform tests.assert_true(v_cnt = v_n_a, 'PERF-01a(b): new-shape rep2 on audit deleted ' || v_cnt);
  v_cnt := p574_shape_pass('p574_c3a', 'audit_logs', true, 23, v_cut, interval '365 days');
  perform tests.assert_true(v_cnt = v_n_a, 'PERF-01a(b): old-shape rep on audit deleted ' || v_cnt);

  for v_pair in
    select * from (values
      (11, 12, 'webrtc_signals'),
      (11, 13, 'webrtc_signals'),
      (21, 22, 'audit_logs'),
      (21, 23, 'audit_logs')
    -- bare column names: a table alias may not carry type definitions unless
    -- the aliased item is a set-returning function call (PG rejects
    -- "t(run_a integer, ...)" here with a syntax error).
    ) as t(run_a, run_b, lbl)
  loop
    select count(*) into v_cnt
    from (select row_number() over (order by ord) as pos, id
            from p574_cap where run_id = v_pair.run_a and tbl = v_pair.lbl) a
    join (select row_number() over (order by ord) as pos, id
            from p574_cap where run_id = v_pair.run_b and tbl = v_pair.lbl) b
      on b.pos = a.pos
    where a.id is distinct from b.id;
    perform tests.assert_true(v_cnt = 0,
      'PERF-01a(b): ' || v_cnt || ' positional batch-order mismatches between runs '
      || v_pair.run_a || ' and ' || v_pair.run_b || ' on ' || v_pair.lbl);
    select count(*) into v_cnt
    from (select row_number() over (order by ord) as pos
            from p574_cap where run_id = v_pair.run_a and tbl = v_pair.lbl) a
    join (select row_number() over (order by ord) as pos
            from p574_cap where run_id = v_pair.run_b and tbl = v_pair.lbl) b
      on b.pos = a.pos;
    perform tests.assert_true(
      v_cnt = case when v_pair.lbl = 'webrtc_signals' then v_n_w else v_n_a end,
      'PERF-01a(b): position join for runs ' || v_pair.run_a || '/' || v_pair.run_b
      || ' covered only ' || v_cnt || ' rows; arms must have equal batch sizes');
  end loop;

  -- digest cross-check: same set across every arm, same order across copies
  select md5(string_agg(id::text, ',' order by id)) into v_w_n1
    from p574_cap where run_id = 11 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by id)) into v_w_n2
    from p574_cap where run_id = 12 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by id)) into v_w_o1
    from p574_cap where run_id = 13 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by id)) into v_a_n1
    from p574_cap where run_id = 21 and tbl = 'audit_logs';
  select md5(string_agg(id::text, ',' order by id)) into v_a_n2
    from p574_cap where run_id = 22 and tbl = 'audit_logs';
  select md5(string_agg(id::text, ',' order by id)) into v_a_o1
    from p574_cap where run_id = 23 and tbl = 'audit_logs';
  perform tests.assert_true(
    v_w_l1 = v_w_ref and v_w_l1 = v_w_n1 and v_w_l1 = v_w_n2 and v_w_l1 = v_w_o1,
    'PERF-01a: webrtc deleted-id set digest differs across arms (live/old/new reps)');
  perform tests.assert_true(
    v_a_l1 = v_a_ref and v_a_l1 = v_a_n1 and v_a_l1 = v_a_n2 and v_a_l1 = v_a_o1,
    'PERF-01a: audit deleted-id set digest differs across arms (live/old/new reps)');

  select md5(string_agg(id::text, ',' order by ord)) into v_wo_n1
    from p574_cap where run_id = 11 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by ord)) into v_wo_n2
    from p574_cap where run_id = 12 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by ord)) into v_wo_old
    from p574_cap where run_id = 13 and tbl = 'webrtc_signals';
  select md5(string_agg(id::text, ',' order by ord)) into v_ao_n1
    from p574_cap where run_id = 21 and tbl = 'audit_logs';
  select md5(string_agg(id::text, ',' order by ord)) into v_ao_n2
    from p574_cap where run_id = 22 and tbl = 'audit_logs';
  select md5(string_agg(id::text, ',' order by ord)) into v_ao_old
    from p574_cap where run_id = 23 and tbl = 'audit_logs';
  perform tests.assert_true(
    v_wo_n1 = v_wo_n2 and v_wo_n1 = v_wo_old,
    'PERF-01a: webrtc batch ORDER digest differs across identical reps (new rep1/new rep2/old rep)');
  perform tests.assert_true(
    v_ao_n1 = v_ao_n2 and v_ao_n1 = v_ao_old,
    'PERF-01a: audit batch ORDER digest differs across identical reps (new rep1/new rep2/old rep)');

  raise notice 'PERF-01a webrtc digests: set live1=% ref=% rep1=% rep2=% oldrep=% | order rep1=% rep2=% oldrep=%',
    v_w_l1, v_w_ref, v_w_n1, v_w_n2, v_w_o1, v_wo_n1, v_wo_n2, v_wo_old;
  raise notice 'PERF-01a audit digests:  set live1=% ref=% rep1=% rep2=% oldrep=% | order rep1=% rep2=% oldrep=%',
    v_a_l1, v_a_ref, v_a_n1, v_a_n2, v_a_o1, v_ao_n1, v_ao_n2, v_ao_old;

  -- 5d. (c) repeatability, live. Re-seed identical rows and run again: the
  -- deleted SET must match run 1 (order is not asserted across live runs, see
  -- the ctid-layout note in the header). Then run 3 immediately: zero.
  update p574_run set run_id = 2;
  insert into public.webrtc_signals (
    id, session_id, from_user_id, kind, payload, created_at
  )
  select s.id, v_session, v_parent, 'ice', '{}'::jsonb, s.created_at
  from p574_spec_w s;
  insert into public.audit_logs (
    id, family_id, actor_user_id, event_type, metadata, created_at
  )
  select s.id, v_family, v_parent, 'p574_backlog', '{}'::jsonb, s.created_at
  from p574_spec_a s;
  select public.run_retention_sweep() into v_r2;
  perform tests.assert_true(
    (v_r2 ->> 'webrtc_signals')::integer = v_n_w
      and (v_r2 ->> 'audit_logs')::integer = v_n_a,
    'PERF-01a(c): re-seeded run 2 must delete the same backlog, got ' || v_r2::text);
  select md5(string_agg(id::text, ',' order by id)) into v_w_l2
    from p574_cap where run_id = 2 and tbl = 'webrtc_signals';
  perform tests.assert_true(v_w_l2 = v_w_l1,
    'PERF-01a(c): live run 2 deleted-id SET differs from run 1 (webrtc): '
    || v_w_l2 || ' vs ' || v_w_l1);
  select md5(string_agg(id::text, ',' order by id)) into v_a_l2
    from p574_cap where run_id = 2 and tbl = 'audit_logs';
  perform tests.assert_true(v_a_l2 = v_a_l1,
    'PERF-01a(c): live run 2 deleted-id SET differs from run 1 (audit): '
    || v_a_l2 || ' vs ' || v_a_l1);

  update p574_run set run_id = 3;
  select public.run_retention_sweep() into v_r3;
  perform tests.assert_true(
    (v_r3 ->> 'webrtc_signals')::integer = 0
      and (v_r3 ->> 'audit_logs')::integer = 0
      and not exists (select 1 from p574_cap where run_id = 3),
    'PERF-01a(c): a back-to-back third call must delete zero rows, got ' || v_r3::text);

  -- 5e. (d) empty-dataset path: with no backlog anywhere, the first batch of
  -- each loop deletes 0 rows and the function must exit immediately - it
  -- returns, and the row-capture trigger records zero deletions for the call.
  update p574_run set run_id = 90;
  delete from public.webrtc_signals where id in (v_fresh_w1, v_fresh_w2);
  delete from public.audit_logs where id = v_fresh_a1;
  update p574_run set run_id = 4;
  perform tests.assert_true(
    not exists (select 1 from public.webrtc_signals
      where created_at < now() - interval '7 days')
      and not exists (select 1 from public.audit_logs
        where created_at < now() - interval '365 days'),
    'PERF-01a(d) precondition: no aged global rows may remain for the empty-path call');
  select public.run_retention_sweep() into v_r4;
  perform tests.assert_true(
    (v_r4 ->> 'webrtc_signals')::integer = 0
      and (v_r4 ->> 'audit_logs')::integer = 0
      and not exists (select 1 from p574_cap where run_id = 4),
    'PERF-01a(d): the empty-dataset path must terminate immediately with zero deletions, got '
    || v_r4::text);

  -- every arm captured exactly the expected size (live runs appear under both
  -- tbl labels, so 12 groups: webrtc 1/2/10/11/12/13, audit 1/2/20/21/22/23)
  select count(*),
         count(*) filter (
           where g.n <> case when g.tbl = 'webrtc_signals' then v_n_w else v_n_a end
         )
    into v_groups, v_cnt
  from (
    select c.run_id, c.tbl, count(*) as n
    from p574_cap c
    where c.run_id in (1, 2, 10, 11, 12, 13, 20, 21, 22, 23)
    group by c.run_id, c.tbl
  ) g;
  perform tests.assert_true(v_groups = 12 and v_cnt = 0,
    'PERF-01a: arm batch counts wrong: ' || v_groups || ' groups, ' || v_cnt
    || ' off expected (v_batch = 10000 loop-exit evidence)');
end;
$$;

-- Section 5 harness is scoped to this file: remove every permanent object it
-- added (triggers on the real tables, functions, temp tables). No COMMIT or
-- procedure syntax is introduced anywhere: the whole section stays inside the
-- same function-shaped contract asserted in 4e.
drop trigger p574_cap_w on public.webrtc_signals;
drop trigger p574_cap_a on public.audit_logs;
drop function p574_capture_delete();
drop function p574_shape_pass(text, text, boolean, integer, timestamptz, interval);
drop table p574_snap_w, p574_snap_a, p574_c1w, p574_c2w, p574_c3w,
           p574_c1a, p574_c2a, p574_c3a, p574_spec_w, p574_spec_a,
           p574_cap, p574_run;

-- Audit append-only refusal is owned by 30_rls.sql and is deliberately not
-- re-probed here: this suite runs as the database superuser, which the trigger
-- in 20260101000000_core.sql:543-566 exempts, so a refusal could not be told
-- apart from an RLS zero-row update.

do $$
begin
  raise notice 'ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED';
end;
$$;
