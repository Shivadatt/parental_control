# Phase 2 — open gaps

Written 2026-11-02. Every entry was re-verified against the current tree on the date above; a claim
copied from an older phase is marked as such. Severities: **P0** authority bypass or data loss, **P1**
wrong result on the intended path, **P2** honest-but-incomplete, unverifiable here, or a documented
risk, **P3** wording. `phase-2-regression-matrix.md` says what was proven; this file says what is
still not true.

## 1. Nothing from Phase 1 or Phase 2 is deployed

| Gate | State | Consequence |
|---|---|---|
| `20261030000100_abandoned_session_sweep.sql`, `20261030000200_phase1_authorization.sql`, `20261030000300_retention_sweep.sql` | **unapplied** | The `delete_zone` / owner-only purge / abandoned-sweep / retention behaviours described in `phase-2-report.md` §4 are **local-only** |
| `account` Edge Function | **not deployed** | Export, `delete_account` and `retention_report` cannot be called in production; the Phase 2 settings UI changes are client-side wording over an undeployed endpoint |
| cron action + SQL ordering | pending | `sweep_sessions` and `retention_sweep` answer `{skipped:true}` until migration 3 exists |
| TURN provisioning, hosted secrets, Auth settings | untouched | Phase 2 made no hosted change of any kind (owner rule; browser dashboard read-only, Supabase CLI never invoked) |
| Hosted observation | 2026-10-30 dashboard audit and the owner's 2026-11-02 screenshot both show **No migrations** / **No backups** for `parent-control-prod` | Point-in-time only — it decays the moment anyone deploys; re-inspect before relying on it |
| Phase 2 work itself | **uncommitted**: `main` @ `8da1de7`, 47 files changed vs HEAD (9 new, 38 modified), 0 commits/branches/pushes created | Rule 3 — commit and push need the owner's approval |

## 2. Closed during Phase 2 (recorded so nobody re-files it)

- **P0, closed — client retention floor.** `audit_logs_controller` used to fall back to `0` when a
  family had no stored window, so the purge dialog could promise "older than 0 days" while the server
  keeps 30/90. It now mirrors the server rule (`_retentionFloor()`, defaults 30/90) and two tests
  cover the missing and non-positive cases. Server side unchanged
  (`supabase/functions/family-admin/index.ts:25-43`, clamps `:252-259`).
- Enforcement dishonesty in the parent UI (empty-target "success", queued command shown in a success
  tone, unsupported banner quoting 0) — fixed and pinned by three new tests.
- Duplicate presence rules (`_deviceTone`, dashboard avatar tint, per-screen label strings) — removed.
- Export-dialog over/under-claims and the sweep-timestamp note — corrected against
  `supabase/functions/account/index.ts:56-79` and `20261030000300_retention_sweep.sql:165-174`.

## 3. P1

| ID | Gap | Evidence | Owner action |
|---|---|---|---|
| SQL-01 | **Rollback instructions re-open the exposure the migration closes.** The rollback block in the migration header (`20261030000200_phase1_authorization.sql:26-35`) restores `grant execute on function private.remote_session_transition_guard() to public`, `grant execute … private.request_device_recovery(uuid, uuid) to public` and `grant delete on public.safe_zones to authenticated` plus the old `safe_zones_delete_parent` policy — i.e. following the documented undo returns to exactly the pre-Phase-1 authorization state, not to a `service_role`-only state. | Read of `:26-35`; carried from the 2026-10-30 audit and re-confirmed unchanged in the current file | Owner decision: keep the rollback as a true revert (and accept the hole) or write a safe rollback that re-grants only to `service_role`. Either way it must be an explicit choice before deployment, not a comment nobody re-reads |

## 4. P2

