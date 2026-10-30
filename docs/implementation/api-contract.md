# API contract

As-built contract of the Flutter client, the 9 Edge Functions and the 19 tables. Derived from
source, not from the audit prose. Phase 1 additions are marked **NEW** and are **not deployed**.

Two states are distinguished throughout:

- **HEAD** — committed at `2a0209f`, and deployed (except `remote-session`, see `baseline.md` §4).
- **NEW** — frozen in `docs/implementation/_work/coordinator-contract.md`, implemented in the
  working tree by the owning workstream, **not applied and not deployed**.

## 1. Routes (26)

`lib/app/routes/app_routes.dart:4-31` declares 26 paths; `lib/app/routes/app_pages.dart:56-186`
registers 26 `GetPage`s. There are **no route guards**: authorization is per-call server-side
(`lib/app/routes/app_pages.dart:56-186`; audit `03_EXISTING_PROJECT_ARCHITECTURE.md:56`).

| # | Route | Page | Controller (binding) | Repositories |
|---|---|---|---|---|
| 1 | `/` | `SplashPage` | `SplashController` | Auth, Family |
| 2 | `/configuration` | `ConfigurationPage` | — (no binding) | — (`core/config/env.dart`) |
| 3 | `/role-selection` | `RoleSelectionPage` | `RoleSelectionController` | Auth, Family |
| 4 | `/auth/login` | `LoginPage` | `LoginController` | Auth, Family |
| 5 | `/auth/register` | `RegisterPage` | `RegisterController` | Auth, Family |
| 6 | `/auth/verify-email` | `VerifyEmailPage` | `VerifyEmailController` | Auth, Family |
| 7 | `/parent` | `ParentShellPage` | `ParentShellController` (tabs only) + `DashboardController` | Device, Family, Policy |
| 8 | `/parent/family-setup` | `FamilySetupPage` | `FamilySetupController` | Family |
| 9 | `/parent/family` | `FamilyPage` | `FamilyController` | Family, Pairing |
| 10 | `/parent/pairing/redeem` | `PairingRedeemPage` | `PairingRedeemController` | Pairing |
| 11 | `/parent/pairing/requests` | `PairingRequestsPage` | `PairingRequestsController` | Pairing |
| 12 | `/parent/devices/detail` | `DeviceDetailPage` | `DeviceDetailController` | Device, Policy |
| 13 | `/parent/app-restrictions` | `AppRestrictionsPage` | `AppRestrictionsController` | Device, Policy |
| 14 | `/parent/screen-time` | `ScreenTimePage` | `ScreenTimeController` | Device, Policy, Usage |
| 15 | `/parent/location` | `LocationPage` | `LocationController` | Location |
| 16 | `/parent/safe-zones` | `SafeZonesPage` | `SafeZonesController` | Family, Location |
| 17 | `/parent/alerts` | `SafetyAlertsPage` | `SafetyAlertsController` | Alert |
| 18 | `/parent/assistance` | `RemoteAssistancePage` | `RemoteAssistanceController` | RemoteSession |
| 19 | `/parent/assistance/session` | `RemoteSessionPage` | `RemoteSessionController` (role `parent`) | RemoteSession |
| 20 | `/parent/audit` | `AuditLogsPage` | `AuditLogsController` | Audit |
| 21 | `/parent/settings` | `ParentSettingsPage` | `ParentSettingsController` | Auth (+ local prefs) |
| 22 | `/child` | `ChildShellPage` | `ChildShellController` | Auth, Device, Family, Pairing, Policy, RemoteSession |
| 23 | `/child/enrollment` | `ChildEnrollmentPage` | `ChildEnrollmentController` | Device, Family, Pairing |
| 24 | `/child/restrictions` | `ChildRestrictionsPage` | `ChildShellController` (reuses `ChildShellBinding`, `app_pages.dart:171-175`) | Policy, Device |
| 25 | `/child/session` | `ChildSessionPage` | `RemoteSessionController` (role `child`, bound through `RemoteSessionRegistry`, `child_session_binding.dart:29-40`) | RemoteSession |
| 26 | `/child/requests` | `ChildRequestsPage` | `ChildRequestsController` | Pairing, RemoteSession |

