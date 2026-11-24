# Phase 2.5 — Final Owner Authorization Register & Decision Gateway

**Document ID:** `HAVEN-GOV-PHASE2-5-OWNER-REG`  
**Phase:** Phase 2.5 — Final Governance Traceability & Owner Authorization Consistency Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Formal Multi-Gate Owner Governance Framework & Authorization Separation  
**Execution Posture:** STRICTLY READ-ONLY — ALL DECISIONS PENDING  
**Default Phase 3 State:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Governance Architecture

This document establishes the authoritative, un-preapproved **Owner Authorization Register** for HAVEN Parent Control.

### 1.1 Critical Separation of Powers
To protect production infrastructure and maintain strict governance, Phase 2.5 enforces rigid boundaries between distinct levels of authorization:
1. **Accepting an Inventory Baseline** does NOT authorize selecting or provisioning a backend.
2. **Selecting a Preferred Backend** does NOT authorize infrastructure provisioning or deploying migrations.
3. **Approving a Test Strategy** does NOT authorize executing destructive operations.
4. **Allocating Dedicated Hardware** does NOT authorize modifying Android OS permissions on personal devices.
5. **Satisfying Technical Prerequisites** does NOT authorize starting Phase 3 manual test execution.

---

## 2. Section A — Historical Owner Decisions Register

| Decision ID | Phase of Origin | Historical Meaning | Options Defined | Historical Approval Evidence | Current Historical Status |
| :---: | :---: | :--- | :--- | :---: | :---: |
| **`P23-DEC-A`** | Phase 2.3 | Master Baseline Acceptance | Accept 92/99 vs Amend | None (Unsigned template) | **`PENDING OWNER DECISION`** |
| **`P23-DEC-B`** | Phase 2.3 | Backend Environment Pathway Selection | Pathway A vs B vs Defer | None (Unsigned template) | **`PENDING OWNER DECISION`** |
| **`P23-DEC-C`** | Phase 2.3 | Destructive Testing Quarantine | Controlled vs Prohibit All | None (Unsigned template) | **`PENDING OWNER DECISION`** |
| **`P23-DEC-D`** | Phase 2.3 | Android System Permissions | Authorize Test HW vs Restrict | None (Unsigned template) | **`PENDING OWNER DECISION`** |
| **`P23-DEC-E`** | Phase 2.3 | Phase 3 Execution Authorization | Authorize vs LOCKED | Explicitly Marked LOCKED | **`STRICTLY LOCKED / WITHHELD`** |
| **`P24-DEC-01`**| Phase 2.4 | Baseline Acceptance Proposal | Accept vs Amend vs Defer | None (Proposed draft) | **`PENDING OWNER DECISION`** |
| **`P24-DEC-02`**| Phase 2.4 | Environment Strategy Proposal | Prefer Staging vs QA Tenant | None (Proposed draft) | **`PENDING OWNER DECISION`** |
| **`P24-DEC-03`**| Phase 2.4 | Destructive Safeguards Proposal | Controlled vs Prohibit vs Defer| None (Proposed draft) | **`PENDING OWNER DECISION`** |
| **`P24-DEC-04`**| Phase 2.4 | Permission & Hardware Allocation | Permit Dedicated HW vs Restrict| None (Proposed draft) | **`PENDING OWNER DECISION`** |
| **`P24-DEC-05`**| Phase 2.4 | Phase 3 Authorization Gate Proposal| Review vs Conditional vs LOCKED| Explicitly Marked LOCKED | **`STRICTLY LOCKED / WITHHELD`** |

---

## 3. Section B — Current Pending Owner Decisions (`P25-OWNER-01` to `07`)

The following seven formal decision gates are submitted for explicit Project Owner review and decision. All gates default to **`PENDING OWNER DECISION`** or **`STRICTLY NOT AUTHORIZED`**:

---

### Gate 1: Baseline Acceptance (`P25-OWNER-01`)
- **Exact Decision Question**: Does the Owner accept the reconciled baseline of 92 unique functionalities, 10 separately tracked absent capabilities (`M01`–`M10`), 99 unique test cases, 100.0% specification coverage, and the 6-tier safety taxonomy?
- **Available Options**:
  - [ ] **Option 1-A (RECOMMENDED)**: ACCEPT THE COMPLETE 92-FUNCTIONALITY AND 99-TEST BASELINE.
  - [ ] **Option 1-B**: REQUIRE DOCUMENTATION AMENDMENTS BEFORE ACCEPTANCE.
  - [ ] **Option 1-C**: DEFER BASELINE ACCEPTANCE.
