# Inventory B — remote camera, screen mirroring, one-way audio

Role: subagent 7 of 10. Read-only audit of `D:\parentcontrol_app`. Output file:
`audit/_work/inv-b-camera-screen-audio.md` (only file written). No repo file was
modified; the Supabase CLI was never run; no secret value is reproduced.

## 1. Scope actually covered (files/dirs read; anything skipped and why)

Read in full:

- `lib/features/remote_assistance/remote_session_controller.dart` (2581 lines)
- `lib/features/remote_assistance/remote_session_page.dart` (799 lines)
- `lib/features/remote_assistance/remote_assistance_page.dart` (322 lines)
- `lib/features/remote_assistance/remote_session_registry.dart` (185)
- `lib/features/remote_assistance/remote_session_binding.dart` (71)
- `lib/features/child/child_session_page.dart` (750)
- `lib/features/child/child_session_binding.dart` (69)
- `lib/data/models/remote_session.dart` (314)
- `lib/data/repositories/supabase_remote_session_repository.dart` (431)
- `android/app/src/main/kotlin/.../AudioAssistanceService.kt` (743)
- `android/app/src/main/kotlin/.../MainActivity.kt` (79)
- `android/app/src/main/AndroidManifest.xml` (131)
- `supabase/functions/remote-session/index.ts` (380), `guard.ts` (155)
- `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql`,
  `20261028000300_signaling_open_session.sql`
- `docs/runtime-mic-test-report.md`, `docs/runtime-failure-analysis.md`,
  `docs/runtime-device-matrix.md`,
  `docs/evidence/stage8/media-verified-11-55Z.txt`,
  `docs/evidence/stage8/f1-expiry-12-16Z.txt`, `docs/evidence/stage8/e1-15min.txt`
- `docs/screen-recording-plan.md` (head), `docs/two-device-webrtc-test-plan.md`
  (known-gaps section), `docs/stage7_hosted_migration_apply_2026-10-29.md`

Read in part (grep + ranged reads): `NativeBridge.kt`, `NativePermissions.kt`,
`lib/data/services/device_admin_service.dart`, `remote_assistance_controller.dart`,
`child_requests_page.dart`, `child_requests_controller.dart`,
`child_shell_controller.dart`, `supabase/functions/_shared/turn.ts`,
`supabase/migrations/20260101000000_core.sql` (remote_sessions/webrtc_signals),
`20260101000200_rls.sql` (policies), tests under
`test/features/remote_assistance/` and `test/features/child/`,
`android/app/src/test/kotlin/.../AudioAssistance*Test.kt` (names only).

Repo-wide negative searches (proving absence, not assumption):

- `mediaprojection|VirtualDisplay|ImageReader|screencast|screen cast|
  screenmirror|screen_mirror|mirroring|screen_recording|getDisplayMedia|
  displayMedia|screenShare` over `lib/`, `android/`, `supabase/`, `android_dpc/`
  (dart/kt/xml/sql): **zero hits**.
- `camera2|CameraX|torch|flashlight|setTorchMode|switchCamera|facingMode|
  switch_camera`: only `lib/features/child/widgets/media_self_test_sheet.dart:159,
  254-259` (local self-test sheet) and
  `lib/features/remote_assistance/remote_session_controller.dart:1129`
  (`facingMode: 'user'`).

Not read / not exercised (honest gaps): no device was re-run (out of scope per
brief), the hosted Supabase dashboard was not opened (only the dashboard
subagent may), `android_dpc/` and the remaining `lib/` feature modules are other
subagents' scope, and the full `docs/stage4..7` reports were only sampled.

Vocabulary note: "Connected?" means Flutter UI → Kotlin/native → server path is
wired for that subfeature (yes/partial/no), not that media was seen working.

## 2. Findings

