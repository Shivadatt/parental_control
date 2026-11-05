# Supabase Hosted-State Verification — 2026-11-05

**Purpose.** Independently establish the *current* state of the hosted Supabase project behind this repository, and classify each claim in the Stage 7 hosted-migration report (`docs/stage7_hosted_migration_apply_2026-10-29.md`) as currently verified, historical only, unverified, conflicting, or inaccessible.

**Method.** Read-only inspection through the authenticated Qoder browser session against the Supabase Dashboard for one project only: Database → Tables, Database → Policies, the SQL Editor (SELECT-only catalog queries), Authentication → Users, Authentication → Sign In / Providers, Project Overview, plus the dashboard's own read-only metadata endpoints for Edge Functions, Storage buckets and project secrets (names only). No `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `TRUNCATE`, `GRANT`, `REVOKE`, migration, deploy, scheduler, cleanup or session-state operation was issued. No Supabase CLI was used.

**Inspection window.** 2026-11-05, approximately 06:50–07:48 UTC (final catalogue read `2026-11-05T07:47:58Z`).

**Verdict.** The two Stage 7 migrations are **VERIFIED CURRENTLY** in the live catalogue. Everything else Stage 7 said it did *not* do is also true today. Two Stage 7 statements are now **superseded by current state**: the database is no longer at 39 sessions, and the "orphaned" session is no longer open. One hosted finding is new and material: a policy that suspends **zero** apps is stored as `enforced`, and **no stored command acknowledgement in production carries the enforcement counters** the current mapping code requires.

---

## 1. Project identity (verified before any inspection)

| Attribute | Value | Evidence type | Status |
|---|---|---|---|
| Project name | `parent-control-prod` | Dashboard header + `GET /v1/projects/{ref}` | VERIFIED |
| Project reference | `hhqgreaoqulmfwfwarhc` | URL bar + API response | VERIFIED |
| Project URL | `https://hhqgreaoqulmfwfwarhc.supabase.co` | API response | VERIFIED |
| Region | `ap-northeast-2` | API response | VERIFIED |
| Created | `2026-10-26T06:18:41.608445Z` | API response | VERIFIED |
| Status | `ACTIVE_HEALTHY`, compute `nano` | API response + Overview page | VERIFIED |
| Organisation | the signed-in dashboard account's single org | Dashboard header | VERIFIED |

The dashboard session also holds other project references in browser storage. **None of them were opened, queried or referenced.** Every query in this report addresses `hhqgreaoqulmfwfwarhc` only.

## 2. Areas inspected

Database → Tables (19), Database → Policies (full page), SQL Editor catalogue queries (`information_schema`, `pg_attribute`, `pg_constraint`, `pg_trigger`, `pg_proc`, `pg_policy`, `pg_indexes`, `pg_extension`, `pg_publication*`, `auth.users` counts, `public.*` row aggregates), Edge Functions list, project secrets list (names only), Storage buckets, Authentication → Users, Authentication → Sign In / Providers, Project Overview (migration history + backup tile).

Not inspected: Logs Explorer, Advisor Center, network restrictions, PITR/restore internals, and Data API permission screens beyond the annotations the Policies page itself displays.

## 3. Schema snapshot

19 tables exist in `public`, every one with **RLS enabled** (`relrowsecurity = true` on all 19; catalogue read 2026-11-05):

`audit_logs`, `child_contact_ids`, `device_apps`, `device_commands`, `device_pairing_tokens`, `device_policies`, `devices`, `families`, `family_members`, `location_events`, `pairing_attempts`, `pairing_requests`, `profiles`, `remote_sessions`, `safe_zone_states`, `safe_zones`, `safety_alerts`, `usage_daily`, `webrtc_signals`.

Approximate row counts from the Tables page (estimate, not exact): `audit_logs` 283, `device_apps` 2, `device_commands` 17, `device_policies` 15, `devices` 14, `families` 3, `family_members` 7, `location_events` 1773, `pairing_requests` 25, `profiles` 8, `remote_sessions` 45, `safe_zones` 0, `safe_zone_states` 0, `safety_alerts` 4, `usage_daily` 110, `webrtc_signals` 1380, `child_contact_ids` 4, `device_pairing_tokens` 27, `pairing_attempts` 68.

