# P4-E — TEST-01: handler testing. What the source pins prove, what they cannot, and the sequenced refactor

Phase: 4 · Workstream: E (agent E produced the baseline log then died; coordinator wrote the proposal)
Executed: 2026-11-03 · Verdict: **NOT IN SCOPE to implement / PROPOSED — handlers unchanged**
Evidence: `.tools/p4e-deno.log` (agent E, executed commands) · baseline `109 passed | 0 failed`, exit 0
Worktree proof that this workstream changed no handler: `git status --porcelain -- supabase/functions`
→ 0 lines, before and after (recorded in the same log).

Brief §7 requires the *exact* export and dependency-injection changes, the files and owners affected,
and — if implementation is not authorised — a sequenced proposal instead. Implementation needs owner
approval (decision #7): it edits the four deployed Edge Function entry points, so it is recorded, not
shipped.

---

## 1. What exists today, and what it actually proves

`supabase/functions/handler_wiring_test.ts` (279 lines, 5 tests) pins the wiring of four handlers by
**reading their source text** and asserting on the normalised string:

```ts
function normalize(text) { return text.replace(/\s+/g, " "); }            // :20-22
async function handler(p) { return normalize(await Deno.readTextFile(new URL(p, import.meta.url))); } // :24-29
```

| test (`handler_wiring_test.ts`) | pins | mechanism |
|---|---|---|
| `:72-104` device-command | one decision site; status written from the decision; version advances only on instruction; decision computed before the write | `import`/call substring + `assertEqualCount(source,"decideEnforcement(",1)` + lexical `assertOrder` |
| `:106-172` family-admin | `delete_zone`/`purge_data` gate on `canDeleteZone`/`canPurge`; membership resolved in the zone's own family; gate precedes the delete; `assertFamilyOwner` → 403 mapping in `_shared/auth.ts` | `caseBody()` slicing + substrings + `assertOrder` |
| `:174-200` family-admin | exactly one `.delete(` in `delete_zone`, scoped by both ids, audit only when `count > 0` | count + substring + order |
| `:202-232` remote-session | request runs the abandoned sweep through the wrapper; consent builds its patch from the guard helpers; terminal precedence; compare-and-set guard retained | substrings |
| `:234-264` account | delete/retention actions import and call the extracted modules; three `case` labels still dispatch | substrings |

**Legitimately proven:** that a refactor cannot silently drop the call into the extracted module, or
replace it with an inline re-implementation, without a test failing. That is exactly what the file's
own header claims (`:1-9`) and it is a real regression net — Phase 1/2 introduced these pins after
inline duplicates were found.

**NOT proven, stated plainly** (the brief asks for the distinction between source-level pins and
handler execution):

1. **No handler is ever executed.** No request is built, no response is read, no status code, no
   envelope body. "403 for a non-owner" is asserted as a *string inside a `throw` in `_shared/auth.ts`*
   (`:163-167`), not as an observed response.
2. **`assertOrder` is lexical, not temporal.** It compares `indexOf` positions in the source text
   (`:56-70`). Two calls in the same `case` body can execute in the opposite order — e.g. separated by
   an `await` whose continuation is re-entrant, or reached from different branches — and the pin still
   passes. Reachability under real values is unobservable this way.
3. **Count assertions are textual.** `assertEqualCount(source,"decideEnforcement(",1)` counts
   occurrences including the `import` line and any comment, so the "one decision site" claim is a
   proxy; renaming the import alias silently changes what is being counted.
4. **Whitespace-collapse cuts both ways.** Assertions encode a specific collapsed form such as
   `'.from("safe_zones") .delete('`, so re-flowing code passes (good) but an argument re-order inside
   the same collapse class can also pass (bad).
5. **The `--allow-read` coupling.** These 5 tests, plus `_shared/error_mapping_test.ts:51` and `:550`
   and `family-admin/delete_zone_atomicity_test.ts:241`, read `.ts` sources from disk; that is the root
   cause behind DOC-01's flagless failure. Nothing to do with SQL files.

So: **wiring regression net — yes. Behaviour test — no.** The behaviour of these four handlers is
currently covered only where it was extracted into pure modules (`enforcement_test.ts` 11,
`authorization_test.ts` 4, `guard_test.ts` 11, `account/validation_test.ts` 7, `retention_test.ts` 6,
`error_mapping_test.ts` 13, `delete_zone_atomicity_test.ts` 8 — all executable, all green). The
un-covered part is the `switch (action)` body itself: auth sequence, awaits, CAS guards, error mapping
end-to-end.

## 2. Why they cannot be executed as they stand

Two blockers, both structural, both in every one of the 10 `Deno.serve` entry points:

1. **Top-level side effect.** `device-command/index.ts:107` is a bare `Deno.serve(async (req) => …)`,
   with no exported handler. Importing the file from a test starts a listener. `deno test` would bind
   an ephemeral port per file and leak a server; worse, Deno Deploy-style runtime globals are assumed.
2. **Hidden global dependencies.** Inside the body: `const db = getServiceClient()`
   (`device-command/index.ts:115`), which is a **module-level memoised singleton** reading
   `Deno.env.get("SUPABASE_URL")` / `"SUPABASE_SERVICE_ROLE_KEY"` (`_shared/auth.ts:45-65`,
   `let cachedClient` at `:45`). Same for `recordAudit` (`_shared/audit.ts`) and `requireUser`, which
   resolves the JWT through that client. Without env vars, `getServiceClient()` throws
   `server_misconfigured/503` — i.e. the first await in every action fails before the rule under test
   runs. There is no seam to substitute a fake.

## 3. Sequenced implementation proposal (for owner approval, not executed)

Ordered so that every step is independently reviewable and every step keeps the deployed entry point
behaving identically.

**Step 0 — decide the shape (1 review, no code).**
Recommended layout: **file split, not an env-flag guard.**
Rejected alternative: `if (!Deno.env.get("VITEST")) Deno.serve(handler)` inside `index.ts` — a
production code path that changes based on a test-only environment variable is exactly the kind of
flag that mis-deploys. The split leaves `index.ts` as a two-line entry with no condition.

**Step 1 — export-first split, one handler per change (mechanical, no logic edit).**
For each of the four, move the body of the `Deno.serve` callback verbatim into a new
`<fn>/handler.ts` exporting `export async function handler(req: Request, deps: HandlerDeps): Promise<Response>`,
and reduce `<fn>/index.ts` to imports of that symbol plus `Deno.serve((req) => handler(req, defaultDeps()))`.

| file | lines today | action |
|---|---|---|
| `supabase/functions/device-command/index.ts` | 399 (`:107` serve) | split → `handler.ts` |
| `supabase/functions/family-admin/index.ts` | 399 | split → `handler.ts` |
| `supabase/functions/remote-session/index.ts` | 384 | split → `handler.ts` |
| `supabase/functions/account/index.ts` | 480 | split → `handler.ts` |

Diff discipline: pure move; a reviewer should see only the function signature line and the 2-line
entry file as *new*. Any other delta in the commit is a bug. The other six entry points
(`auth-bootstrap`, `cron`, `device-policy`, `device-register`, `device-telemetry`, `pairing`) are left
alone until this pattern is proven.

**Step 2 — one dependency seam, shared.** New `_shared/handler_deps.ts`:

```ts
export interface HandlerDeps {
  db: () => SupabaseClient;                        // production: getServiceClient
  audit: typeof recordAudit;                       // production: recordAudit
  now: () => string;                               // production: new Date().toISOString()
  uuid: () => string;                              // production: crypto.randomUUID()
}
export function defaultDeps(): HandlerDeps { … }   // the current behaviour, unchanged
```

`handler(req, deps)` replaces the in-body `getServiceClient()` / `recordAudit(...)` / `crypto…` calls
with `deps.db()` / `deps.audit(...)` / `deps.uuid()`. Rationale for a parameter object rather than a
`setServiceClient()` test hook: module-global mutation makes tests order-dependent and can leak a fake
client into a warm Edge Runtime isolate between invocations — the memoised `cachedClient`
(`_shared/auth.ts:45`) already shows how sticky this state is.

Note this is a *behaviour-preserving* change only if `defaultDeps()` is the sole production caller;
the `now`/`uuid` seams exist so a test can pin a timestamp, not to change semantics.

**Step 3 — a narrow fake, sized to what these four actually use.** Measured surface (counts of
builder calls inside the four `index.ts` files today):

| handler | builders used | `await`s |
|---|---|---|
| device-command | `.from` 8, `.eq` 11, `.maybeSingle` 5, `.update` 4, `.rpc` 2, `.in` 2, `.single` 1, `.insert` 1 | 22 |
| family-admin | `.from` 10, `.eq` 9, `.maybeSingle` 4, `.delete` 3, `.update` 2, `.rpc` 2, `.insert` 2, `.single` 1, `.is` 1 | 28 |
| remote-session | `.from` 8, `.eq` 13, `.update` 5, `.maybeSingle` 5, `.rpc` 2, `.order` 1, `.limit` 1, `.in` 1 | 30 |
| account | `.from` 13, `.eq` 20, `.in` 5, `.order` 3, `.delete` 3, `.maybeSingle` 1, `.limit` 1, `.is` 1 | 27 |

So the fake needs: `from(table)` → filter chain (`eq`, `in_`, `is`, `order`, `limit`, `gte`), verbs
(`select`, `insert`, `update`, `delete`, `upsert`) with `{ count: "exact" }`, terminal
`maybeSingle`/`single`, and `rpc(name, args)` — plus the ability to return a
`{ error: { code: "42501", message, details } }` to drive the SQL-03 path end-to-end. Roughly 150 lines
in `_shared/test_support/fake_postgrest.ts`, driven by a plain `Map<table, Row[]>`. It must reject
unsupported builder methods loudly, so a future handler cannot quietly use a method the fake doesn't
implement and get a false green.

**Step 4 — executable tests that replace, not duplicate, each pin.** Per action: assert the observed
status code and envelope `error_code`, and the fake's recorded writes. Concretely the ones that matter:

| in-scope risk today pinned lexically | executed test after the refactor |
|---|---|
| `delete_zone` non-parent gets 403 before any write | `handler(request(...), deps)` → `status === 403`, `.delete` never recorded, no audit row |
| audit written only when `count > 0` | same request with the row absent → no audit insert; present → exactly one |
| CAS guard against a concurrent end (`remote-session` respond) | pre-set session `status="accepted"`, respond accept → existing row returned, zero updates issued |
| `enforcement_status` derived only from the decision | ack with `result` claiming 5/5 applied but `policy_id` mismatching → status stays `pending`, `policy_version` unchanged |
| 42501 → `owner_required`/`forbidden` mapping end-to-end | fake returns `error.code = "42501"` on the family read → observed 403 body, `server_misconfigured` never returned |
| `purge_data` resolves family through `assertFamilyOwner` first | fake records call order; assert the owner assertion precedes any delete |

**Step 5 — retire the pins that became redundant, keep the ones that did not.** After step 4, the
substrate pins for those six risks are duplicates of an executed assertion and should be deleted (with
their `--allow-read` need). Pins with no behavioural equivalent — e.g. "exactly one decision site" —
can stay; they guard a structural property an executed test cannot see. Any pin deletion must land in
the same commit as the executed test that replaces it, so coverage never dips mid-series.

**Step 6 — verification.** `deno check supabase/functions/`, `deno test --allow-read supabase/functions/`
(the flag stays because other tests still read sources — see DOC-01), then redeploy is **not** part of
this phase; the owner's deployment gate (HOST-01) governs when these entry points go anywhere.

### Cost, risk, ownership

- **Files touched:** 4 handler entry points + 4 new `handler.ts` + 1 new `_shared/handler_deps.ts` +
  1 new fake + test files. Total ≈ 10–12 files, of which 9 are new-or-mechanical.
- **Risk:** the *only* production-visible risk is a non-mechanical edit during the move. Mitigation is
  the diff discipline in step 1 plus the existing green suite (109 tests) on the same commit.
- **Ownership:** Edge Function handlers belong to the session/enforcement/family-admin workstreams per
  `docs/implementation/feature-ownership.md`; this spans four of them, which is precisely why brief §7
  forbids doing it without approval.
- **Sizing:** 4–6 focused engineer-days (1 per handler for steps 1–2, 1 for the fake, 1–2 for step 4),
  sequenced one handler at a time — `device-command` first as the smallest surface.

## 4. What Phase 4 concludes

TEST-01 stays **open**. It is not a defect: today's net is real but narrow, and nothing in Phase 1–4
behaviour has been shown to be wrong. It is a testability gap that becomes a *deployment* risk if the
handlers keep growing (they are 384–480 lines each, with 22–30 awaits apiece, of which zero are
executed in test). Recommendation to the owner: schedule it as a Phase 5 engineering-hygiene item,
before further handler feature work, not as a Phase 4 blocker — and do not couple its approval to
HOST-01.
