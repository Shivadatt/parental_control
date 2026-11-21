# 06 — Kotlin and Secure Credential-Storage Implementation Plan

**Scope:** Native changes required for recovery. Planning only; no Kotlin file modified.

---

## 1. Existing SecureStore behaviour (verified)

`android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt`:

| Function | Lines | Behaviour |
|---|---|---|
| `installationId()` | 86–92 | stored or new random UUID |
| `deviceSecret()` | 94–105 | stored or new 32-byte base64url secret |
| `saveConfig(SyncConfig)` | 107–115 | five keys in one editor |
| `config()` | 117–131 | null unless all fields present |
| `clearConfig()` | 133–140 | removes sync config + run flag |
| `shouldRunGuardian()` | 142–145 | service intent flag |
| `setLastError()` | 152–158 | truncated human text |
| `clearPolicyState()` | 210+ | policy JSON/version/suspensions/quota |

Storage: `EncryptedSharedPreferences` file `parent_control_secure`, AES256-GCM master key (`SecureStore.kt:66-84`).

`NativeBridge.getDeviceIdentity()` (`NativeBridge.kt:206-219`) returns `installationId`, `secret`, `secretHash`.
`GuardianService.configFingerprint` (`GuardianService.kt:225-241`) already detects a changed device id/secret.
`GuardianService.recordError()` (`:682-695`) writes `lastError` and emits service status.

`VERIFIED (source)`.

---

## 2. Proposed SecureStore additions

### Keys (non-secret)
```
credential_state            : "unknown" | "confirmed" | "unconfirmed" | "revoked"
credential_checked_at       : epoch millis
```

### Methods
```
fun credentialState(): String
fun credentialCheckedAt(): Long
fun setCredentialState(state: String, checkedAtMillis: Long)
fun markCredentialConfirmed()
fun markCredentialUnconfirmed()
fun markCredentialRevoked()
```

Rules:
- No secret/hash/token in these keys.
- `clearConfig()` also clears credential state.
- State is advisory; it never blocks or enables a server mutation by itself.

---

## 3. GuardianService classification

Where device-authenticated calls catch `DeviceHttpException`:

| Status | Action | Notes |
|---|---|---|
| 401 | `markCredentialUnconfirmed()` | keep existing human error text |
| 403 with `device_revoked` | `markCredentialRevoked()` | do not mark every 403 revoked |
| 2xx | `markCredentialConfirmed()` | clear stale error |
| 429 | no state change | backoff already exists |
| network | no state change | transient |

Call sites:
- `sendHeartbeat` `GuardianService.kt:497-521`;
- `pollCommands` and its catch `:262-274`;
- `uploadApps`, `uploadUsage`, location upload.

No scheduling/backoff changes.

---

## 4. Proposed NativeBridge methods

Additive MethodChannel methods:
- `getCredentialState` → `{state, checkedAt}`;
- `restartBackgroundSync` → re-reads `config()`, starts/stops the service, returns `isRunning`.

`restartBackgroundSync` must:
- return false if `config()` is null;
- never call `installationId()`/`deviceSecret()` in a creating path;
- never clear config.

Optional, **not recommended** for recovery: `regenerateInstallationId()`. If ever added, it must be an explicit user action after `installation_conflict`, never automatic.

---

## 5. Missing/corrupt credential handling

| Condition | Current | Proposed |
|---|---|---|
| Encrypted store cannot open | `secure_storage_unavailable`; service error | blocking error; **no auto-clear**; explicit "reset local identity" path |
| `installation_id` missing | lazy new UUID | fine; recovery replaces server value after approval |
| `device_secret` missing | lazy new secret | fine; recovery registers it |
| Partial `SyncConfig` | `config()==null`; service stops | shell re-runs `_ensureIdentityAndSync` |
| Wrong secret | 401 → `unconfirmed` | recovery card |
| Store cleared after success | new secret → `unconfirmed` | requires **new** parent approval |

**Rule:** never delete encrypted storage silently to "fix" recovery; that creates a new secret and repeats the original failure.

---

## 6. Atomic local replacement

Because the local secret does not change during recovery, no multi-key credential transaction is needed.

Writes after success:
1. `SyncConfig` — one editor (`saveConfig`);
2. `credential_state` — one key;
3. service run flag — unchanged.

If the process dies:
- before `saveConfig`: next launch rewrites;
- during: `config()==null` → rewrite;
- after: heartbeat sets `confirmed`.

If a future design rotates the **local** secret, it must write secret + config in one editor and keep the old value until commit. That is not this design.

---

## 7. Installation-ID collision

`devices` unique `(family_id, installation_id)` (`core.sql:111`).
- A random new UUID colliding is practically impossible.
- The realistic conflict is the same installation re-registering after a revoked row; that is governed by `assertReenrollmentAllowed` (`device-register/index.ts:51-88`), not recovery.
- The RPC must detect a **different** row owning the new `(family_id, installation_id)` and return `409 installation_conflict`; transaction rolls back.
- Client shows a restart/contact message; no automatic regeneration.

---

## 8. Process restart and reboot

- `GuardianService.onStartCommand` returns `START_STICKY` and stops if config missing (`GuardianService.kt:165-171`).
- `onCreate` requires `hasConfig()` and notification permission (`:123-163`).
- `BootReceiver` uses `shouldRunGuardian`.
- After rotation the persisted config is correct; no native journal required.

---

## 9. Native tests (design)

New file: `android/app/src/test/kotlin/com/parentcontrol/parent_control/CredentialStateTest.kt`.

1. `deviceSecret()` stable across calls.
2. `saveConfig`/`config` round-trip.
3. `markCredentialUnconfirmed` does not alter identity keys.
4. `clearConfig` clears state.
5. `restartBackgroundSync` without config returns false and creates nothing.
6. 401 classification sets `unconfirmed`; success clears it.
7. 403 `device_revoked` sets `revoked`; other 403 does not.

No test file created in this phase.

---

## 10. Evidence classification

| Claim | Class |
|---|---|
| Current SecureStore behaviour | VERIFIED (source) |
| Config-change detection | VERIFIED (source) |
| Proposed state keys/methods | DESIGN PROPOSAL |
| Local atomicity argument | VERIFIED from `saveConfig` single editor + `config()` null-on-partial |
| Collision handling | DESIGN PROPOSAL (Gate C) |
