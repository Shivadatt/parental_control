# Agent 5 — Live On-Device Verification: Child-Screen Recording (MediaProjection)

Date: 2026-10-27 (IST) · Verifier: agent 5 (sole ADB holder) · Tool: `adb` (read-only inspection + screenshots + uiautomator + one OS screenrecord probe, cleaned up)

Scope: verify on real hardware whether Android screen RECORDING (MediaProjection capture of the child screen) exists in the installed app `com.parentcontrol.parent_control`. No project source modified. No installs, no uninstalls, no data wipes, no settings changes, no logins.

## Verdict

**Screen recording: NOT IMPLEMENTED — CONFIRMED LIVE.** No capture permission in the installed package, no capture service running, no recording UI reachable, no MediaProjection consent activity ever launched, zero MediaProjection/VirtualDisplay logcat evidence, and no app-produced video files anywhere. Acceptance rule (a feature passes only if actual screen content is recorded by the app): **FAIL / absent** — recording does not exist on-device, matching the four prior code audits.

Two material surprises (details below): the "parent device" emulator has **no app installed at all**, and the child realme app is **signed out** (onboarding screen), so authenticated child/parent dashboards were NOT TESTED live.

## Device identity (Task 1)

| Check | realme RMX2161 (child) | emulator-5554 (parent) |
|---|---|---|
| Command | `adb -s 5HXWRGQ4IFU8WS4T shell getprop ...` | `adb -s emulator-5554 shell getprop ...` |
| Model | RMX2161 | sdk_gphone64_x86_64 (Pixel 9a AVD) |
| Android / SDK | 12 / API 31 | "17" / API 37 |
| ABI | arm64-v8a | x86_64 |
| Fingerprint | realme/RMX2161/RMX2161L1:12/SP1A.210812.016/Q.d5ef75_5f7:user/release-keys | google/sdk_gphone64_x86_64/emu64xa:17/CE2A.260420.051.A2/16418371:user/release-keys |
| Evidence | `device1-realme-identity.txt` | `device2-emulator-identity.txt` |

## Installed package (Task 1)

| Check | Command | Observed | Label |
|---|---|---|---|
| realme install | `dumpsys package com.parentcontrol.parent_control` | versionName 1.0.0, versionCode 2001, minSdk 24, targetSdk 36; firstInstall=lastUpdate=2026-10-27 12:55:41; APK `/data/app/~~sVdK97UTzFHM4fbV8nIMpA==/com.parentcontrol.parent_control-pp9holpDjTW9GOpxImWgqQ==/base.apk` | PASS (installed) |
| emulator install | `dumpsys package …` / `pm list packages -3` | **"Unable to find package"**; zero third-party packages on emulator | FAIL (app absent — contradicts briefing) |
| Requested perms (realme) | dumpsys `requested permissions` | INTERNET, ACCESS_NETWORK_STATE, COARSE/FINE/BACKGROUND_LOCATION, CAMERA, RECORD_AUDIO, POST_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_LOCATION, RECEIVE_BOOT_COMPLETED, PACKAGE_USAGE_STATS, QUERY_ALL_PACKAGES, MODIFY_AUDIO_SETTINGS, DYNAMIC_RECEIVER_NOT_EXPORTED | recorded |
| **Capture perms in installed pkg** | `grep -icE "projection|RECORD_SCREEN|MEDIA_PROJECTION" device1-realme-dumpsys-package.txt` | **0 hits. `FOREGROUND_SERVICE_MEDIA_PROJECTION` is NOT requested or granted; no screen-capture permission of any kind exists in the installed package** | **PASS (absence confirmed)** |
| Granted runtime perms | dumpsys runtime permissions | CAMERA=false, RECORD_AUDIO=false, all LOCATION=false (none granted); only normal install-time perms granted | recorded |

## Live capture state (Task 2)

| Check | Command | Observed | Label |
|---|---|---|---|
| Projection service name | `dumpsys -l \| grep -i proj…` (both devices) | service is `media_projection` (not `media.projection`) | info |
| Active capture realme | `dumpsys media_projection` | `MEDIA PROJECTION MANAGER … Media Projection: null` — no active session | PASS (none) |
| Active capture emulator | `dumpsys media_projection` | same: `Media Projection: null` | PASS (none) |
| App services realme | `dumpsys activity services com.parentcontrol.parent_control` | `(nothing)` — no services at all, hence **no foreground service of any type**, no media-projection FGS; app process was alive (PID 27003) with zero services | PASS (none) |
| App services emulator | same | `(nothing)` (package absent) | PASS (none) |
| Evidence | `device1-realme-media-projection-state.txt`, `device2-emulator-media-projection-state.txt`, `device1-realme-app-services.txt`, `device2-emulator-app-services.txt` | | |

## UI surface proof (Task 3)

Cold launch: `monkey -p com.parentcontrol.parent_control -c android.intent.category.LAUNCHER 1`. The app on the child device is **signed out** — it opens on the "Get started — How will you use Parent Control?" role-select. Per constraints I did not log in or register; I walked every reachable pre-auth screen.

Note on tooling: Flutter exposes no text in `uiautomator dump` (semantics off); keyword search of all dumped XML for record/recording/capture/screenshot/screen share/projection/play/video returned **0 hits**. Screenshots are the authoritative enumeration. Injected `input tap` was unreliable on this ColorOS device until the display was in portrait and node-center coordinates from the dump were used.

