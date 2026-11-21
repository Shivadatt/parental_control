# 10 — Remediation Options and Authorization Requirements

**Date:** 2026-11-21  
**Status:** proposal only — **no remediation is authorized or performed in this phase**  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Diagnosis to remediate

The active device row and the current installation disagree about the device secret:

- server: old `secret_hash` + old `installation_id` from the pre-2026-11-17 install;
- child: new local secret + new installation ID, stored in the current install;
- shell: reuses the old server device ID with the new secret;
- backend: rejects the mismatch, so `last_seen_at` never advances.

Any fix must either **restore the matching credential** or **re-issue the server credential for the same device row**, without losing the family relationship.

---

## 2. Options

### Option 1 — Add a safe re-credentialing path (recommended)

**Goal:** let the existing child account, already an active member of the family, replace the stale credential for its own active device after a reinstall/data loss.

**What would change:**

- Child shell detects that the server has an active device for this child but the local credential has never been confirmed.
- A new explicit action (e.g. `device-register` `recredential`, or an allowed `register` path) updates `secret_hash`, `installation_id`, `credential_issued_at` on the existing active row.
- The server requires:
  - a valid child user session with verified email,
  - active membership in the device’s family,
  - the device row belongs to that child,
  - no other active device is being silently replaced,
  - rate limiting and an audit event (`device_recredentialed`).
- The child UI confirms the re-credential explicitly (not silent).

**Pros:** preserves family and device row; fixes the real-world reinstall case; no parent action.

**Cons:** requires source, backend and deployment work; must be designed to prevent credential takeover.

**Risk:** medium. The user-session requirement is strong but the endpoint must not become a way for a second device to seize the row.

**Authorization needed:** source change, tests, Edge Function deployment, build/install, device QA.

---

### Option 2 — Owner-approved device recovery + re-pair

Use the existing `family-admin recover_device` path:

- It unlinks the child, revokes the device row, clears `secret_hash`, and ends sessions.
- The parent then creates a new pairing request, and the child approves it.
- A new device row and credential are created.

**Pros:** uses existing, tested server behavior; cleanly restores a working credential.

**Cons:** **destroys the existing relationship**, requires parent action, a new pairing code, and child approval. The current phase prohibits this.

**Risk:** low technically, high relationally.

**Authorization needed:** explicit owner approval for unlink/re-pair, plus confirmation that preserving the current family is not required.

---

### Option 3 — Manual database secret update

Replace `devices.secret_hash` with the hash of the current device secret.

**Why not recommended:**

- Requires extracting or deriving a device secret into an administrative channel.
- Bypasses the normal credential lifecycle and audit.
- Easy to get wrong and hard to reproduce.
- The phase explicitly prohibits database writes and secret handling.
- It fixes one device but leaves the reinstall defect for every future user.

**Authorization needed:** database write approval, secret-handling approval, audit and rollback plan. Not recommended.

---

### Option 4 — Do nothing

**Effect:** the parent remains blind to the running child indefinitely. The child can read family data but cannot report heartbeat, usage, location, apps or command acknowledgements.

**Acceptable only as a temporary state** until one of the above is authorized.

---

## 3. Recommended sequence

1. **Confirm the 401 non-destructively (no code change).**
   - Owner opens the child Settings / diagnostic area that shows `guardian.lastError`, or an owner-approved read-only server log query is performed.
   - Do not extract the device secret or secure preferences.
   - Expected safe message: “Heartbeat failed: Device credentials are not valid.”
2. **Decide the product behavior for reinstall/data loss.**
   - Recommended: explicit child-approved re-credential for the same device row.
3. **Implement with regression tests.**
   - Fresh install + existing active device + same child session → heartbeat succeeds and `last_seen_at` advances.
   - Wrong/old secret → 401, old credential not silently accepted.
   - Different child/session → forbidden.
   - Revoked device → cannot be re-credentialed without re-enrollment.
   - Duplicate active device → rejected.
4. **Deploy, rebuild and re-run the two-device test.**
   - Record APK hash and build commit.
   - Verify parent shows Online within one heartbeat window.
5. **Then close E2E-002/003/004** as separate UI/query fixes.

---

## 4. Authorization checklist for the remediation phase

| Item | Required approval |
|---|---|
| Dart/Kotlin source changes | Explicit implementation grant |
| Supabase Edge Function change/deploy | Separate deployment approval |
| Database migration (if any) | Schema-change approval + rollback plan |
| APK build | Owner-run or approved build |
| APK install on child | Explicit device-change approval |
| Device recovery / re-pair (Option 2) | Explicit relationship-change approval |
| Log inspection on hosted project | Read-only access approval, redacted output |
| Credential extraction | **Not authorized** |

---

## 5. What must not be done as a shortcut

- Do not clear app data or uninstall/reinstall to “see if it fixes itself.”
- Do not regenerate the secret blindly.
- Do not disable device authentication.
- Do not make `requireDevice` accept missing/mismatched secrets.
- Do not update `secret_hash` from a client-supplied value without child/session/family authorization.
- Do not use the parent’s `recover_device` button silently in the background.
- Do not claim the fix works from a 200 response alone; verify `last_seen_at` on the parent and a fresh child timestamp.

---

## 6. Remediation verdict

**No remediation performed.** The recommended path is a scoped, child-approved re-credentialing flow (Option 1), with Option 2 as the existing but relationship-destructive fallback. Both require new authorization.
