# Backend audit — microphone-only remote assistance (Supabase)

Date: 2026-10-28
Scope: `supabase/functions/remote-session`, `supabase/functions/_shared` (auth/turn), `supabase/migrations/*.sql`, `supabase/tests/*.sql`.
Method: static read of the working tree only. No edits, no `adb`, no hosted database, no Supabase CLI. Line numbers are from this tree.

**Bottom line: the backend does not implement "microphone-only". Both `audio` and `video` are first-class everywhere (Edge enum, DB check, client), and no server check exists that would reject video or prove that only audio is captured. A session reaching `active` proves consent + authorization of participants, not media.**

---

## 1. Remote-session Edge Function (`supabase/functions/remote-session/index.ts`)

Actions: `request`, `pending_child`, `respond`, `start`, `end`, `ice` (`:94-341`); unknown actions 400 (`:339-340`). No `extend`/renew action exists.

### 1.1 `request`
- Auth: `requireUser(..., { requireVerifiedEmail: true })` (`:96`), `requireRole(auth.profile, "parent")` (`:97`).
- Inputs: `device_id` UUID (`:98`), `kind = readEnum(body.kind, "kind", KINDS)` (`:99`) with `KINDS = ["audio", "video"]` (`:27`).
- Device authority: `requireActiveDeviceForParent` (`:100`).
- Row values are taken from the **device row**, not the request: `family_id: device.family_id`, `child_user_id: device.child_user_id` (`:106-109`), `status: "requested"` (`:111`), `expires_at = now + REQUEST_TTL_MS` (`:113`, `REQUEST_TTL_MS = 10 min` at `:28`), `consent_recorded: false` (`:114`).
- Audit `session_requested` including `{ kind }` (`:121-129`).
- No check for an already-open session, no per-device concurrency limit, no rate limiting (the function imports no `rate_limit.ts`), no `last_seen_at`/online check, and no `microphone_granted` check.

### 1.2 `pending_child`
Child-only (`:135`). Lazily expires stale `requested` rows (`:138-144`), then returns unexpired requests for `child_user_id = auth.uid()` (`:146-153`), max 50.

### 1.3 `respond` (accept/decline)
- Child-only (`:159-160`); `session.child_user_id !== auth.user.id` → 403 (`:164-166`).
- Idempotency: an already `accepted`+accept or `declined`+decline returns the row **before** any expiry check (`:167-168`).
- Only `requested` may be responded to (`:169-175`); expiry checked at `:176-179`, then `markExpired` (`:74-82`).
- Accept patch (`:183-190`): `status: "accepted"`, `accepted_at`, `expires_at = now + CONSENT_TTL_MS` (**30 min**, `:29`, `:187`), `consent_recorded: true`, `session_nonce: crypto.randomUUID()`.
- Decline patch (`:191-196`): `status: "declined"`, `ended_at`, `ended_reason: "declined"`.
- Compare-and-set on `status = "requested"` (`:197-203`) so accept/decline races are resolved by the DB.
- Consent is **a boolean plus `accepted_at`**; there is no consent text/version, no per-kind consent, no client attestation, no IP/device evidence, and no withdrawal path. `session_nonce` is never checked anywhere (only written here and typed at `:49`; DB default none).

### 1.4 `start`
- Child-only (`:226-232`). `if (session.status === "active") return ok(session);` (`:233`) — this early return happens **before** the expiry check, so an `active` row past `expires_at` is reported as live.
- Requires `accepted` **and** `consent_recorded` (`:234-240`), unexpired (`:241-244`), then `accepted → active` with `started_at` (`:246-253`).

### 1.5 `end`
- Any participant (`assertParticipant`, `:271`, `:68-72`); terminal statuses return the row unchanged (`:279-281`).
- Writes `status: "ended"`, `ended_at`, `ended_by`, and `ended_reason: reason ?? null` where `reason` is **free text from the client** (`:273-276`, `:283-291`, max 200). A client can therefore write any reason, and omitting it stores `null`. G9 in `docs/remote-assistance.md` already notes clients sending `expired` here.
- Only `requested|accepted|active` can transition to `ended` (`:293`).

