# Stage 4 — Parent-Controlled Remote Session Lifetime

Date: 2026-10-28
App: Parent Control 1.0.0 (debug)
Scope: remote audio/video assistance session lifetime, consent, end authority,
client lifecycle and TURN credential refresh.

> Deployment status: **NO hosted changes were made**. The repository migration and
> Edge Function changes are validated locally only. The hosted Supabase project
> still runs the previously deployed backend. Items that require the hosted
> backend to be updated are marked **BLOCKED** below, not passed.

---

## 1. Root causes found in the Phase 1 audit

| # | Cause | Effect observed |
|---|-------|-----------------|
| 1 | `remote_sessions.expires_at` was `not null` and was set to `now + 10 min` for every request. The client treated any `expires_at` in the past as expiry, regardless of `status`. | An accepted session showed `Expired` / `Reason: expired` about 10 minutes after the request, even though consent had been recorded. |
| 2 | The deployed session-expiry path (cleanup + Edge validation) operated on rows by deadline, not by pending state. `expire_stale_sessions()` had no `status = 'requested'` restriction in the old body. | A session that had been accepted at 5:49 PM appeared ended/expired at ~6:25 PM with `Reason: expired`. |
| 3 | The Edge Function `respond` kept the request deadline on the row after consent; `end` accepted a caller-supplied reason/`ended_by`, and child-side callers could end the record. | The server could not distinguish a parent end from a client-side teardown, and the accepted row still looked time-limited. |
| 4 | The child page exposed an `End session` action and child controllers ended the server session on dispose/back/route change/sign-out/unlink/permission loss. | Leaving the child screen (or the OS killing it) terminated the server session. |
| 5 | The client computed `Expired` from elapsed time and hid media banners for past-deadline accepted sessions; no parent-only enforcement existed in the UI. | Authorization (server session) and connectivity (media) were conflated in the UI. |
| 6 | TURN credentials had a 10-minute lifetime but the client only fetched them at join time. | ICE restart could not recover after the credentials expired. |

Policy implemented: `expires_at` is a **pending-request deadline only**. Once
consent is recorded it is cleared (`null`). Only the authenticated parent who
requested the session can end the server record. Temporary media loss is not a
terminal state; TURN credentials remain short-lived and are independent of
session lifetime.

---

## 2. Server-side changes

### 2.1 Migration

`supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql`

- `expires_at` becomes nullable.
- New constraint `remote_sessions_pending_expiry_check`:
  `status <> 'requested' or expires_at is not null` — pending requests still
  need a deadline; consented/terminal rows may keep `NULL` or historical values.
- One-time data fix: existing `accepted` / `active` rows get `expires_at = NULL`.
  Terminal history (`ended`, `declined`, `expired`, `failed`) is not rewritten.
- `private.remote_session_transition_guard()` + trigger
  `remote_sessions_transition_guard` reject any attempt to move a terminal row
  back to `requested` / `accepted` / `active` (`session_terminal`). This prevents
  revival of an ended or expired session by reusing its id.
- `private.expire_stale_sessions()` now updates **only** `status = 'requested'`
  rows with a past `expires_at`. Consented rows cannot be clock-expired.
- `public.request_remote_session(...)` (service-role only) still creates a
  pending request with a 10-minute deadline, but in-lock it:
  - expires only stale **pending** requests,
  - raises `session_in_progress` when any `requested`/`accepted`/`active` row
    exists (a legacy past deadline on an accepted row is never used to silently
    end it),
  - preserves the advisory lock on `device_id`.

### 2.2 Edge Function `remote-session` (local source only)

- `respond` (accept): sets `accepted_at`, `consent_recorded = true`, and
  **`expires_at = NULL`**. Decline sets `ended_reason = 'declined'`.
- `end`: parent-owner only via `assertParentOwner()`. Child-originated calls are
  rejected (`403`). A caller-supplied `ended_by`/reason is ignored; the server
  derives it with `endPatch(statusBefore, parentUserId, now)`:
  - `requested` → `cancelled_by_parent`
  - `accepted`/`active` → `ended_by_parent`
  Duplicate end calls on a terminal row return the existing row (idempotent).
- `session_state` (device-authenticated poll used by the Android foreground
  service) returns the nullable `expires_at` and verifies device/child ownership.
- `pending_child` expires only past-deadline `requested` rows and returns only
  unexpired pending requests.
