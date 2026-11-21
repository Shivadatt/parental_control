# 03 — Failure Point Source Evidence

**Purpose:** Pin the failure to exact source locations, classify each as verified or inferred, and enumerate every endpoint that depends on the same credential.  
**Mode:** Read-only source inspection. No runtime/production call was made.

**Legend:** `VERIFIED` = read directly from the file below; `INFERRED` = logically forced by the source but not executed; `REPORTED` = prior-phase observation, not re-executed here.

---

## 1. Failure chain with exact evidence

### F1 — Reinstall creates a new installation ID and secret

**File:** `android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:86-105`  
`installationId()` and `deviceSecret()` return the stored value only if non-blank; otherwise they generate and persist a new one. The store is `EncryptedSharedPreferences`, removed with app data/uninstall.

**Evidence class:** `VERIFIED`  
**Why it fails:** the new values are unrelated to the server row registered by the previous install.

---

### F2 — Flutter refuses to register when a device row is already loaded

**File:** `lib/features/child/controllers/child_enrollment_controller.dart:264-279`  
```dart
bool get needsDeviceRegistration => isLinked && !hasDevice;   // line 69
...
if (device.value != null) {                                   // line 276
  actionMessage.value = 'This phone is already registered.';
  return true;
}
```
The check is presence-based, not credential-based. No comparison with `secret_hash` is possible client-side because the hash is service-only and the local hash is never sent for verification.

**Evidence class:** `VERIFIED`  
**Effect:** the Child app never attempts a legitimate re-credential after reinstall.

---

### F3 — Server rejects a second active device for the same child

**File:** `supabase/functions/device-register/index.ts:197-208`
```ts
const activeDevice = await db.from("devices").select("id")
  .eq("child_user_id", auth.user.id).eq("status", "active").maybeSingle();
...
if (activeDevice.data) {
  throw new ApiError("device_already_registered",
    "This account already has an active device.", 409);
}
```
The earlier lookup (lines 141-150) matches `(family_id, installation_id)`. A reinstall has a different `installation_id`, so it misses the existing row and falls into the active-device guard.

**Evidence class:** `VERIFIED`  
**Effect:** no new row and no update of the old row.

---

### F4 — Shell binds the old UUID to the new secret

**File:** `lib/features/child/controllers/child_shell_controller.dart:570-605`
```dart
final nativeIdentity = await _deviceAdmin.getIdentity();
identity = nativeIdentity.copyWith(serverDeviceId: loadedDevice.id); // 582
...
final configured = await _deviceAdmin.configureBackgroundSync(
  deviceId: loadedDevice.id,           // old server UUID
  deviceSecret: identity.secret,       // new local secret
  familyId: loadedFamily.id,
);
```
No hash comparison, no registration, no recovery branch.

**Evidence class:** `VERIFIED`  
**Effect:** background sync is configured with a guaranteed-mismatched credential pair.

---

### F5 — Device authentication rejects the mismatch

**File:** `supabase/functions/_shared/auth.ts:297-353`
- headers required (299-309);
- UUID/length validation (310-317);
- load `secret_hash` (318-327);
- `sha256Hex(secret)` then `constantTimeEqualHex(digest, device.secret_hash)` (328-343);
- revoked/inactive check after hash match (345-351).

On mismatch: `401 invalid_device_credentials`. It performs a dummy comparison for unknown devices to keep timing similar.

**Evidence class:** `VERIFIED`  
**Effect:** every device-authenticated call fails while the mismatch persists.

---

### F6 — `last_seen_at` is never advanced

**File:** `supabase/functions/device-telemetry/index.ts:68-83`  
The heartbeat action calls `requireDevice()` at line 69 and only then updates `last_seen_at` at line 80. Because F5 throws first, the update is unreachable.

**Evidence class:** `VERIFIED`  
**Effect:** the server row's presence timestamp freezes at the last successful heartbeat.

---

### F7 — Parent derives "Offline" from the frozen timestamp

**File:** `lib/data/models/device.dart:394-458`
```dart
static const Duration onlineWindow  = Duration(minutes: 12);   // 394
static const Duration stalledWindow = Duration(minutes: 30);   // 399
DeviceSyncHealth get syncHealth { ... }                        // 414
String get statusLabel { ... 'Online' / 'Sync stalled' / 'Offline' ... } // 443
```
No server column records credential health; the Parent has no independent signal.

**Evidence class:** `VERIFIED`  
**Effect:** the Parent shows "Offline" indefinitely even though the Child process is running and authenticated as a **user** (only the device credential is rejected).

---

### F8 — The only rotation branch requires the same installation ID

