-- Per-device remote-session concurrency guard
-- (migration 20261028000100_remote_session_concurrency.sql).
--
-- Run AFTER 20_fixtures.sql and the migrations. Self-contained: every row below
-- uses fresh UUIDs and its own family, so no fixture owned by another test file
-- is read or mutated. A single psql session cannot prove two callers truly
-- block on the advisory lock; this file proves the lock+expiry+rejection
-- contract (the lock serialises callers, so the assertions below are the
-- post-lock state every concurrent caller observes).
do $$
declare
  v_parent uuid := 'cc000000-0000-4000-8000-0000000000a1';
  v_child_1 uuid := 'cc000000-0000-4000-8000-0000000000c1';
  v_child_2 uuid := 'cc000000-0000-4000-8000-0000000000c2';
  v_child_3 uuid := 'cc000000-0000-4000-8000-0000000000c3';
  v_family uuid := 'fc000000-0000-4000-8000-000000000001';
  v_device_1 uuid := 'dc000000-0000-4000-8000-000000000001';
  v_device_2 uuid := 'dc000000-0000-4000-8000-000000000002';
  v_device_3 uuid := 'dc000000-0000-4000-8000-000000000003';
  v_expired_session uuid := 'ec000000-0000-4000-8000-000000000001';
  v_first public.remote_sessions;
  v_second public.remote_sessions;
  v_after_expiry public.remote_sessions;
  v_count integer;
  v_status text;
  v_reason text;
  v_ended_at timestamptz;
  v_state text;
  v_msg text;
