# Phase 1 — independent code and contract review

Reviewer role: read-only. No application code, tests, migrations, functions or configuration were
modified by this review. Base: `HEAD = 8ebb73c` (working tree contains the Phase 1 changes).
Date: 2026-10-30.
Inputs read in full: `docs/implementation/_work/coordinator-contract.md`,
`docs/implementation/phase-0-report.md`, `docs/implementation/api-contract.md`,
`docs/implementation/deployment/manifest.md`, `docs/implementation/deployment/remote-session.md`,
all eight `_work/*.md` notes (the coordinator contract plus seven workstream notes), every modified
file in `git diff` and every new file in `git status --porcelain`.

## Verdict

**ACCEPT WITH FOLLOW-UPS.** No blocking security regression was found. The authorization,
session-sweep, presence, enforcement and data-lifecycle changes are implemented substantially as
frozen, and the highest-risk paths (client zone deletion, owner-only purge, cross-family RPC actors,
account deletion, export scoping) are closed with evidence below. The follow-ups are documentation,
contract-synchronisation, wiring-test and pre-deploy-manifest defects — none of them require
redesign, but F1–F2 must be closed before anything is applied or deployed.

Totals at the final read: 36 tracked files modified, 40 new Phase 1 files (six pre-existing untracked
Phase 0 documents and this report/pair excluded). Four of the modified files (`60`, `61`, `62` SQL
fixtures and `test/features/child/child_shell_controller_test.dart`) changed **during** this review —
the first `git status` showed 32 modified files. Those edits are correct but were made after the
initial diff read; see §8. No file was deleted.

---

## 1. Implementation summary

| Workstream | What actually landed | Contract adherence |
|---|---|---|
| session | `expire_abandoned_sessions(interval)` + partial index; best-effort sweep in `remote-session request`; `acceptPatch`/`declinePatch` extracted; concurrent-end re-read | Matches, with one deviation self-recorded in the contract (unratified) and one documentation gap |
| presence | 12 min online / 30 min stalled derivation, age labels, "Sync stalled" / "Never synced" UI, 10 s tick + 3x stall watchdog with recovery audit | Matches |
| enforcement | ack counters, honest `unsupported`/`failed`/`pending` mapping, policy-version advance only on enforced/unsupported, "Applied to N of M apps" UI | Matches; one duplicated mode helper |
| security | grant-level removal of client zone DELETE, `delete_zone`, owner-only `purge_data`, `is_parent_of_family` on four RPCs, guarded unique index | Matches; two out-of-ownership test edits |
| lifecycle | `run_retention_sweep()`, new `account` function (export / delete / retention report), Privacy & data settings UI | Mostly matches; cron response shapes do not match `api-contract.md` |
| audio | single exclusive peer, one-future idempotent teardown, terminal-state precedence, 2 s rejoin debounce, startId-scoped native stop | Matches; no protocol change |
| android | opt-in release signing with warning + example file, cleartext disabled, deep-link auth callback validation | Matches; pinning correctly left as TODO |
| contracts | coordinator contract amended, api-contract, deployment manifest, remote-session deploy notes | Contract self-amended by a constraint-bound workstream; manifest is stale |

Positive findings worth recording: the SQL test files are substantive rather than smoke tests
(`supabase/tests/70_phase1_authorization.sql`, `63_abandoned_session_sweep.sql`,
`72_retention_sweep.sql` assert grants, truth tables and negative paths); the unique index refuses to
delete data and degrades with a notice
(`supabase/migrations/20261030000200_phase1_authorization.sql:334-354`); teardown is genuinely
single-flight (`lib/features/remote_assistance/remote_session_controller.dart:2498-2570`); the
watchdog isolates a failing tick and reschedules itself
(`android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:330-356`); export
scoping for a child never widens to the family
(`supabase/functions/account/index.ts:150-199`); and no secret material was added anywhere in the
diff.

## 2. Changed files by workstream

### contracts / documentation (11 Phase 1 files, plus the amended Phase 0 api-contract)
- `docs/implementation/_work/coordinator-contract.md` — `ended_by=NULL` amendment (line 41-43),
  child-self unlink exception retained (line 78-80). Governance issue: amended by the workstream it
  constrains, not by the coordinator.
- `docs/implementation/api-contract.md` (untracked Phase 0 document, amended during Phase 1) — §6
  additions; §2.9 cron table is stale (see §8 and §9).
