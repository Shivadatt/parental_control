# 14 — Known Defects and Root Causes

**Date:** 2026-11-21  
**Statuses:** OPEN / REPORTED / NOT_IMPLEMENTED  
**No remediation performed.**

---

## E2E-001 — P1 — Child running, parent shows Offline with stale data

| Field | Detail |
|---|---|
| **Component** | Child credential lifecycle + heartbeat + parent presence |
| **Reproduction** | Launch child signed in to `demo`; confirm `GuardianService` foreground; refresh parent Dashboard/Devices. |
| **Expected** | Child Online within 12 min; recent `last_seen_at`. |
| **Actual** | Parent Offline; last seen Nov 13, 2026 5:23 PM (~187 h); child Home “Updated 2 d ago”. |
| **Root cause** | Current install (2026-11-17) created a new installation ID and secret. `fetchMyDevice()` returns the old active row; `_ensureIdentityAndSync()` reuses its ID with the new secret. No re-registration occurs because a device exists; `device-register` rejects a new installation ID with 409. `requireDevice()` finds a hash mismatch and returns 401 before `last_seen_at` is updated. |
| **Source** | `SecureStore.kt`, `child_shell_controller.dart`, `child_enrollment_controller.dart`, `device-register/index.ts`, `_shared/auth.ts`, `device-telemetry/index.ts`, `GuardianService.kt` |
| **Confidence** | High (~0.9); literal 401 body and `guardian_lastError` unobserved. |
| **Status** | OPEN — not fixed, not worked around. |

---

## E2E-002 — P2 — Revoked device listed as a current device

| Field | Detail |
|---|---|
| **Component** | Parent device query/UI |
| **Actual** | Two `realme RMX2161` rows: one Revoked, one Offline/active. |
| **Root cause** | `fetchDevices(familyId)` has no `status` filter; `DevicesController` and both UI tabs render every row. Child-side `fetchMyDevice()` does filter `status='active'`. |
| **Source** | `supabase_device_repository.dart`, `devices_controller.dart`, `parent_devices_tab.dart`, `parent_dashboard_tab.dart` |
| **Status** | REPORTED (BUG-040) and independently observed; OPEN as a product defect. |

---

## E2E-003 — P2 — Policy v2 on Devices list, v4 on detail/dashboard

| Field | Detail |
|---|---|
| **Component** | Parent policy presentation |
| **Actual** | Devices list “Policy v2”; detail “Version 4 / Waiting for device”; dashboard “Policy v4 · Waiting for device”. |
| **Root cause** | The list uses `devices.policy_version` (last acknowledged/applied) with a bare label; detail/dashboard use the latest `device_policies.version` (saved, pending ack). Different concepts, not a cache. |
| **Source** | `devices_controller.policySummaryFor()`, `device_presentation.policySummary()`, `device_detail_controller.dart`, `dashboard_controller.dart` |
| **Status** | OPEN — presentation/source-of-truth defect. |

---

## E2E-004 — P2 — Location warning contradicts Android permission state

| Field | Detail |
|---|---|
| **Component** | Child capability/permission messaging |
| **Actual** | UI says “Android location or notification permission is missing”; Android reports fine and background location granted; API 31 notification check returns true; `LocationTrackingService` is not running. |
| **Root cause** | Not established. Candidates: stale `capabilities.value` snapshot, installed-build/source mismatch, service-start failure mapped to permission message, transient state. |
| **Source** | `NativePermissions.kt`, `NativeBridge.kt`, `child_shell_controller.dart` (`_resumeBackgroundWork`) |
| **Status** | OPEN / unresolved. |

---

## GAP-01 — P1 — No re-credentialing path after reinstall/data loss

| Field | Detail |
|---|---|
| **Actual** | A fresh install with an existing active device row can never regain device authentication without unlink/re-pair or manual DB change. |
| **Root cause** | `needsDeviceRegistration` is false when a device exists; `registerDevice()` returns “already registered”; `device-register` only re-credentials by matching installation ID and returns 409 for a different installation with an active device. |
| **Status** | NOT_IMPLEMENTED — design gap, not a regression. |

---

## GAP-02 — P2 — Bedtime is informational only

`PolicyApplier.kt` sets `bedtime_active` but does not suspend apps for bedtime. The parent can save a bedtime and see it honored in the ack, but no hard enforcement exists.

**Status:** NOT_IMPLEMENTED.

---

## GAP-03 — P2 — No 10-minute emergency pass

No code path for a temporary pass, chaining prevention, audit or expiry. DEC-12 T-B-04 is not implemented.

**Status:** NOT_IMPLEMENTED.

---

## GAP-04 — P2 — No push/FCM channel

- No Firebase project or `google-services.json`.
- Pairing/assistance/alerts depend on polling or an open Realtime subscription.
- No OS notification when the app is closed.

**Status:** NOT_IMPLEMENTED / NOT CONFIGURED.

---

## GAP-05 — P3 — No map rendering

Location has latest/history text and timestamps; no Google Maps/FlutterMap/Mapbox dependency or renderer exists.

**Status:** NOT_IMPLEMENTED.

---

## GAP-06 — P2 — Build provenance and release signing

- Installed build is 2026-11-18; HEAD is 2026-11-20. No commit hash is embedded.
- Release signing falls back to the debug keystore unless a release key is supplied.
- Version is `1.0.0+1`; historical QA used build 4005.

**Status:** OPEN / process gap.

---

## GAP-07 — P3 — No route guards

26 named routes have no middleware; authorization is enforced per backend call and by controller redirects. No unauthorized-navigation test was executed.

**Status:** PARTIAL / NOT_TESTED.

---

## GAP-08 — P3 — Forgot-password absent

No `resetPasswordForEmail` call or “Forgot password” UI was found.

**Status:** NOT_IMPLEMENTED.

---

## Defect summary

| Priority | Count | Items |
|---|---:|---|
| P1 | 2 | E2E-001, GAP-01 |
| P2 | 6 | E2E-002, E2E-003, E2E-004, GAP-02, GAP-03, GAP-04, GAP-06 |
| P3 | 3 | GAP-05, GAP-07, GAP-08 |

No P0 security/data-exposure defect was observed.
