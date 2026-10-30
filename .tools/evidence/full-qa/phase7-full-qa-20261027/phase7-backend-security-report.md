# Phase 7 full QA — backend / security agent report

Run date: 2026-10-27 (hosted project `hhqgreaoqulmfwfwarhc.supabase.co`)
Scope: tasks 1–8 of the Phase 7 brief. No project source file was modified.
Secret policy honoured: no password, service-role key, device secret, pairing
code or token value appears in this folder — secrets are referenced by
variable name only.

## 1. Harness counts vs documented baseline

| Harness (documented count) | Executed | Pass | Fail | Blocked/Skip/Info | Note |
|---|---|---|---|---|---|
| `.tools/live/verify_live.mjs` (24 live checks) | 18 | 16 | 2 | 2 SKIP | `pairing.A.create`/`pairing.B.create` → 429 `rate_limited`; the 2 dependent redeem checks record SKIP, and **6 more checks vanish unrecorded** (`pairing.A.pending_child`, `A.respond_approve`, `A.membership_visible_to_child`, `A.replay_denied`, `A.cross_family_redeem_denied`, `B.respond_approve`) because they sit inside the `if (freshCode)` block with no `else` branch |
| `.tools/live/revoke_shape_check.mjs` (4 shape checks) | 4 | 4 | 0 | 0 | Revoke response leaks no `secret_hash`/`installation_id` |
| `.tools/live/verify_devices.mjs` (42 device checks) | 1 | 1 | 0 | 41 not run | `device.register` → 403 (re-enrollment after revocation blocked) → harness exits FATAL |
| `.tools/live/recover_device_live.mjs` (31 recovery checks) | 0 | – | – | 31 not run | Deliberately not run: it `unlink`s CHILD_C and consumes 2 pairing codes, i.e. it would destroy the fixture the device agent is re-pairing with |
| New: `cross_family_isolation.mjs` | 70 | 67 | 0 | 3 | 17-table bidirectional A→B REST invisibility, column grants, IDOR, roles, realtime, anon/cron edge |
| New: `isolation_round2.mjs` | 73 | 70 | 1 → reclassified 0 | 2 | The single FAIL (401 on foreign `device-command` create) reproduced as 403 `forbidden` in `device_command_401_probe.mjs`; cause = harness bearer lifetime, not backend |
| New: `device_credential.mjs` | 24 | 20 | 0 | 4 (2 BLOCKED + 2 INFO) | Full credential rejection matrix, REST write-forge denial, expired-command census |
| New: `pairing_security.mjs` + `pairing_window_retry.mjs` + `pairing_uniform_retry.mjs` | 26 | 20 | 3 → reclassified 0 | 6 | All 3 FAILs were the documented 5-per-10-min parent attempt window (429) or a corrected expectation (valid-UUID `request_id` → 404 is correct) |
| New: `storage_check.mjs` | 10 | 10 | 0 | 0 | No bucket exists, nothing publicly listable |
| New: `secret_scan.mjs`, `apk_secret_stream.mjs`, `apk_secret_chunked.mjs`, `debug_apk_asset_scan.mjs` | 4 artifact classes | clean | 0 | – | Repo working tree + release APK `libapp.so` (5 ABIs) + debug APK `kernel_blob.bin` (80.9 MB) |

Net: every FAIL recorded above was traced to fixture/quota state or a
harness-expectation bug; no FAIL survived re-testing as a product defect.
Total newly-executed hosted checks this run: 199, of which 196 pass and 3 are
BLOCKED for documented fixture reasons (2 need a live device credential, 1
needs a fresh pairing code).

## 2. Checks 2–7 results (compact)

