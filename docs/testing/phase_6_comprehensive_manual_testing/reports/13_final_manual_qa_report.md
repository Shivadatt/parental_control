# 13 — Final Manual QA Report (Run 3)

**Verdict: BLOCKED — REQUIRED TESTING COULD NOT BE COMPLETED**

A fresh universal APK was built from HEAD
`80375f518139bf922bc1b66c998691bee912af44` and installed on both devices. The
Parent app launched to role selection with no session; the required Parent QA
password was not present in the conversation. Manual Parent–Child testing cannot
proceed without it.

## Build and installation

| Item | Result |
|---|---|
| Flutter | 3.44.6 (FVM-pinned) / Dart 3.12.2 |
| Build command | `.fvm/flutter_sdk/bin/flutter.bat build apk --debug --dart-define-from-file=.tools/live_config.env` |
| APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| SHA-256 | `7934cb34adb7d793dbfbdb349189ada3c536e08a096baaafdf425c9c79c1456c` |
| Created | 2026-11-23 10:02:23 +0530 |
| Package/version | `com.parentcontrol.parent_control`, 1.0.0 (code 1) |
| Child install | Success, in place, 10:03:48; arm64 |
| Parent install | Success, in place, 10:05:29; x86_64 |
| Old APK used | No |

## Verified device state

| Device | Serial | Model | Android | App state |
|---|---|---|---|---|
| Child | `5HXWRGQ4IFU8WS4T` | RMX2161 | 12 / API 31 | Session preserved, child home |
| Parent | `emulator-5554` | AVD Pixel_9a | 17 / API 37 | Fresh role-selection screen |

## Executed tests this run

| Test | Expected | Actual | Status |
|---|---|---|---|
| Fresh build from current HEAD | APK generated during run | Universal APK created at 10:02:23, hash `7934cb…` | PASS |
| In-place child install | Data/session preserved | Installed; session preserved | PASS |
| In-place parent install | App installs | Installed; no prior session | PASS |
| Parent launch | Parent role | Role-selection screen, no session | PASS (launch only) |
| Parent login | Parent dashboard | Password not supplied | BLOCKED |
| Child launch/session | Child home | Linked, `ankit1`, RMX2161 | PASS |
| Child online status | Online with heartbeat | Offline, last seen 232 h | FAIL (observed) |
| Parent–Child sync | Both directions | Parent not authenticated | BLOCKED |
| E2E-001–004 regression | Retest | Blocked at parent login | BLOCKED |
| Automated suites | Run and record | Not run after blocker | NOT TESTED |

## Feature coverage

The Phase 6 inventory contains **86** features. In this run only launch, install,
child-session and child-status observations were executed. All Parent-side and
Parent–Child features remain **BLOCKED/NOT TESTED** because the Parent account could
not be signed in.

Prior reports `01`–`12` and the earlier findings remain historical evidence for the
earlier completed run at `bbd3c213…`; they are not being represented as evidence for
this fresh-login run.

## Defects observed

- **DEF-601 (previously P1):** child Offline, last seen 232 h, credential failure
  still visible in the child session. Parent-side verification blocked.
- No new P0 was observed.

## Git

| Item | Baseline | Final |
|---|---|---|
| HEAD | `80375f518139bf922bc1b66c998691bee912af44` | unchanged |
| Branch | `main` | unchanged |
| Source diff | None | None |
| Git mutation | None | None |

## Required owner action

Provide the Parent QA password through an approved secret-input mechanism and
re-issue the Phase 6 execution instruction. Do not put the password in chat output
or repository files.