`/parent/devices` (list) and `/parent/alerts` are tabs inside `ParentShellPage`; the Devices tab is
`lib/features/devices/parent_devices_tab.dart` under `DevicesController`. There is **no**
`/parent/devices` route — device selection navigates to `/parent/devices/detail` with arguments.

Call layer: every Edge Function call goes through one client,
`lib/data/services/edge_api.dart:19-40`, which posts `{'action': action, ...body}` and unwraps the
envelope `{ok, data}` (`supabase/functions/_shared/envelope.ts:36-38`). Errors are
`{ok:false, error:{code,message[,details]}}` with HTTP status.

## 2. Edge Function action contract (9 functions, 34 actions at HEAD)

Common: `POST` only; `OPTIONS` preflight; body must contain `action`. User-JWT functions call
`requireUser` (verified email) and `requireRole`; device functions authenticate with
`x-device-id`/`x-device-secret`; `cron` authenticates with `x-cron-secret`. Request shapes list
required fields only unless marked optional.

### 2.1 `auth-bootstrap` (2 actions) — `supabase/functions/auth-bootstrap/index.ts:33-130`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `set_role` | user JWT, any role | `{role: 'parent'\|'child'\|'unset', display_name?}` | profile row; role is write-once (409 on re-set) |
| `create_family` | user JWT, parent | `{name}` | family row from `create_family_with_owner` RPC |

### 2.2 `pairing` (9 actions) — `supabase/functions/pairing/index.ts:442-970`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `get_contact_id` | child JWT | `{}` | contact-id payload (`contactPayload`), assigns `PC-XXXXXXXX` on first call |
| `create` | child JWT | `{family_id, ...}` | `{code, qr_payload: 'parentcontrol://pair?code=…&v=1', expires_at}` |
| `redeem` | parent JWT | `{code, family_id}` | request payload: `{id, token_id, family_id, family_name, parent_user_id, parent_display_name, child_user_id, child_display_name, status, created_at, expires_at, responded_at}` (`:148-175`); pending child name is masked |
| `invite` | parent JWT | `{family_id, child_id}` | same request payload |
| `pending_child` | child JWT | `{}` | array of decorated pending requests (≤50) |
| `respond` | child JWT | `{request_id, approve: bool}` | RPC result (request + membership + device state) |
| `cancel` | parent JWT | `{request_id}` | `{status:'cancelled', request_id}` |
| `list_family` | parent JWT | `{family_id}` | array of decorated family requests (≤100, pending child name masked) |
| `unlink` | parent JWT | `{family_id, child_user_id}` | RPC result (`unlink_child`) |

### 2.3 `device-register` (1 action) — `supabase/functions/device-register/index.ts:109-245`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `register` | child JWT | `{family_id, installation_id, secret_hash (64 hex), display_name, platform?, android_version?, app_version?}` | public device row (no `secret_hash`); `409 device_already_registered` |

### 2.4 `device-telemetry` (4 actions) — `supabase/functions/device-telemetry/index.ts:64-430`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `heartbeat` | device headers | `{battery_level?, is_charging?, online?, capabilities?{enforcement_mode?, permissions…}}` | `{server_time, pending_policy_version}`; writes `devices.last_seen_at`, `battery_level`, `capabilities`→`enforcement_mode`/permission flags; may insert `low_battery` alert |
| `usage_upload` | device headers | `{entries: [{day, package_name, app_label?, total_ms, last_used_at?, source?}]}` (≤500) | `{accepted, uploaded_at}`; upserts `usage_daily` |
| `location_upload` | device headers | `{lat, lng, accuracy_m, recorded_at, source?}` | `{accepted: true, zone_events}`; inserts `location_events` and evaluates safe zones (`:274-352`) |
| `apps_upload` | device headers | `{apps: [{package_name, label?, is_system?, is_suspended?, version_name?}]}` (≤500) | `{accepted, reported_at}`; upserts `device_apps` |

