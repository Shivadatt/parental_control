-- Enforced data retention (Phase 1, workstream lifecycle).
--
-- `public.run_retention_sweep()` is the single server-side retention job. It is
-- called by the `cron` Edge Function action `retention_sweep`, which an external
-- scheduler (GitHub Actions / dashboard scheduler / any HTTPS cron) invokes with
-- the CRON_SECRET. There is no pg_cron and no hosted scheduler in this phase.
--
-- Deletes, in order:
--   1. webrtc_signals older than 7 days (signaling payloads have no long-term
--      value; the session row keeps the history),
--   2. audit_logs older than 365 days (append-only while retained),
--   3. per-family location_events older than
--      settings->>'location_retention_days' (default 30),
--   4. per-family usage_daily older than
--      settings->>'usage_retention_days' (default 90); `usage_daily.day` is a
--      calendar date, so the cutoff is a date.
--
-- Batched (10 000 rows per statement) - see "What batched does and does not
-- mean here" below: it bounds a statement, not the transaction. Safe to run
-- repeatedly: an empty second run deletes zero rows. No table,
-- column, constraint or policy changes. The only write outside the four tables
-- is one append-only `audit_logs` summary row (`event_type='retention_sweep'`),
-- which the `account` Edge Function reads as "last sweep".
--
-- Rollback:
--   drop function if exists public.run_retention_sweep();
--   drop index if exists public.webrtc_signals_created_idx;
--   drop index if exists public.audit_logs_created_idx;
-- Rows already deleted stay deleted; that is the point of retention.

-- ---------------------------------------------------------------------------
-- Access paths (SQL-04, phase-2 open gaps).
--
-- Steps 1 and 2 filter on a bare `created_at` that no index led with:
-- `webrtc_signals` had only `(session_id, sequence)` and `audit_logs` only
-- `(family_id, created_at desc)` / `(actor_user_id, created_at desc)`. Every
-- batch therefore ran a Seq Scan, and because all batches of one call share one
-- transaction the next batch re-scanned the same pages (now also carrying the
-- dead tuples of the previous batch), so the backlog cost grew quadratically.
-- Measured locally with 140 000 signals / 200 800 audit rows and a 60 000 /
-- 25 000 backlog: one call took 1 151 ms and `pg_stat_user_tables` counted 23
-- seq scans / 1 270 001 tuples read on `webrtc_signals` and 22 seq scans /
-- 1 595 200 tuples read on `audit_logs`.
--
-- Steps 3 and 4 already match an index -
-- `location_events_family_recorded_idx (family_id, recorded_at desc)` and
-- `usage_daily_family_day_idx (family_id, day)`, both measured as Bitmap Index
-- Scans with the whole predicate in "Index Cond" - so nothing is added for them.
--
-- The two indexes below are exactly what the sweep's own predicates need
-- (`created_at < v_now - <window>`, no family qualifier) and turn each batch
-- into a bounded range scan instead of a full re-scan.
create index if not exists webrtc_signals_created_idx
  on public.webrtc_signals (created_at);

create index if not exists audit_logs_created_idx
  on public.audit_logs (created_at);

-- ---------------------------------------------------------------------------
-- What "batched" does and does not mean here (read before enabling a schedule).
--
-- `v_batch` bounds one *statement*: at most 10 000 rows are looked up and
-- deleted per DELETE. It does not bound the call: a PL/pgSQL function cannot
-- COMMIT, so every batch of every table inside one call is a single
-- transaction. A call is all-or-nothing - it either walks the whole backlog and
-- commits, or it rolls back completely.
--
-- True today:
--   * idempotent - the boundaries are absolute ages, so a second call deletes
--     nothing new (tests/72, tests/74);
--   * safe to run repeatedly, and safe on an empty dataset - the first batch
--     deletes 0 rows and `exit when v_deleted < v_batch` ends the loop at once;
--   * after this change, linear rather than quadratic in the backlog, which is
--     what keeps one scheduled call per period viable.
-- Not true today, and not achievable inside a function at all:
--   * partial progress committed. A backlog too large for one call cannot be
--     chewed through over several calls.
--
-- Bounded-across-calls execution is therefore a contract decision, recorded
-- here rather than shipped silently (analysis and measurements:
-- docs/implementation/_work/p3-sql-performance.md):
--   A. `create procedure public.run_retention_sweep(p_max_rows integer)` with
--      `commit` inside the batch loops - needs the `cron` Edge Function action
--      `retention_sweep` to CALL instead of `rpc(...)`, so it touches workstream
--      `lifecycle` files and needs owner approval.
--   B. an additive capped overload `run_retention_sweep(p_max_rows integer)` -
--      rejected on inspection: giving the parameter a default removes the
--      0-arg signature that tests/72 and the deployment manifest query
--      (`public.run_retention_sweep()`), and a second no-default overload makes
--      `rpc('run_retention_sweep')` ambiguous for PostgREST (PGRST202).
--   C. ship only the indexes (done here) and keep the current one-call model.
-- Deliberately not implemented: no advisory-lock skip, no per-call row ceiling,
-- no new or renamed RPC, and the service-role-only grant is unchanged.

