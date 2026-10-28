import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _FakeRtpSender extends Fake implements RTCRtpSender {}

class _FakeMediaStreamTrack extends Fake implements MediaStreamTrack {}

class _FakeMediaStream extends Fake implements MediaStream {
  _FakeMediaStream({this.audioTracks = const []});
  final List<MediaStreamTrack> audioTracks;

  @override
  List<MediaStreamTrack> getAudioTracks() => audioTracks;

  @override
  List<MediaStreamTrack> getVideoTracks() => const [];

  @override
  List<MediaStreamTrack> getTracks() => audioTracks;

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
  Map<String, dynamic>? createOfferConstraints;
  bool closed = false;
  bool disposed = false;
  int restartIceCount = 0;

  @override
  Future<void> restartIce() async {
    restartIceCount += 1;
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async {
    createOfferConstraints = constraints;
    return RTCSessionDescription('dummy-sdp-offer', 'offer');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}

  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async {
    addedTracks.add(track);
    return _FakeRtpSender();
  }

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
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    return [
      StatsReport('audio-inbound', 'inbound-rtp', 12345.0, {
        'jitter': '0.015',
        'packetsLost': '0',
        'roundTripTime': '0.045',
      }),
    ];
  }
}

class _FakeDeviceAdminService extends DeviceAdminService {
  _FakeDeviceAdminService({
    this.permissions = const {'camera': true, 'microphone': true},
  });

  final Map<String, bool> permissions;
  final bool notificationsGranted = true;
  final bool oneTimeMicrophoneGrant = false;
  final bool audioServiceStartResult = true;
  final bool emitStartedEvent = true;
  int requestCount = 0;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void emitNativeEvent(Map<String, dynamic> event) {
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }

  // New native contract methods. They are invoked dynamically by the
  // controller while the Android agent lands the typed bridge.
  // ignore: annotate_overrides
  Future<bool> areNotificationsGranted() async => notificationsGranted;

  // ignore: annotate_overrides
  Future<bool> isMicrophoneOneTimeGrant() async => oneTimeMicrophoneGrant;

  bool audioServiceStarted = false;
  String? audioServiceSessionId;
  bool audioServiceStopped = false;

  @override
  Future<bool> startAudioAssistanceService({required String sessionId}) async {
    audioServiceStarted = true;
    audioServiceSessionId = sessionId;
    audioServiceStopped = false;
    if (!audioServiceStartResult) return false;
    if (emitStartedEvent) {
      scheduleMicrotask(() {
        if (_eventController.isClosed) return;
        _eventController.add({
          'type': 'audio_assistance_started',
          'sessionId': sessionId,
        });
      });
    }
    return true;
  }

  @override
  Future<bool> stopAudioAssistanceService() async {
    audioServiceStopped = true;
    return true;
  }

