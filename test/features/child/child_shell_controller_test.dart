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
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';
import 'package:parent_control/features/remote_assistance/remote_session_registry.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _MockDeviceAdminService extends Mock implements DeviceAdminService {}

class _MockChildPreferences extends Mock implements ChildPreferences {}

/// App-scoped session controller stand-in: no timers, media or native I/O, but
/// `onClose()` records disposal so registry release can be asserted.
class _MinimalSessionController extends RemoteSessionController {
  _MinimalSessionController()
    : super(
        remoteSessionRepository: _MockRemoteSessionRepository(),
        session: SessionService(),
        deviceAdmin: DeviceAdminService(),
        sessionId: 'session-1',
        role: 'child',
      );

  int closeCount = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onClose() {
    closeCount += 1;
  }
}

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
    when(
      () => families.fetchFamily(familyId),
    ).thenAnswer((_) async => testFamily());
    when(() => devices.fetchMyDevice()).thenAnswer(
      (_) async => Device(
        id: deviceId,
        familyId: familyId,
        childUserId: 'child-1',
        displayName: 'Mia phone',
        status: DeviceStatus.active,
      ),
    );
    when(
      () => pairing.fetchPendingForChild(),
    ).thenAnswer((_) async => const <PairingRequest>[]);
    when(
      () => remoteSessions.fetchPendingForChild(),
    ).thenAnswer((_) async => const <RemoteSession>[]);
    when(
      () => policies.fetchLatestPolicy(deviceId),
    ).thenAnswer((_) async => null);
    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(
      () => preferences.locationSharingEnabled(),
    ).thenAnswer((_) async => false);
    when(() => deviceAdmin.isAvailable).thenReturn(true);
    when(
      () => deviceAdmin.getCapabilities(),
    ).thenAnswer((_) async => capabilities);
    when(
      () => deviceAdmin.getGuardianServiceStatus(),
    ).thenAnswer((_) async => const GuardianServiceStatus());
    when(() => deviceAdmin.getIdentity()).thenAnswer(
      (_) async => const DeviceIdentity(
        installationId: 'install-1',
        secret: 'secret-1',
        secretHash: 'hash-1',
      ),
    );
    when(
      () => deviceAdmin.getInstalledApps(),
    ).thenAnswer((_) async => const <InstalledApp>[]);
    when(
      () => deviceAdmin.stopLocationTracking(),
    ).thenAnswer((_) async => true);
    when(() => deviceAdmin.stopGuardianService()).thenAnswer((_) async => true);
    when(
      () => deviceAdmin.stopAudioAssistanceService(),
    ).thenAnswer((_) async => true);
    when(() => deviceAdmin.clearBackgroundSync()).thenAnswer((_) async {});
    when(
      () => deviceAdmin.requestPermissions(
        camera: any(named: 'camera'),
        microphone: any(named: 'microphone'),
        location: any(named: 'location'),
        backgroundLocation: any(named: 'backgroundLocation'),
        notifications: any(named: 'notifications'),
      ),
    ).thenAnswer((_) async => const <String, bool>{});
    when(
      () => remoteSessions.fetchForFamily(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => const <RemoteSession>[]);
    when(
      () => remoteSessions.end(sessionId: any(named: 'sessionId')),
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

  test(
    'performs the first load instead of staying on the loading state',
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
    },
  );

  test('offline first load reports the network error honestly', () async {
    connectivity.isOnline.value = false;

    await controller.load();

    expect(controller.isLoading.value, isFalse);
    expect(controller.error.value?.code, 'network_error');
    expect(controller.isEnrolled, isFalse);
    verifyNever(() => families.fetchMyMembership());
  });

  test(
    'clears linked state when this account is no longer a family child',
    () async {
      when(() => families.fetchMyMembership()).thenAnswer((_) async => null);

      await controller.load();

      expect(controller.family.value, isNull);
      expect(controller.device.value, isNull);
      expect(controller.needsEnrollment, isTrue);
      expect(controller.policy.value, isNull);
      verify(() => deviceAdmin.stopLocationTracking()).called(1);
      verify(() => deviceAdmin.stopGuardianService()).called(1);
    },
  );

  test(
    'without Device Owner it never claims blocked apps are suspended',
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
    },
  );

  test(
    'reports per-package suspension only when Android confirms it',
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
      when(
        () => deviceAdmin.isPackageSuspended('com.instagram.android'),
      ).thenAnswer((_) async => true);
      when(
        () => deviceAdmin.isPackageSuspended('com.zhiliaoapp.musically'),
      ).thenAnswer((_) async => false);
      when(
        () => deviceAdmin.isPackageSuspended('com.example.extra'),
      ).thenAnswer(
        (_) async => throw const AppException(
          'native_error',
          'Android did not answer for this package.',
        ),
      );

      await controller.load();
      await controller.ensureVerification();

      expect(controller.canVerifySuspension, isTrue);
      expect(controller.verifiedApps.map((app) => app.label), [
        'Extra App',
        'Instagram',
        'TikTok',
      ]);
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
      expect(byPackage['com.zhiliaoapp.musically']?.isScheduleRule, isTrue);
      expect(
        controller.verifiedApps.any(
          (app) => app.packageName == 'com.google.android.youtube',
        ),
        isFalse,
      );

      await controller.ensureVerification();
      verify(() => deviceAdmin.getInstalledApps()).called(1);
      verify(
        () => deviceAdmin.isPackageSuspended('com.instagram.android'),
      ).called(1);
    },
  );

  test(
    'policy fetch failure is surfaced instead of looking enforced',
    () async {
      when(
        () => policies.fetchLatestPolicy(deviceId),
      ).thenThrow(Exception('policy unavailable'));

      await controller.load();

      expect(controller.policy.value, isNull);
      expect(controller.policyError.value, isNotNull);
      expect(controller.isLoading.value, isFalse);
      expect(controller.isEnrolled, isTrue);
    },
  );

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

  test('sign-out stops the microphone service and leaves the session open for '
      'the parent', () async {
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
      () => auth.signOut(),
    ]);
    verify(() => deviceAdmin.stopGuardianService()).called(1);
    verifyNever(() => remoteSessions.end(sessionId: any(named: 'sessionId')));
  });

  test('unlink stops the microphone service and lets the server end the '
      'session', () async {
    session.userId.value = 'child-1';
    await controller.load();
    when(
      () => remoteSessions.fetchForFamily(familyId, limit: any(named: 'limit')),
    ).thenAnswer((_) async => [openSession()]);

    final removed = await controller.unlink();

    expect(removed, isTrue);
    verify(() => deviceAdmin.stopAudioAssistanceService()).called(1);
    verify(
      () => pairing.unlink(familyId: familyId, childUserId: 'child-1'),
    ).called(1);
    verifyNever(() => remoteSessions.end(sessionId: any(named: 'sessionId')));
  });

  // -------------------------------------------------------------------------
  // Active assistance session card (child shell)
  // -------------------------------------------------------------------------

  RemoteSession sessionRow({
    required String id,
    required RemoteSessionStatus status,
    String rowDeviceId = deviceId,
    String childUserId = 'child-1',
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? expiresAt,
    SessionKind kind = SessionKind.audio,
  }) => RemoteSession(
    id: id,
    familyId: familyId,
    deviceId: rowDeviceId,
    parentUserId: 'parent-1',
    childUserId: childUserId,
    kind: kind,
    status: status,
    requestedAt:
        requestedAt ?? DateTime.now().subtract(const Duration(minutes: 2)),
    acceptedAt: acceptedAt,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 10)),
  );

  Future<void> loadEnrolledWith(List<RemoteSession> sessions) async {
    session.userId.value = 'child-1';
    when(
      () => remoteSessions.fetchForFamily(familyId, limit: any(named: 'limit')),
    ).thenAnswer((_) async => sessions);
    await controller.load();
  }

  RemoteSessionRegistry registerRegistryWith(
    _MinimalSessionController live, {
    String sessionId = 'session-1',
  }) {
    final registry = Get.put<RemoteSessionRegistry>(
      RemoteSessionRegistry(),
      permanent: true,
    );
    registry.acquire(sessionId: sessionId, role: 'child', create: () => live);
    return registry;
  }

  test(
    'the active session is only this device/child newest open one',
    () async {
      final now = DateTime.now();
      await loadEnrolledWith([
        sessionRow(id: 'requested', status: RemoteSessionStatus.requested),
        sessionRow(id: 'ended', status: RemoteSessionStatus.ended),
        sessionRow(id: 'declined', status: RemoteSessionStatus.declined),
        sessionRow(
          id: 'other-device',
          status: RemoteSessionStatus.active,
          rowDeviceId: 'device-2',
          acceptedAt: now,
        ),
        sessionRow(
          id: 'other-child',
          status: RemoteSessionStatus.active,
          childUserId: 'child-9',
          acceptedAt: now,
        ),
        sessionRow(
          id: 'expired',
          status: RemoteSessionStatus.active,
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
        sessionRow(
          id: 'older-accepted',
          status: RemoteSessionStatus.accepted,
          acceptedAt: now.subtract(const Duration(minutes: 5)),
        ),
        sessionRow(
          id: 'newest-active',
          status: RemoteSessionStatus.active,
          acceptedAt: now.subtract(const Duration(minutes: 1)),
        ),
      ]);

      expect(controller.activeSession.value?.id, 'newest-active');
      expect(controller.hasActiveSession, isTrue);
    },
  );

  test(
    'no active session card for requested, ended or other-device rows only',
    () async {
      final now = DateTime.now();
      await loadEnrolledWith([
        sessionRow(id: 'requested', status: RemoteSessionStatus.requested),
        sessionRow(id: 'ended', status: RemoteSessionStatus.ended),
        sessionRow(
          id: 'other-device',
          status: RemoteSessionStatus.active,
          rowDeviceId: 'device-2',
          acceptedAt: now,
        ),
      ]);

      expect(controller.activeSession.value, isNull);
      expect(controller.hasActiveSession, isFalse);
    },
  );

  test('stopActiveSession stops capture locally, releases the registry and '
      'keeps the card because only the parent ends the session', () async {
    Get.testMode = true;
    addTearDown(Get.reset);
    addTearDown(() => Get.testMode = false);
    await loadEnrolledWith([
      sessionRow(id: 'session-1', status: RemoteSessionStatus.active),
    ]);
    final live = _MinimalSessionController();
    final registry = registerRegistryWith(live);
    expect(registry.active, same(live));

    await controller.stopActiveSession();

    verifyNever(() => remoteSessions.end(sessionId: any(named: 'sessionId')));
    verify(() => deviceAdmin.stopAudioAssistanceService()).called(1);
    expect(controller.activeSession.value?.id, 'session-1');
    expect(controller.hasActiveSession, isTrue);
    expect(controller.isStoppingActiveSession.value, isFalse);
    expect(controller.actionError.value, isNull);
    expect(controller.actionMessage.value, contains('Sharing stopped'));
    expect(registry.active, isNull);
    expect(registry.sessionId, isNull);
    expect(Get.isRegistered<RemoteSessionController>(), isFalse);
    expect(live.closeCount, 1);
  });

  test('offline Stop sharing still releases the microphone and never asks the '
      'server to end the session', () async {
    await loadEnrolledWith([
      sessionRow(id: 'session-1', status: RemoteSessionStatus.active),
    ]);
    connectivity.isOnline.value = false;

    await controller.stopActiveSession();

    verifyNever(() => remoteSessions.end(sessionId: any(named: 'sessionId')));
    verify(() => deviceAdmin.stopAudioAssistanceService()).called(1);
    expect(controller.isStoppingActiveSession.value, isFalse);
    expect(controller.activeSession.value?.id, 'session-1');
    expect(controller.actionError.value, isNull);
    expect(controller.actionMessage.value, contains('Sharing stopped'));
  });

  test(
    'microphone permission is refused before this phone is linked',
    () async {
      await controller.requestPermissions(microphone: true);

      verifyNever(
        () => deviceAdmin.requestPermissions(
          camera: any(named: 'camera'),
          microphone: any(named: 'microphone'),
          location: any(named: 'location'),
          backgroundLocation: any(named: 'backgroundLocation'),
          notifications: any(named: 'notifications'),
        ),
      );
      expect(controller.isEnrolled, isFalse);
      expect(controller.actionError.value?.code, AppErrorCodes.validation);
      expect(
        controller.actionError.value?.message,
        contains('Link this phone'),
      );
    },
  );

  test(
    'microphone permission is requested once this phone is linked',
    () async {
      await loadEnrolledWith(const []);

      await controller.requestPermissions(microphone: true);

      expect(controller.actionError.value, isNull);
      verify(
        () => deviceAdmin.requestPermissions(
          camera: false,
          microphone: true,
          location: false,
          backgroundLocation: false,
          notifications: false,
        ),
      ).called(1);
    },
  );

  test('sign-out releases the app-scoped session controller', () async {
    Get.testMode = true;
    addTearDown(Get.reset);
    addTearDown(() => Get.testMode = false);
    await loadEnrolledWith([
      sessionRow(id: 'session-1', status: RemoteSessionStatus.active),
    ]);
    final live = _MinimalSessionController();
    final registry = registerRegistryWith(live);

    await controller.signOut();

    expect(registry.active, isNull);
    expect(registry.sessionId, isNull);
    expect(Get.isRegistered<RemoteSessionController>(), isFalse);
    expect(live.closeCount, 1);
  });

  test('unlink releases the app-scoped session controller', () async {
    Get.testMode = true;
    addTearDown(Get.reset);
    addTearDown(() => Get.testMode = false);
    await loadEnrolledWith([
      sessionRow(id: 'session-1', status: RemoteSessionStatus.active),
    ]);
    final live = _MinimalSessionController();
    final registry = registerRegistryWith(live);

    final removed = await controller.unlink();

    expect(removed, isTrue);
    expect(registry.active, isNull);
    expect(Get.isRegistered<RemoteSessionController>(), isFalse);
    expect(live.closeCount, 1);
  });

  test(
    'a registry holding another session is left alone when stopping',
    () async {
      Get.testMode = true;
      addTearDown(Get.reset);
      addTearDown(() => Get.testMode = false);
      await loadEnrolledWith([
        sessionRow(id: 'session-1', status: RemoteSessionStatus.active),
      ]);
      final other = _MinimalSessionController();
      final registry = registerRegistryWith(other, sessionId: 'session-other');

      await controller.stopActiveSession();

      // The card stays, but the registry holds a different live session.
      expect(controller.activeSession.value?.id, 'session-1');
      expect(registry.active, same(other));
      expect(other.closeCount, 0);
      verifyNever(() => remoteSessions.end(sessionId: any(named: 'sessionId')));
    },
  );

  test(
    'a pending invite reaches an open child shell without a manual refresh',
    () async {
      var pairingCalls = 0;
      when(() => pairing.fetchPendingForChild()).thenAnswer((_) async {
        pairingCalls += 1;
        return pairingCalls == 1
            ? const <PairingRequest>[]
            : [testPairingRequest()];
      });
      final polling = ChildShellController(
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
        linkedPollInterval: const Duration(milliseconds: 20),
      );
      addTearDown(polling.onClose);

      await polling.load();
      expect(polling.pendingPairings, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(polling.pendingPairings, hasLength(1));
      expect(
        polling.pendingPairings.single.status,
        PairingRequestStatus.pendingChild,
      );
    },
  );

  test(
    'the linked poll refreshes the device presence row',
    () async {
      var deviceCalls = 0;
      when(() => devices.fetchMyDevice()).thenAnswer((_) async {
        deviceCalls += 1;
        return Device(
          id: deviceId,
          familyId: familyId,
          childUserId: 'child-1',
          displayName: 'Mia phone',
          status: DeviceStatus.active,
          lastSeenAt: deviceCalls == 1
              ? DateTime.now().subtract(const Duration(minutes: 20))
              : DateTime.now(),
        );
      });
      final polling = ChildShellController(
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
        linkedPollInterval: const Duration(milliseconds: 20),
      );
      addTearDown(polling.onClose);

      await polling.load();
      expect(polling.device.value?.isOnline, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(polling.device.value?.isOnline, isTrue);
      expect(deviceCalls, greaterThan(1));
    },
  );
}
