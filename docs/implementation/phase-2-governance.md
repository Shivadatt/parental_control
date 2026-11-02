# Phase 2 — governance record and Kotlin follow-ups

Recorded 2026-11-02. Documentation only: this workstream changed no source, migration, config or
hosted object. Companion documents: `phase-2-report.md` (what changed),
`phase-2-regression-matrix.md` (evidence), `phase-2-open-gaps.md` (what is still not true).

## 1. Baseline this record applies to

| Item | Value | How verified |
|---|---|---|
| Branch | `main` | `git rev-parse --abbrev-ref HEAD` |
| HEAD | `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2` ("chore: generate build artifacts and configure project files", 2026-10-30 19:22 +0530) | `git rev-parse HEAD`, `git log -1` |
| HEAD movement during Phase 2 | none — the newest `git reflog` entry is still the 2026-10-30 19:22 commit | `git reflog -8` |
| Phase 2 delta | 34 files, +1711 / −116, **all staged, nothing unstaged, nothing untracked** — this is the state *before* Phase 2 work began; the state Phase 2 leaves behind is in `phase-2-report.md` §2 | `git diff --cached --stat`, `git status --short` |
| Commits / branches / pushes created | none | no `git commit`, `git branch`, `git push` was run in this phase |

The index carries the Phase 2 diff because the IDE keeps it refreshed after each edit; **no
workstream in this phase ran `git add`**. No reset, stash or clean was run; §7 records the two
`git checkout -- <path>` commands that discarded only this session's own formatter churn.

Phase 1 is already inside HEAD: `supabase/functions/family-admin/authorization.ts` and
`supabase/migrations/20261030000200_phase1_authorization.sql` both resolve in
`git ls-tree -r --name-only HEAD`. Phase 2 is therefore additive to committed Phase 1 work, not a
second copy of it.

## 2. Phase 1 contract amendment — ratification status

| Amendment | Where written | Ratified by | Status |
|---|---|---|---|
| Abandoned-session close stores `ended_by = NULL` + `ended_reason = 'abandoned'` (the contract's original `ended_by='system'` is unrepresentable because `remote_sessions.ended_by` is `uuid references profiles(id)`) | `docs/implementation/_work/coordinator-contract.md:41-43`; rationale `docs/implementation/_work/session.md:31-38`; original finding `docs/implementation/_work/contracts.md:8-10` (report D1) | coordinator addendum, `docs/implementation/phase-1-report.md:363` ("ratified by the coordinator as forced by the `ended_by uuid` column type") | **RATIFIED (coordinator).** Consumers must key on `ended_reason`, never on `ended_by`. |
| `unlink_child` keeps the child-self exception (`p_actor = p_child`) | `coordinator-contract.md:78-80`; rationale `security.md:15-18` | same addendum | **RATIFIED (coordinator).** |
| Out-of-ownership Phase 1 edits (`supabase_location_repository.dart`, `supabase/tests/30_rls.sql`, `supabase/tests/40_functions.sql`, `supabase/tests/README.md`) | `phase-1-report.md:363` | same addendum | **RATIFIED (coordinator).** |

No owner-level signature was recorded for D1: the ratification is the reviewing coordinator's, which
is why `phase-2-open-gaps.md` still lists it as an owner-visible decision rather than calling it
closed. This is the honest ceiling of what the artifacts show.

## 3. Cross-workstream edits made in Phase 2

Phase 2's own workstream split (A dashboard/presence, B family, C enforcement honesty, D tests,
E governance, F verification) supersedes the Phase 1 file table for this phase. Against the Phase 1
ownership table (`coordinator-contract.md:121-132`), the Phase 2 diff touches:

| Path | Phase 1 owner | Phase 2 workstream | Why it was unavoidable |
|---|---|---|---|
| `lib/data/models/device.dart`, `lib/features/dashboard/**`, `lib/features/devices/**`, `test/data/device_model_test.dart`, `test/features/dashboard/**`, `test/features/devices/**` | presence | A | The consolidation target *is* that vocabulary; leaving the duplicates anywhere else would keep two sources of truth. |
| `lib/features/app_restrictions/**`, `test/features/app_restrictions/**` | enforcement | C | Client-side display only; `enforcement.ts` and the Kotlin counters were not touched. |
| `lib/features/settings/**`, `test/features/settings/**` | lifecycle | B 4.4 | Wording only — no `account` handler, migration or action-shape change. |
| `lib/features/safe_zones/**`, `test/features/safe_zones/**` | security | B 4.2, D | The client half of the frozen `delete_zone` replacement path. |
| `lib/features/audit_logs/**`, `lib/features/family/**`, `lib/features/child/tabs/child_home_tab.dart`, `test/features/audit_logs/**`, `test/features/family/**`, `test/features/auth/fakes.dart` | unowned in Phase 1 | A, B | First time these files are touched; `test/features/auth/fakes.dart` is shared test scaffolding. |
| `supabase/tests/30_rls.sql` | ratified out-of-ownership (Phase 1) | D 6.6 | Restores the service-role row-count assertion for the ratified delete path. |
| `supabase/functions/handler_wiring_test.ts` | new, no Phase 1 owner | D 6.1–6.4 | Cross-handler wiring proof; test-only, reads sources. |

Zero Phase 2 edits fall in the Phase 1 **session**, **audio** or **android** ownership areas, and
none changes a frozen surface: no migration, no `supabase/functions/*/index.ts`, no route
(`lib/routes/**`), no RPC signature, no `pubspec.yaml`, no `android/**`. Verified with
`git diff --cached --name-only` against those prefixes.

## 4. Build-rule record

On 2026-10-30 the Phase 1 Android workstream ran
`./.fvm/flutter_sdk/bin/flutter build apk --debug` and recorded it as validation in
`docs/implementation/_work/android.md:36`. Phase 1 coordinator rule 10
(`coordinator-contract.md:25-27`) forbids exactly that inside a workstream. Status:

- **RULE-10 BREACH — NOT RATIFIED.** The coordinator refused it (`phase-1-report.md:363`) and
  `remaining-gaps.md:107` repeats the refusal.
- It is a **compile-level check only**, not test evidence. The APK does not prove enforcement,
  presence, lifetime or authorization behaviour, and it must not be cited as such in any future
  phase. The build log survives at `.tools/verify-apk-20261030.log` (1126 bytes; `.tools/` is
  gitignored at `.gitignore:16`).
- The authoritative Phase 1 build was run once by the verification workstream and is reported that
  way in `regression-matrix.md:27`.

For Phase 2: **no `flutter build` of any kind was run**, by any workstream. The verification
workstream ran analyzer, Flutter tests, Deno tests and the SQL chain only (see
`phase-2-regression-matrix.md`). No Android-source compile claim is made for Phase 2, and none was
needed: `git diff --cached --name-only -- android/` returns nothing, so the Kotlin, manifest, Gradle
and resource trees are byte-identical to HEAD.

## 5. Kotlin follow-ups (documented, deliberately not consolidated)

### 5.1 Duplicated `enforcementMode()`

Two implementations of the same three-way mapping exist:

| Site | Shape | Call site |
|---|---|---|
| `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:229-234` | `fun enforcementMode(): String = when { isDeviceOwner() -> "device_owner"; isAdminActive() -> "device_admin"; else -> "none" }` | `PolicyApplier.kt:376`, into the apply-result JSON |
| `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:668-674` | `private fun enforcementMode()` returning the same three values from `applier.isDeviceOwner()` / `applier.isAdminActive()` | `GuardianService.kt:503`, into the `policy_ack` payload |

Both read the *same* two capability predicates from the same `applier`, so they cannot disagree
today. The risk is drift: `enforcement_mode` is the field the server pairs with
`enforcement_supported` (`supabase/functions/device-command/enforcement.ts`), and changing one
mapping without the other would make the ack and the apply result describe different capability
states for one device — with nothing in this environment able to catch it, because Kotlin tests
cannot run here (§5.2).

