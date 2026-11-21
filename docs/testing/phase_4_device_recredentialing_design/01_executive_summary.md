# 01 — Executive Summary

**Phase:** Phase 4 — Existing Child Device Re-Credentialing  
**Mode:** Read-only investigation and design. No implementation.  
**Repository:** `control` (`D:\parentcontrol_app`), branch `main`  
**HEAD at start of phase:** `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f`  
**Production project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) — not contacted  
**Date:** 2026-11-21

**Evidence labels used throughout:** `PASS` / `FAIL` / `BLOCKED` / `NOT TESTED` / `NOT IMPLEMENTED` / `REPORTED`. Every architectural claim cites repository source. No credential, hash, token, installation ID or secret value is reproduced.

---

## 1. Problem in one paragraph

A Child device that has an **active** `devices` row on the server, but has lost its local encrypted secret (uninstall, clear-data, or keystore loss), generates a **new** installation ID and a **new** secret on the next launch. The Child shell nevertheless reuses the **old** server device UUID with the **new** local secret. `device-register` refuses to replace an existing active device, and `requireDevice()` rejects every heartbeat because the new secret hash does not equal the stored `secret_hash`. `devices.last_seen_at` therefore never advances, and the Parent's client-derived presence logic keeps showing **Offline**. The family membership and all child data remain intact; only the credential binding is broken.

This is a **missing recovery capability**, not a random defect, and it is confirmed from source plus the prior two-device evidence.

---

## 2. Confirmed root cause (source-level)

| Step | Location | Finding |
|---|---|---|
| Local secret creation | `android/.../SecureStore.kt:86,94` | Installation ID and secret are created lazily when the encrypted store is empty; uninstall/clear-data deletes them. |
| Registration | `lib/features/child/controllers/child_enrollment_controller.dart:264,276` | `registerDevice()` returns "already registered" whenever a device row is already loaded. |
| Duplicate active device | `supabase/functions/device-register/index.ts:197-207` | If any active device exists for the child, registration returns `409 device_already_registered`. |
| Normal shell sync | `lib/features/child/controllers/child_shell_controller.dart:570-605` | Binds the **old** `loadedDevice.id` to the **new** local secret with no credential-match check. |
| Device auth | `supabase/functions/_shared/auth.ts:297-353` | Constant-time SHA-256 comparison; mismatch → `401 invalid_device_credentials`. |
| Heartbeat | `supabase/functions/device-telemetry/index.ts:68-83` | `last_seen_at` is written only after `requireDevice()` succeeds. |
| Parent presence | `lib/data/models/device.dart:394-457` | "Online/Offline" is derived entirely from `last_seen_at` age; no server health column. |

**Verdict:** `CONFIRMED` — the existing active device row can never be re-credentialed by a reinstall, and the relationship-preserving path does not exist.

---

## 3. What already exists, and why it does not solve this case

- `device-register` **can** rotate the secret when the `installation_id` matches the same row (`device-register/index.ts:141-194`). A reinstall changes the installation ID, so this branch is not reached.
- `family-admin recover_device` → `request_device_recovery` → `private.unlink_child` (`supabase/migrations/20260101000400_device_recovery.sql`, `20260101000100_functions.sql:325`) **revokes the device and removes the family membership**. Recovery then requires a brand-new pairing code and Child approval, creating a **new** device row and UUID. It resolves the symptom by destroying the relationship, which contradicts the Phase 4 objective.
- There is **no** parent-approved credential-rotation endpoint, **no** recovery challenge store, and **no** transaction that rotates a device credential without unlinking.

---

## 4. Recommended design (subject to owner approval)

**Option C — Parent-approved, Child-authenticated, single-use challenge, atomic rotation.**

1. A Parent (active membership in the device's family) explicitly requests credential replacement for a named, currently-active device.
2. The server issues a short-lived, single-use, attempt-limited recovery challenge bound to `(family_id, device_id, child_user_id)`.
3. The reinstalled Child app, signed in as that child with an active membership, submits the challenge together with its **new** `installation_id` and `secret_hash`.
4. A single database transaction consumes the challenge, replaces `secret_hash`/`installation_id`/`credential_issued_at` on the **same** `devices.id`, leaves `family_id`, `child_user_id`, status and history untouched, and writes an audit event.
5. The old secret stops matching immediately; the new secret works on the next heartbeat; the Parent sees the same device come Online.

This preserves the device UUID, the family relationship, and all policy/usage/telemetry history. The Child session proves account continuity but **not** physical device possession; the Parent's explicit, target-specific approval is the authorization boundary.

---

## 5. Why other options are weaker

- **A (parent approval only):** functionally converges with C because `device-register` already requires a Child JWT. Documented separately to make the two authorization factors explicit.
- **B (Child session only):** a stolen/stale Child session could seize the device identity. Rejected as a standalone boundary.
- **D (existing `recover_device`):** destroys membership and device UUID; requires re-pairing. Relationship-destructive; retained only as an explicit fallback with separate owner approval.
- **Manual hash update:** bypasses lifecycle, audit and authorization. Rejected.

---

## 6. Backend capability gap

`device-register` performs **read → check → update → audit as separate PostgREST statements**. Edge Functions hold no interactive transaction across them. Rotation therefore cannot be proven atomic today. The design requires a **new SECURITY DEFINER RPC** (Gate C) that locks the challenge and device rows, performs the rotation, and writes the audit record in one transaction. Until Gate C is approved, the design is complete but **not implementable safely**.

---

## 7. Required authorization gates (none executed)

- **Gate A** — approve this design (recommended option).
- **Gate B** — authorize source implementation (Dart/Kotlin/Edge).
- **Gate C** — authorize schema + RPC migration.
- **Gate D** — authorize deployment to a named environment.
- **Gate E** — authorize test-device credential recovery.
- **Gate F** — authorize full two-device regression testing.

Approval of one gate does not imply another.

---

## 8. Phase verdict

# **A — DESIGN COMPLETE, READY FOR OWNER DECISION**

The failure is fully explained from source; a relationship-preserving design, threat model, transaction requirement, test plan and gate matrix are complete. The only unresolved items are genuine product/owner decisions (challenge delivery UX, TTLs, parent scope, whether to also offer Child-initiated requests), recorded in `12_owner_decision_record.md`. No implementation was performed. See `12_owner_decision_record.md` for the decision package.
