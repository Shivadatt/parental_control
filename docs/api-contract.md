# Parent Control — implementation contract (authoritative for this build)

This file is the single source of truth shared by all implementation agents. Do not
change shared files listed as OWNER-owned. If a signature is missing, implement a
private helper in your own domain and report `NEEDS OWNER` instead of editing the
shared contract.

## 1. Environment / toolchain rules

- Pinned SDK: Flutter **3.44.6**, Dart **3.12.2**, FVM-managed at
  `C:\Users\ASUS\fvm\versions\3.44.6`.
- Dependencies are already installed. **Do not edit `pubspec.yaml`**, do not run
  `flutter pub get`, `flutter test`, `flutter build`, or any repo-wide analyzer.
- One scoped analyzer run per agent at the very end is allowed:
  `cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\dart.bat analyze lib/features/<your-dir> lib/data/repositories/<your-files> test/features/<your-dir>"`
  (omit paths that do not apply; this is ONE run — do not loop analyzer runs).
- Never delete, stub, or comment out existing widgets to silence an error. Never add
  `// ignore_for_file:` or edit `analysis_options.yaml`. Never fabricate success.
- Do not edit files outside your ownership block. Do not run destructive git commands.
- No mock/sample data presented as real. All screens must handle loading, error,
  empty, offline and permission-required states honestly.
- Android minimum SDK is 24, target/compile SDK 36, Java 17, AGP 9.0.1, Kotlin 2.3.20.

## 2. Shared client files (OWNER: lead agent — do not edit)

```
pubspec.yaml, analysis_options.yaml, .env.example, README.md
lib/main.dart
lib/app/routes/app_routes.dart
lib/app/routes/app_pages.dart              (written at integration)
lib/app/bindings/repository_binding.dart   (written at integration)
lib/app/app.dart                           (written at integration)
lib/core/**                                (config, errors, utils, theme, widgets)
lib/data/models/**
lib/data/services/**
lib/data/repositories/repository_contracts.dart
docs/api-contract.md
```

Available shared APIs (read the files before use):

- `Env` — `appName`, `qrScheme`, `supabaseUrl`, `supabaseAnonKey`, `defaultStunUrl`,
  `isBackendConfigured`.
- `AppException` / `AppErrorCodes` — typed failures. `AppException.native()`,
  `AppException.from()`, `error.message`, `error.isNetwork`, etc.
- JSON helpers: `jsonMap`, `jsonList`, `jsonString`, `jsonStringOr`, `jsonInt`,
  `jsonIntOr`, `jsonDouble`, `jsonBool`, `jsonBoolOr`, `jsonDate`, `jsonDateOr`,
  `jsonDateFromMillis`, `jsonStringList`, `withoutNulls`.
- Formatters: `formatDateTime`, `formatDate`, `formatTime`, `relativeTime`,
  `formatDurationMs`, `formatMinutes`, `formatBattery`, `formatTimeOfDayMinutes`.
- `Validators` — email, password, required, familyName, displayName, pairingCode,
  `normalizePairingCode`.
- Theme: `AppColors`, `AppTheme.light()`.
- Widgets (`package:parent_control/core/widgets/widgets.dart`):
  `AsyncStateView`, `LoadingState`, `ErrorState`, `EmptyState`, `AppButton`,
  `StatusChip` + `StatusTone`, `SectionCard`, `InfoBanner` + `BannerTone`,
  `AppTextField`, `ConfirmDialog.show(...)`, `PermissionStatusTile`, `KeyValueRow`,
  `PageSection`.
- Models: `Profile`, `ProfileRole`, `Family`, `FamilySettings`, `FamilyMember`,
  `PairingCode`, `PairingRequest`, `PairingRequestStatus`, `Device`, `DeviceStatus`,
  `DevicePolicy`, `PolicyPayload`, `AppRule`, `ScheduleWindow`,
  `PolicyEnforcementStatus`, `DeviceCommand`, `DeviceCommandType`,
  `DeviceCommandStatus`, `InstalledApp`, `DeviceCapabilities`, `DeviceIdentity`,
  `NativePolicyApplyResult`, `GuardianServiceStatus`, `BatteryStatus`,
  `UsageDaily`, `UsageStat`, `LocationFix`, `LocationEvent`, `SafeZone`,
  `SafetyAlert`, `SafetyAlertType`, `AlertSeverity`, `RemoteSession`, `SessionKind`,
  `RemoteSessionStatus`, `IceConfig`, `IceServerConfig`, `SignalKind`, `WebRtcSignal`,
  `AuditLogEntry`, `PolicyUpdateResult`.
