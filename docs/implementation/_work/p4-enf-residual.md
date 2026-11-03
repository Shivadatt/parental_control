# P4-C — enforcement report residual: superseded policy reads reproduced, fixed, pinned

Phase: 4 · Workstream: C (coordinator-completed; the delegated agent died in the queue)
Executed: 2026-11-03 · Verdict: **PASS — fix shipped in the working tree, 6 deterministic tests**
File changed: [lib/features/app_restrictions/app_restrictions_controller.dart](../../lib/features/app_restrictions/app_restrictions_controller.dart)
(+97 / −25 vs `HEAD`; pre-fix copy retained at `.tools/p4c-controller-fixed.dart`)
Untouched: the `payload.policy_id` correlation rule (brief §5) — `_loadEnforcementReport`'s matching
logic and `PolicyEnforcementEvidence` are byte-identical to `HEAD`; only *who may publish* changed.

---

## 1. Reachability trace, against `HEAD` (`953b337`) only

`git show HEAD:lib/.../app_restrictions_controller.dart` — the report side already had a generation
token (`_reportRequest` at `:62`, `:533`, checked at `:543` and `:569`, the Phase 3 fix). The **policy
side had none**:

| site | HEAD line | write | guarded? |
|---|---|---|---|
| `_load()` initial read | `:192` | `latestPolicy.value = await fetchLatestPolicy(...)` | no token exists |
| `savePolicy()` after a successful save | `:432-433` | `latestPolicy.value = result.policy; savedPolicy.value = result.policy` | no |
| `refreshPolicy()` read → publish | `:451` → `:457-458` | same two assignments, **after** the await | no |
| `_startAckPolling()` tick | `:505` → `:507-508` | same two assignments, **after** the await | no |
| evidence writes | `:535`, `:560`, `:567`, `:571` | `enforcementEvidence.value = …` at four separate points | token only, and no `_isClosed` |

Three concrete interleavings, all reachable without any exotic scheduler:

1. **Older version rolls the screen back.** Parent taps save (`savePolicy` publishes v7 at `:432`),
   and a `refreshPolicy()` that had already awaited `:451` — i.e. started while the server still
   answered v6 — lands afterwards and assigns v6 at `:457-458`. The same applies to an ack-poll tick
   (`:505`) that was in flight before the save. `latestPolicy`/`savedPolicy` are written
   unconditionally, so the newest write wins rather than the newest policy. Measured, not argued:
   pre-fix run fails `Expected: <7> Actual: <6>` (`.tools/p4c-prefix-failures.log:5-10`).
2. **A superseded failure becomes the current error.** `refreshPolicy()`'s `catch` wrote
   `saveError.value` regardless of whether its response was still the one on screen, so a late
   failure from a read of a superseded policy replaced the status line of the policy actually shown.
   Pre-fix: `Expected: null Actual: AppException(unknown): The policy could not be loaded.`
   (`.tools/p4c-prefix-failures.log:14-20`).
3. **Counts from policy A displayed under policy B — the false-proof path.** `_loadEnforcementReport`
   took `request = ++_reportRequest` and then published at four points (`:535/:560/:567/:571`) with no
   check that the policy it was asked about is still the policy on screen. So after a policy switch,
   the previous policy's report (including "Applied to 2 of 2 apps") stayed rendered next to the new
   version, and `enforcementProven` could go green for a version that never received that report.
   Pre-fix: `Expected: null Actual: <Instance of 'PolicyEnforcementReport'>`
   (`:22-29`). The same absence of `_isClosed` let a read that landed after `onClose()` write
   `enforcementEvidence` on a disposed controller (`:33-39`).

So the answer to the brief's question — *can a superseded response temporarily display an older
policy version?* — is **yes, observed**, and it was also able to display a *newer* policy's absence
alongside stale proof.

## 2. Fix: the existing generation strategy, extended (no new concurrency mechanism)

The UI-02 pattern already in the codebase (Phase 3: monotonically increasing request token, checked
before every post-await write) is reused verbatim; two tokens, one per owned piece of state:

```dart
int _reportRequest = 0;   // owns enforcementEvidence
int _policyRequest  = 0;  // owns latestPolicy / savedPolicy / draft / policyReady
bool _isClosed = false;   // set in onClose()
bool _ownsPolicy(int r) => !_isClosed && _policyRequest == r;
bool _ownsReport(int r) => !_isClosed && _reportRequest == r;
```

Two behaviours were added on top, because a plain owner-bail-out was **measured to be wrong here**:

- **Version-monotonic acceptance** — `_publishPolicy(request, policy)` publishes when the caller owns
  the token, *or* when the incoming policy is strictly newer than what is displayed:
  ```dart
  if (!_ownsPolicy(request)) {
    final displayed = currentPolicy;
    final isNewer = policy != null && (displayed == null || policy.version > displayed.version);
    if (!isNewer) return false;
  }
  _showPolicy(policy);
  ```
  A superseded read may not roll the screen back, but a superseded read that happens to carry a
  *newer* version (the ack poll racing a save) must still be shown — otherwise the poll would simply
  stop updating. This is why the fix is not `_ownsPolicy || return`; the second option was tried and
  deadlocked the Phase 3 correlation suite, whose fake hands the same pending `Completer` to the first
  commands call (`test/features/app_restrictions/enforcement_report_correlation_controller_test.dart`,
  the ~v6-pending scenario).
- **Evidence invalidation on policy switch** — `_showPolicy()` clears `enforcementEvidence` whenever
  the policy *id* changes, and the single publish point in `_loadEnforcementReport` additionally
  re-checks that the policy it read for is still the one displayed:
  ```dart
  if (!_ownsReport(request) || !_stillShows(policy)) return;
  enforcementEvidence.value = matched ?? uncorrelated;
  ```
  `_stillShows(policy) => currentPolicy?.id == policy.id`. Correlation itself (`payload.policy_id`
  matching, uncorrelated-reference handling, `unsupported` handling) is untouched: `matched`/
  `uncorrelated` computation is the same code as `HEAD`, only the write is guarded.

Writes now: `_load()` (`++_policyRequest`, guarded `error`/`appsError`/`isLoading` finally),
`savePolicy()` (`++_policyRequest;` then `_showPolicy(result.policy)`, `_isClosed` guard; still
returns `true` for a successful-but-superseded save — the save *did* succeed, only the display is
owned elsewhere), `refreshPolicy()` and `_startAckPolling()` (both publish through
`_publishPolicy`), `_loadEnforcementReport()` (one guarded publish point instead of four).
`isLoading` is deliberately cleared in `finally` even after disposal-safe writes: it is owned by
`_load` alone and a spinner left on forever is a worse defect than a write to a disposed `RxBool`.

## 3. Tests

New file `test/features/app_restrictions/policy_read_supersede_test.dart` — 6 tests, mocktail +
`Completer`-controlled so every interleaving is deterministic (no sleeps, no wall-clock dependence):

| test | what it pins |
|---|---|
| a late response carrying an older policy cannot roll the screen back | v7 displayed, in-flight v6 read lands → still v7 |
| a genuinely newer policy from a superseded read is still published | version-monotonic acceptance is not an over-guard |
| a late failure from a superseded read is not shown as the current error | guarded `saveError`/`error` writes |
| a policy switch clears the previous policy's counts before its own read resolves | `enforcementReport`, `enforcementCorrelation`, `appliedCountsText` all null while v7's report is pending — no proof can be borrowed across versions |
| evidence for the displayed policy is still published normally | positive control: `policyStateText` contains "Policy v6 enforced on the device — Applied to 2 of 2 apps" |
| a read that lands after disposal writes nothing | `_isClosed`, after `controller.onClose()` |

Measured before/after on the same test file:

```
pre-fix  (.tools/p4c-prefix-failures.log): 00:00 +2 -4  — 4 of the 6 fail, with the exact
         expectations quoted in §1 (Expected 7 / Actual 6; Expected null / AppException;
         Expected null / PolicyEnforcementReport; Expected null / PolicyEnforcementEvidence)
post-fix (.tools/p4c run, same command): 6/6 pass; app_restrictions group 49/49;
         full suite see phase-4-regression-matrix.md
```

Existing suites re-run, not modified: `enforcement_report_correlation_controller_test.dart` (43 tests
in-group including the ack-poll scenarios) and the Phase 3 supersede tests for the dashboard/devices
controllers all still green. `dart analyze` clean for this file.

## 4. Limits of this fix

In-memory only, per-screen: it cannot survive a `Get.delete`/rebuild, and it makes no claim about the
server's own ordering. `PolicyEnforcementEvidence` still trusts the device's reported counts once the
correlation matches — unchanged from Phase 3. No new dependency, no persistence, no change to
`PolicyRepository`, and no change to the polling cadence (5 s × 6 attempts, `HEAD :493-511`).
