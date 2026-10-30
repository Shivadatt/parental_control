# A6 — Local empirical reproduction of the pairing rate-limit defects

**Date:** 2026-10-27 · **Mode:** read-only audit of `D:\parentcontrol_app` (no project file was modified)
**Verdict:** all seven checks executed and proven against a real PostgreSQL. Nothing in this report is inferred from source alone.

## 0. Harness

- Reused the already-running documented local server: **PostgreSQL 16.9** on `127.0.0.1:55432`, trust auth, binaries `D:\parentcontrol_app\.tools\pgsql16\pgsql\bin` (the same harness described in `supabase/tests/README.md` and `.tools/sql-tests-20261027.log`).
- **No** connection to any `*.supabase.co` host was made; `psql` was always given `-h 127.0.0.1 -p 55432`.
- New throwaway database, created only for this run:

```
psql -U postgres -h 127.0.0.1 -p 55432 -c "drop database if exists parentcontrol_ratelimit_repro;" postgres
-- NOTICE:  database "parentcontrol_ratelimit_repro" does not exist, skipping / DROP DATABASE
psql -U postgres -h 127.0.0.1 -p 55432 -c "create database parentcontrol_ratelimit_repro;" postgres
-- CREATE DATABASE
```

- Baseline applied first (all 5 migrations + all 8 test files, exactly the documented order) — see §7. All repro SQL lives in
  `.tools/evidence/full-qa/read-only-audit-20261027/scratch/` (`a6_01_counting.sql`, `a6_02_attempts.sql`, `a6_03_deadcols_structure_retention.sql` + `.log` files + `suite-run.log`).

## 1. THE COUNTING BUG — `device_pairing_tokens` counted with no status filter

`supabase/functions/_shared/rate_limit.ts:70-88` counts **all** rows for the child with `created_at >= now()-24h` and throws at `>= 5` (`CODE_CREATIONS_PER_24H = 5`, `rate_limit.ts:8`). `supabase/functions/pairing/index.ts:248-253` revokes every previous `active` token on each create, so ordinary use accumulates dead rows that keep counting.

Scenario A replays the real create sequence in SQL (insert `active`, then revoke the other `active` rows, 5 times). Scenario B adds the unlink bulk-revoke (`migrations/20260101000100_functions.sql:398-401`). C/D/E are the mixes requested.

Actual stored row mixes (verbatim from the DB):

```
 a1000000-… | active(live), revoked(live), revoked(live), revoked(live), revoked(live)     <- scenario A
 a2000000-… | revoked(live) x5                                                             <- scenario B
 a3000000-… | expired(past-ttl) x2, redeemed(past-ttl), revoked(past-ttl) x2               <- scenario C
 a4000000-… | active(past-ttl) x5                                                          <- scenario D
 a5000000-… | active(live)                                                                 <- scenario E control
```

The two count expressions (SQL below; `current_count` = `rate_limit.ts` as shipped, `proposed_count` = same plus `and status='active' and expires_at > now()`):

```sql
with scenarios(label, child) as (values
  ('A: 4 revoked + 1 active (5 real creates)','a1000000-0000-4000-8000-000000000000'::uuid),
  ('B: 5 revoked (unlinked/relinked child)',  'a2000000-0000-4000-8000-000000000000'::uuid),
  ('C: 1 redeemed + 2 expired + 2 revoked',   'a3000000-0000-4000-8000-000000000000'::uuid),
  ('D: 5 active rows past TTL (stale)',       'a4000000-0000-4000-8000-000000000000'::uuid),
  ('E: control, 1 live active token',         'a5000000-0000-4000-8000-000000000000'::uuid))
select sc.label,
  (select count(*) from public.device_pairing_tokens t
     where t.child_user_id = sc.child and t.created_at >= now() - interval '24 hours') as current_count,
  (select count(*) from public.device_pairing_tokens t
     where t.child_user_id = sc.child and t.created_at >= now() - interval '24 hours'
       and t.status = 'active' and t.expires_at > now()) as proposed_count, ...
```

Actual output:

```
                  label                   | current_count | proposed_count | current_verdict | proposed_verdict
------------------------------------------+---------------+----------------+-----------------+------------------
 A: 4 revoked + 1 active (5 real creates) |             5 |              1 | BLOCKED (429)   | allowed
 B: 5 revoked (unlinked/relinked child)   |             5 |              0 | BLOCKED (429)   | allowed
 C: 1 redeemed + 2 expired + 2 revoked    |             5 |              0 | BLOCKED (429)   | allowed
 D: 5 active rows past TTL (stale)        |             5 |              0 | BLOCKED (429)   | allowed
 E: control, 1 live active token          |             1 |              1 | allowed         | allowed
```

**Conclusion (proven):** five ordinary code creations by one child — the app's own happy path — trip the 429 even though at most one token is usable. The `status='active' and expires_at > now()` filter relieves a locked-out child **immediately** in every dead-row scenario (5 → 0 in B/C/D, 5 → 1 in A) while leaving the control at 1, i.e. it does not weaken the limit against genuine code spam (an attacker would still need 5 *live* tokens, and the create path revokes prior actives, so live rows for one child are capped at 1 — scenarios A shows `proposed_count = 1` after 5 creates).
Scenario D also proves a second hazard: `status` is only flipped to `'expired'` opportunistically (`pairing/index.ts:308-313` on a redeem attempt, `:440-445` on the `pending_child` list), never by a job, so `status='active'` alone would still over-count — the `expires_at > now()` half of the predicate is load-bearing.

