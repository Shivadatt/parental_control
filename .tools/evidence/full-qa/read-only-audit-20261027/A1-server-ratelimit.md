# A1 — Root cause: "You have created too many linking codes today. Try again later."

Read-only audit, 2026-10-27. No file modified, no migration run, no hosted-DB write, no Edge Function deployed.
All Q7 evidence is from local `.tools/` logs; the hosted database was not queried.

## Verdict

Your reading is **correct on every point**, and the contract itself proves it is a bug rather than intent.

`supabase/functions/_shared/rate_limit.ts:75-79` counts **every** `device_pairing_tokens` row for the child in a
rolling 24h window filtered on `created_at` only — no `status` filter, no `expires_at` filter. Since
`supabase/functions/pairing/index.ts:227-237` unconditionally INSERTs a row before `:248-253` revokes the previous
`active` one, each button press permanently burns one unit of a 5-unit daily budget for a code that is already dead.
Revoked, expired and `redeemed` rows all keep counting; nothing deletes or ages them out.

The child never caused this by double-tapping. **The QA harness exhausted the budget, and it did so before the
Phase-2 UI journey began** (see Q7). And `docs/api-contract.md:301-304` specifies "Max 5 **active** code creations
per 24h" — the word *active* is the spec, and the implementation dropped it. That makes this a spec/implementation
divergence, not a designed policy.

## 1. `device_pairing_tokens` schema

`supabase/migrations/20260101000000_core.sql:128-142` (indexes at `:144-147`):

`id` uuid PK `gen_random_uuid()` (129) · `child_user_id` uuid NOT NULL→`profiles` CASCADE (130) · **`code_hash` text
NOT NULL UNIQUE** + `check ~ '^[0-9a-f]{64}$'` (131-132) · `expires_at` timestamptz NOT NULL, no default (133) ·
`redeemed_at` nullable (134) · `redeemed_by`→`profiles` SET NULL (135) · **`status` text NOT NULL DEFAULT `'active'`
with `check (status in ('active','redeemed','revoked','expired'))`** (136-137) · `attempts` int NOT NULL DEFAULT 0
`>=0` (138) · `max_attempts` int NOT NULL DEFAULT 10 `>0` (139) · `created_at` timestamptz NOT NULL DEFAULT `now()`
(140) · `created_by`→`profiles` SET NULL (141).

Indexes: `(child_user_id, status)` at 144-145 — exactly what a status-filtered count would use, which the current
unfiltered count ignores — and `(expires_at)` at 146-147.