- **Technical Implications**: Locks the test catalog at 99 test cases; establishes the authoritative coverage target.
- **Security Implications**: Confirms 10 absent capabilities (`M01`–`M10`) are recognized as missing and quarantined.
- **Prerequisites**: `PREREQ-01`, `PREREQ-02`, `PREREQ-04`, `PREREQ-05`.
- **What it Authorizes**: Accepts documentation and audit metrics as authoritative.
- **What it DOES NOT Authorize**: Does NOT authorize test execution, backend selection, or code modifications.
- **Subsequent Approval Required**: Yes; Gates 2 through 7 remain required.

---

### Gate 2: Backend Pathway Preference (`P25-OWNER-02`)
- **Exact Decision Question**: Which backend execution pathway does the Owner select for Phase 3 test planning?
- **Available Options**:
  - [ ] **Option 2-A**: PREFER PATHWAY A (Dedicated Staging Supabase Cloud Project).
  - [ ] **Option 2-B**: PREFER PATHWAY B (Existing Supabase Project with QA Tenant Quarantine).
  - [ ] **Option 2-C (RECOMMENDED FOR PRIVACY/ZERO COST)**: PREFER PATHWAY C (Local Docker Supabase Environment).
  - [ ] **Option 2-D**: DEFER BACKEND SELECTION.
- **Technical Implications**: Determines target URLs, secret handling, and network routing for test runners.
- **Security Implications**: Pathway A provides physical cloud isolation; Pathway B requires strict RLS quarantine and prohibition of sweeps; Pathway C eliminates cloud risk entirely.
- **Prerequisites**: `PREREQ-03`, `PREREQ-07`.
- **What it Authorizes**: Directs QA engineering to prepare the specific setup plan for the chosen pathway.
- **What it DOES NOT Authorize**: Does NOT authorize creating cloud instances, spending money, running migrations, or provisioning infrastructure.
- **Subsequent Approval Required**: Yes; explicit provisioning authorization is required before deployment.

---

### Gate 3: Destructive Testing Policy & Global Sweep Prohibition (`P25-OWNER-03`)
- **Exact Decision Question**: What policy does the Owner establish for destructive operations, account purges, and retention sweeps?
- **Available Options**:
  - [ ] **Option 3-A (RECOMMENDED)**: STRICTLY PROHIBIT GLOBAL RETENTION SWEEPS (`AUD04`) ON ANY SHARED BACKEND; PERMIT CONTROLLED FAMILY PURGES (`AUD03`) ONLY AGAINST DEDICATED DISPOSABLE ACCOUNTS.
  - [ ] **Option 3-B**: PROHIBIT ALL DESTRUCTIVE TESTING (All 6 Tier-5 tests and destructive Tier-3 tests marked BLOCKED).
  - [ ] **Option 3-C**: AUTHORIZE FULL DESTRUCTIVE TESTING EXCLUSIVELY WITHIN ISOLATED LOCAL DOCKER (PATHWAY C).
  - [ ] **Option 3-D**: DEFER DESTRUCTIVE TESTING DECISION.
- **Technical Implications**: Prevents accidental triggering of `public.run_retention_sweep()` across production customer tables.
- **Security Implications**: Protects multi-tenant integrity and audit log retention compliance (>365d).
- **Prerequisites**: `PREREQ-08`, `PREREQ-12`.
- **What it Authorizes**: Establishes execution boundaries and approves teardown checklists for Tier-2 and Tier-3 tests.
- **What it DOES NOT Authorize**: Does NOT authorize running destructive tests yet.

---

### Gate 4: Disposable Account & Dedicated Test Hardware Allocation (`P25-OWNER-04`)
- **Exact Decision Question**: Does the Owner authorize the creation of dedicated disposable test accounts and the allocation of dedicated test smartphones?
- **Available Options**:
  - [ ] **Option 4-A (RECOMMENDED)**: AUTHORIZE ALLOCATION OF 4 DISPOSABLE QA ACCOUNTS AND 2 DEDICATED PHYSICAL ANDROID TEST PHONES.
  - [ ] **Option 4-B**: RESTRICT TESTING TO EMULATORS AND DUMMY ACCOUNTS ONLY (Excludes Category 4 native tests).
  - [ ] **Option 4-C**: DEFER HARDWARE AND ACCOUNT ALLOCATION.
