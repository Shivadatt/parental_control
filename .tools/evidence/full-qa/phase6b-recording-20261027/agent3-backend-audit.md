# Agent 3 — Backend audit: recording support (phase6b, 2026-10-27)

Scope: supabase/migrations/*.sql (all 5, read fully), supabase/functions/*,
supabase/tests/*, supabase/config.toml, scripts/complete_hosted_setup.sh,
docs/backend.md, docs/api-contract.md, lib/ grep, live read-only DB probe.

## VERDICT: NOT IMPLEMENTED

There is zero recording support in the backend: no table, no column, no enum,
no storage bucket, no RLS policy, no Edge Function, and no contract language
for recordings/screenshots/media clips. This is deliberate — the project
contracts forbid it (see "Explicit out-of-scope statements" below).

## 1. Schema map (18 tables, all in `public`, all RLS-enabled)

From 20260101000000_core.sql (only file creating tables):

| Table | Key columns (abridged) |
|---|---|
| profiles | id uuid PK ->auth.users (cascade), role ('unset'/'parent'/'child'), display_name, created/updated_at |
| families | id, name, owner_id ->profiles, settings jsonb (`{"location_retention_days":30,"usage_retention_days":90}`), deleted_at (soft delete); partial unique: one active family per owner |
| family_members | id, family_id (cascade), user_id (cascade), role ('parent'/'child'), status ('active'/'removed'), removed_at; partial unique: one active family per child |
| devices | id, family_id, child_user_id, installation_id, display_name, platform, android/app_version, status ('pending'/'active'/'revoked'), secret_hash (sha256 hex, service-only), credential_issued/revoked_at, last_seen_at, battery_level, is_charging, enforcement_mode ('none'/'device_admin'/'device_owner'), policy_version, *_granted booleans incl. **camera_granted, microphone_granted**; partial unique: one active device per child |
| device_pairing_tokens | id, child_user_id, code_hash, expires_at, redeemed_at/by, status ('active'/'redeemed'/'revoked'/'expired'), attempts/max_attempts |
| pairing_requests | id, token_id (unique), family_id, parent/child_user_id, status ('pending_child'/'approved'/'rejected'/'cancelled'/'expired'), expires_at, responded_at |
| device_policies | id, device_id, family_id, version, policy jsonb, created_by, acknowledged_at, enforcement_status ('pending'/'enforced'/'failed'/'unsupported'), last_error; unique (device_id, version) |
| device_commands | id, device_id, family_id, type ('apply_policy'/'sync_policy'/'request_usage'/'request_location'/'end_session'/'custom'), payload jsonb, status ('pending'/'delivered'/'succeeded'/'failed'/'expired'), idempotency_key, expires_at, delivered/acked_at, result jsonb, error_message, attempts |
| usage_daily | id, device_id, family_id, day, package_name, app_label, total_ms bigint, last_used_at, uploaded_at, source; unique (device, day, package) |
| location_events | id, device_id, family_id, lat/lng, accuracy_m, recorded_at, received_at, source |
| safe_zones | id, family_id, name, lat/lng, radius_m, active, created_by |
| safe_zone_states | (zone_id, device_id) PK, inside bool, updated_at |
| safety_alerts | id, family_id, device_id, type ('low_battery'/'offline'/'geofence_enter'/'geofence_exit'/'app_blocked'/'permission_missing'/'other'), severity ('info'/'warning'/'critical'), message, payload jsonb, acknowledged_at/by |
| remote_sessions | id, family_id, device_id, parent/child_user_id, **kind ('audio'/'video')**, status ('requested'/'accepted'/'active'/'declined'/'ended'/'expired'/'failed'), requested/accepted/started/ended/expires_at, ended_by/reason, consent_recorded bool, session_nonce |
| webrtc_signals | id, session_id (cascade), from_user_id (default auth.uid()), kind ('offer'/'answer'/'ice'), payload jsonb **capped 16 KiB**, sequence identity |
| audit_logs | id, family_id/actor_user_id/device_id (all `on delete set null`), event_type, target_type/id, metadata jsonb, created_at; append-only trigger |
| device_apps | id, device_id, family_id, package_name, label, is_system, is_suspended, version_name, reported_at; unique (device, package) |
| pairing_attempts | id, parent_user_id, code_hash, attempted_at, success (rate-limit bookkeeping) |

Recording-specific answers:
- NO `recordings` / `screen_captures` / `media_clips` / `video_assets` table anywhere.
- NO byte-storage column: `grep bytea` over all migrations = 0 hits. Only jsonb/text
  metadata exists; nothing can hold media bytes in Postgres today.
- NO recording-related enum or CHECK value. Closest matches, both misdirections:
  `remote_sessions.kind IN ('audio','video')` = live WebRTC call type, no persistence
  of media; `devices.camera_granted`/`microphone_granted` = permission flags only;
  `consent_recorded` = consent boolean for a live session. `device_commands.type`
  has no capture/start_recording-style value ('custom' is the only generic slot).

## 2. Storage buckets

- Migrations/tests: zero references to `storage`, `buckets`, or any bucket id.
- Dart (lib/): zero `.storage` / bucket usage (grep). The `storage_client` entry in
  pubspec.lock is a transitive dependency of supabase_flutter, unused.
- supabase/config.toml: `[storage] enabled = true, file_size_limit = "50MiB"` —
  local CLI default only; proves nothing about the hosted project.
- Hosted project: a read-only probe of `storage.buckets` could not be completed
  (see §5), so bucket inventory of the live project is **NOT TESTED**; there is no
  evidence any recordings bucket (or any custom bucket) was ever created —
  docs/backend.md's hosted verification record never mentions Storage.
- Existing access pattern for bytes/media: **none at all**. All data is structured
  rows via PostgREST/Edge Functions; the only binary-ish flow is WebRTC P2P media
  (never stored server-side; signaling capped at 16 KiB JSON per message).

## 3. RLS model (20260101000200_rls.sql)

Family isolation is enforced through four SECURITY DEFINER boolean helpers in
schema `private` (core.sql lines 571-639), executed as the caller but not
re-entering family_members RLS, all keyed on `auth.uid()` + active membership +
`families.deleted_at is null`:

- `private.is_family_member(uuid)` — active member of family
- `private.is_family_parent(uuid)` — active **parent** member of family
- `private.shares_active_family(uuid)` — another user in my active family
- `private.realtime_topic_allowed(text)` — topic-scoped gate for private channels

Design rules (file header): no client DELETE policies except safe_zones;
service-only tables (`device_pairing_tokens`, `safe_zone_states`,
`pairing_attempts`) get RLS enabled with **zero policies** and **zero grants**;
anon gets no table privileges; grants are column-where sensitive (devices omits
`secret_hash`, `installation_id` from authenticated SELECT). All writes go
through service-role Edge Functions calling `SECURITY DEFINER` RPCs.

The three policies a future `recordings` table must mirror:

```sql
-- (1) telemetry read pattern (usage_daily/location_events/safety_alerts identical):
create policy usage_daily_select_parent_or_child on public.usage_daily
  for select to authenticated
  using (private.is_family_parent(family_id) or exists (
    select 1 from public.devices d
    where d.id = device_id and d.child_user_id = auth.uid()));

-- (2) live-session participant pattern (remote_sessions):
create policy remote_sessions_select_participants on public.remote_sessions
  for select to authenticated
  using (parent_user_id = auth.uid() or child_user_id = auth.uid()
         or private.is_family_parent(family_id));

-- (3) time-bounded participant scope (webrtc_signals SELECT):
using (exists (select 1 from public.remote_sessions s
  where s.id = session_id and s.status in ('accepted','active')
    and s.expires_at > now()
    and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid())));
```

## 4. Edge Functions (9, all deployed per docs/backend.md §Hosted record)

| Function | verify_jwt | Actions / purpose |
|---|---|---|
| auth-bootstrap | on | set_role, create_family |
| pairing | on | create/redeem/pending_child/respond/cancel/list_family/unlink |
| device-register | on | enrollment + credential issuance (device headers) |
| device-policy | on | policy fetch/ack |
| family-admin | on | revoke_device, ack_alert, **purge_data**, **update_retention**, recover_device |
| remote-session | on | request/pending_child/respond/start/end/ice (ephemeral TURN creds) |
| device-command | off | create (parent JWT) / poll / ack (device-secret auth) |
| device-telemetry | off | heartbeat/usage_upload/location_upload/apps_upload (device-secret auth) |
| cron | off | expire_sessions, detect_offline (x-cron-secret; **CRON_SECRET not set → disabled**) |

None does upload/download of binary media. Closest candidates for reuse:
`remote-session` (already authorizes consented audio/video participant pairs and
hands out ephemeral TURN) and `device-telemetry` (already authenticates devices
by `x-device-id`/`x-device-secret` constant-time SHA-256 check — the natural auth
path for a device pushing captured media). A recording feature would need a NEW
function (or new actions on these) for signed-upload-URL minting; nothing
existing can serve it today.

## 5. Drift check (migrations vs hosted)

- Attempted live read-only probe via `.tools/pgsql16` psql against
  `db.<project-ref>.supabase.co:5432` using the password in
  `.tools/supabase-db-password.txt` (referenced by name only; network path
  reached the server). Result: **FATAL: password authentication failed for user
  "postgres"** — the local-drill password does not match the hosted project, and
  no other DB credential is available by design (docs/backend.md: "the
  service-role key and database password were never read, stored or printed").
- Hosted catalog (information_schema / pg_policies / storage.buckets) check is
  therefore **NOT TESTED**. No guessing: per docs/backend.md hosted verification
  record (2026-10-26/27), all five migrations were applied via the dashboard and
  a live RLS/Realtime probe passed; local SQL tests
  (`supabase/tests/10_schema.sql` etc.) assert the same 18-table schema. That is
  documented evidence, not independent confirmation. No drift evidence either way.

## 6. Retention / deletion machinery that exists today

1. **family-admin `purge_data`** (index.ts:157-227): parent-authorized manual
   delete of `location_events` (by `recorded_at`) and `usage_daily` (by `day`),
   with per-family **minimum keep windows** from `families.settings`
   (`location_retention_days` 1-365, `usage_retention_days` 1-730, via
   `update_retention`); audited as `data_purged`.
2. **`update_retention`**: owner-only settings writer, audited `settings_updated`.
3. **Cron RPCs**: `private.expire_stale_sessions()` (every 5 min) and
   `private.detect_offline_devices()` (10 min) — pg_cron schedules guarded; on
   the hosted project `CRON_SECRET` is unset so the Edge cron is disabled and
   pg_cron jobs were "not exercised" per docs.
4. **Revocation cascades**: `private.unlink_child` and `private.revoke_device`
   atomically revoke device credentials (null secret_hash), end open
   remote_sessions (`ended_reason='member_unlinked'/'device_revoked'`), revoke
   pairing tokens, cancel pending requests, audit. FK `on delete cascade` chains
   family→members/devices→telemetry/commands/policies/signals; `profiles` cascades
   from `auth.users`; audit_logs only `set null` (survives subject deletion).
5. **audit_logs**: append-only for clients (trigger `audit_logs_append_only`);
   UPDATE/DELETE allowed only for service context ("retention jobs") — but **no
   audit-purge job exists today**; nothing ever deletes audit rows.
6. **Soft delete**: only `families.deleted_at`; hidden from RLS SELECT.

Recording retention would have to integrate with: purge_data cutoffs (pattern 1),
unlink_child/revoke_device cascades (a recordings row keyed by device/family is
auto-deleted by FK cascade only if declared `on delete cascade`; audit rows must
keep `set null` semantics), and a real scheduled purge (none exists; pg_cron is
the documented hook).

## 7. PROPOSAL — backend change list for recording support

NOT existing state; sketch for the implementation plan. Every name here is new.

### 7.1 Migration sketch `20260102000000_recordings.sql`

```sql
create table public.recordings (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  child_user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null unique            -- 'recordings/<family_id>/<recording_id>.<ext>'
    check (char_length(storage_path) between 10 and 512),
  kind text not null check (kind in ('screen_capture','video_clip','audio_clip')),
  mime_type text not null, size_bytes bigint not null check (size_bytes between 1 and 52428800),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  started_at timestamptz not null, ended_at timestamptz,
  status text not null default 'uploading'
    check (status in ('uploading','available','expired','deleted','failed')),
  consent_recorded boolean not null default false,   -- mirror remote_sessions gate
  session_id uuid references public.remote_sessions (id) on delete set null,
  trigger text not null default 'manual'
    check (trigger in ('manual','schedule','alert')),
  retention_days integer not null default 7 check (retention_days between 1 and 90),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index recordings_family_created_idx on public.recordings (family_id, created_at desc);
create index recordings_expiry_idx on public.recordings (expires_at) where deleted_at is null;
-- NEVER store bytes in Postgres; metadata + Storage object only.
```

### 7.2 Storage bucket sketch

```sql
insert into storage.buckets (id, name, public) values ('recordings','recordings', false);
```

- Private bucket; no public policies. All client access via **signed URLs**
  minted server-side (Edge Function), never `createSelectiveObject`-style direct
  client access. Path constraint `<family_id>/<recording_id>.*` so storage
  policies can scope by family prefix.
- Storage RLS (storage.objects) sketch: service_role does all reads/writes;
  one SELECT policy `to authenticated` using family-prefix check backed by
  `private.is_family_parent(recordings row)`; or simpler: leave clients with zero
  storage policies and serve everything through signed URLs.

### 7.3 RLS sketch (mirror §3 patterns)

```sql
alter table public.recordings enable row level security;
create policy recordings_select_parent_or_owner on public.recordings
  for select to authenticated
  using (private.is_family_parent(family_id)
         or (child_user_id = auth.uid() and status = 'available'));
-- NO client insert/update/delete policies: writes only via service-role Edge
-- Function + SECURITY DEFINER RPCs (project's established rule).
grant select (id, family_id, device_id, child_user_id, kind, mime_type, size_bytes,
  started_at, ended_at, status, consent_recorded, trigger, expires_at, created_at)
  on public.recordings to authenticated;   -- omit storage_path/sha256 from clients
```

### 7.4 Functions / RPCs / cron sketch

- `private.create_recording(...)` + `public.` wrapper (service-role only),
  returning the storage path; `private.finalize_recording(id, sha256, size)`
  verifying the uploaded object; audit events `recording_created/consumed/deleted`
  via `private.record_audit`.
- New Edge Function `recording` (verify_jwt on, like remote-session) with actions:
  `grant_upload` (device-auth or consented parent; mints 5-min signed upload URL,
  enforces size limit + consent), `list` (family parent), `play_link` (mints
  60-second signed URL, requires consent + audits every view), `delete`.
- Retention: extend `private.expire_stale_sessions` style with
  `private.purge_expired_recordings()` deleting rows past `expires_at` **and**
  their Storage objects (Edge cron action `purge_recordings`, since pg_cron
  cannot touch Storage); fold recordings into `family-admin.purge_data`
  (new `recording_retention_days` in `families.settings`); rely on FK cascade in
  `unlink_child`/`revoke_device` for subject-driven deletion.
- Realtime: add `recordings` to `supabase_realtime` only if the parent app needs
  push; extend `private.realtime_topic_allowed` with a `recordings:<familyId>`
  kind → `private.is_family_parent`.

### 7.5 Policy/approval caveats

- README.md line 98 and docs/api-contract.md §7 (lines 545-546) explicitly commit
  to "no hidden recording, covert capture… no screenshots, no recording"; the
  child/parent UI texts in lib/features/** (child_settings_tab.dart:65,
  remote_session_page.dart:120, remote_assistance_page.dart:70) promise "nothing
  is recorded". Shipping recordings REQUIRES changing these contract/UI claims
  plus Play-policy review (covert screen capture is a store-violation class).

## Explicit out-of-scope statements (evidence)

- docs/api-contract.md:545-46 — "No … hidden capture, … no screenshots, … no recording."
- README.md:98 — "There is no hidden recording, covert capture…"
- remote_sessions/webrtc signals carry no media server-side; `webrtc_signals.payload`
  capped 16 KiB.
- No `recordings`|`screen_capture`|`media_clip`|`video_asset` token exists in any
  .sql, functions/*.ts, or lib/*.dart file (case-insensitive grep).
