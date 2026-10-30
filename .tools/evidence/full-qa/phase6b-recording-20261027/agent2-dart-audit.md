# Agent 2 — Dart/Flutter layer audit: does child-screen recording exist?

Date: 2026-10-27 · Scope: `D:/parentcontrol_app/lib/**`, `pubspec.yaml`, `pubspec.lock`
Mode: READ-ONLY. No project file was modified.

## VERDICT: NOT IMPLEMENTED (and intentionally excluded by product design)

Child-screen recording does not exist anywhere in the Dart/Flutter layer — no
start/stop controller, no UI action, no metadata field, no storage path, no
upload, no download, no playback, and no parent-side recording list. The app
instead ships explicit user-facing privacy promises that recording never
happens.

A *separate* feature, remote assistance (`flutter_webrtc`), does open the camera
and microphone live, after explicit child consent, and never persists media.

---

## 1. Dependency evidence (pubspec)

`pubspec.yaml` (30-47) declares 12 direct dependencies. Full list relevant to capture:

| Dependency | line | Capture capability | Class |
|---|---|---|---|
| `flutter_webrtc: ^1.6.2+hotfix.4` | 43 | camera + mic live P2P A/V (getUserMedia) | (b) |
| `mobile_scanner: ^7.4.2` | 42 | `BarcodeCapture` for QR pairing only | (c) |
| `qr_flutter: ^4.1.0` | 41 | QR *generation* only | (c) |
| `supabase_flutter: ^2.18.3` | 38 | Postgres/Realtime/Edge; `.storage` never called | (c) |
| `get`, `shared_preferences`, `flutter_secure_storage`, `connectivity_plus`, `crypto`, `uuid`, `intl`, `cupertino_icons` | 36-47 | no capture | (c) |

NOT present (searched `pubspec.yaml` and the full `pubspec.lock` package list):
- No `screen`/`recording`/`media_projection`/`desktop_capture`/`native_pdf`-style package.
- No `camera`, no `record`, no `audio_recorder*`, no `flutter_video_*`.
- No `video_player`, no `chewie`, no `media_kit`, no `just_audio`, no `audioplayers`.
- No `file_picker`, no `share_plus`, no `sharing_intent`.
- `path_provider` appears **only** as a transitive dependency in `pubspec.lock`
  (lines 514-560, platform plugins of `mobile_scanner`/`integration_test`).
  It is **not** a direct dependency and is **never imported** in `lib/`
  (grep `PathProvider|getApplicationDocuments` → 0 hits in `lib/`).

## 2. Keyword classification (case-insensitive, over `lib/`, 139 Dart files)

Raw occurrence counts (`grep -r -i -o`):

| term | hits | (a) screen recording | (b) camera/mic WebRTC | (c) unrelated |
|---|---|---|---|---|
| `record` | 79 | **0** | 21 (prose "Nothing is recorded" + `consentRecorded`) | 58 |
| `capture` | 10 | **0** | 3 (prose "screen capture are taken", `_handleCapture` nearby) | 7 (`BarcodeCapture` ×3, `capture.barcodes`, "captures passwords", camera/mic capture) |
| `projection` | 0 | 0 | 0 | 0 |
| `video` | 89 | **0** | 89 (`SessionKind.video`, `RTCVideoRenderer`, `RTCVideoView`, `getVideoTracks`, `videoWidth/Height`, `Icons.videocam*`) | 0 |
| `screenshot` | 4 | **0** | 4 (all privacy prose: "no screenshots", "never takes screenshots") | 0 |
| `snapshot` | 16 | **0** | 0 | 16 (installed-app policy snapshot: `hasLoadedSnapshot`, `appsSnapshotMessage`) |
| `frame` | 16 | **0** | 4 (`_framesRendered`, "Video frames", `onFirstFrameRendered`) | 12 (`addPostFrameCallback`, "framework assertion") |
| `stream` | 122 | **0** | ~40 (`MediaStream`, `_localStream`, `_stopStream`, `getUserMedia`) | ~82 (Dart `Stream`/`StreamController`/`StreamSubscription`/`receiveBroadcastStream`) |
| `display` | 189 | **0** | 0 | 189 (`displayName` / `display_name` / `display` in `Get.toNamed`) |
| `mp4` | 0 | 0 | 0 | 0 |
| `upload` | 65 | **0** | 0 | 65 (telemetry only: `uploadUsage`, `uploadLocation`, `uploadReportedApps`, `uploaded_at`) |
| `storage` | 0 | 0 | 0 | 0 |
| `bucket` | 0 | 0 | 0 | 0 |
| `playback` | 0 | 0 | 0 | 0 |
| `player` | 0 | 0 | 0 | 0 |

