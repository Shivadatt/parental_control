# 04 — Cross-Defect Dependency & Shared Component Review

**Document ID:** HAVEN-REV-004  
**Phase:** Phase 1.1 — Remediation Plan Independent Review (Strictly Read-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE INDEPENDENT TECHNICAL REVIEW  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Objectives

When remediating multiple defects across Flutter client widgets, native Android services, repository contracts, and backend Edge Functions, changes to shared components can introduce unintended regressions.

This document reviews the cross-defect dependencies documented in `07_cross_defect_dependency_matrix.md`, identifies unacknowledged couplings, evaluates shared component blast radius, and provides an authoritative, corrected dependency matrix.

---

## 2. Shared Component Blast Radius Analysis

### 2.1 Shared Component 1: `AppButton` (`lib/core/widgets/app_button.dart`)
- **Planned Usage**: Proposed to be modified for `HAVEN-QA-001` by adding `FittedBox(fit: BoxFit.scaleDown)`.
- **Actual Codebase Footprint**:
  - `AppButton` is referenced in **88 distinct locations across 24 files**:
    - Authentication: `login_page.dart`, `register_page.dart`, `verify_email_page.dart`.
    - Family & Onboarding: `role_selection_page.dart`, `family_page.dart`, `family_setup_page.dart`.
    - Child Shell: `child_enrollment_page.dart`, `child_requests_page.dart`, `child_session_page.dart`, `child_home_tab.dart`, `child_settings_tab.dart`.
    - Remote Assistance: `remote_assistance_page.dart`, `remote_session_page.dart`.
    - Device Management: `device_detail_page.dart`, `pairing_redeem_page.dart`.
    - Restrictions & Rules: `app_restrictions_page.dart`, `screen_time_page.dart`, `safe_zones_page.dart`.
- **Review Finding (REV-004)**: Modifying `AppButton` to resolve a layout defect that occurs only on `RoleSelectionPage` represents an **unacceptably wide blast radius**. Any change to `AppButton` affects primary call-to-action buttons across every core user journey.
- **Architectural Correction**: `AppButton` must remain untouched. The layout constraint must be resolved within `RoleSelectionPage` itself.

### 2.2 Shared Component 2: `AppTextField` (`lib/core/widgets/app_text_field.dart`)
- **Planned Usage**: Modified for `HAVEN-QA-002` (`SEC-001`) to enforce password security.
- **Actual Codebase Footprint**:
  - Referenced in `login_page.dart`, `register_page.dart`, and `role_selection_page.dart` (admin PIN lock).
  - Also used for non-password fields: Email input, Display name, Family name, Device name, Safe zone name, and search fields.
- **Review Finding**: Unlike `AppButton`, `AppTextField` is the appropriate boundary for input hardening because password security is an intrinsic property of credential inputs. However, decoupling the security flags from `obscureText` is required to prevent the eyeball visibility toggle leak (REV-003).

### 2.3 Shared Component 3: `SupabaseDeviceRepository` & `repository_contracts.dart`
- **Planned Usage**: Modified for `HAVEN-QA-005` to filter revoked devices.
- **Actual Codebase Footprint**:
  - `fetchDevices(familyId)` is consumed directly by both `DashboardController` (`lib/features/dashboard/dashboard_controller.dart:67`) and `DevicesController` (`lib/features/devices/devices_controller.dart:61`).
- **Review Finding**: `DashboardController` and `DevicesController` both depend on the list returned by `fetchDevices()`. Ensuring that `fetchDevices()` filters `.eq('status', 'active')` cleanly fixes both screens in a single atomic change, eliminating revoked devices without controller-level filtering duplication.

### 2.4 Shared Component 4: `device_presentation.dart`
- **Planned Usage**: Modified for `HAVEN-QA-006` to harmonize policy version display.
- **Actual Codebase Footprint**:
  - `device_presentation.dart` provides pure formatting functions (`presenceChip`, `presenceTone`, `enforcementModeLabel`, `policySummary`).
  - It is imported by `DashboardController`, `DevicesController`, and `DeviceDetailPage`.
- **Review Finding**: Consolidating all policy string formatting into `device_presentation.dart` is architecturally sound and adheres to the existing presentation design principles.

---

## 3. Inter-Defect Coupling Analysis

### 3.1 Interaction: HAVEN-QA-003 (Re-credentialing) and HAVEN-QA-005 (Device Filtering)
- **Coupling Type**: Database Lifecycle State Coupling.
- **Review Finding**:
  - In `HAVEN-QA-003`, when a child device re-credentiales, it updates the existing row (`devices.id`) where `status = 'active'`.
  - In `HAVEN-QA-005`, the repository filters to return only active devices.
  - If a device was previously revoked, the unique index `devices_one_active_per_child` ensures that the revoked row and the active row cannot conflict on active status.
  - **Verdict**: Fully compatible. Filtering `status = 'active'` ensures the active re-credentialed device is displayed, while the revoked historical row is suppressed.

### 3.2 Interaction: HAVEN-QA-003 (Telemetry) and HAVEN-QA-004 (Notification Detection)
- **Coupling Type**: Wire Protocol Payload Coupling.
- **Review Finding**:
  - In `GuardianService.kt:285`, the telemetry heartbeat gathers native permissions via `NativePermissions.hasNotifications(context)` and serializes it into `capabilities.notifications_granted`.
  - `HAVEN-QA-004` corrects the boolean calculation in `NativePermissions.kt`.
  - `HAVEN-QA-003` restores the device's ability to successfully upload the heartbeat to `/device-telemetry`.
  - **Verdict**: Synergistic. Neither defect alters the JSON wire schema.

### 3.3 Interaction: HAVEN-QA-005 (Device Query) and HAVEN-QA-006 (Policy Presentation)
- **Coupling Type**: Controller Consumer Coupling.
- **Review Finding**:
  - Both `DashboardController` and `DevicesController` iterate over the devices returned by `fetchDevices()` and format policy labels using `policySummary()`.
  - Modifying `fetchDevices()` to filter active devices (`005`) reduces the list size, while updating `policySummary()` (`006`) changes the rendered text on the remaining cards.
  - **Verdict**: No conflict, but both files should be updated within the same commit or wave to avoid intermediate inconsistent states.

---

## 4. Corrected Cross-Defect Dependency Matrix

The following matrix represents the authoritative coupling and dependency graph verified by this review:

| Defect ID | Title | True Pre-requisites | Downstream Impacts | Safe Implementation Wave | Independent Testability |
|---|---|---|---|---|---|
| **HAVEN-QA-001** | Role Selection Button Layout | None | `RoleSelectionPage` only | **Wave 1** | **100% Isolated** (Widget test) |
| **HAVEN-QA-002** | Password Security (`SEC-001`) | None | `LoginPage`, `RegisterPage` | **Wave 1** | **100% Isolated** (Widget test) |
| **HAVEN-QA-004** | Notification Permission Detection | None | `GuardianService.kt` heartbeat payload | **Wave 1** | **100% Isolated** (Native JUnit) |
| **HAVEN-QA-005** | Revoked Devices Filter | None | `DashboardController`, `DevicesController` | **Wave 2** | **High** (Repository unit test) |
| **HAVEN-QA-006** | Policy Version Consistency | `HAVEN-QA-005` (recommended) | `device_presentation.dart` | **Wave 2** | **High** (Presentation unit test) |
| **HAVEN-QA-003** | Device Re-credentialing Protocol | `HAVEN-QA-005` (logical) | KeyStore, RPC, Edge Functions, Telemetry | **Wave 3 (Blocked)** | **Requires Multi-Tier Environment** |

---

## 5. Architectural Recommendations for Decoupling

1. **Strictly Quarantine Wave 3**: Wave 3 touches the database schema, RPCs, Edge Functions, and native KeyStore encryption. It must NOT be bundled into a single pull request with Wave 1 and Wave 2 client changes.
2. **Bundle Wave 2 Changes Together**: Changes to `SupabaseDeviceRepository` (`005`) and `device_presentation.dart` (`006`) should be delivered together in a single Wave 2 pull request to present a completely coherent Parent Mode device management experience.
3. **Keep Wave 1 Changes Atomic**: Each fix in Wave 1 (`001`, `002`, `004`) modifies distinct, non-overlapping files and can be reviewed, verified, and merged independently.
