# Stage 6 — QA Accounts, Child Stop Control and Media Recovery

Date: 2026-10-29
App: Parent Control 1.0.0+1 (debug)
Scope: QA account verification, the missing child Stop sharing control, and the
5–7 minute audio assistance media failure.

> Status: **partial**. The child Stop sharing control is fixed and covered by
> automated tests. The requested `ankit1@gmail.com` / `ankit@gmail.com` accounts
> cannot be verified or created from this environment (**BLOCKED**), and the
> current QA device links are all revoked, so the live Stop/recovery scenarios
> could not be exercised on the final build (**BLOCKED**, not passed). No hosted
> Supabase change, secret change or deployment was made.

---

## 1. QA accounts

### 1.1 Requested accounts

`ankit1@gmail.com` (parent) and `ankit@gmail.com` (child) do **not** appear
anywhere in this repository: not in docs, migrations, seeds, scripts, fixtures or
environment examples. Their existence in the hosted project can only be checked
in `auth.users`, which is Dashboard-only.

**Result: BLOCKED.** No credentials, email inbox or Supabase Dashboard session
was available. No account was created, no password was invented and no
authentication was weakened. The Supabase CLI was not used.

### 1.2 Accounts actually signed in on the test devices

| Device | Account | Role observed |
|---|---|---|
| realme RMX2161 (`5HXWRGQ4IFU8WS4T`) | `qa.child.a2.20261026@example.com` | child, family “QA Family A”, device registered |
| emulator `emulator-5554` | QA Family A parent | parent |

These are the documented QA accounts from
`docs/verification-report.md` and `docs/backend.md`, not the requested `ankit`
accounts.

### 1.3 Exact manual steps if the accounts are absent

1. Supabase Dashboard → Authentication → Users → **Add user**: create
   `ankit1@gmail.com` and `ankit@gmail.com` (or sign up in the app), and confirm
   the email.
2. Sign in on each device and choose the role through the existing
   `auth-bootstrap` flow. A role is set once and must be verified by the server;
   a local role field never grants access
   (`supabase/migrations/20260101000000_core.sql:456-507`).
3. As the parent, create the family; as the child, accept the pairing request
   and register the device. Only then can the parent request assistance.

Do not send passwords or tokens through chat, logs or commits.

---

## 2. Child Stop sharing control (fixed)

### 2.1 Reported symptom

In the failure state the child screen showed “Connection setup failed”,
“Microphone is stopped — not sharing audio” and the copy “You can stop sharing
at any time”, but the **Stop sharing** control was missing.

### 2.2 Confirmed cause

`canStopSharing` required a live peer **or** live local capture:

```dart
// before
isChildRole &&
(hasActivePeer.value || _captureActive) &&
status.isOpen
```

When ICE recovery exhausts, `_pauseMediaAfterConnectionLoss()` clears
`_captureActive`, `_teardownMedia()` closes the peer, and the button disappears
while the server session intentionally stays open. The leave-note and media-card
copy kept referring to Stop sharing. A safe retry also reported an error
(“Camera and microphone are already off…”) even though the desired state was
already true.

### 2.3 Fix

- `lib/features/remote_assistance/remote_session_controller.dart:254` —
  `canStopSharing` is now true for any `accepted`/`active`, non-expired child
  session. It no longer depends on peer or capture state.
- `lib/features/remote_assistance/remote_session_controller.dart:1775` —
  `withdrawConsent()` is idempotent: with no live capture it sets
  `sharingStopped`, clears the error and returns true. It still never calls the
  server `end` RPC; only the parent ends the session.
- `lib/features/child/child_session_page.dart:116` — the button continues to be
  rendered from `canStopSharing`, so it is present in the join/reconnect,
  media-card and failed-recovery states.

### 2.4 Retry truthfulness (same failure path)

- `remote_session_controller.dart:937` — `join()` clears the stale
  “Connection setup failed” banner before a new attempt.
- `remote_session_controller.dart:705` and `:943` — an explicit refresh or join
  re-arms signaling after the five-attempt terminal state instead of leaving the
  session permanently unable to receive an answer. The copy already tells the
  user to refresh to retry.

### 2.5 Tests

| Test | Change |
|---|---|
| `test/features/child/child_session_page_test.dart` “Stop sharing confirms…” | now expects the control to remain visible after withdrawal |
| `test/features/child/child_session_page_test.dart` “an active session with no peer…” | now expects Stop sharing to be visible |
| `test/features/remote_assistance/remote_session_controller_test.dart` new “withdrawing consent with no live capture…” | verifies idempotent success, no server end, control still available |

---

## 3. The 5–7 minute media failure

