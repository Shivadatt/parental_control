# Bug report

Date: 2026-10-28 (initial pass 2026-10-26; parent UI journey, device
capabilities, BUG-024 recovery and APK-size work added on 2026-10-27; Child ID
production deployment, Phase 4 live matrix and the Phase 5 two-device journey
added the same day; complete two-device QA on the emulator + realme RMX2161,
including unlink/relink, heartbeat, policy and remote-assistance checks, added on
2026-10-28)
Workspace: `D:\parentcontrol_app`
Toolchain: FVM Flutter 3.44.6 / Dart 3.12.2, Deno 2.9.4, PostgreSQL 16.9 (local).

Severity: **P0** crash/data loss/security bypass, **P1** user-visible broken core
flow, **P2** incorrect or unreliable behavior, **P3** documentation/polish.
Labels: **FIXED — VERIFIED BY TEST**, **FIXED — ANALYZER/BUILD VERIFIED**,
**FIXED — NOT DEVICE TESTED**, **OPEN**, **BLOCKED**, **NOT TESTED**.

Status lines record the evidence available when the entry was last touched.
Several early entries say "not deployed" or "hosted NOT TESTED" because they
predate the hosted deployment; the current hosted and device state for those
areas is recorded in [verification-report.md](verification-report.md). BUG-032 to
BUG-034 were re-verified against the production deployment on 2026-10-27 and
carry live status lines below.

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
bytes at the time of this fix. After later fixes the normal build is 242,192,247
bytes (SHA-256 `1349075f…5e3201`); `adb install -r` → `Success`; activity
resumed; logcat contained no `FATAL`, `AndroidRuntime` or `E/flutter` entry.

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

**Status:** FIXED — DENO CHECK VERIFIED; hosted endpoint exercised (the field's
response shape was not separately re-asserted after deployment).
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
the shared Deno tests pass. The hosted `device-register` path was exercised in
Phase 2 (`device.register` PASS) and with the real phone enrollment. The
registration response was not separately inspected for `secret_hash` after
deployment; the client-side `rls.child_cannot_read_secret_hash` check passed and
the column grants keep the field server-only.

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
policy, revocation and BUG-026 checks, was rerun as
`parentcontrol_final7_20261026` with all four migrations and the same corrected
form: `SQL_EXIT=0`, `ERR_LINES=0`, 18 public tables, `realtime policy=1`
(`.tools/sql-final7.log`).

## BUG-016 — Device revocation left pending pairing requests approvable (P1)

**Status:** FIXED — SQL VERIFIED LOCALLY; hosted re-link lifecycle verified, the
revocation-during-pending-request attack not replayed on the hosted Edge
Function.
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
suite passed on the fresh database `parentcontrol_final7_20261026`
(`SQL_EXIT=0`, 0 errors/assertions, 18 tables), and a direct query confirmed the
two request states and `device7 = revoked`. The hosted re-link lifecycle
(unlink → new code → child approval → active membership) was exercised later in
both QA families, but the specific revocation-during-pending-request attack was
not replayed on the hosted Edge Function.

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
cover version creation and idempotency. The hosted HTTP path was later exercised:
Phase 2 `command.poll_delivers_policy` / `command.ack_apply_policy` passed, and
the device run acknowledged policy v1 and reported v2 as failed with the Device
Owner error.

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
filter, and the hosted redirect allowlist contains the same URL. A real
confirmation email, deep link and hosted PKCE exchange remain **NOT TESTED**
because no SMTP provider is configured; QA accounts were confirmed through the
dashboard.

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

**Status:** FIXED — HOSTED VERIFIED (31 checks: 29 `PASS`, 2 setup `INFO`).
**Components:** [20260101000400_device_recovery.sql](../supabase/migrations/20260101000400_device_recovery.sql),
[supabase/functions/family-admin/index.ts](../supabase/functions/family-admin/index.ts),
[lib/features/devices/device_detail_page.dart](../lib/features/devices/device_detail_page.dart),
[lib/features/devices/device_detail_controller.dart](../lib/features/devices/device_detail_controller.dart)

**Reproduction:** Enroll a child phone; clear app data or reinstall; sign in as
the linked child.

**Expected:** The app detects that it has no valid device credential and either
re-registers (when allowed) or tells the user that a parent must unlink and re-link
the child.

**Actual:** The child shell loaded the server device row and reported “Device
setup Registered”, but the local sync credential was gone. The guardian then
failed every heartbeat with “Heartbeat failed: Device credentials are not valid.”,
and no UI action prompted recovery. Registering the new installation was rejected
by `device-register` with `409 device_already_registered` while the old active row
existed. Only a manual parent unlink → new pairing code → child approval → fresh
install restored background protection.

**Fix:** Recovery is now an explicit, parent-authorized operation that cannot be
self-served by the child:

1. `private.request_device_recovery(p_device_id, p_actor_user_id)` is a
   `security definer` wrapper around `private.unlink_child`, so revocation, device
   session termination, pairing-token invalidation and pending-request cancellation
   stay in one transaction, and a `device_recovery_requested` audit row is written
   (no secret, token or plaintext credential is stored).
2. `family-admin` exposes the action only to an authenticated **parent** of that
   device's family; the child role, a parent from another family, an unknown device
   id and a malformed id are all denied and leave the membership and credential
   untouched.
3. The device detail screen shows the recovery action and states that the phone
   must be linked again afterwards. The client never replaces an active device row
   by itself, and the BUG-011/BUG-016 revocation gates stay in force.
4. After recovery the child must complete a fresh pairing (child issues a one-time
   code, parent redeems it, child approves) before a new device can register; the
   old credential stays invalid, so a replayed old secret is rejected.

