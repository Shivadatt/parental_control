# Two-device WebRTC test plan (remote assistance)

Status: **NOT EXECUTED — BLOCKED.** As of 2026-10-27 only one physical Android
device is attached (`RMX2161`, serial `5HXWRGQ4IFU8WS4T`) and no emulator is
available. TURN is not configured in the hosted project and `CRON_SECRET` is
unset. This document is the executable procedure for a future run; **nothing in
it is a passing result**, and no claim of end-to-end remote audio/video is made.

Companion documents: [remote-assistance.md](remote-assistance.md),
[verification-report.md](verification-report.md), [bug-report.md](bug-report.md).

## 0. Why this cannot run today

| Blocker | Evidence | Effect on this plan |
|---|---|---|
| One physical device, no emulator | `adb devices -l` shows only RMX2161 | No second peer; all media steps are BLOCKED |
| No TURN relay | `remote-session` `ice` returns `turn_configured:false` and STUN only (phase 2 `remote.ice_config_uses_stun`) | T14 (TURN-only) is BLOCKED, not FAIL |
| No scheduled expiry job | `CRON_SECRET` unset, `cron` endpoint disabled (`docs/backend.md`) | Expiry is enforced lazily by server actions and RLS; T10/T11 still executable |
| Android 12 test phone, no Device Owner | `dpm list-owners` reports none | Irrelevant to media, but do not confuse with other blockers |
| No Firebase/FCM | No `google-services.json` | Decline/accept has no push notification; visibility depends on the open screen or a refresh |

An emulator is **not** an acceptable substitute for the final pass: camera and
microphone capture, audio routing, permission dialogs and Doze/background rules
are the behaviors under test. It may be used only for a dry run of the UI
script, clearly labelled as such.

## 1. Prerequisites

### 1.1 Devices and accounts

| Item | Requirement | How to confirm |
|---|---|---|
| Parent device | Physical Android phone, Android 10+ | `adb -s <serial> shell getprop ro.build.version.release` |
| Child device | A **second** physical Android phone, signed into a different account | `adb devices -l` shows two serials |
| Install type | Two distinct installs of the same APK/version; do not share one device for both roles | App Settings → version, and APK SHA-256 |
| Hosted project | Same project for both installs: `hhqgreaoqulmfwfwarhc` (or the current QA project) | `Env` / app configuration screen |
| Parent account | QA account with server role `parent`, email confirmed | Sign-in succeeds; parent shell opens |
| Child account | **Different** QA account with server role `child`, email confirmed | Child shell opens; role chosen |
| Family | A dedicated QA family containing both accounts; the child phone is the **active** device the parent will target | Parent device list shows the child device as active |
| Consent | The child account owner is present and taps Accept | No scripted/automated acceptance |

Do not reuse a real family. If the QA child was previously unlinked and its
device revoked, re-link before this plan: child creates the code, parent redeems
it, child approves, then the child registers (see
[device-enrollment.md](device-enrollment.md)). A reinstall alone cannot recover
a revoked credential (BUG-024).

### 1.2 Build and install

Use the pinned toolchain and record the artifact before testing:

```bash
fvm flutter --version
fvm flutter build apk --release --dart-define-from-file=.tools/live_config.env
sha256sum build/app/outputs/flutter-apk/app-release.apk
adb -s <parent-serial> install -r build/app/outputs/flutter-apk/app-release.apk
adb -s <child-serial>  install -r build/app/outputs/flutter-apk/app-release.apk
```

Both devices must report the same hash. Debug builds are acceptable for logcat
detail; record which build was used. Do not put TURN credentials, service-role
keys or account passwords in `--dart-define`, the repo or the test log.

### 1.3 Backend preflight

1. Confirm the `remote-session` function is deployed and `ice` works for the QA
   session (open the session screen after acceptance; the **Relay not
   configured** banner must appear when TURN is absent).
2. Confirm private Realtime is reachable from both devices (the session screen
   must not show **Live updates interrupted**).
3. Confirm the QA device row is `active`, and the child membership is `active`.
4. If TURN is part of this run, complete the TURN setup in
   [remote-assistance.md](remote-assistance.md) first and record
   `turn_configured:true` before T14.

### 1.4 Tooling and access

- `adb` (two devices), `logcat`, `screencap`.
- Supabase dashboard access for read-only SQL and, only where this plan says so,
  QA-only test-data updates (never schema changes).
