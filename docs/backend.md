# Backend deployment and operations

**Status: NOT DEPLOYED.** The backend source is complete in this repository, but
no Supabase project was created, linked, migrated or deployed; no secret was set;
no Edge Function, database or Realtime endpoint was called. Everything below is
a manual runbook for the owner/lead. Commands are documented, not executed.

Local verification covers the Deno commands and the SQL authorization suite against
a disposable plain PostgreSQL 16 database; see [Local checks](#local-checks). No
Supabase-hosted component has been exercised.

## Current blocker and owner handoff (2026-10-26)

The dashboard session shown by the owner (`spg7753@gmail.com's Org`, 0 projects)
and the authenticated Supabase CLI session (`anvikinnovations-cmyk's Org`, which
contains one unrelated pre-existing project, `irlqctcddjmkwqdvsdsm`) are different
accounts. Browser automation was denied, and creating a project through the CLI
with an agent-generated database password was blocked by the security gate.
Nothing hosted was created, linked, altered or deployed.

To unblock, the owner must choose one path:

1. In the dashboard for the intended account, create a free project named
   `parent-control` in `ap-south-1` (Mumbai), let the dashboard generate the
   database password, and store it in a password manager. Provide only the
   project ref/URL and the publishable/anon key. Keep the database password out
   of chat and run the `supabase link` / `supabase db push` commands locally.
2. Or explicitly authorize deploying into the existing project
   `irlqctcddjmkwqdvsdsm`, after confirming it holds no production data.

The app cannot pass its configuration gate until one of these is done. After the
project exists, the remaining sequence is:

```bash
# The owner enters the database password locally when prompted; never paste it
# into chat or a committed file.
supabase link --project-ref <PROJECT_REF>
supabase db push

# Local, gitignored file with CRON_SECRET and optional STUN_URL/TURN_* values.
supabase secrets set --env-file <LOCAL_SECRETS_ENV> --project-ref <PROJECT_REF>

supabase functions deploy auth-bootstrap pairing device-register device-policy \
  family-admin remote-session --project-ref <PROJECT_REF> --use-api
supabase functions deploy device-command device-telemetry cron \
  --no-verify-jwt --project-ref <PROJECT_REF> --use-api

"C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter.bat" build apk --debug \
  --dart-define=SUPABASE_URL=<SUPABASE_URL> \
  --dart-define=SUPABASE_ANON_KEY=<PUBLISHABLE_KEY>
```

For live testing, create two pre-confirmed test accounts (parent and child) in
Authentication -> Users, or confirm real email addresses. Do not disable email
confirmation in a production project. One physical phone is connected; a second
Android device or emulator is required for the two-role pairing and WebRTC
matrix. Sections 3-7 below give the full details and verification queries.

## Layout

```text
supabase/
  config.toml                         local CLI config + per-function verify_jwt
  migrations/
    20260101000000_core.sql           tables, constraints, triggers, RLS helpers
    20260101000100_functions.sql      private RPCs, service-only wrappers, realtime, cron
    20260101000200_rls.sql            RLS policies and grants
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

`db push` applies the three files in timestamp order. It may prompt for the
database password. Do not use `supabase db reset` on a project with real data.
If `pg_cron` was not enabled yet, see [Cron](#7-cron) and schedule the jobs after
enabling it; the migration's guarded block runs only once.

### Option B: Dashboard SQL Editor

Open SQL Editor, create a query, paste **one** file at a time, run it, and wait
for success before the next. Apply in this exact order:

1. `supabase/migrations/20260101000000_core.sql`
2. `supabase/migrations/20260101000100_functions.sql`
3. `supabase/migrations/20260101000200_rls.sql`

Never apply `supabase/tests/00_auth_stub.sql` to Supabase. It is local-test-only
scaffolding and would conflict with Supabase's real `auth` schema and roles.

### Option C: Direct psql

```bash
psql -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -d "$SUPABASE_DB_URL"
```

Keep all options before the connection argument; Windows `psql` ignores options
placed after the database name and can exit 0 without applying anything.

### Post-migration verification (SQL Editor)

```sql
-- 18 tables, all with RLS enabled (relrowsecurity = true)
select relname, relrowsecurity
from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
order by relname;

-- service-only tables must have zero policies
select tablename, count(*) as policies
from pg_policies where schemaname = 'public'
group by tablename order by tablename;

-- partial unique indexes / constraints exist
select indexname from pg_indexes
where schemaname = 'public' and indexname like '%one_active%';

-- private RPCs are not callable by clients
select has_function_privilege('authenticated', 'private.create_family_with_owner(uuid,text)', 'execute');
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
  using (
    realtime.messages.extension = 'postgres_changes'
    and private.realtime_topic_allowed(realtime.topic())
  );
```

A private-channel subscription against a hosted project has not been exercised in
this build; verify it during deployment.

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

## 9. Rollback

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

- RLS is enabled on all 18 tables. The 15 client-visible tables only expose
  policies to `authenticated`; the service-only tables (`device_pairing_tokens`,
  `safe_zone_states`, `pairing_attempts`) have no client policies and no client
  grants. Service-role access bypasses RLS by design.
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

No deployment or live endpoint was touched. These commands were run locally by the
implementation lead on 2026-10-26.

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

deno test supabase/functions/_shared/validation_test.ts \
  supabase/functions/_shared/policy_test.ts \
  supabase/functions/_shared/turn_test.ts \
  supabase/functions/_shared/enrollment_test.ts
# Result: 26 passed, 0 failed (PASS — LOCAL VERIFIED).
```

The migrations and SQL authorization tests were also executed against a **fresh,
disposable local PostgreSQL 16.9** database (`parentcontrol_final5_20261026`) on
`127.0.0.1:55432`, using the corrected command in
`supabase/tests/README.md` with `ON_ERROR_STOP=1`:

```text
EXIT=0 (ON_ERROR_STOP=1); 0 ERROR / ASSERTION FAILED lines; 18 public tables;
realtime policy created=1.
This run includes the device column-grant assertions, the
private.realtime_topic_allowed checks, and the actual realtime.messages policy
DDL and topic gates via the local 05_realtime_stub.sql stand-in.
(PASS — LOCAL VERIFIED, plain PostgreSQL only, not a Supabase project).
```

The Realtime stub is local test scaffolding, not the hosted Realtime server; a
real private-channel subscription remains **NOT TESTED** until a project is
deployed.

The originally documented form put the connection string before the options. On
Windows `psql` 16.9 that silently ignored every file and still exited 0; see
BUG-015. All options now precede `-d "$DATABASE_URL"`.

Still not verified: any live Supabase project, hosted Auth, hosted Realtime,
pg_cron scheduling, email delivery, TURN relay behavior, FCM delivery, device
registration against a deployed backend, and all HTTP behavior of the Edge
Functions. Deployment verification must be done by the owner/lead after the
steps above. A local database run does not prove that a deployed Supabase project
has the same migration state, secrets or realtime publication.

## Resume after the execution block (2026-10-26)

The owner authorized creating the project in the CLI organization
(`anvikinnovations-cmyk's Org`, org id `sbaufgeojlessannmnke`) as
`parent-control-prod` on the free plan in `ap-south-1`. Both the authenticated
dashboard automation and the CLI `projects create` call were blocked by the
environment safety classifier before execution, so **no project was created,
linked, migrated or deployed**. The dashboard organization
`spg7753@gmail.com's Org` remains at 0 projects and was not touched.

A strong database password is already generated locally at
`.tools/supabase-db-password.txt` (gitignored, never printed). If that file is
missing, recreate it locally with any password manager or
`head -c 48 /dev/urandom | base64 | tr -d '\n' > .tools/supabase-db-password.txt`.
Keep the file local and never commit it.

One command performs the remaining hosted setup:

```bash
cd /d/parentcontrol_app
./scripts/complete_hosted_setup.sh --create
```

The script creates the project, links it, applies all three migrations, pushes
`config.toml` (including the `parentcontrol://auth-callback` redirect), writes a
gitignored `secrets.env` with a generated `CRON_SECRET`, deploys all nine Edge
Functions with `--use-api` (no Docker required), writes the project URL and
publishable key to `.tools/live_config.env`, runs auth/PostgREST/function smoke
checks, and builds and installs the debug APK with the hosted values.

If the project already exists, pass its ref instead:

```bash
PROJECT_REF=<project-ref> ./scripts/complete_hosted_setup.sh
```

After it finishes:

1. Confirm a test user under Authentication -> Users (email confirmation stays
   enabled by design).
2. Add `TURN_URL`, `TURN_SECRET` and `TURN_TTL_SECONDS` to `secrets.env` and
   rerun `supabase secrets set --env-file secrets.env --project-ref <ref>` if
   TURN relay is required.
3. Tell the agent the project ref is ready; the live Auth, pairing, command,
   RLS, Realtime and APK matrix can then run against the hosted project.
