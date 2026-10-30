# Stage 5 — Background Audio Survival When the Child UI Closes

Date: 2026-10-29
App: Parent Control 1.0.0+1 (debug)
Scope: keep an already-authorized child audio assistance session running when
the Flutter UI is disposed, backgrounded, recreated or swiped from Recents,
without bypassing Android privacy rules or the parent's end authority.

> Status: **partial / verification blocked**. The ownership and lifecycle
> changes are implemented and covered by automated tests. The two-device matrix
> was executed on the build before the final UI-truthfulness fixes; the final
> build was installed but a live re-check was blocked by the child-side network
> and later by revoked QA device links. See `docs/stage6_account_and_media_recovery_report.md`.

---

## 1. Confirmed root cause

1. **Route-scoped controller ownership.** The session route used `Get.lazyPut`
   for `RemoteSessionController`. Popping the route disposed the controller and
   its `onClose()` released capture, the peer connection and the microphone
   service, even though the server session was still authorized and consented.
2. **Activity-owned Flutter engine.** The default `FlutterActivity` owned the
   engine. Finishing or recreating the Activity destroyed the engine, which
   destroyed Dart and the WebRTC peer/tracks with it. A foreground service
   alone did not preserve them.
3. **Activity-scoped native bridge.** `NativeBridge` held the Activity; if the
   bridge died with the UI, later service events had no listener even when the
   service survived.

The server session was never the thing that failed; the client conflated UI
lifetime with capture lifetime.

---

## 2. Architecture and resource ownership changes

### 2.1 Process-scoped engine

`android/app/src/main/kotlin/com/parentcontrol/parent_control/MainActivity.kt:24-65`
hosts a single cached `FlutterEngine` (`ENGINE_ID = "parentcontrol_main_engine"`):

- `getCachedEngineId()` reuses the engine across Activity instances.
- `ensureEngine()` creates it once on `applicationContext`, starts the Dart
  entrypoint exactly once, and puts it in `FlutterEngineCache`.
- `cleanUpFlutterEngine()` only detaches the Activity reference; the engine and
  its WebRTC peers outlive the UI.

`NativeBridge.kt:29-39` is engine-scoped rather than Activity-scoped. Permission
prompts and foreground-only intents use the currently attached Activity; session
events do not depend on one.

### 2.2 App-scoped controller registry

`lib/features/remote_assistance/remote_session_registry.dart:23-134` owns the
single live controller:

- `acquire(sessionId, role)` returns the same instance for the same
  `(sessionId, role)`, so a re-pushed route or deep link reattaches instead of
  restarting capture.
- A different session/role disposes the previous controller first, so exactly
  one capture engine can be live.
- Empty session ids fail closed and never touch the live controller.
- `releaseActive()` is the explicit release used by logout/unlink; it never ends
  the server session.
- On resume it calls `reconcileAfterResume()`; the pause/hide path does nothing,
  because backgrounding is not consent withdrawal.

`main.dart:35` registers the registry permanently; both route bindings resolve
it (`remote_session_binding.dart`, `child_session_binding.dart`).

### 2.3 Detach-only controller disposal

`lib/features/remote_assistance/remote_session_controller.dart:2133-2160`
(Stage 5 revision) makes `onClose()` cancel timers, subscriptions and the ticker
but **not** stop the microphone service, close the peer or call the server end
RPC. `releaseNativeResources()` is the explicit local teardown used only for
logout, unlink, session replacement or a confirmed failure.

### 2.4 Independent microphone foreground service

`android/.../AudioAssistanceService.kt`:

- `microphone` foreground service, `stopWithTask=false`, notification id 4303,
  partial wake lock, `START_NOT_STICKY`.
- `startDisposition()` (`:168-199`) reports `START`, `ALREADY_RUNNING` or
  `BUSY_OTHER_SESSION`; it never tears down a different live session.
- `onTaskRemoved()` (`:469-477`) emits the non-terminal
  `audio_assistance_detached` event and keeps running. A Recents swipe is not a
  stop request.
- Capture heartbeat: Dart confirms every 10 s; the service stops after 45 s
  without confirmation (`CAPTURE_HEARTBEAT_TIMEOUT_MS`, `:117`), so a
  microphone notification cannot outlive real capture.
- Parent-end watchdog (15 s) stops the service when the server session ends;
  permission revocation stops it as well. Neither path calls the server end RPC.

---

## 3. Truthful media status

`isMediaFlowing` is derived from cumulative WebRTC `outbound-rtp` /
`inbound-rtp` audio packet/byte deltas, not from ICE/DTLS alone
(`remote_session_controller.dart:1839-1887`). It is reset on every disconnect,
teardown and new connection. The UI now distinguishes Active, Checking audio,
Audio unavailable, Reconnecting and Sharing stopped, and never says
“Microphone live” without RTP evidence.

