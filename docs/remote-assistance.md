# Remote assistance: consent, privacy and limits

Status: implementation audit, 2026-10-27. **No two-device media call has been
executed.** Several signaling/teardown defects found by audit (BUG-029) were
fixed and unit-tested on 2026-10-27 (see below); two real peers are still
required to prove media. The executable procedure is
[two-device-webrtc-test-plan.md](two-device-webrtc-test-plan.md).

## Session lifecycle (as implemented)

1. A parent requests an audio or video session for an active device in their
   family (`remote-session` Edge Function, action `request`). The request expires
   after **10 minutes**.
2. The child device sees a pending request naming the guardian. The child must
   explicitly **Accept** or **Decline**. Accepting records consent, sets a fresh
   **30-minute** expiry and a session nonce. Accepting does not open media.
3. The child opens the session screen and taps **Join**; only then does
   `getUserMedia` run. The parent joins from its own explicit Join tap after the
   server reports `accepted`.
4. Either participant can end the session. Ending stops both local tracks and
   disposes the peer connection; a terminal Realtime update does the same on the
   other side.
5. Expiry, device revocation and family unlinking end or invalidate the session
   server-side. `expires_at` is checked by `respond`, `start` and `ice`, and by
   the signal RLS, so late signals fail closed even if no sweep has run. The
   scheduled `expire_stale_sessions` sweep is not enabled in the hosted project
   (`CRON_SECRET` unset), so a session row can remain `accepted` past its expiry
   until a client auto-end or a later lazy expiry.
6. An active session is shown only in the visible app UI. The app does not run a
   camera/microphone foreground service, so there is no background-call mode.

The `remote-session` `start` action exists and marks a session `active`. The
Flutter client previously never called it, so a live call stayed **Accepted** in
the UI with `started_at` null. This was fixed on 2026-10-27 (BUG-029): the
controller now marks the session active once the peer connection connects, so
the UI shows **Live**. The fix is unit-tested but **NOT TESTED** between two
physical devices.

Other audit findings fixed in the same change: early ICE candidates that arrived
before the peer/remote description existed are now buffered (≤64) and flushed
instead of dropped; `endSession` stops local media **before** calling the server
so a failing server end cannot leave the camera/microphone open; and back
navigation runs a `PopScope` that ends the session / releases media. All are
covered by `test/features/remote_assistance/` (11/11 pass), including
`stops local media even when the server end call fails`.

## Signaling and credentials

- Signaling uses the `webrtc_signals` table with RLS: only the two session
  participants may select/insert, only while the session is accepted/active and
  not expired, and `from_user_id` must equal the authenticated user.
- Flutter subscribes to `postgres_changes` on that table using a private
  Realtime channel; it also replays stored signals after subscribing so a late
  joiner can apply an offer sent before it subscribed.
- STUN is public (`STUN_URL`, default Google STUN).
- TURN credentials are generated server-side using the coturn REST scheme
  (`TURN_URL`, `TURN_SECRET`, `TURN_TTL_SECONDS`) and returned by the `ice`
  action only to participants of an accepted/active session with recorded
  consent and an unexpired `expires_at`. The response contains only ephemeral
  HMAC-derived credentials; the shared secret never leaves the Edge Function.
- If TURN is not configured, the server returns STUN-only ICE with
  `turn_configured:false` and a warning; the session screen shows **Relay not
  configured** instead of pretending a relay exists.
- The TURN credentials are cached by the session controller for the lifetime of
  the screen. A new screen (or a new session) fetches fresh credentials.
  `TURN_TTL_SECONDS` defaults to 600 s, which is shorter than the 30-minute
  session; the current build has no ICE restart (G7), so this only matters if a
  future reconnection path is added and forgets to refetch ICE.

## Permissions

- Camera and microphone are requested only from **Join**, through
  `DeviceAdminService.requestPermissions(camera: kind == video, microphone:
  true)`, before `getUserMedia`. Accepting a request opens no media.
- Denial is shown as a permission state with a specific message; the app does
  not fall back to a broken session. The parent requests no camera for an
  audio-only session.
- The Android runtime permission bridge and the camera/microphone capture path
  were exercised on one phone by the local **Camera and microphone test**
  (Settings → child), which uses the same permission call. That proves this
  phone's capture and preview, not a two-device call.

