# Subagent 4 — local backend implementation findings

Read-only audit of `D:\parentcontrol_app`. No repository file was modified, no
Supabase CLI command was run, no database was contacted, no secret is reproduced
below (keys/secrets are named only). Hosted-database state is **not** asserted
here; where docs record hosted facts they are cited as documents.

## 1. Scope actually covered (files/dirs read; anything skipped and why)

Read in full, every line:

- `supabase/migrations/` — all 10 files:
  `20260101000000_core.sql` (640 lines), `20260101000100_functions.sql` (971),
  `20260101000200_rls.sql` (360), `20260101000300_service_role_grants.sql` (17),
  `20260101000400_device_recovery.sql` (89), `20260101000500_child_contact_ids.sql` (54),
  `20260101000600_atomic_pairing_invite.sql` (215),
  `20261028000100_remote_session_concurrency.sql` (119),
  `20261028000200_parent_controlled_session_lifetime.sql` (189),
  `20261028000300_signaling_open_session.sql` (55).
- `supabase/config.toml` (91 lines).
- `supabase/functions/_shared/` — `auth.ts` (337), `cors.ts` (12), `envelope.ts` (111),
  `rate_limit.ts` (210), `turn.ts` (106), `audit.ts` (37), `enrollment.ts` (13),
  `validation.ts` (418, plus targeted reads of the hashing/date helpers),
  `policy.ts` (first 120 of 304 lines + export/const survey).
- `supabase/functions/` — `auth-bootstrap` (139), `cron` (70), `device-command` (387),
  `device-policy` (98), `device-register` (249), `device-telemetry` (435),
  `family-admin` (270), `pairing` (971), `remote-session/index.ts` (380),
  `remote-session/guard.ts` (155).
- Cross-check sources: `lib/data/repositories/*.dart` (all 11 + `services/edge_api.dart`
  surveyed through greps and full reads of `supabase_pairing_repository.dart`,
  `supabase_remote_session_repository.dart`, `supabase_policy_repository.dart`,
  `supabase_device_repository.dart` head, `supabase_family_repository.dart` excerpts,
  `supabase_auth_repository.dart` excerpt).
- Docs used for evidence only: `docs/runtime-failure-analysis.md` (148 lines, full),
  `docs/backend.md` §1-§120, `docs/stage7_hosted_migration_apply_2026-10-29.md` (158,
  full), `docs/pairing-recovery-fix-report.md` §1-§3, `docs/api-contract.md`
  §228-236/§500-515, `supabase/tests/README.md` §1-§60.
- Read-only git: `git log`, `git diff --stat 8eee1b1 HEAD -- supabase`,
  `git status`. No write git command.

Deliberately **not** covered (other agents / out of scope): Flutter UI and
controllers, Kotlin services, hosted dashboard/DB state, Android manifest.
`supabase/functions/pairing` and `remote-session/index.ts` were read in full;
the other function bodies were read in full as well. `_shared/policy.ts` was only
partially read (validation helpers for app rules were read; the remainder was
sampled via exported names) — flagged as a gap in §3.

No test was executed in this audit (no SQL suite, no `deno test`, no app run);
every automated-test statement below therefore cites an existing test file or a
documented run, not my own execution.

---

## 2. Findings

### 2.1 Table inventory (19 tables, all in `public`)

| # | Table | Purpose | Keys / FKs | Indexes & constraints |
|---|---|---|---|---|
| 1 | `profiles` | App profile + role; created by auth trigger | PK `id` → `auth.users(id)` cascade (`core.sql:17-18`) | role/name checks, `updated_at` (`core.sql:19-25`) |
| 2 | `families` | Family owned by one parent, soft delete | PK; `owner_id`→`profiles` cascade (`core.sql:33-43`) | unique active family per owner `families_one_active_per_owner` (`core.sql:48-50`); settings jsonb object check (`:37-39`) |
| 3 | `family_members` | parent/child membership, removable | FK family & user cascade (`core.sql:55-66`) | unique `(family_id,user_id)` `:63`; one active child family (partial unique) `:69-71`; removed/removed_at consistency `:64-65`; 2 indexes `:73-74` |
| 4 | `devices` | Enrolled child Android installation + credential hash | FK family, child profile (`core.sql:79-114`) | unique `(family_id, installation_id)` `:111`; revoked⇒no secret `:112-113`; one active device per child `:117-119`; 3 indexes `:121-123` |
| 5 | `device_pairing_tokens` | Short-lived child codes and internal invites | FK child; `redeemed_by`, `created_by` set null (`core.sql:128-142`) | `code_hash` unique + 64-hex check `:131-132`; `purpose` added later (`00500:45-47`); 2+1 indexes `core.sql:144-147`, `00500:52-53` |
| 6 | `pairing_requests` | Parent→child consent request (one token) | `token_id` unique FK; family/parent/child FKs (`core.sql:152-164`) | status enum `:159-160`; 3 indexes `:166-171`; atomic creation in `00600` |
| 7 | `device_policies` | Versioned policy documents | FK device/family; `created_by` (`core.sql:176-189`) | unique `(device_id, version)` `:188`; enforcement enum `:185-186` |
| 8 | `device_commands` | Parent→device command queue | FK device/family; `created_by` (`core.sql:196-219`) | unique `(device_id,idempotency_key)` `:217-218`; type enum `:200-202`; 2 indexes `:221-223` |
| 9 | `usage_daily` | Per-day per-package usage | FK device/family (`core.sql:228-243`) | unique `(device_id,day,package_name)` `:242`; 2 indexes `:245-246` |
| 10 | `location_events` | Raw location samples | FK device/family (`core.sql:251-262`) | lat/lng/accuracy checks `:255-257`; 2 desc indexes `:264-267` |
| 11 | `safe_zones` | Geofences, parent-managed | FK family; `created_by default auth.uid()` (`core.sql:272-282`) | radius 50-5000 m `:278`; index `:284` |
| 12 | `safe_zone_states` | Last inside/outside per zone×device (service-only) | composite PK `(zone_id,device_id)` (`core.sql:286-292`) | cascade on both FKs; updated_at trigger `:449-451` |
| 13 | `safety_alerts` | Alerts (battery/offline/geofence/…) | FK family/device; `acknowledged_by` (`core.sql:297-311`) | type enum `:301-303`; 2 desc indexes `:313-316` |
| 14 | `remote_sessions` | Consent + lifetime of audio/video assistance | FKs family/device/parent/child (`core.sql:321-345`) | `expires_at` nullable since `00200:35-36`; pending-only expiry check `00200:40-42`; 4 indexes `core.sql:347-353` |
| 15 | `webrtc_signals` | SDP/ICE rows for a session | FK session cascade; `from_user_id default auth.uid()` (`core.sql:358-367`) | `kind` enum `:363`; payload ≤16 384 bytes `:364`; identity `sequence` `:366`; index `:369-370` |
| 16 | `audit_logs` | Append-only accountability trail | FK family/actor/device set-null (`core.sql:375-386`) | append-only trigger `:543-565`; 2 indexes `:388-390` |
| 17 | `device_apps` | Installed-app snapshot (replace-all) | FK device/family (`core.sql:395-407`) | unique `(device_id,package_name)` `:406` |
| 18 | `pairing_attempts` | Failed/successful lookup log for rate limits | FK parent (`core.sql:414-420`) | 64-hex check `:417`; 2 indexes `:422-425`; **never pruned** |
| 19 | `child_contact_ids` | Permanent "Child ID" identifier | PK/FK child (`00500:18-26`) | `contact_id` unique + regex `:22-23`; RLS on, zero policies `:33-35` |

