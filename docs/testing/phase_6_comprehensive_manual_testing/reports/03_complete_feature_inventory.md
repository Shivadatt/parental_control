# 03 — Complete Feature Inventory and Status

Feature inventory was reconciled from application routes, tabs, visible controls,
Edge/RPC-backed screens, and the Phase 3 inventory. Every discovered feature area
has an explicit status. A control that was observed but not exercised is not PASS.

## Summary

| Area | Features | PASS | FAIL | BLOCKED | NOT TESTED |
|---|---:|---:|---:|---:|---:|
| Parent | 50 | 29 | 4 | 1 | 16 |
| Child | 19 | 10 | 6 | 1 | 2 |
| Parent–Child end-to-end | 17 | 5 | 5 | 3 | 4 |
| **Total** | **86** | **44** | **15** | **5** | **22** |

Manually tested (PASS + FAIL): **59 / 86 (68.6%)**.

## Parent application

| ID | Feature | Status | Evidence |
|---|---|---|---|
| P01 | Splash and persisted-session restore | PASS | `logs/parent_after_restart_loaded.xml` |
| P02 | Login with QA credentials | NOT TESTED | No password supplied; session already active |
| P03 | Registration | NOT TESTED | Not required; account creation prohibited |
| P04 | Role selection | NOT TESTED | Session already past role selection |
| P05 | Configuration/backend-not-configured screen | NOT TESTED | Backend configured |
| P06 | Dashboard load | PASS | `screenshots/parent/16_dashboard.png` |
| P07 | Dashboard refresh | PASS | `logs/parent_dashboard2.xml` |
| P08 | Dashboard offline banner | PASS | `screenshots/parent/34_dashboard_offline.png` |
| P09 | Dashboard reconnection | PASS | `screenshots/parent/35_dashboard_reconnected.png` |
| P10 | Device list | PASS | `screenshots/parent/01_devices.png` |
| P11 | Online/offline and last-seen accuracy | FAIL | Both rows Offline/Revoked; E2E-001 |
| P12 | Revoked-device visibility | FAIL | Duplicate rows for the same child/device; E2E-002 |
| P13 | Device detail identity | PASS | `logs/parent_device_detail.xml` |
| P14 | Policy version consistency | FAIL | List v2 vs dashboard/detail v4; E2E-003 |
| P15 | Device permission summary | FAIL | Notifications shown Granted; OS permission absent |
| P16 | Recent command history | PASS | `logs/parent_after_safezones.xml` |
| P17 | App restrictions overview | PASS | `screenshots/parent/18_app_restrictions.png` |
| P18 | App restriction edit/enforce | BLOCKED | Child offline; no Device Owner; no propagation path |
| P19 | Screen-time overview | PASS | `screenshots/parent/20_screen_time.png` |
| P20 | Usage stale/empty state | PASS | "No usage reported yet"; stale >24 h |
| P21 | Screen-time policy save | NOT TESTED | Avoided changing live child restriction |
| P22 | Bedtime picker open/cancel | PASS | `screenshots/parent/22_bedtime_picker.png` |
| P23 | Location latest fix | PASS | `screenshots/parent/23_location.png` |
| P24 | Stale-location warning | PASS | STALE banner, 8-day-old fix |
| P25 | Location history 24 h / 7 d filters | PASS | `logs/parent_location_7d.xml` |
| P26 | Safe-zone list | PASS | `screenshots/parent/25_safe_zones.png` |
| P27 | Safe-zone create validation | PASS | Required field/lat/long/radius errors |
| P28 | Safe-zone create/save | NOT TESTED | Avoided creating live zone |
| P29 | Safe-zone edit/delete | NOT TESTED | Avoided changing live zone |
| P30 | Safety-alert list | PASS | `screenshots/parent/28_safety_alerts.png` |
| P31 | Alert severity filters and empty state | PASS | Info/Critical empty messages |
| P32 | Alert acknowledge | NOT TESTED | All existing alerts already acknowledged |
| P33 | Remote-assistance session list | PASS | 11 sessions visible |
| P34 | Remote-session detail | PASS | `logs/parent_remote_session_detail.xml` |
| P35 | Request audio/video assistance | NOT TESTED | Avoided unsolicited live request |
| P36 | Family details | PASS | `screenshots/parent/11_family_details.png` |
| P37 | Pairing requests empty state | PASS | "No pairing request is waiting" |
| P38 | Link a child / create code | NOT TESTED | Would create live pairing state |
| P39 | Audit and retention screen | PASS | `screenshots/parent/12_audit_log.png` |
| P40 | Save retention | NOT TESTED | Avoided changing family retention |
| P41 | Purge old data | NOT TESTED | Destructive; prohibited |
| P42 | Account/settings display | PASS | Parent email/role/family verified |
| P43 | Local notification toggle | PASS | Off/on exercised; local-only |
| P44 | Location reminder toggle | NOT TESTED | Not exercised |
| P45 | Export account data | NOT TESTED | Not exercised |
| P46 | Delete account | NOT TESTED | Destructive; prohibited |
| P47 | Sign out | NOT TESTED | No password to sign back in |
| P48 | Back navigation | PASS | Detail → list → tab navigation |
| P49 | Loading/empty/error states | PASS | Splash, offline, empty filters, stale data |
| P50 | Restart with session persistence | PASS | Force-stop/relaunch retained session |

