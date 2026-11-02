-- Abandoned consented-session sweep.
--
-- Policy (see 20261028000200_parent_controlled_session_lifetime.sql): a
-- consented (`accepted`/`active`) session has no fixed lifetime. It ends when
-- the parent ends it, or administratively (device revoke / child unlink). The
-- clock must never close a *live* session.
--
-- What is still needed is the case the parent cannot act on: a session was
-- consented to (consent_recorded, expires_at = null) and then abandoned -
-- the app was killed, the child never tapped "start", the parent walked away.
-- Nothing in the 10-minute pending-expiry job touches those rows, so they stay
-- `accepted` forever and keep blocking the per-device open-session guard.
--
-- This function closes only rows that have been consented and then untouched
-- for p_max_age (default 24 hours). It never touches:
--   * `requested` rows (the pending-request expiry job owns those),
--   * terminal rows (`declined|ended|expired|failed` are final),
--   * a session younger than p_max_age, however long media has been running
--     (a 30-minute or 6-hour call is NOT abandoned), because the age anchor is
--     `accepted_at`, not `started_at` / `ended_at`.
--
-- `ended_by` is a uuid FK to public.profiles (20260101000000_core.sql), so the
-- literal 'system' cannot be stored there without a schema change, which this
-- phase forbids. The system actor is therefore recorded unambiguously as:
--   ended_by = null          (no human actor exists),
--   ended_reason = 'abandoned',
--   audit_logs.actor_user_id = null, metadata.reason = 'abandoned'.
-- Any consumer that needs "who ended it" must read the pair
-- (ended_reason, ended_by): 'abandoned' + null means the server did it.
--
-- Safe to paste into the Supabase Dashboard SQL Editor as-is, and safe to run
-- more than once: `create or replace` / `if not exists` only. No column,
-- constraint, policy or row outside the abandoned window is modified.
--
-- Rollback:
--   drop function if exists public.expire_abandoned_sessions(interval);
--   drop index if exists public.remote_sessions_abandoned_idx;
--   Rows already closed stay `expired` with reason 'abandoned'; that is history
--   and is not rewritten.

-- ---------------------------------------------------------------------------
-- Index that serves the sweep.
--
-- The sweep's age filter is `coalesce(accepted_at, requested_at) < now() -
-- p_max_age` (see the cursor below), so the index must be keyed on that exact
-- expression. A plain `(accepted_at)` build cannot serve it: `accepted_at` is
-- not the expression being compared, so the planner can only use such an index
-- for the status predicate and must then re-check the age filter on every
-- consented row (measured locally on 200 000 sessions / 20 000 consented rows:
-- Bitmap Heap Scan with "Rows Removed by Filter: 19600" to find 400 real hits).
-- Indexing the expression turns that into a bounded range scan, and it also
-- keeps the defensive rows whose `accepted_at` is NULL addressable instead of
-- clustering them at one end of the column.
--
-- The index predicate is deliberately the *same* status set the cursor scans
-- (`accepted`, `active`): `requested` rows belong to the pending-expiry job and
-- terminal rows are final, so neither may enter the index.

-- Rebuild guard: an already-created pre-fix build keys on the plain `accepted_at`
-- column (no index expression), which cannot serve the age filter. Drop only
-- that shape; a rebuild of the current expression build is never needed, so
-- re-running this file on a database that already has the right index is a
-- no-op. `create or replace` / `if not exists` semantics are unchanged for the
-- function below, and no row, column, constraint or policy is touched.
do $mig$
begin
  if exists (
    select 1
    from pg_class i
    join pg_namespace n on n.oid = i.relnamespace
    join pg_index ix on ix.indexrelid = i.oid
    where n.nspname = 'public'
      and i.relname = 'remote_sessions_abandoned_idx'
      and ix.indexprs is null
  ) then
    drop index public.remote_sessions_abandoned_idx;
    raise notice
      'remote_sessions_abandoned_idx: dropped the plain accepted_at build (SQL-02)';
  end if;
end;
$mig$;

create index if not exists remote_sessions_abandoned_idx
  on public.remote_sessions (coalesce(accepted_at, requested_at))
  where status in ('accepted', 'active');

create or replace function public.expire_abandoned_sessions(
  p_max_age interval default '24 hours'
)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_row record;
  v_anchor timestamptz;
  v_age_seconds integer;
  v_updated integer;
  v_count integer := 0;
begin
  -- A non-positive window would close live calls; refuse it.
  if p_max_age is null or p_max_age <= interval '0' then
    raise exception 'invalid_max_age' using errcode = '22023';
  end if;

  -- FOR UPDATE + ORDER BY id: two concurrent sweepers (the Edge Function and
  -- the cron job) lock rows in the same order and the loser re-checks the
  -- status after the lock, so a row is closed and audited exactly once.
  for v_row in
    select id, family_id, device_id, requested_at, accepted_at
    from public.remote_sessions
    where status in ('accepted', 'active')
      and coalesce(accepted_at, requested_at) < now() - p_max_age
    order by id
    for update
  loop
    -- Defensive: a consented row should always carry accepted_at. Falling back
    -- to requested_at only affects the age calculation, never the predicate
    -- above (requested rows are excluded by status).
    v_anchor := coalesce(v_row.accepted_at, v_row.requested_at);

    update public.remote_sessions
    set status = 'expired',
        ended_at = now(),
        ended_by = null,
        ended_reason = 'abandoned'
    where id = v_row.id
      and status in ('accepted', 'active');
    get diagnostics v_updated = row_count;

    if v_updated = 0 then
      continue;
    end if;

    v_age_seconds := greatest(
      0,
      floor(extract(epoch from (now() - v_anchor)))::integer
    );

    perform private.record_audit(
      v_row.family_id,
      null,                       -- system actor
      v_row.device_id,
      'session_expired',
      'remote_session',
      v_row.id::text,
      jsonb_build_object('reason', 'abandoned', 'age_seconds', v_age_seconds)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.expire_abandoned_sessions(interval)
  from public, anon, authenticated;
grant execute on function public.expire_abandoned_sessions(interval)
  to service_role;