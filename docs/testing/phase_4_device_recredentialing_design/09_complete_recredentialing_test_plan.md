# 09 — Complete Re-Credentialing Test Plan

**Scope:** Tests required before any implementation can be declared complete. None are executed in Phase 4.  
**Legend:** `NOT RUN` (all rows), priority P0/P1/P2, layer = Unit / Backend / Staging / E2E / Production.

The plan covers the 30 scenarios required by the Phase 4 brief plus the specific security invariants from reports 05–08.

---

## 1. Test layers and gates

| Layer | What it proves | Runs where | Gate |
|---|---|---|---|
| **L1 Offline unit (Dart)** | Controller/repository state machines, error mapping, no secret logging | `flutter test` | B |
| **L2 Offline unit (Kotlin)** | Credential-state classification, resync intent, no regeneration | `./gradlew test` | B |
| **L3 Backend unit (Deno)** | Handler validation, auth wiring, envelope shapes, rate-limit helpers | `deno test` | B/C |
| **L4 Backend integration (SQL)** | RPC atomicity, locking, grants, RLS, audit, invariants | `supabase/tests/run_sql_chain` | C |
| **L5 Staging** | Real Edge + real Postgres + two test accounts | Staging project (Gate D) | D |
| **L6 Physical two-device E2E** | Real Android reinstall, parent/child UI, heartbeat/presence | Named devices (Gate E/F) | E/F |
| **L7 Production** | Only if separately approved; never in this phase | Production (Gate D/F) | D+F |

---

## 2. Scenario catalogue (required coverage)

### A. Credential states

| ID | Scenario | Preconditions | Steps | Expected | Layer | Pri |
|---|---|---|---|---|---|---|
| RC-01 | Fresh install, no existing device | Child linked, no device row | Sign in → enroll → register | New device row created; heartbeat 200; Parent Online | L5/L6 | P0 |
| RC-02 | Existing device, valid local credential | Active row + matching secret | Launch | No recovery prompt; heartbeat 200; presence healthy | L1/L5/L6 | P0 |
| RC-03 | Existing device, missing local credential | Active row; store empty | Launch | `unconfirmed` state; recovery card; **no** automatic rotation; heartbeat 401 | L1/L5/L6 | P0 |
| RC-04 | Existing device, mismatched credential | Active row; different secret | Launch | Same as RC-03; no silent re-register | L5/L6 | P0 |

### B. Parent authorization

| ID | Scenario | Preconditions | Expected | Layer | Pri |
|---|---|---|---|---|---|
| RC-05 | Parent approval accepted | Active parent, active device | Challenge issued; Child completes; same device id; old secret 401, new secret 200 | L4/L5/L6 | P0 |
| RC-06 | Parent rejects / cancels | Pending challenge | Challenge closed; Child completion 410/409; no rotation | L5 | P0 |
| RC-07 | Parent approval expired | Challenge past `expires_at` | Completion 410; device row unchanged; new challenge issuable | L4/L5 | P0 |
| RC-08 | Unauthorized (non-parent) caller | Child or unset role calls Parent action | 403; no challenge row | L3/L4 | P0 |
| RC-09 | Foreign-family device id | Parent of family A, device of family B | 403/404 uniform; no challenge; no audit leak of B | L4/L5 | P0 |
| RC-10 | Removed/suspended parent | Membership `removed` | 403 | L4 | P0 |
| RC-11 | Removed/suspended child | Child membership not active | Completion 403; no rotation | L4 | P0 |

### C. Device state guards

| ID | Scenario | Preconditions | Expected | Layer | Pri |
|---|---|---|---|---|---|
| RC-12 | Revoked device | `status='revoked'` | Parent action 409/403; no challenge; Child still under re-link gate | L4/L5 | P0 |
| RC-13 | Device revoked mid-recovery | Pending challenge, then revoke | Completion fails; membership/device state follows revoke; no reactivation | L4 | P0 |
| RC-14 | Child unlinked mid-recovery | Pending challenge, then unlink | Completion 403; no rotation | L4 | P0 |
| RC-15 | Challenge for a different device | Challenge bound to D1; Child submits D2 | 409/403; D2 unchanged | L4/L5 | P0 |
| RC-16 | Challenge for a different family | Cross-family challenge | 403; no rotation | L4 | P0 |

### D. Idempotency / replay / rate limits

