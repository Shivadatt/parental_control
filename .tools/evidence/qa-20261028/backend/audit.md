# Backend security / authorization audit — read-only

Date: 2026-10-28
Scope: `D:\parentcontrol_app\supabase` (7 migrations, 9 Edge Functions, `_shared/*`, SQL test suite).
Method: static reading of code + migrations + tests, plus *pre-existing* evidence under `.tools/` (local SQL logs, hosted staging logs from 2026-10-27).
No file outside this evidence directory was modified, no adb, no deploy, no migration run against any hosted project. No SQL test suite was re-executed for this audit; local verdicts below are "code + existing local test file" verifications, and **nothing here asserts live/hosted behaviour except where an existing hosted log is cited and labelled HOSTED-EVIDENCE-2026-10-27**.

Legend for verdicts:
- `PASS — LOCAL VERIFIED` — code implements the claim and the local SQL/Deno suite asserts it.
- `PARTIAL` — code implements it, but at least one sub-claim has no test, or the test only covers a neighbouring case.
- `NOT TESTED` — code only, no assertion anywhere.
- `FAIL` — code does not implement the claim.

---

## 1. Auth identity: parent/child comes from `profiles` / `family_members`, never client metadata

| Claim | Code evidence | Test evidence | Verdict | Concrete gap |
|---|---|---|---|---|
| Role is read from `public.profiles` server-side on every call | `supabase/functions/_shared/auth.ts:101-117` (`select id, role, display_name` then enum check); `:129-139` `requireRole` compares `profile.role` | `supabase/tests/30_rls.sql:213-217` (`update profiles set role='parent'` → `42501 permission denied`); `30_rls.sql:100-102` (cannot update another profile) | PASS — LOCAL VERIFIED | — |
| Client-supplied `user_metadata` is never a role source | Only use of metadata: `supabase/migrations/20260101000000_core.sql:467` (`raw_user_meta_data->>'display_name'`, display name only). `grep user_metadata\|app_metadata` over `supabase/` finds nothing else | `supabase/tests/10_schema.sql:200-203` (`authenticated` has no UPDATE privilege on `profiles.role`) | PASS — LOCAL VERIFIED | — |
| Role is set once and immutable afterwards | `supabase/functions/auth-bootstrap/index.ts:44-50` (409 `role_already_set` if a different role is already set); DB backstop `20260101000000_core.sql:491-516` (`profile role is immutable`, except service context); grant is column-scoped: `20260101000200_rls.sql:251` `grant update (display_name)` | `10_schema.sql:200-203`; `30_rls.sql:214` | PASS — LOCAL VERIFIED | A brand-new account may self-select `parent` or `child` at bootstrap (by design, but it means "parent" is not an approved privilege — see §2 ownership note). |
| Family membership, not profile role, gates family data | `private.is_family_parent/is_family_member` in `20260101000000_core.sql:571-606`; used by every RLS policy (`20260101000200_rls.sql:27-108, 185-240`) and by `assertFamilyParent` (`_shared/auth.ts:194-205`) | `30_rls.sql:47-50` (unlinked child reads 0 family profiles), `30_rls.sql:262-265` | PASS — LOCAL VERIFIED | `profiles.role` alone is never sufficient for data: every function that touches family data also calls `assertFamilyParent`/`assertChildMembership`. |

## 2. Family isolation via RLS on the eight named tables

| Table | Policy (code) | Local assertion | Verdict |
|---|---|---|---|
| `profiles` | `20260101000200_rls.sql:27-38` (self or `shares_active_family`; update self only) | `30_rls.sql:47-50, 160-163, 264-265`; `10_schema.sql:196-203` | PASS |
| `family_members` | `rls.sql:59-63` (select only, family members) | `30_rls.sql:42-45, 157-158` | PASS (read) |
| `devices` | `rls.sql:68-72` (family parent or `child_user_id = auth.uid()`); column grants `rls.sql:259-266` hide `secret_hash`/`installation_id` | `30_rls.sql:37-40, 152-155, 266-267, 280-283`; `10_schema.sql:180-195` | PASS |
| `device_policies` | `rls.sql:92-99` | `30_rls.sql:84-85, 206-207` — **own-family only; no cross-family read assertion** | PARTIAL |
| `pairing_requests` | `rls.sql:79-87` (child, parent, or family parent) | `30_rls.sql:57-60, 168-169, 258-261, 290-291` | PASS |
| `audit_logs` | `rls.sql:236-240` (family **parent** only) + append-only trigger `core.sql:543-565` | `30_rls.sql:52-55, 165-166, 286-289, 243-247` | PASS |
| `remote_sessions` | `rls.sql:185-193` (participants or family parent) | `30_rls.sql:67-71, 176-179, 296-297` | PASS |
| `child_contact_ids` | `20260101000500_child_contact_ids.sql:33-35` (RLS on, no policies, no anon/authenticated grants, service_role DML) | `10_schema.sql:362-390` | PASS (see §3 for the missing zero-policy assertion) |

