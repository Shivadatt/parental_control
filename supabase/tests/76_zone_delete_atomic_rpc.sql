-- SQL-05 — atomic audited safe-zone delete (migration
-- 20261103000100_zone_delete_atomic_rpc.sql, public.delete_safe_zone_audited).
--
-- WHAT THIS FILE PROVES. The Phase 1..4 gap SQL-05 was: `family-admin`
-- `delete_zone` committed the `safe_zones` DELETE in one PostgREST transaction
-- and appended the `zone_deleted` `audit_logs` row in a SECOND, independent
-- one, so a failing audit insert left a committed deletion with no ledger entry
-- and a retry 404'd, making the ledger unrepairable through the API. The RPC
-- under test does resolve + authorize + delete + audit in ONE function body.
-- Section 2 is the test that matters most: with the audit INSERT made to fail,
-- the zone MUST survive and MUST NOT be audited.
--
-- Run position: AFTER 75_signaling_replay_index_duplicate_guard.sql and BEFORE
-- 45_device_recovery.sql, in the documented `psql -f` chain
-- (supabase/tests/README.md). It must come before 45 because it temporarily
-- installs a failing BEFORE INSERT trigger on public.audit_logs and drops it
-- again at the end of section 2 — 45_device_recovery.sql writes real audit rows
-- and must not run against that trigger. Self-contained: its own accounts,
-- families, device, zones and state rows (a8../b8../c8../d8../e8../f8../g8..
-- UUIDs); it never mutates a row owned by another test file (the single
-- `safe_zones` row from 20_fixtures.sql is left untouched, which is why every
-- count here is scoped to this file's own zone ids).
--
-- HONEST SCOPE LIMITS (do not over-read this file):
--   1. The chain runs as the database superuser (postgres), which bypasses RLS
--      and holds every table privilege. Therefore the grant assertions use
--      has_function_privilege() (the mechanism 63/74 already use) rather than
--      "run as anon and see it fail", and audit append-only refusal is NOT
--      re-probed here for the same reason documented in
--      74_sweep_indexes_and_repeatability.sql:431-434.
--   2. The audit-failure abort is observed at PostgreSQL's statement /
--      subtransaction rollback granularity, because tests.expect_error() catches
--      the raised error in a subtransaction (00_auth_stub.sql:76-105) - the only
--      way to survive an expected error under ON_ERROR_STOP=1 without printing an
--      ERROR line. A failed RPC call discards every effect it produced either
--      way, which is exactly the property under test: the delete is not
--      committed. Multi-backend interleavings (a real concurrent deleter) are
--      still only covered by the two-session race scripts, not here; the row-lock
--      behaviour is asserted structurally in section 5.
--   3. No hosted Supabase behaviour is verified. This file has only ever run
--      against a disposable local PostgreSQL 16.9 cluster.
--
-- Every negative-control-relevant assertion is a plain equality check, so any
-- regression makes psql exit non-zero with ASSERTION FAILED.

-- ===========================================================================
-- 0. Contract: service-role-only SECURITY DEFINER function, pinned search_path,
--    and NO client-settable identity source.
-- ===========================================================================
do $$
declare
  v_sig text := 'public.delete_safe_zone_audited(uuid, uuid)';
  v_prosrc text;
  v_flag boolean;
begin
  perform tests.assert_true(
    to_regprocedure(v_sig) is not null,
    'SQL-05: public.delete_safe_zone_audited(uuid, uuid) must exist after '
    || '20261103000100'
  );

  select p.prosecdef
    and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
    and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
    and p.pronargs = 2
    and p.proargtypes[0] = 'uuid'::regtype
    and p.proargtypes[1] = 'uuid'::regtype
    and p.prorettype = (select oid from pg_type where typname = 'jsonb')
    into v_flag
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited';
  perform tests.assert_true(
    coalesce(v_flag, false),
    'SQL-05: must be a plpgsql SECURITY DEFINER function (uuid, uuid) returns '
    || 'jsonb with a pinned search_path'
  );

  -- The exact pinning matters: an unfixed search_path lets a caller with CREATE
  -- rights in a lower schema shadow public.safe_zones / private.is_parent_of_family.
  select string_agg(cfg, ',' order by cfg) into v_prosrc
  from unnest(
    (select proconfig from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited')
  ) as cfg;
  perform tests.assert_true(
    v_prosrc = 'search_path=public, private, pg_temp',
    'SQL-05: search_path must be exactly "public, private, pg_temp" (the '
    || 'expire_abandoned_sessions convention), got: ' || coalesce(v_prosrc, '<null>')
  );

  -- Grants: service_role only. Mirrors 20261030000100:158-161.
  perform tests.assert_true(
    has_function_privilege('service_role', v_sig, 'execute'),
    'SQL-05: service_role must be able to execute the RPC'
  );
  perform tests.assert_true(
    not has_function_privilege('anon', v_sig, 'execute'),
    'SQL-05: anon must not execute the RPC'
  );
  perform tests.assert_true(
    not has_function_privilege('authenticated', v_sig, 'execute'),
    'SQL-05: authenticated must not execute the RPC (api-contract.md §7 forbids '
    || 'a new client-callable surface)'
  );
  -- PUBLIC must hold nothing at all, so no role reaches it by membership. A
  -- proacl entry for PUBLIC has an EMPTY grantee, i.e. starts with '='. (The
  -- service_role grant itself legitimately prints `service_role=X/postgres`, so
  -- the pin is per-entry, not "no =X/ anywhere".)
  perform tests.assert_true(
    (
      select count(*)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral unnest(p.proacl) as a
      where n.nspname = 'public'
        and p.proname = 'delete_safe_zone_audited'
        and a::text like '=%'
    ) = 0,
    'SQL-05: no PUBLIC execute entry may exist on the RPC'
  );

  -- TRUSTED ATTRIBUTION (the hole 20261030000200 closed for revoke_device):
  -- the actor id must come from the parameter only. Reading the client-settable
  -- request.jwt.claim.sub GUC anywhere in the body is a forged-actor regression.
  select prosrc into v_prosrc
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited';
  perform tests.assert_true(
    v_prosrc not like '%request.jwt.claim.sub%'
      and v_prosrc not like '%auth.uid()%'
      and v_prosrc not like '%current_user%',
    'SQL-05: the body must not read request.jwt.claim.sub / auth.uid() / '
    || 'current_user for actor attribution - p_actor_user_id is the only actor source'
  );
  perform tests.assert_true(
    v_prosrc like '%p_actor_user_id%'
      and v_prosrc like '%private.is_parent_of_family%'
      and v_prosrc like '%not_family_parent%'
      and v_prosrc like '%42501%',
    'SQL-05: authorization must go through private.is_parent_of_family() and '
    || 'raise not_family_parent (42501), the Phase 1 vocabulary'
  );

  -- Zero-row invariant, structurally: the audit insert must come AFTER the
  -- row_count guard, so no path can audit a delete that deleted nothing.
  perform tests.assert_true(
    position('record_audit' in v_prosrc) > position('v_deleted = 0' in v_prosrc)
      and position('v_deleted = 0' in v_prosrc) > 0,
    'SQL-05: the audit insert must be guarded behind the zero-row check (a '
    || 'zero-row delete is never audited)'
  );
  perform tests.assert_true(
    (length(v_prosrc) - length(replace(v_prosrc, 'record_audit', '')))
      / length('record_audit') = 1,
    'SQL-05: exactly one audit insert site, so no branch can double-record'
  );
  -- One delete site only: a second DELETE would reopen the unaudited path.
  perform tests.assert_true(
    (length(v_prosrc) - length(replace(v_prosrc, 'delete from public.safe_zones', '')))
      / length('delete from public.safe_zones') = 1,
    'SQL-05: exactly one safe_zones DELETE site in the body'
  );
  -- No COMMIT inside: one call must stay one transaction (same tripwire 74 uses
  -- for run_retention_sweep at :408-417). The check is on the statement forms,
  -- not a bare 'commit' substring: prosrc keeps the function's own comments, and
  -- the body comment about a concurrent deleter says "once it has committed".
  perform tests.assert_true(
    v_prosrc not like '%commit;%'
      and v_prosrc not like '%commit work%'
      and v_prosrc not like '%;commit%'
      and v_prosrc not like '%perform transaction%',
    'SQL-05: the body must not COMMIT - if it did, delete and audit would be '
    || 'separate transactions again and SQL-05 would be back'
  );
end;
$$;

-- ===========================================================================
-- 1. Fixtures + success: zone gone, exactly one correctly attributed audit row,
--    cascade latches wiped, return shape as the handler expects.
-- ===========================================================================
do $$
declare
  v_owner  uuid := 'a8000000-0000-4000-8000-0000000000a1';
  v_parent uuid := 'a8000000-0000-4000-8000-0000000000a2';
  v_child  uuid := 'b8000000-0000-4000-8000-0000000000c1';
  v_outsider uuid := 'b8000000-0000-4000-8000-0000000000b1';
  v_xparent  uuid := 'b8000000-0000-4000-8000-0000000000b2';
  v_removed  uuid := 'b8000000-0000-4000-8000-0000000000b3';
  v_fam   uuid := 'c8000000-0000-4000-8000-000000000001';
  v_fam_x uuid := 'c8000000-0000-4000-8000-000000000002';
  v_fam_del uuid := 'c8000000-0000-4000-8000-000000000003';
  v_dev   uuid := 'd8000000-0000-4000-8000-000000000001';
  v_z1 uuid := 'e8000000-0000-4000-8000-000000000001';
  v_z2 uuid := 'e8000000-0000-4000-8000-000000000002';
  v_z3 uuid := 'e8000000-0000-4000-8000-000000000003';
  v_z4 uuid := 'e8000000-0000-4000-8000-000000000004';
  v_z5 uuid := 'e8000000-0000-4000-8000-000000000005';
  v_res jsonb;
  v_actor uuid;
  v_audit integer;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_owner, 'sql05-owner@example.test', now()),
    (v_parent, 'sql05-parent@example.test', now()),
    (v_child, 'sql05-child@example.test', now()),
    (v_outsider, 'sql05-outsider@example.test', now()),
    (v_xparent, 'sql05-xparent@example.test', now()),
    (v_removed, 'sql05-removed@example.test', now());
  update public.profiles set role = 'parent'
    where id in (v_owner, v_parent, v_outsider, v_xparent, v_removed);
  update public.profiles set role = 'child' where id = v_child;

  -- families_one_active_per_owner: one live family per owner, so each live
  -- family needs a distinct owner. v_fam_del is soft-deleted, so its owner does
  -- not collide.
  insert into public.families (id, name, owner_id, deleted_at) values
    (v_fam, 'SQL05 Family', v_owner, null),
    (v_fam_x, 'SQL05 Other Family', v_xparent, null),
    (v_fam_del, 'SQL05 Deleted Family', v_outsider, now() - interval '1 day');

  insert into public.family_members (family_id, user_id, role, status) values
    (v_fam, v_owner, 'parent', 'active'),
    (v_fam, v_parent, 'parent', 'active'),
    (v_fam, v_child, 'child', 'active'),
    (v_fam_x, v_xparent, 'parent', 'active'),
    (v_fam_del, v_outsider, 'parent', 'active');
  insert into public.family_members (family_id, user_id, role, status, removed_at)
    values (v_fam, v_removed, 'parent', 'removed', now() - interval '1 day');

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values (v_dev, v_fam, v_child, 'sql05-device', 'SQL05 Phone', 'active');

  insert into public.safe_zones (
    id, family_id, name, lat, lng, radius_m, active, created_by
  ) values
    (v_z1, v_fam, 'SQL05 Library', 51.5, -0.12, 200, true, v_parent),
    (v_z2, v_fam, 'SQL05 Home',    51.6, -0.13, 150, true, v_parent),
    (v_z3, v_fam, 'SQL05 Park',    51.7, -0.14, 300, true, v_parent),
    (v_z5, v_fam, 'SQL05 Gym',     51.8, -0.15, 120, true, v_parent),
    (v_z4, v_fam_del, 'SQL05 Ghost', 40.0, -75.0, 100, true, null);

  -- The cascade latch the restore path could never rebuild (the documented
  -- residual risk in delete_zone_atomicity.ts:38-41).
  insert into public.safe_zone_states (zone_id, device_id, inside, updated_at)
    values (v_z1, v_dev, true, now() - interval '1 hour');

  -- Stash the fixture ids for the later sections (tests.put/tests.get, the
  -- harness helper from 00_auth_stub.sql).
  perform tests.put('sql05_owner',   v_owner::text);
  perform tests.put('sql05_parent',  v_parent::text);
  perform tests.put('sql05_child',   v_child::text);
  perform tests.put('sql05_outsider', v_outsider::text);
  perform tests.put('sql05_xparent', v_xparent::text);
  perform tests.put('sql05_removed', v_removed::text);
  perform tests.put('sql05_fam',     v_fam::text);
  perform tests.put('sql05_fam_x',   v_fam_x::text);
  perform tests.put('sql05_fam_del', v_fam_del::text);
  perform tests.put('sql05_dev',     v_dev::text);
  perform tests.put('sql05_z2',      v_z2::text);
  perform tests.put('sql05_z3',      v_z3::text);
  perform tests.put('sql05_z4',      v_z4::text);
  perform tests.put('sql05_z5',      v_z5::text);

  -- -------------------------------------------------------------------------
  -- 1a. Success: an active parent deletes its own zone.
  -- -------------------------------------------------------------------------
  v_res := public.delete_safe_zone_audited(v_z1, v_parent);

  perform tests.assert_true(
    v_res ->> 'status' = 'deleted',
    'SQL-05: a real delete must report status deleted, got ' || v_res::text
  );
  perform tests.assert_true(
    (v_res ->> 'audited')::boolean
      and (v_res ->> 'zone_id')::uuid = v_z1
      and (v_res ->> 'family_id')::uuid = v_fam,
    'SQL-05: the return shape must carry audited/zone_id/family_id for the '
    || 'handler, got ' || v_res::text
  );
  perform tests.assert_true(
    (v_res ->> 'audit_id') is not null,
    'SQL-05: the audit row id must be returned, got ' || v_res::text
  );

  perform tests.assert_true(
    not exists (select 1 from public.safe_zones where id = v_z1),
    'SQL-05: the zone row must be gone'
  );
  -- Cascade semantics unchanged (core.sql:287): the latch goes with the zone.
  perform tests.assert_true(
    not exists (select 1 from public.safe_zone_states where zone_id = v_z1),
    'SQL-05: safe_zone_states latches must still cascade-delete'
  );

  select count(*) into v_audit
  from public.audit_logs
  where event_type = 'zone_deleted' and target_id = v_z1::text;
  perform tests.assert_true(
    v_audit = 1,
    'SQL-05: exactly one zone_deleted audit row per real delete, got ' || v_audit
  );
end;
$$;

-- 1b. The audit row's own fields, asserted column-by-column.
do $$
declare
  v_parent uuid := tests.get('sql05_parent')::uuid;
  v_fam    uuid := tests.get('sql05_fam')::uuid;
  v_z1     uuid := 'e8000000-0000-4000-8000-000000000001';
  v_row record;
begin
  select * into v_row
  from public.audit_logs
  where event_type = 'zone_deleted' and target_id = v_z1::text;

  perform tests.assert_true(
    v_row.id is not null,
    'SQL-05: the success delete must have left a zone_deleted row'
  );
  perform tests.assert_true(
    v_row.actor_user_id = v_parent,
    'SQL-05: audit actor_user_id must be the p_actor_user_id passed by the '
    || 'handler, got ' || coalesce(v_row.actor_user_id::text, '<null>')
  );
  perform tests.assert_true(
    v_row.family_id = v_fam,
    'SQL-05: audit family_id must be the zone''s family, got '
    || coalesce(v_row.family_id::text, '<null>')
  );
  perform tests.assert_true(
    v_row.device_id is null,
    'SQL-05: a zone delete has no device actor; device_id must stay NULL'
  );
  perform tests.assert_true(
    v_row.target_type = 'safe_zone',
    'SQL-05: target_type must stay safe_zone, got ' || coalesce(v_row.target_type, '<null>')
  );
  perform tests.assert_true(
    v_row.target_id = v_z1::text,
    'SQL-05: target_id must be the zone id as text, got ' || coalesce(v_row.target_id, '<null>')
  );
  -- The ledger shape is a contract: buildZoneAuditInsert() and
  -- _shared/audit.ts recordAudit() both produced metadata = {"name": <zone name>}.
  perform tests.assert_true(
    v_row.metadata = jsonb_build_object('name', 'SQL05 Library'),
    'SQL-05: metadata must be exactly {"name": <zone name>}, got ' || v_row.metadata::text
  );
  perform tests.assert_true(
    v_row.created_at is not null,
    'SQL-05: the audit row must be timestamped'
  );
end;
$$;

-- ===========================================================================
-- 2. THE ATOMICITY TEST (the reason SQL-05 exists): make the audit INSERT fail
--    and prove the delete does not survive it.
-- ===========================================================================
create or replace function tests.sql05_audit_boom()
returns trigger
language plpgsql
as $$
begin
  raise exception 'injected_audit_failure' using errcode = 'P0001';
end;
$$;

create trigger sql05_audit_boom
  before insert on public.audit_logs
  for each row execute function tests.sql05_audit_boom();

do $$
declare
  v_parent uuid := tests.get('sql05_parent')::uuid;
  v_z2     uuid := tests.get('sql05_z2')::uuid;
begin
  -- Call the RPC with the audit insert poisoned: the injected error must
  -- propagate out of the function (NOT be swallowed), because swallowing it is
  -- what made the old two-transaction path lossy.
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z2, v_parent),
    'P0001', 'injected_audit_failure',
    'SQL-05: the audit failure must abort the whole RPC'
  );

  -- THE INVARIANT: no unaudited deletion.
  perform tests.assert_true(
    exists (select 1 from public.safe_zones where id = v_z2),
    'SQL-05: after a failed audit insert the zone MUST still exist '
    || '(an unaudited committed delete is the SQL-05 defect)'
  );
  perform tests.assert_true(
    not exists (
      select 1 from public.audit_logs
      where event_type = 'zone_deleted' and target_id = v_z2::text
    ),
    'SQL-05: a rolled-back delete must leave no zone_deleted row'
  );
  -- The cascade must roll back too, otherwise the latch history is destroyed by
  -- a delete that did not happen.
  perform tests.assert_true(
    not exists (select 1 from public.safe_zone_states where zone_id = v_z2),
    'SQL-05: precondition - z2 has no latch row yet (section 2b adds one)'
  );