- Repository interfaces: `lib/data/repositories/repository_contracts.dart`
  (`AuthRepository`, `FamilyRepository`, `PairingRepository`, `DeviceRepository`,
  `PolicyRepository`, `UsageRepository`, `LocationRepository`, `AlertRepository`,
  `RemoteSessionRepository`, `AuditRepository`).
- Services available with `Get.find`:
  `SupabaseService` (`client`, `isConfigured`, `isReady`, `initError`),
  `EdgeApi` (`invoke`, `invokeMap`, `invokeList`), `SessionService`
  (`userId`, `email`, `emailVerified`, `profile`, `activeFamily`, `activeDevice`,
  `deviceIdentity`, setters, `clear()`, `isParent`, `isChild`),
  `LocalSettingsService` (cached role, active family id, last sync, toggles),
  `ConnectivityService` (`isOnline.obs`),
  `DeviceAdminService` (all native calls, typed).

### Concrete repositories (each domain agent implements its own)

All constructors must be:

```dart
ClassName({required SupabaseService supabase, required EdgeApi edgeApi})
```

- Agent B: `SupabaseAuthRepository`, `SupabaseFamilyRepository`,
  `SupabasePairingRepository`
  files: `lib/data/repositories/supabase_auth_repository.dart`,
  `supabase_family_repository.dart`, `supabase_pairing_repository.dart`.
- Agent C: `SupabaseDeviceRepository`, `SupabasePolicyRepository`,
  `SupabaseUsageRepository` in corresponding files.
- Agent D: `SupabaseLocationRepository`, `SupabaseAlertRepository`,
  `SupabaseRemoteSessionRepository`, `SupabaseAuditRepository`.
- Agent E: none; use the interfaces via `Get.find<...>()`.

Do not create alternate provider implementations. Tests use fake implementations of
the abstract interfaces with `mocktail`.

## 3. Edge Function envelope and authentication

- Every request body includes `action`. Success HTTP 2xx:
  `{"ok": true, "data": <object|array>}`. Error HTTP 4xx/5xx:
  `{"ok": false, "error": {"code": "<stable_code>", "message": "<safe text>"}}`.
- User-authenticated functions require `Authorization: Bearer <user JWT>` (the
  Supabase Flutter client adds it) and re-check the caller server-side.
- Device-authenticated calls additionally/alternatively send:
  - `x-device-id: <devices.id uuid>`
  - `x-device-secret: <raw secret, base64url>`
  Server computes SHA-256 hex and compares to `devices.secret_hash` in constant time,
  requires `devices.status = 'active'` and `credential_revoked_at is null`.
  A user JWT or device id alone is never accepted as device proof.
- Service-role key and TURN secret are **server-side only** (Supabase secrets).
- Rate limiting is server-side; never rely on client throttling.

## 4. Database schema (Supabase migrations)

All public tables: UUID PK, `created_at timestamptz default now()`, FKs, checks and
indexes as listed. RLS enabled on every exposed table. No DELETE policies; unlink and
purge use explicit functions. All Edge Functions use the service role, but every
operation validates caller, membership, relationship, action, schema and expiry.

### profiles
`id uuid pk -> auth.users`, `role text not null default 'unset' check in
('unset','parent','child')`, `display_name text not null check 1..60`,
`created_at`, `updated_at`. Trigger creates a profile on auth signup. Role may be set
once (unset -> parent/child) via Edge Function and is immutable afterwards (trigger
allows service_role only). RLS: select self, or profiles of users sharing an active
family.

All user-referencing columns (`family_members.user_id`, `devices.child_user_id`,
`device_pairing_tokens.child_user_id`, `pairing_requests.parent_user_id` /
`child_user_id`, `device_policies.created_by`, `device_commands.created_by`,
`remote_sessions.parent_user_id` / `child_user_id`, `webrtc_signals.from_user_id`,
`audit_logs.actor_user_id`, `safe_zones.created_by`) must reference
`public.profiles(id)` (which itself cascades from `auth.users`) so PostgREST can
embed `profiles` and expose display names. Deleting an auth user cascades through
profiles.

