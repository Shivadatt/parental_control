import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/family/controllers/family_controller.dart';
import 'package:parent_control/features/family/family_page.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(registerRepositoryFallbacks);

  testWidgets('family page shows the empty children state from server data',
      (tester) async {
    final families = MockFamilyRepository();
    final pairing = MockPairingRepository();
    final devices = MockDeviceRepository();
    final session = SessionService();
    session.setAuthenticated(
      id: 'user-1',
      address: 'alex@example.com',
      verified: true,
    );
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => const <Device>[]);
    when(() => pairing.fetchForFamily('family-1'))
        .thenAnswer((_) async => const <PairingRequest>[]);

    final controller = FamilyController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      connectivity: ConnectivityService(),
    );
    await controller.start('family-1');

    Get.put(ConnectivityService());
    Get.put(controller);
    addTearDown(Get.reset);

    await tester.pumpWidget(const GetMaterialApp(home: FamilyPage()));
    await tester.pump();

    expect(find.text('No children linked yet'), findsOneWidget);
    expect(find.text('Test Family'), findsWidgets);
    expect(find.text('Link a child'), findsWidgets);
    expect(
      find.text('No device has completed pairing in this family yet.'),
      findsOneWidget,
    );
    expect(
      find.text('No pairing request is waiting for a child to approve.'),
      findsOneWidget,
    );

    // Unmount the page before Get.reset() disposes the controller's Rx state.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('family page shows per-device health and pending pairing counts',
      (tester) async {
    final families = MockFamilyRepository();
    final pairing = MockPairingRepository();
    final devices = MockDeviceRepository();
    final session = SessionService();
    session.setAuthenticated(
      id: 'user-1',
      address: 'alex@example.com',
      verified: true,
    );
    final stalled = testDevice(
      displayName: 'Sam phone',
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 14)),
    );
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => [stalled]);
    when(() => pairing.fetchForFamily('family-1'))
        .thenAnswer((_) async => [testPairingRequest()]);

    final controller = FamilyController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      connectivity: ConnectivityService(),
    );
    await controller.start('family-1');

    Get.put(ConnectivityService());
    Get.put(controller);
    addTearDown(Get.reset);

    await tester.pumpWidget(const GetMaterialApp(home: FamilyPage()));
    await tester.pump();

    expect(find.text('Linked devices'), findsOneWidget);
    expect(find.text('Sam phone'), findsOneWidget);
    // The family page uses the shared presence label; it never invents one.
    expect(find.text('Sync stalled'), findsOneWidget);
    expect(find.textContaining('last seen 14 min ago'), findsOneWidget);
    expect(find.textContaining('Online'), findsNothing);
    expect(find.text('Pending pairing'), findsOneWidget);
    expect(find.textContaining('Waiting for child approval'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a device load failure is retryable and never blanks the family',
      (tester) async {
    final families = MockFamilyRepository();
    final pairing = MockPairingRepository();
    final devices = MockDeviceRepository();
    final session = SessionService();
    session.setAuthenticated(
      id: 'user-1',
      address: 'alex@example.com',
      verified: true,
    );
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1')).thenThrow(
      const AppException(AppErrorCodes.network, 'Devices could not be loaded'),
    );
    when(() => pairing.fetchForFamily('family-1'))
        .thenAnswer((_) async => const <PairingRequest>[]);

    final controller = FamilyController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      connectivity: ConnectivityService(),
    );
    await controller.start('family-1');

    Get.put(ConnectivityService());
    Get.put(controller);
    addTearDown(Get.reset);

    await tester.pumpWidget(const GetMaterialApp(home: FamilyPage()));
    await tester.pump();

    expect(find.text('Test Family'), findsWidgets);
    expect(find.text('Could not load devices'), findsOneWidget);
    final banner = find.ancestor(
      of: find.text('Could not load devices'),
      matching: find.byType(InfoBanner),
    );
    expect(find.descendant(of: banner, matching: find.text('Retry')),
        findsOneWidget);

    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => [testDevice(displayName: 'Sam phone')]);
    final retryButton = find.descendant(
      of: banner,
      matching: find.text('Retry'),
    );
    await tester.ensureVisible(retryButton);
    await tester.pump();
    await tester.tap(retryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not load devices'), findsNothing);
    expect(find.text('Sam phone'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