| ID | Scenario | Expected | Layer | Pri |
|---|---|---|---|---|
| RC-17 | Repeated recovery request (same parent) | One pending challenge (supersede); no duplicate device changes | L4/L5 | P0 |
| RC-18 | Concurrent recovery requests | One pending challenge; no deadlock; deterministic winner | L4 | P1 |
| RC-19 | Replay of a consumed challenge with same secret | Idempotent 200 (if designed) or 409; **no** second rotation | L4/L5 | P0 |
| RC-20 | Replay of a consumed challenge with a **different** secret | 409; current credential unchanged | L4 | P0 |
| RC-21 | Replay of an expired challenge | 410; unchanged | L4 | P0 |
| RC-22 | Brute force wrong codes | Attempt cap enforced; 429 after limit; audit denied attempts | L3/L4/L5 | P0 |
| RC-23 | Rate limit across devices | Per-child/per-parent window enforced; no cross-family victim lockout | L4 | P1 |

### E. Failure and recovery

| ID | Scenario | Expected | Layer | Pri |
|---|---|---|---|---|
| RC-24 | Network loss during completion | No commit or full commit; retry works; no lockout | L5/L6 | P0 |
| RC-25 | Server success + client response loss | Heartbeat succeeds with new secret; Parent Online; optional idempotent retry | L5/L6 | P0 |
| RC-26 | Old credential after success | All seven device endpoints return 401 | L4/L5 | P0 |
| RC-27 | New credential after success | All seven device endpoints return 200 | L4/L5/L6 | P0 |
| RC-28 | Heartbeat after recovery | `last_seen_at` advances; `pending_policy_version` returned | L5/L6 | P0 |
| RC-29 | Parent online/offline after recovery | "Online" within the 12-minute window; no stale "Offline" after a successful beat | L1/L6 | P0 |
| RC-30 | App process restart after recovery | Config persists; heartbeat continues | L6 | P0 |
| RC-31 | Child reboot after recovery | Boot receiver restarts guardian; heartbeat continues | L6 | P1 |
| RC-32 | Audit verification | `device_recovery_requested` + `device_recredentialed` exist once; no secrets in metadata | L4/L5 | P0 |
| RC-33 | Data preservation | Membership unchanged; device id unchanged; policy/usage/location rows still attached | L4/L5/L6 | P0 |
| RC-34 | No automatic recovery on new installation ID | Child cannot rotate without a challenge; server rejects any implicit path | L3/L5 | P0 |

### F. Compatibility

| ID | Scenario | Expected | Layer | Pri |
|---|---|---|---|---|
| RC-35 | Old Child + new server | Existing 401 behavior; no crash; clear update message if surfaced | L5 | P1 |
| RC-36 | New Child + old server | `unknown_action`; no partial state | L3/L5 | P1 |
| RC-37 | Old Parent + new server | Destructive recovery unchanged; no regression | L5 | P1 |
| RC-38 | New Parent + old server | Clean failure; no local "success" | L5 | P1 |

### G. Negative security tests

| ID | Scenario | Expected | Layer | Pri |
|---|---|---|---|---|
| RC-39 | Parent supplies another parent's device id in body | Server ignores client family/child claims; uses device row | L4 | P0 |
| RC-40 | Child supplies `family_id` of another family | Rejected; challenge family is authoritative | L4 | P0 |
| RC-41 | Client tries to set `secret_hash` for a device it does not own | 403; no update | L4 | P0 |
| RC-42 | Client tries to set `status`/`credential_revoked_at` via recovery | Server ignores; only rotation fields accepted | L4 | P0 |
| RC-43 | RLS: authenticated/anon select on challenge table | Denied (no policy/grant) | L4 | P0 |
| RC-44 | RLS: devices still hides `secret_hash`/`installation_id` | Column grants unchanged | L4 | P0 |
| RC-45 | Audit insert failure | Rotation rolls back; no device change | L4 | P0 |

---

## 3. L1 — Offline unit tests (Dart)

Add to `test/features/child/child_shell_controller_test.dart`, `test/features/devices/device_detail_controller_test.dart`, `test/data/device_model_test.dart`:

1. `credential_unconfirmed` set when a device-auth 401 is observed; cleared on 200.
2. Recovery card does not call any recovery endpoint on load (no auto-recovery).
3. Parent controller surfaces challenge code/expiry, and maps 403/404/409/410/429.
4. Child completion sends `installationId` + `secretHash` only (assert no `secret` in the request body).
5. On completion success, `_ensureIdentityAndSync` is invoked with the **same** `device.id`.
6. On completion failure, no local success state and no `serverDeviceId` change.
7. `Device.statusLabel` remains unchanged for existing presence logic (regression).
8. No logger receives the secret/hash/code (test with a fake logger).

`NOT RUN`.

