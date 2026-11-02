import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/widgets/widgets.dart';
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

  Device device({String enforcementMode = 'device_owner'}) => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: enforcementMode,
        policyVersion: 4,
      );

  DeviceCommand applyCommand(String policyId, Map<String, dynamic> result) =>
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
    devices = _MockDeviceRepository();
    policies = _MockPolicyRepository();
    controller = AppRestrictionsController(
      deviceId: 'device-1',
      deviceRepository: devices,
      policyRepository: policies,
      connectivity: ConnectivityService(),
    );
    addTearDown(controller.onClose);
    when(() => devices.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(controller);
    await tester.pumpWidget(
      const GetMaterialApp(home: AppRestrictionsPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('proven enforcement shows Applied to N of M apps', (tester) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device());
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => DevicePolicy(
        id: 'policy-4',
        deviceId: 'device-1',
        version: 4,
        payload: const PolicyPayload(
          blockedPackages: ['com.instagram.android'],
        ),
        createdAt: DateTime(2025, 1, 1),
        status: PolicyEnforcementStatus.enforced,
        acknowledgedAt: DateTime(2025, 1, 2),
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        applyCommand('policy-4', const {
          'desired_count': 2,
          'applied_count': 2,
          'failed_count': 0,
          'enforcement_supported': true,
          'enforcement_mode': 'device_owner',
        }),
      ],
    );

    await pumpPage(tester);

    expect(find.textContaining('Applied to 2 of 2 apps'), findsWidgets);
    expect(find.text('Unverified'), findsNothing);
    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsOneWidget,
    );
  });

  testWidgets('a queued command is never shown as a success banner',
      (tester) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device());
    when(() => policies.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);
    when(() => policies.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    await pumpPage(tester);
    controller.syncMessage.value =
        'The device will receive this at its next check-in.';
    await tester.pumpAndSettle();

    final banner = tester
        .widgetList<InfoBanner>(find.byType(InfoBanner))
        .where((b) => b.message.startsWith('The device will receive this'))
        .single;
    expect(banner.tone, BannerTone.info);
  });

  testWidgets('an enforced policy with no target apps is not a success',
      (tester) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device());
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => DevicePolicy(
        id: 'policy-4',
        deviceId: 'device-1',
        version: 4,
        payload: const PolicyPayload(),
        createdAt: DateTime(2025, 1, 1),
        status: PolicyEnforcementStatus.enforced,
        acknowledgedAt: DateTime(2025, 1, 2),
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        applyCommand('policy-4', const {
          'desired_count': 0,
          'applied_count': 0,
          'failed_count': 0,
          'enforcement_supported': true,
          'enforcement_mode': 'device_owner',
        }),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
    expect(find.textContaining('reported an empty app set'), findsOneWidget);
  });

  testWidgets('the unsupported banner quotes the count the device reported',
      (tester) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device());
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => DevicePolicy(
        id: 'policy-6',
        deviceId: 'device-1',
        version: 6,
        payload: const PolicyPayload(
          blockedPackages: ['com.instagram.android'],
        ),
        createdAt: DateTime(2025, 1, 1),
        status: PolicyEnforcementStatus.unsupported,
        acknowledgedAt: DateTime(2025, 1, 2),
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        applyCommand('policy-6', const {
          'desired_count': 3,
          'applied_count': 1,
          'enforcement_supported': false,
          'enforcement_mode': 'none',
        }),
      ],
    );

    await pumpPage(tester);

    // The number is the device's own, not a hardcoded zero.
    expect(find.textContaining('reported 1 applied apps'), findsOneWidget);
    expect(find.textContaining('reported 0 applied apps'), findsNothing);
  });

  testWidgets('unsupported enforcement shows the explicit banner', (
    tester,
  ) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device(enforcementMode: 'none'));
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => DevicePolicy(
        id: 'policy-5',
        deviceId: 'device-1',
        version: 5,
        payload: const PolicyPayload(
          blockedPackages: ['com.instagram.android'],
        ),
        createdAt: DateTime(2025, 1, 1),
        status: PolicyEnforcementStatus.unsupported,
        acknowledgedAt: DateTime(2025, 1, 2),
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        applyCommand('policy-5', const {
          'desired_count': 3,
          'applied_count': 0,
          'failed_count': 3,
          'enforcement_supported': false,
          'enforcement_mode': 'none',
        }),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('App blocking requires Device Owner'),
      findsWidgets,
    );
    expect(find.textContaining('Applied to 0 of 3 apps'), findsWidgets);
    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
  });

  testWidgets('a partial failure lists each app the device refused', (
    tester,
  ) async {
    when(() => devices.fetchDevice('device-1'))
        .thenAnswer((_) async => device());
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => DevicePolicy(
        id: 'policy-6',
        deviceId: 'device-1',
        version: 6,
        payload: const PolicyPayload(
          blockedPackages: ['com.a', 'com.b', 'com.c'],
        ),
        createdAt: DateTime(2025, 1, 1),
        status: PolicyEnforcementStatus.failed,
        acknowledgedAt: DateTime(2025, 1, 2),
        lastError: '2 of 3 packages could not be suspended',
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        applyCommand('policy-6', const {
          'desired_count': 3,
          'applied_count': 1,
          'failed_count': 2,
          'enforcement_supported': true,
          'enforcement_mode': 'device_owner',
          'failures': [
            {'package': 'com.b', 'reason': 'blocked by Android system policy'},
            {'package': 'com.c', 'reason': 'not installed'},
          ],
        }),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('Apps the device could not confirm as suspended (2)'),
      findsOneWidget,
    );
    expect(find.text('blocked by Android system policy'), findsOneWidget);
    expect(find.text('not installed'), findsOneWidget);
    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
  });
}