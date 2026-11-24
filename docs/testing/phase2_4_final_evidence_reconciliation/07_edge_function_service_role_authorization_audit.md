# Phase 2.4 — Edge Function Service-Role Authorization Static Audit

**Document ID:** `HAVEN-GOV-PHASE2-4-EDGE`  
**Phase:** Phase 2.4 — Final Evidence Reconciliation & Governance Correction Audit  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Comprehensive Function-by-Function Static Security & Authorization Audit  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Security Architecture & RLS Bypass Context

In Supabase Edge Functions, database interactions occur via an instantiated `SupabaseClient`. 

Source inspection of `supabase/functions/_shared/auth.ts:60–75` confirms that all Edge Functions instantiate the database client using `getServiceClient()`:
```typescript
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

### 1.1 The Security Implication
1. **Database RLS Bypass**: In PostgreSQL, any client authenticated with `SUPABASE_SERVICE_ROLE_KEY` **completely bypasses Row-Level Security**.
2. **Application-Level Responsibility**: Multi-tenant isolation is not enforced by PostgreSQL RLS for Edge Function queries. Instead, isolation depends **entirely upon Deno TypeScript application code**.
3. **Audit Question**: Does each Edge Function properly authenticate the caller, validate family membership, and scope every query to the caller's authorized tenant?

---

## 2. Function-by-Function Static Authorization Matrix (All 10 Deployable Functions)

The following matrix documents the exact authorization mechanics across all 10 Edge Functions:

| Function Name | Client Type | DB RLS Bypass? | Identity & Auth Check | Family Scoping Check | Device Scoping Check | Query & Mutation Scoping | Inherent Multi-Tenant Risk | Static Audit Verdict | Evidence Path |
| :--- | :---: | :---: | :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **`account`** | Service Role | **YES** | `requireUser` / `requireAuthUser` via JWT | Caller memberships loaded via `user_id` | Caller devices loaded via `child_user_id` | Scoped to caller's owned families & profile | Moderate (Account deletion) | **VERIFIED APPLICATION ISOLATION** | `account/index.ts:180–350`, `deletion.ts:282` |
| **`auth-bootstrap`** | Service Role | **YES** | `requireUser` via JWT | Creates family with `owner_id = user.id` | N/A | Mutates only caller's profile (`id = auth.uid`) | Low | **VERIFIED APPLICATION ISOLATION** | `auth-bootstrap/index.ts:35–110` |
| **`cron`** | Service Role | **YES** | `constantTimeSecretEqual` vs `CRON_SECRET` | **NONE** (System-level cron) | **NONE** | **UNSCOPED / GLOBAL** (Executes `run_retention_sweep`) | **CRITICAL (Global Sweeps)** | **PROHIBITED ON PATHWAY B** | `cron/index.ts:40–120` |
| **`device-command`**| Service Role | **YES** | `requireUser` (Parent) or `requireDevice` | `requireActiveDeviceForParent` validates family | `requireDevice` constant-time secret | Scoped to `device.family_id` and `device.id` | Low | **VERIFIED APPLICATION ISOLATION** | `device-command/handler.ts:45–180` |
| **`device-policy`** | Service Role | **YES** | `requireUser` (Parent) | `requireActiveDeviceForParent(db, uid, devId)` | Checks device is active | Calls atomic policy RPC with family verification | Low | **VERIFIED APPLICATION ISOLATION** | `device-policy/index.ts:35–120` |
| **`device-register`**| Service Role | **YES** | `requireUser` (Child) | `assertChildMembership(db, uid, familyId)` | Checks pairing token | Binds device to child's family and user ID | Low | **VERIFIED APPLICATION ISOLATION** | `device-register/index.ts:45–160` |
| **`device-telemetry`**| Service Role | **YES** | `requireDevice` (Header secret) | Device row loads `family_id` | Constant-time SHA-256 secret verification | Telemetry writes scoped to `device.family_id` | Low | **VERIFIED APPLICATION ISOLATION** | `device-telemetry/index.ts:40–180` |
| **`family-admin`** | Service Role | **YES** | `requireUser` + `requireRole("parent")` | `assertFamilyOwner` / `assertFamilyParent` | Validates device in family | `purge_data` scoped by `.eq("family_id", familyId)` | High (Purge & revoke) | **VERIFIED APPLICATION ISOLATION** | `family-admin/index.ts:50–290` |
| **`pairing`** | Service Role | **YES** | `requireUser` (Parent or Child) | `assertFamilyParent` on create/cancel | Token-based pairing | Scoped by pairing invitation token & family | Low | **VERIFIED APPLICATION ISOLATION** | `pairing/index.ts:45–180` |
| **`remote-session`**| Service Role | **YES** | `requireUser` (Parent) or `requireDevice` | `requireActiveDeviceForParent` | Verified against active session | Calls RPC enforcing participant authorization | Low | **VERIFIED APPLICATION ISOLATION** | `remote-session/index.ts:40–200` |

---

## 3. Security Findings & Architectural Synthesis

### 3.1 Standard User & Device Endpoints Are Strictly Isolated in Application Code
For nine of the ten Edge Functions (`account`, `auth-bootstrap`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`), **tenant isolation is rigorously enforced in Deno TypeScript**:
- User identity is extracted from verified Supabase Auth JWTs (`auth.user.id`), never trusted from request body parameters.
- Device identity requires both `x-device-id` and `x-device-secret`, compared constant-time against stored SHA-256 hashes (`requireDevice`).
- Parent operations require explicit family membership and ownership checks (`assertFamilyParent`, `assertFamilyOwner`).
- Mutations are parameterized with `.eq("family_id", familyId)` or executed via RPCs that re-verify membership.

### 3.2 The Sole Unscoped Threat: `cron` Maintenance Sweeps
The only Edge Function that lacks tenant scoping is **`cron`**:
- When invoked with `x-cron-secret` and action `retention_sweep`, it executes `db.rpc("run_retention_sweep")`.
- `public.run_retention_sweep()` sweeps and deletes data across **every single family in the database**.
- This proves that while user-facing Edge Functions are safe for Pathway B, the `cron` maintenance sweeps are **strictly incompatible with a shared production database**.