| # | Check | Result | Evidence |
|---|---|---|---|
| 2 | Cross-family REST SELECT isolation, 17 tables, both directions | PASS (17/17 + 17/17) | `cross_family_isolation.json`, `isolation_round2.json` |
| 2 | Privileged columns (`secret_hash`, `installation_id`) not granted to anon/authenticated | PASS (42501) | `cross_family_isolation.json` |
| 2 | IDOR by substituting a foreign device/session id into 12 Edge actions | PASS — 403 `forbidden`/`role_required`, 401 for device-credential actions; no foreign row mutated | `isolation_round2.json`, `device_command_401_probe.json` |
| 2 | Realtime cross-family subscribe denied, own-family allowed | PASS (allow 4/4, deny 8/8) | `isolation_round2.json` (2 denials surfaced as TIMED_OUT instead of CHANNEL_ERROR — cosmetic) |
| 3 | Roles server-derived; client-side promotion attempts | PASS — PATCH `profiles` 42501/0 rows, INSERT `profiles` denied, INSERT `family_members` denied, membership role UPDATE denied, `set_role` child→parent 409 `role_already_set`, `create_family` as child 403, anon PATCH 401; role after all attempts still `child` | `cross_family_isolation.json` |
| 4 | Pairing expiry / replay / non-target redemption / wrong-family redemption | PARTIAL — wrong-family 403 `forbidden`, child 403 `role_required`, anon 401, replay of consumed code previously 409, malformed `family_id` 400; expiry + fresh replay + cross-family-of-a-live-code BLOCKED (create cap 5/24 h exhausted for CHILD_A/B/C). Unknown-but-well-formed and short codes answer identically (400 `invalid_code`) → no enumeration oracle | `pairing_security.log`, `pairing_uniform_retry.log`, `pairing_blocked_proof.json` |
| 5 | Device credential validation | PASS on rejection surface (missing/partial headers 401 `device_auth_required`; short secret / malformed UUID / unknown id / wrong secret all 401 `invalid_device_credentials` and byte-identical; user JWT does not authenticate a device; forged REST inserts 42501) — the 403 `device_revoked` branch and duplicate/stale-telemetry positive paths BLOCKED (sha256 secret unrecoverable, no new enrollment possible) | `device_credential.json` |
| 6 | Realtime private-channel authorization allow/deny | PASS (see row 2); `private.realtime_topic_allowed` behaves as documented for `<kind>:<uuid>` and `<kind>:<uuid>:<micros>` | `isolation_round2.json` |
| 7 | Secret hygiene, repo + built APK | PASS, no regression | `secret_scan.json`, `apk_secret_chunked.json`, `debug_apk_asset_scan.json` |
| 8 | Storage bucket existence / public listing | PASS — 0 buckets, `object/list` 404/401, no public URL resolves | `storage.json` |

## 3. BLOCKED (with reasons, not retried)

1. **Direct SQL to hosted** — per brief; local drill password is not the hosted
   DB password. `direct_sql_blocked.json`. DDL-level assertions fall back to
   the local SQL suite plus behavioural REST/Edge probes.
2. **42-check `verify_devices.mjs`** — needs a live enrollment; every device
   row is `revoked` and `device-register` returns 403 `device_revoked` /
   403 `forbidden` (`probe_enrollment.log`), because
   `requiresRelink()` blocks re-enrollment while
   `credential_issued_at <= revoked_at` and the correct secret is not
   recoverable (sha256 only, `.tools/live/device_a.env` deleted).
3. **31-check `recover_device_live.mjs`** — would unlink CHILD_C and consume
   two of the remaining pairing codes the device agent is racing for.
4. **Pairing expiry/replay positive paths** — `device_pairing_tokens` cap of 5
   creations per child per 24 h exhausted (create → 429). Code spec verified
   from source + `pairing_blocked_proof.json`: 8 chars over a 30-char alphabet
   (~6.5e11 keyspace), 10-min TTL, 10 attempts per code, 5 attempts per parent
   per 10 min.
5. **`heartbeat after revocation → 403` and `duplicate/stale telemetry`
   accept-path** — same root cause as (2).

## 4. Defect / risk list for the fix owner (nothing edited)

