# Remote Access Runtime Results — Superseding Report

**Audit date:** 2026-11-26  
**Scope:** BG-03, BG-04, BG-05 and CAM-01–CAM-07, AUD-01–AUD-07, MIR-01–MIR-03  
**Overall result:** **PARTIAL.** Consented camera video and one-way-audio live states were reached, but full media-content/RTP proof is incomplete and Parent End released Child capture only after 51–52 seconds. Screen mirroring and recording workflows are absent.

## 1. Supersession and provenance

This report supersedes the earlier request-delivery FAIL conclusion. Exactly four runtime subagents were authorized. The original remote subagent reached its turn limit; the main agent continued that same lane without creating a fifth subagent.

The earlier failures targeted a revoked device record. Backend rejection of that record was expected authorization behavior. A cold Parent process selecting the verified active third device card then delivered a request successfully. The same-process revoked-to-active navigation defect is retained separately below.

No application/source, backend, dependency, manifest, Gradle, account, pairing, permission, credential, zone, policy, Git or Device Owner state was changed. Normal remote-session records were created through the app and ended through the app; none were deleted. No media bytes were retained.

## 2. Runtime baseline

| Role | Serial | Model | Android / API | App | Observed relevant state |
|---|---|---|---|---|---|
| Parent | `emulator-5554` | `sdk_gphone64_x86_64` | 17 / 37 | `com.parentcontrol.parent_control` 1.0.0 (1) | Receive-only camera/microphone inactive in every native sample |
| Child | `5HXWRGQ4IFU8WS4T` | RMX2161 | 12 / 31 | `com.parentcontrol.parent_control` 1.0.0 (1) | Ordinary background operation; Guardian and Location services active; capture inactive before consent |

Evidence: lane-2 baseline artifacts, lane-3 verified media summaries, and lane-4 `L4_000_parent_native.json` / `L4_000_child_native.json`.

## 3. Request targeting and delivery

### 3.1 Expected authorization result

Directly opening a revoked device and submitting its stale ID produced **“Request failed The device is not active.”** The server requires an active device for a Parent. This is correct fail-closed authorization behavior, not evidence that the online Child could not receive a request.

### 3.2 Active cold-start delivery

After normal Parent process restart and direct selection of the active Child card, Request video reached the Parent waiting state and the Child pending-request list. The same sequence was used for audio. The Parent later cancelled the request and the Child pending request disappeared.

Evidence: `evidence/lane4/L4_032_cold_remote_loaded.ui.txt`, `L4_032_cold_parent_waiting.ui.txt`, `L4_032_child_pending_refreshed.ui.txt`, `L4_032_parent_cancelled.ui.txt`, and corresponding command metadata.

### 3.3 Confirmed stale-target defect

Within the same Parent process, navigating from a revoked record back to the active device could reuse the revoked target. A cold process worked. The route receives the selected `device.id`, but the GetX controller registration can outlive the route and retain its first constructor argument. Exact GetX disposal timing was not directly logged, so the source trace identifies a lifecycle mismatch and does not claim an observed dispose timestamp.

**Defect BUG-003:** same-process revoked-to-active navigation can submit the stale revoked device ID. Severity: Medium. It causes failed requests and confusing authorization errors; it does not bypass server authorization.

## 4. Consent and role safety

Across the verified video and audio runs:

1. The request was delivered while the Child main app was in the background.
2. The Child opened Requests and explicitly accepted.
3. Accept alone did **not** start capture.
4. The Child explicitly tapped Join.
5. Native camera/microphone or recording state became active only after Join.
6. The Parent joined automatically as receive-only.
7. Parent camera and microphone remained inactive in every native sample.
8. Child Stop sharing or Parent End eventually released capture.

This is positive runtime evidence for explicit consent gating and receive-only Parent behavior. Request, server status, signalling or service existence alone were not used as media proof.

## 5. Camera video evidence

### 5.1 Verified frame-changing run

`evidence/lane3/L4_MEDIA_VIDEO_FRAME_VERIFIED2_summary.json` ran from `16:36:13+05:30` to `16:39:25+05:30`.

- Child raw UI: **“Media connected Camera and microphone live…”**
- Parent raw UI in every sample: **“Media connected Video live Ending stops video streaming.”**
- Parent-rendered region samples:

| Sample | Mean luma | Standard deviation | Bright fraction |
|---|---:|---:|---:|
| 1 | 208.053 | 43.257 | 0.9867 |
| 2 | 207.614 | 43.571 | 0.9857 |
| 3 | 207.588 | 43.680 | 0.9849 |

- Adjacent mean-luma deltas: `0.473` and `0.230`.
- `all_frames_nonblack_varied: true`.
- Child capture active and Parent capture inactive in all samples.
- Images were processed in memory and discarded; no private image bytes were retained.

This proves nonblack, varying Parent-rendered camera content rather than a static placeholder. A deliberately staged scene change and direct numeric inbound RTP counters were not collected.

### 5.2 Collector matcher artifact

The historical summary field `all_parent_media_live` is false in video runs because the collector matched only a label beginning with `Video live`. Flutter's actual combined label begins with `Media connected Video live…`. Raw UI therefore proves the live marker while the aggregate field is a false negative. The collector now uses case-insensitive substring matching; historical summaries were not rewritten.

This artifact is **not** an app media failure.

## 6. One-way audio evidence

`evidence/lane3/L4_MEDIA_AUDIO_VERIFIED_summary.json` ran from `16:40:47+05:30` to `16:43:51+05:30`.

