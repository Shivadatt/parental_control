# 03 — Credential Rotation Security & Protocol Review (HAVEN-QA-003)

**Document ID:** HAVEN-REV-003  
**Target Defect:** HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Phase:** Phase 1.1 — Remediation Plan Independent Review (Strictly Read-Only)  
**Date:** 2026-11-23  
**Review Focus:** Distributed Cryptographic Identity, Concurrency, and Security Validation  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Context & Review Mandate

`HAVEN-QA-003` represents the highest-risk architectural workstream in the remediation package. It proposes modifying how hardware devices authenticate against Supabase Edge Functions and the PostgreSQL database.

This review independently verifies:
1. Fidelity to the binding **Phase 4 Gate A Option C** approved design baseline.
2. The cryptographic integrity of the challenge exchange.
3. Concurrency, race conditions, and transaction boundaries.
4. Failure recovery under catastrophic network and power interruptions.
5. The validity of the proposed rollback runbook.

---

## 2. Phase 4 Gate A Option C Fidelity Audit

The Phase 4 Gate A Option C design establishes four inviolable architectural requirements:
1. **Parent-Approved**: Only an authenticated Parent with active membership in the device's family can request credential rotation.
2. **Child-Authenticated**: The Child device must authenticate using a verified Child JWT with active family membership.
3. **Single-Use Challenge**: Challenge tokens must expire after 10 minutes, be limited to 5 attempts, and be consumed atomically.
4. **Relationship Preservation**: The `devices.id` UUID, family membership, and historical telemetry (location, usage, alerts) must be preserved intact on the existing row.

### Fidelity Assessment
The Phase 1 proposal in `03_credential_lifecycle_remediation_design.md` **correctly adheres to the core Option C topology**. It rejects Option B (child-only takeover) and Option D (destructive unpairing). However, its technical implementation in SQL and client state management introduces severe vulnerabilities detailed below.

---

## 3. Critical Security & Protocol Findings

---

### Finding REV-001 (CRITICAL): The PL/pgSQL Attempt Counter Rollback Bug

#### The Flaw
In `03_credential_lifecycle_remediation_design.md`, lines 120–127 define how failed challenge token verifications are handled in the `rotate_device_secret` RPC:

```sql
-- Lines 120-127 in 03_credential_lifecycle_remediation_design.md
if v_challenge.challenge_hash <> v_token_hash then
  update public.device_recovery_challenges
  set attempts = attempts + 1
  where id = v_challenge.id;
  raise exception 'Invalid re-credentialing challenge token.'
    using errcode = 'P0005';
end if;
```

#### Technical Mechanism of Failure
- In PostgreSQL, calling `RAISE EXCEPTION` aborts the current transaction block.
- Any uncommitted statements executed earlier in that block—including the `UPDATE ... set attempts = attempts + 1` statement—are **completely rolled back**.
- As a direct consequence, the `attempts` column in `device_recovery_challenges` remains at `0` regardless of how many invalid tokens are submitted.
- The check `if v_challenge.attempts >= v_challenge.max_attempts` will **NEVER** evaluate to true!
- An attacker can submit an infinite stream of brute-force challenge guesses within the 10-minute window without ever encountering lockout!

#### Proof of Exploitability
If an attacker intercepts or observes that a re-credentialing challenge is active for a target device, they can run an automated script calling `/device-register` with brute-forced 6-digit codes. Because each incorrect attempt rolls back the counter increment, all 5 attempts remain available until the 10-minute TTL expires.

#### Required Remediation
PostgreSQL cannot commit a partial update if the function terminates via `RAISE EXCEPTION`. The RPC must handle verification failures by returning a structured JSON result without rolling back the transaction:
```sql
if v_challenge.challenge_hash <> v_token_hash then
  update public.device_recovery_challenges
  set attempts = attempts + 1
  where id = v_challenge.id;

  return jsonb_build_object(
    'ok', false,
    'error', 'invalid_challenge_token',
    'attempts_remaining', greatest(0, v_challenge.max_attempts - (v_challenge.attempts + 1))
  );
end if;
```
This allows the transaction to commit the incremented `attempts` count, guaranteeing that on the 5th failed attempt, the challenge is locked permanently.

---

### Finding REV-002 (CRITICAL): The Asymmetric Update / Lost Response Deadlock

#### The Flaw
The proposed protocol in Report 03 assumes an idealized, uninterrupted network exchange:
1. Child submits challenge and new secret hash.
2. Server executes `rotate_device_secret`, updates `devices.secret_hash = new_hash`, marks challenge `consumed_at = now()`.
3. Server returns HTTP 200.
4. Child receives HTTP 200 and begins syncing with new secret.

#### Failure Mechanism (The "Lost Response" Deadlock)
In real-world mobile environments (especially on unstable 3G/4G or roaming connections):
1. The server successfully updates the database and commits the rotation.
2. **Before the HTTP 200 response reaches the Child phone, the mobile connection drops or the app process is terminated by Android's low-memory killer (OOM).**
3. On the server:
   - `devices.secret_hash` is now set to `new_hash`.
   - The recovery challenge is marked `consumed`.
4. On the Child device:
   - The client never received confirmation that rotation succeeded.
   - If the client generated `new_secret` in memory or in a temporary staging key, it does not know whether to promote it to active or discard it.
   - If the client retries redeeming the challenge, the server rejects it with `"Challenge already consumed"`.
   - If the client attempts to use `secret_old`, the server rejects it with HTTP 401 `"invalid_device_credentials"`.
   - If the client attempts to use `secret_new`, it has no confirmation that `secret_new` was accepted.
5. **The device is now permanently deadlocked from syncing telemetry.**