  @override
  Future<bool> isAudioAssistanceServiceRunning() async =>
      audioServiceStarted && !audioServiceStopped;

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
  required RemoteSessionStatus status,
  required DateTime expiresAt,
  SessionKind kind = SessionKind.audio,
}) => RemoteSession(
  id: 'session-1',
  familyId: 'family-1',
  deviceId: 'device-1',
  parentUserId: 'parent-1',
  childUserId: 'child-1',
  kind: kind,
  status: status,
  requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
  expiresAt: expiresAt,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockRemoteSessionRepository repository;
  late _FakeDeviceAdminService deviceAdmin;
  late RemoteSessionController controller;

  setUpAll(() {
    registerFallbackValue(SignalKind.offer);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(RTCSessionDescription('', 'offer'));
  });

  setUp(() {
    repository = _MockRemoteSessionRepository();
    deviceAdmin = _FakeDeviceAdminService();
    when(
      () => repository.watchSession('session-1'),
    ).thenAnswer((_) => const Stream<RemoteSession>.empty());
    when(
      () => repository.watchSignals('session-1'),
    ).thenAnswer((_) => const Stream<List<WebRtcSignal>>.empty());
    when(() => repository.fetchIceConfig('session-1')).thenAnswer(
      (_) async => const IceConfig(
        iceServers: [
          IceServerConfig(urls: ['stun:stun.l.google.com:19302']),
        ],
      ),
    );
    when(
      () => repository.end(
        sessionId: 'session-1',
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
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

  test(
    'treats an accepted session past its expiry as expired and refuses media',
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
      verify(
        () => repository.end(sessionId: 'session-1', reason: 'expired'),
      ).called(1);

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
    },
  );

  test('stops local media even when the server end call fails', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
    when(
      () => repository.end(
        sessionId: 'session-1',
        reason: any(named: 'reason'),
      ),
    ).thenThrow(const AppException('network_error', 'The network is offline.'));

    await controller.load();
    controller.hasActivePeer.value = true;
    await controller.endSession();

    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isConnected.value, isFalse);
    expect(controller.isEnding.value, isFalse);
    expect(controller.actionError.value, isNotNull);
    expect(controller.session.value?.status, RemoteSessionStatus.accepted);
  });

  test('child asks Android for camera and microphone before opening media',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.video,
      ),
    );
    deviceAdmin = _FakeDeviceAdminService(
      permissions: const {'camera': false, 'microphone': true},
    );
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
    );

    await controller.load();
    await controller.join();

    expect(deviceAdmin.requestCount, 1);
    expect(controller.permissionDenied.value, isTrue);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isJoining.value, isFalse);
    verifyNever(
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test(
      'parent joins without microphone capture or permission requests and does not publish audio',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    deviceAdmin = _FakeDeviceAdminService(
      permissions: const {'camera': false, 'microphone': false},
    );
    final fakePeer = _FakePeerConnection();
    bool userMediaCalled = false;
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      peerConnectionFactory: (config) async => fakePeer,
      userMediaCapture: (constraints) async {
        userMediaCalled = true;
        return _FakeMediaStream();
      },
    );

    await controller.load();
    await controller.join();

    // 1. Parent never requested mic permission from the OS:
    expect(deviceAdmin.requestCount, 0);
    expect(controller.permissionDenied.value, isFalse);

    // 2. Parent never called getUserMedia for local audio:
    expect(userMediaCalled, isFalse);

    // 3. Parent never published an outgoing track:
    expect(fakePeer.addedTracks, isEmpty);

    // 4. Parent creates receive-only offer and sends offer signal:
    expect(fakePeer.createOfferConstraints, isNotNull);
    final constraints = fakePeer.createOfferConstraints!;
    expect(constraints['mandatory']['OfferToReceiveAudio'], isTrue);
    expect(constraints['mandatory']['OfferToReceiveVideo'], isFalse);

    verify(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: any(named: 'payload'),
      ),
    ).called(1);
    expect(controller.hasActivePeer.value, isTrue);
  });

  test(
      'parent incoming audio attachment routes to loudspeaker and teardown restores route',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    final fakePeer = _FakePeerConnection();
    final speakerphoneCalls = <bool>[];
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      peerConnectionFactory: (config) async => fakePeer,
      speakerphoneHandler: (enable) async {
        speakerphoneCalls.add(enable);
      },
    );

    await controller.load();
    await controller.join();

    // Verify onTrack callback is registered
    expect(fakePeer.onTrack, isNotNull);

    // Simulate incoming child stream with an audio track
    final audioTrack = _FakeMediaStreamTrack();
    final incomingStream = _FakeMediaStream(audioTracks: [audioTrack]);

    fakePeer.onTrack!(
      RTCTrackEvent(
        streams: [incomingStream],
        track: audioTrack,
      ),
    );
    await pumpEventQueue();

    // Loudspeaker must be turned on upon receiving child audio:
    expect(speakerphoneCalls, contains(true));

    // Teardown restores the prior audio route:
    await controller.endSession();
    expect(speakerphoneCalls.last, isFalse);
    expect(fakePeer.closed, isTrue);
  });

  test(
      'child audio session starts AudioAssistanceService on join and stops it on teardown',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(() => repository.markActive('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.active,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );

    final fakePeer = _FakePeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
      peerConnectionFactory: (config) async => fakePeer,
      userMediaCapture: (constraints) async => _FakeMediaStream(
        audioTracks: [_FakeMediaStreamTrack()],
      ),
    );

    await controller.load();
    await controller.join();

    expect(deviceAdmin.audioServiceStarted, isTrue);
    expect(deviceAdmin.audioServiceSessionId, 'session-1');

    await controller.endSession();
    expect(deviceAdmin.audioServiceStopped, isTrue);
  });

  test(
      'native audio_assistance_stopped event triggers child session termination',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(() => repository.markActive('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.active,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );

    final fakePeer = _FakePeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
      peerConnectionFactory: (config) async => fakePeer,
      userMediaCapture: (constraints) async => _FakeMediaStream(
        audioTracks: [_FakeMediaStreamTrack()],
      ),
    );

    controller.onInit();
    await pumpEventQueue();
    await controller.join();
    expect(controller.hasActivePeer.value, isTrue);

    // Child taps "Stop" on ongoing foreground service notification
    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_stopped',
      'reason': 'child_stopped',
    });
    await pumpEventQueue(times: 20);

    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'ended_by_child');
    expect(controller.hasActivePeer.value, isFalse);
  });

  test(
      'ICE connection state transitions update isConnected and connectionWarning accurately',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    final fakePeer = _FakePeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      peerConnectionFactory: (config) async => fakePeer,
    );

    await controller.load();
    await controller.join();

    expect(fakePeer.onIceConnectionState, isNotNull);

    // Connected
    fakePeer.onIceConnectionState!(
        RTCIceConnectionState.RTCIceConnectionStateConnected);
    expect(controller.isConnected.value, isTrue);
    expect(controller.connectionWarning.value, isNull);

    // Disconnected
    fakePeer.onIceConnectionState!(
        RTCIceConnectionState.RTCIceConnectionStateDisconnected);
    expect(controller.isConnected.value, isFalse);
    expect(controller.connectionWarning.value, contains('interrupted'));

    // Failed
    fakePeer.onIceConnectionState!(
        RTCIceConnectionState.RTCIceConnectionStateFailed);
    expect(controller.isConnected.value, isFalse);
    expect(controller.connectionWarning.value, contains('failed'));
  });

  test('getMediaStats queries WebRTC telemetry reports', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );
    when(
      () => repository.sendSignal(
        sessionId: 'session-1',
        kind: SignalKind.offer,
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    final fakePeer = _FakePeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      peerConnectionFactory: (config) async => fakePeer,
    );

    await controller.load();
    await controller.join();

    final stats = await controller.getMediaStats();
    expect(stats, isNotEmpty);
    expect(stats.containsKey('timestamp'), isTrue);
    expect(stats.containsKey('audio-inbound'), isTrue);
  });
}
