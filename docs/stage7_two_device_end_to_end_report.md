# Stage 7 — Two-Device End-to-End Audio, Automatic Recovery and Lifecycle

Date: 2026-10-29
App: Parent Control 1.0.0+1 (debug)
APK: `build/app/outputs/flutter-apk/app-debug.apk`
SHA-256: `47842509ec6e784b9db23fe1300d819855b840416a667ebfe6729c10fe37c312`
Size: 243,806,784 bytes
Built: 2026-10-29 10:03 (FVM Flutter 3.44.6 / Dart 3.12.2)

Devices used:

| Role | Serial | Model | Installed APK SHA-256 (on-device) |
|---|---|---|---|
| Parent | `emulator-5554` | sdk_gphone64_x86_64 | `47842509…fe37c312` (verified 11:29) |
| Child | `5HXWRGQ4IFU8WS4T` | realme RMX2161 | `47842509…fe37c312` (verified 11:29) |

> **Correction notice (2026-10-29, later):** §8(1), §8(4), §9-P1 and §2.5 were
> true when written and were **superseded** later that day: the two migrations
> were applied to hosted through the Dashboard (see §11 and
> `docs/stage7_hosted_migration_apply_2026-10-29.md`), and the child account was
> re-linked through the normal invite/approval flow at 05:46Z. The child matrix
> remains unexecuted. See also `docs/pairing-recovery-baseline.md`.
>
> Status: **partial**.
> - One-way child→parent media, parent-controlled lifetime, parent lifecycle
>   (Home, app switch, lock, Activity destroy/recreate, Recents+reopen, network
>   off/on, explicit End) were exercised on this exact APK and **passed** except
>   one client deviation (realtime banner not auto-clearing, §8/P9) and the
>   hosted signaling RLS block seen during the run (since fixed in the database).
> - The **child lifecycle matrix and the 15-minute media endurance are BLOCKED**:
>   at 10:52:58 the child app logged a *local sign-out* and an operator then
>   signed the phone in as `ankit1@gmail.com`, which at that time was **not
>   linked to any family**. From that moment the child device could no longer
>   participate in the paired session. Nothing was recorded as passed that was
>   not observed.
> - The requested parent account `ankit@gmail.com` was not signed in on any
>   device during this run; no credentials were invented.
> - No hosted Supabase change, secret change, TURN provisioning or Edge Function
>   deployment was made *during this run*. The Supabase CLI was not used.
>   Database-only changes were applied later (§11).

---

## 1. Accounts and pairing

### 1.1 What the master prompt asked for

`ankit@gmail.com` = Parent, `ankit1@gmail.com` = Child, both verified by the
server, paired through the normal invitation + child-approval flow.

### 1.2 State actually observed

| Device | Account signed in | Role / link state | How verified |
|---|---|---|---|
| `emulator-5554` | `qa.parent.a2.20261026@example.com` (QA Parent A) | parent, family “QA Family A”, device `realme RMX2161` listed | app UI (session header, device list), app prefs e-mail only |
| `5HXWRGQ4IFU8WS4T` | `ankit1@gmail.com` at 11:0x (previously QA Child A) | **child, not linked** at the time — “Set up this phone”, Child ID `PC-G2RSSRYB`, “Not linked to a parent”. **Superseded 2026-10-29 05:46Z:** the account is now an active child of family `demo` (request `c0c70473…` approved 05:47:15Z) | child app UI, app prefs e-mail only; later state by hosted read |

Change observed during this stage (uncontrolled, not performed by me):

* `10:52:58.947` child process logs `supabase.auth: INFO: Signing out user with scope: local`.
* `10:53:04` Home; `10:53:06` app foregrounded again with an autofill field focused;
  a partial e-mail (`ankit…`) is visible on screen; `10:53:12` Recents;
  `10:53:14.657` `Killing 15571:com.parentcontrol.parent_control (adj 400): remove task`;
  `10:53:17` an `android.intent.action.DELETE` for our package opens the system
  uninstaller (the same APK, same SHA-256, is still installed afterwards);
  `10:53:55` the app is relaunched and the sign-in form is shown.
* The child is then signed in as `ankit1@gmail.com` and lands on
  “Set up this phone / Your Child ID / Not linked to a parent”.

No code path in this app signs a user out on backgrounding (the only sign-outs
are the settings button and the unlink/logout release), and the typed e-mail on
screen shows a person was using the phone. The exact trigger of the 10:52:58
sign-out is therefore **not conclusively attributable**; it is recorded as an
uncontrolled interruption and is **not** counted as a pass for any child
lifecycle case.