## 2. Status constraint values (live catalog, not source)

```sql
select conname, pg_get_constraintdef(oid) from pg_constraint
where conrelid = 'public.device_pairing_tokens'::regclass
  and conname = 'device_pairing_tokens_status_check';
```
```
 device_pairing_tokens_status_check | CHECK ((status = ANY (ARRAY['active'::text, 'redeemed'::text,
                                   |  'revoked'::text, 'expired'::text])))
 has_active | has_redeemed | has_revoked | has_expired | has_consumed
 t          | t            | t           | t           | f
```
Empirical probe: `insert … status='consumed'` →
`NOTICE: CONFIRMED: rejected with SQLSTATE 23514 (… violates check constraint "device_pairing_tokens_status_check")`.
**There is no `'consumed'` status**; the four values are `active | redeemed | revoked | expired` (declared `core.sql:136-137`).

## 3. `attempts` / `max_attempts` on `device_pairing_tokens` are dead

Declarations `core.sql:138-139` (`attempts integer not null default 0`, `max_attempts integer not null default 10`).

Grep evidence (whole repo, `*.{ts,sql,dart}`):
- Writes to the table: `migrations/20260101000100_functions.sql:280-282` (`status='redeemed', redeemed_at, redeemed_by`), `:301-303` (`status='revoked'`), `:398-401` (`status='revoked'`); Edge Function writes `pairing/index.ts:229-235` (insert: `child_user_id, code_hash, expires_at, status, created_by`), `:249-253`, `:310-313`, `:441-445`, `:521-524` — **every one of them touches only `status` / `redeemed_*`**.
- The columns appear only in a *read*: `pairing/index.ts:55-56` (row interface) and `:295` `.select("id, child_user_id, status, expires_at, attempts, max_attempts")`. Neither is ever used in a condition and no update sets them.
- The only SQL that increments an `attempts` column is `functions.sql:633` `attempts = c.attempts + 1` — that is `public.device_commands` (`core.sql:216`), not the token table.

Live-catalog confirmation in the throwaway DB after the whole suite plus 16 repro token writes:

```
 functions mentioning device_pairing_tokens : private.respond_pairing_request, private.unlink_child
 mentions_max_attempts = f, mentions_attempts = f for BOTH
 functions anywhere mentioning max_attempts : NONE
 triggers on device_pairing_tokens          : (0 rows)     rules: (0 rows)

 attempts | max_attempts | count
----------+--------------+-------
        0 |           10 |    27        <- 27 rows, every one still on the DDL default
```

**Conclusion:** no SQL in migrations, RPCs, Edge Functions or the client writes `attempts`/`max_attempts`. They are dead columns; per-code brute-force accounting actually lives in `public.pairing_attempts` (§5).

## 4. `pairing_requests.token_id NOT NULL UNIQUE` — structural blocker for invite-style linking

`core.sql:152-155`. Live catalog:

```
 token_id_not_null = t
 pairing_requests_token_id_key | u | UNIQUE (token_id)
 pairing_requests_token_id_fkey| f | FOREIGN KEY (token_id) REFERENCES device_pairing_tokens(id) ON DELETE CASCADE
```
plus `\d public.pairing_requests` (also shows `token_id uuid not null`, `status` check `pending_child|approved|rejected|cancelled|expired`).

Empirical:
```
NOTICE: CONFIRMED: token_id NOT NULL rejects an invite-style request (SQLSTATE 23502)
NOTICE: OK: exactly one request per redeemed/active token (token_id=a05e3a2d-…) inserted
NOTICE: CONFIRMED: token_id UNIQUE rejects a second request (SQLSTATE 23505)
requests_without_token = 0
```
**Conclusion:** a pairing request cannot exist without exactly one pre-issued token — a parent cannot invite a child (or start a link) before the child generates a code. This is the structural blocker for invite-style linking, and it also means the `token_id UNIQUE` caps one request per code, so retrying a code after a cancel hits `code_unavailable` (`pairing/index.ts:370-390`).

## 5. `recordPairingAttempt` bills successes; `success` is ignored

`rate_limit.ts:49-68` inserts a row on **every** outcome, and `pairing/index.ts:330, 353, 401` pass `success = true` when a valid code redeems successfully. The two gates (`rate_limit.ts:20-38`) count rows with **no `success` predicate**: per-parent 5/10min (`MAX_ATTEMPTS_PER_PARENT = 5`), per-code 10/10min (`MAX_ATTEMPTS_PER_TOKEN = 10`), `ATTEMPT_WINDOW_MINUTES = 10`.

Scenario P — one parent successfully links 5 different children (5 rows, all `success = true`, no failures):