### 2.1 Inventory table — A) Remote Camera, B) Screen Mirroring, C) One-Way Audio

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | table/function/RLS | Connected? | tests | runtime evidence | STATUS | gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-RC01 | Remote Camera | Front camera capture on child (video session) | `/parent/assistance/session`, `/child/session` | `remote_session_controller.dart:1119-1134` (facingMode user, 640x480 ideal), `:1191-1195` addTrack | `AndroidManifest.xml:9` CAMERA; `NativeBridge.kt:465` request; capture via flutter_webrtc `pubspec.yaml:43` | `remote_sessions.kind` check audio/video `20260101000000_core.sql:331` | partial | only denial path: `test/features/remote_assistance/remote_session_controller_test.dart:409-443` | none — the documented run is a microphone run, every scenario requests audio (`docs/runtime-mic-test-report.md:76-83`); S1 row is `kind: audio` in `docs/evidence/stage8/f1-expiry-12-16Z.txt` | CODE EXISTS — NOT TESTED | Capture/encode never exercised on a device. Risk: flagship video path may fail at getUserMedia or camera-in-use. P1 |
| F-RC02 | Remote Camera | Rear camera | — (no control) | — only local self-test `media_self_test_sheet.dart:159` | none (no CameraX/camera2 code) | — | no | — | — | MISSING | Remote session hard-codes the front camera `remote_session_controller.dart:1129`; no way to pick rear. Parity P3 |
| F-RC03 | Remote Camera | Camera permission (child) | system dialog from `/child/session` Join | `remote_session_controller.dart:1281-1296`, `:1526-1536` | `NativeBridge.kt:455-492`, `NativePermissions.kt:12` | — (client consent + OS) | yes | `remote_session_controller_test.dart:409-443` | none for camera; mic grant only `docs/runtime-device-matrix.md:62` | IMPLEMENTED — PARTIALLY VERIFIED | Unit test proves a denied camera aborts join before signaling; a camera grant has never been run. P2 |
| F-RC04 | Remote Camera | Child authorization before any capture | `/child/requests`, `/child/session` | `remote_session_controller.dart:657-708`, `:1021-1031`; `child_session_page.dart:267-310`, `:632-662` | — | `remote-session` respond `index.ts:195-265`; signaling RLS requires accepted/active `20261028000300:25-54` | yes | `test/features/remote_assistance/remote_child_session_test.dart:79-110` | accept then a second "Join now" tap in every session, `docs/runtime-mic-test-report.md:86-87`; reject-before-consent path `remote_session_controller.dart:1021-1031` | FULLY IMPLEMENTED — VERIFIED | Gate is kind-agnostic and proven for audio; a video session was never accepted on a device. P3 |
| F-RC05 | Remote Camera | Visible capture indication (camera) | `/child/session` media card only | `child_session_page.dart:408-520`; `remote_session_page.dart:419-480` | only a MICROPHONE FGS: `AndroidManifest.xml:88-92`; notification `AudioAssistanceService.kt:539-575` | — | partial | — | no camera run; mic notification/FGS proven `docs/runtime-device-matrix.md:74` | PARTIALLY IMPLEMENTED | No camera-type foreground service and no explicit "camera live" indicator; relies on the Android privacy dot (assumption). Privacy P1 |
| F-RC06 | Remote Camera | Live video streaming to parent | `/parent/assistance/session` (RTCVideoView) | `remote_session_controller.dart:1175-1189` onTrack, `:1553-1575` attach; `remote_session_page.dart:455-479` | flutter_webrtc plugin `pubspec.yaml:43` | `webrtc_signals` `core.sql:358-370` | partial | only negative: video stats are not audio proof `remote_session_controller_test.dart:1107-1180` | none (audio-only sessions) | CODE EXISTS — NOT TESTED | A WebRTC dependency does not prove video: no remote video track, renderer or frame was ever observed. P1 |
| F-RC07 | Remote Camera | Audio from child mic during a VIDEO session | both session screens | `remote_session_controller.dart:1120-1126`, `:1191-1195` | `AudioAssistanceService.kt` mic FGS `AndroidManifest.xml:88-92` | — | partial | audio tests only | no video-kind session ever run | CODE EXISTS — NOT TESTED | Same code path as audio, but video sessions change constraints and camera-in-use behaviour. P2 |
| F-RC08 | Remote Camera | Flashlight / torch | — | — | none; zero torch/flash hits in `lib/`+`android/` | — | no | — | — | MISSING | No torch API anywhere. Parity P3 |
| F-RC09 | Remote Camera | Camera switching (front/rear) in session | — | only `media_self_test_sheet.dart:254-259` (local test sheet) | — | — | no | — | — | MISSING | `Helper.switchCamera` exists only in the child self-test, never in `RemoteSessionController`. P3 |
| F-RC10 | Remote Camera | Network recovery during a video session | both session screens (banners) | `remote_session_controller.dart:1702-1966`, `:2511-2575`, TURN refresh `:1935-1957` | — | signaling RLS `20261028000300:25-54` | partial | `test/features/remote_assistance/remote_session_reliability_test.dart:547-588`, group `:877+` | only audio: 539 s outage then manual re-join `docs/runtime-mic-test-report.md:159` | IMPLEMENTED — PARTIALLY VERIFIED | Recovery worked only after a manual "Join now" tap, and never for video. P2 |
| F-RC11 | Remote Camera | Session termination while camera is on | parent End button | `remote_session_controller.dart:2269-2323`, teardown `:2348-2398` (stops every track) | service stop `AudioAssistanceService.kt:300-307` | `end` `index.ts:309-346`; parent-only `guard.ts:117-155` | yes | `remote_session_reliability_test.dart:655-704` | audio only: I1/I2 `docs/runtime-mic-test-report.md:182-183` | IMPLEMENTED — PARTIALLY VERIFIED | Camera track release at end is unit-covered, never observed on a device. P2 |
| F-RC12 | Remote Camera | Camera lifecycle / background restrictions | — | detach-only `onClose` `remote_session_controller.dart:2468-2484`; resume `:2511-2575`; app-scoped registry `remote_session_registry.dart:47-52` | cached engine `MainActivity.kt:29-50`; **no camera FGS type** `AndroidManifest.xml:88-92` | — | partial | `remote_session_controller_test.dart:988-1057` | audio only: background 300 s, lock 120 s, Recents `docs/runtime-mic-test-report.md:94,110,123` | PARTIALLY IMPLEMENTED | A video session backgrounded or locked has no camera foreground service; whether capture survives is unverified (assumption: Android may deny background camera). P1 |
| F-RC13 | Remote Camera | Transport (WebRTC + signaling) | — | `remote_session_controller.dart:1499-1503` peer, `:1188-1276`; repo `supabase_remote_session_repository.dart:223-321` | flutter_webrtc + cached FlutterEngine `MainActivity.kt:24-57` | `webrtc_signals` `core.sql:358-370`; replay/RLS `20261028000300` | yes | controller tests + `supabase/functions/remote-session/guard_test.ts` | offer 11:54:05Z, answer 11:54:06Z, 31 ICE rows, host 37 / srflx 10 / relay 0 `docs/evidence/stage8/media-verified-11-55Z.txt` | IMPLEMENTED — PARTIALLY VERIFIED | Transport proven once, on one LAN, for audio only. P2 |
| F-RC14 | Remote Camera | Unauthorized-access protection | — | role fail-closed `remote_session_binding.dart:46-50`, `remote_session_controller.dart:255-258`, `:1012-1019`; parent never captures `:1526-1536`; stale-signal horizon `:225-227`, `:838-844` | service `exported=false` `AndroidManifest.xml:90`; start gate `AudioAssistanceService.kt:231-240` | RLS participants only `20261028000300:25-54`; ICE requires consent `index.ts:348-366`; `session_state` device-scoped `guard.ts:87-106` | yes | `guard_test.ts`, `remote_child_session_test.dart:163`, `remote_session_reliability_test.dart:693` | not adversarially tested | IMPLEMENTED — PARTIALLY VERIFIED | No penetration test or non-participant attempt was recorded. P2 |
| F-SM01 | Screen Mirroring | MediaProjection integration (VirtualDisplay/encoder) | — | none (zero hits repo-wide) | no `ScreenCaptureManager`/`ScreenRecordService`; manifest has no mediaProjection FGS type `AndroidManifest.xml:1-131` | — | no | — | — | MISSING | Feature does not exist at any layer; `docs/screen-recording-plan.md:1-15` says NOT IMPLEMENTED by owner decision. P1 |
| F-SM02 | Screen Mirroring | Capture permission (createScreenCaptureIntent) | — | none | — | — | no | — | — | MISSING | No screen-capture consent intent exists. P1 |
| F-SM03 | Screen Mirroring | Visible user consent on child | — | none | — | — | no | — | — | MISSING | No consent UI for screen content; session consent covers camera/mic only `child_session_page.dart:277-281`. P1 |
| F-SM04 | Screen Mirroring | Live screen stream | — | none (`getDisplayMedia` absent) | — | — | no | — | — | MISSING | Only camera `video` track exists `remote_session_controller.dart:1127-1132`. P1 |
| F-SM05 | Screen Mirroring | Screen-share audio | — | none | — | — | no | — | — | MISSING | No display-audio capture path. P2 |
| F-SM06 | Screen Mirroring | Rotation handling of shared screen | — | none | — | — | no | — | — | MISSING | No capture surface exists to rotate. P3 |
| F-SM07 | Screen Mirroring | Resolution / frame-rate control | — | none | — | — | no | — | — | MISSING | No encoder settings (only 640x480 camera ideal `:1130-1131`). P2 |
| F-SM08 | Screen Mirroring | Network adaptation for screen video | — | none | — | — | no | — | — | MISSING | No bitrate/adaptation layer beyond ICE restart `:1799-1901`. P2 |
| F-SM09 | Screen Mirroring | Reconnection of a screen stream | — | none | — | — | no | — | — | MISSING | ICE recovery is audio/camera only `:1702-1966`. P2 |
| F-SM10 | Screen Mirroring | Background / lock behaviour of screen share | — | none | — | — | no | — | — | MISSING | No mediaProjection FGS, which Android requires. P2 |
| F-SM11 | Screen Mirroring | Termination of screen share | — | none | — | — | no | — | — | MISSING | No session/stream to terminate. P2 |
| F-SM12 | Screen Mirroring | Capture notification / indicator | — | none | only the microphone notification `AudioAssistanceService.kt:539-575` | — | no | — | — | MISSING | No screen-capture notification exists. P2 |
| F-SM13 | Screen Mirroring | Performance / battery impact | — | none | — | — | no | — | — | NOT APPLICABLE | Nothing runs, so there is no capture pipeline to measure. P3 |
| F-AU01 | One-Way Audio | Parent requests audio assistance | `/parent/assistance` "Request audio" | `remote_assistance_page.dart:110-143`, `:201-217`; `remote_assistance_controller.dart:68-80` | — | `remote-session` request `index.ts:108-146`; RPC `20261028000200:106-181` | yes | `test/features/remote_assistance/remote_assistance_controller_test.dart` | S1 requested 11:27:08Z `docs/runtime-mic-test-report.md:45`; A1-A4 PASS `:80-83` | FULLY IMPLEMENTED — VERIFIED | Hosted bundle is pre-fix, so the new in-progress guard RPC is not used in production (`docs/stage7_hosted_migration_apply_2026-10-29.md:94-99`). P2 |
| F-AU02 | One-Way Audio | Child receives the request | `/child/requests`, `/child` home card | `child_requests_controller.dart:25,45` (15 s poll), `child_requests_page.dart:118-128`, `child_shell_controller.dart:683` | — | `pending_child` `index.ts:170-193` | yes | `test/features/child/child_requests_controller_test.dart` | `docs/evidence/stage8/e2-child-incoming.png`; A1 flow | FULLY IMPLEMENTED — VERIFIED | No push; up to 15 s latency and only while the app polls. P3 |
| F-AU03 | One-Way Audio | Explicit approval (accept, then Join) | `/child/requests` accept dialog, `/child/session` Join | `remote_session_controller.dart:657-708`; `child_session_page.dart:632-662`; `child_requests_page.dart:168-186` | — | respond `index.ts:195-265` (consent_recorded, expiry cleared) | yes | `remote_child_session_test.dart:79-110`, `:104-136` | double confirmation documented `docs/runtime-mic-test-report.md:86-87` | FULLY IMPLEMENTED — VERIFIED | Accept alone opens nothing; two visible taps required by design. P3 |
| F-AU04 | One-Way Audio | Microphone permission | system dialog from `/child/session` | `remote_session_controller.dart:1281-1321`, one-time grant `:1465-1475` | `NativeBridge.kt:455-492`; `NativePermissions.kt:14` | — | yes | `remote_session_reliability_test.dart:442` | granted appops `allow` `docs/runtime-device-matrix.md:62`; revoke/restore PASS `runtime-mic-test-report.md:147-148` | FULLY IMPLEMENTED — VERIFIED | Deny-before-session (F3) never run `runtime-mic-test-report.md:149`. P3 |
| F-AU05 | One-Way Audio | Foreground microphone service | ongoing notification channel | `device_admin_service.dart:111-150` | `AudioAssistanceService.kt:68-121`, `:371-443`; `AndroidManifest.xml:88-92` (microphone, stopWithTask false) | — | yes | Kotlin tests exist but cannot run: `docs/runtime-failure-analysis.md:124-143` | FGS 4303 foreground `docs/runtime-device-matrix.md:74`; `media-verified-11-55Z.txt` | FULLY IMPLEMENTED — VERIFIED | Kotlin suite unverified on this workstation (mixed-drive Gradle block). P3 |
| F-AU06 | One-Way Audio | Audio capture (echo cancel, NS, AGC) | — | `remote_session_controller.dart:1119-1134` | capture is flutter_webrtc; service only keeps process foreground `AudioAssistanceService.kt:24-43` | — | yes | controller tests | child appops running + parent RTP in 5463 pkts `docs/evidence/stage8/media-verified-11-55Z.txt` | FULLY IMPLEMENTED — VERIFIED | No content stored; capture never recorded to disk (`remote_session_page.dart:137-144`). P3 |
| F-AU07 | One-Way Audio | WebRTC connection / signaling | — | `remote_session_controller.dart:1003-1276` (offer/answer/ICE), dedupe `:830-873`; repo `:223-321` | — | `webrtc_signals` `core.sql:358-370`; RLS `20261028000300:25-54` | yes | `remote_session_reliability_test.dart:589-630` | offer 11:54:05Z answer 11:54:06Z, 31 ICE rows `media-verified-11-55Z.txt` | FULLY IMPLEMENTED — VERIFIED | F6: signaling-loss banner shown during healthy media `runtime-failure-analysis.md:112-120`. P3 |
| F-AU08 | One-Way Audio | Parent playback (loudspeaker, receive-only) | `/parent/assistance/session` audio stage | `remote_session_controller.dart:1505-1516`, `:1567-1570`; `remote_session_page.dart:424-453` | — | — | yes | `remote_session_reliability_test.dart:862` (parent never captures) | AudioTrack piid 271 started, VOICE_COMMUNICATION, frames advanced `media-verified-11-55Z.txt` | FULLY IMPLEMENTED — VERIFIED | Human audibility never verified `docs/runtime-mic-test-report.md:36-39`. P3 |
| F-AU09 | One-Way Audio | Session status / liveness labelling | both session screens | `remote_session_controller.dart:353-400`; `remote_session_page.dart:669-758` | — | statuses `core.sql:332-334` | yes | `test/features/remote_assistance/remote_session_page_test.dart` | A1/A3/A4 live, I1-I5 terminal `runtime-mic-test-report.md:80-83,182-186` | FULLY IMPLEMENTED — VERIFIED | Labels separate server state from RTP proof; good. P3 |
| F-AU10 | One-Way Audio | Reconnection (automatic) | "Reconnect microphone" / "Start the live session" | `remote_session_controller.dart:1702-1966`, `:2511-2575`, child-ready `:1607-1700` | service restart handshake `AudioAssistanceService.kt:385-401` | — | yes | `remote_session_reliability_test.dart:547-588`, `:877+` | G1 recovered only after manual Join tap `runtime-mic-test-report.md:159`; A2 manual reconnect `:81` | IMPLEMENTED — PARTIALLY VERIFIED | Automatic recovery is unit-tested, not proven between two real peers. P2 |
| F-AU11 | One-Way Audio | Network loss handling | banners + ICE restart | `remote_session_controller.dart:1766-1919` | session watchdog unaffected `AudioAssistanceService.kt:667-742` | — | yes | same as F-AU10 | 539 s child Wi-Fi outage, then manual recovery `runtime-mic-test-report.md:159`; airplane/5-min rows BLOCKED/NOT TESTED `:160-161` | IMPLEMENTED — PARTIALLY VERIFIED | Failure state is handled; recovery across carrier NAT unproven (no TURN). P2 |
| F-AU12 | One-Way Audio | App background (child) | — | registry never tears down on pause `remote_session_registry.dart:47-52` | wake lock `AudioAssistanceService.kt:616-638` | — | yes | lifecycle tests | B2 300 s PASS `runtime-mic-test-report.md:94`; D1 lock 120 s PASS `:123` | FULLY IMPLEMENTED — VERIFIED | Parent-background leg (B5) NOT TESTED `:97`; 15/30 min legs cut by F1. P2 |
| F-AU13 | One-Way Audio | Recents removal (child) | — | detached, not terminated `remote_session_controller.dart:451-459` | `onTaskRemoved` `AudioAssistanceService.kt:473-481`; stopWithTask false `AndroidManifest.xml:91` | — | yes | — | C3 PASS, pid unchanged, FGS foreground `runtime-mic-test-report.md:110` | FULLY IMPLEMENTED — VERIFIED | OEM task cleaners still kill it (documented `AudioAssistanceService.kt:57-61`). P3 |
| F-AU14 | One-Way Audio | Force stop / process kill | — | rejoin requires visible action `remote_session_controller.dart:2511-2551` | START_NOT_STICKY `AudioAssistanceService.kt:442`; F5 `runtime-failure-analysis.md:100-108` | — | yes | — | C5 process+services gone ≤4 s, C6 no revival `runtime-mic-test-report.md:112-113` | FULLY IMPLEMENTED — VERIFIED | Cannot survive force stop by design; parent sees "Connection setup failed" until reconnect. P3 |
| F-AU15 | One-Way Audio | Permission revocation mid-session | — | poll `remote_session_controller.dart:1972-2026` | permission watch `AudioAssistanceService.kt:325-340` (5 s) | — | yes | `remote_session_reliability_test.dart:519-546` | F1 revoke PASS (+25 s), F2 restore PASS `runtime-mic-test-report.md:147-148` | FULLY IMPLEMENTED — VERIFIED | Android also kills the process on revoke; teardown is OS+app. P3 |
| F-AU16 | One-Way Audio | End session (parent authority) | "End session" on parent screen | `remote_session_controller.dart:2269-2323`; `remote_session_page.dart:551-620` | stop `AudioAssistanceService.kt:300-307` | `end` `index.ts:309-346`; `assertParentOwner` `guard.ts:117-128` | yes | `remote_session_reliability_test.dart:655-704`, `:693` | I1 13:53:02Z, I2 13:36:40Z, I5 14:12:57Z `runtime-mic-test-report.md:182-186` | FULLY IMPLEMENTED — VERIFIED | Parent-end detection when the child UI is gone relies on `session_state`, absent from the hosted bundle (`AudioAssistanceService.kt:699-705`). P2 |
| F-AU17 | One-Way Audio | Audio recording + storage/management/deletion | — | none; UI promises "does not record" `remote_session_page.dart:137-144` | — | — | no | — | — | MISSING | No recording, upload, retention or deletion exists; deliberate owner decision `docs/screen-recording-plan.md:1-15`. Parity P3 |
| F-AU18 | One-Way Audio | Privacy indicators | ongoing notification, child status card | `child_session_page.dart:408-520` | notification `AudioAssistanceService.kt:539-575`, channel `:522-537`; POST_NOTIFICATIONS gate `:231-240` | — | yes | `AudioAssistanceStartGateTest.kt` (unrunnable) | notification 4303 + mic appops `docs/runtime-device-matrix.md:74`; preflight refusal text `remote_session_controller.dart:1298-1308` | FULLY IMPLEMENTED — VERIFIED | Camera has no equivalent indicator (F-RC05). P3 |
| F-AU19 | One-Way Audio | Session lifetime (parent-controlled until End) | status card "Session duration" | `remote_session.dart:104-130`; `remote_session_controller.dart:376-390`; `remote_session_page.dart:703-709` | watchdog treats non-open status as stop `AudioAssistanceService.kt:253-261` | `20261028000200:35-48`; pending-only sweep `:80-99`; edge `respond` clears expiry `index.ts:225-232` | yes | `remote_session_reliability_test.dart:731-755` | **FAIL**: S1 flipped to `expired` 12:16:38.393Z, media closed 144 ms later, UI still said "Until you end the session" `docs/evidence/stage8/f1-expiry-12-16Z.txt`; `runtime-failure-analysis.md:35-49` | BROKEN | F1: hosted `remote-session` still pre-fix (inserts `expires_at` on accept, lazily expires) while DB migrations are applied; fix at HEAD undeployed (`docs/stage7_hosted_migration_apply_2026-10-29.md:94-99`). P0/P1 |
| F-AU20 | One-Way Audio | TURN relay support | "Relay not configured" banner | `remote_session_controller.dart:402-412`, `:1935-1957`; `remote_session.dart:244-265` | — | `_shared/turn.ts:71-105` (ephemeral HMAC creds, TTL 600 s); `ice` `index.ts:348-371` | partial | `supabase/functions/_shared/turn_test.ts` (unit) | relay 0 candidates; `turn_configured:false` `media-verified-11-55Z.txt`; F4 `runtime-failure-analysis.md:88-97` | IMPLEMENTED — PARTIALLY VERIFIED | Code issues TURN credentials, but no relay was configured in the run, so a relayed call has never been observed. P2 |

