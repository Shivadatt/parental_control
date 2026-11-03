# PHASE 4 — regression matrix

Companion to `phase-4-report.md`. Every row states **what was executed and observed**, never what should pass.
Tested tree: `main` @ `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` + the 25-path working-tree digest
`b39d63a5377a9385199ebd9d31737e2f4884eec63b143f905774894c9efcfd11` (basis named in `phase-4-report.md` §2).
All commands were run on 2026-11-03 on this workstation. Evidence files live under `.tools/` (gitignored).
This digest is the **tested** tree; the delivered tree (the four `phase-4-*.md` files plus a 15-line dated
correction in the Android plan) re-measures to `c33bb5e9026c92e5b3d0c290d495db9443a688d0b89be960edb8d270360cc847`
over 29 paths — see `phase-4-report.md` §2a. No suite was re-run for that docs-only delta.

Status labels are the approved set only: **PASS / PASS (SCOPED) / MITIGATED / BLOCKED / NOT RUN / STOPPED /
AWAITING OWNER**.

---

## 1. Authoritative suites (coordinator-owned, run after every edit)

| Suite | Exact command | Exit | Observed | Evidence |
|---|---|---|---|---|
| Dart analyzer | `./.fvm/flutter_sdk/bin/dart analyze` | 0 | `No issues found!` | `.tools/p4f-analyze.log` (`ANALYZE_EXIT=0`) |
| Flutter — full suite | `./.fvm/flutter_sdk/bin/flutter test` | 0 | **`00:33 +396: All tests passed!`** (Phase 3 measured `+390`) | `.tools/p4f-flutter-test.log` (`FLUTTER_TEST_EXIT=0`) |
| Flutter — Phase 4 file alone | `./.fvm/flutter_sdk/bin/flutter test test/features/app_restrictions/policy_read_supersede_test.dart` | 0 | **`+6: All tests passed!`** — the same file that measured 4 failures pre-fix (§2) | `.tools/p4f-single-test.log` (`SINGLE_EXIT=0`) |
| Flutter — touched feature subset | `./.fvm/flutter_sdk/bin/flutter test test/features/app_restrictions` | 0 | **`00:13 +49: All tests passed!`** (Phase 3 ENF-01 correlation tests still inside the set) | console capture |
| Deno — all functions | `deno test --allow-read supabase/functions/` | 0 | **`ok \| 109 passed \| 0 failed (3s)`** — byte-equal count to Phase 3; Phase 4 added **no** Deno test | `.tools/p4f-deno.log` (`DENO_EXIT=0`) |
| Kotlin/JVM — unit tests (KOT-01) | `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` (cwd `android/`) | 0 | **35 tests, 0 failures, 0 errors, 0 skipped** across 5 classes; 182 tasks executed; 5 fresh JUnit XML files, `timestamp="2026-11-03T05:36:52Z"` | `.tools/p4b-gradle-coordinator.log`; `build/app/test-results/testDebugUnitTest/*.xml` |
| SQL — documented chain (31 files) | `psql -v ON_ERROR_STOP=1 -f …` over the 31 `-f` files listed at `supabase/tests/README.md:31-64`, `-d` last, on fresh DB `p4_final_chain` (cluster `.tools/pgdata_p4f`, port **55471**) | **0** | 604-line log; `grep -c 'ASSERTION FAILED'` = **0**; `grep -c 'ERROR'` = **0**; per-file banners `:478 :480 :482 :484 :486 :550 :565 :598 :601`; `tests/75` NOTICE ×2 | `.tools/p4f-chain.log` (`CHAIN_EXIT=0`) |
| SQL — chain validity criterion | `select count(*) from information_schema.tables where table_schema='public'` after the chain | 0 | **19** public tables (criterion at `README.md:104`); `webrtc_signals_session_sequence_uniq` present; **66** indexes | console capture |
| SQL — chain repeatability | The same 31-file chain run a second time on a *different* fresh DB (agent A at 09:16, coordinator at 11:39) | 0 | `cmp` of the two logs differs **only** in generated UUIDs/timestamps (4 lines) — the chain is order-stable and repeatable | `.tools/p4a-chain.log` vs `.tools/p4f-chain.log`, `diff` printed |

