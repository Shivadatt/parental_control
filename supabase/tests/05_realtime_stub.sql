-- LOCAL-ONLY stand-in for Supabase's realtime schema.
-- NEVER apply this file to a Supabase project: the hosted project already has
-- realtime.messages, realtime.topic() and the Realtime server.
--
-- It exists so the RLS migration's realtime.messages policy is actually created
-- and can be exercised on plain PostgreSQL. This validates the policy DDL and
-- its topic gate; it does not emulate the Realtime server or prove hosted
-- subscription behavior.
create schema if not exists realtime;

create table if not exists realtime.messages (
  id bigserial primary key,
  inserted_at timestamptz not null default now(),
  topic text not null,
  extension text not null,
  payload jsonb,
  event text,
  private boolean not null default true
);

alter table realtime.messages enable row level security;

create or replace function realtime.topic()
returns text
language sql
stable
as $$
  select nullif(current_setting('realtime.topic', true), '');
$$;

grant usage on schema realtime to authenticated;
grant select on realtime.messages to authenticated;
