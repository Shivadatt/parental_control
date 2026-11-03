# PHASE 5 — regression matrix

Companion to `phase-5-report.md`; same status vocabulary. Every executed row names
the log that produced it. Nothing in the **NOT RUN** column is described anywhere in
this phase as passing.

Branch `main`, HEAD `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d`, no commit made.
The tested tree is the working tree. Two digests describe it and they are not the
same thing: `docs/evidence/phase5/tree-digest.txt` (57 paths) is the tree the
suites below executed against, and `tree-digest-final.txt` (69 paths) is the tree
this phase delivers — the difference is evidence-pack and documentation bytes, not
code. Basis and exclusions: `phase-5-report.md` §2 and §2a.

---

## 1. Authoritative suites (coordinator-owned, run after every edit)

| # | Suite / command (exact) | Exit | Observed result | What it covers | Artifact |
|---|---|---|---|---|---|
| S1 | `./.fvm/flutter_sdk/bin/dart analyze` | 0 | `No issues found!` | whole `lib/` + `test/` tree, incl. the PRIV-01 UI scope types | `.tools/p5-coord-dart-analyze-run2.log` |
| S2 | `./.fvm/flutter_sdk/bin/flutter test` | 0 | `00:30 +408: All tests passed!` | all Flutter suites, incl. the 11 new retention-disclosure cases and 7 account-privacy controller cases | `.tools/p5-coord-flutter-run2.log` |
| S3 | `deno test --allow-read supabase/functions/` | 0 | `ok \| 150 passed \| 0 failed` | every Edge Function suite: `account/scope_test.ts` 17, `device-command/handler_test.ts` 24, `_shared/error_mapping_test.ts` 13, `family-admin/delete_zone_atomicity_test.ts` 8, `handler_wiring_test.ts` 5, plus the 83 pre-existing | `.tools/p5-coord-deno-full3.txt`; re-run after mutation restore `.tools/p5-coord-deno-restored.log` |
| S4 | `deno test --allow-read supabase/functions/family-admin supabase/functions/handler_wiring_test.ts` | 0 | `ok \| 17 passed \| 0 failed` | SQL-05 handler surface + wiring pins in isolation | `.tools/p5-coord-deno-sql05.log` |
| S5 | `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` (cwd `android/`) | 0 | `BUILD SUCCESSFUL in 50s`, `182 actionable tasks: 182 executed` | all JVM unit tests, incl. the 4 new `EnforcementModeTest` cases | `.tools/p5-coord-gradle-run1.log` + 6 XML in `docs/evidence/phase5/gradle-junit/` |
| S6 | `bash .tools/p5coord_chain.sh p5rpc_full9 <log>` on a disposable PG 16.9 cluster (port 55581), fresh DB; the documented chain = **33 `-f`** files (14 migrations + 19 tests) with `ON_ERROR_STOP=1` | 0 | `CHAIN p5rpc_full9 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0`; resulting DB has 19 public tables / 66 public indexes | every SQL suite incl. `74` (with §5 now executing), `75`, `76`, and all pre-existing RLS/function/concurrency tests | `docs/evidence/phase5/logs/p5coord-chain-run9.log` |
| S6b | `PGPORT=55581 bash .tools/p5coord_chain.sh p5rpc_final1 <log>` — same 33-file chain, **fresh database**, re-run as the closing action of the phase after the SQL-05 citation fix and all doc corrections | 0 | `CHAIN p5rpc_final1 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0` | final bytes of the executed migration/test set | `docs/evidence/phase5/logs/p5coord-chain-run10.log` (detail §1a) |
| S7 | repeat of S6 into a second fresh database (idempotency of the chain itself, not of the sweep) | 0 | 646-line log, `ASSERT_FAILED=0 ERRORS=0` | chain is deterministic given a fresh DB | `logs/p5coord-chain-run6.log` |

