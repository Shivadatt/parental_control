# Stage 2 — Device Verification Report

**Date:** 2026-10-28
**Project:** `D:\parentcontrol_app`
**Outcome:** **BLOCKED — no test in the T/N/Q matrix was executed.** The authorized APK contains no Supabase compile-time configuration, so the app cannot connect, sign in, or create a session. Nothing below should be read as a device pass.

---

## 1. Authorized artifact and verification

| Item | Value |
|---|---|
| Path | `build/app/outputs/flutter-apk/app-debug.apk` |
| Size | 239,532,180 bytes |
| SHA-256 (local) | `ec2141a02f1637670764cfba8b5cd37d0f9fdbce6ff65f49271527efd7c78db1` |
| Package | `com.parentcontrol.parent_control` |
| versionCode / versionName | 4010 / 1.0.0 |
| Build toolchain | FVM Flutter 3.44.6, Dart 3.12.2 |
| Debuggable | yes |
| compileSdk | 36 |

Local hash, package and version matched the authorization before installation.

## 2. Devices and installed state

| Device | Model / OS | Serial | Installed versionCode | Installed APK SHA-256 | Install time |
|---|---|---|---|---|---|
| Parent emulator | sdk_gphone64_x86_64 / Android 17 (API 37) | `emulator-5554` | 4010 | `ec2141a0…` (matches authorized) | 15:39:17 |
| Child phone | realme RMX2161 / Android 12 (API 31) | `5HXWRGQ4IFU8WS4T` | 4010 | `ec2141a0…` (matches authorized) | 15:40:00 |

Both serials matched the authorized targets. The installed `base.apk` was hashed **on-device** (`sha256sum` via adb), not inferred from the version code.

**Pre-existing state found before installation:** both devices already reported versionCode 4010 installed at 15:25:31 (child) and 15:31:25 (emulator), but with a **different** APK hash, `73369c46be2bece687877f268cbeb325e1c4b6d0a088561ebcbedaa7d9f22b87` (239,533,047 bytes). That build was produced outside this project's toolchain, continuing the same external-interference pattern seen earlier with builds 4007 and 4008. It was replaced by the authorized artifact via `adb install -r` (no uninstall, no data wipe). It is not recoverable from this project's outputs.

**Install events:** the emulator dropped offline during its first streamed install and later reconnected; the child became `unauthorized` after an adb server restart and re-authorized. Both recovered without data loss, and the final on-device hashes prove the authorized build is what is installed.

## 3. Environment baseline after install

| Check | Emulator (API 37) | Child (API 31) |
|---|---|---|
| `RECORD_AUDIO` | granted (`USER_SET`) | granted, **`ONE_TIME`** |
| `POST_NOTIFICATIONS` | granted (`USER_SET`) | not applicable pre-API 33 |
| `FOREGROUND_SERVICE_MICROPHONE` | granted | permission does not exist pre-API 34 |
| `AudioAssistanceService` running | none | none |
| App process / screen | MainActivity focused | MainActivity focused |

The child's one-time microphone grant is live right now; the T9 path (auto-revoke) would have been directly testable had a session been possible.

## 4. Blocker

Both apps start on the "Connect the backend" screen:

- `SUPABASE_URL` — **Not set**
- `SUPABASE_ANON_KEY` — **Not set**
- Error: *"The backend configuration was rejected. SUPABASE_URL is not set. Fix the --dart-define values and restart the app."*

Proof that this is a build-time omission, not a device/network issue:

- The APK's Dart kernel (`assets/flutter_assets/kernel_blob.bin`, 81,079,952 bytes) contains **zero** occurrences of the configured Supabase URL and **zero** occurrences of the configured anon key. The values exist locally in `.tools/live_config.env` (keys present: `SUPABASE_URL`, `SUPABASE_ANON_KEY`), but were not passed to the build.
- The documented build command in `docs/release-build.md` is `flutter build apk ... --dart-define-from-file=.tools/live_config.env`; build 4010 was produced without that flag.

Without a backend connection there is no authentication, no family link, no session request, no WebRTC signaling and therefore no microphone path to exercise. Running the matrix against this artifact would produce fabricated results, so it was stopped before T1.

