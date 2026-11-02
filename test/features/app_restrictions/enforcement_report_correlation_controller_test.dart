import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockPolicyRepository policyRepository;
  late AppRestrictionsController controller;

  setUpAll(() => registerFallbackValue(const PolicyPayload()));

  Device buildDevice() => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        policyVersion: 4,
      );

  DevicePolicy buildPolicy({
    required String id,
    required int version,
    PolicyEnforcementStatus status = PolicyEnforcementStatus.enforced,
    bool acknowledged = true,
  }) =>
      DevicePolicy(
        id: id,
        deviceId: 'device-1',
        version: version,
        payload: const PolicyPayload(blockedPackages: ['com.instagram.android']),
        createdAt: DateTime(2025, 1, 1),
        status: status,
        acknowledgedAt: acknowledged ? DateTime(2025, 1, 2) : null,
      );

  /// Mirrors what `apply_policy_version` stores: policy_id + version + policy.
  DeviceCommand ackedCommand({
    required String id,
    required Map<String, dynamic> payload,
    required String deviceId,
    Map<String, dynamic>? result,
  }) =>
      DeviceCommand(
        id: id,
        deviceId: deviceId,
        type: DeviceCommandType.applyPolicy,
        payload: payload,
        status: result == null
            ? DeviceCommandStatus.delivered
            : DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        ackedAt: result == null ? null : DateTime(2025, 1, 2),
        result: result,
      );

  const provenCounts = <String, dynamic>{
    'desired_count': 2,
    'applied_count': 2,
    'failed_count': 0,
    'enforcement_supported': true,
    'enforcement_mode': 'device_owner',
  };

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    controller = AppRestrictionsController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: ConnectivityService(),
    );
    addTearDown(controller.onClose);
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice());
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
  });

  Future<void> loadWith({
    required DevicePolicy? policy,
    required List<DeviceCommand> commands,
  }) async {
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => commands);
    await controller.load();
  }

  test('a report whose policy id matches proves enforcement', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        ackedCommand(
          id: 'command-1',
          deviceId: 'device-1',
          payload: const {'policy_id': 'policy-4', 'version': 4},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementCorrelation, PolicyReportCorrelation.matched);
    expect(controller.enforcementUncorrelated, isFalse);
    expect(controller.enforcementProven, isTrue);
    expect(controller.appliedCountsText, 'Applied to 2 of 2 apps');
    expect(controller.policyStateText, contains('enforced on the device'));
    expect(controller.policyStateText, contains('Applied to 2 of 2 apps'));
    expect(controller.enforcementCorrelationNotice, isNull);
  });

  test('a report naming another policy is never reused for this one', () async {
    await loadWith(
      policy: buildPolicy(
        id: 'policy-6',
        version: 6,
        status: PolicyEnforcementStatus.pending,
        acknowledged: false,
      ),
      commands: [
        ackedCommand(
          id: 'command-old',
          deviceId: 'device-1',
          payload: const {'policy_id': 'policy-5', 'version': 5},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementCorrelation, isNull);
    expect(controller.appliedCountsText, isNull);
    expect(controller.enforcementProven, isFalse);
    expect(controller.awaitingAcknowledgement, isTrue);
    expect(controller.policyStateText, contains('Pending device acknowledgement'));
  });

  test('a report without a policy id stays visible but is not proof', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        ackedCommand(
          id: 'command-legacy',
          deviceId: 'device-1',
          payload: const <String, dynamic>{'version': 4},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementCorrelation, PolicyReportCorrelation.uncorrelated);
    expect(controller.enforcementUncorrelated, isTrue);
    expect(controller.enforcementReport?.appliedSummary, 'Applied to 2 of 2 apps');
    expect(controller.appliedCountsText, 'Applied to 2 of 2 apps');
    expect(controller.enforcementProven, isFalse);
    expect(controller.policyStateText, isNot(contains('enforced on the device')));
    expect(controller.policyStateText, contains('does not name this policy'));
    expect(controller.enforcementCorrelationNotice, contains('for reference only'));
  });

  test('an empty policy id is treated as uncorrelated, not as a wildcard', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        ackedCommand(
          id: 'command-blank',
          deviceId: 'device-1',
          payload: const {'policy_id': ''},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementCorrelation, PolicyReportCorrelation.uncorrelated);
    expect(controller.enforcementProven, isFalse);
    expect(controller.enforcementReport?.desiredCount, 2);
  });

  test('an older device payload without the field is never proof for the current policy',
      () async {
    await loadWith(
      policy: buildPolicy(
        id: 'policy-7',
        version: 7,
        status: PolicyEnforcementStatus.enforced,
      ),
      commands: [
        ackedCommand(
          id: 'command-old-device',
          deviceId: 'device-1',
          // The device's own result shape: counters plus bookkeeping fields,
          // no policy id anywhere.
          payload: const <String, dynamic>{},
          result: const <String, dynamic>{
            'success': true,
            'applied_at': '2025-01-02T00:00:00.000Z',
            'suspended_packages': ['com.instagram.android'],
            'errors': <String>[],
            'desired_count': 1,
            'applied_count': 1,
            'failed_count': 0,
            'enforcement_supported': true,
            'enforcement_mode': 'device_owner',
          },
        ),
      ],
    );

    expect(controller.currentStatus, PolicyEnforcementStatus.enforced);
    expect(controller.enforcementUncorrelated, isTrue);
    expect(controller.enforcementProven, isFalse);
    expect(controller.policyStateText, contains('not counted as proof'));
  });

  test('a matching report outranks a newer uncorrelated one', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        // newest first, as the repository orders them
        ackedCommand(
          id: 'command-legacy',
          deviceId: 'device-1',
          payload: const <String, dynamic>{},
          result: const <String, dynamic>{
            'desired_count': 5,
            'applied_count': 0,
            'failed_count': 5,
            'enforcement_supported': true,
          },
        ),
        ackedCommand(
          id: 'command-match',
          deviceId: 'device-1',
          payload: const {'policy_id': 'policy-4'},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementCorrelation, PolicyReportCorrelation.matched);
    expect(controller.enforcementProven, isTrue);
    expect(controller.appliedCountsText, 'Applied to 2 of 2 apps');
  });

  test('a command row from another device is ignored', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        ackedCommand(
          id: 'command-other-device',
          deviceId: 'device-2',
          payload: const {'policy_id': 'policy-4'},
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementProven, isFalse);
  });

  test('a new policy while an old command is pending gets no old report', () async {
    final oldPolicy = buildPolicy(
      id: 'policy-4',
      version: 4,
      status: PolicyEnforcementStatus.enforced,
    );
    final newPolicy = buildPolicy(
      id: 'policy-5',
      version: 5,
      status: PolicyEnforcementStatus.pending,
      acknowledged: false,
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => oldPolicy);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [
              ackedCommand(
                id: 'command-4',
                deviceId: 'device-1',
                payload: const {'policy_id': 'policy-4', 'version': 4},
                result: provenCounts,
              ),
            ]);
    await controller.load();
    expect(controller.enforcementProven, isTrue);

    // The parent saves v5; the v4 ack is still the only result on file.
    when(() => policyRepository.updatePolicy(
          deviceId: 'device-1',
          payload: any(named: 'payload'),
          idempotencyKey: any(named: 'idempotencyKey'),
        )).thenAnswer(
      (_) async => PolicyUpdateResult(
        policy: newPolicy,
        command: ackedCommand(
          id: 'command-5',
          deviceId: 'device-1',
          payload: const {'policy_id': 'policy-5', 'version': 5},
        ),
      ),
    );
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [
              ackedCommand(
                id: 'command-5',
                deviceId: 'device-1',
                payload: const {'policy_id': 'policy-5', 'version': 5},
              ),
              ackedCommand(
                id: 'command-4',
                deviceId: 'device-1',
                payload: const {'policy_id': 'policy-4', 'version': 4},
                result: provenCounts,
              ),
            ]);

    final saved = await controller.savePolicy();

    expect(saved, isTrue);
    expect(controller.currentVersion, 5);
    expect(controller.awaitingAcknowledgement, isTrue);
    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementProven, isFalse);
    expect(controller.appliedCountsText, isNull);

    // The device finally acks v5: the server marks v5 enforced and the report
    // is attributed to it.
    final ackedNewPolicy = buildPolicy(id: 'policy-5', version: 5);
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => ackedNewPolicy);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [
              ackedCommand(
                id: 'command-5',
                deviceId: 'device-1',
                payload: const {'policy_id': 'policy-5', 'version': 5},
                result: provenCounts,
              ),
              ackedCommand(
                id: 'command-4',
                deviceId: 'device-1',
                payload: const {'policy_id': 'policy-4', 'version': 4},
                result: provenCounts,
              ),
            ]);
    await controller.refreshPolicy();

    expect(controller.enforcementCorrelation, PolicyReportCorrelation.matched);
    expect(controller.evidence?.expectedPolicyId, 'policy-5');
    expect(controller.enforcementProven, isTrue);
  });

  test('a superseded report response cannot overwrite the newer policy', () async {
    final v6 = buildPolicy(
      id: 'policy-6',
      version: 6,
      status: PolicyEnforcementStatus.enforced,
    );
    final v7 = buildPolicy(
      id: 'policy-7',
      version: 7,
      status: PolicyEnforcementStatus.pending,
    );
    final firstCommands = Completer<List<DeviceCommand>>();
    var policyCalls = 0;
    var commandCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async {
      policyCalls += 1;
      return policyCalls == 1 ? v6 : v7;
    });
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async {
      commandCalls += 1;
      if (commandCalls == 1) return firstCommands.future;
      return [
        ackedCommand(
          id: 'command-7',
          deviceId: 'device-1',
          payload: const {'policy_id': 'policy-7', 'version': 7},
        ),
      ];
    });

    final first = controller.refreshPolicy();
    await controller.refreshPolicy();
    expect(controller.currentVersion, 7);
    expect(controller.enforcementReport, isNull);

    // The slow response for v6 lands after v7 was already loaded.
    firstCommands.complete([
      ackedCommand(
        id: 'command-6',
        deviceId: 'device-1',
        payload: const {'policy_id': 'policy-6', 'version': 6},
        result: provenCounts,
      ),
    ]);
    await first;

    expect(controller.currentVersion, 7);
    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementProven, isFalse);
  });

  test('a report command that is not apply_policy is never a report', () async {
    await loadWith(
      policy: buildPolicy(id: 'policy-4', version: 4),
      commands: [
        DeviceCommand(
          id: 'command-sync',
          deviceId: 'device-1',
          type: DeviceCommandType.syncPolicy,
          payload: const {'policy_id': 'policy-4'},
          status: DeviceCommandStatus.succeeded,
          createdAt: DateTime(2025, 1, 1),
          expiresAt: DateTime(2025, 1, 2),
          result: provenCounts,
        ),
      ],
    );

    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementProven, isFalse);
  });

  test('a read failure leaves no report behind for the current policy', () async {
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(id: 'policy-4', version: 4));
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenThrow(Exception('backend down'));

    await controller.load();

    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementProven, isFalse);
  });
}
