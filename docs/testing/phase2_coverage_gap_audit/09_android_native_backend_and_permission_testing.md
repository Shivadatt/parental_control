# 09 — Android Native, Backend and Permission Testing

**Document ID:** `HAVEN-GAP-009`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Deep-Dive Verification of Android Native OS Daemons, Hardware Bridges, Supabase Edge Functions & PostgreSQL Security  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Domain Architecture & Technical Boundaries

HAVEN Parent Control extends beyond standard cross-platform Flutter boundaries into native Android system services and enterprise management APIs. The native Android layer provides:
1. **Device Management & Anti-Tamper**: Enforcing application suspension, detecting permission revocation, and preventing uninstallation.
2. **Persistent Daemon Services**: Foreground services that survive app closure, device reboots, and Android Doze battery optimizations.
3. **Hardware & Cryptographic Anchors**: Generating and storing device private keys in the hardware-backed Android Keystore.
4. **Backend Edge Functions & RLS**: Enforcing zero-trust multi-tenant isolation and automated safety alert evaluations.

This document synthesizes the testing coverage across the Android native subsystem, native-to-Flutter MethodChannels, backend Edge Functions, and database policies.

---

## 2. Android Native Subsystems & Permission Architecture

```
+----------------------------------------------------------------------------------------------------+
|                                    ANDROID NATIVE SUBSYSTEM MAP                                    |
|                                                                                                    |
|  [Flutter Presentation Layer]                                                                      |
|           |                                                                                        |
|           v (MethodChannel: 'com.haven.parentcontrol/native')                                      |
|  [NativeBridge.kt] <====================> [SecureStore.kt] (Android Keystore / Hardware-Backed)     |
|     |            |                   |                                                             |
|     v            v                   v                                                             |
|  [Guardian]   [UsageReporter]   [LocationService]   [DeviceAdminReceiver]                          |
|  Foreground   UsageStatsManager FusedLocationClient DevicePolicyManager                            |
|  Service      PACKAGE_USAGE     ACCESS_BACKGROUND   Device Admin vs Device Owner                   |
+----------------------------------------------------------------------------------------------------+
```

### 2.1 Device Administrator vs Device Owner Ceiling
HAVEN supports two distinct operational modes on Android:
1. **Device Administrator Mode (Standard)**:
   - Activated via `ParentControlDeviceAdminReceiver.kt:25` (`SET05`).
   - Accessible on any consumer Android device via standard user prompt.
   - Prevents non-administrative uninstallation of the app.
   - Restricts apps via full-screen window overlay interception (`USE08`, `TC-EXP-31`).
2. **Device Owner Mode (Enterprise / MDM Ceiling)**:
   - Requires factory reset or ADB provisioning (`dpm set-device-owner`).
   - Enables native OS-level application suspension via `setPackagesSuspended()` (`APP07`, `CHD06`).
   - The OS launcher itself grays out and locks suspended app icons.
   - Completely prevents package launching at the Linux zygote level.

#### Test Coverage for Native MDM:
- `TC-SET05`: Android Device Administrator Activation prompt and system grant.
- `TC-APP07`: Native OS App Suspension under Device Owner mode.
- `TC-EXP-55`: Device Admin revocation tamper warning dialog and broadcast.

---

### 2.2 The Three Native Android Daemons

#### 1. Guardian Foreground Service (`GuardianService.kt`)
- **Capability**: `CHD04` (Persistent Notification & Service Survival)
- **Implementation**: Runs as a high-priority foreground service with `START_STICKY`.
- **System Requirements**: Requires `FOREGROUND_SERVICE` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- **Test Case**: `TC-CHD04` verifies ongoing un-dismissable notification in Android notification shade. Tapping notification opens child app; killing app in Recents causes immediate daemon auto-restart.

#### 2. Native Usage Reporter (`UsageReporter.kt`)
- **Capabilities**: `USE03` (Guidance Banner), `USE04` (Background Collection & Upload)
- **Implementation**: Queries Android `UsageStatsManager` hourly, calculates foreground durations per package, and uploads records to `app_usage_events`.
- **System Requirements**: Requires `PACKAGE_USAGE_STATS` (special system app-ops permission).
- **Test Cases**:
  - `TC-EXP-27`: Verifies child UI displays guidance banner leading directly to Android Usage Access settings.
  - `TC-EXP-28`: Validates hourly aggregation and verified insertion into `app_usage_events`.

#### 3. Continuous Location Service (`LocationTrackingService.kt`)
- **Capabilities**: `LOC03` (Privacy Toggle), `LOC04` (Background GPS Tracking)
- **Implementation**: Uses Google Play Services `FusedLocationProviderClient` for battery-efficient location tracking.
- **System Requirements**: Requires `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION` ("Allow all the time").
- **Test Cases**:
  - `TC-EXP-36`: Verifies child privacy toggle state and policy locks.
  - `TC-EXP-37`: Validates GPS acquisition and coordinate upload while phone screen is OFF and device is locked.

---

