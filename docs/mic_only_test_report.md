# Microphone-Only End-to-End Test — Parent (emulator, left) → Child (realme, right)

Date: 2026-10-28 · Auditor: automated QA session driven over ADB
Repository: `D:\parentcontrol_app` (Flutter 3.44.6 / Dart 3.12.2 via FVM, GetX, native Kotlin, Supabase)

## 0. Scope and rules observed

In scope: microphone capture on the child, one-way child→parent audio, permissions, foreground/background behaviour, privacy indicators, cleanup.

Explicitly out of scope, not exercised: camera/video, screen recording, Instagram/app blocking, location and other parental-control features, unrelated Supabase tables/functions.

Rules observed:

- No source code was modified **by this audit**. The only file added is this report. (A separate process did change the working tree after the tested build; see "Post-test working-tree changes" below.)
- No backend deployment, RLS change, rate-limit change or production-data change was made.
- Android permissions and privacy indicators were not bypassed or hidden; the app's own permission flow was used.
- No factory reset, no app-data clear, no revocation of unrelated or real linked devices.
- A UI status was not accepted as proof of device behaviour. Capture/playout was verified from OS counters (`appops`, `dumpsys audio`, `dumpsys media.audio_flinger`) and WebRTC audio-device statistics at both endpoints.
- Evidence files are under `.tools/evidence/qa-20261028-mic/` (git-ignored). `live/` holds this session's files.

### Devices under test

| Role | Serial | Model | OS | App |
| --- | --- | --- | --- | --- |
| Parent (viewer/listener) | `emulator-5554` | `sdk_gphone64_x86_64` | Android 17 (API 37) | `com.parentcontrol.parent_control` versionCode 4005, versionName 1.0.0, minSdk 24, targetSdk 36 |
| Child (microphone source) | `5HXWRGQ4IFU8WS4T` | realme RMX2161 | Android 12 (API 31) | same package, versionCode 4005 |

Build under test: debug build from the working tree, `versionCode 4005` on both devices (`dumpsys package` `lastUpdateTime` 11:28:42 parent / 11:28:56 child). Local artifact `.tools/evidence/qa-20261028-mic/apk/base4005.apk`, SHA-256 `649ef4d246a447f416cb10fba80999e30f4cfe8b3e809d0284a37d4f59382e99` (217,389,522 bytes).

### Build provenance and contamination disclosure

- `versionCode 4002` (a two-way build from `HEAD`) was installed before 11:28. The permission-dialog tests in §4 were captured at 11:24–11:26 on 4002, before 4005 was installed. All §5/§6 media results are from 4005.
- An external process (not this audit) rebuilt/installed 4005 at 11:28 and sent ADB input to the child (e.g. `input tap 540 1608` — Join — at 11:39:32). Tap logs are disclosed because the app itself has no auto-join.
- At 11:53 the child Wi-Fi was toggled to exercise network loss; the restore left a transient "network unavailable" banner at 12:00–12:02 although `dumpsys connectivity` showed a validated Wi-Fi network and `ping 8.8.8.8` succeeded at 12:03.
- During the 12:07 lock test the phone unlocked itself via biometrics roughly 20 s after screen-off (keyguard logs at 12:07:10; `mWakefulness=Awake` by 12:07:31). The lock-state evidence therefore covers ~20 s only.

### Post-test working-tree changes (not made by this audit)

While this audit was writing the report, a separate process (the same external actor noted above) modified the working tree:

| File | mtime | Change |
| --- | --- | --- |
| `android/app/src/main/AndroidManifest.xml` | 12:04:52 | adds `FOREGROUND_SERVICE_MICROPHONE` (`:15`) and `<service android:name=".AudioAssistanceService" … android:foregroundServiceType="microphone" />` (`:86-89`) |
| `android/.../AudioAssistanceService.kt` | 12:06:49 (new file) | `microphone`-typed foreground service with a persistent notification and Stop action |
| `lib/features/remote_assistance/remote_session_controller.dart` | 12:13:32 | native `audio_assistance_stopped` event (`:150-159`), extra audio constraints (`:543-557`), `onIceConnectionState` hook (`:585-587`), reconnect-timer calls (`:601,606,617,620`) and definitions (`:802-847`), service start (`:660-662`) |