- `ice` issues fresh ephemeral TURN credentials per call
  (`TURN_TTL_SECONDS`, default 600 s) with a TTL independent of the session.
  No TURN secret is embedded in the app.

---

## 3. Client changes

### 3.1 Model and repository

- `RemoteSession.isExpired` is true **only** for `status == requested` with a
  past deadline. Accepted/active rows can never read as expired from elapsed
  time (`isParentControlled` helper added).
- `expires_at` is nullable throughout the Dart model and repository; no code
  path synthesizes a deadline for a consented session.

### 3.2 Controller (`remote_session_controller.dart`)

- Removed elapsed-time teardown: the ticker only updates informational elapsed
  time. It cannot end, expire, or dispose media.
- `endSession()` is parent-only. Child role gets a clear forbidden error and is
  not allowed to call the end API. The parent call sends no reason; the server
  derives `ended_by_parent` / `cancelled_by_parent`. Duplicate end is a no-op.
- `withdrawConsent()` (child) stops capture/service and keeps the server session
  open. It does not call `end`.
- Connection loss, ICE failure, service destruction and permission loss set
  guidance/reconnect state; they do **not** end the server session. Media is
  torn down locally and renegotiated when possible.
- `_refreshIceServers()` re-fetches TURN credentials before they expire or after
  an ICE failure, applies `peer.setConfiguration(...)` and calls `restartIce()`.
- Realtime `watchSession` updates are ignored once the local session is terminal
  (no revival). Disconnected Realtime surfaces "Live updates interrupted" with
  an explicit refresh action instead of implying the session ended.

### 3.3 UI

- Parent session screen: "Session duration: Until you end the session"; no
  expiry timestamp/countdown. Elapsed time is informational only. Parent-only
  `End session` with confirmation.
- Child session screen: "Session duration: Until your guardian ends the session";
  `Stop sharing` (confirm dialog: camera/mic off **and the session stays open**)
  replaces `End session`. No control can end the server record.
- Child dispose/onClose/back/route change/background/screen-lock never call the
  end API; the Android service keeps sharing with its visible notification and
  watchdog. "You can leave this screen" explains this.
- Media state is shown separately: `Media connected` / `Microphone live` /
  `Audio not live` / `Reconnecting` are connectivity, while `Active`/`Ended`
  come from the server status.
- Child "Session is still live" + `Reconnect microphone` is offered after
  `Stop sharing` or media loss; it reuses the same session.
- Outdated copy "accepted sessions are short-lived" on the Remote assistance
  screen was replaced with: "once accepted, the session stays open until the
  guardian ends it."

---

## 4. Automated test results (executed)

| Suite | Command | Result |
|-------|---------|--------|
| Flutter analyze | `.fvm/flutter_sdk/bin/flutter analyze` | **No issues found** (150.7 s) |
| Flutter tests | `.fvm/flutter_sdk/bin/flutter test` | **243 passed, 0 failed** |
| Kotlin unit tests | `cd android; .\gradlew.bat :app:cleanTestDebugUnitTest :app:testDebugUnitTest` | **24 passed, 0 failed** (clean task forced execution; prior run was UP-TO-DATE) |
| Deno Edge Function tests | `deno test supabase/functions/remote-session/guard_test.ts` | **11 passed, 0 failed** |
| SQL migration + policy tests | disposable PostgreSQL 16.9 on `127.0.0.1:55432`, full migration chain + `supabase/tests/61_parent_controlled_lifetime.sql` | **EXIT=0**, 19 tables, all `ALL ... PASSED` notices, no `ERROR` / `ASSERTION FAILED` |

Targeted Stage 4 tests added/rewritten (all executed):

- pending request expiry opens no media;
- accepted multi-day session stays open (`Session active`, `Until you end the session`, clock advanced by one day);
- client countdown/elapsed time cannot terminate a session;
- parent-only end (child role forbidden, no RPC);
- child disposal/back/service destruction/permission loss leave the session active and never call `end`;
- child-originated end rejected by the Edge Function (Deno);
- server-derived end reason and ignored caller input (Deno);
- duplicate/stale end is idempotent (Flutter + Deno);
- terminal session cannot be revived by a late Realtime update;
- ICE restart reissues TURN credentials through the backend and applies
  `setConfiguration` + `restartIce` without ending the session;
- `session_state` reports a null expiry for a consented session (Deno);
- SQL: transition guard, pending-only expiry job, request guard with a legacy
  accepted row.

