import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

RemoteSession _session({
  required RemoteSessionStatus status,
  required DateTime expiresAt,
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
      expiresAt: expiresAt,
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
    when(() => repository.end(
          sessionId: 'session-1',
          reason: any(named: 'reason'),
        )).thenAnswer((_) async {});
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      sessionId: 'session-1',
      role: 'parent',
    );
  });

  tearDown(() => controller.onClose());

  test('does not fetch ICE or send signals before the child accepts', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.requested,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );

    await controller.load();
    expect(controller.canJoin, isFalse);

    await controller.join();

    expect(controller.actionError.value?.code, 'consent_required');
    expect(controller.actionError.value?.message, contains('has not accepted'));
    verifyNever(() => repository.fetchIceConfig('session-1'));
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('shows a declined session as declined and never opens media', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.declined,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );

    await controller.load();

    expect(controller.statusLabel, 'Declined');
    expect(controller.canJoin, isFalse);
    expect(controller.canEnd, isFalse);

    await controller.join();

    expect(controller.actionError.value?.code, 'consent_required');
    verifyNever(() => repository.fetchIceConfig('session-1'));
  });

  test('treats an accepted session past its expiry as expired and refuses media',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    await controller.load();

    expect(controller.statusLabel, 'Expired');
    expect(controller.canJoin, isFalse);
    verify(() => repository.end(sessionId: 'session-1', reason: 'expired'))
        .called(1);

    await controller.join();

    expect(controller.actionError.value?.code, 'consent_required');
    expect(controller.actionError.value?.message, contains('expired'));
    verifyNever(() => repository.fetchIceConfig('session-1'));
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });
}