**There is no `consumed` status.** The four legal values are `active | redeemed | revoked | expired`. "Consumed"
in your proposal maps to `redeemed`. Status writers: `redeemed` at `20260101000100_functions.sql:280-282` (child
approves), `revoked` at `:301-303` (child rejects), `:398-401` (unlink), `pairing/index.ts:248-253` (superseded by a
new code) and `:521-524` (parent cancel), `expired` at `pairing/index.ts:308-313` (lazily, at redeem) and `:440-445`
(lazily, on the child's `pending_child` poll).

**`attempts` / `max_attempts` are dead columns.** `pairing/index.ts:295` selects them into `TokenRow` (`:55-56`) and
never reads or increments them; the only `attempts` arithmetic in SQL is `functions.sql:633` on `device_commands`.
The real per-token cap is enforced by counting `pairing_attempts.code_hash`, and its `default 10` merely coincides
with `MAX_ATTEMPTS_PER_TOKEN = 10` (`rate_limit.ts:7`). RLS: `device_pairing_tokens` is service-role-only, no
policies (`20260101000200_rls.sql:9`, `:74`, `:287`), so the client cannot read or clear its own state.

## 2. Timing constants

- `CODE_TTL_MINUTES = 10` — `supabase/functions/pairing/index.ts:36`; applied `:223-225`, returned `:273`.
- `ATTEMPT_WINDOW_MINUTES = 10` (`rate_limit.ts:5`, via `windowStart()` `:10-12`), `MAX_ATTEMPTS_PER_PARENT = 5`
  (`:6`), `MAX_ATTEMPTS_PER_TOKEN = 10` (`:7`), `CODE_CREATIONS_PER_24H = 5` (`:8`).
- The 24h window is **hardcoded inline, not a named constant**: `rate_limit.ts:74`
  `new Date(Date.now() - 24 * 60 * 60 * 1000)`. No config/secret override exists anywhere.
- Adjacent: offline threshold 15 min + 6h alert suppression (`functions.sql:546`, `:552`); client poll 15s
  (`child_enrollment_controller.dart:40`).

Confirmed: only `code_hash` is stored (`core.sql:131`). The plaintext from `generatePairingCode()`
(`validation.ts:237-251`) exists solely in memory and is emitted once at `pairing/index.ts:270-274`, never persisted,
and there is no `get my current code` action. **Returning an existing unexpired code is therefore impossible** — a
child who backgrounded or restarted the app cannot recover the code, only mint a new one. This drives the fix shape.

## 3. Reuse and purge: both absent

**No reuse path exists.** `pairing/index.ts:221-237` generates a fresh code and inserts unconditionally; no lookup for
an existing `active` + unexpired token for `auth.user.id`. (Reuse is impossible per section 2.)
**No purge path exists anywhere.** Exhaustive check:

- `private.expire_stale_sessions()` (`functions.sql:511-529`) — `remote_sessions` only; never references
  `device_pairing_tokens` or `pairing_attempts`. `private.detect_offline_devices()` (`:531-570`) — `devices` +
  `safety_alerts` only.
- `cron/index.ts` — the entire switch is two cases, `expire_sessions` (`:40-51`) and `detect_offline` (`:52-63`),
  calling exactly those two RPCs. **No third maintenance job, and no `default` that could purge.** The pg_cron
  bootstrap (`functions.sql:952-967`) schedules only those two.
- `family-admin` `purge_data` (`:157-227`) — deletes from `location_events` (`:187-191`) and `usage_daily`
  (`:194-199`) **only**; it cannot reach pairing tables even by accident, and its cutoff is floored at the family
  retention minimum (`:172-179`).
- `unlink_child` (`functions.sql:398-401`) UPDATEs active tokens to `revoked`, never DELETEs — and revoked rows still
  count, so unlinking a child to let them re-pair *keeps* their old rows in the budget.
- `pairing_attempts` is append-only: `recordPairingAttempt` (`rate_limit.ts:49-68`) only inserts, and no delete exists
  anywhere in `supabase/` for that table. **Net: rows accumulate permanently, and every one is a live budget debit
  for 24h.**

## 4. Redeem-path limits interact, and successes do consume the parent budget

`assertPairingRedeemAllowed` (`rate_limit.ts:14-47`) counts **all** `pairing_attempts` rows with no `success` filter
— `:20-24` by `parent_user_id`, `:34-38` by `code_hash`.

`recordPairingAttempt` inserts on **both** outcomes. Verified `success` values by call site in `pairing/index.ts`:
`false` at `:289` (code fails shape validation), `:301` (no token row for the hash), `:315` (token not active or past
`expires_at`), `:370` (existing request not reusable), `:389` (unique violation on `token_id`, `core.sql:154`);
**`true`** at `:330` (`child_already_linked` — a *refusal* recorded as a success), `:353` (idempotent reuse of an
existing `pending_child` request) and `:401` (normal successful redeem).

So **a correct code entry costs the parent one unit of the 5-per-10-minute budget**, exactly as you suspected. A
parent legitimately pairing five children inside ten minutes is 429-locked by their own success. `:330` additionally
mislabels a refusal as a success, inflating the counter with rows the "count failures" spec would not have billed.

`docs/api-contract.md:308-309` says "5 attempts per parent per 10 minutes and 10 per token; **count failures**."
The implementation counts all attempts. Second divergence between spec and code in the same file.

Interaction with the creation cap is a pincer: once the child is capped the parent cannot get a fresh code to retry
with, so `MAX_ATTEMPTS_PER_TOKEN`'s advice "Ask for a new code" (`rate_limit.ts:43`) becomes unsatisfiable. Empirically
confirmed — `pairing_security.log` `FAIL pairing.unknown_codes_uniform_error {"a":400,"b":429}`: the QA parent hit the
10-minute window while probing.

## 5. Guard order in the create path — limiter is last, auth is before it

Ordered, with lines (`pairing/index.ts` unless noted): 1. OPTIONS preflight `:189` · 2. non-POST→405 `:190-192` ·
3. `readJson` `:194` (512KB + JSON-object validation, `envelope.ts:50-77`, guards `:52`, `:62`, `:73`) ·
4. `requireAction` `:195` (`envelope.ts:79-85`) · 5. `getServiceClient()` `:196` · 6. **`requireUser` w/
`requireVerifiedEmail` `:200`** (`auth.ts:80+`) → 401 · 7. **`requireRole(...,"child")` `:201`** (`auth.ts:129-133`)
→ 403 `role_required` · 8. **`child_already_linked` `:203-217`** → 409 · 9. **`assertPairingCodeCreationAllowed`
`:219`** → 429 · 10. generate+hash+insert `:221-245` · 11. revoke other active `:248-253` · 12. cancel stale
`pending_child` `:256-261` · 13. audit `:263-268` · 14. return `:270-274`.

Answers: the rate limit is checked **strictly after** `child_already_linked` (step 8 before step 9), and **strictly
after** both authentication and role authorization. **An unauthenticated or wrong-role caller never reaches the
limiter.** The prior agent's `requireAction()`-before-`requireUser()` observation is factually true here (`:195`
before `:200`) but is **not a vulnerability and does not affect the limiter**: `requireAction` only validates a JSON
string field and cannot touch `device_pairing_tokens`. The only pre-auth work is bounded JSON parsing (512KB). The
ordering that actually matters — auth before limiter — is correct.

