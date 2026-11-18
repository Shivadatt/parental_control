# Phase 3.2.2 — Report 08: Storage, Realtime Publications & Cron Audit

## 1. Executive Summary

This report covers the live browser audit of Supabase Storage buckets, Realtime publications, and Cron job infrastructure for project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

Inspection was performed across the Storage Dashboard (`/storage/files`), Database Publications (`/database/publications`), and Integrations Cron (`/integrations/cron`).

---

## 2. Storage Buckets Audit

Live inspection of **Storage > Files** (`/storage/files`):

- **Total Buckets**: **0**
- **Bucket List**: None present.
- **Visual Evidence**: [P322_10_storage_buckets.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_10_storage_buckets.png)

### Design Parity Evaluation:
- The Parent Control application architecture deliberately does not use object storage for child photos, audio recordings, or avatars.
- All real-time streaming (camera, microphone, screen share) is handled peer-to-peer via WebRTC over encrypted DTLS/SRTP, without persistent file storage on Supabase buckets.
- The 0-bucket count is **intended and compliant with design**.

---

## 3. Realtime Publications Audit

Live inspection of **Database > Publications** (`/database/publications`):

- **Visual Evidence**:
  - [P322_11_realtime_publications.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_11_realtime_publications.png) (Overview)
  - [P322_12_supabase_realtime_tables.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_12_supabase_realtime_tables.png) (Publication Tables)

### Active Publications:
1. `supabase_realtime` (System ID: `16430`):
   - Events Enabled: `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`
   - Active Tables: **Exactly 4 tables**
2. `supabase_realtime_messages_publication` (System ID: `18401`):
   - Internal Supabase broadcast channel publication (1 system table).

### The 4 Realtime Tables in `supabase_realtime`:

| Table Name | Replication Switch | Client Consumer / Operational Purpose |
| :--- | :---: | :--- |
| `device_commands` | **CHECKED (ON)** | Child device listens for immediate commands (lock screen, ring, wipe, app limit change) pushed by the parent. |
| `remote_sessions` | **CHECKED (ON)** | Parent and child synchronize WebRTC session lifecycle states (`pending`, `active`, `ended`). |
| `safety_alerts` | **CHECKED (ON)** | Parent client instantly receives emergency SOS, geofence breaches, and tamper alerts. |
| `webrtc_signals` | **CHECKED (ON)** | Ephemeral SDP offers, answers, and ICE candidates exchange between parent and child clients. |

All other 15 tables have replication toggled **OFF**, preventing unnecessary database replication load and protecting sensitive historical logs from real-time leakage.

---

## 4. Cron & Scheduled Jobs Audit

Live inspection of **Integrations > Cron** (`/integrations/cron` and `/integrations/cron/jobs`):

- **Status**: **`Cron is not installed`** (Button "Install integration" available).
- **Configured pg_cron Jobs**: **0 jobs**
- **Visual Evidence**: [P322_14_cron_jobs.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_14_cron_jobs.png)

### Architectural Clarification:
1. The PostgreSQL extension `pg_cron` is not installed as an integration in the database dashboard.
2. Scheduled maintenance (such as token pruning, daily usage rollups, and stale session cleanup) is implemented via the deployed **`cron` Edge Function** (`supabase/functions/cron/`), which is triggered externally via an authorized webhook with `CRON_SECRET`.
3. There are zero unmanaged or dangling database cron jobs.
