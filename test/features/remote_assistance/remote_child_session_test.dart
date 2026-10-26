import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

RemoteSession _session({
  RemoteSessionStatus status = RemoteSessionStatus.requested,
  Duration expiresIn = const Duration(minutes: 10),
}) =>
    RemoteSession(
      id: 'session-1',
      familyId: 'family-1',
      deviceId: 'device-1',
      parentUserId: 'parent-1',
      childUserId: 'child-1',
      kind: SessionKind.video,
      status: status,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      expiresAt: DateTime.now().add(expiresIn),
    );

void main() {
  late _MockRemoteSessionRepository repository;
  late RemoteSessionController controller;

  setUpAll(() {
    registerFallbackValue(SignalKind.offer);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = _MockRemoteSessionRepository();
    when(() => repository.watchSession('session-1'))
        .thenAnswer((_) => const Stream<RemoteSession>.empty());
    when(() => repository.watchSignals('session-1'))
        .thenAnswer((_) => const Stream<List<WebRtcSignal>>.empty());
    when(() => repository.fetchIceConfig('session-1')).thenAnswer(
      (_) async => const IceConfig(
        iceServers: [
          IceServerConfig(urls: ['stun:stun.l.google.com:19302']),
        ],
      ),
    );
    when(
      () => repository.end(
        sessionId: any(named: 'sessionId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      sessionId: 'session-1',
      role: 'child',
    );
  });

  tearDown(() => controller.onClose());

  test('child cannot start media before accepting the request', () async {
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());

    await controller.load();
    expect(controller.canJoin, isFalse);

    await controller.join();

    expect(controller.actionError.value?.code, 'consent_required');
    expect(
      controller.actionError.value?.message,
      contains('Accept this request'),
    );
    expect(controller.hasActivePeer.value, isFalse);
    verifyNever(() => repository.fetchIceConfig('session-1'));
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('accepting only records consent and opens no media or negotiation',
      () async {
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());
    when(
      () => repository.respond(sessionId: 'session-1', accept: true),
    ).thenAnswer(
      (_) async => _session(status: RemoteSessionStatus.accepted),
    );

    await controller.load();
    final result = await controller.respond(accept: true);

    expect(result, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.accepted);
    expect(controller.isResponding.value, isFalse);
    expect(controller.canJoin, isTrue);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isConnected.value, isFalse);
    expect(controller.isRemoteVideoActive.value, isFalse);
    expect(controller.permissionDenied.value, isFalse);
    verify(
      () => repository.respond(sessionId: 'session-1', accept: true),
    ).called(1);
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('declining keeps media off and stops the session', () async {
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());
    when(
      () => repository.respond(sessionId: 'session-1', accept: false),
    ).thenAnswer(
      (_) async => _session(status: RemoteSessionStatus.declined),
    );

    await controller.load();
    final result = await controller.respond(accept: false);

    expect(result, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.declined);
    expect(controller.canJoin, isFalse);
    expect(controller.isResponding.value, isFalse);
    verifyNever(() => repository.fetchIceConfig('session-1'));
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('the parent side cannot answer a request for the child', () async {
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      sessionId: 'session-1',
      role: 'parent',
    );
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());

    await controller.load();
    final result = await controller.respond(accept: true);

    expect(result, isFalse);
    expect(controller.actionError.value?.code, 'forbidden');
    verifyNever(
      () => repository.respond(
        sessionId: any(named: 'sessionId'),
        accept: any(named: 'accept'),
      ),
    );
  });

  test('an expired request cannot be accepted or start media', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(expiresIn: const Duration(minutes: -1)),
    );

    await controller.load();
    final result = await controller.respond(accept: true);

    expect(result, isFalse);
    expect(controller.actionError.value?.code, 'session_expired');
    expect(controller.canJoin, isFalse);
    verifyNever(
      () => repository.respond(
        sessionId: any(named: 'sessionId'),
        accept: any(named: 'accept'),
      ),
    );
    verifyNever(() => repository.fetchIceConfig('session-1'));
  });

  test('accepting an already accepted session is idempotent', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(status: RemoteSessionStatus.accepted),
    );

    await controller.load();
    final result = await controller.respond(accept: true);

    expect(result, isTrue);
    verifyNever(
      () => repository.respond(
        sessionId: any(named: 'sessionId'),
        accept: any(named: 'accept'),
      ),
    );
  });
}
