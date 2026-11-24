# 02 — In-Depth Audit of REV-001 & REV-002: Transactions, Concurrency & KeyStore Crash Recovery

**Document ID:** HAVEN-AUD-002  
**Target Workstream:** HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Target Findings:** REV-001 (CRITICAL — PL/pgSQL Attempt Counter Rollback Bug), REV-002 (CRITICAL — Lost Response / KeyStore Deadlock)  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Protocol Audit Summary

`HAVEN-QA-003` is the highest-risk architectural workstream in the HAVEN remediation portfolio. Phase 1.1 identified two critical vulnerabilities:
1. `REV-001`: In the PL/pgSQL function `rotate_device_secret`, `RAISE EXCEPTION` aborted the transaction, rolling back the attempt counter increment and rendering the system vulnerable to brute-force attacks.
2. `REV-002`: If a network drop or process crash occurred after database commit but before the client processed HTTP 200, the server held new credentials while the client reverted to old credentials (or could not retry because the challenge was consumed), bricking the device permanently.

Phase 1.2 introduced structured JSON returns with `SELECT ... FOR UPDATE` row locking for `REV-001`, and a native two-phase pre-staging state machine with idempotent server verification (`verify_device_rotation`) for `REV-002`.

---

## 2. In-Depth Audit of REV-001: The 15 Mandatory Transaction & Concurrency Questions

### Q1: What was the exact root cause of the attempt counter rollback flaw in Phase 1?
**Citation:** `03_credential_lifecycle_remediation_design.md:120-127`
```sql
if v_challenge.challenge_hash <> v_token_hash then
  update public.device_recovery_challenges set attempts = attempts + 1 where id = v_challenge.id;
  raise exception 'Invalid re-credentialing challenge token.' using errcode = 'P0005';
end if;
```
**Auditor Analysis:** In PostgreSQL, transactions are strictly atomic blocks of execution. When a PL/pgSQL function encounters an unhandled `RAISE EXCEPTION`, the PostgreSQL transaction manager marks the entire transaction block as aborted. All uncommitted DML writes executed prior to that exception—including the `UPDATE` statement incrementing `attempts = attempts + 1`—are discarded and rolled back in WAL. As a consequence, `attempts` remained permanently at `0`, completely bypassing the `attempts >= max_attempts` lockout guard.

### Q2: Why does `RAISE EXCEPTION` abort uncommitted DML statements, and why could subtransactions/savepoints not resolve this safely?
**Auditor Analysis:** PostgreSQL handles exceptions by unwinding the call stack and reverting to the last transaction boundary. While PL/pgSQL allows `BEGIN ... EXCEPTION ... END` subtransactions (which create internal savepoints), catching and re-raising an exception still triggers an outer rollback if propagated to PostgREST. Catching without re-raising within the same transaction creates complex exception-handling overhead and does not cleanly return structured error state to Edge Functions.

### Q3: How does Approach A (Structured Return Value: `jsonb` with `ok: false`) solve this problem?
**Auditor Analysis:** Approach A treats authentication verification failure as an *expected domain outcome* rather than a *fatal database exception*. By concluding execution with a structured JSON payload:
```sql
RETURN jsonb_build_object(
  'ok', false,
  'error', 'invalid_token',
  'attempts_remaining', v_challenge.max_attempts - v_new_attempts
);
```
the function exits normally. PostgreSQL executes a standard transaction `COMMIT`, ensuring that the incremented attempt count and any state transitions (e.g., `'exhausted'`) are durably written to the table heap and WAL.

### Q4: Does returning a structured `jsonb` allow the PostgreSQL transaction to commit successfully to disk?
**Auditor Analysis:** **YES.** Because no unhandled exception aborts the executor, the transaction completes with status `COMMITTED`. The incremented `attempts` value is written to disk and visible to all subsequent database queries.

