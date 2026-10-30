# Remote Microphone — Implementation Report

**Project:** `D:\parentcontrol_app`
**Branch:** `main` (no commits created during this work; changes left in the working tree)
**Toolchain:** Flutter 3.44.6 / Dart 3.12.2 via FVM (`.fvm/flutter_sdk`), Deno 2.9.4, PostgreSQL 16.9 (local disposable), Gradle wrapper (JVM unit tests)
**Date:** 2026-10-28
**Companion documents:** `reports/remote_microphone_bug_report.md`, `reports/supabase_browser_audit_2026-10-28.md`, `reports/remote_microphone_audit_report.md` (pre-existing, untouched)

No Supabase CLI command was run at any point. Hosted state was inspected through the official Dashboard in the in-app browser only, read-only.

---

## 1. Executive summary

The approved changes are implemented and locally verified:

1. **Session lifetime decoupled from Flutter routing.** A new app-scoped `RemoteSessionRegistry` owns the single `RemoteSessionController`. Popping the child session route, opening other screens, or returning no longer disposes the controller, stops the native service, or ends the session. Only a different session, logout/unlink, or an explicit termination releases it.
2. **Recents swipe no longer withdraws consent.** `AudioAssistanceService.onTaskRemoved` keeps the foreground service, wake lock, notification (with Stop) and watchdogs alive and emits a non-terminal `audio_assistance_detached` event. Dart no longer treats `task_removed` as a session end.
3. **Parent End reaches a child whose UI is gone.** The native service polls the backend every 15 s (`session_state`, device-authenticated) and stops capture on a terminal status, failing safe on network errors.
4. **Atomic per-device concurrency guard.** `public.request_remote_session` takes a transaction-scoped advisory lock keyed on the device id, expires stale rows in-lock, raises `session_in_progress` on a conflict, and never deletes history or terminates a valid session. The Edge Function calls it and maps the errors.
5. **Builds carry client configuration or do not build.** Validated wrapper scripts require `.tools/live_config.env` (key-name checks only, no value printing) and pass it via `--dart-define-from-file`.
6. **Microphone UI is gated behind enrolment.** An unlinked phone shows an explanatory banner instead of the microphone permission tile and self-test; the controller also refuses to request microphone permission before linking.

Verification: Flutter analyze clean, 239/239 Flutter tests, 24/24 Kotlin JVM tests, 44/44 Deno tests, full SQL chain exit 0, genuine two-session race PASS, debug APK built with the validated defines. Release APK: see §8. Physical-device lifecycle behaviour is **NOT TESTED** (§11). Hosted Supabase migration/redeploy is **BLOCKED** pending explicit confirmation (§7).

---

## 2. Original findings verified against the actual code

Each claim in the pre-existing audit was checked against the working tree before editing.

| Prior finding | Verified cause in code | Outcome |
|---|---|---|
| Popping the child session route kills capture (SEC-06 / P1) | `ChildSessionBinding`/`RemoteSessionBinding` registered the controller with route-scoped `Get.lazyPut`; route disposal ran `RemoteSessionController.onClose()` → `_shutdown()` → native stop + session end | Fixed (registry) |
| Recents swipe ends the session | `AudioAssistanceService.onTaskRemoved` set `isRunning=false`, emitted `audio_assistance_stopped("task_removed")` and called `shutdown()`; the manifest already had `android:stopWithTask="false"` (`AndroidManifest.xml:91`), so the flag alone did not help | Fixed (service keeps running; Dart ignores `task_removed`) |
| No server-side active-session exclusivity (SEC-07 / P2) | Edge Function `request` did a plain `insert` after lookup; no lock, no unique guard | Fixed locally (RPC guard); hosted BLOCKED |
| No parent-end delivery when the child UI is gone | Nothing polled session status on the device; only Realtime/UI drove termination | Fixed natively; needs the redeployed function for the hosted action |
| Builds without dart-defines ship an unconfigured client | No build wrapper validated `.tools/live_config.env`; `flutter build apk` alone omits the defines | Fixed (scripts + docs) |

Two further defects were found during implementation and are documented in the bug report: the offline child "Stop sharing" early-return (BUG-RM-04) and the pre-link microphone UI exposure (BUG-RM-06).

---

## 3. Files changed and why

### Flutter / Dart

