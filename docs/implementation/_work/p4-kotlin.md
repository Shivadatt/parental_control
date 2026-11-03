# P4-B — Kotlin validation: KOT-01 re-run green, KOT-02 blocked by the test stack (code unchanged)

Phase: 4 · Workstream: B (agent B landed KOT-01 then died; coordinator re-ran it authoritatively)
Executed: 2026-11-03 · KOT-01: **PASS** · KOT-02: **BLOCKED — prerequisite cannot be met, code left unchanged**

---

## 1. KOT-01 — the documented command, executed for real

Brief §4 required the exact command, exit code, JUnit XML, executed count and environment, and
forbade claiming success if Gradle did not execute the tests.

```
command : ./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks
cwd     : D:/parentcontrol_app/android            (the Android project directory, as documented)
exit    : 0        ("BUILD SUCCESSFUL in 1m 39s" / "182 actionable tasks: 182 executed")
log     : .tools/p4b-gradle-coordinator.log (469 lines)
```

`--rerun-tasks` is what makes this a real re-run rather than a cached up-to-date: 182 tasks
**executed**, and `> Task :app:testDebugUnitTest` appears with no `UP-TO-DATE`/`FROM-CACHE` suffix
(`.tools/p4b-gradle-coordinator.log`, task list).

Environment, captured in the same log header:

| component | value |
|---|---|
| JDK | `openjdk version "17.0.16" 2025-07-15` Temurin-17.0.16+8 |
| Gradle | wrapper `gradle-9.1.0` |
| Kotlin plugin | 2.2.20 in use against `kotlin-dsl` expecting 2.2.0 (build warns, does not fail) |
| `ANDROID_HOME` | **empty in this shell** — the build resolves the SDK through `android/local.properties`, so an unset variable is not a blocker and was not "fixed" |

JUnit XML (`build/app/test-results/testDebugUnitTest/` — note the build directory is redirected to
the repository root, not `android/app/build/`; five class files, all timestamps
`2026-11-03T05:36:52Z`, i.e. this run):

| class | tests | failures | errors | skipped |
|---|---|---|---|---|
| `AudioAssistanceRecreationTest` | 8 | 0 | 0 | 0 |
| `AudioAssistanceSessionWatchdogTest` | 7 | 0 | 0 | 0 |
| `AudioAssistanceStartGateTest` | 4 | 0 | 0 | 0 |
| `AudioAssistanceStopIdempotenceTest` | 3 | 0 | 0 | 0 |
| `policy.PolicyEvaluatorTest` | 13 | 0 | 0 | 0 |
| **total** | **35** | **0** | **0** | **0** |

Independent corroboration: the agent's own earlier run of the identical command at 09:24 also ended
`BUILD SUCCESSFUL`, 182 tasks executed, `GRADLE_EXIT=0` (`.tools/p4b-gradle.log`, 461 lines). Two
executions, same counts.

**Pre-Phase-4 note, kept honest:** the Phase 3 matrix recorded KOT-01 as *not actually executed*.
This closes that. Nothing in the Kotlin sources changed in Phase 4, so the 35/0/0 result validates the
code as committed in `953b337`, not new code.

Warnings emitted (not failures): `EncryptedSharedPreferences` deprecation ×4 in `SecureStore.kt:80-81`,
Flutter-gradle annotation-target warnings, and Gradle-10 deprecation notices. Recorded, not silenced.

## 2. KOT-02 — why consolidation is NOT possible without approval

Brief §4 order of work: first establish coverage for `enforcementMode()`, confirm the two helpers are
equivalent, and **only then** consolidate; if the prerequisite cannot be met, leave the code unchanged
and record the reason. That is the outcome.

The duplicate, in full:

```kotlin
// PolicyApplier.kt:229-233
fun enforcementMode(): String = when {
    isDeviceOwner() -> "device_owner"
    isAdminActive() -> "device_admin"
    else -> "none"
}

// GuardianService.kt:668-674
private fun enforcementMode(): String {
    return when {
        applier.isDeviceOwner() -> "device_owner"
        applier.isAdminActive() -> "device_admin"
        else -> "none"
    }
}
```

**Equivalence: confirmed by inspection, and it is the strong kind.** `GuardianService`'s copy does not
have its own predicates — it calls the *same two functions* on the injected `applier`
(`PolicyApplier.isDeviceOwner()` at `PolicyApplier.kt:283-289`, `isAdminActive()` at `:291-297`, each a
`try/catch(_: Exception) → false` around `devicePolicyManager`). Identical branch order, identical
return strings, identical sources. The only difference is `private` and one level of indirection. So
this is a genuine duplicate, not two behaviours that happen to look alike.

**Coverage: NOT establishable with this module's JVM test stack.** Evidence:

- `android/app/build.gradle.kts:93` is the *entire* test dependency list:
  `testImplementation("junit:junit:4.13.2")`. No Robolectric, no Mockito, no
  `androidx.test.ext:junit`.
- There is no `testOptions { unitTests { ... } }` block anywhere in the module, so
  `returnDefaultValues`/`includeAndroidResources` are off: android.jar classes in a JVM unit test throw
  "not mocked" the moment they are touched.
- Both helpers are therefore unreachable: `PolicyApplier`'s constructor takes `Context` +
  `DevicePolicyManager`, and the value depends on `devicePolicyManager.isDeviceOwnerApp(...)` /
  `isAdminActive(...)` — framework calls that need an Android runtime, not a JVM.
  `GuardianService` is a `Service` subclass, same problem.
- The five existing green classes prove the boundary: each tests a **side-effect-free function
  extracted into plain Kotlin** (e.g. `AudioAssistanceService.startBlockReason(sdkInt = …)`), and
  `AudioAssistanceStartGateTest.kt:11-13` already says so out loud: *"the Android service lifecycle
  itself needs an instrumented (or Robolectric) test, and this module has no such dependency."*

Consequence: writing the requested test first is impossible without either adding a test dependency or
refactoring production sources. Both are outside what Phase 4 may do unilaterally (brief §4
"consolidate … only after the test passes"; §2 "never overwrite another workstream's changes"; the
Android workstream owns these files).

**Code left byte-identical to `HEAD`.** No helper removed, no helper merged, no dependency added:

```
git diff HEAD --stat -- android/  ->  (empty)
```

### Options for the owner (unblock paths, none executed)

| # | option | cost / risk |
|---|---|---|
| 1 | **Extract the decision to a pure function** — e.g. `object EnforcementMode { fun of(isDeviceOwner: Boolean, isAdminActive: Boolean): String }`, both helpers delegate, JVM test covers `of()` (4 cases: owner / admin-only / neither / both). Follows the pattern the module already uses for the start gate. | Smallest change, testable today. Touches `PolicyApplier.kt` + `GuardianService.kt` (android workstream files) and adds one new file. Needs approval. |
| 2 | **Add Robolectric** (`testImplementation` + `testOptions.unitTests.isIncludeAndroidResources`) and mock `DevicePolicyManager`. | New test-only dependency + Gradle/AGP matrix risk on Gradle 9.1 / AGP as configured; broader blast radius than option 1 for the same coverage. |
| 3 | **Instrumented test on a device/emulator.** | Real coverage, but requires the device-execution authorisation (brief §8: no APK install, no device run without explicit authorisation) and the build owner. |
| 4 | **Do nothing, keep the duplicate.** | Zero risk. The duplicates are provably equivalent today; the risk is future drift (one helper edited, the other not). Recorded as open gap. |

Recommendation: **option 1**, as a Phase 5 code-hygiene item under the android workstream's ownership,
with the drift-risk note in `phase-4-open-gaps.md` until then.
