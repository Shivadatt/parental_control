# Runtime microphone test report — Pixel 9a (parent) + realme RMX2161 (child)

Run date: 2026-10-29 (IST = UTC+5:30). App `com.parentcontrol.parent_control`
1.0.0 (debug, JIT). Parent account `ankit@gmail.com`, child account
`ankit1@gmail.com`, family `demo`. Roles were fixed and never swapped.

- Parent: `emulator-5554`, Pixel 9a AVD, Android 17 / API 37 (x86_64)
- Child: `5HXWRGQ4IFU8WS4T`, **physical** realme RMX2161, Android 12 / API 31

Build details, installed hashes and permission state: `docs/runtime-device-matrix.md`.
Defect analysis: `docs/runtime-failure-analysis.md`. Raw evidence and screenshots:
`docs/evidence/stage8/`.

## 1. What is proven about "audio is live"

A green badge alone was never accepted. A test passes only when, in the same
window:

1. the child has an active `RECORD_AUDIO` client (`dumpsys audio` / `appops`,
   state `(running)`) and the `AudioAssistanceService` FGS (id 4303);
2. the parent's WebRTC peer reports `onConnectionChangeCONNECTED` and its DEBUG
   RTP counter `in` is advancing;
3. the parent has a started playback track (`dumpsys audio`, usage
   `VOICE_COMMUNICATION`).

Representative proof (session `1bd26a84`, 2026-10-29 11:55:59Z):

| Signal | Observed |
|---|---|
| Signaling | offer 11:54:05Z, answer 11:54:06Z, 31 ICE rows, types host 37 / srflx 10 / relay 0 |
| Parent track | AudioTrack piid 271, state `started`, 8000 Hz, `VOICE_COMMUNICATION`, started 11:54:06.789Z |
| Parent rendering | audio_flinger server frame position advanced 600575 → 650805 (6.28 s) across a 6 s window |
| Parent RTP | `in 5463 pkts / 399641 B`, `out 0` |
| Child capture | mic FGS 4303, appops `allow (running)` |

**Not proven: human audibility.** No human listener was asked to confirm that
sound leaves the emulator's speaker, and `dumpsys` cannot show that. All PASS
results below mean "capture + RTP + started playback track", not "a person heard
it". No private audio was recorded.

## 2. Session inventory

| # | Session id | Requested | Accepted | Media live from | Ended | Reason |
|---|---|---|---|---|---|---|
| S1 | `1bd26a84-137d-4e87-84ed-80190bfbea3e` | 11:27:08Z | 11:27:25Z | 11:54:06Z (rejoined) | 12:16:38Z | expired by hosted function (F1) |
| S2 | `af0b39b9-d453-4d4c-8b5b-5a6b4df77f4a` | 12:46:39Z | 12:48:46Z | 12:58:25Z | 13:36:40Z | parent End (child offline) |
| S3 | `d1a04614-36e0-4b69-8e6e-88282f79d948` | ~13:40Z | 13:46:31Z | 13:50:28Z | 13:53:02Z | parent End (child live) |
| S4 | `1a728cff-4d9f-40f5-932d-0a77dc89de9e` | 14:02:31Z | — | — | 14:12:57Z | parent canceled pending request |

Older rows: `e84ba35e…` (orphan, expired 11:21:35Z; not deleted, not edited),
`7f50b52c…` and `1c6ad5ed…` (short owner-initiated cycles 12:16–12:22Z).

## 3. Results matrix

Status meanings: PASS = reproduced with evidence; FAIL = reproduced defect;
BLOCKED = could not be performed; NOT TESTED = not reached. Durations are actual
measured spans, not nominal.

The letters below group the work (A background, C task removal, …); they are not
identical to `docs/mic-lifecycle-test-plan.md`, whose sections rotate at G. Plan
ID mapping and the plan IDs that were never attempted:

| Report | Plan ID | Report | Plan ID |
|---|---|---|---|
| A1–A4 | A1/A2/A6 (three live cycles) | F1–F3 | F5, F6, F2/F3 |
| B1–B4 | B1, B2, B5, K3 (30-min) | G1–G4 | H2, H4, H5, H1 |
| C1–C7 | C1–C7 | H rows | I1 (short windows only), I2 (off) |
| D1/D2 | D1/D2 | I1–I5 | J1, J3, J4, J5 (+ cancel) |
| E1–E4 | E1–E4 | J1–J4 | K1, K2, K3, K4 |

