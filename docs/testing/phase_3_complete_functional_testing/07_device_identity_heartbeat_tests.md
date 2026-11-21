# 07 — Device Identity and Heartbeat Tests

**Date:** 2026-11-21  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / NOT_IMPLEMENTED  
**No secret, hash or token is reproduced.**

---

## 1. Test results

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| H01 | Installation identity created | Random installation ID persisted | Source creates one on first access; current install postdates last heartbeat | PASS (source) |
| H02 | Device secret created | Random secret persisted encrypted | Source creates 32 random bytes; encrypted store | PASS (source) |
| H03 | Secret survives `install -r` | Same secret, heartbeat continues | Not tested; current install is a fresh install, not an update | NOT_TESTED |
| H04 | Secret survives data clear | Same secret | Not true: clear deletes store | FAIL by design |
| H05 | Registration binds secret hash | Server stores hash for row | Source does; prior relationship row exists | PASS (source) |
| H06 | Shell reuses active device row | Use registered device ID | `fetchMyDevice()` returns active row | PASS |
| H07 | Shell notices credential mismatch | Re-register or surface error | No check; configures old ID + new secret | **FAIL (P1)** |
| H08 | Heartbeat sends both headers | `x-device-id` + `x-device-secret` | Source-complete | PASS (source) |
| H09 | Backend verifies hash | 401 on mismatch | `requireDevice` constant-time compare | PASS (source) |
| H10 | Heartbeat updates `last_seen_at` | Fresh timestamp | Parent still shows Nov 13 | **FAIL (P1)** |
| H11 | Heartbeat retries after failure | Retry without storm | 60 s retry; command poll backoff 6× on 401/403 | PASS (source) |
| H12 | Parent reads updated field | Online within 12 min | Offline, 187 h old | **FAIL (P1)** |
| H13 | Child reports heartbeat failure | Visible safe error | Message only in secure `lastError`/notification; not surfaced on Home | FAIL (observability) |
| H14 | Re-credentialing after reinstall | Safe recovery path | No path; `registerDevice` returns “already registered” | NOT_IMPLEMENTED |

---

## 2. Source-level failure path

```text
SecureStore: new installation ID + new secret
        │
fetchMyDevice(): old active device row
        │
_ensureIdentityAndSync()
  deviceId = old UUID
  deviceSecret = new secret
        │
GuardianService heartbeat
        │
requireDevice(): sha256(secret) != old secret_hash
  → 401 invalid_device_credentials
        │
last_seen_at unchanged
        │
parent: age > 30 min → Offline
```

Exact source points:

- `SecureStore.kt` — `installationId()`, `deviceSecret()`, `saveConfig()`
- `child_shell_controller.dart` — `_ensureIdentityAndSync()`
- `child_enrollment_controller.dart` — `needsDeviceRegistration`, `registerDevice()`
- `device-register/index.ts` — lookup by installation ID; 409 for existing active device
- `_shared/auth.ts` — `requireDevice()`
- `device-telemetry/index.ts` — heartbeat patch `last_seen_at`
- `GuardianService.kt` — `sendHeartbeat()`, `recordError()`
- `device.dart` — 12/30-minute presence thresholds

---

## 3. Runtime evidence

- Child `GuardianService` foreground, id 4101, alive ~37 h.
- Child app had an ESTABLISHED TLS connection to Supabase.
- Child Home: “Updated 2 d ago”.
- Parent: Offline, last seen 2026-11-13 17:23 (187 h).
- Child current install: 2026-11-17 (after the last heartbeat).
- No app crash or ANR; failure is not service death.

The literal 401 body and `guardian_lastError` remain unobserved. Classification in report 14 is **A — confirmed credential mismatch** with high confidence.

---

## 4. Verdict

**FAIL (P1).** Device identity is created and stored correctly, but the app has no re-credential path after data loss. Heartbeat is scheduled and retried; it is rejected at authentication before updating `last_seen_at`.
