# AGENT B — Automated Suite Audit (two-device functional audit, Agent B)

Auditor: Agent B (automated-test + build-verification lane)
Date: 2026-11-13 (local run, Git Bash on Windows)
Repo: `D:\parentcontrol_app`
Git HEAD: `5a39747bfaadc2ff79d010db97c7a154f5584f56` ("fix and audit prompt", 2026-11-06 15:12:50 +0530), branch `main`
Working tree at audit time: clean except ` M .idea/caches/deviceStreaming.xml` and untracked `docs/testing/` — **no source file was modified by this agent**.
SDK used: `/c/Users/ASUS/fvm/versions/3.44.6/bin/flutter` — Flutter 3.44.6 / Dart 3.12.2, matching `.fvmrc` (`{"flutter": "3.44.6"}`). The PATH `flutter`/`dart` (3.38.8 / Dart 3.10.7) were NOT used for `flutter` commands.
Raw logs written by this agent (new files, logs dir is gitignored): `logs/agentb_analyze.log`, `logs/agentb_dart_analyze.log`, `logs/agentb_flutter_test.log`, `logs/agentb_deno.log`, `logs/agentb_kotlin_offline.log`.

Constraint compliance: no `adb`/`fastboot` invoked; no `install*` Gradle task; no `flutter run`; no `flutter build apk`; no device touched; no test weakened, skipped, annotated or rewritten; no migration or Edge Function executed; no secret values printed.

---

## 1. Summary table

