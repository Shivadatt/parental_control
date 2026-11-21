# 08 — Contract Freeze Proposal

**Status:** PROPOSED — NOT AUTHORIZED. No SQL, migration, Edge change or client change is authorized by this document.  
**Basis:** Phase 4 Option C (asserted approved) + Phase 5 plan + Phase 5.1 recommendations.

This is the contract that Gate C/B would implement **if** the owner accepts the recommended C1–C8 values.

---

## 1. Frozen scope

### In scope
- One service-only challenge table.
- One Parent request RPC, one committed-attempt RPC, one atomic redeem RPC.
- Optional status/cancel RPCs (C3).
- Existing `family-admin` and `device-register` Edge actions.
- Flutter Parent/Child UI and Kotlin credential-state/resync.
- Audit events and session termination.

### Out of scope
- E2E-002/003/004 fixes.
- Bedtime, emergency pass, FCM, map, route guards, forgot-password.
- Any change to `requireDevice`, pairing, or destructive `recover_device`.

---

## 2. Authorization model

| Operation | Caller | Checks |
|---|---|---|
| Request challenge | Parent | user JWT, verified email, role `parent`, active parent in **device's** family |
| Read status | Parent | same |
| Cancel | Parent | same, challenge in family |
| Redeem | Child | user JWT, verified email, role `child`, active child in **challenge's** family |
| RPC execution | Service role only | `SECURITY DEFINER`, safe `search_path`, explicit in-body checks |

No device headers are accepted for recovery.

---

## 3. Challenge table (behavioural contract)

**Name:** `device_recredential_challenges`

| Field | Contract |
|---|---|
| `id` | uuid PK |
| `family_id` | uuid, FK families, cascade |
| `device_id` | uuid, FK devices, cascade |
| `child_user_id` | uuid, FK profiles, cascade |
| `created_by` | uuid, FK profiles, set null |
| `code_hash` | 64-hex, unique, keyed digest preferred (C4) |
| `status` | `pending|consumed|expired|superseded|cancelled` |
| `expires_at` | timestamptz, = creation + 10 min |
| `attempts` | int >= 0 |
| `max_attempts` | int = 5 |
| `consumed_at` / `consumed_by` | set only on success |
| `superseded_at` / `cancelled_at` | matching status |
| `created_at` | now |

**Constraints/indexes:**
- unique `code_hash`;
- unique partial on `device_id where status='pending'`;
- `(child_user_id,status)`, `(family_id,status)`, `(expires_at)`;
- status/timestamp consistency checks.

**RLS/grants:**
- RLS enabled; no `anon`/`authenticated` policies;
- `REVOKE ALL` from `public`, `anon`, `authenticated`;
- `GRANT SELECT, INSERT, UPDATE` to `service_role`.

---

## 4. RPC contracts

### 4.1 `request_device_recredential`

```
Inputs:  p_device_id uuid
         p_actor_user_id uuid
         p_code_hash text
         p_expires_at timestamptz
         p_max_attempts int
Returns: { challenge_id, expires_at, max_attempts,
           device_id, family_id, child_user_id,
           superseded_challenge_id | null }
```

Transaction:
1. lock device;
2. active parent in `device.family_id`;
3. active device, not revoked;
4. active child;
5. supersede pending;
6. insert challenge;
7. audit `device_recredential_requested`;
8. return metadata (never `code_hash`).

Errors: `device_not_found`, `forbidden`, `device_not_active`, `child_not_active`, `challenge_conflict`.

### 4.2 `record_device_recredential_attempt`

```
Inputs:  p_challenge_id uuid, p_child_user_id uuid
Returns: { attempts, max_attempts, allowed, reason }
```

Locks challenge; validates pending/expiry; atomically increments and **commits** (D8); returns `allowed`.

### 4.3 `redeem_device_recredential`

```
Inputs:  p_challenge_id uuid
         p_child_user_id uuid
         p_device_id uuid
         p_installation_id text
         p_secret_hash text
         p_platform text | null
         p_android_version text | null
         p_app_version text | null
Returns: public device projection + status 'recredentialed'
```

