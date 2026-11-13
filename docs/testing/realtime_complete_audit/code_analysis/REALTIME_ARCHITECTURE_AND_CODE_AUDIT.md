# Realtime Architecture & Code-Level Audit Report
**Target Repository:** `D:\parentcontrol_app`  
**Generated Date:** 2026-11-13  
**Auditor:** Agent 1 — Realtime Architecture & Code Analyst  
**Scope:** Exhaustive audit of all real-time, streaming, telemetry, background services, polling loops, database publications, RLS filters, Edge Functions, advisory locking, and failure resilience across Flutter, Kotlin Android Native, and PostgreSQL / Supabase Backend.

---

## Executive Summary

The `parentcontrol_app` employs a **hybrid architecture** combining:
1. **Supabase Realtime (PostgreSQL Changes via WebSocket)** for safety alerts, remote assistance session lifecycles, and WebRTC signaling.
2. **Deterministic Periodic Polling Loops** for child device command consumption, parent dashboard telemetry refreshes, device list synchronization, and policy enforcement acknowledgement verification.
3. **Android Native Foreground Services** (`GuardianService`, `LocationTrackingService`, `AudioAssistanceService`) enforcing background sync, location streaming, WebRTC audio maintenance, and device owner app restrictions.
4. **Serverless Edge Functions & PostgreSQL Stored Procedures** backed by transaction-scoped advisory locks (`pg_advisory_xact_lock`), security-definer RPCs, and cron-triggered sweeps.

Notably, **no Supabase Broadcast or Presence channels** are used. All real-time updates rely exclusively on **private, RLS-filtered `postgres_changes` subscriptions** on specific tables, or explicit HTTP polling.

---

## 1. Flutter Realtime & Polling Code Audit

### 1.1 Complete Inventory of Supabase Realtime Subscriptions

Across the entire Flutter codebase (`lib/`), exactly **three (3)** distinct table listeners are constructed through Supabase Realtime channels. All three are configured as private (`opts: const RealtimeChannelConfig(private: true)`), and topic authorization is enforced server-side by PostgreSQL function `private.realtime_topic_allowed(p_topic text)`.

| # | Feature / Subscription | Source File & Lines | Channel Topic Pattern | Table Listened | Event Filter Condition | Event Types | Status Callbacks & Disposal | State / UI Updated |
|---|------------------------|---------------------|-----------------------|----------------|------------------------|-------------|-----------------------------|--------------------|
| 1 | **Safety Alerts Stream** | `lib/data/repositories/supabase_alert_repository.dart:60-143` | `safety-alerts:<familyId>:<microsecondsSinceEpoch>` | `public.safety_alerts` | `family_id=eq.<familyId>` | `INSERT`, `UPDATE` | Subscribes to `RealtimeSubscribeStatus`. Handles `channelError` and `timedOut` by emitting `AppException(network)`. Teardown: `active.unsubscribe()` + `removeChannel(active)` via broadcast `onCancel`. | `SafetyAlertsController.alerts` (`RxList<SafetyAlert>`), `unacknowledgedCount`, `visibleAlerts` |
| 2 | **WebRTC Signaling Stream** | `lib/data/repositories/supabase_remote_session_repository.dart:223-297` | `webrtc-signals:<sessionId>:<microsecondsSinceEpoch>` | `public.webrtc_signals` | `session_id=eq.<sessionId>` | `INSERT` | Emits empty list on `subscribed` to clear stale connection banners. Emits network error on `channelError`/`timedOut`. Replays pre-existing signals via `_replaySignals()`. Teardown: `active.unsubscribe()` + `removeChannel(active)`. | `RemoteSessionController._handleRemoteSignal()` -> WebRTC offer/answer/candidate processing, peer connection state |
| 3 | **Remote Session Row Updates** | `lib/data/repositories/supabase_remote_session_repository.dart:323-398` | `remote-session:<sessionId>:<microsecondsSinceEpoch>` OR `remote-session-family:<familyId>:<microsecondsSinceEpoch>` | `public.remote_sessions` | `id=eq.<sessionId>` OR `family_id=eq.<familyId>` | `INSERT`, `UPDATE` | Handles `channelError` and `timedOut`. Calls `active.unsubscribe()` and `removeChannel(active)` in `onCancel`. | `RemoteSessionController.session` (`Rxn<RemoteSession>`), triggers UI phase transitions (accepted, active, ended) |

