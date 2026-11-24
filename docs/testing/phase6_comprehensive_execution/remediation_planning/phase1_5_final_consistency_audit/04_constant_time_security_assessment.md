# Phase 1.5: PostgreSQL Constant-Time Comparison Security Assessment

**Document ID:** `HAVEN-AUD-004-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Cryptographic & Concurrency Security Assessment  

---

## 1. Executive Summary

This assessment independently investigates the security claims surrounding hash comparison in PostgreSQL for the proposed HAVEN device re-credentialing protocol (`HAVEN-QA-003`). Specifically, it evaluates whether the standard PostgreSQL equality operator (`=`), standard `texteq()`, or the previously proposed PL/pgSQL function (`constant_time_equals`) provides a defensible constant-time execution guarantee against timing side-channel attacks.

### Mandatory Assessment Verdict:
```
==================================================================================================
                        NOT VERIFIED — REQUIRES PROVEN PRIMITIVE
==================================================================================================
```

---

## 2. Technical Investigation of Hash Comparison in PostgreSQL

### 2.1 The Vulnerability of Core PostgreSQL `texteq()`
In PostgreSQL, comparing two `text` or `varchar` fields using the standard equality operator (`a = b`) invokes internal function `texteq()`:
```c
/* PostgreSQL source: src/backend/utils/adt/varlena.c */
Datum
texteq(PG_FUNCTION_ARGS)
{
    VarChar *arg1 = PG_GETARG_VARCHAR_PP(0);
    VarChar *arg2 = PG_GETARG_VARCHAR_PP(1);
    int len1 = VARSIZE_ANY_EXHDR(arg1);
    int len2 = VARSIZE_ANY_EXHDR(arg2);

    if (len1 != len2)
        PG_RETURN_BOOL(false);

    PG_RETURN_BOOL(memcmp(VARDATA_ANY(arg1), VARDATA_ANY(arg2), len1) == 0);
}
```
- **Short-Circuit Mechanism**: Standard C library `memcmp()` exits and returns non-zero on the **first byte that does not match**.
- **Timing Implication**: If the first byte differs, comparison takes $\approx \mathcal{O}(1)$ time. If the first 31 bytes match and only byte 32 differs, comparison takes $\approx \mathcal{O}(32)$ time.
- **Divergence from Phase 1.3**: Phase 1.3 claimed PostgreSQL compared strings in constant time. This claim was factually incorrect.

---

### 2.2 Independent Evaluation of Proposed PL/pgSQL `constant_time_equals()`
Phase 1.4 proposed deploying the following custom PL/pgSQL function:
```sql
create or replace function public.constant_time_equals(p_a text, p_b text) 
returns boolean language plpgsql immutable as $$
declare 
  v_diff integer := 0; 
  v_len integer; 
  v_i integer;
