# 02 — Existing Child Device Identity Lifecycle (Reconstructed)

**Purpose:** Reconstruct the real lifecycle of an existing Child device identity from repository source, not from assumptions.  
**Mode:** Read-only. No credential value is reproduced. Identity values are described by type and role only.

**Legend:** `VERIFIED (source)` = read directly from the cited file; `INFERRED` = follows from source but not directly exercised in this phase; `REPORTED` = from prior phase evidence.

---

## 0. Identity primitives

| Primitive | Where created | Type / shape | Where stored | Server source of truth |
|---|---|---|---|---|
| `installation_id` | `SecureStore.installationId()` `android/.../SecureStore.kt:86` | Random UUID string (8–128 chars by DB check) | `EncryptedSharedPreferences` file `parent_control_secure`, key `installation_id` | `devices.installation_id` |
| `device secret` | `SecureStore.deviceSecret()` `SecureStore.kt:94` | 32 random bytes, base64url no padding | Same encrypted file, key `device_secret` | Never stored; only `devices.secret_hash` |
| `secret_hash` | `NativeBridge.getDeviceIdentity()` `NativeBridge.kt:206-218` | lowercase SHA-256 hex (64 chars) | Never persisted by the app; sent to `device-register` | `devices.secret_hash` |
| `server device UUID` | `device-register` insert (`device-register/index.ts:211-230`) | UUID (`gen_random_uuid()`) | Returned to the app; copied into `SyncConfig` | `devices.id` |
| `family_id` | Family membership | UUID | Local settings + `SyncConfig` | `family_members.family_id` / `devices.family_id` |

The raw secret and its hash are **never logged** by the app: `SecureStore.kt` header states values in the encrypted store must not be logged; `DeviceHttpClient.kt` sends credentials only as headers.

`PASS (source)`.

---

## 1. First installation

**Step 1.1 — SecureStore initialisation**  
File/function: `SecureStore.init` (`SecureStore.kt:75-84`).  
Creates/opens `EncryptedSharedPreferences` with an AES256-GCM master key.  
Expected: encrypted store opens. Failure: constructor throws; `NativeBridge` reports `secure_storage_unavailable` (`NativeBridge.kt:206-212`) and no identity exists.  
`VERIFIED (source)`.

**Step 1.2 — Installation ID creation**  
`SecureStore.installationId()` (`SecureStore.kt:86-92`): returns existing value or creates `UUID.randomUUID()` and persists it.  
Source of truth after registration: `devices.installation_id`.  
`VERIFIED (source)`.

**Step 1.3 — Device secret creation**  
`SecureStore.deviceSecret()` (`SecureStore.kt:94-105`): returns existing or generates 32 bytes via `SecureRandom`, base64url-encodes, persists.  
Same lazy-creation property: it is created on first identity read after the store is empty.  
`VERIFIED (source)`.

**Step 1.4 — Local encrypted persistence**  
`saveConfig(SyncConfig)` (`SecureStore.kt:107-115`) stores backend URL, publishable key, server device ID, device secret, family ID. `config()` (`SecureStore.kt:117-131`) returns `null` unless **all** fields are present.  
Consequence: a partially written config is treated as "no background sync" rather than a half-valid credential.  
`VERIFIED (source)`.

**Step 1.5 — Identity exposed to Flutter**  
`NativeBridge.getDeviceIdentity()` (`NativeBridge.kt:206-219`) returns `installationId`, `secret`, `secretHash`. Flutter model `DeviceIdentity` (`lib/data/models/device.dart:787-822`) carries the same plus optional `serverDeviceId`, and `authHeaders()` emits `x-device-id` + `x-device-secret`.  
`VERIFIED (source)`.

---

## 2. Pairing, membership and registration

**Step 2.1 — Family link must exist before registration**  
`ChildEnrollmentController.registerDevice()` rejects when `family.value == null` (`child_enrollment_controller.dart:264-274`). Family linking is a separate pairing flow (`supabase/functions/pairing/index.ts`).  
Server check: `assertChildMembership()` requires an **active** `child` membership (`_shared/auth.ts:239-253`).  
`VERIFIED (source)`.

**Step 2.2 — Registration request**  
`SupabaseDeviceRepository.registerDevice()` (`supabase_device_repository.dart:74-104`) sends `family_id`, `installation_id`, `secret_hash`, display name, platform, versions to `device-register` action `register`. Raw secret is not sent.  
`VERIFIED (source)`.

