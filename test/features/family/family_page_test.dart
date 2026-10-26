import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
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

    final controller = FamilyController(
      familyRepository: families,
      pairingRepository: pairing,
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

    // Unmount the page before Get.reset() disposes the controller's Rx state.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