---

## 5. Build

- `flutter build apk --debug --dart-define-from-file=.tools/live_config.env`
  via `scripts/build_debug_apk.sh` (config validated; values not printed).
- Artifact: `build/app/outputs/flutter-apk/app-debug.apk`
- Size: **243,780,258 bytes**
- SHA-256: **402a43f26bdc6490671984643d22600a5fbca52d89b23278d5b9e5103273bbe5**
- Version name: `1.0.0`; installed on both devices with `adb install -r`.

---

## 6. Device verification

Environment:

| Role | Device | Serial | OS | App |
|------|--------|--------|----|-----|
| Parent | Android emulator `sdk_gphone64_x86_64` | `emulator-5554` | Android 17 | 1.0.0 debug |
| Child | realme RMX2161 (physical) | `5HXWRGQ4IFU8WS4T` | Android 12 | 1.0.0 debug |

Both accounts were already signed in: parent "QA Parent A" (QA Family A),
child "QA Child A" (`qa.child.a2.20261026@example.com`), device linked/online.
Screenshots were captured with `adb exec-out screencap -p` at each step and are
stored under `docs/evidence/stage4/`:

| File | Shows |
|------|-------|
| `01-parent-accepted.png` | Parent: Accepted, `Until you end the session`, consent recorded, no expiry |
| `02-child-accepted.png` | Child: Accepted, `Until your guardian ends the session`, elapsed 31s, Consent recorded |
| `03-parent-active-media-live.png` | Parent: Active, audio live, media connected, duration label unchanged |
| `04-child-active-mic-live.png` | Child: Active, microphone on, media connected, no End control |
| `05-child-left-screen-session-active.png` | Child Home after leaving: session still active, Open session / Stop sharing |
| `06-child-stop-sharing-session-open.png` | After Stop sharing: "Session is still live", Reconnect microphone, session not ended |
| `07-parent-reconnecting-audio-not-live.png` | Parent: Reconnecting, "Audio not live", server status still Active, End available |
| `08-parent-ended.png` | Parent: Ended after parent confirmation |
| `09-child-ended.png` | Child: Ended after the parent end |
| `10-parent-lifetime-copy.png` | Corrected copy on the rebuilt APK (pending vs accepted lifetime) |

Flows executed and observed:

1. **Request created** from the parent device (9:39 PM run). Pending state shows
   `Waiting for consent`, `Expires: Waiting for consent (9m left)`, child consent
   `Not recorded` — the pending deadline is still enforced and visible.
2. **Child accepted** (9:06 PM run). Child screen showed `Accepted`,
   `Session duration: Until your guardian ends the session`, `Elapsed 31s`,
   `Consent: Recorded`, and `Join with microphone`; no expiry timestamp and no
   countdown. Parent screen independently showed `Accepted`,
   `Session duration: Until you end the session`, `Child consent: Recorded`.
3. **Child joined**. Child showed `Microphone is on`, `Media connected`,
   `Microphone live`, and only `Stop sharing` (no `End session`). The footer read:
   "Only your guardian can end this session. Stop sharing turns off this phone's
   camera and microphone and leaves the session open."
4. **Server status became Active**. After the child joined, both screens showed
   server status `Active` (child on refresh/rollover; parent after refresh),
   duration still `Until you/your guardian ends the session`, elapsed
   informational (`3m`), `Consent: Recorded`.
5. **Child left the session screen (back)**. Child Home showed
   "Microphone sharing is on / Session active", `Open session`, `Stop sharing`.
   Parent stayed `Active` / `One-way audio live` — leaving the screen did not end
   the session.
6. **Child Stop sharing** (9:12 PM). Confirmation dialog: "This turns off your
   camera and microphone on this phone immediately. The session stays open until
   your guardian ends it." After confirming, child showed
   "Session is still live", `Reconnect microphone`, and a banner "Camera and
   microphone are off. The session itself stays open until your guardian ends
   it; the app will not reopen the microphone by itself." Parent moved to
   `Reconnecting` with `Audio not live`; server session was **not** ended.
7. **Parent End session** (9:15 PM). Confirmation "This stops audio playback and
   ends the session for both participants." Parent showed `Ended`,
   `Ended 9:15 PM`, "Session ended". Child refreshed to `Ended`, "Session ended".
   This is the only flow observed to terminate the server record.
