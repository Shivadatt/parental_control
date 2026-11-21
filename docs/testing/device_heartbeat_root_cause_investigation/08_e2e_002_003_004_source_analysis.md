# 08 — E2E-002, E2E-003 and E2E-004 Source Analysis

**Date:** 2026-11-21  
**Mode:** read-only source analysis; no fixes applied  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## E2E-002 — Revoked devices appear in current-device listings

### Source path

`lib/data/repositories/supabase_device_repository.dart` → `fetchDevices(familyId)`:

```dart
.from('devices')
.select(_deviceColumns)
.eq('family_id', familyId)
.order('created_at', ascending: true);
```

There is **no `status` filter**.

`lib/features/devices/devices_controller.dart` → `_fetch()`:

```dart
final loaded = await _deviceRepository.fetchDevices(activeFamily.id);
devices.assignAll(loaded);
```

`lib/features/devices/parent_devices_tab.dart` and
`lib/features/dashboard/parent_dashboard_tab.dart` render every row in that list. A revoked row is not filtered, collapsed or moved to a history section.

### Why it happens

- Revocation sets `devices.status = 'revoked'` and clears `secret_hash` (migration `20260101000100_functions.sql`, `private.revoke_device`).
- The parent query is intentionally family-scoped but not status-scoped.
- The child-side `fetchMyDevice()` **does** filter `status = 'active'`; the parent-side list does not.

### Result

The parent sees both the current active row and the old revoked row, both named `realme RMX2161`. The UI can display “Revoked” on one, but it is still in the current-device list.

### Classification

**Confirmed source defect (P2).** The query/UI should either filter to `status = 'active'` or render revoked devices in a separate “previous devices” section. This is a presentation/query issue, not a heartbeat issue.

---

## E2E-003 — Devices list shows Policy v2, detail/dashboard show Policy v4

### Source path

There are two different sources of the displayed policy version:

**Devices list** — `lib/features/devices/devices_controller.dart`:

```dart
String policySummaryFor(Device device) {
  final version = device.policyVersion;
  if (version == null || version <= 0) return 'No policy applied yet';
  return 'Policy v$version';
}
```

`Device.policyVersion` comes from `devices.policy_version`, which is advanced only by a **successful apply-policy acknowledgement** (`device-command` ack path), not by a saved policy.

**Device detail** — `lib/features/devices/device_detail_controller.dart` loads the latest policy from `device_policies` and uses:

```dart
String get policySummaryText => policySummary(
      devicePolicyVersion: device.value?.policyVersion,
      policy: latestPolicy.value,
    );
```

`policySummary` in `lib/features/devices/device_presentation.dart` prefers `policy.version` (the latest **saved** version) over `devicePolicyVersion`.

**Dashboard** — `lib/features/dashboard/dashboard_controller.dart` also loads per-device policies and uses the same `policySummary` helper, so it follows the saved-version value.

### Why it happens

This is **not a cache bug**. It is a data-source mismatch:

- `devices.policy_version` = last **acknowledged/applied** version (v2).
- `device_policies.version` = latest **saved** policy (v4, still waiting for acknowledgement).

The list shows the acknowledged number without its status; the detail/dashboard show the saved number with “Waiting for device.” Both can be technically correct but they are different concepts, and the list label does not explain that.

### Classification

**Confirmed presentation/source-of-truth defect (P2).** The UI should use one helper and one vocabulary, e.g. “Applied v2 · Saved v4 pending,” or the list should use the same latest-policy projection as detail.

---

## E2E-004 — Location warning contradicts Android permission state

### Source path

`android/.../NativePermissions.kt`:

```kotlin
fun hasFineLocation(context: Context) = granted(... ACCESS_FINE_LOCATION)

fun hasNotifications(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
    return granted(context, Manifest.permission.POST_NOTIFICATIONS)
}
```

On the child (API 31), `hasNotifications()` returns `true` **without** checking `POST_NOTIFICATIONS`, which is correct for Android 12. Android reports fine and background location as granted.

`lib/features/child/controllers/child_shell_controller.dart` → `_resumeBackgroundWork()`:

```dart
final caps = capabilities.value;
...
if (!caps.fineLocationGranted || !caps.notificationsGranted) {
  locationWarning.value =
      'Location sharing is on in this app, but Android location or '
      'notification permission is missing. The location service is not running.';
}
```

`capabilities.value` is refreshed through `_readCapabilities()` at load time, and again in explicit permission-request paths. It is **not** re-read immediately before this check.

### What can be concluded

- For the current HEAD logic on API 31, with fine location granted, this branch should be false.
- Yet the child Home displayed exactly this message, and `LocationTrackingService` was not running.
- Therefore one of the inputs to `caps` was false at the time the warning was set, or the installed build differs from HEAD in this area.

### Candidate explanations (none confirmed)

1. **Stale capability snapshot:** `capabilities.value` was read before a permission grant/service change and not refreshed before the warning.
2. **Source/build mismatch:** the installed 2026-11-18 APK does not contain the same `NativePermissions`/controller logic as HEAD.
3. **A service-start failure mapped to the wrong message:** less likely, because the code has a distinct “Android did not start the visible location service” branch.
4. **A transient permission state during load:** possible, not observed directly.

The message is cautious and does not claim a permission is granted when it is not. It also correctly says the location service is not running. The defect is that it may blame permissions when the actual state (fine/background granted) does not support that blame.

### Classification

**Unresolved (P2), root cause not established.** Requires a safe diagnostic that reads `capabilities.value`/live permission flags on the installed build, without exposing credentials.

---

## Summary

| Finding | Source confirmed? | Root cause | Confidence |
|---|---|---|---|
| E2E-002 revoked row listed | Yes | Missing parent-side status filter | High |
| E2E-003 policy v2 vs v4 | Yes | `devices.policy_version` vs latest `device_policies.version` | High |
| E2E-004 permission warning | Partly | Stale snapshot or build/source mismatch | Low–medium |

No code, migration, Edge Function or UI behavior was changed.
