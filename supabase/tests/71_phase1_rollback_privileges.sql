-- Phase 1 rollback privilege tests (migration 20261030000200_phase1_authorization.sql).
--
-- Closes Phase 2 gap SQL-01: the migration's rollback text used to restore
-- PUBLIC EXECUTE on the two private `private` functions, restore client DELETE
-- on public.safe_zones and re-create the safe_zones_delete_parent policy, i.e.
-- following the documented undo returned to exactly the pre-Phase-1 exposure.
--
-- Run in the documented `psql -f` chain AFTER 70_phase1_authorization.sql and
-- BEFORE 72_retention_sweep.sql, from the repository root (this file re-applies
-- the migration with `\i`, exactly like the chain does). See supabase/tests/README.md.
--
-- Nothing here is executed against a Supabase project; it needs only plain
-- PostgreSQL 15+ with supabase/tests/00_auth_stub.sql applied.
--
-- Method: the privilege state is read from pg_proc.proacl, pg_class.relacl,
-- pg_policies and has_*_privilege() - never from the migration prose - and
-- snapshotted with the same query at every checkpoint:
--
--   1. FORWARD        the state the chain leaves behind.
--   2. UNSAFE-PATH    the five statements the old rollback text told operators
--                     to run, executed inside an explicit transaction and
--                     undone by ROLLBACK. Asserts they DO re-open the exposure
--                     (negative control) and that the database is unchanged
--                     afterwards.
--   3. ROLLBACK       steps R1 + R2 of the migration header, executed for real,
--                     then asserts the privilege snapshot is IDENTICAL to 1:
--                     a supported rollback changes privileges and policies not
--                     at all, and only drops the function this migration
--                     introduced.
--   4. GUARD          runs step R2 alone with the forward bodies still in place
--                     and asserts it HALTS instead of orphaning the helper.
--                     (The old text dropped the helper unconditionally, which
--                     psql reported as success and every later wrapper call
--                     failed with 42883 - a P0 outage.)
--   5. RE-FORWARD     the migration is applied again and the snapshot must match
--                     1 again, so 72_retention_sweep.sql and
--                     45_device_recovery.sql see the state they expect.
drop view if exists p3a_capture;
drop table if exists p3a_snap;
drop table if exists p3a_phase;

create temp table p3a_phase (phase text not null);
insert into p3a_phase values ('init');
create temp table p3a_snap (phase text, k text, v text);

