import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';
import 'package:parent_control/features/dashboard/parent_dashboard_tab.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  setUpAll(registerRepositoryFallbacks);

  late _MockDeviceRepository devices;
  late _MockFamilyRepository families;
  late _MockPolicyRepository policies;
  late SessionService session;
  late ConnectivityService connectivity;

  final family = testFamily();
  final child = testMember(
    userId: 'child-1',
    role: FamilyMemberRole.child,
    displayName: 'Sam',
  );

  Device deviceSeenAgo(Duration age) => Device(
        id: 'device-1',
        familyId: family.id,
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        lastSeenAt: DateTime.now().subtract(age),
        batteryLevel: 67,
        isCharging: false,
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

  Future<DashboardController> pumpDashboard(
    WidgetTester tester,
    Device device,
  ) async {
    when(() => families.fetchMembers(family.id))
        .thenAnswer((_) async => [child]);
    when(() => devices.fetchDevices(family.id))
        .thenAnswer((_) async => [device]);
    when(() => policies.fetchLatestPolicy(device.id))
        .thenAnswer((_) async => null);

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
    await tester.pumpWidget(
      const GetMaterialApp(home: ParentDashboardTab()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  testWidgets('a stalled device renders the stalled copy, never plain Online',
      (tester) async {
    await pumpDashboard(
      tester,
      deviceSeenAgo(const Duration(minutes: 14)),
    );

    expect(find.text('Online (sync stalled)'), findsOneWidget);
    expect(find.text('Sync stalled'), findsOneWidget);
    expect(find.textContaining('last seen 14 min ago'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('a healthy device shows its heartbeat age', (tester) async {
    await pumpDashboard(
      tester,
      deviceSeenAgo(const Duration(minutes: 2)),
    );

    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('synced 2 min ago'), findsOneWidget);
    expect(find.text('Sync stalled'), findsNothing);
  });
}
