# Phase 1.4: Canonical Eight-Gate Authorization Matrix

**Document ID:** `HAVEN-AUD-012-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification & Final Authorization Gate Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Formal Governance Framework & Authorization Lifecycle  

---

## 1. Executive Summary

This document establishes the authoritative **Canonical 8-Gate Authorization Lifecycle** for the HAVEN Parent Control application remediation. It defines the formal boundaries, permitted activities, strict prohibitions, environmental constraints, and objective exit criteria for each phase of implementation and verification.

This matrix ensures that no code is deployed to production, no migrations are applied to the live database, and no physical devices are manipulated without sequential, evidence-based owner authorization.

---

## 2. Master 8-Gate Lifecycle Architecture

```
[ Gate 1: Baseline Architecture Approval ]  --> (PASSED - Phase 4 Gate A Option C)
                     |
                     v
[ Gate 2: Client Source Implementation ]     --> (READY FOR OWNER CONSIDERATION - Waves 1 & 2)
                     |
                     v
[ Gate 3: Migration Design & Script Review]  --> (READY FOR OWNER CONSIDERATION - Wave 3 SQL)
                     |
                     v
[ Gate 4: Disposable Staging DB Migration ]  --> (BLOCKED - Requires Gate 3 + Staging DB)
                     |
                     v
[ Gate 5: Edge Function Staging Deploy ]     --> (BLOCKED - Requires Gate 4 + Staging Edge)
                     |
                     v
[ Gate 6: Disposable Staging E2E Suite ]     --> (BLOCKED - Requires Gate 5 + Test Suite)
                     |
                     v
[ Gate 7: Production Deployment ]            --> (STRICTLY BLOCKED - Requires Gate 6 + Owner)
                     |
                     v