### 1.3 Result for Phase 1

* `ankit1@gmail.com` — **exists and authenticated** on the child phone (it
  reached the child setup screen, so the server accepted the session). It was
  **not paired** at that time; it was re-linked later the same day (see §1.2).
* `ankit@gmail.com` — **BLOCKED (unverified)**. It is not signed in on either
  device and no credentials or Dashboard session were available. No password was
  invented, no e-mail verification was bypassed, and no role was assigned from a
  client field.

**Exact manual action required to unblock the paired-account run**

1. Parent device (`emulator-5554`): sign in with `ankit@gmail.com` (Settings →
   sign out of the current QA parent, then sign in). The role must be confirmed
   by the server (`auth-bootstrap`), never typed locally.
2. Parent → Devices → add device with the Child ID shown on the child phone
   (`PC-G2RSSRYB` on this run; it changes per account/install).
3. Child phone: open “Check for requests”, approve the request, accept the
   pairing prompt, then start sharing.
4. Parent: Remote assistance → Request audio; child accepts and taps Join.

Until step 1 is done, the child phone cannot be re-linked and the child matrix
below cannot be executed on the requested account pair. Re-linking QA Child A
is possible (its credentials exist locally in `.tools/qa_accounts.env`) but would
have signed out the owner’s `ankit1@gmail.com` session; that in-progress state
was deliberately preserved instead of being overwritten.

---

## 2. Root causes addressed in this stage

### 2.1 SDP glare (two offerers)

Earlier builds let either side answer an ICE failure with a fresh offer. When
both did it, both peers sat in `have-local-offer` and libwebrtc rejected the
remote SDP, so a recoverable blip became a dead session. Fix: **single-negotiator
rule** — the parent is the only offerer.

* `_scheduleIceRecovery()` — child does **not** offer; it asks the parent to
  renegotiate (`_requestParentRenegotiation()` → `_announceChildReady()`).
  `lib/features/remote_assistance/remote_session_controller.dart:1797-1833`
* `_attemptIceRestart()` — parent-only, refuses to run while connected unless
  forced, refreshes TURN credentials before every restart.
  `lib/features/remote_assistance/remote_session_controller.dart:1835-1860`
* `_handleChildReady()` — parent-only, 3 s cooldown, in-flight offer guard,
  bounded restarts per peer, then a bounded number of recovery joins.
  `lib/features/remote_assistance/remote_session_controller.dart:1640-1698`

### 2.2 Bounded retries, backoff and stale generations

* ICE restart backoff `[2 s, 5 s]`, per-attempt cap 20 s.
  `lib/features/remote_assistance/remote_session_controller.dart:78-82`
* Signaling retry backoff `1/2/4/8/16 s`, reset on foreground resume
  (`_resetSignalRetry()` in `reconcileAfterResume`).
  `lib/features/remote_assistance/remote_session_controller.dart:83-89, 2511-2515`
* Subscription generation: callbacks from a stale channel are dropped
  (`_signalGeneration`, `_onSignalError`).
  `lib/features/remote_assistance/remote_session_controller.dart:769-800`
* Negotiation generation is carried in each signal (`gen`) and a stale answer is
  ignored. `lib/features/remote_assistance/remote_session_controller.dart:887-890, 1205-1223`

### 2.3 False “microphone off” while the mic was open

The child media card derived the mic state from media flow, so during the window
between `getUserMedia` and the first RTP packet it said “Microphone is stopped”.
Fixed by separating **capture** from **flow**:

* `isCapturing` (`RxBool`, line 163) and `isCaptureActive` (line 319) in the
  controller; `_setCaptureActive()` (line 322) is the single place that flips it.
  `lib/features/remote_assistance/remote_session_controller.dart:163,319-322`
* Child card now says “Microphone is on — starting the connection… /
  checking audio… / not reaching your guardian / reconnecting…”, and “live”
  only when RTP actually flows.
  `lib/features/child/child_session_page.dart:412` (`_mediaCard`),
  `:546` (`_mediaHeadline`), `:594` (`_mediaChipLabel`)

### 2.4 Child could not re-join over a stale peer

`canJoin` (line 268) required “no active peer”, so after Stop sharing the Join
control disappeared. Now the child may re-join an open session and `join()` tears
the stale peer down first; the parent still never replaces a live peer.
`lib/features/remote_assistance/remote_session_controller.dart:268` and the Join
button in `lib/features/child/child_session_page.dart:412` (`_mediaCard`).

