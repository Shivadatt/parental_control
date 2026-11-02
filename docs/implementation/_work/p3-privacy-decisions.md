# P3-F — privacy and governance decisions (analysis only)

Workstream: **P3-F**, Phase 3 "Security Hardening & Deployment Readiness".
Baseline: branch `main`, HEAD `8da1de7e9b4bc4ce3ede1336c4782d4d82596dc2`, Phase 2's 47 uncommitted files
preserved. **No source, migration, test or config file was changed by this workstream.** Every line
below is a read of the working tree, not of a hosted system: `account` is **not deployed** and
`20261030000100` / `20261030000200` / `20261030000300` are **unapplied**
(`docs/implementation/phase-2-open-gaps.md:13-14`). Where this document says "the code returns X",
that is a statement about code; nothing in this repo has been observed running.

Companion: `docs/implementation/_work/p3-followups.md` (triage of the remaining Phase 2 items).

---

# 1. PRIV-01 — child scope of `account` action `retention_report`

## 1.1 What the code actually does (verified)

| Fact | Evidence |
|---|---|
| The handler dispatches `retention_report` for **any** verified caller; there is no role gate and no verified-email gate | `supabase/functions/account/index.ts:473-474` → `retentionReport(db, auth)`; the gate is `requireUser(req, db)` with no options at `index.ts:466`; `requireRole` exists (`supabase/functions/_shared/auth.ts:129-139`) but is not used anywhere in `account/index.ts` |
| The client is the **service-role** client, so RLS does not constrain these reads | `index.ts:462` `getServiceClient()` → `_shared/auth.ts:49-65`; `auth.ts:60` creates the client with `SUPABASE_SERVICE_ROLE_KEY` |
| One report row is built **per family the caller belongs to**, and both counts are whole-family | `index.ts:389-424`: loop over `families` from `loadActiveMemberships` (`:370-374`, memberships `.eq("user_id", userId).eq("status","active")` at `:118-124`); count queries filter on `family_id` only — `location_events …eq("family_id", family.id)` at `:401-405`, `usage_daily …eq("family_id", family.id)` at `:406-410`; the values are passed as `locationEventsOlder` / `usageDaysOlder` at `:419-420` |
| The response shape is family-keyed, with no per-member field | `supabase/functions/account/retention.ts:75-83` (`FamilyRetentionReport`), built at `:86-104`; `family_id` and `name` are echoed at `:96-97` |
| The response **also** carries the global sweep row's `metadata` | `index.ts:377-383` selects the newest `audit_logs` row with `event_type = 'retention_sweep'` **with no family filter**; `index.ts:434-435` returns `last_sweep_at` and `last_sweep: lastSweep?.metadata` |
| That metadata is a project-wide total, not a family total | `supabase/migrations/20261030000300_retention_sweep.sql:232-247`: the inserted row has `family_id = null, actor_user_id = null` and `metadata = {swept_at, webrtc_signals, audit_logs, location_events, usage_daily}` summed over **every family in the database** (global loops at `:118-130` and `:134-146`, per-family loop summed at `:214`); the per-family breakdown `v_per_family` (`:218-219`) is returned from the RPC (`:250-257`) but deliberately **not** stored in the audit row |
| What RLS would have allowed the same child to read directly | `supabase/migrations/20260101000200_rls.sql:113-120` (`usage_daily`) and `:122-129` (`location_events`): a non-parent is granted only rows whose `device_id` belongs to a device with `d.child_user_id = auth.uid()`. `audit_logs` is **parent-only** (`rls.sql:236-240`) |
| The `export` action is already scoped per child; `retention_report` is the only family-wide one | `index.ts:154-158` (`child_user_id` filter for a child), `:167-177` (`scopeRows` by `childDeviceIds`), `:183-201` (audit rows limited to `actor_user_id = self` OR own `device_id`) |
| There is **no child-facing retention UI today** | `lib/features/child/tabs/child_settings_tab.dart:29-77` renders account, permissions, media test, enforcement, background and account-action cards — no retention card, no `retention_report` call. The only client of the action is `lib/features/settings/account_privacy_repository.dart:234-240`, reached from `ParentSettingsController` (`lib/features/settings/parent_settings_controller.dart:89`, `:224-243`) |
| Role routing means the parent shell (and therefore the retention card) is not navigable by a child | `lib/features/auth/auth_session_flow.dart:94-96` (parent → `AppRoutes.parentShell`, child → `AppRoutes.childShell`); `lib/app/routes/app_pages.dart:157-159`, `lib/features/settings/parent_settings_binding.dart:12-29` |
| The parent UI already discloses the family scope, unconditionally, and labels the counts "all members" | `lib/features/settings/settings_body.dart:164-167` (`'Counts cover the whole family, not just this account.'`) and `:179-186` (label `'… older than the window (all members)'`) |
| That disclosure string is not pinned by any test | grep for `Counts cover the whole family` matches only `lib/features/settings/settings_body.dart:165`; the retention tests at `test/features/settings/account_privacy_controller_test.dart:202-250` assert controller state, not the rendered sentence |
| The Dart model silently drops fields it does not know | `account_privacy_repository.dart:96-104` reads only `generated_at`, `last_sweep_at`, `families`; `last_sweep`, `defaults` and `cutoffs` are parsed nowhere. `FamilyRetentionWindow.fromJson` `:72-82` defaults counts to `0` when a key is absent (`jsonIntOr`) |

