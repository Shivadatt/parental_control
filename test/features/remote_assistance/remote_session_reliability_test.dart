import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _FakeRtpSender extends Fake implements RTCRtpSender {}

class _FakeMediaStreamTrack extends Fake implements MediaStreamTrack {
  bool stopped = false;

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakeMediaStream extends Fake implements MediaStream {
  _FakeMediaStream({List<MediaStreamTrack>? audioTracks})
    : _tracks = audioTracks ?? [_FakeMediaStreamTrack()];

  final List<MediaStreamTrack> _tracks;

  @override
  List<MediaStreamTrack> getAudioTracks() => _tracks;

  @override
  List<MediaStreamTrack> getVideoTracks() => const [];

  @override
  List<MediaStreamTrack> getTracks() => _tracks;

  @override
  Future<void> dispose() async {}
}

class _FakePeerConnection extends Fake implements RTCPeerConnection {
  @override
  void Function(RTCTrackEvent)? onTrack;

  @override
  void Function(RTCIceCandidate)? onIceCandidate;

  @override
  void Function(RTCPeerConnectionState)? onConnectionState;

  @override
  void Function(RTCIceConnectionState)? onIceConnectionState;

  final List<MediaStreamTrack> addedTracks = [];
  final List<Map<String, dynamic>> offerConstraints = [];
  final List<Map<String, dynamic>> configurations = [];
  bool closed = false;
  bool disposed = false;
  int restartIceCount = 0;
  int setRemoteDescriptionCount = 0;
  final List<RTCSessionDescription> remoteDescriptions = [];

  @override
  Future<void> setConfiguration(Map<String, dynamic> configuration) async {
    configurations.add(configuration);
  }

