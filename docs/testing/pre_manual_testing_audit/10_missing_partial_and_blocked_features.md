# 10 — Missing, Partial and Blocked Features Report

**Document ID:** `HAVEN-INV-010`  
**Phase:** Pre-Testing Functional Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Scope:** Functional Gap Analysis, Truncated Implementations & Capability Absences  

---

## 1. Executive Summary

This document categorizes all functionality gaps, incomplete implementations, non-functional UI controls, and completely absent parental control capabilities in HAVEN Parent Control. 

Understanding these limitations is vital to ensure that QA testers do not report expected architectural absences as unexpected software crashes, and to provide product stakeholders with a clear roadmap of functional boundaries.

---

## 2. Category 1: Partially Implemented Functionalities (7 Features)

These features have substantial code written in the client or native daemon, but their complete user outcome is broken or severely truncated:

| Functionality ID | Feature Name | Intended Outcome | What Works | What is Broken / Missing | Root Cause & Evidence |
|---|---|---|---|---|---|
| **MON04** | Heartbeat-Derived Online/Offline Presence | Parent sees green "Online" badge when child is active; "Offline" when inactive. | Presence model, mathematical delta calculations, and status indicators in UI. | If child app is reinstalled, new device secret no longer matches `devices.secret_hash`. Server returns HTTP 401; heartbeat permanently halts; child stays "Offline". | `HAVEN-QA-003` (DEF-601). In `auth.ts:297-353`, `SecureStore.kt:86-105`. |
| **MON05** | Child Permissions Diagnostic Summary | Parent sees truthful status of child hardware permissions. | Permission fields are serialized and uploaded to `devices` table; rendered on Device Detail. | On Android 12, notification permission reports false-positive "Granted" even when user disabled notifications in OS settings. | `HAVEN-QA-004` (DEF-604). In `NativePermissions.kt:29-32`, naive SDK check returns `true`. |
| **USE04** | Child Usage Statistics Collection & Upload | Child uploads daily app usage hours and launch counts to parent. | `UsageReporter.kt` queries `UsageStatsManager` and aggregates daily usage. | Telemetry upload requires valid device secret. Breaks after reinstall; parent receives zero usage updates. | Cascading failure from `HAVEN-QA-003`. |
| **USE06** | Bedtime Schedule Lockout | Child device locks down during configured bedtime hours (e.g. 21:00–07:00). | Parent can configure bedtime start/end; schedule renders in Child Rules. | Bedtime rule is informational only. `PolicyApplier.kt:502` logs bedtime, but no lock screen or app suspension is triggered. | Incomplete enforcement logic in `PolicyApplier.kt`. |
| **USE08** | OS-Level Daily Quota Enforcement | Device suspends non-essential apps when daily limit is reached. | `QuotaEvaluator.kt` calculates consumed time and builds suspension plan. | Package suspension requires Android **Device Owner** status. Standard Play/sideloaded install reaches Device Admin only; suspension fails. | Device Owner privilege ceiling (`EnforcementMode.kt`). |
| **APP07** | Native OS Package Suspension | Blocked apps cannot be launched by child; OS shows block prompt. | Parent configures rules; daemon calls `DevicePolicyManager.setPackagesSuspended()`. | Call throws security exception or returns failure on standard installs because app is not Device Owner. | Android OS security model boundary (`PolicyApplier.kt:140`). |
| **LOC04** | Continuous Background Location Upload | Child GPS coordinates uploaded on displacement to track movements. | `LocationTrackingService.kt` acquires GPS fixes and creates JSON payload. | Ingress endpoint requires valid device secret. Breaks after reinstall; location updates cease. | Cascading failure from `HAVEN-QA-003`. |

---

## 3. Category 2: UI-Only & Backend-Only Features (4 Features)

These features represent "half-implemented" components where either the user interface or the backend server logic exists without the corresponding counterpart:

### 3.1 UI-Only Preferences (2 Controls)
- **`SET01` — Local Notification Preference**:
  - *Location*: Parent Settings tab (`parent_settings_page.dart:147`).
  - *Behavior*: A toggle switch labeled "Local notifications" persists a boolean in `SharedPreferences`.
  - *Gap*: Zero local notification schedulers, background listeners, or notification plugins read or consume this setting.
- **`SET02` — Location-Sharing Reminder Preference**:
  - *Location*: Parent Settings tab (`parent_settings_page.dart:164`).
  - *Behavior*: A toggle switch labeled "Location reminder" persists a boolean in `SharedPreferences`.
  - *Gap*: Zero reminder engines or background work managers consume this preference.

