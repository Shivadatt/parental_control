# Read-only audit — child identifiers, linking-code rate limit, two-device status

**Date:** 2026-10-27 · **Mode:** audit-only · **Repo:** `D:\parentcontrol_app` @ `b3f1e20`
**Governing brief:** "READ-ONLY AUDIT, CHILD ID WORKFLOW AND TWO-DEVICE TESTING — STRICT RULE: NO CODE CHANGES"

Evidence files for this audit: [`.tools/evidence/full-qa/read-only-audit-20261027/`](../.tools/evidence/full-qa/read-only-audit-20261027)
(`A1-server-ratelimit.md`, `A2-client-ui.md`, `A3-identifiers.md`, `A4-security-design.md`,
`A5-live-matrix.md`, `A6-local-repro.md`, `scratch/`, screenshots).

---

## 0. Scope statement and honest disclosures

**0.1 — Nothing in this audit turn changed code, schema, config or hosted state.**
No migration was created or applied. No Edge Function was deployed. No hosted Supabase
instance was queried or written. No `pm grant`/`pm revoke`, no force-stop, no reboot, no
factory reset, no data clear, no unlink of a real device. The rate-limit fix in §9 is
**proposed, not applied** — verified below.

```
$ git diff HEAD --stat -- supabase/functions/_shared/rate_limit.ts supabase/functions/pairing/index.ts
(empty — server-side pairing code is byte-identical to HEAD)
```

**0.2 — Disclosure: three client files were edited in *earlier, separately authorized*
turns of this same session, before this brief was issued.** They are already in the
working tree and are *not* products of this audit. They are listed here because this
brief's framing ("no code changes") would otherwise be misleading about the state of the
tree:

| File | Change | Authorized in |
|---|---|---|
| [lib/features/role_selection/role_selection_page.dart:140](file:///D:/parentcontrol_app/lib/features/role_selection/role_selection_page.dart#L140) | Removed the duplicated "mode" ("Parent Mode mode." → "Parent Mode.") | Phase-2 UI-journey turn |
| [lib/features/pairing/pairing_redeem_page.dart:446](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L446), [:527](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L527) | Wrapped the scanner in `ValueListenableBuilder<MobileScannerState>` and hid the viewfinder caption when `errorBuilder` is showing | Phase-2 UI-journey turn |
| [lib/features/child/widgets/media_self_test_sheet.dart:307-308](file:///D:/parentcontrol_app/lib/features/child/widgets/media_self_test_sheet.dart#L307) | "Recording — Off — preview only" → "Recording — Not available in this app" (BUG-030) | Phase-6B recording audit |

The working tree also carries staged changes from the earlier Phase 6B / Phase 7 work
(docs, integration tests, device-recovery migration, remote-assistance files). None of
them were touched by this audit.

**0.3 — Disclosure: both devices were rebuilt and reinstalled during this session**
(split APKs built 17:17, installed 17:21; emulator `lastUpdateTime 2026-10-27 17:21:34`
v4001, realme `17:21:22` v2001). This was done by an earlier QA turn, not by this
read-only pass. Consequence: the installed builds **do** contain the three fixes above.

**0.4 — Corrections to sub-agent claims.** Six agents were dispatched. Two of their
findings were wrong and I disproved them directly:

- **A5 §5 items 8–9 were false.** A5 reported the "Camera and microphone test" card is
  "absent from the installed v2001 build". It is present. The card is inserted
  unconditionally at [child_settings_tab.dart:56](file:///D:/parentcontrol_app/lib/features/child/tabs/child_settings_tab.dart#L56)
  (`_mediaTestCard(context)`, no link-state or capability gate), `ChildShellPage` applies
  no gating, and I captured it live on the realme at 19:02:
  [`manual-realmesettings-top.png`](file:///D:/parentcontrol_app/.tools/evidence/full-qa/read-only-audit-20261027/manual-realmesettings-top.png)
  shows the card, its "Test camera and microphone" button, and the permissions card with
  Camera / Microphone / Notifications / Device admin all "Granted". A5 had scrolled past
  it. Items 8–9 remain **NOT TESTED** — but for the reason in §7.4 (I did not tap the
  button, per "do not silently activate media capture"), not because the UI is missing.
- **A5 §4 item 2's "caption expected missing" note is moot.** The caption *is* visible on
  the emulator because its camera opens successfully; my change only suppresses it when
  `errorBuilder` is rendering. Both observations are consistent.
- **My own earlier claim that a `'consumed'` token status exists was wrong**, and A1 +
  A6's live catalog query corrected it: the check constraint admits exactly
  `active | redeemed | revoked | expired`
  ([core.sql:136-137](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L136));
  inserting `'consumed'` raises SQLSTATE 23514. Any fix must not count on it.
- **My earlier claim that `requiresRelink()` exists was wrong** — A2 grepped `lib/` and
  found no such symbol. The real trap is `request_device_recovery` → `private.unlink_child`
  plus the `status='active'` filters.

---

## 1. Identifier catalogue

Full detail with per-identifier evidence: [`A3-identifiers.md`](file:///D:/parentcontrol_app/.tools/evidence/full-qa/read-only-audit-20261027/A3-identifiers.md)

| Identifier | Names | Where generated | Stable across reinstall / sign-out / device loss? | Secret? | Can it authorize anything alone? |
|---|---|---|---|---|---|
| `auth.users.id` = `profiles.id` | one **human** account (parent or child) | GoTrue, server-side at signup; mirrored by trigger `private.handle_new_user` ([core.sql:456-486](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L456)) | **Yes** — UUID v4, PK, immutability enforced by trigger ([core.sql:491-499](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L491)) | No (semi-private; never rendered in UI) | No — needs a Bearer JWT re-verified by `db.auth.getUser()` ([auth.ts:80-127](file:///D:/parentcontrol_app/supabase/functions/_shared/auth.ts#L80)) |
| `families.id` | a family | `private.create_family_with_owner` ([functions.sql:44-81](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L44)) | Yes while the row exists | No | No — `assertFamilyParent` re-derives |
| `family_members.id` | a **relationship** | service role only ([functions.sql:67](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L67), [:272](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L272)) | Yes | No | No — SELECT-only grant to clients ([rls.sql:256](file:///D:/parentcontrol_app/supabase/migrations/20260101000200_rls.sql#L256)) |
| `devices.id` | a **server-side device record** | `device-register` INSERT ([device-register/index.ts:214-223](file:///D:/parentcontrol_app/supabase/functions/device-register/index.ts#L214)) | No — dies with `unlink_child` / `revoke_device` | No (visible inside family) | No — `x-device-id` is one of **two** required headers ([auth.ts:281-300](file:///D:/parentcontrol_app/supabase/functions/_shared/auth.ts#L281)) |
| `devices.installation_id` | an **app install** | client, `UUID.randomUUID()`, persisted in EncryptedSharedPreferences ([SecureStore.kt:85-91](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt#L85)) | **No** — app-private, `allowBackup="false"` ([AndroidManifest.xml:40](file:///D:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L40)) | No — service-only column, stripped from responses | No — an upsert key scoped by family ([core.sql:111](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L111)) |
| `x-device-secret` → `devices.secret_hash` | the **device credential** | 32 bytes `SecureRandom`, base64url, ~256 bit ([SecureStore.kt:93-104](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt#L93)); hashed on the phone, SHA-256 hex server-stored | Rotated on every re-register; nulled on revoke | **Yes** | Yes, *in combination with* `x-device-id` — constant-time compare + `status='active'` + `credential_revoked_at is null` ([auth.ts:312-335](file:///D:/parentcontrol_app/supabase/functions/_shared/auth.ts#L312)) |
| **8-char pairing code** | a **10-minute offer** | server, rejection-sampled over a 30-char alphabet ([validation.ts:237-251](file:///D:/parentcontrol_app/supabase/functions/_shared/validation.ts#L237)) ≈ 39.5 bit | **No** — TTL 600 s ([pairing/index.ts:36](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L36)), single-use | **Yes** — plaintext exists once, in the response; never stored | No — redeem only creates a `pending_child` row; the child must still approve |
| `device_pairing_tokens.id` | a **code instance** (not a child, not a device) | `pairing/index.ts:227-237` | No | No — service-role-only table, zero policies/grants ([rls.sql:74](file:///D:/parentcontrol_app/supabase/migrations/20260101000200_rls.sql#L74)) | No |
| `code_hash` | SHA-256 of the normalized code | `pairing/index.ts:222` | No | Derived secret; UNIQUE ([core.sql:131-132](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L131)) | No |
| `pairing_requests.id` | an **approval pending** | parent's redeem INSERT ([pairing/index.ts:375-386](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L375)) | Until resolved/expired | No | No — `respond` requires `child_user_id = auth.uid()` ([functions.sql:215-217](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L215)) |
| `remote_sessions.id`, `session_nonce` | a **live assistance session** | `remote-session` action `request` / `crypto.randomUUID()` at `:189` | No | No | No |
| `webrtc_signals.id` + `sequence` | one **signal envelope** | DB ([core.sql:359-367](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L359)) | No | No | No — RLS requires live session + participant + self-authored ([rls.sql:202-231](file:///D:/parentcontrol_app/supabase/migrations/20260101000200_rls.sql#L202)) |
| `device_commands.idempotency_key` | a **retry dedupe key** | client UUID v4 | No | No | No |
| `audit_logs.target_id` | free-text pointer (≤128 chars, no FK) ([core.sql:381-382](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L381)) | various | n/a | **Parent-visible** — every family parent can read audit logs ([rls.sql:236-240](file:///D:/parentcontrol_app/supabase/migrations/20260101000200_rls.sql#L236)) | No |

**Interchangeability — disproved, not assumed.** A code cannot be used as a device id (the
redeem path accepts only `{code, family_id}` and never touches `devices`); a `devices.id`
cannot authorize a user action; an `installation_id` authorizes nothing at all. User
identity always comes from the JWT, device identity always from the two headers. Notably,
`device_pairing_tokens` has **no device column whatsoever**
([core.sql:128-142](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L128))
— a linking code is bound to a *person*, never to a *phone*.

---

## 2. Current pairing workflow (as implemented)

```
 CHILD (realme)                                  SERVER (Edge/Postgres)                      PARENT (emulator)
 ─────────────                                   ──────────────────────                      ─────────────────
 1. "Set up this phone"
    tap "Create linking code" ────────────────▶  pairing.create
                                                 ├ requireUser + verified email   :200
                                                 ├ requireRole("child")           :201
                                                 ├ child_already_linked?  409     :203-217
                                                 ├ assertPairingCodeCreationAllowed  :219   ◀── 429 fires HERE
                                                 ├ generatePairingCode() 8 chars  :221
                                                 ├ INSERT device_pairing_tokens   :227-237
                                                 ├ UPDATE …status='revoked' on
                                                 │   every OTHER active token     :248-253   ◀── the row it counts against itself
                                                 ├ CANCEL pending_child requests  :256-261   ◀── destroys a live request
                                                 └ return {code, qr_payload, expires_at}  ◀── plaintext returned ONCE, never stored
    shows code + QR (memory only,               "parentcontrol://pair?code=XXXXXXXX&v=1"
    lost on process kill)  ──────────────────────────────────────────────────────────────────────────────────▶ 2. "Link a child"
                                                                                                                   type code / scan QR
                                                                                                                   pairing.redeem
                                                                                                                   ├ assertPairingRedeemAllowed  :286  ◀── counts SUCCESSES
                                                                                                                   ├ hash → token → child_user_id
                                                                                                                   ├ child_already_linked? 409
                                                                                                                   └ INSERT pairing_requests
                                                                     pending_child  ◀── status='pending_child'  :375-386
                                                                     (token flips to 'redeemed' ONLY on approval)
 3. 15 s poll pending_child  ◀──────────────────────────────────────────────────────────────────────────────────  "Nothing is linked yet"
    sees family name + parent display name
    Approve / Decline
    pairing.respond ─────────────────────────▶ respond_pairing_request
                                                ├ child_user_id = auth.uid()    functions.sql:215
                                                ├ token active + unexpired      functions.sql:231-237
                                                ├ parent still active parent    functions.sql:239-247
                                                ├ INSERT family_members(child)  functions.sql:272
                                                └ token → 'redeemed'            functions.sql:280
                                                                     200 {status:'approved', family_id}  ───▶ 4. parent sees the child
 5. tap "Register this device" ──────────────▶  device-register
                                                ├ requires ACTIVE child membership  :141
                                                ├ child identity from JWT, NOT body :218
                                                └ INSERT/UPSERT devices + secret_hash (SHA-256 of phone-generated secret)
 6. from now on: x-device-id + x-device-secret headers on every telemetry call
```

**The three properties the brief asked about already hold:**
- The child approves. Nothing links on the parent's action alone.
- "No family can attach this account without your approval" is real copy *and* real code
  ([child_enrollment_page.dart:307-316](file:///D:/parentcontrol_app/lib/features/child/child_enrollment_page.dart#L307),
  [functions.sql:215-217](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L215)).
- The parent's screen explicitly disclaims self-approval
  ([pairing_redeem_page.dart:204-209](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L204)).

**What does not hold:** step 1 is mandatory, ephemeral, and metered. The child must mint a
fresh 10-minute secret every single time a link is (re)started.

---

## 3. Exact cause of the linking-code rate-limit error

**Symptom (reproduced live on the realme at 18:09 and again at 19:02):**
`Action failed — You have created too many linking codes today. Try again later.`
(`A5-09_child_state.png`, `A5-00_realme_baseline.png`)

### 3.1 The defect, in one sentence

The limiter counts every token row the child created in the last 24 hours — **including
the rows that the very same request immediately revokes** — so the child's own normal
"create a code" happy path burns the entire daily budget.

### 3.2 Source references

[supabase/functions/_shared/rate_limit.ts:70-88](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L70)

```ts
export async function assertPairingCodeCreationAllowed(db, childUserId) {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();  // :74  window hardcoded
  const result = await db
    .from("device_pairing_tokens")
    .select("id", { count: "exact", head: true })
    .eq("child_user_id", childUserId)
    .gte("created_at", since);                    // ← :78  ONLY predicate. no .eq("status", …), no .gt("expires_at", …)
  if ((result.count ?? 0) >= CODE_CREATIONS_PER_24H) {   // :81  CODE_CREATIONS_PER_24H = 5  (:8)
    throw new ApiError("rate_limited",
      "You have created too many linking codes today. Try again later.", 429);   // :82-86
  }
}
```

[supabase/functions/pairing/index.ts:219-253](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L219) — the create path calls that check at `:219`, then
**unconditionally** INSERTs a new row at `:227-237`, then at `:248-253` sets
`status='revoked'` on every other active token for the same child. So each press leaves
behind exactly one dead, still-counted row.

### 3.3 The spec says the code is wrong

[docs/api-contract.md:303](file:///D:/parentcontrol_app/docs/api-contract.md#L303):

> Max 5 **active** code creations per 24h.

The word *active* is in the contract and absent from the implementation. This is a
spec/implementation divergence, not a designed policy. Same file, same class of bug,
second instance: [docs/api-contract.md:309](file:///D:/parentcontrol_app/docs/api-contract.md#L309)
says "5 attempts per parent per 10 minutes and 10 per token; **count failures**" — and
`assertPairingRedeemAllowed` counts *all* attempts (§3.6).

### 3.4 Nothing ages the rows out

- No purge exists. `cron/index.ts` has exactly two cases (`expire_sessions`,
  `detect_offline`); the pg_cron bootstrap ([functions.sql:952-967](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L952))
  schedules only those two, and neither touches pairing tables.
- `family-admin` `purge_data` ([family-admin/index.ts:187-199](file:///D:/parentcontrol_app/supabase/functions/family-admin/index.ts#L187))
  deletes only `location_events` and `usage_daily`.
- `unlink_child` ([functions.sql:398-401](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L398))
  **UPDATEs** active tokens to `revoked`; it never DELETEs. Unlinking a child to let them
  re-pair therefore *keeps* their old rows in the budget.
- `pairing_attempts` is append-only ([rate_limit.ts:49-68](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L49)).
- `status` is only flipped to `'expired'` opportunistically — at redeem
  ([pairing/index.ts:308-313](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L308))
  and on the child's poll (`:440-445`). A6 seeded a token 400 days in the past, ran both
  maintenance RPCs, and it was **still `status='active'`**.

### 3.5 Empirically proven, not inferred

A6 replayed the real create sequence against a throwaway PostgreSQL 16.9 on
`127.0.0.1:55432` (no hosted connection), with the shipped count and the proposed count
side by side:

| scenario | row mix | shipped count | proposed count | shipped verdict | proposed verdict |
|---|---|---|---|---|---|
| A | 4 revoked + 1 active (5 real creates) | **5** | 1 | 429 | allowed |
| B | 5 revoked (unlinked/re-linked child) | **5** | 0 | 429 | allowed |
| C | 1 redeemed + 2 expired + 2 revoked | **5** | 0 | 429 | allowed |
| D | 5 active rows past TTL (stale) | **5** | 0 | 429 | allowed |
| E | control: 1 live active token | 1 | 1 | allowed | allowed |

Scenario D is the reason `expires_at > now()` is load-bearing and `status='active'` alone
is not enough. Scenario E is the reason the fix does not weaken the control against real
spam.

### 3.6 Second, independent bug on the redeem side

[rate_limit.ts:14-47](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L14)
counts `pairing_attempts` with **no `success` predicate**, and `recordPairingAttempt`
inserts on both outcomes — including `success = true` at
[pairing/index.ts:353](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L353)
and [:401](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L401).
A6 scenario P: a parent who cleanly links 5 children gets
`per_parent_count = 5 >= MAX_ATTEMPTS_PER_PARENT = 5` → the **6th child's valid code is
rejected unread**, because the assert runs at `:286`, before redemption.
`pairing/index.ts:330` additionally records `child_already_linked` (a *refusal*) as
`success = true`.

### 3.7 Third contributor: the client cannot stop losing the code

- The code lives only in memory — `Rxn<PairingCode> linkingCode`
  ([child_enrollment_controller.dart:50](file:///D:/parentcontrol_app/lib/features/child/controllers/child_enrollment_controller.dart#L50)).
  `local_settings_service.dart` has no pairing key. A process kill silently forces a
  re-mint and a fresh budget burn.
- There is **no "read my current code" action** server-side (only `create`, `redeem`,
  `pending_child`, `respond`, `cancel`, `list_family`, `unlink`), and it *cannot* be added:
  only `code_hash` is stored, so the plaintext is unrecoverable by design.
- Every fresh code displays **"Expires Just now"** —
  [formatters.dart:21](file:///D:/parentcontrol_app/lib/core/utils/formatters.dart#L21)
  returns `'Just now'` for any negative/future diff, and
  [child_enrollment_page.dart:239](file:///D:/parentcontrol_app/lib/features/child/child_enrollment_page.dart#L239)
  feeds it a future timestamp.
- The 429 renders as a generic red "Action failed" with no retry time
  ([child_enrollment_page.dart:99-107](file:///D:/parentcontrol_app/lib/features/child/child_enrollment_page.dart#L99));
  the child side has no error→guidance map at all, unlike the parent's
  `_errorTitle`/`_errorGuidance` ([pairing_redeem_page.dart:320-362](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L320)).
- The parent's own guidance tells the guardian to have the child mint **new** codes
  ([pairing_redeem_page.dart:344-348](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L344)) —
  one mistype costs the child 1 of 5.
- A slow-but-successful create turns into "The request timed out. Try again."
  ([edge_api.dart:24](file:///D:/parentcontrol_app/lib/data/services/edge_api.dart#L24)) and
  the retry burns a second unit. No idempotency key exists.

**What did *not* cause it:** no client path double-submits. `createCode` early-returns on
`isCreatingCode` ([child_enrollment_controller.dart:133-141](file:///D:/parentcontrol_app/lib/features/child/controllers/child_enrollment_controller.dart#L133)),
the button is disabled while loading, `AppButton` forces `onPressed: null` while loading,
the 15 s poll only calls the read-only `pending_child`, and there is no
`WidgetsBindingObserver`/`AppLifecycleListener`/retry hook anywhere in `lib/`.

**What did cause today's specific lockout:** the QA harness. `.tools/live/results/phase1.json`
(mtime 15:44) already shows `pairing.A.create → 429` and `pairing.B.create → 429`, ~2.5 h
before the 18:09 screenshot. Worse, `pairing_security.mjs:17` calls `action:'create'`
purely as a *state probe* to learn whether quota remains — so every run of the security
suite spends one real code from each child's budget. Note also that `code_capacity.mjs`
reported `permission denied for table device_pairing_tokens`: that table is service-role
only, so any capacity figure produced that way is invalid evidence.

### 3.8 Guard order (why this is not an auth issue)

`pairing/index.ts` create path: OPTIONS → 405 → `readJson` → `requireAction` →
`getServiceClient` → **`requireUser` (verified email)** → **`role=child`** →
**`child_already_linked` 409** → **limiter 429** → insert → revoke → cancel → audit.
The limiter is strictly *after* authentication, authorization and the already-linked
check. Confirmed against the live log: `anon_cannot_create_code → 401`,
`parent_cannot_create_code → 403`, `create_quota.childC → 409`, while childA/childB → 429.

---

## 4. Assessment of the current policy

| Dimension | Verdict | Reasoning |
|---|---|---|
| Does the cap stop an unauthorized link? | **No** | A code links nothing by itself. Approval is child-initiated and identity-bound ([functions.sql:215-247](file:///D:/parentcontrol_app/supabase/migrations/20260101000100_functions.sql#L215)). A minted code is an *offer* only the child can accept. |
| Does the cap stop brute force? | **No — other controls already do that** | ~6.6e11 keyspace, uniform via rejection sampling; 10 guesses per code per 10 min; 5 per parent per 10 min; unknown and expired codes answer identically ([pairing/index.ts:316-317](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L316)) so there is no enumeration oracle. |
| Does the cap bound DB-row growth / mint spam from one compromised child session? | **Yes — this is its only genuine value** | And a 30 s cooldown + hourly cap preserves it. |
| Is the cap correctly implemented? | **FAIL** | Counts rows it just revoked (§3.2); contradicts its own contract (§3.3). |
| Is the cap survivable for a real family? | **FAIL** | A child who loses the code to a process kill, or who is unlinked for device recovery, is locked out until an arbitrary tomorrow — with a message that says only "later". |
| Does the cap interact safely with the redeem cap? | **FAIL — a pincer** | Once the child is capped, the parent can never get a fresh code, so the per-token advice "Ask for a new code" ([rate_limit.ts:43](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L43)) is unsatisfiable. |
| Is the 429 actionable? | **FAIL** | Static string, no `Retry-After` header, no reset time. `ApiError` carries only `code`/`message`/`status` and `fail()` emits only `Content-Type` + `Cache-Control: no-store` ([envelope.ts:6-35](file:///D:/parentcontrol_app/supabase/functions/_shared/envelope.ts#L6)). The count query uses `head: true` so it never even *has* the timestamps. |
| Are the dead columns a problem? | **P3, but misleading** | `attempts` / `max_attempts` are selected at [pairing/index.ts:295](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L295) and never read or incremented. A6's live catalog: 27 rows, all still on the DDL default `0`/`10`; zero functions mention either column; zero triggers. Real accounting lives in `pairing_attempts`. A future reader will trust them. |

**Overall: the policy is correct in intent, wrong in implementation, and — as shipped —
an availability defect rather than a security control.**

---

## 5. Desired workflow vs. reality

Desired: *child account created once → backend assigns a stable child identifier → parent
enters or scans that identifier once → server verifies it belongs to the right child and
device → child gets a clear approval request → relationship established only after approval
→ later sessions reuse it → unlink invalidates it.*

| # | Step | Status | Evidence |
|---|---|---|---|
| 1 | Child creates an account once | **WORKS** | `supabase_auth_repository.dart:60-75`; profile trigger `core.sql:476-486`; role set once `auth-bootstrap/index.ts:32-64`, immutable `core.sql:491-516`; verified-email gate `auth.ts:118-125` |
| 2 | Backend assigns a stable unique child identifier | **WORKS** | `profiles.id` UUID PK, immutable (`core.sql:17-25`, `:497-499`); one active family per child `core.sql:69-71`; one active device per child `core.sql:117-119` |
| 3 | Child need not repeatedly create a linking code for ordinary linking | **MISSING** | The code is the only entry point (`pairing/index.ts:280-297`); 10-min TTL `:36`; new code revokes the previous `:248-254`; 5 per 24 h (`rate_limit.ts:8`, `:70-88`); the child UI offers only "Create linking code" (`child_enrollment_page.dart:189-199`) |
| 4 | Parent enters/scans that identifier | **PARTIAL** | Enters/scans the 8-char code only (`pairing_redeem_page.dart:43-63`); the QR parser accepts exactly `code` + `v=1` (`pairing_qr_payload.dart:13-37`). No uid/handle input or RPC exists |
| 5 | Server verifies it belongs to the right child **and device** | **PARTIAL** | Child half works (`pairing/index.ts:282-336`, `functions.sql:239-247`). **Device half missing:** tokens carry no device reference (`core.sql:128-142`); the device binds later, by the child alone, at `device-register/index.ts:118-141` |
| 6 | Child gets a clear approval request | **WORKS** | `pairing/index.ts:428-460`; UI "Waiting for your approval / Approve only if you recognise the guardian and family below" (`child_enrollment_page.dart:281-296`); 15 s poll (`child_enrollment_controller.dart:40`) |
| 7 | Child approves the intended parent and family | **WORKS** | ownership `functions.sql:215-217`, expiry `:227-237`, parent-still-active `:239-247`; consent copy `child_enrollment_page.dart:307-316`; parent screen disclaims self-approval `pairing_redeem_page.dart:204-209` |
| 8 | Relationship established only after approval | **WORKS** | child `family_members` row inserted only in the approve branch (`functions.sql:249-274`); device registration demands active membership (`device-register/index.ts:141`) |
| 9 | Later sessions reuse the relationship | **WORKS** | RLS predicates `core.sql:571-626` across `rls.sql:43-240`; `remote-session/index.ts:99-113` re-derives family/device/child from the device row; realtime topic gate `rls.sql:295-332` |
| 10 | Unlink/revocation invalidates it | **WORKS** | `unlink_child` `functions.sql:325-427`; `revoke_device` `:432-506`; re-enrollment gate `enrollment.ts:3-13` + `device-register/index.ts:53-102`; recovery path `20260101000400_device_recovery.sql` |

**A stable, shareable child identifier already exists: `profiles.id`.** What blocks the
desired workflow is not identity, it is four concrete things:

1. **Structural blocker:** `pairing_requests.token_id uuid NOT NULL UNIQUE`
   ([core.sql:154-155](file:///D:/parentcontrol_app/supabase/migrations/20260101000000_core.sql#L154)).
   A request cannot exist without a redeemed code token, so there is no
   invite-without-code row to approve. A6 confirmed empirically: an invite-style insert
   raises SQLSTATE 23502 (NOT NULL) and a second one raises 23505 (UNIQUE).
2. **No lookup/invite RPC** takes a child uid and produces a request.
3. **No parent UI** for it — "Link a child" is code field + QR scanner only.
4. **No child UI** for it — the app never renders the account uid;
   `SessionService.userId` is used only for equality checks.
5. **Anti-enumeration is deliberate:** RLS forbids reading a stranger's profile
   (`rls.sql:27-31`) and the contract says "Do not expose any directory search"
   ([api-contract.md:312](file:///D:/parentcontrol_app/docs/api-contract.md#L312)) — so a
   uid-only path needs an explicit, separately rate-limited RPC. Today's limits are keyed
   only on `parent_user_id` and `code_hash`.

---

## 6. Permanent child identifier — security analysis and recommended design

Full memo: [`A4-security-design.md`](file:///D:/parentcontrol_app/.tools/evidence/full-qa/read-only-audit-20261027/A4-security-design.md)

### 6.1 Risks introduced by making a stable ID sufficient to initiate linking

| # | Risk | Why today it is impossible |
|---|---|---|
| R1 | **Unsolicited requests / harassment of a known ID.** Redemption is already open to "any authenticated parent, any family they own" (`pairing/index.ts:277-282`). A stable learnable key turns the insert at `:375-386` into an unbounded write into a minor's consent inbox. | The unguessable 39.5-bit code *is* the inbound rate limit. **No per-child inbound cap exists anywhere in `rate_limit.ts`.** |
| R2 | **Consent fatigue → consent bypass.** Spam trains a child to tap Approve. A link is not cosmetic: it switches on location/usage/app reads for the parent (`rls.sql:113-138`). A coerced approval is a tracking incident. | Same as R1. |
| R3 | **Enumeration / directory.** A stable ID that resolves to a display name (`pairing/index.ts:69-77` decorates requests with names) *is* a directory. | `profiles_select_self_or_family` (`rls.sql:27-31`) + contract `:312`. Also: `pairing_attempts` is keyed by `code_hash` (`core.sql:417`), so it structurally cannot rate-limit "guess child IDs". |
| R4 | **A permanent QR is a permanent bearer artifact.** A screenshot forwarded in a group chat gives an indefinite path to the child. | The current QR self-destructs in 10 minutes. |
| R5 | **Cross-family pre-emption / lock-out-by-priority** — an attacker occupies the child's inbox so the real guardian's request is buried. | `token_id UNIQUE` (`core.sql:154`) accidentally prevents this (one request per token). Replacing it must be replaced *explicitly*, not implicitly. |
| R6 | **Escalation via a buggy approval gate.** `functions.sql:231-237` requires an active, unexpired token before approval. A naive port that drops the token concept often drops this check too — losing "expired request cannot be approved" rather than moving it. | — |
| R7 | **ID == auth UUID.** Using `profiles.id` as the entered value makes a minor's primary key public, unrotatable and correlatable across families and backups. | **Rejected outright.** |
| R8 | **Revocation asymmetry.** If the stable ID were also an authorization source it would have to be revocable — and "stable" would be a lie. | `unlink_child` already nulls credentials and ends sessions (`functions.sql:379-406`). |
| R9 | **Identifier leakage.** `audit_logs.target_id` is free text readable by every family parent (`core.sql:382`, `rls.sql:236-240`) — writing a shareable ID there makes it parent-visible. `secret_hash`/`installation_id` are deliberately stripped (`rls.sql:257-266`). | — |
| R10 | **Weak verification display.** The child identifies the requester only from `family_name` + `parent_display_name`, and `display_name` is a self-chosen, user-updatable 1..60-char string (`core.sql:21-22`, grant `rls.sql:251`). This is the sole impersonation check the approval UI rests on. | — |

The brief's two constraints are both satisfied by the recommended design: the identifier
**identifies the account** and is **not** a secret or an authorization token, and a stable
public ID is **not** sufficient by itself to grant remote access.

### 6.2 Recommended design — stable contact handle + consent-gated invite

Three refinements over the naive version: the identifier is a **separate opaque handle,
not the UUID**; the mint/revoke machinery is **removed from the critical path** rather
than made reusable; and an explicit **per-child inbound cap** is added, because that is
the control the unguessable code was silently providing.

1. **Handle issuance.** New service-role-only table
   `child_contact_ids(child_user_id uuid pk, handle_hash text unique check hex64, rotated_at, created_at)`
   — same "RLS enabled, zero policies, zero grants" posture as `device_pairing_tokens`
   (`rls.sql:9,74,286`). Handle = **12 chars** from the existing alphabet
   (`validation.ts:12`), stored only as `sha256Hex` and looked up by hash exactly like
   today's code. 12 vs 8 means the two spaces can never collide and the server routes by
   length; the existing client regex already accepts 8–12 chars (`validators.dart:5`), so
   a new handle typed into an old app fails *safely* as `invalid_code`. Generated lazily
   on first read — **no backfill migration**.
2. **Child UI.** `get_contact_id` (child JWT + role) returns
   `{contact_id, qr_payload: "parentcontrol://pair?id=<handle>&v=2", rotated_at}`.
   **It is a pure read: it creates no row, so it needs no budget. This is what deletes the
   lockout.** The `v=1` path and QR parser stay untouched
   (`pairing_qr_payload.dart:12-32` strictly rejects unknown versions, so an old parent app
   cannot act on a new QR).
3. **Parent initiation.** New `invite` action: parent JWT → role parent →
   `assertFamilyParent` → format-check then hash-lookup the handle → insert **only** a
   `pairing_requests` row with `status='pending_child'` and `expires_at = now + 24 h`.
   Response reuses `redeemPayload` so the parent screen works unchanged, including its
   honest "Nothing is linked yet" copy. Audit `pairing_invite_created` — the event-type
   column is length-checked only, so new event names need no schema change.
4. **Consent — unchanged.** `pending_child` listing + lazy expiry, and `respond` →
   `public.respond_pairing_request` with child-ownership, status, expiry,
   parent-still-active and one-active-family re-checks all intact. **The single SQL change:**
   the token requirement at `functions.sql:231-237` becomes *conditional* — token present
   ⇒ must be active and unexpired (legacy path); token absent ⇒ must be a non-expired
   invite.
5. **The durable object stays the relationship, not the identifier.** Membership is written
   only by the service role; runtime authority remains the device credential
   (`x-device-id` + `x-device-secret`, constant-time SHA-256 compare with a decoy compare
   for unknown ids, `auth.ts:281-337`), minted only by the child's own JWT plus active
   membership. Revocation and the re-enrollment gate are untouched.
6. **Optional hardening (display-only, never required by `respond`):** a 4-char
   verification phrase shown on both the parent's invite result and the child's request
   card, so the child can match the person standing in front of them. This softens R10
   without creating a second secret.

**Alternatives rejected.** (B) a long-lived reusable token row in `device_pairing_tokens`
— makes the permanent identifier *also* a live credential, which the brief forbids, and
reusability requires deleting the anti-replay guard. (C) a static family contact code —
is a shared secret, needs a notification channel that does not exist in this repo, and
rotation breaks every saved contact. Its useful half (out-of-band confirmation) is folded
into the chosen design as display-only.

### 6.3 Server-enforced invariants (each phrased as a test)

I1 a request grants **zero** data access before approval (parent-RLS SELECTs on
location/usage/apps/devices return 0 rows) · I2 no client can create membership
(SELECT-only grant) · I3 approval requires the child's own JWT, never the body ·
I4 nothing is approvable past expiry · I5 one active family per child even under
concurrent approvals · I6 at most one actionable invite per (child, family) via a new
partial unique index · I7 no directory and no state oracle — unknown handle, non-child
handle and already-linked-child handle return the **byte-identical** error ·
I8 every initiation attempt is recorded, fail-closed · I9 revocation nulls the device
credential in the same transaction · I10 rotating the handle changes no membership, no
device row and no policy, and a retired handle's already-created invite stays approvable
until its TTL (so rotation cannot silently kill consent the child already gave, nor
resurrect an expired one) · I11 approval re-checks the parent is still active ·
I12 inbound flood capped per child, per family **and** per parent, server-side only ·
I13 length-based routing is total (8 ⇒ token, 12 ⇒ handle, anything else ⇒ the same
uniform `invalid_code`) · I14 every transition audited, audit-insert failure aborts the
action · I15 a link alone never produces a `devices` row.

### 6.4 Migration and rollout order that cannot produce "nobody can link"

1. Deploy SQL (additive or *relaxing* only — `token_id` → nullable; every pre-existing
   request row has a `token_id` and still approves normally).
2. Deploy Edge Functions: `get_contact_id` + `invite` added; `create`/`redeem`
   **byte-for-byte unchanged**. Verify pre-approved legacy `pending_child` rows remain
   approvable — check the branch order in the RPC.
3. Ship the child build that displays the handle; keep the "Create linking code" button
   for one release cycle.
4. Ship the parent build with the ID field/scanner; `v=1 code=` keeps working, `v=2 id=`
   is added, unknown versions still parse to null so the parent falls back to typing.

**Kill switch:** a `Deno.env` flag (read like `SUPABASE_URL` at `auth.ts:51-53`); off ⇒
`invite` returns `feature_disabled` 503 and `get_contact_id` reports disabled so the child
UI hides the ID. Rollback is safe because invite rows are a new row type. **Never delete
or expire the `v=1` path while any installed APK depends on it.**

A 22-case test matrix (T1–T22, SQL-level plus wire-level) is in
[`A4-security-design.md` §7](file:///D:/parentcontrol_app/.tools/evidence/full-qa/read-only-audit-20261027/A4-security-design.md).

---

## 7. Two-device test matrix (read-only, current builds)

Devices and builds, verified by pulling and hashing the installed `base.apk`:

| Role | Device | OS | versionCode | base.apk SHA-256 |
|---|---|---|---|---|
| PARENT | `emulator-5554` (Pixel 9a AVD, x86_64) | Android 17 / API 37 | 4001 | `537f2152db8cf50e61f43d005eec2db3d0f69165396ebab1d73adbdca7de3611` |
| CHILD | realme RMX2161 `5HXWRGQ4IFU8WS4T` (arm64) | Android 12 / API 31 | 2001 | `e5b7355c60b8165d34f53fc0e1785d449748200ffb28e60000a08ddf9684a4b8` |

Both carry the 17:21 reinstall, i.e. the three client fixes in §0.2.

| # | Area | Test | Verdict | Observation |
|---|---|---|---|---|
| 1 | Parent | login + family + dashboard | **PASS — LIVE VERIFIED** | Signed in, header "QA Family A", 2 devices both "Revoked" (QA Test Phone A "Last seen 20 h ago · Fully managed (Device Owner) · Policy v1 Enforced"; QA Phone A "Never reported · Not enforced · Policy v2 Waiting for device") |
| 2 | Parent | "Link a child" QR preview is live | **PASS — LIVE VERIFIED** | `dumpsys media.camera` shows an OPEN client `Camera ID 10, State 2, PID 15419, com.parentcontrol.parent_control`; screenshot renders a real scene |
| 3 | Parent | invalid 8-char code | **PASS — LIVE VERIFIED** | "ZZZZZZZZ" → "Code not recognised / The linking code is not valid…". Truthful; no existence/expiry leak |
| 4 | Parent | malformed code | **PASS — LIVE VERIFIED** | "AB-12 3" → normalized "AB123" → client-side "Check the code". Does **not** reach the server, does not burn budget |
| 5 | Parent | 5-per-10-min budget → 429 | **PASS — LIVE VERIFIED** | "Too many attempts / Too many linking attempts. Wait a few minutes and try again." — no exact retry time. **New defect DUP-429 below** |
| 6 | Child | setup screen budget state | **PASS — LIVE VERIFIED** | Banner "Action failed — You have created too many linking codes today. Try again later." — no retry time |
| 7 | Child | "Expires Just now" | **BLOCKED** | Defect CONFIRMED statically (`formatters.dart:21`), but no live surface is reachable without creating a code, and the budget is exhausted |
| 8 | Both | pending-approval UI | **NOT TESTED** | Child Requests tab: "No pending requests" |
| 9 | Both | existing-link reuse | **PASS — LIVE VERIFIED** | All parent-side devices "Revoked"; child home shows "Link this phone / Set up linking" — consistent unlinked state |
| 10 | Child | camera + mic self-test | **NOT TESTED** | Card **is present** (§0.4, `manual-realmesettings-top.png`); I did not tap it — "do not silently activate media capture". `CAMERA` and `RECORD_AUDIO` both `granted=true (USER_SET)`, verified not changed |
| 11 | Child | "Recording" row wording | **NOT TESTED** | Sheet not opened, same reason. Source is fixed (`media_self_test_sheet.dart:308`) |
| 12 | Child | background services | **NOT TESTED (state-blocked)** | After HOME: `dumpsys activity services` = "(nothing)". Process cached then FROZEN by `OplusHansManager`. Consistent with the **unlinked** state ("Background protection — Not running"), not evidence of a defect. Force-stop leg skipped as destructive |
| 13 | Child | heartbeat over 60 s | **NOT TESTED (state-blocked)** | `A5-13_heartbeat_60s.txt`: no app-emitted heartbeat lines. The "Telemetry SDK 6.0" lines are PID 4818, not the app |
| 14 | Child | Device Owner state | **PASS — LIVE VERIFIED** | `dpm list-owners` = "no owners"; `dumpsys device_policy` provisioningState 0 with ENABLED **device admin only** |
| 15 | Parent | app-blocking honesty | **PASS — LIVE VERIFIED** | Device detail states honestly: "App suspension is not supported here — This device is not a fully managed Device Owner device… A policy flag on its own does not block an app." Child Settings corroborates: "Device admin only — app blocking is not available" |
| 16 | Both | Instagram / app restrictions | **NOT TESTED** | Backend policy rows exist at Policy v1/v2, but both devices are revoked and the device is not Device Owner. **A backend policy row is not a block — do not report Instagram as blocked** |
| 17 | Both | two-endpoint WebRTC media | **NOT TESTED** | Requires an active link; the child cannot mint a code (§3) and I did not delete rate-limit records to work around it |
| 18 | Child | reboot persistence | **NOT TESTED** | Reboot forbidden by the brief |
| 19 | Child | screen recording | **NOT IMPLEMENTED** | Confirmed absent from every visited screen; child Settings footer states "This app never records audio or video, takes screenshots…". Owner decided to keep it out of scope (Phase 6B) |

**New defect found this run — DUP-429 (P3, cosmetic):** the rate-limit banner concatenates
server text and client guidance into two overlapping "wait" sentences —
"Too many linking attempts. Wait a few minutes and try again. **Wait before trying again;
the server throttles attempts.**" Neither gives a concrete retry time.
Evidence `A5-08_rate_limited_429.png`. Source:
[pairing_redeem_page.dart:350](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L350)
appending its own guidance to the verbatim server message.

**Blocked-path note.** Phases 4 (WebRTC), 6 (background/heartbeat) and 3 (pairing negative
tests) are all blocked by the *same* root cause: the child cannot mint a code, so no link
can be created, and creating one would require deleting rate-limit records — explicitly
forbidden by the brief. **These are BLOCKED, not PASS, and must not be counted as passes.**

---

## 8. Feature status summary (as asked in the brief)

| Capability | Status | Basis |
|---|---|---|
| Child camera/mic during an accepted assistance session | **IMPLEMENTED — LIVE VERIFIED on a newer build in an earlier phase; NOT RE-TESTED on the current build** | `child_settings_tab.dart:196` card present and reachable (`manual-realmesettings-top.png`); permissions granted; not activated this run |
| Background operation / guardian service / heartbeat | **IMPLEMENTED, NOT TESTED in this state** | Requires an active link; both QA children are unlinked and rate-limited |
| App blocking / suspension | **NOT AVAILABLE — correctly reported as such** | Device admin only, `dpm list-owners` = "no owners". UI is honest about it |
| Screen recording (child) | **NOT IMPLEMENTED** — intentionally, out of scope per owner decision | Proven at five independent levels in Phase 6B: source, packaged manifest (aapt2), dex attribution (dexdump — all 728 capture hits belong to `com.cloudwebrtc`/`org.webrtc`), installed-package permissions, 33 live authenticated screens |
| Linking-code creation | **BROKEN (P1)** | §3 |
| Redeem attempt accounting | **BROKEN (P2)** | §3.6 |
| Stable child identifier workflow | **NOT IMPLEMENTED** — structural blocker identified | §5.1 |

---

## 9. Prioritized recommendations

### P1 — unblock linking (server, one-line filter + three small changes)

**Fix A — correct the count filter.** [rate_limit.ts:76-79](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L76)
add:

```ts
.eq("status", "active")
.gt("expires_at", new Date().toISOString())
```

**This alone relieves every locked-out family immediately, with no migration, no backfill
and no record deletion.** A1's walkthrough and A6's scenario table both prove it: dead
rows stop being debt the instant the filter ships. Do **not** count `redeemed` rows —
`unlink_child` leaves them intact, so a family re-provisioning after a factory reset would
be billed for their own past successes. There is no `'consumed'` status to count.

Honest consequence: because `pairing/index.ts:248-253` revokes predecessors, this count is
**at most 1**, so a threshold of 5 becomes inert. That is not a bug — it is the proof that
a row-count cap can never express "how many live codes exist". Fix B must supply the real
throttle.

**Fix B — replace the cap with what it should have been.** `CODE_CREATION_COOLDOWN_SECONDS`
(~30 s, implemented as `.order("created_at", {ascending:false}).limit(1)`) plus
`CODE_CREATIONS_PER_HOUR` (~10, window constant extracted from the inline `24*60*60*1000`
at `rate_limit.ts:74`). Optionally keep a generous 20/24 h backstop so old clients can
never be locked out.

**Fix C — stop the create path destroying live requests.**
[pairing/index.ts:256-261](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L256)
currently cancels *every* `pending_child` request for the child. Cancel only requests whose
token was just replaced. Today this is a double lockout: retry a code and you also kill a
parent's in-flight request.

**Fix D — make the redeem ledger match the contract.** Add `.eq("success", false)` to both
counts in `assertPairingRedeemAllowed` ([rate_limit.ts:20-24](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L20),
[:34-38](file:///D:/parentcontrol_app/supabase/functions/_shared/rate_limit.ts#L34)) and
change [pairing/index.ts:330](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L330)
from `true` to `false` — `child_already_linked` is a refusal, not a success.
*Caution:* this reclassifies harness expectations that were recorded as passes against
today's behaviour (`pairing_window_retry.log`, `pairing_security.log`); those need re-running.

**Fix E — make the 429 actionable.** Select `created_at` (drop `head: true`), compute the
recovery time, add an optional `retry_after_seconds`/`resets_at` to `ApiError` and a
`Retry-After` header in `fail()` ([envelope.ts:6-35](file:///D:/parentcontrol_app/supabase/functions/_shared/envelope.ts#L6)).
`code`/`message` stay as-is so every existing client keeps working. Message becomes "You
can create another linking code in 12 minutes."

**Fix F — add the missing retention.** New service-role RPC
`private.expire_stale_pairing_tokens()` (`UPDATE … SET status='expired' WHERE status='active'
AND expires_at <= now()`) plus `DELETE FROM pairing_attempts WHERE attempted_at < now() -
interval '7 days'`, wired as a third `cron/index.ts` case and a third pg_cron entry. This is
retention hygiene, not a correctness crutch — Fix A must not depend on it.

**Recovery path for a family locked out *before* deployment.** The brief forbids deleting
rate-limit records; it does not forbid *updating status*, and that distinction is the whole
recovery path — `device_pairing_tokens` is a domain table, `pairing_attempts` is the
immutable ledger. A documented service-role operator action
(`UPDATE device_pairing_tokens SET status='expired', expires_at=now() WHERE child_user_id=$1
AND status='active'`) is the only lever needed **under fixed code**; under current code it
does nothing, because the limiter ignores `status` — itself an argument for shipping Fix A.
Deleting rows is not required and should be explicitly disallowed. Never delete
`pairing_attempts`: the parent window is only 10 minutes.

### P2 — client hardening (all in [A2-client-ui.md](file:///D:/parentcontrol_app/.tools/evidence/full-qa/read-only-audit-20261027/A2-client-ui.md))

1. Persist `linkingCode` in `LocalSettingsService` keyed by user id and restore it in
   `load()`; hide the create button while an unexpired code exists. (The code cannot be
   re-fetched from the server — only its hash is stored.)
2. Show remaining quota and a confirm sheet before minting ("each code counts against a
   5-per-day limit").
3. On `timeout`/`network` from `create`, replace "Try again" with "A code may already have
   been created — wait a minute, then check for requests"; send a client idempotency token.
4. Fix `relativeTime` for future timestamps — add a ticking `countdownLabel()`
   ("9 min left"). Currently every code reads "Expires Just now".
5. Add a child-side `_errorTitle`/`_errorGuidance` parity map; special-case `rateLimited`.
6. De-duplicate DUP-429 (drop the client guidance sentence when the server already gave one).
7. `Get.delete<ChildEnrollmentController>()` on sign-out — today a previous child's code is
   re-displayed to the next sign-in in the same process.
8. Stop the parent's guidance from telling guardians to burn the child's budget
   ([pairing_redeem_page.dart:344-348](file:///D:/parentcontrol_app/lib/features/pairing/pairing_redeem_page.dart#L344));
   state the parent's own 5-per-10-min limit; suppress "Scan again" on `rate_limited`.
9. Require exactly 8 characters locally (`^[A-Z0-9]{8}$`) so 9–12 char junk stops costing a
   server attempt.
10. Gate the 15 s poll on the page being visible — it currently runs for the whole process
    life on the realme, draining battery/data.

### P3 — hygiene

- Remove or document `device_pairing_tokens.attempts` / `max_attempts` (dead, misleading).
- Fix the timing side channel: the expired branch performs an UPDATE before throwing
  ([pairing/index.ts:308-314](file:///D:/parentcontrol_app/supabase/functions/pairing/index.ts#L308)),
  which separates "exists but expired" from "no such token" even though the body is uniform.
  Defer status writes to the lazy sweep.
- Fix BUG-031 (`--split-per-abi` version codes make the documented `adb install -r -d`
  debug path fail with `INSTALL_FAILED_VERSION_DOWNGRADE`).
- Make `pairing_security.mjs`'s `create` state-probe non-consuming, or it will keep taxing
  the fixture it is observing.

### P1 (product) — stable identifier workflow

Implement §6.2 (handle + `get_contact_id` + `invite` + conditional token branch + per-child
inbound cap). This is the change that makes the brief's desired workflow true, and it also
removes the mint budget from the child's critical path entirely. Sequence it **after**
Fix A–C so families can link again today, and use the §6.4 rollout order with the kill
switch.

---

## 10. Baseline health (re-verified this session)

| Suite | Result |
|---|---|
| `flutter analyze` | 0 issues |
| Flutter tests | 102 passed |
| Kotlin unit tests | 13 passed |
| Deno Edge Function tests | 26 passed |
| SQL suite (5 migrations + 8 test files, `ON_ERROR_STOP=1`) | EXIT=0 — 403-line log, 0 ERROR, 0 ASSERTION FAILED; 18 public tables, 1 realtime policy, 32 functions, PostgreSQL 16.9 |

Toolchain note: `fvm` is not on PATH in this shell — use
`./.fvm/flutter_sdk/bin/flutter` (Flutter 3.44.6, Dart 3.12.2).

---

## 11. Residual gaps — explicitly not claimed as passes

1. **Two-endpoint WebRTC media (Phase 4): NOT TESTED.** Never completed on any build in
   this session. Blocked on an active link.
2. **Camera/mic on the *current* build: NOT TESTED.** Card presence verified live; the
   capture itself was deliberately not activated. A prior phase recorded PASS — LIVE
   VERIFIED on an earlier build; that does not transfer.
3. **Background services, heartbeat, notification (Phase 6): NOT TESTED.** The observed
   "no services running" is consistent with the unlinked state and is **not** evidence of a
   defect either way.
4. **Reboot persistence: NOT TESTED** (reboot forbidden).
5. **Phase 3 pairing negative tests: NOT COMPLETABLE** while the caps are armed — this is
   why task #13 is still pending.
6. **Hosted Supabase state: UNVERIFIED.** Every server-side conclusion is source reading
   plus a local PostgreSQL replay. The local DB uses `00_auth_stub.sql`/`05_realtime_stub.sql`
   and does not validate PostgREST query translation or the deployed project.
7. **Actual token/attempt counts in the hosted database: UNKNOWN.** That table is
   service-role-only; the `code_capacity.mjs` figure that appeared to show it was
   `permission denied` and is invalid evidence.
8. **The QA children may still be enrolled in a partially-revoked state** — both parent
   dashboard devices read "Revoked", so the fixture is not in a clean starting condition for
   a future two-device run.

---

## 12. Awaiting owner approval

Nothing in §9 is applied. The proposed changes are confined to
`supabase/functions/_shared/rate_limit.ts`, `supabase/functions/_shared/envelope.ts`,
`supabase/functions/pairing/index.ts`, `supabase/functions/cron/index.ts`, one new
migration for the retention RPC (and, for §6, `pairing_requests.token_id` → nullable plus
`child_contact_ids`), and the client files listed in §9/P2.

**Say the word and I will implement P1 Fixes A–C first** — A alone is a two-line change that
unblocks linking today with no migration and no data deletion.
