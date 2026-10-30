# A4 — Stable child identifier for linking (design memo, read-only audit 2026-10-27)

Scope: design only. No file was modified, no hosted backend touched, no migration authored.
Everything below reuses mechanics that already exist in this repo; each reuse is cited.

Sources read: `supabase/functions/pairing/index.ts`, `_shared/rate_limit.ts`, `_shared/auth.ts`,
`_shared/validation.ts`, `_shared/audit.ts`, `_shared/envelope.ts`, `_shared/enrollment.ts`,
`device-register/index.ts`, `device-telemetry/index.ts`, `cron/index.ts`, `auth-bootstrap/index.ts`,
`supabase/migrations/20260101000000_core.sql`, `...000100_functions.sql`, `...000200_rls.sql`,
`...000300_service_role_grants.sql`, `docs/api-contract.md`, `lib/features/child/*`,
`lib/features/pairing/*`, `lib/data/repositories/supabase_pairing_repository.dart`, `supabase/tests/40_functions.sql`.

---

## 1. Threat model of the CURRENT short-code design

Code space: 8 chars over the 30-char unambiguous alphabet (`validation.ts:12-14`), generated with
rejection sampling so it is uniform, not modulo-biased (`validation.ts:237-251`) => ~6.6e11 candidates.

What the 10-minute TTL (`pairing/index.ts:36`) and single-use actually buy:

| Threat | Protected? | Mechanism |
|---|---|---|
| Shoulder-surfing / photo of the code | Yes, bounded | 10-min TTL; code is only ever rendered inside `child_enrollment_page.dart:208-245` and self-expires |
| Online brute force of one code | Yes | 10 attempts per code_hash / 10 min (`rate_limit.ts:7,40-46`); 6.6e11 space makes random hit probability per attempt ~1.5e-12 |
| Brute force across the whole space | Yes | 5 attempts per parent / 10 min (`rate_limit.ts:6,20-32`); guessing the space costs ~1e9 account-days |
| Replay of a captured code | Yes | `pairing_requests.token_id` is UNIQUE (`core.sql:154-155`) + token flips to `redeemed` (`functions.sql:280-282`); second redeem gets `code_unavailable` (`index.ts:370-371`) |
| Misdirected linking (right code, wrong intent) | Partially | Redemption only creates `pending_child` (`index.ts:375-386`); the child must approve with their own JWT (`index.ts:462-471`, `functions.sql:215-217`) |
| Enumeration (does this code exist?) | Mostly | Unknown (`index.ts:300-303`) and expired/revoked (`index.ts:304-318`) both return the identical `invalid_code` 400 body — the comment at `index.ts:316-317` states the intent, matching `docs/api-contract.md:309-312` |

Residual weaknesses worth recording:
- The expired branch performs an UPDATE before throwing (`index.ts:308-314`), so a *timing/tuning* side
  channel separates "token exists but expired" from "no such token" even though the response body is uniform.
- `child_already_linked` (`index.ts:329-336`) is only reachable with a correct code hash, so it leaks nothing.
- The mint budget is an availability bug, not a control: see §5.
- Nothing sweeps expired tokens/requests server-side (`cron/index.ts:40-50` only expires sessions);
  expiry is applied lazily in `pending_child` (`index.ts:433-446`) and at approval (`functions.sql:227-237`).

Net: the design is sound against a *remote attacker*. Its failure is availability and friction, which is
exactly the owner's complaint.

## 2. Threat model of a naive "parent enters the child's stable ID" design

Concrete failures, in order of likelihood:

1. **Unsolicited requests / harassment of a known ID.** Redemption is already "any authenticated parent,
   any family they own" (`index.ts:277-282`); if the lookup key becomes stable and learnable, the insert at
   `index.ts:375-386` becomes an unbounded write into the child's consent inbox
   (`child_requests_tab.dart:80-103`). Today the *child* decides when a code exists; that implicit inbound
   rate limit disappears and there is no per-child cap anywhere in `rate_limit.ts`.
