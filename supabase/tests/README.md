# SQL authorization tests

These tests exercise the schema, RLS policies, grants and internal RPCs against a
**plain PostgreSQL 15+** database. They do **not** use a Supabase project. The
suite was re-run on 2026-10-27 against a fresh disposable PostgreSQL 16.9
database with **all seven migrations** (including
`20260101000600_atomic_pairing_invite.sql`) and every test file, including
`55_pairing_invite_atomic.sql` and `45_device_recovery.sql` (the latter last),
and passed (psql `EXIT=0` with `ON_ERROR_STOP=1`, no `ERROR` and no
`ASSERTION FAILED` in the log; 19 public tables, realtime policy present). A
separate two-session run, `run_pairing_invite_race.sh`, passed against a
disposable database as well (see below). Earlier runs on 2026-10-27/26 used the
five and four migrations present at those times. No run verifies any
Supabase-hosted behavior.

`00_auth_stub.sql` is local-test scaffolding only. It creates the `anon`,
`authenticated` and `service_role` roles when missing, a minimal `auth.users`
table, and `auth.uid()` / `auth.role()` that read the usual
`request.jwt.claim.sub` / `request.jwt.claim.role` settings. **Never apply this
file to a Supabase project**; Supabase already provides all of it.

## Exact command

Run from the repository root against an **empty, disposable, local** database as
a role allowed to create roles/schemas (usually the database owner or a
superuser). Use a fresh database for every run; fixtures use fixed UUIDs and
are not re-runnable.

```bash
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql \
  -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/migrations/20260101000400_device_recovery.sql \
  -f supabase/migrations/20260101000500_child_contact_ids.sql \
  -f supabase/migrations/20260101000600_atomic_pairing_invite.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -f supabase/tests/55_pairing_invite_atomic.sql \
  -f supabase/tests/45_device_recovery.sql \
  -d "$DATABASE_URL"
```

`50_realtime_policy.sql` runs before `40_functions.sql` because the latter unlinks
a fixture child used by the policy test. `55_pairing_invite_atomic.sql` is
self-contained (it inserts its own `auth.users`/profiles/families with fresh
UUIDs), so it runs before `45_device_recovery.sql`. `45_device_recovery.sql`
mutates the family1/child1 fixtures, so it runs **last**.

`20260101000500_child_contact_ids.sql` and
`20260101000600_atomic_pairing_invite.sql` were appended after the earliest run
recorded above. The current command applies all seven migrations and every test
file and exits 0 with 19 public tables and no `ERROR` or `ASSERTION FAILED`
line. `10_schema.sql` also asserts that `child_contact_ids` exists with RLS
enabled, that only `service_role` holds privileges on it, that its check
constraint rejects ambiguous characters, that `device_pairing_tokens.purpose`
is `NOT NULL`, defaults to `'code'` and accepts only `'code'`/`'invite'`, and
that the four `create_pairing_invite`/`create_pairing_request` functions
(public wrappers and private implementations) are `SECURITY DEFINER` with a
pinned `search_path` and are executable only by `service_role`.

Keep every option before the connection argument. On Windows, PostgreSQL
16.9 `psql` does not permute arguments: options placed after the database name
are reported as "extra command-line argument ... ignored" and the command can
still exit 0 without executing a single file. Treat a run as valid only if the
log shows SQL activity and the database ends with 19 public tables for the
seven-migration command above.

`$DATABASE_URL` is your own local connection string; no credential value is
stored in this repository. Example shape only:
`postgresql://postgres:<password>@127.0.0.1:5432/parentcontrol_test`.

Any failure raises `ASSERTION FAILED: ...` (or an unexpected SQL error) and
`ON_ERROR_STOP=1` makes `psql` exit non-zero. A silent run with no output is not
proof of success; check the exit status.

## Two-session race test (BUG-033)

A single session cannot prove that `private.create_pairing_invite()` serialises
concurrent callers; it only proves the read-then-insert logic. The race script
builds a disposable database, opens session A in one transaction (RPC + 4 s
sleep, holding `pg_advisory_xact_lock`), starts session B ~0.7 s later on the
same `(child, family, parent)` triple, and fails unless B blocked for at least
2.5 s, returned `created=false` with A's request id, and left exactly one live
request row. Run it from the repository root:

```bash
bash supabase/tests/run_pairing_invite_race.sh
# Keep the disposable DB for inspection:
KEEP_DB=1 bash supabase/tests/run_pairing_invite_race.sh
# Non-default cluster:
PGHOST=127.0.0.1 PGPORT=55432 PGUSER=postgres \
  bash supabase/tests/run_pairing_invite_race.sh
```

The script prepends `$REPO_ROOT/.tools/pgsql16/pgsql/bin` (resolved from its own
location) to `PATH`, uses `postgres`/trust auth, applies `00_auth_stub.sql`,
`05_realtime_stub.sql`, all migrations in filename order and
`20_fixtures.sql`, then its own rows. It prints an evidence block and exits
non-zero on any failed assertion; the disposable
`parentcontrol_race_<timestamp>` database is dropped on success and failure
unless `KEEP_DB=1`.

## Coverage

- `00_auth_stub.sql` — local roles, `auth.users`, `auth.uid/role`, assertion
  helpers `tests.assert_true`, `tests.expect_error`, `tests.put/get`,
  `tests.fk_columns`.
- `05_realtime_stub.sql` — local-only stand-in for Supabase's `realtime.messages`
  and `realtime.topic()`, so the actual private-channel policy DDL is created
  and can be exercised. It does not emulate the Realtime server.
- `10_schema.sql` — all 19 tables exist with RLS enabled; service-only tables have
  no policies; client tables only grant policy access to `authenticated`; FK
  columns to `profiles`/`auth.users`; expected triggers, partial unique indexes
  and unique constraints; `anon` has no table privileges; column-level grants
  (e.g. `profiles.role` is not client-writable, `devices.secret_hash` and
  `devices.installation_id` are never client-readable); private state-changing
  RPCs are not executable by clients (the four boolean policy helpers are the
  documented exception); public RPC wrappers are service-role only; the four
  atomic pairing RPCs are `SECURITY DEFINER` with a pinned `search_path` and
  executable only by `service_role`.
- `20_fixtures.sql` — two unrelated families, owner/parent/child memberships,
  devices (active, revoked, pending), policy versions, commands, telemetry,
  zones, alerts, sessions and pairing requests. Writes use direct SQL and the
  service-role RPC wrappers, mirroring the Edge Functions' server access.
- `30_rls.sql` — cross-family isolation for parents and children, owner-only
  family updates, child read/write restrictions (devices, safe zones, signals,
  audit, pairing, role promotion), service-only table denial, `anon` rejection,
  and private-Realtime topic authorization (family membership, session
  participation, unlinked users and malformed topics).
- `40_functions.sql` — family creation, policy versioning/idempotency, command
  poll/ack/expiry, stale-session expiry, offline detection suppression, pairing
  approve/reject/expiry/replay, unlink/revoke side effects, app snapshot
  replacement, and denial of public RPC wrappers to authenticated users.
- `50_realtime_policy.sql` — the created policy exists and authorizes on the
  subscribed topic alone (no `extension` predicate; BUG-021), for family and
  session topics, while denying cross-family, non-participant and malformed
  topics. In the local stub the topic is a fixed setting, so an allowed topic
  admits every inserted row; the real Realtime server evaluates at channel join
  and delivers only that topic. This validates the policy DDL and topic gate, not
  hosted Realtime behavior.
- `55_pairing_invite_atomic.sql` — BUG-033, self-contained (own profiles and
  families): a repeated invite returns the live request instead of inserting;
  an expired `pending_child` row does not suppress a fresh invite (the case a
  partial unique index would have broken); a different parent gets their own
  request; `create_pairing_request` is idempotent for one triple, and replaying
  the same token for another triple raises `code_unavailable`; the invite token
  is `purpose='invite'`, `status='active'`, created by the parent and shares the
  request's `expires_at`.
- `run_pairing_invite_race.sh` — BUG-033 two-session lock proof described above;
  builds and drops its own database, so it is not part of the `psql -f` chain.
- `45_device_recovery.sql` — BUG-024: `public.request_device_recovery` is
  service-only; recovery unlinks the child and writes an audit row with no secret
  field; the child/parent authorization checks are enforced at the Edge Function
  layer (verified live). Runs last because it mutates the family1/child1 fixtures.

These tests cover database authorization and RPC behavior only. Edge Function
HTTP behavior is covered by the Deno tests noted in `docs/backend.md`; neither
suite validates a deployed project. The `realtime` schema here is a local stub,
not the hosted Realtime server.
