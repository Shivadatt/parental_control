# Microphone lifecycle test plan — Pixel parent / realme child

Status: **armed, waiting on parent authentication**. Baseline recorded 2026-10-29
10:58Z. No implementation change is made until the first failing case is captured
with evidence (master prompt §9).

## 1. Roles and accounts

| Role | Device | Account | Notes |
|---|---|---|---|
| Parent | `emulator-5554` — Android 17 (SDK 37), Pixel AVD `sdk_gphone64_x86_64` | `ankit@gmail.com` | Family `demo` owner (verified read-only: owner + active parent member) |
| Child | `5HXWRGQ4IFU8WS4T` — realme RMX2161, Android 12 (SDK 31), ColorOS | `ankit1@gmail.com` | Active child member of `demo`; signed in; device registered and online |

Roles are never reversed. Identity is verified from the app UI and read-only
server rows only; no password, token or key is read, logged or pasted.

## 2. Build under test

* Both devices run the same debug APK built today:
  `build/app/outputs/flutter-apk/app-debug.apk`
  (sha256 `e23277a5e7d798fdebdc1de6d91904b4aa4d3301270ef7e11c6f25fa8e958ae9`).
* Installed with `adb install -r`, so the child's signed-in session survived.
* Emulator: freshly installed (no prior session).
* Release APK exists but is debug-signed; it is not used for these tests.

## 3. Baseline facts (recorded before any session)

| Item | Pixel (parent) | realme (child) |
|---|---|---|
| Device clock vs host (UTC) | aligned within 1 s | aligned within 1 s |
| App version | 1.0.0 (debug) | 1.0.0 (debug) |
| `RECORD_AUDIO` | declared, granted at install by adb (parent never captures) | granted by user (USER_SET) |
| `POST_NOTIFICATIONS` | declared | declared |
| `FOREGROUND_SERVICE` / `_MICROPHONE` | granted | granted |
| Battery optimization whitelist | not whitelisted | not whitelisted (default ColorOS policy) |
| GuardianService | n/a | running, `isForeground=true`, id 4101 |
| AudioAssistanceService | n/a | not running at baseline |
| Microphone capture at baseline | none | **none** (verified via `dumpsys audio`) |
| Previous session | — | child UI shows an old "Session active" card; DB row `e84ba35e…` open with NULL expiry |

The orphan session must be closed with the parent's supported **End session** flow
before the matrix starts. Its database row is not edited or deleted.

## 4. Evidence method

For every case capture, with UTC timestamps:

1. Screenshot of both devices.
2. Child capture state: `adb -s <rmx> shell dumpsys audio` (active recording client
   must name `com.parentcontrol.parent_control`) and
   `dumpsys activity services com.parentcontrol.parent_control` (service ids).
3. Parent playback/peer state: parent UI text plus `dumpsys audio` playback
   clients on the emulator.
4. WebRTC state from the app's own session UI (connecting / live / reconnecting)
   and sanitized Flutter logs filtered on `RemoteSession|WebRtc|AudioAssist`.
5. Session row state read-only through the Dashboard SQL Editor.

A UI badge alone is never accepted as proof of live audio; a case passes only
when the child shows an active capture client **and** the parent shows an active
playback client/peer while the UI reports live.

The child's microphone is the real physical microphone. Test audio is a spoken
count or a tone played next to the child phone; no private conversation is
recorded.

## 5. Test matrix

Each case is run at least twice, three times for the critical ones
(marked ★). Case IDs are used verbatim in the results table.

### A. Startup and authentication

| ID | Action | Pass criterion |
|---|---|---|
| A1 | Cold start both apps, parent first | Both restore the correct account/role; child linked; no stale audio |
| A2 | Cold start child first, then parent | Same as A1 |
| A3 | Force-stop both, reopen | Session state re-read from server; no revival of terminal sessions |
| A4 | Reboot the child phone, reopen | Child re-registers, linked, no capture until a new session is accepted |
| A5 | Open/close both apps repeatedly before a session (5×) | No duplicate services, no phantom sessions |
| A6★ | Three consecutive start/accept/live/end cycles | Each cycle clean; no leaked capture between cycles |

### B. Background and foreground

| ID | Action | Pass criterion |
|---|---|---|
| B1★ | Child: Home while live | Capture continues; parent still live |
| B2 | Child: switch to another app | Capture continues |
| B3 | Child: notification shade / quick settings and back | Capture continues |
| B4 | Child: Recents switch back and forth | Capture continues, single peer |
| B5★ | Child background 1 / 5 / 15 min | Capture continues; session stays accepted |
| B6 | Parent background 1 / 5 / 15 min | Child stays live; parent resumes without stale state |
| B7 | Both backgrounded simultaneously | Session remains open; returning shows accurate state |

### C. Close / task removal

| ID | Action | Pass criterion |
|---|---|---|
| C1 | Leave session screen via back navigation | Session not ended; state accurate |
| C2 | Reopen session screen | No duplicate capture/peer |
| C3★ | Swipe child app from Recents while live | Capture continues via foreground service; notification remains |
| C4 | Swipe parent app from Recents while live | Session continues; reopen re-attaches |
| C5 | Stop the child process with `am kill`/`am force-stop` vs swipe (documented separately) | Report actual OS behavior; no false "live" state |
| C6 | Settings → Force stop on child | Capture and service stop; notification gone; session left open for parent End |
| C7 | Reopen after each of C3–C6 | Correct recovery path; consent required again if a new session is needed |

