# Phase 3.6 — Report 01: Scope, Production Boundaries & Operational Constraints

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Organization ID:** `symqztrmaziuwdibcfrq` (`spg7753@gmail.com's Org`)  
**Region:** `ap-northeast-2` (Seoul / Northeast Asia)  
**Target Function:** `account`  
**Production Endpoint:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`  
**Previous Baseline:** Phase 3.5 — `AUDIT COMPLETE, NO CRITICAL FINDINGS` (Commit `b3d3677`)  
**Audit Date:** 2026-11-20  

---

## 1. Mission & Phase Objectives

The objective of Phase 3.6 is to design, model, and qualify a strictly isolated test environment architecture for future authenticated production testing of the `account` Edge Function.

The core question evaluated in this phase is:
> *Can disposable, ephemeral test tenants be safely provisioned, exercised, verified, and cleaned up in production without impacting any existing users, family memberships, monitored devices, account records, audit trails, or retention policies?*

This phase is strictly **READ-ONLY ARCHITECTURE AND SAFETY QUALIFICATION**.

$$\mathbf{Phase\ 3.6\ Scope} = \mathbf{SCHEMA\ DISCOVERY} + \mathbf{THREAT\ MODELING} + \mathbf{ISOLATION\ ARCHITECTURE\ DESIGN} + \mathbf{OFFLINE\ QUALIFICATION} + \mathbf{ADR}$$

Phase 3.6 does **NOT** grant authorization to create test accounts, create test tenants, write database records, invoke mutations, execute live account deletions, or trigger retention sweeps.

---

## 2. Production Baseline Verification

Phase 3.5 established the following operational baseline, which remains active and intact in `parent-control-prod`:

| Baseline Dimension | Reported Phase 3.5 Status | Independent Source Inspection Status |
|---|---|---|
| **Staged Package Integrity** | 9/9 files match SHA-256 baseline | **CONFIRMED** (`python scratch/verify_local_package.py`) |
| **Local Staged Tests** | 46 passed, 0 failed (401ms) | **CONFIRMED** (`deno test --allow-read docs/.../account/`) |
| **Full Backend Tests** | 199 passed, 0 failed (1.0s) | **CONFIRMED** (`deno test -A supabase/functions/`) |
| **Security Invariants** | 12/12 evaluated PASS | **CONFIRMED** (Audited in Phase 3.5 Report 09) |
| **Production Functions** | Exactly 10 active Edge Functions | **CONFIRMED** (`account` + 9 baseline functions) |
| **Production Endpoint** | `200 OK` on OPTIONS, `401` on unauthenticated POST | **CONFIRMED** (Phase 3.4.7 / 3.5 live smoke logs) |
| **Protected Accounts** | Untouched and isolated | **CONFIRMED** (Zero requests targeting operational accounts) |

The production `account` function is published and operational; redeployment is strictly prohibited.

---

## 3. Mandatory Safety Constraints & Prohibitions

To ensure zero impact on production stability and user data, the following constraints are active throughout Phase 3.6:

### 3.1 Prohibited Operations
1. **NO Production State Mutations:**
   - Zero test user creation in Supabase Auth (`auth.users`).
   - Zero family creation or membership insertion.
   - Zero device registration or command creation.
   - Zero database row insertion, update, or deletion.
   - Zero execution of SQL scripts, DDL, or database migrations.
2. **NO Supabase CLI / Management API / PAT Usage:**
   - Supabase CLI commands (`supabase db push`, `supabase functions deploy`) remain strictly prohibited.
   - No Personal Access Tokens (PAT) or Management API keys are requested or used.
   - No extraction of session cookies, JWTs, or localStorage tokens from the browser.
3. **NO Production Configuration Alterations:**
   - Zero modifications to RLS policies, PostgreSQL triggers, security definer functions, or role grants.
   - Zero modifications to Supabase secrets or environment variables (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`).
   - Zero modifications to client Flutter application source or Edge Function code.

### 3.2 Permanent Account Protection
The following accounts are permanently classified as **PROTECTED OPERATIONAL ACCOUNTS**:
- `spg7753@gmail.com` (Owner / Organization Administrator)
- `ankit@gmail.com` (Primary Parent QA Account)
- `ankit1@gmail.com` (Primary Child QA Account)

**Rules of Engagement:**
- These accounts must NEVER be utilized as disposable test identities.
- Their passwords, roles, profiles, memberships, devices, and pairing states must never be modified.
- No personal data or credentials relating to these accounts may appear in test fixtures, scripts, or reports.

---

## 4. Preservation of Existing Architecture

All designs formulated in Phase 3.6 strictly adhere to the existing architectural foundation:
- **Client Stack:** Flutter (Dart) + native Android Kotlin services.
- **Backend Stack:** Supabase (PostgreSQL 15+, GoTrue Auth, PostgREST, Deno Edge Functions).
- **Tenant Topology:** Multi-tenant row-level isolation where a family represents a logical tenant owned by a Parent user (`profiles.role = 'parent'`).
- **Security Posture:** Defense-in-depth where Row Level Security (RLS) denies client-side direct deletion, forcing all account operations through audited service-role Edge Functions.

No third-party SaaS, alternate cloud provider, or database re-architecture is considered.