### 1a. Final chain re-run (closing measurement, executed after every file of the phase existed)
| Item | Value (measured) |
|---|---|
| Command | `PGPORT=55581 bash .tools/p5coord_chain.sh p5rpc_final1 docs/evidence/phase5/logs/p5coord-chain-run10.log` |
| Harness exit | 0 |
| Result line | `CHAIN p5rpc_final1 PRE76=<none> EXIT=0 FILES=33 LINES=648 ASSERT_FAILED=0 ERRORS=0` |
| Pass NOTICEs | `74…:934 ALL SWEEP INDEX AND REPEATABILITY TESTS PASSED`, `75…:185` and `75…:216`, `76…:773 ALL ZONE DELETE ATOMIC RPC TESTS PASSED`, `71…:605` |
| Catalog re-check on `p5rpc_final1` | 19 public tables, 66 public indexes, `webrtc_signals_session_sequence_uniq` present (count 1) |
| RPC privileges on `p5rpc_final1` | `delete_safe_zone_audited(uuid,uuid) \| jsonb \| secdef=true \| cfg=search_path=public, private, pg_temp \| anon=false \| authed=false \| srv=true \| acl={postgres=X/postgres,service_role=X/postgres}` |

Why this run exists: between run9 and the delivery, two things changed in files the
chain actually executes — the SQL-05 header citation fix (EV-02) and the
manifest/doc corrections. Both are comments or docs outside the executed set, but
"comments cannot change behaviour" is an argument, not a measurement, so the chain
was re-run against the final bytes. Identical counts to run9 (648 lines, 0 asserts
failed, 0 errors) on a fresh database — also a repeat of the whole 33-file chain,
third time on this tree.

### 1b. Gradle class-by-class, read out of the XML rather than summarised

| Class | tests | failures | errors | skipped |
|---|---|---|---|---|
| `AudioAssistanceRecreationTest` | 8 | 0 | 0 | 0 |
| `AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 | 0 |
| `AudioAssistanceStartGateTest` | 4 | 0 | 0 | 0 |
| `AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 | 0 |
| `EnforcementModeTest` (**new, KOT-02**) | 4 | 0 | 0 | 0 |
| `policy.PolicyEvaluatorTest` | 13 | 0 | 0 | 0 |
| **total** | **39** | **0** | **0** | **0** |

`build/app/test-results/testDebugUnitTest/` is where Gradle puts these for this
project; `android/app/build/test-results/` is empty and is not the location to
check.

---

## 2. Negative controls actually measured

| ID | Mutation | Suite | Expected red | Observed |
|---|---|---|---|---|
| N1 | `await assertFamilyParent(…)` commented out at `supabase/functions/_shared/auth.ts:270` | S3, narrowed to `device-command/handler_test.ts` | the two authorization cases fail | `FAILED \| 22 passed \| 2 failed`, exactly `handler_test.ts:219` (cross-family, nothing written) and `:239` (soft-deleted family forbidden before the membership read). Log `logs/p5-coord-deno-negative.log`. File restored byte-identical; S3 re-run green. |
| N2 | `delete_safe_zone_audited` body replaced with a lossy variant that lets the audit insert fail independently, injected **immediately before `tests/76`** | S6 | `tests/76` audit-atomicity assertion fails | `EXIT=3`, `ASSERT_FAILED=1` at `supabase/tests/76_zone_delete_atomic_rpc.sql:411` — `ASSERTION FAILED (SQL-05: the audit failure must abort the whole RPC): expected error, statement succeeded`. Log `logs/p5coord-chain-negative3.log`. |
| N2-failed-first-attempt | same variant passed as the chain's *migration argument* instead | S6 | — | **came back EXIT=0 green.** Cause: `tests/71` §5 re-forwards the real migration, overwriting the variant before `tests/76` ran. Disclosed because it is the mechanism by which a false PASS was almost recorded; the harness was changed and N2 re-measured red. |
| N3 | pre-existing pin kept honest: `tests/74` §5 runs against both batch shapes and captures deleted row ids | S6 | if the shipped shape diverged, the row-set/order assertions fail | not mutated this phase; instead §5 was found **never to have executed** (NOTICE at `:440` of a 934-line file) and its two syntax errors were fixed, so the assertion is now live rather than decorative. |

---

## 3. Requirement-level matrix

Legend — **I** implemented, **T** tested in this phase, **B** blocked, **S** stopped
by refusal, **A** awaiting owner, **U** unapplied (locally tested only).

