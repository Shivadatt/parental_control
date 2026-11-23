# 02 — Resolution of Finding REV-001: PL/pgSQL Attempt Counter Transaction Correction

**Document ID:** HAVEN-COR-002  
**Target Finding:** REV-001 (CRITICAL)  
**Target Defect:** HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Phase:** Phase 1.2 — Remediation Plan Correction & Closure (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** RESOLVED BY DESIGN CORRECTION  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Verified Technical Issue & Failure Mechanism

In the Phase 1 proposal (`03_credential_lifecycle_remediation_design.md:120-127`), the `rotate_device_secret` RPC handled an invalid token as follows:
```text
if challenge_hash <> token_hash then
    update device_recovery_challenges set attempts = attempts + 1 where id = challenge_id;
    raise exception 'Invalid re-credentialing challenge token.';
end if;
```

### The Transaction Rollback Flaw
In PostgreSQL, `RAISE EXCEPTION` aborts the current transaction block. Any uncommitted writes executed prior to that exception—including the `UPDATE ... attempts = attempts + 1` statement—are rolled back. As a result:
1. `attempts` is never persisted as incremented.
2. The check `if attempts >= max_attempts` never fires.
3. An attacker can execute unlimited brute-force attempts within the 10-minute challenge window without triggering lockout.
4. The approved Phase 4 Gate A security guarantee (maximum 5 attempts) is defeated.

---

## 2. Evaluation of Architectural Alternatives

| Approach | Architecture | Transaction Isolation | Attempt Persistence | Concurrency Safety | Recommendation |
|---|---|---|---|---|---|
| **Approach A: Structured Return Value** | RPC handles expected verification failure without `RAISE EXCEPTION`, commits `attempts = attempts + 1`, and returns `ok: false`. | `READ COMMITTED` with `FOR UPDATE` | **Guaranteed**: Update is committed inside the transaction. | **High**: Row lock serializes concurrent attempts. | **RECOMMENDED** |
| **Approach B: Autonomous Transaction** | Use `dblink` or background worker to increment counter in separate transaction. | Out-of-band transaction | High | High, but introduces external extension dependency (`dblink`), forbidden in Supabase. | **REJECTED** |
| **Approach C: Pre-verification in Edge Function** | Edge Function increments counter in DB, then checks token in Edge code. | Two round-trips | Medium | Race conditions possible between check and increment; violates single-transaction atomicity. | **REJECTED** |
| **Approach D: Independent Rate-Limit Store** | Redis or separate attempt table. | Out-of-band store | High | Adds infrastructure complexity beyond PostgreSQL; lacks foreign key cascades. | **REJECTED** |

### Selected Architecture: Approach A (Structured Return Value with Explicit Row Locking)
In PostgreSQL, expected authentication failures (e.g. incorrect token, expired challenge) are domain outcomes, not system exceptions. By returning a structured `JSONB` response indicating failure, PostgreSQL successfully **COMMITS** the transaction, persisting the incremented `attempts` count and marking the challenge exhausted if the threshold is met. True infrastructure errors (e.g. database disk failure, constraint violation) still raise exceptions.

---

## 3. Corrected RPC Transaction & Concurrency Design

### 3.1 Concurrency & Row Locking Strategy
To prevent two simultaneous requests from both reading `attempts = 4` and bypassing the `max_attempts = 5` limit, the transaction executes an immediate exclusive row lock:
1. `SELECT * FROM public.device_recovery_challenges WHERE id = ... FOR UPDATE;`
2. This serializes all concurrent redemption attempts for that challenge. The second request blocks until the first request completes and commits.
3. When the second request unblocks, it reads the incremented `attempts` count (now 5), observes `attempts >= max_attempts`, and immediately returns lockout.

### 3.2 State-Transition Table for Challenge Row

| Initial Challenge State | Inbound Action | Resulting Action on Challenge Row | Resulting Action on Device Row | Return Payload |
|---|---|---|---|---|
| `active` (attempts < 4) | Invalid Token | `attempts = attempts + 1` | None | `ok: false, error: "invalid_token", attempts_remaining: X` |
| `active` (attempts = 4) | Invalid Token | `attempts = 5, status = 'exhausted', consumed_at = now()` | None | `ok: false, error: "max_attempts_exceeded", attempts_remaining: 0` |
| `exhausted` | Any Token | No update | None | `ok: false, error: "challenge_exhausted", attempts_remaining: 0` |
| `expired` (now > expires_at) | Any Token | `status = 'expired', consumed_at = now()` | None | `ok: false, error: "challenge_expired"` |
| `active` (attempts < 5) | Valid Token | `status = 'redeemed', consumed_at = now()` | `secret_hash = new_hash, installation_id = new_id, credential_issued_at = now()` | `ok: true, device_id: uuid, recredentialed_at: now()` |

---

## 4. Error/Result Contract & Information Leakage Prevention

To prevent timing attacks and enumeration:
- Both invalid token format and incorrect token hash return an identical error code: `"invalid_token"`.
- If the challenge row does not exist, the RPC returns `"challenge_not_found"`. The Edge Function maps this to HTTP 404.
- If the calling Child user does not match `devices.child_user_id`, the RPC returns `"unauthorized_device_owner"`. The Edge Function maps this to HTTP 403.
- The RPC execution requires `service_role` privileges, meaning clients cannot directly invoke this function over PostgREST.

---

## 5. Maximum-Attempt Enforcement Logic Specification

The PL/pgSQL logic adheres to the following specification:

1. **Lock Active Challenge**:
   - Query `device_recovery_challenges` for `device_id` where `status = 'active'` using `FOR UPDATE`.
   - If not found, return `{"ok": false, "error": "challenge_not_found"}`.
2. **Check Expiration**:
   - If `expires_at < now()`, set `status = 'expired'`, `consumed_at = now()`, return `{"ok": false, "error": "challenge_expired"}`.
3. **Check Exhaustion**:
   - If `attempts >= max_attempts`, set `status = 'exhausted'`, `consumed_at = now()`, return `{"ok": false, "error": "max_attempts_exceeded"}`.
4. **Evaluate Token Hash**:
   - Compare `challenge_hash` with `sha256(p_challenge_token)` using constant-time equality.
   - **On Hash Mismatch**:
     - Increment `attempts = attempts + 1`.
     - If `attempts >= max_attempts`, set `status = 'exhausted'`, `consumed_at = now()`.
     - Insert audit event `device_recredential_failed` with attempt count.
     - **RETURN** `{"ok": false, "error": "invalid_token", "attempts_remaining": max_attempts - attempts}`. (Transaction commits!).
   - **On Hash Match**:
     - Verify `p_actor_user_id == device.child_user_id`. If mismatch, return `{"ok": false, "error": "unauthorized"}`.
     - Update `devices`: set `secret_hash = p_new_secret_hash`, `installation_id = p_new_installation_id`, `credential_issued_at = now()`.
     - Update challenge: set `status = 'redeemed'`, `consumed_at = now()`.
     - Insert audit event `device_recredentialed`.
     - **RETURN** `{"ok": true, "device_id": p_device_id, "recredentialed_at": now()}`. (Transaction commits!).

---

## 6. Verification Test Matrix for REV-001

| Test ID | Test Case Description | Inbound Input | Expected DB State | Expected Result |
|---|---|---|---|---|
| `TEST-REV001-01` | First failed attempt | Wrong token | `attempts = 1`, `status = 'active'` | `ok: false, attempts_remaining: 4` |
| `TEST-REV001-02` | Sequential failed attempts | 4 wrong tokens | `attempts = 4`, `status = 'active'` | `ok: false, attempts_remaining: 1` |
| `TEST-REV001-03` | 5th failed attempt triggers lockout | 5th wrong token | `attempts = 5`, `status = 'exhausted'`, `consumed_at` not null | `ok: false, error: 'max_attempts_exceeded', attempts_remaining: 0` |
| `TEST-REV001-04` | 6th attempt after exhaustion | Valid token | `attempts = 5`, `status = 'exhausted'` | `ok: false, error: 'challenge_exhausted'` |
| `TEST-REV001-05` | Concurrent redemption serialized | 2 simultaneous invalid tokens | `attempts` increments from 0 to 2 sequentially | Zero race condition; both increments persist |
| `TEST-REV001-06` | Success on 5th attempt | 4 wrong, then 1 valid | `attempts = 4`, `status = 'redeemed'`, `secret_hash` updated | `ok: true`, device authenticated |

---

## 7. Resolution Status

**RESOLVED BY DESIGN CORRECTION**. The structured return value architecture guarantees that failed attempts are permanently committed to disk, locking the challenge after 5 failed attempts and eliminating the brute-force vulnerability.
