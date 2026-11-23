# 10 — Owner Decision & Approval Register

**Document ID:** HAVEN-REM-010  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Notice to Owner

**Nothing in this file is pre-approved.** Every item below represents an explicit architectural or product governance decision reserved exclusively for the application owner.

### Status Vocabulary
- **`AWAITING OWNER`**: The decision is pending owner evaluation. No engineering implementation may begin on this workstream.
- **`APPROVED`**: The owner has formally sanctioned the specified option.
- **`REJECTED`**: The owner has declined the proposal.

---

## 2. Decision Register Table

| Decision ID | Target Defect | Topic | Recommended Option | Status |
|---|---|---|---|---|
| **DEC-REM-001** | HAVEN-QA-003 | Architecture Selection for Device Re-credentialing | **Option C (Two-Factor Challenge + Atomic RPC)** | **AWAITING OWNER** |
| **DEC-REM-002** | HAVEN-QA-003 | Challenge TTL and Attempt Limits | **10-minute TTL, 5 maximum attempts** | **AWAITING OWNER** |
| **DEC-REM-003** | HAVEN-QA-003 | Challenge Exchange UX | **6-digit alphanumeric code + in-band sync** | **AWAITING OWNER** |
| **DEC-REM-004** | HAVEN-QA-005 | Revoked Device Visibility in Parent Views | **Filter from active views; optional Archived accordion** | **AWAITING OWNER** |
| **DEC-REM-005** | HAVEN-QA-006 | Policy Version Presentation Copy | **Dual status: "Policy v2 · Updating to v4..."** | **AWAITING OWNER** |
| **DEC-REM-006** | HAVEN-QA-001 | Role Selection Button Responsive Layout | **FittedBox label scaling with 8dp button gap** | **AWAITING OWNER** |
| **DEC-REM-007** | HAVEN-QA-002 | Password Field Hardening Enforcement | **Secure-by-default inside AppTextField** | **AWAITING OWNER** |
| **DEC-REM-008** | ALL | Phased Implementation Authorization | **Approve Wave 1 & Wave 2, Gate C for Wave 3** | **AWAITING OWNER** |

---

## 3. Detailed Decision Records

---

### DEC-REM-001: Architecture Selection for Device Re-credentialing (`HAVEN-QA-003`)
- **Question**: Which architectural pattern shall be used to reconcile a reinstalled Child device's new KeyStore secret with its existing active database record?
- **Options**:
  - **Option C (Recommended)**: Parent-approved, Child-authenticated, single-use challenge token triggering atomic `rotate_device_secret` RPC. Preserves `devices.id` UUID, family membership, and telemetry history.
  - **Option B**: Child-only self-rotation endpoint. (High security risk: stolen child JWT could hijack hardware identity).
  - **Option D**: Unlink and re-pair using existing `recover_device`. (Destructive: destroys family membership and wipes telemetry history).
- **Consequence of Not Deciding**: Reinstalled or updated Child devices remain permanently "Offline" and unable to upload telemetry.
- **Files Approval Would Open**:
  - `supabase/migrations/20261124000100_device_recredentialing.sql`
  - `supabase/functions/family-admin/index.ts`
  - `supabase/functions/device-register/index.ts`
  - `lib/features/child/controllers/child_shell_controller.dart`
- **Status**: **AWAITING OWNER**

---

### DEC-REM-002: Challenge TTL and Attempt Limits (`HAVEN-QA-003`)
- **Question**: What time-to-live and brute-force retry bounds should govern the re-credentialing challenge?
- **Options**:
  - **10 minutes, 5 attempts (Recommended)**: Industry standard for interactive device pairing/reconnection; aligns with Phase 4 Gate A baseline.
  - **15 minutes, 3 attempts**: More conservative brute-force margin; slightly longer parent-child coordination window.
  - **5 minutes, 3 attempts**: Maximum security posture; requires tighter physical proximity between parent and child.
