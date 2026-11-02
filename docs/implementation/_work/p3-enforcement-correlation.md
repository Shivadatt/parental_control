# P3-D — ENF-01 enforcement-report correlation (Phase 3)

Scope: a device enforcement report must never be attributed to the wrong policy.
Verified from code, then implemented in the parent client. No server, Kotlin or
schema change (ownership); no `flutter test` / `flutter build` run here.

## 1. How a report becomes visible (trace)

1. Parent saves a policy → `device-policy` action `update` → `apply_policy_version`
   (`supabase/migrations/20260101000100_functions.sql:86-175`) inserts the
   `device_policies` row **and** the `apply_policy` command in one transaction,
   with command payload `{"policy_id": <uuid>, "version": <int>, "policy": {...}}`
   (`:160-171`). This is the only place a policy-identifying key enters a command.
2. Device polls (`device-command` action `poll`) and acks
   (`GuardianService.kt:485-498`): the ack body is exactly
   `{action, command_id, status, result}` — no `policy_id`, no `policy_version`.
   `PolicyApplier.buildResult` (`PolicyApplier.kt:348-379`) produces the result:
   `success, applied_at, suspended_packages, unsupported_packages, errors,
   service_running, bedtime_active` and, when `countsKnown`, `desired_count`,
   `applied_count`, `failed_count`, `enforcement_supported`, `enforcement_mode`,
   `failures[{package,reason}]`.
3. Server-side attribution: `device-command/index.ts:319-356` reads
   `command.payload.policy_id`, requires `isUuid(policyId)`, and only then runs
   `decideEnforcement` and updates **that** policy row
   (`.eq("id", policyId).eq("device_id", device.id)`). A command without a UUID
   `policy_id` updates nothing, so the server never mis-marks a policy. `enforcement.ts`
   is purely about counters — it has no policy identity to check.
4. Parent-side attribution (the ENF-01 defect): `device_policies` has no counter
   columns, so the controller re-reads `device_commands`
   (`SupabasePolicyRepository.fetchRecentCommands`, `created_at desc`, `:64-78`) and
   picked the first acked `apply_policy` command whose payload had *no* `policy_id`
   as a report for **whatever policy was on screen** (old
   `app_restrictions_controller.dart:519-524`: the `continue` only fired when an id
   was present and different). That is exactly "lacking `policy_id` may be accepted
   and associated with the currently active policy" — confirmed in code, P1.

## 2. Correlation rules (what actually identifies the policy)

| Field | Where it lives | Present in real payloads? | Usable as correlation key |
|---|---|---|---|
| `payload.policy_id` | `device_commands.payload` (written by `apply_policy_version`) | Yes for every command created through `device-policy`/`device-command`; the only writer | **Yes — the one and only key** |
| `payload.version` | same insert | Yes | Informational only: it identifies the policy the *command* carried, and a hand-made/legacy row can set it arbitrarily; never used to prove |
| ack `result.*` counters | `policy_ack.result` | Yes (newer builds); absent on old builds and when `countsKnown` is false | No — says nothing about which policy |
| `result.applied_at`, `command.created_at/acked_at` | row timestamps | Yes | No — a late ack is real evidence for its own version; letting age upgrade it is the bug being removed |
| `installation_id` | `devices` column | Not in any command payload; revoked from `authenticated` (`20260101000200_rls.sql:257`, `supabase/tests/10_schema.sql:189`) | No — the parent client cannot even read it |
| `device_commands.device_id` | row | Yes | Scope check only (a report from another device is ignored) |

## 3. Chosen rule for missing/empty `policy_id` (backward compatibility)

**Labelled uncorrelated and kept visible; excluded from every enforcement claim.**

