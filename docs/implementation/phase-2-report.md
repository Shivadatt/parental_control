# Phase 2 — Dashboard & Family Management Consolidation: implementation report

Written 2026-11-02. Companions: `phase-2-governance.md` (rule compliance, ratification, Kotlin
follow-ups), `phase-2-regression-matrix.md` (evidence), `phase-2-open-gaps.md` (what is still not
true). Nothing in this file describes deployed production behaviour: see §7.

## 1. Exact starting state

Measured before the first Phase 2 edit.

| Item | Value | Command |
|---|---|---|
| Branch | `main` | `git rev-parse --abbrev-ref HEAD` |
| HEAD | `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2` — "chore: generate build artifacts and configure project files", 2026-10-30 19:22 +0530 | `git rev-parse HEAD`, `git log -1` |
| Remote | `origin` = `https://github.com/Shivadatt/parental_control.git`; `origin/main` = `8da1de7` (local `main` is level with it) | `git remote -v`, `git for-each-ref` |
| Other refs | `backup-main-before-cleanup` `20a6c45`, `backup/local-main-before-sync` `295b6b5`, `backup/pre-cleanup-main` `cf4c7d4`, `test-cleanup` `20a6c45` | `git for-each-ref` |
| Working tree | 34 files changed vs HEAD, **+1711 / −116, all of it already in the index**; nothing unstaged, nothing untracked | `git diff --cached --stat`, `git status --short` |
| Phase 1 code | already committed at HEAD — `supabase/functions/family-admin/authorization.ts` and `supabase/migrations/20261030000200_phase1_authorization.sql` both appear in `git ls-tree -r --name-only HEAD` | `git ls-tree` |
| Hooks | none configured (only `filter.lfs.*` in git config) | `git config --get-regexp '^hooks\.'` |

Two references supplied in the Phase 2 brief do **not** resolve in this clone:
`2a0209f` (the Phase 0 frozen baseline, also recorded in `baseline.md:12`) and `8ebb73c` (the Phase 1
independent review). `git cat-file -t` fails for both and `git rev-list --all | grep -cE
'^(2a0209|8ebb73)'` returns 0. The brief instructs "never reset to either commit"; that was honoured
trivially, but the ancestry of the Phase 0 baseline cannot be proven here — recorded as GOV-01 in
`phase-2-open-gaps.md`.

## 2. Exact final state

| Item | Value | Command |
|---|---|---|
| Branch / HEAD | unchanged: `main` @ `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2`; the newest `git reflog` entry is still the 2026-10-30 commit | `git rev-parse HEAD`, `git reflog` |
| Commits, branches, pushes | **none created** in this phase | no `git commit` / `git branch` / `git push` was run |
| Total Phase 2 delta | **47 files changed vs HEAD** — 9 new (`A`) and 38 modified (`M`); **+2660 / −154** at the penultimate measurement, the closing sentence itself adds ~2 lines | `git diff HEAD --shortstat`, `git diff HEAD --name-status` |
| Unstaged at close | **4 doc files** — the four Phase 2 documents were re-edited after the index caught up, so `git diff` (worktree vs index) shows 28 insertions / 13 deletions still awaiting refresh. Nothing is untracked and nothing outside the Phase 2 set is involved | `git status --short` (5 `A`, 4 `AM`, 38 `M`), `git diff --stat` |
| `git add` | never run by a workstream. The IDE refreshes the index after each edit, so the index briefly lags the worktree; `git diff HEAD` — worktree against HEAD — is therefore the authoritative Phase 2 figure above. Because these closing sentences are themselves doc edits, the insertions count moves by a few lines after this measurement — re-measure rather than quote it as fixed | observation, §1 note |

New files (9): `docs/implementation/phase-2-governance.md`, `phase-2-report.md`,
`phase-2-regression-matrix.md`, `phase-2-open-gaps.md`,
`supabase/functions/handler_wiring_test.ts`, `test/data/safe_zone_delete_wiring_test.dart`,
`test/features/devices/device_presence_consistency_test.dart`,
`test/features/safe_zones/safe_zones_authorization_test.dart`,
`test/features/settings/export_result_dialog_test.dart`.
One Phase 1 document was amended in place rather than rewritten: `regression-matrix.md:24` carries a
dated marker because its documented Deno command no longer runs (DOC-01).

