# PHASE 3.2 — DATABASE SCHEMA INVENTORY & MIGRATION BASELINE

**Project:** Parent Control System (`parentcontrol_app`)  
**Target Project Name:** `parent-control-prod`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Target Cloud Region:** `ap-south-1`  
**Audit Execution Timestamp:** 2026-11-18T15:12:00+05:30  
**Audit Scope:** Relational Schema, Table Definitions, Foreign Keys, Indexes, Migration History  
**Execution Mode:** STRICT READ-ONLY AUDIT  

---

## 1. DATABASE TOPOLOGY & SCHEMAS

The PostgreSQL database underpinning the hosted project `hhqgreaoqulmfwfwarhc` is structured into isolated logical schemas to enforce clear separation of concerns, administrative privilege partitioning, and defense-in-depth:

| Schema Name | Owner / Role | Direct PostgREST API Exposure | Purpose & Contents |
|---|---|---|---|
| `public` | `postgres` | **YES** (Controlled strictly via Row-Level Security) | Contains all 19 application relational tables, exposed client RPC wrappers, and user-facing data entities. |
| `private` | `postgres` | **NO** (`REVOKE ALL FROM anon, authenticated`) | Contains security-critical procedures, password hashing helpers, authorization checks, internal state transition functions, and audit writers. Accessible only by `service_role` and PostgreSQL triggers. |
| `auth` | `supabase_admin` | **RESTRICTED** (Via GoTrue Auth API only) | Core Supabase authentication schema containing `auth.users`, `auth.identities`, `auth.refresh_tokens`, and session records. |
| `realtime` | `supabase_admin` | **INTERNAL** (Realtime Engine CDC) | Manages replication slots, change-data-capture publications, and broadcast channels. |
| `storage` | `supabase_admin` | **RESTRICTED** (Storage API) | Houses `storage.buckets` and `storage.objects` metadata. |
| `extensions`| `postgres` | **NO** | Contains PostgreSQL extensions (`uuid-ossp`, `pgcrypto`, `pg_stat_statements`). |

---

## 2. COMPREHENSIVE TABLE CATALOG (19 TABLES)

Every table defined in the core data contract (`docs/api-contract.md` §3–4) and instantiated via repository migrations has been analyzed.

