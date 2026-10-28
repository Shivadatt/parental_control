# TURN relay: root cause, configuration and verification

Status date: 2026-10-28. Scope: local source (read-only), hosted-state guidance.
This document does not change any code, secret or hosted setting. Every claim
below is either **CODE-VERIFIED**, **RECORDED EVIDENCE** (a stored result from an
earlier run) or **NOT VERIFIED / NOT TESTED**.

Hosted project state (which secrets exist, which function build is deployed) was
**not readable** in this audit; treat all hosted statements as "as last recorded",
not "as of now".

---

## 1. Root cause of `turn_configured: false`

`turn_configured` is **not** a health check of a relay. It is a boolean that says
"this response contains a TURN entry", computed in one place:

- The two secrets are read from the Edge Function environment:
  `supabase/functions/_shared/turn.ts:30-38` (`TURN_URL`, `TURN_SECRET`,
  optional `TURN_TTL_SECONDS`, optional `STUN_URL`).
- `TURN_URL` is split on commas/whitespace and filtered to `turn:`/`turns:`
  schemes; `TURN_SECRET` is trimmed (`turn.ts:41-47`, `:84-85`).
- If **either** the URL list is empty **or** the secret is empty, the function
  returns STUN-only with `turn_configured: false` and the warning
  `"TURN is not configured. Audio and video may fail on restrictive networks."`
  (`turn.ts:86-93`).
- Only when both are present does it mint credentials and set
  `turn_configured: true` plus `expires_at` (`turn.ts:95-105`).

So `turn_configured: false` has exactly four possible inputs: `TURN_URL` absent
or blank; `TURN_URL` present but containing no `turn:`/`turns:` entry (for
example `http://host`, a typo, or a bare hostname); `TURN_SECRET` absent or
whitespace-only; or the running function not being the build that reads these
names. There is no other switch: nothing in the database, no feature flag, no
per-family setting.

Recorded evidence: the hosted `ice` call on 2026-10-26 returned one STUN server
and `turn_configured: false`
(`.tools/live/results/phase2.json:247-253`, test `remote.ice_config_uses_stun`).
`docs/backend.md:21` also records `TURN_URL`/`TURN_SECRET` as absent at audit
time.

### "Secret not set" versus "deployment not updated"

These are different failures and only the first is diagnosable from here:

| Hypothesis | What it means | How to distinguish |
|---|---|---|
| Secrets were never created | No `TURN_URL`/`TURN_SECRET` row in the project's Edge Function secrets | Dashboard → Project Settings → Edge Functions → Secrets: the rows are absent |
| Secrets exist but the running function predates them | Secrets are project-level and normally visible to new invocations immediately; a stale isolate/rollout can still serve the old environment | Dashboard → Edge Functions → `remote-session`: compare the deployed version/time with the secret "updated" time, then redeploy and re-check |
| Secrets exist with a bad shape | `TURN_URL` without a `turn:`/`turns:` prefix, or a secret containing only spaces | Presence check passes but the endpoint still returns `false`; compare the endpoint against the recorded URL format in §4 |
| Secret mismatch with coturn | `turn_configured: true` but every allocation is rejected `401`/`438` | Endpoint check passes; coturn logs reject the credentials (expired timestamp or wrong `static-auth-secret`) |

Reading the secret **values** is neither necessary nor allowed; presence,
timestamp and endpoint behaviour are enough. Deployment staleness is
**NOT VERIFIED** here and cannot be settled without the Dashboard.

---

## 2. What the server actually issues

- Username: `<unix-expiry>:<userId>`, where expiry = now + TTL
  (`turn.ts:95-97`).
- Credential: `base64(HMAC-SHA1(TURN_SECRET, username))` (`turn.ts:55-69`,
  `:98`).
- TTL: parsed from `TURN_TTL_SECONDS`, clamped to **60..86400 s**, default
  **600 s** (`turn.ts:26-28`, `:49-53`).
- Response: `{ ice_servers: [...], turn_configured, expires_at?, warning? }`
  (`turn.ts:18-23`); the STUN entry is separate and stays present
  (`turn.ts:76-82`). The shared secret is never echoed; `turn_test.ts:88-91`,
  `:178-181` assert this.