**There is no `push_tokens` table** (or any similarly named table) in `public`. Status: VERIFIED CURRENTLY. This is the hosted gap that DEC-14 must close before push delivery can exist.

## 4. `remote_sessions` — the Stage 7 object, read live

Columns (catalogue, 2026-11-05): `id NN, family_id NN, device_id NN, parent_user_id NN, child_user_id NN, kind NN, status NN, requested_at NN, accepted_at, started_at, ended_at, expires_at, ended_by, ended_reason, consent_recorded NN, session_nonce, created_at NN`.

Constraints:

| Constraint | Definition | Status |
|---|---|---|
| `remote_sessions_pkey` | `PRIMARY KEY (id)` | VERIFIED CURRENTLY |
| `remote_sessions_pending_expiry_check` | `CHECK ((status <> 'requested') OR (expires_at IS NOT NULL))` | **VERIFIED CURRENTLY** (Stage 7 migration 1 object) |
| `remote_sessions_status_check` | `status ∈ (requested, accepted, active, declined, ended, expired, failed)` | VERIFIED CURRENTLY |
| `remote_sessions_kind_check` | `kind ∈ (audio, video)` | VERIFIED CURRENTLY |
| `remote_sessions_ended_reason_check` | `ended_reason IS NULL OR char_length ≤ 200` | VERIFIED CURRENTLY |
| 4 foreign keys | to `profiles` / `devices` / `families` | VERIFIED CURRENTLY |

`expires_at` is **`timestamp with time zone`, NULLABLE** (no `attnotnull`). Stage 7's headline change is present in the live catalogue: VERIFIED CURRENTLY.

Indexes: `remote_sessions_pkey`, `remote_sessions_child_status_idx`, `remote_sessions_device_status_idx`, `remote_sessions_expires_idx`, `remote_sessions_family_idx`. **`remote_sessions_abandoned_idx` does not exist**, so `supabase/migrations/20261030000100_abandoned_session_sweep.sql` is not applied: NOT APPLIED (evidence-based, see §9).

Trigger: `remote_sessions_transition_guard`, `tgtype = 19` (BEFORE UPDATE, FOR EACH ROW), function `private.remote_session_transition_guard()`. Live body:

```
begin
  if OLD.status in ('declined', 'ended', 'expired', 'failed')
     and NEW.status in ('requested', 'accepted', 'active') then
    raise exception 'session_terminal' using errcode = 'P0001';
  end if;
  return NEW;
end;
```

VERIFIED CURRENTLY; matches `20261028000200_parent_controlled_session_lifetime.sql:55-74`.

## 5. Functions

| Object | Live signature | ACL | Status |
|---|---|---|---|
| `private.expire_stale_sessions()` | `returns integer` | `postgres=X/postgres, service_role=X/postgres` | VERIFIED CURRENTLY |
| `public.expire_stale_sessions()` | wrapper, present from baseline | same | VERIFIED CURRENTLY |
| `public.request_remote_session(p_device_id uuid, p_parent_user_id uuid, p_kind text)` | `returns remote_sessions` | `postgres=X/postgres, service_role=X/postgres` | **VERIFIED CURRENTLY** |
| `private.remote_session_transition_guard()` | trigger fn | default (owner/granted) | VERIFIED CURRENTLY |
| `private.is_parent_of_family(uuid, uuid)` | — | — | **ABSENT** → migration `20261030000200_phase1_authorization.sql` NOT APPLIED |
| `public.expire_abandoned_sessions(...)` | — | — | ABSENT → `20261030000100` NOT APPLIED |
| `public.run_retention_sweep()` | — | — | ABSENT → `20261030000300` NOT APPLIED |
| `public.delete_safe_zone_audited(...)` | — | — | ABSENT → `20261103000100` NOT APPLIED |

`private.expire_stale_sessions()` live body sweeps **pending requests only**:

```
  update public.remote_sessions
  set status = 'expired', ended_at = coalesce(ended_at, now()),
      ended_reason = coalesce(ended_reason, 'expired')
  where status = 'requested'
    and expires_at is not null
    and expires_at <= now();
```

This is the replacement described by Stage 7 (the baseline version at `20260101000100_functions.sql:511-529` swept `status in ('requested','accepted','active')`). VERIFIED CURRENTLY.

`public.request_remote_session` live body contains, in order: `invalid_kind` guard, `pg_advisory_xact_lock(hashtextextended(p_device_id::text, 0))`, `device_not_found`, `device_not_active`, an in-function sweep of stale `requested` rows, `session_in_progress` raised with `errcode 'P0001'` when any `requested/accepted/active` row exists for that device, and `insert ... values (..., now(), now() + interval '10 minutes', false)`. VERIFIED CURRENTLY; matches `20261028000200_...sql:106-188`.

Function ACLs prove **service-role-only execution** for `request_remote_session`: no `anon`, no `authenticated`, no `PUBLIC` entry appears in `proacl`. VERIFIED CURRENTLY.

`apply_policy_version`, `revoke_device`, `unlink_child` exist in both `private` and `public`; these come from the baseline `20260101000100_functions.sql:86/325/432/721/748/761`, **not** from the Phase 1 authorization migration — their Phase 1 companion `is_parent_of_family` is absent.

## 6. RLS policies (full live inventory)

21 policies across 15 tables, all `TO authenticated`. Tables with **no policies at all** (RLS on ⇒ deny-by-default for client roles, service role only): `child_contact_ids`, `device_pairing_tokens`, `pairing_attempts`, `safe_zone_states`.

`audit_logs_select_family_parent`, `device_apps_select_parent_or_child`, `device_commands_select_parent_or_child`, `device_policies_select_parent_or_child`, `devices_select_parent_or_child`, `families_select_members`, `families_update_owner`, `family_members_select_family`, `location_events_select_parent_or_child`, `pairing_requests_select_participants`, `profiles_select_self_or_family`, `profiles_update_self`, `remote_sessions_select_participants`, `safe_zones_select_family`, `safe_zones_insert_parent`, `safe_zones_update_parent`, `safe_zones_delete_parent`, `safety_alerts_select_parent_or_child`, `usage_daily_select_parent_or_child`, `webrtc_signals_select_participant`, `webrtc_signals_insert_participant`.

Live `webrtc_signals` policy definitions (read verbatim from `pg_policy`):

```
webrtc_signals_select_participant  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM remote_sessions s
     WHERE s.id = webrtc_signals.session_id
       AND s.status IN ('accepted','active')
       AND (s.parent_user_id = auth.uid() OR s.child_user_id = auth.uid())))

webrtc_signals_insert_participant  FOR INSERT TO authenticated
  WITH CHECK (from_user_id = auth.uid()
     AND EXISTS (SELECT 1 FROM remote_sessions s
     WHERE s.id = webrtc_signals.session_id
       AND s.status IN ('accepted','active')
       AND (s.parent_user_id = auth.uid() OR s.child_user_id = auth.uid())))
```

Neither contains an expiry predicate. A project-wide catalogue check for **any** policy in `public` whose `USING` or `WITH CHECK` expression mentions `expires_at` returned **0 rows**. Stage 7 migration 2 is therefore VERIFIED CURRENTLY, and its effect is global, not table-local. Access remains restricted to `accepted`/`active` sessions and to the two participants.

## 7. Realtime, Edge Functions, Storage, secrets, Auth

**Realtime.** Publications: `supabase_realtime`, `supabase_realtime_messages_publication`. `supabase_realtime` contains exactly `public.device_commands`, `public.remote_sessions`, `public.safety_alerts`, `public.webrtc_signals` — matching the four `Enabled` rows on the Tables page and `20260101000100_functions.sql:922-924`. The `realtime.messages_*` partition set spans 2026-10-26 … 2026-11-01. VERIFIED CURRENTLY.