Independently verified against the live log: `pairing_security.log` shows `anon_cannot_create_code → 401
unauthorized`, `parent_cannot_create_code → 403 role_required`, and `create_quota.childC → 409
child_already_linked` while `childA`/`childB` returned `429 rate_limited` — CHILD_C short-circuited at step 8 and
never reached step 9, exactly as the code says it should.

## 6. The 429 gives no retry time

It does not, and it cannot as written.

- Static string, no interpolation — `rate_limit.ts:82-86`. The true unblock time is computable from rows already in
  hand (`max(created_at) + 24h`), but the query selects only `count` with `head: true` (`:76-79`), so it never has
  the timestamps.
- No `Retry-After` header: `ApiError` carries only `code`/`message`/`status` (`envelope.ts:6-16`), and `fail()`
  (`:33-35`) via `json()` (`:18-27`) emits only `Content-Type` + `Cache-Control: no-store`. No header parameter
  exists on the error path.
- The child really reads the server text verbatim: `_errorFromPayload` prefers `map['message']` over its own status
  mapping (`edge_api.dart:111-116`, `:114`); the generic 429 fallback at `:153-154` is unused here.
- It renders as a dismissible red "Action failed" banner (`child_enrollment_page.dart:99-107`) and leaves the button
  tappable (`:189-199`), so the natural response is to press again — rejected at step 9, harmless, but it teaches
  nothing about when to return. "Try again later" at 18:09 functionally means tomorrow.

## 7. Today's exhaustion is fully explained by the QA runs — not a duplicate-submit bug

The app cannot double-submit. `createCode()` early-returns on `isCreatingCode.value`
(`child_enrollment_controller.dart:133-141`) and the button is disabled while loading
(`child_enrollment_page.dart:195-198`). The 15s poll calls `checkRequests` → `pending_child`
(`controller:70-74`), which never mints. `load()` also never mints (`:78-119`).

The decisive artifact is `.tools/live/results/phase1.json` (mtime **2026-10-27 15:44**):

```
{"name":"pairing.A.create","status":"FAIL","detail":{"status":429,"qr":false}}
{"name":"pairing.A.redeem","status":"SKIP","detail":{"reason":"no fresh code"}}
{"name":"pairing.B.create","status":"FAIL","detail":{"status":429}}
{"name":"pairing.B.redeem","status":"SKIP","detail":{"reason":"no fresh code"}}
```

CHILD_A and CHILD_B were **already exhausted at 15:44**, ~2.5h before the 18:09 realme screenshot, so the
Phase-2/3 UI journeys could not have caused it. What did, inside the rolling 24h window that was live at 18:09
(i.e. everything after 2026-10-26 18:09):

| when | source | creates |
|---|---|---|
| 10-26 22:26, 23:11 | `.tools/live/pairing_expiry.mjs:53-58` (`mode === 'create'`), `relink_a.mjs:62` | 2 (childA) |
| 10-27 00:26, 09:39 | `relink_b.mjs:62`, `recover_device_live.mjs:67` | 2 (childB, child) |
| 10-27 15:44 | `.tools/live/verify_live.mjs:96` + `:157` | 2 (A, B) — **already 429** |
| 10-27 ~16:03 | `pairing_security.mjs:16-21` **probe loop** | 3 (A, B, C) |
| 10-27 16:07-16:59 | realme manual taps `039`/`040`/`041`/`066`/`067a`/`067b` | several |

Two aggravators worth naming:

1. **`pairing_security.mjs:17` is a *state probe* with a side effect.** It calls `action: 'create'` purely to learn
   whether quota remains, then labels the result `AVAILABLE`/`BLOCKED` (`:18`) — so every run of the security suite
   spends one real code from each child's daily budget, taxing the fixture it is trying to observe.
2. **`code_capacity.mjs` could not corroborate, and that is itself a finding.** Its log reads
   `{"count":null,"error":"permission denied for table device_pairing_tokens"}` for both families — RLS makes the
   table service-role-only (`rls.sql:74`), so any "capacity" figure produced that way is invalid evidence (already
   flagged at `phase7-backend-security-report.md:98-101`). I did not re-run it and did not query the hosted DB.

Corroborating documentation: `phase7-backend-security-report.md:13` records
`pairing.A.create`/`pairing.B.create` → 429 and 6 checks silently lost because they sit in an `if (freshCode)` block
with no `else`; `:39` and `:58-59` record the expiry/replay positives as BLOCKED by the same cap;
`pairing_blocked_proof.json` and `pairing_security.log`'s `NOT_RUN pairing.parent_attempt_rate_limit_enforced` entry
show the QA agents deliberately avoided triggering the parent window because it would lock out the very parents the
device journey needed. Both caps are re-entrant traps.

## PROPOSAL (not implemented)

### Minimal correct fix

Two separate concerns are currently collapsed into one count; separate them.

**(a) Fix the count filter in `rate_limit.ts:70-88`.** Count only rows that are still *usable*, not all rows:

```ts
.eq("status", "active")
.gt("expires_at", new Date().toISOString())
```

Because `pairing/index.ts:248-253` already revokes every other active token, this count is **at most 1**, so a
threshold of 5 becomes inert. That is not a bug — it is the honest result: the "how many live codes exist" invariant
is already guaranteed by revocation, so a row-count cap can never express it. Which means (a) alone converts the cap
from "self-lockout" to "no-op", and (b) must supply the real throttle.

Note "count only `active` + `redeemed`" (your first option) is **wrong**: `unlink_child` (`functions.sql:398-401`)
leaves `redeemed` rows intact, so a family re-provisioning after a factory reset would be billed for their own past
successes — the same trap with a different label. `consumed` does not exist in the constraint (`core.sql:137`).

**(b) Add a creation cooldown, which is what the cap should have been.** A short rolling mint-rate limit named
`CODE_CREATION_COOLDOWN_SECONDS` (~30s) plus `CODE_CREATIONS_PER_HOUR` (~10, renamed from
`CODE_CREATIONS_PER_24H`, window `3600 * 1000` instead of the inline `24 * 60 * 60 * 1000` at `rate_limit.ts:74`),
counting rows for the child in that hour. Bounded mint spam, still recoverable within an hour instead of a day.
Implement the cooldown with `.order("created_at", {ascending:false}).limit(1)` on the child's rows.

**(c) Do not attempt reuse.** Confirmed impossible: only `code_hash` is persisted (`core.sql:131`) and the plaintext
is returned exactly once (`pairing/index.ts:270-274`). The correct client-side complement is to stop *losing* the
code: persist `linkingCode` in `LocalSettingsService` (it is in-memory `Rxn` today,
`child_enrollment_controller.dart:50`, so a restart silently forces a re-mint and a fresh budget burn) and restore it
on `load()`.

**(d) Add the missing purge as retention, not as a correctness crutch.** New service-role RPC
`private.expire_stale_pairing_tokens()` — `UPDATE device_pairing_tokens SET status='expired' WHERE status='active'
AND expires_at <= now()` — plus `DELETE FROM pairing_attempts WHERE attempted_at < now() - interval '7 days'`, wired
as a third case in `cron/index.ts` and a third entry in the pg_cron bootstrap (`functions.sql:952-967`). This closes
the lazy-expiry gap where `pending_child` (`:440-445`) only expires the *calling* child's rows.

**(e) Make the 429 actionable.** Change the count query to also select `created_at` and return the earliest
slot-recovery time; add a `retry_after_seconds` field to `ApiError` (`envelope.ts:6-16`) and a `Retry-After` header
in `fail()`/`json()` (`:18-35`). Message becomes e.g. "You can create another linking code in 12 minutes."

**(f) Fix the redeem ledger to match `api-contract.md:309`.** Add `.eq("success", false)` to both counts in
`assertPairingRedeemAllowed` (`rate_limit.ts:20-24`, `:34-38`) so successful redeems stop billing the parent, and
change `pairing/index.ts:330` from `true` to `false` — `child_already_linked` is a refusal, not a success.

### Security trade-off