2. **Consent fatigue -> consent bypass.** Spam trains a minor to tap Approve on the dialog at
   `child_requests_page.dart:156-165`. A link is not cosmetic: it turns on location/usage/app reads for the
   parent (`rls.sql:113-138`), so a coerced approval is a tracking incident for a child.
3. **Enumeration / directory.** A stable ID that resolves to a display name (`index.ts:69-77` decorates
   requests with names) converts into a directory. `profiles_select_self_or_family` (`rls.sql:27-31`) is what
   currently makes a directory impossible for clients, and `docs/api-contract.md:312` explicitly says
   "Do not expose any directory search".
4. **Permanent QR = permanent bearer artifact.** A screenshot of a permanent code forwarded in a group chat
   gives an indefinite path to the child. The current QR (`index.ts:270-274`) self-destructs in 10 minutes;
   a stable ID has no such property, so the *only* surviving control must be the child's approval.
5. **Cross-family pre-emption / lock-out-by-priority.** Without a "one pending per (child, family)" rule, an
   attacker can occupy the child's inbox so the real guardian's request is buried; the unique `token_id`
   (`core.sql:154`) accidentally prevents this today (one request per token) and must be replaced explicitly.
6. **Escalation with a buggy approval gate.** `functions.sql:231-237` requires an active, unexpired
   `device_pairing_tokens` row before approval. A naive port drops the token concept and, in doing so, often
   drops this check too — losing the "expired request cannot be approved" invariant rather than moving it.
7. **ID == auth UUID.** Using `profiles.id` (`core.sql:17-25`) as the entered value makes the primary key of
   a minor's account public, unrotatable, and correlatable across families/backups. Rejected outright.
8. **Revocation asymmetry.** Unlink already nulls device credentials and ends sessions
   (`functions.sql:379-406`); if the stable ID were also an authorization source it would have to be revoked
   too, and "stable" would be a lie. Decoupling these is the whole design goal.

## 3. Recommended design

The hypothesis in the brief is correct in shape and I keep it, with three refinements: (a) the identifier must
be a **separate opaque handle, not the UUID, and not a token row**; (b) the mint/revoke machinery must be
removed from the critical path entirely rather than made reusable; (c) an explicit per-**child** inbound cap
is mandatory — it is the control the unguessable code was silently providing.

**Recommended: Alternative A — stable child contact handle + consent-gated invite.**

1. **Handle issuance.** New service-role-only table `child_contact_ids(child_user_id uuid pk, handle_hash text
   unique check hex64, rotated_at, created_at)` — same "RLS enabled, zero policies, zero grants" posture as
   `device_pairing_tokens` / `pairing_attempts` (`rls.sql:9,22,74,242`, `rls.sql:286`). Handle = 12 chars from
   the existing alphabet (`validation.ts:12`), hashed with `sha256Hex` (`validation.ts:253-258`) and looked up
   by hash exactly like `index.ts:285,293-297`. 12 vs 8 chars means the two spaces can never collide and the
   server can route by length; the existing client input regex already accepts 8-12 chars
   (`lib/core/utils/validators.dart:5`), so a new handle typed into an old app fails safely as `invalid_code`.
   Lazy generation on first read (no backfill migration), triggered from `set_role`-style flows
   (`auth-bootstrap/index.ts:32-65`).
2. **Child UI.** `get_contact_id` (child JWT, `requireUser` + `requireRole`, `index.ts:200-201` pattern)
   returns `{contact_id, qr_payload: "parentcontrol://pair?id=<handle>&v=2", rotated_at}`. Read-only: it
   creates nothing, so it needs no rate budget — this is what removes the lockout. Keep the current
   `v=1` code path and QR parser untouched (`pairing_qr_payload.dart:12-32` strictly rejects unknown versions,
   so an old parent app cannot act on a new QR).
