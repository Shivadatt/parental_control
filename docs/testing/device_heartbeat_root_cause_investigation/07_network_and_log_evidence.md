# 07 — Network and Log Evidence

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED  
**No token, header, secret, pairing code or location was captured.**

---

## 1. Evidence available

### From the immediately preceding two-device phase (read-only observations)

| Observation | Value | Timestamp |
|---|---|---|
| Child date/time | 2026-11-21 11:48 IST | 11:48 |
| Child Wi-Fi | Connected, validated, RSSI −65 dBm | 11:48 |
| Child DNS / route | Present | 11:48 |
| Child ping to Supabase host | 64.5 ms; 1 of 2 packets | 11:48 |
| Child app TCP | ESTABLISHED to Supabase `:443` from app UID | 11:55 |
| Child `GuardianService` | `isForeground=true`, `foregroundId=4101`, channel `guardian_status` | 11:55 |
| Service age | `lastActivity ≈ -1d13h` (~37 h) | 11:55 |
| Child Home | “Updated 2 d ago” | 11:56 |
| Parent Devices | “Updated Just now”; active row Offline; last seen Nov 13 17:23 | 11:56 |
| Parent Dashboard | `Policy v4 · Waiting for device`; duplicate revoked row | 11:48 |
| Parent process | PID 3410, app foreground | 12:0x |
| Child app crash buffer | Empty | 11:55 |
| Parent app crash buffer | No Parent Control crash | 11:55 |

### From this phase

| Observation | Result |
|---|---|
| Parent app process/focus | PID 3410; `MainActivity` focused | PASS |
| Parent crash buffer | No Parent Control entry | PASS |
| Physical child ping/log/notification inspection | Refused by execution policy (“beyond source-only diagnostics”) | BLOCKED |
| Encrypted `guardian_last_error` read | Not attempted / would expose secure state | BLOCKED (by design) |
| Production endpoint invocation | Not performed | NOT TESTED (by design) |

---

## 2. What the network evidence proves

**PASS:**

- The child has a working network path to Supabase.
- The child app holds a TLS connection to the Supabase endpoint.
- The child guardian service is alive and foreground.
- The failure is not “no network” or “service killed.”

**Not proven:**

- Which request the established socket belongs to (heartbeat, command poll, or another call).
- That a heartbeat request was actually sent on that socket in the observation window.
- The HTTP status returned to a heartbeat.
- That the server rejected the credential (versus a client-side validation stop).

The connection is consistent with the heartbeat path but is not, by itself, proof that a heartbeat was transmitted.

---

## 3. Why ordinary logs do not show the heartbeat error

`GuardianService.recordError()`:

- truncates the message to 300 characters,
- stores it in `SecureStore` under `guardian_last_error`,
- emits a service-status event,
- updates the foreground notification text.

It does **not** call `android.util.Log` or `print`. There is no `Log.d`/`Log.e` in `GuardianService.kt`. Therefore:

- `adb logcat` contains no heartbeat failure line.
- The only safe runtime source is the app’s own UI/notification, which could not be inspected further under the policy.
- Reading `EncryptedSharedPreferences` was correctly refused; it may contain the device secret and must not be extracted.

This is an observability gap in the app, not just in the test environment.

---

## 4. Redaction

- No Authorization header, JWT, API key, device secret, secret hash, pairing code, password or refresh token was read or printed.
- No packet capture was used.
- No production endpoint was called.
- No unredacted log is stored in this report set.

---

## 5. Network/log verdict

**PASS** — sufficient evidence to exclude “child offline because the phone or app is dead.”

**BLOCKED** — exact HTTP rejection and stored guardian error are not observable with the authorized read-only tooling.

**Implication:** the root-cause classification in report 09 relies on source + install-timing evidence for the exact rejection, not on a captured 401 body.