### Q5: How is `READ COMMITTED` transaction isolation affected by explicit row locking (`SELECT ... FOR UPDATE`) on `device_recovery_challenges`?
**Auditor Analysis:** Under default `READ COMMITTED` isolation, concurrent transactions see snapshots taken at query start. However, when `SELECT ... FOR UPDATE` is executed:
1. PostgreSQL acquires an exclusive tuple-level lock (`ExclusiveLock` / `ForUpdate`) on the challenge row.
2. Any concurrent transaction attempting to read that same challenge row with `FOR UPDATE` is immediately suspended and placed in a wait queue.
3. Once the active transaction commits, the suspended transaction awakens, re-reads the *newly committed* tuple version, and evaluates its logic against the updated `attempts` count.

### Q6: How does `FOR UPDATE` serialize concurrent requests attempting to redeem the same challenge?
**Auditor Analysis:** If Request 1 and Request 2 arrive at the database simultaneously:
- Request 1 locks the challenge tuple.
- Request 2 blocks.
- Request 1 processes token evaluation, increments `attempts = attempts + 1`, and commits.
- Request 2 awakens, re-reads the row, observes the incremented attempt count, and processes sequentially.
Zero lost updates or race conditions occur.

### Q7: What happens when two concurrent transactions attempt redemption when `attempts = 4`?
**Auditor Analysis:**
1. Initial State: `attempts = 4`, `max_attempts = 5`, `status = 'active'`.
2. Simultaneous Inbound: Request A and Request B both submit invalid tokens.
3. Lock Arbitration: Request A acquires the tuple lock; Request B suspends.
4. Request A Processing: Reads `attempts = 4`. Increments `attempts = 5`. Because `5 >= 5`, updates `status = 'exhausted'` and `consumed_at = now()`. Inserts `device_recredential_exhausted` audit event. Returns `ok: false, attempts_remaining: 0` and **COMMITS**.
5. Request B Unblocks: Awakens, re-reads committed tuple. Reads `attempts = 5` and `status = 'exhausted'`.
6. Request B Guard: Detects `status = 'exhausted'`, makes zero updates, returns `ok: false, error: 'challenge_exhausted', attempts_remaining: 0` and commits.
7. Verification: Exactly 5 attempts were consumed; the challenge is locked; zero bypass occurred.

### Q8: Can an attacker exploit concurrency or race conditions to exceed `max_attempts = 5`?
**Auditor Analysis:** **MATHEMATICALLY AND TRANSACTIONALLY IMPOSSIBLE.** Because every redemption transaction begins with `SELECT ... FOR UPDATE` on the challenge tuple, all attempts are strictly serialized in single-file order. Every attempt increments the counter and commits before any subsequent transaction can evaluate the threshold.

### Q9: Does the transaction lock the `devices` row as well, and in what order?
**Auditor Analysis:** **YES.** On a verified token match, `rotate_device_secret` executes `SELECT * FROM public.devices WHERE id = p_device_id AND status = 'active' FOR UPDATE;`.
- **Lock Ordering**:
  1. `device_recovery_challenges` (Challenge Row) is locked FIRST.
  2. `devices` (Device Row) is locked SECOND (only upon verified token match).
- **Deadlock Freedom**: On failed attempts, the `devices` row is never locked, preventing lock contention with background telemetry. Because all mutating RPCs follow this exact lock hierarchy, no distributed deadlock cycles can form.

### Q10: How are system-level/infrastructure exceptions distinguished from domain-level authentication failures?
**Auditor Analysis:**
- **Domain Authentication Outcomes (Committed)**: Invalid tokens, expired challenges, exhausted attempts, and non-matching installation IDs return `{ ok: false, error: ... }`. Transactions commit cleanly to record attempt counts and audit events.
- **System Exceptions (Rolled Back)**: Relational constraint violations, disk full errors, or network socket drops raise native PostgreSQL exceptions, causing immediate rollback to preserve relational integrity.

### Q11: When does the challenge status transition to `'exhausted'` and `'consumed_at = now()'`?
**Auditor Analysis:** Inside the transaction, whenever an invalid token causes `attempts + 1 >= max_attempts`, or when an attempt arrives against a challenge already at `attempts >= max_attempts`. `status` is set to `'exhausted'` and `consumed_at` is set to `clock_timestamp()`.