**Evidence:** `.tools/live/results/recover_device.json` (gitignored) — 31 checks,
29 `PASS` and 2 `INFO` setup steps, run against the hosted project on
2026-10-27T04:09Z: `child_role_denied`, `foreign_parent_denied`,
`unknown_device_denied`, `malformed_device_denied`, `old_credential_replay_denied`
and `unlinked_registration_denied` all pass while
`denials_leave_membership_active` / `denials_leave_credential_valid` confirm no
side effects; `audit_event_written` and `audit_has_no_secret_fields` confirm the
audit row; and the post-recovery pairing produced `fresh_device_distinct` with
`old_credential_still_revoked`. The migration and the Edge Function are deployed
on the hosted project.

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

## BUG-026 — `revoke_device` returned service-only device fields to the parent (P2)

**Status:** FIXED — HOSTED VERIFIED (4/4 shape checks).
**Component:** `private.revoke_device`
([20260101000100_functions.sql](../supabase/migrations/20260101000100_functions.sql)),
reached through `family-admin`.

**Observed:** Revoking a device through `family-admin` returned the entire
`devices` row. That included `installation_id`, which the column grants mark as
service-only and which the parent UI never uses. The same response is relayed
by the Edge Function, so the field reached the client even though direct
`select` on it is denied.

**Impact:** Data minimization and defense in depth. No credential secret was
exposed (`secret_hash` was null for that device), but a stable hardware
identifier was sent to a parent client that has no need for it.

**Fix:** Both return paths of `private.revoke_device` now return
`to_jsonb(v_device) - 'installation_id' - 'secret_hash'` plus the session count.
The updated function was applied through the hosted SQL Editor
(`Success. No rows returned`). Re-calling `family-admin` `revoke_device` for the
already-revoked device returned 200 with `status: "revoked"`,
`revoke_shape.no_service_only_fields` passed, and the response keys exclude both
fields. The Edge Function source was left unchanged so local source still
matches the deployed bundle; the narrowing lives in the RPC.

## BUG-027 — Remote assistance opened media without asking Android first (P2)

**Status:** FIXED — LOCAL VERIFIED (unit test); the shared media path is
device-verified through the self-test, but a two-device session is still
**NOT TESTED**.
**Component:** `RemoteSessionController`
([remote_session_controller.dart](../lib/features/remote_assistance/remote_session_controller.dart)),
bindings in [remote_session_binding.dart](../lib/features/remote_assistance/remote_session_binding.dart)
and [child_session_binding.dart](../lib/features/child/child_session_binding.dart).

**Observed:** `join()` called `getUserMedia` directly. On Android the camera and
microphone runtime grants are owned by `DeviceAdminService.requestPermissions`;
without that call the session could fail with a permission error, or a stale
one-time grant could be reused silently. Nothing surfaced which permission was
missing.

**Fix:** `join()` now asks `DeviceAdminService.requestPermissions(camera: kind ==
video, microphone: true)` before fetching ICE. A denial sets `permissionDenied`
and a specific `permission_denied` error instead of starting a broken session.
The controller unit test covers the denial path (`requestCount == 1`, no peer, no
signals). The same request path is exercised on the device by the self-test.

## BUG-028 — Alerts and Settings tabs crashed with a GetX misuse error (P1)

**Status:** FIXED — DEVICE VERIFIED (parent UI journey run 16).
**Components:** [lib/features/safety_alerts/parent_alerts_tab.dart](../lib/features/safety_alerts/parent_alerts_tab.dart),
[lib/features/settings/parent_settings_tab.dart](../lib/features/settings/parent_settings_tab.dart)

**Reproduction:** Sign in as a parent and open the shell. `ParentShellPage` builds
all four tabs eagerly inside an `IndexedStack`, so the Alerts and Settings tabs are
constructed at once.

**Expected:** Every tab renders.

**Actual:** Both tab shells used `GetX<Controller>(builder: ...)`, and their
builders returned a body widget that owns the `Obx` observables. Because the
builder itself read no observable, `observer.canUpdate` stayed false and
`RxInterface.notifyChildren` threw “improper use of a GetX”; the journey aborted
as soon as the shell mounted.

**Fix:** Switched both tab shells to `GetBuilder<Controller>(init: ...)`, which
does not require the builder to read an observable and still disposes the created
controller when the tab unmounts (with `tag` values that keep the two tabs
independent).

**Evidence:** `flutter analyze` clean; the on-device parent journey now mounts and
drives the Dashboard, Devices, Alerts and Settings tabs (`ui_journey_16.log`), and
the run reaches child approval, device detail, restrictions, policy save and
revocation without the GetX exception.

## BUG-029 — WebRTC signalling dropped early ICE candidates and never recorded the start (P2)

**Status:** FIXED — UNIT TESTED; two-device session still NOT TESTED.
**Component:** [lib/features/remote_assistance/remote_session_controller.dart](../lib/features/remote_assistance/remote_session_controller.dart)

**Observed:** Three defects in the signalling path:

1. An ICE candidate that arrived before this side had a peer connection (or before
   the remote description was set) was discarded, which can stall the connection on
   networks where candidates arrive first.
2. The child never called `markActive` after media connected, so the server kept
   the session in `accepted` and the parent UI never saw the call as started.
3. `endSession` and the session screen's back button could tear down signalling
   before media was stopped, so a failed server `end` call could leave the camera
   and microphone open.

**Fix:** ICE candidates that precede the peer connection or the remote description
are buffered (bounded to 64) and flushed once the answer is applied; the child
marks the session active once it is connected; `endSession` stops local media
first and only then calls the server, reporting a non-fatal `actionError` if the
server call fails; and the session screen is wrapped in `PopScope` so leaving the
page ends the session through the same path.

**Evidence:** `flutter test test/features/remote_assistance` → 11/11 pass,
including the new `stops local media even when the server end call fails` test
(media closed, `isEnding` false, `actionError` set, session unchanged). The media
path itself is exercised locally by the camera/microphone self-test; a real
two-device audio/video call remains **NOT TESTED** (one phone, no TURN).

