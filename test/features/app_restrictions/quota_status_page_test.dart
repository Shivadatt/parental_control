import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_page.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository devices;
  late _MockPolicyRepository policies;
  late AppRestrictionsController controller;

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
    PolicyEnforcementStatus status = PolicyEnforcementStatus.enforced,
    String? lastError,
  }) =>
      DevicePolicy(
        id: 'policy-4',
        deviceId: 'device-1',
        version: 4,
        payload: const PolicyPayload(dailyScreenTimeLimitMinutes: 90),
        createdAt: DateTime(2025, 1, 1),
        status: status,
        acknowledgedAt: DateTime(2025, 1, 2),
        lastError: lastError,
      );

  DeviceCommand applyCommand(Map<String, dynamic> result) => DeviceCommand(
        id: 'command-1',
        deviceId: 'device-1',
        type: DeviceCommandType.applyPolicy,
        payload: const {'policy_id': 'policy-4', 'version': 4},
        status: DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        ackedAt: DateTime(2025, 1, 2),
        result: result,
      );

  setUp(() {
    devices = _MockDeviceRepository();
    policies = _MockPolicyRepository();
    controller = AppRestrictionsController(
      deviceId: 'device-1',
      deviceRepository: devices,
      policyRepository: policies,
      connectivity: ConnectivityService(),
    );
    addTearDown(controller.onClose);
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice());
    when(() => devices.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
    when(() => policies.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy());
  });

  tearDown(Get.reset);

  Future<void> pumpWithResult(
    WidgetTester tester,
    Map<String, dynamic> result,
  ) async {
    when(() => policies.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [applyCommand(result)]);
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(controller);
    await tester.pumpWidget(const GetMaterialApp(home: AppRestrictionsPage()));
    await tester.pumpAndSettle();
  }

  const appCounts = <String, dynamic>{
    'desired_count': 2,
    'applied_count': 2,
    'failed_count': 0,
    'enforcement_supported': true,
    'enforcement_mode': 'device_owner',
  };

  testWidgets('the device-reported quota panel shows every quota field',
      (tester) async {
    await pumpWithResult(tester, {
      ...appCounts,
      'quota': {
        'configured': true,
        'usage_available': true,
        'usage_minutes': 30,
        'limit_minutes': 90,
        'day_bucket': '2026-11-06',
        'limit_reached': false,
        'action': 'none',
        'desired_count': 0,
        'applied_count': 0,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'reason': 'quota_below_limit',
      },
    });

    expect(find.text('Daily limit as the device reported it'), findsOneWidget);
    expect(find.text('Used in the device day'), findsOneWidget);
    expect(find.textContaining('30 min (2026-11-06)'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.text('Not reached'), findsOneWidget);
    expect(find.text('Fully managed (Device Owner)'), findsOneWidget);
    expect(find.textContaining('below the daily limit'), findsOneWidget);
  });

  testWidgets('remaining is zero, never negative, past the limit',
      (tester) async {
    await pumpWithResult(tester, {
      ...appCounts,
      'quota': {
        'configured': true,
        'usage_available': true,
        'usage_minutes': 120,
        'limit_minutes': 90,
        'limit_reached': true,
        'action': 'suspended',
        'desired_count': 4,
        'applied_count': 4,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'reason': 'quota_suspended 4 of 4',
      },
    });

    expect(find.text('0 min'), findsOneWidget);
    expect(find.text('Reached'), findsOneWidget);
    expect(find.text('Apps suspended at the limit'), findsOneWidget);
    expect(find.textContaining('blocked 4 of 4 apps'), findsOneWidget);
  });

  testWidgets('unavailable usage reads as unknown, not as a full allowance',
      (tester) async {
    await pumpWithResult(tester, {
      ...appCounts,
      'quota': {
        'configured': true,
        'usage_available': false,
        'usage_minutes': null,
        'limit_minutes': 90,
        'limit_reached': false,
        'action': 'none',
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'reason': 'quota_usage_unavailable',
      },
    });

    expect(find.text('Usage unavailable on the device'), findsOneWidget);
    expect(
      find.textContaining('Unknown — the device reported no limit or no usage'),
      findsOneWidget,
    );
    expect(find.text('90 min'), findsNothing);
  });

  testWidgets('a zero limit never reads as a total ban', (tester) async {
    await pumpWithResult(tester, {
      ...appCounts,
      'quota': {
        'configured': true,
        'usage_available': true,
        'usage_minutes': 10,
        'limit_minutes': 0,
        'limit_reached': false,
        'action': 'none',
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'reason': 'quota_not_configured',
      },
    });

    expect(find.text('No daily limit configured'), findsOneWidget);
    expect(find.text('90 min'), findsNothing);
    expect(find.textContaining('The device has no active daily screen-time limit'),
        findsOneWidget);
  });

  testWidgets('an ack with no quota object keeps the pre-T-B-02 surface',
      (tester) async {
    await pumpWithResult(tester, appCounts);

    expect(find.text('Daily limit as the device reported it'), findsNothing);
    expect(find.text('Used in the device day'), findsNothing);
    // The app counters still render exactly as before.
    expect(find.textContaining('Applied to 2 of 2 apps'), findsWidgets);
  });

  testWidgets('a failed policy shows the mapped reason, not the raw token',
      (tester) async {
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => buildPolicy(
        status: PolicyEnforcementStatus.failed,
        lastError: 'quota_advisory_only',
      ),
    );
    await pumpWithResult(tester, appCounts);

    expect(find.text('Enforcement failed'), findsWidgets);
    expect(find.textContaining('advisory on this device'), findsWidgets);
    expect(find.textContaining('quota_advisory_only'), findsNothing);
  });

  testWidgets('an unknown device reason is still displayed', (tester) async {
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => buildPolicy(
        status: PolicyEnforcementStatus.failed,
        lastError: 'brand_new_reason_from_the_device',
      ),
    );
    await pumpWithResult(tester, appCounts);

    expect(
      find.textContaining('brand_new_reason_from_the_device'),
      findsWidgets,
    );
  });
}
