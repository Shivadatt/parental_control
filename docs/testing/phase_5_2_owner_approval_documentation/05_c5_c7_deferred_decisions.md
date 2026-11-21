# 05 — C5 and C7 Deferred Decisions

**Status:** Both are **NEW RECOMMENDATIONS**. Neither is approved. Both are recorded here as **DEFERRED** to a named later gate where the Phase 5.1 analysis supports deferral.

Source: `docs/testing/phase_5_1_owner_decision_reconciliation/05_c5_c6_decision_analysis.md:7-78` and `06_c7_c8_decision_analysis.md:7-79`.

---

# C5 — Server-side feature flag

**Status: NEW RECOMMENDATION — DEFERRED to Gate B/D implementation.**

## Recommendation
- Server-side only.
- Default **OFF**.
- Checked at the start of both recovery Edge actions.
- Off → `503 recovery_disabled` with a safe message.
- Flag-read failure → **fail closed**.
- Never a client-side flag.

## Alternatives
| Option | Assessment |
|---|---|
| Server-side env/function setting (recommended MVP) | Enforceable; no new admin surface; redeploy to change |
| Per-tenant config table | Flexible; more complexity |
| Build-time flag | Two builds; not a runtime kill switch |
| Client-only flag | Bypassable; reject |

## Why defer
Gate C can create the table/RPC with the flag off. Gate B can wire the flag. Gate D is the first point where the flag must actually be switchable. C5 does not block the Gate C schema contract.

## Security implications
- A client cannot bypass the Edge check; RPCs remain service-role-only.
- Anyone with the service key bypasses everything, which is outside this threat model.
- Fail-closed protects against misconfiguration.

## Operational implications
- Rollout: deploy off → enable for a named test tenant/family → Gate E → test environment → production separately.
- Disabling after a challenge exists: pending challenges should fail closed at redeem or expire; choose an in-flight policy before Gate D.
- Flag name, default and failure code must be frozen before Gate D.

## Dependencies
- Edge flag read.
- `503 recovery_disabled` error contract.
- Tests: off → 503; on → normal; read failure → 503.
- Deployment runbook.

## Gate placement
**Decision can be deferred to Gate B/D.** It does not block Gate C contract finalization.

---

# C7 — Expiry sweeper

**Status: NEW RECOMMENDATION — DEFERRED (sweeper only).**

## Recommendation
- **Lazy expiration is mandatory**: every RPC that reads a challenge must compare `expires_at <= now()` under lock.
- A scheduled sweeper is **optional hygiene** and can be deferred.
- If a status endpoint exists, it must derive `expired` from the timestamp even if the row is still `pending`.

## Alternatives
| Option | Assessment |
|---|---|
| Lazy only (recommended for correctness) | No scheduler; stale pending rows are cosmetic |
| Scheduled sweeper | Clean state; adds cron/monitoring/privileged path |
| Both | Best long-term: lazy + hygiene |

## Why defer
Correctness — "an expired challenge cannot rotate" — depends on the timestamp check, not on a job. A sweeper only improves status accuracy and table hygiene. It can be added after Gate C without changing the credential transaction.

## Security implications
- Expired challenges cannot redeem if every RPC checks expiry.
- A sweeper must never rotate or delete a device; it only marks `expired`.
- A sweeper failure degrades hygiene, not security.

## Operational implications
- Lazy-only: simpler deploy/rollback.
- Sweeper: needs schedule, monitoring, audit event, retention policy.
- Retention (e.g., 90-day challenge purge) is a separate ops task.

## Dependencies
- Gate C RPC timestamp checks (mandatory).
- Optional cron/DB job and audit event if the sweeper is approved.
- Status endpoint (if C3) computes expiry.

## Gate placement
- **Lazy check:** required in Gate C; not deferrable.
- **Sweeper:** **DEFERRED** to post-Gate C or Gate D operations; not a contract blocker.

---

## Deferral summary

| Item | Status | Deferred to | Contract blocker? |
|---|---|---|---|
| C5 server flag | **NEW RECOMMENDATION / DEFERRED** | Gate B/D | No |
| C7 lazy expiry | **REQUIRED design element, not separately approved** | Gate C | Yes (RPC behaviour) |
| C7 sweeper | **NEW RECOMMENDATION / DEFERRED** | Post-Gate C / Gate D ops | No |

No item in this report is approved. C5 and C7 remain outside the Gate A approval.
