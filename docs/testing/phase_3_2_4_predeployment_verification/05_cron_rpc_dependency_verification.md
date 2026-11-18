# Phase 3.2.4 — Report 05: Cron RPC Dependency & Migration Parity Audit

## 1. Executive Summary

This report delivers the technical dependency audit of the four database Remote Procedure Calls (RPCs) invoked by the deployed `cron` Edge Function (`supabase/functions/cron/index.ts`):
1. `expire_stale_sessions`
2. `detect_offline_devices`
3. `expire_abandoned_sessions`
4. `run_retention_sweep`

This audit cross-references live Supabase Dashboard evidence ([P322_03_database_functions.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_03_database_functions.png) and full snapshot `snapshot_full_1794997836100.txt`) against local repository migrations.

---

## 2. RPC Dependency Parity Matrix

| RPC Name | Defined in Migration | Migration File | Present on Hosted Project? | Function Signature & Return Type | Invocation Privilege |
| :--- | :--- | :--- | :---: | :--- | :---: |
| `expire_stale_sessions` | Core Functions | `20260101000100_functions.sql` | **YES (PRESENT)** | `() -> integer` | `service_role` |
| `detect_offline_devices`| Core Functions | `20260101000100_functions.sql` | **YES (PRESENT)** | `() -> integer` | `service_role` |
| `expire_abandoned_sessions` | Abandoned Session Sweep | `20261030000100_abandoned_session_sweep.sql` | **NO (UNAPPLIED)** | `(p_max_age interval) -> integer` | `service_role` |
| `run_retention_sweep` | Retention Sweep | `20261030000300_retention_sweep.sql` | **NO (UNAPPLIED)** | `() -> jsonb` | `service_role` |

---

## 3. Deep Analysis of the Two Missing RPCs

### 1. `expire_abandoned_sessions`
- **Migration Source:** `supabase/migrations/20261030000100_abandoned_session_sweep.sql:87`
- **Status in Hosted Database:** **NOT PRESENT**.
- **Edge Function Tolerance:**
  In `supabase/functions/cron/index.ts:79`:
  ```ts
  case "sweep_sessions": {
    const rpc = await db.rpc("expire_abandoned_sessions", { p_max_age: "24 hours" });
    if (rpc.error) {
      if (isMissingFunction(rpc.error)) {
        console.warn("sweep_sessions_function_missing");
        return ok({ skipped: true, reason: "function_missing" });
      }
      ...
  ```
  - The Edge Function code was intentionally engineered with an `isMissingFunction` guard. If `expire_abandoned_sessions` is missing in PostgreSQL (error code `PGRST202` or `42883`), the Edge Function answers `HTTP 200 OK` with `{ "skipped": true, "reason": "function_missing" }` instead of throwing an unhandled `500 Internal Server Error`.

### 2. `run_retention_sweep`
- **Migration Source:** `supabase/migrations/20261030000300_retention_sweep.sql:113`
- **Status in Hosted Database:** **NOT PRESENT**.
- **Edge Function Tolerance:**
  In `supabase/functions/cron/index.ts:103`:
  ```ts
  case "retention_sweep": {
    const rpc = await db.rpc("run_retention_sweep");
    if (rpc.error) {
      if (isMissingFunction(rpc.error)) {
        console.warn("retention_sweep_function_missing");
        return ok({ skipped: true, reason: "function_missing" });
      }
      ...
  ```
  - Similarly, the Edge Function catches the missing function error and returns `HTTP 200 OK` with `{ "skipped": true, "reason": "function_missing" }`.

---

## 4. Operational Invariants & Failure Behavior

### 1. Idempotency & Concurrency:
- `expire_stale_sessions()`: Executes `UPDATE public.remote_sessions SET status = 'ended' WHERE status IN ('pending', 'accepted') AND expires_at < now()`. Multiple invocations produce identical safe outcomes without deadlocks.
- `detect_offline_devices()`: Evaluates `last_seen_at` on active devices and creates alerts in `safety_alerts` with a cooldown window, preventing alert storms.

### 2. Retention Consequence:
- Because `run_retention_sweep` has not been applied to the hosted database, calling the `retention_sweep` action skips execution cleanly without error.
- **Consequence:** Automated telemetry truncation is paused until migration `20261030000300_retention_sweep.sql` is applied to hosted production.

---

## 5. Security & Privilege Verdict

1. **Service Role Isolation:**
   - Both deployed RPCs (`expire_stale_sessions` and `detect_offline_devices`) are strictly granted to `service_role` with execution revoked from `public`, `anon`, and `authenticated`.
   - Untrusted clients cannot trigger or manipulate database sweeps.
2. **Defensive Programming:**
   - The Edge Function's defensive `isMissingFunction` design prevents operational crashes when migrations and function deployments occur out of sync.
