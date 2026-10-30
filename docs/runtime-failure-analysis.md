# Runtime failure analysis — Pixel 9a (parent) + realme RMX2161 (child)

Date: 2026-10-29. All times IST (UTC+5:30). Build under test:
`app-debug.apk` sha256 `7ee501fa0e1c…` (243,869,900 B), built with
`scripts/build_debug_apk.sh` (`--dart-define-from-file=.tools/live_config.env`).

Devices confirmed at runtime:

| Role | Serial | Identity | OS |
|---|---|---|---|
| Parent | `emulator-5554` | Google Pixel 9a AVD (`sdk_gphone64_x86_64`) | Android 17 (SDK 37) |
| Child | `5HXWRGQ4IFU8WS4T` | **physical** realme RMX2161 (mt6785) | Android 12 / API 31 |

Accounts verified on-device without exposing credentials:
parent `ankit@gmail.com` (role `parent`), child `ankit1@gmail.com` (role
`child`), family `demo`.

---

## F0 — Blocking environmental event: an unconfigured APK replaced the build under test

| Field | Value |
|---|---|
| Symptom | Child app switched to "Connect the backend — SUPABASE_URL Not set"; parent lost media; session went to "Connection setup failed" |
| Observed | 17:14:31 IST task removed; 17:16:22 IST `lastUpdateTime` of `com.parentcontrol.parent_control` changed; 17:13 APK on disk was 146,701,573 B and contained **zero** occurrences of the project ref `hhqgreaoqulmfwfwarhc` in `kernel_blob.bin` |
| Cause | A rebuild in this workspace (`flutter build apk --debug` without `--dart-define-from-file`) produced an APK with no Supabase URL/anon key, and that APK was installed on the child |
| Fix | Rebuilt via `scripts/build_debug_apk.sh`; verified the config literal is present in `kernel_blob.bin`; preserved as `build/qa/app-debug-7ee501fa0e1c.apk`; reinstalled 17:22:52 |
| Status | RESOLVED (environmental). Guard: always install from `build/qa/…` after verifying the config literal |

This is not an app defect, but it invalidated one measurement window
(17:14–17:22) and is recorded so the timeline is not misread as an app crash.

---

## F1 — Hosted backend still enforces a 30-minute deadline that the UI denies

| Field | Value |
|---|---|
| Severity | P1 (session lifetime contradicts the UI; audio dies silently at the first media call after the deadline) |
| Evidence A | Live session `1bd26a84-137d-4e87-84ed-80190bfbea3e`: `accepted_at = 11:27:25.197Z`, `expires_at = 11:57:25.197Z` (exactly +30 min), `status = active`, parent `ankit@gmail.com` |
| Evidence B | Parent screen shows "Session duration: **Until you end the session**" and "Elapsed 30m" while the row carries a hard deadline |
| Evidence C | At 11:57:25Z the deadline passed. Media kept flowing (parent RTP 11,025 → 31,002 packets) **only because no new `media`/`ice` call was made**. The old hosted function expires on the next such call |
| Evidence D | Previous session `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9` (accepted 11:18:20 IST) was flipped to `status=expired`, `ended_reason=expired`, `ended_at=11:21:35Z` — the exact second the child opened its session screen (which calls `media`/`ice`) |
| Evidence E | `audit_logs` for that session contains only `session_requested`, `session_accepted`, `session_started`. **No end/expire audit row** because the old `markExpired()` does not write audit |
| Evidence F (runtime, 12:16:38Z) | During the 15-minute endurance leg the same session flipped to `status=expired`, `ended_reason=expired`, `ended_by=NULL`, `ended_at=12:16:38.393Z`. Parent logcat shows `onConnectionChangeCLOSED` at 12:16:38.537Z (144 ms later), voice engine terminated, AudioTrack removed. Media had run **19 minutes past** the stored deadline; the flip happened on the next client call into the old function. The leg therefore ended at 8m14s of the required 15m (`docs/evidence/stage8/f1-expiry-12-16Z.txt`, `e1-15min.txt`) |
| Evidence G | The child reacted correctly: `onConnectionChangeDISCONNECTED` at 12:16:44Z, mic capture stopped, `AudioAssistanceService` gone by 12:21:47Z, while `GuardianService` (non-mic) stayed foreground. No zombie microphone |
| Root cause | The hosted `remote-session` Edge Function is still the pre-fix build (`git show 8eee1b1:supabase/functions/remote-session/index.ts`, lines 241/279/330): it calls `markExpired()` when `new Date(session.expires_at).getTime() <= Date.now()`. With the new nullable-expiry schema, `new Date(null)` is epoch 0, so any `media`/`ice`/start call on a consented session expires it immediately. Separately, the hosted accept path still writes `expires_at = accepted_at + 30 min`, which the new lifetime policy removes |
| Fix (already in repo, not deployed) | `supabase/functions/remote-session/index.ts` at HEAD: `expirePending()` only touches `status='requested'`; accepted sessions are never expired by a clock; `expires_at` nullable via `20261028000200_parent_controlled_session_lifetime.sql` |
| Status | **FAIL (runtime) / FIX WRITTEN, DEPLOYMENT BLOCKED** — deploying Edge Functions and replaying `20261028000200` require explicit owner approval |