### 2.5 Hosted defect found live (fixed in the database on 2026-10-29)

At the time of the run, with an accepted session (`expires_at = NULL`) the
parent’s signaling insert was rejected by the **hosted** database:

> `Session action failed — new row violates row-level security policy for table "webrtc_signals"`

observed on the parent at 11:11 and again at 11:17/11:22, immediately after the
resume-triggered renegotiation. The repo already contained the fix
`supabase/migrations/20261028000300_signaling_open_session.sql` and the local
test `supabase/tests/62_signaling_consented_session.sql` (passing), but at that
moment the migration was **not deployed**. Consequence on hosted at that time:
initial media could be established, but *any* renegotiation/ICE restart after
acceptance could not publish signals.

**Superseded:** `20261028000200` + `20261028000300` were applied to hosted via
the Dashboard later on 2026-10-29, with positive/negative/terminal probes (§11).
The Edge Function bundle was not deployed. Device-level proof that the parent's
renegotiation offer is now accepted during automatic recovery is still pending.

---

## 3. Files changed (this stage)

Dart

* `lib/features/remote_assistance/remote_session_controller.dart` — capture/flow
  separation, single-negotiator recovery, bounded retries, stale-generation
  guards, child rejoin.
* `lib/features/child/child_session_page.dart` — capture-vs-flow media card,
  Join control for a connected-but-muted child.
* `lib/features/remote_assistance/remote_session_registry.dart`,
  `remote_session_page.dart`, `remote_assistance_page.dart`,
  `remote_assistance_controller.dart` — route/app-scoped session state.
* `lib/features/child/child_requests_page.dart`, `controllers/child_shell_controller.dart`,
  `tabs/child_home_tab.dart`, `tabs/child_requests_tab.dart` — child shell wiring.
* `lib/data/models/remote_session.dart`, `lib/data/services/device_admin_service.dart`,
  `lib/features/settings/parent_settings_controller.dart`.

Android (Kotlin)

* `AudioAssistanceService.kt` — microphone FGS (id 4303), `stopWithTask=false`,
  `START_NOT_STICKY`, 10 s capture heartbeat, startId-safe stop.
* `MainActivity.kt`, `NativeBridge.kt` — process-scoped FlutterEngine, engine-scoped
  bridge, service probe.
* `android/app/src/test/kotlin/.../AudioAssistanceRecreationTest.kt` — new.

Server (migration applied on hosted 2026-10-29; Edge Function still not deployed)

* `supabase/migrations/20261028000300_signaling_open_session.sql` — allows
  signaling on a consented session whose `expires_at` is NULL.
* `supabase/tests/62_signaling_consented_session.sql`, `supabase/tests/README.md`.

Tests

* `test/features/child/child_session_page_test.dart`,
  `child_session_lifetime_test.dart`, `child_shell_controller_test.dart`,
  `test/features/remote_assistance/remote_session_controller_test.dart`,
  `remote_session_reliability_test.dart`, `remote_session_page_test.dart`,
  `remote_session_registry_test.dart`, `remote_assistance_controller_test.dart`.

---

## 4. Verification actually run

| Command | Result |
|---|---|
| `.fvm/flutter_sdk/bin/flutter analyze` | clean, 0 issues |
| `.fvm/flutter_sdk/bin/flutter test` | **264 / 264 passed** |
| `cd android; .\gradlew.bat :app:testDebugUnitTest` | BUILD SUCCESSFUL |
| Deno `_shared` tests | 36 passed |
| Deno `remote-session` tests | 11 passed |
| SQL chain (`supabase/tests/README.md` exact command) on fresh DB `parentcontrol_stage7_104725` | `EXIT=0`, 0 `ERROR`, 0 `ASSERTION FAILED`, 19 public tables; DB dropped afterwards |
| `run_pairing_invite_race.sh` | PASS (B blocked ≥2.5 s, `created=false`, one live row) |
| `run_remote_session_race.sh` | PASS (one open session per device) |
| On-device APK hash, both devices | equals build hash `47842509…c312` |

SQLite/PostgreSQL note: the local cluster runs on `127.0.0.1:55432`; all SQL
runs used disposable databases.

---

## 5. Parent lifecycle matrix (emulator-5554)

Exact APK, session `Audio assistance`, accepted 10:38, “Until you end the session”.

