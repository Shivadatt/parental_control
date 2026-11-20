# Phase 3.6 — Report 11: Architecture Decision Record (ADR-001)

**Title:** ADR-001: Isolated Test Environment Strategy for Production Account Edge Function Qualification  
**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Status:** **PROPOSED — AWAITING OWNER APPROVAL**  
**Date:** 2026-11-20  

---

## 1. Context and Problem Statement

The `account` Edge Function was successfully deployed and smoke-verified in Phase 3.4.7 and audited in Phase 3.5. To achieve full end-to-end production qualification, the engineering team must execute authenticated functional tests—including data export, retention audits, blocker enforcement, and account deletion cascades.

Executing tests against production databases carries inherent risks:
- Cross-tenant data leakage if queries are improperly scoped.
- Accidental mutation or deletion of operational users or monitored children's devices.
- Cluttering production audit trails with uncascaded test logs.

The architecture must define a strategy that allows live qualification while maintaining absolute safety for production users.

---

## 2. Decision Drivers

1. **Safety First:** Zero risk of data loss, credential compromise, or disruption to operational users (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`).
2. **Environmental Fidelity:** Testing must exercise the exact live Edge Function runtime, CORS headers, GoTrue Auth network behavior, and PostgreSQL database instance.
3. **Maintenance Overhead:** Minimizing manual synchronization of schemas, secrets, and Edge Function packages across separate environments.
4. **Deterministic Teardown:** Ensuring that all test entities, records, and orphaned audit rows can be 100% purged after testing.

---

## 3. Considered Options

### Option A: Dedicated Separate Supabase Project (Physical Isolation)
- **Description:** Provision a secondary Supabase project (e.g. `parent-control-staging`).
- **Pros:** 100% physical separation. A total failure in test scripts cannot touch production.
- **Cons:** High operational friction. All 14 migrations must be synchronized. All 10 Edge Functions must be deployed and maintained in the second project (which requires manual browser editor transfers due to CLI organization limits). Configuration drift between staging and prod often invalidates test results. Incurs extra project hosting costs.

### Option B: Ephemeral Test Tenants in Existing Production Project (Logical Isolation)
- **Description:** Provision disposable, short-lived test users, families, and devices within `parent-control-prod` using strict synthetic namespaces (`@internal-test.local`) and correlation ID tagging.
- **Pros:** Maximum fidelity (100% exact live environment). Zero drift. Zero additional infrastructure or hosting cost. Exercises the true production gateway.
- **Cons:** Relies on logical multi-tenant isolation (RLS and foreign keys). Requires strict pre-flight barriers, hardcoded blacklists, and targeted cleanup scripts to prevent data contamination.

### Option C: Local / Offline Integration Environment (Emulated Isolation)
- **Description:** Local mock environment using Deno test harness and in-memory mock databases.
- **Pros:** Zero risk to production, zero cost, instant test execution (400ms).
- **Cons:** Does not test the live production HTTPS endpoint, real GoTrue Auth network latency, or CDN caching behaviors.

---

## 4. Decision & Strategic Recommendation

The architecture recommends a **two-tiered hybrid strategy**:

$$\mathbf{Tier\ 1\ (Option\ C):\ Mandatory\ Offline\ Baseline} \longrightarrow \mathbf{Tier\ 2\ (Option\ B):\ Gated\ Ephemeral\ Production\ Qualification}$$

1. **Option C is retained as the permanent continuous regression baseline.** No test may be run against production without first passing 100% offline.
2. **Option B (Ephemeral Tenants) is qualified as architecturally safe for live production testing**, subject to:
   - Mandatory synthetic email namespace (`@internal-test.local`).
   - Hardcoded blacklisting of protected operational accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`).
   - Stage 2 pre-flight isolation probes before executing functional tests.
   - Dedicated correlation ID tagging (`metadata->>'test_correlation_id'`) allowing complete cleanup of relational entities and orphaned `audit_logs` records.
   - Multi-gate owner authorization (Report 10) requiring discrete approval for tenant creation, deletion testing, and cleanup execution.

If the project owner prefers absolute physical separation over operational simplicity, **Option A** remains the designated fallback.

---

## 5. Consequences & Risk Controls

- **Positive:** Enables definitive end-to-end verification of the production `account` function without maintaining duplicate cloud infrastructure.
- **Negative:** Leaves temporary records in production for the duration of the test run (max 1 hour).
- **Mitigation:** Stage 5 automated orphan sweeper purges any expired ephemeral tenant automatically.

---

## 6. Required Owner Approvals

Execution of Option B requires the project owner to sign off on:
1. Approval of ADR-001 strategy.
2. Explicit authorization of Gate 1 (Tenant Provisioning) and Gate 2 (Read-Only Verification).
3. Separate explicit authorization for Gate 4 (Live Account Deletion on Ephemeral Tenant).
