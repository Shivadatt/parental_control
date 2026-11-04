# Phase 2 — regression matrix

All rows measured **2026-11-02** by the Phase 2 verification workstream. The static, unit and Deno
rows were re-executed after the final document edits (analyzer clean, `+355`, `88 | 0 failed`, and the
targeted re-runs of row 18); the SQL row is the fresh-database run recorded below, executed before its
throwaway databases were dropped at close, and the doc-only edits that followed touch no SQL.
Discipline: `PASS` requires an executed check with a captured result; `NOT TESTED` means the claim was
never exercised here; `BLOCKED` means the environment cannot run the check. An expected result is not
an observed result. Severities used in `phase-2-open-gaps.md`: **P0** data/authority loss, **P1**
feature incorrect on the happy path, **P2** honest-but-incomplete or unverifiable, **P3** wording.

## 1. Executed checks

| Level | Check | Exact command | Result | Evidence |
|---|---|---|---|---|
| Static | Dart analyzer, whole repo | `./.fvm/flutter_sdk/bin/dart analyze` | **PASS** | `No issues found!`, exit 0. Re-run after the presence consolidation, which removed the last unused import (`child_home_tab.dart` had one transiently). |
| Unit | Flutter full suite | `./.fvm/flutter_sdk/bin/flutter test` | **PASS** | **`+355`, "All tests passed!"**, exit 0 (final re-run 00:23). 48 test files under `test/`. |
| Unit | Deno suite, all functions | `/c/Users/ASUS/AppData/Local/Microsoft/WinGet/Links/deno test --allow-read supabase/functions/` | **PASS** | **`ok \| 88 passed \| 0 failed`** across 11 files: `_shared` 36 (enrollment 3, policy 8, turn 8, validation 17), `account` 13 (retention 6, validation 7), `device-command/enforcement_test` 11, `family-admin/authorization_test` 4, `handler_wiring_test` 5, `remote-session` 19 (guard 11, lifecycle 8). |
| Static | Deno type-check of the four handlers | `deno check supabase/functions/{account,cron,family-admin,remote-session}/index.ts` | **PASS** (Phase 1, unchanged) | Phase 2 edited no `index.ts`; `git diff HEAD --name-only -- supabase/functions/` lists only `handler_wiring_test.ts`. Carried as `regression-matrix.md:21` evidence, not re-run here. |
| Integration | SQL authorization suite, fresh DB | `createdb parentcontrol_p2_final3` then one `psql -v ON_ERROR_STOP=1` chain of the 28 `-f` files in the exact `supabase/tests/README.md:32-60` order (2 stubs, 13 migrations, 13 test files) against local PostgreSQL 16.9 on port 55440 | **PASS** | **`SQL_EXIT=0`**, `grep -c "ASSERTION FAILED"` = **0**, no `psql:` `ERROR` line (the single case-insensitive "error" hit is the `error_message`/`last_error` keys inside a JSON test payload at log line 13). 19 public tables. Success banners in `.tools/sql-final3.log:131-135`: `ALL CONCURRENCY TESTS PASSED`, `ALL PARENT-CONTROLLED LIFETIME TESTS PASSED`, `ALL CONSENTED-SESSION SIGNALING TESTS PASSED`, `ALL ABANDONED SESSION SWEEP TESTS PASSED`, `ALL PHASE 1 AUTHORIZATION TESTS PASSED`. |
| Unit | Targeted re-runs of the changed areas | `flutter test test/features/devices/device_presence_consistency_test.dart` and `flutter test test/features/settings/export_result_dialog_test.dart`; `deno test --allow-read supabase/functions/handler_wiring_test.ts` | **PASS** | 7/7, 4/4 and 5/5 respectively. |
| Negative control | Does the documented Deno command still work? | `deno test supabase/functions` (no flag) | **FAILS — expected, and recorded** | `FAILED \| 83 passed \| 5 failed`, exit 1; the 5 failures are all `handler_wiring_test.ts` (`--allow-read` is required to read the handler sources it pins). Gap DOC-01. |
| Negative control | Does the SQL chain detect a missing precondition? | first attempt, `05_realtime_stub.sql` omitted by the operator | **Correctly fails** | `psql:supabase/tests/50_realtime_policy.sql:25: ERROR: ASSERTION FAILED: the private channel policy was created`, `SQL_EXIT=3`. Operator error, not a repository defect; it also confirms `supabase/tests/README.md:29-30` ("fixtures use fixed UUIDs and are not re-runnable" — a fresh database is required for every run). |
| Runtime | App on emulator or device | — | **NOT TESTED** | Phase 2 launched no app, no emulator, no device. Presence, enforcement, purge and family UI are proven at widget/unit level only. |
| Integration | Hosted Edge Function / hosted SQL behaviour | — | **NOT TESTED** | Phase 2 performs no hosted operation (§8 of the brief; owner rule: browser dashboard read-only, never the CLI). |
| Unit | Kotlin JVM tests | `./android/gradlew test` | **BLOCKED — environment** | Cross-drive Gradle (toolchain working set on `C:`, project on `D:`). **Not re-attempted in Phase 2.** Five test files under `android/app/src/test/kotlin/**` therefore remain unexecuted; see `phase-2-governance.md` §5.2. |
| Build | `flutter build` (any kind) | — | **NOT RUN — by rule** | Rule 10: the verification workstream owns the authoritative build, and Phase 2 needed no Android compile claim: `git diff HEAD --name-only -- android/` returns nothing. |