end;
$$;

do $$
declare
  v_parent uuid := tests.get('sql05_parent')::uuid;
  v_dev    uuid := tests.get('sql05_dev')::uuid;
  v_z2     uuid := tests.get('sql05_z2')::uuid;
begin
  -- 2b. With a latch row present, repeat the poisoned call and check the latch
  --     survives as well (the old compensating restore could not rebuild it).
  insert into public.safe_zone_states (zone_id, device_id, inside, updated_at)
    values (v_z2, v_dev, false, now() - interval '2 hours');

  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z2, v_parent),
    'P0001', 'injected_audit_failure',
    'SQL-05: the poisoned audit insert must fail the RPC again'
  );
  perform tests.assert_true(
    exists (select 1 from public.safe_zone_states
            where zone_id = v_z2 and device_id = v_dev and inside = false),
    'SQL-05: the cascade-deleted latch must roll back with the zone '
    || '(delete_zone_atomicity.ts:38-41 lists this as an unrecoverable residual)'
  );
end;
$$;

drop trigger sql05_audit_boom on public.audit_logs;
drop function tests.sql05_audit_boom();

do $$
declare
  v_parent uuid := tests.get('sql05_parent')::uuid;
  v_z2     uuid := tests.get('sql05_z2')::uuid;
  v_res jsonb;
