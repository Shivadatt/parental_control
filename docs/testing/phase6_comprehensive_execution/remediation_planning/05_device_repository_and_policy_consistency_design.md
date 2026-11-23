# 05 — Device Repository & Policy Consistency Remediation Design

**Document ID:** HAVEN-REM-005  
**Target Defects:** HAVEN-QA-005 (`DEF-602`) & HAVEN-QA-006 (`DEF-603`)  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Context & Objectives

This report addresses two interdependent Parent Mode data projection defects:
1. **HAVEN-QA-005 (`DEF-602`)**: Revoked child device rows are returned by `SupabaseDeviceRepository.fetchDevices()` because the SQL query lacks status filtering. This results in duplicate cards on the Parent Dashboard and Devices tab (one active/offline card and one revoked card for the same child).
2. **HAVEN-QA-006 (`DEF-603`)**: Parent Dashboard and Devices tab display conflicting policy version numbers for the same device during policy transition windows because `DashboardController` projects the server desired version while `DevicesController` projects the device-reported version.

---

## 2. Part 1: Device Repository Query Filtering (`HAVEN-QA-005`)

### 2.1 Current Implementation & Failure Mode
In `lib/data/repositories/supabase_device_repository.dart:31-40`:
```dart
@override
Future<List<Device>> fetchDevices(String familyId) => _guard(() async {
      final rows = await _supabase.client
          .from('devices')
          .select(_deviceColumns)
          .eq('family_id', familyId)
          .order('created_at', ascending: true);
      return rows
          .map((row) => Device.fromJson(jsonMap(row)))
          .toList(growable: false);
    });
```
The query selects all rows matching `family_id` without filtering `status`. When a child device is unlinked or revoked, its row is set to `status = 'revoked'`. When re-enrolled, a new row is created with `status = 'active'`. Both rows are returned to the UI.

### 2.2 Proposed Architectural Fix
To preserve historical audit records in the database while preventing dead rows from polluting active views, the repository contract and implementation are updated:

#### 1. Repository Contract Update (`lib/data/repositories/repository_contracts.dart`)
```dart
abstract class DeviceRepository {
  /// Fetches devices for the family. By default, returns only active/enrolled devices.
  /// Pass [includeRevoked] as true only for historical audit or archived device management.
  Future<List<Device>> fetchDevices(
    String familyId, {
    bool includeRevoked = false,
  });

  Future<Device> fetchDevice(String deviceId);
  Future<Device?> fetchMyDevice();
  // ... remaining methods preserved
}
```

#### 2. Implementation Update (`lib/data/repositories/supabase_device_repository.dart`)
```dart
@override
Future<List<Device>> fetchDevices(
  String familyId, {
  bool includeRevoked = false,
}) => _guard(() async {
      var query = _supabase.client
          .from('devices')
          .select(_deviceColumns)
          .eq('family_id', familyId);

      if (!includeRevoked) {
        query = query.neq('status', 'revoked');
      }

      final rows = await query.order('created_at', ascending: true);
      return rows
          .map((row) => Device.fromJson(jsonMap(row)))
          .toList(growable: false);
    });
```

### 2.3 UI Controller Alignment
- **`DashboardController`** and **`DevicesController`**: Call `fetchDevices(familyId)` with default `includeRevoked = false`.
- **Archived Devices Section (Optional)**: If the owner elects to display revoked devices, they are rendered in an explicit, collapsible "Archived Devices" section at the bottom of the Devices tab, clearly segregated from active hardware.

---

## 3. Part 2: Policy Version Consistency Harmonization (`HAVEN-QA-006`)

### 3.1 Current Divergence Analysis
The divergence occurs because the application tracks two distinct version milestones:
- **Desired Version** (`policy.version` from `device_policies` table): The version created by the Parent on the server.
- **Enforced/Applied Version** (`device.policyVersion` from `devices` table): The version successfully applied and acknowledged by the Child device via `/device-command`.

