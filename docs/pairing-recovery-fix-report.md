# Pairing recovery and session-safety fix report — 2026-10-29

Scope: Phase B–G of the "Restore Pairing + Complete Two-Device E2E Testing" work.
Baseline evidence: [`docs/pairing-recovery-baseline.md`](pairing-recovery-baseline.md).
No hosted Edge Function was deployed, no secret was rotated, no migration was
replayed, and no production row was deleted or edited in this phase.

## 1. Status summary

| Area | Status | Basis |
|---|---|---|
| Root cause identified | **PASS** | Backend healthy; six client staleness defects traced in the tree (baseline §6) |
| Pairing freshness fixes (D1–D4) | **PASS (unit/controller level)** | Code + 4 suites green (§4) |
| "Live updates interrupted" banner clears (D5) | **PASS (unit/controller level)** | Code + rewritten reliability test (§4) |
| Pairing on real devices, both apps, refresh + relaunch | **NOT TESTED** | No parent device; child phone in human use (§5) |
| Two-device audio session, duration | **NOT TESTED** | Same blocker; last measured evidence is Stage 7 14 m 16 s (§6) |
| Device-level network interruption → banner clears → audio recovers | **NOT TESTED** | Same blocker; controller-level recovery is PASS (§7) |
| Duplicate-session guard (DB) | **PASS (SQL)** | Atomic RPC + two-session race proof (§9) |
| Duplicate-session guard (production) | **BLOCKED** | Deployed `remote-session` bundle predates the RPC (§10) |
| Orphan session `e84ba35e…` closed | **BLOCKED** | Requires the authenticated parent End flow |
| Terminal session cannot revive | **PASS (code + SQL)** | `session_terminal` probe; stale realtime update dropped (§8) |
| Builds | **PASS** | Debug + release APK built (§4) |
| Hosted deployment | **BLOCKED on authorization** | Plan in §10; nothing deployed |

## 2. Root cause

Pairing was not broken on the server. Verified read-only against hosted
`parent-control-prod` on 2026-10-29:

* the parent account owns the family and the child account is an active member;
* device `fd79ee34…` is `active` with a recent `last_seen_at`;
* pairing request `c0c70473…` went `pending_child` → `approved` within ~18 s
  (05:46:57Z → 05:47:15Z);
* the `pairing` Edge Function deployed hash equals the local file
  (`ac4dcef…`, 33,999 B).

The user-visible failure was **client-side staleness**, not a rejected pairing.
Six defects were confirmed in the current tree (baseline §6). The two that
produce the reported symptom directly:

1. **D1** — the child shell loaded pending pairing requests only inside `load()`
   (init, pull-to-refresh, unlink). Its only periodic timer polled the active
   *session*, not `pairing_requests`. With the child app open, a parent invite
   was invisible until a manual refresh or a restart.
2. **D2** — `DevicesController` loaded once in `onInit` and never refreshed, so
   after the child approved, the parent's device list stayed stale until a
   manual pull-to-refresh or relaunch.

D3–D6 are supporting staleness: no automatic status check on the parent's result
card, the check-status error being unreachable in the result view, the realtime
banner never clearing, and the requests-page poll being page-scoped.

## 3. Changes

All changes are additive to existing controllers/pages; no UI redesign, no
route changes, no backend change.

| File | Change |
|---|---|
| `lib/features/child/controllers/child_shell_controller.dart` | `linkedPollInterval` (default 20 s) drives a linked-only timer that refreshes pending pairing requests and the active session when online (`:38`, `:54`, `:367-378`). `_loadPendingRequests` is single-flight via `_pendingRequestsInFlight` so the timer, pull-to-refresh and init cannot overlap (`:97`, `:641-675`). |
| `lib/features/devices/devices_controller.dart` | `refreshInterval` (default 60 s) periodic refresh plus an `ever(isOnline)` worker that reloads on reconnect (`:18`, `:36-62`). `refreshInterval: null` disables the timer for tests. |
| `lib/features/pairing/controllers/pairing_redeem_controller.dart` | `statusPollInterval` (default 10 s) polls `checkStatus()` while the request is `pending_child` and unexpired; stopped on `start`, `reset`, success-with-approval and `onClose` (`:17`, `:101`, `:141`, `:153-177`). |
| `lib/features/pairing/pairing_redeem_page.dart` | Result card renders the error banner with a "Try again" action when `checkStatus` fails (`:259-265`); footnote now states the screen re-checks the server (`:323`). |
| `lib/features/remote_assistance/remote_session_controller.dart` | A successful `load()` clears `realtimeError` (`:599-604`), so a stale "Live updates interrupted" banner cannot outlive a confirmed server read. |
| `lib/data/repositories/supabase_remote_session_repository.dart` | On `RealtimeSubscribeStatus.subscribed` the signal stream emits an empty batch (`:251-255`), letting consumers clear the banner on channel recovery even when no new signal row arrives. |