  @override
  Future<void> restartIce() async {
    restartIceCount += 1;
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async {
    if (constraints != null) offerConstraints.add(constraints);
    return RTCSessionDescription('offer-sdp-$restartIceCount', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('answer-sdp', 'answer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    setRemoteDescriptionCount += 1;
    remoteDescriptions.add(description);
  }

  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async {
    addedTracks.add(track);
    return _FakeRtpSender();
  }

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {}

  @override
  List<MediaStream> getRemoteStreams() => [];

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => [
    StatsReport('audio-out', 'outbound-rtp', 1.0, {
      'packetsSent': 10,
      'bytesSent': 2000,
      'timestamp': 100,
    }),
    StatsReport('audio-in', 'inbound-rtp', 2.0, {
      'packetsReceived': 8,
      'bytesReceived': 1600,
      'timestamp': 90,
    }),
  ];
}

class _FakeDeviceAdminService extends DeviceAdminService {
  _FakeDeviceAdminService();

  final Map<String, bool> permissions = const {
    'camera': true,
    'microphone': true,
  };
  bool notificationsGranted = true;
  bool oneTimeMicrophoneGrant = false;
  bool microphoneGranted = true;
  bool startResult = true;
  bool emitStarted = true;
  bool emitStartFailed = false;

  int requestCount = 0;
  bool serviceStarted = false;
  bool serviceStopped = false;
  String? startedSessionId;

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void emit(Map<String, dynamic> event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  void dispose() {
    _events.close();
  }

  // Native contract methods are called dynamically until the typed bridge
  // lands, so no @override is attached here.
  // ignore: annotate_overrides
  Future<bool> areNotificationsGranted() async => notificationsGranted;

  // ignore: annotate_overrides
  Future<bool> isMicrophoneOneTimeGrant() async => oneTimeMicrophoneGrant;

  @override
  Future<DeviceCapabilities> getCapabilities() async => DeviceCapabilities(
    available: true,
    microphoneGranted: microphoneGranted,
    notificationsGranted: notificationsGranted,
  );

  @override
  Future<bool> startAudioAssistanceService({required String sessionId}) async {
    serviceStarted = true;
    startedSessionId = sessionId;
    if (!startResult) return false;
    if (emitStarted) {
      scheduleMicrotask(() {
        emit({'type': 'audio_assistance_started', 'sessionId': sessionId});
      });
    }
    if (emitStartFailed) {
      scheduleMicrotask(() {
        emit({
          'type': 'audio_assistance_start_failed',
          'reason': 'notification_permission_missing',
        });
      });
    }
    return true;
  }

  @override
  Future<bool> stopAudioAssistanceService() async {
    serviceStopped = true;
    return true;
  }

  @override
  Future<bool> isAudioAssistanceServiceRunning() async =>
      serviceStarted && !serviceStopped;

  @override
  Future<Map<String, bool>> requestPermissions({
    bool camera = false,
    bool microphone = false,
    bool location = false,
    bool backgroundLocation = false,
    bool notifications = false,
  }) async {
    requestCount += 1;
    return permissions;
  }
}

RemoteSession _session({
  RemoteSessionStatus status = RemoteSessionStatus.accepted,
  SessionKind kind = SessionKind.audio,
  DateTime? requestedAt,
  DateTime? expiresAt,
  DateTime? acceptedAt,
  DateTime? endedAt,
  String? endedReason,
}) => RemoteSession(
  id: 'session-1',
  familyId: 'family-1',
  deviceId: 'device-1',
  parentUserId: 'parent-1',
  childUserId: 'child-1',
  kind: kind,
  status: status,
  requestedAt:
      requestedAt ?? DateTime.now().subtract(const Duration(minutes: 2)),
  expiresAt: expiresAt,
  acceptedAt: acceptedAt,
  endedAt: endedAt,
  endedReason: endedReason,
);

WebRtcSignal _signal({
  required String id,
  required SignalKind kind,
  required Map<String, dynamic> payload,
  DateTime? createdAt,
  int sequence = 1,
  String fromUserId = 'child-1',
}) => WebRtcSignal(
  id: id,
  sessionId: 'session-1',
  fromUserId: fromUserId,
  kind: kind,
  payload: payload,
  createdAt: createdAt ?? DateTime.now(),
  sequence: sequence,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemoteSessionRepository repository;
  late _FakeDeviceAdminService deviceAdmin;
  late _FakePeerConnection peer;
  late List<_FakeMediaStream> capturedStreams;
  late StreamController<List<WebRtcSignal>> signals;
  late RemoteSessionController controller;

  setUpAll(() {
    registerFallbackValue(SignalKind.offer);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(RTCSessionDescription('', 'offer'));
    registerFallbackValue(RTCIceCandidate('', '', 0));
  });

  setUp(() {
    repository = _MockRemoteSessionRepository();
    deviceAdmin = _FakeDeviceAdminService();
    peer = _FakePeerConnection();
    capturedStreams = [];
    signals = StreamController<List<WebRtcSignal>>.broadcast();
    when(
      () => repository.watchSession('session-1'),
    ).thenAnswer((_) => const Stream<RemoteSession>.empty());
    when(
      () => repository.watchSignals('session-1'),
    ).thenAnswer((_) => signals.stream);
    when(() => repository.fetchIceConfig('session-1')).thenAnswer(
      (_) async => const IceConfig(
        iceServers: [
          IceServerConfig(urls: ['stun:stun.l.google.com:19302']),
        ],
      ),
    );
    when(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.markActive('session-1'),
    ).thenAnswer((_) async => _session(status: RemoteSessionStatus.active));
    when(
      () => repository.end(sessionId: any(named: 'sessionId')),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    controller.onClose();
    deviceAdmin.dispose();
    if (!signals.isClosed) signals.close();
  });

  RemoteSessionController buildController({
    String role = 'child',
    Duration serviceStartTimeout = const Duration(seconds: 5),
    Duration permissionPollInterval = const Duration(seconds: 2),
    List<Duration> iceRestartBackoff = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
    ],
    Duration iceRestartAttemptCap = const Duration(seconds: 20),
    List<Duration> signalRetryBackoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ],
    Duration childReadyCooldown = const Duration(seconds: 3),
    Duration rejoinDebounce = const Duration(seconds: 2),
  }) {
    return RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: role,
      serviceStartTimeout: serviceStartTimeout,
      permissionPollInterval: permissionPollInterval,
      iceRestartBackoff: iceRestartBackoff,
      iceRestartAttemptCap: iceRestartAttemptCap,
      signalRetryBackoff: signalRetryBackoff,
      childReadyCooldown: childReadyCooldown,
      // Recovery-budget tests drive retries at millisecond scale and assert the
      // bounded retry count, not the production debounce window (covered by
      // remote_session_audio_lifecycle_test.dart).
      rejoinDebounce: rejoinDebounce,
      peerConnectionFactory: (config) async => peer,
      userMediaCapture: (constraints) async {
        final stream = _FakeMediaStream();
        capturedStreams.add(stream);
        return stream;
      },
    );
  }

  Future<void> loadAccepted() async {
    when(
      () => repository.fetchById('session-1'),
    ).thenAnswer((_) async => _session());
    await controller.load();
  }

  test(
    'service start false aborts join with no peer, tracks or capture',
    () async {
      deviceAdmin.startResult = false;
      controller = buildController();
      await loadAccepted();

      await controller.join();

      expect(controller.actionError.value?.code, 'microphone_service_failed');
      expect(controller.hasActivePeer.value, isFalse);
      expect(controller.isJoining.value, isFalse);
      expect(controller.isMediaLive, isFalse);
      expect(capturedStreams, isEmpty);
      expect(peer.addedTracks, isEmpty);
      expect(deviceAdmin.serviceStopped, isTrue);
      verifyNever(
        () => repository.sendSignal(
          sessionId: any(named: 'sessionId'),
          kind: any(named: 'kind'),
          payload: any(named: 'payload'),
        ),
      );
    },
  );

  test(
    'service start confirmation timeout aborts join and stops the service',
    () async {
      deviceAdmin.emitStarted = false;
      controller = buildController(
        serviceStartTimeout: const Duration(milliseconds: 25),
      );
      await loadAccepted();

      await controller.join();

      expect(controller.actionError.value?.code, 'microphone_service_failed');
      expect(controller.actionError.value?.message, contains('stayed off'));
      expect(capturedStreams, isEmpty);
      expect(controller.hasActivePeer.value, isFalse);
      expect(deviceAdmin.serviceStopped, isTrue);
    },
  );

  test('audio_assistance_start_failed aborts join before capture', () async {
    deviceAdmin.emitStarted = false;
    deviceAdmin.emitStartFailed = true;
    controller = buildController();
    await loadAccepted();

    await controller.join();

    expect(controller.actionError.value?.code, 'microphone_service_failed');
    expect(
      controller.actionError.value?.message,
      contains('notification_permission_missing'),
    );
    expect(capturedStreams, isEmpty);
    expect(peer.addedTracks, isEmpty);
    expect(controller.hasActivePeer.value, isFalse);
    expect(deviceAdmin.serviceStopped, isTrue);
  });

  test('one-time microphone grant is rejected before capture', () async {
    deviceAdmin.oneTimeMicrophoneGrant = true;
    controller = buildController();
    await loadAccepted();

    await controller.join();

    expect(controller.actionError.value?.code, 'microphone_one_time');
    expect(
      controller.actionError.value?.message,
      contains('While using the app'),
    );
    expect(capturedStreams, isEmpty);
    expect(deviceAdmin.serviceStarted, isFalse);
  });

  test(
    'missing role is view-only and cannot request permissions or capture',
    () async {
      controller = buildController(role: '');
      await loadAccepted();

      expect(controller.isViewOnly, isTrue);
      expect(controller.canJoin, isFalse);

      await controller.join();

      expect(controller.actionError.value?.code, AppErrorCodes.forbidden);
      expect(deviceAdmin.requestCount, 0);
      expect(deviceAdmin.serviceStarted, isFalse);
      expect(capturedStreams, isEmpty);
      expect(controller.hasActivePeer.value, isFalse);
    },
  );

  test(
    'isMediaLive requires both live capture and confirmed service',
    () async {
      controller = buildController();
      await loadAccepted();

      expect(controller.isMediaLive, isFalse);

      await controller.join();
      expect(controller.isMediaLive, isTrue);

      deviceAdmin.emit({
        'type': 'audio_assistance_stopped',
        'reason': 'service_destroyed',
      });
      await pumpEventQueue(times: 20);

      expect(controller.isMediaLive, isFalse);
      expect(controller.session.value?.status, RemoteSessionStatus.active);
      expect(controller.session.value?.endedReason, isNull);
      expect(controller.sharingStopped.value, isTrue);
      expect(controller.permissionDenied.value, isFalse);
      verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    },
  );

  test('capture is reported on before any audio RTP arrives', () async {
    controller = buildController();
    await loadAccepted();
    expect(controller.isCaptureActive, isFalse);
    expect(controller.isCapturing.value, isFalse);

    await controller.join();

    // getUserMedia returned and the microphone service is confirmed, but no
    // RTP sample has proven audio flow: the microphone is on, not off.
    expect(controller.isCaptureActive, isTrue);
    expect(controller.isCapturing.value, isTrue);
    expect(controller.isMediaFlowing.value, isFalse);
    expect(capturedStreams, hasLength(1));
  });

  test('microphone permission loss mid-session stops capture but not the '
      'server session', () async {
    controller = buildController(
      permissionPollInterval: const Duration(milliseconds: 10),
    );
    await loadAccepted();
    await controller.join();

    final stream = capturedStreams.single;
    final track = stream.getAudioTracks().single as _FakeMediaStreamTrack;
    expect(controller.isMediaLive, isTrue);

    deviceAdmin.microphoneGranted = false;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await pumpEventQueue(times: 20);

    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.permissionDenied.value, isTrue);
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.actionError.value?.code, 'permission_revoked');
    expect(track.stopped, isTrue);
    expect(deviceAdmin.serviceStopped, isTrue);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaLive, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('ICE failure asks the parent twice then pauses media without ending '
      'the session', () async {
    controller = buildController(
      iceRestartBackoff: const [Duration.zero, Duration.zero],
      iceRestartAttemptCap: const Duration(milliseconds: 20),
      rejoinDebounce: Duration.zero,
    );
    await loadAccepted();
    await controller.join();
    expect(controller.hasActivePeer.value, isTrue);

    peer.onConnectionState!(
      RTCPeerConnectionState.RTCPeerConnectionStateFailed,
    );
    expect(controller.connectionWarning.value, contains('failed'));

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await pumpEventQueue(times: 20);

    // The child never negotiates on its own; it asks the parent to offer.
    final offers = verify(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: captureAny(named: 'payload'),
      ),
    ).captured;
    // One readiness from the visible join plus two bounded recovery requests.
    expect(offers, hasLength(3));
    for (final payload in offers) {
      expect((payload as Map<String, dynamic>)['ready'], isTrue);
    }
    expect(peer.restartIceCount, 0);
    expect(peer.remoteDescriptions, isEmpty);
    expect(peer.closed, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.iceError.value?.code, 'media_connection_failed');
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.hasActivePeer.value, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('signaling stream error resubscribes with backoff and the banner clears '
      'when the channel is re-established', () async {
    var signalSubscriptions = 0;
    final recovered = StreamController<List<WebRtcSignal>>.broadcast();
    addTearDown(recovered.close);
    when(() => repository.watchSignals('session-1')).thenAnswer((_) {
      signalSubscriptions += 1;
      if (signalSubscriptions == 1) {
        return Stream<List<WebRtcSignal>>.error(
          const AppException('network_error', 'signaling disconnected'),
        );
      }
      return recovered.stream;
    });
    controller = buildController(
      role: 'parent',
      signalRetryBackoff: const [
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );
    when(
      () => repository.fetchById('session-1'),
    ).thenAnswer((_) async => _session());
    await controller.load();

    await pumpEventQueue(times: 30);

    expect(signalSubscriptions, greaterThanOrEqualTo(2));
    expect(controller.realtimeError.value, isNotNull);

    // The repository emits an empty batch when the channel subscribes again;
    // no new signal row is needed to clear the stale interruption banner.
    recovered.add(const <WebRtcSignal>[]);
    await pumpEventQueue();

    expect(controller.realtimeError.value, isNull);
  });

  test('a successful reload clears a stale realtime banner', () async {
    final signals = StreamController<List<WebRtcSignal>>.broadcast();
    addTearDown(signals.close);
    when(
      () => repository.watchSignals('session-1'),
    ).thenAnswer((_) => signals.stream);
    when(
      () => repository.fetchById('session-1'),
    ).thenAnswer((_) async => _session());
    controller = buildController(role: 'parent');
    await controller.load();
    await pumpEventQueue();

    signals.addError(
      const AppException('network_error', 'live updates disconnected'),
    );
    await pumpEventQueue();
    expect(controller.realtimeError.value, isNotNull);

    await controller.load(showLoading: false);

    expect(controller.realtimeError.value, isNull);
  });

  test('endSession returns false and keeps the session open when the server '
      'end throws', () async {
    when(
      () => repository.end(sessionId: 'session-1'),
    ).thenThrow(const AppException('network_error', 'offline'));
    controller = buildController(role: 'parent');
    await loadAccepted();
    await controller.join();

    final ended = await controller.endSession();

    expect(ended, isFalse);
    expect(controller.endError, isNotNull);
    expect(controller.actionError.value, isNotNull);
    expect(controller.isEnding.value, isFalse);
    expect(controller.session.value?.status.isTerminal, isFalse);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaLive, isFalse);
  });

  test(
    'endSession returns true only after the server confirms the end',
    () async {
      controller = buildController(role: 'parent');
      await loadAccepted();
      await controller.join();

      final ended = await controller.endSession();

      expect(ended, isTrue);
      expect(controller.session.value?.status, RemoteSessionStatus.ended);
      expect(controller.session.value?.endedReason, 'ended_by_parent');
      expect(controller.endError, isNull);
      expect(controller.hasActivePeer.value, isFalse);
      verify(() => repository.end(sessionId: 'session-1')).called(1);
    },
  );

  test('child cannot end the server session', () async {
    controller = buildController();
    await loadAccepted();
    await controller.join();

    final ended = await controller.endSession();

    expect(ended, isFalse);
    expect(controller.actionError.value?.code, AppErrorCodes.forbidden);
    expect(controller.session.value?.status.isTerminal, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test(
    'pending request expiry comes from server state and opens no media',
    () async {
      when(() => repository.fetchById('session-1')).thenAnswer(
        (_) async => _session(
          status: RemoteSessionStatus.requested,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      );
      controller = buildController();
      await controller.load();

      expect(controller.statusLabel, 'Request expired');
      expect(controller.canJoin, isFalse);
      expect(controller.isExpired, isTrue);

      await controller.join();

      expect(capturedStreams, isEmpty);
      expect(controller.hasActivePeer.value, isFalse);
      verifyNever(() => repository.fetchIceConfig('session-1'));
      verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    },
  );

  test('a multi-day accepted session is still open and elapsed time never ends '
      'it', () async {
    final acceptedAt = DateTime.now().subtract(const Duration(days: 3));
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async =>
          _session(status: RemoteSessionStatus.active, acceptedAt: acceptedAt),
    );
    controller = buildController(role: 'parent');
    await controller.load();

    expect(controller.statusLabel, 'Session active');
    expect(controller.sessionDurationLabel, 'Until you end the session');
    expect(controller.elapsedLabel, isNot('—'));
    expect(controller.canJoin, isTrue);
    expect(controller.isExpired, isFalse);

    // Advancing the informational clock a day further changes nothing.
    controller.now.value = DateTime.now().add(const Duration(days: 1));
    await pumpEventQueue(times: 5);

    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.isExpired, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('a late realtime update cannot revive a terminal session', () async {
    final updates = StreamController<RemoteSession>();
    when(
      () => repository.watchSession('session-1'),
    ).thenAnswer((_) => updates.stream);
    controller = buildController(role: 'parent');
    await loadAccepted();

    updates.add(
      _session(
        status: RemoteSessionStatus.ended,
        endedAt: DateTime.now(),
        endedReason: 'ended_by_parent',
      ),
    );
    await pumpEventQueue(times: 10);
    expect(controller.session.value?.status, RemoteSessionStatus.ended);

    updates.add(_session(status: RemoteSessionStatus.active));
    await pumpEventQueue(times: 10);

    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'ended_by_parent');
    expect(controller.canJoin, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    await updates.close();
  });

  test('ending an already terminal session is idempotent and sends no second '
      'end call', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.ended,
        endedAt: DateTime.now(),
        endedReason: 'ended_by_parent',
      ),
    );
    controller = buildController(role: 'parent');
    await controller.load();

    expect(await controller.endSession(), isTrue);
    expect(await controller.endSession(), isTrue);

    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'ended_by_parent');
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test(
    'ICE restart reissues expiring TURN credentials through the backend',
    () async {
      var iceCalls = 0;
      when(() => repository.fetchIceConfig('session-1')).thenAnswer((_) async {
        iceCalls += 1;
        if (iceCalls == 1) {
          return IceConfig(
            iceServers: const [
              IceServerConfig(
                urls: ['turn:stale.example:3478'],
                username: 'stale-user',
                credential: 'stale-credential',
              ),
            ],
            turnConfigured: true,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          );
        }
        return IceConfig(
          iceServers: const [
            IceServerConfig(
              urls: ['turn:fresh.example:3478'],
              username: 'fresh-user',
              credential: 'fresh-credential',
            ),
          ],
          turnConfigured: true,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );
      });
      controller = buildController(
        role: 'parent',
        iceRestartBackoff: const [Duration.zero],
        iceRestartAttemptCap: const Duration(seconds: 5),
      );
      await loadAccepted();
      await pumpEventQueue(times: 5);
      await controller.join();
      expect(iceCalls, 1);

      peer.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateFailed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await pumpEventQueue(times: 20);

      expect(iceCalls, 2);
      expect(peer.restartIceCount, 1);
      expect(peer.configurations, isNotEmpty);
      final servers =
          peer.configurations.last['iceServers'] as List<Map<String, dynamic>>;
      expect(servers.first['urls'], ['turn:fresh.example:3478']);
      expect(controller.session.value?.status.isTerminal, isFalse);
      verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    },
  );

  test('parent join never requests the microphone, captures, or starts the '
      'foreground service', () async {
    controller = buildController(role: 'parent');
    await loadAccepted();

    await controller.join();

    expect(controller.hasActivePeer.value, isTrue);
    expect(capturedStreams, isEmpty);
    expect(deviceAdmin.requestCount, 0);
    expect(deviceAdmin.serviceStarted, isFalse);
    expect(peer.addedTracks, isEmpty);
    expect(controller.isMediaLive, isFalse);
  });

  group('automatic media recovery', () {
    const readyPayload = {'ready': true, 'sdp': '', 'type': 'offer'};

    test(
      'parent with no peer negotiates again when the child is ready',
      () async {
        controller = buildController(role: 'parent');
        await loadAccepted();

        signals.add([
          _signal(id: 'ready-1', kind: SignalKind.offer, payload: readyPayload),
        ]);
        await pumpEventQueue(times: 40);

        final offers = verify(
          () => repository.sendSignal(
            sessionId: 'session-1',
            kind: SignalKind.offer,
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(offers, hasLength(1));
        final offer = offers.single as Map<String, dynamic>;
        expect(offer['ready'], isNot(true));
        expect((offer['sdp'] as String?)?.isNotEmpty, isTrue);
        expect(controller.hasActivePeer.value, isTrue);
        // The parent is receive-only: no permission, service or capture.
        expect(deviceAdmin.requestCount, 0);
        expect(deviceAdmin.serviceStarted, isFalse);
        expect(capturedStreams, isEmpty);
        expect(peer.addedTracks, isEmpty);
      },
    );

    test(
      'parent with a disconnected peer restarts ICE and re-offers',
      () async {
        controller = buildController(role: 'parent');
        await loadAccepted();
        await controller.join();
        expect(controller.hasActivePeer.value, isTrue);

        // Complete the first negotiation so no local offer is pending.
        signals.add([
          _signal(
            id: 'answer-1',
            kind: SignalKind.answer,
            payload: const {'sdp': 'answer-sdp', 'type': 'answer'},
          ),
        ]);
        await pumpEventQueue(times: 20);
        expect(peer.setRemoteDescriptionCount, 1);

        peer.onConnectionState!(
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
        );
        await Future<void>.delayed(Duration.zero);

        signals.add([
          _signal(id: 'ready-2', kind: SignalKind.offer, payload: readyPayload),
        ]);
        await pumpEventQueue(times: 40);

        expect(peer.restartIceCount, 1);
        verify(
          () => repository.sendSignal(
            sessionId: 'session-1',
            kind: SignalKind.offer,
            payload: any(named: 'payload'),
          ),
        ).called(2);
        expect(controller.hasActivePeer.value, isTrue);
      },
    );

    test(
      'child recovery asks the parent to renegotiate instead of offering',
      () async {
        controller = buildController(
          iceRestartBackoff: const [Duration(milliseconds: 20)],
          rejoinDebounce: Duration.zero,
        );
        await loadAccepted();
        await controller.join();
        await pumpEventQueue(times: 20);
        expect(controller.hasActivePeer.value, isTrue);

        peer.onConnectionState!(
          RTCPeerConnectionState.RTCPeerConnectionStateFailed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await pumpEventQueue(times: 20);

        // Only readiness requests (empty SDP), never a competing offer.
        final offers = verify(
          () => repository.sendSignal(
            sessionId: 'session-1',
            kind: SignalKind.offer,
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(offers, hasLength(2));
        for (final payload in offers) {
          expect((payload as Map<String, dynamic>)['ready'], isTrue);
          expect(payload['sdp'], '');
        }
        expect(peer.restartIceCount, 0);
        expect(peer.remoteDescriptions, isEmpty);
        verifyNever(
          () => repository.sendSignal(
            sessionId: any(named: 'sessionId'),
            kind: SignalKind.answer,
            payload: any(named: 'payload'),
          ),
        );
      },
    );

    test(
      'parent with a pending offer ignores a competing remote offer',
      () async {
        controller = buildController(role: 'parent');
        await loadAccepted();
        await controller.join();
        await pumpEventQueue(times: 10);

        signals.add([
          _signal(
            id: 'child-offer',
            kind: SignalKind.offer,
            payload: const {
              'sdp': 'child-offer-sdp',
              'type': 'offer',
              'gen': 9,
            },
            createdAt: DateTime.now(),
          ),
        ]);
        await pumpEventQueue(times: 20);

        // Answering would hit libwebrtc's have-local-offer INVALID_STATE.
        expect(peer.setRemoteDescriptionCount, 0);
        verifyNever(
          () => repository.sendSignal(
            sessionId: any(named: 'sessionId'),
            kind: SignalKind.answer,
            payload: any(named: 'payload'),
          ),
        );
      },
    );

    test(
      'child join with no buffered offer announces readiness once',
      () async {
        controller = buildController();
        await loadAccepted();

        await controller.join();
        await pumpEventQueue(times: 20);

        final announced = verify(
          () => repository.sendSignal(
            sessionId: 'session-1',
            kind: SignalKind.offer,
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(announced, hasLength(1));
        final payload = announced.single as Map<String, dynamic>;
        expect(payload['ready'], isTrue);
        expect(payload['sdp'], '');
        expect(peer.setRemoteDescriptionCount, 0);
        expect(controller.hasActivePeer.value, isTrue);
      },
    );

    test(
      'child join answers a buffered fresh offer without a readiness signal',
      () async {
        controller = buildController();
        await loadAccepted();

        signals.add([
          _signal(
            id: 'offer-fresh',
            kind: SignalKind.offer,
            payload: const {'sdp': 'remote-offer-sdp', 'type': 'offer'},
            createdAt: DateTime.now(),
          ),
        ]);
        await pumpEventQueue(times: 10);

        await controller.join();
        await pumpEventQueue(times: 20);

        expect(peer.setRemoteDescriptionCount, 1);
        expect(peer.remoteDescriptions.single.sdp, 'remote-offer-sdp');
        final answers = verify(
          () => repository.sendSignal(
            sessionId: 'session-1',
            kind: SignalKind.answer,
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(answers, hasLength(1));
        expect((answers.single as Map<String, dynamic>)['ready'], isNull);
        // No readiness request: the buffered offer was answered instead.
        verifyNever(
          () => repository.sendSignal(
            sessionId: any(named: 'sessionId'),
            kind: SignalKind.offer,
            payload: any(named: 'payload'),
          ),
        );
      },
    );

    test('a replayed stale offer is neither buffered nor answered', () async {
      controller = buildController();
      await loadAccepted();

      signals.add([
        _signal(
          id: 'offer-stale',
          kind: SignalKind.offer,
          payload: const {'sdp': 'stale-offer-sdp', 'type': 'offer'},
          createdAt: DateTime.now().subtract(const Duration(seconds: 60)),
        ),
      ]);
      await pumpEventQueue(times: 10);

      await controller.join();
      await pumpEventQueue(times: 20);

      expect(peer.setRemoteDescriptionCount, 0);
      final announced = verify(
        () => repository.sendSignal(
          sessionId: 'session-1',
          kind: SignalKind.offer,
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(announced, hasLength(1));
      expect((announced.single as Map<String, dynamic>)['ready'], isTrue);
    });

    test('an answer with no pending local offer is ignored', () async {
      controller = buildController(role: 'parent');
      await loadAccepted();

      signals.add([
        _signal(
          id: 'answer-early',
          kind: SignalKind.answer,
          payload: const {'sdp': 'early-answer', 'type': 'answer'},
        ),
      ]);
      await pumpEventQueue(times: 10);
      expect(peer.setRemoteDescriptionCount, 0);

      await controller.join();
      expect(controller.hasActivePeer.value, isTrue);

      signals.add([
        _signal(
          id: 'answer-1',
          kind: SignalKind.answer,
          payload: const {'sdp': 'first-answer', 'type': 'answer'},
        ),
      ]);
      await pumpEventQueue(times: 10);
      expect(peer.setRemoteDescriptionCount, 1);

      signals.add([
        _signal(
          id: 'answer-2',
          kind: SignalKind.answer,
          payload: const {'sdp': 'second-answer', 'type': 'answer'},
        ),
      ]);
      await pumpEventQueue(times: 10);
      expect(peer.setRemoteDescriptionCount, 1);
      expect(peer.remoteDescriptions.single.sdp, 'first-answer');
    });

    test('reconcile after resume re-joins a parent with no peer', () async {
      controller = buildController(role: 'parent');
      await loadAccepted();

      await controller.reconcileAfterResume();
      await pumpEventQueue(times: 40);

      expect(controller.hasActivePeer.value, isTrue);
      verify(
        () => repository.sendSignal(
          sessionId: 'session-1',
          kind: SignalKind.offer,
          payload: any(named: 'payload'),
        ),
      ).called(1);
      expect(deviceAdmin.requestCount, 0);
      expect(capturedStreams, isEmpty);
    });

    test(
      'reconcile after resume never starts capture for a child without it',
      () async {
        controller = buildController();
        await loadAccepted();

        await controller.reconcileAfterResume();
        await pumpEventQueue(times: 30);

        expect(deviceAdmin.requestCount, 0);
        expect(deviceAdmin.serviceStarted, isFalse);
        expect(capturedStreams, isEmpty);
        expect(controller.hasActivePeer.value, isFalse);
        verifyNever(
          () => repository.sendSignal(
            sessionId: any(named: 'sessionId'),
            kind: any(named: 'kind'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );
  });
}
