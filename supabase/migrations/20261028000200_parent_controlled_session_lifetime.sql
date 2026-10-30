-- Parent-controlled remote-session lifetime.
--
-- Policy after this migration:
--   * `expires_at` is a PENDING-REQUEST deadline only. A `requested` row must
--     have one; an accepted/active row is released from it on consent.
--   * An accepted/active session has no fixed expiry. It ends when the
--     authenticated parent explicitly ends it, or when an administrative
--     action (device revocation, member unlink) ends it with its own reason.
--     Elapsed time alone never terminates it, and the cron job below no longer
--     touches consented rows.
--   * TURN credential lifetime (`TURN_TTL_SECONDS`, default 600 s) is unrelated
--     to session lifetime: the `ice` action issues fresh ephemeral credentials
--     per call and the client refreshes them on reconnection.
--   * Temporary media loss is not a terminal state. Only the server status
--     transitions listed here change the session.
--
-- Backward compatibility: terminal history is not rewritten. Currently open
-- consented rows keep their row and consent but lose the obsolete deadline, so
-- they become parent-controlled from the moment this migration applies.
--
-- Rollback:
--   drop trigger remote_sessions_transition_guard on public.remote_sessions;
--   drop function private.remote_session_transition_guard();
--   delete from public.remote_sessions where status in ('accepted','active')
--     and expires_at is null;  -- impossible to restore a deadline cleanly
--   alter table public.remote_sessions
--     drop constraint remote_sessions_pending_expiry_check;
--   alter table public.remote_sessions alter column expires_at set not null;
--   -- then re-create the previous bodies of private.expire_stale_sessions()
--   -- and public.request_remote_session(uuid, uuid, text) from
--   -- 20260101000100_functions.sql / 20261028000100_remote_session_concurrency.sql.
--   The data step cannot be rolled back losslessly; a deadline was not real
--   information once the session had been consented to.

alter table public.remote_sessions
  alter column expires_at drop not null;

-- Pending requests must still time out. Consented and terminal rows may keep
-- NULL (the new policy) or a historical timestamp.
alter table public.remote_sessions
  add constraint remote_sessions_pending_expiry_check
  check (status <> 'requested' or expires_at is not null);

-- Existing consented sessions become parent-controlled. Terminal history
-- (ended/declined/expired/failed) is intentionally untouched.
update public.remote_sessions
   set expires_at = null
 where status in ('accepted', 'active');

-- ---------------------------------------------------------------------------
-- Terminal rows are immutable: a client or a bug must not revive an ended or
-- expired session by reusing its id. Status may still move between terminal
-- values (for example a cleanup job normalising a reason).
-- ---------------------------------------------------------------------------
create or replace function private.remote_session_transition_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if OLD.status in ('declined', 'ended', 'expired', 'failed')
     and NEW.status in ('requested', 'accepted', 'active') then
    raise exception 'session_terminal' using errcode = 'P0001';
  end if;
  return NEW;
end;
$$;

drop trigger if exists remote_sessions_transition_guard
  on public.remote_sessions;
create trigger remote_sessions_transition_guard
  before update of status on public.remote_sessions
  for each row execute function private.remote_session_transition_guard();

-- ---------------------------------------------------------------------------
-- Scheduled cleanup: pending requests only. A consented session is never
-- expired by a clock.
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
  where status = 'requested'
    and expires_at is not null
    and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Request guard: a stale *pending* request is cleaned in-lock; a consented
-- session is never silently ended to admit a new request, even when it carries
-- a legacy past deadline. The parent must end it first.
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
  from public;
revoke all on function public.request_remote_session(uuid, uuid, text)
  from anon, authenticated;
grant execute on function public.request_remote_session(uuid, uuid, text)
  to service_role;
