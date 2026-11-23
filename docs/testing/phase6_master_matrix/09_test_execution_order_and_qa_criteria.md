# 09 — Test Execution Order and QA Criteria

This is a proposed future sequence. Nothing here authorizes execution.

## 1. Recommended order

1. **Environment and baseline verification** — D01–D20; build identity, sessions, family, pairing, credentials, permissions, timezone, backend, safe test environments, and observation parameters.
2. **Parent-only non-destructive tests** — dashboard, family, devices, usage, location, alerts, audit, settings.
3. **Child-only non-destructive tests** — home, rules, requests, identity, protection, permissions, background service.
4. **Shared functionality tests** — Parent and Child variants where behaviour differs.
5. **Parent–Child interconnected tests** — paired-device observations and approved synchronization scenarios.
6. **Partially implemented tests** — supported behavior first, then limitation/failure scenarios.
7. **UI-only verification** — visibility, change, persistence, and absence of notification/reminder behavior.
8. **Backend-only verification** — read-only source/schedule/log evidence; no write API, no retention execution.
9. **Security verification for SEC-001** — synthetic value only, no real credential, no submission.
10. **Approval-gated/destructive scenarios** — remain blocked until separately authorized.

### Why paired tests follow independent baselines

Paired tests can only distinguish synchronization failure from an offline device, broken permission, stale build, or invalid credential if each side is verified first. Otherwise every paired failure is ambiguous.

## 2. Stage gates

| Stage | Entry criterion | Exit criterion |
|---|---|---|
| Baseline | Owner authorizes execution | Dependencies verified or explicitly blocked |
| Parent non-destructive | Parent baseline PASS | Parent read-only cases executed or blocked |
| Child non-destructive | Child baseline PASS | Child cases executed or blocked |
| Shared | Both baselines PASS | Role differences documented |
| Interconnected | Both devices online and paired | Observations correlated |
| Partial | Known limitation documented | Supported and limitation scenarios distinguished |
| UI/backend | Approval for writes | Read-only evidence sufficient |
| Security | Security review authorized | SEC-001 evidence safe and complete |
| Destructive | Explicit owner approval per scenario | Scope, backup, restoration confirmed |

**Absolute exception:** no stage gate or owner approval authorizes sign-out, session replacement or invalidation, credential change, secure-storage reset, app-data clearing, or reinstall against the preserved QA accounts. Those actions are prohibited regardless of risk classification; future authentication testing requiring a session change must use a separately approved isolated environment.

Interconnected timing values are **PROPOSED — OWNER REVIEW REQUIRED** and are not application SLAs. They are proposed, not approved, not validated by runtime QA, and owner acceptance or revision is pending. Do not treat them as approved thresholds.

## 3. Result definitions

- **NOT TESTED** — planned but not executed.
- **PASS** — executed with all expected results confirmed by valid evidence.
- **FAIL** — executed and one or more expected results demonstrably failed.
- **BLOCKED — DEPENDENCY NOT VERIFIED** — required prerequisite missing.
- **BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED** — needs separate approval.
- **NOT APPLICABLE** — outside supported scope with rationale.
- **INCONCLUSIVE** — evidence insufficient.

A static finding is never PASS. A visible button is not proof. An API response is not proof of correct end-to-end behavior.

## 4. Risk definitions

| Risk | Definition |
|---|---|
| **LOW** | Read-only UI navigation, viewing existing data, or non-mutating observation. No persistent account, family, device, policy, or backend changes. |
| **MEDIUM** | Reversible local or application operation. May change a preference or transient state; requires documented restoration or cleanup. Must not affect the preserved Parent/Child QA relationship. |
| **HIGH** | Persistent account, family, pairing, device, policy, permission, or backend state change. Requires explicit owner approval before execution and a documented impact and restoration plan. |
| **DESTRUCTIVE** | Deletes, revokes, unlinks, wipes, resets, rotates, purges, or irreversibly changes identity or data. Always blocked until separate explicit owner approval and requires a specific recovery/restoration plan. |

Existing risk levels are not downgraded to make cases executable.

## 5. Evidence standards

- Timestamped screenshots from the actual device and role.
- UI hierarchy dumps when the claim depends on node state.
- Redacted logs for sync, permissions, backend, or service state.
- Both-device evidence for interconnected cases.
- Before/after evidence for reversible changes.
- Explicit empty, stale, error, and unknown states; no placeholder is data.
- No passwords, tokens, secrets, or unredacted personal data.

## 6. Exit and readiness criteria

Matrix exit: all 80 IDs traceable; executed cases evidenced; blocked cases name the exact dependency or approval; no false PASS; SEC-001 and ten gaps separate; destructive scenarios gated.

Application readiness is not declared here. Release readiness requires later runtime evidence, resolution or acceptance of partial items, and owner decisions on absent capabilities and SEC-001.
