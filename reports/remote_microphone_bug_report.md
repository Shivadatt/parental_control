# Remote Microphone — Bug Report

**Project:** `D:\parentcontrol_app` (Flutter 3.44.6 / Dart 3.12.2 via FVM, GetX, flutter_webrtc, Supabase)
**Date:** 2026-10-28
**Scope:** remote audio assistance session lifecycle, consent persistence, backend session concurrency, APK build configuration.
**Evidence rule:** every status below is based on a command or browser observation recorded in this session. No physical-device result is claimed.

Severity scale: P0 = data loss / privacy breach in production, P1 = core feature broken or consent violated, P2 = incorrect behaviour with workaround / hardening gap, P3 = cosmetic or tooling.

---

## BUG-RM-01 — Navigating away from the child session screen tore down the live microphone session

- **Severity:** P1
- **Status:** FIXED (automated evidence; physical device NOT TESTED)
- **Symptom (as audited):** after the child accepted a session, pressing Back or opening another screen ended capture. Re-entering the session screen showed a dead/inactive session.
- **Root cause:** `ChildSessionBinding` / `RemoteSessionBinding` registered `RemoteSessionController` with route-scoped `Get.lazyPut`. Popping the route disposed the controller, `onClose()` ran `_shutdown()`, which stopped the native capture service and terminated the session. Controller lifetime was coupled to the widget route instead of to the consented session.
- **Reproduction (pre-fix):** accept a session as child → open the session route → Back → mic service stops, session status changes, notification disappears.
- **Fix:**
  - New app-scoped `RemoteSessionRegistry` (`lib/features/remote_assistance/remote_session_registry.dart:18`), registered permanently in `lib/main.dart`, owns exactly one controller.
  - Both bindings now call `registry.acquire(sessionId: …, role: …, create: …)` instead of `Get.delete` + `Get.lazyPut`. Same (session, role) returns the identical instance; a different session disposes the old one first; an empty session id is fail-closed and never replaces or disposes a live controller.
  - `ChildSessionPage` uses `PopScope(canPop: !_ending)` — Back simply pops; no end call is made, no confirmation dialog for a live session.
- **Verification:**
  - `test/features/remote_assistance/remote_session_registry_test.dart` — 10 tests, including `popping the bound session route keeps the controller alive` and `acquire returns the same instance for the same session and role`.
  - `test/features/child/child_session_page_test.dart` — `back pops the route without ending a live session`, `repeated push and pop cycles reuse the same controller`.
  - Full suite: 239/239 pass.

---

## BUG-RM-02 — Recents swipe withdrew consent and killed the foreground service

