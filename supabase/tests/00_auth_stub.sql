-- LOCAL-ONLY auth stub for running supabase/tests against a plain PostgreSQL 15+.
-- NEVER apply this file to a Supabase project: Supabase already provides the
-- auth schema, auth.uid(), auth.role() and the anon/authenticated/service_role
-- roles.
--
-- Apply this file BEFORE the migrations when testing without the Supabase stack.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'create role anon nologin';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'create role authenticated nologin';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'create role service_role nologin bypassrls';
  end if;
end;
$$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  email_confirmed_at timestamptz,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    'anon'
  );
$$;

grant usage on schema auth to anon, authenticated, service_role;

create schema if not exists tests;

create table if not exists tests.state (
  key text primary key,
  value text not null
);

grant usage on schema tests to anon, authenticated, service_role;
grant select on tests.state to authenticated;

-- Small assertion harness. These helpers run as the caller, so DML executed by
-- tests.expect_error() is subject to the caller's RLS and grants.
create or replace function tests.assert_true(p_condition boolean, p_label text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'ASSERTION FAILED: %', p_label;
  end if;
end;
$$;

create or replace function tests.expect_error(
  p_sql text,
  p_state text,
  p_message text,
  p_label text
)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if p_state is not null and sqlstate <> p_state then
        raise exception
          'ASSERTION FAILED (%): expected SQLSTATE %, got % (%)',
          p_label, p_state, sqlstate, sqlerrm;
      end if;
      if p_message is not null
         and position(lower(p_message) in lower(sqlerrm)) = 0 then
        raise exception
          'ASSERTION FAILED (%): expected message containing %, got %',
          p_label, p_message, sqlerrm;
      end if;
      return;
  end;
  raise exception 'ASSERTION FAILED (%): expected error, statement succeeded', p_label;
end;
$$;

create or replace function tests.put(p_key text, p_value text)
returns text
language sql
as $$
  insert into tests.state (key, value)
  values (p_key, p_value)
  on conflict (key) do update set value = excluded.value
  returning value;
$$;

create or replace function tests.get(p_key text)
returns text
language sql
stable
as $$
  select value from tests.state where key = p_key;
$$;

-- Columns of p_table that reference p_ref through a foreign key.
create or replace function tests.fk_columns(p_table regclass, p_ref regclass)
returns text[]
language sql
stable
as $$
  select coalesce(array_agg(a.attname order by a.attname), '{}'::text[])
  from pg_constraint c
  join unnest(c.conkey) as k(attnum) on true
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
  where c.contype = 'f'
    and c.conrelid = p_table
    and c.confrelid = p_ref;
$$;

grant execute on function tests.assert_true(boolean, text) to authenticated;
grant execute on function tests.expect_error(text, text, text, text) to authenticated;
