# 13 — Gate Sequencing, Dependencies, Rollback and Deployment Plan

**Scope:** How a future approved implementation should be sequenced. **No gate is executed.**

---

## 1. Gate matrix

| Gate | Scope | Status | Prerequisite |
|---|---|---|---|
| A | Architecture + D1–D14 | **APPROVED per Phase 5 brief; signed Phase 4 record missing** | — |
| B | Flutter/Kotlin/Edge source + unit tests | **NOT AUTHORIZED** | A; C contract frozen |
| C | Table, RPCs, RLS, grants | **NOT AUTHORIZED** | A; contract frozen |
| D | Deploy to named environment | **NOT AUTHORIZED** | B + C for that environment |
| E | One approved test-device recovery | **NOT AUTHORIZED** | D; rollback plan |
| F | Two-device regression | **NOT AUTHORIZED** | E core path |
| — | Production | **NOT AUTHORIZED** | Separate decision |

A ≠ B ≠ C ≠ D ≠ E ≠ F. A phase report never authorizes the next gate.

---

## 2. Can Gate B precede Gate C?

| Work | Before C? | Reason |
|---|---|---|
| Flutter models/UI scaffolding | Yes | mock repository |
| Flutter repository calls | Written yes, functional no | endpoint returns unknown_action until handlers/C exist |
| Kotlin state/resync | Yes | independent |
| Edge handlers | Written yes, functional no | RPC missing |
| Atomic-behaviour tests | **No** | mock would not prove security |

**Recommendation:** freeze contract → Gate C → Gate B Edge → Gate B client, with Flutter/Kotlin allowed to start in parallel only against the frozen contract and with the feature flag off.

---

## 3. Pre-implementation decisions to freeze

1. Parent re-validation at redeem: **any active parent** (recommended) vs creator only.
2. Attempt accounting placement: separate committed RPC (recommended).
3. Status/cancel actions in MVP: recommended yes.
4. Code format: 8-char 30-symbol alphabet (recommended).
5. Rate-limit numbers from report 11: **not approved**.
6. Feature flag name/default: server flag, default off.
7. Expiry sweeper: lazy + optional cron.

---

## 4. Execution sequence

### Step 0 — Contract freeze (no gate)
Resolve §3; publish frozen RPC signatures and JSON contracts.

### Step 1 — Gate C
1. Additive migration: table, constraints, indexes, RLS, grants, RPCs.
2. SQL tests + race script.
3. Security review: owner, search_path, execute grants, lock order.
4. Freeze error codes.

### Step 2 — Gate B Edge
1. `_shared/recovery.ts` helpers.
2. `family-admin` actions.
3. `device-register` action.
4. Edge unit tests + wiring pins.
5. Feature flag off.

### Step 3 — Gate B Flutter
Models → repository → Parent UI → Child UI → tests.

### Step 4 — Gate B Kotlin
State keys → classification → bridge → tests.

### Step 5 — Unit verification
FU + KU + EU; static review: no `devices` update outside RPC; no secret logging.

### Step 6 — Gate D (named environment)
Deploy migration + functions; enable flag for test tenant; run staging matrix; record versions/checksum.

### Step 7 — Gate E
One approved test device; verify same UUID, heartbeat, audit, old credential 401; rehearse rollback.

### Step 8 — Gate F
Full 24-scenario matrix + compatibility + reinstall/reboot/races.

### Step 9 — Production
Separate written authorization, named environment, separate rollback plan.

---

## 5. Dependency graph

```
A (asserted approved)
│
├── contract freeze
│      ├── C ──► C tests
│      │            │
│      └── B Edge ──┤
│                   ▼
│            B Flutter/Kotlin
│                   ▼
│              unit verification
│                   ▼
│                 D staging
│                   ▼
│                 E one device
│                   ▼
│                 F two-device
│                   ▼
│            production (separate)
```

---

## 6. Branch and review strategy (proposal)

- Branch `feature/device-recredentialing`.
- Commit 1: Gate C migration + SQL tests (security review).
- Commit 2: Edge helpers/handlers + tests.
- Commit 3: Flutter.
- Commit 4: Kotlin.
- Commit 5: docs.
- Feature flag off in every commit.
- No deployment config or secrets committed.

---

## 7. Rollback

| Stage | Rollback |
|---|---|
| Gate C migration | additive; drop table/RPC reverts to current 409/401; rotated devices keep working |
| Gate B handlers | flag off → `503 recovery_disabled`; existing endpoints unchanged |
| Gate B clients | older APK lacks UI; server state harmless |
| Gate D | redeploy previous function versions; reverse migration |
| Gate E/F | destructive `recover_device` remains available, separately labelled |

No rollback path may invalidate a successfully rotated credential.

---

## 8. Deployment constraints

- One environment per Gate D decision.
- Migration checksum + function versions recorded.
- Kill switch verified before enabling.
- No Supabase CLI/Management API in this planning phase.
- No APK build/install in this phase.

---

## 9. What must not happen

- No Edge-side multi-statement credential update.
- No enabling before Gate D.
- No treating Gate A as B/C.
- No Gate E/F without written approval.
- No E2E-002/003/004 or deferred features in scope.
