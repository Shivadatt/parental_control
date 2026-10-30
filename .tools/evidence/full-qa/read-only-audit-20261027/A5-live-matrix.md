# A5 — LIVE-DEVICE READ-ONLY AUDIT MATRIX (2026-10-27)

Mode: STRICTLY READ-ONLY. No source/migration/manifest/permission changes. No
`pm grant`/`pm revoke`. No `Create linking code` tap. No force-stop, no swipe-away,
no reboot, no provisioning. Credentials never printed.

## Device / build attribution
| Role | Device | OS | versionCode | base.apk SHA-256 |
|------|--------|----|-------------|------------------|
| PARENT | emulator-5554 (Pixel 9a AVD, x86_64) | Android 17 / API 37 | 4001 | `537f2152db8cf50e61f43d005eec2db3d0f69165396ebab1d73adbdca7de3611` |
| CHILD  | realme RMX2161 `5HXWRGQ4IFU8WS4T` (arm64) | Android 12 / API 31 | 2001 | `e5b7355c60b8165d34f53fc0e1785d449748200ffb28e60000a08ddf9684a4b8` |

APKs pulled to `base_emulator_5554.apk` / `base_realmes_RMX2161.apk` and hashed. Both
devices unlocked, app foreground at start (`A5-00_*_baseline.png/.xml`).

## §4 LINKING / PAIRING
| # | Test | Verdict | Evidence / observation |
|---|------|---------|------------------------|
| 1 | Parent login + family + dashboard devices | **PASS** | Signed in; header "QA Family A". Dashboard lists 2 devices, BOTH "Revoked" (QA Test Phone A "Last seen 20 h ago… Fully managed (Device Owner) · Policy v1 Enforced"; QA Phone A "Never reported · Not enforced · Policy v2 Waiting for device"). `A5-00_emulator_baseline.*` |
| 2 | "Link a child" QR preview LIVE + caption | **PASS** | `dumpsys media.camera` shows an OPEN active client `Camera ID 10, State 2, PID 15419, com.parentcontrol.parent_control` (CONNECT 18:33:02). Screenshot renders a real camera scene (room + checkerboard). Caption **"Point the camera at the child's QR code" IS visible** in the installed v4001 (brief expected it missing — it is present). Two 3s-apart frames are pixel-identical only because the emulator feeds a static synthetic scene; liveness proven by open client + rendered scene. `A5-01_emulator_pairdevice.*`, `A5-02_emulator_scan_A/B.png` |
| 3a | Manual invalid 8-char code | **PASS** | "ZZZZZZZZ" → red banner title **"Code not recognised"**, msg "The linking code is not valid. Ask the child to generate a fresh code and enter all 8 characters." Truthful; no existence/expiry leak. `A5-03d_invalid8_banner.*` |
| 3b | Malformed code (wrong length + space/dash) | **PASS** | "AB-12 3" → normalized to "AB123" → client-side banner title **"Check the code"**, msg "Enter the 8-character code shown on the child device". Truthful (does not hit server / does not burn budget). `A5-06b_banner_top.*` |
| 3c | Parent 5-per-10-min budget → 429 | **PASS** | After repeated valid-format attempts: banner title **"Too many attempts"**, msg **"Too many linking attempts. Wait a few minutes and try again. Wait before trying again; the server throttles attempts."** It gives only a VAGUE "a few minutes" — NO exact retry timestamp/countdown. `A5-08_rate_limited_429.*` |
| 4 | Child "Set up this phone" budget state | **PASS** | Child already signed in, on setup screen, showing banner **"Action failed — You have created too many linking codes today. Try again later."** Wording gives NO retry time ("later"). `A5-09_child_state.*`, `A5-00_realme_baseline.*` |
| 5 | "Expires Just now" future-timestamp defect | **NOT TESTED** | Code defect CONFIRMED statically: `lib/core/utils/formatters.dart:21` `if (difference.isNegative) return 'Just now';` → any FUTURE timestamp renders "Just now". But no live surface exists to display it: no linking code created (budget exhausted), no pending request, no remote session. Parent redeem page uses `formatDateTime` for "Expires" (correct). All observed relative times are past ("Updated 44 min ago", "Requests refreshed Just now"). Cannot confirm/deny on-screen without a future-dated value. |
| 6 | Pending-approval UI | **NOT TESTED** | Child Requests tab: **"No pending requests"** — no `pending_child` request exists from earlier runs. Nothing to observe (approve/decline not touched). `A5-11_child_requests.*` |
| 7 | Existing-link reuse | **PASS** | Parent dashboard shows devices but ALL "Revoked" (no active link). Child home shows "Link this phone / Set up linking" = unlinked. `A5-00_emulator_baseline.*`, `A5-10_child_home.*` |