Never reached (recorded as NOT TESTED/BLOCKED, not as pass): plan A3–A5 (cold
start/reboot/open-close ×5), B3/B6/B7, C4, D3–D5, E3/E4, F1/F4, G1–G4 (audio
routing, volume, focus, incoming call), H3, I3, J2, K5. Bluetooth was excluded
by the plan (no headset).

### A. Normal session start / accept / live

| ID | Device / role | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|---|
| A1 | both | Parent requests audio; child accepts; both join | Media live, one-way child→parent | Live, RTP advancing, track started | ~2 min | `media-verified-11-55Z.txt`, `emu-09`, `rmx-13/14` | PASS |
| A2 | both | Reconnect microphone on same session | New offer/answer, media restored | offer 11:54:05Z, answer 11:54:06Z, live | ~2 min | `media-verified-11-55Z.txt` | PASS |
| A3 | both | Second full cycle (S2) | Clean start, live | Live by 12:58:33Z (first seen 12:58:25Z), RTP 422 pkts | ~10 min incl. consent dialogs | `e5/e8-*.png` | PASS |
| A4 | both | Third full cycle (S3) | Clean start, live | Live at 13:50:28Z, RTP 4185 pkts | ~8 min | `j1-*-before-end.png` | PASS |

Three separate sessions reached live media, satisfying the "normal session ×3"
requirement. Each needed a second confirmation dialog on the child ("Join now")
after accepting the request; this is by design (consent before capture).

### B. Background

| ID | Device / role | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|---|
| B1 | child | Home while live | Capture continues | RTP +4,045 pkts, ≈52 pkt/s, capture `(running)` | **60 s** (17:28:04–17:29:04) | earlier stage8 log | PASS |
| B2 | child | Background 5 min | Capture continues | RTP +15,932 pkts, ≈50.6 pkt/s, no freeze | **300 s** (17:29:19–17:34:19) | earlier stage8 log | PASS |
| B3 | child | Background 15 min | Capture continues 15 min | Media ran **8m14s**, then hosted function expired the session; child stopped capture correctly | **494 s** (12:08:24–12:16:38Z) | `e1-15min.txt`, `f1-expiry-12-16Z.txt`, `e1-failure-*.png` | FAIL (server F1) |
| B4 | child | Background 30 min | Capture continues 30 min | Not run on a fresh session; the same 30-minute deadline governs it (F1), and the physical child was taken over at 14:10Z | — | F1 evidence | NOT TESTED / BLOCKED |
| B5 | parent | Parent background | Child stays live | Not reached | — | — | NOT TESTED |
| B6 | both | Both backgrounded | Session stays open | Not reached | — | — | NOT TESTED |

ColorOS logged `uid=11312 … cannot transition from R to M, importance=traffic`
repeatedly during B2/B3, i.e. the mic FGS successfully blocked demotion. No
`freeze uid` event occurred while 4303 was foreground.

### C. Close / task removal / force stop

| ID | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|
| C1 | Child leaves session screen via Back | Session stays open | Not repeated this run; stage-5 evidence shows "Leaving does not end this session" | — | `rmx-14-recents.png` | NOT TESTED (this run) |
| C2 | Reopen session screen after process death | Same session re-attached | Home showed "Open session"; screen said "Session is still live … Reconnect microphone" | 13:00:28–13:06:23Z | `f6-child-session.png` | PASS |
| C3 | Swipe child app from Recents | Capture continues via FGS | Task count 0, pid 11906 unchanged, FGS 4101+4303 foreground, capture `(running)` | observed 17:37:10 | earlier stage8 log, `rmx-14-recents.png` | PASS |
| C4 | Swipe parent app | Session continues | Not reached | — | — | NOT TESTED |
| C5 | Force stop child | Capture and services stop; no zombie | pid gone, both services gone, capture `duration=+4 ms`, notification gone | 13:30:05Z + ≤4 s | `c6-child-force-stopped.png` | PASS (OS force-stop path; see limitation) |
| C6 | Relaunch after force stop | Terminal state persists, no revival | No session card, no mic service, last capture 9m earlier | 13:39:47–13:39:55Z | `j4-child-relaunch-ended.png` | PASS |
| C7 | Another app foreground (no kill) | Capture continues | Litmatch foreground for minutes; capture continued until server expiry | 12:16–12:16:38Z | child logcat | PASS (until F1) |

Force-stop behavior is reported separately from ordinary background/Recents:
force stop kills capture and both services; Recents swipe does not.

### D. Screen lock

