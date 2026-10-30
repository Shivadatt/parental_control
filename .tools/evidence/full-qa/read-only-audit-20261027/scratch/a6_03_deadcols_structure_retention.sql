-- A6 scratch tasks 3, 4, 6: dead columns, structural blocker, retention.
\pset footer off

\echo '================ TASK 3: are device_pairing_tokens.attempts / .max_attempts ever written? ================'
\echo '-- (a) every compiled function whose body mentions device_pairing_tokens, and whether that'
\echo '--     body also mentions the attempts columns at all:'
select n.nspname || '.' || p.proname as fn,
       p.prosrc ~* 'device_pairing_tokens' as touches_tokens,
       p.prosrc ~* 'max_attempts' as mentions_max_attempts,
       p.prosrc ~* '(^|[^.a-z_])attempts' as mentions_attempts
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prosrc ~* 'device_pairing_tokens'
order by 1;

\echo '-- (b) any function anywhere in the DB that mentions max_attempts:'
select coalesce(string_agg(n.nspname || '.' || p.proname, ', '), 'NONE') as functions_mentioning_max_attempts
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prosrc ~* 'max_attempts';

\echo '-- (c) triggers / rules on the token table:'
select tgname from pg_trigger where tgrelid = 'public.device_pairing_tokens'::regclass and not tgisinternal;
select rulename from pg_rules where schemaname='public' and tablename='device_pairing_tokens';

\echo '-- (d) empirical: after the FULL suite (fixtures + 40_functions + 45_device_recovery) plus'
\echo '--     this repro''s 16 token writes, every row is still on the DDL defaults:'
select attempts, max_attempts, count(*)
from public.device_pairing_tokens group by 1,2 order by 3 desc;

\echo '-- (e) the columns exist and are readable, that is all:'
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='device_pairing_tokens'
  and column_name in ('attempts','max_attempts');

\echo '================ TASK 4: pairing_requests.token_id NOT NULL UNIQUE (live catalog) ================'
\echo '-- re-runnable cleanup of this script''s own probe rows only:'
delete from public.pairing_requests
where parent_user_id::text like 'b_000000-0000-4000-8000-000000000000';
delete from public.device_pairing_tokens
where code_hash in (md5('UNIQUE-PROBE') || md5('UNIQUE-PROBE-2'),
                   md5('ANCIENT') || md5('ANCIENT-2'));
delete from public.pairing_attempts
where code_hash = md5('ANCIENT') || md5('ANCIENT-2');

select attnotnull as token_id_not_null
from pg_attribute where attrelid='public.pairing_requests'::regclass and attname='token_id';
select conname, contype, pg_get_constraintdef(oid) as def
from pg_constraint where conrelid='public.pairing_requests'::regclass order by 2,1;

\echo '-- empirical 1: a pairing request with NO token (the invite-style link) is impossible:'
do $$
begin
  begin
    insert into public.pairing_requests (token_id, family_id, parent_user_id, child_user_id, expires_at)
    values (null,
            (select id from public.families limit 1),
            'b1000000-0000-4000-8000-000000000000',
            'a1000000-0000-4000-8000-000000000000',
            now() + interval '10 minutes');
    raise exception 'ASSERTION FAILED: request without a token was accepted';
  exception when not_null_violation then
    raise notice 'CONFIRMED: token_id NOT NULL rejects an invite-style request (SQLSTATE %)', sqlstate;
  end;
end $$;

\echo '-- empirical 2: two requests for the same token are impossible (token_id UNIQUE):'
do $$
declare v_fam uuid; v_tok uuid;
begin
  select id into v_fam from public.families limit 1;
  insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status)
  values ('a1000000-0000-4000-8000-000000000000', md5('UNIQUE-PROBE') || md5('UNIQUE-PROBE-2'),
          now() + interval '10 minutes', 'active')
  returning id into v_tok;

  insert into public.pairing_requests (token_id, family_id, parent_user_id, child_user_id, expires_at)
  values (v_tok, v_fam, 'b1000000-0000-4000-8000-000000000000',
          'a1000000-0000-4000-8000-000000000000', now() + interval '10 minutes');
  raise notice 'OK: exactly one request per redeemed/active token (token_id=%) inserted', v_tok;

  begin
    insert into public.pairing_requests (token_id, family_id, parent_user_id, child_user_id, expires_at)
    values (v_tok, v_fam, 'b2000000-0000-4000-8000-000000000000',
            'a1000000-0000-4000-8000-000000000000', now() + interval '10 minutes');
    raise exception 'ASSERTION FAILED: duplicate token_id was accepted';
  exception when unique_violation then
    raise notice 'CONFIRMED: token_id UNIQUE rejects a second request (SQLSTATE %)', sqlstate;
  end;
