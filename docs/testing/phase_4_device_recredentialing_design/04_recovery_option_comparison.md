# 04 — Recovery Option Comparison

**Purpose:** Evaluate relationship-preserving recovery alternatives against the confirmed failure, without choosing silently.  
**Mode:** Design analysis only. Nothing here is implemented.

Each option is scored on: security, relationship preservation, backend/Flutter/Kotlin change, DB impact, audit, UX, partial-failure behaviour, backwards compatibility, tests, deployment risk.

---

## 1. Evaluation criteria

| Criterion | Meaning |
|---|---|
| **Relationship preservation** | Does `family_members` stay `active` and does `devices.id` (UUID) stay the same? |
| **Authorization strength** | What proves the requester may replace this credential? |
| **Atomicity** | Can old invalidation and new activation be one transaction? |
| **Reinstall friendliness** | Works when `installation_id` and secret are both new. |
| **Account-takeover resistance** | A stolen Child session or stale session cannot silently seize the device. |
| **Operability** | Parent and Child understand what happened and what to do. |
| **Migration cost** | New table/RPC/grants/RLS and their review surface. |
| **Compatibility** | Behaviour for installed older clients. |

---

## 2. Option A — Parent-authorized re-credentialing (no explicit Child factor)

**Shape:** Parent calls a new endpoint with `device_id`; server rotates the credential directly (or issues a challenge) after verifying active parent membership.

### Strengths
- Parent is the natural data owner and already has `recover_device`/`revoke_device` authority (`family-admin/index.ts:57-121`).
- Target is a concrete `device_id` the Parent can see; no guessing.
- Preserves `devices.id` and membership if implemented as rotation, not unlink.
- Existing authorization helpers (`assertFamilyParent`, `requireActiveDeviceForParent`) are reusable (`_shared/auth.ts:212-291`).

### Weaknesses
- A Parent acting alone cannot prove the **new phone** is the intended phone; a malicious actor who controls a Child account and colludes with (or social-engineers) a Parent could claim the row.
- If the Parent rotates the hash without the Child's new secret, the server would need the Child's `secret_hash` from somewhere. A pure "Parent supplies new credential" flow would require transmitting a credential through the parent channel — unacceptable.
- Therefore Option A in practice **must** also require the Child to submit its new secret, which makes it Option C. Standalone A is only safe if the Parent triggers a challenge that the Child redeems.

### Required changes (if pursued)
- Backend: new parent endpoint + challenge + atomic RPC.
- Flutter (Parent): approval UI.
- Flutter (Child): challenge entry.
- Kotlin: none beyond existing identity plumbing.
- DB: recovery-challenge table + RPC.
- Audit: `device_recovery_requested`, `device_recredentialed`.
- UX: Parent initiates; Child completes.
- Partial failure: same as C.
- Compatibility: old Child builds cannot complete it → Parent sees "waiting".
- Deployment risk: medium (new endpoint + migration).
- Tests: same as C.

**Verdict:** not independently viable; it collapses into C once the Child must supply the new hash.

---

## 3. Option B — Child authenticated-session-assisted recovery

**Shape:** The reinstalled Child app, signed in as the child, calls a `recredential` action with its new `installation_id`/`secret_hash`; server verifies only the Child JWT + active membership + row ownership.

### Strengths
- Simplest UX: reinstall → sign in → automatic repair.
- Child JWT is already required for `device-register` (`requireUser` + `requireRole('child')`), so the plumbing exists.
- Preserves UUID and relationship if implemented as an update.
- No new table strictly required (could extend `device-register`), although audit/rate-limit state would be thin.

### Weaknesses (decisive)
- **A Child session is not proof of physical device ownership.** Anyone with the Child's credentials (shared password, stolen refresh token, a second phone signed into the same account) could replace the credential and receive the device's commands/data.
- **Session theft / stale session:** a long-lived refresh token on another device can silently take over.
- **Device impersonation:** the "new" device would inherit policy, location history and remote-assistance eligibility without any guardian awareness.
- **No human confirmation** of the target device.
- Conflicts with the existing security posture: revoked-device re-enrollment already requires a **later parent-approved pairing** (`assertReenrollmentAllowed`, `device-register/index.ts:51-88`). Allowing child-only rotation would be a weaker path than the already-guarded revoked path.