In `dashboard_controller.dart:202-205`:
```dart
String policySummaryFor(Device device) => policySummary(
      devicePolicyVersion: device.policyVersion,
      policy: policies[device.id],
    );
```
Where `device_presentation.dart:27` picks `policy?.version ?? devicePolicyVersion`.

In `devices_controller.dart:159-163`:
```dart
String policySummaryFor(Device device) {
  final version = device.policyVersion;
  if (version == null || version <= 0) return 'No policy applied yet';
  return 'Policy v$version';
}
```
`DevicesController` only looks at `device.policyVersion`, completely ignoring `policies[device.id]`.

### 3.2 Proposed Presentation Model (`device_presentation.dart`)
The presentation layer is refactored to present an honest, comprehensive policy status that eliminates confusion:

```dart
// lib/features/devices/device_presentation.dart

class PolicyDisplayStatus {
  const PolicyDisplayStatus({
    required this.label,
    required this.isPendingSync,
    required this.versionText,
  });

  final String label;
  final bool isPendingSync;
  final String versionText;
}

PolicyDisplayStatus resolvePolicyStatus({
  required int? appliedVersion,
  required DevicePolicy? desiredPolicy,
}) {
  final desiredVersion = desiredPolicy?.version;
  
  if ((appliedVersion == null || appliedVersion <= 0) && desiredVersion == null) {
    return const PolicyDisplayStatus(
      label: 'No policy configured',
      isPendingSync: false,
      versionText: 'No policy',
    );
  }

  // Case 1: Desired policy exists, but device has not acknowledged it yet
  if (desiredVersion != null && appliedVersion != desiredVersion) {
    if (appliedVersion == null || appliedVersion <= 0) {
      return PolicyDisplayStatus(
        label: 'Policy v$desiredVersion · Pending initial sync',
        isPendingSync: true,
        versionText: 'v$desiredVersion (Pending)',
      );
    }
    return PolicyDisplayStatus(
      label: 'Policy v$appliedVersion · Updating to v$desiredVersion...',
      isPendingSync: true,
      versionText: 'v$appliedVersion → v$desiredVersion',
    );
  }

  // Case 2: In sync
  final activeVersion = desiredVersion ?? appliedVersion!;
  final enforcementLabel = desiredPolicy?.status.label ?? 'Enforced';
  return PolicyDisplayStatus(
    label: 'Policy v$activeVersion · $enforcementLabel',
    isPendingSync: false,
    versionText: 'Policy v$activeVersion',
  );
}

String policySummary({
  required int? devicePolicyVersion,
  required DevicePolicy? policy,
}) {
  return resolvePolicyStatus(
    appliedVersion: devicePolicyVersion,
    desiredPolicy: policy,
  ).label;
}
```

### 3.3 Controller Updates
Both `DashboardController` and `DevicesController` must use the unified `policySummary()` function:
```dart
// In DevicesController:
// Replace lines 159-163 with:
String policySummaryFor(Device device) => policySummary(
      devicePolicyVersion: device.policyVersion,
      policy: policies[device.id],
    );
```
`DevicesController` already has access to `policies` map via its dependencies. Using the unified presentation logic ensures that both the Dashboard and Devices tabs project the identical string and state indicators.

---

## 4. Regression Prevention & Test Strategy

1. **Repository Unit Test** (`test/data/repositories/supabase_device_repository_test.dart`):
   - Assert `fetchDevices()` omits rows with `status == 'revoked'`.
   - Assert `fetchDevices(includeRevoked: true)` includes revoked rows.
2. **Presentation Logic Unit Test** (`test/features/devices/device_presentation_test.dart`):
   - Test when `appliedVersion == null` and `desiredVersion == 4` → yields "Pending initial sync".
   - Test when `appliedVersion == 2` and `desiredVersion == 4` → yields "Updating to v4...".
   - Test when `appliedVersion == 4` and `desiredVersion == 4` → yields "Policy v4 · Enforced".
3. **Widget Golden / Snapshot Tests**:
   - Verify device cards on both Dashboard and Devices tab display matching labels under divergent sync states.