begin
  -- -----------------------------------------------------------------------
  -- Own accounts: auth.users first so private.handle_new_user makes profiles.
  -- -----------------------------------------------------------------------
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'concurrency-parent@example.test', now()),
    (v_child_1, 'concurrency-child-1@example.test', now()),
    (v_child_2, 'concurrency-child-2@example.test', now()),
    (v_child_3, 'concurrency-child-3@example.test', now());

  perform tests.assert_true(
    (select count(*) from public.profiles
      where id in (v_parent, v_child_1, v_child_2, v_child_3)) = 4,
    'auth.users trigger must create four concurrency-test profiles'
  );

  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child'
  where id in (v_child_1, v_child_2, v_child_3);

  insert into public.families (id, name, owner_id) values
    (v_family, 'Concurrency Family', v_parent);

  -- Migration 20261030000200 (Phase 1) requires the actor in
  -- request_remote_session to be an active parent of the device's family.
  -- The original fixture created devices without family_members rows because
  -- that check did not exist yet.
  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child_1, 'child', 'active'),
    (v_family, v_child_2, 'child', 'active'),
    (v_family, v_child_3, 'child', 'active');

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values
    (v_device_1, v_family, v_child_1, 'concurrency-device-1',
      'Concurrency Device 1', 'active'),
    (v_device_2, v_family, v_child_2, 'concurrency-device-2',
      'Concurrency Device 2', 'active'),
    (v_device_3, v_family, v_child_3, 'concurrency-device-3',
      'Concurrency Device 3', 'active');

  -- -----------------------------------------------------------------------
  -- 0. The RPC exists (10_schema.sql also checks definer/search_path/grants).
  -- -----------------------------------------------------------------------
  perform tests.assert_true(
    to_regprocedure('public.request_remote_session(uuid,uuid,text)') is not null,
    'public.request_remote_session(uuid,uuid,text) must exist'
  );

  -- -----------------------------------------------------------------------
  -- 1. First request inserts a consent-pending row.
  -- -----------------------------------------------------------------------
  v_first := public.request_remote_session(v_device_1, v_parent, 'audio');
  perform tests.assert_true(
    v_first.id is not null,
    'first request must return the inserted row'
  );
  perform tests.assert_true(
    v_first.status = 'requested',
    'first request must be requested, got ' || v_first.status
  );
  perform tests.assert_true(
    v_first.kind = 'audio',
    'first request must keep the requested kind, got ' || v_first.kind
  );
  perform tests.assert_true(
    v_first.consent_recorded is false,
    'a new request must not record consent'
  );
  perform tests.assert_true(
    v_first.device_id = v_device_1,
    'the request must target the device'
  );
  perform tests.assert_true(
    v_first.family_id = v_family,
    'the request must take family_id from the device'
  );
  perform tests.assert_true(
    v_first.child_user_id = v_child_1,
    'the request must take child_user_id from the device'
  );
  perform tests.assert_true(
    v_first.parent_user_id = v_parent,
    'the request must record the requesting parent'
  );
  perform tests.assert_true(
    v_first.requested_at is not null,
    'requested_at must be set'
  );
  perform tests.assert_true(
    v_first.expires_at between now() + interval '9 minutes'
      and now() + interval '11 minutes',
    'a request must expire in about ten minutes, got ' || v_first.expires_at
  );

  -- -----------------------------------------------------------------------
  -- 2. A second request for the same device is rejected atomically and the
  --    live session is neither ended nor replaced.
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    format(
      'select public.request_remote_session(%L::uuid, %L::uuid, %L::text)',
      v_device_1, v_parent, 'audio'
    ),
    'P0001', 'session_in_progress',
    'a second request for the same device must raise session_in_progress'
  );

  select count(*) into v_count
  from public.remote_sessions
  where device_id = v_device_1;
  perform tests.assert_true(
    v_count = 1,
    'the rejected request must not insert a row, got ' || v_count
  );

  select status into v_status
  from public.remote_sessions
  where id = v_first.id;
  perform tests.assert_true(
    v_status = 'requested',
    'the rejected request must not end the live session, got ' || v_status
  );

  -- -----------------------------------------------------------------------
  -- 3. A request for a different device succeeds (the lock is per device).
  -- -----------------------------------------------------------------------
  v_second := public.request_remote_session(v_device_2, v_parent, 'video');
  perform tests.assert_true(
    v_second.id <> v_first.id,
    'a different device must get its own session row'
  );
  perform tests.assert_true(
    v_second.status = 'requested',
    'the second device session must be requested, got ' || v_second.status
  );
  perform tests.assert_true(
    v_second.device_id = v_device_2,
    'the second device session must target the second device'
  );
  perform tests.assert_true(
    v_second.child_user_id = v_child_2,
    'the second device session must belong to the second child'
  );

  -- -----------------------------------------------------------------------
  -- 4. An expired open row never blocks a new request; it is preserved as
  --    history with status expired. (A partial unique index on status would
  --    have rejected this insert.)
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, expires_at
  ) values (
    v_expired_session, v_family, v_device_3, v_parent, v_child_3, 'audio',
    'requested', now() - interval '30 minutes', now() - interval '20 minutes'
  );

  v_after_expiry := public.request_remote_session(v_device_3, v_parent, 'audio');
  perform tests.assert_true(
    v_after_expiry.id <> v_expired_session,
    'the new request must be a new row, not the expired one'
  );
  perform tests.assert_true(
    v_after_expiry.status = 'requested',
    'a stale row must not block a new request, got ' || v_after_expiry.status
  );
  perform tests.assert_true(
    v_after_expiry.expires_at > now(),
    'the new request must have a future expiry'
  );

  select status, ended_reason, ended_at
  into v_status, v_reason, v_ended_at
  from public.remote_sessions
  where id = v_expired_session;
  perform tests.assert_true(
    v_status = 'expired',
    'the stale row must become expired, got ' || coalesce(v_status, '<none>')
  );
  perform tests.assert_true(
    v_reason = 'expired',
    'the stale row must record ended_reason expired, got '
      || coalesce(v_reason, '<none>')
  );
  perform tests.assert_true(
    v_ended_at is not null,
    'the stale row must record ended_at'
  );

  select count(*) into v_count
  from public.remote_sessions
  where device_id = v_device_3;
  perform tests.assert_true(
    v_count = 2,
    'expiring must keep history: expected 2 rows, got ' || v_count
  );

  select count(*) into v_count
  from public.remote_sessions
  where device_id = v_device_3
    and status in ('requested', 'accepted', 'active');
  perform tests.assert_true(
    v_count = 1,
    'exactly one open row may remain for the device, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 5. Execute is granted only to service_role.
  -- -----------------------------------------------------------------------
  perform tests.assert_true(
    has_function_privilege(
      'service_role',
      'public.request_remote_session(uuid,uuid,text)',
      'execute'
    ),
    'service_role must execute the request RPC'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'anon',
      'public.request_remote_session(uuid,uuid,text)',
      'execute'
    ),
    'anon must not execute the request RPC'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated',
      'public.request_remote_session(uuid,uuid,text)',
      'execute'
    ),
    'authenticated must not execute the request RPC'
  );

  select count(*) into v_count
  from pg_proc p
  join aclexplode(p.proacl) a on true
  where p.oid = 'public.request_remote_session(uuid,uuid,text)'::regprocedure
    and a.grantee = 0
    and a.privilege_type = 'EXECUTE';
  perform tests.assert_true(
    v_count = 0,
    'PUBLIC must hold no EXECUTE grant on the request RPC, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 6. Unauthenticated and authenticated callers cannot invoke the RPC.
  -- -----------------------------------------------------------------------
  v_state := null;
  v_msg := null;
  begin
    set local role anon;
    perform public.request_remote_session(v_device_1, v_parent, 'audio');
  exception
    when others then
      v_state := sqlstate;
      v_msg := sqlerrm;
  end;
  reset role;
  perform tests.assert_true(
    v_state = '42501',
    'anon direct RPC must raise 42501, got ' || coalesce(v_state, '<none>')
  );
  perform tests.assert_true(
    position('permission denied' in lower(coalesce(v_msg, ''))) > 0,
    'anon direct RPC must be permission denied, got ' || coalesce(v_msg, '<none>')
  );

  v_state := null;
  v_msg := null;
  begin
    set local role authenticated;
    perform public.request_remote_session(v_device_1, v_parent, 'audio');
  exception
    when others then
      v_state := sqlstate;
      v_msg := sqlerrm;
  end;
  reset role;
  perform tests.assert_true(
    v_state = '42501',
    'authenticated direct RPC must raise 42501, got ' || coalesce(v_state, '<none>')
  );
  perform tests.assert_true(
    position('permission denied' in lower(coalesce(v_msg, ''))) > 0,
    'authenticated direct RPC must be permission denied, got '
      || coalesce(v_msg, '<none>')
  );

  -- The denied calls must not have created rows.
  select count(*) into v_count
  from public.remote_sessions
  where device_id in (v_device_1, v_device_2, v_device_3);
  perform tests.assert_true(
    v_count = 4,
    'denied direct calls must not insert rows, expected 4, got ' || v_count
  );

  raise notice 'ALL CONCURRENCY TESTS PASSED';
end;
$$;
