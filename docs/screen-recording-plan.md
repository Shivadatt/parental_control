# Child screen recording — implementation plan (proposal only)

**Status: NOT IMPLEMENTED, and the owner decided on 2026-10-27 to keep it that
way.** This document exists so that a future reversal does not have to re-derive
the constraints. It is a plan, not a description of existing code. Nothing in it
exists in the repository. It was written after the 2026-10-27 Phase 6B audit
confirmed the feature absent at five independent levels (evidence:
`.tools/evidence/full-qa/phase6b-recording-20261027/`, table R1–R16 in
[verification-report.md](verification-report.md#phase-6b--child-screen-recording-audit)).

## 0. Decision required before any code

**Asked and answered: on 2026-10-27 the owner chose to keep recording out of
scope.** Everything below is therefore dormant planning material, not an approved
work order.

Screen recording is **out of scope by design** in this project today, and the app
actively promises the opposite to the child:

- `docs/api-contract.md:545-546` — no screenshots, no recording.
- `docs/remote-assistance.md:83-94` — "No recording feature is present".
- `lib/features/child/tabs/child_settings_tab.dart:65` — "never records audio or
  video, takes screenshots…".
- `lib/features/settings/settings_body.dart:196`,
  `lib/features/remote_assistance/remote_session_page.dart:120`,
  `lib/features/child/child_session_page.dart:94` — same promise, parent side.

Building it therefore requires the owner to (a) reverse the product position, and
(b) rewrite every one of those strings, because shipping capture while the UI
says "nothing is recorded" would be a false statement to a minor. This is a
product decision, not an engineering task, and it is why the audit stopped at
"NOT IMPLEMENTED" rather than implementing.

Two viable framings, with very different cost:

| Framing | What it is | Cost |
|---|---|---|
| **A. Live view only** (recommended) | Keep WebRTC, add screen as a third track. Nothing is stored, so no bucket, no retention, no leak surface | Native + WebRTC track work only |
| **B. Recorded clips delivered to parent** | Full MediaProjection → MP4 → Supabase Storage → parent playback | Everything in §1–§5 plus a retention and legal story |

Sections 1–5 below describe **B**, since that is what the Phase 6B brief asked
about. A is a strict subset of the native work.

## 1. Android native layer

New files under `android/app/src/main/kotlin/com/parentcontrol/parent_control/`:

- `ScreenCaptureManager.kt` — owns `MediaProjectionManager.createScreenCaptureIntent()`,
  the resulting `MediaProjection`, the `VirtualDisplay` and the encoder surface.
  Single-session by design: a second request returns "already capturing" instead
  of stacking displays.
- `ScreenRecordService.kt` — a foreground service that must be created **before**
  `getMediaProjection()` is called, and stopped in `onDestroy()` with the ordering
  `VirtualDisplay.release()` → `MediaProjection.stop()` → `MediaRecorder.release()`
  → `stopSelf()`. `MediaProjection` is invalidated when the service dies, so the
  service is the session's lifetime owner, not the activity.
- Encoder: `MediaRecorder` with `VideoCodec.H264` writing to
  `context.cacheDir` (app-private, no `WRITE_EXTERNAL_STORAGE`). Audio: **no
  `MIC` source** in v1 — see §4.

Manifest changes (`android/app/src/main/AndroidManifest.xml`):

- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>`
- `<service android:name=".ScreenRecordService" android:foregroundServiceType="mediaProjection"/>`

`NativeBridge.kt` additions (the current 19 methods have nothing capture-related):
`requestCaptureConsent` (launches the system intent, returns a result code),
`startRecording`, `stopRecording`, `getRecordingState`, and an event-channel
`recording-state` topic mirroring the existing `NativeEventBus` pattern. Consent
must be requested through an `Activity` result — a service cannot obtain a
`MediaProjection` token.

### Version-specific constraints (both test devices)

| Concern | realme RMX2161, API 31 | Pixel 9a emulator, API 37 |
|---|---|---|
| Foreground-service start | Ordinary start allowed | `startForegroundService` from the UI is allowed; a **pending intent** path is allowed as a background start exemption |
| Consent | Per-session dialog already required | Android 14+ makes the token **single-use and time-limited**; re-arming after a service restart needs a fresh dialog, and the app must handle `ErrorCode` ERROR_INVALID / ERROR_SECURE |
| Notification | Ordinary FGS notification | Full-screen-intent and system-overlay rules apply; the FGS notification must show before the projection is created |
| Secure surfaces | Frames are black for FLAG_SECURE | Same; plus system media-projection indicator in the status bar |
| Encoder | **UNPROVEN** — `adb shell screenrecord` is refused by ColorOS SELinux on this unit | Verified working (5 s H.264 `avc1`) |

The realme encoder gap is a **P1 prerequisite**: prove a MediaProjection capture
works on the physical child device before writing delivery code, otherwise the
whole feature is emulator-only.

## 2. Dart layer

- `lib/data/models/recording.dart` — metadata model (`id`, `deviceId`, `familyId`,
  `startedAt`, `durationMs`, `sizeBytes`, `width`, `height`, `sha256`,
  `status: local|uploading|uploaded|failed|deleted`, `storagePath`).
  `RemoteSession` currently has none of these fields.
- `lib/data/repositories/recording_repository.dart` — the **first** Supabase
  Storage usage in this app; `lib/` currently performs no file I/O at all.
- `lib/features/child/recording_controller.dart` — state machine
  `idle → consentPending → recording → stopping → uploading → done/failed`,
  with a hard rule that no state is entered without an explicit tap.
- Child UI: a persistent visible banner plus a stop affordance that survives
  navigation; the existing `PopScope` pattern from `remote_session_page.dart` is
  the model for "leaving the page stops capture".
- Parent UI: a recordings list on the device detail page and a playback route.
  There is no video player dependency today (`pubspec.yaml` has none), so
  `video_player` or equivalent must be added.
- `path_provider` is only a transitive lock entry today and is never imported; it
  would become a direct dependency.

## 3. Backend

Nothing exists: 18 tables, no recording table, zero `bytea` columns, zero Storage
buckets referenced anywhere, and no Edge Function handles media bytes.

- Migration `recordings` table: metadata only, FK to `devices` and `families`,
  `on delete cascade`, status enum, `storage_path`, `sha256`, `duration_ms`,
  `size_bytes`.
- Private `recordings` bucket. No public objects. Client policies: parent
  `SELECT` via the existing `private.is_family_parent(family_id)` helper; **no**
  client `INSERT`/`UPDATE`/`DELETE` — writes go through a service-role Edge
  Function, matching the pattern already used by `device-telemetry`.
- Edge Function `recording`: issues a short-lived upload URL, finalises metadata,
  mints playback links, and deletes. Device authentication should reuse the
  `x-device-id` / `x-device-secret` constant-time SHA-256 scheme rather than
  inventing a second one.
- Retention: `purge_expired_recordings()` on the existing cron, plus a
  `recording_retention_days` family setting. Note that **no automated purge runs
  today at all** — even audit logs are never deleted, and hosted `CRON_SECRET` is
  unset — so retention is dead code until cron is configured.
- Cross-family isolation must be tested with direct API calls using a modified
  `recording_id`, not just through the UI.

## 4. Audio

The brief asks whether microphone audio belongs in recordings. Today the app's
only audio path is `getUserMedia` → `peerConnection.addTrack` in remote
assistance; nothing is ever written to disk. For recording:

- Screen-only (no `AudioSource.MIC`) is the safer default and keeps the existing
  "no audio is recorded" promise intact.
- Adding `MIC` means a second runtime permission, a second disclosure string, and
  capture of everyone in the room — a materially different privacy posture than
  capturing the child's own screen. Recommend excluding it from v1.
- `AudioPlaybackCapture` (API 29+) captures other apps' audio, which raises the
  same third-party-content problem as full-display video. Not recommended.

## 5. Consent and anti-covert rules

- Consent is Android's dialog, always. A parent request may only ever *arm* a
  workflow; the child must tap to start, and the system prompt appears per
  session. There is no token caching across sessions on API 34+.
- Recording must never start from login, pairing, reboot, `BootReceiver`,
  remote-assistance acceptance, or a policy update. `BootReceiver` and
  `GuardianService` must be explicitly excluded from any capture code path.
- Visible status at all times: in-app banner plus the Android media-projection
  indicator. If either is missing, fail closed and stop.
- Stop must be reachable from any screen, and a crash must not leave a projection
  alive — the service owns the token, so service death releases it.
- No video bytes, signed URLs or tokens in logs. Uploads resumable, with the
  metadata row created only after a verified object exists, so an interrupted
  upload cannot leave a phantom "completed" recording.

## 6. Test plan (what would have to pass for a real PASS)

1. Realme: record a synthetic screen with a unique marker; verify transitions,
   duration, resolution, orientation, frame continuity by pulling and probing the
   file.
2. Deny the consent dialog → recording must not start and the UI must say so.
3. Kill the app mid-recording → no projection remains (`dumpsys media_projection`
   returns null), temp file bounded and removed.
4. Background, screen lock, incoming call, policy update during capture.
5. Upload with network loss at 50 % → resumes or reports `failed`, never
   "completed".
6. Second QA family attempts read/download by guessing a `recording_id` → denied
   at the RLS and bucket level.
7. Public bucket URL probe → 400/404.
8. Deletion → object gone, playback link dead, retention cron removes expired rows.
9. Regression: `integration_test/child_media_selftest_test.dart:173` and the
   consent-gating tests in `test/features/remote_assistance/` assert the *absence*
   of capture and will need deliberate updating — that change is itself the
   evidence that the privacy promise changed.

## 7. Rough effort

- Framing A (live screen share, no storage): ~1–1.5 weeks — native capture
  surface, WebRTC screen track, consent UI, two-device testing.
- Framing B (recorded clips + delivery): ~3–4 weeks — all of A plus encoder/file
  handling, the first Storage integration and bucket policies, an Edge Function,
  retention cron (currently unconfigured), a player dependency, cross-family
  access testing, and the contract/UI rewrite.
- Plus one unbounded prerequisite: proving the realme's encoder path works at all.
