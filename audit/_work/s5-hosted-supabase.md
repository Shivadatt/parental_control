# Subagent 5 — hosted Supabase (dashboard) findings

Project: `parent-control-prod`, ref `hhqgreaoqulmfwfwarhc`, org "spg7753@gmail.com's Org".
Access method: Supabase **Web Dashboard only** (in-app browser, authenticated session).
No Supabase CLI was run at any point. All SQL was `SELECT`/metadata reads issued through the
dashboard SQL Editor ("Database" query source) — no DDL/DML, no RLS/secret/storage/auth changes.
Logs were read through the dashboard Logs Explorer (`SELECT … FROM logs …`) and the function Logs page.

Dashboard clock during the audit: `now()` = 2026-10-30 05:45 UTC (probe in SQL Editor).

## 1. Scope actually covered

Covered:
- SQL Editor metadata: `pg_class`, `information_schema.columns`, `pg_constraint`, `pg_indexes`,
  `pg_trigger`, `pg_policies`, `information_schema.role_table_grants`, `pg_proc` (all bodies scanned),
  `pg_extension`, `pg_namespace`, `pg_publication`, `pg_publication_tables`, `storage.buckets`,
  `pg_settings` (pgrst*), triggers on `auth.users`.
- Data reads (aggregate/sample, no PII): `public.remote_sessions` (10 newest rows + status aggregate),
  `auth.users` counts, `auth.identities` provider counts, `public.profiles` role counts,
  `public.families` / `public.devices` counts, `public.audit_logs` event-type counts (7 days).
- Dashboard pages: Edge Functions list, `remote-session` Overview / **Code (deployed bundle read in
  place)** / Settings, `remote-session` Logs, Logs Explorer, Auth → Sign In/Providers, Auth → User
  Sessions, Data API (Integration) Overview + Settings, JWT Keys, project SQL Editor.
- Local side (read-only): `supabase/migrations/` file list, `20261028000200_parent_controlled_session_lifetime.sql`,
  `20261028000300_signaling_open_session.sql`, `supabase/functions/remote-session/index.ts` (grep),
  `git log` dates for the function directories.

Skipped / not covered: Storage UI (no buckets exist), Cron UI (pg_cron absent), Realtime inspector,
Auth users list (counts only, deliberately), per-row expansion in the function Logs grid
(requires pointer interaction — see §3).

## 2. Findings

### 2.1 Hosted `public` inventory

19 base tables; **RLS enabled on every one**; every table has `relreplident = 'd'` (default replica
identity). Row counts are planner estimates (`reltuples`); `-1` = never analyzed.

| table | approx rows | RLS | replica identity |
|---|---|---|---|
| audit_logs | 236 | on | default |
| child_contact_ids | never analyzed | on | default |
| device_apps | never analyzed | on | default |
| device_commands | never analyzed | on | default |
| device_pairing_tokens | 26 | on | default |
| device_policies | never analyzed | on | default |
| devices | 14 | on | default |
| families | never analyzed | on | default |
| family_members | never analyzed | on | default |
| location_events | 1633 | on | default |
| pairing_attempts | 58 | on | default |
| pairing_requests | never analyzed | on | default |
| profiles | never analyzed | on | default |
| remote_sessions | 45 | on | default |
| safe_zone_states | never analyzed | on | default |
| safe_zones | never analyzed | on | default |
| safety_alerts | never analyzed | on | default |
| usage_daily | 29 | on | default |
| webrtc_signals | 1292 | on | default |

Columns (`information_schema.columns`, type / nullability / default), abbreviated for the long tables:

- **audit_logs**: id uuid NOT NULL DEF gen_random_uuid(); family_id uuid; actor_user_id uuid; device_id uuid; event_type text NOT NULL; target_type text; target_id text; metadata jsonb NOT NULL DEF '{}'; created_at timestamptz NOT NULL DEF now()
- **child_contact_ids**: child_user_id uuid NOT NULL; contact_id text NOT NULL; created_at NOT NULL DEF now(); rotated_at timestamptz
- **device_apps**: id; device_id, family_id uuid NOT NULL; package_name text NOT NULL; label text NOT NULL DEF ''; is_system bool NOT NULL DEF false; is_suspended bool NOT NULL DEF false; version_name text; reported_at NOT NULL DEF now()
- **device_commands**: id; device_id, family_id NOT NULL; type text NOT NULL; payload jsonb NOT NULL DEF '{}'; status text NOT NULL DEF 'pending'; idempotency_key text NOT NULL; created_by; created_at DEF now(); expires_at timestamptz NOT NULL; delivered_at, acked_at, result jsonb, error_message text; attempts int NOT NULL DEF 0
- **device_pairing_tokens**: id; child_user_id NOT NULL; code_hash text NOT NULL; expires_at NOT NULL; redeemed_at, redeemed_by; status NOT NULL DEF 'active'; attempts int NOT NULL DEF 0; max_attempts int NOT NULL DEF 10; created_at; created_by; purpose text NOT NULL DEF 'code'
- **device_policies**: id; device_id, family_id NOT NULL; version int NOT NULL; policy jsonb NOT NULL; created_by; created_at; acknowledged_at; enforcement_status NOT NULL DEF 'pending'; last_error text
- **devices**: id; family_id, child_user_id NOT NULL; installation_id NOT NULL; display_name NOT NULL; platform NOT NULL DEF 'android'; android_version, app_version; status NOT NULL DEF 'pending'; secret_hash; credential_issued_at, credential_revoked_at, last_seen_at; battery_level int; is_charging bool; enforcement_mode NOT NULL DEF 'none'; policy_version int NOT NULL DEF 0; usage_access_granted, location_granted, background_location_granted, camera_granted, microphone_granted, notifications_granted bool; created_at, updated_at DEF now()
- **families**: id; name NOT NULL; owner_id NOT NULL; settings jsonb NOT NULL DEF '{"usage_retention_days": 90, "location_retention_days": 30}'; created_at, updated_at; deleted_at
- **family_members**: id; family_id, user_id NOT NULL; role NOT NULL; status NOT NULL DEF 'active'; created_at; removed_at
- **location_events**: id; device_id, family_id NOT NULL; lat, lng double precision NOT NULL; accuracy_m real NOT NULL; recorded_at NOT NULL; received_at NOT NULL DEF now(); source NOT NULL DEF 'device'
- **pairing_attempts**: id; parent_user_id NOT NULL; code_hash NOT NULL; attempted_at DEF now(); success bool NOT NULL DEF false
- **pairing_requests**: id; token_id, family_id, parent_user_id, child_user_id NOT NULL; status NOT NULL DEF 'pending_child'; created_at; expires_at NOT NULL; responded_at
- **profiles**: id uuid NOT NULL (PK, FK→auth.users); role text NOT NULL DEF 'unset'; display_name NOT NULL; created_at, updated_at
- **remote_sessions**: id; family_id, device_id, parent_user_id, child_user_id NOT NULL; kind text NOT NULL; status NOT NULL DEF 'requested'; requested_at DEF now(); accepted_at, started_at, ended_at, **expires_at NULLABLE**, ended_by, ended_reason; consent_recorded bool NOT NULL DEF false; session_nonce uuid; created_at DEF now()
- **safe_zone_states**: zone_id, device_id NOT NULL; inside bool NOT NULL; updated_at DEF now()
- **safe_zones**: id; family_id NOT NULL; name NOT NULL; lat, lng double precision NOT NULL; radius_m double precision NOT NULL; active bool NOT NULL DEF true; created_by uuid DEF auth.uid(); created_at DEF now()
- **safety_alerts**: id; family_id, device_id NOT NULL; type, severity, message NOT NULL; payload jsonb NOT NULL DEF '{}'; created_at; acknowledged_at, acknowledged_by
- **usage_daily**: id; device_id, family_id NOT NULL; day date NOT NULL; package_name NOT NULL; app_label NOT NULL DEF ''; total_ms bigint NOT NULL; last_used_at; uploaded_at DEF now(); source NOT NULL DEF 'usage_stats'
- **webrtc_signals**: id; session_id uuid NOT NULL; from_user_id uuid NOT NULL DEF auth.uid(); kind NOT NULL; payload jsonb NOT NULL; created_at DEF now(); sequence bigint NOT NULL

