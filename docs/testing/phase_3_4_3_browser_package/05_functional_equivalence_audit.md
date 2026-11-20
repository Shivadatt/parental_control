# Phase 3.4.3 — Report 05: Functional Equivalence & Security Invariance Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account`  
**Standard:** Rigorous Equivalence Evaluation across Security, Lifecycle, and Permissions  

---

## 1. Functional Equivalence Verification Matrix

| Capability / Security Boundary | Requirement in Original Source | Observed Implementation in Staged Package | Status |
| :--- | :--- | :--- | :---: |
| **`requireAuthUser()` Behavior** | Validates JWT cryptographically via `db.auth.getUser()`; succeeds even when `profiles` row is absent. | Strictly unchanged in `shared-auth.ts:168`; identical function body and error contracts. | **EQUIVALENT** |
| **`requireUser()` Behavior** | Enforces both valid JWT AND existing `profiles` row; throws `403 profile_missing` if profile is absent. | Strictly unchanged in `shared-auth.ts:205`; identical function body and error contracts. | **EQUIVALENT** |
| **Missing-Profile Deletion Retry** | Bypasses `requireUser()` for `delete_account` / `delete`; resumes deletion idempotently. | Strictly preserved in `deletion.ts:316`; executes GoTrue Admin deletion and skip logic. | **EQUIVALENT** |
| **Normal Operations Defense** | `export` and `retention_report` reject callers with missing profiles with HTTP 403. | Strictly preserved in `deletion.ts:107` and `index.ts:57`. | **EQUIVALENT** |
| **Single-Phase Audit Emission** | `account_deleted` is recorded ONLY after GoTrue Auth returns successful deletion. | Strictly preserved in `deletion.ts:400`; audit emitted only upon verified removal. | **EQUIVALENT** |
| **Failed Deletion Audit** | If GoTrue fails, records `account_deletion_failed` with `actor_user_id = null`. | Strictly preserved in `deletion.ts:384`; error logged and envelope returned. | **EQUIVALENT** |
| **Sensitive Field Exclusion** | `DEVICE_COLUMNS` strictly omits `secret_hash` and `credential_revoked_at`. | Strictly identical in `deletion.ts:59`; zero device credential leakage possible. | **EQUIVALENT** |
| **Retention Read-Only Boundary** | `retention_report` executes read-only count queries; never executes cleanup. | Strictly preserved in `index.ts:119` and `retention.ts:161`. | **EQUIVALENT** |
| **Payload Validation** | Rejects non-string email, casing mismatches, and invalid confirmation tokens. | Strictly preserved in `validation.ts:43`. | **EQUIVALENT** |
| **CORS Policy & Preflight** | Responds to `OPTIONS` with standard headers and `204 No Content`. | Strictly preserved in `shared-cors.ts:6`. | **EQUIVALENT** |

---

## 2. Invariance Proof

Because:
1. Every modified line in the staged package is exclusively an ES module `import` statement targeting a flat sibling file.
2. Zero function signatures, arguments, conditions, database queries, HTTP statuses, or return payloads were touched.
3. Every test that verified Phase 3.3 behavior was re-run against the staged package and achieved an identical pass rate.

**Conclusion:** The staged flat-root package is mathematically and functionally equivalent to the original nested package.