- Issuer: `remote-session` action `ice` (`supabase/functions/remote-session/index.ts:311-337`).
  It requires an authenticated participant (`:312-315`), session status
  `accepted`/`active` (`:316-322`), recorded consent (`:323-329`) and an
  unexpired `expires_at` (`:330-333`); otherwise `403`/`409`/`410`. Consent sets
  a **1800 s** session lifetime (`:29`, `:187`).

The client is a pure consumer: `fetchIceConfig` posts `action: 'ice'`
(`lib/data/repositories/supabase_remote_session_repository.dart:152-159`),
`IceConfig.fromJson` maps `ice_servers`/`turn_configured`/`expires_at`
(`lib/data/models/remote_session.dart:236-256`), and the peer is created with
only those servers (`lib/features/remote_assistance/remote_session_controller.dart:568-572`).
No TURN secret, no `--dart-define`, no persisted ICE data exists in `lib/`
(**CODE-VERIFIED**). The response is held in memory for the life of the screen
(`remote_session_controller.dart:67`, `:308-321`, `:516-520`) and is **not**
refreshed at `expires_at`; a banner explains the STUN-only state
(`remote_session_controller.dart:131-141`).

---

## 3. TTL defect (present in code, fix needs authorization)

Session lifetime is 1800 s but the default relay credential lifetime is 600 s.
TURN allocations are kept alive by periodic Refresh requests, and coturn
re-validates the REST username timestamp on each authenticated request; once
the timestamp is in the past those refreshes are rejected and the allocation
expires (expected coturn REST behaviour; **NOT TESTED** here). A TURN-only call
therefore can lose its relay roughly 10-20 minutes into a 30-minute session,
even without any renegotiation. The client also caches the config and has no ICE
restart (`docs/remote-assistance.md`, G7), so it cannot recover by refetching.

Guidance:

- Set `TURN_TTL_SECONDS=3600` (2x the 1800 s session, still inside the
  60..86400 clamp).
- Do **not** change `DEFAULT_TTL_SECONDS` in `turn.ts:26` without
  authorization: it changes behaviour for every deployment that omits the
  variable, and the existing test `turn_test.ts:134-139` asserts 600.
- Rotating `TURN_SECRET` does not revoke already issued credentials; lower the
  TTL first for a hard cutoff.

---

## 4. Environment variable contract

All four live in **Supabase Edge Function secrets** (Dashboard → Project
Settings → Edge Functions → Secrets, or `supabase secrets set --env-file
<gitignored file>`). They are read only by `remote-session` →
`_shared/turn.ts`. Nothing belongs in Flutter, `--dart-define`, `assets/`, a
committed `.env` or CI logs. `.env.example:11-15` lists placeholders only.

| Name | Required for `turn_configured: true` | Secret? | Purpose | Placeholder example |
|---|---|---|---|---|
| `TURN_URL` | yes | No (a public hostname/port) | Comma/space-separated `turn:`/`turns:` URLs matching the coturn listeners | `turn:turn.example.com:3478?transport=udp,turns:turn.example.com:5349?transport=tcp` |
| `TURN_SECRET` | yes | **Yes** | coturn `static-auth-secret`; HMAC key for ephemeral credentials | `replace-with-32-plus-random-bytes` |
| `TURN_TTL_SECONDS` | no (default 600) | No | Credential lifetime, clamped 60..86400 | `3600` |
| `STUN_URL` | no | No | Override the default `stun:stun.l.google.com:19302` | `stun:stun.example.com:3478` |

Format rules that cause silent `false`:

- `TURN_URL` must start with `turn:` or `turns:` per entry; `http://`, a bare
  `host:port`, or `stun:` entries are filtered out (`turn.ts:84`).
- A `turns:` URL needs coturn TLS listening (normally 5349) and a valid
  certificate for that hostname.
- `TURN_SECRET` must be byte-identical to coturn's `static-auth-secret`; coturn
  trims nothing, the function trims surrounding whitespace (`turn.ts:85`).
- Secrets are write-only in the Dashboard: presence and update time are
  readable, values are not. Never attempt to display them.

---

## 5. Minimal coturn reference configuration

Placeholders only (`turn.example.com`, TEST-NET addresses). Choose **one**
transport story:

- UDP + TCP 3478 (`turn:`) — simplest; works through most NATs, fails where UDP
  is blocked.
- TLS 5349 (`turns:`) — needed for UDP-blocking networks. This is the mode to
  prefer for TURN-only tests.

