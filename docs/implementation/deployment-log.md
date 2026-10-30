# Phase 1 — deployment log

Owner: verification workstream. Date: **2026-10-30**.
Base: commit **`2a0209f`** (Phase 0 baseline) + **working tree, uncommitted** (observed `HEAD`
`8ebb73c`).

## Status

**No hosted operation was executed in Phase 1.** No migration was applied, no Edge Function was
deployed, no secret was set, no auth setting was changed, and the Supabase CLI was not used or
installed (contract non-negotiable 2). Every row below is
`NOT APPLIED — owner approval required`. The SHA-256 values identify the exact local file the
owner would paste; recompute them immediately before applying.

Apply order matters: migrations 1 → 2 → 3, then `account`, `remote-session`, `family-admin`, and
`cron` last. `cron` tolerates a missing sweep function (returns `skipped: function_missing`), but
the reverse order hides real failures.

## 1. Operations required

| # | Operation | Artifact (local) | Status | Purpose |
|---|---|---|---|---|
| 1 | Apply migration 1 | `supabase/migrations/20261030000100_abandoned_session_sweep.sql` | **NOT APPLIED — owner approval required** | `public.expire_abandoned_sessions(interval)` + partial index: closes consented sessions abandoned > 24 h, writes `session_expired` audit rows, service-role only. |
| 2 | Apply migration 2 | `supabase/migrations/20261030000200_phase1_authorization.sql` | **NOT APPLIED — owner approval required** | `private.is_parent_of_family`; parent check on four service RPCs; revoke client `safe_zones` DELETE; revoke PUBLIC execute on two private helpers; conditional unique index on `webrtc_signals(session_id, sequence)`. |
| 3 | Apply migration 3 | `supabase/migrations/20261030000300_retention_sweep.sql` | **NOT APPLIED — owner approval required** | `public.run_retention_sweep()`: 7-day signals, 365-day audit, per-family location/usage windows; service-role only; writes one `retention_sweep` audit row. |
| 4 | Redeploy `remote-session` | `supabase/functions/remote-session/index.ts`, `guard.ts` | **NOT APPLIED — owner approval required** | Replace the stale hosted 30-minute build with parent-controlled lifetime, parent-only `end`, nullable `expires_at` for consented rows, best-effort sweep on `request`. |
| 5 | Redeploy `family-admin` | `supabase/functions/family-admin/index.ts`, `authorization.ts` | **NOT APPLIED — owner approval required** | New `delete_zone` action, owner-only `purge_data`, `not_family_parent` → 403 mapping. |
| 6 | Redeploy `cron` | `supabase/functions/cron/index.ts` | **NOT APPLIED — owner approval required** | New actions `sweep_sessions` and `retention_sweep`; existing actions unchanged. |
| 7 | Deploy new `account` function | `supabase/functions/account/index.ts`, `retention.ts`, `validation.ts` | **NOT APPLIED — owner approval required** | `export` (JSON attachment, capped, truncated flags), `delete_account` (`confirm:"DELETE"` + caller email, owner-blocked), `retention_report`. |
| 8 | Secrets and auth | none | **NOT APPLIED — owner approval required (no change proposed)** | Zero secret changes, zero auth-provider/redirect/email-template changes, no new buckets. |

File hashes at verification time:

```text
12f20c8193110c35bc3b0146f899ec90ac46bef3b59137ff9d97f4058f14297a  20261030000100_abandoned_session_sweep.sql
f7062a84cff31a283fae8c917d41bbd540e4a8b27d2c55102ec19881a835db58  20261030000200_phase1_authorization.sql
8de3cb388cfaf767d1945e47dbe771497e8d08d5139ba407d787622586d415ff  20261030000300_retention_sweep.sql
44e97714e6750f52ad5e1f35f382612bb3ddf038183fd5d4a625c2676ba72826  remote-session/index.ts
165f1f4b48734f16edcb18ce8b033ed818c726f0d4850a72b035d41f6c940e0c  remote-session/guard.ts
3919b952a6e1a04e7f6b6ffac9cceb808d667fbf2cb9f67138807c9bbe92f61e  family-admin/index.ts
3cdf029cafd34f2fc2417e6708891169894a454905b0d7d59c1a6cb8e7a48bbe  cron/index.ts
f487c146e5b7c944a9e15abf5495c4a430b225851a1efd398a6aa887a79c0532  account/index.ts
```