- **Consequence of Not Deciding**: Challenge table schema cannot be frozen.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-003: Challenge Exchange UX (`HAVEN-QA-003`)
- **Question**: How should the parent communicate the re-credentialing challenge to the child device?
- **Options**:
  - **In-App Code Entry (Recommended)**: Parent app displays a 6-digit code; Child app displays a prompt "Enter Reconnect Code from Parent".
  - **QR Code Scan**: Parent app generates a QR code; Child app scans via camera. (Requires camera permission on Child).
  - **Automatic In-Band Realtime Push**: Parent taps "Reconnect", server pushes challenge via Supabase Realtime/FCM. (Simplest UX, but requires active background socket on Child).
- **Consequence of Not Deciding**: Child UI flow cannot be finalized.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-004: Revoked Device Visibility in Parent Views (`HAVEN-QA-005`)
- **Question**: How should revoked devices be handled in the Parent Dashboard and Devices tab?
- **Options**:
  - **Option A (Recommended)**: Exclude completely from the active device list; provide a separate collapsible "Archived Devices" tile at the bottom of the Devices tab.
  - **Option B**: Hard filter exclusion only. Revoked devices are never displayed in the UI, but remain in the database for audit logs.
  - **Option C**: Keep in the main list, but visually gray out with a prominent "Revoked" watermark. (Preserves current confusion risk).
- **Consequence of Not Deciding**: Duplicate device cards persist on Parent screens.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-005: Policy Sync-Lag Presentation Copy (`HAVEN-QA-006`)
- **Question**: What string format should be displayed when the server desired policy version has not yet been applied by the device?
- **Options**:
  - **Option A (Recommended)**: `"Policy v2 · Updating to v4..."` (Displays active applied version while indicating desired version is pending).
  - **Option B**: `"Policy v4 (Pending sync)"` (Focuses on target version).
  - **Option C**: `"Policy v2"` on Devices tab and `"Policy v4"` on Dashboard. (Status quo defect).
- **Consequence of Not Deciding**: Dashboard and Devices tab continue to show divergent policy numbers.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-006: Role Selection Button Responsive Layout (`HAVEN-QA-001`)
- **Question**: How should the 138dp button width constraint on 480dpi screens be resolved on `RoleSelectionPage`?
- **Options**:
  - **Option A (Recommended)**: Wrap button labels in `FittedBox(fit: BoxFit.scaleDown)` inside `AppButton`, and adjust intra-button gap from 10dp to 8dp. Preserves single-line appearance and 48dp touch target.
  - **Option B**: Stack buttons vertically (`Column`) when logical screen width is less than 380dp. (Changes card height).
  - **Option C**: Shorten button label to "Register". (Slight copy divergence).
- **Consequence of Not Deciding**: "Create acc..." clipping persists on high-density displays.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-007: Password Field Hardening Enforcement (`HAVEN-QA-002` / `SEC-001`)
- **Question**: Should password hardening (`enableSuggestions: false`, `autocorrect: false`, `password: true`) be enforced automatically inside `AppTextField` when `obscureText: true`?
- **Options**:
  - **Option A (Recommended)**: Yes, secure-by-default inside `AppTextField`. Eliminates human error on current and future password fields.
  - **Option B**: Require callers to pass parameters explicitly (`enableSuggestions: false`). (Fragile, error-prone).
- **Consequence of Not Deciding**: Plaintext credential and predictive dictionary exposure remains unresolved.
- **Status**: **AWAITING OWNER**

---

### DEC-REM-008: Master Remediation Implementation Authorization
- **Question**: Does the owner authorize engineering to begin implementation according to the phased sequence?
- **Options**:
  - **Full Authorization (Recommended)**: Authorize Wave 1 (Client UI/Sec), Wave 2 (Repository/Presentation), and authorize drafting of Gate C Migration for Wave 3.
  - **Client-Only Wave 1 & 2 Authorization**: Authorize only Defects 001, 002, 004, 005, 006. Defer Defect 003.
  - **Hold**: No implementation authorized.
- **Status**: **AWAITING OWNER**
