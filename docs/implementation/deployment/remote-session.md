# `remote-session` deployment preparation

**Status: NOT DEPLOYED IN THIS PHASE. Requires owner approval.**
Nothing in this document has been executed against Supabase. No hosted SQL, no
function upload, no secret change, no CLI. The pre-checks below are read-only
`select` statements intended for the Supabase Dashboard SQL Editor (or
`psql` against a read-only connection) and are the only steps a human can run
before approval.

Owner of this change set: workstream `session`. File: `supabase/functions/remote-session/`.

---

## 1. Deployed build vs repository HEAD

The live function is the bundle preserved at `.tools/deploy/remote-session.ts`
(12,848 bytes, 2026-10-26 21:35; `.b64` / `.gz.b64` copies beside it). HEAD is
`supabase/functions/remote-session/index.ts` (13,583 bytes) +
`guard.ts` (5,251 bytes) + `supabase/functions/_shared/*`, bundled to one file at
deploy time. Both bundles are single-file ES modules with
`import ... from "npm:@supabase/supabase-js@2"`. Behavioural delta, deployed →
HEAD:

| # | Action | Deployed build (live) | HEAD (this repository) |
|---|---|---|---|
| 1 | `request` | Direct `insert` into `remote_sessions`; two concurrent calls can create two open sessions. | Calls `public.request_remote_session` (per-device advisory lock, in-lock pending expiry, `session_in_progress` 409). Sweep runs first, best effort (`index.ts:125-133`). |
| 2 | `respond` + `accept` | Stamps `expires_at = now + 30 minutes`. This is the 30-minute cap. | `acceptPatch()` writes `expires_at: null` and `consent_recorded: true` (`guard.ts:170-177`). |
| 3 | `start` | Rejects with **410 `session_expired`** once that 30 minutes has elapsed, and expires the row. | No clock check. `accepted` + consent → `active` (`index.ts:274-296`). |
| 4 | `ice` | Same 410 clock check, then expires the row. Media cannot (re)connect after 30 minutes. | No clock check; credentials are reissued per call (`index.ts:352-366`). |
| 5 | `end` | Any participant may end (child included); `ended_by` = caller; `reason` is taken from the request body. | `assertParentOwner()` → 403 `parent_only` for the child; `ended_by` = parent uuid, reason derived server-side (`index.ts:315-320`, `guard.ts:117-156`). |
| 6 | `session_state` | Absent. | Device-authenticated poll returning `{session_id,status,expires_at}` (`index.ts:161+`, `guard.ts:87-106`). |
| 7 | `pending_child` | 10-minute pending expiry + list. | Unchanged (10-minute pending expiry kept). |

That is the reported failure: a consented call is killed at 30:00 by #3/#4, and
the child can end the parent's session via #5.

`media` is not an action of this function: signaling writes go through the
`webrtc_signals` RLS policies. The deployed database still carries the
`expires_at > now()` predicate, which is dropped by
`20261028000300_signaling_open_session.sql`. Both changes are required for a
consented session to keep media beyond 30 minutes.

## 2. Hard preconditions (schema)

HEAD cannot run against the schema the live project had on 2026-10-27
(`docs/backend.md` records migrations only through `20260101000600`). Applying
it before the schema is ready breaks sessions in a new way:

| Missing object | Effect if HEAD is deployed without it |
|---|---|
| `public.request_remote_session(uuid,uuid,text)` (20261028000100/200/300) | `request` returns 500 `internal_error` for **every** parent request. |
| nullable `remote_sessions.expires_at` + `remote_sessions_pending_expiry_check` (20261028000200) | accept writes `NULL` into a `NOT NULL` column → 500, consent impossible. |
| `webrtc_signals` policies without `expires_at > now()` (20261028000300) | signaling rejected for consented sessions (NULL expiry). |
| `public.expire_abandoned_sessions(interval)` (20261030000100) | Optional for correctness: the sweep logs `abandoned_session_sweep_failed:PGRST202` and the request still succeeds (proved by `lifecycle_test.ts`). |

Order: apply migrations first, then deploy the function. `Verify JWT` must stay
**ON** for `remote-session` (`supabase/config.toml`), as it is today.