#### Required Remediation: Two-Phase KeyStore Staging & Idempotent Verification
The Child native layer (`SecureStore.kt`) and Edge Function must implement a robust two-phase handshake:
1. **Pre-Staging in KeyStore**: Before transmitting the redemption request, `SecureStore.kt` writes `candidate_secret` and `candidate_installation_id` to an encrypted staging slot, keeping the current active secret intact.
2. **Idempotent Rotation Query**: If a network timeout occurs during redemption, the Child app does NOT immediately give up. It invokes an idempotent verification endpoint (`POST /device-register { action: "verify_rotation", device_id }`) authenticated with `candidate_secret`.
3. **Commit Promotion**: If the server verifies that `candidate_secret` matches `devices.secret_hash`, the client promotes `candidate_secret` to primary and deletes the staging slot. If rejected, it prompts the user to request a fresh challenge.

---

### Finding REV-005 (HIGH): The Schema Down-Migration Rollback Fallacy

#### The Flaw
In `08_implementation_order_and_rollback_plan.md:104-118`, the planning team states:
> *"If Step 6 encounters an unexpected production issue after deployment... execute down-migration: drop function rotate_device_secret; drop table device_recovery_challenges... The core devices table retains all existing data... without corruption."*

#### Why This Is a Dangerous Fallacy
- A database schema down-migration can drop tables and functions, but **it cannot reverse state modifications made to existing rows**!
- If 50 devices successfully re-credentialed during the deployment window, their `devices.secret_hash` values were updated to their new secrets.
- If an engineer executes the down-migration and reverts the Edge Function and client code to pre-Step-6 versions:
  - All 50 re-credentialed devices will immediately fail authentication (HTTP 401) because the old client builds or reverted Edge Functions will not understand the rotated keys.
  - The challenge history and audit trail are destroyed by `drop table cascade`.
  - The devices cannot be recovered without full unpairing.
- **Credential rotation is an irreversible state transition.** It cannot be rolled back via a down-migration.

#### Required Remediation
The remediation plan must explicitly state:
1. **Forward Recovery Only**: Once `rotate_device_secret` has been executed in production, rollback is NOT achieved by reverting migrations. If a bug is found, it must be fixed forward with a hotfix.
2. **Deprecation Window**: If the re-credentialing feature must be disabled, the Edge Function route should be toggled OFF via feature flag (`FEATURE_RECREDENTIALING_ENABLED = false`), leaving existing rotated credentials and database schemas completely untouched.

---

### Finding REV-009 (MEDIUM): Challenge Token Entropy and Usability

#### Analysis
- The proposal recommends a **6-digit alphanumeric code** with a 10-minute TTL and 5 attempts.
- **Entropy Math**:
  - A 6-character alphanumeric string (A–Z, 0–9, 36 characters) provides $36^6 \approx 2.18 \times 10^9$ possibilities (~31 bits of entropy).
  - With a maximum of 5 attempts, the probability of an attacker randomly guessing a valid challenge is $5 / (2.18 \times 10^9) \approx 2.3 \times 10^{-9}$ (negligible).
  - **Verdict on Security**: The mathematical entropy is robust.
- **Usability Friction on Mobile (REV-009)**:
  - Alphanumeric strings typed on soft mobile keyboards suffer from character confusion:
    - `0` (zero) vs `O` (capital O) vs `o` (lowercase o)
    - `1` (one) vs `I` (capital i) vs `l` (lowercase L)
  - If a parent dictates or reads a 6-digit mixed-case code to a child, transcription errors will rapidly consume the 5 allowed attempts, causing frustration and premature lockout.
- **Recommendation**:
  - Use **Crockford's Base32** (digits 0–9 and 22 letters, excluding I, L, O, and U) or an uppercase-only 6-character code with automatic normalisation (`toUpperCase()`, mapping `0` to `O` if necessary).
  - Crockford Base32 yields $32^6 \approx 1.07 \times 10^9$ combinations (~30 bits of entropy), maintaining identical security while eliminating user transcription errors.

---

## 4. RPC Security Architecture & `SECURITY DEFINER` Audit

The proposed `rotate_device_secret` RPC was evaluated for standard PostgreSQL security hardening:

| Security Invariant | Proposal Status | Reviewer Assessment |
|---|---|---|
| **Explicit `search_path`** | Set to `public, pg_temp` | **PASS**. Prevents schema injection attacks via search_path hijacking. |
| **Row Locking (`FOR UPDATE`)** | Locks challenge row and device row | **PASS**. Prevents race conditions during concurrent redemption attempts. |
| **Actor Ownership Check** | Asserts `v_device.child_user_id = p_actor_user_id` | **PASS**. Ensures authenticated child owns the target device row. |
| **Constant-Time Hash Comparison** | Uses `v_challenge.challenge_hash = v_token_hash` | **PASS**. Operating on SHA-256 hex digests eliminates timing leakage. |
| **Privilege Hardening** | `REVOKE ALL FROM public, anon, authenticated` | **PASS**. Function is executable only by `service_role`. |

---

## 5. Credential Architecture Review Conclusion

The overall architectural direction of Option C is sound and faithful to Phase 4 Gate A. However, **the implementation design cannot be approved in its current state**.

### Blocking Conditions for Owner Approval:
1. **Fix REV-001**: Rewrite `rotate_device_secret` to return structured JSON errors on failed token checks so that `attempts = attempts + 1` commits to disk.
2. **Fix REV-002**: Specify the two-phase KeyStore staging and verification handshake in `SecureStore.kt` and `device-register` to handle lost HTTP responses.
3. **Fix REV-005**: Eliminate the schema down-migration rollback instructions and replace them with a forward recovery and feature-flag disablement runbook.