## Explicitly not implemented

- Hidden or automatic recording.
- Covert camera/microphone activation.
- Silent background surveillance, screenshots, keylogging.
- Reading private messages, passwords or one-time codes.
- Permission bypass, root, Accessibility abuse or notification/service tricks.
- In-session mute/unmute, camera on/off, speaker routing or camera switching.
  Only the local camera/microphone self-test has a mute toggle.
- ICE restart or automatic re-subscribe after a signaling channel error.

No recording feature is present, therefore no recording retention policy applies.
Session metadata (`remote_sessions`) and audit events are retained. The owner's
retention/purge action currently deletes only `location_events` and
`usage_daily`, not session or audit rows; it is therefore not a session-metadata
purge.

## Verification status (2026-10-27)

Labels: **CODE-VERIFIED** (read in source), **UNIT-TESTED** (repository tests,
not re-run in this audit), **HOSTED API VERIFIED** (live `remote-session` checks
recorded in `.tools/live/results/phase2.json`), **LIVE VERIFIED** (observed on
the hosted project or the physical phone), **BLOCKED**, **NOT TESTED**.

| Claim | Status | Evidence / limit |
|---|---|---|
| Parent requests, child sees the request | HOSTED API VERIFIED | `remote.request`, `remote.visible_to_child` PASS; on-device visibility requires the child to open **Requests** (15 s poll) or refresh — no push (G8) |
| No auto-accept; only the child accepts/declines | CODE-VERIFIED + UNIT-TESTED + HOSTED API VERIFIED | `respond` requires the child profile and `child_user_id`; consent tests; foreign child `403` |
| Accept opens no media or negotiation | UNIT-TESTED | `accepting only records consent and opens no media or negotiation`; `accepting an already accepted session is idempotent` |
| Decline ends the request and reaches the parent | CODE-VERIFIED + UNIT-TESTED | Server sets `declined`/`ended_at`; the parent session screen shows **Request declined** via Realtime. No push notification exists, so the parent sees it only while that screen is open (or after a refresh) |
| Parent cannot answer for the child | UNIT-TESTED | `the parent side cannot answer a request for the child` |
| Permission asked before `getUserMedia`; denial handled | CODE-VERIFIED + UNIT-TESTED | `asks Android for camera and microphone before opening media`; same native bridge exercised by the on-device self-test |
| Session authorization (accept, start, ICE, end) | HOSTED API VERIFIED | `remote.child_accepts_with_consent`, `remote.start_after_consent`, `remote.ice_config_uses_stun`, `remote.parent_ends_session`; foreign parent ICE `403`. The hosted `start` call was made by the QA harness; the Flutter client now calls `markActive` itself after BUG-029, but that client call is **NOT TESTED** on a device |
| Signal read/write restricted to participants; no spoofing | CODE-VERIFIED + LOCAL SQL VERIFIED | `webrtc_signals` RLS (`supabase/migrations/20260101000200_rls.sql:202-231`); `parent1 reads session signals`, `child1 reads the other party signal`, `child1 cannot spoof signal authorship`, `parent2 cannot read family1 signals`. Hosted signal insert was **not** exercised |
| Private Realtime topics | HOSTED API VERIFIED (family topic) | Family parent/child `SUBSCRIBED`; foreign parent and anon denied. The session/signal topic subscription itself was **NOT TESTED** on the hosted project (local policy tests only) |
| STUN-only ICE when TURN is absent | HOSTED API VERIFIED | `turn_configured:false`, one STUN server |
| On-device capture/preview (one phone) | LIVE VERIFIED | `integration_test/child_media_selftest_test.dart`: main + front camera live, 1280×720 frames, mute, stop — preview only, never recorded |
| Two-device audio/video media | **BLOCKED** | Only one physical device (RMX2161) and no emulator; no second peer |
| TURN relay | **BLOCKED / NOT CONFIGURED** | No `TURN_URL`/`TURN_SECRET`; TURN-only network path not testable |
| In-session mute / camera off | **NOT IMPLEMENTED** | No control exists on either session screen |
| Background/lock behavior | **NOT TESTED** | No lifecycle observer; depends on Android restrictions |
| Reconnection after network loss | **NOT IMPLEMENTED / NOT TESTED** | No ICE restart; channel error only shows a warning |