### families
`id`, `name text check 1..80`, `owner_id -> auth.users`, `settings jsonb not null
default {"location_retention_days":30,"usage_retention_days":90}`, `created_at`,
`updated_at`, `deleted_at`. Unique partial index: one active family per owner.
RLS: select active members; update owner only.

### family_members
`id`, `family_id -> families on delete cascade`, `user_id -> auth.users`,
`role check ('parent','child')`, `status check ('active','removed')`,
`created_at`, `removed_at`. Unique `(family_id,user_id)`. Unique partial index: a
child can be in only one active family. RLS: select members of own family.

### devices
`id`, `family_id`, `child_user_id -> auth.users`, `installation_id text`,
`display_name text`, `platform text default 'android'`, `android_version`,
`app_version`, `status check ('pending','active','revoked')`, `secret_hash text`
(null when revoked), `credential_issued_at`, `credential_revoked_at`,
`last_seen_at`, `battery_level int check 0..100`, `is_charging bool`,
`enforcement_mode check ('none','device_admin','device_owner')`,
`policy_version int default 0`, `usage_access_granted bool`,
`location_granted bool`, `background_location_granted bool`, `camera_granted bool`,
`microphone_granted bool`, `notifications_granted bool`, `created_at`, `updated_at`.
Unique `(family_id,installation_id)`. Unique partial index: one active device per
child account (`child_user_id where status='active'`). RLS: select family parent or
the child owner. No direct writes. Clients receive column-level SELECT only;
`secret_hash` and `installation_id` are service-only columns.

### device_pairing_tokens
`id`, `child_user_id`, `code_hash text unique`, `expires_at`, `redeemed_at`,
`redeemed_by`, `status check ('active','redeemed','revoked','expired')`,
`attempts int default 0`, `max_attempts int default 10`, `created_at`, `created_by`.
Expiry 10 minutes. No client access (service role only).

### pairing_requests
`id`, `token_id unique -> device_pairing_tokens`, `family_id`, `parent_user_id`,
`child_user_id`, `status check ('pending_child','approved','rejected','cancelled','expired')`,
`created_at`, `expires_at`, `responded_at`. RLS: select child owner, requesting
parent, or family parent. No direct writes.

### device_policies
`id`, `device_id`, `family_id`, `version int`, `policy jsonb`, `created_by`,
`created_at`, `acknowledged_at`, `enforcement_status check
('pending','enforced','failed','unsupported') default 'pending'`, `last_error`.
Unique `(device_id,version)`. RLS: select family parent or child owner. No direct
writes.

### device_commands
`id`, `device_id`, `family_id`, `type text`, `payload jsonb`, `status check
('pending','delivered','succeeded','failed','expired')`, `idempotency_key text`,
`created_by`, `created_at`, `expires_at`, `delivered_at`, `acked_at`, `result jsonb`,
`error_message text`, `attempts int default 0`. Unique
`(device_id,idempotency_key)`. RLS: select family parent or child owner.
Realtime enabled.

### usage_daily
`id`, `device_id`, `family_id`, `day date`, `package_name`, `app_label`,
`total_ms bigint check >=0`, `last_used_at`, `uploaded_at timestamptz`, `source`.
Unique `(device_id,day,package_name)`. RLS: select family parent or child owner.

### location_events
`id`, `device_id`, `family_id`, `lat double precision check -90..90`,
`lng double precision check -180..180`, `accuracy_m real check >=0`,
`recorded_at`, `received_at default now()`, `source`. Index
`(device_id, recorded_at desc)`. RLS: select family parent or child owner.

### safe_zones
`id`, `family_id`, `name text check 1..60`, `lat`, `lng`,
`radius_m check 50..5000`, `active bool default true`, `created_by`, `created_at`.
RLS: select family; insert/update/delete family parent.

### safe_zone_states
`zone_id`, `device_id`, `inside bool`, `updated_at`, primary key `(zone_id,device_id)`.
Service role only.

### safety_alerts
`id`, `family_id`, `device_id`, `type text`, `severity check
('info','warning','critical')`, `message text`, `payload jsonb default '{}'`,
`created_at`, `acknowledged_at`, `acknowledged_by`. RLS: select family parent or
child owner. No direct update. Realtime enabled.