- Child raw UI: **“Media connected Microphone live…”**
- Parent samples: `parent_media_connected`, `parent_live`, and `parent_playback` were all true.
- Parent camera and recording remained false.
- Child main UI was background; Child recording and `AudioAssistanceService` were active; Child camera remained false.
- `all_parent_media_live: true`.

The Parent playback state and live marker support a functioning receive path. However, no harmless spoken phrase and no direct inbound RTP counter were collected. Actual audible content delivery therefore remains **unproven**, not failed.

## 7. Stop sharing and Parent End

### 7.1 Child Stop sharing — video

`evidence/lane3/L4_MEDIA_VIDEO_STOP_VERIFIED_summary.json`:

- Visible confirmation: **“This turns off your camera and microphone on this phone immediately. The session stays open until your guardian ends it.”**
- Native camera/recording state became clean in **1.759 seconds**.
- Parent End afterward produced clean native state in **4.062 seconds** because Child capture had already stopped.
- Parent reached terminal UI; Child eventually showed Ended.
- Final Child services were only Guardian and Location.

This path worked as designed for the tested video session.

### 7.2 Parent End — delayed Child capture release

| Run | Parent End confirmation tap | Child native clean | Delay |
|---|---|---|---:|
| Video | `2026-11-26T16:38:25+05:30` | `2026-11-26T16:39:18+05:30` | **52.624 s** |
| Audio | `2026-11-26T16:42:53+05:30` | `2026-11-26T16:43:44+05:30` | **51.051 s** |

Both runs independently showed Child camera/microphone capture and/or recording plus `AudioAssistanceService` remaining active after the Parent confirmed End. Both eventually reached clean native state and terminal UI.

**Defect BUG-001:** delayed Child capture release after Parent End. Severity: High because the Child privacy/stop expectation is not met promptly. The evidence proves delayed **local capture release**, not continued media transmission. The timestamp is the Parent confirmation tap, not a directly logged server acknowledgement.

## 8. TURN and transport limits

Both media UIs displayed **“Relay not configured”** and the no-TURN warning. The server ICE response therefore contained STUN but no TURN relay. This is a deployment/configuration gap, not automatically an application-code defect. Media worked on the tested network; restrictive-network/carrier-NAT reliability was not tested.

`parent_rtp` was null because the installed release does not expose the debug-only `DEBUG RTP` label. ICE/DTLS state and server `Active` status were not credited as media proof.

## 9. Screen mirroring and recording

- Parent Remote assistance exposed only Request audio and Request video.
- Runtime disclosure: **“Nothing is recorded, and no screenshots or screen capture are taken.”**
- Recent sessions had no record/save/manage controls.
- Scoped source scan found no `MediaProjection`, `VIRTUAL_DISPLAY`, or `FOREGROUND_SERVICE_MEDIA_PROJECTION` workflow.
- Camera video was never substituted for screen mirroring.

MIR-01–MIR-03 and AUD-07 are `NOT IMPLEMENTED`.

## 10. Reconciled case statuses

| Test | Status | Runtime basis |
|---|---|---|
| CAM-01 | PASS | Active cold-start request, background delivery, explicit Accept then Join, no pre-consent capture |
| CAM-02 | PASS | Parent raw live UI plus nonblack, varying in-memory frame metrics; direct RTP and deliberate scene change remain limitations |
| CAM-03 | BLOCKED | No approved reversible network interruption |
| CAM-04 | PARTIAL | Child service/controls and Parent inactivity verified; Android indicator and exact ongoing-notification wording not fully captured |
| CAM-05 | NOT IMPLEMENTED | Front-camera path only; no rear-camera switch found |
| CAM-06 | NOT IMPLEMENTED | No rotate/full-screen/flashlight workflow found |
| CAM-07 | FAIL | Audio-during-video content unproven and Parent End capture release delayed 52.624 s |
| AUD-01 | PASS | Background request, explicit Accept/Join, no pre-consent microphone activation |
| AUD-02 | PARTIAL | Parent live/playback and Child recording verified; no harmless phrase or direct RTP proof |
| AUD-03 | PARTIAL | State comparison performed; direct sent/received RTP counters unavailable in release UI |
| AUD-04 | PARTIAL | Parent capture inactive and Child service/Stop control verified; indicator/notification details incomplete |
| AUD-05 | NOT TESTED | Child Stop sharing was executed for video, not independently for audio |
| AUD-06 | FAIL | Parent End released Child capture only after 51.051 s |
| AUD-07 | NOT IMPLEMENTED | No recording/save/management workflow |
| MIR-01 | NOT IMPLEMENTED | No screen-mirroring initiation control |
| MIR-02 | NOT IMPLEMENTED | No HAVEN MediaProjection consent/token path |
| MIR-03 | NOT IMPLEMENTED | No mirrored-screen media/control/teardown workflow |
| BG-03 | PARTIAL | Background request, consent, changing video and role safety verified; teardown delayed |
| BG-04 | PARTIAL | Background request and audio live/playback state verified; audible content and prompt teardown not proven |
| BG-05 | NOT IMPLEMENTED | Independent screen-mirroring absence confirmed |

## 11. Final safety state

At the end of the verified media sequence:

- No remote session remained open.
- Parent terminal UI; no Parent camera, recording, playback or HAVEN foreground service.
- Child returned to background/Launcher; only Guardian and Location services remained.
- No Child camera, recording, playback or `AudioAssistanceService` remained.
- No credentials, tokens, device secrets, raw coordinates, package identities, private media or account identifiers are intentionally retained in this report.
- No remediation was attempted.
