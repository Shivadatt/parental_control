# 09 — Root Cause and Confidence Assessment

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Classification

# A. CONFIRMED DEVICE CREDENTIAL MISMATCH

**Confidence: HIGH (approximately 0.9).**

The child’s current installation has a **new** device secret and installation ID, while the server’s active device row still holds the hash from the pre-reinstall credential. The child shell reuses the old server device ID with the new secret and never re-registers. The heartbeat therefore fails device authentication, and `last_seen_at` is never updated.

---

## 2. Evidence chain

| # | Evidence | Source | Strength |
|---|---|---|---|
| 1 | Child current install `firstInstallTime = 2026-11-17 12:44` | `dumpsys package` | Direct runtime |
| 2 | Active device’s last successful heartbeat = 2026-11-13 17:23 | Parent UI (`last_seen_at`) | Direct runtime |
| 3 | Current install postdates the last heartbeat by ~4 days | 1 + 2 | Direct inference |
| 4 | Fresh install deletes `EncryptedSharedPreferences`; `allowBackup=false` | `SecureStore.kt`, manifest | Source |
| 5 | `deviceSecret()` generates a new 32-byte secret when none exists | `SecureStore.kt` | Source |
| 6 | `installationId()` generates a new UUID when none exists | `SecureStore.kt` | Source |
| 7 | Child shell loads the existing active device row via `fetchMyDevice()` | `supabase_device_repository.dart` | Source |
| 8 | `_ensureIdentityAndSync()` stores `deviceId = loadedDevice.id` with the **new** local secret | `child_shell_controller.dart` | Source |
| 9 | Registration is skipped when a device row exists; `registerDevice()` returns “already registered” | `child_enrollment_controller.dart` | Source |
| 10 | `device-register` cannot re-credential an active device with a new installation ID; returns 409 | `device-register/index.ts` | Source |
| 11 | Backend heartbeat auth requires `sha256(secret) == devices.secret_hash`; mismatch → 401 and no update | `_shared/auth.ts` | Source |
| 12 | Heartbeat retries every 60 s; failure persists | `GuardianService.kt` | Source |
| 13 | Parent shows the stale `last_seen_at`; refresh executes but value is old | `devices_controller.dart`, `device.dart` | Source + runtime |
| 14 | Child service alive, network reachable, TLS socket established | prior E2E observations | Direct runtime |

No single link is a guess. The only unobserved link is the literal HTTP 401 response/`guardian_lastError` text.

---

## 3. Why not the other classifications

### B. Heartbeat authentication rejection for another reason

Possible rejection reasons besides hash mismatch:

- revoked credential → would be `403 device_revoked`; the active row is not revoked (the separate old row is). `revoke_device` sets `status=revoked` and clears the hash, so a revoked row would not appear as the active row the child fetches.
- malformed headers → the device ID comes from a server UUID and the secret is a generated 43-character value; both fit the validators.
- missing headers → `DeviceHttpClient` always sets both.

No alternative rejection is supported by the source/state. A 401 hash mismatch is the only one consistent with a fresh install and an old active row.

### C. Heartbeat not scheduled/executed

The service is alive, its config gates passed, its tick loop is unconditional, and a watchdog re-arms stalls. No crash/restart was observed. This is not the failure.

### D. Backend accepts heartbeat but DB update fails

The update is a service-role update by primary key with `ensureNoError`; a failure would be a 500, not a silent old value. The row is otherwise readable and active. No evidence of SQL failure.

### E. Backend updates but parent query/cache is stale

The parent re-queries every 60 seconds and its “Updated Just now” label reflects a successful fetch. The same old `last_seen_at` is shown on multiple screens. PostgREST read caching cannot persist an eight-day-old value across repeated queries.

### F. Multiple interacting causes

There are multiple **symptoms** (sync failure + duplicate rows + policy label + permission warning), but the heartbeat failure itself has one coherent cause. The P2s are independent presentation/query defects, not part of the heartbeat rejection.

### G. Insufficient evidence

The source+timing chain is strong enough to name the mechanism. The missing 401 body lowers certainty slightly but does not make the cause unknown. Labeling G would discard direct install-timing evidence.

---

## 4. Exact failure point

```text
Fresh install → new local secret + new installation ID
        │
fetchMyDevice() → old active device row (old ID, old secret_hash)
        │
_ensureIdentityAndSync()
  deviceId = old server UUID
  deviceSecret = new local secret
        │
GuardianService heartbeat
  x-device-id = old UUID
  x-device-secret = new secret
        │
requireDevice()
  sha256(new secret) != old secret_hash
  → 401 invalid_device_credentials
        │
devices.last_seen_at never updated
        │
parent shows Offline / 186 h old
```

The failure is **before the database update**, in the credential match. It is not in scheduling, not in the parent threshold, and not in the UI.

---

## 5. Residual uncertainty

| Unknown | Impact | How to confirm safely |
|---|---|---|
| Exact HTTP status/body | Confirms 401 vs 403 | Read Edge Function logs for the device-telemetry request, redacting headers; or surface `lastError` in a safe diagnostic UI |
| Exact `guardian_lastError` | Confirms the client-side message | Owner-approved child Settings/diagnostic view; never export secure prefs |
| Installed APK source revision | Confirms the code in the APK matches HEAD | Rebuild from a known commit and reproduce; record APK hash |
| Whether app data was cleared vs uninstalled | Explains how the secret was regenerated | Install/update history; both produce a new secret, so the conclusion is unchanged |

Even if the secret changed for a reason other than uninstall (e.g., keystore invalidation), the result is the same: local secret ≠ server hash, and there is no re-credential path.

---

## 6. Root-cause verdict

**A — confirmed device credential mismatch**, with the precise failure at `_ensureIdentityAndSync()` + `requireDevice()` and the missing re-registration path as the systemic cause. Confidence high; the only unobserved link is the literal rejection response.