These changes are **not in the installed 4005 APK** (installed 11:28, before the edits). The file was still being edited while this report was written: at 12:13:14 the three reconnect methods were called but not defined; definitions appeared at 12:13:32. This audit did not build, install, execute or review these changes, and did not modify them. All live findings below describe build 4005; where the untested worktree contains a candidate fix, the status is **NOT TESTED (fix present, unverified)**. The worktree's build state is unverified — no build was produced by this audit.

Line numbers below refer to the current worktree (mtimes 12:04–12:13), not to the exact source snapshot that produced 4005; apart from the additions listed above the logic is the same.

## 1. Verdict summary

| Area | Verdict |
| --- | --- |
| One-way topology (parent never captures, child sends) | **PASS — LIVE VERIFIED** |
| Child→parent audio transport (real audio statistics) | **PASS — LIVE VERIFIED** |
| Audibility by human ear / test-phrase content | **NOT TESTED** |
| Runtime microphone permission (real Android dialog) | **PASS — LIVE VERIFIED** (4002), not re-run on 4005 |
| Microphone foreground-service configuration (build 4005) | **FAIL — NOT CONFIGURED** |
| Microphone FGS fix present in current worktree | **NOT TESTED** (present 12:04–12:13, not built/installed; build state unverified) |
| Background (HOME) operation (build 4005) | **FAIL — LIVE VERIFIED** |
| Screen-locked operation (build 4005) | **FAIL — LIVE VERIFIED** |
| Removed from recents / force-stop on 4005 | **NOT TESTED** (4002 supplementary) |
| Cleanup and mic release on end | **PASS — LIVE VERIFIED** |
| Visible OS privacy indicator during capture | **FAIL — not observed** (device/ROM-level) |

## 2. Status vocabulary

- **PASS — LIVE VERIFIED**: observed on devices during this audit, with OS/WebRTC evidence.
- **PASS — LOCAL VERIFIED**: verified by reading the shipped code/paths; not re-executed on hardware.
- **PARTIAL**: some required aspect verified, another aspect missing.
- **FAIL**: verified behaviour does not meet the requirement.
- **NOT IMPLEMENTED**: no code path exists.
- **NOT TESTED**: not executed in this audit (reason given).
- Severities: **P0** privacy/security breach, **P1** core function broken, **P2** significant defect, **P3** cosmetic/copy.

## 3. Permission and setup audit

| # | Case | Status | Evidence |
| --- | --- | --- | --- |
| 3.1 | `RECORD_AUDIO` declared in the manifest | PASS | `android/app/src/main/AndroidManifest.xml:10` |
| 3.2 | Microphone hardware not mandatory (installable without a mic) | PASS | `AndroidManifest.xml:31-33` (`required="false"`); the app does not pre-check for a mic |
| 3.3 | Runtime grant uses the real Android dialog, not a substitute | PASS — LIVE VERIFIED (4002) | `c_android_mic_dialog.png`, `c_appsettings.xml`; `NativeBridge.kt:359-390` calls `activity.requestPermissions`; no custom dialog exists in `lib/` |
| 3.4 | Child-only capture; parent is receive-only in code | PASS — LOCAL VERIFIED | `remote_session_controller.dart:502-515` (parent skips the permission request), `:543-566` (local stream and constraints built only when `!isParentRole`), `:705-709` (`getUserMedia`), parent copy `remote_session_page.dart:285,288` |
| 3.5 | One-way topology at runtime | PASS — LIVE VERIFIED (4005, 12:06) | Parent `appops` duration stayed at 38.108 s from 11:19 and showed no `(running)`; parent ADM emitted **0** `[REC]` lines; child `appops` showed `(running)` and child ADM emitted `[REC : 10000msec, 48kHz]`; see `m_baseline.txt`, `p_webrtc_ow.txt`, `c_webrtc_ow.txt` |
| 3.6 | Foreground-service type for microphone — **tested build 4005** | **FAIL — NOT CONFIGURED** | 4005 declared `FOREGROUND_SERVICE` (`:12`), `FOREGROUND_SERVICE_DATA_SYNC` (`:13`), `FOREGROUND_SERVICE_LOCATION` (`:14`); services were `GuardianService` `foregroundServiceType="dataSync"` and the location service. No `microphone` service type existed, which Android 12 requires for mic use from a foreground service. |
| 3.6b | Foreground-service type for microphone — **current worktree** | **NOT TESTED** (fix present) | Worktree now declares `FOREGROUND_SERVICE_MICROPHONE` (`AndroidManifest.xml:15`) and `AudioAssistanceService` `foregroundServiceType="microphone"` (`:86-89`), started from `remote_session_controller.dart:660-662`. Not in the tested APK; not built or installed; correctness and runtime behaviour unreviewed. |
| 3.7 | Android 12 foreground capture | PASS — LIVE VERIFIED | 11:39–11:43 and 12:06–12:07 with screens on and app in foreground; see §5 |
| 3.8 | Android 12 background/locked behaviour (build 4005) | **FAIL** | See §6: capture stops, media connection cannot be maintained, no recovery |
| 3.9 | Visible capture indicator | **FAIL — not observed** | No microphone indicator in the child status bar in `c_fg_indicator.png` (11:53, capture active), `c_fg_indicator2.png`, or `c_bg5.png` (background). The in-app UI does show a live state. This is ROM-level behaviour (ColorOS) and cannot be "fixed" by the app; it is recorded as an unmet privacy-visibility requirement. |
| 3.10 | Notification about capture | PARTIAL (4005) / NOT TESTED (worktree service) | In 4005 only the app's `guardian_status` notification channel existed (`logcat -b events` at 11:57:46, id 4101); no capture-specific ongoing notification, and the dataSync `GuardianService` was not tied to the audio session. The worktree's `AudioAssistanceService` is written to post a persistent notification with a Stop action, but it was never run. |