| # | Table Name | Source Migration | Primary Purpose | Primary Key | Foreign Keys & Cascades | Key Constraints / Unique Indexes | Columns | RLS | Soft Delete / TTL |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `profiles` | `20260101000000_core.sql` | User account profiles, role binding (`parent`/`child`), display name | `id uuid` | `references auth.users(id) ON DELETE CASCADE` | `check (role in ('unset', 'parent', 'child'))`, `display_name length 1..60` | 5 | ENABLED | No / Cascades with Auth User |
| 2 | `families` | `20260101000000_core.sql` | Family group entity, retention settings, owner reference | `id uuid` | `owner_id -> profiles(id) ON DELETE CASCADE` | Unique index on `owner_id` where `deleted_at is null` | 7 | ENABLED | `deleted_at timestamptz` (Soft-deleted) |
| 3 | `family_members` | `20260101000000_core.sql` | User-to-Family association, membership lifecycle | `id uuid` | `family_id -> families CASCADE`, `user_id -> profiles CASCADE` | Unique `(family_id, user_id)`, Unique index on `user_id` where `status = 'active' and role = 'child'` | 7 | ENABLED | `removed_at timestamptz`, status: `active`/`removed` |
| 4 | `devices` | `20260101000000_core.sql` | Physical hardware inventory, enrollment status, heartbeat | `id uuid` | `family_id -> families CASCADE`, `child_user_id -> profiles CASCADE` | `platform in ('android', 'ios')`, `status in ('pending', 'active', 'revoked')`, `unique (child_user_id, device_fingerprint)` | 13 | ENABLED | `status = 'revoked'` |
| 5 | `device_pairing_tokens` | `20260101000000_core.sql` | Ephemeral 8-char pairing PINs for device onboarding (15m TTL) | `token text` | `child_user_id -> profiles CASCADE` | `token length 8`, `expires_at > created_at` | 6 | ENABLED | Ephemeral TTL (15 min) |
| 6 | `pairing_requests` | `20260101000000_core.sql` | Bi-directional parent-child link negotiation | `id uuid` | `token -> device_pairing_tokens CASCADE`, `family_id -> families CASCADE`, `parent_user_id/child_user_id -> profiles CASCADE` | `status in ('pending', 'accepted', 'rejected', 'expired')` | 8 | ENABLED | Expired after 15m or consumed |
| 7 | `device_policies` | `20260101000000_core.sql` | Operational rules (bedtime, daily app limits, web filter) | `id uuid` | `device_id -> devices CASCADE`, `family_id -> families CASCADE` | `policy_version >= 1`, unique `(device_id, policy_version)` | 7 | ENABLED | Versioned overwrite |
| 8 | `device_commands` | `20260101000000_core.sql` | Asynchronous command queue for child hardware | `id uuid` | `device_id -> devices CASCADE`, `family_id -> families CASCADE` | `command_type in ('lock', 'unlock', 'apply_policy', 'wipe', 'alarm')`, `status in ('queued', 'delivered', 'executed', 'failed', 'expired')` | 10 | ENABLED | Expired command cleanup (24h) |
| 9 | `usage_daily` | `20260101000000_core.sql` | Aggregated app screen-time and category metrics | `id uuid` | `device_id -> devices CASCADE`, `family_id -> families CASCADE` | Unique `(device_id, usage_date, app_identifier)` | 7 | ENABLED | Default 90-day retention sweep |
| 10 | `location_events` | `20260101000000_core.sql` | GPS fixes, altitude, speed, and accuracy telemetry | `id uuid` | `device_id -> devices CASCADE`, `family_id -> families CASCADE` | `latitude between -90 and 90`, `longitude between -180 and 180`, `accuracy >= 0` | 9 | ENABLED | Default 30-day retention sweep |
| 11 | `safe_zones` | `20260101000000_core.sql` | Geofence boundaries (center lat/lng, radius in meters) | `id uuid` | `family_id -> families CASCADE` | `radius_meters between 50 and 50000`, `latitude between -90 and 90` | 7 | ENABLED | Hard delete via audited RPC |
| 12 | `safe_zone_states` | `20260101000000_core.sql` | Realtime containment state per device and zone (`inside`/`outside`) | `id uuid` | `zone_id -> safe_zones CASCADE`, `device_id -> devices CASCADE` | Unique `(zone_id, device_id)`, `state in ('inside', 'outside', 'unknown')` | 6 | ENABLED | Cascades on safe_zone removal |
| 13 | `safety_alerts` | `20260101000000_core.sql` | Critical parent notifications (SOS, geofence, low battery) | `id uuid` | `family_id -> families CASCADE`, `device_id -> devices CASCADE` | `severity in ('info', 'warning', 'critical')`, `acknowledged boolean default false` | 9 | ENABLED | Preserved in family history |
| 14 | `remote_sessions` | `20260101000000_core.sql` | WebRTC audio assistance signaling session state | `id uuid` | `parent_user_id -> profiles CASCADE`, `child_user_id -> profiles CASCADE`, `device_id -> devices CASCADE` | `status in ('requested', 'accepted', 'active', 'ended', 'rejected', 'expired')` | 10 | ENABLED | 5m abandoned session sweep |
| 15 | `webrtc_signals` | `20260101000000_core.sql` | Ephemeral SDP offers, answers, and ICE candidates | `id uuid` | `session_id -> remote_sessions CASCADE` | `signal_type in ('offer', 'answer', 'ice')`, Unique `(session_id, sequence)` | 6 | ENABLED | Cascades on session removal |
| 16 | `audit_logs` | `20260101000000_core.sql` | Immutable append-only compliance and security event ledger | `id uuid` | `family_id -> families ON DELETE SET NULL`, `actor_user_id -> profiles ON DELETE SET NULL` | Immutable: UPDATE and DELETE blocked by trigger | 8 | ENABLED | 365-day legal compliance retention |
| 17 | `device_apps` | `20260101000000_core.sql` | Installed application inventory cache per enrolled device | `id uuid` | `device_id -> devices CASCADE`, `family_id -> families CASCADE` | Unique `(device_id, package_name)` | 8 | ENABLED | Synchronized with hardware device |
| 18 | `pairing_attempts` | `20260101000000_core.sql` | Brute-force rate limiting table for pairing PIN redemptions | `id uuid` | `parent_user_id -> profiles CASCADE` | Indexed on `(parent_user_id, attempted_at)` | 4 | ENABLED | Rolling 15-minute rate limit window |
| 19 | `child_contact_ids` | `20260101000500_child_contact_ids.sql` | Deterministic permanent child discovery IDs (`PC-XXXXXX`) | `child_user_id uuid` | `references public.profiles(id) ON DELETE CASCADE` | Unique `contact_id`, format `check (contact_id ~ '^PC-[A-Z0-9]{6}$')` | 4 | ENABLED | Lifetime of Child Profile |

---

## 3. INDEX ARCHITECTURE & PERFORMANCE AUDIT

The database employs specialized composite, unique, and partial indexes designed to eliminate race conditions and optimize querying performance:

### 3.1 Concurrency & Uniqueness Guard Indexes
1. **`families_one_active_per_owner`**  
   - Definition: `CREATE UNIQUE INDEX ON public.families (owner_id) WHERE deleted_at IS NULL;`  
   - Purpose: Strictly enforces business rule that a parent profile can own at most one active family concurrently.
2. **`family_members_one_active_child_family`**  
   - Definition: `CREATE UNIQUE INDEX ON public.family_members (user_id) WHERE status = 'active' AND role = 'child';`  
   - Purpose: Prevents a child profile from being simultaneously linked to multiple active families, closing multi-family takeover vulnerabilities.
