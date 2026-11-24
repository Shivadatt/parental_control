# Agent 2 — WebRTC Media Diagnosis (two-device audit)

Scope: source-only audit of `D:\parentcontrol_app`. No ADB, no builds, no hosted
mutations. Classification tags: **CONFIRMED** (from code/config in this repo),
**CONFIRMED-HOSTED** (from `docs/supabase-hosted-state-verification-2026-11-05.md`,
a recorded read-only dashboard pass of 2026-11-05 against project
`hhqgreaoqulmfwfwarhc`), **SUSPECTED** (needs runtime), **UNVERIFIED**.

---

## 1. Every producer of the UI string "No media is open"

There is exactly **one** code site that emits the string:

- `lib/data/models/remote_session.dart:156-171` — `RemoteSession.mediaNote`.
  It is a pure mapping from the **server status enum** to fixed wording:
  | status | mediaNote |
  |---|---|
  | `requested` | "Off — waiting for the child to accept" |
  | `accepted` | "Off — waiting for the child to join" |
  | `active` | "Started by the child; not verified here" |
  | `declined`/`expired`/`failed` | "No media was opened" |
  | **`ended`** | **"No media is open"** |
- Rendered at exactly one widget: `lib/features/remote_assistance/remote_assistance_page.dart:278`
  (`KeyValueRow(label: 'Media', value: session.mediaNote)`) on the parent's
  assistance **list** screen.

