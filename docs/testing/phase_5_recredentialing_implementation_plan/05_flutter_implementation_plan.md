# 05 — Flutter/Native Integration, Credential Persistence and Heartbeat Restart

**Scope:** How the Child app persists state, refreshes identity, restarts sync and survives process death after rotation. Planning only.

---

## 1. Existing integration points (verified)

| Component | File / symbol | Role |
|---|---|---|
| Method channel | `lib/data/services/device_admin_service.dart:17-19` | Flutter↔native bridge |
| Identity | `NativeBridge.getDeviceIdentity()` `NativeBridge.kt:206-219` | Returns installation id, secret, hash |
| Sync config | `NativeBridge.configureBackgroundSync()` `NativeBridge.kt:357-379` | Persists device id + secret + family |
| Clear config | `NativeBridge.clearBackgroundSync()` `NativeBridge.kt:381+` | Stops services and clears config |
| Service | `GuardianService.kt` | Heartbeat/poll/uploads |
| Config-change detection | `GuardianService.kt:225-241` | Resets timers when device id/secret changes |
| HTTP | `DeviceHttpClient.kt:43-49` | Sends device headers |
| Session display state | `lib/data/services/session_service.dart` | Holds device/identity for UI only |

`VERIFIED (source)`.

---

## 2. Persistence model

### What recovery changes locally
**Nothing in the credential itself.** The Server replaces `secret_hash`/`installation_id`; the Child keeps:
- the same local `device_secret` created on first launch;
- the same server `devices.id`;
- the same `family_id`.

The only local writes after success are:
1. `SyncConfig` (same device id, same secret, same family);
2. credential-state flag `confirmed`;
3. UI/session state.

### Why this is safe
- `saveConfig` writes five keys in one `SharedPreferences.Editor` (`SecureStore.kt:107-115`), so a config is either complete or `config()` returns null.
- `config()` returns null on any missing field (`SecureStore.kt:117-131`), so the shell reconfigures.
- No new secret is generated; no multi-key credential swap is needed.

### Required Flutter/native sequence
1. On success, update `SessionService.activeDevice` and `deviceIdentity`.
2. Re-run `ChildShellController._ensureIdentityAndSync(device, family)`.
3. Optionally call `restartBackgroundSync()` (new native method) to force an immediate tick.
4. Clear the native `credential_unconfirmed` flag only after the config write.

---

## 3. Heartbeat restart

Current behaviour already helps:
- `GuardianService` computes a `configFingerprint` and resets `nextPollAllowedAt`, `pollBackoffMs`, `lastHeartbeatAt` when it changes (`GuardianService.kt:225-241`).
- Therefore rewriting `SyncConfig` is sufficient for the next tick to use the new credential.
- The tick is every 10 s (`GuardianService.kt:38`), poll every 20 s (`:39`), heartbeat every 5 min (`:41`).

Proposed optional addition:
- `NativeBridge.restartBackgroundSync()` → read `config()`, ensure `shouldRunGuardian`, call `GuardianService.start(context)`, return `isRunning`.
- Must return false (not regenerate) when `config()` is null.
- Must not call `installationId()`/`deviceSecret()` in a creating path.

---

## 4. Process death and restart

| Kill point | Local state | Next launch |
|---|---|---|
| Before completion submission | unchanged, `unconfirmed` | recovery card; code still valid until TTL |
| During HTTP | server may or may not commit | if committed, heartbeat succeeds; else code still pending |
| After server commit, before config write | config already contains same secret/device id | `_ensureIdentityAndSync` rewrites; heartbeat succeeds |
| During `saveConfig` | partial config → `config()==null` | shell rewrites; no identity regeneration |
| After config write, before state flag | config correct, flag stale | first success sets `confirmed` |

No crash journal required.

---

## 5. Reboot

- `BootReceiver` starts `GuardianService` if `shouldRunGuardian` (`SecureStore.shouldRunGuardian`).
- It uses the persisted `SyncConfig`.
- After rotation, that config is the new credential; heartbeat succeeds.
- If the boot start is blocked by Android 15 FGS rules, the existing error is surfaced; this is a runtime risk, not a credential risk.

---

## 6. Preventing accidental regeneration loops

1. Recovery never calls `clearConfig`, `clearPolicyState`, or deletes the encrypted store.
2. `getIdentity()` is called before completion; the secret already exists.
3. `restartBackgroundSync` fails closed when config is missing.
4. The `unconfirmed` state is advisory; it never mutates.
5. A `installation_conflict` response does **not** auto-regenerate the installation ID; it asks the user to restart/contact support. Any regeneration would be an explicit, separate action.

---

## 7. Local observability

- `GuardianService.recordError()` (`GuardianService.kt:682-690`) writes `guardian_lastError`, truncated to 300/500 chars.
- Add a non-secret `credential_state` field; do not add the secret/hash.
- Flutter reads state through the channel for the recovery card.
- No credential in crash reports, analytics or logs.

---

## 8. Integration tests (design)

- `SecureStore` secret stability across calls and after `saveConfig`.
- `config()` null on partial fields.
- `restartBackgroundSync` with no config returns false.
- `credential_unconfirmed` set on 401, cleared on success.
- App restart after simulated rotation keeps config and succeeds.
- Reboot path uses the same config.

Files: report 12 §4/§5.

---

## 9. Residual integration risks

| Risk | Status |
|---|---|
| Android 12/15 FGS start restrictions after reboot | existing platform risk; surfaced not hidden |
| Battery optimization delaying heartbeat | existing; Parent window is 12 min (`device.dart:394`) |
| Config write race with service tick | low; `configFingerprint` handles change |
| User force-stops the app | expected; next launch recovers |