Class (a) total = **0 occurrences across all 14 terms.**

Additional negative greps, all **0 hits** in `lib/`:
`recordToFile`, `recordToBuffer`, `MediaRecorder`, `startRecord`, `stopRecord`,
`screen.?record`, `MediaProjection`, `VirtualDisplay`, `ImageReader`,
`desktop_capture`, `.mp4`, `bucket`, `PathProvider`, `writeAsBytes`,
`writeAsString`, `openSink`, `ByteData`, `Uint8List`, `base64` (except JWT decode).

`dart:io` is imported in 5 files (`app_exception.dart:2`,
`supabase_auth_repository.dart:2`, `supabase_pairing_repository.dart:2`,
`device_admin_service.dart:2`, `edge_api.dart:3`, `supabase_family_repository.dart:2`)
and is used **only** for `SocketException` (network error mapping) and
`Platform.isAndroid` (`device_admin_service.dart:22`). **No `File`/`Directory`
API is used anywhere in `lib/`.**

## 3. Complete screen inventory — no recording action on any screen

Routes: `lib/app/routes/app_routes.dart:1-32`, bound in
`lib/app/routes/app_pages.dart:56-186` (26 routes total).

Parent-side (20): `/`, `/configuration`, `/role-selection`, `/auth/login`,
`/auth/register`, `/auth/verify-email`, `/parent` (ParentShellPage),
`/parent/family-setup`, `/parent/family`, `/parent/pairing/redeem`,
`/parent/pairing/requests`, `/parent/devices/detail`, `/parent/app-restrictions`,
`/parent/screen-time`, `/parent/location`, `/parent/safe-zones`, `/parent/alerts`,
`/parent/assistance` (RemoteAssistancePage), `/parent/assistance/session`
(RemoteSessionPage), `/parent/audit`, `/parent/settings`.

Child-side (5): `/child` (ChildShellPage + tabs home/requests/rules/settings),
`/child/enrollment`, `/child/restrictions`, `/child/session` (ChildSessionPage),
`/child/requests`.

Recording start/stop/list/play action present on any screen: **NONE.**

The nearest thing to a "parent-side recording list" is
`remote_assistance_page.dart:130-170`, titled **"Recent sessions"** — it lists
`RemoteSession` rows and each card's only action is
`onOpen: () => _openSession(context, session)` (`:167`), which navigates to the
live-call page. There is no thumbnail, duration, size, play, download, share, or
delete-recording control anywhere.

## 4. Metadata model — no recording field

`lib/data/models/remote_session.dart:71-166` is the only media-adjacent model.
Its complete field set is: `id, familyId, deviceId, parentUserId, childUserId,
kind (audio|video), status, requestedAt, expiresAt, acceptedAt, endedAt,
endedReason, consentRecorded, parentDisplayName, childDisplayName, deviceName`.

There is **no** `recordingUrl`, `mediaPath`, `blobId`, `durationMs`, `sizeBytes`,
`thumbnailUrl`, or `hasRecording`. `toJson()` (`:148-165`) confirms the wire
shape. `WebRtcSignal` (`:237-265`) carries `kind` limited to
`SignalKind { offer, answer, ice }` (`:218-235`) — SDP/ICE JSON only, no binary
media payload.

`lib/data/repositories/repository_contracts.dart:150-173` — the entire
`RemoteSessionRepository` surface is `request`, `fetchPendingForChild`,
`fetchById`, `fetchForFamily`, `respond`, `markActive`, `fetchIceConfig`,
`sendSignal`, `watchSession`, `watchFamilySessions`, `end`. No media method.

Backend corroboration: `supabase/migrations/*.sql` grep for
`recording|storage|bucket|media_path|video_url` → **0 hits**. `supabase/config.toml:30-32`
enables local storage generally, but no bucket is provisioned and no Dart code
calls `client.storage`.

## 5. Remote-assistance media path — proof media never touches disk or server