Init/stop of the verification cluster: `initdb` exit 0 (`.tools/p4f-initdb.log`), `pg_ctl start` exit 0
(`.tools/p4f-pgctl.log`), `pg_ctl stop` exit 0 (`.tools/p4f-pgctl-stop.log`) with `pg_isready` then returning
exit 2 (no listener). `pgdata_p4f` directory kept; `pgdata_p2`, `pgdata_p3a`, `pgdata_p3b` untouched.

Deltas are measurements, not expectations: **Flutter +390 → +396** (6 new, one file), **chain 30 → 31**
`-f` files (`75` added), **Deno 109 → 109**, **Gradle “never executed” → 35/0/0** (first real run).

### 1a. Gradle class-by-class (the KOT-01 evidence, read out of the XML rather than summarised)

| Class | tests | skipped | failures | errors |
|---|---|---|---|---|
| `AudioAssistanceRecreationTest` | 8 | 0 | 0 | 0 |
| `AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 | 0 |
| `AudioAssistanceStartGateTest` | 4 | 0 | 0 | 0 |
| `AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 | 0 |
| `policy.PolicyEvaluatorTest` | 13 | 0 | 0 | 0 |
| **Total** | **35** | **0** | **0** | **0** |

Summed with `awk -F'"' '{s[$1]+=$2} END …'` over the five XML `testsuite` attributes (`bc` is not available in
this Git Bash). Warnings emitted by the build are disclosed in `_work/p4-kotlin.md`; `ANDROID_HOME` was empty in
this shell and did not block `testDebugUnitTest` — recorded as observed.

---

## 2. Negative controls actually measured (a green suite proves nothing unless red is reachable)

