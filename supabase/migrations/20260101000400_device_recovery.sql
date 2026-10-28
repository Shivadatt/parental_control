-- Device credential recovery after app data loss or a lost phone.
--
-- A reinstalled child app has no local device secret, so it cannot heartbeat
-- and the old row keeps the partial unique index occupied. The only safe
-- replacement path is: an authenticated parent authorizes recovery, the old
-- credential is revoked and the family link removed, and the child completes a
-- fresh pairing (one-time code issued by the child, redeemed by the parent,
-- approved by the child) before a new device can register.
--
-- This wrapper reuses private.unlink_child so the revocation, session ending,
-- pairing-token invalidation and pending-request cancellation stay in one
-- transaction, and adds an explicit recovery audit event. No secret, token or
-- plaintext credential is written to the audit row.

create or replace function private.request_device_recovery(
  p_device_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_device public.devices;
  v_result jsonb;
begin
  select * into v_device
  from public.devices
  where id = p_device_id
  for update;
  if not found then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;

  if p_actor_user_id is null or not exists (
    select 1 from public.family_members
    where family_id = v_device.family_id
      and user_id = p_actor_user_id
      and role = 'parent'
      and status = 'active'
  ) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  v_result := private.unlink_child(
    v_device.family_id,
    v_device.child_user_id,
    p_actor_user_id
  );

  perform private.record_audit(
    v_device.family_id,
    p_actor_user_id,
    v_device.id,
    'device_recovery_started',
    'device',
    v_device.id::text,
    jsonb_build_object(
      'child_user_id', v_device.child_user_id,
      'devices_revoked', v_result ->> 'devices_revoked',
      'already_unlinked', coalesce((v_result ->> 'already_removed')::boolean, false)
    )
  );

  return v_result || jsonb_build_object(
    'recovery', 'started',
    'old_device_id', v_device.id
  );
end;
$$;

create or replace function public.request_device_recovery(
  p_device_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.request_device_recovery(p_device_id, p_actor_user_id);
$$;

revoke all on function public.request_device_recovery(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.request_device_recovery(uuid, uuid)
  to service_role;