```conf
# /etc/turnserver.conf  (minimal reference; every value is a placeholder)
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=<PASTE_TURN_SECRET_VALUE_FROM_SECRET_STORE>
realm=turn.example.com
# 1:1 NAT / cloud VM: public address first, private address second
external-ip=203.0.113.10/10.0.0.10
min-port=49152
max-port=65535
# abuse limits, not required but recommended
total-quota=100
user-quota=12
no-cli
no-loopback-peers
no-multicast-peers
# only with turns: (install a valid certificate first)
# cert=/etc/letsencrypt/live/turn.example.com/fullchain.pem
# pkey=/etc/letsencrypt/live/turn.example.com/privkey.pem
```

Notes:

- `static-auth-secret` must equal the Edge secret `TURN_SECRET`; the *name*
  `TURN_SECRET` is the function's env key, `static-auth-secret` is coturn's
  config key — do not create a `STATIC_AUTH_SECRET` env var, the function ignores
  it.
- `realm` must be non-empty but does not need to match the credential scheme.
- Relay range `49152-65535/udp` is the conventional range; open it inbound in
  the firewall/security group, plus 3478/udp, 3478/tcp and (for TLS) 5349/tcp.
  Restrict the relay range to a smaller block if the provider caps rules; then
  update `min-port`/`max-port`, not the client.
- Behind 1:1 NAT set `external-ip`; behind a load balancer or container, keep a
  single UDP flow sticky or the allocation breaks.
- Do not expose the coturn CLI; do not run an open relay (auth is mandatory).
- `turnutils_peer`/`turnutils_uclient` flags vary by coturn version; check `-h`.

---

## 6. Verification procedure

### (a) Endpoint contract check (no credentials printed)

Requires a QA session in `accepted` (or `active`) state with consent recorded and
unexpired. Read the bearer token from an environment variable; never echo it.

```bash
curl -sS -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/remote-session" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  --data '{"action":"ice","session_id":"<SESSION_ID>"}' \
| jq '{ok,
       turn_configured: .data.turn_configured,
       urls: [.data.ice_servers[].urls],
       has_turn_creds: ([.data.ice_servers[] | has("username") and has("credential")] | any),
       expires_at: .data.expires_at,
       warning: .data.warning}'
```

Pass criteria: `turn_configured: true`; `urls` contains a `turn:` or `turns:`
entry; `has_turn_creds: true`; `warning` null; `expires_at` about
`now + TURN_TTL_SECONDS`. Do not print `username`/`credential` into logs,
screenshots or reports; they are live relay credentials until they expire.
Also confirm the response contains no substring of the shared secret
(`turn_test.ts:88-91` covers this locally). `403 forbidden`/`409`/`410` mean the
session state, not TURN, is the blocker.

### (b) On-device relay candidate check

1. Join on both devices; keep the session foregrounded.
2. Read the stored ICE candidates (public signaling rows, no secrets):

```sql
select from_user_id, payload->>'candidate' as candidate
from public.webrtc_signals
where session_id = '<SESSION_ID>' and kind = 'ice'
order by sequence;
```

Pass criteria: at least one candidate containing `typ relay` per side, with
`relay` in the candidate's related address section.

3. Selected pair: the client exposes `getMediaStats()`
   (`remote_session_controller.dart:850-870`), which returns `candidate-pair`
   reports (with `selected`, `localCandidateId`, `remoteCandidateId`) but **not**
   the `local-candidate`/`remote-candidate` reports needed to resolve those IDs
   to `candidateType`. So "the selected pair is relay" cannot be proven from the
   current stats map alone; use the candidate list plus the blocked-network
   condition in (c) instead. Adding candidate reports is a client change, not
   part of this audit.

### (c) TURN-only test (proves relay use)

1. Put both phones on a test Wi-Fi with AP/client isolation.
2. Block outbound UDP entirely, then allow only TCP 443 to the TURN host if the
   provider fronts TLS there; if coturn listens on 5349 directly, allow TCP
   5349. Keep `turns:` in `TURN_URL` for this run.
3. Join child-first, then repeat parent-first.
4. Pass requires: `typ relay` candidates on both sides, both screens
   **Connected**, audible two-way audio (video if requested), no **Relay not
   configured** banner, and coturn logs showing allocations from both peers.
   Because UDP and direct paths are blocked, a connected call is necessarily
   relayed.
