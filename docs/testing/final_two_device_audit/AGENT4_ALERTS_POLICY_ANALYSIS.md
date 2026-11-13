# AGENT 4 — Alerts, Notification Surfaces, Policy State Machine & Enforcement Reality

- **Scope:** source-only, read-only analysis of `D:\parentcontrol_app`.
- **Git state at analysis:** branch `main`, HEAD `5a39747bfaadc2ff79d010db97c7a154f5584f56` (verified with read-only `git rev-parse`; unchanged by this agent).
- **Files touched by this agent:** exactly one — `docs/testing/final_two_device_audit/AGENT4_ALERTS_POLICY_ANALYSIS.md`. No device, ADB, git-state, Supabase or migration operation was performed.
- **Method:** every verdict below is a `path:line` citation from the current source. Claims that could not be cited are explicitly marked `[HYPOTHESIS]`.
- **Adversarial stance:** the prior audit (`docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md`) was treated as a set of assertions to falsify. **Two of its load-bearing assertions are wrong** (§G).

---

## A. Safety alerts (category H)

### A.1 The complete declared surface

`type` is a hosted CHECK constraint — there are exactly **seven** legal values:

```
check (type in ('low_battery', 'offline', 'geofence_enter', 'geofence_exit',
                'app_blocked', 'permission_missing', 'other')),
```
`supabase/migrations/20260101000000_core.sql:302-303`

`severity` has exactly **three** legal values: `supabase/migrations/20260101000000_core.sql:304`
`'info' | 'warning' | 'critical'`.

The Dart model mirrors both enums exhaustively:
- `SafetyAlertType` (7 cases + wire parser + label): `lib/data/models/telemetry.dart:203-248`
- `AlertSeverity` (3 cases + wire parser): `lib/data/models/telemetry.dart:251-266`

The UI can render all seven types and all three severities:
- icon per type (incl. `appBlocked`, `permissionMissing`): `lib/features/safety_alerts/alerts_body.dart:301-317`
- severity filter chips built from `AlertSeverity.values` — **so a "Critical" chip is offered**: `lib/features/safety_alerts/alerts_body.dart:194-199`, label at `:208-216`, tone at `:321-330`
- free-text `message` (1..300 chars) is the primary payload: `supabase/migrations/20260101000000_core.sql:306`, parsed at `lib/data/models/telemetry.dart:256`

### A.2 Exhaustive inventory of `safety_alerts` INSERT paths

`INSERT` into `safety_alerts` exists in **exactly two files**. Full enumeration below (searched across `supabase/functions/**`, `supabase/migrations/**`, `android/app/src/main/**`, `lib/**` for `insert into public.safety_alerts`, `.from("safety_alerts").insert`, `.from('safety_alerts')`):

| # | Writer | Kind | Row(s) it can create |
|---|---|---|---|
| 1 | `supabase/functions/device-telemetry/index.ts:138-147` | Edge Function (`heartbeat`) | `low_battery` / `warning` |
| 2 | `supabase/functions/device-telemetry/index.ts:349-351` | Edge Function (`location_upload`) | `geofence_enter` / `info`, `geofence_exit` / `warning` |
| 3 | `supabase/migrations/20260101000100_functions.sql:555-568` | SQL `private.detect_offline_devices()`, invoked by pg_cron | `offline` / `warning` |

There is **no** Kotlin writer (zero matches for `safety_alerts` under `android/`) and **no** Dart writer. The only Dart touchpoints are a `SELECT` (`lib/data/repositories/supabase_alert_repository.dart:30-35`) and an `UPDATE` of `acknowledged_at` routed through the `family-admin` Edge Function (`lib/data/repositories/supabase_alert_repository.dart:45-57` → `supabase/functions/family-admin/index.ts` action `ack_alert`).

**Architectural proof that a client could never add one:** `authenticated` holds only `grant select on public.safety_alerts` (`supabase/migrations/20260101000200_rls.sql:272`) and the table has exactly one RLS policy, a `for select` policy (`supabase/migrations/20260101000200_rls.sql:173-179`). There is no INSERT policy and no INSERT privilege, so alert creation is *server-only by construction*.

### A.3 Verdict per declared alert type

| `type` | Verdict | Generator / evidence |
|---|---|---|
| `low_battery` | **GENERATED AT RUNTIME** | `supabase/functions/device-telemetry/index.ts:121-148`; trigger = `batteryLevel <= 20 && isCharging === false` (`:121-125`, constants `:29-30`) |
| `offline` | **GENERATED AT RUNTIME, with a hole** | `supabase/migrations/20260101000100_functions.sql:555-568`, scheduled `*/10 * * * *` at `:959-965`. **Gap:** predicate requires `d.last_seen_at is not null` (`:545`) — a device that has *never* heartbeated is never alerted as offline. |
| `geofence_enter` | **GENERATED AT RUNTIME** | `supabase/functions/device-telemetry/index.ts:314-341` (build), `:349-351` (insert) |
| `geofence_exit` | **GENERATED AT RUNTIME** | same block; `type: inside ? "geofence_enter" : "geofence_exit"` at `:326` |
| `app_blocked` | **NEVER GENERATED** | Only occurrences in the entire tree are the schema CHECK (`supabase/migrations/20260101000000_core.sql:303`) and the Dart display maps (`lib/data/models/telemetry.dart:221-222`, `:232-233`; `lib/features/safety_alerts/alerts_body.dart:310-311`). No writer. |
| `permission_missing` | **NEVER GENERATED** | Same: schema CHECK (`supabase/migrations/20260101000000_core.sql:303`) and Dart maps (`lib/data/models/telemetry.dart:223-224`, `:234-235`; `lib/features/safety_alerts/alerts_body.dart:312-313`). The data it would need **is** collected — the heartbeat writes six permission booleans to `devices` (`supabase/functions/device-telemetry/index.ts:96-111`, source `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:502-509`) — and is surfaced *synchronously in the UI* instead (`lib/features/devices/device_presentation.dart:73-82`), but no alert row is ever created from it. |
| `other` | **NEVER GENERATED** (defensive default only) | No writer supplies it. Reachable purely as the Dart fallback for an unrecognised wire value: `lib/data/models/telemetry.dart:226-227`. |

**Prior-audit claim `app_blocked` / `permission_missing` are never generated: CONFIRMED**, and stronger than the prior audit stated — it is not merely that no code path exists, the grant structure forecloses it (`supabase/migrations/20260101000200_rls.sql:173-179`, `:272`).

**New finding not in the prior audit — `severity = 'critical'` is never generated.** The only three severity values written anywhere in the tree are `'warning'` (`supabase/functions/device-telemetry/index.ts:142`, `:327`), `'info'` (`supabase/functions/device-telemetry/index.ts:327`) and `'warning'` (`supabase/migrations/20260101000100_functions.sql:562`). The only occurrences of the literal `'critical'` outside the schema CHECK are the Dart parser and chip label (`lib/data/models/telemetry.dart:257-258`, `lib/features/safety_alerts/alerts_body.dart:214`). Consequence: the parent's "Critical" filter chip (`lib/features/safety_alerts/alerts_body.dart:194-199`) can never match a row; selecting it always lands on the "No alerts with this severity" empty state (`:92`).

### A.4 Safe-zone geofence evaluation — where it lives

**It is in the Edge Function (TypeScript / Deno), i.e. server-side. Not Kotlin, not Dart, not SQL.**

1. **Trigger** — the child device uploads a fix. Native path: `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:592-608` (`uploadPendingLocation`, called on every 10 s tick at `:288`) → `:610-625` (`uploadLocation`, `action: "location_upload"`, `:613`).
   There is a second, Dart-side uploader (`lib/data/repositories/supabase_location_repository.dart:71-93`, `action: 'location_upload'` at `:79`) — **it has no caller in `lib/features/**`** (only the interface declaration at `lib/data/repositories/repository_contracts.dart:141`). It is dead weight; all live geofence evaluation flows through the native uploader.
2. **Geometry** — Haversine, computed in the Edge Function: `supabase/functions/device-telemetry/index.ts:301` (`distanceMeters`, imported `:14`).
3. **Zone source** — `safe_zones` for the device's family with `.eq("active", true)`: `supabase/functions/device-telemetry/index.ts:276-283`.
4. **State** — `safe_zone_states (zone_id, device_id, inside, updated_at)`, PK `(zone_id, device_id)`: `supabase/migrations/20260101000000_core.sql:285-291`. Read at `supabase/functions/device-telemetry/index.ts:287-296`, written by upsert at `:342-347`.

### A.5 Duplicate-event prevention — it exists, and it is transition-based

```
const wasInside = previous.get(zone.id);
if (wasInside === undefined) { /* First sample is a baseline, not a transition. */ ... continue; }
if (wasInside !== inside) { ... alerts.push({ ... type: inside ? "geofence_enter" : "geofence_exit" ... }); }
```
`supabase/functions/device-telemetry/index.ts:303-313` (baseline guard `:304-312`), `:314` (transition test), `:322-341` (alert build)

Three properties follow:

- **A zone the device has always been inside never alerts.** The first sample only seeds state (`:304-312`, comment at `:305`). Correct.
- **Standing still inside a zone never re-alerts.** `wasInside === inside` skips the branch entirely (`:314`).
- **`low_battery` and `offline` use a different, time-window dedupe:** a 6-hour look-back `select ... .gte("created_at", since)` (`supabase/functions/device-telemetry/index.ts:125-137`) and a `not exists (... created_at > now() - interval '6 hours')` (`supabase/migrations/20260101000100_functions.sql:547-552`). Consistent 6 h cooldown for both.

### A.6 Two real geofence defects found (not in the prior audit)