| ID | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|
| D1 | Lock child 2 min while live | Capture continues, FGS holds | `mWakefulness=Asleep`, RTP +7,084 pkts (≈50.2 pkt/s) | **120 s** (17:34:40–17:36:40) | earlier stage8 log | PASS |
| D2 | Unlock child | UI accurate, no duplicate peer | UI live, single peer | — | `rmx-14-recents.png` | PASS |
| D3 | Lock parent | Playback resumes | Not reached | — | — | NOT TESTED |
| D4 | Lock both 5/15 min | Survives | Not reached | — | — | NOT TESTED |

### E. Navigation / activity lifecycle

| ID | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|
| E1 | Child switches tabs while live | Capture continues | Child device was taken over by another app; tabs not exercised this run | — | — | BLOCKED |
| E2 | Parent leaves/reopens session screen while live | Media survives | Not performed (parent stayed on screen); incidentally one banner "Live updates interrupted" appeared while media stayed live (RTP 4185) | ~3 min | `j1-parent-live-before-end.png` | NOT TESTED (F6 observed) |
| E3 | Rotation | No duplicate peer | Device rotation was locked earlier to keep taps deterministic | — | documented setting change | NOT TESTED |
| E4 | Flutter route recreation | Re-attach | Not reached | — | — | NOT TESTED |

The "Live updates interrupted" banner while `Media connected / Audio live` is a
real inconsistency in the opposite direction: the UI warns that signaling is
down even though RTP is flowing. Media is peer-to-peer, so the banner is
plausible, but the wording ("End the session and retry") is misleading during a
healthy call. Logged as F6 in the failure analysis.

### F. Microphone permission

| ID | Action | Expected | Actual | Evidence | Status |
|---|---|---|---|---|---|
| F1 | Revoke `RECORD_AUDIO` during live session (adb `pm revoke`, documented device change) | Capture stops visibly, no silent capture | At +25 s: permission `granted=false`, app-op `ignore`, capture `duration=+1 ms`, mic FGS gone, parent "Audio not live" (RTP frozen 2,176) | `f5-child-permission-revoked.png` | PASS |
| F2 | Restore permission, relaunch, reconnect | Clean capture resumes | `pm grant`; Android had killed the process on revoke; relaunch showed "Session is still live"; Reconnect + "Join now" → mic FGS back, capture `(running)`, parent `Audio live`, RTP 380 | `f5-child-permission-restored.png`, `f6-*.png` | PASS |
| F3 | Deny before a session | Clear error, no capture | Not reached (permission already granted) | — | NOT TESTED |

Note: revoking a runtime permission makes Android kill the app process. The
observed teardown is therefore OS behavior as well as app behavior; either way
no capture continued.

### G. Network

| ID | Action | Expected | Actual | Duration | Evidence | Status |
|---|---|---|---|---|---|---|
| G1 | Child Wi-Fi off 60 s then on | Banner, then recovery | `Active default network: none`; parent showed "Media connection could not be recovered. The session is still open." Wi-Fi on 13:22:30Z; app offered "Start the live session?"; after Join now, media live again: parent RTP 3,930, child out 4,052 | off 13:13:29–13:22:27Z (539 s) | `h2-*.png` | PASS (manual confirm tap) |
| G2 | Airplane mode on/off | Recovery | Not reached (child device taken over) | — | — | BLOCKED |
| G3 | 5-minute outage | Policy honored | Not reached | — | — | NOT TESTED |
| G4 | Network switch (Wi-Fi ↔ cellular) | Live on supported path | Not reached | — | — | NOT TESTED |

Network path: ICE `host 37 / srflx 10 / relay 0`; both devices were on the same
LAN. No TURN relay is configured, so recovery across carrier NAT is unproven
(known gap F4).

### H. realme / ColorOS restrictions

| Item | Observation | Status |
|---|---|---|
| Default battery policy, app not whitelisted | Mic FGS held through Home, 5-min background, 2-min lock, Recents swipe | PASS (for these windows) |
| Standby bucket | 5 (ACTIVE) while running | PASS (observation) |
| Battery saver | off during the run; not tested enabled | NOT TESTED |
| 15/30-min screen-off standby | not run | NOT TESTED |
| FGS demotion | `cannot transition from R to M, importance=traffic`, no freeze | PASS |

### I. Session end and cleanup

