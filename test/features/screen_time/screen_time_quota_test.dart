import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
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

  Device buildDevice({bool? usageAccess = true}) => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        usageAccessGranted: usageAccess,
      );

  DevicePolicy buildPolicy({
    int? limitMinutes,
    PolicyEnforcementStatus status = PolicyEnforcementStatus.enforced,
    String? lastError,
  }) =>
      DevicePolicy(
        id: 'policy-1',
        deviceId: 'device-1',
        version: 7,
        payload: PolicyPayload(dailyScreenTimeLimitMinutes: limitMinutes),
        createdAt: DateTime(2025, 1, 1),
        status: status,
        acknowledgedAt: DateTime(2025, 1, 2),
        lastError: lastError,
      );

  UsageDaily buildEntry({required int minutes}) => UsageDaily(
        deviceId: 'device-1',
        day: DateTime.now(),
        packageName: 'com.google.android.youtube',
        appLabel: 'YouTube',
        totalMs: minutes * 60000,
      );

  Future<void> loadWith({
    Device? device,
    DevicePolicy? policy,
    List<UsageDaily>? entries,
    Object? usageFailure,
  }) async {
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => device ?? buildDevice());
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => policy);
    if (usageFailure != null) {
      when(() => usageRepository.fetchUsage(
            deviceId: 'device-1',
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenThrow(usageFailure);
    } else {
      when(() => usageRepository.fetchUsage(
            deviceId: 'device-1',
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenAnswer((_) async => entries ?? const <UsageDaily>[]);
    }
    when(() => usageRepository.fetchLastUpload('device-1'))
        .thenAnswer((_) async => null);
    await controller.load();
  }

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    usageRepository = _MockUsageRepository();
    connectivity = ConnectivityService();
    controller = ScreenTimeController(
      deviceId: 'device-1',
      usageRepository: usageRepository,
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: connectivity,
    );
    addTearDown(controller.onClose);
  });

  group('remaining time on the screen-time surface', () {
    test('reports the difference between the limit and today', () async {
      await loadWith(
        policy: buildPolicy(limitMinutes: 90),
        entries: [buildEntry(minutes: 30)],
      );
      expect(controller.dailyLimitMinutes.value, 90);
      expect(controller.todayTotalMinutes, 30);
      expect(controller.remainingMinutesToday, 60);
      expect(controller.remainingTimeText, '1h');
      expect(controller.limitReachedText, 'Not reached');
    });

    test('exactly at the limit is zero remaining and reached', () async {
      await loadWith(
        policy: buildPolicy(limitMinutes: 60),
        entries: [buildEntry(minutes: 60)],
      );
      expect(controller.remainingMinutesToday, 0);
      expect(controller.limitReachedToday, isTrue);
      expect(controller.limitReachedText, 'Reached');
    });

    test('past the limit never goes negative', () async {
      await loadWith(
        policy: buildPolicy(limitMinutes: 60),
        entries: [buildEntry(minutes: 300)],
      );
      expect(controller.remainingMinutesToday, 0);
      expect(controller.remainingTimeText, '0 min');
    });

    test('no limit configured is stated, not counted down from nothing',
        () async {
      await loadWith(policy: buildPolicy(limitMinutes: null), entries: const []);
      expect(controller.hasLimit, isFalse);
      expect(controller.remainingMinutesToday, isNull);
      expect(controller.remainingTimeText, 'No daily limit set');
      expect(controller.limitReachedText, 'No limit to reach');
    });

    test('a zero limit stored on the policy reads as no limit', () async {
      await loadWith(policy: buildPolicy(limitMinutes: 0), entries: const []);
      expect(controller.configuredDailyLimit, isNull);
      expect(controller.hasLimit, isFalse);
      expect(controller.remainingTimeText, 'No daily limit set');
    });

    test('an out-of-range limit reads as no limit', () async {
      await loadWith(policy: buildPolicy(limitMinutes: 1441), entries: const []);
      expect(controller.configuredDailyLimit, isNull);
      expect(controller.hasLimit, isFalse);
    });
  });

  group('unavailable usage renders as unknown', () {
    test('usage access denied does not become zero used', () async {
      await loadWith(
        device: buildDevice(usageAccess: false),
        policy: buildPolicy(limitMinutes: 90),
        entries: const [],
      );
      expect(controller.usageKnownToday, isFalse);
      expect(controller.remainingMinutesToday, isNull);
      expect(
        controller.remainingTimeText,
        'Unknown — the device has not reported usage yet',
      );
      expect(
        controller.limitReachedText,
        'Unknown — the device has not reported usage yet',
      );
    });

    test('an unreported usage access state is not a usage reading', () async {
      await loadWith(
        device: buildDevice(usageAccess: null),
        policy: buildPolicy(limitMinutes: 90),
        entries: const [],
      );
      expect(controller.usageKnownToday, isFalse);
      expect(controller.remainingTimeText, contains('Unknown'));
    });

    test('a failed usage read is not presented as zero used', () async {
      await loadWith(
        policy: buildPolicy(limitMinutes: 90),
        usageFailure: AppException.network(),
      );
      expect(controller.usageKnownToday, isFalse);
      expect(controller.remainingMinutesToday, isNull);
      expect(controller.remainingTimeText, contains('Unknown'));
    });
  });

  group('setting a limit only accepts 1..1440', () {
    test('zero clears the limit instead of storing a ban', () {
      controller.setDailyLimit(0);
      expect(controller.dailyLimitMinutes.value, isNull);
      controller.setDailyLimit(-30);
      expect(controller.dailyLimitMinutes.value, isNull);
    });

    test('the day boundary is kept and anything above is clamped', () {
      controller.setDailyLimit(1440);
      expect(controller.dailyLimitMinutes.value, 1440);
      controller.setDailyLimit(2000);
      expect(controller.dailyLimitMinutes.value, 1440);
    });

    test('decreasing below one minute removes the limit', () {
      controller.setDailyLimit(10);
      controller.adjustDailyLimit(-15);
      expect(controller.dailyLimitMinutes.value, isNull);
      expect(controller.hasLimit, isFalse);
    });

    test('the draft never writes a zero limit back to the policy', () async {
      controller.clearDailyLimit();
      expect(controller.draftPayload.dailyScreenTimeLimitMinutes, isNull);
      controller.setDailyLimit(45);
      expect(controller.draftPayload.dailyScreenTimeLimitMinutes, 45);
    });
  });

  group('the device reason is human-readable on the screen-time surface', () {
    test('a quota token is mapped, not printed raw', () async {
      await loadWith(
        policy: buildPolicy(
          limitMinutes: 90,
          status: PolicyEnforcementStatus.failed,
          lastError: 'quota_suspend_failed',
        ),
        entries: const [],
      );
      expect(controller.policyStateText, contains('could not block apps'));
      expect(controller.policyStateText, isNot(contains('quota_suspend_failed')));
    });

    test('the pre-T-B-02 unverified token is mapped', () async {
      await loadWith(
        policy: buildPolicy(
          limitMinutes: 90,
          status: PolicyEnforcementStatus.failed,
          lastError: 'limits_enforcement_unverified',
        ),
        entries: const [],
      );
      expect(controller.policyStateText, contains('not verified'));
    });

    test('an unknown reason stays visible', () async {
      await loadWith(
        policy: buildPolicy(
          limitMinutes: 90,
          status: PolicyEnforcementStatus.failed,
          lastError: 'reason_from_a_newer_device',
        ),
        entries: const [],
      );
      expect(
        controller.policyStateText,
        contains('reason_from_a_newer_device'),
      );
    });

    test('no reason at all keeps the honest short sentence', () async {
      await loadWith(
        policy: buildPolicy(
          limitMinutes: 90,
          status: PolicyEnforcementStatus.failed,
          lastError: null,
        ),
        entries: const [],
      );
      expect(controller.policyStateText, 'Policy v7 failed on the device.');
    });
  });
}
