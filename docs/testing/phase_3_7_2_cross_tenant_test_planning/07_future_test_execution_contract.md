# Phase 3.7.2 — Report 07: Future Cross-Tenant Test Execution Contract

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / TEST PLANNING / SOURCE REVIEW  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report establishes the binding **Test Execution Contract** for any future execution of the cross-tenant isolation test suite. 

The contract defines the exact request sequences, expected HTTP statuses, deterministic data payload assertions, sanitized telemetry capture standards, and security invariants that must govern execution.

$$\mathbf{Execution\ Contract\ Invariant} = \mathbf{ZERO\ RESIDUAL\ STATE\ -\ ZERO\ SENSITIVE\ LEAKAGE\ -\ STRICT\ FAIL-CLOSED}$$

---

## 2. Authentication Contract & Identity Verification

1. **Dual Independent Identities:**
   - Test requires two independently authenticated GoTrue identities: `User_A` and `User_B`.
   - Credentials must be generated in memory using secure cryptographic randomness and transmitted directly to Supabase Auth.
2. **Strict Redaction & Memory-Only Storage:**
   - Raw passwords, refresh tokens, access tokens, and `Authorization` headers must **never** be logged to console, written to scratch files, or committed to Git.
   - All reports must reference tokens abstractly: `Bearer <User_A_JWT>` and `Bearer <User_B_JWT>`.
3. **Pre-Invocation Token Identity Assertion:**
   - Before executing any scenario, the test harness must decode the unverified JWT payload and assert:
     $$\texttt{JWT\_A.sub} == \texttt{Expected\_User\_A\_UUID} \quad \wedge \quad \texttt{JWT\_B.sub} == \texttt{Expected\_User\_B\_UUID}$$

---

## 3. Test Request Sequence & Assertions

```mermaid
sequenceDiagram
    autonumber
    participant Harness as Test Harness
    participant EF as account Edge Function
    participant DB as Supabase DB (service_role)

    Note over Harness,DB: Baseline Isolation Probes
    Harness->>EF: 1. User A calls export (Own Token)
    EF->>DB: Query Family A & Child Rows A
    DB-->>EF: Family A rows (TENANT_A_ONLY)
    EF-->>Harness: 200 OK: strictly Family A, 0 Family B rows

    Harness->>EF: 2. User B calls export (Own Token)
    EF->>DB: Query Family B & Child Rows B
    DB-->>EF: Family B rows (TENANT_B_ONLY)
    EF-->>Harness: 200 OK: strictly Family B, 0 Family A rows

    Note over Harness,DB: Adversarial Cross-Tenant Probes
    Harness->>EF: 3. User A calls export with body {"family_id": Family_B}
    EF->>DB: Ignored body param; query caller memberships
    DB-->>EF: Family A rows only
    EF-->>Harness: 200 OK: strictly Family A, 0 Family B rows

    Harness->>EF: 4. User B calls retention_report with body {"family_id": Family_A}
    EF->>DB: Ignored body param; query caller memberships
    DB-->>EF: Family B settings only
    EF-->>Harness: 200 OK: strictly Family B, 0 Family A metrics
```

### 3.1 Detailed Request & Assertion Specifications

| Test Case | Actor | Action | Payload / Target | Expected HTTP | Data-Level Assertions & Boundary Invariants |
|---|---|---|---|:---:|---|
| **TC-01** | `User_A` | `export` | `{"action": "export"}` | **`200 OK`** | 1. `account.user_id == User_A_UUID`<br>2. `families[0].id == Family_A_UUID`<br>3. `devices[0].id == Device_A_UUID`<br>4. Child tables contain marker `TENANT_A_ONLY`<br>5. **Zero occurrences of marker `TENANT_B_ONLY`** |
| **TC-02** | `User_B` | `export` | `{"action": "export"}` | **`200 OK`** | 1. `account.user_id == User_B_UUID`<br>2. `families[0].id == Family_B_UUID`<br>3. `devices[0].id == Device_B_UUID`<br>4. Child tables contain marker `TENANT_B_ONLY`<br>5. **Zero occurrences of marker `TENANT_A_ONLY`** |
| **TC-03** | `User_A` | `export` (Adversarial) | `{"action": "export", "family_id": Family_B_UUID}` | **`200 OK`** | 1. Body parameter `family_id` is ignored<br>2. Returns strictly Family A data<br>3. **Zero Family B rows exposed** |
| **TC-04** | `User_B` | `export` (Adversarial) | `{"action": "export", "family_id": Family_A_UUID}` | **`200 OK`** | 1. Body parameter `family_id` is ignored<br>2. Returns strictly Family B data<br>3. **Zero Family A rows exposed** |
| **TC-05** | `User_A` | `retention_report` | `{"action": "retention_report"}` | **`200 OK`** | 1. `scope == "family"`<br>2. `families[0].family_id == Family_A_UUID`<br>3. Zero Family B settings or cutoffs returned |
| **TC-06** | `User_B` | `retention_report` | `{"action": "retention_report"}` | **`200 OK`** | 1. `scope == "family"`<br>2. `families[0].family_id == Family_B_UUID`<br>3. Zero Family A settings or cutoffs returned |
| **TC-07** | `User_A` | `retention_report` (Adversarial) | `{"action": "retention_report", "family_id": Family_B_UUID}` | **`200 OK`** | 1. Injected `family_id` ignored<br>2. Evaluates strictly Family A |
| **TC-08** | `Child_A` | `export` (Role Scope) | `{"action": "export"}` | **`200 OK`** | 1. `scope == "device"`<br>2. Returns only Device A rows tied to `child_user_id`<br>3. Zero parent audit logs returned |
| **TC-09** | `User_A` | `export` (Device Injection) | `{"action": "export", "device_id": Device_B_UUID}` | **`200 OK`** | 1. Injected `device_id` ignored<br>2. Returns strictly Device A |
| **TC-10** | `Stranger` | `export` (Empty Scope) | `{"action": "export"}` | **`200 OK`** | 1. `scope == "not_reported"`<br>2. `families: []`, `devices: []`<br>3. All child tables have `row_count: 0` |

---

## 4. Evidence Capture & Telemetry Standards

All future test executions must record evidence into a sanitized machine-readable telemetry file (`cross_tenant_results.json`):

```json
{
  "phase": "3.7.3",
  "correlation_id": "ct-isolation-YYYYMMDD-XXXX",
  "project_ref": "hhqgreaoqulmfwfwarhc",
  "status": "PASSED",
  "summary": {
    "total_probes": 10,
    "passed_probes": 10,
    "failed_probes": 0,
    "cross_tenant_leakage_detected": false
  },
  "test_cases": [
    {
      "id": "TC-01",
      "actor": "User_A",
      "action": "export",
      "http_status": 200,
      "authorized_family": "Family_A_UUID",
      "returned_families_count": 1,
      "tenant_a_markers_found": 16,
      "tenant_b_markers_found": 0,
      "isolation_verified": true
    }
  ]
}
```

**Prohibited Output:** Raw JSON bodies containing child table rows, database connection strings, or Auth tokens must **never** be stored.
