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

  Device buildDevice() => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        policyVersion: 4,
      );

  DevicePolicy buildPolicy(
    PolicyEnforcementStatus status, {
    bool acknowledged = true,
  }) =>
      DevicePolicy(
        id: 'policy-4',
        deviceId: 'device-1',
        version: 4,
        payload: const PolicyPayload(blockedPackages: ['com.instagram.android']),
        createdAt: DateTime(2025, 1, 1),
        status: status,
        acknowledgedAt: acknowledged ? DateTime(2025, 1, 2) : null,
      );

  DeviceCommand command(Map<String, dynamic> payload, Map<String, dynamic> result) =>
      DeviceCommand(
        id: 'command-1',
        deviceId: 'device-1',
        type: DeviceCommandType.applyPolicy,
        payload: payload,
        status: DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        ackedAt: DateTime(2025, 1, 2),
        result: result,
      );

  const counts = <String, dynamic>{
    'desired_count': 2,
    'applied_count': 2,
    'failed_count': 0,
    'enforcement_supported': true,
    'enforcement_mode': 'device_owner',
  };

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
    when(() => devices.fetchDevice('device-1')).thenAnswer((_) async => buildDevice());
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
    await tester.pumpWidget(const GetMaterialApp(home: AppRestrictionsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('an uncorrelated report never earns the enforced badge', (tester) async {
    when(() => policies.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(PolicyEnforcementStatus.enforced));
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [command(<String, dynamic>{'version': 4}, counts)],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.text('Device report not linked to this policy'), findsOneWidget);
    // The device's own numbers stay readable — history is not hidden.
    expect(find.textContaining('Applied to 2 of 2 apps'), findsWidgets);
    // And the screen does not also claim the device reported no counts.
    expect(find.text('Enforcement not proven by counts'), findsNothing);
    expect(
      find.textContaining('does not name this policy'),
      findsOneWidget,
    );
  });

  testWidgets('a matched report still earns the enforced badge', (tester) async {
    when(() => policies.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(PolicyEnforcementStatus.enforced));
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        command(
          const <String, dynamic>{'policy_id': 'policy-4', 'version': 4},
          counts,
        ),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsOneWidget,
    );
    expect(find.text('Device report not linked to this policy'), findsNothing);
    expect(find.text('Unverified'), findsNothing);
  });

  testWidgets('an uncorrelated failure report keeps its list and honest wording',
      (tester) async {
    when(() => policies.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(PolicyEnforcementStatus.failed));
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        command(
          const <String, dynamic>{},
          const <String, dynamic>{
            'desired_count': 2,
            'applied_count': 0,
            'failed_count': 2,
            'enforcement_supported': true,
            'enforcement_mode': 'device_owner',
            'failures': [
              {
                'package': 'com.b',
                'reason': 'Could not confirm that com.b is suspended.',
              },
            ],
          },
        ),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('Apps the device could not confirm as suspended (2)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Could not confirm that com.b is suspended.'),
      findsOneWidget,
    );
    expect(find.text('Device report not linked to this policy'), findsOneWidget);
    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
  });

  testWidgets('a pending policy with only an uncorrelated report waits honestly',
      (tester) async {
    when(() => policies.fetchLatestPolicy('device-1')).thenAnswer(
      (_) async => buildPolicy(
        PolicyEnforcementStatus.pending,
        acknowledged: false,
      ),
    );
    when(() => policies.fetchRecentCommands('device-1', limit: 10)).thenAnswer(
      (_) async => [
        command(
          const <String, dynamic>{},
          const <String, dynamic>{
            'desired_count': 2,
            'applied_count': 2,
            'failed_count': 0,
            'enforcement_supported': true,
          },
        ),
      ],
    );

    await pumpPage(tester);

    expect(
      find.textContaining('Apps the device could not confirm as suspended'),
      findsNothing,
    );
    expect(
      find.textContaining('Policy v4 saved. Pending device acknowledgement'),
      findsOneWidget,
    );
    expect(
      find.textContaining('confirmed every selected app is suspended'),
      findsNothing,
    );
    final banners = tester
        .widgetList<InfoBanner>(find.byType(InfoBanner))
        .map((banner) => banner.title ?? '')
        .toList();
    expect(banners, contains('Pending device acknowledgement'));
    expect(banners, contains('Device report not linked to this policy'));
  });
}