- **Technical Implications**: Enables testing of background services, push notifications, and device pairing.
- **Security Implications**: Strictly prohibits installing test builds or granting Device Admin on personal employee phones.
- **Prerequisites**: `PREREQ-09`, `PREREQ-10`.
- **What it Authorizes**: Authorizes allocating specific test credentials and lab test phones.
- **What it DOES NOT Authorize**: Does NOT authorize granting Device Admin permissions without Gate 5.

---

### Gate 5: Android System Permission Testing Scope (`P25-OWNER-05`)
- **Exact Decision Question**: What native Android OS permissions does the Owner authorize testers to activate on dedicated test phones?
- **Available Options**:
  - [ ] **Option 5-A (RECOMMENDED)**: AUTHORIZE FULL NATIVE PERMISSIONS ON SPECIFICALLY ALLOCATED DEDICATED HARDWARE (Device Admin, Usage Stats, Background Location, Camera, Audio, Notifications).
  - [ ] **Option 5-B**: RESTRICT HIGH-PRIVILEGE PERMISSIONS (Prohibit Device Admin activation; test app management in user mode).
  - [ ] **Option 5-C**: DEFER PERMISSION TESTING AUTHORIZATION.
- **Technical Implications**: Allows verification of `ParentControlDeviceAdminReceiver` and native daemons (`GuardianService`, `LocationTrackingService`).
- **Security Implications**: Prevents device lockouts on non-dedicated hardware.
- **Prerequisites**: `PREREQ-09`, `PREREQ-15`.
- **What it Authorizes**: Permits testers to accept Android system dialogs on designated test hardware.
- **What it DOES NOT Authorize**: Does NOT authorize testing on personal hardware or everyday smartphones.

---

### Gate 6: Test Execution Phasing & Batching Strategy (`P25-OWNER-06`)
- **Exact Decision Question**: How should Phase 3 manual test execution be phased and controlled?
- **Available Options**:
  - [ ] **Option 6-A (RECOMMENDED)**: EXECUTE IN SIX SEQUENTIAL SAFETY BATCHES (Batch 1: Safe $\to$ Batch 2: Reversible $\to$ Batch 3: Disposable Acct $\to$ Batch 4: Disposable Dev $\to$ Batch 5: Isolated Backend $\to$ Batch 6: Specialist).
  - [ ] **Option 6-B**: EXECUTE BATCH 1 (SAFE READ-ONLY) ONLY AS A SANITY SMOKE SUITE.
  - [ ] **Option 6-C**: DEFER EXECUTION PHASING.
- **Technical Implications**: Ensures high-risk tests are not executed until low-risk baseline stability is proven.
- **Security Implications**: Contains failures and provides immediate abort points if anomalies arise.
- **Prerequisites**: `PREREQ-01` through `PREREQ-16`.
- **What it Authorizes**: Establishes the sequential batch schedule for QA execution.
- **What it DOES NOT Authorize**: Does NOT authorize test execution without Gate 7.

---

### Gate 7: Phase 3 Execution Authorization Gate (`P25-OWNER-07`)
- **Exact Decision Question**: Does the Owner authorize the commencement of Phase 3 manual test execution?
- **Available Options**:
  - [ ] **Option 7-A**: AUTHORIZE PHASE 3 EXECUTION (Subject to Gates 1 through 6 and technical prerequisite verification).
  - [ ] **Option 7-B**: CONDITIONAL AUTHORIZATION (Authorize Batch 1 Safe Read-Only tests only).
  - [ ] **Option 7-C (DEFAULT POSTURE)**: AUTHORIZATION WITHHELD — ALL TESTS REMAIN NOT TESTED.
- **Technical Implications**: Unlocks the test suite for human QA tester execution.
- **Security Implications**: All actions must be logged in formal test execution logs.
- **Prerequisites**: All mandatory prerequisites (`PREREQ-01` through `PREREQ-17`) satisfied.
- **What it Authorizes**: Authorizes testers to transition test cases from `NOT TESTED` to `PASS`, `FAIL`, or `BLOCKED`.
- **Current Status**: **`STRICTLY WITHHELD / NOT AUTHORIZED`**.
