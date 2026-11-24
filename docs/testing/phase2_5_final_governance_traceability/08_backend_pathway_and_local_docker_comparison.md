# Phase 2.5 — Backend Execution Pathways & Local Docker Comparative Audit

**Document ID:** `HAVEN-GOV-PHASE2-5-PATHWAYS`  
**Phase:** Phase 2.5 — Final Governance Traceability & Owner Authorization Consistency Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Neutral, Multi-Dimensional Architectural Feasibility Assessment  
**Execution Posture:** STRICTLY READ-ONLY — NO BACKEND SELECTION AUTHORIZED  

---

## 1. Executive Purpose & Governance Neutrality

Previous audit reports have discussed two primary backend execution targets:
- **Pathway A**: Dedicated Staging Supabase Project (Cloud).
- **Pathway B**: Existing Supabase Project with QA Tenant Quarantine (In-Project Partitioning).

Phase 2.4 introduced a third architectural option based on existing repository configuration:
- **Pathway C (Local Docker / Hybrid)**: Local Supabase CLI containerized environment combined with local/emulated test runners.

**Governance Boundary**: Phase 2.5 does **NOT** select, recommend, or authorize any backend pathway. The decision is reserved exclusively for the Project Owner under Decision `P25-OWNER-02`. This document provides an objective, evidence-based comparative audit across ten critical dimensions.

---

## 2. Multi-Dimensional Architectural Comparison Matrix

| Dimension | Pathway A (Dedicated Staging Cloud) | Pathway B (Existing Project QA Tenant) | Pathway C (Local Docker / Hybrid) |
| :--- | :--- | :--- | :--- |
| **1. Current Existence** | **NON-EXISTENT** (`docs/backend.md:327`). Must be created. | **EXISTS** (`hhqgreaoqulmfwfwarhc`). Active production project. | **CONFIGURED ONLY** (`supabase/config.toml` exists; daemon not running). |
| **2. Setup Evidence** | Documented setup procedure in `docs/backend.md`. Requires cloud provisioning. | Exists and active. Requires seeding QA family and account fixtures. | `supabase/config.toml` lines 1–95 define local ports (API: 54321, DB: 54322, Auth: 3000). |
| **3. Tenant Isolation** | **PHYSICAL / INFRASTRUCTURE ISOLATION**. Complete separation of databases and secrets. | **LOGICAL / ROW-LEVEL ISOLATION**. Relies on `family_id` RLS and Deno application checks. | **PHYSICAL / LOCAL ISOLATION**. Completely isolated on local workstation Docker engine. |
| **4. Destructive Test Suitability** | **EXCELLENT**. High tolerance for destructive sweeps, account purges, and schema drops. | **HIGH RISK**. Retention sweep (`AUD04`) and account deletion (`AUD01`) strictly quarantined. | **EXCELLENT**. Database can be reset instantly via `supabase db reset` without cloud risk. |
| **5. Edge Function Compatibility** | **FULL NATIVE CLOUD COMPATIBILITY**. All 10 functions deploy to Supabase Cloud runtime. | **FULL NATIVE CLOUD COMPATIBILITY**. Functions already deployed or ready to deploy. | **LOCAL DENO RUNTIME**. Tested via `supabase functions serve`. Requires local Deno setup. |
| **6. Android Integration** | **EXCELLENT**. Mobile devices connect directly to public HTTPS endpoint. | **EXCELLENT**. Mobile devices connect directly to public HTTPS endpoint. | **COMPLEX**. Physical phones cannot reach `localhost:54321` without LAN IP routing or ADB reverse. |
| **7. Realtime / WebRTC** | **FULL CLOUD SUPPORT**. Standard WebSocket realtime and Google STUN server (`env.dart`). | **FULL CLOUD SUPPORT**. Active realtime channel and WebRTC signaling table. | **PARTIAL**. Realtime runs locally; WebRTC peer traversal across LAN requires specialized NAT setup. |
| **8. Production Impact** | **ZERO IMPACT** on production data. Potential naming/deep-link collision on test devices. | **MODERATE-TO-HIGH RISK** of accidental cross-tenant data corruption if sweeps are run. | **ZERO IMPACT** on production cloud. Zero risk to customer records. |
| **9. Critical Unknowns** | Cloud hosting cost; setup duration; verification of secret configuration. | Exact rate limits; risk of tester error confusing prod and staging builds. | Workstation Docker performance; physical device network reachability. |
| **10. Owner Authorization Required** | **YES** (Decision `P25-OWNER-02`, Option B-1; requires infrastructure provisioning approval). | **YES** (Decision `P25-OWNER-02`, Option B-2; requires destructive quarantine approval). | **YES** (Decision `P25-OWNER-02`, Option B-3; requires local environment authorization). |

---

## 3. Deep-Dive Feasibility Analysis by Pathway

### 3.1 Pathway A: Dedicated Staging Cloud Project
- **Strengths**: True end-to-end cloud fidelity. Physical isolation prevents any possibility of production data contamination. Safest environment for destructive tests (`TC-EXP-47`, `TC-A09`, `TC-FAM10`, `TC-EXP-17`).
- **Hazards & Unknowns**:
  1. `lib/core/config/env.dart:28–33` contains silent production fallbacks if `--dart-define` flags are omitted during compilation.
  2. Developers with shared Supabase CLI credentials can inadvertently deploy to production if project context is switched improperly.
  3. Android package ID collision (`com.parentcontrol.parent_control`) prevents concurrent installation of staging and production builds on the same device.

### 3.2 Pathway B: Existing Project with QA Tenant Quarantine
- **Strengths**: Zero infrastructure provisioning cost. Zero delay in standing up cloud projects. Exact parity with live database schema.
- **Hazards & Unknowns**:
  1. Edge Functions bypass PostgreSQL RLS via `getServiceClient()` (`_shared/auth.ts:60–75`), relying entirely on Deno application logic.
  2. The global retention sweep `public.run_retention_sweep()` (`20261030000300_retention_sweep.sql:116`) lacks family scoping and deletes data across all families. Running it on Pathway B destroys real customer records.
  3. Destructive account deletion (`deletion.ts`) triggers cascading deletions that must be rigorously restricted to dedicated disposable test accounts (`qa-destroy-*@haven.internal`).

### 3.3 Pathway C: Local Docker / Hybrid Architecture
- **Strengths**: Zero cloud cost. Total physical isolation on developer workstation. Complete safety for schema drops, table resets, and destructive sweeps.
- **Hazards & Unknowns**:
  1. Physical Android devices cannot resolve `http://localhost:54321` or `http://10.0.2.2:54321` without dedicated LAN configuration or ADB port forwarding (`adb reverse tcp:54321 tcp:54321`).
  2. Supabase Studio and Inbucket email testing run locally, requiring workstation RAM and Docker daemon availability.
  3. WebRTC signaling over local networks may encounter ICE candidate gathering failures without an external STUN/TURN server.

---

## 4. Governance Decision Framework Summary

The comparative audit yields the following governance findings:
1. **No Pathway is Risk-Free**: Pathway A has client configuration and fallback risks; Pathway B has production data contamination risks; Pathway C has mobile networking and toolchain complexity.
2. **Owner Discretion**: The Project Owner must weigh the trade-offs (cloud cost and setup time vs shared-tenant operational discipline vs local Docker networking) under Decision `P25-OWNER-02`.
3. **No Selection Authorized**: The audit team has made no binding selection. All execution remains strictly locked.