`lib/features/remote_assistance/remote_session_controller.dart`. The only two
destinations for any captured frame are:

1. **Live to the peer:** `join()` → `getUserMedia(constraints)` (`:507-509`) →
   stored in `_localStream` (`:515`) → `peerConnection.addTrack(track, localStream)`
   (`:572-574`). Real-time RTP only.
2. **Live to the local screen:** `onTrack` (`:534-543`) → `_attachRemote(stream)`
   → `remoteRenderer.srcObject = stream` (`:673`) → rendered by `RTCVideoView`
   (`remote_session_page.dart:343-346`, `child_session_page.dart:293-295`).

There is **no third destination**. Specifically:
- No `RecordVideoFile`/`RecordAudioFile`/`RTCFileRecorder` call; `flutter_webrtc`'s
  file-recording APIs are never referenced.
- `sendSignal` (`:416-420`, `:579-583`, `:683-687`) transmits **only**
  `{sdp, type}` and `candidate.toMap()` strings over the repository → Edge
  Function. `supabase_remote_session_repository.dart:168-180` accepts a
  `Map<String, dynamic> payload` used for signaling; no byte upload path exists.
- `_bufferIce` (`:386-391`) buffers up to 64 **ICE candidate strings**
  (`List<RTCIceCandidate>`), not media frames. `_pendingOffer` (`:57`) is one SDP
  string. `_processedSignals` (`:61`) is a `Set<String>` of signal ids for dedupe.
  These are the only buffers in the controller and all three hold text.
- The only server writes during a call are `sendSignal` (SDP/ICE) and
  `markActive` (`:623-633`, status bookkeeping).

Teardown guarantees no residual capture:
- `_teardownMedia()` (`:749-777`): stops tracks, closes + disposes peer,
  `remoteRenderer.srcObject = null`, clears buffers.
- `endSession()` (`:695-734`) stops media **before** the server call, with the
  comment at `:699-701` explaining that leaving them open would keep a session
  alive without consent.
- `_afterSessionChanged()` (`:243-254`) tears media down on terminal status and on
  expiry; `_startTicker()` (`:804-817`) re-checks expiry every second.
- `onClose()` (`:824-838`) tears down and disposes the renderer.

Child-side self test — `lib/features/child/widgets/media_self_test_sheet.dart`:
local-only preview. `getUserMedia` (`:81-91`) → `_renderer.srcObject = stream`
(`:106`) → `RTCVideoView` (`:360`). It renders the *local* stream and attaches it
to **no** peer connection and **no** file. `_stopStream()` (`:167-181`) stops and
disposes every track; `dispose()` (`:205-218`) and `_stopAndClose()` (`:370-384`)
run it on sheet close. Its only metrics are `videoWidth`/`videoHeight` integers
(`:152-165`) — no bytes retained. The "Recording" `KeyValueRow` at `:306-309` is a
status readout whose value is hard-coded `'Off — preview only'`; it is not a
control and has no handler.

Native bridge — `lib/data/services/device_admin_service.dart` is the only
platform-channel surface (`com.parentcontrol/native`, `:17-20`). Its 20 methods
(`:29-189`) are capabilities, identity, battery, installed apps, package
suspension, policy apply, guardian service, background sync config, device-admin
and settings launchers, permission requests, location tracking, daily usage.
**No capture/recording method exists.** `requestPermissions` (`:131-147`) accepts
only `camera`, `microphone`, `location`, `backgroundLocation`, `notifications` —
no screen-recording consent key.

## 6. User-facing privacy promises (verbatim, file:line)

Child-facing:
1. `lib/features/child/tabs/child_settings_tab.dart:65-68` — "This app never
   records audio or video, takes screenshots, reads messages, or captures
   passwords. Camera and microphone are used only during an assistance session
   you accept and start, and a visible notification stays on while background
   services run."
2. `lib/features/child/tabs/child_settings_tab.dart:203-205` — "Open the main or
   front camera and the microphone for a few seconds on this phone. The preview
   stays on this screen and is not recorded, saved, or sent."
3. `lib/features/child/widgets/media_self_test_sheet.dart:253-256` — "This opens
   this phone's camera and microphone for a live preview on this screen. It is
   not recorded, saved, or sent anywhere, and it stops when you close this sheet."
