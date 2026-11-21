# 04 — Heartbeat Execution Trace

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Implemented heartbeat path

```text
GuardianService.onCreate
  ├─ open SecureStore
  ├─ require store.hasConfig()
  ├─ require notifications
  ├─ schedule tick every 10 s
  └─ start watchdog every 60 s
        │
        ▼
tick / runTick every 10 s
  ├─ read SyncConfig
  ├─ if config changed → reset timers
  ├─ poll device-command every 20 s (backoff on error)
  ├─ every 5 min → sendHeartbeat(DeviceHttpClient)
  ├─ every 30 min → upload app list
  ├─ every 60 min → upload usage
  └─ upload pending location
        │
        ▼
sendHeartbeat
  POST device-telemetry {action: heartbeat, battery, is_charging, online, capabilities}
  headers: apikey, Authorization, x-device-id, x-device-secret
        │
        ▼
device-telemetry
  requireDevice(req, db)
  → update devices set last_seen_at = now(), capabilities...
  → return pending_policy_version
```

Source:

- `android/.../GuardianService.kt` (constants at top; `onCreate`; `runTick`; `sendHeartbeat`)
- `android/.../DeviceHttpClient.kt`
- `supabase/functions/device-telemetry/index.ts`
- `supabase/functions/_shared/auth.ts`

---

## 2. Stage-by-stage status

| # | Stage | Implemented? | Executed? | Expected input | Observed output | Failure? |
|---|---|---|---|---|---|---|
| 1 | Service start | Yes | **Yes** | Stored sync config, notifications | `GuardianService` foreground, id 4101, alive ~37 h | No |
| 2 | Sync config load | Yes | **Yes** (service would stop without it) | URL, key, device ID, secret, family ID | Config present; service remains running | No |
| 3 | Scheduler | Yes | **Yes** | 10 s fixed delay | Service/watchdog log timestamps; no stall evidence | No |
| 4 | Heartbeat timer | Yes | **Likely** | 5 min interval | Not directly logged | Unknown |
| 5 | Request construction | Yes | Planned | battery, charging, online, capabilities | Source-complete | No |
| 6 | Credential headers | Yes | Planned | `x-device-id`, `x-device-secret` | Source-complete | No |
| 7 | HTTPS POST | Yes | **Some app TLS traffic observed** | `device-telemetry` | Established socket to Supabase `:443` (could be poll or heartbeat) | Not isolated |
| 8 | Backend auth | Yes | Presumed | headers | Not observable without server logs | **Probable failure point** |
| 9 | DB `last_seen_at` update | Yes | Not reached if auth fails | device row ID | Parent’s `last_seen_at` unchanged since Nov 13 | **Yes (effect)** |
| 10 | Parent read | Yes | **Yes** | `devices.last_seen_at` | 186 h old value displayed | Yes (stale) |
| 11 | Parent UI status | Yes | **Yes** | age < 12 min | “Offline” | Correct for the stale input |

---

## 3. Retry behavior

`sendHeartbeat` catches every exception, records a safe error, and returns `false`:

```kotlin
lastHeartbeatAt = if (sendHeartbeat(client)) now else now - HEARTBEAT_MS + 60_000L
```

So a failed heartbeat is retried **every 60 seconds**, not every 5 minutes. The tick continues indefinitely. There is no retry cap that would explain an eight-day gap.

`pollCommands` treats HTTP 401/403 specially: it multiplies the current poll backoff by 6, capped at 300 seconds. That means command polling also degrades on invalid credentials. Heartbeats continue every minute.

`recordError` stores the last error in encrypted preferences and updates the visible notification text. It does **not** write to logcat, which is why the failure is invisible in ordinary `adb logcat` output.

---

## 4. Is heartbeat even scheduled?

Evidence for scheduling:

- The service passed `onCreate`’s config/notification gates; otherwise it would have called `stopSelf()`.
- The service is still alive as a foreground service after ~37 hours.
- The watchdog re-arms the tick loop if it stalls; no service restart or crash was observed.
- The code path from `onCreate` to `scheduleWithFixedDelay` is unconditional once the gates pass.

Evidence against “not scheduled”:

- None. A dead scheduler would normally trigger the watchdog or lose the foreground service.

**Conclusion:** heartbeat scheduling/execution is **not** the primary failure. The failure is downstream, at credential acceptance.

---

## 5. Heartbeat vs telemetry credentials/endpoints

Both use the **same** `DeviceHttpClient` and the **same** `SyncConfig` credentials:

- `device-command` — command poll/ack
- `device-telemetry` — heartbeat, usage, location, apps

There is no separate heartbeat credential or endpoint. A credential mismatch therefore breaks heartbeat and all telemetry uploads together, while user-session reads (family/device/policy) can still work. That matches the observed child UI: family data visible, device freshness dead.

---

## 6. Exact failure point

The trace narrows the failure to **stage 8, `requireDevice()`**, before the database update at stage 9.

Combined with report 03:

- the current install created a new local secret on 2026-11-17;
- the server row still carries the 2026-11-13 hash;
- the shell sent the old server device ID with the new secret;
- `requireDevice()` rejects the hash mismatch.

The heartbeat is being attempted, repeatedly, but rejected. `last_seen_at` remains frozen.

---

## 7. What is still not directly observed

- The HTTP status/body of the failing heartbeat (no server logs, no network interception).
- The encrypted `guardian_lastError` text.
- Whether the Bearer publishable key or any other header is also rejected (unlikely; the same client reads/fetches policy data).

These gaps affect confidence in the *exact* rejection code, not in the credential-mismatch mechanism.

---

## 8. Heartbeat trace verdict

**FAIL — heartbeat execution reaches authentication but cannot update `last_seen_at`.**  
**Root cause location:** `SecureStore` new secret + old server device ID, with no re-credential path.  
**Retry:** present (60 s), so the failure is persistent, not a transient timeout.
