# P3-F — Phase 2 follow-up triage (analysis only)

Workstream **P3-F** (documentation-only). Baseline `main` @ `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2`;
Phase 2's 47 uncommitted files untouched; **this workstream changed no source, migration, test or
config file and executed no test, build, CLI or hosted call.** Every statement is a read of the
working tree; nothing here is evidence that a hosted system behaves this way — `account` is
undeployed and migrations `20261030000100` / `20261030000200` / `20261030000300` are unapplied
(`docs/implementation/phase-2-open-gaps.md:13-14`).

PRIV-01 and GOV-02 are in `docs/implementation/_work/p3-privacy-decisions.md`.

## 1. Disposition table

| ID | Verified current state (short) | Disposition | Owner decision needed? |
|---|---|---|---|
| TEST-01 | Still open, unchanged. `supabase/functions/handler_wiring_test.ts:1-14` still states the reason: handlers are bare `Deno.serve(...)` with no export and build a service-role client internally (`:72`, `:107`, `:163`, `:175`, `:203`, `:235` read six source files). Only `remote-session/lifecycle_test.ts` is dependency-injected (`:138`, `:180` pass an injected `rpc`) | **Still open — needs a cross-ownership export-first refactor; deliberately not attempted in Phase 3 while four workstreams edit the same tree** | Yes, but only to approve the ownership change (`coordinator-contract.md:124-128`), not the design |
| SQL-06 | Still open as a *deployment pre-check*; the underlying claim is weaker than filed and the contract wording is stronger than true (see §3) | **Re-scope: pre-check + wording. No code fix needed** | Yes — approve re-labelling `api-contract.md:223`, and run the hosted duplicate pre-check before apply |
| WORD-01 | **CLOSED in Phase 3 by workstream P3-D.** Header now reads `'Apps the device could not confirm as suspended'` (`lib/features/app_restrictions/app_restrictions_page.dart:373`) and the model doc comment was softened in the same spirit (`lib/data/models/policy_enforcement.dart:3-6`); the Kotlin reason is unchanged (`android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:151`). Three tests pin the new string: `test/features/app_restrictions/app_restrictions_page_test.dart:282`, `enforcement_correlation_page_test.dart:168` and `:207` | **Closed — no action** | No |
| WORD-02 | Still open. `lib/features/settings/account_privacy_repository.dart:41-42` is a strict `== 'child'` boolean, so an absent/unknown role falls to the family-scoped sentence at `lib/features/settings/export_result_dialog.dart:79-82` | **Still open — fix together with the PRIV-01 UI change** (`p3-privacy-decisions.md` §1.5) | No (yes, if PRIV-01 Option A is chosen, because then the label semantics change) |
| KOT-01 | Cause as recorded is imprecise. Real limitation: Kotlin incremental cache / plugin test-task configuration across `C:\Users\ASUS\AppData\Local\Pub\Cache` and `D:\parentcontrol_app\android` (`docs/bug-report.md:196-200`; `docs/runtime-failure-analysis.md:126-134`). Mitigation is already committed (`android/gradle.properties:9` `kotlin.incremental=false`), and an **app-only** invocation is recorded as succeeding **on this workstation** (`docs/verification-report.md:130-142`: `BUILD SUCCESSFUL`, `GRADLE_EXIT=0`) | **Still open (5 files never executed) — but the precise unblock is a local command, not a new machine.** Not executed by this workstream | No. Phase 3 docs should stop repeating "needs a workstation with both on one drive" (`phase-2-open-gaps.md:53`) as the only path |
| KOT-02 | Both helpers still exist and still agree: `PolicyApplier.kt:229-233` (called `:376`) and `GuardianService.kt:668-674` (called `:503`), both reading `applier.isDeviceOwner()` / `applier.isAdminActive()` | **Deliberately deferred (unchanged); prerequisite test does not exist yet** — `android/app/src/test/kotlin/**` holds only the 4 `AudioAssistance*` files and `policy/PolicyEvaluatorTest.kt`; there is **no `PolicyApplierTest.kt`**, contrary to the "coverage first" wording at `phase-2-governance.md:106` | No |
| DOC-01 | Current state: `docs/implementation/regression-matrix.md:24` still lists `deno test supabase/functions` in the *Exact command* column, with the amendment appended in the same cell's note (`FAILED \| 83 passed \| 5 failed` without `--allow-read`, `88 passed` with). Correct invocation is authoritative in `phase-2-regression-matrix.md:18`, negative control at `:22`; root cause `handler_wiring_test.ts:11-14` | **Deferred — documented in place, not rewritten; needs a one-cell docs edit** | No |
| UX-01 | Current state unchanged: `lib/features/safe_zones/safe_zones_controller.dart:40-49` (`canManage`), client pre-check at `:155-161`, 8 render sites in `safe_zones_page.dart` (`:46`, `:92-93`, `:104`, `:112`, `:197`, `:204`, `:229`). Server is authoritative: `supabase/functions/family-admin/index.ts:180-181` (`requireUser` verified-email + `requireRole(..., "parent")`) and `:203` (`assertFamilyParent`) — line numbers shifted when SQL-05 expanded the block comment above the `delete_zone` case | **Deliberately deferred, correct as-is** — restructuring would be a second implementation of a server rule | No |

