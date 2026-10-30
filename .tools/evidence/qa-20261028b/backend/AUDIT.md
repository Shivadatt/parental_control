# Backend static security audit — parent-control app

Date: 2026-10-28
Scope: `D:\parentcontrol_app` Supabase backend (`supabase/migrations`, `supabase/functions`, `supabase/config.toml`, `supabase/tests`), read-only.
Baseline: git `b3f1e20` plus the current working tree (staged/unstaged changes, including migrations 004/005/006 and tests 45/50/55). Backend line references below are the working-tree contents, which is what would ship.
Method: static source and SQL reading only. No edits, no adb, no Supabase CLI, no hosted DB queries and no test execution. Hosted-only behaviour (JWT signing settings, Realtime server policy evaluation, Storage service) is therefore unverified by construction.

## Verdict summary

| # | Claim | Verdict |
|---|-------|---------|
| 1 | Parent/child roles are server-derived, never client-asserted | PASS |
| 2 | Family RLS isolation on all family-scoped tables | PASS |
| 3 | Device identity: credential binding, uniqueness, re-registration, revocation | FAIL (P2) |
| 4 | Pairing approval + replay protection + atomic invite | PASS |
| 5 | Policy/command authorization and expiry | PASS |
| 6 | Recording access authorization | NOT IMPLEMENTED |
| 7 | Private Storage access / nothing public | PASS (no buckets exist) |
| 8 | Realtime subscription isolation | PASS (hosted semantics unverified) |
| 9 | Revocation / stale token rejection after unlink | PASS |
| 10 | Remote-assistance session authorization | PASS |

No P0/P1 findings. One P2 and six P3 observations are listed at the end.

## Per-claim evidence

### 1. Server-derived roles — PASS

- `profiles.role` is constrained to `unset|parent|child` (`supabase/migrations/20260101000000_core.sql:17-21`) and is written only through the service-role client after `db.auth.getUser(token)` (`supabase/functions/_shared/auth.ts:80-126`, `supabase/functions/auth-bootstrap/index.ts:37-75`). `requireRole` reads `profiles.role`, never JWT user metadata (`auth.ts:129-140`). Role changes after first set are rejected (`auth-bootstrap/index.ts:44-50`).
- Authenticated callers cannot write the column: only `grant update (display_name)` (`20260101000200_rls.sql:33-39`, grant at `:251`) and `10_schema.sql:201-202` asserts the role grant is absent. A trigger also blocks role mutation (`core.sql:491-516`).
- Residual: the trigger's `old.role = 'unset'` escape (`core.sql:500-507`) is dormant because column grants already block it (see P3-1).
- SQL suite: grant/trigger preconditions exercised; HTTP/JWT derivation is not testable in the SQL harness and has no Deno unit test.

### 2. Family RLS isolation — PASS

- RLS is enabled on all 18 public tables (`20260101000200_rls.sql:1-22`, asserted by `10_schema.sql:12-48`). Every family-scoped table has a select policy keyed on `private.is_family_member`/`is_family_parent` (profiles, families, family_members, devices, pairing_requests, device_policies, device_commands, usage_daily, location_events, device_apps, safe_zones, safety_alerts, audit_logs, remote_sessions, webrtc_signals). Service-only tables (`device_pairing_tokens`, `safe_zone_states`, `pairing_attempts`, `child_contact_ids`) have RLS enabled and zero policies (`rls.sql:74`, `:168`, `:242`; `20260101000500_child_contact_ids.sql:18-40`).
- Writes are policy-scoped (safe zones parent-only at `rls.sql:149-166`; families owner-only at `:49-56`; webrtc signals authorship at `:217-232`). Anon is fully revoked (`rls.sql:247-248`).
- SQL suite: `30_rls.sql:30-212` exercises cross-family reads/writes as parent1/parent3/child1/child3 on every family table, plus anon denial at `:312-331`. This claim is genuinely exercised, not assumed.

### 3. Device identity/registration — FAIL (P2)

What works:
- Registration requires a verified child JWT + active membership (`supabase/functions/device-register/index.ts:113-140`); uniqueness is `(family_id, installation_id)` plus a partial unique index for one active device per child (`core.sql:79-119`, asserted by `10_schema.sql:133-159`). `secret_hash` and `installation_id` are not readable by clients (`rls.sql:68-73`, `10_schema.sql:185-190`).
- Revocation is a soft delete: status `revoked`, `secret_hash = null`, `credential_revoked_at` set (`20260101000100_functions.sql:432-507`, `20260101000400_device_recovery.sql:15-70`), and re-enrolment after revocation requires a parent approval newer than the revocation (`device-register/index.ts:50-100`, `:175`, `:212`).
- Device requests authenticate on `x-device-id` + `x-device-secret` with constant-time SHA-256 comparison and reject revoked/credential-cleared rows (`_shared/auth.ts:281-337`).

