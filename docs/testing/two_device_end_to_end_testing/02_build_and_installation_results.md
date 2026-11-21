# 02 — Build and Installation Results

**Date:** 2026-11-21  
**HEAD:** `bbd3c21`  
**Installed build under test:** `1.0.0` (`versionCode 1`), debug, last updated 2026-11-18  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Phase A — static and automated verification

| Check | Command | Result | Label |
|---|---|---|---|
| Dependency resolution | `fvm flutter pub get` | `Got dependencies!`; 28 packages have newer incompatible versions, no resolution error | PASS |
| Analyzer | `fvm flutter analyze` | `No issues found!` (16.2 s) | PASS |
| Flutter tests | `fvm flutter test` | **493 passed, 0 failed** | PASS |
| Deno Edge Function tests | `DENO_DIR=<project>/.tools/deno_dir deno test --allow-read supabase/functions/` | **209 passed, 0 failed** (5 s) | PASS |
| Kotlin JVM tests | `android/gradlew testDebugUnitTest` | **BUILD FAILED** during configuration: `this and base files have different roots: D:\parentcontrol_app\build\... and C:\Users\ASUS\AppData\Local\Pub\Cache\...` | BLOCKED |
| Flutter integration tests | 4 files present | Not run (device/backend orchestration not authorized in this pass) | NOT TESTED |

The Kotlin failure is the previously documented mixed-drive Gradle problem. No source or build file was modified to work around it.

### Build warnings observed

- FVM wrapper kernel-format warning (tooling only).
- Kotlin Gradle Plugin deprecation warnings for plugins including `flutter_webrtc`.
- 28 Flutter dependencies have newer versions incompatible with current constraints.

None of these warnings blocked the analyzer or Flutter test suite.

---

## 2. Phase B/C — application build

**Status: BLOCKED — no APK was produced in this pass.**

The repository’s documented build path is:

```bash
fvm flutter build apk --debug --dart-define-from-file=.tools/live_config.env
```

The execution policy refused:
- `bash scripts/build_debug_apk.sh` (reason: bypasses required FVM / may alter artifacts),
- the direct FVM build (reason: reads a secret-bearing config file and invokes an APK build).

The policy refusal was respected. No workaround, alternate config, plain `flutter` call, or guessed signing configuration was used.

**Consequence:** no Child APK or Parent APK was built, installed or replaced during this test. Both devices continued to run the previously installed debug build.

---

## 3. Installed artifacts inspected

| Property | Child (Realme) | Parent (Pixel emulator) |
|---|---|---|
| Package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| APK path | `/data/app/~~X-TDWl5pf87CcctN7KX8tg==/com.parentcontrol.parent_control-XfIg9n7oL22tuY7HRUbeUQ==/base.apk` | Installed package present |
| Version name | `1.0.0` | `1.0.0` |
| Version code | `1` | `1` |
| Debuggable | Yes | Yes |
| minSdk / targetSdk | 24 / 36 | 24 / 36 |
| First install | 2026-11-17 12:44:28 | 2026-11-13 15:05:52 |
| Last update | 2026-11-18 09:46:33 | 2026-11-18 13:55:28 |
| App data cleared | No | No |
| Reinstalled in this pass | No | No |

**Artifact traceability risk:** HEAD is 2026-11-20, while the installed build is from 2026-11-18. Findings in this report are therefore valid for the installed `1.0.0` build. They must be re-confirmed after a fresh HEAD build.

---

## 4. Manifest and native declarations inspected

Permissions declared in `android/app/src/main/AndroidManifest.xml`:

- `INTERNET`, `ACCESS_NETWORK_STATE`
- `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- `CAMERA`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`
- `FOREGROUND_SERVICE` and the data-sync, location and microphone service types
- `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`
- `PACKAGE_USAGE_STATS`, `QUERY_ALL_PACKAGES`

Services declared:

- `GuardianService` — `dataSync`, `exported=false`
- `LocationTrackingService` — `location`, `exported=false`
- `AudioAssistanceService` — `microphone`, `stopWithTask=false`, `exported=false`
- `ParentControlDeviceAdminReceiver` — device-admin receiver
- `BootReceiver`

No manifest, permission or native service file was modified.

---

## 5. Launch verification of the installed build

| Check | Child | Parent |
|---|---|---|
| `am start` succeeds | PASS | PASS |
| App process alive | PASS (PID 9467) | PASS (PID 3410) |
| Correct role shell | PASS (child tabs) | PASS (parent tabs) |
| Fatal Kotlin/Flutter exception on launch | None observed | None observed |
| Missing native plugin error | None observed | None observed |
| Backend configuration error screen | Not shown | Not shown |

The parent process logged a single “Skipped 139 frames” during launch on the emulator; no crash or ANR followed.

---

## 6. Build/install verdict

**BLOCKED.** The installed build is functional enough for observation, but this pass did **not** satisfy the requirement to build and install fresh Child and Parent artifacts. A fresh-build phase must be run by the owner or in an environment that permits the documented FVM build with the local config.
