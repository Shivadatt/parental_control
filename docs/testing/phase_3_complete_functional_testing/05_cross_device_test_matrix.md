# 05 — Cross-Device Test Matrix

**Date:** 2026-11-21  
**Parent:** Pixel 9a emulator (`emulator-5554`)  
**Child:** Realme RMX2161 (`5HXWRGQ4IFU8WS4T`)  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED

---

## 1. Cross-device tests

| Test ID | Feature | Parent observation | Child observation | Expected | Status |
|---|---|---|---|---|---|
| X01 | Family membership | `demo`, owner `ankit`, child `ankit1` | Family `demo` | Both resolve the same family | PASS |
| X02 | Child role | Family page: `ankit1` role Child | Child shell tabs | Parent and child agree | PASS |
| X03 | Linked device identity | `realme RMX2161`, Android 12, app 1.0.0 | Device name displayed in shell | Same device | PASS |
| X04 | Device presence | Offline, last seen Nov 13 | FGS running, network connected | Online within heartbeat window | **FAIL (P1)** |
| X05 | Last-seen freshness | 186–187 h old | “Updated 2 d ago” | Both current | **FAIL (P1)** |
| X06 | Heartbeat/telemetry | Device row not updating | Service running, TLS established | Heartbeat accepted and visible | **FAIL (P1)** |
| X07 | Saved vs applied policy | Detail: v4 saved, waiting; list: v2 applied | Policy presentation not opened | Explicit saved/applied distinction | **FAIL (P2)** |
| X08 | Enforcement state | “Not enforced”; Device Owner banner | Not managed | Honest on both | PASS |
| X09 | Permission state | Parent shows permission gaps | Child warning contradicts Android grant | Accurate on both | **FAIL (P2)** |
| X10 | Alerts | 2 acknowledged low-battery alerts | No new event generated | Consistent, no fabricated alert | PASS (display) / NOT_TESTED (generation) |
| X11 | Location | Not opened | Location service not running | Fresh location visible if enabled | BLOCKED |
| X12 | Usage/screen time | Not opened | Usage access granted | Fresh usage visible | BLOCKED |
| X13 | Remote assistance | Not requested | Not consented | Consent-gated media only | AUTHORIZATION_REQUIRED |
| X14 | Device revocation visibility | Revoked row still listed | N/A | Only active device in current list | **FAIL (P2)** |
| X15 | Notification/service visibility | N/A | Guardian notification visible | Visible while service runs | PASS |

---

## 2. Cross-device consistency summary

| Area | Consistent? | Notes |
|---|---|---|
| Identity/family | Yes | Same `demo` family and `ankit1` child |
| Presence | No | Child alive; parent shows Offline |
| Freshness | No | Both sides stale, but parent value is much older |
| Policy | No | Different version concepts/surfaces |
| Permissions | No | Android grant vs app warning |
| Enforcement messaging | Yes | Both say not managed/not enforced |
| Alerts | Yes for existing data | No new alert was generated |
| Location/usage | Unknown | Parent screens not opened; child uploads blocked |
| Remote assistance | Unknown | Not authorized/tested |

---

## 3. Cross-device verdict

**PASS:** identity, family, role, enforcement honesty, guardian notification.  
**FAIL:** presence, last-seen, heartbeat, policy-version presentation, permission consistency, revoked-row visibility.  
**BLOCKED/AUTH REQUIRED:** location, usage, remote assistance, new alerts.

The cross-device layer is not functional for the core parent-visibility promise because of the P1 heartbeat failure.
