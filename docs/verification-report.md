# Verification report

Date: 2026-10-26 (hosted and device runs); local SQL rerun after the BUG-026 fix
on 2026-10-27; camera/microphone self-test and BUG-027 on 2026-10-27; parent UI
journey, device capabilities (Usage Access + location), BUG-024 hosted recovery
and the APK-size split on 2026-10-27; **Child ID migrations and function
redeployment, Phase 4 live security matrix and the Phase 5 two-device journey on
2026-10-27**; **complete two-device QA (revoked-row and no-policy root cause,
unlink/relink, heartbeat, camera/microphone, remote assistance, background
service) on 2026-10-28**.
Workspace: `D:\parentcontrol_app`
Device: realme RMX2161 (`5HXWRGQ4IFU8WS4T`), Android 12 / API 31.
Hosted project: `hhqgreaoqulmfwfwarhc` (Supabase, Seoul `ap-northeast-2`,
PostgreSQL 17.11, dashboard status Healthy).

Labels used below: **PASS — LIVE VERIFIED** (observed on the hosted project or
the physical device), **PASS — LOCAL VERIFIED** (command executed locally with
captured output), **PARTIAL**, **FAIL**, **BLOCKED**, **NOT TESTED**,
**NOT CONFIGURED**, **UNVERIFIED**. Severity: **P0** crash/data
loss/security bypass, **P1** user-visible broken core flow, **P2**
incorrect/unreliable behavior, **P3** docs/polish.

## Environment