The getter inspects **no** `RTCPeerConnection` state, **no** track count, **no**
local flag — by design (docstring `remote_session.dart:152-155`: "The session
list receives no live track telemetry"). Grep confirms no other producer in
`lib/` (only the historical uiautomation dump `docs/testing/evidence/parent/p02.xml`).

**Precise semantics** — "No media is open" means only *"the server row is
status=ended"*:

- It does **not** distinguish "never attempted" from "attempted and failed" from
  "worked and was torn down". A hypothetically perfect 45-minute call, once
  ended, shows exactly this string (see `docs/stage7_two_device_end_to_end_report.md:258`,
  which records the same label for its PASS run).
- The observed "9 sessions, all No media is open" therefore proves only that
  all 9 rows reached `ended` (audit chain ends with parent-actor end). The
  media verdict must come from other evidence:
  | Evidence | Where | Distinguishes |
  |---|---|---|
  | Live-screen labels `Active` / `Audio unavailable` / `Checking audio…` / `Reconnecting` / `Media connected` chip | `remote_session_page.dart:322-370, 418-522`, driven by `hasActivePeer`+`isConnected`+`isMediaFlowing` (`remote_session_controller.dart:175-181, 427-445`) | attempted-and-connected vs ICE-up-but-no-RTP vs never-attempted |
  | `DEBUG RTP: in N pkts…` (kDebugMode builds only) | `remote_session_page.dart:526-532`, `child_session_page.dart:613-619`, stats loop `remote_session_controller.dart:2294-2355` | real audio-flow proof |
  | `webrtc_signals` rows per session (offer/answer/ice + candidate text) | Supabase dashboard SQL (read-only) | negotiation reached the wire |
  | `ended_reason` (`ended_by_parent` vs `cancelled_by_parent` vs `expired`/`abandoned`) | `supabase/functions/remote-session/guard.ts:142-155` | who closed it and why |
  | Banners "Connection setup failed" / "Media connection" / "Relay not configured" | `remote_session_page.dart:177-239` | attempted-and-failed reasons |

**Classification for the owner:** the label is a *torn-down / server-ended*
display convention, not a media-failure indicator. "Media never connects" is a
separate conclusion supported by §5 causes, not by this string.

---

## 2. Full media negotiation path and ICE/TURN runtime

**Who creates the offer:** the **parent**, always. `join()`
(`remote_session_controller.dart:1283-1314`) calls `createOffer` with
`OfferToReceiveAudio: true` and sends it as `kind:'offer'`. The child answers
(`_answerOffer` `:1057-1076`), either from a buffered offer (`:930-940`) or after
sending the SDP-less `{'ready': true}` marker (`:1327`, `:1728-1767`), which
makes the parent (re-)negotiate (`_handleChildReady` `:1775-1834` — `join()` if
no peer, `restartIce` + fresh offer otherwise). The parent ignores remote offers
while its own offer is pending (`:992-997`) — sole-offerer design.

**Signaling transport:** direct Supabase inserts into `webrtc_signals`
(`supabase_remote_session_repository.dart:171-193`) + Postgres-changes realtime
with row replay (`:223-321`). RLS allows insert only while session status is
`accepted|active` — the **hosted policies carry no expiry predicate**
(CONFIRMED-HOSTED, verification doc §6; migration `20261028000300_signaling_open_session.sql`).

**ICE server list construction (runtime):** client never hardcodes servers.
`fetchIceConfig` → EF `remote-session`, action `ice`
(`supabase/functions/remote-session/index.ts:352-376`) → `buildIceConfig(readTurnEnv(), userId)`
(`supabase/functions/_shared/turn.ts:71-106`). Env inputs: `STUN_URL`
(default `stun:stun.l.google.com:19302`, entries filtered to `stun(s):`),
`TURN_URL` (filtered to `turn(s):`), `TURN_SECRET`, `TURN_TTL_SECONDS` (clamped
60..86400, default 600). The peer is created with exactly these servers
(`remote_session_controller.dart:1236-1240`); empty list → join throws
"The server returned no ICE servers" (`:1185-1191`).

**Ephemeral TURN credential path exists in code:** yes — coturn REST-style
[REDACTED CREDENTIAL ROW]
`_refreshIceServers` (`:1989-2001`, `:2069-2086`).

**Hosted reality (CONFIRMED-HOSTED):**
- Deployed `remote-session` is **v5, 2026-10-26T16:24Z** — a build that predates
  the parent-controlled-lifetime rework; *nothing* was deployed after
  2026-10-27T18:07Z. Its `ice` action exists (a recorded hosted call on
  2026-10-26 returned STUN-only, `turn_configured:false` —
  `docs/turn_configuration.md:38-40`) but the old build also **gates `ice` on an
  unexpired `expires_at`** (`docs/turn_configuration.md:73-77`) and **writes
  `expires_at` on accept** instead of NULLing it (verification doc §7).
- Project secrets include `STUN_URL` but **no `TURN_URL` / `TURN_SECRET`**
  (verification doc §7, names only; `docs/backend.md:21`). ⇒ every runtime ICE
  config is STUN-only, `turn_configured:false`, and the client shows the
  "Relay not configured" banner (`remote_session_controller.dart:477-487` →
  `remote_session_page.dart:195-201`, `child_session_page.dart:173-180`).

---

## 3. Is the parent capable of receiving media?

**CONFIRMED yes — the "parent never creates a peer" theory is ruled out.**
In `join()` the parent:
- creates the `RTCPeerConnection` (`_createExclusivePeer` `:1236`, `:1610-1624`),
- registers `onTrack` (`:1262-1272`) which attaches the remote stream
  (`_attachRemote` `:1674-1696`) and enables the loudspeaker for audio
  (`:1688-1690`),
- sends a `recvonly`-semantics offer (`OfferToReceiveAudio: true`, `:1284-1291`),
- samples `inbound-rtp` deltas to set `isMediaFlowing` (`:2312-2334`).
The parent never `addTrack`s and never requests mic/camera
(`:79-84`, `:1278-1282` skips addTrack for parent, `:1647-1648`) — receive-only
by design, but fully wired for reception. If media fails, it is not because the
parent lacks a peer or an `onTrack`.

Corollary (CONFIRMED): for the 9 audited sessions, the child also created its
peer — the "Assistance session started" audit row is produced by the child's
`markActive` call, which `join()` invokes only **after** permissions, the
confirmed microphone foreground service, capture, and peer creation all passed
(`:1339-1347`). Child pipeline start is therefore proven; failure is downstream
(SDP/ICE connectivity), not capture.

---

## 4. Child vs parent asymmetries

- **Same controller class** (`RemoteSessionController`) for both roles, created
  by two bindings: `remote_session_binding.dart` (parent route) and
  `child/child_session_binding.dart` (fail-closed, `requiredRole='child'`,
  non-child routes collapse to parent/view-only). Different **pages**:
  `remote_session_page.dart` (parent) vs `child_session_page.dart` (child).
- **Join gate:** identical server gate — `canJoin` requires status
  `accepted|active` (`:331-339`), and `join()` re-checks and refuses with
  `consent_required` before touching hardware (`:1098-1108`). The old deployed
  EF's `ice` action additionally requires `consent_recorded`
  (`index.ts:364-370`; set by `acceptPatch`, `guard.ts:170-178`).
- **ICE gathering cannot start before consent** (CONFIRMED): the gathering
  machinery (peer creation → `onIceCandidate`) lives only inside `join()`, which
  is consent-gated; `_prefetchIce` fires only on `accepted|active`
  (`_afterSessionChanged` `:806-813`). No ordering deadlock in repo code. The
  "child joined but no offer yet" race is covered by `_announceChildReady` /
  `_handleChildReady`, and stale replayed offers are discarded by the
  `_signalHorizon` 10 s window (`:253-255`, `:915-921`) precisely so a fresh
  peer never binds a dead negotiation.
- **Real asymmetries:**
  - Truthfulness of chips: parent `_StatusCard._tone` demands `hasActivePeer +
    isMediaFlowing` before a green "active" (`remote_session_page.dart:750-758`);
    the **child page colors `active` success unconditionally**
    (`child_session_page.dart:698-699`) — cosmetic inconsistency.
  - Authority: only the parent can end the server session (`canEnd :343-346`,
    `endSession :2403`); the child only withdraws local capture
    (`withdrawConsent :2195-2235`).
  - Parent auto-rebuilds media on resume (`reconcileAfterResume :2717-2723`);
    child requires capture already live in-process.
- **SUSPECTED (deployed-build) asymmetry:** the live v5 EF gates `ice` on a
  future `expires_at` and stamps a 30-min deadline at consent. On a consented
  session older than its stamped deadline, `fetchIceConfig` returns 410 →
  `iceError` banner → parent `join()` throws before peer creation → "no media"
  even though consent/signaling succeeded. The repo code does not do this; the
  **deployed build may**. Distinguish with the SQL test in §5.

---

## 5. Ranked root causes + cheapest decisive tests (no code changes, no ADB)

Ranked by probability × evidence strength:

1. **NAT traversal with STUN-only config (config + NAT) — top cause.**
   CONFIRMED-HOSTED: no TURN secrets ⇒ relay is impossible. Child (RMX2161,
   carrier/home NAT) and parent (`emulator-5554`) are on different NATs; the
   emulator additionally sits behind the host's `10.0.2.x` virtual NAT, so even
   peer-reflexive/srflx pairing normally cannot punch through both.
   *Cheapest decisive tests — runnable here now:*
   a) On the parent's live session screen check for the **"Relay not
   configured"** banner — on-device proof the ICE config is STUN-only.
   b) Dashboard SQL (read-only):
   `select from_user_id, kind, payload->>'candidate' from webrtc_signals where session_id='<sid>' and kind='ice' order by sequence;`
   — pass/fail criterion: zero `typ relay` candidates on either side, and a
   `10.0.2.x` host candidate from the parent side.
   *Needs infra (cannot run here):* the decisive "would TURN fix it" test
   requires a provisioned coturn + `TURN_URL`/`TURN_SECRET` (`docs/turn_configuration.md` §5-6c).