The index also carries Phase 1 work; §2 counts only the delta against HEAD, i.e. Phase 2's own edits.

## 3. Workstream A — dashboard and device-health consolidation (§3 of the brief, reqs 1–10)

One vocabulary, no second definition of online/offline:

- The model remains the single source: `Device.onlineWindow` (12 min) and `stalledWindow` (30 min)
  at `lib/data/models/device.dart:371,376`, `syncHealth` at `:391-397`, `isOnline` / `isSyncStalled`
  at `:399-401`, `lastSeenAgeLabel` at `:405-413`, `statusLabel` at `:420-431`. `statusLabel` gained a
  fourth value, `'Never synced'` (`:423`), so a device that never reported is no longer shown as
  offline.
- `lib/features/devices/device_presentation.dart:35-52` now owns the shared `presenceChip()` /
  `presenceTone()`. `presenceTone` reads `isRevoked`, then `!isActive`, then `syncHealth` — so a
  pending-enrollment device cannot be tinted green on any screen.
- Every presence site calls it: `parent_dashboard_tab.dart:251`, `parent_devices_tab.dart:168`,
  `device_detail_page.dart:196`, `family_page.dart:537`, and — closed in this phase —
  `lib/features/child/tabs/child_home_tab.dart:299` (`trailing: presenceChip(current)`). The child
  tab's private `_deviceTone()` helper and its hand-built `StatusChip` were deleted.
- The tone→colour rule was extracted once: `statusToneColor()` at
  `lib/core/widgets/status_chip.dart:9`, used by `StatusChip._foreground` (`:36`) and by the
  dashboard avatar tint (`parent_dashboard_tab.dart:219-224`), which previously re-derived presence
  for itself.
- Age display: `child_home_tab.dart:308-314` now uses `current.lastSeenAgeLabel` instead of a
  hand-built `relativeTime()` string.
- **Stale-response protection** (req 9) in `dashboard_controller.dart` and `devices_controller.dart`:
  `_isStillCurrent(familyId)` (checks `!_isClosed` and that the session still holds that family) is
  tested after every await; `_reloadRequested` + a `finally` that re-enters `_fetch` fold a reload
  requested mid-flight; `_isClosed` is set in `onClose()`. The active-family resolution was also fixed:
  a family fetched in the background no longer clobbers one the session chose while the request was in
  flight (`activeFamily = _session.activeFamily.value ?? resolved`, then write only if the session is
  still empty).
  Residual, recorded as UI-02: the `catch`/`finally` writes in those two controllers are still
  unguarded by `_isStillCurrent`.

## 4. Workstream B — family management (§4, 4.1–4.4)

**4.1 Family information.** `lib/features/family/controllers/family_controller.dart` loads members,
devices and pairing requests (`_loadAuxiliary` at `:177`, `retryAuxiliary` at `:201`, `isAuxLoading` /
`auxError` at `:39-40`), so empty, loading, error and retry are separate states; `family_page.dart`
renders the family, the owner/parent distinction, the child accounts, per-device health through
`presenceChip` (`:537`) and pending pairing requests. Covered by
`test/features/family/family_controller_test.dart` (+92) and `family_page_test.dart` (+134).

**4.2 Safe Zone deletion.** The client calls the server-authorized `family-admin` action `delete_zone`
(`supabase_location_repository.dart`), never a direct `safe_zones` DELETE. `safe_zones_controller.dart`
gates on `canManage` (`:40`) before offering the action (`:155`), confirms first (`safe_zones_page.dart`),
refreshes on a server-confirmed deletion and surfaces the server error otherwise. `canManage` is a UX
gate only — the authoritative check is `canDeleteZone` + `assertFamilyParent` in
`supabase/functions/family-admin/`, proven in SQL by `supabase/tests/70_phase1_authorization.sql`.
Tested by `test/features/safe_zones/safe_zones_authorization_test.dart` (+184) and the repository
wiring proof `test/data/safe_zone_delete_wiring_test.dart` (+143).

