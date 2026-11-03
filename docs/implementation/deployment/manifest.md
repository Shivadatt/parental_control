# Phase 1 migration manifest (apply order + proof of application)

**Status: none of these migrations is applied. Phase 1 writes files only; there
is no hosted SQL in this phase and no Supabase CLI. Applying them is an
owner-approved dashboard step.**

*(2026-11-03, Phase 5: this manifest now lists four files; `20261103000100`
was added this phase under workstream SQL-05 and is likewise unapplied, §4.
Phase 5 made **no** hosted change and made **no** new read-only dashboard
inspection — the last hosted state check is the 2026-10-30 read-only dashboard
audit recorded in `docs/implementation/_work/p4-hosted.md`, which found
production entirely pre-Phase-1. Nothing in this phase re-confirms or refutes
that; HOST-01 stays open until someone applies the authorized migrations and
verifies them read-only.)*

How to apply, per file, through the Dashboard SQL Editor:

1. Open SQL Editor → New query → paste one file **exactly as-is** → Run.
2. Run that file's `select` check below and compare with the expected output.
3. Record file name, SHA-256 and timestamp in
   `docs/implementation/deployment-log.md` (verification workstream).
4. Only then apply the next file. All three are additive and re-runnable
   (`create or replace` / `if not exists` / guarded blocks). *(2026-11-03: files
   1–3 as listed; file 4, §4, is additive and re-runnable too, but it is ordered —
   it must follow file 2.)*

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

### 0.1 Hashes re-measured on 2026-11-03 (Phase 5) — the table above is stale

The three values in the table were printed when this manifest was written in
Phase 1 and were **not** re-verified here at the time. Recomputing them on the
uncommitted Phase 5 tree (`main` @ `953b337`, nothing applied, nothing committed)
shows two of the three no longer match anything, and the third matches HEAD but
not the worktree:

| # | File | Table value (Phase 1) | HEAD blob (2026-11-03) | worktree (2026-11-03) | Verdict |
|---|---|---|---|---|---|
| 1 | `20261030000100` | `12f20c81…` | `aca47b44bb69c5d9ad70a95d52da314faec56217203cd0d49fa90f9085182c7b` | same as HEAD | table value matches neither → stale since before Phase 5 |
| 2 | `20261030000200` | `f7062a84…` | `7558021d6aec4f9a80b16b1d401e03b4b84751ec93ea6c3dd83b9df67b1bfa38` | same as HEAD | table value matches neither → stale since before Phase 5 |
| 3 | `20261030000300` | `8de3cb38…` | `dd734fbdcd3f3300c1f3d75f3946d5845d7e959a2aa4c9bc3e015c781abcdf0e` | `184d8acb33090e4a587de8cad97e21c00688234f452fc50224242ba5cc1870ba` | Phase 5 (PERF-01a) changed the worktree; HEAD still differs from the table |
| 4 | `20261103000100` | — (did not exist) | absent from HEAD | `a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf` | new in Phase 5 (SQL-05), unapplied. The earlier `4fdf1cfb…` value is **not** a guess — it is the blob sitting in the git index (`git show :supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql \| sha256sum` → `4fdf1cfb25606b68…`), i.e. the file as added before the Phase 5 header-citation correction (EV-02). Worktree and index disagree, which is why this row's status code is `AM` in `phase-5-report.md` §2. |

Method, so the discrepancy is not a line-ending artifact: `sha256sum <file>` for
the worktree bytes, `git show HEAD:<file> | sha256sum` for the committed blob and
`git show :<file> | sha256sum` for the staged blob, run in the same shell on
2026-11-03. Files 1–2 hash identically on all three bases, so the table's values
are genuinely old content hashes, not LF/CRLF artifacts.

**Do not apply against the table above.** Use the §0.1 worktree values, then
re-check on the applying machine (the Phase 5 tree is uncommitted; the next
`git` operation that rewrites these paths can legitimately change the digests —
git already warns `LF will be replaced by CRLF the next time Git touches it` on
some of these paths).

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

**Pre-apply check (mandatory, read-only — run this in the SQL Editor *before*
pasting file 2, not after):**

```sql
select count(*) as duplicate_sequence_groups
from (
  select session_id, sequence
  from public.webrtc_signals
  group by 1, 2
  having count(*) > 1
) d;
```

Expected `0`. This is the same predicate the migration itself evaluates
(`20261030000200_phase1_authorization.sql:478-486`), lifted out of the `do $$`
block so the operator learns the outcome *before* the run instead of reading it
out of the Editor's NOTICE stream afterwards. Why it is mandatory: the post-apply
check below (`unique_sequence_index`) only reports `1` or `0` *after* the fact,
and `0` is produced by two very different paths — the guard finding duplicates
and skipping (migration `:492` `raise notice 'duplicate sequences exist; index
skipped'`), or the file never having run. The SQL-06 contract wording in
`docs/implementation/api-contract.md` §5 describes replay protection as
conditional on this index existing, so a `0` result means the documented
guarantee is **not** in force and the duplicates are still live data.

