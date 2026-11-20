# Phase 3.7.2 — Report 11: Owner Authorization Template (Copy-Ready)

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Organization ID:** `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`)  
**Target Function:** `account`  
**Document Purpose:** Formal written approval template for owner review and signature  
**Default State:** ALL GATES DEFAULT TO PENDING — NO EXECUTION AUTHORIZED  

---

## Formal Owner Authorization Template

```text
================================================================================
FORMAL OWNER AUTHORIZATION: ADVERSARIAL CROSS-TENANT ISOLATION TESTING
================================================================================

Project Name: Parent Control App
Supabase Project: parent-control-prod
Project Ref: hhqgreaoqulmfwfwarhc
Organization: symqztrmaziuwdibcfrq (spg7753@gmail.com's Org)
Target Endpoint: https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account
Authorized Test Correlation ID: [ e.g. ct-isolation-20261121-a4b2 ]

--------------------------------------------------------------------------------
GATE CT-A — SYNTHETIC FIXTURE PROVISIONING
--------------------------------------------------------------------------------
Scope: Authorizes the creation of the minimum isolated synthetic fixtures 
required for Tenant A and Tenant B.

Authorized Boundaries:
- Synthetic Parent Users: Exactly 2 Auth users (Parent A, Parent B)
- Permitted Email Domain: Exclusively @internal-test.local
- Synthetic Families: Exactly 2 families (Family A, Family B)
- Synthetic Profiles: Exactly 2 parent profiles, up to 2 child profiles
- Synthetic Devices: Exactly 2 devices (Device A, Device B)
- Synthetic Child Data: Maximum 20 records per table (location, usage, alerts, audit)
- Data Content: 100% artificial test data with markers TENANT_A_ONLY / TENANT_B_ONLY
- Prohibited Accounts: Under no circumstances may spg7753@gmail.com, ankit@gmail.com,
  or ankit1@gmail.com be used, modified, or associated with this test.

[  ] APPROVED — Authorize Gate CT-A Provisioning
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
GATE CT-B — ADVERSARIAL CROSS-TENANT VERIFICATION
--------------------------------------------------------------------------------
Scope: Authorizes read-only HTTP invocations against the live account Edge 
Function using exclusively the newly provisioned test identities.

Authorized Boundaries:
- Permitted Endpoint Actions: "export" and "retention_report" ONLY
- Permitted Actors: User A, User B, Child A ONLY
- Cross-Tenant Probes:
  * User A requesting export (Baseline)
  * User B requesting export (Baseline)
  * User A injecting Family B ID into export request body
  * User B injecting Family A ID into export request body
  * User A injecting Family B ID into retention_report request body
  * Child A requesting export (Child role scope)
- Maximum HTTP Invocations: 15 total requests
- Expected Behavior: 100% read-only; zero database mutations; strict rejection
  or omission of foreign tenant data.
- Prohibited Actions: "delete", "delete_account", and "retention_cleanup" 
  are STRICTLY PROHIBITED.

[  ] APPROVED — Authorize Gate CT-B Invocations
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
GATE CT-C — CONTROLLED TEARDOWN & RECOVERY
--------------------------------------------------------------------------------
Scope: Authorizes the complete cascade teardown and cleanup of strictly the 
synthetic entities provisioned under Gate CT-A.

Authorized Boundaries:
- Target Allowlist: Strictly the explicit UUIDs created during Gate CT-A.
- Protected Account Denylist: Absolute abort if target matches protected accounts.
- Deletion Order:
  1. Delete synthetic audit logs matching correlation ID in metadata.
  2. Delete synthetic child records (location, usage, alerts) via family_id.
  3. Delete synthetic devices via family_id.
  4. Delete synthetic family members via family_id.
  5. Delete synthetic families via explicit UUID.
  6. Delete synthetic profiles and auth.users via explicit UUID.
- Prohibited Methods: Zero wildcard deletes; zero broad email prefix deletes.

[  ] APPROVED — Authorize Gate CT-C Teardown
[X] PENDING — NOT AUTHORIZED (Default)

--------------------------------------------------------------------------------
AUTHORIZATION SIGN-OFF
--------------------------------------------------------------------------------
Authorizing Owner: _____________________________________________
Owner Email: spg7753@gmail.com
Signature / Confirmation: _____________________________________
Date: _________________________________________________________
================================================================================
```
