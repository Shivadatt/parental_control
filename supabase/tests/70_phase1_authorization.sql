-- Phase 1 authorization tests (migration 20261030000200_phase1_authorization.sql).
--
-- Run AFTER 20_fixtures.sql and every migration, in the same `psql -f` chain as
-- the other files (see supabase/tests/README.md). Self-contained: own accounts,
-- family and devices (e3…/f3… UUIDs), so no fixture owned by another test file
-- is mutated. Nothing here is executed in Phase 1 (no CLI, no hosted database);
-- the file is written to be runnable.
--
-- Covers:
--   1. private.is_parent_of_family() semantics and its service-only grant.
--   2. A non-parent actor is rejected (42501 not_family_parent) by
--      request_remote_session, revoke_device, apply_policy_version and
--      unlink_child — and the legitimate callers still work.
--   3. safe_zones has no DELETE policy and no DELETE privilege for clients.
--   4. Purging is gated on the family owner: the same owner_id predicate the
--      Edge Function asserts is the only writable path to family settings. The
--      Edge Function decision itself (canPurge) is covered by
--      supabase/functions/family-admin/authorization_test.ts.
--   5. The two private functions lost their default PUBLIC EXECUTE.
--   6. The webrtc_signals unique index exists when no duplicate sequences exist.
do $$
declare
  v_owner uuid := 'e3000000-0000-4000-8000-0000000000a1';
  v_parent2 uuid := 'e3000000-0000-4000-8000-0000000000a2';
  v_removed_parent uuid := 'e3000000-0000-4000-8000-0000000000a3';
  v_child_a uuid := 'e3000000-0000-4000-8000-0000000000c1';
  v_child_b uuid := 'e3000000-0000-4000-8000-0000000000c2';
  v_outsider uuid := 'e3000000-0000-4000-8000-0000000000b1';
  v_family_a uuid := 'f3000000-0000-4000-8000-000000000001';
  v_family_b uuid := 'f3000000-0000-4000-8000-000000000002';
  v_family_deleted uuid := 'f3000000-0000-4000-8000-000000000003';
  v_device_session uuid := 'e3000000-0000-4000-8000-0000000000d1';
  v_device_revoke uuid := 'e3000000-0000-4000-8000-0000000000d2';
  v_zone uuid := 'e3000000-0000-4000-8000-0000000000f1';
  v_allowed boolean;
  v_count integer;
  v_rows integer;
  v_result jsonb;
  v_session public.remote_sessions;
  v_owner_id uuid;