#### Deep-Dive Analysis of Subscriptions:
- **`SupabaseAlertRepository.watchAlerts`** (`lib/data/repositories/supabase_alert_repository.dart:60-143`):
  - Subscribes to `postgres_changes` on `safety_alerts` for `family_id = eq.<familyId>`.
  - Captures `INSERT` (new safety alert triggered, e.g. low battery, geofence enter/exit, device offline) and `UPDATE` (e.g. parent acknowledged alert).
  - Controller integration (`lib/features/safety_alerts/safety_alerts_controller.dart:78-93`): In `onInit()`, controller invokes `_subscribe()`. On incoming items, `_merge(incoming)` deduplicates by `alert.id` in `alerts` RxList.
  - Resilience: Controller provides `retryRealtime()` (`lib/features/safety_alerts/safety_alerts_controller.dart:95-98`) allowing manual reconnection if channel times out.
- **`SupabaseRemoteSessionRepository.watchSignals`** (`lib/data/repositories/supabase_remote_session_repository.dart:223-297`):
  - Channel name: `webrtc-signals:$sessionId:${DateTime.now().microsecondsSinceEpoch}`.
  - Listens only to `INSERT` because signaling packets (offer, answer, ICE candidates) are immutable event rows.
  - **Late Joiner Replay**: Immediately executes `_replaySignals(sessionId)` (`lib/data/repositories/supabase_remote_session_repository.dart:303-321`) which queries all existing signals ordered by `sequence ascending`.
  - Controller integration (`lib/features/remote_assistance/remote_session_controller.dart:849-905`): Deduplicates incoming signals via `_seenSignalIds` (`Set<String>`). Has exponential backoff retry `_signalRetryTimer = Timer(delay, ...)` with schedule `[1s, 2s, 4s, 8s, 16s]`.
- **`SupabaseRemoteSessionRepository.watchSession`** (`lib/data/repositories/supabase_remote_session_repository.dart:196-206`, `323-398`):
  - Topic: `remote-session:$sessionId:${DateTime.now().microsecondsSinceEpoch}`.
  - Listens for `INSERT` and `UPDATE` on `remote_sessions` table filtered by `id=eq.<sessionId>`.
  - Updates `RemoteSessionController.session` to drive WebRTC negotiation handshake.

---

### 1.2 Audit of Polling Loops & Periodic Timers in Flutter

A comprehensive search across `lib/` identified all active polling loops and timers:

| Controller / Service | Source File & Line | Timer / Loop Type | Interval / Backoff | Triggered Action & Backend Endpoint | Cancellation / Disposal Mechanism |
|----------------------|--------------------|-------------------|---------------------|--------------------------------------|-----------------------------------|
| **DashboardController** | `lib/features/dashboard/dashboard_controller.dart:71-76` | `Timer.periodic` | 60 seconds (`refreshInterval`) | Re-fetches family, devices, and policies (`fetchFamily`, `fetchDevices`, `fetchLatestPolicy`). Also triggers on connectivity restored (`ever(_connectivity.isOnline)`). | `_refreshTimer?.cancel()` in `onClose()` (`lines 80-85`). |
| **DevicesController** | `lib/features/devices/devices_controller.dart:61-66` | `Timer.periodic` | 60 seconds (`refreshInterval`) | Refreshes device list (`_deviceRepository.fetchDevicesForFamily`). Triggers on connectivity restored. | `_refreshTimer?.cancel()` in `onClose()` (`lines 70-75`). |
| **ChildShellController (Linked Polling)** | `lib/features/child/controllers/child_shell_controller.dart:388-406` | `Timer.periodic` (`_linkedPollTimer`) | 20 seconds (`linkedPollInterval`) | Polls pending pairing requests (`_loadPendingRequests`), checks active remote sessions (`_loadActiveSession`), and refreshes device row (`_refreshDeviceRow`). Only runs while enrolled. | `_stopLinkedPollTimer()` on unlinking or `onClose()` (`lines 1115-1120`). |
| **ChildRequestsController** | `lib/features/child/controllers/child_requests_controller.dart:43-48` | `Timer.periodic` (`_pollTimer`) | 15 seconds (`pollInterval`) | Polls pending assistance and pairing requests (`refresh()`). | `_pollTimer?.cancel()` in `onClose()` (`lines 211-216`). |
| **ChildEnrollmentController** | `lib/features/child/controllers/child_enrollment_controller.dart:73-78` | `Timer.periodic` (`_pollTimer`) | 15 seconds (`pollInterval`) | Checks incoming pairing requests while enrollment screen is active (`checkRequests(silent: true)`). | `_pollTimer?.cancel()` in `onClose()` (`lines 332-337`). |
| **PairingRequestsController** | `lib/features/pairing/controllers/pairing_requests_controller.dart:49-54` | `Timer.periodic` (`_pollTimer`) | 20 seconds (`pollInterval`) | Refreshes family pairing requests list (`_load(silent: true)`). | `_pollTimer?.cancel()` in `onClose()` (`lines 144-149`). |
| **PairingRedeemController** | `lib/features/pairing/controllers/pairing_redeem_controller.dart:163-168` | `Timer.periodic` (`_statusPollTimer`) | 10 seconds (`statusPollInterval`) | Polls status of submitted pairing invite code (`checkStatus()`) while status is `pendingChild`. | `_stopStatusPolling()` when status changes or in `onClose()` (`lines 175-179`). |
| **ScreenTimeController (Policy Ack Polling)** | `lib/features/screen_time/screen_time_controller.dart:432-459` | `Timer.periodic` (`_ackTimer`) | 5 seconds (Max 6 attempts = 30s cap) | Polls `fetchLatestPolicy(deviceId)` to confirm child device acknowledged limit/bedtime. Cancels early once status is `enforced`, `failed`, or `unsupported`. | `_ackTimer?.cancel()` in `onClose()`. |
| **AppRestrictionsController (Policy Ack Polling)** | `lib/features/app_restrictions/app_restrictions_controller.dart:629-657` | `Timer.periodic` (`_ackTimer`) | 5 seconds (Max 6 attempts = 30s cap) | Polls `fetchLatestPolicy(deviceId)` and `_loadEnforcementReport(policy)` to check suspension confirmation. | `_ackTimer?.cancel()` in `onClose()`. |
| **RemoteSessionController (Signaling Retry)** | `lib/features/remote_assistance/remote_session_controller.dart:887-897` | `Timer` (Single-shot exponential backoff) | 1s, 2s, 4s, 8s, 16s | Retries establishing `watchSignals` WebSocket subscription on channel timeout/error. | `_signalRetryTimer?.cancel()` in `onClose()`. |
| **RemoteSessionController (Capture Heartbeat)** | `lib/features/remote_assistance/remote_session_controller.dart:2245-2262` | `Timer.periodic` (`_captureHeartbeatTimer`) | 10 seconds (`captureHeartbeatInterval`) | Sends platform channel ping `notifyAudioCaptureHeartbeat` to native `AudioAssistanceService` to prevent capture timeout (45s cap). | `_stopCaptureHeartbeat()` on session teardown or `onClose()`. |
| **RemoteSessionController (Stats Sampling)** | `lib/features/remote_assistance/remote_session_controller.dart:2268-2281` | `Timer.periodic` (`_statsTimer`) | 5 seconds (`statsSampleInterval`) | Samples WebRTC peer connection media statistics (audio bytes received, packets lost, jitter). | `_stopStatsSampling()` on session teardown. |
| **RemoteSessionController (Permission Poller)** | `lib/features/remote_assistance/remote_session_controller.dart:2106-2115` | `Timer.periodic` (`_permissionTimer`) | 2 seconds (`permissionPollInterval`) | Polls microphone permission state while waiting for permission dialog. | `_permissionTimer?.cancel()`. |
| **RemoteSessionController (Session Ticker)** | `lib/features/remote_assistance/remote_session_controller.dart:2622-2628` | `Timer.periodic` (`_ticker`) | 1 second | Increments session duration elapsed seconds in UI. | `_stopTicker()` on session end. |
| **VerifyEmailController (Resend Cooldown)** | `lib/features/auth/controllers/verify_email_controller.dart:211-224` | `Timer.periodic` (`_cooldownTimer`) | 1 second | Decrements resend cooldown counter (60s). | `_cooldownTimer?.cancel()` in `onClose()`. |

---

### 1.3 Complete Feature Classification Matrix

Every application capability is classified into one of the designated architectural patterns:

