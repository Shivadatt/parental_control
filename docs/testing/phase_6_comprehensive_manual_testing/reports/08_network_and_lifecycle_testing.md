# 08 — Network and Lifecycle Testing

All tests were reversible. No app data, secure storage, account, family or pairing
state was cleared.

## Parent emulator

| Test | Action | Result | Status |
|---|---|---|---|
| N-P1 | Wi-Fi and mobile data disabled | Dashboard displayed "You are offline… Showing the last data loaded" | PASS |
| N-P2 | Refresh while offline | Cached data retained; no fabricated success | PASS |
| N-P3 | Wi-Fi and mobile data restored | After refresh, offline banner cleared and dashboard reloaded | PASS |
| L-P1 | Force-stop and relaunch | Splash session check, then dashboard; session persisted | PASS |
| L-P2 | Detail/tab back navigation | Returned to device list and tabs correctly | PASS |
| L-P3 | Screen/emulator remained stable | No crash/ANR observed | PASS |

The offline path is honest: it does not show stale data as live and does not claim a
successful refresh.

## Child device

| Test | Action | Result | Status |
|---|---|---|---|
| L-C1 | Install arm64 APK over existing app | In-place update, data/session preserved | PASS |
| L-C2 | Launch after install | "Checking this phone…" then child home | PASS |
| L-C3 | Refresh child home | Loads, but remains Offline with credential error | FAIL |
| L-C4 | Background protection observation | Service running with visible notification | PASS |
| L-C5 | Heartbeat after install | Credentials invalid; no authenticated heartbeat | FAIL |
| L-C6 | Explicit force-stop/relaunch | Physical device became `unauthorized`; USB dialog could not be accepted via ADB | BLOCKED |

## Child USB authorization incident

The physical device disappeared from ADB during testing and later returned. After
the testing ADB server was restarted, the device returned as `unauthorized`; the
on-device "Allow USB debugging?" dialog requires a physical tap. No attempt was made
to bypass it. This did not affect the already-collected manual evidence, but it
prevented an explicit second restart test (C18/E13).

## Heartbeat behavior

- Child background service was running, so the failure is not simply a stopped
  service.
- Child displayed `Usage upload failed: Device credentials are not valid.`
- Parent last-seen did not move from Nov 13, 2026.
- No duplicate heartbeat events or duplicate successful uploads were observed
  because authenticated uploads never succeeded.

## Untested lifecycle cases

- Child Wi-Fi/mobile toggling: not performed on the real device to avoid disrupting
  the owner's phone without a second authorization window.
- Child reboot: not performed.
- Long-duration background/doze test: not performed.
