import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';
import 'package:parent_control/features/dashboard/parent_dashboard_tab.dart';
import 'package:parent_control/features/devices/device_presentation.dart';
import 'package:parent_control/features/devices/devices_controller.dart';
import 'package:parent_control/features/devices/parent_devices_tab.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

/// Phase 2 requires one presence vocabulary: the dashboard and the devices
/// list must describe the same device with the same words, derived only from
/// `Device.syncHealth` / `statusLabel` / `lastSeenAgeLabel`.
void main() {
  setUpAll(registerRepositoryFallbacks);

  final family = testFamily();
  final child = testMember(
    userId: 'child-1',
    role: FamilyMemberRole.child,
    displayName: 'Sam',
  );

  late _MockDeviceRepository devices;
  late _MockFamilyRepository families;
  late _MockPolicyRepository policies;
  late SessionService session;
  late ConnectivityService connectivity;

  Device deviceWith({DateTime? lastSeenAt}) => Device(
        id: 'device-1',
        familyId: family.id,
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        lastSeenAt: lastSeenAt,
        batteryLevel: 67,
        enforcementMode: 'device_owner',
        policyVersion: 3,
        usageAccessGranted: true,
      );

  setUp(() {
    devices = _MockDeviceRepository();
    families = _MockFamilyRepository();
    policies = _MockPolicyRepository();
    session = SessionService()..setActiveFamily(family);
    connectivity = ConnectivityService();
  });

  tearDown(Get.reset);

  void stubDevice(Device device) {
    when(() => families.fetchMyFamilies()).thenAnswer((_) async => [family]);
    when(() => families.fetchMembers(family.id))
        .thenAnswer((_) async => [child]);
    when(() => devices.fetchDevices(family.id))
        .thenAnswer((_) async => [device]);
    when(() => policies.fetchLatestPolicy(device.id))
        .thenAnswer((_) async => null);
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    final controller = DashboardController(
      deviceRepository: devices,
      familyRepository: families,
      policyRepository: policies,
      session: session,
      connectivity: connectivity,
      refreshInterval: null,
    );
    Get.put(connectivity);
    Get.put(controller);
    await tester.pumpWidget(const GetMaterialApp(home: ParentDashboardTab()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpDevicesTab(WidgetTester tester) async {
    final controller = DevicesController(
      deviceRepository: devices,
      familyRepository: families,
      session: session,
      connectivity: connectivity,
      refreshInterval: null,
    );
    Get.put(connectivity);
    Get.put(controller);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ParentDevicesTab())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  const states = <String, Duration?>{
    'healthy': Duration(minutes: 2),
    'stalled': Duration(minutes: 14),
    'offline': Duration(minutes: 45),
    'never synced': null,
  };

  for (final entry in states.entries) {
    testWidgets('${entry.key}: dashboard and devices list agree',
        (tester) async {
      final age = entry.value;
      final device = deviceWith(
        lastSeenAt: age == null ? null : DateTime.now().subtract(age),
      );
      stubDevice(device);

      await pumpDashboard(tester);
      expect(find.text(device.statusLabel), findsWidgets);
      if (age != null) {
        expect(find.textContaining(device.lastSeenAgeLabel), findsOneWidget);
      }
      final dashboardLabel = device.statusLabel;
      Get.reset();

      await pumpDevicesTab(tester);
      expect(find.text(dashboardLabel), findsWidgets);
      if (age != null) {
        expect(find.textContaining(device.lastSeenAgeLabel), findsOneWidget);
      }
    });
  }

  testWidgets('a stalled device is never called online on either screen',
      (tester) async {
    stubDevice(deviceWith(lastSeenAt: DateTime.now().subtract(
      const Duration(minutes: 14),
    )));

    await pumpDashboard(tester);
    expect(find.textContaining('Online'), findsNothing);
    Get.reset();

    await pumpDevicesTab(tester);
    expect(find.textContaining('Online'), findsNothing);
  });

  test('the shared chip keeps an unenrolled or revoked device non-green', () {
    StatusTone toneOf(Device device) => presenceTone(device);

    expect(toneOf(deviceWith(lastSeenAt: DateTime.now())), StatusTone.success);
    expect(
      toneOf(
        Device(
          id: 'device-2',
          familyId: family.id,
          childUserId: 'child-1',
          displayName: 'Pixel 8',
          status: DeviceStatus.pending,
          lastSeenAt: DateTime.now(),
        ),
      ),
      StatusTone.warning,
    );
    expect(
      toneOf(
        Device(
          id: 'device-3',
          familyId: family.id,
          childUserId: 'child-1',
          displayName: 'Pixel 8',
          status: DeviceStatus.revoked,
          lastSeenAt: DateTime.now(),
        ),
      ),
      StatusTone.danger,
    );
  });

  // The child's own home tab used to derive its presence colour from a private
  // copy of the rule, which drifted from the parent screens. Reading the source
  // is the cheapest way to keep a fourth copy from reappearing; the handlers in
  // supabase/functions/handler_wiring_test.ts use the same technique.
  test('the child home tab shows the shared chip, not its own rule', () {
    final source = File(
      'lib/features/child/tabs/child_home_tab.dart',
    ).readAsStringSync();

    expect(source, contains('trailing: presenceChip(current)'));
    expect(source, isNot(contains('_deviceTone')));
  });
}