**Net, in plain terms.** PRIV-01 as filed is accurate but understated in one direction and overstated
in another. Accurate: a Child-role caller can obtain counts for data it cannot read row-by-row under
RLS — a count channel over sibling data (`index.ts:401-410` vs `rls.sql:113-129`). Understated: the
same response returns the **project-wide** deletion totals from the sweep marker (`index.ts:434-435` +
`20261030000300_retention_sweep.sql:232-247`), which cross the family boundary entirely. Overstated:
no child sees any of this in the app today, because the child shell never calls the action; the
exposure is the **endpoint's answer to a call a child's own device can make**, not a rendered screen.

Two severities, stated separately:
- family-wide counts returned to a child caller — **P2** as filed (`phase-2-open-gaps.md:55`):
  honest-but-wrong-scope aggregate, no UI path.
- `last_sweep` project-wide totals returned to a child caller — **P2** on its own (aggregate counts of
  other families' deletions), and it would become **P1** if any UI ever renders `last_sweep` per
  family, because the number is not this family's.

`audit_logs` parent actions: `retention_report` does **not** count per-family audit rows, so no
per-parent-action tally leaks through it. What does leak is the sweep's global `audit_logs` deletion
total (`20261030000300_retention_sweep.sql:244`) and the `location_events` / `usage_daily` totals.
The child's *own* export does surface parent actions on their own device — `index.ts:194-198`
matches `device_id.in.(own devices)`, which is by design and is disclosed to the user at
`lib/features/settings/export_result_dialog.dart:73-78`.

## 1.2 Option A — return child/device-specific counts

Design assumed: for a caller whose `profiles.role = 'child'` (`_shared/auth.ts:16`, the role is
write-once per `docs/implementation/api-contract.md:67`), scope the two counts to that caller's own
devices exactly as `export` already does, keep the family-level retention **windows** (they are the
windows that apply to the child's own data), add a `scope` marker, and stop returning `last_sweep`
totals to child callers.

### Privacy implications
- Sibling data: eliminated as a channel. The child learns only counts over `device_id` in
  {their own devices}, which is exactly the row set `rls.sql:113-129` already grants them. No new
  inference about a sibling's presence, travel or app use becomes possible.
- Parental activity: a child learns nothing about parent actions from the counts. If `last_sweep` is
  redacted for children, the child also stops seeing project-wide `audit_logs` deletion totals. The
  child still sees `last_sweep_at` (a timestamp) unless the owner also redacts it; a timestamp alone
  reveals that retention runs, which is arguably what a data subject is entitled to know.
- Residual disclosure: the child sees the **family's** windows (`retention.ts:98-99`) and the family
  `name`/`family_id` (`retention.ts:96-97`). Those are already visible to a child elsewhere
  (`families` membership rows in the child's own export, `index.ts:216-230`; `family_members` RLS is
  family-wide, `rls.sql:59`), so A does not add exposure.

### Exact changes (file:line targets, none applied)
1. `supabase/functions/account/index.ts:366-424` `retentionReport()` — after `index.ts:374`, when
   `auth.profile.role === "child"`, load the caller's device ids with the same predicate as the
   export path (`index.ts:153-165`), and:
   - replace the family filters at `index.ts:404` and `:409` with `.in("device_id", childDeviceIds)`
     (or `.eq("device_id", NO_MATCH_UUID)` when the list is empty — the sentinel already exists at
     `index.ts:39` and is used for exactly this purpose at `:171`, `:195`);
   - keep the window queries (`:391`) unchanged, because the window is a family setting.
2. `supabase/functions/account/retention.ts:75-83` — **add** `scope: "family" | "child_devices"` and
   `scope_device_ids?: string[]` to `FamilyRetentionReport`; `:86-104` passes them through from a new
   `scope` input. No existing field is renamed or removed.
3. `supabase/functions/account/index.ts:434-435` — for a child caller, return
   `last_sweep: null` (or a whitelisted subset `{swept_at}`), since the stored metadata is global
   (`20261030000300_retention_sweep.sql:241-247`).
4. `lib/features/settings/settings_body.dart:162-167` and `:179-186` — the disclosure and the
   `(all members)` label must become scope-driven, read from the server field, not from the client's
   guess. Under A the sentence "Counts cover the whole family" is **false** for a child-scope report.
5. `lib/features/settings/account_privacy_repository.dart:55-83` — parse `scope` into
   `FamilyRetentionWindow` (default must be the honest "unknown", not "family").

### API contract changes
- `docs/implementation/api-contract.md:244` (`account` row) must state the per-role scope of
  `retention_report`, currently silent beyond "configured windows + last sweep timestamp";
  `coordinator-contract.md:98` says the same one-liner.
- Envelope is additive-only (`api-contract.md:261-262`): A is expressible additively
  (`scope` is new; `location_events_older_than_window` / `usage_days_older_than_window` keep their
  names and change *meaning* for child callers only). That last clause is the honest weakness of A —
  a redefined semantic under a stable name. Mitigation is the `scope` field plus the UI reading it.
- Versioning: the action takes **no** request body today (`account_privacy_repository.dart:235-238`
  posts only `{action}`; `lib/data/services/edge_api.dart:59-74` merges `action` with an empty body),
  so there is no parameter to version on. Two options: (i) implicit versioning by caller role — no
  client change, but an old build shows a new meaning; (ii) an explicit opt-in
  `retention_scope: "self"` request field with the current behaviour as the default for absent keys —
  preserves old builds exactly, and lets the child UI ask. A is safest as (i) + `scope`, or (ii) if
  the owner wants zero behaviour change for shipped builds.

### Backward compatibility
- Older app builds: `RetentionReport.fromJson` ignores unknown keys
  (`account_privacy_repository.dart:96-104`), and a missing count key parses as `0` (`:78-80`,
  `jsonIntOr`). So an old build never crashes; it either shows the new smaller number under the old
  "(all members)" label (mislabel, no crash) or shows `0` if a key is renamed — which is why the
  field names must not be reused for a different metric.
- Cached UI: `ParentSettingsController.retentionWindows` (`parent_settings_controller.dart:69-82`)
  falls back to `SessionService.activeFamily.settings` with **zero counts** when the report has not
  loaded; a scope change never touches that path, and the counts are only ever server-reported.
- The child's own export path: unaffected — `export` already child-scopes (`index.ts:154-158`,
  `:167-177`). A actually *reduces* the inconsistency between the two actions, which is the strongest
  argument for it.

### Required tests
- **Deno (real proof)**: `retentionReport` cannot be injected today — it is a non-exported function
  inside a bare `Deno.serve` handler (`index.ts:366`, `index.ts:454`). A true test needs either an
  export of `retentionReport` in `supabase/functions/account/index.ts` (a behaviour-neutral refactor,
  and that file is Phase 1 `lifecycle`-owned, `coordinator-contract.md:128`) or a fake-PostgREST
  harness. Cheaper but weaker: extend the source-level proof at
  `supabase/functions/handler_wiring_test.ts:235-262` to assert the child branch filters by
  `device_id`. This is the same blocker as TEST-01 (`phase-2-open-gaps.md:48`).
- **SQL authorization**: no SQL function is involved, so the meaningful test is a psql assertion that
  the *RLS grant* a child has is row-limited to their own devices — `supabase/tests/30_rls.sql`
  already covers the parent/child split; a new case should assert a child role sees 0 sibling
  `location_events` rows so the aggregate scope of A is provably equal to the row grant.
- **Dart widget**: a `SettingsBody` case pinning the scope sentence per `scope` value (the string at
  `settings_body.dart:165` is currently unpinned), plus a `export_result_dialog_test.dart`-style
  regression that an unknown scope is not described as family-wide — see §1.5 / WORD-02.
- **Dart unit**: `RetentionReport.fromJson` with `scope` absent, `"family"`, `"child_devices"`
  (extend `test/features/settings/account_privacy_controller_test.dart:202-250`).

### Cost
Roughly 40–60 lines across `account/index.ts`, `account/retention.ts`, one Dart model and two Dart UI
strings, plus one Deno test and one widget test. No migration, no new column, no new table, no new
client-callable RPC — so it does **not** collide with `coordinator-contract.md:21-23` or
`api-contract.md:255-256`. If the export-first refactor needed for a real Deno test is included, add
a second, cross-ownership file (`account/index.ts` export list).

### Residual risk after shipping A
1. A child with their own JWT can still enumerate *how many devices* the family report by reading
   `scope_device_ids` — mitigated by omitting that field, in which case A leaks nothing extra.
2. Aggregate-timing inference disappears with A, but a child can still learn the family's **windows**
   and see them change over time; that is parental policy, not sibling data. Accepted by design.
3. The `(all members)` label and the disclosure sentence become wrong for any build that predates the
   UI change, i.e. wording correctness is version-coupled — old builds mislabel correct numbers.
4. Nothing is enforced by RLS: the scoping lives in the handler (`index.ts:389-424` is the only
   guard, exactly as it is today). A future second caller of the same helper can re-introduce the
   leak; only the missing injectable test can catch it. This is the honest weakness of A, and it is
   TEST-01's root cause.

## 1.3 Option B — keep family-wide counts, disclose the family scope in the Child UI

### Privacy implications
- A child learns: the family's retention windows, the number of **all-member** `location_events` and
  `usage_daily` rows past those windows, the family `name` and `family_id`, and the project-wide
  sweep totals in `last_sweep` (`index.ts:434-435`). Counts are aggregate, but with two siblings a
  non-zero delta over time is a weak channel about a sibling's device activity, and `> 0` vs `= 0`
  alone already tells a child whether another device has old data.
- Parental activity: the family's window values are the parent's choices
  (`family-admin` `update_retention`, `api-contract.md:125`); a child watching them change learns the
  parent's policy behaviour. Not covered by a wording fix, because it is disclosed **data**.
- Disclosure honesty: B makes the response truthful-but-broader-than-the-caller. That is defensible
  for a consenting data subject who is shown the scope, and indefensible as a silent default.

### Exact changes (file:line targets, none applied)
1. Server: `index.ts:389-424` unchanged. If `last_sweep` totals are kept, they must be labelled
   global — the string at `settings_body.dart:230-238` already does this for the parent shell
   ("one global marker row, not this family's own run time") but says nothing about the **counts**
   inside `last_sweep`.
2. Client: B as literally scoped ("disclose in the Child UI") requires a **new child-facing surface**,
   because none exists: `lib/features/child/tabs/child_settings_tab.dart:29-77` has no retention card
   and the only repository caller is `parent_settings_controller.dart:224-243` bound to the parent
   shell (`app_pages.dart:157-159`, `parent_settings_binding.dart:12-29`; role routing at
   `auth_session_flow.dart:94-96`). Adding it means a new widget plus a `ChildShellController` call
   path — that is scope growth, not a wording change, and it should be costed as such.
3. If instead B is implemented only on the parent surface, then B changes **nothing** in the tree
   today: `settings_body.dart:164-167` already discloses the family scope, and
   `:179-186` already says "(all members)". B-in-the-parent-shell is therefore already shipped, and
   the honest label for that variant is "accept the current behaviour and record it".

### API contract changes
- `api-contract.md:244` gains one clause: `retention_report` is member-callable and returns
  **family**-scoped counts plus a **global** sweep marker; the client is responsible for saying so.
  Optionally add a non-negotiable `scope: "family"` field so the client can render truthfully from
  data instead of hard-coded prose (this is a minimal additive change and is the one part of B worth
  requiring regardless of the A/B decision).

### Backward compatibility
- Zero: no response field changes meaning, so an old build renders the same numbers with the same
  meaning. A new child UI card is additive navigation. Cached-UI fallback
  (`parent_settings_controller.dart:69-82`) unaffected. Child export unaffected.
- The compat cost moves to the **human** side: an old build shows the counts without any new
  sentence, and any build whose UI the child cannot reach shows nothing at all.

### Required tests
- Dart widget: the child retention card renders the family-scope sentence (new surface) or, for the
  parent-only variant, pin `settings_body.dart:165` — currently unpinned by any test (grep hits only
  the source line).
- Deno: unchanged server behaviour needs no new Deno test; a contract test asserting `scope` is
  returned if that field is added.
- SQL: none (behaviour unchanged).

### Cost
Lowest: a contract paragraph plus one unpinned-string test; plus one new child widget and one
controller call path if "Child UI" is read literally.

### Residual risk after shipping B
1. Disclosure does not bind the endpoint. A child calling `account` with their own JWT
   (`supabase/config.toml:81-82` `verify_jwt = true` only requires *a* valid user JWT) still receives
   sibling aggregates and project-wide totals. UI wording cannot reduce what the API answers; it can
   only make the reading of it deliberate.
2. GDPR/CCSR-style "my data" expectations: a child asking "how long is *my* data kept" receives a
   number that includes their siblings. Disclosed, but still not the answer to the question asked.
3. The child shell disclosure invites the reverse problem — surfacing family data to a child **in
   order to warn them about it** creates the very sibling visibility A avoids.

## 1.4 Recommendation (not a decision)

**Recommend A**, scoped narrowly: child-scope the two counts by the caller's own devices (mirroring
the already-shipped `export` predicate at `index.ts:153-177`), add an explicit `scope` field, and
redact `last_sweep`'s global totals for child callers. Reasons, in order of weight:

1. A makes `retention_report` agree with `export`. Today the same child, in the same Settings card,
   gets a row-scoped answer from one action and a family-scoped answer from the other
   (`index.ts:154-158` vs `:401-410`). Two implementations of "what is my data" is the pattern Phase 2
   was told to stop creating.
2. B's disclosure cannot constrain the server. The exposure is an API answer, not a rendered screen
   (`child_settings_tab.dart:29-77` shows no retention at all), so a wording fix under B removes no
   access and adds a new child-facing surface to hold it.
3. A leaks nothing that RLS already grants, and B leaks aggregates that RLS deliberately withholds
   (`rls.sql:113-129`, `:236-240`).
4. A's cost is bounded and schema-free; B's literal cost is a new UI surface.

If the owner prefers the least code, the middle path already documented before this workstream is
**parent-only gating** of `retention_report` (`remaining-gaps.md:103` — "Decide parent-only vs
member-wide; if parent-only, add `requireRole`-style gating in the handler"): one line
(`requireRole(auth.profile, "parent")` at `index.ts:466`-equivalent) closes the child exposure but
removes the child's transparency answer entirely, which is a privacy-regression trade the owner, not
this workstream, should weigh.

**The decision is the owner's. No behaviour, file or contract was changed by this workstream.**
Nothing above is deployed or executed; `account` remains undeployed (`phase-2-open-gaps.md:14`).

## 1.5 WORD-02 interaction (recorded, not decided here)

`AccountDataExport.isChildExport` (`account_privacy_repository.dart:41-42`) is `true` only when
`payload.profile.role === 'child'`, so an absent or unexpected role falls through to the
**parent/family-scoped** sentence at `export_result_dialog.dart:79-82`. Same card, two different
scope-derivation styles: the retention block derives nothing from role and hard-codes the family
sentence (`settings_body.dart:162-167`, `:179-186`), while the export block derives from a role
boolean with a parent default.

Consequences for PRIV-01:
- If **A** is chosen, hard-coding the family sentence becomes factually wrong for a child caller, and
  reusing the `isChildExport`-style boolean would reproduce WORD-02's defect in a new place (an
  unknown role rendered as family-scoped). A must render from a server-supplied `scope` value, with
  an explicit "scope not reported" third state — never a boolean.
