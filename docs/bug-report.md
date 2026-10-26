# Bug report

Date: 2026-10-26
Workspace: `D:\parentcontrol_app`
Toolchain: FVM Flutter 3.44.6 / Dart 3.12.2, Deno 2.9.4, PostgreSQL 16.9 (local).

Severity: **P0** crash/data loss/security bypass, **P1** user-visible broken core
flow, **P2** incorrect or unreliable behavior, **P3** documentation/polish.
Labels: **FIXED — VERIFIED BY TEST**, **FIXED — ANALYZER/BUILD VERIFIED**,
**FIXED — NOT DEVICE TESTED**, **OPEN**, **BLOCKED**, **NOT TESTED**.

## BUG-001 — Child shell never performed its first load (P1)

**Status:** FIXED — VERIFIED BY TEST (`child_shell_controller_test.dart`).
**Component:** [lib/features/child/controllers/child_shell_controller.dart](../lib/features/child/controllers/child_shell_controller.dart)

**Reproduction:** Sign in as a child, link a family, open `My phone` (child shell)
with a reachable backend.

**Expected:** The shell loads membership, device, policy and pending requests and
leaves the loading state.

**Actual:** `isLoading` was initialized to `true`, and `load()` started with
`if (isLoading.value || isRefreshing.value) return;`. Therefore every call to
`load()` — including `onInit()` and the retry button — returned immediately.
`isLoading` stayed `true` and the screen could remain on the loading state
indefinitely, with no server calls.

**Cause:** Conflating the initial UI state (`isLoading = true`) with the
re-entrancy guard.

**Fix:** Replaced the guard with an explicit `_loadInFlight` boolean; `isLoading`
is now only an observable UI state. The `finally` block always clears it.

**Evidence:** `flutter test test/features/child` → the test
`performs the first load instead of staying on the loading state` asserts the
family/device load, `lastLoadedAt`, session state and `isLoading == false`.
Before the fix this test could not pass because `fetchMyMembership` was never
called.

## BUG-002 — Declining pairing/assistance did not refresh the child inbox (P2)

**Status:** FIXED — VERIFIED BY TEST (`child_requests_controller_test.dart`).
**Component:** [lib/features/child/controllers/child_requests_controller.dart](../lib/features/child/controllers/child_requests_controller.dart)

**Reproduction:** On the child device open the requests inbox with a pending
pairing request or assistance request, then tap **Decline**.

**Expected:** The declined item disappears promptly because the list reloads
after the server confirms the response.

**Actual:** Both `_respondPairing` and `_respondSession` called
`await load(showLoading: false)` while `isResponding` was still `true`. `load()`
returns early when `isResponding` is true, so the list was not refreshed until the
next 15-second poll. A declined request could remain visible and tappable-looking
even though the server had already recorded the answer.

**Fix:** Set `isResponding` to `false` before the reload in both decline paths
(the accept path already did this before navigation). The `finally` block keeps
the flag correct on errors.

**Evidence:** `declining a pairing request never links the family`,
`declining an assistance request returns to the inbox` and
`offline actions fail loudly and send nothing to the server` pass. The server
`respond` call is verified exactly once; no optimistic list mutation claims a
rejected request was accepted.

## BUG-003 — Child could never join a consented remote-assistance session (P1)

**Status:** FIXED — ANALYZER + UNIT TEST VERIFIED; media path NOT DEVICE TESTED.
**Components:** [lib/features/remote_assistance/remote_session_controller.dart](../lib/features/remote_assistance/remote_session_controller.dart),
[lib/features/child/child_session_page.dart](../lib/features/child/child_session_page.dart)

**Reproduction:** Parent requests video assistance; child accepts; child opens the
session screen and taps **Join**.

**Expected:** The child, as the answering peer, opens camera/microphone only after
its own explicit tap, applies the parent's offer, creates an answer and sends it.

**Actual:** The controller treated every non-parent role as view-only for joining,
`join()` refused non-parents, and there was no code path that applied an offer or
created an answer. The child session screen did not exist. A parent could
therefore obtain consent but never establish media.