4. `lib/features/child/widgets/media_self_test_sheet.dart:307-308` —
   `label: 'Recording'` / `value: 'Off — preview only'`.
5. `lib/features/child/child_session_page.dart:94-96` — "Nothing is recorded.
   Camera and microphone are used only during this session and stop when you end
   it or leave this screen. The app never takes screenshots or reads messages."
6. `lib/features/child/child_session_page.dart:376-377` — "Accepting records your
   consent. The camera and microphone stay off until you tap Join on the next
   step. Nothing is recorded."
7. `lib/features/child/child_session_page.dart:389-394` — join confirmation, both
   video and audio branches end with "Nothing is recorded."
8. `lib/features/child/child_requests_page.dart:178-180` — "…stays off until you
   tap Join there. Nothing is recorded."
9. `lib/features/child/tabs/child_home_tab.dart:357-358` — "No location is
   recorded by this app itself; uploads are short-lived fixes."

Parent-facing:
10. `lib/features/settings/settings_body.dart:196-197` — "Assistance sessions
    never record or capture the child's screen." (Security notes card)
11. `lib/features/remote_assistance/remote_assistance_page.dart:66-73` — "A
    request is delivered to the child account. The child must accept before any
    session is created. Camera and microphone are never opened by this app until
    the child has accepted and you tap Join. Nothing is recorded, and no
    screenshots or screen capture are taken. Requests expire quickly; accepted
    sessions are short-lived."
12. `lib/features/remote_assistance/remote_session_page.dart:120-122` — "This app
    does not record audio or video, take screenshots, or capture the screen.
    Ending or leaving stops the media tracks immediately."
13. `lib/features/remote_assistance/remote_session_page.dart:367-369` — join
    confirmation: "The child has already accepted. Nothing is recorded."
14. `lib/features/remote_assistance/remote_assistance_page.dart:124-126` — "Video
    sessions use the camera and microphone only after the child consents and you
    join. Audio sessions use the microphone only."
15. `lib/features/pairing/pairing_redeem_page.dart:163` — "camera stream is only
    used to read the pairing code."

Code-comment promises (same contract, enforced in code):
16. `media_self_test_sheet.dart:11-15` — "…every track is stopped when the sheet
    closes. Nothing is recorded, stored, or sent to the guardian or any server."
17. `remote_session_controller.dart:16-19` — "Nothing is recorded, captured, or
    sent before that tap."
18. `remote_session_page.dart:471` — `consentRecorded` renders as
    `'Recorded' : 'Not recorded'` — this is **consent**, not media.

## 7. Product intent: the app promises NOT to record

Intent is documented as deliberate exclusion, matching the code:
- `README.md:98-99` — "There is no hidden recording, covert capture, keylogging
  or interception of messages/passwords/OTPs."
- `docs/remote-assistance.md:85` — "Explicitly not implemented: Hidden or
  automatic recording."
- `docs/remote-assistance.md:94` — "No recording feature is present, therefore no
  recording retention policy applies."
- `docs/bug-report.md:776-785` — heading "## Screen recording (child) — NOT
  IMPLEMENTED, intentionally": no `MediaProjection`, `VirtualDisplay`,
  `ImageReader` or `MediaRecorder`; MediaProjection captures the whole display
  including third-party apps, which conflicts with the app-only requirement and
  "would also enable invisible surveillance of third-party content."
- `docs/verification-report.md:43-44` — "Audio/video recording | NOT IMPLEMENTED"
  and "Child screen recording | NOT IMPLEMENTED".
- `docs/api-contract.md:546` — "no … recording".

Android manifest (`android/app/src/main/AndroidManifest.xml:4-26`) grants
`CAMERA` and `RECORD_AUDIO` but has **no** `FOREGROUND_SERVICE_MEDIA_PROJECTION`
and no projection service — consistent with "camera/mic yes, screen never."

## 8. Dart-side changes required to implement recording (if ever scoped)

Ordered by dependency; each follows an existing pattern.

1. **Dependency** — add a capture package (e.g. a `media_projection`/`screen`
   recorder wrapper) to `pubspec.yaml:30-47`; `path_provider` must be promoted
   from transitive (`pubspec.lock:514`) to a direct dependency for local file
   paths, plus `share_plus` if export is wanted. None exist today.