`docs/implementation/deployment/manifest.md` now records these same hashes and the real migration-3
filename (`20261030000300_retention_sweep.sql`); the earlier `3e6c56c8…` entry and the
`…_retention_and_sweeps.sql` name were stale and have been corrected. Re-hash on the applying machine
before use — hashes move with line-ending conversion.

---

## 2. Migration 1 — `20261030000100_abandoned_session_sweep.sql`

**Status: NOT APPLIED — owner approval required.**

Pre-check (read-only; hosted has no such function yet, and this previews the impact):

```sql
select p.oid::regprocedure::text, p.prosecdef, p.proconfig
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'expire_abandoned_sessions';
-- expected: 0 rows

select count(*) as abandoned_candidates
from public.remote_sessions
where status in ('accepted', 'active')
  and coalesce(accepted_at, requested_at) < now() - interval '24 hours';
-- expected: 0 on a healthy project; >0 means the first sweep will close that many rows
```

Apply: Dashboard → SQL Editor → paste the file exactly as-is → Run. Do not edit the interval.

Post-check:

```sql
select p.oid::regprocedure::text as function, pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer, p.proconfig as settings,
       has_function_privilege('anon', p.oid, 'execute') as anon_execute,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'expire_abandoned_sessions';
-- expected: expire_abandoned_sessions(interval) | integer | t
--           {"search_path=public, private, pg_temp"} | f | f | t

select indexname from pg_indexes
where schemaname = 'public' and indexname = 'remote_sessions_abandoned_idx';
-- expected: 1 row

select count(*) from public.remote_sessions
where status = 'expired' and ended_reason = 'abandoned' and ended_by is null;
-- record the value; it must not change until the cron action is called
```

Rollback: `drop function if exists public.expire_abandoned_sessions(interval);`
`drop index if exists public.remote_sessions_abandoned_idx;` Rows already closed remain `expired`
with reason `abandoned` (history is not rewritten).

Local evidence: applied in the full local chain, `63_abandoned_session_sweep.sql` passed
(`ALL ABANDONED SESSION SWEEP TESTS PASSED`); whole chain exit 0.

## 3. Migration 2 — `20261030000200_phase1_authorization.sql`

**Status: NOT APPLIED — owner approval required.**

Pre-check (run all three; do not apply if the duplicate check returns rows):

```sql
-- webrtc_signals duplicates decide whether the unique index can be created
select session_id, sequence, count(*) as copies
from public.webrtc_signals
group by session_id, sequence
having count(*) > 1;
-- expected: 0 rows; if rows exist the migration skips the index with a notice.
-- Plan a one-off, owner-approved dedupe; never delete rows by hand here.

select has_table_privilege('authenticated', 'public.safe_zones', 'delete') as authenticated_can_delete,
       (select count(*) from pg_policy
        where polrelid = 'public.safe_zones'::regclass
          and polname = 'safe_zones_delete_parent') as delete_policies;
-- expected BEFORE: authenticated_can_delete = true, delete_policies = 1

select p.oid::regprocedure::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private' and p.proname = 'is_parent_of_family';
-- expected: 0 rows
```

Apply: paste the file exactly as-is. It is re-runnable and never deletes rows.

Post-check:

```sql
select p.oid::regprocedure::text as function, pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private' and p.proname = 'is_parent_of_family';
-- expected: is_parent_of_family(uuid,uuid) | boolean | t | f | t

select has_table_privilege('authenticated', 'public.safe_zones', 'delete') as authenticated_can_delete,
       (select count(*) from pg_policy
        where polrelid = 'public.safe_zones'::regclass
          and polname = 'safe_zones_delete_parent') as delete_policies;
-- expected AFTER: false | 0

select count(*) as unique_sequence_index
from pg_indexes
where schemaname = 'public' and indexname = 'webrtc_signals_session_sequence_uniq';
-- expected: 1; 0 means duplicates were found and the index was skipped (read the notice)

select p.oid::regprocedure::text,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('request_remote_session','revoke_device','unlink_child','apply_policy_version')
order by 1;
-- expected: 4 rows, all authenticated_execute = f, service_role_execute = t
```

**Known finding:** the migration revokes PUBLIC on `private.request_device_recovery` without
re-granting `service_role`; the private helper therefore loses the implicit service-role execute it
had via PUBLIC. No Edge Function calls it directly — `family-admin` uses the public
`SECURITY DEFINER` wrapper, which remains service-role-only. Recorded, not changed (migration is
out of verification scope).

Rollback (from the file header; privileges are not restored by `create or replace`): drop
`webrtc_signals_session_sequence_uniq`; `grant execute on function
private.request_device_recovery(uuid, uuid) to public;` (and the transition guard if desired);
re-create the four public wrappers from `20261028000200…` / `20260101000100…`; revoke/drop
`private.is_parent_of_family(uuid, uuid)`; re-grant safe-zone DELETE and re-create
`safe_zones_delete_parent`. No data rows change, so rollback is lossless.

Local evidence: full local chain exit 0; `70_phase1_authorization.sql` printed
`ALL PHASE 1 AUTHORIZATION TESTS PASSED`.

## 4. Migration 3 — `20261030000300_retention_sweep.sql`

**Status: NOT APPLIED — owner approval required.**

Pre-check (read-only; previews how much the first sweep would delete):

```sql
select
  (select count(*) from public.webrtc_signals where created_at < now() - interval '7 days') as signals_7d,
  (select count(*) from public.audit_logs where created_at < now() - interval '365 days') as audit_365d,
  (select count(*) from public.location_events le join public.families f on f.id = le.family_id
    where le.recorded_at < now() - make_interval(days => coalesce((f.settings->>'location_retention_days')::int, 30))) as location_outside,
  (select count(*) from public.usage_daily u join public.families f on f.id = u.family_id
    where u.day < current_date - coalesce((f.settings->>'usage_retention_days')::int, 90)) as usage_outside;

select p.oid::regprocedure::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';
-- expected: 0 rows
```

Apply only after migrations 1 and 2, and after the owner has seen the counts above.

Post-check:

```sql
select p.oid::regprocedure::text as function, pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';
-- expected: run_retention_sweep() | jsonb | t | f | t
```

Rollback: `drop function if exists public.run_retention_sweep();` Rows already deleted stay
deleted — that is the purpose of retention. Do not run the function until the counts above are
accepted.

Local evidence: full local chain exit 0; `72_retention_sweep.sql` passed.

## 5. Redeploy `remote-session`

**Status: NOT APPLIED — owner approval required.**

Why: hosted is a stale 30-minute build (`Q = 30*60*1e3`; accept stamps `accepted_at + 30 min`;
`active`/`ice` throw `session_expired` 410; `end` accepts any participant). Repository code has
parent-controlled lifetime and calls `expire_abandoned_sessions` best-effort on `request`.

Pre-check SQL (DB prerequisites must exist before the function is deployed):

```sql
select p.oid::regprocedure::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where (n.nspname = 'public' and p.proname in ('request_remote_session','expire_abandoned_sessions'))
   or (n.nspname = 'private' and p.proname = 'is_parent_of_family')
order by 1;
-- expected after migrations 1-2: all rows present (3 rows)

select status, count(*)
from public.remote_sessions
where status in ('accepted', 'active')
group by status;
-- record; these rows must keep their current expires_at after deploy (no bulk rewrite)
```

