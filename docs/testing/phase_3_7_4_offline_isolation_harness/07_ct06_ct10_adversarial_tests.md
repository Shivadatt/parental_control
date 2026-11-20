# Phase 3.7.4 — Report 07: Adversarial Isolation Scenarios CT-06 through CT-10

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Test Suite:** `supabase/functions/account/cross_tenant_isolation_test.ts`  
**Execution Mode:** STRICTLY LOCAL / OFFLINE  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report documents the design, execution, and verification of adversarial test scenarios **CT-06 through CT-10** as defined in Phase 3.7.2. These scenarios evaluate multi-membership query isolation, empty-scope fail-closed mechanics (`NO_MATCH_UUID`), injected device IDs, audit log sweep isolation, and pagination across interleaved records.

$$\mathbf{Status:\ CT-06\ through\ CT-10} = \mathbf{100\%\ PASSED\ (5/5)}$$

---

## 2. Detailed Scenario Analysis

### CT-06: Multi-Membership Scope Isolation
- **Objective:** Verify that when a parent belongs to multiple families (e.g. Family A and Family C), they receive data from both of their families, while foreign families (Family B) remain completely unreachable.
- **Setup:** User A possesses active memberships in Family A (`owner`) and Family C (`parent`). Family B belongs to Tenant B.
- **Request:** `POST /account` with `{"action": "export"}` authenticated as `USER_A_ID`.
- **Observed Results:**
  - `families`: Contains Family A and Family C. Zero references to Family B.
  - Telemetry: Contains rows from Family A and Family C. Exactly **0** rows from Family B.
- **Verdict:** **PASSED**.

### CT-07: Empty Scope Fail-Closed Verification (`NO_MATCH_UUID`)
- **Objective:** Verify that a user with a valid profile but zero active family memberships fails closed and triggers `NO_MATCH_UUID` (`00000000-0000-0000-0000-000000000000`) rather than executing an unconstrained query.
- **Setup:** `STRANGER_ID` possesses a valid auth token and profile, but 0 family memberships and 0 devices.
- **Request:** `POST /account` with `{"action": "export"}` authenticated as `STRANGER_ID`.
- **Observed Results:**
  - `scope`: `"not_reported"`.
  - Database calls: Executed `.eq("family_id", "00000000-0000-0000-0000-000000000000")`.
  - Exported arrays: All tables return empty arrays (`rows: []`, `row_count: 0`). Zero rows leaked.
- **Verdict:** **PASSED**.

### CT-08: Adversarial Injected Device ID in Export
- **Objective:** Verify that injecting a foreign `device_id` into the request body cannot force the function to export data from another tenant's device.
- **Adversarial Payload:** `{"action": "export", "device_id": DEVICE_B_ID, "injected_device": DEVICE_B_ID}` sent with Child A's token.
- **Observed Results:**
  - Handler behavior: Request body device parameters are ignored. For child callers, `devices` are loaded strictly via `loadOwnDeviceIds(db, callerUserId)` which filters `.eq("child_user_id", userId)`.
  - Result: Only `DEVICE_A_ID` rows are returned; `DEVICE_B_ID` data is never queried or returned.
- **Verdict:** **PASSED**.

### CT-09: Audit Log Query Isolation & Sweep Marker Leak Prevention
- **Objective:** Verify that global retention sweep markers (`family_id: null`) stored in `audit_logs` are never leaked in tenant export payloads.
- **Setup:** Database contains:
  1. Family A audit log (`family_id: FAMILY_A_ID`).
  2. Family B audit log (`family_id: FAMILY_B_ID`).
  3. Global sweep marker (`family_id: null`, `event_type: "retention_sweep"`).
- **Request:** `POST /account` with `{"action": "export"}` authenticated as `USER_A_ID`.
- **Observed Results:**
  - Export returned strictly 3 audit logs for Family A.
  - The global sweep marker (`audit-sweep-01`) was excluded because the query filters `.in("family_id", familyIds)`.
  - Foreign Family B audit logs were excluded.
- **Verdict:** **PASSED**.

### CT-10: Pagination & Row-Cap Isolation Across Interleaved Records
- **Objective:** Verify that explicit pagination (`range(from, from + 999)`) in `fetchCapped` preserves tenant isolation at page boundaries when records from different tenants are interleaved in the database.
- **Setup:** 1,050 Tenant A location events interleaved with 500 Tenant B location events.
- **Execution:**
  - Page 1: Fetched rows 0..999 (1,000 rows, all Tenant A).
  - Page 2: Fetched rows 1000..1049 (50 rows, all Tenant A).
- **Observed Results:**
  - `tables.location_events.row_count`: `1050`.
  - `tables.location_events.truncated`: `false`.
  - Exactly 1,050 rows returned, all belonging to Family A (`TENANT_A_PAGED`).
  - Exactly **0** Tenant B rows returned across both pages.
- **Verdict:** **PASSED**.

---

## 3. CT-06 to CT-10 Summary Table

| Scenario | Objective | Adversarial Vector | Verified Outcome | Verdict |
|---|---|---|---|:---:|
| **CT-06** | Multi-Family Scope | Member of multiple families | Sees own families; foreign hidden | **PASS** |
| **CT-07** | Empty Scope Fail-Closed | Zero family memberships | `NO_MATCH_UUID` activated; 0 leaks | **PASS** |
| **CT-08** | Injected Device ID | Body `{"device_id": "victim"}` | Injected param ignored; 0 leaks | **PASS** |
| **CT-09** | Audit Log & Sweep Marker | Global sweep row (`family_id: null`) | Sweep marker excluded from export | **PASS** |
| **CT-10** | Pagination Isolation | 1,050 rows interleaved with foreign | Multi-page boundary preserves 0 leaks | **PASS** |