## BUG-030 — The child self-test row labelled "Recording" reads like a recording control (P3)

**Status:** FIXED — wording changed and the integration test now pins it. The
on-device re-run of that integration test is **NOT TESTED** (it needs a live
camera session on the realme).
**Component:** [lib/features/child/widgets/media_self_test_sheet.dart:306](../lib/features/child/widgets/media_self_test_sheet.dart)

**Observed:** The camera/microphone self-test sheet renders a row whose label is
literally `Recording` with the value `Off — preview only`. It is a status readout,
not a control: the nodes are `clickable="false"` and tapping it during the
2026-10-27 live sweep did nothing, produced no dialog and no capture-API activity.
The label is nevertheless the most plausible reason a child screen-recording
feature was believed to exist — a Phase 6B QA brief was written against it.

**Impact:** A tester or parent reading "Recording / Off" may infer that a recording
capability exists and is merely switched off, which is the opposite of what the
row means and sits awkwardly next to the app's "nothing is recorded" promises.

**Fix:** the value now reads `Recording` / `Not available in this app`, which
states a capability rather than a switch position. The integration test at
`integration_test/child_media_selftest_test.dart:173` previously asserted only
the ambiguous `Recording` label; it now asserts the new value text, so renaming
the row back to an on/off wording fails the test. A widget test proving the row is
non-interactive was not added, because the row only renders while a live camera
stream exists and the sheet has no injectable media seam.

## BUG-031 — `--split-per-abi` rewrites versionCode, so the documented debug install can never run on a device that has had a split build (P3)

**Status:** OPEN — packaging/tooling only, no runtime defect and no user-visible
behaviour change.
**Component:** `android/app/build.gradle.kts:24` (`versionCode = flutter.versionCode`) and the split build in [release-build.md](release-build.md)

**Observed:** `aapt2 dump badging` on artefacts built from one source tree
(`version: 1.0.0+1`, so base versionCode 1):

| Artefact | versionCode |
|---|---|
| `app-debug.apk` | 1 |
| `app-release.apk` (universal) | 1 |
| `app-armeabi-v7a-release.apk` | **1001** |
| `app-arm64-v8a-release.apk` | **2001** |
| `app-x86_64-release.apk` | **4001** |

The 1000× step is Android Gradle Plugin's ABI-split convention (ABI index × base
code), not a manual `--build-number`. The consequence is that once a device has
installed any split artefact, the documented Phase 2 QA command

