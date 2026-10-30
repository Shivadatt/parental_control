# Agent 1 — Android native layer: child screen RECORDING audit

Date: 2026-10-27 · Scope: read-only audit of `D:\parentcontrol_app` Android native layer.
Question: is child-screen recording (Android screen capture) implemented in the native layer?

## VERDICT: **NOT IMPLEMENTED**

Zero lines of app-owned native code perform screen capture. No `MediaProjection`,
`VirtualDisplay`, `MediaRecorder`, `MediaCodec`, `ImageReader`, capture permission, or
`mediaProjection` foreground-service type exists anywhere in `android/` (source or merged
manifests). `flutter_webrtc` internally contains MediaProjection classes, but the app never
invokes that path (see §Risk).

## Evidence table

| # | Item | Result |
|---|---|---|
| 1 | MediaProjection / MediaProjectionManager / createScreenCaptureIntent | **absent** — `Grep` over `D:\parentcontrol_app\android` for `MediaProjection\|createScreenCaptureIntent` → "No files found" |
| 2 | VirtualDisplay / createVirtualDisplay | **absent** — same search, 0 hits in `android/` |
| 3 | MediaRecorder / MediaCodec / MPEG4Writer | **absent** — 0 hits in `android/` (only `android.media` import in native layer is none) |
| 4 | ImageReader / Surface frame capture | **absent** — 0 hits; no `Surface`/`SurfaceTexture` in app Kotlin |
| 5 | FOREGROUND_SERVICE_MEDIA_PROJECTION / RECORD_VIDEO | **absent** in `android/app/src/main/AndroidManifest.xml:4-26`, `src/debug/AndroidManifest.xml:6`, `src/profile/AndroidManifest.xml:6`, and merged release manifest `build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml:11-68` |
| 6 | Foreground services | Only 2 app services (see below); neither declares `mediaProjection` |
| 7 | Recording-suggesting MethodChannel methods | **absent** — 19 methods in `NativeBridge.kt:67-95`, none capture-related |
| 8 | minSdk / targetSdk / compileSdk | Inherited from Flutter defaults: `android/app/build.gradle.kts:9` (`compileSdk = flutter.compileSdkVersion`), `:22` (`minSdk = flutter.minSdkVersion`), `:23` (`targetSdk = flutter.targetSdkVersion`) → Flutter 3.44.6 `FlutterExtension.kt:23 compileSdk=36`, `:26 minSdk=24`, `:34 targetSdk=36`. AGP 9.0.1 / Kotlin 2.3.20 (`android/settings.gradle.kts:22-23`) |
| 9 | Screen-record classes in any build variant | **absent** — `find build -iname *.class` filtered on `record\|projection\|capture` → 0 results; `src/{main,debug,profile}` contain no Kotlin beyond the 19 listed files; test source is only `src/test/kotlin/.../policy/PolicyEvaluatorTest.kt` |

`android_dpc/` is an **empty directory** (no Gradle project, no manifest, no source).
`.flutter-plugins-dependencies` android plugin list: app_links, connectivity_plus,
flutter_secure_storage, flutter_webrtc, integration_test, jni, jni_flutter, mobile_scanner,
path_provider_android, shared_preferences_android, url_launcher_android — **no**
screen-capture/recording plugin. `pubspec.yaml:43` is the only media dependency (`flutter_webrtc`).

## Full existing native surface

MethodChannel `com.parentcontrol/native` (`NativeBridge.kt:29`), handler `NativeBridge.kt:67-95`:
`getCapabilities`, `getDeviceIdentity`, `getBatteryStatus`, `getInstalledApps`,
`isPackageSuspended`, `applyPolicy`, `getGuardianServiceStatus`, `startGuardianService`,
`stopGuardianService`, `configureBackgroundSync`, `clearBackgroundSync`, `requestDeviceAdmin`,
`openUsageAccessSettings`, `openBackgroundLocationSettings`, `requestPermissions`,
`getLastKnownLocation`, `startLocationTracking`, `stopLocationTracking`, `getDailyUsage`.
Unknown methods → `result.notImplemented()` (`NativeBridge.kt:94`).

EventChannel `com.parentcontrol/native_events` (`NativeBridge.kt:30`, stream handler `:50-58`);
events emitted by `NativeEventBus.kt:22-56`: location fix, service status, command ack. Nothing else.

