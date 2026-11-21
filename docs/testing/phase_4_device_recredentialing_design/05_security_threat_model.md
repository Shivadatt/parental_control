# 05 — Security Threat Model and Requirements Enforcement

**Design under analysis:** Option C — parent-approved, Child-authenticated, single-use challenge, atomic rotation (report 04).  
**Mode:** Design analysis. No control is claimed as implemented; each is mapped to the exact enforcement point the implementation must have.

**Evidence labels:** `ENFORCED-BY-DESIGN` (mechanism fully specified and feasible with existing primitives), `REQUIRES-NEW-CODE` (mechanism depends on code not yet written), `EXISTING-CONTROL` (already in repository).

---

## 1. Assets and adversaries

### Assets
- Device credential binding (`devices.secret_hash` + `devices.installation_id`).
- The family relationship (`family_members`).
- Device-scoped data: policy, usage, location, alerts, reported apps, remote-assistance eligibility.
- Audit integrity (who authorized what, when).
- Child account session.

### Adversaries
| ID | Adversary | Capability |
|---|---|---|
| T1 | Foreign Parent | Authenticated parent of another family |
| T2 | Removed/Suspended Parent | Previously active parent, now `removed` |
| T3 | Child-account thief | Knows/steals Child credentials, not physical device |
| T4 | Malicious second device on Child account | Signed into the Child account concurrently |
| T5 | Network attacker | Reads/modifies traffic (TLS assumed; still validate) |
| T6 | Replay attacker | Captures a recovery code/response |
| T7 | Brute-forcer | Guesses challenge codes |
| T8 | Curious operator/DB reader | Reads tables/audit/logs |
| T9 | Compromised Parent session | Valid Parent JWT used maliciously |
| T10 | Revoked device owner | Wants a revoked row reactivated silently |

Explicit non-goal: proving physical possession of the new phone after secret loss is **not** solvable with app-only factors. The design states this limitation rather than pretending otherwise.

---

## 2. Threat scenarios and mitigations

