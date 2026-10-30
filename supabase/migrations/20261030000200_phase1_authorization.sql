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
-- Rollback (in reverse order; privileges are not restored by `create or replace`):
--   drop index if exists public.webrtc_signals_session_sequence_uniq;
--   grant execute on function private.remote_session_transition_guard() to public;
--   grant execute on function private.request_device_recovery(uuid, uuid) to public;
--   -- re-create the four public wrappers from 20261028000200 / 20260101000100;
--   revoke all on function private.is_parent_of_family(uuid, uuid) from service_role;
--   drop function if exists private.is_parent_of_family(uuid, uuid);
--   grant delete on public.safe_zones to authenticated;
--   create policy safe_zones_delete_parent on public.safe_zones
--     for delete to authenticated using (private.is_family_parent(family_id));

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