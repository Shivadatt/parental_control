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
-- Batched (10 000 rows per statement) so a large backlog does not hold one long
-- lock. Safe to run repeatedly: an empty second run deletes zero rows. No table,
-- column, constraint or policy changes. The only write outside the four tables
-- is one append-only `audit_logs` summary row (`event_type='retention_sweep'`),
-- which the `account` Edge Function reads as "last sweep".
--
-- Rollback:
--   drop function if exists public.run_retention_sweep();
-- Rows already deleted stay deleted; that is the point of retention.

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