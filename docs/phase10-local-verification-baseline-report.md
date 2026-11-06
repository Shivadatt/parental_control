# Phase 10 Local Verification Baseline Report

**Document class:** T-A-01 Execution Record — Local Hermetic Verification Baseline (Test Execution, not an audit phase).  
**Task Reference:** Phase 9.13 §E.1 task **T-A-01**; executed on 2026-11-06. This document creates no Phase 9.x successor and grants no implementation authority.  
**Repository:** `D:\parentcontrol_app` (`main`, HEAD `a2faa5fb70f84638359154c68d19ce304fadab36`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) — **NOT ACCESSED**; every command in this run was offline and local-only.  
**Date:** 2026-11-06.  
**Authorizing Basis:** `phase-9-owner-decision-register.md:97` — "Offline Test Execution (Deno, local SQL, JVM, Flutter) — **PERMITTED (Green)**".  
**Companion Documents:** [`docs/phase9-13-final-audit-and-implementation-launch-plan.md`](phase9-13-final-audit-and-implementation-launch-plan.md) (defines T-A-01 and the task inventory) · canonical register [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) (unmodified).  
**Verdict:** **BASELINE ESTABLISHED.** Every suite that has a permitted runner is green at HEAD: Deno **150/150**, local SQL chain **33/33 files, 0 assertion failures**, Flutter **408/408**. The Kotlin JVM suite was **NOT executed and NOT compiled** — no permitted runner exists (see F).  
**Raw Transcripts:** `C:\Users\ASUS\AppData\Local\Temp\t-a-01\` (outside the repository; see E.3 for the one log the SQL runner itself writes inside `.tools\`, which is gitignored by `.gitignore:22`).

**Strict Governance Invariant:** Nothing in this run modified source, tests, configuration, hosted state, device state or Git state. Results below are copied from actual command output. Where a suite could not run, the reason is stated and no substitute claim is offered. Offline test execution is Green; it is not implementation permission, and this report does not start T-B-01 or any other implementation task.

---

## A. Environment and Tool Versions

Measured in this run.

| Component | Measured | Status for this suite |
|---|---|---|
| Host | Windows 10.0.26300, x64, Git Bash (`/usr/bin/bash`) | — |
| Deno | `deno 2.9.4 (stable, release, x86_64-pc-windows-msvc)` · v8 15.0.245.2-rusty · TypeScript 6.0.3 | Used |
| Flutter on `PATH` | `Flutter 3.38.8 • channel stable` / **Dart 3.10.7** (`/d/software/flutter/flutter_windows_3.38.8-stable/flutter/bin`) | **Insufficient** — cannot resolve this repo |
| Flutter declared by repo (FVM) | `.fvm/flutter_sdk` → `Flutter 3.44.6` / **Dart 3.12.2**; `.fvm/fvm_config.json` `"flutterSdkVersion": "3.44.6"`; `.fvmrc` `"flutter": "3.44.6"`; `.dart_tool/version` = `3.44.6` | **Used for the passing run** |
| SDK constraint | `pubspec.yaml:21-22` → `environment: sdk: ^3.12.2` | Satisfied only by FVM 3.44.6 |
| JDK | `openjdk version "17.0.16" 17 Temurin`, `JAVA_HOME=C:\Program Files\Java\jdk-17` (a JDK 19 also precedes it on `PATH`) | Recorded only; not used |
| Kotlin compiler | `which kotlinc` → not found; `kotlinc -version` → exit 127; no Kotlin distribution under `.tools\` or the scanned program dirs | **Absent** |
| Local PostgreSQL | Bundled at `.tools/pgsql16/pgsql/bin`; `PGDATA` default `.tools/pgdata_chain`; `PGHOST` `127.0.0.1`; `PGPORT` `55581` (`supabase/tests/run_sql_chain.sh:34-38`) | Used by the chain |
| `psql` / `docker` on `PATH` | both **NOT FOUND** (the chain uses its bundled binaries, so this is not a blocker) | — |
| ADB 1.0.41, Supabase CLI 2.109.0 | Present on `PATH` | **Not used** (prohibited) |
| `android/local.properties` | **EXISTS** (178 B, mtime 2026-10-29 17:19; keys `sdk.dir`, `flutter.sdk`, `flutter.buildMode`, `flutter.versionName`, `flutter.versionCode`; gitignored) | Recorded — corrects a Phase 9.13 statement (H.2) |
| `android/key.properties` | **NOT FOUND** (only `key.properties.example`) | Recorded |

---

## B. Exact Commands Executed and Exit Codes

| # | Command (verbatim) | Suite | Exit |
|---|---|---|:---:|
| 1 | `deno test supabase/functions` | Deno, as specified by the owner | **1** |
| 2 | `DENO_DIR="C:/Users/ASUS/AppData/Local/deno" deno test --allow-read supabase/functions/` | Deno, repository-documented form (`scripts/local-ci.ps1:208`) | **0** |
| 3 | `bash supabase/tests/run_sql_chain.sh` (no options) | Local SQL regression chain | **0** |
| 4 | `flutter test` (PATH SDK 3.38.8) | Flutter — dependency resolution | **1** |
| 5 | `.fvm/flutter_sdk/bin/flutter test --no-pub` | Flutter — repo-declared SDK | **0** |
| 6 | `.fvm/flutter_sdk/bin/flutter test --no-pub --reporter json` | Flutter — corroborating run | **0** |
| 7 | `flutter --version`, `.fvm/flutter_sdk/bin/flutter --version`, `dart --version`, `deno --version`, `java -version`, `which kotlinc`, `git status --porcelain`, `git diff --stat -- pubspec.lock pubspec.yaml`, `stat -c '%y' .git/index`, read-only `grep`/`find`/`sed`/`ls` | Environment + integrity checks | various |

No other command type was executed. Specifically: no `gradlew`, no `gradle`, no `flutter build`, no `adb`, no `supabase` CLI, no network client, and no Git write command.

---

## C. Actual Test Counts Per Suite

### C.1 Deno Edge Function tests — 150 cases, 15 files

| Run | Passed | Failed | Ignored / filtered | Runner clock | Runner summary verbatim |
|---|:---:|:---:|:---:|:---:|---|
| 1 — literal command | 139 | 11 | 0 | 5 s | `FAILED \| 139 passed \| 11 failed (5s)` then `error: Test failed` |
| 2 — `--allow-read` | **150** | 0 | 0 | 1 s | `ok \| 150 passed \| 0 failed (1s)` |

Inventory cross-check: 15 `*_test.ts` files and 150 `Deno.test` invocations — the runner executed exactly 150 in both runs. **Suite verdict: green (150/150).**

### C.2 Local SQL regression chain — 33 files

| Metric (from the runner's own summary block) | Value |
|---|---|
| `Files Executed` | **33** |
| `psql Exit Code` | **0** |
| `Assert Failed` | **0** |
| `Errors Count` | **0** |
| `Log Line Count` | 647 |
| `STATUS` | `PASSED (All 33 test/migration files clean)` |
| Mode / target | `NORMAL (all assertions must pass)` on `127.0.0.1:55581` |
| Disposable DB | `p6chain_20261106_122629`, created and dropped by the script's own default (`KEEP_DB=false`) |
| Cluster afterwards | **left running** (`pg_isready`: `127.0.0.1:55581 - accepting connections`; the script's default is not to stop it) |

Files that printed explicit `ALL … TESTS PASSED` notices: chain files 60, 61, 62, 63, 70, 71, 74, 75, 76. Stubs, schema, RLS, function and migration files carry no assertion notices — their verdict is the clean `ON_ERROR_STOP=1` session with zero errors. The negative-control fixture `fixtures/sql05_lossy_negative.sql` is **not** part of a normal run (it requires `--negative`) and was not executed.

**The "33-file chain" claim is now reconciled, not disputed:** the runner's `FILES` array is 14 `supabase/migrations/*.sql` + 19 `supabase/tests/*.sql` = 33. `docs/implementation/phase-9-regression-matrix.md:35` is correct; Phase 9.13 §B.12 called it unverifiable (see H.3).

### C.3 Flutter unit/widget tests — 408 cases, 55 files

| Metric | Value |
|---|---|
| Result line | `00:47 +408: All tests passed!` |
| Passed / failed / skipped | **408 / 0 / 0** |
| `[E]` error entries in the expanded log | 0 |
| JSON run corroboration (verified first-party) | 509 `testStart`, 509 `testDone`, 509 `"result":"success"`, 101 `"hidden":true`, 0 error/failure → 509 − 101 = **408** |
| Source inventory | 55 `*_test.dart` files; 330 `test(` + 57 `testWidgets(` = 387 literal case lines; 509 − 387 = 122 hidden/pseudo + loop-generated events; the 387→408 delta is attributable to loop-generated cases (agent-reported, `NOT RE-VERIFIED` line-by-line) |

**Suite verdict: green (408/408) on the repo-declared SDK.** Command 4 (`flutter test` on the PATH SDK) executed **zero tests** — it aborted during dependency resolution.

### C.4 Kotlin JVM — not executed

| Item | Value | Verified how |
|---|---|---|
| Test files | 6 (expected 6) | `find android -path '*src/test*' -name '*.kt' \| wc -l` |
| `@Test` methods | **39** (expected 39) | `grep -rh "@Test" android/app/src/test \| wc -l` |
| Main sources | 21 `.kt`; `androidTest` 0 | file count |
| Suite executed today | **NO** | Gradle prohibited (`phase-9-owner-decision-register.md:101`) |
| Compiled today | **NO** | no `kotlinc`; no permitted runner |
| Result today | **NOT VERIFIED** | — |

---

## D. Failures and Blockers

**D.1 Zero product-code failures.** Every failure in this run was environmental or mechanical. No executed test asserted a wrong product behaviour.

**D.2 Deno run 1 — 11 failures, all one mechanical cause.** `NotCapable: Requires read access to "…", run again with the --allow-read flag`. The failing tests are deliberate source-introspection tests that read sibling handler files; all 11 pass under the repository's own CI form (run 2):

| Test name (verbatim) | Source | Denied read target |
|---|---|---|
| `SQL-03: device-policy and device-command delegate the RPC denial and keep their mappings` | `supabase/functions/_shared/error_mapping_test.ts:351` | `device-policy/index.ts` |
| `SQL-03: pairing maps every RPC error branch it owns before its generic 500` | `error_mapping_test.ts:442` | `pairing/index.ts` |
| `SQL-03: all four affected handlers answer a denial with the same code and shape` | `error_mapping_test.ts:499` | `family-admin/index.ts` |
| `SQL-03: the caller-facing message is fixed text, never database text` | `error_mapping_test.ts:543` | `device-policy/index.ts` |
| `[source-level] delete_zone delegates the delete+audit pair to the atomic RPC` | `supabase/functions/family-admin/delete_zone_atomicity_test.ts:271` | `family-admin/index.ts` |
| `[source-level] the pre-check precedes the RPC and success is returned only after its errors` | `delete_zone_atomicity_test.ts:313` | `family-admin/index.ts` |
| `device-command: the ack path decides enforcement only in enforcement.ts` | `supabase/functions/handler_wiring_test.ts:72` | `device-command/handler.ts` |
| `family-admin: zone delete and purge route through the authorization predicates` | `handler_wiring_test.ts:121` | `family-admin/index.ts` |
| `family-admin: delete_zone sends the zone id and JWT actor to the atomic RPC` | `handler_wiring_test.ts:189` | `family-admin/index.ts` |
| `remote-session: request sweeps abandoned rows and respond uses the guard patches` | `handler_wiring_test.ts:225` | `remote-session/index.ts` |
| `account: delete and retention actions use the extracted modules` | `handler_wiring_test.ts:257` | `account/index.ts` |

**Consequence:** the owner-specified command as literally written is red for a reason unrelated to product quality. The canonical command must be `deno test --allow-read supabase/functions/` (`scripts/local-ci.ps1:208`), or these 11 tests must be recorded as expected-to-fail-without-flags. **No flag was added to any test file; no suppression was introduced.**

**D.3 Flutter PATH-SDK blocker (real, reproducible, unresolved).** Verbatim from `flutter test` (exit 1): `Because parent_control requires SDK version ^3.12.2, version solving failed.` … `Try using the Flutter SDK version: 3.47.9.` … `Failed to update packages.` The machine's `PATH` Flutter (3.38.8 / Dart 3.10.7) cannot resolve this project; the repo pins Flutter 3.44.6 / Dart 3.12.2 through FVM, and that SDK satisfies the constraint. **Any future baseline must invoke `.fvm/flutter_sdk/bin/flutter`, and `--no-pub` must be used because `pubspec.lock` is tracked** (this run left it untouched — G.2).

**D.4 Kotlin suite has no permitted runner (governance contradiction, needs an owner ruling).** `phase-9-owner-decision-register.md:97` marks JVM test execution `PERMITTED (Green)`, but `:101` prohibits `gradlew` / `flutter build` outright, and `./gradlew :app:testDebugUnitTest` is the only supported way to run those 39 tests. A standalone Kotlin compiler is also absent, and even with one, the 21 main sources import `android.app.Service`, `android.os.Build` and `androidx.core.*`, which only the AGP-generated classpath supplies. This is not a defect in the code; it is an unsatisfiable instruction pair that must be resolved by the owner (it is the same ambiguity class as J-2 / Section G item 1 of Phase 9.13).

**D.5 Historical Kotlin evidence is stale, not current.** `.tools/kotlin-tests-2.log` records a past green run (39/39) but its test XML artifacts are no newer than 2026-11-05 11:28, and `.tools/kotlin-tests.log` records an earlier failure in `:flutter_secure_storage:testDebugUnitTest` ("this and base files have different roots", D: vs C: pub cache). Neither is a result of this run; the Kotlin suite's status today remains **NOT VERIFIED**.

---

## E. What Was Written Where

1. **Inside the repository:** nothing by hand. The SQL runner wrote its own log to `.tools/chain_p6chain_20261106_122629.log` (16,352 B, covered by `.gitignore:22 *.log`) and the Flutter runner refreshed `D:\parentcontrol_app\.dart_tool\` internals (already gitignored, `build/` and `.dart_tool/` excluded). Both were produced by the tools themselves, are ignored by Git, and were not cleaned up — cleaning would have meant deleting tool state, which this phase prohibits.
2. **Outside the repository** (`C:\Users\ASUS\AppData\Local\Temp\t-a-01\`): `deno-as-specified.txt` (31,518 B), `deno-as-specified-MAIN.txt`, `deno-documented.txt` (18,619 B), `deno-documented-MAIN.txt` (18,616 B), `sqlchain.txt` (1,138 B), `flutter.txt` (285 B), `flutter-pathsdk.txt` (285 B), `flutter-fvm.txt` (62,812 B), `flutter-fvm-json.txt` (231,994 B).
3. **Local Postgres cluster on port 55581:** left **running** by the runner's own default. It is disposable, bound to `127.0.0.1`, and holds no data (its DB was dropped). Stopping it was not requested; `bash supabase/tests/run_sql_chain.sh --stop-cluster` would do so if the owner wants it closed.

---

## F. Kotlin Verification Limitation (stated plainly)

**Kotlin compilation was NOT performed. The Kotlin JVM test suite was NOT executed. Only read-only source-level compatibility was reviewed.** No result in this report may be read as "Kotlin tests pass".

The source-level review covered the 6 test files against the 21 main sources and reported that all 39 tests' referenced symbols resolve, signatures and arities match, and JUnit4-only imports align with `testImplementation("junit:junit:4.13.2")`. Findings from that review that a compiler would **not** catch:

| Finding | Location | Nature |
|---|---|---|
| Two tests comment that "Dart keys on these strings", but Dart keys on the *event type* and merely interpolates start-failure reason text | `android/app/src/test/kotlin/com/parentcontrol/parent_control/AudioAssistanceSessionWatchdogTest.kt:71`, `AudioAssistanceRecreationTest.kt:91` vs `lib/features/remote_assistance/remote_session_controller.dart:505-517`, `:554-574` | Overstated coupling comment; no runtime breakage proven either way |
| `REASON_SESSION_ENDED_BY_PARENT` has no case in the reason→message switch | `AudioAssistanceService.kt:775` vs `:595-652` | Child likely sees the generic default message for that reason — **candidate real defect**, unverified |
| `wireVocabulary` in the enforcement-mode test matches the schema check constraint | `EnforcementModeTest.kt:20` vs `supabase/migrations/20260101000000_core.sql:101` | Consistent (a genuine guard, not a defect) |

This review method cannot prove compilation, cannot prove the 39 tests pass, and cannot replace `./gradlew :app:testDebugUnitTest`. Recorded command for a future authorized run: `cd D:/parentcontrol_app/android && ./gradlew :app:testDebugUnitTest` — the Gradle 9.1.0 distribution is already extracted under `~/.gradle/wrapper/dists/` with populated `caches/modules-2`, so network access may not be required, but that has **NOT VERIFIED**.

---

## G. No Source Files Were Modified — Confirmation With Evidence

**G.1 Command inventory:** the run contained only test runners, `--version` probes, `grep`/`find`/`sed -n`/`ls`/`stat` reads, and the SQL runner's own disposable-DB lifecycle. No editor, no `Write`, no `sed -i`, no formatter, no codegen was invoked against `lib/`, `test/`, `android/`, `supabase/` or `docs/`.

**G.2 Verification (actual output):**

- `git diff --stat -- pubspec.lock pubspec.yaml` → **empty**; `pubspec.lock` mtime unchanged at `Oct 26 22:40`.
- `git status --porcelain` at the start and end of the run shows the same five entries and nothing else:
  `A  docs/phase9-10-consolidated-release-readiness-governance-blocker-review.md`, `A  docs/phase9-11-…`, `A  docs/phase9-12-owner-decision-packet.md`, `A  docs/phase9-13-final-audit-and-implementation-launch-plan.md`, `A  docs/phase9-9-2-2-documentation-completion-acceptance-record.md`. **No `M`, no `D`, no `AM`, no new `??` other than the report you are reading.**
- Registers untouched: `phase-9-owner-decision-register.md` and `docs/implementation/phase-9-owner-decision-register.md` remain byte-identical at SHA-256 `3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f`.
- No test file was edited, skipped, annotated, renamed or deleted; no `--ignore`/`--filter` flag was used on any suite.

**G.3 One delivery-stage caveat:** this very file (`docs/phase10-local-verification-baseline-report.md`) is the only repository addition, and it is untracked (`??`) — as expected, since committing is prohibited.

---

## H. Out-of-Band Observations and Corrections to Phase 9.13

**H.1 The Git index was written twice by an actor outside these runs.** `.git/index` mtime was `2026-11-06 11:13:20` before this task began, and changed to `2026-11-06 12:18:11` mid-task, during which the Phase 9.13 plan moved from `??` to `A `. No `git add`/`commit`/`reset`/`stash` was issued by this pass, before, during or after (index mtime re-checked at the end of the run and unchanged at `12:18:11`). There are no active hooks and `core.hooksPath` is unset, so the staging came from the owner or another session. **It has been left exactly as found — nothing was unstaged, committed or reverted.** Consequence: J-10 ("fate of the uncommitted governance files") now covers five staged files.

**H.2 Erratum in Phase 9.13, recorded here and NOT edited there.** §B.13 and the §K "verified locally" list state that `android/local.properties` is **NOT FOUND**. It **exists** (178 B, mtime 2026-10-29 17:19, gitignored, holding `sdk.dir` / `flutter.sdk` / `flutter.buildMode` / `flutter.versionName` / `flutter.versionCode`). `key.properties` remains genuinely **NOT FOUND**. Phase 9.13 §F also cites the Gradle/build prohibition at register `:98`; the correct line is `:101` (`:98` is the dashboard-preflight row). Because that document is now staged in the index, editing it would create an `AM` worktree change, which this phase's boundaries prohibit — so the correction lives here, and the owner should fold it into the J-10 commit.

**H.3 Superseded statement (improvement, not error):** Phase 9.13 §B.12 called the "33-File SQL Chain" claim unverifiable. It is now verified and correct (§C.2). Phase 9.13 §E.1 T-A-01 predicted 150 Deno / 387 Flutter / 39 Kotlin; the Flutter figure is the *source case-line* count, while the runtime count is 408 — the baseline number to quote going forward is **408**.

---

## I. Recommendation — First Implementation Task After This Baseline

**Recommended next task: T-B-01 — enforcement-status truthfulness in `supabase/functions/device-command/enforcement.ts` (lines 51-58), plus a negative test in `enforcement_test.ts`.** This is a recommendation, not an authorization.

Why it is the right first move now that the baseline exists:

1. **The safety net is proven, not assumed.** 150 Deno tests and 33 chain files pass at HEAD, so a small TypeScript change lands on a green floor with an immediate regression signal. Before this run, no document could state that.
2. **It is entirely local.** No hosted access, no build, no device — it needs only the Phase 10 local-implementation grant, not DEC-02 or DEC-03.
3. **It is on the critical path of the product claim.** `policyTargetsApps` currently lets a limits-only policy report `enforced` while suspending nothing; DEC-12's screen-time and bedtime work (T-B-02/T-B-03) would inherit that misreporting. Fixing the reporting first means the feature work is measured honestly from its first commit.
4. **Acceptance shape:** a new Deno test asserting that a payload with only `daily_screen_time_limit_minutes`/bedtime yields a status that is **not** `enforced`, and that no `devices.policy_version` advance is implied; existing 150 tests stay green under the canonical `deno test --allow-read supabase/functions/`.

Two items must accompany or precede it, both trivial:

- **Owner ruling that ends the ambiguity:** grant Phase 10 local implementation authority explicitly, and resolve the `:97`-Green-vs-`:101`-prohibited contradiction so "run the JVM tests" is either possible or honestly recorded as impossible (D.4).
- **Record the canonical commands** (`deno test --allow-read …`, `.fvm/flutter_sdk/bin/flutter test --no-pub`, `bash supabase/tests/run_sql_chain.sh`, `./gradlew :app:testDebugUnitTest` **pending build authorization**) wherever CI guidance is kept — otherwise the next baseline repeats run 1's false red and command 4's SDK failure.
- **Then, before any DEC-03 build**, T-B-07 (deterministic versionCode) — with `flutter.versionCode` present in `local.properties` (H.2), the version-pinning fix has a real mechanism and must not be deferred past the first APK, or the new device evidence will be as unreconcilable as build 4005's.

**STOPPED. T-A-01 only. No source file, test, configuration, hosted resource, device or Git state was modified. No Phase 9.14 or further audit cycle was created, and no implementation task was started.**
