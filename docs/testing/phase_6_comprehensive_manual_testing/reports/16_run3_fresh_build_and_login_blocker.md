# 16 — Run 3: Fresh Build, Installation, and Login Blocker

Date: 2026-11-23  
Verdict: **BLOCKED — Parent login credential not supplied**

## Repository baseline

| Item | Result |
|---|---|
| Git root | `D:/parentcontrol_app` |
| Branch | `main` |
| HEAD | `80375f518139bf922bc1b66c998691bee912af44` |
| Working tree | Only untracked Phase 6 reports 14 and 15 |
| Source changes | None |
| Git mutations | None |

## Device verification

| Device | Serial | Model | Android | State |
|---|---|---|---|---|
| Child | `5HXWRGQ4IFU8WS4T` | RMX2161 | 12 / API 31 | `device` |
| Parent | `emulator-5554` | AVD `Pixel_9a` (`sdk_gphone64_x86_64`) | 17 / API 37 | `device`, boot complete |

Both devices were authorized and distinguishable. The Pixel app was not installed
before this run; the child had an older build installed.

## Build

FVM-pinned Flutter: **3.44.6 / Dart 3.12.2**. `.tools/live_config.env` exists and
was passed only as a file path; its contents were not printed.

| Step | Result |
|---|---|
| arm64-only build | Success, `cc621bf6…0fc5ff5a`, 173,158,306 bytes, 09:58:09 |
| universal build | **Success**, all ABIs |
| Exact universal command | `.fvm/flutter_sdk/bin/flutter.bat build apk --debug --dart-define-from-file=.tools/live_config.env` |
| Universal APK path | `build/app/outputs/flutter-apk/app-debug.apk` |
| Universal SHA-256 | `7934cb34adb7d793dbfbdb349189ada3c536e08a096baaafdf425c9c79c1456c` |
| Universal size | 243,948,399 bytes |
| Creation timestamp | 2026-11-23 10:02:23 +0530 |
| Package/version | `com.parentcontrol.parent_control`, 1.0.0 (code 1) |

## Installation

| Device | Command | Timestamp | Result |
|---|---|---|---|
| Child | `adb -s 5HXWRGQ4IFU8WS4T install -r build/app/outputs/flutter-apk/app-debug.apk` | 10:03:48 | Success, in place |
| Parent | `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk` | 10:05:29 | Success, in place |

Verified installed identity:

- Child: `primaryCpuAbi=arm64-v8a`, versionName 1.0.0, versionCode 1.
- Parent: `primaryCpuAbi=x86_64`, versionName 1.0.0, versionCode 1.

No uninstall, data clear, downgrade, or old APK was used.

## Launch and login

| Device | Observed | Status |
|---|---|---|
| Parent | Role selection screen: “How will you use Parent Control?” with Parent/Child Sign in and Create account | PASS (launch) |
| Child | Home loaded, still signed in as `ankit1`, Linked, Registered, device RMX2161 | PASS (session preserved) |

The Parent install had no persisted session. Continuing requires the Parent QA
password. The Phase 6 instruction says the password is supplied by the Project Owner
“in the conversation”, but no password value exists in the conversation. No password
was guessed, read from a credential file, printed, or changed.

## Child state observed

Child home at 10:08:

- Linked child account `ankit1`, family `demo`.
- Device **Offline**.
- Last seen 232 h ago, Nov 13, 2026 5:23 PM.
- Policy version **v4**.
- Device admin only; app blocking unavailable.

This is consistent with the previously reported credential/heartbeat defect, but the
Parent side could not be authenticated to complete E2E verification in this run.

## Hard stop

The task requires both accounts to sign in and Parent–Child testing to be performed.
Without the Parent password, the following cannot be executed safely:

- Parent dashboard/device/family/policy screens.
- Parent–Child heartbeat, last-seen, policy, usage, location, alert synchronization.
- E2E-001–004 from the Parent side.
- Parent network/lifecycle tests.
- Full regression and automated verification tied to a signed-in parent.

No account, credential, family, device, or database recovery was attempted.

## Required owner input

Provide the Parent QA password through an approved secret-input mechanism, or
authorize a different non-destructive session-recovery path. Do not include the
password in a report or command output.
