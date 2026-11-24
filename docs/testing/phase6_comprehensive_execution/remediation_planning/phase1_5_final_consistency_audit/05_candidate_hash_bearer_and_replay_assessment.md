# Phase 1.5: Candidate Secret Hash Bearer-Credential & Replay Risk Assessment

**Document ID:** `HAVEN-AUD-005-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Independent Adversarial Threat Analysis  

---

## 1. Executive Summary

This assessment independently evaluates the threat model surrounding the transmission and storage of `candidate_secret_hash` within the proposed HAVEN device re-credentialing protocol (`HAVEN-QA-003`). It rigorously challenges the assumption that SHA-256 pre-image resistance alone renders the candidate hash safe from replay, theft, or unauthorized elevation of privilege.

### Mandatory Assessment Verdict:
```
==================================================================================================
                        DESIGN-ONLY — REQUIRES SECURITY TESTING
==================================================================================================
```

---

## 2. Ingress Endpoints & Identity Binding Analysis

The re-credentialing protocol involves three primary endpoints across Supabase Edge Functions:

```
[ Parent Device ] ---> POST /family-admin (request_recredential_challenge) ---> [ DB: Challenge Minted ]
                                                                                         |
                                                                                         v
[ Child Device ]  ---> POST /device-register (redeem_recredential_challenge)  ---> [ DB: Secret Rotated ]
                                                                                         |
                                  (If Network Response Lost)                             v
