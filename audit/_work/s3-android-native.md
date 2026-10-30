# Android native capability audit — findings

Subagent 3 of 10. Read-only. No repo file was modified; nothing was built, installed
or executed on a device; the Supabase CLI was not run. Every claim below cites
`path:line` from the working tree at the time of this audit, or is explicitly
labelled `(assumption)`.

## 1. Scope actually covered (files/dirs read; anything skipped and why)

Read in full:

- `android/app/src/main/AndroidManifest.xml` (132 lines), `android/app/src/debug/AndroidManifest.xml`,
  `android/app/src/profile/AndroidManifest.xml`, `android/app/src/main/res/xml/device_admin.xml`,
  `android/app/src/main/res/values/strings.xml`
- All Kotlin under `android/app/src/main/kotlin/com/parentcontrol/parent_control/`:
  `MainActivity.kt` (79), `NativeBridge.kt` (640), `GuardianService.kt` (633),
  `AudioAssistanceService.kt` (743), `LocationTrackingService.kt` (263),
  `BootReceiver.kt` (53), `ParentControlDeviceAdminReceiver.kt` (18),
  `PolicyApplier.kt` (309), `NativePermissions.kt` (70), `UsageReporter.kt` (97),
  `InstalledApps.kt` (43), `NativeEventBus.kt` (108), `LiveState.kt` (40),
  `SecureStore.kt` (229), `DeviceHttpClient.kt` (86), `TimeUtils.kt` (104),
  `JsonConvert.kt` (74), `policy/PolicyModels.kt` (86), `policy/PolicyEvaluator.kt` (77),
  `policy/PolicyJson.kt` (78)
- JVM unit tests under `android/app/src/test/kotlin/...` (`AudioAssistanceStartGateTest`,
  `AudioAssistanceRecreationTest`, `AudioAssistanceSessionWatchdogTest`,
  `policy/PolicyEvaluatorTest`)
- `android/app/build.gradle.kts`, `android/settings.gradle.kts`,
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- Generated build artifacts used **as evidence only**:
  `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`
  (merged, released-variant manifest) and `.flutter-plugins-dependencies`
- Docs used only for runtime/test evidence: `docs/runtime-device-matrix.md`,
  `docs/stage5_background_audio_survival_report.md`, `docs/verification-report.md`,
  `docs/integrations-setup.md`, `docs/app-restrictions.md`, `docs/device-enrollment.md`,
  `docs/device-owner-provisioning.md`, `docs/screen-recording-plan.md`,
  `docs/bug-report.md`, `docs/remote-assistance.md`, `docs/read_only_audit_2026-10-27.md`,
  `docs/evidence/stage8/media-verified-11-55Z.txt`
- Flutter call sites needed to interpret the native contract:
  `lib/data/services/device_admin_service.dart` (301), `integration_test/device_capabilities_test.dart`

Findings about the working tree:

- `android_dpc/` is **empty** (directory listing returns 0 files) and
  `android/settings.gradle.kts:26` includes only `:app`, so no DPC / managed-provisioning
  module is built or linked.
- There is **one** Android module and **three** manifests only (main/debug/profile);
  no product flavors, no build-variant manifests beyond those.
- No device and no emulator were touched in this audit; all runtime statements are
  quoted from the docs above. Anything without such a quote is marked `(assumption)`.
- Flutter UI and SQL were not audited here (other subagents); Flutter lines are cited only
  where they are needed to show whether a native capability is called at all.

## 2. Findings

### 2.1 Permission inventory (main manifest) and what each is for