-- One capture definition, reused at every checkpoint: change p3a_phase, then
-- `insert into p3a_snap select * from p3a_capture`.
create temp view p3a_capture as
    -- effective EXECUTE on every function the migration touches (except the
    -- helper it introduces, which is captured separately below)
    select ph.phase,
           'eff|' || o.obj || '|' || r.rol as k,
           case
             when to_regprocedure(o.obj) is null then 'ABSENT'
             else (has_function_privilege(r.rol, to_regprocedure(o.obj),
                                          'EXECUTE'))::text
           end as v
    from p3a_phase ph
    cross join (values
      ('f', 'private.remote_session_transition_guard()'),
      ('f', 'private.request_device_recovery(uuid, uuid)'),
      ('f', 'public.request_remote_session(uuid, uuid, text)'),
      ('f', 'public.revoke_device(uuid, uuid)'),
      ('f', 'public.unlink_child(uuid, uuid, uuid)'),
      ('f', 'public.apply_policy_version(uuid, jsonb, uuid, text)'),
      ('f', 'public.request_device_recovery(uuid, uuid)')
    ) as o(kind, obj)
    cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rol)

    union all

    -- effective table / column privileges on safe_zones
    select ph.phase,
           'eff|public.safe_zones|' || r.rol || '|' || p.priv,
           case p.scope
             when 'table' then
               (has_table_privilege(r.rol, 'public.safe_zones', p.priv))::text
             else
               (has_any_column_privilege(r.rol, 'public.safe_zones',
                                         p.priv))::text
           end
    from p3a_phase ph
    cross join (values
      ('SELECT', 'table'), ('DELETE', 'table'),
      ('INSERT', 'col'), ('UPDATE', 'col')) as p(priv, scope)
    cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rol)

    union all

    -- raw ACLs: PUBLIC leakage is only visible in the aclitem list (grantee 0)
    select ph.phase, 'acl|fn|' || p.oid::regprocedure::text,
           coalesce(array_to_string(p.proacl, ','), 'NULL=default-PUBLIC')
    from p3a_phase ph
    join pg_proc p on p.oid in (
      to_regprocedure('private.remote_session_transition_guard()'),
      to_regprocedure('private.request_device_recovery(uuid, uuid)'),
      to_regprocedure('public.request_remote_session(uuid, uuid, text)'),
      to_regprocedure('public.revoke_device(uuid, uuid)'),
      to_regprocedure('public.unlink_child(uuid, uuid, uuid)'),
      to_regprocedure('public.apply_policy_version(uuid, jsonb, uuid, text)'),
      to_regprocedure('public.request_device_recovery(uuid, uuid)'))

    union all

    select ph.phase, 'acl|table|public.safe_zones',
           coalesce(array_to_string(c.relacl, ','), 'NULL=default-PUBLIC')
    from p3a_phase ph
    join pg_class c on c.oid = 'public.safe_zones'::regclass

    union all

    -- the full safe_zones policy list
    select ph.phase, 'policy|' || pol.policyname,
           pol.cmd || '|' || pol.roles::text || '|' || coalesce(pol.qual, '(null)')
    from p3a_phase ph
    join pg_policies pol
      on pol.schemaname = 'public' and pol.tablename = 'safe_zones'

    union all

    -- objects this migration owns, asserted separately per checkpoint
    select ph.phase, 'helper|private.is_parent_of_family(uuid, uuid)',
           coalesce((select array_to_string(p.proacl, ',') from pg_proc p
                     where p.oid = to_regprocedure(
                       'private.is_parent_of_family(uuid, uuid)')), 'ABSENT')
    from p3a_phase ph

    union all

    select ph.phase, 'index|webrtc_signals_session_sequence_uniq',
           coalesce(to_regclass(
             'public.webrtc_signals_session_sequence_uniq')::text, 'ABSENT')
    from p3a_phase ph

    union all

    select ph.phase, 'refs|functions_calling_helper',
           -- schema-qualified name, so the value never depends on search_path
           -- the way regprocedure output does
           coalesce((select string_agg(n.nspname || '.' || p.proname, ','
                                       order by n.nspname, p.proname)
                     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname in ('public', 'private')
                       and p.prosrc like '%is_parent_of_family%'
                       -- Excluded by name, NOT by `'<sig>'::regprocedure`: a
                       -- regprocedure literal inside a VIEW records a pg_depend
                       -- edge on the helper and makes step R2's DROP fail with
                       -- "cannot drop ... because view p3a_capture depends on it".
                       and not (n.nspname = 'private'
                                and p.proname = 'is_parent_of_family')),
                    'NONE')
    from p3a_phase ph;

-- ===========================================================================
-- 1. FORWARD STATE (the migration is already applied by the chain)
-- ===========================================================================
update p3a_phase set phase = '1_forward';
insert into p3a_snap select * from p3a_capture;

do $$
declare
  v_hits integer;
