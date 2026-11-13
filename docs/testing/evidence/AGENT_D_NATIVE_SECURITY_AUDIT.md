# Agent D — Native & Security Layer Audit (source-only)

Scope: `android/app/src/main/kotlin/com/parentcontrol/parent_control/**` (4,587 LOC Kotlin),
`android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/*`,
the Dart bridge wrapper `lib/data/services/device_admin_service.dart`, and the
server-side ack mapping `supabase/functions/device-command/enforcement.ts`.

Legend — **CONFIRMED** = proven from code (file:line given). **SUSPECTED** = code
implies it but only runtime proves it. **UNVERIFIED** = not determinable from source.

Effective build target (CONFIRMED): `targetSdk = 36`, `minSdk = 24`, `compileSdk = 36` —
inherited from Flutter 3.44.6 defaults (`android/local.properties:11`,
`C:/Users/ASUS/fvm/versions/3.44.6/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23-34`,
`android/app/build.gradle.kts:37-53`). **This is load-bearing for §5**: full
Android 14/15 FGS behaviour applies even on the API 31 Realme.

---

## 1. Service / receiver inventory

### 1.1 `GuardianService` — the whole enforcement + telemetry engine
`android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt` (763 LOC)

| Property | Value | Cite |
|---|---|---|
| FGS type | `dataSync` (`FOREGROUND_SERVICE_TYPE_DATA_SYNC` on Q+) | `GuardianService.kt:736-747`, manifest `:79-82` |
| Permission | `FOREGROUND_SERVICE_DATA_SYNC` | manifest `:13` |
| Notification | id 4101, channel `guardian_status`, `IMPORTANCE_LOW`, `setOngoing(true)` | `:36-37`, `:699-734` |
| Start | `GuardianService.start()` via `startForegroundService`; refuses if no sync config or no notification permission | `:57-71`, `:143-152` |
| Stop | `stopService`; self-stops when `shouldRunGuardian()` false, config missing, notification missing, or Android FGS timeout | `:73-75`, `:225-234`, `:195-209` |
| Restart | `START_STICKY` | `:165-171` |
| Cadence | scheduler tick **10 s**; command poll **20 s** (exp backoff →300 s); policy re-apply **60 s**; heartbeat **5 min**; app list **30 min**; usage **60 min**; watchdog **60 s** (stall = 3 × tick = 30 s) | `:38-45`, `:249-289`, `:306-332` |
| Endpoints | `device-command` (poll + ack), `device-telemetry` (heartbeat / apps_upload / usage_upload / location_upload) | `:360-372`, `:485-497`, `:518`, `:547-550`, `:581-584`, `:619` |
| Tables (server) | `device_commands`, `device_policies`, `devices`, `device_apps`, `usage_daily`, `location_events`, `safe_zone_states`, `safety_alerts`, `audit_logs` | `supabase/functions/device-command/handler.ts:359-424`, `device-telemetry/index.ts:79-354` |
| Uploads | device id, battery %, charging, online, **7 permission/capability booleans**, installed-app package+label+version+isSystem (≤500), per-day per-package foreground ms (≤500), lat/lng/accuracy/timestamp/source, policy ack counts | `:502-517`, `:530-556`, `:558-590`, `:610-625` |

Heartbeat `capabilities` is the **only** thing that keeps `devices.enforcement_mode` and the
per-permission columns fresh (`device-telemetry/index.ts:87-111`), so the parent's
"Enforcement: …" label is at most 5 minutes stale and stops updating entirely when this
service dies.

### 1.2 `LocationTrackingService`
`LocationTrackingService.kt` (263 LOC) — FGS type `location` (`:242-253`, manifest `:84-87`,
permission `FOREGROUND_SERVICE_LOCATION` manifest `:14`). Notification id 4202, channel
`location_sharing`, `setOngoing(true)` (`:221-240`). Uses raw `LocationManager`
GPS + NETWORK providers, **no FusedLocation** (`:112-162`). Interval from Dart, clamped
**15…3600 s**, default 60 (`NativeBridge.kt:549-550`, `:88-90`). It only writes into
`LiveState` + the Dart event bus (`:164-187`); **the upload is done by GuardianService**
(`GuardianService.kt:592-608`). Consequence (CONFIRMED): with Guardian stopped, location is
collected on-device and never leaves it. `START_STICKY` (`:96`). Mock fixes are labelled, not
dropped, at collect time and **dropped at upload time** with a throttled error
(`:164-186`, `GuardianService.kt:596-604`).

### 1.3 `AudioAssistanceService`
`AudioAssistanceService.kt` (779 LOC) — FGS type `microphone` (`:618-637`, manifest `:89-93`,
permission `FOREGROUND_SERVICE_MICROPHONE` manifest `:15`). `stopWithTask="false"`
(manifest `:92`). Notification id 4303, `setOngoing(true)` + a **Stop action**
(`:596-610`) → non-dismissible. Wake lock: `PARTIAL_WAKE_LOCK`, **no timeout** (`:652-664`).
Cadence: permission watchdog **5 s** (`:107`, `:342-357`), capture watchdog **15 s** with a
**45 s** Dart-heartbeat timeout (`:109-117`, `:365-384`), session watchdog **15 s** polling the
`remote-session` Edge Function with `action:"session_state"` (`:108`, `:118`, `:703-763`).
`START_NOT_STICKY` always (`:426`, `:432`, `:468`). **It never opens the microphone itself** —
capture lives in the cached FlutterEngine (`:35-43`, `MainActivity.kt:78-92`). No telemetry
upload other than the session-state poll.

