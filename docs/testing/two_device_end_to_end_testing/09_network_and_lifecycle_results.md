# 09 — Network and Lifecycle Results

**Date:** 2026-11-21  
**Devices:** Realme RMX2161 (child), Pixel 9a emulator (parent)  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Network baseline

| Check | Observation | Label |
|---|---|---|
| Child Wi-Fi state | Wi-Fi connected, validated, SSID available, RSSI −65 dBm, 433 Mbps link | PASS |
| Child DNS / routing | DNS servers present; default route present | PASS |
| Child reachability to Supabase host | `ping` succeeded: 64.5 ms, 1 of 2 packets (50% ICMP loss) | PASS |
| Child app TLS connection | ESTABLISHED TCP socket to `104.18.38.10:443` from app UID | PASS |
| Parent emulator network | App loaded family/device data and refreshed lists | PASS |
| Parent/child clock | Child date 2026-11-21 11:48 IST; no clock skew observed | PASS |

Network is not the cause of the stale child state: the app has a live TLS connection and the host is reachable.

---

## 2. Failure and recovery tests

| Test | Result | Label |
|---|---|---|
| Disable child Wi-Fi, observe parent offline | Not performed; policy refused network-state changes | NOT TESTED |
| Restore child Wi-Fi, observe reconnect | Not performed | NOT TESTED |
| Disable mobile data | Not performed; device is Wi-Fi only in this setup | NOT TESTED |
| Observe API failure / retry banner | Child requests card showed a timeout once, then cleared | FAIL (observed once) |
| Infinite spinner | None observed on any inspected screen | PASS |
| Duplicate event submission | No duplicate events observed; duplicate device rows are a separate P2 | PASS (events) |
| False online state | None; parent conservatively shows Offline | PASS |

The one observed timeout (“Some requests could not be loaded — The request timed out. Try again.”) is consistent with the broader device-authentication/synchronization failure. It was not reproduced after relaunch.

---

## 3. Child lifecycle

| Step | Observation | Label |
|---|---|---|
| Launch child app | Child shell loaded; family `demo`; session persisted | PASS |
| Background child app | Guardian service remained foreground | PASS |
| Reopen child app | Child shell restored; stale data labeled “Updated 2 d ago” | PASS (lifecycle) / FAIL (freshness) |
| Lock screen | Not performed | NOT TESTED |
| Unlock and recover | Not performed | NOT TESTED |
| Permission remains accurate after resume | Android state unchanged; app warning still inconsistent | PASS / FAIL (P2) |
| Unexpected crash | None | PASS |
| Battery optimization handling | Not whitelisted; no guidance test performed | NOT TESTED |

The guardian service has remained alive for roughly 37 hours (`lastActivity ≈ -1d13h`). This is strong evidence that background execution is working and the missing updates are not caused by the service being killed.

---

## 4. Parent lifecycle

| Step | Observation | Label |
|---|---|---|
| Launch parent app | Parent shell loaded; family `demo` | PASS |
| Background parent app | App moved to launcher; process remained alive | PASS |
| Reopen parent app | Returned to Devices tab; session valid; data re-read | PASS |
| Lock/unlock emulator | Not performed | NOT TESTED |
| Realtime reconnection | Not independently observed | NOT TESTED |
| Authentication after resume | Session persisted; no login prompt | PASS |
| Unexpected crash / ANR | None observed | PASS |

No force-stop or app-data clear was used as a lifecycle substitute.

---

## 5. Logs and diagnostics

Collected with ADB and filtered to remove tokens, authorization headers, keys and credentials.

| Source | Result |
|---|---|
| Child app crash buffer | Empty |
| Parent app crash buffer | No app crash; a system Bluetooth process crash was present and unrelated to Parent Control |
| App ANR events | None for Parent Control in the current event buffer |
| Parent app log | Normal Flutter/Activity lifecycle; “Skipped 139 frames” during launch; GC pause ~159 ms |
| Child app log | No Flutter/Kotlin exception or HTTP error logged in the captured window |
| Unredacted logs committed | No |

An old ANR trace file dated 2026-11-13 exists on the child device; it is not evidence of a current ANR and was not caused by this test.

---

## 6. Network and lifecycle verdict

**PASS** — both apps survive background/relaunch, sessions persist, the child foreground service remains alive, and no app crash/ANR was observed.

**FAIL** — the child data is not refreshed despite a live network and running service.

**NOT TESTED** — deliberate network loss/recovery, lock-screen survival, and Realtime reconnect. These must be retested after the P1 synchronization fault is fixed.