### 2.2 Does remote camera exist, and does screen mirroring exist?

**Camera: partial code, zero runtime proof.** A `video` session kind is modelled
(`lib/data/models/remote_session.dart:3-12`, DB check
`supabase/migrations/20260101000000_core.sql:331`), the parent requests it
(`remote_assistance_page.dart:129-139`), the child adds a camera track with
`facingMode: 'user'` only for that kind
(`remote_session_controller.dart:1127-1133`), and the parent renders it with
`RTCVideoView` (`remote_session_page.dart:455-479`). Nothing beyond the denial
path is tested (`test/features/remote_assistance/remote_session_controller_test.dart:409-443`),
and every runtime scenario on record requests audio
(`docs/runtime-mic-test-report.md:76-83`). There is no rear camera, no torch, no
in-session camera switch and no camera foreground service. So the feature is
**not** "implemented": it is reachable code that has never produced a frame.

**Screen mirroring: absent.** Zero matches for MediaProjection, VirtualDisplay,
`getDisplayMedia`, "mirroring" or screen capture in `lib/`, `android/`,
`supabase/` or `android_dpc/`; the manifest declares no
`FOREGROUND_SERVICE_MEDIA_PROJECTION` and no mediaProjection service
(`AndroidManifest.xml:1-131`). The repo's own plan states the feature is not
implemented and that the owner decided on 2026-10-27 to keep it out of scope
(`docs/screen-recording-plan.md:1-15`). All screen rows are MISSING, not "UI
only": there is not even a screen for it.

