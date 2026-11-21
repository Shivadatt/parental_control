# 03 — Parent Functional Test Matrix

**Date:** 2026-11-21  
**Device:** Pixel 9a emulator (`emulator-5554`), Android 17 / API 37  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Legend:** N normal · I initial · E empty · L loading · ER error · V validation · P permission · S stale · BG background/resume · R repeat  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED / PLATFORM_LIMITED

---

## 1. Executed parent tests

| Test ID | Feature | Scenarios executed | Expected | Actual | Status | Evidence |
|---|---|---|---|---|---|---|
| P01-T1 | Splash/session restore | I, BG | Existing session restores to parent shell | Parent app resumed signed in; no login prompt | PASS | Parent relaunch observation |
| P07-T1 | Parent shell/navigation | N | Shell with Dashboard/Devices/Alerts/Settings | All four tabs rendered | PASS | Dashboard dump |
| P08-T1 | Dashboard family summary | N | Family name and summary | `demo` shown | PASS | Dashboard dump |
| P09-T1 | Dashboard device cards | N | Device card data | Two `realme RMX2161` cards | PASS | Dashboard dump |
| P10-T1 | Dashboard presence | N, S | Healthy child shown Online | Active row shown **Offline**, 187 h old | **FAIL (P1)** | Dashboard dump |
| P11-T1 | Dashboard quick links | N | Family link opens Family | Family page opened | PASS | Family dump |
| P12-T1 | Family overview | N | Name/owner/created/retention | `demo`, owner `ankit`, Oct 29, 30/90 days | PASS | Family dump |
| P13-T1 | Guardians | N | Guardian list | `ankit (you)` owner active | PASS | Family dump |
| P14-T1 | Children | N | Child membership list | `ankit1`, Active, Child, joined Oct 29 | PASS | Family dump |
| P15-T1 | Linked devices | N | Device list | `realme RMX2161`, Offline | PASS | Family dump |
| P16-T1 | Pending pairing | E | Empty state | “No pairing request is waiting…” | PASS | Family dump |
| P17-T1 | Retention display | N | 30-day location / 90-day usage | Correct values shown | PASS | Family dump |
| P22-T1 | Device list | N | Device rows | Revoked + Offline rows | PASS | Devices dump |
| P23-T1 | Device detail identity | N | Model/Android/app version/last seen/battery | `realme RMX2161`, Android 12, 1.0.0, last seen Nov 13, 100% charging | PASS | Detail dump |
| P24-T1 | Device online/offline | N, S | Online for a running child | Offline | **FAIL (P1)** | Detail dump |
| P25-T1 | Last seen | N, S | Recent heartbeat | 186–187 h old | **FAIL (P1)** | Detail + dashboard |
| P26-T1 | Policy summary | N | One consistent version | Devices list v2; detail/dashboard v4 | **FAIL (P2)** | Devices vs detail |
| P27-T1 | Policy acknowledgement | N | Saved-but-unacked state explained | “Waiting for device”, “Not yet acknowledged”, v4 | PASS | Detail dump |
| P33-T1 | Enforcement truthfulness | N | No false “blocked” claim | “Not enforced”; Device Owner banner | PASS | Detail dump |
| P45-T1 | Alerts list/filter | N, E | Alerts and empty filter states | 0 unacknowledged, 2 total, low-battery warning rows | PASS | Alerts dump |
| P63-T1 | Loading/error/retry | S, ER | No infinite spinner; useful offline/stale text | Offline/stale data clearly labelled; no frozen spinner | PASS | Dashboard/Devices |
| P29-T0 | Recovery UI presence | N | Recovery entry visible | “Start device recovery” shown (not pressed) | PASS (presence only) | Detail dump |
| P28-T0 | Revoke UI presence | N | Revoke entry visible | “Revoke device” and warning shown (not pressed) | PASS (presence only) | Detail dump |

### Defect rows directly exercised

| Test ID | Feature | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| P10-T2 | Stale presence | S | Stale data distinguished from live | Offline label and old timestamp shown | PASS (honesty) / FAIL (freshness) |
| P22-T2 | Duplicate device rows | R | Only current device | Revoked row still listed | **FAIL (P2)** |

---

## 2. Not-tested parent features

The following feature rows were **not executed** in this phase. Navigation beyond the initial Dashboard/Devices/Detail/Family/Alerts pass was refused by the execution policy, and credential entry was not performed.

