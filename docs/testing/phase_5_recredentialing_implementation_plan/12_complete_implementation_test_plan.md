# 12 — Detailed Unit, Integration, Database and Regression Test Matrix

**Scope:** Test plan for a future implementation. **No test is created or modified in this phase.**  
**Baseline:** Phase 4 report `09_complete_recredentialing_test_plan.md` (RC-01…RC-45).

---

## 1. Layers

| Layer | Tool | Proves |
|---|---|---|
| FU | `flutter test` (FVM) | controller/UI/model state, payload shape, error mapping |
| KU | `./gradlew test` | SecureStore state, 401/403 classification, resync |
| EU | `deno test` | validation, auth wiring, envelope, rate-limit helpers |
| DB | SQL chain + race scripts | atomicity, locks, grants/RLS, audit, invariants |
| SI | staging Edge + Postgres | HTTP matrix, real RPC, redaction |
| E2E | two physical devices | reinstall, presence, reboot, restart |

---

## 2. Scenario matrix (24 core)

| # | Scenario | FU | KU | EU | DB | SI | E2E | Key assertion |
|---|---|---|---|---|---|---|---|---|
| T01 | Fresh install, no device | | | | | ✓ | ✓ | new row, heartbeat 200 |
| T02 | Existing valid credential | ✓ | ✓ | | | ✓ | ✓ | no recovery prompt/mutation |
| T03 | Missing local credential | ✓ | ✓ | | | ✓ | | `unconfirmed`, no auto-recovery |
| T04 | Mismatched credential | ✓ | ✓ | | | ✓ | ✓ | 401 classified, recovery offered |
| T05 | Parent approval accepted | ✓ | | ✓ | ✓ | ✓ | ✓ | same UUID, rotation, audit |
| T06 | Parent rejection/cancel | ✓ | | ✓ | ✓ | ✓ | | no rotation |
| T07 | Expired approval | ✓ | | ✓ | ✓ | ✓ | | 410, unchanged |
| T08 | Unauthorized parent | | | ✓ | ✓ | | | 403, no challenge |
| T09 | Foreign-family device | | | ✓ | ✓ | | | 403/404, no change |
| T10 | Revoked device | | | ✓ | ✓ | ✓ | | 409/403, no reactivation |
| T11 | Suspended membership | | | ✓ | ✓ | | | 403 |
| T12 | Duplicate request | ✓ | | ✓ | ✓ | ✓ | | one pending, supersede |
| T13 | Concurrent requests/redeem | | | | ✓ | ✓ | | one rotation |
| T14 | Network interruption | | | | | ✓ | ✓ | no lockout |
| T15 | Server success, lost response | | | | | ✓ | ✓ | heartbeat succeeds |
| T16 | Old credential after rotation | | | | ✓ | ✓ | ✓ | 401 on all endpoints |
| T17 | New credential after rotation | | | | ✓ | ✓ | ✓ | 200 on all endpoints |
| T18 | Heartbeat after rotation | | | | | ✓ | ✓ | `last_seen_at` advances |
| T19 | Parent online status | ✓ | | | | | ✓ | Online within 12 min |
| T20 | App process restart | | ✓ | | | | ✓ | config persists |
| T21 | Child reboot | | | | | | ✓ | boot start + heartbeat |
| T22 | Audit verification | | | | ✓ | ✓ | | events once, no secrets |
| T23 | Rate limiting | | | ✓ | ✓ | ✓ | | 429 after limits |
| T24 | Challenge replay | | | ✓ | ✓ | ✓ | | no second rotation |

Additional Phase 4 scenarios (RC-25…RC-45) remain required: response-loss idempotency, revocation mid-flow, cross-family negatives, RLS/grant checks, audit-failure rollback, installation conflict, compatibility.

---

## 3. Flutter unit files

| File | Status |
|---|---|
| `test/features/devices/device_detail_controller_test.dart` | modify |
| `test/features/devices/device_recovery_controller_test.dart` | new |
| `test/features/child/child_shell_controller_test.dart` | modify |
| `test/features/child/child_recovery_controller_test.dart` | new |
| `test/features/child/child_enrollment_controller_test.dart` | modify |
| `test/data/device_model_test.dart` | modify |
| `test/data/recovery_models_test.dart` | new |
| `test/features/devices/device_presence_consistency_test.dart` | modify |
| `test/features/audit_logs/audit_logs_controller_test.dart` | modify |

Required assertions:
- no auto-recovery on load;
- payload contains `installationId` + `secretHash`, not `secret`;
- success re-runs `_ensureIdentityAndSync` with same device id;
- error mappings 403/404/409/410/429/503;
- no secret in logs/widgets.

---

## 4. Kotlin unit files

| File | Status |
|---|---|
| `android/app/src/test/kotlin/com/parentcontrol/parent_control/CredentialStateTest.kt` | new |
| `android/app/src/test/kotlin/com/parentcontrol/parent_control/GuardianErrorClassificationTest.kt` | new |

Assertions:
- secret stable across calls;
- state does not alter identity;
- 401→unconfirmed, 403 device_revoked→revoked, success→confirmed;
- restart without config returns false and creates nothing;
- process/reboot state persistence.

---

## 5. Edge unit files

| File | Status |
|---|---|
| `supabase/functions/device-register/recovery_test.ts` | new |
| `supabase/functions/family-admin/recredential_test.ts` | new |
| `supabase/functions/_shared/recovery.ts` | new production helper |
| `supabase/functions/_shared/recovery_test.ts` | new |
| `supabase/functions/_shared/validation_test.ts` | modify |
| `supabase/functions/handler_wiring_test.ts` | modify |
| `supabase/functions/family-admin/authorization_test.ts` | modify |

Assertions: role/email/membership checks, field validation, code normalization, error mapping, no secret in responses/audit metadata, action wiring order.

---

## 6. Database tests

| File | Status |
|---|---|
| `supabase/tests/80_device_recredentialing.sql` | new |
| `supabase/tests/81_device_recredentialing_races.sh` | new |
| `supabase/tests/20_fixtures.sql` | modify only if a second family/device is needed |

Required:
- execute grants service_role only;
- no RLS policies for clients;
- happy path preserves id/family/child/policy/display name;
- old hash rejected, new accepted;
- revoked rejected;
- expired/replay/idempotent;
- installation conflict rolls back;
- audit insert failure rolls back;
- sessions ended;
- concurrent redeem once;
- no active device for removed child.

---

## 7. Staging tests

Proposed script `scripts/recovery_staging_check.sh` (Gate D):
- real Edge + Postgres;
- two families;
- redacted HTTP status/body;
- public device before/after;
- audit rows;
- rate limits;
- response-loss simulation.

---

## 8. Physical E2E (Gate E/F)

Runbook under a future `docs/testing/phase_6_recovery_e2e/` (not created now):
- record build commit + APK SHA-256;
- current failure state;
- Parent approval → Child code → same UUID;
- Parent Online;
- old install fails;
- restart/reboot;
- negative/expired/replay;
- destructive recovery still works.

---

## 9. Exit criteria

- All 24 scenarios pass at required layers plus Phase 4 RC-25…RC-45.
- No secret-shaped value in logs/audit/responses.
- Device UUID, membership, policy version, history preserved.
- Concurrency rotates once.
- Compatibility matrix documented.
