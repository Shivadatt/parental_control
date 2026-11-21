# 08 — Parent Dashboard and Controls

**Date:** 2026-11-21  
**Parent:** Pixel 9a emulator (`emulator-5554`), Android 17 / API 37  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Screens actually observed

| Screen | How reached | Result |
|---|---|---|
| Dashboard | App launch | PASS |
| Devices tab | Bottom navigation | PASS |
| Device detail | “Open device” on the Offline row | PASS |
| Device detail — manage section | Scrolled | PASS |
| Family | Quick link | PASS |
| Alerts | Bottom navigation | PASS |
| Settings | Attempted bottom navigation | BLOCKED by execution policy |
| Location / Screen time / App restrictions | Not opened | BLOCKED |
| Remote assistance / Safe zones | Not opened | NOT TESTED |

No policy change, revoke, recovery, unlink or pairing action was performed.

---

## 2. Dashboard

Observed content:

- Family label `demo`.
- “Refresh dashboard” action.
- Two device cards, both `realme RMX2161`:
  - Revoked, last seen 193 h ago, Nov 13 10:18 AM, “Device admin only”, “No policy applied yet”.
  - Offline, last seen 186 h ago, Nov 13 5:23 PM, “Not enforced”, “Policy v4 · Waiting for device”.
- Quick links: Family.
- Bottom tabs: Dashboard / Devices / Alerts / Settings.

**Assessment:**

- Correct family and child identity: PASS.
- Current online state: FAIL (Offline while child runs) — P1.
- Duplicate revoked row: FAIL (P2).
- Policy/version presentation: FAIL (P2; see below).
- No crash, overflow, blank screen or infinite spinner: PASS.
- Stale data is labeled with an old timestamp rather than presented as live: PASS.

---

## 3. Devices tab

Observed content:

- “Refresh devices”.
- Revoked row: last seen 193 h ago; “No policy applied yet”.
- Offline row: last seen 186 h ago; **“Policy v2”**.
- “Updated Just now”.
- Bottom navigation.

**Discrepancy:** the same Offline device is shown as **Policy v2** on the Devices list, but **Policy v4** on the Dashboard and device detail. The detail screen reports “Waiting for device / version 4 / Not yet acknowledged”.

This is a consistency defect. It can mislead a parent about which policy the device has actually acknowledged.

---

## 4. Device detail

Observed content:

- Back, device name `realme RMX2161`, Refresh device.
- Device identity: Offline; Platform android; Android 12; App version 1.0.0; last seen 186 h ago; battery 100% (charging); Enforcement mode “Not enforced”.
- Banner: “App suspension is not supported here — This device is not a fully managed Device Owner device… A policy flag on its own does not block an app.”
- Policy: “Waiting for device”; Version 4; Enforcement status “Waiting for device”; Acknowledged “Not yet acknowledged”; explanatory copy that no restriction is active until the device acknowledges.
- Manage actions: App restrictions, Screen time, Location, Safe zones, Safety alerts, Remote assistance.
- Revoke device section with explicit invalidation warning.
- Lost/reinstalled phone recovery section.

**Assessment:** PASS for honest enforcement and acknowledgment reporting. No false claim that apps are blocked. No control was activated.

---

## 5. Family

See report 05. The family, owner, child membership, linked device and pending-pairing state render correctly. The only failures are the stale device state and duplicate revoked row.

---

## 6. Alerts

Observed content:

- “Alerts — 0 unacknowledged · 2 total”.
- Filters All / Info / Warning / Critical.
- Two acknowledged low-battery warnings (Nov 3 and Oct 30, 2026), associated with `realme RMX2161`.

**Assessment:** PASS for rendering, severity, device association and acknowledged state. No new alert was generated.

---

## 7. Controls not exercised

The following were deliberately not changed:

- App restrictions / blocked-app list
- Screen-time limit and bedtime
- Safe zones
- Remote assistance request
- Revoke device
- Device recovery
- Pairing / linking

The brief prohibited policy changes without separate authorization. Read-only inspection of the controls was possible only until the execution policy blocked further navigation.

---

## 8. Parent UI verdict

**PASS** — dashboard, devices, family, alerts and device detail load, remain readable, and do not crash.

**FAIL (P1)** — child is displayed Offline with stale data while it is running.

**FAIL (P2)** — duplicate revoked device row; policy version shown as v2 on the list and v4 on detail/dashboard.

**BLOCKED** — Settings, Location, Screen time, App restrictions and the remaining control screens could not be opened under the execution policy.
