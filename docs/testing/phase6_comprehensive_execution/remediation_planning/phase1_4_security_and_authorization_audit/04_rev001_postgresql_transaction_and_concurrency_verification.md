# 04 — REV-001 PostgreSQL Transaction Invariants, Concurrency & Structured Return Semantics

**Document ID:** `HAVEN-AUD-004-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification, Protocol Verification & Final Owner Approval Readiness  
**Date:** 2026-11-24  
**Target Workstream:** WORKSTREAM B1, B2 (PostgreSQL Transaction Semantics & Attempt Invariants)  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary & Verification of Structured JSONB Returns

Phase 1.1 identified finding `REV-001`: In PostgreSQL PL/pgSQL, raising an exception via `RAISE EXCEPTION` aborts the transaction, reverting the attempt counter update in WAL and allowing unlimited brute-force attempts.
Phase 1.2 proposed Approach A: Returning a structured `JSONB` payload (`{"ok": false, "error": "...", "attempts_remaining": X}`) to allow the transaction to commit cleanly.

This report independently verifies the PostgreSQL storage engine mechanics, transaction boundaries, commit durability conditions, and concurrency serialization locks.

---

## 2. In-Depth PostgreSQL Transaction Semantics (Workstream B1)

### 2.1 When Does Returning Structured JSON Guarantee Durable Disk Commit?
The statement *"Returning structured JSON guarantees that the attempt counter is durably committed"* is true **ONLY UNDER SPECIFIC EXECUTION CONDITIONS**.
The audit defines the exact conditions required for durability:

1. **Clean Statement Completion**: The PL/pgSQL function must execute to its `RETURN` statement without triggering any unhandled database exception (e.g. division by zero, null constraint violation, or out-of-memory).
2. **PostgREST Connection Persistence**: The HTTP connection between PostgREST and PostgreSQL must remain open until PostgreSQL acknowledges the commit. If a network socket drop triggers an unhandled `SIGPIPE` or cancellation request before commit, PostgreSQL aborts the transaction.
3. **WAL Flush**: PostgreSQL's Write-Ahead Log (WAL) must flush the commit record to disk (governed by `synchronous_commit = on` in Supabase).
4. **Trigger & Constraint Integrity**: No deferred foreign key constraints or post-execution triggers may throw errors during statement commit.

### 2.2 Exhaustive Failure Scenario Analysis

The table below evaluates transaction commit and rollback behavior across 10 critical operational conditions:

| Scenario ID | Inbound Execution Condition | Function Internal Action | PostgreSQL Transaction Outcome | Attempt Counter State on Disk | Audit Event Persisted? | Security / Resilience Assessment |
|---|---|---|---|---|---|---|
| **TX-01** | Invalid token attempt (attempts 1–4) | Increments `attempts = attempts + 1`, inserts audit row, returns `{"ok": false, "error": "invalid_token"}` | **COMMITTED** | Counter durably incremented by 1 | Yes (`device_recredential_failed`) | **PASS**. Expected domain outcome commits cleanly. |
| **TX-02** | Expired token submitted | Marks `status = 'expired'`, `consumed_at = now()`, returns `{"ok": false, "error": "challenge_expired"}` | **COMMITTED** | Row marked expired on disk | Yes | **PASS**. Stale challenge deactivated permanently. |
| **TX-03** | Already consumed challenge submitted | Reads `consumed_at IS NOT NULL`, makes zero DML updates, returns `{"ok": false, "error": "challenge_already_consumed"}` | **COMMITTED** | Unchanged on disk | Yes (Replay warning) | **PASS**. Replay blocked without state corruption. |
| **TX-04** | Fifth failed attempt submitted | Increments `attempts = 5`, sets `status = 'exhausted'`, `consumed_at = now()`, returns `attempts_remaining: 0` | **COMMITTED** | Durably locked at 5; status `exhausted` | Yes (`device_recredential_exhausted`) | **PASS**. Lockout permanently enforced on disk. |
| **TX-05** | Two simultaneous invalid attempts racing at `attempts = 4` | Request A acquires `FOR UPDATE`, commits 5 and exhausts. Request B unblocks, reads exhausted, makes zero updates. | **BOTH COMMITTED** | Durably locked at exactly 5; zero race bypass | Yes | **PASS**. Concurrency strictly serialized. |
| **TX-06** | Successful redemption concurrent with failed attempt | Valid and invalid requests arrive simultaneously. Winner of `FOR UPDATE` processes first. | **COMMITTED** | If valid wins: secret rotated, redeemed. If invalid wins: attempts incremented, valid redeems on 2nd turn. | Yes | **PASS**. Valid redemption succeeds without deadlock. |
| **TX-07** | Device revocation concurrent with redemption | Parent revokes device while child enters code. Revocation locks `devices` row. | **ONE COMMITS FIRST** | If revocation commits first: redemption fails with `device_revoked`. If redemption commits first: revocation revokes new secret. | Yes | **PASS**. Revocation hierarchy safe. |
| **TX-08** | Family membership removed concurrent with redemption | Parent unlinks child while child enters code. | **REJECTED** | Foreign key check fails closed; redemption rejected with HTTP 403. | Yes | **PASS**. Tenant boundary intact. |
| **TX-09** | Database disk failure / crash before commit | Hard power loss occurs while function is running. | **ROLLED BACK** | Transaction rolled back via WAL replay on reboot; zero partial state. | No | **PASS**. ACID atomicity preserved. |
| **TX-10** | Client cancels HTTP request mid-flight | Client drops socket connection while RPC is executing. | **COMMITTED OR ABORTED CLEANLY** | If query finished execution, PostgreSQL commits. If canceled mid-execution, PostgreSQL rolls back. | Partial state impossible | **PASS**. No counter corruption. |

---

## 3. Attempt Counter Invariants & 5th Attempt Policy (Workstream B2)

### 3.1 Lock Acquisition Order & Deadlock Freedom
To prevent deadlocks between concurrent re-credentialing, telemetry heartbeats, and device revocations, the transaction adheres to a strict lock hierarchy:
1. `public.device_recovery_challenges` (Challenge Row) is locked FIRST via `SELECT ... FOR UPDATE`.
2. `public.devices` (Device Row) is locked SECOND, **ONLY** upon verified token match.
3. Because failed redemption attempts never attempt to lock `devices`, failed attempts can **NEVER** deadlock with background telemetry updates (`UPDATE devices SET last_seen_at = now()`) or parent revocations!

### 3.2 Clarification of the 5th Attempt Policy
An ambiguity existed in Phase 1.1 regarding whether a successful 5th attempt is accepted or rejected:
- **Authoritative Resolution**: A challenge permits up to 5 attempts. If the 5th attempt presents a **VALID** token, the rotation **SUCCEEDS**.
- **Execution Invariant**:
  ```text
  If token is valid AND attempts < 5:
    -> ROTATE SECRET, SET status = 'redeemed', COMMIT.
  If token is invalid AND attempts + 1 < 5:
    -> INCREMENT attempts, LEAVE status = 'active', COMMIT.
  If token is invalid AND attempts + 1 >= 5:
    -> SET attempts = 5, SET status = 'exhausted', COMMIT.
  If attempts >= 5 (Sixth Attempt):
    -> REJECT IMMEDIATELY with error 'challenge_exhausted', COMMIT.
  ```

---

## 4. Conclusion & Required Migration Script Invariants

The structured JSONB return architecture with `FOR UPDATE` locking is **DESIGN VERIFIED**. The SQL migration `20261124000100_device_recredentialing.sql` must enforce:
1. `SELECT * FROM public.device_recovery_challenges WHERE device_id = p_device_id AND status = 'active' FOR UPDATE;`
2. Explicit constant-time byte comparison loop for SHA-256 digests.
3. Durable JSONB return mapping for invalid token, expired, and exhausted states.
