# 10 — Location, Usage, Screen Time and Alert Tests

**Date:** 2026-11-21  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED / NOT_IMPLEMENTED

---

## 1. Location

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| L01 | Parent latest location | Latest child fix with timestamp | Screen not opened | NOT_TESTED |
| L02 | Parent location history | Time-ranged history | Screen not opened | NOT_TESTED |
| L03 | Location permission state | Accurate on child | Warning contradicts Android grants | **FAIL (P2)** |
| L04 | Location tracking service | Running when sharing enabled | Not running | **FAIL** |
| L05 | Location upload | Fix reaches parent | Auth-blocked | BLOCKED |
| L06 | Stale/fresh labels | Clearly distinguish age | Source supports stale label; live view not opened | NOT_TESTED |
| L07 | Map rendering | Map/tiles | No map dependency or renderer found | NOT_IMPLEMENTED |
| L08 | Safe-zone CRUD | Create/edit/delete | Not executed | AUTHORIZATION_REQUIRED |
| L09 | Geofence alert firing | Enter/exit alert | Not observed | NOT_TESTED |

No location coordinates are included in this report.

---

## 2. Usage and screen time

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| U01 | Usage access | Granted and recognized | `GET_USAGE_STATS: allow` | PASS |
| U02 | Usage upload | Rows reach backend | Device auth blocked | BLOCKED |
| U03 | Parent today usage | Today’s per-app usage | Screen not opened | NOT_TESTED |
| U04 | Parent 7-day usage | Aggregate week | Screen not opened | NOT_TESTED |
| U05 | Daily limit edit | Save quota | Not executed | AUTHORIZATION_REQUIRED |
| U06 | Bedtime edit | Save bedtime | Not executed | AUTHORIZATION_REQUIRED |
| U07 | Quota status panel | Applied/usage/remaining | Screen not opened | NOT_TESTED |
| U08 | Quota enforcement | Suspend at limit | Requires Device Owner | PLATFORM_LIMITED |
| U09 | Bedtime enforcement | Hard suspension | Informational only | NOT_IMPLEMENTED |
| U10 | Timezone/date boundary | Correct local day | Not tested | NOT_TESTED |
| U11 | Stale upload warning | Shown after threshold | Not tested | NOT_TESTED |

---

## 3. Alerts

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| A01 | Parent alert list | Alerts with severity/device/time | 2 acknowledged low-battery warnings | PASS |
| A02 | Alert filters | All/Info/Warning/Critical | Filter controls rendered | PASS (presence) |
| A03 | Alert acknowledge | Server-first ack | Not executed | NOT_TESTED |
| A04 | Realtime delivery | New alert appears live | No new event; no subscription proof | NOT_TESTED |
| A05 | Low-battery generation | Alert below threshold | Old rows display; no new generation test | NOT_TESTED |
| A06 | Offline alert | Device offline alert | No generator observed | NOT_IMPLEMENTED |
| A07 | Permission alert | Permission missing alert | No generator observed | NOT_IMPLEMENTED |
| A08 | Geofence alert | Zone enter/exit | Not observed | NOT_TESTED |
| A09 | Alert empty state | Clear empty message | Not tested | NOT_TESTED |
| A10 | Alert persistence | Survives restart | Existing old alerts still present | PASS (implicit) |

---

## 4. Findings

- The alert list renders correctly and does not fabricate new alerts.
- Both displayed alerts are old and already acknowledged.
- Location and usage are not verifiable while device telemetry is rejected.
- There is no map renderer; location is textual/timestamped only.
- Bedtime is not enforced; emergency pass does not exist.
- No notification/push channel exists, so “realtime” alerts depend on an open app/poll/subscription.

---

## 5. Verdict

**PASS:** usage access, alert list rendering, alert persistence.  
**FAIL:** location service/permission warning.  
**BLOCKED:** location and usage uploads.  
**NOT TESTED:** parent location/usage screens, alert ack, realtime, geofence firing.  
**NOT IMPLEMENTED:** map rendering, offline/permission alert generators, bedtime enforcement, emergency pass.