| Feature / Domain | Classification | Mechanism & Citation |
|------------------|----------------|----------------------|
| **Safety Alerts Feed** | **(A) Supabase Realtime Subscription** | `watchAlerts()` in `supabase_alert_repository.dart:60-143`, table `safety_alerts`. |
| **WebRTC Signaling Exchange** | **(A) Supabase Realtime Subscription** | `watchSignals()` in `supabase_remote_session_repository.dart:223-297`, table `webrtc_signals`. |
| **Remote Assistance Session State** | **(A) Supabase Realtime Subscription** | `watchSession()` in `supabase_remote_session_repository.dart:323-398`, table `remote_sessions`. |
| **Supabase Broadcast Channels** | **(G) No Implementation** | No `channel.onBroadcast()` or `channel.sendBroadcast()` exists. Broadcast is bypassed in favor of private postgres changes. |
| **Supabase Presence Tracking** | **(G) No Implementation** | Device online presence is derived from `devices.last_seen_at` (heartbeat), not Supabase Realtime Presence. |
| **Child Device Commands Delivery** | **(D) Polling** | Kotlin `GuardianService.kt:360-372` polls `device-command` function every 20 seconds. |
| **Parent Dashboard Data** | **(D) Polling** | `DashboardController.dart:71-76` periodic 60s poll + manual pull-to-refresh. |
| **Devices List View** | **(D) Polling** | `DevicesController.dart:61-66` periodic 60s poll + manual pull-to-refresh. |
| **Child Linked State & Pairings** | **(D) Polling** | `ChildShellController.dart:388-406` periodic 20s poll (`_syncLinkedPollTimer`). |
| **Pairing Requests List** | **(D) Polling** | `PairingRequestsController.dart:49-54` periodic 20s poll. |
| **Pairing Invite Redemption Status** | **(D) Polling** | `PairingRedeemController.dart:163-168` periodic 10s poll while `pendingChild`. |
| **Policy Enforcement Acknowledgement** | **(D) Polling** | `ScreenTimeController.dart:432-459` & `AppRestrictionsController.dart:629-657` 5s poll for 30s. |
| **Device Detail Screen** | **(E) Manual Refresh** | `DeviceDetailController.dart:63-95` loads on view init and manual refresh. |
| **Location Map & History View** | **(E) Manual Refresh** | `LocationController.dart:61-91` loads `fetchLatestLocation` and `fetchHistory` manually. |
| **Safe Zones List & Management** | **(E) Manual Refresh** | `SafeZonesController.dart:57-80` loads on init and reloads upon zone upsert/delete. |
| **Audit Logs Viewer** | **(E) Manual Refresh** | `AuditLogsController.dart:52-56` loads on init with pagination `loadMore()`. |
| **Child App Restrictions Catalog** | **(E) Manual Refresh** | `AppRestrictionsController.dart:170-200` loads installed apps from DB manually. |
| **Native Device Hardware Events** | **(B) Broadcast (Platform)** | Flutter `DeviceAdminService.dart:19-37` listens to native Android `EventChannel('com.parentcontrol/native_events')`. |
| **Device Capabilities & Identity** | **(F) Local-Only State** | `SecureStore.kt:86-105` generates AES encrypted `installation_id` & `device_secret`. |
| **Offline Detection Alerting** | **(D) Polling (Backend Cron)** | `cron` function calls `private.detect_offline_devices()` checking `last_seen_at < now() - 15 min`. |

---

## 2. Kotlin Android Native Architecture

### 2.1 GuardianService (`GuardianService.kt`)
The primary background synchronization worker for managed child devices. Runs as a persistent **Foreground Service** (`ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC`).

- **Tick Loop Architecture** (`GuardianService.kt:153-163`, `211-289`):
  - Driven by a single-threaded `ScheduledExecutorService` with fixed delay:
    - **Base Tick Interval (`TICK_MS`):** `10_000L` (10 seconds).
    - Wrapped in isolated `Runnable` (`tickTask`, `lines 113-119`) preventing thrown exceptions from terminating future executions.
