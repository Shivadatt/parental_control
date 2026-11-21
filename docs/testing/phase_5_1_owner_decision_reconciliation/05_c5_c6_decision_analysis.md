# 05 — C5 and C6 Decision Analysis

**Scope:** Feature flag (C5) and rate limits (C6). No implementation.

---

# C5 — Feature flag

## 1. Exact question

How should the recovery feature be gated so it can be deployed without being active, and enabled per environment/tenant?

## 2. Existing decisions

- Phase 5 report `07_edge_function_api_contracts.md:177` requires a server-side flag.
- `phase_5.../13_gate_dependency_and_execution_sequence.md:44` recommends a server flag, default off.
- D13 keeps destructive recovery available, so disabling the new flow does not strand users; it only preserves the current 409/401 behaviour.

No approved decision fixes the flag mechanism or default. This is a **new implementation decision**, not a reinterpretation of D1–D14.

## 3. Recommended option

**Server-side flag, default OFF, checked in both Edge actions; RPCs remain callable only by the service role.**

Behaviour:
- flag off → both recovery actions return `503 recovery_disabled` with a safe message.
- flag on → normal flow.
- the flag is **not** sent to clients; clients never decide.
- the flag is evaluated per request in the Edge handler (not cached indefinitely).
- migration/table/RPC may exist while the flag is off; that is inert and rollback-friendly.

### Why server-side
- A client-side flag is cosmetic and bypassable by an old build or a direct HTTP call.
- A server-side flag is the only enforceable switch.
- Because the RPCs grant execute to `service_role` only, an ordinary client cannot bypass the Edge check by calling the RPC directly. Anyone with the service key can bypass anything, which is outside this threat model.

## 4. Alternatives

| Option | Assessment |
|---|---|
| Build-time flag | Requires two builds; not a runtime kill switch |
| Client flag only | Bypassable; reject |
| Per-tenant flag table | More flexible; more complexity and a new admin surface |
| Environment env var | Simple; requires redeploy to change; acceptable MVP |
| Trusted server config table | Best runtime control; needs a read path and caching |

Recommended MVP: **environment-level server setting** (or function secret) checked at the start of each action, with a clear default off. A per-tenant table can come later.

## 5. Failure behaviour

- If the flag read fails → **fail closed** (`503 recovery_disabled` or `503 server_misconfigured`), never fall through to enabled.
- If the flag is missing → default off.
- Disabling after a challenge was created: existing pending challenges should fail closed at redeem; they expire naturally. The owner may prefer to allow in-flight completion — that is a policy choice.

## 6. Rollout

1. Deploy migration/RPC with flag off (Gate D).
2. Enable for a named test tenant/family.
3. Run Gate E.
4. Enable for the test environment.
5. Production only after separate approval.

## 7. Dependencies

- Edge helper/flag read.
- Error code `recovery_disabled`.
- Tests: off → 503; on → normal; flag-read failure → 503.
- Deployment runbook.

## 8. Must it be decided before Gate C?

**No for Gate C** (the table/RPC can exist), **yes for Gate B/D**. It should be frozen before the Edge handlers are wired so the error contract is stable.

## 9. Can it be deferred?

**No.** Without a flag, the only rollout control is deploy/undeploy, which is riskier. It can be implemented after the core but before Gate D.

---

# C6 — Rate limits

## 1. Status of the numbers

**Already approved:**
- challenge TTL = **10 minutes** (D2);
- max attempts per challenge = **5** (D2).

**Everything else below is a NEW RECOMMENDATION**, not an approved value. They are derived from the existing `_shared/rate_limit.ts` patterns.

## 2. Limit-by-limit analysis

### L1 — One pending challenge per device

| Attribute | Value |
|---|---|
| Proposed | **1** |
| Scope | `device_id` |
| Counting | rows with `status='pending'` for the device |
| Reset | new pending supersedes the old; consume/expire/cancel removes the pending row from the count |
| Concurrency | unique partial index on `device_id where status='pending'`; request RPC locks the device and supersedes |
| Abuse prevented | duplicate/multiple live codes for one phone; UI ambiguity; code spam |
| Failure mode | a Parent cannot have two simultaneous approvals for the same device (intended) |
| Bypass | none at the DB level if the partial unique index exists |

**Assessment:** strongly recommended; it is as much a consistency invariant as a rate limit. Blocking for Gate C if supersede semantics are to be enforced.

### L2 — Five challenge requests per device per hour

| Attribute | Value |
|---|---|
| Proposed | **5** |
| Scope | `device_id` |
| Counting | challenge rows created for the device in a rolling 60-minute window, all statuses |
| Reset | rolling window; oldest row ages out |
| Concurrency | two requests can race; count query is advisory, the partial unique index is authoritative |
| Abuse prevented | repeated code generation spam to a child; notification/UI flooding |
| Failure mode | a legitimate Parent retrying >5 times in an hour is blocked; they can still use the destructive recovery |
| Bypass | switching Parent accounts does not bypass the per-device limit |

