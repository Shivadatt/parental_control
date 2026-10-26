-- Parent Control — row level security and grants.
-- Rules: no client DELETE policies; service-only tables have RLS enabled and no
-- policies; anon gets no table privilege at all.

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.devices enable row level security;
alter table public.device_pairing_tokens enable row level security;
alter table public.pairing_requests enable row level security;
alter table public.device_policies enable row level security;
alter table public.device_commands enable row level security;
alter table public.usage_daily enable row level security;
alter table public.location_events enable row level security;
alter table public.safe_zones enable row level security;
alter table public.safe_zone_states enable row level security;
alter table public.safety_alerts enable row level security;
alter table public.remote_sessions enable row level security;
alter table public.webrtc_signals enable row level security;
alter table public.audit_logs enable row level security;
alter table public.device_apps enable row level security;
alter table public.pairing_attempts enable row level security;

-- ---------------------------------------------------------------------------
-- policies: profiles
-- ---------------------------------------------------------------------------
create policy profiles_select_self_or_family
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid() or private.shares_active_family(id));

create policy profiles_update_self
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- policies: families
-- ---------------------------------------------------------------------------
create policy families_select_members
  on public.families
  for select
  to authenticated
  using (deleted_at is null and private.is_family_member(id));

create policy families_update_owner
  on public.families
  for update
  to authenticated
  using (owner_id = auth.uid() and deleted_at is null)
  with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- policies: family_members
-- ---------------------------------------------------------------------------
create policy family_members_select_family
  on public.family_members
  for select
  to authenticated
  using (private.is_family_member(family_id));

-- ---------------------------------------------------------------------------
-- policies: devices
-- ---------------------------------------------------------------------------
create policy devices_select_parent_or_child
  on public.devices
  for select
  to authenticated
  using (private.is_family_parent(family_id) or child_user_id = auth.uid());

-- device_pairing_tokens: service role only (no policies).

-- ---------------------------------------------------------------------------
-- policies: pairing_requests
-- ---------------------------------------------------------------------------
create policy pairing_requests_select_participants
  on public.pairing_requests
  for select
  to authenticated
  using (
    child_user_id = auth.uid()
    or parent_user_id = auth.uid()
    or private.is_family_parent(family_id)
  );

-- ---------------------------------------------------------------------------
-- policies: device_policies / device_commands
-- ---------------------------------------------------------------------------
create policy device_policies_select_parent_or_child
  on public.device_policies
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

create policy device_commands_select_parent_or_child
  on public.device_commands
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- policies: telemetry tables
-- ---------------------------------------------------------------------------
create policy usage_daily_select_parent_or_child
  on public.usage_daily
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

create policy location_events_select_parent_or_child
  on public.location_events
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

create policy device_apps_select_parent_or_child
  on public.device_apps
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- policies: safe_zones (family read, parent write)
-- ---------------------------------------------------------------------------
create policy safe_zones_select_family
  on public.safe_zones
  for select
  to authenticated
  using (private.is_family_member(family_id));

create policy safe_zones_insert_parent
  on public.safe_zones
  for insert
  to authenticated
  with check (private.is_family_parent(family_id));

create policy safe_zones_update_parent
  on public.safe_zones
  for update
  to authenticated
  using (private.is_family_parent(family_id))
  with check (private.is_family_parent(family_id));

create policy safe_zones_delete_parent
  on public.safe_zones
  for delete
  to authenticated
  using (private.is_family_parent(family_id));

-- safe_zone_states: service role only (no policies).

-- ---------------------------------------------------------------------------
-- policies: safety_alerts
-- ---------------------------------------------------------------------------
create policy safety_alerts_select_parent_or_child
  on public.safety_alerts
  for select
  to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- policies: remote_sessions
-- ---------------------------------------------------------------------------
create policy remote_sessions_select_participants
  on public.remote_sessions
  for select
  to authenticated
  using (
    parent_user_id = auth.uid()
    or child_user_id = auth.uid()
    or private.is_family_parent(family_id)
  );

