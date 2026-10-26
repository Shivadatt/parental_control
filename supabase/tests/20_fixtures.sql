-- Deterministic fixtures shared by the RLS and function tests.
-- Run AFTER 10_schema.sql. This file writes data as the session owner.

-- ---------------------------------------------------------------------------
-- users + profiles (profiles are created by private.handle_new_user trigger)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'parent1@example.test', now(),
   '{"display_name":"Parent One"}'),
  ('22222222-2222-4222-8222-222222222222', 'parent2@example.test', now(),
   '{"display_name":"Parent Two"}'),
  ('55555555-5555-4555-8555-555555555555', 'parent3@example.test', now(),
   '{"display_name":"Parent Three"}'),
  ('33333333-3333-4333-8333-333333333333', 'child1@example.test', now(),
   '{"display_name":"Child One"}'),
  ('44444444-4444-4444-8444-444444444444', 'child2@example.test', now(),
   '{"display_name":"Child Two"}'),
  ('66666666-6666-4666-8666-666666666666', 'child3@example.test', now(),
   '{"display_name":"Child Three"}'),
  ('77777777-7777-4777-8777-777777777777', 'child4@example.test', now(),
   '{"display_name":"Child Four"}');

select tests.assert_true(
  (select count(*) from public.profiles
   where id in (
     '11111111-1111-4111-8111-111111111111',
     '22222222-2222-4222-8222-222222222222',
     '55555555-5555-4555-8555-555555555555',
     '33333333-3333-4333-8333-333333333333',
     '44444444-4444-4444-8444-444444444444',
     '66666666-6666-4666-8666-666666666666',
     '77777777-7777-4777-8777-777777777777'
   )) = 7,
  'auth.users trigger must create seven profiles'
);

update public.profiles set role = 'parent'
where id in (
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '55555555-5555-4555-8555-555555555555'
);
update public.profiles set role = 'child'
where id in (
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
  '66666666-6666-4666-8666-666666666666',
  '77777777-7777-4777-8777-777777777777'
);

-- ---------------------------------------------------------------------------
-- families via the service RPC (also covered again in 40_functions.sql)
-- ---------------------------------------------------------------------------
insert into tests.state (key, value)
select 'family1', public.create_family_with_owner(
  '11111111-1111-4111-8111-111111111111', 'Family One'
)->>'id';

insert into tests.state (key, value)
select 'family2', public.create_family_with_owner(
  '22222222-2222-4222-8222-222222222222', 'Family Two'
)->>'id';

insert into public.family_members (family_id, user_id, role, status)
values
  (tests.get('family1')::uuid, '33333333-3333-4333-8333-333333333333', 'child', 'active'),
  (tests.get('family1')::uuid, '55555555-5555-4555-8555-555555555555', 'parent', 'active'),
  (tests.get('family1')::uuid, '77777777-7777-4777-8777-777777777777', 'child', 'active'),
  (tests.get('family2')::uuid, '44444444-4444-4444-8444-444444444444', 'child', 'active');