1. **No boundary debounce / rate limit.** Dedupe is purely `wasInside !== inside` (`supabase/functions/device-telemetry/index.ts:314`). A device loitering at `distance ≈ radius_m` with normal GPS accuracy flaps `inside` on each successive fix, and each flap emits an alert (`:322-341`, insert `:349`). The upload cadence is *every tick that carries a new fix* — `GuardianService.kt:595` (`if (fix.timestampMillis <= lastLocationUploadMillis) return`) gates only on freshness, so with a 1 Hz location source this is up to one geofence alert pair per second, unbounded. `low_battery`/`offline` have a 6 h window; geofence alerts have **no** time window at all.
2. **Stale `safe_zone_states` latch on edit / deactivate / reactivate.** The evaluation reads the *existing* state row before comparing (`supabase/functions/device-telemetry/index.ts:287-296`), but nothing resets that row when a parent edits `lat`/`lng`/`radius_m` or toggles `active`. Zone CRUD writes `lat, lng, radius_m, active` directly: `lib/data/repositories/supabase_location_repository.dart:113-133` (grant at `supabase/migrations/20260101000200_rls.sql:149-153`, `:283`). Because zone selection filters on `.eq("active", true)` (`supabase/functions/device-telemetry/index.ts:280`) while the state row survives deactivation, switching a zone off and back on compares the current position against a months-old latch and can fire a spurious `geofence_exit`. `deleteSafeZone` (`lib/data/repositories/supabase_location_repository.dart:140-153`) is the only path that cleans up, via `on delete cascade` (`supabase/migrations/20260101000000_core.sql:288`).

---

## B. Notification surfaces (category I)

### B.1 The four candidate surfaces, resolved

| Surface | Status | Evidence |
|---|---|---|
| **(1) FCM / push** | **NOT IMPLEMENTED — zero code, zero dependency** | `pubspec.yaml` dependency block (`dependencies:` … `dev_dependencies:`) contains no `firebase_messaging`, no `flutter_local_notifications`, no `awesome_notifications`. No `android/app/google-services.json` exists. No `FirebaseMessagingService` and no `android.permission.POST_NOTIFICATIONS`-adjacent messaging service in `android/app/src/main/AndroidManifest.xml`. No `firebase`/`google-services` reference in `android/app/build.gradle.kts`. |
| **(2) Local notifications via a plugin** | **NOT IMPLEMENTED** | No notification plugin in `pubspec.yaml`. Zero Dart matches for `AndroidNotificationChannel`, `flutterLocalNotifications`, `FirebaseMessaging`, `NotificationDetails`. |
| **(3) Foreground-service ongoing notifications** | **REAL — this is the only notification surface in the app** | Exactly three channels, all Kotlin, all `IMPORTANCE_LOW`, all `setOngoing(true)`. See §B.2. |
| **(4) In-app banner** | **EXISTS, but is a generic section widget — not an alert sink** | `lib/core/widgets/info_banner.dart` is a styling component used pervasively for form/state messages (e.g. `lib/features/app_restrictions/app_restrictions_page.dart:336-366`). It is never driven by a `safety_alerts` row outside the Alerts screen. |

### B.2 Every Android notification channel created in Kotlin

| id | name | description | importance | badge | created at | used at |
|---|---|---|---|---|---|---|
| `guardian_status` | `@string/guardian_channel_name` = "Background sync" | "Keeps the device policy and status synchronized while visible." | `IMPORTANCE_LOW` | off | `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:699-713` (id `:36`, notif id 4101 `:37`) | `:715-734` build, `:736-747` `startForeground` (type `DATA_SYNC` on Q+), `:749-753` update |
| `location_sharing` | "Location sharing" | "Shows when this device is sharing its location." | `IMPORTANCE_LOW` | — | `android/app/src/main/kotlin/com/parentcontrol/parent_control/LocationTrackingService.kt:206-218` (id `:33`, notif id 4202 `:34`) | `:229-240` build (`setOngoing(true)` `:236`), `:242-252` `startForeground` |
| `audio_assistance_channel` | "Audio assistance" | "Shows when one-way audio assistance is active." | `IMPORTANCE_LOW` | — | `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt:556-569` (id `:76`, notif id 4303 `:77`) | `:594-610` build (`setOngoing(true)` `:606`), `:620-630` `startForeground` |

String resources: `android/app/src/main/res/values/strings.xml:5-9` (guardian), `:12-15` (location), `:17-20` (audio).

Exact ongoing-notification texts:
- `guardian_notification_title` = "Parent Control"; body "Syncing device status with your family. Tap to review." (`strings.xml:5-6`)
- On any recorded error the *same* notification id 4101 is re-posted with body **"Background sync needs attention. Tap to review."** (`strings.xml:7`, driven from `GuardianService.kt:682-689` → `:749-753`). This is the closest thing in the app to an alert notification, and it concerns the *transport*, not safety events.

All three channels are created with `IMPORTANCE_LOW` and the guardian builder adds `setOnlyAlertOnce(true)` (`android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:731`). **No channel in this app can ever make a sound, vibrate, or light pulse**, and there is no `IMPORTANCE_HIGH`/`DEFAULT_ALL` channel anywhere.

### B.3 Every Dart-side notification path

**There are none.** Method-channel surface (`android/app/src/main/kotlin/com/parentcontrol/parent_control/NativeBridge.kt:121-162`) exposes `areNotificationsGranted` (`:160`) and `getGuardianServiceStatus` (`:133`) — read-only permission/service probes. There is **no** `postNotification` / `showNotification` / `cancelNotification` method on the bridge, so Dart cannot raise a notification by any route.

### B.4 Live-alert delivery actually requires the Alerts screen to be open

`watchAlerts` builds its Realtime channel inside `StreamController.broadcast(onListen: start, ...)` (`lib/data/repositories/supabase_alert_repository.dart:136-142`, `start()` at `:66-120`). The channel therefore exists only while a listener is subscribed, and the sole listener is `SafetyAlertsController._subscribe()` (`lib/features/safety_alerts/safety_alerts_controller.dart:78-90`), called from `onInit` (`:60-64`). `SafetyAlertsController` is a per-route GetX controller (`lib/features/safety_alerts/safety_alerts_binding.dart`), reached from the Alerts tab/page or the dashboard link (`lib/features/dashboard/parent_dashboard_tab.dart:188-192`, route `lib/app/routes/app_routes.dart:21`).

