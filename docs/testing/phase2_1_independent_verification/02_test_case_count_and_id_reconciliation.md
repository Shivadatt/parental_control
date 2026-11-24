# 02 — Test Case Count and ID Reconciliation

**Document ID:** `HAVEN-VER-002`  
**Phase:** Phase 2.1 — Independent Consistency & Coverage Verification  
**Workspace:** `D:\parentcontrol_app`  
**Baseline Suite:** `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md`  
**Expansion Suite:** `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md`  
**Audit Standard:** Mathematical Audit & Unique ID Verification  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Audit Target & Problem Statement

Phase 2 deliverables report the following suite sizing:
- Original Baseline Suite: **35 Test Cases**
- Expansion Suite: **50 Test Cases** (claimed in `01_phase2_executive_summary.md:38`) / **58 Test Cases** (defined in `05_additional_manual_test_cases.md`)
- Consolidated Master Suite: **"85 Master Test Cases"** / **"85+ Master Test Cases"**

This formulation is mathematically inconsistent:
- $35 + 58 = 93$
- $41 + 58 = 99$
- Neither equals $85$.

The mission of this audit is to inspect every physical test case heading in the repository, identify all unique IDs, detect duplicate or phantom references, and establish the exact, immutable integer for the consolidated manual testing suite.

---

## 2. Independent Baseline Test Case Sizing Audit

### 2.1 The "35 Core" vs 41 Actual Baseline Headings
In `docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md`, the document states in §10:  
> *"Total Manual Test Cases Prepared: 35 Core End-to-End Test Cases (spanning all 92 inventoried functionalities)."*

However, an automated regex match for `^### (TC-[A-Z0-9]+)` across `08_manual_test_case_master_list.md` reveals **exactly 41 test case headings**:

```
Group 1 (Basic App & Navigation):      TC-A10, TC-A06, TC-SYS01                              ( 3 Tests)
Group 2 (Auth & Account Lifecycle):    TC-A01, TC-A02, TC-A04, TC-A05, TC-A08, TC-A09, TC-A11 ( 7 Tests)
Group 3 (Family Setup & Pairing):      TC-FAM08, TC-FAM06, TC-FAM01, TC-FAM02, TC-FAM07, TC-FAM10 ( 6 Tests)
Group 4 (Parent Dashboard & Telemetry):TC-MON01, TC-MON03                                    ( 2 Tests)
Group 5 (Screen Time & App Mgmt):      TC-USE01, TC-USE02, TC-USE05, TC-APP01, TC-APP02, TC-APP04 ( 6 Tests)
Group 6 (Location & Geofencing):       TC-LOC01, TC-LOC05, TC-LOC10                          ( 3 Tests)
Group 7 (Remote Assistance & Audit):   TC-REM01, TC-AUD01                                    ( 2 Tests)
Group 8 (Child Shell & System):        TC-CHD01, TC-CHD02, TC-CHD03, TC-CHD05, TC-CHD09, TC-CHD04 ( 6 Tests)
---------------------------------------------------------------------------------------------------------
[Subtotal: "35 Core End-to-End Test Cases"]:                                                 (35 Tests)
---------------------------------------------------------------------------------------------------------
Group 8 Continued (Native System):     TC-SET05, TC-APP07, TC-MON04, TC-APP05                 ( 4 Tests)
Group 9 (Security & Boundaries):       TC-SEC01, TC-SEC02                                    ( 2 Tests)
---------------------------------------------------------------------------------------------------------
[GRAND TOTAL BASELINE HEADINGS]:                                                             (41 Tests)
```

**Verification Finding**: The Pre-Testing functional audit created 35 core functional test cases, but appended 6 specialized native and security test cases (`TC-SET05`, `TC-APP07`, `TC-MON04`, `TC-APP05`, `TC-SEC01`, `TC-SEC02`), bringing the true baseline count to **41 defined test cases**.

---

## 3. Independent Expansion Suite Sizing Audit

In `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md`, every test case was checked via automated regex `^### (TC-EXP-[0-9]+)`.

**Verification Finding**:
- `TC-EXP-01` through `TC-EXP-58` are sequentially defined.
- Exactly **58 expansion test cases** exist in `05_additional_manual_test_cases.md`.
- Zero duplicate IDs exist in the expansion suite.
- Zero gaps exist in the numbering sequence (01 through 58).
- **The claim in §2.2 of `01_phase2_executive_summary.md` that Phase 2 authored "50 new comprehensive manual test cases" is an undercount**: the author actually authored 58 granularized test cases.

---

## 4. Master Mathematical Reconciliation Table