```
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

fails with `INSTALL_FAILED_VERSION_DOWNGRADE: Update version code 1 is older than
current 4001`, and `adb install -r -d` does **not** bypass it on this Android
version. Both test devices were in exactly that state: the realme was running
versionCode 2001 and the emulator 4001.

**Consequence for QA:** the debug APK could not be installed on either device, so
the Phase 6B live sweep ran against the release splits instead. Both were verified
byte-identical to their local artefacts (realme → `ec15b5e2325219…`, emulator →
`80164c708014cb…`), so the evidence is sound but is release-build evidence. An
interim agent report attributed the failure to the debug APK being arm64-only;
that was wrong — `unzip -l` confirms it carries `lib/arm64-v8a`,
`lib/armeabi-v7a` **and** `lib/x86_64`.

**Suggested fix (not applied):** either install the split matching the device ABI
in the QA procedure, or give debug builds a versionCode above any split (AGP 9 no
longer allows `versionCode` inside `buildTypes`, so this needs a documented
`--build-number` on the debug command rather than a gradle edit).

## BUG-032 — Manual linking codes locked the child out after five codes, failed as a generic "Action failed", and were never kept (P1)

**Status:** FIXED AND DEPLOYED (production `hhqgreaoqulmfwfwarhc`) —
**PASS — LIVE VERIFIED** for the replacement flow; the original over-count was
reproduced locally, not on the hosted project (2026-10-27).
**Components:** [rate_limit.ts](../supabase/functions/_shared/rate_limit.ts),
[pairing/index.ts](../supabase/functions/pairing/index.ts) `create`,
[child_enrollment_controller.dart](../lib/features/child/controllers/child_enrollment_controller.dart),
[child_enrollment_page.dart](../lib/features/child/child_enrollment_page.dart),
[local_settings_service.dart](../lib/data/services/local_settings_service.dart)
and [20260101000500_child_contact_ids.sql](../supabase/migrations/20260101000500_child_contact_ids.sql).

**Observed:** three defects in the old child-minted linking code:

1. `assertPairingCodeCreationAllowed` counted **every** token row the child had
   created in the last 24 hours, regardless of `status` or `expires_at`, and
   rejected at 5 with 429 "You have created too many linking codes today. Try
   again later." Revoked and expired rows were included, so five create taps —
   including retries that replaced their own predecessor — exhausted the budget
   while the child had at most one usable code. The read-only audit reproduced
   this: 4 revoked + 1 active row counted 5 and returned 429
   ([read_only_audit_2026-10-27.md](read_only_audit_2026-10-27.md) §3.2 and §3.5).
2. The child screen rendered every failure in a single `InfoBanner` titled
   **Action failed** with the raw server message. A quota rejection was
   indistinguishable from a network or auth failure and offered no wait time.
3. The code existed only in controller memory (`linkingCode`). It was never
   persisted or re-requestable, so navigating away, rebuilding or restarting lost
   the only copy while its token stayed live until expiry; the parent's only
   copy was whatever had been written down or screenshotted.

**Impact:** P1 for the core linking flow. A child who retried normally could not
link for 24 hours, and a parent who had not captured the code had nothing to
type. No security bypass: the limiter was over-strict, not under-strict.

**Fix:** The creation guard now counts only `purpose='code'`, `status='active'`,
unexpired tokens inside 24 hours against the 5-code limit, and adds a separate
10-creations-per-rolling-hour mint limit with wait guidance
(`details.retry_after_seconds`). `create` tags tokens `purpose='code'`, revokes
only code tokens and cancels only the pairing requests whose tokens it replaced.
The manual action is gone from the child UI: a permanent Child ID is assigned
once (`get_contact_id`), shown with linked status, **Copy ID**, **Show QR** and
**Check for requests**, cached per user id as non-sensitive display data and
refreshed whenever the phone is online. A parent starts the request from that ID
(`invite`), and the child still approves it.

**Evidence:** The original defect is documented from source and reproduced in the
read-only audit against a throwaway local database (§3.5). The fix is **LOCAL
VERIFIED and deployed**: on 2026-10-27 `flutter analyze` reported no issues,
`flutter test` passed 150 tests (including the new validators, QR-payload,
pairing-controller, child-enrollment and child-page widget cases), `deno test`
passed 36 shared tests, `./gradlew :app:testDebugUnitTest` succeeded, and the
full seven-migration SQL suite exited 0 with 19 public tables.

Live evidence: the migration and both functions were deployed and exercised. The
child screen on the realme showed **Your Child ID** (`PC-94EA…`, truncated
because a live ID can still start a pending invite for the linked QA child) with
**Copy ID**, **Show QR** and **Check for requests**, and no "Create linking
code" action. Repeated `get_contact_id` calls returned the same ID. The parent
started a request from that ID, the child approved it, and the legacy
8-character path still worked for an old-client-style code without creating a
duplicate request. The two-device journey is in
[verification-report.md](verification-report.md#two-device-journey-phase-5-2026-10-27).

## BUG-033 — Two simultaneous invites from one parent can leave duplicate pending requests (P2)

**Status:** FIXED AND DEPLOYED (production `hhqgreaoqulmfwfwarhc`) —
**PASS — LIVE VERIFIED** (2026-10-27).
**Components:** [20260101000600_atomic_pairing_invite.sql](../supabase/migrations/20260101000600_atomic_pairing_invite.sql),
[pairing/index.ts](../supabase/functions/pairing/index.ts) `handleInvite` and
`redeem`.

**Observed:** `handleInvite` read for a live `pending_child` request and then
inserted. Two requests that interleaved between those two statements could both
insert, leaving the child two identical items in the approval list. The same
shape existed in the legacy `redeem` path.

**Impact:** Cosmetic to the child and self-limiting: the child can approve only
one, because `respond_pairing_request` raises `child_already_linked` (23505) for
the second, so no duplicate membership or device relationship was created.

**Fix:** Both create paths now run through a SECURITY DEFINER RPC that takes
`pg_advisory_xact_lock(hashtextextended(child:family:parent, 0))`, re-reads for a
live request and only then inserts. `create_pairing_invite` mints the internal
token and the request in the same transaction; `create_pairing_request` covers
the legacy code path, whose token already exists. The functions and their
`public.*` wrappers are service-role only; `anon` and `authenticated` have no
EXECUTE. A partial unique index was rejected again: a request stays
`pending_child` after `expires_at` until the child polls, so an index predicate
cannot distinguish "expired, invite again" from a duplicate. Verified in SQL
that an expired row does not suppress a new invitation.

**Evidence — local (2026-10-27):** `supabase/tests/55_pairing_invite_atomic.sql`
(25 assertions: idempotency, expired-row re-invite, per-parent separation, token
replay → `code_unavailable`, token attributes) and
`supabase/tests/run_pairing_invite_race.sh`, a genuine two-session test:
session A held the transaction 4 s, session B **waited 3404 ms** on the lock,
returned `created=false` with A's request id, and the database held **one** live
row. The seven-migration suite exits 0 with 19 public tables.

**Evidence — production (2026-10-27):** the migration
`20260101000600_atomic_pairing_invite.sql` (SHA-256
`9bf7e2785d1348c7c748808dce73e2f4d9ea9bef47ba46688dece95abd923646`) was applied
through the dashboard SQL Editor and `pairing` was redeployed with the matching
source (deployed content SHA-256
`427d419d4f691cfbc50ccfbc63c500fdcb8f5838cbaa5105b4a58f8551424307`, 33,993
characters). Against that deployment, **six parallel `invite` calls** from one
parent for one unlinked child returned **one unique request id**
(`e7d60a75-385f-4376-9a5e-662bf0a95032`) in all six responses. A database query
in the same window reported `dup_live_pending = 0` (no child/parent/family
triple with more than one live `pending_child` row) and
`concurrent_window_rows = 1`. The live run also re-checked the split between the
two create paths: a legacy-code replay by a different parent returned
`409 code_unavailable`, the same parent's replay returned `200` with the
identical request id (`a2815dba-4744-482a-9516-9d35270b9792`), and the request
was cancelled afterwards (`.tools/phase4b_run_235916.log`,
`.tools/phase4c_run.log`; gitignored).

**Residual:** the 3-pending-inbox quota is checked just outside the lock, so a
burst can exceed it by the number of concurrent callers; the inbox then settles
at the created rows. Documented, not fixed.

## BUG-034 — Identifier-derived metadata leaks (P3)

**Status:** FIXED AND DEPLOYED (production `hhqgreaoqulmfwfwarhc`) —
**PASS — LIVE VERIFIED** for items 1-3, with the residual noted below
(2026-10-27).
**Components:** [pairing/index.ts](../supabase/functions/pairing/index.ts),
[_shared/validation.ts](../supabase/functions/_shared/validation.ts),
[20260101000500_child_contact_ids.sql](../supabase/migrations/20260101000500_child_contact_ids.sql).

1. **Fixed, needs a secret.** `pairing_attempts.code_hash` stored an unsalted
   SHA-256 of the looked-up identifier (30^8 ≈ 6.6×10^11, recoverable offline).
   Attempts now use `identifierHash()`, an HMAC-SHA-256 keyed by
   `PAIRING_HASH_PEPPER`. Without the secret the helper falls back to SHA-256 and
   logs `pairing_hash_pepper_missing` once per isolate, so the mitigation is
   only active once the secret is set. `device_pairing_tokens.code_hash` keeps
   plain SHA-256 on purpose: already-issued linking codes must still redeem.
2. **Fixed.** A guardian no longer receives the child's display name before the
   child approves. `redeemPayload` returns `Child account (pending approval)`
   until `status='approved'`, and the guardian-facing `list_family` masks the
   same way. The parent screen confirms the account with the identifier the
   guardian entered (`lastIdentifier`). The child still sees the guardian's name,
   which the requester supplied.
3. **Fixed.** `child_already_linked` (409) is now returned only to a guardian of
   the family the child already belongs to. Any other family gets the identical
   `invalid_code` 400 used for unknown identifiers, and the attempt is recorded
   as a failure so it consumes the 5-per-10-minutes budget.

**Residual:** response timing still differs slightly between known and unknown
identifiers (extra profile/membership reads); rate limiting bounds it. The
`child_user_id` UUID remains in the pre-approval payload; it is opaque and grants
nothing on its own. Four `pairing_attempts` rows written before the pepper was
active still match a plain SHA-256 of the identifier they were derived from
(`10:24:34`–`13:05:50` UTC); they are historical and were not rewritten.

**Evidence — local (2026-10-27):** `deno test supabase/functions/_shared/` →
36 passed (including four new keyed-hash cases with a pinned HMAC vector);
`deno check` clean for all nine entrypoints; `flutter analyze` clean and
`flutter test` 150 passed.

**Evidence — production (2026-10-27):** the migration
`20260101000500_child_contact_ids.sql` (SHA-256
`6d4b13e01cc4f49cdf31424d5334fdf1f389b484365e047094836671890c197f`) was applied
and `pairing` + `auth-bootstrap` were redeployed (`auth-bootstrap` deployed
content SHA-256
`34cf673247a61a91dbeda77c14c06d01184aad7a0724b5f7eaeb9d2f85b7383b`, 4,302
characters).

1. **Keyed hash active.** Every `pairing_attempts` row in the live run window
   (31 rows, `bad_hash_shape = 0`) is a 64-hex digest. Recomputing the plain
   SHA-256 of the known Child IDs matched only 4 rows, all created at or before
   `13:05:50` UTC; no later row matched. That is the expected signature of
   HMAC-SHA-256 under `PAIRING_HASH_PEPPER` (set in the hosted project; the
   value was never displayed, copied or recorded). Legacy token `code_hash`
   columns still use plain SHA-256 as designed.
2. **Pre-approval masking.** Live `invite` and `redeem` responses returned
   `child_display_name: "Child account (pending approval)"` and the nested
   `child_profile` carried the same masked value until the child approved. The
   parent screen showed the entered identifier (`PC94EA…`) instead of a name.
3. **No cross-family oracle.** A parent from another family inviting a child who
   is already linked to QA Family A received the byte-identical
   `400 invalid_code` used for a malformed/unknown identifier; a parent of the
   child's own family received `409 child_already_linked`. Six malformed/unknown
   IDs in a row produced five uniform `400 invalid_code` responses and then
   `429 rate_limited` with `details.retry_after_seconds: 600`, so the failure
   path is bounded and carries wait guidance.

**Evidence — audit:** a 4-hour window over `public.audit_logs` grouped by event
type returned six pairing/device events with `leaky = 0` for each. Metadata held
only opaque UUIDs and `via: "child_id"`; no Child ID, contact ID, identifier
hash or secret appeared. Logs: `.tools/phase4_run_235716.log`,
`.tools/phase4b_run_235916.log`, `.tools/phase4c_run.log` (gitignored).

## BUG-035 — A known Child ID can hold a child's three pending invite slots (P2, open)

**Status:** OPEN — accepted, documented.
**Components:** [rate_limit.ts](../supabase/functions/_shared/rate_limit.ts)
`assertInviteQuotaAllowed`.

**Observed:** `MAX_PENDING_INVITES_PER_CHILD = 3` with a 24-hour invite TTL. An
attacker who knows a valid Child ID can send three invites and keep the child's
inbox full for a day; the legitimate parent then receives 429 "already has
several linking requests waiting".

**Impact:** Availability, not confidentiality. The child sees the three requests
and can reject or ignore them, and the attacker needs the identifier plus an
authenticated parent account. Successful lookups are not rate-limited by design
(a guardian linking several children must not be throttled), so the pending cap
is the only control.

**Why it is not fixed here:** the consent model has no way to tell a legitimate
guardian from an attacker holding the ID, and shortening the TTL trades the same
availability for slower legitimate linking. Candidate fixes for a later change:
per-parent pending cap of one, or a child-side "block this family" action.

**Evidence:** source review and the local SQL suite; no live reproduction.

## BUG-036 — A pending guardian request shows "expires Just now" for a request that expires tomorrow (P3, open)

**Status:** OPEN — cosmetic, not fixed.
**Components:** child pending-request card
([child_enrollment_page.dart](../lib/features/child/child_enrollment_page.dart)).

**Observed:** during the Phase 5 two-device journey the child's pending card read
`From QA Parent A · expires Just now` while the server-side request had a
24-hour expiry (`expires_at` one day after `created_at`). The relative-time
formatter renders a future timestamp as "Just now" instead of a future duration.

**Impact:** cosmetic. It understates how long the guardian's request stays
valid and could make a child think the request is already expiring. No state or
authorization effect.

**Evidence:** `.tools/evidence/phase5/child_pending.xml` (uiautomator
`content-desc`), plus the server response in `.tools/phase4b_run_235916.log`
showing `created_at` and `expires_at` 24 hours apart. Reproduced 2026-10-28 in
two places: the linking card again read `From QA Parent A · expires Just now`
(`.tools/evidence/qa-20261028/live/child_pending_request.xml`) and a 10-minute
assistance request read `Video assistance · expires Just now`
(`child_assist_request.xml`), while the session page then showed `Expires 29m`
(`parent_assist_accepted.xml`). The formatter maps any future timestamp to
"Just now" (`relativeTime` returns `Just now` for a negative difference,
[formatters.dart](../lib/core/utils/formatters.dart)).

## BUG-037 — The child setup screen keeps a success banner after the family is removed (P3, open)

**Status:** OPEN — cosmetic/state-refresh, not fixed.
**Components:** child setup state
([child_enrollment_page.dart](../lib/features/child/child_enrollment_page.dart),
[child_enrollment_controller.dart](../lib/features/child/controllers/child_enrollment_controller.dart)).

**Observed:** after the parent unlinked the child in Phase 5, the child setup
screen still showed the green `Done — This phone is registered. Open My phone to
review rules, permissions and requests.` banner even though the account was no
longer in a family and the pending-request area had returned to its initial
state. The banner is a cached success from before the unlink, not a fresh
server read.

**Impact:** cosmetic and potentially misleading: the banner implies a completed
setup while the family relationship is gone. The account and device state are
enforced server-side, so this is presentation only. The screen's family section
did update (the child disappeared from Family and the page returned to the
no-request state), but the success banner was not cleared with it.

**Evidence:** `.tools/evidence/phase5/child_after_unlink.xml` shows the banner
together with the "no guardian request" state and no family name. The screen
only showed the correct `Linked` and `Registered` state after the deliberate
relink and device re-registration
(`.tools/evidence/phase5/child_relinked.xml`,
`.tools/evidence/phase5/restore_child.xml`). The banner's refresh behaviour was
not reduced to a single root cause, so the entry stays P3 and open.

Reproduced on 2026-10-28: after the parent unlinked the child, the child's
**My phone** screen still showed `QA Family A`, `Linked`, `Registered` and
`Background protection Running`; only the last-error line changed to
`App list upload failed: Device credentials are not valid.`
(`.tools/evidence/qa-20261028/live/child_home_after_unlink.xml`). The stale
linked state cleared only after a deliberate force-stop and relaunch
(`child_relaunch.xml`). There is no periodic membership refresh in the child
shell, so an in-session unlink is invisible until the app is reopened; the
server-side revocation itself is immediate (same evidence).

## BUG-038 — A healthy child device shows Offline for two minutes of every five-minute heartbeat cycle (P2, open)

**Status:** OPEN — confirmed live 2026-10-28.
**Components:** [GuardianService.kt](../android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt)
(`HEARTBEAT_MS = 5 * 60_000`),
[device.dart](../lib/data/models/device.dart) (`isOnline` = last seen within
3 minutes).

**Observed:** The background service heartbeats every five minutes, but the UI
calls a device Online only when `last_seen_at` is under three minutes old.
Live timeline on the relinked realme: heartbeat at 08:46 → at 08:50:5x the
detail showed `Last seen 4 min ago · 8:46 AM` with badge **Offline**; heartbeat
at 08:51 → at 08:51:55 it showed `Just now · 8:51 AM` with badge **Online**.
The device never stopped heartbeating.

**Impact:** A correctly working child phone is reported Offline for roughly two
minutes out of every five, so the guardian cannot trust the badge for presence
checks or "is my child's phone online" support conversations. No authorization
effect.

**Recommended fix:** derive the Online window from the heartbeat interval
(for example 2 × interval + jitter) or use a server-side presence flag; keep the
threshold in one place so the two constants cannot drift.

**Evidence:** `.tools/evidence/qa-20261028/live/parent_detail_t5.xml`
(08:49:02, Online, last seen 8:46), `parent_detail_t8.xml` (08:50:5x, Offline,
4 min ago), `parent_detail_t9.xml` (08:51:55, Online, Just now).

## BUG-039 — After relinking, background sync kept failing until the app process was restarted (P2, open)

**Status:** OPEN — observed live 2026-10-28; root cause not isolated.
**Components:** child background service, re-credentialing path
([GuardianService.kt](../android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt),
[device-register/index.ts](../supabase/functions/device-register/index.ts),
[SecureStore.kt](../android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt)).

**Observed:** The parent unlinked the QA child at 08:32. The child was relinked
through a fresh Child-ID request and approved at 08:36, then **Register this
phone** reported success and the UI showed `Status Online`. Despite that, the
parent's `last_seen_at` stayed frozen at 08:33: at 08:39:45 it read
`6 min ago · 8:33 AM`, and at 08:41:0x it was still 08:33 while the child UI
said `Background protection Running`. A force-stop and cold relaunch of the
child app at 08:41 produced an immediate heartbeat (`Just now · 8:41 AM`,
**Online**), and the five-minute cadence continued correctly after that.

**Impact:** After every unlink/relink or device recovery, the child phone can
look online locally while the server receives no heartbeat, telemetry, policy or
command traffic, and the guardian sees only "Offline" with no explanation. The
condition clears only when the child reopens the app.

**Not isolated:** the service re-reads its config every tick
(`GuardianService.kt:175`), so a simple cached config is not the whole story;
the observed service restart loop (`dumpsys activity services` showed
`lastActivity` resetting roughly every 40 s) and the 401 backoff path
(`:203-210`) are both candidates. The entry stays open until reproduced with
service logging.

**Evidence:** `.tools/evidence/qa-20261028/live/parent_detail_t1.xml`,
`parent_detail_t2.xml`, `parent_detail_t3.xml`; `child_after_register.xml`;
`child_my_phone_after_relink.xml`; `child_logcat_after_relink.txt`; service
dump in `.tools/evidence/qa-20261028/device/SUMMARY.md`.

## BUG-040 — The dashboard and Devices tab list revoked devices as if they were current (P2, open)

**Status:** OPEN — confirmed live 2026-10-28.
**Components:** [supabase_device_repository.dart](../lib/data/repositories/supabase_device_repository.dart)
(`fetchDevices` filters only by `family_id`),
[parent_dashboard_tab.dart](../lib/features/dashboard/parent_dashboard_tab.dart),
[parent_devices_tab.dart](../lib/features/devices/parent_devices_tab.dart),
[dashboard_controller.dart](../lib/features/dashboard/dashboard_controller.dart).

**Observed:** The QA family had five device rows: four `status='revoked'` rows
from earlier enrolments and one active realme row. Both the Dashboard and the
Devices tab rendered all five with the same card layout; the only difference is
the **Revoked** badge. The revoked rows still show their last historical state,
including `Fully managed (Device Owner)` and `Policy v1 · Enforced on device`,
which are snapshots from devices that no longer exist. The dashboard also treats
a revoked row as "this child has a device", so a child whose only rows are
revoked is never shown as needing setup.

**Impact:** A guardian cannot tell the current phone from history, is shown
enforcement claims that were true only for old installations, and may believe a
child is still monitored when the only live device is gone. Revoked rows are
kept deliberately server-side for audit and recovery, so this is a presentation
bug, not data loss.

**Recommended fix:** default the list to `status='active'`, render revoked rows
under a collapsed "Past devices"/history section, and count only active rows for
setup prompts. Do not delete the historical rows.

**Evidence:** `.tools/evidence/qa-20261028/device/SUMMARY.md` (five rows, four
Revoked), `.tools/evidence/qa-20261028/live/parent_now.xml`,
`parent_devices_scrolled.xml`; call chain at
`supabase_device_repository.dart:31-40` and
`dashboard_controller.dart:112-113,147-149`.

## BUG-041 — "Last seen" disagrees with itself and with other screens (P3, open, needs reproduction)

**Status:** OPEN — observed live 2026-10-28; not reproducible on demand.
**Components:** [formatters.dart](../lib/core/utils/formatters.dart),
[parent_dashboard_tab.dart](../lib/features/dashboard/parent_dashboard_tab.dart),
[parent_devices_tab.dart](../lib/features/devices/parent_devices_tab.dart).

**Observed:** Within eight minutes, the same realme row rendered as
`4 min ago · Oct 28, 2026 3:47 AM` on the Dashboard, `7 h ago` on the Devices
tab, `3 min ago · Oct 28, 2026 8:27 AM` on the device detail, and
`39–48 min ago · 7:41 AM` on the child itself, while both device clocks read
08:2x IST. The Dashboard string is internally inconsistent (`4 min ago` cannot
be 3:47 AM at 08:22) even though it formats one field
(`parent_dashboard_tab.dart:261-263`). All screens agreed after a refresh and
after relinking.

**Impact:** The guardian cannot rely on "Last seen" when supporting a child.
No functional or authorization effect. The 2026-10-28 uiautomator dumps can
merge recycled list semantics, so this entry stays P3 until it is reproduced
with a single-card capture and a known server timestamp.

**Evidence:** `.tools/evidence/qa-20261028/live/parent_dash_scrolled.xml`,
`parent_devices_scrolled.xml`, `parent_realme_detail.xml`,
`parent_detail_t1.xml`, `child_now.xml`.

## BUG-042 — Parent app raised an ANR when ending a remote-assistance session (P2, observed once)

**Status:** OPEN — observed once on the emulator 2026-10-28; needs reproduction.
**Components:** parent remote-session screen
([remote_session_page.dart](../lib/features/remote_assistance/remote_session_page.dart),
[remote_session_controller.dart](../lib/features/remote_assistance/remote_session_controller.dart)).

**Observed:** Tapping **End session** at 08:47:25 produced the system dialog
`Parent Control isn't responding`; the event log records
`am_anr ... Input dispatching timed out ... Waited 5003ms for MotionEvent`.
Choosing **Wait** left the app backgrounded; a later relaunch restored the
session state normally.

