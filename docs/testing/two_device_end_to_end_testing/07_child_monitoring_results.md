# 07 — Child Monitoring Results

**Date:** 2026-11-21  
**Child:** Realme RMX2161, Android 12 / API 31  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Summary

| Monitoring area | Result | Label |
|---|---|---|
| Device heartbeat / last seen | Parent shows 186 h old while child runs | FAIL |
| Guardian background service | Foreground service running with visible notification | PASS |
| Permission status | Honest Device Admin/Not enforced; one inconsistent location warning | PASS / FAIL (P2) |
| Location reporting | Location service not running; parent view not opened | BLOCKED |
| Usage / screen time | Not observed on either side | NOT TESTED |
| App activity / installed apps | Not observed | NOT TESTED |
| Safety alerts | Two old acknowledged low-battery alerts displayed | PASS (display) / NOT TESTED (generation) |
| Battery status | Stale 100% charging value | REPORTED |

---

## 2. Heartbeat and last-seen

Child-side evidence:

- `GuardianService` running as a foreground service, notification id `4101`, channel `guardian_status`.
- Service start/restart timestamps indicate it has been alive for about 37 hours.
- App has an established HTTPS connection to Supabase.
- Child Home says “Updated 2 d ago”.

Parent-side evidence:

- Linked device: Offline, “last seen 186 h ago · Nov 13, 2026 5:23 PM”.
- A second revoked row: “last seen 193 h ago · Nov 13, 2026 10:18 AM”.
- Devices tab says “Updated Just now” — that timestamp describes the list refresh, not the device heartbeat.

**Conclusion:** device-authenticated telemetry is not reaching/being accepted by the backend. This is the same P1 as report 06.

---

## 3. Location

- Child Home: “Location sharing is on in this app, but Android location or notification permission is missing. The location service is not running.”
- Android reports fine location and background location as granted.
- `LocationTrackingService` is **not running**.
- The parent Location screen could not be opened before the execution policy refused further UI taps.

No location was read, simulated or published. No map or coordinate is included in this report.

**Labels:** location service — FAIL (not running); parent location view — NOT TESTED; location freshness — NOT TESTED.

---

## 4. Usage and screen time

- Usage access is granted (`GET_USAGE_STATS: allow`).
- No ordinary apps were opened as a controlled usage test because child UI interaction was refused.
- Parent Screen time screen was not opened.
- No usage aggregation or date-boundary check was performed.

**Label:** NOT TESTED.

---

## 5. App activity and installed apps

- `QUERY_ALL_PACKAGES` is granted.
- No app-activity report was inspected on either device.
- No installed-app list was uploaded or validated.

**Label:** NOT TESTED.

---

## 6. Safety alerts

Parent Alerts screen showed:

- “0 unacknowledged · 2 total”
- “Device battery is low (4%)” — Warning — Acknowledged — Nov 3, 2026
- “Device battery is low (1%)” — Warning — Acknowledged — Oct 30, 2026

The alert list, severity, device association and acknowledged state render correctly. No new alert was generated during the test. Offline/permission/geofence alert generation was not exercised.

**Labels:** alert display — PASS; new alert generation — NOT TESTED; offline alert — NOT TESTED.

---

## 7. Battery and device health

- Parent device card/detail reports “100% (charging)” from the stale last report.
- Child battery stats show the app’s foreground service has been active for about 6 h 24 m of recorded stats.
- No live battery sample was taken from the device to compare.
- No low-battery alert was triggered in this pass.

**Labels:** stale battery display — REPORTED; live battery accuracy — NOT TESTED; battery drain — NOT MEASURED.

---

## 8. Monitoring verdict

**FAIL (P1) for heartbeat/last-seen freshness.** The parent cannot rely on the child’s online state.

**PASS for the guardian service and honest enforcement/permission messaging** (with the P2 location-warning inconsistency).

All other monitoring areas are NOT TESTED or BLOCKED and are not counted as passes.
