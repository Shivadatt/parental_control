-- Parent Control — atomic per-device remote-session request.
--
-- A parent could previously fire two "request" calls (double tap, retry, two
-- parents) and both would pass the Edge Function's checks and INSERT, leaving
-- two open microphone/video sessions for one child device. The guard here is a
-- transaction-scoped advisory lock keyed on the device id:
--
--   1. pg_advisory_xact_lock(hashtextextended(device_id, 0)) — concurrent
--      callers for the same device queue here, so the rest of this function is
--      one serialised step per device. Different devices hash to different keys
--      and never block each other.
--   2. Resolve the device (family_id, child_user_id) and reject missing or
--      non-active devices. The Edge Function already authorised the caller;
--      this is defence in depth for direct service-role calls.
--   3. Expire stale open rows for that device (status requested/accepted/active
--      with expires_at <= now()) before the check, so an expired request can
--      never block a legitimate new one. History is preserved: the old row is
--      moved to 'expired', not deleted.
--   4. If any open row remains, raise 'session_in_progress'. This is an
--      exception, so the whole RPC (including step 3 if it ran late) rolls
--      back: a valid session is never silently ended to admit a new one, and
--      the caller gets 409.
--   5. Otherwise insert the new 'requested' row with a 10-minute expiry.
--
-- Why not a partial unique index on status: the index predicate cannot
-- reference now(), so an open row whose expires_at has passed would keep
-- blocking inserts until some other process cleaned it up, and there is no
-- cleanup trigger. Expiry is therefore evaluated in-lock above; the advisory
-- lock plus the in-lock expiry is the atomic guard. The lock is released when
-- the transaction ends, so nothing is leaked on error.
--
-- Rollback:
--   drop function public.request_remote_session(uuid, uuid, text);
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
    and status in ('requested', 'accepted', 'active')
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

-- Service role only: the Edge Function is the only caller and it applies the
-- user/parent/device authorization before invoking this defence-in-depth RPC.
revoke all on function public.request_remote_session(uuid, uuid, text)
  from public;
revoke all on function public.request_remote_session(uuid, uuid, text)
  from anon, authenticated;

grant execute on function public.request_remote_session(uuid, uuid, text)
  to service_role;