Evidence: `.tools/evidence/stage2-20261028/emulator-5554_unlock.png`, `.tools/evidence/stage2-20261028/5HXWRGQ4IFU8WS4T_home.png`.

## 5. Test matrix — results

All entries are **NOT TESTED**. None may be reported as pass or fail.

| ID | Test | Status | Reason |
|---|---|---|---|
| T1 | Child joins; mic FGS starts; notification visible with Stop | NOT TESTED | no backend/session |
| T2 | HOME during active session; capture continues | NOT TESTED | no session |
| T3 | Screen lock during session; capture continues | NOT TESTED | no session |
| T4 | Child Back ends session server-side | NOT TESTED | no session |
| T5 | Child Stop ends both sides and stops capture | NOT TESTED | no session |
| T6 | Parent End stops child capture | NOT TESTED | no session |
| T7 | Network loss/restoration recovers audio | NOT TESTED | no session |
| T8 | Permission revoked mid-session stops capture | NOT TESTED | no session |
| T9 | One-time grant behaviour | NOT TESTED | no session (grant is `ONE_TIME` now) |
| T10 | Task removal / recents swipe behaviour | NOT TESTED | no session |
| T11 | Session expiry and 30-minute behaviour | NOT TESTED | no session |
| N1 | TURN-only relay path | NOT TESTED / BLOCKED | no session; TURN also not configured |
| N2 | Wi-Fi ↔ cellular handover | NOT TESTED | no session |
| N3 | Sustained packet loss | NOT TESTED | no session |
| Q1 | RTP stats: parent receive-only, no parent `[REC]` | NOT TESTED | no session |
| Q2 | 15-minute soak, stability, battery | NOT TESTED | no session |

No test tone or spoken phrase was played, no audio was captured or recorded, and no claim about audibility is made. No force-stop or permission-revocation test was run because there was no capture to terminate.

## 6. Safety and scope compliance

- No uninstall, `pm clear`, data wipe, factory reset, or app-data deletion.
- No Supabase CLI, migrations, deployments, secret rotation, TURN provisioning, or hosted configuration change.
- No source/config/git writes: HEAD remains `b3f1e20`, zero commits; no reset, clean, revert or stash.
- Only device changes: installing the authorized APK on the two authorized serials, waking/unlocking screens, and launching the app.
- No authentication tokens, TURN credentials, keys, or personal data were printed; the configured values were only tested for presence/absence, never displayed.

## 7. Remaining blockers and resume conditions

1. **Blocking:** build 4010 was compiled without `.tools/live_config.env`. The artifact identity is fixed by the authorization, so it cannot be corrected without a new build and a new hash authorization.
2. **Blocking:** TURN remains unconfigured in the hosted environment (`turn_configured: false`); N1/relay verification needs a separate TURN authorization.
3. **Not blocking:** the parent emulator renders and captures correctly once woken/unlocked (earlier black capture was a locked screen, not a display fault).
4. **Not verified:** hosted Supabase deployment freshness and secret presence (Dashboard not accessed).

### Exact resume procedure

```bash
# 1. Rebuild the same source with the documented configuration
fvm flutter build apk --debug --build-name=1.0.0 --build-number=4011 \
  --dart-define-from-file=.tools/live_config.env

# 2. Record size + SHA-256, obtain authorization for the new hash

# 3. Install on the two authorized serials (never uninstall)
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 5HXWRGQ4IFU8WS4T install -r build/app/outputs/flutter-apk/app-debug.apk

# 4. Verify on-device identity
adb -s <serial> shell sha256sum $(adb -s <serial> shell pm path com.parentcontrol.parent_control | sed 's/package://')
```

After a verified install, the T1–T11 / N1–N3 / Q1–Q2 matrix can run under the previously approved test plan. TURN items stay blocked until separately authorized.

## 8. Summary

- Authorized artifact verified and installed on both authorized devices; on-device hashes match `ec2141a0…`.
- The build is functionally unusable for testing because it lacks Supabase compile-time configuration.
- **Zero matrix tests executed.** All are NOT TESTED/BLOCKED; no device claim is made for background audio, notification, reconnect, or termination behavior.
- Next action requires an explicit decision on rebuilding with `.tools/live_config.env` (new hash) and, separately, TURN provisioning authorization.
