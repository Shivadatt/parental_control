import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/screen_time/screen_time_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

class _MockUsageRepository extends Mock implements UsageRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockPolicyRepository policyRepository;
  late _MockUsageRepository usageRepository;
  late ConnectivityService connectivity;
  late ScreenTimeController controller;

  setUpAll(() => registerFallbackValue(DateTime(2024, 1, 1)));

  Device buildDevice({required bool usageAccess}) => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        usageAccessGranted: usageAccess,
      );

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    usageRepository = _MockUsageRepository();
    connectivity = ConnectivityService();
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);
  });

  test('flags stale usage from the last upload timestamp', () async {
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice(usageAccess: true));
    final entry = UsageDaily(
      deviceId: 'device-1',
      day: DateTime.now(),
      packageName: 'com.google.android.youtube',
      appLabel: 'YouTube',
      totalMs: 3600000,
    );
    when(
      () => usageRepository.fetchUsage(
        deviceId: 'device-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => [entry]);
    when(() => usageRepository.fetchLastUpload('device-1')).thenAnswer(
      (_) async => DateTime.now().subtract(const Duration(hours: 30)),
    );

    controller = ScreenTimeController(
      deviceId: 'device-1',
      usageRepository: usageRepository,
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.usageAccessDenied, isFalse);
    expect(controller.hasUsageData, isTrue);
    expect(controller.isUploadStale, isTrue);
    expect(controller.todayTotalMs, 3600000);
    expect(controller.weekTotalMs, 3600000);
    expect(controller.appBreakdown, hasLength(1));
    expect(controller.appBreakdown.first.label, 'YouTube');
  });

  test('does not fetch or show numbers when Usage Access is denied', () async {
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice(usageAccess: false));

    controller = ScreenTimeController(
      deviceId: 'device-1',
      usageRepository: usageRepository,
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    await controller.load();

    expect(controller.usageAccessDenied, isTrue);
    expect(controller.entries, isEmpty);
    expect(controller.usageError.value, isNull);
    expect(controller.usagePermissionText, contains('Usage Access'));
    verifyNever(
      () => usageRepository.fetchUsage(
        deviceId: any(named: 'deviceId'),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    );
    verifyNever(() => usageRepository.fetchLastUpload(any()));
  });

  test('presents pending then acknowledged policy states', () async {
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice(usageAccess: true));
    when(
      () => usageRepository.fetchUsage(
        deviceId: 'device-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => const <UsageDaily>[]);
    when(() => usageRepository.fetchLastUpload('device-1'))
        .thenAnswer((_) async => null);
    final pending = DevicePolicy(
      id: 'policy-1',
      deviceId: 'device-1',
      version: 1,
      payload: const PolicyPayload(dailyScreenTimeLimitMinutes: 90),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.pending,
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => pending);

    controller = ScreenTimeController(
      deviceId: 'device-1',
      usageRepository: usageRepository,
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);

    await controller.load();
    expect(controller.awaitingAcknowledgement, isTrue);
    expect(controller.policyStateText, contains('Pending device acknowledgement'));
    expect(controller.dailyLimitMinutes.value, 90);

    final enforced = DevicePolicy(
      id: 'policy-1',
      deviceId: 'device-1',
      version: 1,
      payload: const PolicyPayload(dailyScreenTimeLimitMinutes: 90),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.enforced,
      acknowledgedAt: DateTime(2025, 1, 2),
    );
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => enforced);
    await controller.refresh();

    expect(controller.awaitingAcknowledgement, isFalse);
    expect(controller.policyStateText, contains('acknowledged by the device'));
  });
}
