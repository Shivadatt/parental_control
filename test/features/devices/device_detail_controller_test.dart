import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/devices/device_detail_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockPolicyRepository policyRepository;
  late ConnectivityService connectivity;

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    connectivity = ConnectivityService();
  });

  Device buildDevice({required DateTime lastSeen, String enforcement = 'device_admin'}) =>
      Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        lastSeenAt: lastSeen,
        batteryLevel: 42,
        isCharging: true,
        enforcementMode: enforcement,
        policyVersion: 4,
        usageAccessGranted: false,
        locationGranted: true,
        notificationsGranted: false,
      );

  test('presents an offline device honestly and flags unsupported suspension',
      () async {
    final device = buildDevice(
      lastSeen: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final policy = DevicePolicy(
      id: 'policy-4',
      deviceId: device.id,
      version: 4,
      payload: const PolicyPayload(),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.pending,
    );
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => device);
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    final controller = DeviceDetailController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.isDeviceOffline, isTrue);
    expect(controller.device.value!.statusLabel, 'Offline');
    expect(controller.suspensionUnsupported, isTrue);
    expect(controller.awaitingAcknowledgement, isTrue);
    expect(controller.policySummaryText, contains('Waiting for device'));
    expect(controller.recentCommands, isEmpty);
  });

  test('revoke succeeds only after the server confirms', () async {
    when(() => deviceRepository.revokeDevice('device-1'))
        .thenAnswer((_) async {});

    final controller = DeviceDetailController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    final revoked = await controller.revokeDevice();

    expect(revoked, isTrue);
    expect(controller.revokeError.value, isNull);
    verify(() => deviceRepository.revokeDevice('device-1')).called(1);
  });

  test('revoke reports a server failure and keeps the device visible', () async {
    when(() => deviceRepository.revokeDevice('device-1'))
        .thenThrow(const AppException(AppErrorCodes.forbidden, 'Not allowed'));

    final controller = DeviceDetailController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    final revoked = await controller.revokeDevice();

    expect(revoked, isFalse);
    expect(controller.revokeError.value?.code, AppErrorCodes.forbidden);
  });

  test('recovery is reported only after the server confirms it', () async {
    final device = buildDevice(lastSeen: DateTime.now());
    when(() => deviceRepository.recoverDevice('device-1'))
        .thenAnswer((_) async {});
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => device);
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    final controller = DeviceDetailController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    final started = await controller.recoverDevice();

    expect(started, isTrue);
    expect(controller.recoveryStarted.value, isTrue);
    expect(controller.recoveryError.value, isNull);
    verify(() => deviceRepository.recoverDevice('device-1')).called(1);
  });

  test('recovery does not claim success when the server rejects it', () async {
    when(() => deviceRepository.recoverDevice('device-1')).thenThrow(
      const AppException(AppErrorCodes.forbidden, 'A parent is required'),
    );

    final controller = DeviceDetailController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    final started = await controller.recoverDevice();

    expect(started, isFalse);
    expect(controller.recoveryStarted.value, isFalse);
    expect(controller.recoveryError.value?.code, AppErrorCodes.forbidden);
    verifyNever(() => deviceRepository.fetchDevice('device-1'));
  });
}