## §5 CAMERA / MICROPHONE (realme)
Permission state (verified, not changed): `CAMERA granted=true (USER_SET)`,
`RECORD_AUDIO granted=true (USER_SET)`.
| # | Test | Verdict | Observation |
|---|------|---------|-------------|
| 8 | Camera + mic self-test (rear/front live, frame counter, privacy indicator) | **NOT TESTED** | The "Camera and microphone test" entry is ABSENT from the installed child build (v2001). Child Settings tab shows only Android control / Background protection / Account actions — no media-test card (feature exists in current source `child_settings_tab.dart:196` but postdates the installed APK). Cannot run. Prior run recorded PASS-LIVE on a newer build (docs row 28). `A5-12_child_settings.*`, `A5-12b_child_settings_scroll.*` |
| 9 | "Recording" row wording | **NOT TESTED** | Sheet unreachable in installed build. Current source `media_self_test_sheet.dart:308` = "Not available in this app" (not the old "Off — preview only"), but not confirmable live. |

## §4 BACKGROUND (realme)
| # | Test | Verdict | Observation |
|---|------|---------|-------------|
| 10 | Guardian/Location service + notification while backgrounded | **NOT TESTED** | After HOME (child backgrounded, launcher resumed): `dumpsys activity services com.parentcontrol.parent_control` = **"(nothing)"** — no GuardianService/LocationTrackingService. No ongoing parentcontrol notification in `dumpsys notification`. Process PID 21312 alive but cached ("hvy … LAST"), then FROZEN by OEM. Consistent with UNLINKED state (Settings: "Background protection — Not running — Service: Not running"). Force-stop leg skipped per instruction (destructive). |
| 11 | Heartbeat/telemetry logcat over 60s | **NOT TESTED** | 60s backgrounded capture (`A5-13_heartbeat_60s.txt`): NO app-emitted heartbeat/telemetry/guardian/location lines from PID 21312. Only `OplusHansManager` (Realme power mgr) events freezing the app: "pkg=com.parentcontrol.parent_control F enter() / freeze". Generic "Telemetry SDK 6.0" lines are PID 4818 (not the app). No heartbeat observable while unlinked. |

## §6 DEVICE OWNER / APP BLOCKING
| # | Test | Verdict | Observation |
|---|------|---------|-------------|
| 12 | Device-owner state + parent App-restrictions honesty | **PASS** | `dpm list-owners` = **"no owners"**; `dumpsys device_policy` provisioningState 0 with ENABLED DEVICE ADMIN `com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver` (admin-only, NOT Device Owner). Parent UI (device detail) states honestly: **"App suspension is not supported here — This device is not a fully managed Device Owner device. Parent Control cannot suspend or block apps until the phone is provisioned as fully managed. A policy flag on its own does not block an app."** (Dedicated AppRestrictionsPage not separately reachable: both devices revoked.) Child Settings corroborates: "Device admin only — app blocking is not available". `A5-15_devdetail.*` |
| — | Screen recording UI | **CONFIRMED ABSENT** | No recording UI in any visited screen; child Settings footer: "This app never records audio or video, takes screenshots, reads messages, or captures passwords." |

## NEW DEFECT (this run)
**DUP-429 double guidance** — the rate-limit banner concatenates server text and client
guidance into a redundant, awkwardly repeated instruction: "Too many linking attempts.
Wait a few minutes and try again. **Wait before trying again; the server throttles
attempts.**" Two overlapping "wait" sentences; and neither gives a concrete retry time.
Screenshot: `A5-08_rate_limited_429.png` (XML `A5-08_rate_limited_429.xml`).

## Notes / discrepancies vs brief
- Brief cited `lib/utils/formatters.dart`; actual path is `lib/core/utils/formatters.dart`.
- Brief expected the QR caption to be MISSING in the installed build; it is PRESENT (v4001).
- Child "Expires Just now" could not be exercised live because no future-dated value is
  reachable without creating a code (budget exhausted) or a pending request (none).
