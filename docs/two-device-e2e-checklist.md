# Two-device end-to-end checklist — pairing, session, network, end

This is the manual matrix that closes the gap marked **NOT TESTED** in
[`docs/pairing-recovery-fix-report.md`](pairing-recovery-fix-report.md) §5–§7.
It must be run on two real Android devices (or one device plus an AVD) with the
accounts below. Do not mark a step PASS without a screenshot or log line.

## Prerequisites

| Item | Requirement |
|---|---|
| Parent account | `ankit@gmail.com`, email verified, owner/parent of the family |
| Child account | `ankit1@gmail.com`, email verified, previously linked as an active child member |
| Parent device | Android 10+ with Play services, signed in as the parent |
| Child device | The paired child phone, network-capable, permission-granted |
| APK | Debug build from `bash scripts/build_debug_apk.sh` (or the release build if it was signed for distribution); both devices must run the **same** build |
| Backend | Hosted `parent-control-prod` — no migration, no Edge Function deploy in this window |
| Access | Chrome signed in to the Supabase Dashboard; SQL Editor used **read-only** |

Record before starting:

* APK sha256 and build time (`sha256sum build/app/outputs/flutter-apk/app-debug.apk`).
* Both devices: manufacturer, model, Android version, app version.
* Start time (UTC).

## Checkpoints

Run steps 1–9 as **Checkpoint A** (pairing). If any step fails, stop and report
before touching the session steps. Run steps 10–15 as **Checkpoint B**
(session). Stop at Checkpoint B after step 12 before doing the network leg, so
the interruption can be reproduced deliberately.

## Checkpoint A — pairing freshness

| # | Actor | Action | Expected | Status |
|---|---|---|---|---|
| 1 | Parent | Install and open the APK, sign in as `ankit@gmail.com` | Home shows the family; no "backend not configured" state | ☐ |
| 2 | Parent | Devices tab → pair/invite child; note the Child ID shown | Child ID is displayed; invite form accepts it | ☐ |
| 3 | Child | Open the app on the child phone, sign in as `ankit1@gmail.com`, stay on **Home** (do not pull to refresh) | Child ID shown on the child screen matches step 2 | ☐ |
| 4 | Parent | Submit the Child ID | Invite is created; parent screen shows "waiting for child approval" | ☐ |
| 5 | Child | **Do nothing** for up to 20 s | Pending invite appears on the child's Home/Requests without any manual refresh (D1 fix) | ☐ |
| 6 | Child | Approve the request | Child app shows linked state; approval confirmation is shown | ☐ |
| 7 | Parent | Stay on the Devices tab; **do not pull to refresh** for up to 60 s | Device list updates to show the child device as linked (D2 fix) | ☐ |
| 8 | Parent | Look at the pairing result card; **do not tap "Check status"** for up to 10 s | Card moves to approved/linked on its own (D3 fix) | ☐ |
| 9 | Both | Force-stop both apps, relaunch, sign in if needed | Both apps show the same linked/approved state; no re-pairing, no duplicate invite | ☐ |

Checkpoint A evidence: a screenshot of step 5 within the 20 s window, step 7
within the 60 s window, step 8 within the 10 s window, and both apps after step 9.

Stop condition: if step 5, 7 or 8 needs a manual refresh, the corresponding fix
is not working on device — capture the timestamps and report; do not continue to
Checkpoint B as if pairing were verified.

## Checkpoint B — session, audio, network, end

| # | Actor | Action | Expected | Status |
|---|---|---|---|---|
| 10 | Parent | Start a remote assistance session for the child device | Session goes `requested`; parent sees waiting consent | ☐ |
| 11 | Child | Approve the session request; keep the app in the foreground at first | Consent is recorded; microphone notification appears | ☐ |
| 12 | Parent | Observe the session page for 5 min of continuous audio | Status is active; audio is audible and continuous; no "Reconnecting" flapping | ☐ |
| 13 | Child | Turn off Wi-Fi **and** mobile data for ~60 s, then restore the same network | Parent shows reconnecting/"live updates interrupted"; after restore the banner **clears without a manual refresh** and audio resumes (D5 fix) | ☐ |
| 14 | Parent | Press **End session** and confirm | Child media stops, microphone notification is removed, both apps show a terminal state | ☐ |
| 15 | Both | Relaunch both apps; re-open the session/history | Terminal state persists; the session does not revive; no second open session for the device | ☐ |

Optional cleanup: the pre-existing open row `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9`
can be closed by the parent from a device that lists it, using **End session**.
Do not delete or update it in SQL.

Checkpoint B evidence: a screenshot of the active state (step 12), a screenshot
of the interrupted banner and of it clearing (step 13), screenshots of both
terminal states (step 14), and both apps after relaunch (step 15).

## Server-side read-only checks (Dashboard SQL Editor)

Run these only as read-only queries; no writes.

* Before step 10: one open session per device at most.
* After step 14: the session row for this device is terminal (`ended`), with an
  `ended_at` and `ended_reason` set by the parent End flow.
* After step 15: no new open session created by the relaunch.

## Failure report template

For every failing step record:

1. Step number and exact action.
2. Expected vs observed behaviour.
3. Timestamps (device clock and UTC).
4. Error text/code shown in the UI, if any.
5. Screenshot(s) named `stage8-<step>-<actor>-<state>.png`.
6. Sanitized `logcat` excerpt for package `com.parentcontrol.parent_control`
   (filter on `parent_control|RemoteSession|AudioAssistance`; never paste tokens,
   JWTs or keys).
7. Session and device rows as read-only SQL output (ids, status, timestamps
   only).

## What this checklist does not cover

* Force Stop and OEM process-kill survival — those are platform limits, already
  measured in Stage 5/7 and not re-scored here.
* TURN provisioning or audio quality on restrictive networks — no TURN claim is
  made by this checklist.
* Production Edge Function deployment — the stale `remote-session` bundle is a
  separate, authorization-gated task (fix report §10).
