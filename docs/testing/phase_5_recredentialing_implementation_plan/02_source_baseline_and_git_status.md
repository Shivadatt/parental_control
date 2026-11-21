# 02 — Existing Architecture and End-to-End Recovery Flow

**Scope:** Reconstruct the current implementation from source, then describe the approved Option C flow for future implementation. Planning only.

---

## 1. Current identity lifecycle (verified from source)

### 1.1 Local identity creation
- `SecureStore.installationId()` (`android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:86-92`) returns a stored UUID or creates one.
- `SecureStore.deviceSecret()` (`SecureStore.kt:94-105`) returns a stored 32-byte base64url secret or creates one.
- Both live in `EncryptedSharedPreferences` (`parent_control_secure`); uninstall/clear-data removes them.
- `saveConfig(SyncConfig)` (`SecureStore.kt:107-115`) stores URL, publishable key, server device id, secret, family id in one editor.
- `config()` (`SecureStore.kt:117-131`) returns null unless all fields exist.
- `NativeBridge.getDeviceIdentity()` (`NativeBridge.kt:206-219`) exposes `installationId`, `secret`, `sha256(secret)` to Flutter.

### 1.2 Enrollment and registration
- `ChildEnrollmentController.needsDeviceRegistration` (`child_enrollment_controller.dart:69`) is `linked && !hasDevice`.
- `registerDevice()` (`child_enrollment_controller.dart:264-325`) refuses when `device.value != null` (lines 276–279) with "already registered", without comparing the secret.
- `SupabaseDeviceRepository.registerDevice()` (`supabase_device_repository.dart:74-104`) sends `family_id`, `installation_id`, `secret_hash`, display name and versions to `device-register`.
- `device-register` (`supabase/functions/device-register/index.ts`):
  - auth/role at 106–111; validation 120–137; `assertChildMembership` at 139;
  - same-`installation_id` lookup 141–150; update branch 165–195 (audits `device_recredentialed`);
  - active-device guard 197–208 → `409 device_already_registered`;
  - insert 210–230; audit 232–239.

### 1.3 Normal shell startup
- `ChildShellController._loadMembershipAndDevice()` (`child_shell_controller.dart:208-252`) requires active child membership, loads family and `fetchMyDevice()`.
- `SupabaseDeviceRepository.fetchMyDevice()` (`supabase_device_repository.dart:58-70`) selects the child's **active** row.
- `_ensureIdentityAndSync()` (`child_shell_controller.dart:570-621`) binds the **old server device id** to the **current local secret** and calls `configureBackgroundSync`; no hash comparison.

### 1.4 Device-authenticated operations
`requireDevice()` (`supabase/functions/_shared/auth.ts:297-353`) is the only device gate: `x-device-id` + `x-device-secret`, constant-time SHA-256 against `devices.secret_hash`, then status/revocation check.
Call sites:
- `device-telemetry/index.ts:69` heartbeat, `:158` usage, `:240` location, `:358` apps;
- `device-command/handler.ts:291` poll, `:310` ack;
- `remote-session/index.ts:161` session state.

### 1.5 Heartbeat and Parent presence
- `GuardianService.sendHeartbeat()` (`GuardianService.kt:497-521`) posts `heartbeat` via `DeviceHttpClient` (headers set at `DeviceHttpClient.kt:43-49`).
- `device-telemetry` updates `last_seen_at` only after `requireDevice` (`device-telemetry/index.ts:68-83`).
- `Device.syncHealth`/`statusLabel` (`lib/data/models/device.dart:394-458`) derive Online/Stalled/Offline from `last_seen_at` age; no server health column.

### 1.6 Confirmed failure
On reinstall, new installation ID + secret + old active row → `device-register` 409, heartbeat 401, `last_seen_at` frozen, Parent "Offline". Full evidence: Phase 4 report `03_failure_point_source_evidence.md`.

---

## 2. Existing recovery and its effects

- Parent `recoverDevice()` (`device_detail_controller.dart:156-170`) → `family-admin` `recover_device` (`family-admin/index.ts:92-123`) → `request_device_recovery` (`20260101000400_device_recovery.sql`).
- That RPC calls `private.unlink_child` (`20260101000100_functions.sql:325-420`): membership `removed`, **all** child devices revoked, `secret_hash=NULL`, sessions ended, pairing tokens/requests cancelled, audit `member_removed`.
- Result: relationship destroyed; new pairing and new device row required.

`VERIFIED (source)`. This is why Option C is needed.

---

## 3. Approved Option C end-to-end flow

