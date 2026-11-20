# Phase 3.4, 3.4.1 & 3.4.2 — Report 03: Post-Deployment Smoke Tests & Verification Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Verification Scope:** Authentication, Export, Retention, and Deletion Retry Paths  
**Status Date:** 2026-11-20 (Phase 3.4.2 Post-Audit)  

---

## 1. Cloud-Hosted vs. Local Verification Seam

Because the Dashboard web editor does not support multi-file directory packages and CLI deployment is awaiting organization delegation, the live production endpoint (`https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`) is **not deployed** in the cloud.

In strict compliance with the instructions:
> **"Do not claim live verification when evidence is only from local source code. Clearly distinguish source-level fixes from hosted production verification."**  
> **"If cloud endpoint tests cannot be safely performed, mark them BLOCKED or NOT TESTED."**

Every post-deployment check is explicitly categorized below.

---

## 2. Authentication Verification Matrix

| Check Item | Target Behavior | Offline / Harness Test Evidence | Cloud-Hosted Live Endpoint Status | Verdict |
| :--- | :--- | :--- | :--- | :---: |
| **Missing Authorization Header** | HTTP 401 `unauthorized` (`{"code": "unauthorized"}`) | `deletion_test.ts:303` (Test 5a passed) | **BLOCKED** (Function not deployed in cloud) | **VERIFIED (HARNESS)** |
| **Invalid / Malformed JWT** | HTTP 401 `unauthorized` (`{"code": "unauthorized"}`) | `deletion_test.ts:311` (Test 5b passed) | **BLOCKED** (Function not deployed in cloud) | **VERIFIED (HARNESS)** |
| **Rejected / Expired JWT** | HTTP 401 `unauthorized` (`{"code": "unauthorized"}`) | `deletion_test.ts:318` (Test 5c passed) | **BLOCKED** (Function not deployed in cloud) | **VERIFIED (HARNESS)** |
| **Missing Profile on Normal Actions** | HTTP 403 `profile_missing` on `export` & `retention_report` | `deletion_test.ts:257` (Test 4a, 4b passed) | **BLOCKED** (Function not deployed in cloud) | **VERIFIED (HARNESS)** |
| **Missing Profile on Deletion Retry** | HTTP 200 `deleted: true` (`requireAuthUser` bypass) | `deletion_test.ts:233` (Test 3 passed) | **BLOCKED** (Function not deployed in cloud) | **VERIFIED (HARNESS)** |

---

## 3. Data Export Verification (`action: "export"`)

### Verification Details:
- **Scope Resolution:** Verified that `resolveRetentionScope()` accurately determines whether the caller is `family`, `device`, or `not_reported`.
- **Sensitive Data Exclusion:** Inspected column projections in `supabase/functions/account/deletion.ts:59`:
  - `DEVICE_COLUMNS` strictly exports: `id, family_id, child_user_id, installation_id, display_name, platform, android_version, app_version, status, last_seen_at, battery_level, is_charging, enforcement_mode, policy_version, permissions, created_at, updated_at`.
  - Sensitive columns (`secret_hash`, `credential_revoked_at`, device secrets) are **never** selected or exported.
- **Wire Format:** Verified `application/json` payload with `Content-Disposition: attachment; filename="parent-control-export-YYYY-MM-DD.json"` and `Cache-Control: no-store`.
- **Harness Evidence:** `deletion_test.ts:558` (Test 15 passed in 7ms).
- **Live Cloud Status:** **BLOCKED / NOT TESTED** against live production database.

---

## 4. Retention Report Verification (`action: "retention_report"`)

### Verification Details:
- **Scope & Role Segregation:**
  - Family owners receive family counts plus project-wide retention sweep totals.
  - Non-owner parents receive family counts with sweep markers redacted.
  - Children receive only their own device rows.
  - Unscoped callers receive `not_reported` (zero counts, zero disclosures).
- **Destructive Execution Boundary:**
  - `retention_report` only executes read-only count queries (`head: true`, `count: "exact"`).
  - It does **not** invoke `run_retention_sweep()` or delete any rows.
- **Harness Evidence:** `account/retention_test.ts` (6 tests passed), `account/scope_test.ts` (17 tests passed).
- **Live Cloud Status:** **BLOCKED / NOT TESTED** against live production database.

---

## 5. Account Deletion Retry Verification

### Test Harness Simulation of Failure Modes:
1. **Initial Failure Simulation:**
   - In `deletion_test.ts:355` (Test 8), GoTrue Admin deletion was injected with a simulated 500 timeout error.
   - The test verified that relational data and profile were removed, but HTTP 500 `account_delete_incomplete` was returned.
   - Verified that `account_deleted` was **NOT** recorded in `audit_logs`; instead, `account_deletion_failed` was recorded.
2. **Subsequent Retry Simulation:**
   - In `deletion_test.ts:382` (Test 9), the simulated timeout was cleared.
   - The caller submitted an identical retry request with the same JWT, `confirm: "DELETE"`, and caller email.
   - The handler detected that `profiles` was absent, skipped relational deletion, executed GoTrue deletion, recorded `account_deleted`, and returned HTTP 200 `{ deleted: true, retry: true }`.
3. **Protected Account Safety:**
   - Zero deletion requests were sent against production accounts (`ankit@gmail.com`, `ankit1@gmail.com`, `spg7753@gmail.com`).
   - Zero live users or devices were touched.

---

## 6. Smoke Test Summary

| Capability | Local Harness Status | Live Cloud Status | Risk Assessment |
| :--- | :---: | :---: | :---: |
| **Authentication Filtering** | **PASS (5/5)** | **BLOCKED** | Safe; verified locally |
| **Data Export Protocol** | **PASS (1/1)** | **BLOCKED** | Safe; zero secret leakage |
| **Retention Reporting** | **PASS (23/23)** | **BLOCKED** | Safe; non-destructive |
| **Deletion Retry Path** | **PASS (15/15)** | **BLOCKED** | Safe; lockout trap resolved |