| # | Case | Observed | Result |
|---|---|---|---|
| P1 | Session open, audio live | Child: `DEBUG RTP: out 30166 pkts / 2028403 B`; Parent: `in 36812 pkts / 2527900 B`, chips “Media connected / Audio live”, “One-way audio live”. Session page shows “Until you end the session”, elapsed 12m. `s7b-child-check.png`, `s7b-parent-live-1.png` | **PASS** |
| P2 | Home 12 s then return | pid 17466 alive; page restored; session Active; elapsed 31m → 32m. `p1-parent-home.png`, `p1-parent-return.png` | **PASS** |
| P3 | App switch (Settings) 10 s | session Active; elapsed 33m. `p2-parent-switch.png`, `p2-parent-return.png` | **PASS** |
| P4 | Lock 2 min 16 s (11:14:03→11:16:19) | session Active; elapsed 37m; no end. `p3-parent-unlock.png` | **PASS** |
| P5 | Navigate away | Back / back-arrow opens “End the session and leave?” with **Stay**; Stay keeps the session and the server state. `s7b-parent-back-1.png`, `p7-parent-end-confirm.png` | **PASS** (explicit, confirmed) |
| P6 | Activity destroy + recreate | Page rebuilt from the app-scoped registry; session Active; screenshot at 11:20 shows elapsed 41m and “Until you end the session”. The `wm_on_destroy_called`/`wm_on_create_called` lines were observed live but are **not in the stored log excerpt**, so the OS-level destroy times (claimed 11:19:53/11:19:55) are not independently evidenced here. `p5-parent-recreate.png` | **PASS for state restoration; OS destroy/create timing unverified** |
| P7 | Recents swipe | Task removed to launcher; process survived on this emulator; reopening restored the session page (elapsed 38m). `p4-parent-recents.png`, `p4-parent-reopen.png` | **PASS** (task-removal variant; parent process death not exercised) |
| P8 | Network off 52 s → on | Airplane mode 11:20:49–11:21:41; session stayed Active (42m→43m) and no “live” claim was made while offline. `p6-parent-offline.png`, `p6-parent-online.png` | **PASS** for session survival |
| P9 | Realtime after reconnect | “Live updates interrupted” banner **did not clear** after reconnect (11:21:41) nor after tapping Refresh (11:22:51). `p6b-parent-refresh.png` | **FAIL (P3, messaging)** |
| P10 | Explicit End | Dialog “End assistance session?” captured at 11:24 (45m elapsed; exact second not established) → End session; status **Ended**, “Ended Oct 29, 2026 11:24 AM”, “This session is over.”; list shows Ended + “No media is open”. `p7-parent-end-confirm.png`, `p7-parent-ended.png`, `p7-parent-list.png` | **PASS** |

Backgrounding, lock, and Activity disposal never sent an end RPC: the server row
stayed `active` through P2–P8 and only the explicit End (P10) closed it.

Recovery attempts were bounded: after the child disappeared the parent logged
`onConnectionChangeFAILED` at 10:53:15, again at 10:53:40, then
`onConnectionChangeCLOSED` at 10:53:43 and settled on
“Connection setup failed … the session stays open until the parent ends it”
(10:57) — no loop, no false “live”.

---

## 6. Child lifecycle matrix (RMX2161)

The child phone left the paired account at 10:52:58 (see §1.2). It was
re-linked later that day, but these cases were **not executed** on this APK and
are not claimed.

| # | Case | Observed | Result |
|---|---|---|---|
| C1 | Screen open, sharing | UI “Microphone is live”, chips “Media connected / Microphone live”, `out 30166 pkts / 2028403 B`; WebRTC `REC : 10000msec, 48kHz … samples: 480000` blocks at 10:52:25/35/45 in the child log | **PASS** |
| C2 | Home | Not run in a controlled way (Home landed at 10:53:04 during the operator sequence) | **BLOCKED** |
| C3 | App switch | Not run | **BLOCKED** |
| C4 | Lock 2+ min | Not run | **BLOCKED** |
| C5 | Navigate away from Assistance screen | Not run | **BLOCKED** |
| C6 | Widget dispose + recreate | Not run | **BLOCKED** |
| C7 | Recents swipe | Observed only as part of the operator sequence: `10:53:14.657 Killing 15571 … (adj 400): remove task`, `exited due to signal 9` — the process and the microphone FGS died with it, capture stopped | **FAIL as “survives swipe”** (OEM task-removal kill; not a controlled test) |
| C8 | Reopen app | Relaunch at 10:53:55 came back to a **signed-out** account; the session UI could not be reached | **BLOCKED** |
| C9 | Network interruption | Not run | **BLOCKED** |
| C10 | Network change | Not run | **BLOCKED** |
| C11 | Microphone permission revoke | Not run | **BLOCKED** |
| C12 | Stop sharing | Control rendered in the accepted-session UI (`Stop sharing` button visible in `s7b-child-check.png`), but the tap was not executed | **BLOCKED** |
| C13 | Force Stop | Not run (must not be faked; OEM may kill regardless of FGS) | **BLOCKED** |

