# Phase 1.5: KeyStore Crash-Recovery Assessment

**Document ID:** `HAVEN-AUD-006-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Native Android State Machine & Crash Resilience Assessment  

---

## 1. Executive Summary

This assessment independently evaluates the native Android KeyStore crash-recovery claims and the formal 7-state protocol proposed for `HAVEN-QA-003` (`SecureStore.kt`). It examines why filesystem-level atomic writes (`editor.commit()`) do not independently guarantee end-to-end crash safety, validates the 7-state lifecycle, and audits all 15 failure/crash points across the client-server boundary.

### Mandatory Assessment Verdict:
```
==================================================================================================
                 DESIGN VERIFIED (REQUIRES RUNTIME CRASH TESTING)
==================================================================================================
```

---

## 2. The Limits of `SharedPreferences.Editor.commit()`

Phase 1.4 noted that `SecureStore.kt` relies on `EncryptedSharedPreferences.edit().commit()` to achieve atomic writes. While `commit()` writes synchronously to disk (replacing the underlying XML via atomic file rename), it is vital to distinguish:
1. **Local Storage Atomicity**: Prevents partially written XML files or half-written strings if the OS process is killed mid-write.
2. **Distributed Protocol Atomicity**: Cannot guarantee that client state matches server state if the crash occurs *after* the local write but *before* the server response is processed (or vice versa).

End-to-end recovery safety requires an explicit, multi-state transition machine that can reconcile ambiguous states upon process restart.

---

## 3. Formal Seven-State KeyStore Transition Machine

```
                      +-------------------+
                      |    STABLE_OLD     | <---+ (Unpairing / Purge)
                      +-------------------+     |
                                |               |
                     (Candidate Keys Staged)    |
                                |               |
                                v               |
                  +---------------------------+ |
                  |   NEW_CREDENTIAL_STAGED   | |
                  +---------------------------+ |
                                |               |
                      (HTTP Request In Flight)  |
                                |               |
                                v               |
                 +-----------------------------+|
                 |   SERVER_ROTATION_UNKNOWN   ||
                 +-----------------------------+|
                     |                      |   |
         (HTTP 200 Received)       (Timeout/Crash)
                     |                      |   |
                     v                      v   |
        +--------------------------+ +---------------------+
        | SERVER_ROTATION_CONFIRMED| |  RECOVERY_REQUIRED  |
        +--------------------------+ +---------------------+
                     |                          |
             (Keys Promoted)           (Query verify_rotation)
                     |                   /                 \
                     v           (Confirmed: true)     (Confirmed: false)
        +--------------------------+     |                     |
        |  STABLE_NEW_CREDENTIAL   |<----+                     v
        +--------------------------+                 +-------------------+
                                                     |  RECOVERY_FAILED  |
                                                     +-------------------+