| Metric | Phase 2 Claim | Independently Verified Count | Reconciliation Finding |
|---|:---:|:---:|:---|
| **Original Baseline Test Cases** | 35 | **41** | Pre-testing summary counted 35 core tests, omitting 6 native/security sub-cases. |
| **Expansion Test Cases** | 50 (claimed) / 58 (actual) | **58** | 58 test cases defined (`TC-EXP-01` through `TC-EXP-58`). |
| **IDs Appearing in Both Suites** | 0 | **0** | Baseline uses `TC-<domain>` prefix; Expansion uses `TC-EXP-<num>`. |
| **Duplicate IDs Inside Baseline Suite** | 0 | **0** | All 41 baseline IDs are unique. |
| **Duplicate IDs Inside Expansion Suite** | 0 | **0** | All 58 expansion IDs are unique. |
| **Total Unique Test Cases Defined** | "85+" (Ambiguous) | **99** | $41 \text{ (Baseline)} + 58 \text{ (Expansion)} = \mathbf{99}$. |
| **Test Cases Mapped in Traceability Matrix**| 92 functionalities | **98** | Mapped all 99 unique tests except `TC-SEC01` (omitted from table). |
| **Test Cases Included in Roadmap** | 85 (claimed) | **95 valid + 1 phantom** | Included 95 valid tests, omitted 4 tests, referenced 1 phantom. |
| **Test Cases Omitted from Roadmap** | 0 | **4** | `TC-MON04`, `TC-EXP-23`, `TC-EXP-49`, `TC-EXP-50` missing from roadmap. |
| **Phantom Test Cases Referenced** | 0 | **1** | `TC-FAM11` referenced in Phase 3.7 step 5 (not defined in any file). |
| **FINAL VALID MASTER SUITE** | "85+" | **99 UNIQUE TEST CASES** | Exact, non-ambiguous integer count. |

---

## 5. Complete Catalog of All 99 Unique Test Cases

### 5.1 Baseline Test Cases (41 Unique IDs)
1. `TC-A10`: Missing Configuration Fallback Screen
2. `TC-A06`: Role Selection Screen Options
3. `TC-SYS01`: Offline Mode Detection & Warning Banner
4. `TC-A01`: Parent & Child Email Sign-In
5. `TC-A02`: Account Registration Flow
6. `TC-A04`: Cold App Launch Session Restoration
7. `TC-A05`: Sign Out & Token Revocation
8. `TC-A08`: Account Data Export (GDPR)
9. `TC-A09`: Account Deletion with Confirmation Cascade
10. `TC-A11`: Password Reveal & Masking Toggle
11. `TC-FAM08`: Family Group Creation
12. `TC-FAM06`: Child Linking Code & QR Code Generation
13. `TC-FAM01`: Link Child via Camera QR Code Scanning
14. `TC-FAM02`: Link Child via Manual 6-Digit Code Entry
15. `TC-FAM07`: Child Device Hardware Registration & Keystore Binding
16. `TC-FAM10`: Unlink Child Account from Parent Dashboard
17. `TC-MON01`: Parent Dashboard Summary Cards Rendering
18. `TC-MON03`: Device Detail Technical Telemetry
19. `TC-MON04`: Background Heartbeat Presence Transmission
20. `TC-USE01`: Daily Screen Time 7-Day Usage Chart
21. `TC-USE02`: Per-Application Daily Usage Breakdown
22. `TC-USE05`: Daily Screen Time Quota Limit Setting
23. `TC-APP01`: Blocking Individual Target Application
24. `TC-APP02`: Whitelist Mode (Block All Except Allowed)
25. `TC-APP04`: Per-App Allowed Schedule Windows
26. `TC-APP05`: Policy Command Delivery & Acknowledgment Loop
27. `TC-APP07`: Native OS App Suspension Under Device Owner
28. `TC-LOC01`: Child Real-Time Map Location Display
29. `TC-LOC05`: Safe Zone Geofence Creation
30. `TC-LOC10`: Safety Alerts Inbox & Acknowledgment
31. `TC-REM01`: Initiating Remote Assistance Call
32. `TC-AUD01`: Administrative Audit Log Viewer
33. `TC-CHD01`: Child Home Protection Status Overview
34. `TC-CHD02`: Child Rules & Policy Oversight View
35. `TC-CHD03`: Child Requests Inbox & Notifications Badge
36. `TC-CHD05`: Camera & Microphone Hardware Self-Test
37. `TC-CHD09`: Emergency Parent Quick-Call Dialer Action
38. `TC-CHD04`: Guardian Foreground Service Persistent Notification
39. `TC-SET05`: Android Device Administrator Activation
40. `TC-SEC01`: Cross-Family Unauthorized Data Access Boundary (RLS)
41. `TC-SEC02`: Replay of Staged Credential Redemption