### 2.5 `device-policy` (1 action) — `supabase/functions/device-policy/index.ts:44-98`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `update` | parent JWT | `{device_id, idempotency_key, policy}` | `{policy, command}` from `apply_policy_version`; `idempotent:true` reuses the row |

### 2.6 `device-command` (3 actions) — `supabase/functions/device-command/index.ts:106-363`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `create` | parent JWT | `{device_id, type, payload, idempotency_key, ttl_seconds?}` | `{command}`; unique `(device_id, idempotency_key)` |
| `poll` | device headers | `{}` | `{commands, server_time}`; marks delivered |
| `ack` | device headers | `{command_id, status: 'succeeded'\|'failed', result? (≤32 KiB), error_message?}` | `{command}`; on `apply_policy` also sets `device_policies.enforcement_status` (`:318-351`) and advances `devices.policy_version` |

`type` ∈ `apply_policy | sync_policy | request_usage | request_location | end_session | custom`
(`supabase/migrations/20260101000000_core.sql:201`).

### 2.7 `family-admin` (5 actions at HEAD + 1 NEW) — `supabase/functions/family-admin/index.ts:54-290`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `revoke_device` | parent JWT | `{device_id}` | RPC `revoke_device` result |
| `recover_device` | parent JWT | `{device_id}` | RPC `request_device_recovery` result |
| `ack_alert` | parent JWT | `{alert_id}` | updated alert |
| **`delete_zone`** (NEW) | parent JWT | `{zone_id}` | `{deleted: true}`; audits `zone_deleted`; 404 `zone_not_found` |
| `purge_data` | parent JWT (owner only — NEW) | `{family_id, older_than_days}` | `{deleted: true}`; deletes `location_events`/`usage_daily` beyond max(purge, retention) |
| `update_retention` | parent JWT | `{family_id, location_days (1–365), usage_days (1–730)}` | family `settings` object |

### 2.8 `remote-session` (7 actions) — `supabase/functions/remote-session/index.ts:107-380`

| Action | Caller | Request | Response `data` |
|---|---|---|---|
| `request` | parent JWT | `{device_id, kind: 'audio'\|'video'}` | session row with participants; `409 session_in_progress` |
| `session_state` | device headers | `{session_id}` | `{id, status, expires_at, …}` (`sessionStatePayload`) |
| `pending_child` | child JWT | `{}` | array of pending sessions; also expires stale `requested` rows |
| `respond` | child JWT | `{session_id, accept: bool}` | session row. Accept sets `consent_recorded`, `status='accepted'`, **`expires_at = null`**; decline sets `declined` |
| `start` | participant JWT | `{session_id}` | session row, `status='active'` (idempotent) |
| `end` | **parent only** | `{session_id}` | session row; child calls get `403`. Client-`reason` ignored; server derives `ended_reason` |
| `ice` | participant JWT | `{session_id}` | ICE server config from `_shared/turn.ts`; requires `accepted|active` **and** `consent_recorded` (`409`/`403`) |

### 2.9 `cron` (2 actions at HEAD, 4 NEW) — `supabase/functions/cron/index.ts:36-70`

Header `x-cron-secret` compared constant-time; no user JWT.

| Action | Request | Response `data` | RPC |
|---|---|---|---|
| `expire_sessions` | `{}` | `{expired_sessions: int}` | `expire_stale_sessions` (requested rows only) |
| `detect_offline` | `{}` | `{alerts_created: int}` | `detect_offline_devices` |
| **`sweep_sessions`** (NEW) | `{}` (bound fixed at 24 h) | `{closed_sessions: int}` or `{skipped: true, reason}` | **`expire_abandoned_sessions('24 hours')`** |
| **`retention_sweep`** (NEW) | `{}` | `{swept_at, webrtc_signals, audit_logs, location_events, usage_daily, families_examined, per_family}` or `{skipped: true, reason}` | **`run_retention_sweep()`** |

## 3. Table contract (19 tables)