- `docs/implementation/deployment/manifest.md`, `deployment/remote-session.md` (new) — pre-deploy
  checklist; manifest table and §3 defects (see §3 and §9 of this report).
- `docs/implementation/_work/{session,presence,enforcement,security,lifecycle,audio,android,contracts}.md`
  (new) — workstream notes, one stale claim (session.md:43-45).
- `supabase/tests/README.md` — new tests added to the `psql -f` chain; unowned file but the correct
  edit (contradicts session.md:43-45, which says it was not done).

### session (6 files)
- `supabase/migrations/20261030000100_abandoned_session_sweep.sql` (new)
- `supabase/functions/_shared/remote_session_lifecycle.ts` (new)
- `supabase/functions/remote-session/index.ts`, `remote-session/guard.ts`
- `supabase/functions/remote-session/lifecycle_test.ts` (new)
- `supabase/tests/63_abandoned_session_sweep.sql` (new)

### presence (8 files)
- `lib/data/models/device.dart`
- `lib/features/dashboard/parent_dashboard_tab.dart`, `lib/features/devices/device_detail_page.dart`
- `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt`
- `test/data/device_model_test.dart`, `test/features/dashboard/parent_dashboard_tab_test.dart`,
  `test/features/devices/device_detail_controller_test.dart`
- `test/features/child/child_shell_controller_test.dart` — fixture moved 10 → 20 min so the test's
  "not online, then online" assertion still holds under the 12 min window; appeared mid-review.

### enforcement (11 files)
- `android/.../PolicyApplier.kt`, `supabase/functions/device-command/index.ts`,
  `supabase/functions/device-command/enforcement.ts` (new), `enforcement_test.ts` (new)
- `lib/data/models/policy_enforcement.dart` (new)
- `lib/features/app_restrictions/app_restrictions_controller.dart`, `app_restrictions_page.dart`,
  `lib/features/child/child_restrictions_page.dart`
- `test/features/app_restrictions/app_restrictions_controller_test.dart`, `app_restrictions_page_test.dart`,
  `policy_enforcement_model_test.dart`

### security (12 files)
- `supabase/migrations/20261030000200_phase1_authorization.sql` (new)
- `supabase/functions/family-admin/index.ts`, `authorization.ts` (new), `authorization_test.ts` (new)
- `supabase/tests/70_phase1_authorization.sql` (new)
- `supabase/tests/30_rls.sql`, `supabase/tests/40_functions.sql` — **outside declared ownership**
- `supabase/tests/60_remote_session_concurrency.sql`, `61_parent_controlled_lifetime.sql`,
  `62_signaling_consented_session.sql` — fixture `family_members` rows added because the new
  `request_remote_session` parent check invalidated the old fixtures; appeared mid-review
- `lib/data/repositories/supabase_location_repository.dart` — **outside declared ownership**
- `test/features/safe_zones/safe_zones_controller_delete_test.dart` (new)

### lifecycle (17 files)
- `supabase/migrations/20261030000300_retention_sweep.sql` (new)
- `supabase/functions/cron/index.ts`
- `supabase/functions/account/{index,validation,retention,validation_test,retention_test}.ts` (new)
- `supabase/tests/72_retention_sweep.sql` (new)
- `lib/features/settings/{parent_settings_controller,parent_settings_binding,parent_settings_tab,settings_body}.dart`
- `lib/features/settings/{account_privacy_repository,delete_account_dialog,delete_confirmation,export_result_dialog}.dart` (new)
- `test/features/settings/account_privacy_controller_test.dart` (new)

### audio (6 files)
- `lib/features/remote_assistance/remote_session_controller.dart`, `remote_session_page.dart`
- `android/.../AudioAssistanceService.kt`
- `test/features/remote_assistance/remote_session_audio_lifecycle_test.dart` (new),
  `remote_session_reliability_test.dart`
- `android/app/src/test/kotlin/.../AudioAssistanceStopIdempotenceTest.kt` (new)