## 2. Workstream A — dashboard and device-health consolidation

| Brief requirement | Evidence | Status |
|---|---|---|
| Reqs 1–3: reuse `syncHealth` / `onlineWindow` / timestamps; no second definition of online/offline | `test/data/device_model_test.dart` (+12) exercises the model windows (12/30 min) and clock-skew clamp; the only remaining UI entry points are `presenceChip` / `presenceTone` (`device_presentation.dart:35-52`) | **PASS** |
| Req 4: remove contradictory status calculations from dashboard widgets | The child tab's `_deviceTone()` helper and the dashboard avatar's private tone logic are gone; `test/features/devices/device_presence_consistency_test.dart` asserts `child_home_tab.dart` contains `trailing: presenceChip(current)` and no `_deviceTone` (source-level guard, same technique as `handler_wiring_test.ts`) | **PASS** |
| Req 5: consistent labels across Parent Dashboard, Devices list, Device Detail | `device_presence_consistency_test.dart`: four states (healthy / stalled / offline / never synced) rendered by the dashboard and the devices tab produce the same `statusLabel` text; "a stalled device is never called online on either screen" | **PASS** |
| Required state `Never synced` | `device.dart:423` + the `never synced` case in the consistency test | **PASS** |
| Reqs 6–7: last successful sync time, clear age label | same test asserts `lastSeenAgeLabel` text on both screens; `child_home_tab.dart:308-314` uses it | **PASS** |
| Req 8: loading / empty / error / retry states | `test/features/dashboard/dashboard_controller_test.dart` (+53) and `parent_dashboard_tab_test.dart` (+21) cover fetch, failure and empty family; retry is the existing `refresh()` path | **PASS** (widget level) |
| Req 9: stale async responses must not overwrite newer device state | `_isStillCurrent(familyId)` guards after every await in both controllers, `_isClosed` blocks post-dispose writes, `_reloadRequested` + `finally` re-entry folds a mid-flight reload, and the active-family resolution no longer clobbers a family chosen concurrently | **PASS** (unit) / **P2 residual** — the `catch` and `finally` assignments still write `error`/`isLoading` unguarded (UI-02) |
| Req 10: keep polling and recovery consistent with Phase 1 | `refreshInterval` stays injectable (`null` in tests); no polling constant changed | **PASS** |
| "never claim online merely because a record exists or an old heartbeat was received" | `presenceTone` now refuses success for `!isActive` and for anything but `DeviceSyncHealth.healthy`; the `unenrolled/revoked device is non-green` case is in the consistency test | **PASS** |

## 3. Workstream B — family management