**Not consolidated in Phase 2, on purpose.** Removing the `GuardianService` wrapper is a behaviour-
neutral refactor in the Phase 1 *android/enforcement* ownership area, outside every Phase 2
workstream brief, and it would be verified only by a Gradle run that this workstation cannot
perform. Phase 2 rule "do not redesign unrelated modules" outranks tidiness here.

Follow-up (owner decision, severity P2, one-line change): delete `GuardianService.kt:668-674` and
call `applier.enforcementMode()` at `GuardianService.kt:503`. Needs a Gradle-capable workstation
(cache and project on one drive) plus `PolicyApplierTest` coverage of the mapping first.

### 5.2 Kotlin JVM tests remain BLOCKED

`android/app/src/test/kotlin/**` holds five test files
(`AudioAssistanceRecreationTest.kt`, `AudioAssistanceSessionWatchdogTest.kt`,
`AudioAssistanceStartGateTest.kt`, `AudioAssistanceStopIdempotenceTest.kt`,
`policy/PolicyEvaluatorTest.kt`). **None was executed in Phase 2.** Status:
`BLOCKED — environment` (the Gradle cache lives on `C:` while the project lives on `D:`; the build
toolchain cannot resolve across the drives here). Kotlin correctness in this repository remains
compile-level only, from the historical build in §4, which is explicitly not test evidence.
No document in this phase may report Kotlin as PASS.

## 6. Stale `_work/*` notes corrected

Each note below was corrected in place with a dated marker; the original claim is kept visible so a
future reviewer can see what changed.

| Note | Stale claim | Current fact |
|---|---|---|
| `docs/implementation/_work/session.md:43-45` | "`supabase/tests/README.md` was **not** updated to add `63_abandoned_session_sweep.sql`" | README now documents `63_abandoned_session_sweep.sql` in the `psql -f` chain and in Coverage, plus `70_phase1_authorization.sql` and `72_retention_sweep.sql`. |
| `docs/implementation/_work/security.md:22-24` | "Stale SQL assertions outside security ownership (must be updated before the suite can pass): `30_rls.sql:110-112`, `40_functions.sql:286-293` and `:417-420`" | All three are current: `supabase/tests/30_rls.sql:110-134` carries the positive control (`:115` the zone is readable before deletion), the client-denied DELETE (`:122`, `42501`) and the `service_role` row-count assertion (`:129` exactly one row, `:134` the row is gone); `40_functions.sql:291` and `:419` expect `not_family_parent`. The full chain is re-run against a fresh database by the Phase 2 verification workstream; see `phase-2-regression-matrix.md` for the dated result. |
| `docs/implementation/_work/contracts.md:8-10` | "Contract wording should be amended (report D1)" | Amended at `docs/implementation/_work/coordinator-contract.md:41-43` and restated in `docs/implementation/api-contract.md:231`; ratified by the coordinator at `docs/implementation/phase-1-report.md:363` (§2). |
| `docs/implementation/_work/lifecycle.md:12-13` | "`public.run_retention_sweep()` (… 10 000-row batches)" | The batches are real per-statement loops (`20261030000300_retention_sweep.sql:35,116-145`), but every batch runs inside one function call, i.e. one transaction, and the `webrtc_signals` / `audit_logs` `created_at` predicates have no usable index (`20260101000000_core.sql:369,388,390`). Recorded as PG-M3 in `phase-2-open-gaps.md`; the note alone overstated the safety of a first backlog run. |
| `docs/implementation/_work/enforcement.md:43`, `audio.md:45` | "`flutter test` intentionally not run (coordinator rule)" | Correct for Phase 1: `_work/coordinator-contract.md:25-26` banned both `flutter test` and `flutter build` inside a workstream. Phase 2 rule 10 bans only the **build**, and the Phase 2 verification workstream ran the authoritative suite on 2026-11-02 — `+355`, all passed (`phase-2-regression-matrix.md` §1). Flagged so the next reviewer does not read "not run" as "untested". |
| `docs/implementation/_work/android.md:34-38` | Build listed under "Validation" | Annotated as a rule-10 breach and compile-level only (§4). |

