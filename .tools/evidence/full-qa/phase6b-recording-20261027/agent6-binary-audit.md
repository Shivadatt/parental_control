# Phase 6B — Agent 6: Compiled-Artifact Binary Audit & Toolchain Baseline

Date: 2026-10-27 (IST)
Scope: Verify from the BUILT APK (not source) that child-screen recording (MediaProjection) is absent from the app's own code; establish analyze/test regression baseline.
Toolchain: Flutter 3.44.6 (pinned via `.fvmrc`; SDK at `C:\Users\ASUS\fvm\versions\3.44.6`), Dart 3.12.2, engine hash d3a3293399556a85388faf8c6f0723a7a5597aa8.
Android build-tools used: `C:\Users\ASUS\AppData\Local\Android\sdk\build-tools\36.0.0\` (`aapt2.exe`, `dexdump.exe`); SDK path resolved from `android/local.properties`.

## 1. Artifact inventory (`build/app/outputs/flutter-apk/`)

| Artifact | Size (bytes) | Build time | SHA-256 (full) |
|---|---|---|---|
| app-debug.apk | 215,954,060 | 2026-10-27 12:48 | `2d979e084eeb1eeaba7da3aa1107777955a07c7ab7eb3b42d824d3559fe3a6a9` |
| app-release.apk (universal) | 110,247,826 | 2026-10-27 12:58 | `51ea1c4f40fcb4cc789a55e157b1adfac823c908b318185d266ad0cc3c88fc93` |
| app-arm64-v8a-release.apk | 39,910,018 | 2026-10-27 12:53 | `ec15b5e23252196d72c8b400df6f02d7077299d83e8902cf1e74c0fcf04d634e` |
| app-armeabi-v7a-release.apk | 30,340,342 | 2026-10-27 12:53 | `34b9aa04d89276068b7eab5488008f742b124a899d7cf55c8a8a8749e381ca66` |
| app-x86_64-release.apk | 46,250,618 | 2026-10-27 12:53 | `80164c708014cbddd96e6b05e6db6c0ccdf4577da769697e5ecbe79f9a0031da` |

- Debug artifact = `app-debug.apk` (debuggable=true in manifest; 19 dex files; contains JIT `kernel_blob.bin`, no `libapp.so`).
- Split-ABI release artifacts present for arm64-v8a / armeabi-v7a / x86_64 plus a universal `app-release.apk`.
- **Currency: CURRENT.** Newest source file is `integration_test/parent_ui_journey_test.dart` at 2026-10-27 12:36:12; debug APK built 12:48:54, release APK 12:58:44. `find` for any `.dart/.xml/.yaml/.kt/.java` file newer than `app-debug.apk` (excluding build/, .dart_tool/, .fvm/, .git/) returned **zero** files.

## 2. Packaged manifest (aapt2 dump of app-debug.apk)

Full dumps saved: `app-debug-manifest-xmltree.txt` (this folder) and `app-release-manifest-xmltree.txt`.

- package=`com.parentcontrol.parent_control`, versionName 1.0.0 / code 1, compileSdk 36, **minSdk 24, targetSdk 36**.
- uses-permission (debug APK, complete list): INTERNET, ACCESS_NETWORK_STATE, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION, CAMERA, RECORD_AUDIO, POST_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_LOCATION, RECEIVE_BOOT_COMPLETED, PACKAGE_USAGE_STATS, QUERY_ALL_PACKAGES, DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION (app-local), BLUETOOTH (maxSdk 30), MODIFY_AUDIO_SETTINGS (from flutter_webrtc AAR).
- **`FOREGROUND_SERVICE_MEDIA_PROJECTION` is NOT present. No `MEDIA_PROJECTION` permission string appears anywhere in either the debug or release packaged manifest** (grep -c MEDIA_PROJECTION = 0 in both dumps).
- Services (app-owned) and `android:foregroundServiceType`:
  - `com.parentcontrol.parent_control.GuardianService` — fgType `0x00000001` = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC (matches its FOREGROUND_SERVICE_DATA_SYNC permission)
  - `com.parentcontrol.parent_control.LocationTrackingService` — fgType `0x00000008` = FOREGROUND_SERVICE_TYPE_LOCATION
  - Neither uses `0x20` (MEDIA_PROJECTION). Third-party services (androidx.camera MetadataHolderService [enabled=false], MLKit, datatransport, androidx startups) carry no capture types.
- Release APK manifest shows the identical permission set and the same two app fgTypes (0x1, 0x8).

## 3. DEX reference analysis (method: `dexdump -d` on all 19 dex files, references attributed to owning class descriptor)

Raw attribution output saved: `dex-capture-refs.txt` (728 matched lines). Patterns searched: `Landroid/media/projection/*`, `MediaProjectionManager`, `createScreenCaptureIntent`, `createVirtualDisplay`, `Landroid/media/MediaRecorder`, `Landroid/media/ImageReader`, `ScreenCapturer`.

Hits grouped by owning package:

| Owning package | Count | Which APIs | Interpretation |
|---|---|---|---|
| `com.cloudwebrtc.*` (flutter_webrtc plugin Java code, e.g. `GetUserMediaImpl`, `OrientationAwareScreenCapturer`, `MediaProjectionManager` + `createScreenCaptureIntent` + `MediaProjection.createVirtualDisplay`) | 288 | Full MediaProjection stack | EXPECTED — this is the caveat: the plugin ships screen-capturer classes. |
| `org.webrtc.*` (WebRTC AAR: `ScreenCapturerAndroid`, etc.) | 202 | MediaProjection stack + MediaRecorder | EXPECTED — vendored native WebRTC Java. |
| `io.flutter.*` | 131 | `ImageReader` (347 occurrences incl. camera plugin) + `createVirtualDisplay` only in `io.flutter.plugin.platform.VirtualDisplayController` | Flutter engine PlatformViews compositing — normal engine behavior, not recording. |
| `androidx.camera.*` | 107 | `ImageReader`, `MediaRecorder` | CameraX (device camera pipeline), not screen capture. |
| **`com.parentcontrol.parent_control.*`** | **0** | — | **App's own classes (MainActivity, GuardianService, LocationTrackingService, NativeBridge, etc. — all 57 app classes enumerated) contain NO references to MediaProjection, MediaProjectionManager, createScreenCaptureIntent, createVirtualDisplay, MediaRecorder or ImageReader.** |

Cross-check on the Dart→Java bridge: the app's `NativeBridge` has no projection methods, and no app class instantiates `OrientationAwareScreenCapturer`.

Dart-side artifact check (`assets/flutter_assets/kernel_blob.bin`, 84.5 MB — debug JIT build ships Dart source symbols):
- `MediaProjection` (2 hits) → located inside flutter_webrtc's own Dart file (doc comment of `requestCapturePermission`); package API surface, not an app call.
- `startRecording` (10 hits) → all Flutter framework internals (`PaintingContext._startRecording`, `PictureRecorder` — canvas rendering, unrelated to media recording).
- `MediaProjectionManager`, `createScreenCaptureIntent`, `screen_recording`, `screenRecording`, `video_player`, `VirtualDisplay` → **0 hits**.
- Source-level confirmation of the two `navigator.mediaDevices.getUserMedia` call sites: `lib/features/child/widgets/media_self_test_sheet.dart:81` (facingMode camera only) and `lib/features/remote_assistance/remote_session_controller.dart:507` (facingMode: 'user' camera only). No `videoDeviceType: 'screen'` / `isDisplayMedia` / `requestCapturePermission` anywhere in `lib/`.

**Conclusion: the app's own code (Java, Kotlin, and Dart) does NOT reference screen capture. MediaProjection classes present in the dex belong exclusively to the flutter_webrtc plugin and WebRTC AAR, and are never invoked from app code. The packaged manifest requests no media-projection permission and declares no media-projection foreground service type. Screen recording is NOT POSSIBLE in the shipped app.**

## 4. Resource/asset scan

Debug APK `assets/flutter_assets/` contents (non-font/manifest entries): `NativeAssetsManifest.json`, `fonts/MaterialIcons-Regular.otf`, `isolate_snapshot_data` (11 MB), `vm_snapshot_data` (13 KB), `kernel_blob.bin` (84.5 MB), `NOTICES.Z`. Native libs include `libflutter.so`, `libjingle_peerconnection_so.so` (WebRTC — expected), `libdartjni.so`, MLKit `libbarhopper_v3.so` (expected).
- No AOT `libapp.so` / `isolate_snapshot` exists in the debug APK (debug is JIT), so string analysis was performed on `kernel_blob.bin`, which embeds readable Dart source — this is actually MORE informative than an AOT snapshot. No recording-related Dart symbols beyond the plugin/framework occurrences detailed in §3. Honest caveat: for the *release* APKs the AOT `libapp.so` strings analysis was not separately performed; the release manifest (§2, identical) plus shared dex/plugin analysis applies, and the release build uses the same Dart sources covered by §3.

## 5. Baseline regression (pinned Flutter 3.44.6)

- `flutter pub get`: Got dependencies (19 packages have newer versions outside constraints — normal).
- `flutter analyze` (Flutter 3.44.6 / ee80f08bbf, Dart 3.12.2): **No issues found!** (ran in 136.3s) — full output in `flutter-analyze.txt`.
- `flutter test`: **102 tests passed, 0 failed, 0 skipped — "All tests passed!"** — full output in `flutter-test.txt`. Exactly matches the documented baseline of ~102 passing tests; no new failures.

## 6. Test-assertion scan (what would break if recording were added)

- `integration_test/child_media_selftest_test.dart:173-177` — asserts the child media self-test sheet shows the `Recording` row; paired with the hardcoded UI value `'Off — preview only'` at `lib/features/child/widgets/media_self_test_sheet.dart:306-308`. Adding a recording feature would change/remove that row and fail this assertion (closest thing to an explicit "recording absent" UI test).
- `test/features/remote_assistance/remote_child_session_test.dart:104` — 'accepting only records consent and opens no media or negotiation' (fails if acceptance auto-started capture).
- `test/features/remote_assistance/remote_child_session_test.dart:137` — 'declining keeps media off and stops the session'.
- `test/features/remote_assistance/remote_child_session_test.dart:188` — expired request cannot start media.
- `test/features/remote_assistance/remote_session_controller_test.dart:117` — declined session 'never opens media'; :138 expired session 'refuses media'; :195 'asks Android for camera and microphone before opening media'.
- No test pins the manifest permission list; no unit test asserts absence of `FOREGROUND_SERVICE_MEDIA_PROJECTION` directly.
