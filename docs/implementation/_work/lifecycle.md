# Lifecycle workstream notes (Phase 1)

## Shipped

- `supabase/functions/account/`: JWT-only `export`, `delete_account` and
  `retention_report`. Export is the raw attachment response (no storage bucket);
  deletion refuses an owner whose family still has another active member or an
  active device, writes `account_deleted` to `audit_logs` before removing the
  profile (actor becomes NULL and the row survives), then calls
  `auth.admin.deleteUser`. Pure rules live in `validation.ts` / `retention.ts`.
- `supabase/migrations/20261030000300_retention_sweep.sql`:
  `public.run_retention_sweep()` (SECURITY DEFINER, pinned `search_path`,
  service-role only, 10 000-row batches).
  **Phase 2 correction (2026-11-02):** the "10 000-row batches" phrase overstates what the
  batching buys. The loops are real (`:51-80` global tables, `:116-145` per-family tables, each
  `limit v_batch` … `exit when v_deleted < v_batch`), but the whole sweep runs inside the single
  transaction of one RPC call, and neither global delete has an index it can use:
  `webrtc_signals` has only `webrtc_signals_session_sequence_idx (session_id, sequence)`
  (`20260101000000_core.sql:369`) and `audit_logs` only `(family_id, created_at desc)` and
  `(actor_user_id, created_at desc)` (`:388`, `:390`), while the predicates filter on bare
  `created_at`. Each batch therefore re-scans the table (roughly O(N²/batch)) and the transaction
  holds one long lock. Open defect — see `docs/implementation/phase-2-open-gaps.md`.
- `supabase/functions/cron/index.ts`: `sweep_sessions` (24 h abandoned sessions)
  and `retention_sweep`. Both answer `200 {skipped:true}` when the SQL function is
  not deployed yet.
- Settings “Privacy & data”: real export (file + clipboard), two-step account
  deletion (`DELETE` + email), retention windows/counts/last sweep.

## External scheduler (no pg_cron)

This project has **no pg_cron**. The `cron` function must be called by an
external scheduler (GitHub Actions, Supabase dashboard scheduler, or any HTTPS
cron) with `x-cron-secret: $CRON_SECRET`; the function self-authenticates and
`CRON_SECRET` must be at least 16 characters.

Suggested daily jobs (replace host/secret):

```bash
curl -fsS -X POST "$SUPABASE_URL/functions/v1/cron" \
  -H "content-type: application/json" \
  -H "x-cron-secret: $CRON_SECRET" \
  -d '{"action":"sweep_sessions"}'

curl -fsS -X POST "$SUPABASE_URL/functions/v1/cron" \
  -H "content-type: application/json" \
  -H "x-cron-secret: $CRON_SECRET" \
  -d '{"action":"retention_sweep"}'
```

`skipped:true, reason:"function_missing"` is expected until the migrations are
applied; it is not an error. Do not schedule `retention_sweep` more often than
the batch size can absorb on first run (one backlog run is fine).

## Exact SQL to verify (dashboard SQL editor, service role)

```sql
-- 1. Function exists, is SECURITY DEFINER, pins search_path, service-only.
select p.prosecdef, p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'run_retention_sweep';

select has_function_privilege('anon', 'public.run_retention_sweep()', 'execute') as anon_exec,
       has_function_privilege('authenticated', 'public.run_retention_sweep()', 'execute') as authenticated_exec,
       has_function_privilege('service_role', 'public.run_retention_sweep()', 'execute') as service_exec;

-- 2. Run it once and inspect the counts (all four tables + per_family).
select public.run_retention_sweep();

-- 3. Last sweep marker read by `account` retention_report.
select created_at, metadata
from public.audit_logs
where event_type = 'retention_sweep'
order by created_at desc
limit 1;
```

Expected: `prosecdef = true`, `proconfig` contains `search_path=...`,
`anon_exec = false`, `authenticated_exec = false`, `service_exec = true`.
A second `run_retention_sweep()` returns zeros for the same data (idempotent)
and appends a new `retention_sweep` audit row.