# 11 — Defect Register

No code was changed. Severity reflects user impact, not fix effort.

| ID | Severity | Feature | Device | Confirmed? | Suspected layer |
|---|---|---|---|---|---|
| DEF-601 | P1 | Child heartbeat/credential failure | Child RMX2161 | Confirmed | Server credential / Kotlin secure identity |
| DEF-602 | P1 | Revoked device duplicated in parent device list | Parent emulator | Confirmed | Database query / Flutter presentation |
| DEF-603 | P2 | Policy version mismatch (v2 vs v4) | Parent emulator | Confirmed | Flutter list projection / data mapping |
| DEF-604 | P2 | Notifications falsely reported Granted | Child RMX2161 | Confirmed | Flutter permission check / Android API |
| DEF-605 | P2 | Child location service not running despite location grants | Child RMX2161 | Confirmed observation | Permission gating / Android service |
| DEF-606 | P3 | Physical device lost USB authorization during test | Child RMX2161 | Confirmed environment issue | Android ADB authorization |

Totals: **P0 = 0, P1 = 2, P2 = 3, P3 = 1**.

## DEF-601 — Heartbeat/device credential failure

**Reproduction**

1. Install the fresh arm64 build in place on the child phone.
2. Open the app and let it finish “Checking this phone…”.
3. Open Settings → Background protection.
4. Observe “Usage upload failed: Device credentials are not valid.”
5. Refresh child home and parent dashboard.

**Expected:** authenticated heartbeat updates `last_seen_at`; patient shows Online
within the status window; usage/location uploads succeed.

**Actual:** child and parent remain Offline; last-seen stays Nov 13, 2026; no usage
upload; location remains a single stale fix.

**Evidence:** `screenshots/child/07_settings_bottom.png`,
`logs/child_settings_bottom.xml`, `logs/e2e_parent_after_child_refresh.xml`,
`screenshots/parent/34_dashboard_offline.png`.

**Suspected layer:** existing server device row retains the old `secret_hash` while
the reinstalled client generated a new install identity/secret. This is the Phase 4
root cause. Fresh APK installation does not rotate or reconcile the credential.

## DEF-602 — Revoked device duplicated

**Reproduction:** open Parent → Dashboard or Devices.

**Expected:** one coherent active device row; revoked entity clearly separated or
not presented as a duplicate active device.

**Actual:** two RMX2161 rows: one Revoked (No policy applied yet), one Offline
(Policy v4 · Waiting for device).

**Evidence:** `screenshots/parent/01_devices.png`, `screenshots/parent/16_dashboard.png`.

**Suspected layer:** device query returns both historical/revoked and current rows;
Flutter renders both without reconciliation.

## DEF-603 — Policy version mismatch

**Reproduction:** compare Parent Dashboard/Device detail with Devices tab.

**Expected:** same saved policy version everywhere.

**Actual:** Dashboard and detail show v4; Devices tab shows Policy v2.

**Evidence:** `logs/parent_dashboard2.xml`, `logs/parent_devices.xml`.

**Suspected layer:** list query/projection uses a stale or different policy field.

## DEF-604 — Notification permission false-positive

**Reproduction:** compare Child Settings → Android permissions with
`adb shell dumpsys package com.parentcontrol.parent_control`.

**Expected:** Notifications reflects the actual OS grant.

**Actual:** app shows Granted; `POST_NOTIFICATIONS` is absent from granted runtime
permissions. Parent device detail also reports Granted.

**Evidence:** `screenshots/child/05_settings_after_install.png`,
`logs/child_settings_after_install.xml`; shell output in the test session.

**Suspected layer:** Flutter permission check using the wrong API/fallback for
Android 13+ notification permission, or stale server-reported capability.

## DEF-605 — Location service not running

**Reproduction:** open Child home with location sharing enabled.

**Expected:** visible location service runs when fine/background location are granted.

**Actual:** earlier child home said Android location or notification permission was
missing and the location service was not running. Fine/background location were
granted; notifications were not.

**Evidence:** `screenshots/child/01_home.png`, `logs/child_home.xml`.

**Suspected layer:** notification-permission gate incorrectly blocking the location
service, related to DEF-604.

## DEF-606 — ADB authorization lost (environment)

**Reproduction:** physical device reconnected/ADB server restarted during testing.

**Actual:** device became `unauthorized`; USB-debugging dialog required a physical
tap. Explicit force-stop/relaunch could not be completed.

**Impact:** C18/E13 blocked; not a product defect. No workaround was attempted.