Note on expiry values: request TTL is 10 min (`supabase/functions/remote-session/index.ts:28`, dialog copy at `remote_assistance_page.dart:184`); after acceptance the expiry becomes 30 min (`index.ts:29`). The "10 min" on the request dialog and the "25–29 m" on an accepted session are therefore consistent, not a bug.

## 4. First-time permission tests (real Android dialog)

| # | Case | Status | Evidence |
| --- | --- | --- | --- |
| 4.1 | First child Join triggers the system microphone dialog | PASS — LIVE VERIFIED (4002) | `c_android_mic_dialog.png` (11:24); permission row absent before, present after (`c_appsettings.xml`, `c_perms_list.xml`) |
| 4.2 | Grant → capture starts | PASS — LIVE VERIFIED | 4002 at 11:25–11:26 (`c_after_grant.xml`, appops `(running)`); 4005 at 11:39 and 12:06 without a new prompt |
| 4.3 | Deny → capture does not start | PASS — LIVE VERIFIED (4002) | `c_after_deny.xml` (11:25): permission denied, no active record client, no `[REC]` output. Not re-run on 4005 (identical request path, no new dialog was shown). |
| 4.4 | Denial is surfaced to the user and not mistaken for success | PASS — LOCAL VERIFIED | `remote_session_controller.dart:507-513,677-681` sets `permissionDenied`; child banner `child_session_page.dart:132-142`; `getUserMedia` failure mapping `:749-764` |
| 4.5 | Grant persists across restart/update | PASS — LIVE VERIFIED | Grant given 11:26 on 4002; app updated at 11:28; 4005 sessions at 11:39 and 12:06 captured with no dialog. Current flags: `RECORD_AUDIO: granted=true, flags=[…ONE_TIME]` (child). |
| 4.6 | Grant is not permanent | PASS — LIVE VERIFIED | Child flags include `ONE_TIME` (no `USER_SET`): a one-time grant that Android may revoke. This audit does not claim permanent authorization. |
| 4.7 | Background capture is not implied by the grant | PASS — verified limitation | Nothing in the app elevates a one-time foreground grant; background capture stops (§6). |

Parent device: `RECORD_AUDIO` is granted (`USER_SET`) but the app never requests or opens it (3.5). The grant is unnecessary for the parent role and could be removed as hardening (P3).

## 5. One-way audio session tests

Session sequence tested (build 4005, 12:01–12:08): parent request → child review → child `Accept` → child `Join with microphone` (confirmation dialog) → parent `Listen to audio` → audio → parent `End`.