All tables have RLS enabled; `anon` has zero grants. "RLS audience" is the `to authenticated`
predicate. "Writer" is the Edge Function performing the write with the service key.

| Table | Purpose | Ownership column | RLS audience | Writer |
|---|---|---|---|---|
| `profiles` | one row per auth user; `role` is the role lock | `id` (= `auth.uid()`) | self OR any co-member of an active family (`rls.sql:27-31`) | auth trigger `on_auth_user_created`; `auth-bootstrap` `set_role` |
| `families` | family root, retention in `settings`, soft delete | `owner_id` | members SELECT (`:43`), owner UPDATE (`:49`) | `auth-bootstrap` `create_family` |
| `family_members` | parent/child membership rows | `family_id`, `user_id` | members of the family (`:59`) | `pairing` `respond`/`unlink` |
| `devices` | child device + credential + presence + `policy_version` | `family_id`, `child_user_id` | family parent OR the child itself (`:68`) | `device-register`; `device-telemetry` heartbeat; `family-admin` revoke/recover; `device-command` `policy_version` |
| `child_contact_ids` | permanent Child ID (`PC…`) | `child_user_id` | **none** — service-role only (`child_contact_ids.sql:34-37`) | `pairing` `get_contact_id` |
| `device_pairing_tokens` | one-time pairing codes (hashed) | `child_user_id` | **none** — service-role only | `pairing` `create`/`invite` |
| `pairing_requests` | pending/approved link requests | `family_id`, `parent_user_id`, `child_user_id` | participants only (`:79`) | `pairing` `redeem`/`respond`/`cancel` |
| `pairing_attempts` | hashed rate-limit ledger | `parent_user_id` | **none** — service-role only | `pairing` `redeem` |
| `device_policies` | versioned policy JSON + ack state | `device_id`, `family_id` | parent of family OR child (`:92`) | `device-policy` via `apply_policy_version`; `device-command` ack sets `enforcement_status` |
| `device_commands` | durable command queue + ack | `device_id`, `family_id` | parent of family OR child (`:101`) | `device-policy`; `device-command` create/poll/ack |
| `device_apps` | installed-package inventory | `device_id`, `family_id` | parent of family OR child (`:131`) | `device-telemetry` `apps_upload` |
| `usage_daily` | per-package daily usage | `device_id`, `family_id` | parent of family OR child (`:113`) | `device-telemetry` `usage_upload` |
| `location_events` | location fixes | `device_id`, `family_id` | parent of family OR child (`:122`) | `device-telemetry` `location_upload` |
| `safe_zones` | geofences | `family_id` | family SELECT (`:143`); parent INSERT/UPDATE (`:149,:155`); **client DELETE dropped in Phase 1** | client insert/update; **`family-admin` `delete_zone`** (NEW) |
| `safe_zone_states` | inside/outside latch per zone+device | `zone_id`, `device_id` | **none** — service-role only | `device-telemetry` `location_upload` |
| `safety_alerts` | parent-facing alerts | `family_id`, `device_id` | parent of family OR child (`:173`) | `device-telemetry` (low battery, geofence); `family-admin` `ack_alert` |
| `remote_sessions` | consent + lifetime state machine | `family_id`, `device_id`, `parent_user_id`, `child_user_id` | participants (`:185`) | `remote-session` (all actions); `cron` sweeps |
| `webrtc_signals` | offer/answer/ICE rows | `session_id` | participants of an `accepted|active` session (`20261028000300:25,41`) | **client INSERT** (parent and child), not Edge Functions |
| `audit_logs` | append-only event ledger (`event_type` text) | `family_id`, `actor_user_id`, `device_id` | family **parent** only (`:236`) | every Edge Function via `_shared/audit.ts`; SQL sweeps |

No new table and no new column is permitted in Phase 1 (contract rule 8).

## 4. Realtime

Publication members: `device_commands`, `remote_sessions`, `safety_alerts`, `webrtc_signals`
(audit `06_BACKEND_DATABASE_RLS_AUDIT.md:15`). Channel-level authorization is topic-based
(`private.realtime_topic_allowed`, `supabase/migrations/20260101000200_rls.sql:295-332`); row
visibility is additionally governed by each table's own RLS.