| # | SUITE | COMMAND | RESULT | COUNTS | EVIDENCE |
|---|-------|---------|--------|--------|----------|
| 1 | Dependency resolution | `flutter pub get` (3.44.6 SDK) | PASS (exit 0) | "Got dependencies!"; 25 packages have newer versions incompatible with constraints | `logs/…` console; `pubspec.lock` unchanged (not in `git status`) |
| 2 | Dart/Flutter static analysis | `flutter analyze` | PASS (exit 0) | **0 errors / 0 warnings / 0 lints / 0 issues** ("No issues found! (ran in 79.4s)") | `D:\parentcontrol_app\logs\agentb_analyze.log` |
| 2b | Repo Stage-1 analyzer (corroboration) | `dart analyze` (3.44.6 SDK) | PASS (exit 0) | **No issues found!** | `D:\parentcontrol_app\logs\agentb_dart_analyze.log` |
| 3 | Flutter unit + widget tests | `flutter test --reporter expanded` | PASS (exit 0) | **482 passed / 0 failed / 0 skipped / 0 errors**; 59 test files; wall time 01:06 | `D:\parentcontrol_app\logs\agentb_flutter_test.log` (last line: `01:06 +482: All tests passed!`) |
| 4 | Kotlin JVM unit tests | `cd android && ./gradlew :app:testDebugUnitTest --offline` | PASS (exit 0), `BUILD SUCCESSFUL in 2m 38s`, 182 tasks (42 executed, 140 up-to-date) | **7 suites, 57 tests, 0 failures, 0 errors, 0 skipped** | `D:\parentcontrol_app\logs\agentb_kotlin_offline.log`; XML in `D:\parentcontrol_app\build\app\test-results\testDebugUnitTest\` |
| 5 | Backend Deno edge-function tests | `deno test --allow-read supabase/functions/` (deno 2.9.4) | PASS (exit 0) | **181 passed / 0 failed** across 15 test files (2s) | `D:\parentcontrol_app\logs\agentb_deno.log` (last line `ok \| 181 passed \| 0 failed (2s)`) |
| 6 | Dart integration tests | `integration_test/` — NOT EXECUTED (by instruction + env) | N/A — blocked | 4 files, 4 `testWidgets` entrypoints; 0 executed | §5 below |
| 7 | SQL / RLS chain | `supabase/tests/` — INVENTORY ONLY, NOT EXECUTED | N/A — not run | 19 `*.sql` test files + 1 negative-control fixture + 2 race scripts; chain = 33 `-f` files (2 stubs + 14 migrations + 17 tests) | §6 below |
| 8 | Debug APK verification | `sha1sum` + `aapt2 dump badging` + `apkanalyzer manifest print` (no rebuild) | PASS | 243,954,904 bytes; sha1 matches sidecar; applicationId `com.parentcontrol.parent_control`; minSdk 24, targetSdk 36, compileSdk 36, versionName 1.0.0 / versionCode 1 | §7 below |
| 9 | Repo scripts (safe subset) | `bash scripts/check_live_config.sh` | PASS (exit 0) | 5 key checks PASS, RESULT: PASS, no forbidden key present | §8 below |

**Overall: every runnable automated suite is green.** No failures occurred in any suite, therefore there are no failing test names or failure outputs to reproduce — see §9 for the non-fatal warnings that were emitted.

---

## 2. Comparison against the stated baseline

Baseline given by the orchestrator: analyze 0 issues, Dart 482/482, Kotlin 7 suites 0 failures, Deno 181/181, APK 243,954,904 bytes.

| Metric | Baseline | This run | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 issues | 0 issues | MATCH |
| `flutter test` | 482/482 | 482 passed, 0 failed, 0 skipped | MATCH |
| Kotlin | 7 suites, 0 failures | 7 suites, 57 tests, 0 failures | MATCH on suites/failures; see note |
| Deno | 181/181 | 181/181 | MATCH |
| APK size | 243,954,904 B | 243,954,904 B | MATCH (also byte-identical sha1) |

Every headline number reproduced exactly. Two clarifications where the repo's own documentation disagrees with the baseline, stated explicitly rather than silently:

- **Kotlin test count.** The baseline quoted "7 suites"; this run also measured the per-test total: **57 tests** (8 + 7 + 4 + 3 + 4 + 13 + 18). The repo's own CI scripts still document "gradle testDebugUnitTest - 39 tests" (`scripts/local-ci.ps1:9` and `.tools/local_ci.sh:8`) — that header figure is **stale**: `QuotaEvaluatorTest.kt` contributes 18 tests added for T-B-02 after the header was written. This is a documentation defect, not a test defect.
- **Dart test count.** `scripts/local-ci.ps1:7`, `.tools/local_ci.sh:7` and `docs/phase10-local-verification-baseline-report.md:93` all document **408/408**; the current tree yields **482**. Same direction as the Deno note below — documented counts lag the code.
- **Deno count.** `scripts/local-ci.ps1:8` documents "deno test - 150 tests"; `docs/backend.md:701` documents 36/0 but only for the narrower `supabase/functions/_shared/` path. The full `--allow-read supabase/functions/` run is 181, consistent with the baseline. **`docs/backend.md:701` ("36 passed, 0 failed") is stale for the whole-functions command**, though it is scoped and self-corrected by the DOC-01 note at `docs/backend.md:703-707`.

---

## 3. `flutter pub get`

`Resolving dependencies... Downloading packages... Got dependencies!` — exit 0. 25 packages reported newer versions that are incompatible with the repo's constraints (pinned by `pubspec.yaml` `environment: sdk: ^3.12.2`): `app_links_linux 1.0.4`, `clock 1.1.2`, `code_assets 1.2.1`, `crypto 3.0.7`, `cupertino_icons 1.0.9`, `flutter_webrtc 1.6.2+hotfix.4`, `hooks 2.0.2`, `jni 1.1.0`, `matcher 0.12.19`, `material_color_utilities 0.13.0`, `meta 1.18.0`, `mobile_scanner 7.4.2`, `objective_c 9.5.0`, `passkeys_platform_interface 2.10.0`, `petitparser 7.0.2`, `qr 3.0.2`, `record_use 0.6.0`, `shared_preferences_android 2.5.3`, `shared_preferences_foundation 2.5.7`, `stack_trace 1.12.1`, `synchronized 3.5.0`, `test_api 0.7.11`, `vector_math 2.2.0`, `web 1.1.1`, `xml 7.0.1`. `pubspec.lock` did not change (`git status --porcelain` shows it clean), which is expected because the lock file is tracked and the pinned SDK satisfies the constraint.

Note (forward-compat): this confirms the phase-10 finding at `docs/phase10-local-verification-baseline-report.md:130` — the PATH Flutter 3.38.8 cannot resolve this project at all (`requires SDK version ^3.12.2, version solving failed`). Any future baseline must invoke the 3.44.6 SDK directly.

---

## 4. Static analysis — exact counts by severity

Command: `flutter analyze` (whole-repo: `lib/`, `test/`, `integration_test/`, `android_dpc/` Dart if any).

```
Analyzing parentcontrol_app...
No issues found! (ran in 79.4s)
EXIT=0
```

| Severity | Count |
|---|---|
| error | 0 |
| warning | 0 |
| info / lint | 0 |
| total | **0** |

Corroborated independently with the repo's own Stage-1 command `dart analyze` → `No issues found!`, exit 0. (Note `analysis_options.yaml` is active and the suite is genuinely empty, not suppressed.)

---

## 5. `flutter test` — full unit + widget suite

Command: `flutter test --reporter expanded` (3.44.6 SDK).

- **Passed: 482**
- **Failed: 0**
- **Skipped: 0** (grep for `skip`, `~` reporter-marked skips and `@Skip` in the log returned 0 hits)
- **Errors / load failures: 0**
- Final lines verbatim: `01:06 +482: D:/parentcontrol_app/test/features/settings/retention_scope_disclosure_test.dart: (tearDownAll)` then `01:06 +482: All tests passed!`
- Exit code 0. Wall time ~66 s + compile.

Because there were zero failures there is no failure output to include. The log contains no stderr lines at all: every non-`+N` line in the file is the `EXIT=0` trailer, i.e. no uncaught exceptions, no `dart:ui` warnings, no "Test failed after completion" noise.

Coverage of the 482: 59 test files under `D:\parentcontrol_app\test\` —

```
10 test/features/app_restrictions      8 test/features/remote_assistance
 8 test/features/child                  4 test/features/settings
 4 test/features/devices                3 test/features/safe_zones
 3 test/features/dashboard              2 test/features/screen_time
 2 test/features/pairing                2 test/features/family
 2 test/features/auth                   2 test/data
 2 test/core (+1 test/core/config)      1 test/features/safety_alerts
 1 test/features/role_selection         1 test/features/parent_shell
 1 test/features/location               1 test/features/audit_logs
 1 test/widget_test.dart