### 1.6 `ice`
- Participant (`:315`), status `accepted|active` (`:316-322`), `consent_recorded` (`:323-329`), unexpired (`:330-333`), then `buildIceConfig(readTurnEnv(), auth.user.id)` (`:335`).
- Does **not** re-check device status, child membership, or session `kind`.
- TURN username is `"<unix-expiry>:<userId>"` and TTL is clamped 60–86400 s, default **600 s** (`_shared/turn.ts:95-99`, `:23-25`): credentials are bound to the user, **not the session**, so they stay valid after a session ends or is revoked.

### 1.7 `kind` validation / audio-vs-video mismatch
- The only validation is enum membership (`_shared/validation.ts:179-192`). `video` is accepted by the server and by the DB (`20260101000000_core.sql:331`).
- There is **no negotiation or capability exchange**. The server never reads `devices.camera_granted` / `devices.microphone_granted` (`core.sql:106-107`), never asks the child what it supports, and never rejects an audio request on a video-only peer (or vice versa). The child simply accepts `kind` as stored; what happens next is client behaviour (the client's capture constraint is derived from `kind` at `lib/features/remote_assistance/remote_session_controller.dart:498-506`).
- Consequence: "parent requested audio" is metadata. A modified client is free to negotiate/send video inside an `audio` session; the backend stores and relays the SDP without inspecting m-lines.

---

## 2. `remote_sessions` schema (`supabase/migrations/20260101000000_core.sql:321-353`)

| Column | Line | Notes |
|---|---|---|
| `family_id`, `device_id`, `parent_user_id`, `child_user_id` | `:323-330` | FKs only; no constraint tying `child_user_id` to `devices.child_user_id` or to `family_members` |
| `kind text not null check (kind in ('audio','video'))` | `:331` | **video is legal** |
| `status` default `requested`, check in `requested, accepted, active, declined, ended, expired, failed` | `:332-334` | No trigger/FSM: any status may follow any status at DB level; only the Edge function's `.eq("status", ...)` predicates enforce ordering |
| `requested_at`, `accepted_at`, `started_at`, `ended_at` | `:335-338` | No ordering constraints |
| `expires_at timestamptz not null` | `:339` | **No DB default**; set only by the Edge function (10 min request, then 30 min from accept) |
| `ended_by` | `:340` | Null for expiry/decline/cron |
| `ended_reason text` ≤200 | `:341` | Free text. Internal values used: `expired` (`index.ts:78,140`), `declined` (`:194`), `device_revoked` (`functions.sql:478`), `member_unlinked` (`:392`), plus arbitrary client text (`index.ts:290`) |
| `consent_recorded boolean not null default false` | `:342` | Only consent artifact |
| `session_nonce uuid` | `:343` | Written at accept (`index.ts:189`), **never verified anywhere** |
| `created_at` | `:344` | No `updated_at`, no trigger |

**Audio-specific field: none.** Nothing records mic permission, codec, media direction, mute state, or "audio only" intent beyond `kind`. `devices.microphone_granted` exists (`core.sql:107`) but is never consulted by session code (grep: no hits in `supabase/functions/remote-session` or `family-admin`).

There is no uniqueness constraint for "one live session per device/child", so duplicate/concurrent sessions are possible. Sessions and signals are never deleted (no purge path in `family-admin` `purge_data`, `family-admin/index.ts:157-227`; no `delete from remote_sessions|webrtc_signals` in migrations), so rows and IP-bearing SDP persist indefinitely.

---

## 3. Signalling: `webrtc_signals` + RLS

Table (`core.sql:358-367`): `session_id` FK cascade, `from_user_id` default `auth.uid()` (`:361`), `kind in ('offer','answer','ice')` (`:363`), `payload jsonb` with only a size cap `octet_length(payload::text) <= 16384` (`:364`), `sequence bigint generated always as identity` (`:366`), index `(session_id, sequence)` (`:369-370`). No `updated_at`, no cleanup.

Grants: `grant select, insert on public.webrtc_signals to authenticated` (`20260101000200_rls.sql:284`) — append-only; no update/delete grant, no update/delete policy.

### 3.1 Who can read
`webrtc_signals_select_participant` (`rls.sql:202-215`):
```sql
exists (select 1 from public.remote_sessions s
        where s.id = session_id
          and s.status in ('accepted','active')
          and s.expires_at > now()
          and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid()))
```
Participant check is by **session user columns only** — not family membership. Both directions are readable by both participants (the migration comment at `:197-200` documents this deliberate deviation). After `ended/expired/declined/failed` or past `expires_at`, signals become unreadable even to participants (rows remain stored).

### 3.2 Who can insert
`webrtc_signals_insert_participant` (`rls.sql:217-231`) requires `from_user_id = auth.uid()` **and** the same live-session predicate. Authorship spoofing is blocked (`:222`). No requirement of `consent_recorded` (status accepted/active implies it, given no client write path to status).

### 3.3 Direction/ordering/content
- **No direction check**: either participant may insert `offer`, `answer`, or `ice` at any time, repeatedly; a child may send an offer, a parent may answer, etc. No "one offer per generation", no tie between `kind` and session `kind`.
- **No payload validation**: `kind` is independent of `payload`; 16 KB of arbitrary JSON is accepted. SDP/ICE with host/srflx candidates can carry local and public IP addresses and is stored verbatim.
- **Ordering**: `sequence` is a global identity; clients order replays by it (`lib/data/repositories/supabase_remote_session_repository.dart:299-303`). Realtime delivery order is not guaranteed, and there is no server-side monotonic enforcement per session. No cap on rows per session (a participant can spam inserts).

### 3.4 Can a third party in the same family read another pair's SDP/ICE?
- **Through the table/PostgREST: no.** The SELECT policy is participant-only (`rls.sql:202-215`); `parent_user_id`/`child_user_id` equality excludes another parent or sibling. Cross-family denial is tested (`tests/30_rls.sql:294-295`).
- **Realtime channel: partially.** `private.realtime_topic_allowed` (`rls.sql:321-327`) authorizes `webrtc-signals:<session_id>` for `child_user_id = auth.uid() **or private.is_family_parent(s.family_id)` — i.e. **any parent in the family**, not just the session's parent, may join the channel. Row payloads are still filtered by table RLS for `postgres_changes`, so today they receive no SDP. But the `realtime.messages` policy has **no extension predicate** (`rls.sql:344-359`; tests/50_realtime_policy.sql:10-16), so any `broadcast` sent on that topic would be delivered to that unrelated parent. This is a defence-in-depth gap, not a current table leak.
- `remote_sessions` metadata (device, parent/child display names, timestamps, status, even the unused `session_nonce`) **is** readable by every parent in the family via `remote_sessions_select_participants` (`rls.sql:185-193`, `... or private.is_family_parent(family_id)`).

---

## 4. Authority: cross-family, revoked, unlinked

`requireActiveDeviceForParent` (`_shared/auth.ts:252-275`):
```ts
const device = ... .from("devices").select(...).eq("id", deviceId).maybeSingle();  // :258-264
if (!device) throw device_not_found;                                              // :267-269
await assertFamilyParent(db, userId, device.family_id);                           // :270
if (device.status !== "active") throw device_not_active;                          // :271-273
```
`assertFamilyParent` → `loadFamily` (rejects `families.deleted_at`, `:141-155`) and `loadMembership` requires `status = 'active'` and `role = 'parent'` (`:165-179`, `:194-205`). The Edge function uses the **service-role client** (`getServiceClient`, `:49-65`), so RLS is bypassed and these checks are the only gate.

- **Another family's device:** blocked by `assertFamilyParent` (caller has no active parent membership in `device.family_id`) → 403.
- **Revoked device:** `status = 'revoked'` → 403 `device_not_active`. Unlinked child: `private.unlink_child` revokes devices (`functions.sql:379-385`), so also blocked.
- **Deleted family:** blocked (`auth.ts:151-153`).
- **Any parent in the family (not just owner)** may request for any child's device in that family; that is allowed.
- **Gaps:** `requireActiveDeviceForParent` does **not** check `credential_revoked_at` (compare `requireDevice`, `auth.ts:329-335`, which does), does **not** verify the child still has an active `family_members` row, does **not** check `microphone_granted`, and does **not** check whether an open session already exists. A device row left `active` with a revoked credential (or a child membership removed by any path that does not run `unlink_child`) would still pass.

---

## 5. Revocation / unlink during a live audio session

- `private.unlink_child` (`functions.sql:388-396`) sets every session for that child in `requested|accepted|active` to `ended`, `ended_at`, `ended_by`, `ended_reason = coalesce(ended_reason,'member_unlinked')`. Devices are revoked in the same transaction (`:379-385`).
- `private.revoke_device` (`functions.sql:474-481`) does the same for `device_id`, reason `device_revoked`, and has an early return if already revoked (`:462-465`).
- **New signals:** rejected by the RLS insert predicate, because the row is no longer `accepted|active` (`rls.sql:226-230`). Not tested (see §7). A signal insert racing the revoke transaction can still commit (statement-time RLS snapshot); no serialization between end and signal insert.
- **Old signals:** become unreadable to participants via the SELECT predicate (`rls.sql:210-213`) but are not deleted. Service role, backups and the DB retain the SDP/IP data.
- **Media:** the DB can only end the row. The audio is peer-to-peer WebRTC; nothing server-side stops the RTP flow. Enforcement is the client reacting to the Realtime `ended` update or polling (`docs/remote-assistance.md:20-22`). A backgrounded/offline/modified client can keep the call up.
- **TURN:** credentials minted before revocation remain valid until their TTL (default 600 s) because they are user-scoped, not session-scoped (`_shared/turn.ts:95-99`). A revoked session can keep relaying for up to the TTL.
- **Realtime topic:** `realtime_topic_allowed` ignores `status`/`expires_at` (`rls.sql:321-327`), so the topic stays joinable after end/revoke; table RLS prevents row delivery.
- **Metadata access:** the select policy keeps `parent_user_id = auth.uid() or child_user_id = auth.uid()` (`rls.sql:190-191`) with no membership requirement, so an unlinked child retains read access to their own historical session rows.

---

## 6. Realtime / private channel authorization

`private.realtime_topic_allowed` (`rls.sql:295-332`):
- Topic must be `<kind>:<uuid>[:...]`; only segments 1–2 are parsed (`:310-315`), so the client's trailing `:<microseconds>` suffix is ignored.
- `safety-alerts`, `remote-session-family` → any active family member (`:317-319`).
- `remote-session`, `webrtc-signals` → `s.child_user_id = auth.uid() or private.is_family_parent(s.family_id)` (`:321-327`). **No status, expiry, or consent check.**
- Anything else false (`:330`).
- Enforced at channel join via `parentcontrol_private_topics` on `realtime.messages` (`:344-359`), created only if the realtime schema exists.
- Child: only sessions where they are `child_user_id`; a sibling is denied (tested, `tests/30_rls.sql:377-384`). Parent: **any** active parent of the session's family, including a parent who is not a party.
- `remote-session-family:<family>` lets any member subscribe; row RLS then limits a child to their own rows.
- The messages policy deliberately has no extension filter (`:338-343` comment), so authorization is topic-only; `broadcast`/`presence` on an authorized topic are not further constrained by the table policies.

---

## 7. Test coverage (SQL + Deno) for audio

What exists:
- Schema: RLS enabled on the table and the two `profiles` FKs (`tests/10_schema.sql:12-13`, `:95-103`). No assertion on `kind`, status, expiry, or ended_reason constraints.
- RLS signals: participant read (`tests/30_rls.sql:73-74`, `:181-182`), authorship spoof rejected (`:184-194`), cross-family read denied (`:294-295`).
- Realtime topics: participant child allowed on session/signal topic (`:367-372`), non-participant child denied (`:382-384`), parent participant allowed and cross-family denied (`:386-393`), unlinked child denied (`:396-402`); policy exists and topic gate works (`tests/50_realtime_policy.sql:17-81`).
- Lifecycle: stale sweep expires (`tests/40_functions.sql:169-174`); unlink ends an **audio** session (`:276-325`); device revoke ends a **video** session (`:387-436`).
- Fixtures: session1 is `video`/`accepted` (`tests/20_fixtures.sql:186-192`); session2 is `audio`/`active` but already expired (`:193-199`); the single signal is an offer (`:201-207`).

Not covered (audio-relevant):
- **No Deno test at all for `remote-session`** — there is no `index_test.ts`; only `_shared/*_test.ts` exist. Request/respond/start/end/ice authorization, consent, expiry, duplicate sessions and audio-vs-video are untested at this layer.
- No test that `kind='video'` should be rejected (because it is not rejected).
- No test of signal insert for a `requested`, `declined`, `ended`, `expired`, or expired-`accepted` session.
- No test that a **non-participant parent of the same family** cannot read signals (predicate blocks it, but unasserted), nor that such a parent is allowed to join the signal realtime topic.
- No test of signal direction/kind (child offer, parent answer), sequence ordering/replay, payload size cap, update/delete denial, or `from_user_id` default.
- No audio-specific media test; a "Connected" state is never asserted anywhere server-side.
- No test of the `start` idempotency bypass of expiry (`index.ts:233`).

---

## 8. What "Connected" proves server-side — and what it does not

A session showing **Connected/Live** means, at most:
1. A parent with active parent membership in the device's family requested it and the device was `active` (`auth.ts:270-273`).
2. The child account explicitly accepted (row became `accepted`, `consent_recorded = true`, `accepted_at` set, 30 min window opened) (`index.ts:183-190`).
3. The child called `start` and the row became `active` with `started_at` (`index.ts:246-253`), i.e. the client asserted it connected; the server does **not** verify the peer connection.
4. At `start`/`ice` time the row was unexpired and (for ICE) consented (`index.ts:241-244`, `:316-333`); an audit event exists (`session_started`, `:259-266`).

It does **not** prove: that the microphone permission was granted or that the mic is capturing; that any audio (RTP) is flowing in either direction; the codec/bitrate; that the session is audio-only (a client can send video; the server never inspects SDP m-lines); that the human on the other end is who the UI says; that nothing is being recorded locally; that ICE used the relay; that the peer actually connected (the child client asserts it); or that the session is still authorized a minute later (media survives DB expiry/revocation). `connected` is a **client-reported signalling milestone**, not media evidence.

---

## Findings (ranked)

| # | Sev | Finding | Evidence |
|---|---|---|---|
| F1 | High (scope) | "Microphone-only" is not enforced. `video` is accepted by the Edge enum and the DB check; no capability/negotiation check exists; SDP m-lines are never inspected. | `remote-session/index.ts:27,99`; `core.sql:331`; no `microphone_granted` use; client capture constraint `lib/.../remote_session_controller.dart:498-506` |
| F2 | Medium | Any parent in the family can join the `webrtc-signals:<session>` private topic (not only the pair); safe today only because `postgres_changes` applies table RLS, while the `realtime.messages` policy has no extension filter, so a future `broadcast` would leak SDP to an unrelated parent. | `rls.sql:321-327`, `:344-359`; tests never assert a non-participant parent on the signal topic |
| F3 | Medium | Revocation/end is row-level only: existing P2P audio continues; TURN credentials are user-bound and valid to TTL (600 s default) after end/revoke. | `functions.sql:388-396,474-481`; `turn.ts:95-99` |
| F4 | Medium | SDP/ICE payloads (IP addresses) are stored indefinitely with no schema validation, no per-session cap, and no retention/purge; only participants can read them while live, but service role/backups keep them forever. | `core.sql:358-367`; no delete path; `family-admin/index.ts:157-227` |
| F5 | Medium | Request path has no rate limit, no duplicate/one-live-session constraint, no online/`last_seen` check, no microphone-capability check, and does not check `credential_revoked_at` (unlike device auth). | `remote-session/index.ts:95-131`; `auth.ts:252-275` vs `:329-335` |
| F6 | Low | Idempotent early returns bypass expiry: `start` on an `active` row and `respond` on `accepted`/`declined` return without checking `expires_at`. | `index.ts:167-168,233` |
| F7 | Low | `session_nonce` is minted but never verified/bound to signals; dead field. | `core.sql:343`; `index.ts:189`; no other reference |
| F8 | Low | `ended_reason` is client-controlled free text and can be overwritten; no enum/FSM at DB level, so audit reasons are not trustworthy. | `core.sql:332-334,341`; `index.ts:273-276,290` |
| F9 | Info | Consent is a single boolean with no text/version/evidence; a modified child client can set it by calling `respond`. | `core.sql:342`; `index.ts:188` |

## Proposal (no code implemented)

1. If the product is mic-only: remove `video` from `KINDS` and from the DB check (or gate it behind an explicit flag), and reject `kind` at request. Add a regression test.
2. Move signal insertion behind an Edge Function (or add a `session kind`/direction check in RLS) that validates `kind` vs direction, rejects SDP containing video m-lines for audio sessions, caps signals per session, and stamps a server-side sequence.
3. Tighten `realtime_topic_allowed` for `webrtc-signals` to `s.parent_user_id = auth.uid() or s.child_user_id = auth.uid()` and require `status in ('accepted','active') and expires_at > now()`; add a test with a non-participant family parent.
4. Bind TURN credentials to the session nonce and shorten TTL; on end/revoke, have clients teardown (server cannot kill P2P), and document that residual relay time is bounded by TTL.
5. Add retention for `webrtc_signals` (and ideally session rows) and/or store only candidates in a reduced form.
6. Add Deno tests for the six `remote-session` actions (authority, consent, expiry, duplicate requests, kind) and SQL tests for signal insert on ended/expired sessions.

---

## Summary (<300 words)

The audio path is authorized but not media-verified, and it is not microphone-only. `remote-session` accepts `kind: "audio" | "video"` (`index.ts:27,99`; `core.sql:331`), never inspects device mic/camera capability, and never negotiates. A parent with active parent membership in the device's family may request for any family device (`auth.ts:252-275`); only the child participant may accept/start (`index.ts:158-166,225-232`); either participant may end/ICE. Consent is one boolean plus `accepted_at`; `session_nonce` is unused. Requests expire in 10 min, accept opens a 30-min window from accept time, never extended.

`webrtc_signals` is participant-only for SELECT/INSERT while `accepted|active` and unexpired, with `from_user_id = auth.uid()` (`rls.sql:202-231`). SDP/ICE payloads (up to 16 KB, unvalidated) can carry IP addresses and are stored indefinitely. Another parent in the same family cannot read them via the table, but **can join the `webrtc-signals` realtime topic** (`rls.sql:321-327`) because the gate is `is_family_parent`, and the `realtime.messages` policy has no extension filter — safe today only because `postgres_changes` applies table RLS.

Revocation is correct at the row level: unlink and device revoke set sessions to `ended` (`functions.sql:388-396,474-481`), RLS rejects new signals, and old signals become unreadable. It does not stop P2P audio or invalidate TURN credentials (user-bound, 10 min default). The cron sweep is not enabled per docs.

Tests cover participant signal read, authorship spoofing, cross-family denial, topic gates, sweep and unlink/revoke session ending. They do not cover the `remote-session` Edge Function at all (no Deno test), audio-vs-video, signal insertion on ended/expired sessions, or a non-participant family parent on the signal topic.

"Connected" proves a consented, authorized row reached `active`; it proves nothing about the microphone, audio flow, or that media is audio-only.