If the count is non-zero: **stop, do not apply file 2, and escalate.** The
migration's own contract is "duplicates are reported, never deleted"
(`:474`) — deleting rows to make the check pass would be a production data
deletion, which is out of scope for every phase so far (§12 of the Phase 5 brief
forbids it outright). The only owner-approved paths are a separate, explicitly
authorised data-cleanup decision, or accepting the documented weaker guarantee
and correcting the contract wording.

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

## 4. `20261103000100_zone_delete_atomic_rpc.sql` (Phase 5, SQL-05)

Added 2026-11-03 by workstream SQL-05 after owner approval of the atomic RPC.
**Unapplied, locally tested only.** SHA-256 of the worktree file measured on
2026-11-03 after every Phase 5 correction:
`a1d7d60954bc61dcd98ada1d8b25ad95af134364622582ee6b43c524d3834adf`
(`sha256sum supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql`). An
earlier value, `4fdf1cfb25606b6893b08738efa45b2c233ff7f6a9f9453351c9c221698bfffc`,
was published before the EV-02 header-citation fix and is superseded — this is the
hazard §0.1 warns about on an uncommitted tree.

Ordering constraint the earlier files do not have: this function's body calls
`private.is_parent_of_family(uuid, uuid)`, which is created by **file 2**
(`20261030000200_phase1_authorization.sql:186-206`, service-role-only grants at
`:208-211`). Applying file 4 before file
2 fails with `function private.is_parent_of_family(uuid, uuid) does not exist`.
It also needs `private.record_audit` from the pre-Phase-1 baseline
(`20260101000100_functions.sql:8-39`), which is already live. So: **files 2 → 4**,
and file 4 is additive (`create or replace function` at `:141`, plus a
revoke/grant pair at `:256-259`) and re-runnable.

```sql
select p.oid::regprocedure::text as function,
       pg_get_function_result(p.oid) as returns,
       p.prosecdef as security_definer,
       p.proconfig as settings,
       has_function_privilege('anon', p.oid, 'execute') as anon_execute,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute,
       p.proacl as acl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'delete_safe_zone_audited';
```

Expected (measured on the final green disposable-chain run, database
`p5rpc_full9`, 2026-11-03 — not on hosted):

```text
function                      | returns | security_definer | settings                                 | anon_execute | authenticated_execute | service_role_execute | acl
delete_safe_zone_audited(uuid,uuid) | jsonb | t            | {"search_path=public, private, pg_temp"} | f            | f                     | t                    | {postgres=X/postgres,service_role=X/postgres}
```

The `acl` value is the load-bearing one: `anon` and `authenticated` do not
appear, so they hold no execute privilege at all — this function is not
client-callable, and the §7 no-new-client-RPC rule in
`docs/implementation/api-contract.md` is unchanged. A hosted result that lists
`authenticated=` or `anon=` privileges means the grant shape differs from what
was reviewed: stop and escalate rather than "fixing" it with a blanket grant.

```sql
-- No table-grant or RLS change is part of this file. These must stay false / 0
-- after applying it, exactly as file 2 left them:
select has_table_privilege('authenticated', 'public.safe_zones', 'delete') as authenticated_can_delete,
       (select count(*) from pg_policy
         where polrelid = 'public.safe_zones'::regclass
           and polname = 'safe_zones_delete_parent') as delete_policies;
```

Expected: `f`, `0`. If either changes, file 4 was edited before applying — the
reviewed version touches no table privilege, policy, trigger, column or
constraint.

Rollback (as documented in the file header at `:128-129`):

```sql
revoke all on function public.delete_safe_zone_audited(uuid, uuid) from service_role;
drop function if exists public.delete_safe_zone_audited(uuid, uuid);
```

Rolling file 4 back while `family-admin` still calls it makes `delete_zone` fail
closed (the handler maps the missing-function error to a 500 and never deletes
unaudited); it does **not** restore the Phase 3 compensating-write path, because
that path was removed from the handler when the RPC went in. Roll back the
function and the handler together, or leave the handler calling nothing.

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

*(2026-11-03: this query covers Phase 1's three files only. SQL-05's
`public.delete_safe_zone_audited` is verified by its own query in §4 — it is
deliberately not folded into this union, because a `0` here would otherwise
mean two different things: "Phase 1 incomplete" or "the Phase 5 RPC was
skipped", and those have different escalation paths.)*

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