begin
  -- 2c. The repair the old path could not offer: once the audit insert works
  --     again, the SAME call succeeds on a plain retry, and the zone is
  --     deleted exactly once with exactly one audit row.
  v_res := public.delete_safe_zone_audited(v_z2, v_parent);
  perform tests.assert_true(
    v_res ->> 'status' = 'deleted',
    'SQL-05: after the audit path recovers, a retry must succeed, got ' || v_res::text
  );
  perform tests.assert_true(
    not exists (select 1 from public.safe_zones where id = v_z2),
    'SQL-05: the retried delete must remove the zone'
  );
  perform tests.assert_true(
    not exists (select 1 from public.safe_zone_states where zone_id = v_z2),
    'SQL-05: the successful delete must cascade the latch'
  );
  perform tests.assert_true(
    (select count(*) from public.audit_logs
      where event_type = 'zone_deleted' and target_id = v_z2::text) = 1,
    'SQL-05: exactly one audit row after fail-then-succeed, got '
    || (select count(*) from public.audit_logs
        where event_type = 'zone_deleted' and target_id = v_z2::text)
  );
end;
$$;

-- ===========================================================================
-- 3. Authorization: every refusal leaves the zone and writes no audit row.
-- ===========================================================================
do $$
declare
  v_owner    uuid := tests.get('sql05_owner')::uuid;
  v_child    uuid := tests.get('sql05_child')::uuid;
  v_outsider uuid := tests.get('sql05_outsider')::uuid;
  v_xparent  uuid := tests.get('sql05_xparent')::uuid;
  v_removed  uuid := tests.get('sql05_removed')::uuid;
  v_fam_del  uuid := tests.get('sql05_fam_del')::uuid;
  v_z3       uuid := tests.get('sql05_z3')::uuid;
  v_z4       uuid := tests.get('sql05_z4')::uuid;
  v_res      jsonb;
  v_audit_before integer;
  v_audit_after integer;