- If **B** is chosen, the two blocks agree by accident, and WORD-02's understatement is limited to
  the malformed-payload case the server cannot produce (`_shared/auth.ts:115-117` rejects a role
  outside `unset|parent|child`).
- Either way the retention disclosure string at `settings_body.dart:165` has no test pinning it, so
  it can drift silently; that is worth fixing independently of A/B.

## 1.6 What this workstream refuses to decide

1. Whether the child's transparency right outweighs sibling-aggregate confidentiality (A vs B) — an
   owner/product decision; both are implemented-cost-quantified above.
2. Whether to keep returning `last_sweep` metadata at all. The stored row is global by design
   (`20261030000300_retention_sweep.sql:232-247`) and the parent UI already describes it as global
   (`settings_body.dart:230-238`); whether a child should see the timestamp is a policy call.
3. Whether to per-device-break-down Option A's counts or aggregate over the child's own devices. The
   draft above aggregates (matching `export`); the owner may prefer per-device.
4. Whether to gate the action to parents (`remaining-gaps.md:103`) — listed for completeness, not
   recommended here.
5. Any claim about hosted behaviour. Nothing was called; the endpoint is not deployed.

---

# 2. GOV-02 — abandoned-session representation: decision memo for the owner

## 2.1 Question put to the owner

