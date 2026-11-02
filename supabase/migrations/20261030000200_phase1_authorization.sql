-- Phase 1 authorization hardening (security workstream).
--
-- Closes four authorization defects found by the Phase 1 audit:
--
--   1. `safe_zones` accepted a client-side DELETE (`safe_zones_delete_parent`
--      policy plus a table-level DELETE grant). Any family parent could delete
--      a zone with no audit trail. Deletion now goes through the `family-admin`
--      Edge Function action `delete_zone`, which re-checks the caller and
--      writes an `audit_logs` row. Reads/inserts/updates are unchanged.
--   2. The service-only SECURITY DEFINER RPCs took the acting user id from the
--      caller and (for request_remote_session / apply_policy_version) never
--      verified it. Each public wrapper now checks the actor against
--      `private.is_parent_of_family()` and raises `not_family_parent` (42501).
--   3. `private.remote_session_transition_guard()` and
--      `private.request_device_recovery(uuid, uuid)` kept PostgreSQL's default
--      PUBLIC EXECUTE grant, so `anon`/`authenticated` could execute them via
--      PostgREST. Both are revoked (guarded, so a missing/different signature
--      cannot abort the migration).
--   4. `webrtc_signals` had no uniqueness guarantee on (session_id, sequence);
--      a replayed signal could be stored twice. A unique index is added only
--      when no duplicates exist today. No rows are ever deleted here.
--
-- Every statement is written to be re-runnable. The migration is LOCAL ONLY in
-- Phase 1: it is not applied and does not change the hosted project.
--
-- Rollback
--
-- This migration only *hardens*, so "roll it back" has two different meanings
-- and they are not equivalent. The matrix below is measured, not asserted: every
-- cell was read from pg_proc.proacl / pg_class.relacl / pg_policies on a
-- disposable local PostgreSQL 16.9 database (before = migrations up to
-- 20261030000100; forward = with this file applied; rollback = after the steps
-- below). Raw captures and the reproduction commands are in
-- docs/implementation/_work/p3-sql-rollback.md.
--
--   object                                    grantee         before      forward     rollback
--   private.remote_session_transition_guard() anon/auth       EXECUTE     REVOKED     REVOKED
--   private.remote_session_transition_guard() service_role    EXECUTE     REVOKED     REVOKED
--   private.request_device_recovery(uuid,uuid) anon/auth      EXECUTE     REVOKED     REVOKED
--   private.request_device_recovery(uuid,uuid) service_role   EXECUTE     REVOKED     REVOKED
--   public.safe_zones DELETE                  anon           (none)      (none)      (none)
--   public.safe_zones DELETE                  authenticated  GRANTED     REVOKED     REVOKED
--   policy safe_zones_delete_parent (DELETE)  authenticated  PRESENT     ABSENT      ABSENT
--   index webrtc_signals_session_sequence_uniq -             ABSENT      PRESENT     PRESENT
--   public.{request_remote_session,revoke_device,unlink_child,apply_policy_version}
--                                             anon/auth      REVOKED     REVOKED     REVOKED
--                                             service_role   EXECUTE     EXECUTE     EXECUTE
--
-- Two measured facts decide the shape of the rollback:
--
--   A. The four public wrappers were ALREADY service-role-only before this
--      migration (20260101000100_functions.sql:876-904 and
--      20261028000200_...sql:183-187). Sections 3-6 below change their bodies,
--      not their grants. Rolling their bodies back is therefore
--      privilege-neutral - see the last two matrix rows.
--   B. The two private functions held EXECUTE only through PostgreSQL's default
--      PUBLIC grant (proacl IS NULL). Re-granting PUBLIC hands EXECUTE back to
--      anon and authenticated over PostgREST: it re-opens defect 3. Re-granting
--      DELETE on safe_zones and re-creating safe_zones_delete_parent re-opens
--      defect 1 (an unaudited client-side delete). Both are client-reachable.
--
-- ROLLBACK - supported, safe. Runs in one transaction, in this order. It
-- restores the pre-Phase-1 function bodies and keeps every privilege / RLS /
-- index hardening:
--
--   R1. Restore the four pre-Phase-1 wrapper bodies verbatim from their source
--       migrations (`create or replace` leaves proacl and reloptions alone, so
--       this cannot change privileges; SECURITY DEFINER and the pinned
--       search_path are part of these statements):
--
--         sed -n '106,181p' \
--           supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql \
--           > /tmp/rollback_r1.sql
--         sed -n '721,733p;748,759p;761,771p' \
--           supabase/migrations/20260101000100_functions.sql >> /tmp/rollback_r1.sql
--         psql -v ON_ERROR_STOP=1 -d <target> -f /tmp/rollback_r1.sql
--
--       Verified on .tools/pgdata_p3a: this yields byte-identical ACLs and
--       policies to restoring the bodies inline, and
--       prosecdef/search_path survive unchanged.
--
--   R2. Drop the helper ONLY if nothing references it any more:
--
--         do $$
--         declare v_refs text;
--         begin
--           select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text)
--             into v_refs
--           from pg_proc p
--           join pg_namespace n on n.oid = p.pronamespace
--           where n.nspname in ('public', 'private')
--             and p.prosrc like '%is_parent_of_family%'
--             and p.oid::regprocedure
--                 <> 'private.is_parent_of_family(uuid, uuid)'::regprocedure;
--           if v_refs is not null then
--             raise exception
--               'rollback halted: % still reference private.is_parent_of_family(uuid, uuid); '
--               'run step R1 first, otherwise these RPCs fail at runtime with 42883',
--               v_refs using errcode = 'P0001';
--           end if;
--           execute 'drop function if exists private.is_parent_of_family(uuid, uuid)';
--         end;
--         $$;
--
--       The guard is not cosmetic. The previous rollback text listed the drop
--       unconditionally and left the wrapper re-creation as a *comment*, so an
--       operator copy-pasting the block dropped the helper while all four
--       wrappers still called it. Measured: psql exits 0, and every later call
--       of public.unlink_child / revoke_device / apply_policy_version /
--       request_remote_session fails with 42883 "function
--       private.is_parent_of_family(uuid, uuid) does not exist" - a P0 outage
--       of the four service RPCs hiding behind a "successful" undo. Skipping
--       R1 and running R2 alone now halts loudly instead (verified).
--
--   R3. NOT RUN, deliberately. Each of these statements re-opens an exposure
--       and none of them belongs in a supported rollback:
--
--         grant execute on function private.remote_session_transition_guard() to public;
--         grant execute on function private.request_device_recovery(uuid, uuid) to public;
--         grant delete on public.safe_zones to authenticated;
--         create policy safe_zones_delete_parent on public.safe_zones
--           for delete to authenticated using (private.is_family_parent(family_id));
--         drop index if exists public.webrtc_signals_session_sequence_uniq;
--
--       Running all five returns the database to the exact pre-Phase-1 state -
--       that is a true revert, and it is the state this migration exists to
--       close. It is available only as an explicit, owner-approved de-hardening
--       (Phase 2 gap SQL-01), not as a routine undo. Note that the pre-Phase-1
--       baseline itself never granted DELETE to `anon` or to PUBLIC: the
--       `grant ... to public` lines were wider than the baseline even for a
--       true revert, because PUBLIC subsumes anon/authenticated/service_role.
--
--   R4. Verify after any rollback direction. proacl must contain no PUBLIC
--       entry (`=X/` with an empty grantee) and calls_helper must be false:
--
--         select oid::regprocedure as function, proacl,
--                prosrc like '%is_parent_of_family%' as calls_helper
--         from pg_proc
--         where oid in ('private.remote_session_transition_guard()'::regprocedure,
--                       'private.request_device_recovery(uuid, uuid)'::regprocedure,
--                       'public.unlink_child(uuid, uuid, uuid)'::regprocedure,
--                       'public.request_remote_session(uuid, uuid, text)'::regprocedure);
--
--       supabase/tests/71_phase1_rollback_privileges.sql asserts the same cells
--       plus the policy list, and is part of the documented suite chain.
--
-- IS AN IN-PLACE ROLLBACK OF AN APPLIED MIGRATION EVEN SUPPORTED?
--   * Privileges/policies/index: yes, reversible in the hardening direction, and
--     reversible to the pre-Phase-1 state if (and only if) the owner accepts the
--     exposures in R3. Nothing here is unrecoverable.
--   * Function bodies: the pre-Phase-1 text is NOT recoverable from the
--     database, because section 3-6 overwrite it. Recovery depends on the two
--     source migrations above being present in the deployed revision. Treat
--     these bodies as git-only rollback material and re-check the line ranges
--     at deploy time.
--   * Data: rollback is schema-only. Zones already deleted through the audited
--     `family-admin delete_zone` path stay deleted, and sessions/policies that
--     were *rejected* by not_family_parent were never written, so a rollback
--     cannot "bring them back" either. No data migration runs here in either
--     direction.
--   * service_role loses EXECUTE on the two private functions in all three
--     columns of the matrix (it held it only via PUBLIC). Verified harmless: no
--     Edge Function or client calls them (only the SECURITY DEFINER public
--     wrappers do, and those run as the owner), and 70_phase1_authorization.sql
--     already pins service_role's entry point to the public wrapper. This is a
--     documented divergence from the literal baseline, in the safe direction.