## 7. Phase 2 rule compliance

| Rule | Evidence |
|---|---|
| No Supabase CLI | The npm-installed binary was never invoked by any command in this phase; every SQL statement ran against a disposable local cluster (`postgres -D .tools/pgdata_p2 -p 55440`) created for the test suite. |
| Dashboard used read-only | Inspection only, per the owner's standing instruction; no migration, function, secret, policy or data change was made in the dashboard during Phase 2. |
| No migration applied / no function deployed | `git diff --cached --name-only` contains no `supabase/migrations/**` entry and no `supabase/functions/*/index.ts` entry. Hosted state remains as last audited 2026-10-30 (`deployment-log.md:9-10`, 9 hosted functions with no `account`, `safe_zones_delete_parent` still present); the 2026-11-02 dashboard screenshot supplied by the owner still shows "No migrations". That observation is point-in-time and decays the moment the owner deploys. |
| No Phase 1 capability presented as live | Every Phase 2 UI statement about `delete_zone`, owner-only purge, abandoned-session sweep, retention or account export is written as behaviour of code that is **local-only until deployed**; `phase-2-open-gaps.md` PG-01 carries that gate. |
| No secret/auth/production-data change | No file under `android/key.properties*`, `supabase/functions/_shared/env*`, or any hosted setting was touched. |
| No runtime/production verification claimed | Phase 2 evidence is analyzer + Flutter widget/unit tests + Deno unit & wiring tests + local SQL authorization suite. No emulator, no device matrix, no hosted call. Anything needing a device is listed as NOT TESTED, never PASS. |
| Phase 0 baseline immutable | `docs/implementation/baseline.md` and `phase-0-report.md` were not edited — `git status --porcelain` and `git diff --cached --name-only` for both paths return nothing. Commit-level proof is **not available**: the baseline records HEAD as `2a0209f` (`baseline.md:12`), and that object exists in no ref of the current repository (`git rev-list --all \| grep '^2a0209'` returns nothing; current HEAD is `8da1de7`). The phase therefore treats baseline immutability as verified by *content* (the two frozen documents are unchanged) and flags the unverifiable hash as an open gap in `phase-2-open-gaps.md` rather than claiming ancestry. |
| Existing work preserved | No `git reset`, `git clean`, `git stash`, revert or branch/push operation was run. Two `git checkout -- <path>` commands **were** run, against `lib/features/dashboard/parent_dashboard_tab.dart` and `lib/features/child/tabs/child_home_tab.dart`, to undo churn from a repo-wide `dart format` (Dart 3.12 tall style reformats pre-existing code). What those checkouts discarded was only that session's own uncommitted formatting; the Phase 2 work was safe in the index, and the intended edits were re-applied by hand in each file's existing style. Nothing written by an earlier phase was lost: the final tree contains every Phase 2 edit, and `git diff HEAD --name-status` shows all 47 changed files (the index carries all of them; the four Phase 2 documents have a final doc-only refresh still ahead of it). The only delete-shaped operations in the phase were `dropdb` calls against the four throwaway databases this session itself created inside the gitignored `.tools/pgdata_p2` cluster (`parentcontrol_p2`, `parentcontrol_p2_final`, `_final2`, `_final3`); no repository file was deleted, and after the drops `pg_database` listed only `postgres`, `template0`, `template1`. The cluster was then stopped with `pg_ctl -m fast`. Full sequence in `phase-2-regression-matrix.md` §8. |
| Build ownership | No workstream ran a Flutter build; §4 records the historical Phase 1 breach instead of repeating it. |