**File:** `supabase/functions/device-register/index.ts:141-194`  
When `(family_id, installation_id)` matches and the row belongs to the same child, it updates `secret_hash`, `credential_issued_at`, `credential_revoked_at=NULL`, `status='active'`, and audits `device_recredentialed`.  
If the row is `revoked`, `assertReenrollmentAllowed()` (lines 51-88, 174-176) blocks unless a later approved pairing exists.

**Evidence class:** `VERIFIED`  
**Effect:** rotation exists **only** for the exact same install (e.g. a keystore reset that preserves `installation_id`), not for a reinstall.

---

### F9 — The only sanctioned recovery destroys the relationship

**Files:**
- `supabase/functions/family-admin/index.ts:92-121` (`recover_device`)
- `supabase/migrations/20260101000400_device_recovery.sql` (`request_device_recovery`)
- `supabase/migrations/20260101000100_functions.sql:325-420` (`private.unlink_child`)

`unlink_child` sets membership `removed`, revokes **all** child devices (`secret_hash=NULL`, `credential_revoked_at=now`), ends sessions, revokes pairing tokens, cancels pending requests, and audits `member_removed`. `request_device_recovery` then audits `device_recovery_started`.

**Evidence class:** `VERIFIED`  
**Effect:** the device and family link are destroyed; a new pairing and Child approval are required, producing a new device UUID.

---

## 2. Confidence assessment

| Finding | Confidence | Basis |
|---|---|---|
| Reinstall ⇒ new installation ID + secret | High | lazy getters + encrypted-store deletion |
| No client credential verification | High | absence of any hash comparison in shell/enrollment |
| Server refuses second active device | High | explicit 409 branch |
| Heartbeat rejected with mismatched secret | High | constant-time compare in `requireDevice` |
| `last_seen_at` frozen ⇒ Parent Offline | High | code path ordering |
| Live device returned exactly 401 | Medium | `REPORTED` in prior phase; not re-captured in this read-only pass |
| Existing `recover_device` is destructive | High | `unlink_child` source + SQL test `45_device_recovery.sql` |

---

## 3. Every endpoint that relies on the device secret

`requireDevice()` (`_shared/auth.ts:297`) is the only device gate. The table lists every call site found in the working tree.

| Endpoint | Action | File:line | Consequence of rotation |
|---|---|---|---|
| `device-telemetry` | `heartbeat` | `device-telemetry/index.ts:69` | Old secret fails; new secret updates `last_seen_at` |
| `device-telemetry` | `usage_upload` | `device-telemetry/index.ts:158` | Same |
| `device-telemetry` | `location_upload` | `device-telemetry/index.ts:240` | Same |
| `device-telemetry` | `apps_upload` | `device-telemetry/index.ts:358` | Same |
| `device-command` | `poll` | `device-command/handler.ts:291-292` | Old secret fails; new secret receives commands |
| `device-command` | `ack` | `device-command/handler.ts:310` | Old secret fails; new secret acknowledges |
| `remote-session` | `session_state` | `remote-session/index.ts:161-162` | Old secret fails; new secret joins assistance state |

No other endpoint authenticates a device. `pairing` authenticates **users** (JWT), not devices. `family-admin` authenticates **parents** (JWT + membership). `cron` uses a separate cron secret (`_shared/cors.ts`).

**Design implication:** rotation must change exactly one field (`secret_hash`) and the clients must re-read it consistently. Because all seven call sites consult the same row, a single atomic update is sufficient; no per-endpoint migration is needed.

---

## 4. Secondary failure points (not root cause, but relevant)

| ID | Location | Observation | Class |
|---|---|---|---|
| S1 | `GuardianService.kt:262-274` | 401/403 poll failures back off ×6 up to 300 s, so recovery is not retried aggressively, but the error is only `guardian_lastError`. | VERIFIED |
| S2 | `GuardianService.kt:497-521` | Heartbeat failure is swallowed into `recordError`; no distinct `credential_invalid` state. | VERIFIED |
| S3 | `child_shell_controller.dart:369-384` | `_refreshDeviceRow()` only updates the local Device if `loaded.isActive`; a revoked row silently leaves the old value. | VERIFIED |
| S4 | `device.dart:414-458` | Presence is inferred from age with no server health input; a credential-invalid device can only look "Offline", never "Needs re-authorization". | VERIFIED |
| S5 | `device_registration` | `assertReenrollmentAllowed` uses the latest approved pairing timestamp vs `credential_revoked_at`; a recovery design must not accidentally satisfy it. | VERIFIED |

---

## 5. Failure-point verdict

**CONFIRMED (source):** the failure is a missing credential-rotation capability, triggered by local secret loss, with no client detection and no relationship-preserving server path.

**NOT OBSERVED IN THIS PHASE:** live HTTP status/body from the production device. The prior phase reported it; this phase deliberately did not call production endpoints or read credentials.

No source file was modified.