| Brief item | Requirement | I | T | Status today | Evidence / pointer |
|---|---|---|---|---|---|
| PRIV-01 (A) | child/device-scoped counts, explicit `scope` | ✔ | ✔ S3 | **IMPLEMENTED, TESTED — UNAPPLIED** | `account/retention.ts`, `account/scope_test.ts` (17 named cases in `phase-5-report.md` §5a) |
| PRIV-01 | no global sweep totals in non-owner responses | ✔ | ✔ S3 | same | `payload: a non-owner parent keeps the timestamp but loses the totals`, `payload: the family owner alone receives the project-wide sweep totals` |
| PRIV-01 | WORD-02 three-state scope in UI, disclosure test | ✔ | ✔ S2 | same | `retention_scope_disclosure_test.dart` 11 cases incl. `not_reported`, "no report yet", no-family-linked |
| PRIV-01 | service-role access kept server-side | ✔ | ✔ S3 | same | no new client-visible surface; the RPC/counts path is service-role only |
| SQL-05 (approved) | reviewed migration, atomic delete+audit | ✔ | ✔ S6 | **IMPLEMENTED, TESTED — UNAPPLIED** | `20261103000100:141` `create or replace`, `:256-259` revoke/grant, `tests/76` 773 lines |
| SQL-05 | preserve trusted actor attribution | ✔ | ✔ S6, S3 | same | actor is a parameter from `auth.ts:80-127`; never `request.jwt.claim.sub`; `is_parent_of_family` at `20261030000200:186-206` |
| SQL-05 | zero-row + authorization-failure + audit-failure cases executable | ✔ | ✔ S6 | same | `tests/76` + measured red via N2 |
| SQL-05 | `family-admin` handler switch + wiring tests | ✔ | ✔ S4 | same | `family-admin/index.ts:214-262`, `handler_wiring_test.ts` |
| SQL-05 | RPC grants verified | ✔ | ✔ S6 | same | measured `proacl {postgres=X/postgres, service_role=X/postgres}`, `anon_execute=f`, `authenticated_execute=f` |
| PERF-01a (approved) | faster DELETE shape | ✔ | ✔ S6 | **IMPLEMENTED, TESTED — UNAPPLIED** | `20261030000300` `id = any (array(select … limit v_batch))` on `webrtc_signals` + `audit_logs` |
| PERF-01a | correct SWP-01 comment | ✔ | n/a (doc) | **DONE** | comment now names the measured Seq-Scan numbers and their provenance |
| PERF-01a | behavioural deleted-row-set assertions, order + repeatability | ✔ | ✔ S6 | **DONE — and now actually executing** | `tests/74` §5, `p574_cap`, NOTICE at `:934` |
| SQL-04 | bounded execution / partial commit | ✖ | ✖ | **STOPPED — owner refused** | function unchanged in that respect; migration comment states one call = one transaction |
| SQL-04 | cron installation | ✖ | ✖ | **STOPPED — not authorised** | nothing installed locally or hosted |
| TEST-01 | six-step refactor, explicit DI | ✔ | ✔ S3 | **IMPLEMENTED, TESTED** | `device-command/handler.ts` 449 lines, `_shared/fake_postgrest.ts` 643 lines |
| TEST-01 | real handler tests, no env-flag shortcuts | ✔ | ✔ S3 | same | 24 cases; red-reachable via N1 |
| TEST-01 | preserve authorization + response envelope | ✔ | ✔ S3, S4 | same | `handler_wiring_test.ts` pins the adapter, not a parallel copy |
| GOV-02 | ratify pair as-is | n/a | consumer check only | **RATIFIED — no code change** | `ended_by`/`ended_reason` consumers listed in `phase-5-owner-decision-log.md` §5 |
| SQL-01/R3 | never sanctioned | ✖ | ✖ | **STOPPED, quarantined** | none executed, none executed against hosted data |
| SQL-06 | approved wording applied | ✔ | ✔ (citation re-verification) | **DONE** | `api-contract.md` §5 + dated note |
| SQL-06 | duplicate pre-check preserved | ✔ | ✔ S6 | **DONE** | `tests/75` kept, two NOTICEs at `:185` and `:216`; `20261030000200:478-486`/`:492` re-read |
| KOT-02 (A) | pure `EnforcementMode.of` + JVM tests + both call sites | ✔ | ✔ S5 | **IMPLEMENTED, TESTED** | `EnforcementMode.kt`, `PolicyApplier.kt:228-234`, `GuardianService.kt:668-670` (call site `:503`), 4 tests |
| KOT-02 (B) | Robolectric/Mockito | ✖ | ✖ | **NOT AUTHORISED — not added** | `android/app/build.gradle.kts` unchanged |
| EVD-01 | Gradle XML + logs + digests + commands | ✔ | n/a | **PREPARED — NOT COMMITTED** | `docs/evidence/phase5/` (18 files, each hashed) |
| EVD-01 | commit the evidence | ✖ | ✖ | **BLOCKED by the no-commit ruling** (conflict disclosed) | `phase-5-owner-decision-log.md` §12 |
| Gate B / AND-01 | device execution | ✖ | ✖ | **STOPPED — owner declined** | §4 below; no device row PASSes |
| Gate A git action | commit / push / branch | ✖ | ✖ | **STOPPED — owner ruled no commit** | HEAD unchanged |
| HOST-01 | hosted migration applied + verified read-only | ✖ | ✖ | **BLOCKED / OPEN — P1 blocker, NOT fixed** | needs owner dashboard action; see `phase-5-deployment-readiness.md` |