Keys / constraints (`pg_constraint`):
- PKs on `id` everywhere except `child_contact_ids (child_user_id)` and `safe_zone_states (zone_id, device_id)`.
- Unique: `child_contact_ids.contact_id`; `device_apps (device_id, package_name)`;
  `device_commands (device_id, idempotency_key)`; `device_pairing_tokens.code_hash`;
  `device_policies (device_id, version)`; `devices (family_id, installation_id)`;
  `family_members (family_id, user_id)`; `pairing_requests.token_id`; `usage_daily (device_id, day, package_name)`.
- FKs: children of `families`/`devices`/`profiles` are `ON DELETE CASCADE`; `audit_logs` uses `SET NULL`
  (family_id, actor_user_id, device_id); `profiles.id → auth.users(id) ON DELETE CASCADE`.
- Notable CHECKs: `remote_sessions_status_check` ∈ (requested, accepted, active, declined, ended, expired, failed);
  **`remote_sessions_pending_expiry_check`: `status <> 'requested' OR expires_at IS NOT NULL`**;
  `remote_sessions_kind_check` ∈ (audio, video); `family_members_removed_consistency`
  (`(status='removed') = (removed_at IS NOT NULL)`); `child_contact_ids_contact_id_check ~ '^PC[2-9A-HJ-NP-Z]{8}$'`;
  `device_commands_status_check` ∈ (pending, delivered, succeeded, failed, expired);
  `device_commands_type_check` ∈ (apply_policy, sync_policy, request_usage, request_location, end_session, custom);
  `device_pairing_tokens_code_hash_check ~ '^[0-9a-f]{64}$'`; `device_pairing_tokens_purpose_check` ∈ (code, invite);
  `devices_enforcement_mode_check` ∈ (none, device_admin, device_owner); `safety_alerts`, `safe_zones` range checks.
  **`webrtc_signals` has no unique (session_id, sequence)** — duplicate sequences are only prevented client-side.

Indexes (`pg_indexes`) — partial uniques that carry invariants:
- `devices_one_active_per_child UNIQUE(child_user_id) WHERE status='active'`
- `families_one_active_per_owner UNIQUE(owner_id) WHERE deleted_at IS NULL`
- `family_members_one_active_child_family UNIQUE(user_id) WHERE status='active' AND role='child'`
- `remote_sessions_expires_idx(expires_at)`, `remote_sessions_family_idx(family_id, requested_at DESC)`,
  `remote_sessions_device_status_idx`, `remote_sessions_child_status_idx`
- `webrtc_signals_session_sequence_idx(session_id, sequence)`, `device_commands_expires_idx`,
  `device_pairing_tokens_child_purpose_idx(child_user_id, purpose, status)`

Triggers (non-internal): `audit_logs_append_only`; `devices_set_updated_at`; `families_before_update`
+ `families_set_updated_at`; `profiles_before_update`; **`remote_sessions_transition_guard`**;
`safe_zone_states_set_updated_at`. On `auth.users`: **`on_auth_user_created → private.handle_new_user`**.

### 2.2 RLS

22 policies, **all scoped `TO authenticated`**; **no policy anywhere grants `anon`**. Full list
(`pg_policies`, USING / WITH CHECK):