```

### 3.1 State Definitions, Entry & Exit Conditions

| State ID | State Name | Persisted Storage Signature | Entry Condition | Exit Condition & Transition |
|---|---|---|---|---|
| **S-01** | `STABLE_OLD` | `device_secret` present.<br/>`candidate_secret` absent. | App enrolled and operating normally. | User/Parent initiates re-credentialing $\to$ Transitions to `S-02`. |
| **S-02** | `NEW_CREDENTIAL_STAGED` | `device_secret` present.<br/>`candidate_secret` present.<br/>`staging_status = 'staged'`. | Candidate keys generated and written via atomic `editor.commit()`. | Network request dispatched $\to$ Transitions to `S-03`. |
| **S-03** | `SERVER_ROTATION_UNKNOWN` | Staged keys present.<br/>`staging_status = 'in_flight'`. | `POST /device-register` dispatched over HTTPS. | HTTP 200 received $\to$ `S-04`.<br/>Network error/crash $\to$ `S-06`. |
| **S-04** | `SERVER_ROTATION_CONFIRMED` | Staged keys present.<br/>`staging_status = 'confirmed'`. | HTTP 200 received from server or confirmed via `verify_device_rotation`. | Local promotion executed $\to$ Transitions to `S-05`. |
| **S-05** | `STABLE_NEW_CREDENTIAL` | `device_secret` updated to candidate.<br/>`candidate_secret` purged. | Staged keys promoted to primary; staging slot deleted in atomic write. | Baseline state restored. Telemetry resumes with new secret. |
| **S-06** | `RECOVERY_REQUIRED` | Staged keys present.<br/>`staging_status = 'in_flight'`. | App restarts following network drop, timeout, or crash. | `verify_device_rotation` returns confirmed $\to$ `S-05`.<br/>Returns false/expired $\to$ `S-07`. |
| **S-07** | `RECOVERY_FAILED` | Staged keys purged.<br/>`device_secret` unchanged. | Server confirms challenge expired or rotation was not committed. | UI prompts parent for fresh recovery challenge $\to$ `S-01`. |

---

## 4. Comprehensive Audit of the 15 Crash Points (CP-01 Through CP-15)

The table below audits all 15 failure and crash points identified across the lifecycle:

| Crash ID | Exact Operation Immediately Prior to Crash | Persisted Local State | Persisted Server State | App Restart Behavior | Recovery Action | Security Consequence | Verification Status |
|---|---|---|---|---|---|---|---|
| **CP-01** | Pre-KeyGen crash (Memory exhaustion / OOM) | `STABLE_OLD` | Challenge Active | Clean boot; `STABLE_OLD` active | Normal telemetry continues; parent can retry challenge | Zero credential desync | **DESIGN VERIFIED** |
| **CP-02** | Android KeyStore provider crypto exception | `STABLE_OLD` | Challenge Active | Catches exception; rolls back candidate keys | Logs error; informs user; retains old secret | Zero credential desync | **DESIGN VERIFIED** |
| **CP-03** | Process termination during staging write | `STABLE_OLD` | Challenge Active | `editor.commit()` ensures write succeeds or is untouched | Clean rollback or resumes staging | Zero file corruption | **DESIGN VERIFIED** |
| **CP-04** | Crash post-staging, prior to HTTP dispatch | `NEW_CREDENTIAL_STAGED` | Challenge Active | Detects staged keys on boot | Retries HTTP dispatch with existing staged keys | Reuses same candidate hash | **DESIGN VERIFIED** |
| **CP-05** | Cellular radio drops during HTTP transmission | `SERVER_ROTATION_UNKNOWN` | Challenge Active (Untouched) | Detects in-flight staging; transitions to `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `confirmed: false`; retries redemption | Zero key corruption | **DESIGN VERIFIED** |
| **CP-06** | Deno Edge isolate crashes prior to DB RPC | `SERVER_ROTATION_UNKNOWN` | Challenge Active (Untouched) | HTTP 500 received or timeout; enters `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `confirmed: false`; retries redemption | Safe retry | **DESIGN VERIFIED** |
| **CP-07** | PostgreSQL transaction rolls back (Invalid Token) | `SERVER_ROTATION_UNKNOWN` | Attempt counter incremented; status active/exhausted | HTTP 400 received; enters `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives remaining attempts; prompts user | Attempts tracked in DB | **DESIGN VERIFIED** |
| **CP-08** | PostgreSQL commits; Edge Function crashes post-commit | `SERVER_ROTATION_UNKNOWN` | **DB Rotated to Candidate Hash** | Timeout received; enters `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `confirmed: true`; promotes staged key | **Resolves lost-response deadlock** | **DESIGN VERIFIED** |
| **CP-09** | HTTP 200 dropped by mobile carrier tower handover | `SERVER_ROTATION_UNKNOWN` | **DB Rotated to Candidate Hash** | Timeout received; enters `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `confirmed: true`; promotes staged key | **Resolves lost-response deadlock** | **DESIGN VERIFIED** |
| **CP-10** | Android OS kills app process immediately on receiving 200 | `SERVER_ROTATION_UNKNOWN` | **DB Rotated to Candidate Hash** | Next app launch enters `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `confirmed: true`; promotes staged key | Telemetry resumes seamlessly | **DESIGN VERIFIED** |
| **CP-11** | Crash mid-promotion write in SharedPreferences | `SERVER_ROTATION_CONFIRMED` | **DB Rotated to Candidate Hash** | Single atomic `.commit()` ensures promotion succeeds completely or rolls back | If rollback, restarts into `RECOVERY_REQUIRED`; re-confirms via verify endpoint | Zero half-promoted state | **DESIGN VERIFIED** |
| **CP-12** | Handset battery dies immediately post-promotion | `STABLE_NEW_CREDENTIAL` | **DB Rotated to Candidate Hash** | Powers on into `STABLE_NEW_CREDENTIAL` | Normal telemetry resumes with new secret | Perfect alignment | **DESIGN VERIFIED** |
| **CP-13** | Handset remains offline for 24h post-staging | `NEW_CREDENTIAL_STAGED` | Challenge Expired | Boots into `RECOVERY_REQUIRED` | Calls `verify_device_rotation`; receives `expired`; purges staging; transitions to `RECOVERY_FAILED` | Safe terminal state | **DESIGN VERIFIED** |
| **CP-14** | User clears app data via Android Settings | Storage Wiped | Server retains last hash | Boots into fresh enrollment flow | Unlinked child must complete pairing | Standard Android behavior | **DESIGN VERIFIED** |
| **CP-15** | Rapid boot loops during background worker init | Handled by Android OS | Untouched | `START_NOT_STICKY` or safe exception handling prevents OS loop | Recovers on stable boot | Safe failure mode | **DESIGN VERIFIED** |

---

## 5. Conclusion & Runtime Verification Requirements

The 7-state KeyStore transition model is **THEORETICALLY COMPLETE AND RESILIENT**. All 15 crash points have concrete, deterministic recovery paths.

However, in accordance with strict evidentiary standards:
- **Current Status**: **DESIGN VERIFIED (REQUIRES RUNTIME CRASH TESTING)**.
- **Mandatory Gate 6 Requirement**: Before production release (Gate 7), automated fault injection tests in a staging Robolectric/container harness must physically simulate:
  1. Process SIGKILL immediately following database commit (CP-08/09).
  2. Cellular network timeout simulation during redemption.
  3. Power-loss restart with staged keys present.