begin
  select count(*) into v_hits from p3a_snap
  where phase = '1_forward' and v = 'true'
    and (k = 'eff|private.remote_session_transition_guard()|anon'
      or k = 'eff|private.remote_session_transition_guard()|authenticated'
      or k = 'eff|private.request_device_recovery(uuid, uuid)|anon'
      or k = 'eff|private.request_device_recovery(uuid, uuid)|authenticated'
      or k = 'eff|public.safe_zones|authenticated|DELETE'
      or k = 'eff|public.safe_zones|anon|DELETE');
  perform tests.assert_true(v_hits = 0,
    'FORWARD: no client may hold execute on the private helpers or DELETE on '
    || 'safe_zones, found ' || v_hits || ' leaking rows');

  select count(*) into v_hits from p3a_snap
  where phase = '1_forward' and k like 'acl|fn|private.%'
    and v <> 'NULL=default-PUBLIC' and v ~ '(^|,)=X/';
  perform tests.assert_true(v_hits = 0,
    'FORWARD: pg_proc.proacl of the private helpers must carry no PUBLIC (=X/) '
    || 'entry, found ' || v_hits);

  select count(*) into v_hits from p3a_snap
  where phase = '1_forward' and k = 'policy|safe_zones_delete_parent';
  perform tests.assert_true(v_hits = 0,
    'FORWARD: safe_zones_delete_parent must not exist');

  select count(*) into v_hits from p3a_snap
  where phase = '1_forward' and k like 'policy|%'
    and k not like 'policy|safe_zones_delete_parent%';
  perform tests.assert_true(v_hits = 3,
    'FORWARD: select/insert/update safe_zones policies must remain, got ' || v_hits);

  perform tests.assert_true(
    (select v from p3a_snap where phase = '1_forward'
      and k = 'index|webrtc_signals_session_sequence_uniq') <> 'ABSENT',
    'FORWARD: the (session_id, sequence) unique index must exist');

  perform tests.assert_true(
    (select v from p3a_snap where phase = '1_forward'
      and k = 'helper|private.is_parent_of_family(uuid, uuid)')
      = 'postgres=X/postgres,service_role=X/postgres',
    'FORWARD: the helper must be service-role-only, no PUBLIC');

  -- [2026-11-03, SQL-05] The fifth entry is public.delete_safe_zone_audited,
  -- added by the later migration 20261103000100, which authorizes through this
  -- same Phase 1 helper. The pin stays an EXACT list: a sixth wrapper, or any
  -- client-reachable function picking up the helper, still fails this test.
  -- Nothing was relaxed - the expected value grew by one known, reviewed name.
  perform tests.assert_true(
    (select v from p3a_snap where phase = '1_forward'
      and k = 'refs|functions_calling_helper')
      = 'public.apply_policy_version,public.delete_safe_zone_audited,'
        || 'public.request_remote_session,public.revoke_device,public.unlink_child',
    'FORWARD: exactly the five wrappers must reference the helper');
end;
$$;

-- ===========================================================================
-- 2. NEGATIVE CONTROL: the statements the OLD rollback text told operators to
--    run. Executed, measured, then undone with ROLLBACK. They must re-open the
--    exposure - that is the whole point of SQL-01.
-- ===========================================================================
begin;
  grant execute on function private.remote_session_transition_guard() to public;
  grant execute on function private.request_device_recovery(uuid, uuid) to public;
  grant delete on public.safe_zones to authenticated;
  create policy safe_zones_delete_parent on public.safe_zones
    for delete to authenticated using (private.is_family_parent(family_id));
  drop index if exists public.webrtc_signals_session_sequence_uniq;

  do $$
  declare v_hits integer;
  begin
    select count(*) into v_hits
    from (
      select 'anon|guard' as what where has_function_privilege(
        'anon', 'private.remote_session_transition_guard()', 'EXECUTE')
      union all select 'authenticated|guard' where has_function_privilege(
        'authenticated', 'private.remote_session_transition_guard()', 'EXECUTE')
      union all select 'anon|recovery' where has_function_privilege(
        'anon', 'private.request_device_recovery(uuid, uuid)', 'EXECUTE')
      union all select 'authenticated|recovery' where has_function_privilege(
        'authenticated', 'private.request_device_recovery(uuid, uuid)', 'EXECUTE')
      union all select 'authenticated|safe_zones DELETE' where has_table_privilege(
        'authenticated', 'public.safe_zones', 'DELETE')
      union all select 'PUBLIC|safe_zones DELETE' where exists (
        select 1 from aclexplode((select relacl from pg_class
                                 where oid = 'public.safe_zones'::regclass)) x
        where x.grantee = 0 and x.privilege_type = 'DELETE')
    ) leaked;
    perform tests.assert_true(v_hits = 5,
      'OLD ROLLBACK TEXT: expected anon+authenticated execute on both private '
      || 'helpers and DELETE on safe_zones back (5 cells), measured ' || v_hits);

    perform tests.assert_true(
      (select count(*) from pg_policies where schemaname = 'public'
         and tablename = 'safe_zones'
         and policyname = 'safe_zones_delete_parent') = 1,
      'OLD ROLLBACK TEXT: the unaudited client DELETE policy comes back');

    perform tests.assert_true(
      (select count(*) from pg_policies where schemaname = 'public'
         and tablename = 'safe_zones') = 4,
      'OLD ROLLBACK TEXT: safe_zones is back to four policies');
  end;
  $$;
