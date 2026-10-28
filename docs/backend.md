# Backend deployment and operations

**Status: DEPLOYED — hosted project verified for Auth, data, Edge Functions,
private Realtime, the parent-authorized device-recovery path and the permanent
Child ID / atomic-invite change set (2026-10-27).**
The app is built against hosted Supabase project `hhqgreaoqulmfwfwarhc`. Device
Owner enforcement, email delivery, FCM, TURN and hosted backups remain blocked,
not configured or unverified; [verification-report.md](verification-report.md)
records the exact claim behind every label.

## Hosted project record (2026-10-26)

| Item | State |
|---|---|
| Project | `hhqgreaoqulmfwfwarhc`, organization `spg7753@gmail.com's Org`, region `ap-northeast-2` (Seoul), PostgreSQL 17.11, compute NANO, dashboard status Healthy |
| Configuration method | Authenticated Supabase Dashboard only: SQL Editor migrations, Auth settings, dashboard function deployment. No CLI project mutation and no undocumented API were used. |
| Migrations | All **seven** files in `supabase/migrations/` applied in order through the SQL Editor: the first five on 2026-10-26, then `20260101000500_child_contact_ids.sql` and `20260101000600_atomic_pairing_invite.sql` on 2026-10-27. The final Realtime policy DDL returned `Success. No rows returned`; the fifth migration (`20260101000400_device_recovery.sql`) adds the parent-authorized `private.request_device_recovery` wrapper. |
| Auth | Email confirmation ON; signups ON; anonymous sign-ins OFF; manual linking OFF; Site URL `http://localhost:3000` (development value; change before a web release); redirect allowlist contains `parentcontrol://auth-callback`. QA parent/child accounts were created and dashboard-confirmed. |
| Edge Functions | All nine deployed from the dashboard: `auth-bootstrap`, `pairing`, `device-register`, `device-policy`, `family-admin`, `remote-session` with Verify JWT ON; `device-command`, `device-telemetry`, `cron` with Verify JWT OFF. `pairing` and `auth-bootstrap` were redeployed on 2026-10-27 with the Child ID / atomic-invite code; the deployed content checksums are recorded in [Production Child ID deployment](#production-child-id-deployment-2026-10-27). |
| Realtime | `parentcontrol_private_topics` policy present on `realtime.messages`. Live probe: the family's parent and child and the remote-session participant subscribe; a foreign parent and an anon client are rejected. |
| Edge secrets | `PAIRING_HASH_PEPPER` is set (HMAC proof below); its value was never displayed, copied or recorded. `TURN_URL`/`TURN_SECRET` and `CRON_SECRET` are absent, so TURN is not configured and the scheduled `cron` endpoint is not enabled. |
| Email delivery | No custom SMTP provider. Confirmation and reset email round-trips are **BLOCKED / NOT TESTED**. |
| FCM | **NOT CONFIGURED**: no Firebase project or `google-services.json`. |
| Backups | **NOT CONFIGURED (hosted) / LOCAL DRILL VERIFIED.** No hosted backup/PITR drill was performed (the current plan's Backups page was not exercised). A local PostgreSQL 16.9 dump → restore drill was performed and verified on 2026-10-27 (identical row counts); see [Backup and restore drill](#backup-and-restore-drill). |
| Client keys | The Flutter build contains `SUPABASE_URL` and the publishable key only. The service-role key and database password were never read, stored or printed by this work. |

## Production Child ID deployment (2026-10-27)

The owner directed that the existing project `hhqgreaoqulmfwfwarhc`
(`parent-control-prod`) be used and that no additional project be created. The
reviewed change set was therefore applied to production through the supported
dashboard workflow, not to a separate staging project. All steps below were
performed in the authenticated dashboard (SQL Editor, Edge Functions); no CLI
project mutation, management API or service-role key was used.

**Migrations applied** (SQL Editor, one file at a time, in this order):

| File | SHA-256 of the local file | Bytes | Applied |
|---|---|---|---|
| `20260101000500_child_contact_ids.sql` | `6d4b13e01cc4f49cdf31424d5334fdf1f389b484365e047094836671890c197f` | 2,846 | 2026-10-27 |
| `20260101000600_atomic_pairing_invite.sql` | `9bf7e2785d1348c7c748808dce73e2f4d9ea9bef47ba46688dece95abd923646` | 7,655 | 2026-10-27 |

Both files are additive: a new service-only `child_contact_ids` table, nullable
`pairing_requests.contact_id`, the `purpose` column on
`device_pairing_tokens`, and the two SECURITY DEFINER creation RPCs with their
`public.*` wrappers. No existing column, row or policy was dropped. A
`jsonb_pretty` verification query against the hosted schema returned:
`public_tables 19` (18 before), `rls_disabled []`,
`child_contact_ids_policies 0`, `child_contact_ids_anon_select false`,
`child_contact_ids_auth_select false`,
`child_contact_ids_service_insert true`, `purpose_default 'code'`,
`purpose_index 1`, and four `create_pairing_invite`/`create_pairing_request`
functions (public + private) each `secdef true`, `search_path` set, and
`anon`/`authenticated` EXECUTE false, `service_role` true. The seven-migration
chain had already been re-run locally from an empty database (`EXIT=0`,
0 ERROR/ASSERTION FAILED, 19 tables).

**Functions redeployed** from the dashboard Code tab, in this order (the
migration had to exist first):

| Function | Verify JWT | Local file SHA-256 (bytes) | Deployed content SHA-256 (characters) |
|---|---|---|---|
| `pairing` | ON | `ac4dcef28ad08ee74f0a5b42feea066ca24e5aef51fd88725b0605359954c0b6` (33,999) | `427d419d4f691cfbc50ccfbc63c500fdcb8f5838cbaa5105b4a58f8551424307` (33,993) |
| `auth-bootstrap` | ON | `f51a8112789ea35d07ce9e9b8fa058bdad6a289768991558a3fa04086d4bcc8c` (4,307) | `34cf673247a61a91dbeda77c14c06d01184aad7a0724b5f7eaeb9d2f85b7383b` (4,302) |

The deployed content is the local file with the dashboard's import rewrite
applied; the hash was recomputed over the rewritten source after the editor
saved it, and it matched the value that was uploaded. The six-character
difference is that rewrite, not a code change. Verify JWT was confirmed ON for
both functions after deployment; no other function was redeployed and no Auth
or gateway setting was changed.

**Secret.** `PAIRING_HASH_PEPPER` was configured before the live runs. The value
was never displayed, copied, logged or written to a file. Its effect is proved
behaviourally: every recent `pairing_attempts` row is a keyed digest, while only
four rows written before the deployment match a plain SHA-256 of the known
identifier (see the verification report). Rotating the pepper is safe for stored
tokens (token hashes are still plain SHA-256) and only resets the 10-minute
per-identifier failure window.

**Post-deploy health.** `pairing` answered `get_contact_id`, `invite`, `redeem`,
`respond`, `cancel` and `unlink` with the documented envelope; `auth-bootstrap`
issued roles at sign-in; the function error rate showed no `internal_error` in
the tested flows. The detailed live matrix, including negative and concurrency
cases, is in [verification-report.md](verification-report.md#production-live-checks-2026-10-27).

**Rollback.** The schema changes are additive and can stay if a function is
rolled back. Restoring the previous `pairing` function alone would make
`get_contact_id`/`invite` unavailable; that is the pre-Child-ID state, not a
working fallback for the current app. There is no automatic rollback and no
hosted backup/PITR was verified before the apply, so restoring the pre-deploy
state would depend on Supabase's own retention. Do not apply further DDL to this
project without first confirming a restore path.

## What remains owner-only

1. Custom SMTP (or a verified sending domain) plus one real confirmation/reset
   round-trip.
2. Firebase/FCM credentials and a delivery test.
3. TURN credentials for restrictive networks. ICE currently returns STUN-only
   with `turn_configured:false`.
4. Device Owner provisioning on a disposable device (factory reset) to exercise
   package suspension, including Instagram.
5. Backup and retention decisions, plus a **hosted** restore drill (the local
   procedure is verified; see [Backup and restore drill](#backup-and-restore-drill)).

Sections 3-7 below are the reproducible dashboard/CLI runbook for migrations,
functions, Realtime and secrets. Sections 4-5 were executed through the dashboard
in the state recorded above; the CLI forms are retained for recreation.

## Layout

```text
supabase/
  config.toml                         local CLI config + per-function verify_jwt
  migrations/
    20260101000000_core.sql           tables, constraints, triggers, RLS helpers
    20260101000100_functions.sql      private RPCs, service-only wrappers, realtime, cron
    20260101000200_rls.sql            RLS policies and grants
    20260101000300_service_role_grants.sql
                                      explicit server-role table/sequence privileges
    20260101000400_device_recovery.sql
                                      parent-authorized device-recovery wrapper (BUG-024)
  functions/
    _shared/                          cors, envelope, auth, validation, policy, audit,
                                      rate-limit, turn (server-only)
    auth-bootstrap/ pairing/ device-register/ device-command/ device-policy/
    device-telemetry/ family-admin/ remote-session/ cron/
  tests/                              plain-PostgreSQL SQL tests; see tests/README.md
```

The Flutter app owns `lib/` and `.env`; it must contain only the project URL and
the publishable (anon) key. The service-role key and all TURN/cron secrets must
never be shipped in the app, committed, or placed in `docs/`.

## 1. Prerequisites

- A Supabase project on PostgreSQL 15 or newer (hosted projects are typically
  PostgreSQL 17).
- Supabase CLI for hosted deployment (optional: SQL Editor can apply migrations).
- `psql` only for the optional plain-PostgreSQL test run.
- An app redirect/site URL for email confirmation links.
- A coturn server only if TURN relay is required.

## 2. Create the project and configure Auth (dashboard)

1. Create a project in the Supabase dashboard. Store the database password in a
   password manager; do not put it in this repository.
2. Authentication -> Providers -> Email: enable Email provider and **Confirm
   email**. Disable anonymous sign-ins.
3. Authentication -> URL Configuration: set the Site URL and add
   `parentcontrol://auth-callback` to the redirect allowlist. That exact value is
   defined in `lib/core/config/env.dart` (`Env.authRedirectUrl`) and in the
   Android manifest; a mismatch makes the confirmation link open the browser
   instead of returning a session to the app.
4. Project Settings -> API: note the Project URL and the publishable/anon key for
   the app. The `service_role` key is server-only and is injected into Edge
   Functions by Supabase; never copy it into Flutter.
5. Database -> Extensions: enable `pg_cron` if scheduled maintenance is wanted
   (optional; the migration guards its absence). Realtime is enabled by default.
6. Database -> Backups: confirm a backup/PITR policy exists before any migration.

## 3. Apply database migrations

### Option A: Supabase CLI (hosted, recommended)

```bash
supabase login
supabase link --project-ref <PROJECT_REF>
supabase db push
```

`db push` applies the seven files in timestamp order. It may prompt for the
database password. Do not use `supabase db reset` on a project with real data.
If `pg_cron` was not enabled yet, see [Cron](#7-cron) and schedule the jobs after
enabling it; the migration's guarded block runs only once.

`20260101000600_atomic_pairing_invite.sql` is required by the current Edge
Functions: `pairing` calls `public.create_pairing_invite` /
`public.create_pairing_request`. Deploy the migration **before** the functions,
and the functions **before** any Flutter build that contains the Child ID
screens. A new app against old functions shows a Child ID error; old functions
against the new schema keep working.

### Option B: Dashboard SQL Editor

Open SQL Editor, create a query, paste **one** file at a time, run it, and wait
for success before the next. Apply in this exact order:

1. `supabase/migrations/20260101000000_core.sql`
2. `supabase/migrations/20260101000100_functions.sql`
3. `supabase/migrations/20260101000200_rls.sql`
4. `supabase/migrations/20260101000300_service_role_grants.sql`
5. `supabase/migrations/20260101000400_device_recovery.sql`
6. `supabase/migrations/20260101000500_child_contact_ids.sql`
7. `supabase/migrations/20260101000600_atomic_pairing_invite.sql`

Never apply `supabase/tests/00_auth_stub.sql` to Supabase. It is local-test-only
scaffolding and would conflict with Supabase's real `auth` schema and roles.

### Option C: Direct psql

```bash
psql -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/migrations/20260101000400_device_recovery.sql \
  -f supabase/migrations/20260101000500_child_contact_ids.sql \
  -f supabase/migrations/20260101000600_atomic_pairing_invite.sql \
  -d "$SUPABASE_DB_URL"
```

Keep all options before the connection argument; Windows `psql` ignores options
placed after the database name and can exit 0 without applying anything.

### Post-migration verification (SQL Editor)

```sql
-- 19 tables (18 before 20260101000500), all with RLS enabled (relrowsecurity = true)
select relname, relrowsecurity
from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
order by relname;

-- service-only tables (device_pairing_tokens, safe_zone_states, pairing_attempts,
-- child_contact_ids) must have zero policies
select tablename, count(*) as policies
from pg_policies where schemaname = 'public'
group by tablename order by tablename;

-- partial unique indexes / constraints exist
select indexname from pg_indexes
where schemaname = 'public' and indexname like '%one_active%';

-- private RPCs are not callable by clients
select has_function_privilege('authenticated', 'private.create_family_with_owner(uuid,text)', 'execute');
-- expected: false

-- 20260101000600 applied: four functions, service-role only
select proname, prosecdef
from pg_proc
where proname in ('create_pairing_invite', 'create_pairing_request')
order by proname;
-- expected: four rows, all prosecdef = true
select has_function_privilege(
  'authenticated',
  'public.create_pairing_invite(uuid,uuid,uuid,text,timestamptz)',
  'execute');
-- expected: false
```

## 4. Edge Function secrets

Set these in Project Settings -> Edge Functions -> Secrets (dashboard) or with
the CLI. Use a secret manager; avoid putting values in shell history.

Create a local file such as `secrets.env` (gitignored) with `NAME=value` lines
for `CRON_SECRET`, optional `STUN_URL`, `TURN_URL`, `TURN_SECRET` and
`TURN_TTL_SECONDS`, then:

```bash
supabase secrets set --env-file secrets.env --project-ref <PROJECT_REF>
```

Do not pass secret values as CLI arguments; they would be retained in shell
history and process listings.

| Name | Required | Purpose |
|---|---|---|
| `SUPABASE_URL` | auto-injected | Project URL used by the server client. Set manually only for self-hosting. |
| `SUPABASE_SERVICE_ROLE_KEY` | auto-injected | Server client key. Bypasses RLS; server-only. Set manually only for self-hosting. |
| `CRON_SECRET` | yes, for `cron` | Shared secret for the scheduled HTTP function; minimum 16 characters. |
| `STUN_URL` | optional | Comma/space-separated STUN URLs. Default: `stun:stun.l.google.com:19302`. |
| `TURN_URL` | optional | Comma/space-separated `turn:`/`turns:` URLs. TURN needs both URL and secret. |
| `TURN_SECRET` | optional | coturn `static-auth-secret`; never returned to clients. |
| `TURN_TTL_SECONDS` | optional | Ephemeral TURN credential lifetime, clamped 60..86400; default 600. |
| `PAIRING_HASH_PEPPER` | optional, recommended | Key used for HMAC-SHA-256 of identifiers stored in `pairing_attempts`. When unset, the function falls back to plain SHA-256 and logs `pairing_hash_pepper_missing` once per isolate, so a database dump can brute-force the identifier (BUG-034). Set it before the first deploy: changing it later resets the per-identifier failure window (10 minutes) and nothing else. |

If `TURN_URL`/`TURN_SECRET` are absent, `remote-session` action `ice` returns
STUN-only with `turn_configured:false` and a warning. It never returns the TURN
secret, only HMAC-derived ephemeral credentials.

## 5. Deploy Edge Functions

Deploy after migrations, otherwise service-role queries fail. Deploy all:

```bash
supabase functions deploy --project-ref <PROJECT_REF> --use-api
```

`--use-api` bundles server-side and is required on this workstation because
Docker is not installed. If Docker is available, omit the flag.

Or deploy explicitly, preserving the JWT settings:

```bash
# Gateway-verified user JWT (verify_jwt = true)
supabase functions deploy auth-bootstrap --project-ref <PROJECT_REF>
supabase functions deploy pairing --project-ref <PROJECT_REF>
supabase functions deploy device-register --project-ref <PROJECT_REF>
supabase functions deploy device-policy --project-ref <PROJECT_REF>
supabase functions deploy family-admin --project-ref <PROJECT_REF>
supabase functions deploy remote-session --project-ref <PROJECT_REF>

# Self-authenticating endpoints (verify_jwt = false)
supabase functions deploy device-command --no-verify-jwt --project-ref <PROJECT_REF>
supabase functions deploy device-telemetry --no-verify-jwt --project-ref <PROJECT_REF>
supabase functions deploy cron --no-verify-jwt --project-ref <PROJECT_REF>
```

`supabase/config.toml` already declares the same settings. In the dashboard,
open each function and confirm **Verify JWT** is ON for the six user-auth
functions and OFF for `device-command`, `device-telemetry` and `cron`. Do not
turn verification off for the six user-auth functions.

The Child ID workflow needs the functions too, not only the migration. After
applying `20260101000500_child_contact_ids.sql` **and**
`20260101000600_atomic_pairing_invite.sql`, redeploy `pairing` (it serves
`get_contact_id` and `invite` and calls the new RPCs) and `auth-bootstrap` (it
assigns the ID at signup). Functions deployed against a database without those
objects make `get_contact_id` and every invite/redeem call fail with
`internal_error`; the migration without the functions leaves the Child ID
unavailable to the app.

No staging project exists: the only project reachable by this workstation's CLI
login is `irlqctcddjmkwqdvsdsm`, while the app targets `hhqgreaoqulmfwfwarhc`.
The owner directed on 2026-10-27 that the reviewed change set be deployed to that
existing production project and that no second project be created. The apply and
redeploy are recorded above; the Phase 4 and Phase 5 checks ran against it with
dedicated QA accounts.

If a staging project is created later, the same order applies: apply the seven
migrations first, set `PAIRING_HASH_PEPPER`, deploy `pairing` then
`auth-bootstrap`, and run the live matrix before pointing a build at it. A new
app against old functions shows a Child ID error; old functions against the new
schema keep working for the legacy code path.

Request shapes:

- User-auth functions: `Authorization: Bearer <user JWT>` plus
  `apikey: <publishable key>`. The functions still call `auth.getUser()` and
  re-check verified email, role and family membership.
- `device-command` (`poll`/`ack`) and `device-telemetry` (all actions): send
  `apikey` and `Authorization: Bearer <publishable key>` only to satisfy the
  gateway, plus `x-device-id` and `x-device-secret`. Identity comes only from the
  device headers. A publishable key or device id alone is not proof.
- `device-command` action `create`: a real user JWT (parent), because the gateway
  is not verifying it.
- `cron`: `x-cron-secret`, no user JWT.

Function URLs are
`https://<PROJECT_REF>.supabase.co/functions/v1/<function-name>`. A GET returns
405; every call is `POST` with a JSON body containing `action`.

## 6. Realtime

The functions migration adds `device_commands`, `safety_alerts`,
`remote_sessions` and `webrtc_signals` to `supabase_realtime` if the publication
exists. Verify:

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by schemaname, tablename;
```

If a table is missing, add only the missing ones (SQL Editor; adding an existing
table errors):

```sql
alter publication supabase_realtime add table public.device_commands;
alter publication supabase_realtime add table public.safety_alerts;
alter publication supabase_realtime add table public.remote_sessions;
alter publication supabase_realtime add table public.webrtc_signals;
```

Alternatively toggle the tables in Database -> Replication -> `supabase_realtime`.
RLS is enforced by Realtime; clients subscribe with `postgres_changes` on these
tables and must not use public broadcast/presence channels for signaling.

The Flutter app opens every channel with `private: true`. The RLS migration
creates `private.realtime_topic_allowed(text)` and, when `realtime.messages`
exists, a SELECT policy for `authenticated`:

```sql
select policyname, cmd, roles, qual
from pg_policies
where schemaname = 'realtime' and tablename = 'messages';
```

Channel authorization is topic-based. Do **not** add a predicate on
`realtime.messages.extension` (for example `= 'postgres_changes'`): a join is
authorized before any message row exists, so that predicate evaluates false and
rejects every subscriber, including legitimate family members (BUG-021). Record
delivery is still filtered by each source table's RLS.

Topic formats are `remote-session:<sessionId>`, `remote-session-family:<familyId>`,
`webrtc-signals:<sessionId>` and `safety-alerts:<familyId>` (a numeric suffix is
allowed). Family topics require active membership; session topics require being
the child participant or a parent in that session's family. If the migration
printed `realtime.messages not found`, Realtime was not initialised yet: enable it,
then create the policy (the helper already exists):

```sql
create policy parentcontrol_private_topics
  on realtime.messages
  for select
  to authenticated
  using (private.realtime_topic_allowed(realtime.topic()));
```

This topic-only policy is what the hosted project runs. A live probe on
2026-10-26 subscribed the family's parent and child and the session participant;
a foreign parent and an anonymous client were rejected.

## 7. Cron

If `pg_cron` was enabled before the functions migration, it created:

- `parentcontrol-expire-sessions` — every 5 minutes
- `parentcontrol-detect-offline` — every 10 minutes

Verify and inspect:

```sql
select jobid, jobname, schedule, command, active
from cron.job where jobname like 'parentcontrol-%' order by jobname;

select * from cron.job_run_details
order by start_time desc limit 20;
```

If the guarded block reported `pg_cron not installed`, enable the extension and
schedule the jobs manually (re-running `cron.schedule` with an existing jobname
can fail; check first):

```sql
select cron.schedule(
  'parentcontrol-expire-sessions', '*/5 * * * *',
  'select private.expire_stale_sessions()'
);
select cron.schedule(
  'parentcontrol-detect-offline', '*/10 * * * *',
  'select private.detect_offline_devices()'
);
```

If `pg_cron` is unavailable, either run the two statements manually as a
privileged role, or call the `cron` Edge Function from an external scheduler:

```bash
curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/cron" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <CRON_SECRET>" \
  --data '{"action":"expire_sessions"}'

curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/cron" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <CRON_SECRET>" \
  --data '{"action":"detect_offline"}'
```

Keep `CRON_SECRET` only in the scheduler's secret store. Rotate it if exposed;
the `cron` function is public at the gateway and relies solely on this secret.

## 8. TURN / coturn

1. Deploy coturn with TLS if `turns:` is used. Expose the UDP/TCP ports in the
   URL, and open them in the firewall/security group.
2. Configure coturn REST authentication:

   ```conf
   use-auth-secret
   static-auth-secret=<TURN_SECRET>
   realm=<turn.example.com>
   ```

   `static-auth-secret` must exactly equal the `TURN_SECRET` Edge secret.
3. Set `TURN_URL` to the same host/ports; optionally `STUN_URL` to your own STUN
   endpoint. `TURN_TTL_SECONDS` is clamped to 60..86400 (default 600).
4. The app obtains credentials only through `remote-session` action `ice` after
   child consent. Do not configure TURN credentials in Flutter or `.env`.

## Backup and restore drill

**Hosted project: NOT CONFIGURED / UNVERIFIED.** No backup/PITR policy was
confirmed and no hosted restore was performed; the Backups page was not
exercised. Do this through the dashboard (Database → Backups) with the owner
before relying on it, and prefer restoring into a throwaway project to prove the
restore rather than overwriting the live one.

**Local PostgreSQL: drill VERIFIED (2026-10-27).** A full dump → restore of the
disposable local database was performed and the restored data matched the source.
This proves the *procedure*, not the hosted project's backup state, and it does
not involve any hosted secret.

```bash
export PATH="$PWD/.tools/pgsql16/pgsql/bin:$PATH"
SRC=parentcontrol_final7_20261026
BASE=postgresql://postgres@127.0.0.1:55432

# Back up (custom format for pg_restore, plus a plain-SQL copy for reading)
pg_dump -Fc -f .tools/backup_drill/parentcontrol_final7.dump "$BASE/$SRC"
pg_dump    -f .tools/backup_drill/parentcontrol_final7.sql  "$BASE/$SRC"

# Restore into a fresh, separate database (never overwrite the source)
createdb "$BASE/parentcontrol_restore_drill_20261027"
pg_restore -d "$BASE/parentcontrol_restore_drill_20261027" \
  .tools/backup_drill/parentcontrol_final7.dump
```

Observed: the restored database has the same 18 public tables and identical row
counts to the source (profiles 7, families 2, devices 6, pairing_requests 5).
Dumps live under `.tools/backup_drill/` (gitignored). The local database holds
only fixed-UUID test fixtures — no real user data and no secret — so the dump
itself is not sensitive; it must still never be committed.

There are **no down migrations**. A schema rollback is a reviewed, manual
operation; take a backup/snapshot first and prefer restoring the project to the
pre-deployment backup for a full revert.

Order for a manual rollback:

1. Stop external cron invocations and unschedule jobs:
   `select cron.unschedule('parentcontrol-expire-sessions');` and the
   `parentcontrol-detect-offline` job (skip if `pg_cron` is absent).
2. Roll back Edge Functions first: redeploy the previous commit with
   `supabase functions deploy --project-ref <PROJECT_REF>` or delete the new
   functions in Dashboard -> Edge Functions.
3. Remove Realtime tables if they were added:
   `alter publication supabase_realtime drop table public.webrtc_signals;` etc.
   (Skipping this is harmless if the tables are dropped next.)
4. Restore the database from the pre-deployment backup, or apply a reviewed
   reverse-order SQL script that drops, in this order: public RPC wrappers,
   private RPCs/helpers and the `private` schema, RLS policies/grants, then the 18
   tables. Never drop the `auth` schema or `auth.users`; profiles cascade from
   `auth.users`.
5. Remove `TURN_*`, `STUN_URL` and `CRON_SECRET` secrets only if no deployed code
   uses them. Deleting a secret is not a data rollback.

Test-only objects from `supabase/tests/` must never exist in a hosted project.

## 10. Security notes

- RLS is enabled on every public table (18 before `20260101000500`, 19 with
  `child_contact_ids`). The 15 client-visible tables only expose policies to
  `authenticated`; the service-only tables (`device_pairing_tokens`,
  `safe_zone_states`, `pairing_attempts`, `child_contact_ids`) have no client
  policies and no client grants. Service-role access bypasses RLS by design.
- `private.is_family_member`, `is_family_parent`, `shares_active_family` and
  `realtime_topic_allowed` are `SECURITY DEFINER` with
  `search_path = public, private, pg_temp`; RLS and Realtime predicates require
  `authenticated` to execute them. All state-changing private RPCs and service
  wrappers are service-role only.
- Device credentials are SHA-256 hashes compared in constant time. Raw device
  secrets are never stored or returned by profile/device APIs. Revoked
  credentials, `status != 'active'` and `credential_revoked_at` are rejected.
  `authenticated` has column-level SELECT on `devices`; `secret_hash` and
  `installation_id` are not readable by clients.
- A revoked device blocks any replacement enrollment for that child in the same
  family until a parent removes the child and a later pairing request is approved
  (revocation timestamp vs. `pairing_requests.responded_at`). Blocked attempts are
  audited as `device_registration_blocked`. The child cannot clear a revocation.
- After app data loss a child can no longer present its old credential. The only
  supported recovery is parent-authorized: `family-admin` action `recover_device`
  calls the `SECURITY DEFINER` `private.request_device_recovery(device_id,
  actor_user_id)`, which reuses `private.unlink_child` and writes an audit row
  with no secret/token/plaintext field. Recovery still requires the child to
  complete a fresh pairing, so the child alone cannot restore access.
- Devices cannot read other devices, commands, telemetry or audit rows; parents
  cannot cross family boundaries. Pairing codes are high-entropy, hashed,
  short-lived, rate-limited and never searchable.
- `devices.policy_version` advances only from a successful `apply_policy`
  acknowledgement using the server-side policy row. Heartbeats cannot set it, so
  a device cannot claim policy enforcement through telemetry.
- Audit logs are append-only for clients; Edge Functions log only error codes,
  never request bodies, headers, tokens or secrets.
- CORS uses `Access-Control-Allow-Origin: *` with an explicit header allowlist.
  Authentication/authorization is still required; no cookie credentials are used.
- Keep the service-role key, `TURN_SECRET`, `CRON_SECRET` and database password
  server-side. Rotate any leaked key; rotating the service-role key requires
  updating the Supabase-injected value.
- `webrtc_signals` payloads are capped at 16 KiB by a table check; Edge Function
  bodies are capped at 512 KiB. TURN credentials are ephemeral and participant
  scoped.

### Permanent Child ID store (`20260101000500_child_contact_ids.sql`)

The migration is purely additive: it creates one table, adds one column and one
index, and no existing row, relationship or token is rewritten.

- `public.child_contact_ids` — `child_user_id uuid primary key references
  profiles(id) on delete cascade`, `contact_id text not null unique check
  (contact_id ~ '^PC[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$')`, `created_at
  timestamptz not null default now()`, `rotated_at timestamptz`. The column
  comment records that the value is assigned once and never regenerated on
  launch.
- **No RLS policy is exposed.** The table has RLS enabled, `revoke all ... from
  public, anon, authenticated`, and select/insert/update/delete granted to
  `service_role` only. That means there is no PostgREST read path for any client,
  not even the owning child; the value reaches the app only through
  `pairing.get_contact_id`. Treat any future policy on this table as a contract
  change, not a convenience.
- `device_pairing_tokens.purpose text not null default 'code' check (purpose in
  ('code','invite'))` separates a child-minted 10-minute secret from a
  server-minted 24-hour invite token. Existing rows keep `purpose='code'`. The
  index `device_pairing_tokens_child_purpose_idx (child_user_id, purpose,
  status)` supports both the mint and quota queries.
- Edge Function `pairing`: `get_contact_id` (child JWT) assigns on first call and
  is idempotent, re-reading after a `23505` so concurrent calls converge on one
  row; `invite` (parent JWT, active parent of the family) normalizes and looks up
  the ID, requires the target profile role to be `child`, returns 409
  `child_already_linked` for a linked child, returns an existing live
  `pending_child` request for the same child and family instead of duplicating,
  then enforces quota, mints the `purpose='invite'` token server-side, inserts
  the request and returns the same payload as `redeem`. `redeem` accepts either
  an 8-character code or a Child ID and returns one identical `invalid_code`
  message for every unusable input. `create` now tags `purpose='code'`, revokes
  only code tokens and cancels only the requests whose tokens it replaced.
  `respond_pairing_request` is unchanged: the child's approval is still what
  creates and activates the membership and redeems the token.
- `auth-bootstrap` `set_role('child')` assigns an ID best-effort when the child
  role is first set. The write is non-fatal on failure; `get_contact_id` assigns
  lazily for accounts created before this migration.
- Audit: `pairing_invited` on `pairing_request` with `{child_user_id,
  via:"child_id"}`. The Child ID is deliberately **not** written into
  `audit_logs.metadata`, because family parents can read that log; `via`
  identifies the flow without leaking the identifier.
- Limits (`_shared/rate_limit.ts`): 5 failed lookups per parent per 10 minutes
  (successes no longer count), 10 failed lookups per identifier, 5 live `code`
  tokens per child per 24h, 10 code creations per child per rolling hour, 3
  pending invites per child and 10 invites per child per 24h. The `invite` action
  and a Child ID `redeem` share the same counters. 429 responses carry
  `details.retry_after_seconds`.
- The Child ID is an identifier, not a credential. It lets an already-authorized
  parent in that family open a request; the child approves on their own device,
  and RLS, family membership and device credentials remain the authorization
  sources.

```sql
-- expect relrowsecurity = true, 0 policies and no anon/authenticated privileges
select relname, relrowsecurity from pg_class
where relname = 'child_contact_ids';
select count(*) from pg_policies
where schemaname = 'public' and tablename = 'child_contact_ids';       -- 0
select has_table_privilege('authenticated', 'public.child_contact_ids', 'select'); -- false
```

## 11. Contract deviations (reported)

These are intentional, code-commented deviations; the owner should accept or
request changes:

1. **Service-only public RPC wrappers.** The contract says private RPCs are
   revoked from `anon, authenticated`; PostgREST does not expose the `private`
   schema, so `public.*` wrappers call them and are granted only to
   `service_role` (`supabase/migrations/20260101000100_functions.sql`,
   wrapper definitions and grants near lines 697-892).
2. **RLS helper grants.** `authenticated` may execute the four boolean helpers
   above because PostgreSQL evaluates RLS and Realtime policy expressions as the
   caller (`20260101000000_core.sql`, around lines 626-639; `20260101000200_rls.sql`,
   Realtime authorization section). State-changing functions remain revoked.
3. **`webrtc_signals` SELECT scope.** Participants can select all signals in
   their own live session; INSERT still requires `from_user_id = auth.uid()`
   (`20260101000200_rls.sql`, around lines 196-226). Applying the contract's
   `from_user_id = auth.uid()` to SELECT literally would hide the remote party's
   signals and break WebRTC.
4. **Expired redeem response.** `pairing.redeem` returns `400 invalid_code` for
   unknown and expired codes to avoid enumeration, not `410 code_expired`
   (`supabase/functions/pairing/index.ts`, around lines 304-318). The contract
   mentions both 400 and 410 for this case.
5. **Additive pairing fields.** Pairing responses keep the contract's flat
   `family_name`/`parent_display_name`/`child_display_name` and also include
   nested `families`/`parent_profile`/`child_profile` objects for the existing
   Flutter wire model (`supabase/functions/pairing/index.ts`, around lines
   105-150).

## Local checks

These commands were run locally by the implementation lead on 2026-10-26 and
re-run on 2026-10-27. They are independent of the hosted project and do not by
themselves prove its state; the hosted run is recorded in
[verification-report.md](verification-report.md).

```bash
deno check supabase/functions/auth-bootstrap/index.ts \
  supabase/functions/pairing/index.ts \
  supabase/functions/device-register/index.ts \
  supabase/functions/device-command/index.ts \
  supabase/functions/device-policy/index.ts \
  supabase/functions/device-telemetry/index.ts \
  supabase/functions/family-admin/index.ts \
  supabase/functions/remote-session/index.ts \
  supabase/functions/cron/index.ts
# Result: exit 0; all nine entrypoints type-checked (PASS — LOCAL VERIFIED).

deno test supabase/functions/_shared/
# Result: 36 passed, 0 failed (PASS — LOCAL VERIFIED, 2026-10-27).
# Includes the four identifierHash HMAC cases added for BUG-034.
```

The migrations and SQL authorization tests were executed against a **fresh,
disposable local PostgreSQL 16.9** database (`parentcontrol_final7_20261026`) on
`127.0.0.1:55432`, with the four migrations present at that time and the
corrected command in `supabase/tests/README.md` (`ON_ERROR_STOP=1`):

```text
SQL_EXIT=0; 0 ERROR / ASSERTION FAILED lines; 18 public tables;
realtime policy created=1.
This run includes the device column-grant assertions, the
private.realtime_topic_allowed checks, the topic-only realtime.messages policy
(tests updated after BUG-021), the narrowed private.revoke_device response
(BUG-026), and the actual policy DDL via the local 05_realtime_stub.sql
stand-in. (PASS — LOCAL VERIFIED, plain PostgreSQL only, not a Supabase
project).
```

The Realtime stub is local test scaffolding, not the hosted Realtime server. A
real private-channel subscription was exercised against the hosted project on
2026-10-26 (family parent/child and remote-session participant accepted; foreign
parent and anonymous client rejected — see the hosted record below); only the
SQL suite uses the stub. The hosted Realtime server has not been re-tested since
2026-10-28.

The fifth migration (`20260101000400_device_recovery.sql`, BUG-024) was authored
after that four-migration run and **was re-run on 2026-10-27** on a fresh local
database (`parentcontrol_full_20261027`) together with
`supabase/tests/45_device_recovery.sql`: psql `EXIT=0`, 0 ERROR/ASSERTION FAILED
lines, 18 public tables, and `authenticated` cannot execute
`request_device_recovery`. Log: `.tools/sql-tests-20261027.log` (gitignored). Its
authorization behavior was also verified **live** against the hosted project (see
the device-recovery bullet in the hosted verification record below and
`supabase/functions/_shared/*_test.ts` for the pure logic).

After the BUG-033/BUG-034 fixes the **full seven-migration chain** and every test
file, including `supabase/tests/55_pairing_invite_atomic.sql`, were re-run from
an empty local database on 2026-10-27: `EXIT=0`, 0 ERROR/ASSERTION FAILED lines,
19 public tables, Realtime policy present. The two-session advisory-lock test
then passed separately (session B blocked 3,404 ms, one live row). Logs:
`.tools/sql_rerun_185456.log` and `supabase/tests/run_pairing_invite_race.sh`
(gitignored).

The originally documented form put the connection string before the options. On
Windows `psql` 16.9 that silently ignored every file and still exited 0; see
BUG-015. All options now precede `-d "$DATABASE_URL"`.

Still not verified by the local run alone: hosted Auth, hosted Realtime,
pg_cron scheduling, email delivery, TURN relay behavior, FCM delivery, device
registration against a deployed backend, and HTTP behavior of the Edge
Functions. Those were tested separately against the hosted project; see
[verification-report.md](verification-report.md) for the result of each. A local
database run does not prove that a deployed Supabase project has the same
migration state, secrets or realtime publication.

## Hosted verification record (2026-10-26)

Everything below was executed against `hhqgreaoqulmfwfwarhc` through the
dashboard (SQL Editor, Auth, Edge Functions) or through the deployed HTTP
endpoints with publishable-key user sessions. No service-role key or database
password was used.

- **Schema**: five migrations applied in order; `Success. No rows returned` for
  each. `private.revoke_device` was later replaced once to strip service-only
  columns (`installation_id`, `secret_hash`) from the parent-facing response;
  the replacement and the follow-up check both succeeded.
- **Auth**: two QA families signed in; parent/child roles came from
  `profiles`/`family_members`, never from client-supplied metadata. Email
  confirmation is enabled, so programmatic signups were confirmed through the
  dashboard instead of an email round-trip.
- **RLS / grants**: cross-family reads and writes were denied; a child could not
  self-promote; an unlinked or revoked device could not authenticate telemetry.
  The unlinked path was exercised directly: after a parent removed the child,
  registration returned `403 forbidden`, the old credential returned `401
  invalid_device_credentials`, and the device row was `revoked`.
- **Pairing**: create/redeem/approve/expire/revoke/unlink/re-link were exercised;
  replay and expired codes were rejected; code creation hit its documented
  5-per-24h limit and was not raised to bypass it.
- **Functions**: all nine entrypoints responded with the documented envelope;
  `remote-session` returned STUN-only ICE with `turn_configured:false`.
- **Realtime**: private topics accepted the family's parent/child and the
  remote-session participant, and rejected a foreign parent and an anonymous
  client.
- **Device**: a real Android phone enrolled through the app, sent heartbeats and
  telemetry, acknowledged a benign policy v1, rejected a blocking policy v2 with
  a Device Owner error, and did not advance `devices.policy_version` on failure.
  The device credential was then revoked and its telemetry path re-tested.
- **Device recovery (BUG-024)**: the parent-authorized recovery path was exercised
  live (31 checks, 29 PASS + 2 setup INFO). A child role, a foreign parent, an
  unknown/malformed device and a replayed old credential were all denied; the
  recovery requires the parent to authorize it and then the child to approve a
  fresh pairing; the audit row carries no secret field; the replacement device is
  distinct and the old credential stays revoked. Results:
  `.tools/live/results/recover_device.json`.

Not exercised in the hosted project: custom SMTP delivery, FCM, TURN relay,
pg_cron schedules, backup/restore. See the owner-only list at the top.

## Hosted verification record (2026-10-27)

Executed against `hhqgreaoqulmfwfwarhc` with dedicated QA parent/child accounts
and publishable-key sessions. No service-role key, database password or TURN/cron
secret was read, stored or printed. Live Child IDs are shown truncated
(`PC-94EA…`); the full values remain in the gitignored Phase 5 device evidence,
because a live ID can still start a pending invite for the linked QA child.

- **Schema**: both new migrations applied; `jsonb_pretty` verification returned
  `public_tables 19`, `rls_disabled []`, zero policies on `child_contact_ids`, no
  `anon`/`authenticated` SELECT on it, `service_role` INSERT present, the
  `purpose` column defaulting to `'code'` with its index, and the four creation
  functions SECURITY DEFINER + service-only. Details in
  [Production Child ID deployment](#production-child-id-deployment-2026-10-27).
- **Stable Child ID**: `get_contact_id` returned the same ID on repeated calls
  (`PC-94EA…`, canonical `PC94EA…`) and a different, new ID for a second
  child (`PC-9GYF…`) without creating a second account for either.
- **Invite and consent**: a parent submitted the ID and received a
  `pending_child` request; the child saw the request and had to approve it
  before any membership existed. No device, camera, microphone or recording
  access follows from knowing the ID.
- **Negative paths**: a malformed ID and a well-formed unknown ID returned the
  same `400 invalid_code` body; a child role could not invite
  (`403 role_required`); an unauthenticated call was rejected; a parent from
  another family got the same `400 invalid_code` for an already-linked child,
  while the child's own family got `409 child_already_linked`; six failed
  lookups ended in `429 rate_limited` with `retry_after_seconds: 600`.
- **Replay**: a legacy code replayed by a second parent returned
  `409 code_unavailable`; the same parent's replay returned `200` with the same
  request id; the request was then cancelled.
- **Concurrency**: six parallel invites produced one unique request id; the
  database showed no duplicate live pending rows.
- **Unlink / relink**: unlink removed the membership and left the Child ID
  unchanged; the same ID started a new request; after approval and device
  re-registration the parent saw the phone again.
- **Audit**: six pairing/device event types in a 4-hour window had no Child ID,
  contact ID or hash in metadata; `leaky = 0` for every type.
- **Pepper**: 31 attempts in the run window were keyed 64-hex digests; only four
  pre-deployment rows matched a plain SHA-256. See
  [verification-report.md](verification-report.md#bug-033--bug-034-hardening-2026-10-27).
- **Two-device journey**: parent on the emulator, child on the physical
  RMX2161; child ID displayed, parent invite, child approval, device visible to
  the parent, unlink and relink, offline handling, force-stop session restore and
  parent account switching all ran on the hosted project. Results and residual
  gaps are in
  [verification-report.md](verification-report.md#two-device-journey-phase-5-2026-10-27).

## Device behaviour after relink (2026-10-28, no config change)

The unlink/relink journey was repeated on the same hosted project without
changing any migration, secret or function. Two server-visible behaviours were
recorded and are app-side defects, not backend misconfiguration:

- **Re-credentialing keeps the device row.** An unlinked device that registers
  again with the same `installation_id` updates the existing `devices` row and
  gets a new credential; the parent then sees the same row active again. No
  duplicate row is created for the same installation.
- **Policy is not inherited.** The re-credentialed row kept `policy_version 0`
  and no `device_policies` row, so the parent showed `No policy applied yet` and
  the child showed `No rules downloaded`. Policies are keyed by device id and
  re-registration does not copy the previous installation's policy.
- **Heartbeat gap.** After re-registration the server did not receive a
  heartbeat for five minutes (`last_seen` stayed at 08:33) even though the child
  service was foreground; a cold app restart produced an immediate heartbeat.
  See BUG-039 in [bug-report.md](bug-report.md); the cause is on the device side
  and was not isolated.

### Recreating the hosted setup later

If the project has to be rebuilt, follow sections 2-7 in order. The dashboard is
the authoritative path; the CLI forms are kept for local automation. Do not use
`scripts/complete_hosted_setup.sh` against the existing project: it creates a
new project and would duplicate the deployment. Its `--create` path is only for
a deliberate rebuild in a fresh organization.