- A coturn host with `turnutils_uclient` / `turnutils_peer` for T14.
- Optional: the read-only QA harness patterns in `.tools/live/` for concurrent
  `respond` races (T5). Do not print tokens or secrets.

## 2. Evidence setup (before the first call)

1. Record date/time (UTC and local), operator, app version/hash, project ref,
   device models, serials (last 4 characters only in shared notes), Android
   versions, and network names.
2. Clear logcat on both devices:
   `adb -s <serial> logcat -c`
3. Capture a baseline screenshot of each device and the camera/mic privacy
   indicators (both off).
4. Create a directory `.tools/evidence/two-device/<run-id>/` (gitignored). Every
   screenshot, log and SQL export goes there. **Never capture** the TURN secret,
   service-role key, JWTs, passwords or `.tools/*.env`.
5. For SQL checks use the dashboard SQL editor and paste only session UUIDs;
   redact account emails before sharing.

## 3. Test script

Session IDs are obtained from the parent session screen URL/route arguments or
from a read-only query in the dashboard:

```sql
select id, status, kind, requested_at, accepted_at, started_at, expires_at,
       ended_at, ended_reason, consent_recorded, parent_user_id, child_user_id
from public.remote_sessions
order by requested_at desc
limit 5;
```

### T1 — Request is visible and decline works

**Actor:** parent, then child.

1. Parent: open the child device → **Remote assistance** → **Request video** →
   confirm.
2. Parent lands on **Assistance session**. Record the session UUID.
3. Child: open **Requests** (tab or **Review and respond**). Pull to refresh if
   the request is not shown yet.
4. Child: tap **Decline**. Do not accept first.

Expected visible states:

| Screen | Expected |
|---|---|
| Parent session | Status **Waiting for consent**; **Join** absent; **Cancel request** present |
| Child Requests | **Assistance requests** card naming the guardian, kind and remaining time; **Decline** and **Accept** |
| Child after decline | Returns to the list; **Assistance request declined.** banner; request disappears |
| Parent after decline (Realtime) | Status **Declined**; **Request declined — The child declined. No media was opened.**; no Join; Close only |

Server/evidence checks:

```sql
select status, consent_recorded, ended_at, ended_reason
from public.remote_sessions where id = '<SESSION_ID>';
-- expected: declined, false, non-null, 'declined'
```

- Both camera/mic privacy indicators stayed off for the whole step.
- No `offer`, `answer` or `ice` rows exist:
  `select kind, count(*) from public.webrtc_signals where session_id='<ID>' group by kind;`
  → zero rows.
- Logcat contains no `getUserMedia` and no permission prompt.

**PASS** only if the child request was visible, the decline was an explicit
child action, the server recorded `declined`, the parent UI reached the terminal
declined state, and no media was opened.

### T2 — Accept records consent but opens no media

1. Parent: send a new video request.
2. Child: **Requests** → **Accept** → confirm **Accept request**.
3. Child lands on **Assistance** (child session screen). Do **not** tap Join yet.
4. Wait 30 seconds.

Expected:

| Screen | Expected |
|---|---|
| Child | Status **Accepted**; consent **Recorded**; **Ready when you are** card; Join button enabled; no permission dialog |
| Parent (Realtime) | Child consent **Recorded**; **Join with camera and microphone** enabled; no media stage yet |
| Both | Camera/mic indicators off; no green dot |

Server:

```sql
select status, consent_recorded, accepted_at, expires_at, session_nonce, started_at
from public.remote_sessions where id='<SESSION_ID>';
-- expected: accepted, true, non-null 30-minute expiry, nonce set, started_at null
```

`webrtc_signals` must still be empty (no offer yet). The server `ice` prefetch
may have run; that is configuration, not media, and is allowed only after
consent.

**PASS** if consent is recorded, no permission dialog appeared, no camera/mic
started, and no signals were inserted.

### T3 — Join with the child joining first (expected good order)

1. Child: tap **Join with camera and microphone** → **Join now**.
2. Grant the Android camera and microphone permissions when asked.
3. Child shows **Connecting…** and then a media card.
4. Parent: tap **Join with camera and microphone** → **Join now**; grant
   permissions.
5. Verify two-way audio (speak both ways) and two-way video (wave/cover each
   camera).

Expected:

| Check | Expected |
|---|---|
| Child media card | Local preview not shown by design; status **Connected** once negotiated |
| Parent media stage | Child video visible; **Connected** |
| Session status | **Accepted** (see known gap G2: the app never calls `start`, so **Live** is not expected in the current build) |
| Camera/mic indicators | On only after each Join tap |
| Banners | No **Media connection**, **Connection setup failed** or **Live updates interrupted** banner |

Evidence:

```sql
select kind, count(*), min(created_at), max(created_at)
from public.webrtc_signals where session_id='<ID>' group by kind;
-- expected: 1 offer, 1 answer, several ice rows

select payload->>'candidate' as candidate
from public.webrtc_signals
where session_id='<ID>' and kind='ice'
order by sequence;
-- record typ host / srflx / relay counts per side (join on from_user_id)
```

**PASS** only with audible two-way audio and visible two-way video, both sides
**Connected**, and no repeated offer/answer. Do not infer success from the
existence of a peer connection alone.

### T4 — Join with the parent joining first (known ICE-order risk)

This is the reverse of T3 and is deliberately included because of code finding
G1.

1. New request → child accepts → child stays on the **Assistance** screen but
   does **not** join.
2. Parent opens the session and taps **Join** first; wait 10 seconds.
3. Child then taps **Join**.

Expected from the documentation: media connects. Expected from the current code:
the parent's trickled ICE candidates that arrive before the child creates its
peer are discarded, so the child may have the offer but no parent candidates;
the call may stay **Connecting…** or fail, especially with TURN.

Record:

- Which side shows **Connected**.
- Candidate counts per side. The parent's ICE rows are stored server-side even
  if the child never applied them, so compare the stored parent candidates with
  whether the call actually connected.
- Any **Media connection** warning.

**PASS** if two-way media connects within 30 seconds in this order too. A failure
here is a confirmed product defect, not a test error; attach the signal SQL and
logcat excerpt.

### T5 — Duplicate taps and accept/decline race

1. On a new accepted session, tap **Join** twice quickly; also double-tap the
   session card from the list before joining.
2. Verify only one offer and one answer per side, one media stage, no repeated
   SDP in `webrtc_signals`, and no **Session action failed** banner.
3. Race (optional, server-level): with the QA child token, send two concurrent
   `remote-session` `respond` calls — one `accept:true`, one `accept:false`.
   Use the existing harness patterns in `.tools/live/verify_devices.mjs`; do not
   add a third device.

Expected:

- Exactly one terminal outcome wins; the loser gets `409 session_not_open` (or
  an idempotent 200 for the same answer) and no media is opened by the loser.
- The audit log contains at most one `session_accepted` or `session_declined`
  for that transition.
- In-app, a duplicate Join cannot create a second peer because `isJoining` /
  `hasActivePeer` guard it (`remote_session_controller.dart:412`); a duplicate
  **route** (double-tap on the list) is not guarded and may create two peer
  connections — record if observed.

### T6 — Mute/unmute and camera on/off

There is no mute button and no camera on/off control on either session screen
(see G5). Do not mark this PASS.

1. During a connected call, look for any mute, speaker, switch-camera or
   camera-off control.
2. Record a screenshot of the media stage/card showing the available controls.
3. Confirm the only mute/switch-camera controls in the app are in the local
   **Camera and microphone test** sheet (child Settings), not in a live session.

**Expected result: NOT IMPLEMENTED → FAIL/BLOCKED for the mute criterion.**
A future implementation must toggle `MediaStreamTrack.enabled` without
restarting capture and must stop tracks on end.

### T7 — End by the child

1. During a connected call, child taps **End session** → confirm.
2. Observe both devices for 10 seconds.

Expected:

| Check | Expected |
|---|---|
| Child | Terminal **Session ended**; UI controls replaced by Close; camera/mic indicators off |
| Parent | Realtime terminal **Session ended**; media stage removed; its own camera/mic stop |
| Server | `status='ended'`, `ended_at` set, `ended_reason='ended_by_child'` |
| Signals | No new rows after `ended_at` |

The app ends the server session explicitly (`endSession`), which also tears down
the peer and tracks. **PASS** if both sides stop within 5 seconds and the server
row is terminal.

### T8 — End by the parent

Repeat T7 with the parent ending first. Expected reason `ended_by_parent`.
**PASS** if the child UI reaches terminal and the child's tracks stop.

### T9 — Leave the screen (back)

1. During a connected call, press Back on the child session screen (do not use
   End).