### remote_sessions
`id`, `family_id`, `device_id`, `parent_user_id`, `child_user_id`,
`kind check ('audio','video')`, `status check
('requested','accepted','active','declined','ended','expired','failed')`,
`requested_at default now()`, `accepted_at`, `started_at`, `ended_at`, `expires_at`,
`ended_by`, `ended_reason text check <=200`, `consent_recorded bool default false`,
`session_nonce uuid`, `created_at`. RLS: select parent, child or family parents. No
direct writes. Realtime enabled.

### webrtc_signals
`id`, `session_id -> remote_sessions on delete cascade`, `from_user_id`,
`kind check ('offer','answer','ice')`, `payload jsonb check
octet_length(payload::text) <= 16384`, `created_at`, `sequence bigint generated
always as identity`. Index `(session_id, sequence)`. RLS: select/insert only for
session participants when session status in ('accepted','active') and
`expires_at > now()` and `from_user_id = auth.uid()`. No update/delete. Realtime
enabled.

### audit_logs
`id`, `family_id nullable`, `actor_user_id nullable`, `device_id nullable`,
`event_type text`, `target_type`, `target_id`, `metadata jsonb default '{}'`,
`created_at`. Append-only trigger blocks update/delete except service role. RLS:
select family parent. No direct writes.

### device_apps
`id`, `device_id`, `family_id`, `package_name`, `label`, `is_system bool`,
`is_suspended bool`, `version_name text`, `reported_at`, unique
`(device_id,package_name)`. RLS: select family parent or child owner. No direct
writes. Populated by `device-telemetry` action `apps_upload`.

### pairing_attempts
`id`, `parent_user_id`, `code_hash`, `attempted_at`, `success bool`. Index
`(parent_user_id, attempted_at)` and `(code_hash, attempted_at)`. Service role only.

### RPC helpers (security definer, execute only service_role or internal)
- `private.is_family_member(uuid)`, `private.is_family_parent(uuid)`,
  `private.shares_active_family(uuid)`, `private.realtime_topic_allowed(text)` —
  boolean policy helpers, stable, `search_path` fixed.
- `private.apply_policy_version(p_device_id uuid, p_policy jsonb, p_actor uuid,
  p_idempotency_key text)` — atomic: insert next version, insert `apply_policy`
  command whose payload includes `{policy_id, version, policy}`, return JSON rows.
- `private.expire_stale_sessions()` and `private.detect_offline_devices()` for cron.
- `private.record_audit(...)` internal helper.
All `SECURITY DEFINER` functions set `search_path = public, private, pg_temp`.
The four boolean helpers above are executable by `authenticated` because RLS and
Realtime evaluate policies as the caller; every state-changing function revokes
execute from `anon, authenticated`.

## 5. Edge Functions

Paths under `supabase/functions/<name>/index.ts`; shared code under
`supabase/functions/_shared/`. `supabase/config.toml` JWT settings:

- `verify_jwt = true`: `auth-bootstrap`, `pairing`, `device-register`,
  `device-policy`, `family-admin`, `remote-session` (user JWT only).
- `verify_jwt = false`: `device-command`, `device-telemetry` (mixed/device
  callers). A publishable key (`sb_publishable_...`) is **not a JWT** and cannot
  pass gateway JWT verification, so these functions authenticate themselves:
  `poll` / `ack` / telemetry require `x-device-id` + `x-device-secret` with a
  constant-time SHA-256 comparison against `devices.secret_hash`,
  `status='active'`, `credential_revoked_at is null`; `create` requires a real
  user JWT parsed with `supabase.auth.getUser(token)`. Never treat the
  publishable key, a device id, or a user JWT alone as device proof.
- User-auth functions must still call `getUser` and re-check role/membership even
  though the gateway verified the JWT.
- Native device calls send `apikey: <publishableKey>` and
  `Authorization: Bearer <publishableKey>` only to satisfy the gateway; identity
  comes exclusively from the device headers.

### auth-bootstrap
- `set_role` (user): `{role:"parent"|"child", display_name?}` → profile row.
  Requires verified email (`email_confirmed_at`), role must be `unset` or identical
  (idempotent); validates role; audit `role_set` (family_id null).
