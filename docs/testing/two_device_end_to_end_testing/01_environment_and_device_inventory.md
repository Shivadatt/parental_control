# 01 — Environment and Device Inventory

**Test phase:** Two-device real-world end-to-end testing  
**Date:** 2026-11-21 (IST)  
**Repository:** `D:\parentcontrol_app`  
**Branch / HEAD:** `main` / `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f`  
**Working tree:** clean before testing  
**Application:** `com.parentcontrol.parent_control` (single dual-role APK)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Toolchain

| Component | Observed | Status |
|---|---|---|
| FVM | `fvm 4.3.2` | PASS |
| Flutter | `3.44.6` (FVM, revision `ee80f08bbf`) | PASS |
| Dart | `3.12.2` | PASS |
| Android SDK / ADB | Platform-tools present; both devices reachable | PASS |
| Build SDK used by installed app | `minSdk 24`, `targetSdk 36` | PASS (recorded) |

FVM emitted `Can't load Kernel binary: Invalid kernel binary format version (expected 125, found 130)` on the wrapper, but still resolved and ran Flutter 3.44.6 correctly. This is a tool-wrapper warning, not an app failure.

---

## 2. Device inventory

| Item | Child device | Parent device |
|---|---|---|
| Assigned role | CHILD | PARENT |
| Model | Realme RMX2161 | Pixel 9a emulator (`sdk_gphone64_x86_64`) |
| ADB serial | `5HXWRGQ4IFU8WS4T` | `emulator-5554` |
| Android release | **12** | **17** |
| API level | **31** | **37** |
| Expected by brief | Android 12 / API 31 | Android 15 / API 35 |
| Device state | `device` (online) | `device` (online) |
| Account | `ankit1@gmail.com` | `ankit@gmail.com` |
| App role seen | Child shell | Parent shell |
| Package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| Installed version | `1.0.0` (`versionCode 1`), debug | `1.0.0` (`versionCode 1`), debug |
| First install | 2026-11-17 12:44:28 | 2026-11-13 15:05:52 |
| Last update | 2026-11-18 09:46:33 | 2026-11-18 13:55:28 |

**Environment discrepancy (P4):** the emulator reports Android **17 / API 37**, not Android 15 / API 35. It is unambiguously the Pixel 9a emulator and was used as the Parent device. No device state was changed to match the brief.

---

## 3. Role model (from the repository, not assumed)

- There are no product flavors and no separate child package.
- One application package contains both roles.
- Role is selected at `/role-selection` and persisted server-side in `profiles.role`.
- `AuthSessionFlow` routes the signed-in profile to the parent or child shell.
- The installed package already existed on both devices and was already signed in.
- No build flags, alternate entrypoints or alternate packages were invented.

Relevant files:

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- `lib/features/auth/auth_session_flow.dart`
- `lib/features/role_selection/role_selection_page.dart`
- `android/app/build.gradle.kts` (`applicationId = "com.parentcontrol.parent_control"`)

---

## 4. Configuration inspection (secrets not printed)

- `.tools/live_config.env` exists and contains only the two client values used by the repository build script: Supabase URL and publishable/anon key.
- No value was printed, copied or written into a report.
- The installed apps already had a working backend configuration: the parent loaded family data and the child displayed the same family.
- Service-role keys, TURN secrets and cron secrets were not read or used.

---

## 5. Pre-existing app state (before testing)

| Observation | Child | Parent |
|---|---|---|
| Signed in | Yes | Yes |
| Family displayed | `demo` | `demo` |
| Login screen shown | No | No |
| Existing relationship | `ankit1` child member | owner `ankit`, child `ankit1` |
| Local data freshness | “Updated 2 d ago” | device last seen Nov 13, 2026 |

The existing relationship was preserved throughout. No app data, pairing, membership or credentials were reset.

---

## 6. Repository and QA documentation reviewed

- `README.md`
- `pubspec.yaml`, `pubspec.lock`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `docs/verification-report.md`
- `docs/bug-report.md`
- `docs/testing/phase_3_0_*`
- `docs/testing/PHASE_2_2_CROSS_DEVICE_FUNCTIONAL_QA_REPORT.md`
- `docs/testing/TWO_DEVICE_COMPLETE_FUNCTIONAL_AUDIT.md`
- `docs/testing/phase_3_7_*`
- `lib/features/child/controllers/child_shell_controller.dart`
- `android/app/src/main/kotlin/com/parentcontrol/parent_control/`

---

## 7. Execution limitations encountered

The environment’s command policy denied several requested actions. They are recorded as BLOCKED, not converted into passes:

1. Building an APK from `.tools/live_config.env` (policy refused reading secret-bearing config and invoking a build).
2. Installing a new APK (no build artifact produced).
3. Tapping child UI on the physical device (policy refused physical-device interaction).
4. Tapping the parent Settings screen.
5. Opening later parent screens (Location, Screen time, App restrictions) after the policy tightened.
6. Temporarily disabling Wi-Fi for network-failure testing.
7. Reading app shared preferences (correctly denied; would expose tokens).

These denials are environment/tool-policy limitations. They do not invalidate the observations recorded before each denial.

---

## 8. Environment verdict

**PASS for device availability and identity** (with the Android 17/API 37 discrepancy recorded).  
**BLOCKED for fresh build and installation.**  
Testing therefore applies to the **already-installed `1.0.0` debug build last updated 2026-11-18**, not to a freshly built HEAD artifact.
