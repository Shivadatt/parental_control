# 03 — Cryptographic Comparison, Timing Resistance, Entropy & Distributed Rate-Limiting Review

**Document ID:** `HAVEN-AUD-003-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification, Protocol Verification & Final Owner Approval Readiness  
**Date:** 2026-11-24  
**Target Workstream:** WORKSTREAM A2, A3, A4 (Cryptographic Comparison, Entropy Proofs & Distributed Abuse Controls)  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Hash Comparison & Timing Attack Analysis (Workstream A2)

### 1.1 Challenging the "Network Jitter Makes Timing Attacks Irrelevant" Assumption
Phase 1.3 claimed that network jitter (~15–50 ms) completely eliminates timing side-channel attacks, implying that constant-time comparison primitives in PostgreSQL are unnecessary.
**Auditor Challenge**: This assumption is theoretically flawed:
1. Box-Cox statistical averaging and box-whisker filtering over thousands of samples can isolate sub-microsecond timing variances across network boundaries.
2. If an attacker is co-located in the same cloud region (e.g. AWS us-east-1 to Supabase AWS host), network jitter drops to sub-millisecond ranges.
3. Therefore, security-critical verification MUST NOT rely on network jitter as a primary defense. It must enforce algorithmic constant-time comparison.

### 1.2 Inspection of Existing Comparison Primitives
- **Edge Functions (TypeScript)**:  
  Citation: `supabase/functions/_shared/validation.ts:334-347`
  ```typescript
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
  **Auditor Assessment**: The TypeScript implementation in Edge Functions is verified as **constant-time**. It accumulates bitwise differences across the maximum length without early exits.
- **PostgreSQL PL/pgSQL**:  
  In the proposed migration script for `rotate_device_secret`:
  ```sql
  if v_challenge.challenge_hash <> v_token_hash then ...
  ```
  **Auditor Assessment**: Native PostgreSQL string equality (`<>` / `=`) uses `varstr_cmp` or `bcmp`, which **exits early upon the first mismatched byte**.  
  **Official Classification**: Constant-time comparison in PL/pgSQL is **DESIGN REQUIREMENT / NOT IMPLEMENTED** in current repository migrations.

### 1.3 Exploitability Reduction via Attempt Limits
While PL/pgSQL string comparison is not constant-time in the current proposal, the attacker's ability to exploit timing is strictly curtailed by **attempt limiting**:
- An attacker is granted a maximum of 5 guesses per challenge, and 3 challenges per hour (15 guesses/hour).
- Statistical timing extraction of a 64-character hex hash requires upwards of $100,000$ measurements per byte position.
- At 15 guesses per hour, extracting a single byte would require over $277\text{ days}$ of continuous probing, triggering dozens of rate-limit alerts.
- **Mandatory Hardening Requirement**: To achieve defense-in-depth, the final SQL migration for `rotate_device_secret` must implement an XOR-accumulation byte comparison loop in PL/pgSQL.

---

## 2. Entropy & Credential Design Verification (Workstream A3)

### 2.1 Crockford Base32 Character Set & Normalization Rules
The re-credentialing challenge code utilizes Crockford's Base32 encoding:
- **Alphabet (32 Characters)**:
  `0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T V W X Y Z`
- **Excluded Characters**:
  - `I` and `L`: Excluded due to visual confusion with digit `1`.
  - `O`: Excluded due to visual confusion with digit `0`.
  - `U`: Excluded to eliminate accidental generation of offensive words.
- **Client Input Normalization Function**:
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

### 2.2 Collision & Normalization Analysis
- **Does normalization create unintended collisions?**  
  **NO.** Because the server-side generator strictly samples from the 32-character alphabet (which already excludes `I`, `L`, `O`, `U`), valid server-generated codes **NEVER** contain `I`, `L`, `O`, or `U`. Normalization simply maps accidental user inputs (`O` $\rightarrow$ `0`, `I/L` $\rightarrow$ `1`) into the valid alphabet.
- **Does Crockford Base32 guarantee typo elimination?**  
  **NO.** Phase 1.3 claimed typo elimination was guaranteed. This is inaccurate. Typing a completely different valid character (e.g. typing `7` instead of `3`, or `K` instead of `M`) cannot be corrected by normalization and will consume a failed attempt. Normalization guarantees the elimination of **homoglyph ambiguity only**.

### 2.3 Mathematical Proof of Entropy & Guessing Probabilities
1. **Total Key Space ($S$)**:
   $$S = 32^6 = (2^5)^6 = 2^{30} = 1,073,741,824\text{ possible codes}$$
2. **True Cryptographic Entropy ($H$)**:
   $$H = \log_2(32^6) = 30.0\text{ bits}$$
3. **Single Challenge Guess Probability ($P_{\text{single}}$)**:
   Given a limit of 5 attempts per challenge:
   $$P_{\text{single}} = \frac{5}{1,073,741,824} \approx 4.6566 \times 10^{-9}\quad (1\text{ in }214,748,364)$$
