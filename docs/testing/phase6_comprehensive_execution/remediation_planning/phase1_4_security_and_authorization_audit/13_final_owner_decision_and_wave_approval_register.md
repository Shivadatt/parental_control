# Phase 1.4: Final Owner Decision and Wave Approval Register

**Document ID:** `HAVEN-AUD-013-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification & Final Authorization Gate Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Formal Owner Authorization Framework  

---

## 1. Executive Summary

This document presents the authoritative **Final Owner Decision Register** for the HAVEN Parent Control remediation program. It organizes all proposed remediation work into three distinct implementation waves and maps them to the Canonical 8-Gate Lifecycle. 

It provides the owner with granular, independent decision gates (`DEC-REM-001` through `DEC-REM-008`), ensuring that low-risk client enhancements can proceed immediately without waiting for or risking complex backend re-credentialing infrastructure, while strictly walling off production databases and physical hardware until staging tests are fully validated.

---

## 2. Implementation Wave Architecture & Scope Breakdown

Remediation work is partitioned into three strictly decoupled waves to minimize risk and avoid broad regression surfaces:

```
+-------------------------------------------------------------------------------+
| WAVE 1: CLIENT SECURITY, ACCESSIBILITY & NATIVE PERMISSIONS                   |
| Scope: HAVEN-QA-001, HAVEN-QA-002, HAVEN-QA-005                               |
| Impact: Low | Dependencies: None (Client-only) | Gate: GATE 2                 |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| WAVE 2: CLIENT PERSISTENCE & DATA PRESENTATION INTEGRITY                      |
| Scope: HAVEN-QA-004, HAVEN-QA-006                                             |
| Impact: Low-Medium | Dependencies: None (Client-only) | Gate: GATE 2          |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| WAVE 3: DEVICE RE-CREDENTIALING PROTOCOL & INFRASTRUCTURE                      |
| Scope: HAVEN-QA-003                                                           |
| Impact: High | Multi-Gate Lifecycle: GATE 3 -> GATE 4 -> GATE 5 -> GATE 6     |
| Production Deployment (GATE 7) & Live Hardware QA (GATE 8): STRICTLY BLOCKED  |
+-------------------------------------------------------------------------------+
```

### 2.1 Wave 1 Breakdown: Client Security, UI & Native Permissions
- **Defects Covered**:
  - `HAVEN-QA-001`: ObscureText toggle state leakage in `AppTextField` and its 3 authentic callers (`auth_form_fields.dart`, `parent_pin_dialog.dart`, `login_page.dart`).
  - `HAVEN-QA-002`: UI overflow and text scaling distortion in `QuickActionsCard`. Implements `LayoutBuilder`, 420dp breakpoint, and modern `TextScaler.scale(1.0) > 1.15`. Strict quarantine on `AppButton` (0 edits).
  - `HAVEN-QA-005`: Native notification channel verification in `GuardianService.kt` for channel `"guardian_status"`. Graceful handling of uncreated channels as `REQUIRED_CHANNEL_NOT_CREATED`.
- **Target Gate**: **Gate 2** (Client Source Implementation).
- **Blast Radius**: Strictly client-side Flutter and Android Kotlin code. Zero backend, database, or schema changes.

### 2.2 Wave 2 Breakdown: Client Persistence & Presentation Integrity
- **Defects Covered**:
  - `HAVEN-QA-004`: Device list filter desynchronization. Replaces boolean flags with explicit, typed repository methods: `fetchActiveDevices()`, `fetchDeviceHistory()`, and `fetchPendingDevices()`. Handles ternary states (`active`, `revoked`, `pending`).
  - `HAVEN-QA-006`: Policy status presentation desynchronization. Formally binds UI badges to canonical database status `'enforced'` combined with `syncHealth` indicators. Purges misleading `'active'` status from domain model.
- **Target Gate**: **Gate 2** (Client Source Implementation).
- **Blast Radius**: Strictly client-side Flutter repositories and presentation models. Zero backend or schema changes.

### 2.3 Wave 3 Breakdown: Device Re-credentialing Architecture
- **Defect Covered**:
  - `HAVEN-QA-003`: Complete end-to-end device re-credentialing protocol (Phase 4 Gate A Option C architecture).
- **Key Technical Components**:
  - Migration script with PL/pgSQL `constant_time_equals` function, partial unique index `idx_device_recovery_single_active`, and structured JSONB RPC `rotate_device_secret`.
  - Edge Functions implementing persistent database rate limiting (10/parent/hr, 3/device/hr), Crockford Base32 normalization, and asymmetric feature flag guard.
  - Client-side 7-state KeyStore machine in `SecureStore.kt` with atomic staging and idempotent `verify_device_rotation`.
- **Target Gates**: Multi-stage progression across **Gate 3** (Script Review), **Gate 4** (Disposable Staging DB), **Gate 5** (Staging Edge Deploy), and **Gate 6** (Disposable Staging Integration).
- **Blast Radius**: High. Involves database schema, RPC functions, edge endpoints, and native Android cryptographic storage.

---

## 3. Master Owner Decision Register (DEC-REM-001 Through DEC-REM-008)

The table below provides the authoritative decision status for each decision point in the remediation lifecycle.

| Decision ID | Decision Subject | Target Gate | Remediation Wave | Auditor Assessment & Readiness | Authoritative Decision Recommendation | Owner Decision |
|---|---|---|---|---|---|---|
| **DEC-REM-001** | Wave 1 Client Source Implementation Authorization | Gate 2 | Wave 1 | Architecture fully verified. Zero backend dependency. Widget tests specified. | **RECOMMENDED — AWAITING OWNER CONFIRMATION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-002** | Wave 2 Client Source Implementation Authorization | Gate 2 | Wave 2 | Ternary domain model reconciled with `core.sql`. Explicit repository methods approved. | **RECOMMENDED — AWAITING OWNER CONFIRMATION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-003** | Wave 3 Migration Design & Script Authoring Authorization | Gate 3 | Wave 3 | Architecture sound. Custom constant-time function, partial unique index, and row locking specified. Review only. | **RECOMMENDED — AWAITING OWNER CONFIRMATION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-004** | Wave 3 Disposable Staging Migration Authorization | Gate 4 | Wave 3 | Requires Gate 3 review completion and provisioning of isolated staging DB. | **DEFERRED — PENDING GATE 3 COMPLETION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-005** | Wave 3 Edge Function Staging Deploy Authorization | Gate 5 | Wave 3 | Requires Gate 4 DB verification and staging Deno environment. | **DEFERRED — PENDING GATE 4 COMPLETION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-006** | Wave 3 Disposable Staging Integration Suite Authorization | Gate 6 | Wave 3 | Requires Gate 2 and Gate 5 completion. 24 ATT scenarios ready for automated test harness. | **DEFERRED — PENDING GATES 2 & 5 COMPLETION** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-007** | Production Infrastructure Deployment Authorization | Gate 7 | Cross-Wave | Production deployment is strictly quarantined. Prohibited until Gate 6 achieves 100% pass rate. | **STRICTLY BLOCKED — PRODUCTION PROHIBITED** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |
| **DEC-REM-008** | Live Hardware Device QA Execution Authorization | Gate 8 | Cross-Wave | Hardware devices (`emulator-5554` and `5HXWRGQ4IFU8WS4T`) are quarantined until Gate 7 release. | **STRICTLY BLOCKED — HARDWARE PROHIBITED** | `[ ] APPROVED`<br/>`[ ] REJECTED`<br/>`[ ] DEFERRED` |

---

## 4. Concrete Owner Action Items & Execution Roadmap

To initiate remediation while maintaining total operational security, the owner is presented with the following immediate recommended action path:

### Step 1: Immediate Approval of Client Waves (Low Risk)
- [ ] **Approve DEC-REM-001 (Wave 1)**: Authorize implementation of client-side UI, password masking, and notification channel fixes in local workspace.
- [ ] **Approve DEC-REM-002 (Wave 2)**: Authorize implementation of client-side repository filtering and policy status presentation fixes.

### Step 2: Authorize Wave 3 SQL Script Design Review (Zero Runtime Mutation)
- [ ] **Approve DEC-REM-003 (Wave 3 Gate 3)**: Authorize authoring the draft SQL migration script (`supabase/migrations/20261124000100_device_recredentialing.sql`) for static review and schema validation. Zero SQL execution will take place.

### Step 3: Enforce Strict Quarantine on Production & Devices
- [X] **Maintain Blocker on DEC-REM-004 through DEC-REM-008**: Prohibit all production deployments, production database access, and interaction with live test devices (`emulator-5554` and `5HXWRGQ4IFU8WS4T`) until Gates 2 through 6 are fully satisfied.

---

## 5. Owner Sign-Off Block

**Program Owner / Authorized Stakeholder:**

**Signature / Decision Stamp:** ___________________________  
**Date:** ___________________________  
**Approved Decisions:** `[ ] DEC-REM-001` | `[ ] DEC-REM-002` | `[ ] DEC-REM-003`  
**Deferred Decisions:** `[ ] DEC-REM-004` | `[ ] DEC-REM-005` | `[ ] DEC-REM-006`  
**Blocked Decisions:** `[X] DEC-REM-007` | `[X] DEC-REM-008`  