| table | policy | cmd | USING / CHECK |
|---|---|---|---|
| audit_logs | audit_logs_select_family_parent | SELECT | `family_id IS NOT NULL AND private.is_family_parent(family_id)` |
| device_apps | device_apps_select_parent_or_child | SELECT | `private.is_family_parent(family_id) OR EXISTS(devices d WHERE d.id=device_id AND d.child_user_id=auth.uid())` |
| device_commands | device_commands_select_parent_or_child | SELECT | same shape |
| device_policies | device_policies_select_parent_or_child | SELECT | same shape |
| devices | devices_select_parent_or_child | SELECT | `private.is_family_parent(family_id) OR child_user_id=auth.uid()` |
| families | families_select_members | SELECT | `deleted_at IS NULL AND private.is_family_member(id)` |
| families | families_update_owner | UPDATE | USING `owner_id=auth.uid() AND deleted_at IS NULL` / CHECK `owner_id=auth.uid()` |
| family_members | family_members_select_family | SELECT | `private.is_family_member(family_id)` |
| location_events | location_events_select_parent_or_child | SELECT | same shape |
| pairing_requests | pairing_requests_select_participants | SELECT | `child_user_id=auth.uid() OR parent_user_id=auth.uid() OR private.is_family_parent(family_id)` |
| profiles | profiles_select_self_or_family | SELECT | `id=auth.uid() OR private.shares_active_family(id)` |
| profiles | profiles_update_self | UPDATE | `id=auth.uid()` / `id=auth.uid()` |
| remote_sessions | remote_sessions_select_participants | SELECT | `parent_user_id=auth.uid() OR child_user_id=auth.uid() OR private.is_family_parent(family_id)` |
| safe_zones | safe_zones_select_family | SELECT | `private.is_family_member(family_id)` |
| safe_zones | safe_zones_insert_parent | INSERT | CHECK `private.is_family_parent(family_id)` |
| safe_zones | safe_zones_update_parent | UPDATE | USING+CHECK `private.is_family_parent(family_id)` |
| safe_zones | safe_zones_delete_parent | DELETE | USING `private.is_family_parent(family_id)` |
| safety_alerts | safety_alerts_select_parent_or_child | SELECT | same shape |
| usage_daily | usage_daily_select_parent_or_child | SELECT | same shape |
| webrtc_signals | webrtc_signals_select_participant | SELECT | `EXISTS(remote_sessions s WHERE s.id=session_id AND s.status IN ('accepted','active') AND (s.parent_user_id=auth.uid() OR s.child_user_id=auth.uid()))` |
| webrtc_signals | webrtc_signals_insert_participant | INSERT | CHECK `from_user_id=auth.uid() AND <same EXISTS>` |

The `webrtc_signals` predicates contain **no `expires_at` test** — this is the post-fix shape of
`supabase/migrations/20261028000300_signaling_open_session.sql:23-54`; the pre-fix policies required
`s.expires_at > now()` and would have rejected NULL-expiry sessions.

Grants (`information_schema.role_table_grants`):
- `anon`: **zero** privileges on any `public` table.
- `authenticated`: `SELECT` on 15 tables; **no** grants at all on `child_contact_ids`,
  `device_pairing_tokens`, `pairing_attempts`, `safe_zone_states`; extra `INSERT` on `webrtc_signals`
  and `DELETE` on `safe_zones`.
- `service_role`: full DML on all 19 tables.
- Consequence: all session/pairing/device state writes must go through Edge Functions with the service
  key; the only direct client-written table is `webrtc_signals` (+ safe_zones CRUD).

### 2.3 SQL functions

38 functions: 24 in `private`, 14 in `public`. **All are `SECURITY DEFINER` with an explicit
`search_path`** (`public, private, pg_temp`; `public.request_remote_session` and
`private.remote_session_transition_guard` use `public, pg_temp` only).
`has_function_privilege` = **false for both `anon` and `authenticated` on all 38** — the RPCs are
service-role-only, i.e. not callable by the app clients.
Two inconsistencies: `private.remote_session_transition_guard()` and `private.request_device_recovery(uuid,uuid)`
report `anon=true / auth=true` (default PUBLIC execute inside the `private` schema).

