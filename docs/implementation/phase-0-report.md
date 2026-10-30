# Phase 0 report — contracts workstream

Phase 0 turned the audit into four frozen documents: `baseline.md`, `api-contract.md`,
`feature-ownership.md`, `dependency-map.md`. Nothing outside `docs/implementation/` was modified; no
git write, no Supabase command, no deployment, no `flutter test`/`flutter build`.

## 1. What was validated, and how

| Claim | Method | Result |
|---|---|---|
| Branch / HEAD / tree state | `git rev-parse`, `git status --porcelain` | `main`, `2a0209f`; see §5 on the moving tree |
| Toolchain versions | `.fvm/flutter_sdk/bin/flutter --version`, `dart --version`, `deno --version`, `node --version` | Flutter 3.44.6, Dart 3.12.2, Deno 2.9.4, Node v24.14.0 |
| 26 routes | read `lib/app/routes/app_routes.dart:4-31` and counted `GetPage`s in `app_pages.dart:56-186` | 26 and 26; one page (`configuration`) has no binding |
| Route → controller → repository | read all 17 `*binding.dart` files and grepped each controller for repository types | table in `api-contract.md` §1; `ParentShellController` has no repository (tab index only) |
| 9 Edge Functions, 35 actions | grepped `switch (action)` / `case "…"` per function and read each action body | 2+9+1+4+1+3+5+7+2 = 34 at HEAD; 35 including the in-flight `delete_zone` |
| Request/response shapes | read the `readX(body.…)` calls and `return ok(…)` sites per action | `api-contract.md` §2 |
| 19 tables / 22 policies / 8 triggers | `grep -n "create table"` and `"create policy"` across `supabase/migrations/` | 18 + 1 = 19 tables; 21 + 1 realtime topic policy = 22; 8 `create trigger` |
| Realtime authorization | read `private.realtime_topic_allowed` (`rls.sql:295-332`) and the four `onPostgresChanges` subscriptions | 4 topics, 2 predicates; `device_commands` is published but never subscribed by Dart |
| Status vocabulary | read every `check (status in …)` in `core.sql` and the Dart mirrors | `api-contract.md` §5 |
| Phase 1 additions are genuinely absent at HEAD | `grep -rn "expire_abandoned\|sweep_sessions\|retention_sweep\|delete_zone\|syncHealth"` | zero hits at HEAD; `expire_abandoned_sessions` + `delete_zone` appear only in the in-flight working tree |
| Duplicate modules | unique top-level class names across `lib/`, model-class grep, binding grep | see §3 |
| Inventory citations | 25 rows re-read against the files (below) | 25/242 |

## 2. Inventory spot-check — 25 of 242 rows re-verified, 217 not re-verified

Rows were chosen across all four ID prefixes (FA 7, FB 7, FC 5, FD 6) and biased toward rows whose
status changes engineering priorities (BROKEN, PARTIALLY IMPLEMENTED, MISSING-with-citation).
**This is a sample, not a re-audit: 25/242 rows (10.3 %) were re-verified; the other 217 rows and
all 17 audit documents outside `00/01/03/04/06` were not re-checked in Phase 0.**