begin
  select count(*) into v_audit_before from public.audit_logs;

  -- 3a. A child, a parent of ANOTHER family and a removed member are all
  -- refused with the Phase 1 vocabulary. Each call runs in the subtransaction
  -- tests.expect_error() opens, so the whole call is discarded.
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z3, v_child),
    '42501', 'not_family_parent',
    'SQL-05: a child must be refused with not_family_parent (42501)'
  );
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z3, v_xparent),
    '42501', 'not_family_parent',
    'SQL-05: cross-family parent must be refused with not_family_parent (42501)'
  );
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z3, v_removed),
    '42501', 'not_family_parent',
    'SQL-05: a membership with status=removed must be refused (is_parent_of_family '
    || 'requires status=active)'
  );

  -- 3b. The zone survives every refusal and nothing was ledgered for it.
  perform tests.assert_true(
    exists (select 1 from public.safe_zones where id = v_z3),
    'SQL-05: a refused delete must leave the zone in place'
  );
  perform tests.assert_true(
    not exists (select 1 from public.audit_logs
                where event_type = 'zone_deleted' and target_id = v_z3::text),
    'SQL-05: a refused delete must write no audit row'
  );

  -- 3c. Family gate first: v_z4 belongs to the SOFT-DELETED family, whose own
  -- active parent is a member of it. The loadFamily() mirror must answer
  -- family_unavailable, not not_family_parent, so the Edge Function keeps its
  -- today's-403 wording for a deleted family.
  perform tests.assert_true(
    (select deleted_at is not null from public.families where id = v_fam_del),
    'SQL-05: precondition - sql05_fam_del must be soft-deleted'
  );
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z4, v_outsider),
    '42501', 'family_unavailable',
    'SQL-05: a zone in a soft-deleted family must answer family_unavailable (42501)'
  );
  perform tests.assert_true(
    exists (select 1 from public.safe_zones where id = v_z4),
    'SQL-05: the family gate must leave the zone in place'
  );

  -- 3d. NULL actor: never attribute an action to nobody, and never reach the
  -- resolve/authorize path at all.
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, null)', v_z3),
    '42501', 'not_family_parent',
    'SQL-05: a NULL p_actor_user_id must be refused before any row is touched'
  );

  -- 3e. Ledger unchanged by all of the above: refusals are not "silent writes".
  select count(*) into v_audit_after from public.audit_logs;
  perform tests.assert_true(
    v_audit_after = v_audit_before,
    'SQL-05: every refusal must leave the audit table byte-for-byte as it was, '
    || 'got ' || v_audit_before || ' -> ' || v_audit_after
  );

  -- 3f. Positive control: the gate is not blanket-deny. The family OWNER (an
  -- active parent member) deletes v_z3 successfully, and the ledger attributes
  -- the row to THAT actor, not to the zone's created_by.
  v_res := public.delete_safe_zone_audited(v_z3, v_owner);
  perform tests.assert_true(
    v_res ->> 'status' = 'deleted',
    'SQL-05: an active parent (the owner) must be able to delete, got ' || v_res::text
  );
  perform tests.assert_true(
    (select actor_user_id from public.audit_logs
      where event_type = 'zone_deleted' and target_id = v_z3::text) = v_owner,
    'SQL-05: the audit actor must be the p_actor_user_id the caller passed'
  );