| Channel topic | Client subscription | Topic predicate | Row predicate |
|---|---|---|---|
| `safety-alerts:<family_id>` | `supabase_alert_repository.dart:70-100` (private) INSERT + UPDATE on `safety_alerts` filtered by `family_id` | `private.is_family_member(family_id)` (`rls.sql:317-319`) | `safety_alerts_select_parent_or_child` |
| `remote-session-family:<family_id>` | `supabase_remote_session_repository.dart:211,230-245` (private) INSERT + UPDATE on `remote_sessions` filtered by `family_id` | `private.is_family_member(family_id)` | `remote_sessions_select_participants` |
| `webrtc-signals:<session_id>` | `supabase_remote_session_repository.dart:230-245,334-360` (private) INSERT on `webrtc_signals` filtered by `session_id` | participant of the session: `child_user_id = auth.uid() OR private.is_family_parent(family_id)` (`rls.sql:321-330`) | `webrtc_signals_select_participant` |
| `remote-session:<session_id>` | same repository (parent-side state) | same participant predicate | `remote_sessions_select_participants` |

`device_commands` is in the publication but **no Dart code subscribes to it**; delivery is the
child's 20 s poll (`device-command` action `poll`). `realtime.messages` carries one policy,
`parentcontrol_private_topics` (`rls.sql:349`). Replica identity is default on all four tables, so
UPDATE payloads carry the primary key plus changed columns only — clients must refresh rather than
patch. **No push transport exists** (no FCM); Subscriptions die with the process.

## 5. Status and enum vocabulary

Values are the database `check` constraints; clients must not invent new strings.

| Domain | Values | Source |
|---|---|---|
| Profile role | `unset`, `parent`, `child` | `core.sql:20` |
| Family member role / status | `parent`/`child`; `active`/`removed` | `core.sql:59-60` |
| Device status | `pending`, `active`, `revoked` | `core.sql:92` |
| Device enforcement mode | `none`, `device_admin`, `device_owner` | `core.sql:101` |
| Policy enforcement status | `pending`, `enforced`, `failed`, `unsupported` | `core.sql:186` |
| Command type | `apply_policy`, `sync_policy`, `request_usage`, `request_location`, `end_session`, `custom` | `core.sql:201` |
| Command status | `pending`, `delivered`, `succeeded`, `failed`, `expired` | `core.sql:206` |
| Session kind | `audio`, `video` | `core.sql:331` |
| Session status | `requested`, `accepted`, `active`, `declined`, `ended`, `expired`, `failed` | `core.sql:333-334`; Dart mirror `lib/data/models/remote_session.dart:14-45` |
| Session terminal set | `declined`, `ended`, `expired`, `failed` | `lib/data/models/remote_session.dart:48` |
| Signal kind | `offer`, `answer`, `ice` | `core.sql:363` |
| Pairing token status | `active`, `redeemed`, `revoked`, `expired` | `core.sql:137` |
| Pairing request status | `pending_child`, `approved`, `rejected`, `cancelled`, `expired` | `core.sql:160` |
| Alert type | `low_battery`, `offline`, `geofence_enter`, `geofence_exit`, `app_blocked`, `permission_missing`, `other` | `core.sql:302-303`; Dart `SafetyAlertType` `telemetry.dart:203-249` (`device_offline`, `permissionMissing`, …) |
| Alert severity | `info`, `warning`, `critical` | `core.sql:304` |
| `audit_logs.event_type` | free text 1–80 chars (`core.sql:380`); used values include `session_requested/accepted/started/ended`, `device_registered`, `policy_updated`, `alert_acknowledged`, `zone_deleted` | producers in `supabase/functions/**` |

`remote_sessions.session_nonce` is **written but never validated** — it is a reserved field, not a
replay control. Signal replay protection is the unique `(session_id, sequence)` index added in
`20261030000200_phase1_authorization.sql`. Do not depend on the nonce until a validation path exists.

