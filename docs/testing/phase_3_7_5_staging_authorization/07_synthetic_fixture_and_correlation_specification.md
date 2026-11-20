# Phase 3.7.5 — Report 07: Synthetic Fixture & Correlation Specification

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Environment:** Non-Production Staging Project (Proposed)  
**Execution Mode:** FIXTURE SPECIFICATION / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report defines the exact structural, arithmetic, and metadata specification for the proposed synthetic test fixtures to be deployed in staging under Gate CT-A. 

Using the corrected Phase 3.7.4 arithmetic, the fixture comprises exactly **40 total database rows** distributed evenly between two isolated tenants (Tenant A and Tenant B). Every record is bound to a unique test-run correlation identifier to enable audit trail verification and deterministic cleanup.

$$\mathbf{Fixture\ Volume} = \mathbf{20\ records\ (Tenant\ A)\ +\ 20\ records\ (Tenant\ B)\ =\ 40\ total\ rows}$$
$$\mathbf{Phase\ 3.7.5\ Execution\ Status} = \mathbf{PROPOSED\ —\ ZERO\ RECORDS\ PROVISIONED}$$

---

## 2. Reconciled Fixture Volume Breakdown

| Entity Layer | Table Name | Tenant A Count | Tenant B Count | Combined Total | Discrimination Marker |
|---|---|:---:|:---:|:---:|:---:|
| **Foundational** | `profiles` | 1 | 1 | 2 | `parent-a` vs `parent-b` |
| **Foundational** | `families` | 1 | 1 | 2 | `Family A` vs `Family B` |
| **Foundational** | `family_members` | 1 | 1 | 2 | `mem-a` vs `mem-b` |
| **Foundational** | `devices` | 1 | 1 | 2 | `Device A` vs `Device B` |
| **Child Data** | `location_events` | 5 | 5 | 10 | `TENANT_A_ONLY` vs `TENANT_B_ONLY` |
| **Child Data** | `usage_daily` | 5 | 5 | 10 | `TENANT_A_ONLY` vs `TENANT_B_ONLY` |
| **Child Data** | `safety_alerts` | 3 | 3 | 6 | `TENANT_A_ONLY` vs `TENANT_B_ONLY` |
| **Audit / Ops** | `audit_logs` | 3 | 3 | 6 | `TENANT_A_ONLY` vs `TENANT_B_ONLY` |
| **Totals** | | **20** | **20** | **40** | **100% Partitioned** |

---

## 3. Synthetic Identity & Coordinate Isolation

### 3.1 Synthetic Email Namespace
All identities must strictly reside under the non-routable test namespace:
- Tenant A Parent: `parent-a-<short_hex>@internal-test.local`
- Tenant B Parent: `parent-b-<short_hex>@internal-test.local`

Operational accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`) are denylisted and must never be referenced.

### 3.2 Geographic & Coordinate Fencing
To prevent synthetic telemetry from resembling any real human movement:
- **Tenant A Coordinates:** Seeded in the middle of the Pacific Ocean (`lat: 0.0001, lon: -160.0001`).
- **Tenant B Coordinates:** Seeded in the middle of the Indian Ocean (`lat: -10.0001, lon: 75.0001`).
- Neither tenant shares any coordinate bounding box.

---

## 4. Run Identifier & Correlation Design

### 4.1 Correlation ID Format
The proposed test-run correlation identifier follows the strict format:
$$\mathbf{Correlation\ ID} = \mathbf{ct-isolation-YYYYMMDD-<short\_random\_suffix>}$$
*Example:* `ct-isolation-20261121-f8a2`

The random suffix must be generated fresh upon explicit CT-A authorization.

### 4.2 Metadata Stamping
Every record that supports extensible metadata or tagging must embed the correlation ID:
- `families.settings`: `{"correlation_id": "<CORRELATION_ID>", "tenant": "A", "location_retention_days": 30}`
- `audit_logs.metadata`: `{"correlation_id": "<CORRELATION_ID>", "marker": "TENANT_A_ONLY"}`
- `devices.display_name`: `Test Device A (<CORRELATION_ID>)`

This allows deterministic post-test query filtering and prevents orphaned records from escaping subsequent cleanup.