Design notes:

* Every timer is a constructor parameter with a production default and `null`
  opt-out, matching the existing `refreshInterval` pattern in the codebase.
* Timers no-op while offline (`ConnectivityService.isOnline`) and are cancelled
  in `onClose`; none of them ends, mutates or revives a session.
* No polling was added to the session page beyond what already existed; the
  session controller keeps owning session state.

## 4. Verification (executed 2026-10-29, this tree)

| Check | Command | Result |
|---|---|---|
| Static analysis | `.fvm/flutter_sdk/bin/flutter analyze` | **PASS** — "No issues found!" (116.2 s) |
| Full Flutter suite | `.fvm/flutter_sdk/bin/flutter test` | **PASS** — 270 tests, "All tests passed!" |
| Touched suites | `flutter test` on devices/pairing-redeem/child-shell/reliability | **PASS** — 70 tests |
| Deno Edge Functions | `deno test --allow-all --no-check _shared/ pairing/ remote-session/` | **PASS** — 47 passed, 0 failed |
| Kotlin unit tests | `./gradlew :app:testDebugUnitTest` | **PASS** — BUILD SUCCESSFUL; XML totals 32 tests, 0 failures, 0 errors |
| SQL chain (10 migrations + all test files) | `psql -v ON_ERROR_STOP=1 …` on disposable `parentcontrol_final_155325` | **PASS** — EXIT=0, 0 `ERROR`, 0 `ASSERTION FAILED`; DB dropped after the run |
| Pairing invite race | `bash supabase/tests/run_pairing_invite_race.sh` | **PASS** — session B waited 3,314 ms on the advisory lock and joined A's request; 1 live request; DB dropped |
| Remote-session race | `bash supabase/tests/run_remote_session_race.sh` | **PASS** — session B waited 3,392 ms then `session_in_progress`; 1 open session; DB dropped |
| Debug APK | `bash scripts/build_debug_apk.sh` | **PASS** — `app-debug.apk`, 243,809,427 B, sha256 `e23277a5e7d7…` |
| Release APK | `bash scripts/build_release_apk.sh` | **PASS (build)** — `app-release.apk`, 110,610,854 B, sha256 `1bf8515d74e2…`; **debug-signed** (`CN=Android Debug` per `apksigner verify --print-certs`) |

New or rewritten regression tests:

* `test/features/child/child_shell_controller_test.dart` — a pending invite
  reaches an open child shell without a manual refresh (20 ms poll);
* `test/features/pairing/pairing_redeem_controller_test.dart` — pending status is
  polled to approval; a failing check-status becomes visible; polling disabled in
  the rest of the suite;
* `test/features/devices/devices_controller_test.dart` (new) — periodic refresh
  picks up a newly approved device; no fetch after `onClose`;
* `test/features/remote_assistance/remote_session_reliability_test.dart` — the
  old test that asserted the banner stayed up after a successful resubscribe was
  replaced: the banner clears when the channel re-subscribes and when a reload
  succeeds.

## 5. Pairing result

* Backend: **PASS** (health verified read-only; no change made).
* Client freshness fix: **PASS at controller level** (tests above).
* End-to-end on two real accounts/devices: **NOT TESTED**. This phase had no
  parent device (no emulator, no AVD) and the child phone was in human use.
  Nothing in this report claims a real pairing round-trip with the new clients.

Manual procedure to close this gap: [`docs/two-device-e2e-checklist.md`](two-device-e2e-checklist.md).

## 6. Audio session and duration

