# Phase 10 T-B-01: Enforcement Status Truthfulness Report

**Document class:** T-B-01 Implementation Completion Report (Phase 10 Local Implementation, Category B).  
**Task Reference:** T-B-01 from [`docs/phase9-13-final-audit-and-implementation-launch-plan.md`](phase9-13-final-audit-and-implementation-launch-plan.md) §E.2, executed after the §0 authorization gate was satisfied.  
**Repository:** `D:\parentcontrol_app` (`main`, HEAD `a2faa5fb70f84638359154c68d19ce304fadab36`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) — **NOT ACCESSED**; nothing in this task was applied, deployed or queried remotely.  
**Date:** 2026-11-06.  
**Authorization:** Phase 10 local-implementation grant, recorded **scoped to T-B-01 only** (see §A).  
**Baseline Predecessor:** [`docs/phase10-local-verification-baseline-report.md`](phase10-local-verification-baseline-report.md) (T-A-01: Deno 150 passed, SQL chain 33/33, Flutter 408 passed).  
**Verdict:** **T-B-01 COMPLETE.** Canonical Deno suite **157 passed / 0 failed** (150 baseline + 7 new), exit code 0. Three tracked source files changed, **289 insertions, 0 deletions, 0 unrelated edits.**

---

## A. Authorization Gate (§0) — How It Was Resolved

| Step | Result |
|---|---|
| 1. Verify an explicit Phase 10 local-implementation grant exists | **NOT FOUND.** No grant in any repository artifact; `docs/dec-12-screen-time-bedtime-decision.md:8` and `docs/dec-13-device-owner-decision.md:13` both state "Phase 10 NOT AUTHORISED"; `docs/phase9-owner-decision-reconciliation-report.md:190` records it as "not requested" |
| 2. Grant absent → STOP | **STOPPED.** No file was modified at that point; `git status` was recorded unchanged (five `A ` docs entries only) |
| 3. Task prompt treated as authorization? | **No** — §0.3 forbids it, and the T-A-01 recommendation in Phase 9.13/§I of the baseline report was explicitly labelled a recommendation |
| 4. Owner decision obtained | **Granted**, and explicitly scoped: **"Grant — T-B-01 only."** Modifications began only after that answer |
| 5. Scope discipline after the grant | T-B-02 (daily quota), T-B-03 (bedtime), T-B-04 (emergency pass) were **not** started. No Flutter, Kotlin, SQL, migration, deployment or Git-write change was made |

Read-only inspection performed *before* the grant (`enforcement.ts`, `enforcement_test.ts`, `handler.ts`, `handler_wiring_test.ts`, `_shared/policy.ts`, DEC-12) modified nothing.

---

## B. Problem Summary

A child policy that configures **only** time-based controls — a daily screen-time limit and/or a bedtime window — and blocks no application was recorded by the backend as `enforcement_status = "enforced"` with `last_error = null`, **and** `devices.policy_version` was advanced to the policy's version. Nothing on the device had enforced anything: no package was suspended, no quota was compared, no bedtime action existed. The parent UI therefore showed a limits policy as fully applied.

This is DEC-12 §2 item 3 as registered ("the backend falsely marks limits-only policies as `enforced`") and it is the reporting defect that would have made T-B-02/T-B-03 unmeasurable: if the status field already lies, correct enforcement would be indistinguishable from the old false positive.

---

## C. Root Cause (traced, not assumed)

`decideEnforcement` decides the zero-target case from a single boolean:

- [enforcement.ts:104](file:///d:/parentcontrol_app/supabase/functions/device-command/enforcement.ts#L104): `if (input.targetsApps && desiredCount === 0)` → `pending` / `no_apps_suspended`.
- Falling through that guard leads to the terminal branch that returns `enforced` + `advancePolicyVersion: true`.

`targetsApps` is produced by `policyTargetsApps`, which recognizes only `blocked_packages`, `app_rules[].blocked` and `block_all_except_allowed`. A limits-only policy correctly returns `false` for that classifier — and that very correctness is what let it reach the terminal `enforced` branch, because the mapping had **no way to know the policy asked for anything at all**. `handler.ts:384` passed only the app-targeting boolean, so the intent was invisible to the decision.

The gap was therefore missing information, not a wrong boolean: the ack counters describe package suspension, and a policy whose only enforcement intent is time-based has **no evidence** behind `enforced`.

---

## D. Files Changed

| File | Insertions | Deletions | Nature |
|---|:---:|:---:|---|
| [`supabase/functions/device-command/enforcement.ts`](file:///d:/parentcontrol_app/supabase/functions/device-command/enforcement.ts) | 44 | 0 | New `EnforcementInput` field, new exported classifier, new decision branch, two doc comments |
| [`supabase/functions/device-command/enforcement_test.ts`](file:///d:/parentcontrol_app/supabase/functions/device-command/enforcement_test.ts) | 238 | 0 | 7 new `Deno.test` cases + one new default in the shared `input()` helper |
| [`supabase/functions/device-command/handler.ts`](file:///d:/parentcontrol_app/supabase/functions/device-command/handler.ts) | 7 | 0 | Second import statement + the new field at the single existing decision site |
| `docs/phase10-tb01-enforcement-status-truthfulness-report.md` | new | — | this report (untracked) |

**Nothing else changed.** `git diff --stat` → `3 files changed, 289 insertions(+)` and `git diff --check` reports no whitespace errors. No governance register, no historical report, no SQL, no Dart, no Kotlin file was touched.

---

## E. Exact Implementation Details

**E.1 New classifier — the missing information.** Keys and nullability are taken from the validator, not invented: `_shared/policy.ts:33-35` types the three fields as `number | null`, and `:204-211` writes an explicit `null` for "not configured", so only a present non-null value counts.

```ts
export function policyDeclaresTimeLimits(policy: unknown): boolean {
  if (!isRecord(policy)) return false;
  const keys = [
    "daily_screen_time_limit_minutes",
    "bedtime_start_minutes",
    "bedtime_end_minutes",
  ] as const;
  return keys.some((key) =>
    policy[key] !== undefined && policy[key] !== null
  );
}
```

The check is against `undefined`/`null` rather than truthiness on purpose: `bedtime_start_minutes: 0` (00:00) and `bedtime_end_minutes: 0` are legitimate configured values and a truthy test would silently classify them as absent.

**E.2 `policyTargetsApps` — semantics preserved, boundary documented.** Its recognised shapes are unchanged (`blocked_packages` non-empty, any `app_rules[].blocked === true`, `block_all_except_allowed === true`) so existing app-targeting behaviour is bit-identical. Its doc comment now records the two-way rule: a time limit is not an app target, and its presence must not let a zero-target policy claim `enforced`.

**E.3 Decision input and branch.** `EnforcementInput` gained a **required** `timeLimitsConfigured: boolean` (required, not optional, so a future call site cannot silently reproduce the bug — `deno check` fails instead). The new branch sits after the capability and count guards and after the existing `failedCount`/`appliedCount` check, immediately before the terminal `enforced` return, and is additionally guarded by `!input.targetsApps`:

```ts
if (input.timeLimitsConfigured && !input.targetsApps) {
  return {
    ...base,                       // advancePolicyVersion is false in `base`
    status: "pending",
    lastError: "limits_enforcement_unverified",
  };
}
```

Placement and the `!targetsApps` conjunct are what keep requirements 4 and 6 intact: mixed policies still reach their existing app-targeting verdicts (`enforced` / `failed` / `pending no_apps_suspended`), and a policy that configures nothing at all still lands on `enforced` with zero desired — the truthful "blocking nothing was applied" case that `handler_wiring_test`/`enforcement_test` already pin.

**E.4 Call site — the reason `handler.ts` is in scope.** Without it the fix would be a test-only artefact, since `handler.ts:384` is the only production decision site. One added field:

```ts
const decision = decideEnforcement({
  result,
  ackStatus: nextStatus,
  targetsApps: policyTargetsApps(command.payload.policy),
  timeLimitsConfigured: policyDeclaresTimeLimits(
    command.payload.policy,
  ),
});
```

The new import is a **separate statement** (`import { policyDeclaresTimeLimits } from "./enforcement.ts";`) rather than a widening of the existing one, because `handler_wiring_test.ts:91-95` pins the exact text `import { decideEnforcement, policyTargetsApps } from "./enforcement.ts";`. A comment at the import records why. `handler_wiring_test.ts:96`'s pinned decision-site text still matches because `normalize()` collapses whitespace and the pinned fragment ends at the `targetsApps` line. No existing test was edited, skipped, widened or weakened.

---

## F. Tests Added and What Each Proves

All 7 live in `supabase/functions/device-command/enforcement_test.ts` and build real policy objects through the two exported classifiers rather than hard-coding flags, so they fail if either classifier drifts.

| # | Test name | Proves |
|---|---|---|
| 1 | `a daily-limit-only policy is not enforced and does not advance the version` | Requirement 1 — `pending`, `limits_enforcement_unverified`, `advancePolicyVersion === false` (no `devices.policy_version` movement implied), zero counts still carried |
| 2 | `a bedtime-only policy is not enforced and does not advance the version` | Requirement 2 — bedtime alone cannot validate a policy |
| 3 | `a daily limit plus a bedtime with no app targets stays pending` | Requirement 3 — two limits are still zero apps |
| 4 | `a policy with app rules and limits keeps its app-targeting verdict` | Requirement 6 — mixed policy stays `enforced` at 5/5, keeps `no_apps_suspended` at 0 desired, and `failed`/`suspended 1 of 3` on partial failure |
| 5 | `an empty non-targeting policy is still applied, not re-labelled` | Requirement 5 — nothing configured ⇒ `enforced` with `lastError: null`, i.e. the new status is not a blanket pessimism and `:126` semantics survive |
| 6 | `a limits policy on an unsupported device stays unsupported` | Ordering — capability outranks the new rule, so Standard Mode still reports `device_owner_required` per DEC-12 D1-B |
| 7 | `policyDeclaresTimeLimits reads the normalized policy shape` | Classifier contract — explicit `null` = unconfigured, `0` = configured, `{}`/`null`/arrays = false |

The shared `input()` helper gained `timeLimitsConfigured: false`, so all 11 pre-existing cases run against exactly the ack shape they were written for. No pre-existing assertion was altered.

---

## G. Exact Verification Commands and Actual Output

Canonical command, as directed (the flagless variant was **not** used as verification):

```
cd /d/parentcontrol_app && deno test --allow-read supabase/functions/
```

```
ok | 157 passed | 0 failed (1s)
EXIT=0
```

| Check | Command | Actual result |
|---|---|---|
| Full canonical suite | `deno test --allow-read supabase/functions/` | **157 passed / 0 failed**, exit **0** (baseline 150 → +7 new) |
| Targeted module | `deno test --allow-read supabase/functions/device-command/` | **42 passed / 0 failed**, exit 0 |
| Case count in file | `grep -c "Deno.test(" .../enforcement_test.ts` | **18** (was 11; +7) |
| Type check | `deno check .../handler.ts .../enforcement.ts` | exit **0**, no diagnostics |
| Handler really compiled/loaded | `grep -n "from \"./handler.ts\"" handler_test.ts` → `12:import { handler, type HandlerDeps } from "./handler.ts";` | the call-site edit is inside the 42 passing module tests, not only text-pinned |
| Unrelated failures | full transcript `C:\Users\ASUS\AppData\Local\Temp\t-a-01\tb01-deno.txt` | **none** — 0 failed, no skipped/ignored tests introduced |

**Before/after proven by execution, not by reasoning.** HEAD's own copy of the module was extracted read-only (`git show HEAD:supabase/functions/device-command/enforcement.ts` to a temp file outside the repo) and both versions were run against the same limits-only payload and the same zero-count ack:

```
BEFORE: targetsApps=false status=enforced lastError=null advancePolicyVersion=true
AFTER : targetsApps=false limitsDeclared=true status=pending lastError=limits_enforcement_unverified advancePolicyVersion=false
```

| Policy shape | Device Owner ack counters | Status before | Status after | Version advance before | after |
|---|---|---|---|:---:|:---:|
| daily limit only | 0 / 0 / 0, supported | `enforced` | **`pending`** + `limits_enforcement_unverified` | `true` | **`false`** |
| bedtime only | 0 / 0 / 0, supported | `enforced` | **`pending`** + `limits_enforcement_unverified` | `true` | **`false`** |
| daily limit + bedtime | 0 / 0 / 0, supported | `enforced` | **`pending`** + `limits_enforcement_unverified` | `true` | **`false`** |
| app rules + limits, all suspended | 5 / 5 / 0, supported | `enforced` | `enforced` (unchanged) | `true` | `true` |
| app rules + limits, none resolved | 0 / 0 / 0, supported | `pending` + `no_apps_suspended` | unchanged | `false` | `false` |
| app rules + limits, partial | 3 / 1 / 2, supported | `failed` + `suspended 1 of 3` | unchanged | `false` | `false` |
| nothing configured | 0 / 0 / 0, supported | `enforced` | `enforced` (unchanged, truthful) | `true` | `true` |
| limits, non-Device-Owner | supported = false | `unsupported` | `unsupported` (unchanged) | `true` | `true` |

---

## H. Scope and Governance Compliance

**Performed (all permitted):** read-only inspection of TypeScript sources and DEC-12; edits to the enforcement module, its single production call site and its Deno test file; execution of the canonical offline Deno command; `deno check`; read-only `git show` / `git diff` / `git status`; this report.

**Not performed:** any Supabase hosted access, SQL, migration or preflight execution; any Edge Function deployment or redeployment (the fixed code is **local only** — hosted behaviour is unchanged until DEC-02/J-1 authorizes deployment); Firebase/FCM or secret changes; `flutter build`, `gradlew`, APK, ADB, emulator or device work; Device Owner/Administrator changes; TURN/WebRTC/audio changes; scheduler, cron, retention or session changes; **no Git write operation** — nothing was staged, committed, reset, cleaned, checked out, restored, stashed, rebased or merged; no governance register or historical report was modified.

**Deliberately excluded per §2:** no daily-quota comparison, no bedtime suspension, no emergency pass. `timeLimitsConfigured` reports *intent*, and the device still has no time-limit enforcement to prove it — that is T-B-02/T-B-03's job.

**Honest tooling notes:**
- The repository is **not** `deno fmt --check` clean at HEAD (pre-existing long lines across `device-command/`, including `handler_test.ts`), and `scripts/local-ci.ps1` has no `fmt`/`lint` stage. Existing code was therefore **not** reformatted; the additions follow each file's existing wrapped style. `deno lint` reports 2 pre-existing `no-unversioned-import` problems in `handler_test.ts`, none in the changed files.
- `\ No newline at end of file` in `enforcement.ts` is HEAD's existing state, verified byte-identical (`;0a7d` in both `git show HEAD:` and the worktree) — not introduced here.

**Out-of-band Git observation (recorded, not altered):** `.git/index` was written at `2026-11-06 12:39:08`, staging `docs/phase10-local-verification-baseline-report.md` (created 12:35:19). My source edits are all later (12:41:31–12:42:50) and remain **unstaged** (` M`). `git diff --cached` contains only documentation files (6 files, 1,951 insertions) — no source file is staged by me or by this task.

---

## I. Remaining Limitations and Follow-up Dependencies

1. **The fix is not live on hosted.** `device-command` is undeployed locally-fixed code; DEC-02 (J-1) already registers `device-command` as one of the three functions its scope covers, so deployment happens under that ruling — architecture/status records must keep saying `NOT APPLIED` until then.
2. **Hosted data already contaminated.** Production row `d4a05b68-eff2-4dca-a794-86ced2565a48` (version 1) is stored `enforced` with `last_error: null` for a policy that suspended nothing — registered as defect 4 in [`docs/dec-12-screen-time-bedtime-decision.md`](file:///d:/parentcontrol_app/docs/dec-12-screen-time-bedtime-decision.md#L38) §2. DEC-12 ruled that remediation **DEFER**; correcting it needs its own hosted authorization under J-1.
3. **`pending` is the honest interim status, not the end state.** Once T-B-02/T-B-03 give the device real quota/bedtime action, the ack must carry that proof and this mapping must be extended to read it — deliberately **not** invented here, because the frozen ack contract (`docs/implementation/_work/coordinator-contract.md`) defines no such field yet, and adding a fake one would be exactly the "artificial production behaviour" §3 prohibits.
4. **New status token reaches the UI verbatim.** `lib/features/app_restrictions/app_restrictions_controller.dart:674` renders `policy.lastError` raw, so parents will see `limits_enforcement_unverified`. A human-readable mapping is a small Flutter-side task; it was **not** done because the grant is scoped to T-B-01 (TypeScript) only. Flagged for the next grant.
5. **Kotlin/Flutter suites not re-run here.** The change is confined to Deno-served TypeScript; the T-A-01 baseline (Flutter 408, SQL chain 33/33) remains the standing evidence, and Kotlin stays NOT VERIFIED until build authorization (D.4 of the baseline report).
6. **Acceptance mapping:** DEC-12 AC "limit must not be reported `enforced` without physical proof" is now satisfied at the reporting layer; "the limit actually restrains usage" remains T-B-02 + T-D-04 (device proof under DEC-03).

**STOPPED. T-B-01 only — T-B-02, T-B-03 and T-B-04 were not started, nothing was committed or staged, no governance register or historical report was modified, and no hosted, build, device or Git-state operation occurred.**