-- ---------------------------------------------------------------------------
-- policies: webrtc_signals
-- Participants may read every signal of their own live session; they may only
-- insert rows authored by themselves. (The contract text also applied
-- from_user_id = auth.uid() to SELECT, which would make the remote party's
-- signals unreadable; reported as a deviation.)
-- ---------------------------------------------------------------------------
create policy webrtc_signals_select_participant
  on public.webrtc_signals
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.remote_sessions s
      where s.id = session_id
        and s.status in ('accepted', 'active')
        and s.expires_at > now()
        and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid())
    )
  );

create policy webrtc_signals_insert_participant
  on public.webrtc_signals
  for insert
  to authenticated
  with check (
    from_user_id = auth.uid()
    and exists (
      select 1
      from public.remote_sessions s
      where s.id = session_id
        and s.status in ('accepted', 'active')
        and s.expires_at > now()
        and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- policies: audit_logs
-- ---------------------------------------------------------------------------
create policy audit_logs_select_family_parent
  on public.audit_logs
  for select
  to authenticated
  using (family_id is not null and private.is_family_parent(family_id));

-- pairing_attempts: service role only (no policies).

-- ---------------------------------------------------------------------------
-- grants
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

grant select on public.families to authenticated;
grant update (name, settings) on public.families to authenticated;

grant select on public.family_members to authenticated;
-- Devices are read column-by-column: secret_hash and installation_id are
-- service-only. Table-wide SELECT would expose the credential hash.
grant select (
  id, family_id, child_user_id, display_name, platform, android_version,
  app_version, status, credential_issued_at, credential_revoked_at,
  last_seen_at, battery_level, is_charging, enforcement_mode, policy_version,
  usage_access_granted, location_granted, background_location_granted,
  camera_granted, microphone_granted, notifications_granted,
  created_at, updated_at
) on public.devices to authenticated;
grant select on public.pairing_requests to authenticated;
grant select on public.device_policies to authenticated;
grant select on public.device_commands to authenticated;
grant select on public.usage_daily to authenticated;
grant select on public.location_events to authenticated;
grant select on public.safety_alerts to authenticated;
grant select on public.remote_sessions to authenticated;
grant select on public.audit_logs to authenticated;
grant select on public.device_apps to authenticated;

grant select on public.safe_zones to authenticated;
grant insert (family_id, name, lat, lng, radius_m, active)
  on public.safe_zones to authenticated;
grant update (name, lat, lng, radius_m, active)
  on public.safe_zones to authenticated;
grant delete on public.safe_zones to authenticated;

grant select, insert on public.webrtc_signals to authenticated;

-- Service-only tables receive no grants at all:
--   device_pairing_tokens, safe_zone_states, pairing_attempts.
-- anon receives no table privileges at all.

-- ---------------------------------------------------------------------------
-- Realtime Authorization for private postgres_changes channels
-- ---------------------------------------------------------------------------
-- The app joins every channel with private: true, so Realtime checks this
-- policy before accepting the subscription. Table RLS still filters the rows.
create or replace function private.realtime_topic_allowed(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, private, pg_temp
as $$
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
$$;

revoke all on function private.realtime_topic_allowed(text)
  from public, anon, authenticated;
grant execute on function private.realtime_topic_allowed(text) to authenticated;

-- The realtime schema does not exist in a plain PostgreSQL test database.
do $$
begin
  if to_regclass('realtime.messages') is not null then
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'realtime'
        and tablename = 'messages'
        and policyname = 'parentcontrol_private_topics'
    ) then
      execute $ddl$
        create policy parentcontrol_private_topics
          on realtime.messages
          for select
          to authenticated
          using (
            realtime.messages.extension = 'postgres_changes'
            and private.realtime_topic_allowed(realtime.topic())
          )
      $ddl$;
    end if;
  else
    raise notice 'realtime.messages not found; private channel policy not created';
  end if;
end;
$$;
