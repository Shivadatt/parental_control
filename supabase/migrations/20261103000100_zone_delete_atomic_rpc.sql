-- ============================================================================
-- Phase 5 / workstream SQL-05 — atomic audited safe-zone delete.
--
-- STATUS: Phase 5 SQL-05. UNAPPLIED TO HOSTED. LOCAL-TESTED ONLY.
--   * Not applied to the hosted Supabase project; nothing in this file has run
--     against any hosted environment, and it must not be deployed by this
--     workstream (owner approval for the SQL surface covers adding this
--     service-role-only function, not deploying it).
--   * Verified only on a disposable local PostgreSQL 16.9 cluster via the
--     documented `psql -f` chain in supabase/tests/README.md, together with
--     supabase/tests/76_zone_delete_atomic_rpc.sql. Captured logs and their
--     digests live in the Phase 5 evidence pack:
--     docs/evidence/phase5/MANIFEST.md §2 rows 9-10 (green chain
--     `logs/p5coord-chain-run9.log`, lossy-RPC negative control
--     `logs/p5coord-chain-negative3.log` -> ASSERT_FAILED=1 at tests/76:411)
--     and §3 (chain command, 33 -f entries, measured proacl).
--   * Converted from the reviewed proposal
--     docs/implementation/proposals/phase3-safe-zone-audit-atomicity.sql
--     (owner-approved in Phase 5). The proposal's deviations are listed in
--     "DIFFERS FROM THE PROPOSAL" at the bottom of this header.
--
-- THE DEFECT THIS CLOSES (gap SQL-05, since Phase 1)
-- `family-admin` action `delete_zone` deleted the `safe_zones` row with one
-- PostgREST call and wrote the `zone_deleted` `audit_logs` row with a second,
-- independent call. The DELETE committed on its own; if the INSERT then failed
-- the deletion stood **unaudited**, and a retry 404'd on the pre-read, so the
-- ledger could not be repaired through the API. The shipped Phase 3 stopgap is
-- bounded audit retries plus a compensating restore
-- (supabase/functions/family-admin/delete_zone_atomicity.ts), which leaves
-- three residual windows documented in that module: duplicate `zone_deleted`
-- rows when an insert commits but its response is lost, a re-created zone whose
-- (already audited) deletion was unknown to us, and cascade-deleted
-- `safe_zone_states` latches that the restore cannot rebuild.
--
-- THE FIX
-- One SECURITY DEFINER function that resolves the zone, authorizes the actor,
-- deletes the row and appends the audit row **inside one function body**.
-- Called via PostgREST it is one statement in one transaction, so an audit
-- failure aborts the delete with it: the zone survives, no audit row exists,
-- and the client gets a retryable error. Invariants this buys:
--   1. no committed deletion without its audit row (the point of the gap),
--   2. no audit row when zero rows were deleted,
--   3. no duplicate row from a lost response — a retry re-resolves the zone and
--      404s instead of deleting-and-auditing twice.
--
-- MECHANISM PRECEDENT (copied, not invented)
-- `public.expire_abandoned_sessions`
-- (supabase/migrations/20261030000100_abandoned_session_sweep.sql:87-161)
-- already mutates rows AND writes `audit_logs` inside one SECURITY DEFINER
-- function granted to `service_role` only, and is called from an Edge Function
-- (`supabase/functions/cron/index.ts:84`). This file copies that shape:
-- `security definer`, `set search_path = public, private, pg_temp`, audit
-- through `private.record_audit` (20260101000100_functions.sql:8-39), the same
-- revoke/grant pair, and no table-grant or RLS change anywhere.
--
-- TRUSTED ACTOR ATTRIBUTION (hard requirement, same hole 20261030000200 closed)
-- The acting user arrives as the `p_actor_user_id` parameter, supplied by the
-- Edge Function from server-side JWT validation
-- (`supabase/functions/_shared/auth.ts:80-127` `requireUser`, which resolves the
-- token with `db.auth.getUser(token)` and reads `user.id`). This function NEVER
-- reads `current_setting('request.jwt.claim.sub')` — that GUC is client-settable
-- over PostgREST, and migration 20261030000200:186-211 (the
-- `private.is_parent_of_family(uuid, uuid)` helper) exists precisely so a
-- service RPC can verify a caller-SUPPLIED actor id instead of trusting it. The
-- same pattern is used by `public.revoke_device(uuid, uuid)`
-- (20261030000200:318-345). Authorization is `private.is_parent_of_family`,
-- raising `not_family_parent` with SQLSTATE 42501, which is the exact vocabulary
-- the four Phase 1 wrappers already use and the exact mapping
-- `family-admin/index.ts` already implements.
--
-- PRIVILEGES / RLS
--   * Execute: `service_role` only. Revoked from `public`, `anon`,
--     `authenticated`. Not client-callable: §7 of
--       docs/implementation/api-contract.md forbids a client calling a
--       service-only RPC, and this grant shape does not create one.
--   * No table privilege, RLS policy, trigger, column, constraint or new table
--     is created, altered or revoked here. The zone DELETE is reachable only
--     through this function: `authenticated`/`anon` hold no DELETE on
--     `safe_zones` since 20261030000200:171-175, and that stays true.
--   * `audit_logs` stays append-only: this path only INSERTs, and
--     `private.audit_logs_append_only` (20260101000000_core.sql:543-565) is
--     untouched.
--   * `safe_zone_states` cascade semantics are unchanged: deleting a zone still
--     wipes its inside/outside latches (core.sql:287 `on delete cascade`); only
--     the auditability of that delete becomes atomic.
--
-- ERROR VOCABULARY (the handler maps these to the frozen HTTP contract; the
-- observable envelope of `delete_zone` does not change)
--   zone_not_found     (P0001) -> 404 `zone_not_found`
--   not_family_parent  (42501) -> 403 `forbidden`   (same as revoke_device)
--   family_unavailable (42501) -> 403 `forbidden`    (soft-deleted/absent
--                                                      family; mirrors
--                                                      auth.ts loadFamily)
--   any other error (e.g. the audit INSERT failing) propagates unchanged and
--                      aborts the whole call -> 500 `audit_failed`, zone kept.
--
-- NO CLIENT-VISIBLE API CHANGE
-- `delete_zone` keeps `{deleted:true}` on both the `deleted` and the
-- defensive `already_gone` return, `zone_not_found`/404, `forbidden`/403 and
-- `audit_failed`/500. `data` is unchanged, so §7's "existing fields may not be
-- renamed or removed" holds.
--
-- DIFFERS FROM THE PROPOSAL (deliberate, recorded here because this file is
-- the approved conversion of docs/implementation/proposals/
-- phase3-safe-zone-audit-atomicity.sql)
--   1. Not-found RETURNS `{'status':'not_found'}` in the proposal; here it
--      RAISES `zone_not_found` (P0001). The proposal's value return would make
--      the handler branch on `data.status` for one error and on `rpc.error` for
--      the others; raising keeps one error channel, which is what
--      `revoke_device` already does (index.ts:70-93).
--   2. The proposal's `select family_id` is unlocked and the comment claims
--      "locking is provided by the delete's own row lock" — that leaves a real
--      read-then-delete window in which a concurrent deleter can commit between
--      the SELECT and the DELETE, so this function's DELETE would match zero
--      rows while still auditing nothing and still reporting `already_gone`.
--      Here the resolve SELECT takes `FOR UPDATE` (mirroring
--      `expire_abandoned_sessions`' `for update` cursor, :110-117), so a
--      concurrent deleter is serialised and the loser gets `zone_not_found`.
--   3. The audit row is written through `private.record_audit` (the precedent's
--      own mechanism) instead of a duplicated literal INSERT, so the shape
--      cannot drift from every other audit row, and the returned audit id is
--      available to the handler for logging.
--   4. Adds the `family_unavailable` branch, which the proposal lacks, so the
--      soft-deleted-family 403 keeps its exact current message text instead of
--      degrading to `not_family_parent`.
--   5. The DELETE is scoped `id = p_zone_id and family_id = v_family_id`
--      (defense in depth against a mid-flight family change); the proposal
--      scopes on the id alone. Behaviour is identical because `v_family_id` was
--      read from that row under the same lock.
--
-- ROLLBACK (true revert; `drop` alone does not restore grants)
--   revoke all on function public.delete_safe_zone_audited(uuid, uuid) from service_role;
--   drop function if exists public.delete_safe_zone_audited(uuid, uuid);
--   -- and the Edge Function must return to the Phase 3 retry + compensating
--   -- restore path (delete_zone_atomicity.ts), NEVER to a bare two-call
--   -- delete-then-audit. That is why supabase/functions/family-admin/
--   -- delete_zone_atomicity.ts and its test are kept in the tree.
-- Re-running this file is a no-op: `create or replace` + idempotent grants, and
-- no row, column, constraint, policy or index is touched.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- The atomic core: resolve, authorize, delete, audit — one function body.
-- ---------------------------------------------------------------------------
create or replace function public.delete_safe_zone_audited(
  p_zone_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_family_id uuid;
  v_zone_name text;
  v_deleted   integer;
  v_audit_id  uuid;
begin
  -- Never attribute an action to nobody. Checked first so a NULL actor can
  -- neither reach is_parent_of_family() nor an authorization bypass.
  if p_actor_user_id is null then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  -- A missing zone id is "no such zone", not "no such row for that id": the
  -- handler's readUuid() already rejected non-UUIDs before this call, so the
  -- only way to reach it is a null body field.
  if p_zone_id is null then
    raise exception 'zone_not_found' using errcode = 'P0001';
  end if;

  -- Resolve the zone under a row lock, so the family used for authorization,
  -- the delete predicate and the audit row all describe ONE snapshot. A
  -- concurrent deleter blocks here and, once it has committed, this re-evaluates
  -- to "no row" -> zone_not_found (so the retry never audits twice).
  select sz.family_id, sz.name
    into v_family_id, v_zone_name
  from public.safe_zones sz
  where sz.id = p_zone_id
  for update;

  if v_family_id is null then
    -- Unknown zone id, or a retry after a successful delete. Nothing was
    -- deleted, so nothing may be audited (invariant 2).
    raise exception 'zone_not_found' using errcode = 'P0001';
  end if;

  -- Mirror the Edge Function's loadFamily() gate (_shared/auth.ts:141-155): a
  -- soft-deleted or absent family is forbidden, not "not a parent", so the
  -- client keeps today's exact 403 message.
  if not exists (
    select 1
    from public.families f
    where f.id = v_family_id
      and f.deleted_at is null
  ) then
    raise exception 'family_unavailable' using errcode = '42501';
  end if;

  -- Server-side authorization, using the Phase 1 helper (20261030000200:186-211)
  -- and its error vocabulary. This is the authoritative gate: the Edge
  -- Function's own assertFamilyParent() check is UX only, and a forged
  -- p_actor_user_id reaches exactly here. A parent of another family fails
  -- this test, which is also the cross-family guard — is_parent_of_family()
  -- requires role='parent' AND status='active' AND f.deleted_at is null.
  if not private.is_parent_of_family(p_actor_user_id, v_family_id) then
    raise exception 'not_family_parent' using errcode = '42501';
  end if;

  delete from public.safe_zones
  where id = p_zone_id
    and family_id = v_family_id;
  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    -- Defensive: unreachable while holding the row lock above, kept as the
    -- explicit postcondition that a zero-row delete is NEVER audited. The
    -- caller's goal (this zone no longer exists) is already satisfied.
    return jsonb_build_object(
      'status', 'already_gone',
      'zone_id', p_zone_id,
      'audited', false
    );
  end if;

  -- Same transaction as the delete: if this INSERT fails, the DELETE above
  -- rolls back with it. Field-for-field identical to what
  -- `delete_zone_atomicity.ts` buildZoneAuditInsert() and _shared/audit.ts
  -- recordAudit() produced, so no consumer of the ledger can tell the
  -- difference: device_id NULL, event_type 'zone_deleted', target_type
  -- 'safe_zone', target_id the zone id as text, metadata {'name': <zone name>}.
  v_audit_id := private.record_audit(
    v_family_id,
    p_actor_user_id,
    null,
    'zone_deleted',
    'safe_zone',
    p_zone_id::text,
    jsonb_build_object('name', v_zone_name)
  );

  return jsonb_build_object(
    'status', 'deleted',
    'zone_id', p_zone_id,
    'family_id', v_family_id,
    'audit_id', v_audit_id,
    'audited', true
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges: service_role only (mirrors 20261030000100:158-161 and
-- 20261030000200:343-345). PG15+ no longer grants PUBLIC EXECUTE by default, so
-- the revoke is defence-in-depth for older/local builds and a pin for readers.
-- The SECURITY DEFINER owner holds DELETE on safe_zones and INSERT on
-- audit_logs as the table owner; no table grant changes.
-- ---------------------------------------------------------------------------
revoke all on function public.delete_safe_zone_audited(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.delete_safe_zone_audited(uuid, uuid)
  to service_role;