| Permission | Declared | Purpose in code | Notes / risk | Citation |
|---|---|---|---|---|
| `INTERNET` | yes | all HTTPS sync/WebRTC signalling | also re-declared for debug/profile | `android/app/src/main/AndroidManifest.xml:4`, `android/app/src/debug/AndroidManifest.xml:6` |
| `ACCESS_NETWORK_STATE` | yes | `isOnline()` heartbeat | read-only | `.../AndroidManifest.xml:5`, `GuardianService.kt:523-531` |
| `ACCESS_COARSE_LOCATION` | yes | fallback fix, requested with FINE | | `.../AndroidManifest.xml:6`, `NativeBridge.kt:467-470` |
| `ACCESS_FINE_LOCATION` | yes | `LocationTrackingService`, last-known fix | gated at start | `.../AndroidManifest.xml:7`, `NativeBridge.kt:546-551` |
| `ACCESS_BACKGROUND_LOCATION` | yes | **only reported, never requested** — dead grant path, Play declaration risk | see §2.8 | `.../AndroidManifest.xml:8`, `NativePermissions.kt:22-27` |
| `CAMERA` | yes | requested before WebRTC video; capture itself is plugin-side | no app-side camera code | `.../AndroidManifest.xml:9`, `NativeBridge.kt:465`, `GeneratedPluginRegistrant.java:34` |
| `RECORD_AUDIO` | yes | gates the microphone FGS and WebRTC mic track | checked 3× before start | `.../AndroidManifest.xml:10`, `AudioAssistanceService.kt:231-240,277-286,414-418` |
| `POST_NOTIFICATIONS` | yes | FGS notification visibility on API 33+ | refusing it blocks both FGS starts | `.../AndroidManifest.xml:11`, `NativeBridge.kt:336-341,471-475` |
| `FOREGROUND_SERVICE` | yes | all three services | | `.../AndroidManifest.xml:12` |
| `FOREGROUND_SERVICE_DATA_SYNC` | yes | `GuardianService` type | Android 15 time cap applies | `.../AndroidManifest.xml:13`, `GuardianService.kt:149-167` |
| `FOREGROUND_SERVICE_LOCATION` | yes | `LocationTrackingService` type | | `.../AndroidManifest.xml:14`, `LocationTrackingService.kt:242-252` |
| `FOREGROUND_SERVICE_MICROPHONE` | yes | `AudioAssistanceService` type | | `.../AndroidManifest.xml:15`, `AudioAssistanceService.kt:582-600` |
| `WAKE_LOCK` | yes | partial lock while mic session runs | **no timeout** — see §2.8 | `.../AndroidManifest.xml:17`, `AudioAssistanceService.kt:616-627` |
| `RECEIVE_BOOT_COMPLETED` | yes | `BootReceiver` restarts guardian only | Android 15 refuses boot start | `.../AndroidManifest.xml:18`, `BootReceiver.kt:31-37` |
| `PACKAGE_USAGE_STATS` | yes (`tools:ignore="ProtectedPermissions"`) | `UsageStatsManager` queries | special access, self-grant impossible | `.../AndroidManifest.xml:19-23`, `NativePermissions.kt:34-55` |
| `QUERY_ALL_PACKAGES` | yes (`tools:ignore`) | installed-app inventory | Play-restricted permission, acknowledged in a comment | `.../AndroidManifest.xml:24-29`, `InstalledApps.kt:15-21` |

Permissions merged in from plugins (not visible in the source manifest):
`BLUETOOTH` (`maxSdkVersion=30`) and `MODIFY_AUDIO_SETTINGS` from `flutter_webrtc`, plus a
signature-level `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`:
`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml:62-69`.

Permissions deliberately **absent** (verified by repo-wide search over `android/` and
`android_dpc/`): `SYSTEM_ALERT_WINDOW`, `BIND_ACCESSIBILITY_SERVICE`,
`BIND_NOTIFICATION_LISTENER_SERVICE`, `FOREGROUND_SERVICE_CAMERA`,
`FOREGROUND_SERVICE_MEDIA_PROJECTION`, `READ_SMS`, `READ_CALL_LOG`, `READ_PHONE_STATE`,
`READ_CONTACTS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `SCHEDULE_EXACT_ALARM`,
`WRITE_EXTERNAL_STORAGE`, any `BIND_VPN_SERVICE`/VPN permission. This absence is the
single most important fact in this audit: six of the thirteen AirDroid categories have
no native primitive at all (§2.6).

### 2.2 `uses-feature`, backup, network config, queries, SDK levels

| Item | Value | Citation |
|---|---|---|
| `uses-feature camera` | `required="false"` | `android/app/src/main/AndroidManifest.xml:31-33` |
| `uses-feature microphone` | `required="false"` | `.../AndroidManifest.xml:34-36` |
| `uses-feature location.gps` | `required="false"` | `.../AndroidManifest.xml:37-39` |
| `allowBackup` | **`false`** (good: encrypted prefs and device secret are not backed up) | `.../AndroidManifest.xml:43` |
| `networkSecurityConfig` | **none declared**; no `usesCleartextTraffic` either (repo search, 0 hits) | absence; `DeviceHttpClient.kt:19-30` enforces `https://` in code |
| `queries` | only `PROCESS_TEXT` (Flutter engine); package visibility relies on `QUERY_ALL_PACKAGES` | `.../AndroidManifest.xml:126-131` |
| `minSdk` | **24** | `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml:8` |
| `targetSdk` | **36** | same file `:9`; `android/app/build.gradle.kts:22-23` uses the Flutter defaults |
| Application class | default `android.app.Application` (no custom Application) | merged manifest `:71-77` |
| Release signing | **debug keystore** (`signingConfig = signingConfigs.getByName("debug")`) | `android/app/build.gradle.kts:28-34` |

There is no `res/xml/network_security_config.xml`; the only file under `res/xml/` is
`device_admin.xml` (`android/app/src/main/res/xml/device_admin.xml:1-6`), which requests
**no** device-admin policies (`<uses-policies />`).

### 2.3 Manifest components: exported surface, filters, FGS types