Evidence that is still valid from C1:

* Microphone capture ran continuously for **856,234 ms (14 min 16 s)** —
  `audio_device_buffer.cc: total recording time: 856234` at 10:52:51 — with
  non-zero levels, i.e. real audio, not a silent track.
* The **child→parent** leg advanced RTP while both phones sat on their session
  screens. The parent→child leg carried no media (`in 0` on the child), which is
  the intended one-way design, not a second leg.

---

## 7. Endurance and timing

| Time | Event | Measurement |
|---|---|---|
| 10:30 | Parent requests audio | server `requested` (request deadline not re-derived in this run) |
| 10:38 | Child accepts, joins | server `accepted` |
| 10:50 | Both screens alive | parent `in 36812 pkts / 2527900 B`, out 0; child `out 30166 pkts / 2028403 B`, in 0 |
| 10:52:51 | Capture stops (sign-out path) | `total recording time: 856234` ms |
| 10:52:58 | Child local sign-out | `supabase.auth … Signing out user with scope: local` |
| 10:53:14 | Child process killed (task removed) | `Killing 15571 … remove task` |
| 10:53:15 | Parent detects loss | `onConnectionChangeFAILED` |
| 10:53:40 → 10:53:43 | Second failed attempt, then closed | bounded, 2 attempts |
| 10:57 | Parent shows media unrecoverable | session still Active, 19m |
| 11:11:19 | Parent resume → renegotiation | ICE gathering restarted; signal insert denied (RLS) |
| 11:16:19 | After 2-min lock | Active, 37m |
| 11:17:xx | After Recents + reopen | Active, 38m |
| 11:19:55 | After Activity recreate | Active, 41m |
| 11:21:41 | After 20 s network loss | Active, 43m |
| 11:24 | Parent End (dialog captured 11:24, 45m elapsed) | **Ended 11:24**, 45–46m total |

**Session endurance: 46 min without expiry (PASS).**
**Media endurance: 14 min 16 s (10:38:35 → 10:52:51), i.e. just under the
15-minute target (FAIL — ended by the external sign-out, not by the app).**

The 15-minute media requirement therefore is **not met** in this run. The
session-level endurance requirement (server session stays open, parent controls
lifetime) is met and evidenced.

---

## 8. Backend, TURN and hosted limitations

1. **Signaling RLS on consented sessions (hosted) — FIXED IN DATABASE
   2026-10-29.** During this run, parent inserts into `public.webrtc_signals`
   failed with `new row violates row-level security policy for table
   "webrtc_signals"` once the session was `active` with `expires_at = NULL`.
   `20261028000200` + `20261028000300` were applied later through the Dashboard;
   probes confirmed a participant insert is now accepted and a non-participant
   insert still fails `42501` (§11). Device-level recovery proof is still
   pending.
2. **Lifetime behaviour on hosted.** The 10:38 session stayed `active` for 46 min
   with “Until you end the session”. An earlier accepted session (requested
   09:26) was shown `Expired` at 10:09. The two runs differ; I did not inspect
   hosted configuration and made no deployment, so the difference is reported,
   not explained.
3. **TURN absent.** Both devices show “Relay not configured / No TURN relay is
   configured”. All media in this run used host candidates on the same network.
   Recovery across carrier NAT, or after a network change, is expected to fail
   without TURN; that path was not tested.
4. **Automatic recovery on hosted was blocked by (1) during this run.** The
   app-side recovery is wired and unit-tested, but with the old policies a
   hosted session could not publish the renegotiation offer. The policies have
   since been corrected; the recovery path itself has not yet been re-proven on
   a device.
5. **OEM process death.** ColorOS killed the child app when its task was removed
   (`remove task`, signal 9). An FGS does not survive that on this ROM. No bypass
   was attempted and none is claimed.

---

## 9. Deviations and follow-ups