2. Observe the parent and the server.

Expected local behavior: the child's peer/tracks stop when the route is popped
(`onClose` → `_shutdown`). Expected server behavior: **the session is not
ended**, because leaving does not call `end` (G4). The parent may therefore keep
camera/mic on with no media until expiry or until the parent ends.

Record whether the child's camera indicator turns off and whether the parent
stays **Connected**. A parent that stays live after the child left is a P2
finding, not a pass.

### T10 — Request expiry (10 minutes)

Accelerated QA-only option (dashboard SQL, test data only — not a migration):

```sql
update public.remote_sessions
set expires_at = now() + interval '20 seconds'
where id = '<SESSION_ID>' and status = 'requested';
```

1. Create a request and do not answer it.
2. Keep the parent session screen open; wait for the countdown to reach zero,
   or refresh.
3. On the child, open **Requests** (this triggers the server-side
   `pending_child` expiry sweep).

Expected:

- Parent: **Expired** label/banner; Join disabled; no media.
- Child: the request disappears from the list; the session screen shows
  **Request expired** if opened directly.
- Server: `status='expired'` (the `pending_child` path sets it) and no signals.
- Client on expiry also calls `end` with reason `expired` as a best effort; if
  that wins first, the row is `ended` with `ended_reason='expired'` (G9). Record
  which one is observed.

### T11 — Accepted-session expiry (30 minutes)

Use the natural wait or the accelerated update:

```sql
update public.remote_sessions
set expires_at = now() + interval '30 seconds'
where id = '<SESSION_ID>' and status = 'accepted';
```

1. Accept, join, and stay connected.
2. Wait until expiry with both session screens open.

Expected:

- Both UIs switch to expired/terminal; tracks stop; peer disposed.
- Server rejects further `ice`/signal writes (`expires_at > now()` in RLS and
  the Edge Function checks).
- Do not expect a scheduled sweep: the `cron` endpoint is disabled, so the row
  may remain `accepted` until a client auto-end or a later lazy expiry.

### T12 — Background and lock screen

1. During a connected call, press Home for 10 seconds, then return.
2. Lock the screen for 10 seconds, then unlock.
3. Repeat with the child device.

Expected from the documentation: no capture outside the visible session.
Expected from the code: there is no lifecycle observer and no camera/microphone
foreground service, so the behavior is whatever Android enforces (G6). Record:

- Privacy indicator state while backgrounded/locked.
- Whether the call recovers on return, and whether the session was ended.
- `adb shell dumpsys media.camera` / `dumpsys audio` snapshots.

**PASS** only if capture stops or the session visibly ends within 5 seconds and
the UI says so. A silent continuation is a P1 privacy finding.

### T13 — Authorization checks (no role trust)

With the parent and child tokens (not the service-role key):

1. Foreign parent: request/`ice`/`respond`/`end`/signal insert for the QA
   session → expect `403 forbidden` or RLS denial.
2. Non-participant child or a second parent in the same family:
   - may read the session row (family parent policy);
   - must receive **zero** `webrtc_signals` rows and must not be able to insert;
   - may be allowed to join the private channel topic (`is_family_parent`) but
     must receive no signal rows. Record the distinction.
3. Spoofing: insert a signal with `from_user_id` of the other participant using
   the child token → expect RLS denial (`from_user_id = auth.uid()`).
4. After end/expiry, insert a signal → expect denial.

Expected: no client-supplied role is trusted; the Edge Function derives role
from `profiles` and membership from `family_members`
(`supabase/functions/_shared/auth.ts`). **PASS** only if every foreign/spoofed
attempt is denied.

### T14 — TURN-only (relay) call

Precondition: TURN configured and `turn_configured:true` (see
[remote-assistance.md](remote-assistance.md)); otherwise mark **BLOCKED**.

1. Put both phones on a test Wi-Fi with **AP/client isolation** and block
   outbound UDP (including 19302/3478) except TCP 443 to the TURN host. If using
   `turns:`, allow TCP 443/5349.
2. Verify direct host candidates cannot reach each other and STUN cannot create
   a server-reflexive path.
3. Repeat T3 (child first) and T4 (parent first).

Expected:

- Both sides' ICE rows contain `typ relay` candidates.
- The UI reaches **Connected**; two-way audio/video.
- The parent screen shows no **Relay not configured** banner.
- With TURN stopped mid-call, the connection fails with a **Media connection**
  warning; it must not falsely report **Connected**.

