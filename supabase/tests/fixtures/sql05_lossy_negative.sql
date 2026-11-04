-- NEGATIVE CONTROL ONLY (SQL-05 lossy RPC variant).
-- Used by CHAIN-01 to verify that test 76 actively detects and fails against
-- an unaudited delete (the lossy two-transaction defect that SQL-05 fixes).
--
-- This file replaces the atomic public.delete_safe_zone_audited RPC with a
-- lossy version that catches and swallows any audit insertion failure while
-- keeping the zone deletion committed.
--
-- INJECTION POINT: Must be executed immediately BEFORE supabase/tests/76_zone_delete_atomic_rpc.sql.
-- Do NOT inject earlier: supabase/tests/71_phase1_rollback_privileges.sql (step 5)
-- re-applies migration 20261103000100_zone_delete_atomic_rpc.sql, which would silently
-- overwrite this negative variant with the atomic version.

\i supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql

create or replace function public.delete_safe_zone_audited(
  p_zone_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_family_id uuid;
  v_zone_name text;
  v_deleted   integer;
  v_audit_id  uuid;
begin
  if p_actor_user_id is null then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;
  if p_zone_id is null then
    raise exception 'zone_not_found' using errcode = 'P0001';
  end if;

  select sz.family_id, sz.name
    into v_family_id, v_zone_name
  from public.safe_zones sz
  where sz.id = p_zone_id
  for update;

  if v_family_id is null then
    raise exception 'zone_not_found' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.families f
    where f.id = v_family_id and f.deleted_at is null
  ) then
    raise exception 'family_unavailable' using errcode = '42501';
  end if;

  if not private.is_parent_of_family(p_actor_user_id, v_family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  delete from public.safe_zones
  where id = p_zone_id
    and family_id = v_family_id;
  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    return jsonb_build_object(
      'status', 'already_gone', 'zone_id', p_zone_id, 'audited', false
    );
  end if;

  -- THE LOSSY MUTATION: delete commits, but audit failure is swallowed.
  begin
    v_audit_id := private.record_audit(
      v_family_id, p_actor_user_id, null, 'zone_deleted', 'safe_zone',
      p_zone_id::text, jsonb_build_object('name', v_zone_name)
    );
  exception when others then
    return jsonb_build_object(
      'status', 'deleted', 'zone_id', p_zone_id, 'family_id', v_family_id,
      'audit_id', null, 'audited', false
    );
  end;

  return jsonb_build_object(
    'status', 'deleted', 'zone_id', p_zone_id, 'family_id', v_family_id,
    'audit_id', v_audit_id, 'audited', true
  );
end;
$$;
