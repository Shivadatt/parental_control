# 05 — Approval, Security, and Environment Audit

## 1. Approval register

`07_security_and_approval_required_register.md` contains APR-01 through APR-14, a total of 14 scenarios:

- Account deletion, family deletion, child unlink, device revoke, device re-registration
- Pairing cancellation/decline, credential recovery/rotation, secure-storage reset
- Local app-data deletion, remote lock/wipe, retention purge
- Parent leave-family, family owner transfer, reinstall/QA-relationship change

Each is marked `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED`. The register is correctly described as a minimum set, with case-level gates still binding.

## 2. Case-level gates

High and Destructive cases are generally gated. The split cases are properly separated:

| Read-only part | Gated action part |
|---|---|
| P6-PAR-004 list/empty | P6-PAR-036 cancel |
| P6-PAR-028 list/filter | P6-PAR-037 acknowledge |
| P6-CHD-016 service state | P6-CHD-020 restart |

P6-PAR-024, P6-SHR-012, and P6-SHR-013 are now read-only. P6-SHR-001 is read-only with positive sign-in separately blocked.

## 3. Session-preservation defect

**P6-SHR-005 is a sign-out case and must not be executable.** It appears in:

- `01_master_qa_test_matrix.md`, `## Planned test cases`
- `02_parent_mode_test_plan.md`, “Parent-side shared scenarios”
- `03_child_mode_test_plan.md`, “Child-side shared scenarios”
- `04_shared_and_interconnected_test_plan.md`, “Shared functionality”
- `10_matrix_coverage_and_traceability.md`, A05 row

The expected result is “session clears,” and the gate is explicit owner approval. The supporting policy also permits the action:

- `02_parent_mode_test_plan.md`, “Parent-mode notes”: “No case may sign out ... without approval.”
- `07_security_and_approval_required_register.md`, section 3: “High-risk writes that are reversible but change policy, retention, pairing, or sessions also require explicit approval.”
- `08_test_environment_and_dependency_register.md`, section 3: sign-out is “Prohibited without approval.”

This is a High safety defect. The existing Parent session is the evidence baseline for Run 8 and for the matrix; an approval gate cannot override the absolute preservation rule. The sign-out case must become a read-only observation of the sign-out control and confirmation, with no confirmation, no session clearing, and no re-authentication instruction.

## 4. SEC-001

SEC-001 remains separate, `HIGH — PROVISIONAL`, `OPEN — NOT FIXED`. `P6-SEC-001` is `NOT TESTED` and gated `BLOCKED — REQUIRES SEPARATE SESSION-PRESERVATION APPROVAL`. It uses a synthetic dummy only and does not submit. No real credential is required or recorded.

The case correctly says to stop if no safe non-sign-out route exists. This is consistent with the absolute session rule.

## 5. Device and backend dependencies

`08_test_environment_and_dependency_register.md` records D01–D20:

- Parent and Child authenticated sessions, existing family/pairing, build identity, clocks, credentials
- Android permissions, background execution, location, notifications, usage access
- Device Owner availability, isolated authentication environment, safe backend-error fixture
- Interconnected observation parameters

No dependency authorizes changing the environment to force a result. D18 and D19 correctly block P6-SHR-015 and P6-SHR-016 when the isolated environment or safe fixture is absent.

## 6. Environment limitations

- The existing Parent session is required and must not be replaced.
- The Child device and Parent emulator must remain paired.
- Do not clear app data, uninstall, re-pair, unlink, revoke, rotate credentials, or reset secure storage.
- Do not read `.tools/live_config.env` or expose credentials.
- Do not call backend APIs or change Supabase state.

## 7. Owner decisions still unresolved

1. Safe route/session strategy for SEC-001.
2. Isolated authentication test environment for P6-SHR-015.
3. Safe backend-error fixture for P6-SHR-016.
4. Authorization for each of the 14 approval scenarios.
5. Acceptance or revision of the proposed timing values.
6. Product scope for M01–M10.
7. Contract-freeze decisions C1–C4, C6/L1, C8.
8. Deferred child lifecycle case.

No owner decision is made by this review.

## 8. Conclusion

The approval register and SEC-001 handling are otherwise coherent. The sign-out path in P6-SHR-005 and its supporting policy wording are the controlling High defect. Runtime QA remains unauthorized.
