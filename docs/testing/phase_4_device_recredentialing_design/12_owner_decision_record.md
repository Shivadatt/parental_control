# 12 — Owner Decision Record

**Phase:** Phase 4 — Existing Child Device Re-Credentialing  
**Date:** 2026-11-21  
**Status:** Awaiting owner decision. No gate granted. No implementation performed.

---

## 1. Recommendation

**Recommended option: Option C — Parent-approved, Child-authenticated, single-use challenge, atomic credential rotation.**

| Property | Decision |
|---|---|
| Preserve `family_members` | **Yes** — never touched |
| Preserve `devices.id` (UUID) | **Yes** — in-place update |
| Preserve policy/usage/location/apps/session lineage | **Yes** — same `device_id` |
| New installation ID accepted | **Yes** — replaces `installation_id` on the same row |
| Old secret invalidated | **Yes** — `secret_hash` replaced atomically |
| Who authorizes | An **active parent** in the device's family |
| Who completes | The **Child account** with an **active child** membership |
| Challenge | Single-use, ~10 min TTL, attempt-limited, server-generated |
| Rotation | New SECURITY DEFINER RPC, one transaction |
| Audit | `device_recovery_requested`, `device_recredentialed` (no secrets) |
| Automatic recovery | **Never** |
| Revoked devices | **Not eligible** |

**Why:** it is the only option that both fixes the confirmed reinstall failure and preserves the relationship, while keeping a human authorization boundary. Option B (Child session only) is rejected as unsafe. Option D (`recover_device`) is relationship-destructive and remains a separately-gated fallback.

**Explicit limitation:** app-only recovery cannot prove physical possession of the new phone. The security boundary is the Child account plus explicit Parent consent. This must be accepted by the owner.

---

## 2. Unresolved owner decisions

Each decision has a recommended default. "Deferred" means the default is adopted until changed.

| ID | Decision | Options | Recommended | Impact if wrong | Status |
|---|---|---|---|---|---|
| D1 | How the challenge reaches the Child | (a) Parent reads/shows a code; (b) in-app realtime approval; (c) QR; (d) email/SMS | **(a) + optional (c)**: short code + QR, out-of-band | (b) adds realtime/push dependency; (d) adds PII channel | **OPEN** |
| D2 | Challenge TTL and attempt cap | 5/10/15 min; 3/5/10 attempts | **10 min, 5 attempts** | Too long → replay window; too short → failed UX | **OPEN** |
| D3 | Which parents may approve | Any active parent / family owner only | **Any active parent** (consistent with revoke/recover) | Owner-only is stricter but can strand a family whose owner is unavailable | **OPEN** |
| D4 | Who initiates | Parent-only / Child requests then Parent approves | **Parent-only for MVP**; Child-initiated request as a later enhancement | Child-initiated improves UX but adds a second state machine | **OPEN** |
| D5 | Active remote sessions on rotation | Keep / end | **End** active sessions for that `device_id` (like `revoke_device`), because the old install is gone | Keeping them may leave a stale capture authorization | **OPEN** |
| D6 | `policy_version` after rotation | Keep / reset to 0 | **Keep**; the next successful ack advances it | Reset could falsely imply a policy was un-applied | **OPEN** |
| D7 | Descriptive fields on rotation | Keep old name / accept new name+platform | **Keep `display_name`; update platform/app version** unless a Parent renames | Accepting a new name enables mild spoofing inside the family | **OPEN** |
| D8 | Attempt accounting on rollback | Commit attempt first / count only committed | **Commit attempt first** (brute-force resistance) | A DB failure could consume one attempt | **OPEN** |
| D9 | Idempotent retry semantics | 200 idempotent / 409 always | **200** when `installation_id` and hash match the current row; otherwise 409 | 409-always is simpler but leaves ambiguous UI after a lost response | **OPEN** |
| D10 | Parent step-up authentication | None / re-auth / TOTP | **Defer** (audit + TTL + target confirmation first) | A compromised Parent session remains a residual risk | **OPEN** |
| D11 | Server-visible credential health for the Parent | None / new column or view | **Defer** to a separate workstream | Without it, the Parent only sees "Offline"; recovery UX relies on the challenge state | **OPEN** |
| D12 | Notify all parents on rotation | None / in-app / push | **Optional in-app audit**; push is `NOT IMPLEMENTED` | Reduces silent misuse but depends on FCM | **OPEN** |
| D13 | Keep the destructive `recover_device` action visible | Remove / keep / collapse | **Keep**, clearly labelled as unlink & re-pair | Removing it strands cases where the Child build is too old | **OPEN** |
| D14 | Whether to bundle E2E-002 fix before recovery UI | Yes / No | **No**; filter revoked rows in the recovery UI only | Bundling expands scope | **OPEN** |

---

## 3. Security acceptance checklist (owner sign-off)

- [ ] Accept that physical possession cannot be proven after secret loss.
- [ ] Accept that a compromised Parent session can authorize rotation within its family (mitigated by TTL, audit, target confirmation).
- [ ] Accept that a compromised Child account can complete a challenge if a Parent is also deceived.
- [ ] Confirm that no device secret, JWT, service key or hash may be read, logged or exported during implementation or testing.
- [ ] Confirm that recovery must never be automatic on a new installation ID.
- [ ] Confirm that revoked devices remain ineligible.
- [ ] Confirm that the destructive recovery path stays separate.

---

## 4. Decision (to be completed by owner)

