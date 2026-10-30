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

/// Phase 1 audio hardening: one live peer, one idempotent teardown, debounced
/// child rejoin offers and a status that never claims live media without a peer.
///
/// Only the controller's own lifecycle is exercised; flutter_webrtc is faked so
/// no platform channel is required.
class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _FakeRtpSender extends Fake implements RTCRtpSender {}

class _FakeMediaStreamTrack extends Fake implements MediaStreamTrack {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _FakeMediaStream extends Fake implements MediaStream {
  _FakeMediaStream({List<MediaStreamTrack>? audioTracks})
    : _tracks = audioTracks ?? [_FakeMediaStreamTrack()];

  final List<MediaStreamTrack> _tracks;
  int disposeCalls = 0;

  _FakeMediaStreamTrack get audioTrack =>
      _tracks.whereType<_FakeMediaStreamTrack>().single;

  @override
  List<MediaStreamTrack> getAudioTracks() => _tracks;

  @override
  List<MediaStreamTrack> getVideoTracks() => const [];

  @override
  List<MediaStreamTrack> getTracks() => _tracks;

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
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

  int closeCalls = 0;
  int disposeCalls = 0;
  int restartIceCount = 0;
  final List<MediaStreamTrack> addedTracks = [];

  @override
  Future<void> setConfiguration(Map<String, dynamic> configuration) async {}