| Test ID | Feature | Reason | Status |
|---|---|---|---|
| P02-T1 | Configuration screen | Backend already configured; screen not opened | NOT_TESTED |
| P03-T1 | Role selection | Not opened | NOT_TESTED |
| P04-T1 | Login | Existing session; no manual password entry | NOT_TESTED |
| P05-T1 | Register | Not opened | NOT_TESTED |
| P06-T1 | Verify email | Not opened | NOT_TESTED |
| P19-T1 | Pairing requests list | Not opened | NOT_TESTED |
| P30-T1 | App restrictions list | Screen not opened | NOT_TESTED |
| P34-T1 | Quota status | Screen not opened | NOT_TESTED |
| P35-T1 | Screen time today | Screen not opened | NOT_TESTED |
| P36-T1 | Screen time 7-day | Screen not opened | NOT_TESTED |
| P39-T1 | Location latest | Screen not opened | NOT_TESTED |
| P40-T1 | Location history | Screen not opened | NOT_TESTED |
| P41-T1 | Location refresh/permission | Screen not opened | NOT_TESTED |
| P42-T1 | Safe zones list | Screen not opened | NOT_TESTED |
| P44-T1 | Safe-zone alert state | Not observed | NOT_TESTED |
| P46-T1 | Alert acknowledge | Would write server state | NOT_TESTED |
| P47-T1 | Realtime alerts | No new event; no subscription observation | NOT_TESTED |
| P50-T1 | Assistance pending state | Requires request | NOT_TESTED |
| P51-T1 | Audio playback | Requires session | NOT_TESTED |
| P52-T1 | Video playback | Requires session | NOT_TESTED |
| P53-T1 | End/reconnect | Requires session | NOT_TESTED |
| P54-T1 | Audit log list | Screen not opened | NOT_TESTED |
| P55-T1 | Audit filters/paging | Screen not opened | NOT_TESTED |
| P56-T1 | Settings/profile | Screen not opened | NOT_TESTED |
| P61-T1 | Notification preferences | Screen not opened | NOT_TESTED |
| P62-T1 | Account/privacy | Screen not opened | NOT_TESTED |
| P64-T1 | Route authorization | No unauthorized navigation test | NOT_TESTED |

---

## 3. Authorization-required parent actions

These were identified and deliberately **not executed** because they would create, modify or delete production state.

| Test ID | Feature | Why gated | Status |
|---|---|---|---|
| P18-T1 | Link child / create code | Creates pairing request | AUTHORIZATION_REQUIRED |
| P20-T1 | Redeem code | Creates membership | AUTHORIZATION_REQUIRED |
| P21-T1 | Unlink child | Destroys relationship | AUTHORIZATION_REQUIRED |
| P28-T1 | Revoke device | Invalidates credential | AUTHORIZATION_REQUIRED |
| P29-T1 | Recover device | Unlinks/revokes device | AUTHORIZATION_REQUIRED |
| P31-T1 | Save policy | Writes policy/command | AUTHORIZATION_REQUIRED |
| P32-T1 | Sync now | Writes command | AUTHORIZATION_REQUIRED |
| P37-T1 | Daily limit edit | Writes policy | AUTHORIZATION_REQUIRED |
| P38-T1 | Bedtime edit | Writes policy | AUTHORIZATION_REQUIRED |
| P43-T1 | Safe-zone CRUD | Writes zone rows | AUTHORIZATION_REQUIRED |
| P48-T1 | Request audio | Creates session | AUTHORIZATION_REQUIRED |
| P49-T1 | Request video | Creates session | AUTHORIZATION_REQUIRED |
| P57-T1 | Sign out | Changes session; requires re-login | AUTHORIZATION_REQUIRED |
| P58-T1 | Retention settings | Writes family settings | AUTHORIZATION_REQUIRED |
| P59-T1 | Data export | Generates exported data | AUTHORIZATION_REQUIRED |
| P60-T1 | Delete account | Destructive | AUTHORIZATION_REQUIRED |

---

## 4. Parent matrix verdict

**21 features exercised, 17 pass, 4 fail.**  
Failures: P10/P24/P25 (P1 stale presence) and P26 (P2 policy-version inconsistency). P22 also carries the P2 duplicate revoked row.

No parent action that writes production state was executed.