create or replace function public.run_retention_sweep()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_batch constant integer := 10000;
  v_now timestamptz := now();
  v_deleted integer;
  v_signals integer := 0;
  v_audit integer := 0;
  v_location integer := 0;
  v_usage integer := 0;
  v_families integer := 0;
  v_family record;
  v_location_days integer;
  v_usage_days integer;
  v_family_location integer;
  v_family_usage integer;
  v_per_family jsonb := '[]'::jsonb;
begin
  -- 1. Signaling payloads: 7 days, global (no per-family window exists).
  loop
    delete from public.webrtc_signals w
    using (
      select id
      from public.webrtc_signals
      where created_at < v_now - interval '7 days'
      limit v_batch
    ) doomed
    where w.id = doomed.id;
    get diagnostics v_deleted = row_count;
    v_signals := v_signals + v_deleted;
    exit when v_deleted < v_batch;
  end loop;

  -- 2. Audit history: 365 days. The service-role guard in
  --    private.audit_logs_append_only() permits this SECURITY DEFINER context.
  loop
    delete from public.audit_logs a
    using (
      select id
      from public.audit_logs
      where created_at < v_now - interval '365 days'
      limit v_batch
    ) doomed
    where a.id = doomed.id;
    get diagnostics v_deleted = row_count;
    v_audit := v_audit + v_deleted;
    exit when v_deleted < v_batch;
  end loop;

  -- 3 + 4. Per-family windows. Soft-deleted families are included: their data
  -- is invisible but must not live forever.
  for v_family in
    select f.id, f.settings
    from public.families f
    order by f.id
  loop
    v_families := v_families + 1;

    -- jsonb -> text is not trusted: only a run of digits is cast, otherwise
    -- the schema default applies. Mirrors account/retention.ts.
    v_location_days := case
      when btrim(coalesce(v_family.settings ->> 'location_retention_days', ''))
        ~ '^[0-9]{1,5}$'
        then btrim(v_family.settings ->> 'location_retention_days')::integer
      else 30
    end;
    v_usage_days := case
      when btrim(coalesce(v_family.settings ->> 'usage_retention_days', ''))
        ~ '^[0-9]{1,5}$'
        then btrim(v_family.settings ->> 'usage_retention_days')::integer
      else 90
    end;
    if v_location_days < 1 then
      v_location_days := 30;
    elsif v_location_days > 3650 then
      v_location_days := 3650;
    end if;
    if v_usage_days < 1 then
      v_usage_days := 90;
    elsif v_usage_days > 3650 then
      v_usage_days := 3650;
    end if;

    v_family_location := 0;
    loop
      delete from public.location_events le
      using (
        select id
        from public.location_events
        where family_id = v_family.id
          and recorded_at < v_now - make_interval(days => v_location_days)
        limit v_batch
      ) doomed
      where le.id = doomed.id;
      get diagnostics v_deleted = row_count;
      v_family_location := v_family_location + v_deleted;
      exit when v_deleted < v_batch;
    end loop;

    v_family_usage := 0;
    loop
      delete from public.usage_daily u
      using (
        select id
        from public.usage_daily
        where family_id = v_family.id
          and day < (v_now - make_interval(days => v_usage_days))::date
        limit v_batch
      ) doomed
      where u.id = doomed.id;
      get diagnostics v_deleted = row_count;
      v_family_usage := v_family_usage + v_deleted;
      exit when v_deleted < v_batch;
    end loop;

    v_location := v_location + v_family_location;
    v_usage := v_usage + v_family_usage;

    if v_family_location > 0 or v_family_usage > 0 then
      v_per_family := v_per_family || jsonb_build_array(
        jsonb_build_object(
          'family_id', v_family.id,
          'location_events', v_family_location,
          'usage_daily', v_family_usage,
          'location_retention_days', v_location_days,
          'usage_retention_days', v_usage_days
        )
      );
    end if;
  end loop;

  -- Recorded so the Settings screen can show when retention last ran. Written
  -- after the audit purge, so it is never deleted by the same sweep.
  insert into public.audit_logs (
    family_id, actor_user_id, device_id, event_type, target_type, target_id, metadata
  ) values (
    null,
    null,
    null,
    'retention_sweep',
    'system',
    null,
    jsonb_build_object(
      'swept_at', v_now,
      'webrtc_signals', v_signals,
      'audit_logs', v_audit,
      'location_events', v_location,
      'usage_daily', v_usage
    )
  );

  return jsonb_build_object(
    'swept_at', v_now,
    'webrtc_signals', v_signals,
    'audit_logs', v_audit,
    'location_events', v_location,
    'usage_daily', v_usage,
    'families_examined', v_families,
    'per_family', v_per_family
  );
end;
$$;

-- Service-role only: clients must never purge family history directly.
revoke all on function public.run_retention_sweep() from public, anon, authenticated;
grant execute on function public.run_retention_sweep() to service_role;

comment on function public.run_retention_sweep() is
  'Enforced retention: webrtc_signals >7d, audit_logs >365d, per-family location/usage windows. Service-role only; call from the cron Edge Function action retention_sweep.';