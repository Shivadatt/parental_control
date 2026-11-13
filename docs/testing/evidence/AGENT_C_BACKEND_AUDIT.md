# AGENT C — Backend / Edge-Function / RLS Audit (read-only)

Project ref `hhqgreaoqulmfwfwarhc` (`parent-control-prod`, ap-northeast-2). Scope:
`supabase/migrations`, `supabase/functions`, `supabase/config.toml`, the Dart
call-surface (`lib/**`), and repo deployment evidence. No device command was run.
No backend write was attempted.

## 0. Tooling reality (affects every "live" claim below)

The Supabase CLI **is installed** (`supabase 2.109.0`,
`C:/Users/ASUS/AppData/Roaming/npm/supabase`) but **is NOT authenticated** in this
environment: `~/.supabase/access-token` is absent and `SUPABASE_ACCESS_TOKEN` is
unset (presence/length-only probe; no value read). Therefore **I could not run
`supabase functions list` / `migration list` / `db inspect` against the live
project**, and I did not send any HTTPS request that could execute function code.

Consequence: **live deployed-vs-local state in this report is reconstructed from
the repository's own read-only dashboard inspection dated 2026-11-05**
(`docs/supabase-hosted-state-verification-2026-11-05.md`, "final catalogue read
`2026-11-05T07:47:58Z`", §5, §7) plus the Stage-7 apply record
(`docs/stage7_hosted_migration_apply_2026-10-29.md`). The current date is 2026-11-13.
Any hosted change after 2026-11-05 is **UNVERIFIED**. To make it a live verdict I
would need a valid `SUPABASE_ACCESS_TOKEN` (then `supabase functions list
--project-ref hhqgreaoqulmfwfwarhc`) or the dashboard SQL Editor for the read-only
catalogue probes quoted in `docs/implementation/deployment/manifest.md`.

---

## 1. LOCAL BACKEND INVENTORY

### 1.1 Migrations (14 files, `supabase/migrations/`, timestamp order)

| # | File | Creates / changes | Realtime/RLS/privilege notes |
|---|---|---|---|
| 1 | `20260101000000_core.sql` | 18 `public` tables; `private` schema; `updated_at`/`handle_new_user`/role-immutability/owner-immutability/audit-append-only triggers; `is_family_member`/`is_family_parent`/`shares_active_family` helpers (`:571-626`) | helpers `grant execute … to authenticated` (`:632-635`), revoked from anon/PUBLIC |
| 2 | `20260101000100_functions.sql` | Internal RPCs + `public` wrappers (record_audit, create_family_with_owner, apply_policy_version, respond_pairing_request, unlink_child, revoke_device, expire_stale_sessions, detect_offline_devices, expire_stale_commands, poll_device_commands, replace_device_apps) | realtime publication adds **device_commands, safety_alerts, remote_sessions, webrtc_signals** (`:909-944`); guarded pg_cron schedule (`:949-970`) |
| 3 | `20260101000200_rls.sql` | `enable row level security` on all 18 (`:5-22`); all select/insert/update/delete policies; grants; `realtime_topic_allowed(text)` (`:295-332`); `parentcontrol_private_topics` policy on `realtime.messages` (`:344-359`) | column-scoped SELECT on `devices` excludes `secret_hash`,`installation_id` (`:259-266`) |
| 4 | `20260101000300_service_role_grants.sql` | service_role full CRUD + sequences + default privileges | anon/authenticated unchanged |
| 5 | `20260101000400_device_recovery.sql` | `request_device_recovery` (private+public, service-only) | — |
| 6 | `20260101000500_child_contact_ids.sql` | `child_contact_ids` table (RLS, **0 policies**, service-only); `device_pairing_tokens.purpose` column + index | — |
| 7 | `20260101000600_atomic_pairing_invite.sql` | `create_pairing_invite` / `create_pairing_request` RPCs (service-only) | — |
| 8 | `20261028000100_remote_session_concurrency.sql` | `request_remote_session` (advisory lock) | superseded by #9 on hosted → indistinguishable |
| 9 | `20261028000200_parent_controlled_session_lifetime.sql` | `remote_sessions.expires_at` nullable; `remote_sessions_pending_expiry_check`; `remote_session_transition_guard` trigger; `expire_stale_sessions`→pending-only; `request_remote_session` 10-min expiry | **APPLIED on hosted** (verified §4,§5) |
| 10 | `20261028000300_signaling_open_session.sql` | re-create `webrtc_signals` select/insert policies **without** expiry predicate | **APPLIED on hosted** (verified §6) |
| 11 | `20261030000100_abandoned_session_sweep.sql` | `expire_abandoned_sessions(interval)` + partial `remote_sessions_abandoned_idx` | **NOT APPLIED** (index absent, §5/§9.6) |
| 12 | `20261030000200_phase1_authorization.sql` | `is_parent_of_family`; **drops `safe_zones_delete_parent` + revokes DELETE on `safe_zones`**; actor checks on request_remote_session/revoke_device/unlink_child/apply_policy_version; `webrtc_signals_session_sequence_uniq` | **NOT APPLIED** (`is_parent_of_family` ABSENT, §5) |
| 13 | `20261030000300_retention_sweep.sql` | `run_retention_sweep()` + `webrtc_signals_created_idx`/`audit_logs_created_idx` | **NOT APPLIED** (function ABSENT, §5) |
| 14 | `20261103000100_zone_delete_atomic_rpc.sql` | `delete_safe_zone_audited(uuid,uuid)` (service-only) | **NOT APPLIED**; header `:4` self-declares "UNAPPLIED TO HOSTED. LOCAL-TESTED ONLY." |

### 1.2 `supabase/config.toml`

- `[realtime] enabled=true`, `[storage] enabled=true`, `[api] max_rows=1000`
  (`config.toml:12`), `[edge_runtime] policy="oneshot"`.
- **No `[cron_jobs]` / scheduled-task section exists.** (grep for cron/schedule/job
  returns only the `[functions.cron] verify_jwt=false` block at `:92-95`.) Scheduled
  work is the *external-scheduler→`cron` Edge Function* design, per
  `20261030000300_retention_sweep.sql:1-6` ("There is no pg_cron and no hosted
  scheduler in this phase").
- Per-function `verify_jwt`: `true` for auth-bootstrap, pairing, device-register,
  device-policy, family-admin, remote-session, account; `false` for device-command,
  device-telemetry, cron (`:61-95`).

### 1.3 Edge Functions (10 slugs) — auth mode + tables touched (local source)

| Slug | Auth (local) | Actions | Tables / RPCs |
|---|---|---|---|
| `auth-bootstrap` | user JWT (`:62-63`) | role setup, family create | profiles, families, `create_family_with_owner` |
| `pairing` | user JWT (+device) | create/cancel/redeem/respond/invite | device_pairing_tokens, pairing_requests, pairing_attempts, `create_pairing_invite`/`respond_pairing_request` |
| `device-register` | user JWT | register | devices |
| `device-policy` | user JWT, parent, verified email (`index.ts:58-59`) | `update` only | `apply_policy_version` → device_policies+device_commands, audit |
| `device-command` | self-auth (`verify_jwt=false`); parent JWT for create, device secret for poll/ack (`handler.ts:177,291,309`) | create/poll/ack | device_commands, device_policies, devices, `poll_device_commands`/`apply_policy_version`, audit |
| `device-telemetry` | device secret (`requireDevice`) | heartbeat/usage_upload/location_upload/apps_upload | devices(last_seen…), usage_daily, location_events, device_apps(`replace_device_apps`), safe_zone_states, safety_alerts |
| `family-admin` | user JWT, parent | revoke_device/recover_device/ack_alert/**delete_zone**/purge_data/update_retention | `revoke_device`,`request_device_recovery`,**`delete_safe_zone_audited` (`index.ts:221`)**, families, safety_alerts, location/usage purge, audit |
| `remote-session` | mixed (JWT for parent/child, device secret for `session_state`) | request/session_state/pending_child/respond/start/end/ice | remote_sessions, webrtc_signals, `request_remote_session`,`expire_abandoned_sessions`(best-effort) |
| `account` | user JWT (`index.ts:566`) | export/delete_account/**retention_report** | cross-table reads via service role; `db.auth.admin.deleteUser` |
| `cron` | `x-cron-secret` vs `CRON_SECRET` (`cron/index.ts:37-51`) | expire_sessions/detect_offline/sweep_sessions/retention_sweep | RPCs, tolerant of missing functions (`isMissingFunction`→skip) |

---

## 2. LIVE vs LOCAL DRIFT (the key output)

### 2.1 Edge Function deployed-vs-local table

Evidence base: hosted Functions list (9 slugs) at
`docs/supabase-hosted-state-verification-2026-11-05.md:137`; the `account`
absence recorded as C-19 in `docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md:77`;
local slugs = 10 (`supabase/functions/*/index.ts`).

| Dart-referenced slug | Referenced from (lib) | Deployed on hosted? | Evidence |
|---|---|---|---|
| `auth-bootstrap` | supabase_family_repository.dart:35; supabase_auth_repository.dart:154 | **DEPLOYED** (v6, 2026-10-27T18:07Z) | hosted §7 `:137` |
| `pairing` | supabase_pairing_repository.dart:219,227 | **DEPLOYED** (v6, 2026-10-27T18:03Z) | hosted §7 `:137` |
| `device-register` | supabase_device_repository.dart:82 | **DEPLOYED** (v5) | hosted §7 `:137` |
| `device-policy` | supabase_policy_repository.dart:41 | **DEPLOYED** (v5, 2026-10-26T16:23Z) | hosted §7 `:137` |
| `device-command` | supabase_policy_repository.dart:90,126 | **DEPLOYED, STALE** (v5, 2026-10-26T16:25Z) | hosted §7; local fix undeployed (`docs/phase10-tb01-…:193`) |
| `device-telemetry` | supabase_location_repository.dart:78; supabase_usage_repository.dart:74; supabase_device_repository.dart:161,190 | **DEPLOYED** (v5, 2026-10-26T16:26Z) | hosted §7 `:137` |
| `family-admin` | supabase_alert/audit/family/device/location repos (update_retention etc.) | **DEPLOYED, STALE** (v6, 2026-10-26T20:41Z) | hosted §7; local RPC path undeployed |
| `remote-session` | supabase_remote_session_repository.dart:36,52,111,127,143,158 | **DEPLOYED, STALE** (v5, 2026-10-26T16:24:39Z) | hosted §7; `expires_at:null` consent undeployed |
| `account` (actions export/delete_account/retention_report) | account_privacy_repository.dart:183,236,266 | **NOT DEPLOYED** | deployed-9 omits it; C-19 `:77` "never observed deployed, never invoke-tested on hosted" |
| `cron` | not called from Dart (server-side only) | **DEPLOYED, NEVER SCHEDULED** (v5, 2026-10-26T16:27Z) | hosted §7 `:137`,§8 row 18 `:170` |

Verdict: **9 of 10 local slugs are deployed.** `account` is **NOT deployed**, which
explains the "Requested function was not found" the prior audit saw for the
retention report — that is a gateway 404 for the missing **`account` slug** (the
Dart call is `functions.invoke('account', body:{action:'retention_report'})`,
account_privacy_repository.dart:265-268), not an unknown action. **Content drift**:
none of the 9 deployed bundles post-date 2026-10-27T18:07Z (hosted §7 `:137`;
register `:322` per C-18 `:76`), so every local code change made in Phases 8-10
(enforcement counters, `expires_at:null` consent, atomic zone delete, quota ack)
is **local-only / UNDEPLOYED** on these slugs. **Classification caveat**: this is
metadata-only ("inference, not inspection", hosted §10 `:186`; C-23 `:81`) — the
deployed *source* was never diffed. `UNVERIFIED` beyond 2026-11-05.

### 2.2 Migration drift

There is **no `supabase_migrations` ledger on hosted** (schema absent; dashboard
shows "No migrations") because migrations were applied via the SQL Editor
(hosted §7 `:147`, C-22 `:80`). Classification by object probe:

- **Applied + verified current:** baseline `20260101000000`–`20260101000600`
  (19 tables incl. `child_contact_ids` exist, hosted §3 `:35-37`), Stage-7
  `20261028000200` (nullable `expires_at`, pending-expiry constraint, guard trigger,
  service-only `request_remote_session`) and `20261028000300` (webrtc policies),
  both VERIFIED CURRENTLY (§4-§6, §8 rows 1-8).
- **`20261028000100`: UNVERIFIED / indistinguishable** — its only object was later
  replaced by #9's version (hosted §9.6 `:179`; C-21 `:79`).
- **NOT APPLIED (proven by absent objects, §5 `:84-87`, §9.6 `:179`):**
  `20261030000100` (`expire_abandoned_sessions` + `remote_sessions_abandoned_idx`
  absent), `20261030000200` (`private.is_parent_of_family` absent),
  `20261030000300` (`run_retention_sweep` absent), `20261103000100`
  (`delete_safe_zone_audited` absent). Matches DEC-02 "4 migrations absent"
  (`docs/phase9-13-final-audit-and-implementation-launch-plan.md:36`).

---

## 3. RLS / TENANT-ISOLATION REVIEW

**CONFIRMED (from SQL):**
- RLS enabled on all 18 core tables + `child_contact_ids` = 19
  (`20260101000200_rls.sql:5-22`, `20260101000500_child_contact_ids.sql:33`); hosted
  confirms `relrowsecurity=true` on all 19 (§3 `:35`).
- **deny-by-default service-only tables** (RLS on, zero policies, zero client
  grants): `device_pairing_tokens`, `safe_zone_states`, `pairing_attempts`,
  `child_contact_ids` (`rls.sql:74,168,242,286-287`; hosted §6 `:110`).
- **anon leaks nothing**: `revoke all on all tables/sequences … from anon, authenticated`
  then only the listed grants to `authenticated`; anon receives no table privilege at all
  (`rls.sql:247-288`).
- **`secret_hash` / `installation_id` are service-only.** `authenticated` gets a
  column-scoped `devices` SELECT that omits both (`rls.sql:259-266`); device auth reads
  `secret_hash` only via the service-role client (`_shared/auth.ts:302-336`). Not
  readable by anon/authenticated. CONFIRMED.
- **Family isolation predicates are airtight** in the local design: every select policy
  routes through `is_family_member`/`is_family_parent`/`shares_active_family`, all of
  which require `status='active'` AND `families.deleted_at is null`
  (`core.sql:571-626`). Cross-family reads are not possible under these policies.
  CONFIRMED by reading SQL; **behaviour not live-probed** (write probes prohibited).

**SUSPECTED / live-state exposures:**
- **SUSPECTED (high confidence, live):** Because `20261030000200` is NOT applied,
  on hosted **`authenticated` still holds table-level DELETE on `safe_zones` and the
  `safe_zones_delete_parent` policy is still live** — hosted §6 `:112` lists it,
  grant is `rls.sql:282`. So a family parent can issue a **direct PostgREST DELETE**
  on `safe_zones` that **bypasses the atomic audited RPC** and leaves the deletion
  unaudited (the exact defect SQL-05 was written to close,
  `20261103000100` header `:22-44`). Not cross-tenant, but an **audit-integrity gap in
  production today**. To confirm: read `pg_policy` + `information_schema.role_table_grants`.
- **UNVERIFIED:** whether the local `family-admin delete_zone` (which calls
  `delete_safe_zone_audited`, `index.ts:221`) is what is deployed. The deployed
  `family-admin` v6 predates that RPC, so it must still use the old two-call path.
  If the current local bundle were deployed **before** `20261103000100`, `delete_zone`
  would **fail closed** (`docs/implementation/deployment/manifest.md:269-273`).

---

## 4. DATA-INTEGRITY OBSERVATIONS (two-device relevant)

- **device_commands pending→delivered→succeeded/failed/expired.** Created `pending`
  (`handler.ts:257`, TTL `min(900,max(60,ttl))` `:189`; apply_policy commands fixed
  900s in `apply_policy_version` `functions.sql:174`). **`delivered` is set only inside
  `poll_device_commands`** (RPC flips pending→delivered, `delivered_at=now`,
  `attempts+1`, `functions.sql:620-635`) — i.e. **only when that device polls**.
  `ack` maps `succeeded|failed|expired` (`ACK_STATUSES` `handler.ts:75`, update
  `:359-372`). **What makes an ack fail:** (a) command not found/other device → 404
  `command_not_found` (`:329-331`); (b) expired deadline with non-`expired` status →
  410 `command_expired`, row forced to `expired` (`:338-355`); (c) result >32 KB /
  non-object → 400 (`:314-322`); (d) concurrent-ack race → returns settled row, no-op
  (`:374-381`). Idempotent re-ack on terminal statuses returns the row (`:332-334`).
- **`policy_version` advance rule:** devices.policy_version advances **only** when the
  apply_policy ack maps to `enforced` or `unsupported` (`enforcement.ts:359,386`,
  `handler.ts:413-424` writes `policy_version = <policy row version>`). A heartbeat
  explicitly does NOT advance it (`device-telemetry/index.ts:84-85`).
- **STUCK STATE #1 (pending forever):** `poll_device_commands` expires a device's
  stale commands only when *that device polls* (`functions.sql:614-618`); `cron`
  `expire_stale_commands` is per-device and there is **no global command sweeper**. A
  command queued to an offline/never-polling device stays `pending`/`delivered`
  indefinitely in the table. Hosted §9.4 confirms 11 `apply_policy` rows still `pending`
  with legacy ack shapes.
- **STUCK STATE #2 (Standard-mode never advances):** a device that acks without the
  honest counters, or a limits-only policy on a non-Device-Owner device, yields
  `pending` (`enforcement.ts:311-321,341-351`) → policy_version never advances and
  `device_policies.enforcement_status` stays `pending`. This is by-design honesty but
  reads as "stuck" to the parent. Hosted §9.3-9.5: no active production device is a
  Device Owner; 0/17 hosted acks carry counters.
- **Presence / last-seen:** `devices.last_seen_at` is written **only** by
  `device-telemetry heartbeat` under device auth (`index.ts:79-80`); "online" is
  inferred client-side from recency (`:77`). Offline detection is
  `detect_offline_devices` (`last_seen_at < now-15min` → safety_alert, `functions.sql:531-572`)
  intended to run every 10 min — **but that only fires if `cron` is scheduled, and it is
  not** (see §5). So offline alerts are effectively never produced on hosted.
- **remote_sessions consent:** local `respond`/accept writes `acceptPatch`
  (`expires_at:null`, `consent_recorded:true`, `session_nonce`) — `guard.ts:162-178`,
  `remote-session/index.ts:235`. Only the requesting parent may end it (`guard.ts:117-128`);
  child consent withdrawal is device-local only. Server clock never closes a *live*
  (accepted/active) session — only the 24h **abandoned sweep** does
  (`20261030000100`, `_shared/remote_session_lifecycle.ts:3-7`).
- **STUCK STATE #3 (live, on hosted):** consented sessions with `expires_at IS NULL`
  are closed only by `expire_abandoned_sessions`, which is **NOT applied** (§5) and
  whose cron trigger is unscheduled. The deployed `remote-session` bundle predates the
  local `withAbandonedSweep` call, so an accepted/active session that is abandoned
  **stays open and permanently blocks `request_remote_session` for that device**
  (`session_in_progress`, `guard.ts:32-38`, `functions.sql` request raises it). This is
  the root of defect F1 / the 8m14s contradiction (`docs/phase9-11…:66` C-13).

---

## 5. REALTIME

- **Client subscribes to exactly 3 postgres_changes channels, all `private:true`:**
  `remote_sessions` (topics `remote-session:<id>` and `remote-session-family:<famId>`,
  supabase_remote_session_repository.dart:198,211,334), `webrtc_signals`
  (`webrtc-signals:<sessionId>`, `:230`), `safety_alerts` (`safety-alerts:<familyId>`,
  supabase_alert_repository.dart:70). (Whole-lib `.channel(` grep = 3 hits; no
  device_commands/device_policies channel.)
- **`realtime_topic_allowed(text)` gates them** (`rls.sql:295-332`): `safety-alerts`
  and `remote-session-family` require `is_family_member(uuid)`; `remote-session` and
  `webrtc-signals` require the caller to be that session's child **or** a family parent;
  anything else → `false`. Enforced via the `parentcontrol_private_topics` policy on
  `realtime.messages` (`rls.sql:344-359`), which is created only if `realtime.messages`
  exists. Row visibility is still table RLS. Hosted confirms `supabase_realtime`
  publication = {device_commands, remote_sessions, safety_alerts, webrtc_signals}
  (§7 `:135`); subscription/deny behavior was live-probed once (2026-10-26,
  C-24 `:82`) but **delivery is otherwise NOT TESTED**.
- **`device_commands` changes do NOT push.** Although `device_commands` is in the
  publication, no client subscribes to it and `realtime_topic_allowed` has no branch
  for it (returns false), so a private channel on it would be denied. The child
  obtains policy/command updates by **polling** `device-command poll`
  (`supabase_policy_repository.dart:90,126`; RPC `poll_device_commands`). Likewise
  `device_policies` is **not** in the publication and is **not** subscribed →
  **policy enforcement is poll-only, never realtime.**

---

## 6. Open items I could not establish (UNVERIFIED → needed access)

1. **Live function inventory/source diff & `account` deployment** — need
   `SUPABASE_ACCESS_TOKEN` (`supabase functions list`) or dashboard Edge-Functions
   read. Only the 2026-11-05 metadata snapshot backs §2.
2. **Post-2026-11-05 hosted state** (any DEC-02 apply/deploy on/after 2026-11-06) —
   need read-only catalogue probe (queries in `manifest.md` §5, §9.6).
3. **`safe_zones` DELETE grant exposure on hosted** — need `pg_policy` +
   `role_table_grants` read (§3 SUSPECTED).
4. **`verify_jwt` discrepancy**: `config.toml:61-82` marks `auth-bootstrap`/`pairing`
   ON, but hosted §7 `:137` records them deployed with **Verify-JWT OFF**
   (backend.md:19 sides with config). Which is live is UNVERIFIED; all functions
   self-authenticate in code, so it is defense-in-depth, not a gate bypass.
5. **RLS live behaviour** (42501/0-row isolation) and **realtime delivery** — need
   authorized write + two-device probes (prohibited here).