-- ---------------------------------------------------------------------------
-- devices
-- ---------------------------------------------------------------------------
insert into public.devices (
  id, family_id, child_user_id, installation_id, display_name, platform,
  status, secret_hash, credential_issued_at, credential_revoked_at,
  last_seen_at, enforcement_mode
) values
  ('d0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   '33333333-3333-4333-8333-333333333333', 'install-c1-0001', 'Child One Phone',
   'android', 'active', repeat('a', 64), now() - interval '2 days', null,
   now(), 'device_admin'),
  ('d0000000-0000-4000-8000-000000000002', tests.get('family2')::uuid,
   '44444444-4444-4444-8444-444444444444', 'install-c2-0002', 'Child Two Phone',
   'android', 'active', repeat('b', 64), now() - interval '1 day', null,
   now(), 'device_admin'),
  ('d0000000-0000-4000-8000-000000000003', tests.get('family1')::uuid,
   '33333333-3333-4333-8333-333333333333', 'install-c1-old3', 'Child One Old Phone',
   'android', 'revoked', null, now() - interval '30 days', now() - interval '1 day',
   now() - interval '2 days', 'none'),
  ('d0000000-0000-4000-8000-000000000004', tests.get('family1')::uuid,
   '77777777-7777-4777-8777-777777777777', 'install-c4-0004', 'Child Four Phone',
   'android', 'active', repeat('d', 64), now() - interval '1 day', null,
   now(), 'device_admin'),
  ('d0000000-0000-4000-8000-000000000006', tests.get('family1')::uuid,
   '77777777-7777-4777-8777-777777777777', 'install-c4-0006', 'Child Four Tablet',
   'android', 'pending', null, null, null, null, 'none'),
  ('d0000000-0000-4000-8000-000000000007', tests.get('family1')::uuid,
   '66666666-6666-4666-8666-666666666666', 'install-c3-0007', 'Child Three Phone',
   'android', 'active', repeat('e', 64), now(), null, now(), 'device_admin');

-- ---------------------------------------------------------------------------
-- policy for device 1 (creates version 1 + an apply_policy command)
-- ---------------------------------------------------------------------------
select public.apply_policy_version(
  'd0000000-0000-4000-8000-000000000001',
  '{
    "enforce_app_blocks": true,
    "block_all_except_allowed": false,
    "blocked_packages": ["com.example.blocked"],
    "allowed_packages": [],
    "app_rules": [],
    "daily_screen_time_limit_minutes": 120,
    "bedtime_start_minutes": 1200,
    "bedtime_end_minutes": 420
  }'::jsonb,
  '11111111-1111-4111-8111-111111111111',
  'fixture-policy-key-1'
);

-- ---------------------------------------------------------------------------
-- commands for the isolated polling device 7
-- ---------------------------------------------------------------------------
insert into public.device_commands (
  id, device_id, family_id, type, payload, status,
  idempotency_key, created_by, created_at, expires_at
) values
  ('c0000000-0000-4000-8000-000000000101',
   'd0000000-0000-4000-8000-000000000007', tests.get('family1')::uuid,
   'sync_policy', '{"reason":"fixture"}'::jsonb, 'pending',
   'fixture-cmd-valid', '11111111-1111-4111-8111-111111111111',
   now() - interval '1 minute', now() + interval '10 minutes'),
  ('c0000000-0000-4000-8000-000000000102',
   'd0000000-0000-4000-8000-000000000007', tests.get('family1')::uuid,
   'sync_policy', '{"reason":"expired"}'::jsonb, 'pending',
   'fixture-cmd-expired', '11111111-1111-4111-8111-111111111111',
   now() - interval '2 minutes', now() - interval '1 minute');