### Required changes
- Backend: allow `device-register` to update an existing active row when the child JWT matches.
- Flutter/Kotlin: minimal.
- DB: none.
- Audit: `device_recredentialed` only.
- UX: silent/automatic.
- Partial failure: retryable, but no way to distinguish a legitimate reinstall from a takeover.
- Compatibility: works for old clients only if they are updated to call it.
- Deployment risk: low technically, **high security risk**.

**Verdict:** **Rejected as a standalone boundary.** It may remain as the *transport* the Child uses after a Parent has authorized, never as the authority itself.

---

## 4. Option C — Parent approval **and** Child authentication (recommended)

**Shape:** Two factors with different powers:
- **Parent approval** authorizes *which device may be re-credentialed*.
- **Child authenticated session** proves *the account continuity* and supplies the *new secret hash*.
- A **single-use, expiring, attempt-limited challenge** binds the two, and one RPC rotates atomically.

### Strengths
- Preserves `devices.id`, `family_id`, `child_user_id`, policy history, usage, location and remote-session lineage.
- Old secret is invalidated implicitly by replacing `secret_hash` (one field, all seven endpoints).
- Parent explicitly sees and confirms the target device (name + platform + last seen).
- Child must be the legitimate account holder with an **active** membership in that family.
- Challenge is short-lived and single-use → replay-resistant.
- Rate limiting limits abuse.
- Audit records both the request and the completion, without secrets.
- A revoked device is **not** eligible (status must be `active`), so it cannot silently become active.
- Fits existing security patterns (`requireUser`, `assertFamilyParent`, `requireActiveDeviceForParent`, service-role-only RPC, audit-on-failure-of-write).

### Weaknesses
- Still cannot cryptographically prove physical possession after secret loss; that is inherent to app-only recovery. The boundary is account + guardian consent.
- Requires a new table + RPC + grants + RLS + Edge action (Gate C).
- Parent must be reachable during recovery; UX needs a "waiting for guardian" state.
- New challenge lifecycle must be correct (expiry, attempts, concurrency).
- Two clients must agree on the target device; a compromised Parent session is still a risk (mitigated by audit, notifications, and short TTL).

### Required changes
- **Backend (Edge):** new `device-register` action (`recovery_request` by parent? or a dedicated `device-recovery` function) and `recovery_complete` by child; the parent-triggered path can live in `family-admin` or a new function.
- **Backend (DB, Gate C):** `device_recovery_challenges` table; `private.request_device_recovery_challenge(...)`; `private.redeem_device_recovery_challenge(...)`; public wrappers; grants to `service_role` only; RLS (no client policies; service-only).
- **Flutter (Parent):** device-detail "Replace credential" + confirm target + show challenge code/status.
- **Flutter (Child):** detect unconfirmed credential, show "Approval required", accept code, call completion, re-sync.
- **Kotlin/native:** none required for the core flow; optional: expose a non-secret `credentialState` and force a sync reconfiguration after completion.
- **Audit:** request, denied attempt, completion, expiry cleanup; metadata contains IDs and reason codes only.
- **UX:** explicit two-sided confirmation; no automatic recovery on new installation ID.
- **Partial failure:** see report 08; idempotent completion + heartbeat as the recovery oracle.
- **Compatibility:** old Child builds cannot complete; they see the current 401 and generic error. Old Parent builds simply lack the new button. Server behaviour for all existing actions is unchanged.
- **Deployment risk:** medium. New table is additive; no existing column changes; RPC must be reviewed for locking and grants.
- **Tests:** full matrix in report 09.

**Verdict:** **Recommended.**

---

## 5. Option D — Existing `recover_device` / re-pair workflow

**Shape:** Parent presses "Start device recovery" (`device_detail_page.dart:177`, `device_detail_controller.dart:156`) → `family-admin recover_device` → `request_device_recovery` → `unlink_child`.

### Exact effects (source)
`private.unlink_child` (`20260101000100_functions.sql:325-420`):
- `family_members.status = 'removed'`, `removed_at = now()`;
- **all** child devices: `status='revoked'`, `secret_hash=NULL`, `credential_revoked_at=now()`;
- active `remote_sessions` ended;
- active `device_pairing_tokens` revoked;
- pending `pairing_requests` cancelled;
- audit `member_removed`.