**Fix:** Added a role-aware answerer flow: the child buffers the parent's offer,
`join()` opens media and answers the buffered offer, and `respond()` records
consent without opening any media. Added the child session UI with explicit join,
decline/end, expiry and privacy states.

**Evidence:** `flutter test test/features/remote_assistance` → 9 tests pass,
including `accepting only records consent and opens no media or negotiation`,
`child cannot start media before accepting the request`, and
`the parent side cannot answer a request for the child`. Analyzer is clean.
This is **not** proof that audio/video connect on a physical device; TURN is not
configured and the media path is NOT DEVICE TESTED.

## BUG-004 — Late-joining child could miss the parent's WebRTC offer (P2)

**Status:** FIXED — ANALYZER VERIFIED; realtime behavior NOT DEVICE TESTED.
**Components:** [lib/data/repositories/supabase_remote_session_repository.dart](../lib/data/repositories/supabase_remote_session_repository.dart),
[lib/features/remote_assistance/remote_session_controller.dart](../lib/features/remote_assistance/remote_session_controller.dart)

**Reproduction:** Parent sends the offer while the child is still opening the
session screen and subscribing to Realtime.

**Expected:** The child still applies the offer and answers.

**Actual:** The signaling subscription only received new `INSERT` events. An
offer inserted before the child subscribed was never delivered, so the child
could open its camera but no media negotiation completed.

**Fix:** After subscribing, replay stored signals ordered by `sequence`, and keep
the newest offer in `_pendingOffer` so `join()` can answer it even if the offer
arrived before the peer connection existed. Processed signal ids are deduplicated
so replay plus realtime do not apply a signal twice.

**Evidence:** Analyzer clean; child-role tests exercise join/consent separation.
Realtime delivery itself requires a deployed Supabase project and two physical
devices, so it is **NOT TESTED**.

## BUG-005 — Backend docs claimed the SQL authorization tests were never run (P3)

**Status:** FIXED — DOCUMENTATION.
**Components:** [docs/backend.md](backend.md), [supabase/tests/README.md](../supabase/tests/README.md)

**Observed:** Both documents said the SQL/RLS tests had not been executed, while
the local PostgreSQL runs had in fact passed.

**Fix:** Documentation now records the exact fresh-database run and explicitly
limits the claim: plain PostgreSQL only, not a Supabase-hosted verification.

## BUG-006 — Backend docs cited a SQL pass banner that the log does not contain (P3)

**Status:** FIXED — DOCUMENTATION.
**Components:** [docs/backend.md](backend.md), [supabase/tests/README.md](../supabase/tests/README.md)

**Observed:** Both documents stated that the SQL test log ended with
`ALL SQL STEPS PASSED` and cited that as evidence. The stored run log
(`.tools/sql-tests-2.log`, gitignored) contains no such line; it ends after the
final `DO` blocks. The suite's actual success signal is `psql` exit 0 with
`ON_ERROR_STOP=1` and no `ERROR` or `ASSERTION FAILED` output.

**Fix:** Replaced the invented banner with the real evidence. Re-ran the whole
suite on a second fresh PostgreSQL 16.9 database (`parentcontrol_rls_final`) on
2026-10-26: `SQL_EXIT=0`, zero `ERROR`/`ASSERTION FAILED` lines
(`.tools/sql-tests-final.log`, gitignored). The claim remains limited to plain
PostgreSQL, not a Supabase project.

## BUG-007 — Debug APK did not compile (P1)

**Status:** FIXED — BUILD + INSTALL VERIFIED.
**Components:** [SecureStore.kt](../android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt),
[PolicyApplier.kt](../android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt)

**Reproduction:** Run the documented `flutter build apk --debug`.

**Expected:** The APK builds.

**Actual:** Two Kotlin compile errors surfaced once plugin compilation succeeded:

1. `SecureStore` declared `KEY_DEVICE_SECRET` twice — `"device_secret"` for the
   local identity and `"sync_device_secret"` for the background-sync credential.
   Every read/write was ambiguous (`Overload resolution ambiguity`).