**Step 2.3 — Server insert**  
`device-register/index.ts`:
- validates `installation_id` and 64-hex `secret_hash` (lines 122-123);
- looks up an existing row by `(family_id, installation_id)` (lines 141-150);
- if absent and **any** active device exists for the child → `409 device_already_registered` (lines 197-207);
- otherwise inserts with `family_id`, `child_user_id`, `installation_id`, `secret_hash`, `status='active'`, `credential_issued_at=now` (lines 210-230);
- writes audit `device_registered` (lines 232-239).

DB constraints: `devices_family_installation_key` unique `(family_id, installation_id)`; partial unique index `devices_one_active_per_child` on `child_user_id` where `status='active'` (`20260101000000_core.sql:111-119`).  
`VERIFIED (source)`.

**Step 2.4 — Registration response**  
`publicDevice()` strips `secret_hash` and `installation_id` (`device-register/index.ts:42-49`). Flutter stores the returned device row in `device.value` and sets `serverDeviceId` into the session identity (`child_enrollment_controller.dart:306-317`).  
`VERIFIED (source)`.

---

## 3. Normal startup on an enrolled device

**Step 3.1 — Membership read**  
`ChildShellController._loadMembershipAndDevice()` reads `fetchMyMembership()`, requires `isActive` and role `child` (`child_shell_controller.dart:208-224`). If not, it clears linked state and stops services.  
`VERIFIED (source)`.

**Step 3.2 — Device read**  
`SupabaseDeviceRepository.fetchMyDevice()` selects the child's row with `child_user_id = auth.uid()` **and `status='active'`** (`supabase_device_repository.dart:58-70`). A revoked row is therefore invisible to the Child; the old row remains the only candidate while it is active.  
`VERIFIED (source)`.

**Step 3.3 — `_ensureIdentityAndSync()`**  
`child_shell_controller.dart:570-621`:
1. native identity read;
2. `identity.copyWith(serverDeviceId: loadedDevice.id)` (line 582);
3. `configureBackgroundSync(deviceId: loadedDevice.id, deviceSecret: identity.secret, familyId: loadedFamily.id)` (lines 599-605);
4. `SyncConfig` persisted natively (`NativeBridge.kt:357-379`).

There is **no** comparison between the locally computed `secretHash` and any server value, and no registration attempt when a row already exists.  
`VERIFIED (source)`.

**Step 3.4 — Background sync start**  
`_resumeBackgroundWork()` / `startGuardianService` path sets `guardian_should_run` and starts `GuardianService` (`SecureStore.kt`, `NativeBridge.kt`).  
`VERIFIED (source)`.

---

## 4. Device-authenticated operations (all share one secret)

`requireDevice()` (`_shared/auth.ts:297-353`) is the single device-authentication gate. Consumers:

| Endpoint / action | File | Effect if secret matches |
|---|---|---|
| `device-telemetry` `heartbeat` | `device-telemetry/index.ts:68` | Updates `last_seen_at`, battery, capabilities |
| `device-telemetry` `usage_upload` | `device-telemetry/index.ts:157` | Inserts usage rows |
| `device-telemetry` `location_upload` | `device-telemetry/index.ts:239` | Inserts location events / safe-zone state |
| `device-telemetry` `apps_upload` | `device-telemetry/index.ts:357` | Replaces reported app list |
| `device-command` `poll` | `device-command/handler.ts:291` | Returns queued commands |
| `device-command` `ack` | `device-command/handler.ts:310` | Records command acknowledgement |
| `remote-session` `session_state` | `remote-session/index.ts:161` | Returns assistance session state |

`VERIFIED (source)` for all rows.

**Step 4.1 — Heartbeat**  
`GuardianService.sendHeartbeat()` (`GuardianService.kt:497-521`) posts `device-telemetry` `heartbeat` through `DeviceHttpClient.post()` (`DeviceHttpClient.kt:19-65`), which sets `x-device-id` / `x-device-secret`.  
`VERIFIED (source)`.

**Step 4.2 — `last_seen_at` update**  
`device-telemetry/index.ts:78-83` builds `{ last_seen_at: now }` and updates `devices` by `device.id`. Only reached after `requireDevice()` succeeds.  
`VERIFIED (source)`.

**Step 4.3 — Parent status calculation**  
`Device.syncHealth` (`lib/data/models/device.dart:414-425`) derives health from `lastSeenAt` age: `<12 min` healthy, `<30 min` stalled, else offline. `statusLabel` (`device.dart:443-458`) maps healthy → "Online", stalled → "Sync stalled", else "Offline"/"Never synced". The server stores **no** health column.  
`VERIFIED (source)`.

