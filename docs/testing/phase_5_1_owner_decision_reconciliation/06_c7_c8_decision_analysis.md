# 06 — C7 and C8 Decision Analysis

**Scope:** Expiry sweeper (C7) and the signed Gate A record (C8). No implementation, no fabricated approval.

---

# C7 — Expiry sweeper

## 1. Exact question

Is a scheduled cleanup job required to expire challenges, or is lazy expiration on access sufficient?

## 2. What the design requires

- `expires_at` is stored at creation (10 minutes, D2).
- Every redeem/status/attempt path can compare `expires_at <= now()` under lock.
- Correctness of the security decision — "an expired challenge cannot rotate" — depends only on that check, **not** on a cleanup job.

Source: Phase 5 report `10_transaction_and_idempotency_design.md:19-24`; report `08_gate_c_database_rpc_specification.md:72-78`.

## 3. Option analysis

### A — Lazy only (recommended for correctness)
- RPC checks expiry.
- When an expired challenge is touched, mark `status='expired'` and audit.
- No scheduler, no cron secret, no extra function.
- Old rows remain `pending` in the table until touched; that is cosmetic, not security-relevant.
- Status queries must compute "expired" from `expires_at` even if status is still `pending`.

**Pros:** minimal moving parts; no scheduler failure mode; no deployment of cron.
**Cons:** table accumulates stale pending rows; a status query must not misreport a stale `pending` as usable.

### B — Scheduled sweeper
- A periodic job (existing cron function or DB job) marks `pending` rows `expired` and audits.
- **Pros:** clean state, accurate status, supports retention/analytics.
- **Cons:** scheduler reliability, another privileged path, audit noise, deployment dependency.
- Must never rotate or delete a device.

### C — Both
- Lazy check for correctness + sweeper for hygiene (recommended long-term).

## 4. Recommendation

**Lazy enforcement is mandatory; a sweeper is optional hygiene.**

- Gate C must implement lazy expiry in every RPC that reads a challenge.
- A sweeper can be deferred without affecting security.
- If a status endpoint exists (C3), it should derive `expired` from the timestamp even before a sweeper marks it.

## 5. Security implications

| Risk | Lazy | Sweeper |
|---|---|---|
| Expired challenge redeems | Prevented by timestamp check | Prevented |
| Status lies "pending" | Must compute from timestamp | Fixed by sweep |
| Scheduler failure | None | Status hygiene degrades only |
| Privileged cleanup abuse | None | Must be service-role/cron only; no client |

## 6. Operational implications

- Lazy-only is simpler to deploy and roll back.
- A sweeper adds monitoring/alerting; it is not required for the first release.
- Retention (90 days proposed) can be a separate purge task.

## 7. Implementation dependencies

- Gate C RPC timestamp checks.
- If sweeper: cron secret/function, audit event, schedule, monitoring.
- Status action (if C3) computes expiry.

## 8. Must it be decided before Gate C?

**Only the lazy-check requirement.** The sweeper itself can be deferred. If the owner wants the `expired` status to be materially accurate without a read, the sweeper must be in scope.

## 9. Can it be deferred?

**Yes, safely**, as long as lazy checks are implemented and status computes expiry. Mark sweeper **DEFERRABLE**.

---

# C8 — Signed Gate A record

## 1. Exact question

How should the project record Gate A approval so that Gate C/B are based on documented owner authorization, not an unverified assertion?

## 2. Evidence

| Artifact | Finding |
|---|---|
| `phase_4.../12_owner_decision_record.md` §1 | Option C recommended |
| same §2 | D1–D14 status **OPEN** |
| same §4 | decision block unsigned; Owner/Date blank |
| same §5.5 | explicitly waits for owner approval |
| `phase_4.../11_future_authorization_matrix.md:91-99` | Gate A checklist unchecked |
| `phase_5.../01_executive_summary.md:19,58` | Gate A asserted by Phase 5 brief; artifact still open |
| `phase_5.../14_owner_implementation_decision.md:17` | same gap |

No owner name, date, signature, or value-level approval exists in the repository.

## 3. What must not happen

- Do not add a fabricated signature.
- Do not invent a date.
- Do not mark D1–D14 approved in the original Phase 4 file in this phase.
- Do not state that "the owner approved" beyond what the Phase 5 brief asserts.
- Do not treat the recommendation table as an approval.

## 4. Proposed correction (for a future authorized documentation update)

Create a **Gate A addendum** (do not edit the original in this phase) with:

```
Gate A status:              APPROVED BY OWNER ASSERTION
Approval source:            Phase 5 authorization brief
Documentary evidence:       NONE at HEAD bbd3c21
Approval date:              NOT RECORDED
Approval scope:             Option C architecture
D1–D14 value-level approval: NOT RECORDED
Security limitations accepted: physical possession not provable;
                            compromised parent session residual risk;
                            child session + deceived parent residual risk
Owner:                      ____________________
Date:                       ____________________
```

Plus the D1–D14 confirmation table from Phase 5.1 report 02 §5.

### Evidence-backed wording (safe)
> "Option C is the selected architecture per the Phase 5 authorization brief. The Phase 4 owner decision record remains unsigned at HEAD `bbd3c21`; the D1–D14 values and the owner's acceptance of residual risks are not documented in the repository. Gate A is therefore treated as owner-asserted, not documented. The owner is asked to sign this addendum before Gate C."

### Unsafe wording (prohibited)
> "The owner approved D1–D14 on <invented date>."

## 5. Recommended resolution path

1. Owner reviews Phase 5.1 reports.
2. Owner signs **one** addendum containing:
   - Option C approval;
   - D1–D14 values (or changes);
   - C1–C8 decisions;
   - residual-risk acceptance;
   - date and scope.
3. The addendum is stored under `docs/testing/phase_5_1_owner_decision_reconciliation/` or a future authorized location.
4. Only then is Gate C eligible for authorization.

Editing the original Phase 4 record is **not required** and should be avoided; an addendum preserves history.

## 6. Must it be decided before Gate C?

**Yes.** Gate C cannot be authorized against an undocumented approval. This is the highest-priority pending item.

## 7. Can it be deferred?

**No.** It blocks Gate C authorization and any claim of owner approval.

## 8. Classification

| Aspect | Status |
|---|---|
| Need for correction | **CONFIRMED** |
| Proposed wording | **PROPOSAL** |
| Signature/date | **OWNER ACTION REQUIRED** |
| Blocks Gate C | **YES** |