| Screen (evidence file) | Visible controls | Recording control? |
|---|---|---|
| Role-select top (`realme-01-launch.png`, `realme-02-rolescroll.png`) | header, Parent Mode card text | NO |
| Role-select bottom (`realme-04-rolebottom.png`, `realme-11-portrait.xml`) | Parent Mode: Sign in, Create account; Child Mode: Sign in, Create account; footer "A device role is a server-side decision…" | NO |
| Child sign-in (`realme-12-child-signin.png/.xml`) | back, "Continuing as Child mode", Email, Password, eye toggle, Sign in, "New here? Create an account" | NO |
| Parent sign-in (`realme-16-parent-signin.png/.xml`) | same shape, "Welcome back" | NO |
| Parent create-account (`realme-17-parent-createacct.png`) | Full name, Email, Password, Confirm password, Create account, "Already have an account? Sign in" | NO |
| Emulator UI | `monkey` → "**No activities found to run**, monkey aborted" (`emulator-launch-attempt.txt`) | NOT TESTED — app not installed |
| Authenticated child dashboard / remote-assistance screens | requires sign-in (forbidden) | **NOT TESTED — no session on device; login prohibited by constraints** |

Child Mode copy mentions "approve pairing or **assistance** requests" — the assistance concept exists, but no recording/capture affordance anywhere reachable.

## OS capability probe (Task 4 — OS tool, unrelated to the app)

| Device | Command | Result | Label |
|---|---|---|---|
| realme API 31 | `adb shell screenrecord --time-limit 5 /sdcard/qa_os_probe.mp4` | **Blocked by ROM**: `/system/bin/sh: screenrecord: inaccessible or not found`; `/system/bin/screenrecord` exists but `ls` → Permission denied (SELinux Enforcing, shell ctx). No file created. | FAIL (OS restriction, not app) — encoder path NOT proven on realme |
| emulator API 37 | same | Worked: 63,064-byte MP4 pulled (`qa_os_probe_emulator.mp4`), header parse: H.264 `avc1` track present, no audio track, mvhd timescale 10000 / duration 19274 ≈ 1.9 s of usable content on a static screen (`osprobe-emulator-mp4header.txt`) | PASS (OS encoder works on emulator) |
| Cleanup | `adb -s emulator-5554 shell rm /sdcard/qa_os_probe.mp4`; verified "No such file or directory" (`osprobe-emulator-cleanup.txt`); `find /sdcard -name '*.mp4' -mtime -2` → empty | deleted | PASS |

## Consent-surface check (Task 5)

| Check | Command | Observed | Label |
|---|---|---|---|
| Projection consent activity | `dumpsys activity activities` before/after window (`consent-activities-start.txt`, `consent30-activities.txt`) | No MediaProjectionPermissionActivity / capture / projection activity ever present; only unrelated WM internals ("mCapturedLeash" animation surfaces) | PASS (no consent dialog) |
| 30s logcat window (app foreground, walking role-select + sign-in screens) | `logcat -c` … UI actions … `logcat -d` → `consent30-logcat-raw.txt` (3,879 lines) | **0 hits** for mediaprojection/virtualdisplay/MediaProjectionManager/ScreenCapture/ProjectionService. First 17s window (`consent-logcat-raw.txt`) had 3 hits, all from the **system** ColorOS app `OplusScreenRecorder` (rotation listener, pid 8784) — not our package | PASS |
| Remote-assistance screens during window | — | NOT TESTED (behind sign-in) | NOT TESTED |

## Resource / cleanup check (Task 6)

| Check | Command | Observed | Label |
|---|---|---|---|
| realme app external dir | `ls -laR /sdcard/Android/data/com.parentcontrol.parent_control/` | **No such directory** — app never wrote external files | PASS |
| realme media dirs | `ls /sdcard/Movies`, `/sdcard/DCIM`, `find /sdcard -name '*.mp4' -mtime -1` | Only pre-existing personal folders (Instagram/Telegram/WhatsApp/Camera); **zero mp4s created in last 24h**; none attributable to this package (`resource-cleanup-check-realme.txt`) | PASS |
| emulator | same set | no app data dir; Movies/DCIM empty; no mp4s (`resource-cleanup-check-emulator.txt`) | PASS |

## Surprises / caveats

1. **Parent device has no app.** emulator-5554 contains zero third-party packages — the "parent side" of the fleet is unverified live; the brief's device map is wrong on this point.
2. **Child app is signed out** (fresh install today 12:55, firstInstall=lastUpdate) — authenticated surfaces (child dashboard, assistance-request flow, any hidden recording entry point) are NOT TESTED live.
3. **Device in active use**: during monitoring, a third-party secure app (`co.griffin.ieouv`) took foreground (its FLAG_SECURE window even blocked screencap → 0-byte capture, `realme-19-probe.png`), and the parent-control app was force-stopped by system/user at 14:35 (seen in WindowManager logs). All my actions were read-only; I left the user's foreground app untouched.
4. **screenrecord blocked on realme** — a future MediaProjection feature must be validated with an in-app test build on this device; the OS shell path cannot pre-prove the encoder.
5. flutter_webrtc caveat: no binary/dex grep was used as evidence; the permission-list and runtime-service findings above are independent of plugin-bundled classes.

## Acceptance summary (recording feature)

| Criterion | Result |
|---|---|
| App records actual screen content on device | **FAIL — not implemented (no capability, no UI, no consent path, no output files)** |
| Prior audits' "NOT IMPLEMENTED" conclusion | **CONFIRMED by live on-device evidence** |