3. **Parent initiation.** New `invite` action: parent JWT (`index.ts:278`), role parent (`index.ts:279`),
   `assertFamilyParent` on the chosen family (`index.ts:281-282` / `auth.ts:194-205`), format-check then
   hash-lookup the handle (`index.ts:284-291` pattern), and insert **only** a `pairing_requests` row with
   `status='pending_child'` (`index.ts:375-386`, status enum already includes it at `core.sql:159-160`) and
   `expires_at = now + 24h`. Response reuses `redeemPayload` (`index.ts:121-151`) so the parent screen works
   unchanged, including its honest copy "Nothing is linked yet" (`pairing_redeem_page.dart:237-246`).
   Audit `pairing_invite_created` via `recordAudit` (`audit.ts:16-37`); the event-type column is length-checked
   only (`functions.sql:25-27`, `core.sql:380`), so new event names need no schema change.
4. **Consent.** Unchanged: `pending_child` listing + lazy expiry (`index.ts:428-460`), and `respond` ->
   `public.respond_pairing_request` (`index.ts:462-477`, `functions.sql:735-746`) with child-ownership
   re-check (`functions.sql:215-217`), status guard + idempotent replay (`functions.sql:218-226`), expiry guard
   (`functions.sql:227-229`), parent-still-active guard (`functions.sql:239-247`) and the one-active-family
   re-check (`functions.sql:250-257` + `core.sql:69-71`). The single SQL change: the token requirement
   (`functions.sql:231-237`) becomes conditional — token present => must be active and unexpired (legacy
   path); token absent => the request must be a non-expired invite (§4 I4/I6). Child consent copy
   (`child_enrollment_page.dart:182-187`) only needs the "your guardian enters your linking ID" sentence.
5. **The durable object stays the relationship, not the identifier.** Membership is written only by the
   service role (`family_members` has a SELECT policy and SELECT-only grants for `authenticated`,
   `rls.sql:59-63,256`); runtime authority is the device credential, `x-device-id`/`x-device-secret` with
   constant-time SHA-256 comparison and the decoy compare for unknown ids (`auth.ts:281-337`), enforced per
   action in `device-telemetry/index.ts:69,158,240,358`, and minted only by the child's own JWT plus active
   membership (`device-register/index.ts:118-141`, 64-hex hash at `:123`, secret never returned `:44-49`).
   Revocation path and the re-enrollment gate are untouched (`functions.sql:375-406`,
   `device-register/index.ts:53-102`, `enrollment.ts:1-13`).
6. **Optional hardening (not authorization):** the invite response carries a 4-char "verification phrase"
   also shown on the child's request card, so the child can match the person standing in front of them. It is
   display-only and never required by `respond`, so it cannot become a second secret.

Alternatives considered:

| | A. handle + invite (chosen) | B. long-lived reusable pairing handle in `device_pairing_tokens` | C. static family contact code + out-of-band confirm |
|---|---|---|---|
| ID is only an identifier | Yes — no access grant | No: a permanent `status='active'` token is a live credential and would need the "revoke previous active tokens" logic (`index.ts:248-254`) to stay coherent | No: a shared static code authorizes initiation => a real secret |
| Needs minting | Never | Once per redeem (reuses the broken budget) | Never |
| Reusable | Yes (multiple families/children, many requests) | Blocked by `token_id UNIQUE` (`core.sql:154`) — making it reusable means deleting the anti-replay guard at `index.ts:338-372` | Yes |
| Screenshot risk | Low: leak => spam only, capped and consent-gated | High: leak => indefinite live token | High: leak => anyone in the chat can initiate |
| Rotation cost | Free, inert for existing links (`core.sql:116-119` unaffected) | Must revoke tokens, which `unlink_child` already does (`functions.sql:398-401`) => breaks "stable" | Rotating breaks every saved contact |
| Infra needed | None | None | Needs a notification channel that does not exist in `supabase/functions/` (only auth e-mail) |

B is rejected because it makes the permanent identifier *also* a live credential — precisely what the owner
forbade — and it sacrifices the replay guard. C is rejected for missing infrastructure and for being a shared
secret; its useful half (out-of-band confirmation) is folded into A as display-only.

## 4. Server-enforced invariants (each phrased for a test)

- **I1 A request grants zero data access.** After `invite` and before approval, a parent-RLS SELECT on
  `location_events`/`usage_daily`/`device_apps`/`devices` for that child returns 0 rows and
  `private.shares_active_family(child)` is false (`core.sql:608-626`, `rls.sql:113-138`).
