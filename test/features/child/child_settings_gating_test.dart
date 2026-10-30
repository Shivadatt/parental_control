import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/services/child_preferences.dart';
import 'package:parent_control/features/child/tabs/child_settings_tab.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _MockDeviceAdminService extends Mock implements DeviceAdminService {}

class _MockChildPreferences extends Mock implements ChildPreferences {}

/// A real [ChildShellController] with inert dependencies. `onInit` is skipped
/// so the widget test only exercises the tab's rendering/gating, and state is
/// set explicitly instead of loading a server.
class _StubShellController extends ChildShellController {
  _StubShellController({
    required MockFamilyRepository families,
    required MockPairingRepository pairing,
    required _MockDeviceRepository devices,
    required _MockRemoteSessionRepository sessions,
    required _MockPolicyRepository policies,
    required MockAuthRepository auth,
    required super.session,
    required MockLocalSettingsService localSettings,
    required super.connectivity,
    required _MockDeviceAdminService deviceAdmin,
    required _MockChildPreferences preferences,
  }) : super(
          familyRepository: families,
          pairingRepository: pairing,
          deviceRepository: devices,
          remoteSessionRepository: sessions,
          policyRepository: policies,
          authRepository: auth,
          localSettings: localSettings,
          deviceAdmin: deviceAdmin,
          preferences: preferences,
        );

  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late _MockDeviceRepository devices;
  late _MockRemoteSessionRepository sessions;
  late _MockPolicyRepository policies;
  late MockAuthRepository auth;
  late MockLocalSettingsService localSettings;
  late SessionService session;
  late ConnectivityService connectivity;
  late _MockDeviceAdminService deviceAdmin;
  late _MockChildPreferences preferences;
  late _StubShellController controller;

  setUpAll(registerRepositoryFallbacks);

  setUp(() {
    Get.testMode = true;
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
    devices = _MockDeviceRepository();
    sessions = _MockRemoteSessionRepository();
    policies = _MockPolicyRepository();
    auth = MockAuthRepository();
    localSettings = MockLocalSettingsService();
    session = SessionService();
    connectivity = ConnectivityService();
    deviceAdmin = _MockDeviceAdminService();
    preferences = _MockChildPreferences();

    when(() => deviceAdmin.isAvailable).thenReturn(true);
    controller = _StubShellController(
      families: families,
      pairing: pairing,
      devices: devices,
      sessions: sessions,
      policies: policies,
      auth: auth,
      session: session,
      localSettings: localSettings,
      connectivity: connectivity,
      deviceAdmin: deviceAdmin,
      preferences: preferences,
    );
    controller.isLoading.value = false;
    controller.capabilities.value = const DeviceCapabilities(
      available: true,
      isAdminActive: true,
      manufacturer: 'realme',
      model: 'RMX2161',
      androidVersion: '12',
      appVersion: '1.0.0',
    );
    Get.put<ChildShellController>(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpSettings(WidgetTester tester) async {
    // A tall surface so the whole ListView (permission cards included) builds.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const GetMaterialApp(home: ChildSettingsTab()),
    );
    await tester.pump();
  }

  void enroll() {
    controller.family.value = testFamily();
    controller.device.value = Device(
      id: 'device-1',
      familyId: 'family-1',
      childUserId: 'child-1',
      displayName: 'Mia phone',
      status: DeviceStatus.active,
    );
  }

  testWidgets('an unlinked phone hides microphone access and the self test',
      (tester) async {
    expect(controller.isEnrolled, isFalse);

    await pumpSettings(tester);

    expect(find.text('Microphone'), findsNothing);
    expect(find.text('Test camera and microphone'), findsNothing);
    expect(find.text('Camera and microphone test'), findsNothing);
    expect(
      find.textContaining('enabled after this phone is linked'),
      findsOneWidget,
    );
    // Non-capture permissions are still offered.
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('a linked phone shows microphone access and the self test',
      (tester) async {
    enroll();
    expect(controller.isEnrolled, isTrue);

    await pumpSettings(tester);

    expect(find.text('Microphone'), findsOneWidget);
    expect(find.text('Camera and microphone test'), findsOneWidget);
    expect(find.text('Test camera and microphone'), findsOneWidget);
    expect(
      find.textContaining('enabled after this phone is linked'),
      findsNothing,
    );
  });
}
