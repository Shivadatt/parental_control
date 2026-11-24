# Phase 2.7 — Cryptographic Constant-Time Claim Final Evidentiary Audit

**Document ID:** `HAVEN-GOV-PHASE2-7-CRYPTO-FINAL`  
**Phase:** Phase 2.7 — Final Residual Governance Corrections & Owner Authorization Lock Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Deep-Dive Cryptographic Code Analysis & Timing Invariance Audit  
**Execution Posture:** STRICTLY READ-ONLY — ZERO RUNTIME TIMING EXPERIMENTS  
**Epistemological Verdict:** IMPLEMENTATION PATTERN INSPECTED — CONSTANT-TIME PROPERTY NOT PROVEN; RUNTIME TIMING VALIDATION NOT PERFORMED  

---

## 1. Executive Purpose & Context

In Phase 2.5 and 2.6, the verification of device credential comparisons was audited. While Phase 2.6 corrected the endpoint count from nine to three device-facing interfaces, the classification of the comparison function remained overly optimistic.

Phase 2.7 conducts an uncompromising, independent source code analysis of the exact comparison algorithm to establish the limits of what static code inspection can and cannot prove.

---

## 2. Granular Source Code Analysis of the Comparison Algorithm

The complete implementation resides in [supabase/functions/_shared/validation.ts:334–347](file:///d:/parentcontrol_app/supabase/functions/_shared/validation.ts#L334-L347):

```typescript
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

### 2.1 Technical Evaluation of Algorithm Steps

| Implementation Dimension | Actual Code Mechanics | Cryptographic / Timing Implication |
| :--- | :--- | :--- |
| **1. Input Normalization** | `a.toLowerCase()`, `b.toLowerCase()` | **Heap Allocations in V8**: `toLowerCase()` traverses character buffers and allocates new strings. In JavaScript engines, string transformation time depends on string length, character classes, and memory fragmentation. |
| **2. Byte Encoding** | `encoder.encode(a)` via `TextEncoder` | Converts string characters to `Uint8Array` bytes. Operates on ASCII/hex characters; linear memory copy. |
| **3. Length Handling** | `length = Math.max(left.length, right.length)` | Loops across the maximum length. If lengths differ, loop duration scales with the longer string, potentially leaking input length. |
| **4. Difference Initialization**| `diff = left.length ^ right.length` | If lengths differ, `diff` starts non-zero. Good defensive logic. |
| **5. XOR Accumulation** | `diff \|= (left[i] ?? 0) ^ (right[i] ?? 0)` | **Bitwise Accumulation**: Avoids the classical early-return (`if (a[i] !== b[i]) return false`). The loop always executes `length` iterations. |
| **6. Array Bounds Lookups** | `left[i] ?? 0` | When `i >= left.length`, the expression triggers JavaScript engine array bounds checks and undefined coalescing, which may incur minor CPU cycle variances compared to in-bounds index hits. |
| **7. JIT Optimization** | Running on Deno / V8 JIT | V8 applies speculative inlining, loop unrolling, and branch prediction. Software loops in high-level managed languages cannot guarantee instruction-level constant-time execution without compiler-level memory barriers. |
| **8. Dummy Comparison** | `constantTimeEqualHex(digest, "0".repeat(64))` | When a device ID is not found in the DB, a dummy comparison is executed ([auth.ts:331](file:///d:/parentcontrol_app/supabase/functions/_shared/auth.ts#L331)) to balance execution time against valid device lookups. |

---

## 3. Scope of Device Authentication Across Endpoints

Source inspection confirms that device secret verification via `requireDevice()` is **NOT** present across all Edge Functions:
- **Endpoints Using `requireDevice()` (3 Endpoints)**:
  1. `device-telemetry`: Child background daemon telemetry reporting.
  2. `device-command`: Child device polling for pending commands.
  3. `remote-session`: Child device joining WebRTC remote assistance session.
- **Endpoints Using Supabase Auth JWTs (`requireUser()`) (6 Endpoints)**:
  - `account`, `auth-bootstrap`, `family-admin`, `pairing`, `device-policy`, `device-register`.
  - These endpoints validate standard Supabase Auth Bearer JWTs; they do **not** verify device secrets using `constantTimeEqualHex`.
- **Administrative Endpoints (1 Endpoint)**:
  - `cron`: Authenticates via `x-cron-secret` using `constantTimeSecretEqual()`.

---

## 4. Final Epistemological Security Classification

```
====================================================================================================
                        CRYPTOGRAPHIC CONSTANT-TIME EVIDENCE ASSESSMENT
====================================================================================================
Audited Function:                constantTimeEqualHex() / constantTimeEqual()
Audited File Path:               supabase/functions/_shared/validation.ts:334–347
Design Pattern Observed:         Custom TypeScript bitwise XOR accumulator loop without early exit.

What the Evidence PROVES:
  1. The author deliberately implemented an anti-timing loop pattern to prevent early-exit leakage.
  2. A dummy comparison is executed when a device is absent to mitigate user-enumeration timing attacks.
  3. The implementation is pure TypeScript and does not rely on external dependencies.

What the Evidence DOES NOT PROVE:
  1. Does NOT prove execution-time invariance at the CPU instruction or cache-line level.
  2. Does NOT prove that toLowerCase() string allocations are timing-neutral.
  3. Does NOT prove resistance to remote network timing attacks without empirical microsecond timing
     distributions (e.g. Dudley / Welch's t-test over 100,000+ requests).

Authoritative Classification:    IMPLEMENTATION PATTERN INSPECTED — CONSTANT-TIME PROPERTY NOT
                                 PROVEN; RUNTIME TIMING VALIDATION NOT PERFORMED
====================================================================================================
```
