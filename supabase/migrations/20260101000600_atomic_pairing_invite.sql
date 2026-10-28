-- Parent Control — atomic pairing-request creation (BUG-033).
--
-- Both create paths used to read for a live request and then insert, so two
-- concurrent callers could both pass the SELECT and both INSERT, leaving
-- duplicate `pending_child` rows in the child's approval inbox.
--
-- Why an advisory lock and not a partial unique index: a request keeps
-- `status = 'pending_child'` after `expires_at` passes, until the child next
-- polls. A partial-index predicate cannot reference now(), so an index on
-- (child_user_id, family_id, parent_user_id) where status = 'pending_child'
-- would reject a legitimate "expired, then invite again" sequence. The SQL
-- suite keeps exactly such a row on purpose (tests/20_fixtures.sql, request
-- 20000000-0000-4000-8000-000000000004) to prove respond_pairing_request
-- answers code_expired.
--
-- The lock key is the (child, family, parent) triple, hashed into a bigint.
-- Callers that could contend for the same live request therefore queue on the
-- same key, and the read + insert becomes one serialised step. The lock is
-- transaction-scoped, so it is released when the RPC's transaction ends; a
-- different parent or family uses a different key and is never blocked.

-- ---------------------------------------------------------------------------
-- Child ID invite: mint the internal token and the request together.
-- ---------------------------------------------------------------------------
create or replace function private.create_pairing_invite(
  p_child_user_id uuid,
  p_family_id uuid,
  p_parent_user_id uuid,
  p_code_hash text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_request public.pairing_requests;
  v_token_id uuid;
begin
  if p_child_user_id is null or p_family_id is null or p_parent_user_id is null then
    raise exception 'invalid_pairing_invite' using errcode = '22023';
  end if;
  if p_code_hash is null or p_code_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_code_hash' using errcode = '22023';
  end if;
  if p_expires_at is null then
    raise exception 'invalid_expiry' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_child_user_id::text || ':' || p_family_id::text || ':' || p_parent_user_id::text,
      0
    )
  );

  select * into v_request
  from public.pairing_requests
  where child_user_id = p_child_user_id
    and family_id = p_family_id
    and parent_user_id = p_parent_user_id
    and status = 'pending_child'
    and expires_at > now()
  order by created_at desc
  limit 1;
  if found then
    return jsonb_build_object('created', false, 'request', to_jsonb(v_request));
  end if;

  insert into public.device_pairing_tokens (
    child_user_id, code_hash, expires_at, status, purpose, created_by
  )
  values (
    p_child_user_id, p_code_hash, p_expires_at, 'active', 'invite', p_parent_user_id
  )
  returning id into v_token_id;

  insert into public.pairing_requests (
    token_id, family_id, parent_user_id, child_user_id, status, expires_at
  )
  values (
    v_token_id, p_family_id, p_parent_user_id, p_child_user_id,
    'pending_child', p_expires_at
  )
  returning * into v_request;

  return jsonb_build_object('created', true, 'request', to_jsonb(v_request));
end;
$$;

-- ---------------------------------------------------------------------------
-- Legacy code redemption: the child's token already exists and was validated
-- by the caller, so only the request row is created here.
-- ---------------------------------------------------------------------------
create or replace function private.create_pairing_request(
  p_child_user_id uuid,
  p_family_id uuid,
  p_parent_user_id uuid,
  p_token_id uuid,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_request public.pairing_requests;
begin
  if p_child_user_id is null or p_family_id is null
     or p_parent_user_id is null or p_token_id is null then
    raise exception 'invalid_pairing_request' using errcode = '22023';
  end if;
  if p_expires_at is null then
    raise exception 'invalid_expiry' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_child_user_id::text || ':' || p_family_id::text || ':' || p_parent_user_id::text,
      0
    )
  );

  select * into v_request
  from public.pairing_requests
  where child_user_id = p_child_user_id
    and family_id = p_family_id
    and parent_user_id = p_parent_user_id
    and status = 'pending_child'
    and expires_at > now()
  order by created_at desc
  limit 1;
  if found then
    return jsonb_build_object('created', false, 'request', to_jsonb(v_request));
  end if;

  insert into public.pairing_requests (
    token_id, family_id, parent_user_id, child_user_id, status, expires_at
  )
  values (
    p_token_id, p_family_id, p_parent_user_id, p_child_user_id,
    'pending_child', p_expires_at
  )
  returning * into v_request;

  return jsonb_build_object('created', true, 'request', to_jsonb(v_request));
exception
  when unique_violation then
    -- pairing_requests.token_id is unique: the same token was redeemed
    -- concurrently for a different triple (a replay, not a duplicate inbox
    -- row). Keep the caller's existing 409 code for that case.
    raise exception 'code_unavailable' using errcode = 'P0001';
end;
$$;

-- ---------------------------------------------------------------------------
-- Public service-only wrappers (PostgREST exposes the public schema only).
-- ---------------------------------------------------------------------------
create or replace function public.create_pairing_invite(
  p_child_user_id uuid,
  p_family_id uuid,
  p_parent_user_id uuid,
  p_code_hash text,
  p_expires_at timestamptz
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.create_pairing_invite(
    p_child_user_id, p_family_id, p_parent_user_id, p_code_hash, p_expires_at
  );
$$;

create or replace function public.create_pairing_request(
  p_child_user_id uuid,
  p_family_id uuid,
  p_parent_user_id uuid,
  p_token_id uuid,
  p_expires_at timestamptz
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.create_pairing_request(
    p_child_user_id, p_family_id, p_parent_user_id, p_token_id, p_expires_at
  );
$$;

-- ---------------------------------------------------------------------------
-- Function privileges: service role only.
-- ---------------------------------------------------------------------------
revoke all on function private.create_pairing_invite(uuid, uuid, uuid, text, timestamptz)
  from public, anon, authenticated;
revoke all on function private.create_pairing_request(uuid, uuid, uuid, uuid, timestamptz)
  from public, anon, authenticated;
revoke all on function public.create_pairing_invite(uuid, uuid, uuid, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.create_pairing_request(uuid, uuid, uuid, uuid, timestamptz)
  from public, anon, authenticated;

grant execute on function private.create_pairing_invite(uuid, uuid, uuid, text, timestamptz)
  to service_role;
grant execute on function private.create_pairing_request(uuid, uuid, uuid, uuid, timestamptz)
  to service_role;
grant execute on function public.create_pairing_invite(uuid, uuid, uuid, text, timestamptz)
  to service_role;
grant execute on function public.create_pairing_request(uuid, uuid, uuid, uuid, timestamptz)
  to service_role;