| File | Change |
|---|---|
| `lib/features/remote_assistance/remote_session_registry.dart` **(new)** | App-scoped `GetxService` owning one controller; `acquire`, `releaseActive`/`releaseAll`; identical (session, role) returns the same instance, a different one disposes the old first, an empty session id is fail-closed. |
| `lib/main.dart` | Registers `RemoteSessionRegistry` permanently after `RepositoryBinding().dependencies()`. |
| `lib/features/remote_assistance/remote_session_binding.dart` | Resolves the registry and calls `acquire(...)` instead of `Get.delete` + `Get.lazyPut`; role validation unchanged (deny-by-default `view-only`). |
| `lib/features/child/child_session_binding.dart` | Same, and still requires `role == 'child'` (otherwise fail-closed empty session id). |
| `lib/features/remote_assistance/remote_session_controller.dart` | Adds `childUiDetached` (`:147`) and the `audio_assistance_detached` event (`:293`); `audio_assistance_stopped` with `task_removed` only marks the UI detached (`:355`), while `permission_revoked` / `service_destroyed` / child stop still terminate. |
| `lib/features/child/child_session_page.dart` | `PopScope(canPop: !_ending)` — Back pops without ending; truthful leave note; "Session is still live"/"Reconnect microphone" state when the session is active without a peer; retry on a failed end. |
| `lib/features/child/controllers/child_shell_controller.dart` | Active-session card state (`activeSession`, `hasActiveSession`, `isStoppingActiveSession`), `openActiveSession()`, `stopActiveSession()` (`:419`, always stops local capture even offline), `_loadActiveSession()` (`:345`) and a 20 s poll; releases the registry on stop/sign-out/unlink; microphone permission gate. |
| `lib/features/child/tabs/child_home_tab.dart` | Active-session `SectionCard` with "Open session" and destructive "Stop sharing" (`:146`–`:195`). |
| `lib/features/child/tabs/child_settings_tab.dart` | Microphone tile and self-test only when enrolled (`:55`, `:169`); explanatory banner otherwise. |
| `lib/features/settings/parent_settings_controller.dart` | Sign-out best-effort ends the session (`signed_out`), then releases the registry in `finally`. |

### Android / Kotlin

| File | Change |
|---|---|
| `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt` | `onTaskRemoved` no longer stops (`:295`); emits `audio_assistance_detached`; 15 s session-state watchdog (`:90`, `:470`–`:542`) with a pure decision function (`:142`); terminal status stops on the main thread with `audio_assistance_stopped` / `session_ended_by_parent`. KDoc states what still ends capture (force-stop, reboot, OEM cleaning, permission revocation). |
| `.../NativeEventBus.kt` | New `emitAudioAssistanceDetached(reason, sessionId)` (`audio_assistance_detached`). |
| `android/app/src/test/kotlin/.../AudioAssistanceSessionWatchdogTest.kt` **(new)** | 7 JVM tests for the watchdog decision. |

`AndroidManifest.xml`, `build.gradle` files, `pubspec.yaml`/`pubspec.lock` are unchanged: `stopWithTask="false"` was already correct, and no dependency or Gradle version was touched.

### Supabase

| File | Change |
|---|---|
| `supabase/migrations/20261028000100_remote_session_concurrency.sql` **(new)** | `public.request_remote_session(uuid, uuid, text)`, `SECURITY DEFINER`, pinned `search_path`, device-keyed advisory xact lock, in-lock expiry, `session_in_progress` rejection, service-role-only execute, rollback documented in the header. |
| `supabase/functions/remote-session/index.ts` | `request` calls the RPC and maps errors via `mapRequestRpcError`; new device-authenticated `session_state` action (`:142`). |
| `supabase/functions/remote-session/guard.ts` **(new)** | Pure `isOpenSessionStatus`, `mapRequestRpcError`, `sessionStatePayload` (device + child binding check). |
| `supabase/functions/remote-session/guard_test.ts` **(new)** | 8 Deno tests. |
| `supabase/tests/60_remote_session_concurrency.sql` **(new)** | Single-session guard assertions. |
| `supabase/tests/run_remote_session_race.sh` **(new)** | Two-session advisory-lock race proof. |
| `supabase/tests/README.md`, `supabase/tests/10_schema.sql` | Documented the new test/race; schema assertions for the RPC (security definer, pinned `search_path`, service_role-only). |

