# P3-E (UI-02) — async guard hardening of the dashboard & devices controllers

Workstream: P3-E · Phase 3. Branch `main` @ `8da1de7`, all Phase 2 worktree changes preserved,
nothing staged/committed/reverted by me. Supabase CLI never invoked. `flutter test`/`build` NOT run
(coordinator runs the authoritative suite); `dart analyze` on owned paths run — clean.

## 0. Path correction (contract deviation)
Ownership listed `lib/features/dashboard/controllers/dashboard_controller.dart` and
`lib/features/devices/controllers/devices_controller.dart`. Those paths do not exist. The real files
(one level up, no `controllers/`) are:
- `lib/features/dashboard/dashboard_controller.dart`
- `lib/features/devices/devices_controller.dart`
These unambiguously hold the Phase 2 `_isStillCurrent`/`_reloadRequested`/`_isClosed` code described,
so they are the intended targets. Edited them. New tests kept under the correct dirs.

## 1. Claim verified: the catch/finally writes were unguarded (UI-02)
`_isStillCurrent(familyId)` (family/session check) protected the *success* data writes, but the
`catch` (`error.value = …`) and `finally` (`isLoading.value = false`, `isOffline.value = …`, the
`_reloadRequested` re-entry) ran unconditionally, and neither `catch`/`finally` checked `_isClosed`.
So a superseded/disposed fetch could paint the newest family as an error, clear a newer fetch's
loading flag, or write UI state after `onClose()`. The `showLoading:` parameter was already dead
(`isLoading.value` is set true unconditionally) — left untouched (out of scope, no behavioural use).

### Write-site audit (before → guard now covering it)
dashboard_controller.dart (post-edit line numbers):
- `isLoading.value = true` / `error.value = null` on fetch start — new entry `if (_isClosed) return`
  + `if (isLoading && _runningFamilyId == requested) → fold` (point 2: no loading for a family the
  session no longer holds; a same-family reload coalesces, a different-family request supersedes).
- `error.value = exception` in `on AppException catch` — now `if (_owns(generation))`.
- `error.value = AppException.from(...)` in `catch` — now `if (_owns(generation))`.
- `finally` `isLoading.value=false; isOffline.value=…; retry re-entry` — now wrapped in
  `if (_owns(generation))`, and the fold uses the already-checked `_owns` (drop `_isClosed` double
  check). Success-path `family/children/devices/policies/lastRefreshedAt` writes stay on
  `_isStillCurrent(loadedFamilyId)` (Phase 2). Offline branch `error`/`isLoading` writes are pre-await
  and run under the freshly-captured generation.
devices_controller.dart: identical shape (`_owns(generation)` on both catch arms + finally; entry
`_isClosed` guard + fold/supersede; success writes keep `_isStillCurrent`).
Timers/worker: `_refreshTimer?.cancel()` and `_connectivityWorker?.dispose()` in `onClose()` already
make a post-close tick *impossible* (not merely ignored); a fetch already in flight when closed now
writes nothing because every catch/finally write is behind `_owns` (`!_isClosed`). No `Future.delayed`
or raw stream subscription exists in these two controllers.

## 2. Mechanism (one shape, deliberately duplicated, NOT abstracted)
`int _generation` bumped at the start of each real fetch; `_owns(generation) => !_isClosed &&
_generation == generation`; `String? _runningFamilyId` distinguishes a same-family reload (coalesce via
`_reloadRequested`) from a different-family request (supersede, new generation). `_isStillCurrent` is
kept for family-scoped *data* writes. Two near-identical guard blocks live in the two controllers;
per the brief I did **not** create a shared abstraction (would require a new file / editing a shared
module). Report: this is the sanctioned duplication.

## 3. Reload preserved on error
`finally` still reads+clears `_reloadRequested` and re-enters `_fetch` when this fetch owns the
generation — including when the try threw — so a reload requested mid-flight is not lost when the
in-flight fetch errors out (point 3).

## 4. Behaviour delta to flag
Different-family `load()` while a fetch is in flight now *supersedes* (new generation) instead of
coalescing into the stale fetch. More correct (a stale fetch early-returns and would not load the new
family) and it is what makes "old request fails after a newer one succeeded" reachable/provable.
Same-family reload semantics unchanged.

## 5. Tests (deterministic, fake repos, Completer-gated, no network, refreshInterval null)
- `test/features/dashboard/dashboard_async_guard_test.dart`
- `test/features/devices/devices_async_guard_test.dart`
Five scenarios each: superseded success doesn't clobber; superseded failure doesn't paint error (UI-02
core, fails on pre-fix code); family-left-during-fetch drops the write + clears loading; disposed
controller writes no UI (catch/after-close asserted via an `ever` write counter == 0, folded reload
must not resurrect); multiple refreshes coalesce into exactly one reload. Existing tests untouched;
`device_presence_consistency_test.dart` not rewritten.

## 6. Evidence status
- `dart analyze` on all four owned paths: PASS (No issues found). Command:
  `./.fvm/flutter_sdk/bin/dart analyze <4 paths>`.
- New + existing Flutter tests: NOT RUN (prohibited in this workstream) — to be run by the coordinator.
- My-delta `git diff HEAD -- <4 owned files> | sha256sum` = `f1680c772caaac3674f53d131c42cc446b6d41bb6305e0e086bfcea785c38227`.
  Caveat: HEAD predates Phase 2, so the two controllers' diff also folds in Phase 2's uncommitted edits;
  the literal brief command (`.../controllers/`, whole `test/features/dashboard|devices/`) hashes the
  wrong paths and other agents' files, so it is not this delta.