- **I2 No client can create membership.** `family_members` is INSERT-impossible for `authenticated`
  (SELECT-only grant, `rls.sql:256`); only `private.respond_pairing_request` creates a child membership.
- **I3 Approval requires the child's own JWT.** `respond` derives `p_child_user_id` from `auth.user.id`
  (`index.ts:469-470`), never the body, and the RPC re-checks it (`functions.sql:215-217`). A parent JWT on
  that request id => `forbidden`.
- **I4 Nothing is approvable past expiry.** Approve with `expires_at <= now()` => `code_expired`
  (`functions.sql:227-229`); invite TTL 24h, legacy token TTL unchanged.
- **I5 One active family per child.** Concurrent approvals from two families yield exactly one active
  `family_members` row: enforced by `core.sql:69-71` + `functions.sql:250-257` + the `unique_violation`
  mapping at `functions.sql:316-318`.
- **I6 At most one actionable invite per (child, family).** New partial unique on
  `(child_user_id, family_id) where status='pending_child'`; a duplicate invite returns the existing request
  (mirror the idempotent branch `index.ts:346-369`) and consumes no additional quota.
- **I7 No directory, no state oracle.** Unknown handle, handle of a non-child, and handle of a child already
  linked to another family all return the byte-identical `contact_unavailable` body (same intent as
  `index.ts:316-317`, `docs/api-contract.md:309-312`); no authenticated grant on `child_contact_ids`
  (same posture as `rls.sql:74,242,286`); `profiles_select_self_or_family` unchanged (`rls.sql:27-31`).
- **I8 Every initiation attempt is recorded, fail-closed.** One `pairing_attempts` row per invite (success
  and failure), insert failure aborts the request as `internal_error` (`rate_limit.ts:49-68`).
- **I9 Revocation invalidates the device credential in the same transaction.** After `unlink`,
  `secret_hash is null`, `credential_revoked_at` set (`functions.sql:379-386`), sessions ended (`:388-396`),
  active tokens revoked (`:398-401`), pending requests cancelled (`:403-406`), and a subsequent
  `requireDevice` call fails `device_revoked`/`invalid_device_credentials` (`auth.ts:322-335`).
- **I10 The handle is not an authorization source.** Rotating it changes no membership, no device row, no
  policy; already-issued invites keep their own stored snapshot; approval of an invite created from a retired
  handle still works until its TTL (so rotation cannot be used to silently kill a consent the child already
  gave — nor to resurrect an expired one).
- **I11 Approval checks the parent is still an active parent of that family** at approve time
  (`functions.sql:239-247`).
- **I12 Inbound flood is capped per child, per family and per parent** (§5), server-side only.
- **I13 Length-based routing is total.** 8 chars => token path only, 12 chars => handle path only; anything
  else is the same uniform `invalid_code` as today (`index.ts:288-291`), so neither path becomes an oracle
  for the other.
- **I14 Every state transition is audited** with family/actor/target ids, and an audit insert failure aborts
  the action (`audit.ts:29-37`); `audit_logs` remains append-only for non-service roles (`core.sql:543-565`).
- **I15 Device enrollment is never implicit.** A link alone produces no `devices` row; enrollment still
  requires the child's JWT, active membership, a client-supplied 64-hex secret hash and the re-enrollment gate
  (`device-register/index.ts:141-141,123,174-212`).

## 5. Rate-limit redesign

Today's counting bugs (all in `rate_limit.ts` + call sites in `pairing/index.ts`):

| # | Bug | Effect |
|---|---|---|
| 1 | `assertPairingCodeCreationAllowed` counts **every** token row created in 24h regardless of status (`rate_limit.ts:74-88`) — including rows the same call immediately revokes (`index.ts:248-254`) and rows that expired unused | 5 mints/day burns on retries => the reported lockout |
| 2 | `create` cancels the child's in-flight `pending_child` requests (`index.ts:256-261`) | retrying a code silently destroys a live request: double lockout |
| 3 | Redeem cap counts **successful** redemptions (`index.ts:353,401` feed `rate_limit.ts:20-32`) | a parent linking a 6th child in one session gets 429 |
| 4 | The cap is checked before format validation (`index.ts:286` before `:288`) | typos and paste noise consume budget |
| 5 | No per-child inbound limit exists anywhere | safe only because codes are unguessable; with stable IDs it is the primary gap |
| 6 | 429 messages say "Try again later" with no reset (`rate_limit.ts:83-86`, `:27-31`, `:41-45`) | support tickets, repeated retries |

