# Phase 3.7.3 — Report 03: Row-Level Security (RLS) & Database Grants Parity

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report audits the Row-Level Security (RLS) policies and PostgreSQL role grants across tables accessed by the `account` Edge Function, evaluating production standards against staging requirements.

$$\mathbf{RLS\ Parity\ Status} = \mathbf{REPOSITORY-DEFINED\ -\ STAGING\ PARITY\ UNKNOWN\ (NO\ PROJECT)}$$

In the target architecture, PostgreSQL RLS policies protect direct client-side PostgREST calls (e.g. Flutter mobile app). However, Edge Functions execute using the backend `service_role` key, which holds PostgreSQL `BYPASSRLS` privileges. Consequently, multi-tenant isolation relies primarily on application-layer query filters in the function source, backed by RLS as a secondary client gateway.

---

## 2. Table-by-Table RLS Policy & Permissions Matrix

The table below audits the RLS policies defined in `supabase/migrations/20260101000200_rls.sql` and grants in `20260101000300_service_role_grants.sql`:

| Table Name | RLS Enabled? | Client PostgREST SELECT Policy | Client PostgREST Mutation Policies | `service_role` Grant & Privileges | Staging Parity Status |
|---|:---:|---|---|---|:---:|
| **`public.profiles`** | **YES** | `profiles_select_own`: Users can view their own profile (`id = auth.uid()`). | `profiles_update_own`: Users can update display_name for own profile. | `GRANT ALL ON public.profiles TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.families`** | **YES** | `families_select_member`: Members can select families where active in `family_members`. | `families_insert_parent`: Authenticated parents can insert families. | `GRANT ALL ON public.families TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.family_members`** | **YES** | `family_members_select_family`: Active members can view co-members of their family. | `family_members_insert_owner`: Only family owner can invite/add members. | `GRANT ALL ON public.family_members TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.devices`** | **YES** | `devices_select_parent_or_own`: Parents see all family devices; children see own device. | `devices_update_parent`: Parents can update device display name and policy. | `GRANT ALL ON public.devices TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.location_events`** | **YES** | `location_events_select_parent`: Active parents can select events for family devices. | `location_events_insert_device`: Devices insert own events via HMAC/secret. | `GRANT ALL ON public.location_events TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.usage_daily`** | **YES** | `usage_daily_select_parent`: Active parents can select usage for family devices. | `usage_daily_insert_device`: Devices insert daily usage rows. | `GRANT ALL ON public.usage_daily TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.safety_alerts`** | **YES** | `safety_alerts_select_parent`: Active parents can select alerts for their family. | `safety_alerts_insert_device`: Devices insert alerts. | `GRANT ALL ON public.safety_alerts TO service_role` (`BYPASSRLS`) | **UNKNOWN** |
| **`public.audit_logs`** | **YES** | `audit_logs_select_family_parent`: Parents view audit events where `family_id` matches. | Prohibited to client roles (`authenticated`, `anon`). | `GRANT ALL ON public.audit_logs TO service_role` (`BYPASSRLS`) | **UNKNOWN** |

---

## 3. The Service-Role Isolation Principle (`BYPASSRLS`)

A crucial security distinction must be emphasized:

```mermaid
flowchart TD
    subgraph ClientAccess ["Direct Client Access (Flutter App)"]
        CA["User JWT (authenticated role)"] --> RLS["PostgreSQL RLS Engine"]
        RLS -->|Enforced via auth.uid()| DB1[("PostgreSQL Tables")]
    end

    subgraph EdgeFunctionAccess ["Edge Function Access (account function)"]
        EF["account Function (service_role key)"] --> BYPASS["PostgreSQL Engine (BYPASSRLS)"]
        BYPASS -->|RLS Ignored!| DB2[("PostgreSQL Tables")]
        APPFILTER["Application Query Filter (.in('family_id', ...))"] -->|Must Enforce Isolation| EF
    end
```

1. **RLS Alone Does Not Protect Edge Functions:**
   Even if staging database RLS policies are 100% identical to production, the `account` Edge Function executes queries with the `service_role` key. PostgreSQL automatically bypasses all RLS checks for this role.
2. **Application Filter Verification:**
   Therefore, multi-tenant safety is 100% determined by the application query filters in `account/index.ts` (`loadActiveMemberships` $\to$ `familyIds` $\to$ `.in('family_id', familyIds)`).
3. **Staging Requirement:**
   When a staging project is provisioned, verifying both RLS migration application (`20260101000200_rls.sql`) and identical `service_role` permissions is mandatory to ensure environment equivalence.