| # | Case | Status | Evidence |
| --- | --- | --- | --- |
| 5.1 | Request delivered; child must explicitly accept | PASS — LIVE VERIFIED | Child pending list with `Accept`/`Decline`; accept dialog (`c_m5.xml`); consent card copy `child_session_page.dart:202-241` |
| 5.2 | Capture starts only after explicit Join, not at accept | PASS — LIVE VERIFIED | Child appops had no `(running)` flag from 12:01 to 12:05; `(running)` appeared only after the Join confirmation; camera not requested (audio session constraints at `remote_session_controller.dart:543-557`) |
| 5.3 | Child audio reaches the parent (actual track statistics) | PASS — LIVE VERIFIED | Child ADM: `[REC : 10000msec, 48kHz] … level: 5637` at 12:06:49 (non-zero, varying levels throughout). Parent ADM: `[PLAY: 10004msec, 8kHz] … level: 14928` at 12:06:52, `level: 11192` at 12:07:02. Earlier run: parent levels 4231/974/615/279/1729/21299/21126 at 11:39:58–11:40:59; child levels 2007/378/2281/158/136/11655/486 at 11:39:56–11:40:56. Evidence: `c_webrtc_ow.txt`, `p_webrtc_ow.txt`, `m_baseline.txt`. |
| 5.4 | Audible on the parent speaker / stated phrase understood | **NOT TESTED** | No human listener in this remote run; only signal-level statistics are available. The phrase content cannot be inferred from levels. |
| 5.5 | Parent microphone is never captured | PASS — LIVE VERIFIED | Parent appops unchanged since 11:19 (`duration=+38s108ms`, no `(running)`); parent ADM 0 `[REC]` lines; parent audio-flinger has no active input thread; parent UI states "Your microphone will not be used." (`remote_session_page.dart:285,288,369-372`) |
| 5.6 | Parent audio is not transmitted; child plays nothing back | PASS — LIVE VERIFIED | Child ADM 0 `[PLAY]` lines in either 4005 session; child never starts playout. Parent is receive-only by construction: only the local stream is added (`remote_session_controller.dart:630-634`), and the parent never creates one (`:543-566`). |
| 5.7 | Mute control during a live session | **NOT IMPLEMENTED / NOT TESTED** | No mute control on either live session page. The only mute toggle is in the device self-test sheet (`lib/features/child/widgets/media_self_test_sheet.dart:319`), not in a session. |
| 5.8 | End stops capture and playback | PASS — LIVE VERIFIED | Parent End → confirm at 12:08; session became `Ended` / `ended_by_parent`; child appops not `(running)`; child `AudioIn_66` `Standby: yes`; parent playout level 0 |
| 5.9 | Network loss — **tested build 4005** | **FAIL — LIVE VERIFIED** | 11:41–11:42: child capture continued (mic stayed on) while parent playout fell to level 0; both sides showed "Media connection failed"/"Connecting"; the session remained open and required a manual End; no automatic stop of the child mic. `p_net1.xml`, `p_net2.xml`. The worktree's reconnect candidates are **NOT TESTED** (see 5.10). |
| 5.10 | Automatic reconnect / ICE restart | **NOT IMPLEMENTED (4005) / NOT TESTED (worktree)** | In 4005 `onConnectionState` only set flags and a warning; there was no ICE restart path, and the UI told the parent to end and request a new session. The current worktree adds an `onIceConnectionState` hook and a 15-second reconnect timer (`remote_session_controller.dart:585-587,802-847`). By inspection the timer only raises a warning and does not restart ICE, stop capture or end the session, but this code has not been built, installed or exercised, so it is not evidence of working recovery. |
| 5.11 | Duplicate/stale display after a new request | **FAIL** (UI defect) | At 12:01 a new request navigated to the old 11:49 ended session page (stale GetX controller). Root cause: `fenix: true` bindings — `child_session_binding.dart:11-19`, `remote_session_binding.dart:12-20` |

Observed one-way invariants (summary):

- Child microphone was the only capture source; parent never opened the mic (OS counters, not just UI).
- Child never played audio; no return path existed to echo parent audio back.
- The parent's "One-way audio live" card and "Your microphone will not be used." copy are consistent with the runtime behaviour.

## 6. Background-state matrix (child device, build 4005)