No session was started in this phase, so there is no new duration evidence.
Last measured evidence remains Stage 7 (`docs/stage7_two_device_end_to_end_report.md`
§6): server session stayed open 46 min; media stream lasted 14 min 16 s and
ended because the child account was externally signed out, not because of an
app-side cap. The 15-minute target is therefore **not met** in that run and
**not re-attempted** here.

Session-safety properties re-verified in code and SQL:

* terminal status stops media and timers (`remote_session_controller.dart:710-718`);
* a late realtime update cannot move a terminal session back to a live status
  (`:621-625`);
* server transition guard rejects terminal revival (`session_terminal` probe in
  `61_parent_controlled_lifetime.sql`, part of the green SQL chain);
* signing out is not treated as session completion (covered by the existing
  child shell tests; the session remains open for the parent to end).

## 7. Network recovery

* Controller level: **PASS**. Signal-stream errors retry with 1/2/4/8/16 s
  backoff; a re-subscribed channel and a successful reload both clear
  `realtimeError`; the new tests assert both transitions.
* Device level (Wi-Fi off → on, banner clears without manual refresh, audio
  resumes): **NOT TESTED** — needs the two-device setup.

## 8. Android platform limits (unchanged, not bypassed)

* `AudioAssistanceService` is a `microphone` foreground service with
  `stopWithTask=false` and `START_NOT_STICKY`; `GuardianService` is
  `START_STICKY`. Neither defeats an OEM/OS process kill.
* Force Stop always terminates capture; nothing in this phase claims otherwise.
* Microphone use stays visible in the notification shade and still requires the
  runtime permission plus child consent. No covert capture path was added.

## 9. Security and RLS validation

* The SQL chain applies every migration and all policy/function tests against a
  disposable database: **PASS**, including RLS negatives (`30_rls.sql`),
  realtime policy (`50_realtime_policy.sql`), parent-only end, and consented
  signaling (`62_signaling_consented_session.sql`).
* No RLS policy, grant or function was modified in this phase.
* The races prove one-open-session-per-device and one-live-invite-per-triple at
  the database level.
* No credentials, tokens or keys appear in this report; hosted access used the
  Dashboard SQL Editor read-only.

## 10. Deployment requirements (not executed)

The hosted `remote-session` bundle is **stale**: it inserts the session row
directly, sets `expires_at`, and never calls `request_remote_session`. The
database guard therefore exists but is **not active in production**.

To activate it, with explicit authorization:

1. Deploy `supabase/functions/remote-session/index.ts` (sha256 `45c4b30d91ef…`,
   13,066 B) through the Dashboard editor, replacing the current bundle.
2. No database change is required: `20261028000100_remote_session_concurrency.sql`
   is already applied. **Do not replay** `20261028000200` (non-idempotent).
3. Verify after deploy: a second `request` for a device with an open session
   returns `session_in_progress` instead of creating a row; `end` still works
   only for the requesting parent; `session_state` still returns a null expiry
   for a consented session.
4. Rollback: redeploy the previously saved bundle version from the Dashboard.
   No SQL rollback is needed, and no data migration is reversed.

`pairing` is current and needs no deployment.

## 11. Blockers

| Blocker | Why it blocks | Owner action |
|---|---|---|
| No parent Android device or AVD | Phase E cannot start | Provide a device signed in as the parent account, or approve creating an AVD on this machine |
| Child phone in human use | Cannot run a controlled child leg | Release the phone for the test window |
| Open orphan session `e84ba35e…` | Only the authenticated parent End flow may close it | Parent signs in on a device and ends it; do not delete the row manually |
| Stale `remote-session` deployment | Production has no duplicate-session guard | Authorize the redeploy in §10 |

## 12. Single next action

**Provide a parent device (physical or AVD) signed in as the parent account and
exclusive use of the child phone for one test window**, then run
[`docs/two-device-e2e-checklist.md`](two-device-e2e-checklist.md) from step 1.

## 13. Evidence index

* `docs/pairing-recovery-baseline.md` — pre-change state, hosted reads, defects.
* `docs/two-device-e2e-checklist.md` — 15-step manual matrix with checkpoints.
* `docs/stage7_two_device_end_to_end_report.md` — last device-level results and
  its correction notice.
* `docs/stage7_hosted_migration_apply_2026-10-29.md` — applied migrations and a
  non-destructive rollback for the lifetime migration.
* `docs/evidence/stage7/` — screenshots and sanitized log excerpts.
