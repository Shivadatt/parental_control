# 02 — Fresh APK Build and Installation

## Build toolchain

- Flutter: 3.44.6 (FVM-pinned, `.fvm/flutter_sdk/bin/flutter`)
- Dart: 3.12.2
- Client configuration: validated `.tools/live_config.env` via
  `--dart-define-from-file` (contents never printed)
- Application ID: `com.parentcontrol.parent_control`
- Version: `1.0.0`, versionCode `1`
- Role model: one APK, role chosen in-app

## Exact build commands

```bash
./.fvm/flutter_sdk/bin/flutter build apk --debug \
  --dart-define-from-file=.tools/live_config.env \
  --target-platform android-arm64

./.fvm/flutter_sdk/bin/flutter build apk --debug \
  --dart-define-from-file=.tools/live_config.env \
  --target-platform android-x64
```

The repository wrapper `scripts/build_debug_apk.sh` was also used successfully for
the first arm64 build. Later builds used the same FVM-pinned SDK directly because
the wrapper's fallback path was refused by the environment.

## Build artifacts

| Target | Built for | SHA-256 | Size/result |
|---|---|---|---|
| arm64 | Realme RMX2161 | `cc621bf6eefc6ee6d8093da11fc6727abe62f3114ba38ef19886ed9c0fc5ff5a` | 173,158,306 bytes (first build); rebuilt and installed |
| x86_64 | Pixel_9a emulator | `7ed729f5d00b146f6840a00e382b459a496887e2789e614d208144741f93ca72` | Built and installed |

Logs:
- `logs/build_debug.log`
- `logs/build_debug_arm64_rebuild.log`
- `logs/build_debug_x64.log`
- `logs/build_debug_arm64_final.log`
- `logs/build_debug_x64_final.log`

## Installation results

| Device | Artifact | Command | Result |
|---|---|---|---|
| Parent emulator | x86_64 | `adb -s emulator-5554 install -r ...` | Success |
| Child RMX2161 | arm64 | `adb -s 5HXWRGQ4IFU8WS4T install -r ...` | Success |

In-place updates were used. Application data and the existing sessions were
preserved on both devices.

### Installation incident

The first installation on the emulator used the arm64 artifact. The app installed
but immediately crashed with “Parent Control keeps stopping”. Root cause was an ABI
mismatch, not an application regression. The emulator was corrected by building and
installing the x86_64 artifact. The arm64 artifact was then installed on the
physical child device.

## Post-install verification

| Item | Parent | Child |
|---|---|---|
| Installed package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| versionName | 1.0.0 | 1.0.0 |
| versionCode | 1 | 1 |
| lastUpdateTime | 2026-11-21 16:05 / corrected x64 install 16:07 | 2026-11-21 16:09:50 |
| Launch | Successful after x64 install | Successful |
| Session preserved | Yes | Yes |
| Fresh artifact hash verified | Yes (`7ed729…`) | Yes (`cc621b…`) |

No previous APK from a download folder, backup, or earlier test run was used.