| Component | Exported | Intent filter / type | Start / stop | Restart semantics | Failure modes | Citation |
|---|---|---|---|---|---|---|
| `MainActivity` | **true** | `MAIN/LAUNCHER`; `VIEW parentcontrol://auth-callback` (DEFAULT+BROWSABLE) | user launch | `singleTop`, `taskAffinity=""`; engine cached process-wide | engine created only on first Activity; cached-engine reuse is intentional | `.../AndroidManifest.xml:46-76` |
| `GuardianService` | false | `foregroundServiceType="dataSync"` | `ContextCompat.startForegroundService` from `startGuardianService`, `BootReceiver` | `START_STICKY` when configured | Android 12+ background-start block → error stored + `stopSelf`; Android 15 timeout → `onTimeout` + `stopSelf` | `.../AndroidManifest.xml:78-81`, `GuardianService.kt:53-67,129-135,149-167` |
| `LocationTrackingService` | false | `foregroundServiceType="location"` | from `startLocationTracking` (UI only) | `START_STICKY` | missing fine-location or notifications → `stopSelf`; no provider enabled → `stopSelf`; **not restarted at boot** | `.../AndroidManifest.xml:83-86`, `LocationTrackingService.kt:62-97,112-162` |
| `AudioAssistanceService` | false, `stopWithTask="false"` | `foregroundServiceType="microphone"` | `startAudioAssistanceService` / notification `ACTION_STOP` | `START_NOT_STICKY` (mic never resurrected) | start gate (mic + notifications), `startForeground` throw, capture-heartbeat loss, permission revocation, parent end | `.../AndroidManifest.xml:88-92`, `AudioAssistanceService.kt:371-443` |
| `ParentControlDeviceAdminReceiver` | **true**, protected by `BIND_DEVICE_ADMIN` | `DEVICE_ADMIN_ENABLED`, `device_admin` meta-data | system only | n/a | enables **admin only**, never Device Owner | `.../AndroidManifest.xml:94-104`, `ParentControlDeviceAdminReceiver.kt:5-18` |
| `BootReceiver` | false | `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` | system | guardian only | API ≥ 35 records an error and returns; missing notification permission records an error | `.../AndroidManifest.xml:106-114`, `BootReceiver.kt:18-52` |

Transitive exported components in the shipped manifest (not app-authored): `urllauncher.WebViewActivity`
(exported=false), CameraX `MetadataHolderService` (exported=false, enabled=false),
ML Kit `MlKitInitProvider` (exported=false, authority `…mlkitinitprovider`),
`androidx.profileinstaller.ProfileInstallReceiver` (**exported=true, guarded by
`android.permission.DUMP`**), and Play-services datatransport services
(`…AndroidManifest.xml:164,172,188,203,209,218,233,253,260`).

### 2.4 Kotlin capability summary (what each file actually does)

| Capability | Implementation | How started / stopped | Evidence |
|---|---|---|---|
| Process-scoped Flutter engine | `FlutterEngineCache` entry `parentcontrol_main_engine`, engine started once, never destroyed with the Activity | first `MainActivity.onCreate` | `MainActivity.kt:26-27,29-50,59-65` |
| MethodChannel `com.parentcontrol/native` + EventChannel `com.parentcontrol/native_events` | engine-scoped `NativeBridge`; 25 methods dispatched | created on engine configure; Activity ref attached/detached | `NativeBridge.kt:40-41,94-116,118-170` |
| Capability/identity/battery probes | `getCapabilities`, `getDeviceIdentity` (returns device secret + SHA-256), `getBatteryStatus` | synchronous channel calls | `NativeBridge.kt:183-255`; `SecureStore.kt:93-104` |
| Installed-app inventory | `PackageManager.getInstalledPackages(0)`, label/system flag/version | on demand and every 30 min from guardian | `InstalledApps.kt:15-42`, `GuardianService.kt:40,217-219,396-422` |
| Policy application | `DevicePolicyManager.setPackagesSuspended` only, DO-gated; re-reads state via `isPackageSuspended` | `applyPolicy` method, `apply_policy`/`sync_policy` commands, 60 s tick | `PolicyApplier.kt:31-153,209-254`; `GuardianService.kt:184-193,266-298` |
| Background sync | 10 s scheduler tick, 20 s command poll with backoff to 300 s, 5 min heartbeat, 30 min app upload, 60 min usage upload, location upload | `GuardianService` | `GuardianService.kt:37-41,120-126,169-224,365-491` |
| Device-authenticated HTTP | HTTPS-only `HttpURLConnection`, `apikey`/Bearer/`x-device-id`/`x-device-secret` headers, 15 s/20 s timeouts | per request | `DeviceHttpClient.kt:17-73` |
| Usage-stats reporting | `UsageStatsManager.queryUsageStats(INTERVAL_DAILY)`, per-day aggregation, 400-day loop cap | on demand and hourly | `UsageReporter.kt:21-86`, `NativeBridge.kt:558-588` |
| Location tracking | `LocationManager` GPS+NETWORK updates, last-known seed, mock flag, in-process `LiveState` | FGS start/stop from UI only | `LocationTrackingService.kt:112-187`, `LiveState.kt:24-40` |
| One-way audio keep-alive | microphone FGS, partial wake lock, permission watchdog (5 s), capture watchdog (15 s/45 s), parent-end watchdog (15 s to `remote-session`) | Dart `start…`/`stop…`/`noteCaptureHeartbeat` | `AudioAssistanceService.kt:107-118,209-218,325-367,667-727` |
| Encrypted local state | `EncryptedSharedPreferences` AES256-GCM/SIV, installation id, 32-byte device secret | lazily instantiated singleton | `SecureStore.kt:70-104` |
| Native → Dart events | `service_status`, `location_update`, `command`, `audio_assistance_started/_start_failed/_stopped/_detached` | single `EventChannel` sink | `NativeEventBus.kt:22-107` |

