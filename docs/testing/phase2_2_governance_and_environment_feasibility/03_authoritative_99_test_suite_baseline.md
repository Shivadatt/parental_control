# 03 — Authoritative 99-Test Suite Baseline

**Document ID:** `HAVEN-GOV-003`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Master Test Suite Scope:** Complete, Reconciled Inventory of All 99 Unique Test Cases  
**Audit Standard:** Immutable Sizing & Traceability Standard  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Master Suite Identity & Integer Proof

Following independent verification in Phase 2.1 (`HAVEN-VER-002`), the master manual testing suite for HAVEN Parent Control is formally and definitively established as **exactly 99 Unique Test Cases**:

$$\text{Total Master Suite} = 41 \text{ Baseline Test Cases} + 58 \text{ Expansion Test Cases} = \mathbf{99 \text{ Unique Test Cases}}$$

- **Zero Overlapping IDs**: Baseline suite uses functional prefixes (`TC-A*`, `TC-FAM*`, etc.); expansion suite uses sequential numerical identifiers (`TC-EXP-01` through `TC-EXP-58`).
- **Zero Duplicate IDs**: All 99 test cases possess globally unique identifiers.
- **Zero Phantom IDs**: All 99 test cases have verified, full-schema specifications in the repository.
- **Zero Unmapped Test Cases**: Every single test case maps directly to at least one of the 92 inventoried functionalities (`A01`–`SYS02`) or core multi-tenant security boundaries.

---

## 2. Complete 99-Test Master Baseline Catalog

