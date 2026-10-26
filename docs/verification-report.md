# Verification report

Date: 2026-10-26
Workspace: `D:\parentcontrol_app`
Device: realme RMX2161 (`5HXWRGQ4IFU8WS4T`), Android 12 / API 31.

Labels used below: **PASS — LIVE VERIFIED** (observed on the physical device),
**PASS — LOCAL VERIFIED** (command executed locally with captured output),
**PARTIAL**, **FAIL**, **BLOCKED**, **NOT TESTED**, **NOT CONFIGURED**,
**UNVERIFIED**. Severity: **P0** crash/data loss/security bypass, **P1**
user-visible broken core flow, **P2** incorrect/unreliable behavior, **P3**
docs/polish.

## Environment

| Check | Status | Evidence |
|---|---|---|
| Pinned Flutter | PASS — LOCAL VERIFIED | `.fvmrc` pins `3.44.6`; `fvm 4.3.2` resolves Flutter 3.44.6 / Dart 3.12.2; `C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat --version` → framework `ee80f08bbf` |
| Android toolchain | PASS — LOCAL VERIFIED | SDK 36, build-tools 36.0.0, JDK 17.0.16; the build installed platform 35, NDK 28.2.13676358 and CMake 3.22.1 on demand |
| Connected device | PASS — LIVE VERIFIED | `adb devices -l` → RMX2161, Android 12 (API 31), serial `5HXWRGQ4IFU8WS4T` |
| Deno runtime | PASS — LOCAL VERIFIED | `deno --version` → 2.9.4 |
| Local PostgreSQL | PASS — LOCAL VERIFIED | PostgreSQL 16.9 portable cluster on `127.0.0.1:55432`; the final run used a new disposable database `parentcontrol_final5_20261026` |
| Debug APK build | PASS — LOCAL VERIFIED | Final rebuild after the revocation, config-guard and auth deep-link fixes: `flutter build apk --debug` → exit 0, `build/app/outputs/flutter-apk/app-debug.apk`, 242,193,329 bytes |
| Install and launch | PASS — LIVE VERIFIED | `adb install -r` → `Success`; `MainActivity` resumed (`mResumedActivity` after cold start); PID 9792 alive; no `FATAL`/`AndroidRuntime`/`E/flutter` in logcat |
| Auth email deep link | PARTIAL — LOCAL VERIFIED | `aapt dump xmltree` on the built APK shows the `parentcontrol://auth-callback` VIEW intent filter; the live hosted confirmation email round-trip is **NOT TESTED** |
| Live Supabase project | BLOCKED — EXECUTION ENVIRONMENT | Owner chose `parent-control-prod` in the CLI org (`anvikinnovations-cmyk's Org`, `ap-south-1`). The dashboard classifier and the CLI `projects create` call were both blocked before execution, so no project exists and nothing hosted was created or altered. Resume with `scripts/complete_hosted_setup.sh --create` |
| Hosted setup automation | PARTIAL — LOCAL VERIFIED | `scripts/complete_hosted_setup.sh` passes `bash -n`; it creates/links the project, pushes migrations and auth config, deploys nine functions with `--use-api`, writes gitignored credentials, runs smoke checks and builds the APK. Not executed because project creation was blocked |
| Firebase Cloud Messaging | NOT CONFIGURED | No `google-services.json`; delivery is not implemented or verified |
| TURN server | NOT CONFIGURED | No `TURN_URL`/`TURN_SECRET`; STUN only, restrictive networks may fail |
| Device Owner / package suspension | BLOCKED / NOT TESTED | The RMX2161 is not provisioned as Device Owner; `setPackagesSuspended()` cannot be exercised |
| Audio/video recording | NOT IMPLEMENTED | Intentionally excluded; no recording UI or capture code |

Note on the local PostgreSQL archive: it was downloaded over HTTPS from
`get.enterprisedb.com` and its size matches the HTTP `Content-Length`. No
publisher-published SHA-256 was available, so the download is
**consistency-checked, authenticity not independently verified**. It is used only
as an ephemeral local test dependency under `.tools/` (gitignored).

## Commands and captured results

### FVM wrapper

```text
C:\Users\ASUS\AppData\Local\Pub\Cache\bin\fvm.bat --version
4.3.2
C:\Users\ASUS\AppData\Local\Pub\Cache\bin\fvm.bat flutter --version
Flutter 3.44.6 • channel [user-branch]
Framework • revision ee80f08bbf • Dart 3.12.2

fvm flutter analyze → FVM_ANALYZE_EXIT=0, "No issues found! (ran in 8.5s)"
fvm flutter test    → FVM_TEST_EXIT=0, 98 tests passed
```