RLS is enabled on **all 19** tables (`rls.sql:5-22` plus `00500:33`) — no table
with RLS disabled exists in the local chain.

Notes: `remote_sessions.session_nonce` (`core.sql:343`) is written by
`remote-session` accept (`remote-session/index.ts:231`) but **no policy, function
or client reads it** — verified by repo-wide grep (only the column, its writes,
fixtures and docs reference it). It is a vestigial column, not an authorization
credential.

### 2.2 RLS matrix (21 table policies + 1 realtime policy)

`anon` has **no** table privilege at all (`rls.sql:247-248`); `service_role`
bypasses RLS and holds explicit DML grants (`20260101000300_service_role_grants.sql:9-17`).
All table policies are `to authenticated`.

| Table | S | I | U | D | Policy name(s) | Predicate summary |
|---|---|---|---|---|---|---|
| `profiles` | ✅ | – | ✅ | – | `profiles_select_self_or_family` `rls.sql:27-31`; `profiles_update_self` `:33-38` | self, or `private.shares_active_family(id)`; update only self and only `display_name` column (`:251`) |
| `families` | ✅ | – | ✅ | – | `families_select_members` `:43-47`; `families_update_owner` `:49-54` | active member sees non-deleted family; update only `owner_id = auth.uid()`, columns `name, settings` (`:254`) |
| `family_members` | ✅ | – | – | – | `family_members_select_family` `:59-63` | `private.is_family_member(family_id)`; membership writes only via RPC |
| `devices` | ✅ | – | – | – | `devices_select_parent_or_child` `:68-72` | parent of family **or** `child_user_id = auth.uid()`; column grant deliberately excludes `secret_hash`,`installation_id` (`:259-266`) |
| `device_pairing_tokens` | – | – | – | – | none (`:74`) | service-only; no grants (`:286-288`) |
| `pairing_requests` | ✅ | – | – | – | `pairing_requests_select_participants` `:79-87` | child, requesting parent, or **any parent in the family** |
| `device_policies` | ✅ | – | – | – | `device_policies_select_parent_or_child` `:92-99` | family parent or owning child (child must be able to read its policy) |
| `device_commands` | ✅ | – | – | – | `device_commands_select_parent_or_child` `:101-108` | family parent or owning child |
| `usage_daily` | ✅ | – | – | – | `usage_daily_select_parent_or_child` `:113-120` | family parent or owning child |
| `location_events` | ✅ | – | – | – | `location_events_select_parent_or_child` `:122-129` | family parent or owning child |
| `device_apps` | ✅ | – | – | – | `device_apps_select_parent_or_child` `:131-138` | family parent or owning child |
| `safe_zones` | ✅ | ✅ | ✅ | ✅ | `safe_zones_select_family` `:143-147`, `_insert_parent` `:149-153`, `_update_parent` `:155-160`, `_delete_parent` `:162-166` | member reads; parent writes; **DELETE policy contradicts the file header "no client DELETE policies"** (`:2`) |
| `safe_zone_states` | – | – | – | – | none (`:168`) | service-only |
| `safety_alerts` | ✅ | – | – | – | `safety_alerts_select_parent_or_child` `:173-180` | family parent or owning child; acknowledgement only through `family-admin` |
| `remote_sessions` | ✅ | – | – | – | `remote_sessions_select_participants` `:185-193` | parent/child participant **or any family parent**; all writes via Edge/RPC |
| `webrtc_signals` | ✅ | ✅ | – | – | `webrtc_signals_select_participant` `00300:25-37`, `webrtc_signals_insert_participant` `00300:41-54` | participant of a session with status `accepted`/`active`; insert additionally requires `from_user_id = auth.uid()`; **no `expires_at > now()`** (removed deliberately, `00300:1-21`) |
| `audit_logs` | ✅ | – | – | – | `audit_logs_select_family_parent` `:236-240` | family parent, `family_id` not null; UPDATE/DELETE additionally blocked by trigger `core.sql:543-565` |
| `pairing_attempts` | – | – | – | – | none (`:242`) | service-only |
| `child_contact_ids` | – | – | – | – | none (`00500:33-35`) | service-only, returned only by `pairing.get_contact_id` |
| `realtime.messages` | ✅ | – | – | – | `parentcontrol_private_topics` `rls.sql:344-359` | `private.realtime_topic_allowed(realtime.topic())` `:295-332` — topic `safety-alerts:<family-uuid>` / `remote-session-family:<family-uuid>` ⇒ family member; `remote-session:<session-uuid>` / `webrtc-signals:<session-uuid>` ⇒ session child or family parent |

Policy observations:

1. **`webrtc_signals` was re-created after the lifetime change** (`00300:23-54`);
   if only `00200` were applied, consented rows with `expires_at = NULL` could not
   carry SDP/ICE at all — the file comment records this history (`00300:9-18`).
2. **Over-broad by design (not a defect, but worth review):** any *family* parent
   can read another parent's `pairing_requests` and `remote_sessions`
   (`rls.sql:79-87`, `:185-193`) and join the family realtime topics
   (`rls.sql:317-319`); the child can join the family `safety-alerts` channel even
   though row RLS only shows its own device rows (`rls.sql:317-319` vs `:173-180`).
