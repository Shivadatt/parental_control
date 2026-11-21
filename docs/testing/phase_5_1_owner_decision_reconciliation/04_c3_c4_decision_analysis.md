# 04 — C3 and C4 Decision Analysis

**Scope:** Status/cancel actions (C3) and challenge code format (C4). No implementation.

---

# C3 — Status and cancel actions

## 1. Exact question

Should the MVP include:

- **status:** a Parent-authenticated read of the current challenge state for a device; and
- **cancel:** a Parent-authenticated action that invalidates a pending challenge before redemption?

## 2. Existing decisions that may cover it

- **D1:** short code + optional QR, out-of-band. It does not require a status endpoint.
- **D3:** any active parent. Both actions would follow the same parent scope.
- **D13:** keep destructive recovery. Not related.
- Phase 5 report `07_edge_function_api_contracts.md:137-151` marks both as optional and tied to "I3".
- Phase 5 report `09`/`10` treat cancellation as a state in the challenge lifecycle.

No approved decision requires or forbids these actions.

## 3. Option analysis

### Option A — Include both status and cancel (recommended)
**Status**
- Read-only; returns state, expiry, attempts remaining, completion time.
- Never returns the code or hash.
- Helps the Parent know whether to reissue or wait.
- Makes testing and support easier.

**Cancel**
- Parent can invalidate a leaked/misdirected code before it expires.
- Reduces the exposure window.
- Requires an atomic `pending → cancelled` transition and a race check against redeem.

**Security:** both are additive; status must not become an existence oracle for foreign families. Cancel must be family-scoped and pending-only.
**Complexity:** two extra actions, one or two extra RPCs, more tests, more audit events.

### Option B — Status only
- Lower complexity; improves UX.
- Does not let a Parent revoke a leaked code early; they must wait up to 10 minutes or issue a new challenge (which supersedes).

### Option C — Cancel only
- Reduces exposure but no visibility.
- Unusual UX; not recommended alone.

### Option D — Neither
- Smallest MVP.
- The Parent relies on expiry/supersede; a leaked code remains valid until TTL or a new request.
- Simpler Gate C (only request/attempt/redeem).

## 4. Recommendation

**Include status; include cancel unless the owner wants the absolute minimum Gate C surface.**

Rationale:
- Status is low-risk and materially improves supportability and tests.
- Cancel is a genuine security improvement for a leaked code and is cheap relative to the rest of the flow.
- If scope must shrink, status-only is the safer drop than cancel-only.

## 5. Security implications

| Risk | Status | Cancel |
|---|---|---|
| Foreign-family probing | Must require active parent in the device's family; return uniform not-found/forbidden | Same |
| Leak of code/hash | Never return either | Never return either |
| Race with redeem | Read-only; no race | Must lock the challenge and only cancel `pending`; redeem must see `cancelled` |
| Audit | Optional read audit; no need | Audit `device_recredential_cancelled` |
| Denial of service | A parent can only affect their family | A parent can cancel their own family's challenge; expected |

## 6. Operational implications

- Status enables a "waiting for phone" UI without polling the device row.
- Cancel enables a "revoke this approval" button and a clean support story.
- Both add endpoints, tests and documentation; they do **not** change the credential-rotation transaction.

## 7. Implementation dependencies

- Gate C optional RPCs `device_recredential_status` and `cancel_device_recredential`.
- Edge `family-admin` optional actions.
- Flutter Parent controller/UI.
- Audit events.
- Race test: cancel vs redeem.

## 8. Must it be decided before Gate C?

**Yes for scope:** whether Gate C includes the optional RPCs determines the migration and test surface. The security-critical core (request/attempt/redeem) is unaffected.

## 9. Can it be deferred?

**Status:** safely deferrable if the Parent UI uses "waiting for heartbeat" and expiry text.
**Cancel:** deferrable, but then a leaked code cannot be invalidated early; supersede/expiry is the only mitigation.

---

# C4 — Challenge code format

## 1. Exact question

What format should the one-time Parent→Child code use?

