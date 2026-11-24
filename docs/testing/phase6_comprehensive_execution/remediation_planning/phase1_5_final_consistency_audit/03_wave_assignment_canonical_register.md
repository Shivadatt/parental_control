# Phase 1.5: Canonical Wave Assignment Register

**Document ID:** `HAVEN-AUD-003-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Authoritative Cross-Phase Traceability & Sequencing  

---

## 1. Executive Summary

This register establishes the single, authoritative **Canonical Wave Assignment** for all six defects under the HAVEN Parent Control remediation program. It explicitly resolves the defect numbering confusion and inverted Wave assignments introduced during Phase 1.4, harmonizing the remediation scope with the original Phase 6 QA defect register (`09_defect_register.md`) and the Phase 1 implementation plan (`08_implementation_order_and_rollback_plan.md`).

> [!IMPORTANT]
> **Governance Notice**: This register represents strict **documentation reconciliation and dependency ordering**. It does **NOT** constitute authorization to implement any code or modify any database. Implementation requires explicit owner approval under Gate 2 (Client Waves) and Gate 3 (Migration Design).

---

## 2. Historical Divergence and Root Cause Analysis

### 2.1 The Inconsistency in Phase 1.4
During the authoring of Phase 1.4, defect IDs and titles became cross-wired:
- Phase 1.4 referred to `HAVEN-QA-001` as "Password visibility toggle" and `HAVEN-QA-002` as "QuickActionsCard layout clipping".
- Phase 1.4 referred to `HAVEN-QA-004` as "Device list filtering" and `HAVEN-QA-005` as "Notification permission diagnostic".

### 2.2 Authoritative Source Reality
Inspection of the authoritative defect definitions in `docs/testing/phase6_comprehensive_execution/09_defect_register.md:11-19` reveals the authentic baseline:
- `HAVEN-QA-001`: Action button text truncated ("Create acc...") on Role Selection screen. (Severity: **Low**)
- `HAVEN-QA-002`: Password input exposes plaintext / lacks secure input hardening (SEC-001). (Severity: **High**)
- `HAVEN-QA-003`: Device re-credentialing failure breaks heartbeat, usage & location uploads (DEF-601). (Severity: **High**)
- `HAVEN-QA-004`: Notification permission reports false-positive "Granted" (DEF-604). (Severity: **Medium**)
- `HAVEN-QA-005`: Revoked devices duplicated in Parent dashboard and device list (DEF-602). (Severity: **High**)
- `HAVEN-QA-006`: Policy version inconsistency between Dashboard and Devices tab (DEF-603). (Severity: **Medium**)

---

## 3. Canonical Wave Assignment Register

Remediation work is partitioned into three strictly decoupled, risk-ascending waves based on architectural dependencies and risk blast radius:

```
+--------------------------------------------------------------------------------------------------+
|                                    CANONICAL WAVE STRUCTURE                                      |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  | WAVE 1: IMMEDIATE CLIENT HARDENING (Zero Backend / Schema Dependency)                      |  |
|  | - HAVEN-QA-001: Role Selection Action Button Text Truncation (Low)                         |  |
|  | - HAVEN-QA-002: Password Input Security & Semantics Hardening (SEC-001) (High)             |  |
|  | - HAVEN-QA-004: Android Notification Compat Detection False-Positive (DEF-604) (Medium)   |  |
|  +--------------------------------------------------------------------------------------------+  |
|                                                |                                                 |
|                                                v                                                 |
|  +--------------------------------------------------------------------------------------------+  |
|  | WAVE 2: CLIENT QUERY & REPOSITORY PROJECTION (Zero Backend / Schema Dependency)            |  |
|  | - HAVEN-QA-005: Revoked Devices Duplicated in Parent Dashboard (DEF-602) (High)          |  |
|  | - HAVEN-QA-006: Harmonized Policy Version Presentation Consistency (DEF-603) (Medium)       |  |
|  +--------------------------------------------------------------------------------------------+  |
|                                                |                                                 |
|                                                v                                                 |
|  +--------------------------------------------------------------------------------------------+  |
|  | WAVE 3: DISTRIBUTED RE-CREDENTIALING PROTOCOL (High Risk / Multi-Tier)                     |  |
|  | - HAVEN-QA-003: Device Re-credentialing & Telemetry Continuity (DEF-601) (High)            |  |
|  |   * Gate 3: Draft SQL Script Review                                                        |  |
|  |   * Gates 4-6: Disposable Staging Migrations, Functions & E2E Verification                   |  |
|  |   * Gates 7-8: Production Deploy & Hardware QA (STRICTLY BLOCKED)                          |  |
|  +--------------------------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------------------------+
```

### 3.1 Detailed Defect Assignment Matrix

| Defect ID | Defect Title | Severity | Canonical Wave | Target Layer & Primary Files | Architectural Dependencies | Owner Authorization Gate |
|---|---|---|---|---|---|---|
| **HAVEN-QA-001** | Role Selection button text truncated ("Create acc...") | Low | **Wave 1** | Flutter UI: `lib/features/role_selection/role_selection_page.dart`, `lib/core/widgets/app_button.dart` | None (Client-only layout) | **Gate 2** |
| **HAVEN-QA-002** | Password input exposes plaintext / lacks secure input hardening | High | **Wave 1** | Flutter Core: `lib/core/widgets/app_text_field.dart`, `lib/features/auth/login_page.dart` | None (Client-only widget) | **Gate 2** |
| **HAVEN-QA-004** | Notification permission reports false-positive "Granted" | Medium | **Wave 1** | Native Android: `android/.../NativePermissions.kt`, `GuardianService.kt` | None (Native Android bridge) | **Gate 2** |
| **HAVEN-QA-005** | Revoked devices duplicated in Parent dashboard & device list | High | **Wave 2** | Flutter Repository: `lib/data/repositories/supabase_device_repository.dart` | Wave 1 complete | **Gate 2** |
| **HAVEN-QA-006** | Policy version inconsistency between Dashboard and Devices tab | Medium | **Wave 2** | Flutter Presentation: `lib/features/devices/device_presentation.dart` | Wave 1 complete | **Gate 2** |
| **HAVEN-QA-003** | Device re-credentialing failure breaks telemetry & heartbeat | High | **Wave 3** | Full Stack: `supabase/migrations/`, `supabase/functions/`, `SecureStore.kt` | Waves 1 & 2 complete; Gates 3–6 | **Gate 3 (Review)**<br/>**Gates 4–6 (Staging)** |

---

## 4. Cross-Phase Traceability Reconciliation

The following table demonstrates how defect representations evolved and where contradictions occurred across phases:

| Defect ID | Original Defect Name (`09_defect_register.md`) | Phase 1 Planning (`08_implementation...`) | Phase 1.4 Mislabeled Text | Phase 1.5 Authoritative Resolution |
|---|---|---|---|---|
| **QA-001** | Role Selection button clipped | Step 2 (Wave 1) | Mislabeled as Password field | Restored as **Role Selection Layout (Wave 1)** |
| **QA-002** | Password input plaintext exposure | Step 1 (Wave 1) | Mislabeled as QuickActionsCard | Restored as **Password Input Hardening (Wave 1)** |
| **QA-003** | Device re-credentialing broken | Step 6 (Wave 3) | Labeled as Re-credentialing | Restored as **Device Re-credentialing (Wave 3)** |
| **QA-004** | Notification permission false-positive | Step 3 (Wave 1) | Mislabeled as Device filter | Restored as **Notification Compat Detection (Wave 1)** |
| **QA-005** | Revoked devices duplicated | Step 4 (Wave 2) | Mislabeled as Notification diagnostic | Restored as **Device Repository Active Filter (Wave 2)** |
| **QA-006** | Policy version inconsistency | Step 5 (Wave 2) | Labeled as Policy presentation | Restored as **Policy Presentation Consistency (Wave 2)** |

---

## 5. Architectural Dependency Justification

1. **Why Wave 1 Precedes Wave 2**:
   - `QA-001`, `QA-002`, and `QA-004` address pure client-side usability, input security, and native permission reporting. They do not alter data queries, domain models, or state persistence. Implementing them first establishes a clean baseline and removes immediate user-facing risks.
2. **Why Wave 2 Precedes Wave 3**:
   - `QA-005` and `QA-006` correct how the Parent client interprets device lists and policy statuses from the existing database. Having a clean query layer is essential before Wave 3 introduces re-credentialing status transitions into the device table.
3. **Why Wave 3 is Isolated into Multi-Gate Progression**:
   - `QA-003` modifies identity credentials, PostgreSQL tables, Edge Function handlers, and native Android cryptographic storage. It carries high blast radius and requires its own sequential gate lifecycle (Gates 3 through 6) in disposable staging before production can even be contemplated.

**Conclusion**: The canonical wave assignment is fully reconciled and verified against all historical documentation.