3. **Boolean-helper RPC surface:** `authenticated` holds EXECUTE on
   `private.is_family_member`, `is_family_parent`, `shares_active_family`
   (`core.sql:632-639`; needed because RLS is evaluated with caller privileges,
   comment `core.sql:628-631`). They are PostgREST-invisible (private schema) but
   still a membership oracle for any SQL-level `authenticated` session.
4. `authenticated` has whole-row SELECT on `remote_sessions` (`rls.sql:273`),
   so `session_nonce` and `ended_reason` are visible to family parents; both are
   non-secret by design (`api-contract.md:233`).

### 2.3 SQL function / trigger inventory (38 functions, 8 triggers)

`search_path` is set on **every** function (no exception found). `service_role`
owns every wrapper's EXECUTE grant; `public`/`anon`/`authenticated` are revoked
(`functions.sql:828-904`, `00500`, `00600:198-214`, `00400:85-88`, `00100:112-118`,
`00200:183-188`).

| Function | Schema | Definer? | search_path | EXECUTE granted to | Caller |
|---|---|---|---|---|---|
| `set_updated_at` | private | no (invoker) | public, private, pg_temp (`core.sql:433`) | triggers only (`func:852-853` revokes) | 3 triggers |
| `handle_new_user` | private | **definer** (`core.sql:459`) | public, private, pg_temp | trigger only | `on_auth_user_created` |
| `profiles_before_update` | private | no | same | trigger only | trigger |
| `families_before_update` | private | no | same | trigger only | trigger |
| `audit_logs_append_only` | private | no | same | trigger only | trigger |
| `is_family_member` | private | **definer** | same | **authenticated** + service_role (`core.sql:633`) | RLS + realtime policy |
| `is_family_parent` | private | **definer** | same | authenticated + service_role (`:634`) | RLS |
| `shares_active_family` | private | **definer** | same | authenticated + service_role (`:635`) | RLS |
| `record_audit` | private | **definer** | public, private, pg_temp | service_role (`func:861`) | other RPCs |
| `create_family_with_owner` | private | **definer** | same | service_role (`:863`) | `auth-bootstrap` |
| `apply_policy_version` | private | **definer** | same | service_role (`:864`) | `device-policy`, `device-command` |
| `respond_pairing_request` | private | **definer** | same | service_role (`:865`) | `pairing.respond` |
| `unlink_child` | private | **definer** | same | service_role (`:866`) | `pairing.unlink`, `request_device_recovery` |
| `revoke_device` | private | **definer** | same | service_role (`:867`) | `family-admin.revoke_device` |
| `expire_stale_sessions` (v1) | private | **definer** | same | service_role (`:868`) | superseded by `00200:80-99` (pending-only) |
| `detect_offline_devices` | private | **definer** | same | service_role (`:869`) | `cron` only |
| `expire_stale_commands` | private | **definer** | same | service_role (`:870`) | **no caller (dead)** |
| `poll_device_commands` | private | **definer** | same | service_role (`:871`) | `device-command.poll` |
| `replace_device_apps` | private | **definer** | same | service_role (`:872`) | `device-telemetry.apps_upload` |
| `realtime_topic_allowed` | private | **definer** | same (`rls.sql:300`) | **authenticated** (`rls.sql:336`) | realtime policy |
| `request_device_recovery` | private | **definer** | same (`00400:22`) | service_role (`00400:87`) | `family-admin.recover_device` |
| `create_pairing_invite` | private | **definer** | same (`00600:35`) | service_role (`00600:207`) | `pairing.invite`/`redeem` |
| `create_pairing_request` | private | **definer** | same (`00600:106`) | service_role (`00600:209`) | `pairing.redeem` |
| `remote_session_transition_guard` | private | **definer** | `public, pg_temp` (`00200:59`) | trigger only | `remote_sessions_transition_guard` |
| `create_family_with_owner` | public | **definer** | public, private, pg_temp | service_role (`func:895`) | thin wrapper (`:709-719`) |
| `apply_policy_version` | public | **definer** | same | service_role (`:896`) | wrapper `:721-733` |
| `respond_pairing_request` | public | **definer** | same | service_role (`:897`) | wrapper `:735-746` |
| `unlink_child` | public | **definer** | same | service_role (`:898`) | wrapper `:748-759` |
| `revoke_device` | public | **definer** | same | service_role (`:899`) | wrapper `:761-771` |
| `expire_stale_sessions` | public | **definer** | same | service_role (`:900`) | wrapper `:773-780` |
| `detect_offline_devices` | public | **definer** | same | service_role (`:901`) | wrapper `:782-789` |
| `expire_stale_commands` | public | **definer** | same | service_role (`:902`) | **no caller (dead)** |
| `poll_device_commands` | public | **definer** | same | service_role (`:903`) | wrapper `:800-810` |
| `replace_device_apps` | public | **definer** | same | service_role (`:904`) | wrapper `:812-823` |
| `request_device_recovery` | public | **definer** | same | service_role (`00400:87-88`) | wrapper `00400:73-83` |
| `create_pairing_invite` | public | **definer** | same | service_role (`00600:211`) | wrapper `00600:161-176` |
| `create_pairing_request` | public | **definer** | same | service_role (`00600:213`) | wrapper `00600:178-193` |
| `request_remote_session` | public | **definer** | `public, pg_temp` (`00200:114`) | service_role (`00200:187`) | `remote-session.request` |

Notable internals:

- `apply_policy_version` takes a `for update` row lock on the device, allocates
  `max(version)+1`, writes the policy and an `apply_policy` command with a 900 s
  expiry in one transaction (`functions.sql:116-176`).
- `poll_device_commands` expires stale rows, claims ≤20 pending rows with
  `for update skip locked`, then returns **all** `delivered` rows (including ones
  that are still pending retries) — a device that never acks keeps receiving the
  same rows until `expires_at` (`functions.sql:596-651`).
- `respond_pairing_request` re-checks: request belongs to the calling child,
  still `pending_child`, not expired, token still active, parent still an active
  parent, child not already linked, and re-activates a previously removed
  membership instead of duplicating it (`functions.sql:208-274`).
- `unlink_child` cascades the unlink into devices, remote sessions, pairing
  tokens and pending requests in one transaction (`functions.sql:375-406`).
- `revoke_device` cancels the child's pending requests so a pre-revocation
  approval cannot resurrect enrolment (`functions.sql:483-489`).