- **Heartbeat & Telemetry Schedule**:
  - **Commands Poll Interval (`POLL_INTERVAL_MS`):** `20_000L` (20 seconds, `lines 260-277`).
    - Error backoff: Multiplies delay by `6x` on HTTP 401/403, `3x` on HTTP 429, and `2x` on generic errors, capped at `300_000L` (5 minutes).
  - **Policy Enforcement Tick (`POLICY_TICK_MS`):** `60_000L` (60 seconds, `lines 249-258`). Calls `PolicyApplier.tick()`.
  - **Device Heartbeat (`HEARTBEAT_MS`):** `300_000L` (5 minutes, `lines 279-281`). Sends battery level, charging status, online boolean, and permissions capability flags to `device-telemetry`. Returns `pending_policy_version`. If newer version exists, sets `nextPollAllowedAt = 0L` to poll immediately.
  - **Installed Apps Snapshot (`APPS_UPLOAD_MS`):** `1_800_000L` (30 minutes, `lines 282-284`).
  - **Daily Usage Upload (`USAGE_UPLOAD_MS`):** `3_600_000L` (60 minutes, `lines 285-287`).
- **Internal Hardware Watchdog** (`GuardianService.kt:306-358`):
  - Second single-threaded `ScheduledExecutorService` running every `60_000L` (`WATCHDOG_INTERVAL_MS`).
  - Evaluates `System.currentTimeMillis() - lastTickAt`.
  - If delta exceeds `STALL_FACTOR * TICK_MS` (30 seconds), diagnoses a stalled tick loop:
    - Cancels stalled future `tickFuture?.cancel(false)`.
    - Reschedules new 10s tick loop.
    - Increments `stallRecoveries`.
    - Records error and emits `guardian_stall_recovered` event to `NativeEventBus`.
- **Android 15 Compatibility** (`GuardianService.kt:195-209`):
  - Overrides `onTimeout(startId: Int)` and `onTimeout(startId: Int, fgsType: Int)`.
  - Safely stops service when Android 15 dataSync timeout is triggered and records error.

---

### 2.2 LocationTrackingService (`LocationTrackingService.kt`)
Responsible for visible, child-consented GPS tracking. Runs as Foreground Service of type `FOREGROUND_SERVICE_TYPE_LOCATION`.

- **Provider Management & Listener** (`LocationTrackingService.kt:112-162`):
  - Requests updates from both `LocationManager.GPS_PROVIDER` and `LocationManager.NETWORK_PROVIDER`.
  - **Update Interval:** Configurable via intent extra `EXTRA_INTERVAL_SECONDS`, clamped between `15` and `3600` seconds (default `60` seconds = `60_000L` ms).
  - **Distance Threshold:** `0f` meters (time-based triggering).
- **Mock Location Filtering** (`LocationTrackingService.kt:171-187`):
  - Inspects `location.isMock` (Android 12+ API 31+) or deprecated `location.isFromMockProvider` (API < 31).
  - Populates `LiveFix(..., isMock = mock)`.
  - Updates `LiveState.update(fix)` and emits `NativeEventBus.emitLocation(fix)`.
  - **Upload Defense in `GuardianService.kt:592-608`:** When `GuardianService` uploads pending location, it explicitly verifies `fix.isMock`. If mock location is detected, it logs an error, rate-limits warnings to once every 5 minutes (`lastMockWarningMillis`), and **refuses to upload the coordinate to Supabase**.

---

### 2.3 AudioAssistanceService (`AudioAssistanceService.kt`)
Manages live background microphone capture for remote assistance WebRTC sessions. Runs as Foreground Service of type `FOREGROUND_SERVICE_TYPE_MICROPHONE` (Android 11+ API 30+).

- **WebRTC Audio Architecture** (`AudioAssistanceService.kt:36-67`):
  - Service does not record audio to disk; it maintains process foreground eligibility and wake lock (`PowerManager.PARTIAL_WAKE_LOCK`) while FlutterEngine captures audio track via WebRTC.
- **Triple Watchdog System**:
  1. **Microphone Permission Watchdog** (`AudioAssistanceService.kt:342-357`):
     - Handler-based loop checking `RECORD_AUDIO` every `5_000L` ms (`PERMISSION_CHECK_INTERVAL_MS`). Revocation triggers immediate shutdown with `REASON_PERMISSION_DENIED`.
  2. **Dart Capture Heartbeat Watchdog** (`AudioAssistanceService.kt:365-384`, `CAPTURE_HEARTBEAT_TIMEOUT_MS = 45_000L`):
     - Every `15_000L` ms, verifies `SystemClock.elapsedRealtime() - lastCaptureHeartbeatAt <= 45_000L`. If Dart stops sending 10-second heartbeats (engine crash, page pop), service shuts down with `REASON_CAPTURE_LOST`.
  3. **Backend Session State Watchdog** (`AudioAssistanceService.kt:695-720`, `SESSION_WATCHDOG_INTERVAL_MS = 15_000L`):
     - Dedicated background thread querying `remote-session` Edge Function (`action: session_state`) every 15 seconds. If parent ended session or status is not in `["requested", "accepted", "active"]`, stops with `REASON_SESSION_ENDED_BY_PARENT`.
