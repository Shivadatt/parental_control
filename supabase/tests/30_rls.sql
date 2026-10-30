-- RLS and column-grant assertions. Every block switches to the `authenticated`
-- role and sets request.jwt.claim.sub, then switches back.
-- Run AFTER 20_fixtures.sql.

do $$
declare
  v_family1 uuid := tests.get('family1')::uuid;
  v_family2 uuid := tests.get('family2')::uuid;
  v_parent1 uuid := '11111111-1111-4111-8111-111111111111';
  v_parent2 uuid := '22222222-2222-4222-8222-222222222222';
  v_parent3 uuid := '55555555-5555-4555-8555-555555555555';
  v_child1 uuid := '33333333-3333-4333-8333-333333333333';
  v_child2 uuid := '44444444-4444-4444-8444-444444444444';
  v_child3 uuid := '66666666-6666-4666-8666-666666666666';
  v_child4 uuid := '77777777-7777-4777-8777-777777777777';
  v_device1 uuid := 'd0000000-0000-4000-8000-000000000001';
  v_device2 uuid := 'd0000000-0000-4000-8000-000000000002';
  v_device7 uuid := 'd0000000-0000-4000-8000-000000000007';
  v_zone1 uuid := 'f0000000-0000-4000-8000-000000000001';
  v_session1 uuid := '50000000-0000-4000-8000-000000000001';
  v_count integer;
  v_rows integer;
  v_zone_id uuid;