- `request_remote_session` is an advisory-lock + in-lock expiry guard; a live
  consented session is never ended to admit a new one (`00200:124-153`).
- `create_pairing_invite` / `create_pairing_request` serialise on a
  `(child,family,parent)` advisory lock `00600:51-56, 119-124` and are
  idempotent for a live request (`00600:58-69, 126-137`).
- `record_audit` validates `event_type` length before insert (`functions.sql:25-27`);
  the Edge `_shared/audit.ts` bypasses it and inserts into `audit_logs` directly
  (`audit.ts:20-28`) — two audit write paths, one validated, one not.

Triggers (8): `families_set_updated_at`, `devices_set_updated_at`,
`safe_zone_states_set_updated_at` (`core.sql:441-451`), `on_auth_user_created`
(`:483-486`), `profiles_before_update` (`:514-516`), `families_before_update`
(`:536-538`), `audit_logs_append_only` (`:563-565`), `remote_sessions_transition_guard`
(`00200:70-74`).

**Immutability guard weakness (latent):** the "service context" tests in three
triggers are `current_user in ('service_role','postgres','supabase_admin', …)`
(`core.sql:502-505`, `:525-529`, `:549-553`). Inside any `SECURITY DEFINER`
function `current_user` is the function owner (in practice `postgres`), which is
in that allow-list, so a future definer path that updates `profiles.role`,
`families.owner_id` or `audit_logs` would silently pass the guard. Today no RPC
touches those columns (verified by reading every function body), so this is
latent, not an active hole; `session_user`/`auth.role()` would be the correct
predicate.

### 2.4 Realtime publication membership

Guarded at migration time (`functions.sql:909-944`): when the
`supabase_realtime` publication exists, these four tables are added —
`device_commands` (`:917`), `safety_alerts` (`:924`), `remote_sessions` (`:931`),
`webrtc_signals` (`:938`). Client subscriptions exist for three of them
(`lib/data/repositories/supabase_alert_repository.dart:70-71`,
`supabase_remote_session_repository.dart:230-244, 334-357`); **`device_commands`
is published but no client subscribes** (the child long-polls via
`device-command.poll`), i.e. publication entry exists but is unused.

Private-channel authorization is a single topic parser
(`rls.sql:295-332`) applied through a policy on `realtime.messages`
(`rls.sql:349-354`). The client appends a third topic segment
(`safety-alerts:<family>:<micros>`, `webrtc-signals:<session>:<micros>`), which
the parser tolerates because it only inspects segments 1–2
(`rls.sql:310-315`). Whether the Realtime server hands the topic to RLS exactly
as the client wrote it could not be verified without a server — see §3.

### 2.5 Storage

No bucket and no storage policy exists anywhere in the local backend (grep for
`storage.buckets`/`storage.objects` returns nothing; no Dart code references
Supabase Storage). `config.toml:30-32` merely enables the local storage service
with a 50 MiB limit. Screen-recording capture/upload (`docs/screen-recording-plan.md`)
has **no server-side storage path** — `MISSING` at the backend level.

### 2.6 Cron / scheduled work

Two pg_cron jobs are registered only when the extension already exists
(`functions.sql:949-970`): `parentcontrol-expire-sessions` every 5 min calling
`private.expire_stale_sessions()`, `parentcontrol-detect-offline` every 10 min
calling `private.detect_offline_devices()`. Locally nothing installs `pg_cron`
(`config.toml` has no extension block), and `docs/stage7_hosted_migration_apply_2026-10-29.md:24`
records `pg_cron` absent on the hosted project. The alternative trigger — the
`cron` Edge Function — needs `CRON_SECRET` (`cron/index.ts:19-33`), which
`docs/backend.md:21` records as **not set**, and **no caller for the `cron`
function exists in the repo** (no scheduler config, no Dart/Kotlin/script call).

Consequence: `private.detect_offline_devices` is the **only** producer of
`safety_alerts.type='offline'` (`functions.sql:531-573`; every other alert type is
written inline by `device-telemetry` at `index.ts:121-148, 323-339`), so the
"device offline" alert can never be generated in the current deployment shape.
`expire_stale_sessions` is redundant for `requested` rows because
`request_remote_session` expires them in-lock (`00200:137-144`) and the child's
`pending_child` action expires its own (`remote-session/index.ts:175-181`);
`expire_stale_commands` is dead code (§2.3).

### 2.7 Edge Functions (9 functions + 9 shared modules)

Config (`supabase/config.toml`): `api` on 54321 with `max_rows = 1000`
(`:7-12`), `db` PG major 15 (`:14-18`) while hosted is PostgreSQL 17.11
(`docs/backend.md:15`), storage/inbucket/studio on, realtime on (`:30-36`),
`auth` with email confirmation on and anonymous off (`:37-53`), edge runtime
oneshot (`:55-57`). Per-function JWT policy (`:61-90`): `verify_jwt = true` for
`auth-bootstrap`, `pairing`, `device-register`, `device-policy`, `family-admin`,
`remote-session`; `false` for `device-command`, `device-telemetry`, `cron`
(these self-authenticate). No secret value is present in the file.