### 1.4 `BootReceiver`
`BootReceiver.kt` (53 LOC) — `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED`, `exported="false"`
(manifest `:107-115`), permission `RECEIVE_BOOT_COMPLETED` (manifest `:18`). Refuses on
API ≥ 35 with a stored error (`:31-37`); refuses without notifications (`:38-44`); otherwise
`GuardianService.start()` and a Toast on failure (`:45-51`). **It never resumes location or
microphone services.** Location resume happens only in Dart when the child opens the app
(`child_shell_controller.dart:640-658`).

### 1.5 `PolicyApplier`
`PolicyApplier.kt` (562 LOC) — not an Android component. Only four DPM calls exist in the
entire codebase: `isDeviceOwnerApp` (`:335`), `isAdminActive` (`:342`),
`isPackageSuspended` (`:323`, `:475`), `setPackagesSuspended` (`:351`, `:364`). Driven by
GuardianService every 60 s (`GuardianService.kt:249-258`) and by command
`apply_policy`/`sync_policy` (`:401-432`).

### 1.6 `ParentControlDeviceAdminReceiver`
`ParentControlDeviceAdminReceiver.kt:18` — an **empty** `DeviceAdminReceiver` subclass
(zero overrides). `res/xml/device_admin.xml:5` is `<uses-policies />` — **empty**. Manifest
`:95-105`, `exported="true"` guarded by `BIND_DEVICE_ADMIN` (correct/required).

### 1.7 `NativeBridge` / `SecureStore` / evaluators
`NativeBridge.kt` (640 LOC) — method + event channel (§7). `SecureStore.kt` (241 LOC) —
EncryptedSharedPreferences singleton (§6). `policy/PolicyEvaluator.kt` (77 LOC) — restore-list
diff + `PolicyGuard` critical-package denylist (`:28-62`).
`policy/QuotaEvaluator.kt` (257 LOC) — pure daily-quota verdicts (§4).

---

## 2. PERMISSION DEPENDENCY MATRIX

| # | Capability | Permission / grant | How granted | Behaviour when DENIED | Cite |
|---|---|---|---|---|---|
| 1 | Foreground location (while service runs) | `ACCESS_FINE_LOCATION` (+`ACCESS_COARSE_LOCATION`) | Runtime dialog via `requestPermissions(location:true)` | `startLocationTracking` returns **false**; Dart rolls back the local preference and shows "Android did not start the location service, so location sharing is still off." No silent success. | `NativeBridge.kt:467-470,546-551`; `NativePermissions.kt:16-20`; `child_shell_controller.dart:941-948,962-970` |
| 2 | **Background** location | `ACCESS_BACKGROUND_LOCATION` | **NOT OBTAINABLE IN-APP.** Dart forwards a `backgroundLocation` flag that Kotlin **silently ignores**; the only path is `openBackgroundLocationSettings()`, which lands on the generic *App info* page, not the permission screen. | Heartbeat reports `background_location_granted=false`. **Practically harmless** (see note below), but the UI implies a grant the app never asks for. | `AndroidManifest.xml:8`; `NativeBridge.kt:464-475` (no branch), `:424` → `:426-433`; `device_admin_service.dart:210-226`; `GuardianService.kt:506` |
| 3 | Usage Access (screen time, app-usage list) | `PACKAGE_USAGE_STATS` app-op (Settings toggle, *not* a runtime dialog) | Settings intent `ACTION_USAGE_ACCESS_SETTINGS`, fallback App info | Upload: `request_usage` command acks **failed** with "No usage data could be uploaded. Check Usage Access on the device." Quota: `usage_available=false` → action `none`, reason `quota_usage_unavailable` → server status **pending**. `getDailyUsage` errors `usage_access_denied`. | `AndroidManifest.xml:21-23`; `NativePermissions.kt:34-55`; `UsageReporter.kt:18-22`; `GuardianService.kt:433-441,558-562`; `NativeBridge.kt:558-566`; `QuotaEvaluator.kt:186-190`; `enforcement.ts:407-409` |
| 4 | App suspension / quota blocking | **Device Owner** (see §3) | adb `dpm set-device-owner` only | `desired>0 && !isOwner` → error string, `enforcement_supported=false`, ack counts `desired=N, applied=0` → server **unsupported** + `device_owner_required`. | `PolicyApplier.kt:135-142,219-226`; `enforcement.ts:302-309` |
| 5 | Camera (video assistance only) | `CAMERA` | Runtime dialog (session preflight, media self-test, pairing) | Session preflight fails, error `permission_denied`, mic/camera stay off. | `AndroidManifest.xml:9`; `NativeBridge.kt:465`; `remote_session_controller.dart:1375-1386` |
| 6 | Microphone (audio assistance) | `RECORD_AUDIO` (+ `FOREGROUND_SERVICE_MICROPHONE`) | Runtime dialog; also live-revoked every 5 s | `startBlockReason` = `permission_denied`; FGS refuses. Mid-session revoke → `audio_assistance_stopped/permission_denied` + service teardown. | `AudioAssistanceService.kt:248-257,294-315,342-357`; `GuardianService.kt:508` |
| 7 | Notifications (mandatory for **all three** FGS) | `POST_NOTIFICATIONS` (API 33+) | Runtime dialog | Guardian: refuses to start, and if already running → `stopSelf()` + "Notification permission is required…". Location: silent `stopSelf()`. Audio: `notification_permission_required` + `start_failed` event. On API<33 `hasNotifications` returns **true** unconditionally. | `NativePermissions.kt:29-32`; `GuardianService.kt:148-152`; `NativeBridge.kt:336-341`; `LocationTrackingService.kt:69-73`; `AudioAssistanceService.kt:253-256` |
| 8 | **Battery-optimization exemption** | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | **NOT IMPLEMENTED AT ALL.** No permission, no intent, no `isIgnoringBatteryOptimizations()` probe anywhere in `lib/` or the Kotlin. The only acknowledgement is one generic user-facing string mentioning "battery restrictions". | No honest-degradation code path exists; Doze/OEM killers silently stall the 10 s tick and the watchdog re-arms it in-process only while the process survives. **This is the single biggest gap for the Realme RMX2161 test.** | grep over `lib` + `android/app/src/main` = 0 hits; `child_shell_controller.dart:893-897` |
| 9 | Boot completion resume | `RECEIVE_BOOT_COMPLETED` | Manifest (install-time) | API ≥ 35: hard refusal + stored error ("Android 15 does not allow…"). API 31-34: attempts `startForegroundService`; on `ForegroundServiceStartNotAllowedException` → stored error + Toast. See §5. | `BootReceiver.kt:19-51`; `GuardianService.kt:57-71` |
| 10 | App suspension "policy pending" resolution | — | — | Parent's ack poller runs **6 × 5 s = 30 s then stops**; the device's command poll is 20 s *best case* and up to 300 s under backoff, TTL 300 s. A healthy device can therefore ack *after* the parent's UI gave up polling. | `app_restrictions_controller.dart:629-638`; `GuardianService.kt:39,260-277`; `handler.ts:189` |
| 11 | Installed-app inventory | `QUERY_ALL_PACKAGES` | Manifest (install-time, Play-review-gated) | With targetSdk 36 and no `<queries>` for the packages it needs, removing the permission would empty the list and `uploadApps` would return false → "App list upload failed". Currently never exercised. | `AndroidManifest.xml:24-29,127-132`; `InstalledAppsProvider.kt:15-42`; `GuardianService.kt:530-556` |
| 12 | Keep CPU awake during mic session | `WAKE_LOCK` | Manifest | `acquireWakeLock` swallows all failures; session continues without a wakelock (background screen-off audio then becomes OEM-dependent). | `AndroidManifest.xml:16-17`; `AudioAssistanceService.kt:652-664` |
| 13 | Device Admin (cosmetic only) | `ACTION_ADD_DEVICE_ADMIN` | Settings dialog | `enforcement_mode` reports `device_admin` instead of `none`. **Grants zero enforcement** (§3). | `NativeBridge.kt:398-410`; `EnforcementMode.kt:22-26`; `device_admin.xml:5` |

