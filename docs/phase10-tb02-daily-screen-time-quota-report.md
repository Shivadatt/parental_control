# Phase 10: T-B-02 Daily Screen-Time Quota Enforcement Report

**Task:** T-B-02 — Daily Screen-Time Quota Enforcement  
**Phase:** 10 — Local Implementation  
**Predecessor:** T-B-01 — Enforcement Status Truthfulness (closed at 157 Deno tests)  
**Repository:** `D:\parentcontrol_app` (branch `main`, HEAD `a2faa5fb70f84638359154c68d19ce304fadab36`)  
**Date:** 2026-11-06 (Asia/Kolkata)  
**Owner Authority:** T-B-02 grant issued in-session on 2026-11-06 — see §A.  
**Verification Status:** Deno 181/181 PASS · Flutter 482/482 PASS · Kotlin NOT VERIFIED (runner prohibited)  
**Hosted / Device / Build Status:** ZERO hosted access, ZERO deployment, ZERO build, ZERO ADB, ZERO Git state change  
**Strict Governance Invariant:** An acknowledgement is proof only of what it measures. No verdict, sentence or counter in this task may claim enforcement that a device did not physically confirm through `DevicePolicyManager`.

---

## A. Authorization Evidence And Scope

**§0 gate sequence, recorded exactly as it happened.**

| Step | Evidence | Outcome |
|---|---|---|
| Gate check before any edit | The only grant on record was "Grant — T-B-01 only"; §0.3 states T-B-01 authority is not sufficient | **STOPPED** — no file was created or modified in the gate phase |
| §2 reconnaissance | Five read-only subagents; repo state re-checked first-party (`git status --porcelain`, `.git/index` mtime `2026-11-06 12:39:08`, HEAD unchanged) | Nothing modified |
| Grant requested from owner | Four explicit questions answered on 2026-11-06 | Implementation authority established |

**Owner rulings that authorize and bound this task.**

| # | Question put to the owner | Owner ruling | Effect on this implementation |
|---|---|---|---|
| A1 | Issue the Phase 10 local-implementation grant specifically for T-B-02? | **Grant T-B-02 in full** | Flutter/Dart, Kotlin, TypeScript and acknowledgement-contract source changes authorized |
| A2 | Approve the §5 acknowledgement-contract amendment to the frozen coordinator contract? | **Approve the additive extension** | `result.quota` designed, documented and coded; no hosted enum or schema change |
| A3 | Resolve register `:97` versus `:101` for Kotlin test execution? | **Leave prohibited (Kotlin = NOT VERIFIED)** | 18 Kotlin cases committed as source; never described as compiled or passing |
| A4 | Ruling on `daily_screen_time_limit_minutes = 0`? | **Keep 0 = invalid (server as-is)** | `0` is never a total ban; rejected as "not configured" on every layer |

**Scope boundary actually exercised:** local source edits under `android/`, `lib/`, `supabase/functions/device-command/`, plus two live contract documents under `docs/implementation/`. No other task, no deployment, no Phase 9 audit, no commit.

**What the grant did NOT resolve, and therefore what was not invented:** §3 of the task requires stopping on semantics undefined by DEC-12. The reconnaissance claimed five such gaps; re-reading DEC-12 §4.1, §4.2, §5 and §9 showed that four of them are in fact **ruled** (§C). The genuinely open remainder — DEC-12 §3.2.3 clock-manipulation policy, §3.2.5 split-screen/PiP attribution, and the proposed `partially_enforced` vocabulary — was excluded from implementation and is recorded in §K rather than decided by an engineer.

---

## B. Existing Architecture And Root Cause

**Lifecycle at HEAD before this task, with the failure point.**

