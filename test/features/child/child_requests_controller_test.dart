import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/child/controllers/child_requests_controller.dart';

import '../auth/fakes.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPairingRepository pairing;
  late _MockRemoteSessionRepository remoteSessions;
  late ConnectivityService connectivity;
  late ChildRequestsController controller;

  setUpAll(registerRepositoryFallbacks);

  setUp(() {
    Get.testMode = true;
    pairing = MockPairingRepository();
    remoteSessions = _MockRemoteSessionRepository();
    connectivity = ConnectivityService();
    controller = ChildRequestsController(
      pairingRepository: pairing,
      remoteSessionRepository: remoteSessions,
      connectivity: connectivity,
    );
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => const <PairingRequest>[]);
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => const <RemoteSession>[]);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  RemoteSession session({
    String id = 'session-1',
    RemoteSessionStatus status = RemoteSessionStatus.requested,
    Duration expiresIn = const Duration(minutes: 10),
  }) =>
      RemoteSession(
        id: id,
        familyId: 'family-1',
        deviceId: 'device-1',
        parentUserId: 'parent-1',
        childUserId: 'child-1',
        kind: SessionKind.video,
        status: status,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        expiresAt: DateTime.now().add(expiresIn),
      );

  test('shows only open pairing and assistance requests', () async {
    final pending = testPairingRequest(childUserId: 'child-1');
    final expired = testPairingRequest(
      id: 'request-2',
      childUserId: 'child-1',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final openSession = session();
    final expiredSession = session(
      id: 'session-2',
      expiresIn: const Duration(minutes: -1),
    );
    final acceptedSession = session(
      id: 'session-3',
      status: RemoteSessionStatus.accepted,
    );
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => [pending, expired]);
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => [openSession, expiredSession, acceptedSession]);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.pairingRequests.map((request) => request.id), ['request-1']);
    expect(controller.sessionRequests.map((item) => item.id), ['session-1']);
    expect(controller.pendingCount, 2);
    expect(controller.lastLoadedAt.value, isNotNull);
  });

  test('declining a pairing request never links the family', () async {
    final pending = testPairingRequest(childUserId: 'child-1');
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => [pending]);
    when(() => pairing.respond(requestId: pending.id, approve: false))
        .thenAnswer((_) async {});

    await controller.load();
    final result = await controller.declinePairing(pending);

    expect(result, isTrue);
    expect(controller.actionError.value, isNull);
    expect(controller.actionMessage.value, contains('declined'));
    verify(() => pairing.respond(requestId: pending.id, approve: false))
        .called(1);
  });

  test('accepting an assistance request only records consent', () async {
    final requested = session();
    final accepted = session(status: RemoteSessionStatus.accepted);
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => [requested]);
    when(
      () => remoteSessions.respond(sessionId: requested.id, accept: true),
    ).thenAnswer((_) async => accepted);

    await controller.load();
    final result = await controller.acceptSession(requested);

    expect(result, isTrue);
    expect(controller.actionError.value, isNull);
    expect(controller.isResponding.value, isFalse);
    verify(
      () => remoteSessions.respond(sessionId: requested.id, accept: true),
    ).called(1);
  });

  test('declining an assistance request returns to the inbox', () async {
    final requested = session();
    final declined = session(status: RemoteSessionStatus.declined);
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => [requested]);
    when(
      () => remoteSessions.respond(sessionId: requested.id, accept: false),
    ).thenAnswer((_) async => declined);

    await controller.load();
    final result = await controller.declineSession(requested);

    expect(result, isTrue);
    expect(controller.actionMessage.value, contains('declined'));
    verify(
      () => remoteSessions.respond(sessionId: requested.id, accept: false),
    ).called(1);
  });

  test('offline actions fail loudly and send nothing to the server', () async {
    final pending = testPairingRequest(childUserId: 'child-1');
    when(() => pairing.fetchPendingForChild())
        .thenAnswer((_) async => [pending]);

    await controller.load();
    connectivity.isOnline.value = false;

    final result = await controller.declinePairing(pending);

    expect(result, isFalse);
    expect(controller.actionError.value?.code, 'network_error');
    verifyNever(
      () => pairing.respond(
        requestId: any(named: 'requestId'),
        approve: any(named: 'approve'),
      ),
    );
  });

  test('refuses an assistance request that is no longer open', () async {
    final accepted = session(status: RemoteSessionStatus.accepted);

    final result = await controller.declineSession(accepted);

    expect(result, isFalse);
    expect(controller.actionError.value?.code, 'validation_error');
    verifyNever(
      () => remoteSessions.respond(
        sessionId: any(named: 'sessionId'),
        accept: any(named: 'accept'),
      ),
    );
  });

  test('keeps the assistance list when only the pairing source fails',
      () async {
    final open = session();
    when(() => pairing.fetchPendingForChild())
        .thenThrow(Exception('pairing unavailable'));
    when(() => remoteSessions.fetchPendingForChild())
        .thenAnswer((_) async => [open]);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.actionError.value, isNotNull);
    expect(controller.pairingRequests, isEmpty);
    expect(controller.sessionRequests, hasLength(1));
  });
}