- `create_family` (user parent): `{name}` → family row. Requires verified email.
  409 if an active owned family exists. Creates family + parent membership + audit
  `family_created` atomically via RPC `private.create_family_with_owner`.

### pairing
- `create` (child): → `{code, qr_payload, expires_at}`. 8-char Crockford base32
  (`23456789ABCDEFGHJKMNPQRSTVWXYZ`), 10-minute expiry, revokes previous active
  tokens. `qr_payload = "parentcontrol://pair?code=<code>&v=1"`. Max 5 active code
  creations per 24h. Audit `pairing_code_created`.
- `redeem` (parent): `{code, family_id}` → pairing request object
  `{id, token_id, family_id, family_name, parent_user_id, parent_display_name,
  child_user_id, child_display_name, status:"pending_child", created_at, expires_at}`.
  Normalize code (uppercase, strip non-alphanumerics). Compare SHA-256. Rate limit:
  5 attempts per parent per 10 minutes and 10 per token; count failures. 400
  `invalid_code` (same response for unknown/expired to prevent enumeration), 410
  `code_expired`, 429 `rate_limited`, 409 `child_already_linked`. Parent must be
  active parent in family. Do not expose any directory search. Audit
  `pairing_redeemed` with family_id.
- `pending_child` (child): → list of request rows for the calling child, status
  pending_child, not expired, with parent_display_name, family_name.
- `respond` (child): `{request_id, approve:boolean}` → `{status, family_id?}`.
  Validates ownership, status, expiry. Approve creates active child membership
  (409 if another active family), marks request approved, token redeemed, audit
  `pairing_approved`; reject marks rejected + token revoked, audit
  `pairing_rejected`.
- `cancel` (parent): `{request_id}` → idempotent cancelled; token revoked; audit.
- `list_family` (parent): `{family_id}` → list of requests with profiles/family.
- `unlink` (parent or child): `{family_id, child_user_id}` → marks membership
  removed, revokes all child devices (secret_hash null), ends open sessions, audit
  `member_removed`. Child may only unlink self; parent must be family parent.

### device-register
`register` (child): `{family_id, installation_id, secret_hash, display_name,
platform, android_version, app_version}` → device row. Validate 64-hex hash,
installation id 8..128, active child membership, one active device per child. A
revoked device for that child in the family blocks registration of any new
installation (403 `device_revoked`, audit `device_registration_blocked`) until the
parent removes the child and a later pairing request is approved; a child cannot
clear a revocation itself. `revoke_device` also cancels pending pairing requests
in that family, so a request redeemed before revocation cannot be approved
afterwards. Idempotent re-register rotates the hash and updates metadata. The
response omits `installation_id` and `secret_hash`. Audit `device_registered` /
`device_recredentialed`.

