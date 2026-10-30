# Agent 7 — Authenticated UI sweep (live QA, Phase 6B)

Date: 2026-10-27 (local 14:45–15:35). Operator: agent 7 (only ADB/Flutter-toolchain holder).
Goal: on AUTHENTICATED parent and child screens, prove/disprove any recording start/stop/list/play/download/delete control and any Android screen-capture (MediaProjection) consent dialog.

## Deviations from the original plan (all forced by environment, none by choice)

1. **app-debug.apk cannot run on emulator-5554.** SHA-256 verified first: `2d979e084eeb1eeaba7da3aa1107777955a07c7ab7eb3b42d824d3559fe3a6a9` (starts `2d979e084eeb1eea` ✓). Installed with `adb -s emulator-5554 install -r` → Success, but launch crashes: the APK bundles `libflutter.so` **only for arm64** (`lib/x86_64/` has no libflutter.so — see unzip listing in session log), while the AVD process runs as x86_64. Crash: `UnsatisfiedLinkError: dlopen failed: ".../libflutter.so" is for EM_AARCH64 (183) instead of EM_X86_64 (62)`. Raw trace: `emu-debug-apk-abi-crash.txt`. Rebuilding was forbidden, so I used the **prebuilt `app-x86_64-release.apk`** (same source tree, built 12:53 today, contains `lib/x86_64/libflutter.so`). No build, no flutter clean.
2. **Emulator process died mid-session** (right after the remote-assistance leg; adb reported `error: closed`, `tasklist` showed no emulator/qemu process). Relaunched `Pixel_9a` AVD (`-no-boot-anim -no-snapshot-save`); app install and parent login survived the reboot; sweep resumed from the Alerts tab. Consequence: the pre-reboot logcat buffer was lost; the post-reboot buffer covers all remaining parent screens and the full child leg was on the realme.
3. **Realme was initially occupied**: at 14:45 `mCurrentFocus = co.griffin.ieouv/com.appx.core.activity.MainActivity` (third-party app, owner present) → child leg deferred, NOT TESTED at that point. Re-checked at 15:16: our app idle on the signed-out role-select screen, no other app foreground, no lock, no touch activity → proceeded with the child leg and restored signed-out state afterwards.
4. Realme local-only side effect: role-select "Last choice on this device" changed Parent Mode → Child Mode (device-local preference; the screen itself states it never grants permissions). Nothing else on the realme was changed (no pairing, no permission grants, no device-admin/DO changes, no unlink).
5. Emulator camera-permission dialog appeared (QR scanner on "Link a child") and was **denied**; camera permission remains ungranted on the emulator.

## Credentials
QA accounts from `.tools/qa_accounts.env` (PARENT_A on emulator, CHILD_A on realme). Passwords intentionally not reproduced anywhere in this file or in evidence.

## Per-screen results

Legend: RC = recording start/stop/list/play/download/delete control found; CD = screen-capture consent dialog appeared.
PASS = screen rendered and inspected (screenshot + uiautomator dump; this build DOES expose semantics, so XML text evidence is valid).

| # | Screen | Device | RC | CD | Evidence | Label |
|---|--------|--------|----|----|----------|-------|
| 1 | Role select (pre-auth) | emulator | N | N | emu-21-roleselect.png/.xml | PASS |
| 2 | Parent sign-in form | emulator | N | N | emu-22-parent-signin, emu-25/26/27 | PASS |
| 3 | Dashboard (family card, device cards) | emulator | N | N | emu-30-dashboard | PASS |
| 4 | Devices list | emulator | N | N | emu-31-devices | PASS |
| 5 | Device detail: QA Test Phone A (identity, permissions, policy) | emulator | N | N | emu-32/33/34 | PASS |
| 6 | App restrictions (QA Test Phone A) | emulator | N | N | emu-35-apprestrictions | PASS |
| 7 | Screen time / usage (QA Test Phone A) | emulator | N | N | emu-36-screentime | PASS |
| 8 | Location (QA Test Phone A) | emulator | N | N | emu-37-location | PASS |
| 9 | Safe zones (QA Test Phone A) | emulator | N | N | emu-38-safezones (slow load, final state captured) | PASS |
| 10 | Safety alerts (device) | emulator | N | N | emu-39-safetyalerts | PASS |
| 11 | Remote assistance list | emulator | N | N | emu-40-remoteassist | PASS |
| 12 | Remote assistance request dialog | emulator | N | N | emu-41-video-request | PASS |
| 13 | Remote assistance after send ("Request failed — device not active"; no session created, no cleanup needed) | emulator | N | N | emu-42-request-sent | PASS |
| 14 | Assistance session status (ended session) | emulator | N | N | emu-43-session-status | PASS |
| 15 | Alerts tab (global) | emulator | N | N | emu-44-alerts | PASS |
| 16 | Settings tab (account, family, notifications, privacy/retention, security notes, app) | emulator | N | N | emu-45/46-settings | PASS |
| 17 | Audit & retention (38 events, event types: enrollment, pairing, policy, unlink) | emulator | N | N | emu-47/48/49-audit | PASS |
| 18 | Family details (guardians, children) | emulator | N | N | emu-50-familydetails | PASS |
| 19 | Link a child (QR scanner + code entry) | emulator | N | N (only a **CAMERA** permission dialog, denied: emu-51) | emu-51/52 | PASS |
| 20 | Pairing requests | emulator | N | N | emu-53-pairingrequests | PASS |
| 21 | Device detail: QA Test Phone A (second revoked instance) | emulator | N | N | emu-54-devdetail2 | PASS |
| 22 | Device detail: QA Phone A (non-DO variant) | emulator | N | N | emu-55/56/57 | PASS |
| 23 | Location (QA Phone A, empty) | emulator | N | N | emu-58-location-phoneA | PASS |
| 24 | App restrictions editor (QA Phone A: blocked apps, schedules, allowlist mode) | emulator | N | N | emu-59/60 | PASS |
| 25 | Live assistance call screen | emulator | — | — | impossible: both family devices revoked; server refuses request | NOT TESTED (no path exists) |
| 26 | Role select / found state | realme | N | N | realme-60-state.png | PASS |
| 27 | Child sign-in form | realme | N | N | realme-61-child-creds | PASS |
| 28 | Child home "My phone" (unlinked state) | realme | N | N | realme-62/63/64 | PASS |
| 29 | Child Settings: Android permissions (usage/precise loc/bg loc/camera/mic/notifications/device admin — **no screen-record row**) | realme | N | N | realme-65/66/68 | PASS |
| 30 | Child Rules tab | realme | N | N | realme-73-child-rules | PASS |
| 31 | Child Requests tab (empty; no pending requests leaked from emulator attempt) | realme | N | N | realme-74-child-requests | PASS |
| 32 | Media self-test sheet ("Camera and microphone test") | realme | N | N | realme-69/70-selftest | PASS |
| 33 | "Recording / Off — preview only" row TAP | realme | **N — no-op** | N | realme-71-recrow-tap.png, realme-72-recrow-tap.xml | PASS |
| 34 | Sign-out (restore to found state) | realme | N | N | realme-75/76/77 | PASS |
| 35 | Child-side incoming assistance-consent UI | realme | — | — | unreachable: phone is unlinked ("Register this phone first"); creating a link would change server state → forbidden | NOT TESTED |

