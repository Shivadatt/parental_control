# Microphone — Full Audit and Stage 2 Fix Report

**Project:** `D:\parentcontrol_app` (Flutter 3.44.6 via FVM, GetX, Kotlin, Supabase, flutter_webrtc 1.6.2)
**Package:** `com.parentcontrol.parent_control`
**QA devices:** parent `emulator-5554` (API 37 / Android 17); child realme RMX2161 `5HXWRGQ4IFU8WS4T` (Android 12 / API 31, ColorOS V12.1)
**Date:** 2026-10-28
**Scope:** Stage 1 read-only audit + Stage 2 source fixes. **No install, no device change, no backend change, no commit was performed.**

---

## 1. Executive summary

The audit found **no P0** (no hidden capture, no recording, no consent bypass, no defeat of Android privacy controls). It found six P1 defects around foreground-service startup, permission lifecycle, network recovery, and session termination truthfulness.

Stage 2 implemented fixes for those P1s plus the related P2/P3 correctness issues, added regression tests, and produced **APK build 4010**.

**What is proven today:** the source changes compile, the analyzer is clean, and all automated suites pass (207 Flutter, 17 Android, 36 Deno). The APK contains the microphone foreground-service declaration and permission.

**What is not proven:** every runtime behavior. Build 4010 was **not installed** (installation requires authorization), so no claim is made that the mic service starts, that capture survives HOME/lock, that ICE restart recovers audio, or that the notification appears on a real device. Those remain **NOT TESTED**.

**Audit limitation preserved:** the only live microphone evidence still comes from **build 4005**, which did **not** contain the mic foreground service. Builds 4007 and 4008 were produced outside this project's toolchain by other processes.

---

## 2. Artifact provenance

| Build | versionCode | Size (bytes) | SHA-256 | Built how | Live mic evidence |
|---|---|---|---|---|---|
| 4005 | 4005 | 217,389,522 | `649ef4d2…` | FVM, pre-staging tree | Yes — last live-tested |
| 4007 | 4007 | 217,394,214 | `6b7fcc83…` | external local build 12:48 | None |
| 4008 | 4008 | 217,388,210 | `23fc1e1f…` | external Flutter 3.38.8 14:12 | None |
| **4010** | **4010** | **239,532,180** | **`ec2141a02f1637670764cfba8b5cd37d0f9fdbce6ff65f49271527efd7c78db1`** | **FVM 3.44.6, this stage** | **None — not installed** |

Build 4010 verification (`aapt2 dump badging` / `xmltree`):