Cross-family **writes**: clients hold no INSERT/UPDATE/DELETE grant on `profiles`, `family_members`, `devices`, `pairing_requests`, `device_policies`, `device_commands`, `audit_logs`, `remote_sessions` (`rls.sql:247-284`), so denial is by privilege, not by policy. Local assertions exist for `devices` INSERT (`30_rls.sql:238-242`), `audit_logs` UPDATE (`30_rls.sql:243-247`), `profiles.role` UPDATE (§1) and `webrtc_signals` spoofed authorship (`30_rls.sql:187-194`).

Verdict for §2: **PARTIAL**. Gaps:
- No assertion that `parent1` cannot read `device_policies` of family2 (every other table has one).
- No cross-family **write** assertion for `safe_zones` (`insert ... family_id=families2` by parent1) — only "child cannot insert" is tested (`30_rls.sql:226-233`). The policy `safe_zones_insert_parent` (`rls.sql:149-153`) is correct, but the cross-family case is untested.
- No cross-family write assertion for `webrtc_signals` INSERT into another family's session (policy would deny; only authorship spoofing is tested).

## 3. Child ID lookup authorization

| Claim | Code evidence | Test evidence | Verdict | Gap |
|---|---|---|---|---|
| `child_contact_ids` RLS on, zero policies, no anon/authenticated grants, service-role DML | `20260101000500_child_contact_ids.sql:18-35` | `10_schema.sql:362-390` (RLS enabled; `anon`/`authenticated` hold no privilege; `service_role` has `select,insert,update,delete`) | PASS | "Zero policies" is not asserted for this table: `10_schema.sql:15-17` `v_service_only` does not include `child_contact_ids`, and the `pg_policies` count at `:36-39` therefore skips it. Denial still holds via grants. |
| `get_contact_id` returns only the caller's own ID | `pairing/index.ts:446-453` — `requireUser(requireVerifiedEmail)`, `requireRole(child)`, `ensureContactId(db, auth.user.id)`; no ID parameter is read from the body (`:224-257`) | none (no Deno/HTTP test for `pairing`) | PASS (code) / NOT TESTED (test) | No automated assertion that a parent JWT gets `403 role_required` from `get_contact_id`. |
| `invite` authorization | `pairing/index.ts:760-776` — verified email, `role=parent`, `assertFamilyParent(family_id)` (`_shared/auth.ts:194-205`), format check before lookup | HOSTED-EVIDENCE-2026-10-27: `.tools/phase4_run_235716.log`, blocks `T3 child role cannot invite` (403 `role_required`) and `T3b unauthenticated invite` (401) | PASS | Function-level behaviour untested locally. |
| Uniform error for unusable identifiers | `pairing/index.ts:47` single message; `:292-307` (unknown / not-a-child), `:331-332` (linked elsewhere), `:569-572` (malformed code) | HOSTED-EVIDENCE-2026-10-27: `phase4_run_235716.log`, blocks `T2 malformed Child ID` / `T2b well-formed unknown` (`uniform_bodies=YES`); lines 57-58 cross-family → `invalid_code` | PASS | Timing differs (see §9). |

## 4. Pairing approval + replay