Also record the currently deployed version/timestamp in the Dashboard before deploying (there is
no SQL view of an Edge Function version).

Apply: Dashboard → Edge Functions → `remote-session` → deploy the two files together (the function
imports `guard.ts` and `_shared/…`). Keep `verify_jwt = true`; no env change.

Post-check SQL (after one consented test session; this is the contract the new build must produce):

```sql
select id, status, expires_at, accepted_at, consent_recorded, ended_reason
from public.remote_sessions
order by requested_at desc
limit 3;
-- expected: the newly accepted row has status in ('accepted','active'),
--           expires_at IS NULL, consent_recorded = true
```

Behavioural check (Dashboard logs/HTTP, not SQL): accept a request, wait past the old 30-minute
mark if practical, confirm `active`/`ice` no longer return 410; a child cannot end (403), the parent
can. Rollback: redeploy the previous version from Dashboard version history; no DB rollback (all
three migrations are backward-compatible with the old function).

## 6. Redeploy `family-admin`

**Status: NOT APPLIED — owner approval required.**

Why: new `delete_zone` action is now the only path to remove a safe zone (client DELETE is revoked
by migration 2); `purge_data` is owner-only; `not_family_parent` maps to 403.

Pre-check SQL:

```sql
select has_table_privilege('authenticated', 'public.safe_zones', 'delete') as client_delete,
       count(*) as zones
from public.safe_zones;
-- expected: client_delete = false (migration 2 applied); record zones
```

Apply after migration 2. `verify_jwt = true` unchanged, no env change.

Post-check SQL (after deleting one disposable zone through the function):

```sql
select count(*) from public.safe_zones where id = '<deleted-zone-uuid>';
-- expected: 0

select event_type, target_type, target_id, actor_user_id, created_at
from public.audit_logs
where event_type = 'zone_deleted'
order by created_at desc
limit 1;
-- expected: one zone_deleted row for target_type='safe_zone' and the deleted id

select count(*) from public.safe_zones where family_id = '<family-uuid>';
-- expected: previous count - 1
```

Rollback: redeploy the previous `family-admin` version. Note the old bundle has no `delete_zone`;
with client DELETE still revoked, zone deletion is unavailable until either the new bundle is
redeployed or migration 2 is rolled back. That ordering is intentional (no silent fallback).

## 7. Redeploy `cron`

**Status: NOT APPLIED — owner approval required.**

Why: adds `sweep_sessions` (calls `expire_abandoned_sessions`, `p_max_age: "24 hours"`, returns
`{closed_sessions}`) and `retention_sweep` (calls `run_retention_sweep`). Existing
`expire_sessions` and `detect_offline` are unchanged. Both new actions return
`{skipped:true, reason:"function_missing"}` if their migration is not applied.

Pre-check SQL:

```sql
select p.oid::regprocedure::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('expire_abandoned_sessions','run_retention_sweep');
-- expected: both present (migrations 1 and 3 applied)

select max(created_at) as last_retention_sweep
from public.audit_logs where event_type = 'retention_sweep';
-- expected: null before the first run
```

Apply after migrations 1 and 3. Do not change `CRON_SECRET`; the function authenticates with the
existing `x-cron-secret` header and `verify_jwt = false`. No schedule is created by this phase (no
pg_cron, no hosted scheduler).

Post-check SQL (after one manual invocation of each action):

```sql
select count(*) as closed_by_sweep
from public.remote_sessions
where status = 'expired' and ended_reason = 'abandoned'
  and ended_at > now() - interval '1 hour';
-- expected: equals the action's closed_sessions (0 is valid on a healthy project)

select event_type, created_at, metadata
from public.audit_logs
where event_type = 'retention_sweep'
order by created_at desc
limit 1;
-- expected: one row after retention_sweep, with the counts in metadata
```