2. `PolicyApplier.isSuspended()` called
   `DevicePolicyManager.isPackageSuspended(packageName)`, but the platform method
   requires the admin `ComponentName` first. The suspend/restore methods already
   passed the app's admin component.

**Fix:** Renamed the sync copy to `KEY_SYNC_DEVICE_SECRET` and used it in
`saveConfig`, `config` and `clearConfig`, so the local identity secret survives
sign-out while the copied sync credential is cleared with the sync configuration.
Passed the existing admin component to `isPackageSuspended`.

**Evidence:** `flutter build apk --debug` → `BUILD_EXIT=0`, APK 215,954,003
bytes at the time of this fix (the final rebuild after later fixes is
242,193,329 bytes); `adb install -r` → `Success`; activity resumed; logcat
contained no `FATAL`, `AndroidRuntime` or `E/flutter` entry.

## BUG-008 — Kotlin incremental compilation failed on Windows cross-drive paths (P2)

**Status:** FIXED — BUILD VERIFIED (workstation-specific workaround).
**Component:** [android/gradle.properties](../android/gradle.properties)

**Observed:** Four plugin Kotlin compile tasks failed with
`java.lang.IllegalArgumentException: this and base files have different roots:
C:\Users\ASUS\AppData\Local\Pub\Cache\... and D:\parentcontrol_app\android`,
followed by `Could not close incremental caches`. The same error occurred while
configuring plugin test tasks for `./gradlew testDebugUnitTest`.

**Cause:** The project is on `D:` and the Pub cache is on `C:`. Kotlin's
incremental cache converts source paths to paths relative to the module build
directory, which is impossible across Windows drive roots.

**Fix:** Set `kotlin.incremental=false` in `android/gradle.properties` (with a
comment). This only disables incremental Kotlin caching; it does not change app
behavior. Native tests are run with `:app:testDebugUnitTest
--configure-on-demand`, which avoids creating the plugin test tasks that trigger
the configuration-time failure.

**Evidence:** Plain `flutter build apk --debug` exits 0; the app-only JVM test
task runs 13/13 tests successfully.

## BUG-009 — `device-register` returned the stored credential hash to the client (P2)

**Status:** FIXED — DENO CHECK VERIFIED; hosted endpoint NOT DEPLOYED.
**Component:** [supabase/functions/device-register/index.ts](../supabase/functions/device-register/index.ts)

**Observed:** Both the re-credential update and the insert used `.select("*")`
and returned the full `devices` row, including `secret_hash`, to the caller.

**Impact:** The value is the SHA-256 hash of a 256-bit random device secret, so it
is not a usable credential and preimage attacks are infeasible. It is still
unnecessary credential metadata and violated the project's own data-minimization
rule; it would become more relevant if a weaker secret were ever accepted.

**Fix:** Added `publicDevice()`, which deletes `secret_hash` from the row before
responding, and applied it to both register paths.

**Evidence:** `deno check supabase/functions/device-register/index.ts` → exit 0;
the 23 shared Deno tests still pass. The deployed function has not been exercised
because no Supabase project exists yet.

## BUG-010 — Enrollment docs described the pairing direction backwards (P3)

**Status:** FIXED — DOCUMENTATION.
**Component:** [docs/device-enrollment.md](device-enrollment.md)

**Observed:** The guide said the Parent generates a one-time child code and the
Child redeems it. The implemented flow is the reverse: the Child device creates
the code/QR (`child_enrollment_page.dart:183`) and the Parent redeems it
(`pairing_redeem_page.dart:47`), after which the Child approves the request.

**Fix:** Rewrote the in-app steps to match the actual Child-generates /
Parent-redeems flow.

## BUG-011 — A revoked child could re-enroll with a new installation id (P1)

**Status:** FIXED — DENO VERIFIED; hosted endpoint NOT DEPLOYED.
**Component:** [supabase/functions/device-register/index.ts](../supabase/functions/device-register/index.ts),
[supabase/functions/_shared/enrollment.ts](../supabase/functions/_shared/enrollment.ts)

**Expected:** After a parent revokes a child device, that child cannot enroll
another device without fresh guardian approval; the contract says re-linking is
required.

