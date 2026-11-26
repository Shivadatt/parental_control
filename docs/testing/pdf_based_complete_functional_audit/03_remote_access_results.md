# Remote Access Runtime Results

**Audit date:** 2026-11-26  
**Scope:** BG-03, BG-04, BG-05 and related CAM/AUD/MIR cases  
**Overall result:** **FAIL for request delivery; media-delivery cases BLOCKED; screen mirroring and recording workflows NOT IMPLEMENTED.**

## 1. Execution provenance

- Exactly four subagents were deployed for the audit. The remote-access subagent reached its 150-turn limit and returned `failed`; its partial evidence was treated as incomplete, not as a successful gate release.
- The main agent continued the same remote lane. No fifth subagent was created.
- The predecessor left BG-03/BG-04 collection errors, BG-05 absence evidence, and a clean-state snapshot, but no consolidated report.
- No application source, Kotlin source, manifest, Gradle file, dependency, Supabase schema/RLS/RPC/Edge Function, account, pairing, permission, device credential, policy, zone, or Git state was changed by this lane.

## 2. Verified runtime baseline

| Role | Serial | Model | Android / API | App | Network | Relevant native state |
|---|---|---|---|---|---|---|
| Parent | `emulator-5554` | `sdk_gphone64_x86_64` | 17 / 37 | `com.parentcontrol.parent_control` 1.0.0 (1) | Validated Wi-Fi | App foreground; no HAVEN foreground service; camera/microphone inactive |
| Child | `5HXWRGQ4IFU8WS4T` | RMX2161 | 12 / 31 | `com.parentcontrol.parent_control` 1.0.0 (1) | Validated Wi-Fi | Launcher foreground after Home; `GuardianService` and `LocationTrackingService` running; camera/microphone inactive |

Evidence: `evidence/lane3/BG04_RETRY_summary.json`, `evidence/lane3/MAINRECOVERY_STATE_summary.json`, and `evidence/lane3/LANE3_MAIN_FINAL_parent.txt` / `LANE3_MAIN_FINAL_child.txt`.

The existing Parent/Child relationship remained usable: the Parent device-detail page loaded the linked Realme device and reported existing permissions as granted; the Child Settings page loaded the existing family/account state. No sign-out, unlink, re-pair, recovery, or new registration was performed.

## 3. Confirmed runtime observations

### 3.1 Background camera request

- BG-03 original attempt: `2026-11-26T11:11:58+05:30` to `11:12:39+05:30`, 41.148 seconds, `COLLECTION_ERROR`.
- The Child was moved to Android Home and verified as `com.android.launcher/.Launcher`.
- Parent opened Remote assistance, tapped Request video, and confirmed Send request.
- Parent did not enter a waiting/consent state. No Child camera or microphone activation occurred.
- A post-recovery retry at `12:03:58+05:30`–`12:04:14+05:30` also failed. The retained Parent UI displayed **“Request failed The device is not active.”**
- A foreground-only diagnostic at `12:06:47+05:30`–`12:07:19+05:30`, with the Child app visibly open, failed with the same message. This rules out “Child UI merely backgrounded” as the sole trigger.

Evidence:
- `evidence/lane3/BG03_request_attempt_summary.json`
- `evidence/lane3/BG03_request_attempt_parent_BG03_parent_waiting.ui.txt`
- `evidence/lane3/BG03_RETRY_parent_BG03_RETRY_parent_waiting.ui.txt`
- `evidence/lane3/BG03_RETRY_RECOVERY_summary.json`
- `evidence/lane3/CAM_FOREGROUND_DIAG_summary.json`
- `evidence/lane3/CAM_FOREGROUND_DIAG_parent_CAM_FOREGROUND_DIAG_parent_waiting.ui.txt`

### 3.2 Background one-way audio request

- BG-04 original attempt: `2026-11-26T11:22:53+05:30` to `11:23:26+05:30`, 33.410 seconds, `COLLECTION_ERROR`.
- The Child was verified in Launcher/background.
- Parent opened Request audio and confirmed Send request.
- Parent displayed **“Request failed The device is not active.”** No waiting/consent state or Child microphone activation occurred.
- A protected post-recovery retry at `12:04:48+05:30`–`12:05:14+05:30`, 25.714 seconds, also failed to enter a waiting state. Its retained UI showed the request controls disabled/absent immediately after Send and no consent card; cleanup found no cancellable own request.

Evidence:
- `evidence/lane3/BG04_summary.json`
- `evidence/lane3/BG04_parent_BG04_parent_waiting.ui.txt`
- `evidence/lane3/BG04_RETRY_summary.json`
- `evidence/lane3/BG04_RETRY_parent_BG04_RETRY_parent_waiting.ui.txt`
- `evidence/lane3/BG04_RETRY_commands.log`

### 3.3 Child presence/recovery state

- Native Child state showed validated Wi-Fi plus running `GuardianService` and `LocationTrackingService`.
- Child Settings initially showed **“Last command check 20 h ago”** and **“App list upload failed: apps[14].package_name is not a valid Android package name.”**
- The visible Retry background protection action changed the command-check label to **“Just now”**, but the app-list upload error remained.
- Parent Remote assistance continued to display **“Request failed The device is not active.”** before and after retry, including while the Child app was foreground.
- This is a runtime presence/request-delivery defect or unavailable precondition. The exact server/source root cause is not assigned here; it is deferred to the post-runtime source trace.

Evidence: `evidence/lane3/MAINRECOVERY_DEVICE_summary.json`, `evidence/lane3/MAINRECOVERY_REFRESH_summary.json`, and `evidence/lane3/LANE3_MAIN_FINAL_summary.json`.

### 3.4 Screen mirroring and recording absence

