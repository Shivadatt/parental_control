# 10 — Related Defect Workstreams (Preserved, Not Fixed)

**Purpose:** Keep the re-credentialing phase from absorbing unrelated fixes, while recording enough design to schedule them separately. **No source code is changed here.**

Prior evidence: `docs/testing/device_heartbeat_root_cause_investigation/08_e2e_002_003_004_source_analysis.md` and `docs/testing/two_device_end_to_end_testing/11_bug_and_risk_register.md`.

---

## 1. E2E-002 — Revoked devices appear in current-device listings

### Confirmed source defect
`SupabaseDeviceRepository.fetchDevices(familyId)` selects every device in the family with **no status filter** (`lib/data/repositories/supabase_device_repository.dart:37-48`). The Child-side `fetchMyDevice()` **does** filter `status='active'` (same file, lines 58-70). Parent screens render the full list (`devices_controller.dart`, `parent_devices_tab.dart`, `dashboard_controller.dart`).

Revocation sets `status='revoked'` and clears `secret_hash` (`private.revoke_device`, `20260101000100_functions.sql:432-500`). A recovered/re-paired child therefore leaves an old revoked row visible beside the new active one.

### Separate remediation design (not implemented)
**Option 1 (recommended):** keep `fetchDevices()` for a "Previous devices" section and add an active-only projection for current-device lists. Filter in the repository (`status='active'`) for current lists; keep a separate `fetchDeviceHistory(familyId)` that includes revoked rows with a clear label.

**Option 2:** filter in the controllers. Less safe because every future caller must remember.

Requirements:
- Parent UI must never present a revoked row as a current device.
- Revoked rows must not offer "Approve credential replacement" (report 07).
- Add widget tests for a mixed list (active + revoked) and a controller test asserting ordering/labels.
- No backend change required; RLS already allows the family parent to read all rows.

**Impact on Phase 4:** the recovery UI must key actions to `device.status == active`. The defect does not block the recovery design but increases the risk of a Parent selecting the wrong row.

**Priority:** P2. **Status:** OPEN, preserved as a separate workstream.

---

## 2. E2E-003 — Policy version presentation inconsistency

### Confirmed source-of-truth mismatch
- `devices.policy_version` is advanced only by a successful `apply_policy` acknowledgement (`device-command` ack path; comment in `device-telemetry/index.ts:85-87`).
- `device_policies.version` is the latest **saved** policy.
- Devices list uses `device.policyVersion` (`devices_controller.dart` `policySummaryFor`).
- Device detail and dashboard use `DevicePresentation.policySummary`, which prefers the latest saved policy (`lib/features/devices/device_presentation.dart`).

Both numbers can be correct but mean different things: "applied v2" vs "saved v4 pending".

### Separate remediation design (not implemented)
- Introduce one projection: `{appliedVersion, savedVersion, pending}`.
- Render "Applied v2 · v4 waiting for device" consistently on list, detail and dashboard.
- Add a regression test with an acknowledged v2 row and a saved v4 policy.
- No schema change.

**Impact on Phase 4:** none functionally. A recovered device should retain `policy_version`; the UI may temporarily show "v4 waiting" until the first post-recovery ack. Documented in report 06 §7 (do not reset `policy_version`).

**Priority:** P2. **Status:** OPEN, separate workstream.

---

## 3. E2E-004 — Stale or inconsistent permission capability state

### Status: root cause not established
Observed: Child Home showed "Android location or notification permission is missing" while `dumpsys` reported fine/background location granted on API 31 (`hasNotifications()` returns true below API 33, `NativePermissions.kt`). `LocationTrackingService` was not running.

Candidate causes (from prior analysis):
1. `capabilities.value` read before a permission/service change and not refreshed before the warning (`child_shell_controller.dart` `_resumeBackgroundWork`);
2. installed APK differs from HEAD in this area;
3. a service-start failure mapped to the permission message;
4. transient permission state.

### Separate remediation design (not implemented)
- Distinguish **permission missing** from **service failed to start** in the UI and in the controller state.
- Re-read capabilities immediately before the warning decision, or push a native capability event.
- Add an API-31 device test.
- Never claim a permission is missing when the live check says granted.

**Impact on Phase 4:** recovery completion re-runs the shell load; it must not surface a stale location warning as if recovery failed. Keep the recovery success criterion tied to `last_seen_at`/heartbeat, not to the location warning.

**Priority:** P2. **Status:** OPEN, separate workstream.

---

## 4. Missing features vs defects (do not conflate)

The following are **product/architecture gaps**, not regressions caused by the credential lifecycle, and require separate decisions:

| Item | Classification | Why separate |
|---|---|---|
| Bedtime enforcement | `NOT IMPLEMENTED` (product feature) | Needs policy model + native enforcement + UX |
| Emergency pass | `NOT IMPLEMENTED` (product feature) | Needs time-boxed policy exception, audit, abuse controls |
| Push / FCM | `NOT IMPLEMENTED` (infrastructure) | Needs FCM project, tokens, server sender, privacy review |
| Map rendering | `NOT IMPLEMENTED` (UI/provider decision) | Needs map SDK/provider key and cost decision |
| Route guards | `NOT IMPLEMENTED` (navigation hardening) | Needs a route-level auth/role matrix; independent of device creds |
| Forgot-password | `NOT IMPLEMENTED` (account recovery) | Needs email flow, token TTL, rate limits; separate security review |

Each must not be bundled into the re-credentialing implementation. They may share a release train only with explicit owner approval.

---

## 5. Dependency notes for Phase 4

- E2E-002 affects **target selection safety** in the Parent UI. The recovery implementation must filter/flag revoked rows before offering approval; otherwise a Parent could approve against a revoked row and receive a confusing failure (the server will reject it).
- E2E-003 affects **post-recovery presentation** only. Do not use the policy version as a recovery-success signal.
- E2E-004 affects **Child feedback clarity** after recovery. A stale permission warning must not be read as recovery failure.
- None of these three defects is a prerequisite for the backend rotation RPC; all three can proceed independently.

---

## 6. Preservation statement

No file for E2E-002/003/004 or for the missing features above was modified in Phase 4. Their designs are recorded only to prevent scope creep and to make the cross-effects explicit.