| Row | Claim | Verification | Discrepancy |
|---|---|---|---|
| FA-009 | 6-min `onlineWindow`, `isOnline`, `statusLabel` in `device.dart:293-380` | File exists (818 lines). 293 = `enum DeviceStatus`, 366 = `onlineWindow`, 368 = `isOnline`, 376 = `statusLabel`. Claim holds | Minor: range ends at 380, the getter closes at 381 (off-by-one) |
| FA-010 | "Last seen" row rendered at `parent_dashboard_tab.dart:259-264` | Range is a `KeyValueRow(` … `),` block inside the device card | none |
| FA-012 | Permission tiles at `device_detail_page.dart:326-366`, model at `device.dart:635-708` | Page range is `Widget _buildPermissionsCard(Device device)` — exact. Model range 635-708 is **`DeviceCommand.fromJson` + the start of the `Device` constructor**; the permission flags are at `device.dart:700-725` | **Yes — correct file, wrong sub-range** (about 60 of the 73 cited lines are device-command parsing). Conclusion of the row (permissions are a snapshot) still holds |
| FA-019 | "Today" usage segmented view at `screen_time_page.dart:215-250` | 215 = `label: 'Today',`; range ends at the "No per-app usage" empty state | none |
| FA-021 | Dashboard has **no** usage widget (`parent_dashboard_tab.dart:33-199`) | Range is `_buildBody`; `grep -i "usage\|screen time"` over the file returns zero hits | none (absence verified by search, as the row states) |
| FA-031 | Pairing request 20 s polling at `pairing_redeem_controller.dart:153-168` | 153 = `void _syncStatusPolling()`; method body is the polling loop | none |
| FA-042 | Alert history `limit 100` at `supabase_alert_repository.dart:25-42` | 25 = `fetchAlerts({`, parameter `int limit = 100`, `.limit(limit)` at 34 | none (citation uses a bare filename; resolves uniquely) |
| FB-004 | Consent handled in `respond()` at `remote_session_controller.dart:657-708` | 657 = `Future<bool> respond({required bool accept})`; body records consent then joins | none |
| FB-010 | ICE connection-state machine at `remote_session_controller.dart:1702-1966` | 1702 = `void _handleIceConnectionState(RTCIceConnectionState state)`; 264-line range ends at the next method boundary | none |
| FB-011 | Parent/child end path at `remote_session_controller.dart:2269-2323` | 2269 = `Future<bool> endSession()` | none |
| FB-016 | No screen-capture intent anywhere | `grep -ril "createScreenCaptureIntent"` over `lib/` and `android/` → zero hits; manifest has no `MediaProjection` service | none (absence claim, no citation given — expected for MISSING rows) |
| FB-028 | Request/session list at `remote_assistance_page.dart:110-143` | Range is a `PageSection(` block listing requests | none |
| FB-034 | `webrtc_signals` definition at `core.sql:358-370` | 358 = `create table public.webrtc_signals (`, 370 = the `(session_id, sequence)` index | none |
| FB-046 | Session lifetime model at `remote_session.dart:104-130` | 104 = the "deadline for a pending request" doc comment; 130 = `isServerActive` | none (migration cited by truncated name `20261028000200` — resolvable) |
| FC-005 | Real enforcement at `device_admin_service.dart:82-96` + `PolicyApplier.kt:94-133` | 82 = `isPackageSuspended`; `PolicyApplier.kt:94` = `if (desired.isNotEmpty() && !isOwner) {` — the Device-Owner gate the row relies on | none (this row's citations are not backticked; formatting differs from FA/FB rows but the facts check out) |
| FC-038 | Uninstall detection at `GuardianService.kt:396-422` + `functions.sql:677-699` | 396 = snapshot builder; 677 = `delete from public.device_apps where device_id = p_device_id;` (delete-then-insert) | none |
| FC-045 | No notification action/intent handler; manifest intent-filters at `:62-75` | 62-75 is a `<intent-filter>` with `MAIN`/`LAUNCHER` plus the auth callback only | none |
| FC-052 | No keyword management: `grep "keyword"` returns zero hits | Confirmed zero hits in `lib/`, `android/`, `supabase/`, `test/` | none |
| FC-070 | No local or cloud image detection | No camera-capture-to-analysis path in `lib/` or `android/`; only session-scoped camera | none (absence claim, no citation — consistent with MISSING) |
| FD-003 | No web mode fields: `device.dart:118-125`, `PolicyModels.kt:37-45` | 118-125 = `enforceAppBlocks` … `bedtimeEndMinutes`; `PolicyModels.kt:37` = `data class ChildPolicy(` to `bedtimeEndMinutes` — no web field in either | none |
| FD-016 | `usage_daily` is per package at `core.sql:226-246` | 226 = `-- usage_daily`, 228-246 the table + indexes, unique `(device_id, day, package_name)` | none |
| FD-022 | No browsing-history route, `app_routes.dart:4-32` | The file is 33 lines; 4-31 are the 26 route consts, 32 closes the class. No `/parent/history` | none (range includes the class close) |
| FD-027 | Latest fix at `location_page.dart:208-340` + native publish at `LocationTrackingService.kt:164-191` | 208 = `class _LatestFixCard`; 164 = `private fun publish(location: Location)` | none |
| FD-050 | Zone delete at `safe_zones_controller.dart:198-212` + `rls.sql:162-166` | 198 = `Future<bool> deleteZone(SafeZone zone)`, calls `_locationRepository.deleteSafeZone`; `rls.sql:162` = `create policy safe_zones_delete_parent` for DELETE | none at HEAD — but this policy is **dropped in Phase 1** (`20261030000200`), so the row's evidence becomes stale after Phase 1 |

Spot-check outcome: **23 of 25 rows stand as written; 1 has an imprecise line range (FA-012) and 1 is
about to be superseded by design (FD-050).** Systematic citation weaknesses found:

- FC and FD rows frequently cite bare basenames (`index.ts`, `core.sql`, `device.dart`,
  `screen_time_controller.dart`). They resolved uniquely in this sample, but `index.ts` matches
  9 files and `core.sql` is only unambiguous by convention. This is a documentation, not a factual,
  defect.
- Truncated migration names are used (`20261028000200:35-48`, `20261028000300:25-54`).
- MISSING rows with no citation (7 of the 25 checked: FB-016, FC-052, FC-070, …) can only be
  verified as absence by search; that is what was done.

## 3. Duplicate-module check

Method: enumerate every top-level class in `lib/`, count name collisions, then inspect the
capabilities the coordinator names explicitly (audio controller, device model), plus models,
repositories and local storage.

| Capability | Implementation | Duplicates? |
|---|---|---|
| Audio / session engine | `RemoteSessionController` (`lib/features/remote_assistance/remote_session_controller.dart:63`), one instance per session owned by `RemoteSessionRegistry` (`remote_session_registry.dart:23`) | **one** — the page and the child route both resolve the same controller through the registry (`child_session_binding.dart:29-40`); no second engine |
| Device model | `Device` (`lib/data/models/device.dart:312`) | **one** — `grep "class Device\b"` returns a single declaration |
| Session model / status enum | `RemoteSession`, `RemoteSessionStatus` (`lib/data/models/remote_session.dart:14,75`) | **one** each |
| Telemetry models | `UsageDaily`, `LocationEvent`, `SafeZone`, `SafetyAlert` all in `lib/data/models/telemetry.dart:3,125,161,268` | **one** each |
| Policy model | Dart `DevicePolicy` (`device.dart:243`); Kotlin `ChildPolicy` (`policy/PolicyModels.kt:37`) | **intentionally one per platform** — not a duplicate to merge, but the two must agree; enforcement owns both sides |
| Repositories | 11 files in `lib/data/repositories/` (1 contracts file + 10 implementations) | **one per table domain** — verified no two classes share a name (`grep "^class [A-Za-z]+" \| sort \| uniq -d` returns nothing) |
| Safe-zone delete | `LocationRepository.deleteSafeZone` — declared once (`repository_contracts.dart:151`), implemented once (`supabase_location_repository.dart:141`) | **one**; it is the path Phase 1 replaces with `family-admin delete_zone` |
| Local preferences | `LocalSettingsService` (parent) and `ChildPreferences` (child), both over `SharedPreferences` | **two implementations, two disjoint domains** — not a functional duplicate, but a consolidation candidate for a later phase |
| Presence logic | `Device.isOnline` / `statusLabel` only; no UI recomputes the window | **one**; in-flight presence work adds `isSyncStalled` to the model, not to the widget |

Result: **no duplicate module found.** One pair worth noting (parent vs child preferences service)
and one cross-language pair that must stay in sync (Dart `DevicePolicy` ↔ Kotlin `ChildPolicy`).

## 4. Contract freeze

The following are frozen as of this report; each is restated with evidence in the companion files.

1. 26 routes and their page/controller/repository wiring (`api-contract.md` §1).
2. The 9 Edge Functions and their action set, request and response shapes (`api-contract.md` §2).
3. The 19 tables, their ownership column, RLS audience and writer (`api-contract.md` §3).
4. Realtime topics and their authorization predicates (`api-contract.md` §4).
5. The status/enum vocabulary, including `pending|enforced|failed|unsupported` (`api-contract.md` §5).
6. The Phase 1 additions exactly as written in the coordinator contract (§"Fixed interfaces"),
   with one correction recorded below.
7. File ownership per workstream and the 15→10 role collapse (`feature-ownership.md`).
8. Migration order and the deploy-ordering rule that `…000100` precedes the new `cron` build
   (`dependency-map.md` §2).

**A contract change is required for any of:** a new/renamed route; a new table, column, publication
member or client-callable RPC; a new Edge Function action or a non-additive response change; a new
status string; a new dependency; a change to any signature in the coordinator contract's fixed
interfaces; a change to a `Device`/`RemoteSession` public field used by another workstream; or a
change to the ownership table. Anything else (adding fields to a response, adding a test, fixing a
defect inside an owned file) is normal work and needs no contract change.

### Recorded deviation from the coordinator text (needs owner ratification)

| ID | Coordinator contract says | Reality | Resolution taken |
|---|---|---|---|
| D1 | sweep sets `ended_by='system'` | `remote_sessions.ended_by` is `uuid references public.profiles` (`core.sql:340`); the literal `'system'` is unrepresentable and would abort the update | session workstream writes `ended_by = null` + `ended_reason = 'abandoned'` and documents the pair as the system marker (`20261030000100_abandoned_session_sweep.sql:22-29,86-87`). Recommend the coordinator amend the contract wording to match; **no functional difference** for clients, which read `status`/`ended_reason` |

## 5. State of the working tree during Phase 0

Phase 1 wave A was coding while this baseline was taken. `git status` changed between the first and
last observation:

- first read: only `.pgdata` deltas plus untracked `audit/` and `docs/implementation/`;
- later reads: `M lib/data/models/device.dart`, `M lib/features/dashboard/parent_dashboard_tab.dart`,
  `M lib/features/devices/device_detail_page.dart`, `M android/.../GuardianService.kt`,
  `M supabase/functions/remote-session/{index,guard}.ts`, `M supabase/functions/family-admin/index.ts`,
  and new files `supabase/migrations/20261030000100_abandoned_session_sweep.sql`,
  `20261030000200_phase1_authorization.sql`.

Consequence: HEAD `2a0209f` is the stable baseline; the half-finished working tree is **not** part of
it. `delete_zone` and `expire_abandoned_sessions` are therefore documented as NEW and "present in
the working tree, not deployed". `20261030000300_retention_sweep.sql` did not exist at the end of
Phase 0; the retention contract is documented from the coordinator contract only, and its migration
is lifecycle's to write.

## 6. Limits of this report

- 25/242 inventory rows re-verified; 217 not. No audit document was re-derived.
- No SQL was executed; the three new migrations are reviewed by reading only.
- No Kotlin compiled or tested (`BLOCKED — environment`).
- Hosted state is inherited from `audit/06`, not re-inspected (dashboard-only access, out of scope).
- Deno tests were not run by this workstream; `deno check` is permitted but adds nothing to a
  documentation deliverable.