2. **Stale/under-deployed signaling state (undeployed EF rework) — second.**
   CONFIRMED-HOSTED: live `remote-session` is the pre-2026-10-27 build;
   migrations `20261030000100` (abandoned sweep) NOT applied; `cron` deployed
   but never scheduled (no pg_cron, DEC-05 Choice B).
   *Test — runnable now:* `select status, expires_at, consent_recorded, ended_reason from remote_sessions order by requested_at desc limit 10;`
   — consented rows with non-NULL `expires_at` prove the old EF is answering
   consent; then join a session older than its `expires_at` and look for the
   parent's "Connection setup failed" (410) banner.
   *Not runnable here:* proving the fix requires the DEC-02 redeploy.

3. **Emulator as a media endpoint (platform/network).** Even with STUN, the
   parent emulator's host candidates are `10.0.2.x` (non-routable). Test (b)'s
   candidate dump shows this directly — runnable now. A true second-device test
   (parent on a second physical phone, same Wi-Fi) needs hardware, not TURN.

4. **Timing / negotiation-order races — low probability.** `gen` matching,
   horizon discards, pending-offer buffering and the ready-marker recovery make
   a clean deadlock unlikely (CONFIRMED from code). *Test — runnable now:* do
   one session parent-Join-first and one child-Join-first; compare labels
   ("Media connected" / "Audio unavailable" / "Checking audio…") and the signal
   table. If both orders fail identically → causes 1-3, not timing.