| Brief item | Evidence | Status |
|---|---|---|
| 4.1 family, owner/parent, children, device health, invitations, empty/loading/error/retry | `family_controller_test.dart` (+92), `family_page_test.dart` (+134); devices rendered through `presenceChip` (`family_page.dart:537`) | **PASS** (widget level). No hosted membership data was inspected, so real multi-family rows remain **NOT TESTED** |
| 4.2 parent-only, family-scoped deletion through `family-admin delete_zone` | server: `70_phase1_authorization.sql` (banner `ALL PHASE 1 AUTHORIZATION TESTS PASSED`) + `30_rls.sql:119-134` (client `42501`, `service_role` deletes exactly 1 row) + `handler_wiring_test.ts` `caseBody`/`assertOrder` scoping; client: `safe_zones_authorization_test.dart` (+184) | **PASS** locally. **NOT TESTED** against the hosted project — the `delete_zone` action is **local-only** (migrations `20261030000100/200/300` are undeployed) |
| 4.2 confirm before delete, refresh after confirmed delete, handle 403/404/network/server | `safe_zones_page.dart` confirmation + `safe_zones_controller.deleteZone` (`:221`) result handling; `safe_zone_delete_wiring_test.dart` proves server-error propagation and that no direct `safe_zones` DELETE is issued | **PASS** (widget/repository level) |
| 4.3 Owner vs ordinary Parent distinguished; exact retention period and impact shown before confirmation; explicit confirm; success only after server confirms; `owner_required` handled | `audit_logs_page.dart` copy quotes the cutoffs the device knows and states the server may keep more, names the append-only audit log as not purged, and promises only the server-reported count; server rule mirrored by `_retentionFloor()` (30/90) vs `family-admin/index.ts:25-43` and clamps at `:252-259`; owner gate asserted in SQL via `assertFamilyOwner` + `owner_required`/403 | **PASS** locally. Purge itself remains **local-only** and was never executed against hosted data |
| 4.3 "never expose service-role credentials or bypass server checks" | no client path reads `SUPABASE_SERVICE_ROLE_KEY`; `grep` of `lib/` for the key name returns nothing | **PASS** (static) |
| 4.4 export / deletion / retention UI with confirmation and error handling | `settings_body.dart` (+67), `account_privacy_repository.dart` (+6), `export_result_dialog_test.dart` (4 tests) | **PASS** locally. `account` Edge Function is **not deployed**, so export/delete/retention_report are **local-only** |
| 4.4 "do not assume parent exports contain only personal data" | the dialog now says a parent export is **family-scoped, not personal-only**, including rows recorded about other members; the child wording states its own-device scope and that parent actions on those devices are included; both anti-quotes of the previous over-claim are asserted in the test | **PASS** |
| 4.4 child `retention_report` scope | unchanged server behaviour (family-wide counts); the gap is recorded as PRIV-01, not silently described as child-only | **P2, owner decision** |

## 4. Workstream C — enforcement honesty

| Brief requirement | Evidence | Status |
|---|---|---|
| 1: how many apps are actually enforced | `app_restrictions_page_test.dart`: "proven enforcement shows Applied to N of M apps" from the device's own counts | **PASS** |
| 2/3/4: unsupported, failed and pending shown separately | separate branches + the unsupported test ("unsupported enforcement shows the explicit banner"), the failed-count test ("the unsupported banner quotes the count the device reported" → finds `reported 1 applied apps`, not `0`), and the queued-command test | **PASS** |
| 5: Device Owner prerequisite displayed | `PolicyEnforcementReport.unsupportedMessage` banner retained and extended with the reported count | **PASS** |
| 6: never claim blocked/suspended unless native Device Owner confirms | `provenOnApps = proven && desiredCount > 0`; empty-target case shows "reported an empty app set … No app is blocked by this selection" and asserts the success sentence is absent | **PASS** — matches the server rule at `enforcement.ts:104-112` |
| 7: no unsupported state hidden behind a success badge | "a queued command is never shown as a success banner" finds the `InfoBanner` carrying `syncMessage` and asserts `banner.tone == BannerTone.info` | **PASS** |
| 8: preserve acknowledgement and policy-version logic | `handler_wiring_test.ts` pins `enforcement_status: decision.status` and `decision.advancePolicyVersion`, with exactly one `decideEnforcement(` call site; `enforcement_test.ts` (11) covers the verdicts | **PASS** |
| Req: real device enforcement on Android | — | **NOT TESTED** — no device was used; Kotlin `BLOCKED`. Device Owner provisioning remains an explicit gap; nothing in Phase 2 attempts it |

## 5. Workstream D — required integration/wiring tests

| Brief item | Evidence | Status |
|---|---|---|
| 6.1 device-command | wiring: import of `decideEnforcement`/`policyTargetsApps`, the call shape, single decision site, `enforcement_status: decision.status`, `advancePolicyVersion`, and ordering (decision before the write). Behaviour: `enforcement_test.ts` 11 cases incl. unsupported, missing counts, expired ack, empty target set, partial apply | **PASS**, with the injection deviation recorded in `phase-2-report.md` §6 (TEST-01) |
| 6.2 family-admin | wiring: `canDeleteZone`/`canPurge` gating, `assertFamilyParent` scoped to the zone's own family, `assertFamilyOwner` for purge (count = 1, ordering before the cutoff maths), the service-role delete scoped by id **and** family, audit only after a real deletion, and the `owner_required`/403 text read from `_shared/auth.ts`. Behaviour: `authorization_test.ts` 4 + `70_phase1_authorization.sql` (wrong family, non-parent, non-owner purge, missing zone) | **PASS** |
| 6.3 remote-session | wiring: `withAbandonedSweep` import + use on the request path, `acceptPatch/declinePatch`, accepted-session idempotence, terminal rejection before any update, compare-and-set `.eq("status","requested")`. Behaviour: `guard_test.ts` 11, `lifecycle_test.ts` 8 (sweep available / function missing / sweep throws / unexpected payload) | **PASS** |
| 6.4 account | wiring: `validateDeleteAccountInput`, `findDeletionBlocker`, `retentionFromSettings`, `buildFamilyRetentionReport` and the three dispatch cases. Behaviour: `validation_test.ts` 7, `retention_test.ts` 6 | **PASS** |
| 6.5 safe-zone repository | `test/data/safe_zone_delete_wiring_test.dart` captures the invocation: function name `family-admin`, body action `delete_zone`, the exact zone id, error propagation, and the absence of any direct `safe_zones` DELETE | **PASS** |
| 6.6 SQL row-count | `30_rls.sql:110` positive control → `:115` "the inserted zone is readable before deletion"; `:122` client DELETE is `42501`-denied; `:129` `service_role` deletes **exactly one** row; `:134` count falls to 0. Existing security assertions were strengthened, not weakened | **PASS** |