Rollback: redeploy the previous `cron` version. The new SQL functions remain installed and
harmless; nothing is scheduled automatically.

## 8. Deploy new `account` function

**Status: NOT APPLIED — owner approval required.**

Why: Settings → Privacy & data is wired to `export`, `delete_account` and `retention_report`; there
is no `[functions.account]` block in `supabase/config.toml` (9 existing blocks only). Create the
function in the Dashboard; the default `verify_jwt = true` is correct (the handler also calls
`requireUser`). No new secret or env var is read beyond the existing service-role key.

Pre-check SQL (data shapes the function depends on; no schema change is needed):

```sql
select p.oid::regprocedure::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';
-- expected: present (migration 3)

select count(*) as public_tables
from information_schema.tables
where table_schema = 'public'
  and table_name in ('profiles','families','devices','location_events','usage_daily',
                     'safety_alerts','audit_logs','family_members');
-- expected: 8

-- Preview for a specific caller (replace the uuid); export is capped at 20 000 rows/table.
select
  (select count(*) from public.location_events le
     join public.devices d on d.id = le.device_id
    where d.child_user_id = '<user-uuid>') as location_rows,
  (select count(*) from public.usage_daily u
     join public.devices d on d.id = u.device_id
    where d.child_user_id = '<user-uuid>') as usage_rows,
  (select count(*) from public.safety_alerts a
     join public.devices d on d.id = a.device_id
    where d.child_user_id = '<user-uuid>') as alert_rows;
```

Apply: Dashboard → Edge Functions → create `account` → paste `index.ts` (imports
`retention.ts`, `validation.ts`, `_shared/*`) → deploy with JWT verification on.

Post-check SQL:

```sql
select max(created_at) as last_sweep
from public.audit_logs where event_type = 'retention_sweep';
-- retention_report must show this value (null before the first cron run)

select count(*) as active_members
from public.family_members
where family_id = '<owned-family-uuid>' and status = 'active';
-- delete_account must refuse while this is > 1 for an owner (verify with the 403 response,
-- do NOT delete a real account during deployment)
```

Behavioural check: call `export` and confirm a JSON attachment with `Content-Disposition` and
`truncated` flags; call `retention_report`; call `delete_account` with a wrong confirmation and
confirm a 4xx with no deletion. Rollback: delete the function in the Dashboard. No schema or data
change from export/report; an actual `delete_account` is irreversible by design and must only be
tested on a disposable account.

## 9. Secrets and auth — zero changes

**Status: NOT APPLIED — owner approval required (no change proposed).**

No secret is added, rotated or removed: `CRON_SECRET`, `TURN_URL`, `TURN_SECRET`, the service-role
key and all Supabase-provided keys stay as they are. No auth provider, redirect URL, email
template, JWT expiry, RLS policy on `auth.*` or storage bucket changes. Phase 1 writes files only.

Pre-check and post-check (record both; values must be identical):

```sql
select count(*) as auth_users from auth.users;

select count(*) as buckets from storage.buckets;

select count(*) as public_tables from pg_tables where schemaname = 'public';
-- expected before and after: 19 (no new table in Phase 1)
```

Dashboard check: function secrets list and Auth settings screenshot/record before and after; the
only permitted difference is the new `account` function entry, which reads existing secrets.

Rollback: not applicable — no change is made. If a later deploy accidentally changes a secret or
auth setting, restore it from the pre-check record; SQL cannot restore dashboard secrets.

---

## 10. What was **not** done

- No `supabase` CLI command, no `db push`, no `functions deploy`, no hosted SQL.
- No migration applied to any hosted project; the only SQL execution was a disposable local
  PostgreSQL 16 cluster (created, exercised, dropped).
- No production data deleted or modified; retention and abandoned-session counts are previews only.
- No secret, auth, storage or Realtime configuration change.
- No device or emulator runtime test; see `regression-matrix.md` §1.