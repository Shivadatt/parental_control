# Phase 3.7.3 — Report 11: Staging Provisioning & Owner Approval Package

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Document Purpose:** Copy-ready owner authorization package for future staging qualification  
**Default State:** ALL GATES DEFAULT TO PENDING — NO EXECUTION AUTHORIZED  

---

## Formal Staging Approval Package (Copy-Ready)

```text
================================================================================
FORMAL OWNER APPROVAL: STAGING ENVIRONMENT CREATION & QUALIFICATION
================================================================================

Project: Parent Control App
Target Organization: symqztrmaziuwdibcfrq (spg7753@gmail.com's Org)
Target Region: ap-northeast-2 (Seoul / Northeast Asia)
Proposed Staging Name: parent-control-staging
Production Project (Protected): hhqgreaoqulmfwfwarhc

--------------------------------------------------------------------------------
1. STAGING PROJECT CREATION & SCHEMA DEPLOYMENT PREREQUISITE
--------------------------------------------------------------------------------
Scope: Authorizes the creation of a new, separate Supabase project in the 
existing organization to serve as an isolated staging environment.

Authorized Actions:
- Create new Supabase project: parent-control-staging
- Region: ap-northeast-2
- Apply repository migrations: 20260101000000_core.sql through 20261103000100
- Deploy verified account Edge Function package (Phase 3.4.3 flat bundle)
- Verify project ref is NOT hhqgreaoqulmfwfwarhc

[  ] APPROVED — Authorize Staging Project Creation
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
2. GATE CT-A — STAGING SYNTHETIC FIXTURE PROVISIONING
--------------------------------------------------------------------------------
Scope: Authorizes the creation of the minimum isolated synthetic fixtures 
in the newly created staging project only.

Authorized Boundaries:
- Target Environment: parent-control-staging ONLY (Zero production writes)
- Correlation ID Format: ct-isolation-YYYYMMDD-<short_hex>
- Synthetic Auth Users: Exactly 2 users (Parent A, Parent B)
- Synthetic Email Namespace: Exclusively @internal-test.local
- Synthetic Families: Exactly 2 families (Family A, Family B)
- Synthetic Profiles: Exactly 2 parent profiles
- Synthetic Devices: Exactly 2 devices (Device A, Device B)
- Synthetic Child Data: Exactly 17 records per tenant (34 total):
  * 5 location events (mid-ocean coordinates)
  * 5 usage daily rows
  * 3 safety alerts
  * 3 audit logs (with correlation_id stamped in metadata)
- Discrimination Markers: Strictly TENANT_A_ONLY and TENANT_B_ONLY
- Protected Accounts Denylist: Absolute prohibition on spg7753@gmail.com,
  ankit@gmail.com, and ankit1@gmail.com.

[  ] APPROVED — Authorize Staging Gate CT-A
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
3. GATE CT-B — STAGING ADVERSARIAL CROSS-TENANT VERIFICATION
--------------------------------------------------------------------------------
Scope: Authorizes read-only HTTP invocations against the staging account 
Edge Function using exclusively the staging synthetic identities.

Authorized Boundaries:
- Target Endpoint: https://<staging_ref>.supabase.co/functions/v1/account
- Permitted Actions: "export" and "retention_report" ONLY
- Maximum Requests: 15 total invocations
- Cross-Tenant Probes:
  * TC-01: User A export (asserts strictly Family A and TENANT_A_ONLY)
  * TC-02: User B export (asserts strictly Family B and TENANT_B_ONLY)
  * TC-03: User A export with injected Family B ID (asserts ignored)
  * TC-04: User B export with injected Family A ID (asserts ignored)
  * TC-05: User A retention report (asserts strictly Family A cutoffs)
  * TC-06: User B retention report (asserts strictly Family B cutoffs)
  * TC-07: Injected parameter retention report (asserts ignored)
- Expected Behavior: 100% read-only; zero cross-tenant leakage; zero mutations.
- Prohibited Actions: "delete", "delete_account", and "retention_cleanup"
  are STRICTLY PROHIBITED.

[  ] APPROVED — Authorize Staging Gate CT-B
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
4. GATE CT-C — STAGING TEARDOWN & CLEANUP
--------------------------------------------------------------------------------
Scope: Authorizes the cascade teardown and cleanup of strictly the synthetic 
entities in parent-control-staging.

Authorized Boundaries:
- Target Allowlist: Explicit staging UUIDs matching the correlation ID.
- Deletion Order:
  1. Audit logs (matching metadata->>'correlation_id')
  2. Child tables (location, usage, alerts via family_id)
  3. Devices (via family_id)
  4. Family members (via family_id)
  5. Families (via explicit UUID)
  6. Profiles & Auth users (via explicit UUID)
- Prohibited Methods: Zero wildcard deletes; zero broad email pattern deletes.

[  ] APPROVED — Authorize Staging Gate CT-C
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
OWNER SIGN-OFF
--------------------------------------------------------------------------------
Authorizing Owner: _____________________________________________
Owner Email: spg7753@gmail.com
Signature / Confirmation: _____________________________________
Date: _________________________________________________________
================================================================================
```
