# Phase 3.6 — Report 10: Production Boundary & Multi-Gate Approval Matrix

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Approval Framework & Non-Delegation Principle

To maintain total operational control over the production environment, future testing activities must not be governed by a single blanket authorization. 

A high-level approval to "test in production" does **NOT** grant authorization to execute destructive account deletions, trigger mass cleanups, or modify configuration. Each tier of activity requires its own explicit, distinct authorization gate.

---

## 2. Granular Production Operation Approval Matrix

| Operation Category | Specific Operation / Action | Allowed in Phase 3.6? | Future Phase Authorization Requirement | Mandatory Safety Guardrail |
|---|---|:---:|---|---|
| **Inspection** | **Repository source code & schema inspection** | **YES** | Pre-authorized (Read-Only) | Read-only tools only. |
| **Inspection** | **Offline Deno unit / regression test execution** | **YES** | Pre-authorized (Local execution) | Zero network egress to Supabase. |
| **Inspection** | **Dashboard browser read-only status check** | **YES** | Pre-authorized (Passive UI) | No click on mutation/deploy buttons. |
| **Tenant Provisioning** | **Create synthetic test user in Supabase Auth** | **NO** | **Gate 1: Explicit Provisioning Approval** | Strict `@internal-test.local` domain check. |
| **Tenant Provisioning** | **Create ephemeral test family & profile** | **NO** | **Gate 1: Explicit Provisioning Approval** | Mandatory `test_correlation_id` tagging. |
| **Tenant Provisioning** | **Register synthetic test device** | **NO** | **Gate 1: Explicit Provisioning Approval** | Synthetic installation ID prefix (`test-inst-`). |
| **Functional Verification** | **Invoke live authenticated export (`export`)** | **NO** | **Gate 2: Read-Only Verification Approval** | Ephemeral test parent JWT only. |
| **Functional Verification** | **Invoke live retention audit (`retention_report`)**| **NO** | **Gate 2: Read-Only Verification Approval** | Read-only calculation; zero deletions. |
| **Destructive Testing** | **Test deletion blocker (`delete` with active child)**| **NO** | **Gate 3: Blocker Test Approval** | Expects `409 Conflict`; zero rows deleted. |
| **Destructive Testing** | **Execute live account deletion (`delete`)** | **NO** | **Gate 4: Explicit Deletion Approval** | Ephemeral user ONLY; requires `"DELETE"` + email. |
| **Destructive Testing** | **Simulate partial failure & retry recovery** | **NO** | **Gate 4: Explicit Deletion Approval** | Disposable test identity only. |
| **Destructive Testing** | **Trigger retention cleanup sweep** | **NO** | **Gate 5: Cron Sweep Approval (Separate Phase)**| Omitted from Edge Function; isolated to cron. |
| **Teardown & Cleanup** | **Execute targeted ephemeral cleanup script** | **NO** | **Gate 6: Explicit Teardown Approval** | Dry-run required first; correlation ID only. |
| **Infrastructure** | **Deploy or redeploy Edge Functions** | **NO** | **Owner Written Deployment Approval** | Code frozen in Phase 3.4.7. |
| **Infrastructure** | **Modify RLS, SQL schema, or migrations** | **NO** | **Owner Written Schema Approval** | Strictly out of scope. |
| **Operational Security** | **Any operation targeting protected QA accounts** | **NEVER** | **ABSOLUTELY FORBIDDEN** | Hardcoded blacklist abort. |

---

## 3. Strict Stop Conditions

Any ongoing verification process must stop immediately if:
1. The active Supabase Dashboard session switches away from project `hhqgreaoqulmfwfwarhc`.
2. A script or operator requests a CLI command or Personal Access Token (PAT).
3. A query or selector targets any email outside `@internal-test.local`.
4. A cleanup query attempts to delete records without specifying `test_correlation_id`.
5. An unexpected 500 error or unhandled database exception occurs during live calls.
