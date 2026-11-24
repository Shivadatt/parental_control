# Phase 2.5 — All 10 Edge Functions Authorization & Isolation Matrix

**Document ID:** `HAVEN-GOV-PHASE2-5-EDGE-AUTH`  
**Phase:** Phase 2.5 — Final Governance Traceability & Owner Authorization Consistency Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Comprehensive Function-by-Function Static Security & Multi-Tenant Isolation Audit  
**Execution Posture:** STRICTLY READ-ONLY — ZERO NETWORK CALLS  

---

## 1. Security Context: Service-Role Initialization vs Application Isolation

In Supabase architectures, database interactions from Edge Functions are executed via an instantiated `SupabaseClient`. 

Source inspection of `supabase/functions/_shared/auth.ts:60–75` verifies that **all Edge Functions instantiate their database client via `getServiceClient()` using `SUPABASE_SERVICE_ROLE_KEY`**:

```typescript
// supabase/functions/_shared/auth.ts:60-75
export function getServiceClient(): SupabaseClient {
  if (cachedClient) return cachedClient;
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  cachedClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "X-Client-Info": "parentcontrol-edge/1" } },
  });
  return cachedClient;
}
```

### 1.1 The Crucial Architectural Distinction
1. **PostgreSQL RLS is Bypassed**: Any query executed with the service-role super-user key **completely bypasses PostgreSQL Row-Level Security policies**. Database-level RLS does NOT protect tenant data during Edge Function execution.
2. **Application-Level Isolation Enforced**: Tenant isolation relies **entirely upon Deno TypeScript application logic**.
3. **Core Audit Objective**: Verify whether every function strictly enforces caller authentication, membership checks, and query/mutation scoping in Deno code before executing database mutations.

---

## 2. Master 10-Function Authorization Matrix

The table below documents the static code inspection results across all 10 deployable Edge Functions:

| Function Directory | Service Role Used? | User JWT Validated? | Family Membership Checked? | Device Ownership Validated? | Database Query Scoping | Database Mutation Scoping | Final Static Assessment | Source Evidence Path |
| :--- | :---: | :---: | :---: | :---: | :--- | :--- | :---: | :--- |
| **`account`** | **YES** | **YES** (`requireUser`) | **YES** (Caller memberships loaded) | **YES** (Caller child devices checked) | Scoped to caller's `user.id` | Scoped to caller's owned profiles & families | **`VERIFIED`** | `account/index.ts:180–350`, `deletion.ts:282` |
| **`auth-bootstrap`** | **YES** | **YES** (`requireUser`) | **YES** (Initializes owned family) | **N/A** (Pre-device registration) | Scoped to caller's `auth.uid` | Mutates only caller's profile row | **`VERIFIED`** | `auth-bootstrap/index.ts:35–110` |
| **`cron`** | **YES** | **NO** (System cron header) | **NO** (System maintenance) | **NO** (System maintenance) | **UNSCOPED / GLOBAL** (All families) | **UNSCOPED / GLOBAL** (Deletes logs/signals) | **`CONTRADICTED (UNSCOPED)`** | `cron/index.ts:40–120` |
| **`device-command`** | **YES** | **YES** (Parent) / Secret (Child) | **YES** (`requireActiveDeviceForParent`) | **YES** (Constant-time token hash) | Scoped to `device.family_id` | Mutates commands for target device only | **`VERIFIED`** | `device-command/handler.ts:45–180` |
| **`device-policy`** | **YES** | **YES** (`requireUser` Parent) | **YES** (`requireActiveDeviceForParent`) | **YES** (Active device check) | Scoped to verified family & device | Atomic RPC enforces family boundary | **`VERIFIED`** | `device-policy/index.ts:35–120` |
| **`device-register`** | **YES** | **YES** (`requireUser` Child) | **YES** (`assertChildMembership`) | **YES** (Pairing token validation) | Scoped to child's family | Binds device to child's family & user | **`VERIFIED`** | `device-register/index.ts:45–160` |
| **`device-telemetry`**| **YES** | **NO** (Device Header Secret) | **YES** (Device row loads `family_id`) | **YES** (Constant-time SHA-256 hash) | Scoped to `device.family_id` | Appends telemetry for authorized device | **`VERIFIED`** | `device-telemetry/index.ts:40–180` |
| **`family-admin`** | **YES** | **YES** (`requireRole("parent")`) | **YES** (`assertFamilyParent` / `Owner`) | **YES** (Device membership in family) | Scoped to verified `familyId` | Purges/mutates only target family data | **`VERIFIED`** | `family-admin/index.ts:50–290` |
| **`pairing`** | **YES** | **YES** (`requireUser`) | **YES** (`assertFamilyParent` on create) | **YES** (One-time pairing token) | Scoped to caller's family | Updates pairing token status | **`VERIFIED`** | `pairing/index.ts:45–180` |
| **`remote-session`** | **YES** | **YES** (Parent) / Secret (Child) | **YES** (`requireActiveDeviceForParent`) | **YES** (Active session member check) | Scoped to active session participants | Atomic RPC controls session state | **`VERIFIED`** | `remote-session/index.ts:40–200` |