**4.3 Data purge (owner-only).** The purge confirmation text states the cutoff the *device knows* and
explicitly refuses to promise what the server will delete
(`lib/features/audit_logs/audit_logs_page.dart`): "…the server applies its own stored window and may
keep more, never less. This cannot be undone. The audit log is append-only, so it is not purged. Only
the count the server reports is shown afterwards." The numbers come from
`knownLocationRetentionDays` / `knownUsageRetentionDays`, which mirror the server rule instead of
inventing a client floor (`audit_logs_controller.dart`): `_retentionFloor()` falls back to **30 / 90**
when a stored window is missing or non-positive, the same substitution
`familySettings()` performs at `supabase/functions/family-admin/index.ts:25-43`; `purge_data` then
clamps each table with `Math.max(olderThanDays, …)` (`:252-259`). `owner_required`/403 is handled as a
distinct failure, and no service-role credential appears in the client.

**4.4 Account privacy.** Settings shows real export (file + clipboard), two-step deletion and
retention windows/counts (`settings_body.dart`, +67). Two inaccurate claims were fixed:
- the export dialog (`lib/features/settings/export_result_dialog.dart`) no longer says other members'
  private data are never included — a parent export **is** family-scoped, exactly as §4.4 warned; and
  it no longer claims credential material is "never selected, whatever the role" without qualification:
  `DEVICE_COLUMNS` (`supabase/functions/account/index.ts:56-79`) does select `installation_id` (`:60`)
  while never selecting `secret_hash`;
- the sweep note (`settings_body.dart`) now states that the sweep timestamp is one global marker row
  (`family_id IS NULL` in `20261030000300_retention_sweep.sql:165-174`), not this family's run time.
Scoping preserved: child export → own devices (`account/index.ts:155`) and rows by
`device_id in childDeviceIds`; parent export → `family_id in familyIds` (`:157`, `:176`); audit rows →
`actor_user_id = uid OR device_id in (...)` (`:195-197`).

## 5. Workstream C — enforcement honesty (§5, reqs 1–8)

Client-side only; `enforcement.ts` and the Kotlin counters were not touched.

- Req 1 (how many are actually enforced): the policy card quotes the device's own
  `applied_count`/`desired_count` ("Applied to N of M apps") only when the report proves it.
- Reqs 2/3/4: unsupported, failed and pending are rendered from separate branches; per-package failure
  reasons come from the device report (`report.failures`), never invented.
