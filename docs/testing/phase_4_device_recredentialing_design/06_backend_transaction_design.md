# 06 — Backend Transaction Safety and Atomicity Design

**Scope:** Determine whether credential replacement can be atomic in the current architecture, what must change, and what happens under partial failure.  
**Constraint:** This report contains **no SQL, no migration, no RPC body and no backend code**. It specifies required behaviour and contracts only.

---

## 1. Current backend write model (evidence)

`device-register` is an Edge Function using the Supabase service-role client. The rotation-relevant sequence is:

1. read existing row by `(family_id, installation_id)` — `device-register/index.ts:141-150`;
2. read active device for child — `device-register/index.ts:197-203`;
3. update the existing row — `device-register/index.ts:177-185`;
4. insert audit — `device-register/index.ts:187-192`.

Each `db.from(...)` call is a separate HTTP/PostgREST statement. There is no interactive transaction spanning steps 1–4. The same pattern appears in `family-admin` and `pairing` Edge handlers.

**Conclusion:** today, a crash between the device update and the audit insert would leave a rotated credential with **no audit record**, or vice versa. `recordAudit` fails the *request*, but it cannot roll back an already-committed device update. `PASS (source) — current model is not transactional across statements.`

The existing SQL RPCs (`private.revoke_device`, `private.unlink_child`, `private.request_device_recovery`) **are** transactional because they are a single function body. That is the model to follow.

---

## 2. Records that must change for a successful rotation

| Record | Field | Before | After | Must change atomically? |
|---|---|---|---|---|
| `devices` (same `id`) | `secret_hash` | old hash | new hash | **Yes** |
| `devices` | `installation_id` | old install id | new install id | **Yes** |
| `devices` | `credential_issued_at` | old timestamp | `now()` | **Yes** |
| `devices` | `credential_revoked_at` | `NULL` (must be, because active) | stays `NULL` | Yes (guard) |
| `devices` | `status` | `active` | stays `active` | Yes (guard) |
| `devices` | `updated_at` | old | trigger `devices_set_updated_at` | Automatic |
| `device_recovery_challenges` | `consumed_at`, `consumed_by` | `NULL` | `now()`, child user id | **Yes** |
| `audit_logs` | new row `device_recredentialed` | — | one row | **Yes** |
| `devices` | `display_name`, platform, versions | old | optionally updated from the new install | Same transaction if changed |
| `devices` | `last_seen_at` | old | **not set** (heartbeat proves liveness) | No |
| `devices` | `policy_version`, permissions | current | **unchanged** | Must not change |

### Records that must **not** change
- `family_members` (no status change, no `removed_at`).
- `families` (no settings/owner change).
- `devices.family_id`, `devices.child_user_id`, `devices.id`.
- `device_policies`, `usage_daily`, `location_events`, `safety_alerts`, `device_apps` (they reference the same `device_id` and remain valid).
- `pairing_requests` / `device_pairing_tokens` (recovery is not pairing).
- `remote_sessions` — unless the owner decides to end them (see §7).

---

## 3. Why a transaction or carefully designed RPC is required

The operation is a **compare-and-swap across two tables plus an audit append**:

- the challenge must transition `pending → consumed` exactly once;
- the device credential must transition `old → new` exactly once;
- both must be visible together;
- the audit row must exist iff the rotation happened.

If done as separate statements:
- a concurrent second completion could consume the challenge and rotate twice (last writer wins), or consume without rotating;
- a crash could consume the challenge but not rotate → device permanently locked out until a new challenge;
- a crash could rotate but not audit → silent security-relevant event;
- a read between steps could observe the new hash while the challenge is still `pending`, enabling a second rotation.

**A single database function is the only mechanism in this stack that provides the required isolation.** `device-register` cannot do it as written.

---

## 4. Required RPC contract (behavioural, no code)

### 4.1 `request_device_recovery` (parent-side) — new function or new mode
Inputs: `device_id`, actor user id (from JWT).  
Steps:
1. Load the device row with a row lock.
2. Reject if not found (uniform `device_not_found_or_forbidden`).
3. Require actor has **active parent** membership in `device.family_id`.
4. Require `device.status='active'` and `credential_revoked_at IS NULL`.
5. Reject if the child membership is not active.
6. Supersede any existing pending challenge for this device (single pending challenge).
7. Insert a challenge row with a server-generated `code_hash`, `expires_at`, `max_attempts`, `family_id`, `device_id`, `child_user_id`, `created_by`.
8. Audit `device_recovery_requested` (no secret/hash/code).
9. Return only non-secret metadata: challenge id, expiry, and (only to the Parent channel) the one-time code.

### 4.2 `redeem_device_recovery` (child-side completion)
Inputs: `device_id` (or challenge code), child user id (from JWT), new `installation_id`, new `secret_hash`, optional display/platform/version.  
Steps under one transaction:
1. Lock the challenge row by its hash/id (`FOR UPDATE`).
2. Verify not consumed, not expired, attempts below max, status pending.
3. Verify the child JWT owns the challenge's `child_user_id` and has an **active child** membership in the challenge's `family_id`.
4. Load and lock the device row; verify it still matches the challenge's `family_id`, `child_user_id`, `status='active'`, `credential_revoked_at IS NULL`.
5. Verify `installation_id` validity and `secret_hash` shape (64-hex).
6. Update the device in place: `secret_hash`, `installation_id`, `credential_issued_at=now()`, `credential_revoked_at=NULL`, `status='active'`, optional descriptive fields.
7. Set `consumed_at=now()`, `consumed_by=child_user_id` on the challenge.
8. Insert audit `device_recredentialed` with non-secret metadata.
9. Return the public device projection (no `secret_hash`, no `installation_id`).
10. Any failure raises → whole transaction rolls back; challenge remains usable (or attempts increment is rolled back too — see §6 for the chosen policy).