`docs/implementation/phase-2-open-gaps.md:52` (GOV-02) records that contract amendment **D1** —
how a system-closed session is represented — has **no owner-level signature**. This memo is the
artifact the owner signs or rejects. It is not a ratification.

**Line-number caveat.** Three files were being edited by other Phase 3 workstreams while this memo was
written: `20261030000100_abandoned_session_sweep.sql` (grew from 121 to 160 lines — the SQL-02
expression index was implemented), `20261030000200_phase1_authorization.sql` (361 → 491 lines) and
`supabase/functions/family-admin/index.ts` (the `delete_zone` compensation path). All citations below
were re-checked against the tree at the moment of writing and point at the **current** lines; the
`ended_by`/`ended_reason` pair is now at `20261030000100…sql:126-127` (previously `:86-87`).

## 2.2 The constraint

| Fact | Evidence |
|---|---|
| The contract originally specified `ended_by = 'system'` | `docs/implementation/_work/coordinator-contract.md:42-43` ("Amended after workstream audit") records the original text and its amendment |
| `remote_sessions.ended_by` is a UUID foreign key, so the literal `'system'` is unrepresentable without a schema change | `supabase/migrations/20260101000000_core.sql:340` — `ended_by uuid references public.profiles (id) on delete set null` |
| `profiles.id` itself is an FK to `auth.users`, so a synthetic "system profile" needs a real Auth user | `core.sql:18` — `id uuid primary key references auth.users (id) on delete cascade`; `core.sql:19-20` role check `unset|parent|child` |
| `ended_reason` is free text ≤ 200 chars, so it can carry the marker | `core.sql:341` |
| Phase 1 forbade new tables and new columns | `coordinator-contract.md:21-23`; restated at `api-contract.md:177` and `:255-256` |
| The audit ledger has the same shape, so the actor-less write has the same cause | `core.sql:378` (`actor_user_id uuid … on delete set null`); `20261030000100_abandoned_session_sweep.sql:141-149` passes `null` for it |

