# Phase 3.7.3 — Report 01: Git Baseline & Project Inventory Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod`  
**Production Project Ref:** `hhqgreaoqulmfwfwarhc`  
**Organization ID:** `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`)  
**Region:** `ap-northeast-2` (Seoul / Northeast Asia)  
**Target Function:** `account`  
**Production Endpoint:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`  
**Phase 3.6 Baseline Commit:** `b573b80`  
**Phase 3.7 Commit:** `5c9d272`  
**Phase 3.7.1 Commit:** `61d70b2`  
**Phase 3.7.2 Commit:** `d49f514`  
**Intermediate Commit:** `91986b9` (`chore: add scratch diagnostic and test scripts`)  
**Existing Production Test Correlation ID:** `run-20261120-e7f1` (Dormant, preserved untouched)  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report audits the Git baseline, evaluates the availability and identity of a separate Supabase staging project, and inventories the technical evidence required to qualify a staging environment for adversarial cross-tenant testing.

$$\mathbf{Staging\ Availability\ Status} = \mathbf{STAGING\ PROJECT\ NOT\ AVAILABLE\ (BLOCKED)}$$

Repository evidence, including `docs/backend.md` L326-331 and configuration scans, confirms that **no separate Supabase staging project currently exists**. The only active cloud project for this application is `parent-control-prod` (`hhqgreaoqulmfwfwarhc`). Consequently, while offline fixture preflight and threat model analysis are 100% complete, live staging qualification is blocked pending project creation.

---

## 2. Git Repository Status & Baseline Verification

| Dimension | Command / Inspection Source | Verified State | Audit Finding |
|---|---|---|:---:|
| **Working Directory** | `D:\parentcontrol_app` | Local repository root | Confirmed |
| **Current Branch** | `git branch --show-current` | `main` | Confirmed |
| **Current HEAD Commit** | `git rev-parse HEAD` | `91986b93caa6787e5fae78fb76216f12b7fa804e` | Confirmed |
| **Parent Commit** | `d49f514` | `docs: add phase 3.7.2 cross-tenant test plan` | Confirmed |
| **Phase 3.7.1 Commit** | `61d70b2` | `docs: complete phase 3.7.1 evidence reconciliation` | Confirmed |
| **Phase 3.7 Commit** | `5c9d272` | `docs: complete phase 3.7 ephemeral tenant read-only qualification` | Confirmed |
| **Phase 3.6 Commit** | `b573b80` | `docs: complete phase 3.6 ephemeral tenant qualification` | Confirmed |
| **Working Tree State** | `git status --short` | Clean (Zero uncommitted application or test changes) | Pristine |

---

## 3. Staging Project Availability & Identity Audit

An exhaustive audit of repository configurations, environment files, and documentation was conducted to determine whether a dedicated staging project exists:

### 3.1 Historical Owner Directive & Documentation Evidence
In `docs/backend.md` (lines 326–331):
> *"No staging project exists: the only project reachable by this workstation's CLI login is `irlqctcddjmkwqdvsdsm`, while the app targets `hhqgreaoqulmfwfwarhc`. The owner directed on 2026-10-27 that the reviewed change set be deployed to that existing production project and that no second project be created."*

### 3.2 Environment & Configuration File Inspection
1. **`.tools/live_config.env`:** Contains strictly `SUPABASE_URL=https://hhqgreaoqulmfwfwarhc.supabase.co`. No staging URL is configured.
2. **`supabase/config.toml`:** Configured for local development (`project_id = "parentcontrol"`). Does not link to any remote staging project.
3. **`.env.example`:** Contains only generic placeholder variables.
4. **`.tools/staging-db-password.txt`:** Contains a database password string, but no associated project reference, endpoint URL, or connection string exists in the repository.

### 3.3 Project Identity Safeguard Finding
- **Production Project Ref:** `hhqgreaoqulmfwfwarhc` (`parent-control-prod` in `ap-northeast-2`).
- **Legacy CLI Ref:** `irlqctcddjmkwqdvsdsm` (historical artifact from early development; unconfigured and unreachable).
- **Dedicated Staging Project:** **NONE FOUND**.

In accordance with Section 4 of the user instructions:
$$\mathbf{Determination:} \quad \mathbf{STAGING\ PROJECT\ NOT\ AVAILABLE}$$
No Supabase project was created, no API calls were made, and offline preflight proceeded.

---

## 4. Reviewed Evidence Inventory

The qualification and preflight analyses in Phase 3.7.3 are grounded in:

1. **Database Schema & Migrations:**
   - `supabase/migrations/20260101000000_core.sql` (Tables, constraints, foreign keys).
   - `supabase/migrations/20260101000100_functions.sql` (Trigger functions).
   - `supabase/migrations/20260101000200_rls.sql` (Row-Level Security policies).
   - `supabase/migrations/20260101000300_service_role_grants.sql` (Database role permissions).
2. **Phase 3.7.2 Planning Deliverables:**
   - `02_two_tenant_threat_model.md` (Scenarios CT-01 through CT-10).
   - `03_service_role_query_test_mapping.md` (19 service-role database operations).
   - `04_populated_synthetic_fixture_design.md` (Fixture schemas and markers).
   - `05_correlation_and_cleanup_safety_design.md` (Reverse-dependency cleanup).
3. **Target Edge Function Source:**
   - `supabase/functions/account/index.ts` (480 lines).
   - `supabase/functions/account/retention.ts` (300 lines).
   - `supabase/functions/account/deletion.ts` (145 lines).
   - `supabase/functions/account/validation.ts` (110 lines).
4. **Offline Test Harness:**
   - `supabase/functions/account/scope_test.ts` (17 tests passing).
   - Complete account unit test suite (45 tests passing in 286ms).
