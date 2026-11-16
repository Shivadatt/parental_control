import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

void main() {
  group('E-13: SafeZone update serialization', () {
    const zone = SafeZone(
      id: 'zone-123',
      familyId: 'family-456',
      name: 'School',
      latitude: 28.5355,
      longitude: 77.3910,
      radiusM: 250,
      active: true,
    );

    test('toUpdateJson excludes family_id to comply with PostgreSQL column privileges', () {
      final updateJson = zone.toUpdateJson();

      expect(updateJson.containsKey('family_id'), isFalse,
          reason: 'family_id must be excluded from UPDATE payload to avoid 42501 error');
      expect(updateJson.containsKey('id'), isFalse);
      expect(updateJson['name'], 'School');
      expect(updateJson['lat'], 28.5355);
      expect(updateJson['lng'], 77.3910);
      expect(updateJson['radius_m'], 250);
      expect(updateJson['active'], true);
    });

    test('toUpsertJson includes family_id for new row INSERT', () {
      final insertJson = zone.toUpsertJson('family-456');

      expect(insertJson['family_id'], 'family-456');
      expect(insertJson['name'], 'School');
      expect(insertJson['lat'], 28.5355);
      expect(insertJson['lng'], 77.3910);
      expect(insertJson['radius_m'], 250);
      expect(insertJson['active'], true);
    });
  });

  group('E-7: Policy enforcement presentation and truthful status', () {
    test('PolicyEnforcementStatus.unsupported displays Advisory label', () {
      expect(PolicyEnforcementStatus.unsupported.label, 'Advisory on this device');
      expect(PolicyEnforcementStatus.unsupported.isAdvisory, isTrue);
      expect(PolicyEnforcementStatus.unsupported.isEnforced, isFalse);
    });

    test('PolicyEnforcementStatus.enforced displays Enforced on device label', () {
      expect(PolicyEnforcementStatus.enforced.label, 'Enforced on device');
      expect(PolicyEnforcementStatus.enforced.isEnforced, isTrue);
      expect(PolicyEnforcementStatus.enforced.isAdvisory, isFalse);
    });

    test('policySummary presents unmanaged/unsupported policy truthfully', () {
      final policy = DevicePolicy(
        id: 'pol-1',
        deviceId: 'dev-1',
        version: 3,
        payload: const PolicyPayload(),
        createdAt: DateTime.now(),
        status: PolicyEnforcementStatus.unsupported,
      );

      final summary = policySummary(
        devicePolicyVersion: 3,
        policy: policy,
      );

      expect(summary, 'Policy v3 · Advisory (Unmanaged)');
    });

    test('policySummary presents managed/enforced policy truthfully', () {
      final policy = DevicePolicy(
        id: 'pol-1',
        deviceId: 'dev-1',
        version: 3,
        payload: const PolicyPayload(),
        createdAt: DateTime.now(),
        status: PolicyEnforcementStatus.enforced,
      );

      final summary = policySummary(
        devicePolicyVersion: 3,
        policy: policy,
      );

      expect(summary, 'Policy v3 · Enforced on device');
    });
  });
}
