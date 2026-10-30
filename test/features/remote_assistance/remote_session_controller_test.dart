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

class _FakeMediaStreamTrack extends Fake implements MediaStreamTrack {
  bool stopped = false;

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

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

class _RtpPeerConnection extends _FakePeerConnection {
  int packetsSent = 0;
  int packetsReceived = 0;
  int videoPacketsReceived = 0;

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    return [
      StatsReport('audio-outbound', 'outbound-rtp', 1000.0, {
        'kind': 'audio',
        'packetsSent': '$packetsSent',
        'bytesSent': '${packetsSent * 100}',
      }),
      StatsReport('audio-inbound', 'inbound-rtp', 2000.0, {
        'kind': 'audio',
        'packetsReceived': '$packetsReceived',
        'bytesReceived': '${packetsReceived * 100}',
      }),
      StatsReport('video-inbound', 'inbound-rtp', 3000.0, {
        'kind': 'video',
        'packetsReceived': '$videoPacketsReceived',
      }),
      StatsReport('transport', 'candidate-pair', 4000.0, {
        'state': 'succeeded',
        'packetsSent': '999999',
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
  int serviceStartCount = 0;
  int serviceStopCount = 0;
  int heartbeatCount = 0;
  bool? probeRunning = true;

  @override
  Future<bool> startAudioAssistanceService({required String sessionId}) async {
    serviceStartCount += 1;
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
    serviceStopCount += 1;
    audioServiceStopped = true;
    return true;
  }

  @override
  Future<bool> isAudioAssistanceServiceRunning() async =>
      audioServiceStarted && !audioServiceStopped;

  @override
  Future<bool?> probeAudioAssistanceServiceRunning() async => probeRunning;

  @override
  Future<String?> getActiveAudioSessionId() async =>
      audioServiceStarted && !audioServiceStopped ? audioServiceSessionId : null;

  @override
  Future<bool> notifyAudioCaptureHeartbeat({required String sessionId}) async {
    heartbeatCount += 1;
    return audioServiceStarted && !audioServiceStopped;
  }

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
  DateTime? expiresAt,
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
    when(() => repository.end(sessionId: 'session-1'))
        .thenAnswer((_) async {});
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
    'an accepted session past its old deadline stays joinable and is never '
    'auto-ended',
    () async {
      when(() => repository.fetchById('session-1')).thenAnswer(
        (_) async => _session(
          status: RemoteSessionStatus.accepted,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
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

      expect(controller.statusLabel, 'Accepted');
      expect(controller.canJoin, isTrue);
      expect(controller.isExpired, isFalse);
      verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));

      await controller.join();

      expect(controller.actionError.value, isNull);
      expect(controller.hasActivePeer.value, isTrue);
      verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    },
  );

  test('stops local media even when the server end call fails', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.accepted,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
    when(() => repository.end(sessionId: 'session-1'))
        .thenThrow(const AppException('network_error', 'The network is offline.'));

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
      'child audio session starts AudioAssistanceService on join and stops it when sharing is withdrawn',
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
    await pumpEventQueue();

    expect(deviceAdmin.audioServiceStarted, isTrue);
    expect(deviceAdmin.audioServiceSessionId, 'session-1');

    expect(await controller.withdrawConsent(), isTrue);
    expect(deviceAdmin.audioServiceStopped, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.sharingStopped.value, isTrue);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test(
      'withdrawing consent with no live capture succeeds and keeps the stop '
      'control available', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.active,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );

    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
    );

    await controller.load();

    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.canStopSharing, isTrue);
    expect(await controller.withdrawConsent(), isTrue);
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.actionError.value, isNull);
    expect(controller.canStopSharing, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test(
      'native audio_assistance_stopped event stops child capture without ending the server session',
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

    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.isMediaLive, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
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

  // ---------------------------------------------------------------------
  // Native "UI detached" events never terminate a live child session.
  // ---------------------------------------------------------------------

  /// Joins a live child audio session (capture + confirmed microphone service)
  /// so the detached-UI events are handled on a session that is actually live.
  Future<RemoteSessionController> joinLiveChildSession() async {
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
    expect(controller.isMediaLive, isTrue);
    return controller;
  }

  test(
      'audio_assistance_detached keeps the live child session and capture running',
      () async {
    await joinLiveChildSession();

    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_detached',
      'reason': 'task_removed_active',
      'sessionId': 'session-1',
    });
    await pumpEventQueue(times: 20);

    // The child UI is gone, but this is not a termination signal.
    expect(controller.childUiDetached.value, isTrue);
    expect(controller.hasActivePeer.value, isTrue);
    expect(controller.isMediaLive, isTrue);
    expect(controller.isConnected.value, isFalse);
    expect(controller.session.value?.status, isNot(RemoteSessionStatus.ended));
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.isEnding.value, isFalse);
    expect(controller.endError, isNull);
    expect(deviceAdmin.audioServiceStopped, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('audio_assistance_detached for another session is ignored', () async {
    await joinLiveChildSession();

    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_detached',
      'reason': 'task_removed_active',
      'sessionId': 'session-other',
    });
    await pumpEventQueue(times: 20);

    expect(controller.childUiDetached.value, isFalse);
    expect(controller.hasActivePeer.value, isTrue);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('audio_assistance_stopped with task_removed only marks the UI detached',
      () async {
    await joinLiveChildSession();

    // An older APK reports a Recents swipe as a service stop even though the
    // microphone foreground service keeps running.
    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_stopped',
      'reason': 'task_removed',
      'sessionId': 'session-1',
    });
    await pumpEventQueue(times: 20);

    expect(controller.childUiDetached.value, isTrue);
    expect(controller.hasActivePeer.value, isTrue);
    expect(controller.isMediaLive, isTrue);
    expect(controller.session.value?.status, isNot(RemoteSessionStatus.ended));
    expect(controller.isEnding.value, isFalse);
    expect(deviceAdmin.audioServiceStopped, isFalse);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('audio_assistance_stopped with permission_revoked stops capture without '
      'ending the server session', () async {
    await joinLiveChildSession();

    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_stopped',
      'reason': 'permission_revoked',
      'sessionId': 'session-1',
    });
    await pumpEventQueue(times: 20);

    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaLive, isFalse);
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.permissionDenied.value, isTrue);
    expect(controller.actionError.value?.code, 'permission_revoked');
    expect(deviceAdmin.audioServiceStopped, isTrue);
    expect(controller.childUiDetached.value, isFalse);
  });

  test('audio_assistance_stopped with service_destroyed stops capture without '
      'ending the server session', () async {
    await joinLiveChildSession();

    deviceAdmin.emitNativeEvent({
      'type': 'audio_assistance_stopped',
      'reason': 'service_destroyed',
      'sessionId': 'session-1',
    });
    await pumpEventQueue(times: 20);

    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaLive, isFalse);
    expect(controller.sharingStopped.value, isTrue);
    expect(controller.childUiDetached.value, isFalse);
  });

  // ---------------------------------------------------------------------
  // Stage 5: background survival, recreation and truthful media status.
  // ---------------------------------------------------------------------

  Future<
      ({
        RemoteSessionController controller,
        _RtpPeerConnection peer,
        _FakeMediaStreamTrack track,
      })> joinRtpChild({
    Duration statsSampleInterval = const Duration(milliseconds: 20),
    Duration captureHeartbeatInterval = const Duration(seconds: 10),
  }) async {
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

    final peer = _RtpPeerConnection();
    final track = _FakeMediaStreamTrack();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
      statsSampleInterval: statsSampleInterval,
      captureHeartbeatInterval: captureHeartbeatInterval,
      peerConnectionFactory: (config) async => peer,
      userMediaCapture: (constraints) async =>
          _FakeMediaStream(audioTracks: [track]),
    );
    controller.onInit();
    await pumpEventQueue();
    await controller.join();
    return (controller: controller, peer: peer, track: track);
  }

  test('onClose detaches without stopping capture, the service or the session',
      () async {
    final live = await joinRtpChild();
    expect(live.controller.isMediaLive, isTrue);

    live.controller.onClose();
    await pumpEventQueue(times: 20);

    // Controller disposal is a UI event, not a consent withdrawal.
    expect(live.track.stopped, isFalse);
    expect(live.peer.closed, isFalse);
    expect(live.peer.disposed, isFalse);
    expect(deviceAdmin.serviceStopCount, 0);
    expect(deviceAdmin.audioServiceStopped, isFalse);
    expect(live.controller.hasActivePeer.value, isTrue);
    expect(live.controller.session.value?.status.isOpen, isTrue);
    expect(live.controller.session.value?.endedReason, isNull);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('rejoining a live session does not create a second peer, capture or '
      'service instance', () async {
    var peerCreates = 0;
    var captureCalls = 0;
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

    final peer = _RtpPeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'child',
      peerConnectionFactory: (config) async {
        peerCreates += 1;
        return peer;
      },
      userMediaCapture: (constraints) async {
        captureCalls += 1;
        return _FakeMediaStream(audioTracks: [_FakeMediaStreamTrack()]);
      },
    );
    controller.onInit();
    await pumpEventQueue();
    await controller.join();

    // An Activity/route recreation asks for the same session again.
    await controller.join();
    await controller.join();

    expect(peerCreates, 1);
    expect(captureCalls, 1);
    expect(deviceAdmin.serviceStartCount, 1);
    expect(peer.addedTracks.length, 1);
  });

  test('reconcileAfterResume restores the existing session and never re-opens '
      'the microphone', () async {
    final live = await joinRtpChild();
    expect(live.controller.hasActivePeer.value, isTrue);

    deviceAdmin.probeRunning = true;
    await live.controller.reconcileAfterResume();
    await pumpEventQueue();

    // A running service means the authorized session is simply kept.
    expect(live.controller.hasActivePeer.value, isTrue);
    expect(live.controller.session.value?.status, RemoteSessionStatus.active);
    expect(live.track.stopped, isFalse);
    expect(deviceAdmin.serviceStopCount, 0);

    // After process/media loss the service is gone: report honestly, release
    // capture, and stay in the same server session.
    deviceAdmin.probeRunning = false;
    await live.controller.reconcileAfterResume();
    await pumpEventQueue(times: 20);

    expect(live.controller.hasActivePeer.value, isFalse);
    expect(live.controller.sharingStopped.value, isTrue);
    expect(live.controller.actionError.value?.code, 'microphone_service_failed');
    expect(live.controller.session.value?.status, RemoteSessionStatus.active);
    expect(live.controller.session.value?.endedReason, isNull);
    expect(live.track.stopped, isTrue);
    expect(deviceAdmin.serviceStopCount, 1);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('child confirms live capture with periodic heartbeats and stops them '
      'when sharing is withdrawn', () async {
    final live = await joinRtpChild(
      captureHeartbeatInterval: const Duration(milliseconds: 20),
    );

    expect(deviceAdmin.heartbeatCount, greaterThanOrEqualTo(1));
    await Future<void>.delayed(const Duration(milliseconds: 90));
    final beforeStop = deviceAdmin.heartbeatCount;
    expect(beforeStop, greaterThanOrEqualTo(2));

    expect(await live.controller.withdrawConsent(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(deviceAdmin.heartbeatCount, beforeStop);
    expect(live.controller.isMediaLive, isFalse);
  });

  test('the parent never reports live audio from ICE, video or transport '
      'counters alone', () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.active,
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

    final peer = _RtpPeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      statsSampleInterval: const Duration(milliseconds: 20),
      audioFlowGrace: const Duration(milliseconds: 40),
      audioIdleTimeout: const Duration(milliseconds: 50),
      peerConnectionFactory: (config) async => peer,
    );
    await controller.load();
    await controller.join();

    expect(controller.isMediaFlowing.value, isFalse);
    expect(controller.hasActivePeer.value, isTrue);

    peer.onIceConnectionState!(
      RTCIceConnectionState.RTCIceConnectionStateConnected,
    );
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.isConnected.value, isTrue);
    expect(controller.isMediaFlowing.value, isFalse);
    expect(controller.isCheckingAudio, isTrue);
    expect(controller.statusLabel, 'Checking audio…');

    // Still no audio RTP after the grace period.
    await Future<void>.delayed(const Duration(milliseconds: 90));
    controller.now.value = DateTime.now();
    expect(controller.isMediaFlowing.value, isFalse);
    expect(controller.audioUnavailable, isTrue);
    expect(controller.statusLabel, 'Audio unavailable');

    // Only inbound audio packets count; a video counter is not media evidence.
    peer.videoPacketsReceived += 5000;
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(controller.isMediaFlowing.value, isFalse);

    peer.packetsReceived += 25;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(controller.isMediaFlowing.value, isTrue);
    expect(controller.statusLabel, 'Active');
    expect(
      controller.mediaStatsSnapshot?.packetsReceived,
      greaterThanOrEqualTo(25),
    );

    // Audio stops: the UI must stop claiming live media.
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(controller.isMediaFlowing.value, isFalse);
    expect(controller.statusLabel, 'Audio unavailable');
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
  });

  test('parent end closes local media and is the only session-ending action',
      () async {
    when(() => repository.fetchById('session-1')).thenAnswer(
      (_) async => _session(
        status: RemoteSessionStatus.active,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        kind: SessionKind.audio,
      ),
    );

    final peer = _RtpPeerConnection();
    controller.onClose();
    controller = RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: 'parent',
      peerConnectionFactory: (config) async => peer,
    );
    await controller.load();
    await controller.join();
    peer.onIceConnectionState!(
      RTCIceConnectionState.RTCIceConnectionStateConnected,
    );

    final ended = await controller.endSession();

    expect(ended, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaFlowing.value, isFalse);
    expect(peer.closed, isTrue);
    expect(peer.disposed, isTrue);
    verify(() => repository.end(sessionId: 'session-1')).called(1);
  });
}
