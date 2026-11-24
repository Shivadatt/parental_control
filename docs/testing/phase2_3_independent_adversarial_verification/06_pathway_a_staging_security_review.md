# Phase 2.3 — Pathway A: Dedicated Staging Security & Isolation Review

**Document ID:** `HAVEN-GOV-PHASE2-3-PW-A`  
**Phase:** Phase 2.3 — Independent Adversarial Governance Closure & Backend Isolation Verification  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Adversarial Architectural & Infrastructure Security Review  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Objective of the Adversarial Review

Phase 2.2 presented **Pathway A (Provisioning a Dedicated Staging Supabase Project)** as providing *"complete physical isolation"* and claimed *"absolute zero risk to production data"*.

This review adversarially challenges those claims. While provisioning a dedicated Supabase project provides strong physical database separation, the assertion of "absolute zero risk" is technically flawed. This audit examines:
1. Shared dependencies that persist even with an independent database.
2. Migration reproducibility from repository source files.
3. Edge Function deployment requirements and secret management.
4. Client-side `--dart-define` compilation behavior and risks.
5. The true safety profile of destructive maintenance functions (`AUD03` and `AUD04`) in staging.

---

## 2. Challenging the "Absolute Zero Risk" Assumption (Shared Dependencies)

A separate Supabase project isolates PostgreSQL tables, auth records, and Edge Function instances. However, **it does not isolate the following critical shared dependencies**:

```
+--------------------------------------------------------------------------------------------------+
|                              PATHWAY A REMAINING SHARED DEPENDENCIES                             |
+--------------------------------------------------------------------------------------------------+
|  1. Shared Repository & Branch    --> Staging & prod share same Git branches (main). Accidental  |
|                                       merge or push can affect production.                       |
|  2. Shared Developer CLI Logins   --> Developer CLI logged into irlqctcddjmkwqdvsdsm or prod     |
|                                       hhqgreaoqulmfwfwarhc; wrong CLI target pushes migrations   |
|                                       to production instead of staging!                          |
|  3. Shared Android Package ID     --> Both builds use com.parentcontrol.parent_control.          |
|                                       Installing staging APK overwrites prod APK and wipes local |
|                                       Keystore tokens!                                           |
|  4. Shared Deep Link Scheme       --> Manifest declares parentcontrol://auth-callback. Intent    |
|                                       collisions occur if both apps reside on same test device.  |
|  5. Shared STUN/TURN Network      --> Both environments point to stun.l.google.com:19302 and     |
|                                       co-turn server, sharing network ingress points.            |
|  6. Shared Supabase CLI Config    --> supabase/config.toml holds single project_id reference.   |
+--------------------------------------------------------------------------------------------------+
```

> [!WARNING]
> Because the developer's Supabase CLI can easily be pointed to the wrong project ID, and because installing a staging APK on a tester's device overwrites the production app, **Pathway A does not have "absolute zero risk"**. Strict configuration controls are mandatory.

---

## 3. Migration Reproducibility Forensic Audit

Phase 2.2 claimed that 14 database migrations exist and can reconstruct a clean staging backend. Source inspection of `supabase/migrations/` independently confirms the exact 14 migration files:

```
1.  20260101000000_core.sql                               (Core tables, schemas, constraints)
2.  20260101000100_functions.sql                          (Triggers, RPCs, realtime publication)
3.  20260101000200_rls.sql                                (Row-level security policies, grants)
4.  20260101000300_service_role_grants.sql                (Service role permissions)
5.  20260101000400_device_recovery.sql                    (Device recovery RPCs & table alterations)
6.  20260101000500_child_contact_ids.sql                  (Emergency contacts schema updates)
7.  20260101000600_atomic_pairing_invite.sql              (Pairing invitation atomic RPCs)
8.  20261028000100_remote_session_concurrency.sql         (WebRTC session concurrency controls)
9.  20261028000200_parent_controlled_session_lifetime.sql (Session lifetime enforcement)
10. 20261028000300_signaling_open_session.sql             (WebRTC signaling open session validation)
11. 20261030000100_abandoned_session_sweep.sql            (Scheduled session cleanup RPC)
12. 20261030000200_phase1_authorization.sql               (Hardened authorization wrapper RPCs)
13. 20261030000300_retention_sweep.sql                    (Scheduled retention sweep SQL function)
14. 20261103000100_zone_delete_atomic_rpc.sql             (Safe zone atomic delete RPC)
```