- **Task Swipe Resilience (`onTaskRemoved`)** (`AudioAssistanceService.kt:489-507`):
  - When child app is swiped from Android Recents, the service **does not stop**. It remains active in the foreground with notification and Stop action, emitting `audio_assistance_detached`.

---

### 2.4 PolicyApplier (`PolicyApplier.kt`)
Executes app restrictions and daily quotas via Android `DevicePolicyManager`.

- **Enforcement Mechanics** (`PolicyApplier.kt:38-251`):
  - Verified via `isDeviceOwner()`.
  - **Device Owner Requirement:** App suspension (`devicePolicyManager.setPackagesSuspended`) strictly requires Device Owner provisioning. If app is only Device Admin, app suspension is rejected, and reported to server as `unsupported`.
  - **Self-Protection & System Defense:** Protects self package (`context.packageName`), default launcher home package (`defaultHomePackage()`), and active IME keyboard (`defaultInputMethodPackage()`).
  - **Quota Enforcement (`QuotaEvaluator.kt`):** Reads daily screen-time quota and compares against `UsageStatsManager`. Packages are dynamically appended to the suspension target set when quota is reached.
  - **Acknowledgement Generation:** Returns structured JSON containing `desired_count`, `applied_count`, `enforcement_supported`, and specific per-package `failures`.

---

### 2.5 Supporting Native Components
- **`BootReceiver.kt:17-53`**:
  - Listens for `ACTION_BOOT_COMPLETED` and `ACTION_MY_PACKAGE_REPLACED`.
  - **Android 15 Guard:** Android 15 prohibits dataSync foreground services from starting at boot. Logs explicit error `Android 15 does not allow starting visible background sync at boot. Open Parent Control to resume it.`.
  - Re-starts `GuardianService.start(context)` on supported platforms.
- **`SecureStore.kt:25-100`**:
  - Backed by Android Jetpack `EncryptedSharedPreferences` (`AES256_SIV` keys, `AES256_GCM` values) with hardware `MasterKey`.
  - Stores `installation_id`, `device_secret`, Supabase credentials, applied policy versions, and handled command IDs (LRU ring buffer of 100).
- **`NativeBridge.kt:35-100` & `NativeEventBus.kt`**:
  - Process-scoped bridge attaching `MethodChannel('com.parentcontrol/native')` and `EventChannel('com.parentcontrol/native_events')`.
  - Survives UI activity destruction, preserving WebRTC engine streams.

---

## 3. Supabase Backend Audit

### 3.1 Realtime Publications & Database Migrations

Inspection of all SQL migrations in `supabase/migrations/`:
- **Realtime Publication Configuration** (`supabase/migrations/20260101000100_functions.sql:908-944`):
  ```sql
  alter publication supabase_realtime add table public.device_commands;
  alter publication supabase_realtime add table public.safety_alerts;
  alter publication supabase_realtime add table public.remote_sessions;
  alter publication supabase_realtime add table public.webrtc_signals;
  ```
  Only these four tables are registered in the Supabase Realtime publication.
- **Private Topic RLS Authorization Policy** (`supabase/migrations/20260101000200_rls.sql:290-359`):
  - Realtime subscriptions join with `private: true`, evaluated by `realtime.messages` security policy:
    ```sql
    create policy parentcontrol_private_topics on realtime.messages
      for select to authenticated
      using (private.realtime_topic_allowed(realtime.topic()));
    ```
  - Validation function `private.realtime_topic_allowed(p_topic text)` restricts topics to:
    1. `safety-alerts:<familyId>:<ts>` -> Requires `private.is_family_member(familyId)`.
    2. `remote-session-family:<familyId>:<ts>` -> Requires `private.is_family_member(familyId)`.
    3. `remote-session:<sessionId>:<ts>` -> Requires caller is child participant or active family parent.
    4. `webrtc-signals:<sessionId>:<ts>` -> Requires caller is child participant or active family parent.
  - **Important Architectural Note:** There is **no allowed topic rule for `device_commands`** in `private.realtime_topic_allowed()`. As designed, devices never subscribe to `device_commands` over WebSocket; they consume commands exclusively via HTTP polling.

