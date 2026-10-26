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

  Device buildDevice() => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        policyVersion: 3,
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
}
