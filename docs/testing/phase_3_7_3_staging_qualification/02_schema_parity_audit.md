# Phase 3.7.3 — Report 02: Database Schema Parity Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Production Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Execution Mode:** STRICTLY READ-ONLY / STAGING QUALIFICATION / OFFLINE PREFLIGHT  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report conducts a database schema parity audit evaluating the production PostgreSQL schema against staging requirements across the eight tables queried or affected by the `account` Edge Function.

$$\mathbf{Schema\ Parity\ Status} = \mathbf{REPOSITORY-DEFINED\ IN\ MIGRATIONS\ -\ STAGING\ PARITY\ UNKNOWN\ (NO\ PROJECT)}$$

Because no dedicated Supabase staging project exists in the organization, live staging schema parity cannot be observed. However, the repository migration suite (`supabase/migrations/`) fully specifies the target schema for any future staging provisioning.

---

## 2. Table-by-Table Schema Specification & Parity Matrix

The table below audits the eight core database tables across columns, types, keys, and foreign-key constraints:

| Table Name | Production Evidence Source | Staging Evidence Source | Columns & Data Types | Primary Key | Foreign Key Constraints & Delete Behavior | Unique Constraints & Indexes | Parity Classification |
|---|---|---|---|---|---|---|:---:|
| **`public.profiles`** | `core.sql` L20-45<br>Dashboard Screenshot 04/05 | None (No staging project) | `id` (uuid), `role` (text check 'parent'\|'child'\|'unset'), `display_name` (text), `created_at` (timestamptz), `updated_at` (timestamptz) | `id` | `id REFERENCES auth.users(id) ON DELETE CASCADE` | PK index on `id` | **UNKNOWN (STAGING MISSING)** |
| **`public.families`** | `core.sql` L50-70<br>Dashboard Screenshot 07 | None (No staging project) | `id` (uuid), `name` (text), `owner_id` (uuid), `settings` (jsonb), `created_at` (timestamptz), `updated_at` (timestamptz) | `id` | `owner_id REFERENCES public.profiles(id) ON DELETE RESTRICT` | PK on `id`, index on `owner_id` | **UNKNOWN (STAGING MISSING)** |
| **`public.family_members`** | `core.sql` L75-105<br>Dashboard Screenshot 08 | None (No staging project) | `id` (uuid), `family_id` (uuid), `user_id` (uuid), `role` (text), `status` (text), `created_at` (timestamptz) | `id` | `family_id REFERENCES public.families(id) ON DELETE CASCADE`<br>`user_id REFERENCES public.profiles(id) ON DELETE CASCADE` | `UNIQUE(family_id, user_id)`<br>Index on `(user_id, status)` | **UNKNOWN (STAGING MISSING)** |
| **`public.devices`** | `core.sql` L120-155 | None (No staging project) | `id` (uuid), `family_id` (uuid), `child_user_id` (uuid), `installation_id` (text), `display_name` (text), `platform` (text), `status` (text), `battery_level` (int), `created_at`, `updated_at` | `id` | `family_id REFERENCES public.families(id) ON DELETE CASCADE`<br>`child_user_id REFERENCES public.profiles(id) ON DELETE CASCADE` | `UNIQUE(family_id, installation_id)`<br>Index on `(family_id, child_user_id)` | **UNKNOWN (STAGING MISSING)** |
| **`public.location_events`** | `core.sql` L245-265 | None (No staging project) | `id` (uuid), `device_id` (uuid), `family_id` (uuid), `lat` (float8), `lng` (float8), `accuracy_m` (real), `recorded_at` (timestamptz), `source` (text) | `id` | `device_id REFERENCES public.devices(id) ON DELETE CASCADE`<br>`family_id REFERENCES public.families(id) ON DELETE CASCADE` | Index on `(family_id, recorded_at DESC)`<br>Index on `(device_id, recorded_at DESC)` | **UNKNOWN (STAGING MISSING)** |
| **`public.usage_daily`** | `core.sql` L220-240 | None (No staging project) | `id` (uuid), `device_id` (uuid), `family_id` (uuid), `day` (date), `package_name` (text), `app_label` (text), `total_ms` (int8), `source` (text) | `id` | `device_id REFERENCES public.devices(id) ON DELETE CASCADE`<br>`family_id REFERENCES public.families(id) ON DELETE CASCADE` | `UNIQUE(device_id, day, package_name)`<br>Index on `(family_id, day DESC)` | **UNKNOWN (STAGING MISSING)** |
| **`public.safety_alerts`** | `core.sql` L270-295 | None (No staging project) | `id` (uuid), `family_id` (uuid), `device_id` (uuid), `type` (text), `severity` (text), `message` (text), `payload` (jsonb), `created_at` (timestamptz) | `id` | `family_id REFERENCES public.families(id) ON DELETE CASCADE`<br>`device_id REFERENCES public.devices(id) ON DELETE CASCADE` | Index on `(family_id, created_at DESC)` | **UNKNOWN (STAGING MISSING)** |
| **`public.audit_logs`** | `core.sql` L310-335 | None (No staging project) | `id` (uuid), `family_id` (uuid), `actor_user_id` (uuid), `device_id` (uuid), `event_type` (text), `target_type` (text), `metadata` (jsonb), `created_at` (timestamptz) | `id` | `family_id REFERENCES public.families(id) ON DELETE SET NULL`<br>`actor_user_id REFERENCES public.profiles(id) ON DELETE SET NULL`<br>`device_id REFERENCES public.devices(id) ON DELETE SET NULL` | Index on `(family_id, created_at DESC)`<br>Index on `(actor_user_id, created_at DESC)` | **UNKNOWN (STAGING MISSING)** |

---

## 3. Evidence Classification & Methodological Guardrails

A critical methodological boundary must be maintained regarding schema evidence:
- **Repository-Defined:** The complete SQL schema is formally defined across migrations `20260101000000_core.sql` through `20261103000100_zone_delete_atomic_rpc.sql`.
- **Dashboard-Observed (Production):** Phase 3.7 screenshots 04, 05, 06, 07, 08 visually confirm the existence of `profiles`, `families`, and `family_members` columns and constraints in production.
- **Staging Project Parity:** Because no staging project currently exists, no staging schema is observed or deployed. Staging parity is **UNKNOWN** and represents an operational blocker until a staging project is created and migrations are pushed.

---

## 4. Staging Schema Provisioning Requirement

If the owner authorizes the creation of a dedicated staging project (`parent-control-staging`), schema parity must be established by applying the full repository migration sequence:
```bash
# Required sequence for future staging setup:
supabase link --project-ref <new_staging_ref>
supabase db push
```
No live test execution may occur until a future staging schema audit confirms `100% MATCH` against this baseline.