### 3.2 Backend-Only APIs (2 Server Capabilities)
- **`FAM14` — Family Settings Update API**:
  - *Location*: `supabase_family_repository.dart:150` (`FamilyRepository.updateSettings`).
  - *Behavior*: Complete repository method and Edge Function support updating family metadata.
  - *Gap*: No button, dialog, or controller in the Flutter application invokes this API.
- **`AUD04` — Scheduled Retention Sweep**:
  - *Location*: `supabase/migrations/20261030000300_retention_sweep.sql` (`run_retention_sweep`).
  - *Behavior*: Server-side SQL cron function and Edge Function `cron` automatically purge expired audit logs.
  - *Gap*: Background system maintenance only; zero in-app user entry points.

---

## 4. Category 3: Absent Capabilities (10 Capabilities)

The following 10 capabilities represent expected parental control features that were thoroughly investigated and confirmed to be **COMPLETELY ABSENT** from the codebase:

```
+--------------------------------------------------------------------------------------------------+
|                                    ABSENT CAPABILITIES CATALOG                                   |
|                                                                                                  |
|  [ M01 ] Web & Content Filtering       --> Zero DNS / VPN / HTTP Proxy / SafeSearch logic        |
|  [ M02 ] Cloud Push Notifications (FCM)--> Zero Firebase / FCM dependencies; realtime only       |
|  [ M03 ] Password Reset Recovery       --> No "Forgot Password" flow or email reset in-app      |
|  [ M04 ] Device Owner Provisioning     --> App explicitly disclaims provisioning support         |
|  [ M05 ] Remote Lock & Wipe            --> No DevicePolicyManager lockNow() or wipeData()        |
|  [ M06 ] App Install/Uninstall Alerts  --> No PACKAGE_ADDED BroadcastReceiver declared           |
|  [ M07 ] Multi-Family Switcher         --> Session model holds single active family              |
|  [ M08 ] Accessibility Enforcement     --> No AccessibilityService declared or implemented      |
|  [ M09 ] Family Ownership Transfer     --> No RPC to transfer family ownership or delete family  |
|  [ M10 ] Co-Parent / Guardian Invites  --> No multi-parent administrative invitation flow        |
+--------------------------------------------------------------------------------------------------+
```

### Detailed Breakdown of Top 3 Missing Capabilities:
1. **`M01` Website & Content Filtering**:
   - Parents cannot restrict adult websites, filter YouTube content, or enforce Google SafeSearch.
   - The application controls local installed Android packages only.
2. **`M02` Cloud Push Notifications (FCM)**:
   - There are zero Firebase Messaging dependencies.
   - If the parent closes the application, **no background alerts will be delivered to the parent's phone**. Alerts are received only when the parent actively launches the application.
3. **`M03` Password Reset Flow**:
   - There is no "Forgot Password" link on `/auth/login`.
   - If a parent forgets their password, they must be manually reset by a database administrator in the Supabase Auth dashboard.

---

## 5. Dependency-Blocked Feature Matrix

The following table maps how specific defects and capability absences cascade to block other features:

| Root Defect or Absence | Blocked Functionalities | Nature of Blocker | Impact on User Experience |
|---|---|---|---|
| **`HAVEN-QA-003`** (DEF-601 Device Credential Lifecycle) | `MON04` (Heartbeat Presence)<br/>`USE04` (Usage Stats Upload)<br/>`LOC04` (Location Tracking)<br/>`MON07` (App Snapshot) | Server returns HTTP 401 on telemetry ingress due to secret hash mismatch after child reinstall. | Child handset appears permanently "Offline"; usage graphs and location maps freeze. |
| **`M04`** (Device Owner Provisioning Absent) | `APP07` (Native OS App Suspension)<br/>`USE08` (Daily Quota Lockout) | Android OS requires Device Owner to invoke `setPackagesSuspended()`. Standard installs reach Device Admin only. | Child can continue launching blocked applications; quota limits do not lock device. |
| **`HAVEN-QA-004`** (DEF-604 Android 12 Permission Detection) | `MON05` (Permissions Summary)<br/>`LOC09` (Permission Tampering Alerts) | Naive SDK check unconditionally returns `true` on API $\le 32$. | Parent dashboard falsely claims notifications are active when disabled by child. |

---

## 6. Pre-Testing QA Guidance

When conducting manual testing in future authorized phases:
1. **Do not log defects for `M01`–`M10`**: These are documented product limitations, not software bugs.
2. **Expect `APP07` to fail on standard installs**: Verify that `PolicyApplier.kt` handles the lack of Device Owner gracefully without crashing.
3. **Quarantine Reinstall Testing**: Do not reinstall the child application during testing without a clean re-enrollment, or `HAVEN-QA-003` will block all telemetry.
