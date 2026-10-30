# 06 — Backend, database and RLS audit (local vs hosted)

Method: local repository read-only (`supabase/migrations`, `supabase/functions`); hosted Supabase inspected **only through the Web Dashboard** (project `parent-control-prod`, ref `hhqgreaoqulmfwfwarhc`) using read-only SQL (`SELECT`/catalog) and dashboard pages. **No Supabase CLI was run, no DDL/DML, no deploy, no policy/secret/auth change.** Dashboard clock at audit time: 2026-10-30 05:45 UTC. Evidence: `audit/_work/s4-backend-local.md`, `audit/_work/s5-hosted-supabase.md`.

## 1. Hosted state (verified)

| Item | Hosted |
|---|---|
| Tables | **19**, all RLS-enabled; replica identity default on all |
| Policies | **22**, all `TO authenticated`; no `anon` policy anywhere |
| Table grants | `anon`: zero; `authenticated`: SELECT on 15 tables + INSERT on `webrtc_signals` + DELETE on `safe_zones`; `service_role`: full DML |
| SQL functions | **38** (24 private / 14 public), all `SECURITY DEFINER` with pinned `search_path`; **none executable by anon/authenticated** except two `private` helpers |
| Triggers | **8** non-internal, incl. `remote_sessions_transition_guard`, append-only `audit_logs`, `on_auth_user_created` |
| Extensions | pgcrypto, uuid-ossp, pg_stat_statements, supabase_vault, plpgsql. **No pg_cron, no pg_net, no PostGIS** |
| Realtime | publication: `device_commands`, `remote_sessions`, `safety_alerts`, `webrtc_signals` |
| Storage | **0 buckets** |
| Auth | email-only, signup ON, email confirmation ON, anonymous OFF, JWT expiry 3600 s, session time-boxing unavailable on this plan; 8 confirmed users (4 parent / 4 child profiles), 3 families, 14 devices (2 active) |
| Cron | **none** (`cron.job` does not exist) |
| Edge Functions | 9 deployed; **`remote-session` is the pre-fix build** (see §4) |
| Integrity indexes | one active device per child; one active child family; one non-deleted family per owner; unique `(device_id, idempotency_key)`; unique `(device_id, version)` |
| Audit coverage | `audit_logs`: session_requested/accepted/started/ended only — **no `session_expired` event** |

## 2. Local repository state

- 10 migrations define the same 19 tables, 38 functions, 22 policies, 8 triggers and indexes — hosted has **no object without a local migration** (verified by catalog scan).
- 9 Edge Functions with shared modules (`auth`, `audit`, `envelope`, `policy`, `validation`, `rate_limit`, `turn`, `cors`) and Deno tests (47 passing historically).
- `config.toml` has no cron schedule and no storage bucket definition.
- Local HEAD `remote-session` implements parent-controlled lifetime: `expires_at: null` on accept (`supabase/functions/remote-session/index.ts:229`), expiry check only for legacy non-null rows, parent-only end, and `guard.ts` tests.

## 3. Required comparison (8 areas)

| Area | Local repository | Hosted Dashboard | Verdict |
|---|---|---|---|
| **Database schema** | 10 migrations (core → signaling) | All 19 tables/columns/constraints/indexes match the migrations; nullable `expires_at` + pending-expiry CHECK present | **IN SYNC** |
| **RLS** | 22 policies in `20260101000200_rls.sql` + signaling update in `20261028000300` | 22 policies, predicates identical; all RLS enabled; no anon grants | **IN SYNC** |
| **SQL functions / triggers** | 38 functions, 8 triggers | Same names/bodies; `expire_stale_sessions` only touches `requested`; `remote_session_transition_guard` blocks terminal→live | **IN SYNC** |
| **Edge Functions** | HEAD has the lifetime fix, parent-only end, guard tests | Deployed bundle is old: `Q=30*60*1e3`, accept writes `expires_at=accepted+30m`, `active`/`ice` throw 410 `session_expired`, `end` participant-only | **OUTDATED (blocking)** |
| **Realtime** | 4 tables in publication, no expiry predicate in `webrtc_signals` policies | Same 4 tables; policies match; replica identity default on all | **IN SYNC** (with design caveat: UPDATE payloads carry PK only) |
| **Storage** | No bucket definitions in migrations | 0 buckets | **IN SYNC / NOT USED** |
| **Authentication** | Email auth via Supabase Auth; role lock via `auth-bootstrap` + trigger | Email-only, confirmation ON, 8 confirmed users, JWT 3600 s, no session timeout | **IN SYNC** |
| **Cron jobs** | `pg_cron` not configured; `cron` Edge Function exists but has no scheduler | `pg_cron` absent, no visible external scheduler | **MISSING / UNVERIFIED CALLER** |

### Delta lists

**Local changes not deployed**
1. `remote-session` Edge Function (lifetime fix, parent-only end, guard module + tests) — **not deployed**. This is the only artifact delta and it is the root cause of the F1 expiry failure.
2. New Deno tests (`guard_test.ts`, etc.) exist locally only.

**Hosted changes missing from local migrations**
- None. Every hosted table, column, index, trigger and function traces to a migration.

**Schema differences**
- None found between migrations and hosted catalog.

