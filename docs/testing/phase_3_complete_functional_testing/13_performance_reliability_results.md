# 13 — Performance, Reliability and UX Results

**Date:** 2026-11-21  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Statuses:** PASS / FAIL / NOT_TESTED / NOT_MEASURED

---

## 1. Stability

| Test | Observation | Status |
|---|---|---|
| Child app crash | None in crash buffer | PASS |
| Parent app crash | None for Parent Control | PASS |
| App ANR | None observed | PASS |
| Fatal Kotlin exception | None observed | PASS |
| Flutter exception | None observed | PASS |
| Missing native plugin | None observed | PASS |
| System crash mistaken for app | Parent crash buffer held a Bluetooth system process crash, unrelated | PASS (not app) |
| Old ANR trace | Child has an ANR file dated 2026-11-13; not current | NOT_TESTED (historical) |

---

## 2. Foreground service

| Test | Observation | Status |
|---|---|---|
| Child guardian service | `isForeground=true`, id 4101, channel `guardian_status` | PASS |
| Service uptime | ~37 hours (`lastActivity ≈ -1d13h`) | PASS |
| Visible notification | Present | PASS |
| Scheduled tick/watchdog | Source implements 10 s tick and 60 s watchdog | PASS (source) |
| Heartbeat effect | `last_seen_at` not updating | FAIL (P1) |

The service is stable but its authenticated work is not succeeding.

---

## 3. Resource usage (debug build)

| Metric | Child | Parent |
|---|---|---|
| PID at observation | 9467 | 3410 |
| VmRSS | 284,708 kB | 336,756 kB |
| Total PSS | 288,107 kB | 300,577 kB |
| Java heap PSS | 8,012 kB | 3,804 kB |
| Native heap PSS | 23,436 kB | 25,216 kB |
| Threads | 77 | 38 |
| Views / activities | 8 / 1 | 14 / 2 |

These are single debug observations, not a leak test.

---

## 4. Launch and UI responsiveness

| Test | Observation | Status |
|---|---|---|
| Parent cold start | Not measured (no force-stop; command restrictions) | NOT_MEASURED |
| Parent warm start | Not measured | NOT_MEASURED |
| Child cold/warm start | Not measured | NOT_MEASURED |
| Parent launch jank | `Skipped 139 frames!` on emulator | FAIL (P3, debug emulator) |
| Parent GC pause | ~159 ms concurrent mark-compact, no visible freeze | PASS |
| Screen transitions | Dashboard/Devices/Detail/Family/Alerts rendered without freeze | PASS |
| Infinite spinner | None observed | PASS |
| Stale data after resume | Parent retained old device row; child “Updated 2 d ago” | FAIL (P1) |
| Incorrect offline indicator | Parent Offline while child running | FAIL (P1) |

---

## 5. Battery and network

| Test | Observation | Status |
|---|---|---|
| Child battery optimization whitelist | Not whitelisted | NOT_TESTED |
| Battery drain over defined period | Not measured | NOT_MEASURED |
| Child foreground time | ~6 h 24 m in battery stats sample | PASS (recorded) |
| Network loss / recovery | Wi-Fi toggle not authorized | NOT_TESTED |
| Reconnect delay | Not measured | NOT_MEASURED |
| Realtime reconnect | Not observed | NOT_TESTED |
| Duplicate event submission | No duplicate events observed; duplicate device rows are separate | PASS (events) |

---

## 6. UX findings

- Stale values are labeled with old timestamps, not presented as live: PASS.
- “Updated Just now” describes the list refresh, not the device heartbeat; can be misread: P3.
- Duplicate revoked device row and policy v2/v4 mismatch reduce trust: P2.
- Child location warning is misleading relative to Android permissions: P2.
- No push notifications: requests/alerts depend on polling; this is a capability gap, not a crash.

---

## 7. Verdict

**PASS** — no crashes/ANRs; foreground service stable; screens render.

**FAIL (P1)** — stale/incorrect presence; **FAIL (P3)** — debug emulator launch jank.

Most timing, battery, network-recovery and long-run metrics are **NOT_MEASURED** and must not be inferred.