Gap: an existing **active** row is re-credentialed from the child JWT alone — `device-register/index.ts:166-183` updates `secret_hash`, clears `credential_revoked_at` and sets `status = active` without requiring the current `x-device-secret`. Only the revoked branch calls `assertReenrollmentAllowed`. This weakens the possession binding on rotation (P2-1).

SQL suite: schema/uniqueness/column grants and revoked-device policy rejection are tested (`10_schema.sql:133-190`, `40_functions.sql:126-138`, `45_device_recovery.sql`); the HTTP registration/rotation path is not tested.

### 4. Pairing approval, expiry, single use, atomicity — PASS

- Invite tokens are minted server-side with 24 h expiry (`supabase/functions/pairing/index.ts:43`, `:276-380`; `20260101000600_atomic_pairing_invite.sql:60-84`), stored as `purpose = 'invite'` (`20260101000500_child_contact_ids.sql`), and are single-use: `pairing_requests.token_id` is unique and approval sets token `redeemed` (`20260101000100_functions.sql: private.respond_pairing_request`).
- Child consent is mandatory: redemption only creates `pending_child`; approval is a child-owned SECURITY DEFINER RPC that checks ownership, request status, expiry, token activity, parent activity and one-active-family (`functions.sql:189-320`; wrapper `:735-745`). Deno calls it with the child JWT (`pairing/index.ts:812-827`).
- Atomicity: `create_pairing_invite`/`create_pairing_request` take `pg_advisory_xact_lock(hashtextextended(child:family:parent))`, re-check for a live request, and map token unique violations to `code_unavailable` (`20260101000600_atomic_pairing_invite.sql:25-158`). Public wrappers are service-role only (`:161-214`).
- SQL suite: consent/approve/idempotency/replay/expiry/reject at `40_functions.sql:191-262`; invite dedupe, expired-row non-blocking, token replay and lock logic at `55_pairing_invite_atomic.sql`. The genuine two-session lock proof is `supabase/tests/run_pairing_invite_race.sh` (present, not executed here).
- Residual defence-in-depth gap: the 006 RPC bodies do not validate parent/child/family roles internally (P3-2). The invite token itself is not exposed to the parent client.

### 5. Policy/command authorization and expiry — PASS

- Command creation requires a verified parent JWT and an active device in the caller's family (`_shared/auth.ts:252-275`, `device-command/index.ts` create branch); payloads are strictly validated (`_shared/policy.ts`), TTL is clamped to 60–900 s, and idempotency is enforced by a unique key.
- Policy writes go through the service-only `apply_policy_version`, which row-locks the device, rejects non-active devices, bumps the version and queues the matching command atomically (`functions.sql:86-183`). Authenticated callers cannot execute it (`40_functions.sql:462-484`).
- Device ack loads the command filtered by `device_id = device.id`, so a device cannot ack another device's command; expired commands become `expired` and return 410 (`device-command/index.ts:242-305`). Commands are only handed out by `poll_device_commands` for the authenticated device (`functions.sql`).
- SQL suite: versioning/idempotency/expiry/redelivery (`40_functions.sql:62-160`), revoked/unknown device policy rejection (`:126-138`). Ack ownership and expiry are code-only (HTTP layer, not exercised in SQL).

### 6. Recording access — NOT IMPLEMENTED

No recording table, column, bucket, RPC or Edge Function exists (`grep -ri recording supabase/migrations supabase/functions` returns nothing). `docs/screen-recording-plan.md` is a plan only. Access control is therefore not applicable yet; when added it needs a table with family/participant RLS and a private bucket, not a public one.

### 7. Private Storage — PASS (no buckets)

`supabase/config.toml` enables the local Storage service but no buckets are declared, and no code calls the Storage API or references `storage.objects` (`grep -r storage supabase/functions supabase/migrations` returns nothing). Consequently nothing is public and there are no bucket policies to audit. This claim is not testable in the current suite because the feature does not exist; adding media upload without a private bucket + owner/family policies would create a P1.

### 8. Realtime isolation — PASS (hosted caveat)