begin
  -- =========================================================================
  -- Parent One (owner of family1)
  -- =========================================================================
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent1::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count from public.families where id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads own family');
  select count(*) into v_count from public.families where id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2');

  select count(*) into v_count from public.devices where family_id = v_family1;
  perform tests.assert_true(v_count = 5, 'parent1 reads all family1 devices');
  select count(*) into v_count from public.devices where id = v_device2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 device');

  select count(*) into v_count from public.family_members where family_id = v_family1;
  perform tests.assert_true(v_count = 4, 'parent1 reads family1 members');
  select count(*) into v_count from public.family_members where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 members');

  select count(*) into v_count from public.profiles where id in (v_child2, v_parent2);
  perform tests.assert_true(v_count = 0, 'parent1 cannot read unrelated profiles');
  select count(*) into v_count from public.profiles where id in (v_parent3, v_child1, v_child4);
  perform tests.assert_true(v_count = 3, 'parent1 reads family1 profiles');

  select count(*) into v_count from public.audit_logs where family_id = v_family1;
  perform tests.assert_true(v_count >= 1, 'parent1 reads family1 audit');
  select count(*) into v_count from public.audit_logs where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 audit');

  select count(*) into v_count from public.pairing_requests where family_id = v_family1;
  perform tests.assert_true(v_count = 4, 'parent1 reads family1 pairing requests');
  select count(*) into v_count from public.pairing_requests where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 pairing requests');

  select count(*) into v_count from public.safe_zones where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 safe zones');
  select count(*) into v_count from public.safe_zones where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 safe zones');

  select count(*) into v_count from public.remote_sessions where id = v_session1;
  perform tests.assert_true(v_count = 1, 'parent1 reads own remote session');
  select count(*) into v_count from public.remote_sessions
  where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 remote sessions');

  select count(*) into v_count from public.webrtc_signals where session_id = v_session1;
  perform tests.assert_true(v_count = 1, 'parent1 reads session signals');

  select count(*) into v_count from public.usage_daily where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 usage');
  select count(*) into v_count from public.location_events where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 locations');
  select count(*) into v_count from public.device_apps where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 apps');
  select count(*) into v_count from public.safety_alerts where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 alerts');
  select count(*) into v_count from public.device_policies where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent1 reads family1 policies');
  select count(*) into v_count from public.device_commands where family_id = v_family1;
  perform tests.assert_true(v_count = 3, 'parent1 reads family1 commands');
  select count(*) into v_count from public.device_commands where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'parent1 cannot read family2 commands');

  -- Owner can update; the RLS policy is owner-only.
  update public.families set name = name where id = v_family1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 1, 'owner can update family1');
  update public.families set name = name where id = v_family2;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'parent1 cannot update family2');

  -- Parent (non-owner) can read but not update.
  update public.profiles set display_name = display_name where id = v_parent3;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'parent1 cannot update another profile');

  insert into public.safe_zones (family_id, name, lat, lng, radius_m)
  values (v_family1, 'Temporary Zone', 51.0, -0.1, 100)
  returning id into v_zone_id;
  update public.safe_zones set name = 'Temporary Zone 2' where id = v_zone_id;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 1, 'parent1 can update a safe zone');
  -- Zone deletion moved to the service-role `family-admin delete_zone` action
  -- (migration 20261030000200 revokes the client DELETE grant).
  perform tests.expect_error(
    format('delete from public.safe_zones where id = %L::uuid', v_zone_id),
    '42501', 'permission denied',
    'zone deletion is service-only'
  );
  set local role service_role;
  delete from public.safe_zones where id = v_zone_id;
  reset role;
  set local role authenticated;

  perform tests.expect_error(
    'select count(*) from public.device_pairing_tokens',
    '42501', 'permission denied',
    'pairing tokens are service-only'
  );

  reset role;

  -- =========================================================================
  -- Parent Three (non-owner parent in family1): owner-only retention/settings
  -- =========================================================================
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent3::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count from public.families where id = v_family1;
  perform tests.assert_true(v_count = 1, 'parent3 reads family1');
  update public.families set settings = settings where id = v_family1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'non-owner parent cannot change retention settings');
  update public.families set name = name where id = v_family1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'non-owner parent cannot rename family1');

  reset role;

  -- =========================================================================
  -- Child One
  -- =========================================================================
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_child1::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count from public.families where id = v_family1;
  perform tests.assert_true(v_count = 1, 'child1 reads family1');
  select count(*) into v_count from public.families where id = v_family2;
  perform tests.assert_true(v_count = 0, 'child1 cannot read family2');

  select count(*) into v_count from public.devices where family_id = v_family1;
  perform tests.assert_true(v_count = 2, 'child1 reads only its own devices');
  select count(*) into v_count from public.devices where id = v_device2;
  perform tests.assert_true(v_count = 0, 'child1 cannot read family2 device');

  select count(*) into v_count from public.family_members where family_id = v_family1;
  perform tests.assert_true(v_count = 4, 'child1 reads family1 members');

  select count(*) into v_count from public.profiles where id in (v_child2, v_parent2);
  perform tests.assert_true(v_count = 0, 'child1 cannot read unrelated profiles');
  select count(*) into v_count from public.profiles where id in (v_parent1, v_parent3, v_child4);
  perform tests.assert_true(v_count = 3, 'child1 reads family1 profiles');

  select count(*) into v_count from public.audit_logs where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'child1 cannot read audit logs');

  select count(*) into v_count from public.pairing_requests where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'child1 cannot read sibling pairing requests');

  select count(*) into v_count from public.safe_zones where family_id = v_family1;
  perform tests.assert_true(v_count = 1, 'child1 reads family1 safe zones');
  select count(*) into v_count from public.safe_zones where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'child1 cannot read family2 safe zones');

  select count(*) into v_count from public.remote_sessions where id = v_session1;
  perform tests.assert_true(v_count = 1, 'child1 reads own remote session');
  select count(*) into v_count from public.remote_sessions where family_id = v_family2;
  perform tests.assert_true(v_count = 0, 'child1 cannot read family2 remote sessions');

  select count(*) into v_count from public.webrtc_signals where session_id = v_session1;
  perform tests.assert_true(v_count = 1, 'child1 reads the other party signal');

  insert into public.webrtc_signals (session_id, kind, payload)
  values (v_session1, 'ice', '{"candidate":"fixture"}'::jsonb);

  perform tests.expect_error(
    format(
      'insert into public.webrtc_signals (session_id, from_user_id, kind, payload) values (%L::uuid, %L::uuid, %L, %L::jsonb)',
      v_session1, v_parent1, 'ice', '{"candidate":"spoof"}'
    ),
    '42501', 'row-level security',
    'child1 cannot spoof signal authorship'
  );

  select count(*) into v_count from public.usage_daily where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own usage');
  select count(*) into v_count from public.usage_daily where device_id = v_device2;
  perform tests.assert_true(v_count = 0, 'child1 cannot read family2 usage');
  select count(*) into v_count from public.location_events where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own locations');
  select count(*) into v_count from public.device_apps where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own apps');
  select count(*) into v_count from public.safety_alerts where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own device alerts');
  select count(*) into v_count from public.device_policies where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own policy');
  select count(*) into v_count from public.device_commands where device_id = v_device1;
  perform tests.assert_true(v_count = 1, 'child1 reads own commands');
  select count(*) into v_count from public.device_commands where device_id = v_device7;
  perform tests.assert_true(v_count = 0, 'child1 cannot read sibling commands');

  perform tests.expect_error(
    format('update public.profiles set role = %L where id = %L::uuid', 'parent', v_child1),
    '42501', 'permission denied',
    'child cannot promote itself'
  );
  update public.profiles set display_name = display_name where id = v_parent1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'child cannot update another profile');

  update public.families set settings = settings where id = v_family1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'child cannot change family settings');

  perform tests.expect_error(
    format(
      'insert into public.safe_zones (family_id, name, lat, lng, radius_m) values (%L::uuid, %L, 51.0, -0.1, 100)',
      v_family1, 'Child Zone'
    ),
    '42501', 'row-level security',
    'child cannot insert a safe zone'
  );
  perform tests.expect_error(
    format('delete from public.safe_zones where id = %L::uuid', v_zone1),
    '42501', 'permission denied',
    'child cannot delete a safe zone'
  );

  perform tests.expect_error(
    'insert into public.devices (family_id, child_user_id, installation_id, display_name) values (gen_random_uuid(), gen_random_uuid(), ''install-fake-01'', ''Fake'')',
    '42501', 'permission denied',
    'clients cannot insert devices directly'
  );
  perform tests.expect_error(
    format('update public.audit_logs set event_type = %L where family_id = %L::uuid', 'tampered', v_family1),
    '42501', 'permission denied',
    'audit logs are append-only for clients'
  );

  reset role;

  -- =========================================================================
  -- Child Three (not yet linked): own pending requests only
  -- =========================================================================
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_child3::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count from public.pairing_requests where child_user_id = v_child3;
  perform tests.assert_true(v_count = 3, 'child3 reads its own pending requests');
  select count(*) into v_count from public.pairing_requests where family_id = v_family1;
  perform tests.assert_true(v_count = 3, 'child3 cannot read sibling requests');
  select count(*) into v_count from public.families where id = v_family1;
  perform tests.assert_true(v_count = 0, 'unlinked child cannot read family1');
  select count(*) into v_count from public.profiles where id = v_parent1;
  perform tests.assert_true(v_count = 0, 'unlinked child cannot read parent profile');
  select count(*) into v_count from public.devices where id = v_device7;
  perform tests.assert_true(v_count = 1, 'unlinked child still reads its own registered device');

  reset role;

  -- =========================================================================
  -- Parent Two (family2)
  -- =========================================================================
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent2::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count from public.families where id = v_family2;
  perform tests.assert_true(v_count = 1, 'parent2 reads own family');
  select count(*) into v_count from public.devices where family_id = v_family2;
  perform tests.assert_true(v_count = 1, 'parent2 reads own device');
  select count(*) into v_count from public.devices where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 devices');
  select count(*) into v_count from public.profiles where id in (v_parent1, v_child1);
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 profiles');
  select count(*) into v_count from public.audit_logs where family_id = v_family2;
  perform tests.assert_true(v_count = 1, 'parent2 reads own audit');
  select count(*) into v_count from public.audit_logs where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 audit');
  select count(*) into v_count from public.pairing_requests where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 pairing requests');
  select count(*) into v_count from public.safe_zones where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 zones');
  select count(*) into v_count from public.webrtc_signals where session_id = v_session1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 signals');
  select count(*) into v_count from public.remote_sessions where family_id = v_family2;
  perform tests.assert_true(v_count = 1, 'parent2 reads own session');
  select count(*) into v_count from public.usage_daily where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 usage');
  select count(*) into v_count from public.safety_alerts where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 alerts');
  select count(*) into v_count from public.device_commands where family_id = v_family1;
  perform tests.assert_true(v_count = 0, 'parent2 cannot read family1 commands');

  update public.families set name = name where id = v_family1;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(v_rows = 0, 'parent2 cannot update family1');

  reset role;

  -- =========================================================================
  -- anon
  -- =========================================================================
  set local role anon;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);

  perform tests.expect_error(
    'select count(*) from public.profiles',
    '42501', 'permission denied',
    'anon cannot read profiles'
  );
  perform tests.expect_error(
    'select count(*) from public.devices',
    '42501', 'permission denied',
    'anon cannot read devices'
  );
  perform tests.expect_error(
    format('select public.poll_device_commands(%L::uuid, 20)', v_device1),
    '42501', 'permission denied',
    'anon cannot execute service RPCs'
  );

  reset role;