### 2.3 One-way audio: what is actually proven

Proven end-to-end (three sessions reached live media, child→parent only):
request, consent, capture, signaling, RTP and a started parent playback track.
The strongest single artifact is session `1bd26a84-137d-4e87-84ed-80190bfbea3e`
at 11:55:59Z: offer 11:54:05Z, answer 11:54:06Z, 31 ICE rows, parent
`in 5463 pkts / 399641 B, out 0`, AudioTrack `VOICE_COMMUNICATION` with the
server frame position advancing 600575→650805 across 6 s
(`docs/evidence/stage8/media-verified-11-55Z.txt`; summarized in
`docs/runtime-mic-test-report.md:26-39`). Child capture was independently
confirmed by appops `RECORD_AUDIO … (running)` and the microphone FGS 4303
(`docs/runtime-device-matrix.md:62,74`). Human audibility was never checked and
is explicitly excluded (`docs/runtime-mic-test-report.md:36-39`).

Lifecycle and safety behaviour proven on device: background 5 min (RTP +15,932
pkts), lock 2 min (RTP +7,084 pkts), Recents swipe (pid unchanged, FGS
foreground), force stop (all services gone in ≤4 s, no zombie mic), permission
revoke (capture stops at +25 s, parent shows not-live) and restore, parent End
while child live and while child offline, and cancel of a pending request
(`docs/runtime-mic-test-report.md:94,110,112-113,123,147-148,182-186`).

