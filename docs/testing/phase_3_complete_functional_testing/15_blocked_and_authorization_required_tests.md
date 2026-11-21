# 15 — Blocked and Authorization-Required Tests

**Date:** 2026-11-21  
**Statuses:** BLOCKED / AUTHORIZATION_REQUIRED / NOT_TESTED  
**No blocked test is counted as a pass.**

---

## 1. Environment-blocked tests

| Block ID | Test area | Reason | What would unblock it |
|---|---|---|---|
| B01 | APK build from config | Execution policy refused secret-bearing config read/build | Owner-run build or approved build environment |
| B02 | APK install/update | No build artifact; policy | Explicit install approval + artifact hash |
| B03 | `fvm flutter pub get` | Policy: may modify lockfiles | Read-only dependency state accepted, or approval |
| B04 | Deno re-run | Policy: project-local cache write | Approved cache location / offline runner |
| B05 | Kotlin JVM tests | Gradle mixed-drive failure (`D:` vs `C:` pub cache) | Fix build root layout (not authorized) or run on another checkout |
| B06 | Child UI navigation | Policy refused physical-device interaction | Explicit device-inspection approval |
| B07 | Parent Settings/Location/Usage/App restrictions navigation | Policy refused further UI taps | Explicit emulator UI approval |
| B08 | Wi-Fi loss/recovery | Policy refused network-state change | Explicit network-toggle approval |
| B09 | Lock-screen/reboot lifecycle | Not performed to avoid service/session disruption | Explicit lifecycle approval |
| B10 | Production endpoint live calls | Prohibited by phase | Separate live-test authorization |
| B11 | Packet capture / 401 body | Prohibited / would expose credentials | Server log query with redaction, or safe diagnostic UI |
| B12 | Encrypted `guardian_lastError` | Secure prefs may contain credentials | Safe UI/diagnostic, not prefs extraction |

---

## 2. Authorization-required product actions

These actions would create, modify or delete production data or change the relationship/session.

| ID | Action | Why gated |
|---|---|---|
| AR01 | Link child / create pairing code | Creates pairing request |
| AR02 | Redeem code | Creates membership |
| AR03 | Approve/decline pairing | Changes relationship |
| AR04 | Unlink child | Destroys relationship |
| AR05 | Revoke device | Invalidates credential |
| AR06 | Recover device | Unlinks/revokes device |
| AR07 | Save app-restriction policy | Writes policy version/command |
| AR08 | Sync now | Writes command |
| AR09 | Save daily limit / bedtime | Writes policy |
| AR10 | Safe-zone create/edit/delete/activate | Writes zone rows |
| AR11 | Acknowledge alert | Writes server state |
| AR12 | Request audio assistance | Creates session request |
| AR13 | Request video assistance | Creates session request |
| AR14 | Accept remote session / join media | Activates camera/microphone |
| AR15 | End remote session | Writes session state |
| AR16 | Update retention settings | Writes family settings |
| AR17 | Purge old data | Destructive |
| AR18 | Export account data | Generates exported data |
| AR19 | Delete account | Destructive |
| AR20 | Sign out | Changes session; requires re-login |
| AR21 | Change notification/location preferences | Local state change; avoided |
| AR22 | Reboot child device | Service/session disruption |
| AR23 | Device Owner provisioning | Managed-device change |
| AR24 | Any production SQL/RLS/Edge deployment | Prohibited |

---

## 3. Features whose backend path is blocked by E2E-001

These cannot be verified until the device credential is repaired:

- App-list upload (C17)
- Usage upload (C18)
- Location upload (C19)
- App inventory upload (C25)
- Policy download/poll (C26)
- Safety-event reporting (C32)
- Parent location/usage freshness (P39–P41)
- Parent policy delivery/ack progression (P26/P27 live)
- New alert generation and realtime delivery (P45/P47)
- Remote-session state freshness (P50–P53)

They are marked BLOCKED or NOT_TESTED, never PASS.

---

## 4. What is still safely testable after authorization

1. Read-only child Rules/Settings/Requests screens.
2. Read-only parent Settings/Location/Usage/App restrictions/Safe zones/Audit screens.
3. Server log inspection for the rejected heartbeat (redacted).
4. A safe child diagnostic that displays `lastError` without exposing secrets.
5. Network-loss/recovery and lock-screen lifecycle.
6. Fresh build/install from a known commit with hash recorded.

---

## 5. Verdict

**12 environment blocks, 24 authorization-required actions, 10 blocked dependent features.**  
No production mutation was executed and no blocked test was reported as passing.