| Control | Command / artifact | Observed |
|---|---|---|
| Workstream C fix is **not** a tautology | `flutter test test/features/app_restrictions/policy_read_supersede_test.dart` executed against the **pre-fix** controller (`git show HEAD:…` copy) | **4 of the 6 tests fail**: `Expected: <7> Actual: <6>`, `Expected: null Actual: AppException(unknown)`, `Expected: null Actual: Instance of 'PolicyEnforcementReport'`, `Expected: null Actual: Instance of 'PolicyEnforcementEvidence'` — `.tools/p4c-prefix-failures.log` |
| `tests/75` guard is not vacuous | duplicate-bearing disposable DB: insert 2 rows with the same `(session_id, sequence)` **before** applying `20261030000200` | migration applies **quietly** with NOTICE ×1, the unique index stays **ABSENT**, and the duplicate rows are **never deleted** — `.tools/p4a-duplicate-probe.log`, `.tools/p4a-duplicate-probe.sh` |
| The disagreement it fixes was real | `tests/70` and `tests/71` run against that same duplicate DB | `70` exits **0** either way (it mirrors the migration's condition); `71` exits **3** at its unguarded index assertion — the red-suite state is demonstrated, not argued |
| DOC-01 negative control preserved | `deno test supabase/functions/` (flagless) | still `FAILED \| 83 passed \| 5 failed` — the recorded Phase 2 control is kept and re-confirmed; the flagged run is `109 passed \| 0 failed` — `.tools/p4a-deno-flagless.log`, `.tools/p4a-deno-flagged.log` |
| PERF-01 arms really executed | `EXPLAIN (ANALYZE, BUFFERS)` inside the equivalence run | webrtc SHIPPED shows `Seq Scan on webrtc_signals` (75.534 ms) vs ALT `Index Scan using w_ship_2_id` (48.429 ms); audit SHIPPED 83.229 ms vs ALT 38.112 ms — the plans differ, which is what makes the identical digests meaningful | `.tools/p4d-equiv.log` §8–§9 |

---

## 3. Requirement-level matrix

| Brief item | Delivered in Phase 4 | Verification executed for it | Status | Evidence |
|---|---|---|---|---|
| **DOC-01** — documented command must carry `--allow-read`, negative control preserved, conflicting commands swept | `regression-matrix.md:24` corrected; 13 phase/audit docs received **appended dated annotations** naming the flag and the reason (`_shared/` gained file-reading tests in Phase 3); historical numbers left untouched | flagless-vs-flagged both re-executed (row above); sweep re-verified by `grep -rn 'deno test' docs` with every remaining flagless hit inside a dated annotation | **PASS** | `.tools/p4a-deno-{flagless,flagged}.log`, staged doc diff, `_work/p4-docs-sql06.md` |
| **SQL-06** — index must not be described as preventing new-sequence replay; correction only inside authorized docs scope | Proposed `api-contract.md:222-224` re-wording written out, **not applied** — contract wording is owner-gated | Read of `core.sql:366-370` (`sequence` is `ALWAYS IDENTITY`), `20261030000200:472-495`, `tests/70:436-451`; client dedupe at `remote_session_controller.dart:911-914` | **AWAITING OWNER** (proposal ready) | `_work/p4-docs-sql06.md` §3 |
| **SQL-06a** — resolve the migration/`70`/`71` disagreement; add a guard that reflects real migration behaviour; keep the mandatory pre-apply duplicate check; don't weaken a test for green | New in-chain `supabase/tests/75_signaling_replay_index_duplicate_guard.sql` (218 lines) asserting: duplicates present → index ABSENT + NOTICE, duplicates **not** silently purged, pre-check query returns the offending groups; `71` left untouched (its unguarded assertion is the honest tripwire, now documented in-chain); chain docs 30 → 31 | `75` green inside the full 31-file chain (exit 0, 0 ASSERTION FAILED, NOTICE ×2 at `:598`/`:601`) **and** red-reachable in isolation on a clean DB where its own fixture is missing; validated on the duplicate DB by `p4a-duplicate-probe` | **PASS (SCOPED)** — guard verified on disposable local PostgreSQL only; hosted apply is an owner act | `.tools/p4f-chain.log`, `.tools/p4a-chain.log`, `.tools/p4a-duplicate-probe.log` |
| **KOT-01** — re-run the JVM tests, capture command/exit/XML/counts/env; don't claim success if Gradle didn't execute | Evidence table (cwd, env, exit, task count, 5 XML files with fresh timestamps) | **Gradle genuinely executed**: `182 actionable tasks: 182 executed`, `--rerun-tasks` forced re-execution, XML `timestamp` = the run minute, and 35 counted from the XML rather than from the console | **PASS** | `.tools/p4b-gradle-coordinator.log`, `build/app/test-results/testDebugUnitTest/*.xml`, `_work/p4-kotlin.md` §1 |
| **KOT-02** — consolidate the duplicated `enforcementMode()` only **after** coverage exists | **Code left unchanged**, per the brief's own fallback clause; the prerequisite is proven unreachable, not merely inconvenient | `android/app/build.gradle.kts:93` shows `testImplementation` = `junit:4.13.2` only — no Robolectric, no Mockito, no `testOptions`; both helper bodies (`PolicyApplier.kt:229-233`, `GuardianService.kt:668-674`) read `DevicePolicyManager`/`isAdminActive`, which is not instantiable on the JVM; equivalence established **by inspection** (same two predicates, `:283-289` and `:291-297`); `git diff HEAD --stat -- android/` is **empty** | **BLOCKED** (4 owner options recorded; recommendation = extract pure `EnforcementMode.of(isDeviceOwner, isAdminActive)`) | `_work/p4-kotlin.md` §2 |
| **Workstream C** — superseded read must not display an older policy; use the existing generation strategy; deterministic tests; `payload.policy_id` rule untouched | `app_restrictions_controller.dart` +103/−25: `_policyRequest` / `_reportRequest` generation tokens, `_isClosed`, version-monotonic `_publishPolicy`, `_showPolicy` invalidates `enforcementEvidence` when the policy identity changes, `_stillShows(policy)` re-check at the single publish point | 6 deterministic tests (no network, no timers, fixed dates) covering: late older-policy success, late failure, policy switch mid-pending, evidence for the displayed policy still publishes, read landing after disposal writes nothing, and a genuinely newer policy from a superseded read still publishing. **Measured red pre-fix (4 of 6).** Full suite green at +396; subset green at +49. `payload.policy_id` correlation rule untouched — verified in the diff | **PASS (SCOPED)** — Dart-level read-ordering only; no device or backend round-trip is claimed | `.tools/p4c-prefix-failures.log`, `test/features/app_restrictions/policy_read_supersede_test.dart`, `_work/p4-enf-residual.md` |
| **PERF-01** — reproduce the seq-scan, evaluate the alternative shape, compare exact rows selected/deleted, batch ordering, repeatability, plans; don't adopt if correctness isn't demonstrable | Measured equivalence; **migration `20261030000300_retention_sweep.sql` unchanged** (byte-identical to HEAD); the two replacement statements delivered as `proposals/phase4-retention-sweep-batch-shape.sql` with 4 adoption blockers | 4 arms (2 shapes × 2 tables) × 2 reps on per-arm `CREATE TABLE AS` copies that are byte-identical in heap order and `ANALYZE`d identically: **one distinct `dig_set`, `dig_returning_order` and `dig_ctid_visit_order` per table across all 8 rows** (audit `3cedf66f…`/`34c0de5b…`/`0c6755ba…`; webrtc `e1f191b6…`/`2f34ec5b…`/`4be87823…`); 12 pairwise set/order diffs all **0 / 0**; positional join **10000 same-position pairs / 0 mismatches**; population before == after (webrtc 140006→60000, audit 200026→25000); 10000 rows deleted per arm | **PASS (SCOPED) — equivalence demonstrated; adoption STOPPED (owner-only)** | `.tools/p4d_equiv.sql`, `.tools/p4d-equiv.log` (318 lines, exit 0), `.tools/p4d_equiv_order.sql`, `.tools/p4d-equiv-order.log`, `_work/p4-perf01.md` |
| **TEST-01** — document exact handler export + DI changes, files and owners; if not authorized leave handlers unchanged; distinguish source-level from executed tests | **All 9 Edge Function handlers untouched** (`git diff HEAD -- supabase/functions` empty apart from nothing). `_work/p4-test01.md` gives the 6-step sequenced proposal (`handler.ts` split, `HandlerDeps { db, audit, now, uuid }` + `defaultDeps()`, a ~150-line `fake_postgrest.ts` sized to the measured builder/await surface, per-risk executed tests, pin-retirement rule, verification) and the ownership/cost table (4–6 engineer-days, `device-command` first) | The 5 existing `handler_wiring_test.ts` pins re-run (109/0 with them included) and **each pin's exact claim enumerated** with line citations, together with 4 explicit "NOT proven" points: no handler was executed; `assertOrder` is lexical not temporal; occurrence counts are textual; whitespace is collapsed by `normalize()` | **NOT RUN** as implementation → **STOPPED (implementation unauthorised)**; deliverable = sequenced proposal, **AWAITING OWNER** | `supabase/functions/handler_wiring_test.ts`, `_shared/auth.ts:45-65` (`let cachedClient`, `getServiceClient()`), `device-command/index.ts:107` (bare `Deno.serve`), `_work/p4-test01.md` |
| **Workstream F** — Android validation matrix; no APK install, no device execution, no build; each row needs preconditions/steps/expected/blank actual/evidence/status; never bypass a privacy control | `phase-4-android-validation-plan.md` (467 lines): §A–§I covering all ten brief-listed areas, preflight checklist, privacy/safety invariants section, row-count summary, §6 rows **BLOCKED today** even after authorization, §7 advisory execution order | **Nothing executed on a device.** Every *Actual result* field is blank by design and every *Status* is `NOT RUN`; the plan's §8 lists the `file:line` sources it was built from and refuses to assert prior-phase device behaviour as verified | **NOT RUN** (execution needs explicit authorization; build remains the build owner's) | `docs/implementation/phase-4-android-validation-plan.md` |
| **HOST gate** — read-only re-checks of authenticated DELETE on `safe_zones`, `safe_zones_delete_parent`, migration provenance/tracking, `account` Edge Function + cron; record timestamp/observation/evidence; no fix | `_work/p4-hosted.md` (88 lines) + `.tools/p4g-probe-observations.txt`; 14-row Phase 3 (2026-11-02) vs Phase 4 (2026-11-03) comparison table | Two `SELECT`-only probes (13 rows + 7 rows, read out of the DOM because the grid virtualises), the Edge Functions inventory (9 functions; `account` shows **0 deployments** with created/updated stamps) and the cron page (no job), plus a **new decisive provenance probe**: `prosrc like '%is_parent_of_family%'` → **NONE**. All 14 observations **unchanged** from Phase 3 | **PASS (SCOPED)** as a re-check; the gate itself is **BLOCKED** — **HOST-01 remains a deployment blocker** | `_work/p4-hosted.md`, `.tools/p4g-probe-observations.txt`, `.tools/p4g-00-overview.png` |
| **§9 OWNER-ONLY register** | `phase-4-owner-approval-register.md`: 8 rows with decision, options, consequences, recommendation, files, status | Analysis only; **no** test executed (correct — nothing changed behaviour) | **AWAITING OWNER** ×8 | that file |
| **§12 final verification** | §1 above | all five suites re-run after the last edit, state re-measured, digest computed | **PASS** | `.tools/p4f-*.log`, `.tools/p4-end-status.txt`, `.tools/p4-digest-perfile.txt` |