## 6. Workstream E — governance and documentation

| Brief item | Evidence | Status |
|---|---|---|
| 1 coordinator amendment remains ratified | `phase-2-governance.md` §2, citing `phase-1-report.md:363`; `_work/contracts.md` and `_work/coordinator-contract.md:41-43` cross-referenced. No owner signature exists → GOV-02 | **PASS** (record) / **P2** (owner ratification) |
| 2 record all ratified cross-workstream edits | `phase-2-governance.md` §3 table, path by path against the Phase 1 ownership table (`_work/coordinator-contract.md:121-132`) | **PASS** |
| 3 correct stale workstream notes | seven files carry dated `Phase 2 correction (2026-11-02)` markers: `session.md`, `security.md`, `contracts.md`, `lifecycle.md`, `enforcement.md`, `audio.md`, `android.md`. Each keeps the original claim visible | **PASS** |
| 4 record the unauthorized build as a breach, not evidence | `phase-2-governance.md` §4; the same wording added to `_work/android.md` under "Validation"; log integrity confirmed (`.tools/verify-apk-20261030.log`, 1126 bytes, contains `√ Built build\app\outputs\flutter-apk\app-debug.apk` / `EXIT=0`) | **PASS** |
| 5 document the duplicated Kotlin `enforcementMode()` | `phase-2-governance.md` §5.1 (sites `PolicyApplier.kt:229-234` → call `:376`; `GuardianService.kt:668-674` → call `:503`). **Not consolidated**, exactly as the brief permits when no Kotlin validation environment exists | **PASS** (record) / Kotlin **BLOCKED** |

## 7. Explicitly NOT established by this phase

1. That any Phase 1 or Phase 2 server behaviour works on the hosted project. Migrations
   `20261030000100`, `20261030000200`, `20261030000300` are unapplied and no Edge Function was
   deployed; the owner's dashboard screenshot of 2026-11-02 still shows **No migrations** / **No
   backups** for `parent-control-prod` (point-in-time, decays on deploy).
2. That a device enforces anything. `enforcement_mode`/counts are read from reports; the Kotlin that
   produces them was not compiled or tested in Phase 2.
3. That the UI is correct on a real screen — widget tests use pumped frames, not a device.
4. That a Flutter build succeeds after Phase 2. Deliberate: rule 10 plus no `android/**` delta.
5. Kotlin correctness of any kind (`BLOCKED — environment`, five unexecuted test files).
6. Ancestry proof of the Phase 0 baseline commit (GOV-01).

## 8. Toolchain used

FVM Flutter 3.44.6 / Dart 3.12.2 via `.fvm/flutter_sdk/bin/{flutter,dart}`; Deno 2.9.4;
PostgreSQL 16.9 unpacked under `.tools/pgsql16` with a throwaway cluster at `.tools/pgdata_p2` on port
55440 (trust auth, `postgres` superuser). `.tools/` is gitignored (`.gitignore:16`), so the logs cited
above exist only on this workstation — they are evidence, not artifacts of the repository.

Cleanup state at close: the server had stopped on its own before the first final `dropdb` attempt (which
returned `Connection refused`), so the cluster was restarted with `pg_ctl`, the four throwaway databases
of this session (`parentcontrol_p2`, `parentcontrol_p2_final`, `_final2`, `_final3`) were dropped —
`pg_database` then listed only `postgres`, `template0`, `template1` — and the server was stopped again
with `pg_ctl -m fast`; port 55440 has no listener. The empty cluster directory itself remains under
gitignored `.tools/pgdata_p2` on this workstation. No repository file, hosted Supabase object or Phase
1/2 evidence depends on any of it, and the authoritative SQL run completed before the server stopped
(`EXIT=0`, `.tools/sql-final3.log`).