Declared permissions (`main/AndroidManifest.xml:4-26`): INTERNET, ACCESS_NETWORK_STATE,
ACCESS_COARSE/FINE/BACKGROUND_LOCATION, CAMERA, RECORD_AUDIO, POST_NOTIFICATIONS,
FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_LOCATION,
RECEIVE_BOOT_COMPLETED, PACKAGE_USAGE_STATS, QUERY_ALL_PACKAGES.
`capabilities()` (`NativeBridge.kt:127-147`) reports camera/mic/location/notification booleans only —
no capture/screen flag. `requestPermissions` (`:357-368`) can only ask for camera, microphone,
location, notifications — there is no branch that could request projection consent.

Services in `main/AndroidManifest.xml`:
| Service | foregroundServiceType | line | startForeground call |
|---|---|---|---|
| `.GuardianService` | `dataSync` | 75-78 | `GuardianService.kt:609-615` (`FOREGROUND_SERVICE_TYPE_DATA_SYNC`) |
| `.LocationTrackingService` | `location` | 80-83 | `LocationTrackingService.kt:245-251` (`FOREGROUND_SERVICE_TYPE_LOCATION`) |
| `.ParentControlDeviceAdminReceiver` | (receiver, `BIND_DEVICE_ADMIN`) | 85-95 | — |
| `.BootReceiver` | (receiver) | 97-105 | — |

Reusability: neither service can carry projection today. `GuardianService` is the natural host
candidate (long-lived, notification, `startForeground` already typed), but its type is fixed to
`dataSync`; Android 14+ requires the running foreground service to be typed `mediaProjection`
before `getMediaProjection()`, so a **separate** service is the correct design, not a reuse.

Dart side confirms the same: `lib/data/services/device_admin_service.dart:18-20` binds only those
two channels; `lib/features/remote_assistance/remote_session_controller.dart:498-508` requests
`getUserMedia` with `{audio: echo/noise, video: facingMode user 640x480}` — camera+mic only;
`getDisplayMedia` is never called anywhere in `lib/`.

Docs already state the same conclusion: `docs/verification-report.md:43-44`,
`docs/verification-report.md:428` (item 29 NOT IMPLEMENTED), `docs/bug-report.md:776-780`,
`docs/integrations-setup.md:646-647`. UI copy explicitly disclaims capture:
`lib/features/remote_assistance/remote_assistance_page.dart:70-71`,
`lib/features/remote_assistance/remote_session_page.dart:121`,
`lib/features/settings/settings_body.dart:197`,
`lib/features/child/widgets/media_self_test_sheet.dart:307` ("Recording — Off, preview only").

## Exact native-side changes required to implement recording

New Kotlin (package `com.parentcontrol.parent_control`):
1. `ScreenCaptureBridge.kt` — owns the consent flow: calls
   `activity.getSystemService(MEDIA_PROJECTION_SERVICE)` →
   `MediaProjectionManager.createScreenCaptureIntent()` (on API 34+ prefer
   `MediaProjectionConfig.createForVirtualDisplay(...)` / `createConfigForDefaultDisplay()`),
   launches it via `registerForActivityResult`/`startActivityForResult`, and hands the returned
   `ResultData` exactly once to the service.
2. `ScreenRecordService.kt` — foreground service typed `mediaProjection`; ordering is mandatory
   on API 34+: `startForeground(id, notif, FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)` **before**
   `getMediaProjection(resultCode, data)`, then `createVirtualDisplay(...)`, then
   `MediaRecorder` (Surface) or `MediaCodec`+`ImageReader` frame pipeline; stop via
   `MediaProjection.registerCallback` (revocation) and `VirtualDisplay.release()`.
3. `ScreenRecordingState.kt` (or extend `LiveState.kt`) + emit events through `NativeEventBus`.

Changes to existing files:
4. `MainActivity.kt` — currently only forwards `onRequestPermissionsResult` (`MainActivity.kt:20-27`);
   must add an `ActivityResultRegistry`/`onActivityResult` path for the capture intent, and pass
   `ActivityResultRegistrar` into `NativeBridge` (`MainActivity.kt:13`).
5. `NativeBridge.kt` — add methods, e.g. `getScreenCaptureCapabilities`,
   `requestScreenCaptureConsent`, `startScreenRecording`, `stopScreenRecording`,
   `getScreenRecordingStatus`, plus a `screenRecordingActive` key in `capabilities()`
   (`NativeBridge.kt:67-95`, `:127-147`). Recording consent is NOT a runtime permission, so do
   not extend `requestPermissions` (`:348-383`) for it.
6. `main/AndroidManifest.xml` — add
   `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>`
   (API 34+; harmless below) and
   `<service android:name=".ScreenRecordService" android:exported="false"
   android:foregroundServiceType="mediaProjection"/>`; optionally
   `<uses-feature android:name="android.hardware.display" android:required="false"/>`.
   `RECORD_VIDEO` is not a real runtime permission and is not needed for MediaProjection.