| ID | Action | Expected | Actual | Evidence | Status |
|---|---|---|---|---|---|
| I1 | Parent End while child live and foreground | Capture stops, notification gone, both terminal | End at 13:53:00Z; capture ended ~13:53:03Z (`duration=+2m35s`), mic FGS gone; DB `ended_at=13:53:02.004Z`, `ended_by` parent; child UI "Session ended" | `j1-*.png`; DB query | PASS |
| I2 | Parent End while child force-stopped/offline | Server end succeeds, parent confirms | End 13:36:37Z, UI "Session ended" 13:36:44Z; DB `ended_at=13:36:40.646Z`, `ended_by` parent, audit `session_ended` 13:36:41Z | `j3-parent-ended-offline.png`; DB query | PASS |
| I3 | Reopen child after End | Terminal state persists | 13:39:47Z relaunch: no session card, no capture | `j4-*.png` | PASS |
| I4 | New session after End | Clean start | S3 created and reached live after S2 ended | A4 row | PASS |
| I5 | Cancel a pending request | Child no longer sees it, row terminal | S4 ended by parent at 14:12:57Z, never accepted | parent UI; DB query | PASS |

### J. Endurance

| ID | Target | Actual continuous media | Result |
|---|---|---|---|
| J1 | 5 min | 300 s (B2), ≈50.6 pkt/s | PASS |
| J2 | 15 min | 494 s, then hosted expiry (F1) | FAIL |
| J3 | 30 min | not run on a fresh session; governed by the same 30-min deadline | NOT TESTED / BLOCKED |
| J4 | Combined background + lock + parent background | not run | NOT TESTED |

## 4. Defects found during this run

1. **F1 (P1, open, deployment blocked):** the hosted `remote-session` function
   still enforces a 30-minute deadline. Session `1bd26a84` was flipped to
   `expired` at 12:16:38.393Z — 19 minutes after its stored deadline — and the
   parent client closed the peer 144 ms later. The UI had promised "Until you end
   the session". This caused the only FAIL in this matrix. Fix exists at HEAD;
   deployment was not authorised.
2. **F6 (P2, observed once):** parent showed "Live updates interrupted — End the
   session and retry" while media was live (RTP 4185). Signaling channel drop
   without media impact; wording can cause a user to end a healthy session.
3. **F3 (fixed):** "Offline" was structurally guaranteed by a 3-min presence
   window under a 5-min heartbeat. Fixed to 6 min + row refresh; runtime showed
   Online and advancing `last_seen_at`.
4. **F2 (P2, open):** guardian scheduler stall observed earlier (16:10–16:54),
   root cause unproven.
5. **F4 (known gap):** no TURN relay; recovery only works on paths where
   host/srflx candidates succeed.

## 5. Limitations and honest gaps

- Human audibility was **not** verified. Packet/track evidence only.
- The physical child phone was being used by a person from ~13:54Z and was taken
  over by another app at ~14:10Z. Further UI-driven child tests (airplane mode,
  tab navigation, 30-min run) were stopped rather than fighting for the screen.
  The pending request was canceled through the parent UI; no row was edited.
- The parent's 15-minute leg was interrupted by F1, not by the child; the
  child-side background survival itself held for the full 8m14s measured.
- The two devices run different APK bytes (same source); both were verified to
  contain the compiled Supabase URL and the presence fix.
- Rotation was locked on both devices earlier to make automated taps
  deterministic; that is a documented device-setting change, still in effect.
- `pm revoke` / `pm grant` and `svc wifi disable` / `enable` were used as the
  documented equivalents of the corresponding Settings actions; all were
  restored afterwards.
- The force-stop leg removed the process through the OS force-stop path; the
  captured evidence shows the post-stop state but cannot distinguish a Settings
  "Force stop" tap from `am force-stop`, so the Settings-UI-specific step is not
  separately evidenced.

## 6. Automated checks

| Check | Command | Result |
|---|---|---|
| Flutter tests | `.fvm/flutter_sdk/bin/flutter test` | **275 passed, 0 failed** (1m28s), exit 0 |
| Flutter analyze | `.fvm/flutter_sdk/bin/flutter analyze` | **No issues found** (126.8 s), exit 0 |
| Deno tests | `deno test supabase/functions/_shared supabase/functions/remote-session/guard_test.ts` | **47 passed, 0 failed** (747 ms), exit 0 |
| Kotlin unit tests | `android/gradlew testDebugUnitTest` | **BLOCKED (environment)**: Gradle fails at configuration time with `this and base files have different roots: D:\parentcontrol_app\build\flutter_secure_storage and C:\Users\ASUS\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_secure_storage-11.2.0\android`. This is a Windows cross-drive limitation between the project (`D:`) and the pub cache (`C:`), not a test failure. No Kotlin test executed, so the Kotlin suite is NOT counted as passing. |

The Kotlin suite (`AudioAssistanceRecreationTest` and others) therefore remains
unverified in this run; see `docs/runtime-failure-analysis.md` for the
environmental note.