## 2.3 Shipped representation (in the working tree, not applied)

- `status='expired'`, `ended_at=now()`, **`ended_by = null`**, **`ended_reason = 'abandoned'`** —
  `supabase/migrations/20261030000100_abandoned_session_sweep.sql:123-127`.
- One audit row per closed session: `event_type='session_expired'`, `actor_user_id = null`,
  `metadata = {"reason":"abandoned","age_seconds":N}` — `…abandoned_session_sweep.sql:141-149`.
- The intended reading is documented in the migration header itself: *"Any consumer that needs 'who
  ended it' must read the pair (ended_reason, ended_by)"* —
  `20261030000100_abandoned_session_sweep.sql:22-29`.
- Ratification status: the amendment was written by the session workstream
  (`_work/session.md:31-38`), reported as a contract deviation D1 by
  `_work/contracts.md:8-10`, amended into the contract at `coordinator-contract.md:41-43`, and
  **ratified by the reviewing coordinator only** (`phase-1-report.md:363`; restated
  `phase-2-governance.md:30`, `:34-36`). **This is not an owner-level signature and must not be
  presented as one.**

## 2.4 Consumers that key on the pair (every one, with citations)

| # | Consumer | What it keys on | Evidence |
|---|---|---|---|
| 1 | The sweeper itself (writes the pair) | `ended_by = null` + `ended_reason = 'abandoned'` | `20261030000100_abandoned_session_sweep.sql:126-127` (inside the `update` at `:123-129`); header `:22-29` |
| 2 | Audit metadata written beside it | `actor_user_id = null`, `metadata.reason = 'abandoned'` | `20261030000100_abandoned_session_sweep.sql:141-149` |
| 3 | RPC invocation contract (name + arg only, never the pair) | `expire_abandoned_sessions(p_max_age)` | `supabase/functions/_shared/remote_session_lifecycle.ts:13`, `:31-50`; `supabase/functions/cron/index.ts:84-86`; `supabase/functions/remote-session/index.ts:125-133` |
| 4 | SQL authorization/regression test | asserts **both** halves: `v_reason = 'abandoned'` **and** `v_ended_by is null`, with the message "ended_by is a profiles uuid: a system close must leave it null" | `supabase/tests/63_abandoned_session_sweep.sql:136-148`; also `:204-214` (audit metadata) and `:251-254` |
| 5 | Schema regression test | asserts `remote_sessions` → `profiles` FK set is exactly `{child_user_id, ended_by, parent_user_id}` | `supabase/tests/10_schema.sql:95-99` |
| 6 | Deno handler tests (the *contrasting* actor-bearing path) | `ended_by = parentId` for a parent end, and "a child id never reaches ended_by"; declined patch carries `ended_reason` only | `supabase/functions/remote-session/guard.ts:133-153`, `:184-192`; tested at `guard_test.ts:192-200` and `lifecycle_test.ts:114-120` |
| 7 | Dart model | reads `ended_reason` **only**; there is no `endedBy` field, so no Dart consumer keys on `ended_by` | `lib/data/models/remote_session.dart:88`, `:110`, `:189`, `:209` (serialize `:209`) |
| 8 | Parent session UI | prints `Reason: <endedReason>` **only** for `status == ended`; an abandoned row is `expired`, and the expired branch (`:653-654`) prints fixed text | `lib/features/remote_assistance/remote_session_page.dart:653-657` |
| 9 | Child session UI | same structure; `expired` prints `'The request expired. No media was opened.'` | `lib/features/child/child_session_page.dart:736-740` |
| 10 | Contract + governance prose | vocabulary row `remote_sessions system closure → ended_by = null + ended_reason = 'abandoned'` | `docs/implementation/api-contract.md:231`; `coordinator-contract.md:41-43`; `phase-2-governance.md:30` |
| 11 | Other system closes that do **not** set `ended_by` at all — the reason `ended_by IS NULL` is not self-sufficient and the *pair* is required | `ended_reason='expired'` with `ended_by` untouched | `supabase/functions/remote-session/index.ts:94`, `:188`; `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql:92`, `:140`; `20260101000100_functions.sql:523`; `20261030000200_phase1_authorization.sql:262`; and the two actor-bearing admin paths `20260101000100_functions.sql:391-392`, `:477-478` |
| 12 | `session_expired` audit vocabulary | `api-contract.md:230` and `:220` (`event_type` is free text) | `docs/implementation/api-contract.md:220`, `:230` |