| Sub-claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| Token status/expiry checked **before** a request may be reused | `pairing/index.ts:585-599` (status `active` + `expires_at` check, token flipped to `expired`) then `:628-662` (existing request reuse). RPC re-checks the token under `FOR UPDATE`: `20260101000100_functions.sql:231-237` | `40_functions.sql:237-244` (`code_expired`); `55_pairing_invite_atomic.sql:236-271` | PASS |
| `child_already_linked` 409 **only** for the child's own family | `pairing/index.ts:319-333` (invite path) and `:610-626` (code path): 409 only when `linkedFamilyId === familyId`, otherwise the uniform 400. RPC guard: `functions.sql:249-257` | `40_functions.sql:229-236` (`23505 child_already_linked` cross-family at RPC level); HOSTED-EVIDENCE-2026-10-27: `phase4_run_235716.log:57-61` (same family → 409, other family → 400) | PASS |
| Same-parent replay idempotent 200 | `pairing/index.ts:341-371` (invite reuse), `:636-659` (code reuse); RPC `functions.sql` via `create_pairing_invite` `20260101000600_atomic_pairing_invite.sql:58-69` | `55_pairing_invite_atomic.sql:86-97` (`created=false`, same request id); HOSTED-EVIDENCE-2026-10-27: `phase4c_run.log` (`redeem_A_replay: 200`, same `id`) | PASS — with caveat |
| Cross-parent replay 409 `code_unavailable` | `pairing/index.ts:660-661` (request already exists for another triple) and `:677-681` (RPC `code_unavailable`) | `55_pairing_invite_atomic.sql:256-263`; HOSTED-EVIDENCE-2026-10-27: `phase4c_run.log` (`redeem_B_replay: 409 code_unavailable`) | PASS |
| Malformed/unknown uniform 400 | `pairing/index.ts:569-572`, `:769-774` | `phase4_run_235716.log:12-18` (hosted) | PASS |

Caveats: (a) after the token has been **redeemed** (approved), a same-parent replay returns the uniform `400 invalid_code`, not `200` — only a still-pending request is "idempotent 200" (`pairing/index.ts:585-599` precedes `:628`). (b) No local automated test drives the Edge Function; the only function-level proof is the hosted log from 2026-10-27. (c) `handleInvite` never inspects the internal invite token's status before returning a pending request; safe today only because every write path that revokes an invite token also cancels the request (`functions.sql:280-283, 301-303, 398-406`, `pairing/index.ts:889-893`).

## 5. Device registration and revocation

| Sub-claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| Unlinked/revoked credential rejected | `_shared/auth.ts:302-335` (`secret_hash` null → 401 with a dummy constant-time compare; `status <> 'active'` or `credential_revoked_at` → 403 `device_revoked`). Unlink nulls the secret: `functions.sql:379-385` | `40_functions.sql:308-321` (all child devices revoked, secret null); `45_device_recovery.sql:98-108` | PASS |
| `private.revoke_device` does not return secret columns | `functions.sql:462-464` (already-revoked branch) and `:503-504` — `to_jsonb(v_device) - 'installation_id' - 'secret_hash'` | none | PARTIAL / NOT TESTED |
| Recovered device is distinct, old credential revoked | `20260101000400_device_recovery.sql:15-70` (recovery = `private.unlink_child` → revoke+null secret, cancel requests/tokens) + `device-register/index.ts:53-102` re-enrolment gate (`requiresRelink`, `_shared/enrollment.ts:3-13`); new row inserted at `device-register:214-221` | `45_device_recovery.sql:79-144` (old row revoked/secret null, membership removed, no active device, one audit row, idempotent replay) | PARTIAL |
| Re-enrolment after revoke needs a *later* approval | `device-register:84-101`; `enrollment_test.ts:11-50` | `enrollment_test.ts` (5 cases) | PASS |

Gaps: no assertion that the `revoke_device` reply omits `secret_hash`/`installation_id` (only code inspection); "distinct device" is not asserted — it depends on the client sending a new `installation_id`. If the reinstalled app reuses the same `installation_id` in the same family, `device-register:143-195` finds the revoked row and **re-credentials that same `devices.id`** instead of inserting a new row (safe, because the gate at `:175` still requires a post-revocation approval, but the claim "distinct" is not enforced server-side).

## 6. Policy download and acknowledgement

| Sub-claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| Who may fetch policy | Device: only via its own credential — `device-command/index.ts:224-239` → `private.poll_device_commands` (`functions.sql:596-651`), policy embedded in the `apply_policy` payload (`functions.sql:160-176`). Child: RLS select on its own device's policies (`rls.sql:92-99`). Parent: RLS select for the family (`rls.sql:92-96`). No client UPDATE grant (`rls.sql:268`) | `30_rls.sql:84-85, 206-207`; `40_functions.sql:144-164` | PASS |
| Who may patch policy state | Parent only, by creating a new version (`device-policy/index.ts:50-66`, `requireActiveDeviceForParent`); device only by ack (`device-command:242-352`). No client write privilege on `device_policies`/`device_commands` | `40_functions.sql:123-139` (revoked/unknown device cannot receive policy), `:476-488` (authenticated cannot call the RPC) | PASS |
| Device cannot ack a version it never received | **Fails the strict reading**: ack accepts `status = 'pending'` as well as `'delivered'` — `device-command:303-304` — so a command that was never polled (never delivered) can be acked, including `apply_policy` | none | PARTIAL / FAIL (strict claim) |
| Failed ack must not advance `devices.policy_version` | `device-command:291-302` (status/`error_message`) then `:318-352`: `device_policies` is updated with `enforcement_status = 'failed'`; `devices.policy_version` is written **only** under `nextStatus === "succeeded"` (`:339-349`). Heartbeat explicitly refuses to set it (`device-telemetry:84-85`) | none | PASS (code) / NOT TESTED |
| `policy_version` is a monotonic server-side truth | Regression possible: `:337-349` writes `appliedVersion` with no `>= current policy_version` guard, so acking an older still-pending command lowers `devices.policy_version` after a newer ack | none | GAP (see bug B1) |