**Actual:** The endpoint rejected only a revoked row with the *same*
`installation_id`. A child account that wiped app data (new installation id) passed
the active-device guard and inserted a fresh active device with a new secret. The
child login and family membership were still valid, so revocation could be undone
by the child alone.

**Fix:** `requiresRelink(revokedAt, latestApprovalAt)` now blocks any new or
re-credentialed enrollment while the latest revocation in that family is newer
than the latest approved pairing request. Clearing it requires the parent to unlink
the child and approve a new pairing (the only supported re-link path). Blocked
attempts are audited as `device_registration_blocked`.

**Evidence:** Three new Deno tests cover past/future approval, equal timestamps and
fail-closed invalid dates; all 26 shared tests pass and all nine entrypoints type
check. The recovery path uses the existing `unlink_child` + pairing approval flow.
Live two-account enrollment was **NOT TESTED** (no deployed project).

## BUG-012 — Table-wide device SELECT exposed `secret_hash` to clients (P2)

**Status:** FIXED — SQL VERIFIED LOCALLY; hosted project NOT DEPLOYED.
**Component:** [supabase/migrations/20260101000200_rls.sql](../supabase/migrations/20260101000200_rls.sql),
[lib/data/repositories/supabase_device_repository.dart](../lib/data/repositories/supabase_device_repository.dart)

**Observed:** `grant select on public.devices to authenticated` (and `.select()` in
the Flutter repository) exposed every column, including the verifier
`secret_hash`, to the parent and child clients through PostgREST.

**Impact:** The stored value is a SHA-256 hash of a 256-bit random secret, so it is
not directly usable and preimage attacks are infeasible. It is still credential
material that no client needs, and table-wide SELECT also exposed
`installation_id`.

**Fix:** Replaced the table grant with an explicit column grant that excludes
`secret_hash` and `installation_id`, and changed all three Flutter device queries
to request exactly the safe column list. Added schema assertions that
`authenticated` has no table-wide SELECT and no privilege on either sensitive
column.

**Evidence:** Fresh-database SQL suite exit 0 including the new grant assertions;
Flutter analyzer exit 0 and 98 tests pass. Hosted PostgREST behavior is
**UNVERIFIED** until deployed.

## BUG-013 — Heartbeat could set `policy_version` and imply enforcement (P2)

**Status:** FIXED — DENO/FLUTTER VERIFIED; hosted endpoint NOT DEPLOYED.
**Component:** [supabase/functions/device-telemetry/index.ts](../supabase/functions/device-telemetry/index.ts),
[supabase/functions/device-command/index.ts](../supabase/functions/device-command/index.ts)

**Observed:** `device-telemetry` action `heartbeat` accepted a device-supplied
`policy_version` and wrote it to `devices.policy_version`. The parent devices list
renders that value as `Policy vN`, so a device could claim a policy version it
never acknowledged.

**Fix:** Heartbeats no longer parse or store `policy_version`. Only a successful
`apply_policy` acknowledgement advances it, using the `version` returned from the
server-side `device_policies` row rather than the command payload. The Kotlin
guardian and the unused Dart heartbeat parameter no longer send it.

**Residual scope:** `capabilities.enforcement_mode` remains a device-reported
capability (the server cannot inspect the phone). The UI's enforcement status
still comes from `device_policies.enforcement_status`, which only changes on an
acknowledged command; the capability label alone is not treated as proof.

**Evidence:** `deno check` all nine entrypoints exit 0; 26 shared tests pass;
analyzer clean; 98 Flutter tests pass. Live command/ack flow is **NOT TESTED**.

## BUG-014 — Private Realtime channels had no `realtime.messages` policy (P1)

**Status:** FIXED — SQL VERIFIED LOCALLY; hosted subscription NOT TESTED.
**Component:** [supabase/migrations/20260101000200_rls.sql](../supabase/migrations/20260101000200_rls.sql)

**Observed:** The Flutter repositories subscribe with
`RealtimeChannelConfig(private: true)` for session, signal and alert topics, but
the migrations created no Realtime Authorization policy. Record delivery is
already filtered by the source-table RLS policies, but the channel layer had no
topic allowlist.

