# 08 — Permissions and Capabilities Tests

**Date:** 2026-11-21  
**Child:** Realme RMX2161, Android 12 / API 31  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / PLATFORM_LIMITED

---

## 1. Android permission state

| Test ID | Capability | Android observation | App observation | Expected | Status |
|---|---|---|---|---|---|
| R01 | Fine location | `granted=true` | Warning claims location/notification missing | Accurate granted state | **FAIL (P2)** |
| R02 | Coarse location | `granted=true` | — | Granted | PASS |
| R03 | Background location | `granted=true` | — | Granted | PASS |
| R04 | Camera | `granted=true` | Not used | No unexpected activation | PASS |
| R05 | Microphone | `granted=true` | Not used | No unexpected activation | PASS |
| R06 | Usage access | `GET_USAGE_STATS: allow` | Usage capability available | Recognized | PASS |
| R07 | Notifications | `POST_NOTIFICATIONS` declared; API 31 does not use the API 33 runtime grant | Guardian notification visible; source returns true below API 33 | Visible notification | PASS |
| R08 | Device Admin | `ParentControlDeviceAdminReceiver` active | Enforcement “Device admin only” | Honest | PASS |
| R09 | Device Owner | Not provisioned | “App suspension is not supported here” | Honest | PASS (PLATFORM_LIMITED) |
| R10 | Battery optimization | App not whitelisted | Guidance not opened | Guidance visible | NOT_TESTED |
| R11 | Foreground service type | `dataSync` guardian running | Notification 4101 | Visible, typed FGS | PASS |
| R12 | Permission refresh | Load-time snapshot | Warning inconsistent | Re-read before check | **FAIL/unresolved** |

---

## 2. E2E-004 analysis

The child Home warning:

> “Android location or notification permission is missing. The location service is not running.”

Android state:

- fine location: granted
- background location: granted
- API 31: source’s `hasNotifications()` returns `true` before checking `POST_NOTIFICATIONS`

`child_shell_controller.dart` `_resumeBackgroundWork()` uses `capabilities.value`, a snapshot read at load time, not a fresh read at the moment of the check. The installed APK’s exact source revision cannot be established.

Possible causes:

1. stale capability snapshot,
2. installed build differs from HEAD,
3. a service-start failure incorrectly mapped to the permission message,
4. a transient permission state during load.

**Result:** unresolved P2. The message is conservative (it does not claim a grant), but it is not supported by the current Android state.

---

## 3. Safety

- No permission was granted, revoked or bypassed.
- Camera/microphone were not activated.
- Device Owner provisioning was not attempted.
- No accessibility service was enabled.

---

## 4. Verdict

**PASS:** permission visibility, usage access, notification/FGS, Device Admin and Device Owner honesty.  
**FAIL (P2):** location warning contradicts granted Android state.  
**NOT TESTED:** battery-optimization guidance, permission-denial recovery dialogs, background-location revocation.
