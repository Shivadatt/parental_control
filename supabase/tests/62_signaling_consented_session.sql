-- Signaling for consented sessions after parent-controlled lifetime
-- (migration 20261028000300_signaling_open_session.sql).
--
-- Run AFTER 20_fixtures.sql and the migrations. Self-contained: own family,
-- devices and accounts (e2… UUIDs), so no fixture owned by another test file is
-- mutated.
--
-- The defect this covers: the original webrtc_signals policies required
-- `s.expires_at > now()`. A consented session has a NULL deadline (and a legacy
-- consented session may carry a past one), so neither participant could send
-- an offer, answer or ICE candidate: media establishment failed for every
-- parent-controlled session.
do $$
declare
  v_parent uuid := 'e2000000-0000-4000-8000-0000000000a1';
  v_child uuid := 'e2000000-0000-4000-8000-0000000000c1';
  v_outsider uuid := 'e2000000-0000-4000-8000-0000000000a2';
  v_family uuid := 'f2000000-0000-4000-8000-000000000001';
  v_device_consented uuid := 'e2000000-0000-4000-8000-0000000000d1';
  v_device_legacy uuid := 'e2000000-0000-4000-8000-0000000000d2';
  v_device_pending uuid := 'e2000000-0000-4000-8000-0000000000d3';
  v_device_ended uuid := 'e2000000-0000-4000-8000-0000000000d4';
  v_consented uuid := 'b2000000-0000-4000-8000-000000000001';
  v_legacy uuid := 'b2000000-0000-4000-8000-000000000002';
  v_pending uuid := 'b2000000-0000-4000-8000-000000000003';
  v_ended uuid := 'b2000000-0000-4000-8000-000000000004';
  v_count integer;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'signaling-parent@example.test', now()),
    (v_child, 'signaling-child@example.test', now()),
    (v_outsider, 'signaling-outsider@example.test', now());

  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child' where id = v_child;

  insert into public.families (id, name, owner_id) values
    (v_family, 'Signaling Family', v_parent);

  -- Signaling policies authorize on active family membership; this fixture
  -- predates the Phase 1 parent-of-family check and never created the rows.
  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child, 'child', 'active');

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values
    (v_device_consented, v_family, v_child, 'signaling-consented', 'Consented Phone', 'active'),
    -- devices_one_active_per_child allows only one active device per child;
    -- device status is irrelevant to signaling, which keys on the session.
    (v_device_legacy, v_family, v_child, 'signaling-legacy', 'Legacy Phone', 'pending'),
    (v_device_pending, v_family, v_child, 'signaling-pending', 'Pending Phone', 'pending'),
    (v_device_ended, v_family, v_child, 'signaling-ended', 'Ended Phone', 'pending');

  -- A consented session has no deadline; default expires_at is NOT NULL before
  -- the lifetime migration, so this insert also proves the column is nullable.
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, expires_at, consent_recorded
  ) values (
    v_consented, v_family, v_device_consented, v_parent, v_child, 'audio',
    'accepted', now() - interval '5 minutes', now() - interval '5 minutes',
    null, true
  );

  -- A legacy consented session still carrying an elapsed deadline must also
  -- keep signaling: elapsed time no longer ends a consented session.
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, started_at, expires_at,
    consent_recorded
  ) values (
    v_legacy, v_family, v_device_legacy, v_parent, v_child, 'audio',
    'active', now() - interval '2 days', now() - interval '2 days',
    now() - interval '2 days', now() - interval '1 day', true
  );

  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, expires_at
  ) values (
    v_pending, v_family, v_device_pending, v_parent, v_child, 'audio',
    'requested', now(), now() + interval '10 minutes'
  );

  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, requested_at, accepted_at, started_at, ended_at, expires_at,
    consent_recorded
  ) values (
    v_ended, v_family, v_device_ended, v_parent, v_child, 'audio',
    'ended', now() - interval '1 hour', now() - interval '1 hour',
    now() - interval '1 hour', now() - interval '30 minutes', null, true
  );

  -- -----------------------------------------------------------------------
  -- 1. Parent may offer on a consented session with a NULL deadline.
  -- -----------------------------------------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.webrtc_signals (session_id, from_user_id, kind, payload)
  values (v_consented, v_parent, 'offer', '{"sdp":"parent-offer"}'::jsonb);

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_consented;
  perform tests.assert_true(
    v_count = 1,
    'the parent must read and insert signals for a consented session without a deadline, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 2. Child may read the parent offer and answer on the same session.
  -- -----------------------------------------------------------------------
  reset role;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_child::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_consented;
  perform tests.assert_true(
    v_count = 1,
    'the child must read the parent offer, got ' || v_count
  );

  insert into public.webrtc_signals (session_id, from_user_id, kind, payload)
  values (v_consented, v_child, 'answer', '{"sdp":"child-answer"}'::jsonb);

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_consented;
  perform tests.assert_true(
    v_count = 2,
    'the child must insert an answer, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 3. A legacy consented session with an elapsed deadline keeps signaling.
  -- -----------------------------------------------------------------------
  insert into public.webrtc_signals (session_id, from_user_id, kind, payload)
  values (v_legacy, v_child, 'ice', '{"candidate":"legacy"}'::jsonb);

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_legacy;
  perform tests.assert_true(
    v_count = 1,
    'a legacy active session must keep signaling, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 4. A pending request cannot carry signaling.
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    format(
      'insert into public.webrtc_signals (session_id, from_user_id, kind, payload) '
      'values (%L, %L, %L, %L::jsonb)',
      v_pending, v_parent, 'offer', '{"sdp":"too-early"}'
    ),
    '42501', 'row-level security',
    'a requested session must not accept signals before consent'
  );

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_pending;
  perform tests.assert_true(
    v_count = 0,
    'a requested session must not expose signals, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 5. An ended session cannot carry signaling, even with a NULL deadline.
  -- -----------------------------------------------------------------------
  perform tests.expect_error(
    format(
      'insert into public.webrtc_signals (session_id, from_user_id, kind, payload) '
      'values (%L, %L, %L, %L::jsonb)',
      v_ended, v_parent, 'offer', '{"sdp":"after-end"}'
    ),
    '42501', 'row-level security',
    'an ended session must not accept signals'
  );

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_ended;
  perform tests.assert_true(
    v_count = 0,
    'an ended session must not expose signals, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 6. Ending the consented session closes signaling immediately.
  -- -----------------------------------------------------------------------
  reset role;
  update public.remote_sessions
  set status = 'ended', ended_at = now(), ended_by = v_parent,
      ended_reason = 'ended_by_parent'
  where id = v_consented;

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform tests.expect_error(
    format(
      'insert into public.webrtc_signals (session_id, from_user_id, kind, payload) '
      'values (%L, %L, %L, %L::jsonb)',
      v_consented, v_parent, 'ice', '{"candidate":"late"}'
    ),
    '42501', 'row-level security',
    'an ended consented session must stop accepting signals'
  );

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_consented;
  perform tests.assert_true(
    v_count = 0,
    'an ended consented session must hide its signals, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 7. A non-participant can neither read nor write.
  -- -----------------------------------------------------------------------
  reset role;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_outsider::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count
  from public.webrtc_signals where session_id = v_legacy;
  perform tests.assert_true(
    v_count = 0,
    'an outsider must not read another session signals, got ' || v_count
  );

  perform tests.expect_error(
    format(
      'insert into public.webrtc_signals (session_id, from_user_id, kind, payload) '
      'values (%L, %L, %L, %L::jsonb)',
      v_legacy, v_outsider, 'ice', '{"candidate":"outsider"}'
    ),
    '42501', 'row-level security',
    'an outsider must not insert signals into another session'
  );

  reset role;
  raise notice 'ALL CONSENTED-SESSION SIGNALING TESTS PASSED';
end;
$$;