3. **`webrtc_signals_session_sequence_uniq`**  
   - Definition: `CREATE UNIQUE INDEX ON public.webrtc_signals (session_id, sequence);`  
   - Purpose: Added in `20261030000200_phase1_authorization.sql` to block replayed WebRTC SDP/ICE packets from causing out-of-order signaling race conditions.
4. **`child_contact_ids_contact_id_key`**  
   - Definition: `CREATE UNIQUE INDEX ON public.child_contact_ids (contact_id);`  
   - Purpose: Guarantees global uniqueness of human-readable child pairing identifiers.

### 3.2 High-Throughput Range & Foreign Key Indexes
- `location_events_device_recorded_idx` on `(device_id, recorded_at DESC)`: Optimizes historical location queries and breadcrumb rendering.
- `usage_daily_device_date_idx` on `(device_id, usage_date DESC)`: Drives parent dashboard screen-time analytics.
- `safety_alerts_family_unread_idx` on `(family_id, acknowledged, created_at DESC)`: Powers real-time notification feeds.
- `device_commands_device_poll_idx` on `(device_id, status, created_at)`: Accelerates periodic command polling from child daemon services.

---

## 4. SCHEMA MIGRATION CHRONOLOGY

The local migration history consists of 14 sequential migrations that define the evolution of the database schema:

| Sequence | Migration File Name | Target Schemas / Objects | Core Purpose & Architectural Change | Hosted Status |
|---|---|---|---|---|
| **01** | `20260101000000_core.sql` | `public`, `private`, 18 tables | Initial foundation: tables, foreign keys, core updated_at and auth triggers, base RLS helpers. | **Applied** |
| **02** | `20260101000100_functions.sql` | `public`, `private` RPCs | Stored procedures: `create_family_with_owner`, `apply_policy_version`, `unlink_child`, `revoke_device`, command pollers. | **Applied** |
| **03** | `20260101000200_rls.sql` | `public` RLS policies | Comprehensive Row Level Security policies for all initial tables and private Realtime topic authorization. | **Applied** |
| **04** | `20260101000300_service_role_grants.sql`| Schema grants | Explicit table permissions granted to `service_role` for Edge Function data mediation. | **Applied** |
| **05** | `20260101000400_device_recovery.sql` | `request_device_recovery` | Emergency device recovery stored procedure for child hardware secret re-issuance. | **Applied** |
| **06** | `20260101000500_child_contact_ids.sql`| `child_contact_ids` table | Introduces permanent `PC-XXXXXX` human-readable pairing codes with lookup RPC. | **Applied** |
| **07** | `20260101000600_atomic_pairing_invite.sql`| Pairing RPCs | Race-condition-free atomic pairing invite creation (`create_pairing_invite`, `create_pairing_request`). | **Applied** |
| **08** | `20261028000100_remote_session_concurrency.sql`| WebRTC RPCs | Concurrency lock on remote audio assistance session requests to prevent simultaneous collisions. | **Applied** |
| **09** | `20261028000200_parent_controlled_session_lifetime.sql`| State machine | Enforces parent-controlled WebRTC lifetime and validates transition states via trigger. | **Applied** |
| **10** | `20261028000300_signaling_open_session.sql`| WebRTC RLS | RLS policy update permitting open-session signaling data exchange between verified participants. | **Applied** |
| **11** | `20261030000100_abandoned_session_sweep.sql`| Cleanup RPC | Introduces `expire_abandoned_sessions` sweeping un-consented audio sessions older than 5 minutes. | **Applied** |
| **12** | `20261030000200_phase1_authorization.sql`| Hardening | Security hardening: revokes direct DELETE on `safe_zones`, revokes public execute on recovery helpers, adds signal uniq index. | **Applied** |
| **13** | `20261030000300_retention_sweep.sql` | Retention RPC | Configurable retention sweep procedure for purging stale telemetry based on family settings. | **Applied** |
| **14** | `20261103000100_zone_delete_atomic_rpc.sql`| `delete_safe_zone_audited`| Atomic safe zone deletion RPC combining zone deletion and audit entry in a single atomic transaction. | **Local Validated** |

---

## 5. SCHEMA DISCREPANCY & GAP TRACKING

| Component | Local Baseline Requirement | Hosted Observation (`hhqgreaoqulmfwfwarhc`) | Discrepancy Severity | Resolution / Status |
|---|---|---|---|---|
| **Table Count** | 19 Tables in `public` | 19 Tables in `public` | **None** | Full structural parity verified |
| **Foreign Keys** | Cascades enforced on `profiles` & `families` | Cascades active on all child tables | **None** | Referential integrity verified |
| **Safe Zone Delete**| Direct DELETE revoked; audited RPC required | Direct DELETE revoked on `public.safe_zones` | **None** | Phase 1 hardening intact on hosted |
| **Child Contact ID**| Permanent `PC-XXXXXX` registry table | Table `public.child_contact_ids` present | **None** | Contact ID infrastructure active |
| **Signal Uniqueness**| `(session_id, sequence)` unique constraint | Unique index present on hosted table | **None** | WebRTC replay protection active |

---

## 6. MANDATORY SAFETY ASSERTIONS

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