rollback;

update p3a_phase set phase = '2a_after_unsafe_rollback';
insert into p3a_snap select * from p3a_capture;
update p3a_phase set phase = '1_forward';

do $$
declare
  v_diff integer;
begin
  -- the ROLLBACK of the negative control must have restored the forward state
  select count(*) into v_diff from (
    (select k, v from p3a_snap where phase = '1_forward'
       except select k, v from p3a_snap where phase = '2a_after_unsafe_rollback')
    union all
    (select k, v from p3a_snap where phase = '2a_after_unsafe_rollback'
       except select k, v from p3a_snap where phase = '1_forward')
  ) d;
  perform tests.assert_true(v_diff = 0,
    'the negative control must leave zero privilege delta after ROLLBACK, got '
    || v_diff);
end;
$$;

-- ===========================================================================
-- 3. THE GUARD: step R2 alone, with the Phase-1 bodies still in place, must
--    halt instead of orphaning the helper.
-- ===========================================================================
-- R2 exists once, so what this file measures is what the header documents.
create or replace function tests.p3a_rollback_r2()
returns void
language plpgsql
as $fn$
declare
  v_refs text;
begin
  select string_agg(p.oid::regprocedure::text, ', '
                    order by p.oid::regprocedure::text)
    into v_refs
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private')
    and p.prosrc like '%is_parent_of_family%'
    and p.oid::regprocedure
        <> 'private.is_parent_of_family(uuid, uuid)'::regprocedure;

  if v_refs is not null then
    raise exception
      'rollback halted: % still reference private.is_parent_of_family(uuid, uuid); '
      'run step R1 first, otherwise these RPCs fail at runtime with 42883',
      v_refs using errcode = 'P0001';
  end if;

  execute 'drop function if exists private.is_parent_of_family(uuid, uuid)';
end;
$fn$;

do $outer$
begin
  perform tests.expect_error(
    'select tests.p3a_rollback_r2()', 'P0001', 'rollback halted',
    'R2 without R1 must halt instead of dropping a helper the wrappers use');
  perform tests.assert_true(
    to_regprocedure('private.is_parent_of_family(uuid, uuid)') is not null,
    'the halted guard must leave the helper in place');
  perform tests.assert_true(
    has_function_privilege('service_role', 'public.unlink_child(uuid, uuid, uuid)',
                           'EXECUTE')
    and not has_function_privilege('authenticated',
          'public.unlink_child(uuid, uuid, uuid)', 'EXECUTE'),
    'the wrappers are still service-role only after the halted rollback');
end;
$outer$;