end;
$$;

-- ===========================================================================
-- 4. Absent and zero-row deletes: nothing is ledgered, and a retry after a
--    successful delete cannot produce a second audit row.
-- ===========================================================================
do $$
declare
  v_parent   uuid := tests.get('sql05_parent')::uuid;
  v_z5       uuid := tests.get('sql05_z5')::uuid;
  v_missing  uuid := 'e8000000-0000-4000-8000-000000000099';
  v_res      jsonb;
  v_audit    integer;
begin
  -- 4a. An unknown zone id is "no such zone" (P0001), never a silent success.
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_missing, v_parent),
    'P0001', 'zone_not_found',
    'SQL-05: an unknown zone id must raise zone_not_found (P0001)'
  );

  -- 4b. A NULL zone id is the same answer (the handler rejects non-UUIDs, so
  -- only a missing body field reaches this).
  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(null, %L::uuid)', v_parent),
    'P0001', 'zone_not_found',
    'SQL-05: a NULL zone id must raise zone_not_found (P0001)'
  );

  perform tests.assert_true(
    not exists (select 1 from public.audit_logs
                where event_type = 'zone_deleted' and target_id = v_missing::text),
    'SQL-05: an absent zone must never be audited as deleted'
  );

  -- 4c. Success, then the REPLAY that the old two-transaction path 404'd on
  -- while the ledger said the zone was already gone.
  v_res := public.delete_safe_zone_audited(v_z5, v_parent);
  perform tests.assert_true(
    v_res ->> 'status' = 'deleted',
    'SQL-05: the first delete must report deleted, got ' || v_res::text
  );

  perform tests.expect_error(
    format('select public.delete_safe_zone_audited(%L::uuid, %L::uuid)', v_z5, v_parent),
    'P0001', 'zone_not_found',
    'SQL-05: replaying a completed delete must raise zone_not_found'
  );

  select count(*) into v_audit from public.audit_logs
    where event_type = 'zone_deleted' and target_id = v_z5::text;
  perform tests.assert_true(
    v_audit = 1,
    'SQL-05: a replay must not add a second zone_deleted row, got ' || v_audit
  );