> Note on #2 (CONFIRMED reasoning): a running FGS with `foregroundServiceType="location"` is
> itself an Android "while-in-use" state, so location updates continue with the service alive
> even without `ACCESS_BACKGROUND_LOCATION`. The missing grant should therefore **not** break
> location sharing in your test. If it does, that is a finding, not expected behaviour.

---

## 3. DEVICE OWNER vs DEVICE ADMIN — verdict

**Confirmed from code:**

* **Device Admin grants nothing.** `ParentControlDeviceAdminReceiver` is an empty subclass
  (`:18`) and `device_admin.xml:5` is `<uses-policies />`. No admin-only DPM API is called
  anywhere (complete list in §1.5). Admin state is used **only** to label `enforcement_mode`
  `"device_admin"` (`EnforcementMode.kt:22-26`).
* **Device Owner is required for:** `setPackagesSuspended` — i.e. app blocking **and** the
  daily screen-time quota's only real action (`PolicyApplier.kt:351,364`;
  `QuotaEvaluator.kt:140-152`, `:256`).
* **Works without Device Owner:** usage telemetry upload, app inventory, location, audio
  assistance, heartbeat/capability reporting, and time-window *app rules* evaluation
  (evaluation yes, suspension no).
* **Nothing else is available even *with* Device Owner**: no `lockNow`, no screen-time
  limit API, no network filtering, no install block.