**Fix:** Added `private.realtime_topic_allowed(text)`, which admits only family
topics for active family members and session/signal topics for that session's
child or a parent in its family. A guarded `parentcontrol_private_topics` SELECT
policy on `realtime.messages` uses it, restricted to
`extension = 'postgres_changes'`. The policy is skipped with a notice when
`realtime.messages` does not exist (plain PostgreSQL tests). This is
defense-in-depth: Supabase documents `realtime.messages` authorization for
broadcast/presence, while Postgres Changes record delivery is governed by the
source tables' RLS. The app uses only `postgres_changes` and table RLS remains
the primary record filter.

**Evidence:** Local SQL tests cover own/cross-family, participant/non-participant,
unlinked and malformed topics. The actual policy DDL is exercised against a
local `realtime` stub (`supabase/tests/05_realtime_stub.sql`): the migration
creates `parentcontrol_private_topics`, `50_realtime_policy.sql` confirms the
`postgres_changes` filter and the family/session/malformed-topic gates, and the
full suite exits 0 on a fresh database. The stub proves only `realtime.messages`
ROW visibility; it is not the Realtime server. A real private subscription
against a hosted project is **NOT TESTED** because no project is deployed, so
whether hosted Realtime consults this policy for `postgres_changes` is
**UNVERIFIED**. Table RLS filtering of delivered rows is also **NOT TESTED**
against hosted Realtime.

## BUG-015 — Documented SQL test command silently skipped every file on Windows (P2)

**Status:** FIXED — DOCUMENTATION CORRECTED; SUITE RE-RUN AND PASSED.
**Component:** [supabase/tests/README.md](../supabase/tests/README.md),
[docs/backend.md](backend.md)

**Observed:** The documented invocation put the connection string first:
`psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f ...`. On Windows PostgreSQL 16.9,
`psql` does not permute arguments. It treated every option after the database
name as an extra argument, printed
`warning: extra command-line argument "-f" ignored` for each one, executed no
file, and exited 0. A check for `ERROR`/`ASSERTION FAILED` therefore also
returned zero, so the run looked green against an empty database.

**Impact:** Verification integrity. An operator following the README could record
a false PASS for the complete schema/RLS/RPC authorization suite even though
nothing was applied or tested.

**Fix:** Put all options before the connection argument and use
`-d "$DATABASE_URL"` last. Added a Windows note and a post-run sanity check: the
database must contain 18 public tables and the log must contain zero
`ERROR`/`ASSERTION FAILED` lines. `docs/backend.md` and the verification report
use the same corrected form.

**Evidence:** Re-ran on the new empty database `parentcontrol_final_20261026`
with `ON_ERROR_STOP=1`: `SQL_EXIT=0`, `ERRORS=0`, 18 public tables
(`.tools/sql-final2.log`, gitignored). The broken invocation emitted a warning
for every ignored option and applied no files; that output was observed before
the corrected run overwrote the log. The final suite, including the Realtime
policy and revocation tests, was rerun as `parentcontrol_final5_20261026` with
the same corrected form: `SQL_EXIT=0`, `ERRORS=0`, 18 public tables,
`realtime policy=1` (`.tools/sql-final5.log`).

## BUG-016 — Device revocation left pending pairing requests approvable (P1)

**Status:** FIXED — SQL VERIFIED LOCALLY; hosted re-enrollment flow NOT TESTED.
**Component:** [supabase/migrations/20260101000100_functions.sql](../supabase/migrations/20260101000100_functions.sql),
[supabase/tests/40_functions.sql](../supabase/tests/40_functions.sql)

**Expected:** After a parent revokes a child device, re-enrollment requires the
parent to remove and re-link the child (`device_revoked` gate in
`device-register`).
**Actual:** `revoke_device` revoked the credential and ended sessions but left
`pairing_requests` in `pending_child`. A request redeemed by a parent *before*
the revocation could be approved by the child *after* it. That approval's
`responded_at` is later than `credential_revoked_at`, so `requiresRelink()`
returned false and the child could register a new device without any fresh
parent action. This undermined the BUG-011 fix.

