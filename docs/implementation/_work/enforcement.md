# Enforcement (Phase 1 wave B)

Enforcement claims are now counter-based end to end.

## Device (Kotlin)

- `PolicyApplier.apply()` returns `desired_count`, `applied_count`, `failed_count`,
  `enforcement_supported`, `enforcement_mode` and `failures[{package,reason}]` (max 20).
- `desired_count` counts every app the policy wants suspended now, including explicitly
  selected packages Android refuses (self/protected). Those become failures instead of
  silently leaving the denominator.
- No Device Owner: the target set is kept, `enforcement_supported=false`, `applied_count=0`,
  and `success=false`. It is never reported as cleared/succeeded.
- `enforcement_supported=true` needs Device Owner plus evidence: an accepted
  `setPackagesSuspended` call, or an already-confirmed suspension set from a previous run.
- After an exception the counters are omitted so the server keeps the policy pending.
- GuardianService already forwards this whole result object as the ack `result`; no ack
  protocol change was needed.

## Server

- `device-command/enforcement.ts` is the only mapping (`decideEnforcement`). Bare command
  success is never used.
- `enforced` requires supported + no failures + applied==desired + desired>0 when the policy
  targets apps. `unsupported` wins on `enforcement_supported=false`. Missing/malformed
  counters stay `pending`.
- `devices.policy_version` advances only for `enforced`/`unsupported`.
- `last_error` is short and truthful (`device_owner_required`, `suspended 2 of 5`,
  `no_apps_suspended`, `enforcement_counts_missing`, `command_expired`).

## Parent UI

- Counters come from the matching `apply_policy` command result (`policy_id` must match the
  displayed policy), because `device_policies` has no counter columns and Phase 1 adds none.
- Policy card shows "Applied to N of M apps". Green "enforced" only when counts prove
  applied==desired. An enforced row without counts is labelled "Unverified".
- Unsupported shows the explicit "App blocking requires Device Owner" banner.
- Child restrictions banner now says "Rules are not enforced on this device".

## Not done / constrained

- Kotlin build: `BLOCKED — cross-drive Gradle` (not attempted).
- `flutter test` intentionally not run (coordinator rule); Dart files pass `dart analyze`.
  **Phase 2 correction (2026-11-02):** the rule withheld per-workstream runs, not the evidence — the
  Phase 2 verification workstream ran the authoritative full suite over these files
  (`.fvm/flutter_sdk/bin/flutter test`, **`+355`, all passed**, 2026-11-02) and `dart analyze` reports no issues
  repo-wide. Enforcement-screen honesty is now covered by
  `test/features/app_restrictions/app_restrictions_page_test.dart`. Kotlin remains `BLOCKED`.
  See `docs/implementation/phase-2-regression-matrix.md`.