Not present anywhere in Kotlin: `AccessibilityService`, `NotificationListenerService`,
`MediaProjection`/`VirtualDisplay`/`ImageReader`/`MediaRecorder`, `VpnService`,
`SYSTEM_ALERT_WINDOW` overlay, `WorkManager`/`JobScheduler`/`AlarmManager`, FCM,
default SMS/dialer role, geofencing, camera capture, clipboard or file provider.

### 2.5 Is enforcement real? (requested verification)

**App blocking — not enforced on a normal install (policy + honest reporting only).**
`PolicyApplier.apply()` builds the desired suspension set, then explicitly refuses to
change anything unless `isDeviceOwnerApp()` is true: it adds
`"Device Owner provisioning is required to suspend apps on this device. No apps were
suspended."` and clears the set (`PolicyApplier.kt:94-101`). Suspension itself is only
`setPackagesSuspended(..., true)` (`PolicyApplier.kt:236-244`) and the result is
re-confirmed with `isPackageSuspended` before being stored/reported
(`PolicyApplier.kt:119-134,209-220`). The admin receiver comments say the same, and the
component can only ever be *Device Admin* (`ParentControlDeviceAdminReceiver.kt:5-16`;
`device_admin.xml:2-6` requests no policies). Runtime evidence: `dpm list-owners` =
"no owners", device admin only (`docs/read_only_audit_2026-10-27.md:505`), and a saved v2
policy was acknowledged `failed` with the Device Owner error
(`docs/verification-report.md:575`). There is **no** Accessibility-based app blocker, no
overlay, no usage-stats "app closer" loop (repo search: no `AccessibilityService`,
`SYSTEM_ALERT_WINDOW`, `MEDIA_PROJECTION` anywhere). Status: `BLOCKED — ACCESS REQUIRED`
(Device Owner). The only platform-feasible fallbacks for a non-DO install are
Accessibility or overlay — neither is implemented, and neither is planned in
`docs/app-restrictions.md:55-56`, which states the app never uses Accessibility.

**Screen mirroring — absent, not "stored but off".** No `MediaProjection`, `VirtualDisplay`,
`ImageReader` or `MediaRecorder` in the app's Kotlin, no capture permission, no
`mediaProjection` FGS type (`android/app/src/main/AndroidManifest.xml:4-29,78-92`).
Independent confirmation: `docs/bug-report.md:1279-1298` (packaged manifest, dex
attribution, `dumpsys media_projection` empty) and `docs/screen-recording-plan.md:1-9`
("NOT IMPLEMENTED … nothing in it exists in the repository"). Screen *viewing* is
therefore not merely untested — it does not exist. Status: `MISSING`.