**NEW vocabulary (Phase 1, not deployed):**

| Addition | Values / shape |
|---|---|
| `audit_logs.event_type` | `session_expired` with `metadata = {"reason":"abandoned","age_seconds":N}` |
| `remote_sessions` system closure | **resolved deviation:** `ended_by = null` + `ended_reason = 'abandoned'` (the pair is the system marker). The coordinator text says `ended_by='system'`, but the column is `uuid references profiles` (`core.sql:340`), so the literal value is unrepresentable. Recorded in `phase-0-report.md` §4 as D1. |
| `policy_ack.result` | adds `desired_count:int`, `applied_count:int`, `failed_count:int`, `enforcement_supported:bool`, `enforcement_mode:string` |
| `Device.syncHealth` | `healthy` < 12 min, `stalled` < 30 min, `offline` otherwise (derived, not stored) |

## 6. Phase 1 additions (NEW — written locally, not applied, not deployed)

| Addition | Signature / shape | Owner |
|---|---|---|
| `public.expire_abandoned_sessions` | `(p_max_age interval default '24 hours') returns integer`; SECURITY DEFINER, `search_path = public, private, pg_temp`; closes `accepted|active` older than the window, sets `status='expired'`, `ended_at=now()`, `ended_by=null`, `ended_reason='abandoned'`, one `session_expired` audit row per session; grant `service_role` only, revoke `public, anon, authenticated` (`supabase/migrations/20261030000100_abandoned_session_sweep.sql:47-121`) | session |
| `cron` action `sweep_sessions` | `{}` → `{closed_sessions:int}`; calls `public.expire_abandoned_sessions('24 hours')` (window fixed in the handler) | lifecycle |
| `cron` action `retention_sweep` | `{}` → deletion counts; calls `public.run_retention_sweep() returns jsonb` (service-role only); deletes `webrtc_signals` > 7 d, `audit_logs` > 365 d, per-family `location_events`/`usage_daily` outside `location_retention_days`/`usage_retention_days` | lifecycle |
| `family-admin` action `delete_zone` | `{zone_id}` → `{deleted:true}`; replaces the client `safe_zones` DELETE | security |
| `family-admin` `purge_data` | now requires the **family owner** | security |
| `account` Edge Function (NEW function) | `export` → JSON attachment via `Content-Disposition`, caller's profile/family/devices + own `location_events`, `usage_daily`, `safety_alerts`, `audit_logs` rows, 20 000-row cap per table with `truncated` flags; `delete_account` → body `{confirm:"DELETE", email:"<caller email>"}`, refuses while the caller owns a family with other active members or active devices, deletes memberships, profile, then `auth.admin.deleteUser`; `retention_report` → configured windows + last sweep timestamp | lifecycle |
| `policy_ack.result` | additive fields listed in §5 | enforcement |
| `Device.syncHealth` + `onlineWindow` 12 min | derived getter only, no schema change | presence |
| `private.is_parent_of_family(p_user uuid, p_family uuid) returns boolean` | used by `request_remote_session`, `revoke_device`, `unlink_child`, `apply_policy_version`; raises `not_family_parent` (`42501`) | security |

## 7. Change requires review

- **No client calls a service-only RPC directly.** Every write path is an Edge Function action in
  §2 or a table policy in §3. Adding a new client-callable RPC, or granting execute on a new
  function to `authenticated`, is a **breaking contract change** and needs coordinator approval.
- **No new table in Phase 1.** `audit_logs` (text `event_type`), `devices`, `device_policies`,
  `remote_sessions`, `webrtc_signals` and `safe_zones` are the only surfaces to reuse. A new table,
  a new column on an existing table, or a new publication member requires approval.
- **No route may be renamed or removed.** The 26 paths in §1 are a public contract; tests and
  deep links depend on them.
- **Status strings are closed sets.** Accepting an unknown status, or adding an enum value without
  a migration and a client mapping, breaks the ack/policy state machine.
- **Response envelopes are additive only.** New fields may be added to `data`; existing fields may
  not be renamed or removed (clients read them positionally by name).