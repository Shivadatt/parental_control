# 03 — Case Quality and Safety Audit

## 1. Read-only versus persistent actions

- The 98-case matrix is predominantly read-only or explicitly gated.
- The corrected cases P6-PAR-024, P6-SHR-012, and P6-SHR-013 are now read-only.
- P6-PAR-004, P6-PAR-028, and P6-CHD-016 are read-only observations; their write portions are split into P6-PAR-036, P6-PAR-037, and P6-CHD-020 with High/Medium gates.
- **P6-SHR-005 is the exception.** It is not a read-only observation. Its expected result is “session clears,” and it is executable if an owner approval is granted.

## 2. Session and credential safety

### 2.1 P6-SHR-001

`01_master_qa_test_matrix.md`, P6-SHR-001, is now a read-only existing-session/identity observation. It prohibits sign-out, sign-in, credential entry, and session change. The positive sign-in path is separately marked `BLOCKED — SEPARATE OWNER-APPROVED SESSION-SAFE STRATEGY REQUIRED`. This part is safe.

### 2.2 P6-SHR-005 — remaining High defect

`01_master_qa_test_matrix.md`, P6-SHR-005, is an executable sign-out case:

- Steps: “Sign out only with approval.”
- Expected: “session clears.”
- Cleanup: “Re-authenticate via owner.”

The same case appears in `02_parent_mode_test_plan.md`, `03_child_mode_test_plan.md`, and `04_shared_and_interconnected_test_plan.md`. `10_matrix_coverage_and_traceability.md` maps A05 directly to it.

This violates the review requirement that session preservation is absolute and that no approval gate permits sign-out. A gate does not make the action safe; it only postpones the destructive action.

### 2.3 Approval-policy conflict

- `02_parent_mode_test_plan.md`, “Parent-mode notes”: “No case may sign out ... without approval.”
- `07_security_and_approval_required_register.md`, section 3: “High-risk writes that are reversible but change policy, retention, pairing, or sessions also require explicit approval.”
- `08_test_environment_and_dependency_register.md`, section 3: sign-out is listed under “Prohibited without approval.”

These statements must become absolute prohibitions. They currently provide a documentation route to authorize session destruction.

## 3. Permission and network safety

- P6-SHR-012 is now read-only. It does not request, grant, revoke, restore, or change permissions. A naturally appearing prompt must not be granted.
- P6-SHR-013 is now naturally occurring observation only. It does not toggle Wi-Fi, mobile data, or airplane mode, and does not force an outage.
- P6-STATE-001, P6-STATE-002, and P6-STATE-003 prohibit forced states, data deletion, permission changes, and network changes.
- P6-CHD-011 (device-admin activation) and P6-CHD-006/007 (Device Owner) remain gated or dependency-blocked.
- No remaining permission- or network-changing instruction was found in the corrected shared cases.

## 4. Risk and Approval Gate consistency

| Case | Risk | Gate | Assessment |
|---|---|---|---|
| P6-PAR-024 | Low | NONE | Consistent; read-only |
| P6-SHR-012 | Low | NONE | Consistent; read-only |
| P6-SHR-013 | Low | Natural-condition block | Consistent; read-only condition |
| P6-SHR-001 | Low | Read-only `NONE`; positive sign-in blocked | Consistent |
| **P6-SHR-005** | High | Explicit owner approval | **Inconsistent with absolute no-sign-out rule** |
| P6-PAR-036 | High | Explicit owner approval | Consistent; persistent cancellation |
| P6-PAR-037 | High | Explicit owner approval | Consistent; persistent acknowledgement |
| P6-CHD-020 | Medium | Explicit owner approval | Consistent; reversible restart |
| P6-SEC-001 | High | Separate session-preservation approval | Consistent; no real credential |
| P6-CHD-019 | Medium | NONE | Ambiguous: “Trigger retry once” is a backend attempt; clarify idempotence/no mutation |

## 5. Missing test states

The three cross-cutting state cases cover Parent loading/empty/cached, Parent empty/error/retry, and Child permission-denied/offline/error. Natural-state conditions are required; forced states are prohibited. No major state-coverage gap was found.

The remaining gap is the invalid-session/expired-session state. It is not explicitly represented as a dedicated case, but P6-SHR-016 and P6-STATE-002 cover backend/auth error and retry. This is an informational coverage observation, not a safety defect.

## 6. Ambiguous or unsafe wording

- “Sign out only with approval” and “without approval” are unsafe. They should be replaced with an absolute prohibition.
- “Sessions also require explicit approval” is unsafe for the same reason.
- “Re-authenticate via owner” is an instruction to replace the session and should be removed.
- “Trigger retry once” in P6-CHD-019 should state that the retry is idempotent, does not change policy or identity, and does not create a persistent command.
- `10_matrix_coverage_and_traceability.md` still says “ready for second independent review, not execution.” This is stale, not unsafe.

## 7. Conclusion

Case quality is substantially improved, and six of the eight N findings are verified corrected. The matrix is not safe for execution approval because the sign-out path and its supporting policy language remain. This is a High safety/documentation defect, not a runtime result.
