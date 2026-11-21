# 04 — Flutter Child-Side Implementation Plan

**Scope:** Child authentication, recovery detection, challenge submission and post-rotation resync. Planning only.

---

## 1. Current Child flow (verified)

| File | Symbol / lines | Behaviour |
|---|---|---|
| `lib/features/child/controllers/child_enrollment_controller.dart` | `needsDeviceRegistration` 69 | `linked && !hasDevice` |
| same | `registerDevice()` 264–325 | Returns "already registered" when `device.value != null` (276–279); otherwise registers |
| `lib/features/child/controllers/child_shell_controller.dart` | `_loadMembershipAndDevice()` 208–252 | Active membership → family → `fetchMyDevice()` |
| same | `_ensureIdentityAndSync()` 570–621 | Binds server device id + local secret; no hash check |
| same | `_refreshDeviceRow()` 365–384 | Re-reads active device |
| `lib/data/repositories/supabase_device_repository.dart` | `fetchMyDevice()` 58–70 | Active row for the signed-in child |
| `lib/data/models/device.dart` | `DeviceIdentity` 787–822 | `installationId`, `secret`, `secretHash`, optional `serverDeviceId` |
| `lib/data/services/device_admin_service.dart` | `getIdentity()` 45+, `configureBackgroundSync` 180+ | Native bridge wrappers |

`VERIFIED (source)`.

---

## 2. New Child-visible state

Add a non-secret credential state, derived from native observation:

| State | Detection | UI |
|---|---|---|
| `unknown` | startup | no banner |
| `confirmed` | any successful device-authenticated call | no banner |
| `unconfirmed` | active device row + HTTP 401 from a device-authenticated call | recovery card |
| `approvalRequired` | user opened recovery / attempt returned not-found/expired | code entry |
| `revoked` | `fetchMyDevice()==null` with active membership, or `403 device_revoked` | re-link guidance |

**Critical rule:** `unconfirmed` must never trigger a server mutation. A new installation ID alone is not a recovery trigger.

Source of the state: Kotlin `GuardianService` classifies 401/403 and stores a non-secret flag in `SecureStore`; Flutter reads it through `DeviceAdminService.getCredentialState()` (report 06).

---

## 3. Proposed Child files

### Modify
1. `lib/features/child/controllers/child_shell_controller.dart` — state, `completeCredentialRecovery`, post-success resync.
2. `lib/features/child/tabs/child_home_tab.dart` — recovery card/banner.
3. `lib/features/child/tabs/child_settings_tab.dart` — "Reconnect this phone" entry.
4. `lib/features/child/child_enrollment_page.dart` — offer recovery when `unconfirmed`, never auto-register.
5. `lib/data/repositories/repository_contracts.dart` — add `completeCredentialRecovery(...)`.
6. `lib/data/repositories/supabase_device_repository.dart` — implement the call.
7. `lib/data/services/device_admin_service.dart` — `getCredentialState`, optional `restartBackgroundSync`.
8. `lib/core/errors/app_exception.dart` — new code mapping.

### New (test-only)
- `test/features/child/child_recovery_controller_test.dart`.

Optional dedicated page (not required): `child_recovery_page.dart` + binding + route.

---

## 4. Completion sequence

`ChildShellController.completeCredentialRecovery(String code)`:

1. Require `device.value?.isActive == true` and `family.value != null`.
2. Normalize/trim the code locally (uppercase, strip separators) — server remains authoritative.
3. Guard against double submit.
4. `identity = await _deviceAdmin.getIdentity()`.
5. Call repository:
   ```
   completeCredentialRecovery(
     deviceId: device.id,
     installationId: identity.installationId,
     secretHash: identity.secretHash,
     platform/androidVersion/appVersion (optional),
   )
   ```
   **Never send `identity.secret`.**
6. On success:
   - update `device.value` from the response (same id);
   - `session.setActiveDevice(device)`;
   - `session.setDeviceIdentity(identity.copyWith(serverDeviceId: device.id))`;
   - re-run `_ensureIdentityAndSync(device, family)`;
   - optionally `_deviceAdmin.restartBackgroundSync()`;
   - clear `credential_unconfirmed`;
   - `await load()`.
7. On failure: map and keep state; do not clear the flag.

### Error mapping
| Backend | UI |
|---|---|
| `404 recovery_not_found` | "That code was not found. Check it with your guardian." |
| `410 challenge_expired` | "The approval expired. Ask your guardian for a new code." |
| `409 recovery_already_used` | "This phone is already reconnected. Refreshing…" then retry status |
| `403 forbidden` | "Sign in with the child account linked to this family." |
| `403 device_revoked` | "This device was revoked. Ask your guardian to re-link it." |
| `429` | "Too many attempts. Wait N minutes." |
| `409 installation_conflict` | "This installation is already registered. Restart the app." |
| 5xx | "The server could not complete reconnection. Try again." |

---

## 5. UI design

### Recovery card (Home, top)
- Title: "This phone needs guardian approval".
- Body: family link and history are kept; a guardian must approve.
- Code field + **Reconnect** button.
- Help text: "Ask your guardian to open this phone in their app and approve the new credential."
- "Use a different account" link if the wrong child is signed in.
- While submitting: progress; disable button.
- Success: "Reconnected. Waiting for the first heartbeat…" until `last_seen_at` updates.

### Settings tab
- "Reconnect this phone" row opens the same card/flow.
- Show current state label (`Confirmed`, `Needs approval`, `Revoked`).

### Enrollment page
- If `device.value != null` and state `unconfirmed`, replace the generic "already registered" message with a link to recovery. Do **not** call `registerDevice`.

---

## 6. Post-rotation identity and config

The local secret does **not** change during recovery. The flow only makes the server accept the existing secret.
- `_ensureIdentityAndSync` writes `SyncConfig` with the same `deviceId` and current secret.
- If the process dies before this, the next launch repeats it.
- `GuardianService` already resets timers when the config changes (`GuardianService.kt:225-241`).

No client-side credential generation or rotation.

---

## 7. Dependencies

| Dependency | Gate |
|---|---|
| Gate C redeem RPC | C |
| Edge `device-register` action | B |
| Kotlin credential-state flag | B |
| `DeviceIdentity` model (exists) | — |
| Optional restart method | B |

---

## 8. Test coverage (design)

- no auto-recovery on load with `unconfirmed`;
- completion payload contains `installationId` + `secretHash`, not `secret`;
- success re-runs `_ensureIdentityAndSync` with the same device id;
- 404/410/409/403/429 mappings;
- double-submit guard;
- process-restart state persistence (Kotlin);
- no secret in logs/widgets.

Files: report 12 §3.

---

## 9. Unresolved Child-side questions

1. **I3:** is there a status endpoint to poll, or is heartbeat the only completion signal?
2. **D4:** Child-initiated request is out of MVP; the card explains "ask a guardian".
3. **D12:** in-app notification only; no push.
4. How long to keep showing "waiting for first heartbeat" before offering retry.