2. **Native bridge** — add methods to
   `lib/data/services/device_admin_service.dart` (pattern: `_invokeMap`/`_invoke`
   at `:191-221`) plus a `MediaProjection`/`VirtualDisplay`/`ImageReader` handler
   on the Kotlin side of channel `com.parentcontrol/native`, and a
   `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission + service type in the
   manifest. Extend `requestPermissions` (`:131-147`) with a `screenRecording`
   key and extend `DeviceCapabilities` (`data/models/device.dart`) with
   `screenRecordingGranted`.
3. **Metadata model** — new `lib/data/models/recording.dart` following
   `remote_session.dart:71-166` (const ctor, typed fields, `fromJson` via the
   `jsonString/jsonDate/jsonInt` helpers from `core/utils/json_utils.dart`,
   `toJson`, plus `toUploadJson()` like `telemetry.dart:106`). Fields: `id`,
   `familyId`, `deviceId`, `startedAt`, `endedAt`, `durationMs`, `sizeBytes`,
   `objectKey`, `status`, `consentRecorded`. Add a `RecordingStatus` enum cloned
   from `RemoteSessionStatus` (`remote_session.dart:14-69`) with `label` getters.
4. **Repository** — add `RecordingRepository` to
   `lib/data/repositories/repository_contracts.dart` (pattern:
   `RemoteSessionRepository` `:150-173`, `UsageRepository` `:107-119`) with
   `fetchForFamily`, `create`, `complete`, `delete`, `watchRecordings`,
   `upload` and `getDownloadUrl`. Implement as
   `supabase_recording_repository.dart` using `client.storage.from('recordings')`
   — the first and currently **only absent** Supabase Storage usage in `lib/`
   (0 hits today) — plus an Edge Function action following
   `data/services/edge_api.dart` and the `_guard`/`_mapError` error pattern of
   `supabase_remote_session_repository.dart:160-164`. Requires new migrations
   adding a `recordings` table + storage bucket + RLS (none exist).
5. **Controllers** — `RecordingController` (GetX) cloned from
   `remote_assistance_controller.dart`: `RxBool isRecording`,
   `Rxn<AppException> actionError`, `observe`-based lifecycle, and a mandatory
   foreground-service stop on `onClose()` mirroring
   `remote_session_controller.dart:824-838`.
6. **Routes** — add to `app_routes.dart` (e.g. `recordings =
   '/parent/recordings'`, `recordingPlayer = '/parent/recordings/play'`) and
   register in `app_pages.dart:56-186` with a binding, following
   `AppRoutes.remoteSession`.
7. **Parent UI** — recording-list page cloned from
   `remote_assistance_page.dart:130-170` ("Recent sessions" card list,
   `RefreshIndicator`, `EmptyState`, `StatusChip`), with start/stop controls
   following the `AppButton` pair pattern at `:88-121` and a `ConfirmDialog`
   gate per `:178-181`. Playback page needs a `video_player`/`media_kit` widget —
   no player exists today (`playback`/`player` = 0 hits).
8. **Child UI** — a visible always-on recording indicator plus a consent sheet
   following `child_session_page.dart:371-380`, and a persistent notice
   following the `InfoBanner` pattern; the child settings tab
   (`child_settings_tab.dart:64-74`) privacy text and `settings_body.dart:196-197`
   "never record or capture the child's screen" would both become false and must
   be rewritten. `media_self_test_sheet.dart:306-309` "Recording / Off — preview
   only" would need a real state.
9. **Tests** — `integration_test/child_media_selftest_test.dart:174-176` asserts
   `find.text('Recording')` exists alongside the preview-only state, so any
   change to that label breaks the test.

## 9. Bottom line

- Class (a) screen-recording code in `lib/`: **0 hits, 0 files, 0 routes, 0
  models, 0 uploads, 0 players.**
- Class (b) camera/mic WebRTC: real, consent-gated, live-only, never persisted
  (see §5 proof path).
- Class (c) unrelated: `record`=DB rows/timestamps/`newRecord`/consent,
  `recorded_at`, `BarcodeCapture`, `snapshot`=app inventory,
  `display`=`displayName`, `stream`=Dart async Stream + MediaStream,
  `upload`=usage/location/app telemetry.
- The app makes an explicit, repeated, machine-tested privacy promise that it
  does not record or capture the child's screen. Implementing recording would
  contradict that promise and require the new code listed in §8.