| Stage | Pre-T-B-02 behaviour | Evidence |
|---|---|---|
| Parent sets a daily limit | Flutter clamped 0–1440 and serialized `daily_screen_time_limit_minutes` | `lib/features/screen_time/screen_time_controller.dart` |
| Server validates | `readInteger(..., 1, 1440)` — `0` and out-of-range are hard 400s | [`_shared/policy.ts:199-202`](file:///D:/parentcontrol_app/supabase/functions/_shared/policy.ts#L199-L202) |
| Child parses | Stored into `ChildPolicy` and **never read again** | [`PolicyJson.kt:16`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyJson.kt#L16), [`PolicyModels.kt:43`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyModels.kt#L43) |
| Child enforces | Nothing. A grep of all of `android/` returned exactly two hits — the parser line and the field declaration | verified first-party with `Grep` on `D:\parentcontrol_app\android` |
| Ack proves | `policy_ack.result` carried only the five app-suspension counters | [`coordinator-contract.md:59-60`](file:///D:/parentcontrol_app/docs/implementation/_work/coordinator-contract.md#L59-L60) |
| Server decides | With zero app targets, `decideEnforcement` returned `enforced` from receipt alone | [`enforcement.ts`](file:///D:/parentcontrol_app/supabase/functions/device-command/enforcement.ts) — T-B-01 branch |

**Root cause 1 — a dead field.** The daily limit round-tripped through JSON parsing into a data class with zero readers. There was no comparison, no reset logic and no suspension path.

**Root cause 2 — the re-apply trap.** `PolicyApplier.tick()` re-derives `desired` from the app rules every 60 seconds and restores anything outside it (`restoreList = previous - desired`). Had quota suspension been issued as a side action, **the next tick would have released it**. The implementation therefore had to join the quota targets to the same `desired` set rather than suspend beside it.

**Root cause 3 — no quota vocabulary in the frozen contract.** Nothing in `result` could distinguish "limit reached and suspended" from "limit received". This is what A2 authorized.

---

## C. Daily Quota Semantics And Timezone Decision

| Semantic | Classification | Source of the rule |
|---|---|---|
| Day boundary | **Derived from the existing architecture** — device-local calendar day, reset at local midnight | `UsageReporter` already buckets with `TimeUtils.startOfLocalDay` / `localDayString`; no family timezone reaches the child process ([`UsageReporter.kt:38-49`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/UsageReporter.kt#L38-L49)) |
| Evaluation cadence | **Ruled** — every tick, 60 seconds | DEC-12 §4.2 "evaluates usage against `daily_screen_time_limit_minutes` on every tick (60 seconds)" |
| Suspension target set | **Ruled** — all non-critical candidate packages | DEC-12 §4.2 "for all non-critical candidate packages" |
| Immunity list | **Reused, not re-decided** — `PolicyGuard.CRITICAL_PACKAGES` + `isSystem` + own package + default home + active IME | DEC-12 §4.2 bullet 3, AC-12-4; [`PolicyEvaluator.kt:27-77`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyEvaluator.kt#L27-L77) |
| At-limit boundary | **Taken from the task wording** — suspend at `usage >= limit` ("when usage reaches the configured daily limit") | T-B-02 §4; [`QuotaEvaluator.kt:103-106`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt#L103-L106) |
| `null` limit | **Ruled** — not configured, no quota enforcement, never reported active | DEC-12 §3.1, validator `1..1440` |
| `0` limit | **Owner ruling A4** — invalid; every layer degrades it to "not configured" | `policy.ts:202`, [`QuotaEvaluator.kt:61-62`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt#L61-L62), [`device.dart:106-115`](file:///D:/parentcontrol_app/lib/data/models/device.dart#L106-L115) |
| Overflow | **Engineering requirement from §3.C** — minutes saturate instead of wrapping, because a negative total would silently read as "below the limit" | [`QuotaEvaluator.kt:69-80`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt#L69-L80) |
| DST / timezone change / clock rollback | **Safety implemented, product policy left open** — a reset is recognised only when the ISO date moves strictly forward; equal or earlier buckets never re-arm or double-count. What should happen when a child deliberately moves the clock forward is DEC-12 §3.2.3 and is **not** decided here | [`QuotaEvaluator.kt:114-134`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt#L114-L134) |
| Split-screen / PiP / background audio | **Open** — `totalTimeInForeground` remains the measurement primitive, exactly as the existing usage report used it | DEC-12 §3.2.5 |
| Per-app daily quotas | **Deferred, untouched** | DEC-12 §7.1 (P1-A) |

**Defect caught in review (Kotlin cannot be compiled here, so review was the only net).** `QuotaEvaluator.decide` and `quotaSuspensionTargets` trusted the caller's limit, so a raw `0` reaching the core would have satisfied `usage >= 0` and suspended **every** eligible app — inventing exactly the total ban that ruling A4 forbids. Both now re-apply the 1–1440 validation internally ([lines 149 and 166](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt#L149)) and case 1 asserts it.

---

## D. Files Changed

**Modified tracked files — 13 files, 1 987 insertions, 19 deletions (`git diff --numstat`).**

| File | ± | Purpose |
|---|---|---|
| [`policy/QuotaEvaluator.kt`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt) | new, 257 | Android-free quota core: limit validation, day totals, target set, at-limit test, forward-only day bucket, `decide()` |
| `PolicyApplier.kt` | +163/−6 | Joins quota targets into `desired` ([`:132`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt#L132)), keeps app counters app-scoped (`:117`, `:143`, `:168`, `:213`), verdict after DPM confirmation (`:183`), bucket persistence (`:204`), `result.quota` (`:516`, `:522-536`), measurement (`:411`), fail-closed confirmation probe (`:474`) |
| `SecureStore.kt` | +12/−0 | `quota_active_day_bucket` key, getter/setter, cleared by `clearPolicyState()` |
| `test/.../policy/QuotaEvaluatorTest.kt` | new, 478 | The 18 §8 cases |
| `device-command/enforcement.ts` | +367/−2 | `QuotaAck`, `normalizeQuotaAck()` (`:204`), `decideQuotaEnforcement()` (`:399`), composition wrapper `decideEnforcement()` (`:462`) around the byte-preserved `decideAppEnforcement()` (`:279`) |
| `device-command/handler.ts` | +12 | `quota: normalizeQuotaAck(result)` at the single decision site ([`:396`](file:///D:/parentcontrol_app/supabase/functions/device-command/handler.ts#L396)) |
| `device-command/enforcement_test.ts` | +1 072/−0 | 24 new cases; zero removed assertion lines |
| `lib/data/models/policy_enforcement.dart` | +128 | `QuotaReport` and `report.quota`, absent ⇒ "no proof" |
| `lib/data/models/device.dart` | +14/−1 | `_configuredDailyLimit` range gate on read |
| `lib/features/app_restrictions/enforcement_reason.dart` | new, 91 | Single tested token→sentence mapping, `enforcementReasonText()` (`:63`) |
| `app_restrictions_controller.dart` | +72/−3 | Raw `last_error` render replaced by the mapping (`:740`, previously :673-674) |
| `app_restrictions_page.dart` | +44/−1 | Quota rows + mapped banner |
| `screen_time_controller.dart` | +60/−5 | Remaining/reached, 1–1440 setter gate, mapped reasons |
| `screen_time_page.dart` | +14/−1 | Quota rows + mapped banner |
| `test/features/app_restrictions/{enforcement_reason,quota_report_model,quota_status_page}_test.dart`, `test/features/screen_time/screen_time_quota_test.dart` | new, 982 | Flutter coverage for §H |
| [`_work/coordinator-contract.md`](file:///D:/parentcontrol_app/docs/implementation/_work/coordinator-contract.md#L71-L99) | +28 | The A2-approved additive extension, the verdict list, mixed-policy rule |
| [`api-contract.md`](file:///D:/parentcontrol_app/docs/implementation/api-contract.md#L246) | +1 | `result.quota` row in the live vocabulary table |

**Deliberate non-edits:** `supabase/migrations/**` (no schema or enum change), `supabase/tests/**`, the historical reports `docs/phase9-*.md` and `docs/implementation/_work/enforcement.md` (a Phase 1 wave-B record, left as written), and `docs/dec-12-*.md` (a governance decision document — this task implements it, never rewrites it).

---

## E. Usage Measurement Design

- Source: the existing `UsageReporter.query(context, dayStartMillis, now)` → `UsageStatsManager.queryUsageStats(INTERVAL_DAILY, …)` aggregated per device-local day ([`UsageReporter.kt:21-86`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/UsageReporter.kt#L21-L86)). No second usage pipeline was added, and no new permission was requested.
- Aggregation: sum of `totalMs` for rows whose `day` equals the current bucket; `totalTimeInForeground` is a focus-time measure, so two apps cannot be foreground simultaneously — overlapping intervals cannot double-count by construction.
- Cost control: the query runs only when a valid limit exists (`configured && usageAvailable`), because DEC-12 §3.2.1 flags polling cadence against battery as an open concern and a tick that does every 60 seconds must not query the system store pointlessly.
- Missing permission or a failed query ⇒ `usage_available:false`, `usage_minutes:null`, `limit_reached:false`, `action:"none"`. The device never guesses a usage figure, and the server refuses to advance on it.
- Legitimate zero: an empty result for today is `0` minutes with `usage_available:true`. "No data" and "no usage" are distinguished by permission and query success, not by inventing a sentinel.
- Reboot/process restart: the system usage store survives, so the first tick reproduces the same verdict; `quota_active_day_bucket` in EncryptedSharedPreferences records which device-local day a quota suspension is held for so a restart cannot be mistaken for a fresh day.
- Staleness limitation, disclosed: `INTERVAL_DAILY` buckets are written by the system periodically, so "today" can lag real wall-clock usage. The chosen response is honesty, not compensation — the number reported is the number measured, and the parent sentence for an unavailable read says so.

---

## F. Standard Versus Managed Mode Behaviour

| Situation | Standard Mode (`!isDeviceOwner`) | Managed Mode (Device Owner) |
|---|---|---|
| No valid limit | Quota path does not run; app behaviour byte-preserved; ack `configured:false` | same |
| Usage unavailable | Nothing suspended; `reason:quota_usage_unavailable` | same — the limit cannot be proven either way |
| Under the limit | Nothing suspended; ack `action:none`, `reason:quota_below_limit`, `enforcement_supported:false` | Nothing suspended; same ack with `enforcement_supported:true` |
| Limit reached | **Advisory only, never a suspension** — `action:"advisory"`, `reason:"quota_advisory_only"`, 0 desired / 0 applied; no package enters `desired` | Quota targets join `desired`, suspend once through the existing `setPackagesSuspended` path, re-confirm through `isPackageSuspended`, report `action:"suspended"` with counts |
| Partial or unconfirmable | Not reachable — nothing was attempted | `action:"suspend_failed"` + `quota_suspended N of M` / `quota_suspend_failed` / `quota_confirmation_missing`; an `errors` entry is added, so the ack status becomes `failed` rather than a false `succeeded` |
| Limit raised or removed, or the local day rolls forward | Nothing to release | Targets leave `desired`, so the already-tested `restoreList(previous, desired)` path restores them |
| Independently configured app rules | Unaffected | Unaffected — the quota only ever **adds** to `desired`; `appDesired` is snapshotted before the union and drives every app counter |
| Protected/system/self packages | Never suspended | Never suspended — `PolicyGuard` + `isSystem` + own package + default home + active IME |

Idempotency comes from the differential that already existed: `toSuspend = union - previous`, so a confirmed package is never re-sent; a package whose suspension the device cannot read is never reported as suspended (`canConfirmSuspension` fails closed at [PolicyApplier.kt:474](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt#L474)).

---

## G. Acknowledgement Contract Changes

**Shape shipped — exactly the A2-approved additive object** inside the existing free-`jsonb` `result`; the ack envelope `{action, command_id, status, result}` is unchanged ([`GuardianService.kt:484`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt#L484)):

```
result.quota = {
  configured: boolean, usage_available: boolean, usage_minutes: int|null,
  limit_minutes: int|null, day_bucket: string|null, limit_reached: boolean,
  action: "none"|"advisory"|"suspended"|"suspend_failed",
  desired_count: int, applied_count: int, failed_count: int,
  enforcement_supported: boolean, enforcement_mode: string, reason: string|null
}
```

Nullable fields are written with `JSONObject.NULL` because Android's `put(name, null)` silently **drops** the key — an absent key is the old-device signal and must never be produced by accident.

**Verdict table implemented server-side** ([`enforcement.ts:399-457`](file:///D:/parentcontrol_app/supabase/functions/device-command/enforcement.ts#L399-L457)):

| §5 state | `enforcement_status` | `last_error` | `policy_version` |
|---|---|---|---|
| 1 No daily limit configured | app mapping unchanged | unchanged | unchanged |
| 2 Limit configured, usage unavailable | `pending` | `quota_usage_unavailable` | **not advanced** |
| 3 Measured, below limit — Managed | `enforced` | `quota_below_limit` | advanced |
| 3 Measured, below limit — Standard | `unsupported` | `quota_advisory_only` | advanced |
| 4 Reached, suspension not established | `pending` | `quota_confirmation_missing` | not advanced |
| 5 Managed quota suspension confirmed | `enforced` | `null` | advanced |
| 6 Standard advisory at the limit | `unsupported` | `quota_advisory_only` | advanced |
| 7 Enforcement failed | `failed` | `quota_suspended N of M` / `quota_suspend_failed` | not advanced |
| Old device / malformed block | app mapping (T-B-01) | `limits_enforcement_unverified` | not advanced |

**Constraints respected.** No value outside the hosted CHECK enum `pending|enforced|failed|unsupported` is ever written ([`20260101000000_core.sql:185-186`](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L185-L186)); `partially_enforced` was **not** adopted. `last_error` stays well inside its 500-character check ([`core.sql:187`](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L187)). A device-supplied `reason` string is validated but **never copied into `last_error`** — the server builds its own text, so an ack cannot inject display content; a dedicated Deno case pins this.

**Two divergences, disclosed rather than smoothed over.**

1. `quota_not_configured` is a *server-side* verdict reachable when the policy declares time limits but the device's quota block says `configured:false` (a bedtime-only policy, or a limit the device refused). The compliant device path never emits it for a valid limit, because Kotlin validates the range before deciding.
2. The Kotlin core pairs `reason:"quota_confirmation_missing"` with `action:"suspend_failed"` when DPM state cannot be read; the server's `suspend_failed` branch runs first, so that ack lands on `failed`, not `pending`. Both refuse enforcement and refuse the version advance, which is the outcome §5 requires; `pending/quota_confirmation_missing` remains reachable for an ack that reaches the limit with a non-failed action and unestablishable counts. The contract text now states this precisely.

---

## H. Tests Added And Actual Results

| Suite | Command (verbatim) | Result | Status |
|---|---|---|---|
| Deno, canonical | `deno test --allow-read supabase/functions/` | `ok \| 181 passed \| 0 failed`, exit `0` (baseline 157) | **PASS, first-party** |
| Deno, scoped | `deno test --allow-read supabase/functions/device-command/` | `66 passed` (baseline 42) | PASS |
| Deno, types | `deno check supabase/functions/device-command/` | exit `0` | PASS |
| Flutter, pinned SDK | `.fvm/flutter_sdk/bin/flutter test --no-pub` | `00:27 +482: All tests passed!`, exit `0` (baseline +408) | **PASS, first-party, re-run after the main agent's wording edits** |
| Dart static analysis | `.fvm/flutter_sdk/bin/dart analyze lib test` | `No issues found!`, exit `0` | PASS |
| Kotlin | `gradlew` / `kotlinc` | **NOT RUN** | **NOT VERIFIED** |

**The nine required Deno contract cases** are present and green: valid quota-enforcement ack · missing required fields · invalid `action`/flag values · old-device ack without a quota object · no quota configured · Standard advisory · Managed success · Managed failure · version never advances without proof. Added beyond the mandate: enum-vocabulary sweep, device-string non-echo, malformed-count sweep, contradictory-ack rejection, mixed-policy preservation, expired-command exclusion.

**The 18 required Kotlin cases** are written one-per-function in `QuotaEvaluatorTest.kt` with `@Test` count verified first-party as `18`, covering every §8 numbered scenario including restart, reboot, local midnight, timezone change, limit increase/removal, app-restriction preservation, non-Device-Owner honesty, partial failure and old-acknowledgement distinguishability. They are **source only**: not compiled, not executed, not passing. Register [`:97`](file:///D:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md#L97) permits JVM tests while [`:101`](file:///D:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md#L101) and [`:210`](file:///D:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md#L210) prohibit Gradle — Gradle is this repo's only Kotlin test runner and no `kotlinc` is installed — and the owner answered A3 with "leave prohibited". Per §9, the honest label is NOT VERIFIED.

**No existing test was weakened.** `enforcement_test.ts` diff contains **zero** removed lines; the only source line removed in `enforcement.ts` is the old `decideEnforcement` signature, re-added as a wrapper around the byte-preserved app mapping. Two Flutter sentences were corrected by the main agent for over-claim (`"The device applied the app restrictions…"` asserted an app-side fact on limits-only policies; `"No daily screen-time limit is configured…"` asserted absence on a policy whose limit the device simply had not installed) and their expectations updated in the same edit — the wording changed, the truthfulness bar was raised, no assertion was deleted.

---

## I. Before / After Behaviour (empirical)

Executed first-party against the HEAD blob (`git show HEAD:supabase/functions/device-command/enforcement.ts`) and the working tree, same inputs, limits-only policy (`daily_screen_time_limit_minutes: 120`, no app targets), `ackStatus:"succeeded"`. Verbatim output:

| Scenario | BEFORE (HEAD `a2faa5f`) | AFTER (T-B-02 tree) |
|---|---|---|
| Old device, no quota block | `enforced` / `null` / advance **true** | `pending` / `limits_enforcement_unverified` / advance **false** |
| State 2 — usage unavailable | `enforced` / `null` / advance **true** | `pending` / `quota_usage_unavailable` / advance false |
| State 5 — Managed suspension confirmed 5 of 5 | `enforced` / `null` / advance true | `enforced` / `null` / advance true (now on **proof**, not receipt) |
| State 6 — Standard advisory at the limit | `enforced` / `null` / advance true | `unsupported` / `quota_advisory_only` / advance true |
| State 7 — quota suspend failed 1 of 5 | `enforced` / `null` / advance true | `failed` / `quota_suspended 1 of 5` / advance false |
| Malformed quota block (applied > desired) | `enforced` / `null` / advance true | `pending` / `limits_enforcement_unverified` / advance false |

**Device-side before/after (behaviour, not yet executed):** a Managed device with a 120-minute limit and 130 minutes of measured local usage left every app untouched and acknowledged nothing about the limit; it now places the non-critical package set into `desired` on the next tick, suspends once through the existing DPM call, re-confirms with `isPackageSuspended`, and keeps it suspended across subsequent 60-second ticks. On a Standard device the same state produces `action:"advisory"` and **zero** suspension calls.

---

## J. Backward Compatibility

- `result.quota` is additive inside free `jsonb`; unknown keys were already stored verbatim, so an old child binary, an old row and an old ack all continue to parse. Nothing reads a key that a pre-T-B-02 device sent.
- An **old device cannot acquire the claim**: `quota` absent ⇒ the T-B-01 verdict `limits_enforcement_unverified` (`pending`, no advance). A half-filled block is rejected by `normalizeQuotaAck`, which requires every field to be present and well-typed before it is treated as evidence at all.
- A policy with **no** daily limit is decided exactly as before — the quota block cannot change the verdict, which is pinned by a test.
- Flutter models treat `report.quota == null` as "no quota proof", never as "quota satisfied", and the parent UI keeps its pre-T-B-02 surface for such acks (widget-tested).
- `devices.policy_version` advance rules are unchanged in kind: only `enforced`/`unsupported` advance, `pending`/`failed` never do.
- The `handler_wiring_test.ts` structural pins still pass: the pinned literal import is untouched, the two new imports are separate statements, and `decideEnforcement(` still appears exactly once in `handler.ts`.
- No hosted row was touched; the DEC-12 §7.2 `d4a05b68…` remediation remains DEFER.

---

## K. Remaining Blockers And Unverified Areas

| ID | Item | Class |
|---|---|---|
| K-1 | **All 18 Kotlin cases are NOT VERIFIED.** No compilation, no execution, no runtime proof of the device half. Register `:97` versus `:101`/`:210` remains unsatisfiable and the owner chose to leave it prohibited (A3) | Verification gap |
| K-2 | **Device behaviour is unproven.** AC-12-3 (quota suspension and restoration on hardware) and AC-12-4 (immunity proofs) are BLOCKED by DEC-03; 75/75 QA rows remain NOT RUN | Release blocker |
| K-3 | **Nothing is deployed.** The `enforcement.ts`/`handler.ts` verdicts exist only in the working tree, so every hosted row keeps behaving as before until an authorized `GATE-HOST-01`/DEC-02 pass deploys the function | Deployment gap |
| K-4 | **`policy_version` can move backwards.** [handler.ts:414-424](file:///D:/parentcontrol_app/supabase/functions/device-command/handler.ts#L414-L424) writes `policy_version = appliedVersion` from the acked command with no monotonic guard, and the ack envelope still carries no `policy_id`/`policy_version` (DEC-12 §5 invariants 1–2 are unimplemented). A late ack for an older command can therefore re-point the device at a stale version. Pre-existing, not introduced here, and **not** fixed because it is outside the T-B-02 acknowledgement extension | Open defect, needs its own task |
| K-5 | **DEC-12 §3.2.3 clock-manipulation policy is undecided.** The forward-only bucket rule prevents re-arming and double-counting, but a deliberate clock move into a genuinely low-usage day still releases the quota, because the verdict follows measured usage | Owner decision |
| K-6 | **DEC-12 §3.2.5 attribution is undecided.** Split-screen, PiP and background audio keep whatever `totalTimeInForeground` reported; no attribution rule was invented | Owner decision |
| K-7 | **`partially_enforced` remains unapproved vocabulary**, so a Standard-mode advisory is reported as `unsupported`, which DEC-12 §4.1 explicitly permits but which reads harsher than "advisory". The parent sentence says "apps are not blocked when it is reached" to compensate | Product decision |
| K-8 | **Two raw `last_error` renders remain** at [device_detail_page.dart:258](file:///D:/parentcontrol_app/lib/features/devices/device_detail_page.dart#L258) and `:261`, `:292`, plus child-app screens. The mapping is applied to the App Restrictions and Screen Time surfaces only; widening it is a UI decision, not a quota rule | Scope limit, disclosed |
| K-9 | **Screen Time "Today" is parent-local**, while the enforced figure is the device-local `day_bucket`; only the App Restrictions panel shows the device-reported quota verdict. Harmonising the two needs a second command read | Known asymmetry |
| K-10 | **Local SQL chain not re-run.** No migration, schema, RLS or SQL-referenced file was modified, so the §9 "if needed" condition was not met | Justified omission |
| K-11 | The T-B-01 working-tree changes and the T-B-02 changes now share three files (`enforcement.ts`, `enforcement_test.ts`, `handler.ts`) **unstaged**, so they cannot be committed independently without a staging decision the owner has not authorized | Handoff note |

---

## L. Hosted, Device And Git Boundary Confirmation

**Operations performed:** local file edits; `Grep`/`Read`; `git status`/`diff`/`show`/`ls-files` (read-only); `deno test`, `deno check`, `deno run` of a scratch script **outside the repository**; `.fvm/flutter_sdk/bin/flutter test --no-pub`; `.fvm/flutter_sdk/bin/dart analyze`.

**Operations NOT performed, each explicitly prohibited by §10:** any hosted Supabase access or mutation; any SQL migration or preflight; any RLS/Auth/Realtime/Storage change; any Edge Function deployment; Firebase/FCM provisioning; secret or environment changes; any APK build, signing or install; any Gradle/`gradlew` invocation; any ADB, emulator or physical-device action; any Device Owner provisioning or device-policy change; TURN/WebRTC/audio changes; scheduler, cron, retention or session changes.

**Git evidence, captured after the last edit:** `.git/index` mtime still `2026-11-06 12:39:08 +0530` — identical to the pre-task value, proving no Git state-changing operation occurred in this task. The six `A ` documentation entries staged before this task, the `?? docs/phase10-tb01-…-report.md` entry, and every pre-existing unstaged modification remain exactly as found. `pubspec.lock` is untouched. Nothing was staged, committed, pushed, reset, cleaned, checked out, restored or stashed. The scratch comparison files were written under the OS temp directory and removed; no scratch file was created inside the repository.

**Governance decisions preserved:** DEC-12 (D1-B, B1-B, O1-C, P1-A, DEFER), DEC-13 Option B, DEC-16 and every Phase 9 register entry are unmodified. The canonical register and its mirror were not edited; the only documents changed are the two live contract files named in §D, which the A2 ruling authorized.

**STOPPED. T-B-02 is implemented locally and is NOT VERIFIED on Kotlin, NOT deployed and NOT committed. T-B-03 (bedtime enforcement) and T-B-04 (emergency pass) were not started; no Phase 9 audit was created; nothing was deployed and no Git write occurred. The next owner actions are K-1 (Kotlin runner ruling), K-3 (deployment authority), K-4 (stale-ack version regression task) and K-5 to K-7 (the three open DEC-12 semantics).**