Note on #8/#9 as a consumer pair: because the sweep sets `status='expired'`, the string `'abandoned'`
is **never rendered** by either UI today — the parent and child screens print generic expiry text for
`expired` (`remote_session_page.dart:653-654`, `child_session_page.dart:739-740`). Whatever the owner
decides, the marker is currently ledger-only. That is a P2 honesty gap in its own right (a user
cannot tell "nobody came back" from "the pending request timed out"), independent of the
representation question.

## 2.5 What breaks if the owner rejects D1 and demands a different representation

The blast radius is small **now** and large **after deploy** — the migration is unapplied
(`phase-2-open-gaps.md:13`), so today the change is a text edit to one `SET` list, one test file and
four document lines: `20261030000100…sql:126-127` and `:22-29`, `supabase/tests/63…sql:136-148`,
`:204-214`, `api-contract.md:231`, `coordinator-contract.md:41-43`. After deployment it becomes a
data migration over rows already closed with reason `'abandoned'`, plus every app build in the field
that reads `ended_reason`.

Concrete breakage by alternative:

**Alternative 1 — sentinel UUID (a seeded "system" profile).**
- Requires a row in `auth.users` before `profiles` will accept it (`core.sql:18`), i.e. a real,
  sign-in-capable identity: new secret surface, new account in Auth user counts, and a role value that
  must be `unset`, `parent` or `child` (`core.sql:19-20`) — no fourth value exists without a schema
  change. A sentinel with `role='parent'` would satisfy every `is_family_parent`-style predicate it
  never appears in (`rls.sql:236-240` reads `family_id`, not `actor`), but it would still be a
  profile row that UI name lookups can join (`lib/data/models/remote_session.dart:191-193`).