## 3. Pre-check SQL (read-only)

Run in the Dashboard SQL Editor before touching the function. Every statement
below is a `select`; none writes.

**A. Abandoned-session sweeper present and service-role only** (Phase 1
migration #1):

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

Expected exactly one row (this is the real output of that query on a local
PostgreSQL 16 run of the migration):

```text
function                            | returns | security_definer | settings                               | anon | authenticated | service_role
expire_abandoned_sessions(interval) | integer | t                | {"search_path=public, private, pg_temp"} | f    | f             | t
```

**B. Parent-controlled lifetime schema** (dependency, 20261028000200):

```sql
select c.is_nullable as expires_at_nullable,
       (select pg_get_constraintdef(k.oid) from pg_constraint k
         where k.conrelid = 'public.remote_sessions'::regclass
           and k.conname = 'remote_sessions_pending_expiry_check') as pending_check,
       (select count(*) from pg_trigger t
         where t.tgrelid = 'public.remote_sessions'::regclass
           and t.tgname = 'remote_sessions_transition_guard'
           and not t.tgisinternal) as transition_guard
from information_schema.columns c
where c.table_schema = 'public' and c.table_name = 'remote_sessions'
  and c.column_name = 'expires_at';
```

Expected: `expires_at_nullable = YES`, `pending_check` mentions
`status <> 'requested'::text OR expires_at IS NOT NULL`, `transition_guard = 1`.
If any differs, stop: HEAD must not be deployed.

**C. Request RPC present** (dependency, 20261028000100/200/300):

```sql
select p.oid::regprocedure::text as function,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute,
       has_function_privilege('service_role', p.oid, 'execute') as service_role_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'request_remote_session';
```

Expected one row: `request_remote_session(uuid, uuid, text)`, `security_definer
t`, `authenticated_execute f`, `service_role_execute t`. Zero rows means HEAD
cannot serve `request`.

**D. Signaling has no expiry predicate** (dependency, 20261028000300):

```sql
select policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'webrtc_signals'
order by policyname;
```

Expected: two policies (`webrtc_signals_select_participant`,
`webrtc_signals_insert_participant`) whose `qual` / `with_check` mention
`status` but **not** `expires_at`.

**E. Deployed function identity.** In the dashboard, Edge Functions →
`remote-session`: `Verify JWT` is ON, and the Code tab still holds the old
single-file bundle (it contains `"This session has expired."` and does **not**
contain `session_state` or `request_remote_session`). Record the pre-deploy
bundle SHA-256 before pasting anything.

## 4. Deployment steps (human, dashboard only; not performed here)

1. **Owner approval.** No step below may be run without it. Budget one
   maintenance window; expect no downtime (a function redeploy is atomic), but
   in-flight calls on the old bundle are killed at their 30-minute mark.
2. **Apply the migrations** from `manifest.md`, in order, through SQL Editor
   (each file pasted as-is). Re-run pre-checks A–D.
3. **Build the single-file bundle** (the function imports `./guard.ts` and
   `../_shared/*`; the dashboard editor cannot reach `../_shared`). From the
   repository root, on a machine with network access for npm:

   ```bash
   npx --yes esbuild@0.25.5 supabase/functions/remote-session/index.ts \
     --bundle --format=esm --platform=neutral '--external:npm:*' --minify \
     --outfile=.tools/deploy/remote-session.next.ts
   ```

   Verified locally: this produces one ~15.5 KB file containing
   `import{createClient as Z}from"npm:@supabase/supabase-js@2"` and
   `expire_abandoned_sessions`, i.e. the same shape as the current live bundle.
   Do not add a second file to the function folder: `_shared` is not uploaded.
4. **Dashboard → Edge Functions → `remote-session` → Code tab.** Select all,
   paste the bundle content, let the editor save.
5. **Verify what is about to ship**, in this order, before clicking Deploy:
   - the editor shows the new code (search for `session_state` and
     `expire_abandoned_sessions`);
   - `Verify JWT` is ON;
   - no secret, TURN credential or key is present in the code (`TURN_SECRET` is
     read from the environment, never inlined);
   - the pasted content contains no `import` other than the `npm:` one.
6. **Click Deploy.** Wait for the "deployed" state, then run section 5.
7. **Record** the deployed SHA-256 and timestamp in
   `docs/implementation/deployment-log.md` (owned by the verification
   workstream), together with the pre-checks output.

## 5. Post-deploy verification

Run against the QA parent/child accounts and one paired device.

1. **Consent clears the deadline.** Parent requests, child accepts. Then:

   ```sql
   select id, status, expires_at, accepted_at, consent_recorded, ended_by, ended_reason
   from public.remote_sessions
   order by requested_at desc
   limit 1;
   ```

   Expected: `status = 'accepted'`, `expires_at IS NULL`, `consent_recorded = true`.
   A non-null `expires_at` means the old bundle is still live.

2. **No 410 at 30 minutes.** Start the session, keep it connected, and call
   `ice` (or let the client refresh) at +31 and +45 minutes. Expected HTTP 200
   with ICE servers, session still `active`. In the function logs, there must be
   no `session_expired` for that session id. This is the regression the old
   build caused.

3. **Parent-only end.** From the child device, the UI stops sharing locally and
   never ends the row. A direct child `end` call must return 403 `parent_only`.
   The parent `end` must produce `status='ended'`, `ended_by=<parent uuid>`,
   `ended_reason='ended_by_parent'` (or `cancelled_by_parent` for a pending
   request). The child must not be able to inject a `reason`.

4. **Concurrency.** Two `request` calls for the same device within a second:
   the second returns 409 `session_in_progress`, and the first session is
   untouched (`select count(*) ... where device_id = ... and status in
   ('requested','accepted','active')` = 1).

5. **Sweeper runs without noise.** The logs must show no
   `abandoned_session_sweep_failed:` line after the first request. Optionally
   (read-only check of intent):

   ```sql
   select count(*) as abandoned_now
   from public.remote_sessions
   where status in ('accepted', 'active')
     and coalesce(accepted_at, requested_at) < now() - interval '24 hours';
   ```

   Any row here is closed by the next parent request and appears in
   `audit_logs` as `session_expired` with `metadata->>'reason' = 'abandoned'`.

6. **Signaling after consent** (the 20261028000300 dependency): an offer/answer
   round trip on a session with `expires_at IS NULL` must succeed.

## 6. Rollback

The previous bundle is preserved at **`.tools/deploy/remote-session.ts`**
(12,848 bytes; `.b64` and `.gz.b64` copies alongside). It is the exact live
build and needs no rebuild.

1. Edge Functions → `remote-session` → Code → select all → paste
   `.tools/deploy/remote-session.ts` → confirm `Verify JWT` ON → Deploy.
2. Keep the migrations. They are additive and the old bundle works with them:
   it writes a non-null `expires_at` on accept, which the nullable column
   accepts, and it never calls `expire_abandoned_sessions`.
3. Do **not** drop the sweep function or the partial index during a rollback;
   they are unused by the old bundle and dropping them would need a second
   DDL change for no benefit.
4. Consequence of rollback: the 30-minute cap and participant-initiated end
   return. Communicate that to the owner before choosing it.

If `.tools/deploy/remote-session.ts` is ever lost, the rollback target can be
reconstructed from git history of this function, but the byte-identical hosted
bundle would not be reproducible — treat the file as release evidence.

## 7. Open risks

- The hosted schema is one migration generation behind HEAD; pre-checks B–D are
  the gate. Skipping them turns every `request`/accept into a 500.
- The dashboard editor is a single file; pasting a multi-file source tree is not
  possible. The bundle step is mandatory and is the only step that needs a
  developer machine.
- `ended_by` for a system close is `NULL` (the column is a `profiles` uuid, so
  `'system'` cannot be stored without a schema change, which Phase 1 forbids).
  Consumers must read `ended_reason = 'abandoned'` instead.
- A parent request now does one extra RPC (the sweep). It is indexed, but on a
  very large `remote_sessions` table the first run after deployment may take
  longer than later ones.
- No hosted verification exists for any of this yet; nothing here is evidence
  that the live project behaves correctly.