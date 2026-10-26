-- RPC / trigger behaviour assertions.
-- Run AFTER 30_rls.sql. This file mutates fixtures (approves pairings, unlinks a
-- child, revokes devices); the earlier test files do not run again.

do $$
declare
  v_family1 uuid := tests.get('family1')::uuid;
  v_family2 uuid := tests.get('family2')::uuid;
  v_parent1 uuid := '11111111-1111-4111-8111-111111111111';
  v_parent2 uuid := '22222222-2222-4222-8222-222222222222';
  v_child1 uuid := '33333333-3333-4333-8333-333333333333';
  v_child3 uuid := '66666666-6666-4666-8666-666666666666';
  v_child4 uuid := '77777777-7777-4777-8777-777777777777';
  v_device1 uuid := 'd0000000-0000-4000-8000-000000000001';
  v_device3 uuid := 'd0000000-0000-4000-8000-000000000003';
  v_device4 uuid := 'd0000000-0000-4000-8000-000000000004';
  v_device7 uuid := 'd0000000-0000-4000-8000-000000000007';
  v_session1 uuid := '50000000-0000-4000-8000-000000000001';
  v_session2 uuid := '50000000-0000-4000-8000-000000000002';
  v_request1 uuid := '20000000-0000-4000-8000-000000000001';
  v_request2 uuid := '20000000-0000-4000-8000-000000000002';
  v_request3 uuid := '20000000-0000-4000-8000-000000000003';
  v_request4 uuid := '20000000-0000-4000-8000-000000000004';
  v_token1 uuid := '10000000-0000-4000-8000-000000000001';
  v_token3 uuid := '10000000-0000-4000-8000-000000000003';
  v_token5 uuid := '10000000-0000-4000-8000-000000000005';
  v_new_session uuid;
  v_result jsonb;
  v_policy jsonb;
  v_policy_id uuid;
  v_command_id uuid;
  v_count integer;
  v_rows integer;
  v_status text;
  v_flag boolean;