**Edge Functions — 9 deployed.** Verify-JWT OFF: `auth-bootstrap` (v6, last deployed 2026-10-27T18:07:08Z), `pairing` (v6, 2026-10-27T18:03Z), `device-command` (v5, 2026-10-26T16:25Z), `device-telemetry` (v5, 2026-10-26T16:26Z), `cron` (v5, 2026-10-26T16:27Z). Verify-JWT ON: `device-register` (v5), `device-policy` (v5, 2026-10-26T16:23Z), `family-admin` (v6, 2026-10-26T20:41Z), `remote-session` (v5, 2026-10-26T16:24:39Z). **No function was deployed or redeployed on or after 2026-10-28**, i.e. after the Stage 7 migrations — the latest deployment timestamp in the project is 2026-10-27T18:07Z. Stage 7's "no Edge Function was deployed" is VERIFIED CURRENTLY. Consequence: the live `remote-session` bundle still writes `expires_at` on accept, which is why sessions created after the migration still carry expiry values while migrated rows do not.

**Storage.** Zero buckets exist. VERIFIED CURRENTLY.

**Project secrets (names only; no value was read, printed or copied).** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`, `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `CRON_SECRET`, `STUN_URL`, `PAIRING_HASH_PEPPER`. There is **no Firebase/FCM credential secret**. VERIFIED CURRENTLY.

**Authentication.** `auth.users` = 8 accounts, all with `email_confirmed_at` set; `public.profiles` = 8 rows, 4 `parent` and 4 `child` (display names deliberately not reproduced here). Sign In / Providers page: "Allow new users to sign up" **checked**, "Allow manual linking" **unchecked**, "Allow anonymous sign-ins" **unchecked**, "Confirm email" **checked**. Provider **Email enabled**; Phone disabled; every third-party OAuth/OIDC/SAML/Web3 provider disabled; no custom providers. VERIFIED CURRENTLY. This is consistent with the repository's claim that accounts are created through `auth-bootstrap`, but it also means self-service signup is currently open on production — an owner-relevant exposure this report records without changing.

**Extensions.** Installed: `plpgsql@1.0`, `pgcrypto@1.3`, `pg_stat_statements@1.11`, `supabase_vault@0.3.1`, `uuid-ossp@1.1`. **`pg_cron` is not installed** (it is installable — `pg_available_extensions` lists it — but is absent from `pg_extension`), and `cron.job` does not resolve (`to_regclass('cron.job')` is NULL). Therefore no scheduled job, cron entry, trigger-scheduler or webhook of any kind exists hosted. VERIFIED CURRENTLY, and consistent with DEC-05 Choice B.

**Migration history and backups.** The Overview tile reads **LAST MIGRATION: "No migrations"** and **LAST BACKUP: "No backups"**. Catalogue check: the `supabase_migrations` schema **does not exist** (`to_regnamespace('supabase_migrations')` is NULL; a direct query raised `42P01: relation "supabase_migrations.schema_migrations" does not exist`). This fully explains the empty history tile: migrations here were applied through the SQL Editor, which never writes that schema. Per the task rules, the empty history is **not** evidence that the Stage 7 changes are absent — §4–§6 show they are present.

## 8. Stage 7 claim-by-claim reconciliation