| Function | Actions | Authentication | Authorization | Input validation | Errors | Rate limit | Tables/RPCs touched |
|---|---|---|---|---|---|---|---|
| `pairing` | `get_contact_id`, `create`, `redeem`, `invite`, `pending_child`, `respond`, `cancel`, `list_family`, `unlink` (`index.ts:446-963`) | user JWT + **verified email** every action (`:449, 456, 547, 761, 779, 813, 830, 906, 930`) | role check (`requireRole`) + `assertFamilyParent`/`assertChildMembership` on every family-scoped action (`:551, 764, 844, 909, 936-939`); `respond` relies on the RPC's child match (`:818-822`) | code/Child-ID format, uuid, boolean (`:549-553, 767, 815-816`); envelope 512 KiB body cap (`envelope.ts:65-92`) | `invalid_code` (uniform 400 for unknown/expired/wrong role, `:47, 569-571, 581-584, 585-599`), `code_expired` 410, `child_already_linked` 409, `code_unavailable` 409, `rate_limited` 429, `unknown_action` 400 | per-parent 5 failures/10 min, per-identifier 10/10 min (`rate_limit.ts:12-14, 51-88`), 5 live codes/24 h + 10 mints/h (`:16-18, 116-160`), 3 pending + 10 invites/24 h per child (`:20-21, 169-210`) | `device_pairing_tokens`, `pairing_requests`, `pairing_attempts`, `child_contact_ids`, `profiles`, `family_members`, `families`, `audit_logs`; RPCs `create_pairing_invite`, `create_pairing_request`, `respond_pairing_request`, `unlink_child` |
| `device-telemetry` | `heartbeat`, `usage_upload`, `location_upload`, `apps_upload` (`:68-427`) | **device credential** only: `x-device-id` + `x-device-secret`, SHA-256 constant-time compare (`auth.ts:281-337`) | device row itself defines `id`/`family_id`/`child_user_id`; no client-supplied device id is accepted (`:115-118, 233, 343, 410-413`) | numeric ranges, ISO dates, ≤500 entries, duplicate detection, package names, future/7-day location window (`:70-112, 172-229, 241-259, 370-408`) | `validation_error`, `invalid_timestamp`, `device_auth_required`, `invalid_device_credentials`, `device_revoked`, `unknown_action` | none (see F-13) | `devices` (update), `safety_alerts` (insert), `usage_daily` (upsert), `location_events` (insert), `safe_zones` (read), `safe_zone_states` (upsert); RPC `replace_device_apps` |
| `remote-session` | `request`, `session_state`, `pending_child`, `respond`, `start`, `end`, `ice` (`:108-372`) | `request`/`pending_child`/`respond`/`start`/`end`/`ice`: user JWT + verified email; `session_state`: **device credential** (`:151`) | `request` → `requireActiveDeviceForParent` (`:113`, `auth.ts:253-275`); `session_state` → session must match device id **and** child id (`guard.ts:87-106`); `respond`/`start` → child must equal `child_user_id` (`:201, 272`); `end` → **only the requesting parent** (`guard.ts:117-128`); `ice` → participant + consent (`:352-366`) | uuid/enum/boolean (`:111-112, 152, 198-199, 270, 311`); server derives `ended_reason`, ignores client `reason` (`guard.ts:130-155`) | `session_in_progress` 409, `session_not_open` 409, `session_expired` 410, `session_not_found` 404, `parent_only` 403, `consent_required` 403, `invalid_kind` 400 (`guard.ts:28-59`) | none on `request` (bounded by one-open-session + 10 min pending expiry); none on `ice` (TURN credential minting is unthrottled) | `remote_sessions` (read/update), `devices` (read), `audit_logs`; RPC `request_remote_session` |
| `device-command` | `create`, `poll`, `ack` (`:110-364`) | `create`: user JWT (parent); `poll`/`ack`: device credential (`auth.ts:281-337`) | `create` → `requireActiveDeviceForParent` (`:113-114`); `poll` uses the credential's device id (`:226-229`); `ack` loads the command **with** `device_id` filter (`:89-97, 262`) so a foreign command id yields 404 | command type enum, strict payload schema (`policy.ts`), idempotency key 1-128, ttl 60-900, ack result ≤32 KiB (`:116-123, 246-260`) | `device_not_found` 404, `device_not_active` 403, `command_not_found` 404, `command_expired` 410, `validation_error`, `unknown_action` | none on `create` (idempotency key is the only bound) | `device_commands`, `device_policies`, `devices`; RPCs `apply_policy_version`, `poll_device_commands` |
| `device-policy` | `update` (`:38-98`) | user JWT + verified email (`:50`) | parent role + `requireActiveDeviceForParent` (`:51-54`) | full policy schema (`policy.ts`), idempotency key (`:55-58`) | `device_not_found` 404, `device_not_active` 403, `validation_error` 400, `internal_error` | none | RPC `apply_policy_version`; `audit_logs` |
| `device-register` | `register` (`:104-249`) | user JWT + verified email + child role (`:118-119`) | `assertChildMembership` on the supplied `family_id`; installation reuse blocked for another account (`:141, 166-173`); revoked-device re-enrolment blocked until a *later* approval exists (`:53-102`, `enrollment.ts:3-13`) | installation id 8-128, hex64 secret hash, display name, platform/versions (`:121-139`) | `device_exists` 409, `device_already_registered` 409, `device_revoked` 403, `unknown_action`, `internal_error` | none | `devices`, `pairing_requests` (approval timestamp), `audit_logs` |
| `family-admin` | `revoke_device`, `recover_device`, `ack_alert`, `purge_data`, `update_retention` (`:55-262`) | user JWT + verified email, parent role on all five (`:56, 82, 114, 158, 230`) | `revoke_device`/`recover_device` → parent membership enforced **inside** the RPC (`functions.sql:452-460`, `00400:36-44`); `ack_alert` → parent of the alert's family (`:128-129`); `purge_data` → **any family parent** (`:167`); `update_retention` → **owner only** (`:235`, `auth.ts:224-250`) | uuid, integer ranges (1-3650; 1-365/1-730) (`:161-166, 233-234`) | `device_not_found` 404, `forbidden` 403, `alert_not_found` 404, `owner_required` 403, `unknown_action` | none on `purge_data` (destructive, repeatable) | RPCs `revoke_device`, `request_device_recovery`; `safety_alerts`, `families`, `location_events` (**delete**), `usage_daily` (**delete**), `audit_logs` |
| `auth-bootstrap` | `set_role`, `create_family` (`:37-131`) | user JWT + verified email on both (`:38, 92`) | `set_role` refuses to change an already-set different role (`:44-50`); `create_family` requires parent role and one active family per owner (`:93, 96-109`) | role enum, display name 1-60, family name 1-80 | `role_already_set` 409, `family_exists` 409, `unknown_action` | none | `profiles` (role/name), `families`, `child_contact_ids`, `audit_logs`; RPC `create_family_with_owner` |
| `cron` | `expire_sessions`, `detect_offline` (`:39-63`) | `x-cron-secret` vs `CRON_SECRET` (≥16 chars), constant-time compare (`:19-33`) | none beyond the shared secret; no user/device identity | action only | `cron_not_configured` 503, `unauthorized` 401, `unknown_action` | none | RPCs `expire_stale_sessions`, `detect_offline_devices` |

Cross-cutting Edge behaviour:

- Uniform envelope `{ok,data}` / `{ok,error:{code,message,details?}}`
  (`envelope.ts:36-50`); unexpected errors become `internal_error` 500 with a
  name-only log (`:56-63`); DB errors are collapsed to `internal_error`
  (`:103-111`) — an RLS denial (SQLSTATE 42501) surfaces as **500, not 403**.
