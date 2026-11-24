# Phase 2.3 — Pathway B: Existing Project QA Tenant Isolation Review

**Document ID:** `HAVEN-GOV-PHASE2-3-PW-B`  
**Phase:** Phase 2.3 — Independent Adversarial Governance Closure & Backend Isolation Verification  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Adversarial Static Database Security & Multi-Tenancy Audit  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Objective of the Adversarial Review

Phase 2.2 presented **Pathway B (In-Project QA Tenant in Existing Production Project `hhqgreaoqulmfwfwarhc`)** as a viable zero-cost alternative, claiming that PostgreSQL Row-Level Security (RLS) protects standard tenant data.

This adversarial review challenges those claims. Testing in a live production database carries severe risks if tenant isolation boundaries are porous. This audit examines:
1. Completeness of PostgreSQL Row-Level Security across all application tables.
2. The critical vulnerability that **Edge Functions bypass RLS completely via the service-role client**.
3. SECURITY DEFINER function search paths and cross-tenant leakage risks.
4. Non-existence of Storage Buckets (correcting Phase 2.2 errors).
5. Supabase Realtime channel isolation for WebRTC and alerts.
6. Shared production infrastructure impact (GoTrue auth rate limits, connection pools).
7. Forensic analysis of `qa-destroy-*@haven.internal` naming conventions.

---

## 2. Row-Level Security (RLS) Completeness Audit

Source inspection of `supabase/migrations/20260101000200_rls.sql` reveals that RLS is enabled and policies are defined for standard public tables:

| Table Name | RLS Enabled? | SELECT Policy | INSERT Policy | UPDATE Policy | DELETE Policy | Tenant Isolation Mechanism |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- |
| **`profiles`** | **YES** | Self or Family | Restricted | Self only | Revoked | `id = auth.uid()` OR `private.is_family_member()` |
| **`families`** | **YES** | Family Members | Restricted | Owner only | Revoked | `private.is_family_member(id)` |
| **`family_members`**| **YES** | Family Members | Restricted | Revoked | Revoked | `private.is_family_member(family_id)` |
| **`devices`** | **YES** | Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`device_policies`**| **YES**| Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`device_commands`**| **YES**| Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`usage_daily`** | **YES** | Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`location_events`**| **YES**| Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`device_apps`** | **YES** | Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`safe_zones`** | **YES** | Family Members | Parent only | Parent only | Parent only | `private.is_family_member(family_id)` / Parent |
| **`safety_alerts`** | **YES** | Parent or Child | Restricted | Revoked | Revoked | `private.is_family_parent(family_id)` OR child uid |
| **`remote_sessions`**| **YES**| Participants | Restricted | Revoked | Revoked | `s.parent_user_id = auth.uid() OR child_user_id`|
| **`webrtc_signals`** | **YES** | Participants | Participant | Revoked | Revoked | Verified against active `remote_sessions` |
| **`audit_logs`** | **YES** | Family Parent | Revoked | Revoked | Revoked | `private.is_family_parent(family_id)` |

### 2.1 RLS Audit Verdict
For **direct PostgREST client queries**, RLS is robustly designed. An authenticated parent user cannot SELECT, UPDATE, or DELETE rows belonging to another family via the standard Supabase client.

---

## 3. The Critical Edge Function Vulnerability: Service-Role Bypass of RLS

> [!CAUTION]
> Phase 2.2 assumed that RLS protects the entire application under Pathway B. **This is architecturally false for all Edge Functions.**

Source inspection of `supabase/functions/_shared/auth.ts:60–75` confirms:
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

### 3.1 Forensic Risk Analysis
1. **RLS Bypass**: In PostgreSQL, the `service_role` super-user role **completely bypasses Row-Level Security**.
2. **TypeScript-Only Enforcement**: Every Edge Function (`account`, `family-admin`, `device-command`, `device-telemetry`, `pairing`) runs all database queries via `getServiceClient()`.
3. **No Database-Level Safety Net**: Tenant isolation inside Edge Functions depends **100% on Deno application code** (`assertFamilyParent`, `assertFamilyMember`, `eq("family_id", familyId)`).
4. **Failure Impact**: If an Edge Function developer writes an unscoped query (e.g. `db.from("devices").select("*")` without `.eq("family_id", ...)`), it returns **all devices across all production customers**!

---

## 4. SECURITY DEFINER Functions & Search Path Audit

Source inspection of `supabase/migrations/` identified **22 distinct `SECURITY DEFINER` functions**. 

