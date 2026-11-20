# Phase 3.7.4 — Report 03: Fixture Arithmetic & Entity Reconciliation

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` Edge Function  
**Execution Mode:** STRICTLY LOCAL / OFFLINE  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report provides the mathematical and structural reconciliation of synthetic test fixture entities per tenant. In Phase 3.7.2 and 3.7.3 documentation, colloquial summaries referred to "17 child data rows + 3 foundational entities" (total 20). 

A rigorous database schema audit reveals that `devices` is a foundational entity rather than child telemetry. Therefore, the precise classification per tenant is:
$$\mathbf{Foundational\ Entities} = 4 \quad (\text{Parent Profile, Family, Family Membership, Device})$$
$$\mathbf{Child\ Data\ \&\ Audit\ Rows} = 16 \quad (\text{Location 5, Usage 5, Safety Alerts 3, Audit Logs 3})$$
$$\mathbf{Total\ Records\ Per\ Tenant} = 4 + 16 = \mathbf{20\ records}$$

---

## 2. Table-by-Table Entity Breakdown

### 2.1 Foundational Entities (4 Records Per Tenant)
These records establish tenant identity, ownership, and device pairing:

| Table Name | Count | Key Attributes | Role in Tenant Structure |
|---|:---:|---|---|
| `profiles` | 1 | `id`, `role: 'parent'`, `display_name` | Root identity in Supabase application schema |
| `families` | 1 | `id`, `name`, `owner_id`, `settings` | Tenant isolation boundary |
| `family_members` | 1 | `family_id`, `user_id`, `role: 'parent'`, `status: 'active'` | Links user to family tenant |
| `devices` | 1 | `id`, `family_id`, `child_user_id`, `status: 'active'` | Physical device registered under family |
| **Subtotal** | **4** | **Foundational Structure** | **Base Tenant Footprint** |

### 2.2 Child Data & Audit Telemetry (16 Records Per Tenant)
These records represent high-volume telemetry and operational logs subject to retention and export queries:

| Table Name | Count | Schema Columns Verified | Role in Testing |
|---|:---:|---|---|
| `location_events` | 5 | `id`, `family_id`, `device_id`, `recorded_at`, `lat`, `lon` | Geospatial location breadcrumbs |
| `usage_daily` | 5 | `id`, `family_id`, `device_id`, `day`, `package_name`, `screen_time_seconds` | Aggregated app screen time |
| `safety_alerts` | 3 | `id`, `family_id`, `device_id`, `alert_type`, `severity`, `created_at` | Geofence and tamper alerts |
| `audit_logs` | 3 | `id`, `family_id`, `actor_user_id`, `device_id`, `event_type`, `created_at` | Security and administration events |
| **Subtotal** | **16** | **Child Data & Telemetry** | **Data Isolation Targets** |

$$\mathbf{Total\ Per\ Tenant} = 4 + 16 = \mathbf{20\ rows}$$

---

## 3. Two-Tenant Test World Population

In `supabase/functions/account/cross_tenant_isolation_test.ts`, the full test world is initialized with:
- **Tenant A (Authorized):** 20 records (4 foundational + 16 child/audit data stamped `TENANT_A_ONLY`).
- **Tenant B (Victim):** 20 records (4 foundational + 16 child/audit data stamped `TENANT_B_ONLY`).
- **Additional Controlled Entities for Edge Cases:**
  - `CHILD_A_ID` profile and membership (for child role isolation testing CT-05).
  - `STRANGER_ID` profile with 0 memberships (for empty-scope fail-closed testing CT-07).
  - `INACTIVE_USER_ID` profile with suspended membership (for revocation testing CT-04).
  - `FAMILY_C_ID` secondary family (for multi-membership testing CT-06).
  - 1 project-wide retention sweep marker with `family_id: null` (for audit log isolation CT-09).

This establishes an unambiguous, deterministic baseline for verifying that query filters never bleed across tenant boundaries.