- Body cap 512 KiB, JSON-object requirement, `action` length 1-64
  (`envelope.ts:65-100`).
- CORS: `Access-Control-Allow-Origin: *` on **every** function, request headers
  allow-list includes `x-device-id`, `x-device-secret`, `x-cron-secret`
  (`cors.ts:2-8`). No origin allow-list; no cookies/credentials involved.
- Service-role client is a module-level singleton (`auth.ts:46-65`); every table
  access runs with service role, so **RLS is never the enforcement layer inside
  Edge Functions** — each function re-implements its own checks.

**"Client-supplied id without an ownership check" sweep:** none found at the
Edge layer. Every id that arrives in a body is either re-derived from the device
credential (`device-telemetry`, `device-command.poll/ack`,
`remote-session.session_state`) or validated against the caller's family/role
before use (`device-policy`, `device-command.create`, `remote-session.request`,
`family-admin.*`, `pairing.cancel/unlink/respond`). The residual risk sits one
layer lower: the service-only RPCs themselves trust their parameters —
`create_pairing_invite` never verifies that `p_parent_user_id` is a parent of
`p_family_id` or that `p_child_user_id` is a child (`00600:25-90`, only null/shape
checks at `:41-49`); `create_pairing_request` likewise (`00600:96-156`);
`apply_policy_version` accepts `p_actor` without a membership check
(`functions.sql:86-114`); `request_remote_session` accepts `p_parent_user_id`
without a membership check (`00200:106-124`). Compare `revoke_device`
(`functions.sql:452-460`), `unlink_child` (`:340-353`),
`request_device_recovery` (`00400:36-44`), which do re-check. Inconsistent
defence-in-depth: a service-key leak or a future Edge bug is immediately a
cross-family write primitive.

### 2.8 Cross-check — `lib/data` vs what the backend exposes

RPC layer: **no Dart code calls any SQL RPC** (repo-wide grep for `.rpc(` in
`lib/` returns nothing; the only "rpc" hit is a comment at
`lib/features/remote_assistance/remote_session_controller.dart:2307`). That
matches the design: every RPC is revoked from `authenticated` and granted to
`service_role` only.

| Backend RPC | Called by | Status |
|---|---|---|
| `create_family_with_owner`, `apply_policy_version`, `respond_pairing_request`, `unlink_child`, `revoke_device`, `request_device_recovery`, `create_pairing_invite`, `create_pairing_request`, `request_remote_session`, `poll_device_commands`, `replace_device_apps` | Edge Functions (see table above) | used |
| `expire_stale_sessions`, `detect_offline_devices` | `cron` only, which has no caller and needs an unset secret | **exists, unreachable** |
| `expire_stale_commands` (public + private) | none | **dead code** |

| Edge function / action | Called from client | Status |
|---|---|---|
| `pairing.{get_contact_id, invite, create, redeem, pending_child, list_family, respond, cancel, unlink}` | `supabase_pairing_repository.dart:27, 61-64, 74, 107-110, 133, 143, 158-161, 176, 194-200` | all present |
| `device-register.register` | `supabase_device_repository.dart:82-83` | present |
| `device-telemetry.{heartbeat, usage_upload, location_upload, apps_upload}` | `supabase_device_repository.dart:161, 190`; `supabase_usage_repository.dart:74-75`; `supabase_location_repository.dart:78-79`; `GuardianService.kt:377, 415, 449, 479` | present |
| `device-policy.update` | `supabase_policy_repository.dart:41-42` | present |
| `device-command.{create, ack}` | `supabase_policy_repository.dart:90-91, 126-127` | present |
| `device-command.poll` | `GuardianService.kt:228-229` | present |
| `family-admin.{revoke_device, recover_device, ack_alert, purge_data, update_retention}` | `supabase_device_repository.dart:107-118`; `supabase_alert_repository.dart:48-49`; `supabase_audit_repository.dart:48-49, 70-71`; `supabase_family_repository.dart:176-177` | all present |
| `remote-session.{request, pending_child, respond, start, end, ice}` | `supabase_remote_session_repository.dart:35-37, 51-53, 110-112, 126-128, 142-145, 157-159` | present |
| `remote-session.session_state` | `AudioAssistanceService.kt:716-718` | present |
| `auth-bootstrap.{set_role, create_family}` | `supabase_auth_repository.dart:154-155`; `supabase_family_repository.dart:35-36` | present |
| `cron.*` | — | **exists but unused** |

