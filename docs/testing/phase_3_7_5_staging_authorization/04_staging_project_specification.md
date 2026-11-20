# Phase 3.7.5 — Report 04: Staging Project Technical Specification

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Execution Mode:** SPECIFICATION / PROPOSAL / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report establishes the technical specification for a proposed dedicated Supabase staging project (`parent-control-staging`). All properties defined herein represent engineering proposals and are explicitly marked as:

$$\mathbf{Status} = \mathbf{PROPOSED\ —\ OWNER\ CONFIRMATION\ REQUIRED}$$

No cloud resources have been provisioned. The proposed project properties are designed to mirror production configuration while ensuring complete cryptographic, network, and operational separation.

---

## 2. Proposed Project Configuration Specification

| Property | Proposed Specification | Status / Classification | Verification Rule |
|---|---|:---:|---|
| **Project Name** | `parent-control-staging` | `PROPOSED` | Must clearly indicate non-production status |
| **Target Organization** | `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`) | `PROPOSED` | Must reside under owner's established org |
| **Region** | `ap-northeast-2` (Seoul / Northeast Asia) | `PROPOSED` | Region parity with production |
| **Environment Tier** | Non-Production Staging | `PROPOSED` | Dedicated exclusively to adversarial testing |
| **Production Data Replication** | **STRICTLY PROHIBITED** | `PROPOSED` | Zero production rows copied |
| **Allowed Test Identities** | Synthetic Only (`@internal-test.local`) | `PROPOSED` | Denylist real operational accounts |
| **Number of Test Tenants** | Exactly 2 (Tenant A, Tenant B) | `PROPOSED` | Minimal two-tenant world |
| **Number of Test Devices** | Exactly 2 (Device A, Device B) | `PROPOSED` | Exactly one per tenant |
| **Fixture Baseline Volume** | Exactly 40 total database rows | `PROPOSED` | 20 records per tenant |
| **Target Edge Function** | `account` | `PROPOSED` | Single flat bundle package |
| **Deployment Method** | Supabase Dashboard Browser Editor Only | `PROPOSED` | Established browser workflow |
| **CLI / PAT / API Usage** | **STRICTLY PROHIBITED** | `PROPOSED` | Zero automated credential usage |

---

## 3. Unknowns & Pre-Creation Constraints

The following conditions cannot be verified without manual owner inspection of the Supabase Dashboard:

1. **Organization Project Quota:** Supabase organizations have project limits based on plan tier (Free plan typically allows 2 active projects). Whether `symqztrmaziuwdibcfrq` has available project slots is currently `UNKNOWN`.
2. **Billing Implications:** If adding a second project incurs additional platform costs or requires upgrading the organization to Pro, explicit owner review is mandatory. Cost impact is currently `UNKNOWN`.
3. **Region Capacity:** Cloud provider capacity for Seoul (`ap-northeast-2`) must be verified at creation time. Availability is currently `UNKNOWN`.
4. **Project Reference ID:** The 20-character project ref will be generated nondeterministically by Supabase upon project creation. The exact ref is currently `UNKNOWN`.

---

## 4. Separation & Safeguard Rules

To ensure staging remains strictly segregated:
- **Zero Production Fallback:** Staging Edge Function environment variables (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) must point strictly to the staging project ref. Any fallback to `hhqgreaoqulmfwfwarhc` will cause immediate abort.
- **Zero Shared Secrets:** Staging database passwords, JWT secrets, and API keys must be completely unique and distinct from production.
- **Manual Dashboard Workflow:** Project creation, secret configuration, and code transfer must be executed manually by the project owner via the browser Dashboard.
