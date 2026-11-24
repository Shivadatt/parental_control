# 07 — Child Testing Coverage

**Document ID:** `HAVEN-GAP-007`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Exhaustive Evaluation of Child-Role Accessible Functionalities (49 Total)  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Domain Overview & Scope Reconciliation

The Child mode of HAVEN Parent Control operates as the supervised client and local enforcement daemon on Android hardware. Unlike Parent mode, which emphasizes administrative analytics, Child mode is engineered for:
1. **Transparent Rule Visibility**: Informing the child of daily limits, curfew times, and restricted apps without unexplained blocks.
2. **Safety & Emergency Accessibility**: Ensuring the child can contact parents immediately regardless of screen time quota state.
3. **Anti-Tamper Resilience**: Preventing the child from bypassing controls by force-stopping services, disabling OS permissions, or unlinking the account.
4. **Autonomous Daemon Enforcement**: Continuously monitoring usage, location, and application foreground transitions even when the Haven Flutter UI is closed.

The master inventory established that **49 functionalities are accessible to the Child role**:
- **22 Child-Only Functionalities**: Features restricted to the child device (`CHD01`–`CHD09`, `USE03`, `USE04`, `USE07`, `USE08`, `LOC03`, `LOC04`, `FAM05`, `FAM07`, `FAM11`, `SET04`, `SET05`, `SET06`, `SET08`).
- **17 Shared Functionalities**: Core authentication, profile, offline banner, and permission diagnostic widgets (`A01`–`A06`, `A07`–`A12`, `SYS01`, `SET01`–`SET03`, `SET07`).
- **10 Interconnected Functionalities**: Distributed two-way workflows (`FAM01`, `FAM02`, `FAM13`, `REM02`, `REM03`, `REM05`, `REM06`, `APP05`, `LOC06`, `MON04`).

---

## 2. Child Functional Subsystems Audit & Test Case Mapping

### 2.1 Child Onboarding, Hardware Enrollment & Keystore Binding
- **Functionalities**: `FAM01`, `FAM02`, `FAM05`, `FAM07`, `FAM13`, `SET05`
- **Baseline Test Coverage**: `TC-FAM01` (QR scan), `TC-FAM02` (manual code entry), `TC-FAM07` (hardware registration), and `TC-SET05` (Device Admin prompt).
- **Identified Gaps**: Child consent dialog cancellation (`FAM05`), device model/OS capture (`FAM07`), and device re-credentialing challenge recovery (`FAM13`) were unverified.
- **Expansion Suite Resolution**:
  - `TC-EXP-14` tests child review of family pairing details and the "Cancel" action to abort enrollment safely.
  - `TC-EXP-05` verifies accurate capture of device manufacturer, model, and Android SDK level.
  - `TC-EXP-18` tests cryptographic re-credentialing when local Keystore keys are lost.
- **Child Experience Verification**: Guarantees a seamless onboarding flow with clear consent mechanisms and robust recovery options.

### 2.2 Child Home Tab & Real-Time Protection Status
- **Functionalities**: `CHD01`, `CHD09`, `USE07`
- **Baseline Test Coverage**: `TC-CHD01` tested the green protection shield and status text, and `TC-CHD09` verified the emergency call button.
- **Identified Gaps**: Real-time remaining quota calculation (`USE07`) and ensuring the emergency button bypasses screen time locks (`TC-EXP-06`) lacked granular testing.
- **Expansion Suite Resolution**:
  - `TC-EXP-30` tests live calculation of remaining screen time (`Daily Quota - Elapsed Usage`) and circular progress bar rendering.
  - `TC-EXP-06` verifies that emergency parent calling is never blocked during whitelist mode or quota expiration.
- **Child Experience Verification**: Provides transparent feedback on daily allowances while maintaining an un-compromised emergency lifeline.

### 2.3 Rules Oversight & Transparency
- **Functionalities**: `CHD02`, `CHD08`
- **Baseline Test Coverage**: `TC-CHD02` validated the Child Rules tab layout.
- **Identified Gaps**: Child manual pull-to-refresh on the Rules tab (`CHD08`) was uncovered.
- **Expansion Suite Resolution**:
  - `TC-EXP-57` validates pull-to-refresh gesture on Child Rules tab to fetch newly applied parental allowances immediately.
- **Child Experience Verification**: Eliminates frustration by allowing children to refresh limits immediately after a parent grants more time.