| Test ID | Test Name | Origin Suite | Functionality ID(s) | Target Role | Safety Classification | Priority | Status |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **`TC-A10`** | Backend Configuration Screen | Baseline | `A10` | Shared | `SAFE` | P2 | `NOT TESTED` |
| **`TC-A06`** | Role Selection Screen Options | Baseline | `A06` | Shared | `REQUIRES_DISPOSABLE_ACCOUNT` | P1 | `NOT TESTED` |
| **`TC-SYS01`**| Offline Mode Detection Banner | Baseline | `SYS01` | Shared | `SAFE` | P1 | `NOT TESTED` |
| **`TC-A01`** | Parent & Child Email Sign-In | Baseline | `A01` | Shared | `SAFE` | P0 | `NOT TESTED` |
| **`TC-A02`** | Account Registration Flow | Baseline | `A02` | Shared | `REQUIRES_DISPOSABLE_ACCOUNT` | P0 | `NOT TESTED` |
| **`TC-A04`** | Cold App Launch Session Restoration | Baseline | `A04` | Shared | `SAFE` | P1 | `NOT TESTED` |
| **`TC-A05`** | Sign Out & Token Revocation | Baseline | `A05` | Shared | `SAFE` | P0 | `NOT TESTED` |
| **`TC-A08`** | Account Data Export (GDPR) | Baseline | `A08` | Parent | `REQUIRES_DISPOSABLE_ACCOUNT` | P2 | `NOT TESTED` |
| **`TC-A09`** | Account Deletion with Cascade | Baseline | `A09` | Shared | `REQUIRES_DISPOSABLE_ACCOUNT` | P0 | `NOT TESTED` |
| **`TC-A11`** | Password Reveal & Masking Toggle | Baseline | `A11` | Shared | `SAFE` | P2 | `NOT TESTED` |
| **`TC-FAM08`**| Family Group Creation | Baseline | `FAM08` | Parent | `REQUIRES_DISPOSABLE_ACCOUNT` | P0 | `NOT TESTED` |
| **`TC-FAM06`**| Pairing Code & QR Generation | Baseline | `FAM06` | Parent | `SAFE` | P0 | `NOT TESTED` |
| **`TC-FAM01`**| Link Child via Camera QR Scan | Baseline | `FAM01` | Interconnected | `REQUIRES_DISPOSABLE_DEVICE` | P0 | `NOT TESTED` |
| **`TC-FAM02`**| Link Child via Manual Code Entry | Baseline | `FAM02` | Interconnected | `REQUIRES_DISPOSABLE_DEVICE` | P0 | `NOT TESTED` |
| **`TC-FAM07`**| Child Hardware Registration | Baseline | `FAM07` | Child | `REQUIRES_DISPOSABLE_DEVICE` | P0 | `NOT TESTED` |
| **`TC-FAM10`**| Unlink Child Account from Dashboard | Baseline | `FAM10` | Parent | `REQUIRES_DISPOSABLE_DEVICE` | P0 | `NOT TESTED` |
| **`TC-MON01`**| Parent Dashboard Summary Cards | Baseline | `MON01` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-MON03`**| Device Detail Technical Telemetry | Baseline | `MON03` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-MON04`**| Background Heartbeat Transmission | Baseline | `MON04` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-USE01`**| Daily Screen Time 7-Day Chart | Baseline | `USE01` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-USE02`**| Per-Application Usage Breakdown | Baseline | `USE02` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-USE05`**| Daily Screen Time Quota Limit | Baseline | `USE05` | Parent | `SAFE_REVERSIBLE` | P0 | `NOT TESTED` |
| **`TC-APP01`**| Blocking Individual Target App | Baseline | `APP01` | Parent | `SAFE_REVERSIBLE` | P0 | `NOT TESTED` |
| **`TC-APP02`**| Whitelist Mode | Baseline | `APP02` | Parent | `SAFE_REVERSIBLE` | P0 | `NOT TESTED` |
| **`TC-APP04`**| Per-App Schedule Windows | Baseline | `APP04` | Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-APP05`**| Policy Delivery & ACK Loop | Baseline | `APP05` | Interconnected | `SAFE` | P1 | `NOT TESTED` |
| **`TC-APP07`**| Native OS App Suspension Under DO | Baseline | `APP07` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-LOC01`**| Child Real-Time Map Location | Baseline | `LOC01` | Parent | `SAFE` | P0 | `NOT TESTED` |
| **`TC-LOC05`**| Safe Zone Geofence Creation | Baseline | `LOC05` | Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-LOC10`**| Safety Alerts Inbox & Acknowledgment| Baseline | `LOC10` | Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-REM01`**| Initiating Remote Assistance Call | Baseline | `REM01` | Parent | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-AUD01`**| Administrative Audit Log Viewer | Baseline | `AUD01` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-CHD01`**| Child Home Protection Shield | Baseline | `CHD01` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-CHD02`**| Child Rules Oversight View | Baseline | `CHD02` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-CHD03`**| Child Requests Inbox & Modal | Baseline | `CHD03` | Child | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-CHD05`**| Hardware Self-Test (Camera/Mic) | Baseline | `CHD05` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-CHD09`**| Emergency Parent Quick-Call Action | Baseline | `CHD09` | Child | `SAFE` | P0 | `NOT TESTED` |
| **`TC-CHD04`**| Guardian Foreground Persistent Notif| Baseline | `CHD04` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-SET05`**| Android Device Admin Activation | Baseline | `SET05` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-SEC01`**| Cross-Family RLS Data Boundary | Baseline | `A01` / RLS | Security | `REQUIRES_ISOLATED_BACKEND` | P0 | `NOT TESTED` |
| **`TC-SEC02`**| Staged Credential Replay Attack | Baseline | `FAM13` / Wave 3 | Security | `REQUIRES_ISOLATED_BACKEND` | P0 | `NOT TESTED` |
| **`TC-EXP-01`**| Role Assignment Immutability | Expansion | `A06` | Shared | `REQUIRES_DISPOSABLE_ACCOUNT` | P0 | `NOT TESTED` |
| **`TC-EXP-02`**| Login Invalid Password & Rate Limit | Expansion | `A01` | Shared | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-03`**| Registration Duplicate Email Reject | Expansion | `A02`, `A12` | Shared | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-04`**| Account Data Export Schema Validate | Expansion | `A08` | Parent | `REQUIRES_DISPOSABLE_ACCOUNT` | P2 | `NOT TESTED` |
| **`TC-EXP-05`**| Child Hardware Metadata Registration| Expansion | `FAM07` | Interconnected | `REQUIRES_DISPOSABLE_DEVICE` | P1 | `NOT TESTED` |
| **`TC-EXP-06`**| Whitelist Mode Emergency Phone Bypass| Expansion | `APP02`, `CHD09` | Child | `SAFE_REVERSIBLE` | P0 | `NOT TESTED` |
| **`TC-EXP-07`**| Child Incoming Call Dialog & Decline| Expansion | `REM02` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-08`**| WebRTC Two-Way Audio/Video Stream | Expansion | `REM03` | Interconnected | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-09`**| Email Verification Resend Throttling| Expansion | `A03` | Shared | `REQUIRES_DISPOSABLE_ACCOUNT` | P2 | `NOT TESTED` |
| **`TC-EXP-10`**| Parent Display Name Update | Expansion | `A07` | Shared | `SAFE_REVERSIBLE` | P2 | `NOT TESTED` |
| **`TC-EXP-11`**| Form Real-Time Validation Feedback | Expansion | `A12` | Shared | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-12`**| Pending Pairing Requests List | Expansion | `FAM03` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-13`**| Cancel Outgoing Pairing Request | Expansion | `FAM04` | Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-EXP-14`**| Child Enrollment Consent & Cancel | Expansion | `FAM05` | Child | `REQUIRES_DISPOSABLE_DEVICE` | P1 | `NOT TESTED` |
| **`TC-EXP-15`**| Family Members & Roles Overview | Expansion | `FAM09` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-16`**| Child Self-Unlink Protection & PIN | Expansion | `FAM11` | Child | `SAFE` | P0 | `NOT TESTED` |
| **`TC-EXP-17`**| Revoke Device from Dashboard | Expansion | `FAM12` | Parent | `REQUIRES_DISPOSABLE_DEVICE` | P0 | `NOT TESTED` |
| **`TC-EXP-18`**| Device Re-Credentialing Recovery | Expansion | `FAM13` | Interconnected | `REQUIRES_ISOLATED_BACKEND` | P1 | `NOT TESTED` |
| **`TC-EXP-19`**| Family Settings Update Backend API | Expansion | `FAM14` | Backend | `REQUIRES_ISOLATED_BACKEND` | P2 | `NOT TESTED` |
| **`TC-EXP-20`**| Connected Devices List & Status Cards| Expansion | `MON02` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-21`**| Child Permission Diagnostics Remote | Expansion | `MON05` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-22`**| Command Delivery & ACK History Log | Expansion | `MON06` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-23`**| Installed Apps Snapshot Upload | Expansion | `MON07` | Child | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-24`**| Parent Dashboard Pull-to-Refresh | Expansion | `MON08` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-25`**| Policy Sync Health Badge Transitions| Expansion | `MON09` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-26`**| Device Filter Toggle: Active/Revoked| Expansion | `MON10` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-27`**| Usage Access Guidance Banner | Expansion | `USE03` | Child | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-28`**| Native Usage Collection & Upload | Expansion | `USE04` | Child | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-29`**| Bedtime Schedule & Curfew Lockout | Expansion | `USE06` | Parent/Child | `SAFE_REVERSIBLE` | P0 | `NOT TESTED` |
| **`TC-EXP-30`**| Real-Time Remaining Quota Countdown | Expansion | `USE07` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-31`**| Quota Exhaustion Lock Screen Trigger| Expansion | `USE08` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-32`**| App Whitelist Category Selection | Expansion | `APP03` | Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-EXP-33`**| Manual Policy Force-Sync Command | Expansion | `APP06` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-34`**| App Restrictions Search & Filter | Expansion | `APP08` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-35`**| 24-Hour Location Route History | Expansion | `LOC02` | Parent | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-36`**| Child Location Sharing Switch | Expansion | `LOC03` | Child/Parent | `SAFE_REVERSIBLE` | P1 | `NOT TESTED` |
| **`TC-EXP-37`**| Background Location Service Tracking| Expansion | `LOC04` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-38`**| Geofence Breach Alert Dispatch | Expansion | `LOC06` | Interconnected | `SAFE` | P0 | `NOT TESTED` |
| **`TC-EXP-39`**| Low Battery Warning Alert Under 15% | Expansion | `LOC07` | Interconnected | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-40`**| Child Device Offline Detection Alert| Expansion | `LOC08` | Interconnected | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-41`**| Tamper Alert on Permission Revoke | Expansion | `LOC09`, `SET08`| Interconnected | `SAFE` | P0 | `NOT TESTED` |
| **`TC-EXP-42`**| Safe Zone Radius Slider Resize | Expansion | `LOC11` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-43`**| Remote Assistance Call Log History | Expansion | `REM04` | Parent | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-44`**| Call Termination & Hardware Teardown| Expansion | `REM05` | Interconnected | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-45`**| In-Call Media Toggle Controls | Expansion | `REM06` | Interconnected | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-46`**| Audit Retention Period Settings | Expansion | `AUD02` | Parent | `SAFE_REVERSIBLE` | P2 | `NOT TESTED` |
| **`TC-EXP-47`**| On-Demand Historical Audit Purge | Expansion | `AUD03` | Parent | `REQUIRES_ISOLATED_BACKEND` | P1 | `NOT TESTED` |
| **`TC-EXP-48`**| Database Scheduled Retention Sweep | Expansion | `AUD04` | Backend | `REQUIRES_ISOLATED_BACKEND` | P2 | `NOT TESTED` |
| **`TC-EXP-49`**| Local Notification Preferences | Expansion | `SET01` | Shared | `SAFE_REVERSIBLE` | P2 | `NOT TESTED` |
| **`TC-EXP-50`**| Location Reminder Interval Dropdown | Expansion | `SET02` | Shared | `SAFE_REVERSIBLE` | P2 | `NOT TESTED` |
| **`TC-EXP-51`**| App Version & Build Display | Expansion | `SET03` | Shared | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-52`**| Runtime Permission Launcher Bridge | Expansion | `SET04` | Child | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-53`**| Background Location Launcher Bridge | Expansion | `SET06` | Child | `SPECIALIST_TEST` | P1 | `NOT TESTED` |
| **`TC-EXP-54`**| Permission Status Tile Visual | Expansion | `SET07` | Shared | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-55`**| Device Admin Revocation Tamper Alert| Expansion | `SET08` | Child | `SPECIALIST_TEST` | P0 | `NOT TESTED` |
| **`TC-EXP-56`**| Child Daemon Sync Network Reconnect | Expansion | `CHD07` | Child | `SAFE` | P1 | `NOT TESTED` |
| **`TC-EXP-57`**| Child Rules Tab Pull-to-Refresh | Expansion | `CHD08` | Child | `SAFE` | P2 | `NOT TESTED` |
| **`TC-EXP-58`**| Periodic Heartbeat Polling Fallback | Expansion | `SYS02` | Shared | `SAFE` | P2 | `NOT TESTED` |

