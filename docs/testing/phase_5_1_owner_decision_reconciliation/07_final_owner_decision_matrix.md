# 07 — Final Owner Decision Matrix

**Purpose:** Single reconciliation table for Gate A, D1–D14, C1–C8 and the proposed numerical limits.  
**Rule:** Nothing in this table is approved by appearing here. "ASSERTED" means the Phase 5 brief says approved; the repository does not document it.

---

## 1. Status legend

| Status | Meaning |
|---|---|
| **APPROVED (DOCUMENTED)** | Signed/recorded in a repository artifact |
| **APPROVED (ASSERTED)** | Stated in the Phase 5 brief; no repository signature |
| **RECOMMENDATION** | Proposed only |
| **OWNER DECISION REQUIRED** | Must be chosen |
| **DEFERRABLE** | Can be postponed without blocking Gate C |
| **BLOCKS GATE C** | Contract cannot freeze without it |

---

## 2. Gate A

| ID | Item | Evidence | Status | Blocks Gate C |
|---|---|---|---|---|
| A | Option C architecture | Phase 4 rec; Phase 5 brief assertion | **APPROVED (ASSERTED)** | **Yes** (documentation) |
| A-1 | D1–D14 value-level record | Phase 4 table OPEN | **NOT DOCUMENTED** | **Yes** |

---

## 3. D1–D14

| ID | Decision | Phase 4 recommendation | Evidence status | Blocks Gate C |
|---|---|---|---|---|
| D1 | Short code + optional QR, out-of-band | Recommended | **ASSERTED** | Yes (code format is C4) |
| D2 | 10-minute TTL / 5 attempts | Recommended | **ASSERTED** | Yes |
| D3 | Any active parent may approve | Recommended | **ASSERTED** | Yes (C1 extends it) |
| D4 | Parent-only initiation | Recommended | **ASSERTED** | No (client scope) |
| D5 | End active remote sessions | Recommended | **ASSERTED** | Yes (RPC behaviour) |
| D6 | Preserve `policy_version` | Recommended | **ASSERTED** | Yes (RPC fields) |
| D7 | Preserve display name; update platform/version | Recommended | **ASSERTED** | Yes (RPC fields) |
| D8 | Commit attempt accounting first | Recommended | **ASSERTED** | Yes (C2 mechanism) |
| D9 | 200 on installation ID + hash match | Recommended | **ASSERTED** | Yes (RPC idempotency) |
| D10 | Defer parent step-up auth | Recommended | **ASSERTED** | No |
| D11 | Defer server-visible credential health | Recommended | **ASSERTED** | No |
| D12 | Optional in-app audit notification | Recommended | **ASSERTED** | No |
| D13 | Retain destructive recovery | Recommended | **ASSERTED** | No |
| D14 | Keep E2E-002 separate | Recommended | **ASSERTED** | No |

**Note:** "ASSERTED" is weaker than "documented". C8 asks the owner to sign the value-level record.

---

## 4. C1–C8

| ID | Decision | Recommendation | Alternatives | Classification | Blocks Gate C | Owner decision |
|---|---|---|---|---|---|---|
| C1 | Parent re-validation at redeem | Any active parent in the family | Creator only; no re-check (unsafe) | **OWNER DECISION REQUIRED** | **Yes** | **PENDING** |
| C2 | Attempt-accounting mechanism | Separate committed RPC (implements D8) | Inside redeem (violates D8); Edge direct update | **MECHANISM CONFIRMATION** | **Yes** | **PENDING** |
| C3 | Status + cancel in MVP | Include both (status first if scope shrinks) | Status only; cancel only; neither | **OWNER DECISION REQUIRED** | **Yes for scope** | **PENDING** |
| C4 | Code format | 8×30 + optional QR; keyed hash | 10×30; 12×30; QR-only; 6×30 (reject) | **OWNER DECISION REQUIRED** | **Yes** | **PENDING** |
| C5 | Feature flag | Server-side, default off, fail closed | Build-time; client-only (reject); per-tenant table | **OWNER DECISION REQUIRED** | No (Gate B/D) | **PENDING** |
| C6 | Rate limits | See §5 | Lower/higher values | **OWNER DECISION REQUIRED** | **Yes for L1** | **PENDING** |
| C7 | Expiry sweeper | Lazy mandatory; sweeper optional | Sweeper required; lazy only | **DEFERRABLE** | No (lazy required) | **PENDING** |
| C8 | Signed Gate A record | Owner-signed addendum | Edit original (not recommended) | **BLOCKS AUTHORIZATION** | **Yes** | **PENDING** |

---

## 5. Numerical limits

| ID | Limit | Value | Status | Blocks Gate C |
|---|---|---|---|---|
| N1 | Challenge TTL | 10 minutes | **APPROVED (ASSERTED D2)** | Yes |
| N2 | Attempts per challenge | 5 | **APPROVED (ASSERTED D2)** | Yes |
| N3 | Pending challenges per device | 1 | **RECOMMENDATION** | **Yes** (partial unique index) |
| N4 | Challenge requests per device per hour | 5 | **RECOMMENDATION** | No (Edge tuneable) |
| N5 | Challenge requests per parent per hour | 10 | **RECOMMENDATION** | No |
| N6 | Failed redemptions per child per 10 min | 10 | **RECOMMENDATION** | No |
| N7 | Failed redemptions per family per 10 min | 20 | **RECOMMENDATION** | No |
| N8 | Code format | 8 chars, 30-symbol alphabet | **RECOMMENDATION** | Yes (C4) |

Only N1/N2 are approved (asserted). N3 is effectively a schema invariant and should be approved with C6.

---

## 6. Decisions that can be deferred safely

| Item | Why safe |
|---|---|
| D10 step-up auth | Residual risk accepted; audit/TTL remain |
| D11 server-visible health | Presence still derives from heartbeat |
| D12 push notification | In-app audit is enough; FCM not implemented |
| C5 feature flag implementation | Can be added before Gate D; but decide the default now |
| C7 sweeper | Lazy expiry protects correctness |
| N4–N7 tuning | Edge-level values can be adjusted without schema change, but freeze initial values before Gate D |

---

## 7. Decisions that block Gate C contract finalization

1. **C8** — signed Gate A/value record (authorization, not schema).
2. **C1** — parent re-validation predicate.
3. **C2** — attempt RPC/grants shape.
4. **C3** — whether status/cancel RPCs are in the migration.
5. **C4** — code length/alphabet validation.
6. **C6/N3** — one pending challenge per device (partial unique index).
7. **D2 asserted values** — TTL/attempts must be confirmed in the signed record.

---

## 8. What is already decided vs not

### Decided (asserted)
Option C, D1–D14 recommendations as values, 10-minute TTL, 5 attempts.

### Not decided
C1–C8, all other numerical limits, signed Gate A record.

### Not authorized
Gate B source changes, Gate C schema/RPC, Gate D deployment, Gate E recovery, Gate F regression.

---

## 9. Matrix verdict

**The contract is not frozen.** It can be frozen immediately after the owner decides C1, C2, C3, C4, C6/N3 and signs C8. C5 and C7 can be finalized in parallel or deferred as noted.
