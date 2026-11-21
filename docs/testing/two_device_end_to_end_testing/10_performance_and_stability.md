# 10 — Performance and Stability

**Date:** 2026-11-21  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Measurement limits

This was a debug build running on one physical mid-range phone and one emulator. Cold-start timing, frame timing, jank and battery drain are not production-representative.

No force-stop was used on the child because it would stop the guardian service and alter the state under test. Cold-start measurements were therefore not taken.

---

## 2. Process and memory observations

| Metric | Child (Realme RMX2161) | Parent (Pixel 9a emulator) |
|---|---|---|
| PID at observation | 9467 | 3410 |
| Process state | Sleeping | Sleeping |
| VmRSS | 284,708 kB (~278 MB) | 336,756 kB (~329 MB) |
| Total PSS | 288,107 kB (~281 MB) | 300,577 kB (~294 MB) |
| Java heap PSS | 8,012 kB | 3,804 kB |
| Native heap PSS | 23,436 kB | 25,216 kB |
| Threads | 77 | 38 |
| Views / activities | 8 views / 1 activity | 14 views / 2 activities |
| WebViews | 0 | 0 |

These are debug-build values with Flutter engine overhead. They indicate a large but not obviously leaking process. No repeated-growth measurement was taken.

---

## 3. Startup and UI responsiveness

| Check | Observation | Label |
|---|---|---|
| Parent launch | Normal Flutter startup; one “Skipped 139 frames!” warning on the emulator | FAIL (P3, emulator jank) |
| Child launch | Normal startup; no ANR or crash | PASS |
| Screen transitions inspected | Dashboard, Devices, Device detail, Family, Alerts — no freeze or infinite spinner | PASS |
| Parent GC pause | ~159 ms concurrent mark-compact, no visible freeze reported | PASS |
| Child GC / jank | Not measured | NOT MEASURED |
| Cold start time | Not measured | NOT MEASURED |
| Warm start time | Not measured | NOT MEASURED |
| Dashboard load time | Not instrumented | NOT MEASURED |
| Child-to-parent sync latency | Effectively undefined: heartbeat is stale by days | FAIL (covered by P1) |
| Reconnect delay | Not tested | NOT TESTED |

The “Skipped 139 frames” line is a debug emulator launch warning, not proof of a production jank defect. It is retained as a P3 observation only.

---

## 4. Stability

| Check | Result | Label |
|---|---|---|
| App crash during test | None | PASS |
| App ANR during test | None observed | PASS |
| Fatal Kotlin exception | None observed | PASS |
| Flutter exception | None observed in logs | PASS |
| Missing native plugin | None observed | PASS |
| System-level crash mistaken for app crash | Parent crash buffer contained a Bluetooth system process crash; unrelated | PASS (not app) |
| Old ANR trace | One file dated 2026-11-13 on the child; not current | REPORTED |

---

## 5. Battery behavior

The child battery stats showed approximately 6 h 24 m of foreground time recorded for the app and screen-on discharge of 45 mAh in the sample window. This is not a controlled drain test.

- Live battery value: not read from the device
- Battery drain over a defined observation period: NOT MEASURED
- Low-battery alert generation: NOT TESTED
- Battery optimization whitelist: **not whitelisted**

No battery claim is made.

---

## 6. Performance verdict

**PASS** for stability: no app crash or ANR, and all inspected screens rendered.

**FAIL (P3)** for the emulator launch jank warning.

**NOT MEASURED** for cold/warm start, frame timing, sync/reconnect latency, battery drain and long-run memory growth. These require a release build and an instrumented test plan.