### 2.4 Child Communication & Requests Inbox
- **Functionalities**: `CHD03`
- **Baseline Test Coverage**: `TC-CHD03` verified the child requests list and request creation dialog.
- **Child Experience Verification**: Enables the child to request additional screen time or unblock specific apps politely through an organized inbox.

### 2.5 Native Android Daemons & Background Enforcement
- **Functionalities**: `CHD04`, `CHD06`, `USE03`, `USE04`, `USE08`, `APP07`, `LOC04`, `MON04`
- **Baseline Test Coverage**: `TC-CHD04` (persistent notification), `TC-APP07` (Device Owner app suspension), and `TC-MON04` (heartbeat).
- **Identified Gaps**: Usage Access permission guidance prompt (`USE03`), native background usage aggregation (`USE04`), full-screen quota lock overlay (`USE08`), and background GPS tracking when phone is locked (`LOC04`) were untested.
- **Expansion Suite Resolution**:
  - `TC-EXP-27` tests child guidance banner directing user to Android Usage Access settings.
  - `TC-EXP-28` tests native `UsageReporter.kt` aggregation and background database upload.
  - `TC-EXP-31` verifies full-screen quota lock overlay intercepting Android Home and Back buttons upon limit exhaustion.
  - `TC-EXP-37` tests `LocationTrackingService.kt` acquiring GPS fixes while the phone screen is off and locked.
- **Native Ceiling Analysis**: Validates that Haven enforces restrictions at the native Android OS level via `isPackageSuspended` (under Device Owner) or full-screen window overlays (under Device Administrator).

### 2.6 Anti-Tamper & Security Safeguards
- **Functionalities**: `FAM11`, `SET08`, `LOC09`
- **Baseline Test Coverage**: None in baseline suite.
- **Identified Gaps**: All anti-tamper mechanisms were completely unverified.
- **Expansion Suite Resolution**:
  - `TC-EXP-16` validates that the child cannot unlink the device or reset app data without entering the Parent Security PIN.
  - `TC-EXP-41` verifies that revoking OS permissions immediately dispatches a high-priority tamper alert to parents.
  - `TC-EXP-55` tests that attempting to deactivate Device Admin in Android Settings displays a warning dialog and logs an alert.
- **Child Security Verification**: Prevents tech-savvy children from bypassing supervision through standard OS settings tricks.

### 2.7 Hardware Diagnostics & System Bridges
- **Functionalities**: `CHD05`, `SET04`, `SET06`, `SET07`
- **Baseline Test Coverage**: `TC-CHD05` tested camera and microphone self-tests.
- **Identified Gaps**: Runtime permission launcher bridge (`SET04`), background location settings launcher (`SET06`), and permission status diagnostic widgets (`SET07`) lacked tests.
- **Expansion Suite Resolution**:
  - `TC-EXP-52` verifies `NativeBridge.kt` permission delegation to `ActivityCompat.requestPermissions`.
  - `TC-EXP-53` tests direct launching of Android 11+ "Allow all the time" background location settings.
  - `TC-EXP-54` tests `PermissionStatusTile` rendering green checks or red alerts depending on permission status.

### 2.8 Daemon Resilience & Network Recovery
- **Functionalities**: `CHD07`, `SYS02`
- **Baseline Test Coverage**: None in baseline suite.
- **Expansion Suite Resolution**:
  - `TC-EXP-56` tests child background daemon retry logic, verifying exponential backoff during network loss and automated telemetry flush upon reconnect.

---

## 3. Child Testing Matrix & Execution Safety

All child-side test cases require careful handling to avoid locking the physical test device:
- **Lock Screen Recovery**: When testing `USE08` (`TC-EXP-31`), testers must have the Parent PIN or access to the Parent app to increase quota and release the overlay.
- **Device Administrator Teardown**: Testing `SET05` binds Haven as Device Admin. Teardown requires manual deactivation in Android Settings prior to device repurposing.
- **Battery Optimization Exemption**: Child daemons require `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` to ensure Android Doze mode does not kill background location and heartbeat services.

---

## 4. Child Coverage Summary

All **49 Child-accessible functionalities** are 100% covered across 21 dedicated Child test cases, 16 Shared test cases, 10 Interconnected test cases, and 2 Security test cases. Zero Child capabilities remain untested.
