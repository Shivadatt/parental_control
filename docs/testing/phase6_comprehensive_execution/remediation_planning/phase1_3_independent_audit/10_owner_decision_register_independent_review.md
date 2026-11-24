# 10 — Independent Review of Owner Decision Register: DEC-REM-001 Through DEC-REM-008

**Document ID:** HAVEN-AUD-010  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Audit Target:** Owner Decision Register (`12_revised_owner_decision_register_and_git_integrity.md`)  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary & Governance Notice

This report provides an independent technical review of the eight formal Owner Decision items (`DEC-REM-001` through `DEC-REM-008`) submitted in Phase 1.2.

**Fundamental Governance Principle**: Every decision represents an architectural or policy determination reserved exclusively for the product owner. No remediation code may be authored, no database migration executed, and no device state modified without an explicit, recorded ruling.

---

## 2. Independent Evaluation of the Eight Owner Decision Items

---

### DEC-REM-001: Re-credentialing Protocol Architecture (`HAVEN-QA-003`)
- **Requested Ruling**: Authorize Option C incorporating two-phase KeyStore pre-staging (`candidate_secret`), structured JSON attempt persistence, and idempotent verification (`verify_device_rotation`).
- **Technical Justification**: Faithfully implements the binding Phase 4 Gate A Option C architecture. Resolves the PL/pgSQL rollback flaw (`REV-001`) and the lost-response deadlock (`REV-002`). Preserves device UUID, family links, and historical telemetry.
- **Dependencies**: Android `SecureStore.kt`, `GuardianService.kt`, Edge Functions (`family-admin`, `device-register`), SQL Migration `20261124000100_device_recredentialing.sql`.
- **Forward-Recovery Implications**: If an operational issue occurs post-release, schema down-migrations are strictly forbidden. System pauses via feature flag (`FEATURE_RECREDENTIALING_ENABLED = false`) while rotated devices continue reporting heartbeats.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE WITH CONDITIONS)**. Implementation must be gated behind disposable staging container verification (Gate C / Gate D).

---

### DEC-REM-002: Challenge Rate Limits & TTL Bounds (`HAVEN-QA-003`)
- **Requested Ruling**: Approve 10-minute challenge TTL, maximum 5 redemption attempts per token, and maximum 3 challenge generations per device per hour.
- **Technical Justification**: Enforces mathematical guess probability $P \le 4.65 \times 10^{-9}$ per challenge and cumulative hourly bound $P \approx 1.4 \times 10^{-8}$. Prevents database table bloat (`REV-013`).
- **Dependencies**: Edge Function `/family-admin` and PL/pgSQL function `rotate_device_secret`.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE)**.

---

### DEC-REM-003: Challenge Exchange UX Encoding (`HAVEN-QA-003`)
- **Requested Ruling**: Approve **6-character Crockford Base32** (`0–9`, `A–Z` excluding I, L, O, U) with automatic uppercase and digit normalization.
- **Technical Justification**: Resolves touchscreen transcription errors (`0` vs `O`, `1` vs `I`) (`REV-009`) while maintaining 30.0 bits of true cryptographic entropy ($1.07 \times 10^9$ space).
- **Dependencies**: Deno CSPRNG generator in `/family-admin` and Flutter Child input normalization formatter.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE)**.

---

### DEC-REM-004: Active vs. Historical Device Visibility (`HAVEN-QA-005`)
- **Requested Ruling**: Approve filtering strictly on `.eq('status', 'active')` for active Parent views, providing an explicit `fetchDeviceHistory()` method for archived records.
- **Technical Justification**: Resolves ghost pending device leakage (`REV-006`) and removes boolean flag coupling (`REV-012`). Aligns Parent dashboard queries with Child `fetchMyDevice()`.
- **Dependencies**: Pure client query layer in `supabase_device_repository.dart` and `repository_contracts.dart`. Zero database migrations.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE)**.

---

