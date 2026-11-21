# 06 — Realtime and Synchronization

**Date:** 2026-11-21  
**Child:** Realme RMX2161, Android 12 / API 31  
**Parent:** Pixel 9a emulator, Android 17 / API 37  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Executive finding

**The child app is running and connected, but the parent sees it as Offline with data from Nov 13, 2026.** This is a confirmed two-device synchronization failure and the primary P1 finding of this test.

---

## 2. Observed timeline

| Time (IST) | Observation |
|---|---|
| 11:48 | Child app launched; child Home shows family `demo`, location-sharing card, requests card |
| 11:48 | Child Home initially shows “Some requests could not be loaded — The request timed out. Try again.” |
| 11:48 | Parent Dashboard shows two `realme RMX2161` rows: one Revoked, one Offline |
| 11:49 | Parent Devices tab: “Updated Just now”; both device rows still Offline/Revoked, last seen 186–193 h ago |
| 11:55 | Child `GuardianService` confirmed running as a foreground service (`foregroundId=4101`) |
| 11:55 | Child process has an ESTABLISHED TCP connection to the Supabase HTTPS endpoint (`104.18.38.10:443`) |
| 11:56 | Child Home now shows “Updated 2 d ago” and no timeout banner |
| 12:00 | Parent still shows the linked device Offline, last seen Nov 13, 2026 5:23 PM |

The child has been running with a visible guardian notification for about 37 hours (`lastActivity ≈ -1d13h`), yet the parent’s last-seen value predates the current app installation (2026-11-17 12:44).

---

## 3. What works

| Check | Evidence | Label |
|---|---|---|
| Child has network | Wi-Fi validated; ping to `hhqgreaoqulmfwfwarhc.supabase.co` succeeded (64.5 ms) | PASS |
| Child app can open HTTPS | ESTABLISHED socket to Supabase `:443` from app UID | PASS |
| Guardian foreground service | `GuardianService` foreground, notification `4101`, channel `guardian_status` | PASS |
| Child reads its family | `demo` displayed | PASS |
| Parent reads family/device rows | Family and devices load | PASS |
| Parent list refresh timestamp | “Updated Just now” | PASS (list refresh only) |

---

## 4. What fails

| Check | Expected | Actual | Label |
|---|---|---|---|
| Child heartbeat updates `last_seen` | Recent timestamp within the heartbeat window | Nov 13, 2026 5:23 PM (186 h old) while the child is running | FAIL |
| Parent sees current child state | Online / recent heartbeat | Offline | FAIL |
| Child local refresh | Data refreshed while app runs | “Updated 2 d ago” | FAIL |
| Child request polling | Pending requests load promptly | Initial timeout, later “0 pending” from cached/partial state | FAIL (observed once) |
| Realtime channel delivery | Parent receives live changes | No new event observed | NOT TESTED |
| Duplicate event prevention | No duplicate rows/events | Two device rows for the same phone (one revoked) | FAIL (P2) |

---

## 5. Root-cause assessment

**Confirmed:** the child app is alive, its guardian service is running, and it has an established HTTPS connection. The failure is not “app closed” or “no network.”

**Most likely cause (not server-confirmed):** device-credential desynchronization after a debug reinstall. The repository documents this as a known failure mode:

- A debug reinstall can regenerate the local hardware-keystore secret while the server retains the old `secret_hash`.
- Device-authenticated heartbeat/telemetry endpoints then reject the device until recovery/re-pairing.
- Read-only user-session queries (family data) can still work, which matches the child showing `demo` while heartbeat fails.

Supporting observations:

- Child current install: 2026-11-17; last successful device heartbeat: 2026-11-13 (before install).
- Guardian service running for ~37 hours with no visible server-side freshness update.
- App can reach Supabase over TLS.
- Prior reports (`docs/testing/phase_3_0_*`, `docs/bug-report.md`, E-16) describe this exact credential-desync pattern after debug reinstalls.

**Not established:** the exact server response (401/403) was not captured because device credentials, request headers and backend logs were out of scope and would contain secrets. No server administration was performed.

---

## 6. Realtime channel and reconnect

- No safe new Realtime event was generated, so subscription delivery was not independently observed.
- Wi-Fi was not toggled because the execution policy refused network-state changes and the relationship was to be preserved.
- No false “online” state was observed: the parent conservatively shows Offline.
- The parent does not present stale timestamps as current; it labels them as old.
- The child does show “Updated 2 d ago”, which is honest but indicates the app is not self-refreshing.

**Labels:** Realtime delivery — NOT TESTED. Network reconnect — NOT TESTED. False-online — PASS (none observed).

---

## 7. Synchronization verdict

**FAIL (P1).** The essential two-device synchronization objective is not met: a running, consenting child device is not represented as current on the parent dashboard. The most likely blocking cause is invalid device credentials after the prior debug installation, but that must be confirmed by an owner-approved recovery/diagnostic step before changing code.
