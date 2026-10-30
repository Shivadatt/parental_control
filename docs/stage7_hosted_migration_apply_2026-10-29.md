# Hosted Supabase apply — Stage 7 migrations (2026-10-29)

Scope: apply the two pending, additive migrations to the existing hosted project
`parent-control-prod` (`hhqgreaoqulmfwfwarhc`) using the Supabase **Dashboard**,
as directed. No CLI was used, no project was created, no table was reset or
replaced, and no Edge Function was deployed.

Status label: **PASS — LIVE VERIFIED** for the database change and its RLS
behaviour. Device-level media renegotiation remains **BLOCKED** (see §6).

## 1. Pre-state (read-only introspection)

Queried in Dashboard → SQL Editor before any change:

| Check | Observed |
|---|---|
| `remote_sessions.expires_at` | `NOT NULL` |
| `remote_sessions_pending_expiry_check` | absent |
| `remote_sessions_transition_guard` trigger | absent |
| `public.request_remote_session(uuid,uuid,text)` | absent |
| `expire_stale_sessions()` | present in `private` and `public` |
| `webrtc_signals` SELECT policy | contained `s.expires_at > now()` |
| `webrtc_signals` INSERT policy | contained `s.expires_at > now()` |
| `pg_cron` extension / `cron.job` | absent |
| `remote_sessions` rows | 39 total; 1 `active` (`e84ba35e-…`, requested 05:48:03Z, expiry 06:18:20Z, consent true), 30 ended, 8 expired |
| Dashboard migration history | "No migrations" (previous schema was applied out-of-band too) |

The one open row predates this work. Its original deadline was recorded before
the data change: `2026-10-29 06:18:20.281+00` (it was already in the past).

## 2. Applied migrations

Both were run in the SQL Editor in a single transaction each. The Dashboard
showed its "destructive operations" confirmation; each was confirmed explicitly.
The SQL was the DDL from the repository files, unchanged.

1. `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql`
   - `alter table public.remote_sessions alter column expires_at drop not null`
   - `add constraint remote_sessions_pending_expiry_check check (status <> 'requested' or expires_at is not null)`
   - `update … set expires_at = null where status in ('accepted','active')` (1 row)
   - `private.remote_session_transition_guard()` + `remote_sessions_transition_guard` trigger
   - `private.expire_stale_sessions()` replaced (pending-only sweep)
   - `public.request_remote_session(uuid,uuid,text)` created, service-role only
   - Result: `Success. No rows returned`
2. `supabase/migrations/20261028000300_signaling_open_session.sql`
   - `webrtc_signals_select_participant` / `webrtc_signals_insert_participant`
     re-created without the `expires_at > now()` predicate, still limited to
     `status in ('accepted','active')` and to the session's two participants
   - Result: `Success. No rows returned`

`20261028000300` was applied **with** `20261028000200`, as required: deploying
the lifetime change without the signaling change would leave consented rows with
`NULL` expiry unable to carry offers/answers/ICE.

## 3. Post-state (read-only verification)

| Check | Observed |
|---|---|
| `expires_at` nullability | `nullable=YES` |
| Pending deadline constraint | `CHECK (((status <> 'requested') OR (expires_at IS NOT NULL)))` |
| Transition trigger | `remote_sessions_transition_guard` present |
| `private.expire_stale_sessions` / `public.request_remote_session` | present (1 each) |
| `webrtc_signals` policies mentioning `expires_at` | none (`insert=false`, `select=false`) |
| Open rows with a deadline | 0 |
| Row count | 39 total, 1 open (unchanged history) |

## 4. Behavioural probes (all rolled back; nothing persisted)

Run against the existing `active` session whose deadline is now `NULL`:

1. **Positive:** as role `authenticated` with the session's parent `sub`, an
   `insert into webrtc_signals (session_id, from_user_id, kind, payload)` was
   accepted and returned a row (`kind=offer`). This is the exact operation that
   previously failed with `42501 … row-level security policy` during automatic
   renegotiation.