- `versionCode=4010`, `versionName=1.0.0`, `application-debuggable`
- permissions include `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `WAKE_LOCK`
- `AudioAssistanceService`: `exported=false`, `stopWithTask=false`, `foregroundServiceType=0x00000080` (microphone)

---

## 3. P1 defects fixed

| # | Defect (Stage 1) | Fix | Location |
|---|---|---|---|
| 1 | Child capture started **before** the microphone foreground service; the start result was discarded (`unawaited`). Capture could run with no confirmed service/notification. | Join now starts the service, **awaits** the `audio_assistance_started` event (5 s timeout) and only then calls `getUserMedia`. Any start failure/timeout aborts the join, stops tracks, closes the peer, and reports an error. | `lib/features/remote_assistance/remote_session_controller.dart:1048` (start), `:1206` (getUserMedia), `:290` (started handler) |
| 2 | `startForeground` had no error handling; the type guard was `>= Q` although the microphone type constant is API 30; notification permission was never required. | `startForeground` wrapped in `try/catch(Throwable)` with a typed 3-arg call only on API ≥ 30; on API 33+ the service refuses to start without `POST_NOTIFICATIONS`; failures emit `audio_assistance_start_failed` with a reason. | `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt:315` |
| 3 | Permission loss and one-time grants were unhandled once a session started. | Child session now polls microphone capability every 2 s while capturing; loss tears down tracks, stops the service, ends the session and reports `permission_revoked`. The service itself re-checks permission every 5 s and emits `permission_denied`. | controller `:1478`, service `:149` |
| 4 | No ICE restart and no signaling resubscription — network blips killed audio permanently. | ICE failure/disconnect > 3 s triggers `restartIce()` with renegotiation, max 2 attempts, 2 s/5 s backoff, then teardown + truthful end. Signal stream errors resubscribe with 1/2/4/8/16 s backoff (max 5) and a generation guard against stale callbacks. | controller `:1416`, `:572`–`:620` |
| 5 | Child Back navigation stopped local capture but left the **server** session live; the parent kept seeing a live session with a dead peer. | Child page uses `PopScope(canPop:false)`; Back shows a confirm dialog, blocks with an "Ending…" overlay, calls `endSession()` and pops only when the server confirms. Failure stays on the page with the real error, Retry, and "Stay in session". | `lib/features/child/child_session_page.dart:34` |
| 6 | Parent "End" returned early when local teardown threw, leaving the child capturing and the server session open. | `endSession()` now runs local teardown in `try/finally`, always attempts the server end, returns `true` only on confirmation, and exposes `endError`. The parent page keeps a truthful "may still be live" state with Retry, and requires a second explicit warning before leaving anyway. | controller `:1657`; `lib/features/remote_assistance/remote_session_page.dart:151`, `:242` |

Also fixed:

- **Role fail-closed:** invalid/missing role is view-only and cannot capture; bindings reject/normalize invalid roles (`remote_session_binding.dart`, `child_session_binding.dart`).
- **Truthful media state:** `isMediaLive` requires live tracks **and** a confirmed service on the child; both pages use it instead of `hasActivePeer` for "microphone on"/"audio live" claims.
- **Sign-out / unlink** now stop the microphone service and end open assistance sessions before auth/unlink (`child_shell_controller.dart:287`, `:890`, `:937`).
- **Self-test sheet** no longer captures on open: explicit Start, consent copy ("nothing recorded or sent"), Stop, and track cleanup in `dispose`.
- **Expiry formatting:** `relativeTime` now handles future timestamps ("in N min"); request tiles say "expired N min ago" instead of "expires N min ago".
- **Status wording:** the session label no longer claims "Live" for server state alone.
- **Copy:** the request dialog now states that the child must accept **and** join, and that the parent's media is never opened.
- **Overflow:** child media footer no longer uses a `Spacer` + fixed text row.
- **Async-gap guards:** all `BuildContext` uses after `await` are guarded with `context.mounted`; analyzer reports zero issues.

---

## 4. Verification results (Stage 2)

| Check | Command | Result |
|---|---|---|
| Static analysis | `fvm flutter analyze` | **0 issues** |
| Flutter tests | `fvm flutter test` | **207 passed, 0 failed, 0 skipped** |
| Android unit tests | `.\gradlew.bat :app:testDebugUnitTest` | **17 passed, 0 failed** |
| Deno function tests | `deno test supabase/functions/_shared/` | **36 passed, 0 failed** |
| Build | `fvm flutter build apk --debug --build-name=1.0.0 --build-number=4010` | **BUILD SUCCESSFUL** |
| APK manifest | `aapt2 dump badging` / `xmltree` | versionCode 4010, debuggable, FGS microphone `0x80`, WAKE_LOCK |

Note: an unrelated Flutter 3.38.8 installation on this machine left a stale Dart kernel cache (`Invalid kernel binary format version (expected 125, found 130)`), which caused three spurious test failures in an earlier verification pass. With the FVM 3.44.6 toolchain the same tests pass. The stale cache is a machine-state hazard, not a code defect.

---

## 5. Device verification — NOT TESTED

**No APK was installed and no device was touched in Stage 2.** Build 4010 exists on disk only. Both devices still run build 4008 from 14:14, which contains none of these fixes.

Consequently the following remain unverified and must not be reported as passing:

- foreground-service start, notification visibility, Stop action
- capture under HOME, sustained screen lock, Doze/OEM battery management
- ICE restart and audible recovery after network loss
- signaling resubscription
- runtime permission revocation and one-time-grant expiry
- child Back / Stop and parent End on real devices
- new session after an ended session
- human audibility, latency, TURN relay use

### Required authorization to proceed

1. Install `app-debug.apk` (4010, SHA-256 above) on `emulator-5554` and `5HXWRGQ4IFU8WS4T`.
2. Run the approval-gated test matrix from Stage 1 (T1–T11 functional, N1–N3 network, Q1–Q2 quality), including a TURN-only run.
3. Read-only Supabase Dashboard checks for TURN secret presence and function deployment freshness (see `docs/turn_configuration.md`).

---

## 6. Residual defects and known limitations

| Sev | Item | Detail |
|---|---|---|
| P1 | **Runtime unproven** | All fixes are source-verified only; no device evidence exists for build 4010. |
| P1 | **One-time grant detection is limited** | `PackageManager.FLAG_ONE_TIME` is not public SDK API, so `isMicrophoneOneTimeGrant` honestly returns `oneTime:false`. A one-time grant cannot be rejected pre-join; it is caught by the 2 s permission poll and the service's 5 s watchdog, which stop capture and end the session rather than capturing silently. |
| P2 | **No app-lifecycle observer** | Permission is polled on a timer only; there is no immediate re-check on `onResume`. Worst case is ~2 s of stale state. |
| P2 | **Parent liveness is approximate** | `isMediaLive` for the parent means peer + ICE connected, not confirmed inbound RTP audio. The UI can still lag actual playback. |
| P2 | **End confirmation is RPC success** | The repository `end` returns void, so `endSession()` confirms on a successful call plus terminal session state, not a server re-read. |
| P2 | **ICE glare risk** | Simultaneous restarts from both roles can race remote descriptions; recovery may exhaust and end the call. Candidates are buffered only before remote description. |
| P2 | **TURN not verified** | `turn_configured` is false unless `TURN_URL` and `TURN_SECRET` exist in the hosted Edge Function; secret presence and deployment freshness are NOT VERIFIED. Credential TTL default is 600 s vs a 1800 s session — recommend `TURN_TTL_SECONDS=3600` (behavior change, needs authorization). |
| P2 | **Notification channel can be blocked by the user** | If the child blocks the channel in Android settings, the OS hides it; the app refuses to start only when the permission itself is missing. This is an OS-level user choice and must not be circumvented. |
| P2 | **Wake lock has no timeout** | It is released on every stop/destroy path, but there is no defensive `acquire(timeout)`; a leaked service would hold it. |
| P3 | **`service_destroyed` cannot fire on hard process kill** | Expected; no resurrection logic is attempted, by design. |
| P3 | **Child media headline lag** | The card can take up to ~1 s (ticker) to reflect a newly confirmed service state. |
| P3 | **OEM battery management** | ColorOS may still kill or restrict background capture; no automatic prompt/allowlisting is implemented. |
| P3 | **Build provenance** | versionCode comes from `--build-number`, not `pubspec.yaml` (`1.0.0+1`). |

---

## 7. Android compatibility

| API | Android | Evidence | Status |
|---|---|---|---|
| 31 | 12 (realme, real device) | Source review only | NOT TESTED |
| 32 | 12L | — | NOT TESTED |
| 33 | 13 | Source: notification permission gate added | NOT TESTED |
| 34 | 14 | Source: typed FGS start, foreground-start restriction respected | NOT TESTED |
| 35 | 15 | Source review | NOT TESTED |
| 36 | 16 | Source review (compileSdk 36) | NOT TESTED |
| 37 | 17 (emulator) | Source review only | NOT TESTED |

Source-level guarantees added: typed `startForeground` for API ≥ 30, notification permission requirement on API ≥ 33, `START_NOT_STICKY` (no resurrection), truthful ongoing notification, Stop action, and no attempt to survive force-stop or permission revocation.

---

## 8. Security and privacy invariants

- Child consent is explicit and recorded server-side; ICE/session start is gated on it.
- Parent remains receive-only: no microphone request, no local track, no audio outgoing.
- Ongoing notification is truthful ("Microphone is being shared with your guardian.") with a Stop action; the notification permission is a precondition for starting capture on API 33+.
- No audio is recorded, buffered to disk, or uploaded as a sample; only numeric RTP counters are kept in memory.
- No permission-prompt bypass, no app-ops tampering, no privacy-indicator suppression, no force-stop defeat.
- No secrets in Flutter or docs; TURN credentials are minted server-side and documented with placeholders only.
- Evidence scan found no audio files and no secret material.

---

## 9. Files changed in Stage 2

**Production (Dart):** `remote_session_controller.dart`, `remote_session_binding.dart`, `remote_session_page.dart`, `remote_assistance_page.dart`, `remote_assistance_controller.dart`, `child_session_page.dart`, `child_session_binding.dart`, `child_shell_controller.dart`, `media_self_test_sheet.dart`, `child_requests_tab.dart`, `child_requests_page.dart`, `formatters.dart`, `remote_session.dart`, `device_admin_service.dart`.

**Android:** `AudioAssistanceService.kt`, `NativeBridge.kt`, `NativeEventBus.kt`, `AndroidManifest.xml` (WAKE_LOCK), plus `android/app/src/test/kotlin/.../AudioAssistanceStartGateTest.kt`.

**Tests:** `remote_session_reliability_test.dart` (new, 12), `child_session_page_test.dart` (new), `remote_session_page_test.dart` (new), `formatters_test.dart` (new), `media_self_test_sheet_test.dart` (new), `remote_assistance_copy_test.dart` (new), `remote_assistance_controller_test.dart`, `remote_session_controller_test.dart`, `child_shell_controller_test.dart`.

**Docs:** `docs/turn_configuration.md` (new), this file.

No commit was created: HEAD remains `b3f1e20`. Some Stage 2 files were staged by the sub-agents; nothing was reset, cleaned, reverted, or committed.

---

## 10. Completion status

| Area | Status |
|---|---|
| P1 source fixes | PASS — LOCAL VERIFIED |
| Automated regression | PASS — 207 / 17 / 36, analyze 0 |
| Identifiable build | PASS — 4010, SHA-256 recorded |
| Device behavior | NOT TESTED — install not authorized |
| TURN relay | NOT VERIFIED — hosted secrets/deployment not inspected |
| Overall | **INCOMPLETE — awaiting install authorization and live test matrix** |

No deployment, commit, or hosted configuration change was made.