```

---

## 6. Kotlin JVM unit tests (`:app:testDebugUnitTest`)

Command, from `D:\parentcontrol_app\android`: `./gradlew :app:testDebugUnitTest --offline`.
**`--offline` succeeded** (exit 0), so no non-offline retry was needed. No `install*`, `assemble*` or device task was requested or executed.

Gradle 9.1.0, AGP per `android/` config, `BUILD SUCCESSFUL in 2m 38s`, `182 actionable tasks: 42 executed, 140 up-to-date`.

| Suite (`build/app/test-results/testDebugUnitTest/`) | tests | failures | errors | skipped |
|---|---|---|---|---|
| `com.parentcontrol.parent_control.AudioAssistanceRecreationTest` | 8 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.AudioAssistanceStartGateTest` | 4 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.EnforcementModeTest` | 4 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.policy.PolicyEvaluatorTest` | 13 | 0 | 0 | 0 |
| `com.parentcontrol.parent_control.policy.QuotaEvaluatorTest` | 18 | 0 | 0 | 0 |
| **TOTAL — 7 suites** | **57** | **0** | **0** | **0** |

Sources audited: `android/app/src/test/kotlin/com/parentcontrol/parent_control/` — `AudioAssistanceRecreationTest.kt`, `AudioAssistanceSessionWatchdogTest.kt`, `AudioAssistanceStartGateTest.kt`, `AudioAssistanceStopIdempotenceTest.kt`, `EnforcementModeTest.kt`, `policy/PolicyEvaluatorTest.kt`, `policy/QuotaEvaluatorTest.kt`. No `androidTest/` instrumentation sources were run (they require a device).

Side-effect check after the gradle run: `build/app/outputs/flutter-apk/app-debug.apk` re-hashed to the same `10dace9c8f625032a99a618601831b2fa83798a8` and the same 243,954,904 bytes, so `cleanMergeDebugAssets` / `:app:*Debug*` tasks performed by the test graph did **not** disturb the artifact the orchestrator is installing from.

---

## 7. Backend Deno tests

Flags were taken from the repo's own scripts, not guessed: `scripts/local-ci.ps1:208` runs `deno test --allow-read supabase/functions/`, and `.tools/local_ci.sh:7` documents the same command. `docs/backend.md:700-707` explains the `--allow-read` requirement (DOC-01): `_shared/error_mapping_test.ts` reads handler sources off disk, which Deno denies by default.

Command: `deno test --allow-read supabase/functions/` — deno 2.9.4 / V8 15.0.245.2 / TypeScript 6.0.3. Result: `ok | 181 passed | 0 failed (2s)`, exit 0. No Deno warnings, no npm/`node:` resolution noise, no unstable-API warnings in the log.

Per-file breakdown (15 files, sum = 181):

| Test file | tests |
|---|---|
| `supabase/functions/device-command/enforcement_test.ts` | 42 |
| `supabase/functions/device-command/handler_test.ts` | 24 |
| `supabase/functions/_shared/validation_test.ts` | 17 |
| `supabase/functions/account/scope_test.ts` | 17 |
| `supabase/functions/_shared/error_mapping_test.ts` | 13 |
| `supabase/functions/remote-session/guard_test.ts` | 11 |
| `supabase/functions/_shared/policy_test.ts` | 8 |
| `supabase/functions/_shared/turn_test.ts` | 8 |
| `supabase/functions/family-admin/delete_zone_atomicity_test.ts` | 8 |
| `supabase/functions/remote-session/lifecycle_test.ts` | 8 |
| `supabase/functions/account/validation_test.ts` | 7 |
| `supabase/functions/account/retention_test.ts` | 6 |
| `supabase/functions/handler_wiring_test.ts` | 5 |
| `supabase/functions/family-admin/authorization_test.ts` | 4 |
| `supabase/functions/_shared/enrollment_test.ts` | 3 |
| **TOTAL** | **181** |