| Check | Status | Evidence |
|---|---|---|
| Pinned Flutter | PASS — LOCAL VERIFIED | `.fvmrc` pins `3.44.6`; `fvm 4.3.2` resolves Flutter 3.44.6 / Dart 3.12.2; framework revision `ee80f08bbf` |
| Android toolchain | PASS — LOCAL VERIFIED | SDK 36, build-tools 36.0.0, JDK 17.0.16; platform 35, NDK 28.2.13676358 and CMake 3.22.1 installed on demand |
| Connected device | PASS — LIVE VERIFIED | `adb devices -l` → RMX2161, Android 12 (API 31), serial `5HXWRGQ4IFU8WS4T` |
| Deno runtime | PASS — LOCAL VERIFIED | `deno --version` → 2.9.4 |
| Local PostgreSQL | PASS — LOCAL VERIFIED | PostgreSQL 16.9 portable cluster on `127.0.0.1:55432`. Earlier run `parentcontrol_final7_20261026` (2026-10-26); re-run 2026-10-27 on `parentcontrol_full_20261027` with five migrations (18 tables); **final re-run 2026-10-27** with **all seven** migrations and every test file (`SQL_EXIT=0`, 0 ERROR/ASSERTION FAILED, 19 tables, Realtime policy present) |
| Hosted project | PASS — LIVE VERIFIED | Dashboard shows `parent-control-prod` (`hhqgreaoqulmfwfwarhc`), Healthy; configuration performed through the authenticated dashboard (SQL Editor, Auth, Edge Functions) |
| Hosted Auth | PASS — LIVE VERIFIED | Four dedicated QA accounts (two families) signed in through `signInWithPassword`; email confirmation ON, signups ON, anonymous sign-ins OFF, redirect allowlist contains `parentcontrol://auth-callback` |
| Hosted schema | PASS — LIVE VERIFIED | Seven migrations applied in order; the last two on 2026-10-27. Verification query: 19 public tables, no table with RLS disabled, `child_contact_ids` service-only with zero policies, `purpose` default `'code'`, four SECURITY DEFINER creation RPCs with `anon`/`authenticated` EXECUTE false |
| Hosted Edge Functions | PASS — LIVE VERIFIED | Nine functions deployed from the dashboard; six with Verify JWT ON (`auth-bootstrap`, `pairing`, `device-register`, `device-policy`, `family-admin`, `remote-session`), three with Verify JWT OFF (`device-command`, `device-telemetry`, `cron`). `pairing` and `auth-bootstrap` were redeployed 2026-10-27 for the Child ID change set (deployed content SHA-256 `427d419d…4307` / `34cf6732…383b`) |
| Hosted private Realtime | PASS — LIVE VERIFIED | Family parent/child and the remote-session participant subscribed; a foreign parent and an anonymous client were rejected |
| Debug APK build | PASS — LOCAL VERIFIED | Final normal rebuild after all fixes: exit 0, `build/app/outputs/flutter-apk/app-debug.apk`, 242,192,247 bytes, SHA-256 `1349075ff632faff9f1ac181cc26fe95a72ee1cc7a139bbaab01d3b2475e3201` |
| Install and launch | PASS — LIVE VERIFIED | The same APK bytes (identical SHA-256) were installed with `adb install -r` → `Success`; cold launch resumed `MainActivity`; PID alive; no `FATAL`/`AndroidRuntime`/`E/flutter` |
| Release APK (normal, hosted config) | PASS — LOCAL VERIFIED | `flutter build apk --release --dart-define-from-file=.tools/live_config.env` → 110,247,706 bytes, SHA-256 `95ae17161dc8dfba34c9c2027ed359587ebff5653228db56a056be1cb7a33bb1` (2026-10-26 build); a 2026-10-27 rebuild is 110,247,826 bytes, SHA-256 `51ea1c4f40fcb4cc789a55e157b1adfac823c908b318185d266ad0cc3c88fc93`. Signed with the debug keystore, not a production key |
| Release APK (split per ABI) | PASS — LOCAL VERIFIED | `flutter build apk --release --split-per-abi` → arm64-v8a 39,910,018 bytes (SHA-256 `ec15b5e2…634e`), armeabi-v7a 30,340,342 (`34b9aa04…ca66`), x86_64 46,250,618 (`80164c70…31da`). Same code, same debug signing; packaging-only change (see [release-build.md](release-build.md)) |
| Release APK (arm64) install and launch | PASS — LIVE VERIFIED | The split arm64-v8a APK was installed with `adb install -r` → `Success`; cold `MainActivity` resumed; PID alive; role-selection screen rendered; screenshot `.tools/evidence/device-release-arm64-launch.png`; no `FATAL`/`AndroidRuntime`/`E/flutter` |
| Release install and launch | PASS — LIVE VERIFIED | `adb install -r` → `Success`; cold `MainActivity` resumed; PID 3860 alive; role-selection screen rendered with hosted config; screenshot `.tools/evidence/device-release-launch.png`; no `FATAL`/`AndroidRuntime`/`E/flutter` |
| Auth email deep link | PARTIAL — LOCAL VERIFIED | `aapt dump xmltree` shows the `parentcontrol://auth-callback` VIEW/BROWSABLE filter; the hosted email → link → session round-trip is **NOT TESTED** because no SMTP provider is configured |
| Firebase Cloud Messaging | NOT CONFIGURED | No Firebase project or `google-services.json`; delivery not implemented or verified |
| TURN server | NOT CONFIGURED | No `TURN_URL`/`TURN_SECRET`; ICE returns STUN-only with `turn_configured:false` |
| Device Owner / package suspension | BLOCKED / NOT TESTED | The RMX2161 is not Device Owner; `setPackagesSuspended()` cannot be exercised |
| Audio/video recording | NOT IMPLEMENTED | Intentionally excluded; no recording UI, `MediaProjection`, `VirtualDisplay`, `ImageReader` or `MediaRecorder` code |
| Child screen recording | NOT IMPLEMENTED | No screen-recording option exists; MediaProjection would capture other apps, which is out of scope for this app-only test |
| Backups / restore | PARTIAL — LOCAL DRILL VERIFIED | A local PostgreSQL dump → restore drill reproduced 18 tables and identical row counts (2026-10-27, [backend.md](backend.md#backup-and-restore-drill)); the hosted project's backup/PITR remains NOT CONFIGURED / UNVERIFIED |

Note on the local PostgreSQL archive: it was downloaded over HTTPS from
`get.enterprisedb.com` and its size matches the HTTP `Content-Length`. No
publisher-published SHA-256 was available, so the download is
**consistency-checked, authenticity not independently verified**. It is used only
as an ephemeral local test dependency under `.tools/` (gitignored).

## Hosted verification runs

All checks below ran against `hhqgreaoqulmfwfwarhc` with publishable-key user
sessions. No service-role key or database password was read, stored or printed.
Result files are written under `.tools/live/results/` (gitignored) with
per-check statuses.

| Suite | Result | Scope |
|---|---|---|
| Phase 1 | **24/24 PASS** | QA sign-in, role bootstrap from server data, family creation, full pairing lifecycle, pairing replay denial, cross-family redeem denial, family isolation, child self-promotion denial, anonymous profile read denial |
| Phase 2 | **42/42 PASS** | Device registration, heartbeat credential check, foreign-parent policy/command denial, policy versioning, command poll/ack, telemetry (usage/location/apps, duplicates, stale data), alert visibility, RLS reads, remote-session consent and authorization, STUN-only ICE, Realtime subscribe/deny, command expiry, device revocation and post-revocation denial |
| Pairing expiry | **PASS** | Expired code redeem returned `400 invalid_code`; no membership was created (`detail: {redeem_status: 400, redeem_code: "invalid_code", membership: null}`) |
| Re-link family A | **6/6 PASS** | Unlink → new code → parent redeem → child sees request → child approves → membership active |
| Re-link family B | **6/6 PASS** | Same lifecycle after the second device test; used because child A had reached the documented code-creation limit |
| Device policy (hosted) | **6/6 PASS** | Benign policy v1 acknowledged and enforced; blocking policy v2 reported `failed` with a Device Owner error; `devices.policy_version` advanced only for the successful ack |
| Unlinked-device denial | **6/6 PASS** | Synthetic device active → heartbeat 200 → parent unlinks child → registration 403 `forbidden` → old credential heartbeat 401 `invalid_device_credentials` → device row `revoked` |
| Revoke response shape (BUG-026) | **4/4 PASS** | `revoke_device` returned 200, `ok:true`, `status:"revoked"`, and no `installation_id`/`secret_hash` keys |

Phase 2 result files include a stricter rerun after the harness bug BUG-025
(`pass`/`record` argument inversion and the `ice_servers` field name). The earlier
`phase2-error.json` is retained as evidence of the failed first attempt; it is
not counted as a pass.

## Commands and captured results

### FVM wrapper and analyzer

```text
C:\Users\ASUS\AppData\Local\Pub\Cache\bin\fvm.bat --version
4.3.2
fvm flutter --version
Flutter 3.44.6 • channel [user-branch]
Framework • revision ee80f08bbf • Dart 3.12.2

fvm flutter analyze → FVM_ANALYZE_EXIT=0, "No issues found! (ran in 7.0s)"
fvm flutter test    → FVM_TEST_EXIT=0, 150 tests passed (final run, 2026-10-27)
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
No issues found! (ran in 7.0s)
```

### Flutter unit/widget suite

```text
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" test
00:10 +150: All tests passed!
TEST_EXIT=0
```

The earlier baseline was 102 tests (2026-10-26); the Child ID change set added
the enrollment, redeem/QR, validator and repository cases for 150. The suite
covers `Env` configuration validation (missing/malformed values, local HTTP
hosts, service-role JWT rejection, `sb_secret_` rejection, accepted HTTPS
publishable keys), auth controllers, pairing, policy, telemetry, remote sessions
(including the BUG-029 early-ICE buffering and media-first teardown cases) and
the UI widgets.

### Kotlin (JVM) policy tests

```text
cd android
./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks
BUILD SUCCESSFUL
GRADLE_EXIT=0
```

JUnit report for `PolicyEvaluatorTest`:
`tests="13" skipped="0" failures="0" errors="0"`. `--rerun-tasks` was used
because the previous invocation was reported `UP-TO-DATE` and did not execute
the tests. A plain `./gradlew.bat testDebugUnitTest` still fails while configuring
plugin test tasks with the cross-drive path error described under **Build
findings**; the app-only invocation runs the same tests.

### Debug APK

```text
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" build apk --debug \
  --dart-define=SUPABASE_URL=<hosted URL> \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
√ Built build\app\outputs\flutter-apk\app-debug.apk
BUILD_EXIT=0
```

Final APK: 242,192,247 bytes; SHA-256
`1349075ff632faff9f1ac181cc26fe95a72ee1cc7a139bbaab01d3b2475e3201`;
package `com.parentcontrol.parent_control`, version 1.0.0. `aapt dump xmltree`
shows the `android.intent.action.VIEW` filter with `BROWSABLE`, scheme
`parentcontrol` and host `auth-callback`, matching `Env.authRedirectUrl`.

The test APK produced by `flutter test integration_test/...` overwrites
`app-debug.apk`; it is roughly 216 MB (215,954,060 bytes on disk after the last
device run). The recorded 242,192,247 bytes / SHA-256 above are from a normal
`flutter build apk --debug`; rerun that command before treating the debug path as
a normal build artifact.

### Release APK

```text
flutter build apk --release --dart-define-from-file=.tools/live_config.env
√ Built build\app\outputs\flutter-apk\app-release.apk (105.1MB)
BUILD_EXIT=0
```

Final release APK: 110,247,706 bytes; SHA-256
`95ae17161dc8dfba34c9c2027ed359587ebff5653228db56a056be1cb7a33bb1` (2026-10-26
build; a 2026-10-27 rebuild is 110,247,826 bytes / `51ea1c4f…fc93`). The last
build, used for the Phase 4/5 deployment checks, is **110,313,302 bytes**,
SHA-256 `d83aa3807e2728b6c031f62d629f32a7082cfca2dc341cfdd18308a9a6e6572c`,
versionCode **4002**; its installed `base.apk` was byte-identical on both the
emulator and the realme (`toybox sha256sum`). The `release` build type still
points at the debug keystore (`android/app/build.gradle.kts`), so this artifact is
for device testing, not store distribution. A `--split-per-abi` variant and its
arm64 install are recorded in [release-build.md](release-build.md) §1.7.

### Android device run

The child-B integration test (`integration_test/child_signin_test.dart`) drove
the real app on the RMX2161:

```text
01:04 +1: All tests passed!
```

Observed in that run:

- QA child sign-in succeeded against hosted Auth.
- Consent screen accepted; device registered; the child shell opened.
- `Background protection` reached `Running` after the retry action, with the
  guardian foreground-service notification visible.
- The guardian service polled commands, sent a heartbeat (server `last_seen`
  advanced), and uploaded the app/usage cycle. Usage Access was denied on this
  phone, so it recorded `Last error | Usage Access is not granted; usage cannot
  be uploaded.` rather than fabricating usage.
- A benign policy (v1, no app blocking) was acknowledged and enforced on the
  device. A blocking policy (v2, `com.cricbuzz.android`) was acknowledged as
  `failed` with `Device Owner provisioning is required to suspend apps on this
  device. No apps were suspended.` — the app reports the truth instead of
  claiming suspension.

The server-side device record was then revoked through the parent API; the
revocation and post-revocation denial checks are part of the Phase 2 results.

### Camera and microphone self-test on device

A second integration test (`integration_test/child_media_selftest_test.dart`)
signed in as the QA child, opened Settings → **Camera and microphone test**, and
exercised the visible, local-only preview. Credentials were passed through
`--dart-define`; no secret was written to the test file.

```text
flutter test integration_test/child_media_selftest_test.dart -d 5HXWRGQ4IFU8WS4T
01:00 +1: All tests passed!   (first run, 1280×720 frames)
00:55 +1: All tests passed!   (second run with screenshot capture)
```

Observed states, read from the on-screen status rows rather than inferred:

| Step | Reported state |
|---|---|
| Open after granting CAMERA/RECORD_AUDIO | `Camera | Main camera live`, `Microphone | Live` |
| Renderer decoded a picture | `Video frames | 1280×720 received` |
| After **Switch camera** | `Camera | Front camera live`, frames still received |
| After **Mute microphone** | `Microphone | Opened, muted for this test` |
| Always | `Recording | Off — preview only` (reworded to `Not available in this app` on 2026-10-27 — BUG-030) |
| After **Stop test** | Sheet closed; camera/mic tracks stopped |

The main-camera picture looked dark because the phone was lying face-up with the
rear camera against a desk; the frame counter and the front-camera image (a real
room, 1280×720) prove that video was decoded and drawn, not just that a track
existed. Screenshots are in `.tools/evidence/device-media-04-main-frames.png`
and `.tools/evidence/device-media-05-front-frames.png`.

This also exercises the BUG-027 fix path: the self-test calls the same
`DeviceAdminService.requestPermissions` bridge that `RemoteSessionController.join`
now calls before `getUserMedia`. A two-device WebRTC media path remains
**NOT TESTED**.

### SQL schema / RLS / RPC suite

The first attempt followed the command as originally documented, with the
connection string before the options. On Windows `psql` 16.9, every option after
the database name was ignored (`warning: extra command-line argument ... ignored`);
no file ran, yet the process exited 0. The command was corrected to place all
options before `-d`, then the suite was rerun on new empty databases. See
BUG-015.

The final run after the BUG-026 RPC change (2026-10-26) used the four migrations
present at that time and the updated Realtime expectations:

```text
createdb parentcontrol_final7_20261026
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql \
  -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -d "postgresql://postgres@127.0.0.1:55432/parentcontrol_final7_20261026"
SQL_EXIT=0
ERR_LINES=0
public tables=18
realtime policy=1
```

**Re-run on 2026-10-27 with all five migrations** (adds
`20260101000400_device_recovery.sql` and `supabase/tests/45_device_recovery.sql`)
on a fresh database `parentcontrol_full_20261027`:

```text
createdb parentcontrol_full_20261027
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql \
  -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/migrations/20260101000400_device_recovery.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -f supabase/tests/45_device_recovery.sql \
  -d "postgresql://postgres@127.0.0.1:55432/parentcontrol_full_20261027"
SQL_EXIT=0
ERR_LINES=0
public tables=18
realtime policy=1
authenticated can execute request_device_recovery = f
```

Log: `.tools/sql-tests-20261027.log` (gitignored).

**Final re-run with all seven migrations** (adds `20260101000500_child_contact_ids.sql`,
`20260101000600_atomic_pairing_invite.sql` and
`supabase/tests/55_pairing_invite_atomic.sql`) on a fresh database:
`SQL_EXIT=0`, 0 ERROR/ASSERTION FAILED lines, 19 public tables, Realtime policy
present. Log: `.tools/sql_rerun_185456.log`. The separate two-session test
`run_pairing_invite_race.sh` then passed with session B blocked **3,404 ms** and
one live request row. Both logs are gitignored.

The runs include the device column-grant assertions,
`private.realtime_topic_allowed`, the topic-only `realtime.messages` policy
(`50_realtime_policy.sql` was updated after BUG-021: the local stub admits every
row once a topic is allowed, because `realtime.topic()` is a fixed setting),
revocation/re-enrollment side effects, and the narrowed `private.revoke_device`
response. The 2026-10-27 run additionally asserts that
`public.request_device_recovery` is service-only and that a recovery unlinks the
child and writes an audit row without a secret field. This is **plain PostgreSQL
16.9 only**, not a Supabase server; hosted Realtime behavior is verified
separately above.

### Permanent Child ID workflow

The permanent Child ID change set (`pairing.get_contact_id`, `pairing.invite`,
`purpose`-scoped pairing tokens, the child **Your Child ID** screen and the
parent Child-ID/code entry) was applied to the production project
`hhqgreaoqulmfwfwarhc` on 2026-10-27 and exercised live with dedicated QA
accounts and the physical child phone. The rows below separate what was proved
locally from what was observed against the deployment. The deployment record,
including file and deployed-content digests, is in
[backend.md](backend.md#production-child-id-deployment-2026-10-27).

Local evidence for this change set:

```text
flutter analyze                            No issues found
flutter test                               All tests passed (150)
deno check <all nine entrypoints>          exit 0
deno test supabase/functions/_shared/      ok | 36 passed | 0 failed
./gradlew :app:testDebugUnitTest            BUILD SUCCESSFUL
psql (seven migrations + all test files)    exit 0, no ERROR, 19 public tables
bash supabase/tests/run_pairing_invite_race.sh   PASS, B blocked 3404 ms, 1 row
```

Migration apply list for that run (seven files, filename order):

```text
psql -v ON_ERROR_STOP=1 \
  -f supabase/tests/00_auth_stub.sql \
  -f supabase/tests/05_realtime_stub.sql \
  -f supabase/migrations/20260101000000_core.sql \
  -f supabase/migrations/20260101000100_functions.sql \
  -f supabase/migrations/20260101000200_rls.sql \
  -f supabase/migrations/20260101000300_service_role_grants.sql \
  -f supabase/migrations/20260101000400_device_recovery.sql \
  -f supabase/migrations/20260101000500_child_contact_ids.sql \
  -f supabase/migrations/20260101000600_atomic_pairing_invite.sql \
  -f supabase/tests/10_schema.sql \
  -f supabase/tests/20_fixtures.sql \
  -f supabase/tests/50_realtime_policy.sql \
  -f supabase/tests/30_rls.sql \
  -f supabase/tests/40_functions.sql \
  -f supabase/tests/55_pairing_invite_atomic.sql \
  -f supabase/tests/45_device_recovery.sql \
  -d "postgresql://postgres@127.0.0.1:55432/<fresh database>"
```

| # | Required check | Status |
|---|---|---|
| 1 | `20260101000500_child_contact_ids.sql` applies additively; `child_contact_ids` exists, `device_pairing_tokens.purpose` defaults to `'code'`, and `device_pairing_tokens_child_purpose_idx` exists | PASS — LIVE VERIFIED (hosted schema query) and PASS — LOCAL VERIFIED |
| 2 | `child_contact_ids` has RLS enabled, zero policies, no `anon`/`authenticated` privilege, and service-role DML only | PASS — LIVE VERIFIED (hosted: `rls_disabled []`, zero policies, anon/auth SELECT false, service INSERT true) and PASS — LOCAL VERIFIED |
| 3 | `get_contact_id` assigns once and returns the identical ID on later calls; a concurrent `23505` loser re-reads the winner's row | PASS — LIVE VERIFIED for assign-once (`PC-94EA…` on repeated calls; `PC-9GYF…` for a second child). The concurrent-loser branch is NOT TESTED live; it is covered by code review and the controller test |
| 4 | `invite` inserts a `pending_child` request plus a `purpose='invite'` token with a 24h TTL, and returns the same payload shape as `redeem` | PASS — LIVE VERIFIED (HTTP response `pending_child`, `created_at`/`expires_at` 24 h apart, same payload shape) and PASS — LOCAL VERIFIED at the RPC layer |
| 5 | `invite` returns the uniform 400 `invalid_code` for an unknown ID, malformed input and a target whose role is not `child` | PASS — LIVE VERIFIED for malformed and unknown IDs (byte-identical body, then 429 after five failures). A target whose role is not `child` is NOT TESTED live |
| 6 | `invite` returns an existing live request instead of duplicating, and 409 `child_already_linked` for a linked child | PASS — LIVE VERIFIED (repeat invite returned the same request id; same-family linked child → 409 `child_already_linked`; other family → uniform 400) |
| 7 | `redeem` auto-detects a Child ID and a legacy 8-character code; both failure paths return the identical message | PASS — LIVE VERIFIED (`get_contact_id` and `invite` by ID; legacy 8-character create/redeem/replay exercised; malformed and unknown inputs returned the same `invalid_code` body) |
| 8 | `create` revokes only `purpose='code'` tokens and cancels only the requests whose tokens it replaced | NOT TESTED live. The SQL suite asserts the scoping; no live token was deliberately left behind to observe the revoke |
| 9 | Quotas hold: 5 failed lookups/parent/10 min (successes excluded), 10 per identifier, 5 live codes/24h, 10 creations/hour, 3 pending invites, 10 invites/24h; 429 carries `details.retry_after_seconds` | PARTIAL — PASS — LIVE VERIFIED for the 5-failures/10-min window and `retry_after_seconds: 600`; the other caps are PASS — LOCAL VERIFIED only |
| 10 | Unlink leaves the Child ID intact and the same ID can start a new request after unlinking | PASS — LIVE VERIFIED (the child showed `PC-94EA…` after the parent removed the family; the same ID started the relink request) |
| 11 | Audit `pairing_invited` records `{child_user_id, via:'child_id'}` and no Child ID value | PASS — LIVE VERIFIED (live `audit_logs` rows: `pairing_invited` with `via: child_id` + UUID; `leaky = 0` across six event types) |
| 12 | Child screen shows **Your Child ID**, linked status, **Copy ID**, **Show QR** and **Check for requests**, with no "Create linking code" action | PASS — LIVE VERIFIED on the RMX2161 (`child_id_loaded.xml`; ID `PC-94EA…`) and PASS — LOCAL VERIFIED in the widget test |
| 13 | Parent screen accepts a Child ID or an 8-character code, scans `…?id=…&v=2` and `…?code=…&v=1`, and always shows **Waiting for child approval** | PARTIAL — PASS — LIVE VERIFIED for Child-ID entry and the **Waiting for child approval** state (`parent_request_sent.xml`); scanning a QR code was NOT TESTED on a device (the page and v=2 payload are covered by widget/unit tests) |

All rows that needed a deployment were repeated against production; the live
matrix is in [Production live checks](#production-live-checks-2026-10-27) and
the device journey in
[Two-device journey](#two-device-journey-phase-5-2026-10-27). Live Child IDs are
truncated (`PC-94EA…`) throughout, because the QA child is still linked and a
live ID can start a pending invite; the full values are preserved in the
gitignored Phase 5 device evidence. The three gaps left open above are named in
[Residual gaps](#residual-gaps-not-passes).

### BUG-033 / BUG-034 hardening (2026-10-27)

Both fixes are deployed to production and were exercised live against
`hhqgreaoqulmfwfwarhc`; the local two-session lock test was also re-run.

| Required check | Status | Evidence |
|---|---|---|
| Concurrent invites cannot create duplicate pending requests | **PASS — LIVE VERIFIED** | Six parallel `invite` calls from one parent returned one unique request id (`e7d60a75-385f-4376-9a5e-662bf0a95032`); DB query `dup_live_pending = 0`, `concurrent_window_rows = 1`. Locally, session B waited **3,404 ms** and the database held one live row; 25 SQL assertions in `55_pairing_invite_atomic.sql` |
| Duplicate prevention is also correct for a pre-expired `pending_child` row | PASS — LOCAL VERIFIED | The same SQL file proves a past-`expires_at` row does not suppress a new invite (the case that ruled out a partial unique index) |
| Identifier hashes are not reversible from a database dump | **PASS — LIVE VERIFIED** (with the deployed secret) | 31 attempts in the run window were keyed 64-hex digests (`bad_hash_shape = 0`); plain SHA-256 matched only four rows, all at or before `13:05:50` UTC, so the HMAC pepper is active. Local `deno test` 36/36 includes the HMAC vector |
| A guardian cannot read a child's name before the child approves | **PASS — LIVE VERIFIED** | Live `invite`/`redeem` payloads and `list_family` returned `Child account (pending approval)`; the parent screen showed the entered identifier `PC94EA…` |
| `child_already_linked` is not an enumeration oracle across families | **PASS — LIVE VERIFIED** | Other-family parent received the uniform `400 invalid_code` (byte-identical to an unknown ID); the child's own family received `409 child_already_linked` |
| Unauthorized callers cannot read child/family data by ID | **PASS — LIVE VERIFIED** (for the invite/get_contact_id surface) | A child role received `403 role_required`; an unauthenticated invite was rejected; cross-family data reads were denied in Phase 1/2; no action returns another account's profile |
| Rate limits and `retry_after_seconds` | **PASS — LIVE VERIFIED** | Five malformed/unknown lookups returned `400 invalid_code`; the sixth returned `429 rate_limited` with `details.retry_after_seconds: 600` |
| Audit records contain no identifier | **PASS — LIVE VERIFIED** | Six pairing/device event types in a 4-hour window: `leaky = 0`; metadata contained only UUIDs and `via: "child_id"` |

Residual: four pre-deployment `pairing_attempts` rows still match a plain
SHA-256 of the identifier. They were not rewritten. The 3-pending-inbox quota is
still checked just outside the advisory lock, so a burst can exceed it by the
number of concurrent callers (BUG-035).

### Production live checks (2026-10-27)

Run against `hhqgreaoqulmfwfwarhc` with dedicated QA accounts. No staging
project was created: the owner directed that the existing production project be
used. "ID alone" tests used only the Child ID, never a token or a device
credential.

| # | Live check | Status | Evidence |
|---|---|---|---|
| 1 | New child receives one stable Child ID | **PASS — LIVE VERIFIED** | `get_contact_id` twice → `PC-94EA…` both times (`stable=YES`); a second child received `PC-9GYF…` |
| 2 | Existing child receives an ID with no duplicate profile | **PASS — LIVE VERIFIED** | The ID was assigned to the existing QA child account; no second account was created or observed |
| 3 | Parent can submit a valid ID | **PASS — LIVE VERIFIED** | Parent form accepted `PC-94EA…`; response showed child `PC94EA…`, family `QA Family A`, status **Waiting for child approval** (`.tools/evidence/phase5/parent_request_sent.xml`) |
| 4 | Child approval is mandatory before any membership exists | **PASS — LIVE VERIFIED** | The child saw the request and had to confirm **Approve**; membership existed only after approval. Unlink/relink repeated the same consent step |
| 5 | Knowing an ID grants no device, camera, microphone or recording access | **PASS — LIVE VERIFIED** (device/membership) / NOT IMPLEMENTED (camera/mic/recording) | The ID created only a `pending_child` request; no device was attached to it, and the realme appeared in the family's device list only after approval **and** device registration. No camera/microphone/recording endpoint accepts an ID, and screen recording does not exist in the app (Phase 6B) |
| 6 | Unknown and malformed IDs return uniform errors | **PASS — LIVE VERIFIED** | Malformed `PC123` and well-formed unknown IDs returned the same `400 invalid_code` body |
| 7 | An unrelated caller cannot enumerate child or family data | **PASS — LIVE VERIFIED** (tested surface) | No list/search action exists; repeated lookups hit the uniform 400 → 429 path; cross-family reads and redeems were denied in Phase 1/2 |
| 8 | Concurrent invites produce no duplicate pending requests | **PASS — LIVE VERIFIED** | Six parallel invites → one request id; DB `dup_live_pending = 0` |
| 9 | Pairing-token replay is rejected | **PASS — LIVE VERIFIED** | Second parent replay → `409 code_unavailable`; same-parent replay → `200` with the identical request id; legacy replay after use → `400 invalid_code` |
| 10 | Unlink revokes the relationship and keeps the same ID | **PASS — LIVE VERIFIED** | Parent family page showed the child as **Removed**; the child screen no longer showed the family; the same `PC-94EA…` remained and started the relink request. Unlinked-device registration/heartbeat denial is also PASS — LIVE VERIFIED from Phase 2 |
| 11 | Rate-limit responses and `retry_after_seconds` | **PASS — LIVE VERIFIED** | `429 rate_limited` with `details.retry_after_seconds: 600` after five failures |
| 12 | Audit records contain expected events and no identifier | **PASS — LIVE VERIFIED** | `pairing_invited`, `pairing_redeemed`, `pairing_approved`, `pairing_cancelled`, `pairing_code_created` and the device event type all `leaky = 0`; `device_recredentialed` appeared after relink |
| 13 | Two-device journey | **PASS — LIVE VERIFIED** | See [Two-device journey](#two-device-journey-phase-5-2026-10-27) |

Logs: `.tools/phase4_run_235716.log`, `.tools/phase4b_run_235916.log`,
`.tools/phase4c_run.log` (gitignored). Screenshots and uiautomator dumps:
`.tools/evidence/phase5/`.

### Two-device journey (Phase 5, 2026-10-27)

Left device: Android emulator running the parent app. Right device: physical
realme RMX2161 (`5HXWRGQ4IFU8WS4T`, Android 12), the child phone. Both devices
ran the same release APK, versionCode 4002, SHA-256
`d83aa3807e2728b6c031f62d629f32a7082cfca2dc341cfdd18308a9a6e6572c`; the realme
was not factory-reset and its user data was not cleared.

| Step | Status | Observed |
|---|---|---|
| Child sign-in / enrollment | PASS — LIVE VERIFIED | Existing QA child signed in on the realme; setup screen showed `PC-94EA…` with **Copy ID**, **Show QR**, **Check for requests** (`.tools/evidence/phase5/child_id_loaded.xml`) |
| Parent enters the ID | PASS — LIVE VERIFIED | Parent typed `PC-94EA…`; response: `QA Family A`, **Waiting for child approval** (`parent_entered_id.xml`, `parent_request_sent.xml`) |
| Child approves | PASS — LIVE VERIFIED | Pending card showed the family and guardian; **Approve** opened a confirmation; after approval the child saw **Family linked** (`child_pending.xml`, `child_approved.xml`) |
| Parent sees the linked device | PASS — LIVE VERIFIED | After the child registered, the parent device list showed `realme RMX2161` (`.tools/evidence/phase5/parent_device_relinked2.xml`). At that capture it showed **Offline / Last seen Never reported** because no heartbeat ran while the child stayed on the setup screen. **Superseded 2026-10-28**: after the second relink the row reports `last_seen` 08:51 and heartbeats every five minutes, while the badge still flips Offline between beats (BUG-038); see [Complete two-device QA](#complete-two-device-qa-2026-10-28) |
| Unlink | PASS — LIVE VERIFIED | Parent removed the child; family page showed **Removed**; child screen returned to the no-family state; Child ID unchanged (`parent_after_unlink.xml`, `child_after_unlink.xml`) |
| Relink | PASS — LIVE VERIFIED | Same ID → new request → child approve → device re-registration. Audit showed `pairing_approved` 19:27:04 and `device_recredentialed` 19:27:17 (`child_relinked.xml`, `restore_child.xml`) |
| Offline handling | PASS — LIVE VERIFIED | With the network off, the child screen showed `You are offline — Linking and registration need a connection. Nothing is sent until this phone is online again.` and a **Retry** action; no request was sent (`child_offline.xml`) |
| Back online | PASS — LIVE VERIFIED | After restoring connectivity and tapping **Retry**, the screen returned to the registered state without a false success (`child_online_again.xml`) |
| Session restoration | PASS — LIVE VERIFIED | Force-stopping and relaunching the child app restored the signed-in, linked state (`restore_child.xml`); the parent app restored its family and devices after relaunch (`restore_parent.xml`) |
| Parent account switching | PASS — LIVE VERIFIED | Parent A → sign out → Parent B (`QA parent B`, `QA Family B`) showed only Family B devices; switching back to A restored Family A and the realme (`parent_signed_out.png`, `parent_signed_in_b.png`, `parent_back_to_a.xml`) |

**Defects found in this journey (P3, open, cosmetic):** the pending card renders
a 24-hour expiry as `expires Just now` (BUG-036), and the child setup screen
keeps a success banner after the family is removed (BUG-037). Both are recorded
in [bug-report.md](bug-report.md).

**Not covered by this journey:** a two-device WebRTC call (one phone only, no
TURN), Device Owner suspension (would require an unauthorized factory reset),
and a camera/microphone test on the parent side. These are not passes.

### Local backup / restore drill

A dump → restore of the local PostgreSQL database was performed on 2026-10-27 to
prove the procedure (the hosted project's backups remain **NOT CONFIGURED /
UNVERIFIED**, see [backend.md](backend.md#backup-and-restore-drill)):

```text
pg_dump -Fc -f .tools/backup_drill/parentcontrol_final7.dump <src>
pg_dump    -f .tools/backup_drill/parentcontrol_final7.sql  <src>
createdb  parentcontrol_restore_drill_20261027
pg_restore -d parentcontrol_restore_drill_20261027 \
  .tools/backup_drill/parentcontrol_final7.dump
```

The restored database has the same 18 public tables and identical row counts to
the source (profiles 7, families 2, devices 6, pairing_requests 5). The local
database holds only fixed-UUID test fixtures, so the dump contains no real user
data and no secret; it lives under `.tools/backup_drill/` (gitignored) and is
never committed.

### Edge Functions

```text
deno check <all nine index.ts entrypoints>
DENO_CHECK_EXIT=0

deno test supabase/functions/_shared/
ok | 36 passed | 0 failed
DENO_TEST_EXIT=0
```

### APK secret scan

The final APK's `assets/flutter_assets/kernel_blob.bin` was scanned for
privileged material:

```text
sb_secret_                   6 occurrences (guard prefix, doc strings, startsWith check)
SUPABASE_SERVICE_ROLE_KEY    2 occurrences (operator guidance text only)
service_role                 7 occurrences (supabase SDK docstrings, guard, identifier pool)
TURN_SECRET                  2 occurrences (operator guidance text only)
CRON_SECRET                  2 occurrences (operator guidance text only)
postgres:// / postgresql://  0
DATABASE_URL                 0
JWT-shaped literals          0
```

All occurrences were inspected in context; none is a credential value. A naive
regex over the kernel string table reported one 67-character
`sb_secret_`-prefixed match, but that span crosses adjacent pooled identifiers
(`sb_secret_`, `service_role`, `isLocalHost`, ...) and is not a key. The hosted
URL and publishable key are compiled in as intended; they are public client
values. The scan does not prove the absence of every possible encoding of a
secret, but no service-role key, database URL/password, TURN secret or cron
secret is present.

The release APK (`lib/*` and `assets/flutter_assets/*`) returned **0** matches
for `sb_secret_`, `SUPABASE_SERVICE_ROLE_KEY`, `postgres://`, `postgresql://`,
`TURN_SECRET` and `CRON_SECRET`.

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
   roots”). `android/gradle.properties` sets `kotlin.incremental=false` with a
   comment explaining the Windows cross-drive limitation.

Details and severity are in [bug-report.md](bug-report.md).

## Functional matrix

| # | Check | Status | Scope / evidence |
|---|---|---|---|
| 1 | Configuration gate rejects missing/privileged client config | PASS — LOCAL VERIFIED | `Env` unit tests; the previous live build showed the honest “not configured” screen before hosted values were supplied |
| 2 | App installs, launches and stays alive | PASS — LIVE VERIFIED | `adb install` Success; cold start; `MainActivity` resumed; PID alive; logcat clean (same APK hash as the final build) |
| 3 | Analyzer | PASS — LOCAL VERIFIED | Exit 0, “No issues found!” |
| 4 | Flutter unit/widget suite | PASS — LOCAL VERIFIED | 150/150 passed, exit 0 (2026-10-27) |
| 5 | Kotlin policy decisions (windows, bedtime, restore list, protected packages) | PASS — LOCAL VERIFIED | 13/13 JUnit tests passed |
| 6 | Debug APK build | PASS — LOCAL VERIFIED | Exit 0; 242,192,247 bytes; SHA-256 recorded |
| 7 | SQL schema, RLS isolation, RPC authorization, Realtime policy | PASS — LOCAL VERIFIED | Final fresh run with **all seven** migrations and every test file: exit 0; 19 tables; Realtime policy created; 0 ERROR/ASSERTION FAILED; includes BUG-024, BUG-026, `55_pairing_invite_atomic.sql`. Realtime is a local stub, not hosted |
| 8 | Edge Function type check and shared pure-logic tests | PASS — LOCAL VERIFIED | 9 entrypoints exit 0; 36 tests passed (2026-10-27) |
| 9 | Hosted Auth and server-derived roles | PASS — LIVE VERIFIED | QA sign-in; `bootstrap.set_role`; child self-promotion denied |
| 10 | Hosted family isolation | PASS — LIVE VERIFIED | Cross-family reads, member lists, redeem and device access denied |
| 11 | Hosted pairing lifecycle, replay and expiry | PASS — LIVE VERIFIED | 24/24 phase 1, 6/6 re-link A, 6/6 re-link B, expired-code 400 |
| 12 | Hosted device registration, heartbeat, telemetry and commands | PASS — LIVE VERIFIED | 42/42 phase 2; wrong-secret heartbeat denied; duplicate/stale telemetry rejected |
| 13 | Revoked-device and unlinked-device denial | PASS — LIVE VERIFIED | Phase 2 revocation checks; unlinked check: registration 403 and telemetry 401 after unlink; post-revocation telemetry/command/control denied |
| 14 | Hosted private Realtime | PASS — LIVE VERIFIED | Family parent/child and session participant subscribed; foreign parent and anon rejected |
| 15 | Policy versioning, ack and honest enforcement reporting | PASS — LIVE VERIFIED | v1 enforced; v2 reported failed with Device Owner error; `policy_version` only advanced on success |
| 16 | Guardian service on device | PASS — LIVE VERIFIED | Running with visible notification; heartbeat and poll observed; Usage Access denial reported |
| 17 | Revoke response data minimization (BUG-026) | PASS — LIVE VERIFIED | 4/4 shape checks; no `installation_id`/`secret_hash` |
| 18 | Parent screens on a physical device | PASS — LIVE VERIFIED | The full parent UI journey ran on the RMX2161 (`integration_test/parent_ui_journey_test.dart`) twice: policy save + acknowledgement (`.tools/ui_journey_17.log`) and the revoke flow (`.tools/ui_journey_21_revoke.log`, device shown as `Revoked`). Both end `All tests passed!` |
| 19 | Usage Access / UsageStats upload on device | PASS — LIVE VERIFIED | After `adb shell appops set … GET_USAGE_STATS allow`, 32 UsageStats rows were returned for the last 24 h and uploaded; the guardian service reports the real state instead of fabricating usage |
| 20 | Location sharing on device | PASS — LIVE VERIFIED | After the location grants, `startLocationTracking` → a real fused fix (`source=fused mock=false accuracyM=100.0`), non-null and not `(0,0)`; tracking stopped cleanly |
| 21 | Remote assistance audio/video media | PARTIAL — BLOCKED | Consent, session authorization, STUN-only ICE and the early-ICE buffering fix (BUG-029) are verified; the on-device capture/preview path is verified, but two-device media is **NOT TESTED** (one phone, no TURN) |
| 21a | Device recovery after app data loss (BUG-024) | PASS — LIVE VERIFIED | Hosted `recover_device` run: 31 checks (29 PASS, 2 setup INFO) including child/foreign-parent denial, old-credential replay denial, audit minimized, fresh device distinct and the old credential still revoked. `.tools/live/results/recover_device.json`, 2026-10-27T04:09Z |
| 22 | Device Owner enrollment and Instagram suspension | BLOCKED / NOT TESTED | RMX2161 is not Device Owner; no factory-reset provisioning was performed |
| 23 | Policy persistence across reboot and expiry restore | NOT TESTED | Depends on Device Owner suspension |
| 24 | FCM safety alerts | NOT CONFIGURED | No Firebase project/config |
| 25 | Email confirmation/reset round-trip | NOT TESTED / BLOCKED | No SMTP provider; accounts were dashboard-confirmed |
| 26 | Backup/restore | PARTIAL — LOCAL DRILL VERIFIED / HOSTED NOT CONFIGURED | Local dump → restore reproduced 18 tables and identical row counts; hosted PITR not confirmed and no hosted restore drilled |
| 27 | Privileged-secret contents of the built APK | PASS — LOCAL VERIFIED (string scan) | No service-role key, database URL/password, TURN or cron secret; publishable client values present as intended |
| 28 | Child camera/microphone self-test (main + front, mute, stop) | PASS — LIVE VERIFIED | Device integration test twice; real 1280×720 frames; screenshots `device-media-04/05` |
| 29 | Child screen-recording option | NOT IMPLEMENTED | Verified at five independent levels in the 2026-10-27 Phase 6B audit: source, packaged manifest, APK dex, installed-package permissions and 33 live authenticated screens. See [Phase 6B](#phase-6b--child-screen-recording-audit) |
| 30 | App enable/disable (suspension) on this phone | BLOCKED / NOT TESTED | No Device Owner on RMX2161; UI reports unsupported and the ack fails honestly |
| 31 | Release APK build, install and cold launch | PASS — LIVE VERIFIED | Exit 0; final Child ID build 110,313,302 bytes, SHA-256 `d83aa380…6572c`, versionCode 4002; `adb install -r` Success on both devices with data preserved; role-selection screen rendered; PID alive; logcat clean |
| 32 | Permanent Child ID assignment and stability | PASS — LIVE VERIFIED | `PC-94EA…` returned on repeated calls before link, after unlink and at relink; second child `PC-9GYF…`; service-only table, no duplicate account |
| 33 | Parent invite by Child ID and mandatory child approval | PASS — LIVE VERIFIED | Parent form → **Waiting for child approval**; child had to approve; parent then saw `realme RMX2161` in the device list |
| 34 | Concurrent invites create one pending request | PASS — LIVE VERIFIED | Six parallel invites → one request id; DB `dup_live_pending = 0`, `concurrent_window_rows = 1` |
| 35 | Pairing-token replay semantics | PASS — LIVE VERIFIED | Cross-parent replay `409 code_unavailable`; same-parent replay `200` with the same request id; used legacy code replay `400 invalid_code` |
| 36 | Two-device journey: unlink/relink, offline, session restore, account switch | PASS — LIVE VERIFIED | See [Two-device journey](#two-device-journey-phase-5-2026-10-27); P3 cosmetic defects BUG-036/BUG-037 remain open |

## Real device vs unit/build-only

| Area | Physical device | Unit / widget / JVM | Hosted | Claim |
|---|---|---|---|---|
| Configuration gate | Observed in an earlier build | Covered by widget test | — | PASS — LOCAL/LIVE |
| Install/launch stability | Observed | — | — | PASS — LIVE |
| Child sign-in and enrollment | Observed | Controller tests | Auth + device rows observed | PASS — LIVE |
| Parent/child navigation and forms (parent side) | Full parent journey driven twice | Widget/controller tests | Parent API harness | PASS — LIVE |
| Android capability bridge | Guardian service observed; Usage Access + location exercised | Controller tests with mocks | Heartbeat/telemetry observed | PASS — LIVE |
| App-blocking policy logic | Benign policy enforced; blocking honestly failed | 13 JVM tests | Policy version/ack observed | PARTIAL — real suspension NOT TESTED (no Device Owner) |
| Usage/location services | Usage Access granted and 32 rows uploaded; real fused location fix | Controller tests | Uploads verified via harness | PASS — LIVE |
| Remote assistance | Consent/signaling/ICE verified; media self-test on one phone; early-ICE buffering fixed and unit-tested | Controller tests with permission denial | Consent/session/ICE verified | PARTIAL — two-device media NOT TESTED |
| Camera/microphone self-test | Main and front live; 1280×720 frames; mute and stop observed | Widget/build only | — | PASS — LIVE |
| Permanent Child ID, invite and consent | Full two-device journey; ID stable across unlink/relink | Widget/controller tests + 25 SQL assertions | Deployed functions exercised; six-way concurrency and replay | PASS — LIVE |
| Backend SQL/RLS/RPC | — | SQL suite on PostgreSQL 16.9 | 66 live checks + 4 shape checks + Child ID matrix | PASS — LOCAL + LIVE |
| Edge Functions | — | Deno tests | Nine deployed and exercised | PASS — LOCAL + LIVE |
| Private Realtime | — | Policy DDL on stub | Subscribe/deny probe | PASS — LIVE |

## Phase 6B — child screen recording audit

Run 2026-10-27, evidence in `.tools/evidence/full-qa/phase6b-recording-20261027/`.
Seven agents (six parallel audits plus one authenticated live sweep) worked
disjoint scopes: Android native, Dart layer, Supabase backend, docs/tests intent,
live device state, compiled APK, and post-login UI.

**Verdict: NOT IMPLEMENTED.** Screen recording does not exist in this app and is
not partially present. No recording test could pass, because there is nothing to
record with.

| # | Check | Label | Evidence |
|---|---|---|---|
| R1 | Capture APIs in app Kotlin | NOT IMPLEMENTED | 0 hits for `MediaProjection`/`MediaProjectionManager`/`createScreenCaptureIntent`/`VirtualDisplay`/`MediaRecorder`/`MediaCodec`/`ImageReader` across all 19 sources and all 3 manifests, all variants |
| R2 | Native bridge surface | NOT IMPLEMENTED | `NativeBridge.kt:67-95` exposes 19 methods (capabilities → daily usage); none captures. `requestPermissions` accepts only camera, mic, location, notifications |
| R3 | Dart recording surface | NOT IMPLEMENTED | 0 hits across 14 recording keywords in `lib/`; 26 routes have no record/stop/list/play action; `lib/` performs no file I/O and never calls `client.storage` |
| R4 | Backend recording support | NOT IMPLEMENTED | 18 tables, no `recordings`/`screen_captures`/`media_clips`, zero `bytea` columns, zero Storage buckets referenced, no Edge Function handles media bytes |
| R5 | Packaged manifest (aapt2) | NOT IMPLEMENTED | `app-debug.apk` and release dumps: no `FOREGROUND_SERVICE_MEDIA_PROJECTION`; services are `GuardianService` fgType `0x1` (dataSync) and `LocationTrackingService` fgType `0x8` (location); neither is `0x20` |
| R6 | APK dex attribution | NOT IMPLEMENTED | `dexdump -d` over 19 dex files: 728 capture-class hits, all inside `com.cloudwebrtc` (288) and `org.webrtc` (202) plus Flutter PlatformViews and CameraX. All 56 `com.parentcontrol.parent_control` classes: zero |
| R7 | Installed package permissions, live | NOT IMPLEMENTED | `dumpsys package` on both devices: no capture permission requested or granted |
| R8 | Live capture session state | NOT IMPLEMENTED | `dumpsys media_projection` → "Media Projection: null" on both devices; the app runs no foreground service of any type |
| R9 | Authenticated UI sweep | PARTIAL — NEGATIVE CONFIRMED | 33 authenticated screens/dialogs walked (≈24 parent on emulator, ≈9 child on realme): zero recording controls; the only dialog all session was the system camera prompt for the QR scanner |
| R10 | "Recording" row behaviour | PASS — LIVE VERIFIED (as a readout) | Tapping the `Recording / Off — preview only` row in the child media self-test did nothing; the nodes are `clickable="false"`. The wording itself was filed and fixed as BUG-030 — it now reads `Not available in this app` |
| R11 | Consent dialog never reachable | PASS — LIVE VERIFIED | Logcat over the whole session on both devices: no `MediaProjectionManager`/`createScreenCaptureIntent`/virtual-display activity from the app pid |
| R12 | Silent start after login/pairing/policy update | PASS — LIVE VERIFIED | Nothing can start silently because nothing exists; no app-attributable MP activity across sign-in, navigation and backgrounding |
| R13 | Orphaned media / temp files | PASS — LOCAL VERIFIED | No `/sdcard/Android/data/com.parentcontrol.parent_control`, no app-created mp4 in Movies/DCIM on either device |
| R14 | Product intent | OUT OF SCOPE BY DESIGN | `docs/api-contract.md:545-546`, `docs/remote-assistance.md:83-94`, `README.md:98` and six child-facing UI strings promise no screen capture; git history shows no recording was ever added and removed |
| R15 | OS encoder path on the real child device | BLOCKED | `adb shell screenrecord` on the RMX2161 is refused by ColorOS SELinux (Enforcing). The emulator captured a valid 5 s H.264 clip. A future implementation therefore cannot assume the realme's encoder works |
| R16 | Regression baseline | PASS — LOCAL VERIFIED | `fvm flutter analyze` 0 issues; `fvm flutter test` 150 passed / 0 failed / 0 skipped on Flutter 3.44.6 (ee80f08bbf). Re-run on 2026-10-28: same 150/0 result, analyze clean in 164.8 s (`.tools/evidence/qa-20261028/flutter/`) |

Test-case mapping for the Phase 6B brief: sections **B** (consent), **C** (physical
recording), **D** (parent delivery), **E** (audio in recordings) and the recording
parts of **F**/**G** are **NOT TESTED — feature absent**; they cannot be marked
passed and no substitute (camera self-test, WebRTC session, build success) was
accepted as proof.

Artefact provenance was re-established because the two devices were not running
the hashed debug build:

- emulator-5554 → byte-identical to `app-x86_64-release.apk`, SHA-256 `80164c708014cb…`, versionCode 4001
- realme RMX2161 → byte-identical to `app-arm64-v8a-release.apk`, SHA-256 `ec15b5e2325219…`, versionCode 2001
- `app-debug.apk` (SHA-256 `2d979e084eeb1eea…`, versionCode 1) cannot be installed over either, see BUG-031

Follow-up for the owner: the QA child sign-in during R9 may have re-created
enrollment state that the previous run had deliberately revoked. Re-check the
hosted device rows and re-revoke if needed.

An implementation plan (native, backend, consent design and the API-contract
change it forces) is in [screen-recording-plan.md](screen-recording-plan.md).
**Owner decision, 2026-10-27: screen recording stays out of scope.** The app's
child-facing privacy promises are kept as written. Two defects found while
auditing were actioned instead: BUG-030 (the self-test row whose `Recording / Off`
wording implied a disabled recorder — fixed, wording plus test assertion) and
BUG-031 (`--split-per-abi` version codes make the documented debug install
impossible on both test devices — filed, P3).

## Agent audit assignments

Six parallel read-only audits were requested for the camera/microphone, app
enable/disable, and screen-recording work. Two (`S4`, `S6`) returned their
findings; four (`S1`, `S2`, `S3`, `S5`) did not deliver because the agent
queue/daily limit rejected or stalled them. Their scopes were therefore covered
by direct inspection and the device runs recorded above, not by a second agent.
No audit was treated as a pass on the strength of an agent that did not return.

The 2026-10-27 Phase 6B recording audit used the same pattern and all seven
agents returned (six parallel plus one follow-up live sweep). ADB and the Flutter
toolchain each had a single owner per agent to avoid clobbering device or build
state; the six code/backend audits were read-only. One agent's diagnosis was
corrected by direct re-testing: it reported the debug APK as arm64-only, when the
actual failure was a version-code downgrade refusal caused by AGP's ABI-split
version codes (BUG-031).

## Residual gaps (not passes)

- No custom SMTP. Confirmation/reset emails and the deep-link session exchange
  are **NOT TESTED**.
- FCM and TURN are **NOT CONFIGURED**. Push alerts and relayed media are
  **NOT TESTED**.
- The phone is not Device Owner. Real package suspension (including Instagram),
  reboot persistence and restore-on-expiry are **NOT TESTED**. The app reports
  unsupported honestly instead of claiming enforcement.
- No two-device WebRTC session was performed. The camera/microphone self-test
  and the on-device grants prove this phone's capture, preview and location
  paths only; peer-to-peer media and TURN relay are **NOT TESTED**.
- Child screen recording does not exist in this app. Android MediaProjection
  captures the entire display (including other apps), so it was not added under
  the "this app only" constraint. Re-confirmed five ways in Phase 6B above; every
  recording test case in that brief is **NOT TESTED — feature absent**, not a
  pass. The realme's OS encoder path is additionally **BLOCKED** (R15), so even a
  future implementation has an unproven prerequisite on the one physical child
  device.
- Backup/restore: the **hosted** project's backup/PITR is **NOT CONFIGURED /
  UNVERIFIED** (no hosted restore drilled). A **local** dump → restore drill was
  performed and verified on 2026-10-27 (identical row counts); see
  [backend.md](backend.md#backup-and-restore-drill).
- Device Owner provisioning is documented but **BLOCKED** on this phone: the
  procedure in [device-owner-provisioning.md](device-owner-provisioning.md)
  requires a factory reset that was not authorized.
- No staging project was created. At the owner's direction the change set was
  applied to the existing production project, so the usual staging gate was
  replaced by the deployment review, the local suite and the live matrix above.
- The hosted project's backup/PITR was not verified before the migrations were
  applied, and no hosted restore was drilled. The apply was additive and the
  live matrix passed, but a rollback would depend on Supabase's own retention.
- Four `pairing_attempts` rows written before the pepper deployment still match
  a plain SHA-256 of the identifier. They are historical and were not rewritten;
  the 10-minute rate-limit window ignores them.
- BUG-035 remains an accepted open **P2** (a holder of a valid Child ID can fill
  the child's three pending slots). BUG-036 (pending request shows
  `expires Just now`) and BUG-037 (stale success banner after unlink) are open
  **P3** presentation defects; both were reproduced again on 2026-10-28.
  The 2026-10-28 run added BUG-038 (false Offline between 5-minute heartbeats,
  P2), BUG-039 (background sync stale after relink until the app process
  restarts, P2), BUG-040 (revoked rows rendered as current devices, P2),
  BUG-041 (last-seen labels disagree, P3, needs reproduction) and BUG-042
  (parent ANR on ending a session, P2, emulator only so far).
- The realme's device row was **Offline / Last seen Never reported** at the
  Phase 5 capture because the guardian service was not running then.
  **Superseded 2026-10-28**: the row is active and heartbeating every five
  minutes (last seen 08:51), and the row is still badged Offline for roughly two
  minutes between beats (BUG-038). No staler claim should be repeated.
- Dedicated QA accounts, result files and test policies remain in the hosted
  project for audit. After the 2026-10-28 unlink/relink the realme is again
  linked to QA Family A as `QA Child A`, its device row is active and
  heartbeating, so **a device credential is active**. Unlink the child and
  revoke the device row before deleting or rotating the QA accounts. No
  privileged secret is stored in the repository or the APK.
- Two-device remote media is **PARTIAL**: consent, signalling, connection and
  child-side capture were verified live on 2026-10-28, but remote audio/video
  delivery to the parent was not observed (blank preview, no parent playback,
  TURN not configured, parent on the x86 emulator).

## Complete two-device QA (2026-10-28)

Run by the implementation lead with five read-only sub-agents (device state,
root-cause code reading, backend authorization audit, Flutter toolchain, Deno
plus documentation reconciliation) and a single ADB owner for the UI journey.
No source file, migration or hosted setting was changed, and no app data was
cleared.

### Devices, build and accounts

| | LEFT — parent | RIGHT — child |
|---|---|---|
| ADB serial | `emulator-5554` (`EMULATOR37X2X12X0`) | `5HXWRGQ4IFU8WS4T` |
| Model / OS | `sdk_gphone64_x86_64`, Android 17 / API 37 | realme RMX2161, Android 12 / API 31 |
| App | 1.0.0, versionCode 4002 | 1.0.0, versionCode 4002 |
| Account (from Settings) | `qa.parent.a2.20261026@example.com`, QA Parent A, Parent, verified | `qa.child.a2.20261026@example.com`, QA Child A, family QA Family A |
| Role in this run | Parent dashboard | Child phone |

`fvm flutter analyze` → 0 issues (164.8 s); `fvm flutter test` → **150 passed,
0 failed**; `deno check` → 9/9 entrypoints exit 0; `deno test
supabase/functions/_shared/` → **36 passed, 0 failed**. The SQL suite was not
re-run in this pass: the local PostgreSQL 16.9 instance was listening on
`127.0.0.1:55432`, but no disposable database was created for it. Logs:
`.tools/evidence/qa-20261028/{flutter,deno}/`.

### Root cause of the Revoked rows on the parent dashboard (BUG-040)

The QA family had five device rows: four `status='revoked'` and one active
realme. The parent app fetches every row for the family and filters only by
`family_id` ([supabase_device_repository.dart:31-40](../lib/data/repositories/supabase_device_repository.dart));
revocation is a soft delete (`status`, `credential_revoked_at`) kept for audit
and recovery, and nothing in the query or the card renderer excludes it
([parent_dashboard_tab.dart:255](../lib/features/dashboard/parent_dashboard_tab.dart),
[dashboard_controller.dart:112-113](../lib/features/dashboard/dashboard_controller.dart)).
Consequences observed live: revoked cards look like current devices, keep the
enforcement snapshot from when they were active (`Fully managed (Device Owner)`,
`Policy v1 · Enforced on device`), and the dashboard counts a revoked row as
"this child has a device", so a child with only revoked rows is never prompted
to set up. The rows themselves are correct server-side; this is presentation and
count logic. Verdict **FAIL** for the screen, **PASS — LIVE VERIFIED** for the
diagnosis.

### Root cause of "No rules downloaded" on the realme

Policy is per device row (`device_policies` keyed by device id,
`apply_policy_version`). The current row reports `Version 0`, `Not yet
acknowledged`, and the parent device screen also says `No commands have been sent
to this device yet`. There is no policy row for this device id: the old v1/v2
policies belong to revoked device rows. The child Home maps "no policy object" to
`No rules downloaded` and does not render a fetch error
([child_home_tab.dart:253-258](../lib/features/child/tabs/child_home_tab.dart));
`sync_policy` replays the locally stored policy only
([GuardianService.kt:283-298](../android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt)).
So the string is honest, but the product silently drops the previous policy on
re-enrolment and gives no "cannot load rules" state. Verdict **FAIL** for policy
continuity, **NOT TESTED** for applying a new policy in this run.

### Live journey

| Step | Status | Observed |
|---|---|---|
| Correct accounts signed in | PASS — LIVE VERIFIED | Settings on both devices: QA Parent A (`qa.parent.a2.20261026@example.com`, Parent) and QA Child A (`qa.child.a2.20261026@example.com`, QA Family A) |
| Child ID visible and stable | PASS — LIVE VERIFIED | Setup screen showed `PC-94EA…` (full value in gitignored evidence); the identical ID appeared again after unlink (`child_enrollment_id.xml`) |
| Parent unlinks QA relationship | PASS — LIVE VERIFIED | Confirmation dialog; family page then showed **Removed** and the snackbar "The server confirmed the removal" (`parent_after_unlink.xml`) |
| Access revoked after unlink | PASS — LIVE VERIFIED | Child's last error became `App list upload failed: Device credentials are not valid.`; the device row was revoked; `dpm` unchanged (`child_home_after_unlink.xml`) |
| Parent re-invites by Child ID | PASS — LIVE VERIFIED | Request pending, `Waiting for child approval`, requested 08:34, expires 08:34 next day (`parent_request_sent.xml`) |
| Child approval mandatory | PASS — LIVE VERIFIED | Child saw `From QA Parent A` and had to open **Approve** → confirm `Join QA Family A?` before any membership existed (`child_pending_request.xml`, `child_assist_*` analogue) |
| Re-registration | PASS — LIVE VERIFIED | `This phone is registered`; parent approved state showed the child name unmasked (`parent_after_approve.xml`, `child_after_register.xml`) |
| Session restoration | PASS — LIVE VERIFIED | Force-stop + relaunch of the child app restored the signed-in account and moved to the unlinked setup state at the right moment (`child_relaunch.xml`); the parent app restored its family and devices after relaunch |
| Stale linked UI after unlink | FAIL (BUG-037) | Until relaunch the child still showed `QA Family A`, `Linked`, `Registered`, `Background protection Running` |
| Heartbeat after relink | FAIL then PASS (BUG-039) | `last_seen` stayed at 08:33 for five minutes after re-registration; a cold restart produced an immediate heartbeat at 08:41 |
| Heartbeat cadence | PASS — LIVE VERIFIED | 08:41, 08:46, 08:51 observed through `last_seen`; service polls every 20 s (`GuardianService.kt:37-39`) |
| Online badge accuracy | **FAIL** (BUG-038) | 08:50:5x: `4 min ago · 8:46 AM` but **Offline**; 08:51:55: `Just now · 8:51 AM` and **Online** — a healthy device is false-Offline for ~2 of every 5 minutes |

### Background protection

The `GuardianService` FGS was running with its visible notification
(`dumpsys activity services`: `isForeground=true`, id 4101). On 2026-10-28 the
notification was filed under Silent notifications and its text warned that
background sync needed attention, while the in-app card said **Running** — the
in-app badge reflects only that the service exists. Force-stop stopped all
background work; nothing was claimed to continue until the app was relaunched.
Between heartbeats the service restart counter reset roughly every 40 seconds
during the relink window, which is recorded under BUG-039 and not yet explained.

### Camera and microphone (real hardware)

PASS — LIVE VERIFIED. The child **Camera and microphone test** opened the main
camera (`Main camera live`, `1280×720` frames), switched to the front camera
(`Front camera live`), and reported the microphone **Live**; Android camera
history shows `CONNECT device 0` → `DISCONNECT` → `CONNECT device 1` →
`DISCONNECT`, and `dumpsys audio` returned to `Recording active: false` after
**Stop test**. The sheet reports `Recording — Not available in this app`. The
mute toggle was tapped but the state label was not captured, so mute is **NOT
VERIFIED**. On starting the remote session, Android showed a microphone runtime
prompt even though Settings listed the permission as Granted; it was answered
through the dialog (no bypass).

### Remote assistance (parent → child)

PARTIAL — LIVE VERIFIED for consent and connection, **NOT VERIFIED** for media
delivery. The parent sent a video request; the child saw it, accepted it, and
the session page recorded consent and showed **Connected** on both devices. The
realme opened its front camera during the session (`CONNECT device 1`,
`Recording active: true`). The parent's preview area stayed blank and no
parent-side audio playback was observed, so remote audio/video is not proven;
TURN is not configured and the parent was the x86 emulator. Ending the session
released the child camera and microphone. The parent app raised an ANR at the
moment **End session** was tapped (BUG-042, observed once). Evidence:
`.tools/evidence/qa-20261028/live/child_assist_*.xml`,
`parent_assist_accepted.png`, `parent_anr.txt`.

### Screen recording and app blocking

- Screen recording: **NOT IMPLEMENTED**. The child self-test itself reports
  `Recording — Not available in this app`; no Android screen-capture consent
  dialog is reachable. Every recording case stays **NOT TESTED because the
  feature is absent**, not a pass.
- App blocking / Device Owner: **BLOCKED**. `dpm list-owners` on the RMX2161
  returns `no owners`; the only active admin is the app's own receiver. The
  parent UI says `App suspension is not supported here` and the child says
  `Device admin only — app blocking is not available`, which is accurate. No
  suspension was attempted and the phone was not reset.

### Backend authorization audit (static, 2026-10-28)

Ten claims were checked against code and the SQL suite
(`.tools/evidence/qa-20261028/backend/audit.md`). Clean at code level: identity
and role derivation, pairing approval/replay, audit content, family isolation
for the main tables, and child-ID authorization. No P0/P1/P2 security bug was
found; a Child ID alone grants no device, camera, microphone or recording
access. Six **P3** issues are recorded there for a later change: device-asserted
non-monotonic `policy_version`, malformed `invite` skipping the rate-limit
pre-check, an existence/timing oracle plus a check-then-insert race in the
rate limiter, the unsalted hash fallback when the pepper is unset, a constant
`retry_after_seconds`, and no per-child cap on remote-session requests. Several
authorization behaviours remain **NOT TESTED** in the suite (revoke response
shape, `device_policies` cross-family read, realtime anon denial).

### Not proved by this run

Applying a policy to the newly linked device, remote audio/video delivery,
Device Owner enforcement, TURN relay, SMTP and FCM delivery, QR scanning on
hardware, and a physical parent phone (the ANR and the blank preview were seen
on the emulator). None of these is claimed as a pass.

## Conclusion

The app is built against a deployed hosted Supabase project and the required
server-enforced flows were exercised live: Auth with server-derived roles, family
isolation, pairing/expiry/replay/revocation, device registration and telemetry,
command expiry, private Realtime authorization, remote-session consent, and
policy versioning. A real Android phone enrolled, ran the guardian service,
heartbeated, acknowledged a benign policy and honestly reported that a blocking
policy could not be enforced without Device Owner. The parent-facing
`revoke_device` response was narrowed to remove service-only fields (BUG-026) and
rechecked live.

On 2026-10-27 the permanent Child ID / atomic-invite change set was applied to
the same production project and verified live: 19 tables with the new service-only
`child_contact_ids`, both functions redeployed with recorded digests, a stable
ID across unlink and relink, mandatory child approval, uniform 400 errors with a
429/`retry_after_seconds` bound, six concurrent invites yielding one request,
replay returning 409 for a different parent and 200 for the same parent, audit
metadata with no identifier, and an HMAC-keyed attempt hash in effect. The
two-device journey ran end to end on the emulator and the physical RMX2161,
including offline handling, session restoration and parent account switching.

Locally, the analyzer is clean, 150 Flutter tests and 13 Kotlin policy tests
pass, Deno type-checks all nine functions and passes 36 tests, the SQL/RLS/RPC
suite passes on a fresh PostgreSQL 16.9 database with **all seven** migrations on
2026-10-27 (the two-session lock test blocked 3,404 ms and left one row), a local
backup → restore drill reproduced the source row counts, and the final APK scans
free of privileged credentials. On the phone, the visible camera/microphone
self-test opened both cameras, decoded 1280×720 video frames, muted and released
the microphone, and closed every track without recording.

Beyond the earliest runs, the same phone drove the full **parent-facing UI**
(family creation, pairing, device detail, restrictions save + acknowledgement,
revocation), granted **Usage Access** (32 rows uploaded) and **location** (real
fused fix), and the **device-recovery** path (BUG-024) was exercised live against
the hosted project (31 checks). A packaging-only split-per-ABI release build was
measured and the arm64 artefact installed and cold-launched.

Still not verified and explicitly marked above: SMTP email round-trip, FCM,
TURN relay, two-device media, Device Owner suspension (including Instagram),
reboot persistence, hosted backups/restore, and the Device Owner provisioning
whose procedure requires an unauthorized factory reset. Two cosmetic P3 defects
(BUG-036, BUG-037) and one accepted P2 (BUG-035) remain open.