  @override
  Future<void> restartIce() async {
    restartIceCount += 1;
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('offer-sdp', 'offer');

  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('answer-sdp', 'answer');

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
  Future<void> addCandidate(RTCIceCandidate candidate) async {}

  @override
  List<MediaStream> getRemoteStreams() => const [];

  @override
  Future<void> close() async {
    closeCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  /// Zero counters: ICE being up is not evidence that audio is flowing.
  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => const [];
}

class _FakeDeviceAdminService extends DeviceAdminService {
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  int requestCount = 0;
  int serviceStartCount = 0;
  int serviceStopCount = 0;
  int heartbeatCount = 0;
  String? activeSessionId;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void emit(Map<String, dynamic> event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  void dispose() {
    _events.close();
  }

  // ignore: annotate_overrides
  Future<bool> areNotificationsGranted() async => true;

  // ignore: annotate_overrides
  Future<bool> isMicrophoneOneTimeGrant() async => false;

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        available: true,
        microphoneGranted: true,
        notificationsGranted: true,
      );

  @override
  Future<bool> startAudioAssistanceService({required String sessionId}) async {
    serviceStartCount += 1;
    activeSessionId = sessionId;
    scheduleMicrotask(() {
      emit({'type': 'audio_assistance_started', 'sessionId': sessionId});
    });
    return true;
  }

  @override
  Future<bool> stopAudioAssistanceService() async {
    serviceStopCount += 1;
    activeSessionId = null;
    return true;
  }

  @override
  Future<bool> isAudioAssistanceServiceRunning() async =>
      activeSessionId != null;

  @override
  Future<bool?> probeAudioAssistanceServiceRunning() async =>
      activeSessionId != null;

  @override
  Future<String?> getActiveAudioSessionId() async => activeSessionId;

  @override
  Future<bool> notifyAudioCaptureHeartbeat({required String sessionId}) async {
    heartbeatCount += 1;
    return activeSessionId == sessionId;
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
    return const {'camera': true, 'microphone': true};
  }
}

RemoteSession _session({
  RemoteSessionStatus status = RemoteSessionStatus.accepted,
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
  acceptedAt: DateTime.now().subtract(const Duration(minutes: 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemoteSessionRepository repository;
  late _FakeDeviceAdminService deviceAdmin;
  late StreamController<List<WebRtcSignal>> signals;
  late List<_FakePeerConnection> peers;
  late List<_FakeMediaStream> captured;
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
    signals = StreamController<List<WebRtcSignal>>.broadcast();
    peers = [];
    captured = [];

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
      () => repository.fetchById('session-1'),
    ).thenAnswer((_) async => _session());
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
    Duration rejoinDebounce = const Duration(seconds: 2),
    List<Duration> iceRestartBackoff = const [
      Duration(seconds: 30),
      Duration(seconds: 30),
    ],
    Duration iceRestartAttemptCap = const Duration(seconds: 30),
  }) {
    return RemoteSessionController(
      remoteSessionRepository: repository,
      session: SessionService(),
      deviceAdmin: deviceAdmin,
      sessionId: 'session-1',
      role: role,
      rejoinDebounce: rejoinDebounce,
      iceRestartBackoff: iceRestartBackoff,
      iceRestartAttemptCap: iceRestartAttemptCap,
      speakerphoneHandler: (enabled) async {},
      peerConnectionFactory: (config) async {
        final peer = _FakePeerConnection();
        peers.add(peer);
        return peer;
      },
      userMediaCapture: (constraints) async {
        final stream = _FakeMediaStream();
        captured.add(stream);
        return stream;
      },
    );
  }

  Future<void> loadAndJoin(RemoteSessionController controller) async {
    await controller.load();
    await controller.join();
    await pumpEventQueue(times: 20);
  }

  group('single peer guarantee', () {
    test('decidePeerJoin never rebuilds a live or parent-owned peer', () {
      // Needed only so tearDown can close a controller; the decision function
      // itself is pure and needs no loaded session.
      controller = buildController();
      // Nothing owned yet: a fresh connection is allowed.
      expect(
        RemoteSessionController.decidePeerJoin(
          hasPeer: false,
          hasLocalMedia: false,
          isChild: true,
          captureActive: false,
        ),
        PeerJoinDecision.create,
      );
      // Child with leftover media but no live capture may replace it.
      expect(
        RemoteSessionController.decidePeerJoin(
          hasPeer: true,
          hasLocalMedia: true,
          isChild: true,
          captureActive: false,
        ),
        PeerJoinDecision.replace,
      );
      // Live child capture is never rebuilt by a second join.
      expect(
        RemoteSessionController.decidePeerJoin(
          hasPeer: true,
          hasLocalMedia: true,
          isChild: true,
          captureActive: true,
        ),
        PeerJoinDecision.noOp,
      );
      // The receive-only parent never replaces the peer it owns.
      expect(
        RemoteSessionController.decidePeerJoin(
          hasPeer: true,
          hasLocalMedia: false,
          isChild: false,
          captureActive: false,
        ),
        PeerJoinDecision.noOp,
      );
    });

    test('a second join creates neither a second peer nor a second capture', () async {
      controller = buildController();
      await loadAndJoin(controller);

      expect(peers, hasLength(1));
      expect(captured, hasLength(1));
      expect(controller.hasActivePeer.value, isTrue);

      // Concurrent and later joins for the same live session are no-ops.
      await Future.wait([controller.join(), controller.join()]);
      await controller.join();
      await pumpEventQueue(times: 10);

      expect(peers, hasLength(1));
      expect(captured, hasLength(1));
      expect(peers.single.closeCalls, 0);
      expect(peers.single.disposeCalls, 0);
      expect(deviceAdmin.serviceStartCount, 1);
    });

    test('a surviving peer object is replaced before a new one is created', () async {
      controller = buildController();
      await loadAndJoin(controller);

      final first = peers.single;
      final firstTrack = captured.single.audioTrack;

      // The child stops sharing: capture and peer are released, and the peer
      // field must be clear before the rebuild.
      expect(await controller.withdrawConsent(), isTrue);
      await pumpEventQueue(times: 10);
      expect(firstTrack.stopCalls, 1);
      expect(first.disposeCalls, 1);

      await controller.join();
      await pumpEventQueue(times: 10);

      expect(peers, hasLength(2));
      expect(captured, hasLength(2));
      expect(peers.last.closeCalls, 0);
      expect(controller.hasActivePeer.value, isTrue);
    });
  });

  group('deterministic teardown', () {
    test('teardown stops each local track once and disposes the peer once',
        () async {
      controller = buildController();
      await loadAndJoin(controller);

      final peer = peers.single;
      final stream = captured.single;
      final track = stream.audioTrack;

      expect(await controller.withdrawConsent(), isTrue);
      await pumpEventQueue(times: 10);

      expect(track.stopCalls, 1);
      expect(stream.disposeCalls, 1);
      expect(peer.closeCalls, 1);
      expect(peer.disposeCalls, 1);
      expect(controller.hasActivePeer.value, isFalse);
      expect(controller.isConnected.value, isFalse);
      expect(controller.isMediaFlowing.value, isFalse);
      expect(controller.isCapturing.value, isFalse);
      expect(controller.isMediaLive, isFalse);
      // Consent withdrawal is local: the server session stays open.
      expect(controller.session.value?.status.isOpen, isTrue);
    });

    test('a second teardown is a safe no-op', () async {
      controller = buildController();
      await loadAndJoin(controller);

      final peer = peers.single;
      final track = captured.single.audioTrack;

      // Two overlapping stops: the release must not run twice.
      final first = controller.withdrawConsent();
      final second = controller.withdrawConsent();
      expect(await first, isTrue);
      expect(await second, isTrue);
      await pumpEventQueue(times: 10);

      // A later stop after the controller already released everything.
      expect(await controller.withdrawConsent(), isTrue);
      await pumpEventQueue(times: 10);

      expect(track.stopCalls, 1);
      expect(peer.closeCalls, 1);
      expect(peer.disposeCalls, 1);
      expect(controller.hasActivePeer.value, isFalse);
    });

    test('transient failed and disconnected states keep media inside the '
        'reconnect window', () async {
      controller = buildController();
      await loadAndJoin(controller);

      final peer = peers.single;
      final track = captured.single.audioTrack;
      expect(controller.hasActivePeer.value, isTrue);

      peer.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateFailed,
      );
      await pumpEventQueue(times: 5);

      expect(controller.connectionWarning.value, isNotNull);
      expect(controller.statusLabel, 'Reconnecting');
      expect(controller.session.value?.status.isTerminal, isFalse);
      expect(track.stopCalls, 0);
      expect(peer.closeCalls, 0);
      expect(controller.hasActivePeer.value, isTrue);
      expect(controller.isCapturing.value, isTrue);

      peer.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue(times: 5);

      expect(track.stopCalls, 0);
      expect(peer.closeCalls, 0);
      expect(controller.hasActivePeer.value, isTrue);
      expect(controller.statusLabel, isNot('Ended'));
    });
  });

  group('rejoin debounce', () {
    Future<List<dynamic>> offersSent() async {
      final capturedPayloads = verify(
        () => repository.sendSignal(
          sessionId: 'session-1',
          kind: SignalKind.offer,
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      return capturedPayloads;
    }

    test('a rapid duplicate rejoin offer is dropped', () async {
      controller = buildController(
        iceRestartBackoff: const [Duration.zero],
        iceRestartAttemptCap: const Duration(milliseconds: 40),
      );
      await loadAndJoin(controller);

      // `verify(...).captured` consumes matched calls, so the total number of
      // offers is asserted once, after the retry window below.
      // The connection fails immediately after the join announcement; the
      // recovery path tries to announce again inside the debounce window.
      peers.single.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateFailed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue(times: 10);

      expect(await offersSent(), hasLength(1));
      expect(controller.connectionWarning.value, isNotNull);
    });

    test('the debounce expires so a later rejoin is still announced', () async {
      controller = buildController(
        rejoinDebounce: const Duration(milliseconds: 50),
        // Attempt 1 fires immediately (dropped), its cap reschedules attempt 2
        // after the window, which must be sent.
        iceRestartBackoff: const [Duration.zero, Duration(milliseconds: 120)],
        iceRestartAttemptCap: const Duration(milliseconds: 30),
      );
      await loadAndJoin(controller);

      // One join offer plus the retry after the debounce window; captured once
      // because `verify(...).captured` consumes matched calls.
      peers.single.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateFailed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await pumpEventQueue(times: 20);

      final offers = await offersSent();
      expect(offers.length, greaterThanOrEqualTo(2));
      for (final payload in offers) {
        expect((payload as Map<String, dynamic>)['ready'], isTrue);
        expect(payload['sdp'], '');
      }
    });
  });

  group('state surfacing', () {
    test('the status never says live while the peer is absent', () async {
      when(
        () => repository.fetchById('session-1'),
      ).thenAnswer((_) async => _session(status: RemoteSessionStatus.active));
      controller = buildController(role: 'parent');
      await loadAndJoin(controller);

      expect(controller.hasActivePeer.value, isTrue);
      expect(controller.statusLabel, 'Reconnecting');
      expect(controller.isMediaFlowing.value, isFalse);

      peers.single.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
      await pumpEventQueue(times: 10);

      // ICE is up but no audio RTP has moved yet.
      expect(controller.statusLabel, 'Checking audio…');
      expect(controller.isMediaLive, isTrue);

      // A server end the phone cannot confirm still releases local media.
      when(
        () => repository.end(sessionId: 'session-1'),
      ).thenThrow(const AppException('network_error', 'offline'));
      expect(await controller.endSession(), isFalse);

      expect(controller.hasActivePeer.value, isFalse);
      expect(controller.isMediaFlowing.value, isFalse);
      expect(controller.isMediaLive, isFalse);
      expect(controller.statusLabel, 'Session active');
      expect(controller.statusLabel, isNot('Active'));
      expect(controller.session.value?.status.isTerminal, isFalse);
    });

    test('a server terminal state wins over a local sharing stop', () async {
      controller = buildController();
      await loadAndJoin(controller);

      expect(await controller.withdrawConsent(), isTrue);
      expect(controller.sharingStopped.value, isTrue);
      expect(controller.statusLabel, 'Sharing stopped');

      final current = controller.session.value!;
      controller.session.value = RemoteSession(
        id: current.id,
        familyId: current.familyId,
        deviceId: current.deviceId,
        parentUserId: current.parentUserId,
        childUserId: current.childUserId,
        kind: current.kind,
        status: RemoteSessionStatus.ended,
        requestedAt: current.requestedAt,
        acceptedAt: current.acceptedAt,
        endedAt: DateTime.now(),
        endedReason: 'ended_by_parent',
      );
      await pumpEventQueue(times: 5);

      expect(controller.statusLabel, 'Ended');
      expect(controller.hasActivePeer.value, isFalse);
    });
  });
}