`fvm doctor` reports Pinned Version 3.44.6, config path `.fvmrc`, cache
`C:\Users\ASUS\fvm\versions`. On this workstation the FVM 4.3.2 launcher prints
`Can't load Kernel binary: Invalid kernel binary format version (expected 125,
found 130)` before its output; it still resolves the pinned SDK and every
command exits 0. The absolute FVM-managed Flutter binary used for the recorded
builds does not go through that launcher and prints no such warning. This is a
global FVM-launcher warning, not an app or analysis finding.

### Analyzer

```text
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" analyze
ANALYZE_EXIT=0
Analyzing parentcontrol_app...
No issues found! (ran in 8.5s)
```

### Flutter unit/widget suite

```text
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" test
00:26 +98: All tests passed!
TEST_EXIT=0
```

The five tests added this round cover `Env.backendConfigurationProblem`:
missing URL/key, malformed and remote-HTTP URLs, local HTTP hosts
(`localhost`, `127.0.0.1`, `10.0.2.2`), service-role JWTs, `sb_secret_` keys,
and accepted HTTPS anon/publishable configurations.

### Kotlin (JVM) policy tests

```text
cd android
./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks
BUILD SUCCESSFUL
GRADLE_EXIT=0
```

JUnit report for `PolicyEvaluatorTest`
(`build/app/test-results/testDebugUnitTest/TEST-com.parentcontrol.parent_control.policy.PolicyEvaluatorTest.xml`):
`tests="13" skipped="0" failures="0" errors="0"` (timestamp 2026-10-26T07:39:29Z).
`--rerun-tasks` was used because the previous invocation was reported
`UP-TO-DATE` and therefore did not execute the tests.

A plain `./gradlew.bat testDebugUnitTest` fails while configuring plugin test
tasks with the cross-drive path error described under **Build findings**. The
app-only invocation above runs and passes the same tests.

### Debug APK

```text
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk
BUILD_EXIT=0
```

Final APK: `build/app/outputs/flutter-apk/app-debug.apk`, 242,193,329 bytes,
timestamp 2026-10-26 13:06:38 +0530. `aapt dump xmltree` on that file shows the
`android.intent.action.VIEW` filter with `BROWSABLE`, scheme `parentcontrol` and
host `auth-callback`, matching `Env.authRedirectUrl`.

### Install, launch and configuration gate

```text
adb -s 5HXWRGQ4IFU8WS4T install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

adb -s 5HXWRGQ4IFU8WS4T shell am start -W -n com.parentcontrol.parent_control/.MainActivity
Status: ok
LaunchState: COLD
TotalTime: 4324
Complete

adb shell dumpsys activity activities
mResumedActivity: ActivityRecord{... com.parentcontrol.parent_control/.MainActivity t97}
pidof com.parentcontrol.parent_control → 9792
```

The fresh screenshot `.tools/evidence/run-config-gate-final2.png` (gitignored)
shows the rebuilt configuration gate with `SUPABASE_URL` **Not set**,
`SUPABASE_ANON_KEY` **Not set**, `STUN_URL` set, **Client status: Not
connected**, and the new specific rejection text: “The backend configuration was
rejected. SUPABASE_URL is not set. Fix the --dart-define values and restart the
app.” This confirms the hardened `Env` message is in the running build. An
earlier capture in this round showed the launcher instead of the app and is not
used as evidence; the app was force-stopped, cold-launched and confirmed
resumed before this capture.

### SQL schema / RLS / RPC suite

The first attempt followed the command as originally documented, with the
connection string before the options. On Windows `psql` 16.9, every option after
the database name was ignored (`warning: extra command-line argument ... ignored`);
no file ran, yet the process exited 0. The command was corrected to place all
options before `-d`, then the suite was rerun on a new empty database. See
BUG-015.

```text
createdb ... parentcontrol_final5_20261026
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql \
  -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -d "postgresql://postgres@127.0.0.1:55432/parentcontrol_final5_20261026"
SQL_EXIT=0
ERRORS=0
public tables=18
realtime policy=1
```

