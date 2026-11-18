# Phase 3.2.2 — Report 09: Backups, Observability & Project Settings Audit

## 1. Executive Summary

This report documents the live audit of database backup policies, unified log observability, and project infrastructure settings for project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).

Inspection was performed on **Database Backups** (`/database/backups/scheduled`), **Logs Explorer** (`/logs/explorer`), **General Settings** (`/settings/general`), and **API Keys** (`/settings/api-keys`).

---

## 2. Database Backups Audit

Live inspection of **Database > Backups > Scheduled** (`/database/backups/scheduled`):

- **Plan Level**: `FREE`
- **Backup Status**: **Not included in Free Plan**
  - Live Notice: *"Free Plan does not include project backups. Upgrade to the Pro Plan for up to 7 days of scheduled backups."*
- **Active Automated Backups**: **0**
- **Visual Evidence**: [P322_13_database_backups.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_13_database_backups.png)

### Recommendation:
For production reliability and disaster recovery, manual database dumps (via `pg_dump` or Supabase CLI) or an organization upgrade to the Pro tier should be evaluated prior to commercial child enrollment.

---

## 3. Unified Logs & Observability Explorer

Live inspection of **Logs > Explorer** (`/logs/explorer`):

- **Visual Evidence**: [P322_15_logs_explorer.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_15_logs_explorer.png)

### Log Streams Available:
1. `edge_logs`: Supabase API Gateway requests and routing
2. `postgres_logs`: PostgreSQL engine queries, errors, and triggers
3. `postgrest_logs`: PostgREST REST API invocations
4. `pooler_logs`: Supavisor connection pooling logs
5. `auth_logs`: GoTrue sign-up, sign-in, token refresh, and OTP attempts
6. `storage_logs`: Supabase Storage operations
7. `realtime_logs`: WebSockets connection status and broadcast traffic
8. `edge_functions_logs`: Execution logs, stdout/stderr from Deno Edge Functions
9. `pgcron_logs`: Cron job execution logs

### Current System Activity:
- Live query against `edge_logs` in the last hour showed "No results found", indicating an idle, stable state during the inspection window.
- 0 custom saved queries.

---

## 4. Project General & Infrastructure Settings

Live inspection of **Project Settings > General** (`/settings/general`):

- **Visual Evidence**: [P322_16_settings_general.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_16_settings_general.png)

| Parameter | Observed Value | Notes |
| :--- | :--- | :--- |
| **Project Name** | `parent-control-prod` | Matches production specification |
| **Project ID** | `hhqgreaoqulmfwfwarhc` | Matches application environment config |
| **Project Region** | `ap-northeast-2` | Northeast Asia (Seoul) |
| **PostgreSQL Version** | `17.11.0.003` | Upgrade available to `17.12.0.000` |
| **PostgREST Version** | `14.18` | Current active REST gateway |
| **Auth Version** | `2.198.0` | Current active GoTrue auth daemon |
| **Organization Members**| 1 (`spg7753@gmail.com`) | Role: `Owner` |
| **Custom Domains** | None | Free tier default subdomain active |

---

## 5. API Keys & Data API Settings

Live inspection of **Settings > API Keys** and **Integrations > Data API**:

- **Visual Evidence**:
  - [P322_17_settings_api.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_17_settings_api.png) (Data API Overview)
  - [P322_17b_settings_api_keys.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_17b_settings_api_keys.png) (Publishable & Secret Keys)
  - [P322_17c_settings_legacy_api_keys.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_17c_settings_legacy_api_keys.png) (Legacy Keys)

| Key / Parameter | Status | Observed Detail |
| :--- | :---: | :--- |
| **RESTful Endpoint** | **ACTIVE** | `https://hhqgreaoqulmfwfwarhc.supabase.co/rest/v1/` |
| **Legacy `anon` Key** | **PRESENT** | Matches client `lib/core/constants/app_constants.dart` (`eyJhbGciOiJIUzI1Ni...`) |
| **New Publishable Key**| **PRESENT** | `sb_publishable_sP1oJ0Pxm6W5YWnFEX3iBA_oLHHovuv` |
| **Service Role & Secret Keys** | **SECURED** | Strictly masked in dashboard; never revealed or logged during audit. |