[ Gate 8: Live Hardware QA Execution ]       --> (STRICTLY BLOCKED - Requires Gate 7 + Owner)
```

---

## 3. Comprehensive Gate Specification Matrix

The table below defines all 8 gates in the remediation and verification lifecycle:

| Gate | Gate Name & Focus | Applicable Wave(s) | Authorized Activities | Strictly Prohibited Activities | Target Environment | Prerequisite Gates | Current Status |
|---|---|---|---|---|---|---|---|
| **GATE 1** | Baseline Architecture Approval | Cross-Wave | Architectural review, threat modeling, state machine design, document audits. | Any code modification, test modification, DB migration, or device execution. | Documentation only | None | **COMPLETED & APPROVED** |
| **GATE 2** | Client Source Implementation | Wave 1 & Wave 2 | Implementing Flutter widgets (`AppTextField`, `QuickActionsCard`), native Android Kotlin (`GuardianService`), Dart models/repos. Running local unit/widget tests. | Modifying SQL migrations, modifying Edge Functions, touching production DB, communicating with devices. | Local developer workstation (`D:\parentcontrol_app`) | Gate 1 | **READY FOR OWNER CONSIDERATION** |
| **GATE 3** | Migration Design & Script Review | Wave 3 | Authoring draft PostgreSQL migration script (`20261124000100_device_recredentialing.sql`) for review. Static linting, syntax checking. | Executing SQL against ANY database (staging or production). Modifying client code or Edge Functions. | Workspace review files only | Gate 1 | **READY FOR OWNER CONSIDERATION** |
| **GATE 4** | Disposable Staging DB Migration | Wave 3 | Applying Gate 3 SQL script to an isolated, disposable staging PostgreSQL instance. Verifying tables, indexes, constraints, `pgTAP` tests. | Applying migrations to Production Supabase DB. Connecting client or devices. | Ephemeral Staging DB container (Local Docker / Staging DB) | Gate 3 | **BLOCKED** (Pending Gate 3 approval & Staging DB) |
| **GATE 5** | Edge Function Staging Deploy | Wave 3 | Deploying TypeScript Edge Functions (`family-admin`, `device-register`) to staging Supabase project. Running `deno test` suites. | Deploying to Production Supabase project. Setting production secrets or feature flags. | Disposable Staging Deno Deploy environment | Gate 4 | **BLOCKED** (Pending Gate 4 completion) |
| **GATE 6** | Disposable Staging Integration Suite | Wave 3 | Executing automated end-to-end integration tests (ATT-01..24 test harness) between mock client, staging Edge Functions, and staging DB. | Testing against production infrastructure. Using live test devices (`emulator-5554` or `5HXWRGQ4IFU8WS4T`). | Integrated Disposable Staging Environment | Gate 2, Gate 5 | **BLOCKED** (Pending Gate 2 & Gate 5 completion) |
| **GATE 7** | Production Deployment | Cross-Wave | Applying migration to Production DB, deploying Edge Functions to Production Deno, toggling feature flag, releasing app APK. | Bypassing staging validation. Deploying without explicit, written owner authorization. | Live Production Infrastructure | Gate 6 + Owner Authorization | **STRICTLY PROHIBITED & BLOCKED** |
| **GATE 8** | Live Hardware QA Execution | Cross-Wave | Running comprehensive end-to-end QA tests on physical Realme device (`5HXWRGQ4IFU8WS4T`) and Pixel 9 emulator (`emulator-5554`). | Running tests prior to production verification. Modifying device OS settings or wiping without authorization. | Live Hardware Devices | Gate 7 + Owner Authorization | **STRICTLY PROHIBITED & BLOCKED** |

---

## 4. Deep-Dive Gate Protocols & Exit Criteria

### 4.1 Gate 2: Client Source Implementation Authorization
- **Scope**:
  - `HAVEN-QA-001` (Wave 1): Edit `AppTextField` and its 3 authentic call sites.
  - `HAVEN-QA-002` (Wave 1): Edit `QuickActionsCard` with `LayoutBuilder`, 420dp breakpoint, and `TextScaler`. Strict quarantine on `AppButton` (0 edits).
  - `HAVEN-QA-005` (Wave 1): Edit `GuardianService.kt` notification query for channel `"guardian_status"`.
  - `HAVEN-QA-004` (Wave 2): Edit `DeviceRepository` and `DeviceService` to implement explicit filtering methods (`fetchActiveDevices()`, `fetchDeviceHistory()`, `fetchPendingDevices()`).
  - `HAVEN-QA-006` (Wave 2): Update presentation models to strictly map canonical `'enforced'` policy status with `syncHealth` diagnostics.
- **Exit Criteria**:
  1. 100% pass rate on all Flutter widget tests across 320dp, 360dp, 400dp, and 480dp widths.
  2. 100% pass rate on Dart repository unit tests.
  3. Clean compile check: `flutter analyze` reports 0 errors and 0 warnings on modified files.
  4. Working tree diff strictly limited to approved client files.

### 4.2 Gate 3: Migration Design & Script Review
- **Scope**:
  - Author migration file: `supabase/migrations/20261124000100_device_recredentialing.sql`.
  - Include:
    - Custom PL/pgSQL `constant_time_equals` function.
    - Partial unique index `idx_device_recovery_single_active` on `device_recovery_challenges(device_id) WHERE status = 'active'`.
    - Function `rotate_device_secret` returning structured JSONB (no `RAISE EXCEPTION` on validation errors).
    - Row-level lock ordering: lock Challenge row first, lock Device row second.
- **Exit Criteria**:
  1. Independent peer review sign-off on SQL script.
  2. Static linting pass (`sqlfluff` or PostgreSQL parser).
  3. Explicit owner approval of the SQL script design.

### 4.3 Gate 4: Disposable Staging Migration Authorization
- **Scope**:
  - Apply Gate 3 migration to a dedicated, ephemeral PostgreSQL container.
- **Exit Criteria**:
  1. Zero errors during `supabase db push` or `psql -f` execution.
  2. `pgTAP` test suite passes 100%, verifying table creation, RLS policies, indexes, and custom functions.
  3. Verification that down-migration is not provided (forward-only recovery).

### 4.4 Gate 5: Edge Function Staging Deploy Authorization
- **Scope**:
  - Implement and deploy Wave 3 Edge Functions (`family-admin`, `device-register`) to staging environment.
  - Implement asymmetric feature flag guard (`FEATURE_RECREDENTIALING_ENABLED`).
- **Exit Criteria**:
  1. All Deno unit tests pass (100%).
  2. Persistent rate-limiting queries verified against staging DB.
  3. Asymmetric kill-switch tested: `verify_device_rotation` remains active when flag is false.

### 4.5 Gate 6: Disposable Staging Integration Suite Authorization
- **Scope**:
  - Run complete end-to-end automated test suite across mock Android client, staging Edge Functions, and staging DB.
  - Execute automated tests for all 24 red-team scenarios (ATT-01 through ATT-24).
- **Exit Criteria**:
  1. 100% pass rate on ATT-01 through ATT-24 automated test harness.
  2. Zero deadlocks under 50 concurrent transactions.
  3. Lost-response recovery protocol verified under dropped network conditions.
  4. Staging execution certificate authored and signed.

### 4.6 Gate 7 & Gate 8: Production & Hardware Device Safeguards
- **Mandatory Prohibitions**:
  - **No Production Access**: Production database URL, production service keys, and production Edge Functions are completely blocked.
  - **No Hardware Access**: ADB commands targeting `5HXWRGQ4IFU8WS4T` or `emulator-5554` are completely forbidden.
  - **Owner Prerequisite**: Gates 7 and 8 require separate, explicit, standalone written approval from the owner after reviewing Gate 6 artifacts.

---

## 5. Governance and Change Control Summary

| Gate Progression | Transition Rule | Required Approval Authority |
|---|---|---|
| **Gate 1 $\rightarrow$ Gate 2** | Design & Planning Audit Passed | Owner Explicit Approval |
| **Gate 1 $\rightarrow$ Gate 3** | Architecture Audit Passed | Owner Explicit Approval |
| **Gate 3 $\rightarrow$ Gate 4** | SQL Script Independently Validated | Automated / Technical Lead |
| **Gate 4 $\rightarrow$ Gate 5** | Staging DB Migrations Verified | Technical Lead |
| **Gate 5 $\rightarrow$ Gate 6** | Staging Edge Functions Verified | Technical Lead |
| **Gate 6 $\rightarrow$ Gate 7** | 100% Staging E2E Suite Passed | **Owner Standalone Explicit Approval** |
| **Gate 7 $\rightarrow$ Gate 8** | Production Deploy Smoke Test Passed | **Owner Standalone Explicit Approval** |

By establishing this clear separation of environments and authorization gates, HAVEN ensures complete operational security and zero risk of accidental production disruption.
