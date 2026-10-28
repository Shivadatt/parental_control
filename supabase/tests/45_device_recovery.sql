-- BUG-024: parent-authorized device recovery replaces a lost credential only
-- through a fresh pairing. Run AFTER 20_fixtures.sql (and the recovery
-- migration). Mutates family1/child1; run it last in the suite.
do $$
declare
  v_device1 uuid := 'd0000000-0000-4000-8000-000000000001';
  v_device2 uuid := 'd0000000-0000-4000-8000-000000000002';
  v_parent1 uuid := '11111111-1111-4111-8111-111111111111';
  v_parent2 uuid := '22222222-2222-4222-8222-222222222222';
  v_child1 uuid := '33333333-3333-4333-8333-333333333333';
  v_family1 uuid := tests.get('family1')::uuid;
  v_result jsonb;
  v_count integer;
  v_status text;
  v_secret text;
begin
  -- The RPC is service-only: clients cannot bypass the Edge Function checks.
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated',
      'public.request_device_recovery(uuid,uuid)',
      'execute'
    ),
    'authenticated cannot execute request_device_recovery'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'anon',
      'public.request_device_recovery(uuid,uuid)',
      'execute'
    ),
    'anon cannot execute request_device_recovery'
  );
  perform tests.assert_true(
    has_function_privilege(
      'service_role',
      'public.request_device_recovery(uuid,uuid)',
      'execute'
    ),
    'service_role can execute request_device_recovery'
  );

  -- A child cannot recover their own device: recovery needs a parent.
  begin
    perform public.request_device_recovery(v_device1, v_child1);
    raise exception 'child actor was allowed to start recovery';
  exception when insufficient_privilege then
    null;
  end;

  -- A parent from another family cannot recover this device.
  begin
    perform public.request_device_recovery(v_device1, v_parent2);
    raise exception 'foreign parent was allowed to start recovery';
  exception when insufficient_privilege then
    null;
  end;

  -- A parent cannot recover a device outside their family.
  begin
    perform public.request_device_recovery(v_device2, v_parent1);
    raise exception 'parent recovered a device in another family';
  exception when insufficient_privilege then
    null;
  end;

  -- Unknown device is a clean not-found, not a silent success.
  begin
    perform public.request_device_recovery(
      'd0000000-0000-4000-8000-0000000000ff',
      v_parent1
    );
    raise exception 'unknown device was accepted';
  exception when no_data_found then
    null;
  end;

  -- Happy path: parent1 recovers child1's active device.
  v_result := public.request_device_recovery(v_device1, v_parent1);
  perform tests.assert_true(
    v_result ->> 'status' = 'unlinked',
    'recovery reports the child as unlinked'
  );
  perform tests.assert_true(
    (v_result ->> 'already_removed')::boolean = false,
    'first recovery is not a repeat'
  );
  perform tests.assert_true(
    (v_result ->> 'devices_revoked')::integer >= 1,
    'recovery revokes the lost device credential'
  );

  select status into v_status
  from public.family_members
  where family_id = v_family1 and user_id = v_child1 and role = 'child';
  perform tests.assert_true(v_status = 'removed', 'child membership is removed');

  select status, secret_hash into v_status, v_secret
  from public.devices where id = v_device1;
  perform tests.assert_true(v_status = 'revoked', 'old device row is revoked');
  perform tests.assert_true(v_secret is null, 'old device secret is nulled');

  select count(*) into v_count
  from public.devices
  where family_id = v_family1
    and child_user_id = v_child1
    and status <> 'revoked';
  perform tests.assert_true(v_count = 0, 'no active credential remains for child1');

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child1 and status = 'pending_child';
  perform tests.assert_true(v_count = 0, 'pending pairing requests are cancelled');

  select count(*) into v_count
  from public.audit_logs
  where event_type = 'device_recovery_started'
    and target_id = v_device1::text
    and family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'recovery writes one audit event');

  select count(*) into v_count
  from public.audit_logs
  where event_type = 'device_recovery_started'
    and metadata ?| array['code', 'token', 'secret', 'secret_hash', 'token_hash'];
  perform tests.assert_true(v_count = 0, 'audit metadata contains no secrets');

  -- Replay / repeat: idempotent, no duplicate membership, no new active device.
  v_result := public.request_device_recovery(v_device1, v_parent1);
  perform tests.assert_true(
    (v_result ->> 'already_removed')::boolean = true,
    'repeat recovery is idempotent'
  );
  select count(*) into v_count
  from public.family_members
  where family_id = v_family1 and user_id = v_child1 and role = 'child';
  perform tests.assert_true(v_count = 1, 'repeat recovery does not duplicate membership');

  -- After recovery the child has no active membership, so the Edge Function
  -- pairing-create guard permits a fresh one-time code and a new approval.
  select count(*) into v_count
  from public.family_members
  where user_id = v_child1 and role = 'child' and status = 'active';
  perform tests.assert_true(v_count = 0, 'fresh pairing is required after recovery');
end;
$$;
