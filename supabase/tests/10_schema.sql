-- Schema, trigger, index and privilege assertions.
-- Run AFTER 00_auth_stub.sql and all three migrations.
-- These tests are local-only and have not been executed against a live
-- Supabase project.

do $$
declare
  v_tables text[] := array[
    'profiles', 'families', 'family_members', 'devices',
    'device_pairing_tokens', 'pairing_requests', 'device_policies',
    'device_commands', 'usage_daily', 'location_events', 'safe_zones',
    'safe_zone_states', 'safety_alerts', 'remote_sessions',
    'webrtc_signals', 'audit_logs', 'device_apps', 'pairing_attempts'
  ];
  v_service_only text[] := array[
    'device_pairing_tokens', 'safe_zone_states', 'pairing_attempts'
  ];
  v_missing text;
  v_count integer;
  v_names text[];
  v_bad text;
begin
  select string_agg(t, ', ') into v_missing
  from unnest(v_tables) as t
  where to_regclass('public.' || t) is null;
  perform tests.assert_true(v_missing is null, 'missing tables: ' || coalesce(v_missing, ''));

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = any (v_tables)
    and c.relrowsecurity;
  perform tests.assert_true(v_count = 18, 'RLS must be enabled on all 18 tables');

  select count(*) into v_count
  from pg_policies
  where schemaname = 'public' and tablename = any (v_service_only);
  perform tests.assert_true(v_count = 0, 'service-only tables must have no policies');

  select count(distinct tablename) into v_count
  from pg_policies
  where schemaname = 'public' and tablename <> all (v_service_only);
  perform tests.assert_true(v_count = 15, 'each client-visible table must have policies');

  select string_agg(tablename || ':' || policyname, ', ') into v_bad
  from pg_policies
  where schemaname = 'public' and roles <> array['authenticated']::name[];
  perform tests.assert_true(v_bad is null, 'policies must target authenticated only: ' || coalesce(v_bad, ''));

  -- Every user reference must point at public.profiles so PostgREST can embed
  -- display names; profiles itself cascades from auth.users.
  perform tests.assert_true(
    tests.fk_columns('public.profiles', 'auth.users') = array['id'],
    'profiles.id must reference auth.users'
  );
  perform tests.assert_true(
    tests.fk_columns('public.families', 'public.profiles') = array['owner_id'],
    'families.owner_id must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.family_members', 'public.profiles') = array['user_id'],
    'family_members.user_id must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.devices', 'public.profiles') = array['child_user_id'],
    'devices.child_user_id must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.device_pairing_tokens', 'public.profiles')
      = array['child_user_id', 'created_by', 'redeemed_by'],
    'device_pairing_tokens user columns must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.pairing_requests', 'public.profiles')
      = array['child_user_id', 'parent_user_id'],
    'pairing_requests user columns must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.device_policies', 'public.profiles') = array['created_by'],
    'device_policies.created_by must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.device_commands', 'public.profiles') = array['created_by'],
    'device_commands.created_by must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.safe_zones', 'public.profiles') = array['created_by'],
    'safe_zones.created_by must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.safety_alerts', 'public.profiles') = array['acknowledged_by'],
    'safety_alerts.acknowledged_by must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.remote_sessions', 'public.profiles')
      = array['child_user_id', 'ended_by', 'parent_user_id'],
    'remote_sessions user columns must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.webrtc_signals', 'public.profiles') = array['from_user_id'],
    'webrtc_signals.from_user_id must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.audit_logs', 'public.profiles') = array['actor_user_id'],
    'audit_logs.actor_user_id must reference profiles'
  );
  perform tests.assert_true(
    tests.fk_columns('public.pairing_attempts', 'public.profiles') = array['parent_user_id'],
    'pairing_attempts.parent_user_id must reference profiles'
  );

  select array_agg(t.tgname order by t.tgname) into v_names
  from pg_trigger t
  where not t.tgisinternal
    and t.tgname = any (array[
      'on_auth_user_created', 'profiles_before_update', 'families_before_update',
      'audit_logs_append_only', 'families_set_updated_at',
      'devices_set_updated_at', 'safe_zone_states_set_updated_at'
    ]);
  perform tests.assert_true(
    v_names = array[
      'audit_logs_append_only', 'devices_set_updated_at', 'families_before_update',
      'families_set_updated_at', 'on_auth_user_created', 'profiles_before_update',
      'safe_zone_states_set_updated_at'
    ],
    'expected triggers are missing'
  );

  select array_agg(c.relname::text order by c.relname) into v_names
  from pg_index i
  join pg_class c on c.oid = i.indexrelid
  where i.indisunique and i.indpred is not null
    and c.relname = any (array[
      'families_one_active_per_owner',
      'family_members_one_active_child_family',
      'devices_one_active_per_child'
    ]);
  perform tests.assert_true(
    v_names = array[
      'devices_one_active_per_child',
      'families_one_active_per_owner',
      'family_members_one_active_child_family'
    ],
    'partial unique indexes are missing'
  );

  perform tests.assert_true(
    (select count(*) from pg_constraint
     where contype = 'u'
       and conname in (
         'family_members_family_user_key',
         'devices_family_installation_key',
         'device_policies_device_version_key',
         'device_commands_device_idempotency_key',
         'usage_daily_device_day_package_key',
         'device_apps_device_package_key'
       )) = 6,
    'expected unique constraints are missing'
  );

  -- anon must have no table privileges at all.
  select string_agg(format('%s:%s', t, p), ', ') into v_bad
  from unnest(v_tables) as t
  cross join unnest(array['select', 'insert', 'update', 'delete']) as p
  where has_table_privilege('anon', 'public.' || t, p);
  perform tests.assert_true(v_bad is null, 'anon has table privileges: ' || coalesce(v_bad, ''));

  -- Service-only tables must not be readable or writable by authenticated.
  select string_agg(format('%s:%s', t, p), ', ') into v_bad
  from unnest(v_service_only) as t
  cross join unnest(array['select', 'insert', 'update', 'delete']) as p
  where has_table_privilege('authenticated', 'public.' || t, p);
  perform tests.assert_true(v_bad is null, 'authenticated can access service-only tables: ' || coalesce(v_bad, ''));

  perform tests.assert_true(
    has_column_privilege('authenticated', 'public.devices', 'display_name', 'select'),
    'authenticated must read safe device columns'
  );
  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.devices', 'select'),
    'authenticated must not have table-wide device SELECT'
  );
  perform tests.assert_true(
    not has_column_privilege('authenticated', 'public.devices', 'secret_hash', 'select'),
    'authenticated must never read devices.secret_hash'
  );
  perform tests.assert_true(
    not has_column_privilege('authenticated', 'public.devices', 'installation_id', 'select'),
    'authenticated must not read devices.installation_id'
  );
  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.devices', 'insert'),
    'authenticated must not insert devices'
  );
  perform tests.assert_true(
    has_column_privilege('authenticated', 'public.profiles', 'display_name', 'update'),
    'authenticated must update its own display_name'
  );
  perform tests.assert_true(
    not has_column_privilege('authenticated', 'public.profiles', 'role', 'update'),
    'authenticated must not update profile role'
  );
  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.audit_logs', 'update'),
    'audit_logs must not be updatable by authenticated'
  );
  perform tests.assert_true(
    not has_table_privilege('authenticated', 'public.audit_logs', 'delete'),
    'audit_logs must not be deletable by authenticated'
  );
  perform tests.assert_true(
    has_column_privilege('authenticated', 'public.safe_zones', 'family_id', 'insert'),
    'authenticated must insert safe_zones rows'
  );
  perform tests.assert_true(
    not has_column_privilege('authenticated', 'public.safe_zones', 'created_by', 'insert'),
    'safe_zones.created_by must not be client controlled'
  );

  perform tests.assert_true(
    has_schema_privilege('authenticated', 'private', 'usage'),
    'authenticated needs private schema usage for RLS helpers'
  );
  perform tests.assert_true(
    not has_schema_privilege('anon', 'private', 'usage'),
    'anon must not use the private schema'
  );
  perform tests.assert_true(
    has_function_privilege('authenticated', 'private.is_family_member(uuid)', 'execute'),
    'RLS helper must be executable by authenticated'
  );
  perform tests.assert_true(
    has_function_privilege('authenticated', 'private.realtime_topic_allowed(text)', 'execute'),
    'Realtime policy helper must be executable by authenticated'
  );
  perform tests.assert_true(
    not has_function_privilege('anon', 'private.realtime_topic_allowed(text)', 'execute'),
    'Realtime policy helper must not be executable by anon'
  );
  perform tests.assert_true(
    not has_function_privilege('authenticated', 'private.apply_policy_version(uuid,jsonb,uuid,text)', 'execute'),
    'private RPC must not be executable by authenticated'
  );
  perform tests.assert_true(
    not has_function_privilege('authenticated', 'public.apply_policy_version(uuid,jsonb,uuid,text)', 'execute'),
    'public RPC wrapper must not be executable by authenticated'
  );
  perform tests.assert_true(
    has_function_privilege('service_role', 'public.apply_policy_version(uuid,jsonb,uuid,text)', 'execute'),
    'service_role must execute public RPC wrappers'
  );
  perform tests.assert_true(
    has_function_privilege('service_role', 'public.create_family_with_owner(uuid,text)', 'execute'),
    'service_role must execute create_family_with_owner'
  );
  perform tests.assert_true(
    not has_function_privilege('anon', 'public.poll_device_commands(uuid,integer)', 'execute'),
    'anon must not execute service RPCs'
  );
end;
$$;