### 3.1 Migration Integrity Findings
- **Count**: Exactly **14 migration files** verified.
- **Ordering**: Sequential timestamp ordering is clean with no timestamp collisions.
- **Idempotency**: All `CREATE OR REPLACE FUNCTION` and `create index if not exists` statements are idempotent.
- **Extensions Required**: PostgreSQL extensions `uuid-ossp`, `pgcrypto`. Realtime publication `supabase_realtime` must exist.
- **Storage Buckets**: **0 storage bucket definitions exist in migrations**.

---

## 4. Edge Functions Deployment & Secret Register

Source inspection of `supabase/functions/` independently confirms **10 deployable Edge Functions** plus one shared library `_shared/`:

| Function Directory | Primary Purpose | Required Secrets (by Variable Name) | Destructive Capability |
| :--- | :--- | :--- | :---: |
| **`account`** | Account export, deletion, retention reports | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | **YES** (Hard deletes user profile & auth) |
| **`auth-bootstrap`** | Initial profile & family initialization | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | No |
| **`cron`** | Scheduled sweeps (retention, session, offline) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `CRON_SECRET` | **YES** (Executes `run_retention_sweep`) |
| **`device-command`** | Parent command dispatch to child handset | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Moderate (Sends lock/sync commands) |
| **`device-policy`** | App restriction & quota policy sync | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | No (Overwrites rules with version check) |
| **`device-register`** | Child hardware registration & secret hashing | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | No |
| **`device-telemetry`** | Usage, location, and battery ingress | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | No |
| **`family-admin`** | Device revoke, zone delete, data purge | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | **YES** (Purges telemetry, revokes devices) |
| **`pairing`** | Distributed pairing invite creation & redeem | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `PAIRING_HASH_PEPPER` | No |
| **`remote-session`** | Remote assistance session initiation | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STUN_URL`, `TURN_URL`, `TURN_SECRET`, `TURN_TTL_SECONDS` | No |

### 4.1 Secret Management Requirement for Staging
To provision staging, the following secrets must be provisioned via `supabase secrets set`:
1. `CRON_SECRET` (Minimum 16 characters).
2. `PAIRING_HASH_PEPPER` (Cryptographic pepper for pairing codes).
3. `TURN_SECRET`, `TURN_URL`, `STUN_URL` (CoTURN credentials).
4. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (Auto-injected by Supabase runtime).

---

## 5. Flutter Client Dynamic Configuration Verification

Source inspection of `lib/core/config/env.dart:15–25` confirms:
```dart
static const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hhqgreaoqulmfwfwarhc.supabase.co',
);
static const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '...',
);
```

### 5.1 Verification Findings
- **Build-Time Parameterization**: Supported. Building with `--dart-define=SUPABASE_URL=https://staging.supabase.co --dart-define=SUPABASE_ANON_KEY=...` cleanly overrides the backend target without Dart source edits.
- **Default Fallback Danger**: If a developer omits `--dart-define`, the client **silently falls back to production `hhqgreaoqulmfwfwarhc`**! This is a dangerous default for QA builds.

---

## 6. Destructive Maintenance Safety in Staging (`AUD03` & `AUD04`)

Phase 2.2 claimed that `AUD03` (`TC-EXP-47`) and `AUD04` (`TC-EXP-48`) can be executed safely under Pathway A.
- **Adversarial Caveat**: While executing `public.run_retention_sweep()` in staging will not damage production customer data, **it will permanently purge staging seeded test data**.
- **Requirement**: Staging must have automated seed scripts so that when `run_retention_sweep()` purges expired test fixtures, the test environment can be re-seeded in minutes.

---

## 7. Pathway A Verdict

```
====================================================================================================
                        PATHWAY A ADVERSARIAL VERDICT
====================================================================================================

      [ FEASIBLE WITH UNRESOLVED PREREQUISITES ]

   1. Technical Feasibility: VERIFIED (14 migrations and 10 functions can reconstruct backend).
   2. Absolute Zero Risk Claim: REFUTED (CLI login targets, app ID collisions, and default 
      fallback in env.dart create non-zero risk of hitting production).
   3. Unresolved Prerequisites:
      - Owner must provision a new Supabase cloud project.
      - Supabase CLI must be authenticated to the staging project ref.
      - Environment secrets (CRON_SECRET, PAIRING_HASH_PEPPER, TURN_SECRET) must be set.
      - Automated seed data script must be created for re-seeding staging after sweeps.
      - Production fallback in env.dart must be disabled for QA builds.

====================================================================================================
```