-- ---------------------------------------------------------------------------
-- 1. safe_zones: no client DELETE (idempotent)
-- ---------------------------------------------------------------------------
drop policy if exists safe_zones_delete_parent on public.safe_zones;

-- Removes the `grant delete on public.safe_zones to authenticated` made by
-- 20260101000200_rls.sql. `anon` never held it; revoking is a no-op then.
revoke delete on public.safe_zones from authenticated, anon;

-- ---------------------------------------------------------------------------
-- 2. private.is_parent_of_family(p_user, p_family)
--
-- Same predicate the RLS helpers use, but parameterised on the user so a
-- SECURITY DEFINER RPC can verify a caller-supplied actor id instead of
-- trusting it. A missing user/family, a removed membership, a child role and a
-- soft-deleted family all return false. SECURITY DEFINER so it does not
-- re-enter family_members RLS; service-only (revoked from clients below).
-- ---------------------------------------------------------------------------
create or replace function private.is_parent_of_family(
  p_user uuid,
  p_family uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family
      and m.user_id = p_user
      and m.role = 'parent'
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

revoke all on function private.is_parent_of_family(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.is_parent_of_family(uuid, uuid)
  to service_role;

-- ---------------------------------------------------------------------------
-- 3. public.request_remote_session(uuid, uuid, text)
--
-- Re-created from 20261028000200_parent_controlled_session_lifetime.sql with
-- one addition: the actor must be an active parent of the device's family.
-- The advisory lock, the pending-only expiry sweep, the NULL-expiry behaviour
-- (expires_at is a pending deadline only) and the return type are unchanged.
-- ---------------------------------------------------------------------------
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

  -- Phase 1: a forged actor id must not be able to open a session for a family
  -- it does not belong to. Checked before any row is written.
  if not private.is_parent_of_family(p_parent_user_id, v_device.family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
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
    family_id,
    device_id,
    parent_user_id,
    child_user_id,
    kind,
    status,
    requested_at,
    expires_at,
    consent_recorded
  )
  values (
    v_device.family_id,
    v_device.id,
    p_parent_user_id,
    v_device.child_user_id,
    p_kind,
    'requested',
    now(),
    now() + interval '10 minutes',
    false
  )
  returning * into v_session;

  return v_session;
end;
$$;

revoke all on function public.request_remote_session(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.request_remote_session(uuid, uuid, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. public.revoke_device(uuid, uuid)
--
-- Was a one-line SQL wrapper around private.revoke_device(). The actor id is
-- resolved against the device row's family before delegating. A missing device
-- is still delegated so the historical `device_not_found` (P0002) contract is
-- preserved for the 404 mapping in family-admin.
-- ---------------------------------------------------------------------------
create or replace function public.revoke_device(
  p_device_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_family_id uuid;
begin
  select family_id into v_family_id
  from public.devices
  where id = p_device_id;

  if v_family_id is not null
     and not private.is_parent_of_family(p_actor_user_id, v_family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  return private.revoke_device(p_device_id, p_actor_user_id);
end;
$$;

revoke all on function public.revoke_device(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.revoke_device(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 5. public.unlink_child(uuid, uuid, uuid)
--
-- The family is an explicit argument, so the actor is checked before any row is
-- touched. Preserved exception: a child may still unlink their own membership
-- (p_actor = p_child). That path is used by the child app
-- (lib/features/child/... -> pairing action `unlink`) and private.unlink_child
-- only acts on the caller's own (family, child) membership row, so it grants no
-- cross-member power. Any other actor must be an active parent of p_family_id.
-- ---------------------------------------------------------------------------
create or replace function public.unlink_child(
  p_family_id uuid,
  p_child_user_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if p_actor_user_id is null then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  if p_actor_user_id is distinct from p_child_user_id
     and not private.is_parent_of_family(p_actor_user_id, p_family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  return private.unlink_child(p_family_id, p_child_user_id, p_actor_user_id);
end;
$$;

revoke all on function public.unlink_child(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.unlink_child(uuid, uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 6. public.apply_policy_version(uuid, jsonb, uuid, text)
--
-- This RPC previously recorded p_actor as created_by without checking it, so a
-- forged actor id produced a policy attributed to a parent of another family.
-- The actor must now be an active parent of the device's family. A missing or
-- NULL device still falls through to private.apply_policy_version() so
-- `device_required` / `device_not_found` keep their existing SQLSTATEs.
-- ---------------------------------------------------------------------------
create or replace function public.apply_policy_version(
  p_device_id uuid,
  p_policy jsonb,
  p_actor uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_family_id uuid;
begin
  select family_id into v_family_id
  from public.devices
  where id = p_device_id;

  if v_family_id is not null
     and not private.is_parent_of_family(p_actor, v_family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  return private.apply_policy_version(
    p_device_id,
    p_policy,
    p_actor,
    p_idempotency_key
  );
end;
$$;

revoke all on function public.apply_policy_version(uuid, jsonb, uuid, text)
  from public, anon, authenticated;
grant execute on function public.apply_policy_version(uuid, jsonb, uuid, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 7. Remove default PUBLIC EXECUTE from two private functions
--
-- Verified signatures:
--   private.remote_session_transition_guard()  -- returns trigger, 20261028000200
--   private.request_device_recovery(uuid, uuid) -- returns jsonb, 20260101000400
-- Their privileges were never revoked when they were created, so PostgreSQL's
-- default (EXECUTE to PUBLIC) still applies. Guarded on to_regprocedure() so a
-- renamed or changed signature raises a notice instead of aborting the run.
--
-- Measured consequence (see the rollback matrix above): revoking PUBLIC also
-- removes service_role's EXECUTE on these two, because it held it through
-- PUBLIC and never had an explicit grant. That is intended and harmless - the
-- only callers are the SECURITY DEFINER public wrappers, which run as the
-- owner, and `family-admin` reaches them through public.request_device_recovery.
-- 71_phase1_rollback_privileges.sql pins both halves of that fact.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('private.remote_session_transition_guard()') is not null then
    execute 'revoke all on function private.remote_session_transition_guard() '
         || 'from public, anon, authenticated';
  else
    raise notice 'private.remote_session_transition_guard() not found; execute not revoked';
  end if;

  if to_regprocedure('private.request_device_recovery(uuid, uuid)') is not null then
    execute 'revoke all on function private.request_device_recovery(uuid, uuid) '
         || 'from public, anon, authenticated';
  else
    raise notice 'private.request_device_recovery(uuid, uuid) not found; execute not revoked';
  end if;
end;
$$;

-- The public wrapper still needs the private function: it is SECURITY DEFINER
-- and the owner keeps EXECUTE, so the revoke above does not break it.

-- ---------------------------------------------------------------------------
-- 8. Signaling replay hygiene: unique (session_id, sequence)
--
-- `sequence` is `generated always as identity`, so duplicates should not exist;
-- the guard makes the migration safe on a database that predates that column
-- default or where rows were imported. Duplicates are reported, never deleted.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from (
      select session_id, sequence
      from public.webrtc_signals
      group by 1, 2
      having count(*) > 1
    ) d
  ) then
    -- DDL inside a DO block must go through EXECUTE (plpgsql does not parse
    -- utility statements as static SQL).
    execute 'create unique index if not exists webrtc_signals_session_sequence_uniq '
         || 'on public.webrtc_signals (session_id, sequence)';
  else
    raise notice 'duplicate sequences exist; index skipped';
  end if;
end;
$$;

-- Note: the pre-existing non-unique index webrtc_signals_session_sequence_idx
-- (20260101000000_core.sql) is now redundant. It is intentionally left in place
-- so this migration stays additive; drop it in a later, owner-approved cleanup.