| # | Stage 7 claim (2026-10-29) | Live evidence (2026-11-05) | Classification |
|---|---|---|---|
| 1 | `remote_sessions.expires_at` made nullable | `information_schema` / `pg_attribute`: nullable, `timestamptz` | **VERIFIED CURRENTLY** |
| 2 | Pending-request expiry constraint added | `remote_sessions_pending_expiry_check` present with the expected expression | **VERIFIED CURRENTLY** |
| 3 | Existing accepted/active rows set to NULL expiry | `e84ba35e…` (accepted+active at the time) still has `expires_at IS NULL` | **VERIFIED CURRENTLY** (one surviving row proves the UPDATE ran; the historical row population is not re-derivable) |
| 4 | Transition-guard trigger/function added | `remote_sessions_transition_guard` BEFORE UPDATE FOR EACH ROW + `private.remote_session_transition_guard()` with `session_terminal`/`P0001` | **VERIFIED CURRENTLY** |
| 5 | `private.expire_stale_sessions()` replaced to sweep pending only | live body filters `status='requested' and expires_at is not null` | **VERIFIED CURRENTLY** |
| 6 | `public.request_remote_session(uuid,uuid,text)` created, service-role only | function exists, expected body, `proacl` grants execute to `service_role` only | **VERIFIED CURRENTLY** |
| 7 | `webrtc_signals` participant SELECT/INSERT policies recreated without the expiry predicate | live policy text + 0 policies project-wide referencing `expires_at` | **VERIFIED CURRENTLY** |
| 8 | Access still restricted to accepted/active sessions and the two participants | live policy `USING`/`WITH CHECK` clauses | **VERIFIED CURRENTLY** |
| 9 | 39 sessions total | **45** rows now: `ended=35, expired=10` | **CONFLICTING EVIDENCE** (superseded by later activity; latest `requested_at` = 2026-10-29T14:02:31Z) |
| 10 | One open session remained unchanged | **zero** rows in `requested/accepted/active`; `e84ba35e…` is now `status='expired'`, `ended_reason='expired'`, `ended_at=2026-10-29T11:21:35.671Z`, `expires_at IS NULL` | **CONFLICTING EVIDENCE** (historically true, currently false; see §9) |
| 11 | Authorized participant INSERT accepted (`42501` for non-participants) | cannot be re-established without a write probe | **VERIFIED HISTORICALLY ONLY** — not re-tested by design (write probe prohibited) |
| 12 | Terminal transition denied with `P0001` | guard trigger + its body are present, so the behaviour is supported by definition; not exercised | **PARTIALLY VERIFIED** (object verified, behaviour historical) |
| 13 | Behavioural probes rolled back, no probe data persisted | `webrtc_signals` holds 1380 rows from normal traffic; no probe marker can be proven absent | **NOT VERIFIED** (unfalsifiable read-only) |
| 14 | No Edge Function deployed | newest deployment timestamp 2026-10-27T18:07Z | **VERIFIED CURRENTLY** |
| 15 | Dashboard migration history still "No migrations" | tile reads "No migrations"; `supabase_migrations` schema absent | **VERIFIED CURRENTLY** |
| 16 | Migration 1 is not idempotent and must not be replayed | `20261028000200_...sql:40-42` performs an unguarded `add constraint`; replay would raise `duplicate_object` | **VERIFIED IN REPO** — and honoured: the file was **not** replayed here |
| 17 | `pg_cron` absent | not in `pg_extension`; `cron.job` unresolved | **VERIFIED CURRENTLY** |
| 18 | No scheduled sweep configured | no scheduler objects of any kind; `cron` Edge Function exists but nothing invokes it on a schedule | **VERIFIED CURRENTLY** (no hosted schedule exists) |

## 9. New and corrected hosted findings

