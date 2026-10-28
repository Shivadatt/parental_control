-- BUG-033: atomic pairing-request creation.
--
-- Run AFTER 20_fixtures.sql and migration 20260101000600_atomic_pairing_invite.sql.
-- Self-contained: every row below uses fresh UUIDs and a fresh family, so no
-- fixture owned by another test file is read or mutated. The single-session
-- assertions here cover the read-then-insert contract; the genuine two-session
-- lock proof lives in run_pairing_invite_race.sh.
do $$
declare
  v_parent_a uuid := 'ca000000-0000-4000-8000-00000000000a';
  v_parent_b uuid := 'ca000000-0000-4000-8000-00000000000b';
  v_child_1 uuid := 'ca000000-0000-4000-8000-0000000000c1';
  v_child_2 uuid := 'ca000000-0000-4000-8000-0000000000c2';
  v_child_3 uuid := 'ca000000-0000-4000-8000-0000000000c3';
  v_family_1 uuid := 'fa000000-0000-4000-8000-000000000001';
  v_family_2 uuid := 'fa000000-0000-4000-8000-000000000002';
  v_expired_token uuid := 'ea000000-0000-4000-8000-000000000001';
  v_expired_request uuid := 'ea000000-0000-4000-8000-000000000002';
  v_code_token uuid := 'ea000000-0000-4000-8000-000000000003';
  v_hash_1 text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_hash_2 text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_hash_3 text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_hash_4 text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_hash_code text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_invite jsonb;
  v_repeat jsonb;
  v_expired_case jsonb;
  v_other_parent jsonb;
  v_code_1 jsonb;
  v_code_2 jsonb;
  v_invite_id uuid;
  v_repeat_id uuid;
  v_expired_id uuid;
  v_other_parent_id uuid;
  v_code_id uuid;
  v_count integer;
  v_purpose text;
  v_status text;
  v_created_by uuid;
  v_token_expires timestamptz;
  v_request_expires timestamptz;
  v_expires_at timestamptz := now() + interval '10 minutes';