### Stage A — Parent initiates
1. Parent opens `DeviceDetailPage` for a specific device.
2. UI confirms the target (name, platform, last seen) and that it is active.
3. `DeviceDetailController` calls `family-admin` action `request_device_recredential` with `device_id`.
4. Edge verifies JWT, verified email, role `parent`, active parent membership in the **device's** family.
5. RPC locks the device, checks active device and active child membership, supersedes any pending challenge, inserts a 10-minute/5-attempt challenge bound to `(family_id, device_id, child_user_id)`, audits `device_recredential_requested`.
6. Parent receives a short code (optional QR); no secret/hash is involved.

### Stage B — Child authenticates
1. Reinstalled Child signs in to the same Child account.
2. Shell detects `unconfirmed` (active row + device-auth 401 / no success since install); shows a recovery card. **No automatic recovery.**
3. Child enters the code; `ChildShellController` reads native identity and calls `device-register` action `recovery_redeem` with `code`, `installation_id`, `secret_hash`, optional platform/version.
4. Edge verifies JWT, verified email, role `child`, active child membership; validates fields; hashes the code; applies committed attempt accounting (D8); calls the atomic RPC.
5. RPC re-verifies child/family/device/challenge, rotates the credential, ends sessions, consumes the challenge, audits.

### Stage C — Atomic rotation
One transaction (Gate C):
- lock challenge → validate status/expiry/attempts;
- lock device → validate same family/child, active, not revoked, installation uniqueness;
- replace `secret_hash`, `installation_id`, `credential_issued_at`; keep `id`, `family_id`, `child_user_id`, `status`, `policy_version`, permissions, `display_name`, `last_seen_at`;
- end active remote sessions (`ended_reason='device_recredentialed'`, D5);
- mark challenge consumed;
- audit `device_recredentialed`;
- commit or roll back everything.

### Stage D — Completion and presence
1. Child stores the server device id (unchanged) in the session identity.
2. Child rewrites `SyncConfig` with the same device id + existing local secret (`_ensureIdentityAndSync` already does this).
3. `GuardianService` detects the config change (`GuardianService.kt:225-241`) and resets timers.
4. Next heartbeat succeeds; `last_seen_at` advances; Parent sees Online.
5. Heartbeat success is an **oracle**, not a guarantee: FGS/network/battery factors remain runtime risks.

---

## 4. Authorization and validation boundaries

| Boundary | Enforced at |
|---|---|
| Parent identity/role/email | Edge `requireUser`, `requireRole` |
| Parent belongs to the device's family | Edge `assertFamilyParent(device.family_id)` + RPC |
| Child identity/role/email | Edge `requireUser`, `requireRole` |
| Child belongs to the challenge family | Edge `assertChildMembership` + RPC |
| Challenge↔child↔device↔family binding | RPC (authoritative) |
| Device active/not revoked | RPC |
| Attempts/expiry/single-use | RPC + attempt RPC |
| Old credential invalidation | RPC hash replacement + existing `requireDevice` |
| Client cannot choose arbitrary family/child | handler passes only `device_id`/`code`; RPC derives |
| No automatic recovery | no client mutation on install-ID change |

---

## 5. State machine

```
none ──parent request──► pending ──child redeem──► consumed
  ▲                        │
  │                        ├──expire──► expired
  │                        ├──supersede──► superseded
  │                        └──revoke/unlink──► invalid
  └────────new request───────────────────────────┘
```

Only `consumed` means the credential changed. `expired`/`superseded`/`invalid` leave the old credential (or the revoked state) in place.

---

## 6. Preserved vs changed

| Item | Effect |
|---|---|
| `devices.id` | preserved |
| `family_id`, `child_user_id` | preserved |
| `family_members` | untouched |
| `policy_version`, permissions | preserved (D6) |
| `display_name` | preserved (D7) |
| `last_seen_at` | preserved until next heartbeat |
| `secret_hash`, `installation_id`, `credential_issued_at` | replaced |
| Active `remote_sessions` | ended (D5) |
| Audit | new request/completion events |

---

## 7. Unresolved architecture question

**Parent re-validation at redeem:** require the specific parent who created the challenge, or any active parent in the family? D3 says any active parent may approve; the challenge is family-scoped, so **any active parent** is recommended. This must be frozen before Gate C because it changes the RPC's authorization predicate.

---

## 8. Evidence classification

| Claim | Class |
|---|---|
| Current failure chain | VERIFIED (Phase 4 report 03 + source) |
| `recover_device` destroys relationship | VERIFIED (source + SQL test `45_device_recovery.sql`) |
| Option C flow | DESIGN PROPOSAL (Phase 4 reports 04/06/07) |
| Heartbeat recovery timing | UNRESOLVED (runtime) |
| Gate A signed approval | MISSING ARTIFACT (asserted in Phase 5 brief) |
