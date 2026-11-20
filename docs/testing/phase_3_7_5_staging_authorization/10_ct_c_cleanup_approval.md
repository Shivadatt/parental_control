# Phase 3.7.5 — Report 10: Gate CT-C — Staging Cleanup Authorization Package

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Environment:** Staging Database Only (`parent-control-staging`)  
**Gate Status:** `PENDING — NO CLEANUP AUTHORIZED`  
**Prerequisite:** Full completion of Gate CT-B and independent post-test inventory reconciliation  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report establishes the standalone authorization specification for **Gate CT-C (Controlled Staging Cleanup)**. Gate CT-C authorizes the targeted removal of synthetic test records and Auth identities created during Gate CT-A, following the successful completion and reconciliation of Gate CT-B.

$$\mathbf{Gate\ CT-C\ Initial\ State} = \mathbf{PENDING\ —\ NO\ CLEANUP\ AUTHORIZED}$$
$$\mathbf{Scope\ Boundary} = \mathbf{EXACT\ SYNTHETIC\ RECORD\ REMOVAL\ ONLY\ (NO\ PRODUCTION)}$$

---

## 2. Gate CT-C Mandatory Safeguards & Rules

To prevent accidental data loss or overbroad deletion:
1. **Explicit Identity Matching:** Records may only be deleted by exact primary key UUID and correlation identifier (`ct-isolation-...`).
2. **Reverse Dependency Order:** Deletion must execute strictly in reverse relational dependency order to respect foreign key constraints:
   $$1.\ \text{Telemetry}\ (\text{location, usage, alerts}) \longrightarrow 2.\ \text{Devices} \longrightarrow 3.\ \text{Memberships} \longrightarrow 4.\ \text{Families} \longrightarrow 5.\ \text{Profiles} \longrightarrow 6.\ \text{Auth Users}$$
3. **Protected Account Denylist:** Operational accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`) and production tenant `run-20261120-e7f1` are permanently denylisted.
4. **Pre-Cleanup Dry Run:** A dry-run report must list every UUID slated for deletion before execution.
5. **Post-Cleanup Verification:** A verification query must confirm that exactly 0 synthetic test rows remain and 0 unrelated rows were modified.

### Prohibited Cleanup Patterns
Gate CT-C strictly prohibits:
- Table truncation (`TRUNCATE TABLE ...`).
- Wildcard deletions (`DELETE FROM ... WHERE email LIKE '%test%'`).
- Production cleanup (production tenant `run-20261120-e7f1` is not affected).
- Automated cron / TTL sweepers.

---

## 3. Copy-Ready Gate CT-C Approval Document

```text
================================================================================
GATE CT-C APPROVAL: CONTROLLED STAGING CLEANUP
================================================================================

Project: Parent Control App
Target Staging Project Name: parent-control-staging
Target Staging Ref: [CONFIRMED STAGING REF — NOT hhqgreaoqulmfwfwarhc]
Protected Production Ref: hhqgreaoqulmfwfwarhc (STRICTLY PROHIBITED)

PREREQUISITE VERIFICATION:
- Gate CT-B Adversarial Testing Completed: YES / NO
- Pre-Cleanup Dry-Run Inventory Reconciled: YES / NO
- All 40 Fixture UUIDs Confirmed: YES / NO

AUTHORIZED CLEANUP ACTIONS:
- Correlation ID: [EXACT MATCH ct-isolation-YYYYMMDD-<short_hex>]
- Target Records Authorized for Removal (in exact reverse dependency order):
  1. location_events: Exactly 10 rows matching correlation ID
  2. usage_daily: Exactly 10 rows matching correlation ID
  3. safety_alerts: Exactly 6 rows matching correlation ID
  4. audit_logs: Exactly 6 synthetic test rows matching correlation ID
  5. devices: Exactly 2 synthetic device UUIDs
  6. family_members: Exactly 2 synthetic membership UUIDs
  7. families: Exactly 2 synthetic family UUIDs
  8. profiles: Exactly 2 synthetic profile UUIDs
  9. auth.users: Exactly 2 synthetic GoTrue user UUIDs via Admin API

EXPLICIT PROHIBITIONS:
- Production Deletion: STRICTLY PROHIBITED.
- Broad Truncation: STRICTLY PROHIBITED.
- Operational Account Touching: STRICTLY PROHIBITED.

APPROVAL STATUS:
[  ] APPROVED — Authorize Gate CT-C Controlled Cleanup
[X] PENDING — NOT AUTHORIZED (Default)

Authorized By: __________________________   Date: ____________________
================================================================================
```
