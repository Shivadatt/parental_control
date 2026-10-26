import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/family/controllers/family_controller.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(registerRepositoryFallbacks);

  late MockFamilyRepository families;
  late MockPairingRepository pairing;
  late SessionService session;
  late ConnectivityService connectivity;
  late FamilyController controller;

  setUp(() {
    families = MockFamilyRepository();
    pairing = MockPairingRepository();
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
      session: session,
      connectivity: connectivity,
    );
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
}
