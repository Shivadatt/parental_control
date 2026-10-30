-- A6 scratch task 5: pairing_attempts rate limits bill SUCCESSFUL links and
-- ignore the `success` column, exactly as supabase/functions/_shared/rate_limit.ts:20-38.
\pset footer off

\echo '================ scratch parents ================'
insert into auth.users (id, email, email_confirmed_at)
select ('b' || g || '000000-0000-4000-8000-000000000000')::uuid,
       'scratchparent' || g || '@example.invalid', now()
from generate_series(1, 3) g
on conflict (id) do nothing;
update public.profiles set role = 'parent', display_name = 'Scratch Parent ' || right(id::text, 1)
where id::text like 'b_000000-0000-4000-8000-000000000000';

delete from public.pairing_attempts
where parent_user_id::text like 'b_000000-0000-4000-8000-000000000000';

\echo '================ scenario P: one parent links 5 DIFFERENT children, all successful ================'
\echo 'recordPairingAttempt(db, parent, codeHash, true) is what pairing/index.ts:330/353/401 does on a'
\echo 'successful redeem, so every successful link writes one row.'
insert into public.pairing_attempts (parent_user_id, code_hash, success, attempted_at)
select 'b1000000-0000-4000-8000-000000000000',
       md5('OK-' || g) || md5('OK-salt-' || g),
       true,
       now() - make_interval(mins => g)          -- all inside the 10-minute window
from generate_series(1, 5) g;

\echo '---- the two queries rate_limit.ts actually issues (10-minute window) ----'
select
  (select count(*) from public.pairing_attempts a
     where a.parent_user_id = 'b1000000-0000-4000-8000-000000000000'
       and a.attempted_at >= now() - interval '10 minutes') as per_parent_count,
  (select count(*) from public.pairing_attempts a
     where a.parent_user_id = 'b1000000-0000-4000-8000-000000000000'
       and a.attempted_at >= now() - interval '10 minutes'
       and a.success) as if_only_success_counted,
  (select count(*) from public.pairing_attempts a
     where a.parent_user_id = 'b1000000-0000-4000-8000-000000000000'
       and a.attempted_at >= now() - interval '10 minutes'
       and not a.success) as if_only_failures_counted;

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.pairing_attempts a
   where a.parent_user_id = 'b1000000-0000-4000-8000-000000000000'
     and a.attempted_at >= now() - interval '10 minutes';
  if v_count >= 5 then
    raise notice 'VERDICT per-parent: count=% >= MAX_ATTEMPTS_PER_PARENT=5 -> ApiError rate_limited 429. The 6th child cannot be linked.', v_count;
  else
    raise notice 'VERDICT per-parent: count=% -> allowed', v_count;
  end if;

  select count(*) into v_count from public.pairing_attempts a
   where a.parent_user_id = 'b1000000-0000-4000-8000-000000000000'
     and a.attempted_at >= now() - interval '10 minutes'
     and not a.success;
  raise notice 'CONTROL: counting only failures gives % -> a parent with 0 failures would be allowed.', v_count;
end $$;

\echo '---- proof the success column is stored but never filtered ----'
select success, count(*) from public.pairing_attempts
where parent_user_id = 'b1000000-0000-4000-8000-000000000000' group by success;

\echo '================ scenario Q: per-code limit, 1 success + 9 failures on ONE code ================'
insert into public.pairing_attempts (parent_user_id, code_hash, success, attempted_at)
select 'b2000000-0000-4000-8000-000000000000',
       md5('SINGLE-CODE') || md5('SINGLE-CODE-salt'),
       (g = 1),                                   -- 1st row is the successful redeem
       now() - make_interval(secs => g * 20)      -- all inside 10 minutes
from generate_series(1, 10) g;

select
  (select count(*) from public.pairing_attempts a
     where a.code_hash = md5('SINGLE-CODE') || md5('SINGLE-CODE-salt')
       and a.attempted_at >= now() - interval '10 minutes') as per_code_count,
  (select count(*) from public.pairing_attempts a
     where a.code_hash = md5('SINGLE-CODE') || md5('SINGLE-CODE-salt')
       and a.attempted_at >= now() - interval '10 minutes'
       and a.success) as per_code_success_count,
  (select count(*) from public.pairing_attempts a
     where a.code_hash = md5('SINGLE-CODE') || md5('SINGLE-CODE-salt')
       and a.attempted_at >= now() - interval '10 minutes'
       and not a.success) as per_code_failure_count;

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.pairing_attempts a
   where a.code_hash = md5('SINGLE-CODE') || md5('SINGLE-CODE-salt')
     and a.attempted_at >= now() - interval '10 minutes';
  if v_count >= 10 then
    raise notice 'VERDICT per-code: count=% >= MAX_ATTEMPTS_PER_TOKEN=10 -> 429 "Ask for a new code.", even though only 1 row was a success.', v_count;
  else
    raise notice 'VERDICT per-code: count=% -> allowed', v_count;
  end if;
end $$;

\echo '---- mixed success/false rows as requested (5 rows, 3 true / 2 false) ----'
insert into public.pairing_attempts (parent_user_id, code_hash, success, attempted_at)
select 'b3000000-0000-4000-8000-000000000000',
       md5('MIX-' || g) || md5('MIX-salt-' || g),
       (g in (1, 3, 5)),
       now() - make_interval(mins => g)
from generate_series(1, 5) g;

select
  (select count(*) from public.pairing_attempts a
     where a.parent_user_id = 'b3000000-0000-4000-8000-000000000000'
       and a.attempted_at >= now() - interval '10 minutes') as current_count,
  (select count(*) from public.pairing_attempts a
     where a.parent_user_id = 'b3000000-0000-4000-8000-000000000000'
       and a.attempted_at >= now() - interval '10 minutes'
       and not a.success) as failures_only_count;