| Severity | Item | Recommendation |
|---|---|---|
| P0 | Child matrix not executed: child phone left the family during the run (`ankit1@gmail.com` was unlinked then) and `ankit@gmail.com` was not signed in. **Child is re-linked as of 2026-10-29 05:46Z; the parent device is still absent** | Restore a parent device signed in as `ankit@gmail.com`, then run §6 |
| P1 | Hosted `webrtc_signals` RLS blocked parent renegotiation on `expires_at = NULL` | **Applied via Dashboard 2026-10-29** together with `20261028000200` (§11). Do not replay `20261028000200` (not idempotent). Edge Function redeploy still requires authorization |
| P2 | Realtime banner does not clear after network restore or manual Refresh | Re-subscribe on connectivity regained; keep the banner only while the channel is actually down |
| P3 | Media endurance 14m16s instead of 15m in this run | Re-run endurance once the child account is paired; nothing in the log indicates an app-side cap |
| P3 | Parent Recents did not kill the process on the emulator | Exercise parent process death on a physical device |

Not done, by rule: no Supabase CLI, no hosted migration/function/secret change,
no TURN provisioning, no account creation, no password invention, no e-mail
verification bypass, no RLS/consent weakening, no audio recording, no
`git reset --hard`/`git clean`, no destructive migration, no unrelated
user/link modification.

---

## 10. Evidence index (`docs/evidence/stage7/`, raw copies in `.tools/evidence/stage7/`)

| File | Shows |
|---|---|
| `s7b-child-check.png` | Child live: “Microphone is live”, RTP out counters, Stop sharing, “Only your guardian can end this session” |
| `s7b-parent-live-1.png` | Parent live: “One-way audio live”, RTP in counters, “Until you end the session”, 12m |
| `s7b-parent-observe-1.png` | Child loss: media unrecoverable, session still active, 19m |
| `s7b-child-home.png` | Child app on a sign-in sheet with a partially typed e-mail |
| `s7b-child-observe-1.png` | Child “Set up this phone”, Child ID `PC-G2RSSRYB`, “Not linked to a parent” |
| `s7b-parent-stay.png` | Signaling banner + session still active (31m) |
| `p1-parent-home.png`, `p1-parent-return.png` | Parent Home → return, session preserved |
| `p2-parent-switch.png`, `p2-parent-return.png` | Parent app switch |
| `p3-parent-unlock.png` | After 2-min lock, 37m |
| `p4-parent-recents.png`, `p4-parent-reopen.png` | Recents → reopen restores the session page |
| `p5-parent-recreate.png` | Activity destroy/create, 41m |
| `p6-parent-offline.png`, `p6-parent-online.png`, `p6b-parent-refresh.png` | Network off → on, banner persists |
| `p7-parent-end-confirm.png`, `p7-parent-ended.png`, `p7-parent-list.png` | Explicit End, Ended 11:24, list shows Ended |
| `logs/parent-excerpt.log` | ICE teardown timing, resume renegotiation, Activity destroy/create |
| `logs/child-excerpt.log` | Capture 10 s blocks + total 856,234 ms, local sign-out, `remove task` kill, uninstall intent, Home |

---

## 11. Addendum — 2026-10-29: hosted migrations applied via Dashboard

This addendum supersedes §8 item 1 and the P1 row in §9. The two pending
migrations were applied to `parent-control-prod` through the Supabase Dashboard
SQL Editor (no CLI, no project change, no table reset, no function deployment):

- `20261028000200_parent_controlled_session_lifetime.sql`
- `20261028000300_signaling_open_session.sql` (applied with the above, never alone)

Verified live: `expires_at` is nullable; the pending-only check constraint,
`remote_sessions_transition_guard` trigger and `private.expire_stale_sessions()`
are present; both `webrtc_signals` policies no longer reference `expires_at`;
a parent-role insert for the existing `NULL`-expiry session succeeded while a
non-participant insert was rejected (`42501`) and reviving a terminal row was
rejected (`session_terminal`). All probes were rolled back.

Consequences for this report:

- The hosted RLS defect in §2/§8(1) is **fixed**; the remaining blocker for
  proving automatic recovery end-to-end is the unpaired child device (task 36),
  not the database.
- The production `remote-session` Edge Function was **not** redeployed, so the
  new `request_remote_session` concurrency guard and `session_state` handling are
  still inactive. That remains a separate, unauthorized production deployment.
- One orphaned `active` session (`e84ba35e-…`, device `fd79ee34-…`) now has no
  deadline and must be ended by a parent. It was left untouched.

Full evidence: `docs/stage7_hosted_migration_apply_2026-10-29.md`.