### 3.1 Confirmed code mechanism

There is **no 5-, 7- or 10-minute media timer** on the client for a consented
session, and the repository server has none either. The observed permanent
failure is produced by this chain:

1. The peer stops receiving media (process death, network change/NAT or OS
   restriction).
2. ICE recovery runs with a bounded budget: 3 s disconnect grace, then at most
   two restarts (2 s and 5 s backoff, 20 s per attempt)
   (`remote_session_controller.dart:77-82`, `:1505-1533`).
3. About 45–50 s later `_exhaustIceRecovery()` sets `iceError` and
   `_pauseMediaAfterConnectionLoss()` stops capture and tears the peer down
   (`:1592-1615`, `:2022-2067`). The server session correctly stays open.
4. Recovery is **manual on both sides**: the parent must press “Join with
   explicit consent”, which creates the offer, and the child must press
   “Reconnect microphone” (or already have its peer) so the new offer is
   answered. Neither side re-offers automatically after exhaustion.
5. Previously, the child could keep showing the stale failure banner after a
   retry and signaling could stay permanently terminal after five subscription
   failures. Both are corrected in §2.4.

### 3.2 What is not proven

The trigger that killed the original connection at 5–7 minutes is **not
confirmed**. Candidates are OEM/Android 12 process or service reclamation,
Wi-Fi/mobile handover, and NAT mapping expiry; STUN-only operation makes the
latter more likely. No logcat/RTP capture of the original incident is
available, so this part is recorded as **BLOCKED**, not as a confirmed OS bug.

The 5–7 minute window does not correspond to any client timeout, the 10-minute
pending-request deadline, or an accepted-session lifetime. TURN credentials
default to 600 s, but the hosted project is STUN-only
(`docs/turn_configuration.md:14-41`).

### 3.3 Backend status

- Accepted/active sessions have no repo expiry; only pending requests have a
  10-minute deadline (`20261028000200_parent_controlled_session_lifetime.sql`).
- The hosted project still runs the older backend: the three `20261028*`
  migrations are repo-only, and the old `webrtc_signals` policy requires
  `expires_at > now()` (`20260101000200_rls.sql:202-231`). Deploying
  `20261028000200` without `20261028000300` would break signaling for sessions
  with a NULL deadline, so they must go together. No deployment was performed.

---

## 4. Files changed in this stage

| File | Change |
|---|---|
| `lib/features/remote_assistance/remote_session_controller.dart` | Stop-control gate, idempotent withdrawal, stale banner clearing, signaling retry re-arm |
| `lib/features/child/child_session_page.dart` | no code change; control now renders in all consented states via the controller |
| `test/features/child/child_session_page_test.dart` | visibility expectations |
| `test/features/remote_assistance/remote_session_controller_test.dart` | idempotent withdrawal test |
| `supabase/tests/62_signaling_consented_session.sql` | local test for NULL-deadline signaling (previous stage, repo-only) |
| `supabase/tests/README.md` | suite command/coverage updated |

No Android, Edge Function or hosted configuration was changed in this stage.

---

## 5. Automated verification

| Command | Result |
|---|---|
| `.fvm/flutter_sdk/bin/flutter analyze` | **No issues found** (2026-10-29) |
| `.fvm/flutter_sdk/bin/flutter test` | **252 passed, 0 failed** (2026-10-29) |
| `gradlew :app:testDebugUnitTest --rerun-tasks` | **32 passed, 0 failed** (8 recreation, 7 watchdog, 4 start gate, 13 policy; re-executed 2026-10-29) |
| `deno test supabase/functions/_shared/` | **36 passed** (2026-10-29, no server change since) |
| Local SQL suite (ten migrations, tests through `62`) | **EXIT=0**, `ALL CONSENTED-SESSION SIGNALING TESTS PASSED` (2026-10-29) |

APK: `build/app/outputs/flutter-apk/app-debug.apk`
Size: **243,790,747 bytes**
SHA-256:
`d8eecfa51ca5e5c66a14d4494af9eafea7a0f24901912b0a18756fbacf680efd`
Built 2026-10-29 08:13 via `bash scripts/build_debug_apk.sh` (FVM Flutter
3.44.6, `--dart-define-from-file=.tools/live_config.env`), i.e. **after** the
final `withdrawConsent` edit that this report's verification covers.

Two superseded artifacts from earlier in this stage, kept for traceability:

| Artifact | Size | Disposition |
|---|---|---|
| `937dc14d8559b8b95e4ea5e87c99e2d36cba4834a673f7fac56d43bf20492867` | 243,792,301 B (08:00) | predates the idempotent-withdrawal edit; replaced |
| `b9103b3cc00a4d0f5a7c8f9f6856be47f9abff007190f39d99b4c34b283110e5` | 243,799,136 B (08:11) | built **without** dart-defines; it launched into “Connect the backend” and was rejected |