end;
$$;

-- ---------------------------------------------------------------------------
-- Private Realtime channel topics
-- ---------------------------------------------------------------------------
do $$
declare
  v_family1 uuid := tests.get('family1')::uuid;
  v_family2 uuid := tests.get('family2')::uuid;
  v_parent1 uuid := '11111111-1111-4111-8111-111111111111';
  v_child1 uuid := '33333333-3333-4333-8333-333333333333';
  v_child3 uuid := '66666666-6666-4666-8666-666666666666';
  v_child4 uuid := '77777777-7777-4777-8777-777777777777';
  v_session1 uuid := '50000000-0000-4000-8000-000000000001';
  v_session2 uuid := '50000000-0000-4000-8000-000000000002';
  v_allowed boolean;
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Child One participates in session1 and belongs to family1.
  perform set_config('request.jwt.claim.sub', v_child1::text, true);
  select private.realtime_topic_allowed('safety-alerts:' || v_family1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'child1 joins its family alert topic');
  select private.realtime_topic_allowed('safety-alerts:' || v_family2 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'child1 cannot join family2 alert topic');
  select private.realtime_topic_allowed('remote-session-family:' || v_family1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'child1 joins its family session topic');
  select private.realtime_topic_allowed('remote-session:' || v_session1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'child1 joins its own session topic');
  select private.realtime_topic_allowed('webrtc-signals:' || v_session1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'child1 joins its own signal topic');
  select private.realtime_topic_allowed('remote-session:' || v_session2 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'child1 cannot join family2 session topic');

  -- Child Four is in family1 but is not a participant in session1.
  perform set_config('request.jwt.claim.sub', v_child4::text, true);
  select private.realtime_topic_allowed('safety-alerts:' || v_family1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'child4 joins its family alert topic');
  select private.realtime_topic_allowed('remote-session:' || v_session1 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'non-participant cannot join a session topic');

  -- Parent One owns family1 and participates in session1.
  perform set_config('request.jwt.claim.sub', v_parent1::text, true);
  select private.realtime_topic_allowed('remote-session:' || v_session1 || ':1')
    into v_allowed;
  perform tests.assert_true(v_allowed, 'parent1 joins its family session topic');
  select private.realtime_topic_allowed('remote-session:' || v_session2 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'parent1 cannot join family2 session topic');

  -- Child Three is unlinked from family1.
  perform set_config('request.jwt.claim.sub', v_child3::text, true);
  select private.realtime_topic_allowed('safety-alerts:' || v_family1 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'unlinked child cannot join family1 topics');
  select private.realtime_topic_allowed('remote-session:' || v_session1 || ':1')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'unlinked child cannot join session topics');

  -- Malformed and unknown topics never authorize.
  perform set_config('request.jwt.claim.sub', v_child1::text, true);
  select private.realtime_topic_allowed('safety-alerts:not-a-uuid')
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'malformed topic is denied');
  select private.realtime_topic_allowed('unknown-topic:' || v_family1)
    into v_allowed;
  perform tests.assert_true(not v_allowed, 'unknown topic kind is denied');
  select private.realtime_topic_allowed(null) into v_allowed;
  perform tests.assert_true(not v_allowed, 'null topic is denied');

  reset role;
end;
$$;
