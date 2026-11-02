import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/family/controllers/family_controller.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(registerRepositoryFallbacks);

  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late MockDeviceRepository devices;
  late SessionService session;
  late ConnectivityService connectivity;
  late FamilyController controller;

  setUp(() {
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
    devices = MockDeviceRepository();
    session = SessionService();
    session.setAuthenticated(
      id: 'user-1',
      address: 'alex@example.com',
      verified: true,
    );
    connectivity = ConnectivityService();
    controller = FamilyController(
      familyRepository: families,
      pairingRepository: pairing,
      deviceRepository: devices,
      session: session,
      connectivity: connectivity,
    );
    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => const <Device>[]);
    when(() => pairing.fetchForFamily('family-1'))
        .thenAnswer((_) async => const <PairingRequest>[]);
  });

  test('a family without children renders the empty children state', () async {
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);

    await controller.start('family-1');

    expect(controller.error.value, isNull);
    expect(controller.family.value?.id, 'family-1');
    expect(controller.children, isEmpty);
    expect(controller.guardians.single.userId, 'user-1');
    expect(controller.isOwner(controller.family.value!), isTrue);
    expect(session.activeFamily.value?.id, 'family-1');
    expect(controller.isLoading.value, isFalse);
  });

  test('a family removed on the server clears any stale rows', () async {
    when(() => families.fetchFamily('family-1')).thenAnswer((_) async => null);

    await controller.start('family-1');

    expect(controller.family.value, isNull);
    expect(controller.members, isEmpty);
    expect(controller.error.value?.code, AppErrorCodes.notFound);
    verifyNever(() => families.fetchMembers(any()));
  });

  test('unlinking a child waits for the server and reloads the members',
      () async {
    final child = testMember(
      id: 'member-2',
      userId: 'child-1',
      role: FamilyMemberRole.child,
      displayName: 'Mia',
    );
    var memberLoads = 0;
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1')).thenAnswer((_) async {
      memberLoads += 1;
      return memberLoads == 1 ? [testMember(), child] : [testMember()];
    });
    when(
      () => pairing.unlink(
        familyId: 'family-1',
        childUserId: 'child-1',
      ),
    ).thenAnswer((_) async {});

    await controller.start('family-1');
    expect(controller.children, hasLength(1));

    final removed = await controller.unlink(child);

    expect(removed, isTrue);
    expect(controller.children, isEmpty);
    expect(controller.isUnlinking.value, isFalse);
    verify(
      () => pairing.unlink(
        familyId: 'family-1',
        childUserId: 'child-1',
      ),
    ).called(1);
    expect(memberLoads, 2);
  });

  test('a failed unlink keeps the child visible', () async {
    final child = testMember(
      id: 'member-2',
      userId: 'child-1',
      role: FamilyMemberRole.child,
      displayName: 'Mia',
    );
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember(), child]);
    when(
      () => pairing.unlink(
        familyId: 'family-1',
        childUserId: 'child-1',
      ),
    ).thenThrow(
      const AppException(AppErrorCodes.notFound, 'Child is not linked.'),
    );

    await controller.start('family-1');
    final removed = await controller.unlink(child);

    expect(removed, isFalse);
    expect(controller.children, hasLength(1));
    expect(controller.actionError.value?.code, AppErrorCodes.notFound);
    expect(controller.isUnlinking.value, isFalse);
  });

  test('a missing family argument is explained without a server call',
      () async {
    await controller.start(null);

    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(() => families.fetchFamily(any()));
    verifyNever(() => families.fetchMembers(any()));
  });

  test('an offline refresh keeps loaded rows and reports the failure',
      () async {
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);

    await controller.start('family-1');
    connectivity.isOnline.value = false;
    await controller.refresh();

    expect(controller.family.value?.id, 'family-1');
    expect(controller.members, hasLength(1));
    expect(controller.error.value, isNull);
    expect(controller.actionError.value?.code, AppErrorCodes.network);
  });

  test('loads device health and pending pairing requests with the family',
      () async {
    final stalled = testDevice(
      id: 'device-1',
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 14)),
    );
    final revoked = testDevice(id: 'device-2', status: DeviceStatus.revoked);
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => [stalled, revoked]);
    when(() => pairing.fetchForFamily('family-1')).thenAnswer(
      (_) async => [
        testPairingRequest(),
        testPairingRequest(
          id: 'request-2',
          status: PairingRequestStatus.approved,
        ),
      ],
    );

    await controller.start('family-1');

    expect(controller.devices, hasLength(2));
    // Only the live device counts as linked.
    expect(controller.activeDevices.map((d) => d.id), ['device-1']);
    expect(controller.devicesForChild('child-1').single.id, 'device-1');
    // Presence comes from the model: a missed heartbeat is stalled, not online.
    expect(controller.activeDevices.single.statusLabel, 'Sync stalled');
    expect(controller.activeDevices.single.isOnline, isFalse);
    // Only an unapproved request is pending.
    expect(controller.pendingPairingCount, 1);
    expect(controller.auxError.value, isNull);
    expect(controller.isAuxLoading.value, isFalse);
  });

  test('a failed device load keeps the family rows and reports the failure',
      () async {
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1')).thenThrow(
      const AppException(AppErrorCodes.network, 'Devices could not be loaded'),
    );

    await controller.start('family-1');

    expect(controller.error.value, isNull);
    expect(controller.family.value?.id, 'family-1');
    expect(controller.members, hasLength(1));
    expect(controller.devices, isEmpty);
    expect(controller.auxError.value?.message, 'Devices could not be loaded');

    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => [testDevice()]);
    await controller.retryAuxiliary();

    expect(controller.auxError.value, isNull);
    expect(controller.devices, hasLength(1));
  });

  test('a pairing failure alone still shows the devices that loaded',
      () async {
    when(() => families.fetchFamily('family-1'))
        .thenAnswer((_) async => testFamily());
    when(() => families.fetchMembers('family-1'))
        .thenAnswer((_) async => [testMember()]);
    when(() => devices.fetchDevices('family-1'))
        .thenAnswer((_) async => [testDevice()]);
    when(() => pairing.fetchForFamily('family-1')).thenThrow(
      const AppException(AppErrorCodes.forbidden, 'Pairing rows are hidden'),
    );

    await controller.start('family-1');

    expect(controller.devices, hasLength(1));
    expect(controller.pairingRequests, isEmpty);
    expect(controller.auxError.value?.message, 'Pairing rows are hidden');
  });
}
