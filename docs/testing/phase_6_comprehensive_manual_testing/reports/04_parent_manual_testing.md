# 04 — Parent Manual Testing

Device: Pixel_9a emulator (`emulator-5554`), Android 17 / API 37  
Role: Parent (`ankit@gmail.com`)  
Build: fresh x86_64 debug APK, SHA-256 `7ed729f5d00b146f6840a00e382b459a496887e2789e614d208144741f93ca72`

## Session and launch

| Test | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| P01 | Force-stop; relaunch | Session restored, dashboard | Splash "Checking your session", then dashboard | PASS |
| P02 | Login with QA password | Credentials accepted | Not executed; password not supplied | NOT TESTED |
| P47 | Sign out | Return to login | Not executed; would strand session | NOT TESTED |

## Dashboard and devices

| Test | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| P06/P10 | Open Dashboard, Devices | Family and devices load | `demo`; two RMX2161 rows | PASS |
| P07 | Tap refresh | Data reloads | "Updated Just now" | PASS |
| P08 | Disable Wi-Fi/data, refresh | Offline notice, cached data | "You are offline… Showing the last data" | PASS |
| P09 | Restore network, refresh | Notice clears | Dashboard reloaded without offline banner | PASS |
| P11 | Inspect status/last seen | Online when heartbeat current | Both rows Offline/Revoked; last seen 190–197 h | FAIL |
| P12 | Inspect revoked row | Revoked device not presented as active duplicate | Same child/device appears twice | FAIL |
| P13 | Open offline device | Identity detail | Name, Android 12, app 1.0.0, battery 100% | PASS |
| P14 | Compare policy versions | Same version on list/detail/dashboard | List v2; detail/dashboard v4 | FAIL |
| P15 | Inspect device permissions | Match actual Android grants | Notifications shown Granted; OS grant absent | FAIL |
| P16 | Inspect recent commands | Delivery history only | Apply policy queued/succeeded entries | PASS |
| P48 | Back navigation | Return to device list | Worked via system back | PASS |

## Restrictions, screen time, location

| Test | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| P17 | Open App restrictions | Policy state + app list/controls | Version 4, pending acknowledgement; installed apps not reported | PASS (view) |
| P18 | Save app restriction | Child applies after ack | Not executed; child credential invalid/no Device Owner | BLOCKED |
| P19/P20 | Open Screen time | Usage and policy state | Stale upload, "No usage reported yet" | PASS |
| P21 | Modify/save daily limit | New version saved | Not executed to avoid live restriction | NOT TESTED |
| P22 | Open bedtime picker, Cancel | Picker opens; cancel leaves policy | 10:00 PM picker opened and cancelled | PASS |
| P23/P24 | Open Location | Latest fix; stale warning if old | STALE banner, 23.13283, 72.29727, Nov 13 | PASS |
| P25 | Switch 24h/7d history | Empty state per range | "No fixes in last 7 days" | PASS |
| P26 | Open Safe zones | Existing zones | `QA_Test_Zone_Live`, 150 m, Active | PASS |
| P27 | Create safe zone with empty fields | Validation errors | Name, latitude, longitude, radius errors shown | PASS |
| P28/P29 | Create/edit/delete zone | Server change | Not executed to avoid live zone mutation | NOT TESTED |

## Alerts and assistance

| Test | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| P30 | Open Safety alerts | Alert list | 2 acknowledged low-battery warnings | PASS |
| P31 | Filter Info/Critical | Empty-state message | "No alerts with this severity" | PASS |
| P32 | Acknowledge alert | State changes | Not executed; all already acknowledged | NOT TESTED |
| P33 | Open Remote assistance | Session list | 11 sessions | PASS |
| P34 | Open ended session | Consent/status detail, no media | Ended, consent accepted, Close only | PASS |
| P35 | Request audio/video | Child receives request | Not executed; unsolicited live request | NOT TESTED |

## Family, audit, settings

| Test | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| P36 | Family details | Members, devices, actions | Parent owner + child + one linked device | PASS |
| P37 | Pairing requests | Empty state if none | "No pairing request is waiting" | PASS |
| P38 | Link a child | Code generated | Not executed; would create live pairing | NOT TESTED |
| P39 | Audit & retention | Read-only history + retention | Location 30 d, usage 90 d, purge controls | PASS |
| P40/P41 | Save retention / purge | Server change | Not executed; state/destructive | NOT TESTED |
| P42 | Settings account | Email, role, family | `ankit@gmail.com`, Parent, `demo`, Owner | PASS |
| P43 | Toggle local notifications off/on | Local preference only | Toggle changed and restored | PASS |
| P44 | Toggle location reminder | Local preference | Not exercised | NOT TESTED |
| P45/P46 | Export/delete account | Data export or deletion | Not executed | NOT TESTED |

## Layout and states

No clipping or unreachable controls were observed on the 1080×2424 emulator.
Loading, empty, stale, offline and error states rendered correctly where exercised.
The device-detail policy inconsistency and duplicate revoked row are functional
defects, not layout defects.

Evidence: `screenshots/parent/`, `logs/parent_*.xml`.
