-- Parent Control — core schema.
-- Authoritative contract: docs/api-contract.md sections 3-4.
-- All user references point at public.profiles(id) so PostgREST can embed
-- display names; profiles itself cascades from auth.users.

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon, authenticated;

-- The service role (Edge Functions) and the owner need access to private RPCs.
grant usage on schema private to service_role;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'unset'
    check (role in ('unset', 'parent', 'child')),
  display_name text not null
    check (char_length(display_name) between 1 and 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Application profile. Created by trigger on auth.users; role is set once by an Edge Function.';

-- ---------------------------------------------------------------------------
-- families
-- ---------------------------------------------------------------------------
create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  settings jsonb not null
    default '{"location_retention_days":30,"usage_retention_days":90}'::jsonb
    check (jsonb_typeof(settings) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.families is
  'A family owned by exactly one parent account. Soft-deleted with deleted_at.';

create unique index families_one_active_per_owner
  on public.families (owner_id)
  where deleted_at is null;

-- ---------------------------------------------------------------------------
-- family_members
-- ---------------------------------------------------------------------------
create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('parent', 'child')),
  status text not null default 'active' check (status in ('active', 'removed')),
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  constraint family_members_family_user_key unique (family_id, user_id),
  constraint family_members_removed_consistency
    check ((status = 'removed') = (removed_at is not null))
);

-- A child account can belong to only one active family at a time.
create unique index family_members_one_active_child_family
  on public.family_members (user_id)
  where status = 'active' and role = 'child';

create index family_members_family_id_idx on public.family_members (family_id);
create index family_members_user_id_idx on public.family_members (user_id);

-- ---------------------------------------------------------------------------
-- devices
-- ---------------------------------------------------------------------------
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  child_user_id uuid not null references public.profiles (id) on delete cascade,
  installation_id text not null
    check (char_length(installation_id) between 8 and 128),
  display_name text not null
    check (char_length(display_name) between 1 and 80),
  platform text not null default 'android'
    check (char_length(platform) between 1 and 32),
  android_version text check (android_version is null or char_length(android_version) between 1 and 40),
  app_version text check (app_version is null or char_length(app_version) between 1 and 40),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'revoked')),
  secret_hash text
    check (secret_hash is null or secret_hash ~ '^[0-9a-f]{64}$'),
  credential_issued_at timestamptz,
  credential_revoked_at timestamptz,
  last_seen_at timestamptz,
  battery_level integer check (battery_level between 0 and 100),
  is_charging boolean,
  enforcement_mode text not null default 'none'
    check (enforcement_mode in ('none', 'device_admin', 'device_owner')),
  policy_version integer not null default 0 check (policy_version >= 0),
  usage_access_granted boolean,
  location_granted boolean,
  background_location_granted boolean,
  camera_granted boolean,
  microphone_granted boolean,
  notifications_granted boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint devices_family_installation_key unique (family_id, installation_id),
  constraint devices_revoked_credential_consistency
    check (status <> 'revoked' or secret_hash is null)
);

-- One active device per child account.
create unique index devices_one_active_per_child
  on public.devices (child_user_id)
  where status = 'active';

create index devices_family_id_idx on public.devices (family_id);
create index devices_child_user_id_idx on public.devices (child_user_id);
create index devices_status_idx on public.devices (status);

-- ---------------------------------------------------------------------------
-- device_pairing_tokens
-- ---------------------------------------------------------------------------
create table public.device_pairing_tokens (
  id uuid primary key default gen_random_uuid(),
  child_user_id uuid not null references public.profiles (id) on delete cascade,
  code_hash text not null unique
    check (code_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  redeemed_by uuid references public.profiles (id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'redeemed', 'revoked', 'expired')),
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 10 check (max_attempts > 0),
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null
);

create index device_pairing_tokens_child_idx
  on public.device_pairing_tokens (child_user_id, status);
create index device_pairing_tokens_expires_idx
  on public.device_pairing_tokens (expires_at);