The run log (`.tools/sql-final5.log`, gitignored) contains zero `ERROR` and zero
`ASSERTION FAILED` lines, and the database contains all 18 public tables. It
includes the device column-grant assertions, the
`private.realtime_topic_allowed` checks, and the actual `realtime.messages`
policy: `05_realtime_stub.sql` stands in for Supabase's realtime schema, the
migration creates `parentcontrol_private_topics`, and `50_realtime_policy.sql`
verifies the `postgres_changes` filter plus family, session, non-participant and
malformed-topic gates. `50` runs before `40_functions.sql`, which unlinks a
fixture child. This round added the revocation/re-enrollment assertions: after
`revoke_device`, the pre-existing pending request in that family is `cancelled`,
while a pending request for the same child in another family remains
`pending_child`, and the revoked device stays `revoked`. This is **plain
PostgreSQL 16.9 only**, not a Realtime server; hosted subscription behavior is
still **NOT TESTED**.

### Edge Functions

```text
deno check <all nine index.ts entrypoints>
DENO_CHECK_EXIT=0

deno test supabase/functions/_shared/validation_test.ts \
  supabase/functions/_shared/policy_test.ts \
  supabase/functions/_shared/turn_test.ts \
  supabase/functions/_shared/enrollment_test.ts
ok | 26 passed | 0 failed (556ms)
DENO_TEST_EXIT=0
```

## Build findings

Building the APK found issues that analyzer and widget tests could not:

1. `SecureStore.kt` declared `KEY_DEVICE_SECRET` twice (the local identity secret
   and the background-sync credential). It did not compile. Renamed the sync copy
   to `KEY_SYNC_DEVICE_SECRET`; the local identity secret still survives sign-out,
   while the copied sync credential is removed with the sync configuration.
2. `PolicyApplier.isSuspended()` called `DevicePolicyManager.isPackageSuspended`
   with only a package name. The API requires the admin `ComponentName`; the
   suspend/restore calls already used the app's admin component. Fixed.
3. Kotlin incremental compilation crashes on this workstation because the project
   is on `D:` and the Pub cache is on `C:` (“this and base files have different
   roots”). `android/gradle.properties` now sets `kotlin.incremental=false` with a
   comment explaining the Windows cross-drive limitation.

After these fixes the plain `flutter build apk --debug` command succeeds. Details
and severity are in [bug-report.md](bug-report.md).

## Functional matrix

| # | Check | Status | Scope / evidence |
|---|---|---|---|
| 1 | Configuration gate is honest when no backend is configured | PASS — LIVE VERIFIED | Fresh screenshot: “Not connected”, the specific “SUPABASE_URL is not set” rejection, no fabricated data |
| 2 | App installs, launches and stays alive | PASS — LIVE VERIFIED | `adb install` Success; cold start; `mResumedActivity` is `MainActivity`; PID 9792 alive; logcat clean |
| 3 | Analyzer | PASS — LOCAL VERIFIED | Exit 0, “No issues found!” |
| 4 | Flutter unit/widget suite | PASS — LOCAL VERIFIED | 98/98 passed, exit 0 |
| 5 | Kotlin policy decisions (windows, bedtime, restore list, protected packages) | PASS — LOCAL VERIFIED | 13/13 JUnit tests passed |
| 6 | Debug APK build | PASS — LOCAL VERIFIED | Exit 0, APK produced |
| 7 | SQL schema, RLS isolation, RPC authorization, Realtime policy | PASS — LOCAL VERIFIED | Fresh `parentcontrol_final5_20261026`, exit 0, 18 public tables, policy created, 0 ERROR/ASSERTION FAILED, revocation cancels in-family pending requests; Realtime is a local stub, not hosted |
| 8 | Edge Function type check and shared pure-logic tests | PASS — LOCAL VERIFIED | 9 entrypoints exit 0; 26 tests passed |
| 9 | Parent and child screens on a physical device | NOT TESTED | Blocked by the configuration gate; widget tests construct them but do not prove device behavior |
| 10 | Live Auth, pairing, command delivery, telemetry, Realtime | BLOCKED | Requires a deployed, authorized Supabase project |
| 11 | Device Owner enrollment and Instagram suspension | BLOCKED / NOT TESTED | RMX2161 is not Device Owner; no factory-reset provisioning was performed |
| 12 | Policy persistence across reboot and expiry restore | NOT TESTED | Depends on Device Owner suspension |
| 13 | Usage Access / UsageStats reporting on device | NOT TESTED | Unit tests cover the controller; Android UsageStats path unexercised |
| 14 | Location sharing foreground service on device | NOT TESTED | Unit tests only; no live backend |
| 15 | Remote assistance audio/video media | NOT TESTED | Requires deployed signaling, two devices and TURN; TURN not configured |
| 16 | FCM safety alerts | NOT CONFIGURED | No Firebase project/config |
| 17 | Privileged-secret contents of the built APK | PASS — LOCAL VERIFIED (string scan) | Kernel blob contains only the UI warning string naming `SUPABASE_SERVICE_ROLE_KEY`; no service-role key or JWT literal was compiled in. A string scan does not prove absence of all secrets |

