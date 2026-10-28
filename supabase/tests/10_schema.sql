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
  perform tests.assert_true(
    has_table_privilege(
      'service_role', 'public.profiles', 'select,insert,update,delete'
    ),
    'service_role must write through PostgREST'
  );
  perform tests.assert_true(
    has_table_privilege(
      'service_role', 'public.device_pairing_tokens', 'select,insert,update,delete'
    ),
    'service_role must access service-only tables'
  );
  perform tests.assert_true(
    not has_table_privilege('anon', 'public.profiles', 'select'),
    'anon must not read profiles'
  );
  perform tests.assert_true(
    not has_column_privilege('authenticated', 'public.profiles', 'role', 'update'),
    'authenticated must not update profile roles'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permanent Child ID (migration 20260101000500_child_contact_ids.sql)
-- ---------------------------------------------------------------------------
do $$
declare
  v_bad text;
  v_default text;
  v_temp_user uuid := '9a0c0de0-0000-4000-8000-0000000000c1';
begin
  perform tests.assert_true(
    to_regclass('public.child_contact_ids') is not null,
    'child_contact_ids table is missing'
  );

  perform tests.assert_true(
    (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'child_user_id') = 'uuid'
    and (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'child_user_id') = 'NO',
    'child_contact_ids.child_user_id must be a NOT NULL uuid'
  );
  perform tests.assert_true(
    (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'contact_id') = 'text'
    and (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'contact_id') = 'NO',
    'child_contact_ids.contact_id must be a NOT NULL text column'
  );
  perform tests.assert_true(
    (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'created_at') = 'timestamp with time zone'
    and (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'created_at') = 'NO',
    'child_contact_ids.created_at must be a NOT NULL timestamptz'
  );
  perform tests.assert_true(
    (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'rotated_at') = 'timestamp with time zone'
    and (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'child_contact_ids'
        and column_name = 'rotated_at') = 'YES',
    'child_contact_ids.rotated_at must be a nullable timestamptz'
  );

  perform tests.assert_true(
    exists (
      select 1 from pg_constraint c
      where c.conrelid = 'public.child_contact_ids'::regclass
        and c.contype = 'p'
        and c.conkey = array[
          (select a.attnum from pg_attribute a
            where a.attrelid = 'public.child_contact_ids'::regclass
              and a.attname = 'child_user_id')
        ]
    ),
    'child_contact_ids.child_user_id must be the primary key'
  );
  perform tests.assert_true(
    exists (
      select 1 from pg_constraint c
      where c.conrelid = 'public.child_contact_ids'::regclass
        and c.contype = 'u'
        and c.conkey = array[
          (select a.attnum from pg_attribute a
            where a.attrelid = 'public.child_contact_ids'::regclass
              and a.attname = 'contact_id')
        ]
    ),
    'child_contact_ids.contact_id must be unique'
  );

  perform tests.assert_true(
    (select c.relrowsecurity from pg_class c
      where c.oid = 'public.child_contact_ids'::regclass),
    'RLS must be enabled on child_contact_ids'
  );

  select string_agg(format('anon:%s', p), ', ') into v_bad
  from unnest(array['select', 'insert', 'update', 'delete']) as p
  where has_table_privilege('anon', 'public.child_contact_ids', p);
  perform tests.assert_true(
    v_bad is null,
    'anon must have no child_contact_ids privileges: ' || coalesce(v_bad, '')
  );

  select string_agg(format('authenticated:%s', p), ', ') into v_bad
  from unnest(array['select', 'insert', 'update', 'delete']) as p
  where has_table_privilege('authenticated', 'public.child_contact_ids', p);
  perform tests.assert_true(
    v_bad is null,
    'authenticated must have no child_contact_ids privileges: '
      || coalesce(v_bad, '')
  );

  perform tests.assert_true(
    has_table_privilege(
      'service_role', 'public.child_contact_ids', 'select,insert,update,delete'
    ),
    'service_role must access child_contact_ids'
  );

  -- The check constraint is behavioural: create a throw-away profile so the FK
  -- does not mask the check violation, then clean it up below.
  insert into auth.users (id, email, email_confirmed_at)
  values (v_temp_user, 'schema-child-id@example.test', now());

  perform tests.expect_error(
    format(
      'insert into public.child_contact_ids (child_user_id, contact_id) '
        || 'values (%L::uuid, %L)',
      v_temp_user, 'PC12345678'
    ),
    '23514', 'check constraint',
    'child_contact_ids must reject ambiguous character 0/1'
  );
  perform tests.expect_error(
    format(
      'insert into public.child_contact_ids (child_user_id, contact_id) '
        || 'values (%L::uuid, %L)',
      v_temp_user, 'XX7K4M2QRX'
    ),
    '23514', 'check constraint',
    'child_contact_ids must reject a wrong prefix'
  );

  perform tests.assert_true(
    (select count(*) from public.child_contact_ids
      where child_user_id = v_temp_user) = 0,
    'rejected Child IDs must not be stored'
  );

  insert into public.child_contact_ids (child_user_id, contact_id)
  values (v_temp_user, 'PC7K4M2QRX');
  perform tests.assert_true(
    (select count(*) from public.child_contact_ids
      where child_user_id = v_temp_user
        and contact_id = 'PC7K4M2QRX') = 1,
    'the check constraint must accept a canonical Child ID'
  );

  -- device_pairing_tokens.purpose: NOT NULL, defaults to 'code', and only the
  -- two documented values pass its check constraint.
  perform tests.assert_true(
    exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'device_pairing_tokens'
        and column_name = 'purpose'
    ),
    'device_pairing_tokens.purpose column is missing'
  );
  perform tests.assert_true(
    (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'device_pairing_tokens'
        and column_name = 'purpose') = 'NO',
    'device_pairing_tokens.purpose must be NOT NULL'
  );
  select column_default into v_default
  from information_schema.columns
  where table_schema = 'public' and table_name = 'device_pairing_tokens'
    and column_name = 'purpose';
  perform tests.assert_true(
    v_default = '''code''::text',
    'device_pairing_tokens.purpose must default to ''code'', got '
      || coalesce(v_default, '<none>')
  );

  insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at)
  values (v_temp_user, repeat('4', 64), now() + interval '5 minutes');
  perform tests.assert_true(
    (select purpose from public.device_pairing_tokens
      where code_hash = repeat('4', 64)) = 'code',
    'device_pairing_tokens.purpose must default to code'
  );

  insert into public.device_pairing_tokens
    (child_user_id, code_hash, expires_at, purpose)
  values (v_temp_user, repeat('5', 64), now() + interval '5 minutes', 'invite');
  perform tests.assert_true(
    (select purpose from public.device_pairing_tokens
      where code_hash = repeat('5', 64)) = 'invite',
    'device_pairing_tokens.purpose must accept invite'
  );

  perform tests.expect_error(
    format(
      'insert into public.device_pairing_tokens '
        || '(child_user_id, code_hash, expires_at, purpose) '
        || 'values (%L::uuid, %L, now() + interval ''5 minutes'', %L)',
      v_temp_user, repeat('6', 64), 'legacy'
    ),
    '23514', 'check constraint',
    'device_pairing_tokens.purpose must reject values other than code/invite'
  );

  -- Deleting the throw-away account cascades through profiles to every row
  -- created above, leaving later fixtures untouched.
  delete from auth.users where id = v_temp_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic pairing-request RPCs (migration 20260101000600_atomic_pairing_invite.sql)
-- Both the private implementation and the public PostgREST wrapper must be
-- SECURITY DEFINER with a pinned search_path, and only service_role may
-- execute them (BUG-033).
-- ---------------------------------------------------------------------------
do $$
declare
  v_functions text[] := array[
    'public.create_pairing_invite(uuid,uuid,uuid,text,timestamptz)',
    'public.create_pairing_request(uuid,uuid,uuid,uuid,timestamptz)',
    'private.create_pairing_invite(uuid,uuid,uuid,text,timestamptz)',
    'private.create_pairing_request(uuid,uuid,uuid,uuid,timestamptz)'
  ];
  v_fn text;
  v_oid oid;
  v_prosecdef boolean;
  v_proconfig text[];
begin
  foreach v_fn in array v_functions loop
    v_oid := to_regprocedure(v_fn);
    perform tests.assert_true(
      v_oid is not null,
      'pairing RPC is missing: ' || v_fn
    );

    select p.prosecdef, p.proconfig into v_prosecdef, v_proconfig
    from pg_proc p where p.oid = v_oid;
    perform tests.assert_true(
      coalesce(v_prosecdef, false),
      'pairing RPC must be SECURITY DEFINER: ' || v_fn
    );
    perform tests.assert_true(
      exists (
        select 1 from unnest(coalesce(v_proconfig, '{}'::text[])) as c
        where c like 'search_path=%'
      ),
      'pairing RPC must pin search_path: ' || v_fn
    );

    perform tests.assert_true(
      not has_function_privilege('anon', v_fn, 'execute'),
      'anon must not execute pairing RPC: ' || v_fn
    );
    perform tests.assert_true(
      not has_function_privilege('authenticated', v_fn, 'execute'),
      'authenticated must not execute pairing RPC: ' || v_fn
    );
    perform tests.assert_true(
      has_function_privilege('service_role', v_fn, 'execute'),
      'service_role must execute pairing RPC: ' || v_fn
    );
  end loop;
end;
$$;
