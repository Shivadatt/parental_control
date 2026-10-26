-- Parent Control — internal RPCs, public service-only wrappers, realtime and cron.
-- Edge Functions run with the service role and call the public wrappers below;
-- the private implementations are the authoritative logic.

-- ---------------------------------------------------------------------------
-- audit helper
-- ---------------------------------------------------------------------------
create or replace function private.record_audit(
  p_family_id uuid,
  p_actor_user_id uuid,
  p_device_id uuid,
  p_event_type text,
  p_target_type text,
  p_target_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_id uuid;
begin
  if p_event_type is null or char_length(p_event_type) not between 1 and 80 then
    raise exception 'invalid audit event type' using errcode = '22023';
  end if;
  insert into public.audit_logs (
    family_id, actor_user_id, device_id, event_type,
    target_type, target_id, metadata
  )
  values (
    p_family_id, p_actor_user_id, p_device_id, p_event_type,
    p_target_type, p_target_id, coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- atomic family creation (family row + owner membership + audit)
-- ---------------------------------------------------------------------------
create or replace function private.create_family_with_owner(
  p_owner uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_family public.families;
begin
  if p_owner is null then
    raise exception 'owner_required' using errcode = '22023';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_family_name' using errcode = '22023';
  end if;

  insert into public.families (name, owner_id)
  values (btrim(p_name), p_owner)
  returning * into v_family;

  insert into public.family_members (family_id, user_id, role, status)
  values (v_family.id, p_owner, 'parent', 'active');

  perform private.record_audit(
    v_family.id, p_owner, null, 'family_created',
    'family', v_family.id::text,
    jsonb_build_object('name', v_family.name)
  );

  return to_jsonb(v_family);
exception
  when unique_violation then
    raise exception 'family_exists' using errcode = '23505';
end;
$$;

-- ---------------------------------------------------------------------------
-- atomic policy version + apply_policy command
-- ---------------------------------------------------------------------------
create or replace function private.apply_policy_version(
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
  v_device public.devices;
  v_existing public.device_commands;
  v_existing_policy public.device_policies;
  v_policy public.device_policies;
  v_command public.device_commands;
  v_version integer;
begin
  if p_device_id is null then
    raise exception 'device_required' using errcode = '22023';
  end if;
  if p_policy is null or jsonb_typeof(p_policy) <> 'object' then
    raise exception 'invalid_policy' using errcode = '22023';
  end if;
  if p_idempotency_key is null
     or char_length(p_idempotency_key) not between 1 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;

  -- Row lock serialises concurrent policy updates for one device.
  select * into v_device
  from public.devices
  where id = p_device_id
  for update;
  if not found then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;
  if v_device.status <> 'active' then
    raise exception 'device_not_active' using errcode = 'P0001';
  end if;

  select * into v_existing
  from public.device_commands
  where device_id = p_device_id
    and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.payload ? 'policy_id' then
      select * into v_existing_policy
      from public.device_policies
      where id = (v_existing.payload ->> 'policy_id')::uuid;
      if found then
        return jsonb_build_object(
          'policy', to_jsonb(v_existing_policy),
          'command', to_jsonb(v_existing),
          'idempotent', true
        );
      end if;
    end if;
  end if;

  select coalesce(max(version), 0) + 1
  into v_version
  from public.device_policies
  where device_id = p_device_id;

  insert into public.device_policies (
    device_id, family_id, version, policy, created_by
  )
  values (
    p_device_id, v_device.family_id, v_version, p_policy, p_actor
  )
  returning * into v_policy;

  insert into public.device_commands (
    device_id, family_id, type, payload, status,
    idempotency_key, created_by, expires_at
  )
  values (
    p_device_id, v_device.family_id, 'apply_policy',
    jsonb_build_object(
      'policy_id', v_policy.id,
      'version', v_policy.version,
      'policy', v_policy.policy
    ),
    'pending',
    p_idempotency_key,
    p_actor,
    now() + interval '900 seconds'
  )
  returning * into v_command;

  return jsonb_build_object(
    'policy', to_jsonb(v_policy),
    'command', to_jsonb(v_command),
    'idempotent', false
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- atomic pairing approval / rejection
-- ---------------------------------------------------------------------------
create or replace function private.respond_pairing_request(
  p_request_id uuid,
  p_child_user_id uuid,
  p_approve boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_request public.pairing_requests;
  v_token public.device_pairing_tokens;
  v_existing public.family_members;
begin
  if p_approve is null then
    raise exception 'invalid_response' using errcode = '22023';
  end if;

  select * into v_request
  from public.pairing_requests
  where id = p_request_id
  for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
  if v_request.child_user_id <> p_child_user_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_request.status <> 'pending_child' then
    if v_request.status = 'approved' and p_approve then
      return jsonb_build_object('status', 'approved', 'family_id', v_request.family_id);
    end if;
    if v_request.status = 'rejected' and not p_approve then
      return jsonb_build_object('status', 'rejected', 'family_id', v_request.family_id);
    end if;
    raise exception 'request_already_responded' using errcode = 'P0001';
  end if;
  if v_request.expires_at <= now() then
    raise exception 'code_expired' using errcode = 'P0001';
  end if;

  select * into v_token
  from public.device_pairing_tokens
  where id = v_request.token_id
  for update;
  if not found or v_token.status <> 'active' or v_token.expires_at <= now() then
    raise exception 'code_expired' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.family_members
    where family_id = v_request.family_id
      and user_id = v_request.parent_user_id
      and role = 'parent'
      and status = 'active'
  ) then
    raise exception 'request_unavailable' using errcode = 'P0001';
  end if;

  if p_approve then
    if exists (
      select 1 from public.family_members
      where user_id = p_child_user_id
        and role = 'child'
        and status = 'active'
    ) then
      raise exception 'child_already_linked' using errcode = '23505';
    end if;

    select * into v_existing
    from public.family_members
    where family_id = v_request.family_id
      and user_id = p_child_user_id
    for update;
    if found then
      if v_existing.status = 'active' then
        raise exception 'child_already_linked' using errcode = '23505';
      end if;
      update public.family_members
      set status = 'active', removed_at = null
      where id = v_existing.id;
    else
      insert into public.family_members (family_id, user_id, role, status)
      values (v_request.family_id, p_child_user_id, 'child', 'active');
    end if;

    update public.pairing_requests
    set status = 'approved', responded_at = now()
    where id = v_request.id;

    update public.device_pairing_tokens
    set status = 'redeemed', redeemed_at = now(), redeemed_by = v_request.parent_user_id
    where id = v_request.token_id;

    perform private.record_audit(
      v_request.family_id,
      p_child_user_id,
      null,
      'pairing_approved',
      'pairing_request',
      v_request.id::text,
      jsonb_build_object('parent_user_id', v_request.parent_user_id)
    );

    return jsonb_build_object('status', 'approved', 'family_id', v_request.family_id);
  end if;

  update public.pairing_requests
  set status = 'rejected', responded_at = now()
  where id = v_request.id;

  update public.device_pairing_tokens
  set status = 'revoked'
  where id = v_request.token_id;

  perform private.record_audit(
    v_request.family_id,
    p_child_user_id,
    null,
    'pairing_rejected',
    'pairing_request',
    v_request.id::text,
    jsonb_build_object('parent_user_id', v_request.parent_user_id)
  );

  return jsonb_build_object('status', 'rejected', 'family_id', v_request.family_id);
exception
  when unique_violation then
    raise exception 'child_already_linked' using errcode = '23505';
end;
$$;

-- ---------------------------------------------------------------------------
-- atomic unlink: membership + device credentials + sessions + tokens + audit
-- ---------------------------------------------------------------------------
create or replace function private.unlink_child(
  p_family_id uuid,
  p_child_user_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_membership public.family_members;
  v_devices integer := 0;
  v_sessions integer := 0;
begin
  if p_actor_user_id is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_actor_user_id <> p_child_user_id then
    if not exists (
      select 1 from public.family_members
      where family_id = p_family_id
        and user_id = p_actor_user_id
        and role = 'parent'
        and status = 'active'
    ) then
      raise exception 'forbidden' using errcode = '42501';
    end if;
  end if;

  select * into v_membership
  from public.family_members
  where family_id = p_family_id
    and user_id = p_child_user_id
    and role = 'child'
  for update;
  if not found then
    raise exception 'membership_not_found' using errcode = 'P0002';
  end if;
  if v_membership.status = 'removed' then
    return jsonb_build_object(
      'status', 'unlinked',
      'family_id', p_family_id,
      'child_user_id', p_child_user_id,
      'already_removed', true,
      'devices_revoked', 0,
      'sessions_ended', 0
    );
  end if;

  update public.family_members
  set status = 'removed', removed_at = now()
  where id = v_membership.id;

  update public.devices
  set status = 'revoked',
      secret_hash = null,
      credential_revoked_at = now()
  where family_id = p_family_id
    and child_user_id = p_child_user_id
    and status <> 'revoked';
  get diagnostics v_devices = row_count;

  update public.remote_sessions
  set status = 'ended',
      ended_at = now(),
      ended_by = p_actor_user_id,
      ended_reason = coalesce(ended_reason, 'member_unlinked')
  where family_id = p_family_id
    and child_user_id = p_child_user_id
    and status in ('requested', 'accepted', 'active');
  get diagnostics v_sessions = row_count;

  update public.device_pairing_tokens
  set status = 'revoked'
  where child_user_id = p_child_user_id
    and status = 'active';

  update public.pairing_requests
  set status = 'cancelled', responded_at = now()
  where child_user_id = p_child_user_id
    and status = 'pending_child';

  perform private.record_audit(
    p_family_id,
    p_actor_user_id,
    null,
    'member_removed',
    'family_member',
    v_membership.id::text,
    jsonb_build_object('child_user_id', p_child_user_id)
  );

  return jsonb_build_object(
    'status', 'unlinked',
    'family_id', p_family_id,
    'child_user_id', p_child_user_id,
    'already_removed', false,
    'devices_revoked', v_devices,
    'sessions_ended', v_sessions
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- atomic device revoke (credential nulled + sessions ended + audit)
-- ---------------------------------------------------------------------------
create or replace function private.revoke_device(
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
  v_sessions integer := 0;
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

  if v_device.status = 'revoked' then
    return to_jsonb(v_device) || jsonb_build_object('sessions_ended', 0);
  end if;

  update public.devices
  set status = 'revoked',
      secret_hash = null,
      credential_revoked_at = now()
  where id = v_device.id
  returning * into v_device;

  update public.remote_sessions
  set status = 'ended',
      ended_at = now(),
      ended_by = p_actor_user_id,
      ended_reason = coalesce(ended_reason, 'device_revoked')
  where device_id = v_device.id
    and status in ('requested', 'accepted', 'active');
  get diagnostics v_sessions = row_count;

  -- A request redeemed before the revocation must not be approvable after it;
  -- otherwise the child could re-enroll without a fresh parent re-link.
  update public.pairing_requests
  set status = 'cancelled', responded_at = now()
  where family_id = v_device.family_id
    and child_user_id = v_device.child_user_id
    and status = 'pending_child';

  perform private.record_audit(
    v_device.family_id,
    p_actor_user_id,
    v_device.id,
    'device_revoked',
    'device',
    v_device.id::text,
    jsonb_build_object('child_user_id', v_device.child_user_id)
  );

  return to_jsonb(v_device) || jsonb_build_object('sessions_ended', v_sessions);
end;
$$;

-- ---------------------------------------------------------------------------
-- cron helpers
-- ---------------------------------------------------------------------------
create or replace function private.expire_stale_sessions()
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_count integer;
begin
  update public.remote_sessions
  set status = 'expired',
      ended_at = coalesce(ended_at, now()),
      ended_reason = coalesce(ended_reason, 'expired')
  where status in ('requested', 'accepted', 'active')
    and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.detect_offline_devices()
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_count integer := 0;
  r record;
begin
  for r in
    select d.id, d.family_id, d.display_name, d.last_seen_at
    from public.devices d
    where d.status = 'active'
      and d.last_seen_at is not null
      and d.last_seen_at < now() - interval '15 minutes'
      and not exists (
        select 1
        from public.safety_alerts a
        where a.device_id = d.id
          and a.type = 'offline'
          and a.created_at > now() - interval '6 hours'
      )
  loop
    insert into public.safety_alerts (
      family_id, device_id, type, severity, message, payload
    )
    values (
      r.family_id,
      r.id,
      'offline',
      'warning',
      'Device has not reported for more than 15 minutes.',
      jsonb_build_object(
        'last_seen_at', r.last_seen_at,
        'threshold_minutes', 15
      )
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function private.expire_stale_commands(p_device_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_count integer;
begin
  update public.device_commands
  set status = 'expired'
  where device_id = p_device_id
    and status in ('pending', 'delivered')
    and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Atomic poll: expire stale rows, claim pending rows for this device only,
-- then return the device's outstanding delivered commands (max 20).
create or replace function private.poll_device_commands(
  p_device_id uuid,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_limit integer;
  v_result jsonb;
begin
  if p_device_id is null then
    raise exception 'device_required' using errcode = '22023';
  end if;
  v_limit := least(greatest(coalesce(p_limit, 20), 1), 20);

  update public.device_commands
  set status = 'expired'
  where device_id = p_device_id
    and status in ('pending', 'delivered')
    and expires_at <= now();

  with picked as (
    select c.id
    from public.device_commands c
    where c.device_id = p_device_id
      and c.status = 'pending'
      and c.expires_at > now()
    order by c.created_at asc
    limit v_limit
    for update skip locked
  )
  update public.device_commands c
  set status = 'delivered',
      delivered_at = now(),
      attempts = c.attempts + 1
  from picked
  where c.id = picked.id;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at), '[]'::jsonb)
  into v_result
  from (
    select *
    from public.device_commands
    where device_id = p_device_id
      and status = 'delivered'
      and expires_at > now()
    order by created_at asc
    limit v_limit
  ) c;

  return v_result;
end;
$$;

-- Replace a device's app snapshot atomically (delete + insert in one call).
create or replace function private.replace_device_apps(
  p_device_id uuid,
  p_family_id uuid,
  p_apps jsonb
)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_count integer;
begin
  if p_apps is null or jsonb_typeof(p_apps) <> 'array' then
    raise exception 'invalid_apps' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.devices
    where id = p_device_id and family_id = p_family_id
  ) then
    raise exception 'device_not_found' using errcode = 'P0002';
  end if;

  delete from public.device_apps where device_id = p_device_id;

  insert into public.device_apps (
    device_id, family_id, package_name, label,
    is_system, is_suspended, version_name, reported_at
  )
  select
    p_device_id,
    p_family_id,
    x.package_name,
    coalesce(x.label, x.package_name, ''),
    coalesce(x.is_system, false),
    coalesce(x.is_suspended, false),
    x.version_name,
    now()
  from jsonb_to_recordset(p_apps) as x(
    package_name text,
    label text,
    is_system boolean,
    is_suspended boolean,
    version_name text
  )
  where x.package_name is not null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Public service-only wrappers (PostgREST exposes the public schema only).
-- ---------------------------------------------------------------------------
create or replace function public.create_family_with_owner(
  p_owner uuid,
  p_name text
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.create_family_with_owner(p_owner, p_name);
$$;

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

create or replace function public.respond_pairing_request(
  p_request_id uuid,
  p_child_user_id uuid,
  p_approve boolean
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.respond_pairing_request(p_request_id, p_child_user_id, p_approve);
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

create or replace function public.expire_stale_sessions()
returns integer
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.expire_stale_sessions();
$$;

create or replace function public.detect_offline_devices()
returns integer
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.detect_offline_devices();
$$;

create or replace function public.expire_stale_commands(p_device_id uuid)
returns integer
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.expire_stale_commands(p_device_id);
$$;

create or replace function public.poll_device_commands(
  p_device_id uuid,
  p_limit integer default 20
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.poll_device_commands(p_device_id, p_limit);
$$;

create or replace function public.replace_device_apps(
  p_device_id uuid,
  p_family_id uuid,
  p_apps jsonb
)
returns integer
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.replace_device_apps(p_device_id, p_family_id, p_apps);
$$;

-- ---------------------------------------------------------------------------
-- Function privileges: service role only.
-- ---------------------------------------------------------------------------
revoke all on function private.record_audit(uuid, uuid, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
revoke all on function private.create_family_with_owner(uuid, text)
  from public, anon, authenticated;
revoke all on function private.apply_policy_version(uuid, jsonb, uuid, text)
  from public, anon, authenticated;
revoke all on function private.respond_pairing_request(uuid, uuid, boolean)
  from public, anon, authenticated;
revoke all on function private.unlink_child(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.revoke_device(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.expire_stale_sessions()
  from public, anon, authenticated;
revoke all on function private.detect_offline_devices()
  from public, anon, authenticated;
revoke all on function private.expire_stale_commands(uuid)
  from public, anon, authenticated;
revoke all on function private.poll_device_commands(uuid, integer)
  from public, anon, authenticated;
revoke all on function private.replace_device_apps(uuid, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function private.handle_new_user()
  from public, anon, authenticated;
revoke all on function private.set_updated_at()
  from public, anon, authenticated;
revoke all on function private.profiles_before_update()
  from public, anon, authenticated;
revoke all on function private.families_before_update()
  from public, anon, authenticated;
revoke all on function private.audit_logs_append_only()
  from public, anon, authenticated;

grant execute on function private.record_audit(uuid, uuid, uuid, text, text, text, jsonb)
  to service_role;
grant execute on function private.create_family_with_owner(uuid, text) to service_role;
grant execute on function private.apply_policy_version(uuid, jsonb, uuid, text) to service_role;
grant execute on function private.respond_pairing_request(uuid, uuid, boolean) to service_role;
grant execute on function private.unlink_child(uuid, uuid, uuid) to service_role;
grant execute on function private.revoke_device(uuid, uuid) to service_role;
grant execute on function private.expire_stale_sessions() to service_role;
grant execute on function private.detect_offline_devices() to service_role;
grant execute on function private.expire_stale_commands(uuid) to service_role;
grant execute on function private.poll_device_commands(uuid, integer) to service_role;
grant execute on function private.replace_device_apps(uuid, uuid, jsonb) to service_role;

revoke all on function public.create_family_with_owner(uuid, text)
  from public, anon, authenticated;
revoke all on function public.apply_policy_version(uuid, jsonb, uuid, text)
  from public, anon, authenticated;
revoke all on function public.respond_pairing_request(uuid, uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.unlink_child(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.revoke_device(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.expire_stale_sessions()
  from public, anon, authenticated;
revoke all on function public.detect_offline_devices()
  from public, anon, authenticated;
revoke all on function public.expire_stale_commands(uuid)
  from public, anon, authenticated;
revoke all on function public.poll_device_commands(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.replace_device_apps(uuid, uuid, jsonb)
  from public, anon, authenticated;

grant execute on function public.create_family_with_owner(uuid, text) to service_role;
grant execute on function public.apply_policy_version(uuid, jsonb, uuid, text) to service_role;
grant execute on function public.respond_pairing_request(uuid, uuid, boolean) to service_role;
grant execute on function public.unlink_child(uuid, uuid, uuid) to service_role;
grant execute on function public.revoke_device(uuid, uuid) to service_role;
grant execute on function public.expire_stale_sessions() to service_role;
grant execute on function public.detect_offline_devices() to service_role;
grant execute on function public.expire_stale_commands(uuid) to service_role;
grant execute on function public.poll_device_commands(uuid, integer) to service_role;
grant execute on function public.replace_device_apps(uuid, uuid, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Realtime publication (guarded so a plain PostgreSQL test run works).
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'device_commands'
    ) then
      execute 'alter publication supabase_realtime add table public.device_commands';
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'safety_alerts'
    ) then
      execute 'alter publication supabase_realtime add table public.safety_alerts';
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'remote_sessions'
    ) then
      execute 'alter publication supabase_realtime add table public.remote_sessions';
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'webrtc_signals'
    ) then
      execute 'alter publication supabase_realtime add table public.webrtc_signals';
    end if;
  else
    raise notice 'supabase_realtime publication not found; realtime tables not added';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- pg_cron schedule (guarded; documented manual alternative in docs/backend.md).
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute $cron$
      select cron.schedule(
        'parentcontrol-expire-sessions',
        '*/5 * * * *',
        'select private.expire_stale_sessions()'
      )
    $cron$;
    execute $cron$
      select cron.schedule(
        'parentcontrol-detect-offline',
        '*/10 * * * *',
        'select private.detect_offline_devices()'
      )
    $cron$;
  else
    raise notice 'pg_cron not installed; schedule private.expire_stale_sessions() and private.detect_offline_devices() manually';
  end if;
end;
$$;
