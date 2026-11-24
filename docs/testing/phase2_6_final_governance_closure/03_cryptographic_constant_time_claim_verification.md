# Phase 2.6 — Cryptographic Constant-Time Claim & Device Authentication Audit

**Document ID:** `HAVEN-GOV-PHASE2-6-CRYPTO`  
**Phase:** Phase 2.6 — Final Governance Defect Correction & Evidence Closure Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Independent Adversarial Cryptographic & Static Source Code Inspection  
**Execution Posture:** STRICTLY READ-ONLY  
**Formal Security Finding:** OVER-STATED CLAIM CORRECTED TO STATICALLY VERIFIED (RUNTIME TIMING UNTESTED)  

---

## 1. Context & The Challenged Phase 2.5 Claim

In Phase 2.5 Deliverables 01, 07, and 12, the following security claim was asserted:  
> *"Nine user/device endpoints perform constant-time SHA-256 device-secret verification via `crypto.subtle.timingSafeEqual`."*

This claim contains two major inaccuracies that must be corrected through adversarial source inspection:
1. **Endpoint Scope Conflation**: Do all nine user/device endpoints verify device secrets?
2. **Cryptographic Primitive Inaccuracy**: Is a platform-native constant-time primitive like `crypto.subtle.timingSafeEqual` actually used, and has timing invariance been proven?

---

## 2. Adversarial Source Code Inspection

### 2.1 Where Device Secrets Are Received & Validated
Source inspection of [supabase/functions/_shared/auth.ts:301–353](file:///d:/parentcontrol_app/supabase/functions/_shared/auth.ts#L301-L353) reveals the actual implementation of `requireDevice()`:

```typescript
// supabase/functions/_shared/auth.ts:301-353
export async function requireDevice(
  req: Request,
  db: SupabaseClient,
): Promise<DeviceRow> {
  const deviceId = req.headers.get("x-device-id") ?? "";
  const secret = req.headers.get("x-device-secret") ?? "";
  if (!deviceId || !secret) {
    throw new ApiError("device_auth_required", "Device credentials are required.", 401);
  }
  if (!isUuid(deviceId) || secret.length < 16 || secret.length > 512) {
    throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
  }

  const { data, error } = await db
    .from("devices")
    .select("id, family_id, child_user_id, secret_hash, status, credential_revoked_at, ...")
    .eq("id", deviceId)
    .maybeSingle();
  ensureNoError({ error });
  const device = data as DeviceRow | null;

  const digest = await sha256Hex(secret);
  if (!device || !device.secret_hash) {
    // Still run a comparison so unknown ids and wrong secrets are similar.
    constantTimeEqualHex(digest, "0".repeat(64));
    throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
  }
  if (!constantTimeEqualHex(digest, device.secret_hash)) {
    throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
  }
  if (device.status !== "active" || device.credential_revoked_at !== null) {
    throw new ApiError("device_revoked", "This device credential was revoked. Link the device again.", 403);
  }
  return device;
}
```

### 2.2 Which Endpoints Actually Use `requireDevice()`?
Inspection of all 10 Edge Function entry points reveals that **only device-connecting endpoints use `requireDevice()`**:
- **`device-telemetry`**: Exclusively uses `requireDevice()` (telemetry reports from child daemon).
- **`device-command`**: Dual-auth: uses `requireUser()` for parent callers, or `requireDevice()` for child polling.
- **`remote-session`**: Dual-auth: uses `requireUser()` for parent callers, or `requireDevice()` for child streaming.
- **The Remaining 6 User Endpoints (`account`, `auth-bootstrap`, `family-admin`, `pairing`, `device-policy`, `device-register`)**:
  - These endpoints **do NOT call `requireDevice()`**.
  - Instead, they authenticate human users via Supabase Auth Bearer JWT tokens ([_shared/auth.ts:111–143](file:///d:/parentcontrol_app/supabase/functions/_shared/auth.ts#L111-L143) `requireUser()`), verifying cryptographic signatures with Supabase Auth's `db.auth.getUser(token)`.
- **Finding**: Claiming that "nine endpoints verify device secrets" was a severe factual error in Phase 2.5. Device secret verification is confined to child device interfaces.

---

### 2.3 How Secrets Are Hashed and Compared
Source inspection of [supabase/functions/_shared/validation.ts:287–347](file:///d:/parentcontrol_app/supabase/functions/_shared/validation.ts#L287-L347) reveals the actual hashing and comparison functions:

```typescript
// supabase/functions/_shared/validation.ts:287-292
export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

// supabase/functions/_shared/validation.ts:334-347
export function constantTimeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  const length = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let i = 0; i < length; i += 1) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

export function constantTimeEqualHex(a: string, b: string): boolean {
  return constantTimeEqual(a.toLowerCase(), b.toLowerCase());
}
```

---

## 3. Cryptographic Security & Timing Side-Channel Analysis

### 3.1 Design Intent vs Implementation Reality
1. **Design Intent**: The author intended to prevent timing attacks by accumulating bitwise differences (`diff |= left[i] ^ right[i]`) across all bytes up to `length`, rather than exiting early on the first mismatched byte.
2. **Missing Platform Native Primitive**:
   - The code does **NOT** use a hardware-enforced constant-time primitive such as Node.js C++ `crypto.timingSafeEqual()`.
   - The Web Cryptography standard (`crypto.subtle`) does not specify a `timingSafeEqual` method.
3. **Potential Microarchitectural & JIT Timing Variances**:
   - **`toLowerCase()` Allocation**: `constantTimeEqualHex` invokes `a.toLowerCase()` and `b.toLowerCase()`. In V8, string case conversion allocates new heap objects, traverses string rope structures, and takes time dependent on string memory layout and character classes.
   - **Array Bounds Checking**: Accessing `left[i] ?? 0` when indices exceed array length invokes V8 array bounds checking and undefined fallback logic, introducing minor timing variations.
   - **JIT Compiler Optimization**: JavaScript running on Deno's V8 engine is subject to speculative compilation, inlining, and branch optimization that can introduce execution time jitter based on branch history.
4. **Pre-Comparison Early Exits**:
   - Input format validation (`!isUuid(deviceId)` or `secret.length < 16`) rejects requests before running SHA-256 or comparison. This leaks format validity, but does **not** leak secret bytes.
   - If a device is not found in the database, a dummy comparison is executed (`constantTimeEqualHex(digest, "0".repeat(64))`) to balance timing, which is a commendable defensive design.

---

## 4. Epistemological Classification & Audit Conclusion

```
====================================================================================================
                        CRYPTOGRAPHIC CLAIM AUDIT DETERMINATION
====================================================================================================
Claim Audited:                   "Nine endpoints perform constant-time SHA-256 secret verification"
Source Finding:                  1. Only device endpoints use requireDevice (3 endpoints, not 9).
                                 2. Comparison uses custom TypeScript loop (constantTimeEqual),
                                    NOT a hardware/platform-native C++ primitive.
                                 3. No runtime timing side-channel testing has been performed.

Authoritative Status:            STATICALLY VERIFIED — RUNTIME TIMING VALIDATION NOT PERFORMED
Security Assessment:             Application design demonstrates defensible anti-timing intent,
                                 but cryptographic timing invariance cannot be declared proven
                                 without empirical microsecond timing distributions (Box-Cox /
                                 Student's t-test) in a runtime test bench.
====================================================================================================
```