---

## 4. Explicitly **not** run, and why

| Item | Status | Reason |
|---|---|---|
| Any physical-device or emulator row of §A–§I | **NOT RUN** | Brief §8 forbids execution without explicit authorization; none exists. |
| Any `flutter build apk` / `gradlew assemble*` | **NOT RUN** | Build ownership stays with the build owner (project rule); only `:app:testDebugUnitTest` was invoked, because KOT-01 names it. |
| Migration apply, function deploy, cron install, dashboard write | **NOT RUN** | This is not a deployment phase (brief §1); every hosted statement issued was `SELECT`. |
| Adoption of the faster sweep batch shape | **STOPPED** | Batch semantics are proven equivalent, but the change touches a lifecycle-owned migration + the `tests/74` `%10000%` tripwire and needs an owner ruling. |
| `create procedure` / `COMMIT` / RPC signature change for bounded execution | **NOT RUN** | SQL-04 remains owner-gated from Phase 3; `tests/74` §4e (`:408-417`) already trips if a `commit` appears without approval. |
| `tests/71` modification | **NOT RUN** | `71:194-197` is the honest tripwire for the duplicate case; weakening it would be exactly the "don't weaken a test to get green" prohibition. |
| Handler export/DI refactor | **STOPPED** | TEST-01 implementation is unauthorised; a 4-handler refactor across 4 Phase 1 owners is scheduled as a proposal instead. |
| Kotlin helper consolidation | **BLOCKED** | Coverage prerequisite unreachable with this module's test stack. |
| `git add` / commit / branch / push by the coordinator | **NOT RUN** | Owner-only. The 15 staged entries pre-date/parallel the coordinator's edits and are reported as observed, not attributed. |
| Supabase CLI | **NOT RUN** | Never invoked; binary presence recorded in `.tools/p4-preflight.txt`. |
| `location_events` / `usage_daily` sweep arms | **NOT RUN** | PERF-01 measured only the two tables where the seq-scan was reproduced; extending the claim to the other sweep targets would be an unproven generalisation. |

---

## 5. Regression claims that would be **over-claims** (stated so they cannot be mis-read later)

- 396 Flutter tests green does **not** mean the device behaves correctly — no device test was run.
- 109 Deno tests green does **not** mean a handler executes correctly — §3/TEST-01 says they are source-level pins.
- Chain exit 0 does **not** mean the hosted database is in that state; hosted is entirely pre-Phase-1 (`_work/p4-hosted.md` §3 proves the presence of some functions is not partial application, because they are `create or replace` targets).
- PERF-01's identical digests do **not** prove the hosted planner chooses the same shape — copies are static, `work_mem`/statistics differ, and the crossover volume was not found.
- KOT-01's 35/0/0 does **not** mean `PolicyApplier`/`GuardianService` are covered — neither is reachable from the JVM test source set; the 5 green classes are audio-lifecycle and `PolicyEvaluator`.
- The two identical chain runs do **not** prove migration idempotence across re-applies on a *populated* database; fixtures use fixed UUIDs and are not re-runnable (`README.md:28-29`).