| Direct PostgREST access from Dart | Table | Backed by RLS/grant? |
|---|---|---|
| `devices` (explicit safe column list) | `supabase_device_repository.dart:12-17, 33, 45, 63` | yes (`rls.sql:259-266`) |
| `device_apps`, `device_policies`, `device_commands`, `remote_sessions`, `usage_daily`, `location_events`, `safety_alerts`, `audit_logs`, `family_members`, `families`, `profiles` | `supabase_device_repository.dart:127`, `supabase_policy_repository.dart:24, 70`, `supabase_remote_session_repository.dart:72, 91`, `supabase_usage_repository.dart:28, 42`, `supabase_location_repository.dart:29, 52`, `supabase_alert_repository.dart:31`, `supabase_audit_repository.dart:27`, `supabase_family_repository.dart:58, 96, 118, 135`, `supabase_auth_repository.dart:129` | yes (all have SELECT policies + grants) |
| `webrtc_signals` insert/select | `supabase_remote_session_repository.dart:184-189, 310-313` | yes (`rls.sql:284`, `00300`) |
| `safe_zones` select/insert/update/**delete** | `supabase_location_repository.dart:99, 121, 127, 143` | yes — delete relies on `safe_zones_delete_parent` (`rls.sql:162-166`) |

**Mismatches found:** `webrtc_signals.payload` / `session_nonce` are written but
never used for authorization; `device_commands` is in the realtime publication
but no client subscribes; `expire_stale_commands` and the whole `cron` function
have no caller; `pairing`'s legacy `create` (code minting) is still exposed and
rate-limited (`pairing/index.ts:455-544`) although `docs/api-contract.md:332-333`
says the shipped child UI no longer offers it (the repository does expose
`createLinkingCode`, `supabase_pairing_repository.dart:71-88`, so the action is
reachable from code even if no current screen calls it — UI usage is another
agent's finding).

### 2.9 Local changes that appear undeployed relative to the F1 pre-fix build

F1 identifies the hosted `remote-session` bundle as the pre-fix build
(`docs/runtime-failure-analysis.md:47`). `git diff --stat 8eee1b1 HEAD -- supabase`
(read-only) shows the only backend deltas since that commit are:

- `supabase/functions/remote-session/index.ts` — `expirePending()` now only
  touches `status='requested'` (`index.ts:84-95`), accept sets `expires_at: null`
  (`:225-232`), no clock check on `start` (`:284`), parent-only `end`
  (`:316`), `session_state` device action (`:150-168`), and `request` routed
  through the RPC (`:118-131`).
- `supabase/functions/remote-session/guard.ts` (new, 155 lines) and
  `guard_test.ts` (new).
- `supabase/migrations/20261028000100_remote_session_concurrency.sql`,
  `20261028000200_parent_controlled_session_lifetime.sql`,
  `20261028000300_signaling_open_session.sql` (all new).
- SQL test files `60/61/62_*.sql`, `run_remote_session_race.sh`, and
  `tests/10_schema.sql`, `tests/40_functions.sql`, `tests/README.md` updates.

Documented cross-checks (documents, not my observation): the two migrations
`20261028000200` and `20261028000300` were applied through the hosted SQL Editor
on 2026-10-29 (`docs/stage7_hosted_migration_apply_2026-10-29.md:37-49`), while
**no Edge Function was deployed** (`:94-99`), the duplicate-session guard is
therefore inactive in production (`docs/pairing-recovery-fix-report.md:191`), and
F1 is still open (`docs/runtime-failure-analysis.md:49`). Note also that
`20261028000100` is **not** in that applied list, while `00200` re-defines its
RPC; the hosted chain is therefore numerically incomplete even though the final
state matches (`stage7…:20` pre-state "`request_remote_session` absent", `:62`
post-state "present").

I am **not** asserting deployment state anywhere; that determination belongs to
the dashboard agent. What the local tree proves is only which files changed.

Additional deployment-hygiene facts visible locally:

- `20261028000200` is **not idempotent** (`add constraint` unguarded,
  `00200:40-42`; acknowledged at `stage7…:89-91`).
- `20261028000100` contains a superseded body whose `request_remote_session`
  expires `accepted`/`active` rows (`00100:65-71`). Any replay that applies
  `00100` *after* `00200` would silently regress the parent-controlled lifetime.
- `20260101000200_rls.sql` uses bare `create policy` with no `drop if exists`
  (`rls.sql:27-240`), so a replay fails; hosted migration history is empty
  (`stage7…:26, 92`), so the file contents, not a migration ledger, are the only
  record of schema state.
- `config.toml` targets PG major 15 (`:17`) while hosted is 17.11
  (`docs/backend.md:15`); the SQL suites run on PG 15/16 (`supabase/tests/README.md:3-12`).

### 2.10 Area status (exact vocabulary)

| Area | Status | Basis |
|---|---|---|
| Schema + constraints (19 tables) | IMPLEMENTED — PARTIALLY VERIFIED | code + `supabase/tests/10_schema.sql` exists (documented pass `tests/README.md:4-12`); I did not run it; hosted PG 17 not exercised locally |
| RLS + grants | IMPLEMENTED — PARTIALLY VERIFIED | 21+1 policies, `tests/30_rls.sql`, `tests/50_realtime_policy.sql`; hosted realtime probe recorded at `docs/backend.md:20` |
| `pairing` (incl. Child ID / atomic invite) | IMPLEMENTED — PARTIALLY VERIFIED | full path + deployed-hash + live health documented (`docs/backend.md:63, 81-85`) |
| `auth-bootstrap` | IMPLEMENTED — PARTIALLY VERIFIED | deployed hash documented (`docs/backend.md:64`), live role issuance documented (`:81-85`) |
| `device-telemetry` | IMPLEMENTED — PARTIALLY VERIFIED | runtime invocations observed (heartbeat/poll/usage upload, incl. one rejected `usage_upload`, `docs/runtime-failure-analysis.md:65-67`) |
| `device-command` | IMPLEMENTED — PARTIALLY VERIFIED | runtime poll activity documented (`docs/runtime-failure-analysis.md:65`) |
| `remote-session` (local code) | IMPLEMENTED — PARTIALLY VERIFIED | `guard_test.ts` + SQL suites 60-62; runtime blocked by the undeployed build |
| `remote-session` (as deployed, per F1) | BROKEN | `docs/runtime-failure-analysis.md:40-49` |
| `device-register`, `device-policy`, `family-admin` | CODE EXISTS — NOT TESTED | no function-level tests, no runtime citation read for these paths |
| `cron` scheduled maintenance | BACKEND ONLY | function exists; no caller, no secret, no pg_cron (`backend.md:21`, `stage7…:24`) |
| `expire_stale_commands` RPC | MISSING (unused) | dead code, no caller |
| Storage buckets/policies | MISSING | none defined; no client usage |
| Screen-recording upload backend | MISSING | plan only (`docs/screen-recording-plan.md`), no bucket/table |
| Offline-device alerting | BACKEND ONLY | producer exists (`functions.sql:531-573`), scheduler unreachable |
| Hosted deployment state | BLOCKED — ACCESS REQUIRED | dashboard agent's scope |

### 2.11 Additional defects / risks (backend-local)

1. **`family-admin.purge_data` is authorized for any family parent**
   (`family-admin/index.ts:158-167`) and deletes `location_events` and
   `usage_daily` for the whole family (`:187-199`), while `update_retention` is
   owner-only (`:229-235`). A co-parent can therefore destroy history but cannot
   change retention. The API contract also says "parent" (`api-contract.md:500`),
   so the code matches its (arguably wrong) contract.
2. **Client DELETE policy on `safe_zones`** (`rls.sql:162-166`) contradicts the
   file's stated rule (`rls.sql:2`) and cascades `safe_zone_states`
   (`core.sql:286-292`), silently resetting the geofence baseline; any family
   parent can do it, and it is not audited (Dart deletes directly,
   `supabase_location_repository.dart:143`).
3. **Idempotency keys are not bound to the payload.** Reusing an
   `idempotency_key` with a different `type`/`payload` silently returns the older
   command (`device-command/index.ts:173-182`) or the older policy
   (`functions.sql:128-145`); if the referenced policy row is missing the RPC
   falls through and then fails on the unique key with a 500.
4. **`apply_policy_version` "idempotent" path can return a stale policy** and
   skip the audit event (`device-command/index.ts:145-167`, `device-policy/index.ts:79-92`),
   so a genuinely new policy pushed under a reused key is invisible in the audit
   trail.
5. **No ingestion quota on device-authenticated writes.** A stolen device
   credential can insert unbounded `location_events` (backdated up to 7 days,
   `device-telemetry/index.ts:31-32, 253-259`) and 500-row `usage_daily`
   upserts per call (`:159, 232-235`). Financially relevant on metered hosting.
6. **`pairing_attempts` grows without bound** (no retention job; only the two
   indexes `core.sql:422-425`), and falls back to unsalted SHA-256 when
   `PAIRING_HASH_PEPPER` is unset (`validation.ts:314-320`), leaving the 30^8
   Child-ID space brute-forceable from a dump (documented as BUG-034 at
   `docs/backend.md:279`).
7. **`usage_upload` overwrites rather than accumulates** (`upsert` on
   `(device_id, day, package_name)`, `device-telemetry/index.ts:232-235`), so an
   older/smaller sample replaces a newer one; no monotonic guard on `uploaded_at`.
8. **`heartbeat` returns the maximum policy version, not the acknowledged one**
   (`device-telemetry/index.ts:42-55, 150-154`) while `devices.policy_version`
   only advances on ack (`device-command/index.ts:337-350`); a client that trusts
   `pending_policy_version` will re-apply the same policy repeatedly.
9. **`webrtc_signals` has no per-session row cap or server-side kind/state
   validation beyond `kind` enum and 16 KiB payload** (`core.sql:361-364`); any
   participant can grow the table while the session is `accepted`/`active`.
10. **`errorResponse`/`ensureNoError` flatten authorization failures to 500**
    (`envelope.ts:102-111`); a legitimate 403 from PostgREST becomes
    `internal_error`, which hides policy regressions during monitoring.
11. **Realtime topic parser is format-fragile** (`rls.sql:310-315`): a topic
    whose segment 2 is not a UUID is denied; the client's `:<micros>` suffix is
    tolerated only because it is segment 3. A future naming change silently
    breaks all private channels (no test covers arbitrary topic shapes —
    `tests/50_realtime_policy.sql` covers the documented ones).
12. **CORS wildcard** on all endpoints (`cors.ts:3`) including device and cron
    routes; harmless for native clients but there is no browser-origin control
    if a web console is added later.
13. **Docs/contract drift inside the backend docs**: `api-contract.md:509-510`
    still specifies accept ⇒ `expires_at = now + 30 min` and `start` "not
    expired", both contradicted by `00200`/`remote-session/index.ts:284-306`;
    `docs/backend.md:44` claims `20260101000500` adds a nullable
    `pairing_requests.contact_id`, which the file does not contain (`00500:18-53`
    adds only `child_contact_ids` + `device_pairing_tokens.purpose`). A reviewer
    trusting those documents would mis-model the schema.

---

## 3. Evidence gaps / BLOCKED items

- **No execution of anything.** SQL suites, Deno tests and the app were not run
  (brief rule 1/4 and read-only scope). Every "tested" statement above is either
  a cited test file or a cited documented run.
- **BLOCKED — ACCESS REQUIRED (hosted state):** whether the deployed functions,
  migrations, `pg_cron`, `CRON_SECRET`, buckets and realtime policies match this
  tree. Only the dashboard agent can determine it; §2.9 lists local deltas
  without asserting deployment.
- **Realtime authorization semantics unverified (assumption gap):**
  `rls.sql:295-332` assumes `realtime.topic()` equals the client channel name
  verbatim. `tests/50_realtime_policy.sql` exercises the parser, not a live
  Realtime server. Hosted probe evidence exists only as documentation
  (`docs/backend.md:20`).
- **`_shared/policy.ts` was not read line-by-line past line 120.** The command
  type list (`:36-44`) and the strict key allow-lists (`:47-63`) were verified;
  the numeric range checks for screen-time/bedtime windows were not individually
  confirmed. Labelled an assumption: policy payloads are strictly validated.
- **`supabase/functions/*/_test.ts` files were listed but not read** except
  `guard_test.ts` existence; their assertions are therefore not summarised.
- **Local PG version skew** (config major 15 vs hosted 17.11) means local SQL
  results cannot be assumed to hold identically on hosted.
- **`device_apps`/`usage_daily` RLS coverage for the child** assumes
  `auth.uid()` equals `devices.child_user_id`; the case of a re-linked child
  keeping an old device row (status `revoked`) was reasoned about, not tested.

---

## 4. One-paragraph summary a reviewer can trust

The local backend is a coherent, service-role-mediated design: 19 public tables
all with RLS enabled, 21 table policies plus one Realtime topic policy, `anon`
with no privileges, no client write path except `safe_zones` and
`webrtc_signals`, and 38 SQL functions (24 `private` + 14 `public` wrappers) that
are uniformly `SECURITY DEFINER`, `search_path`-pinned and granted only to
`service_role` (three boolean RLS helpers are additionally granted to
`authenticated`). Nine Edge Functions implement the client API with a consistent
JWT-or-device-credential model, verified-email gating, strict input validation,
a uniform error envelope and pairing-specific rate limits; every client-supplied
id is re-checked against the caller's family/role/device, so the usual
"trust-the-body-id" class of bug is absent at that layer — the equivalent
weakness exists one level down, in four service-only RPCs that accept
`p_parent_user_id`/`p_actor` without a membership re-check. The most consequential
local defects are operational rather than logical: scheduled maintenance is
completely inert (no `pg_cron` locally, `CRON_SECRET` unset and no caller for the
`cron` function, so `offline` alerts can never be produced), any family parent can
irreversibly purge telemetry while only the owner can change retention, the
client can delete geofences directly, and the migration chain contains a
superseded `request_remote_session` body plus a non-idempotent constraint, so
replay order matters. Relative to the pre-fix build named in F1, the only backend
files that changed are `remote-session/index.ts` + new `guard.ts` and the three
`20261028*` migrations; the two that fix signalling and lifetime are documented
as already applied to the hosted database while the Edge Function was not
redeployed — a deployment question this subagent deliberately does not answer.

counts: fully_verified=0 partially_verified=7 partial=0 ui_only=0 backend_only=2
code_untested=3 broken=1 missing=3 blocked=1 not_applicable=0