## 2. TEST-01 — what the real unblock action is

The gap is not "tests are missing"; it is that **four handlers are not importable**. Verified shape:
`supabase/functions/account/index.ts:454` `Deno.serve(async (req) => …)` with every action inline and
`getServiceClient()` called inside the handler (`account/index.ts:462`); the same pattern at
`family-admin/index.ts`, `device-command/index.ts`, `remote-session/index.ts` (the four files read by
`handler_wiring_test.ts:72`, `:107`, `:175`, `:203`, `:235`, plus `_shared/auth.ts:163`).

What the source-level proof **does** catch: the extracted module's import disappearing, the call site
disappearing, a second inline re-derivation of the rule (`handler_wiring_test.ts:87-88` counts
`decideEnforcement(` occurrences), and **ordering** inside one action (`assertOrder`, `:56-70`, used at
`:98-103`). What it cannot catch, and what Phase 2 already conceded (`phase-2-open-gaps.md:48`): a
handler that calls the right module with the wrong **variable** — e.g. `decideEnforcement({result,
ackStatus: nextStatus, targetsApps: …})` at `:83` is pinned as a literal string, so renaming
`nextStatus` fails the test (good) but passing `command.status` instead of `nextStatus` would not,
because the assertion never evaluates anything (stated honestly).

Real unblock action, in order of value:
1. **Export-first refactor of the four handlers**: extract each `case "<action>"` body into an
   exported `async function handleX(db, auth, body)` and let `Deno.serve` dispatch to it, so a Deno
   test can pass a fake `db` the way `lifecycle_test.ts:138` already passes a fake `rpc`. This is the
   only change that converts the proofs into executions.
2. Ownership must be settled first: those four files belong to Phase 1 **session**, **security**,
   **enforcement** and **lifecycle** (`coordinator-contract.md:124-128`), and Phase 3 already has
   workstreams editing `family-admin` (SQL-03/B) concurrently — so this refactor cannot safely happen
   in this phase's window. It is a coordinator/owner scheduling call.
3. Interim, cheap and honest: keep the wiring tests, and label them in `phase-3-*` as *source-level
   pinning, not handler execution*, so nobody reads 88 passing Deno tests as handler coverage
   (`phase-2-regression-matrix.md:18`).

`account`'s `retentionReport` is the concrete instance of the same problem: it is a non-exported
function (`account/index.ts:366`) reached only through `Deno.serve` (`:454`), which is exactly why the
PRIV-01 fix in `p3-privacy-decisions.md` §1.2 cannot come with a real Deno test unless item 1 happens.

## 3. SQL-06 — signaling uniqueness, precisely

Verified write path (only one INSERT exists in the whole tree):
- `sequence bigint generated always as identity` (`supabase/migrations/20260101000000_core.sql:366`);
  a non-unique `webrtc_signals_session_sequence_idx (session_id, sequence)` at `:369-370`.