**Impact:** The parent UI freezes at the moment a session is ended, which is the
most likely moment for a guardian to need the phone back. Whether this is
emulator-only (Android 17 x86_64, software media) is unknown; it must be
reproduced on a physical parent before being treated as a product defect.

**Evidence:** `.tools/evidence/qa-20261028/live/parent_anr.png`,
`parent_anr.txt` (`am_anr` line, 08:47:25).

## Camera and microphone self-test (new, device verified)

The child Settings tab now has **Camera and microphone test**
([media_self_test_sheet.dart](../lib/features/child/widgets/media_self_test_sheet.dart)),
a visible, local-only preview. It asks Android for both permissions, opens the
main camera, reports the real decoded frame size, allows switching to the front
camera, mutes and unmutes the microphone, and stops every track on close. It
states **Recording — Off — preview only** and contains no capture code.

Device evidence on the RMX2161 (Android 12, one phone only):

- Main camera: `Main camera live`, `Mic Live`, `Video frames 1280×720 received`,
  `Recording Off — preview only`. The picture was dark because the phone lay
  face-up on a desk; decoded frames were still reported.
- Front camera after **Switch camera**: `Front camera live`, a real image of the
  room, `Video frames 1280×720 received`.
- **Mute microphone** → `Opened, muted for this test`; **Stop test** closed the
  sheet and released the tracks.