Also test the negative control once: TURN configured but firewall blocks the
TURN port → call must fail, not silently pass.

### T15 — Network change / reconnection

1. During a connected call, toggle airplane mode for 10 seconds, then restore.
2. Change Wi-Fi → cellular on one device.

Expected from the documentation: the call recovers or clearly fails. Expected
from the code: no ICE restart and no re-subscribe after a channel error (G7);
the warning text says to end and re-request.

**PASS** only if media resumes within 30 seconds without a new request. A
failure is an accepted finding for this build; record it.

## 4. Network matrix

| ID | Path | Setup | Expected candidates | What to record |
|---|---|---|---|---|
| N1 | Same LAN | Both on the same Wi-Fi, AP isolation off | `host` (and `srflx`) | Connect time, candidate types, direct vs relay |
| N2 | Different networks | Parent Wi-Fi, child cellular (and the reverse) | `srflx`, possibly `relay` | Whether media connects without TURN; failure is valid evidence |
| N3 | TURN-only | AP isolation + UDP blocked except TURN TCP/TLS | `relay` on both sides | `turn_configured:true`, relay counts, two-way media |
| N4 | TURN unreachable | TURN configured, port blocked | none usable | Clear failure; no false **Connected** |
| N5 | Network change | Toggle airplane mode / Wi-Fi ↔ cellular | re-gather | Recovery or terminal warning; no silent hang |

For each row, capture per-device screenshots at **Connecting** and **Connected**
(or at failure), the session row, and the ICE candidate list per `from_user_id`.

## 5. Logcat, UI and server checks

The app does not log ICE/SDP itself. Use plugin/native logs plus server rows:

```bash
adb -s <serial> logcat -c
adb -s <serial> logcat -v threadtime | grep -iE \
  "webrtc|peerconnection|ice|candidate|sdp|media|permission"
adb -s <serial> logcat -d -v threadtime > .tools/evidence/two-device/<run>/<device>-logcat.txt
```

Useful state snapshots:

```bash
adb -s <serial> shell dumpsys media.camera | grep -iE "Active|Client|Camera ID"
adb -s <serial> shell dumpsys audio | grep -iE "record|mode|communication"
adb -s <serial> exec-out screencap -p > .tools/evidence/two-device/<run>/<step>-<device>.png
```

- The Android privacy indicator (green dot) is the primary visual proof that
  the camera/mic are in use; confirm it appears only after Join and disappears
  on End/leave.
- The UI **Connected** chip alone is not proof of media: it comes from
  `RTCPeerConnectionState.connected`, which can be true before any frame is
  rendered/audio is audible. Require audible two-way audio and visible two-way
  video.
- Server-side ICE evidence is the stored candidate strings. Count `typ host`,
  `typ srflx`, `typ relay` per `from_user_id`; a TURN-only pass requires relay
  candidates on both sides and a working call.

## 6. Pass/fail criteria

| Area | PASS requires | FAIL / not pass |
|---|---|---|
| Consent visibility | Child sees the request on **Requests**; only the child can accept/decline | Request only visible after an unspecified refresh, or accepted by anyone else |
| No auto-accept | Server row stays `requested` until the child taps Accept; no permission/media before that | Any automatic consent or media |
| Decline terminal | Row `declined`, `consent_recorded=false`, no signals, parent UI terminal | Request stays open, parent keeps waiting, any media |
| Accept without media | Row `accepted` + `consent_recorded=true`; no permission dialog, no camera/mic, no offer | Camera/mic or signals before Join |
| Two-way media | Audible both ways + visible both ways + both **Connected** + no error banner | One-way, black video, no audio, stuck **Connecting…** |
| Join order | Connects in both T3 (child first) and T4 (parent first) | Fails when the parent joins first (known G1) |
| Mute/camera off | In-session controls work and tracks are not recreated | **NOT IMPLEMENTED** in this build |
| End (either side) | Both stop within 5 s; server terminal; reason matches actor | One side keeps media; status stays open |
| Leave screen | Local tracks stop; record whether the session ends | Parent keeps media after child leaves (G4) |
| Expiry | No media after expiry; both stop; server enforces via `expires_at` | Signals still accepted after expiry; media continues |
| Cleanup | Camera/mic indicators off; peer closed; no post-end signals | Track/peer leak; indicator stays on |
| Security | Foreign/spoofed signal attempts denied; non-participant reads zero rows | Any foreign read/write or client role trust |
| TURN | `turn_configured:true`; relay candidates; TURN-only call connects; failure when TURN is blocked | STUN-only reported as a TURN pass |
| Reconnection | Media recovers after a 10 s network loss without a new request | Hang or false **Connected** |
| Background | Capture stops or session ends visibly within 5 s | Silent capture or undefined state |

