# 08 — Backend Data and Destructive Operation Risk

**Document ID:** `HAVEN-GOV-008`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Deep-Dive Assessment of Database Domains, Cascades, Triggers, RLS, Edge Functions & Destructive Quarantines  
**Audit Standard:** Database Integrity, Multi-Tenant Security & Destructive Risk Audit  
**Execution Posture:** STRICTLY READ-ONLY — NO DATA MODIFIED — ALL TESTS `NOT TESTED`  

---

## 1. Domain Architecture & Multi-Tenant Risk Model

HAVEN Parent Control stores all state in PostgreSQL under Supabase. The database architecture relies heavily on foreign key cascade constraints (`on delete cascade`), security definer triggers, and Row-Level Security policies.

When executing manual QA tests, understanding how database mutations cascade across related tables is essential to prevent unintended data loss or security leaks, especially if testing is performed on a shared project (Pathway B).

---

## 2. Table-by-Table Architectural Risk Assessment

```
+----------------------------------------------------------------------------------------------------+
|                                    DATABASE DOMAIN RISK TAXONOMY                                    |
|                                                                                                    |
|  [HIGH RISK]     - Tables with global deletion jobs or cascade roots (profiles, families)          |
|  [MEDIUM RISK]   - Tables with unique hardware bindings (devices, pairing_tokens)                   |
|  [LOW RISK]      - Append-only event logs scoped strictly by family_id (location, usage, alerts)   |
+----------------------------------------------------------------------------------------------------+
```

### 2.1 Authentication & Profile Domain (`auth.users`, `public.profiles`)
- **Foreign Key Binding**: `public.profiles.id` references `auth.users(id)` with `on delete cascade`.
- **Cascade Tree**: Deleting a profile cascades down to:
  - `public.families` (where `owner_id = profiles.id`)
  - `public.family_members` (where `user_id = profiles.id`)
  - `public.devices` (where `child_user_id = profiles.id`)
  - All associated `location_events`, `usage_daily`, `safety_alerts`, and `device_policies`.
- **Pathway B Risk**: **HIGH**. Deleting a QA user cascades to all family state. If a QA user is improperly linked to a real family, deleting that QA user would destroy the real family.
- **Guardrail**: QA accounts must NEVER be invited to or joined with non-QA families.

### 2.2 Family & Membership Domain (`public.families`, `public.family_members`)
- **Constraints**:
  - `families_one_active_per_owner`: Each parent owns at most one active family.
  - `family_members_one_active_child_family`: Each child belongs to at most one active family.
- **Pathway B Risk**: **LOW**. A QA parent cannot own multiple families, and QA children cannot be co-enrolled in real families.

### 2.3 Hardware & Device Domain (`public.devices`, `pairing_tokens`)
- **Fields**: `installation_id`, `status` (`pending`, `active`, `revoked`), `secret_hash`, `last_seen_at`.
- **Pathway B Risk**: **MEDIUM**. Device revocation (`FAM12` / `TC-EXP-17`) invalidates the cryptographic JWT token in Keystore. In Pathway B, testers must only revoke dedicated test hardware.

### 2.4 Application Restrictions & Policy Domain (`device_policies`, `device_commands`)
- **Scoping**: All policies and commands carry foreign keys to `device_id` and `family_id`.
- **Pathway B Risk**: **LOW**. Modifying policies or issuing commands affects only the specific QA device enrolled in that family.

### 2.5 Telemetry & Events Domain (`location_events`, `usage_daily`, `safety_alerts`)
- **Scoping**: All telemetry records are indexed and partitioned by `family_id` and `device_id`.
- **RLS Enforced**: Parents can only query telemetry belonging to their family (`private.is_family_parent(family_id)`).
- **Pathway B Risk**: **LOW** for inserts and reads. Zero cross-tenant leakage.

### 2.6 Audit Logging Domain (`public.audit_logs`)
- **Structure**: Append-only log recording actor, event type, metadata JSON, and timestamp.
- **Pathway B Risk**: **CRITICAL** during purge operations (see §3 below).

---

## 3. In-Depth Destructive Operation Risk Analysis

### 3.1 The Retention Sweep Hazard (`AUD04` / `TC-EXP-48`)
- **Source Code Verification**: `supabase/migrations/20261030000300_retention_sweep.sql:8–23`:
  ```sql
  create or replace function public.run_retention_sweep()
  returns jsonb
  language plpgsql
  security definer
  ...
  -- Deletes, in order:
  --   1. webrtc_signals older than 7 days,
  --   2. audit_logs older than 365 days,
  --   3. per-family location_events older than settings->>'location_retention_days',
  --   4. per-family usage_daily older than settings->>'usage_retention_days'
  ```
- **Architectural Reality**: `run_retention_sweep()` takes **zero arguments**. It does NOT accept a `family_id`. It iterates across the entire database and permanently purges records older than retention thresholds for EVERY family.
- **Pathway B Verdict**: **STRICTLY PROHIBITED**. Running this job on production will permanently delete historical location events and usage metrics belonging to real production families.

### 3.2 The Immediate Audit Purge Hazard (`AUD03` / `TC-EXP-47`)
- **Architectural Reality**: Manual audit purges operate on retention thresholds. Unless an RPC explicitly scopes deletion to `WHERE family_id = auth.user_family_id()`, executing an audit purge risks truncating shared database tables.
- **Pathway B Verdict**: **PROHIBITED ON PRODUCTION** unless verified to take a strict `family_id` parameter.

### 3.3 Permanent Account Deletion (`A09` / `TC-A09`)
- **Architectural Reality**: Calls Supabase Auth delete user, which triggers PostgreSQL foreign key cascades.
- **Pathway B Verdict**: **PERMISSIBLE WITH STRICT GUARDRAILS**. Permissible only on fresh disposable test accounts (`qa_disposable_*@haven.test`) that own an isolated test family.

---

## 4. Destructive Quarantine Protocols: Pathway A vs Pathway B

```
+====================================================================================================+
|                                DESTRUCTIVE OPERATION GOVERNANCE COMPARISON                         |
+====================================================================================================+
| Destructive Operation                | Pathway A (Dedicated Staging) | Pathway B (In-Project QA)   |
+--------------------------------------+-------------------------------+-----------------------------+
| TC-A09 (Cascade Account Deletion)    | PERMITTED (Disposable User)   | PERMITTED (Disposable Only) |
| TC-FAM10 (Unlink Child Account)      | PERMITTED (Test Hardware)     | PERMITTED (Test Hardware)   |
| TC-EXP-17 (Device Revocation)        | PERMITTED (Test Hardware)     | PERMITTED (Test Hardware)   |
| TC-EXP-18 (Keystore Re-Credential)   | PERMITTED (Test Hardware)     | PERMITTED (Test Hardware)   |
| TC-EXP-47 (Immediate Audit Purge)    | PERMITTED (Staging DB)        | STRICTLY PROHIBITED         |
| TC-EXP-48 (Retention Sweep SQL)      | PERMITTED (Staging DB)        | STRICTLY PROHIBITED         |
+====================================================================================================+
```

---

## 5. Security Summary & Owner Directive

- In **Pathway A**, all 6 destructive operations can be tested safely without operational restrictions.
- In **Pathway B**, `TC-EXP-47` and `TC-EXP-48` **MUST BE PERMANENTLY REMOVED** from the runtime test plan to protect real customer data.
