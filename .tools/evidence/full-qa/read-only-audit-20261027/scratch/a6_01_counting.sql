-- A6 scratch: prove the device_pairing_tokens status CHECK constraint from the
-- LIVE catalog (task 2), then the counting-bug comparison (task 1).
\pset footer off
\echo '================ TASK 2: status CHECK constraint as created in the local catalog ================'
select conname, pg_get_constraintdef(oid) as def
from pg_constraint
where conrelid = 'public.device_pairing_tokens'::regclass
  and conname = 'device_pairing_tokens_status_check';

\echo '-- which status literals the live status constraint accepts:'
select pg_get_constraintdef(oid) ~ '''active''' as has_active,
       pg_get_constraintdef(oid) ~ '''redeemed''' as has_redeemed,
       pg_get_constraintdef(oid) ~ '''revoked''' as has_revoked,
       pg_get_constraintdef(oid) ~ '''expired''' as has_expired,
       pg_get_constraintdef(oid) ~ '''consumed''' as has_consumed
from pg_constraint
where conrelid = 'public.device_pairing_tokens'::regclass
  and conname = 'device_pairing_tokens_status_check';

\echo '-- statuses actually stored in the table right now (fixtures + suite):'
select status, count(*) from public.device_pairing_tokens group by status order by 2 desc;

\echo '================ scratch children for the counting scenarios ================'
\echo '(the on_auth_user_created trigger already makes the profile row, so only role is set)'
insert into auth.users (id, email, email_confirmed_at)
select ('a' || g || '000000-0000-4000-8000-000000000000')::uuid,
       'scratch' || g || '@example.invalid', now()
from generate_series(1, 5) g
on conflict (id) do nothing;

update public.profiles
set role = 'child', display_name = 'Scratch Child ' || right(id::text, 1)
where id::text like 'a_000000-0000-4000-8000-000000000000';

select id, role, display_name from public.profiles
where id::text like 'a_000000-0000-4000-8000-000000000000' order by 1;

\echo '-- empirical: inserting status = ''consumed'' must fail with 23514:'
do $$
begin
  begin
    insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status)
    values ('a1000000-0000-4000-8000-000000000000',
            md5('consumed-probe') || md5('consumed-probe-2'),
            now() + interval '10 minutes', 'consumed');
    raise exception 'ASSERTION FAILED: status=consumed was accepted';
  exception when check_violation then
    raise notice 'CONFIRMED: rejected with SQLSTATE % (%)', sqlstate, sqlerrm;
  end;
end $$;

\echo '================ TASK 1: the counting bug ================'
\echo '-- clean only the scratch-child rows so this script is re-runnable:'
delete from public.device_pairing_tokens where child_user_id::text like 'a_%000000-0000-4000-8000-000000000000';

\echo '-- Scenario A: replay the REAL app sequence = 5 code creations by one child.'
\echo '   pairing/index.ts:227-254 -> insert active, then revoke every previous active.'
do $$
declare v_child uuid := 'a1000000-0000-4000-8000-000000000000';
        v_id uuid;
begin
  for i in 1 .. 5 loop
    insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, created_by)
    values (v_child, md5('A-' || i) || md5('A-salt-' || i),
            now() + interval '10 minutes', 'active', v_child)
    returning id into v_id;

    update public.device_pairing_tokens
    set status = 'revoked'
    where child_user_id = v_child and status = 'active' and id <> v_id;
  end loop;
end $$;

\echo '-- Scenario B: same 5 rows for child a2..., then unlink_member-style bulk revoke'
\echo '   (functions.sql:398-401 sets status=revoked for every active token of the child).'
do $$
declare v_child uuid := 'a2000000-0000-4000-8000-000000000000';
        v_id uuid;
begin
  for i in 1 .. 5 loop
    insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, created_by)
    values (v_child, md5('B-' || i) || md5('B-salt-' || i),
            now() + interval '10 minutes', 'active', v_child)
    returning id into v_id;
    update public.device_pairing_tokens
    set status = 'revoked'
    where child_user_id = v_child and status = 'active' and id <> v_id;
  end loop;
  -- the unlink/removal path
  update public.device_pairing_tokens
  set status = 'revoked'
  where child_user_id = v_child and status = 'active';
