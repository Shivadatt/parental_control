# Phase 0 baseline

Frozen at the start of Phase 0. Every other implementation document refers to this state.
Nothing in this file was produced by mutation: no commit, no migration, no deploy, no
Supabase CLI call.

## 1. Git state

| Item | Value | How observed |
|---|---|---|
| Branch | `main` | `git rev-parse --abbrev-ref HEAD` |
| HEAD | `2a0209f` | `git rev-parse --short=7 HEAD` |
| Backup branch | **none created** | owner approval for any git-writing step has not been given |
| Working tree | untracked `audit/`, untracked `docs/implementation/`, pre-existing `.pgdata` deltas (`D .pgdata/postmaster.pid`, `M .pgdata/server.log`) | `git status --porcelain` |
| Audit documents | 13 files under `audit/` (+ `audit/_work/` fragments) | `ls audit/` |

The `.pgdata` entries are a running local Postgres, not source. They are left untouched per
coordinator-contract rule 4 (no destructive git, no cleanup of user work).

## 2. Toolchain (measured, not assumed)

| Tool | Version / location | Evidence |
|---|---|---|
| Flutter | **3.44.6**, `channel [user-branch]`, framework `ee80f08bbf` | `.fvm/flutter_sdk/bin/flutter --version` |
| Dart | **3.12.2** (bundled with the FVM SDK) | `.fvm/flutter_sdk/bin/dart --version` |
| Deno | **2.9.4** | `deno --version` |
| Node | **v24.14.0** | `node --version` |
| Supabase CLI | **absent, and must stay absent** | coordinator-contract non-negotiable 2 |
| Kotlin unit tests | **BLOCKED — environment** (Gradle cannot build a project on `D:` from the toolchain working set; cross-drive failure). Zero Kotlin tests executed in this phase. | audit `00_EXECUTIVE_SUMMARY.md:219` |

`flutter test` and `flutter build` are not run by this workstream (contract rule 10); the
verification workstream runs them once.

## 3. Audit baseline

Source: `audit/00_EXECUTIVE_SUMMARY.md:49-73`, cross-checked against the tree where cheap.

| Measure | Count | Phase 0 re-check |
|---|---|---|
| Subfeatures inventoried | **242** | 242 table rows parsed from `audit/01_COMPLETE_FEATURE_INVENTORY.md` |
| Status distribution | 28 verified / 53 partially verified / 30 partial / 2 backend-only / 13 code-not-tested / 2 broken / 111 missing / 3 not-applicable (0 UI-only, 0 blocked) | sums to 242 |
| Flutter source files | **140** | `find lib -name '*.dart'` → 140 |
| Routes | **26** | `lib/app/routes/app_routes.dart:4-31` (26 consts) + `lib/app/routes/app_pages.dart:56-186` (26 `GetPage`s) |
| Kotlin files | **20** | `find android/app/src/main/kotlin -name '*.kt'` → 20 |
| Base tables | **19** | 18 in `supabase/migrations/20260101000000_core.sql` + `child_contact_ids` in `20260101000500_child_contact_ids.sql:18` |
| RLS policies | **22** | 21 in `20260101000200_rls.sql` + `parentcontrol_private_topics` on `realtime.messages` (`:349`); the two `webrtc_signals` policies are re-created, not added, by `20261028000300_signaling_open_session.sql:25,41` |
| SQL functions | **38** live (24 `private` / 14 `public`) | `audit/06_BACKEND_DATABASE_RLS_AUDIT.md:12`; local files contain 41 `create or replace function` statements, three of which are superseded bodies |
| Triggers | **8** (+1 on `auth.users`) | `grep -c 'create trigger' supabase/migrations/*.sql` → 8 |
| Migrations | **10** | `ls supabase/migrations/` |
| Edge Functions | **9** | `find supabase/functions -name index.ts` → 9 |
| Flutter test files | 38 | `find test -name '*_test.dart'` |
| Realtime publication members | 4 | `device_commands`, `remote_sessions`, `safety_alerts`, `webrtc_signals` (`audit/06:15`) |

## 4. Known deployment drift

| Artifact | Repository HEAD | Hosted | Consequence |
|---|---|---|---|
| `remote-session` Edge Function | parent-controlled lifetime: `expires_at: null` on accept, parent-only `end`, no clock expiry for consented rows | **stale 30-minute build**: `Q = 30*60*1e3`, accept stamps `accepted_at + 30 min`, `active`/`ice` throw `session_expired` 410, `end` accepts any participant | every consented audio session dies 30 min after consent; reproduced 2026-10-29 12:16:38Z (`audit/06:73-92`) |
| Database (19 tables / 22 policies / 38 functions / 8 triggers) | 10 migrations | **in sync** with the migrations | none |
| Realtime | 4 publication members | in sync | none |
| Storage / Auth | 0 buckets, email auth | in sync | none |
| `pg_cron` | absent | absent | no scheduler exists for `expire_stale_sessions` / `detect_offline_devices`; the `cron` function's caller is unverified |
| `cron` function schedule | `supabase/config.toml` defines no schedule | no visible external caller | server sweeps never run (`audit/06:41,63`) |
| TURN | `_shared/turn.ts` helper exists | no relay secret deployed | ICE `relay 0`; carrier-NAT calls fail |

Deployment is **out of scope** for Phase 0 and Phase 1. The drift stays open until the owner
approves a deploy; `docs/implementation/deployment-log.md` (verification workstream) records it.

## 5. Known verification limits

| Limit | Status | Consequence for Phase 0 |
|---|---|---|
| SQL suite execution | **NOT RUN** — no local Postgres harness is used and no Supabase CLI; `supabase/tests/*.sql` are written to be runnable but are not executed here | migration contracts are reviewed by reading, not by execution |
| Kotlin unit suite | **BLOCKED — environment** (cross-drive Gradle) | Kotlin changes in Phase 1 can be compiled only by the owner; results must be reported `BLOCKED` |
| Push channel | **absent by design** — no FCM dependency, no local notification transport | any "realtime alert" claim stays polling-scoped; no Phase 1 feature may claim push |
| Hosted inspection | dashboard-only, read-only, and not repeated in Phase 0 | all hosted facts are inherited from `audit/06` |
| Byte-level parity of 8 of 9 Edge Functions | **BLOCKED — dashboard limitation** (compared by timestamp) | only `remote-session` drift is proven |
| Human audibility of audio | **BLOCKED** — no listener, evidence is RTP counters | audio workstream can prove counters, not audibility |
| Historical automated results (2026-10-29, not re-run) | Flutter 275 passed / analyze clean / Deno 47 passed / Kotlin blocked | **must not** be quoted as a Phase 1 result |

Any Phase 1 statement of PASS requires an execution performed in Phase 1 by the workstream that
owns the change. Inherited numbers are historical context only.