Authenticated screens viewed: **emulator parent side ≈ 24** (incl. dialogs and sub-states), **realme child side ≈ 9**.

## The "Recording" row (child media self-test sheet)

- Dump shows nodes `content-desc="Recording"` (bounds [60,1476][430,1524], `clickable="false"`) and `content-desc="Off — preview only"` (bounds [466,1476][1020,1536], `clickable="false"`).
- Tapped the row center (540,1500): **nothing happened.** Sheet unchanged (row still reads "Off — preview only" in post-tap dump), no new activity/window, no dialog, and post-tap logcat shows 0 hits for `mediaprojection|virtualdisplay|screenrecord|startCapturing|createScreenCaptureIntent`.
- The sheet's own copy: "This opens this phone's camera and microphone for a live preview on this screen. It is not recorded, saved, or sent anywhere, and it stops when you close this sheet." Sheet closed after the test (camera/mic tracks released).

## Keyword grep of all XML dumps (record|recording|capture|screenshot|projection|share screen|play|video|download|.mp4)

- Emulator hits file: `keyword-hits-emulator.txt` (16 unique lines). Every hit is benign:
  - Explicit disclaimers: "Nothing is recorded, and no screenshots or screen capture are taken" (remote assistance), "This app does not record audio or video, take screenshots, or capture the screen" (session status), "Assistance sessions never record or capture the child's screen" (settings security notes), "…not recorded, saved, or sent" (child self-test, realme).
  - System CAMERA permission dialog string "Allow Parent Control to take pictures and record video?" (QR scanner; camera, not screen capture — denied).
  - "Request video"/"Video sessions use the camera and microphone…" (assistance = camera/mic calls, not screen capture).
  - "Recorded" used as a verb for logs/timestamps (location fix "Recorded", consent "Recorded/Accepted", alerts "recorded by the server").
  - "Play Store" (app name in restriction list). No start/stop/list/play/download/delete recording control anywhere.
- Realme hits file: `keyword-hits-realme.txt` (6 lines) — same pattern: disclaimers + the static "Recording / Off — preview only" readout + "Video frames" (camera-preview stat label). No control.

## Logcat capture-API audit (end of session)

- Emulator `emu-logcat-raw.txt` (48,267 lines): 12 keyword hits, **all** `system_server` (pid 691) boot-time `MediaProjectionManagerService` lifecycle at 15:08 (AVD relaunch). Zero hits from `com.parentcontrol.parent_control` pid. `dumpsys media.projection`: no projections. Raw filtered: `emu-logcat-keyword-hits.txt`.
- Realme `realme-logcat-full.txt` (84,005 lines): 20 keyword hits — all `com.oplus.screenrecorder` (OEM system screen-recorder app, idle `STATE_INACTIVE`, later killed by Android), SurfaceFlinger `VirtualDisplaySurface` errors caused by our own `screencap`/earlier probes, and an adbd `ls /system/bin/screenrecord` line from the earlier agent-5 OS probe. Zero MediaProjection/virtual-display/consent activity from the app pid. Raw filtered: `realme-logcat-keyword-hits.txt`.
- No MediaProjection consent dialog appeared on either device at any point (screenshots cover all dialog states: emu-51 camera-permission only).

## Final device states

- **emulator-5554**: app = prebuilt `app-x86_64-release.apk`, **left SIGNED IN** as QA Parent A, on the app-restrictions screen. (The arm64-only debug APK was removed from it because it cannot run there.)
- **realme 5HXWRGQ4IFU8WS4T**: **left exactly as found** — signed out at role-select (local "last choice" now shows Child Mode; local-only preference). No accounts, permissions, pairing, or device-owner state touched.

## Verdict

**PASS — the negative is closed.** Across ~33 authenticated screens/dialogs/states on both roles, there is NO recording start/stop/list/play/download/delete control, NO screen-capture (MediaProjection) consent dialog, and NO logcat trace of capture APIs from the app. The "Recording / Off — preview only" row is a non-clickable readout that does nothing when tapped. Nothing observed contradicts the NOT IMPLEMENTED verdict from agents 1–6.