**Assessment:** reasonable. Five failures/retries in an hour is generous for legitimate use. Could be lowered to 3 if support burden is low.

### L3 — Ten challenge requests per Parent per hour

| Attribute | Value |
|---|---|
| Proposed | **10** |
| Scope | `created_by` (parent user id) |
| Counting | challenge rows created by that parent in a rolling 60-minute window |
| Reset | rolling window |
| Concurrency | count is advisory; per-device L1/L2 still bound the effect |
| Abuse prevented | a compromised/malicious parent spamming many devices/families |
| Failure mode | a parent with many children/devices could hit 10; 10 is likely sufficient |
| Bypass | a second Parent account bypasses the per-parent count, but per-device and per-family limits still apply |

**Assessment:** reasonable. Consider 20/hour if a family has many devices; not necessary for the common case.

### L4 — Ten failed redemptions per Child per 10 minutes

| Attribute | Value |
|---|---|
| Proposed | **10** |
| Scope | `child_user_id` (the authenticated Child attempting redemption) |
| Counting | failed redeem attempts in a rolling 10-minute window; "failed" = wrong code, wrong device, expired, forbidden, or exhausted |
| Reset | rolling window; a successful redemption clears the need for the count |
| Concurrency | two attempts can both read the same count; the per-challenge `attempts` cap is the hard limit |
| Abuse prevented | a Child-account holder or session thief trying many codes |
| Failure mode | a legitimate Child with repeated typos can be temporarily blocked; 10 is generous |
| Bypass | switching Child sessions bypasses the per-child count, but each challenge has 5 attempts and per-family L5 applies |

**Assessment:** reasonable, but not a substitute for the per-challenge cap. Should be enforced **after** the committed attempt increment so the count matches reality.

### L5 — Twenty failed redemptions per family per 10 minutes

| Attribute | Value |
|---|---|
| Proposed | **20** |
| Scope | `family_id` (derived from the challenge, not the request) |
| Counting | failed redemption attempts across challenges in the family in a rolling 10-minute window |
| Reset | rolling window |
| Concurrency | advisory count; per-challenge cap and per-child limit are the primary controls |
| Abuse prevented | distributed guessing across several Child sessions/devices in one family |
| Failure mode | a large family with several children could hit 20 during a coordinated mistake; unlikely |
| Bypass | switching families is not possible without a valid challenge; creating a new family is a separate expensive path |

**Assessment:** reasonable upper bound. It should never reveal which family hit the limit to a non-member.

## 3. Counting and enforcement mechanics

Recommended:
- **Rolling windows**, not fixed calendar buckets (avoids burst-at-boundary).
- Count from `device_recredential_challenges` for request limits; count from the attempt/denial records for failed redemptions.
- **Fail closed** if the count query errors.
- Return `429` with `retry_after_seconds`.
- Per-challenge `attempts` is authoritative in the RPC; Edge limits are the first line.
- Do not use IP addresses (shared NAT/carrier-grade NAT false positives).

### Concurrency caveat
A pure `SELECT count(*)` followed by an insert is racy: two requests can both see 4 and both insert, producing 6. The per-device partial unique index prevents duplicate **pending** rows, but not >5 **created** rows. If the limit must be exact, either:
- serialize on the device row (`FOR UPDATE`) and count inside the same transaction; or
- accept a small overrun and rely on the pending cap.

Recommended: serialize request creation on the device row; accept approximate failed-redemption counts because the per-challenge cap is hard.

## 4. Abuse scenarios

| Scenario | Limits that apply |
|---|---|
| Parent spams codes to one child | L1, L2 |
| Parent spams many devices | L3 |
| Child session thief guesses codes | per-challenge 5, L4, L5 |
| Distributed guessing via many child sessions | L5 |
| Attacker creates many parent accounts | per-device L2 and per-family L5 still apply; account creation is out of scope |
| Network identity rotation | not relevant; limits are account/device/family based |

## 5. Must it be decided before Gate C?

**Yes for L1** (DB partial unique index) and the presence/absence of the counter queries. **No for exact L2–L5 values**, which can be tuned at the Edge layer after Gate C, but they should be frozen before Gate B/D to avoid behavioural churn.

## 6. Can it be deferred?

- L1: **no** (schema invariant).
- L2–L5: **partially**; a conservative default can ship and be tuned, but the owner should approve the initial values.

## 7. Recommendation summary

| Limit | Proposed | Recommendation |
|---|---:|---|
| Pending/device | 1 | Approve (schema invariant) |
| Requests/device/hour | 5 | Approve initial value |
| Requests/parent/hour | 10 | Approve initial value |
| Failed/child/10 min | 10 | Approve initial value |
| Failed/family/10 min | 20 | Approve initial value |

Only **10-minute TTL** and **5 attempts** are approved today.