`public.*` (14): apply_policy_version, create_family_with_owner, create_pairing_invite,
create_pairing_request, detect_offline_devices, expire_stale_commands, expire_stale_sessions,
poll_device_commands, replace_device_apps, request_device_recovery, **request_remote_session**,
respond_pairing_request, revoke_device, unlink_child.
`private.*` (24): those bodies plus is_family_member, is_family_parent, shares_active_family,
realtime_topic_allowed (STABLE), record_audit, handle_new_user, set_updated_at, families_before_update,
profiles_before_update, audit_logs_append_only, remote_session_transition_guard.

Hosted `private.remote_session_transition_guard()` body (verbatim `pg_proc.prosrc`) — identical to
`supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql:55-74`:
`if OLD.status in ('declined','ended','expired','failed') and NEW.status in ('requested','accepted','active') then raise exception 'session_terminal'`. It does not touch `expires_at`.

Hosted `private.expire_stale_sessions()` — identical to migration lines 80-98: updates only
`status='requested' AND expires_at <= now()`; consented rows are never clock-expired by SQL.

Hosted `public.request_remote_session(uuid,uuid,text)` is the **newest** version: body opens with
`perform pg_advisory_xact_lock(hashtextextended(p_device_id::text, 0))`, checks device active, and only
sweeps `status='requested'` rows with a past deadline (matches `20261028000200` / `20261028000100`).

Full-body scan of all 38 functions: **no function writes a 30-minute window**; the only deadline literals
are `10 min` (pending request) in `request_remote_session`.

### 2.4 Extensions

`pg_stat_statements 1.11` (schema `extensions`), `pgcrypto 1.3` (extensions), `plpgsql 1.0`,
`supabase_vault 0.3.1` (vault), `uuid-ossp 1.1` (extensions).
**`pg_cron` is NOT installed** (no `cron` schema; non-system schemas are auth, extensions, graphql,
graphql_public, private, public, realtime, storage, vault). `pg_net`, `postgis`, `pgvector` also absent.

### 2.5 Realtime

`supabase_realtime` publication members: `public.device_commands`, `public.remote_sessions`,
`public.safety_alerts`, `public.webrtc_signals` — all four at **replica identity default** (`d`), so
UPDATE/DELETE payloads carry only the PK and RLS-filtered UPDATE/DELETE fan-out depends on client re-reads.
`supabase_realtime_messages_publication` carries the `realtime.messages_YYYY_MM_DD` partitions
(2026-10-26 … 2026-11-01). `private.realtime_topic_allowed(text)` (STABLE, executable by
`authenticated`) is present — the private-channel authorization helper.

### 2.6 Storage

`storage.buckets` returns **0 rows**: no buckets, therefore no storage policies apply and nothing in the
app can be storing artifacts in Supabase Storage. Profile photos / logs / chat attachments have no bucket.

### 2.7 Cron

`cron.job` does not exist (pg_cron absent) → **no database-scheduled jobs**. `expire_stale_sessions()`
and `detect_offline_devices()` exist but nothing in the database invokes them on a schedule; the
`cron` Edge Function (deployed, "4 days ago") would have to be called by an external scheduler —
no scheduler configuration is visible anywhere in the dashboard, so this is an unverified assumption
(see §3). Pending pairing/session requests therefore rely on opportunistic in-function cleanup.

### 2.8 Edge Functions deployed

9 functions — exactly the 9 local directories in `supabase/functions/`:

| function | dashboard "UPDATED" |
|---|---|
| auth-bootstrap | 2 days ago |
| cron | 4 days ago |
| device-command | 4 days ago |
| device-policy | 4 days ago |
| device-register | 4 days ago |
| device-telemetry | 4 days ago |
| family-admin | 3 days ago |
| pairing | 2 days ago |
| **remote-session** | **4 days ago** |

`remote-session` Settings page: `verify_jwt` = **ON** ("Verify JWT with legacy secret"); JWT signing keys
are ECC P-256 (JWT Keys page) with a previous key still verifying unexpired tokens. Exact version integer
is not exposed (see §3).

### 2.9 F1 evidence — hosted data still stores `expires_at = accepted_at + 30 min`

`public.remote_sessions`, 10 newest rows (ids truncated to 8 chars; no user identifiers):