- The app subscribes only to `private: true` channels for `safety-alerts:`, `remote-session:` and `webrtc-signals:` (`lib/data/repositories/supabase_alert_repository.dart:70-72`, `supabase_remote_session_repository.dart:227-229`, `:326-328`).
- Channel join is gated by `private.realtime_topic_allowed`, which parses `kind:uuid[:suffix]`, requires family membership for `safety-alerts`/`remote-session-family`, and participant status for session topics (`rls.sql:295-335`). Execute is granted only to `authenticated` (`:334-336`), so anon cannot even evaluate it; `realtime.messages` gets a SELECT policy only when that schema exists (`:342-357`). Row delivery for `postgres_changes` remains subject to each table's RLS.
- SQL suite: topic allow/deny for members, foreigners, unlinked child, malformed topics and anon is exercised (`30_rls.sql:350-412`, `50_realtime_policy.sql`). The actual hosted `realtime.messages` policy and public-vs-private channel semantics cannot be verified statically; treat that slice as NOT TESTED.
- Residual: the session-topic predicate does not check session status/expiry (P3-5). Today the app only uses `postgres_changes`, so no broadcast payload leaks; adding broadcast later would leak to past participants.

### 9. Revocation / stale token rejection — PASS

- `unlink_child` removes membership, revokes all child devices (secret null, `credential_revoked_at` set), ends sessions and revokes outstanding pairing tokens/requests atomically (`functions.sql:325-428`; exercised in `40_functions.sql:265-340`).
- Device credentials stop working because `requireDevice` rejects status ≠ active or non-null `credential_revoked_at` before any handler runs (`_shared/auth.ts:329-337`); `secret_hash` is null so the digest comparison fails first. Parent-side data access after the child is unlinked is intentionally retained: the parent remains a family member and owns the family record. The removed child is denied family/profile reads (`30_rls.sql:258-265`).
- SQL suite asserts the revocation state and child denial; Edge Function rejection is code-only (not exercised end-to-end). Note `30_rls.sql:266-267` intentionally allows the unlinked child to still read its own (revoked) device metadata row — low impact, see P3-6.
- Device recovery (`request_device_recovery`) is parent-only, family-scoped, revokes the lost credential and forces a fresh pairing (`20260101000400_device_recovery.sql:15-90`, tested in `45_device_recovery.sql`).

### 10. Remote-assistance authorization — PASS

- A parent can request only for an active device in their own family (`remote-session/index.ts:95-130`), with email verification. The child must explicitly accept; acceptance records consent and sets a 30-minute expiry (`:158-210`). Start is child-only, requires `accepted` + `consent_recorded` + unexpired, and is idempotent for an already-active session (`:225-260`). ICE config requires participation, consent and an unexpired session (`:311-340`). Ending is participant-only (`:270-309`).
- Signalling rows are protected by RLS: participants may read their session's signals, but inserts must be self-authored and for a live session (`rls.sql:185-232`); spoofed authorship is rejected in `30_rls.sql` (`webrtc` assertions). Topic joins are participant-gated (`:321-328`).
- Replay: accept/start are guarded by status + conditional updates; a finished/declined session cannot be restarted. `session_nonce` is generated at accept (`:189`) but never validated (P3-4), so it provides no replay binding today.
- SQL suite covers participant isolation, session sweep expiry (`40_functions.sql:169-173`) and topic gates; the consent/start/ICE HTTP flow has no automated test.

## SQL-test coverage map

| Claim | Exercised in SQL suite | Assumed / not covered |
|-------|------------------------|------------------------|
| 1 roles | `10_schema.sql:201-202` (no role grant), `:263-271` (service-only writes) | JWT→profile derivation in Deno |
| 2 family RLS | `30_rls.sql:30-212` every family table; `10_schema.sql:12-48` all tables RLS | — |
| 3 device | `10_schema.sql:133-190`; `40_functions.sql:126-138`; `45_device_recovery.sql` | `device-register` HTTP flow, active re-credentialing |
| 4 pairing | `40_functions.sql:191-262`; `55_pairing_invite_atomic.sql` | lock race only via unexecuted `run_pairing_invite_race.sh` |
| 5 policy/command | `40_functions.sql:62-160`, `:462-484` | ack ownership/expiry HTTP path |
| 6 recording | none (no feature) | whole claim |
| 7 storage | none (no buckets) | whole claim |
| 8 realtime | `30_rls.sql:350-412`; `50_realtime_policy.sql` (local stub) | hosted `realtime.messages` evaluation, public-channel behaviour |
| 9 revocation | `40_functions.sql:265-340`; `30_rls.sql:258-267` | `requireDevice` rejection end-to-end |
| 10 remote session | `30_rls.sql` participant/signal RLS; `40_functions.sql:169-173` sweep | consent/start/ICE/expiry HTTP flow, nonce replay |