Proposed replacement (`rate_limit.ts` gains `assertInviteAllowed`; `pairing_attempts` gains nullable
`child_user_id`, `family_id`, `kind`, `reason`; `code_hash` stays NOT NULL by storing `handle_hash` in it, so
`core.sql:417` is untouched):

- **Failed lookups** (brute-force control): 10 per parent per 10 min; 3 per parent per (handle, hour).
  Successes do **not** count here — fixes bug 3.
- **Invite successes (abuse control)**: per family 5 concurrent pending + 20 per rolling 24h; **per target
  child 3 concurrent pending + 10 per rolling 24h across all parents + 4 distinct parents per 24h** — the new
  invariant I12 that makes a public identifier survivable.
- **Child-side reads** (`get_contact_id`): unlimited (pure read, no row created) — this is the lockout fix.
  **Rotations**: 3 per child per 24h.
- **Legacy code minting**: keep, but (a) count only rows whose status is `active` or `redeemed` in the window,
  (b) rotate in place (UPDATE `code_hash`/`expires_at` on the child's single active row) instead of INSERT, so
  a retry is not a new creation, and (c) raise the cap to 20/24h so old clients can never be locked out.
  Remove the "cancel all pending requests" side effect at `index.ts:256-261` and replace it with "cancel only
  requests whose token you just replaced".
- **Reset disclosure**: every 429 carries `retry_after_seconds` and `resets_at` (ISO), plus human text ("Try
  again at 18:40"). Needs one additive change: `fail()` in `envelope.ts:33-35` accepts an optional details
  object merged into the error body. `code`/`message` stay as-is, so the Flutter error mapping
  (`supabase_pairing_repository.dart:207-213`) and every existing client keep working.
- **Anti-timing**: keep the uniform body *and* avoid the pre-throw UPDATE on the miss path (removes the
  side channel noted in §1) by deferring status writes to the lazy sweep (`index.ts:433-446`).

## 6. Migration and rollout safety

Must remain backward compatible: `create`/`redeem`/`pending_child`/`respond`/`cancel`/`list_family`/`unlink`
and the `v=1` QR payload (`docs/api-contract.md:300-325`). Actions are additive; an old client cannot reach a
new code path because unknown actions 400 (`index.ts:591-592`).

Schema deltas a future migration must carry (none written here): `child_contact_ids` with RLS enabled and no
policies (copy the `rls.sql:9,74,242` posture; service grants are automatic per
`20260101000300_service_role_grants.sql:14-17`); `pairing_requests.token_id` relaxed to NULL plus nullable
`contact_id`; the two partial unique indexes for I6 and the pending-count caps; the conditional token branch
in `private.respond_pairing_request`; optional `details` in the error envelope. All are additive or relaxing,
so every pre-existing request row (which always has a `token_id`) still approves normally.

Order that cannot produce a "nobody can link" state:
1. Deploy SQL (additive; no behavior change until a function uses it).
2. Deploy Edge Functions: `get_contact_id` + `invite` added; `create`/`redeem` byte-for-byte unchanged.
   Pre-approve legacy `pending_child` rows must remain approvable — verify the branch order in the RPC.
3. Ship the child build that displays the handle; the "Create linking code" button
   (`child_enrollment_page.dart:189-199`) stays for one release cycle.
4. Ship the parent build with the ID field/scanner; `pairing_qr_payload.dart:12-32` gains a `v=2 id=` branch
   while `v=1 code=` stays, and an unknown version still parses to null so the parent falls back to typing.

Kill switch: `Deno.env` flag read like `SUPABASE_URL` at `auth.ts:51-53`; with it off, `invite` returns
`feature_disabled` 503 and `get_contact_id` reports disabled so the child UI hides the ID. Rollback is safe
because invite rows are a new row type; guard the NULL-`token_id` insert behind the same flag so disabling
also stops new NULL-token rows from being created. Handles are generated lazily, so no backfill job (and no
window where an unmigrated child cannot link). Never delete or expire the `v=1` path while any installed APK
still depends on it — the field builds are listed in `.tools/evidence/full-qa/phase7-full-qa-20261027`.

## 7. Test matrix

SQL-level assertions in the `supabase/tests/40_functions.sql` style (existing pairing consent block at
`:191-260`, revoke-cancels-pending block at `:405-447`); wire-level assertions via the
`.tools/evidence/full-qa/phase7-full-qa-20261027/pairing_security.mjs` harness pattern.

| ID | Case | Assertion |
|---|---|---|
| T1 | invite with valid handle, child unlinked | 1 `pending_child` row, `token_id is null`, `expires_at ≈ +24h`, audit `pairing_invite_created`, zero membership rows (I1/I6) |
| T2 | child approves via own JWT | membership active, request `approved`, audit `pairing_approved`; mirrors `functions.sql:276-294` |
| T3 | parent JWT calls `respond` on that request | `forbidden` (I3) |
| T4 | approve after expiry | `code_expired`, no membership (I4) |
| T5 | request grants zero data | parent-RLS SELECTs on location/usage/apps/devices => 0 rows pre-approval (I1) |
| T6 | two parents invite the same child, both approve | exactly one active child membership (I5, `core.sql:69-71`) |
| T7 | invite a child already in another family | `contact_unavailable`, 0 rows written; cross-family isolation |
| T8 | invite a child already in **my** family | same uniform `contact_unavailable` body as T7 (no state oracle, I7) |
| T9 | enumeration: unknown / parent-role / child-role / deleted-profile handles | byte-identical error body, identical HTTP status, no differing row counts visible to the caller (I7) |
| T10 | replay: re-run the same invite twice | second call returns the existing pending request and no extra quota use (I6) |
| T11 | approve twice | idempotent `approved` echo; third with `approve=false` => `request_already_responded` (`functions.sql:218-226`) |
| T12 | length routing | 8-char string on `invite` and 12-char on `redeem` both => `invalid_code` (I13) |
| T13 | legacy `v=1` flow end-to-end | unchanged: `create` => `redeem` => `respond` => `device-register` succeeds (regression gate) |
| T14 | flood from 50 parent accounts on one child | child caps hold (<=3 pending, <=10/24h); 429 body contains `retry_after_seconds` + `resets_at` (I12, §5) |
| T15 | 10 failed lookups by one parent | 11th attempt 429; a **successful** invite never counted toward that cap (bug 3 fixed) |
| T16 | unlink after invite-approved | same transaction revokes credential (`secret_hash is null`) and ends sessions; next `requireDevice` fails (I9, `functions.sql:379-406`, `auth.ts:329-335`) |
| T17 | handle rotation | existing membership, device, policy_version untouched; retired handle's pending invite still approvable until TTL; new handle works (I10) |
| T18 | revoked-device re-enrollment after a handle-based link | still blocked until parent removes child + later approval (`device-register/index.ts:53-102`, `enrollment.ts:1-13`) |
| T19 | audit immutability | non-service UPDATE/DELETE on `audit_logs` => 42501 (`core.sql:543-565`); audit insert failure aborts invite (I14) |
| T20 | kill switch off | `invite` 503 `feature_disabled`; `create`/`redeem` still succeed (rollout safety) |
| T21 | parent removed from family mid-flight | approval => `request_unavailable` (I11, `functions.sql:239-247`) |
| T22 | QR `v=2` payload against the v1 parser | rejected (null) by old client, parsed by new one; `v=1` unaffected (`pairing_qr_payload.dart:12-32`) |

---
Bottom line: keep `pairing_requests`/`family_members`/device credentials as the only sources of authority; add
a stable 12-char handle whose sole capability is creating an expiring, capped, child-approved `pending_child`
request; delete the mint budget from the child's critical path entirely.