**Fix:** `private.revoke_device` now cancels `pending_child` pairing requests for
that child in the device's family. Requests in another family are deliberately
untouched, so a legitimate re-link in a new family is not blocked by an old
revocation.

**Evidence:** `40_functions.sql` now inserts a pending request for the same child
in another family, revokes `v_device7`, and asserts the family request becomes
`cancelled` while the other family's request stays `pending_child`. The full
suite passed on the fresh database `parentcontrol_final5_20261026`
(`SQL_EXIT=0`, 0 errors/assertions, 18 tables), and a direct query confirmed the
two request states and `device7 = revoked`. The hosted Edge Function gate itself
is not integration tested.

## BUG-017 — `device-command` `apply_policy` ack could never update policy state (P2)

**Status:** FIXED — DENO TYPE CHECK PASSED; endpoint NOT INTEGRATION TESTED.
**Component:** [supabase/functions/device-command/index.ts](../supabase/functions/device-command/index.ts)

**Expected:** An `apply_policy` command carries `policy_id`; the ack updates
`device_policies.acknowledged_at/enforcement_status` and, on success,
`devices.policy_version`.
**Actual:** The normal `device-policy` path creates commands through
`apply_policy_version`, which includes `policy_id`. But the generic
`device-command` `create` path validated the payload down to `{policy}` and
inserted it directly. Its `policy_id` was undefined, so the ack's reconciliation
block was skipped silently: the child applied the policy, but the parent UI
never saw it acknowledged or enforced.

**Fix:** `device-command` `create` now routes `apply_policy` through
`apply_policy_version` using the caller's idempotency key, so the command payload
always includes `{policy_id, version, policy}` and a versioned
`device_policies` row exists. Added `policy_updated` and `command_created`
audits for new versions; idempotent repeats do not duplicate audits.

**Evidence:** `deno check` passes. The existing `apply_policy_version` SQL tests
cover version creation and idempotency; the HTTP endpoint itself is not
integration tested because no hosted project exists.

## BUG-018 — Email confirmation could dead-end with no session (P2)

**Status:** FIXED — ANALYZER/TEST SUITE PASSED; live email flow NOT TESTED.
**Component:** [lib/data/repositories/supabase_auth_repository.dart](../lib/data/repositories/supabase_auth_repository.dart),
[lib/features/auth/controllers/verify_email_controller.dart](../lib/features/auth/controllers/verify_email_controller.dart),
[android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)

**Expected:** After sign-up with email confirmation enabled, opening the
confirmation link returns the user to the app with a session and the app checks
`email_confirmed_at`.
**Actual:** `signUp`/`resend` sent no `emailRedirectTo`, no Android intent filter
existed for a callback scheme, and `refreshEmailVerification()` returns false
when `currentSession == null`. Sign-up with confirmation required produces no
session, so “I verified my email” could only fail until the user signed out and
signed in again from another screen.

**Fix:** Added `Env.authRedirectUrl = parentcontrol://auth-callback`, passed it to
both `signUp` and `resend`, added the matching VIEW/BROWSABLE intent filter, and
made the verify controller listen for auth-state changes so the SDK's PKCE code
exchange navigates automatically. Added an explicit “Already verified? Sign in”
fallback for links opened on another device. The Supabase redirect allowlist must
contain the same URL ([backend.md](backend.md)).

**Evidence:** Analyzer and Flutter tests pass; the manifest contains the intent
filter. A real confirmation email, deep link and hosted PKCE exchange are
**NOT TESTED** because no hosted project exists.

## BUG-019 — Client config accepted privileged keys and remote plain HTTP (P2)

**Status:** FIXED — UNIT TESTED.
**Component:** [lib/core/config/env.dart](../lib/core/config/env.dart)

**Expected:** The app refuses a service-role/secret key and never sends account
credentials over plain HTTP to a remote host.
**Actual:** `Env.isBackendConfigured` accepted any non-empty key and both
`http`/`https` for any host. A pasted service-role key would be compiled into the
APK without an explicit warning. `device-register` also echoed
`installation_id`, which the column grants treat as service-only.

