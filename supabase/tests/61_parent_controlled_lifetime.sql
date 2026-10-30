-- Parent-controlled session lifetime
-- (migration 20261028000200_parent_controlled_session_lifetime.sql).
--
-- Run AFTER 20_fixtures.sql and the migrations. Self-contained: own family,
-- devices and accounts (dd… UUIDs), so no fixture owned by another test file is
-- mutated. A single psql session cannot wait out a 30-minute clock, so the
-- assertions use explicit timestamps: a legacy deadline in the past stands in
-- for "the old fixed cap elapsed".
do $$
declare
  v_parent uuid := 'dd000000-0000-4000-8000-0000000000a1';
  v_child uuid := 'dd000000-0000-4000-8000-0000000000c1';
  v_child2 uuid := 'dd000000-0000-4000-8000-0000000000c2';
  v_child3 uuid := 'dd000000-0000-4000-8000-0000000000c3';
  v_child4 uuid := 'dd000000-0000-4000-8000-0000000000c4';
  v_family uuid := 'fd000000-0000-4000-8000-000000000001';
  v_device_pending uuid := 'ed000000-0000-4000-8000-000000000001';
  v_device_accepted uuid := 'ed000000-0000-4000-8000-000000000002';
  v_device_active uuid := 'ed000000-0000-4000-8000-000000000003';
  v_device_legacy uuid := 'ed000000-0000-4000-8000-000000000004';
  v_requested uuid := 'ad000000-0000-4000-8000-000000000001';
  v_accepted uuid := 'ad000000-0000-4000-8000-000000000002';
  v_active uuid := 'ad000000-0000-4000-8000-000000000003';
  v_legacy_active uuid := 'ad000000-0000-4000-8000-000000000004';
  v_ended uuid := 'ad000000-0000-4000-8000-000000000005';
  v_revived integer;
  v_status text;
  v_nullable text;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'lifetime-parent@example.test', now()),
    (v_child, 'lifetime-child-1@example.test', now()),
    (v_child2, 'lifetime-child-2@example.test', now()),
    (v_child3, 'lifetime-child-3@example.test', now()),
    (v_child4, 'lifetime-child-4@example.test', now());

  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child'
  where id in (v_child, v_child2, v_child3, v_child4);

  insert into public.families (id, name, owner_id) values
    (v_family, 'Lifetime Family', v_parent);

  -- Migration 20261030000200 (Phase 1) requires the actor in
  -- request_remote_session to be an active parent of the device's family;
  -- this fixture predates that check and only created devices.
  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child, 'child', 'active'),
    (v_family, v_child2, 'child', 'active'),
    (v_family, v_child3, 'child', 'active'),
    (v_family, v_child4, 'child', 'active');

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values
    (v_device_pending, v_family, v_child, 'lifetime-pending', 'Pending Phone', 'active'),
    (v_device_accepted, v_family, v_child2, 'lifetime-accepted', 'Accepted Phone', 'active'),
    (v_device_active, v_family, v_child3, 'lifetime-active', 'Active Phone', 'active'),
    (v_device_legacy, v_family, v_child4, 'lifetime-legacy', 'Legacy Phone', 'active');

  -- -----------------------------------------------------------------------
  -- 0. Schema: a pending request still requires a deadline; a consented one
  --    does not.
  -- -----------------------------------------------------------------------
  select is_nullable into v_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'remote_sessions'
    and column_name = 'expires_at';
  perform tests.assert_true(
    v_nullable = 'YES',
    'remote_sessions.expires_at must be nullable, got ' || coalesce(v_nullable, '<none>')
  );

  perform tests.expect_error(
    format(
      'insert into public.remote_sessions '
      '(id, family_id, device_id, parent_user_id, child_user_id, kind, status, '
      'expires_at) values (%L, %L, %L, %L, %L, %L, %L, null)',
      v_requested, v_family, v_device_pending, v_parent, v_child,
      'audio', 'requested'
    ),
    '23514', 'remote_sessions_pending_expiry_check',
    'a requested row must keep an expiry timestamp'
  );

  -- -----------------------------------------------------------------------
  -- 1. A pending request past its deadline is expired by the cleanup job.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, expires_at
  ) values (
    v_requested, v_family, v_device_pending, v_parent, v_child, 'audio',
    'requested', now() - interval '40 minutes', now() - interval '30 minutes'
  );

  perform public.expire_stale_sessions();

  select status into v_status
  from public.remote_sessions where id = v_requested;
  perform tests.assert_true(
    v_status = 'expired',
    'a stale pending request must be expired by cleanup, got ' || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 2. An accepted session without a deadline is NOT terminated by cleanup,
  --    no matter how much wall-clock time passes.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, expires_at, consent_recorded
  ) values (
    v_accepted, v_family, v_device_accepted, v_parent, v_child2, 'audio',
    'accepted', now() - interval '2 days', now() - interval '2 days', null, true
  );

  perform tests.assert_true(
    (select consent_recorded and expires_at is null
       from public.remote_sessions where id = v_accepted),
    'a consented row must carry consent and no deadline'
  );

  perform public.expire_stale_sessions();
  select status into v_status
  from public.remote_sessions where id = v_accepted;
  perform tests.assert_true(
    v_status = 'accepted',
    'an accepted session without expiry must survive cleanup, got ' || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 3. A legacy consented row that still carries a past deadline (the exact
  --    shape of the old 30-minute cap) is neither expired by cleanup nor
  --    silently ended to admit a new request.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, started_at, expires_at,
    consent_recorded
  ) values (
    v_legacy_active, v_family, v_device_legacy, v_parent, v_child4, 'audio',
    'active', now() - interval '36 minutes', now() - interval '35 minutes',
    now() - interval '35 minutes', now() - interval '5 minutes', true
  );

  perform public.expire_stale_sessions();
  select status into v_status
  from public.remote_sessions where id = v_legacy_active;
  perform tests.assert_true(
    v_status = 'active',
    'a consenting active session must not be expired by elapsed time, got '
      || coalesce(v_status, '<none>')
  );

  perform tests.expect_error(
    format(
      'select public.request_remote_session(%L::uuid, %L::uuid, %L::text)',
      v_device_legacy, v_parent, 'audio'
    ),
    'P0001', 'session_in_progress',
    'a legacy active session must block a new request instead of being ended'
  );

  select status into v_status
  from public.remote_sessions where id = v_legacy_active;
  perform tests.assert_true(
    v_status = 'active',
    'the blocked request must not end the legacy active session, got '
      || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 4. A currently active session without a deadline also survives cleanup.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, started_at, expires_at,
    consent_recorded
  ) values (
    v_active, v_family, v_device_active, v_parent, v_child3, 'audio',
    'active', now() - interval '3 days', now() - interval '3 days',
    now() - interval '3 days', null, true
  );

  perform public.expire_stale_sessions();
  select status into v_status
  from public.remote_sessions where id = v_active;
  perform tests.assert_true(
    v_status = 'active',
    'a three-day-old active session must stay active, got ' || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 5. Accepting a pending request clears its deadline (the Edge Function
  --    writes this patch, and the column/constraint must allow it).
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, expires_at
  ) values (
    v_ended, v_family, v_device_pending, v_parent, v_child, 'audio',
    'requested', now(), now() + interval '10 minutes'
  );

  update public.remote_sessions
  set status = 'accepted',
      accepted_at = now(),
      expires_at = null,
      consent_recorded = true
  where id = v_ended;

  select status into v_status
  from public.remote_sessions where id = v_ended;
  perform tests.assert_true(
    v_status = 'accepted',
    'accepting a request with a null deadline must be allowed, got '
      || coalesce(v_status, '<none>')
  );

  -- -----------------------------------------------------------------------
  -- 6. Terminal rows can never be revived by a late or malicious write.
  -- -----------------------------------------------------------------------
  update public.remote_sessions
  set status = 'ended', ended_at = now(), ended_by = v_parent,
      ended_reason = 'ended_by_parent'
  where id = v_ended;

  perform tests.expect_error(
    format(
      'update public.remote_sessions set status = %L where id = %L',
      'active', v_ended
    ),
    'P0001', 'session_terminal',
    'an ended session must not be revived'
  );

  perform tests.expect_error(
    format(
      'update public.remote_sessions set status = %L where id = %L',
      'accepted', v_requested
    ),
    'P0001', 'session_terminal',
    'an expired session must not be revived'
  );

  select status into v_status
  from public.remote_sessions where id = v_ended;
  perform tests.assert_true(
    v_status = 'ended',
    'the failed revival must leave the row ended, got ' || coalesce(v_status, '<none>')
  );

  select count(*) into v_revived
  from public.remote_sessions
  where status in ('requested', 'accepted', 'active')
    and id in (v_ended, v_requested);
  perform tests.assert_true(
    v_revived = 0,
    'no terminal row may be left open, got ' || v_revived
  );

  raise notice 'ALL PARENT-CONTROLLED LIFETIME TESTS PASSED';
end;
$$;
