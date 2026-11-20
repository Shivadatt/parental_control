# Phase 3.7.3 — Report 07: Offline Synthetic Fixture Preflight & Table Distribution

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report performs an independent, offline preflight validation of the synthetic fixture dataset designed in Phase 3.7.2. The analysis validates record counts, required fields, foreign-key relationships, and PostgreSQL check constraints against `supabase/migrations/20260101000000_core.sql`.

$$\mathbf{Fixture\ Validation\ Status} = \mathbf{100\%\ SCHEMA-COMPLIANT\ -\ ZERO\ PII\ -\ FULLY\ VALIDATED}$$

---

## 2. Table-by-Table Fixture Count & Field Distribution

Phase 3.7.2 Report 04 proposed a fixture baseline. The table below presents the exact distribution reconciling foundational tenant entities with child-data records:

| Record Category | Tenant A Count | Tenant B Count | Required Fields Verified | Dependency & Relationship Verified | Schema Constraints Satisfied |
|---|:---:|:---:|---|---|:---:|
| **Parent / Profile** | 1 | 1 | `id`, `role`, `display_name` | Linked to Auth UID via primary key | `role = 'parent'` check satisfied |
| **Family** | 1 | 1 | `id`, `name`, `owner_id`, `settings` | `owner_id REFERENCES profiles(id)` | Settings JSONB valid |
| **Family Membership** | 1 | 1 | `id`, `family_id`, `user_id`, `role`, `status` | `family_id` + `user_id` FKs | `status = 'active'`, `role = 'parent'` |
| **Synthetic Device** | 1 | 1 | `id`, `family_id`, `child_user_id`, `installation_id`, `display_name`, `platform`, `status` | `family_id` + `child_user_id` FKs | `char_length(installation_id) >= 8` |
| **Location Events** | 5 | 5 | `id`, `device_id`, `family_id`, `lat`, `lng`, `accuracy_m`, `recorded_at`, `source` | `device_id` + `family_id` FKs | `lat BETWEEN -90 AND 90`<br>`lng BETWEEN -180 AND 180` |
| **Usage Records** | 5 | 5 | `id`, `device_id`, `family_id`, `day`, `package_name`, `app_label`, `total_ms`, `source` | `device_id` + `family_id` FKs | `total_ms >= 0`, `char_length <= 150` |
| **Safety Alerts** | 3 | 3 | `id`, `family_id`, `device_id`, `type`, `severity`, `message`, `payload` | `family_id` + `device_id` FKs | `type IN ('low_battery', ...)`, `severity IN (...)` |
| **Audit Events** | 3 | 3 | `id`, `family_id`, `actor_user_id`, `device_id`, `event_type`, `target_type`, `metadata` | `family_id`, `actor_user_id` FKs | `jsonb_typeof(metadata) = 'object'` |
| **TOTALS** | **20** | **20** | **All 8 Tables Verified** | **Complete Graph Intact** | **100% Constraints Satisfied** |

*(Note: The total of 20 records per tenant consists of exactly 17 child-data records plus 3 foundational tenant entities: profile, family, and membership).*

---

## 3. Strict Data Minimization & Marker Verification

1. **Unambiguous Discrimination:**
   - Every text field for Tenant A contains the literal string `TENANT_A_ONLY`.
   - Every text field for Tenant B contains the literal string `TENANT_B_ONLY`.
2. **Artificial Ocean Coordinates (Zero Real Locations):**
   - Tenant A coordinates: `lat: 10.0001, lng: -20.0001` (Atlantic Ocean).
   - Tenant B coordinates: `lat: 20.0002, lng: -140.0002` (Pacific Ocean).
   - No GPS coordinate corresponds to any real physical residence, school, or commercial building.
3. **Synthetic Package Names:**
   - `com.synthetic.qa.app.TENANT_A_ONLY`
   - `com.synthetic.qa.app.TENANT_B_ONLY`
   - No real commercial application packages are referenced.
4. **Zero Operational User Coupling:**
   - Under no condition does any fixture foreign key link to `spg7753@gmail.com`, `ankit@gmail.com`, or `ankit1@gmail.com`.