2. **Persistence check:** `select count(*) from webrtc_signals where payload ? 'probe'` → `0`.
3. **Negative:** as `authenticated` with a non-participant `sub`, the same insert
   failed with `ERROR: 42501: new row violates row-level security policy for table "webrtc_signals"`.
4. **Terminal guard:** `update remote_sessions set status='active'` on a terminal
   row failed with `ERROR: P0001: session_terminal`.

All probes ended in `ROLLBACK`.

## 5. What this does and does not change

- Consented sessions are now parent-controlled in the database: no clock ends
  them, and signaling works without a deadline.
- The pending-request sweep now only touches `status = 'requested'` rows.
- `20261028000200` is **not idempotent** (the `add constraint` is unguarded).
  It has been applied once; do not re-run the file as-is. Future replays should
  guard it with a `pg_constraint` check.
- The hosted migration history still reads "No migrations"; these changes were
  applied through the SQL Editor.
- No Edge Function was deployed. Production still runs the older `remote-session`
  bundle, which inserts sessions directly and sets an `expires_at` on accept.
  That is now harmless for RLS and lifetime, but the new
  `public.request_remote_session` concurrency guard and the `session_state`
  expiry handling only take effect after an Edge Function redeploy, which is a
  production deployment and needs separate authorization.
- `pg_cron` is not installed on hosted, so no scheduled sweep runs there. This is
  unchanged and pre-existing.
- The single `active` row (`e84ba35e-…`, device `fd79ee34-…`) is now
  parent-controlled and has no deadline. It is orphaned (the child account on the
  test device was signed out). It was **not** ended by this work. A parent must
  end it explicitly; leaving it open is consistent with the new policy but it
  will block a future `request_remote_session` for that device once the new Edge
  Function bundle is deployed.

## 6. Remaining blocker

End-to-end proof that the parent's renegotiation offer is now accepted during
automatic recovery still needs the paired child device *and* a parent device.

At the time of this apply the child phone was signed in as an unlinked account.
**Superseded later the same day:** the child account was re-linked through the
normal invite + child-approval flow (pairing request `c0c70473…`, approved
`2026-10-29T05:47:15Z`). The device-level rerun is still **BLOCKED**: no parent
device/emulator is attached, and the child phone is in human use.

## 7. Rollback

Rollback is a schema/function rollback only. It must not delete session history
or unrelated rows.

```sql
-- 1. Stop new transitions from being guarded.
drop trigger if exists remote_sessions_transition_guard on public.remote_sessions;
drop function if exists private.remote_session_transition_guard();

-- 2. Remove the RPC (safe only if no newer Edge Function bundle calls it).
drop function if exists public.request_remote_session(uuid, uuid, text);

-- 3. Drop only the constraint added by 20261028000200.
alter table public.remote_sessions
  drop constraint if exists remote_sessions_pending_expiry_check;

-- 4. Restoring NOT NULL requires every open row to have a deadline.
--    Do NOT fabricate one by deleting rows. Close sessions through the
--    authenticated parent End flow first, then re-check:
--      select count(*) from public.remote_sessions
--       where expires_at is null and status in ('accepted','active');
--    Only when that count is 0:
-- alter table public.remote_sessions alter column expires_at set not null;

-- 5. Restore the previous bodies of private.expire_stale_sessions() and the
--    two webrtc_signals policies from the pre-20261028 migrations.
```

Notes:

* An earlier draft of this section contained a `delete from remote_sessions …`
  statement. It was removed: it destroys production session history and is not
  an acceptable rollback step. Close open sessions through the app's parent
  **End session** flow or leave them open under the new policy.
* Rolling back the signaling policies alone immediately reintroduces the
  renegotiation failure for NULL-expiry sessions.
* `20261028000200` is not idempotent. A replay must first guard the constraint
  with a `pg_constraint` existence check.