end;
$$;

-- 4d. The zero-row exit is structurally pinned (it stays unreachable while the
--     row lock is held, exactly as the migration comment says).
do $$
declare
  v_prosrc text;
begin
  select prosrc into v_prosrc
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited';

  perform tests.assert_true(
    v_prosrc like '%already_gone%'
      and v_prosrc like '%''audited'', false%',
    'SQL-05: the zero-row path must answer already_gone with audited=false'
  );
  -- Ordering is the guarantee: already_gone returns BEFORE the audit site.
  perform tests.assert_true(
    position('already_gone' in v_prosrc) > position('v_deleted = 0' in v_prosrc)
      and position('already_gone' in v_prosrc) < position('record_audit' in v_prosrc),
    'SQL-05: the zero-row return must sit between the row_count guard and the '
    || 'audit insert, so no zero-row path can ledger a delete'
  );
end;
$$;

-- ===========================================================================
-- 5. Row lock, structurally: one snapshot decides family, delete predicate and
--    audit row. Multi-backend interleavings are NOT covered here (see the
--    honest-limit note in the header); this pins that the lock exists and that
--    it is taken before anything is mutated.
-- ===========================================================================
do $$
declare
  v_prosrc text;
  v_pos_actor integer;
  v_pos_zone integer;
  v_pos_lock integer;
  v_pos_family_gate integer;
  v_pos_parent_gate integer;
  v_pos_delete integer;
  v_pos_audit integer;