-- ===========================================================================
-- 4. SUPPORTED ROLLBACK: step R1 (restore the four pre-Phase-1 bodies) then
--    step R2 (guarded helper drop). Bodies copied verbatim from
--    20261028000200_parent_controlled_session_lifetime.sql:106-181 and
--    20260101000100_functions.sql:721-733 / 748-759 / 761-771.
-- ===========================================================================
create or replace function public.apply_policy_version(
  p_device_id uuid,
  p_policy jsonb,
  p_actor uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.apply_policy_version(p_device_id, p_policy, p_actor, p_idempotency_key);
$$;

create or replace function public.unlink_child(
  p_family_id uuid,
  p_child_user_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.unlink_child(p_family_id, p_child_user_id, p_actor_user_id);
$$;

create or replace function public.revoke_device(
  p_device_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.revoke_device(p_device_id, p_actor_user_id);
$$;

create or replace function public.request_remote_session(
  p_device_id uuid,
  p_parent_user_id uuid,
  p_kind text
)
returns public.remote_sessions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device public.devices;
  v_session public.remote_sessions;
begin
  if p_kind is null or p_kind not in ('audio', 'video') then
    raise exception 'invalid_kind';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_device_id::text, 0));

  select * into v_device
  from public.devices
  where id = p_device_id;

  if not found then
    raise exception 'device_not_found';
  end if;
  if v_device.status <> 'active' then
    raise exception 'device_not_active';
  end if;

  update public.remote_sessions
  set status = 'expired',
      ended_at = now(),
      ended_reason = 'expired'
  where device_id = p_device_id
    and status = 'requested'
    and expires_at is not null
    and expires_at <= now();

  if exists (
    select 1
    from public.remote_sessions
    where device_id = p_device_id
      and status in ('requested', 'accepted', 'active')
  ) then
    raise exception 'session_in_progress' using errcode = 'P0001';
  end if;

  insert into public.remote_sessions (
    family_id, device_id, parent_user_id, child_user_id, kind, status,
    requested_at, expires_at, consent_recorded
  )
  values (
    v_device.family_id, v_device.id, p_parent_user_id, v_device.child_user_id,
    p_kind, 'requested', now(), now() + interval '10 minutes', false
  )
  returning * into v_session;

  return v_session;
end;
$$;

-- Step R1' (SQL-05, added 2026-11-03): public.delete_safe_zone_audited comes
-- from the LATER migration 20261103000100 and authorizes through this same
-- Phase 1 helper, so a Phase-1 rollback must take that migration back first.
-- This file failed at R2 ("rollback halted: ... delete_safe_zone_audited ...")
-- until this line existed, which is the proof the ordering is enforced rather
-- than merely documented. Section 5 re-applies 20261103000100, so the chain
-- continues from the same forward state it entered this file with.
drop function if exists public.delete_safe_zone_audited(uuid, uuid);

-- Step R2, the same implementation section 3 proved halts.
select tests.p3a_rollback_r2();

update p3a_phase set phase = '3_rollback';
insert into p3a_snap select * from p3a_capture;

do $$
declare
  v_diff integer;
  v_rows integer;
begin
  -- THE CORE ASSERTION OF SQL-01: a supported rollback changes no privilege and
  -- no policy. Everything that would re-open an exposure stays closed.
  select count(*) into v_diff from (
    (select k, v from p3a_snap where phase = '1_forward' and k not like 'helper|%'
       and k not like 'refs|%'
     except
     select k, v from p3a_snap where phase = '3_rollback' and k not like 'helper|%'
       and k not like 'refs|%')
    union all
    (select k, v from p3a_snap where phase = '3_rollback' and k not like 'helper|%'
       and k not like 'refs|%'
     except
     select k, v from p3a_snap where phase = '1_forward' and k not like 'helper|%'
       and k not like 'refs|%')
  ) d;
  perform tests.assert_true(v_diff = 0,
    'ROLLBACK: the privilege/policy/index snapshot must be identical to the '
    || 'forward state, got ' || v_diff || ' differing cells');

  -- Re-state the individual cells so a failure names the exposure, not a count.
  perform tests.assert_true(
    not has_function_privilege('anon', 'private.remote_session_transition_guard()',
                               'EXECUTE')
    and not has_function_privilege('authenticated',
          'private.remote_session_transition_guard()', 'EXECUTE'),
    'ROLLBACK: PUBLIC execute must NOT be restored on the transition guard');
  perform tests.assert_true(
    not has_function_privilege('anon', 'private.request_device_recovery(uuid, uuid)',
                               'EXECUTE')
    and not has_function_privilege('authenticated',
          'private.request_device_recovery(uuid, uuid)', 'EXECUTE'),
    'ROLLBACK: PUBLIC execute must NOT be restored on request_device_recovery');
  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.safe_zones', 'DELETE')
    and not has_table_privilege('anon', 'public.safe_zones', 'DELETE'),
    'ROLLBACK: client DELETE must NOT be restored on safe_zones');
  select count(*) into v_rows from pg_policies
  where schemaname = 'public' and tablename = 'safe_zones'
    and policyname = 'safe_zones_delete_parent';
  perform tests.assert_true(v_rows = 0,
    'ROLLBACK: the unaudited safe_zones_delete_parent policy must NOT come back');

  -- The helper is gone (R1 ran first), and nothing is left pointing at it.
  -- [2026-11-03, SQL-05] still true, but only because step R1' below drops
  -- public.delete_safe_zone_audited (the fifth dependant, created by the LATER
  -- migration 20261103000100) before R2 runs - R2's own guard halts otherwise,
  -- which section 3 proves. The rollback order between the two migrations is
  -- therefore enforced, not merely documented.
  perform tests.assert_true(
    to_regprocedure('private.is_parent_of_family(uuid, uuid)') is null,
    'ROLLBACK: the helper this migration introduced is dropped');
  perform tests.assert_true(
    (select v from p3a_snap where phase = '3_rollback'
       and k = 'refs|functions_calling_helper') = 'NONE',
    'ROLLBACK: no function may still reference the dropped helper');
  perform tests.assert_true(
    to_regprocedure('public.delete_safe_zone_audited(uuid, uuid)') is null,
    'ROLLBACK: the SQL-05 wrapper must be gone at this point - it is what made '
    || 'R2 halt before step R1 existed');

  -- Rolling back the bodies must not quietly drop SECURITY DEFINER or the
  -- pinned search_path, and must keep the wrappers service-role only.
  select count(*) into v_rows from pg_proc p
  where p.oid in (
      to_regprocedure('public.request_remote_session(uuid, uuid, text)'),
      to_regprocedure('public.revoke_device(uuid, uuid)'),
      to_regprocedure('public.unlink_child(uuid, uuid, uuid)'),
      to_regprocedure('public.apply_policy_version(uuid, jsonb, uuid, text)'))
    and p.prosecdef
    and array_to_string(p.proconfig, ',') like '%search_path=%'
    and has_function_privilege('service_role', p.oid, 'EXECUTE')
    and not has_function_privilege('anon', p.oid, 'EXECUTE')
    and not has_function_privilege('authenticated', p.oid, 'EXECUTE');
  perform tests.assert_true(v_rows = 4,
    'ROLLBACK: all four wrappers must stay SECURITY DEFINER, pinned and '
    || 'service-role-only, got ' || v_rows);

  -- The pre-Phase-1 bodies are what came back: no actor check left.
  select count(*) into v_rows from pg_proc
  where prosrc like '%not_family_parent%';
  perform tests.assert_true(v_rows = 0,
    'ROLLBACK: the public wrappers must no longer raise not_family_parent, got '
    || v_rows);

  -- Rollback is functional, not just ACL-correct: the wrappers execute. Before
  -- the guard existed this call raised 42883 after a copy-paste rollback.
  perform tests.expect_error(
    'select public.unlink_child(gen_random_uuid(), gen_random_uuid(), gen_random_uuid())',
    null, 'forbidden',
    'ROLLBACK: unlink_child must reach private.unlink_child again (no 42883)');