| # | State | Status | Observed behaviour |
| --- | --- | --- | --- |
| 6.1 | Foreground, screen on | PASS — LIVE VERIFIED | Capture and playout active; child `AudioIn` not in standby; parent levels non-zero (11:39–11:43, 12:06–12:07) |
| 6.2 | Background (HOME) | **FAIL — LIVE VERIFIED** | After HOME at ~11:54:05, capture continued ~24 s (appops foreground duration `+24s407ms`), then the WebRTC audio engine and Flutter activity were torn down at 11:54:29 (`onConnectionChangeCLOSED`, `AudioSendStream::Stop`, `StopRecording`, `WebRtcVoiceEngine::Terminate` in `c_bg_close.txt`); process survived (same PID). Parent showed "Media connection failed" but status stayed "Live"/"Accepted"; no recovery, no automatic end. |
| 6.3 | Screen locked | **FAIL — LIVE VERIFIED** | Power key at 12:07:11; keyguard `onStartedGoingToSleep` at 12:07:10; child capture stopped (appops last access 12:07:10, no `(running)`; `AudioIn_66` standby); parent playout decayed to level 0 by 12:07:42 and showed failure; no capture or media recovery after the phone auto-unlocked ~20 s later. Caveat: biometric auto-unlock shortened the locked window; the capture-stop is unambiguous. |
| 6.4 | Removed from recents | **NOT TESTED on 4005** | Supplementary 4002 evidence (`c_recents.png`, 11:18) showed the task/engine destroyed and capture stopped; not re-run on 4005 to avoid further state churn after the lock test invalidated the session. |
| 6.5 | Force-stopped via Settings | **NOT TESTED on 4005** | Supplementary 4002 evidence (`c_fs1.txt`, `c_fs2.txt`, 11:18–11:19) showed process death and stopped capture; the parent had to end the session manually. 4005 behaviour not re-tested. |

Cross-cutting finding for build 4005: because no microphone foreground-service type was declared (3.6), background/locked capture was not supportable on Android 12. The app did not warn the user that the session would die when the child left the app.

The current worktree contains an `AudioAssistanceService` (`foregroundServiceType="microphone"`, persistent notification with a Stop action) plus the manifest permission. It is supposed to address 6.2/6.3, but it is **not in the tested APK, it has not been built or installed, and it has not been exercised**. Treat 6.2/6.3 as open failures until that change is built and re-run through this matrix.

## 7. Privacy, cleanup and log audit

| # | Case | Status | Evidence |
| --- | --- | --- | --- |
| 7.1 | Session status cleared after end | PASS | Parent detail page shows `Ended` and `Reason: ended_by_parent` at 12:09 (`p_m_ended2.xml`); child shows no pending request after relaunch (`c_req_end2_ow.png`) |
| 7.2 | Stop is accessible | PASS for parent / **NOT TESTED** for child-initiated stop | Parent has header `End` and an `End session` button with a confirmation dialog (`remote_session_page.dart:103,392`; `p_m_endd2.xml`). The child page exposes `End session` (`child_session_page.dart:74-82`, confirm at `:401-412`) but the child-initiated path was not exercised |
| 7.3 | Parent audio never sent to the child | PASS — LIVE VERIFIED | See 5.5/5.6: no parent capture, no child playout |
| 7.4 | No stored microphone data | PASS | `run-as … find files app_flutter -type f` on the child shows only Flutter assets and profile files; no `.m4a/.wav/.pcm/.aac/.opus` anywhere in app storage. The app uses no `MediaRecorder`/`AudioRecord` of its own (grep: no matches in `lib/` or `kotlin/`); capture is only the WebRTC in-memory stream |
| 7.5 | No audio payloads, tokens or credentials in logs | PASS | Recent 8,000-line child buffer contains 0 matches for `access_token|refresh_token|service_role|eyJhb|password=|apikey` (`c_log_secrets_ow.txt`). Earlier buffers contained a request URL with the literal parameter name `grant_type=refresh_token` but no token value. Logcat contains WebRTC level statistics, not audio samples |
| 7.6 | Capture stops on logout | **NOT TESTED** | Signing out during a live session was not exercised |
| 7.7 | Capture stops on app termination | PARTIAL | Background teardown stopped capture at 11:54:29; 4002 force-stop stopped it; 4005 force-stop not tested |
| 7.8 | Capture stops on permission revocation | **NOT TESTED** | Not exercised during a live session |
| 7.9 | Capture stops on device revocation | **NOT TESTED** | Deliberately not performed: the linked real device would need to be revoked, which the brief forbids for real devices |
| 7.10 | Microphone released after end | PASS — LIVE VERIFIED | `appops … RECORD_AUDIO`: child `allow` with no `(running)`, last access 12:07:10; parent unchanged since 11:19; child `AudioIn_66` `Standby: yes`; parent AudioOut threads standby; no active track (`cleanup_state_ow.txt`) |

## 8. Defects found (no fixes applied)