- **Table RLS Policies for Realtime Tables**:
  - `safety_alerts`: Parent or device child owner can `SELECT` (`supabase/migrations/20260101000200_rls.sql:173-182`).
  - `remote_sessions`: Participants (`parent_user_id` or `child_user_id`) can `SELECT` (`20260101000200_rls.sql:185-195`).
  - `webrtc_signals`: Participants can `SELECT` and `INSERT` only when session is in `('accepted', 'active')` status (`supabase/migrations/20261028000300_signaling_open_session.sql:23-54`).

---

### 3.2 Edge Functions Implementation & Security

All functions in `supabase/functions/` run on Deno with strict JWT or device-credential verification:

1. **`device-telemetry`** (`supabase/functions/device-telemetry/index.ts`):
   - Authenticates child phone via `x-device-id` and `x-device-secret` (`requireDevice`).
   - `heartbeat`: Updates `devices.last_seen_at`, battery percentage, charging state, and capabilities. Evaluates low-battery alert (< 20% & discharging, max 1 alert per 6 hours). Returns `pending_policy_version`.
   - `location_upload`: Inserts `location_events`. Evaluates all active `safe_zones` for the family using Haversine calculation (`distanceMeters`). If transition detected against `safe_zone_states`, inserts `geofence_enter` or `geofence_exit` alert into `safety_alerts`.
   - `usage_upload`: Upserts daily package usage to `usage_daily` table with conflict target `(device_id, day, package_name)`.
   - `apps_upload`: Replaces installed application snapshot in `device_apps`.
2. **`device-command`** (`supabase/functions/device-command/handler.ts`):
   - `create`: Parent queues command (`apply_policy`, `sync_policy`, `request_usage`, `request_location`).
   - `poll`: Device executes `db.rpc("poll_device_commands", { p_device_id, p_limit: 20 })`. Marks commands as delivered.
   - `ack`: Device reports command outcome (`succeeded`, `failed`, `expired`) with execution details and suspension counts. Updates `device_policies.status` to `enforced` or `failed`.
3. **`remote-session`** (`supabase/functions/remote-session/index.ts`):
   - `request`: Parent initiates audio/video session. Invokes `public.request_remote_session` RPC protected by advisory lock.
   - `session_state`: Unauthenticated/device-authenticated lightweight poll used by native Android `AudioAssistanceService` watchdog.
   - `respond`: Child records consent (`accept` or `decline`). Nulls `expires_at` (making session parent-controlled).
   - `start`: Child marks session `active` upon WebRTC connection initialization.
   - `end`: Parent terminates session, updates `ended_at` and `ended_reason`.
   - `ice`: Generates ephemeral TURN / STUN credentials via HMAC-SHA1.
4. **`family-admin`** (`supabase/functions/family-admin/index.ts`):
   - Parent administrative actions (`ack_alert`, `delete_zone`, `unlink_child`, `revoke_device`).
   - Safe zone deletion calls atomic RPC `public.delete_safe_zone_atomic` (`20261103000100_zone_delete_atomic_rpc.sql`) preventing unaudited deletes.
5. **`cron`** (`supabase/functions/cron/index.ts`):
   - Authenticated with `x-cron-secret`.
   - `expire_sessions`: Closes unconsented requests older than 10 minutes.
   - `detect_offline`: Finds active devices with `last_seen_at < now() - 15 minutes` and inserts `offline` warnings into `safety_alerts`.
   - `sweep_sessions`: Closes consented but abandoned sessions older than 24 hours (`expire_abandoned_sessions`).
   - `retention_sweep`: Executes `run_retention_sweep()` deleting expired telemetry and signaling rows.

---

### 3.3 Database Advisory Locks & Atomic Concurrency

- **Remote Session Request Lock** (`supabase/migrations/20261028000100_remote_session_concurrency.sql:52`):
  ```sql
  perform pg_advisory_xact_lock(hashtextextended(p_device_id::text, 0));
  ```
  - **Purpose:** Eliminates race conditions where two parents or rapid taps create duplicate concurrent remote sessions on the same child device.
  - Serializes requests per device; automatically released on transaction commit/rollback.
  - Automatically expires stale pending sessions in-lock before checking existing active sessions. If another active session exists, raises `session_in_progress` (HTTP 409).
