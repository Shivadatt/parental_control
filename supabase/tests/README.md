# SQL authorization tests

These tests exercise the schema, RLS policies, grants and internal RPCs against a
**plain PostgreSQL 15+** database. They do **not** use a Supabase project. They
were executed on 2026-10-26 against a fresh disposable PostgreSQL 16.9 database
and passed (psql `EXIT=0` with `ON_ERROR_STOP=1`, no `ERROR` and no
`ASSERTION FAILED` in the log); that run does not verify any Supabase-hosted
behavior.

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
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -d "$DATABASE_URL"
```

`50_realtime_policy.sql` runs before `40_functions.sql` because the latter unlinks
a fixture child used by the policy test.

Keep every option before the connection argument. On Windows, PostgreSQL
16.9 `psql` does not permute arguments: options placed after the database name
are reported as "extra command-line argument ... ignored" and the command can
still exit 0 without executing a single file. Treat a run as valid only if the
log shows SQL activity and the database ends with 18 public tables.

`$DATABASE_URL` is your own local connection string; no credential value is
stored in this repository. Example shape only:
`postgresql://postgres:<password>@127.0.0.1:5432/parentcontrol_test`.

Any failure raises `ASSERTION FAILED: ...` (or an unexpected SQL error) and
`ON_ERROR_STOP=1` makes `psql` exit non-zero. A silent run with no output is not
proof of success; check the exit status.

## Coverage

- `00_auth_stub.sql` — local roles, `auth.users`, `auth.uid/role`, assertion
  helpers `tests.assert_true`, `tests.expect_error`, `tests.put/get`,
  `tests.fk_columns`.
- `05_realtime_stub.sql` — local-only stand-in for Supabase's `realtime.messages`
  and `realtime.topic()`, so the actual private-channel policy DDL is created
  and can be exercised. It does not emulate the Realtime server.
- `10_schema.sql` — all 18 tables exist with RLS enabled; service-only tables have
  no policies; client tables only grant policy access to `authenticated`; FK
  columns to `profiles`/`auth.users`; expected triggers, partial unique indexes
  and unique constraints; `anon` has no table privileges; column-level grants
  (e.g. `profiles.role` is not client-writable, `devices.secret_hash` and
  `devices.installation_id` are never client-readable); private state-changing
  RPCs are not executable by clients (the four boolean policy helpers are the
  documented exception); public RPC wrappers are service-role only.
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
- `50_realtime_policy.sql` — the created policy exists, accepts only
  `extension = 'postgres_changes'`, and authorizes family/session topics for the
  right members while denying cross-family, non-participant and malformed
  topics. Realtime evaluates the policy for the subscribed topic, so a direct
  SELECT admits every `postgres_changes` row when the topic is allowed; the
  internal queue is never delivered to clients. This validates the policy DDL
  and topic gate, not hosted Realtime behavior.

These tests cover database authorization and RPC behavior only. Edge Function
HTTP behavior is covered by the Deno tests noted in `docs/backend.md`; neither
suite validates a deployed project. The `realtime` schema here is a local stub,
not the hosted Realtime server.