- The single writer is the client: `lib/data/repositories/supabase_remote_session_repository.dart:184-189`
  inserts `session_id`, `from_user_id`, `kind`, `payload` and **never** `sequence`. No Edge Function
  writes the table (grep over `supabase/functions/**` finds `webrtc_signals` only as a *default
  retention number* at `account/index.ts:431` and inside the sweep's `DELETE`), and the retained rows
  are deleted after 7 days (`20261030000300_retention_sweep.sql:119-123`; the matching `created_at`
  index added in Phase 3 is at `:53-54`).
- **Answer to "can duplicates arise in the current write path?" — No.** An `ALWAYS IDENTITY` column
  draws a fresh table-wide value per insert and Postgres rejects both supplying it in an `INSERT` and
  updating it, so `(session_id, sequence)` cannot collide for rows created through this path whether
  or not the unique index exists. Duplicates are only reachable through an imported/restored database
  or a schema that predates the identity default — the case the migration comment itself names
  (`20261030000200_phase1_authorization.sql:472-474`).

**Therefore the finding should be re-scoped, and one doc claim is wrong in substance:**
- The conditional index is *not* replay protection. A replayed signal is a **new insert** with a
  **new** sequence and a new `id`; uniqueness never trips. `docs/implementation/api-contract.md:222-224`
  currently tells a reader that "Signal replay protection is the unique `(session_id, sequence)` index
  added in `20261030000200_phase1_authorization.sql`" — that is an over-claim about a notice-only
  index (`:492`) over a column that is already unique. P2 (documentation stating something the code
  cannot enforce).
- What actually mitigates replay today is client-side: dedupe by row `id` with a `kind:sequence`
  fallback only when the id is missing (`lib/features/remote_assistance/remote_session_controller.dart:911-914`)
  plus rejection of stored pre-negotiation rows by horizon (`:915-921`). Server-side, signaling writes
  are gated by the participants-only INSERT policy (`docs/implementation/api-contract.md:174`).
- Cost of making uniqueness enforced, option by option:
  - **Unconditional `create unique index`** (drop the duplicate guard at
    `20261030000200_phase1_authorization.sql:478-490`): if any duplicate is present the statement
    fails and, inside the single-file `psql -v ON_ERROR_STOP=1` chain (`regression-matrix.md:26`), the
    **whole authorization migration aborts** — i.e. the five `not_family_parent` (42501) checks in the
    same file (`:252`, `:336`, `:369`, `:374`, `:414`, in `request_remote_session`, `revoke_device`,
    `unlink_child` x2 and `apply_policy_version`) do not land either. Cheapest and safest variant of
    "enforce", but
    only after the pre-check returns zero rows.
  - **Row deletion to make it enforceable**: destroys signaling history. Given the 7-day retention
    (`20261030000300_retention_sweep.sql:119-123`) the data is nearly worthless, but the session row
    keeps the record (`:9-10`), and deleting rows to satisfy an index that the write path cannot
    violate is unjustified data loss. Do not.
  - **Reject the insert (index present, writer unchanged)**: a violating client insert returns
    Postgres `23505`, which reaches Dart as a `PostgrestException` and is mapped at
    `supabase_remote_session_repository.dart:416-429` to `AppErrorCodes.unknown` with the **raw**
    Postgres message passed through (`:426`) — the live session screen would surface
    "duplicate key value violates unique constraint …" for a condition the client did not cause.
    Unacceptable without also adding an error-code mapping, which is a second change in a
    session/audio-owned file.
- How to close: (a) run the pre-check query (`20261030000200_phase1_authorization.sql:478-486`, whose
  duplicate-detecting subquery is `:479-485`) against
  the target database before apply — already assigned in `remaining-gaps.md:105`, and hosted inspection
  belongs to the coordinator, not to this workstream; (b) correct `api-contract.md:223` so it says the
  index is *hygiene against imported duplicates* and that replay mitigation is client-side
  (`remote_session_controller.dart:911-921`); (c) leave the notice-only guard in place. No security
  control is currently missing from the write path.

- **NEW, found while re-verifying (same root cause, different blast radius): the migration, test 70
  and test 71 disagree about whether the index is optional.** The migration skips creation and only
  raises a *notice* when duplicates exist (`20261030000200_phase1_authorization.sql:492`, guard at
  `:478-486`, create at `:489-490`); `supabase/tests/70_phase1_authorization.sql:436-451` mirrors
  that condition and so
  passes either way. But `supabase/tests/71_phase1_rollback_privileges.sql:194-197` asserts
  `index|webrtc_signals_session_sequence_uniq <> 'ABSENT'` for the forward phase **with no duplicate
  guard**, and the migration's own rollback state table
  (`20261030000200_phase1_authorization.sql:36-47`, row `:44`) records the index as
  `ABSENT → PRESENT / PRESENT`, i.e. unconditionally present forward *and* after rollback. So on an
  imported-duplicate database the apply succeeds quietly (notice) and the suite then fails loudly at
  `71…:194-197`. P2 today (only the pre-apply duplicate check can trigger it), and it strengthens
  closure (a): the pre-check is not optional hygiene, it is the only thing standing between a quiet
  apply and a red suite. No source change proposed — the cheapest correct fix is a one-line guard in
  the test owned by P3-A, or an honest `:44` cell reading `PRESENT (skipped, notice, on duplicates)`.

## 4. WORD-01 / WORD-02 — closures

- **WORD-01 — closed by P3-D.** The header at `app_restrictions_page.dart:360` was an
  overstatement of `PolicyApplier.kt:151`, exactly as filed; the fix taken is the header text, which
  is now `'Apps the device could not confirm as suspended'` at `app_restrictions_page.dart:373`, with
  the same softening applied to the model doc comment (`policy_enforcement.dart:3-6`). The per-row
  device reason remains rendered, so no information was lost. The string **is** pinned —
  `app_restrictions_page_test.dart:282` and `enforcement_correlation_page_test.dart:168`, `:207`.
  The rejected alternative (a distinct Kotlin reason code) changes the `policy_ack.result` payload
  and needs the Kotlin suite, which is why it was not chosen for a wording bug.
- **WORD-02**: `isChildExport` (`account_privacy_repository.dart:41-42`) is a boolean with a
  family-scoped default. The server always stamps a valid role (`account/index.ts:211-215`, and
  `_shared/auth.ts:115-117` 403s any other value), so the reachable failure is a malformed or absent
  payload only. Correct fix is a three-state scope (child / family / not reported) read from the
  payload, which is the same change PRIV-01 requires of the retention card
  (`p3-privacy-decisions.md` §1.5); doing them together avoids inventing two vocabularies.

## 5. KOT-01 — exact environment limitation and precise unblock

Verified facts (not inferred):
| Item | Value | How verified |
|---|---|---|
| Project root | `D:\parentcontrol_app` (Android module `D:\parentcontrol_app\android`) | read |
| Gradle user home | unset, so `distributionBase=GRADLE_USER_HOME` / `zipStoreBase=GRADLE_USER_HOME` (`android/gradle/wrapper/gradle-wrapper.properties:1`, `:3`) resolve to `C:\Users\ASUS\.gradle`, which exists | `echo $GRADLE_USER_HOME` → empty; `ls -d /c/Users/ASUS/.gradle` → present |
| JDK | `JAVA_HOME=C:\Program Files\Java\jdk-17` | env read |
| Android SDK | `sdk.dir=C:\\Users\\ASUS\\AppData\\Local\\Android\\sdk` | `android/local.properties` |
| Flutter SDK | `flutter.sdk=D:\\parentcontrol_app\\.fvm\\flutter_sdk` | `android/local.properties` |
| Pub cache (the actual second root) | `C:\Users\ASUS\AppData\Local\Pub\Cache` vs `D:\parentcontrol_app\android` | `docs/bug-report.md:196-200` (recorded error text) |
| Failure text | `java.lang.IllegalArgumentException: this and base files have different roots: C:\Users\ASUS\AppData\Local\Pub\Cache\… and D:\parentcontrol_app\android`, "Could not close incremental caches"; and at task-configuration time for a plugin: `A problem occurred configuring project ':flutter_secure_storage' … Could not create task ':flutter_secure_storage:testDebugUnitTest'` | `docs/bug-report.md:196-200`; `docs/runtime-failure-analysis.md:128-134` |
| Committed mitigation | `kotlin.incremental=false` with the explanatory comment | `android/gradle.properties:6-9` |
| Recorded **successful** app-only run on this machine | `cd android` then `./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` → `BUILD SUCCESSFUL`, `GRADLE_EXIT=0`; `PolicyEvaluatorTest` report `tests="13" skipped="0" failures="0" errors="0"`; a plain all-modules `testDebugUnitTest` still fails while configuring plugin test tasks | `docs/verification-report.md:130-142` |
| Currency of that run | dated 2026-10-26/27/28 (`verification-report.md:3-8`) — it predates the four `AudioAssistance*` test files added later | read |
| Test files present now | `AudioAssistanceRecreationTest.kt`, `AudioAssistanceSessionWatchdogTest.kt`, `AudioAssistanceStartGateTest.kt`, `AudioAssistanceStopIdempotenceTest.kt`, `policy/PolicyEvaluatorTest.kt` (5; no `PolicyApplierTest.kt`) | `find android/app/src/test -name '*.kt'` |

**Precise unblock action** (single command, this workstation, no new machine, no layout change):

```
cd /d/parentcontrol_app/android && ./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks
```

Scoping to `:app:` avoids creating the plugin test tasks that trigger the configuration-time
cross-root failure, and `--rerun-tasks` is required because a repeat invocation reports `UP-TO-DATE`
without executing (`verification-report.md:138-140`). `phase-2-open-gaps.md:53` and
`phase-2-governance.md:114-116` should be corrected to this when the phase docs are written (they are
coordinator-owned, so this is a note, not an edit).

Status discipline: this workstream **did not run Gradle**. Reasons: analysis-only remit, four
workstreams editing the same tree concurrently, and a Gradle run rewrites `build/**` (and
`.gradle/**`) that another workstream's build may hold. KOT-01 therefore remains
**`NOT EXECUTED` / `BLOCKED — not attempted by P3-F`**, and the five files' result must not be
reported as passing until someone runs the command above and records the JUnit XML.

## 6. KOT-02 — the one-line fix and why it waits

Both helpers exist and cannot currently disagree, because both derive from the same two predicates on
the same object: `PolicyApplier.kt:229-233` (`isDeviceOwner()` / `isAdminActive()`), used at `:376`
inside the apply-result JSON; `GuardianService.kt:668-674` (`applier.isDeviceOwner()` /
`applier.isAdminActive()`), used at `:503` inside the heartbeat `capabilities` object. `enforcement_mode`
is paired server-side with `enforcement_supported` (`phase-2-governance.md:94-97`), so drift would make
one device describe two capability states.

Fix: delete `GuardianService.kt:668-674` and call `applier.enforcementMode()` at
`GuardianService.kt:503` (the method is already public — `PolicyApplier.kt:229` has no `private`
modifier). Why it needs the Gradle-capable invocation rather than a new machine: it is behaviour-neutral
by inspection but its only real proof is `:app:testDebugUnitTest` plus a `PolicyApplierTest` that
**does not exist yet**; Phase 2's note (`phase-2-governance.md:104-106`) assumed that test would be
written first, so the correct order is (1) KOT-01 unblock, (2) add the mapping test, (3) collapse the
duplicate. Touching two Phase-1-owned native files (`coordinator-contract.md:126`) inside a phase where
no other workstream owns Android also needs a scheduling call, which is why Phase 2's
"do not redesign unrelated modules" ruling still holds (`phase-2-governance.md:99-102`).

## 7. DOC-01 / UX-01 — current state, no action required from the owner

- DOC-01: closed as a *documentation accuracy* problem only by in-place amendment
  (`regression-matrix.md:24`, which keeps the stale command visible and appends the measured result);
  the authoritative Phase 2 command is `deno test --allow-read supabase/functions/`
  (`phase-2-regression-matrix.md:18`), and the negative control that the flagless command fails is
  itself recorded (`:22`). Anyone re-running Phase 1 evidence must add the flag; a one-cell edit to
  the *Exact command* column would finish it. The flag is needed because the wiring test reads handler
  sources (`handler_wiring_test.ts:11-14`, `:24-29`).
- UX-01: confirmed as a UX gate, not an authorization boundary, and left as-is on purpose. The server
  path is the authority (`family-admin/index.ts:180-181`, `:203` — shifted by the SQL-05 comment block), the client `safe_zones` DELETE policy
  was dropped in Phase 1 (`api-contract.md:170`), and the gate's own behaviour is pinned
  (`test/features/safe_zones/safe_zones_authorization_test.dart:102`, `:115`, `:127`, `:164`, `:182`).
  The residual, and it is cosmetic: the client message at `safe_zones_controller.dart:156-159` claims
  "An active parent of this family is required" from a client-side guess that
  `canManage`'s fallback branch (`:46-48`) derives from `family.ownerId`, not from a real membership
  row — so it can deny a parent whose membership has not loaded. That is an argument for keeping the
  gate as UX and never as proof, which is what the code already says at `:37-39`.

## 8. PERF-01 — the shipped retention DELETE shape still scans the target table (new, from P3-A2)

`p3-sql-performance.md` §2 measures this, and it is deliberately **not** fixed in Phase 3:

- `run_retention_sweep()` uses `delete from t w using (select id … limit 10000) doomed where w.id
  = doomed.id`. The two new `created_at` indexes make the *doomed* side an index range scan, but at
  both measured selectivities the planner keeps a **`Seq Scan` on the delete target** for
  `webrtc_signals` (43 % backlog: 67.434 ms; 1.48 % backlog: 26.285 ms with
  `Seq Scan on webrtc_signals w (rows=81,200)`). On `audit_logs` the plan does flip to
  `Index Scan using audit_logs_pkey … loops=400` at 0.23 %, which is why that statement went
  149.615 ms → 6.936 ms.
- The alternative measured in the same probe — `where id = any(array(select …))` — was faster on
  `webrtc_signals` at the backlog point (36.256 ms vs 67.434 ms) but was **not adopted**: changing
  the delete shape changes which rows a batch takes when `limit` truncates, and no evidence yet
  shows the new ordering is equivalent for the retention guarantee.

**Unblock action:** a scoped A/B on the alternative shape with a *correctness* assertion (same rows
removed for the same backlog, batch-order stability across repeated calls), then a one-line change
in `20261030000300_retention_sweep.sql` plus `tests/74` §4. Owner decision needed? **No** — it is a
performance change inside the lifecycle workstream's own file; it was skipped only to keep Phase 3
scope, and `tests/74` already pins the current shape so the swap cannot be silent.