8. **Second active session** (requested/accepted 9:21 PM, ended 9:37 PM). It was
   found still active while checking the rebuilt APK; the parent ended it and the
   child went to `Ended`. Origin of this row is **not explained by the scripted
   steps** (see limitations). The child app had just been reinstalled and
   resumed this active session with `Microphone live` after launch.
9. **Rebuilt APK (this build)** was installed on both devices; the parent Remote
   assistance screen was re-checked and now displays the corrected lifetime copy:
   "A pending request expires if it is not answered; once accepted, the session
   stays open until the guardian ends it."
10. **Pending expiry** (9:39 PM request) was left unanswered to observe the
    pending timeout on the hosted backend. Result is recorded below.

### 6.1 Pending expiry observation — NOT COMPLETED

The 9:39 PM request was intentionally left unanswered, but by 9:42 PM the child
device already showed it as `Active`, `Consent: Recorded`, `Accepted 9:40 PM`
and `Microphone live`, with `One-way audio live` on the parent side. Neither
device was touched by this automation between 9:37 and 9:42 PM. The session was
ended from the parent at 9:44 PM. Because the request did not stay pending, the
pending-expiry state was **not observed on device** and is not claimed as a
device pass; it is covered only by the SQL/Flutter tests listed above.

### 6.2 Unexplained accepted sessions

Two sessions (requested/accepted 9:21 PM and 9:39 PM) were accepted and started
while the devices were unattended from this automation. A search of the client
does not find an automatic accept/join path (`respond`/`join` are only called
from explicit UI handlers), so the origin cannot be attributed to the code from
the available evidence. It may be manual interaction with the shared physical
device or with the emulator. Both sessions were ended from the parent. This must
be investigated with request/audit logs in a deployed environment before the
behavior can be classified.

### 6.2 Honest status of device checks

| Requirement | Device status |
|-------------|---------------|
| Accepted session shows no expiry/countdown and `Until ... ends the session` | **PASS** (screenshots, both roles) |
| Parent is the only role with an End control | **PASS** (child has only Stop sharing/Reconnect) |
| Child leaving/back/dispose does not end the session | **PASS for back/leave on device** (step 5); dispose/service/permission paths covered by tests |
| Child Stop sharing stops capture and keeps the session open | **PASS** (step 6) |
| Parent End ends the session for both participants | **PASS** (step 7) |
| UI separates server status from media connectivity | **PASS** (`Active` + `Audio not live` / `Reconnecting`) |
| Elapsed time alone does not end an accepted session | **PARTIAL on hosted**: observed active for 8+ and 16+ minutes past the request deadline; the former 30-minute hosted cap was not reached before the sessions were ended. Local SQL tests prove no cap. |
| Server stores `ended_by_parent` and returns it | **BLOCKED on hosted**: hosted backend does not return `ended_reason` (screens show "This session is over." without a reason). Local Deno/SQL tests verify `ended_by_parent`; it requires backend deployment to observe on device. |
| Child-originated end rejected | **BLOCKED on hosted**: no child end control exists in the app, so the flow cannot be driven from the child UI; local Deno test rejects it with 403. |
| TURN credential refresh under ICE failure | **Not exercised on device**; covered by the Flutter ICE-restart test. Hosted env also reports `Relay not configured` (no TURN secret configured), so relay connectivity is not available. |

---

## 7. Remaining limitations / blocked items

1. **Hosted backend not updated.** No deployment, migration push, function
   deploy, or hosted secret change was authorized or performed. Until
   `20261028000200_parent_controlled_session_lifetime.sql` and the updated
   `remote-session` function are deployed:
   - the hosted DB still has the old `expires_at` semantics and 30-minute cap;
   - the hosted `end` response/history does not contain `ended_reason`, so the
     device UI cannot display `ended_by_parent` (it showed no reason);
   - the hosted client cannot demonstrate the no-cap policy beyond the observed
     16 minutes.
   Deploying these changes requires separate explicit authorization.