### Q12: Is the timing of hash verification vulnerable to side-channel timing attacks?
**Auditor Analysis:** **NO.** The function compares fixed-length 64-character SHA-256 hexadecimal digests (`v_challenge.challenge_hash = v_token_hash`). Operating on uniform-length cryptographic digests completely neutralizes string-length timing leaks. Furthermore, network latency (~15–50 ms) completely eclipses nanosecond-level byte comparison jitter.

### Q13: How are error messages and status codes structured to avoid information leakage?
**Auditor Analysis:**
- Incorrect token format, invalid characters, and non-matching hashes all return an identical domain error: `"invalid_token"`.
- Missing challenges return `"challenge_not_found"` (mapped to HTTP 404).
- Calling user mismatch returns `"unauthorized"` (mapped to HTTP 403).
- Zero details regarding the expected token, stored hash, or internal attempt counts are leaked.

### Q14: What privileges and execution security context are applied to `rotate_device_secret`?
**Auditor Analysis:**
1. `SECURITY DEFINER`: Runs with database owner privileges to update `devices` and `device_recovery_challenges`.
2. Hardened `search_path`: Strictly set to `SET search_path = public, pg_temp;` to prevent search-path hijacking attacks.
3. Privilege Revocation: `REVOKE ALL ON FUNCTION public.rotate_device_secret FROM public, anon, authenticated;` followed by `GRANT EXECUTE ON FUNCTION public.rotate_device_secret TO service_role;`. Direct client access over PostgREST is blocked; only verified Edge Functions can invoke it.

### Q15: How does the 6-test verification matrix (`TEST-REV001-01` through `TEST-REV001-06`) validate the transaction semantics?
**Auditor Analysis:** The test matrix covers all transaction paths: single failed attempt persistence, sequential increment tracking, 5th attempt lockout trigger, post-exhaustion rejection, parallel concurrency serialization, and 5th-attempt success handling.

**REV-001 Official Status:** **VERIFIED CLOSED BY DESIGN**

---

## 3. In-Depth Audit of REV-002: Client KeyStore Crash Recovery & Failure Boundaries

### 3.1 Trace of All 15 Mandatory Crash Points

