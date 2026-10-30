--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9
-- Dumped by pg_dump version 16.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- Name: private; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA private;


ALTER SCHEMA private OWNER TO postgres;

--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA realtime;


ALTER SCHEMA realtime OWNER TO postgres;

--
-- Name: tests; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tests;


ALTER SCHEMA tests OWNER TO postgres;

--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    'anon'
  );
$$;


ALTER FUNCTION auth.role() OWNER TO postgres;

--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;


ALTER FUNCTION auth.uid() OWNER TO postgres;

--
-- Name: apply_policy_version(uuid, jsonb, uuid, text); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) OWNER TO postgres;

--
-- Name: audit_logs_append_only(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.audit_logs_append_only() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
begin
  if tg_op in ('UPDATE', 'DELETE')
     and not (
       current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')
       or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
     ) then
    raise exception 'audit_logs is append-only' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;


ALTER FUNCTION private.audit_logs_append_only() OWNER TO postgres;

--
-- Name: create_family_with_owner(uuid, text); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.create_family_with_owner(p_owner uuid, p_name text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.create_family_with_owner(p_owner uuid, p_name text) OWNER TO postgres;

--
-- Name: detect_offline_devices(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.detect_offline_devices() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.detect_offline_devices() OWNER TO postgres;

--
-- Name: expire_stale_commands(uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.expire_stale_commands(p_device_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.expire_stale_commands(p_device_id uuid) OWNER TO postgres;

--
-- Name: expire_stale_sessions(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.expire_stale_sessions() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.expire_stale_sessions() OWNER TO postgres;

--
-- Name: families_before_update(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.families_before_update() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
begin
  if new.owner_id is distinct from old.owner_id
     and not (
       current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')
       or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
     ) then
    raise exception 'family owner is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;


ALTER FUNCTION private.families_before_update() OWNER TO postgres;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
declare
  v_name text;
begin
  v_name := left(
    coalesce(
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'User'
    ),
    60
  );
  if v_name is null or char_length(v_name) = 0 then
    v_name := 'User';
  end if;
  insert into public.profiles (id, role, display_name)
  values (new.id, 'unset', v_name)
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION private.handle_new_user() OWNER TO postgres;

--
-- Name: is_family_member(uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.is_family_member(p_family_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select exists (
    select 1
    from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;


ALTER FUNCTION private.is_family_member(p_family_id uuid) OWNER TO postgres;

--
-- Name: is_family_parent(uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.is_family_parent(p_family_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select exists (
    select 1
    from public.family_members m
    join public.families f on f.id = m.family_id
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.role = 'parent'
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;


ALTER FUNCTION private.is_family_parent(p_family_id uuid) OWNER TO postgres;

--
-- Name: poll_device_commands(uuid, integer); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.poll_device_commands(p_device_id uuid, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.poll_device_commands(p_device_id uuid, p_limit integer) OWNER TO postgres;

--
-- Name: profiles_before_update(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.profiles_before_update() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
begin
  if new.id is distinct from old.id then
    raise exception 'profile id is immutable' using errcode = '42501';
  end if;
  if new.role is distinct from old.role then
    if old.role <> 'unset'
       and not (
         current_user in ('service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin')
         or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
       ) then
      raise exception 'profile role is immutable' using errcode = '42501';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION private.profiles_before_update() OWNER TO postgres;

--
-- Name: realtime_topic_allowed(text); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.realtime_topic_allowed(p_topic text) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $_$
declare
  v_kind text;
  v_id text;
  v_uuid uuid;
begin
  if p_topic is null or p_topic = '' then
    return false;
  end if;
  v_kind := split_part(p_topic, ':', 1);
  v_id := split_part(p_topic, ':', 2);
  if v_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_uuid := v_id::uuid;

  if v_kind in ('safety-alerts', 'remote-session-family') then
    return private.is_family_member(v_uuid);
  end if;

  if v_kind in ('remote-session', 'webrtc-signals') then
    return exists (
      select 1
      from public.remote_sessions s
      where s.id = v_uuid
        and (s.child_user_id = auth.uid() or private.is_family_parent(s.family_id))
    );
  end if;

  return false;
end;
$_$;


ALTER FUNCTION private.realtime_topic_allowed(p_topic text) OWNER TO postgres;

--
-- Name: record_audit(uuid, uuid, uuid, text, text, text, jsonb); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.record_audit(p_family_id uuid, p_actor_user_id uuid, p_device_id uuid, p_event_type text, p_target_type text, p_target_id text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.record_audit(p_family_id uuid, p_actor_user_id uuid, p_device_id uuid, p_event_type text, p_target_type text, p_target_id text, p_metadata jsonb) OWNER TO postgres;

--
-- Name: replace_device_apps(uuid, uuid, jsonb); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) OWNER TO postgres;

--
-- Name: respond_pairing_request(uuid, uuid, boolean); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) OWNER TO postgres;

--
-- Name: revoke_device(uuid, uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.revoke_device(p_device_id uuid, p_actor_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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
    return (to_jsonb(v_device) - 'installation_id' - 'secret_hash')
      || jsonb_build_object('sessions_ended', 0);
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

  -- installation_id and secret_hash are service-only. The parent UI does not
  -- use them, and this RPC response is relayed to the parent by family-admin.
  return (to_jsonb(v_device) - 'installation_id' - 'secret_hash')
    || jsonb_build_object('sessions_ended', v_sessions);
end;
$$;


ALTER FUNCTION private.revoke_device(p_device_id uuid, p_actor_user_id uuid) OWNER TO postgres;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION private.set_updated_at() OWNER TO postgres;

--
-- Name: shares_active_family(uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.shares_active_family(p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select exists (
    select 1
    from public.family_members mine
    join public.family_members theirs on theirs.family_id = mine.family_id
    join public.families f on f.id = mine.family_id
    where mine.user_id = auth.uid()
      and theirs.user_id = p_user_id
      and mine.status = 'active'
      and theirs.status = 'active'
      and f.deleted_at is null
  );
$$;


ALTER FUNCTION private.shares_active_family(p_user_id uuid) OWNER TO postgres;

--
-- Name: unlink_child(uuid, uuid, uuid); Type: FUNCTION; Schema: private; Owner: postgres
--

CREATE FUNCTION private.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
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


ALTER FUNCTION private.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) OWNER TO postgres;

--
-- Name: apply_policy_version(uuid, jsonb, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.apply_policy_version(p_device_id, p_policy, p_actor, p_idempotency_key);
$$;


ALTER FUNCTION public.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) OWNER TO postgres;

--
-- Name: create_family_with_owner(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_family_with_owner(p_owner uuid, p_name text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.create_family_with_owner(p_owner, p_name);
$$;


ALTER FUNCTION public.create_family_with_owner(p_owner uuid, p_name text) OWNER TO postgres;

--
-- Name: detect_offline_devices(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.detect_offline_devices() RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.detect_offline_devices();
$$;


ALTER FUNCTION public.detect_offline_devices() OWNER TO postgres;

--
-- Name: expire_stale_commands(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.expire_stale_commands(p_device_id uuid) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.expire_stale_commands(p_device_id);
$$;


ALTER FUNCTION public.expire_stale_commands(p_device_id uuid) OWNER TO postgres;

--
-- Name: expire_stale_sessions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.expire_stale_sessions() RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.expire_stale_sessions();
$$;


ALTER FUNCTION public.expire_stale_sessions() OWNER TO postgres;

--
-- Name: poll_device_commands(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.poll_device_commands(p_device_id uuid, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.poll_device_commands(p_device_id, p_limit);
$$;


ALTER FUNCTION public.poll_device_commands(p_device_id uuid, p_limit integer) OWNER TO postgres;

--
-- Name: replace_device_apps(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.replace_device_apps(p_device_id, p_family_id, p_apps);
$$;


ALTER FUNCTION public.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) OWNER TO postgres;

--
-- Name: respond_pairing_request(uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.respond_pairing_request(p_request_id, p_child_user_id, p_approve);
$$;


ALTER FUNCTION public.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) OWNER TO postgres;

--
-- Name: revoke_device(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.revoke_device(p_device_id uuid, p_actor_user_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.revoke_device(p_device_id, p_actor_user_id);
$$;


ALTER FUNCTION public.revoke_device(p_device_id uuid, p_actor_user_id uuid) OWNER TO postgres;

--
-- Name: unlink_child(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'private', 'pg_temp'
    AS $$
  select private.unlink_child(p_family_id, p_child_user_id, p_actor_user_id);
$$;


ALTER FUNCTION public.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) OWNER TO postgres;

--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: postgres
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select nullif(current_setting('realtime.topic', true), '');
$$;


ALTER FUNCTION realtime.topic() OWNER TO postgres;

--
-- Name: assert_true(boolean, text); Type: FUNCTION; Schema: tests; Owner: postgres
--

CREATE FUNCTION tests.assert_true(p_condition boolean, p_label text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  if p_condition is not true then
    raise exception 'ASSERTION FAILED: %', p_label;
  end if;
end;
$$;


ALTER FUNCTION tests.assert_true(p_condition boolean, p_label text) OWNER TO postgres;

--
-- Name: expect_error(text, text, text, text); Type: FUNCTION; Schema: tests; Owner: postgres
--

CREATE FUNCTION tests.expect_error(p_sql text, p_state text, p_message text, p_label text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if p_state is not null and sqlstate <> p_state then
        raise exception
          'ASSERTION FAILED (%): expected SQLSTATE %, got % (%)',
          p_label, p_state, sqlstate, sqlerrm;
      end if;
      if p_message is not null
         and position(lower(p_message) in lower(sqlerrm)) = 0 then
        raise exception
          'ASSERTION FAILED (%): expected message containing %, got %',
          p_label, p_message, sqlerrm;
      end if;
      return;
  end;
  raise exception 'ASSERTION FAILED (%): expected error, statement succeeded', p_label;
end;
$$;


ALTER FUNCTION tests.expect_error(p_sql text, p_state text, p_message text, p_label text) OWNER TO postgres;

--
-- Name: fk_columns(regclass, regclass); Type: FUNCTION; Schema: tests; Owner: postgres
--

CREATE FUNCTION tests.fk_columns(p_table regclass, p_ref regclass) RETURNS text[]
    LANGUAGE sql STABLE
    AS $$
  select coalesce(array_agg(a.attname order by a.attname), '{}'::text[])
  from pg_constraint c
  join unnest(c.conkey) as k(attnum) on true
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
  where c.contype = 'f'
    and c.conrelid = p_table
    and c.confrelid = p_ref;
$$;


ALTER FUNCTION tests.fk_columns(p_table regclass, p_ref regclass) OWNER TO postgres;

--
-- Name: get(text); Type: FUNCTION; Schema: tests; Owner: postgres
--

CREATE FUNCTION tests.get(p_key text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select value from tests.state where key = p_key;
$$;


ALTER FUNCTION tests.get(p_key text) OWNER TO postgres;

--
-- Name: put(text, text); Type: FUNCTION; Schema: tests; Owner: postgres
--

CREATE FUNCTION tests.put(p_key text, p_value text) RETURNS text
    LANGUAGE sql
    AS $$
  insert into tests.state (key, value)
  values (p_key, p_value)
  on conflict (key) do update set value = excluded.value
  returning value;
$$;


ALTER FUNCTION tests.put(p_key text, p_value text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.users (
    id uuid NOT NULL,
    email text,
    email_confirmed_at timestamp with time zone,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.users OWNER TO postgres;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid,
    actor_user_id uuid,
    device_id uuid,
    event_type text NOT NULL,
    target_type text,
    target_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT audit_logs_event_type_check CHECK (((char_length(event_type) >= 1) AND (char_length(event_type) <= 80))),
    CONSTRAINT audit_logs_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT audit_logs_target_id_check CHECK (((target_id IS NULL) OR (char_length(target_id) <= 128))),
    CONSTRAINT audit_logs_target_type_check CHECK (((target_type IS NULL) OR (char_length(target_type) <= 40)))
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- Name: device_apps; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_apps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    family_id uuid NOT NULL,
    package_name text NOT NULL,
    label text DEFAULT ''::text NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    is_suspended boolean DEFAULT false NOT NULL,
    version_name text,
    reported_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT device_apps_label_check CHECK ((char_length(label) <= 100)),
    CONSTRAINT device_apps_package_name_check CHECK (((char_length(package_name) >= 1) AND (char_length(package_name) <= 150))),
    CONSTRAINT device_apps_version_name_check CHECK (((version_name IS NULL) OR (char_length(version_name) <= 64)))
);


ALTER TABLE public.device_apps OWNER TO postgres;

--
-- Name: device_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_commands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    family_id uuid NOT NULL,
    type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    idempotency_key text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    delivered_at timestamp with time zone,
    acked_at timestamp with time zone,
    result jsonb,
    error_message text,
    attempts integer DEFAULT 0 NOT NULL,
    CONSTRAINT device_commands_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT device_commands_error_message_check CHECK (((error_message IS NULL) OR (char_length(error_message) <= 500))),
    CONSTRAINT device_commands_idempotency_key_check CHECK (((char_length(idempotency_key) >= 1) AND (char_length(idempotency_key) <= 128))),
    CONSTRAINT device_commands_payload_check CHECK ((jsonb_typeof(payload) = 'object'::text)),
    CONSTRAINT device_commands_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'delivered'::text, 'succeeded'::text, 'failed'::text, 'expired'::text]))),
    CONSTRAINT device_commands_type_check CHECK ((type = ANY (ARRAY['apply_policy'::text, 'sync_policy'::text, 'request_usage'::text, 'request_location'::text, 'end_session'::text, 'custom'::text])))
);


ALTER TABLE public.device_commands OWNER TO postgres;

--
-- Name: device_pairing_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_pairing_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    child_user_id uuid NOT NULL,
    code_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    redeemed_at timestamp with time zone,
    redeemed_by uuid,
    status text DEFAULT 'active'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 10 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT device_pairing_tokens_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT device_pairing_tokens_code_hash_check CHECK ((code_hash ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT device_pairing_tokens_max_attempts_check CHECK ((max_attempts > 0)),
    CONSTRAINT device_pairing_tokens_status_check CHECK ((status = ANY (ARRAY['active'::text, 'redeemed'::text, 'revoked'::text, 'expired'::text])))
);


ALTER TABLE public.device_pairing_tokens OWNER TO postgres;

--
-- Name: device_policies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    family_id uuid NOT NULL,
    version integer NOT NULL,
    policy jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    acknowledged_at timestamp with time zone,
    enforcement_status text DEFAULT 'pending'::text NOT NULL,
    last_error text,
    CONSTRAINT device_policies_enforcement_status_check CHECK ((enforcement_status = ANY (ARRAY['pending'::text, 'enforced'::text, 'failed'::text, 'unsupported'::text]))),
    CONSTRAINT device_policies_last_error_check CHECK (((last_error IS NULL) OR (char_length(last_error) <= 500))),
    CONSTRAINT device_policies_policy_check CHECK ((jsonb_typeof(policy) = 'object'::text)),
    CONSTRAINT device_policies_version_check CHECK ((version >= 1))
);


ALTER TABLE public.device_policies OWNER TO postgres;

--
-- Name: devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    child_user_id uuid NOT NULL,
    installation_id text NOT NULL,
    display_name text NOT NULL,
    platform text DEFAULT 'android'::text NOT NULL,
    android_version text,
    app_version text,
    status text DEFAULT 'pending'::text NOT NULL,
    secret_hash text,
    credential_issued_at timestamp with time zone,
    credential_revoked_at timestamp with time zone,
    last_seen_at timestamp with time zone,
    battery_level integer,
    is_charging boolean,
    enforcement_mode text DEFAULT 'none'::text NOT NULL,
    policy_version integer DEFAULT 0 NOT NULL,
    usage_access_granted boolean,
    location_granted boolean,
    background_location_granted boolean,
    camera_granted boolean,
    microphone_granted boolean,
    notifications_granted boolean,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT devices_android_version_check CHECK (((android_version IS NULL) OR ((char_length(android_version) >= 1) AND (char_length(android_version) <= 40)))),
    CONSTRAINT devices_app_version_check CHECK (((app_version IS NULL) OR ((char_length(app_version) >= 1) AND (char_length(app_version) <= 40)))),
    CONSTRAINT devices_battery_level_check CHECK (((battery_level >= 0) AND (battery_level <= 100))),
    CONSTRAINT devices_display_name_check CHECK (((char_length(display_name) >= 1) AND (char_length(display_name) <= 80))),
    CONSTRAINT devices_enforcement_mode_check CHECK ((enforcement_mode = ANY (ARRAY['none'::text, 'device_admin'::text, 'device_owner'::text]))),
    CONSTRAINT devices_installation_id_check CHECK (((char_length(installation_id) >= 8) AND (char_length(installation_id) <= 128))),
    CONSTRAINT devices_platform_check CHECK (((char_length(platform) >= 1) AND (char_length(platform) <= 32))),
    CONSTRAINT devices_policy_version_check CHECK ((policy_version >= 0)),
    CONSTRAINT devices_revoked_credential_consistency CHECK (((status <> 'revoked'::text) OR (secret_hash IS NULL))),
    CONSTRAINT devices_secret_hash_check CHECK (((secret_hash IS NULL) OR (secret_hash ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT devices_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'revoked'::text])))
);


ALTER TABLE public.devices OWNER TO postgres;

--
-- Name: families; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.families (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    owner_id uuid NOT NULL,
    settings jsonb DEFAULT '{"usage_retention_days": 90, "location_retention_days": 30}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT families_name_check CHECK (((char_length(name) >= 1) AND (char_length(name) <= 80))),
    CONSTRAINT families_settings_check CHECK ((jsonb_typeof(settings) = 'object'::text))
);


ALTER TABLE public.families OWNER TO postgres;

--
-- Name: TABLE families; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.families IS 'A family owned by exactly one parent account. Soft-deleted with deleted_at.';


--
-- Name: family_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.family_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    removed_at timestamp with time zone,
    CONSTRAINT family_members_removed_consistency CHECK (((status = 'removed'::text) = (removed_at IS NOT NULL))),
    CONSTRAINT family_members_role_check CHECK ((role = ANY (ARRAY['parent'::text, 'child'::text]))),
    CONSTRAINT family_members_status_check CHECK ((status = ANY (ARRAY['active'::text, 'removed'::text])))
);


ALTER TABLE public.family_members OWNER TO postgres;

--
-- Name: location_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.location_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    family_id uuid NOT NULL,
    lat double precision NOT NULL,
    lng double precision NOT NULL,
    accuracy_m real NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    source text DEFAULT 'device'::text NOT NULL,
    CONSTRAINT location_events_accuracy_m_check CHECK ((accuracy_m >= (0)::double precision)),
    CONSTRAINT location_events_lat_check CHECK (((lat >= ('-90'::integer)::double precision) AND (lat <= (90)::double precision))),
    CONSTRAINT location_events_lng_check CHECK (((lng >= ('-180'::integer)::double precision) AND (lng <= (180)::double precision))),
    CONSTRAINT location_events_source_check CHECK (((char_length(source) >= 1) AND (char_length(source) <= 40)))
);


ALTER TABLE public.location_events OWNER TO postgres;

--
-- Name: pairing_attempts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pairing_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_user_id uuid NOT NULL,
    code_hash text NOT NULL,
    attempted_at timestamp with time zone DEFAULT now() NOT NULL,
    success boolean DEFAULT false NOT NULL,
    CONSTRAINT pairing_attempts_code_hash_check CHECK ((code_hash ~ '^[0-9a-f]{64}$'::text))
);


ALTER TABLE public.pairing_attempts OWNER TO postgres;

--
-- Name: pairing_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pairing_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    token_id uuid NOT NULL,
    family_id uuid NOT NULL,
    parent_user_id uuid NOT NULL,
    child_user_id uuid NOT NULL,
    status text DEFAULT 'pending_child'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    responded_at timestamp with time zone,
    CONSTRAINT pairing_requests_status_check CHECK ((status = ANY (ARRAY['pending_child'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text, 'expired'::text])))
);


ALTER TABLE public.pairing_requests OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    role text DEFAULT 'unset'::text NOT NULL,
    display_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_display_name_check CHECK (((char_length(display_name) >= 1) AND (char_length(display_name) <= 60))),
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['unset'::text, 'parent'::text, 'child'::text])))
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: TABLE profiles; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.profiles IS 'Application profile. Created by trigger on auth.users; role is set once by an Edge Function.';


--
-- Name: remote_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.remote_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    device_id uuid NOT NULL,
    parent_user_id uuid NOT NULL,
    child_user_id uuid NOT NULL,
    kind text NOT NULL,
    status text DEFAULT 'requested'::text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    ended_by uuid,
    ended_reason text,
    consent_recorded boolean DEFAULT false NOT NULL,
    session_nonce uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT remote_sessions_ended_reason_check CHECK (((ended_reason IS NULL) OR (char_length(ended_reason) <= 200))),
    CONSTRAINT remote_sessions_kind_check CHECK ((kind = ANY (ARRAY['audio'::text, 'video'::text]))),
    CONSTRAINT remote_sessions_status_check CHECK ((status = ANY (ARRAY['requested'::text, 'accepted'::text, 'active'::text, 'declined'::text, 'ended'::text, 'expired'::text, 'failed'::text])))
);


ALTER TABLE public.remote_sessions OWNER TO postgres;

--
-- Name: safe_zone_states; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.safe_zone_states (
    zone_id uuid NOT NULL,
    device_id uuid NOT NULL,
    inside boolean NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.safe_zone_states OWNER TO postgres;

--
-- Name: safe_zones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.safe_zones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name text NOT NULL,
    lat double precision NOT NULL,
    lng double precision NOT NULL,
    radius_m double precision NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT safe_zones_lat_check CHECK (((lat >= ('-90'::integer)::double precision) AND (lat <= (90)::double precision))),
    CONSTRAINT safe_zones_lng_check CHECK (((lng >= ('-180'::integer)::double precision) AND (lng <= (180)::double precision))),
    CONSTRAINT safe_zones_name_check CHECK (((char_length(name) >= 1) AND (char_length(name) <= 60))),
    CONSTRAINT safe_zones_radius_m_check CHECK (((radius_m >= (50)::double precision) AND (radius_m <= (5000)::double precision)))
);


ALTER TABLE public.safe_zones OWNER TO postgres;

--
-- Name: safety_alerts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.safety_alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    device_id uuid NOT NULL,
    type text NOT NULL,
    severity text NOT NULL,
    message text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    acknowledged_at timestamp with time zone,
    acknowledged_by uuid,
    CONSTRAINT safety_alerts_message_check CHECK (((char_length(message) >= 1) AND (char_length(message) <= 300))),
    CONSTRAINT safety_alerts_payload_check CHECK ((jsonb_typeof(payload) = 'object'::text)),
    CONSTRAINT safety_alerts_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text]))),
    CONSTRAINT safety_alerts_type_check CHECK ((type = ANY (ARRAY['low_battery'::text, 'offline'::text, 'geofence_enter'::text, 'geofence_exit'::text, 'app_blocked'::text, 'permission_missing'::text, 'other'::text])))
);


ALTER TABLE public.safety_alerts OWNER TO postgres;

--
-- Name: usage_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usage_daily (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_id uuid NOT NULL,
    family_id uuid NOT NULL,
    day date NOT NULL,
    package_name text NOT NULL,
    app_label text DEFAULT ''::text NOT NULL,
    total_ms bigint NOT NULL,
    last_used_at timestamp with time zone,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    source text DEFAULT 'usage_stats'::text NOT NULL,
    CONSTRAINT usage_daily_app_label_check CHECK ((char_length(app_label) <= 100)),
    CONSTRAINT usage_daily_package_name_check CHECK (((char_length(package_name) >= 1) AND (char_length(package_name) <= 150))),
    CONSTRAINT usage_daily_source_check CHECK (((char_length(source) >= 1) AND (char_length(source) <= 32))),
    CONSTRAINT usage_daily_total_ms_check CHECK ((total_ms >= 0))
);


ALTER TABLE public.usage_daily OWNER TO postgres;

--
-- Name: webrtc_signals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.webrtc_signals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    from_user_id uuid DEFAULT auth.uid() NOT NULL,
    kind text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sequence bigint NOT NULL,
    CONSTRAINT webrtc_signals_kind_check CHECK ((kind = ANY (ARRAY['offer'::text, 'answer'::text, 'ice'::text]))),
    CONSTRAINT webrtc_signals_payload_check CHECK ((octet_length((payload)::text) <= 16384))
);


ALTER TABLE public.webrtc_signals OWNER TO postgres;

--
-- Name: webrtc_signals_sequence_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.webrtc_signals ALTER COLUMN sequence ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.webrtc_signals_sequence_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: postgres
--

CREATE TABLE realtime.messages (
    id bigint NOT NULL,
    inserted_at timestamp with time zone DEFAULT now() NOT NULL,
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT true NOT NULL
);


ALTER TABLE realtime.messages OWNER TO postgres;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: realtime; Owner: postgres
--

CREATE SEQUENCE realtime.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE realtime.messages_id_seq OWNER TO postgres;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: realtime; Owner: postgres
--

ALTER SEQUENCE realtime.messages_id_seq OWNED BY realtime.messages.id;


--
-- Name: state; Type: TABLE; Schema: tests; Owner: postgres
--

CREATE TABLE tests.state (
    key text NOT NULL,
    value text NOT NULL
);


ALTER TABLE tests.state OWNER TO postgres;

--
-- Name: messages id; Type: DEFAULT; Schema: realtime; Owner: postgres
--

ALTER TABLE ONLY realtime.messages ALTER COLUMN id SET DEFAULT nextval('realtime.messages_id_seq'::regclass);


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at) FROM stdin;
11111111-1111-4111-8111-111111111111	parent1@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Parent One"}	2026-10-26 23:53:40.950732+05:30
22222222-2222-4222-8222-222222222222	parent2@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Parent Two"}	2026-10-26 23:53:40.950732+05:30
55555555-5555-4555-8555-555555555555	parent3@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Parent Three"}	2026-10-26 23:53:40.950732+05:30
33333333-3333-4333-8333-333333333333	child1@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Child One"}	2026-10-26 23:53:40.950732+05:30
44444444-4444-4444-8444-444444444444	child2@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Child Two"}	2026-10-26 23:53:40.950732+05:30
66666666-6666-4666-8666-666666666666	child3@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Child Three"}	2026-10-26 23:53:40.950732+05:30
77777777-7777-4777-8777-777777777777	child4@example.test	2026-10-26 23:53:40.950732+05:30	{"display_name": "Child Four"}	2026-10-26 23:53:40.950732+05:30
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (id, family_id, actor_user_id, device_id, event_type, target_type, target_id, metadata, created_at) FROM stdin;
ae6762eb-20d6-4c97-a25d-7234e2b041e6	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	\N	family_created	family	8b733f0b-172f-4cc4-830e-9fb6498c22b6	{"name": "Family One"}	2026-10-26 23:53:40.958477+05:30
365deedc-5f47-4082-9ce7-e82898e33281	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	22222222-2222-4222-8222-222222222222	\N	family_created	family	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	{"name": "Family Two"}	2026-10-26 23:53:40.973294+05:30
4c33bb1f-1a7e-4196-be29-301371995c7e	8b733f0b-172f-4cc4-830e-9fb6498c22b6	66666666-6666-4666-8666-666666666666	\N	pairing_approved	pairing_request	20000000-0000-4000-8000-000000000001	{"parent_user_id": "11111111-1111-4111-8111-111111111111"}	2026-10-26 23:53:41.143703+05:30
4666f0e3-b154-43aa-99a3-1c4ca29cc04d	8b733f0b-172f-4cc4-830e-9fb6498c22b6	77777777-7777-4777-8777-777777777777	\N	pairing_rejected	pairing_request	20000000-0000-4000-8000-000000000003	{"parent_user_id": "11111111-1111-4111-8111-111111111111"}	2026-10-26 23:53:41.143703+05:30
402092cf-8512-4e8c-b4a4-678e494501a5	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	\N	member_removed	family_member	19cbe70f-c2cb-4ca7-8abd-6531ddc7cc7b	{"child_user_id": "77777777-7777-4777-8777-777777777777"}	2026-10-26 23:53:41.143703+05:30
01b743bd-0339-482e-902c-3bc30e92f1a0	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	d0000000-0000-4000-8000-000000000007	device_revoked	device	d0000000-0000-4000-8000-000000000007	{"child_user_id": "66666666-6666-4666-8666-666666666666"}	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: device_apps; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_apps (id, device_id, family_id, package_name, label, is_system, is_suspended, version_name, reported_at) FROM stdin;
dce2c790-7672-4532-be29-3ba3a7e1a23a	d0000000-0000-4000-8000-000000000002	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	com.example.other	Other App	f	f	\N	2026-10-26 23:53:41.011051+05:30
d19e0195-26ac-4ad7-b44e-a4d6ef7b80e8	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	com.example.new	New App	f	f	2.1	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: device_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_commands (id, device_id, family_id, type, payload, status, idempotency_key, created_by, created_at, expires_at, delivered_at, acked_at, result, error_message, attempts) FROM stdin;
7d0771ba-d2a1-42f1-b0f8-cccae318c41f	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	apply_policy	{"policy": {"app_rules": [], "allowed_packages": [], "blocked_packages": ["com.example.blocked"], "enforce_app_blocks": true, "bedtime_end_minutes": 420, "bedtime_start_minutes": 1200, "block_all_except_allowed": false, "daily_screen_time_limit_minutes": 120}, "version": 1, "policy_id": "25ce1ada-7738-473e-a3c2-29b0460500a5"}	pending	fixture-policy-key-1	11111111-1111-4111-8111-111111111111	2026-10-26 23:53:40.98742+05:30	2026-10-27 00:08:40.98742+05:30	\N	\N	\N	\N	0
6c5e8f8f-4c86-4e68-93ab-a0a300416295	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	apply_policy	{"policy": {"blocked_packages": ["com.example.blocked"], "enforce_app_blocks": false}, "version": 2, "policy_id": "80613054-456e-4f40-867b-dde3909cbd34"}	pending	test-policy-key-2	11111111-1111-4111-8111-111111111111	2026-10-26 23:53:41.143703+05:30	2026-10-27 00:08:41.143703+05:30	\N	\N	\N	\N	0
c0000000-0000-4000-8000-000000000102	d0000000-0000-4000-8000-000000000007	8b733f0b-172f-4cc4-830e-9fb6498c22b6	sync_policy	{"reason": "expired"}	expired	fixture-cmd-expired	11111111-1111-4111-8111-111111111111	2026-10-26 23:51:40.999009+05:30	2026-10-26 23:52:40.999009+05:30	\N	\N	\N	\N	0
c0000000-0000-4000-8000-000000000101	d0000000-0000-4000-8000-000000000007	8b733f0b-172f-4cc4-830e-9fb6498c22b6	sync_policy	{"reason": "fixture"}	delivered	fixture-cmd-valid	11111111-1111-4111-8111-111111111111	2026-10-26 23:52:40.999009+05:30	2026-10-27 00:03:40.999009+05:30	2026-10-26 23:53:41.143703+05:30	\N	\N	\N	1
\.


--
-- Data for Name: device_pairing_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_pairing_tokens (id, child_user_id, code_hash, expires_at, redeemed_at, redeemed_by, status, attempts, max_attempts, created_at, created_by) FROM stdin;
10000000-0000-4000-8000-000000000002	66666666-6666-4666-8666-666666666666	dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd	2026-10-27 00:03:41.034776+05:30	\N	\N	active	0	10	2026-10-26 23:53:41.034776+05:30	66666666-6666-4666-8666-666666666666
10000000-0000-4000-8000-000000000004	66666666-6666-4666-8666-666666666666	8888888888888888888888888888888888888888888888888888888888888888	2026-10-26 23:43:41.034776+05:30	\N	\N	active	0	10	2026-10-26 23:53:41.034776+05:30	66666666-6666-4666-8666-666666666666
10000000-0000-4000-8000-000000000001	66666666-6666-4666-8666-666666666666	cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc	2026-10-27 00:03:41.034776+05:30	2026-10-26 23:53:41.143703+05:30	11111111-1111-4111-8111-111111111111	redeemed	0	10	2026-10-26 23:53:41.034776+05:30	66666666-6666-4666-8666-666666666666
10000000-0000-4000-8000-000000000003	77777777-7777-4777-8777-777777777777	9999999999999999999999999999999999999999999999999999999999999999	2026-10-27 00:03:41.034776+05:30	\N	\N	revoked	0	10	2026-10-26 23:53:41.034776+05:30	77777777-7777-4777-8777-777777777777
10000000-0000-4000-8000-000000000005	77777777-7777-4777-8777-777777777777	7777777777777777777777777777777777777777777777777777777777777777	2026-10-27 00:03:41.143703+05:30	\N	\N	revoked	0	10	2026-10-26 23:53:41.143703+05:30	77777777-7777-4777-8777-777777777777
10000000-0000-4000-8000-000000000008	66666666-6666-4666-8666-666666666666	ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff	2026-10-27 00:03:41.143703+05:30	\N	\N	active	0	10	2026-10-26 23:53:41.143703+05:30	66666666-6666-4666-8666-666666666666
\.


--
-- Data for Name: device_policies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_policies (id, device_id, family_id, version, policy, created_by, created_at, acknowledged_at, enforcement_status, last_error) FROM stdin;
25ce1ada-7738-473e-a3c2-29b0460500a5	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	1	{"app_rules": [], "allowed_packages": [], "blocked_packages": ["com.example.blocked"], "enforce_app_blocks": true, "bedtime_end_minutes": 420, "bedtime_start_minutes": 1200, "block_all_except_allowed": false, "daily_screen_time_limit_minutes": 120}	11111111-1111-4111-8111-111111111111	2026-10-26 23:53:40.98742+05:30	\N	pending	\N
80613054-456e-4f40-867b-dde3909cbd34	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	2	{"blocked_packages": ["com.example.blocked"], "enforce_app_blocks": false}	11111111-1111-4111-8111-111111111111	2026-10-26 23:53:41.143703+05:30	\N	pending	\N
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.devices (id, family_id, child_user_id, installation_id, display_name, platform, android_version, app_version, status, secret_hash, credential_issued_at, credential_revoked_at, last_seen_at, battery_level, is_charging, enforcement_mode, policy_version, usage_access_granted, location_granted, background_location_granted, camera_granted, microphone_granted, notifications_granted, created_at, updated_at) FROM stdin;
d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	33333333-3333-4333-8333-333333333333	install-c1-0001	Child One Phone	android	\N	\N	active	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	2026-10-24 23:53:40.978376+05:30	\N	2026-10-26 23:53:40.978376+05:30	\N	\N	device_admin	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:40.978376+05:30
d0000000-0000-4000-8000-000000000002	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	44444444-4444-4444-8444-444444444444	install-c2-0002	Child Two Phone	android	\N	\N	active	bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb	2026-10-25 23:53:40.978376+05:30	\N	2026-10-26 23:53:40.978376+05:30	\N	\N	device_admin	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:40.978376+05:30
d0000000-0000-4000-8000-000000000003	8b733f0b-172f-4cc4-830e-9fb6498c22b6	33333333-3333-4333-8333-333333333333	install-c1-old3	Child One Old Phone	android	\N	\N	revoked	\N	2026-09-26 23:53:40.978376+05:30	2026-10-25 23:53:40.978376+05:30	2026-10-24 23:53:40.978376+05:30	\N	\N	none	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:40.978376+05:30
d0000000-0000-4000-8000-000000000004	8b733f0b-172f-4cc4-830e-9fb6498c22b6	77777777-7777-4777-8777-777777777777	install-c4-0004	Child Four Phone	android	\N	\N	revoked	\N	2026-10-25 23:53:40.978376+05:30	2026-10-26 23:53:41.143703+05:30	2026-10-26 23:53:40.978376+05:30	\N	\N	device_admin	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:41.143703+05:30
d0000000-0000-4000-8000-000000000006	8b733f0b-172f-4cc4-830e-9fb6498c22b6	77777777-7777-4777-8777-777777777777	install-c4-0006	Child Four Tablet	android	\N	\N	revoked	\N	\N	2026-10-26 23:53:41.143703+05:30	\N	\N	\N	none	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:41.143703+05:30
d0000000-0000-4000-8000-000000000007	8b733f0b-172f-4cc4-830e-9fb6498c22b6	66666666-6666-4666-8666-666666666666	install-c3-0007	Child Three Phone	android	\N	\N	revoked	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:41.143703+05:30	2026-10-26 23:33:41.143703+05:30	\N	\N	device_admin	0	\N	\N	\N	\N	\N	\N	2026-10-26 23:53:40.978376+05:30	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: families; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.families (id, name, owner_id, settings, created_at, updated_at, deleted_at) FROM stdin;
fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	Family Two	22222222-2222-4222-8222-222222222222	{"usage_retention_days": 90, "location_retention_days": 30}	2026-10-26 23:53:40.973294+05:30	2026-10-26 23:53:40.973294+05:30	\N
8b733f0b-172f-4cc4-830e-9fb6498c22b6	Family One	11111111-1111-4111-8111-111111111111	{"usage_retention_days": 90, "location_retention_days": 30}	2026-10-26 23:53:40.958477+05:30	2026-10-26 23:53:41.070973+05:30	\N
\.


--
-- Data for Name: family_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.family_members (id, family_id, user_id, role, status, created_at, removed_at) FROM stdin;
fb3b361b-d9ef-4ecd-850d-9858c623dbe7	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	parent	active	2026-10-26 23:53:40.958477+05:30	\N
05defdac-9a96-4ccc-8b50-190659553472	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	22222222-2222-4222-8222-222222222222	parent	active	2026-10-26 23:53:40.973294+05:30	\N
639258cd-bd02-4a03-bbab-de06b358d60f	8b733f0b-172f-4cc4-830e-9fb6498c22b6	33333333-3333-4333-8333-333333333333	child	active	2026-10-26 23:53:40.974735+05:30	\N
c718556d-3362-4525-92d3-e0e901e45249	8b733f0b-172f-4cc4-830e-9fb6498c22b6	55555555-5555-4555-8555-555555555555	parent	active	2026-10-26 23:53:40.974735+05:30	\N
9ff23af0-6766-4e1a-b091-03e639ca1f68	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	44444444-4444-4444-8444-444444444444	child	active	2026-10-26 23:53:40.974735+05:30	\N
a4ad0217-abf6-4df3-9247-d07360768baa	8b733f0b-172f-4cc4-830e-9fb6498c22b6	66666666-6666-4666-8666-666666666666	child	active	2026-10-26 23:53:41.143703+05:30	\N
19cbe70f-c2cb-4ca7-8abd-6531ddc7cc7b	8b733f0b-172f-4cc4-830e-9fb6498c22b6	77777777-7777-4777-8777-777777777777	child	removed	2026-10-26 23:53:40.974735+05:30	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: location_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.location_events (id, device_id, family_id, lat, lng, accuracy_m, recorded_at, received_at, source) FROM stdin;
bc79ebd1-96e7-4af5-aa4d-21cd2d44797f	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	51.5007	-0.1246	12.5	2026-10-26 23:48:41.006237+05:30	2026-10-26 23:53:41.006237+05:30	device
177e109c-157c-4b1c-bc6f-364fc95d0a34	d0000000-0000-4000-8000-000000000002	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	40.7128	-74.006	20	2026-10-26 23:47:41.006237+05:30	2026-10-26 23:53:41.006237+05:30	device
\.


--
-- Data for Name: pairing_attempts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pairing_attempts (id, parent_user_id, code_hash, attempted_at, success) FROM stdin;
\.


--
-- Data for Name: pairing_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pairing_requests (id, token_id, family_id, parent_user_id, child_user_id, status, created_at, expires_at, responded_at) FROM stdin;
20000000-0000-4000-8000-000000000001	10000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	66666666-6666-4666-8666-666666666666	approved	2026-10-26 23:53:41.040131+05:30	2026-10-27 00:03:41.040131+05:30	2026-10-26 23:53:41.143703+05:30
20000000-0000-4000-8000-000000000003	10000000-0000-4000-8000-000000000003	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	77777777-7777-4777-8777-777777777777	rejected	2026-10-26 23:53:41.040131+05:30	2026-10-27 00:03:41.040131+05:30	2026-10-26 23:53:41.143703+05:30
20000000-0000-4000-8000-000000000008	10000000-0000-4000-8000-000000000008	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	22222222-2222-4222-8222-222222222222	66666666-6666-4666-8666-666666666666	pending_child	2026-10-26 23:53:41.143703+05:30	2026-10-27 00:03:41.143703+05:30	\N
20000000-0000-4000-8000-000000000002	10000000-0000-4000-8000-000000000002	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	66666666-6666-4666-8666-666666666666	cancelled	2026-10-26 23:53:41.040131+05:30	2026-10-27 00:03:41.040131+05:30	2026-10-26 23:53:41.143703+05:30
20000000-0000-4000-8000-000000000004	10000000-0000-4000-8000-000000000004	8b733f0b-172f-4cc4-830e-9fb6498c22b6	11111111-1111-4111-8111-111111111111	66666666-6666-4666-8666-666666666666	cancelled	2026-10-26 23:53:41.040131+05:30	2026-10-26 23:43:41.040131+05:30	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profiles (id, role, display_name, created_at, updated_at) FROM stdin;
11111111-1111-4111-8111-111111111111	parent	Parent One	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.956563+05:30
22222222-2222-4222-8222-222222222222	parent	Parent Two	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.956563+05:30
55555555-5555-4555-8555-555555555555	parent	Parent Three	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.956563+05:30
33333333-3333-4333-8333-333333333333	child	Child One	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.957793+05:30
44444444-4444-4444-8444-444444444444	child	Child Two	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.957793+05:30
66666666-6666-4666-8666-666666666666	child	Child Three	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.957793+05:30
77777777-7777-4777-8777-777777777777	child	Child Four	2026-10-26 23:53:40.950732+05:30	2026-10-26 23:53:40.957793+05:30
\.


--
-- Data for Name: remote_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.remote_sessions (id, family_id, device_id, parent_user_id, child_user_id, kind, status, requested_at, accepted_at, started_at, ended_at, expires_at, ended_by, ended_reason, consent_recorded, session_nonce, created_at) FROM stdin;
50000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	d0000000-0000-4000-8000-000000000001	11111111-1111-4111-8111-111111111111	33333333-3333-4333-8333-333333333333	video	accepted	2026-10-26 23:48:41.023841+05:30	2026-10-26 23:49:41.023841+05:30	\N	\N	2026-10-27 00:23:41.023841+05:30	\N	\N	t	70000000-0000-4000-8000-000000000001	2026-10-26 23:53:41.023841+05:30
50000000-0000-4000-8000-000000000002	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	d0000000-0000-4000-8000-000000000002	22222222-2222-4222-8222-222222222222	44444444-4444-4444-8444-444444444444	audio	expired	2026-10-26 22:53:41.023841+05:30	2026-10-26 22:54:41.023841+05:30	\N	2026-10-26 23:53:41.143703+05:30	2026-10-26 23:48:41.023841+05:30	\N	expired	t	70000000-0000-4000-8000-000000000002	2026-10-26 23:53:41.023841+05:30
50000000-0000-4000-8000-000000000004	8b733f0b-172f-4cc4-830e-9fb6498c22b6	d0000000-0000-4000-8000-000000000004	11111111-1111-4111-8111-111111111111	77777777-7777-4777-8777-777777777777	audio	ended	2026-10-26 23:51:41.143703+05:30	2026-10-26 23:52:41.143703+05:30	\N	2026-10-26 23:53:41.143703+05:30	2026-10-27 00:13:41.143703+05:30	11111111-1111-4111-8111-111111111111	member_unlinked	t	70000000-0000-4000-8000-000000000004	2026-10-26 23:53:41.143703+05:30
50000000-0000-4000-8000-000000000007	8b733f0b-172f-4cc4-830e-9fb6498c22b6	d0000000-0000-4000-8000-000000000007	11111111-1111-4111-8111-111111111111	66666666-6666-4666-8666-666666666666	video	ended	2026-10-26 23:51:41.143703+05:30	2026-10-26 23:52:41.143703+05:30	\N	2026-10-26 23:53:41.143703+05:30	2026-10-27 00:13:41.143703+05:30	11111111-1111-4111-8111-111111111111	device_revoked	t	70000000-0000-4000-8000-000000000007	2026-10-26 23:53:41.143703+05:30
\.


--
-- Data for Name: safe_zone_states; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.safe_zone_states (zone_id, device_id, inside, updated_at) FROM stdin;
\.


--
-- Data for Name: safe_zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.safe_zones (id, family_id, name, lat, lng, radius_m, active, created_by, created_at) FROM stdin;
f0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	School	51.5007	-0.1246	200	t	11111111-1111-4111-8111-111111111111	2026-10-26 23:53:41.016297+05:30
\.


--
-- Data for Name: safety_alerts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.safety_alerts (id, family_id, device_id, type, severity, message, payload, created_at, acknowledged_at, acknowledged_by) FROM stdin;
a0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	d0000000-0000-4000-8000-000000000001	low_battery	warning	Battery is low.	{"battery_level": 15}	2026-10-26 23:53:41.019672+05:30	\N	\N
9b85353f-b9b3-489d-9e2d-ae0773a23bf4	8b733f0b-172f-4cc4-830e-9fb6498c22b6	d0000000-0000-4000-8000-000000000007	offline	warning	Device has not reported for more than 15 minutes.	{"last_seen_at": "2026-10-26T23:33:41.143703+05:30", "threshold_minutes": 15}	2026-10-26 23:53:41.143703+05:30	\N	\N
\.


--
-- Data for Name: usage_daily; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usage_daily (id, device_id, family_id, day, package_name, app_label, total_ms, last_used_at, uploaded_at, source) FROM stdin;
7be09133-ab59-41ae-8f6f-9ae9230fe64d	d0000000-0000-4000-8000-000000000001	8b733f0b-172f-4cc4-830e-9fb6498c22b6	2026-10-25	com.example.kid	Kid App	90000	2026-10-26 20:53:41.000381+05:30	2026-10-26 23:53:41.000381+05:30	usage_stats
cc1bc7c2-2696-4768-b847-21c7c78bff63	d0000000-0000-4000-8000-000000000002	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	2026-10-25	com.example.other	Other App	120000	2026-10-26 21:53:41.000381+05:30	2026-10-26 23:53:41.000381+05:30	usage_stats
\.


--
-- Data for Name: webrtc_signals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.webrtc_signals (id, session_id, from_user_id, kind, payload, created_at, sequence) FROM stdin;
60000000-0000-4000-8000-000000000001	50000000-0000-4000-8000-000000000001	11111111-1111-4111-8111-111111111111	offer	{"sdp": "fixture-offer"}	2026-10-26 23:53:41.03113+05:30	1
f85c2688-4968-44e7-802d-49b6d756fea0	50000000-0000-4000-8000-000000000001	33333333-3333-4333-8333-333333333333	ice	{"candidate": "fixture"}	2026-10-26 23:53:41.070973+05:30	2
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: realtime; Owner: postgres
--

COPY realtime.messages (id, inserted_at, topic, extension, payload, event, private) FROM stdin;
1	2026-10-26 23:53:41.049188+05:30	safety-alerts:8b733f0b-172f-4cc4-830e-9fb6498c22b6	postgres_changes	{"n": 1}	\N	t
2	2026-10-26 23:53:41.049188+05:30	safety-alerts:fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2	postgres_changes	{"n": 2}	\N	t
3	2026-10-26 23:53:41.049188+05:30	safety-alerts:8b733f0b-172f-4cc4-830e-9fb6498c22b6	broadcast	{"n": 3}	\N	t
4	2026-10-26 23:53:41.049188+05:30	remote-session:50000000-0000-4000-8000-000000000001	postgres_changes	{"n": 4}	\N	t
5	2026-10-26 23:53:41.049188+05:30	remote-session:50000000-0000-4000-8000-000000000002	postgres_changes	{"n": 5}	\N	t
6	2026-10-26 23:53:41.049188+05:30	bogus:8b733f0b-172f-4cc4-830e-9fb6498c22b6	postgres_changes	{"n": 6}	\N	t
\.


--
-- Data for Name: state; Type: TABLE DATA; Schema: tests; Owner: postgres
--

COPY tests.state (key, value) FROM stdin;
family1	8b733f0b-172f-4cc4-830e-9fb6498c22b6
family2	fb42d200-c4b4-4f4e-80f0-e1a3d6c42de2
\.


--
-- Name: webrtc_signals_sequence_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.webrtc_signals_sequence_seq', 3, true);


--
-- Name: messages_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: postgres
--

SELECT pg_catalog.setval('realtime.messages_id_seq', 6, true);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: device_apps device_apps_device_package_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_apps
    ADD CONSTRAINT device_apps_device_package_key UNIQUE (device_id, package_name);


--
-- Name: device_apps device_apps_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_apps
    ADD CONSTRAINT device_apps_pkey PRIMARY KEY (id);


--
-- Name: device_commands device_commands_device_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_device_idempotency_key UNIQUE (device_id, idempotency_key);


--
-- Name: device_commands device_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_pkey PRIMARY KEY (id);


--
-- Name: device_pairing_tokens device_pairing_tokens_code_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_pairing_tokens
    ADD CONSTRAINT device_pairing_tokens_code_hash_key UNIQUE (code_hash);


--
-- Name: device_pairing_tokens device_pairing_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_pairing_tokens
    ADD CONSTRAINT device_pairing_tokens_pkey PRIMARY KEY (id);


--
-- Name: device_policies device_policies_device_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_policies
    ADD CONSTRAINT device_policies_device_version_key UNIQUE (device_id, version);


--
-- Name: device_policies device_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_policies
    ADD CONSTRAINT device_policies_pkey PRIMARY KEY (id);


--
-- Name: devices devices_family_installation_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_family_installation_key UNIQUE (family_id, installation_id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: families families_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.families
    ADD CONSTRAINT families_pkey PRIMARY KEY (id);


--
-- Name: family_members family_members_family_user_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_members
    ADD CONSTRAINT family_members_family_user_key UNIQUE (family_id, user_id);


--
-- Name: family_members family_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_members
    ADD CONSTRAINT family_members_pkey PRIMARY KEY (id);


--
-- Name: location_events location_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location_events
    ADD CONSTRAINT location_events_pkey PRIMARY KEY (id);


--
-- Name: pairing_attempts pairing_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_attempts
    ADD CONSTRAINT pairing_attempts_pkey PRIMARY KEY (id);


--
-- Name: pairing_requests pairing_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_pkey PRIMARY KEY (id);


--
-- Name: pairing_requests pairing_requests_token_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_token_id_key UNIQUE (token_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: remote_sessions remote_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_pkey PRIMARY KEY (id);


--
-- Name: safe_zone_states safe_zone_states_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zone_states
    ADD CONSTRAINT safe_zone_states_pkey PRIMARY KEY (zone_id, device_id);


--
-- Name: safe_zones safe_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zones
    ADD CONSTRAINT safe_zones_pkey PRIMARY KEY (id);


--
-- Name: safety_alerts safety_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safety_alerts
    ADD CONSTRAINT safety_alerts_pkey PRIMARY KEY (id);


--
-- Name: usage_daily usage_daily_device_day_package_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_device_day_package_key UNIQUE (device_id, day, package_name);


--
-- Name: usage_daily usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_pkey PRIMARY KEY (id);


--
-- Name: webrtc_signals webrtc_signals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.webrtc_signals
    ADD CONSTRAINT webrtc_signals_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: postgres
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: state state_pkey; Type: CONSTRAINT; Schema: tests; Owner: postgres
--

ALTER TABLE ONLY tests.state
    ADD CONSTRAINT state_pkey PRIMARY KEY (key);


--
-- Name: audit_logs_actor_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX audit_logs_actor_idx ON public.audit_logs USING btree (actor_user_id, created_at DESC);


--
-- Name: audit_logs_family_created_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX audit_logs_family_created_idx ON public.audit_logs USING btree (family_id, created_at DESC);


--
-- Name: device_apps_family_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_apps_family_idx ON public.device_apps USING btree (family_id);


--
-- Name: device_commands_device_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_commands_device_status_idx ON public.device_commands USING btree (device_id, status, created_at);


--
-- Name: device_commands_expires_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_commands_expires_idx ON public.device_commands USING btree (expires_at);


--
-- Name: device_pairing_tokens_child_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_pairing_tokens_child_idx ON public.device_pairing_tokens USING btree (child_user_id, status);


--
-- Name: device_pairing_tokens_expires_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_pairing_tokens_expires_idx ON public.device_pairing_tokens USING btree (expires_at);


--
-- Name: device_policies_family_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_policies_family_idx ON public.device_policies USING btree (family_id);


--
-- Name: devices_child_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX devices_child_user_id_idx ON public.devices USING btree (child_user_id);


--
-- Name: devices_family_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX devices_family_id_idx ON public.devices USING btree (family_id);


--
-- Name: devices_one_active_per_child; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX devices_one_active_per_child ON public.devices USING btree (child_user_id) WHERE (status = 'active'::text);


--
-- Name: devices_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX devices_status_idx ON public.devices USING btree (status);


--
-- Name: families_one_active_per_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX families_one_active_per_owner ON public.families USING btree (owner_id) WHERE (deleted_at IS NULL);


--
-- Name: family_members_family_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX family_members_family_id_idx ON public.family_members USING btree (family_id);


--
-- Name: family_members_one_active_child_family; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX family_members_one_active_child_family ON public.family_members USING btree (user_id) WHERE ((status = 'active'::text) AND (role = 'child'::text));


--
-- Name: family_members_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX family_members_user_id_idx ON public.family_members USING btree (user_id);


--
-- Name: location_events_device_recorded_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_events_device_recorded_idx ON public.location_events USING btree (device_id, recorded_at DESC);


--
-- Name: location_events_family_recorded_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_events_family_recorded_idx ON public.location_events USING btree (family_id, recorded_at DESC);


--
-- Name: pairing_attempts_code_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pairing_attempts_code_idx ON public.pairing_attempts USING btree (code_hash, attempted_at DESC);


--
-- Name: pairing_attempts_parent_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pairing_attempts_parent_idx ON public.pairing_attempts USING btree (parent_user_id, attempted_at DESC);


--
-- Name: pairing_requests_child_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pairing_requests_child_idx ON public.pairing_requests USING btree (child_user_id, status);


--
-- Name: pairing_requests_family_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pairing_requests_family_idx ON public.pairing_requests USING btree (family_id, status);


--
-- Name: pairing_requests_parent_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pairing_requests_parent_idx ON public.pairing_requests USING btree (parent_user_id, status);


--
-- Name: remote_sessions_child_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX remote_sessions_child_status_idx ON public.remote_sessions USING btree (child_user_id, status);


--
-- Name: remote_sessions_device_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX remote_sessions_device_status_idx ON public.remote_sessions USING btree (device_id, status);


--
-- Name: remote_sessions_expires_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX remote_sessions_expires_idx ON public.remote_sessions USING btree (expires_at);


--
-- Name: remote_sessions_family_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX remote_sessions_family_idx ON public.remote_sessions USING btree (family_id, requested_at DESC);


--
-- Name: safe_zones_family_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX safe_zones_family_idx ON public.safe_zones USING btree (family_id);


--
-- Name: safety_alerts_device_type_created_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX safety_alerts_device_type_created_idx ON public.safety_alerts USING btree (device_id, type, created_at DESC);


--
-- Name: safety_alerts_family_created_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX safety_alerts_family_created_idx ON public.safety_alerts USING btree (family_id, created_at DESC);


--
-- Name: usage_daily_device_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usage_daily_device_idx ON public.usage_daily USING btree (device_id, day);


--
-- Name: usage_daily_family_day_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usage_daily_family_day_idx ON public.usage_daily USING btree (family_id, day);


--
-- Name: webrtc_signals_session_sequence_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX webrtc_signals_session_sequence_idx ON public.webrtc_signals USING btree (session_id, sequence);


--
-- Name: users on_auth_user_created; Type: TRIGGER; Schema: auth; Owner: postgres
--

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();


--
-- Name: audit_logs audit_logs_append_only; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER audit_logs_append_only BEFORE DELETE OR UPDATE ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION private.audit_logs_append_only();


--
-- Name: devices devices_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER devices_set_updated_at BEFORE UPDATE ON public.devices FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();


--
-- Name: families families_before_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER families_before_update BEFORE UPDATE ON public.families FOR EACH ROW EXECUTE FUNCTION private.families_before_update();


--
-- Name: families families_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER families_set_updated_at BEFORE UPDATE ON public.families FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();


--
-- Name: profiles profiles_before_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER profiles_before_update BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION private.profiles_before_update();


--
-- Name: safe_zone_states safe_zone_states_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER safe_zone_states_set_updated_at BEFORE UPDATE ON public.safe_zone_states FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE SET NULL;


--
-- Name: device_apps device_apps_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_apps
    ADD CONSTRAINT device_apps_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: device_apps device_apps_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_apps
    ADD CONSTRAINT device_apps_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: device_commands device_commands_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: device_commands device_commands_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: device_commands device_commands_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: device_pairing_tokens device_pairing_tokens_child_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_pairing_tokens
    ADD CONSTRAINT device_pairing_tokens_child_user_id_fkey FOREIGN KEY (child_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: device_pairing_tokens device_pairing_tokens_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_pairing_tokens
    ADD CONSTRAINT device_pairing_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: device_pairing_tokens device_pairing_tokens_redeemed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_pairing_tokens
    ADD CONSTRAINT device_pairing_tokens_redeemed_by_fkey FOREIGN KEY (redeemed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: device_policies device_policies_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_policies
    ADD CONSTRAINT device_policies_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: device_policies device_policies_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_policies
    ADD CONSTRAINT device_policies_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: device_policies device_policies_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_policies
    ADD CONSTRAINT device_policies_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: devices devices_child_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_child_user_id_fkey FOREIGN KEY (child_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: devices devices_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: families families_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.families
    ADD CONSTRAINT families_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: family_members family_members_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_members
    ADD CONSTRAINT family_members_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: family_members family_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_members
    ADD CONSTRAINT family_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: location_events location_events_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location_events
    ADD CONSTRAINT location_events_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: location_events location_events_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location_events
    ADD CONSTRAINT location_events_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: pairing_attempts pairing_attempts_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_attempts
    ADD CONSTRAINT pairing_attempts_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: pairing_requests pairing_requests_child_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_child_user_id_fkey FOREIGN KEY (child_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: pairing_requests pairing_requests_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: pairing_requests pairing_requests_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: pairing_requests pairing_requests_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pairing_requests
    ADD CONSTRAINT pairing_requests_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.device_pairing_tokens(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: remote_sessions remote_sessions_child_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_child_user_id_fkey FOREIGN KEY (child_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: remote_sessions remote_sessions_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: remote_sessions remote_sessions_ended_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_ended_by_fkey FOREIGN KEY (ended_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: remote_sessions remote_sessions_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: remote_sessions remote_sessions_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.remote_sessions
    ADD CONSTRAINT remote_sessions_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: safe_zone_states safe_zone_states_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zone_states
    ADD CONSTRAINT safe_zone_states_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: safe_zone_states safe_zone_states_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zone_states
    ADD CONSTRAINT safe_zone_states_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.safe_zones(id) ON DELETE CASCADE;


--
-- Name: safe_zones safe_zones_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zones
    ADD CONSTRAINT safe_zones_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: safe_zones safe_zones_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safe_zones
    ADD CONSTRAINT safe_zones_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: safety_alerts safety_alerts_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safety_alerts
    ADD CONSTRAINT safety_alerts_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: safety_alerts safety_alerts_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safety_alerts
    ADD CONSTRAINT safety_alerts_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: safety_alerts safety_alerts_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.safety_alerts
    ADD CONSTRAINT safety_alerts_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: usage_daily usage_daily_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: usage_daily usage_daily_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usage_daily
    ADD CONSTRAINT usage_daily_family_id_fkey FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: webrtc_signals webrtc_signals_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.webrtc_signals
    ADD CONSTRAINT webrtc_signals_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: webrtc_signals webrtc_signals_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.webrtc_signals
    ADD CONSTRAINT webrtc_signals_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.remote_sessions(id) ON DELETE CASCADE;


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_select_family_parent; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY audit_logs_select_family_parent ON public.audit_logs FOR SELECT TO authenticated USING (((family_id IS NOT NULL) AND private.is_family_parent(family_id)));


--
-- Name: device_apps; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.device_apps ENABLE ROW LEVEL SECURITY;

--
-- Name: device_apps device_apps_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY device_apps_select_parent_or_child ON public.device_apps FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = device_apps.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: device_commands; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.device_commands ENABLE ROW LEVEL SECURITY;

--
-- Name: device_commands device_commands_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY device_commands_select_parent_or_child ON public.device_commands FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = device_commands.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: device_pairing_tokens; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.device_pairing_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: device_policies; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.device_policies ENABLE ROW LEVEL SECURITY;

--
-- Name: device_policies device_policies_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY device_policies_select_parent_or_child ON public.device_policies FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = device_policies.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: devices; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

--
-- Name: devices devices_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY devices_select_parent_or_child ON public.devices FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (child_user_id = auth.uid())));


--
-- Name: families; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;

--
-- Name: families families_select_members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY families_select_members ON public.families FOR SELECT TO authenticated USING (((deleted_at IS NULL) AND private.is_family_member(id)));


--
-- Name: families families_update_owner; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY families_update_owner ON public.families FOR UPDATE TO authenticated USING (((owner_id = auth.uid()) AND (deleted_at IS NULL))) WITH CHECK ((owner_id = auth.uid()));


--
-- Name: family_members; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

--
-- Name: family_members family_members_select_family; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY family_members_select_family ON public.family_members FOR SELECT TO authenticated USING (private.is_family_member(family_id));


--
-- Name: location_events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.location_events ENABLE ROW LEVEL SECURITY;

--
-- Name: location_events location_events_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY location_events_select_parent_or_child ON public.location_events FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = location_events.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: pairing_attempts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pairing_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: pairing_requests; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pairing_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: pairing_requests pairing_requests_select_participants; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY pairing_requests_select_participants ON public.pairing_requests FOR SELECT TO authenticated USING (((child_user_id = auth.uid()) OR (parent_user_id = auth.uid()) OR private.is_family_parent(family_id)));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_self_or_family; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_select_self_or_family ON public.profiles FOR SELECT TO authenticated USING (((id = auth.uid()) OR private.shares_active_family(id)));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- Name: remote_sessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.remote_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: remote_sessions remote_sessions_select_participants; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY remote_sessions_select_participants ON public.remote_sessions FOR SELECT TO authenticated USING (((parent_user_id = auth.uid()) OR (child_user_id = auth.uid()) OR private.is_family_parent(family_id)));


--
-- Name: safe_zone_states; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.safe_zone_states ENABLE ROW LEVEL SECURITY;

--
-- Name: safe_zones; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.safe_zones ENABLE ROW LEVEL SECURITY;

--
-- Name: safe_zones safe_zones_delete_parent; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY safe_zones_delete_parent ON public.safe_zones FOR DELETE TO authenticated USING (private.is_family_parent(family_id));


--
-- Name: safe_zones safe_zones_insert_parent; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY safe_zones_insert_parent ON public.safe_zones FOR INSERT TO authenticated WITH CHECK (private.is_family_parent(family_id));


--
-- Name: safe_zones safe_zones_select_family; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY safe_zones_select_family ON public.safe_zones FOR SELECT TO authenticated USING (private.is_family_member(family_id));


--
-- Name: safe_zones safe_zones_update_parent; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY safe_zones_update_parent ON public.safe_zones FOR UPDATE TO authenticated USING (private.is_family_parent(family_id)) WITH CHECK (private.is_family_parent(family_id));


--
-- Name: safety_alerts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.safety_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: safety_alerts safety_alerts_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY safety_alerts_select_parent_or_child ON public.safety_alerts FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = safety_alerts.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: usage_daily; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usage_daily ENABLE ROW LEVEL SECURITY;

--
-- Name: usage_daily usage_daily_select_parent_or_child; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY usage_daily_select_parent_or_child ON public.usage_daily FOR SELECT TO authenticated USING ((private.is_family_parent(family_id) OR (EXISTS ( SELECT 1
   FROM public.devices d
  WHERE ((d.id = usage_daily.device_id) AND (d.child_user_id = auth.uid()))))));


--
-- Name: webrtc_signals; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.webrtc_signals ENABLE ROW LEVEL SECURITY;

--
-- Name: webrtc_signals webrtc_signals_insert_participant; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY webrtc_signals_insert_participant ON public.webrtc_signals FOR INSERT TO authenticated WITH CHECK (((from_user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.remote_sessions s
  WHERE ((s.id = webrtc_signals.session_id) AND (s.status = ANY (ARRAY['accepted'::text, 'active'::text])) AND (s.expires_at > now()) AND ((s.parent_user_id = auth.uid()) OR (s.child_user_id = auth.uid())))))));


--
-- Name: webrtc_signals webrtc_signals_select_participant; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY webrtc_signals_select_participant ON public.webrtc_signals FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.remote_sessions s
  WHERE ((s.id = webrtc_signals.session_id) AND (s.status = ANY (ARRAY['accepted'::text, 'active'::text])) AND (s.expires_at > now()) AND ((s.parent_user_id = auth.uid()) OR (s.child_user_id = auth.uid()))))));


--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: postgres
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages parentcontrol_private_topics; Type: POLICY; Schema: realtime; Owner: postgres
--

CREATE POLICY parentcontrol_private_topics ON realtime.messages FOR SELECT TO authenticated USING (private.realtime_topic_allowed(realtime.topic()));


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA auth TO anon;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT USAGE ON SCHEMA auth TO service_role;


--
-- Name: SCHEMA private; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA private TO service_role;
GRANT USAGE ON SCHEMA private TO authenticated;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: SCHEMA realtime; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA realtime TO authenticated;


--
-- Name: SCHEMA tests; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA tests TO anon;
GRANT USAGE ON SCHEMA tests TO authenticated;
GRANT USAGE ON SCHEMA tests TO service_role;


--
-- Name: FUNCTION apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION audit_logs_append_only(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.audit_logs_append_only() FROM PUBLIC;


--
-- Name: FUNCTION create_family_with_owner(p_owner uuid, p_name text); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.create_family_with_owner(p_owner uuid, p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.create_family_with_owner(p_owner uuid, p_name text) TO service_role;


--
-- Name: FUNCTION detect_offline_devices(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.detect_offline_devices() FROM PUBLIC;
GRANT ALL ON FUNCTION private.detect_offline_devices() TO service_role;


--
-- Name: FUNCTION expire_stale_commands(p_device_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.expire_stale_commands(p_device_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.expire_stale_commands(p_device_id uuid) TO service_role;


--
-- Name: FUNCTION expire_stale_sessions(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.expire_stale_sessions() FROM PUBLIC;
GRANT ALL ON FUNCTION private.expire_stale_sessions() TO service_role;


--
-- Name: FUNCTION families_before_update(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.families_before_update() FROM PUBLIC;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC;


--
-- Name: FUNCTION is_family_member(p_family_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.is_family_member(p_family_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.is_family_member(p_family_id uuid) TO authenticated;


--
-- Name: FUNCTION is_family_parent(p_family_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.is_family_parent(p_family_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.is_family_parent(p_family_id uuid) TO authenticated;


--
-- Name: FUNCTION poll_device_commands(p_device_id uuid, p_limit integer); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.poll_device_commands(p_device_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION private.poll_device_commands(p_device_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION profiles_before_update(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.profiles_before_update() FROM PUBLIC;


--
-- Name: FUNCTION realtime_topic_allowed(p_topic text); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.realtime_topic_allowed(p_topic text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.realtime_topic_allowed(p_topic text) TO authenticated;


--
-- Name: FUNCTION record_audit(p_family_id uuid, p_actor_user_id uuid, p_device_id uuid, p_event_type text, p_target_type text, p_target_id text, p_metadata jsonb); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.record_audit(p_family_id uuid, p_actor_user_id uuid, p_device_id uuid, p_event_type text, p_target_type text, p_target_id text, p_metadata jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION private.record_audit(p_family_id uuid, p_actor_user_id uuid, p_device_id uuid, p_event_type text, p_target_type text, p_target_id text, p_metadata jsonb) TO service_role;


--
-- Name: FUNCTION replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION private.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) TO service_role;


--
-- Name: FUNCTION respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION private.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) TO service_role;


--
-- Name: FUNCTION revoke_device(p_device_id uuid, p_actor_user_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.revoke_device(p_device_id uuid, p_actor_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.revoke_device(p_device_id uuid, p_actor_user_id uuid) TO service_role;


--
-- Name: FUNCTION set_updated_at(); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.set_updated_at() FROM PUBLIC;


--
-- Name: FUNCTION shares_active_family(p_user_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.shares_active_family(p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.shares_active_family(p_user_id uuid) TO authenticated;


--
-- Name: FUNCTION unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid); Type: ACL; Schema: private; Owner: postgres
--

REVOKE ALL ON FUNCTION private.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) TO service_role;


--
-- Name: FUNCTION apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION create_family_with_owner(p_owner uuid, p_name text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.create_family_with_owner(p_owner uuid, p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_family_with_owner(p_owner uuid, p_name text) TO service_role;


--
-- Name: FUNCTION detect_offline_devices(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.detect_offline_devices() FROM PUBLIC;
GRANT ALL ON FUNCTION public.detect_offline_devices() TO service_role;


--
-- Name: FUNCTION expire_stale_commands(p_device_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.expire_stale_commands(p_device_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.expire_stale_commands(p_device_id uuid) TO service_role;


--
-- Name: FUNCTION expire_stale_sessions(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.expire_stale_sessions() FROM PUBLIC;
GRANT ALL ON FUNCTION public.expire_stale_sessions() TO service_role;


--
-- Name: FUNCTION poll_device_commands(p_device_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.poll_device_commands(p_device_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.poll_device_commands(p_device_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.replace_device_apps(p_device_id uuid, p_family_id uuid, p_apps jsonb) TO service_role;


--
-- Name: FUNCTION respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.respond_pairing_request(p_request_id uuid, p_child_user_id uuid, p_approve boolean) TO service_role;


--
-- Name: FUNCTION revoke_device(p_device_id uuid, p_actor_user_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.revoke_device(p_device_id uuid, p_actor_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.revoke_device(p_device_id uuid, p_actor_user_id uuid) TO service_role;


--
-- Name: FUNCTION unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.unlink_child(p_family_id uuid, p_child_user_id uuid, p_actor_user_id uuid) TO service_role;


--
-- Name: FUNCTION assert_true(p_condition boolean, p_label text); Type: ACL; Schema: tests; Owner: postgres
--

GRANT ALL ON FUNCTION tests.assert_true(p_condition boolean, p_label text) TO authenticated;


--
-- Name: FUNCTION expect_error(p_sql text, p_state text, p_message text, p_label text); Type: ACL; Schema: tests; Owner: postgres
--

GRANT ALL ON FUNCTION tests.expect_error(p_sql text, p_state text, p_message text, p_label text) TO authenticated;


--
-- Name: TABLE audit_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.audit_logs TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.audit_logs TO service_role;


--
-- Name: TABLE device_apps; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.device_apps TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.device_apps TO service_role;


--
-- Name: TABLE device_commands; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.device_commands TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.device_commands TO service_role;


--
-- Name: TABLE device_pairing_tokens; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.device_pairing_tokens TO service_role;


--
-- Name: TABLE device_policies; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.device_policies TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.device_policies TO service_role;


--
-- Name: TABLE devices; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.devices TO service_role;


--
-- Name: COLUMN devices.id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(id) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.family_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(family_id) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.child_user_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(child_user_id) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.display_name; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(display_name) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.platform; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(platform) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.android_version; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(android_version) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.app_version; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(app_version) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.status; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(status) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.credential_issued_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(credential_issued_at) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.credential_revoked_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(credential_revoked_at) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.last_seen_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(last_seen_at) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.battery_level; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(battery_level) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.is_charging; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(is_charging) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.enforcement_mode; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(enforcement_mode) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.policy_version; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(policy_version) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.usage_access_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(usage_access_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.location_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(location_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.background_location_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(background_location_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.camera_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(camera_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.microphone_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(microphone_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.notifications_granted; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(notifications_granted) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.created_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(created_at) ON TABLE public.devices TO authenticated;


--
-- Name: COLUMN devices.updated_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(updated_at) ON TABLE public.devices TO authenticated;


--
-- Name: TABLE families; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.families TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.families TO service_role;


--
-- Name: COLUMN families.name; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(name) ON TABLE public.families TO authenticated;


--
-- Name: COLUMN families.settings; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(settings) ON TABLE public.families TO authenticated;


--
-- Name: TABLE family_members; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.family_members TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.family_members TO service_role;


--
-- Name: TABLE location_events; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.location_events TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.location_events TO service_role;


--
-- Name: TABLE pairing_attempts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.pairing_attempts TO service_role;


--
-- Name: TABLE pairing_requests; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.pairing_requests TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.pairing_requests TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.profiles TO service_role;


--
-- Name: COLUMN profiles.display_name; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(display_name) ON TABLE public.profiles TO authenticated;


--
-- Name: TABLE remote_sessions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.remote_sessions TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.remote_sessions TO service_role;


--
-- Name: TABLE safe_zone_states; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.safe_zone_states TO service_role;


--
-- Name: TABLE safe_zones; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,DELETE ON TABLE public.safe_zones TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.safe_zones TO service_role;


--
-- Name: COLUMN safe_zones.family_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(family_id) ON TABLE public.safe_zones TO authenticated;


--
-- Name: COLUMN safe_zones.name; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(name),UPDATE(name) ON TABLE public.safe_zones TO authenticated;


--
-- Name: COLUMN safe_zones.lat; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(lat),UPDATE(lat) ON TABLE public.safe_zones TO authenticated;


--
-- Name: COLUMN safe_zones.lng; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(lng),UPDATE(lng) ON TABLE public.safe_zones TO authenticated;


--
-- Name: COLUMN safe_zones.radius_m; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(radius_m),UPDATE(radius_m) ON TABLE public.safe_zones TO authenticated;


--
-- Name: COLUMN safe_zones.active; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(active),UPDATE(active) ON TABLE public.safe_zones TO authenticated;


--
-- Name: TABLE safety_alerts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.safety_alerts TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.safety_alerts TO service_role;


--
-- Name: TABLE usage_daily; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.usage_daily TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.usage_daily TO service_role;


--
-- Name: TABLE webrtc_signals; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.webrtc_signals TO authenticated;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.webrtc_signals TO service_role;


--
-- Name: SEQUENCE webrtc_signals_sequence_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.webrtc_signals_sequence_seq TO service_role;


--
-- Name: TABLE messages; Type: ACL; Schema: realtime; Owner: postgres
--

GRANT SELECT ON TABLE realtime.messages TO authenticated;


--
-- Name: TABLE state; Type: ACL; Schema: tests; Owner: postgres
--

GRANT SELECT ON TABLE tests.state TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