begin
  select prosrc into v_prosrc
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited';

  v_pos_actor := position('p_actor_user_id is null' in v_prosrc);
  v_pos_zone := position('p_zone_id is null' in v_prosrc);
  v_pos_lock := position('for update' in v_prosrc);
  v_pos_family_gate := position('family_unavailable' in v_prosrc);
  v_pos_parent_gate := position('private.is_parent_of_family' in v_prosrc);
  v_pos_delete := position('delete from public.safe_zones' in v_prosrc);
  v_pos_audit := position('record_audit' in v_prosrc);

  perform tests.assert_true(
    v_pos_lock > 0,
    'SQL-05: the resolve select must take a row lock (FOR UPDATE)'
  );
  perform tests.assert_true(
    v_pos_actor > 0 and v_pos_actor < v_pos_zone
      and v_pos_zone < v_pos_lock
      and v_pos_lock < v_pos_family_gate
      and v_pos_family_gate < v_pos_parent_gate
      and v_pos_parent_gate < v_pos_delete
      and v_pos_delete < v_pos_audit,
    'SQL-05: guard order must be actor, zone id, locked resolve, family gate, '
    || 'parent gate, delete, audit - got '
    || format('%s/%s/%s/%s/%s/%s/%s', v_pos_actor, v_pos_zone, v_pos_lock,
              v_pos_family_gate, v_pos_parent_gate, v_pos_delete, v_pos_audit)
  );
  -- The delete is scoped by the SAME family the locked read resolved, so a
  -- forged zone id cannot delete a row in another family.
  perform tests.assert_true(
    v_prosrc like '%and family_id = v_family_id%',
    'SQL-05: the DELETE predicate must carry the resolved family_id'
  );
  -- Authorization is server-side and takes the parameter, never a GUC.
  perform tests.assert_true(
    v_prosrc like '%private.is_parent_of_family(p_actor_user_id, v_family_id)%',
    'SQL-05: authorization must be is_parent_of_family(p_actor_user_id, v_family_id)'
  );
