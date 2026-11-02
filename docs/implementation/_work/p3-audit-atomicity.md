# P3-C — SQL-05: safe-zone delete / audit-row atomicity (phase notes)

Branch `main` @ `8da1de7`, Phase 2 worktree preserved; nothing committed, nothing deployed,
Supabase CLI never invoked, no local database started.

## 1. The failure window (pre-fix, verified in code)

Sequence in `supabase/functions/family-admin/index.ts` (Phase 2 worktree line numbers):

1. `:175-179` pre-read of the zone (service role); `:184-190` `zone_not_found`/404 if absent.
2. `:192-203` `assertFamilyParent` + `canDeleteZone` (403 path).
3. `:205-209` `DELETE FROM safe_zones WHERE id AND family_id` with `count:"exact"` — one
   PostgREST request, committed in its own transaction the moment it returns OK.
   `:210` `ensureNoError(deleted)` → a failed delete never reaches the audit.
4. `:214` gate `if ((deleted.count ?? 0) > 0)` — a zero-row delete (only possible if the row
   vanished between step 1 and step 3, i.e. concurrent delete) skips the audit entirely and
   still answers `{deleted:true}` (`:224`). Deliberate and correct: no audit without an
   actual removal.
5. `:215-223` `recordAudit(...)` → `_shared/audit.ts:20-28` INSERT into `audit_logs` in a
   second, independent transaction; `:29-36` on error it logs `audit_insert_failed:<code>`
   and throws `ApiError("audit_failed", …, 500)`.

**Window** = between commit of step 3 and commit of the insert in step 5. Only the audit
INSERT can fail there (connection loss / DB down; FK checks cannot block it —
`family_id`/`actor_user_id` are nullable references with `on delete set null`, and
`event_type` is a constant within the 1–80 check). Resulting state: zone gone (its
`safe_zone_states` latches cascade-wiped, `core.sql:287`), **no `zone_deleted` audit row**,
client receives a 500 whose wording ("The action could not be recorded") is truthful but was
previously the only signal, with no log line naming *which* zone is unaudited.
**Retry is impossible through the API**: a second `delete_zone` call hits the 404 pre-read
(step 1), so the ledger can never be repaired for that deletion.

## 2. Atomic RPC vs trigger — contract answer

* `coordinator-contract.md:21-23` (rule 8) forbids "No new RPC **that clients call
  directly**"; `api-contract.md` §7 ("No client calls a service-only RPC directly… Adding a
  new client-callable RPC, or granting execute on a new function to `authenticated`, is a
  breaking contract change"). A `service_role`-only function called solely by the Edge
  Function satisfies the letter of both.
* Precedent that the *mechanism* is already approved: `public.expire_abandoned_sessions`
  (`20261030000100_abandoned_session_sweep.sql:47-121`, listed in `api-contract.md` §6)
  mutates rows and writes `audit_logs` inside one SECURITY DEFINER function, service-role
  only.
* BUT `api-contract.md` §6 is the closed list of approved new SQL surfaces and
  `phase-2-open-gaps.md` §1 freezes the pending migration chain to exactly three files; a
  fourth migration changes the deployment gate and the `supabase/tests/` chain (owned by
  P3-A1/coordinator). **Verdict: legal in privilege shape, outside approved scope in
  process → STOP for owner approval; written as a proposal, not a migration.**
* Trigger alternative rejected: the handler uses the service-role key with no per-request
  JWT forwarding, so a trigger cannot attribute `actor_user_id` without trusting a
  client-settable GUC — the forged-actor hole `20261030000200` closed for `revoke_device` —
  and it would fire on every future service-role delete.

## 3. What was implemented (path B: provably safe inside `family-admin` alone)

`supabase/functions/family-admin/delete_zone_atomicity.ts` (new, importable — the
`remote-session/lifecycle_test.ts` DI pattern) owns the post-delete decision:

* audit insert retried up to `AUDIT_MAX_ATTEMPTS = 3` with linear backoff (injectable sleep);
* if every attempt fails: **compensating restore** of the exact pre-delete row (pre-read now
  selects `lat, lng, radius_m, active, created_by, created_at`), then `audit_failed`/500
  "the safe zone was kept" (`zone_delete_reverted:<id>` in the log);
* if the restore also fails: explicit `audit_failed`/500 stating the zone **was** deleted
  but not recorded, log line `zone_delete_unaudited:<code>:<zone id>` — never `{deleted:true}`;
* zero-row delete: module not called, no audit (invariant 1 unchanged); delete error:
  `ensureNoError` short-circuits before any audit.

Invariants preserved: audit-only-on-actual-removal; no *silent* unaudited deletion;
`audit_logs` remains append-only (insert-only code, immutability trigger untouched, audit
row shape byte-identical to `recordAudit`). Error codes unchanged (`audit_failed`,
`zone_not_found`, `forbidden`); `details` field on `fail()` is documented additive-only
(`envelope.ts:44-48`). The client shows `error.message` verbatim
(`edge_api.dart:111-116` → `supabase_location_repository.dart` `_mapError` passthrough →
`safe_zones_page.dart:77,315` `actionError…message`), so **no `lib/` change was needed**.
`handler_wiring_test.ts` (all pinned strings) untouched and still green.

## 4. Tests — what is real injection vs source-level

`supabase/functions/family-admin/delete_zone_atomicity_test.ts`
(6 `[injected]` tests execute the decision module with fake stores: audit-succeeds,
transient-fail-then-success, audit-always-fails→restore, audit+restore-fail, budget=1,
not-called-no-writes; **2 `[source-level]` tests** read `index.ts` because the bare
`Deno.serve` handler is not importable — they pin call-site ordering: guard→module,
ensureNoError→module, both failure throws before `return ok`, single delete site, full
snapshot select).

Genuinely NOT executable here without the frozen contract change: true cross-transaction
atomicity (needs the proposed RPC + a real PG cluster — P3-A1/A2 clusters are not mine),
real PostgREST commit-vs-response loss (network-level fault injection).
Also un-runnable by me: `flutter test` (coordinator owns it); relevant existing Flutter
tests (`safe_zone_delete_wiring_test.dart`) only fake the Edge API, unaffected by this change.

## 5. Residual risks (documented in the module header, not hidden)

* Retry after a commit-then-lost-response audit insert can duplicate the `zone_deleted` row
  (over-recording; append-only-safe). In the same pathological window the restore can
  re-create a zone whose deletion was already audited.
* Compensating restore re-creates the zone row but not cascade-deleted `safe_zone_states`
  latches; they rebuild on the next `location_upload` — inside/outside history resets.
* Full atomicity still requires the approved proposal — until then SQL-05 is *mitigated*,
  not closed: residual probability = all 3 inserts AND the restore failing simultaneously
  (same DB outage), now loudly surfaced instead of silent.

## 6. Executed

```
deno test --allow-read supabase/functions/family-admin            → ok | 12 passed | 0 failed
deno test --allow-read supabase/functions/handler_wiring_test.ts  → ok | 5 passed | 0 failed (regression)
deno check supabase/functions/family-admin/{index.ts,delete_zone_atomicity.ts,delete_zone_atomicity_test.ts} → exit 0
```

Not run (not mine / forbidden): `flutter test`, `flutter build`, Supabase CLI, local PG, any hosted op.

## 7. Proposal

`docs/implementation/proposals/phase3-safe-zone-audit-atomicity.sql` — service-role-only
`public.delete_safe_zone_audited(uuid, uuid)` SECURITY DEFINER RPC (resolve → re-check
`private.is_parent_of_family` → delete RETURNING → audit INSERT, one function = one
transaction), zero-row and not-found short-circuit without audit, rollback block, privilege
and behaviour deltas, and the cross-file changes required on approval. Not in the applied
chain; not in `supabase/tests/README.md` run order.
