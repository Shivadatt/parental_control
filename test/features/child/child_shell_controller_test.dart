import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/models/child_enforcement.dart';
import 'package:parent_control/features/child/services/child_preferences.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _MockDeviceAdminService extends Mock implements DeviceAdminService {}

class _MockChildPreferences extends Mock implements ChildPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late _MockDeviceRepository devices;
  late _MockRemoteSessionRepository remoteSessions;
  late _MockPolicyRepository policies;
  late MockAuthRepository auth;
  late MockLocalSettingsService settings;
  late SessionService session;
  late ConnectivityService connectivity;
  late _MockDeviceAdminService deviceAdmin;
  late _MockChildPreferences preferences;
  late ChildShellController controller;
  late DeviceCapabilities capabilities;

  const familyId = 'family-1';
  const deviceId = 'device-1';

  setUpAll(registerRepositoryFallbacks);

  setUp(() {
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
    devices = _MockDeviceRepository();
    remoteSessions = _MockRemoteSessionRepository();
    policies = _MockPolicyRepository();
    auth = MockAuthRepository();
    settings = MockLocalSettingsService();
    session = SessionService();
    connectivity = ConnectivityService();
    deviceAdmin = _MockDeviceAdminService();
    preferences = _MockChildPreferences();
    capabilities = const DeviceCapabilities(
      available: true,
      isAdminActive: true,
      manufacturer: 'realme',
      model: 'RMX2161',
      androidVersion: '12',
      appVersion: '1.0.0',
    );
    controller = ChildShellController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      remoteSessionRepository: remoteSessions,
      policyRepository: policies,
      authRepository: auth,
      session: session,
      localSettings: settings,
      connectivity: connectivity,
      deviceAdmin: deviceAdmin,
      preferences: preferences,
    );

    when(() => families.fetchMyMembership()).thenAnswer(
      (_) async => testMember(
        role: FamilyMemberRole.child,
        userId: 'child-1',
        displayName: 'Mia',
      ),
    );
    when(() => families.fetchFamily(familyId))
        .thenAnswer((_) async => testFamily());
    when(() => devices.fetchMyDevice()).thenAnswer((_) async => Device(
          id: deviceId,
          familyId: familyId,
          childUserId: 'child-1',
          displayName: 'Mia phone',
          status: DeviceStatus.active,
        ));
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => const <PairingRequest>[]);
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => const <RemoteSession>[]);
    when(() => policies.fetchLatestPolicy(deviceId))
        .thenAnswer((_) async => null);
    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(() => preferences.locationSharingEnabled()).thenAnswer((_) async => false);
    when(() => deviceAdmin.isAvailable).thenReturn(true);
    when(() => deviceAdmin.getCapabilities())
        .thenAnswer((_) async => capabilities);
    when(() => deviceAdmin.getGuardianServiceStatus())
        .thenAnswer((_) async => const GuardianServiceStatus());
    when(() => deviceAdmin.getIdentity()).thenAnswer(
      (_) async => const DeviceIdentity(
        installationId: 'install-1',
        secret: 'secret-1',
        secretHash: 'hash-1',
      ),
    );
    when(() => deviceAdmin.getInstalledApps())
        .thenAnswer((_) async => const <InstalledApp>[]);
    when(() => deviceAdmin.stopLocationTracking()).thenAnswer((_) async => true);
    when(() => deviceAdmin.stopGuardianService()).thenAnswer((_) async => true);
    when(() => deviceAdmin.stopAudioAssistanceService())
        .thenAnswer((_) async => true);
    when(() => deviceAdmin.clearBackgroundSync()).thenAnswer((_) async {});
    when(
      () => remoteSessions.fetchForFamily(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => const <RemoteSession>[]);
    when(
      () => remoteSessions.end(
        sessionId: any(named: 'sessionId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => pairing.unlink(
        familyId: any(named: 'familyId'),
        childUserId: any(named: 'childUserId'),
      ),
    ).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => settings.clearOnSignOut()).thenAnswer((_) async {});
    when(() => preferences.clear()).thenAnswer((_) async {});
  });

  tearDown(() => controller.onClose());

  DevicePolicy policy(PolicyPayload payload) => DevicePolicy(
        id: 'policy-1',
        deviceId: deviceId,
        version: 1,
        payload: payload,
        createdAt: DateTime.utc(2026, 1, 1),
        status: PolicyEnforcementStatus.enforced,
        acknowledgedAt: DateTime.utc(2026, 1, 2),
      );

  test('performs the first load instead of staying on the loading state',
      () async {
    await controller.load();

    expect(controller.isLoading.value, isFalse);
    expect(controller.error.value, isNull);
    expect(controller.isEnrolled, isTrue);
    expect(controller.familyName, 'Test Family');
    expect(controller.deviceName, 'Mia phone');
    expect(controller.lastLoadedAt.value, isNotNull);
    expect(session.activeFamily.value?.id, familyId);
    expect(session.activeDevice.value?.id, deviceId);
    expect(controller.isManaged, isFalse);
    expect(
      controller.enforcementLabel,
      'Device admin only — app blocking is not available',
    );
  });

  test('offline first load reports the network error honestly', () async {
    connectivity.isOnline.value = false;

    await controller.load();

    expect(controller.isLoading.value, isFalse);
    expect(controller.error.value?.code, 'network_error');
    expect(controller.isEnrolled, isFalse);
    verifyNever(() => families.fetchMyMembership());
  });

  test('clears linked state when this account is no longer a family child',
      () async {
    when(() => families.fetchMyMembership()).thenAnswer((_) async => null);

    await controller.load();

    expect(controller.family.value, isNull);
    expect(controller.device.value, isNull);
    expect(controller.needsEnrollment, isTrue);
    expect(controller.policy.value, isNull);
    verify(() => deviceAdmin.stopLocationTracking()).called(1);
    verify(() => deviceAdmin.stopGuardianService()).called(1);
  });

  test('without Device Owner it never claims blocked apps are suspended',
      () async {
    when(() => policies.fetchLatestPolicy(deviceId)).thenAnswer(
      (_) async => policy(
        const PolicyPayload(
          blockedPackages: ['com.instagram.android'],
          appRules: [
            AppRule(
              packageName: 'com.zhiliaoapp.musically',
              label: 'TikTok',
              blocked: true,
              windows: [
                ScheduleWindow(
                  daysOfWeek: [1, 2, 3, 4, 5],
                  startMinutes: 60,
                  endMinutes: 120,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await controller.load();
    await controller.ensureVerification();

    expect(controller.canVerifySuspension, isFalse);
    expect(controller.verifiedApps, hasLength(2));
    expect(
      controller.verifiedApps.every((app) => app.suspended == null),
      isTrue,
      reason: 'suspension must stay unknown without Device Owner control',
    );
    expect(
      controller.verifiedApps
          .firstWhere((app) => app.packageName == 'com.zhiliaoapp.musically')
          .isScheduleRule,
      isTrue,
    );
    verifyNever(() => deviceAdmin.isPackageSuspended(any()));
    verifyNever(() => deviceAdmin.getInstalledApps());
  });

  test('reports per-package suspension only when Android confirms it',
      () async {
    capabilities = const DeviceCapabilities(
      available: true,
      isDeviceOwner: true,
      isAdminActive: true,
      canSuspendPackages: true,
      manufacturer: 'realme',
      model: 'RMX2161',
      androidVersion: '12',
      appVersion: '1.0.0',
    );
    when(() => policies.fetchLatestPolicy(deviceId)).thenAnswer(
      (_) async => policy(
        const PolicyPayload(
          blockedPackages: ['com.example.extra'],
          appRules: [
            AppRule(
              packageName: 'com.instagram.android',
              label: 'Instagram',
              blocked: true,
            ),
            AppRule(
              packageName: 'com.zhiliaoapp.musically',
              label: 'TikTok',
              blocked: true,
              windows: [
                ScheduleWindow(
                  daysOfWeek: [6, 7],
                  startMinutes: 1200,
                  endMinutes: 1380,
                ),
              ],
            ),
            AppRule(
              packageName: 'com.google.android.youtube',
              label: 'YouTube',
              blocked: false,
            ),
          ],
        ),
      ),
    );
    when(() => deviceAdmin.getInstalledApps()).thenAnswer(
      (_) async => const [
        InstalledApp(
          packageName: 'com.instagram.android',
          label: 'Instagram',
        ),
        InstalledApp(
          packageName: 'com.zhiliaoapp.musically',
          label: 'TikTok',
        ),
        InstalledApp(packageName: 'com.example.extra', label: 'Extra App'),
      ],
    );
    when(() => deviceAdmin.isPackageSuspended('com.instagram.android'))
        .thenAnswer((_) async => true);
    when(() => deviceAdmin.isPackageSuspended('com.zhiliaoapp.musically'))
        .thenAnswer((_) async => false);
    when(() => deviceAdmin.isPackageSuspended('com.example.extra'))
        .thenAnswer(
      (_) async => throw const AppException(
        'native_error',
        'Android did not answer for this package.',
      ),
    );

    await controller.load();
    await controller.ensureVerification();

    expect(controller.canVerifySuspension, isTrue);
    expect(
      controller.verifiedApps.map((app) => app.label),
      ['Extra App', 'Instagram', 'TikTok'],
    );
    final byPackage = <String, ChildEnforcedApp>{
      for (final app in controller.verifiedApps) app.packageName: app,
    };
    expect(byPackage['com.instagram.android']?.suspended, isTrue);
    expect(byPackage['com.zhiliaoapp.musically']?.suspended, isFalse);
    expect(
      byPackage['com.example.extra']?.suspended,
      isNull,
      reason: 'a failed native check must stay unknown, not become false',
    );
    expect(
      byPackage['com.zhiliaoapp.musically']?.isScheduleRule,
      isTrue,
    );
    expect(
      controller.verifiedApps.any(
        (app) => app.packageName == 'com.google.android.youtube',
      ),
      isFalse,
    );

    await controller.ensureVerification();
    verify(() => deviceAdmin.getInstalledApps()).called(1);
    verify(() => deviceAdmin.isPackageSuspended('com.instagram.android'))
        .called(1);
  });

  test('policy fetch failure is surfaced instead of looking enforced',
      () async {
    when(() => policies.fetchLatestPolicy(deviceId))
        .thenThrow(Exception('policy unavailable'));

    await controller.load();

    expect(controller.policy.value, isNull);
    expect(controller.policyError.value, isNotNull);
    expect(controller.isLoading.value, isFalse);
    expect(controller.isEnrolled, isTrue);
  });

  RemoteSession openSession() => RemoteSession(
        id: 'session-1',
        familyId: familyId,
        deviceId: deviceId,
        parentUserId: 'parent-1',
        childUserId: 'child-1',
        kind: SessionKind.audio,
        status: RemoteSessionStatus.active,
        requestedAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 1, 0, 10),
      );

  test('sign-out stops the microphone service and ends an open session',
      () async {
    Get.testMode = true;
    addTearDown(() => Get.testMode = false);
    session.userId.value = 'child-1';
    await controller.load();
    when(
      () => remoteSessions.fetchForFamily(familyId, limit: any(named: 'limit')),
    ).thenAnswer((_) async => [openSession()]);

    await controller.signOut();

    verifyInOrder([
      () => deviceAdmin.stopAudioAssistanceService(),
      () => remoteSessions.end(sessionId: 'session-1', reason: 'signed_out'),
      () => auth.signOut(),
    ]);
    verify(() => deviceAdmin.stopGuardianService()).called(1);
  });

  test('unlink stops the microphone service and ends an open session',
      () async {
    session.userId.value = 'child-1';
    await controller.load();
    when(
      () => remoteSessions.fetchForFamily(familyId, limit: any(named: 'limit')),
    ).thenAnswer((_) async => [openSession()]);

    final removed = await controller.unlink();

    expect(removed, isTrue);
    verify(() => deviceAdmin.stopAudioAssistanceService()).called(1);
    verify(
      () => remoteSessions.end(sessionId: 'session-1', reason: 'unlinked'),
    ).called(1);
    verify(
      () => pairing.unlink(familyId: familyId, childUserId: 'child-1'),
    ).called(1);
  });
}