## Findings

### P2-1 — Active device credential rotated without proof of the existing secret
`supabase/functions/device-register/index.ts:166-183` (patch built at `:155-161`).
Any holder of the child JWT who knows the installation_id can replace the active device's `secret_hash` and re-activate it; the revoked branch (`:174-176`) is gated by `assertReenrollmentAllowed`, the active branch is not. Exploit needs the child JWT plus the installation_id (not client-readable, so not trivial), but it breaks the possession binding the device model relies on.
Fix: require `x-device-id` + matching `x-device-secret` before rotating an active row (or return 409 `requires_relink` and force parent re-approval).

### P3-1 — Role trigger has an `unset` escape hatch
`supabase/migrations/20260101000000_core.sql:500-507`.
The trigger permits a role change when `old.role = 'unset'` for any caller; today only column grants stop authenticated clients, so a future grant regression becomes role escalation.
Fix: require service context even for `old.role = 'unset'` (auth-bootstrap already writes as service_role).

### P3-2 — 006 pairing RPCs lack internal authorization checks
`supabase/migrations/20260101000600_atomic_pairing_invite.sql:25-58` and `:96-129`.
`create_pairing_invite`/`create_pairing_request` validate parameters but not that the child is a child, the parent is an active parent in that family, or the family is not deleted; safety depends entirely on the Deno caller. The public wrappers are service-role only, so this is defence in depth.
Fix: add the same membership/role/deleted-family assertions used by `respond_pairing_request` inside these SECURITY DEFINER bodies.

### P3-3 — Parent learns the child's account id before consent
`supabase/functions/pairing/index.ts:172` returns `child_user_id` while status is `pending_child`; the `pairing_requests` SELECT policy (`20260101000200_rls.sql:79-86`) also exposes it to the parent.
A guessed Child ID (or invite) reveals the account UUID before the child approves; display names are masked but the identifier is not.
Fix: return/select-serialize `child_user_id` only when `status = 'approved'` (keep it for the child-side response).

### P3-4 — `session_nonce` is generated but never enforced
`supabase/functions/remote-session/index.ts:189` writes a nonce on accept; no `start`/`ice`/signalling path reads it.
The consent flow has no replay binding beyond row status/expiry, and a leaked session id plus a participant JWT is sufficient.
Fix: require `session_nonce` on `start`/`ice` and compare it, or drop the column to avoid a false security signal.

### P3-5 — Session Realtime topic stays joinable after expiry/end
`supabase/migrations/20260101000200_rls.sql:321-328`.
`remote-session:*`/`webrtc-signals:*` gates only participant identity, not `status in ('accepted','active')` or `expires_at > now()`. `postgres_changes` rows are still RLS-filtered, but any future broadcast on these topics would reach lapsed participants.
Fix: add a live-session predicate to the topic check (no RLS weakening).

### P3-6 — Unlinked child can still read its own revoked device row
`supabase/migrations/20260101000200_rls.sql:68-73`, asserted at `supabase/tests/30_rls.sql:266-267`.
The child branch of `devices_select_parent_or_child` keys only on `child_user_id = auth.uid()`, so after unlink it exposes device metadata (not `secret_hash`/`installation_id`).
Fix: require `private.is_family_member(family_id)` in the child branch, or document the metadata exposure as accepted.

### P3-7 — Device-reported enforcement state is trusted as telemetry
`supabase/functions/device-telemetry/index.ts:87-111` accepts `capabilities.enforcement_mode` and permission booleans from the device heartbeat and stores them for parent display.
A tampered child device can report "enforced" while blocking is off; this is a monitoring-integrity issue, not an access-control bypass.
Fix: mark these fields as self-reported in the API/UI (or correlate with command acks) rather than treating them as verified state.

## Limits

- All verdicts are static. No migration was applied, no SQL test or race script was run, and no hosted project was queried; hosted Realtime policy evaluation, JWT expiry settings and Storage configuration remain unverified.
- `supabase/config.toml` sets `verify_jwt = true` for auth-bootstrap, pairing, device-register, device-policy, family-admin and remote-session, and `false` for device-command, device-telemetry and cron, which self-authenticate; that split matches the code paths above.
- No RLS policy, rate limit or credential check was weakened or proposed to be weakened by this audit.