`request_device_recovery` adds audit `device_recovery_started` and returns `{recovery:'started', old_device_id}`.

### Relationship impact
- The **membership row is removed**, not merely the credential.
- The device UUID is retained but revoked; a **new** device row/UUID is created after re-pairing.
- All device-scoped history stays attached to the old row, which is exactly what E2E-002 currently mis-renders as a second "current" device.
- Re-linking requires a fresh one-time code, Parent redemption, and Child approval (`pairing/index.ts`), plus `assertReenrollmentAllowed` requires approval **after** revocation (`enrollment.ts` `requiresRelink`).

### Strengths
- Already implemented, tested (`supabase/tests/45_device_recovery.sql`) and authorized for parents.
- Cleanly invalidates the old credential.
- No new schema.

### Weaknesses
- **Destroys the family relationship and device identity**, contradicting the Phase 4 objective.
- Requires physical/logistical cooperation and a new pairing cycle.
- Produces a second device row; worsens the E2E-002 presentation defect until that workstream lands.
- Any remote session / pending state is cancelled.
- Cannot be made relationship-preserving without effectively becoming Option C (a new non-unlinking RPC).

### Can it be made preserving?
Yes, but only by adding a **separate** mode that does **not** call `unlink_child`: revoke/rotate only the credential on the same row. That is a new operation with its own authorization and audit — i.e. Option C. Changing `recover_device` itself to preserve membership would alter an existing, approved, tested contract and is not recommended.

### Assessment
| Criterion | Result |
|---|---|
| Relationship preservation | **No** |
| Device UUID preservation | **No** (new row after re-pair) |
| Reinstall friendliness | Yes, but with re-pairing |
| Security | Good (parent-approved) |
| Cost | Low (exists) |
| UX | Heavy |

**Verdict:** acceptable only as an explicitly approved fallback, not the primary remediation.

---

## 6. Manual database hash update (rejected)

Replacing `devices.secret_hash` with a hash of the current device secret:
- requires extracting/deriving a secret into an admin channel;
- bypasses authorization, audit and rate limits;
- is unreproducible and unauditable;
- violates the Phase 4 prohibitions.

**Verdict:** rejected. Not an option.

---

## 7. Comparison matrix

| Criterion | A (Parent only) | B (Child only) | C (Parent + Child) | D (recover_device) |
|---|---|---|---|---|
| Preserves family membership | Yes* | Yes* | **Yes** | No |
| Preserves device UUID | Yes* | Yes* | **Yes** | No |
| Reinstall-friendly | Yes* | Yes | **Yes** | Yes (via re-pair) |
| Parent approval | Yes | No | **Yes** | Yes |
| Child session | Required in practice | Yes | **Yes** | Yes (after re-link) |
| Physical-possession proof | No | No | **No (documented limit)** | No |
| Account-takeover resistance | Medium | **Low** | **High** | High |
| Revoked device protected | Yes | Needs guard | **Yes** | Yes |
| Old credential invalidated | Yes | Yes | **Yes** | Yes |
| Atomic rotation possible | With RPC | With RPC | **With RPC** | Yes (existing) |
| New DB object | Yes | No | **Yes** | No |
| Audit | Yes | Thin | **Full** | Yes |
| UX | Medium | Easiest | Medium | Heavy |
| Deployment risk | Medium | Low/High | **Medium** | Low |
| Meets Phase 4 objective | Partly | Partly | **Yes** | **No** |

`*` only if implemented as rotation; standalone A is not independently viable.

---

## 8. Recommendation

Adopt **Option C** with these explicit properties:

1. Parent **initiates** for a named active device in their family.
2. Server issues a **single-use challenge** bound to `(family_id, device_id, child_user_id)`, ~10 minute TTL, max 5 attempts.
3. Child (new install, signed in, active membership) **completes** with `installation_id` + `secret_hash`.
4. **One RPC** consumes the challenge and rotates the credential on the **same** row; audit both sides.
5. Old secret stops working at commit; next heartbeat proves success; no automatic recovery occurs merely because a new installation ID is seen.

Option D remains the documented, separately-gated fallback when the Parent cannot or will not approve in-app.

**No option was implemented.**