| # | Scenario | Mitigation in the design | Class |
|---|---|---|---|
| S1 | T1 (foreign parent) calls recovery for someone else's device | Server derives `family_id` from the **device row**, then requires `assertFamilyParent(actor, device.family_id)`; no client-supplied family is trusted. Existing helper does exactly this (`_shared/auth.ts:212-231`, `258-291`). | `EXISTING-CONTROL` reused |
| S2 | T2 removed parent tries | `loadMembership` filters `status='active'` (`_shared/auth.ts:207-217`); `assertFamilyParent` fails. | `EXISTING-CONTROL` |
| S3 | Target is in another family | RPC reloads the device by id and re-checks the actor's active parent membership against **that** row's family; a foreign device id yields `403 forbidden`, not a silent success. Mirrors `request_device_recovery` (`20260101000400_device_recovery.sql:29-40`). | `REQUIRES-NEW-CODE` (new RPC) |
| S4 | T10 revoked device silently reactivated | Recovery **requires `devices.status='active'`** and `credential_revoked_at IS NULL`. Revoked rows are never eligible; they still need the existing re-link gate (`device-register/index.ts:51-88`). | `REQUIRES-NEW-CODE` (explicit guard) |
| S5 | Old credential keeps working | Rotation replaces `secret_hash` in the same transaction. `requireDevice()` compares against the current hash only (`_shared/auth.ts:328-343`), so the old secret fails immediately after commit. No second credential column, no grace credential. | `ENFORCED-BY-DESIGN` |
| S6 | Rotation half-applied | Single RPC: consume challenge + update device + audit in one transaction; `FOR UPDATE` locks. If any step raises, the transaction rolls back and the old credential remains valid (no lockout). | `REQUIRES-NEW-CODE` (report 06) |
| S7 | Duplicate requests | Challenge row unique per pending request (partial unique index on `device_id` where `consumed_at IS NULL`); completion is idempotent for the same `installation_id` + matching current hash. | `REQUIRES-NEW-CODE` |
| S8 | Challenge replay | `consumed_at` set in the same transaction that rotates; a second redemption finds it consumed and returns `409 recovery_already_used` unless it is the documented idempotent retry. | `REQUIRES-NEW-CODE` |
| S9 | Guessable challenge | High-entropy code (≥ 8 chars from a 32-char alphabet, or a 128-bit random token in QR), stored only as SHA-256; constant-time compare; per-challenge `attempts`/`max_attempts`; per-actor rate limit. Reuse the `pairing_attempts` pattern (`_shared/rate_limit.ts`). | `REQUIRES-NEW-CODE` |
| S10 | Challenge never expires | `expires_at` (~10 min) checked in the RPC; expired challenges are rejected and swept. | `REQUIRES-NEW-CODE` |
| S11 | Brute force across devices | Per-parent and per-challenge attempt caps over a rolling window, plus per-child pending cap. Modeled on `assertPairingRedeemAllowed` (`rate_limit.ts:54-105`). | `REQUIRES-NEW-CODE` |
| S12 | T3/T4 second phone on Child account | Child session alone never authorizes; Parent must approve a **specific device** and the challenge is bound to `device_id` + `child_user_id`. The Parent UI shows name/platform/last-seen for confirmation. Residual risk documented. | `ENFORCED-BY-DESIGN` |
| S13 | T9 compromised parent JWT | Short TTL, single-use, audit, and an explicit target confirmation; optionally notify all parents. Residual risk cannot be eliminated without step-up auth (owner decision). | `REQUIRES-NEW-CODE` + `OWNER DECISION` |
| S14 | T5/T6 replay of HTTP response | No secret is returned in the completion response; the Child already holds the new secret locally. Replay of a completion body cannot rotate again because the challenge is consumed. Idempotent retry compares `installation_id` only after the Child proves possession by sending its secret hash. | `ENFORCED-BY-DESIGN` |
| S15 | T8 reads audit/logs | Audit metadata stores IDs, reason codes and timestamps only: never `secret_hash`, raw secret, JWT, or challenge code. `recordAudit` already fails the request if the insert fails (`_shared/audit.ts:17-40`). | `REQUIRES-NEW-CODE` (metadata discipline) |
| S16 | T8 reads challenge table via API | Table has **no** client policies and **no** grants to `anon`/`authenticated`; only `service_role` (as `device_pairing_tokens` is service-only, `20260101000200_rls.sql:73`). | `REQUIRES-NEW-CODE` |
| S17 | RLS leak of `secret_hash` | Devices column grants already exclude `secret_hash`/`installation_id` (`20260101000200_rls.sql:255-266`). The new table must follow the same column discipline. | `EXISTING-CONTROL` (pattern) |
| S18 | Child loses the challenge code | Parent can re-issue a new challenge; old pending one is superseded. No permanent lockout. | `REQUIRES-NEW-CODE` |
| S19 | Recovery used to hijack a healthy device | Rotation requires a Parent-initiated challenge; there is no automatic path. A Child cannot self-trigger recovery on a new install. | `ENFORCED-BY-DESIGN` |
| S20 | Revoked/suspended membership child | `assertChildMembership` requires active child membership in the **challenge's** family; a removed child cannot complete. | `EXISTING-CONTROL` reused |
| S21 | Cross-family challenge confusion | Challenge stores `family_id`, `device_id`, `child_user_id`; completion requires all three to match the JWT/row. No client-supplied family is trusted. | `REQUIRES-NEW-CODE` |
| S22 | Remote session left open from old install | Optional: on rotation, end active `remote_sessions` for that device (like `revoke_device` does) or leave them; **owner decision**. If left, they are still bound to the same device UUID. | `OWNER DECISION` |
| S23 | Recovery while device is heartbeating (not lost) | Parent may still initiate; rotation invalidates the old install, which then fails. This is an intentional "replace phone" capability but must be confirmed in the Parent UI. | `ENFORCED-BY-DESIGN` |
| S24 | Database migration widens privileges | New RPCs are `SECURITY DEFINER` with `SET search_path`, `REVOKE ALL FROM public, anon, authenticated`, `GRANT EXECUTE TO service_role` only, matching `20260101000400_device_recovery.sql:85-88` and phase-1 authorization hardening. | `REQUIRES-NEW-CODE` (review gate) |

---

## 3. The fourteen required properties, and how each is enforced

