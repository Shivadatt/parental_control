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
    if (constraints != null) offerConstraints.add(constraints);
    return RTCSessionDescription('offer-sdp-$restartIceCount', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) async =>
      RTCSessionDescription('answer-sdp', 'answer');

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
}) =>
    RemoteSession(
      id: 'session-1',
      familyId: 'family-1',
      deviceId: 'device-1',
      parentUserId: 'parent-1',
      childUserId: 'child-1',
      kind: kind,
      status: status,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemoteSessionRepository repository;
  late _FakeDeviceAdminService deviceAdmin;
  late _FakePeerConnection peer;
  late List<_FakeMediaStream> capturedStreams;
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
      () => repository.sendSignal(
        sessionId: any(named: 'sessionId'),
        kind: any(named: 'kind'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(() => repository.markActive('session-1'))
        .thenAnswer((_) async => _session(status: RemoteSessionStatus.active));
    when(
      () => repository.end(
        sessionId: any(named: 'sessionId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    controller.onClose();
    deviceAdmin.dispose();
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
      peerConnectionFactory: (config) async => peer,
      userMediaCapture: (constraints) async {
        final stream = _FakeMediaStream();
        capturedStreams.add(stream);
        return stream;
      },
    );
  }

  Future<void> loadAccepted() async {
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());
    await controller.load();
  }

  test('service start false aborts join with no peer, tracks or capture',
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
  });

  test('service start confirmation timeout aborts join and stops the service',
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
  });

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

  test('missing role is view-only and cannot request permissions or capture',
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
  });

  test('isMediaLive requires both live capture and confirmed service', () async {
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
    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.permissionDenied.value, isFalse);
  });

  test('microphone permission loss mid-session stops tracks and ends session',
      () async {
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

    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'permission_revoked');
    expect(controller.permissionDenied.value, isTrue);
    expect(controller.actionError.value?.code, 'permission_revoked');
    expect(track.stopped, isTrue);
    expect(deviceAdmin.serviceStopped, isTrue);
    expect(controller.hasActivePeer.value, isFalse);
    expect(controller.isMediaLive, isFalse);
  });

  test('ICE failure retries restartIce twice then tears the session down',
      () async {
    controller = buildController(
      iceRestartBackoff: const [Duration.zero, Duration.zero],
      iceRestartAttemptCap: const Duration(milliseconds: 20),
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

    expect(peer.restartIceCount, 2);
    expect(peer.closed, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'connection_failed');
    expect(controller.iceError.value?.code, 'media_connection_failed');
    expect(controller.actionError.value?.code, 'media_connection_failed');
    expect(controller.hasActivePeer.value, isFalse);
    expect(
      peer.offerConstraints.last['mandatory']['OfferToReceiveAudio'],
      isTrue,
    );
  });

  test('signaling stream error resubscribes with backoff', () async {
    var signalSubscriptions = 0;
    when(() => repository.watchSignals('session-1')).thenAnswer((_) {
      signalSubscriptions += 1;
      if (signalSubscriptions == 1) {
        return Stream<List<WebRtcSignal>>.error(
          const AppException('network_error', 'signaling disconnected'),
        );
      }
      return const Stream<List<WebRtcSignal>>.empty();
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
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _session());
    await controller.load();

    await pumpEventQueue(times: 30);

    expect(signalSubscriptions, greaterThanOrEqualTo(2));
    expect(controller.realtimeError.value, isNotNull);
  });

  test('endSession returns false and keeps the session open when the server '
      'end throws', () async {
    when(
      () => repository.end(
        sessionId: 'session-1',
        reason: any(named: 'reason'),
      ),
    ).thenThrow(const AppException('network_error', 'offline'));
    controller = buildController();
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
    expect(deviceAdmin.serviceStopped, isTrue);
  });

  test('endSession returns true only after the server confirms the end',
      () async {
    controller = buildController();
    await loadAccepted();
    await controller.join();

    final ended = await controller.endSession(reason: 'ended_by_child');

    expect(ended, isTrue);
    expect(controller.session.value?.status, RemoteSessionStatus.ended);
    expect(controller.session.value?.endedReason, 'ended_by_child');
    expect(controller.endError, isNull);
    expect(controller.hasActivePeer.value, isFalse);
    verify(
      () => repository.end(
        sessionId: 'session-1',
        reason: 'ended_by_child',
      ),
    ).called(1);
  });

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
}
