import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockPolicyRepository policyRepository;
  late ConnectivityService connectivity;
  late AppRestrictionsController controller;

  Device buildDevice({String enforcementMode = 'device_owner'}) => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: enforcementMode,
        policyVersion: 3,
      );

  DeviceCommand applyCommand({
    required String policyId,
    required Map<String, dynamic> result,
  }) =>
      DeviceCommand(
        id: 'command-1',
        deviceId: 'device-1',
        type: DeviceCommandType.applyPolicy,
        payload: {'policy_id': policyId},
        status: DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        result: result,
      );

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    connectivity = ConnectivityService();
    controller = AppRestrictionsController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice());
  });

  test('shows pending acknowledgement and an unreported app snapshot', () async {
    const payload = PolicyPayload(dailyScreenTimeLimitMinutes: 120);
    final policy = DevicePolicy(
      id: 'policy-3',
      deviceId: 'device-1',
      version: 3,
      payload: payload,
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.pending,
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.currentVersion, 3);
    expect(controller.awaitingAcknowledgement, isTrue);
    expect(controller.policyStateText, contains('Pending device acknowledgement'));
    expect(controller.policyStateText, isNot(contains('enforced on the device')));
    expect(controller.appsReported, isFalse);
    expect(controller.hasLoadedSnapshot.value, isTrue);
    expect(controller.appsSnapshotMessage, contains('has not reported'));
    expect(
      controller.appsSnapshotMessage,
      startsWith('This device has not reported'),
    );
    expect(controller.draftPayload.dailyScreenTimeLimitMinutes, 120);
  });

  test('shows enforced only after the device acknowledged the version', () async {
    final policy = DevicePolicy(
      id: 'policy-4',
      deviceId: 'device-1',
      version: 4,
      payload: const PolicyPayload(),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.enforced,
      acknowledgedAt: DateTime(2025, 1, 2),
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer(
      (_) async => [
        applyCommand(
          policyId: 'policy-4',
          result: const {
            'desired_count': 0,
            'applied_count': 0,
            'failed_count': 0,
            'enforcement_supported': true,
            'enforcement_mode': 'device_owner',
          },
        ),
      ],
    );
    when(() => deviceRepository.fetchReportedApps('device-1')).thenAnswer(
      (_) async => const [
        InstalledApp(
          packageName: 'com.instagram.android',
          label: 'Instagram',
        ),
      ],
    );

    await controller.load();

    expect(controller.currentStatus, PolicyEnforcementStatus.enforced);
    expect(controller.policyStateText, contains('enforced on the device'));
    expect(controller.appliedCountsText, 'Applied to 0 of 0 apps');
    expect(controller.appsSnapshotMessage, contains('1 installed apps'));
    expect(controller.instagramAvailable, isTrue);

    controller.selectInstagram();
    expect(controller.instagramBlocked, isTrue);
    expect(
      controller.draftPayload.blockedPackages,
      contains('com.instagram.android'),
    );
  });

  test('validates package names before adding a blocked app', () async {
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);

    await controller.load();

    final rejected = controller.addBlockedPackage('not a package');
    expect(rejected, isFalse);
    expect(controller.blockedRules, isEmpty);
    expect(controller.validationMessage.value, isNotEmpty);

    final accepted = controller.addBlockedPackage('com.example.game');
    expect(accepted, isTrue);
    expect(controller.validationMessage.value, isEmpty);
    expect(controller.isBlocked('com.example.game'), isTrue);
    expect(controller.blockedUnreportedPackages, contains('com.example.game'));
  });

  test('shows applied N of M only from the matching ack counters', () async {
    final policy = DevicePolicy(
      id: 'policy-4',
      deviceId: 'device-1',
      version: 4,
      payload: const PolicyPayload(
        blockedPackages: ['com.instagram.android'],
      ),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.enforced,
      acknowledgedAt: DateTime(2025, 1, 2),
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer(
      (_) async => [
        applyCommand(
          policyId: 'policy-4',
          result: const {
            'desired_count': 2,
            'applied_count': 2,
            'failed_count': 0,
            'enforcement_supported': true,
            'enforcement_mode': 'device_owner',
          },
        ),
      ],
    );

    await controller.load();

    expect(controller.appliedCountsText, 'Applied to 2 of 2 apps');
    expect(controller.enforcementProven, isTrue);
    expect(controller.enforcementUnsupported, isFalse);
    expect(controller.policyStateText, contains('Applied to 2 of 2 apps'));
  });

  test('reports unsupported when the ack says supported=false', () async {
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice(enforcementMode: 'none'));
    final policy = DevicePolicy(
      id: 'policy-5',
      deviceId: 'device-1',
      version: 5,
      payload: const PolicyPayload(
        blockedPackages: ['com.instagram.android'],
      ),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.unsupported,
      acknowledgedAt: DateTime(2025, 1, 2),
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer(
      (_) async => [
        applyCommand(
          policyId: 'policy-5',
          result: const {
            'desired_count': 3,
            'applied_count': 0,
            'failed_count': 3,
            'enforcement_supported': false,
            'enforcement_mode': 'none',
          },
        ),
      ],
    );

    await controller.load();

    expect(controller.enforcementUnsupported, isTrue);
    expect(controller.enforcementProven, isFalse);
    expect(controller.appliedCountsText, 'Applied to 0 of 3 apps');
    expect(controller.policyStateText, contains('cannot be enforced'));
  });

  test('a report from another policy version is never reused', () async {
    final policy = DevicePolicy(
      id: 'policy-6',
      deviceId: 'device-1',
      version: 6,
      payload: const PolicyPayload(
        blockedPackages: ['com.instagram.android'],
      ),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.pending,
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer(
      (_) async => [
        applyCommand(
          policyId: 'policy-5',
          result: const {
            'desired_count': 2,
            'applied_count': 2,
            'failed_count': 0,
            'enforcement_supported': true,
          },
        ),
      ],
    );

    await controller.load();

    expect(controller.appliedCountsText, isNull);
    expect(controller.enforcementProven, isFalse);
    expect(controller.awaitingAcknowledgement, isTrue);
  });
}