Unit coverage: 11 controller tests in `test/features/remote_assistance/`
(`remote_child_session_test.dart`, `remote_session_controller_test.dart`) plus
the shared Deno suite (26 tests, including `turn_test.ts`). The hosted API flow
is covered by `.tools/live/verify_devices.mjs` and the recorded phase 2 results.

## Known implementation gaps (code-verified)

G1–G4 were fixed on 2026-10-27 (BUG-029) and are now covered by unit tests; the
remaining G5–G10 are still open. None of this is a claim of working two-device
media, because that has not been executed between two real peers.

| ID | Sev | Gap | Status / evidence |
|---|---|---|---|
| G1 | P1 | Parent ICE candidates arriving before the child's peer exists were discarded (no candidate queue), and `addCandidate` ran without waiting for a remote description. | **FIXED** (BUG-029): candidates buffered (≤64) and flushed after the remote description. `test/features/remote_assistance/` |
| G2 | P2 | `start`/`markActive` was never called: sessions stayed `accepted`, `started_at` null, no `session_started` audit, **Live** never shown. | **FIXED** (BUG-029): the client marks the session active on connect. Two-device NOT TESTED |
| G3 | P2 | If the `end` call failed (offline), `endSession` returned without stopping local tracks; camera/mic kept running. | **FIXED** (BUG-029): media stops before the server call (`stops local media even when the server end call fails`) |
| G4 | P2 | Leaving the session screen stopped local tracks but did not end the session or notify the peer. | **FIXED** (BUG-029): `PopScope` ends the session / releases media on back-navigation. Two-device NOT TESTED |
| G5 | P2 | No in-session mute/unmute or camera on/off. | OPEN. session pages; only `lib/features/child/widgets/media_self_test_sheet.dart:147` |
| G6 | P2 | No `WidgetsBindingObserver`/lifecycle handling in the session controller and no camera/mic foreground service; background capture is not actively stopped by the app. | OPEN. `lib/features/remote_assistance/**` (no lifecycle listener) |
| G7 | P2 | No ICE restart and no re-subscribe after a Realtime channel error; the warning tells the user to end and request again. | OPEN. `remote_session_controller.dart:176-179`, `:285-288`, `:506-531`; repository `:246-257`, `:350-361` |
| G8 | P2 | Request visibility on the child shell relies on a manual refresh; only the open Requests screen polls (15 s). No push (FCM not configured). | OPEN. `child_requests_controller.dart:43-49`; `child_shell_controller.dart:136-141` |
| G9 | P3 | Client auto-end on expiry records `ended` with reason `expired`, not status `expired`. | OPEN. `remote_session_controller.dart:683-694`; `remote-session/index.ts:270-309` |
| G10 | P3 | The parent page's `isViewOnly` banner is unreachable/mislabeled (that page is parent-only). | OPEN. `remote_session_page.dart:74-85`; `remote_session_controller.dart:68` |

## TURN relay setup

TURN is **not configured** in the hosted project today. Without it, calls on
restrictive networks (carrier NAT, AP isolation, UDP-blocking firewalls) can
fail; the app must show the **Relay not configured** warning. This section is
operational guidance only; it is not evidence that a relayed call works.

### 1. coturn minimal configuration

Use `use-auth-secret` (coturn REST credentials) so the Edge Function can mint
short-lived credentials. The values below contain no secret; the secret comes
from your secret store.

```conf
# /etc/turnserver.conf (minimal)
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=<TURN_SECRET_FROM_SECRET_STORE>
realm=turn.example.com
# Set this when the server is behind 1:1 NAT:
# external-ip=<public-ip>/<private-ip>
min-port=49152
max-port=65535
no-cli
no-multicast-peers
```

- Open UDP/TCP 3478 and, for `turns:`, TCP 5349 in the firewall/security group.
- If you use `turns:`, install a valid certificate for the TURN hostname.
- `static-auth-secret` must exactly equal the `TURN_SECRET` Edge secret.
- Do not enable the coturn CLI on a public interface.

### 2. Supabase Edge Function secrets (dashboard-managed)

