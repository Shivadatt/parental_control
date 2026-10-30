-- Abandoned consented-session sweep
-- (migration 20261030000100_abandoned_session_sweep.sql).
--
-- Run AFTER 20_fixtures.sql and the migrations. Self-contained: own family,
-- devices and accounts (af../bf../cf../df../ef../ff.. UUIDs), so no fixture
-- owned by another test file is mutated.
--
-- The default sweep is deliberately wide (24 hours): it also closes consented
-- rows left behind by earlier tests (61 deliberately keeps 2- and 3-day-old
-- accepted/active rows), so assertions are per-row, never a global row count.
-- NOT EXECUTED in Phase 1 unless the local plain-PostgreSQL chain was run; see
-- docs/implementation/deployment/manifest.md.
do $$
declare
  v_parent uuid := 'af000000-0000-4000-8000-0000000000a1';
  v_child uuid := 'bf000000-0000-4000-8000-0000000000c1';
  v_family uuid := 'cf000000-0000-4000-8000-000000000001';
  v_device uuid := 'df000000-0000-4000-8000-000000000001';
  v_abandoned uuid := 'ef000000-0000-4000-8000-000000000001';
  v_defensive uuid := 'ef000000-0000-4000-8000-000000000002';
  v_live_6h uuid := 'ef000000-0000-4000-8000-000000000003';
  v_young uuid := 'ef000000-0000-4000-8000-000000000004';
  v_pending uuid := 'ef000000-0000-4000-8000-000000000005';
  v_declined uuid := 'ef000000-0000-4000-8000-000000000006';
  v_closed integer;
  v_second integer;
  v_status text;
  v_reason text;
  v_ended_by uuid;
  v_age integer;
  v_audit integer;
  v_flag boolean;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'sweep-parent@example.test', now()),
    (v_child, 'sweep-child@example.test', now());

  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child' where id = v_child;

  insert into public.families (id, name, owner_id)
  values (v_family, 'Sweep Family', v_parent);

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values (
    v_device, v_family, v_child, 'sweep-device', 'Sweep Phone', 'active'
  );

  -- -----------------------------------------------------------------------
  -- 0. Contract: service-only SECURITY DEFINER function with a pinned
  --    search_path, plus the partial index the sweep relies on.
  -- -----------------------------------------------------------------------
  select p.prosecdef
    and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
    into v_flag
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'expire_abandoned_sessions'
    and p.pronargs = 1
    and p.proargtypes[0] = 'interval'::regtype;
  perform tests.assert_true(
    coalesce(v_flag, false),
    'expire_abandoned_sessions(interval) must be SECURITY DEFINER with a pinned search_path'
  );

  perform tests.assert_true(
    not has_function_privilege(
      'anon', 'public.expire_abandoned_sessions(interval)', 'execute'
    ),
    'anon must not execute the sweeper'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated', 'public.expire_abandoned_sessions(interval)', 'execute'
    ),
    'authenticated must not execute the sweeper'
  );
  perform tests.assert_true(
    has_function_privilege(
      'service_role', 'public.expire_abandoned_sessions(interval)', 'execute'
    ),
    'service_role must execute the sweeper'
  );
  perform tests.assert_true(
    exists (
      select 1 from pg_indexes
      where schemaname = 'public'
        and indexname = 'remote_sessions_abandoned_idx'
    ),
    'the partial index remote_sessions_abandoned_idx must exist'
  );

  -- -----------------------------------------------------------------------
  -- 1. Fixtures: consented rows of different ages, one pending row and one
  --    terminal row.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, expires_at, consent_recorded
  ) values
    -- consented 2 days ago, then abandoned
    (v_abandoned, v_family, v_device, v_parent, v_child, 'audio',
     'accepted', now() - interval '2 days', now() - interval '2 days',
     null, true),
    -- defensive: consented, accepted_at missing, requested_at is the anchor
    (v_defensive, v_family, v_device, v_parent, v_child, 'audio',
     'accepted', now() - interval '3 days', null, null, true),
    -- a long but live call: 6 hours is not abandonment
    (v_live_6h, v_family, v_device, v_parent, v_child, 'audio',
     'active', now() - interval '6 hours', now() - interval '6 hours',
     null, true),
    -- consented 30 minutes ago
    (v_young, v_family, v_device, v_parent, v_child, 'audio',
     'active', now() - interval '30 minutes', now() - interval '30 minutes',
     null, true),
    -- pending for 2 days: the pending-expiry job owns it, not this sweep
    (v_pending, v_family, v_device, v_parent, v_child, 'audio',
     'requested', now() - interval '2 days', null,
     now() - interval '2 days' + interval '10 minutes', false),
    -- terminal history is final
    (v_declined, v_family, v_device, v_parent, v_child, 'audio',
     'declined', now() - interval '3 days', null,
     now() - interval '3 days' + interval '10 minutes', false);

  -- -----------------------------------------------------------------------
  -- 2. Default sweep closes only the abandoned consented rows.
  -- -----------------------------------------------------------------------
  v_closed := public.expire_abandoned_sessions();
  perform tests.assert_true(
    v_closed >= 1,
    'the default sweep must close at least the abandoned fixture, got ' || v_closed
  );

  select status, ended_reason, ended_by into v_status, v_reason, v_ended_by
  from public.remote_sessions where id = v_abandoned;
  perform tests.assert_true(
    v_status = 'expired',
    'a 2-day-old accepted session must be closed, got ' || coalesce(v_status, '<none>')
  );
  perform tests.assert_true(
    v_reason = 'abandoned',
    'the close reason must be abandoned, got ' || coalesce(v_reason, '<none>')
  );
  perform tests.assert_true(
    v_ended_by is null,
    'ended_by is a profiles uuid: a system close must leave it null'
  );
  perform tests.assert_true(
    (select ended_at is not null from public.remote_sessions where id = v_abandoned),
    'a closed session must carry ended_at'
  );

  select status into v_status
  from public.remote_sessions where id = v_defensive;
  perform tests.assert_true(
    v_status = 'expired',
    'a consented row without accepted_at must fall back to requested_at, got '
      || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 3. Live sessions and foreign statuses are untouched.
  -- -----------------------------------------------------------------------
  select status into v_status from public.remote_sessions where id = v_live_6h;
  perform tests.assert_true(
    v_status = 'active',
    'a 6-hour-old active call must survive the 24-hour sweep, got '
      || coalesce(v_status, '<none>')
  );
  select status into v_status from public.remote_sessions where id = v_young;
  perform tests.assert_true(
    v_status = 'active',
    'a 30-minute-old active call must survive the 24-hour sweep, got '
      || coalesce(v_status, '<none>')
  );
  select status into v_status from public.remote_sessions where id = v_pending;
  perform tests.assert_true(
    v_status = 'requested',
    'a pending request is the pending-expiry job''s responsibility, got '
      || coalesce(v_status, '<none>')
  );
  select status into v_status from public.remote_sessions where id = v_declined;
  perform tests.assert_true(
    v_status = 'declined',
    'terminal history must not be rewritten, got ' || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 4. One audit row per closed session, system actor, no SQL message.
  -- -----------------------------------------------------------------------
  select count(*) into v_audit
  from public.audit_logs
  where event_type = 'session_expired'
    and target_type = 'remote_session'
    and target_id = v_abandoned::text;
  perform tests.assert_true(
    v_audit = 1,
    'exactly one session_expired audit row per closed session, got ' || v_audit
  );

  select (metadata ->> 'age_seconds')::integer, metadata ->> 'reason'
    into v_age, v_reason
  from public.audit_logs
  where event_type = 'session_expired'
    and target_id = v_abandoned::text;
  perform tests.assert_true(
    v_age between 172700 and 172900,
    'age_seconds must reflect the consent age (~172800), got ' || coalesce(v_age::text, '<none>')
  );
  perform tests.assert_true(
    v_reason = 'abandoned',
    'audit metadata.reason must be abandoned, got ' || coalesce(v_reason, '<none>')
  );
  perform tests.assert_true(
    (select actor_user_id is null and device_id = v_device
       from public.audit_logs
      where event_type = 'session_expired' and target_id = v_abandoned::text),
    'the audit row records the system actor (null) and the device'
  );

  -- -----------------------------------------------------------------------
  -- 5. Idempotent: an immediate second run closes nothing and adds no audit.
  -- -----------------------------------------------------------------------
  v_second := public.expire_abandoned_sessions();
  perform tests.assert_true(
    v_second = 0,
    'a repeated sweep must close nothing, got ' || v_second
  );
  select count(*) into v_audit
  from public.audit_logs
  where event_type = 'session_expired'
    and target_id = v_abandoned::text;
  perform tests.assert_true(
    v_audit = 1,
    'the repeated sweep must not duplicate the audit row, got ' || v_audit
  );

  -- -----------------------------------------------------------------------
  -- 6. An explicit window is honoured; a live call inside it survives.
  -- -----------------------------------------------------------------------
  perform public.expire_abandoned_sessions(interval '7 hours');
  select status into v_status from public.remote_sessions where id = v_live_6h;
  perform tests.assert_true(
    v_status = 'active',
    'a 6-hour-old call survives a 7-hour window, got ' || coalesce(v_status, '<none>')
  );

  perform public.expire_abandoned_sessions(interval '5 hours');
  select status, ended_reason into v_status, v_reason
  from public.remote_sessions where id = v_live_6h;
  perform tests.assert_true(
    v_status = 'expired' and v_reason = 'abandoned',
    'a 6-hour-old consented session is closed by a 5-hour window, got '
      || coalesce(v_status, '<none>') || '/' || coalesce(v_reason, '<none>')
  );

  select status into v_status from public.remote_sessions where id = v_young;
  perform tests.assert_true(
    v_status = 'active',
    'a 30-minute-old session survives a 5-hour window, got '
      || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 7. Invalid windows are rejected instead of closing live calls.
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    'select public.expire_abandoned_sessions(interval ''0 seconds'')',
    '22023', 'invalid_max_age',
    'a non-positive window must be rejected'
  );
  perform tests.expect_error(
    'select public.expire_abandoned_sessions(interval ''-1 hour'')',
    '22023', 'invalid_max_age',
    'a negative window must be rejected'
  );

  raise notice 'ALL ABANDONED SESSION SWEEP TESTS PASSED';
end;
$$;