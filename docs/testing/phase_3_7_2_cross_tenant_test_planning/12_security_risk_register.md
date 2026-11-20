# Phase 3.7.2 — Report 12: Security Risk Register & Mitigation Matrix

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / TEST PLANNING / SOURCE REVIEW  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report establishes the comprehensive **Security Risk Register** for multi-tenant isolation, data protection, and operational safety in the `account` Edge Function. Every identified threat is evaluated across severity, evidence provenance, architectural countermeasure, and mandatory owner approval dependencies.

$$\mathbf{Risk\ Governance\ Standard} = \mathbf{FAIL-CLOSED\ ARCHITECTURE\ -\ FORMAL\ GATED\ MITIGATIONS}$$

---

## 2. Comprehensive Security Risk Register

| Risk ID | Risk Description | Severity | Evidence Source | Technical Countermeasure & Mitigation | Approval Dependency |
|:---:|---|:---:|---|---|:---:|
| **SR-01** | **Service-Role `BYPASSRLS` Data Leakage**<br>Database queries execute with service-role privileges, bypassing PostgreSQL RLS policies. | **Critical** | `account/index.ts` L458 (`getServiceClient()`) | Strict application-layer filtering; every query mandates `.in('family_id', activeFamilyIds)`. | Gate CT-B Verification |
| **SR-02** | **Audit Log Orphan Decoupling**<br>`audit_logs` foreign keys use `ON DELETE SET NULL`, causing logs to lose user/family references upon deletion. | **High** | `core.sql` L310-335 | Mandatory stamping of `correlation_id` in `metadata` JSONB; archive audit rows prior to tenant deletion. | Gate CT-C Teardown |
| **SR-03** | **Request Body Parameter Injection (IDOR)**<br>Adversary supplies a foreign `family_id` in the JSON request body. | **High** | `account/index.ts` L227-250 | Function derives query scope strictly from verified JWT `sub` and active memberships; request body IDs are ignored. | Gate CT-B Verification |
| **SR-04** | **Child Privilege Escalation**<br>A synthetic child user attempts to export whole-family telemetry or parent audit logs. | **High** | `account/retention.ts` L167-173 | `resolveRetentionScope` strictly clamps role `child` to `scope: "device"`, querying only own device rows (`child_user_id = caller`). | Gate CT-B Verification |
| **SR-05** | **Empty Scope Query Broadening**<br>An unaffiliated user with zero active memberships triggers an unbounded database query. | **Critical** | `account/index.ts` L259, L276 | Empty array guard substitutes `NO_MATCH_UUID` (`00000000-...`), guaranteeing PostgREST never executes an open query. | Gate CT-B Verification |
| **SR-06** | **Pagination Filter Loss**<br>`fetchCapped` multi-page range loop (`from += 1000`) drops tenant filter on subsequent iterations. | **High** | `account/index.ts` L93-119 | Scoping filter is passed as an immutable closure to the query builder on every iteration; limit capped at 20,000 rows. | Gate CT-B Verification |
| **SR-07** | **Accidental Mutation of Operational Accounts**<br>A test script or teardown routine impacts `spg7753@gmail.com` or other production users. | **Critical** | Phase 3.7 Boundary Rules | Hardcoded in-memory denylist; instant fatal abort if any operational account appears in target set. | Gate CT-A / Gate CT-C |
| **SR-08** | **Credential / JWT Exposure in Telemetry**<br>Raw tokens, passwords, or Authorization headers committed to Git reports. | **Medium** | `gate2_results.json` (Phase 3.7) | Test harness redacts tokens in memory; records only sanitized boolean indicators and counts. | Ongoing Practice |
| **SR-09** | **Uncontrolled Retention Sweeper Purge**<br>Executing `action: "retention_cleanup"` purges production records outside the test tenant. | **Critical** | `account/retention.ts` L95-130 | Prohibited from the `account` endpoint; retention sweeper qualification quarantined to separate Gate 4. | Separate Gate 4 |
| **SR-10** | **Residual Dormant Tenant Clutter**<br>Synthetic tenants remain permanently dormant in production database after testing concludes. | **Low** | Phase 3.7 Tenant State | Formal Gate CT-C teardown protocol using reverse-dependency cascade deletion. | Gate CT-C Teardown |

---

## 3. Residual Risk Summary

Following the full implementation of the countermeasures designed in Phase 3.7.2:
- **Design Risks Resolved:** The service-role scoping logic, body parameter immutability, child role scoping, empty-set fail-closed handling, and audit metadata stamping are 100% verified at the source level.
- **Operational Risks Gated:** Execution risks are strictly controlled via the 3-gate approval model (Gate CT-A, CT-B, CT-C), requiring explicit owner opt-in before any cloud resource is touched.
- **Residual Operational Risk:** Low, contingent upon owner execution of the approved test contract.
