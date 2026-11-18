# Phase 3.2.2 — Report 02: Database Tables Inventory

## 1. Executive Summary

This report provides the full inventory of database tables residing in the PostgreSQL database of project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

The inventory was verified via live inspection of the Supabase Dashboard Table Editor (`/editor`) and Database Tables viewer (`/database/tables`).

---

## 2. Table Count & Schema Distribution

- **Total Public Tables**: **19 tables**
- **Schema**: `public`
- **RLS Status**: All 19 tables have Row Level Security enabled.
- **Visual Evidence**: [P322_02_table_editor_01.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_02_table_editor_01.png)

---

## 3. Exhaustive Table Inventory

| # | Table Name | Purpose / Description | Primary Key | Key Relationships / Foreign Keys |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `audit_logs` | Append-only security audit log for sensitive actions | `id` (UUID) | `family_id`, `actor_id` |
| 2 | `child_contact_ids` | Stable child identifier used to initiate pairing | `id` (UUID) | `child_id` -> `profiles(id)` |
| 3 | `device_apps` | Installed applications on enrolled child devices | `id` (UUID) | `device_id` -> `devices(id)` |
| 4 | `device_commands` | Realtime asynchronous commands sent to child devices | `id` (UUID) | `device_id` -> `devices(id)` |
| 5 | `device_pairing_tokens`| Cryptographic tokens generated for device enrollment | `id` (UUID) | `family_id`, `created_by` |
| 6 | `device_policies` | Parental restriction policies (app limits, bedtime, web) | `id` (UUID) | `device_id` -> `devices(id)` |
| 7 | `devices` | Enrolled parent and child hardware devices | `id` (UUID) | `family_id`, `owner_id` |
| 8 | `families` | Family groups linking parent and children | `id` (UUID) | Soft-deleted via `deleted_at` |
| 9 | `family_members` | Membership junction between profiles and families | `id` (UUID) | `family_id`, `user_id` -> `profiles(id)` |
| 10 | `location_events` | Periodic GPS tracking and geofence entry/exit events | `id` (UUID) | `device_id` -> `devices(id)` |
| 11 | `pairing_attempts` | Rate limiting and failure tracking for device pairing | `id` (UUID) | `ip_address`, `token_hash` |
| 12 | `pairing_requests` | Active pairing handshake sessions | `id` (UUID) | `family_id`, `device_id` |
| 13 | `profiles` | Application user profile extending `auth.users` | `id` (UUID) | `id` -> `auth.users(id)` |
| 14 | `remote_sessions` | WebRTC live camera/screen streaming session metadata | `id` (UUID) | `initiator_id`, `device_id` |
| 15 | `safe_zone_states` | Realtime state tracking whether child is inside/outside | `id` (UUID) | `safe_zone_id`, `child_id` |
| 16 | `safe_zones` | Geofenced circular safety zones (home, school, etc.) | `id` (UUID) | `family_id` -> `families(id)` |
| 17 | `safety_alerts` | Instant push/realtime emergency and policy alert events | `id` (UUID) | `family_id`, `child_id` |
| 18 | `usage_daily` | Aggregated daily screen time and application usage stats | `id` (UUID) | `device_id` -> `devices(id)` |
| 19 | `webrtc_signals` | Ephemeral signaling messages for WebRTC peer connection | `id` (UUID) | `session_id` -> `remote_sessions(id)` |

---

## 4. Observations & Baseline Parity

1. **Exact 19-Table Match**: The 19 tables in the live database exactly match the 19 migration files in the repository (`supabase/migrations/`).
2. **Naming Conventions**: Strict adherence to lowercase snake_case naming throughout.
3. **Partitioning / Archival**: Telemetry tables (`location_events`, `usage_daily`, `audit_logs`) feature timestamp indexes for periodic pruning via Edge Functions or background cleanup.
4. **Visual Evidence**: [P322_02_table_editor_01.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_02_table_editor_01.png) displays all 19 public tables in the sidebar navigation.