Both devices now run the final artifact: `adb install -r` returned `Success`,
and the installed `base.apk` on each device is exactly 243,790,747 bytes,
matching the build output.

---

## 6. Device verification

### 6.1 What was executed on the final build

| Scenario | Result | Evidence |
|---|---|---|
| Install final APK on child realme and parent emulator | PASS | both installs returned `Success`; installed `base.apk` = 243,790,747 B on both |
| Final build keeps the Supabase config (not “Connect the backend”) | PASS | `06-final-build-child-home.png`, `07-final-build-parent-revoked.png` |
| Child app launches and restores the signed-in child account | PASS | `06-final-build-child-home.png` |
| Child Requests tab | PASS (empty) | `02-child-no-pending-requests.png` |
| Child permissions (mic, camera, notifications, device admin) | PASS (all granted) | `03-child-settings-permissions.png` |
| Parent dashboard / device list | **FAIL (environment)** — all three QA devices are `Revoked`, last seen 2 days ago; no active device or session | `04-parent-dashboard-revoked-devices.png`, `05-parent-devices-revoked.png` |
| Live Stop sharing visibility after recovery exhaustion | **BLOCKED** — no active session can be created while every device is revoked | — |
| Close/reopen, 7-minute endurance, network loss, parent End, permission revoke on final build | **BLOCKED** for the same reason | — |

The child account still reads “Linked”, but the parent’s server-side device rows
are revoked. Re-linking requires a fresh pairing invite and child approval; that
state change was not performed without the account/link decisions belonging to
the owner.

### 6.2 Previous two-device matrix (earlier Stage 5 build)

These results were recorded on build
`5bef45d6a2e313b06277db9f0a13dd79f8ce96ae3d96892c166ba8d4ee7f4341`
(243,792,348 bytes), **before** the Stop-control fix. They are not results for
the final APK.

| Scenario | Result |
|---|---|
| Child Home 30 s, audio live | PASS |
| Screen lock 135 s, audio continues | PASS |
| Recents swipe: process/FGS and parent audio survive | PASS |
| Reopen child: same process/session, single service | PASS |
| Network loss: truthful “Reconnecting”, session stays open | PASS |
| Automatic media recovery after network return | **FAIL** (no renegotiation) |
| Explicit rejoin on the same session | PASS |
| Dashboard “Stop sharing” releases mic/service, session stays open | PASS |
| Force Stop: process/service gone, parent says audio not live, session open | PASS (not bypassed) |
| Parent End | PASS (`ended_by = PARENT_A`) |
| Microphone permission revocation stops service, no auto restart | PASS |
| TURN relay refresh | **BLOCKED** — no TURN relay configured; provisioning not authorized |

The Force Stop result is a truthful failure, not a survival claim: Force Stop,
process death and OEM task cleaners end media and this app does not bypass them.

---

## 7. Required manual settings and limitations

- The realme notification channel `audio_assistance_channel` was observed with
  importance `NONE`; the microphone foreground service still runs, but its
  ongoing notification is not visible in the shade. The app no longer claims a
  visible notification. Enabling that channel is a user/device choice; no
  setting was changed silently.
- Battery optimization and OEM auto-start/freeze settings were left unchanged.
  No claim is made that disabling them guarantees survival.
- No TURN relay exists. Audio depends on STUN/direct connectivity and can fail
  on carrier NAT or restrictive networks.
- Automatic cross-device renegotiation is not implemented. After an unrecovered
  connection loss, both participants must explicitly rejoin the same session;
  the server session is never duplicated or ended by this.
- The hosted Supabase backend still runs the pre-Stage-4 session lifetime and
  signaling policy. Deployment is **BLOCKED** pending explicit authorization and
  must include both `20261028000200` and `20261028000300`.
- The requested `ankit` QA accounts remain unverified for the same reason.

---

## 8. Evidence index

- `docs/evidence/stage6/01-child-linked-home.png`
- `docs/evidence/stage6/02-child-no-pending-requests.png`
- `docs/evidence/stage6/03-child-settings-permissions.png`
- `docs/evidence/stage6/04-parent-dashboard-revoked-devices.png`
- `docs/evidence/stage6/05-parent-devices-revoked.png`
- `docs/evidence/stage6/06-final-build-child-home.png` (final APK `d8eecfa5…`)
- `docs/evidence/stage6/07-final-build-parent-revoked.png` (final APK)
- Stage 5 device evidence: `docs/evidence/stage5/` (25 files)
