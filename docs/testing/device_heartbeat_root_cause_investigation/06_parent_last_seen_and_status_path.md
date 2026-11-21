# 06 — Parent Last-Seen and Status Path

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Source of device status

Parent reads the `devices` table directly through PostgREST:

`lib/data/repositories/supabase_device_repository.dart`

```dart
.from('devices')
.select(_deviceColumns)
.eq('family_id', familyId)
.order('created_at', ascending: true)
```

`_deviceColumns` includes:

- `id`, `family_id`, `child_user_id`, `display_name`
- `status`, `credential_issued_at`, `credential_revoked_at`
- `last_seen_at`, `battery_level`, `is_charging`
- `enforcement_mode`, `policy_version`
- permission flags
- `created_at`, `updated_at`

No view, RPC or server-computed presence field is used. `last_seen_at` is the only presence input.

---

## 2. Presence computation

`lib/data/models/device.dart`

| Rule | Value |
|---|---|
| Healthy / online | `age < 12 minutes` (`onlineWindow`) |
| Stalled | `12 ≤ age < 30 minutes` (`stalledWindow`) |
| Offline | age ≥ 30 minutes, or `last_seen_at == null` |
| Future timestamp | treated as age zero |

The comment documents that the 12-minute window covers two 5-minute heartbeats plus grace, specifically to avoid the old “Offline for 2 minutes of every cycle” defect.

For the observed row, `last_seen_at = 2026-11-13 17:23`, so the computed age is ~8 days → **Offline**. The UI is correctly rendering the stale data. The defect is the stale DB value, not the status calculation.

---

## 3. Refresh behavior

`lib/features/devices/devices_controller.dart`

- `onInit` starts a `Timer.periodic(60 s)` refresh.
- Connectivity restoration triggers an immediate refresh.
- `fetchDevices` re-queries the server every cycle.
- `lastRefreshedAt = DateTime.now()` is set after a successful fetch; the “Updated Just now” label reflects **the list fetch**, not the device heartbeat.

There is **no Realtime subscription** for the devices list in this controller. The parent does not receive a live push when `last_seen_at` changes; it polls once a minute.

`lib/features/dashboard/dashboard_controller.dart` has the same 60-second pattern and additionally loads the latest policy per device.

---

## 4. Why the parent shows Offline

| Step | Value | Correct? |
|---|---|---|
| Child heartbeat update | Rejected before DB update (report 04/05) | No |
| `devices.last_seen_at` | Still 2026-11-13 17:23 | Stale |
| Parent fetch | Executes every 60 s; “Updated Just now” | Yes |
| Age calculation | ~8 days | Yes |
| `syncHealth` | `offline` | Yes |
| Status chip | “Offline” | Yes |

The parent is not caching an old value; it is faithfully displaying an old value that the backend still holds.

---

## 5. Revoked-device filtering

`fetchDevices` does **not** filter `status`:

```dart
.eq('family_id', familyId)   // no status filter
```

`DevicesController` assigns all returned rows and the Devices tab/dashboard render all of them. That is why a revoked row and the active row both appear. See report 08 for the P2 source analysis.

The child’s `fetchMyDevice` **does** filter `status = active` and uses `maybeSingle()`, so the child resolves only the active row. That is why the child can load family/device data while the parent sees both rows.

---

## 6. Timezone

`last_seen_at` is an ISO timestamp from the server and is parsed into a `DateTime`; the UI formats it with the device locale/timezone. A timezone error large enough to turn “now” into “8 days ago” is not plausible; the same timestamp is consistently old on both the dashboard and device detail.

---

## 7. Parent path verdict

**PASS** — parent presence logic is implemented, uses the same `last_seen_at` field the child updates, computes the threshold correctly, and refreshes on a timer.

**FAIL (effect)** — the value it reads is stale because the child heartbeat never updates it.

**E2E-002** — revoked rows are not filtered from current-device queries.

**E2E-003** — the Devices list uses `devices.policy_version` while detail/dashboard use the latest `device_policies.version`; they are different sources of truth.
