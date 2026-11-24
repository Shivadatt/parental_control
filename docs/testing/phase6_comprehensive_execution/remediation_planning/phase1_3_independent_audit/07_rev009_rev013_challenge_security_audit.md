# 07 — In-Depth Audit of REV-009 & REV-013: Challenge Security, Cryptographic Entropy & Issuance Throttling

**Document ID:** HAVEN-AUD-007  
**Target Workstream:** HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Target Findings:** REV-009 (MEDIUM — Challenge Code UX & Crockford Base32), REV-013 (INFO — Challenge Issuance Rate Limiting)  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

This audit evaluates the cryptographic strength, mathematical brute-force resilience, mobile touchscreen usability, and database abuse resistance of the Child device re-credentialing challenge mechanism.

Phase 1.1 identified that a generic alphanumeric code caused transcription errors on mobile keyboards (`O/0`, `I/1/L`) that risked premature challenge exhaustion (`REV-009`), while an absence of rate limiting on the Parent issuance endpoint enabled table bloat and brute-force flooding (`REV-013`).

---

## 2. Section 14: In-Depth Audit of REV-009 & REV-013 (Entropy & Throttling)

### 2.1 The Crockford Base32 Specification & Normalization Pipeline (REV-009)
To eliminate transcription errors without sacrificing entropy, the system adopts **Crockford's Base32**:
- **Alphabet (32 Characters)**:
  `0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T V W X Y Z`
- **Excluded Ambiguous Characters**:
  - `I` and `L` are excluded due to visual ambiguity with digit `1`.
  - `O` is excluded due to visual ambiguity with digit `0`.
  - `U` is excluded to avoid unintentional formation of offensive words.
- **Client-Side Normalization Pipeline**:
  When a user enters or pastes the code, the input formatter automatically executes:
  ```dart
  String normalizeChallengeCode(String input) {
    return input.trim().toUpperCase()
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
  }
  ```
  Accidental typos (e.g. typing `"o1l8-ab"`) are deterministically transformed into `"0118AB"`.

### 2.2 Mathematical Proof of Cryptographic Entropy
1. **Alphabet Cardinality ($N$)**: $32$ characters.
2. **Code Length ($L$)**: $6$ characters.
3. **Total Key Space ($S$)**:
   $$S = 32^6 = (2^5)^6 = 2^{30} = 1,073,741,824 \approx 1.074 \times 10^9\text{ possible combinations}$$
4. **True Cryptographic Entropy ($H$)**:
   $$H = \log_2(32^6) = 6 \times \log_2(32) = 6 \times 5 = 30.0\text{ bits}$$
5. **CSPRNG Uniformity**: Challenge codes are generated in the Deno Edge Function via `crypto.getRandomValues(new Uint8Array(6))`, ensuring uniform distribution across the entire $2^{30}$ space.

---

## 3. Server-Side Challenge Issuance Throttling (REV-013)

### 3.1 The Sliding Window Throttle Specification
To protect the database against denial-of-service and table exhaustion attacks, `/family-admin` enforces an hourly rate limit before generating a challenge:
```sql
SELECT count(*) FROM public.device_recovery_challenges
WHERE device_id = p_device_id AND created_at > (now() - interval '1 hour');
```
If `count >= 3`, the Edge Function throws:
`ApiError("rate_limit_exceeded", "Too many recovery attempts requested. Please wait before generating another code.", 429)`

### 3.2 Single-Active-Challenge Invariant (Supersession)
Before inserting a new challenge row, the server executes:
```sql
UPDATE public.device_recovery_challenges
SET status = 'superseded', consumed_at = now()
WHERE device_id = p_device_id AND status = 'active';
```
**The Invariant**: Exactly **ONE** challenge token can be in `status = 'active'` for any device at any instant in time. Issuing a new code instantly renders any previously unconsumed code permanently dead.

---

## 4. Mathematical Brute-Force Resilience Proofs

### 4.1 Single Challenge Guess Probability
For any individual challenge token, an attacker is granted a strict maximum of 5 attempts before permanent lockout:
$$P(\text{guess} \mid \text{single challenge}) = \frac{5}{1,073,741,824} \approx 4.6566 \times 10^{-9}$$
**Odds**: Less than **1 in 214.7 million**.

### 4.2 Cumulative Hourly Attack Bound
Because challenge issuance is capped at 3 per hour:
$$\text{Max Guessing Opportunities/Hour} = 3\text{ challenges/hr} \times 5\text{ attempts/challenge} = 15\text{ attempts/device/hr}$$
The cumulative probability of successfully guessing a valid challenge within an hour of continuous attacking is:
$$P(\text{hourly brute force}) = \frac{15}{1,073,741,824} \approx 1.39698 \times 10^{-8} \approx 1.4 \times 10^{-8}$$
**Odds**: Less than **1 in 71.5 million**.

### 4.3 Comparison with Industry Standards
- **Standard 6-digit decimal PIN**: $10^6 = 1,000,000$ combinations ($5\text{ attempts} \rightarrow P = 5 \times 10^{-6}$).
- **Crockford Base32 6-character code**: $1,073,741,824$ combinations ($5\text{ attempts} \rightarrow P = 4.65 \times 10^{-9}$).
- **Advantage**: Crockford Base32 is over **$1,073\times$ more resistant to brute force** than standard 6-digit SMS/banking 2FA codes, while remaining completely immune to character confusion.

**REV-009 & REV-013 Official Status:** **VERIFIED CLOSED BY DESIGN**