- Screenshots: `.tools/evidence/device-media-04-main-frames.png` and
  `.tools/evidence/device-media-05-front-frames.png` (gitignored).
- Integration test `integration_test/child_media_selftest_test.dart` fails if the
  preview never receives a frame; it passed twice.

## Screen recording (child) — NOT IMPLEMENTED, intentionally

There is no screen-recording option in this app. A repository search finds no
`MediaProjection`, `VirtualDisplay`, `ImageReader` or `MediaRecorder` usage and
no capture permission or service. Android's MediaProjection captures the whole
display, including other apps, which conflicts with the requirement to touch
only this app; adding it would also enable invisible surveillance of third-party
content. The app therefore reports the feature as absent rather than shipping a
partial or covert version.

The 2026-10-27 Phase 6B audit re-tested this claim at five independent levels
rather than trusting the source read, and all five agree. See
[verification-report.md](verification-report.md#phase-6b--child-screen-recording-audit)
for the R1–R16 evidence table. In short: the packaged manifest requests no
capture permission and runs no `MEDIA_PROJECTION` foreground service; every one
of the 728 screen-capture class references in the shipped dex belongs to the
`flutter_webrtc` plugin payload or to Flutter/CameraX internals, with zero in the
app's own 56 classes; the installed packages on both devices hold no capture
permission; `dumpsys media_projection` reports no session; and 33 authenticated
screens walked live contain no record, stop, list, play or download control. No
Android screen-capture consent dialog was reachable.

Consequently every recording test case in the Phase 6B brief — consent grant and
deny, physical capture, parent delivery and playback, audio in recordings — is
**NOT TESTED because the feature is absent**. The camera/microphone self-test and
the WebRTC remote-assistance path are separate features and were not accepted as
substitute evidence.

Two side findings from this work are logged as BUG-030 and BUG-031. The
implementation plan, including the API-contract and consent-model change recording
would force, is in
[screen-recording-plan.md](screen-recording-plan.md); nothing was implemented,
because the feature contradicts promises the shipped UI already makes to the
child.

## App enable/disable — BLOCKED on this device

Enabling and disabling other apps requires `setPackagesSuspended`, which Android
only permits for a Device Owner. `dpm list-owners` on the RMX2161 reports no
owners. The parent App restrictions screen states this and refuses to claim an
app is blocked; a saved policy is acknowledged as `failed` with the Device Owner
error. No adb command was used to suspend other apps. This remains **BLOCKED /
NOT TESTED**, not a pass.

## Open / not tested

No open P0 or P1 bug is known. BUG-035 remains an accepted open **P2**
(identifier-holder can occupy the child's pending slots). The 2026-10-28
two-device run added four open defects: BUG-038 (false Offline between
heartbeats, **P2**), BUG-039 (background sync stale after relink until the app
restarts, **P2**), BUG-040 (revoked devices listed as current, **P2**), BUG-041
(last-seen labels disagree, **P3**) and BUG-042 (ANR on ending a session,
**P2**, emulator only so far). BUG-036 and BUG-037 remain open **P3**
presentation defects, both reproduced on 2026-10-28. Every item below is
**NOT TESTED**, **BLOCKED** or **NOT CONFIGURED**, not a pass:

- Hosted email delivery: no custom SMTP provider. The confirmation/reset email
  round-trip and the deep link are not exercised end to end.
- FCM: no Firebase project or `google-services.json`.
- TURN: no `TURN_URL`/`TURN_SECRET`; ICE returns STUN-only with
  `turn_configured:false`.
- Device Owner provisioning and `setPackagesSuspended()` on the realme RMX2161:
  the phone is not Device Owner, so Instagram suspension and reboot persistence
  are blocked. The provisioning procedure is documented in
  [docs/device-owner-provisioning.md](device-owner-provisioning.md).
- Child screen recording: **NOT IMPLEMENTED**, so every recording test case is
  **NOT TESTED** — see the Phase 6B evidence table in
  [verification-report.md](verification-report.md). Related: `adb shell
  screenrecord` on the RMX2161 is refused by ColorOS SELinux, so the realme's
  hardware encoder path is **BLOCKED / UNPROVEN** on the one physical child
  device; the emulator's encoder was confirmed working with a 5 s H.264 clip that
  was pulled and deleted.
- QA enrollment state (2026-10-28): the realme RMX2161 was unlinked from QA
  Family A, re-invited by Child ID, approved on the child and re-registered at
  08:36; the same device row is active again and heartbeating every five
  minutes (`last_seen` 08:51). The realme still has no policy row
  (`policy_version 0`), because policies are per-device and re-registration
  does not inherit the previous installation's policy. Unlink the child and
  revoke the device row through the parent API before deleting the QA accounts.
- Backups/restore: the hosted project's backup/PITR is **NOT CONFIGURED /
  UNVERIFIED**. A **local** dump → restore drill was performed and verified
  (identical row counts). See [docs/backend.md](backend.md).
- Two-device WebRTC media: **PARTIAL**. On 2026-10-28 the parent request
  reached the child, the child's consent was required and recorded, both
  screens reported **Connected**, and the realme opened its camera (front,
  `CONNECT device 1`) with `Recording active: true` while the session ran.
  The parent's preview area stayed blank and no parent-side audio playback was
  observed, so actual remote audio/video delivery is **NOT VERIFIED**; TURN is
  not configured and the parent ran on the x86 emulator. See
  [verification-report.md](verification-report.md#complete-two-device-qa-2026-10-28).
- Policy application to the relinked device: **NOT TESTED** in this run. No
  command or policy was deliberately sent, because the goal was to observe the
  existing zero-policy state; the hosted policy v1/v2 acknowledgement path was
  verified on 2026-10-27.
- Usage Access and location NB: **now device verified** — see the verification
  report (`device_capabilities_test.dart`: 32 usage rows in 24 h and a real fused
  location fix). Earlier "not tested" claims in this list are superseded for that
  item only.