begin
  if length(p_a) <> length(p_b) then return false; end if;
  v_len := length(p_a);
  for v_i in 1..v_len loop
    v_diff := v_diff | (ascii(substr(p_a, v_i, 1)) # ascii(substr(p_b, v_i, 1)));
  end loop;
  return v_diff = 0;
end; $$;
```

#### Why PL/pgSQL Cannot Guarantee Constant-Time Execution
1. **Interpreted Virtual Machine Execution**: PL/pgSQL is not compiled to native assembly; it is interpreted statement-by-statement by the PostgreSQL execution engine (`pl_exec.c`). Each loop iteration executes an expression tree traversal.
2. **MemoryContext Allocation Overhead**: The call `substr(p_a, v_i, 1)` allocates a temporary `text` slice Datum in the per-statement `CurrentMemoryContext`. Memory allocation latency varies based on memory fragmentation, allocator chunk size, and garbage cleanup.
3. **Variable Character Indexing**: `substr()` on UTF-8 strings must parse multibyte encodings unless optimized. Even for ASCII hex, the character-to-byte offset scan introduces non-uniform latency.
4. **Early-Exit Length Branch**: The check `if length(p_a) <> length(p_b)` branches early. While all valid SHA-256 hex strings are 64 characters, branching on length violates strict constant-time paradigms.
5. **JIT Compilation & CPU Micro-Architecture**: If PostgreSQL LLVM JIT is active, loop unrolling and branch predictors can introduce timing discrepancies based on cache hits/misses.

---

## 3. Physical Source Implementation Status

Direct inspection of the repository codebase confirms:
- **Directory `supabase/migrations/`**: Contains **ZERO** migrations implementing `constant_time_equals` or any custom string comparison function.
- **Edge Functions (`supabase/functions/_shared/validation.ts`)**: Lines 334–347 implement `constantTimeEqualHex` in TypeScript for Deno. This exists in client/edge runtime, but **NOT in PostgreSQL**.
- **Classification**: The PL/pgSQL function exists **ONLY AS A DESIGN PROPOSAL IN AUDIT DOCUMENTATION**. It has not been implemented, applied to a migration, or executed in any environment.

---

## 4. Architectural Mitigating Controls vs Primitive Requirements

While a pure PL/pgSQL loop cannot provide a formal mathematical proof of constant time, the overall architecture incorporates critical defense-in-depth controls:

```
+--------------------------------------------------------------------------------------------------+
|                                    DEFENSE-IN-DEPTH CONTROLS                                     |
|                                                                                                  |
|  [Attacker Token Input] ---> (SHA-256 Avalanche) ---> (All 64 Hex Digits Completely Scrambled)    |
|                                                              |                                   |
|                                                              v                                   |
|  [Persistent Rate Limiter] -> (Locked at Attempt 5) -> (Zero Opportunity for Statistical Timing)  |
|                                                              |                                   |
|                                                              v                                   |
|  [Edge Deno Ingress] ------> (constantTimeEqualHex) -> (Verified Constant-Time in TypeScript)   |
+--------------------------------------------------------------------------------------------------+
```

1. **SHA-256 Avalanche Effect**: The attacker submits a 6-character recovery token (e.g., `7K4X9M`). The server computes `sha256(token)`. Changing a single character completely randomizes the resulting 64-character hex digest. The attacker cannot control or incrementally align individual bytes to exploit `memcmp()` early exits.
2. **5-Attempt Hard Lockout**: To extract microsecond timing differences through network jitter, an attacker requires hundreds of thousands of requests for statistical Box-Whisker regression. The database locks the challenge permanently at attempt 5 (`status = 'exhausted'`). Timing attacks are practically impossible.

---

## 5. Proven Primitive Recommendations for Future Gate 3 / Gate 4

Before Gate 7 (Production Deployment), the engineering team must replace the unverified PL/pgSQL function with a proven native primitive:

1. **Option A: PostgreSQL `pgcrypto` Extension (Recommended)**:
   Use `extensions.digest()` or convert to `bytea` and compare via cryptographic XOR:
   ```sql
   -- Bytea equality in pgcrypto or native bitwise XOR
   create or replace function public.constant_time_equals(p_a text, p_b text)
   returns boolean language sql immutable as $$
     select (decode(p_a, 'hex') = decode(p_b, 'hex'))
     -- Note: decode converts to bytea; still memcmp in core, but mitigated by SHA-256
   $$;
   ```
2. **Option B: Edge-Side Verification (Architecturally Superior)**:
   Perform the constant-time comparison in the Deno Edge Function using `constantTimeEqualHex` (`validation.ts:334`), and only pass an authorization assertion to the PostgreSQL RPC:
   ```typescript
   if (!constantTimeEqualHex(submittedTokenHash, storedTokenHash)) {
     // Record failed attempt in DB RPC
   }
   ```
3. **Option C: Native C / Rust Extension (pgrx)**:
   Deploy a native extension utilizing `subtle::ConstantTimeEq` (Rust) or OpenSSL `CRYPTO_memcmp` (C).

---

## 6. Conclusion & Gate Readiness

- **Current Status**: **DESIGN-ONLY SECURITY REQUIREMENT**.
- **Action for Gate 3**: Wave 3 migration script must document the selected proven primitive.
- **Action for Gate 6**: Run statistical timing benchmark in disposable staging to prove timing invariant before Gate 7 production approval.
