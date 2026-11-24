# 02 — QA-003 Credential Transmission, Request/Response Protocol & Threat Model

**Document ID:** `HAVEN-AUD-002-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification, Protocol Verification & Final Owner Approval Readiness  
**Date:** 2026-11-24  
**Target Workstream:** WORKSTREAM A1 (QA-003 Credential Transmission & Cryptographic Threat Model)  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary & Resolution of the Plaintext Transmission Contradiction

Phase 1.3 report `02_rev001_rev002_transaction_and_keystore_audit.md` and `10_consolidated_qa003_credential_protocol.md` made the categorical assertion:
> *"Raw secrets never stored on DB, never logged, never sent over wire."*

### Independent Source Evidence & Adversarial Challenge
This claim is **PROVABLY INACCURATE AND DIRECTLY CONTRADICTED BY THE CODEBASE**:
1. In `supabase/functions/_shared/auth.ts:297-343` (the production authentication helper for all Edge Functions):
   ```typescript
   export async function requireDevice(req: Request, db: SupabaseClient): Promise<DeviceRow> {
     const deviceId = req.headers.get("x-device-id") ?? "";
     const secret = req.headers.get("x-device-secret") ?? "";
     ...
     const digest = await sha256Hex(secret);
     if (!constantTimeEqualHex(digest, device.secret_hash)) {
       throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
     }
   }
   ```
2. The client transmits the **RAW SECRET MATERIAL** in the HTTP request header `x-device-secret` for normal device telemetry (`/device-telemetry`), command acknowledgments (`/device-command`), and remote assistance sessions (`/remote-session`).
3. The Edge Function receives the raw secret, computes its SHA-256 digest in server memory, and compares it against `devices.secret_hash` stored in PostgreSQL.

### Corrected Technical Reality
- **Where raw plaintext secrets exist**: Generated and held in memory on the child device; persisted in `EncryptedSharedPreferences` backed by the Android hardware KeyStore MasterKey (`SecureStore.kt`).
- **Where raw secrets travel**: Transmitted over the wire in HTTP header `x-device-secret` during all normal telemetry and heartbeat communications, protected in transit exclusively by **Transport Layer Security (TLS 1.3)**.
- **Where raw secrets are processed**: Parsed into memory within Deno Edge Function isolates, hashed with SHA-256, and discarded immediately after memory comparison.
- **Where hashes are stored**: Only the 64-character hexadecimal SHA-256 hash digest is written to and stored in PostgreSQL (`public.devices.secret_hash`).
- **Where raw secrets must never appear**: In application logs, Edge Function console logs, PostgreSQL WAL/tables, audit event metadata, and error message responses.

---

## 2. Complete Request/Response Re-credentialing & Telemetry Protocol Table

The following authoritative table details every network interaction across re-credentialing and subsequent device operations:

| Request Step | Endpoint & Method | Caller Identity | Authentication Factor | Request Payload / Headers | Sensitive Fields Present | Transport Protection | Server-Side Processing | Database Mutation | Response Payload | Replay & Security Implications | Logging & Redaction Requirements |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Step 1: Challenge Request** | `POST /family-admin` | Active Parent | Verified Parent JWT (`Bearer <jwt>`) | `{ action: "request_recredential_challenge", device_id: "<uuid>" }` | None (Device ID is a non-sensitive UUID) | HTTPS / TLS 1.3 | 1. Verifies parent role & family membership<br/>2. Checks rate limit (< 3/hr)<br/>3. Invalidates prior active challenge<br/>4. Generates 6-char Crockford Base32 token | `UPDATE device_recovery_challenges SET status = 'superseded'`<br/>`INSERT INTO device_recovery_challenges` | `HTTP 200 { challenge_token: "7K4X9M", expires_at: "..." }` | Single-use; 10m TTL. Token is single-use bearer verifier. | Token MUST NOT be logged in server logs. Audit event `device_recredential_challenge_issued` logs `challenge_id` only. |
| **Step 2: Challenge Redemption** | `POST /device-register` | Enrolled Child | Verified Child JWT (`Bearer <jwt>`) | `{ action: "redeem_recredential_challenge", device_id: "<uuid>", challenge_token: "7K4X9M", installation_id: "<new_uuid>", secret_hash: "<sha256_hex>" }` | `challenge_token` (single-use verifier); `secret_hash` (candidate hash) | HTTPS / TLS 1.3 | 1. Verifies child JWT owns `device_id`<br/>2. Validates format & Crockford normalization<br/>3. Invokes `rotate_device_secret` RPC with row lock | `SELECT ... FOR UPDATE`<br/>Atomic update of `devices.secret_hash` & `devices.installation_id`<br/>`UPDATE challenges SET status = 'redeemed'` | `HTTP 200 { ok: true, device_id: "<uuid>", recredentialed_at: "..." }` | Replay rejected; challenge consumed atomically. Possession of `secret_hash` alone cannot authenticate telemetry. | Redact `challenge_token` and `secret_hash` from request body logs. Audit event records `device_recredentialed`. |
| **Step 3: Verification Handshake** | `POST /device-register` | Enrolled Child | Verified Child JWT (`Bearer <jwt>`) | `{ action: "verify_device_rotation", device_id: "<uuid>", candidate_installation_id: "<uuid>", candidate_secret_hash: "<sha256_hex>" }` | `candidate_secret_hash` (derived verifier) | HTTPS / TLS 1.3 | 1. Verifies child JWT owns device<br/>2. Queries `devices` row<br/>3. Compares `devices.secret_hash == candidate_secret_hash` | Zero database mutations. Strictly read-only query. | `HTTP 200 { confirmed: true }` OR `{ confirmed: false, retry_allowed: bool }` | Strictly idempotent. Can be invoked repeatedly across retries without burning attempts. | Redact `candidate_secret_hash`. Audit event `device_rotation_verified` logs `device_id`. |
| **Step 4: Normal Telemetry Heartbeat** | `POST /device-telemetry` | Enrolled Hardware | Device Credentials (`x-device-id`, `x-device-secret`) | Headers:<br/>`x-device-id: <uuid>`<br/>`x-device-secret: <raw_32_bytes_hex>`<br/>Body: Telemetry JSON | `x-device-secret` (RAW BEARER SECRET) | HTTPS / TLS 1.3 | 1. Extracts secret from header<br/>2. Computes `sha256Hex(secret)`<br/>3. Constant-time compares with `device.secret_hash`<br/>4. Updates `last_seen_at` | `UPDATE devices SET last_seen_at = now(), battery_level = ...` | `HTTP 200 { ok: true, server_time: "..." }` | Header `x-device-secret` acts as bearer credential. Must be transmitted exclusively over TLS. | **CRITICAL**: Redact `x-device-secret` header from all HTTP access logs and proxy logs! |
| **Step 5: Device Command Acknowledgment** | `POST /device-command` | Enrolled Hardware | Device Credentials (`x-device-id`, `x-device-secret`) | Headers: `x-device-id`, `x-device-secret`<br/>Body: Command Ack JSON | `x-device-secret` (RAW BEARER SECRET) | HTTPS / TLS 1.3 | 1. Authenticates device via SHA-256 comparison<br/>2. Records command ack & enforcement status | `UPDATE device_commands SET acked_at = now()`<br/>`UPDATE device_policies SET enforcement_status = ...` | `HTTP 200 { ok: true }` | Same bearer replay considerations as Step 4. | Redact `x-device-secret` header. |

---

## 3. Cryptographic Classification of Protocol Artifacts

To prevent architectural ambiguity, the table below categorizes every cryptographic data item:

| Protocol Artifact | Exact Representation | Generation Source | Transmission Medium | Classification | Can Possession Allow Telemetry Impersonation? | Replay Implications |
|---|---|---|---|---|---|---|
| **`device_secret` / `candidate_secret`** | 32 random bytes (64-char hex string) | Android `SecureRandom` in `SecureStore.kt` | Transmitted in `x-device-secret` header during telemetry | **Raw Bearer Secret** | **YES**. Anyone possessing this raw pre-image can authenticate to telemetry endpoints. | Replayable over network if TLS is broken or leaked from logs. |
| **`secret_hash` / `candidate_hash`** | 64-character SHA-256 hexadecimal string | Computed via `sha256(secret)` on client or server | Transmitted in body during redemption and verification | **Derived Cryptographic Verifier** | **NO**. Telemetry endpoints demand the raw secret pre-image (`sha256Hex(secret)`), not the hash. Pre-image resistance holds. | Possession of hash alone CANNOT spoof telemetry heartbeats. |
| **`challenge_token`** | 6-character Crockford Base32 string (`[0-9A-HJKMNP-TV-Z]`) | Deno CSPRNG (`crypto.getRandomValues`) in `/family-admin` | Out-of-band Parent $\rightarrow$ Child; transmitted in redemption body | **Single-Use Challenge Token** | **NO**. Only valid when paired with verified Child JWT matching device owner. | Dead upon redemption (`consumed_at`). Cannot be replayed. |
| **`candidate_installation_id`** | 36-character UUID string | `UUID.randomUUID()` in `SecureStore.kt` | Transmitted in redemption and verification body | **Non-Sensitive Hardware Installation ID** | **NO**. Informational binding identifier. | Replay harmless without valid secret. |

---

## 4. Threat Model & Secret Exposure Boundaries

### 4.1 Threat Model Assumptions & TLS Boundaries
1. **Transport Layer Security (TLS 1.3)**:
   - The HAVEN threat model assumes TLS 1.3 encryption terminates cleanly at the Supabase infrastructure edge.
   - Passive network eavesdroppers (Wi-Fi sniffers, ISP routing nodes) cannot inspect HTTP headers or request bodies.
   - Eavesdropping on `x-device-secret` is possible ONLY if an attacker controls a compromised Certificate Authority or installs a rogue CA certificate onto the child's Android trust store.
2. **Reverse Proxy & Infrastructure Logging Threat**:
   - Because `x-device-secret` travels in HTTP headers, standard reverse proxy access logs (NGINX, Cloudflare, Supabase Ingress) could accidentally log header values unless explicitly stripped.
   - **Mandatory Hardening Requirement**: Supabase Edge Functions and ingress proxies must enforce `Access-Control-Expose-Headers` restrictions and configure log scrubbers to mask `x-device-secret` from access logs.
3. **Database Compromise Threat**:
   - In the event of an unauthorized PostgreSQL database dump or SQL injection vulnerability, the attacker obtains `devices.secret_hash`.
   - Because SHA-256 is computationally infeasible to invert ($2^{256}$ pre-image resistance), obtaining `secret_hash` does **NOT** grant the attacker the ability to inject fake telemetry heartbeats, because the telemetry endpoints require the raw pre-image `x-device-secret`.

---

## 5. Precise Replacement Security Statement

The inaccurate Phase 1.3 claim is formally replaced by the following authoritative specification:

> **Authoritative HAVEN Credential Transmission & Storage Specification:**  
> 1. Raw device secrets are generated on the child handset using cryptographically secure hardware RNG and stored encrypted in native Android KeyStore-backed storage.  
> 2. Raw device secrets are transmitted over the network in HTTP header `x-device-secret` for telemetry authentication, protected in transit by TLS 1.3 encryption.  
> 3. Server Edge Functions hash the received secret in memory using SHA-256 and store only the 64-character hexadecimal hash digest in PostgreSQL (`devices.secret_hash`). Raw secrets are never stored in the database.  
> 4. In re-credentialing redemption, the client transmits the derived `candidate_hash`, meaning the candidate raw secret does not cross the network until normal telemetry resumes.  
> 5. Raw secrets, challenge tokens, and candidate hashes must be strictly redacted from application logs, error payloads, and audit event records.
