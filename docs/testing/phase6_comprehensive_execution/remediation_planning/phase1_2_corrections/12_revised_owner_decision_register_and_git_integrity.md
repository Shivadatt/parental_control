# 12 — Revised Owner Decision Register & Git Integrity Certification

**Document ID:** HAVEN-COR-012  
**Phase:** Phase 1.2 — Remediation Plan Correction & Closure (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE DECISION REGISTER & SAFETY CERTIFICATION  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  
**Lineage:** Direct descendant of `5ffc5c1` and approved baseline `80375f5`  

---

## 1. Governance Notice to Product Owner

**Every item below represents an explicit architectural or product governance decision reserved exclusively for the application owner.** No design or wave is pre-authorized. Decisions must be ruled on individually.

### Status Vocabulary:
- **`AWAITING OWNER RULING`**: Fully specified, corrected, and ready for owner evaluation.
- **`APPROVED`**: Formally sanctioned by the owner.
- **`REJECTED`**: Declined by the owner.

---

## 2. Revised Master Decision Register Table

| Decision ID | Target Defect | Topic | Recommended Option | Readiness Status | Separate Backend Approval Needed? |
|---|---|---|---|---|---|
| **`DEC-REM-001`** | `HAVEN-QA-003` | Re-credentialing Protocol Architecture | **Option C with Two-Phase Staging & Committed Attempts** | **READY FOR OWNER RULING** | **YES (Gate C)** |
| **`DEC-REM-002`** | `HAVEN-QA-003` | Challenge Rate Limits & TTL Bounds | **10m TTL, max 5 attempts, max 3 challenges/hr** | **READY FOR OWNER RULING** | **YES (Gate C)** |
| **`DEC-REM-003`** | `HAVEN-QA-003` | Challenge Exchange UX Encoding | **6-character Crockford Base32 with Auto-Normalization** | **READY FOR OWNER RULING** | **YES (Edge Function)** |
| **`DEC-REM-004`** | `HAVEN-QA-005` | Active vs. Historical Device Visibility | **Strict `.eq('status', 'active')` with Separate History Method** | **READY FOR OWNER RULING** | **NO (Client Query)** |
| **`DEC-REM-005`** | `HAVEN-QA-006` | Policy Version Presentation Copy | **Full 4-State Status Mapping + Connectivity Cross-Check** | **READY FOR OWNER RULING** | **NO (Presentation)** |
| **`DEC-REM-006`** | `HAVEN-QA-001` | Role Selection Responsive Layout | **Localized Adaptive Layout (Column on narrow displays)** | **READY FOR OWNER RULING** | **NO (UI Only)** |
| **`DEC-REM-007`** | `HAVEN-QA-002` | Password Input Security Hardening | **Dedicated `isPassword: true` Property in `AppTextField`** | **READY FOR OWNER RULING** | **NO (Core Widget)** |
| **`DEC-REM-008`** | ALL | Implementation Wave Authorization | **Separate Authorization for Wave 1, Wave 2, Wave 3** | **READY FOR OWNER RULING** | **Gated per Wave** |

---

## 3. In-Depth Technical Decision Specifications

---

### DEC-REM-001: Re-credentialing Protocol Architecture (`HAVEN-QA-003`)
- **Decision Requested**: Approve the corrected Option C protocol incorporating two-phase KeyStore staging, structured JSON attempt persistence, and idempotent verification.
- **Technical Basis**: Faithfully implements the binding **Phase 4 Gate A Option C** baseline. Resolves the PL/pgSQL attempt counter rollback bug (REV-001) and lost-response deadlock (REV-002).
- **Remaining Uncertainty**: None in architecture. Staging verification required in Gate C/D.
- **Consequences of Approval**: Enables relationship-preserving re-credentialing, restoring heartbeat and telemetry uploads after app reinstall without unpairing.
- **Consequences of Rejection**: Reinstalled Child devices remain permanently "Offline" unless unlinked via destructive `recover_device`.
- **Implementation Boundary**: `SecureStore.kt`, `GuardianService.kt`, `family-admin`, `device-register`, `20261124000100_device_recredentialing.sql`.
- **Separate Backend Approval Required?**: **YES (Gate C Migration Approval)**.

---

### DEC-REM-002: Challenge Rate Limits & TTL Bounds (`HAVEN-QA-003`)
- **Decision Requested**: Approve 10-minute challenge TTL, maximum 5 redemption attempts, and maximum 3 challenge generations per device per hour.
- **Technical Basis**: Enforces mathematical guess probability $\le 4.65 \times 10^{-9}$ while throttling table creation.
- **Remaining Uncertainty**: None.
- **Consequences of Approval**: Locks in server-side rate limits and challenge cleanup parameters.
- **Consequences of Rejection**: Brute-force bounds remain undefined; migration schema cannot be finalized.
- **Implementation Boundary**: Edge Functions (`family-admin`, `device-register`) and RPC.
- **Separate Backend Approval Required?**: **YES**.

---

### DEC-REM-003: Challenge Exchange UX Encoding (`HAVEN-QA-003`)
- **Decision Requested**: Approve **6-character Crockford Base32** (`0–9`, `A–Z` excluding I, L, O, U) with automatic uppercase and digit normalization.
- **Technical Basis**: Resolves mobile keyboard transcription confusion (`0` vs `O`, `1` vs `I`) while maintaining 30.1 bits of true cryptographic entropy.
- **Remaining Uncertainty**: None.
- **Consequences of Approval**: Child enters code effortlessly without accidental lockout caused by transcription typos.
- **Consequences of Rejection**: Mixed-case alphanumeric confusion persists, risking accidental lockout after 5 attempts.
- **Implementation Boundary**: Edge Function generator and Flutter Child entry form.
- **Separate Backend Approval Required?**: **YES**.

---

### DEC-REM-004: Active vs. Historical Device Visibility (`HAVEN-QA-005`)
- **Decision Requested**: Approve filtering strictly on `.eq('status', 'active')` for Parent active views, providing an explicit `fetchDeviceHistory()` method for archived records.
- **Technical Basis**: Resolves REV-006 (pending device leakage) and eliminates boolean flag coupling (REV-012).
- **Remaining Uncertainty**: None. Aligns with `fetchMyDevice()`.
- **Consequences of Approval**: Duplicate revoked cards and ghost pending cards are 100% removed from Parent dashboards.
- **Consequences of Rejection**: Duplicate cards persist on Parent screens.
- **Implementation Boundary**: `lib/data/repositories/supabase_device_repository.dart` and `repository_contracts.dart`.
- **Separate Backend Approval Required?**: **NO (Client Query Layer Only)**.

---

### DEC-REM-005: Policy Version Presentation Copy (`HAVEN-QA-006`)
- **Decision Requested**: Approve comprehensive presentation model evaluating `enforcement_status` (`active`, `pending`, `unsupported`, `failed`) and device connectivity.
- **Technical Basis**: Resolves REV-007. Distinguishes in-flight sync from device enforcement failures and offline states.
- **Remaining Uncertainty**: None. Pure functional presentation logic.
- **Consequences of Approval**: Parents see truthful, accurate policy status ("Enforced", "Update failed", "Pending reconnection") across all screens.
- **Consequences of Rejection**: Conflicting and misleading version numbers persist across Dashboard and Devices tabs.
- **Implementation Boundary**: `lib/features/devices/device_presentation.dart`.
- **Separate Backend Approval Required?**: **NO (Pure Client Presentation)**.

---

### DEC-REM-006: Role Selection Responsive Layout (`HAVEN-QA-001`)
- **Decision Requested**: Approve localizing the layout fix to `RoleSelectionPage` (adaptive vertical `Column` on narrow displays < 380dp), strictly quarantining `AppButton`.
- **Technical Basis**: Resolves REV-004 (88 call site blast radius) and REV-011 (button asymmetry). Preserves WCAG 1.4.4 accessibility font scaling up to 2.0x.
- **Remaining Uncertainty**: None.
- **Consequences of Approval**: Eliminates "Create acc..." clipping while protecting all other app buttons and accessibility users.
- **Consequences of Rejection**: Text clipping persists on 480dpi displays, or global `AppButton` changes risk regressions across 24 screens.
- **Implementation Boundary**: `lib/features/role_selection/role_selection_page.dart` only.
- **Separate Backend Approval Required?**: **NO (UI Only)**.

---

### DEC-REM-007: Password Input Security Hardening (`HAVEN-QA-002` / `SEC-001`)
- **Decision Requested**: Approve dedicated `isPassword: true` property in `AppTextField`, decoupling security hardening from the eyeball visibility toggle.
- **Technical Basis**: Resolves REV-003 and REV-010. Ensures keyboard suggestions and autocorrect remain permanently disabled even when the password is visually unmasked.
- **Remaining Uncertainty**: None.
- **Consequences of Approval**: Permanently closes SEC-001 credential leakage vulnerability across all authentication screens.
- **Consequences of Rejection**: Passwords can be indexed and predicted by keyboard caches whenever the user reveals their password.
- **Implementation Boundary**: `lib/core/widgets/app_text_field.dart`, `login_page.dart`, `register_page.dart`.
- **Separate Backend Approval Required?**: **NO (Client Core Widget)**.

---

### DEC-REM-008: Phased Implementation Authorization
- **Decision Requested**: Formally authorize implementation across three discrete, independent wave decisions:
  - **Decision 8.1 (Wave 1 Authorization)**: Authorize immediate implementation of client hardening: QA-001 (localized layout), QA-002 (dedicated `isPassword`), QA-004 (channel check).
  - **Decision 8.2 (Wave 2 Authorization)**: Authorize immediate implementation of repository & presentation: QA-005 (`fetchActiveDevices`), QA-006 (comprehensive policy model).
  - **Decision 8.3 (Wave 3 Gated Authorization)**: Authorize drafting Gate C database migration (`20261124000100_device_recredentialing.sql`) and Edge Functions for testing in disposable staging containers.
- **Technical Basis**: Isolates low-risk client fixes from multi-tier database migrations.
- **Remaining Uncertainty**: Wave 3 requires staging test verification before mobile deployment.
- **Consequences of Approval**: Wave 1 and Wave 2 can be shipped immediately to resolve 5 of 6 defects without backend risk.
- **Consequences of Rejection**: All defect fixes remain blocked in planning.

---

## 4. Git Safety & Review Integrity Certification

### 4.1 Git Lineage Audit
- **Workspace Directory**: `D:\parentcontrol_app`
- **Active Branch**: `main`
- **Initial HEAD**: `56636f62d5144610ae12c89d02d582feb48217fc`
- **Final HEAD**: `56636f62d5144610ae12c89d02d582feb48217fc`
- **Verified Ancestor Baseline 1**: `5ffc5c170add4bfafd236beb633f00b6fe86243b` (exit code `0`)
- **Verified Ancestor Baseline 2**: `80375f518139bf922bc1b66c998691bee912af44` (exit code `0`)

### 4.2 Staging Index & Working Tree Preservation
- **Staging Index**: Pre-existing staged files from Phase 1 and Phase 1.1 remain completely untouched. Zero `git add`, `git reset`, `git restore`, `git commit`, `git checkout`, or `git clean` commands were executed.
- **Working Tree**: Zero unstaged modifications exist across tracked files.
- **Untracked Additions**: The only additions are the 12 planning reports authored in `docs/testing/phase6_comprehensive_execution/remediation_planning/phase1_2_corrections/`.

### 4.3 Formal Non-Destructive Certification Checklist
- [x] **Zero Source Code Edited**: No changes to Dart (`lib/`), Kotlin (`android/`), Swift (`ios/`), or native bridges.
- [x] **Zero Test Code Edited**: No changes to unit, widget, or integration test suites.
- [x] **Zero Backend Operations**: No migrations applied, no RPCs modified, no Edge Functions deployed, no database records changed.
- [x] **Zero Device Interaction**: Connected devices (`emulator-5554` and `5HXWRGQ4IFU8WS4T`) remained completely idle.
- [x] **Zero Account / Session Modifications**: No sign-ins, sign-outs, token rotations, password resets, or secret extractions.
- [x] **Zero Secret Reading**: `.tools/live_config.env` was never accessed or read.
- [x] **Zero Builds / Tests Run**: Only static code and documentation inspection was performed.

---

## 5. Mandatory Final Statement

Phase 1.2 — Remediation Plan Correction & Closure completed. Only read-only source, architecture, report, and Git inspection was performed. The 13 independent review findings were assessed and their corrected designs and remaining uncertainties were documented. No application source, tests, configuration, database, backend, device, account, family, pairing, session, permission, or credential state was intentionally modified. No tests, builds, deployment, or runtime QA were performed. No Git staging/index mutation was performed. All remediation implementation remains pending explicit owner approval.