**Device Owner cannot be provisioned in-app — CONFIRMED (your belief is correct).**
Evidence: zero occurrences of `ACTION_PROVISION_MANAGED_DEVICE`,
`ACTION_PROVISION_MANAGED_PROFILE`, `setActiveAdmin`, or any provisioning intent in
`android/` or `lib/` (only hit for `managedprovisioning` is the *denylist* entry
`PolicyEvaluator.kt:45`). The single DPM intent is `ACTION_ADD_DEVICE_ADMIN`
(`NativeBridge.kt:402`). `android/settings.gradle.kts:26` contains only `include(":app")` —
there is **no DPC module**, and `android_dpc/` is an **empty directory**. The KDoc states the
policy explicitly (`ParentControlDeviceAdminReceiver.kt:8-16`: "This app never attempts the
provisioning command programmatically", `adb shell dpm set-device-owner …`).
`docs/device-owner-provisioning.md` is documentation, not code.

**What `PolicyApplier` reports without Device Owner** (`:135-142`): keeps the target set,
appends `"Device Owner provisioning is required to suspend apps on this device. No apps were
suspended."`, marks every app `unsupported`; `enforcement_supported = false` (`:219-221`);
`success = false` unless `desiredCount == 0` (`:223-226`); quota action
`advisory` + reason `quota_advisory_only` (`QuotaEvaluator.kt:191-196`).
A previously-DO device that lost ownership cannot even un-suspend (`:153-161`).

**How that reaches the parent UI (3 hops, CONFIRMED):**
1. ack `result{enforcement_supported, desired_count, applied_count, enforcement_mode,
   quota}` → `device-command` `action:"ack"` (`GuardianService.kt:485-497`).
2. `decideEnforcement` writes `device_policies.enforcement_status` + `last_error`, and
   advances `devices.policy_version` only on `enforced`/`unsupported`
   (`handler.ts:384-424`, `enforcement.ts:302-309`).
3. Parent renders it: `app_restrictions_controller.dart:714-748` +
   `app_restrictions_page.dart:128-138` (warning banner when `enforcementMode !=
   'device_owner'`), `:352-366`, and the reason table
   `enforcement_reason.dart:41-42` → "App blocking requires Device Owner, which this device
   does not have."

**Caveat for your testing (CONFIRMED):** the *server-side* `devices.enforcement_mode` is
written **only by the heartbeat** (`device-telemetry/index.ts:89-95`), and the *client-side*
mirror `DeviceAdminService.getCapabilities().isDeviceOwner` is a separate, live path
(`NativeBridge.kt:183-203`). If GuardianService is dead, the parent's Device-Owner banner is
frozen at its last value — a stale "unsupported" or a stale "device_owner" both look real.
Also, `supabase_device_repository.dart:179-181` re-implements `EnforcementMode.of` in Dart;
byte-identical today, but it is an untested drift risk.

---

## 4. ENFORCEMENT REALITY CHECK

### 4.1 App suspension — REAL, but only under Device Owner
`setPackagesSuspended` is called (`:351`) and the result is **re-verified** through
`isPackageSuspended` per package rather than trusting the call (`:163-179`, `:320-331`).
`enforcement_supported` requires DO **plus** evidence (`:219-221`). `canConfirmSuspension()`
fails closed if DPM is unreadable (`:474-479`). Suspended sets are persisted and restored on
differential (`:145-151`, `store.setSuspendedPackages` `:180`).
**No fake-success path found.**

### 4.2 Daily screen-time quota — REAL only under DO + Usage Access; otherwise advisory
Pure decision `QuotaEvaluator.decide` (`:154-237`). Without DO → `action:"advisory"`,
`targets = ∅` (`:140-152`, `PolicyApplier.kt:441-450`) → **suspends nothing**, correctly.
With DO + Usage Access + limit reached, quota targets join the same desired set
(`PolicyApplier.kt:118-132`) so non-critical third-party apps are genuinely suspended for the
rest of the local day; `quotaActiveDayBucket` is persisted so reboot cannot re-arm the counter
(`:196-204`, `SecureStore.kt:183-190`) and `advanceDayBucket` refuses equal/backward days
(`QuotaEvaluator.kt:114-118`). Measurement is `UsageStatsManager.totalTimeInForeground`
(`UsageReporter.kt:40-69`), summed across *all* packages (`:69-80`).
**Honest-degradation strings:** `quota_below_limit` / `quota_advisory_only` /
`quota_usage_unavailable` / `quota_suspend_failed` → `enforcement_reason.dart:19-34`.

### 4.3 Bedtime / curfew — **DOES NOT RESTRICT ANYTHING. CONFIRMED.**
The complete set of bedtime code: parsed into `ChildPolicy.bedtimeStartMinutes/EndMinutes`
(`PolicyModels.kt:44-60`), and used at exactly **one** place —
`PolicyApplier.kt:500-503`:
```kotlin
// Informational only: bedtime is stored but app suspension follows app rules.
result.put("bedtime_active", policy.hasBedtime && policy.isWithinBedtime(...))
```
Nothing reads `bedtime_active`: zero references in `lib/` and zero in `supabase/` (grep).
`QuotaEvaluator` never sees it. There is **no** `lockNow`, no display-off, no DPM
`setMaxTimeUntilLock`, no FGS blocking the launcher. **During curfew the child's phone is
completely usable.** What *does* work time-wise is a per-app **schedule** (`PolicyWindow`
`PolicyModels.kt:4-22`, `PolicyAppRule.isActiveAt` `:30-34`), re-evaluated every 60 s —
and that is still suspension, i.e. DO-gated.
The child UI states this honestly (`policy_summary_card.dart:120-126`,
`child_restrictions_page.dart:296`); the **parent's** Screen-time page does not carry an
equivalent "bedtime does nothing" sentence.

### 4.4 Status written as "success" with no device effect
* **Native side: none found.** `success` requires `errors.isEmpty()` plus either no targets or
  verified suspension (`:223-226`).
* **Server-side overstatement risk (CONFIRMED):** `enforcement.ts:490-494` — for a **mixed**
  policy (apps + daily limit/bedtime) the *app* verdict wins, so a policy whose app half is
  provably suspended and whose quota half is only advisory is stored as
  **`enforcement_status = 'enforced'`**, with the truth demoted into `last_error`. The parent's
  Screen-time page then shows the green banner
  (`screen_time_page.dart:287-295`) "The device acknowledged this policy version…" with no
  mention that the limit is advisory. The nuance survives only in `policyStateText` /
  `quotaReasonText` (`app_restrictions_controller.dart:714`,
  `screen_time_controller.dart:215-216`). **Verify this rendering live — it is the closest
  thing to a false success in the whole pipeline.**
* Conversely, DO + a policy with **zero eligible** packages yields
  `desiredCount == 0` → `success = true` (`:224`) and `enforcement_supported = true` (`:220`)
  → status **`enforced`** with nothing blocked. `app_restrictions_page.dart:368-378`
  ("empty app set, so there was nothing to suspend") covers it honestly.

### 4.5 Paths that leave a policy PERMANENTLY PENDING (CONFIRMED)
1. **Bedtime-only policy — dead end, on every device, forever.** `policyDeclaresTimeLimits`
   is true, `policyTargetsApps` false → `enforcement.ts:477-480` lets the quota block decide
   alone → `quota.configured = false` because there is no daily limit
   (`PolicyApplier.kt:422-423`) → **`pending` + `quota_not_configured`,
   `advancePolicyVersion = false`** (`enforcement.ts:401-403`). Nothing ever resolves it:
   `store.setAppliedVersion` already ran (`PolicyApplier.kt:211`), the command is consumed
   (`GuardianService.kt:475`), and `pending_policy_version` is just *the latest version number*
   (`device-telemetry/index.ts:50-55,150`), so no new command is ever created. There is **no
   cron/requeue** for policies (`supabase/functions/cron/index.ts` has no policy/command
   reference). Parent sees "Pending device acknowledgement — the limit and bedtime are not
   active yet" (`screen_time_page.dart:276-285`) indefinitely.
2. **Daily limit without Usage Access** → `pending` + `quota_usage_unavailable`
   (`enforcement.ts:407-409`). Self-heals once granted.
3. **Command expires un-acked** (TTL 60–900 s vs a 20 s–300 s poll and a dead FGS) → the row
   is flipped to `expired` by `poll_device_commands`
   (`supabase/migrations/20260101000100_functions.sql:614-618`) but `device_policies` is
   **never touched** — no ack, so no `enforcement_status` write (`handler.ts:384`).
   Status stays `pending` with `acknowledged_at = null`, forever, until the parent re-saves.
4. **Native exception during apply** → `countsKnown = false` → the ack omits
   `desired_count`/`applied_count`/`enforcement_supported`/`quota` entirely
   (`PolicyApplier.kt:227-237`, `:504-517`) → `readCount` gives nulls → `countsPresent` false →
   **`pending` + `enforcement_counts_missing`**, non-advancing (`enforcement.ts:311-321`).

---

## 5. BACKGROUND-LIFECYCLE REALISM (which results are environment- not code-limited)

* **FGS start from background (API 31+, both devices).** Only `GuardianService` (dataSync) is
  ever started from a non-UI context (BootReceiver); audio and location are started from the
  visible Dart UI, so `ForegroundServiceStartNotAllowedException` is not expected for them.
  `startForegroundService` is wrapped in try/catch and the failure is surfaced, not swallowed
  (`GuardianService.kt:57-71`). **SUSPECTED, must be measured:** whether AOSP 12 exempts a
  `BOOT_COMPLETED` receiver from the dataSync ban. Code only hard-refuses at API ≥ 35
  (`BootReceiver.kt:31-37`), so on the Realme (API 31) it **will attempt** the boot start.
  Either outcome is environment-limited; the only code question is whether the resulting
  message reaches the child, which it does via `setLastError` + Toast (`:32-51`).
* **Android 15 dataSync time cap (~6 h/24 h).** `onTimeout` is implemented
  (`GuardianService.kt:195-209`) with a resume message. **Not testable on either device**
  (API 31 and, unless the emulator image is 15, not there either) — UNVERIFIED.
* **Android 14 (API 34) "while-in-use" camera/mic FGS-type enforcement.** With
  `targetSdk = 36`, a **video** assistance session running under the `microphone`-only FGS
  (`AndroidManifest.xml:89-93`; `FOREGROUND_SERVICE_CAMERA` is **never declared**) would lose
  camera access when backgrounded. **Environment-limited:** the Realme is API 31 (unaffected);
  expect it only on an API 34+ emulator. SUSPECTED — confirm on the emulator image you use.
* **Doze / app standby / OEM battery killers (Realme RMX2161, realme UI).** The 10 s in-process
  `ScheduledExecutorService` tick (`GuardianService.kt:153-161`) is a **plain executor, not
  WorkManager/JobScheduler/AlarmManager** — no `setExactAndAllowWhileIdle`, no
  `JobScheduler`, no GCM/FCM push, and (per §2 row 8) **no battery-optimisation exemption is
  even requested**. So: deep Doze freezes the network, the poll and the heartbeat; the watchdog
  (`:306-358`) only proves *the scheduler is running inside a live process*, which is exactly
  why it cannot detect a frozen one. **A stalled Guardian on the Realme is
  environment-limited and is the expected, correct result — not a code defect.** On the Pixel
  emulator, disable battery optimization manually for a clean code-path signal.
* **Process death.** `AudioAssistanceService` explicitly documents non-survival of
  force-stop/reboot/OEM clean (`:58-61`); `GuardianService` is `START_STICKY` (`:170`),
  `LocationTrackingService` `START_STICKY` (`:96`), `AudioAssistanceService`
  `START_NOT_STICKY` (`:468`) — intentional: audio must never resurrect without consent.

---

## 6. SECURITY & PRIVACY

**Secret storage — CONFIRMED strong.** `EncryptedSharedPreferences` (AES256-GCM master key via
Android Keystore, AES256_SIV keys / AES256_GCM values) in `parent_control_secure`
(`SecureStore.kt:71-84`). Device secret = 32 bytes `SecureRandom`, URL-safe Base64, generated
once (`:94-105`). Contents: Supabase URL, publishable key, device id, device secret, family id
(`:107-129`), stored policy JSON, suspended/quota/command-id state.
**Note (CONFIRMED):** the secret is passed **over the platform channel to Dart** by
`getDeviceIdentity` (`NativeBridge.kt:206-220`, `"secret" to secret`) and kept in an in-memory
`Rxn<DeviceIdentity>` (`session_service.dart:14,51-52`) — never in SharedPreferences
(`local_settings_service.dart` / `child_preferences.dart` hold only ids, role, flags). Dart
re-sends that same secret via `authHeaders()` (`device.dart:802-811`). Both channel hops are
in-process, so this is not an interception risk, but it does mean the plaintext secret is
reachable from the Dart heap of a debug build.

**Transport.** HTTPS-only, twice-validated, `HttpURLConnection`,
`Content-Type: application/json`; credentials in headers (`x-device-id`, `x-device-secret`,
`apikey`, `Authorization: Bearer <publishable>`) never in the URL or body
(`DeviceHttpClient.kt:18-50`, `SecureStore`/`NativeBridge.kt:364-368` length+scheme
validation). `network_security_config.xml:9` `cleartextTrafficPermitted="false"` —
**and no `<pin-set>`: certificate pinning is an explicit open TODO**
(`network_security_config.xml:5-7`). Consequence: local/self-hosted `http://10.0.2.2`
backends pass Dart's validator (`env.dart:42-46`) but are killed by the platform — if any of
your tests use a cleartext backend, that is environment, not code.

**What leaves the child device, and where it lands.**
| Data | Endpoint → table | Cite |
|---|---|---|
| Presence, battery, charging, 7 capability booleans | `device-telemetry` heartbeat → `devices` | `GuardianService.kt:499-528`; `device-telemetry/index.ts:79-119` |
| Full installed-app inventory (≤500 pkg + label + version + isSystem + isSuspended) every 30 min | → `device_apps` | `GuardianService.kt:530-556`; `device-telemetry/index.ts:357-427` |
| Per-app foreground minutes per day (≤500 rows, 2 days) every 60 min | → `usage_daily` | `GuardianService.kt:558-590`; `index.ts:157-237` |
| Raw lat/lng/accuracy/timestamp/provider on every fresh fix | → `location_events` + `safe_zone_states` + `safety_alerts` | `GuardianService.kt:610-625`; `index.ts:239-355` |
| Policy ack counters + per-package failure reasons + quota verdict | → `device_commands.result`, `device_policies`, `audit_logs` | `handler.ts:359-435` |
| WebRTC SDP (offer/answer/ICE) | `remote-session` → `webrtc_signals` | `remote_session_controller.dart:1306-1315` |
| Audio media | **peer-to-peer WebRTC; no recording, no server relay of media** | `AudioAssistanceService.kt:35-43` |
Retention: `location_events` 30 d, `usage_daily` 90 d, `webrtc_signals` 7 d, `audit_logs` 365 d
(`migrations/20261030000300_retention_sweep.sql:137-221`).

**logcat leakage — CONFIRMED CLEAN.** `grep -n 'Log\.(d|v|i|w|e|println|wtf)'` over the whole
Kotlin tree = **0 hits**. No `println`. In Dart, `print(` / `debugPrint` / `developer.log` =
**0 hits**. The KDoc asserts it too (`NativeBridge.kt:26-27`,
`AudioAssistanceService.kt:735-741`). All error strings are length-capped at 200–500 chars and
are user-facing sentences, not stack traces (`GuardianService.kt:682-689`,
`SecureStore.kt:150-156`), and `safeMessage` truncates exception text
(`NativeBridge.kt:636-637`) — a message could in principle echo a URL, but no call site
interpolates the secret. Server functions log codes only, e.g.
`console.error("poll_rpc_failed:...")` (`handler.ts:297`).
**Residual (UNVERIFIED):** third-party plugin tags (`flutter_webrtc`, `supabase_flutter`)
log independently — check `logcat` during the live session, that is not source-observable.

**`allowBackup` — CONFIRMED `false`** (`AndroidManifest.xml:43`), plus
`adb:BackupRule`-free. `taskAffinity=""` on MainActivity (`:51`).

**Exported surface.** Only two exported components: `MainActivity` (`:47-77`) and the
DeviceAdminReceiver (`:95-105`, guarded by `BIND_DEVICE_ADMIN`, correct). All three services
`exported="false"` (`:81,86,91`). `BootReceiver` `exported="false"` (`:110`). No
`<provider>`, no deep-link into a settings/enforcement screen.
`parentcontrol://auth-callback` is BROWSABLE (`:69-76`) and is hardened: a cold start with a
malformed link strips `intent.data` before Flutter sees it, and `onNewIntent` forwards only a
well-formed callback carrying `code` or `access_token` (`MainActivity.kt:35-76`).
**Real gap (CONFIRMED):** it is a *custom scheme*, not an `autoVerify` HTTPS App Link, so any
installed app can claim `parentcontrol://` and capture PKCE codes. Low severity (single-use
code + server-side verifier) but worth stating.

**`QUERY_ALL_PACKAGES` (`AndroidManifest.xml:24-29`).** Declared with the Play-policy warning
comment intact. Effects: (a) `getInstalledPackages(0)` returns the whole device inventory
(`InstalledAppsProvider.kt:18`) which is then **uploaded to `device_apps` every 30 min** — the
single broadest privacy export in the app, and it is what makes the parent's app-restriction
list possible; (b) it is **not declared in `<queries>`**, so it is the only package-visibility
mechanism; (c) a Play release must justify it or replace it with a `<queries>` block —
explicitly flagged in the source, not yet resolved.

**Surveillance-capable paths and their consent.**
| Path | Visible consent gate | Indicator | Verdict |
|---|---|---|---|
| Microphone | Server-side: session must be `accepted` with `consent_recorded`; child taps **Accept** in a confirm dialog (`child_requests_page.dart:168-184`, `child_session_page.dart:632-645`; `remote-session/index.ts:210-259,275`) and ICE config is refused pre-consent (`index.ts:357-366`). Media opens only after `status ∈ {accepted, active}` (`remote_session_controller.dart:1192-1201`). | Ongoing, non-dismissible `setOngoing(true)` mic notification + Stop action (`AudioAssistanceService.kt:596-610`) + Android's own mic chip. | Consented. |
| Camera | Same accept gate; constraints only when `kind == video` (`remote_session_controller.dart:1204-1218`). | No dedicated ongoing notification — relies on the Android green camera indicator. | Consented; **no app-level camera FGS type** (see §5). |
| Location | Child toggles sharing explicitly (`child_shell_controller.dart:910-971`) + persistent notification. | Yes (`LocationTrackingService.kt:221-240`). | Consented. |
| Guardian background sync | Child taps start explicitly (`child_shell_controller.dart:840-908`). | Yes (`GuardianService.kt:715-734`). | Consented. |
| Usage / installed-apps | Piggybacks on Guardian consent; **no separate child-facing disclosure of the installed-app upload**. | Guardian notification. | **Weak spot** — the notification text ("Syncing device status with your family", `strings.xml:6`) does not name apps, usage or location. |

**Gap worth a runtime check (CONFIRMED from code):** the native
`startAudioAssistanceService` handler performs **no consent or session-state check** — it only
gates on microphone + notification permission (`NativeBridge.kt:147-150` →
`AudioAssistanceService.kt:294-315`). Consent enforcement lives entirely in Dart
(`remote_session_controller.dart:1154-1160,1192-1201`). Nothing in the native layer would stop
a compromised/patched client from starting a mic FGS with an arbitrary `sessionId`.
Also, the mic FGS is started **before** the post-consent status re-check at `:1192-1201`
(grace window at `AudioAssistanceService.kt:459-461`) — the notification appears, capture does
not, if the session was revoked in between.

**"Parent is receive-only, never captures mic" — CONFIRMED.**
`_captureUserMedia` is called from exactly one site, inside `if (isChildRole)`
(`remote_session_controller.dart:1204-1219`, call at `:1219`; the definition with its live
`navigator.mediaDevices.getUserMedia` is `:1592-1596`). `_localStream` is only ever assigned at
`:1231`, in that same branch, so `addTrack` (`:1278-1282`) is unreachable for the parent. The
parent's role branch never requests `RECORD_AUDIO` — the only `requestPermissions(microphone:
true)` in the media path is guarded by `if (!isChildRole) return;` (`:1648-1651`, gate at
`:1649`'s preceding line `if (!isChildRole) return false;`). The parent instead creates the
offer with `OfferToReceiveAudio: true` (`:1283-1291`).
**Nuance (CONFIRMED, not a defect):** the parent's offer uses legacy
`mandatory`/`optional` constraints rather than an explicit `recvonly` transceiver direction —
no such call exists anywhere (`grep recvonly|setDirection|transceiver` = 0 hits) — so the
negotiated audio transceiver will normally read `sendrecv` while carrying no track. Nothing is
captured; a strict recvonly offer would be cleaner and a peer-side audit would show sendrecv.

---

## 7. NATIVE BRIDGE CONTRACT

Channels (both directions, exactly one each):
`com.parentcontrol/native` (MethodChannel) and `com.parentcontrol/native_events`
(EventChannel) — `NativeBridge.kt:40-41` ↔ `device_admin_service.dart:17-20`.

| Method | Dart caller | Kotlin handler | Status |
|---|---|---|---|
| `getCapabilities` | `device_admin_service.dart:39-43` | `NativeBridge.kt:121,183-204` | wired |
| `getDeviceIdentity` | `:45-67` | `:122,206-220` | wired |
| `getBatteryStatus` | `:69-72` | `:123,222-255` | **DEAD — 0 callers.** Battery comes from the server, written by the native heartbeat. |
| `getInstalledApps` | `:74-80` | `:124,257-269` | wired (`child_shell_controller.dart:532`) |
| `isPackageSuspended` | `:82-85` | `:125-131` | wired (`child_shell_controller.dart:543`) |
| `applyPolicy` | `:87-96` | `:132,271-283` | **DEAD — 0 callers.** See consequence below. |
| `getGuardianServiceStatus` | `:98-103` | `:133,320-328` | wired |
| `startGuardianService` | `:105-106` | `:134,330-348` | wired |
| `stopGuardianService` | `:108-109` | `:135,350-355` | wired |
| `configureBackgroundSync` | `:180-195` | `:136,357-379` | wired |
| `clearBackgroundSync` | `:197-199` | `:137,381-396` | wired |
| `requestDeviceAdmin` | `:201-202` | `:138,398-410` | wired |
| `openUsageAccessSettings` | `:204-205` | `:139,412-422` | wired |
| `openBackgroundLocationSettings` | `:207-208` | `:140,424` | wired (opens App info, not the permission page) |
| `requestPermissions` | `:210-226` | `:142,455-497` | wired — **`backgroundLocation` argument is accepted by Dart and silently dropped by Kotlin** |
| `getLastKnownLocation` | `:228-233` | `:143,499-544` | **DEAD — 0 callers.** |
| `startLocationTracking` | `:235-239` | `:144,546-551` | wired |
| `stopLocationTracking` | `:241-242` | `:145,553-556` | wired |
| `getDailyUsage` | `:244-268` (`queryDailyUsage`) | `:146,558-588` | **DEAD — 0 callers.** Usage screens read `usage_daily` from Supabase instead. |
| `startAudioAssistanceService` | `:111-113` | `:147-150` | wired |
| `stopAudioAssistanceService` | `:115-116` | `:151-154` | wired |
| `getAudioAssistanceStatus` | `:118-132,155-159` | `:155,295-301` | wired |
| `notifyAudioCaptureHeartbeat` | `:137-148` | `:156-159` | wired (10 s loop, `remote_session_controller.dart:2246`) |
| `areNotificationsGranted` | `:165-166` | `:160,NativePermissions.kt:29-32` | wired |
| `isMicrophoneOneTimeGrant` | `:174-178` | `:162,315-318` | wired but **structurally inert** — `oneTime` is hard-coded `false` because the Android flag is a hidden API (`:303-314`) |
| — | `acknowledgeCommand` (`supabase_policy_repository.dart:111-143`) | n/a (HTTPS, not channel) | **DEAD — 0 call sites** |
| — | `DeviceRepository.heartbeat` / `.uploadReportedApps` (`supabase_device_repository.dart:137,170`), `LocationRepository.uploadLocation` / `.fetchHistory`, `UsageRepository.uploadUsage` | n/a | **DEAD — 0 call sites.** All device→server telemetry is native-only. |

**Kotlin handlers with no Dart caller: 4** (`getBatteryStatus`, `applyPolicy`,
`getLastKnownLocation`, `getDailyUsage`).
**Dart calls with no Kotlin handler: 0.** Unknown methods → `result.notImplemented()`
(`NativeBridge.kt:163`) → `MissingPluginException` → `null` in `_invoke` (`:288-300`), i.e.
fail-to-null, not fail-open.

**Consequence of the dead `applyPolicy` (CONFIRMED, matters for your test):** there is **no
foreground path that applies a policy or acknowledges a command**. Everything enforcement-related
requires `GuardianService` to be alive and polling. With Guardian stopped, a parent's save
leaves the policy `pending` forever and the child's own Rules screen shows only what the *server*
last reported. Related: `requestPermissions`' returned `snapshot`
(`NativePermissions.kt:57-63`) **omits usage-access state**, so the caller must re-read
`getCapabilities()` to learn whether the settings toggle was actually granted — the UI does this
correctly (`child_shell_controller.dart:865-870,935-940`).

### Event channel (`com.parentcontrol/native_events`)
| `type` | Kotlin emitter | Dart consumer |
|---|---|---|
| `service_status` | `NativeEventBus.kt:44-52` (`GuardianService.kt:134,186,687,695`) | `child_shell_controller.dart:722-729` |
| `command` | `NativeEventBus.kt:54-63` (`GuardianService.kt:390,457,481`) | `child_shell_controller.dart:730-736` |
| `location_update` | `NativeEventBus.kt:28-42` (`LocationTrackingService.kt:186`) | **UNCONSUMED — 0 Dart handlers.** The parent's map polls `location_events` instead (`location_controller.dart:79`). |
| `guardian_stall_recovered` | `GuardianService.kt:351-357` | **UNCONSUMED — 0 Dart handlers.** Only its side effect (a stored `lastError`, `:347-350`) reaches the UI. |
| `audio_assistance_started` | `NativeEventBus.kt:66-73` (`AudioAssistanceService.kt:425,466`) | `remote_session_controller.dart:506` |
| `audio_assistance_start_failed` | `:76-83` (`:521`) | `:509` |
| `audio_assistance_stopped` | `:85-92` (`:351,378,404,483,775`) | `:512` |
| `audio_assistance_detached` | `:99-107` (`:501`) | `:515` |

Single-sink caveat (CONFIRMED): the native side keeps **one** `EventSink`
(`NativeEventBus.kt:14-20`), so the last `onListen` wins; this is mitigated by the shared
cached stream (`device_admin_service.dart:24-37`). Both listeners
(`child_shell_controller.dart:718-739`, `remote_session_controller.dart:497-517`) therefore see
**every** event and filter by type — a `service_status` event delivered while the child shell is
closed is dropped, since `sink` is null.

---

## 8. Prioritized map-to-runtime checklist

1. **§3 Device Owner verdict** — expect `enforcement_mode: none|device_admin` on both devices
   with zero suspension; `desired=N, applied=0`, status `unsupported` / `device_owner_required`.
   Any other result is a code defect.
2. **§4.3 bedtime** — expect the phone to remain fully usable during curfew, and (bedtime-only
   policy) status `pending` / `quota_not_configured` permanently.
3. **§4.4 mixed-policy `enforced` + advisory quota** — verify what the parent's Screen-time
   banner actually says.
4. **§2 row 8** — no battery-optimisation exemption exists: expect Guardian stalls on the Realme.
5. **§2 rows 1-2** — background location is never requested; expect sharing to work anyway
   while the `location` FGS is alive.
6. **§4.5 paths 3-4** — command expiry vs the 30 s parent poll window.
7. **§7 dead `applyPolicy`** — with Guardian stopped, no policy can ever apply.
8. **§6** — mic/consent: confirm the Stop action and the parent's receive-only audio, and
   `logcat` the third-party WebRTC/Supabase plugins for anything Agent D cannot see in source.