Two truthfulness defects found during the matrix were fixed before the final
build:

- the child dashboard claimed “Microphone sharing in progress / guardian can
  hear” without a running service or after permission revocation;
- the leave note claimed a visible Android notification even when the realme
  channel importance was `NONE`.

---

## 4. Verification recorded

### 4.1 Automated

| Command | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 251 passed (Stage 5; 252 after the Stage 6 control test) |
| `gradlew :app:testDebugUnitTest` | 32 passed, 0 failed |
| `deno test supabase/functions/_shared/` | 36 passed |
| Local SQL suite (ten migrations through `20261028000300`, test `62`) | EXIT=0, all assertions passed |

Stage 5 APK: `app-debug.apk`, 243,790,060 bytes, SHA-256
`948b6b2a0d1fe9b5f013960f095edc7b7436bd982d8e9a46069760be74cf4eef`.
A later Stage 6 build (`d8eecfa5…`, 243,790,747 bytes, 2026-10-29 08:13)
adds the Stop-control fix and supersedes it; that build is the one installed on
both test devices and is documented in the Stage 6 report.

### 4.2 Two-device matrix

Executed with the parent on `emulator-5554` and the child on realme RMX2161
Android 12, on build `5bef45d6…` (the build before the final UI-copy fixes):

| Scenario | Result |
|---|---|
| Child Home 30 s, audio live | PASS |
| Lock 135 s, audio continues | PASS |
| Recents swipe, process/FGS survive, parent still live | PASS |
| Reopen, same process/session, single service | PASS |
| Network loss: truthful Reconnecting, session stays open | PASS |
| Automatic recovery after network return | **FAIL** |
| Explicit rejoin same session | PASS |
| Dashboard Stop sharing releases mic/service, session open | PASS |
| Force Stop: process/service gone, parent truthful, session open | PASS (not bypassed) |
| Parent End | PASS |
| Microphone permission revocation | PASS (no auto restart) |
| TURN refresh | **BLOCKED** (no relay configured) |

Evidence: `docs/evidence/stage5/` (25 files, including `dumpsys activity
services` captures for swipe and lock).

### 4.3 What is not verified

- The final Stage 5 build and the Stage 6 build were not re-run through the live
  matrix. A post-fix attempt was blocked by child-side Edge Function transport
  failures (screenshots `postfix-child-accept-network-failed.png`,
  `postfix-child-heartbeat-failed.png`); a host diagnostic confirmed the
  function and the `accept` contract were reachable, so this was an environment
  problem, not a code regression. Later the QA devices were revoked server-side.
- No audible tone/loopback proof or RTP logcat capture was archived. Media
  liveness is proven by the UI's RTP-derived state on the devices, not by a
  recorded audio sample.

---

## 5. Required manual settings

- The realme channel `audio_assistance_channel` had importance `NONE`; the
  service still ran, but the ongoing notification was not visible. No setting
  was changed silently.
- Battery optimization and OEM auto-start/freeze settings were left at their
  defaults. No guarantee is made that disabling them would keep the process
  alive.
- For testing only, the lock screen was temporarily disabled and rotation was
  locked; the lock screen was restored. These are test aids, not requirements.

---

## 6. Limitations

- **Force Stop, process death and OEM task cleaners end media.** The app does
  not and cannot bypass them. The session remains open server-side for a later
  explicit rejoin.
- **Automatic media recovery after an unrecovered connection loss is not
  implemented.** Both sides must explicitly rejoin the same session; this is
  covered in the Stage 6 report.
- **No TURN relay** is configured; STUN-only connectivity can fail on restrictive
  networks.
- The hosted backend still runs the pre-Stage-4 lifetime/signaling policy. The
  three `20261028*` migrations are repo-only and were not deployed.

---

## 7. Evidence index

- `docs/evidence/stage5/child-15-live.png`
- `docs/evidence/stage5/child-21-recents.png`, `child-22-after-swipe.png`
- `docs/evidence/stage5/child-23-reopen.png`
- `docs/evidence/stage5/child-31-netlost.png`, `child-33-reconnect-visible.png`
- `docs/evidence/stage5/child-37-stop-visible.png`, `child-41-session-after-stop.png`
- `docs/evidence/stage5/parent-12-active.png`, `parent-25-after-child-swipe.png`
- `docs/evidence/stage5/parent-34-after-force-stop.png`
- `docs/evidence/stage5/parent-43-perm-revoked.png`
- `docs/evidence/stage5/child-swipe-services.txt`, `child-lock-services.txt`