| Crash Point | Injected Failure Event | Local Storage State | Server DB State | Relaunch / Recovery Action | Safety Invariant |
|---|---|---|---|---|---|
| **CP-01** | User enters code, app crashes before candidate key generation. | Active keys intact. Staging empty. | Challenge `active`. | App restarts idle; active keys continue telemetry; user re-enters code. | Zero state corruption. |
| **CP-02** | Hardware KeyStore throws exception during candidate key generation. | Active keys intact. Staging empty. | Challenge `active`. | Handled via try-catch in `SecureStore.kt`; rotation aborted; user notified. | Active credentials protected. |
| **CP-03** | Crash during write to `EncryptedSharedPreferences` for staging keys. | Active keys intact. Staging partial. | Challenge `active`. | App detects corrupted staging slot on boot; wipes staging; falls back to active keys. | Atomic file write protects active keys. |
| **CP-04** | Crash after staging keys persisted, before HTTP dispatch. | Staged keys valid (`rotation_state = 'NEW_CREDENTIAL_STAGED'`). Active intact. | Challenge `active`. | On reboot, app detects staged keys $\rightarrow$ calls `verify_device_rotation` $\rightarrow$ server reports unrotated $\rightarrow$ client dispatches redemption. | Self-healing dispatch. |
| **CP-05** | Radio disconnects during HTTP transit to `/device-register`. | Staging keys intact. Active intact. | Challenge `active`. Server never received request. | Client times out $\rightarrow$ calls `verify_device_rotation` $\rightarrow$ unrotated confirmed $\rightarrow$ client retries redemption. | Telemetry continues on active secret. |
| **CP-06** | Edge Function crashes before invoking `rotate_device_secret`. | Staging keys intact. Active intact. | Challenge `active`. Zero DB writes. | Client times out $\rightarrow$ `verify_device_rotation` reports unrotated $\rightarrow$ client retries cleanly. | Zero database mutation. |
| **CP-07** | PostgreSQL transaction aborts/rolls back mid-RPC. | Staging keys intact. Active intact. | Challenge `active`. Zero DB writes. | RPC returns failure $\rightarrow$ client queries verification $\rightarrow$ retries cleanly. | Relational atomicity preserved. |
| **CP-08** | DB commits rotation, Edge Function crashes before sending HTTP 200. | Staging keys intact. Active intact. | `devices.secret_hash = new_hash`. Challenge `redeemed`. | App times out $\rightarrow$ invokes `verify_device_rotation` $\rightarrow$ DB confirms hash match $\rightarrow$ client promotes candidate keys! | **Deadlock Broken!** |
| **CP-09** | HTTP 200 lost in transit (The Classic "Lost Response" Trap). | Staging keys intact. Active intact. | `devices.secret_hash = new_hash`. Challenge `redeemed`. | Next heartbeat or launch detects staged keys $\rightarrow$ calls `verify_device_rotation` $\rightarrow$ server reports `confirmed: true` $\rightarrow$ keys promoted. | **Deadlock Broken!** |
| **CP-10** | HTTP 200 received by OS socket, but app killed by Android OOM before promotion. | Staging keys intact. Active intact. | DB has new credentials; challenge redeemed. | On restart, controller sees staged keys $\rightarrow$ calls `verify_device_rotation` $\rightarrow$ receives `confirmed: true` $\rightarrow$ promotes keys. | Immune to Android OOM killer. |
| **CP-11** | Crash during promotion in `SecureStore.kt` (active updated, staging not purged). | Active keys updated to candidate. Staging still present. | DB has new credentials. | On restart, client detects active keys already match staged keys $\rightarrow$ purges staging $\rightarrow$ resumes telemetry. | Idempotent cleanup. |
| **CP-12** | Sudden battery pull / power loss immediately after promotion. | Active keys updated. Staging purged. | DB has new credentials. | Power on $\rightarrow$ `GuardianService` boots with new active keys $\rightarrow$ heartbeat 200 OK. | System in stable new state. |
| **CP-13** | Handset remains offline for > 10 min (TTL expires) while staged. | Staging keys intact. Active intact. | Challenge `expired`. DB unrotated. | Handset comes online $\rightarrow$ `verify_device_rotation` reports `retry_allowed: false` $\rightarrow$ staging purged. | User prompted for fresh challenge. |
| **CP-14** | Child user clears app storage / uninstalls while staged. | App sandbox wiped by OS. | DB rotated or unrotated. | Reinstalled app starts fresh in unconfirmed state; prompts parent for recovery. | OS sandbox deletion is clean. |
| **CP-15** | Rapid successive device reboots while staged. | Staging keys intact. Active intact. | Unaffected by client reboots. | Each boot checks state; does not thrash or discard until verification succeeds or TTL expires. | Stable state invariants hold. |

### 3.2 Formal 3-Way Protocol Distinction

```
┌────────────────────────────────────────────────────────────────────────┐
│                   THE THREE-WAY PROTOCOL DISTINCTION                   │
├────────────────────────────────────────────────────────────────────────┤
│ (1) RETRY-SAFE VERIFICATION (`verify_device_rotation`)                 │
│     • Read-only query comparing devices.secret_hash == candidate_hash   │
│     • Strictly idempotent; zero mutations; consumes zero attempts      │
├────────────────────────────────────────────────────────────────────────┤
│ (2) STATEFUL ATOMIC ROTATION (`redeem_recredential_challenge`)         │
│     • Mutating, compare-and-swap transaction with FOR UPDATE row lock   │
│     • Bounded to 5 attempts; consumes challenge token atomically       │
├────────────────────────────────────────────────────────────────────────┤
│ (3) LOST HTTP RESPONSE RESOLUTION (The Deadlock Breaker)               │
│     • Reconciles server committed state with client staged keys        │
│     • Safe key promotion without token re-submission or credential leak│
└────────────────────────────────────────────────────────────────────────┘
```

**REV-002 Official Status:** **VERIFIED CLOSED BY DESIGN**
