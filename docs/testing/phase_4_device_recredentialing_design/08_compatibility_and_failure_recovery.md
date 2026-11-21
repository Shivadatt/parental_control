# 08 — Compatibility and Failure Recovery

**Scope:** Exhaustive behaviour of the proposed flow under partial failure, restart, concurrency and version skew. Design only.

---

## 1. State model

Credential recovery has three durable states on the server:

| State | `device_recovery_challenges` | `devices.secret_hash` | Meaning |
|---|---|---|---|
| `none` | no pending row | old | No recovery in progress |
| `pending` | row with `consumed_at IS NULL`, not expired | old | Parent approved; waiting for Child |
| `completed` | row consumed | new | New credential active |
| `expired/superseded` | row closed, not consumed | old | Must issue a new challenge |

The device row is **never** in a "revoked" state during this flow. That is the core relationship-preserving property.

---

## 2. Failure matrix

| # | Failure | State after failure | User-visible result | Recovery action | Data loss |
|---|---|---|---|---|---|
| FR1 | Parent request times out before server commit | `none` | "Could not create approval" | Retry request | None |
| FR2 | Parent request committed, response lost | `pending` | Parent may not see code | Parent re-requests; server supersedes the old pending challenge and shows a new code | None |
| FR3 | Parent enters wrong device | `pending` for wrong active device | Child cannot complete (challenge bound to wrong `device_id`); expires | New challenge for the correct device | None |
| FR4 | Child enters wrong code | `pending`; attempt count +1 | "Invalid or expired approval code" | Retry, up to max attempts | None |
| FR5 | Child code expired | `expired` | "Approval expired; ask your guardian again" | New challenge | None |
| FR6 | Child completes but network drops before response | `completed` (commit happened) | Child may show error | Next heartbeat succeeds; or idempotent completion retry returns success | None |
| FR7 | Server fails mid-transaction | `pending` (rollback) | Error | Retry completion with same challenge | None; old credential still valid |
| FR8 | Two Child devices submit concurrently | one commits, second gets `409`/idempotent | One device reconnects | The loser asks for a new challenge | None |
| FR9 | Two Parents issue challenges concurrently | one pending after supersede | One code valid | Use latest code | None |
| FR10 | Parent revokes device while challenge pending | device `revoked`, challenge should be invalidated | Child completion `403` | Re-link flow | Expected |
| FR11 | Child is unlinked while challenge pending | membership `removed`, devices revoked | `403` | Re-link flow | Expected |
| FR12 | App process killed after completion | `completed`; local secret/config already persisted | On relaunch, shell loads active device + same secret | Heartbeat succeeds | None |
| FR13 | Device rebooted after completion | `completed` | `BootReceiver` restarts guardian if `shouldRunGuardian` | Heartbeat succeeds | None |
| FR14 | Child clears data **after** completion | new secret again, `unconfirmed` | Needs a **new** Parent approval | New challenge | None |
| FR15 | Parent uninstalls / loses device mid-flow | `pending` | Child cannot proceed | Another active parent (or future owner decision on scope) issues a challenge; otherwise destructive fallback | None |
| FR16 | Server deploys rollback after rotation | Old code reads new hash — `requireDevice` unchanged | No effect; hash comparison is version-independent | — | None |
| FR17 | Challenge table migration rolled back | RPC unavailable; old 409 remains | Recovery unavailable | Destructive fallback | None new |

`ENFORCED-BY-DESIGN` for the transaction outcomes; `REQUIRES-NEW-CODE` for the endpoints/UI.

---

## 3. Server success + client response loss (deep dive)

The dangerous case is FR6: the server committed the rotation, but the Child never saw the 200.

**Why it is safe:**
1. The Child already knows the server `device_id` from `fetchMyDevice()` — it does not depend on the completion response.
2. The Child already holds the new secret in `SecureStore`; the completion call transmitted only its hash.
3. On the next `GuardianService` tick, `DeviceHttpClient` sends the same `device_id` + new secret. `requireDevice()` compares against the **new** `secret_hash` and succeeds, updating `last_seen_at`.
4. Therefore the Parent sees Online even if the Child's UI showed an error.

**Optional idempotent retry:**
- Retry with the same challenge id/code + same `installation_id` + same secret:
  - if challenge consumed **and** `devices.installation_id` equals the submitted value **and** `sha256(secret)` equals the current `secret_hash` → return `200` with the public device (idempotent success);
  - if consumed and anything differs → `409 recovery_already_used`.
