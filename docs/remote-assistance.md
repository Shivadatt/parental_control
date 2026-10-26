# Remote assistance: consent, privacy and limits

## Session lifecycle

1. A parent requests an audio or video session for an active device in their family
   (`remote-session` Edge Function, action `request`). The request expires after
   **10 minutes**.
2. The Child device sees a visible pending request naming the guardian. The child
   must explicitly **Accept** or **Decline**. Accepting records consent, sets a
   fresh **30-minute** expiry and a session nonce.
3. The Child starts the session (`start`) only after accepting. Until the server
   reports `accepted`/`active`, no camera, microphone or peer connection is opened.
4. Either participant can end the session at any time. Sessions also end on expiry,
   device revocation or family unlinking. The parent page stops tracks and disposes
   the peer connection on any terminal state.
5. An active session is shown with an in-app indicator; the Child side uses a visible
   foreground session and never runs media silently in the background.

## Signaling and credentials

- Signaling uses the `webrtc_signals` table with RLS: only the two session
  participants may select/insert, only while the session is accepted/active and not
  expired, and `from_user_id` must equal the authenticated user.
- Flutter subscribes to `postgres_changes` on that table. No public broadcast channel
  carries location, codes or media signaling.
- STUN is public (`STUN_URL`, default Google STUN).
- TURN credentials are generated server-side using the coturn REST scheme
  (`TURN_URL`, `TURN_SECRET`, `TURN_TTL_SECONDS`) and returned by the `ice` action
  only to participants of an accepted/active session. The TURN secret never enters
  the APK.
- If TURN is not configured, the server returns a warning; the UI must show that
  connectivity may fail on restrictive networks instead of pretending TURN exists.

## Permissions

- Camera and microphone are requested only when the child accepts/starts a session,
  using the Android runtime permission flow.
- Denial is shown as a permission state; the app never opens the camera or microphone
  without an explicit user action and a granted permission.
- Android foreground-service rules are respected. If background media is not
  permitted, the session stays in a visible foreground UI rather than circumventing
  the restriction.

## Explicitly not implemented

- Hidden or automatic recording.
- Covert camera/microphone activation.
- Silent background surveillance, screenshots, keylogging.
- Reading private messages, passwords or one-time codes.
- Permission bypass, root, Accessibility abuse or notification/service tricks.

No recording feature is present, therefore no recording retention policy applies.
Session metadata and audit events are retained according to the family's settings and
can be purged by the parent owner through the audited retention/purge actions.

## Verification status

The signaling repository and UI states are implemented, but a real parent-child media
session requires a configured Supabase project (for Auth, RLS, Realtime and the ICE
function) and two enrolled devices. Without that backend the end-to-end call is
**BLOCKED**, and this is recorded as such in
[verification-report.md](verification-report.md).