```
 per_parent_count | if_only_success_counted | if_only_failures_counted
------------------+-------------------------+--------------------------
                5 |                       5 |                        0

NOTICE:  VERDICT per-parent: count=5 >= MAX_ATTEMPTS_PER_PARENT=5 -> ApiError rate_limited 429. The 6th child cannot be linked.
NOTICE:  CONTROL: counting only failures gives 0 -> a parent with 0 failures would be allowed.
 success | count
---------+-------
 t       |     5
```

**A parent who linked 5 children cleanly is locked out of a 6th for the rest of the 10-minute window** (and the assert runs *before* redemption, `pairing/index.ts:286`, so the 6th child's valid code is rejected unread). The `success` column is stored (`5/5 = t`) but never read by either gate.

Scenario Q — one code, 1 success + 9 failures (`attempted_at` all inside 10 min):

```
 per_code_count | per_code_success_count | per_code_failure_count
----------------+------------------------+------------------------
             10 |                      1 |                      9
NOTICE:  VERDICT per-code: count=10 >= MAX_ATTEMPTS_PER_TOKEN=10 -> 429 "Ask for a new code.", even though only 1 row was a success.
```

Scenario R — mixed 3 true / 2 false for one parent (the requested mix): `current_count = 5`, `failures_only_count = 2` → same verdict flip as P.

## 6. No purge/retention for `device_pairing_tokens` or `pairing_attempts`

Static: `functions.sql:947-968` registers exactly two pg_cron jobs (`expire_stale_sessions`, `detect_offline_devices`); `functions/cron/index.ts:39-66` exposes exactly those two actions and nothing else; `family-admin/index.ts:187-199` (`purge_data`) deletes only `location_events` and `usage_daily`. The only SQL `delete` inside a function is `private.replace_device_apps` (`functions.sql:677`).

Live catalog (every `DELETE FROM` compiled into any function of `public`/`private`):

```
             fn              |               target
-----------------------------+------------------------------------
 private.replace_device_apps | public.device_apps where device_id

writers_deleting_tokens     : NONE
writers_deleting_attempts   : NONE
pg_cron_installed (local)   : 0
```

Empirical ageing test — seeded a token and an attempt with `created_at/attempts = now() - 400 days`, ran both maintenance RPCs:

```
 before: device_pairing_tokens = 28, pairing_attempts = 20, of which expired tokens = 11
 select public.expire_stale_sessions(), public.detect_offline_devices();  -> 0 | 0
 after : device_pairing_tokens = 29, pairing_attempts = 21,
         ancient token still present = 1, ancient attempt still present = 1

 c1109772-35f8-44a0-ab28-8cc778a08b41 | active | 2025-09-22 … | 2025-09-22 …   <- still status='active' after 400 days
```

**Conclusion:** nothing deletes or ages out either table; rows are permanent. The 24h window in §1 only *hides* old rows (`in_24h_window = 6` vs `total_rows_for_that_child = 7`); within that window every dead row is billed, and dead rows are guaranteed to accumulate because `pairing/index.ts:248-253` turns each superseded code into a permanently-counting `revoked` row.

## 7. Repo SQL suite baseline (run first, before any repro write)

Command (from `D:\parentcontrol_app`, README order, all options before `-d`):

```
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/migrations/20260101000400_device_recovery.sql \
  -f supabase/tests/10_schema.sql -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql -f supabase/tests/45_device_recovery.sql \
  -h 127.0.0.1 -p 55432 -U postgres -d parentcontrol_ratelimit_repro
```

Result: **EXIT=0** with `ON_ERROR_STOP=1`; log `.tools/evidence/full-qa/read-only-audit-20261027/scratch/suite-run.log` = 403 lines of real SQL activity (226 statement-status lines, 9 test `DO` blocks), **0 `ERROR` lines and 0 `ASSERTION FAILED`** (the single case-insensitive `error` hit is the JSON payload key `"error_message": null` at log line 267). Post-run catalog: `18` public tables, `1` realtime policy, `32` functions in `public`+`private`, server version `16.9`. Baseline is green: **5 migrations + 8 test files, 18 public tables.**

## 8. Cleanup

```
psql -U postgres -h 127.0.0.1 -p 55432 -c "drop database parentcontrol_ratelimit_repro;" postgres
-- DROP DATABASE
psql -U postgres -h 127.0.0.1 -p 55432 -Atc "select count(*) from pg_database where datname='parentcontrol_ratelimit_repro';"
-- 0     (removed; no other database was created, touched or dropped)
```

## 9. Scope notes / non-claims

- The local DB is a plain PostgreSQL with `00_auth_stub.sql`/`05_realtime_stub.sql` scaffolding; it does **not** validate hosted Supabase behavior, PostgREST query translation, or the deployed project. The count expressions reproduce the exact filters `rate_limit.ts` sends (`.eq/.gte`, no `success`/`status` predicate) as SQL equivalents.
- `pg_cron` is absent locally, so the two registered jobs could not be scheduled; irrelevant to §6 because those jobs touch `remote_sessions`/`devices`/`safety_alerts` only, verified by the function-body scan.
- No project file, migration, test, or cluster configuration was modified; only the throwaway database and the scratch directory were written.