- Parent Remote assistance exposed only Request audio and Request video; no screen-mirroring action was present.
- The runtime disclosure states: **“Nothing is recorded, and no screenshots or screen capture are taken.”**
- Recent-session cards exposed only Tap to open the session screen; no record/save/manage control was present.
- A scoped source scan found zero `MediaProjection`, `VIRTUAL_DISPLAY`, and `FOREGROUND_SERVICE_MEDIA_PROJECTION` matches under `lib/` and `android/`.
- `dumpsys media.projection` was unavailable on both devices (`Can't find service: media.projection`), so no positive OS projection-session claim is made. The absence classification rests on the runtime control inventory plus the zero-match source scan, not on OS capability alone.

Evidence: `evidence/lane3/BG05_summary.json`, `evidence/lane3/BG05_source_scan.txt`, `evidence/lane3/LANE3FINAL_summary.json`, and `evidence/lane3/LANE3_MAIN_FINAL_summary.json`.

## 4. Case status reconciliation

| Test | Status | Runtime basis |
|---|---|---|
| CAM-01 | FAIL | Video request did not reach Child consent; explicit inactive-device failure, including foreground diagnostic. |
| CAM-02 | BLOCKED | No accepted/joined camera session; actual received video cannot be tested. |
| CAM-03 | BLOCKED | No active consented camera session for interruption/recovery. |
| CAM-04 | BLOCKED | No active camera session for indicators/visibility verification. |
| CAM-05 | BLOCKED | Active/idle session camera-selection controls could not be fully exercised because no session started. |
| CAM-06 | BLOCKED | Active-session rotate/full-screen/flashlight controls could not be fully exercised. |
| CAM-07 | BLOCKED | No active video session for audio/teardown verification. |
| AUD-01 | FAIL | Audio request did not reach Child consent; explicit inactive-device failure. |
| AUD-02 | BLOCKED | No accepted/joined audio session; no live phrase/RTP proof possible. |
| AUD-03 | BLOCKED | No active session for signalling-versus-media comparison. |
| AUD-04 | BLOCKED | No active session for role-specific microphone/privacy verification. |
| AUD-05 | BLOCKED | No active session for Child Stop sharing. |
| AUD-06 | BLOCKED | No active session for Parent End/teardown. |
| AUD-07 | NOT IMPLEMENTED | Runtime disclosure/history show no recording, save, or management workflow. |
| MIR-01 | NOT IMPLEMENTED | No Parent screen-mirroring action; camera was not substituted. |
| MIR-02 | NOT IMPLEMENTED | No HAVEN MediaProjection consent/token path; source scan has zero relevant matches. |
| MIR-03 | NOT IMPLEMENTED | No mirrored-screen session/control/artifact workflow; no Child capture occurred. |
| BG-03 | FAIL | Background camera request failed before consent/delivery. |
| BG-04 | FAIL | Background audio request failed before consent/delivery. |
| BG-05 | NOT IMPLEMENTED | Independent screen-mirroring absence confirmed. |

`BLOCKED` here means the required active consented session could not be established. It does not imply that media delivery passed.

## 5. Main-agent continuation commands

Working directory for all commands: `D:\parentcontrol_app`.

```text
PYTHONIOENCODING=utf-8 python -c "... Audit('BG03_RETRY', ...); execute_media(..., 'video') ..."
# exit 1; traceback: Parent did not enter Waiting for consent state

PYTHONIOENCODING=utf-8 python -c "... Audit('BG03_RETRY_RECOVERY', ...); cleanup(...); finish(...) ..."
# exit 0; cleanup/native evidence collected

PYTHONIOENCODING=utf-8 python -c "... Audit('BG04_RETRY', ...); execute_media(..., 'audio') ..."
# exit 1; summary duration 25.714 s; COLLECTION_ERROR

PYTHONIOENCODING=utf-8 python -c "... Audit('CAM_FOREGROUND_DIAG', ...); execute_media(..., 'video', background_child=False) ..."
# exit 1; summary duration 32.378 s; Request failed before Child consent

python docs/testing/pdf_based_complete_functional_audit/evidence/lane2/native_state.py emulator-5554 LANE3_MAIN_FINAL_parent
# exit 0; 0.524 s

python docs/testing/pdf_based_complete_functional_audit/evidence/lane2/native_state.py 5HXWRGQ4IFU8WS4T LANE3_MAIN_FINAL_child
# exit 0; 0.843 s
```

The BG-03 retry wrapper initially exited before its `finally`-equivalent report write because the helper lacked exception finalization. The main agent immediately ran a separate cleanup/native verification. The helper was then hardened to poll request state and guarantee cleanup/finalization for subsequent attempts.

## 6. Final safety state

At `2026-11-26T12:08:35+05:30`:

- Parent: app foreground; no HAVEN foreground service; camera inactive; recording inactive; playback inactive.
- Child: Launcher/background; `GuardianService` and `LocationTrackingService` running; camera inactive; recording inactive; playback inactive; no `AudioAssistanceService`.
- No open/terminal remote-session marker was present on the Parent remote page; the page retained the inactive-device error.
- No permission, account, pairing, credential, policy, zone, network, or Git mutation was performed.

Evidence: `evidence/lane3/LANE3_MAIN_FINAL_parent.txt`, `evidence/lane3/LANE3_MAIN_FINAL_child.txt`, and `evidence/lane3/LANE3_MAIN_FINAL_summary.json`.

## 7. Limits

- No WebRTC request reached Child consent, so RTP, ICE/DTLS, received frames, received audio, camera switching, Stop sharing, and Parent End could not be exercised.
- No screen mirroring was started or bypassed.
- No private media, credentials, tokens, device secrets, coordinates, or personal message content was retained.
- No remediation was attempted.
