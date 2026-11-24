# 06 — Pathway A vs Pathway B Comparison

**Document ID:** `HAVEN-GOV-006`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Neutral, Multi-Dimensional Architectural Comparison of Test Environment Pathways  
**Audit Standard:** Objective Adversarial Governance Evaluation  
**Execution Posture:** STRICTLY READ-ONLY — NO PATHWAY SELECTED  

---

## 1. Comparison Framework & Governance Neutrality

This document presents an objective, side-by-side technical evaluation of:
- **Pathway A**: Provisioning a dedicated Staging Supabase project.
- **Pathway B**: Implementing an isolated QA environment within the existing production Supabase project.

> [!IMPORTANT]
> **Neutrality Statement**:  
> This audit does **NOT** select a winner or recommend automatic adoption of either pathway. Both options possess distinct technical advantages, operational risks, and resource requirements. The Product Owner retains exclusive authority to evaluate these tradeoffs and make the strategic infrastructure decision.

---

## 2. Comprehensive 19-Dimension Comparison Table

| # | Dimension | Pathway A: Dedicated Staging Project | Pathway B: Existing Project QA Quarantine |
|:---:|:---|:---|:---|
| **1** | **Project Isolation** | **Total (100%)**: Completely distinct cloud project entity. | **Zero (0%)**: Shared single Supabase cloud project. |
| **2** | **Database Isolation** | **Total**: Independent PostgreSQL cluster, separate connection pool. | **Logical Only**: Shared database instance; separated via `family_id` RLS. |
| **3** | **Auth Isolation** | **Total**: Independent `auth.users` table; zero shared credentials. | **Partial**: Shared `auth.users` table; separated by email prefix. |
| **4** | **Storage Isolation** | **Total**: Separate S3/GCS buckets; zero object collisions. | **Logical Only**: Shared buckets; requires distinct folder path conventions. |
| **5** | **Edge Function Isolation** | **Total**: Separate Deno deployments; separate function logs. | **Shared**: Real users and QA invoke same function endpoints. |
| **6** | **Production Data Exposure** | **Zero Risk**: Impossible for test queries to reach production data. | **Low-to-Medium Risk**: RLS bugs or flawed scripts could query real rows. |
| **7** | **RLS Verification Rigor** | **High**: Can test cross-tenant queries safely between test families. | **Very High**: True production RLS test, but errors could expose real data. |
| **8** | **Destructive Testing** | **100% Unrestricted**: Can test `AUD03` purge, `AUD04` sweep, `A09` deletion. | **Severely Restricted**: `AUD03` and `AUD04` must be **STRICTLY PROHIBITED**. |
| **9** | **Migration Management** | **Dual Deploy**: Every migration must be applied to staging and prod. | **Single Deploy**: Zero migration duplication; tests against live schema. |
| **10**| **Configuration Complexity** | **Moderate**: Requires managing staging `--dart-define` build flags. | **Very Low**: App uses existing standard production build configuration. |
| **11**| **Infrastructure Setup** | **High**: Owner must create project, run CLI push, set secrets. | **Zero**: Uses existing deployed backend; ready immediately. |
| **12**| **Maintenance Burden** | **Moderate-to-High**: Ongoing task of keeping staging in sync with prod. | **Very Low**: Single environment to maintain and monitor. |
| **13**| **Monitoring & Log Clarity** | **High**: Staging logs contain only test traffic; easy debugging. | **Moderate**: QA errors and production errors mingle in shared logs. |
| **14**| **Backup & Recovery** | **Simple**: Can wipe, reset, or re-seed staging database at will. | **Complex**: Cannot reset database without destroying production data. |
| **15**| **Test Fixture Lifecycle** | **Ephemeral**: Can script automated database resets between runs. | **Persistent**: QA families and accounts accumulate unless manually purged. |
| **16**| **Operational Risk** | **Low**: Technical risks confined to staging environment. | **High**: Global jobs, rate limits, or deletion bugs can impact real users. |
| **17**| **Cost Category** | **Moderate**: Requires Supabase project quota (Free tier slot or Paid). | **Zero Additional Cost**: Utilizes existing project capacity. |
| **18**| **Prerequisites** | Owner account creation, CLI setup, migration push, secrets. | Strict QA account policy, prohibition of `AUD03`/`AUD04`, owner sign-off. |
| **19**| **Unresolved Questions** | Which cloud region to host staging? Who maintains staging sync? | How to verify retention sweeps without a dedicated database? |

---

## 3. Detailed Tradeoff Analysis

### 3.1 Pathway A: Dedicated Staging Project

#### Key Advantages:
1. **Absolute Safety**: Completely eliminates the possibility of test-induced data loss, account destruction, or service disruption for real users.
2. **Full Scope Execution**: Allows executing all 99 manual test cases, including destructive audit purges (`TC-EXP-47`) and scheduled retention sweeps (`TC-EXP-48`).
3. **Database Reset Freedom**: Testers can drop and recreate the database, seed mock historical data, and test edge recovery scenarios without operational fear.

#### Key Disadvantages & Costs:
1. **Setup Overhead**: Requires active owner intervention to create the project, apply 14 migrations, configure 4 secrets, and deploy 10 edge functions.
2. **Schema Drift Risk**: If developer migrations are applied to production without being applied to staging (or vice versa), testing will validate an outdated schema.
3. **Infrastructure Cost**: Consumes a Supabase project slot or incurs monthly cloud hosting fees.

---

### 3.2 Pathway B: Existing Project QA Quarantine

#### Key Advantages:
1. **Zero New Infrastructure**: Requires zero cloud project setup, zero deployment commands, and zero additional hosting expenses.
2. **Guaranteed Schema Parity**: Testing occurs against the exact, authoritative database schema and edge function versions running in production.
3. **Immediate Operational Readiness**: Non-destructive testing can begin as soon as disposable test accounts and hardware are provisioned.

#### Key Disadvantages & Risks:
1. **Destructive Testing Blocker**: Tests `TC-EXP-47` (`AUD03` immediate purge) and `TC-EXP-48` (`AUD04` retention sweep) **CANNOT BE SAFELY EXECUTED** because `public.run_retention_sweep()` operates globally across all database records.
2. **Shared Quota Exhaustion**: Aggressive authentication testing could consume hourly Supabase GoTrue email quotas, blocking real user registrations.
3. **Log Pollution**: QA test errors and stack traces appear in production logs, complicating production error monitoring.

---

## 4. Risks That Cannot Be Eliminated

| Pathway | Irreducible Technical Risk | Governance Mitigation |
|:---|:---|:---|
| **Pathway A** | **Environment Configuration Drift**: Staging environment becomes outdated relative to production. | Enforce CI/CD pipeline that applies migrations to staging before production. |
| **Pathway B** | **Global Job Data Destruction**: Global database functions (`run_retention_sweep`) lack family filtering. | **Formally prohibit** `TC-EXP-47` and `TC-EXP-48` from runtime execution on production. |

---

## 5. Comparative Feasibility Verdict

```
====================================================================================================
                        COMPARATIVE ENVIRONMENT VERDICT
====================================================================================================
OWNER DECISION REQUIRED — NO PATHWAY SELECTED

- Pathway A is the SUPERIOR SAFETY PATHWAY for comprehensive, unrestricted QA execution.
- Pathway B is the ZERO-COST, ZERO-SETUP PATHWAY, but requires accepting the permanent omission 
  of destructive retention sweep testing (TC-EXP-47 and TC-EXP-48).

The Product Owner must review these tradeoffs and select the preferred operational pathway.
====================================================================================================
```