2. **TURN is not configured in the hosted client config** ("Relay not
   configured" on both devices). Media worked on the same LAN without a relay.
   Relay-only networks are not verifiable in this environment; no TURN secret
   was added or exposed.
3. **Realtime connectivity is unreliable in this environment.** Both devices
   periodically showed "Live updates interrupted — Refresh to check the current
   server status." Refresh/reload reconciled correctly, and the app never
   converted this into `Expired`/`Ended`; however, live push updates were not
   continuously available during the run.
4. **Unexplained accepted sessions.** Sessions requested/accepted at 9:21 PM and
   9:39 PM appeared active while the devices were unattended from this
   automation; neither origin nor the accept action was captured. The client has
   no automatic accept/join path visible in code (only explicit UI handlers call
   `respond`/`join`), so this is recorded as unexplained shared-device activity
   rather than a confirmed defect. The 9:39 request was expected to stay pending
   for the expiry check; it did not. Both sessions were ended from the parent.
   This needs audit-log investigation in a deployed environment.
5. **Accepted session with a vanished child** remains `active` on the server
   until the parent ends it (by design). The parent sees `Reconnecting`/media not
   live, not `Expired`; ending it is a manual parent action.
6. **Abandoned-session policy**: there is no automatic end for an accepted
   session if both apps disappear. The parent can end it from the session screen.
   If the family needs an administrative cleanup (e.g. retention), that is a
   product decision and was not added here.
7. **Automatic resume after reinstall**: after reinstalling the child APK, the
   child app resumed an active consented session and turned the microphone on
   without a new Join tap. This follows the Phase 4 "safe re-negotiation when OS
   permits" rule, but is a privacy-sensitive behavior that should be re-reviewed
   before production (for example, require a fresh Join after a reinstall even
   when a session is active).
8. **Build/verification mismatch**: the UI flow was verified with the first
   debug build; the only later source change was the Remote assistance copy fix.
   The rebuilt APK (hash above) was installed and the corrected copy was
   re-checked on the parent emulator. The lifetime/end logic is identical.

---

## 8. Acceptance checklist

| Criterion | Status |
|-----------|--------|
| Accepted sessions do not expire because of elapsed time | **PASS (implementation + local SQL/Flutter tests)**; hosted observation limited per 7.1 |
| Parent is the sole authority to end the server session | **PASS (implementation + Deno/Flutter tests + device UI)**; hosted reason field blocked |
| Child UI disposal/back/background cannot terminate the session | **PASS for back/leave on device**; dispose, service destruction, permission loss and route changes covered by Flutter/Kotlin tests; screen-lock/backgrounding not separately exercised on device |
| Microphone permission and child consent are respected | **PASS (tests + device Stop sharing flow)** |
| UI distinguishes session authorization from media connectivity | **PASS (device: Active/Reconnecting + Audio not live)** |
| Backend, UI and reconnection follow one lifecycle policy in the repository | **PASS**; deployment required to make hosted match |
| No hosted deployment/secrets/infrastructure changed | **CONFIRMED** — no hosted writes were made |

---

## 9. Files changed (repository)

Server:
- `supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql` (new)
- `supabase/functions/remote-session/index.ts`
- `supabase/functions/remote-session/guard.ts`
- `supabase/functions/remote-session/guard_test.ts`
- `supabase/tests/61_parent_controlled_lifetime.sql` (new)
- `supabase/tests/40_functions.sql`, `supabase/tests/README.md`

Client:
- `lib/data/models/remote_session.dart`
- `lib/features/remote_assistance/remote_session_controller.dart`
- `lib/features/remote_assistance/remote_session_page.dart`
- `lib/features/remote_assistance/remote_assistance_controller.dart`
- `lib/features/remote_assistance/remote_assistance_page.dart`
- `lib/features/child/child_session_page.dart`
- `lib/features/child/child_requests_page.dart`
- `lib/features/child/tabs/child_requests_tab.dart`
- `lib/features/child/controllers/child_shell_controller.dart`
- `lib/features/settings/parent_settings_controller.dart`

Tests:
- `test/features/remote_assistance/remote_session_reliability_test.dart`
- `test/features/remote_assistance/remote_session_controller_test.dart`
- `test/features/remote_assistance/remote_assistance_controller_test.dart`
- `test/features/remote_assistance/remote_session_page_test.dart`
- `test/features/child/child_session_page_test.dart`
- `test/features/child/child_shell_controller_test.dart`
- `test/features/child/child_session_lifetime_test.dart`

---

## 10. Recommended next step (requires authorization)

1. Review the migration and Edge Function diff.
2. Deploy the migration and `remote-session` function through the approved
   process (explicit authorization required).
3. Re-run the device matrix, including a >30-minute accepted-session observation
   and a check that the child ended screen shows `Reason: ended_by_parent`.
4. Configure TURN if relay connectivity is required, and re-test ICE restart on
   a network that forces relay.
