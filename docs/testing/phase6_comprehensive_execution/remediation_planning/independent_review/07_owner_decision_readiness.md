# 07 — Owner Decision Readiness & Governance Review

**Document ID:** HAVEN-REV-007  
**Phase:** Phase 1.1 — Remediation Plan Independent Review (Strictly Read-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE INDEPENDENT TECHNICAL REVIEW  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Governance Mandate

The Phase 1 planning package submitted eight formal decision items in `10_owner_decision_and_approval_register.md` (`DEC-REM-001` through `DEC-REM-008`).

This review independently evaluates each decision to determine:
1. Whether the technical context and trade-offs are accurately presented to the owner.
2. Whether technical prerequisites have been satisfied.
3. Whether critical questions or vulnerabilities remain open.
4. The authoritative independent recommendation for owner action.

---

## 2. Independent Evaluation of the Eight Owner Decisions

---

### DEC-REM-001: Architecture Selection for Device Re-credentialing (`HAVEN-QA-003`)
- **Requested Decision**: Authorize Option C (Parent Approval + Child Auth + 10m Challenge + Atomic RPC) to re-credential devices without unlinking.
- **Review Evaluation**: **APPROVE WITH CONDITIONS (NOT YET IMPLEMENTABLE)**.
- **Prerequisites**: Approval of Option C architecture is conceptually sound and faithful to Phase 4 Gate A.
- **Unresolved Technical Questions**:
  - The PL/pgSQL attempt counter rollback bug (REV-001) must be corrected.
  - The lost-response / client KeyStore persistence failure recovery mechanism (REV-002) must be specified.
- **Independent Recommendation**: **Approve Option C as the binding architectural model**, but explicitly CONDITION implementation authorization on engineering submitting a revised RPC specification that fixes REV-001 and REV-002.
- **Status for Owner Ruling**: **READY FOR CONDITIONAL APPROVAL**.

---

### DEC-REM-002: Challenge TTL and Attempt Limits (`HAVEN-QA-003`)
- **Requested Decision**: Approve 10-minute challenge TTL and 5 maximum verification attempts.
- **Review Evaluation**: **APPROVE AS RECOMMENDED**.
- **Prerequisites**: Server-side attempt enforcement that commits counter increments.
- **Unresolved Technical Questions**: None. The 10-minute window and 5 attempts align with Phase 4 Gate A baseline and provide an acceptable balance between mobile user friction and brute-force resistance ($5 / 10^9 \approx 5 \times 10^{-9}$ guess probability).
- **Independent Recommendation**: **APPROVE**.
- **Status for Owner Ruling**: **READY FOR APPROVAL**.

---

### DEC-REM-003: Challenge Exchange UX (`HAVEN-QA-003`)
- **Requested Decision**: Approve a 6-digit alphanumeric reconnection code entered on the Child device.
- **Review Evaluation**: **APPROVE WITH USABILITY MODIFICATION**.
- **Prerequisites**: Elimination of ambiguous characters.
- **Unresolved Technical Questions**:
  - Alphanumeric codes on soft keyboards introduce character confusion (`0` vs `O`, `1` vs `I`). Non-technical children and parents will make transcription mistakes that exhaust the 5 allowed attempts.
- **Independent Recommendation**: **APPROVE WITH MODIFICATION**: Restrict the code to **Crockford's Base32** (digits 0–9 and 22 uppercase letters, omitting I, L, O, and U). Automatically normalize user input (`.toUpperCase()`, map `0` to `O` if entered).
- **Status for Owner Ruling**: **READY FOR APPROVAL WITH CONDITION**.

---

### DEC-REM-004: Revoked Device Visibility in Parent Views (`HAVEN-QA-005`)
- **Requested Decision**: Exclude revoked devices from active dashboard views with an optional collapsible "Archived Devices" accordion on the Devices tab.
- **Review Evaluation**: **APPROVE WITH QUERY CLARIFICATION**.
- **Prerequisites**: Explicit status filtering in `SupabaseDeviceRepository`.
- **Unresolved Technical Questions**:
  - The planning report proposed `.neq('status', 'revoked')`, which inadvertently allows abandoned `pending` devices to appear.
- **Independent Recommendation**: **APPROVE**, with the explicit technical directive that the repository must query `.eq('status', 'active')` for active views, and provide a separate `fetchDeviceHistory()` method for the archived view.
- **Status for Owner Ruling**: **READY FOR APPROVAL WITH CONDITION**.

---

### DEC-REM-005: Policy Sync-Lag Presentation Copy (`HAVEN-QA-006`)
- **Requested Decision**: Approve dual-version presentation string format: `"Policy v2 · Updating to v4..."`.
- **Review Evaluation**: **APPROVE WITH STATE EXPANSION**.
- **Prerequisites**: Incorporating all backend enforcement statuses.
- **Unresolved Technical Questions**:
  - If a child device reports an enforcement failure (`enforcement_status == 'failed'`) or lacks Device Owner capability (`unsupported`), displaying `"Updating to v4..."` misrepresents an error as in-progress synchronization.
- **Independent Recommendation**: **APPROVE**, with the requirement that the presentation helper evaluate `enforcement_status`:
  - In-flight sync: `"Policy v$applied · Applying v$desired..."`
  - Failed enforcement: `"Policy v$applied · Update failed (v$desired)"` (tone: danger)
  - Unsupported capability: `"Policy v$applied · Advisory only"`
- **Status for Owner Ruling**: **READY FOR APPROVAL WITH CONDITION**.

---

### DEC-REM-006: Role Selection Button Responsive Layout (`HAVEN-QA-001`)
- **Requested Decision**: Approve `FittedBox(fit: BoxFit.scaleDown)` label scaling inside `AppButton` and reducing button gap from 10dp to 8dp.
- **Review Evaluation**: **REJECT AS SUBMITTED — APPROVE LOCALIZED ALTERNATIVE**.
- **Prerequisites**: Preserving WCAG accessibility font scaling and protecting the other 85+ `AppButton` call sites.
- **Unresolved Technical Questions**:
  - Modifying `AppButton` globally causes uncontrolled text shrinking across 24 screens and counteracts Android OS accessibility font scaling.
- **Independent Recommendation**: **REJECT global `AppButton` changes**. Approve localizing the fix to `RoleSelectionPage` using an adaptive layout (e.g. stacking buttons vertically if screen width < 380dp, or adjusting button padding locally).
- **Status for Owner Ruling**: **READY FOR MODIFIED APPROVAL**.

---

### DEC-REM-007: Password Field Hardening Enforcement (`HAVEN-QA-002` / `SEC-001`)
- **Requested Decision**: Enforce secure-by-default behavior inside `AppTextField` when `obscureText: true`.
- **Review Evaluation**: **APPROVE WITH SECURITY HARDENING**.
- **Prerequisites**: Decoupling password protection from eyeball visibility toggle.
- **Unresolved Technical Questions**:
  - When the user toggles text visibility to verify their password, `obscureText` becomes `false`. Tying hardening solely to `obscureText` causes keyboard suggestions to re-engage while the password is plain text (REV-003).
- **Independent Recommendation**: **APPROVE**, with the mandatory correction that hardening flags (`enableSuggestions: false`, `autocorrect: false`, `Semantics.password: true`) are driven by an explicit `isPassword: true` property or `autofillHints`, keeping security active even when text is visually revealed.
- **Status for Owner Ruling**: **READY FOR APPROVAL WITH CONDITION**.

---

### DEC-REM-008: Phased Implementation Authorization
- **Requested Decision**: Authorize implementation of Wave 1, Wave 2, and drafting Gate C database migrations for Wave 3.
- **Review Evaluation**: **PARTIAL AUTHORIZATION RECOMMENDED**.
- **Independent Recommendation**:
  1. **Wave 1 (Client UI & Core Security)**: **AUTHORIZE** subject to conditions on DEC-REM-006 (localized button layout) and DEC-REM-007 (dedicated `isPassword` flag).
  2. **Wave 2 (Repository & Presentation)**: **AUTHORIZE** subject to conditions on DEC-REM-004 (`status = 'active'`) and DEC-REM-005 (full status mapping).
  3. **Wave 3 (Distributed Credential Recovery)**: **DO NOT AUTHORIZE YET**. Keep Wave 3 blocked until the engineering team submits revised SQL and state machine specifications addressing REV-001 (attempt counter rollback bug) and REV-002 (lost response recovery).
- **Status for Owner Ruling**: **PARTIALLY READY FOR OWNER RULING**.

---

## 3. Owner Decision Sign-Off Summary Table

| Decision ID | Defect ID | Topic | Reviewer Recommendation | Action Required by Owner |
|---|---|---|---|---|
| **DEC-REM-001** | `HAVEN-QA-003` | Option C Architecture Selection | **APPROVE WITH CONDITIONS** | Rule: Approve Option C concept; block RPC implementation until revision. |
| **DEC-REM-002** | `HAVEN-QA-003` | 10m TTL & 5 Attempt Bounds | **APPROVE** | Rule: Approve 10m TTL and 5 attempts. |
| **DEC-REM-003** | `HAVEN-QA-003` | Challenge Exchange UX | **APPROVE WITH CONDITION** | Rule: Approve Crockford Base32 6-character code format. |
| **DEC-REM-004** | `HAVEN-QA-005` | Revoked Device Filtering | **APPROVE WITH CONDITION** | Rule: Approve `.eq('status', 'active')` for dashboards; separate history query. |
| **DEC-REM-005** | `HAVEN-QA-006` | Policy Version Copy | **APPROVE WITH CONDITION** | Rule: Approve dual copy with support for `failed` and `unsupported` states. |
| **DEC-REM-006** | `HAVEN-QA-001` | Role Selection Button Layout | **REJECT GLOBAL / APPROVE LOCAL** | Rule: Reject `AppButton` edit; approve localized `RoleSelectionPage` adaptive layout. |
| **DEC-REM-007** | `HAVEN-QA-002` | Password Input Hardening | **APPROVE WITH CONDITION** | Rule: Approve dedicated `isPassword: true` flag in `AppTextField`. |
| **DEC-REM-008** | ALL | Phased Implementation Authorization | **PARTIAL APPROVAL** | Rule: Authorize Wave 1 & Wave 2; keep Wave 3 blocked pending revised design. |
