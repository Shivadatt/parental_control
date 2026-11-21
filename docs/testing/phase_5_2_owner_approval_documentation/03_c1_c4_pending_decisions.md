# 03 — C1–C4 Pending Owner Decisions

**Status of all four: PENDING OWNER DECISION.**  
These are recommendations from Phase 5.1. None is approved. Gate A does not cover them.

Source analysis: `docs/testing/phase_5_1_owner_decision_reconciliation/03_c1_c2_decision_analysis.md` and `04_c3_c4_decision_analysis.md`.

---

# C1 — Parent re-validation at redemption

**Status: PENDING OWNER DECISION — blocks Gate C.**

## Question
When the Child redeems, must the server require an active Parent in the challenge's family? If yes, is it **any active parent** or **only the parent who created the challenge**?

## Recommendation
Require **at least one active parent** in the challenge's family at redemption.

## Alternatives
| Option | Effect |
|---|---|
| Any active parent (recommended) | Family retains recovery capability if the creating parent is removed |
| Creator only | Stronger provenance; stale challenge fails if creator leaves |
| No parent re-check (rejected) | Removed/foreign parent's challenge could rotate a credential |

## Rationale
- D3 already says any active parent may approve; the challenge is family-scoped.
- The critical authorization event is audited at creation (`created_by`).
- Avoids a silent lockout when the approving parent is removed.

## Security implications
- Any-active-parent preserves family authorization; it does not let a foreign family in.
- Creator-only is stricter per-person but operationally brittle.
- No re-check is unsafe.

## Operational implications
- Any-active-parent supports multi-parent families with less support burden.
- Creator-only needs a specific error and reissue flow.
- Audit should store `created_by` and `consumed_by`.

## Dependencies
Gate C redeem RPC membership predicate; audit metadata; tests for parent removal between request and redeem.

## Gate C / deferral
**Blocks Gate C. Cannot be deferred.**

---

# C2 — Attempt-accounting mechanism

**Status: PENDING OWNER DECISION — blocks Gate C (RPC/grants shape).**

## Question
How should approved D8 ("commit attempt accounting first") be implemented?

## Recommendation
Use a **separate committed service-role-only RPC** that atomically increments `attempts` before the redeem call.

## Alternatives
| Option | Assessment |
|---|---|
| Separate committed RPC (recommended) | Implements D8 explicitly; keeps credential write in redeem; avoids Edge table grants |
| Increment inside redeem | Rollback refunds wrong attempts; violates D8 |
| Edge direct `UPDATE` | Works but duplicates policy and needs table update grant |

## Rationale
D8 is the approved policy; C2 is only the mechanism. The separate RPC makes "commit first" testable and keeps the atomic credential transaction clean.

## Security implications
- Wrong secrets consume budget even when redeem aborts.
- A transient redeem failure still consumes one attempt (accepted D8 trade-off).
- Redeem re-checks `attempts <= max_attempts` as final authority.

## Operational implications
- One extra round trip.
- Edge maps `allowed=false` to 429/410.
- New challenge resets attempts.

## Dependencies
Gate C attempt RPC and grants; Edge orchestration; tests for concurrent attempts.

## Gate C / deferral
**Blocks Gate C. Cannot be deferred.**

---

# C3 — Challenge status and cancellation in MVP

**Status: PENDING OWNER DECISION — blocks Gate C scope.**

## Question
Should the MVP include a Parent status read and a Parent cancel action?

## Recommendation
Include **both**; if scope must shrink, include status first and defer cancel.

## Alternatives
| Option | Effect |
|---|---|
| Status + cancel (recommended) | Best UX; early invalidation of a leaked code |
| Status only | Good UX; leaked code waits for TTL/supersede |
| Cancel only | Security benefit without visibility |
| Neither | Smallest Gate C; relies on expiry/supersede |

## Rationale
- Status is low-risk and improves supportability/tests.
- Cancel reduces exposure of a leaked/misdirected code.
- Neither changes the credential-rotation transaction.

## Security implications
- Both must be family-scoped and never return code/hash.
- Cancel must be pending-only and race-safe against redeem.
- Status must not become a foreign-family oracle.

## Operational implications
- Extra actions/RPCs/tests/audit events.
- Status supports a "waiting for phone" UI without device polling.

## Dependencies
Gate C optional status/cancel RPCs; Edge actions; Flutter Parent UI; audit.

## Gate C / deferral
**Scope decision needed before Gate C.** Status can be deferred with a waiting/expiry UX; cancel can be deferred but then only supersede/expiry mitigates a leaked code.

---

# C4 — Challenge code format

**Status: PENDING OWNER DECISION — blocks Gate C validation.**

## Question
What code format should be used?

## Recommendation
**8 characters from the existing 30-symbol alphabet**, optional QR, **keyed hash**.

## Alternatives and entropy
| Format | Entropy | Comment |
|---|---:|---|
| 6×30 | 29.44 bits | Too weak — reject |
| **8×30** | **39.26 bits** | Recommended; same as existing pairing code |
| 10×30 | 49.07 bits | Stronger; slightly harder to read |
| 12×30 | 58.89 bits | Strong; QR preferred |
| 8 digits | 26.58 bits | Too weak |

Formula: `L × log2(30)`, `log2(30) ≈ 4.9069`.

## Rationale
- 8×30 is consistent with the product's existing pairing-code UX and excludes ambiguous characters.
- Online guessing is bounded by 5 attempts and rate limits.
- Offline brute force of a 39-bit code is feasible if the hash is unsalted; use HMAC/pepper (`identifierHash`) and keep the 10-minute TTL.

## Security implications
- Code is only useful with a valid Child JWT and active membership.
- Keyed hash materially reduces offline value.
- QR reduces transcription risk but must not replace the code for devices without cameras.

## Operational implications
- 8 chars is easy to read aloud; 10/12 chars reduce usability.
- Unique `code_hash` constraint; regenerate on negligible collision.

## Dependencies
`_shared/validation.ts` alphabet/generator; Gate C hash validation; Edge hashing; UI/QR.

## Gate C / deferral
**Blocks Gate C.** A placeholder would encode an unapproved format.