begin
  -- -----------------------------------------------------------------------
  -- create_family_with_owner: family + owner membership + audit, atomically
  -- -----------------------------------------------------------------------
  select count(*) into v_count from public.families where owner_id = v_parent1;
  perform tests.assert_true(v_count = 1, 'parent1 owns exactly one family');
  select count(*) into v_count
  from public.family_members
  where family_id = v_family1 and user_id = v_parent1
    and role = 'parent' and status = 'active';
  perform tests.assert_true(v_count = 1, 'family creation adds the owner membership');
  select count(*) into v_count
  from public.audit_logs
  where family_id = v_family1 and event_type = 'family_created';
  perform tests.assert_true(v_count = 1, 'family creation writes an audit row');

  perform tests.expect_error(
    format(
      'select public.create_family_with_owner(%L::uuid, %L)',
      v_parent1, 'Second Family'
    ),
    '23505', 'family_exists',
    'a parent cannot own two active families'
  );

  -- -----------------------------------------------------------------------
  -- apply_policy_version: versioning + idempotency
  -- -----------------------------------------------------------------------
  select public.apply_policy_version(
    v_device1,
    '{"enforce_app_blocks":false,"blocked_packages":["com.example.blocked"]}'::jsonb,
    v_parent1,
    'test-policy-key-2'
  ) into v_result;

  perform tests.assert_true(
    (v_result ->> 'idempotent')::boolean is false,
    'new policy apply is not idempotent'
  );
  perform tests.assert_true(
    (v_result #>> '{policy,version}')::int = 2,
    'policy version increments to 2'
  );
  v_policy_id := (v_result #>> '{policy,id}')::uuid;
  v_command_id := (v_result #>> '{command,id}')::uuid;
  perform tests.assert_true(
    v_result #>> '{command,type}' = 'apply_policy',
    'policy apply queues an apply_policy command'
  );
  perform tests.assert_true(
    v_result #>> '{command,status}' = 'pending',
    'policy command starts pending'
  );

  select count(*) into v_count from public.device_policies where device_id = v_device1;
  perform tests.assert_true(v_count = 2, 'two policy versions exist');
  select count(*) into v_count from public.device_commands where device_id = v_device1;
  perform tests.assert_true(v_count = 2, 'two policy commands exist');

  select public.apply_policy_version(
    v_device1,
    '{"enforce_app_blocks":true}'::jsonb,
    v_parent1,
    'test-policy-key-2'
  ) into v_result;
  perform tests.assert_true(
    (v_result ->> 'idempotent')::boolean is true,
    'repeating the idempotency key is idempotent'
  );
  perform tests.assert_true(
    (v_result #>> '{policy,id}')::uuid = v_policy_id,
    'idempotent apply returns the original policy'
  );
  perform tests.assert_true(
    (v_result #>> '{command,id}')::uuid = v_command_id,
    'idempotent apply returns the original command'
  );
  select count(*) into v_count from public.device_policies where device_id = v_device1;
  perform tests.assert_true(v_count = 2, 'idempotent apply does not bump the version');
  select count(*) into v_count from public.device_commands where device_id = v_device1;
  perform tests.assert_true(v_count = 2, 'idempotent apply does not duplicate commands');
  select policy into v_policy from public.device_policies where id = v_policy_id;
  perform tests.assert_true(
    v_policy = '{"enforce_app_blocks": false, "blocked_packages": ["com.example.blocked"]}'::jsonb,
    'idempotent apply keeps the original policy payload'
  );

  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      v_device3, '{"enforce_app_blocks":false}', v_parent1, 'revoked-device-key'
    ),
    'P0001', 'device_not_active',
    'revoked device cannot receive a policy'
  );
  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      'd0000000-0000-4000-8000-000000000005',
      '{"enforce_app_blocks":false}', v_parent1, 'missing-device-key'
    ),
    'P0002', 'device_not_found',
    'unknown device is rejected'
  );

  -- -----------------------------------------------------------------------
  -- command polling: expiry, delivery, repeat delivery without re-claiming
  -- -----------------------------------------------------------------------
  select public.poll_device_commands(v_device7, 20) into v_result;
  perform tests.assert_true(jsonb_typeof(v_result) = 'array', 'poll returns an array');
  perform tests.assert_true(jsonb_array_length(v_result) = 1, 'poll returns one live command');
  perform tests.assert_true(
    v_result #>> '{0,id}' = 'c0000000-0000-4000-8000-000000000101',
    'poll returns the live command'
  );
  perform tests.assert_true(v_result #>> '{0,status}' = 'delivered', 'poll marks command delivered');
  perform tests.assert_true((v_result #>> '{0,attempts}')::int = 1, 'poll increments attempts');

  select status into v_status
  from public.device_commands
  where id = 'c0000000-0000-4000-8000-000000000102';
  perform tests.assert_true(v_status = 'expired', 'poll expires stale commands');

  select public.poll_device_commands(v_device7, 20) into v_result;
  perform tests.assert_true(jsonb_array_length(v_result) = 1, 'poll redelivers outstanding commands');
  perform tests.assert_true(
    (v_result #>> '{0,attempts}')::int = 1,
    'redelivery does not increment attempts again'
  );

  -- -----------------------------------------------------------------------
  -- cron helpers
  -- -----------------------------------------------------------------------
  select public.expire_stale_sessions() into v_count;
  perform tests.assert_true(v_count >= 1, 'stale session sweep expires at least one session');
  select status into v_status from public.remote_sessions where id = v_session2;
  perform tests.assert_true(v_status = 'expired', 'stale session is expired');
  select status into v_status from public.remote_sessions where id = v_session1;
  perform tests.assert_true(v_status = 'accepted', 'live session is untouched');

  update public.devices set last_seen_at = now() - interval '20 minutes'
  where id = v_device7;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 1, 'fixture device marked stale');

  select public.detect_offline_devices() into v_count;
  perform tests.assert_true(v_count >= 1, 'offline sweep raises an alert');
  select count(*) into v_count
  from public.safety_alerts
  where device_id = v_device7 and type = 'offline';
  perform tests.assert_true(v_count = 1, 'offline alert is created once');
  select public.detect_offline_devices() into v_count;
  perform tests.assert_true(v_count = 0, 'offline alert is suppressed for six hours');

  -- -----------------------------------------------------------------------
  -- pairing consent: forbidden, approve, idempotency, replay, expiry, reject
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    format(
      'select public.respond_pairing_request(%L::uuid, %L::uuid, true)',
      v_request1, v_parent1
    ),
    '42501', 'forbidden',
    'only the requested child can respond'
  );

  select public.respond_pairing_request(v_request1, v_child3, true) into v_result;
  perform tests.assert_true(v_result ->> 'status' = 'approved', 'child approval succeeds');
  perform tests.assert_true(
    (v_result ->> 'family_id')::uuid = v_family1,
    'approval returns the family id'
  );
  select count(*) into v_count
  from public.family_members
  where family_id = v_family1 and user_id = v_child3
    and role = 'child' and status = 'active';
  perform tests.assert_true(v_count = 1, 'approval creates the child membership');
  select status into v_status from public.device_pairing_tokens where id = v_token1;
  perform tests.assert_true(v_status = 'redeemed', 'approval redeems the token');
  select status into v_status from public.pairing_requests where id = v_request1;
  perform tests.assert_true(v_status = 'approved', 'approval marks the request approved');
  select count(*) into v_count
  from public.audit_logs
  where family_id = v_family1 and event_type = 'pairing_approved';
  perform tests.assert_true(v_count = 1, 'approval is audited');

  select public.respond_pairing_request(v_request1, v_child3, true) into v_result;
  perform tests.assert_true(v_result ->> 'status' = 'approved', 'repeat approval is idempotent');
  select count(*) into v_count
  from public.family_members
  where family_id = v_family1 and user_id = v_child3 and role = 'child';
  perform tests.assert_true(v_count = 1, 'repeat approval does not duplicate membership');

  perform tests.expect_error(
    format(
      'select public.respond_pairing_request(%L::uuid, %L::uuid, true)',
      v_request2, v_child3
    ),
    '23505', 'child_already_linked',
    'linked child cannot be approved into a second family'
  );
  perform tests.expect_error(
    format(
      'select public.respond_pairing_request(%L::uuid, %L::uuid, true)',
      v_request4, v_child3
    ),
    'P0001', 'code_expired',
    'expired request cannot be approved'
  );

  select public.respond_pairing_request(v_request3, v_child4, false) into v_result;
  perform tests.assert_true(v_result ->> 'status' = 'rejected', 'child can reject a request');
  select status into v_status from public.device_pairing_tokens where id = v_token3;
  perform tests.assert_true(v_status = 'revoked', 'rejection revokes the token');

  -- Replaying a redeemed token by inserting another request must violate the
  -- one-request-per-token unique constraint.
  perform tests.expect_error(
    format($q$
      insert into public.pairing_requests
        (token_id, family_id, parent_user_id, child_user_id, status, expires_at)
      values (%L::uuid, %L::uuid, %L::uuid, %L::uuid, 'pending_child',
              now() + interval '1 hour')
    $q$, v_token1, v_family1, v_parent1, v_child3),
    '23505', 'pairing_requests',
    'token replay is rejected by the unique request constraint'
  );

  -- -----------------------------------------------------------------------
  -- unlink_child: authorization + atomic cleanup
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    format(
      'select public.unlink_child(%L::uuid, %L::uuid, %L::uuid)',
      v_family1, v_child1, v_child4
    ),
    '42501', 'forbidden',
    'a child cannot unlink a sibling'
  );

  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind, status,
    requested_at, accepted_at, expires_at, consent_recorded, session_nonce
  ) values (
    '50000000-0000-4000-8000-000000000004', v_family1, v_device4,
    v_parent1, v_child4, 'audio', 'active',
    now() - interval '2 minutes', now() - interval '1 minute',
    now() + interval '20 minutes', true,
    '70000000-0000-4000-8000-000000000004'
  );
  insert into public.device_pairing_tokens (
    id, child_user_id, code_hash, expires_at, status, created_by
  ) values (
    v_token5, v_child4, repeat('7', 64), now() + interval '10 minutes',
    'active', v_child4
  );

  select public.unlink_child(v_family1, v_child4, v_parent1) into v_result;
  perform tests.assert_true(v_result ->> 'status' = 'unlinked', 'unlink succeeds');
  perform tests.assert_true(
    (v_result ->> 'devices_revoked')::int = 2,
    'unlink revokes active and pending devices'
  );
  perform tests.assert_true(
    (v_result ->> 'sessions_ended')::int = 1,
    'unlink ends the active session'
  );
  perform tests.assert_true(
    (v_result ->> 'already_removed')::boolean is false,
    'first unlink is not idempotent-marked'
  );

  select status, removed_at is not null into v_status, v_flag
  from public.family_members
  where family_id = v_family1 and user_id = v_child4 and role = 'child';
  perform tests.assert_true(v_status = 'removed' and v_flag, 'membership is removed');

  select count(*) into v_count
  from public.devices
  where child_user_id = v_child4 and status <> 'revoked';
  perform tests.assert_true(v_count = 0, 'all child devices are revoked');
  select count(*) into v_count
  from public.devices
  where child_user_id = v_child4 and secret_hash is null
    and credential_revoked_at is not null;
  perform tests.assert_true(v_count = 2, 'all device credentials are cleared');
  select status into v_status
  from public.remote_sessions
  where id = '50000000-0000-4000-8000-000000000004';
  perform tests.assert_true(v_status = 'ended', 'unlink ends remote sessions');
  select status into v_status from public.device_pairing_tokens where id = v_token5;
  perform tests.assert_true(v_status = 'revoked', 'unlink revokes pairing tokens');
  select count(*) into v_count
  from public.audit_logs
  where family_id = v_family1 and event_type = 'member_removed'
    and metadata ->> 'child_user_id' = v_child4::text;
  perform tests.assert_true(v_count = 1, 'unlink is audited');

  select public.unlink_child(v_family1, v_child4, v_parent1) into v_result;
  perform tests.assert_true(
    (v_result ->> 'already_removed')::boolean is true,
    'repeat unlink is idempotent'
  );
  perform tests.assert_true(
    (v_result ->> 'devices_revoked')::int = 0,
    'repeat unlink revokes nothing'
  );

  -- -----------------------------------------------------------------------
  -- replace_device_apps: atomic snapshot replacement
  -- -----------------------------------------------------------------------
  select public.replace_device_apps(
    v_device1,
    v_family1,
    '[
      {"package_name":"com.example.kid","label":"Kid App","is_system":false,
       "is_suspended":true,"version_name":"1.2.3"},
      {"package_name":"com.example.new","label":"New App","is_system":false,
       "is_suspended":false,"version_name":"2.0"}
    ]'::jsonb
  ) into v_count;
  perform tests.assert_true(v_count = 2, 'app snapshot inserts every row');
  select count(*) into v_count from public.device_apps where device_id = v_device1;
  perform tests.assert_true(v_count = 2, 'app snapshot replaced the old rows');
  select is_suspended into v_flag
  from public.device_apps
  where device_id = v_device1 and package_name = 'com.example.kid';
  perform tests.assert_true(v_flag, 'app snapshot updates existing metadata');

  select public.replace_device_apps(
    v_device1,
    v_family1,
    '[{"package_name":"com.example.new","label":"New App","is_system":false,
       "is_suspended":false,"version_name":"2.1"}]'::jsonb
  ) into v_count;
  perform tests.assert_true(v_count = 1, 'app snapshot can shrink');
  select count(*) into v_count from public.device_apps where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'shrunken snapshot removed old rows');

  perform tests.expect_error(
    format(
      'select public.replace_device_apps(%L::uuid, %L::uuid, %L::jsonb)',
      v_device1, v_family2, '[]'
    ),
    'P0002', 'device_not_found',
    'app snapshot rejects a mismatched family'
  );

  -- -----------------------------------------------------------------------
  -- revoke_device: authorization, credential clear, session end, idempotency
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind, status,
    requested_at, accepted_at, expires_at, consent_recorded, session_nonce
  ) values (
    '50000000-0000-4000-8000-000000000007', v_family1, v_device7,
    v_parent1, v_child3, 'video', 'active',
    now() - interval '2 minutes', now() - interval '1 minute',
    now() + interval '20 minutes', true,
    '70000000-0000-4000-8000-000000000007'
  ) returning id into v_new_session;

  perform tests.expect_error(
    format('select public.revoke_device(%L::uuid, %L::uuid)', v_device7, v_parent2),
    '42501', 'forbidden',
    'a parent from another family cannot revoke a device'
  );

  -- A request redeemed before revocation must not survive it. A request for the
  -- same child in another family belongs to a different revocation scope.
  insert into public.device_pairing_tokens (
    id, child_user_id, code_hash, expires_at, status, created_by
  ) values (
    '10000000-0000-4000-8000-000000000008',
    '66666666-6666-4666-8666-666666666666', repeat('f', 64),
    now() + interval '10 minutes', 'active',
    '66666666-6666-4666-8666-666666666666'
  );
  insert into public.pairing_requests (
    id, token_id, family_id, parent_user_id, child_user_id, status, expires_at
  ) values (
    '20000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000008', tests.get('family2')::uuid,
    '22222222-2222-4222-8222-222222222222',
    '66666666-6666-4666-8666-666666666666', 'pending_child',
    now() + interval '10 minutes'
  );

  select public.revoke_device(v_device7, v_parent1) into v_result;
  perform tests.assert_true(v_result ->> 'status' = 'revoked', 'device revoke succeeds');
  perform tests.assert_true(
    (v_result ->> 'sessions_ended')::int = 1,
    'device revoke ends active sessions'
  );
  select count(*) into v_count
  from public.devices
  where id = v_device7 and status = 'revoked' and secret_hash is null
    and credential_revoked_at is not null;
  perform tests.assert_true(v_count = 1, 'device revoke clears the secret');
  select status into v_status from public.remote_sessions where id = v_new_session;
  perform tests.assert_true(v_status = 'ended', 'device revoke ends the session row');
  select status into v_status from public.pairing_requests where id = v_request2;
  perform tests.assert_true(
    v_status = 'cancelled',
    'device revoke cancels pending pairing requests in the family'
  );
  select status into v_status
  from public.pairing_requests
  where id = '20000000-0000-4000-8000-000000000008';
  perform tests.assert_true(
    v_status = 'pending_child',
    'device revoke leaves another family pairing request untouched'
  );
  select count(*) into v_count
  from public.audit_logs
  where device_id = v_device7 and event_type = 'device_revoked';
  perform tests.assert_true(v_count = 1, 'device revoke is audited');

  select public.revoke_device(v_device7, v_parent1) into v_result;
  perform tests.assert_true(
    (v_result ->> 'sessions_ended')::int = 0,
    'repeat device revoke is idempotent'
  );

  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      v_device7, '{"enforce_app_blocks":false}', v_parent1, 'after-revoke-key'
    ),
    'P0001', 'device_not_active',
    'newly revoked device cannot receive a policy'
  );

  -- -----------------------------------------------------------------------
  -- service-only wrappers are not executable by authenticated
  -- -----------------------------------------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent1::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform tests.expect_error(
    format('select public.poll_device_commands(%L::uuid, 20)', v_device1),
    '42501', 'permission denied',
    'authenticated cannot call poll_device_commands'
  );
  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      v_device1, '{"enforce_app_blocks":false}', v_parent1, 'client-key'
    ),
    '42501', 'permission denied',
    'authenticated cannot call apply_policy_version'
  );

  reset role;
end;
$$;