**Fix:** `Env.backendConfigurationProblem` now requires HTTPS except for
localhost/127.0.0.1/::1/10.0.2.2, rejects `sb_secret_` keys and JWTs whose
`role` is `service_role`, and returns a specific operator message. The
configuration screen shows the rejection and the service reports it in
`initError`. `device-register` no longer returns `installation_id`.

**Evidence:** New `test/core/config/env_test.dart` covers missing values,
malformed URLs, remote HTTP, local HTTP, anon/publishable keys and privileged
keys. This is a client-side guard, not a substitute for keeping server keys out
of the build pipeline.

## BUG-020 — Secret examples encouraged values in shell history (P3)

**Status:** FIXED — DOCUMENTATION CORRECTED.
**Component:** [docs/backend.md](backend.md), [.gitignore](../.gitignore)

**Observed:** The Edge secret example passed `CRON_SECRET`, `TURN_SECRET` and
other values as command-line arguments, which are retained in shell history and
process listings. `secrets.env` and `supabase/.temp/` were not gitignored.
**Fix:** The runbook now uses `supabase secrets set --env-file secrets.env` and
states why inline values are prohibited; `.gitignore` covers `secrets.env`,
`*.secrets.env` and `supabase/.temp/`.

## BUG-021 — Private Realtime rejected every subscriber (P1)

**Status:** FIXED — HOSTED VERIFIED.
**Component:** [supabase/migrations/20260101000200_rls.sql](../supabase/migrations/20260101000200_rls.sql),
hosted `realtime.messages` policy.

**Expected:** An authenticated family member or session participant can join the
matching private topic; a foreign parent and an anonymous client are rejected.

**Actual:** The SELECT policy required
`realtime.messages.extension = 'postgres_changes'`. That column is populated for
delivered rows, but a channel join is authorized against the topic before any
message row exists, so the predicate was false for everyone. All private
subscriptions returned `Unauthorized: ...`, including the legitimate parent and
child.

**Fix:** Authorize on the topic alone through
`private.realtime_topic_allowed(realtime.topic())`, guarded so the policy is only
created when `realtime.messages` exists. Row delivery remains filtered by each
source table's RLS.

**Evidence:** Hosted probe after applying the policy in the SQL Editor:
parent A, child A and the remote-session participant reached `SUBSCRIBED`; parent B
and an anon client received `CHANNEL_ERROR ... Unauthorized` for family A's topic.
The hosted dashboard confirmed the policy DDL with “Success. No rows returned”.

## BUG-022 — Lists inside `SectionCard` raised framework assertions (P2)

**Status:** FIXED — DEVICE VERIFIED.
**Component:** [lib/core/widgets/section_card.dart](../lib/core/widgets/section_card.dart)

**Expected:** Cards containing `ListTile`/`SwitchListTile` render and respond to
taps without framework assertions.

**Actual:** `SectionCard` wrapped its column in a decorated `Container`. The
`ListTile`s therefore had no `Material` ancestor, which raises “ListTile
background color or ink splashes may be invisible” and blocks a clean test run.
Thirteen such assertions occurred during the physical-device enrollment flow.

**Fix:** Wrap the card contents in `Material(type: MaterialType.transparency)`, so
the decoration is preserved and the tiles get a Material ancestor.

**Evidence:** `flutter analyze` → no issues; `flutter test` → 98/98; the
on-device integration run proceeded through enrollment and the shell with no
ListTile assertion.

## BUG-023 — Edge Functions had no server-role table privileges (P1)

**Status:** FIXED — HOSTED VERIFIED.
**Component:** [supabase/migrations/20260101000300_service_role_grants.sql](../supabase/migrations/20260101000300_service_role_grants.sql)

**Expected:** Edge Functions, which use the auto-injected service-role client for
every write, can read and write the public tables.

**Actual:** The migrations granted privileges to `anon` and `authenticated` only.
`service_role` has `BYPASSRLS`, which skips policies but does not grant table or
sequence privileges, so the server client could not perform the writes the
functions depend on.

