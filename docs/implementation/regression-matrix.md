# Phase 1 — regression matrix

Owner: verification workstream. Date: **2026-10-30**.
Base: commit **`2a0209f`** (Phase 0 baseline) + **working tree, uncommitted**. The observed `HEAD`
is `8ebb73c` (a docs-only commit after the baseline; `2a0209f` is its ancestor). All Phase 1 source,
test, migration and Android changes are uncommitted.

Toolchain actually used: Flutter **3.44.6** / Dart **3.12.2** via
`./.fvm/flutter_sdk/bin/flutter` and `./.fvm/flutter_sdk/bin/dart`; Deno **2.9.4**; local
PostgreSQL **16.9** (`./.tools/pgsql16/pgsql/bin`, disposable cluster on port 55439). The system
`dart` (3.10.7) was never used.

Status vocabulary: `PASS` / `FAIL` / `BLOCKED` / `NOT TESTED` / `NOT APPLICABLE`. A run is `PASS`
only if it was executed in this phase. No device, emulator or hosted Supabase project was used.

## 1. Five levels

| Level | Check | Exact command | Result | Evidence / note |
|---|---|---|---|---|
| Static | Flutter analyzer | `./.fvm/flutter_sdk/bin/flutter analyze` | **PASS** (exit 0) | Final re-run after the three constructor fixes: **"No issues found!"** (11.5 s), exit 0. The verification snapshot had 0 errors/0 warnings/**10 info** lints (`prefer_initializing_formals`, 3 files) and exit 1; those 10 lints are now fixed, not silenced. Verification log `.tools/verify-analyze-final-20261030.log`; see §6 for the post-verification delta. |
| Static | Deno type-check of the four deployed functions | `deno check supabase/functions/account/index.ts supabase/functions/cron/index.ts supabase/functions/family-admin/index.ts supabase/functions/remote-session/index.ts` | **PASS** | Four `Check ...` lines, no diagnostics. |
| Static | Kotlin/Android source | compiled by the APK build below (no standalone Kotlin compiler here) | **PASS** | See Integration / Android build. |
| Unit | Flutter unit + widget suite | `./.fvm/flutter_sdk/bin/flutter test` | **PASS** | Final: **`+316 -0`, "All tests passed!", exit 0** (00:25). Initial run before triage: `+310 -6`, exit 1. Log `.tools/verify-flutter-test-final-20261030.log`. |
| Unit | Deno function suite | `deno test supabase/functions` | **PASS** | **83 passed, 0 failed** (1 s), exit 0. Per-directory: `_shared` 36 (3+8+8+17), `account` 13 (6+7), `device-command` 11, `family-admin` 4, `remote-session` 19 (11+8). Log `.tools/verify-deno-test-20261030.log`. |
| Unit | Kotlin JVM unit tests (incl. new `AudioAssistanceStopIdempotenceTest.kt`) | `./android/gradlew test` | **BLOCKED — cross-drive Gradle** | Environment cannot build a project on `D:` from the toolchain working set. Not attempted further; Gradle layout not changed. |
| Integration | SQL authorization suite on a disposable PostgreSQL 16 | 13 migrations + 28 test/stub files via one `psql -v ON_ERROR_STOP=1` chain (exact order = `supabase/tests/README.md`) | **PASS** | **EXIT=0**, no `ERROR`, no `ASSERTION FAILED`; 19 public tables; notices include `ALL CONCURRENCY TESTS PASSED`, `ALL PARENT-CONTROLLED LIFETIME TESTS PASSED`, `ALL CONSENTED-SESSION SIGNALING TESTS PASSED`, `ALL ABANDONED SESSION SWEEP TESTS PASSED`, `ALL PHASE 1 AUTHORIZATION TESTS PASSED`. Log `.tools/verify-sql-final6-20261030.log`. |
| Integration | Android debug build (Kotlin compile check) | `./.fvm/flutter_sdk/bin/flutter build apk --debug` | **PASS** | `√ Built build\app\outputs\flutter-apk\app-debug.apk`, exit 0, Gradle 62.8 s, 243,909,473 bytes. Log `.tools/verify-apk-20261030.log`. |
| Integration | Hosted Edge Function behaviour | dashboard/HTTP against the hosted project | **NOT TESTED** | Phase 1 performs no hosted operation; see `deployment-log.md`. |
| Runtime | App on a device or emulator (session, audio, presence, enforcement) | — | **NOT TESTED** | No device/emulator used in Phase 1. |
| Physical device | Real-phone matrix (mic, FGS, lock/Recents, network, Device Owner) | — | **NOT TESTED** | No physical device used in Phase 1. |

## 2. Per-area rows

Runtime and physical-device columns are `NOT TESTED` for every area because no device was used.

| Area | Executed evidence (level) | Result | Runtime | Physical device |
|---|---|---|---|---|
| Auth | Flutter auth/session tests inside the 316-test suite; SQL `10_schema`, `30_rls` (cross-family, `anon`, role promotion) | **PASS** | NOT TESTED | NOT TESTED |
| Pairing | Flutter child/parent pairing controller tests; SQL `55_pairing_invite_atomic`, `10_schema` (token purpose/grants), `40_functions` approve/reject/expiry/replay | **PASS** | NOT TESTED | NOT TESTED |
| Presence | `test/data/device_model_test.dart` (12 min online / 30 min stalled / age), dashboard + device-detail widget tests, child linked poll (fixture corrected from 10 to 20 min) | **PASS** | NOT TESTED | NOT TESTED |
| Enforcement | `app_restrictions_controller_test.dart`, `policy_enforcement_model_test.dart`, page test; Deno `device-command/enforcement_test.ts` (11); SQL `40_functions` policy versioning | **PASS** | NOT TESTED | NOT TESTED |
| Remote session | Flutter remote-assistance suite (controller, page, reliability, lifetime); Deno `remote-session` 19 tests; SQL `60`–`63` (guard, lifetime, consented signaling, abandoned sweep) | **PASS** | NOT TESTED | NOT TESTED |
| Audio | Flutter audio lifecycle + reliability suites (single peer, idempotent teardown, debounce, permission revoke) after 3 test/production fixes; Kotlin JVM test **BLOCKED — cross-drive Gradle** | **PASS (Flutter) / BLOCKED (Kotlin)** | NOT TESTED | NOT TESTED |
| Safe zones | `safe_zones_controller_delete_test.dart`; SQL `70_phase1_authorization` (no DELETE policy/grant), `30_rls` (child zone writes) | **PASS** | NOT TESTED | NOT TESTED |
| Account / export / deletion | `account_privacy_controller_test.dart` (7) + settings UI tests; Deno `account` 13 tests; SQL `72_retention_sweep` | **PASS** | NOT TESTED | NOT TESTED |
| Settings | `parent_settings_controller_test.dart`, settings body/tab tests inside the 316 | **PASS** | NOT TESTED | NOT TESTED |
| Android build | Debug APK (Kotlin + manifest + network-security-config compiled) | **PASS** | NOT TESTED | NOT TESTED |
| SQL authorization | Full disposable-PostgreSQL chain described above (13 migrations, 19 tables) | **PASS** | NOT TESTED | NOT TESTED |

`supabase/tests/*.sql` run against plain PostgreSQL with an auth/realtime stub; they say nothing
about hosted Supabase RLS/Realtime behaviour.

## 3. Triage of the initial failures

Initial Flutter run: `+310 -6`. All six are accounted for; none was waived.

| # | Failing test | Classification | Resolution |
|---|---|---|---|
| 1 | `test/features/child/child_shell_controller_test.dart`: the linked poll refreshes the device presence row | Phase 1 contract change (presence window 6 → 12 min); fixture encoded the old window | Fixture `lastSeenAt` 10 min → 20 min (still outside 12 min). Assertions unchanged. |
| 2 | `remote_session_audio_lifecycle_test.dart`: decidePeerJoin never rebuilds a live or parent-owned peer | Test bug: pure test never assigned the `late controller`, so `tearDown` threw | Initialise `controller = buildController()` in that test; decision assertions unchanged. |
| 3 | `remote_session_audio_lifecycle_test.dart`: a rapid duplicate rejoin offer is dropped | Test bug: `verify(...).captured` consumes matched calls, second call found none | Assert the total offer count once, after the retry window (`hasLength(1)`); no assertion removed. |
| 4 | `remote_session_audio_lifecycle_test.dart`: the debounce expires so a later rejoin is still announced | Same consumed-call bug | Same one-shot capture; final expectation `>= 2` offers retained. |
| 5 | `remote_session_controller_test.dart`: audio_assistance_stopped with permission_revoked stops capture without ending the server session | **Genuine Phase 1 bug** (audio): the stop handler cleared `_nativeServiceRunning` before teardown, so teardown no longer commanded the idempotent native stop | Removed the premature clear in `_handleServiceStopped`; teardown's `_stopAudioAssistanceService` clears the flag itself. Existing assertion kept. |
| 6 | `account_privacy_controller_test.dart`: a confirmed deletion clears the local session | **Genuine Phase 1 bug** (lifecycle): after a successful server deletion the controller called `Get.offAllNamed` unguarded; in a unit test (and on any navigation failure) it threw and `deleteAccount` returned `false` with an error for an account that was already deleted | Navigation wrapped in `try/catch` after local cleanup; the server outcome is what the method reports. Assertion kept. |

SQL suite triage (each iteration started from a **fresh** database; first failing file reported):

| Iteration | First failing file | Error | Classification / resolution |
|---|---|---|---|
| 1 | `60_remote_session_concurrency.sql` | `ERROR: not_family_parent` at `request_remote_session` (line 23 RAISE) | Phase 1 authorization check; fixture created devices but no `family_members`. Added parent/child memberships. |
| 2 | `61_parent_controlled_lifetime.sql` | `ASSERTION FAILED (a legacy active session must block...): expected P0001, got 42501 (not_family_parent)` | Same missing memberships in the fixture. Added them. |
| 3 | `62_signaling_consented_session.sql` (pre-emptive fix; did not get to run) | — | Same fixture gap; added parent/child memberships before the rerun. |
| 4 | `70_phase1_authorization.sql` | `duplicate key ... families_one_active_per_owner` | Fixture inserted two live families for one owner before soft-deleting one; the partial unique index rejects that. Insert the third family already deleted. |
| 5 | `70_phase1_authorization.sql` | `invalid input syntax for type json: Token "("` then `invalid input syntax for type uuid: "(row...)"` | `request_remote_session` returns the `remote_sessions` row type, not `jsonb`; the test assigned it to `v_result jsonb` / used `SELECT INTO`. Added a typed `v_session` and used composite assignment (`:=`). Production not changed. |
| 6 | `70_phase1_authorization.sql` | `ASSERTION FAILED: service_role keeps execute on request_device_recovery` | The private helper never had an explicit `service_role` grant (relied on PUBLIC); migration 2 removes PUBLIC by design and the public `SECURITY DEFINER` wrapper is the supported path. Assertion corrected to the public wrapper. **Finding recorded:** the migration does not re-grant `service_role` on the private helper; no Edge Function calls it directly. |

## 4. Every edit made by verification

Production (two files, both genuine Phase 1 bugs):

1. `lib/features/remote_assistance/remote_session_controller.dart` — removed
   `_nativeServiceRunning = false;` from `_handleServiceStopped` (the stop path now issues the
   idempotent native stop exactly once via teardown).
2. `lib/features/settings/parent_settings_controller.dart` — wrapped `Get.offAllNamed(...)` in
   `_clearAfterAccountDeletion` in `try/catch`, so a navigation failure cannot report a completed
   account deletion as failed.

Tests / fixtures (no assertion deleted or relaxed):

3. `test/features/child/child_shell_controller_test.dart` — presence fixture 10 → 20 minutes.
4. `test/features/remote_assistance/remote_session_audio_lifecycle_test.dart` — (a) initialise the
   controller in the pure decision test; (b) two rejoin tests capture verified calls once because
   `verify(...).captured` consumes them. Final expectations are equivalent or stronger (exactly one
   offer; at least two offers).
5. `supabase/tests/60_remote_session_concurrency.sql` — added `family_members` rows.
6. `supabase/tests/61_parent_controlled_lifetime.sql` — added `family_members` rows.
7. `supabase/tests/62_signaling_consented_session.sql` — added `family_members` rows.
8. `supabase/tests/70_phase1_authorization.sql` — insert soft-deleted family with `deleted_at` set;
   read `request_remote_session` into a typed row variable; assert `service_role` execute on the
   public `request_device_recovery` wrapper instead of the private helper.

No migration or Edge Function was edited. No assertion was weakened, skipped or deleted. The two
production edits were re-verified by the targeted run (59/59) and by the final full suite (316/316).

## 5. Limits of this matrix

- Kotlin unit tests: `BLOCKED — cross-drive Gradle`; Kotlin correctness is only compile-level (APK).
- Runtime and physical-device levels: `NOT TESTED` — no device was used in Phase 1.
- Hosted behaviour, RLS, Realtime and Edge Function deploys: `NOT TESTED` — nothing was applied;
  `deployment-log.md` records the operations that still need owner approval.
- SQL suite: local PostgreSQL 16 with `00_auth_stub.sql` / `05_realtime_stub.sql`; not Supabase.
- `flutter analyze` is clean (`No issues found!`, exit 0) as of the post-verification delta in §6. During
  verification it exited 1 on 10 info lints; no errors/warnings at any point, and nothing was silenced.
- Audio audibility is not measurable here (no listener); only object-level behaviour is asserted.

## 6. Post-verification delta (coordinator, 2026-10-30)

After the verification run above, a review pass required corrections. None of them changes production
behaviour, but the tested snapshot is therefore **not byte-identical** to the final tree. Exact delta:

| File | Change | Re-verified how |
|---|---|---|
| `lib/features/app_restrictions/app_restrictions_controller.dart` | Constructor converted to the project's private-named-parameter form (`required this.deviceId`, `required this._deviceRepository`, …) — clears 2 `prefer_initializing_formals` infos, no logic change | `flutter analyze` → "No issues found!", exit 0; `flutter test test/features/app_restrictions` → all pass |
| `lib/features/settings/parent_settings_controller.dart` | Same constructor change (clears 4 infos) | `flutter test test/features/settings` → all pass |
| `lib/features/settings/account_privacy_repository.dart` | Same constructor change (clears 4 infos) | same targeted run |
| `supabase/config.toml` | Added `[functions.account] verify_jwt = true` (the function was registered in the dashboard manifest without a matching local block) | Deno suite unaffected (no config load); manifest reviewed |
| `docs/implementation/deployment/manifest.md` | Row 3 filename corrected to `20261030000300_retention_sweep.sql`; migration 2/3 SHA-256 refreshed (`f7062a84…`, `8de3cb38…`) | `sha256sum` re-computed on the three migration files |
| `docs/implementation/api-contract.md` | `cron` rows corrected to `{}` / `{closed_sessions}`; retention keys matched to `run_retention_sweep()` | read against `supabase/functions/cron/index.ts` and `20261030000300_retention_sweep.sql` |

Targeted re-run of the affected Flutter suites: `./.fvm/flutter_sdk/bin/flutter test test/features/app_restrictions test/features/settings` → **"All tests passed! (+24)"**, exit 0.

Not re-run after this delta (no affected code): the full 316-test suite, the 83 Deno tests, the SQL
chain, and the APK build. Those results in §1 stand for the snapshot they were run against. Kotlin
remains `BLOCKED`; runtime and hosted levels remain `NOT TESTED`.