The 24h cap does **not** prevent unauthorized linking, and the brief's threat model should stop assuming it does:

- A code links nothing on its own. Approval is child-initiated and identity-bound: `respond_pairing_request`
  requires `v_request.child_user_id = p_child_user_id` (`functions.sql:215-217`), `status='pending_child'` (`:218`),
  unexpired (`:227`), the token still `active` + unexpired under `FOR UPDATE` (`:231-237`), and the parent still an
  active parent in that family (`:239-247`). A minted code is an *offer* only the child can accept. And only one code
  per child is ever live, because `pairing/index.ts:248-253` revokes predecessors.
- Brute force is already hopeless: 8 chars over a 30-char alphabet ≈ 6.56e11 keyspace (`validation.ts:236-251`,
  uniform via rejection sampling `:239`; recorded as `keyspace: "30^8 ~= 6.5e11"` in `pairing_blocked_proof.json`),
  and per-code guessing is capped by `MAX_ATTEMPTS_PER_TOKEN` (`rate_limit.ts:34-46`). Enumeration is closed too:
  `pairing/index.ts:316-317` answers unknown and expired codes identically (PASS, `pairing_uniform_retry.log`).

So the cap's genuine value is narrow: bounding DB-row growth and mint spam from one compromised child session.
Replacing it with an hourly limit + cooldown keeps that property while removing the self-lockout. The rows doing the
throttling are not security-critical evidence, and `pairing_attempts` — the actual audit ledger — is left completely
untouched by (a), (b) and (d). Net: **the fix does not weaken any control that protects a family.** The one real
regression to watch is that a fast re-mint loop becomes possible again, which the cooldown bounds; if you want a
hard ceiling, keep a generous per-24h limit (e.g. 20) as a backstop.

### Recovery path for a locked-out real family

The brief forbids **deleting rate-limit records**. It does not forbid *updating status*, and this distinction is the
whole recovery path — `device_pairing_tokens` is a domain table, whereas `pairing_attempts` is the rate-limit ledger
that must stay immutable.

1. **Deploy (a).** It is the primary recovery and needs no data touch at all — see next section.
2. **Pre-deploy, for a family locked out today:** a documented service-role operator action —
   `UPDATE device_pairing_tokens SET status='expired', expires_at=now() WHERE child_user_id=$1 AND status='active'
   AND expires_at <= now()`, wrapped in `record_audit`. Under fixed code this is the only lever needed; under current
   code it is useless precisely because the limiter ignores `status` — itself an argument for shipping (a). Deleting
   rows is not required and should be explicitly disallowed.
3. **Never** delete `pairing_attempts`; the parent-side window is only 10 minutes, so waiting is sufficient there
   (and after (f) it will rarely trip).
4. Surface the retry time in-product when the limiter trips (per (e)), so a family has an answer that does not
   involve support.

### Does deployment immediately unblock today's QA children?

**Yes — immediately, with no data migration.** This is the strongest argument for the shape of fix (a).

Walk the state of CHILD_A's rows at 18:09 under the proposed filter:

- Every row except the newest is `revoked` (each mint revokes its predecessors, `:248-253`) → excluded by
  `.eq("status","active")`.
- The newest `active` row has `expires_at = created_at + 10 min` (`:223-225`, `CODE_TTL_MINUTES` at `:36`) and was
  minted hours ago → excluded by `.gt("expires_at", now())`. It is also almost certainly already flipped to
  `expired`, because the setup screen polls `pending_child` on load and every 15s (`child_enrollment_controller.dart:40`,
  `:70-74`; `pairing/index.ts:440-445`), which flips just such rows.
- `redeemed`/`expired` rows → excluded by status.

Resulting count: **0**, against a threshold of 5 → the very next tap returns 200 with a live code. The 24h `created_at`
window never enters the decision, so stale rows stop being debt the instant the filter ships. No backfill, no
DELETE, no per-family operator action, no waiting for the window to roll over.

Under fix (b) alone (hourly window, no status filter) today's QA children would clear within ~60 minutes of their last
mint rather than at an arbitrary tomorrow — unblocking, but not instantly. Under (a)+(b) together, which I recommend,
both properties hold: instant unblock plus a bounded mint rate.

Caveat before shipping: (f) changes redeem accounting, so harness expectations reclassified as passes against today's
behavior (`pairing_window_retry.log`, `pairing_security.log`) need re-running. Phase 3 (pairing negative tests) has
never been completable while these caps are armed — task #13 is still `pending` for exactly this reason.