- `PolicyReportCorrelation.matched` — payload id equals the displayed policy id.
- `PolicyReportCorrelation.mismatched` — names another policy: never shown for the
  policy on screen (it remains visible for the policy it *does* name, because that
  policy's own screen correlates it). This preserves historical visibility while
  making mis-attribution impossible.
- `PolicyReportCorrelation.uncorrelated` — id absent, empty, or whitespace, **or**
  the displayed policy has no usable id: the report is rendered with counts and
  per-app failures (so legitimate history is not hidden) under an explicit banner
  and with `provesEnforcement == false`.

Rejected alternative: dropping uncorrelated reports entirely — it would erase real
device evidence for old rows and make a parent think a device never reported.
Rejected alternative: timestamp/version inference — it silently re-creates ENF-01.

`enforcementProven` (the only gate for the green badge / success banner) now requires
`evidence.provesEnforcement` = matched id **and** the frozen contract's counts
(`enforcement_supported == true`, `failed_count == 0`, `applied == desired`).
`PolicyEnforcementReport.provesFullEnforcement` stays the counts-only predicate but is
documented as necessary-and-not-sufficient; the UI reads no other proof path.

## 4. Race: new policy while an older command report is pending

Two independent protections:

1. **Correlation** — after a save, the newest ack on file usually names the previous
   policy: mismatched → not selected → the new version shows "Pending device
   acknowledgement", no counts, no badge, until the device acks the *new* command.
   An uncorrelated legacy ack is displayed only as reference, never as proof.
2. **Generation guard** (`_reportRequest` in the controller) — `_loadEnforcementReport`
   captures a request id and returns without assigning if a newer load (load /
   refresh / ack-poll / save) started meanwhile, including the error path. A slow
   response computed against a superseded policy can no longer overwrite the display.
   `refreshPolicy()` with no policy on file now clears the report instead of keeping
   a stale one.

## 5. WORD-01 (in owned paths — fixed)

The device's reason is `Could not confirm that X is suspended.`
(`PolicyApplier.kt:151`), a confirmation failure, not proof of a failed suspend.
Header changed to `Apps the device could not confirm as suspended (N)`
(`app_restrictions_page.dart`) and the model doc comments corrected
(`policy_enforcement.dart`). One existing assertion in
`test/features/app_restrictions/app_restrictions_page_test.dart:282` was updated to the
new string — wording only, count `(2)` still asserted, nothing weakened.
Kotlin reason codes untouched (ownership).

## 6. Evidence status

- `./.fvm/flutter_sdk/bin/dart analyze test/features/app_restrictions lib/features/app_restrictions lib/data/models/policy_enforcement.dart`
  → **PASS**, "No issues found!".
- New + existing Flutter tests: **NOT RUN** here (coordinator rule — the authoritative
  suite runs once at the end). Written deterministically: injected fake repositories,
  fixed `DateTime(2025, ...)` values, a `Completer` gate for the stale-response race,
  no network, no wall-clock or timer assumptions.
- Server decision path: reviewed only, unchanged, and confirmed already safe
  (`isUuid(policyId)` gate). No Deno test was needed or run by this workstream.
- Kotlin/hosted behaviour: **BLOCKED — environment** (cross-drive Gradle; no CLI, no
  hosted access); device-side claims here are source reads, not executions.
- Delta hash of the requested paths, `git diff HEAD -- lib/features/app_restrictions/
  lib/data/models/policy_enforcement.dart test/features/app_restrictions/ | sha256sum`
  → `84f60fd64ed69888a2edd874aba028d12f64fe5c85ddd175246d6e5279657642`. Note this
  covers **all** uncommitted work in those paths, including Phase 2's still-uncommitted
  changes to `app_restrictions_page.dart` / `app_restrictions_page_test.dart`, not only
  this workstream's edits.

## 7. Residual, deliberately out of scope

`refreshPolicy()` and the ack poll assign `latestPolicy`/`savedPolicy` before awaiting
the command read, so a slow superseded refresh can still briefly show the older version
number (the *report* is generation-guarded, so no false proof is possible). Same class
as gap UI-02; fixing the assignment order belongs with the async-guard workstream.