| ID | Gap | Evidence | Note |
|---|---|---|---|
| SQL-02 | Abandoned-session index cannot serve its own predicate | `20261030000100_abandoned_session_sweep.sql:43-44` builds `remote_sessions_abandoned_idx on (accepted_at) where status in ('accepted','active')`, while the sweep filters `coalesce(accepted_at, requested_at) < now() - p_max_age` (`:74`) | The comment at `:41-42` claims it "Matches the WHERE clause exactly" — it does not. The planner can use the partial index for the status filter but not for the age filter, so the sweep still scans the accepted/active set. Fix = index the expression, or change the comment |
| SQL-03 | `not_family_parent` surfaces as **500** outside `family-admin` | The migration raises it at `20261030000200_phase1_authorization.sql:121` (`request_remote_session`), `:205` (`revoke_device`), `:238`/`:243` (`unlink_child`), `:283` (`apply_policy_version`). `grep -rn "not_family_parent" supabase/functions/` matches **only** `family-admin`. `mapPolicyRpcError` (`device-policy/index.ts:20-36`) handles `device_not_active` / `invalid_policy` / `invalid_idempotency_key` / `device_required` and falls through to `internal_error`/500 (`:35`); `mapApplyPolicyRpcError` (`device-command/index.ts:56-65`, called at `:136`) handles only `device_not_found` / `device_not_active` before the same 500; `pairing/index.ts:947-961` maps `membership_not_found` and `forbidden` only | Authorization failures become retryable server errors for the client, and a real "you are not a parent of this family" is indistinguishable from a bug in logs. Fix before the migration is deployed |
| SQL-04 | Retention sweep batching is cosmetic | `20261030000300_retention_sweep.sql:51-80` (global) and `:116-145` (per family) do loop with `limit v_batch`, but one call = one transaction, and the two global predicates filter on bare `created_at` with no usable index: `webrtc_signals` has only `(session_id, sequence)` (`20260101000000_core.sql:369`); `audit_logs` has `(family_id, created_at desc)` and `(actor_user_id, created_at desc)` (`:388`, `:390`) | First backlog run is roughly O(N²/10 000) inside a single long-lived transaction. Add `created_at` indexes, or chunk the sweep across calls, before enabling the cron |
| SQL-05 | Audit row and zone delete are not atomic | `family-admin/index.ts` deletes with the service-role client, then writes the audit row only `if ((deleted.count ?? 0) > 0)`; a failed insert leaves an unaudited delete | Acceptable only if the append-only guarantee is treated as best-effort — an explicit product decision |
| SQL-06 | Signaling replay protection is conditional | The unique `(session_id, sequence)` index is skipped with `raise notice 'duplicate sequences exist; index skipped'` (`20261030000200_phase1_authorization.sql:354`) rather than aborting | Check for duplicates in the hosted table before relying on it; `sequence` is `generated always as identity`, so duplicates should not exist |
| TEST-01 | §6.1–6.4 are source-level wiring proofs, not injected handler executions | Handlers are bare top-level `Deno.serve(...)` with no export and build a service-role client internally; `handler_wiring_test.ts` header records this. Only `remote-session/lifecycle_test.ts` is truly dependency-injected | A refactor that drops the call or inlines a second rule now fails — a handler that calls the right module with the wrong variable still would not. Closing this needs an export-first refactor of four handlers (owner decision, out of Phase 2 scope) |
| DOC-01 | The documented Deno command fails | `deno test supabase/functions` → `FAILED \| 83 passed \| 5 failed`, exit 1 (`--allow-read` is required by `handler_wiring_test.ts`). Amended in place at `regression-matrix.md:24`; `phase-2-regression-matrix.md` §1 uses the correct invocation | Anyone re-running Phase 1 evidence must add the flag |
| UI-02 | Unguarded writes remain in the dashboard and devices controllers | `_isStillCurrent(familyId)` protects the success paths; the `catch` (`error.value = exception`) and `finally` (`isLoading.value = false`, `_reloadRequested` re-entry) assignments are still unguarded, so a failed superseded request can overwrite a newer error or clear a newer loading state | Low blast radius (transient UI state), found by the Phase 2 review rather than by a test |
| GOV-01 | Phase 0 baseline commit is unverifiable in this clone | `2a0209f` (also `baseline.md:12`) and the Phase 1 review ref `8ebb73c` both fail `git cat-file -t`; `git rev-list --all \| grep -cE '^(2a0209\|8ebb73)'` = 0 | Baseline immutability is therefore proven by **content** (`baseline.md` / `phase-0-report.md` are untouched in both worktree and index), not by ancestry. If the owner has the real objects, record their full hashes |
| GOV-02 | D1 has no owner-level signature | Ratification is the reviewing coordinator's (`phase-1-report.md:363`); `_work/contracts.md` and `phase-2-governance.md` §2 say so explicitly | Owner countersign (or replace) the `ended_by = NULL` + `ended_reason = 'abandoned'` representation |
| KOT-01 | Kotlin JVM tests remain `BLOCKED — environment`, not re-attempted in Phase 2 | Five files under `android/app/src/test/kotlin/**`; cross-drive Gradle (`C:` toolchain vs `D:` project). No Kotlin claim in Phase 2 is anything but "not executed" | Needs a workstation with cache and project on one drive |
| KOT-02 | Two `enforcementMode()` helpers remain, deliberately unconsolidated | `PolicyApplier.kt:229-234` (call `:376`) and `GuardianService.kt:668-674` (call `:503`) | One-line refactor, blocked by KOT-01; see `phase-2-governance.md` §5.1 |
| PRIV-01 | Child `retention_report` returns family-wide counts | `account/index.ts:389-422` builds one report per family the caller belongs to and counts `location_events` / `usage_daily` for the **whole family** (`locationEventsOlder`, `usageDaysOlder`), so a child asking about retention sees the family's totals, not its own | Not silently relabelled. Needs a product/privacy decision: scope the numbers per child, or state the family scope in the child UI |
| ENF-01 | An enforcement report can be attached to the wrong policy | `app_restrictions_controller.dart:519-524`: a command whose payload carries no `policy_id` (null or empty) is accepted for **any** current policy, so the newest matching `apply_policy` row is shown as the report for the latest version | Old clients omit `policy_id`. Either require it before trusting the report or label such a report "policy id not reported" |
| UX-01 | `safe_zones_controller.canManage` (`:40`, used at `:155`) is a UX gate, not the authorization check | The authoritative gate is server-side (`canDeleteZone` + `assertFamilyParent`, proven in `70_phase1_authorization.sql`) | Left as-is on purpose: restructuring it would be a second implementation of a server rule. Keep the server authoritative |

## 5. P3 (wording)

| ID | Gap | Evidence |
|---|---|---|
| WORD-01 | The parent UI says "Apps the device could not suspend" (`app_restrictions_page.dart:360`, echoed in `policy_enforcement.dart:3`) while the device's own reason is "Could not confirm that X is suspended." (`PolicyApplier.kt:151`) | A confirmation failure is not proof that suspension failed. Either soften the header to "could not be confirmed as suspended" or have Kotlin emit a distinct reason code — the header change is client-only |
| WORD-02 | `AccountDataExport.isChildExport` (`account_privacy_repository.dart:41-42`) is false whenever `profile.role` is absent or unexpected, so an unknown role is described with the **parent/family-scoped** wording | Safe default for a parent, understated for a child. Server always sends `role`; only a malformed payload would hit it |

## 6. Not covered by any Phase 2 check

Emulator or physical-device behaviour (presence transitions over 12/30 real minutes, Device Owner
enrollment, mic lifecycle), hosted HTTP calls, realtime delivery, backup/restore, and any performance
or battery claim. Each is listed as `NOT TESTED` in `phase-2-regression-matrix.md` §1 rather than
inferred from the code.