**Downtime / schedules — partially enforced, bedtime is not enforced at all.**
Per-app windows are parsed and evaluated (`PolicyModels.kt:4-35,67-76`;
`PolicyJson.kt:54-72`) and unit-tested (`android/app/src/test/kotlin/.../policy/PolicyEvaluatorTest.kt`).
But: (a) enforcement is the same DO-only suspension path (`PolicyApplier.kt:50-74,94-101`);
(b) bedtime is computed **for reporting only** —
`"Informational only: bedtime is stored but app suspension follows app rules"
(``PolicyApplier.kt:296-299``); (c) `daily_screen_time_limit_minutes` is parsed
(`PolicyJson.kt:16`) and stored (`PolicyModels.kt:43`) but **never read** anywhere in
Kotlin (grep over `android/app/src/main/kotlin` shows only those two lines). So "downtime"
as an all-app pause and "daily screen time" are policy fields without an enforcement path.

**Instant block — policy delivery exists, "instant" and "block" do not.** A parent action
becomes an `apply_policy` command that the child polls every 20 s, with backoff multipliers
of 2/3/6 up to 300 s (`GuardianService.kt:37,195-212`), and the service applies it on a
60 s tick (`GuardianService.kt:184-193`). There is no push channel (no FCM anywhere;
`docs/integrations-setup.md:24`), and the guardian must be alive — it is a `dataSync` FGS
that Android 15 stops at its time limit (`GuardianService.kt:149-167`) and that `BootReceiver`
refuses to start on API ≥ 35 (`BootReceiver.kt:31-37`). Even with a live service the block
still needs Device Owner. Status: `BLOCKED — ACCESS REQUIRED`, with a latency floor of
~20 s and no enforcement without DO.

### 2.6 AirDroid category → native capability matrix

| # | AirDroid category | Native mechanism (or absence) | Started/stopped | Status | Prerequisite / feasibility for a normal third-party app |
|---|---|---|---|---|---|
| 1 | Camera | `CAMERA` runtime permission requested before WebRTC; capture is `flutter_webrtc`'s `getUserMedia`, not app code (`NativeBridge.kt:465`, `GeneratedPluginRegistrant.java:29-33`). Child consent + Join gate it in Dart (`lib/features/remote_assistance/remote_session_controller.dart:1521-1536`) | per session | `IMPLEMENTED — PARTIALLY VERIFIED` | camera permission + explicit child consent; **no** camera FGS type, so no background camera path (`AndroidManifest.xml:78-92`). One-phone preview LIVE VERIFIED (`docs/remote-assistance.md:119`); two-device video NOT TESTED (`docs/verification-report.md:581`) |
| 2 | Screen mirroring | none | — | `MISSING` | MediaProjection + per-session consent dialog; intentionally out of scope (`docs/screen-recording-plan.md:1-9`) |
| 3 | One-way audio | mic FGS + WebRTC audio track kept alive by the process-scoped engine (`MainActivity.kt:9-23`, `AudioAssistanceService.kt:24-67`) | Dart start/stop, notification Stop, parent end, permission loss | `FULLY IMPLEMENTED — VERIFIED` | RECORD_AUDIO + POST_NOTIFICATIONS; no DO/Accessibility. Runtime: FGS `foregroundId=4303`, RTP `in 5463 pkts / out 0` (`docs/evidence/stage8/media-verified-11-55Z.txt:7,16`); lock/Recents/force-stop matrix (`docs/stage5_background_audio_survival_report.md:144-151`) |
| 4 | Instant block | DO-gated `setPackagesSuspended` only (`PolicyApplier.kt:94-101,236-244`); command poll 20 s (`GuardianService.kt:37,195-212`) | command → tick | `BLOCKED — ACCESS REQUIRED` | **Device Owner** (factory-reset/adb provisioning). Without it the app honestly reports unsupported (`docs/verification-report.md:575`). No accessibility/overlay fallback |
| 5 | Downtime | per-app windows evaluated (`PolicyModels.kt:4-35`); bedtime informational only (`PolicyApplier.kt:296-299`); daily limit unused (`PolicyJson.kt:16`) | 60 s tick inside guardian | `PARTIALLY IMPLEMENTED` | Device Owner for any enforcement; no all-app pause mechanism; tick stops when the service stops |
| 6 | App management (list/suspend) | installed-app inventory + upload (`InstalledApps.kt:15-42`, `GuardianService.kt:396-422`); suspension DO-only | on demand / 30 min | `PARTIALLY IMPLEMENTED` | inventory needs `QUERY_ALL_PACKAGES` (Play declaration); suspend/restore need Device Owner |
| 7 | Notifications (read child notifications) | none — no `NotificationListenerService` anywhere | — | `MISSING` | Notification Listener access (`BIND_NOTIFICATION_LISTENER_SERVICE`) + user grant; feasible but not implemented |
| 8 | Social / image detection | none; ML Kit is present only transitively for QR scanning (`mobile_scanner`), barcode registrar only (`build/.../AndroidManifest.xml:188-207`) | — | `MISSING` | requires Accessibility + screen capture (MediaProjection) or root; **not feasible** for a normal third-party app under this architecture |
| 9 | Calls / SMS | none — no SMS/call-log/phone-state permission, no `ROLE_SMS`/`ROLE_DIALER`, no `TelecomManager` use (repo search, 0 hits) | — | `MISSING` | default SMS/dialer role + Play-restricted permissions; **not feasible** as a normal app for interception/blocking |
| 10 | Website restrictions | none — no `VpnService`, DNS, proxy or Accessibility-based URL inspection | — | `MISSING` | VPN service with user consent (feasible) or Accessibility; neither implemented |
| 11 | Location | `LocationTrackingService` + `LiveState` + guardian upload (`LocationTrackingService.kt:112-187`, `GuardianService.kt:458-491`) | UI start/stop only | `IMPLEMENTED — PARTIALLY VERIFIED` | fine location + notifications; background location **never requested** (§2.8). Runtime: real fused fix, start/stop clean (`docs/verification-report.md:580`) |
| 12 | Route | only individual fixes uploaded with `recorded_at`/`source` (`GuardianService.kt:476-491`); no route reconstruction, no distance/geocode natively | per fix | `PARTIALLY IMPLEMENTED` | no extra permission; history depends on backend/UI (other subagents) |
| 13 | Geofence | none — `geofenceEnter/Exit` exist only as Flutter alert types (`lib/data/models/telemetry.dart:206-221`); no `GeofencingClient`, no native geofence registration | — | `MISSING` | Play-services geofencing + background location (feasible); not implemented |

Counts over these 13 rows: fully verified 1, partially verified 2, partial 3, blocked 1,
missing 6. Nothing is `UI ONLY` at native level because the six missing categories have no
native half either.

### 2.7 API-level constraints (minSdk 24 / targetSdk 36)

| Constraint | Handling | Citation |
|---|---|---|
| `FOREGROUND_SERVICE_TYPE_DATA_SYNC` exists from API 29 | guarded `SDK_INT >= Q` | `GuardianService.kt:606-617` |
| `FOREGROUND_SERVICE_TYPE_MICROPHONE` exists from API 30 | guarded `SDK_INT >= R` | `AudioAssistanceService.kt:585-593` |
| `FOREGROUND_SERVICE_TYPE_LOCATION` exists from API 29 | guarded `SDK_INT >= Q` | `LocationTrackingService.kt:244-252` |
| `POST_NOTIFICATIONS` runtime permission from API 33 | both FGS starts refuse without it | `AudioAssistanceService.kt:104,231-240,414-418`; `NativeBridge.kt:336-341,471-475` |
| Android 15 (API 35) forbids dataSync FGS start at boot | explicit refusal + stored error | `BootReceiver.kt:31-37` |
| Android 14+/15 dataSync time limit | `onTimeout(startId)` and `onTimeout(startId, fgsType)` stop cleanly | `GuardianService.kt:149-167` |
| No `java.time` below API 26 | `SimpleDateFormat` helpers | `TimeUtils.kt:7-23` |
| `Location.isMock` from API 31 | guarded `SDK_INT >= S` | `NativeBridge.kt:529-534`; `LocationTrackingService.kt:171-176` |
| `AppOpsManager.unsafeCheckOpNoThrow` from API 29 | guarded `SDK_INT >= Q` | `NativePermissions.kt:37-50` |
| Background FGS start restrictions (API 31+) | start only from UI or notification action; failures are caught and reported, never faked | `GuardianService.kt:53-67`; `AudioAssistanceService.kt:277-298,582-601` |
| Android 12+ notification trampoline restrictions | all `PendingIntent`s target an Activity directly or a service action, all `FLAG_IMMUTABLE` | `GuardianService.kt:589-594`; `AudioAssistanceService.kt:543-558`; `LocationTrackingService.kt:225-230` |

Behavior that the code cannot deliver at any API level, and says so:
Force Stop / OEM task cleaners / process death end mic capture and background sync
(`AudioAssistanceService.kt:58-61`, `docs/stage5_background_audio_survival_report.md:188-190`);
boot restart of the guardian on Android 15+ requires the user to open the app
(`BootReceiver.kt:31-37`); location sharing does not resume after reboot
(`BootReceiver.kt:18-52`, `docs/integrations-setup.md:517-519`).

### 2.8 Battery and ColorOS (realme RMX2161, ColorOS 12 / API 31) implications

- **No battery-optimisation exemption is ever requested.** Repo search for
  `IGNORE_BATTERY_OPTIMIZATIONS`/`isIgnoringBatteryOptimizations` returns nothing; the
  manifest has no such permission (`AndroidManifest.xml:4-29`). Both test devices were
  "not whitelisted" and battery settings were deliberately left at defaults
  (`docs/runtime-device-matrix.md:66`, `docs/stage5_background_audio_survival_report.md:178-180`).
- **ColorOS freezer observed:** after HOME with no link, `dumpsys activity services` was
  empty and the process was frozen by `OplusHansManager`
  (`docs/read_only_audit_2026-10-27.md:503`). That run was in an unlinked state, so it is
  not proof of a defect, but it is the OEM behaviour this design has to survive.
- **Notification channel can be silently invisible:** the realme `audio_assistance_channel`
  had importance `NONE` while the service ran (`docs/stage5_background_audio_survival_report.md:175-177`).
  Because the start gate only checks `POST_NOTIFICATIONS` (`AudioAssistanceService.kt:231-240`),
  a per-channel block produces a running mic FGS with no visible notice — a privacy
  regression the app cannot detect with public APIs (`(assumption)` that channel-level
  block is indistinguishable from app-level grant on ColorOS).
- **Wake lock without timeout:** a non-reference-counted `PARTIAL_WAKE_LOCK` is acquired at
  session start and only released on stop (`AudioAssistanceService.kt:616-638`). A long
  session keeps the CPU awake for its whole duration; there is no `acquire(timeout)`.
  Justified for audio continuity, but it is the largest battery cost in the app.
- **Guardian wake-up pattern:** 10 s scheduler tick, 20 s HTTPS poll, 5 min heartbeat,
  30 min app upload, 60 min usage upload (`GuardianService.kt:37-41,120-126,169-224`).
  Continuous radio wakeups on a child phone are a battery and OEM-freezer target
  (`(assumption)` on measured drain — no power measurement exists in the repo).
- **Data sync is not a durable scheduler:** there is no `WorkManager`, `JobScheduler` or
  `AlarmManager` anywhere in `android/app/src/main/kotlin`, so once the FGS is stopped
  (15/16 timeout, force stop, OEM clean) nothing wakes the app until the child opens it
  (`docs/device-owner-provisioning.md:45`).

### 2.9 Security-relevant native items

| Item | Finding | Citation |
|---|---|---|
| Exported `MainActivity` with unverified custom scheme | any app can fire `parentcontrol://auth-callback…`; the URL is handed to Dart via `app_links`. Custom schemes are hijackable; impact depends on whether Dart treats the URL as trusted auth material `(assumption)` | `AndroidManifest.xml:46-48,68-75`; `GeneratedPluginRegistrant.java:20-24` |
| Exported device-admin receiver | `exported="true"` but protected by the system-only `BIND_DEVICE_ADMIN` permission — standard and correct | `AndroidManifest.xml:94-104` |
| Other exported component | transitive `androidx.profileinstaller.ProfileInstallReceiver` (`exported=true`, `android.permission.DUMP`), system/shell-only | `build/.../AndroidManifest.xml:233-250` |
| PendingIntents | all `FLAG_IMMUTABLE`; no mutable PendingIntent, no implicit-intent PendingIntent | `GuardianService.kt:589-594`; `AudioAssistanceService.kt:543-558`; `LocationTrackingService.kt:225-230` |
| Services | all three `exported="false"`; start actions are app-internal | `AndroidManifest.xml:78-92` |
| Device secret handling | 32-byte `SecureRandom` secret in `EncryptedSharedPreferences`; returned to Dart over the method channel; sent as `x-device-secret` header over HTTPS only; no logging of credentials anywhere in Kotlin (repo search for `Log.`/`println` = 0 hits) | `SecureStore.kt:70-104`; `NativeBridge.kt:206-220`; `DeviceHttpClient.kt:43-46` |
| Transport hardening | HTTPS enforced in code at two points; **no certificate pinning / network security config** | `DeviceHttpClient.kt:19-30`; absence of `networkSecurityConfig` |
| Capture visibility | microphone capture always carries an ongoing, non-dismissible notification with a Stop action; the service self-stops after 45 s without Dart capture confirmations, so the notification cannot outlive real capture | `AudioAssistanceService.kt:117,142-149,348-367,539-575` |
| Child stop path | notification action stops capture immediately and reports `child_stopped` | `AudioAssistanceService.kt:375-383` |
| Clipboard / file providers | none of the app's own; only transitive ML Kit/AndroidX providers; no `FileProvider`, no clipboard code | `build/.../AndroidManifest.xml:203,218` |
| Backup | `allowBackup="false"` — device secret and policy state not backed up | `AndroidManifest.xml:43` |
| Release signing | release variant signed with the **debug** keystore — not shippable as a real product build | `android/app/build.gradle.kts:28-34` |
| Dead permission path | `ACCESS_BACKGROUND_LOCATION` is declared but `requestPermissions` never reads the `backgroundLocation` argument, and `openBackgroundLocationSettings()` only opens the app-details page | `AndroidManifest.xml:8`; `NativeBridge.kt:455-497,424`; controller passes it anyway at `lib/features/child/controllers/child_shell_controller.dart:787` |
| Shared PendingIntent aliasing | Guardian, audio and location use request code 0 with the same `MainActivity` intent and `FLAG_UPDATE_CURRENT`, so they resolve to one PendingIntent — benign today, but any per-notification extra would collide | `GuardianService.kt:586-594`; `AudioAssistanceService.kt:540-548`; `LocationTrackingService.kt:222-230` |