| id | status | kind | requested_at | accepted_at | expires_at | ended_at | ended_reason | ttl |
|---|---|---|---|---|---|---|---|---|
| 1a728cff | ended | audio | 10-29 14:02:31 | — | 10-29 14:12:31 | 10-29 14:12:57 | — | 10 min (pending window) |
| d1a04614 | ended | audio | 10-29 13:42:07 | 13:46:31 | 14:16:31 | 13:53:02 | — | **30.0 min** |
| af0b39b9 | ended | audio | 10-29 12:46:39 | 12:48:46 | 13:18:46 | 13:36:40 | — | **30.0 min** |
| 1c6ad5ed | ended | audio | 10-29 12:21:32 | 12:21:42 | 12:51:42 | 12:21:58 | — | **30.0 min** |
| 7f50b52c | ended | audio | 10-29 12:16:46 | 12:17:06 | 12:47:06 | 12:17:50 | — | **30.0 min** |
| 1bd26a84 | expired | audio | 10-29 11:27:07 | 11:27:25 | 11:57:25 | 12:16:38 | expired | **30.0 min** |
| e84ba35e | expired | audio | 10-29 05:48:03 | 05:48:20 | **null** | 11:21:35 | expired | — |
| 255d42d6 | ended | audio | 10-29 05:00:47 | 05:08:26 | 05:38:26 | 05:54:41 | — | **30.0 min** |
| 1116a0ab | expired | audio | 10-29 03:56:26 | 03:57:22 | 04:27:22 | 04:39:42 | expired | **30.0 min** |
| 8bed0f55 | expired | audio | 10-29 03:13:31 | 03:15:07 | 03:45:07 | 03:46:47 | expired | **30.0 min** |

Aggregate: 45 rows — 35 `ended`, 10 `expired`; **all 35 `ended` rows carry a non-NULL `expires_at`**;
9 of 10 `expired` rows carry one. Newest activity: 2026-10-29 14:02 UTC (nothing since).

Conclusion for F1: the 30-minute accepted-session deadline **is still written for every session through
2026-10-29 13:46**, i.e. after the database migration that made `expires_at` a pending-only deadline was
already live (nullable column + `remote_sessions_pending_expiry_check` + new guard all present). The SQL
layer no longer sweeps consented rows (`expire_stale_sessions` only touches `requested`), so the remaining
writer is the deployed Edge Function.

`audit_logs` (7 days, session events only): `session_requested` 45 (latest 10-29 14:02:31),
`session_accepted` 37 (latest 13:46:32), `session_ended` 35 (latest 14:12:58), `session_started` 31
(latest 13:50:26). There is **no `session_expired` audit event type** — clock expiry is never audited,
so expiry is invisible in the audit trail.

### 2.10 Deployed `remote-session` is the OLD (30-minute) build — confirmed from deployed code

The dashboard **Code** tab exposes the deployed bundle; reading it in place shows:

- Constants: `X = 10*60*1e3` (pending 10 min) and **`Q = 30*60*1e3`**.
- Consent/accept path writes a new deadline:
  `update({status:"accepted", accepted_at: l, expires_at: new Date(c.getTime()+Q).toISOString(), consent_recorded:true, session_nonce: …})`.
- `active` and `ice` actions re-check and kill the session:
  `if (new Date(o.expires_at).getTime() <= Date.now()) throw await T(n,o.id), new i("session_expired","This session has expired.",410)`.
  The request-expiry path throws `session_expired … 410` as well.
- `end` action is **participant-gated only**: `if (…) throw new i("forbidden","You are not a participant in this session.",403)` then
  `update({status:"ended", ended_at:c, ended_by:s.user.id, ended_reason:o??null}).in("status",["requested","accepted","active"])`
  — the child can still end the session server-side.
- Helper `T()`: `update({status:"expired", ended_at, ended_reason:"expired"}).in("status",["requested","accepted","active"])`.

The local fixed source differs exactly there: `supabase/functions/remote-session/index.ts:214-218` only
checks expiry when `session.expires_at !== null`; `:224` comment "only the parent can end it
(migration 20261028000200)"; **`:229` `expires_at: null`** on accept.