### D. Screen lock

| ID | Action | Pass criterion |
|---|---|---|
| D1★ | Lock child screen while live | Capture continues; FGS notification present on lock screen |
| D2 | Unlock child | UI state accurate |
| D3 | Lock parent while live | Playback continues or resumes; UI accurate on return |
| D4 | Lock both 1 / 5 / 15 min | Session and capture survive per OS policy; duration recorded |
| D5 | Screen off/on 10× on child | No capture drop |

### E. Navigation and activity lifecycle

| ID | Action | Pass criterion |
|---|---|---|
| E1 | Navigate every child tab during a session | No capture stop, no duplicate peer |
| E2 | Open/close device list on parent | Session unaffected |
| E3 | Rotate both devices during a session | No duplicate services/peers |
| E4 | Recreate the Flutter route during a session | Same session re-attached |

### F. Microphone permission

| ID | Action | Pass criterion |
|---|---|---|
| F1 | First-run permission prompt on child | Capture starts only after grant |
| F2 | Deny once, then retry | Clear error; no capture |
| F3 | Deny permanently | Clear recoverable guidance; no capture |
| F4 | Revoke in Settings before a session | No capture; clear error |
| F5 | Revoke during a live session (if OS allows) | Capture stops or session degrades visibly; never silent |
| F6 | Restore permission, restart app, retry | Clean capture resumes |

### G. Audio routing and interruptions

| ID | Action | Pass criterion |
|---|---|---|
| G1 | Speaker vs wired headset (if available) | Route change handled; capture unaffected |
| G2 | Media volume muted/unmuted on parent | Playback state honest |
| G3 | Audio focus interruption (alarm/tone) | Capture continues; playback resumes |
| G4 | Incoming call on child | Documented behavior; no claim of survival |

Bluetooth is **NOT TESTED** unless a headset is provided.

### H. Network

| ID | Action | Pass criterion |
|---|---|---|
| H1 | Same Wi-Fi vs different networks | Live audio on the supported path; no TURN claim |
| H2★ | Child Wi-Fi off 60 s → on | Banner appears, then clears without manual refresh; audio resumes |
| H3 | Parent network off/on | Parent recovers; child unaffected |
| H4 | Airplane mode on/off on child | Recovery per backoff; no stale "live" |
| H5 | Longer outage (5 min) | Session policy honored; recovery documented |

### I. Battery and ColorOS restrictions

| ID | Action | Pass criterion |
|---|---|---|
| I1 | Default battery policy, screen-off standby 15 min | Actual behavior recorded |
| I2 | Battery saver on | Actual behavior recorded |
| I3 | Whitelisting only if the owner authorizes the setting change | Documented before/after |

No security control is disabled without the owner's explicit approval.

### J. Session end and cleanup

| ID | Action | Pass criterion |
|---|---|---|
| J1★ | Parent End while child foreground | Capture stops, notification removed, terminal state on both |
| J2 | Parent End while child backgrounded | Same as J1 |
| J3 | Parent End while child offline | "End requested" vs "confirmed" distinguished; no false claim |
| J4 | Reopen both after End | Terminal state persists; no revival |
| J5 | New session after End | Starts cleanly; no duplicate open session |

### K. Duration and repetition

| ID | Action | Pass criterion |
|---|---|---|
| K1 | 5-minute sanity | Continuous live audio; duration recorded |
| K2 | 15-minute endurance | Report actual duration, not a rounded pass |
| K3 | 30-minute endurance (if approved) | Same |
| K4 | Combined: child background + child locked + parent background | Capture continues |
| K5 | Combined: network loss + lock + reconnect | Recovery per H2 |

## 6. Stop conditions

* Any capture that continues after a confirmed parent End → stop, capture logs,
  investigate before further cases.
* Any UI that reports live while no capture/peer exists → stop, treat as false
  state, capture evidence.
* Parent sign-in unavailable → all parent-dependent cases are BLOCKED, not
  simulated.

## 7. Blocker

Parent authentication on the Pixel emulator is the only gate. The parent
password is not stored in the repository and is not bypassed; the owner enters it
on the emulator. Until then only child-side baseline checks can run.

## 8. Workstreams (disjoint ownership)

| # | Workstream | Scope |
|---|---|---|
| 1 | Coordinator | Matrix, device control, evidence index |
| 2 | Codebase audit | Mic/session code trace |
| 3 | Parent auth | Sign-in, token refresh, state restore |
| 4 | Child auth | Session persistence, unexpected sign-out |
| 5 | Pairing | Family/device link checks |
| 6 | Supabase/RLS | Session rows, signaling policies, duplicates |
| 7 | Edge Functions | Deployed vs local; no deployment |
| 8 | WebRTC | Offer/answer, ICE, tracks, recovery |
| 9 | Android mic | Permission, FGS, native service |
| 10 | Android lifecycle | Foreground/background/Recents/lock/process death |
| 11 | Parent UI | Request/connecting/live/interrupted/ended |
| 12 | Child UI | Incoming/accept/mic/active |
| 13 | Automated tests | Flutter/Kotlin/Deno regressions if a defect is found |
| 14 | Device QA | Physical matrix execution |
| 15 | Reviewer | Verify every PASS and security claim |
