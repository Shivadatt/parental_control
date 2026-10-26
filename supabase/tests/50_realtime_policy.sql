-- Exercises the private postgres_changes policy created by
-- 20260101000200_rls.sql. Run after 05_realtime_stub.sql creates the local
-- stand-in schema and after 20_fixtures.sql creates the users and sessions.
-- Run before 40_functions.sql, which unlinks child4.
\set ON_ERROR_STOP on
\pset pager off

reset role;

-- Realtime evaluates this policy once for the subscribed topic, not per row.
-- A direct SELECT over realtime.messages therefore admits every
-- extension='postgres_changes' row when the topic is allowed; the internal queue
-- is never delivered to clients, and the public tables' own RLS filters the
-- actual payload rows. These assertions verify the topic gate and the extension
-- filter, which is what the Realtime server checks.
select tests.assert_true(
  exists (
    select 1 from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'parentcontrol_private_topics'
  ),
  'the private channel policy was created'
);

insert into realtime.messages (topic, extension, payload)
values
  ('safety-alerts:' || tests.get('family1'), 'postgres_changes', '{"n":1}'),
  ('safety-alerts:' || tests.get('family2'), 'postgres_changes', '{"n":2}'),
  ('safety-alerts:' || tests.get('family1'), 'broadcast', '{"n":3}'),
  ('remote-session:50000000-0000-4000-8000-000000000001', 'postgres_changes', '{"n":4}'),
  ('remote-session:50000000-0000-4000-8000-000000000002', 'postgres_changes', '{"n":5}'),
  ('bogus:' || tests.get('family1'), 'postgres_changes', '{"n":6}');

set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);

-- child1 in family1
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);
select set_config('realtime.topic', 'safety-alerts:' || tests.get('family1'), false);
select tests.assert_true(
  count(*) = 5 and count(*) filter (where extension = 'postgres_changes') = 5,
  'child1 may subscribe to family1 alerts and broadcast rows are excluded'
)
from realtime.messages;

select set_config('realtime.topic', 'safety-alerts:' || tests.get('family2'), false);
select tests.assert_true(count(*) = 0, 'child1 cannot subscribe to family2 alerts')
from realtime.messages;

select set_config('realtime.topic', 'remote-session:50000000-0000-4000-8000-000000000001', false);
select tests.assert_true(count(*) = 5, 'child1 may subscribe to its own session1')
from realtime.messages;

select set_config('realtime.topic', 'remote-session:50000000-0000-4000-8000-000000000002', false);
select tests.assert_true(count(*) = 0, 'child1 cannot subscribe to family2 session2')
from realtime.messages;

select set_config('realtime.topic', 'safety-alerts:' || tests.get('family1'), false);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', false);
select tests.assert_true(count(*) = 5, 'child4 may subscribe to its own family alerts')
from realtime.messages;

select set_config('realtime.topic', 'remote-session:50000000-0000-4000-8000-000000000001', false);
select tests.assert_true(count(*) = 0, 'child4 cannot subscribe to a session it is not part of')
from realtime.messages;

-- parent1 in family1
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
select set_config('realtime.topic', 'remote-session:50000000-0000-4000-8000-000000000001', false);
select tests.assert_true(count(*) = 5, 'parent1 may subscribe to family1 session1')
from realtime.messages;

select set_config('realtime.topic', 'remote-session:50000000-0000-4000-8000-000000000002', false);
select tests.assert_true(count(*) = 0, 'parent1 cannot subscribe to family2 session2')
from realtime.messages;

select set_config('realtime.topic', 'not-a-topic', false);
select tests.assert_true(count(*) = 0, 'malformed topic is denied')
from realtime.messages;

reset role;