## 7. Realtime private topics

| Claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| Private topic policy restricted to family members / session participants | `20260101000200_rls.sql:295-332` (`private.realtime_topic_allowed`: `safety-alerts`/`remote-session-family` → `is_family_member`; `remote-session`/`webrtc-signals` → participant or family parent; malformed/unknown → false), `:344-359` (`create policy ... to authenticated using (...)`) | `50_realtime_policy.sql:17-81` (policy exists; family1 yes / family2 no; own session yes / other session no; non-participant child4 denied; malformed denied); `30_rls.sql:356-413` (same matrix at function level, incl. unlinked child and null topic) | PASS |
| No anon access | Policy is `to authenticated`; helper EXECUTE revoked from `anon` (`rls.sql:334-336`) | `10_schema.sql:237-239` (anon lacks EXECUTE on the helper). **No test selects from `realtime.messages` as `anon`** | PARTIAL |
| Payload rows still filtered by table RLS | `rls.sql:338-343` comment + each table's own policy | `50_realtime_policy.sql:10-16` documents the local stub limitation | PASS (design) |

Gaps: (a) no `anon`-role assertion against `realtime.messages` itself; (b) the policy is **topic-only**, so an authorized subscriber also sees any `broadcast` row on that topic — the local test at `50_realtime_policy.sql:31, 42-46` counts 6 rows including the `broadcast` fixture, i.e. the gate does not discriminate `extension`; there is no INSERT policy on `realtime.messages`, so clients cannot publish, and no hosted Realtime run exists in this repo; (c) the policy is created only if `realtime.messages` already exists when the migration runs (`rls.sql:344-359`, `raise notice` otherwise) — a deployment-order hazard, not testable locally beyond the stub.

## 8. Device command expiry / single-use

| Claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| Commands expire | `20260101000000_core.sql:211` (`expires_at` NOT NULL) ; `functions.sql:614-618` expires stale rows on every poll; `device-command:122-123` TTL clamped to 60–900 s; ack of an expired command settles it as `expired` and returns 410 (`device-command:270-289`) | `40_functions.sql:144-157` (poll marks delivered, expires stale), `:159-164` (redelivery does not re-increment attempts) | PASS |
| Single use (ack) | `device-command:266-268` terminal status returns the settled row; `:303-304` conditional update `.in(['pending','delivered'])` makes the transition a one-shot CAS; `:308-315` returns the winner's row on a race | none (Edge Function only) | PASS (code) / NOT TESTED |
| DB-level expiry guarantee | No `check (expires_at > created_at)` and no default; a caller that bypasses the Edge Function (service role only) could insert a past `expires_at` | none | PARTIAL |

Gap: `device_commands` (like `remote_sessions`) has no per-device queue cap — an authorized parent can insert unbounded pending commands; `device-command:184-197` only dedupes by `idempotency_key`. Low impact (authorized actor, 15-min TTL, 20-row poll page).

## 9. Rate limiting on pairing lookups

| Claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| 5 failed lookups per parent per 10 min | `_shared/rate_limit.ts:12-13, 51-71` (`success=false`, `attempted_at >= now-10min`, `>= 5` → 429) | HOSTED-EVIDENCE-2026-10-27: `phase4_run_235716.log:82-87` (5 × `invalid_code`, 6th → `429 rate_limited`) | PASS |
| `retry_after_seconds` present | `rate_limit.ts:64-71` (constant `600`); computed remaining window only for code-creation/invite-quota (`:30-37, 150, 200`) | hosted log line 87 shows `"retry_after_seconds":600` | PARTIAL — the parent-limit value is a constant, not the true remaining window |
| Successes excluded | `rate_limit.ts:57-62` filters `success=false`; `recordPairingAttempt(..., true)` on every 200 path (`pairing/index.ts:324, 357, 403, 643, 715, 733`) | none | PASS (code) |
| Per-identifier cap | `rate_limit.ts:73-88` (10 failures per `code_hash` / 10 min) | none | PASS (code) |
| Unknown/malformed cannot enumerate | identical `code/message/status` (`pairing/index.ts:47, 292-307, 331-332, 569-572, 769-774`); keyed digest `identifierHash` (`validation.ts:305-316`) | hosted `uniform_bodies=YES` | PARTIAL |

Static side channels and gaps found:
1. **Timing.** An unknown well-formed Child ID costs one indexed SELECT + one `pairing_attempts` INSERT (`pairing/index.ts:285-294`); a valid, unlinked ID costs that plus a `profiles` SELECT, a `family_members` SELECT, a `pairing_requests` SELECT, an RPC (advisory lock + 2 inserts), a `families` SELECT and 2 audit inserts (`:298-433`). Response bodies are identical but latency is not; the 5-per-10-min cap makes it impractical to enumerate the 30^8 ≈ 6.6×10^11 space, but it is a real oracle for a targeted guess.
2. **Counting.** Each failure is recorded *after* the lookup, so a burst of >5 concurrent requests from the same parent can all pass `assertPairingRedeemAllowed` before any failure is counted (TOCTOU; `pairing/index.ts:283-294`, `rate_limit.ts:51-71`). Concurrent bursts are therefore not capped at 5.
3. **Malformed `invite` skips the pre-check** (`pairing/index.ts:769-774` records an attempt but never calls `assertPairingRedeemAllowed` first), so an authenticated parent can generate unlimited `pairing_attempts` rows with garbage input; `redeem` does gate this (`:565-572`). See bug B2.
4. **Pepper fallback.** `identifierHash` silently falls back to unsalted SHA-256 when `PAIRING_HASH_PEPPER` is unset (`validation.ts:309-315`), making stored attempt hashes offline-enumerable over 30^8 (child IDs are 8 chars from a 30-char alphabet) — metadata only, not access.

## 10. Audit content

| Claim | Code evidence | Test evidence | Verdict |
|---|---|---|---|
| No raw Child ID, token or secret in audit rows | `_shared/audit.ts:20-28` writes only the supplied fields; pairing insert sites: `pairing/index.ts:405-417` (`child_user_id`, `via:"child_id"` — comment `:413-414` explains why the ID is not stored), `:734-741`, `:895-901`; revocation/recovery: `functions.sql:491-499`, `20260101000400_device_recovery.sql:52-64` (child_user_id + counters only). `grep contact_id` shows the Child ID never reaches an audit call | `45_device_recovery.sql:122-126` (no `code|token|secret|secret_hash|token_hash` key in `device_recovery_started`); `55_pairing_invite_atomic.sql` / `40_functions.sql:217-220` assert the events exist but not their metadata keys | PASS |

Gap: the metadata secret-scan is asserted for one event type only (`device_recovery_started`). `pairing_invited`, `pairing_redeemed`, `command_created` have no key-set assertion; code inspection is clean (`child_user_id` UUIDs and `via` only).

---

## "Knowing a Child ID alone" — access analysis

| Path reachable with only a Child ID + any self-registered parent account | Result |
|---|---|
| `pairing.invite` / `pairing.redeem` with a `PC…` value | Creates a `pending_child` request only (`pairing/index.ts:276-433`, `20260101000600_atomic_pairing_invite.sql:71-88`). |
| Approval | Requires the child's own JWT: `_shared/auth.ts:129-139` + `pairing/index.ts:812-827` + `functions.sql:215-217` (`child_user_id <> p_child_user_id` → 42501). The child app's approval is an explicit user action (`lib/features/pairing/pairing_redeem_page.dart:206-212`). |
| Device telemetry / commands / policy | Need `x-device-id` + `x-device-secret` (`_shared/auth.ts:281-337`); a Child ID yields neither, and the secret is only ever issued to the child's own authenticated `device-register` call. |
| Camera / microphone | `remote-session` `request` needs a parent of the device's family (`remote-session/index.ts:95-118`); `ice` needs a session with `status in (accepted, active)`, `consent_recorded = true` and a live `expires_at` (`:311-337`), and the child must `respond`/`start` (`:158-268`). TURN credentials are minted per session for a participant (`_shared/turn.ts` via `:335`). |
| Realtime | Topic gate needs `auth.uid()` membership/participation (`rls.sql:295-332`); a Child ID is not a UUIDv4 session/family id. |