5. **Code bug in the media path — ruled down.** Parent reception is fully
   wired (§3), child start is proven by the `start` audit (§3). No repo-side bug
   found that prevents negotiation given working transport. (Anything in the
   deployed EF body remains UNVERIFIED — deployed source was never pulled;
   verification doc §10.)

6. **Platform restrictions (Android 12 child FGS / one-time mic grant /
   ColorOS kill) — ruled out as the mass cause.** A failed preflight would have
   prevented the "Assistance session started" audit row from ever appearing.
   Still relevant for *background* survival only; single-session test: keep the
   child screen open and observe — runnable now.

7. **TURN credential TTL (600 s default)** — cannot matter while no TURN exists
   (config 1 subsumes it); becomes relevant only after provisioning — UNVERIFIED.

---

## 6. Session lifecycle defects

- **Expiry policy (repo, CONFIRMED):** `expires_at` is a *pending-request*
  deadline only (10 min); consent NULLs it (`guard.ts:157-178`;
  migration `20261028000200`, applied on host — verification §8 items 1-6).
  A consented session is parent-controlled; elapsed time never ends it
  (`remote_session.dart:116-130`, `remote_session_controller.dart:2619-2626`).
- **Hosted divergence (CONFIRMED-HOSTED, SUSPECTED impact):** the deployed v5
  EF "still writes `expires_at` on accept" and expires sessions by its own
  clock mid-run (F1: `docs/phase9-10-…:243`, `docs/runtime-mic-test-report.md:95`).
  This both breaks the parent-controlled policy and feeds cause-4/§5.2 above.
  Contradicting evidence (45-min session survived to an explicit end in Stage 7)
  is itself recorded as conflicting (`phase9-11` report) — mechanism
  attribution: UNVERIFIED.
- **Stranded sessions / stale cleanup (CONFIRMED):** `expire_abandoned_sessions`
  is ABSENT on host (migration `20261030000100` NOT applied) and no scheduler
  exists, so an `accepted|active` row with `expires_at NULL` (which the new EF,
  once deployed, creates) would strand **forever**. Critically,
  `request_remote_session` (live hosted body, verification §5) raises
  `session_in_progress` while ANY open row exists for the device — so a stranded
  consented session **does block all new requests for that device** (409),
  except for stale *pending* rows which it expires in-lock. Currently zero open
  rows hosted (§9.1) — latent, not active, blocker.
- **`end_session` device command — CONFIRMED deliberately failed.**
  `GuardianService.kt:456-460`: the background-command branch emits
  `"failed"` with "Session media is managed by the visible assistance screen
  and cannot be ended by the background service." That is the *native command*
  path only. The parent UI's End button is unaffected: it calls EF action `end`
  (`remote-session/index.ts:308-350`, parent-owner check in `guard.ts:117-128`),
  which your audit log proves is functional (actor=parent "Assistance session
  ended" × 9).

---

## Bottom line

Signaling and consent demonstrably work; the *media plane* was never possible in
this deployment because the hosted project issues **STUN-only ICE** with no TURN
relay while the two endpoints sit behind different (one double) NATs — with the
stale v5 `remote-session` build (30-min expiry, `ice` expiry-gate, no abandoned
sweep) as the secondary cause that will also poison long sessions. The
"No media is open" string itself is only a status=ended caption and must not be
used as the defect evidence line; use the live-screen labels and the
`webrtc_signals` candidate dump instead.