### 4.1 Search Path Evaluation
- **Best Practice Compliance**: All modern functions (e.g., `private.realtime_topic_allowed`, `public.atomic_create_pairing_invitation`, `public.delete_zone_atomic`) explicitly specify:
  `SET search_path = public, private, pg_temp;`
  This prevents search path hijacking attacks.

### 4.2 Cross-Tenant Leakage Hazard
- Functions like `public.run_retention_sweep()` (`20261030000300_retention_sweep.sql:116`) and `public.expire_abandoned_sessions()` run as `SECURITY DEFINER` and execute **cross-tenant sweeps without any `family_id` argument**.
- Executing `run_retention_sweep()` sweeps and deletes data across **every single family in the database**.

---

## 5. Storage & Realtime Multi-Tenancy Reality

### 5.1 Supabase Storage: Refuting Phase 2.2 Claims
Phase 2.2 Deliverable 09 cited Prerequisite 9 as *"Storage Bucket Isolation... Supabase Storage policies in migrations."*
- **Forensic Truth**: Source inspection confirms that **HAVEN uses zero Supabase Storage buckets**.
- Account data exports stream directly via HTTP JSON attachments (`account/index.ts:5–8`).
- There are no storage buckets to isolate or leak under Pathway B.

### 5.2 Realtime Channel Isolation
Inspection of `20260101000200_rls.sql:320–360` confirms that Realtime subscriptions enforce topic authorization via `private.realtime_topic_allowed(realtime.topic())`:
- Channel topics for `safety-alerts:<family_id>` require caller to be an active family member.
- Channel topics for `webrtc-signals:<session_id>` require caller to be a participant in that active session.
- Realtime message leakage between families is prevented.

---

## 6. Shared Infrastructure Production Impact

Even with logical data isolation, running QA tests on the production Supabase project (`hhqgreaoqulmfwfwarhc`) introduces severe shared infrastructure risks:

```
+--------------------------------------------------------------------------------------------------+
|                            SHARED PRODUCTION INFRASTRUCTURE IMPACT                               |
+--------------------------------------------------------------------------------------------------+
| 1. GoTrue Auth Rate Limits   --> Supabase Auth enforces IP and email rate limits (e.g., 30 sign- |
|                                  ups/hour). Automated or rapid QA tests will trigger rate limit   |
|                                  throttling, blocking real customer sign-ups!                    |
| 2. PostgreSQL Connection Pool--> Automated tests opening multiple connections can exhaust the    |
|                                  PostgREST connection pool, causing 503 errors for customers.    |
| 3. Single Project Log Stream --> QA error logs and crash dumps pollute production monitoring     |
|                                  and Sentry alerts, masking real customer incidents.              |
| 4. Realtime Broadcast Quotas --> WebRTC video/audio signaling stress-testing consumes production  |
|                                  Supabase Realtime message quotas.                               |
+--------------------------------------------------------------------------------------------------+
```

---

## 7. QA Account Naming Convention Forensic Analysis

Phase 2.2 proposed using `qa-destroy-*@haven.internal` to prevent accidental deletion of real accounts.
- **Forensic Truth**: The string `haven.internal` is **purely a client-side naming convention**.
- There is **zero server-side code, SQL constraint, or RLS policy** in the repository that checks for `haven.internal` or treats test accounts differently from production customer accounts.
- If a tester accidentally passes a production customer ID to `account` action `delete_account`, the backend will delete the production customer without hesitation!

---

## 8. Pathway B Verdict

```
====================================================================================================
                        PATHWAY B ADVERSARIAL VERDICT
====================================================================================================

      [ FEASIBLE ONLY FOR A LIMITED NON-DESTRUCTIVE SUBSET ]

   1. RLS Client-Side Isolation: VERIFIED for standard direct PostgREST table queries.
   2. Edge Function Isolation: CAUTION (Edge Functions use service-role key, bypassing RLS; 
      isolation rests entirely on Deno application logic).
   3. Mandatory Hard Prohibitions on Pathway B:
      - TC-EXP-48 (Retention Sweep / AUD04): STRICTLY PROHIBITED (deletes prod data globally).
      - TC-EXP-47 (Audit Purge / AUD03): STRICTLY PROHIBITED.
      - Destructive Account Deletion (TC-A09, TC-EXP-17, TC-EXP-18): PROHIBITED on production.
      - High-frequency automated auth tests: PROHIBITED (exhausts GoTrue auth rate limits).
   4. Executable Test Suite: Strictly restricted to non-destructive functional tests (Max ~85 tests).

====================================================================================================
```