### 5.2 Expansion Test Cases (58 Unique IDs)
42. `TC-EXP-01`: Role Assignment Persistence and Immutability
43. `TC-EXP-02`: Login Invalid Password and Rate Limiting
44. `TC-EXP-03`: Registration Duplicate Email Rejection
45. `TC-EXP-04`: Account Data Export Structure Verification
46. `TC-EXP-05`: Child Device Model and OS Metadata Registration
47. `TC-EXP-06`: Whitelist Mode Emergency Phone Bypass Verification
48. `TC-EXP-07`: Child Incoming Remote Call Notification & Dialog
49. `TC-EXP-08`: WebRTC Two-Way Audio and Video Streaming
50. `TC-EXP-09`: Email Verification Resend and Rate Throttling
51. `TC-EXP-10`: Update Parent Display Name in Settings
52. `TC-EXP-11`: Input Validation Feedback on Auth Forms
53. `TC-EXP-12`: Pending Pairing Invitations Roster
54. `TC-EXP-13`: Revoke Pending Pairing Code Before Redemption
55. `TC-EXP-14`: Child Enrollment Consent Screen Cancel Action
56. `TC-EXP-15`: Family Management Members and Roles List
57. `TC-EXP-16`: Child Self-Unlink Prevention and Parent PIN Challenge
58. `TC-EXP-17`: Revoke Child Device from Dashboard
59. `TC-EXP-18`: Re-Credential Child Device via Recovery Challenge
60. `TC-EXP-19`: Family Settings API Configuration Update
61. `TC-EXP-20`: Multi-Device List Rendering on Parent App
62. `TC-EXP-21`: Remote Inspection of Child Android OS Permissions
63. `TC-EXP-22`: Inspect Device Remote Command Audit Trail
64. `TC-EXP-23`: Native Installed Applications List Snapshot
65. `TC-EXP-24`: Dashboard Manual Refresh via Swipe Gesture
66. `TC-EXP-25`: Visual Policy Sync Status Badge Updates
67. `TC-EXP-26`: Filter Devices Tab by Status
68. `TC-EXP-27`: Usage Access Guidance Prompt on Child Device
69. `TC-EXP-28`: Hourly Usage Reporter Daemon Verification
70. `TC-EXP-29`: Bedtime Lockout Schedule Configuration
71. `TC-EXP-30`: Real-Time Remaining Quota Countdown
72. `TC-EXP-31`: Quota Exhaustion Lock Screen Trigger
73. `TC-EXP-32`: Whitelist Apps Selection by Category
74. `TC-EXP-33`: Dispatch Manual Policy Force-Sync from Parent
75. `TC-EXP-34`: Search App Restrictions List by App Name
76. `TC-EXP-35`: View 24-Hour Location History Breadcrumb Trail
77. `TC-EXP-36`: Child Location Sharing Switch Enforcement
78. `TC-EXP-37`: Background Location Service Tracking and Upload
79. `TC-EXP-38`: Safe Zone Geofence Breach Alert Dispatch
80. `TC-EXP-39`: Low Battery Warning Alert Under 15%
81. `TC-EXP-40`: Child Device Offline Detection Alert
82. `TC-EXP-41`: Tamper Alert on OS Permission Revocation
83. `TC-EXP-42`: Safe Zone Geofence Radius Slider Visual Resize
84. `TC-EXP-43`: Remote Assistance Call Log Audit Trail
85. `TC-EXP-44`: Remote Call Termination and Hardware Teardown
86. `TC-EXP-45`: In-Call Media Toggle Controls
87. `TC-EXP-46`: Set Audit Log Retention Period in Settings
88. `TC-EXP-47`: On-Demand Historical Audit Log Purge
89. `TC-EXP-48`: Database Scheduled Retention Sweep RPC
90. `TC-EXP-49`: Parent App Push Notification Preferences
91. `TC-EXP-50`: Location Update Interval Dropdown
92. `TC-EXP-51`: App Version and Build Number Verification
93. `TC-EXP-52`: Native Permission Request Dialog Launcher
94. `TC-EXP-53`: Launch Android Background Location Settings
95. `TC-EXP-54`: Permission Status Tile Visual Indicator
96. `TC-EXP-55`: Device Admin Revocation Tamper Warning Dialog
97. `TC-EXP-56`: Child Daemon Sync Network Reconnect
98. `TC-EXP-57`: Child Rules Tab Pull-to-Refresh
99. `TC-EXP-58`: Periodic Heartbeat Polling Fallback

---

## 6. Discrepancy Reconciliation Verdict

The master test suite for HAVEN Parent Control consists of **exactly 99 unique, non-overlapping, and fully specified manual test cases**.  
The term "85+" is an obsolete relic from an early draft that assumed 35 + 50 = 85.  
All future QA documentation must use the authoritative count of **99 Master Test Cases**.