1. **The orphaned session is no longer open.** `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9` on device `fd79ee34-c6fe-4abd-a3ae-39f9b16ed628` is now `expired` with `expires_at IS NULL` and `ended_at = 2026-10-29T11:21:35.671Z`. **This pass did not end, update or delete it** — the row was already in that state when first read. Because `request_remote_session` raises `session_in_progress` only while a `requested/accepted/active` row exists, the previously flagged blocker for that device is **currently not present**; six further sessions on that same device were accepted and ended later on 2026-10-29 (12:47Z–14:16Z).
2. **The expiring actor cannot be attributed.** The migrated `private.expire_stale_sessions()` cannot produce this result (it requires `expires_at IS NOT NULL`), and the baseline version required an expiry in the past. The transition to `expired` at 11:21:35Z therefore came from another path — most plausibly the deployed `remote-session` Edge Function bundle, which per Stage 7 still manages expiry itself. Classification: **NOT VERIFIED (mechanism unidentified)**; no Edge Function source was pulled or diffed as part of this read-only pass.
3. **`enforced` can already be observed on a policy that suspends nothing.** `public.device_policies` holds 15 rows: `enforced=3, pending=11, failed=1`. Exactly one `enforced` row (`d4a05b68-eff2-4dca-a794-86ced2565a48`, device `9dcadadc…`, version 1, `last_error` NULL, acknowledged 2026-10-26T17:57:53Z) has a policy whose `blocked_packages` and `app_rules` are both empty, `block_all_except_allowed` is not true, and whose only substantive control is `daily_screen_time_limit_minutes = 120` plus bedtime-window fields. That is the DEC-12 reporting defect observed in production data, not merely in code.
4. **No production acknowledgement carries the honest counter set.** `public.device_commands` holds 17 rows (`apply_policy pending=11, succeeded=3, failed=1`, `request_usage expired=2`); the count of rows whose `result` contains `desired_count` is **0**, and the count with `enforcement_supported = false` is **0**. The stored `result` payloads are legacy shapes, e.g. `{"success":true,"appliedAt":"…","suspended":["com.instagram.android"]}` and `{"errors":[],"success":true,"applied_at":"…","bedtime_active":true,"service_running":true,"suspended_packages":[],"unsupported_packages":[]}`. One failed ack does carry the honest text `"Device Owner provisioning is required to suspend apps on this device. No apps were suspended."` Under today's `decideEnforcement()`, every one of these results maps to `pending`/`enforcement_counts_missing`. All four terminal acks predate the current bundle (created 2026-10-26).
5. **Device posture is device-admin, not device-owner.** `public.devices` holds 14 rows, all `platform='android'`: `enforcement_mode='none'` 10 (revoked, `policy_version` 1), `'device_owner'` 2 (**both revoked**), `'device_admin'` 2 (**the only active devices**, `policy_version` 0). No active production device is a Device Owner.
6. **Four repository migrations are demonstrably not applied hosted** (`20261030000100`, `20261030000200`, `20261030000300`, `20261103000100`) — see §5. `20261028000100_remote_session_concurrency.sql` cannot be attributed independently: its only object, `request_remote_session`, was later replaced by the `20261028000200` version, and the two indexes sometimes credited to it originate in `20260101000000_core.sql:349-352`. Classification: **NOT VERIFIED (indistinguishable)**.
7. **Data volume growth since the last documented snapshot** (`remote_sessions` 39 → 45) is consistent with activity confined to 2026-10-29; `device_commands` has nothing newer than 2026-10-27T07:07Z. There is no hosted evidence of device activity in November 2026.

## 10. Limitations

- Row counts on the Tables page are dashboard **estimates** (`reltuples`-based); the exact figures in this report come from `count(*)` queries where stated.
- RLS behaviour (the `42501` and `P0001` probes) cannot be re-verified without a write, which this task prohibits; those items stay historical.
- Edge Function **source** was not read from the hosted project (only metadata: slug, verify-JWT flag, version, timestamp). Deployed code is therefore characterised from repository files plus deployment timestamps, which is inference, not inspection.
- The `visibility: hidden` state of the embedded browser prevented screenshots; every reading above is a DOM/catalogue read, not a pixel capture.
- No Auth *configuration* mutation was attempted; the providers page was read as-is. SMTP is documented as not configured in `docs/backend.md:22` and `docs/integrations-setup.md`; this pass did not re-verify SMTP because verifying it requires sending mail. **NOT VERIFIED here.**
- The dashboard's pre-existing 14 unnamed SQL tabs were left untouched. This pass added one unnamed, unsaved tab and saved nothing.

## 11. Explicit no-mutation statement

This inspection executed only `SELECT` statements and read-only dashboard/API reads. No migration was run; no DDL or DML was issued; no `GRANT`/`REVOKE` was issued; no Edge Function was deployed, redeployed or deleted; no RLS policy, schema object, Auth setting, Realtime configuration, Storage bucket, secret, project setting, scheduled job, session or backup was created, changed or removed. No secret, access token, service-role key, connection string, password or credential value was read into this report, printed, copied or stored. No other Supabase project was opened. Nothing in this document authorises a hosted operation; hosted migrations, Edge Function deployment and the session/retention sweeps remain gated behind DEC-02 and DEC-05 as recorded in `phase-9-owner-decision-register.md`.