[ Child Device ]  ---> POST /device-register (verify_device_rotation)        ---> [ DB: Idempotent Query ]
```

### 2.1 Endpoint Identity & Authorization Binding

| Endpoint & Action | Invoker Identity | Auth Mechanism | Input Parameters | Server Verification & Binding Checks |
|---|---|---|---|---|
| `POST /family-admin`<br/>(`request_recredential_challenge`) | Parent User | Parent Bearer JWT (`auth.uid()`) | `device_id: UUID` | 1. Verifies parent belongs to `devices.family_id`.<br/>2. Enforces device rate limit ($\le 3$/hr).<br/>3. Enforces DB single-active index.<br/>4. Issues 6-char Base32 token. |
| `POST /device-register`<br/>(`redeem_recredential_challenge`) | Child Device | Child Bearer JWT (`auth.uid()`) | `device_id: UUID`<br/>`challenge_token: TEXT`<br/>`installation_id: UUID`<br/>`candidate_secret_hash: TEXT` | 1. Verifies child JWT matches `devices.child_user_id`.<br/>2. Matches `challenge_token` with active DB challenge.<br/>3. Checks `expires_at > now()` and `attempts < 5`.<br/>4. Writes `devices.secret_hash = candidate_secret_hash`. |
| `POST /device-register`<br/>(`verify_device_rotation`) | Child Device | Child Bearer JWT (`auth.uid()`) | `device_id: UUID`<br/>`candidate_installation_id: UUID`<br/>`candidate_secret_hash: TEXT` | 1. Verifies child JWT matches `devices.child_user_id`.<br/>2. Compares inputs against current `devices` row.<br/>3. Returns `{ "confirmed": true/false }`. |

---

## 3. Threat Analysis: Eight Threat Vectors

### 3.1 Threat Vector 1: Credential Disclosure & Pre-Image Exploitation
- **Scenario**: An adversary intercepts `candidate_secret_hash` from TLS termination logs or proxy inspect.
- **Analysis**: The candidate secret $s$ is generated via `SecureRandom().nextBytes(32)` inside the child handset's KeyStore. The transmitted value is $h = \text{SHA256}(s)$.
- **Security Assessment**: Pre-image resistance of SHA-256 guarantees that deriving $s$ from $h$ requires $\mathcal{O}(2^{256})$ operations. Because normal telemetry (`POST /device-telemetry`) strictly requires the plaintext $s$ in header `x-device-secret`, possessing $h$ alone does **NOT** allow an attacker to forge telemetry, heartbeat, or commands.
- **Finding**: **SAFE BY DESIGN**.

### 3.2 Threat Vector 2: Replay of Challenge Redemption
- **Scenario**: An adversary captures the full payload of `redeem_recredential_challenge` and replays it over the network.
- **Analysis**:
  - The redemption transaction in PostgreSQL executes `UPDATE device_recovery_challenges SET status = 'redeemed', consumed_at = now() WHERE id = v_challenge.id AND status = 'active'`.
  - The first request consumes the challenge.
  - The replayed request encounters `status = 'redeemed'` and is rejected immediately with HTTP 400 / 409 (`challenge_already_redeemed`).
- **Finding**: **SAFE BY DESIGN**.

### 3.3 Threat Vector 3: Cross-Device Hash Reuse
- **Scenario**: An attacker captures a candidate hash intended for Device A and attempts to inject it into Device B's recovery flow.
- **Analysis**: The redemption RPC binds the candidate hash to the specific `device_id` associated with the active challenge. If submitted against Device B, Device B's active challenge token would be required, and the rotation would update Device B's hash to $h$. However, because neither the attacker nor Device B possesses the pre-image $s$ (which is isolated in Device A's KeyStore), Device B would become permanently orphaned from telemetry.
- **Finding**: **SAFE BY DESIGN (Denial-of-Service if Child JWT Compromised)**.

### 3.4 Threat Vector 4: Challenge Substitution & Man-in-the-Middle
- **Scenario**: An attacker substitutes their own candidate hash during an active challenge redemption initiated by a legitimate parent.
- **Analysis**: Requires the attacker to intercept and modify the child device's outbound HTTPS traffic and possess the child's valid Bearer JWT. If the child JWT is compromised, the attacker can submit their own candidate hash and retain the corresponding secret, hijacking device telemetry.
- **Mitigating Controls**: Child Bearer JWT is stored in Android `EncryptedSharedPreferences` and protected by Android OS sandbox. TLS 1.3 encryption prevents in-transit payload modification.
- **Finding**: **SAFE BY DESIGN (Standard Token Boundary)**.

### 3.5 Threat Vector 5: Lost-Response Recovery & Re-Authentication Deadlock
- **Scenario**: The server commits key rotation to the database, but the HTTP 200 response is dropped by a mobile network tower drop (Crash Point CP-08/09).
- **Analysis**: The child device is unaware of server success. If the child is forced to generate a new secret and request a new parent challenge, the parent must intervene repeatedly.
- **Resolution**: The child transitions to `SERVER_ROTATION_UNKNOWN` (or `RECOVERY_REQUIRED` on app reboot). It calls `verify_device_rotation` transmitting its staged `(candidate_installation_id, candidate_secret_hash)`. The server verifies that `devices.secret_hash == candidate_secret_hash` and returns `{ "confirmed": true }`. The client promotes the staged key to primary.
- **Finding**: **SAFE BY DESIGN**.

### 3.6 Threat Vector 6: Duplicate Ingress Requests
- **Scenario**: The child device sends duplicate redemption requests due to client-side network retry timeouts.
- **Analysis**: The database transaction locks the challenge row via `SELECT ... FOR UPDATE`. The first request succeeds and sets `status = 'redeemed'`. The second request reads `status = 'redeemed'` and returns HTTP 409. The client handles HTTP 409 by executing `verify_device_rotation`, which confirms that the candidate hash is indeed active.
- **Finding**: **SAFE BY DESIGN**.

### 3.7 Threat Vector 7: Concurrent Recovery Race Conditions
- **Scenario**: Multiple concurrent requests attempt to redeem the same challenge simultaneously.
- **Analysis**: PostgreSQL row-level locks serialize the execution. The atomic update condition `WHERE status = 'active'` ensures that exactly one transaction modifies the row.
- **Finding**: **SAFE BY DESIGN**.

### 3.8 Threat Vector 8: Unauthorized Verification Probing
- **Scenario**: An external party calls `verify_device_rotation` to probe whether a given secret hash exists in the database.
- **Analysis**: The endpoint strictly requires an authenticated Child JWT. Supabase RLS and RPC verify `auth.uid() == devices.child_user_id`. An arbitrary third party receives HTTP 401/403.
- **Finding**: **SAFE BY DESIGN**.

---

## 4. Threat Matrix Summary

| Threat ID | Threat Description | Inherent Risk | Mitigating Architectural Control | Residual Risk Level | Required Gate Verification |
|---|---|---|---|---|---|
| **T-01** | Telemetry Forgery via Captured Hash | Critical | SHA-256 pre-image resistance; telemetry requires raw secret. | Negligible | Gate 6 (Staging E2E) |
| **T-02** | Redemption Request Replay | High | Atomic state transition `status = 'redeemed'`. | Negligible | Gate 6 (Staging E2E) |
| **T-03** | Cross-Device Hash Reuse | Medium | Bound to `p_challenge_id` and `p_device_id`. | Low | Gate 6 (Staging E2E) |
| **T-04** | Man-in-the-Middle Substitution | High | TLS 1.3 transport security; Android app sandbox. | Low | Gate 6 (Staging E2E) |
| **T-05** | Lost-Response Key Lockout | High | Idempotent `verify_device_rotation` protocol. | Low | Gate 6 (Fault Injection) |
| **T-06** | Duplicate Request Race | Medium | Row-level locking (`SELECT FOR UPDATE`). | Negligible | Gate 4 / Gate 6 |
| **T-07** | Concurrent Redemption Race | High | Relational transaction atomicity. | Negligible | Gate 4 (pgTAP) |
| **T-08** | Unauthorized Verification Probing | Medium | Authenticated Child Bearer JWT check (`auth.uid()`). | Negligible | Gate 5 (Deno Test) |

---

## 5. Conclusion & Mandatory Implementation Conditions

The claim that `candidate_secret_hash` is not a bearer credential is **THEORETICALLY AND ARCHITECTURALLY DEFENDED**. However, because these endpoints have not yet been deployed to staging, this finding cannot be closed as "verified by source evidence."

**Conditions for Gate 5 / Gate 6 Approval**:
1. Edge Function request logging must explicitly redact `candidate_secret_hash` from debug and error logs.
2. The `verify_device_rotation` RPC must enforce strict child user ID authorization matching `devices.child_user_id`.
3. Automated staging penetration tests must verify that replay of redeemed tokens returns HTTP 400/409.