- Deletes the marker by accident: the FK is `on delete set null` (`core.sql:340`), so removing or
  losing the sentinel row silently rewrites history back to `ended_by = null`. The same hazard already
  applies to real parents and is relied upon by the account-deletion path: `actor_user_id` is nulled
  by the FK when the profile row goes away, which is why the audit record is written *before*
  deletion (`supabase/functions/account/index.ts:307-322`; `core.sql:378`).
- Inconsistency: the other four system closes (`index.ts:94`, `:188`;
  `20261028000200…:92`, `:140`; `20260101000100_functions.sql:523`) leave `ended_by` untouched, so
  either they are all converted (5 SQL/TS sites) or the sentinel marks only abandonment and `NULL`
  stays ambiguous — the original problem, relocated.
- Costs: one data migration + one test rewrite + `10_schema.sql:95-99` still passes (the FK is
  unchanged) + a documented secret-ownership question. No schema change, so it is the cheapest
  "non-NULL actor" variant and the most fragile.

**Alternative 2 — new column (e.g. `ended_by_kind text`).**
- Directly violates `coordinator-contract.md:21-23` ("No new columns on existing tables") and
  `api-contract.md:177`; `api-contract.md:255-256` requires approval for it — which is exactly the
  approval the owner can give, so it is legal **post-decision**, not before.
- Migration: `ALTER TABLE public.remote_sessions ADD COLUMN …` (cheap, no rewrite for a nullable
  text), then update the sweep `SET` list (`:123-129`), the vocabulary tables (`api-contract.md:226-233`
  gains a row), the Dart model (`remote_session.dart:88`, `:110`, `:189`, `:209`) and both UI message
  builders, plus `63_abandoned_session_sweep.sql:136-148`. `10_schema.sql` is unaffected.
- Envelope safety: `ended_by_kind` never reaches the client unless `remote-session` selects it, so old
  builds are unaffected — the cleanest backward-compat profile of the three.

**Alternative 3 — relax the actor-less FK (drop the constraint / retype `ended_by` as text).**
- Breaks `supabase/tests/10_schema.sql:95-99` outright (it asserts the exact FK set).
- Loses referential integrity and, more importantly, loses `on delete set null` (`core.sql:340`): a
  deleted parent's UUID would then **survive** account deletion, turning an existing privacy property
  of the schema into a data-retention defect. Treat that as a P1 consequence of a formatting choice.
- `ALTER COLUMN TYPE uuid → text` rewrites the table under an `ACCESS EXCLUSIVE` lock; on a hosted
  database that is a downtime-window operation, and it changes the embedded/`select` typing every
  consumer sees.
- Also lets a caller-supplied string into an actor column — the reason the current code derives
  `ended_by` server-side and ignores the client (`guard.ts:140`, `:150`) would need re-arguing.

**Alternative 4 — keep the pair but make it verifiable.** No schema change: state the rule in the
contract as a check (e.g. a `CHECK` constraint or trigger forbidding `ended_reason='abandoned'`
unless `ended_by IS NULL`, and vice versa). Costs one migration file, keeps `10_schema.sql` green, and
converts today's comment (`20261030000100…sql:28-29`) into an enforced invariant. This is the only
alternative that closes the drift risk without touching the column set; it is offered as analysis,
not as a recommendation the workstream is entitled to make.

## 2.6 What the owner is being asked to sign

1. **Ratify** `ended_by = NULL` + `ended_reason = 'abandoned'` as the system marker (D1 as shipped),
   and record that consumers must key on the pair, per `20261030000100…sql:28-29` — or
2. **Reject** it and pick one of Alternatives 1–4 above, understanding the pre-deploy vs post-deploy
   cost difference in §2.5.

Either way, two items are **not** part of D1 and stay open: the marker is never surfaced in either
session UI (§2.4 #8/#9), and the four `expired` writers in §2.4 #11 leave `ended_by` untouched, so
`ended_by IS NULL` alone is ambiguous regardless of what the owner signs.

## 2.7 Refusals

- This workstream does not ratify, countersign or restate the coordinator's ratification as the
  owner's. `phase-2-governance.md:34-36` is the accurate description of the current ceiling.
- No file was changed; no migration applied; no function deployed; no hosted object inspected.
- No opinion is expressed on which representation the product should prefer beyond the cost analysis
  in §2.5.