### Scripts / docs

| File | Change |
|---|---|
| `scripts/check_live_config.sh` **(new)** | Validates `.tools/live_config.env` by key name only; exits 2 missing file, 3 privileged key present, 4 non-HTTPS URL; never prints values. |
| `scripts/build_debug_apk.sh`, `scripts/build_release_apk.sh` **(new)** | Abort unless config validates, select FVM or the pinned SDK, build with `--dart-define-from-file`, print the command (config path only) and the artifact size/hash. |
| `docs/release-build.md` (§7), `README.md` | Document the validated build flow. |

### Tests (Flutter)

| File | Change |
|---|---|
| `test/features/remote_assistance/remote_session_registry_test.dart` **(new)** | 10 tests: instance reuse, disposal on session/role change, fail-closed empty id, idempotent release, route-pop survival, detached UI. |
| `test/features/child/child_session_lifetime_test.dart` **(new)** | Widget test for the lifetime policy. |
| `test/features/child/child_settings_gating_test.dart` **(new)** | Unlinked vs linked microphone UI. |
| `test/features/child/child_session_page_test.dart` | Rewritten for the new Back/leave policy; reconnect, repeated push/pop, terminal leave, media-card truthfulness, 320 dp layout, role refusal. |
| `test/features/child/child_shell_controller_test.dart` | Active-session selection, stop/offline stop, sign-out/unlink release, permission gating. |
| `test/features/remote_assistance/remote_session_controller_test.dart` | `audio_assistance_detached` handling and the stop-reason matrix. |

---

## 4. Route-lifecycle fix

- One controller per consented session, owned by `RemoteSessionRegistry` and registered with `Get.put(..., permanent: true)`.
- `acquire` returns the identical instance when `(sessionId, role)` match, so re-entering the route restores the live controller and its `session` state (R02).
- A different session or role disposes the previous controller **before** creating the next one, so at most one capture engine exists.
- An empty session id is the fail-closed binding path: it never replaces, disposes, or marks a controller active; if nothing is registered it registers a route-scoped transient so the page can still render its error state.
- `releaseActive()` is idempotent, clears fields before disposal (re-entrancy safe), disposes a controller that lost its Get registration, and yields one event-loop turn so `onClose()` teardown runs before navigation.
- Release points: child Stop, child sign-out, child unlink, parent sign-out, an explicit termination in `onClose()`, and acquiring a different session. Route disposal is not a release point.

## 5. Android service and Recents swipe