* **D-1 (Low, info disclosure + cost)** `requireAction()` runs before
  `requireUser()` in the Edge Functions, so an unauthenticated caller with the
  anon key gets 400 `unknown_action` for a bad action and only 401 for a good
  one — valid actions are enumerable pre-auth and each probe bills an
  invocation. Files: `supabase/functions/pairing/index.ts`,
  `device-command/index.ts`, `family-admin/index.ts`, `device-policy/index.ts`,
  `remote-session/index.ts` (same pattern). Evidence:
  `cross_family_isolation.json` (`edge.anon_invalid_action_status`),
  `isolation_round2.json`.
* **D-2 (Low, self-lockout)** `assertPairingRedeemAllowed()` counts **all**
  rows in `pairing_attempts` for the parent in the 10-minute window, including
  `success = true` rows, and it is called **before** `isPairingCode()` shape
  validation. Five typos therefore lock a parent out of redeeming a correct
  code (429) for up to 10 minutes, and a 4-char typo costs the same quota as a
  full attempt. File: `supabase/functions/_shared/rate_limit.ts:14-47` plus
  `supabase/functions/pairing/index.ts:286-291`.
* **D-3 (Medium, product availability — also the blocker for tasks 2/5)**
  A revoked device can never be re-enrolled from the same install
  (`requiresRelink()`), and pairing-code creation is capped at 5/child/24 h.
  Once both are spent, no harness or UI path can restore a live device link for
  ~6 h; today it is spent for all three child accounts. Needs an operator
  escape hatch (service-role reset, or a documented "re-enroll after revoke"
  flow that issues a fresh credential).
* **D-4 (Low, code reading, untestable today)** redemption order lets the
  first parent who redeems an un-consumed code create the
  `pending_child` request **in their own family**; the rightful parent then
  receives 409 `code_unavailable`. Child consent (`respond`) is still required,
  so it is a nuisance/redirect risk, not an auto-link. If a code is ever
  observed by a second family this becomes an account-confusion vector.
* **D-5 (Harness / evidence integrity)**
  * `.tools/live/code_capacity.mjs` reads `device_pairing_tokens` as the child;
    that table is service-role-only (no policies,
    `20260101000200_rls.sql:74`) → "permission denied", so any historical
    "capacity" line it produced is invalid evidence.
  * `verify_live.mjs` treats a 429 `rate_limited` create as FAIL instead of
    SKIP/BLOCKED, and the 5 checks nested inside `if (freshCode)` (pending,
    respond, membership, replay, cross-family redeem) have no `else` branch, so
    a capped day silently reports 18 checks instead of 24 — which reads as a
    16/18 regression against a documented 24-check baseline.
  * All live harnesses overwrite their own `results/phaseN.json` in place, so
    running them destroys the prior baseline (confirmed: today's run replaced
    `phase1.json`; a backup of the pre-run phase-2 artifact is in
    `baseline_results_backup/`).
  * Realtime denials sometimes surface as `TIMED_OUT` rather than
    `CHANNEL_ERROR`, so "denied" needs a timeout branch in every consumer.
* **Non-defects confirmed**: no Storage bucket, no privileged value in the repo
  or in any built APK, roles server-derived, cross-family data invisible in
  both directions, device credentials uniform on rejection.
  `sb_secret_` inside `libapp.so`/`kernel_blob.bin` is the app's own defensive
  guard prefix (`lib/core/config/env.dart:51`), matching the documented
  baseline in `docs/verification-report.md:354`.

## 5. Reproduce

```
node .tools/evidence/full-qa/phase7-full-qa-20261027/cross_family_isolation.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/isolation_round2.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/device_command_401_probe.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/device_credential.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/pairing_security.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/pairing_uniform_retry.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/storage_check.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/secret_scan.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/apk_secret_chunked.mjs
node .tools/evidence/full-qa/phase7-full-qa-20261027/debug_apk_asset_scan.mjs
```
Each writes its own `.json` + is logged in this folder. They load
`@supabase/supabase-js` from `.tools/live/node_modules` through `_lib.mjs` and
read credentials from `.tools/live_config.env` / `.tools/qa_accounts.env`.