### 2.10 Evidence quality per capability

| Capability | Code | Automated test | Runtime evidence | Status |
|---|---|---|---|---|
| One-way audio FGS | yes | JVM start-gate/watchdog/recreation tests (`android/app/src/test/kotlin/.../AudioAssistanceStartGateTest.kt`, `...SessionWatchdogTest.kt`, `...RecreationTest.kt`) | `docs/evidence/stage8/media-verified-11-55Z.txt:7,16`; `docs/stage5_background_audio_survival_report.md:144-151` | `FULLY IMPLEMENTED — VERIFIED` |
| Guardian service / heartbeat / policy ack | yes | no service-level test (JVM tests cover only pure policy logic) | `docs/verification-report.md:576` (visible notification, heartbeat, poll) | `IMPLEMENTED — PARTIALLY VERIFIED` |
| App suspension | yes | pure policy tests only (`PolicyEvaluatorTest.kt`) | refused with DO error, no owners (`docs/verification-report.md:575`, `docs/read_only_audit_2026-10-27.md:505`) | `BLOCKED — ACCESS REQUIRED` |
| Location | yes | no Kotlin test; integration probe `integration_test/device_capabilities_test.dart:77-90` | `docs/verification-report.md:580` | `IMPLEMENTED — PARTIALLY VERIFIED` |
| Usage stats | yes | none | `docs/verification-report.md:579` (32 rows, uploaded) | `IMPLEMENTED — PARTIALLY VERIFIED` |
| Camera/video | plugin only | integration probe `integration_test/child_media_selftest_test.dart` | one-phone preview `docs/remote-assistance.md:119`; two-device NOT TESTED | `IMPLEMENTED — PARTIALLY VERIFIED` |
| Screen capture / mirroring | no | — | absence re-verified five ways `docs/bug-report.md:1292-1298` | `MISSING` |

