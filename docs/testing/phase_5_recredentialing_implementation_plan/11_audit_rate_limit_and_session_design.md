# 11 — Audit Logging, Session Invalidation, Notifications and Abuse Control

**Scope:** Operational/security controls for the recovery flow. Planning only.

---

## 1. Audit events

| Event | Writer | Transaction | Metadata (no secrets) |
|---|---|---|---|
| `device_recredential_requested` | request RPC | same tx | device_id, child_user_id, challenge_id, expires_at, created_by, superseded_id |
| `device_recredential_superseded` | request RPC | same tx | old_challenge_id, new_challenge_id |
| `device_recredential_cancelled` | cancel RPC | same tx | challenge_id |
| `device_recredential_denied` | Edge | best-effort | reason, challenge_id (never code) |
| `device_recredential_expired` | sweeper/Edge | best-effort | challenge_id |
| `device_recredentialed` | redeem RPC | same tx | device_id, child_user_id, challenge_id, created_by, method, sessions_ended |

Existing conventions:
- `audit_logs` 1–80 char event type (`core.sql:375-390`).
- Edge `recordAudit` fails closed (`_shared/audit.ts:17-40`).
- SQL `private.record_audit` for transactional inserts.
- UI labels in `lib/data/models/audit.dart:29-73` need new cases.

**Forbidden in metadata:** raw secret, `secret_hash`, challenge code, JWT, service key, full installation ID.

---

## 2. Session invalidation (D5)

In the redeem transaction, for the target `device_id`:
- `requested|accepted|active` → `ended`;
- `ended_at=now()`, `ended_by=child_user_id`, `ended_reason='device_recredentialed'`;
- count included in audit.

Do not touch `declined|failed|expired`.
Model: `private.revoke_device` (`functions.sql:474-478`).

Rationale: the lost install must not retain an assistance/capture authorization.

---

## 3. Notifications (D12)

- **In-app only:** audit row and a device-detail/audit-tab label.
- **No push/FCM** — `NOT IMPLEMENTED` and out of scope.
- Parents other than the actor can see the audit entry because audit reads are family-scoped (`SupabaseAuditRepository.fetchAuditLogs`).
- Optional UI: a banner on device detail when a challenge is pending for another parent.

---

## 4. Observability

Allowed log fields:
`event`, `family_id`, `device_id`, `challenge_id`, `status`, `error_code`, `attempts`, `duration_ms`.

Forbidden: request/response bodies, headers, secret, hash, code, JWT, installation ID.

Add a test that scans captured logs/audit for secret-shaped values.

---

## 5. Rate limits — proposals

**No rate-limit numbers beyond D2 are approved.** The following are **NEW RECOMMENDATIONS** derived from the existing `_shared/rate_limit.ts` patterns. They must be owner-approved before Gate C.

| Limit | Proposed value | Scope | Protects against | Source/status |
|---|---|---|---|---|
| Challenge TTL | **10 minutes** | per challenge | replay window | **APPROVED D2** |
| Max attempts | **5** | per challenge | guessing | **APPROVED D2** |
| Pending challenges | **1** | per device | spam/duplicate flows | **NEW RECOMMENDATION** (DB partial unique) |
| Challenge requests | **5 per hour** | per device | code spam to a child | **NEW RECOMMENDATION** |
| Challenge requests | **10 per hour** | per parent | abuse across devices | **NEW RECOMMENDATION** |
| Failed redemptions | **10 per 10 minutes** | per child | distributed guessing | **NEW RECOMMENDATION** |
| Failed redemptions | **20 per 10 minutes** | per family | family-wide abuse | **NEW RECOMMENDATION** |

Existing reference values (not recovery limits): pairing failed attempts 5 per parent / 10 per token per 10 minutes; 10 code creations/hour; 5 live codes/24 h; 3 pending invites; 10 invites/24 h (`_shared/rate_limit.ts:10-18`).

### Rationale
- 5 requests/hour/device and 10/hour/parent permit retries while bounding spam.
- 10/10 min per child and 20/10 min per family bound guessing without locking a whole family for one bad actor.
- 1 pending/device keeps the UX unambiguous and matches the supersede rule.

### Trade-offs
- Too strict: a family with repeated failures can be temporarily blocked.
- Too loose: code spam to a minor and guessing budget increase.
- Values should be configurable server-side, not hard-coded in clients.

### Bypass considerations
- Parent sessions can be switched; the per-device and per-family limits still apply.
- Network identity/IP is not used (avoids shared-NAT false positives).
- Device identity is not available before recovery; limits key on user/family/device rows.

---

## 6. Rate-limit enforcement placement

1. Edge: pre-check request/failed-redeem windows; return 429 with `retry_after_seconds`.
2. RPC: authoritative `attempts/max_attempts` and pending uniqueness; never rely on Edge alone.
3. Fail closed if the count query fails.

---

## 7. Retention

- Challenges: retain 90 days for audit, then purge (separate ops task).
- Audit: follows existing family retention.
- No credential material in either.

---

## 8. Unresolved

- Final approval of the six proposed rate-limit values.
- Whether to add a dedicated attempts table or count challenge rows.
- Whether an expired-challenge sweeper is in MVP.
