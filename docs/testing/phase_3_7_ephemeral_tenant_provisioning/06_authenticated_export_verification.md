# Phase 3.7 — Report 06: Authenticated Account Export Verification & Preflight Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Action:** `export`  
**Audit Date:** 2026-11-20  

---

## 1. Execution Gate Status: BLOCKED

In accordance with Phase 3.7 Section 2 and Section 7:
> *"Gate 2 — Read-Only Verification Approval must explicitly authorize authenticated invocation of the production account function... If Gate 1 is missing, do not provision or invoke authenticated endpoints."*

Because Gate 1 was not provisioned and Gate 2 written approval was not granted, **zero live authenticated HTTP calls were sent to the production endpoint**.

$$\mathbf{Gate\ 2\ Live\ Export\ Status} = \mathbf{BLOCKED\ -\ AWAITING\ OWNER\ AUTHORIZATION}$$

---

## 2. Source-Level Verification of Export Handlers

The export implementation in `index.ts` lines 227–343 was audited to verify compliance with GDPR data portability, secret sanitization, and pagination safety.

### 1. Identity & Tenant Scoping
- Caller identity is derived exclusively from `requireUser(req, db)`, which extracts `auth.user.id` from the GoTrue verified JWT.
- In `exportAccount`:
  ```ts
  const memberships = await loadActiveMemberships(db, userId);
  const familyIds = memberships.map((m) => m.family_id);
  ```
  The caller can only ever query families they actively belong to. Unrelated production families are physically omitted from `familyIds`.

### 2. Secret Material Sanitization
In `index.ts` lines 63–86, `DEVICE_COLUMNS` defines the exact SQL projection for the `devices` table:
```ts
const DEVICE_COLUMNS = [
  "id", "family_id", "child_user_id", "installation_id", "display_name",
  "platform", "android_version", "app_version", "status", "last_seen_at",
  "battery_level", "is_charging", "enforcement_mode", "policy_version",
  "usage_access_granted", "location_granted", "background_location_granted",
  "camera_granted", "microphone_granted", "notifications_granted",
  "created_at", "updated_at",
].join(", ");
```
- **Finding:** Critical credential hashes (`secret_hash`) and credential revocation tokens are **100% excluded** from the export projection.

### 3. Paging Bounds & Denial-of-Service Protection
- `EXPORT_PAGE_SIZE = 1,000`: Queries are chunked in increments of 1,000 rows to respect PostgREST buffer caps.
- `EXPORT_ROW_CAP = 20,000`: Hard safety cap preventing unbounded heap memory consumption.
- If a table contains $> 20,000$ rows, output truncates cleanly with `truncated: true`.

---

## 3. Offline Verification Baseline

Offline unit test `deletion_test.ts` (Test 15: `Existing account export behavior`) passed cleanly in 2ms, confirming that:
- Scope is correctly marked `family`.
- Telemetry tables (`location_events`, `usage_daily`, `safety_alerts`, `audit_logs`) are packaged in the standard schema.
- Response includes `limits: { max_rows_per_table: 20000 }`.
