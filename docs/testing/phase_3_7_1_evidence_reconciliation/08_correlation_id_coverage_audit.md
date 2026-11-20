# Phase 3.7.1 — Report 08: Correlation ID Coverage & Traceability Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Active Correlation ID:** `run-20261120-e7f1`  
**Audit Execution Mode:** STRICTLY AUDIT-ONLY / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report audits the scope and depth of the correlation tracking identifier `run-20261120-e7f1` across all database entities, audit logs, and test artifacts.

$$\mathbf{Correlation\ Coverage\ Rating} = \mathbf{PARTIALLY\ DISTRIBUTED\ -\ LIMITED\ BY\ TABLE\ SCHEMAS}$$

The audit establishes that while the correlation ID is prominently stamped into user emails, family names, and family settings JSONB, it is **not a first-class database column** across core tables. Consequently, future automated cleanup (Gate 3) must trace relationships through foreign key joins rather than relying on a universal indexed column.

---

## 2. Multi-Entity Correlation Coverage Matrix

The table below assesses the presence, location, and cleanup traceability of the correlation marker across all 9 database record categories:

| Record Category | Correlation Marker Present? | Stamped Attribute / Field Location | Evidence Artifact | Future Cleanup Traceability |
|---|:---:|---|---|---|
| **1. Auth User** | **YES (Embedded)** | `email: ephemeral-parent-run-20261120-e7f1@internal-test.local` | Screenshot 03 / `gate2_results.json` | High — identifiable via `email ILIKE '%run-20261120-e7f1%'` query. |
| **2. Profile** | **YES (Embedded)** | `display_name: ephemeral-parent-run-20261120-e7f1` | Screenshot 04 / Export payload | High — links directly to Auth user via primary key `id`. |
| **3. Family** | **YES (Explicit JSONB)** | `name: Ephemeral QA Family run-20261120-e7f1`<br>`settings->>'test_correlation_id'` | Screenshot 07 / Export payload | Absolute — direct JSONB query `settings->>'test_correlation_id' = 'run-20261120-e7f1'`. |
| **4. Family Membership** | **NO (Implicit FK)** | Relies strictly on `family_id` and `user_id` foreign keys | Screenshot 08 / Export payload | High — cascades or resolves via `family_id` join. |
| **5. Devices** | **N/A (Zero Records)** | Zero synthetic devices created | Export payload (`devices: []`) | N/A — No device rows exist. |
| **6. Location Events** | **N/A (Zero Records)** | Zero synthetic events created | Export payload (`row_count: 0`) | N/A — No location rows exist. |
| **7. Usage Records** | **N/A (Zero Records)** | Zero synthetic records created | Export payload (`row_count: 0`) | N/A — No usage rows exist. |
| **8. Safety Alerts** | **N/A (Zero Records)** | Zero synthetic alerts created | Export payload (`row_count: 0`) | N/A — No alert rows exist. |
| **9. Audit Logs** | **PARTIAL (Risk Identified)** | Not tagged directly unless written to `details` JSONB | Export payload (`row_count: 0`) | Medium/Risk — If user/family is deleted with `ON DELETE SET NULL`, audit rows may become orphaned. |

---

## 3. Key Findings & Cleanup Limitations for Gate 3

1. **Absence of Universal Column:**
   `public.family_members`, `public.profiles`, and child tables do not possess a native `test_correlation_id` column. Marking is achieved through user emails, family names, and the `families.settings` JSONB field.
2. **Audit Log Orphan Risk:**
   If a user deletion is performed and the foreign key relationship is configured with `ON DELETE SET NULL`, the `audit_logs.actor_id` or `family_id` could become `NULL`, decoupling the audit record from the synthetic run. To prevent untraceable orphan logs during Gate 3, all deletion-related audit log entries must explicitly write `"correlation_id": "run-20261120-e7f1"` into the `metadata` JSONB column.
3. **Fail-Closed Cleanup Query Requirement:**
   Automated cleanup scripts must never perform open pattern deletes. They must target strictly the resolved UUIDs:
   - User UUID: `22a1dbb7-c4d9-4a3a-8481-e0d44871146d`
   - Family UUID: `cd5e2b6e-1a84-4bc6-a757-cd79600cd523`
