# 04 — Pathway A: Staging Project Feasibility

**Document ID:** `HAVEN-GOV-004`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Target Architecture:** Pathway A — Dedicated Staging Supabase Project  
**Audit Standard:** Read-Only Infrastructure Feasibility Review  
**Execution Posture:** STRICTLY READ-ONLY — NO INFRASTRUCTURE PROVISIONED  

---

## 1. Architectural Concept & Status

**Pathway A** proposes provisioning an independent, dedicated Supabase project (e.g. `haven-staging-eu`) exclusively for automated and manual QA testing of HAVEN Parent Control.

### Current Architectural Reality:
As independently verified in Phase 2.1 via `docs/backend.md:327`, **no staging project currently exists**. The owner previously directed on 2026-10-27 that no second project be created. Therefore, Pathway A represents a **future provisioning option** requiring explicit Product Owner approval, account setup, and deployment actions.

---

## 2. Technical Feasibility Evaluation Across Engineering Layers

### 2.1 Database Layer & Migration Reproducibility
- **Migration Inventory**: The repository contains **14 sequential migration files** in `supabase/migrations/`:
  1. `20260101000000_core.sql` (Core schemas `public` and `private`, base tables)
  2. `20260101000100_functions.sql` (Security definer functions, auth triggers)
  3. `20260101000200_rls.sql` (Row-Level Security policies and schema grants)
  4. `20260101000300_service_role_grants.sql` (Service role grants)
  5. `20260101000400_device_recovery.sql` (Device recovery tokens & RPCs)
  6. `20260101000500_child_contact_ids.sql` (Child contact ID helpers)
  7. `20260101000600_atomic_pairing_invite.sql` (Atomic pairing transaction RPCs)
  8. `20261028000100_remote_session_concurrency.sql` (WebRTC signaling concurrency)
  9. `20261028000200_parent_controlled_session_lifetime.sql` (Call lifetime enforcement)
  10. `20261028000300_signaling_open_session.sql` (Signaling open session checks)
  11. `20261030000100_abandoned_session_sweep.sql` (Zombie session cleanup RPC)
  12. `20261030000200_phase1_authorization.sql` (Parent authorization RPCs)
  13. `20261030000300_retention_sweep.sql` (Data retention sweep job & indexes)
  14. `20261103000100_zone_delete_atomic_rpc.sql` (Atomic safe zone deletion RPC)
- **Feasibility Finding**: High. The database schema is fully version-controlled, idempotent, and reproducible. Migrations can be applied sequentially via `supabase db push` to a clean project without manual SQL hacking.

### 2.2 Authentication & Identity Isolation
- **User Directory**: Uses standard Supabase GoTrue authentication (`auth.users`).
- **Role Assignment**: `public.profiles.role` cascades from `auth.users` via trigger; roles (`parent`, `child`) are bound upon onboarding.
- **Deep Links & Redirects**: `lib/core/config/env.dart:13` defines `authRedirectUrl = 'parentcontrol://auth-callback'`.
- **Feasibility Finding**: High. A dedicated project completely isolates test users from production accounts, avoiding any risk of account collisions or email spamming.

### 2.3 Storage Layer
- **Bucket Usage**: Standard Supabase Storage buckets for avatars and export payloads.
- **Feasibility Finding**: High. Dedicated storage prevents test files or GDPR exports from entering production S3/GCS buckets.

### 2.4 Edge Function Layer
- **Function Inventory**: 10 TypeScript Edge Functions in `supabase/functions/` (`account`, `auth-bootstrap`, `cron`, `device-command`, `device-policy`, `device-register`, `device-telemetry`, `family-admin`, `pairing`, `remote-session`).
- **Secrets Required**:
  - `SUPABASE_URL` (injected automatically by Supabase)
  - `SUPABASE_SERVICE_ROLE_KEY` (injected automatically by Supabase)
  - `PAIRING_HASH_PEPPER` (required for HMAC challenge generation)
  - `CRON_SECRET` (required for invoking `run_retention_sweep()`)
- **Feasibility Finding**: High. All 10 functions can be deployed to the staging project via `supabase functions deploy`.

### 2.5 Flutter Client Configuration
- **Compile-Time Injection**: `lib/core/config/env.dart` reads configuration via:
  ```dart
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  ```
- **Zero Hardcoded URLs**: Dart source code contains zero hardcoded project URLs. Pointing a test build at staging requires only compile-time `--dart-define` flags:
  ```bash
  flutter build apk --dart-define=SUPABASE_URL=https://<staging-project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<staging-anon-key>
  ```
- **Feasibility Finding**: Very High. Client architecture already supports arbitrary backend URLs cleanly.

---

## 3. Operational Requirements & Cost Categories

To implement Pathway A, the Product Owner must perform or authorize the following setup actions:
1. **Cloud Account Provisioning**: Create new project in Supabase Dashboard (incurs free-tier slot or Pro tier project charge).
2. **Migration Deployment**: Run `supabase db push` using staging db connection string.
3. **Secret Provisioning**: Execute `supabase secrets set PAIRING_HASH_PEPPER=... CRON_SECRET=...`.
4. **Edge Function Deployment**: Deploy all 10 Edge Functions to staging.
5. **Test Build Distribution**: Compile test APKs with staging `--dart-define` flags and install on test hardware.
6. **Ongoing Maintenance**: Keep staging migrations in sync with production whenever future features are developed.

---

## 4. Pathway A Risk & Safety Profile

```
+----------------------------------------------------------------------------------------------------+
|                                    PATHWAY A RISK PROFILE                                          |
+----------------------------------------------------------------------------------------------------+
| 1. Production Data Exposure:           ZERO RISK (Completely isolated database).                  |
| 2. Destructive Testing Safety:         100% SAFE (AUD03, AUD04, A09 cannot harm production).      |
| 3. Rate Limit / Quota Spikes:          ZERO IMPACT on real users.                                  |
| 4. Primary Operational Risk:           CONFIGURATION DRIFT (Staging schema lags production).       |
| 5. Cost / Resource Burden:             MODERATE (Requires cloud project quota & maintenance).      |
+----------------------------------------------------------------------------------------------------+
```

---

## 5. Pathway A Feasibility Verdict

```
====================================================================================================
                        PATHWAY A FEASIBILITY VERDICT
====================================================================================================
VERDICT: FEASIBLE SUBJECT TO OWNER PROVISIONING & APPROVAL
Technical readiness is high; codebase is cleanly abstracted for multi-environment deployment.
Requires owner authorization to create and maintain a second Supabase project.
====================================================================================================
```
