# Phase 3.2.3 — Report 07: Scheduled Cron & Retention Automation Audit

## 1. Executive Summary

This report delivers the operational readiness audit of scheduled cron tasks, retention sweeping, and automated system maintenance for `parent-control-prod`.

The audit reveals a critical operational condition:
> **The `cron` Edge Function is deployed and configured with `CRON_SECRET` in Edge Function secrets, but NO active scheduler (neither `pg_cron` nor an external runner) is currently invoking it.**

---

## 2. Deployed Cron Infrastructure Overview

### 1. The `cron` Edge Function (`supabase/functions/cron/index.ts`)
- **Status:** **DEPLOYED** to `/functions/v1/cron`.
- **Authentication:** Requires HTTP header `x-cron-secret` matching `CRON_SECRET` via `constantTimeSecretEqual`.
- **JWT Verification:** Bypassed (`verify_jwt = false`) to permit automated runner invocation without user tokens.
- **Actions Implemented:**
  1. `expire_sessions`: Calls `db.rpc("expire_stale_sessions")`
  2. `detect_offline`: Calls `db.rpc("detect_offline_devices")`
  3. `sweep_sessions`: Calls `db.rpc("expire_abandoned_sessions", { p_max_age: "24 hours" })`
  4. `retention_sweep`: Calls `db.rpc("run_retention_sweep")`

### 2. The Database Extension Status
- **Live Dashboard Check:** **`Cron is not installed`** ([P322_14_cron_jobs.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_14_cron_jobs.png)).
- `pg_cron` extension is uninstalled. Configured database cron jobs: **0**.

### 3. Repository Automation Scan
- `.github/workflows/`: **DOES NOT EXIST**.
- No external webhook service (Cloudflare Worker, AWS Lambda, GCP Cloud Scheduler, cron-job.org) is currently wired to the project.

---

## 3. Operational Risk & Degradation Analysis

Because the `cron` function is not invoked periodically, what happens to system operations?

### Impact Assessment by Domain:

| Domain | Intended Cron Routine | Impact of Missing Cron | Risk Level | Mitigation Already Present? |
| :--- | :--- | :--- | :---: | :--- |
| **WebRTC Sessions** | `expire_stale_sessions` & `sweep_sessions` | Stale session rows remain in database in `accepted` state rather than being marked `expired`. | **P2 (Medium)** | **YES:** RLS policies explicitly enforce `expires_at > now()`. WebRTC signaling rejects connections after expiry. Also, `remote-session` Edge Function performs in-band lazy sweep before new session creation (`withAbandonedSweep`). |
| **Telemetry Retention** | `retention_sweep` | Location events (`location_events`) and daily app usage (`usage_daily`) rows accumulate indefinitely without being pruned according to family retention policies. | **P2 (Medium)** | **NO:** Data remains in database, consuming storage. On the Free tier (500 MB database cap), unbounded location logs will eventually exhaust quota. |
| **Offline Detection** | `detect_offline` | Automatic parent alerts when a child phone stops pinging are delayed. | **P3 (Low)** | **PARTIAL:** Parent UI displays `last_seen_at` directly from the `devices` table, allowing parents to see device freshness visually. |
| **Pairing Tokens** | `cleanup_expired_tokens` | Expired pairing token rows stay in `device_pairing_tokens`. | **P3 (Low)** | **YES:** Token lookup queries check `expires_at > now()` and `consumed_at IS NULL`. Expired tokens cannot be redeemed. |

---

## 4. Remediation Options (Requires User Decision)

### Option A: Enable Native Supabase Cron Integration (`pg_cron`)
- Go to Dashboard > Integrations > Cron (`/integrations/cron`).
- Click "Install integration" to enable `pg_cron` and `pg_net`.
- Add a periodic schedule in SQL (e.g., every 15 minutes) using `net.http_post` to invoke `/functions/v1/cron` with `x-cron-secret`.

### Option B: External Serverless Scheduler (Recommended for Free Tier)
- Set up an external cron trigger (e.g. GitHub Actions scheduled workflow or Cloudflare Worker) that executes:
```bash
curl -X POST "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/cron" \
  -H "x-cron-secret: $CRON_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"action":"sweep_sessions"}'
```
- Schedule:
  - `sweep_sessions`: Hourly.
  - `retention_sweep`: Once daily at midnight UTC.

---

## 5. Finding Classification

- **Finding CRON-01 (Severity: P2 - Medium):**
  - **Component:** `supabase/functions/cron/` & Database Retention
  - **Actual Risk:** Unbounded accumulation of telemetry and location rows over months, risking database storage quota exhaustion.
  - **Remediation Requires Explicit Approval:** YES (requires scheduler setup or `pg_cron` installation).
