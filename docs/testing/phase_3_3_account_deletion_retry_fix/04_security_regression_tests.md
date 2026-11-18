# Phase 3.3 — Report 04: Security & Regression Test Matrix Specification

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Test Suite:** `supabase/functions/account/deletion_test.ts`  
**Execution Tool:** Deno Test Runner (`deno test`)

---

## 1. Test Suite Architecture

The test suite is built on top of `fakePostgrest` (`supabase/functions/_shared/fake_postgrest.ts`), which provides in-memory emulation of PostgreSQL tables, PostgREST query builders, GoTrue user authentication (`auth.getUser`), and GoTrue admin deletion (`auth.admin.deleteUser`).

Every test issues real `Request` objects containing headers and JSON payloads to `handleAccountRequest`, exercising the full serialization, deserialization, envelope wrapping, and error status mapping stack.

---

## 2. Comprehensive 15-Test Matrix Specification

| # | Test Name | Invariant Tested | Test Scenario Setup | Expected Result |
| :---: | :--- | :---: | :--- | :--- |
| **1** | **Normal Parent deletion with existing profile** | 1, 3, 7, 8 | Parent owns family with 0 other members and 0 devices. Submits `DELETE` and matching email. | **200 OK** `{ ok: true, data: { deleted: true, retry: false } }`. Profile, family, and memberships removed. `account_deleted` audited. |
| **2** | **Child deletion with existing profile** | 1, 3 | Child user submits `DELETE` and matching email. Family is owned by parent. | **200 OK** `{ ok: true, data: { deleted: true } }`. Child profile removed; family and parent data preserved. |
| **3** | **Missing profile + valid deletion retry** | 6, 2 | Previous deletion removed `public.profiles`, but Auth user still exists. User retries deletion. | **200 OK** `{ ok: true, data: { deleted: true, retry: true } }`. Resumes Auth deletion without 403 `profile_missing`. |
| **4** | **Missing profile + non-delete action** | 4 | Profile is missing. User attempts `action: "export"` or `action: "retention_report"`. | **403 Forbidden** `{ ok: false, error: { code: "profile_missing" } }`. Access to normal features is strictly denied. |
| **5** | **Invalid JWT** | 1 | Request with missing token, short token, or rejected signature. | **401 Unauthorized** `{ ok: false, error: { code: "unauthorized" } }`. |
| **6** | **Invalid confirmation** | 3 | Request submits `confirm: "delete"` (lowercase) or non-matching text. | **400 Bad Request** `{ ok: false, error: { code: "confirmation_required" } }`. No DB changes made. |
| **7** | **Incorrect caller email** | 3 | Request submits `confirm: "DELETE"`, but email does not match verified JWT email. | **400 Bad Request** `{ ok: false, error: { code: "email_mismatch" } }`. No DB changes made. |
| **8** | **Auth deletion failure after profile deletion** | 6, 8, 10 | Profile deleted, but GoTrue `deleteUser` times out / returns 500. | **500 Internal Server Error** `{ ok: false, error: { code: "account_delete_incomplete" } }`. `account_deleted` is NOT logged; `account_deletion_failed` logged. |
| **9** | **Successful retry after partial failure** | 6, 8 | GoTrue service recovers. User retries deletion with valid JWT and confirmation. | **200 OK** `{ ok: true, data: { deleted: true, retry: true } }`. Auth user deleted; `account_deleted` logged. |
| **10** | **Duplicate retry** | 9 | Deletion already finished and Auth user removed. User sends another retry request. | **401 Unauthorized** (or 200 idempotent). User identity is completely gone. |
| **11** | **Concurrent duplicate requests** | 9 | Two identical deletion requests arrive concurrently via `Promise.all`. | Both requests resolve cleanly (one 200, one 401/200). Zero unhandled 500 crashes; DB cleanly purged. |
| **12** | **Active child/device deletion blocker** | 7 | Parent owns a family that still has an active child device or other active member. | **409 Conflict** `{ ok: false, error: { code: "account_deletion_blocked", details: { blocked_reason: ... } } }`. No rows deleted. |
| **13** | **Cross-user deletion attempt** | 5 | Caller is User A, but body maliciously passes User B's email and `user_id: User B`. | **400 Bad Request** (`email_mismatch`). User B's profile and data are completely untouched. |
| **14** | **Audit event correctness** | 8 | Forensic audit trail verification across pre-deletion and post-auth deletion stages. | 2 audit rows: (1) `account_deletion_requested` with `actor_user_id = caller`; (2) `account_deleted` with `actor_user_id = null`. |
| **15** | **Existing account export behavior** | - | Caller with valid profile requests `action: "export"`. | **200 OK** with `Content-Disposition: attachment`. Verifies no regressions in export functionality. |