- Req 6/7, the two defects this workstream removed:
  - an `enforced` status with `desired_count == 0` is **not** a success. The UI now requires
    `provenOnApps = proven && (report?.desiredCount ?? 0) > 0` and shows an info banner ("the device
    reported an empty app set, so there was nothing to suspend"), matching the server rule in
    `supabase/functions/device-command/enforcement.ts:104-112` (`targetsApps && desiredCount === 0` →
    `pending` / `no_apps_suspended`) and `provesFullEnforcement` in
    `lib/data/models/policy_enforcement.dart:58-62`;
  - a queued command keeps `BannerTone.info` — it is never a success badge; the unsupported banner
    quotes the count the device reported instead of asserting zero.
- Req 5: the Device Owner prerequisite stays an explicit banner (`PolicyEnforcementReport.unsupportedMessage`),
  and enrollment is never automated or bypassed (req 8 keeps ack/policy-version logic intact —
  `policy_version` still advances only on `decision.advancePolicyVersion`).

## 6. Workstream D — integration / wiring tests (§6, 6.1–6.6)

| Brief | Delivered | Status |
|---|---|---|
| 6.1 device-command | `handler_wiring_test.ts` pins the `decideEnforcement(...)` call site, one decision site only, `enforcement_status: decision.status` and version advance; `enforcement_test.ts` covers enforced / unsupported / failed / pending / empty-target | **PASS** |
| 6.2 family-admin | wiring proof for `canDeleteZone` / `canPurge` / `assertFamilyParent` / `assertFamilyOwner`, with per-`case` scoping and call-ordering assertions; behaviour cases live in `authorization_test.ts` (4) and `70_phase1_authorization.sql` | **PASS** |
| 6.3 remote-session | wiring proof for `withAbandonedSweep`, `acceptPatch/declinePatch`, terminal precedence, compare-and-set update; behaviour via `guard_test.ts` (11) and `lifecycle_test.ts` (8, dependency-injected fakes) | **PASS** |
| 6.4 account | wiring proof for `validateDeleteAccountInput`, `findDeletionBlocker`, `retentionFromSettings`, `buildFamilyRetentionReport` and the three dispatch cases; behaviour via `validation_test.ts` (7), `retention_test.ts` (6) | **PASS** |
| 6.5 safe-zone repository | `test/data/safe_zone_delete_wiring_test.dart` records what the repository puts on the wire: function `family-admin`, action `delete_zone`, the exact zone id, error propagation, and no direct `safe_zones` DELETE | **PASS** |
| 6.6 SQL row-count | `supabase/tests/30_rls.sql:110-134`: positive control that the inserted zone is readable (`:115`), client DELETE denied with `42501` (`:122`), `service_role` delete reports exactly **one** row (`:129`), the row is gone (`:134`) | **PASS** |

**Deviation from the brief, recorded honestly.** §6 asks for handler-level tests "with injected
dependencies/fakes". Every `index.ts` is a bare top-level `Deno.serve(...)` with no exported handler,
and the modules it calls build a service-role client from `SUPABASE_URL` /
`SUPABASE_SERVICE_ROLE_KEY`, so 6.1–6.4 could not be executed against the real handler without binding
a port and faking PostgREST. They are source-level wiring proofs at the call site instead
(`handler_wiring_test.ts` documents this in its header comment): a refactor that drops the call, or
re-implements the rule inline, fails the test — but a handler that calls the right module with
arguments built from a wrong variable would not. Only `remote-session/lifecycle_test.ts` achieves true
injection, because that module was written export-first. Tracked as TEST-01.

Consequence: `deno test supabase/functions` (the command documented at
`docs/implementation/regression-matrix.md:24`) now **fails** without `--allow-read` — measured
2026-11-02: `FAILED | 83 passed | 5 failed`, exit 1. The correct invocation is
`deno test --allow-read supabase/functions/`. Tracked as DOC-01.

## 7. Workstream E — governance (§7) and boundaries (§8)

`phase-2-governance.md` records: the baseline table above, the Phase 1 amendment ratification status
(D1, `unlink_child`, out-of-ownership edits — coordinator-ratified, no owner signature), every
cross-workstream path with its Phase 1 owner, the historical unauthorized
`flutter build apk --debug` as **RULE-10 BREACH — NOT RATIFIED** and compile-level only, the two
duplicated Kotlin `enforcementMode()` helpers left deliberately unconsolidated, Kotlin JVM tests as
`BLOCKED`, and seven dated in-place corrections to the stale `_work/*` notes
(`session.md`, `security.md`, `contracts.md`, `lifecycle.md`, `enforcement.md`, `audio.md`,
`android.md`).

Boundaries held: no migration applied, no Edge Function deployed, no hosted secret/auth/data change,
no Supabase CLI invocation (the npm-installed binary was never called), dashboard used read-only per
the owner's standing instruction, no `flutter build` of any kind in Phase 2 (`git diff HEAD --name-only
-- android/` returns nothing, so no Android-source compile claim is made for this phase), and no
unrelated redesign — Phase 2 removed second implementations rather than adding any.

## 8. Verification

See `phase-2-regression-matrix.md`. Headline — `dart analyze`, `flutter test` and the Deno suite were
all re-run on 2026-11-02 after the final document edits:
`dart analyze` clean; `flutter test` **+355, all passed**; `deno test --allow-read
supabase/functions/` **88 passed / 0 failed** across 11 files. The SQL chain is the run recorded in
the matrix: `EXIT=0` with no `ERROR` and no `ASSERTION FAILED` on a fresh disposable PostgreSQL 16.9
database, executed before those throwaway databases were dropped at close (§8 of the matrix); it was
not re-run after the final doc-only edits, which touch no SQL.
Kotlin: `BLOCKED — environment`, not re-attempted. Runtime, emulator and physical-device behaviour:
`NOT TESTED` — Phase 2 ran no app.