end $$;

\echo '-- empirical 3: how many requests exist that are NOT backed by a token? (must be 0)'
select count(*) as requests_without_token
from public.pairing_requests r
left join public.device_pairing_tokens t on t.id = r.token_id
where t.id is null;

\echo '================ TASK 6: purge / retention for device_pairing_tokens and pairing_attempts ================'
\echo '-- (a) complete inventory of every DELETE statement compiled into the local DB functions:'
select n.nspname || '.' || p.proname as fn, m.target
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
cross join lateral (
  select trim((regexp_matches(p.prosrc, '(?is)delete\s+from\s+([a-zA-Z0-9_." ]+)', 'g'))[1]) as target
) m
where p.prosrc ilike '%delete from%' and n.nspname in ('public','private')
group by 1,2 order by 1,2;

\echo '-- (b) do ANY functions/RPCs delete from the two tables? (search bodies directly)'
select coalesce(string_agg(n.nspname || '.' || p.proname, ', '), 'NONE') as writers_deleting_tokens
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prosrc ilike '%delete from public.device_pairing_tokens%'
   or p.prosrc ilike '%delete from  public.device_pairing_tokens%';

select coalesce(string_agg(n.nspname || '.' || p.proname, ', '), 'NONE') as writers_deleting_attempts
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prosrc ilike '%delete from public.pairing_attempts%';

\echo '-- (c) pg_cron availability locally + the only two scheduled jobs the migration registers:'
select count(*) as pg_cron_installed from pg_extension where extname = 'pg_cron';
select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and proname in ('expire_stale_sessions','detect_offline_devices');

\echo '-- (d) empirical: count rows, run BOTH maintenance RPCs, count again.'
select 'device_pairing_tokens' as tbl, count(*) as before_cnt from public.device_pairing_tokens
union all select 'pairing_attempts', count(*) from public.pairing_attempts
union all select '  of which expired tokens', count(*) from public.device_pairing_tokens where expires_at <= now();

\echo '-- seed one ancient token and one ancient attempt (age 400 days) to test ageing out:'
insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, created_at)
values ('a1000000-0000-4000-8000-000000000000', md5('ANCIENT') || md5('ANCIENT-2'),
        now() - interval '400 days', 'active', now() - interval '400 days');
insert into public.pairing_attempts (parent_user_id, code_hash, success, attempted_at)
values ('b1000000-0000-4000-8000-000000000000', md5('ANCIENT') || md5('ANCIENT-2'), false,
        now() - interval '400 days');

select public.expire_stale_sessions() as expired_sessions,
       public.detect_offline_devices() as offline_alerts;

select 'device_pairing_tokens' as tbl, count(*) as after_cnt from public.device_pairing_tokens
union all select 'pairing_attempts', count(*) from public.pairing_attempts
union all select '  ancient token still present', count(*) from public.device_pairing_tokens
     where created_at < now() - interval '399 days'
union all select '  ancient attempt still present', count(*) from public.pairing_attempts
     where attempted_at < now() - interval '399 days';

\echo '-- (e) the ancient token is STILL status=active 400 days later (nothing ages it out):'
select id, status, expires_at, created_at from public.device_pairing_tokens
where created_at < now() - interval '399 days';

\echo '-- (f) but it no longer counts against the 24h window; it is never deleted:'
select count(*) as in_24h_window from public.device_pairing_tokens
where child_user_id = 'a1000000-0000-4000-8000-000000000000'
  and created_at >= now() - interval '24 hours';
select count(*) as total_rows_for_that_child from public.device_pairing_tokens
where child_user_id = 'a1000000-0000-4000-8000-000000000000';