## 4. L2 — Offline unit tests (Kotlin)

1. `GuardianService` classifies HTTP 401 as `credential_invalid` without altering the human message.
2. A successful heartbeat clears the flag.
3. Resync intent rewrites `SyncConfig` with the same `deviceId` and does not regenerate `installationId`/secret.
4. `SecureStore.deviceSecret()` is stable across calls (already implicit; add explicit test).
5. No credential appears in `lastError`.

`NOT RUN`.

## 5. L3 — Backend unit tests (Deno)

1. Parent action rejects unverified email, non-parent role, missing/invalid `device_id`.
2. Child completion rejects unverified email, non-child role, invalid `installation_id`, non-64-hex hash.
3. Envelope shape and status codes for 400/401/403/404/409/410/429.
4. Rate-limit helper windows and retry hints.
5. Error mapping never includes the submitted hash or code in the response message.
6. Audit metadata builder excludes secret/hash/code.
7. Handler wiring test (`supabase/functions/handler_wiring_test.ts`) updated to include the new action.

`NOT RUN`.

## 6. L4 — Backend integration / SQL (highest value)

Add a dedicated suite (name proposed: `80_device_recredentialing.sql`, run after fixtures like `45_device_recovery.sql`). It must assert:

1. Grants: `anon`/`authenticated` cannot execute either RPC; `service_role` can.
2. Parent of family A cannot recover a family B device (no state change).
3. Revoked device cannot be recovered.
4. Happy path: challenge consumed, hash/installation changed, `id`/`family_id`/`child_user_id` unchanged, membership unchanged, audit rows present.
5. Old hash no longer matches; new hash matches.
6. Replay after consumption with a different hash fails and leaves the row unchanged.
7. Expired challenge fails.
8. Concurrent completion (two sessions or a controlled race script) rotates exactly once.
9. Revoke/unlink during pending challenge invalidates completion.
10. RLS: challenge table invisible to authenticated; devices column grants unchanged.
11. Audit metadata contains no `secret_hash`, raw secret or code.
12. `devices_one_active_per_child` and `devices_family_installation_key` still hold.

The repo already has race runners (`run_pairing_invite_race.sh`, `run_remote_session_race.sh`) to model RC-18/RC-19.

`NOT RUN`.

## 7. L5 — Staging tests

Use a dedicated ephemeral tenant (the repo has prior ephemeral-tenant qualification work). Execute RC-01…RC-45 except physical-device-only items, with real Edge Functions, real Postgres, two test accounts, and a scripted device client that holds its own new secret.

Must capture:
- HTTP status/body (redacted of any credential);
- `devices` row before/after (public columns only);
- audit rows;
- challenge expiry;
- rate-limit responses.

`NOT RUN`.

## 8. L6 — Physical two-device E2E (Gate E/F)

Devices: Child Realme RMX2161 (API 31) and Parent Pixel 9a emulator (API 37), or the owner-named replacements. Record exact build/commit and APK SHA-256.

Sequence:
1. Establish the current failure state (Parent Offline, Child heartbeat 401).
2. Parent approves credential replacement for the named device; record the code.
3. Child (reinstalled) enters the code.
4. Verify: same device UUID; Parent shows Online within 12 minutes; `last_seen_at` advanced; policy/usage/location/apps still attached; membership unchanged.
5. Restart the Child app; verify heartbeat continues.
6. Reboot the Child phone; verify heartbeat continues.
7. Verify the old install (if retained) can no longer authenticate.
8. Verify the audit events in the Parent audit log (no secrets).
9. Repeat with an expired code and a wrong code (negative).
10. Verify the destructive recovery path still works and is clearly separate.

`NOT RUN — requires Gate E (test-device credential recovery) and Gate F (two-device regression).`

## 9. L7 — Production tests

Only if the owner separately authorizes a production test with a **test** family/device. Never use a real child's device. All production tests must be read-only or confined to the test tenant, and must have a rollback/kill-switch plan. `NOT RUN — not authorized`.

---

## 10. Exit criteria

| Criterion | Required evidence |
|---|---|
| All P0 tests pass | Test log + redacted responses |
| No secret/hash/code in any log or audit | Grep of logs + audit query |
| Membership + device id unchanged | Before/after SQL snapshots (public columns) |
| Old credential rejected, new accepted | 401/200 matrix for all seven endpoints |
| Concurrency rotates once | Race test output |
| Expiry/replay respected | Negative test output |
| Parent sees Online | Two-device screenshots/dumps |
| Compatibility matrix | Old/new build matrix results |

No test in this plan was executed in Phase 4.