end $$;

\echo '-- Scenario C: 1 redeemed + 2 expired + 2 revoked (all past their TTL), child a3...'
insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, redeemed_at, created_by)
values
  ('a3000000-0000-4000-8000-000000000000', md5('C-1') || md5('C-s1'), now() - interval '1 hour', 'redeemed', now() - interval '2 hours', 'a3000000-0000-4000-8000-000000000000'),
  ('a3000000-0000-4000-8000-000000000000', md5('C-2') || md5('C-s2'), now() - interval '2 hours', 'expired', null, 'a3000000-0000-4000-8000-000000000000'),
  ('a3000000-0000-4000-8000-000000000000', md5('C-3') || md5('C-s3'), now() - interval '3 hours', 'expired', null, 'a3000000-0000-4000-8000-000000000000'),
  ('a3000000-0000-4000-8000-000000000000', md5('C-4') || md5('C-s4'), now() - interval '4 hours', 'revoked', null, 'a3000000-0000-4000-8000-000000000000'),
  ('a3000000-0000-4000-8000-000000000000', md5('C-5') || md5('C-s5'), now() - interval '5 hours', 'revoked', null, 'a3000000-0000-4000-8000-000000000000');

\echo '-- Scenario D: 5 rows still status=active but past expires_at (nobody redeemed'
\echo '   them and no job flips them), child a4...'
insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, created_by)
select 'a4000000-0000-4000-8000-000000000000',
       md5('D-' || g) || md5('D-salt-' || g),
       now() - make_interval(hours => g), 'active',
       'a4000000-0000-4000-8000-000000000000'
from generate_series(1, 5) g;

\echo '-- Scenario E (control): a normal child with exactly 1 live active token, child a5...'
insert into public.device_pairing_tokens (child_user_id, code_hash, expires_at, status, created_by)
values ('a5000000-0000-4000-8000-000000000000', md5('E-1') || md5('E-s1'),
        now() + interval '10 minutes', 'active', 'a5000000-0000-4000-8000-000000000000');

\echo '---- per-scenario row mix as actually stored ----'
select ('a' || s || '000000-0000-4000-8000-000000000000')::uuid as child,
       string_agg(status || case when expires_at > now() then '(live)' else '(past-ttl)' end, ', ' order by status) as stored_rows
from generate_series(1, 5) s
join public.device_pairing_tokens t on t.child_user_id = ('a' || s || '000000-0000-4000-8000-000000000000')::uuid
group by 1 order by 1;

\echo '---- THE TWO COUNT EXPRESSIONS (rate_limit.ts:70-88 current vs proposed) ----'
with scenarios(label, child) as (
  values
    ('A: 4 revoked + 1 active (5 real creates)', 'a1000000-0000-4000-8000-000000000000'::uuid),
    ('B: 5 revoked (unlinked/relinked child)',   'a2000000-0000-4000-8000-000000000000'::uuid),
    ('C: 1 redeemed + 2 expired + 2 revoked',    'a3000000-0000-4000-8000-000000000000'::uuid),
    ('D: 5 active rows past TTL (stale)',        'a4000000-0000-4000-8000-000000000000'::uuid),
    ('E: control, 1 live active token',          'a5000000-0000-4000-8000-000000000000'::uuid)
)
select sc.label,
  (select count(*)
     from public.device_pairing_tokens t
    where t.child_user_id = sc.child
      and t.created_at >= now() - interval '24 hours') as current_count,
  (select count(*)
     from public.device_pairing_tokens t
    where t.child_user_id = sc.child
      and t.created_at >= now() - interval '24 hours'
      and t.status = 'active'
      and t.expires_at > now()) as proposed_count,
  case when (select count(*)
     from public.device_pairing_tokens t
    where t.child_user_id = sc.child
      and t.created_at >= now() - interval '24 hours') >= 5
       then 'BLOCKED (429)' else 'allowed' end as current_verdict,
  case when (select count(*)
     from public.device_pairing_tokens t
    where t.child_user_id = sc.child
      and t.created_at >= now() - interval '24 hours'
      and t.status = 'active'
      and t.expires_at > now()) >= 5
       then 'BLOCKED (429)' else 'allowed' end as proposed_verdict
from scenarios sc order by 1;