- **Atomic Pairing Invite Lock** (`supabase/migrations/20260101000600_atomic_pairing_invite.sql:53`):
  ```sql
  perform pg_advisory_xact_lock(hashtextextended(v_code, 0));
  ```
  - Prevents race conditions when redeeming 6-digit pairing invitation codes.

---

## 4. Realtime Performance & Failure Modes Analysis

### 4.1 Duplicate Event Handling & WebRTC Signaling
- **Duplicate Signals:** WebRTC ICE candidates and SDP offers/answers can arrive both from the live WebSocket `postgres_changes` stream and from the initial `_replaySignals` fetch.
  - **Mitigation:** In `lib/features/remote_assistance/remote_session_controller.dart:865-873`, incoming signals pass through `_seenSignalIds.add(signal.id)`. Duplicate signals are dropped before touching the WebRTC peer connection.
- **Duplicate Safety Alerts:**
  - In `lib/features/safety_alerts/safety_alerts_controller.dart:121-135`, incoming alerts are merged via `_merge()`. Existing alerts matched by ID are updated in-place rather than appended.

### 4.2 Reconnection Storms & WebSocket Failure Resilience
- **Channel Teardown & Leak Prevention:**
  - All three realtime streams use `StreamController.broadcast` with `onCancel` handlers (`supabase_alert_repository.dart:136-141`, `supabase_remote_session_repository.dart:290-295`, `391-396`).
  - When the last listener unsubscribes (e.g. view popped), `active.unsubscribe()` and `_supabase.client.removeChannel(active)` are immediately invoked. This guarantees no lingering channel subscriptions or memory leaks.
- **Disconnect / Reconnect Behavior:**
  - Supabase Realtime WebSocket does not infinite-loop reconnect blindly in the repository.
  - In `supabase_alert_repository.dart:100-111`, error statuses (`channelError`, `timedOut`) push an `AppException(network)` onto the stream.
  - In `safety_alerts_controller.dart`, this triggers `isWatching.value = false` and presents a "Live updates disconnected" banner with a "Retry" button (`retryRealtime()`), avoiding reconnect storms on dead networks.
  - In `remote_session_controller.dart:874-900`, WebRTC signaling uses a capped exponential backoff (`[1s, 2s, 4s, 8s, 16s]`) capped at 5 attempts before declaring the session interrupted.

### 4.3 Database Scalability & Sweep Retention
- **Table Retention Limits:**
  - Migration `20261030000300_retention_sweep.sql` implements `run_retention_sweep()`:
    - `webrtc_signals`: Automatically deleted after 7 days.
    - `audit_logs`: Purged after 365 days.
    - `location_events`: Purged after family retention window (default 30 days).
    - `usage_daily`: Purged after family retention window (default 90 days).
  - Deletions are batched in statement-bounded chunks of `10,000` rows using primary key arrays (`id = any(array(select ... limit 10000))`), avoiding long table locks and sequential scan degradation.
- **Abandoned Session Sweep:**
  - Function `expire_abandoned_sessions` (`20261030000100_abandoned_session_sweep.sql`) targets consented sessions left in `accepted`/`active` status older than 24 hours without child activity, freeing child devices from deadlock.

---

## Conclusion & Architecture Assessment

The `parentcontrol_app` Realtime and Telemetry architecture is **exceptionally robust and defensively designed**:
1. It avoids brittle full-duplex WebSocket channels for mission-critical command execution, opting instead for authenticated HTTP polling with backoff (`GuardianService` -> `device-command`), which operates reliably across hostile Android battery optimizations and OEM process killers.
2. Realtime WebSocket subscriptions are scoped strictly to ephemeral, human-facing events (Safety Alerts and WebRTC Session Signaling), protected by topic-level RLS functions and automatic channel disposal.
3. Android native services strictly adhere to modern Android 12, 14, and 15 foreground service policies (`dataSync`, `location`, `microphone`), implementing hardware-backed watchdog routines and graceful timeout handlers.
4. Database integrity is protected by transaction-scoped advisory locks, preventing concurrency bugs during session initiation and device pairing.