| # | Requirement | Enforcement point (design) | Class |
|---|---|---|---|
| R1 | Only an authorized parent may approve recovery for a device in their **active** family | Parent JWT verified by `requireUser`; device row loaded by id; `assertFamilyParent(actor, device.family_id)` requires active `parent` membership. Membership is derived from the **device**, not the request. | `EXISTING-CONTROL` reused |
| R2 | A foreign family cannot recover another family's device | Same check as R1; the RPC reloads family from `devices.family_id`. Foreign device id → `403`, no oracle beyond existence (return a uniform `device_not_found_or_forbidden` if desired). | `REQUIRES-NEW-CODE` |
| R3 | A revoked device cannot silently become active | Completion requires `status='active' AND credential_revoked_at IS NULL`; revoked path stays under `assertReenrollmentAllowed`, which needs a later approved pairing. | `REQUIRES-NEW-CODE` |
| R4 | Old credential stops working after rotation | `secret_hash` is replaced atomically; `requireDevice` compares only the current hash. | `ENFORCED-BY-DESIGN` |
| R5 | A failed rotation must not leave the device unusable | One transaction; challenge consumption and device update commit together or roll back. Failure leaves the old credential valid. The Child can retry with the same or a new challenge. | `REQUIRES-NEW-CODE` |
| R6 | Duplicate requests are safe/idempotent | Partial unique index for one pending challenge per device; completion idempotent when `installation_id` matches and the presented secret hashes to the current `secret_hash`; otherwise `409`. | `REQUIRES-NEW-CODE` |
| R7 | Challenges expire | `expires_at` set by server (~10 min); checked inside the RPC under lock. | `REQUIRES-NEW-CODE` |
| R8 | Challenges are single-use | `consumed_at` set in the same transaction as rotation; replay rejected. | `REQUIRES-NEW-CODE` |
| R9 | Rate limits prevent repeated abuse | (a) max attempts per challenge, (b) max failed completions per child/parent per window, (c) max pending challenges per device/child. Reuse `rate_limit.ts` patterns; counts stored server-side. | `REQUIRES-NEW-CODE` |
| R10 | Auditable without logging credentials | Audit events `device_recovery_requested`, `device_recovery_denied`, `device_recredentialed`, `device_recovery_expired`; metadata = ids, reason codes, timestamps, optional hashed installation fingerprint. No secret/hash/code. `recordAudit` fails closed. | `REQUIRES-NEW-CODE` |
| R11 | Membership and ownership unchanged | The rotation updates only `devices` columns; it never touches `family_members`, `families`, `devices.family_id`, or `devices.child_user_id`. Verified by an integration assertion. | `REQUIRES-NEW-CODE` |
| R12 | Child receives clear feedback when approval is required | Child shell detects "server active device exists but local credential unconfirmed" (a non-secret local flag plus a failed heartbeat/auth probe) and shows "A guardian must approve this phone". No silent recovery. | `REQUIRES-NEW-CODE` |
| R13 | Parent sees explicit confirmation of the target device | Parent UI shows device name, platform, last-seen and asks for an explicit confirm before issuing a challenge; the challenge is bound to that `device_id`. | `REQUIRES-NEW-CODE` |
| R14 | No automatic recovery merely because a new installation ID is seen | The Child cannot initiate a rotation; only a Parent-issued challenge enables it. A new `installation_id` is never sufficient. | `ENFORCED-BY-DESIGN` |

---

## 4. Residual risks (must be recorded, not hidden)

1. **No physical-possession proof.** Account + guardian consent is the ceiling for app-only recovery after secret loss.
2. **Compromised Parent session** can authorize rotation for a device in their family. Mitigations: short TTL, audit, optional multi-parent notification, optional step-up re-auth (owner decision).
3. **Child account theft** can complete a challenge if the Parent is also deceived. The Parent's target confirmation and out-of-band code delivery reduce this.
4. **Side channels on device existence.** A foreign parent probing `device_id` may learn existence via error timing/status unless responses are uniform; the design recommends a uniform `not_found_or_forbidden` response.
5. **Challenge delivery UX.** If the code is shown only on the Parent screen, the Parent must read it to the Child; if delivered by push/realtime, the security properties depend on that channel. This is an owner decision (report 12).
6. **Historical revoked rows** remain visible until E2E-002 is fixed (report 10); they are not eligible for recovery.

---

## 5. Security verdict

**Design-level security is sound for the stated threat model**, with the explicit limitation that physical possession cannot be proven. Every one of the fourteen required properties has a concrete enforcement point. Most authorization primitives already exist and are tested; the new code surface is a challenge table, two RPCs and thin Edge handlers, all of which must pass Gate C review.

No security control was implemented in this phase.