Current proposal: **8 characters from the existing 30-symbol unambiguous alphabet** (`23456789ABCDEFGHJKMNPQRSTVWXYZ`), reusing `PAIRING_ALPHABET`/`PAIRING_CODE_LENGTH` in `supabase/functions/_shared/validation.ts:9-11`.

**This format is not approved.** Only D1 (code + optional QR) is asserted approved; the exact format is a new decision.

## 2. Entropy calculations

For an alphabet of size 30:

| Length | Entropy `L × log2(30)` | Search space | Comment |
|---|---:|---:|---|
| 6 | 29.44 bits | 7.29×10^8 | Too weak for a credential-like code |
| **8** | **39.26 bits** | **6.56×10^11** | Proposed; same as existing pairing code |
| 10 | 49.07 bits | 5.90×10^14 | Stronger; slightly harder to read |
| 12 | 58.89 bits | 5.31×10^17 | Strong; long for manual entry |
| 8 digits (10-symbol) | 26.58 bits | 1.0×10^8 | Too weak |
| 8 base32 (32-symbol) | 40.00 bits | 1.10×10^12 | Slightly stronger; 32-symbol alphabet includes ambiguous chars unless curated |

Formula: `H = L × log2(30)`, `log2(30) ≈ 4.9069`.

## 3. Threat model for the code

- **Online guessing:** the code is only useful with a valid Child JWT and an active membership. Attempts are capped at 5 per challenge (D2) and rate-limited (C6); 39 bits is far beyond online guessing under those caps.
- **Offline guessing:** if an attacker obtains a database dump containing `code_hash`, an unsalted SHA-256 of a 39-bit code is brute-forceable at high speed. Mitigations:
  - store a **keyed** digest (HMAC with a server-side pepper), as `_shared/validation.ts` already does for pairing attempts via `identifierHash`;
  - short TTL (10 min) limits the useful window;
  - codes are single-use and family-scoped.
- **Shoulder surfing / relay:** 8 characters are easier to read aloud than 12; QR reduces transcription risk.
- **Collision:** 6.56×10^11 space; unique `code_hash` constraint; regenerate on collision (negligible).

## 4. Usability

| Format | Typing | Read-aloud | Error rate | Fits D1 |
|---|---|---|---|---|
| 8×30 | 8 chars | Good | Low (no 0/O/1/I/L) | Code + QR |
| 10×30 | 10 chars | Fair | Low | Code + QR |
| 12×30 | 12 chars | Poor | Low | QR preferred |
| 8 digits | 8 | Good | Medium | Code only |

The 30-symbol alphabet excludes `0`, `O`, `1`, `I`, `L`, reducing transcription errors.

## 5. Alternatives and trade-offs

### (a) 8×30 (recommended)
- 39.26 bits, same as existing pairing codes.
- Best usability; consistent with the product's current code UX.
- Requires keyed hashing to reduce offline-crack value.

### (b) 10×30
- 49.07 bits; materially stronger offline.
- Slightly worse UX; no QR dependency.
- Recommended if the owner wants a larger margin without a major UX change.

### (c) 12×30 or QR-only
- Strongest; manual entry becomes painful.
- QR-only excludes devices without a camera/permission; not recommended as the only path.

### (d) 6×30
- 29.44 bits; too weak. Reject.

## 6. Recommendation

**8 characters from the existing 30-symbol alphabet, with a keyed digest, plus optional QR.**

Conditions:
- store `code_hash` using HMAC/pepper, not plain SHA-256, if the deployment has a pepper (reuse `identifierHash`);
- constant-time comparison;
- unique constraint and regeneration on collision;
- 5 attempts and 10-minute TTL as approved.

If the owner prefers a larger offline margin, choose **10×30**; the rest of the design is unchanged.

## 7. Implementation dependencies

- `_shared/validation.ts` code generator/alphabet.
- Gate C `code_hash` column and unique index.
- Edge hashing (peppered).
- UI code display/input and QR.

## 8. Must it be decided before Gate C?

**Yes**, because the `code_hash` validation and unique index, and the Edge generator, depend on the length/alphabet. It does not change the table columns, only validation rules.

## 9. Can it be deferred?

**No.** The contract needs a concrete format; a placeholder would be implemented by default.