-- ---------------------------------------------------------------------------
-- telemetry
-- ---------------------------------------------------------------------------
insert into public.usage_daily (
  device_id, family_id, day, package_name, app_label, total_ms, last_used_at
) values
  ('d0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   current_date - 1, 'com.example.kid', 'Kid App', 90000, now() - interval '3 hours'),
  ('d0000000-0000-4000-8000-000000000002', tests.get('family2')::uuid,
   current_date - 1, 'com.example.other', 'Other App', 120000, now() - interval '2 hours');

insert into public.location_events (
  device_id, family_id, lat, lng, accuracy_m, recorded_at
) values
  ('d0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   51.5007, -0.1246, 12.5, now() - interval '5 minutes'),
  ('d0000000-0000-4000-8000-000000000002', tests.get('family2')::uuid,
   40.7128, -74.0060, 20.0, now() - interval '6 minutes');

insert into public.device_apps (
  device_id, family_id, package_name, label, is_system
) values
  ('d0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   'com.example.kid', 'Kid App', false),
  ('d0000000-0000-4000-8000-000000000002', tests.get('family2')::uuid,
   'com.example.other', 'Other App', false);

insert into public.safe_zones (
  id, family_id, name, lat, lng, radius_m, created_by
) values
  ('f0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   'School', 51.5007, -0.1246, 200, '11111111-1111-4111-8111-111111111111');

insert into public.safety_alerts (
  id, family_id, device_id, type, severity, message, payload
) values
  ('a0000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   'd0000000-0000-4000-8000-000000000001', 'low_battery', 'warning',
   'Battery is low.', '{"battery_level":15}'::jsonb);

-- ---------------------------------------------------------------------------
-- remote sessions + signalling
-- ---------------------------------------------------------------------------
insert into public.remote_sessions (
  id, family_id, device_id, parent_user_id, child_user_id, kind, status,
  requested_at, accepted_at, expires_at, consent_recorded, session_nonce
) values
  ('50000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   'd0000000-0000-4000-8000-000000000001',
   '11111111-1111-4111-8111-111111111111',
   '33333333-3333-4333-8333-333333333333', 'video', 'accepted',
   now() - interval '5 minutes', now() - interval '4 minutes',
   now() + interval '30 minutes', true,
   '70000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000002', tests.get('family2')::uuid,
   'd0000000-0000-4000-8000-000000000002',
   '22222222-2222-4222-8222-222222222222',
   '44444444-4444-4444-8444-444444444444', 'audio', 'active',
   now() - interval '1 hour', now() - interval '59 minutes',
   now() - interval '5 minutes', true,
   '70000000-0000-4000-8000-000000000002');

insert into public.webrtc_signals (
  id, session_id, from_user_id, kind, payload
) values
  ('60000000-0000-4000-8000-000000000001',
   '50000000-0000-4000-8000-000000000001',
   '11111111-1111-4111-8111-111111111111',
   'offer', '{"sdp":"fixture-offer"}'::jsonb);

-- ---------------------------------------------------------------------------
-- pairing tokens and requests
-- ---------------------------------------------------------------------------
insert into public.device_pairing_tokens (
  id, child_user_id, code_hash, expires_at, status, created_by
) values
  ('10000000-0000-4000-8000-000000000001',
   '66666666-6666-4666-8666-666666666666', repeat('c', 64),
   now() + interval '10 minutes', 'active',
   '66666666-6666-4666-8666-666666666666'),
  ('10000000-0000-4000-8000-000000000002',
   '66666666-6666-4666-8666-666666666666', repeat('d', 64),
   now() + interval '10 minutes', 'active',
   '66666666-6666-4666-8666-666666666666'),
  ('10000000-0000-4000-8000-000000000003',
   '77777777-7777-4777-8777-777777777777', repeat('9', 64),
   now() + interval '10 minutes', 'active',
   '77777777-7777-4777-8777-777777777777'),
  ('10000000-0000-4000-8000-000000000004',
   '66666666-6666-4666-8666-666666666666', repeat('8', 64),
   now() - interval '10 minutes', 'active',
   '66666666-6666-4666-8666-666666666666');

insert into public.pairing_requests (
  id, token_id, family_id, parent_user_id, child_user_id, status,
  expires_at
) values
  ('20000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000001', tests.get('family1')::uuid,
   '11111111-1111-4111-8111-111111111111',
   '66666666-6666-4666-8666-666666666666', 'pending_child',
   now() + interval '10 minutes'),
  ('20000000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000002', tests.get('family1')::uuid,
   '11111111-1111-4111-8111-111111111111',
   '66666666-6666-4666-8666-666666666666', 'pending_child',
   now() + interval '10 minutes'),
  ('20000000-0000-4000-8000-000000000003',
   '10000000-0000-4000-8000-000000000003', tests.get('family1')::uuid,
   '11111111-1111-4111-8111-111111111111',
   '77777777-7777-4777-8777-777777777777', 'pending_child',
   now() + interval '10 minutes'),
  ('20000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004', tests.get('family1')::uuid,
   '11111111-1111-4111-8111-111111111111',
   '66666666-6666-4666-8666-666666666666', 'pending_child',
   now() - interval '10 minutes');