A run with TURN missing can still pass T1–T13 (direct/STUN paths) but **must not**
be reported as an end-to-end pass for restrictive networks. A run with one
device cannot pass any media criterion.

## 7. Known code-verified gaps to expect during execution

These were audit findings in the current source. **G1–G4 were fixed on
2026-10-27 (BUG-029)** and are covered by unit tests
(`test/features/remote_assistance/`, 11/11 pass), but the two-device run should
still confirm the user-visible behavior because the fix has not been exercised
between two real peers. **G5–G10 remain open** and are product/UX decisions or
unverified privacy behaviors, not test-script mistakes.

| ID | Finding | Status | Evidence |
|---|---|---|---|
| G1 | Parent ICE candidates that arrive before the child's peer exists were dropped, and `addCandidate` had no guard/queue for the remote description | **FIXED (unit-verified, two-device NOT TESTED)** — candidates are buffered (≤64) and flushed once the peer/remote description exists | `lib/features/remote_assistance/remote_session_controller.dart` (BUG-029); `test/features/remote_assistance/` |
| G2 | The client never called `markActive`/`start`; sessions stayed `accepted`, `started_at` null, no `session_started` audit, **Live** never shown | **FIXED (unit-verified, two-device NOT TESTED)** — the client now marks the session active on connect | `lib/data/repositories/supabase_remote_session_repository.dart`; `remote_session_controller.dart` (BUG-029) |
| G3 | `endSession` returned on server failure without stopping local tracks | **FIXED (unit-verified)** — teardown stops local media first, then calls the server; a failing server end no longer leaves capture open (`stops local media even when the server end call fails`) | `remote_session_controller.dart` (BUG-029) |
| G4 | Leaving the screen stopped local media but did not end the session or notify the peer | **FIXED (unit-verified, two-device NOT TESTED)** — a `PopScope` path ends the session / releases media on back-navigation | `remote_session_controller.dart` (BUG-029) |
| G5 | No in-session mute/unmute or camera on/off control | OPEN (missing feature) | session pages; only `lib/features/child/widgets/media_self_test_sheet.dart:147` toggles a track |
| G6 | No lifecycle observer and no camera/microphone foreground service; background capture behavior is undefined | OPEN (privacy, unverified) | no `AppLifecycleState` handling in `lib/features/remote_assistance/**` |
| G7 | No ICE restart and no re-subscribe after a Realtime channel error | OPEN | `remote_session_controller.dart:176-179`, `:285-288`, `:506-531`; repository `:246-257`, `:350-361` |
| G8 | Request delivery depends on opening the Requests screen (15 s poll); the shell badge is not polled | OPEN (no push) | `lib/features/child/controllers/child_requests_controller.dart:43-49`; `child_shell_controller.dart:136-141` |
| G9 | Client auto-end on expiry records `ended`/reason `expired`, not `expired` | OPEN (P3) | `remote_session_controller.dart:683-694`; `remote-session/index.ts:270-309` |
| G10 | Parent page's `isViewOnly` banner is unreachable/mislabeled (the page is parent-only) | OPEN (P3) | `remote_session_page.dart:74-85`; `remote_session_controller.dart:68` |

## 8. Evidence package

For each run, keep:

1. This plan with every step marked PASS/FAIL/BLOCKED and timestamps.
2. Per-device screenshots at: request visible, decline, accepted/no media,
   connecting, connected (both directions), mute attempt, end, expiry.
3. Per-device logcat files (full, not grepped only).
4. `dumpsys media.camera` and `dumpsys audio` before, during and after.
5. SQL exports: `remote_sessions` row and `webrtc_signals` counts/types.
6. Network description per matrix row (SSID/carrier, no passwords).
7. APK SHA-256 and app version on both phones.
8. Any observed G1–G10 behavior with the exact step and timestamp.

Do not include tokens, emails, passwords, TURN secrets or `.tools/*.env` content
in the evidence package.