- `onTaskRemoved` emits `audio_assistance_detached` and leaves `isRunning`, `activeSessionId`, the wake lock, the notification (#4303, with Stop) and both watchdogs untouched.
- Dart receives `audio_assistance_detached` (filtered by session id) and sets `childUiDetached`; a `task_removed` stop reason is also treated as "UI detached", never as a session end.
- The permission watchdog (5 s) still ends capture on revocation; the session watchdog (15 s) ends it when the backend reports a terminal status.
- The service is `START_NOT_STICKY` and never restarts itself after process death; no capture is resumed without a new consented session and user interaction.
- Honest limitations (KDoc and report): force-stop, reboot, OEM task cleaners and system memory pressure still end capture. `stopWithTask="false"` is necessary but not sufficient on every OEM.

## 6. Backend concurrency

Mechanism (migration `20261028000100_remote_session_concurrency.sql`):

1. `pg_advisory_xact_lock(hashtextextended(p_device_id::text, 0))` serialises callers per device; different devices use different keys.
2. In-lock, the device is resolved and must be `active`.
3. Stale open rows (`requested`/`accepted`/`active` with `expires_at <= now()`) are moved to `expired` (history kept, never deleted), so an expired request cannot block forever.
4. Any remaining open row → `raise exception 'session_in_progress'` (SQLSTATE P0001). The exception rolls the whole RPC back; a valid session is never ended to admit a new request.
5. Otherwise a `requested` row with a 10-minute expiry is inserted and returned.

Security: `SECURITY DEFINER`, `search_path = public, pg_temp`, execute revoked from `public`/`anon`/`authenticated` and granted to `service_role` only (asserted by `10_schema.sql`). The Edge Function keeps the existing parent/family/device authorization and records the same audit event. No RLS policy, grant or table definition was changed.

Why not a partial unique index: its predicate cannot reference `now()`, so an expired open row would block inserts until another process cleaned it up, and there is no cleanup trigger. The advisory lock plus in-lock expiry is the atomic guard; rollback is a single `drop function`.

The `session_state` action is device-authenticated (`x-device-id`/`x-device-secret`), reads one row by id through the service client, and returns only `{session_id, status, expires_at}` when both `device_id` and `child_user_id` match the calling device; otherwise 403. No signal data, SDP/ICE or personal details are returned.

Tests: `60_remote_session_concurrency.sql`, `run_remote_session_race.sh`, `guard_test.ts` (see §9–§10).

## 7. Supabase Dashboard workflow and hosted status

**Method:** official Dashboard in the in-app browser, signed in, read-only; no SQL executed, nothing created/renamed/deleted, no new project (the organisation has exactly one project).

**Verified hosted state** (full evidence in `reports/supabase_browser_audit_2026-10-28.md`):

- Project: `parent-control-prod`, ref `hhqgreaoqulmfwfwarhc`, `ap-northeast-2` — matches the repo's non-secret config and `docs/backend.md`. Single org, single project.
- `public.remote_sessions`: 17 columns, the expected check constraints and four plain btree indexes, RLS enabled with exactly one `SELECT` policy for participants; no INSERT/UPDATE/DELETE policy.
- **No concurrency guard:** no partial unique index, no trigger, and `request_remote_session` is absent from the 13 functions listed.
- `remote-session` function is deployed (last deploy "2 days ago", ~1,003 invocations) as a minified bundle whose actions are `request`, `pending_child`, `respond`, `start`, `end`, `ice` — **no `session_state`**, and `request` is still a plain `insert` with no conflict handling.

**Status: BLOCKED.** Applying the migration and redeploying the function are production-impacting changes and require explicit confirmation, which has not been given. Nothing was changed in the hosted project.

**Exact steps once confirmed (browser only):**

1. Dashboard → project `parent-control-prod` → SQL Editor → paste the full contents of `supabase/migrations/20261028000100_remote_session_concurrency.sql` → review → Run. Expected: "Success. No rows returned".
2. Dashboard → Database → Functions: `public.request_remote_session` now listed; Database → Policies/Tables unchanged.
3. Dashboard → Edge Functions → `remote-session` → Code: replace `index.ts` with the local `supabase/functions/remote-session/index.ts` (the Dashboard bundles `guard.ts` through the relative import; if the editor does not accept multi-file functions, inline `guard.ts` — its contents are dependency-free apart from `_shared/envelope.ts`).
4. Deploy, then verify: a normal request returns a session; an immediate second request for the same device returns HTTP 409 `session_in_progress`; `session_state` returns `{session_id,status,expires_at}` for the owning device and 403 for another device.
5. Re-run the browser audit to record the new deployment and confirm the guard exists.

**Rollback:** Dashboard SQL Editor → `drop function public.request_remote_session(uuid, uuid, text);` then redeploy the previous `index.ts` bundle (the dashboard keeps deployment history). The earlier plain-insert behaviour returns; no table, row, policy or grant is affected.

**Until the redeploy:** the local `request_remote_session` guard is not active in production, and the child's native watchdog receives an error for `session_state`, which it treats as "unknown" and keeps capture running (fail-safe). Parent End with the child UI open still works through the existing Realtime/UI path.

## 8. Build configuration and build results

What changed:

- `.tools/live_config.env` is validated by key name (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); missing file → exit 2, privileged key names (`SERVICE_ROLE`, `DB_PASSWORD`, TURN secret names) → exit 3, URL not `https://` → exit 4. Values are never echoed.
- Both scripts abort before Gradle starts when validation fails, prefer `fvm` when on `PATH`, otherwise use the pinned `.fvm/flutter_sdk`, and print the exact command plus the config file **path** only.
- Release script reports whether `android/key.properties` exists; absence means Gradle likely signs with the debug key, and the script says so instead of claiming a signed release.

**Debug APK (R09): PASS**

```
[build_debug_apk] exact command:
  .fvm/flutter_sdk/bin/flutter build apk --debug --dart-define-from-file=<repo>/.tools/live_config.env
Running Gradle task 'assembleDebug'... 243.7s
√ Built build\app\outputs\flutter-apk\app-debug.apk
243,781,783 bytes  sha256 14030c3e2fa6d277627decbeaad8ef7c45b7ee8a692eb7783cf5c59432e9e20b
```

**Release APK (R10): PASS (build) — debug-signed, not a production artefact**

```
[check_live_config] RESULT: PASS (required keys present, no privileged key)
[build_release_apk] signing: android/key.properties absent -> Gradle likely falls back to debug signing
[build_release_apk] exact command:
  .fvm/flutter_sdk/bin/flutter build apk --release --dart-define-from-file=<repo>/.tools/live_config.env
Running Gradle task 'assembleRelease'... 266.3s
√ Built build\app\outputs\flutter-apk\app-release.apk (105.5MB)
110,594,470 bytes  sha256 989a899dc6485291f839a8174ebea4d79dc068713f2242cb74770e17493b8950

apksigner verify --print-certs:
  Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
```

The release build succeeds with the validated client configuration. Because `android/key.properties` is absent, Gradle signed it with the **Android Debug** key; this APK is not a production-signed release and must be re-signed with the upload keystore before distribution. No signing configuration was invented or committed.

## 9. Commands executed and sanitized results

| Command | Result |
|---|---|
| `.fvm/flutter_sdk/bin/flutter analyze lib test` | `No issues found!` |
| `.fvm/flutter_sdk/bin/flutter test` | `239: All tests passed!` |
| `cd android && ./gradlew :app:testDebugUnitTest` | `BUILD SUCCESSFUL`, 24 tests, 0 failures, 0 errors (includes 7 new watchdog tests) |
| `./gradlew assembleDebug` (invoked by the debug build) | `BUILD SUCCESSFUL` |
| `deno test` over `guard_test.ts` + four `_shared` test files | `ok | 44 passed | 0 failed` |
| `deno check` on the function sources | no type errors |
| Full SQL chain (stubs + all 8 migrations + all test files) on a disposable PostgreSQL 16.9 | `EXIT=0`, no `ERROR`, no `ASSERTION FAILED`, "ALL CONCURRENCY TESTS PASSED" |
| `bash supabase/tests/run_remote_session_race.sh` | PASS — B waited 3381 ms, `session_in_progress`, 1 session row, 0 devices with multiple open sessions |
| `bash scripts/build_debug_apk.sh` | PASS (see §8) |
| `bash scripts/build_release_apk.sh` | See §8 |
| Secret scan of new/changed reports, scripts and docs | no key, JWT, password or TURN credential found; scripts print key names/paths only |

All Flutter/Gradle commands used the FVM-pinned SDK; `fvm` itself is not on `PATH` in this environment, so the pinned `.fvm/flutter_sdk` binary was used directly.

Note: a bare `./gradlew test` fails in this environment before compiling any test, on a **pre-existing** plugin-path problem — `Could not create task ':flutter_secure_storage:testDebugUnitTest': this and base files have different roots: D:\parentcontrol_app\build\flutter_secure_storage and C:\Users\…\Pub\Cache\…\flutter_secure_storage-11.2.0\android`. That is a Gradle/Flutter build-directory-on-another-drive issue in a plugin subproject, not a code failure; the app module is tested with `:app:testDebugUnitTest`, which passes. No Gradle or dependency version was changed to work around it.

## 10. Automated test results

| Suite | Passed | Failed | Notes |
|---|---|---|---|
| Flutter (`flutter test`) | 239 | 0 | Includes 13 new lifetime/registry/gating tests and rewritten page tests |
| Kotlin JVM (`:app:testDebugUnitTest`) | 24 | 0 | Includes 7 new watchdog tests |
| Deno (`deno test`) | 44 | 0 | Includes 8 new guard/session-state tests |
| SQL single-session guard | pass | 0 | `60_remote_session_concurrency.sql` in the full chain |
| SQL two-session race | pass | 0 | Real lock contention, 3381 ms wait |

Backend lifecycle coverage (Phase F) — authorized/unauthorized request authorization is asserted in the existing Edge Function and RLS suites (unchanged); duplicate rejection and simultaneous requests are covered by the new SQL tests; expired-request handling, separate-device independence, parent/child termination idempotency and signaling behaviour remain covered by the pre-existing suites, which still pass. No request was sent to the hosted project.

## 11. Physical-device test results

**NOT TESTED.** A device and an emulator are attached to the machine, but no two-device session flow was driven, so no result is claimed. No automated test is labelled as a physical-device pass.

Manual procedure (two real Android devices, both with the debug APK from §8 installed and a linked family):

1. **Home button** — child accepts and joins; press Home. Expected: audible audio continues; notification #4303 stays visible. Return to the app: "Session is still live".
2. **Screen lock** — lock the child device 60 s. Expected: audio continues; notification present on unlock.
3. **Recents swipe** — swipe the child app away. Expected: audio continues on supported devices; notification remains with Stop; parent side remains Live.
4. **Notification Stop** — tap Stop. Expected: capture stops, session becomes `ended` (`ended_by_child`), parent UI leaves Live, no mic indicator.
5. **Parent Stop** — parent presses End. Expected (UI open): audio stops within ~1 s. Expected (UI detached): audio stops within ~15–20 s once the redeployed `session_state` action is live; before the redeploy this case is expected to keep running (documented blocker).
6. **Permission revocation** — revoke Microphone in Android settings during a session. Expected: capture stops within ~5 s, session reconciled, parent informed.
7. **Force-stop** — force-stop the child app. Expected: audio ends (OS guarantee); verify the parent UI does not remain falsely Live.
8. **Network loss** — enable airplane mode during a session. Expected: audio drops; local Stop still releases the microphone (covered by an automated test); restore network and verify status reconciles.

Record for each step: timestamp, device model/Android version, observed audio, notification state, backend session row status, parent UI state.

## 12. UI and unrelated-feature regression review

- `flutter analyze` clean; no unused imports, no dead code paths from removed helpers.
- No screen redesign: the only visual additions are the active-session card on the child home tab, the leave note on the child session page, the enrolment banner in child settings, and truthful status text.
- No audio recording or cloud audio storage added in Dart, Kotlin or SQL; the feature remains live one-way streaming.
- No dependency or SDK upgrades (`pubspec.yaml`, `pubspec.lock`, Gradle files unchanged).
- No auth, RLS, consent or pairing rule weakened. The migration only adds a function with `service_role`-only execute; the `session_state` payload is restricted to the owning device.
- No schema change other than the additive function. No data deleted; only the in-lock status transition of already-expired rows (which the previous code also performed elsewhere).
- Single-controller invariant enforced by the registry; `onClose` releases the peer connection and native service on every explicit termination; the service owns one wake lock and releases it in `onDestroy`; watchdogs are shut down in `onDestroy`.
- No new secret in source, scripts or reports; `.tools/live_config.env` remains untracked.
- Pre-existing user work (including `reports/remote_microphone_audit_report.md`, `.pgdata`, `.dart_tool` artifacts in the working tree) was left untouched; no reset/clean/stash was run.

## 13. Remaining risks and blockers

1. **BLOCKED — hosted concurrency guard and `session_state`.** Production still runs the old bundle and has no `request_remote_session`. Concurrent duplicate requests remain possible, and the native watchdog cannot confirm a parent end while the child UI is detached. Requires confirmation + Dashboard apply (§7).
2. **NOT TESTED — physical device.** All lifecycle claims are automated-only until §11 is executed, especially OEM-specific Recents/background behaviour.
3. **R10 — release build passes, but the APK is debug-signed.** `android/key.properties` is absent, so Gradle used the Android Debug certificate. A production upload keystore must be configured before distribution; no signing config was fabricated.
4. **Force-stop / process death.** Capture ends, but the session row stays `active` until the child reopens the app, stops, or it expires; the parent's Live indicator may lag. Not verified end-to-end (R14).
5. **Watchdog fail-safe.** Network errors, HTTP 401/404 and unparsable responses never stop capture (deliberate: a transient error is not proof of consent withdrawal). A deleted session row would therefore not stop capture; this app ends sessions rather than deleting them.
6. **Android limits.** Revoked permissions, force-stop, reboot, OEM task cleaners and memory pressure can still end capture; no claim of uninterrupted operation is made.
7. **Pre-existing repository hygiene (not introduced here).** `.tools/live_config.env` is already **tracked** in Git (committed in `08e6afc`) even though `.gitignore` lists `.tools/`; the file holds the client URL and publishable anon key only (validation confirms no service-role key, DB password or TURN secret). Removing it from tracking (`git rm --cached`) and rotating the anon key is the owner's decision and was not done.
8. **Pre-existing CLI script must not be used.** The tracked `scripts/complete_hosted_setup.sh` drives the Supabase CLI and can create a project. This task forbids the CLI and forbids creating projects, so it was neither run nor modified. The hosted change must go through the Dashboard as described in §7.

## 14. Rollback

**Code (all local, nothing committed):**

- Restore the previous bindings: `git checkout -- lib/features/remote_assistance/remote_session_binding.dart lib/features/child/child_session_binding.dart` — **but this reintroduces the P1 route-pop teardown**; prefer reverting individual commits/patches instead.
- To disable only the native watchdog: remove `startSessionWatchdog()` from `onStartCommand` and `stopSessionWatchdog()` from `onDestroy` (the service keeps running, parent-end detection while detached is lost).
- To restore the old Recents behaviour: revert `onTaskRemoved` to stop the service (undoes the approved consent policy).
- New files can be deleted safely if unused: `remote_session_registry.dart`, the race script, `guard.ts`/`guard_test.ts`, the three new Flutter test files, the watchdog test, the migration and `60_remote_session_concurrency.sql`.

**Hosted (only if §7 was applied):**

- `drop function public.request_remote_session(uuid, uuid, text);`
- Redeploy the previous `remote-session` bundle from the Dashboard deployment history.
- No table, row, policy or grant changes need reverting.

## 15. Final acceptance checklist

| ID | Scenario | Status | Evidence |
|---|---|---|---|
| R01 | Child navigates away from active session | **PASS (automated)** — physical NOT TESTED | Registry keeps the controller and never calls end on pop; `remote_session_registry_test.dart`, `child_session_page_test.dart` |
| R02 | Child opens other screens and returns | **PASS (automated)** | Identical instance returned for the same session; "repeated push and pop cycles reuse the same controller" |
| R03 | Child swipes app from Recents | **PASS (automated; native + Dart)** — physical NOT TESTED | `onTaskRemoved` keeps service/notification; controller ignores `task_removed`; watchdog tests + controller tests |
| R04 | Parent presses End Session | **PARTIAL — BLOCKED for detached UI** | Attached UI path covered by controller tests; detached path needs the hosted `session_state` redeploy |
| R05 | Child presses Stop Assistance | **PASS (automated)** | `stopActiveSession` ends server-side, stops the native service, releases the registry; offline regression test |
| R06 | Microphone permission revoked | **PASS (automated)** — physical NOT TESTED | `permission_revoked still ends the session`; native 5 s permission watchdog (pre-existing) |
| R07 | Two concurrent requests, one child | **PASS** | Real two-session race: B waited 3381 ms, `session_in_progress`, one open session |
| R08 | Requests for two different devices | **PASS** | SQL test: a different device is still allowed; fixture family2 keeps its independent session; whole-table scan shows 0 devices with multiple open sessions |
| R09 | Debug APK build | **PASS** | `assembleDebug` OK, validated defines, 243,781,783 bytes, sha256 `14030c3e…e20b` |
| R10 | Release APK build | **PASS (build)** — signed with the Android Debug key, not release-signed | `assembleRelease` OK, 110,594,470 bytes, sha256 `989a899d…8950`, apksigner DN `CN=Android Debug`; §8 |
| R11 | Existing automated test suite | **PASS** | 239 Flutter + 24 Kotlin + 44 Deno + SQL chain, 0 failures |
| R12 | Physical Android lifecycle test | **NOT TESTED** | No two-device run performed; procedure in §11 |
| R13 | Logout or device unlink | **PASS (automated)** | session ended + native stop + registry released on sign-out and unlink |
| R14 | Force-stop or fatal process death | **PARTIAL** | Audio ends by the OS and the service never restarts; parent false-Live not verified end-to-end |
| R15 | Existing UI and unrelated functionality | **PASS** | Analyze clean, diff review (§12), no redesign, no dependency/auth/RLS changes |

**Overall:** implementation, builds and local verification are complete; the task is **not fully complete** because the physical-device lifecycle run (R12) has not been executed, the detached-UI half of R04 depends on the hosted redeploy, and the hosted concurrency guard is BLOCKED pending confirmation. R14 is PARTIAL (parent false-Live indicator unverified).