### 2.3 Cryptographic Hardware Security (`SecureStore.kt`)
- **Capability**: `FAM07` (Device Registration & Keystore Binding)
- **Implementation**: Interacts with Android Keystore (`AndroidKeyStore` provider).
  - Generates RSA-2048 or EC P-256 asymmetric keypairs inside hardware-backed secure enclave (TEE/StrongBox).
  - Private key never leaves device hardware; public key is transmitted to Supabase during pairing.
  - Device signs telemetry and requests using hardware-bound keys.
- **Test Cases**:
  - `TC-FAM07`: Verifies hardware key generation during pairing handshake.
  - `TC-EXP-18`: Verifies recovery challenge re-keying when Keystore keys are cleared during app reinstall.

---

## 3. Supabase Backend Architecture & Edge Functions

HAVEN Parent Control relies on four specialized Supabase Edge Functions deployed in Deno:

```
+----------------------------------------------------------------------------------------------------+
|                                    SUPABASE EDGE FUNCTIONS                                         |
|                                                                                                    |
|  1. /pairing          - Cryptographic 6-digit challenge generation, QR rendering, token redemption |
|  2. /account          - GDPR data aggregation export, cascade account deletion                     |
|  3. /remote-session   - WebRTC session creation, signaling broker, media session cleanup           |
|  4. /device-telemetry - Telemetry parsing, battery alerts, offline detection, geofence breaches    |
+----------------------------------------------------------------------------------------------------+
```

### 3.1 Edge Functions Test Mapping
- **`pairing` Function**: Verified via `TC-FAM06` (generation), `TC-FAM01`/`TC-FAM02` (redemption), `TC-EXP-13` (cancellation), and `TC-SEC02` (anti-replay).
- **`account` Function**: Verified via `TC-A08` and `TC-EXP-04` (GDPR JSON export) and `TC-A09` (cascade account deletion).
- **`remote-session` Function**: Verified via `TC-REM01` (initiation), `TC-EXP-07` (signaling receipt), `TC-EXP-08` (WebRTC stream), and `TC-EXP-44` (session termination).
- **`device-telemetry` Function**: Verified via `TC-MON04` (heartbeat), `TC-EXP-38` (geofence alerts), `TC-EXP-39` (battery alerts), `TC-EXP-40` (offline detection), and `TC-EXP-41` (tamper alerts).

---

## 4. PostgreSQL Database Security & Multi-Tenant RLS

### 4.1 Row-Level Security (RLS) Tenant Boundary Isolation
All tables in HAVEN (`families`, `devices`, `device_policies`, `location_events`, `app_usage_events`, `safety_alerts`, `audit_events`) enforce PostgreSQL Row-Level Security. A parent's JWT only allows querying data where `family_id` matches the user's enrolled family.

#### Security Adversarial Verification (`TC-SEC01`):
- **Scenario**: Authenticate as Parent A. Execute query against `devices` or `location_events` using `device_id` belonging to Family B.
- **Expected Result**: PostgreSQL RLS policies evaluate `family_id` check to FALSE; query returns 0 rows (`[]`) or HTTP 403 Forbidden. Zero data leakage across family boundaries.
- **Test Classification**: `SPECIALIST_TEST` (Requires isolated staging backend).

### 4.2 Staged Credential Anti-Replay Verification (`TC-SEC02`):
- **Scenario**: Redeem a recovery challenge token. Capture HTTP POST payload. Replay exact same payload 1 second later.
- **Expected Result**: Backend rejects replayed request with HTTP 400 or 409 (`challenge_already_redeemed`). Database credentials remain un-mutated.
- **Test Classification**: `SPECIALIST_TEST` (Requires isolated staging backend).

### 4.3 Database Maintenance & Retention Sweeps (`AUD04`)
- **Capability**: Scheduled database maintenance.
- **Implementation**: PostgreSQL migration `20261030000300_retention_sweep.sql` defines `execute_retention_sweep()`.
- **Test Case**: `TC-EXP-48` verifies the RPC deletes expired audit and telemetry records while preserving active history.

---

## 5. Native & Backend Testing Quarantine Protocols

To protect production infrastructure during native and backend verification:
1. **Isolated Staging Backend Required**: Tests `TC-SEC01`, `TC-SEC02`, `TC-EXP-18`, `TC-EXP-47`, and `TC-EXP-48` must ONLY be run against a dedicated staging Supabase instance (`STAGE_SUPABASE_URL`).
2. **Dedicated Test Hardware**: Tests `TC-SET05`, `TC-APP07`, `TC-EXP-31`, and `TC-EXP-55` must be executed on disposable test phones (or Android Emulators) to prevent locking a personal daily-driver phone.
3. **ADB Shell Access**: Device Owner suspension testing (`TC-APP07`) requires developer workstation connected via ADB to provision Device Owner rights prior to testing.

---

## 6. Native & Backend Coverage Summary

All native Android daemons, hardware keystores, MethodChannels, Edge Functions, and PostgreSQL RLS security boundaries have complete, dedicated manual test cases. Zero native or backend components remain untested.