begin
  -- -----------------------------------------------------------------------
  -- Own accounts: auth.users first so private.handle_new_user makes profiles.
  -- -----------------------------------------------------------------------
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent_a, 'atomic-parent-a@example.test', now()),
    (v_parent_b, 'atomic-parent-b@example.test', now()),
    (v_child_1, 'atomic-child-1@example.test', now()),
    (v_child_2, 'atomic-child-2@example.test', now()),
    (v_child_3, 'atomic-child-3@example.test', now());

  perform tests.assert_true(
    (select count(*) from public.profiles
      where id in (v_parent_a, v_parent_b, v_child_1, v_child_2, v_child_3)) = 5,
    'auth.users trigger must create five atomic-test profiles'
  );

  update public.profiles set role = 'parent'
  where id in (v_parent_a, v_parent_b);
  update public.profiles set role = 'child'
  where id in (v_child_1, v_child_2, v_child_3);

  insert into public.families (id, name, owner_id) values
    (v_family_1, 'Atomic Family One', v_parent_a),
    (v_family_2, 'Atomic Family Two', v_parent_b);

  -- -----------------------------------------------------------------------
  -- 1. Same triple twice: one live request, the second call reports the first.
  -- -----------------------------------------------------------------------
  v_invite := public.create_pairing_invite(
    v_child_1, v_family_1, v_parent_a, v_hash_1, v_expires_at
  );
  perform tests.assert_true(
    (v_invite ->> 'created')::boolean is true,
    'first invite for a triple must be created'
  );
  v_invite_id := (v_invite -> 'request' ->> 'id')::uuid;

  v_repeat := public.create_pairing_invite(
    v_child_1, v_family_1, v_parent_a, v_hash_2, v_expires_at
  );
  perform tests.assert_true(
    (v_repeat ->> 'created')::boolean is false,
    'second invite for a live triple must not create a row'
  );
  v_repeat_id := (v_repeat -> 'request' ->> 'id')::uuid;
  perform tests.assert_true(
    v_repeat_id = v_invite_id,
    'the repeat invite must return the existing request id'
  );

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child_1
    and family_id = v_family_1
    and parent_user_id = v_parent_a
    and status = 'pending_child'
    and expires_at > now();
  perform tests.assert_true(
    v_count = 1,
    'exactly one live request must exist for the triple, got ' || v_count
  );

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child_1
    and family_id = v_family_1
    and parent_user_id = v_parent_a;
  perform tests.assert_true(
    v_count = 1,
    'the suppressed call must not leave a second request row, got ' || v_count
  );

  select count(*) into v_count
  from public.device_pairing_tokens
  where code_hash = v_hash_2;
  perform tests.assert_true(
    v_count = 0,
    'a suppressed invite must not mint an orphan token'
  );

  -- -----------------------------------------------------------------------
  -- 2. BUG-033 regression: an expired pending_child row (still status
  --    'pending_child' until the child polls) must not block a fresh invite.
  --    A partial unique index would have rejected this insert.
  -- -----------------------------------------------------------------------
  insert into public.device_pairing_tokens (
    id, child_user_id, code_hash, expires_at, status, created_by
  ) values (
    v_expired_token, v_child_2,
    replace(gen_random_uuid()::text, '-', '')
      || replace(gen_random_uuid()::text, '-', ''),
    now() - interval '1 hour', 'active', v_parent_a
  );
  insert into public.pairing_requests (
    id, token_id, family_id, parent_user_id, child_user_id, status, expires_at
  ) values (
    v_expired_request, v_expired_token, v_family_1, v_parent_a, v_child_2,
    'pending_child', now() - interval '1 hour'
  );

  v_expired_case := public.create_pairing_invite(
    v_child_2, v_family_1, v_parent_a, v_hash_3, v_expires_at
  );
  perform tests.assert_true(
    (v_expired_case ->> 'created')::boolean is true,
    'an expired pending_child row must not suppress a new invite'
  );
  v_expired_id := (v_expired_case -> 'request' ->> 'id')::uuid;
  perform tests.assert_true(
    v_expired_id <> v_expired_request,
    'the fresh invite must be a new request, not the expired one'
  );

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child_2
    and family_id = v_family_1
    and parent_user_id = v_parent_a
    and status = 'pending_child'
    and expires_at > now();
  perform tests.assert_true(
    v_count = 1,
    'one live request must exist beside the expired one, got ' || v_count
  );

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child_2
    and family_id = v_family_1
    and parent_user_id = v_parent_a
    and status = 'pending_child';
  perform tests.assert_true(
    v_count = 2,
    'the expired row must survive the fresh invite, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 3. The lock key includes the parent: another parent gets their own row.
  -- -----------------------------------------------------------------------
  v_other_parent := public.create_pairing_invite(
    v_child_1, v_family_1, v_parent_b, v_hash_4, v_expires_at
  );
  perform tests.assert_true(
    (v_other_parent ->> 'created')::boolean is true,
    'a different parent must get their own request'
  );
  v_other_parent_id := (v_other_parent -> 'request' ->> 'id')::uuid;
  perform tests.assert_true(
    v_other_parent_id <> v_invite_id,
    'a different parent must not receive the first parent''s request'
  );
  perform tests.assert_true(
    (v_other_parent -> 'request' ->> 'parent_user_id')::uuid = v_parent_b,
    'the second request must belong to the second parent'
  );

  select count(*) into v_count
  from public.pairing_requests
  where child_user_id = v_child_1
    and family_id = v_family_1
    and parent_user_id = v_parent_b
    and status = 'pending_child'
    and expires_at > now();
  perform tests.assert_true(
    v_count = 1,
    'exactly one live request must exist for the second parent, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 4. Legacy code path: the token already exists; only the request is
  --    inserted. A token replay for another triple is code_unavailable.
  -- -----------------------------------------------------------------------
  insert into public.device_pairing_tokens (
    id, child_user_id, code_hash, expires_at, status, created_by
  ) values (
    v_code_token, v_child_3, v_hash_code, v_expires_at, 'active', v_child_3
  );

  v_code_1 := public.create_pairing_request(
    v_child_3, v_family_1, v_parent_a, v_code_token, v_expires_at
  );
  perform tests.assert_true(
    (v_code_1 ->> 'created')::boolean is true,
    'first redemption of a code token must create a request'
  );
  v_code_id := (v_code_1 -> 'request' ->> 'id')::uuid;

  v_code_2 := public.create_pairing_request(
    v_child_3, v_family_1, v_parent_a, v_code_token, v_expires_at
  );
  perform tests.assert_true(
    (v_code_2 ->> 'created')::boolean is false,
    'redeeming the same code twice for one triple must reuse the request'
  );
  perform tests.assert_true(
    (v_code_2 -> 'request' ->> 'id')::uuid = v_code_id,
    'the second redemption must return the first request id'
  );

  select count(*) into v_count
  from public.pairing_requests
  where token_id = v_code_token;
  perform tests.assert_true(
    v_count = 1,
    'one code token must map to exactly one request, got ' || v_count
  );

  perform tests.expect_error(
    format(
      'select public.create_pairing_request(%L::uuid, %L::uuid, %L::uuid, %L::uuid, %L::timestamptz)',
      v_child_3, v_family_2, v_parent_a, v_code_token, v_expires_at
    ),
    'P0001', 'code_unavailable',
    'replaying a code token for another triple must raise code_unavailable'
  );

  select count(*) into v_count
  from public.pairing_requests
  where token_id = v_code_token;
  perform tests.assert_true(
    v_count = 1,
    'the replay must not create a second row for the code token, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 5. The invite token is the internal one the RPC minted.
  -- -----------------------------------------------------------------------
  select t.purpose, t.status, t.created_by, t.expires_at, pr.expires_at
  into v_purpose, v_status, v_created_by, v_token_expires, v_request_expires
  from public.pairing_requests pr
  join public.device_pairing_tokens t on t.id = pr.token_id
  where pr.id = v_invite_id;

  perform tests.assert_true(
    v_purpose = 'invite',
    'the invite request must use an invite-purpose token, got ' || coalesce(v_purpose, '<none>')
  );
  perform tests.assert_true(
    v_status = 'active',
    'the invite token must be active, got ' || coalesce(v_status, '<none>')
  );
  perform tests.assert_true(
    v_created_by = v_parent_a,
    'the invite token must be created by the inviting parent'
  );
  perform tests.assert_true(
    v_token_expires = v_request_expires,
    'the invite token and the request must share expires_at'
  );
end;
$$;
