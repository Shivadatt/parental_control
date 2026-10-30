# 07 — Android native capability audit

Source: `audit/_work/s3-android-native.md` (361 lines). Manifest, Kotlin and device evidence read directly; no build or install was performed.

## 1. Declared surface

**Permissions (source manifest)** — 16: INTERNET, ACCESS_NETWORK_STATE, COARSE/FINE location, **ACCESS_BACKGROUND_LOCATION (declared but never requested)**, CAMERA, RECORD_AUDIO, POST_NOTIFICATIONS, FOREGROUND_SERVICE + DATA_SYNC + LOCATION + MICROPHONE, WAKE_LOCK, RECEIVE_BOOT_COMPLETED, PACKAGE_USAGE_STATS, QUERY_ALL_PACKAGES. Plugins add BLUETOOTH (≤API 30) and MODIFY_AUDIO_SETTINGS.

**Deliberately absent** (repo-wide search): SYSTEM_ALERT_WINDOW, BIND_ACCESSIBILITY_SERVICE, BIND_NOTIFICATION_LISTENER_SERVICE, FOREGROUND_SERVICE_CAMERA, FOREGROUND_SERVICE_MEDIA_PROJECTION, READ_SMS, READ_CALL_LOG, READ_PHONE_STATE, READ_CONTACTS, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, SCHEDULE_EXACT_ALARM, any VPN service. **This absence determines which AirDroid categories can exist at all.**

**Components**

| Component | Exported | Type | Restart | Notes |
|---|---|---|---|---|
| MainActivity | **yes** | launcher + `parentcontrol://auth-callback` | n/a | custom scheme is hijackable; engine is process-scoped |
| GuardianService | no | `dataSync` FGS | `START_STICKY` when configured | Android 15 time cap → `onTimeout` → stop; boot start refused on API ≥ 35 |
| LocationTrackingService | no | `location` FGS | `START_STICKY` | started from UI only; not restarted at boot |
| AudioAssistanceService | no, `stopWithTask=false` | `microphone` FGS | `START_NOT_STICKY` | never resurrects a mic |
| ParentControlDeviceAdminReceiver | yes (BIND_DEVICE_ADMIN) | device admin | system | admin only; **can never become Device Owner by itself** |
| BootReceiver | no | BOOT_COMPLETED / MY_PACKAGE_REPLACED | system | restarts guardian only, and refuses on API ≥ 35 |

`allowBackup=false`, no network security config, no certificate pinning; release variant is **signed with the debug keystore** (`android/app/build.gradle.kts:28-34`) — not shippable.

## 2. What the native layer actually does

| Capability | Implementation | Runtime evidence |
|---|---|---|
| Process-scoped engine | `FlutterEngineCache`, engine survives the Activity | used by mic/location services |
| MethodChannel (25 methods) + EventChannel | `NativeBridge`, `NativeEventBus` | app boots |
| Device identity | 32-byte secret in EncryptedSharedPreferences; `x-device-id`/`x-device-secret` over HTTPS | registration works |
| Installed apps | `getInstalledPackages`, uploaded every 30 min | live inventory observed |
| Policy application | `setPackagesSuspended` **only**, Device-Owner gated | `dpm list-owners` = none; suspension never executed |
| Background sync | 10 s tick, 20 s command poll (backoff to 300 s), 5 min heartbeat, 30/60 min uploads | heartbeat/presence observed |
| Usage stats | `UsageStatsManager.queryUsageStats` | 32 rows uploaded (historical) |
| Location | `LocationManager` GPS+NETWORK, FGS | real fix observed |
| One-way audio | mic FGS + wake lock + permission/capture/parent-end watchdogs | **live RTP + started playback track** |
| Events to Dart | `service_status`, `location_update`, `command`, audio lifecycle | works |

Not present in Kotlin at all: AccessibilityService, NotificationListenerService, MediaProjection/VirtualDisplay/MediaRecorder, VpnService, overlay, WorkManager/JobScheduler/AlarmManager, FCM, default SMS/dialer role, GeofencingClient, camera capture code, clipboard/FileProvider.