- **Severity:** P1
- **Status:** FIXED (automated evidence; physical device NOT TESTED)
- **Symptom:** swiping the child app from Recents stopped the microphone foreground service, i.e. an explicit consent was silently withdrawn by a system gesture.
- **Root cause:** `AudioAssistanceService.onTaskRemoved()` called `stopSelf()`; additionally the Dart controller treated the `task_removed` stop reason as a session failure and terminated it.
- **Fix:**
  - `AudioAssistanceService.onTaskRemoved` (`android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt:295`) no longer stops. If the session is running it emits `audio_assistance_detached` (`NativeEventBus.emitAudioAssistanceDetached`, reason `task_removed_active`) and keeps the service, wake lock, notification (#4303 with Stop) and watchdogs alive.
  - `RemoteSessionController` (`lib/features/remote_assistance/remote_session_controller.dart:147,293,355`) adds `childUiDetached` and a public `audio_assistance_detached` event. `audio_assistance_stopped` with reason `task_removed` now only marks the UI detached; `permission_revoked`, `service_destroyed` and child stop still terminate.
  - The session screen shows a truthful "You can leave this screen" note and, on return, "Session is still live" / "Reconnect microphone" instead of claiming capture stopped.
- **Verification:** `remote_session_controller_test.dart` — `audio_assistance_stopped with task_removed only marks the UI detached`, `audio_assistance_detached for another session is ignored`, plus `permission_revoked` / `service_destroyed` still-end tests.
- **Residual limitation (documented, not a bug):** the notification's Stop remains the visible control; force-stop, reboot, OEM battery kills and permission revocation can still end capture.

---

## BUG-RM-03 — Parent "End Session" did not reach a child whose Flutter UI was gone

- **Severity:** P1
- **Status:** PARTIALLY FIXED — native watchdog implemented and unit-tested; **hosted `session_state` action is BLOCKED** (see BUG-RM-05 / deployment section of the implementation report)
- **Symptom:** with the child UI detached (Recents swipe, screen off, Dart isolate dead), nothing polled the session status on the child device, so a parent End left capture running until the child reopened the app or the OS killed the service.
- **Fix:** `AudioAssistanceService` now schedules a 15 s `ScheduledExecutorService` poll (`SESSION_WATCHDOG_INTERVAL_MS`, `AudioAssistanceService.kt:90`) that POSTs `{"action":"session_state","session_id":…}` to the `remote-session` function with device credentials. The pure decision function `sessionWatchdogAction(status)` (`AudioAssistanceService.kt:142`) stops the service (main thread, `stopAfterParentEnded`, reason `session_ended_by_parent`) only for terminal statuses (`ended`, `declined`, `expired`, `failed`) and keeps running for `requested`/`accepted`/`active`, `null`, unknown or network-error responses (fail-safe).
- **Verification:** `android/app/src/test/kotlin/.../AudioAssistanceSessionWatchdogTest.kt` — 7 JVM tests covering terminal/open/unknown/null and `shouldStopForSessionStatus`. All native tests pass (24/24).
- **Blocker:** the deployed `remote-session` bundle does **not** contain the `session_state` action (browser audit, `reports/supabase_browser_audit_2026-10-28.md` §4). Until the function is redeployed through the Dashboard, the watchdog receives an error response and keeps capture running (documented fail-safe, not a false "Live"). Parent End therefore still reaches an attached UI through Realtime immediately; the detached case requires the redeploy.

---

## BUG-RM-04 — Child "Stop sharing" left the microphone capturing when offline

- **Severity:** P1 (privacy: capture kept running after explicit stop)
- **Status:** FIXED
- **Symptom:** with no network, tapping Stop returned early before stopping the native microphone service, because the method required a successful server call first.
- **Root cause:** `ChildShellController.stopActiveSession()` began with an early return when the active session was null **or** the device was offline.
- **Fix:** removed the connectivity early-return (`lib/features/child/controllers/child_shell_controller.dart:419`). Local capture is always stopped and the registry released; a failed server end is surfaced as an honest, retryable error instead of silently keeping the mic open.
- **Verification:** `test/features/child/child_shell_controller_test.dart` — `offline Stop sharing still releases the microphone on this phone`. The test asserts the native stop call and registry release happen with the repository failing.

---

## BUG-RM-05 — Two concurrent parent requests could create two open sessions for one child device

- **Severity:** P1 (server-side; two conflicting mic sessions)
- **Status:** FIXED LOCALLY (DB + Edge Function + tests). **Hosted deployment BLOCKED** pending explicit confirmation.
- **Root cause:** the Edge Function's `request` action did a plain `insert` after lookup; no lock, no unique guard, no transaction. A double tap, client retry, or two parents could all pass the checks and insert.
- **Fix:**
  - New migration `supabase/migrations/20261028000100_remote_session_concurrency.sql` — `public.request_remote_session(p_device_id, p_parent_user_id, p_kind)` is `SECURITY DEFINER` with `set search_path = public, pg_temp`. It takes `pg_advisory_xact_lock(hashtextextended(device_id::text, 0))`, resolves/validates the device, expires stale open rows in-lock (moved to `expired`, never deleted), raises `session_in_progress` (P0001) if any `requested`/`accepted`/`active` row remains, otherwise inserts a 10-minute `requested` row. Execute is revoked from `public`/`anon`/`authenticated` and granted to `service_role` only.
  - `supabase/functions/remote-session/index.ts` calls the RPC and maps `session_in_progress` → HTTP 409, `device_not_found` → 404, `device_not_active` → 403, `invalid_kind` → 400; pure helpers in `guard.ts`.
  - No history is deleted; a valid existing session is never terminated to admit a new request.
- **Verification:**
  - Single-session SQL: `supabase/tests/60_remote_session_concurrency.sql` (duplicate rejection, expired row unblocking, different device allowed, service-role-only execute) — passes in the full chain (`EXIT=0`).
  - Two-session race: `supabase/tests/run_remote_session_race.sh` — session B waited **3381 ms** on the advisory lock, then received `session_in_progress`; device ended with **1** session row and **0** devices anywhere hold more than one open session. Result: **PASS**.
  - Deno: `supabase/functions/remote-session/guard_test.ts` (8 tests) + existing suite (36) pass; `deno check` OK.
- **Blocker:** hosted project `parent-control-prod` has no `request_remote_session` function and runs the old bundle (browser audit §4–5). Applying the migration and redeploying is a production change and requires explicit user confirmation.

---

## BUG-RM-06 — Microphone permission UI was available before the phone was linked

- **Severity:** P2 (product/consent hardening)
- **Status:** FIXED
- **Symptom:** an unlinked child device could see/open the microphone permission tile and mic self-test, i.e. microphone access was offered before any parent link existed.
- **Fix:**
  - `lib/features/child/tabs/child_settings_tab.dart:55,169` — `Microphone PermissionStatusTile` and the camera/mic self-test card render only when `controller.isEnrolled`; otherwise an `InfoBanner` explains that microphone access is enabled after linking and that phone setup must finish.
  - Controller-level guard: microphone permission is refused before enrolment and requested only after (`child_shell_controller.dart`, tests `microphone permission is refused before this phone is linked` / `…requested once this phone is linked`).
- **Verification:** `test/features/child/child_settings_gating_test.dart` — `an unlinked phone hides microphone access and the self test`, `a linked phone shows microphone access and the self test`; both pass.
- **Scope note:** this gates *permission prompts and self-test UI only*. The session accept path already required an enrolled device; no auth/RLS rule was relaxed.

---

## BUG-RM-07 — APK builds silently produced a backend-less client

- **Severity:** P1 (release blocker: app starts in "backend not configured" state)
- **Status:** FIXED
- **Symptom:** `flutter build apk` without `--dart-define-from-file` compiled fine but the client had no Supabase URL/anon key.
- **Fix:**
  - `scripts/check_live_config.sh` validates `.tools/live_config.env` by key name only: missing file → exit 2, privileged keys (`SERVICE_ROLE`, `DB_PASSWORD`, `TURN` secret names) → exit 3, non-HTTPS URL → exit 4; values are never printed.
  - `scripts/build_debug_apk.sh` / `scripts/build_release_apk.sh` abort before building when validation fails, select FVM (PATH `fvm`, else the pinned `.fvm/flutter_sdk`), and print the exact command with the config path only.
  - `docs/release-build.md` §7 and `README.md` document the flow.
- **Verification:** debug build log shows the validated command `flutter build apk --debug --dart-define-from-file=…/.tools/live_config.env`, `assembleDebug` OK, APK produced. Release build recorded in the implementation report §8.

---

## BUG-RM-08 — Sign-out / unlink could leave an app-scoped session controller alive

- **Severity:** P2
- **Status:** FIXED
- **Symptom (introduced by the lifetime fix, caught in review):** once controllers moved to permanent GetX registration, plain route disposal no longer freed them, so logout/unlink had to release them explicitly or the microphone could outlive the account session.
- **Fix:** `ParentSettingsController.signOut()` best-effort ends the session (`reason: 'signed_out'`), signs out, then `finally` releases the registry. `ChildShellController` releases the matching registry on stop, sign-out and unlink (`_releaseSessionRegistry`).
- **Verification:** `child_shell_controller_test.dart` — `sign-out stops the microphone service and ends an open session`, `unlink stops the microphone service and ends an open session`, `sign-out releases the app-scoped session controller`, `unlink releases the app-scoped session controller`, `a registry holding another session is left alone when stopping`. All pass.

---

## Summary

| Bug | Severity | Status |
|---|---|---|
| BUG-RM-01 route pop torn down live session | P1 | Fixed, tested |
| BUG-RM-02 Recents swipe withdrew consent | P1 | Fixed, tested (device not tested) |
| BUG-RM-03 parent End vs detached child UI | P1 | Native watchdog fixed/tested; hosted action BLOCKED |
| BUG-RM-04 offline child Stop kept mic | P1 | Fixed, tested |
| BUG-RM-05 concurrent duplicate sessions | P1 | Fixed locally, tested incl. real race; hosted BLOCKED |
| BUG-RM-06 mic access before link | P2 | Fixed, tested |
| BUG-RM-07 builds without client config | P1 | Fixed, build verified |
| BUG-RM-08 sign-out/unlink registry leak | P2 | Fixed, tested |

No P0 defect was found or introduced. No audio recording or cloud audio storage was added at any point.