## 3. Evidence gaps / BLOCKED items

1. **`BLOCKED — ACCESS REQUIRED`: Device Owner.** No DO device exists; `android_dpc/` is
   empty and no provisioning activity/QR path exists (`android/settings.gradle.kts:26`,
   `docs/device-owner-provisioning.md:1-10,43`). Therefore every DO-dependent claim
   (suspension, restore, reboot persistence, schedule enforcement) is unproven on hardware.
2. **`BLOCKED` — two-device video.** Only audio sessions were exercised on 2026-10-29
   (`docs/runtime-device-matrix.md:80-85`); camera-in-background behaviour is therefore
   unverified, and there is no `FOREGROUND_SERVICE_CAMERA` type to make it possible
   (`AndroidManifest.xml:78-92`). Stated as an inference where it matters.
3. **`NOT TESTED` — Android 15/16 paths.** API-35 boot refusal and the dataSync timeout
   handler exist (`BootReceiver.kt:31-37`, `GuardianService.kt:149-167`) but the test child
   device is API 31 (`docs/runtime-device-matrix.md:14`); no Android 15+ run exists.
4. **`NOT TESTED` — OEM kill/freeze durability.** One observation of `OplusHansManager`
   freezing the process exists (`docs/read_only_audit_2026-10-27.md:503`), but no
   controlled test of auto-start/battery-exemption settings was performed; the repo
   explicitly leaves them at defaults (`docs/stage5_background_audio_survival_report.md:178-180`).
