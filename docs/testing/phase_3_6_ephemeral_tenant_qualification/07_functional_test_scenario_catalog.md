# Phase 3.6 — Report 07: Functional Test Scenario Catalog & Execution Specifications

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account` (`https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`)  
**Audit Date:** 2026-11-20  

---

## 1. Scenario Catalog Overview

This catalog defines the precise functional test cases proposed for future authenticated qualification in production, following owner authorization. Every test case specifies its preconditions, inputs, expected database state transitions, expected audit events, isolation boundaries, and risk tier.

---

## 2. Test Scenarios Matrix

### TC-EXP-01: Authenticated Account Export
- **Test ID:** `TC-EXP-01`
- **Required Entities:** Ephemeral Parent user (`ephemeral-parent-<RUN_ID>@internal-test.local`) with active profile and ephemeral family.
- **Preconditions:** Parent has authenticated JWT; Stage 2 isolation qualification PASSED.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "export" }`.
- **Expected Response:** HTTP `200 OK`; headers include `Content-Disposition: attachment; filename="parent-control-export-..."`; JSON body contains `scope: "family"`, caller's account details, profile, family, and empty telemetry arrays.
- **Expected Database Changes:** Zero database rows modified.
- **Expected Audit Events:** Zero audit rows written (export is read-only).
- **Isolation Guarantee:** Query filter enforces `family_id IN (ephemeral_family_id)`; zero access to external families.
- **Cleanup Procedure:** Test user cleaned up during Stage 4.
- **Risk Classification:** **Category B (Low Risk / Read-Only)**.

### TC-EXP-02: Export Pagination and Safety Row Limits
- **Test ID:** `TC-EXP-02`
- **Required Entities:** Ephemeral Parent user; ephemeral family with mock location rows.
- **Preconditions:** Paging logic evaluated against `EXPORT_ROW_CAP = 20,000` and `EXPORT_PAGE_SIZE = 1,000`.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "export" }`.
- **Expected Response:** Streamed JSON contains `limits: { max_rows_per_table: 20000 }` and correctly chunked rows.
- **Expected Database Changes:** Zero database rows modified.
- **Expected Audit Events:** Zero.
- **Isolation Guarantee:** `fetchCapped` bounds query strictly to caller's `family_id`.
- **Risk Classification:** **Category B (Low Risk / Read-Only)**.

### TC-EXP-03: Export Secret Material Sanitization
- **Test ID:** `TC-EXP-03`
- **Required Entities:** Ephemeral Parent user; ephemeral family with registered device.
- **Preconditions:** Device has non-null `secret_hash` in `devices`.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "export" }`.
- **Expected Response:** Export payload lists device under `devices`, but `secret_hash` and credential secrets are **100% absent** from JSON keys.
- **Expected Database Changes:** Zero.
- **Expected Audit Events:** Zero.
- **Isolation Guarantee:** Projection uses explicit whitelist `DEVICE_COLUMNS` omitting credentials.
- **Risk Classification:** **Category B (Low Risk / Read-Only)**.

### TC-DEL-01: Deletion Confirmation & Case Sensitivity Validation
- **Test ID:** `TC-DEL-01`
- **Required Entities:** Ephemeral Parent user.
- **Preconditions:** Caller authenticated.
- **Request Action:**  
  1. Test 1A: `{ "action": "delete", "confirm": "delete", "email": "caller@internal-test.local" }` (lowercase).  
  2. Test 1B: `{ "action": "delete", "confirm": "DELETE", "email": "wrong@internal-test.local" }` (mismatched email).
- **Expected Response:**  
  1. Test 1A: HTTP `400 Bad Request` (`confirmation_required`).  
  2. Test 1B: HTTP `400 Bad Request` (`email_mismatch`).
- **Expected Database Changes:** Zero rows deleted.
- **Expected Audit Events:** Zero.
- **Isolation Guarantee:** Refused before database read/write.
- **Risk Classification:** **Category B (Low Risk / Pre-Flight Rejection)**.