These Deno suites are pure-logic tests (dependency-injected fakes); they did not contact the hosted Supabase project. `supabase/functions/{auth-bootstrap,pairing,device-register,device-policy,device-telemetry,family-admin,remote-session,cron,account}` entrypoints were exercised only where they have colocated `_test.ts` files; the `deno check` type-check gate documented at `docs/backend.md:689-698` was not re-run (it is not part of any repo script's stages).

---

## 8. Dart integration tests — inventory and executability

`D:\parentcontrol_app\integration_test\` contains 4 files, all real device-driven journeys using `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`. `integration_test` is a declared dev-dependency (`pubspec.yaml:52-53`, `sdk: flutter`).

| File | Shape | Can it run here? Why / why not |
|---|---|---|
| `device_capabilities_test.dart` (3,504 B) | 1 `testWidgets`, "Usage Access and location report on this phone"; header documents `flutter test integration_test -d <serial> --dart-define-from-file=.tools/ui_journey.json` | **NO.** Needs (a) a device serial via `-d`, which is forbidden for this agent because the orchestrator owns `emulator-5554` and `5HXWRGQ4IFU8WS4T`; (b) `--dart-define-from-file=.tools/ui_journey.json` (present but gitignored); (c) grant-only permissions (Usage Access, background location) that only exist on a provisioned device. |
| `child_signin_test.dart` (7,909 B) | 1 `testWidgets`, "linked child signs in and reaches phone enrollment"; reads `String.fromEnvironment('QA_CHILD_EMAIL'/'QA_CHILD_PASSWORD')` | **NO.** Same device requirement, plus live QA credentials via `--dart-define` (in gitignored `.tools/qa_accounts.env`) and a live hosted Supabase backend with the child already linked. Running it would consume/rotate the same child account the orchestrator is testing against. |
| `child_media_selftest_test.dart` (9,348 B) | 1 `testWidgets`, "child camera and microphone self-test opens and stops media" | **NO.** Device-only by construction: it asserts real camera/microphone capture lifecycle and WebRTC media release. On a host `flutter test` VM the platform channels do not exist. It also needs the child signed in (credentials + backend) and would contend for the child's mic — exactly the resource the orchestrator is measuring. |
| `parent_ui_journey_test.dart` (48,954 B, 1,364+ lines) | 1 `testWidgets` with `timeout: const Timeout(Duration(minutes: 30))`; guarded by `skip`-less `expect` preconditions requiring `QA_PARENT_EMAIL`/`QA_PARENT_PASSWORD`; line 1409-1410 fails with "The configuration page is showing. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define."; line 1287 reports `REVOKE SKIPPED: pass --dart-define=QA_REVOKE=true to revoke through the UI.` | **NO.** Requires a parent device, both parent + child QA credentials, the live Supabase URL/anon key compiled in via `--dart-define`, and a 30-minute window. It is also a *mutating* journey (it pairs, revokes, issues commands), so executing it would destroy the orchestrator's seeded state. |

Additional blocking facts, independent of the device ban:
1. `flutter test integration_test/ -d <serial>` drives `flutter run` under the hood; this tooling has **no TTY** ("stdin is not a tty"), so the invocation cannot survive here even against an allowed device. The phase-10 baseline (`docs/phase10-local-verification-baseline-report.md:45-47`) records the same class of environment blocker.
2. None of the four files are runnable headlessly: they are not `WidgetTester`-only tests, so `flutter test` on the host VM (without `-d`) cannot execute them either.
3. **Verdict: 0 of 4 executed, 0 skipped artificially.** They are genuinely blocked in this lane, and are the responsibility of the two-device runtime agents (Agents C/D) and the orchestrator.

---

## 9. SQL / RLS test chain under `supabase/tests/` — inventory (NOT executed)

**Executed: no.** I ran zero `psql`, zero migrations, zero `initdb`, and started/created/dropped no database or cluster. Rationale: hard constraint 3 forbids creating files/state (the runners write a PGDATA cluster under `.tools/pgdata_chain`, bind TCP port 55581, and auto-start a cluster), and item 7's own instruction is inventory. A concurrently-started cluster or port bind is also a real interference risk with the live backend the orchestrator is testing against.

Inventory of `D:\parentcontrol_app\supabase\tests\` — 19 test `.sql` files, 1 negative-control fixture, 3 runners, 1 README:

| File | Role | Executed by |
|---|---|---|
| `00_auth_stub.sql` | LOCAL scaffolding only: creates `anon`/`authenticated`/`service_role`, `auth.users`, `auth.uid()`/`auth.role()`. `README.md:21-22` — "**Never apply this file to a Supabase project**" | chain position 1 (both runners + README `psql -f`) |
| `05_realtime_stub.sql` | Local stand-in for Supabase Realtime policy DDL | chain position 2 |
| `10_schema.sql` | table-count / shape assertions (19 public tables) | chain position 17 |
| `20_fixtures.sql` | family1/child1 fixtures with **fixed UUIDs** → chain is not re-runnable on a dirty DB | chain position 18 |
| `30_rls.sql` | RLS policy matrix | chain position 20 |
| `40_functions.sql` | internal RPC behavior; unlinks a fixture child | chain position 21 |
| `45_device_recovery.sql` | mutates family1/child1 → runs **LAST** | chain position 33 |
| `50_realtime_policy.sql` | realtime policy; ordered before `40_functions.sql` | chain position 19 |
| `55_pairing_invite_atomic.sql` | self-contained atomic pairing-invite test | chain position 22 |
| `60_remote_session_concurrency.sql` | advisory-lock concurrency | chain position 23 |
| `61_parent_controlled_lifetime.sql` | | position 24 |
| `62_signaling_consented_session.sql` | | position 25 |
| `63_abandoned_session_sweep.sql` | | position 26 |
| `70_phase1_authorization.sql` | Phase 1 grants/privileges forward state | position 27 |
| `71_phase1_rollback_privileges.sql` | rolls Phase 1 back and re-applies it **inside** the chain; must leave it forward again | position 28 (immediately after 70) |
| `72_retention_sweep.sql` | global retention sweep | position 29 |
| `74_sweep_indexes_and_repeatability.sql` | sweep indexes + repeatability; runs after 72 because both invoke the global sweep | position 30 |
| `75_signaling_replay_index_duplicate_guard.sql` | asserts the `(session_id, sequence)` unique index 71 leaves; re-applies `20261030000200_phase1_authorization.sql` in a fully-rolled-back transaction | position 31 |
| `76_zone_delete_atomic_rpc.sql` | atomic zone-delete; temporarily installs a failing `BEFORE INSERT` trigger on `public.audit_logs` — must never meet `45_device_recovery.sql` | position 32 |
| `fixtures/sql05_lossy_negative.sql` | SQL-05 lossy-RPC **negative control** (expected non-zero exit) | injected only by `--negative` / `-NegativeControl` |

Note: numbering has gaps at `35_`, `46_`–`49_`, `73_`, `77_`+; there is no `73_` file, so `73` is simply unassigned (not a missing file referenced by the chain — every one of the 33 chain entries resolves on disk).

Who executes the chain (3 documented, mutually redundant runners):
1. **`supabase/tests/README.md:31-67`** — the canonical manual 33-`-f` `psql -v ON_ERROR_STOP=1` invocation, "Run from the repository root against an **empty, disposable, local** database". 33 files = 2 stubs + 14 migrations + 17 test `.sql`.
2. **`supabase/tests/run_sql_chain.sh`** (bash, "CHAIN-01") + **`run_sql_chain.ps1`** (PowerShell) — auto-start a disposable cluster (`PGDATA=$REPO_ROOT/.tools/pgdata_chain`, `PG_BIN=.tools/pgsql16/pgsql/bin`, `127.0.0.1:55581` by default), create a fresh disposable DB with a strict name whitelist, never touch non-disposable DBs, never connect to hosted Supabase, support `--negative` / `-NegativeControl` (expects exit 3).
3. **`scripts/local-ci.ps1` Stage 5** (`:256-300+`) and **`.tools/local_ci.sh`** stage 5 — same 33-file list embedded, DB name `ci_disposable_$Timestamp`, using the bundled `.tools/pgsql16/pgsql/bin/{psql,createdb,dropdb}.exe` (verified present).

Two single-purpose race scripts, explicitly **not** part of the `psql -f` chain (`README.md:251`, `:280`) because they build and drop their own database: `run_pairing_invite_race.sh` (two-session advisory lock; last recorded run blocked 3,404 ms and left one live row) and `run_remote_session_race.sh`. Also not executed.

Last recorded evidence of these suites being green (historical, produced by others, **not by this audit**): `.tools/chain_p6chain_20261106_122629.log` ends with `psql:supabase/tests/76_zone_delete_atomic_rpc.sql:773: NOTICE:  ALL ZONE DELETE ATOMIC RPC TESTS PASSED`; `docs/backend.md:710-749` records EXIT=0 / 0 ERROR / 0 ASSERTION FAILED runs on disposable local PostgreSQL 16.9. **No run verifies any Supabase-hosted behavior** (`README.md:16`).

---

## 10. Debug APK verification (no rebuild)

Artifact: `D:\parentcontrol_app\build\app\outputs\flutter-apk\app-debug.apk`

| Check | Value | Verdict |
|---|---|---|
| Size | `243954904` bytes (232.7 MiB) | MATCHES baseline |
| sha1 (actual) | `10dace9c8f625032a99a618601831b2fa83798a8` | |
| sha1 sidecar (`app-debug.apk.sha1`) | `10dace9c8f625032a99a618601831b2fa83798a8` | **IDENTICAL — integrity confirmed** |
| mtime | 2026-11-13 11:23:57 +0530 | pre-dates this audit's gradle run; unchanged by it |
| applicationId (`aapt2 dump badging`, build-tools 36.0.0) | `com.parentcontrol.parent_control` | CONFIRMED |
| versionName / versionCode | `1.0.0` / `1` | |
| minSdkVersion | `24` | |
| targetSdkVersion | `36` (Android 16) | CONFIRMED |
| compileSdk / platformBuildVersion | `36` / `16` | |
| apkanalyzer cross-check (`cmdline-tools/latest/bin/apkanalyzer.bat manifest print`) | `package="com.parentcontrol.parent_control"`, `android:minSdkVersion="24"`, `android:targetSdkVersion="36"`, `android:versionCode="1"`, `android:versionName="1.0.0"`, `platformBuildVersionCode="36"` | **agrees with aapt2** |
| application-label | `Parent Control` | |

Packaged permissions observed in badging (relevant to the enforcement features under test): `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_MICROPHONE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `PACKAGE_USAGE_STATS`, `QUERY_ALL_PACKAGES`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH` (`maxSdkVersion='30'`), plus the Flutter-generated `...DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.

Also present but **not** touched: `app-release.apk` (110,610,854 B) + its `.sha1` sidecar.

No `flutter build`, no `gradlew assemble*`, no `build_debug_apk.sh`/`build_release_apk.sh` was run. The APK was verified read-only and re-verified after the Kotlin suite.

---

## 11. Repo scripts inventory and my run/skip decision

`D:\parentcontrol_app\scripts\` (5 files) + 2 runner scripts in `supabase/tests/` + 1 in `.tools/`.

| Script | Decision | Reasoning |
|---|---|---|
| `check_live_config.sh` | **RUN** | Purely local and read-only. By its own header (`:8-11`) it only emits key *names* and PASS/FAIL verdicts, never values, and never sources the file as shell code. Verified output contains no secret material. Result: `RESULT: PASS`, exit 0 — `SUPABASE_URL` present/non-empty, scheme `https://` PASS, `SUPABASE_ANON_KEY` present/non-empty, forbidden keys (`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_PASSWORD`, `DB_PASSWORD`, `SERVICE_ROLE_KEY`) absent. Config resolved to `.tools/live_config.env`. |
| `build_debug_apk.sh` | **SKIP** | Runs `flutter build apk` → would overwrite `build/app/outputs/flutter-apk/app-debug.apk` while the orchestrator is installing from it. Explicitly forbidden. |
| `build_release_apk.sh` | **SKIP** | Same (builds APKs); also would attempt release signing and needs `android/key.properties`. |
| `complete_hosted_setup.sh` | **SKIP** | Contains `supabase db push --yes` (`:46`), `supabase functions deploy` (`:64`, `:68`), and `adb -s "$SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk` (`:92-95`). Mutates the live project and drives devices — doubly forbidden. |
| `local-ci.ps1` | **SKIP (components run directly instead)** | Its Stages 1–4 are exactly what I ran individually, and its Stage 5 starts a PostgreSQL cluster + creates/drops databases (stateful, creates files, port-bind risk). Running it would duplicate work and add that risk without new evidence. Note it uses the **PATH** `dart`/`flutter`, which per `docs/phase10-local-verification-baseline-report.md:130` cannot even resolve this project — the script is broken as written on this machine. |
| `.tools/local_ci.sh` (gitignored helper, same 5 stages) | **SKIP** | Same Stage 5 objection; additionally `mkdir -p "$LOG_DIR"` writes into `.tools/ci-logs` (creates files). Also PATH-SDK based. |
| `supabase/tests/run_sql_chain.sh` / `.ps1` | **SKIP** | See §9 — starts a disposable cluster on `127.0.0.1:55581`, creates and drops databases, writes a PGDATA tree. Stateful; not read-only. |
| `supabase/tests/run_pairing_invite_race.sh` / `run_remote_session_race.sh` | **SKIP** | Build and drop their own database (two-session advisory-lock races). Stateful. |

---

## 12. Every error, warning and forward-compatibility risk, verbatim

### 12.1 Hard errors
**None.** All four executed suites exited 0. No test failed. No build failed.

### 12.2 flutter_webrtc Kotlin Gradle Plugin warning (the item the orchestrator called out) — verbatim, from `:flutter_webrtc` project configuration

```
> Configure project :flutter_webrtc
w: Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':flutter_webrtc' is no longer required for Kotlin support since AGP 9.0.
Solution:
Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.
```

Forward-compat reading: `flutter_webrtc 1.6.2+hotfix.4` applies the **external** `org.jetbrains.kotlin.android` plugin. AGP 9 no longer needs it, and the repo currently suppresses built-in Kotlin with `android.builtInKotlin=false` + `android.newDsl=false` in `android/gradle.properties`. When those flags are removed (AGP 10 deletes them, see 12.3) `:flutter_webrtc` must be migrated or bumped (`flutter_webrtc 1.6.3` is available per `pub get`). This is the single highest-risk item for the next AGP major upgrade, and `flutter_webrtc` carries the WebRTC/remote-assistance feature surface.

The identical warning fired for **11 projects** (all non-fatal, `w:` level): `:app`, `:app_links`, `:connectivity_plus`, `:flutter_secure_storage`, `:flutter_webrtc`, `:integration_test`, `:jni`, `:jni_flutter`, `:mobile_scanner`, `:shared_preferences_android`, `:url_launcher_android`.

### 12.3 Gradle / AGP deprecations — verbatim

```
WARNING: Unsupported Kotlin plugin version.
The `embedded-kotlin` and `kotlin-dsl` plugins rely on features of Kotlin `2.2.0` that might work differently than in the requested version `2.2.20`.
```

```
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
WARNING: The option setting 'android.newDsl=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
```

```
Deprecated Gradle features were used in this build, making it incompatible with Gradle 10.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/9.1.0/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.
```

### 12.4 Release-signing warning fired during a *debug* task — verbatim

```
WARNING: release build signed with DEBUG key - not shippable. android/key.properties not found (copy android/key.properties.example). 
```

Emitted by `android/`'s own build config while configuring `:app`. This is a deliberate guard, and it is telling the truth: no `android/key.properties` exists on this machine, so any release build would be debug-signed. Relevant to the release-readiness lane, not to the debug APK under test. (`app-release.apk` sitting next to it predates this state — see §10.)

### 12.5 Android SDK layout warning — verbatim

```
Observed package id 'platform-tools' in inconsistent location 'C:\Users\ASUS\AppData\Local\Android\Sdk\platform-tools-2' (Expected 'C:\Users\ASUS\AppData\Local\Android\Sdk\platform-tools')
```

Duplicate/misplaced `platform-tools` directory in the SDK root. Forward risk: SDK-manager integrity checks and any tool that resolves `adb` by the canonical path may pick the wrong copy; a future `sdkmanager` update could refuse or duplicate further.

### 12.6 Kotlin compile warnings — 33 `w:` lines total: 11 plugin-usage deprecations + 12 from this app's Kotlin sources + 9 from Flutter's own Gradle tooling + 1 from `mobile_scanner`

Project source (`android/app/src/main/kotlin/com/parentcontrol/parent_control/`) — 12 lines:
```
w: NativePermissions.kt:38:24 'fun unsafeCheckOpNoThrow(p0: String, p1: Int, p2: String): Int' is deprecated. Deprecated in Java.
w: SecureStore.kt:6:8 'class EncryptedSharedPreferences : Any, SharedPreferences' is deprecated. Deprecated in Java.
w: SecureStore.kt:7:8 'class MasterKey : Any' is deprecated. Deprecated in Java.
w: SecureStore.kt:74:25 'class MasterKey : Any' is deprecated. Deprecated in Java.
w: SecureStore.kt:74:35 'constructor(p0: Context): MasterKey.Builder' is deprecated. Deprecated in Java.
w: SecureStore.kt:75:27 'class MasterKey : Any' is deprecated. Deprecated in Java.
w: SecureStore.kt:75:37 'enum class KeyScheme : Enum<MasterKey.KeyScheme!>' is deprecated. Deprecated in Java.
w: SecureStore.kt:77:17 'class EncryptedSharedPreferences : Any, SharedPreferences' is deprecated. Deprecated in Java.
w: SecureStore.kt:81:13 'class EncryptedSharedPreferences : Any, SharedPreferences' is deprecated. Deprecated in Java.
w: SecureStore.kt:81:40 'enum class PrefKeyEncryptionScheme : Enum<EncryptedSharedPreferences.PrefKeyEncryptionScheme!>' is deprecated. Deprecated in Java.
w: SecureStore.kt:82:13 'class EncryptedSharedPreferences : Any, SharedPreferences' is deprecated. Deprecated in Java.
w: SecureStore.kt:82:40 'enum class PrefValueEncryptionScheme : Enum<EncryptedSharedPreferences.PrefValueEncryptionScheme!>' is deprecated. Deprecated in Java.
```
(Those 12 lines are the entire project-code warning set — all of it lives in `SecureStore.kt` plus `NativePermissions.kt`.)
Forward-compat: **AndroidX `security-crypto` (`EncryptedSharedPreferences` / `MasterKey`) is deprecated library-wide** and is the storage path for the child's session/token material. It has no replacement inside that artifact; the migration target is Biometric-protected `EncryptedFile`/Keystore-direct or Jetpack Security 1.1+. `unsafeCheckOpNoThrow` likewise needs a `CHECKSelfPermission`-era replacement. These are the two places where a future dependency purge silently breaks child sign-in persistence.

Dependency/tooling warnings (not project code, recorded for completeness):
```
w: mobile_scanner-7.4.2/android/src/main/kotlin/dev/steenbakker/mobile_scanner/MobileScanner.kt:63:5 This annotation is currently applied to the value parameter only, but in the future it will also be applied to property.
```
```
w: file:///C:/Users/ASUS/fvm/versions/3.44.6/packages/flutter_tools/gradle/src/main/kotlin/Deeplink.kt:{13,15,17,19}:5 This annotation is currently applied to the value parameter only, but in the future it will also be applied to property.
- To opt in to applying to both value parameter and property, add '-Xannotation-default-target=param-property' to your compiler arguments.
- To keep applying to the value parameter only, use the '@param:' annotation target.
See https://youtrack.jetbrains.com/issue/KT-73255 for more details.
w: .../flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:13:8 'interface ApkVariant : ...' is deprecated. Deprecated in Java.
w: .../flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:662:69 'interface ApkVariant : ...' is deprecated. Deprecated in Java.
w: .../flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt:12:8 'interface BaseVariantOutput : Any, OutputFile' is deprecated. Deprecated in Java.
w: .../flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt:168:70 Unchecked cast of 'NamedDomainObjectContainer<out BuildType>' to 'NamedDomainObjectContainer<BuildType>'.
w: .../flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt:169:75 Unchecked cast of 'NamedDomainObjectContainer<out BuildType>' to 'NamedDomainObjectContainer<BuildType>'.
```
These originate inside Flutter 3.44.6's own Gradle tooling, i.e. they are **upstream** and will only disappear by moving to a newer Flutter, not by editing this repo.

### 12.7 Benign Gradle notices (not risks)
```
> Task :gradle:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :app:checkKotlinGradlePluginConfigurationErrors SKIPPED
[Incubating] Problems report is available at: file:///D:/parentcontrol_app/build/reports/problems/problems-report.html
Consider enabling configuration cache to speed up this build: https://docs.gradle.org/9.1.0/userguide/configuration_cache_enabling.html
> Task :gradle:compileJava NO-SOURCE / :gradle:compileGroovy NO-SOURCE / :app_links:compileDebugKotlin NO-SOURCE / :connectivity_plus:compileDebugKotlin NO-SOURCE / :app:compileDebugUnitTestJavaWithJavac NO-SOURCE
```

### 12.8 Deno and Dart analysis
Zero warnings. `deno test --allow-read supabase/functions/` produced no `WARN`, no unstable-API notice, no npm-resolution notice. `flutter analyze` and `dart analyze` both emitted only `No issues found!`. `flutter test` emitted no stderr at all.

### 12.9 Documentation-vs-code drift (real audit findings, non-fatal)
1. `scripts/local-ci.ps1:7-9` and `.tools/local_ci.sh:5-8` under-report current suite sizes: 408 Dart (actual **482**), 150 Deno (actual **181**), 39 Kotlin (actual **57**). Anyone trusting the headers will under-verify.
2. `scripts/local-ci.ps1` / `.tools/local_ci.sh` resolve the analyzer and `flutter test` through the **PATH** SDK, which cannot resolve this project at all (Dart `^3.12.2` vs PATH 3.10.7). The repo's own CI wrapper is therefore red-on-this-machine for the wrong reason; the pinned `.fvm/flutter_sdk` / `C:\Users\ASUS\fvm\versions\3.44.6\bin` must be used.
3. `docs/backend.md:701` records "36 passed, 0 failed" for `deno test supabase/functions/_shared/`; the whole-`functions/` figure (181) is not recorded anywhere in the docs, and the DOC-01 note at `:703-707` is a partial patch.
4. `supabase/tests/README.md:5` and `docs/backend.md:710-749` document SQL/RLS verification only against **plain local PostgreSQL**, and `README.md:16` states plainly "No run verifies any Supabase-hosted behavior." Any claim that RLS is proven for the hosted project must cite the live-behavior tests, not this chain.
5. The SQL chain is **not re-runnable** on a dirty database (`20_fixtures.sql` uses fixed UUIDs; `README.md:28-29`), so a fresh disposable DB per run is mandatory — a foot-gun for anyone attempting it manually.

### 12.10 Environment limitations affecting this lane's coverage
- 4 integration tests unexecutable in this tooling (no TTY for the `flutter run` transport + device ban + credential/state contention). Their absence means the automated suites prove **logic**, not **on-device behavior**.
- No `instrumentation` (`androidTest/`) Kotlin tests were run — they require a device.
- `deno check` on the 9 edge-function entrypoints was not re-run this session.
- SQL/RLS chain and both race scripts not executed (see §9).

---

## 13. Bottom line for the orchestrator

Every automated suite that can run without touching a device ran, and all four are green with zero failures and zero skips: **analyze 0 issues (both analyzers) · Dart 482/482 · Kotlin 7 suites / 57 tests / 0 failures · Deno 181/181**. The debug APK is **byte-identical to its own sha1 sidecar** (`10dace9c…3798a8`, 243,954,904 B, `com.parentcontrol.parent_control`, targetSdk 36, minSdk 24) and was still identical after the gradle task graph ran, so your installs are safe. Baseline reproduced exactly on every headline metric; the two deviations I flagged are documentation staleness (Kotlin 39→57 tests, Dart 408→482, Deno 150→181 in `scripts/local-ci.ps1`) and the fact that the repo's own CI wrapper targets a PATH SDK that cannot resolve this project. The 4 Dart integration journeys and the 33-entry SQL/RLS chain remain unexecuted and are structurally blocked in this lane — they belong to the runtime agents. The forward-compat cluster worth owning: `flutter_webrtc` + 10 other plugins on the deprecated external `org.jetbrains.kotlin.android` plugin against AGP's built-in Kotlin (AGP 10 removes the suppressing flags), AndroidX `security-crypto` `EncryptedSharedPreferences`/`MasterKey` deprecated at the child's token-storage path, and the misplaced `platform-tools-2` SDK directory.