5. Negative control once: TURN configured but the TURN port blocked → the call
   must fail with the **Media connection** warning, not silently report
   **Connected**.

Current status: **BLOCKED** — no TURN server, one physical device, so this has
never been executed (`docs/two-device-webrtc-test-plan.md:3-18`, T14 at `:405`).

### (d) Audio across the credential-TTL boundary

1. With `TURN_TTL_SECONDS=3600`, run a TURN-only call for 25-30 minutes and
   confirm audio never drops and no **Media connection** warning appears.
2. Confirm `expires_at` on the originally issued config has passed while audio
   still flows; the client does not refetch, so this tests allocation refresh,
   not re-authentication.
3. To demonstrate the 600 s defect (requires authorization to change the
   hosted secret), set `TURN_TTL_SECONDS=60`, start a TURN-only call and observe
   whether relayed audio dies after the allocation's refresh interval. Record
   timestamps; expected outcome is relay loss inside the 30-minute session.
4. A fresh join after expiry must fetch new credentials; reusing a cached
   config across sessions is not supported by design (a new screen refetches).

All of (b)-(d) are **NOT TESTED** today.

---

## 7. Privacy and security rules

- The only place `TURN_SECRET` may exist: coturn's configuration/secret store
  and the Supabase Edge Function secret store. Nowhere else.
- Never in Flutter/Dart, `--dart-define`, `lib/`, `assets/`, the APK, test
  fixtures, committed `.env` files (`.gitignore:1-6` already covers `.env*`,
  `secrets.env`), screenshots, tickets or this document. No value is reproduced
  here.
- Never print secret values; never pass them as CLI arguments (shell history and
  process listings). Use a gitignored env file or the Dashboard.
- The `ice` action is the only issuer; keep JWT verification on
  (`supabase/config.toml:76-77`), keep the participant/consent/expiry gates, and
  do not weaken them to "make TURN easier".
- Do not run a public/open relay: `use-auth-secret` is mandatory, and quotas
  should be set. Unauthenticated TURN is an abuse vector.
- Ephemeral credentials are still credentials: they are scoped to one user and
  expire, but do not paste them into reports; redact `username`/`credential`
  from any captured response.
- Do not disable TLS verification, and do not bypass certificate validation to
  "get turns: working".

---

## 8. What needs authorization, and read-only owner checks

Nothing below is performed by this audit. Each item changes hosted state and
needs the project owner's explicit approval:

1. Creating/updating the four secrets (Dashboard or CLI) — a config change.
2. Redeploying `remote-session` — a deployment. (Secret-only changes normally
   take effect for new invocations, but a redeploy is the deterministic way to
   rule out staleness.)
3. Provisioning coturn (VM, DNS, TLS certificate, firewall/security-group
   changes, quota tuning) — infrastructure and cost.
4. Any client-side change (TTL-aware ICE refetch, stats candidate reports, ICE
   restart) — code and release.

Read-only checks an owner can do today, in order:

1. **Secrets presence:** Dashboard → Project Settings → Edge Functions →
   Secrets. Confirm rows named `TURN_URL`, `TURN_SECRET` (and optionally
   `STUN_URL`, `TURN_TTL_SECONDS`). Note only presence and "updated" time —
   never reveal or copy a value. Absent rows confirm Hypothesis 1.
2. **Deployed build:** Dashboard → Edge Functions → `remote-session`. Record the
   deployed version/time and compare with the secret update time. If the build
   predates the secrets, suspect a stale deployment.
3. **Deployed code:** open the function's code view read-only and confirm it
   contains `TURN is not configured` (the `turn.ts` warning). Do not edit or
   save anything in that editor.
4. **Logs:** Dashboard → Edge Functions → Logs for `remote-session`; look for
   `ice` invocations and any `500`/`internal_error` around the test window.
   Function logs do not contain the secret.
5. **Session state:** Table Editor → `remote_sessions`; confirm the QA session is
   `accepted`/`active`, `consent_recorded = true`, `expires_at` in the future.
   Without that, `ice` returns `403`/`409`/`410` regardless of TURN.
6. **Endpoint behaviour:** with the owner's consent, run §6(a) and record only
   the boolean/URL/warning fields.