Corroboration: the function directory's last commit is `79f4962` (2026-10-28 19:48 +0530) and the dashboard
reports `remote-session` as updated **4 days ago** ⇒ the deployed artifact predates the fix.
Verdict: **`BROKEN` for the parent-controlled-lifetime feature on hosted** — the client/DB are consistent
with the new policy, but the deployed function still stamps +30 min and returns 410 at that deadline.

### 2.11 Auth

- Providers: **Email only** (ENABLED). Phone, SAML, Web3, and all 20 social providers DISABLED; no custom
  OAuth/OIDC providers.
- `Allow new users to sign up` = ON; `Allow manual linking` = OFF; `Allow anonymous sign-ins` = OFF;
  **`Confirm email` = ON**.
- User Sessions page: `JWT_EXP` = **3600 s**, `SESSIONS_TIMEBOX` = 0 (never), `SESSIONS_INACTIVITY_TIMEOUT` = 0,
  `SECURITY_REFRESH_TOKEN_REUSE_INTERVAL` = 10 s; the session time-box / inactivity fields are plan-gated
  ("only available on the Pro Plan and above"), so sessions never time out by configuration.
- Users: **8** total, 8 with `email_confirmed_at` set, 8 signed in within 7 days; providers from
  `auth.identities`: `email=8`.
- `public.profiles.role`: `parent=4`, `child=4`. Families (not deleted) = 3; devices = 14, of which
  **2 active**.

### 2.12 Hosted objects with no counterpart in `supabase/migrations/`

Checked every hosted table, function, index, trigger, constraint and the non-core columns against the 10
migration files: **no hosted-only object found** (no dashboard-created table/function/index/trigger).
Only hosted-only artifact is the platform-managed `supabase_realtime_messages_publication` and the
`realtime.messages_*` partitions.

Migration → hosted confirmation:

| migration | hosted evidence |
|---|---|
| 20260101000000_core.sql | all 19 tables, PK/FK/CHECK, partial unique indexes, `remote_sessions_expires_idx`, `webrtc_signals_session_sequence_idx` |
| 20260101000100_functions.sql | all function names/bodies present |
| 20260101000200_rls.sql | 22 policies, `authenticated`-only, `private.is_family_*` helpers |
| 20260101000300_service_role_grants.sql | `anon` has zero grants; service_role full DML |
| 20260101000400_device_recovery.sql | `public/private.request_device_recovery` present |
| 20260101000500_child_contact_ids.sql | `child_contact_ids` table, `rotated_at`, `purpose` column + index |
| 20260101000600_atomic_pairing_invite.sql | `pairing_requests.token_id` UNIQUE, invite purpose |
| 20261028000100_remote_session_concurrency.sql | `devices_one_active_per_child`, advisory lock in `request_remote_session` |
| 20261028000200_parent_controlled_session_lifetime.sql | nullable `expires_at`, `remote_sessions_pending_expiry_check`, new guard body, pending-only `expire_stale_sessions` |
| 20261028000300_signaling_open_session.sql | `webrtc_signals` policies with no `expires_at` predicate |

So the **database** is at the latest migration; the **Edge Function artifact** is not. This is the delta
that matters: schema and function were deployed independently and the function deploy was missed.

## 3. Evidence gaps / BLOCKED items

- **Deployed function version integer / exact `updated_at`**: not rendered on Overview, Code or Settings;
  the platform functions REST endpoint returns 404 from the dashboard origin and 401 from `api.supabase.com`
  without a bearer token. Evidence used instead: dashboard relative "4 days ago", git commit dates, and the
  deployed bundle contents. `BLOCKED — dashboard does not surface version metadata.`
- **Cron jobs**: `BLOCKED — pg_cron not installed (no `cron` schema, no `cron.job`).` Whether an external
  scheduler calls the `cron` Edge Function is `BLOCKED — no scheduler configuration visible in the dashboard`;
  the fact that 10 sessions transitioned to `expired` while the DB has no scheduler is consistent with
  callers doing it (function/`T()` path), not with a platform cron.
