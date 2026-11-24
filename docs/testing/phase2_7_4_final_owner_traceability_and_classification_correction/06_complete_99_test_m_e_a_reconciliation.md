# HAVEN PARENT CONTROL — PHASE 2.7.4 DELIVERABLE 06
# AUDIT E & F: COMPLETE 99-TEST M/E/A MASTER RECONCILIATION

**Document ID:** `HAVEN-GOV-PHASE2-7-4-99-TEST-RECON`  
**Phase:** Phase 2.7.4 — Final Owner Decision Traceability & Test Classification Correction Audit  
**Audit Dimension:** Multi-Dimensional Dependency Reconciliation & Baseline Acceptance  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Verification  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Status:** ALL 99 TESTS REMAIN NOT TESTED  

---

## 1. Executive Summary & Purpose

This report provides the complete, authoritative, 99-test case reconciliation across the three orthogonal dependency dimensions:
1. **Database Migration Dependency (M-Class)**: Correcting historical M3 and M4 anomalies based on source evidence.
2. **Environment Readiness (E-Class)**: Disentangling isolated fixture testing (`E2`) from infrastructure provisioning (`E3`).
3. **Android Native Capability (A-Class)**: Preserving precise platform permission and Device Owner boundaries (`A0–A8`).

Every one of the 99 test cases is individually cataloged with its historical versus current classifications, source reference, and execution status (`NOT TESTED`).

---

## 2. Global Testing Baseline Verification (Audit F)

In accordance with Section 9 of the Phase 2.7.4 specification, the global testing baseline is verified:

| Governance Baseline Component | Expected Target | Audited Actual | Reconciled Status | Evidence Reference |
| :--- | :---: | :---: | :---: | :--- |
| **Unique Functionality IDs** | 92 | 92 | **MATCH (100.0%)** | `docs/testing/phase2_4_final_evidence_reconciliation/03_...md` |
| • Fully Implemented | 81 | 81 | **MATCH (100.0%)** | Source code verified |
| • Partially Implemented | 7 | 7 | **MATCH (100.0%)** | Documented in `03_complete_92_functionality_reconciliation.md` |
| • UI-Only | 2 | 2 | **MATCH (100.0%)** | Documented in `03_complete_92_functionality_reconciliation.md` |
| • Backend-Only | 2 | 2 | **MATCH (100.0%)** | Documented in `03_complete_92_functionality_reconciliation.md` |
| **Missing Capabilities (M01–M10)**| 10 | 10 | **MATCH (100.0%)** | Separately tracked; excluded from execution |
| **Total Unique Test Cases** | 99 | 99 | **MATCH (100.0%)** | Reconciled across 4 operational domains |
| • Original Baseline Test Cases | 41 | 41 | **MATCH (100.0%)** | Authored in `08_manual_test_case_master_list.md` |
| • Expansion Test Cases | 58 | 58 | **MATCH (100.0%)** | Authored in `05_additional_manual_test_cases.md` |
| **Safety Classifications** | 99 | 99 | **MATCH (100.0%)** | 45 + 17 + 8 + 9 + 6 + 14 = 99 |
| • Tier 1: SAFE | 45 | 45 | **MATCH** | Read-only UI and client tests |
| • Tier 2: SAFE_REVERSIBLE | 17 | 17 | **MATCH** | User settings and reversible policies |
| • Tier 3: REQUIRES_DISPOSABLE_ACCOUNT | 8 | 8 | **MATCH** | Account creation, export, and deletion |
| • Tier 4: REQUIRES_DISPOSABLE_DEVICE | 9 | 9 | **MATCH** | Device pairing, unlinking, hardware config |
| • Tier 5: REQUIRES_ISOLATED_BACKEND | 6 | 6 | **MATCH** | RLS, token replay, purges, sweeps |
| • Tier 6: SPECIALIST_TEST | 14 | 14 | **MATCH** | WebRTC, native daemons, Device Owner |
| **Technical Prerequisites** | 18 | 18 | **MATCH (100.0%)** | `PREREQ-01` through `PREREQ-18` |
| **Canonical Owner Decision Gates** | 7 | 7 | **MATCH (100.0%)** | `P25-OWNER-01` through `P25-OWNER-07` |
| **Phase 3 Test Execution Status** | NOT TESTED | NOT TESTED | **100% UNTESTED** | Exactly 0 tests executed |

---