7. Gradle — **no new dependency required** (platform APIs). `minSdk 24` already supports
   `VirtualDisplay` (API 21) and `ImageReader`; API-34-only calls (`MediaProjectionConfig`,
   type-checked `startForeground`) must be `Build.VERSION.SDK_INT`-guarded as the codebase already
   does (`NativeBridge.kt:415-420`, `GuardianService.kt:609-615`). If compileSdk 36 cannot resolve
   an API-37 surface, bump `compileSdk` explicitly in `android/app/build.gradle.kts:9`.
8. Transport/storage (outside native capture but blocking) — no recordings table or Storage bucket
   exists (`supabase/migrations/` = core, functions, rls, service_role_grants, device_recovery only;
   grep for `storage.buckets`/`create bucket` → 0 hits). `DeviceHttpClient.kt` has no media upload path.

### API-31 (realme RMX2161, Android 12) vs API-37 (Pixel 9a emulator)
* **API 31**: consent dialog per `createScreenCaptureIntent()`; the `ResultData` may be reused for a
  second `getMediaProjection()` only while the same session/token is alive — Android 12 does not
  enforce the Android 14 single-use rule. `FOREGROUND_SERVICE_MEDIA_PROJECTION` does not exist at 31,
  but the service must still be started with a `mediaProjection` type on `startForeground`
  (Android 12 requires declaring the type in the manifest). Background-start limits apply: the
  capture intent must be launched from a visible Activity, so the silently-running `GuardianService`
  cannot self-initiate a recording — a parent command can only *arm* it, and the child must bring
  the app to the foreground.
* **API 34/35/36+ (target 36 here)**: (a) consent is **single-use and per-session** — one
  `ResultData` yields exactly one `MediaProjection`; every start of recording re-prompts the system
  dialog naming the app; there is no "always allow" and the projection dies if the service is
  recreated. (b) `FOREGROUND_SERVICE_MEDIA_PROJECTION` must be declared **and** the service
  `android:foregroundServiceType="mediaProjection"`; calling `getMediaProjection()`/
  `createVirtualDisplay()` before `startForeground(..., MEDIA_PROJECTION)` throws
  `IllegalStateException`/`SecurityException`. (c) The app must be in the foreground to request
  consent; Android 15 (API 35) additionally restricts **full-screen intents** for non-privileged
  apps (only allowed with an active `mediaProjection`/`camera`/`phone` FGS, or exemptions) and
  hardens **system-overlay** handling, so any "recording indicator" must be a notification or a
  same-app overlay window, and a consent UI cannot be smuggled in via `SYSTEM_ALERT_WINDOW`.
  (d) `MediaProjectionConfig.createForVirtualDisplay()` (API 34) is the only way to lock
  DPI/resolution and to satisfy the emulator's larger display; it must be SDK-guarded since minSdk is 24.
* The Pixel 9a emulator at API 37 inherits all of the above (target 36 ≥ 34), plus Android 15+ FGS
  start-from-background and full-screen-intent gating — meaning an emulator test of "record silently
  while the child does something else" is not achievable on stock Android at all.

## Risk: WebRTC camera/mic mistaken for recording
`flutter_webrtc-1.6.2+hotfix.4` bundles real MediaProjection code —
`.../cloudwebrtc/webrtc/GetUserMediaImpl.java:15-17`, `:201-214`, `:538-544` and
`OrientationAwareScreenCapturer.java:13-43` — and its Dart API exposes `getDisplayMedia`
(`lib/src/native/mediadevices_impl.dart`). Consequences for this audit:
1. A repo-wide grep for `MediaProjection` hits the pub cache, not the app; it is **not** evidence
   of a native recording feature. The app-side search must be scoped to `android/` + `lib/`.
2. The plugin screen-capture path is **unusable as-is** in this build: the plugin's own manifest
   (`android/src/main/AndroidManifest.xml`) declares no permissions, and the app never declares
   `FOREGROUND_SERVICE_MEDIA_PROJECTION` or a `mediaProjection` service — so calling
   `getDisplayMedia` would show consent and then fail Android 14+ FGS rules with no recorder.
3. `CAMERA` + `RECORD_AUDIO` + the live WebRTC session (`remote_session_controller.dart:498-508`)
   are frequently mis-read as "recording". They are a live, ephemeral camera/mic channel; nothing
   is persisted, and UI text says so explicitly (`media_self_test_sheet.dart:307`).
