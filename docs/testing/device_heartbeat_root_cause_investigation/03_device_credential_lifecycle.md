# 03 — Device Credential Lifecycle

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED  
**No credential value, hash, installation ID or token is reproduced in this report.**

---

## 1. Lifecycle overview

```text
Fresh install / cleared app data
        │
        ▼
SecureStore.installationId()  ──► random UUID, persisted encrypted
SecureStore.deviceSecret()    ──► 32 random bytes, base64url, persisted encrypted
        │
        ▼
Child enrollment / registration
  getIdentity() ──► {installationId, secret, sha256(secret)}
  device-register(register) ──► creates devices row:
        id (server UUID), installation_id, secret_hash, status=active
        │
        ▼
Child shell load
  fetchMyDevice() ──► existing devices row for this child_user_id (status=active)
  getIdentity()   ──► local secret (possibly NEW after data loss)
  configureBackgroundSync(deviceId = existing row id, deviceSecret = local secret)
        │
        ▼
GuardianService heartbeat
  x-device-id = existing server UUID
  x-device-secret = local secret
        │
        ▼
device-telemetry requireDevice()
  sha256(secret) == devices.secret_hash ?
        │ yes                 │ no
        ▼                     ▼
  update last_seen_at     401 invalid_device_credentials
  parent sees healthy     last_seen_at unchanged
```

---

## 2. Source trace

### 2.1 Credential creation and persistence

`android/.../SecureStore.kt`

- `installationId()` — returns an existing UUID or creates one and persists it.
- `deviceSecret()` — returns an existing secret or generates 32 random bytes as base64url and persists it.
- Both live in `EncryptedSharedPreferences` under `parent_control_secure`.
- `saveConfig()` stores the backend URL, publishable key, server device ID, device secret and family ID.
- `config()` returns `null` unless **all** fields are present.

**Important:** the values are created lazily on first access after the encrypted store is empty. Uninstalling the app or clearing app data deletes this store. With `android:allowBackup="false"`, Android backup does not restore it.

### 2.2 Registration

`lib/features/child/controllers/child_enrollment_controller.dart`

- `needsDeviceRegistration => isLinked && !hasDevice`.
- `registerDevice()` immediately returns “This phone is already registered.” when `device.value != null`, without comparing the local secret to the server.
- Registration sends `installation_id` and the locally computed `secret_hash` through `device-register`.

`supabase/functions/device-register/index.ts`

- Looks up an existing row by `(family_id, installation_id)`.
- If found and owned by the same child, it **updates** `secret_hash` and re-credentials the row.
- If not found, it checks for any active device for the child. If one exists, it returns **409 `device_already_registered`**.
- Therefore, a new installation ID cannot re-credential an existing active device.

### 2.3 Normal shell startup

`lib/features/child/controllers/child_shell_controller.dart`

- `fetchMyDevice()` selects the child’s **active** device row (server-side).
- `_ensureIdentityAndSync()`:
  - reads the local identity,
  - copies `serverDeviceId = loadedDevice.id`,
  - calls `configureBackgroundSync(deviceId: loadedDevice.id, deviceSecret: identity.secret, ...)`.
- There is **no** registration, re-registration or credential-match check in this path.

### 2.4 Transmission and verification

`android/.../DeviceHttpClient.kt`

- Sends:
  - `x-device-id: <server device UUID>`
  - `x-device-secret: <local secret>`

`supabase/functions/_shared/auth.ts` — `requireDevice()`

- Rejects missing/blank headers (`401 device_auth_required`).
- Rejects non-UUID device ID or secret length outside 16–512 (`401 invalid_device_credentials`).
- Loads `devices.secret_hash`.
- Computes SHA-256 of the supplied secret and compares in constant time.
- Mismatch/unknown device → `401 invalid_device_credentials`.
- Revoked status or `credential_revoked_at` → `403 device_revoked`.
- Only on success does `device-telemetry` update `last_seen_at`.

---

## 3. Effect of update vs uninstall vs data clear

| Operation | App data | Local secret | Server `secret_hash` | Result |
|---|---|---|---|---|
| `adb install -r` (same signing key) | Preserved | Preserved | Unchanged | Match; heartbeat works |
| App update through a store | Preserved | Preserved | Unchanged | Match; heartbeat works |
| Uninstall then install | **Deleted** | **New** | Old value remains | **Mismatch; heartbeat 401** |
| Clear app data | **Deleted** | **New** | Old value remains | **Mismatch; heartbeat 401** |
| Restore from backup | Normally restored | Preserved | Unchanged | Match — but `allowBackup=false` disables this path |
| Revoke device | Preserved | Preserved | Set to `null`, status revoked | `403 device_revoked` |
| Unlink child | Preserved | Preserved | Set to `null`, status revoked | `403 device_revoked` |

The observed child build has `firstInstallTime = 2026-11-17 12:44`, while the active device’s last successful heartbeat was **2026-11-13 17:23**. That is direct evidence that the current install is **not** a continuation of the install that registered the device row. A fresh install necessarily created a new installation ID and secret.

---

## 4. Exact failure point

The failure is in the **normal shell startup path**, not in the heartbeat scheduler:

1. `fetchMyDevice()` returns the old active device row.
2. `device.value != null`, so enrollment/registration is considered unnecessary (`needsDeviceRegistration == false`; `registerDevice()` would return “already registered”).
3. `_ensureIdentityAndSync()` writes the **new** local secret into the background sync config together with the **old** server device ID.
4. Every heartbeat sends `old device ID + new secret`.
5. `requireDevice()` compares the new secret hash against the old row’s `secret_hash` and rejects it.
6. `last_seen_at` is never updated; the parent continues to show the old timestamp.

This is a credential mismatch introduced by reinstall/data loss and made permanent by the absence of a re-credentialing path.

---

## 5. Lifecycle verdict

**PASS (source trace)** — creation, persistence, registration, transmission, verification and failure handling are all identified.  
**CONFIRMED (timing + code)** — the current install postdates the last successful heartbeat and must have generated a new secret.  
**NOT DIRECTLY OBSERVED** — the exact 401 response body and the encrypted `guardian_lastError` value.  
No credential was read, printed, regenerated or changed.