**Step 4.4 — Failure handling**  
On non-2xx, `DeviceHttpClient` throws `DeviceHttpException`; `sendHeartbeat` catches it and records `store.lastError` via `recordError()` (`GuardianService.kt:519-520, 682-690`). Poll failures apply status-aware backoff (401/403 → ×6, max 300 s) (`GuardianService.kt:262-274`). The error is surfaced as `guardian.lastError`/service status, **not** as a direct "credential mismatch" UI state.  
`VERIFIED (source)`.

---

## 5. Reinstall / local data loss

**Step 5.1 — Local store loss**  
Uninstall or "clear app data" deletes `EncryptedSharedPreferences`. `android:allowBackup` is not relied upon for credential restoration (prior phase `03_device_credential_lifecycle.md`).  
`PASS (source round-trip; loss mechanism is platform behavior)`.

**Step 5.2 — New identity on next launch**  
Because `installationId()` and `deviceSecret()` are lazy, the first identity read creates **new** values. `PASS (source)`.

**Step 5.3 — Existing active row is rediscovered**  
`fetchMyDevice()` still returns the old active row (same `child_user_id`, unchanged `status`).  
`PASS (source)`.

**Step 5.4 — Duplicate active-device handling**  
Two independent guards:
- Flutter: `registerDevice()` returns "This phone is already registered." without comparing secrets (`child_enrollment_controller.dart:276-279`).
- Server: `device-register` finds no row for the **new** installation ID, then finds an active device for the child → `409 device_already_registered` (`device-register/index.ts:197-207`).

There is **no** path that maps a new installation ID onto the existing active row.  
`VERIFIED (source)`.

**Step 5.5 — Heartbeat rejection**  
The old row's `secret_hash` is unchanged. The new local secret hashes differently. `requireDevice()` returns `401 invalid_device_credentials` (`_shared/auth.ts:329-343`). `last_seen_at` is not updated.  
`VERIFIED (source)`.

**Step 5.6 — Parent display**  
Because `last_seen_at` is stale, `syncHealth` becomes `offline` and `statusLabel` becomes "Offline" (`device.dart:414-458`).  
`VERIFIED (source)`.

**Step 5.7 — Actual vs expected**

| Aspect | Expected by a user | Actual |
|---|---|---|
| Family relationship | Preserved | Preserved (membership untouched) |
| Device row | Same device | Same row/UUID, old credential |
| Heartbeat | Works after reinstall | `401`, never updates |
| Parent presence | Online when phone is on | Offline indefinitely |
| Child feedback | Clear "needs re-authorization" | Generic guardian `lastError` only |

`VERIFIED (source)` for the mechanisms; the exact 401 body on the live device was `REPORTED` in the prior phase but not captured in this read-only phase. `NOT TESTED` directly.

---

## 6. Other identity-affecting paths

| Path | Function | Effect |
|---|---|---|
| Parent revoke | `family-admin revoke_device` → `private.revoke_device` (`20260101000100_functions.sql:432-500`) | `status='revoked'`, `secret_hash=NULL`, `credential_revoked_at=now`, ends sessions, cancels pending pairings, audit |
| Parent/child unlink | `pairing unlink` → `private.unlink_child` (`20260101000100_functions.sql:325-420`) | Membership `removed`; **all** child devices revoked; sessions ended; pairing tokens/requests cancelled; audit `member_removed` |
| Parent recovery | `family-admin recover_device` → `request_device_recovery` (`20260101000400_device_recovery.sql`) | Calls `unlink_child`, then audit `device_recovery_started` |
| Re-registration after revocation | `device-register` `assertReenrollmentAllowed` (`device-register/index.ts:51-88`) | Blocks until a **later** approved pairing exists; otherwise `403 device_revoked` |

`VERIFIED (source)`.

---

## 7. Lifecycle gaps identified

1. **No credential-confirmation step.** The shell never checks whether the local secret matches the server before binding it.
2. **No relationship-preserving rotation.** The only rotation branch requires the same `installation_id`.
3. **No Child-visible sync-failure state.** `guardian_lastError` is diagnostic text, not an actionable recovery prompt.
4. **Presence is client-derived only.** There is no server-side "credential invalid" state the Parent could display.
5. **One secret, many endpoints.** Rotation must be atomic across the credential, or different endpoints would disagree mid-rotation.

These gaps drive the design in reports 04–07.

---

## 8. Verification statement

All items marked `VERIFIED (source)` were read from the working tree at HEAD `bbd3c21`. No credential value, secret, hash, JWT, service key or installation ID was read, printed or stored. No production endpoint was called.
