# SQL authorization tests

These tests exercise the schema, RLS policies, grants and internal RPCs against a
**plain PostgreSQL 15+** database. They do **not** use a Supabase project. The
suite was re-run on 2026-10-29 against a fresh disposable PostgreSQL 16 database
with **all ten migrations** (through
`20261028000300_signaling_open_session.sql`) and every test file, including
`62_signaling_consented_session.sql`,
`61_parent_controlled_lifetime.sql`, `60_remote_session_concurrency.sql`
and `45_device_recovery.sql` (the latter last), and passed (psql `EXIT=0` with
`ON_ERROR_STOP=1`, no `ERROR` and no `ASSERTION FAILED` in the log; 19 public
tables, realtime policy present). The 2026-10-28 run covered the nine migrations
present at that time. An earlier 2026-10-27 run covered the seven migrations
present then, and a separate two-session run, `run_pairing_invite_race.sh`,
passed against a disposable database (see below). No run verifies any
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
  -f supabase/migrations/20261028000100_remote_session_concurrency.sql \
  -f supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql \
  -f supabase/migrations/20261028000300_signaling_open_session.sql \
  -f supabase/migrations/20261030000100_abandoned_session_sweep.sql \
  -f supabase/migrations/20261030000200_phase1_authorization.sql \
  -f supabase/migrations/20261030000300_retention_sweep.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -f supabase/tests/55_pairing_invite_atomic.sql \
  -f supabase/tests/60_remote_session_concurrency.sql \
  -f supabase/tests/61_parent_controlled_lifetime.sql \
  -f supabase/tests/62_signaling_consented_session.sql \
  -f supabase/tests/63_abandoned_session_sweep.sql \
  -f supabase/tests/70_phase1_authorization.sql \
  -f supabase/tests/72_retention_sweep.sql \
  -f supabase/tests/45_device_recovery.sql \
  -d "$DATABASE_URL"
```

`50_realtime_policy.sql` runs before `40_functions.sql` because the latter unlinks
a fixture child used by the policy test. `55_pairing_invite_atomic.sql` is
self-contained (it inserts its own `auth.users`/profiles/families with fresh
UUIDs), so it runs before `45_device_recovery.sql`. `45_device_recovery.sql`
mutates the family1/child1 fixtures, so it runs **last**.

`20261028000100_remote_session_concurrency.sql`,
`20261028000200_parent_controlled_session_lifetime.sql`,
`20261028000300_signaling_open_session.sql`,
`60_remote_session_concurrency.sql`,
`61_parent_controlled_lifetime.sql` and
`62_signaling_consented_session.sql` were appended after the 2026-10-27 run
recorded earlier; the command above now applies all ten migrations and every
test file. The new tests are self-contained and run before
`45_device_recovery.sql`.

`20260101000500_child_contact_ids.sql` and
`20260101000600_atomic_pairing_invite.sql` were appended after the earliest run
recorded above. `10_schema.sql` also asserts that `child_contact_ids` exists with RLS
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

## Two-session race test (R07: remote-session guard)

`60_remote_session_concurrency.sql` shows the read-then-insert logic but not the
lock. `run_remote_session_race.sh` builds a disposable database, opens session A
in one transaction (`request_remote_session` for one active fixture device + 4 s
sleep, holding `pg_advisory_xact_lock`), starts session B ~0.7 s later for the
same device, and fails unless B blocked for at least 2.5 s, was rejected with
`session_in_progress`, and the device ended with exactly one session row and no
device anywhere holds two open sessions. Run it from the repository root:

```bash
bash supabase/tests/run_remote_session_race.sh
KEEP_DB=1 bash supabase/tests/run_remote_session_race.sh   # keep the DB
```

Same connection defaults and `PATH` setup as the pairing race; the disposable
`parentcontrol_session_race_<timestamp>` database is dropped unless `KEEP_DB=1`.

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
  poll/ack/expiry, pending-request expiry (a consented session with a past
  deadline must survive), offline detection suppression, pairing
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
- `60_remote_session_concurrency.sql` — per-device remote-session guard:
  `public.request_remote_session` inserts a `requested` row, rejects a second
  call for the same device with `session_in_progress` (leaving the live row
  untouched), allows a different device, expires a stale `requested` row in-lock
  so it cannot block a new request while keeping it as history, and is executable
  only by `service_role` (`anon`/`authenticated` direct calls raise 42501).
- `61_parent_controlled_lifetime.sql` — parent-controlled session lifetime:
  `expires_at` is nullable but a `requested` row still requires a deadline
  (check constraint); the cleanup job expires stale pending requests only; an
  accepted session with no deadline, a consenting active session carrying a
  legacy past deadline, and a three-day-old active session all survive cleanup;
  the legacy active row blocks a new request with `session_in_progress` instead
  of being ended; accepting a request may clear the deadline; and terminal rows
  cannot be revived (`session_terminal`).
- `62_signaling_consented_session.sql` — signaling for a consented session with
  no deadline (migration `20261028000300`), self-contained (own profiles and
  families): a participating parent inserts an offer and the child reads it and
  inserts an answer on a session whose `expires_at` is NULL; an `active` session
  carrying a legacy past deadline still carries signals; a `requested` session
  and an `ended` session (even before its signals are cleared) reject inserts
  and expose no rows; ending the session closes signaling; and a non-participant
  can neither read nor write.
- `run_remote_session_race.sh` — R07 two-session proof that the same function
  serialises concurrent callers per device; builds and drops its own database,
  so it is not part of the `psql -f` chain.
- `63_abandoned_session_sweep.sql` — migration `20261030000100`:
  `expire_abandoned_sessions()` closes consented rows older than the bound with
  `ended_reason='abandoned'` and `ended_by IS NULL`, writes one `session_expired`
  audit row per session, leaves pending requests to the existing expiry job, and
  is executable only by `service_role`.
- `70_phase1_authorization.sql` — migration `20261030000200`: the
  `is_parent_of_family` truth table, rejection (`42501 not_family_parent`) of a
  non-parent actor by `request_remote_session`/`revoke_device`/`unlink_child`/
  `apply_policy_version`, absence of the `safe_zones` DELETE policy and grant,
  and `anon`/`authenticated` inability to execute the two private helpers.
- `72_retention_sweep.sql` — migration `20261030000300`:
  `run_retention_sweep()` deletes only rows outside the configured windows,
  returns counts, and is service-role only.

These tests cover database authorization and RPC behavior only. Edge Function
HTTP behavior is covered by the Deno tests noted in `docs/backend.md`; neither
suite validates a deployed project. The `realtime` schema here is a local stub,
not the hosted Realtime server.