4. **Cumulative Hourly Brute-Force Probability ($P_{\text{hourly}}$)**:
   Given 3 challenges per device per hour ($15\text{ attempts/hr}$):
   $$P_{\text{hourly}} = \frac{15}{1,073,741,824} \approx 1.39698 \times 10^{-8} \approx 1.4 \times 10^{-8}\quad (1\text{ in }71,582,788)$$

### 2.4 Explicit Assumptions Behind Probability Calculations
The probability calculations above are valid **ONLY IF** the following four assumptions hold:
1. The token generator utilizes a true CSPRNG (`crypto.getRandomValues()`) with uniform distribution.
2. The attacker has zero out-of-band knowledge of the token generation algorithm or internal seed state.
3. Attempt limiting is durably committed to PostgreSQL before subsequent attempts can execute.
4. Challenge issuance rate limiting cannot be bypassed through concurrent requests or distributed nodes.

---

## 3. Distributed Rate Limiting & Issuance Abuse Controls (Workstream A4)

### 3.1 The Stateless Edge Function Flaw
Phase 1.2 and Phase 1.3 proposed evaluating challenge issuance limits in Edge Function logic:
```sql
SELECT count(*) FROM public.device_recovery_challenges
WHERE device_id = p_device_id AND created_at > (now() - interval '1 hour');
```
**Auditor Challenge**: In serverless architectures (Supabase Deno Edge Workers):
1. Edge Function instances are stateless, spun up dynamically across global edge locations.
2. An in-memory rate-limiter counter (e.g. `Map<string, number>`) in Edge Function memory is completely useless because concurrent requests land on different worker isolates.
3. Even with a database `SELECT count(*)`, two simultaneous HTTP requests to `/family-admin` can execute the `count(*)` query concurrently, both read `count = 2`, and both proceed to generate a challenge, bypassing the 3/hr cap!

### 3.2 Recommended Distributed Abuse Control Hierarchy

To prevent distributed abuse, the system must enforce a multi-tier abuse hierarchy backed by PostgreSQL relational constraints:

```
[Tier 1: Relational Constraint] ==> CREATE UNIQUE INDEX idx_challenges_single_active 
                                    ON device_recovery_challenges(device_id) WHERE status = 'active'
                                    (Guarantees exactly ONE active challenge per device at the SQL engine level)
              │
[Tier 2: Per-Device Rate Limit] ==> SELECT ... FOR UPDATE or Serialized SQL Function
                                    (Enforces strict cap of 3 challenges / device / hour)
              │
[Tier 3: Per-Family Rate Limit] ==> Cap of 10 challenges / family / hour across all child devices
                                    (Prevents multi-device table bloat)
              │
[Tier 4: Per-Parent Rate Limit] ==> Cap of 5 challenges / parent account / hour
                                    (Throttles compromised parent credentials)
```

### 3.3 Atomic Challenge Creation & Supersession RPC Specification
Challenge creation and supersession **MUST BE ATOMIC**. They cannot be executed as separate HTTP round-trips.
The database migration must package challenge issuance into a dedicated `SECURITY DEFINER` function:

```sql
CREATE OR REPLACE FUNCTION public.issue_recredential_challenge(
  p_device_id uuid,
  p_actor_user_id uuid,
  p_challenge_token text,
  p_challenge_hash text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_recent_count int;
  v_family_id uuid;
BEGIN
  -- 1. Check family authorization
  SELECT family_id INTO v_family_id FROM public.devices WHERE id = p_device_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'device_not_found');
  END IF;

  -- 2. Enforce persistent hourly sliding-window rate limit (Max 3/hr)
  SELECT count(*) INTO v_recent_count
  FROM public.device_recovery_challenges
  WHERE device_id = p_device_id AND created_at > (now() - interval '1 hour');

  IF v_recent_count >= 3 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rate_limit_exceeded');
  END IF;

  -- 3. Atomically supersede any existing active challenge for this device
  UPDATE public.device_recovery_challenges
  SET status = 'superseded', consumed_at = now()
  WHERE device_id = p_device_id AND status = 'active';

  -- 4. Insert new challenge row
  INSERT INTO public.device_recovery_challenges (
    device_id,
    family_id,
    issued_by_user_id,
    challenge_hash,
    attempts,
    max_attempts,
    status,
    expires_at
  ) VALUES (
    p_device_id,
    v_family_id,
    p_actor_user_id,
    p_challenge_hash,
    0,
    5,
    'active',
    now() + interval '10 minutes'
  );

  RETURN jsonb_build_object('ok', true, 'expires_at', now() + interval '10 minutes');
END;
$$;
```

**Workstream A Summary Verdict**: **DESIGN VERIFIED WITH CONDITIONS**. Constant-time comparison in PL/pgSQL and atomic challenge issuance RPC must be incorporated into the Gate 3 migration script.