Impact: every real session silently dies ~30 minutes after consent at the
first server call, and the client tears the audio down at that instant. This
was reproduced end-to-end on 2026-10-29 at 12:16:38Z: the parent UI still said
"Until you end the session" while the row was already past its deadline, and
the next call expired it mid-session. It is the same class of failure the
parent saw as "Connection setup failed — This session has expired."

---

## F2 — Guardian poll loop stalled while the FGS record stayed alive (presence/polling freeze)

| Field | Value |
|---|---|
| Severity | P2 (presence flaps to Offline, commands stop; app recovers only on process restart) |
| Observed | 16:53 IST: Settings showed "Background protection: Running", "Service: Running with a visible notification", but "Last command check: **42 min ago**" (≈16:10) and error `Usage upload failed: entries[38].package_name is not a valid Android package name.` |
| Concurrent | Server `devices.last_seen_at` frozen at the same 16:10 mark; Home card showed "Session active" together with "This phone Offline / Last seen 40 min ago" |
| Mechanics | GuardianService runs one `ScheduledExecutorService` at a 10 s fixed delay; heartbeat (5 min), command poll (20 s) and presence all derive from that single tick. When the tick stops, all three go stale together, while the `ServiceRecord` still reports `isForeground=true` |
| Not the cause | Process not frozen at observation time (`am get-standby-bucket` = 5/ACTIVE, UI responsive, pid unchanged); HTTP client does set 15 s connect / 20 s read timeouts |
| Status | FAIL (observed); root cause not proven — most likely the single scheduler task terminated after an exception thrown outside `runCatching` (e.g. inside `recordError`/EncryptedSharedPreferences) or a ColorOS freeze during a blocking call. Needs a watchdog/self-heal fix; not changed in this pass |

Mitigation shipped in this pass (separate defect, F3) keeps the *label*
honest while this is open.

---

## F3 — "Offline" was structurally guaranteed (FIXED)

| Field | Value |
|---|---|
| Cause | `Device.isOnline` used a 3-minute window while `GuardianService.HEARTBEAT_MS` is 5 minutes, so a healthy device was "Offline" for ~2 minutes of every 5 |
| Fix | `lib/data/models/device.dart`: `onlineWindow = 6 min` (one heartbeat + grace); `lib/features/child/controllers/child_shell_controller.dart`: `_refreshDeviceRow()` runs on the 20 s linked poll so the row is re-read instead of aging locally |
| Tests | `test/data/device_model_test.dart` (4 cases: null, 2 min, 5:59, 6:01, future) plus child-shell test "the linked poll refreshes the device presence row" — all pass |
| Runtime proof | After installing the fixed build the child Home showed "This phone · **Online** · Last seen 1 min ago" at 16:55, and server `last_seen_at` advanced 11:24:32Z → 11:29:41Z → 11:44:07Z across the session |
| Status | **PASS** (code + unit + runtime) |

---

## F4 — No TURN relay configured (risk, not a failure in this run)

Parent banner: "Relay not configured — No TURN relay is configured." ICE
candidates gathered for the live session: `host` 37, `srflx` 10, `relay` 0.
Media still connected because both devices are on the same NAT path, so
`srflx` was enough. On carrier-grade NAT or strict firewall networks the
session would fail with no fallback.

Status: NOT A FAILURE HERE / KNOWN GAP.

---

## F5 — AudioAssistanceService does not survive a process kill (by design)

`AudioAssistanceService` returns `START_NOT_STICKY` and `stopWithTask=false`.
When ColorOS removed the task at 17:14:31 the service did **not** restart
(correct: no zombie mic), but the session stayed `active` and the parent dropped
to "Connection setup failed" until the child tapped "Reconnect microphone".

Status: EXPECTED. Recovery path (child tap → new offer/answer → live audio)
verified working (see runtime-mic-test-report A2).

---

## F6 — Parent warns "Live updates interrupted — End the session and retry" while media is live

| Field | Value |
|---|---|
| Severity | P3 (misleading copy; does not stop audio, but invites the user to end a healthy session) |
| Observed | 13:50:31Z, session `d1a04614-36e0-4b69-8e6e-88282f79d948`: parent screen showed the banner "Live updates interrupted — Live session signaling disconnected. End the session and retry." directly above "One-way audio live" and `DEBUG RTP: in 4185 pkts` |
| Cause | The realtime/signaling socket dropped independently of the peer-to-peer media path. The banner is rendered for signaling loss without checking whether media is currently live |
| Impact | User may end a working session; no audio was lost in this observation |
| Status | OBSERVED ONCE, NOT FIXED in this pass. Fix would gate the banner on media liveness (or soften the copy to "status updates paused; audio may continue") |

---

## E1 — Kotlin unit suite cannot run on this workstation (environment, not product)

`android/gradlew testDebugUnitTest` fails during project configuration:

```
A problem occurred configuring project ':flutter_secure_storage'.
> Could not create task ':flutter_secure_storage:testDebugUnitTest'.
  > this and base files have different roots:
    D:\parentcontrol_app\build\flutter_secure_storage and
    C:\Users\ASUS\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_secure_storage-11.2.0\android
```

The project is on `D:` and the pub cache is on `C:`; Gradle refuses mixed roots
for that plugin's unit-test task. No Kotlin test executed, so the Kotlin suite is
NOT reported as passing. Flutter (275) and Deno (47) suites and `flutter analyze`
all passed on the same tree.

Status: ENVIRONMENT BLOCKER. Workaround would be a single-drive pub cache or
project move; neither was applied in this run.
