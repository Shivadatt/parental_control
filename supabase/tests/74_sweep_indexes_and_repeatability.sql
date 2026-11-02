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

-- Audit append-only refusal is owned by 30_rls.sql and is deliberately not
-- re-probed here: this suite runs as the database superuser, which the trigger
-- in 20260101000000_core.sql:543-566 exempts, so a refusal could not be told
-- apart from an RLS zero-row update.

do $$
begin
  raise notice 'ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED';
end;
$$;
