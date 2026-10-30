# Phase 1 migration manifest (apply order + proof of application)

**Status: none of these migrations is applied. Phase 1 writes files only; there
is no hosted SQL in this phase and no Supabase CLI. Applying them is an
owner-approved dashboard step.**

How to apply, per file, through the Dashboard SQL Editor:

1. Open SQL Editor → New query → paste one file **exactly as-is** → Run.
2. Run that file's `select` check below and compare with the expected output.
3. Record file name, SHA-256 and timestamp in
   `docs/implementation/deployment-log.md` (verification workstream).
4. Only then apply the next file. All three are additive and re-runnable
   (`create or replace` / `if not exists` / guarded blocks).

Baseline that must be true first: the hosted project has the four `20261028000100…20261028000300`
migrations applied (confirmed read-only through the dashboard during the audit: nullable
`expires_at`, pending-only expiry, signaling policies without an expiry predicate). They are not
repeated in this manifest because they are already live; re-check them with `remote-session.md`
§3 B–D before applying Phase 1.

| # | File | Purpose | SHA-256 (at writing) |
|---|---|---|---|
| 1 | `20261030000100_abandoned_session_sweep.sql` | `public.expire_abandoned_sessions(interval)` + partial index. Closes consented sessions abandoned for 24 h. | `12f20c8193110c35bc3b0146f899ec90ac46bef3b59137ff9d97f4058f14297a` |
| 2 | `20261030000200_phase1_authorization.sql` | Family-parent authorization (`private.is_parent_of_family`), safe-zone DELETE removal, signaling unique index, RPC actor checks. Owned by workstream `security`. | `f7062a84cff31a283fae8c917d41bbd540e4a8b27d2c55102ec19881a835db58` |
| 3 | `20261030000300_retention_sweep.sql` | `public.run_retention_sweep()` retention windows (signals 7 d, audit 365 d, per-family location/usage). Owned by workstream `lifecycle`. | `8de3cb388cfaf767d1945e47dbe771497e8d08d5139ba407d787622586d415ff` |

Recompute every hash on the machine that applies it; a hash that differs from
this table means the file changed after this manifest was written.

```bash
sha256sum supabase/migrations/20261030000100_abandoned_session_sweep.sql
```

## 1. `20261030000100_abandoned_session_sweep.sql`

Adds a partial index `remote_sessions_abandoned_idx` and a `SECURITY DEFINER`
function granted to `service_role` only. It touches no column, constraint or
policy.

```sql
select p.oid::regprocedure::text as function,
       pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer,
       p.proconfig as settings,
       has_function_privilege('anon', p.oid, 'execute') as anon_execute,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'expire_abandoned_sessions';
```

Expected (actual output from a local PostgreSQL 16 run of the full chain):

```text
function                            | returns | security_definer | settings                                 | anon_execute | authenticated_execute | service_role_execute
expire_abandoned_sessions(interval) | integer | t                | {"search_path=public, private, pg_temp"} | f            | f                     | t
```

```sql
select indexname from pg_indexes
where schemaname = 'public' and indexname = 'remote_sessions_abandoned_idx';
```

Expected: one row, `remote_sessions_abandoned_idx`.

Rollback: `drop function if exists public.expire_abandoned_sessions(interval);`
`drop index if exists public.remote_sessions_abandoned_idx;` (rows already
closed stay `expired` / reason `abandoned`; that is history).

## 2. `20261030000200_phase1_authorization.sql`

```sql
select p.oid::regprocedure::text as function,
       pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private' and p.proname = 'is_parent_of_family';
```

Expected: `private.is_parent_of_family(uuid,uuid) | boolean | t | f | t`.

```sql
select has_table_privilege('authenticated', 'public.safe_zones', 'delete') as authenticated_can_delete,
       (select count(*) from pg_policy
         where polrelid = 'public.safe_zones'::regclass
           and polname = 'safe_zones_delete_parent') as delete_policies;
```

Expected: `authenticated_can_delete = false`, `delete_policies = 0`.

```sql
select count(*) as unique_sequence_index
from pg_indexes
where schemaname = 'public' and indexname = 'webrtc_signals_session_sequence_uniq';
```

Expected: `1`. `0` means the migration found duplicate `(session_id, sequence)`
rows and skipped the index with a notice — read the SQL Editor output, do not
retry blindly.

Rollback: documented in the file header (re-grant, drop helper, drop index).
Owned by workstream `security`.

## 3. `20261030000300_retention_sweep.sql` (lifecycle workstream)

```sql
select p.oid::regprocedure::text as function,
       pg_get_function_result(p.oid) as returns,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';
```

Expected: `run_retention_sweep() | jsonb | f | t`.

If the file is absent when this manifest is used, Phase 1 is incomplete for the
lifecycle scope: do not substitute a different function name, and do not apply
files 1–2 as "the whole thing". Files 1–2 are independent and safe to apply
without file 3.

## Combined post-apply check (read-only)

```sql
select 'sweeper' as item,
       count(*) as present
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'expire_abandoned_sessions'
union all
select 'is_parent_of_family', count(*)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private' and p.proname = 'is_parent_of_family'
union all
select 'run_retention_sweep', count(*)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';
```

Expected: three rows, each `present = 1`.

## Local evidence for file 1 (not hosted)

`20261030000100` was applied on a **disposable local PostgreSQL 16** cluster
(`initdb` in a temp data directory, no Supabase project, no CLI): migrations
`20260101000000…20261028000300` + `20261030000100`, then
`supabase/tests/10,20,50,30,40,55,60,61,62,63` and `45_device_recovery` — all
`psql -v ON_ERROR_STOP=1` runs exited 0 with no `ERROR` / `ASSERTION FAILED`, and
`63_abandoned_session_sweep.sql` printed
`ALL ABANDONED SESSION SWEEP TESTS PASSED`. Re-running the migration file on the
same database also exited 0 (`relation "remote_sessions_abandoned_idx" already
exists, skipping`; function replaced), which is the idempotency proof.
This says nothing about the hosted project.