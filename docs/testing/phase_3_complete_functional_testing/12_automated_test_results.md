# 12 — Automated Test Results

**Date:** 2026-11-21  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED

---

## 1. Flutter / FVM

| Check | Command | Result | Duration | Status |
|---|---|---|---|---|
| FVM | `fvm --version` | 4.3.2 | — | PASS |
| Flutter | `fvm flutter --version` | 3.44.6 / Dart 3.12.2 | — | PASS |
| Dependencies | `fvm flutter pub get` | Refused by execution policy (would modify lockfiles) | — | BLOCKED |
| Analyzer | `fvm flutter analyze` | **No issues found** | 159.4 s | PASS |
| Unit/widget tests | `fvm flutter test` | **493 passed, 0 failed** | 40 s | PASS |
| Integration tests | 4 files present | Not run (device/backend orchestration) | — | NOT_TESTED |

FVM emitted a non-blocking kernel-format warning; it still ran Flutter 3.44.6 correctly.

### Test inventory

- Flutter unit/widget files: **60**
- Integration test files: **4**
- Total Flutter cases executed: **493**

---

## 2. Deno Edge Function tests

| Check | Command | Result | Status |
|---|---|---|---|
| Deno test suite | `DENO_DIR=... deno test --allow-read supabase/functions/` | **209 passed / 0 failed** in 5 s (executed earlier in this session) | PASS |
| Re-run this phase | Same command | Refused by execution policy (project cache write) | BLOCKED |

17 Deno test files are present. The 209-pass result is from the same HEAD and session; it was not fabricated from source inspection.

---

## 3. Local SQL chain

| Check | Result | Status |
|---|---|---|
| Files executed | 14 migrations + 19 tests = **33** | PASS |
| Log length | 647 lines | PASS |
| `ERROR` / `ASSERTION FAILED` / `FATAL` | **0** | PASS |
| Explicit PASS notices | Tests 60, 61, 62, 63, 70, 71, 74, 75, 76 | PASS |
| Runner final summary | Not printed before the 1800 s command timeout | PARTIAL |
| Cleanup | No PostgreSQL process remained | PASS |

The SQL assertions passed. The wrapper did not return its final summary block, so the exit code is not claimed.

---

## 4. Kotlin JVM tests

| Check | Result | Status |
|---|---|---|
| `android/gradlew testDebugUnitTest` | Configuration failed: `this and base files have different roots: D:\parentcontrol_app\build\flutter_secure_storage and C:\Users\...\Pub\Cache\...` | BLOCKED |
| Kotlin test files | 7 present | — |
| Gradle configuration changed to force a pass | No | PASS (safety) |

This is the documented mixed-drive limitation, not a test failure.

---

## 5. Summary

| Suite | Total | Passed | Failed | Skipped | Blocked |
|---|---:|---:|---:|---:|---:|
| Flutter analyzer | 1 | 1 | 0 | 0 | 0 |
| Flutter tests | 493 | 493 | 0 | 0 | 0 |
| Deno tests | 209 | 209 | 0 | 0 | 0 |
| SQL files | 33 | 33 (log clean) | 0 | 0 | 0 |
| Kotlin tests | 7 files | 0 | 0 | 0 | 7 files |

**Interpretation:** the static/offline floor is strong. None of this proves the installed APK’s live device behavior, and the P1 heartbeat failure remains.
