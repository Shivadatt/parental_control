# PHASE 3.2 — LOCAL VS HOSTED GAP ANALYSIS & DRIFT REPORT

**Project:** Parent Control System (`parentcontrol_app`)  
**Target Project Name:** `parent-control-prod`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Target Cloud Region:** `ap-south-1`  
**Audit Execution Timestamp:** 2026-11-18T15:25:00+05:30  
**Audit Scope:** Full Comparative Analysis of Local Repository Artifacts vs Hosted Supabase Production  
**Execution Mode:** STRICT READ-ONLY AUDIT  

---

## 1. COMPARATIVE METHODOLOGY & GAP TAXONOMY

This gap analysis systematically cross-examines the local repository baseline against the live hosted Supabase environment (`hhqgreaoqulmfwfwarhc`) across five core architectural layers:
1. **Relational Schemas & Tables (DDL)**
2. **Row-Level Security Policies & Permissions (RLS/Grants)**
3. **Database Stored Procedures & Triggers (RPC)**
4. **Serverless Edge Functions (Deno Runtime)**
5. **Realtime Channels & GoTrue Auth Configuration**

### Gap Severity Taxonomy
- **P0 / Critical:** Outage, security vulnerability, or broken end-user feature caused by backend absence (e.g., HTTP 404 on active client call).
- **P1 / Major:** Un-applied migration, functional divergence between local code and hosted execution, or performance degradation.
- **P2 / Minor:** Non-breaking discrepancy, cosmetic deviation, metadata divergence, or documentation gap.
- **Synchronized / None:** Exact parity verified between local source code and hosted cloud environment.

---

## 2. LAYER-BY-LAYER GAP ANALYSIS

### 2.1 Database Schema & Tables
- **Local Source:** 14 SQL migrations creating 19 tables in `public` and helper objects in `private`.
- **Hosted State:** 19 tables present in schema `public` with identical primary keys, foreign key constraints, cascading behaviors, and uniqueness guards.
- **Drift Evaluation:** **SYNCHRONIZED (Zero Schema Drift)**.
  - Foreign key cascades (`profiles` -> `families` -> `devices` -> `usage_daily` / `location_events`) match 1:1.
  - Unique partial indexes (`families_one_active_per_owner`, `family_members_one_active_child_family`, `webrtc_signals_session_sequence_uniq`) are active on the hosted database.

### 2.2 Row Level Security Policies
- **Local Source:** `20260101000200_rls.sql` and `20261030000200_phase1_authorization.sql`.
- **Hosted State:** All 19 public tables have RLS enabled. Direct `DELETE` on `safe_zones` is revoked. Anonymous access is strictly denied across all sensitive tables.
- **Drift Evaluation:** **SYNCHRONIZED (Zero Security Drift)**.

### 2.3 Stored Procedures & Triggers
- **Local Source:** 26 functions across `public` and `private`, 8 PostgreSQL triggers.
- **Hosted State:** All 8 triggers active on hosted database. SECURITY DEFINER functions have pinned search paths (`public, private, pg_temp`). Public wrappers verify actor authorization via `private.is_parent_of_family`.
- **Atomic Safe Zone Delete Note:** Migration `20261103000100_zone_delete_atomic_rpc.sql` (`delete_safe_zone_audited`) is verified locally and active in hosted environment, ensuring atomicity of geofence removal.
- **Drift Evaluation:** **SYNCHRONIZED**.

### 2.4 Serverless Edge Functions (CRITICAL FINDING)
- **Local Source:** 10 Deno function suites in `supabase/functions/` (`account`, `auth-bootstrap`, `cron`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`).
- **Hosted State:**
  - 9 functions are deployed and healthy: `auth-bootstrap`, `cron`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`.
  - **1 function is NOT DEPLOYED:** `account` (`supabase/functions/account/`).
  - Probing `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account` returns `HTTP/1.1 404 Not Found`.
- **Drift Evaluation:** **P0 DEFECT GAP (Defect E-15)**.
  - The missing deployment directly causes the parent settings error banner when accessing Account & Privacy.

### 2.5 Realtime & Authentication
- **Local Source:** Realtime CDC enabled on `safety_alerts`, `remote_sessions`, `webrtc_signals`. GoTrue auto-creates `public.profiles`.
- **Hosted State:** Realtime publications active; topic authorization hook `private.realtime_topic_allowed` active.
- **Drift Evaluation:** **SYNCHRONIZED**.

---

## 3. MASTER GAP REGISTER

The following consolidated register details all identified discrepancies and their associated remediation paths:

| Gap ID | Severity | Component | Issue Description | Impact | Remediation Plan |
|---|---|---|---|---|---|
| **GAP-01** | **P0 (Critical)** | Edge Functions | Function `account` is not deployed to hosted Supabase (`hhqgreaoqulmfwfwarhc`). Probing returns 404. | Parent Settings displays error banner: `"Retention report unavailable: Requested function was not found"`. GDPR export and account deletion endpoints unavailable over HTTP. | Execute `supabase functions deploy account` in Phase 3.3 followed by production smoke-test verification. |
| **GAP-02** | **P2 (Minor)** | Documentation | Client-side error banner in Parent Settings lacks graceful offline / fallback state when edge function is unreachable. | Displays raw exception message to user rather than friendly retry indicator. | Enhance `account_privacy_screen.dart` error handling with user-friendly retry button in Phase 3.3. |
| **GAP-03** | **P2 (Minor)** | Monitoring | Absence of automated synthetic monitoring probe against hosted Edge Function endpoints. | Deployment regressions or cold-start timeouts are not alerted until parent user interaction. | Establish automated health-check probe in CI/CD pipeline. |

---

## 4. DEFECT E-15 READINESS SYNCHRONIZATION

The deployment readiness of the `account` function was thoroughly vetted in Phase 3.1:
1. **Source Code Parity:** Complete implementation exists locally in `supabase/functions/account/` (`index.ts`, `retention.ts`, `validation.ts`).
2. **Automated Test Validation:** 30 out of 30 unit tests pass locally (216 ms).
3. **Safety Controls:** Dual-confirmation deletion (`confirm: "DELETE"`, email verification), 1,000-row batching, and 20,000-row table export caps are fully baked in.
4. **Action Items for Phase 3.3:**
   - Deploy `account` function via Supabase CLI.
   - Verify live endpoints: `retention_report`, `export`, and `delete_account` via authenticated smoke tests.
   - Confirm complete resolution of Defect E-15 on physical test devices.

---

## 5. MANDATORY SAFETY ASSERTIONS

```
TARGET_PROJECT_NAME = parent-control-prod
TARGET_PROJECT_REF = hhqgreaoqulmfwfwarhc
OTHER_PROJECTS_ACCESSED = NO
SOURCE_MODIFICATIONS = NONE
DATABASE_MUTATIONS = NONE
RLS_CHANGES = NONE
EDGE_FUNCTION_DEPLOYMENTS = NONE
AUTH_SETTINGS_CHANGED = NONE
STORAGE_CHANGES = NONE
REALTIME_CONFIGURATION_CHANGED = NONE
RPC_OR_TRIGGER_CHANGES = NONE
SECRETS_CHANGED = NONE
USERS_MODIFIED = NONE
DEVICE_RECOVERY_EXECUTED = NO
ACCOUNT_DELETION_EXECUTED = NO
PRODUCTION_DATA_EXPORTED = NO
BACKUP_RESTORE_EXECUTED = NO
```
