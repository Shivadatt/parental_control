# 07 — Cross-Defect Dependency Matrix

**Document ID:** HAVEN-REM-007  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Overview & Objectives

Remediating six defects across Flutter Dart UI, shared core widgets, native Android Kotlin bridges, Supabase Edge Functions, and PostgreSQL database migrations creates potential cross-system dependencies.

This document analyzes:
1. Direct and indirect couplings between the six defects.
2. Shared components and files touched by multiple fixes.
3. Potential merge conflicts and state interference.
4. Independent testability and deployment decoupling.

---

## 2. Cross-Defect Dependency Matrix

| Defect ID | Title | Depends On | Depended On By | Shared Components / Files | Coupling Level |
|---|---|---|---|---|---|
| **HAVEN-QA-001** | Role Selection Button Truncation | None | None | `AppButton`, `RoleSelectionPage` | **None (Isolated UI)** |
| **HAVEN-QA-002** | Password Input Hardening (`SEC-001`) | None | None | `AppTextField`, `LoginPage`, `RegisterPage` | **Low (Core Widget)** |
| **HAVEN-QA-003** | Device Re-credentialing (`DEF-601`) | `HAVEN-QA-005` (logical) | None | `devices` table, `SecureStore.kt`, `GuardianService.kt`, `device-telemetry` | **High (Multi-Tier)** |
| **HAVEN-QA-004** | Notification Permission Detection (`DEF-604`) | None | `HAVEN-QA-003` (telemetry payload) | `NativePermissions.kt`, `GuardianService.kt` | **Medium (Native)** |
| **HAVEN-QA-005** | Revoked Devices Filter (`DEF-602`) | None | `HAVEN-QA-003`, `HAVEN-QA-006` | `SupabaseDeviceRepository`, `devices` table, `DashboardController`, `DevicesController` | **Medium (Repository)** |
| **HAVEN-QA-006** | Policy Version Consistency (`DEF-603`) | `HAVEN-QA-005` (device query) | None | `device_presentation.dart`, `DashboardController`, `DevicesController` | **Medium (Presentation)** |

---

## 3. Detailed Component Interaction Analysis

### 3.1 Interaction: HAVEN-QA-003 (Re-credentialing) and HAVEN-QA-005 (Revoked Devices)
- **Nature of Interaction**: Database state management on `devices` table.
- **Analysis**:
  - In `HAVEN-QA-005`, the repository query is updated to filter out `status = 'revoked'`.
  - In `HAVEN-QA-003`, when a device is re-credentialed, it updates the **same existing row** (`devices.id`) with a new `secret_hash`, leaving `status = 'active'`.
  - Conversely, if a parent explicitly revokes a device, `devices.status` becomes `'revoked'`.
- **Conflict Assessment**: **No conflict**. Filtering out revoked devices in `HAVEN-QA-005` ensures that after re-credentialing, the active device continues to be displayed normally, while any prior historically revoked rows remain suppressed.
- **Sequencing Requirement**: Deploy `HAVEN-QA-005` before or concurrently with `HAVEN-QA-003`.

### 3.2 Interaction: HAVEN-QA-004 (Notification Detection) and HAVEN-QA-003 (Telemetry)
- **Nature of Interaction**: Telemetry payload structure.
- **Analysis**:
  - `NativePermissions.hasNotifications()` is called by `GuardianService.kt` during every heartbeat cycle to populate `capabilities.notifications_granted`.
  - When `HAVEN-QA-003` restores successful heartbeat uploads, the heartbeat payload will transmit the corrected notification status produced by `HAVEN-QA-004`.
- **Conflict Assessment**: **Synergistic**. Neither defect alters the JSON wire schema. `HAVEN-QA-004` corrects the boolean value, while `HAVEN-QA-003` ensures the packet reaches the database.

### 3.3 Interaction: HAVEN-QA-005 (Device Query) and HAVEN-QA-006 (Policy Version)
- **Nature of Interaction**: Shared controllers (`DashboardController` and `DevicesController`).
- **Analysis**:
  - `HAVEN-QA-005` changes the list of devices passed to `DashboardController` and `DevicesController` by excluding revoked rows.
  - `HAVEN-QA-006` changes the policy string projection for each device in those controllers.
- **Conflict Assessment**: **Direct code neighbor**. Both changes touch `lib/features/dashboard/dashboard_controller.dart` and `lib/features/devices/devices_controller.dart`.
- **Mitigation**: Changes should be implemented in coordinated commits or within the same branch to prevent merge conflicts.

### 3.4 Interaction: Shared Core Widgets (`AppButton` and `AppTextField`)
- **HAVEN-QA-001** touches `AppButton` (or its usage in `RoleSelectionPage`).
- **HAVEN-QA-002** touches `AppTextField` (used in `LoginPage`, `RegisterPage`, and role lock PIN).
- **Conflict Assessment**: **Zero overlap**. `AppButton` and `AppTextField` are independent components in `lib/core/widgets/`.

---

## 4. Testability & Decoupling Strategy

| Defect ID | Can Be Tested In Complete Isolation? | Mock Dependencies Required | Deployment Independence |
|---|---|---|---|
| `HAVEN-QA-001` | **Yes (100% Isolated)** | None (Pure Flutter widget test) | Independent client release |
| `HAVEN-QA-002` | **Yes (100% Isolated)** | None (Flutter widget / semantics test) | Independent client release |
| `HAVEN-QA-004` | **Yes (100% Isolated)** | Android Context / NotificationManagerCompat | Independent client release |
| `HAVEN-QA-005` | **Yes** | Mock Supabase PostgREST client | Independent client release |
| `HAVEN-QA-006` | **Yes** | Mock Device and Policy models | Independent client release |
| `HAVEN-QA-003` | **No (Requires Backend + Client)** | Requires DB migration & Edge Function deploy | Coupled release (Migration → Edge → Client) |

---

## 5. Architectural Isolation Boundary Summary

To prevent cross-defect contamination:
1. **Client UI & Core Tier (`001`, `002`)**: Self-contained in Dart. No backend, native, or database dependencies. Can be implemented, tested, and shipped immediately upon approval.
2. **Native Android Platform Tier (`004`)**: Isolated to `NativePermissions.kt`. Can be validated via unit tests independently of Flutter.
3. **Parent Presentation & Repository Tier (`005`, `006`)**: Modifies query filters and pure presentation helpers. Does not alter database schemas.
4. **Distributed Re-credentialing Tier (`003`)**: Isolated behind a dedicated database migration (`20261124000100_device_recredentialing.sql`) and dedicated RPC (`rotate_device_secret`). Does not mutate existing core tables or affect other flows.