Transaction:
1. lock challenge;
2. D9 idempotency check if consumed;
3. status/expiry/attempts;
4. child identity + active membership;
5. lock device; same family/child, active, not revoked;
6. installation uniqueness excluding this device;
7. replace `secret_hash`, `installation_id`, `credential_issued_at`;
8. preserve `id`, `family_id`, `child_user_id`, `status`, `policy_version`, permissions, `display_name`, `last_seen_at`;
9. end active remote sessions (`device_recredentialed`);
10. mark consumed;
11. audit `device_recredentialed`;
12. commit.

Errors: `challenge_not_found`, `challenge_expired`, `challenge_superseded`, `challenge_cancelled`, `recovery_already_used`, `attempts_exhausted`, `forbidden`, `child_not_active`, `challenge_mismatch`, `device_not_active`, `installation_conflict`.

### 4.4 Optional (C3)

- `device_recredential_status(p_device_id, p_actor_user_id)` → `{state, expires_at, attempts_remaining, completed_at}`.
- `cancel_device_recredential(p_challenge_id, p_actor_user_id)` → `{status:'cancelled'}`; pending only; audit.

---

## 5. State machine

```
none --request--> pending --redeem--> consumed
                    |
                    +--expire--> expired
                    +--supersede--> superseded
                    +--cancel--> cancelled
```

Only `consumed` changes the credential. Expired/superseded/cancelled leave it unchanged.

---

## 6. Expiry and attempts

| Rule | Value | Status |
|---|---|---|
| TTL | 10 minutes | asserted D2 |
| Max attempts | 5 | asserted D2 |
| Attempt commit | before validation | asserted D8 |
| Expiry enforcement | in every RPC, under lock | required |
| Sweeper | optional | deferrable (C7) |

---

## 7. Idempotency (D9)

On consumed challenge, return 200 only if:
- submitted `installation_id` equals current;
- submitted `secret_hash` equals current;
- device active/not revoked.

Otherwise 409. Never rotate twice.

---

## 8. Session and audit

- End `requested|accepted|active` sessions for the device with reason `device_recredentialed` (D5).
- Audit request and completion in their transactions; audit failure rolls back.
- Metadata: IDs, timestamps, method, counts; no secret/hash/code/JWT/installation ID.

---

## 9. Rate limits

| Limit | Value | Status |
|---|---:|---|
| Pending/device | 1 | recommendation (schema) |
| Requests/device/hour | 5 | recommendation |
| Requests/parent/hour | 10 | recommendation |
| Failed/child/10 min | 10 | recommendation |
| Failed/family/10 min | 20 | recommendation |

Only TTL and attempts are approved. These freeze only if C6 is accepted.

---

## 10. Feature flag (C5)

- Server-side only.
- Default off.
- Off → `503 recovery_disabled`.
- Flag-read failure → fail closed.
- RPCs remain service-role-only; clients cannot bypass.
- No client-side flag.

---

## 11. Client contracts

### Parent
- `request_device_recredential` → challenge code/expiry.
- Show code/QR; confirm target; offer reissue; optional status/cancel.
- Never show secret/hash.

### Child
- Detect `unconfirmed` from native 401 classification.
- Enter code; send `installation_id` + `secret_hash` only.
- On success, rewrite `SyncConfig` with same device id/secret; heartbeat proves completion.
- No auto-recovery.

---

## 12. Contract invariants

1. No client-supplied family/child authority.
2. No secret in any request except the hash.
3. No hash/installation id in any response.
4. No automatic recovery.
5. No revoked device rotation.
6. No second rotation from a consumed challenge.
7. Membership and device UUID preserved.
8. No code returned after creation.

---

## 13. Freeze blockers

The contract cannot be marked frozen until the owner decides:

- **C1** parent re-validation;
- **C2** attempt mechanism;
- **C3** status/cancel scope;
- **C4** code format;
- **C6/N3** at least the pending-per-device invariant;
- **C8** signed Gate A/value record.

C5 and C7 can be finalized before Gate D.

---

## 14. Status

**PROPOSED — NOT FROZEN — NOT AUTHORIZED.**

No SQL, migration, Edge change, Flutter/Kotlin change, deployment, or recovery was performed.
