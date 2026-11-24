# AGENT3 — Automated Verification Re-Measurement (current working tree)

Independent re-measurement of the automated test and build story. Every number below was produced by a command literally run in this session; nothing is quoted from the baseline without being reproduced. Raw logs retained under `D:\parentcontrol_app\.tools\` (`agent3-flutter-test.log`, `agent3-deno.log`, `agent3-gradle.log`, `agent3-gradle-rerun.log`, `agent3-build-apk.log`).

| Field | Value |
|---|---|
| `git rev-parse HEAD` | `5a39747bfaadc2ff79d010db97c7a154f5584f56` |
| Branch | `main` |
| Working tree | 123 entries in `git status --porcelain` — **all `docs/**` audit artifacts plus `.idea/caches/deviceStreaming.xml`**. Zero dirty files in `lib/ test/ android/ android_dpc/ supabase/ integration_test/ pubspec.yaml pubspec.lock analysis_options.yaml`. |
| Pinned SDK used | `C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter` / `.../bin/dart` |
| Pinned version string | Flutter **3.44.6** • Framework `ee80f08bbf` • Engine `d3a3293399` (rev `83675ed276`) • **Dart 3.12.2** • DevTools 2.57.0 |
| `.fvmrc` | `{ "flutter": "3.44.6" }` |
| Report timestamp | 2026-11-13T12:59:53+05:30 |
| Verdict | **Baseline CONFIRMED — 0 deltas on all five measured signals.** |

**Environment deviation (reported as instructed):** `fvm` is not on PATH, so the pinned SDK was invoked by absolute path. The PATH `flutter`/`dart` resolve to a *different, older* SDK — `D:/software/flutter/flutter_windows_3.38.8-stable/...`, Flutter **3.38.8** / Dart **3.10.7**, 10 months older than the pin. Any command run as bare `flutter`/`dart` would test the wrong toolchain. Everything in §3–§9 below used the 3.44.6 absolute path.

---

## 1. Git state — PASS (measured)

```
git rev-parse HEAD          -> 5a39747bfaadc2ff79d010db97c7a154f5584f56
git rev-parse --abbrev-ref HEAD -> main
git status --porcelain      -> 123 lines (reported only; no action taken)
```

Material point for the whole audit: the dirty set is **documentation and evidence artifacts only**. The code paths under test are byte-identical to `HEAD`, so every number below is attributable to commit `5a39747b`.

## 2. SDK versions — PASS with deviation (see header)

```
C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter --version
Flutter 3.44.6 • channel [user-branch] • unknown source
Framework • revision ee80f08bbf (4 months ago) • 2026-07-08 15:02:06 -0700
Engine • hash d3a3293399556a85388faf8c6f0723a7a5597aa8 (revision 83675ed276) (4 months ago)
Tools • Dart 3.12.2 • DevTools 2.57.0

flutter --version   (PATH)
Flutter 3.38.8 • channel stable • Dart 3.10.7 • DevTools 2.51.1   <- DIFFERENT
```
`which fvm` → not found. `which deno` → `.../WinGet/Links/deno`, **deno 2.9.4** (V8 15.0.245.2, tsc 6.0.3). `which java` → **JDK 17** (`/c/Program Files/Java/jdk-17/bin/java`).

## 3. `flutter pub get` — PASS

```
C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter pub get   -> exit 0
"Got dependencies!"
25 packages have newer versions incompatible with dependency constraints.
```
Resolver succeeded; 25 pinned transitive deps are behind latest (informational, not an error). Notable pins: `flutter_webrtc 1.6.2+hotfix.4`, `mobile_scanner 7.4.2`, `test_api 0.7.11`, `meta 1.18.0`.

## 4. `flutter analyze` — PASS, 0 issues

```
C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter analyze
-> No issues found! (ran in 64.0s)     exit 0
```
Exact counts: **0 errors / 0 warnings / 0 info / 0 issues.** `analysis_options.yaml` is present and active (no blanket suppressions), so the zero is real rather than muted.
Corroborated with the repo's own Stage-1 analyzer: `.../3.44.6/bin/dart analyze` → `No issues found!`, exit 0. Scope covers `lib/`, `test/`, and `integration_test/` — so the integration tests do at least type-check.

## 5. `flutter test` — PASS, 482 / 0 / 0

```
C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter test   -> exit 0
last line: 00:51 +482: All tests passed!
```
- **Passed: 482. Failed: 0. Skipped: 0. Errors: 0.** Verified by scanning the log: zero `-N:` failure markers, zero `[E]` lines, zero `skip` markers.
- **Test files: 59** (`find test -name "*_test.dart"`), matching the baseline's "59 files".
- Coverage spans 21 directories: `test/core/config`, `test/data`, and 19 `test/features/*` modules (app_restrictions, audit_logs, auth, child, dashboard, devices, family, location, pairing, parent_shell, remote_assistance, role_selection, safety_alerts, safe_zones, screen_time, settings) plus `test/widget_test.dart`.
- No failing test names to report verbatim — there were none.
- `integration_test/` is **not** in this run: zero occurrences of the string `integration_test` in the 482-test log. `flutter test` only ingests `test/`.

## 6. Kotlin JVM unit tests — PASS, 7 suites / 57 tests / 0 failures

The first invocation reported `:app:testDebugUnitTest UP-TO-DATE` (182 tasks: 3 executed, 179 up-to-date), i.e. **Gradle had NOT re-executed the tests**. I did not accept that as evidence and forced a genuine re-run:

```
cd android && FLUTTER_ROOT="C:/Users/ASUS/fvm/versions/3.44.6" \
  ./gradlew :app:testDebugUnitTest --rerun --offline
-> BUILD SUCCESSFUL in 20s   (4 executed, 178 up-to-date)   exit 0
```
The `--rerun` pass re-executed `:app:testDebugUnitTest` and rewrote the JUnit XML with timestamp `2026-11-13T07:17:52.898Z` (wall-clock local 12:47:53), confirming execution rather than cache. **Gradle did not need to download anything** — `--offline` succeeded because the dependency cache is already populated.

Per-suite counts, read straight off `build/app/test-results/testDebugUnitTest/*.xml`:

| Suite | tests | failures | errors | skipped |
|---|---|---|---|---|
| `AudioAssistanceRecreationTest` | 8 | 0 | 0 | 0 |
| `AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 | 0 |
| `AudioAssistanceStartGateTest` | 4 | 0 | 0 | 0 |
| `AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 | 0 |
| `EnforcementModeTest` | 4 | 0 | 0 | 0 |
| `policy.PolicyEvaluatorTest` | 13 | 0 | 0 | 0 |
| `policy.QuotaEvaluatorTest` | 18 | 0 | 0 | 0 |
| **7 suites** | **57** | **0** | **0** | **0** |

Toolchain: Gradle wrapper `9.1.0`, AGP `9.0.1`, `org.jetbrains.kotlin.android` `2.3.20`, JVM 17, `jvmTarget JVM_17`, `sourceCompatibility/targetCompatibility VERSION_17`. Test sources are 7 `.kt` files under `android/app/src/test`.

## 7. Deno Edge Function tests — PASS, 181 / 0 across 15 files

```
deno test --allow-read supabase/functions/
-> ok | 181 passed | 0 failed (13s)     exit 0
```
- **181 passed, 0 failed, 0 filtered out.** File count **15** (`_test.ts` convention — there are no `*.test.ts` files in this repo). Per-file breakdown, which sums exactly to 181:

| File | tests |
|---|---|
| `device-command/enforcement_test.ts` | 42 |
| `device-command/handler_test.ts` | 24 |
| `_shared/validation_test.ts` | 17 |
| `account/scope_test.ts` | 17 |
| `_shared/error_mapping_test.ts` | 13 |
| `remote-session/guard_test.ts` | 11 |
| `_shared/policy_test.ts` | 8 |
| `_shared/turn_test.ts` | 8 |
| `family-admin/delete_zone_atomicity_test.ts` | 8 |
| `remote-session/lifecycle_test.ts` | 8 |
| `account/validation_test.ts` | 7 |
| `account/retention_test.ts` | 6 |
| `handler_wiring_test.ts` | 5 |
| `family-admin/authorization_test.ts` | 4 |
| `_shared/enrollment_test.ts` | 3 |

These are pure in-process tests (`--allow-read` only, no network, dependency-injected fakes) — they never contact Supabase, consistent with the phase constraint.

## 8. Integration tests — NOT RUNNABLE by this agent (by constraint), and not run by any command above

```
ls integration_test/
child_media_selftest_test.dart  child_signin_test.dart  device_capabilities_test.dart  parent_ui_journey_test.dart
```
Four journeys:
1. **`parent_ui_journey_test.dart`** (1364+ lines) — the flagship end-to-end journey on ONE physical phone using only public widgets and visible text: cold launch → sign-out normalisation → deliberately-invalid sign-in must show "Could not sign in" → parent sign-in → family creation → detect already-linked active device → (else) child sign-in, link/consent, permanent Child ID, parent pairing request, child approval, device registration, parent verification in list + detail → device detail, App restrictions, honest Device-Owner limitation banners, benign policy save asserted *pending acknowledgement*, optional revoke behind `QA_REVOKE`.
[REDACTED CREDENTIAL ROW]
4. **`device_capabilities_test.dart`** — asserts Usage Access + fine/coarse/background location are granted, with `adb shell appops set` / `adb shell pm grant` remediation strings baked into the failure messages.

**Verdict: NOT RUNNABLE in this session.** Three independent reasons, not one:
- They require `flutter test integration_test/<x> --device-id <serial>` against a live device. The devices `emulator-5554` and `5HXWRGQ4IFU8WS4T` are being driven concurrently by another agent and are explicitly out of bounds for me. Running them would also have mutated app state (sign-out, unlink, revoke), i.e. destructive.
[REDACTED CREDENTIAL ROW]

Neither local CI script mentions `integration_test` at all (zero hits for "integration" in `scripts/local-ci.ps1`), so this gap is structural, not just a constraint of this session.

**Automated coverage NOT exercised by §3–§9:** device/runtime behaviour (all 4 integration journeys); the Stage-5 PostgreSQL SQL regression chain — 33 `.sql` files referenced by `.tools/local_ci.sh`, over 14 `supabase/migrations/` and 25 `supabase/tests/` files (RLS policies, RPC contracts, triggers) — completely untested here because I was barred from Supabase/postgres; Android instrumentation tests (**zero** `src/androidTest` sources exist, so Device Admin / `GuardianService` / `LocationTrackingService` / `AudioAssistanceService` / `BootReceiver` have no automated test at all); release-mode build and signing (`android/key.properties` absent); actual Supabase Edge Function deployment; and all native-Android runtime behaviour.

## 9. Debug APK build — PASS. Byte-identical to baseline.

```
date -Iseconds  -> 2026-11-13T12:48:30+05:30
C:/Users/ASUS/fvm/versions/3.44.6/bin/flutter build apk --debug --dart-define-from-file=.tools/live_config.env
  EXIT=0     ELAPSED=292s wall (Gradle reported 281.4s for assembleDebug)     end 12:53:22
-> √ Built build\app\outputs\flutter-apk\app-debug.apk
```
| Measurement | Value |
|---|---|
| Output path | `D:\parentcontrol_app\build\app\outputs\flutter-apk\app-debug.apk` |
| Exact size (`stat -c %s`) | **243,954,904 bytes** |
| `sha1sum` | `10dace9c8f625032a99a618601831b2fa83798a8` |
| `sha256sum` | `d3780da7e351293a818913a1636cccc58ab5268cd69965222b0d4129f4eca979` |

Both size and full SHA-1 match the recorded baseline (`243,954,904` / `10dace9c…`), so the rebuild is reproducible and confirms §5/§6/§7 were measured against the same artifact the previous audit saw. Only `app-debug.apk` was rewritten by this run; a stale `app-release.apk` (110,610,854 B, Oct 29) remains beside it and is **not** this run's output.

**Single dual-role APK confirmed.** `aapt2 dump badging` (build-tools 36.0.0, read-only file inspection — no adb, no device touched):
```
package: name='com.parentcontrol.parent_control' versionCode='1' versionName='1.0.0'
         platformBuildVersionCode='36' compileSdkVersion='36'
minSdkVersion:'24'   targetSdkVersion:'36'
application-label:'Parent Control'   application-debuggable
densities: '160' '240' '320' '480' '640'
native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'
```
- Exactly one `applicationId` = `com.parentcontrol.parent_control`; **no `productFlavors`/`flavorDimensions` anywhere in `android/`** (grepped, excluding `.gradle/`); one `MainActivity`. Three ABIs inside the one APK ⇒ universal fat APK, not a split.
- Parent and child are **not** separate build artifacts: role is chosen at runtime in Dart (`lib/features/role_selection/`), and the manifest carries both roles' natives in one APK — `MainActivity`, `ParentControlDeviceAdminReceiver`, `BootReceiver`, `GuardianService`, `LocationTrackingService`, `AudioAssistanceService`.

## 10. Static quality signals

Real build-time warnings from `agent3-build-apk.log`, verbatim:
```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_webrtc
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
Note: Some input files use or override a deprecated API.
Note: Some input files use unchecked or unsafe operations.
```
From the Gradle test run:
```
WARNING: Unsupported Kotlin plugin version.
The `embedded-kotlin` and `kotlin-dsl` plugins rely on features of Kotlin `2.2.0`
  that might work differently than in the requested version `2.2.20`.
w: Deprecated 'org.jetbrains.kotlin.android' plugin usage
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
WARNING: The option setting 'android.newDsl=false' is deprecated.
Deprecated Gradle features were used in this build, making it incompatible with Gradle 10.
WARNING: release build signed with DEBUG key - not shippable. android/key.properties not found
```
Assessment: (a) the **KGP/Built-in-Kotlin migration warning is attributed to third-party `flutter_webrtc`**, not app code, and is a *future* breakage — the current pin builds fine; (b) `gradle.properties` carries two Flutter-template flags (`android.builtInKotlin=false`, `android.newDsl=false`) that are themselves deprecated and are the documented remedy path; (c) "source/target value 8 is obsolete" comes from a plugin module, not `:app` (which is set to 17); (d) **the release-signing warning is a shipping blocker and is active today** — `android/key.properties` is absent by design (gitignored, `.example` present), so any `--release` build silently signs with the debug key and is unshippable. Debug-only runs are unaffected.

**SDK levels:** `android/app/build.gradle.kts` does not hard-code them; it defers to `flutter.minSdkVersion` / `flutter.targetSdkVersion` / `flutter.compileSdkVersion`. Those resolve from the 3.44.6 SDK's `FlutterExtension.kt` (`minSdkVersion: Int = 24`, `targetSdkVersion: Int = 36`) and are confirmed empirically in the produced APK as **minSdk 24 / targetSdk 36 / compileSdk 36**. No `minSdk`/`uses-sdk` override exists in `android/app/src/main/AndroidManifest.xml`.

### `local-ci.ps1` documented counts vs. my measured counts — DRIFT CONFIRMED (reported, not fixed)

`scripts/local-ci.ps1:6-10` and `.tools/local_ci.sh:6-8` both carry the same stale header. The scripts hard-code no assertions — they only report these numbers in prose, then run the live commands — so the drift is documentation-only and never fails CI:

| Stage | Script's documented count | Measured (this session) | Delta |
|---|---|---|---|
| 2 — `flutter test` | **408** tests | **482** passed / 0 failed | **+74** |
| 3 — `deno test --allow-read supabase/functions/` | **150** tests | **181** passed / 0 failed | **+31** |
| 4 — `gradle testDebugUnitTest` | **39** tests | **57** tests / 0 failures | **+18** |
| 5 — SQL chain | 33-file chain | **not run** (Supabase barred) | n/a |
| 1 — analyzer | `dart analyze` (no count) | 0 issues (both `dart analyze` and `flutter analyze`) | n/a |

All three headers understate reality; suite growth has outrun the docs. The +18 Kotlin gap is explicable: `QuotaEvaluatorTest.kt` alone contributes 18 tests. Also note Stage 1 of the script runs `dart analyze`, whereas the orchestrator baseline and §4 ran `flutter analyze` — I measured both and both are clean, so this is a naming difference with no numeric consequence.

## 11. Difference table vs. previously-recorded baseline

| Signal | Recorded baseline | Measured this session | Delta | Verdict |
|---|---|---|---|---|
| `flutter analyze` | 0 issues | **0 errors / 0 warnings / 0 info**, "No issues found! (ran in 64.0s)" | **0** | CONFIRMED |
| `flutter test` | 482 passed / 59 files | **482 passed / 0 failed / 0 skipped / 59 files** | **0** | CONFIRMED |
| Kotlin JVM | 7 suites, 57 tests, 0 failures | **7 suites, 57 tests, 0 failures, 0 errors, 0 skipped** | **0** | CONFIRMED |
| Deno | 181 passed / 15 files | **181 passed / 0 failed / 15 files** | **0** | CONFIRMED |
| Debug APK size | 243,954,904 B | **243,954,904 B** | **0 bytes** | CONFIRMED |
| Debug APK SHA-1 | `10dace9c…` | **`10dace9c8f625032a99a618601831b2fa83798a8`** | **identical** | CONFIRMED |
| `flutter pub get` | (not in baseline) | exit 0, "Got dependencies!", 25 deps behind latest | new | PASS |
| Integration tests | (not in baseline) | 4 files, **NOT RUNNABLE here**, self-declared "has NOT been run" | new | GAP |
| `local-ci.ps1` counts | (not in baseline) | 408/150/39 vs measured 482/181/57 | **doc drift** | FAIL (docs) |
| Gradle execution | (not in baseline) | first run was `UP-TO-DATE` cache hit; needed `--rerun` | methodological | note |

**The baseline is fully reproduced — not merely uncontradicted.** Zero regressions found. The two genuine findings are (1) `integration_test/` is a structural coverage hole that no automated command in this pipeline touches, and (2) the repo's own CI headers are stale by +74/+31/+18. One methodological trap worth flagging to future agents: a plain `./gradlew :app:testDebugUnitTest` returns `BUILD SUCCESSFUL` off cache without running a single test, and would have produced a fabricated "pass" had `--rerun` not been forced.

## 12. What automated green does NOT prove

1. **Nothing about the running app.** 482 Dart tests are unit/widget tests on a VM with mocked repositories and fakes. They prove pure functions and widget trees behave as specified in isolation; they prove no RPC was called, no row was written, and no screen was ever displayed on a phone.
2. **Backend is unverified end-to-end.** The 181 Deno tests run with `--allow-read` only, against dependency-injected fakes. They never execute SQL and never touch Supabase. Combined with Stage 5 (33-file SQL chain) being unrun here, **RLS policies, migration correctness, RPC signatures and trigger behaviour have zero executed evidence in this session** — the highest-risk surface in a parental-control app, where a policy bug means one family reading another's child's location.
3. **Zero native Android coverage.** No `src/androidTest` sources exist. Device Admin provisioning, `ParentControlDeviceAdminReceiver`, `GuardianService`, `LocationTrackingService`, `AudioAssistanceService`, `BootReceiver`, usage-stats and overlay permissions are exercised only by hand. The 57 Kotlin tests cover pure policy/enforcement logic (`PolicyEvaluator`, `QuotaEvaluator`, `EnforcementMode`, audio-assistance gating) — deliberately the *testable* parts, not the parts that touch the OS.
4. **Green ≠ enforced.** Tests that assert "pending acknowledgement" or "honest unsupported banner" encode the fact that enforcement was *not* verified on a real device; a passing suite is consistent with enforcement being broken. `BUG-010` shows source comments can contradict a spec while all tests stay green.
[REDACTED CREDENTIAL ROW]
7. **A green suite can coexist with an unshippable artifact.** The debug-key signing warning is silent in every test command above; only a release build surfaces it, and no release build was run.
8. **Absent from scope entirely:** performance, jank, cold-start, background/kill resilience, OS-version matrix (only minSdk 24–36 implied, never run), accessibility, and multi-device concurrency — the actual operating condition of a two-device parental-control product.
