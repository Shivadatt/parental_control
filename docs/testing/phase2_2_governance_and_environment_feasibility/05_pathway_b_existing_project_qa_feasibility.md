# 05 — Pathway B: Existing Project QA Feasibility

**Document ID:** `HAVEN-GOV-005`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Target Architecture:** Pathway B — Isolated QA Testing within Existing Production Project (`hhqgreaoqulmfwfwarhc`)  
**Audit Standard:** Multi-Tenant Isolation, Database Mutation Risk & Data Safety Audit  
**Execution Posture:** STRICTLY READ-ONLY — NO DATA MODIFIED — ALL TESTS `NOT TESTED`  

---

## 1. Architectural Concept & Status

**Pathway B** evaluates the feasibility of conducting manual QA testing within the **existing Supabase production project** (`hhqgreaoqulmfwfwarhc`), relying on dedicated QA accounts, tenant isolation, and strict procedural quarantines without creating a secondary cloud project.

### Alignment with Historical Directives:
`docs/backend.md:327` confirms that on 2026-10-27 the Product Owner directed that all reviewed changes be deployed to the existing project and that **no second project be created**. Pathway B adheres directly to this established constraint.

However, a QA email prefix alone (`qa_*@haven.test`) does NOT establish tenant, database, or backend isolation. This audit evaluates whether the application's multi-tenant architecture provides sufficient safeguards to prevent testing activities from impacting real production users.

---

## 2. Technical Feasibility Evaluation Across Engineering Layers

### 2.1 Multi-Tenant Family Isolation via Row-Level Security (RLS)
- **Tenant Model**: In HAVEN, the primary multi-tenant boundary is the `family_id` UUID in `public.families`.
- **Membership Binding**: `public.family_members` binds each authenticated user (`profiles.id`) to a specific `family_id` with a role of `parent` or `child`.
- **Policy Enforcement**: `supabase/migrations/20260101000200_rls.sql` enforces strict RLS across all tables:
  ```sql
  create policy devices_select_parent_or_child on public.devices
    for select to authenticated
    using (private.is_family_parent(family_id) or child_user_id = auth.uid());
  ```
- **Feasibility Finding**: High for standard reads and writes. If test users belong exclusively to dedicated QA families (`qa_family_alpha`, `qa_family_beta`), standard Flutter app queries executed by authenticated QA parents **cannot read or modify production family data**.

### 2.2 Global Uniqueness Constraints & Contamination Safeguards
- **Constraints Checked**:
  - `families_one_active_per_owner`: Each parent profile can own at most one active family.
  - `family_members_one_active_child_family`: Each child profile can belong to at most one active family.
- **Feasibility Finding**: Moderate. QA accounts cannot accidentally join multiple families, but testers must never use real user emails or link test devices to production families.

### 2.3 Authentication Service & Shared Quotas
- **Shared Auth Pool**: Both real users and QA testers share the same Supabase GoTrue auth service.
- **Risks Identified**:
  - **Email Rate Limiting**: Supabase imposes project-wide hourly limits on outgoing emails (e.g. 30 emails/hour on free tier). Aggressive registration testing (`TC-A02`, `TC-EXP-09`) could exhaust email quotas, preventing real users from signing up.
  - **Global User Table**: QA users exist in the same `auth.users` table as production users.
- **Feasibility Finding**: Moderate risk. Requires throttling test account creations to prevent rate-limit exhaustion.

### 2.4 Shared Infrastructure & Resource Contention
- **Shared Resources**:
  - PostgreSQL database connection pool.
  - Realtime WebSocket channels (push notifications, policy sync).
  - Edge Function compute runtime.
- **Risks Identified**: Heavy video assistance testing (`TC-EXP-08`) or rapid telemetry dispatch (`TC-EXP-37`) consumes project CPU and memory.
- **Feasibility Finding**: Acceptable for manual QA (which involves only 1–2 test devices), but unsuited for automated load testing.

