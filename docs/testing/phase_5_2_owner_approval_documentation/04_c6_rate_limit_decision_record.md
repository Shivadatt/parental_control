# 04 — C6 Rate-Limit Decision Record

**Status:** Five proposals remain **NEW RECOMMENDATIONS — PENDING OWNER DECISION**.  
**Approved numerical limits:** only **10-minute challenge TTL** and **5 attempts** (D2, conversation-based Gate A approval, 2026-11-21).  
Source: `docs/testing/phase_5_1_owner_decision_reconciliation/05_c5_c6_decision_analysis.md:80-207`.

---

## 1. Approved limits (for contrast)

| Limit | Value | Status |
|---|---:|---|
| Challenge TTL | 10 minutes | **APPROVED (D2)** |
| Max attempts per challenge | 5 | **APPROVED (D2)** |

No other number in this report is approved.

---

## 2. Proposed limit L1 — One pending challenge per device

| Attribute | Record |
|---|---|
| Proposed value | **1** |
| Status | **NEW RECOMMENDATION** |
| Scope | `device_id` |
| Counting | rows with `status='pending'` for the device |
| Reset | new request supersedes old; consume/expire/cancel removes it from pending |
| Concurrency | partial unique index on `device_id where status='pending'`; request RPC locks the device and supersedes |
| Failure behaviour | second simultaneous approval is impossible; the Parent must wait or reissue |
| Security rationale | prevents duplicate live codes, UI ambiguity and code spam |
| Trade-off | cannot run two approvals for the same device concurrently (intended) |

**Classification:** schema invariant as much as a rate limit. If C6 is approved, this is the minimum necessary value. **Blocks Gate C** if supersede semantics are to be enforced.

---

## 3. Proposed limit L2 — Five challenge requests per device per hour

| Attribute | Record |
|---|---|
| Proposed value | **5 per rolling 60 minutes** |
| Status | **NEW RECOMMENDATION** |
| Scope | `device_id` |
| Counting | all challenge rows created for the device in the last 60 minutes |
| Reset | rolling window; oldest row ages out |
| Concurrency | count is advisory; L1 unique index is authoritative for pending; exact enforcement requires serializing on the device row |
| Failure behaviour | 429 with `retry_after_seconds`; destructive recovery remains available |
| Security rationale | bounds repeated code generation/spam to a child |
| Trade-off | a legitimate Parent retrying >5 times/hour is blocked; 5 is generous for normal use |

**Gate C impact:** not a schema requirement; can be tuned at the Edge layer. Freeze initial value before Gate D.

---

## 4. Proposed limit L3 — Ten challenge requests per Parent per hour

| Attribute | Record |
|---|---|
| Proposed value | **10 per rolling 60 minutes** |
| Status | **NEW RECOMMENDATION** |
| Scope | `created_by` (parent user id) |
| Counting | challenge rows created by that parent in the last 60 minutes |
| Reset | rolling window |
| Concurrency | advisory; per-device L1/L2 bound the effect |
| Failure behaviour | 429; other parents in the family can still act |
| Security rationale | bounds a compromised/malicious parent spamming many devices |
| Trade-off | a parent with many children/devices could approach 10; 10 is likely sufficient |

**Gate C impact:** Edge-level; freeze before Gate D.

---

## 5. Proposed limit L4 — Ten failed redemptions per Child per ten minutes

| Attribute | Record |
|---|---|
| Proposed value | **10 per rolling 10 minutes** |
| Status | **NEW RECOMMENDATION** |
| Scope | `child_user_id` (authenticated Child attempting redemption) |
| Counting | failed redemption attempts in the last 10 minutes: wrong code, wrong device, expired, forbidden, exhausted |
| Reset | rolling window; successful redemption removes the need to continue counting |
| Concurrency | advisory count; per-challenge 5-attempt cap is the hard limit |
| Failure behaviour | 429; the Child can retry after the window or ask for a new code |
| Security rationale | bounds a session thief or typo-prone Child across challenges |
| Trade-off | a legitimate Child with repeated typos can be temporarily blocked; 10 is generous |

**Gate C impact:** Edge-level; implement after the committed attempt increment so the count reflects reality.

---

## 6. Proposed limit L5 — Twenty failed redemptions per family per ten minutes

| Attribute | Record |
|---|---|
| Proposed value | **20 per rolling 10 minutes** |
| Status | **NEW RECOMMENDATION** |
| Scope | `family_id` derived from the challenge |
| Counting | failed redemption attempts across the family's challenges in the last 10 minutes |
| Reset | rolling window |
| Concurrency | advisory; per-challenge and per-child limits are primary |
| Failure behaviour | 429; should not reveal which family/device hit the limit to a non-member |
| Security rationale | bounds distributed guessing across several Child sessions/devices in one family |
| Trade-off | a large family with several children could hit 20 during coordinated mistakes; unlikely |

**Gate C impact:** Edge-level; freeze before Gate D.

---

## 7. Enforcement mechanics (all proposals)

- Rolling windows, not fixed calendar buckets.
- Count request limits from `device_recredential_challenges` rows.
- Count failed redemptions from attempt/denial records (or a dedicated table if chosen).
- **Fail closed** if the count query errors.
- Return `429` with `retry_after_seconds`.
- Per-challenge `attempts` in the RPC is authoritative; Edge limits are the first line.
- Do **not** use IP addresses (shared NAT/carrier-grade NAT false positives).

### Concurrency caveat
`SELECT count(*)` then insert is racy. The per-device unique pending index prevents duplicate pending rows but not >5 created rows. Exact enforcement requires serializing on the device row (`FOR UPDATE`) and counting inside the transaction. Recommended for L2; approximate counting is acceptable for L4/L5 because the per-challenge cap is hard.

---

## 8. Abuse scenarios covered

| Scenario | Limits |
|---|---|
| Parent spams codes to one child | L1, L2 |
| Parent spams many devices | L3 |
| Child session thief guesses codes | per-challenge 5, L4, L5 |
| Distributed guessing across child sessions | L5 |
| Many parent accounts | L2/L5 still apply; account creation is out of scope |
| Network identity rotation | not applicable; limits are account/device/family based |

---

## 9. Decision required

The owner must explicitly **approve, reject or replace each** of L1–L5. Silence or a general "approved" without values is not sufficient.

| ID | Proposal | Owner decision |
|---|---|---|
| L1 | 1 pending/device | **PENDING** |
| L2 | 5 requests/device/hour | **PENDING** |
| L3 | 10 requests/parent/hour | **PENDING** |
| L4 | 10 failed/child/10 min | **PENDING** |
| L5 | 20 failed/family/10 min | **PENDING** |

---

## 10. Gate impact

- **L1** is a schema invariant and **blocks Gate C** if accepted.
- **L2–L5** are Edge-level and can be tuned, but the initial values should be frozen before Gate D to avoid behavioural churn.
- None of L1–L5 is approved today.
