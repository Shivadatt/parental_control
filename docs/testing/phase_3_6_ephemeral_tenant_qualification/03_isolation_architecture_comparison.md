# Phase 3.6 — Report 03: Isolation Architecture Comparison & Strategic Evaluation

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Architectural Isolation Candidates

To qualify a strategy for authenticated end-to-end testing of the `account` Edge Function, three architectural models were evaluated:

1. **Option A: Dedicated Separate Supabase Project (Physical Isolation)**  
   A completely separate Supabase project (e.g., `parent-control-staging`) hosted independently from production.
2. **Option B: Ephemeral Test Tenants in Production (Logical Isolation)**  
   Disposable users, families, and device entities provisioned within the existing `parent-control-prod` project, isolated via Row Level Security (RLS) and namespace partitioning.
3. **Option C: Local / Offline Integration Environment (Emulated Isolation)**  
   Local test harness using mocked Supabase clients, Dockerized Postgres instances, and offline Deno runtime execution.

---

## 2. In-Depth Comparative Evaluation Matrix

| Comparison Dimension | Option A: Separate Project | Option B: Ephemeral Tenants in Prod | Option C: Local / Offline Mocks |
|---|---|---|---|
| **Isolation Strength** | **Absolute (Physical Boundary):** Zero shared tables, zero shared Auth, zero physical overlap with production. | **High (Logical Boundary):** Relies on RLS, GoTrue JWT tenant isolation, and strict query filters. | **Absolute (Local Boundary):** Completely isolated on developer workstation; zero network egress. |
| **Production Risk** | **Zero:** Catastrophic test failure cannot mutate production rows or affect real users. | **Low-to-Moderate:** Defect in cleanup or cross-tenant bypass could theoretically affect production data if unconstrained. | **Zero:** No connection to Supabase cloud infrastructure. |
| **Gateway & Network Fidelity** | **High:** Uses real Supabase Edge Function gateways, live GoTrue Auth endpoints, and live Postgres. | **Maximum (100% Exact):** Executes against the identical live Edge Function gateway and production runtime. | **Low:** Mocks network, GoTrue timeouts, and HTTP gateway behaviors in-memory. |
| **Configuration Parity Overhead** | **High:** Requires replicating 14 SQL migrations, 10 Edge Function deployments, Auth settings, and Vault secrets. | **Zero:** Environment, configuration, secrets, and functions are already deployed and 100% identical. | **Moderate:** Requires maintaining local mock tables, stub functions, and fake Deno modules. |
| **Operational & Hosting Cost** | Additional Supabase project tier (Free tier limits or \$25+/mo Pro project compute). | Zero additional compute cost (utilizes existing nano compute margin). | Zero hosting cost. |
| **Credential Confusion Risk** | **Moderate:** Operators must juggle two sets of API keys/URLs, introducing potential for misdirected traffic. | **Low-to-Moderate:** Requires strict programmatic guardrails so tests never target real operational users. | **Zero:** No cloud credentials required. |
| **Audit Trail Clutter** | Kept entirely in separate project database. | Audit logs persist with `family_id = null` after cascade unless specifically swept by cleanup scripts. | Ephemeral to the local test process. |
| **Setup & Maintenance Friction** | High initial effort to stand up, configure, and keep synchronized across releases. | Minimal setup; requires only provisioning and cleanup lifecycle scripts. | Low setup; already fully implemented and verified in Phase 3.5. |

---

## 3. Comparative Trade-Off Analysis

### Option A: The Gold Standard of Risk Elimination
- **Advantages:** Eliminates all catastrophic failure modes. Even an unconstrained `DELETE FROM profiles;` in a test script causes zero production impact.
- **Drawbacks:** Maintenance overhead. In Supabase, each project requires separate Edge Function deployment management (which currently requires manual browser editor transfers due to CLI organization permission restrictions). Schema migrations must be applied twice.

### Option B: High-Fidelity Qualification with Controlled Guardrails
- **Advantages:** Zero drift. Directly exercises the live production endpoint (`https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`) without needing to duplicate infrastructure.
- **Drawbacks:** Requires rigorous, multi-layered safeguards:
  1. Strict synthetic naming convention (`@internal-test.local`).
  2. Permanent exclusion of protected QA accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`).
  3. Pre-flight isolation validation before destructive operations.
  4. Targeted cleanup scripts utilizing explicit correlation IDs.

### Option C: Fast Local Regression Testing
- **Advantages:** Instantaneous feedback (401ms for 46 tests), zero cloud dependencies, safe for CI/CD pipelines.
- **Drawbacks:** Cannot validate real GoTrue Auth network latency, actual production Edge Function CORS headers, or hosted PostgREST serialization quirks.

---

## 4. Architectural Recommendation & Staged Strategy

$$\mathbf{Recommended\ Strategy} = \mathbf{Option\ C\ (Continuous\ Baseline)} \longrightarrow \mathbf{Option\ B\ (Gated\ Ephemeral\ Production\ Qualification)}$$

1. **Option C remains the primary development and regression barrier:** All functional testing must first pass 100% offline (Phase 3.5).
2. **Option B is recommended for live production qualification**, provided that:
   - An explicit, approval-gated lifecycle (designed in Report 04) is enforced.
   - The threat model (Report 05) proves zero cross-tenant leakage.
   - A dedicated cleanup and recovery engine (Report 08) guarantees total removal of test data.
3. If the project owner requires 100% risk elimination over operational simplicity, **Option A** must be provisioned.