---

## 3. Function-by-Function Forensic Findings

### 3.1 Standard User & Device Endpoints (9 Functions)
For nine of the ten functions, static code verification confirms that Deno application logic enforces strict multi-tenant boundaries:
1. **Identity Extraction**: Identity is never taken from request body parameters; it is extracted directly from the verified Supabase Auth JWT (`auth.user.id`) or verified device secret header.
2. **Device Authentication**: Devices authenticate via `x-device-id` and `x-device-secret`. Secrets are hashed with SHA-256 and compared using constant-time string comparison (`crypto.subtle.timingSafeEqual`) to prevent timing attacks (`_shared/auth.ts:115–140`).
3. **Role & Membership Enforcement**: Parent functions enforce `requireRole("parent")` and query `family_members` to ensure the caller has active parent status in the target family before allowing any mutation.
4. **Query & Mutation Scoping**: All database updates and deletes are explicitly filtered with `.eq("family_id", familyId)` or `.eq("user_id", userId)`.

### 3.2 The Global Retention Hazard: `cron`
The `cron` Edge Function represents an unscoped administrative maintenance task:
- It requires `x-cron-secret` compared constant-time against `Deno.env.get("CRON_SECRET")`.
- When invoked with `action: "retention_sweep"`, it executes `db.rpc("run_retention_sweep")`.
- Inspection of `20261030000300_retention_sweep.sql:116–250` proves that `public.run_retention_sweep()`:
  - Purges `webrtc_signals` older than 7 days across **all families**.
  - Purges `audit_logs` older than 365 days across **all families**.
  - Loops globally through all families without `family_id` partition.
- **Risk Assessment**: If triggered on Pathway B (shared production backend), `cron` will permanently delete real customer telemetry and audit records.
- **Enforcement Rule**: `cron` retention sweep (`AUD04`) must remain **STRICTLY PROHIBITED ON PATHWAY B**.

---

## 4. Evidentiary Synthesis

```
====================================================================================================
                        EDGE FUNCTION AUTHORIZATION AUDIT SUMMARY
====================================================================================================
Total Functions Audited:                         10
  • Service-Role Database Client Used:           10 / 10 (100.0%) [Database RLS is bypassed]
  • User-Facing / Device-Facing Endpoints:        9 / 10 ( 90.0%)
  • Administrative Maintenance Endpoints:         1 / 10 ( 10.0%) [`cron`]

Static Authorization Assessment:
  • VERIFIED (Application-Level Multi-Tenancy):   9 / 10 ( 90.0%) [All user/device endpoints]
  • CONTRADICTED (Unscoped Global Sweeps):        1 / 10 ( 10.0%) [`cron` retention sweep]

Operational Conclusion:
  - User-facing Edge Functions are safe for Pathway B testing if properly scoped in test scripts.
  - cron retention sweep (AUD04) is strictly incompatible with Pathway B and must be quarantined.
  - Live runtime tenant isolation cannot be declared runtime-proven until Phase 3 test execution.
====================================================================================================
```