**Fix:** Added an explicit service-role migration granting `usage` on schema
`public`, CRUD on all tables, sequence usage/select, and matching default
privileges for future objects. RLS stays enabled everywhere; no client policy was
broadened.

**Evidence:** The migration was applied in the hosted SQL Editor, and the hosted
auth, pairing and device suites then passed (24/24, 42/42 and 6/6). Before the
grant, those server-side writes were not possible.

## BUG-024 — A reinstalled phone cannot recover its device credential (P2)

**Status:** OPEN — WORKAROUND EXISTS.
**Components:** [lib/features/child/child_shell_controller.dart](../lib/features/child/child_shell_controller.dart),
[supabase/functions/device-register/index.ts](../supabase/functions/device-register/index.ts)

**Reproduction:** Enroll a child phone; clear app data or reinstall; sign in as
the linked child.

**Expected:** The app detects that it has no valid device credential and either
re-registers (when allowed) or tells the user that a parent must unlink and re-link
the child.

**Actual:** The child shell loads the server device row and reports “Device setup
Registered”, but the local sync credential is gone. The guardian then fails every
heartbeat with “Heartbeat failed: Device credentials are not valid.”, and no UI
action prompts recovery. Registering the new installation is rejected by
`device-register` with `409 device_already_registered` while the old active row
exists. Only a parent unlink → new pairing code → child approval → fresh install
restores background protection.

**Impact:** After data loss, background protection silently stays non-functional
while the parent UI still lists the phone as the active device. The server
fail-closed behavior is correct; the client recovery path is missing.

**Workaround:** Parent unlinks the child, the child creates a new linking code,
the parent redeems it, the child approves, then the app is reinstalled and
re-enrolled. This was executed twice against the hosted project (6/6 assertions
per run).

**Fix direction (not implemented):** On a `401/403` from the sync endpoint, mark
the local enrollment invalid and surface a “Re-link this phone” action. Do not let
the client replace an active device row by itself; keep the revocation gate.

## BUG-025 — The live harness could report failures as passes (P2)

**Status:** FIXED — RERUN AND VERIFIED.
**Component:** [.tools/live/verify_devices.mjs](../.tools/live/verify_devices.mjs) (gitignored harness)

**Observed:** The helper `pass(cond, name, detail)` called `record(status, name)`
while `record` expects `(name, status, detail)`. Every assertion was stored with
its name in the status field, so failures would also have looked like passes. A
second defect read `iceServers` while the server returns `ice_servers`, producing
a false TURN assertion.

**Impact:** Verification integrity. The first reported 42/42 was not trustworthy.

**Fix:** `record(name, cond ? 'PASS' : 'FAIL', detail)` and the correct ICE field.
The suite was rerun; `phase2.json` now stores per-check statuses and the rerun
genuinely passed 42/42. Hosted result files are timestamped so earlier runs remain
distinguishable.

## Open / not tested

No open P0 is known. One open P2 remains: **BUG-024**, the missing recovery path
after app data loss. The following are **NOT TESTED**, **BLOCKED** or
**NOT CONFIGURED**, not passes:

- Hosted email delivery: no custom SMTP provider. The confirmation/reset email
  round-trip and the deep link are not exercised end to end.
- FCM: no Firebase project or `google-services.json`.
- TURN: no `TURN_URL`/`TURN_SECRET`; ICE returns STUN-only with
  `turn_configured:false`.
- Device Owner provisioning and `setPackagesSuspended()` on the realme RMX2161:
  the phone is not Device Owner, so Instagram suspension and reboot persistence
  are blocked.
- Two-device WebRTC media: only one physical phone is connected. Signaling,
  session authorization and ICE response were verified server-side; no media
  path between two devices was exercised.
- Backups/restore: not configured or verified.
- Parent screens on a physical device: parent flows were exercised through the
  hosted API harness, not by driving the parent UI on the phone.
- Usage Access and location uploads from the physical phone: the guardian service
  starts and heartbeats, but Usage Access is denied on this phone, so the usage
  upload path is not tested. Location sharing was not started.