```
Gate A decision:            [ ] APPROVE Option C   [ ] APPROVE WITH CHANGES   [ ] REJECT
Changes / conditions:       ______________________________________________
D1: ____  D2: ____  D3: ____  D4: ____  D5: ____  D6: ____  D7: ____
D8: ____  D9: ____  D10: ___  D11: ___  D12: ___  D13: ___  D14: ___
Owner:                      ____________________
Date:                       ____________________
Next gate requested:        [ ] B (source)   [ ] C (schema)   [ ] none yet
```

No gate may be inferred from silence. Phase 4 stops here.

---

## 5. Phase 4 completion record

### 5.1 Repository state

| Item | Before | After |
|---|---|---|
| Branch | `main` | `main` |
| HEAD | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` |
| Tracked diff | none | none (`git diff --stat` empty) |
| Untracked before | `docs/testing/device_heartbeat_root_cause_investigation/`, `docs/testing/phase_3_complete_functional_testing/`, `docs/testing/two_device_end_to_end_testing/` | same three preserved |
| Untracked after | — | the same three plus `docs/testing/phase_4_device_recredentialing_design/` |

### 5.2 Files created (12)

1. `docs/testing/phase_4_device_recredentialing_design/01_executive_summary.md`
2. `docs/testing/phase_4_device_recredentialing_design/02_existing_identity_lifecycle.md`
3. `docs/testing/phase_4_device_recredentialing_design/03_failure_point_source_evidence.md`
4. `docs/testing/phase_4_device_recredentialing_design/04_recovery_option_comparison.md`
5. `docs/testing/phase_4_device_recredentialing_design/05_security_threat_model.md`
6. `docs/testing/phase_4_device_recredentialing_design/06_backend_transaction_design.md`
7. `docs/testing/phase_4_device_recredentialing_design/07_flutter_kotlin_implementation_design.md`
8. `docs/testing/phase_4_device_recredentialing_design/08_compatibility_and_failure_recovery.md`
9. `docs/testing/phase_4_device_recredentialing_design/09_complete_recredentialing_test_plan.md`
10. `docs/testing/phase_4_device_recredentialing_design/10_related_defect_workstreams.md`
11. `docs/testing/phase_4_device_recredentialing_design/11_future_authorization_matrix.md`
12. `docs/testing/phase_4_device_recredentialing_design/12_owner_decision_record.md`

### 5.3 Confirmations

- **No source file was changed.** No file under `lib/`, `android/`, `supabase/`, `test/`, `integration_test/`, `scripts/` or `pubspec.*` was edited.
- **No migration, schema, RLS, grant or policy was created or changed.**
- **No production endpoint was invoked.** No Supabase CLI, PAT, Management API or SQL Editor was used.
- **No device credential was read, printed, generated, changed or stored.** No secret, hash, JWT or service key appears in these reports.
- **No database, account, device, family or pairing state was changed.**
- **No APK was built or installed; no device was recovered, revoked, paired or re-paired.**
- **No Git commit, checkout, merge or history rewrite was performed.**
- **All pre-existing untracked reports and unrelated changes were preserved.**

### 5.4 Evidence index (major claims)

| Claim | Evidence |
|---|---|
| Installation ID/secret are lazily created in encrypted storage | `android/.../SecureStore.kt:86-105` |
| Flutter refuses registration when a device row exists | `lib/features/child/controllers/child_enrollment_controller.dart:69,264-279` |
| Shell binds old UUID to new secret without verification | `lib/features/child/controllers/child_shell_controller.dart:570-605` |
| `device-register` rejects a second active device | `supabase/functions/device-register/index.ts:141-150,197-208` |
| Rotation exists only for the same installation ID | `supabase/functions/device-register/index.ts:152-194` |
| Device auth is constant-time SHA-256 vs `secret_hash` | `supabase/functions/_shared/auth.ts:297-353` |
| Heartbeat updates `last_seen_at` only after auth | `supabase/functions/device-telemetry/index.ts:68-83` |
| Parent presence is derived from `last_seen_at` age | `lib/data/models/device.dart:394-458` |
| Revocation nulls the hash and revokes the row | `supabase/migrations/20260101000100_functions.sql:432-500` |
| `recover_device` unlinks the child and revokes all devices | `supabase/migrations/20260101000400_device_recovery.sql`, `20260101000100_functions.sql:325-420` |
| One active device per child (partial unique index) | `supabase/migrations/20260101000000_core.sql:111-119` |
| `secret_hash`/`installation_id` are not client-readable | `supabase/migrations/20260101000200_rls.sql:255-266` |
| All device-secret endpoints | `device-telemetry/index.ts:69,158,240,358`; `device-command/handler.ts:291,310`; `remote-session/index.ts:161` |
| Parent recovery UI is destructive | `lib/features/devices/device_detail_controller.dart:156-170`; `device_detail_page.dart:159-184` |
| Re-link gate after revocation | `supabase/functions/_shared/enrollment.ts`, `device-register/index.ts:51-88` |
| Audit is fail-closed | `supabase/functions/_shared/audit.ts:17-40` |
| Rate-limit patterns | `supabase/functions/_shared/rate_limit.ts` |

### 5.5 Phase verdict

# **A — DESIGN COMPLETE, READY FOR OWNER DECISION**

**Stop point:** this record. Do not implement the recommended design. Wait for explicit owner approval of Gate A and the decisions in §2.