### DEC-REM-005: Policy Version Presentation Copy (`HAVEN-QA-006`)
- **Requested Ruling**: Approve comprehensive presentation model evaluating `enforcement_status` (`enforced`, `pending`, `unsupported`, `failed`) and device connectivity.
- **Technical Justification**: Resolves misleading sync copy (`REV-007`). Accurately surfaces failed updates, unmanaged devices, and offline reconnection delays.
- **Dependencies**: Pure client presentation helper in `device_presentation.dart`. Zero database migrations.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE WITH CONDITION)**. Condition: Rectify report `07_rev006...` to use canonical status `'enforced'` instead of `'active'`.

---

### DEC-REM-006: Role Selection Responsive Layout (`HAVEN-QA-001`)
- **Requested Ruling**: Localize the layout fix to `RoleSelectionPage` (adaptive vertical `Column` on narrow displays), strictly quarantining `AppButton`.
- **Technical Justification**: Resolves 88-call-site blast radius (`REV-004`) and paired button font asymmetry (`REV-011`). Preserves WCAG 1.4.4 font scaling up to 2.0x.
- **Dependencies**: Pure UI layout in `role_selection_page.dart`.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE WITH CONDITION)**. Condition: Bind layout to `LayoutBuilder` with 420dp / `textScale > 1.15` breakpoint.

---

### DEC-REM-007: Password Input Security Hardening (`HAVEN-QA-002` / `SEC-001`)
- **Requested Ruling**: Approve dedicated `isPassword: true` property in `AppTextField`, decoupling security hardening from the eyeball visibility toggle.
- **Technical Justification**: Resolves credential leakage vulnerability (`REV-003`) and OEM IME variations (`REV-010`). Guarantees suggestions and autocorrect remain suppressed during eyeball reveals.
- **Dependencies**: `app_text_field.dart`, `login_page.dart`, `register_page.dart`.
- **Auditor Ruling Recommendation**: **READY FOR OWNER RULING (APPROVE WITH CONDITION)**. Condition: Remove non-existent PIN caller from test specifications.

---

### DEC-REM-008: Phased Implementation Authorization Governance
- **Requested Ruling**: Formally authorize implementation across three discrete, independent wave decisions (8.1 for Wave 1, 8.2 for Wave 2, 8.3 for Wave 3).
- **Audit of Governance Claims**: The auditor conducted a strict audit to ensure no prior approval is misrepresented:
  - **Phase 4 Gate A Ruling**: Formally approved ONLY the conceptual architecture of Option C over Options A/B. It did **NOT** grant implementation or migration authorization.
  - **Planning Package Verification**: Phase 1.2 planning documents correctly respect this boundary. Document `12_revised_owner_decision...` states explicitly: *"No design or wave is pre-authorized. Decisions must be ruled on individually."*

---

## 3. Strict Separation of the Eight Lifecycle Authorization Gates

To ensure total transparency, the auditor establishes the strict separation of the 8 discrete lifecycle gates:

```
[Gate 1: Architecture Baseline Approval]  ==> COMPLETED in Phase 4 Gate A (Option C Concept)
                     │
[Gate 2: Client Source Implementation]    ==> READY for Owner Decision 8.1 & 8.2 (Wave 1 & Wave 2)
                     │
[Gate 3: Migration Design Approval]       ==> READY for Owner Decision 8.3 (Wave 3 Script Drafting)
                     │
[Gate 4: Migration Application (Sandbox)] ==> GATED behind Disposable Staging Container
                     │
[Gate 5: Edge Function Implementation]   ==> GATED behind Gate 4 Sandbox Pass
                     │
[Gate 6: Staging Integration Deploy]     ==> GATED behind Disposable Staging Container Tests
                     │
[Gate 7: Production Deployment]          ==> STRICTLY BLOCKED; Requires Separate Owner Ruling
                     │
[Gate 8: Live Hardware QA Audit]         ==> STRICTLY BLOCKED; Requires Separate Owner Ruling
```

### Official Governance Status:
All eight decision items (`DEC-REM-001` through `DEC-REM-008`) are **READY FOR OWNER RULING**.