5. **Doc drift found while cross-checking (not a code bug).** `docs/remote-assistance.md:30`
   still says the app "does not run a camera/microphone foreground service", which the
   later `AudioAssistanceService` contradicts (`android/app/src/main/AndroidManifest.xml:88-92`);
   `docs/screen-recording-plan.md:66` says the bridge has "19 methods" while
   `NativeBridge.kt:118-164` dispatches 25. Report these as stale docs, not as behaviour.
6. **Notification-listener / accessibility / VPN / geofence / SMS-role capabilities are
   absent by design or by omission**; no runtime test can exist for absent code, so their
   status is `MISSING`, not `BROKEN`.
7. No power/battery measurement (mAh, wake-lock duration, radio time) exists in the repo;
   battery statements here are mechanism-level, not measured.

## 4. One-paragraph summary a reviewer can trust

The Android layer is a small, honest, consent-driven native implementation: one activity
with an engine cached process-wide, a 25-method `com.parentcontrol/native` bridge, three
non-exported foreground services (`dataSync` guardian, `location` sharing, `microphone`
one-way audio), one boot receiver and one device-admin receiver, plus an HTTPS
device-authenticated command/telemetry loop against Edge Functions. Its strongest verified
capability is one-way audio: the microphone FGS, wake lock, capture heartbeat, permission
watchdog and parent-end watchdog all exist, and packet-level runtime evidence plus a
lock/Recents/force-stop matrix are on file. Its central limitation is that *enforcement*
is not present for a normal install: app blocking, per-app schedules and "instant block"
all funnel through `setPackagesSuspended`, which the code applies only when the app is
Device Owner — and no DO provisioning exists (`android_dpc/` is empty, no provisioning
activity, no `clearDeviceOwnerApp`). Bedtime and daily screen-time limits are parsed but
never enforced, and six AirDroid categories (screen mirroring, notifications, social/image
detection, calls/SMS, website restrictions, geofence) have no native primitive at all, with
several of them not feasible for a normal third-party app without Accessibility, VPN,
MediaProjection or default-app roles. Background durability is the other structural gap:
there is no push, no WorkManager/AlarmManager, dataSync is time-capped on Android 15+, boot
restart is refused on 35+, and the only test device (ColorOS 12) has frozen the process and
once hid the microphone notification entirely. Release hygiene also needs attention: the
release variant is signed with the debug keystore, `ACCESS_BACKGROUND_LOCATION` is declared
but never requestable, and the exported activity accepts an unverified custom-scheme deep
link.

```
counts: fully_verified=1 partially_verified=2 partial=3 ui_only=0 backend_only=0
code_untested=0 broken=0 missing=6 blocked=1 not_applicable=0
```