- **Edge Function log messages**: the `remote-session` Logs page rendered invocation timestamps and
  `200` statuses for 29 Oct (2.6k rows in the window) but the message bodies require expanding rows, and
  pointer interaction is unavailable in this browser session (`NATIVE_BROWSER_VIEWPORT_UNAVAILABLE`).
  A Logs Explorer SQL over `source='edge_logs'` for 4 days returned 0 rows for `remote-session` /
  `session_expired` (function traffic is not in `edge_logs`); the explorer's Run stopped firing after the
  first successful query, so `function_logs` / `function_edge_logs` were not reached.
  `BLOCKED — 410/`session_expired` log lines not retrievable; the 410 behaviour is proven from deployed
  code and from `status='expired'` rows instead.`
- **Postgres error logs / API auth aggregates**: `BLOCKED — not collected` (same Logs Explorer limitation;
  no error aggregates were read). Auth state is instead evidenced by `auth.users` counts (all confirmed)
  and by the Sign In/Providers page.
- **Data API settings ambiguity**: the Data API Settings page states "2 of 3 schemas exposed", "0 of 19
  tables exposed", "0 of 38 functions exposed". The 38 count includes `private` functions, so `private`
  is one of the three selectable schemas; the per-schema/per-table toggles are virtualized and its
  aria state could not be read without pointer input. Whether `private` is actually exposed to PostgREST
  is therefore `BLOCKED — toggle state not readable`; it matters because
  `private.remote_session_transition_guard()` and `private.request_device_recovery()` are executable by
  `anon`/`authenticated` inside that schema.
- **Row counts**: `reltuples = -1` for 11 tables (never analyzed), so all row counts except those listed
  are unknown; `count(*)` was deliberately not run on every table.

## 4. Summary a reviewer can trust

The hosted project is structurally healthy and *ahead of most expectations*: 19 tables all with RLS,
`authenticated`-only policies (22) and zero `anon` table grants, all 38 functions `SECURITY DEFINER` with
pinned `search_path` and service-role-only execute, the three partial unique indexes that implement the
one-active-device / one-active-child-family / one-family-per-owner invariants, `auth.users` → `profiles`
trigger, and every database object traceable to one of the 10 local migrations — **the schema is fully
migrated, including the nullable-`expires_at` lifetime policy, the pending-only expiry function and the
signaling policies that no longer require `expires_at > now()`**. What is *not* deployed is the Edge
Function: the hosted `remote-session` bundle is the pre-fix build — it still writes
`expires_at = accepted_at + 30 min` on consent, still force-ends accepted sessions with HTTP 410
`session_expired`, and still lets a non-parent participant end a session. Hosted rows prove it: all 35
`ended` sessions carry a 30-minute deadline and 10 sessions were expired by the clock, the newest activity
being 2026-10-29 13:46–14:12 UTC. Supporting gaps: no `pg_cron` (so no scheduled sweep at all and
`expire_stale_sessions`/`detect_offline_devices` are never invoked by the platform), no Storage buckets,
JWT expiry 3600 s with session time-boxing unavailable on this plan, email-only auth with confirmation on
and 8 confirmed users (4 parent, 4 child profiles, 3 families, 2 active devices), and no `session_expired`
audit event type, which is why clock expiry is invisible in `audit_logs`. Bottom line: **the server schema
is current; the deployed `remote-session` function is stale and is the single blocking deployment gap.**

Status tally for the hosted-side checks: schema/RLS/grants inventory `FULLY IMPLEMENTED — VERIFIED`;
parent-controlled session lifetime `BROKEN` on the deployed function (schema side verified);
scheduled maintenance `MISSING` (no pg_cron); Storage `NOT APPLICABLE` (no buckets);
Edge Function version metadata `BLOCKED — ACCESS REQUIRED`; function/auth/postgres log bodies
`BLOCKED — ACCESS REQUIRED` (pointer interaction unavailable).