# 10 — Challenge Expiry, Attempt Accounting, Replay Protection and Idempotency

**Scope:** Lifecycle rules for the challenge and rotation. Planning only. No SQL or code.

---

## 1. Approved numerics

| Parameter | Value | Source |
|---|---|---|
| Challenge TTL | **10 minutes** | D2 (Phase 4 report `12_owner_decision_record.md`; Phase 5 brief) |
| Max attempts per challenge | **5** | D2 |
| Attempt accounting | **commit first** | D8 |
| Idempotent retry | **200 on installation ID + hash match** | D9 |
| Code format | **8 chars, 30-symbol alphabet** | D1 + existing `_shared/validation.ts:9-11` (reuse, proposed) |

Other rate-limit numbers are **proposals**, not approved; see report 11.

---

## 2. Expiry

- `expires_at` is server-computed at challenge creation.
- Every RPC checks `expires_at <= now()` under lock.
- Correctness does **not** depend on a cleanup job.
- Optional sweeper marks stale rows `expired` and audits; it must never rotate or delete a device.
- An expired challenge cannot be revived; the Parent must issue a new one.

---

## 3. Attempt accounting (D8)

Sequence:
1. Edge locates challenge by code hash.
2. Calls `record_device_recredential_attempt` (separate committed call).
3. RPC locks challenge, checks status/expiry, increments `attempts`, commits.
4. If `attempts > max_attempts` → `allowed=false` (Edge maps to 429/410).
5. Only then calls redeem.

Consequences:
- Wrong secret/wrong child consumes an attempt even though redeem rolls back.
- A transient redeem failure still consumes an attempt (accepted trade-off).
- A new challenge resets the count to 0.

**Concurrency:** the increment is atomic (`UPDATE ... SET attempts = attempts + 1 ... RETURNING` semantics); two concurrent attempts cannot both read the same old value.

---

## 4. Replay protection

A challenge is replayable only in the D9 idempotent sense.

| Request | Result |
|---|---|
| Same consumed challenge, same installation id, same hash, active device | 200 idempotent, no rotation |
| Same consumed challenge, different installation id or hash | 409 `recovery_already_used`, no rotation |
| Same challenge before consumption, valid | rotates once |
| Same challenge after expiry | 410, no rotation |
| Same challenge after supersede/cancel | 409/410, no rotation |

The hash comparison uses the submitted 64-hex `secret_hash`; no secret is returned.

---

## 5. Idempotency (D9)

Preconditions for 200 on retry:
- challenge `status='consumed'`;
- `devices.installation_id = submitted installation_id`;
- `devices.secret_hash = submitted secret_hash`;
- `devices.status='active'`, `credential_revoked_at IS NULL`.

Otherwise 409. A consumed challenge can never install a second, different secret.

---

## 6. Response loss

If the server commits but the Child never receives 200:
1. The Child already knows the same `device_id` (from `fetchMyDevice`).
2. The Child already holds the new secret locally.
3. Next heartbeat uses the same headers → `requireDevice` matches the new hash → 200.
4. Parent sees `last_seen_at` advance.
5. Optional retry with the same code returns idempotent 200.

No lockout; no second rotation.

---

## 7. Failure matrix

| Failure | State | Recovery |
|---|---|---|
| Parent request fails before RPC | no challenge | retry |
| Parent request commits, response lost | pending | reissue (supersedes) |
| Attempt increment commits, redeem never runs | attempts+1, pending | retry uses another attempt |
| Redeem raises before update | pending, attempt charged | retry/new challenge |
| Redeem commits, response lost | consumed/rotated | heartbeat or idempotent retry |
| Audit insert fails | rollback | retry |
| Installation conflict | rollback | restart/contact support |
| Device revoked mid-flow | revoked | destructive re-link |

---

## 8. Concurrency

- Two redeem: challenge `FOR UPDATE` → one rotation.
- Two requests: device lock + partial unique pending → one pending.
- Redeem + revoke: device lock → serialized.
- Redeem + unlink: membership/device guards → no active device for removed child.
- Redeem + second register: active-device unique index → no second active row.

---

## 9. Tests

Report 12 covers: expiry, attempt limits, replay, idempotent retry, concurrent redeem/request, response loss, audit rollback.

---

## 10. Unresolved

1. Sweeper cadence/retention (proposal: lazy + optional daily).
2. Whether `attempts > max` or `>= max` is the exact cut-off; implementation must match the error mapping.
3. Whether the status endpoint exposes `attempts_remaining` to the Child (recommended: no; Parent only).