`ENFORCED-BY-DESIGN` once implemented under Gate C.

---

## 5. Concurrency and locking

| Race | Locking rule | Outcome |
|---|---|---|
| Two completions with the same challenge | `SELECT ... FOR UPDATE` on the challenge; second waits, then sees `consumed_at` set | Second returns `409 recovery_already_used` (or idempotent success, §6) |
| Parent issues a new challenge while one is pending | Supersede under the same device row lock | Exactly one pending challenge remains |
| Parent revokes the device mid-recovery | Device row lock in both `revoke_device` and the completion | One wins; the other observes the new state |
| Child is unlinked mid-recovery | Membership is checked inside the transaction; unlink also locks membership | Completion fails if membership is no longer active |
| Two devices race for the same child | The partial unique index `devices_one_active_per_child` plus the device row lock | Only the challenge's device can be updated; no second device is created |

The existing `private.revoke_device` and `private.unlink_child` both use `FOR UPDATE` on their target rows (`20260101000100_functions.sql:432-470`, `325-365`); the recovery RPC must use the same discipline and lock ordering (device → challenge or a documented order) to avoid deadlocks.

---

## 6. Partial-failure behaviour (client disconnect, response loss)

### 6.1 Client disconnects during the request
The server either commits the whole transaction or none of it. If the TCP connection drops after commit, the credential **is** rotated but the Child may not know. The challenge is consumed.

### 6.2 Server succeeds but the Child never receives the response
Two recovery oracles, both already available:

1. **Heartbeat:** the Child's `SyncConfig` already has the new `installation_id`/secret and the **same** `device_id` (it learned it from `fetchMyDevice()`). On the next heartbeat, `requireDevice()` compares the new secret to the now-rotated hash and succeeds → `last_seen_at` advances. No special retry endpoint is needed.
2. **Idempotent completion retry:** if the Child retries the completion with the same `installation_id` and the same secret, the RPC can detect `consumed_at IS NOT NULL` **and** `devices.installation_id = submitted installation_id` **and** `devices.secret_hash = submitted hash` → return success without rotating again. If the hash differs, return `409` (a consumed challenge cannot be used to install a different secret).

This comparison is safe because the Child proves possession of the new secret by submitting its hash. The server never returns the hash.

### 6.3 Server fails before commit
Nothing changed: the challenge is still pending (or its attempt counter may have been incremented only if a separate committed statement did so — the design keeps attempt accounting **inside** the transaction so a rolled-back attempt does not consume the budget; see §6.4). The old credential remains valid. The Child can retry or request a new challenge.

### 6.4 Attempt accounting policy (owner-visible design choice)
- **Option 1 (recommended):** increment `attempts` in a separate, committed statement **before** validation, so brute-force attempts are counted even when the transaction rolls back. Trade-off: a transient DB failure could consume one attempt.
- **Option 2:** increment inside the transaction, so a failed attempt that rolls back is free. Weaker against brute force under repeated induced failures.

Recommendation: Option 1, with a modest `max_attempts` (5) and a short TTL, plus a per-child failed-completion rate limit in the Edge layer. This is recorded as an owner decision.

---

## 7. Open transaction-scope decisions

| Decision | Options | Impact |
|---|---|---|
| End active remote sessions on rotation? | (a) end them like `revoke_device`; (b) leave them bound to the same device id | Security/UX; (b) preserves continuity, (a) is stricter |
| Reset `policy_version` / permissions? | (a) keep; (b) reset to 0/unknown until next heartbeat | (a) preserves state; (b) avoids claiming enforcement from a new install |
| Update descriptive fields? | accept new display name/platform from Child; keep old name | UX; name spoofing is low risk inside the family |
| Clear `last_seen_at`? | no; let the next heartbeat set it | Parent can distinguish "rotated but not yet beating" |
| Delete superseded challenges? | mark `superseded_at`; keep for audit | Auditability |

None of these are required for security; they must be fixed before Gate C so the RPC contract is unambiguous.

---

## 8. Audit consistency

- Audit is written in the **same transaction** as the rotation. If the audit insert fails, the rotation rolls back. This mirrors `recordAudit`'s fail-closed intent (`_shared/audit.ts:17-40`) but is stronger because it is transactional.
- One `device_recovery_requested` event per challenge and one `device_recredentialed` per successful rotation.
- Denied/expired attempts may be recorded in the Edge layer (non-transactional) but must never block the security decision; if the audit write fails there, the request should still be denied.
- Metadata: `family_id`, `device_id`, `child_user_id`, `actor_user_id`, `reason`, `challenge_id`, timestamps. **No** secret, hash, code, JWT.

---

## 9. Missing capability statement

> **The current architecture cannot safely perform a relationship-preserving credential rotation without new database capability.**  
> Edge Functions cannot span multiple PostgREST statements in one transaction, and no existing RPC rotates a device credential without also unlinking the child. A new SECURITY DEFINER RPC (plus a challenge store) is required. This is a **Gate C** dependency, not an implementation detail.

`BLOCKED (by design) until Gate C` — not blocked by missing evidence.

---

## 10. What must not be done

- Do **not** perform the rotation as two Edge-side `update` calls with a compensating delete.
- Do **not** reuse `request_device_recovery` (it calls `unlink_child`).
- Do **not** rotate `secret_hash` without consuming the challenge in the same transaction.
- Do **not** return `secret_hash` or `installation_id` to any client.
- Do **not** add a client-visible RLS policy on the challenge table.
