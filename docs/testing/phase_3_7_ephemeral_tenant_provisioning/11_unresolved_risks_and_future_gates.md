# Phase 3.7 — Report 11: Unresolved Risks & Future Approval Gates

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Identified Risks & Preflight Security Observations

The rigorous preflight revalidation conducted in Phase 3.7 surfaced three mission-critical architectural observations that must be accounted for in future live testing:

### 1. Service-Role RLS Bypass Risk
- **Mechanism:** In `shared-auth.ts`, the database client is created with `SUPABASE_SERVICE_ROLE_KEY`. In Postgres, the service role has `BYPASSRLS` privileges.
- **Consequence:** Postgres Row Level Security does not protect against missing query filters inside the Edge Function.
- **Control Requirement:** Tenant isolation relies entirely on application-level filtering (`.eq("user_id", ...)`, `.in("family_id", ...)`). Prior to any future test execution, offline regression suites must re-verify that every handler derives filters from verified JWT claims.

### 2. Audit-Log Cascade Invariant
- **Mechanism:** `public.audit_logs` specifies `ON DELETE SET NULL` on `family_id` and `actor_user_id`.
- **Consequence:** When an ephemeral test family or user is deleted, their audit log entries remain in the table indefinitely with `NULL` foreign keys.
- **Control Requirement:** All future live test actions must inject `metadata: { "test_correlation_id": "<RUN_ID>" }` so that the Gate 6 cleanup script can explicitly sweep orphaned audit records without touching operational logs.

### 3. Missing Owner Authorization Barrier
- **Observation:** Neither Gate 1 (Provisioning) nor Gate 2 (Read-Only Verification) written approvals have been granted by project owner `spg7753@gmail.com`.
- **Control Requirement:** In accordance with deployment governance, testing is strictly blocked until explicit written approval is delivered.

---

## 2. Granular Multi-Gate Authorization Roadmap

To transition from this preflight state to live verification, the project owner must authorize the following distinct gates in sequence:

```
┌─────────────────────────────────────────────────────────────┐
│ GATE 1: Ephemeral Tenant Provisioning                       │
│  - Authorizes creation of 1 Parent + 1 Child test user      │
│  - Strictly restricted to @internal-test.local namespace    │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ GATE 2: Authenticated Read-Only Verification                │
│  - Authorizes live POST export and retention_report         │
│  - Authorizes synthetic cross-tenant rejection probes       │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ GATE 3: Deletion Blocker Verification (Non-Destructive 409) │
│  - Authorizes attempting delete with active members/devices │
│  - Confirms 409 account_deletion_blocked rejection          │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ GATE 4: End-to-End Deletion Cascade (Ephemeral User Only)   │
│  - Authorizes full cascade deletion on disposable test user │
│  - Confirms GoTrue Auth deletion & retry recovery           │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ GATE 6: Targeted Ephemeral Teardown                         │
│  - Authorizes surgical cleanup of test records and tagged   │
│    audit logs using exact correlation ID                    │
└─────────────────────────────────────────────────────────────┘
```

A generic or combined approval is rejected; each gate must be independently confirmed.
