import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/controllers/child_enrollment_controller.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockDeviceAdminService extends Mock implements DeviceAdminService {}

void main() {
  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late _MockDeviceRepository devices;
  late MockLocalSettingsService settings;
  late _MockDeviceAdminService deviceAdmin;
  late SessionService session;
  late ConnectivityService connectivity;
  late ChildEnrollmentController controller;

  setUpAll(() {
    registerRepositoryFallbacks();
    registerFallbackValue(
      const DeviceIdentity(
        installationId: 'install-1',
        secret: 'secret-1',
        secretHash: 'hash-1',
      ),
    );
  });

  setUp(() {
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
    devices = _MockDeviceRepository();
    settings = MockLocalSettingsService();
    deviceAdmin = _MockDeviceAdminService();
    session = SessionService();
    connectivity = ConnectivityService();
    controller = ChildEnrollmentController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      settings: settings,
      connectivity: connectivity,
      deviceAdmin: deviceAdmin,
    );
    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(() => settings.cachedChildContactId(any())).thenReturn(null);
    when(() => settings.setCachedChildContactId(any(), any()))
        .thenAnswer((_) async {});
    when(() => settings.clearCachedChildContactId(any()))
        .thenAnswer((_) async {});
    when(() => deviceAdmin.isAvailable).thenReturn(true);
    when(() => deviceAdmin.getCapabilities()).thenAnswer(
      (_) async => const DeviceCapabilities(
        available: true,
        manufacturer: 'Pixel',
        model: '8',
        androidVersion: '31',
        appVersion: '1.2.0',
      ),
    );
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => const <PairingRequest>[]);
    when(() => devices.fetchMyDevice()).thenAnswer((_) async => null);
  });

  tearDown(() => controller.onClose());

  void stubChildMembership() {
    when(() => families.fetchMyMembership()).thenAnswer(
      (_) async => testMember(
        role: FamilyMemberRole.child,
        userId: 'child-1',
        displayName: 'Mia',
      ),
    );
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
  }

  void stubSignedInChild() {
    session.setAuthenticated(
      id: 'child-1',
      address: 'mia@example.test',
      verified: true,
    );
    when(() => families.fetchMyMembership()).thenAnswer((_) async => null);
    when(() => pairing.fetchChildContactId())
        .thenAnswer((_) async => testChildContactId());
  }

  String cachedContactJson(ChildContactId contact) {
    return jsonEncode({
      'contact_id': contact.id,
      'contact_id_canonical': contact.canonicalId,
      'qr_payload': contact.qrPayload,
      'created_at': contact.assignedAt?.toUtc().toIso8601String(),
    });
  }

  test('loads a linked child family and its pending requests', () async {
    stubChildMembership();
    final pending = testPairingRequest(childUserId: 'child-1');
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => [pending]);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.isLoading.value, isFalse);
    expect(controller.family.value?.name, 'Test Family');
    expect(controller.isLinked, isTrue);
    expect(controller.needsDeviceRegistration, isTrue);
    expect(controller.pendingRequests, hasLength(1));
    expect(controller.lastCheckedAt.value, isNotNull);
    expect(session.activeFamily.value?.id, 'family-1');
  });

  test('does not treat a parent membership as a linked child', () async {
    when(() => families.fetchMyMembership()).thenAnswer(
      (_) async => testMember(role: FamilyMemberRole.parent),
    );

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.isLinked, isFalse);
    expect(controller.isReady, isFalse);
    verifyNever(() => families.fetchFamily(any()));
  });

  test('registers this phone only after the server confirms the family',
      () async {
    stubChildMembership();
    when(() => deviceAdmin.getIdentity()).thenAnswer(
      (_) async => const DeviceIdentity(
        installationId: 'install-1',
        secret: 'secret-1',
        secretHash: 'hash-1',
      ),
    );
    final registered = Device(
      id: 'device-1',
      familyId: 'family-1',
      childUserId: 'child-1',
      displayName: 'Pixel 8',
      status: DeviceStatus.active,
    );
    when(
      () => devices.registerDevice(
        familyId: 'family-1',
        identity: any(named: 'identity'),
        displayName: 'Pixel 8',
        androidVersion: '31',
        appVersion: '1.2.0',
      ),
    ).thenAnswer((_) async => registered);

    await controller.load();
    expect(controller.device.value, isNull);
    expect(controller.displayName.value, 'Pixel 8');

    final result = await controller.registerDevice();

    expect(result, isTrue);
    expect(controller.actionError.value, isNull);
    expect(controller.device.value?.id, 'device-1');
    expect(controller.isReady, isTrue);
    expect(session.activeDevice.value?.id, 'device-1');
    expect(session.deviceIdentity.value?.serverDeviceId, 'device-1');
    verify(
      () => devices.registerDevice(
        familyId: 'family-1',
        identity: any(named: 'identity'),
        displayName: 'Pixel 8',
        androidVersion: '31',
        appVersion: '1.2.0',
      ),
    ).called(1);
  });

  test('refuses device registration before a family is linked', () async {
    when(() => families.fetchMyMembership()).thenAnswer((_) async => null);

    await controller.load();
    final result = await controller.registerDevice();

    expect(result, isFalse);
    expect(controller.actionError.value?.message, contains('Link a family'));
    verifyNever(() => deviceAdmin.getIdentity());
    verifyNever(
      () => devices.registerDevice(
        familyId: any(named: 'familyId'),
        identity: any(named: 'identity'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('reports offline instead of pretending to load or register', () async {
    connectivity.isOnline.value = false;

    await controller.load();

    expect(controller.error.value?.code, 'network_error');
    expect(controller.isLinked, isFalse);

    final result = await controller.registerDevice();
    expect(result, isFalse);
    expect(controller.actionError.value?.message, contains('Link a family'));

    verifyNever(() => families.fetchMyMembership());
    verifyNever(() => pairing.fetchPendingForChild());
  });

  test('declining a pairing request leaves the family unlinked', () async {
    final pending = testPairingRequest(childUserId: 'child-1');
    when(() => families.fetchMyMembership()).thenAnswer((_) async => null);
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => [pending]);
    when(() => pairing.respond(requestId: pending.id, approve: false))
        .thenAnswer((_) async {});

    await controller.load();
    expect(controller.pendingRequests, hasLength(1));

    final result = await controller.respondTo(pending, approve: false);

    expect(result, isTrue);
    expect(controller.actionError.value, isNull);
    expect(controller.actionMessage.value, contains('declined'));
    expect(controller.family.value, isNull);
    verify(() => pairing.respond(requestId: pending.id, approve: false))
        .called(1);
  });

  test('refuses to answer a request that already expired', () async {
    final expired = testPairingRequest(
      childUserId: 'child-1',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    final result = await controller.respondTo(expired, approve: true);

    expect(result, isFalse);
    expect(controller.actionError.value?.code, 'validation_error');
    verifyNever(
      () => pairing.respond(
        requestId: any(named: 'requestId'),
        approve: any(named: 'approve'),
      ),
    );
  });

  // The child setup screen shows the permanent Child ID. The old linking-code
  // API (createCode / linkingCode / isCreatingCode) is intentionally not
  // referenced anywhere below.
  test('load exposes the stable Child ID returned by the server', () async {
    stubSignedInChild();

    await controller.load();
    await pumpEventQueue();

    expect(controller.contactId.value?.id, 'PC-7K4M2QRX');
    expect(controller.contactId.value?.canonicalId, 'PC7K4M2QRX');
    expect(controller.contactId.value?.qrPayload, contains('v=2'));
    expect(controller.contactError.value, isNull);
    verify(() => pairing.fetchChildContactId()).called(1);
    verify(
      () => settings.setCachedChildContactId('child-1', any()),
    ).called(1);
    verifyNever(() => pairing.createLinkingCode());
  });

  test('a second load refetches but never regenerates the Child ID', () async {
    stubSignedInChild();

    await controller.load();
    await pumpEventQueue();
    final first = controller.contactId.value;

    await controller.load();
    await pumpEventQueue();

    expect(controller.contactId.value?.canonicalId, first?.canonicalId);
    expect(controller.contactId.value?.id, first?.id);
    // refreshContactId fires once per online load(); it never mints a new ID.
    verify(() => pairing.fetchChildContactId()).called(2);
    verifyNever(() => pairing.createLinkingCode());
  });

  test('restores the cached Child ID offline without a network call', () async {
    session.setAuthenticated(
      id: 'child-1',
      address: 'mia@example.test',
      verified: true,
    );
    final cached = testChildContactId();
    when(() => settings.cachedChildContactId('child-1'))
        .thenReturn(cachedContactJson(cached));
    connectivity.isOnline.value = false;

    await controller.load();
    await pumpEventQueue();

    expect(controller.contactId.value?.id, 'PC-7K4M2QRX');
    expect(controller.contactId.value?.canonicalId, 'PC7K4M2QRX');
    expect(controller.error.value?.code, AppErrorCodes.network);
    verifyNever(() => pairing.fetchChildContactId());
    verifyNever(() => pairing.createLinkingCode());
    verifyNever(
      () => settings.setCachedChildContactId(any(), any()),
    );
  });

  for (final code in <String>[
    AppErrorCodes.unauthorized,
    AppErrorCodes.forbidden,
    AppErrorCodes.notFound,
  ]) {
    test('a $code failure clears the cached Child ID', () async {
      session.setAuthenticated(
        id: 'child-1',
        address: 'mia@example.test',
        verified: true,
      );
      final cached = testChildContactId();
      when(() => settings.cachedChildContactId('child-1'))
          .thenReturn(cachedContactJson(cached));
      when(() => families.fetchMyMembership()).thenAnswer((_) async => null);
      when(() => pairing.fetchChildContactId())
          .thenThrow(AppException(code, 'Rejected with $code'));

      await controller.load();
      await pumpEventQueue();

      expect(controller.contactId.value, isNull);
      expect(controller.contactError.value?.code, code);
      verify(
        () => settings.clearCachedChildContactId('child-1'),
      ).called(1);
    });
  }
}