Not proven for audio: automatic reconnection (G1 needed a manual "Start the live
session" tap, `docs/runtime-mic-test-report.md:159`), airplane mode and 5-minute
outages (`:160-161`), parent background (`:97`), 30-minute endurance (`:194`),
and any relayed (TURN) call (`docs/runtime-failure-analysis.md:88-97`).

### 2.4 F1 — hosted-expiry defect (reliability finding, not a feature)

The DB side of the parent-controlled-lifetime policy is applied on hosted
(`expires_at` nullable, pending-only sweep, signaling RLS without the expiry
predicate: `docs/stage7_hosted_migration_apply_2026-10-29.md:30-46`), but the
hosted `remote-session` Edge Function is still the pre-fix bundle because no
function was deployed (`docs/stage7_hosted_migration_apply_2026-10-29.md:6,
94-99`). At runtime that bundle stamped `expires_at = accepted_at + 30 min` and
later flipped an `active` row to `expired`:
`accepted_at 11:27:25.197Z`, `expires_at 11:57:25.197Z`,
`ended_at 12:16:38.393Z`, `ended_by NULL`, `ended_reason expired`, with no
expiry audit row (`docs/evidence/stage8/f1-expiry-12-16Z.txt`). The parent
client closed the peer 144 ms later and that 15-minute endurance leg ended after
8m14s (`docs/evidence/stage8/e1-15min.txt`). The UI simultaneously promised
"Until you end the session" (`remote_session_controller.dart:376-390`;
`remote_session_page.dart:703-709`). HEAD already fixes the logic
(`expirePending` touches only `requested`, `supabase/functions/remote-session/index.ts:84-95`;
nullable expiry `20261028000200:35-48`), so this is a **deployment** gap, not a
missing feature — but as shipped it is the single highest-impact defect in this
inventory. Note that the stage-7 document predicted the old bundle would be
"harmless for RLS and lifetime" (`:94-99`); the later stage-8 runtime evidence
disproves that prediction for lifetime.

Secondary reliability items seen in runtime evidence: F6, the parent warning
"Live updates interrupted — End the session and retry" while RTP was flowing
(`docs/runtime-failure-analysis.md:112-120`, screenshots
`docs/evidence/stage8/j1-parent-live-before-end.png`), and the native
parent-end watchdog depending on a `session_state` action the hosted bundle does
not implement (`AudioAssistanceService.kt:699-705`).

## 3. Evidence gaps / BLOCKED items

- **No camera/video runtime evidence at all.** Every documented scenario requests
  audio (`docs/runtime-mic-test-report.md:76-83`), S1 records `kind: audio`
  (`docs/evidence/stage8/f1-expiry-12-16Z.txt`) and the session inventory lists
  no video row (`docs/runtime-mic-test-report.md:43-48`).
  Re-running a video session needs both devices; not performed here (brief: do
  not re-run devices).
- **Screen mirroring cannot be tested because it does not exist** (zero code
  hits; `docs/screen-recording-plan.md:1-15`). Marked MISSING, not BLOCKED.
- **BLOCKED — hosted Edge Function state**: only the Web Dashboard subagent may
  read the hosted bundle; this audit relies on `docs/stage7_hosted_migration_apply_2026-10-29.md:94-99`
  and the stage-8 runtime capture for the claim that production runs the pre-fix
  function.
- **BLOCKED — Kotlin unit suite**: `android/gradlew testDebugUnitTest` fails at
  configuration time on this workstation (mixed D:/C: roots), so
  `AudioAssistanceRecreationTest`, `AudioAssistanceStartGateTest` and
  `AudioAssistanceSessionWatchdogTest` were not executed here
  (`docs/runtime-failure-analysis.md:124-143`).
- **No TURN relay**: `relay 0` candidates, `turn_configured:false`
  (`docs/evidence/stage8/media-verified-11-55Z.txt`); a relayed call is unproven
  (`docs/runtime-failure-analysis.md:88-97`).
- **Not tested on device**: airplane mode, 5-min outage, parent background,
  both devices backgrounded, rotation, 30-min endurance, deny-before-session
  (`docs/runtime-mic-test-report.md:96-98,125-126,134-135,140,149,160-162,194`).
- **Adversarial authorization testing absent**: RLS and edge guards were read
  and have Deno unit tests (`supabase/functions/remote-session/guard_test.ts`),
  but no non-participant/forged-signal attempt was recorded at runtime.

## 4. One-paragraph summary a reviewer can trust

One-way audio from the child's microphone to the parent's loudspeaker is the
only assistance media that is genuinely implemented and proven end-to-end:
consent is double-gated on the child device, capture is tied to a visible
microphone foreground service with heartbeat and permission watchdogs, and the
parent is strictly receive-only, with packet-level proof (session
`1bd26a84…`, `in 5463 pkts`, AudioTrack started) plus device-verified
background, lock, Recents, force-stop, permission-revoke and parent-End
behaviour. Remote camera exists only as code: the `video` kind adds a front
camera track and a parent video renderer, but no runtime video session has ever
been recorded, and rear camera, torch, in-session camera switching and a camera
foreground service do not exist. Screen mirroring does not exist at any layer
and is explicitly out of scope by owner decision. The most serious defect is
F1: because the hosted `remote-session` function was never redeployed, a
consented session is still expired ~30 minutes after consent, which killed live
audio at 12:16:38.393Z while the UI promised "Until you end the session" — a
deployment fix, not a missing feature, and it invalidates any claim of
parent-controlled session lifetime in production today.

```
counts: fully_verified=16 partially_verified=8 partial=2 ui_only=0 backend_only=0
code_untested=3 broken=1 missing=16 blocked=0 not_applicable=1
```