# Phase 2.6 — All 10 Edge Functions Security Evidence Reconciliation

**Document ID:** `HAVEN-GOV-PHASE2-6-EDGE-SECURITY`  
**Phase:** Phase 2.6 — Final Governance Defect Correction & Evidence Closure Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Comprehensive Function-by-Function Static Security & Authorization Audit  
**Execution Posture:** STRICTLY READ-ONLY — ZERO NETWORK CALLS  
**Overall Security Verdict:** STATICALLY VERIFIED — RUNTIME SECURITY UNVERIFIED  

---

## 1. Security Baseline & Verified Helper Line References

A core objective of Phase 2.6 is to verify the actual current source code line numbers of the shared authentication and database client helpers.

### 1.1 Verified Location of `getServiceClient()`
Source inspection of [supabase/functions/_shared/auth.ts:52–68](file:///d:/parentcontrol_app/supabase/functions/_shared/auth.ts#L52-L68) confirms:

```typescript
// supabase/functions/_shared/auth.ts:52-68 (Actual Current Lines)
/** Service-role client. Called only from Edge Functions server-side. */
export function getServiceClient(): SupabaseClient {
  if (cachedClient) return cachedClient;
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new ApiError(
      "server_misconfigured",
      "The backend is missing required server configuration.",
      503,
    );
  }
  cachedClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "X-Client-Info": "parentcontrol-edge/1" } },
  });
  return cachedClient;
}
```

### 1.2 The Architectural Fact: PostgreSQL RLS Bypass
- Every Edge Function interacts with the database via `getServiceClient()`.
- Because `SUPABASE_SERVICE_ROLE_KEY` has the PostgreSQL superuser role, **PostgreSQL Row-Level Security (RLS) is 100% bypassed**.
- **Security Consequence**: Multi-tenant safety is not enforced by database policies; it depends entirely upon the Deno TypeScript application layer.

---

## 2. Comprehensive 10-Function Security Evidence Matrix

The table below reconciles the exact security controls across all 10 deployable Edge Functions:

| Function Name | Entry Point | Auth Mechanism | Identity Extraction | Membership & Scope Validation | Database Query & Mutation Scoping | Destructive Capability | Service-Role RLS Bypass? | Static Audit Classification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: | :---: |
| **`account`** | `account/index.ts` | Supabase Auth JWT (`requireUser` / `requireAuthUser`) | `auth.user.id` | Profile row + family ownership checks | Scoped to caller's `user.id` & owned families | Account & profile deletion (`deletion.ts`) | **YES** | `STATICALLY_VERIFIED` |
| **`auth-bootstrap`** | `auth-bootstrap/index.ts`| Supabase Auth JWT (`requireUser`) | `auth.user.id` | Profile row role check; creates owned family | Mutates caller profile (`id = auth.uid`) | None | **YES** | `STATICALLY_VERIFIED` |
| **`cron`** | `cron/index.ts` | Header Secret (`x-cron-secret`) | System Cron | **NONE** (System-level cron task) | **UNSCOPED / GLOBAL** (All families swept) | Global purge of audit logs & WebRTC signals | **YES** | **`CONTRADICTED (UNSCOPED)`** |
| **`device-command`** | `device-command/handler.ts`| Dual: JWT (Parent) or Device Secret (Child) | JWT `uid` or `x-device-id` | `requireActiveDeviceForParent` or constant-time token | Scoped to verified `device.family_id` & `device.id` | Reboots, lock commands | **YES** | `STATICALLY_VERIFIED` |
| **`device-policy`** | `device-policy/index.ts` | Supabase Auth JWT (`requireUser` Parent) | JWT `uid` | `requireActiveDeviceForParent(db, uid, devId)` | Policy RPC enforces family & device boundary | Overwrites active policy version | **YES** | `STATICALLY_VERIFIED` |
| **`device-register`** | `device-register/index.ts`| Supabase Auth JWT (`requireUser` Child) | JWT `uid` | `assertChildMembership(db, uid, familyId)` | Binds device to child's family & user ID | Device registration | **YES** | `STATICALLY_VERIFIED` |
| **`device-telemetry`**| `device-telemetry/index.ts`| Header Secret (`requireDevice`) | `x-device-id` | Device row loads `family_id`; token hash checked | Telemetry writes scoped to `device.family_id` | None (Append-only telemetry) | **YES** | `STATICALLY_VERIFIED` |
| **`family-admin`** | `family-admin/index.ts` | Supabase Auth JWT (`requireRole("parent")`) | JWT `uid` | `assertFamilyParent` / `assertFamilyOwner` | Explicit `.eq("family_id", familyId)` filters | Family data purge (`purge_data`) | **YES** | `STATICALLY_VERIFIED` |
| **`pairing`** | `pairing/index.ts` | Supabase Auth JWT (`requireUser`) | JWT `uid` | `assertFamilyParent` on creation/cancellation | Scoped by pairing invitation token & family | Revokes pairing codes | **YES** | `STATICALLY_VERIFIED` |
| **`remote-session`** | `remote-session/index.ts` | Dual: JWT (Parent) or Device Secret (Child) | JWT `uid` or `x-device-id` | `requireActiveDeviceForParent` or active participant | Atomic RPC controls session participant status | Terminates remote assistance | **YES** | `STATICALLY_VERIFIED` |

---

## 3. Forensic Analysis: The Global Retention Sweep Hazard (`AUD04`)

### 3.1 SQL Source Inspection of `public.run_retention_sweep()`
Inspection of [supabase/migrations/20261030000300_retention_sweep.sql:115–250](file:///d:/parentcontrol_app/supabase/migrations/20261030000300_retention_sweep.sql#L115-L250) verifies:
1. **Unscoped WebRTC Signals Purge (Lines 135–147)**:
   ```sql
   delete from public.webrtc_signals w
   where w.id = any (array(
     select id from public.webrtc_signals
     where created_at < v_now - interval '7 days'
     limit v_batch
   ));
   ```
   *Forensic Result*: Deletes signals older than 7 days **globally across every family**.
2. **Unscoped Audit Logs Purge (Lines 149–162)**:
   ```sql
   delete from public.audit_logs a
   where a.id = any (array(
     select id from public.audit_logs
     where created_at < v_now - interval '365 days'
     limit v_batch
   ));
   ```
   *Forensic Result*: Deletes audit log entries older than 365 days **globally across every family**.
3. **Global Family Loop (Lines 166–244)**:
   ```sql
   for v_family in select f.id, f.settings from public.families f order by f.id loop
   ```
   *Forensic Result*: Iterates over **all families in the database**, purging `location_events` and `usage_daily` based on per-family retention windows.

### 3.2 Strict Disambiguation: `AUD03` vs `AUD04`
- **`AUD03` (Family-Scoped Data Purge)**:
  - Executed via `family-admin` (`purge_data` action) or user account deletion.
  - Scoped strictly to the target family: `DELETE ... WHERE family_id = target_family_id`.
  - Permitted on Pathway B if restricted to dedicated disposable test families (`qa-destroy-*`).
- **`AUD04` (Global Cron Retention Sweep)**:
  - Executed via `cron` Edge Function calling `public.run_retention_sweep()`.
  - Contains **zero family scoping**; purges telemetry and audit logs across all customer tenants.
  - **PROHIBITION**: `AUD04` is **strictly prohibited on Pathway B (shared production backend)**.

---

## 4. Epistemological Security Conclusion

```
====================================================================================================
                        EDGE FUNCTION SECURITY EVIDENCE ASSESSMENT
====================================================================================================
Total Functions Audited:                         10
  • Service-Role Key Used (RLS Bypassed):        10 / 10 (100.0%) [Architectural Fact]
  • User-Facing & Device Endpoints:               9 / 10 ( 90.0%) [Isolated in Application Code]
  • Administrative Maintenance Endpoints:         1 / 10 ( 10.0%) [`cron` Unscoped Global Sweep]

Epistemological Standard Adherence:
  - Static AST inspection confirms application-level tenant isolation logic for all 9 user endpoints.
  - However, because zero runtime security tests, network invocations, or penetration tests have
    been executed in read-only mode, the maximum valid security classification is:

    [ STATICALLY VERIFIED — RUNTIME SECURITY UNVERIFIED ]

Operational Directive:
  - AUD04 (Global Retention Sweep) must remain strictly quarantined and prohibited on Pathway B.
  - Live tenant isolation must be empirically validated during Phase 3 under authorized test execution.
====================================================================================================
```