### device-command
- `create` (parent): `{device_id, type, payload, idempotency_key, ttl_seconds?}` →
  `{command}`. Valid types and payload schemas. ttl clamp 60..900. Idempotent on
  `(device_id,idempotency_key)`. `apply_policy` is routed through
  `apply_policy_version`, so the created command always carries
  `{policy_id, version, policy}` and the ack can update `device_policies`
  (policy commands use the RPC's 900-second expiry). Audit `command_created`
  (plus `policy_updated` for a new policy).
- `poll` (device auth): → `{commands:[...], server_time}`. Marks pending as
  delivered; marks expired commands expired; limit 20; never returns another
  device's commands.
- `ack` (device auth): `{command_id, status:"succeeded"|"failed"|"expired", result}`
  → `{command}`. Idempotent; 410 if ack after expiry (mark expired). On
  `apply_policy` success/failure update the matching `device_policies` row
  (`acknowledged_at`, `enforcement_status`, `last_error`); only a successful ack
  updates `devices.policy_version`, from the server-side policy row. Audit
  `command_acked`/`command_failed`.

### device-policy
`update` (parent): `{device_id, policy, idempotency_key}` → `{policy, command}`.
Validate policy schema strictly. Calls atomic RPC `apply_policy_version`; command
payload contains full policy for offline execution. Audit `policy_updated`.

### device-telemetry (device auth on every action)
- `heartbeat`: `{battery_level, is_charging, online,
  capabilities:{enforcement_mode, usage_access_granted, location_granted,
  background_location_granted, camera_granted, microphone_granted,
  notifications_granted}}` → `{server_time, pending_policy_version}`. Updates
  device presence. `policy_version` is ignored if sent: it is advanced only by a
  successful `apply_policy` ack, so a heartbeat cannot claim enforcement. Creates
  `low_battery` alert at ≤20% (not charging) at most once per 6 hours. Never
  claims freshness when data absent.
- `usage_upload`: `{entries:[{day:"YYYY-MM-DD", package_name, app_label, total_ms,
  last_used_at?}]}` (1..500) → `{accepted, uploaded_at}`. Upserts; family_id derived
  from device; validates package name/size.
- `location_upload`: `{lat, lng, accuracy_m, recorded_at, source}` →
  `{accepted, zone_events:[{zone_id, name, event:"enter"|"exit"}]}`. Inserts event;
  updates `safe_zone_states`; creates geofence alerts on transitions. Rejects
  timestamps >5 minutes in the future or >7 days old.
- `apps_upload`: `{apps:[{package_name,label,is_system,is_suspended,version_name}]}`
  (1..500) → `{accepted, reported_at}`. Upserts `device_apps` (replace snapshot for
  that device). Parent restriction UI reads this snapshot; absence means the device
  has not reported and must be shown as unknown, never as "no apps".

### family-admin (user-auth)
- `revoke_device` (parent): `{device_id}` → revoked + credentials nulled + sessions
  ended; audit.
- `ack_alert` (parent): `{alert_id}` → acknowledged; audit.
- `purge_data` (parent): `{family_id, older_than_days}` → counts; audit.
- `update_retention` (parent owner): `{family_id, location_days 1..365,
  usage_days 1..730}` → family settings; audit.

### remote-session (user-auth)
- `request` (parent): `{device_id, kind}` → session. Device must be active and in
  family. Expires in 10 minutes. Audit `session_requested`.
- `pending_child` (child): → list of requested, non-expired sessions.
- `respond` (child): `{session_id, accept}` → session. Accept sets status accepted,
  `consent_recorded=true`, `expires_at=now+30min`, `session_nonce`.
- `start` (child): `{session_id}` → active; requires accepted, not expired.
- `end` (participant): `{session_id, reason?}` → ended; idempotent.
- `ice` (participant): → `{ice_servers:[{urls:[...],username?,credential?}],
  turn_configured, warning?, expires_at}`. STUN from `STUN_URL`; TURN ephemeral
  credentials from `TURN_URL`/`TURN_SECRET`/`TURN_TTL_SECONDS` (HMAC, coturn REST).
  No TURN secrets in the app. Only when accepted/active and not expired.
- Signaling: clients insert/select `webrtc_signals` directly (RLS-protected) and use
  private Supabase Realtime `postgres_changes` channels with topics
  `remote-session:<sessionId>`, `remote-session-family:<familyId>`,
  `webrtc-signals:<sessionId>` and `safety-alerts:<familyId>`. Record delivery is
  filtered by the source-table RLS policies; the guarded `realtime.messages`
  policy additionally calls `private.realtime_topic_allowed(topic)` for the
  topic shapes above (defense-in-depth; Supabase documents `realtime.messages`
  authorization as applying to broadcast/presence). No public broadcast
  channels are used. Hosted Realtime behavior is **NOT TESTED**.
- Session must stop on end, decline, expiry, device revoke, unlink; no media before
  consent.

### Cron (documented, not required for local run)
`expire_stale_sessions()` and `detect_offline_devices()` via `pg_cron` or scheduled
Edge invocation. If `pg_cron` is unavailable, provide a documented manual command.

## 6. Flutter pages, routes and ownership

Page classes must be `const`-constructible and read args from `Get.arguments`
(Map<String,String>) or `Get.parameters`.

| Route | Page class / file | Owner |
|---|---|---|
| `/` | `SplashPage` | B |
| `/configuration` | `ConfigurationPage` | lead |
| `/role-selection` | `RoleSelectionPage` | B |
| `/auth/login` | `LoginPage` | B |
| `/auth/register` | `RegisterPage` | B |
| `/auth/verify-email` | `VerifyEmailPage` | B |
| `/parent` | `ParentShellPage` | C |
| `/parent/family-setup` | `FamilySetupPage` | B |
| `/parent/family` | `FamilyPage` (args familyId) | B |
| `/parent/pairing/redeem` | `PairingRedeemPage` (args familyId) | B |
| `/parent/pairing/requests` | `PairingRequestsPage` (args familyId) | B |
| `/parent/devices/detail` | `DeviceDetailPage` (args deviceId) | C |
| `/parent/app-restrictions` | `AppRestrictionsPage` (args deviceId) | C |
| `/parent/screen-time` | `ScreenTimePage` (args deviceId) | C |
| `/parent/location` | `LocationPage` (args deviceId, familyId) | D |
| `/parent/safe-zones` | `SafeZonesPage` (args familyId, optional deviceId) | D |
| `/parent/alerts` | `SafetyAlertsPage` (args familyId) | D |
| `/parent/assistance` | `RemoteAssistancePage` (args deviceId) | D |
| `/parent/assistance/session` | `RemoteSessionPage` (args sessionId, role) | D |
| `/parent/audit` | `AuditLogsPage` (args familyId) | D |
| `/parent/settings` | `ParentSettingsPage` | D |
| `/child` | `ChildShellPage` | E |
| `/child/enrollment` | `ChildEnrollmentPage` | E |
| `/child/restrictions` | `ChildRestrictionsPage` | E |
| `/child/session` | `ChildSessionPage` (args sessionId?) | E |
| `/child/requests` | `ChildRequestsPage` | E |

Tabs composed by ParentShellPage (C) and owned as follows:

- `ParentDashboardTab` — C, `lib/features/dashboard/parent_dashboard_tab.dart`
- `ParentDevicesTab` — C, `lib/features/devices/parent_devices_tab.dart`
- `ParentAlertsTab` — D, `lib/features/safety_alerts/parent_alerts_tab.dart`
- `ParentSettingsTab` — D, `lib/features/settings/parent_settings_tab.dart`

All are `StatelessWidget` with `const X({super.key})`. ParentShellPage has four tabs
and must not duplicate their business logic. Child shell tabs live under
`lib/features/child/`.

No route is added to `AppPages` by agents; the lead writes it at integration. Use
`AppRoutes` constants only. Required class names and paths must match exactly.

Each routed page has a `Bindings` subclass that the lead wires into `AppPages`.
Put it beside the page as `lib/features/<feature>/<page>_binding.dart` and name it
`<PageName>Binding` (e.g. `LoginPage` → `lib/features/auth/login_binding.dart` class
`LoginBinding`). Bindings register controllers with
`Get.lazyPut(() => XController(repo: Get.find<XRepository>()), fenix: true)` and
never construct repositories. Tabs inside a shell may instead initialise their own
controller with `GetX<XController>(init: XController(repo: Get.find<...>()), ...)`.
Every binding class name must be listed in the agent report. Pages must be
`const`-constructible and must not reach into another feature's controller.

### Auth/onboarding flow (Agent B)
- Splash: if backend missing → `AppRoutes.configuration`; else listen to auth.
  Signed out → role selection. Signed in → load profile; if role unset → role
  selection in `lock` mode (choosing calls `set_role` once); if parent → family
  setup if no family, else parent shell; if child → child shell.
- RoleSelection: before login placeholders Parent Mode/Child Mode; store intended
  role in `LocalSettingsService`; navigate to login/register. After auth with no
  server role, the same screen locks the initial server role (does not grant data).
- Email verification: if `emailVerified == false`, show VerifyEmailPage with resend
  and refresh; parent/child features that call Edge Functions must show this gate.
- Sign out: clear `SessionService`, `LocalSettingsService.clearOnSignOut()`, stop
  native guardian service for child, navigate to role selection.

## 7. Native Android platform channel (Agent E)

Channel: `com.parentcontrol/native` (MethodChannel), `com.parentcontrol/native_events`
(EventChannel). All payloads are JSON maps. The Dart wrapper
`DeviceAdminService` already defines these method names/fields:

| Method | Arguments | Result |
|---|---|---|
| `getCapabilities` | — | `{available:true,isDeviceOwner,isAdminActive,canSuspendPackages,sdkInt,manufacturer,model,androidVersion,appVersion,usageAccessGranted,fineLocationGranted,backgroundLocationGranted,cameraGranted,microphoneGranted,notificationsGranted,guardianServiceRunning}` |
| `getDeviceIdentity` | — | `{installationId,secret,secretHash}` (secret 32 random bytes base64url; hash = SHA-256 hex; stored in EncryptedSharedPreferences) |
| `getBatteryStatus` | — | `{level,isCharging}` |
| `getInstalledApps` | — | `[{packageName,label,isSystem,isSuspended,versionName}]` |
| `isPackageSuspended` | `{packageName}` | bool |
| `applyPolicy` | `{policy:{...}}` | `{success,applied_at,suspended_packages,unsupported_packages,errors,service_running}` |
| `getGuardianServiceStatus` | — | `{running,lastPollAtMillis,lastError,queuedCommands}` |
| `startGuardianService` / `stopGuardianService` | — | bool |
| `configureBackgroundSync` | `{supabaseUrl,publishableKey,deviceId,deviceSecret,familyId}` | bool (store encrypted; never log) |
| `clearBackgroundSync` | — | bool |
| `requestDeviceAdmin` | — | bool |
| `openUsageAccessSettings` / `openBackgroundLocationSettings` | — | bool |
| `requestPermissions` | `{camera,microphone,location,backgroundLocation,notifications}` | `{camera,microphone,location,backgroundLocation,notifications}` |
| `getLastKnownLocation` | — | `{available,lat,lng,accuracyM,timestampMillis,isMock,source}` or `{available:false}` |
| `startLocationTracking` / `stopLocationTracking` | `{intervalSeconds}` / — | bool |
| `getDailyUsage` | `{startMillis,endMillis}` | `[{day:"YYYY-MM-DD",packageName,label,totalMs,lastUsedAtMillis}]`; throw `PlatformException(code:"usage_access_denied")` when access is missing |

Events: `{type:"location_update",fix:{...}}`, `{type:"command",commandId,type,status}`,
`{type:"service_status",running,lastError}`.

Native requirements:
- `DeviceAdminReceiver` + `res/xml/device_admin.xml` and `dpm set-device-owner`
  instructions. Do not assume Play Store install grants Device Owner. On
  non-fully-managed devices report `canSuspendPackages=false` and never claim
  Instagram is blocked.
- `PolicyApplier`: validate packages exist; refuse own package, system-critical
  packages (launcher, phone, settings, systemui, permission controller, Play Store
  where risky); use `setPackagesSuspended` only when Device Owner; persist policy;
  evaluate schedules on service ticks; restore packages when rules expire/removed;
  merge duplicate commands; report per-package results. Never silently ignore.
- Background command poller in a visible foreground service (notification). Uses
  stored config, TLS, headers `apikey` + `Authorization: Bearer <publishableKey>` +
  `x-device-id` + `x-device-secret`; POST body `{"action":"poll"}`; executes
  `apply_policy` from payload; acks; backoff on failure; respects expiry; no secret
  logging. Start at configure/ boot where allowed; Android background limits are
  documented honestly.
- Usage via `UsageStatsManager`; no fabricated data; permission required.
- Location via `LocationManager` + foreground service, permission-gated; last fix
  timestamp/accuracy; no background tracking without authorization; mock location
  flagged.
- Request/accept assistance permissions (camera/mic) only when needed; service for
  a live WebRTC session must be visible.
- Manifest: internet/network, fine/coarse/background location, foreground services
  (location + dataSync), notifications, camera, record audio, boot completed,
  package usage stats, query all packages (document Play policy implication), device
  admin receiver, services/receivers. `allowBackup=false`.
- No accessibility abuse, no root, no hidden capture, no permission bypass, no
  keylogging, no screenshots, no reading private messages/OTP, no recording.

## 8. Agent output requirements

Return a concise report (≤350 words) with:
1. FILES — created/modified paths.
2. WHAT WORKS — implemented features with honest state.
3. CONTRACT DEVIATIONS / NEEDS OWNER — any additions or missing APIs, file:line.
4. SCOPED ANALYZE — exact command and result (errors/warnings in your files only;
   do not fix files outside your domain).
5. NOT VERIFIED — everything you could not run.
6. OPEN QUESTIONS.

Do not run tests/builds. Do not edit outside your ownership. Do not invent backend
success. Use `PASS — LOCAL VERIFIED` only for a scoped analyzer run you actually
performed; everything else stays UNVERIFIED until the lead runs it.