-- ---------------------------------------------------------------------------
-- pairing_requests
-- ---------------------------------------------------------------------------
create table public.pairing_requests (
  id uuid primary key default gen_random_uuid(),
  token_id uuid not null unique
    references public.device_pairing_tokens (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  parent_user_id uuid not null references public.profiles (id) on delete cascade,
  child_user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending_child'
    check (status in ('pending_child', 'approved', 'rejected', 'cancelled', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz
);

create index pairing_requests_family_idx
  on public.pairing_requests (family_id, status);
create index pairing_requests_child_idx
  on public.pairing_requests (child_user_id, status);
create index pairing_requests_parent_idx
  on public.pairing_requests (parent_user_id, status);

-- ---------------------------------------------------------------------------
-- device_policies
-- ---------------------------------------------------------------------------
create table public.device_policies (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  version integer not null check (version >= 1),
  policy jsonb not null check (jsonb_typeof(policy) = 'object'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  enforcement_status text not null default 'pending'
    check (enforcement_status in ('pending', 'enforced', 'failed', 'unsupported')),
  last_error text check (last_error is null or char_length(last_error) <= 500),
  constraint device_policies_device_version_key unique (device_id, version)
);

create index device_policies_family_idx on public.device_policies (family_id);

-- ---------------------------------------------------------------------------
-- device_commands
-- ---------------------------------------------------------------------------
create table public.device_commands (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  type text not null
    check (type in ('apply_policy', 'sync_policy', 'request_usage', 'request_location',
                    'end_session', 'custom')),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending'
    check (status in ('pending', 'delivered', 'succeeded', 'failed', 'expired')),
  idempotency_key text not null
    check (char_length(idempotency_key) between 1 and 128),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  delivered_at timestamptz,
  acked_at timestamptz,
  result jsonb,
  error_message text check (error_message is null or char_length(error_message) <= 500),
  attempts integer not null default 0 check (attempts >= 0),
  constraint device_commands_device_idempotency_key
    unique (device_id, idempotency_key)
);

create index device_commands_device_status_idx
  on public.device_commands (device_id, status, created_at);
create index device_commands_expires_idx on public.device_commands (expires_at);

-- ---------------------------------------------------------------------------
-- usage_daily
-- ---------------------------------------------------------------------------
create table public.usage_daily (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  day date not null,
  package_name text not null
    check (char_length(package_name) between 1 and 150),
  app_label text not null default ''
    check (char_length(app_label) <= 100),
  total_ms bigint not null check (total_ms >= 0),
  last_used_at timestamptz,
  uploaded_at timestamptz not null default now(),
  source text not null default 'usage_stats'
    check (char_length(source) between 1 and 32),
  constraint usage_daily_device_day_package_key unique (device_id, day, package_name)
);

create index usage_daily_family_day_idx on public.usage_daily (family_id, day);
create index usage_daily_device_idx on public.usage_daily (device_id, day);

-- ---------------------------------------------------------------------------
-- location_events
-- ---------------------------------------------------------------------------
create table public.location_events (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  accuracy_m real not null check (accuracy_m >= 0),
  recorded_at timestamptz not null,
  received_at timestamptz not null default now(),
  source text not null default 'device'
    check (char_length(source) between 1 and 40)
);

create index location_events_device_recorded_idx
  on public.location_events (device_id, recorded_at desc);
create index location_events_family_recorded_idx
  on public.location_events (family_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- safe_zones / safe_zone_states
-- ---------------------------------------------------------------------------
create table public.safe_zones (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  radius_m double precision not null check (radius_m between 50 and 5000),
  active boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index safe_zones_family_idx on public.safe_zones (family_id);

create table public.safe_zone_states (
  zone_id uuid not null references public.safe_zones (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  inside boolean not null,
  updated_at timestamptz not null default now(),
  primary key (zone_id, device_id)
);

-- ---------------------------------------------------------------------------
-- safety_alerts
-- ---------------------------------------------------------------------------
create table public.safety_alerts (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  type text not null
    check (type in ('low_battery', 'offline', 'geofence_enter', 'geofence_exit',
                    'app_blocked', 'permission_missing', 'other')),
  severity text not null check (severity in ('info', 'warning', 'critical')),
  message text not null check (char_length(message) between 1 and 300),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid references public.profiles (id) on delete set null
);

create index safety_alerts_family_created_idx
  on public.safety_alerts (family_id, created_at desc);
create index safety_alerts_device_type_created_idx
  on public.safety_alerts (device_id, type, created_at desc);

-- ---------------------------------------------------------------------------
-- remote_sessions
-- ---------------------------------------------------------------------------
create table public.remote_sessions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  parent_user_id uuid not null
    constraint remote_sessions_parent_user_id_fkey
    references public.profiles (id) on delete cascade,
  child_user_id uuid not null
    constraint remote_sessions_child_user_id_fkey
    references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('audio', 'video')),
  status text not null default 'requested'
    check (status in ('requested', 'accepted', 'active', 'declined',
                      'ended', 'expired', 'failed')),
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  expires_at timestamptz not null,
  ended_by uuid references public.profiles (id) on delete set null,
  ended_reason text check (ended_reason is null or char_length(ended_reason) <= 200),
  consent_recorded boolean not null default false,
  session_nonce uuid,
  created_at timestamptz not null default now()
);

create index remote_sessions_family_idx
  on public.remote_sessions (family_id, requested_at desc);
create index remote_sessions_child_status_idx
  on public.remote_sessions (child_user_id, status);
create index remote_sessions_device_status_idx
  on public.remote_sessions (device_id, status);
create index remote_sessions_expires_idx on public.remote_sessions (expires_at);

-- ---------------------------------------------------------------------------
-- webrtc_signals
-- ---------------------------------------------------------------------------
create table public.webrtc_signals (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.remote_sessions (id) on delete cascade,
  from_user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('offer', 'answer', 'ice')),
  payload jsonb not null check (octet_length(payload::text) <= 16384),
  created_at timestamptz not null default now(),
  sequence bigint generated always as identity
);

create index webrtc_signals_session_sequence_idx
  on public.webrtc_signals (session_id, sequence);

-- ---------------------------------------------------------------------------
-- audit_logs
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families (id) on delete set null,
  actor_user_id uuid references public.profiles (id) on delete set null,
  device_id uuid references public.devices (id) on delete set null,
  event_type text not null check (char_length(event_type) between 1 and 80),
  target_type text check (target_type is null or char_length(target_type) <= 40),
  target_id text check (target_id is null or char_length(target_id) <= 128),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index audit_logs_family_created_idx
  on public.audit_logs (family_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- device_apps
-- ---------------------------------------------------------------------------
create table public.device_apps (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  package_name text not null
    check (char_length(package_name) between 1 and 150),
  label text not null default '' check (char_length(label) <= 100),
  is_system boolean not null default false,
  is_suspended boolean not null default false,
  version_name text check (version_name is null or char_length(version_name) <= 64),
  reported_at timestamptz not null default now(),
  constraint device_apps_device_package_key unique (device_id, package_name)
);

create index device_apps_family_idx on public.device_apps (family_id);

-- ---------------------------------------------------------------------------
-- pairing_attempts
-- ---------------------------------------------------------------------------
create table public.pairing_attempts (
  id uuid primary key default gen_random_uuid(),
  parent_user_id uuid not null references public.profiles (id) on delete cascade,
  code_hash text not null check (code_hash ~ '^[0-9a-f]{64}$'),
  attempted_at timestamptz not null default now(),
  success boolean not null default false
);

create index pairing_attempts_parent_idx
  on public.pairing_attempts (parent_user_id, attempted_at desc);
create index pairing_attempts_code_idx
  on public.pairing_attempts (code_hash, attempted_at desc);

-- ---------------------------------------------------------------------------
-- Generic updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger families_set_updated_at
  before update on public.families
  for each row execute function private.set_updated_at();

create trigger devices_set_updated_at
  before update on public.devices
  for each row execute function private.set_updated_at();

create trigger safe_zone_states_set_updated_at
  before update on public.safe_zone_states
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Profile creation from auth.users
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Profile role is set once; only service context may change it afterwards.
-- ---------------------------------------------------------------------------
create or replace function private.profiles_before_update()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
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

create trigger profiles_before_update
  before update on public.profiles
  for each row execute function private.profiles_before_update();

-- Family ownership cannot be reassigned by clients.
create or replace function private.families_before_update()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
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

create trigger families_before_update
  before update on public.families
  for each row execute function private.families_before_update();

-- ---------------------------------------------------------------------------
-- audit_logs is append-only except for service context (retention jobs).
-- ---------------------------------------------------------------------------
create or replace function private.audit_logs_append_only()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
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

create trigger audit_logs_append_only
  before update or delete on public.audit_logs
  for each row execute function private.audit_logs_append_only();

-- ---------------------------------------------------------------------------
-- RLS helpers (SECURITY DEFINER so family_members RLS is not re-entered).
-- The predicates only expose booleans and use auth.uid().
-- ---------------------------------------------------------------------------
create or replace function private.is_family_member(p_family_id uuid)
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
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

create or replace function private.is_family_parent(p_family_id uuid)
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
    where m.family_id = p_family_id
      and m.user_id = auth.uid()
      and m.role = 'parent'
      and m.status = 'active'
      and f.deleted_at is null
  );
$$;

create or replace function private.shares_active_family(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
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

-- NOTE (contract deviation, reported): RLS policy expressions are evaluated
-- with the caller's privileges, so `authenticated` needs EXECUTE on the three
-- boolean helpers above. They are still revoked from anon and PUBLIC. RPCs and
-- table-changing private functions remain revoked from anon/authenticated.
grant usage on schema private to authenticated;
grant execute on function private.is_family_member(uuid) to authenticated;
grant execute on function private.is_family_parent(uuid) to authenticated;
grant execute on function private.shares_active_family(uuid) to authenticated;

revoke all on function private.is_family_member(uuid) from public, anon;
revoke all on function private.is_family_parent(uuid) from public, anon;
revoke all on function private.shares_active_family(uuid) from public, anon;
