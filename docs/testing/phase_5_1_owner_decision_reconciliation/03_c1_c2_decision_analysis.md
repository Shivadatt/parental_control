# 03 — C1 and C2 Decision Analysis

**Scope:** Parent re-validation at redemption (C1) and attempt-accounting mechanism (C2). No implementation.

---

# C1 — Parent re-validation at redemption

## 1. Exact question

When the Child redeems the challenge, must the server re-verify the **Parent**? If yes, which Parent must be valid:

- **(a)** any active parent in the challenge's family; or
- **(b)** only the specific parent who created the challenge (`created_by`).

The question matters because a challenge may be created by Parent A and redeemed after Parent A is removed, suspended, or signs out.

## 2. Existing approved decisions that may cover it

- **D3:** "Any active parent" may approve. This is a statement about who may initiate, not explicitly about re-validation at redemption.
- **Phase 4 report 05** requires "Only an authorized parent may approve recovery for a device within their active family."
- **Phase 4 report 06** says the RPC must "Revalidate parent authorization".
- **Phase 5 report 08 §6** recommends **any active parent** and flags it as needing freeze.

D3 does **not** fully resolve C1: it answers "who can approve at creation", not "what if that parent is gone at redemption".

## 3. Recommended option

**Option (a): require at least one active parent in the challenge's family at redemption.**

Rationale:
- The challenge is family-scoped, not person-scoped.
- The critical authorization event is the Parent's explicit approval at creation, which is audited with `created_by`.
- A family does not lose recovery capability because the approving parent is removed or unavailable.
- It avoids a silent failure mode where a valid challenge cannot be redeemed.
- It matches D3's "any active parent" model.

## 4. Alternatives

### (b) Only the creating parent
- Stronger provenance; the exact approver must still be active.
- Risk: if that parent is removed, the challenge becomes unusable; the Child must wait for a new challenge.
- Operationally brittle for multi-parent families.

### (c) No parent re-check at redemption
- Not acceptable: a removed/foreign parent's stale challenge could rotate a credential after the family relationship changed.
- Violates the "authorized parent" requirement.

## 5. Security implications

| Option | Security | Failure mode |
|---|---|---|
| (a) any active parent | Family still authorized; audit records creator | A compromised remaining parent can complete a challenge created by another; but they could create their own anyway |
| (b) creator only | Stronger per-person binding | Stale challenge after creator removal; possible lockout |
| (c) none | **Unsafe** | Removed parent's challenge survives |

Option (a) does not weaken D3; it extends the same trust model to redemption. It still requires the **Child** to be active and the challenge to match.

## 6. Operational implications

- (a) supports multi-parent families and avoids support burden.
- (b) requires an explicit "creator removed" error and a new-challenge flow.
- Both need audit metadata: `created_by`, `redeemed_by`, `redeemed_at`.

## 7. Implementation dependencies

- Gate C redeem RPC authorization predicate.
- Audit metadata.
- Error code for "no active parent" if (b) or if (a) finds none.
- Tests: parent removed between request and redeem.

## 8. Must it be decided before Gate C?

**Yes.** It changes the RPC's membership query and error behaviour. Without it the RPC cannot be frozen.

## 9. Can it be deferred?

**No.** A placeholder would encode a security decision by accident.

---

# C2 — Attempt accounting

## 1. Exact question

How is D8 ("commit attempt accounting first") implemented:

- **(a)** a separate committed RPC/statement before validation (recommended);
- **(b)** increment inside the redeem transaction (rolls back on failure);
- **(c)** Edge-side direct update before calling redeem.

## 2. Relationship to approved D8

**D8 is the owner decision:** attempts must be charged before secret validation, even if redemption later fails.

C2 is therefore **not a new security policy**. It is the **implementation mechanism** for D8. The three options differ in where the committed increment lives and what failure modes they create.

## 3. Recommended option

**Option (a): a dedicated service-role-only RPC that atomically increments and commits `attempts` before the redeem call.**

Why:
- It makes the "commit first" semantics explicit and testable.
- It keeps the credential write in the redeem transaction.
- It avoids giving the Edge handler direct `UPDATE` privileges on the challenge table.
- It centralizes the attempt/expiry/status check.

## 4. Alternatives

### (b) Increment inside redeem
- Simpler (one RPC).
- A failed redeem rolls back the attempt → wrong secrets get free retries.
- **Violates D8** unless compensated by a separate committed counter, which reintroduces (a).

### (c) Edge direct `UPDATE`
- Works, but requires an `UPDATE` grant on the challenge table to the service role and duplicates policy logic in TypeScript.
- More places to get expiry/status/concurrency wrong.
- Not recommended.

## 5. Security implications

- (a) guarantees wrong attempts consume budget even when the transaction aborts.
- (b) weakens brute-force resistance.
- (c) is equivalent to (a) but with weaker encapsulation.

A transient DB failure during redeem still consumes an attempt under (a). This is the accepted D8 trade-off.

## 6. Operational implications

- (a) adds one round trip per redemption.
- The Edge handler must map `allowed=false` to `429 attempts_exhausted` or `410 challenge_expired`.
- A new challenge resets the counter.

## 7. Concurrency

- The increment must be atomic (`UPDATE ... attempts = attempts + 1 ... RETURNING`).
- Two concurrent attempts must not read the same old count.
- The redeem RPC re-checks `attempts <= max_attempts` as the authority even if Edge was bypassed.

## 8. Must it be decided before Gate C?

**Yes**, because it determines whether Gate C contains one RPC or two (or grants `UPDATE` to the Edge role). The contract freeze includes the attempt RPC.

## 9. Can it be deferred?

**No.** D8 cannot be correctly implemented without choosing a mechanism.

## 10. C2 classification

| Aspect | Classification |
|---|---|
| Security policy | **APPROVED D8** |
| Mechanism | **OWNER CONFIRMATION RECOMMENDED** (a) |
| Blocking Gate C? | **Yes**, for the RPC/grants shape |