7. **Relay provider side:** coturn logs for `Allocate`/`Refresh` and
   `401`/`438` authentication failures; firewall counters for 3478/5349 and the
   relay range.

Do not click "Reveal", rotate, delete or edit any secret to answer these
questions.

---

## 9. Android 31-37 notes for background audio / notifications

Context: `minSdk 24`, `targetSdk 36`, `compileSdk 36` (recorded binary evidence,
`.tools/evidence/full-qa/phase6b-recording-20261027/agent6-binary-audit.md:26`;
manifest `android/app/build.gradle.kts:9-23`). The child service is
`AudioAssistanceService` (`android:foregroundServiceType="microphone"`,
`AndroidManifest.xml:86-89`) with `FOREGROUND_SERVICE_MICROPHONE` declared
(`:15`); it is started only after the peer exists, from the foreground session
screen (`remote_session_controller.dart:657-663`). Everything in this section is
platform-behaviour analysis, not a device result unless stated.

| API / Android | Behaviour that matters here | Status |
|---|---|---|
| 31 / 12 | No `POST_NOTIFICATIONS` runtime permission exists; the FGS notification appears without a prompt. Background FGS starts are restricted, so the service must be started while the app is visible (it is). Mic/camera privacy indicators and the system mic toggle apply. | **NOT TESTED** (realme is API 31 but the audio FGS flow has not been exercised) |
| 32 / 12L | Same as 31 for this path. | **NOT TESTED** |
| 33 / 13 | `POST_NOTIFICATIONS` becomes a runtime permission. The app declares it (`AndroidManifest.xml:11`) but the join path requests only camera/microphone (`remote_session_controller.dart:737-747`), so the FGS notification may be suppressed even though the service runs. A suppressed notification is not a stopped service, but it removes the visible stop affordance. | **CODE-VERIFIED** gap; runtime **NOT TESTED** |
| 34 / 14 | Microphone FGS needs both the `FOREGROUND_SERVICE_MICROPHONE` permission and the `microphone` type (both present), plus a while-in-use mic grant at start time. Starting a mic FGS from the background throws unless exempt, so keep the start tied to the visible Join action. | **NOT TESTED** |
| 35 / 15 | No change to microphone FGS semantics known to this audit; the 6-hour `dataSync` timeout does not apply to `microphone`. Boot-start restrictions affect the existing guardian `dataSync` service (`docs/device-owner-provisioning.md:631-635`), not the audio service. | **NOT TESTED** |
| 36 / 16 | App targets 36, so current platform FGS/permission behaviour applies unchanged in this code path; no TURN or notification change is expected. Verify FGS start and notification rendering on a real 36 device. | **NOT TESTED** |
| 37 / 17 | Only seen on the emulator parent (`docs/read_only_audit_2026-10-27.md:485`), which does not capture mic. No child-side API 37 test exists. | **NOT TESTED** |

### ColorOS (realme UI) on Android 12

The only physical child phone is a realme RMX2161 on Android 12/API 31
(`docs/read_only_audit_2026-10-27.md:486`). OEM power management can kill the FGS
or revoke a grant even when the AOSP rules are satisfied. Owner/child steps to
try (all **NOT TESTED** in this audit):

- Settings → Apps → Parent Control → Battery → **Allow background activity**,
  and set battery optimisation to **Don't optimise** for the app.
- Settings → Apps → Parent Control → Permissions → Microphone → **Allow only
  while using the app** (not "Ask every time"/one-time). One-time grants are
  dropped when the app leaves the foreground; ColorOS may also offer
  "Remove permissions if app is unused" / auto-revoke — turn it off.
- Lock the app in the recents card ("lock" icon) so ColorOS does not clear it.
- After any OS update or long idle period, re-check the mic grant before a call;
  a revoked grant stops capture even though the service is declared.
- Do not use "Force stop" or a cleaner app: nothing can restart after
  force-stop, by design.

---

## 10. Bottom line

`turn_configured: false` means the running function saw no usable
`TURN_URL`+`TURN_SECRET` pair; that is the whole gate (`turn.ts:84-93`), and it
was last recorded false on 2026-10-26. Relay use has **never** been demonstrated:
there is no relay, no second device, and no TURN-only run. Before any claim of
"TURN working", complete §6(a)-(c) and record the candidate types and coturn
allocations; then raise `TURN_TTL_SECONDS` to 3600 under authorization and
repeat §6(d).
