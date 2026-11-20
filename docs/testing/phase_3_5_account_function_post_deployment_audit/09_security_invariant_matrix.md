# Phase 3.5 — Report 09: Security Invariant Verification Matrix

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Security Invariants Evaluation

This matrix establishes the compliance status of the deployed `account` Edge Function against the twelve fundamental security invariants governing tenant isolation, privacy, and account lifecycles.

| # | Security Invariant Description | Status | Evidence & Implementation Reference |
|---|---|:---:|---|
| **INV-01** | **Caller Identity Bound to Verified JWT**<br>Caller identity (`userId`, `callerEmail`) is strictly derived from cryptographically validated JWT claims via GoTrue; client body parameters (`body.user_id`) are completely ignored. | **PASS** | `shared-auth.ts` lines 84–105 (`requireAuthUser`), `index.ts` line 467. Verified by `deletion_test.ts` (Test 13). |
| **INV-02** | **Cross-User & Cross-Tenant Isolation**<br>A caller cannot read, export, audit, or delete another user's account, family, or devices under any circumstance. | **PASS** | `index.ts` lines 255–267 (`exportAccount` filters `child_user_id = userId`), `deletion.ts` line 423. Verified by `deletion_test.ts` (Test 13). |
| **INV-03** | **Profile-Independent Deletion Retry Authorization**<br>Account deletion retry (`isRetry = profile === null`) is authorized via `requireAuthUser` without granting access to non-deletion actions (`export`, `retention_report`). | **PASS** | `shared-auth.ts` lines 84–105 & 111–143, `index.ts` lines 461–473. Verified by `deletion_test.ts` (Tests 3, 4, 8, 9). |
| **INV-04** | **Affirmative Multi-Factor Confirmation for Deletion**<br>Deletion strictly requires the exact word `"DELETE"` (case-sensitive) and explicit re-typing of the caller's confirmed email address. | **PASS** | `validation.ts` lines 8 & 36–66 (`validateDeleteAccountInput`). Verified by `validation_test.ts` and `deletion_test.ts` (Tests 6, 7). |
| **INV-05** | **Owner Deletion Blocked by Other Active Members**<br>A family owner cannot delete their account while other active members remain in any owned family (`otherActiveMembers > 0`). | **PASS** | `validation.ts` lines 95–116 (`findDeletionBlocker`), `deletion.ts` lines 467–498. Verified by `validation_test.ts` and `deletion_test.ts` (Test 12). |
| **INV-06** | **Owner Deletion Blocked by Active Monitored Devices**<br>A family owner cannot delete their account while active monitored devices remain in any owned family (`activeDevices > 0`). | **PASS** | `validation.ts` lines 107–115, `deletion.ts` lines 476–498. Verified by `validation_test.ts` and `deletion_test.ts` (Test 12). |
| **INV-07** | **Data Export Sanitization & Row Capping**<br>Exported data excludes secret hashes (`devices.secret_hash`), enforces paging (`EXPORT_PAGE_SIZE = 1,000`), and caps output at `EXPORT_ROW_CAP = 20,000` rows. | **PASS** | `index.ts` lines 41–46, 63–86 (`DEVICE_COLUMNS`), 93–119 (`fetchCapped`). Verified by `deletion_test.ts` (Test 15). |
| **INV-08** | **Retention Scope Partitioning (PRIV-01)**<br>Minors (children) receive only device-scoped counts; non-owner parents receive family counts with sweep totals redacted; unauthenticated/misaligned callers receive `not_reported`. | **PASS** | `retention.ts` lines 72–175 (`resolveRetentionScope`). Verified by `scope_test.ts` (17 tests passing). |
| **INV-09** | **Zero Destructive Retention Execution in Edge Function**<br>The Edge Function provides only read-only `retention_report`; `retention_cleanup` is intentionally omitted from the router to prevent on-demand mass deletion. | **PASS** | `index.ts` lines 460–476 (router omits cleanup), `retention.ts` (pure reporting functions). Verified by `handler_wiring_test.ts`. |
| **INV-10** | **Temporal Audit Trail Integrity**<br>Audit events are recorded in immutable chronological sequence: `account_deletion_requested` precedes relational deletion, and `account_deleted` only follows confirmed Auth removal. | **PASS** | `deletion.ts` lines 501–512, 558–568, 579–591. Verified by `deletion_test.ts` (Test 14). |
| **INV-11** | **Information Disclosure Prevention in HTTP Responses**<br>Errors returned to clients use sanitized error codes and generic messages; internal SQL errors, stack traces, and GoTrue details are never leaked. | **PASS** | `shared-envelope.ts` lines 58–84 (`errorResponse`), `shared-auth.ts` lines 91–101. Verified by live smoke tests (Phase 3.4.7). |
| **INV-12** | **Idempotent & Concurrency-Safe Deletion**<br>Subsequent or concurrent duplicate deletion requests handle `404 user_not_found` gracefully and return consistent `{ deleted: true, retry: true }` responses. | **PASS** | `deletion.ts` lines 546–576. Verified by `deletion_test.ts` (Tests 10, 11). |

---

## 2. Invariant Compliance Verdict

$$\mathbf{12\ of\ 12\ Invariants\ Verified\ PASS\ (100\%)\ -\ ZERO\ DEFECTS}$$

All twelve security invariants are fully implemented in the production codebase and rigorously backed by automated offline regression suites.