end;
$$;

-- ===========================================================================
-- 5. RE-FORWARD so the rest of the documented chain sees the state it expects.
--    Both migrations are re-applied, in filename order: step R1' above dropped
--    public.delete_safe_zone_audited, and the 'refs|functions_calling_helper'
--    cell is part of the forward/re-forward diff, so leaving it dropped would
--    make this file end in a state the chain never started from.
-- ===========================================================================
\i supabase/migrations/20261030000200_phase1_authorization.sql
\i supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql

update p3a_phase set phase = '4_reforward';
insert into p3a_snap select * from p3a_capture;

do $$
declare
  v_diff integer;
  v_rows integer;
begin
  select count(*) into v_diff from (
    (select k, v from p3a_snap where phase = '1_forward'
     except select k, v from p3a_snap where phase = '4_reforward')
    union all
    (select k, v from p3a_snap where phase = '4_reforward'
     except select k, v from p3a_snap where phase = '1_forward')
  ) d;
  perform tests.assert_true(v_diff = 0,
    'RE-FORWARD: re-applying the migration must reproduce the forward state '
    || 'exactly, got ' || v_diff || ' differing cells');

  -- [2026-11-03, SQL-05] five, not four: the four Phase 1 actor checks plus
  -- public.delete_safe_zone_audited, re-created by the `\i` above. The pin is
  -- still an exact count, so a sixth body quietly raising this code still fails.
  select count(*) into v_rows from pg_proc where prosrc like '%not_family_parent%';
  perform tests.assert_true(v_rows = 5,
    'RE-FORWARD: the four actor checks (plus the SQL-05 wrapper) must be back, '
    || 'got ' || v_rows);

  raise notice 'ALL PHASE 1 ROLLBACK PRIVILEGE TESTS PASSED';
  drop view if exists p3a_capture;
  drop table if exists p3a_snap;
  drop table if exists p3a_phase;
end;
$$;

drop function if exists tests.p3a_rollback_r2();