end;
$$;

-- ===========================================================================
-- 6. End state: exactly one ledger row per zone this file actually deleted, no
--    orphan latch rows, and the 20_fixtures.sql zone left untouched.
-- ===========================================================================
do $$
declare
  v_rows integer;
begin
  select count(*) into v_rows
  from public.audit_logs
  where event_type = 'zone_deleted'
    and target_id in (
      'e8000000-0000-4000-8000-000000000001',  -- z1, section 1a
      'e8000000-0000-4000-8000-000000000002',  -- z2, section 2c (after 2 failures)
      'e8000000-0000-4000-8000-000000000003',  -- z3, section 3f
      'e8000000-0000-4000-8000-000000000005'   -- z5, section 4c (after one replay)
    );
  perform tests.assert_true(
    v_rows = 4,
    'SQL-05: four real deletes across this file must leave exactly four '
    || 'zone_deleted rows, got ' || v_rows
  );

  -- The zones refused in sections 3/4 must be absent from the ledger entirely.
  select count(*) into v_rows
  from public.audit_logs
  where event_type = 'zone_deleted'
    and target_id = 'e8000000-0000-4000-8000-000000000004';
  perform tests.assert_true(
    v_rows = 0,
    'SQL-05: the soft-deleted family''s zone must never be ledgered, got ' || v_rows
  );

  -- Cascade integrity after every delete/rollback in this file.
  perform tests.assert_true(
    not exists (
      select 1 from public.safe_zone_states s
      where not exists (select 1 from public.safe_zones z where z.id = s.zone_id)
    ),
    'SQL-05: no safe_zone_states row may outlive its zone (cascade intact)'
  );

  -- This file never mutates another file's rows: the fixture zone is still there.
  perform tests.assert_true(
    exists (
      select 1 from public.safe_zones
      where id::text not like 'e8%'
    ),
    'SQL-05: the 20_fixtures.sql safe zone must still exist (self-containment)'
  );
end;
$$;

-- Marker for the chain log: every section above ran to completion. Without it a
-- green exit proves only that no statement errored, not that this file's last
-- assertion was reached (60-75 print the same style of notice).
do $$
begin
  raise notice 'ALL ZONE DELETE ATOMIC RPC TESTS PASSED';
end;
$$;