## 3. Enforcement reality (the decisive question)

| Feature | Claimed | Actual |
|---|---|---|
| Instant block | block apps | `PolicyApplier.apply()` refuses unless `isDeviceOwnerApp()`, clears the target set and records "Device Owner provisioning is required" (`PolicyApplier.kt:94-101`). Suspension itself only `setPackagesSuspended` (`:236-244`). No Accessibility/overlay fallback. **Inert on a normal install.** |
| Downtime | bedtime / daily limit | bedtime computed "for reporting only" (`PolicyApplier.kt:296-299`); `daily_screen_time_limit_minutes` parsed but never read. Per-app windows are evaluated but still DO-gated. **Not enforced.** |
| App inventory | installed list | works; suspension DO-only |
| Remote camera | request video | `flutter_webrtc` `getUserMedia(facingMode: user)` only; no rear camera, no torch, no camera FGS. **Never run on a device.** |
| Screen mirroring | — | absent at every layer (no MediaProjection, no permission, no service). **MISSING.** |
| Notifications monitoring | — | no NotificationListenerService. **MISSING.** |
| Social/image detection | — | no content source, no ML pipeline (ML Kit is transitive QR scanning only). **MISSING.** |
| Calls & SMS | — | no SMS/call permissions or roles. **MISSING.** |
| Website restrictions | — | no VpnService/DNS/accessibility URL inspection. **MISSING.** |
| Geofence | — | no GeofencingClient; geofences are evaluated server-side on uploaded fixes only. |

A separate truthfulness defect: even when nothing is suspended, `PolicyApplier` can report `success = errors.isEmpty()` (`:137`) and the ack path marks `enforcement_status = enforced` — so the parent can see a green "enforced" state on a phone that is enforcing zero apps.

## 4. API-level and OEM constraints

- minSdk 24, targetSdk 36. FGS types are correctly guarded by SDK level; POST_NOTIFICATIONS is required before either FGS starts; PendingIntents are immutable.
- Android 15+ forbids starting a `dataSync` FGS at boot and enforces a time cap; the app handles both by stopping cleanly — but that means **no background recovery until the user opens the app**.
- No WorkManager/JobScheduler/AlarmManager: no durable scheduling after force stop, reboot or OEM cleanup.
- No battery-optimisation exemption is ever requested; the mic FGS uses an untimed partial wake lock for the whole session.
- ColorOS/realme: process freezing was observed in an unlinked state; the mic notification channel was once `IMPORTANCE_NONE` while the service ran, which can hide capture from the user (privacy risk the app cannot detect).
- `ACCESS_BACKGROUND_LOCATION` is declared but the request path ignores the background argument, and "open settings" only opens app details — a dead permission path that also carries Play policy risk.

## 5. Security-relevant native findings

| Severity | Finding | Evidence |
|---|---|---|
| Medium | Exported launcher activity with an unverified custom scheme auth callback; any app can deliver a `parentcontrol://auth-callback` URL | `AndroidManifest.xml:46-48,68-75` |
| Medium | Release build signed with the debug keystore | `build.gradle.kts:28-34` |
| Low | No certificate pinning / network security config (HTTPS enforced in code only) | `DeviceHttpClient.kt:19-30` |
| Low | Shared PendingIntent request code 0 across three services with `FLAG_UPDATE_CURRENT` — benign today, collision-prone | `GuardianService.kt:586-594` |
| Good | Device secret never logged (repo-wide zero `Log.` calls), encrypted at rest, `allowBackup=false` | `SecureStore.kt`, manifest |
| Good | Capture always carries an ongoing, non-dismissible notification and self-stops 45 s after capture confirmations stop | `AudioAssistanceService.kt:117,348-367` |

## 6. Native status summary (13 AirDroid categories)

1 fully verified (one-way audio), 2 partially verified (camera, location), 3 partially implemented (downtime, app management, route), 1 blocked (instant block — Device Owner), 6 missing (screen mirroring, notifications, social/image detection, calls/SMS, website restrictions, native geofences).

Nothing is "UI only" at native level because the six missing categories have no native half at all.