# 01 — Baseline and Evidence Inventory

**Phase:** 5.1 — Owner Decision Reconciliation & Contract Freeze  
**Mode:** Read-only inspection, reconciliation and documentation proposal  
**Workspace:** `D:\parentcontrol_app`  
**Git root (verified):** `D:/parentcontrol_app`  
**Branch:** `main`  
**HEAD:** `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f`

---

## 1. Baseline verification

| Item | Value |
|---|---|
| Git root | `D:/parentcontrol_app` |
| Branch | `main` |
| HEAD | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` |
| Tracked diff | none (`git diff --stat` empty) |
| Initial Git status | `?? docs/testing/device_heartbeat_root_cause_investigation/`<br>`?? docs/testing/phase_3_complete_functional_testing/`<br>`?? docs/testing/phase_4_device_recredentialing_design/`<br>`?? docs/testing/phase_5_recredentialing_implementation_plan/`<br>`?? docs/testing/two_device_end_to_end_testing/` |

All pre-existing modified and untracked files are preserved. Nothing was committed, reset, checked out or cleaned.

---

## 2. Package verification

### Phase 4 package
`docs/testing/phase_4_device_recredentialing_design/` — **12 reports present**:

1. `01_executive_summary.md`
2. `02_existing_identity_lifecycle.md`
3. `03_failure_point_source_evidence.md`
4. `04_recovery_option_comparison.md`
5. `05_security_threat_model.md`
6. `06_backend_transaction_design.md`
7. `07_flutter_kotlin_implementation_design.md`
8. `08_compatibility_and_failure_recovery.md`
9. `09_complete_recredentialing_test_plan.md`
10. `10_related_defect_workstreams.md`
11. `11_future_authorization_matrix.md`
12. `12_owner_decision_record.md`

### Phase 5 package
`docs/testing/phase_5_recredentialing_implementation_plan/` — **14 reports present**:

1. `01_executive_summary.md`
2. `02_source_baseline_and_git_status.md`
3. `03_existing_flow_revalidation.md`
4. `04_proposed_end_to_end_architecture.md`
5. `05_flutter_implementation_plan.md`
6. `06_kotlin_secure_storage_plan.md`
7. `07_edge_function_api_contracts.md`
8. `08_gate_c_database_rpc_specification.md`
9. `09_security_threat_model.md`
10. `10_transaction_and_idempotency_design.md`
11. `11_audit_rate_limit_and_session_design.md`
12. `12_complete_implementation_test_plan.md`
13. `13_gate_dependency_and_execution_sequence.md`
14. `14_owner_implementation_decision.md`

Both packages are non-empty and readable.

---

## 3. Evidence relevant to Gate A

### 3.1 What the Phase 4 record actually says
`docs/testing/phase_4_device_recredentialing_design/12_owner_decision_record.md`:

- §1 recommends **Option C**.
- §2 lists D1–D14 with a **Recommended** column and a **Status** column whose values are **OPEN**.
- §4 contains an unsigned decision block:
  ```
  Gate A decision: [ ] APPROVE Option C  [ ] APPROVE WITH CHANGES  [ ] REJECT
  Owner: ____  Date: ____
  Next gate requested: ...
  ```
- §5.5 ends with "Wait for explicit owner approval of Gate A".

### 3.2 What the Phase 5 package claims
`phase_5.../01_executive_summary.md:19` and `14_owner_implementation_decision.md:17` record:

> "The Phase 5 instruction states Gate A is approved, but the Phase 4 record still marks D1–D14 OPEN and unsigned."

The Phase 5 package therefore treats Gate A approval as **asserted by the Phase 5 brief**, not as a signed repository artifact.

### 3.3 What is present in project evidence
A repository search across both packages found:

- no signed Gate A decision;
- no owner name/timestamp;
- no "APPROVED" entry for D1–D14;
- only recommendations, checklists and an unsigned block.

**Conclusion:** there is **no documentary Gate A approval** in the repository at HEAD `bbd3c21`. The approval exists only as an assertion in the Phase 5 task brief, which is not stored in the repository.

This is a **reconciliation gap**, not a reason to fabricate a signature.

---

## 4. Evidence classification used in Phase 5.1

| Class | Meaning |
|---|---|
| **APPROVED (documented)** | Recorded with owner scope/decision in a repository artifact |
| **APPROVED (asserted)** | Stated in the Phase 5 brief but not recorded in the repository |
| **RECOMMENDATION** | Proposed in Phase 4/5, not approved |
| **PENDING** | Requires owner decision before contract freeze |
| **DEFERRABLE** | Can be safely deferred without blocking Gate C |

- Option C: **APPROVED (asserted)**, not documented.
- D1–D14: **RECOMMENDATIONS** in the Phase 4 table; the Phase 5 brief asserts approved values, but the artifact still shows OPEN.
- C1–C8: **PENDING** (this phase).
- TTL 10 min / 5 attempts: **APPROVED (asserted via D2)**.
- Other rate limits: **RECOMMENDATION**.

---

## 5. Source evidence re-inspected

No new source tracing was required for this phase; the Phase 4/5 reports cite the source. Key source files remain:

- `lib/features/child/controllers/child_enrollment_controller.dart`
- `lib/features/child/controllers/child_shell_controller.dart`
- `lib/features/devices/device_detail_controller.dart`, `device_detail_page.dart`
- `lib/data/repositories/supabase_device_repository.dart`, `repository_contracts.dart`
- `android/.../SecureStore.kt`, `NativeBridge.kt`, `GuardianService.kt`, `DeviceHttpClient.kt`
- `supabase/functions/device-register/index.ts`, `family-admin/index.ts`, `_shared/auth.ts`, `_shared/rate_limit.ts`, `_shared/validation.ts`
- `supabase/migrations/20260101000000_core.sql`, `20260101000100_functions.sql`, `20260101000200_rls.sql`, `20260101000400_device_recovery.sql`

No credential, hash, token or key was read or printed.

---

## 6. Deliverables in this phase

New directory `docs/testing/phase_5_1_owner_decision_reconciliation/` will contain exactly nine reports:

1. `01_baseline_and_evidence_inventory.md`
2. `02_gate_a_approval_reconciliation.md`
3. `03_c1_c2_decision_analysis.md`
4. `04_c3_c4_decision_analysis.md`
5. `05_c5_c6_decision_analysis.md`
6. `06_c7_c8_decision_analysis.md`
7. `07_final_owner_decision_matrix.md`
8. `08_contract_freeze_proposal.md`
9. `09_authorization_and_gate_boundary.md`

The original Phase 4 and Phase 5 reports are not modified.

---

## 7. Baseline verdict

Evidence is sufficient to analyze C1–C8 from the Phase 4/5 packages and source references. The only mandatory-evidence gap is the **absence of a signed Gate A record**. That gap does not prevent a decision proposal, but it prevents treating Gate A as documented.

**Status: CONDITIONALLY READY for owner decisions.**