| ID | Severity | Defect | Source references | Evidence |
| --- | --- | --- | --- | --- |
| MIC-01 | P1 | No microphone foreground-service type in build 4005. Capture cannot continue when the child backgrounds or locks the screen on Android 12; the session dies with no warning and no recovery. | 4005: manifest permissions `:12-14`, services `:76-84`. Current worktree candidate fix (unverified): `AndroidManifest.xml:15,86-89`, `AudioAssistanceService.kt`, started at `remote_session_controller.dart:660-662` | §6.2, §6.3. **Fix present in worktree — NOT TESTED** (not in the APK under test; not built or exercised). |
| MIC-02 | P1 | A failed media connection does not stop capture or end the session. After network loss the child microphone stayed open until the parent manually ended the session, while the UI showed contradictory states. | `remote_session_controller.dart:598-628` (Failed/Disconnected branches only set a warning), `:115-120` (`statusLabel` ignores media state); `remote_session_page.dart:197-205,327-334,453` | 5.9; `p_net1.xml`, `p_net2.xml`. The worktree's reconnect timer is untested; by inspection neither the peer-state nor the ICE-state failure branch tears down capture or ends the session — they only set a warning. |
| MIC-03 | P2 | `_markActiveStarted()` runs before the peer is connected, and its failure message claims "The call is connected" when it is not. Session status can remain `Accepted` while media is live, or show connected UI while no capture runs. | Call site `remote_session_controller.dart:663-666`; method/message `:693-703` | 12:02 child page (`c_m8_joined.png`): "call is connected" banner with `Recording active: false`; 12:06 parent: "Connected" + status `Accepted` |
| MIC-04 | P2 | Stale session screen: a new request can open the previous ended session because the controller is kept alive with `fenix: true`. | `lib/features/child/child_session_binding.dart:11-19`; `lib/features/remote_assistance/remote_session_binding.dart:12-20`; `lib/features/child/controllers/child_requests_controller.dart:192-193` | 12:01: after "Send request" the parent displayed the ended 11:49 session |
| MIC-05 | P2 | Every pending/active request card shows "expires Just now": a past-tense formatter is applied to a future expiry timestamp. | `lib/features/child/child_requests_page.dart:294`; `lib/features/child/tabs/child_requests_tab.dart:128`; `lib/core/utils/formatters.dart:18-27` | `c_m4.xml` at 12:01: "Audio assistance · expires Just now" for a request with 29 minutes left |
| MIC-06 | P2 | 13 px horizontal overflow in the child session status row. | `lib/features/child/child_session_page.dart:332-345` (fixed-width `Text` after `Spacer` at `:340-342`) | `c_fg_indicator.png` (11:53): "RIGHT OVERFLOWED BY 13 PIXELS" |
| MIC-07 | P2 | Contradictory media copy in an audio-only session: "Microphone on — waiting for the parent" while also "Connecting…", and "Ending stops camera and microphone" in a microphone-only flow. | `lib/features/child/child_session_page.dart:321-325,342,94` | `c_fg_indicator.png` at 11:53 |
| MIC-08 | P3 | Ended session page keeps the "Media connection failed" and "Relay not configured" banners after the session ends. | `lib/features/remote_assistance/remote_session_page.dart:162-205` (banners do not check `isTerminal`) | `p_m_ended2.xml` at 12:09; `p_after_end_ow.png` at 11:57 |
| MIC-09 | P3 | The parent grant of `RECORD_AUDIO` is unnecessary and can be removed; the parent role never requests or opens the microphone. | `remote_session_controller.dart:502-515,737-747` | 5.5 |

Not reported as a bug: the 10-minute request TTL vs 30-minute accepted-session TTL (see §3 note).

## 9. Manual Android setup steps (reproduction)

1. Build and install the same build on both phones:
   ```
   fvm flutter build apk --debug
   adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
   adb -s 5HXWRGQ4IFU8WS4T install -r build/app/outputs/flutter-apk/app-debug.apk
   adb -s <serial> shell dumpsys package com.parentcontrol.parent_control | grep versionCode
   ```
   Confirm `versionCode 4005` on both before testing. **Caveat (2026-10-28 12:15):** the worktree was still being edited while this report was written (reconnect-method definitions appeared at 12:13:32 after calls were added at 12:13:14). No build was produced by this audit and the worktree's build state is unverified. A re-run must be treated as a new build with unverified FGS and reconnect behaviour.
