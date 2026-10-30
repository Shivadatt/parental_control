-- Retention sweep tests (migration 20261030000300_retention_sweep.sql).
--
-- Run AFTER 20_fixtures.sql and every migration, in the same `psql -f` chain as
-- the other files. Self-contained: own accounts, family, device and session
-- (a4../b4../c4../d4../e4../f4.. UUIDs), so no fixture owned by another test
-- file is mutated. Written to be runnable; NOT EXECUTED in Phase 1 (no Supabase
-- CLI and no hosted database).
--
-- Covers:
--   1. SECURITY DEFINER, pinned search_path, service-role-only execute.
--   2. 7-day webrtc_signals purge, 365-day audit_logs purge.
--   3. Per-family location/usage windows from families.settings.
--   4. Idempotence and the retention_sweep audit row read by `account`.
do $$
declare
  v_parent uuid := 'a4000000-0000-4000-8000-0000000000a1';
  v_child uuid := 'b4000000-0000-4000-8000-0000000000c1';
  v_family uuid := 'c4000000-0000-4000-8000-000000000001';
  v_device uuid := 'd4000000-0000-4000-8000-000000000001';
  v_session uuid := 'e4000000-0000-4000-8000-000000000001';
  v_old_location uuid := 'f4000000-0000-4000-8000-000000000001';
  v_new_location uuid := 'f4000000-0000-4000-8000-000000000002';
  v_old_usage uuid := 'f4000000-0000-4000-8000-000000000003';
  v_new_usage uuid := 'f4000000-0000-4000-8000-000000000004';
  v_old_signal uuid := 'f4000000-0000-4000-8000-000000000005';
  v_new_signal uuid := 'f4000000-0000-4000-8000-000000000006';
  v_old_audit uuid := 'f4000000-0000-4000-8000-000000000007';
  v_new_audit uuid := 'f4000000-0000-4000-8000-000000000008';
  v_result jsonb;
  v_second jsonb;
  v_count integer;