---

## 3. Catastrophic Destructive Operation Blockers in Pathway B

Adversarial inspection of database migration source code revealed a **CRITICAL SAFETY BLOCKER** regarding database retention and purge operations:

### 3.1 The Retention Sweep Hazard (`AUD04` / `TC-EXP-48`)
- **Source Code Citation**: `supabase/migrations/20261030000300_retention_sweep.sql:8–17`:
  ```sql
  -- Deletes, in order:
  --   1. webrtc_signals older than 7 days,
  --   2. audit_logs older than 365 days,
  --   3. per-family location_events older than settings->>'location_retention_days',
  --   4. per-family usage_daily older than settings->>'usage_retention_days'
  ```
- **Architectural Reality**: `public.run_retention_sweep()` is a **GLOBAL DATABASE JOB**. It accepts NO `family_id` parameter. When executed, it queries ALL families across the entire database and permanently deletes expired records.
- **Catastrophic Impact**: Executing `TC-EXP-48` in Pathway B would run the sweep across real production families, **permanently deleting historical location and usage records for real paying users**.

### 3.2 The Immediate Audit Purge Hazard (`AUD03` / `TC-EXP-47`)
- **Architectural Reality**: Similar to retention sweeps, historical log purging operates on global timestamps unless explicitly restricted by server-side RPC parameters.
- **Catastrophic Impact**: Testing manual purge on a shared project risks truncating real audit trails.

---

## 4. Pathway B Feasibility Matrix by Functional Domain

| Testing Domain | Pathway B Feasibility | Risk Level | Operational Guardrail Required |
|:---|:---:|:---:|:---|
| **UI Navigation & App Settings** | **FEASIBLE** | Zero | Standard testing; non-mutating. |
| **Authentication & Role Selection** | **FEASIBLE** | Low | Restrict to `qa_isolated_*@haven.test`; monitor email rate limits. |
| **Family Setup & Device Pairing** | **FEASIBLE** | Low | Create isolated QA families; pairing tokens bound to QA family ID. |
| **Parent Monitoring & Screen Time**| **FEASIBLE** | Low | Policies and rules scoped strictly to QA child devices. |
| **App Restrictions & Whitelist** | **FEASIBLE** | Low | Restrictions affect only enrolled QA test hardware. |
| **Safe Zones & Location Tracking** | **FEASIBLE** | Low | Geofences and GPS events scoped by `family_id` via RLS. |
| **Remote Assistance WebRTC** | **FEASIBLE** | Low | Signaling rows scoped by `session_id` and family membership. |
| **Device Unlinking & Revocation** | **FEASIBLE** | Medium | Affects only QA device row; teardown requires re-pairing. |
| **Account Deletion Cascade (`A09`)**| **FEASIBLE WITH GUARDRAIL**| High | Must strictly delete newly created disposable QA accounts only. |
| **Immediate Audit Purge (`AUD03`)** | **STRICTLY PROHIBITED** | **CRITICAL** | Cannot guarantee safety on shared database. |
| **Database Retention Sweep (`AUD04`)**| **STRICTLY PROHIBITED** | **CRITICAL** | `run_retention_sweep()` deletes real production records globally. |

---

## 5. Pathway B Feasibility Verdict

```
====================================================================================================
                        PATHWAY B FEASIBILITY VERDICT
====================================================================================================
VERDICT: FEASIBLE ONLY FOR NON-DESTRUCTIVE WORKFLOWS; UNSAFE FOR GLOBAL RETENTION SWEEPS (AUD04) 
         AND IMMEDIATE AUDIT PURGES (AUD03)

Pathway B is technically viable for 97 of 99 test cases under strict in-project QA account 
quarantine. However, tests TC-EXP-47 (AUD03) and TC-EXP-48 (AUD04) MUST BE PROHIBITED from runtime 
execution on the existing production database to prevent catastrophic loss of real user data.
====================================================================================================
```
