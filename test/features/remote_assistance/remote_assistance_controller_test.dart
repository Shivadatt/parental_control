import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_assistance_controller.dart';

import '../auth/fakes.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

RemoteSession _session({
  String id = 'session-1',
  RemoteSessionStatus status = RemoteSessionStatus.requested,
  DateTime? expiresAt,
}) {
  final now = DateTime.now();
  return RemoteSession(
    id: id,
    familyId: 'family-1',
    deviceId: 'device-1',
    parentUserId: 'parent-1',
    childUserId: 'child-1',
    kind: SessionKind.video,
    status: status,
    requestedAt: now.subtract(const Duration(minutes: 1)),
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5, seconds: 30)),
  );
}

RemoteAssistanceController _controller(_MockRemoteSessionRepository repo) {
  final session = SessionService();
  session.setActiveFamily(testFamily());
  return RemoteAssistanceController(
    remoteSessionRepository: repo,
    session: session,
    deviceId: 'device-1',
  );
}

void main() {
  test('load keeps the server order of sessions', () async {
    final repo = _MockRemoteSessionRepository();
    final first = _session(id: 'session-1');
    final second = _session(id: 'session-2');
    when(() => repo.fetchForFamily('family-1'))
        .thenAnswer((_) async => [first, second]);

    final controller = _controller(repo);
    await controller.load();

    expect(controller.sessions.map((session) => session.id), ['session-1', 'session-2']);
    expect(controller.isLoading.value, isFalse);
    expect(controller.error.value, isNull);
  });

  test('a new request is inserted first without disturbing the rest', () async {
    final repo = _MockRemoteSessionRepository();
    final existing = _session(id: 'session-1');
    final created = _session(id: 'session-2');
    when(() => repo.fetchForFamily('family-1'))
        .thenAnswer((_) async => [existing]);
    when(() => repo.request(
          deviceId: 'device-1',
          kind: SessionKind.audio,
        )).thenAnswer((_) async => created);

    final controller = _controller(repo);
    await controller.load();
    final result = await controller.requestSession(SessionKind.audio);

    expect(result?.id, 'session-2');
    expect(controller.sessions.map((session) => session.id), ['session-2', 'session-1']);
    expect(controller.isRequesting, isFalse);
  });

  test('statusLabel names the server state without claiming media is live', () {
    final controller = _controller(_MockRemoteSessionRepository());

    expect(
      controller.statusLabel(
        _session(status: RemoteSessionStatus.requested),
      ),
      'Waiting for consent',
    );
    expect(
      controller.statusLabel(
        _session(status: RemoteSessionStatus.accepted),
      ),
      'Accepted',
    );
    expect(
      controller.statusLabel(
        _session(status: RemoteSessionStatus.active),
      ),
      'Session active',
    );
    expect(
      controller.statusLabel(
        _session(status: RemoteSessionStatus.ended),
      ),
      'Ended',
    );
    expect(
      controller.statusLabel(
        _session(
          status: RemoteSessionStatus.active,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ),
      'Session active',
    );
    expect(
      controller.statusLabel(
        _session(
          status: RemoteSessionStatus.requested,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      ),
      'Request expired',
    );
  });

  test('no status label claims that audio is live', () {
    for (final status in RemoteSessionStatus.values) {
      expect(status.label.toLowerCase(), isNot('live'));
      expect(status.label.toLowerCase(), isNot(contains('live')));
    }
  });

  test('expiryLabel counts down pending requests and names parent control for '
      'consented sessions', () {
    final controller = _controller(_MockRemoteSessionRepository());
    final soon = DateTime.now().add(const Duration(minutes: 5, seconds: 30));

    expect(
      controller.expiryLabel(
        _session(status: RemoteSessionStatus.requested, expiresAt: soon),
      ),
      'in 5 min',
    );
    expect(
      controller.expiryLabel(
        _session(
          status: RemoteSessionStatus.accepted,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ),
      'Until you end it',
    );
    expect(
      controller.expiryLabel(
        _session(status: RemoteSessionStatus.active),
      ),
      'Until you end it',
    );

    expect(
      controller.expiryLabel(
        _session(status: RemoteSessionStatus.ended),
      ),
      '—',
    );
  });

  test('session cards describe media honestly', () {
    expect(
      _session(status: RemoteSessionStatus.requested).mediaNote,
      contains('Off'),
    );
    expect(
      _session(status: RemoteSessionStatus.accepted).mediaNote,
      contains('waiting for the child to join'),
    );
    expect(
      _session(status: RemoteSessionStatus.active).mediaNote,
      contains('not verified here'),
    );
    expect(
      _session(status: RemoteSessionStatus.declined).mediaNote,
      'No media was opened',
    );
  });

  test('isServerActive follows server status only, never elapsed time', () {
    final active = _session(status: RemoteSessionStatus.active);
    final staleDeadline = _session(
      status: RemoteSessionStatus.active,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final ended = _session(status: RemoteSessionStatus.ended);

    expect(active.isServerActive, isTrue);
    expect(staleDeadline.isServerActive, isTrue);
    expect(ended.isServerActive, isFalse);
  });
}
