# 11 — Remediation Risk Register

**Document ID:** HAVEN-REM-011  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Risk Evaluation Methodology

Every proposed remediation is evaluated across four risk dimensions:
1. **Implementation Complexity**: Lines of code touched, architectural tiers crossed.
2. **Blast Radius**: Extent of user workflows or system services affected if a failure occurs.
3. **Session Invalidation Risk**: Likelihood of invalidating existing Parent/Child authenticated sessions.
4. **Backend / Schema Drift Risk**: Likelihood of orphaned database records, RLS breaches, or lock contention.

---

## 2. Comprehensive Defect Remediation Risk Matrix

| Defect ID | Severity | Affected Files | Backend Impact? | Migration Needed? | Regression Risk | Session Risk | Mitigation Strategy | Owner Approval Required |
|---|---|---|---|---|---|---|---|---|
| **HAVEN-QA-001** | **Low** | `app_button.dart`, `role_selection_page.dart` | None | None | **Low** (UI only) | **Zero** | `FittedBox` bounded downscale; automated widget test on 360dp width. | DEC-REM-006 |
| **HAVEN-QA-002** | **High** | `app_text_field.dart`, `login_page.dart`, `register_page.dart` | None | None | **Low** (Input behavior) | **Zero** | Secure-by-default logic only overrides when `obscureText: true`; unit test semantics. | DEC-REM-007 |
| **HAVEN-QA-003** | **High** | `SecureStore.kt`, `GuardianService.kt`, `family-admin`, `device-register`, `20261124000100_*.sql` | High (New RPC & table) | **Yes** (Challenge table + RPC) | **High** (Auth protocol) | **Low** (Preserves existing JWT) | Atomic PostgreSQL transaction; rate-limiting (5 attempts); 10m TTL; down-migration ready. | DEC-REM-001, 002, 003 |
| **HAVEN-QA-004** | **Medium** | `NativePermissions.kt` | None | None | **Low** (Native check) | **Zero** | `NotificationManagerCompat` standard Android API; Robolectric tests for API 31 & 34. | Standard Review |
| **HAVEN-QA-005** | **High** | `repository_contracts.dart`, `supabase_device_repository.dart` | None (Client query filter) | None | **Low** (Projection filter) | **Zero** | Default `includeRevoked = false`; optional parameter allows historical query if needed. | DEC-REM-004 |
| **HAVEN-QA-006** | **Medium** | `device_presentation.dart`, `dashboard_controller.dart`, `devices_controller.dart` | None | None | **Low** (String formatter) | **Zero** | Pure functional helper in `device_presentation.dart`; unit test coverage for sync states. | DEC-REM-005 |

---

## 3. High-Level Systemic Risks & Safeguards

### Risk 1: Accidental QA Session Invalidation (Critical Risk)
- **Description**: Reinstalling the app or modifying authentication tokens during verification could invalidate the existing Parent and Child QA sessions, violating Absolute Rule 2.1.
- **Safeguard**: 
  - All automated testing must run in hermetic unit test suites (`flutter test`, `cargo/deno test`, `gradle test`) using mock credentials.
  - No interactive sign-out or session clear commands may be executed on the connected test devices (`emulator-5554` or `5HXWRGQ4IFU8WS4T`).

### Risk 2: KeyStore Ephemerality on Debug Rebuilds
- **Description**: Deploying a new debug build of the Child APK on the physical Realme device overwrites the KeyStore master key, triggering the exact re-credentialing deadlock described in `HAVEN-QA-003`.
- **Safeguard**:
  - The implementation of `HAVEN-QA-003` provides the required solution for this condition.
  - Until `HAVEN-QA-003` is deployed to the backend, the existing Child APK on `5HXWRGQ4IFU8WS4T` must NOT be reinstalled or updated.

### Risk 3: Database Transaction Deadlock during Secret Rotation
- **Description**: If concurrent requests attempt to rotate secrets for the same device, database locks could contend or deadlock.
- **Safeguard**:
  - The `rotate_device_secret` RPC locks the specific challenge row and device row using `SELECT ... FOR UPDATE` with an explicit single-row filter.
  - The single-use challenge guarantees that only one request can ever proceed.

### Risk 4: Accessibility Regressions from Password Semantics
- **Description**: Applying `Semantics(password: true)` on text fields could cause screen readers on custom OEM Android skins to behave unpredictably.
- **Safeguard**:
  - Use Flutter's standard `Semantics` widget flags which translate directly to `AccessibilityNodeInfo.setPassword(true)`.
  - Verified across standard Android accessibility guidelines.

---

## 4. Residual Risk Assessment Post-Remediation

| Defect ID | Pre-Remediation Risk | Post-Remediation Risk | Residual Risk Status |
|---|---|---|---|
| `HAVEN-QA-001` | Low (Usability / Clipping) | Negligible | Closed permanently |
| `HAVEN-QA-002` | High (Security / SEC-001) | Negligible | Hardened by default; zero leakage |
| `HAVEN-QA-003` | High (Telemetry Blocked) | Low (Handled by Protocol) | Handled by Parent-Child Reconnect Flow |
| `HAVEN-QA-004` | Medium (False Telemetry) | Negligible | Corrected by Android Compat API |
| `HAVEN-QA-005` | High (Confusing UI / Duplication) | Negligible | Cleanly filtered by query |
| `HAVEN-QA-006` | Medium (Conflicting Status) | Negligible | Fully harmonized presentation |
