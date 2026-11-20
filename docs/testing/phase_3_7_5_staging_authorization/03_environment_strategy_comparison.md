# Phase 3.7.5 — Report 03: Environment Strategy & Architecture Comparison

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` Edge Function  
**Execution Mode:** ARCHITECTURAL ANALYSIS / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report evaluates three potential environment pathways for verifying cross-tenant isolation in the `account` Edge Function:
1. **Path A (Dedicated Staging Project):** Create `parent-control-staging` to execute live cloud tests in complete isolation from production.
2. **Path B (Existing Production Project with Synthetic Tenants):** Execute two-tenant tests within `parent-control-prod` using synthetic email namespaces.
3. **Path C (Offline-Only Verification):** Retain Phase 3.7.4 offline harness evidence and defer all live cloud testing.

$$\mathbf{Recommended\ Strategy} = \mathbf{PATH\ A\ (DEDICATED\ STAGING\ PROJECT)}$$

---

## 2. In-Depth Pathway Evaluation

### Path A: Dedicated Staging Project (Recommended)
- **Concept:** Provision a separate, non-production Supabase project (`parent-control-staging`) under the existing organization (`symqztrmaziuwdibcfrq`) in region `ap-northeast-2`. Apply repository migrations, deploy the verified `account` function flat bundle, create two synthetic tenants (40 records total), and execute live CT-01 through CT-10 tests.
- **Advantages:**
  - **Zero Production Risk:** The blast radius is completely contained within the disposable staging project.
  - **Live Cloud Parity:** Exercises real Supabase GoTrue Auth, live PostgREST API, real PostgreSQL transactional constraints, and live Edge Function deployment on Deno Deploy.
  - **Full Adversarial Testing:** Allows executing aggressive parameter tampering and negative boundary tests that would be high-risk in production.
  - **Clean Lifecycle:** The entire staging project or test dataset can be destroyed after testing without affecting production users.
- **Risks & Prerequisites:**
  - Requires creating a new Supabase cloud project, which is subject to organization project limits and potential billing changes if free-tier limits are exceeded.
  - Migration parity, RLS policies, and function environment variables must be rigorously deployed and audited before testing.
  - Production data must never be replicated into staging.

### Path B: Existing Production Project with Synthetic Tenants (NOT RECOMMENDED)
- **Concept:** Create two synthetic tenants directly inside `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) using synthetic namespaces (`@internal-test.local`) and execute cross-tenant requests against the live production endpoint.
- **Why It Is Prohibited as Default:**
  - **Operational Blast Radius:** Any failure or bug in service-role logic or RLS during cross-tenant testing could expose or modify real production data.
  - **Audit Log Contamination:** Production compliance tables (`audit_logs`) are append-only. Synthetic adversary events and test logs would permanently pollute production audit history.
  - **Operational Identity Hazard:** Production operational accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`) share the same database instance.
  - **Namespace Illusion:** A synthetic email namespace (`@internal-test.local`) is an application-level convention, not a cryptographic or database security boundary.

### Path C: Offline-Only Verification
- **Concept:** Treat the Phase 3.7.4 test results (55/55 passed) as the definitive proof of cross-tenant isolation and conclude verification without executing live cloud requests.
- **Advantages:**
  - **Zero Cloud Cost:** No new projects, zero operational risk, instant turnaround.
  - **Deterministic & Repeatable:** CI/CD test suite runs locally in < 700ms.
- **Limitations:**
  - Leaves live GoTrue Auth, PostgREST query generation, and Deno Deploy edge execution unverified against live cloud infrastructure.

---

## 3. Comprehensive Risk Comparison Matrix

| Evaluation Dimension | Path A: Dedicated Staging | Path B: Production Synthetic | Path C: Offline Only |
|---|:---:|:---:|:---:|
| **Production Blast Radius** | **Zero (Completely Isolated)** | **High (Shared Database)** | **Zero (No Cloud Touch)** |
| **Real GoTrue Auth Exercised** | **Yes (Live Staging Auth)** | **Yes (Live Production Auth)** | **No (Mock In-Memory)** |
| **Real PostgREST SQL Exercised** | **Yes (Live Cloud Engine)** | **Yes (Live Cloud Engine)** | **No (Mock Filter)** |
| **Real Edge Function Runtime** | **Yes (Seoul Deno Deploy)** | **Yes (Seoul Deno Deploy)** | **No (Local Deno CLI)** |
| **Audit Log Contamination** | **None (Staging Only)** | **Permanent (Production)** | **None** |
| **Cost / Billing Impact** | **Potential Project Fee** | **Zero Additional Fee** | **Zero Additional Fee** |
| **Owner Approval Requirement** | **Staging Creation Gate** | **Extreme Production Gate** | **None Required** |
| **Evidence Classification** | `LIVE CLOUD VERIFIED` | `LIVE CLOUD VERIFIED` | `OFFLINE TEST VERIFIED` |
| **Engineering Recommendation** | **STRONGLY RECOMMENDED** | **STRICTLY DISCOURAGED** | **ACCEPTABLE FALLBACK** |

---

## 4. Conclusion

Path A is the only pathway that achieves authentic cloud verification while maintaining absolute zero risk to production data, existing family records, child devices, and audit trails.