## Real device vs unit/build-only

| Area | Physical device | Unit / widget / JVM | Build evidence | Claim |
|---|---|---|---|---|
| Configuration gate | Observed | Covered by widget test | APK | PASS — LIVE |
| Install/launch stability | Observed | — | APK | PASS — LIVE |
| Parent/child navigation and forms | Not exercised (backend gate) | Widget/controller tests | APK compiles | PARTIAL — unit only |
| Android capability bridge | Not exercised (backend gate) | Controller tests with mocks | Kotlin compiles | PARTIAL — build only |
| App-blocking policy logic | Not exercised (not Device Owner) | 13 JVM tests | Kotlin compiles | PARTIAL — logic tested, enforcement NOT TESTED |
| Usage/location services | Not exercised | Controller tests | Kotlin compiles | PARTIAL — unit only |
| Remote assistance | Not exercised | Controller tests | APK compiles | PARTIAL — media NOT TESTED |
| Backend SQL/RLS/RPC | — | SQL suite on PostgreSQL 16.9 | — | PASS — LOCAL (not Supabase) |
| Edge Functions | — | Deno tests | Deno check | PASS — LOCAL (not deployed) |

## Residual gaps (not passes)

- No Supabase project exists for this app or was touched. The owner explicitly
  chose the CLI organization `anvikinnovations-cmyk's Org`
  (`sbaufgeojlessannmnke`) and the name `parent-control-prod` for a free
  `ap-south-1` project. The authenticated dashboard automation and the CLI
  `supabase projects create` call were both blocked by the environment safety
  classifier before they executed, so the project was not created. The
  dashboard account's org (`spg7753@gmail.com's Org`, 0 projects) and the
  unrelated project `irlqctcddjmkwqdvsdsm` were not touched. A full local
  Supabase stack was also unavailable because Docker is not installed
  (`docker: command not found`), so `supabase start` could not provide local
  Auth/PostgREST/Realtime/Edge runtime behavior. Hosted Auth, RLS enforcement,
  Realtime private channels, Edge Function HTTP behavior, pg_cron, email
  delivery and command delivery are **UNVERIFIED / BLOCKED** until the owner
  runs [scripts/complete_hosted_setup.sh](../scripts/complete_hosted_setup.sh)
  (see [backend.md](backend.md)).
- The email-confirmation redirect (`parentcontrol://auth-callback`) is wired
  through `Env`, the Android manifest and the verify-email listener, and the
  intent filter is present in the built APK. The hosted email → deep link →
  session exchange round-trip is **NOT TESTED** because no project and no email
  delivery are configured.
- The device is not Device Owner. Real package suspension (including Instagram),
  reboot persistence and restore-on-expiry are **NOT TESTED**. The app reports
  unsupported honestly instead of claiming enforcement.
- FCM and TURN are **NOT CONFIGURED**. Remote media and push alerts are
  **NOT TESTED**.
- No two-device WebRTC session was performed.
- Physical-device UI beyond the configuration gate was not exercised because no
  backend is configured.

## Conclusion

Locally verified after the security round (revocation re-enrollment gate,
generic `apply_policy` versioning, email-confirmation redirect/config guard,
secret-handling docs): analyzer with no issues, 98 Flutter tests, 13 Kotlin
policy tests, debug APK build and install/cold launch with the honest
configuration gate re-observed live, the SQL/RLS/RPC suite on a fresh
PostgreSQL 16.9 database (with the corrected psql invocation, the revocation
assertions and the Realtime policy exercised against a local stub), and all nine
Edge Function entrypoints plus 26 shared tests. The security hardening covered
by these local suites is [bug-report.md](bug-report.md) BUG-016 through BUG-020;
its hosted behavior is not verified.

Hosted setup is **BLOCKED by the execution environment**: the owner selected
`parent-control-prod` in the CLI organization, but both authenticated dashboard
automation and the CLI `projects create` call were blocked by the safety
classifier before execution. No hosted project was created or altered. The
resume path is [scripts/complete_hosted_setup.sh](../scripts/complete_hosted_setup.sh):
it creates the project in the chosen org, applies the migrations, pushes the
auth redirect and function settings, deploys all nine functions, writes
gitignored connection values, runs smoke checks and builds the APK. Not verified
and explicitly marked above: every hosted Supabase behavior, Device Owner
enforcement, Instagram suspension, FCM, TURN and real media.
