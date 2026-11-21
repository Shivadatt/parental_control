# 03 — Flutter Parent-Side Implementation Plan

**Scope:** Parent approval and device management changes required by Option C. Planning only; no file modified.  
**Evidence baseline:** Phase 4 report `07_flutter_kotlin_implementation_design.md`; source at HEAD `bbd3c21`.

---

## 1. Current Parent device surfaces (verified)

| File | Symbol / lines | Behaviour |
|---|---|---|
| `lib/features/devices/device_detail_page.dart` | `_buildBody` 34–191 | Loads device, banners, identity/policy/permissions/commands/links, revoke and destructive recovery |
| same | "Lost or reinstalled phone" section 159–184 | Only destructive `Start device recovery` today |
| same | `_confirmRecovery` 469–483 | Confirmation dialog for unlink/re-pair |
| `lib/features/devices/device_detail_controller.dart` | `recoverDevice()` 156–170 | Calls repository, sets `recoveryStarted` after server 200 |
| `lib/features/devices/devices_controller.dart` | `_fetch()` | Lists all family devices (no active filter) |
| `lib/data/repositories/supabase_device_repository.dart` | `recoverDevice` 114–120 | `family-admin` action `recover_device` |
| same | `fetchDevices` 37–48 | No status filter (E2E-002, out of scope) |

`VERIFIED (source)`.

---

## 2. Proposed Parent files

### Modify
1. `lib/data/repositories/repository_contracts.dart` — add `requestCredentialRecovery(String deviceId)` → `RecoveryChallenge?`; optional `fetchCredentialRecoveryStatus(deviceId)`; optional `cancelCredentialRecovery(challengeId)`.
2. `lib/data/repositories/supabase_device_repository.dart` — implement via `EdgeApi.invokeMap` on `family-admin`.
3. `lib/features/devices/device_detail_controller.dart` — request/status/cancel state and methods.
4. `lib/features/devices/device_detail_page.dart` — new action, confirmation, code/QR display, waiting state.
5. `lib/data/models/device.dart` — optional `RecoveryChallenge` and `CredentialRecoveryState` model.
6. `lib/data/models/models.dart` — export.
7. `lib/core/errors/app_exception.dart` — new code mappings if needed.

### New (test-only)
- `test/features/devices/device_recovery_controller_test.dart`
- `test/data/recovery_models_test.dart`

No new production screen is required; the existing detail page is the correct entry point.

---

## 3. Controller design

### New state
```
isRequestingCredentialRecovery : RxBool
credentialChallenge            : Rxn<RecoveryChallenge>
credentialRecoveryError        : Rxn<AppException>
credentialRecoveryRequested    : RxBool
isCancellingCredentialRecovery : RxBool
```

### `requestCredentialRecovery()`
1. Guard `device.value?.isActive == true`; refuse if revoked.
2. Clear error; set loading.
3. Call repository with `deviceId` only (never a client-supplied family).
4. On success: store challenge, show code/expiry, return true.
5. On error: map `403/404/409/429/503`; return false.
6. Never set `recoveryStarted` — that flag belongs to the destructive flow.

### `refreshCredentialRecoveryStatus()` (optional, if I3 status action approved)
- Poll only while the Parent is on the detail page; show `pending/completed/expired`.
- Do not poll on the dashboard/list.

### `cancelCredentialRecovery()` (optional)
- Visible only for a pending challenge; confirm dialog; on success clear state.

### Error mapping
| Backend | UI message |
|---|---|
| 403 | "You do not have permission for this device." |
| 404 | "This device is no longer part of your family." |
| 409 `device_not_active` | "This device is not active. Use re-link recovery." |
| 409 `child_not_active` | "The child account is not active in this family." |
| 429 | "Too many approval requests. Try again in N minutes." |
| 503 | "Recovery is temporarily unavailable." |

`EdgeApi` already maps HTTP statuses (`lib/data/services/edge_api.dart:100-146`).

---

## 4. Page/UX design

### Entry point
In `_buildLinksCard` / the existing "Lost or reinstalled phone" section:

- **New primary outlined action:** "Approve this phone's new credential".
- **Existing destructive action:** "Start device recovery (unlink & re-pair)" stays, relabelled only for clarity (D13).
- Revoked or non-active device: new action disabled/hidden.

### Confirmation dialog
Show:
- display name, platform, `last_seen` age, status;
- "The old install will stop reporting. The family link, device identity and history are kept."
- explicit confirm label "Approve credential replacement".

Use the existing `_confirmRecovery` dialog pattern (`device_detail_page.dart:469-483`).

### Challenge display
- Selectable short code, expiry timestamp/countdown, "Enter this on the child phone".
- Optional QR (D1). Use an existing QR dependency if already present; do not add a new dependency without owner approval.
- "Reissue code" action (supersedes the old one).
- "Waiting for the phone to reconnect…" until `last_seen_at` advances.
- If status action exists: show `pending/consumed/expired`.

### Safety rules
- Do not show the code after a status refresh; only the creation response carries it.
- Do not offer the action for a revoked row.
- Do not silently fall back to destructive recovery.
- Do not claim success until a heartbeat updates the device row.

---

## 5. Repository contract

```text
Future<RecoveryChallenge> requestCredentialRecovery(String deviceId)
Future<RecoveryChallenge?> fetchCredentialRecoveryStatus(String deviceId)
Future<void> cancelCredentialRecovery(String challengeId)
```

Proposed response model:
```
RecoveryChallenge {
  challengeId, code?, expiresAt, attemptsRemaining, device
}
```
No secret/hash fields.

Implementation calls:
- `family-admin` action `request_device_recredential` (body `device_id`);
- optional `credential_recovery_status` / `cancel_device_recredential`.

---

## 6. Dependencies

| Dependency | Owner |
|---|---|
| Gate C `request_device_recredential` RPC | Gate C |
| Edge `family-admin` action | Gate B |
| `EdgeApi` error mapping | existing |
| QR renderer | existing dependency or deferred |
| Status/cancel actions | I3 decision |

---

## 7. Test coverage (design)

- request success shows code and expiry;
- 403/404/409/429/503 mappings;
- revoked device cannot request;
- loading state does not double-submit;
- cancel clears state (if I3);
- status transitions pending→consumed/expired;
- no secret/hash in any widget or log.

Files: report 12 §3.

---

## 8. Unresolved Parent-side questions

1. **I3:** include status/cancel in MVP?
2. **D1:** QR supported in this build or code-only first?
3. **Multi-parent:** should all parents see the pending challenge (D12 in-app audit only)?
4. **E2E-002:** the list still shows revoked rows; the detail page must guard actions even if the list does not. Fixing the list remains separate (D14).

---

## 9. Out of scope

- E2E-002 list filtering.
- E2E-003 policy labels.
- Any change to `recover_device`/`revoke_device`.
- Push/FCM notifications.