---

## 3. Master Suite Quality & Role Distributions

```
+----------------------------------------------------------------------------------------------------+
|                                    MASTER 99-TEST SUITE DISTRIBUTIONS                              |
+----------------------------------------------------------------------------------------------------+
| 1. ROLE DISTRIBUTION:                                                                              |
|    - Parent Mode Specific:       39 Test Cases (39.4%)                                             |
|    - Child Mode Specific:        25 Test Cases (25.3%)                                             |
|    - Shared (Dual Role):         19 Test Cases (19.2%)                                             |
|    - Interconnected (Multi-Dev): 14 Test Cases (14.1%)                                             |
|    - Backend / Security:          2 Test Cases ( 2.0%)                                             |
+----------------------------------------------------------------------------------------------------+
| 2. EXECUTION PRIORITY DISTRIBUTION:                                                                |
|    - P0 (Critical Path / Danger): 33 Test Cases (33.3%)                                             |
|    - P1 (Core Functional Scope): 42 Test Cases (42.4%)                                             |
|    - P2 (UI / Settings / Info):   24 Test Cases (24.2%)                                             |
+----------------------------------------------------------------------------------------------------+
| 3. EXECUTION STATUS:                                                                               |
|    - Total Tests Executed:        0 ( 0.0%)                                                        |
|    - Total Tests Marked NOT TESTED: 99 (100.0%)                                                    |
+----------------------------------------------------------------------------------------------------+
```
