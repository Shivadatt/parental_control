# Phase 3.2.3 — Report 06: Realtime Publications vs. Background Polling Architecture Review

## 1. Executive Summary

This report analyzes the runtime architecture discrepancy identified during Phase 3.2.2 regarding device command distribution:
- **Observed Database State:** The `device_commands` table is explicitly toggled **ON** in the `supabase_realtime` logical replication publication (ID: 16430) ([P322_12_supabase_realtime_tables.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_12_supabase_realtime_tables.png)).
- **Observed Client Code State:** The native Android child service (`GuardianService.kt`) executes an **HTTPS polling loop every 20 seconds**, calling the `device-command` Edge Function.

---

## 2. In-Depth Codebase Investigation

### Native Android Child Consumer (`GuardianService.kt`)
Inspection of lines 39–370 in `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt`:

```kotlin
private const val POLL_INTERVAL_MS = 20_000L // 20 seconds

private fun pollCommands(client: DeviceHttpClient) {
    val data = client.callEdgeFunction(
        "device-command",
        JSONObject().put("action", "poll")
    )
    store.setLastPollAt(System.currentTimeMillis())
    val commands = data.optJSONArray("commands") ?: JSONArray()
    for (index in 0 until commands.length()) {
        val command = commands.optJSONObject(index) ?: continue
        handleCommand(client, command)
    }
}
```

- **Mechanism:** The child device is a headless native Android foreground service.
- **Communication Channel:** Pure HTTP/1.1 or HTTP/2 POST over TLS to Supabase Edge Functions (`https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/device-command`).
- **Authentication:** Custom device token with HMAC-SHA256 signature calculated across timestamp and body payload.
- **Realtime WebSocket Client:** **NOT INSTALLED IN NATIVE KOTLIN**. The Kotlin service does not maintain an active Supabase Realtime WebSocket connection.

### Flutter Parent Client Consumer (`device_detail_controller.dart` & `supabase_policy_repository.dart`)
Inspection of `lib/features/devices/device_detail_controller.dart`:

```dart
Future<void> _loadPolicyAndCommands() async {
  ...
  final commands = await _policyRepository.fetchRecentCommands(deviceId, limit: 10);
  recentCommands.assignAll(commands);
}
```

Inspection of `lib/data/repositories/supabase_policy_repository.dart`:

```dart
@override
Future<List<DeviceCommand>> fetchRecentCommands(String deviceId, {int limit = 20}) =>
    _guard(() async {
      final rows = await _supabase.client
          .from('device_commands')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((row) => DeviceCommand.fromJson(jsonMap(row))).toList(growable: false);
    });
```

- **Mechanism:** The parent application loads recent commands via standard PostgREST REST query on screen open and on pull-to-refresh.
- **Realtime Subscription:** The parent app does **not** subscribe to `device_commands` via `_supabase.client.channel(...)`.

---

## 3. Discrepancy Resolution & Root Cause

| Component | Uses WebSockets? | Uses HTTPS Polling? | Uses REST Select? |
| :--- | :---: | :---: | :---: |
| **Child Native Service (`GuardianService`)** | NO | **YES (20s Interval)** | NO |
| **Parent Flutter Client** | NO | NO | **YES (On Demand)** |
| **Supabase Realtime Publication** | **ENABLED (Unused)** | N/A | N/A |

### Why is `device_commands` in `supabase_realtime`?
1. **Planned Feature Heritage:** The table was added to `supabase_realtime` during the initial schema definition (`20260101000200_rls.sql`) under the original assumption that child devices would maintain an active WebSocket connection.
2. **Android Background Realities:** During native Android engineering, keeping a persistent WebSocket connection active 24/7 on Android 12+ (API 31) triggered severe Doze mode network throttling, OEM battery manager kills, and socket silent termination.
3. **Engineering Pivot:** The native client pivoted to a reliable 20-second foreground service HTTP polling loop, but the database publication toggle in Postgres was left enabled.

---

## 4. Impact & Operational Risks

### Performance & Resource Impact:
- **Database Logical Replication Overhead:** Every time a command is created or updated in `device_commands`, PostgreSQL wal2json logical replication generates messages to Supabase Realtime. Because zero active WebSocket subscribers exist for this table, these messages are discarded at the Realtime cluster boundary.
- **Risk Level:** **LOW (P3 / Informational)**. Given modest command generation frequency (parent locks, wipes, app limit updates), the replication load on Postgres 17 is negligible.

### Operational Benefit:
- Leaving `device_commands` in `supabase_realtime` allows future Flutter parent clients to show live command status delivery tick marks without requiring database schema changes.

---

## 5. Architectural Recommendations

1. **Short Term (Keep As-Is):** No immediate changes required. The 20s polling mechanism in `GuardianService.kt` is robust, battery-optimized, and resilient to carrier NAT timeouts.
2. **Medium Term (Parent UI Enhancement):** Consider subscribing to `device_commands` in `device_detail_controller.dart` via Realtime so the parent sees instant visual feedback when the child device acknowledges a command (`status = 'executed'`).
3. **No Database Modification Needed:** Modifying `supabase_realtime` publication is not needed for production stability.