- This lets the Child clear its error state deterministically without a second rotation.

**What must never happen:** a retry with the same consumed challenge but a **different** secret must not rotate. That would be a replay-driven takeover.

---

## 4. Old credential after rotation

- `requireDevice()` has one comparison against `devices.secret_hash` (`_shared/auth.ts:328-343`).
- Rotation writes the new hash in the same transaction as challenge consumption.
- Therefore the old secret returns `401 invalid_device_credentials` **immediately after commit** on all seven device endpoints (report 03 §3).
- There is no grace period and no second credential column. A grace period would be an owner decision and is **not** proposed.

---

## 5. New credential after rotation

- The new secret is the one generated by the current install; it is already persisted.
- Heartbeat, usage, location, apps, command poll/ack and remote-session state all use the same `SyncConfig`, so all recover at once.
- If the Child had previously failed to `configureBackgroundSync` (e.g. background sync disabled), the recovery completion must still rewrite the config or instruct the user; otherwise the server is correct but the device does not beat. The implementation design (report 07 §4.2) re-runs `_ensureIdentityAndSync` after success.

---

## 6. Process restart and reboot

| Event | Behaviour |
|---|---|
| App process killed (recovery not started) | No state change; Child still `unconfirmed`; no automatic recovery |
| App process killed (challenge pending) | Challenge remains server-side until expiry; Child can still complete with the code |
| App process killed (rotation committed) | New secret/config are already in `EncryptedSharedPreferences`; next start works |
| Device reboot after rotation | `BootReceiver`/`GuardianService` start path uses the persisted `SyncConfig` with the new secret; heartbeat succeeds |
| Reboot before completion | Nothing changed; old credential still invalid, but no further damage |

`DEVICE BOOT` path is `BootReceiver.kt` + `SecureStore.shouldRunGuardian()`; it does not regenerate identity. `VERIFIED (source)`.

---

## 7. Compatibility matrix (detailed)

| Server | Child | Parent | Result |
|---|---|---|---|
| New | New | New | Full flow |
| New | Old | New | Parent can issue challenge; Old Child can't consume; expires; Parent instructed to update Child |
| New | New | Old | Old Parent lacks the action; destructive recovery remains |
| Old | New | New | New action → `unknown_action`/404; clear error; no partial state |
| Old | Old | Old | Current behaviour (409 + 401) |
| New | New (credential already valid) | New | Parent should not be offered the action for a confirmably healthy device; if offered, rotation still works but is unnecessary. UI should prefer "device is online" and require an extra confirm. |

**Compatibility rule:** server changes are additive; no existing request/response shape changes. Existing `device-register` `register` behavior (including `409 device_already_registered`) is preserved for all old clients.

---

## 8. Interaction with `assertReenrollmentAllowed`

`device-register` blocks a **revoked** row unless a later approved pairing exists (`device-register/index.ts:51-88`; `enrollment.ts`). The recovery flow:
- never operates on a revoked row (`status='active'` required), so it cannot be used to bypass the re-link gate;
- never creates a pairing request, so it cannot satisfy `requiresRelink`;
- if a Parent revokes the device during a pending challenge, completion must fail closed and the Child must use the destructive re-link path.

`VERIFIED (source)` for the gate; `REQUIRES-NEW-CODE` for the recovery guard.

---

## 9. Rollback and kill-switch design

- **Feature flag (server-side):** if the new Edge action is disabled, it returns `503 recovery_disabled`; no schema is dropped. Old behaviour remains.
- **Schema rollback:** the challenge table and RPCs are additive. Dropping them reverts to the current 409/401 behaviour; it does **not** invalidate credentials already rotated (the `devices` row remains valid).
- **Client rollback:** an older APK simply lacks the UI; the server state is harmless.
- **No data migration** of existing devices is required.

---

## 10. Failure-recovery acceptance criteria

1. No failure mode leaves the device **permanently** unusable when the old credential was valid before the attempt.
2. A committed rotation is discoverable by the Child without the original response (heartbeat).
3. A consumed challenge can never install a second, different secret.
4. Expiry/supersede never deletes the device row or membership.
5. A revoked device cannot use recovery to reactivate.
6. Restart/reboot after success requires no manual step.

These are testable; see report 09.