---

## 4. Explicitly **not** run, and why

| Row | Why not | What would be needed |
|---|---|---|
| Any Android device behaviour (force-stop, recents-swipe, permission revocation, notification visibility, child consent, mic foreground/background/lock) | Gate B refused by the owner; §11 of the brief forbids marking a device row PASS without captured evidence | AND-01 authorization + a paired QA parent/child device pair |
| APK build for validation | follows Gate B; not built | same |
| Any hosted SQL execution | §12 prohibition | owner applies via dashboard, then read-only verification |
| Any Edge Function deploy / Supabase setting change / cron install | §12 + "no cron unless separately authorized" | owner authorization per action |
| Real planner timings for the sweep shape on the hosted instance | no hosted access; the numbers quoted in the migration comment are from a disposable PG 16 A/B probe, and the comment says so | post-apply `EXPLAIN (ANALYZE, BUFFERS)` by the owner |
| `tests/74` §5 behavioural assertions **before** this phase | they could not have run — the file "passed" while its NOTICE pointed at line 440 of a 934-line file | fixed; now green (S6) |
| `run_retention_sweep()` against a real backlog | no hosted data, and bounded execution was refused | owner decision on SQL-04 |
| Device-command Edge Function against a live project | undeployed | owner deployment |

---

## 5. Regression claims that would be **over-claims**

Stated so they cannot be mis-read later. None of these is asserted by Phase 5:

1. **"the sweep is now fast on production"** — no. The shipped shape is asserted to
   delete the same rows in the same order, repeatably, on a disposable database.
   Production plan/timing is unmeasured and the function is still one transaction
   per call.
2. **"zone deletion is atomic in production"** — no. `delete_safe_zone_audited` has
   never been applied. Until it is, the hosted `delete_zone` path (if the currently
   deployed function predates this handler change) still has the two-transaction
   window. **HOST-01 stays open.**
3. **"the replay-protection index exists"** — unverified. `webrtc_signals_session_sequence_uniq`
   is created conditionally; the pre-apply duplicate count has never been run on
   hosted data.
4. **"the retention disclosure is correct on a phone"** — the widget tests are
   `flutter_test` render assertions, not device behaviour.
5. **"408 Flutter tests cover the new scope"** — the 408 is the whole suite; the new
   PRIV-01 cases are 11 (disclosure) + 7 (controller) + 6 (supersede, Phase 4).
6. **"150 Deno tests pass on the deployed code"** — they pass on the working tree;
   none of this code is deployed.
7. **"Phase 4's delivered digest was wrong"** — narrower and measured: 2 of its 29
   paths were hashed before their final write (§1a of the report); the published
   aggregate does reproduce from its own per-file table, and the suspicion that it
   was fabricated is withdrawn.
8. **"the audit-failure path is reachable from the app"** — since the RPC switch,
   `audit_failed` / `zone_restored` / `delete_unaudited` are unreachable from the
   `delete_zone` UI path; the Deno tests that document a command row surviving an
   `audit_failed` 500 exercise the extracted handler's dependency seams, not the
   live zone path.
9. **"nothing else changed"** — the index moved on its own twice (IDE auto-staging);
   disclosed, not explained, in `phase-5-report.md` §2.