begin
  insert into auth.users (id, email, email_confirmed_at) values
    (v_parent, 'retention-parent@example.test', now()),
    (v_child, 'retention-child@example.test', now());

  update public.profiles set role = 'parent' where id = v_parent;
  update public.profiles set role = 'child' where id = v_child;

  insert into public.families (id, name, owner_id, settings)
  values (
    v_family,
    'Retention Family',
    v_parent,
    '{"location_retention_days":30,"usage_retention_days":90}'::jsonb
  );

  insert into public.family_members (family_id, user_id, role, status) values
    (v_family, v_parent, 'parent', 'active'),
    (v_family, v_child, 'child', 'active');

  insert into public.devices (
    id, family_id, child_user_id, installation_id, display_name, status
  ) values (
    v_device, v_family, v_child, 'retention-device', 'Retention Phone', 'active'
  );

  -- -----------------------------------------------------------------------
  -- 0. Contract: SECURITY DEFINER, pinned search_path, service-role only.
  -- -----------------------------------------------------------------------
  perform tests.assert_true(
    (select p.prosecdef
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'run_retention_sweep'),
    'run_retention_sweep is SECURITY DEFINER'
  );
  perform tests.assert_true(
    (select coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'run_retention_sweep'),
    'run_retention_sweep pins search_path'
  );
  perform tests.assert_true(
    has_function_privilege('service_role', 'public.run_retention_sweep()', 'execute'),
    'service_role may execute the sweep'
  );
  perform tests.assert_true(
    not has_function_privilege('anon', 'public.run_retention_sweep()', 'execute'),
    'anon may not execute the sweep'
  );
  perform tests.assert_true(
    not has_function_privilege('authenticated', 'public.run_retention_sweep()', 'execute'),
    'authenticated may not execute the sweep'
  );

  -- -----------------------------------------------------------------------
  -- Fixtures: location (40d / 2d), usage (120d / 5d), signals (8d / 1d) and
  -- audit rows (400d / today) for the retention family.
  -- -----------------------------------------------------------------------
  insert into public.remote_sessions (
    id, family_id, device_id, parent_user_id, child_user_id, kind,
    status, expires_at
  ) values (
    v_session, v_family, v_device, v_parent, v_child, 'audio',
    'ended', now() - interval '1 day'
  );

  insert into public.location_events (
    id, device_id, family_id, lat, lng, accuracy_m, recorded_at
  ) values
    (v_old_location, v_device, v_family, 51.5, -0.12, 10, now() - interval '40 days'),
    (v_new_location, v_device, v_family, 51.5, -0.12, 10, now() - interval '2 days');

  insert into public.usage_daily (
    id, device_id, family_id, day, package_name, total_ms
  ) values
    (v_old_usage, v_device, v_family, (now() - interval '120 days')::date, 'com.example.old', 1000),
    (v_new_usage, v_device, v_family, (now() - interval '5 days')::date, 'com.example.new', 1000);

  insert into public.webrtc_signals (
    id, session_id, from_user_id, kind, payload, created_at
  ) values
    (v_old_signal, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '8 days'),
    (v_new_signal, v_session, v_parent, 'ice', '{}'::jsonb, now() - interval '1 day');

  insert into public.audit_logs (
    id, family_id, actor_user_id, event_type, metadata, created_at
  ) values
    (v_old_audit, v_family, v_parent, 'test_old_audit', '{}'::jsonb, now() - interval '400 days'),
    (v_new_audit, v_family, v_parent, 'test_new_audit', '{}'::jsonb, now());

  -- -----------------------------------------------------------------------
  -- 1. First sweep deletes outside every window and keeps the rest.
  -- -----------------------------------------------------------------------
  select public.run_retention_sweep() into v_result;
  perform tests.assert_true(v_result is not null, 'sweep returns jsonb');

  perform tests.assert_true(
    not exists (select 1 from public.location_events where id = v_old_location),
    'location older than 30 days is deleted'
  );
  perform tests.assert_true(
    exists (select 1 from public.location_events where id = v_new_location),
    'location inside 30 days is kept'
  );
  perform tests.assert_true(
    not exists (select 1 from public.usage_daily where id = v_old_usage),
    'usage older than 90 days is deleted'
  );
  perform tests.assert_true(
    exists (select 1 from public.usage_daily where id = v_new_usage),
    'usage inside 90 days is kept'
  );
  perform tests.assert_true(
    not exists (select 1 from public.webrtc_signals where id = v_old_signal),
    'signaling older than 7 days is deleted'
  );
  perform tests.assert_true(
    exists (select 1 from public.webrtc_signals where id = v_new_signal),
    'signaling inside 7 days is kept'
  );
  perform tests.assert_true(
    not exists (select 1 from public.audit_logs where id = v_old_audit),
    'audit older than 365 days is deleted'
  );
  perform tests.assert_true(
    exists (select 1 from public.audit_logs where id = v_new_audit),
    'recent audit is kept'
  );
  perform tests.assert_true(
    (v_result ->> 'webrtc_signals')::integer >= 1,
    'sweep reports signaling deletes'
  );
  perform tests.assert_true(
    (v_result ->> 'audit_logs')::integer >= 1,
    'sweep reports audit deletes'
  );
  perform tests.assert_true(
    (v_result ->> 'location_events')::integer >= 1,
    'sweep reports location deletes'
  );
  perform tests.assert_true(
    (v_result ->> 'usage_daily')::integer >= 1,
    'sweep reports usage deletes'
  );

  -- -----------------------------------------------------------------------
  -- 2. Last-sweep marker used by the `account` Edge Function.
  -- -----------------------------------------------------------------------
  select count(*) into v_count
  from public.audit_logs
  where event_type = 'retention_sweep'
    and (metadata ->> 'swept_at') is not null;
  perform tests.assert_true(v_count >= 1, 'sweep records a retention_sweep audit row');

  -- -----------------------------------------------------------------------
  -- 3. Idempotence: a second run must not fail or delete recent rows.
  -- -----------------------------------------------------------------------
  select public.run_retention_sweep() into v_second;
  perform tests.assert_true(v_second is not null, 'second sweep returns jsonb');
  perform tests.assert_true(
    exists (select 1 from public.location_events where id = v_new_location),
    'second sweep keeps recent location'
  );
  perform tests.assert_true(
    exists (select 1 from public.usage_daily where id = v_new_usage),
    'second sweep keeps recent usage'
  );
  perform tests.assert_true(
    exists (select 1 from public.webrtc_signals where id = v_new_signal),
    'second sweep keeps recent signaling'
  );
  perform tests.assert_true(
    (select count(*)
     from public.audit_logs
     where event_type = 'retention_sweep') >= 2,
    'each sweep appends its own marker'
  );
end;
$$;