**Policy differences**
- None in predicates. Behavioural note: `remote-session` `end` (deployed) ignores the new parent-only rule even though the schema/guard would allow it.

**Outdated Edge Functions**
- `remote-session` only. Others (`pairing`, `auth-bootstrap`, `family-admin`) are 2–3 days old; `device-*` and `cron` 4 days old, consistent with the last commits.

**Missing configuration**
- No TURN relay credentials configured (client reports "Relay not configured"; ICE `relay 0`). The repo has a `turn.ts` credential helper, but no deployed secret/relay.
- No scheduler for `expire_stale_sessions` / `detect_offline_devices` (no pg_cron, no visible external caller).
- No Storage buckets (intentional, but means no media/attachment capability).
- No `session_expired` audit event type, so clock expiry is invisible in `audit_logs`.

**Deployment dependencies**
- Supabase CLI/owner action to deploy `remote-session` (requires explicit owner approval — not performed).
- Migration `20261028000200` is already applied hosted; no replay needed.
- TURN relay + secrets if carrier-NAT recovery is required.
- An external scheduler if server-side sweeps are required.

## 4. Deployed `remote-session` — evidence of the stale build

Deployed bundle (Dashboard → Edge Functions → `remote-session` → Code) contains:

- `Q = 30*60*1e3`, and on accept: `expires_at: new Date(c.getTime()+Q).toISOString()`.
- On `active` and `ice`: `if (new Date(o.expires_at).getTime() <= Date.now()) throw … ("session_expired", 410)`.
- On `end`: `if (not participant) 403` — no parent-only check.

Data corroboration (read-only sample, ids truncated):

| session | accepted | expires_at | ttl | final |
|---|---|---|---|---|
| d1a04614 | 10-29 13:46:31 | 14:16:31 | 30.0 min | ended 13:53:02 |
| af0b39b9 | 10-29 12:48:46 | 13:18:46 | 30.0 min | ended 13:36:40 |
| 1bd26a84 | 10-29 11:27:25 | 11:57:25 | 30.0 min | **expired 12:16:38** |
| 255d42d6 | 10-29 05:08:26 | 05:38:26 | 30.0 min | ended 05:54:41 |

All 35 `ended` rows carry a 30-minute deadline; 10 rows were expired by the clock. The newest activity is 2026-10-29 13:46–14:12 UTC. The DB's `expire_stale_sessions()` only sweeps `requested` rows, so the remaining writer is the deployed function.

**Verdict: `BROKEN` on hosted for parent-controlled session lifetime; schema side `FULLY IMPLEMENTED — VERIFIED`.**

## 5. RLS and authorization findings (local, applies to hosted)

| Severity | Finding | Evidence |
|---|---|---|
| High | `safe_zones` has a client `DELETE` policy, contradicting the migration file's own "no client DELETE policies" rule | `20260101000200_rls.sql:162-166` vs `:2` |
| High | `family-admin` `purge_data` accepts **any family parent** and irreversibly deletes `location_events`/`usage_daily`, while the less destructive retention change is owner-only | `supabase/functions/family-admin/index.ts:157-227` |
| High | Service-only RPCs trust caller-supplied parent/actor ids (`create_pairing_invite`, `create_pairing_request`, `apply_policy_version`, `request_remote_session`) without re-verifying membership | `s4` §2 |
| Medium | Immutability triggers test `current_user in ('service_role','postgres',…)` inside SECURITY DEFINER paths, so definer-owned writes bypass append-only intent | `20260101000000_core.sql:502-505,525-529,549-553` |
| Medium | `webrtc_signals` has no unique `(session_id, sequence)`; replay/dedup is client-side only | hosted catalog + `core.sql` |
| Medium | `session_nonce` is written but never verified by the client or function | `s4` |
| Low | `private.remote_session_transition_guard` and `private.request_device_recovery` are executable by PUBLIC inside `private` (default grant) | hosted `has_function_privilege` |
| Low | Every DB error collapses to HTTP 500; CORS is `*` | `_shared/envelope.ts:103-111`, `_shared/cors.ts:3` |
| Info | No policy grants `anon`; all writes are service-role — good baseline | hosted grants |

## 6. Blocked / not verifiable from the Dashboard

- Deployed function **version integer/exact timestamp**: not rendered anywhere → `BLOCKED — dashboard limitation` (evidence used: "updated 4 days ago", git dates, deployed bundle contents).
- Edge Function **log message bodies** (410/session_expired lines): row expansion needs pointer input unavailable in this session → `BLOCKED`; the 410 behaviour is proven from code and `expired` rows instead.
- **Postgres error logs / API auth aggregates**: not collected → `BLOCKED`.
- **Data API per-schema exposure toggle** (is `private` exposed?): virtualized control unreadable → `BLOCKED`. This matters because two `private` functions are PUBLIC-executable.
- **Row counts** for 11 tables: never analyzed (`reltuples = -1`) → unknown.

## 7. Bottom line

The database, RLS, grants, functions and realtime configuration are in sync with the repository and are, on the whole, well built: RLS on every table, no anon grants, service-role-only RPCs, and real invariants in partial unique indexes. The one blocking divergence is the **`remote-session` Edge Function** — the only component whose deployed build predates the fix. Until it is deployed, every accepted audio session still dies 30 minutes after consent, exactly as observed at 12:16:38Z on 2026-10-29.