**No backend path turns a Child ID into device, camera, microphone or recording access.** The Child ID is an identifier that can only open a consent prompt. Residual exposure: a valid Child ID confirms (200 vs 400) that the identifier exists and returns the child's `child_user_id` UUID before approval (`pairing/index.ts:164-181, 420-432`), and it drops the display-name mask only after approval (`:164`). Both are intentional per the code comments and the design memo `.tools/evidence/full-qa/read-only-audit-20261027/A4-security-design.md`.

---

## Findings (bugs)

| # | Severity | Finding | Evidence |
|---|---|---|---|
| B1 | P3 | `devices.policy_version` is written from whatever `apply_policy` command the device acks, with no monotonic guard and no "must have been delivered" guard: a device can ack an undelivered `pending` command or re-ack an older pending version and make the stored version jump forward or **regress**. The parent UI's enforcement indicator is therefore device-asserted, not server-verified. Not an access-control bypass (the device is the controlled party and the credential is required). | `supabase/functions/device-command/index.ts:303-304` (ack allowed from `pending`), `:337-349` (unconditional `policy_version = appliedVersion`) |
| B2 | P3 | The `invite` action records a failed attempt for malformed input but never calls `assertPairingRedeemAllowed` first, so an authenticated parent can write unlimited `pairing_attempts` rows (and get unlimited 400s) with garbage — an unbounded write path that the `redeem` action correctly gates. | `supabase/functions/pairing/index.ts:769-774` vs `:565-572` and `_shared/rate_limit.ts:51-71` |
| B3 | P3 | Child ID existence oracle by latency (identical bodies, different query/RPC work). Bounded by 5 failures/10 min; also a concurrency window lets >5 parallel lookups pass the pre-check before failures are counted. | `supabase/functions/pairing/index.ts:285-294` vs `:298-433`; `_shared/rate_limit.ts:51-71` (check-then-insert, no unique/advisory guard) |
| B4 | P3 | `identifierHash` falls back to unsalted SHA-256 when `PAIRING_HASH_PEPPER` is unset (logged once as a warning), so stored attempt hashes become offline-enumerable over the 30^8 identifier space in a DB dump. Metadata only. | `supabase/functions/_shared/validation.ts:305-316` |
| B5 | P3 | The parent-level 429 advertises a constant `retry_after_seconds: 600` instead of the true remaining window; clients that honour it may retry too early or too late. Cosmetic/UX, not security. | `supabase/functions/_shared/rate_limit.ts:64-71` |
| B6 | P3 | No cap on `remote_sessions` requests or non-policy `device_commands` per child/device: an authorized family parent can fill a minor's consent inbox beyond the pairing cap (3 pending) and queue unbounded commands. Consent still gates every media path. | `supabase/functions/remote-session/index.ts:102-118`; `supabase/functions/device-command/index.ts:184-197` |

No P0/P1/P2 finding was identified in the backend: every family-scoped read/write is gated by `private.is_family_parent`/`is_family_member` or a `child_user_id = auth.uid()` predicate, every service-only table has RLS with no policies and no client grants, and every state-changing RPC is `service_role`-only.

---

## Limitations of this audit

- Local only. No Edge Function was executed; `deno test` covers only `_shared` (`enrollment_test.ts`, `policy_test.ts`, `turn_test.ts`, `validation_test.ts`) — there are **no** tests for `pairing`, `device-command`, `device-register`, `device-policy`, `family-admin`, `remote-session`, `device-telemetry` or `cron` handlers.
- The SQL suite result cited indirectly here is the pre-existing local log `.tools/sql_rerun_185456.log` (0 `ASSERTION FAILED`, 0 `ERROR`) which `supabase/tests/README.md:4-14` describes as a disposable PostgreSQL 16.9 run of all seven migrations; it was **not** re-run for this audit, and it does not validate any Supabase project.
- Hosted observations are quoted only from `.tools/phase4_run_235716.log`, `.tools/phase4b_run_235916.log`, `.tools/phase4c_run.log` (2026-10-27 staging), and are labelled as such; they are not reproducible from this repository alone.
- `realtime.messages` in the local suite is a stub (`supabase/tests/05_realtime_stub.sql`); no hosted Realtime server behaviour is verified.