## Child application

| ID | Feature | Status | Evidence |
|---|---|---|---|
| C01 | Child home | PASS | `screenshots/child/04_home_loaded.png` |
| C02 | Identity, family, device display | PASS | `logs/child_home_loaded.xml` |
| C03 | Online status | FAIL | Shows Offline despite active network/service |
| C04 | Manual refresh recovery | FAIL | Refresh does not restore authentication/status |
| C05 | Rules and permissions screen | PASS | `screenshots/child/08_rules.png` |
| C06 | Policy version display | PASS | "Version 4 · received Nov 17" |
| C07 | Non-enforceable Device Owner warning | PASS | Clear warning shown |
| C08 | Requests empty state | PASS | "No pending requests" |
| C09 | Settings/account display | PASS | `screenshots/child/05_settings_after_install.png` |
| C10 | Android permission reporting | FAIL | Notifications "Granted" while OS grant absent |
| C11 | Background service status | PASS | Running with visible notification |
| C12 | Heartbeat/device credential | FAIL | "Device credentials are not valid" |
| C13 | Usage upload | FAIL | Upload failed; no recent usage on parent |
| C14 | Location service/sharing | FAIL | Initially reported service not running |
| C15 | Camera/microphone self-test | NOT TESTED | Not exercised |
| C16 | Device-admin capability display | PASS | "Device admin only" |
| C17 | Relaunch after install/session persistence | PASS | Session preserved, app loaded |
| C18 | Explicit force-stop restart | BLOCKED | Physical device lost USB authorization |
| C19 | Sign out / unlink | NOT TESTED | Destructive; prohibited |

## Parent–Child end-to-end

| ID | Workflow | Status | Evidence |
|---|---|---|---|
| E01 | Both accounts have active sessions | PASS | Pre-existing sessions on both devices |
| E02 | Child/device visible to parent | PASS | Two device rows visible |
| E03 | Heartbeat brings child Online | FAIL | Child and parent remain Offline |
| E04 | Last-seen timestamp updates | FAIL | Stuck at Nov 13, ~190 h old |
| E05 | Policy version consistent everywhere | FAIL | Device list v2 vs detail/dashboard v4 |
| E06 | Policy save propagates to child | NOT TESTED | No live policy mutation performed |
| E07 | App restriction propagation | BLOCKED | Child credential invalid; no Device Owner |
| E08 | Bedtime/schedule propagation | BLOCKED | Credential invalid; save not exercised |
| E09 | Usage upload visible to parent | FAIL | No usage uploaded; stale data |
| E10 | Location upload/history | FAIL | One stale fix, no 7-day history |
| E11 | New alert synchronization | NOT TESTED | Existing alerts only |
| E12 | Parent sign-out/sign-in | NOT TESTED | No password supplied |
| E13 | Child restart then resync | BLOCKED | USB authorization lost |
| E14 | Parent restart then resync | PASS | Session and dashboard restored |
| E15 | Network loss handling | PASS | Offline banner + cached data |
| E16 | Network restore | PASS | Banner cleared after reconnect |
| E17 | Duplicate-event check | NOT TESTED | No successful upload path |