**Consequence:** a `geofence_exit` fired while the parent is anywhere else in the app — or with the app backgrounded or closed — produces **no signal of any kind** until the parent manually opens Alerts. There is no badge, no notification, no push, no polling of `safety_alerts` from the dashboard (`lib/features/dashboard/dashboard_controller.dart:19`, `:73` refresh only the dashboard's own queries). The alert is silently queued in Postgres.

### B.5 The two parent Settings switches — both DEMO ONLY

| Switch | Storage key | Writer | Readers | Verdict |
|---|---|---|---|---|
| **"Show local notifications"** (`lib/features/settings/settings_body.dart:127-137`) | `notifications_enabled` in `SharedPreferences` (`lib/data/services/local_settings_service.dart:10`) | `setNotificationsEnabled` (`lib/data/services/local_settings_service.dart:56-57`), called from `lib/features/settings/parent_settings_controller.dart:147-160` | **Only** `parent_settings_controller.dart:113`, which loads it straight back into the same `RxBool` rendered by the switch (`settings_body.dart:132`) | **DEMO ONLY — a write-only preference.** The *missing reader* is any code that renders a notification: there is no notification-producing code at all (§B.1, §B.3). Toggling it off changes nothing observable beyond the switch position. |
| **"Location sharing reminder"** (`lib/features/settings/settings_body.dart:139-151`) | `location_sharing_enabled` (`lib/data/services/local_settings_service.dart:11`) | `setLocationReminderEnabled` → `_localSettings.setLocationSharingEnabled` (`lib/features/settings/parent_settings_controller.dart:161-176`, `lib/data/services/local_settings_service.dart:60-61`) | **Only** `parent_settings_controller.dart:114`, echoing back into the same switch (`settings_body.dart:146`) | **DEMO ONLY.** No reminder is ever produced. It also does **not** touch the child's actual location switch, which lives under a different key: `child_location_sharing_enabled` (`lib/features/child/services/child_preferences.dart:9`, gate consumers `lib/features/child/controllers/child_shell_controller.dart:708-711`, `:957-964`, `:1001-1002`). So the parent switch is inert *and* cannot accidentally revoke child location. |

Mitigating honesty: the section subtitle states "These switches are local to this phone only. They do not change server authorization, alert creation, or what the child device reports." (`lib/features/settings/settings_body.dart:118-121`), and both subtitles call themselves "A local reminder…" (`:129-131`, `:141-144`). **The labels are honest; the controls are non-functional.** No notification is ever "shown" by either, so both are correctly classified DEMO ONLY with the missing reader being the notification subsystem itself, which does not exist.

---

## C. Policy state machine (category E; defects E-6, E-7, E-11)

### C.1 The full lifecycle, transition by transition

| # | Transition | Code |
|---|---|---|
| 1 | Parent edits draft, presses Save → **fresh** `idempotency_key = uuid.v4()` | `lib/features/app_restrictions/app_restrictions_controller.dart:557-561`; screen-time twin `lib/features/screen_time/screen_time_controller.dart` (same `updatePolicy` call) |
| 2 | `device-policy` Edge Function, action `update` | `lib/data/repositories/supabase_policy_repository.dart:34-61`; `supabase/functions/device-policy/index.ts:53-77` (`rpc("apply_policy_version")` at `:69`) |
| 3 | `apply_policy_version`: row-lock device, replay on idempotency hit, `version = max+1`, INSERT `device_policies`, INSERT `device_commands` (`apply_policy`, `status='pending'`, `expires_at = now() + 900 s`) — one transaction | `supabase/migrations/20260101000100_functions.sql:86-181`; lock `:118-121`; replay `:131-146`; version `:148-152`; policy insert `:154-160`; command insert `:162-176` (TTL `:174`); payload carries `policy_id`, `version`, `policy` `:167-171` |
| 4 | Parent UI begins optimistic polling: 5 s × 6 attempts (30 s ceiling) | `lib/features/app_restrictions/app_restrictions_controller.dart:628-660` (`Timer.periodic(const Duration(seconds: 5))` `:632`, `_pollAttempts > 6` stop `:635-638`); `lib/features/screen_time/screen_time_controller.dart:431-460` |
| 5 | Child **pulls** commands every 20 s (no push — see §E.1) | `android/.../GuardianService.kt:39` (`POLL_INTERVAL_MS = 20_000L`), `:260-277`, `pollCommands` `:360-372` → `device-command` action `poll` |
| 6 | Server atomically expires, claims and returns: `pending → delivered`, `attempts+1`, then returns all `delivered && expires_at > now()` | `supabase/migrations/20260101000100_functions.sql:596-…` (`poll_device_commands`): expire `update … set status='expired'`, claim `set status='delivered', delivered_at=now(), attempts=c.attempts+1`, final select |
| 7 | Child dispatches on `type`; `apply_policy` → `applier.apply(policy, version)` | `android/.../GuardianService.kt:374-416` (`apply` call `:407`) |
| 8 | Apply: parse → compute `desired` → (non-DO: refuse) / (DO: `setPackagesSuspended`) → **re-confirm via DPM** → quota verdict → counters | `android/.../PolicyApplier.kt:38-251`; desired `:64-116`; non-DO refusal `:135-143`; DO suspend `:144-152`; DPM re-confirm `:164-181`; quota `:183-194`; `enforcementSupported` `:219-221`; `success` `:223-226` |
| 9 | Ack: `markCommandHandled` **then** `sendAck` `{action:'ack', command_id, status, result}` | `android/.../GuardianService.kt:475` (mark), `:476-480` (send), `:484-497` (schema) |
| 10 | Server settles the command row, then (only for `type='apply_policy'` with a UUID `payload.policy_id`) computes the verdict | `supabase/functions/device-command/handler.ts:357-381` (update), `:384-425` (reconcile); `decideEnforcement` call `:389-397` |
| 11 | `device_policies` gets `acknowledged_at`, `enforcement_status`, `last_error` | `supabase/functions/device-command/handler.ts:398-409` (`.update({acknowledged_at, enforcement_status: decision.status, last_error: decision.lastError})`) |
| 12 | `devices.policy_version` advances **only** when `advancePolicyVersion` | `supabase/functions/device-command/handler.ts:411-424`; rule `supabase/functions/device-command/enforcement.ts:386` (`status === "enforced" \|\| status === "unsupported"`) |
| 13 | Enforcement status computed | `supabase/functions/device-command/enforcement.ts:462-495` (`decideEnforcement`) |
| 14 | Parent displays | `lib/data/models/device.dart:223-253` (`enforcement_status` → enum → `label`), `lib/features/devices/device_presentation.dart:23-31`/`:58-69`, `lib/features/app_restrictions/app_restrictions_page.dart:333-420`, `lib/features/screen_time/screen_time_page.dart:271-316`, `lib/features/devices/device_detail_page.dart:248-256` |
| 15 | Ongoing re-apply every 60 s from stored policy (no ack) | `android/.../GuardianService.kt:40` (`POLICY_TICK_MS`), `:249-258`; `PolicyApplier.tick()` `:286-289` |

### C.2 E-11 — why a policy can remain permanently `pending`

Five independent mechanisms, ordered by how likely they are to bite. `pending` is *terminal* in every one of them, because nothing in the codebase ever re-drives an unreconciled `device_policies` row: `expire_stale_commands` (`supabase/migrations/20260101000100_functions.sql:575-592`) touches only `device_commands`, is service-role-only (`:902`), takes a single `p_device_id` and is **not scheduled** — the pg_cron block registers only `expire_stale_sessions` and `detect_offline_devices` (`supabase/migrations/20260101000100_functions.sql:949-966`).

**(a) THE EXACT PREDICATE THAT NEVER BECOMES TRUE — `quota.configured` for any bedtime-only policy.**

`policyDeclaresTimeLimits` counts **three** fields: `daily_screen_time_limit_minutes`, `bedtime_start_minutes`, `bedtime_end_minutes` (`supabase/functions/device-command/enforcement.ts:139-149`). But for a policy that names no app, `decideEnforcement` hands the decision entirely to `decideQuotaEnforcement` (`supabase/functions/device-command/enforcement.ts:480`), whose **first** test is

```
if (!quota.configured) {
  return quotaDecision(quota, "pending", "quota_not_configured");
}
```
`supabase/functions/device-command/enforcement.ts:401-403`

`quota.configured` is produced by `QuotaEvaluator.decide(configured = limit != null, …)` where the only input is the daily limit: `android/.../PolicyApplier.kt:422` (`QuotaEvaluator.limitMinutes(policy.dailyScreenTimeLimitMinutes)`) → `:166-167` (`effectiveConfigured`). **Bedtime is never an input to `configured`** (`android/.../policy/QuotaEvaluator.kt:61-62`; `ChildPolicy` keeps bedtime in separate fields — `android/.../policy/PolicyModels.kt:44-49`).

Therefore a bedtime-only policy is written as `timeLimitsConfigured = true` but evaluates to `quota_not_configured` → **`pending`, forever, on every device, including a fully Device-Owner-provisioned one.** Parent-visible label: "Waiting for device" (`lib/data/models/device.dart:244-245`). This is the single cleanest instance of E-11 and it is 100% reproducible without any device fault.

**(b) Lost ack — the child marks the command handled *before* it sends the ack.**
`android/.../GuardianService.kt:475` calls `store.markCommandHandled(commandId)`; `:476-480` then posts the ack inside a `try/catch` whose handler only calls `recordError(...)`. If that POST fails (offline, 401, 5xx), the failure is swallowed. The server leaves the row `delivered` (it never saw the ack), so `poll_device_commands` re-returns it on every subsequent poll (`supabase/migrations/20260101000100_functions.sql` final select of `status = 'delivered' and expires_at > now()`). On receipt the child hits the dedupe guard and **`return`s without acking**:

```
if (store.handledCommands().contains(commandId)) return
```
`android/.../GuardianService.kt:377` (set backed by `SecureStore` FIFO capped at 100 — `android/.../SecureStore.kt:42-43`, `:192-204`)

Net effect: the ack is unrecoverable for the whole 900 s window, then `poll_device_commands` marks the command `expired` — and `device_policies.enforcement_status` is never written at all (the ack branch at `handler.ts:384` is unreachable). Row stays `pending`.

**(c) A device-side exception reports `pending`, not `failed`.**
On any throw in `apply()`, `countsKnown = false` (`android/.../PolicyApplier.kt:236`) so `buildResult` omits `desired_count`/`applied_count`/`failed_count`/`enforcement_supported` entirely (`:504-517`). `success` stays `false` → `GuardianService.kt:409` sends `status = "failed"`. Server side, `readCount` returns null for all three → `countsPresent === false` →

```
if (!countsPresent || !supported) { return { ...base, status: "pending", lastError: … } }
```
`supabase/functions/device-command/enforcement.ts:311-321`

So **`device_commands.status = 'failed'` while `device_policies.enforcement_status = 'pending'`** — two rows, one screen, contradictory story (`lib/features/devices/device_detail_page.dart:248-252` next to `:387-404`).

**(d) Late ack is rejected with HTTP 410 and no policy write.**
`supabase/functions/device-command/handler.ts:339-355`: if `expires_at <= now` and the device did not itself say `"expired"`, the server marks the command `expired` and **throws** — control never reaches the reconciliation at `:384`. The policy row keeps its creation default `'pending'` (`supabase/migrations/20260101000000_core.sql` `device_policies.enforcement_status text not null default 'pending'`).
Note the child's own `"expired"` ack path (`android/.../GuardianService.kt:379-392`) is effectively **dead code**: `poll_device_commands` only returns rows with `expires_at > now()`, so `handleCommand`'s expiry test can only be true under clock skew. Consequently the `command_expired` reason string (`supabase/functions/device-command/enforcement.ts:317-319`; `lib/features/app_restrictions/enforcement_reason.dart:38-40`) is unreachable in practice.

**(e) Recovery paths that do not recover.** When the child returns online, the heartbeat's `pending_policy_version` check (`supabase/functions/device-telemetry/index.ts:46-52` `latestPolicyVersion`, returned `:152-156`; consumed at `android/.../GuardianService.kt:519-522`) fires an immediate poll — but there are no `pending` commands left, so nothing is fetched. The visible "Request sync" button sends `sync_policy` (`lib/features/app_restrictions/app_restrictions_controller.dart:612-618`), and the child responds by applying **its own stored** policy: `applier.applyStoredPolicy()` reads `store.policyJson()` (`android/.../PolicyApplier.kt:253-275`, key `last_policy_json` at `android/.../SecureStore.kt:38`, `:163`). The never-delivered version is not fetched from anywhere, and because the command type is `sync_policy` the reconciliation block at `handler.ts:384` is skipped entirely — so `enforcement_status` stays `pending` while the command happily records `succeeded`. **The one UI affordance offered for this situation cannot fix it and reports success.** The only true repair is to change and re-save the policy (fresh version, fresh UUID idempotency key — `lib/features/app_restrictions/app_restrictions_controller.dart:557-561`).

### C.3 E-6 — bedtime/curfew-only has no observable effect: proven

First, terminology: **"curfew" does not exist in this codebase.** Zero matches for `curfew` across `lib`, `android/app/src/main`, `supabase`. The only time-window features are per-app `app_rules[].windows` (`android/.../policy/PolicyModels.kt:4-35`) and device-wide `bedtime_start_minutes`/`bedtime_end_minutes`.

**The bedtime field's final reader is `PolicyApplier.kt:503`.** Chain, complete:

1. Written by the parent: `lib/features/screen_time/screen_time_controller.dart:363-371` → `updatePolicy` → stored verbatim (`supabase/functions/_shared/policy.ts:204-215` validates and always emits explicit keys; `supabase/migrations/20260101000100_functions.sql:154-160`).
2. Delivered inside the `apply_policy` payload (`supabase/migrations/20260101000100_functions.sql:167-171`) and persisted on-device (`android/.../PolicyApplier.kt:52`, `android/.../SecureStore.kt:163-170`).
3. Parsed into `ChildPolicy.bedtimeStartMinutes/bedtimeEndMinutes`: `android/.../policy/PolicyJson.kt:17-18`.
4. Read by exactly two members, `hasBedtime` and `isWithinBedtime`: `android/.../policy/PolicyModels.kt:47-60`.
5. `hasBedtime` / `isWithinBedtime` have **exactly one call site each** in the entire production tree — the ack field:

```
// Informational only: bedtime is stored but app suspension follows app rules.
result.put("bedtime_active", policy.hasBedtime && policy.isWithinBedtime(TimeUtils.minuteOfDay(calendar)))
```
`android/.../PolicyApplier.kt:502-503`

6. **`bedtime_active` is read by nobody.** A full-tree search for `bedtime_active|bedtimeActive` returns exactly two hits: the write at `android/.../PolicyApplier.kt:503`, and a test fixture string `test/features/app_restrictions/policy_report_correlation_test.dart:13`. It is not in `normalizeQuotaAck` (`supabase/functions/device-command/enforcement.ts:204-271` reads only the `quota` sub-object), not in `decideEnforcement`, not in `PolicyEnforcementReport.fromJson` (`lib/data/models/policy_enforcement.dart:91-108`), not in `QuotaReport.fromResult` (`:198-221`), not in any repository, not in any UI.
7. Decisively, bedtime **cannot** gate an app block even indirectly: `ChildPolicy.isPackageBlockedNow` consults only `enforceAppBlocks`, `appRules`, `blockedPackages`, `allowedPackages` (`android/.../policy/PolicyModels.kt:67-76`) — no bedtime term. The `desired` set is built from it at `android/.../PolicyApplier.kt:64-92`. The quota `targets` set takes only the daily limit (`android/.../PolicyApplier.kt:411-471`).

**Verdict: E-6 PROVEN.** The bedtime value is transported, persisted, parsed, evaluated into a boolean, put on the wire — and then discarded by the receiver. No Android state (`setPackagesSuspended`, `android/.../PolicyApplier.kt:348-360`), no `device_policies` column and no parent-visible string ever changes because of it. The only *observable* effect of setting a bedtime is a side effect of §C.2(a): it permanently pins the policy to `pending`.

The app does disclose this in three places — `lib/features/child/widgets/policy_summary_card.dart:126` ("Daily screen-time limits and bedtime are shown for information only. This Android build enforces app blocks and their schedules, not a system-wide time limit."), `lib/features/child/child_restrictions_page.dart:296`, and `lib/features/app_restrictions/enforcement_reason.dart:16-18`. But the disclosure lives on the *child's* screens and in a reason string; the **parent's** Bedtime editor (`lib/features/screen_time/screen_time_page.dart:376-420`) offers "Set bedtime"/"Clear bedtime" controls with no equivalent warning, and the pending text the parent gets instead is "The limit and bedtime are not active yet." (`:281-283`) — which reads as "still propagating" and never as "will never be active."

### C.4 E-7 — mixed app-block + screen-time can report `enforced` while the quota half is unproven

**The exact aggregation expression is one line:**

```
return { ...app, lastError: app.lastError ?? quota.lastError };
```
`supabase/functions/device-command/enforcement.ts:494`

Precedence in `decideEnforcement` (`:462-495`): app-`failed` wins (`:485`); quota-`failed` wins (`:490`); **everything else returns `app.status` verbatim**, including `advancePolicyVersion` from the app half, with the quota verdict demoted into `lastError` only. Also note the two `… ?? …`-guarded early exits at `:469-474` (`!timeLimitsConfigured || quota === null || ackStatus === "expired"`) which make the whole quota analysis skippable.

Reproducible `enforced`-but-unproven case (Device Owner **is** provisioned, Usage Access is **not** granted, policy blocks one installed app **and** sets a daily limit):
- `enforcementSupported = isOwner && (…)` → `true` (`android/.../PolicyApplier.kt:219-221`), `success = true` (`:223-226`) → ack `succeeded`.
- Quota half: `usageAvailable = UsageReporter.hasAccess(context)` → `false` (`android/.../PolicyApplier.kt:424`) → `quota.usage_available = false` (`:524`) → `supabase/functions/device-command/enforcement.ts:407-409` → `pending / "quota_usage_unavailable"`.
- App half → `enforced` (`:355-360`).
- Neither is `failed` → `:494` → **`enforcement_status = 'enforced'`, `last_error = 'quota_usage_unavailable'`**, and `devices.policy_version` advances (`:386`).

**What the parent then sees — and why it is misleading:**
- Chip + line: **"Enforced on device"** (`lib/data/models/device.dart:246-247`), rendered green (`lib/features/devices/device_presentation.dart:61-63`).
- App Restrictions: `describePolicy` `case enforced` returns "Policy vN enforced on the device — Applied to N of N apps" — it never consults `lastError` (`lib/features/app_restrictions/app_restrictions_controller.dart:723-738`).
- Green success banner, unconditional on `last_error`: "…DevicePolicyManager confirmed every selected app is suspended." (`lib/features/app_restrictions/app_restrictions_page.dart:359-365`). The `enforcementReasonText(lastError)` banner is gated `if (status == PolicyEnforcementStatus.failed)` only (`:403-410`).
- Screen Time: green banner "The device acknowledged this policy version. It must keep Usage Access and the guardian service running for limits to be enforced." (`lib/features/screen_time/screen_time_page.dart:289-297`), and its `describePolicy` `case enforced` likewise ignores `lastError` (`lib/features/screen_time/screen_time_controller.dart:469-471`).
- The Screen Time page has **no quota panel at all** (zero `quota` matches in `lib/features/screen_time/screen_time_page.dart`), so on the screen that *owns* the daily limit the parent gets no per-quota evidence whatsoever.

**Partial mitigation, stated fairly:** the App Restrictions page *does* render a quota panel with a "Device reason" row (`lib/features/app_restrictions/app_restrictions_page.dart:289`, `:296-300`) → `quotaReasonText` → `enforcementReasonText(quotaReport?.reason)` (`lib/features/app_restrictions/app_restrictions_controller.dart:213-217`), which for this case prints "The device could not read today's screen time…" So the information exists, but only on the *other* screen, only one row deep among six, and never in the headline status, banner, or sentence that the parent is actually reading. `enforcement.ts:494`'s own comment — "which is how the parent sees 'apps are blocked, the limit half is only advisory'" (`:491-493`) — is contradicted by the UI, which suppresses `last_error` unless status is `failed`. **E-7 CONFIRMED**, with the sharpened root cause that it is a *display-gate* bug (`app_restrictions_page.dart:403`, `screen_time_page.dart:300`) on top of the *aggregation* bug (`enforcement.ts:494`).

Two adjacent honesty failures found while tracing E-7:
- `supabase/functions/device-command/enforcement.ts:421-423`: with the limit **not** reached, `quota.enforcement_supported === true` yields `"enforced"` with `lastError "quota_below_limit"`. The policy is called enforced on the strength of *being under budget*, which is not evidence that the limit will ever be enforced. On a non-DO device the same line yields `unsupported`/`quota_advisory_only`, correctly.
- `lib/features/screen_time/screen_time_controller.dart:478-479`, `case unsupported`: returns bare "Policy vN is unsupported on this device." and **drops the reason entirely** (no `enforcementReasonText` call, unlike `case failed` at `:472-477`). The companion banner says "The device refused this policy." (`lib/features/screen_time/screen_time_page.dart:310-315`) — but the device never *refused* anything; the server inferred a capability gap.

### C.5 Can `policy_version` acknowledgements go stale / mismatched?

**Version-level: defended. Identity-level: defended. Cross-row: not defended.**

- *Attribution is by `policy_id`, and only that.* `PolicyEnforcementEvidence.correlate` accepts an exact non-blank `payload.policy_id` match, and deliberately rejects timestamps, `version` and `installation_id` as substitutes (`lib/data/models/policy_enforcement.dart:296-314`); an `uncorrelated` report is displayed but never counts as proof (`:336`, `:339-351`). The server writes `policy_id` in the same transaction as the policy row (`supabase/migrations/20260101000100_functions.sql:154-176`), and reconciliation only runs when `isUuid(policyId)` (`supabase/functions/device-command/handler.ts:384-386`). Solid.
- *`provesEnforcement` requires matched-id **and** proving counts*: `lib/data/models/policy_enforcement.dart:336` = `isMatched && report.provesFullEnforcement`, with `provesFullEnforcement` = `enforcementSupported == true && hasCounts && failedCount == 0 && appliedCount == desiredCount` (`:73-77`). So a green "Enforced" claim in App Restrictions needs both (`app_restrictions_page.dart:359`, `provenOnApps`).
- *A stale ack cannot age into proof for a newer version*, because each save mints a new policy row and id (`supabase/migrations/20260101000100_functions.sql:148-160`) and the correlation is by id. `app_restrictions_controller.dart:726-730` even emits an explicit "the device report on file does not name this policy" sentence.

**Three real gaps:**

1. **`device_policies.enforcement_status` is write-once and last-writer-wins-without-guard.** The ack update (`supabase/functions/device-command/handler.ts:398-408`) filters on `id` and `device_id` only — no `enforcement_status = 'pending'` predicate and no version comparison. Combined with `handler.ts:332-334` (a command already in `succeeded|failed|expired` returns early, so the *first* ack settles the command), a re-ack is impossible. This is safe for one command, but **two commands for two versions can settle out of order**: nothing stops a slow ack for v5 (already `delivered`, still inside its 900 s window) from being processed after a fast ack for v6, overwriting the displayed status of v5 while `devices.policy_version` was advanced to v6 by the other path (`:411-424`). `[HYPOTHESIS: reachable only if the child returns v5's ack after v6's — the child processes commands in `created_at asc` order (GuardianService.kt:368-371, poll SQL) so this needs an ack-path failure, i.e. §C.2(b).]`
2. **The device's `applied_version` is set unconditionally before success is known.** `android/.../PolicyApplier.kt:211` (`if (policyVersion != null) store.setAppliedVersion(policyVersion)`) executes ahead of the `success` computation at `:223-226`. So after a *refused* apply on a non-DO device, the local `applied_policy_version` (`android/.../SecureStore.kt:39`, `:172`) still advances to N — while nothing was enforced. That value is then used as the default for subsequent `apply_policy` commands (`android/.../GuardianService.kt:406`) and as the floor for the heartbeat fast-poll (`:519-522`), so the device believes it is current and stops asking. Server `devices.policy_version` and device `appliedVersion()` can therefore agree on a version neither machine enforced.
3. **`ackStatus` is taken from the device's own claim.** `supabase/functions/device-command/handler.ts:311` validates `status ∈ {succeeded, failed, expired}` (`:75`) and `PolicyApplier.buildResult` also puts a raw `success` boolean in `result` (`:496`) — but `decideEnforcement` never cross-checks `result.success` against the counters. It does not need to (the counters drive everything), so this is only a redundant-channel smell, not a live hole.

### C.6 Offline and download-failure behaviour on the child

| Condition | Behaviour | Evidence | Retry? | Give up? | Silent? |
|---|---|---|---|---|---|
| Poll POST fails | exponential backoff ×2 (×6 on 401/403, ×3 on 429), ceiling 300 s; error recorded; ongoing notification switches to "Background sync needs attention" | `android/.../GuardianService.kt:260-277` (multipliers `:267-272`, `coerceAtMost(300_000L)` `:273`), `recordError` `:682-689`, `updateNotification` `:749-753` | **Yes**, forever, with backoff | No | No — visible on the child's notification and in `guardian_last_error` (`android/.../SecureStore.kt:149-156`) |
| Command poll succeeds but policy is absent/malformed (`payload.policy` missing) | `errorMessage` set → ack `failed` | `android/.../GuardianService.kt:401-415` (`:403-404`) | One-shot (acked) | Yes | Server records `failed` + `error_message` (`supabase/functions/device-command/handler.ts:358-368`); policy row → `pending` per §C.2(c) |
| Tick body throws | watchdog re-arms the scheduler every 60 s after 3 missed 10 s ticks, records "Background sync stalled for N s; it was restarted automatically." and emits `guardian_stall_recovered` | `android/.../GuardianService.kt:113-119` (never let a throw kill `scheduleWithFixedDelay`), `:306-358` | **Yes** | No | No — this is genuinely well covered |
| Command TTL elapses while offline | server-side `poll_device_commands` flips `pending|delivered → expired` | `supabase/migrations/20260101000100_functions.sql` (expire update); TTL fixed at 900 s `:174` | — | **Yes, implicitly** | **YES — this is the silent one.** `device_policies` is untouched (no write path exists outside the ack at `supabase/functions/device-command/handler.ts:398-409`), so the policy reads "Waiting for device" indefinitely. See §C.2(d,e). |
| Ack POST fails after successful apply | `markCommandHandled` already ran; error recorded, never re-sent | `android/.../GuardianService.kt:475-480` | **No** | Yes | Partially silent on the child (one error string); fully invisible to the parent |
| 60 s re-apply (`tick`) fails | errors surfaced via `recordError`, but **no ack is ever sent** for a tick | `android/.../GuardianService.kt:249-258`, `PolicyApplier.tick()` `:286-289` (calls `apply(null)`; the ack belongs to `handleCommand` only) | Every 60 s locally | — | Server never learns; the parent's counts stay whatever the single accepted ack said |
| Android kills the FGS on time limit (API 34+) | `onTimeout` → record "Android stopped background sync because its time limit was reached. Open Parent Control to resume it." → `stopSelf()` | `android/.../GuardianService.kt:191-209` | No auto-resume | **Yes** | Honest and surfaced, but requires a human to reopen the app |

---

## D. Enforcement reality without Device Owner

### D.1 Device Owner is unobtainable in-app — confirmed

- `android_dpc/` **is an empty directory** (`ls -R android_dpc` → no files). There is no Device Policy Controller APK in this repository, so the `adb shell dpm set-device-owner` flow has no target component to promote. (Matches `docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md` §1: "no DPC exists".)
- Device Admin grants **nothing**: `android/app/src/main/res/xml/device_admin.xml` is `<uses-policies />` with the explicit comment "App suspension is a Device Owner capability and must never be applied without it."
- `setPackagesSuspended` is the only mutation attempted, and it is reachable only under `isOwner`: `android/.../PolicyApplier.kt:144-152`, `:348-360`; `isDeviceOwner()` is `devicePolicyManager.isDeviceOwnerApp(context.packageName)` (`:333-338`).

### D.2 `PolicyApplier` early-return paths and the resulting counter triple

| Situation | Path | `desired_count` | `applied_count` | `enforcement_supported` | `success` → ack status |
|---|---|---|---|---|---|
| **Not DO, ≥1 eligible app to block** — *the case in question* | `PolicyApplier.kt:135-143` (`desiredCount > 0 && !isOwner`): target set deliberately **kept**, `errors +=` "Device Owner provisioning is required…", `unsupported.addAll(appDesired)`; re-confirm loop `:168-174` adds a per-package failure; `:219-221` false; `:223-226` false | `N` (`:116`) | **0** (`:213-214`) | **false** (`isOwner && …` short-circuits, `:219`) | false → `"failed"` (`GuardianService.kt:409`) |
| Not DO, blocked app **not installed** | `PolicyApplier.kt:87-90` → `unsupported.add`, `continue` (no `failures` entry) → `desiredCount == 0`, no error | `0` | `0` | false | true → `"succeeded"` |
| Not DO, target is self / protected system component | `PolicyApplier.kt:66-71` / `:73-86` → `failures[pkg]` set → **counted in the denominator** (comment `:112-115`) | `N` | `0` | false | false |
| Not DO, nothing to restore | `PolicyApplier.kt:153-161` — silent branch | 0 | 0 | false | true |
| DO, suspend call accepted + DPM confirms | `PolicyApplier.kt:144-152` + `:164-181` | `N` | `N` | **true** | true |
| DO, `SecurityException` from `setPackagesSuspended` | `PolicyApplier.kt:348-360` (`:353-355`) | `N` | `<N` | `suspendCallSucceeded=false`; true only if `applied==appDesired` (`:219-221`) | false |
| Any throw | `PolicyApplier.kt:227-237`, `countsKnown=false` | *absent* | *absent* | *absent* | false |

Crucially, the non-DO branch comments its own intent — *"Never clear the target set: the ack has to say desired=N, applied=0, supported=false so the server can record 'unsupported' instead of a false 'enforced'"* (`android/.../PolicyApplier.kt:136-138`) — and `GuardianService.kt:543` likewise reports `is_suspended = owner && applier.isSuspended(pkg)` rather than claiming a block. Also `PolicyApplier.kt:320-331` re-queries DPM for every confirmation and returns `false` on `SecurityException`/`IllegalArgumentException`. **The native layer does not lie.**

### D.3 What actually happens to the child's Android state

**Nothing at all.** `setPackagesSuspended` is never invoked (`PolicyApplier.kt:144` is the only call site, guarded by `isOwner`); no package is suspended, no `SecurityException` is even provoked; `isPackageSuspended` returns false for every target (`:320-331`), so `tracked` stays empty (`:164-181`) and `store.setSuspendedPackages(emptySet())` (`:180`). Instagram launches exactly as before. `enforcement_mode` reported to the server is `"device_admin"` if admin is active else `"none"` (`android/.../EnforcementMode.kt:22-26`, via `GuardianService.kt:668-670`) — and per §D.1, an active admin confers no capability. The 60 s tick repeats this no-op forever (`PolicyApplier.kt:286-289`).

The only *observable* device-side effect is on the parent's app snapshot: `is_suspended` stays `false` for every package (`GuardianService.kt:543`).

### D.4 What the parent UI displays for that outcome — per enforcement mode the code can report

Server verdict for the primary row of §D.2: `enforcement_supported === false` hits the first branch of `decideAppEnforcement` (`supabase/functions/device-command/enforcement.ts:302-309`) → `status = "unsupported"`, `lastError = "device_owner_required"`, `advancePolicyVersion = true`. (The app-level `enforcement_supported` wins over `quota`, and `quota` cannot rescue it: mixed + `targetsApps` → `enforcement.ts:494` returns the app status.) The hosted enum is exactly `'pending'|'enforced'|'failed'|'unsupported'` (`supabase/migrations/20260101000000_core.sql` `device_policies` CHECK; `partially_enforced` is refused, as `enforcement.ts:369-372` documents).

| Reported mode | `enforcement_status` | Exact user-visible strings (verbatim) | Source | Honest? |
|---|---|---|---|---|
| `none` or `device_admin` (child **not** DO) | `unsupported` | Chip/row: **"Not supported on device"** · `lib/data/models/device.dart:250-251` | | **HONEST** |
| ″ | ″ | Device-detail line: "Policy vN cannot be enforced on this device. App blocking requires Device Owner." | `lib/features/app_restrictions/app_restrictions_controller.dart:745-749` | **HONEST** |
| ″ | ″ | Banner: **"Unsupported on this device"** — "App blocking requires Device Owner. This installation cannot enforce restrictions. The device reported 0 applied apps, so no restriction is proven active." | `lib/features/app_restrictions/app_restrictions_page.dart:346-358` + `lib/data/models/policy_enforcement.dart:88-89` | **HONEST — and explicitly refuses to imply a block** |
| ″ | ″ | Device-detail banner: "The device refused this policy because enforcement is not available. Set the phone up as a fully managed device to suspend apps." | `lib/features/devices/device_detail_page.dart:279-288` | **MOSTLY HONEST**; "the device refused" mis-attributes a *server-inferred capability verdict* to a device decision. The device refused nothing — it reported counts. |
| ″ | ″ | Screen-time banner: "The device refused this policy. Screen-time enforcement depends on device support and permissions." + sentence "Policy vN is unsupported on this device." (reason dropped) | `lib/features/screen_time/screen_time_page.dart:308-316`, `lib/features/screen_time/screen_time_controller.dart:478-479` | **MISLEADING on two counts** — "the device refused" (same mis-attribution) and the reason token `device_owner_required` is silently discarded, unlike the `failed` branch at `:472-477` |
| ″ | ″ | Enforcement mode label: "Not enforced" / "Device admin only" | `lib/features/devices/device_presentation.dart:7-18` | **HONEST** |
| ″ | ″ | Child side: "Not managed — app blocking is not available"; per-app "Not verified" | `lib/features/child/models/child_enforcement.dart:33-36` (+ child shell strings) | **HONEST** |
| `device_owner`, app half OK, **Usage Access missing** | **`enforced`** with `last_error = quota_usage_unavailable` | **"Enforced on device"** + green "…DevicePolicyManager confirmed every selected app is suspended." + "Policy vN enforced on the device — Applied to N of N apps"; **no `last_error` shown** (gated to `failed`) | `lib/data/models/device.dart:246-247`, `lib/features/app_restrictions/app_restrictions_page.dart:359-365`, `:403-410`, `lib/features/app_restrictions/app_restrictions_controller.dart:731-738` | **MISLEADING — this is E-7.** App half is genuinely proven; the screen-time half in the same policy is not, and the headline says "enforced" |
| any | `pending` | **"Waiting for device"** + "The policy is saved on the server but this device has not confirmed applying it yet. No restriction is active until the device acknowledges." | `lib/data/models/device.dart:244-245`, `lib/features/devices/device_detail_page.dart:265-274` | **HONEST WORDING, WRONG MODEL.** For every §C.2(a) and §C.2(d,e) case this is not a transient wait — it is the terminal state. "Waiting for device" promises motion that will never happen |

### D.5 Raw-token leak (new, not in the prior audit)

`lib/features/devices/device_detail_page.dart:258-263` prints `policy!.lastError!` **verbatim** in danger colour. So on Device Detail the parent sees `device_owner_required`, `quota_not_configured`, `enforcement_counts_missing`, `suspended 0 of 3` — internal server tokens — while App Restrictions and Screen Time run the same value through the parent-facing translator `enforcementReasonText` (`lib/features/app_restrictions/enforcement_reason.dart:15-46`, `:63-91`). Two screens, same field, two registers; one of them is machine-readable. (The translator itself is well built — an unmapped token is deliberately shown as-is rather than swallowed, `:88-90`, and `quota_suspended A of B` / `suspended A of B` are parsed at `:70-86`.)

**Bottom line for D:** with Device Owner unprovisionable, "block Instagram" changes **nothing** on the child's Android state, and the reporting chain is accurate about it (`unsupported` / "Not supported on device" / "no restriction is proven active"). The genuine dishonesty in this area is not in the app-block path — it is (i) the `enforced`+unproven-quota combination of §C.4/D.4, (ii) "Waiting for device" presented as transient when it is terminal, and (iii) "the device refused this policy" attributing a server inference to the device.

---

## E. Command history, audit, and realtime (category L)

### E.1 Definitive realtime publication list

The only place the publication is configured is one guarded `DO` block:

```
supabase/migrations/20260101000100_functions.sql:907-944
  :917  alter publication supabase_realtime add table public.device_commands
  :924  alter publication supabase_realtime add table public.safety_alerts
  :931  alter publication supabase_realtime add table public.remote_sessions
  :938  alter publication supabase_realtime add table public.webrtc_signals
```

| Table | In publication? | Citation |
|---|---|---|
| `device_commands` | **YES** | `supabase/migrations/20260101000100_functions.sql:913-918` |
| `safety_alerts` | **YES** | `:920-925` |
| `remote_sessions` | **YES** | `:927-932` |
| `webrtc_signals` | **YES** | `:934-939` |
| `device_policies` | **NO** — never appears in the block | absence across `:907-944` |
| `audit_logs` | **NO** — never appears | absence across `:907-944` |

`supabase/config.toml:34-35` only sets `[realtime] enabled = true`; there is no other publication config. The whole block is conditional on `pg_publication 'supabase_realtime'` existing (`:911`) and otherwise just `raise notice`s (`:940-941`) — so on a plain PostgreSQL test DB **nothing** is published, which is likely how the prior audit concluded "not published". **Also note: no migration anywhere sets `REPLICA IDENTITY`** (zero matches for `REPLICA IDENTITY` under `supabase/`), so `UPDATE`-event payloads like `safety_alerts.acknowledged_at` (`lib/data/repositories/supabase_alert_repository.dart:90-99`) rely on the default replica identity carrying only the PK — `SafetyAlert.fromJson(payload.newRecord)` there would receive a near-empty record. `[HYPOTHESIS: Postgres default REPLICA IDENTITY = DEFAULT emits full OLD/NEW for UPDATEs when no replica identity is set, so this is fine; the risk is only if a deployment sets `REPLICA IDENTITY NOTHING` for volume. Flagged, not asserted.]`

### E.2 What the client actually subscribes to

Exactly **three** Realtime channels, all `private: true`, all `onPostgresChanges`:
1. `safety_alerts` — `insert` + `update` filtered on `family_id`: `lib/data/repositories/supabase_alert_repository.dart:60-143` (channel `:70-73`, filter `:75-79`, insert `:80-89`, update `:90-99`)
2. `remote_sessions`: `lib/data/repositories/supabase_remote_session_repository.dart:230-247`
3. `webrtc_signals`: `lib/data/repositories/supabase_remote_session_repository.dart:334-360`

**`device_commands` is published by the server and subscribed to by nobody.** A tree-wide search for `onPostgresChanges` / `.channel(` in `lib/` yields only the three sites above. So the prior audit's *functional* conclusion is right for the wrong reason: policy/command traffic is pull-only not because the publication omits `device_commands`, but because the client never opens a channel on it — and even if it did, `poll_device_commands` mutates `pending → delivered` via a service-role SQL function whose `UPDATE` is what would surface, not an `INSERT`, so a client `INSERT` subscription would see the row at creation time without the claim semantics (`supabase/migrations/20260101000100_functions.sql` `poll_device_commands`), i.e. it would not replace the poll.

The private-topic allowlist `private.realtime_topic_allowed` (`supabase/migrations/20260101000200_rls.sql:295-334`) governs `realtime.messages` broadcast topics (`:338-356`) and admits only `safety-alerts`, `remote-session-family`, `remote-session`, `webrtc-signals` (`:320-330`) — it has no bearing on `postgres_changes`, which is why `device_commands` can be published yet unused.

### E.3 "Refresh policy state" — what it reads, and what it does not

There are three distinct `refreshPolicy` implementations; **none of them sends a command or triggers a device poll.** All are plain read-only `SELECT`s against `device_policies`:

| Screen | Method | Reads | Also re-reads commands? |
|---|---|---|---|
| Device Detail | `lib/features/devices/device_detail_controller.dart:119-129` | `_policyRepository.fetchLatestPolicy(deviceId)` only | **NO** — `recentCommands` is only populated by `load()`/`_loadPolicyAndCommands()` (`:100-115`). Pressing "Refresh policy state" (`lib/features/devices/device_detail_page.dart:306-314`) updates the Policy card while the **command history below it silently goes stale** |
| App Restrictions | `lib/features/app_restrictions/app_restrictions_controller.dart:583-603` | `fetchLatestPolicy` + `_loadEnforcementReport(policy)` (`:667-709`, which reads `fetchRecentCommands(deviceId, limit: 10)` at `:672-674`) | Yes |
| Screen Time | `lib/features/screen_time/screen_time_controller.dart:415-430` | `fetchLatestPolicy` + payload re-draft | No quota read (Screen Time has no quota panel) |

Underlying queries — both direct PostgREST reads under RLS, no Edge Function:
- `lib/data/repositories/supabase_policy_repository.dart:22-31`: `.from('device_policies').select().eq('device_id', …).order('version', desc).limit(1).maybeSingle()`
- `lib/data/repositories/supabase_policy_repository.dart:64-78`: `.from('device_commands').select().eq('device_id', …).order('created_at', desc).limit(20 default; 10 from the UI)`

**Does the parent have to poll? Yes, unavoidably, on both clocks:**
1. The child only learns of a new policy on its next poll (20 s best case; `android/.../GuardianService.kt:39`, `:260-277`), accelerated to "immediately" only by the heartbeat path at `:519-522` (≤5 min, `:41`). Nothing is pushed to the child.
2. The parent's optimistic window is **30 seconds total** — 5 s × 6 attempts (`lib/features/app_restrictions/app_restrictions_controller.dart:632-638`, `lib/features/screen_time/screen_time_controller.dart:435-441`) — and it *cancels itself* as soon as status leaves `pending` (`app_restrictions_controller.dart:645-651`). Any child slower than ~30 s (backoff after one failed poll puts the next attempt at 40 s, `GuardianService.kt:273`) lands the parent back on a manual button. The dashboard/device list do have 60 s auto-refresh for devices (`lib/features/dashboard/dashboard_controller.dart:19`, `:73`; `lib/features/devices/devices_controller.dart:18`, `:63`), but that refreshes `devices`, not `device_policies`.

### E.4 Command history rendering

`lib/features/devices/device_detail_page.dart:378-405` — one `ListTile` per command: `command.type.label`, then `'${command.status.label} · ${relativeTime(command.createdAt)}'` plus `command.error` when present (`:400-403`). Labels are complete and truthful — "Queued" / "Delivered" / "Succeeded" / "Failed" / "Expired" (`lib/data/models/device.dart:~255-290`, `DeviceCommandStatus.label`). One cosmetic flaw: the icon ternary at `:391-398` gives `expired` the same `hourglass_empty` + muted treatment as `pending`/`delivered`, so a dead command *looks* pending even though the text says "Expired".

`audit_logs` is read-only for the parent (`lib/data/repositories/supabase_audit_repository.dart:27-29`, `grant select on public.audit_logs to authenticated` at `supabase/migrations/20260101000200_rls.sql:274`), is not realtime-published (§E.1), and its controller sets up **no** timer or subscription (zero `Timer.periodic`/`watch` matches in `lib/features/audit_logs/`). Command lifecycle events *are* audited (`command_created` `supabase/functions/device-command/handler.ts:224-232`/`:278-286`; `command_acked`/`command_failed` `:428-435`) and policy saves are (`policy_updated` `:212-223`), so the ledger is a genuine, if pull-only, history. Alert acknowledgement is audited too (`family-admin` `ack_alert` → `eventType: "alert_acknowledged"`).

---

## F. Prioritized defect list

Severity key: **S1** = advertised behaviour silently does nothing / false claim of safety; **S2** = wrong or materially incomplete information shown to a parent; **S3** = real but bounded or self-disclosed; **S4** = cosmetic/hygiene.

| ID | Defect | User-visible symptom | Root cause `file:line` | Sev | Minimal fix (describe only) |
|---|---|---|---|---|---|
| **A1** | `app_blocked` alert never generated | The alert list can never tell a parent "an app restriction bit"; the type exists in the schema, the enum, the label map and the icon map | declared `supabase/migrations/20260101000000_core.sql:303`; rendered `lib/data/models/telemetry.dart:221-222`, `lib/features/safety_alerts/alerts_body.dart:310-311`; **no writer** | **S1** | In the `apply_policy` ack reconciliation, insert one `app_blocked` alert when `decision.status === 'enforced' && app.appliedCount > 0`, deduped per `(device, package, day)` like `low_battery`. Alternatively delete the enum member, the Dart case, the label and the icon so the surface stops advertising it. |
| **A2** | `permission_missing` alert never generated, although all the input data arrives every heartbeat | Guardian permissions degrade (Usage Access revoked ⇒ screen-time dies, Notifications revoked ⇒ the FGS refuses to start `android/.../GuardianService.kt:148-152`) with **no** alert; parent only notices if they open Device Detail | permission booleans written `supabase/functions/device-telemetry/index.ts:96-111`; source `android/.../GuardianService.kt:502-509`; UI-derives-instead `lib/features/devices/device_presentation.dart:73-82`; type declared `supabase/migrations/20260101000000_core.sql:303` | **S1** | In `heartbeat`, after the `devices` update, compare the six permission columns to their previous values and insert a `permission_missing` alert on any `true → false` edge, with a 6 h window mirroring `supabase/functions/device-telemetry/index.ts:125-137`. |
| **C1** | **Bedtime is a no-op end to end** (E-6) | Parent sets a bedtime; child's Android state never changes; policy pins to `pending`; the control stays offered and re-saved forever | final reader writes an unread ack field `android/.../PolicyApplier.kt:502-503`; **`bedtime_active` consumed nowhere** (only `test/features/app_restrictions/policy_report_correlation_test.dart:13`); cannot gate blocks `android/.../policy/PolicyModels.kt:67-76` | **S1** | Pick one: (a) implement it — when `isWithinBedtime` and DO, union `quotaTargetPackages(...)` into `desired` in `PolicyApplier.kt:117-132` and add `bedtime_*` to the `quota` ack object + `decideQuotaEnforcement`; or (b) **remove** `bedtime_start_minutes`/`bedtime_end_minutes` from the policy model, the validator (`supabase/functions/_shared/policy.ts:204-215`), the Bedtime UI (`lib/features/screen_time/screen_time_page.dart:376-420`) and `policyDeclaresTimeLimits` (`supabase/functions/device-command/enforcement.ts:141-145`). (b) is the smaller, honest change. |
| **C2** | **Bedtime-only policy is permanently `pending`, even on a Device-Owner device** (E-11 primary) | "Waiting for device" / "The limit and bedtime are not active yet." never clears; 30 s optimistic polling gave up; "Refresh policy state" re-reads the same `pending` | `supabase/functions/device-command/enforcement.ts:401-403` tests `quota.configured`, which derives **only** from the daily limit (`android/.../PolicyApplier.kt:422`, `android/.../policy/QuotaEvaluator.kt:61-62`) while `:139-149` declares time limits from three fields; dispatch `supabase/functions/device-command/enforcement.ts:480` | **S1** | Either stop letting bedtime enter `policyDeclaresTimeLimits` (align the two vocabularies), or give the `quota` ack block explicit bedtime fields and a bedtime branch in `decideQuotaEnforcement` that can reach a terminal verdict. |
| **C3** | **Lost ack is unrecoverable ⇒ `pending` forever** (E-11) | Policy saved, device online, restriction actually applied locally — parent sees "Waiting for device" indefinitely | `markCommandHandled` before the send `android/.../GuardianService.kt:475-480`; re-delivery then short-circuits without acking `:377`; dedupe set `android/.../SecureStore.kt:42-43`, `:192-204` | **S1** | Move `markCommandHandled(commandId)` to *after* a successful `sendAck`, and on ack failure skip the `handledCommands` guard for still-`delivered` commands so the re-delivery re-acks. (`apply` is idempotent — `PolicyApplier.kt:164-181` re-confirms against DPM — so re-running is safe.) |
| **C4** | **`sync_policy` reports success without repairing the un-delivered version** | Parent presses "Request sync", sees the command `Succeeded`, but `enforcement_status` is unchanged and the device applied its *old* stored policy | `lib/features/app_restrictions/app_restrictions_controller.dart:612-618`; child applies `store.policyJson()` `android/.../PolicyApplier.kt:253-275` (key `android/.../SecureStore.kt:38`); reconciliation only runs for `apply_policy` `supabase/functions/device-command/handler.ts:384` | **S2** | Have `sync_policy` first fetch the newest `device_policies` row for the device (it already knows `pending_policy_version` from `supabase/functions/device-telemetry/index.ts:46-52`, `:152`) and apply *that*, or make "Request sync" create a fresh `apply_policy` command carrying the current version. |
| **C5** | **Mixed policy shows a green "Enforced" while the quota half is unproven** (E-7) | App + daily-limit policy on a DO device without Usage Access ⇒ headline "Enforced on device", green "DevicePolicyManager confirmed every selected app is suspended", screen-time half doing nothing, no caveat on the Screen Time screen | aggregation `{ ...app, lastError: … }` `supabase/functions/device-command/enforcement.ts:494`; `display gate`s `last_error` to `failed` only — `lib/features/app_restrictions/app_restrictions_page.dart:403-410`, `lib/features/app_restrictions/app_restrictions_controller.dart:731-738`, `lib/features/screen_time/screen_time_page.dart:289-297`, `lib/features/screen_time/screen_time_controller.dart:469-471`; Screen Time has no quota panel at all | **S2** | Append the translated `enforcementReasonText(policy.lastError)` to the `enforced` sentence/banner when `last_error` is non-null (one guard per screen). Larger fix: stop the aggregation from discarding a `pending`/`unsupported` quota half into a bare `enforced`. |
| **C6** | Device exception lands as `pending`, not `failed` | `device_commands.status = 'failed'` with `error_message`, side by side with `device_policies` "Waiting for device" on the same card | `countsKnown = false` suppresses the counters `android/.../PolicyApplier.kt:236`, `:504-517`; `!countsPresent || !supported ⇒ pending` `supabase/functions/device-command/enforcement.ts:311-321`; both surfaces `lib/features/devices/device_detail_page.dart:248-252`, `:387-404` | **S2** | In `buildResult`, always emit the counters (zeros plus `enforcement_supported=false` is honest) even on the exception path, or map `ackStatus === 'failed' && !countsPresent ⇒ 'failed'` in `decideEnforcement`. |
| **C7** | A blocked app that is simply not installed pins the policy to `pending` | Parent blocks an app the child never installed ⇒ "Waiting for device" forever, `desired=0` | `android/.../PolicyApplier.kt:87-90` adds to `unsupported` but not to `failures`, so `desiredCount == 0` (`:116`) ⇒ `input.targetsApps && desiredCount === 0 ⇒ pending / "no_apps_suspended"` `supabase/functions/device-command/enforcement.ts:323-331` | **S2** | Treat "not installed" as a settled outcome: `unsupported`-class terminal verdict with the existing `enforcement_reason.dart:35-37` text, rather than a retryable `pending`. |
| **A3** | Geofence alerts have no debounce/rate limit | GPS flap at a zone boundary can emit an `exit`/`enter` alert pair per fix — up to ~1/s — drowning the Alerts list and the 6 h-deduped battery/offline alerts | transition test only `supabase/functions/device-telemetry/index.ts:314`; per-new-fix upload cadence `android/.../GuardianService.kt:288`, `:592-608`; contrast the 6 h windows `:125-137` and `supabase/migrations/20260101000100_functions.sql:547-552` | **S2** | Add a per-`(device, zone)` cooldown constant mirroring `LOW_BATTERY_WINDOW_HOURS`, and require two consecutive same-direction samples before flipping `safe_zone_states.inside`. |
| **A4** | Stale `safe_zone_states` latch on zone edit/deactivate | Parent edits a zone's radius or toggles `active` off/on; child gets a spurious "Left safe zone X." on the very next fix | evaluation reads the prior latch `supabase/functions/device-telemetry/index.ts:287-296`, `:303-314`; zones filtered `.eq("active", true)` `:280`; zone rows edited/deactivated with no state reset `lib/data/repositories/supabase_location_repository.dart:113-133`; latch cleanup only via `on delete cascade` `supabase/migrations/20260101000000_core.sql:288` | **S3** | On any `safe_zones` UPDATE touching `lat/lng/radius_m/active`, delete that zone's `safe_zone_states` rows so the next sample re-baselines via the `wasInside === undefined` branch. |
| **A5** | `offline` alert never fires for a device that has never heartbeated | A freshly paired child that never syncs — precisely the broken case — produces no alert at all; parent sees only "Offline" in the device list | `and d.last_seen_at is not null` `supabase/migrations/20260101000100_functions.sql:545` | **S3** | Broaden to `last_seen_at is null and created_at < now() - interval '15 minutes'`, keeping the `not exists` window at `:547-552`. |
| **A6** | `severity = 'critical'` never generated | The Alerts screen offers a "Critical" filter chip that can never return a row ⇒ "No alerts with this severity" | chip from `AlertSeverity.values` `lib/features/safety_alerts/alerts_body.dart:194-199`, `:214`, empty state `:92`; parser `lib/data/models/telemetry.dart:257-258`; declared `supabase/migrations/20260101000000_core.sql:304`; only `info`/`warning` ever written `supabase/functions/device-telemetry/index.ts:142`, `:327`, `supabase/migrations/20260101000100_functions.sql:562` | **S3** | Emit `critical` for `geofence_exit` (the one event a parent acts on), or drop the chip until a producer exists. |
| **B1** | **No push, no local notifications, no audible channel, no background alert surface** — 3 of the 4 candidate surfaces are absent | Safety alerts are delivered only if the parent happens to have the Alerts screen open; otherwise they sit unread in Postgres with zero signal. "Location sharing reminder" and "Show local notifications" promise a notification subsystem that does not exist | no `firebase_messaging`/`flutter_local_notifications` in `pubspec.yaml` (`dependencies:` block); no `android/app/google-services.json`; no messaging service in `android/app/src/main/AndroidManifest.xml`; channel creation only in three FGSes (`GuardianService.kt:699-713`, `LocationTrackingService.kt:206-218`, `AudioAssistanceService.kt:556-569`), all `IMPORTANCE_LOW`; bridge exposes no notification method `android/.../NativeBridge.kt:121-162`; **channel is `onListen`-scoped** `lib/data/repositories/supabase_alert_repository.dart:136-142`, sole listener `lib/features/safety_alerts/safety_alerts_controller.dart:78-90`, `:60-64` | **S1** *(product gap, not a code fault)* | Either wire FCM behind the existing `notifications_granted` capability, or rename the Settings switches to say plainly that reminders are not delivered and remove them. Do not ship the current labels without one of the two. |
| **B2** | Both parent Settings switches are write-only (confirmed DEMO ONLY) | Toggling either persists a `SharedPreferences` bool and moves the thumb; nothing else in the process ever reads it | key `notifications_enabled` `lib/data/services/local_settings_service.dart:10`, `:55-57` — sole reader `lib/features/settings/parent_settings_controller.dart:113`, re-rendered `lib/features/settings/settings_body.dart:127-137`; key `location_sharing_enabled` `:11`, `:59-61` — sole reader `parent_settings_controller.dart:114`, re-rendered `settings_body.dart:139-151`; child's real switch is a different key, `lib/features/child/services/child_preferences.dart:9` | **S2** | Delete both switches (and both keys), or give them one real consumer each — e.g. gate the alerts screen's banner on `notifications_enabled`. |
| **D1** | "The device refused this policy" mis-attributes a server inference to the device | Parent believes the child *declined*; in fact the server inferred a capability gap from counters and the device was never asked | `lib/features/devices/device_detail_page.dart:279-288`, `lib/features/screen_time/screen_time_page.dart:310-315`; contrast the accurate App Restrictions wording `lib/features/app_restrictions/app_restrictions_controller.dart:745-749` | **S3** | Reword to "This device can't enforce it — app blocking needs Device Owner." and route Screen Time's `unsupported` case through `enforcementReasonText(policy.lastError)` like its `failed` case already does (`lib/features/screen_time/screen_time_controller.dart:472-477`). |
| **D2** | Raw reason tokens leak to parents on Device Detail | Parent reads `device_owner_required` / `quota_not_configured` / `suspended 0 of 3` as red text, while the sibling screens show sentences | `lib/features/devices/device_detail_page.dart:258-263` prints `policy!.lastError!` un-translated, vs. `lib/features/app_restrictions/app_restrictions_page.dart:409` and `lib/features/screen_time/screen_time_page.dart:302` which wrap it in `enforcementReasonText` (`lib/features/app_restrictions/enforcement_reason.dart:63-91`) | **S4** | Wrap the one call site in `enforcementReasonText`. |
| **E1** | **"Refresh policy state" is a single stale-tolerant `SELECT`** and leaves the command list below it stale | Parent presses Refresh, Policy card updates, command history still shows pre-refresh statuses ⇒ a screen that contradicts itself | `lib/features/devices/device_detail_controller.dart:119-129` (policy only) vs `:100-115` (`_loadPolicyAndCommands`); button `lib/features/devices/device_detail_page.dart:306-314`; underlying read `lib/data/repositories/supabase_policy_repository.dart:22-31` | **S2** | Call `_loadPolicyAndCommands()` from `refreshPolicy()`. |
| **E2** | Parent's post-save feedback window is 30 s and self-cancelling, against a child whose best-case round trip is ~20–25 s and whose backoff floor after one miss is 40 s | "Saved" reverts to "Waiting for device" and stays there until the parent finds a manual button | 5 s × 6 `lib/features/app_restrictions/app_restrictions_controller.dart:632-638`, cancel-on-settle `:645-651`; same `lib/features/screen_time/screen_time_controller.dart:435-441`; child backoff `android/.../GuardianService.kt:260-277` (`:273` `coerceAtMost(300_000L)`) | **S2** | Keep polling while `pending` with a decaying interval and a hard cap, and say so in the banner ("checking for up to N minutes"). |
| **E3** | Prior audit's realtime premise is wrong: `device_commands` **is** published | (Documentation/audit accuracy, not a product symptom) | `supabase/migrations/20260101000100_functions.sql:913-918` vs `docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md:187`, `:230` | **S4** | Correct the audit text; the pull-only conclusion stands via §E.2. |
| **L1** | `audit_logs` / `device_policies` are pull-only, undocumented as such | Audit and policy history look live everywhere else in the product and are not | not in `supabase/migrations/20260101000100_functions.sql:907-944`; no timer or subscription in `lib/features/audit_logs/` | **S3** | One line in the Audit screen's subtitle ("Reads on open; refresh manually"). |
| **L2** | Command `expired` renders with the same hourglass as `pending` | Dead commands look in-flight in the history list | icon ternary `lib/features/devices/device_detail_page.dart:391-398`; labels themselves are correct `lib/data/models/device.dart` (`DeviceCommandStatus.label`) | **S4** | Give `expired` its own `Icons.cancel` + danger tone. |
| **H1** | Device `applied_policy_version` advances on a *refused* apply | Device and server can both believe version N is applied while nothing was enforced; the device also stops fast-polling on heartbeat | `android/.../PolicyApplier.kt:211` runs before `success` at `:223-226`; consumed `android/.../GuardianService.kt:406`, `:519-522` | **S3** | Only call `setAppliedVersion` when `success` is true, or record it as a separate `seen_version`. |

---

## G. Adversarial result: where the prior audit is wrong

1. **`docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md:187` — "`device_commands` / `device_policies` are **not** in the realtime publication" is FALSE for `device_commands`.** It is explicitly added at `supabase/migrations/20260101000100_functions.sql:913-918`. The publication list is four tables, not three, so `:230` ("only `remote_sessions`, `webrtc_signals`, `safety_alerts` are published") is also wrong. *The functional conclusion survives for a different reason:* no Dart code subscribes to it (`lib/data/repositories/**` has exactly three channels, §E.2). Most likely the prior audit read a plain-PostgreSQL test DB where the `DO` block's `pg_publication` guard at `:911` short-circuits to a `RAISE NOTICE` (`:940-941`).
2. **`POLL_INTERVAL_MS` is at `GuardianService.kt:39`, not `:38`.** Line 38 is `TICK_MS = 10_000L`. The 20 s value itself is confirmed. More importantly, the prior audit's "20-second pull poll" understates the pipeline: there are **two** independent native clocks — a 20 s command poll (`:39`, `:260-277`) *and* a 60 s local policy re-apply tick (`:40`, `:249-258`) — plus a 5-minute heartbeat (`:41`) that can collapse the poll delay (`:519-522`).
3. **New, not covered by the prior audit:** bedtime-only policies are terminally `pending` on *any* device including Device Owner (§C.2(a) — the predicate `quota.configured` at `enforcement.ts:401`); the `sync_policy` "Request sync" affordance reports success without repairing anything (§C.4/C4); `markCommandHandled`-before-`sendAck` makes a lost ack unrecoverable (§C.2(b)); a device-side exception produces `pending` next to a `failed` command on the same card (§C.2(c)); `critical` is an unreachable-but-offered severity filter (§A.3); geofence alerts have no debounce while every other type has a 6 h window (§A.6); `app_blocked`/`permission_missing` are foreclosed by grants, not merely unimplemented (§A.2); and both Settings switches were confirmed write-only with named keys and named missing readers (§B.5).

---

## Appendix — verification limits

- No device, ADB, emulator, network or Supabase call was made; every claim is static. Consequently this report can prove a code path exists or does not, but cannot prove which paths executed on the two audited handsets.
- `.tools/deploy/*.ts` and `.tools/backup_drill/*.sql` are compiled deployment artefacts and were **excluded** as sources of truth; `supabase/functions/**` and `supabase/migrations/**` were used. If the hosted deployment drifted from `supabase/functions/`, §A and §C's server-side citations describe the repository, not necessarily production.
- `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql:1-18` states in its own header that it is **UNAPPLIED TO HOSTED / LOCAL-TESTED ONLY**; §A.6's zone-delete note therefore reflects the `family-admin` stopgap, not that RPC.
- Two items are marked `[HYPOTHESIS]` inline (§E.1 replica identity, §C.5 gap 1) and should not be treated as established.