### android (5 files)
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/res/xml/network_security_config.xml` (new),
  `android/key.properties.example` (new), `android/.../MainActivity.kt`

## 3. Database changes pending (none applied)

Three local migration files, in this order:

1. `20261030000100_abandoned_session_sweep.sql` — `public.expire_abandoned_sessions(interval)`
   (`SECURITY DEFINER`, `search_path` pinned, `FOR UPDATE` ordered, `ended_by=NULL`,
   `ended_reason='abandoned'`, one `session_expired` audit row per session, rejects non-positive
   windows at line 63-65), grants service-role only, plus partial index
   `remote_sessions_abandoned_idx`.
2. `20261030000200_phase1_authorization.sql` — drops policy `safe_zones_delete_parent` and revokes
   table DELETE (lines 40-44); creates `private.is_parent_of_family` (service-role only, line 55-79);
   recreates `request_remote_session`, `revoke_device`, `unlink_child` and `apply_policy_version`
   with the family-parent check (`not_family_parent`, 42501) while preserving the child-self unlink
   exception (line 236-244); revokes default PUBLIC execute on two private helpers with
   missing-object notices (line 308-323); creates `webrtc_signals_session_sequence_uniq` only when
   no duplicates exist, never deletes rows (line 334-354).
3. `20261030000300_retention_sweep.sql` — `public.run_retention_sweep()` batched at 10 000 rows,
   7 d signals, 365 d audit, per-family location/usage windows validated and clamped, one
   `retention_sweep` audit row, service-role only.

Nothing was applied: no CLI (contract rule 2), no hosted SQL, no dashboard SQL editor use. The only
execution evidence anywhere in the phase is the migration #1 chain on a disposable local PostgreSQL
16 cluster recorded at `docs/implementation/deployment/manifest.md:151-153`; migrations #2 and #3
have no recorded run. The deploy runbook is not reliable yet:

- `manifest.md:28` and `:111` name `20261030000300_retention_and_sweeps.sql` — the file on disk is
  `20261030000300_retention_sweep.sql` — and still say **"File does not exist in the tree at the time
  of writing"**.
- The recorded SHA-256 for migration #2 (`manifest.md:27`,
  `3e6c56c8…fe2fd0`) does **not** match the current file (`f7062a84…db58`). Migration #1's hash does
  match. The manifest itself says a mismatch means "the file changed after this manifest was
  written" (`manifest.md:30-31`), so the file must be rehashed and the table corrected; otherwise the
  apply gate stops or, worse, the wrong content is trusted.
- `supabase/config.toml` has no `[functions.account]` entry (9 function blocks, lines 61-90). The
  deploy default (`verify_jwt=true`) is the intended behaviour for this function, but the new surface
  is undocumented in the deploy config.

## 4. Dashboard operations pending (none executed)

- No Edge Function was deployed; no `supabase functions deploy` was run.
- No migration was applied via SQL editor or otherwise.
- No secret was created or rotated; no auth provider, redirect URL, or JWT setting was changed.
- No cron schedule was created or modified; `cron` remains an externally triggered function.
- No Storage bucket or Realtime publication was touched (`api-contract.md:199-230` unchanged).

`remote-session.md:56-106` documents "migrations first, then the function" for `remote-session` only.
The cron handler degrades safely if the SQL functions are missing — `PGRST202`/`42883` become
`{skipped:true, reason:"function_missing"}` (`supabase/functions/cron/index.ts:88-91`, `:109-112`) —
so out-of-order deployment is survivable, but the order must still be documented per function.
`account` has no equivalent deploy note.

## 5. Test results

**Pending, see `docs/implementation/regression-matrix.md`.** That file does not exist in the tree at
review time (`ls` → no such file), and `docs/implementation/deployment-log.md` is also absent. This
review reports no pass/fail numbers and treats the verification run as in flight.

Test inventory added (existence only, not results):
- SQL: `63_abandoned_session_sweep.sql`, `70_phase1_authorization.sql`, `72_retention_sweep.sql`
  (self-contained, create/drop their own fixtures; written to be runnable, but not executed in this
  phase — the one local PG16 run recorded in the manifest covered migration #1 only).
- Deno: `device-command/enforcement_test.ts`, `remote-session/lifecycle_test.ts`,
  `family-admin/authorization_test.ts`, `account/validation_test.ts`, `account/retention_test.ts`.
- Dart: `device_model_test.dart` (extended), `parent_dashboard_tab_test.dart`,
  `app_restrictions_controller_test.dart` (extended), `app_restrictions_page_test.dart`,
  `policy_enforcement_model_test.dart`, `safe_zones_controller_delete_test.dart`,
  `account_privacy_controller_test.dart`, `remote_session_audio_lifecycle_test.dart`,
  `remote_session_reliability_test.dart` (knob only), `device_detail_controller_test.dart`.
- Kotlin: `AudioAssistanceStopIdempotenceTest.kt` — `BLOCKED — environment` (cross-drive Gradle),
  as the contract requires (`coordinator-contract.md:146`).

Workstream-claimed executions, **unverified by this reviewer**:
- `docs/implementation/_work/security.md:38` — `deno test …/family-admin` → 4 passed.
- `docs/implementation/_work/audio.md:40-41` and `enforcement.md:43` — `dart analyze` clean on edited
  files.
- `docs/implementation/_work/android.md:36` — `flutter build apk --debug` was run. This breaches
  contract rule 10 (`coordinator-contract.md:25-27`, verification runs builds once). It is not test
  evidence and must not be counted as such.

## 6. Runtime evidence

None. No device or emulator matrix, no hosted endpoint call, no two-account session, no push or
deep-link exercise was performed in Phase 1. The Android debug build claim above is a build artifact,
not runtime evidence, and is disallowed by the contract besides. All behavioural conclusions here are
static-code and contract analysis.

## 7. Security review

| # | Check | Verdict | Evidence |
|---|---|---|---|
| S1 | Client `safe_zones` DELETE removed at policy and grant level | PASS | `20261030000200_phase1_authorization.sql:40-44`; `30_rls.sql:112-116` asserts 42501 |
| S2 | Zone deletion is parent-only, family-scoped, audited | PASS | `family-admin/index.ts:170-224`: `requireUser` + `requireRole("parent")`, service-role read, `assertFamilyParent`, `canDeleteZone`, delete constrained by `family_id`, audit `zone_deleted` |
| S3 | `purge_data` requires the family owner | PASS | `family-admin/index.ts:240-247` (`assertFamilyOwner` + `canPurge`, 403 `owner_required`) |
| S4 | Four service RPCs reject a non-parent actor | PASS | migration lines 120-121, 204-205, 236-244, 280-283; `unlink_child` null-actor rejected at 236, child-self exception preserved at 239-241 |
| S5 | Replay-proof signalling index without destructive cleanup | PASS | migration lines 340-354, notice on duplicates |
| S6 | Export leaks no secrets and is role-scoped | PASS (note) | `account/index.ts:56-70` excludes `secret_hash`/revocation secrets; child devices `:154-158`; child rows `:168-177`; child audit `:186-199` |
| S7 | `delete_account` cannot touch another user | PASS | `account/index.ts:326-347`: membership/profile deletes keyed on caller id; families keyed on `owner_id = caller`; blocker at `:290-305` |
| S8 | Authorization failure mapped honestly to clients | PASS | `family-admin/index.ts` maps `not_family_parent` → 403; `apply_policy_version` no longer records a forged actor |
| S9 | RLS/grants not widened | PASS | no `grant … to authenticated` on new functions; `is_parent_of_family` service-role only (`:77-79`); audit append-only trigger unchanged and compatible with service-role retention deletes (`20260101000000_core.sql:549-555`) |
| S10 | No secrets committed | PASS | `android/key.properties` gitignored (`.gitignore:9`), only `.example` added; no keys/tokens in the diff or new files |
| S11 | Transport and deep-link hardening | PASS | `network_security_config.xml:9` cleartext false; `MainActivity.kt:41-56,62+` validates scheme/host and a code/token shape, ignores non-auth intents; no new exported component |
| S12 | Account deletion fails closed when auth deletion fails | PASS (note) | `account/index.ts:349-357` returns `account_delete_incomplete` when `auth.admin.deleteUser` fails; the auth user then remains without a profile and needs owner intervention, but nothing cross-user is exposed |

Residual security notes, not regressions:
- `retention_report` is callable by a child and returns family-wide retention counts and settings
  (`account/index.ts:366-424`); it exposes counts, not rows, but the role split should be a conscious
  decision.
- Parent export is family-scoped by design (`account/index.ts:150-177`), which is broader than a
  literal reading of "their own rows" in `coordinator-contract.md:94`. The result is data the parent
  UI already shows, so this is a wording/ratification issue.

## 8. Regression review

**Feature preservation — PASS.** No file deletions; no route removed (`api-contract.md` §1 lists 26
routes and the routing files are untouched); nine existing Edge Functions preserved and extended
(`family-admin` +1 action, `cron` +2 actions, `remote-session` behaviour preserved); no new table or
column. The child restrictions banner now says "Rules are not enforced on this device"
(`lib/features/child/child_restrictions_page.dart`), which is a truthful text change, not a removed
feature.

**Public API preservation — PASS (repair).** Controller constructors were normalised to the parameter
names call sites already use (`ParentSettingsController(authRepository: …, privacy: …)`,
`AppRestrictionsController(deviceId: …)`); bindings and existing tests did not have to change. The
`rejoinDebounce` knob is additive with a 2 s default
(`remote_session_controller.dart:112,130`), so production behaviour is unchanged for callers.

**Test integrity — PASS WITH NOTES.**
- Strengthened: the child zone-delete assertion moved from row-count 0 to an explicit 42501
  (`30_rls.sql:239-246`); the device-detail test moved 10 → 31 min because 10 min is now healthy, not
  because the assertion was relaxed (`device_detail_controller_test.dart:44`); the child-shell test
  moved 10 → 20 min so "not online, then online" still holds under the 12 min window, with its
  assertions unchanged (`child_shell_controller_test.dart:777-780`).
- Weakened: the parent zone-delete assertion became a service-role delete with no
  `get diagnostics … row_count` check (`30_rls.sql:117-119`). The client-denied half is stronger; the
  service-role success half no longer proves a row was removed. Restore the count assertion.
- Wiring gap: every Deno suite tests only a pure module (`device-command/enforcement_test.ts:4-8`,
  `family-admin/authorization_test.ts:4-6`, `remote-session/lifecycle_test.ts:4-12`,
  `account/validation_test.ts:3-11`). If `index.ts` stopped calling `decideEnforcement`,
  `canDeleteZone`/`canPurge`, `withAbandonedSweep` or `acceptPatch`, these suites would still pass.
- Wiring gap: `safe_zones_controller_delete_test.dart:40-51` mocks `LocationRepository`, so the actual
  change in `supabase_location_repository.dart:142-152` (edge action instead of table DELETE) is
  untested.
- Kotlin idempotence test exists but is unexecutable here (contract-sanctioned).
- Existing SQL fixtures were not compatible with the new `request_remote_session` parent check:
  `60_remote_session_concurrency.sql`, `61_parent_controlled_lifetime.sql` and
  `62_signaling_consented_session.sql` created families/devices without `family_members` rows and now
  needed them added (`60:53-62`, `61:44-53`, `62:40-45`). The fixes are correct and preserve every
  assertion, but they are the only concrete sign that the SQL chain was actually run against
  migration #2, and they appeared mid-review in files owned by no declared workstream.

**Cross-workstream interference — PASS WITH NOTES.**
- Security edited three files outside its ownership block: the location repository (necessary for the
  contract's replacement path), `30_rls.sql`, `40_functions.sql` (necessary because the frozen
  behaviour changed). All are correct edits, none are ratified in the contract.
- The coordinator contract was amended by the session workstream (`coordinator-contract.md:41-43`).
  The amendment is technically forced (`ended_by uuid references profiles(id)`), but a frozen contract
  should be amended by its owner with an explicit ratification line.
- `session.md:43-45` says `supabase/tests/README.md` was not updated; the diff shows it was. Stale
  workstream note.
- `api-contract.md:139-148` (cron) records `sweep_sessions` as `{max_age_hours?}` →
  `{expired_sessions:int}` and `retention_sweep` as `{signals_deleted, audit_deleted, location_deleted,
  usage_deleted}`, while the implementation accepts no options, returns `{closed_sessions}`
  (`cron/index.ts:83-101`) and returns `{swept_at, webrtc_signals, audit_logs, location_events,
  usage_daily, families_examined, per_family}` (`retention_sweep.sql:185-193`). §2.9's header also
  says "4 NEW" for two new actions.
- Two implementations of the enforcement-mode string exist:
  `PolicyApplier.enforcementMode()` (`PolicyApplier.kt:229`) and a private
  `GuardianService.enforcementMode()` (`GuardianService.kt:668`). They can drift.
- The working tree changed while this review was running: 32 modified files at the first read, 36 at
  the last, with `60/61/62` SQL fixtures and `child_shell_controller_test.dart` edited in between.
  The edits are sensible, but the reviewed snapshot and the snapshot that verification tests are not
  the same. The regression matrix must therefore name the exact tree/commit it tested.

## 9. Remaining blockers

| Blocker | Impact | Unblock |
|---|---|---|
| `manifest.md` §3 filename and stale "does not exist" text | Owner cannot apply migration #3 by following the runbook | Rename references to `20261030000300_retention_sweep.sql`, update §3, rehash all three |
| Migration #2 hash mismatch (`manifest.md:27` vs actual `f7062a84…`) | Apply gate fails or trusts stale content | Recompute and record; state hash-at-writing vs hash-at-apply |
| `api-contract.md` cron shapes vs implementation | Callers and cron scheduling would send ignored fields / read missing keys | Align contract §2.9 to `closed_sessions` + actual retention keys, or implement `max_age_hours` |
| `supabase/config.toml` has no `account` block | New function surface undocumented; deploy default is correct but implicit | Add `[functions.account] verify_jwt = true` in the deploy change, not in Phase 1 |
| Verification results unavailable (`regression-matrix.md` absent) | No test results are published yet; nothing in this report is a pass claim | Verification workstream publishes the matrix and deployment log |
| Kotlin JVM test `BLOCKED — environment` | Native idempotence proof is static-only | Run on a machine where Gradle and the project share a drive |
| No hosted or device runtime evidence | Enforcement, presence windows and the sweep are unproven in production conditions | Phase 2 device matrix after approved deploy |

## 10. Next-phase recommendation — Phase 2 (dashboard / family)

Proceed to Phase 2 dashboard/family, but treat the Phase 1 deploy gate as a separate, owner-approved
step that must first close F1–F2. Recommended Phase 2 scope:

1. Dashboard/family UI consolidation using the Phase 1 presence vocabulary (healthy / stalled /
   offline with age labels) as the only source of truth; do not add a second "online" definition.
2. Family management surfaces that depend on the new authorization: zone deletion through
   `family-admin delete_zone`, owner-only purge, and remove-account flows. These are already backed by
   server checks and can be built on them.
3. Enforcement honesty in the dashboard: show `unsupported`/`failed` counts and the Device Owner
   prerequisite prominently rather than hiding it. Device Owner provisioning remains an explicit gap
   (`remaining-gaps.md`) and is the precondition for any real suspension claim.
4. Add the missing wiring tests before or with Phase 2 UI work: one handler-level test per integration
   point that proves `index.ts` calls the tested pure module, and one repository test for
   `delete_zone`.
5. Do not extend `account`/`cron` contracts until the Phase 1 contract shapes are reconciled (F2).

Phase 2 must not assume that Phase 1 was deployed; every endpoint it consumes must still be treated
as local-only until the owner applies the migrations and deploys the functions in the documented
order.

---

## Ranked follow-ups

| Rank | Follow-up | Why it matters | Concrete change |
|---|---|---|---|
| F1 (must, before any apply) | Fix `deployment/manifest.md`: §3 filename, stale "file does not exist" text, and the migration #2 hash | The runbook is the only apply gate and it is wrong in three independent ways | Rewrite §3 against `20261030000300_retention_sweep.sql`; recompute all hashes on the applying machine; state that hashes change with line endings |
| F2 (must, before any deploy) | Reconcile `api-contract.md` §2.9 with cron implementation (`{max_age_hours?}`/`expired_sessions` vs `{closed_sessions}`; retention keys) and the "4 NEW" count; add the `account` function section or cross-reference from §2 | Contract drift silently ignores caller intent and breaks consumers | One docs edit from the contracts workstream, agreed with lifecycle |
| F3 (should, next PR) | Add wiring tests: handler-level checks that `device-command`, `family-admin`, `remote-session` and `account` call the tested modules; a repository test that `deleteSafeZone` invokes `family-admin delete_zone`; restore the service-role delete row-count assertion in `30_rls.sql` | Current suites pass even if production wiring is reverted | Four small integration tests with injected fakes; one SQL assertion |
| F4 (should) | Ratify governance: contract amendment at `coordinator-contract.md:41-43`; out-of-ownership edits (`supabase_location_repository.dart`, `30_rls.sql`, `40_functions.sql`, `supabase/tests/README.md`); record the `flutter build` rule-10 breach and do not repeat it | Unratified contract edits undermine the freeze; stale notes mislead the next reviewer | Coordinator notes in `_work/contracts.md` plus corrected `session.md` |
| F5 (should) | Resolve scoping/wording: parent export is family-scoped, child `retention_report` returns family-wide counts; document both explicitly; `session_nonce` is written but still not documented as reserved; dedupe `enforcementMode()` | Privacy intent must be explicit; two mode helpers will drift | Contract wording plus one shared Kotlin helper |
| F6 (later) | Add `[functions.account]` to the deploy config and a per-function deploy-order note (cron first vs SQL first) during the deployment change | Removes an undocumented new surface | Config + runbook edit at deploy time |

---

## Coordinator addendum (2026-10-30)

This report was written by the reviewer against a snapshot taken while verification was still running;
its §3 and §5 therefore describe a state that no longer exists, and its follow-ups were resolved after
it was filed. Recorded here so the report is not read as current findings. No reviewer text above was
edited.

**Reviewer findings now closed**

| Ref | Status | Resolution |
|---|---|---|
| F1, blocker "manifest.md §3 filename", "migration #2 hash" | **Closed** | `docs/implementation/deployment/manifest.md` row 3 now names `20261030000300_retention_sweep.sql`; both hashes recomputed from the files on disk (`f7062a84…`, `8de3cb38…`); baseline paragraph corrected. |
| F2, blocker "api-contract cron shapes" | **Closed** | `api-contract.md` cron rows now read `{}` → `{closed_sessions}` and the actual `run_retention_sweep()` keys; §2.9 header count corrected. |
| Blocker "`config.toml` has no `account` block" | **Closed** | `[functions.account] verify_jwt = true` added; deploy-order note remains part of the deployment step (F6 stays open for the cron/SQL ordering wording). |
| Blocker "verification results unavailable" | **Closed** | `regression-matrix.md` and `deployment-log.md` now exist; results: analyzer clean (exit 0), Flutter `+316 -0`, Deno 83/83, SQL chain EXIT=0, debug APK built. Kotlin still `BLOCKED`. |
| F4 "ratify governance" | **Ratified, with one exception** | The contract amendment at `coordinator-contract.md` (abandoned-session close writes `ended_by = NULL`, reason `abandoned`; `unlink_child` keeps the child-self exception) is ratified by the coordinator as forced by the `ended_by uuid` column type. Out-of-ownership edits ratified: `supabase_location_repository.dart` (contract replacement path), `supabase/tests/30_rls.sql` and `40_functions.sql` (pre-existing assertions invalidated by the frozen authorization change; the client-denied assertion was strengthened to `42501`), `supabase/tests/README.md` (migration chain now 13 + files `63/70/72`). **Not ratified:** the `flutter build apk --debug` run by the Android workstream (contract rule 10). It is recorded as a compile-level check only and is not counted as test evidence in `regression-matrix.md` §1; the coordinator ran the authoritative build once. |
| F5 "dedupe `enforcementMode()`" | **Deferred, accepted risk** | Two helpers (`PolicyApplier.kt`, `GuardianService.kt`) remain. Consolidating them touches two owned native files and carries Kotlin regression risk that cannot be validated here (Kotlin suite `BLOCKED`), so it moves to the Phase 3 enforcement work. |
| F5 "`session_nonce` unwritten/unused" | **Deferred** | Nonce validation was scoped out of Phase 1; the column is documented as reserved in the contract. Replay protection for signals is the unique `(session_id, sequence)` index added in migration 2. |

**Still open from this report** (carried into `remaining-gaps.md`)

- F3 wiring tests: handler-level proof that `index.ts` calls each tested pure module, and a repository
  test for `delete_zone`. The review's point stands — the current Deno suites would still pass if the
  wiring were reverted.
- F5: parent export is family-scoped and child `retention_report` returns family-wide counts; both need
  explicit product wording.
- Kotlin JVM tests `BLOCKED — cross-drive Gradle`.
- No hosted or device runtime evidence — unchanged and expected: nothing was deployed or applied.

**Tree/snapshot honesty.** `regression-matrix.md` §1 names the commit and tree it tested; §6 there
records the post-verification delta (three constructor-style edits, `supabase/config.toml`, and the two
contract/manifest doc fixes) with the targeted 24-test re-run that covers it. The full suite, Deno
suite, SQL chain and APK build were not re-run after that delta because no production logic changed.