## 3. Dimensional Reconciliation & Mathematical Proof

### 3.1 Database Migration Dependency (M-Class)
- **Historical (Phase 2.7.2):** M0: 26, M1: 61, M2: 1, M3: 4, M4: 7 (Total: 99).
- **Audit A Adjustments:** The 4 historical `M3` tests (`TC-SEC01`, `TC-SEC02`, `TC-EXP-17`, `TC-EXP-18`) do not require fresh migration replay; they execute on existing compatible schema with isolated fixtures (`M1`).
- **Audit B Adjustments:** 5 of the 7 historical `M4` tests (`TC-A08`, `TC-APP05`, `TC-APP07`, `TC-EXP-04`, `TC-FAM10`) do not perform destructive database operations; they execute on existing schema (`M1`). Only `TC-A09` (hard account delete) and `TC-EXP-47` (audit log purge) perform genuine destructive database purges under `AUD03`.
- **Current Evidence-Based Totals (Phase 2.7.4):**
  - **`M0` (No Database Dependency):** **26 tests** (26.3%)
  - **`M1` (Existing Compatible Schema):** **70 tests** (70.7%) [61 baseline + 4 from M3 + 5 from M4]
  - **`M2` (Static Migration Inspection):** **1 test** (1.0%) [`TC-EXP-48`]
  - **`M3` (Fresh Migration Replay Required):** **0 tests** (0.0%)
  - **`M4` (Destructive Database Operation):** **2 tests** (2.0%) [`TC-A09`, `TC-EXP-47`]
  - **Total:** **99 tests** (100.0%)

### 3.2 Environment Readiness (E-Class)
- **Historical (Phase 2.7.3):** E0: 18, E1: 30, E2: 30, E3: 3, E4: 8, E5: 10 (Total: 99).
- **Current Evidence-Based Adjustments:** `TC-SEC01` and `TC-SEC02` require isolated tenant fixtures (`E2`), not fresh infrastructure spin-up (`E3`). `TC-EXP-48` represents static review (`M2`), but requires `E3` if executed at runtime.
- **Current Evidence-Based Totals (Phase 2.7.4):**
  - **`E0` (No Backend Needed):** **18 tests** (18.2%)
  - **`E1` (Existing Compatible Backend):** **30 tests** (30.3%)
  - **`E2` (Isolated Tenant Fixture Required):** **32 tests** (32.3%) [30 baseline + 2 from E3]
  - **`E3` (Fresh Infrastructure Provisioning):** **1 test** (1.0%) [`TC-EXP-48`]
  - **`E4` (Specialist Hardware Required):** **8 tests** (8.1%)
  - **`E5` (Combined Environment Required):** **10 tests** (10.1%)
  - **Total:** **99 tests** (100.0%)

### 3.3 Android Capability Dependency (A-Class)
- **Authoritative Distribution (Unchanged & Verified):**
  - **`A0` (No Special Android Privilege):** **71 tests** (71.7%)
  - **`A1` (Ordinary Runtime Permissions):** **7 tests** (7.1%)
  - **`A2` (Usage Access AppOps):** **1 test** (1.0%) [`TC-EXP-28`]
  - **`A3` (Device Admin Active):** **2 tests** (2.0%) [`TC-SET05`, `TC-EXP-55`]
  - **`A4` (Device Owner Provisioned):** **1 test** (1.0%) [`TC-APP07`]
  - **`A5` (Accessibility Service):** **0 tests** (0.0% — Unavailable in source M08)
  - **`A6` (Notification Listener Service):** **0 tests** (0.0% — Unavailable in source M09)
  - **`A7` (Specialist Hardware / Multi-Device):** **1 test** (1.0%) [`TC-FAM01`]
  - **`A8` (Combined Android Capabilities):** **16 tests** (16.2%)
  - **Total:** **99 tests** (100.0%)

---

## 4. Master 99-Test Reconciliation Catalog

The table below catalogs all 99 unique test cases with their exact historical and current classifications across M, E, and A dimensions:

| Test ID | Test Title | Funcs | Batch | M Hist | M Curr | E Hist | E Curr | A Hist | A Curr | Source File Reference | Execution Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| **`TC-A10`** | Backend Configuration Screen | `A10` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/core/config/env.dart` | **`NOT TESTED`** |
| **`TC-A06`** | Role Selection Interface | `A06` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/auth/presentation/screens/role_selection_screen.dart` | **`NOT TESTED`** |
| **`TC-SYS01`** | Offline Mode Detection & Warning Banner | `SYS01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/app/app.dart` | **`NOT TESTED`** |
| **`TC-A01`** | Parent & Child Email Sign-In | `A01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/data/repositories/supabase_auth_repository.dart` | **`NOT TESTED`** |
| **`TC-A02`** | Account Registration Flow | `A02` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000100_functions.sql:10` | **`NOT TESTED`** |
| **`TC-A04`** | Cold App Launch Session Restoration | `A04` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/auth/controllers/auth_controller.dart` | **`NOT TESTED`** |
| **`TC-A05`** | Sign Out & Token Revocation | `A05` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/data/repositories/supabase_auth_repository.dart` | **`NOT TESTED`** |
| **`TC-A08`** | Account Data Export (GDPR) | `A08` | Batch 3 | **`M4`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/functions/account/index.ts` | **`NOT TESTED`** |
| **`TC-A09`** | Account Deletion with Confirmation | `A09` | Batch 3 | **`M4`** | **`M4`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/functions/account/deletion.ts:418` | **`NOT TESTED`** |
| **`TC-A11`** | Password Reveal & Masking Toggle | `A11` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/auth/presentation/screens/login_screen.dart` | **`NOT TESTED`** |
| **`TC-FAM08`** | Family Group Creation | `FAM08` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000100_functions.sql:65` | **`NOT TESTED`** |
| **`TC-FAM06`** | Child Linking Code & QR Generation | `FAM06` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/data/repositories/supabase_family_repository.dart` | **`NOT TESTED`** |
| **`TC-FAM01`** | Link Child via Camera QR Code Scanning | `FAM01` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A7`** | **`A7`** | `supabase/migrations/20260101000600_atomic_pairing_invite.sql` | **`NOT TESTED`** |
| **`TC-FAM02`** | Link Child via Manual 6-Digit Code Entry | `FAM02` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000600_atomic_pairing_invite.sql` | **`NOT TESTED`** |
| **`TC-FAM07`** | Child Device Hardware Registration | `FAM07` | Batch 4 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `supabase/functions/device-register/index.ts` | **`NOT TESTED`** |
| **`TC-FAM10`** | Unlink Child Account from Parent Dashboard | `FAM10` | Batch 4 | **`M4`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `supabase/migrations/20261030000200_phase1_authorization.sql` | **`NOT TESTED`** |
| **`TC-MON01`** | Parent Dashboard Summary Cards Rendering | `MON01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/parent_dashboard_screen.dart` | **`NOT TESTED`** |
| **`TC-MON03`** | Device Detail Technical Telemetry | `MON03` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/device_detail_screen.dart` | **`NOT TESTED`** |
| **`TC-USE01`** | Daily Screen Time 7-Day Usage Chart | `USE01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/widgets/usage_chart.dart` | **`NOT TESTED`** |
| **`TC-USE02`** | Per-Application Daily Usage Breakdown | `USE02` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/data/models/usage.dart` | **`NOT TESTED`** |
| **`TC-USE05`** | Daily Screen Time Quota Limit Setting | `USE05` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000000_core.sql:185` | **`NOT TESTED`** |
| **`TC-APP01`** | Blocking Individual Target Application | `APP01` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000000_core.sql:180` | **`NOT TESTED`** |
| **`TC-APP02`** | Whitelist Mode (Block All Except Allowed) | `APP02` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000000_core.sql:182` | **`NOT TESTED`** |
| **`TC-APP04`** | Per-App Allowed Schedule Windows | `APP04` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000000_core.sql:188` | **`NOT TESTED`** |
| **`TC-LOC01`** | Child Real-Time Map Location Display | `LOC01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/location_map_screen.dart` | **`NOT TESTED`** |
| **`TC-LOC05`** | Safe Zone Geofence Creation | `LOC05` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql` | **`NOT TESTED`** |
| **`TC-LOC10`** | Safety Alerts Inbox & Acknowledgment | `LOC10` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/alerts_screen.dart` | **`NOT TESTED`** |
| **`TC-REM01`** | Initiating Remote Assistance Call | `REM01` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/migrations/20261028000100_remote_session_concurrency.sql` | **`NOT TESTED`** |
| **`TC-AUD01`** | Administrative Audit Log Viewer | `AUD01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/audit_log_screen.dart` | **`NOT TESTED`** |
| **`TC-CHD01`** | Child Home Protection Status Overview | `CHD01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/child_home_screen.dart` | **`NOT TESTED`** |
| **`TC-CHD02`** | Child Rules & Policy Oversight View | `CHD02` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/child_rules_screen.dart` | **`NOT TESTED`** |
| **`TC-CHD03`** | Child Requests Inbox & Notifications Badge | `CHD03` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/widgets/child_request_badge.dart` | **`NOT TESTED`** |
| **`TC-CHD05`** | Camera & Microphone Hardware Self-Test | `CHD05` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A1`** | **`A1`** | `lib/features/child/presentation/screens/hardware_test_screen.dart` | **`NOT TESTED`** |
| **`TC-CHD09`** | Emergency Parent Quick-Call Action | `CHD09` | Batch 2 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A1`** | **`A1`** | `supabase/migrations/20260101000500_child_contact_ids.sql` | **`NOT TESTED`** |
| **`TC-CHD04`** | Guardian Service Persistent Notification | `CHD04` | Batch 4 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A8`** | **`A8`** | `android/app/src/main/kotlin/.../GuardianService.kt` | **`NOT TESTED`** |
| **`TC-SET05`** | Android Device Administrator Activation | `SET05` | Batch 4 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A3`** | **`A3`** | `android/app/src/main/kotlin/.../NativeBridge.kt:398` | **`NOT TESTED`** |
| **`TC-APP07`** | Native App Suspension Under Device Owner | `APP07` | Batch 6 | **`M4`** | **`M1`** | **`E5`** | **`E5`** | **`A4`** | **`A4`** | `android/app/src/main/kotlin/.../PolicyApplier.kt:351` | **`NOT TESTED`** |
| **`TC-MON04`** | Background Heartbeat Presence Transmission | `MON04` | Batch 2 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/functions/device-telemetry/index.ts` | **`NOT TESTED`** |
| **`TC-APP05`** | Policy Command Delivery & ACK Loop | `APP05` | Batch 5 | **`M4`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/functions/device-command/index.ts` | **`NOT TESTED`** |
| **`TC-SEC01`** | Cross-Family Unauthorized Access Boundary | `SEC01` | Batch 5 | **`M3`** | **`M1`** | **`E3`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000200_rls.sql` | **`NOT TESTED`** |
| **`TC-SEC02`** | Replay of Staged Credential Redemption | `SEC02` | Batch 5 | **`M3`** | **`M1`** | **`E3`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000600_atomic_pairing_invite.sql` | **`NOT TESTED`** |
| **`TC-EXP-01`** | Role Assignment Persistence & Immutability | `A06` | Batch 2 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/auth/controllers/role_controller.dart` | **`NOT TESTED`** |
| **`TC-EXP-02`** | Authentication Negative Paths & Lockout | `A01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/auth/presentation/screens/login_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-03`** | Registration Form Validation & Duplicate Email | `A02` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/auth/presentation/screens/register_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-04`** | GDPR Data Export Payload Schema Validation | `A08` | Batch 5 | **`M4`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/functions/account/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-05`** | Child Device Hardware Metadata Capture | `FAM07` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/data/models/device.dart` | **`NOT TESTED`** |
| **`TC-EXP-06`** | Whitelist Mode Emergency App Bypass | `APP02` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/data/models/policy.dart` | **`NOT TESTED`** |
| **`TC-EXP-07`** | Child Remote Assistance Incoming Call Dialog | `REM01` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `lib/features/child/presentation/screens/incoming_call_dialog.dart` | **`NOT TESTED`** |
| **`TC-EXP-08`** | WebRTC Live Audio/Video Bidirectional Stream | `REM01` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `lib/data/services/webrtc_service.dart` | **`NOT TESTED`** |
| **`TC-EXP-09`** | Email Verification Resend Throttling | `A02` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/auth/presentation/screens/verify_email_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-10`** | Account Profile Display & Name Update | `A07` | Batch 2 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/profile_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-11`** | Registration & Login Real-Time Validation | `A01, A02` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/core/utils/validators.dart` | **`NOT TESTED`** |
| **`TC-EXP-12`** | Outgoing Pairing Requests List Rendering | `FAM06` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/pairing_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-13`** | Cancel Outgoing Pairing Request | `FAM06` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/data/repositories/supabase_family_repository.dart` | **`NOT TESTED`** |
| **`TC-EXP-14`** | Child Pairing Consent and Cancellation | `FAM01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/enrollment_consent_dialog.dart` | **`NOT TESTED`** |
| **`TC-EXP-15`** | Family Roster and Role Hierarchy View | `FAM08` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/family_roster_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-16`** | Child App Self-Unlink Guard and PIN Gate | `FAM11` | Batch 1 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/unlink_guard_dialog.dart` | **`NOT TESTED`** |
| **`TC-EXP-17`** | Parent Device Revocation & Child Invalidate | `FAM10` | Batch 4 | **`M3`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `supabase/functions/device-command/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-18`** | Child Record Removal & Orphan Cleanup | `FAM10` | Batch 4 | **`M3`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20260101000000_core.sql:75` | **`NOT TESTED`** |
| **`TC-EXP-19`** | Family Settings Update Backend API Verify | `FAM08` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/functions/family-admin/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-20`** | Connected Devices List and Status Cards | `FAM07` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/devices_list_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-21`** | Child Permission Diagnostics Remote View | `SET05` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/device_diagnostics_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-22`** | Command Delivery and ACK History Log | `APP05` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/command_history_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-23`** | Installed Apps Snapshot Upload Verify | `APP01` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `supabase/migrations/20260101000100_functions.sql:180` | **`NOT TESTED`** |
| **`TC-EXP-24`** | Parent Dashboard Pull-to-Refresh | `MON01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/parent_dashboard_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-25`** | Policy Sync Health Badge Transitions | `APP05` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/widgets/policy_sync_badge.dart` | **`NOT TESTED`** |
| **`TC-EXP-26`** | Device Filter Toggle: Active vs Revoked | `FAM07` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/devices_list_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-27`** | Child Usage Access Guidance Banner | `USE01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/widgets/usage_permission_banner.dart` | **`NOT TESTED`** |
| **`TC-EXP-28`** | Native Usage Stats Collection & Upload | `USE01` | Batch 4 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A2`** | **`A2`** | `supabase/migrations/20260101000100_functions.sql:220` | **`NOT TESTED`** |
| **`TC-EXP-29`** | Bedtime Schedule Setup & Boundary Enforce | `APP04` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/data/models/policy.dart` | **`NOT TESTED`** |
| **`TC-EXP-30`** | Child Home Remaining Time Live Calculation | `USE05` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/child_home_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-31`** | Daily Quota Expiry Full-Screen Lock Overlay | `USE05` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/screens/lock_overlay_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-32`** | App Whitelist Selection & Category Filter | `APP02` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/app_whitelist_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-33`** | Manual Policy Force-Sync Command | `APP05` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/functions/device-command/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-34`** | App Restrictions Search and Package Filter | `APP01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/app_restrictions_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-35`** | 24-Hour Location History Route Playback | `LOC01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/location_history_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-36`** | Child Location Sharing Privacy Toggle | `LOC01` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A1`** | **`A1`** | `lib/features/child/presentation/screens/privacy_settings_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-37`** | Continuous Background Location Daemon | `LOC01` | Batch 4 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `android/app/src/main/kotlin/.../LocationTrackingService.kt` | **`NOT TESTED`** |
| **`TC-EXP-38`** | Geofence Exit Telemetry Alert Trigger | `LOC10` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/functions/device-telemetry/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-39`** | Low-Battery Telemetry Alert Dispatch | `MON01` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/functions/device-telemetry/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-40`** | Offline Heartbeat Timeout Alert | `MON04` | Batch 6 | **`M1`** | **`M1`** | **`E5`** | **`E5`** | **`A8`** | **`A8`** | `supabase/functions/cron/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-41`** | Child Permission Revocation Tamper Alert | `SET05` | Batch 2 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `supabase/functions/device-telemetry/index.ts` | **`NOT TESTED`** |
| **`TC-EXP-42`** | Safe Zone Radius Live Preview Slider | `LOC05` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/safe_zone_dialog.dart` | **`NOT TESTED`** |
| **`TC-EXP-43`** | Remote Assistance Call History Log | `REM01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/call_history_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-44`** | Call Hangup & Camera/Mic Resource Release | `REM01` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A1`** | **`A1`** | `lib/data/services/webrtc_service.dart` | **`NOT TESTED`** |
| **`TC-EXP-45`** | In-Call Media Stream Controls: Mute, Flip | `REM01` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A1`** | **`A1`** | `lib/features/parent/presentation/screens/remote_call_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-46`** | Audit Retention Policy Config Dialog | `AUD01` | Batch 2 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/retention_settings_dialog.dart` | **`NOT TESTED`** |
| **`TC-EXP-47`** | Manual Audit Log Purge with Confirmation | `AUD01` | Batch 5 | **`M4`** | **`M4`** | **`E2`** | **`E2`** | **`A0`** | **`A0`** | `supabase/migrations/20261030000300_retention_sweep.sql:120` | **`NOT TESTED`** |
| **`TC-EXP-48`** | PostgreSQL Audit Retention Sweep Function | `AUD01` | Batch 5 | **`M2`** | **`M2`** | **`E3`** | **`E3`** | **`A0`** | **`A0`** | `supabase/migrations/20261030000300_retention_sweep.sql` | **`NOT TESTED`** |
| **`TC-EXP-49`** | Local Notification Preferences Toggle | `SYS01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/data/services/preferences_service.dart` | **`NOT TESTED`** |
| **`TC-EXP-50`** | Location Reminder Frequency Preference | `LOC01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/data/services/preferences_service.dart` | **`NOT TESTED`** |
| **`TC-EXP-51`** | App Version and Build Information Display | `SYS01` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/parent/presentation/screens/about_screen.dart` | **`NOT TESTED`** |
| **`TC-EXP-52`** | Runtime Permission Launcher Bridge | `SET05` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A1`** | **`A1`** | `android/app/src/main/kotlin/.../NativeBridge.kt:455` | **`NOT TESTED`** |
| **`TC-EXP-53`** | Background Location Launcher Bridge | `LOC01` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A1`** | **`A1`** | `android/app/src/main/kotlin/.../NativeBridge.kt:424` | **`NOT TESTED`** |
| **`TC-EXP-54`** | Native Permission Diagnostic Status Tile | `SET05` | Batch 1 | **`M0`** | **`M0`** | **`E0`** | **`E0`** | **`A0`** | **`A0`** | `lib/features/child/presentation/widgets/diagnostic_tile.dart` | **`NOT TESTED`** |
| **`TC-EXP-55`** | Device Admin Revocation Alert UI | `SET05` | Batch 6 | **`M0`** | **`M0`** | **`E4`** | **`E4`** | **`A3`** | **`A3`** | `android/app/src/main/kotlin/.../ParentControlDeviceAdminReceiver.kt` | **`NOT TESTED`** |
| **`TC-EXP-56`** | Child Background Sync Retry & Backoff | `APP05` | Batch 6 | **`M1`** | **`M1`** | **`E2`** | **`E2`** | **`A8`** | **`A8`** | `android/app/src/main/kotlin/.../GuardianService.kt` | **`NOT TESTED`** |
| **`TC-EXP-57`** | Child Rules Real-Time Manual Refresh | `CHD02` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/child/controllers/child_rules_controller.dart` | **`NOT TESTED`** |
| **`TC-EXP-58`** | Dashboard Periodic Polling Fallback | `MON01` | Batch 1 | **`M1`** | **`M1`** | **`E1`** | **`E1`** | **`A0`** | **`A0`** | `lib/features/parent/controllers/parent_dashboard_controller.dart` | **`NOT TESTED`** |
---

## 5. Master Traceability & Governance Guarantees

1. **Zero Disappearing or Duplicate Tests:**
   - Every one of the 99 test cases from `08_manual_test_case_master_list.md` and `05_additional_manual_test_cases.md` is present.
   - Exact count: **99 unique test cases**.
2. **Deterministic Arithmetic:**
   - Database Dimension: 26 (M0) + 70 (M1) + 1 (M2) + 0 (M3) + 2 (M4) = **99 tests**.
   - Environment Dimension: 18 (E0) + 30 (E1) + 32 (E2) + 1 (E3) + 8 (E4) + 10 (E5) = **99 tests**.
   - Android Dimension: 71 (A0) + 7 (A1) + 1 (A2) + 2 (A3) + 1 (A4) + 0 (A5) + 0 (A6) + 1 (A7) + 16 (A8) = **99 tests**.
3. **Execution Prohibition:**
   - Exactly **0 of the 99 test cases** have been executed.
   - All 99 test cases remain formally marked **`NOT TESTED`**.