2. Sign in the dedicated QA parent on the emulator and the dedicated QA child on the realme; confirm the device is linked and online on the dashboard.
3. First-time microphone permission (child): open the pending audio request → `Accept` → `Join with microphone` → `Join now` → choose **Allow** on the Android system dialog. Do not substitute an in-app dialog. Verify:
   ```
   adb -s 5HXWRGQ4IFU8WS4T shell dumpsys package com.parentcontrol.parent_control | grep -A1 RECORD_AUDIO
   adb -s 5HXWRGQ4IFU8WS4T shell appops get com.parentcontrol.parent_control RECORD_AUDIO
   ```
4. To test denial, revoke and retry through the UI (test-only; never in production):
   ```
   adb -s 5HXWRGQ4IFU8WS4T shell pm revoke com.parentcontrol.parent_control android.permission.RECORD_AUDIO
   ```
   Join again, tap **Deny**, and confirm no record client starts:
   ```
   adb -s 5HXWRGQ4IFU8WS4T shell dumpsys audio | grep -i "Recording active"
   adb -s 5HXWRGQ4IFU8WS4T shell dumpsys media.audio_flinger | grep -A3 "type 3 (RECORD)"
   ```
5. Parent listener: open the session → `Listen to audio` → `Join now`. Verify one-way audio from statistics, not status text:
   ```
   adb -s emulator-5554 logcat -s audio_device_buffer.cc | findstr PLAY
   adb -s 5HXWRGQ4IFU8WS4T logcat -s audio_device_buffer.cc | findstr REC
   ```
   Parent must show only `[PLAY: …]`; child only `[REC: …]`.
6. Lock-screen test: disable fingerprint/face unlock, set a short screen timeout, lock with `adb shell input keyevent 26`, then check appops and flinger as above. (In this audit biometrics unlocked the phone after ~20 s.)
7. Background test: press HOME, then check appops/flinger/logcat for `AudioSendStream::Stop` / `StopRecording`.
8. Force-stop test: Settings → Apps → Parent Control → Force stop (or `adb shell am force-stop com.parentcontrol.parent_control`), then verify the process is gone and the parent session has to be ended manually.
9. TURN: this build has `turn_configured:false` ("Relay not configured"), so sessions are expected to fail on carrier NAT or strict-firewall networks. Configure TURN server-side for wider testing; do not put TURN secrets in evidence.

## 10. Not tested / residual gaps

- Audibility by ear and the content of the harmless test phrase (statistics only; no listener).
- Mute during a live session (no control exists).
- Child-initiated End.
- Removed-from-recents and force-stop on build 4005 (4002 evidence is supplementary only).
- The entire background/locked matrix with a microphone foreground service: the worktree contains a candidate `AudioAssistanceService` but it has not been built, installed or exercised.
- Automatic reconnect after network loss: the worktree adds a reconnect timer but it has not been built or exercised; by inspection it only warns and does not restart ICE, stop capture or end the session.
- Logout during capture; runtime permission revocation during capture; device revocation during capture.
- OS-level guarantee of a privacy indicator (none was shown by ColorOS while capture was active).
- Camera/video, screen recording, app blocking, location (explicitly out of scope).
- Network-loss test after the 11:53 Wi-Fi toggle left a transient "network unavailable" state; the connectivity was re-verified as working at 12:03 before the second session.

## 11. Change summary

- Source code, tests, backend functions and database: **unchanged by this audit**. No fix from §8 was applied or proposed as a code change.
- Added: `docs/mic_only_test_report.md` (this file); raw evidence under `.tools/evidence/qa-20261028-mic/` (git-ignored).
- The working tree was already dirty before this audit and was not reverted or committed by it. During the audit a **separate process** modified `AndroidManifest.xml` (12:04:52), created `AudioAssistanceService.kt` (12:06:49) and edited `remote_session_controller.dart` (12:13:32); those edits are described in "Post-test working-tree changes" and were neither built nor tested. The tree was still changing while this report was written, so its build state is unverified.
- Device-side state changed during testing: enabled/disabling Wi-Fi on the child, the earlier `pm revoke`/`grant` of `RECORD_AUDIO` on the child for permission tests, creation/acceptance/ending of QA sessions (11:23, 11:34, 11:46, 11:49, 12:01), and app restarts (`am force-stop` + relaunch) on the parent to clear a stale session screen. No factory reset, no app-data clear, no device revocation.