Project Settings → Edge Functions → Secrets (dashboard):

| Name | Required | Meaning |
|---|---|---|
| `TURN_URL` | for TURN | Comma/space-separated `turn:`/`turns:` URLs matching the coturn listener |
| `TURN_SECRET` | for TURN | coturn `static-auth-secret`; server-side only |
| `STUN_URL` | optional | Override the default Google STUN |
| `TURN_TTL_SECONDS` | optional | Ephemeral credential lifetime, clamped 60–86400 (default 600) |

Rules:

- `TURN_SECRET` is a **server-side secret**. It exists only in the coturn
  configuration/secret store and the Supabase Edge Function secret store.
- Never put it in Flutter, `--dart-define`, `lib/`, `assets/`, a committed
  `.env`, the APK, test fixtures, screenshots or logs. The app only ever
  receives the HMAC-derived username/credential with an expiry.
- Set secrets through the dashboard or `supabase secrets set --env-file
  <gitignored file>`; never as command-line values (shell history/process
  listings). Do not print `.tools/*.env`.
- The `ice` action is the only issuer; it requires a participant of an
  accepted/active, consented, unexpired session.
- The hosted dashboard is the source of truth; a rotated secret must be updated
  there, not in the repo.

### 3. Verification command

Preferred: read the ephemeral credentials from the deployed `ice` action for a
QA session (they are scoped to the user and expire in `TURN_TTL_SECONDS`), then
run coturn's client against the relay. This avoids handling the shared secret
locally.

On the coturn host, start a peer for the client to relay to:

```bash
turnutils_peer -L 127.0.0.1 -p 3480
```

On a test machine with `turnutils_uclient`:

```bash
# Use the username/credential returned by the ice action (no secret here):
turnutils_uclient -u "<expiry>:<user-id>" -w "<base64-hmac-credential>" \
  -p 3478 <turn-host>
```

If you must mint credentials locally for a lab check, read the secret from the
secret store into the environment and do not echo it:

```bash
EXPIRY=$(( $(date +%s) + 600 ))
USERNAME="$EXPIRY:<test-user-id>"
CREDENTIAL=$(printf '%s' "$USERNAME" | openssl dgst -sha1 -hmac "$TURN_SECRET" -binary | openssl base64)
turnutils_uclient -u "$USERNAME" -w "$CREDENTIAL" -p 3478 <turn-host>
```

`turnutils_uclient` flags vary by coturn version; check `turnutils_uclient -h`.
A successful allocation/relay test proves the relay and credentials, not the
app's media path. The app path is proven only by the two-device TURN-only test
(T14 in the test plan), which is currently **BLOCKED**.

Also confirm the server-side response after configuring TURN: the `ice` action
must return `turn_configured:true`, a TURN entry with a username/credential, and
no `warning`; the session screen must no longer show **Relay not configured**.
The shared secret must not appear anywhere in that response
(`turn_test.ts` asserts this).

### 4. Rotation

1. Generate a new random secret (at least 32 bytes) into the secret store, e.g.
   `openssl rand -base64 48` written directly to the store, never to shell
   history.
2. Update coturn's `static-auth-secret` and reload/restart coturn.
3. Update `TURN_SECRET` in the Supabase dashboard back-to-back. If Edge
   Functions do not pick it up immediately, redeploy the `remote-session`
   function.
4. Existing ephemeral credentials stay valid until their TTL (default 600 s).
   For a hard cutoff, lower `TURN_TTL_SECONDS` before rotating and end active
   sessions so clients fetch new credentials.
5. Verify: `turn_configured:true`, the `turnutils_uclient` check, and (when a
   second device is available) a TURN-only call.
6. If the secret leaked, rotate immediately, review coturn/Edge logs for relay
   abuse, and revoke/rotate any other secret stored beside it. Never commit the
   new value.

## Bottom line

Consent, server-side authorization, the STUN-only ICE response and the
single-phone capture path are verified. The audit findings G1–G4 were fixed and
unit-tested on 2026-10-27 (BUG-029). The remote audio/video path between two
devices is still **not** verified: there is one physical device, no TURN relay
and no scheduled expiry job, so an end-to-end remote-assistance call must not be
claimed until a two-device run passes.