### TC-DEL-02: Owner Deletion Blocker — Active Family Members
- **Test ID:** `TC-DEL-02`
- **Required Entities:** Ephemeral Parent (Owner) + Ephemeral Child linked as active member in family.
- **Preconditions:** Family has active member where `user_id <> caller.user.id`.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "delete", "confirm": "DELETE", "email": "caller@internal-test.local" }`.
- **Expected Response:** HTTP `409 Conflict` (`account_deletion_blocked`, `blocked_reason: "owned_family_has_other_members"`).
- **Expected Database Changes:** Zero rows deleted; family and profile remain active.
- **Expected Audit Events:** Zero.
- **Isolation Guarantee:** Blocked by `findDeletionBlocker`.
- **Risk Classification:** **Category B (Low Risk / Blocker Guardrail)**.

### TC-DEL-03: Owner Deletion Blocker — Active Monitored Devices
- **Test ID:** `TC-DEL-03`
- **Required Entities:** Ephemeral Parent (Owner) + Ephemeral family with active device.
- **Preconditions:** Family has 0 other members, but 1 active device (`status = 'active'`).
- **Request Action:** `POST /functions/v1/account` with valid confirmation.
- **Expected Response:** HTTP `409 Conflict` (`account_deletion_blocked`, `blocked_reason: "owned_family_has_active_devices"`).
- **Expected Database Changes:** Zero rows deleted.
- **Expected Audit Events:** Zero.
- **Risk Classification:** **Category B (Low Risk / Blocker Guardrail)**.

### TC-DEL-04: Successful End-to-End Account Deletion Cascade
- **Test ID:** `TC-DEL-04`
- **Required Entities:** Ephemeral Parent (Owner) with empty family (zero other members, zero active devices).
- **Preconditions:** Valid confirmation word and email; caller is sole member.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "delete", "confirm": "DELETE", "email": "caller@internal-test.local" }`.
- **Expected Response:** HTTP `200 OK` (`{ "ok": true, "data": { "deleted": true, "retry": false } }`).
- **Expected Database Changes:**  
  - `public.profiles` row deleted for ephemeral parent.  
  - `public.families` row deleted for ephemeral family.  
  - `public.family_members` row deleted.  
  - `auth.users` row deleted in GoTrue.
- **Expected Audit Events:**  
  1. `account_deletion_requested` (before relational cascade).  
  2. `account_deleted` (after confirmed GoTrue deletion).
- **Isolation Guarantee:** Operation scoped strictly to `caller.user.id`; foreign families untouched.
- **Risk Classification:** **Category D (High Risk / Permanent Mutation — Ephemeral User Only)**.

### TC-DEL-05: Partial Failure Simulation & Recovery Handling
- **Test ID:** `TC-DEL-05`
- **Required Entities:** Ephemeral Parent.
- **Preconditions:** GoTrue Auth deletion simulated to fail (e.g. timeout / error code).
- **Request Action:** Initial delete call fails at Step 3 (Auth deletion).
- **Expected Response:** HTTP `500 Internal Server Error` (`account_delete_incomplete`).
- **Expected Database Changes:** Database profile deleted; GoTrue Auth record remains.
- **Expected Audit Events:** `account_deletion_requested`, then `account_deletion_failed`.
- **Risk Classification:** **Category D (High Risk / Ephemeral Only)**.

### TC-DEL-06: `profile_missing` Deletion Retry Recovery
- **Test ID:** `TC-DEL-06`
- **Required Entities:** Ephemeral Parent in partial-failure state from TC-DEL-05.
- **Preconditions:** Profile row is absent; JWT remains valid in GoTrue Auth.
- **Request Action:** Retry `action: "delete"` with identical parameters.
- **Expected Response:** HTTP `200 OK` (`{ "ok": true, "data": { "deleted": true, "retry": true } }`).
- **Expected Database Changes:** GoTrue Auth user completely removed.
- **Expected Audit Events:** Final `account_deleted` event recorded.
- **Verification:** Proves that the user is not locked out by a missing profile on retry.
- **Risk Classification:** **Category D (High Risk / Ephemeral Only)**.

### TC-RET-01: Retention Report Scope Partitioning (PRIV-01)
- **Test ID:** `TC-RET-01`
- **Required Entities:** Ephemeral Parent (Owner), Ephemeral Parent (Member), and Ephemeral Child.
- **Preconditions:** All callers authenticated.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "retention_report" }`.
- **Expected Response:**  
  - Owner: `scope: "family"`, `last_sweep` contains sweep totals.  
  - Non-owner Parent: `scope: "family"`, `last_sweep = null` (sweep totals redacted).  
  - Child: `scope: "device"`, only own device counts, `last_sweep = null`.
- **Expected Database Changes:** Zero.
- **Expected Audit Events:** Zero.
- **Risk Classification:** **Category B (Low Risk / Read-Only)**.

### TC-RET-02: Retention Window Parsing and Defensive Clamping
- **Test ID:** `TC-RET-02`
- **Required Entities:** Ephemeral Parent with custom family settings (`location_retention_days: 99999` or `-5`).
- **Preconditions:** Custom settings row configured.
- **Request Action:** `action: "retention_report"`.
- **Expected Response:** Windows clamped to `[1, 3650]` days (max 10 years; negative clamped to default 30).
- **Expected Database Changes:** Zero.
- **Risk Classification:** **Category B (Low Risk / Read-Only)**.

### TC-RET-03: Retention Purge Absence Verification
- **Test ID:** `TC-RET-03`
- **Required Entities:** Ephemeral Parent.
- **Request Action:** `POST /functions/v1/account` with `{ "action": "retention_cleanup" }`.
- **Expected Response:** HTTP `400 Bad Request` (`unknown_action`, `"Unsupported action."`).
- **Expected Database Changes:** Zero rows deleted. Proves `account` function cannot execute destructive purges.
- **Risk Classification:** **Category B (Low Risk / Rejection Probe)**.
