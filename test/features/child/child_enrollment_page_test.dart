import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/child_enrollment_page.dart';
import 'package:parent_control/features/child/controllers/child_enrollment_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockDeviceAdminService extends Mock implements DeviceAdminService {}

void main() {
  setUpAll(registerRepositoryFallbacks);

  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late _MockDeviceRepository devices;
  late MockLocalSettingsService settings;
  late SessionService session;
  late ConnectivityService connectivity;
  late ChildEnrollmentController controller;
  late _MockDeviceAdminService deviceAdmin;

  setUp(() {
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
    devices = _MockDeviceRepository();
    settings = MockLocalSettingsService();
    session = SessionService()
      ..setAuthenticated(
        id: 'child-1',
        address: 'mia@example.com',
        verified: true,
      );
    connectivity = ConnectivityService();
    deviceAdmin = _MockDeviceAdminService();

    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(() => settings.cachedChildContactId(any())).thenReturn(null);
    when(() => settings.setCachedChildContactId(any(), any()))
        .thenAnswer((_) async {});
    when(() => settings.clearCachedChildContactId(any()))
        .thenAnswer((_) async {});
    when(() => families.fetchMyMembership()).thenAnswer((_) async => null);
    when(() => devices.fetchMyDevice()).thenAnswer((_) async => null);
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => const <PairingRequest>[]);

    controller = ChildEnrollmentController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      settings: settings,
      connectivity: connectivity,
      deviceAdmin: deviceAdmin,
    );
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    Get.put(connectivity);
    Get.put(controller);
    await tester.pumpWidget(const GetMaterialApp(home: ChildEnrollmentPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The controller polls every 15s; stop it before the test ends so the
    // framework does not report a pending timer.
    controller.onClose();
  }

  testWidgets('shows the permanent Child ID and the status line', (
    tester,
  ) async {
    when(() => pairing.fetchChildContactId())
        .thenAnswer((_) async => testChildContactId());

    await pumpPage(tester);

    expect(find.text('Your Child ID'), findsOneWidget);
    expect(find.text('PC-7K4M2QRX'), findsOneWidget);
    expect(find.text('Status: Not linked to a parent'), findsOneWidget);
    expect(find.text('Copy ID'), findsOneWidget);
    expect(find.text('Show QR'), findsOneWidget);
    expect(find.text('Check for requests'), findsOneWidget);
    expect(find.text('Create linking code'), findsNothing);

    await disposePage(tester);
  });

  testWidgets('Show QR renders the server payload and can be hidden', (
    tester,
  ) async {
    when(() => pairing.fetchChildContactId())
        .thenAnswer((_) async => testChildContactId());

    await pumpPage(tester);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Show QR'));
    await tester.pump();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, 196);
    expect(find.text('Hide QR'), findsOneWidget);

    await tester.tap(find.text('Hide QR'));
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);

    await disposePage(tester);
  });

  testWidgets('offline with no cached ID offers a retry, not a generated code', (
    tester,
  ) async {
    connectivity.isOnline.value = false;

    await pumpPage(tester);

    expect(find.text('Create linking code'), findsNothing);
    expect(find.textContaining('network is unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await disposePage(tester);
  });
}