begin
  -- -----------------------------------------------------------------------
  -- Fixtures: two families, one soft-deleted family, owner + non-owner parent,
  -- a removed parent, two children and two active devices.
  -- -----------------------------------------------------------------------
  insert into auth.users (id, email, email_confirmed_at) values
    (v_owner, 'phase1-owner@example.test', now()),
    (v_parent2, 'phase1-parent2@example.test', now()),
    (v_removed_parent, 'phase1-removed@example.test', now()),
    (v_child_a, 'phase1-child-a@example.test', now()),
    (v_child_b, 'phase1-child-b@example.test', now()),
    (v_outsider, 'phase1-outsider@example.test', now());

  update public.profiles set role = 'parent'
  where id in (v_owner, v_parent2, v_removed_parent, v_outsider);
  update public.profiles set role = 'child' where id in (v_child_a, v_child_b);

  insert into public.families (id, name, owner_id, deleted_at) values
    (v_family_a, 'Phase1 Family A', v_owner, null),
    (v_family_b, 'Phase1 Family B', v_outsider, null),
    (v_family_deleted, 'Phase1 Deleted Family', v_outsider,
      now() - interval '1 day');

  insert into public.family_members (family_id, user_id, role, status) values
    (v_family_a, v_owner, 'parent', 'active'),
    (v_family_a, v_parent2, 'parent', 'active'),
    (v_family_a, v_child_a, 'child', 'active'),
    (v_family_a, v_child_b, 'child', 'active'),
    (v_family_b, v_outsider, 'parent', 'active'),
    (v_family_deleted, v_outsider, 'parent', 'active');

  insert into public.family_members (family_id, user_id, role, status, removed_at)
  values (v_family_a, v_removed_parent, 'parent', 'removed', now() - interval '1 day');

  -- families_one_active_per_owner is unique on owner_id where deleted_at is
  -- null, so the soft-deleted family must be inserted already deleted.

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values
    (v_device_session, v_family_a, v_child_a, 'phase1-session-dev', 'Phase1 Phone A', 'active'),
    (v_device_revoke, v_family_a, v_child_b, 'phase1-revoke-dev', 'Phase1 Phone B', 'active');

  insert into public.safe_zones (id, family_id, name, lat, lng, radius_m)
  values (v_zone, v_family_a, 'Phase1 Zone', 51.5, -0.12, 200);

  -- -----------------------------------------------------------------------
  -- 1. private.is_parent_of_family() semantics
  -- -----------------------------------------------------------------------
  perform tests.assert_true(
    private.is_parent_of_family(v_owner, v_family_a),
    'the owner is an active parent of the family'
  );
  perform tests.assert_true(
    private.is_parent_of_family(v_parent2, v_family_a),
    'a non-owner parent is still an active parent of the family'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_child_a, v_family_a),
    'a child is not a parent of the family'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_removed_parent, v_family_a),
    'a removed parent membership is not an active parent'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_outsider, v_family_a),
    'a parent of another family is not a parent of this family'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_owner, v_family_b),
    'parent membership is scoped to one family'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_outsider, v_family_deleted),
    'a soft-deleted family never authorizes'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(null, v_family_a),
    'a null actor is never a parent'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_owner, null),
    'a null family never authorizes'
  );
  perform tests.assert_true(
    not private.is_parent_of_family(v_owner, gen_random_uuid()),
    'an unknown family never authorizes'
  );

  -- -----------------------------------------------------------------------
  -- 2. The four service RPCs verify the caller-supplied actor id
  -- -----------------------------------------------------------------------
  -- A child and a parent of another family may not open a session. The RPC is
  -- service-only, so these calls run with the function owner's privileges and
  -- prove the actor check itself, not the grant.
  perform tests.expect_error(
    format(
      'select public.request_remote_session(%L::uuid, %L::uuid, %L)',
      v_device_session, v_child_a, 'audio'
    ),
    '42501', 'not_family_parent',
    'a child cannot request a session for itself'
  );
  perform tests.expect_error(
    format(
      'select public.request_remote_session(%L::uuid, %L::uuid, %L)',
      v_device_session, v_outsider, 'audio'
    ),
    '42501', 'not_family_parent',
    'a parent of another family cannot request a session'
  );

  select count(*) into v_count
  from public.remote_sessions where device_id = v_device_session;
  perform tests.assert_true(
    v_count = 0,
    'a rejected request must not create a session row, got ' || v_count
  );

  -- revoke_device / apply_policy_version resolve the family from the device.
  perform tests.expect_error(
    format(
      'select public.revoke_device(%L::uuid, %L::uuid)',
      v_device_session, v_child_a
    ),
    '42501', 'not_family_parent',
    'a child cannot revoke a device'
  );
  perform tests.expect_error(
    format(
      'select public.revoke_device(%L::uuid, %L::uuid)',
      v_device_session, v_outsider
    ),
    '42501', 'not_family_parent',
    'a parent of another family cannot revoke a device'
  );
  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      v_device_session, '{"apps":[]}', v_child_b, 'phase1-forged'
    ),
    '42501', 'not_family_parent',
    'a child cannot apply a policy'
  );
  perform tests.expect_error(
    format(
      'select public.apply_policy_version(%L::uuid, %L::jsonb, %L::uuid, %L)',
      v_device_session, '{"apps":[]}', v_outsider, 'phase1-forged'
    ),
    '42501', 'not_family_parent',
    'a parent of another family cannot apply a policy'
  );

  -- unlink_child takes the family explicitly; a sibling cannot unlink a child.
  perform tests.expect_error(
    format(
      'select public.unlink_child(%L::uuid, %L::uuid, %L::uuid)',
      v_family_a, v_child_a, v_child_b
    ),
    '42501', 'not_family_parent',
    'a sibling cannot unlink a child'
  );
  perform tests.expect_error(
    format(
      'select public.unlink_child(%L::uuid, %L::uuid, %L::uuid)',
      v_family_a, v_child_a, v_outsider
    ),
    '42501', 'not_family_parent',
    'a parent of another family cannot unlink a child'
  );
  perform tests.expect_error(
    format(
      'select public.unlink_child(%L::uuid, %L::uuid, %L)',
      v_family_a, v_child_a, null
    ),
    '42501', 'not_family_parent',
    'a missing actor is rejected'
  );

  -- Control: a removed parent loses the ability to act on family children.
  perform tests.expect_error(
    format(
      'select public.unlink_child(%L::uuid, %L::uuid, %L::uuid)',
      v_family_a, v_child_a, v_removed_parent
    ),
    '42501', 'not_family_parent',
    'a removed parent cannot unlink a child'
  );

  -- Legitimate callers still work: the wrapper did not change the happy path.
  -- request_remote_session returns the row type, not jsonb (unlike the other
  -- service RPCs). Assign it as a composite (`:=`), not via `SELECT INTO`,
  -- which tries to coerce the row to its first column's type.
  v_session := public.request_remote_session(
    v_device_session, v_parent2, 'audio'
  );
  perform tests.assert_true(
    v_session.status = 'requested'
      and v_session.parent_user_id = v_parent2,
    'a non-owner parent of the family can request a session'
  );

  select public.apply_policy_version(
    v_device_session, '{"apps":["com.example.app"]}'::jsonb, v_parent2,
    'phase1-ok'
  ) into v_result;
  perform tests.assert_true(
    (v_result ->> 'idempotent')::boolean is false
      and v_result -> 'policy' -> 'version' is not null,
    'a non-owner parent of the family can apply a policy'
  );

  select public.revoke_device(v_device_revoke, v_parent2) into v_result;
  perform tests.assert_true(
    v_result ->> 'status' = 'revoked',
    'a non-owner parent of the family can revoke a device'
  );

  -- unlink_child: same, last because it removes the child membership.
  select public.unlink_child(v_family_a, v_child_a, v_parent2) into v_result;
  perform tests.assert_true(
    v_result ->> 'status' = 'unlinked',
    'a non-owner parent of the family can unlink a child'
  );

  -- -----------------------------------------------------------------------
  -- 3. safe_zones: no client DELETE
  -- -----------------------------------------------------------------------
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'safe_zones'
    and policyname = 'safe_zones_delete_parent';
  perform tests.assert_true(
    v_count = 0,
    'the safe_zones_delete_parent policy must be gone, got ' || v_count
  );

  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'safe_zones'
    and cmd in ('SELECT', 'INSERT', 'UPDATE', 'ALL');
  perform tests.assert_true(
    v_count = 3,
    'select/insert/update safe_zones policies must remain, got ' || v_count
  );

  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.safe_zones', 'DELETE'),
    'authenticated must not hold table DELETE on safe_zones'
  );
  perform tests.assert_true(
    not has_table_privilege('anon', 'public.safe_zones', 'DELETE'),
    'anon must not hold table DELETE on safe_zones'
  );
  perform tests.assert_true(
    has_table_privilege('authenticated', 'public.safe_zones', 'SELECT'),
    'authenticated keeps SELECT on safe_zones'
  );
  perform tests.assert_true(
    has_any_column_privilege('authenticated', 'public.safe_zones', 'INSERT'),
    'authenticated keeps column INSERT on safe_zones'
  );
  perform tests.assert_true(
    has_any_column_privilege('authenticated', 'public.safe_zones', 'UPDATE'),
    'authenticated keeps column UPDATE on safe_zones'
  );

  -- The actual client DELETE now fails on the privilege, not just on RLS.
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform tests.expect_error(
    format('delete from public.safe_zones where id = %L::uuid', v_zone),
    '42501', 'permission denied',
    'an owner parent can no longer delete a zone directly'
  );
  reset role;

  select count(*) into v_count from public.safe_zones where id = v_zone;
  perform tests.assert_true(
    v_count = 1,
    'the zone must survive the rejected client DELETE, got ' || v_count
  );

  -- -----------------------------------------------------------------------
  -- 4. Purge is owner-only
  -- -----------------------------------------------------------------------
  -- family-admin calls assertFamilyOwner(): active parent + families.owner_id =
  -- caller. The database facts that decision rests on:
  select owner_id into v_owner_id from public.families where id = v_family_a;
  perform tests.assert_true(
    v_owner_id = v_owner and v_owner_id <> v_parent2,
    'the fixture must distinguish owner from non-owner parent'
  );
  perform tests.assert_true(
    private.is_parent_of_family(v_parent2, v_family_a)
      and v_owner_id <> v_parent2,
    'a non-owner parent is a parent but not the owner'
  );

  -- The only way to change what a purge is allowed to delete is the owner-only
  -- UPDATE path on families.settings.
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_parent2::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  update public.families
  set settings = settings || '{"location_retention_days":1}'::jsonb
  where id = v_family_a;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(
    v_rows = 0,
    'a non-owner parent must not be able to change retention settings'
  );
  reset role;

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  update public.families set settings = settings where id = v_family_a;
  get diagnostics v_rows = row_count;
  perform tests.assert_true(
    v_rows = 1,
    'the owner can change retention settings'
  );
  reset role;

  -- -----------------------------------------------------------------------
  -- 5. Function exposure
  -- -----------------------------------------------------------------------
  perform tests.assert_true(
    not has_function_privilege(
      'anon', 'private.remote_session_transition_guard()', 'EXECUTE'
    ),
    'anon must not execute the session transition guard'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated', 'private.remote_session_transition_guard()', 'EXECUTE'
    ),
    'authenticated must not execute the session transition guard'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'anon', 'private.request_device_recovery(uuid, uuid)', 'EXECUTE'
    ),
    'anon must not execute request_device_recovery'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated', 'private.request_device_recovery(uuid, uuid)', 'EXECUTE'
    ),
    'authenticated must not execute request_device_recovery'
  );
  -- The private helper never had an explicit service_role grant (it relied on
  -- PUBLIC). Phase 1 removes PUBLIC by design; service_role's supported entry
  -- point is the public SECURITY DEFINER wrapper, which must stay executable.
  perform tests.assert_true(
    has_function_privilege(
      'service_role', 'public.request_device_recovery(uuid, uuid)', 'EXECUTE'
    ),
    'service_role keeps execute on the public request_device_recovery wrapper'
  );
  perform tests.assert_true(
    not has_function_privilege(
      'authenticated', 'private.is_parent_of_family(uuid, uuid)', 'EXECUTE'
    ),
    'authenticated must not execute the new parent predicate'
  );
  perform tests.assert_true(
    has_function_privilege(
      'service_role', 'private.is_parent_of_family(uuid, uuid)', 'EXECUTE'
    ),
    'service_role keeps execute on the new parent predicate'
  );

  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform tests.expect_error(
    format('select private.is_parent_of_family(%L::uuid, %L::uuid)', v_owner, v_family_a),
    '42501', 'permission denied',
    'a client cannot call the parent predicate directly'
  );
  reset role;

  -- -----------------------------------------------------------------------
  -- 6. webrtc_signals replay index (only when no duplicates exist)
  -- -----------------------------------------------------------------------
  if not exists (
    select 1
    from (
      select session_id, sequence
      from public.webrtc_signals
      group by 1, 2
      having count(*) > 1
    ) d
  ) then
    perform tests.assert_true(
      to_regclass('public.webrtc_signals_session_sequence_uniq') is not null,
      'the (session_id, sequence) unique index must exist when no duplicates exist'
    );
  else
    raise notice 'duplicate signals exist; unique index correctly skipped';
  end if;

  raise notice 'ALL PHASE 1 AUTHORIZATION TESTS PASSED';
end;
$$;