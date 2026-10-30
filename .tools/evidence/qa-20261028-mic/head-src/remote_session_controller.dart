import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json_utils.dart';
import '../../data/models/remote_session.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';

/// One side of a consented assistance session.
///
/// The parent creates the offer; the child answers from its own visible screen.
/// Media is opened only from [join], which first verifies that the child has
/// accepted (or the session is already active) and has not expired. Nothing is
/// recorded, captured, or sent before that tap.
class RemoteSessionController extends GetxController {
  RemoteSessionController({
    required this._remoteSessionRepository,
    required this._session,
    required this.sessionId,
    required this.role,
  });

  final RemoteSessionRepository _remoteSessionRepository;
  final SessionService _session;
  final String sessionId;
  final String role;

  final Rxn<RemoteSession> session = Rxn<RemoteSession>();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final RxBool isLoading = true.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final Rxn<AppException> realtimeError = Rxn<AppException>();
  final Rxn<AppException> iceError = Rxn<AppException>();
  final Rxn<IceConfig> iceConfig = Rxn<IceConfig>();
  final RxBool isJoining = false.obs;
  final RxBool isResponding = false.obs;
  final RxBool isEnding = false.obs;
  final RxBool hasActivePeer = false.obs;
  final RxBool isConnected = false.obs;
  final RxBool isRemoteVideoActive = false.obs;
  final RxBool permissionDenied = false.obs;
  final RxnString connectionWarning = RxnString();
  final Rx<DateTime> now = DateTime.now().obs;

  StreamSubscription<RemoteSession>? _sessionSubscription;
  StreamSubscription<List<WebRtcSignal>>? _signalSubscription;
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  RTCSessionDescription? _pendingOffer;
  Timer? _ticker;
  final Set<String> _processedSignals = <String>{};
  bool _rendererInitialized = false;
  bool _iceLoading = false;
  bool _autoEndAttempted = false;
  bool _isClosed = false;
  int _joinToken = 0;

  bool get hasContext => sessionId.isNotEmpty;
  bool get isParentRole => role.toLowerCase() == 'parent';
  bool get isViewOnly => !isParentRole;

  bool get isExpired => session.value?.isExpired ?? false;
  bool get canJoin =>
      !isJoining.value &&
      !hasActivePeer.value &&
      session.value != null &&
      (session.value!.status == RemoteSessionStatus.accepted ||
          session.value!.status == RemoteSessionStatus.active) &&
      !isExpired;
  bool get canEnd {
    final current = session.value;
    return current != null && current.status.isOpen && !current.isExpired;
  }

  String get statusLabel {
    final current = session.value;
    if (current == null) return 'Unknown';
    if (current.status.isOpen && current.isExpired) return 'Expired';
    return current.status.label;
  }

  String get expiresInLabel {
    final current = session.value;
    if (current == null) return '—';
    if (!current.status.isOpen) return formatDateTime(current.expiresAt);
    final remaining = current.expiresAt.difference(now.value);
    if (remaining.isNegative) return 'Expired';
    return formatDurationMs(remaining.inMilliseconds);
  }

  String? get turnWarning {
    final config = iceConfig.value;
    if (config == null) return null;
    if (!config.turnConfigured) {
      return 'No TURN relay is configured. Audio/video may fail to connect on '
          'networks with strict firewalls or carrier NAT.';
    }
    final warning = config.warning;
    if (warning != null && warning.trim().isNotEmpty) return warning;
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoading = true}) async {
    if (!hasContext) {
      isLoading.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'This screen needs a session id. Open it from the assistance list.',
      );
      return;
    }
    if (showLoading) isLoading.value = true;
    error.value = null;
    try {
      final loaded = await _remoteSessionRepository.fetchById(sessionId);
      if (loaded == null) {
        error.value = const AppException(
          AppErrorCodes.notFound,
          'This assistance session no longer exists or you cannot read it.',
        );
        return;
      }
      session.value = loaded;
      _subscribeSession();
      _afterSessionChanged();
    } catch (caught) {
      error.value = AppException.from(caught);
    } finally {
      isLoading.value = false;
    }
  }

  void _subscribeSession() {
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription =
        _remoteSessionRepository.watchSession(sessionId).listen(
      (updated) {
        final existing = session.value;
        session.value = RemoteSession(
          id: updated.id,
          familyId: updated.familyId,
          deviceId: updated.deviceId,
          parentUserId: updated.parentUserId,
          childUserId: updated.childUserId,
          kind: updated.kind,
          status: updated.status,
          requestedAt: updated.requestedAt,
          expiresAt: updated.expiresAt,
          acceptedAt: updated.acceptedAt,
          endedAt: updated.endedAt,
          endedReason: updated.endedReason,
          consentRecorded: updated.consentRecorded,
          parentDisplayName:
              updated.parentDisplayName ?? existing?.parentDisplayName,
          childDisplayName:
              updated.childDisplayName ?? existing?.childDisplayName,
          deviceName: updated.deviceName ?? existing?.deviceName,
        );
        realtimeError.value = null;
        _afterSessionChanged();
      },
      onError: (Object caught) {
        realtimeError.value = AppException.from(caught);
      },
    );
  }

  /// Child-side consent. Only the child account may call this, and the server
  /// verifies that the request belongs to it. Accepting does not open media.
  Future<bool> respond({required bool accept}) async {
    if (isParentRole) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the child device can answer an assistance request.',
      );
      return false;
    }
    final current = session.value;
    if (current == null) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'The session is still loading. Try again in a moment.',
      );
      return false;
    }
    if ((accept && current.status == RemoteSessionStatus.accepted) ||
        (!accept && current.status == RemoteSessionStatus.declined)) {
      return true;
    }
    if (current.status != RemoteSessionStatus.requested) {
      actionError.value = const AppException(
        'session_not_open',
        'This request is no longer waiting for an answer.',
      );
      return false;
    }
    if (current.isExpired) {
      actionError.value = const AppException(
        'session_expired',
        'This request expired. No camera or microphone was opened.',
      );
      return false;
    }
    if (isResponding.value) return false;
    isResponding.value = true;
    actionError.value = null;
    try {
      final updated = await _remoteSessionRepository.respond(
        sessionId: sessionId,
        accept: accept,
      );
      session.value = updated;
      _afterSessionChanged();
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isResponding.value = false;
    }
  }

  void _afterSessionChanged() {
    final current = session.value;
    if (current == null) return;
    if (current.status.isTerminal) {
      _stopSignalWatch();
      _stopTicker();
      unawaited(_teardownMedia());
      return;
    }
    if (current.isExpired) {
      _stopSignalWatch();
      _stopTicker();
      unawaited(_teardownMedia());
      unawaited(_autoEndExpired());
      return;
    }
    _startTicker();
    if (current.status == RemoteSessionStatus.accepted ||
        current.status == RemoteSessionStatus.active) {
      _ensureSignalWatch();
      unawaited(_prefetchIce());
    } else {
      _stopSignalWatch();
    }
  }

  Future<void> _prefetchIce() async {
    if (_iceLoading || iceConfig.value != null) return;
    _iceLoading = true;
    iceError.value = null;
    try {
      iceConfig.value = await _remoteSessionRepository.fetchIceConfig(sessionId);
    } catch (caught) {
      iceError.value = AppException.from(caught);
    } finally {
      _iceLoading = false;
    }
  }

  void _ensureSignalWatch() {
    if (_signalSubscription != null) return;
    _signalSubscription =
        _remoteSessionRepository.watchSignals(sessionId).listen(
      (signals) {
        for (final signal in signals) {
          _handleSignal(signal);
        }
      },
      onError: (Object caught) {
        realtimeError.value = AppException.from(caught);
      },
    );
  }

  void _stopSignalWatch() {
    unawaited(_signalSubscription?.cancel());
    _signalSubscription = null;
  }

  void _handleSignal(WebRtcSignal signal) {
    if (_isClosed) return;
    final myUserId = _session.userId.value;
    if (myUserId.isNotEmpty && signal.fromUserId == myUserId) return;
    final key = signal.id.isEmpty
        ? '${signal.kind.wireName}:${signal.sequence}'
        : signal.id;
    if (!_processedSignals.add(key)) return;
    final peer = _peer;
    if (peer == null) {
      // The child may still be opening its camera when the parent's offer
      // arrives. Keep the newest offer so join() can answer it instead of
      // losing the negotiation.
      if (!isParentRole && signal.kind == SignalKind.offer) {
        final sdp = jsonString(signal.payload['sdp']);
        if (sdp != null && sdp.isNotEmpty) {
          _pendingOffer = RTCSessionDescription(
            sdp,
            jsonStringOr(signal.payload['type'], 'offer'),
          );
        }
      }
      return;
    }
    unawaited(_applySignal(peer, signal));
  }

  Future<void> _applySignal(
    RTCPeerConnection peer,
    WebRtcSignal signal,
  ) async {
    try {
      switch (signal.kind) {
        case SignalKind.answer:
          final sdp = jsonString(signal.payload['sdp']);
          if (sdp == null || sdp.isEmpty) return;
          final type = jsonStringOr(signal.payload['type'], 'answer');
          await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
          break;
        case SignalKind.ice:
          final candidate = jsonString(signal.payload['candidate']);
          if (candidate == null || candidate.isEmpty) return;
          await peer.addCandidate(
            RTCIceCandidate(
              candidate,
              jsonString(signal.payload['sdpMid']),
              jsonInt(signal.payload['sdpMLineIndex']),
            ),
          );
          break;
        case SignalKind.offer:
          if (isParentRole) {
            // The parent is the offerer. A child offer would create a
            // conflicting negotiation, so it is ignored.
            break;
          }
          final sdp = jsonString(signal.payload['sdp']);
          if (sdp == null || sdp.isEmpty) return;
          await _answerOffer(
            peer,
            RTCSessionDescription(
              sdp,
              jsonStringOr(signal.payload['type'], 'offer'),
            ),
          );
          break;
      }
    } catch (_) {
      connectionWarning.value =
          'A WebRTC signal could not be applied. The session may not connect.';
    }
  }

  Future<void> _answerOffer(
    RTCPeerConnection peer,
    RTCSessionDescription offer,
  ) async {
    await peer.setRemoteDescription(offer);
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await _remoteSessionRepository.sendSignal(
      sessionId: sessionId,
      kind: SignalKind.answer,
      payload: {
        'sdp': answer.sdp,
        'type': answer.type ?? 'answer',
      },
    );
  }

  /// Starts local media. The parent then sends the offer; the child answers the
  /// parent's offer. Must only be called from a visible action after [canJoin].
  Future<void> join() async {
    final current = session.value;
    if (current == null) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'The session is still loading. Try again in a moment.',
      );
      return;
    }
    if (current.isExpired ||
        (current.status != RemoteSessionStatus.accepted &&
            current.status != RemoteSessionStatus.active)) {
      actionError.value = AppException(
        'consent_required',
        current.isExpired
            ? 'This session has expired. No camera or microphone was opened.'
            : (isParentRole
                ? 'The child has not accepted this session. Camera and '
                    'microphone stay off until the child consents.'
                : 'Accept this request before turning on your camera or '
                    'microphone.'),
      );
      return;
    }
    if (isJoining.value || hasActivePeer.value) return;

    final token = ++_joinToken;
    isJoining.value = true;
    permissionDenied.value = false;
    actionError.value = null;
    connectionWarning.value = null;
    MediaStream? local;
    RTCPeerConnection? peer;
    try {
      final config =
          iceConfig.value ?? await _remoteSessionRepository.fetchIceConfig(sessionId);
      if (token != _joinToken || _isClosed) return;
      iceConfig.value = config;
      if (config.iceServers.isEmpty) {
        throw const AppException(
          AppErrorCodes.unsupported,
          'The server returned no ICE servers, so a media connection cannot be '
          'established right now.',
        );
      }
      final latest = session.value;
      if (latest == null ||
          latest.isExpired ||
          (latest.status != RemoteSessionStatus.accepted &&
              latest.status != RemoteSessionStatus.active)) {
        throw AppException(
          'consent_required',
          latest?.isExpired == true
              ? 'The session expired before media started.'
              : 'The session is no longer accepted. No camera or microphone was '
                  'opened.',
        );
      }

      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        if (latest.kind == SessionKind.video)
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
      };
      final localStream =
          await navigator.mediaDevices.getUserMedia(constraints);
      if (token != _joinToken || _isClosed) {
        await _stopTracks(localStream);
        return;
      }
      local = localStream;
      _localStream = localStream;

      final peerConnection = await createPeerConnection({
        'iceServers':
            config.iceServers.map((server) => server.toWebRtcMap()).toList(),
      });
      if (token != _joinToken || _isClosed) {
        await _disposePeer(peerConnection);
        await _stopTracks(localStream);
        if (_localStream == localStream) _localStream = null;
        return;
      }
      peer = peerConnection;
      _peer = peerConnection;
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        unawaited(_sendIce(candidate));
      };
      peerConnection.onTrack = (event) {
        MediaStream? stream;
        if (event.streams.isNotEmpty) {
          stream = event.streams.first;
        } else {
          final remoteStreams = peerConnection.getRemoteStreams();
          if (remoteStreams.isNotEmpty) stream = remoteStreams.first;
        }
        if (stream != null) unawaited(_attachRemote(stream));
      };
      peerConnection.onConnectionState = (state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            isConnected.value = true;
            connectionWarning.value = null;
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            isConnected.value = false;
            connectionWarning.value =
                'The media connection failed. End this session and request a '
                'new one.';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            isConnected.value = false;
            connectionWarning.value =
                'The media connection was interrupted. Waiting for it to '
                'recover; end the session if it does not.';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            isConnected.value = false;
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            isConnected.value = false;
            break;
        }
      };

      for (final track in localStream.getTracks()) {
        await peerConnection.addTrack(track, localStream);
      }
      if (isParentRole) {
        final offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        if (token != _joinToken || _isClosed) return;
        await _remoteSessionRepository.sendSignal(
          sessionId: sessionId,
          kind: SignalKind.offer,
          payload: {
            'sdp': offer.sdp,
            'type': offer.type ?? 'offer',
          },
        );
      } else {
        final pending = _pendingOffer;
        _pendingOffer = null;
        if (pending != null) {
          await _answerOffer(peerConnection, pending);
        }
      }
      if (token != _joinToken || _isClosed) return;
      hasActivePeer.value = true;
    } catch (caught) {
      await _stopTracks(local);
      await _disposePeer(peer);
      if (_localStream == local) _localStream = null;
      if (_peer == peer) _peer = null;
      hasActivePeer.value = false;
      isConnected.value = false;
      final message = _mediaErrorMessage(caught);
      if (message == null) {
        actionError.value = AppException.from(caught);
      } else if (message == _permissionMessage) {
        permissionDenied.value = true;
      } else {
        actionError.value = AppException('media_failed', message);
      }
    } finally {
      isJoining.value = false;
    }
  }

  static const _permissionMessage =
      'Camera or microphone permission was denied on this phone. Grant it in '
      'Android settings, then try joining again.';

  String? _mediaErrorMessage(Object caught) {
    if (caught is AppException) return caught.message;
    final text = caught.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('notallowed') ||
        text.contains('denied')) {
      return _permissionMessage;
    }
    if (text.contains('getusermedia')) {
      return 'Camera or microphone could not be started. Check that no other '
          'app is using them, then try again.';
    }
    return null;
  }

  Future<void> _attachRemote(MediaStream stream) async {
    if (_isClosed) return;
    try {
      if (!_rendererInitialized) {
        await remoteRenderer.initialize();
        _rendererInitialized = true;
      }
      if (_isClosed) return;
      remoteRenderer.srcObject = stream;
      isRemoteVideoActive.value = stream.getVideoTracks().isNotEmpty;
    } catch (_) {
      connectionWarning.value =
          'The remote media arrived but could not be displayed.';
    }
  }

  Future<void> _sendIce(RTCIceCandidate candidate) async {
    try {
      await _remoteSessionRepository.sendSignal(
        sessionId: sessionId,
        kind: SignalKind.ice,
        payload: candidate.toMap(),
      );
    } catch (_) {
      connectionWarning.value =
          'Some network candidates could not be shared. The call may struggle '
          'to connect on this network.';
    }
  }

  Future<void> endSession({String reason = 'ended_by_parent'}) async {
    if (isEnding.value) return;
    isEnding.value = true;
    actionError.value = null;
    try {
      await _remoteSessionRepository.end(
        sessionId: sessionId,
        reason: reason,
      );
    } catch (caught) {
      actionError.value = AppException.from(caught);
      isEnding.value = false;
      return;
    }
    _stopSignalWatch();
    _stopTicker();
    await _teardownMedia();
    final current = session.value;
    if (current != null && current.status.isOpen) {
      session.value = RemoteSession(
        id: current.id,
        familyId: current.familyId,
        deviceId: current.deviceId,
        parentUserId: current.parentUserId,
        childUserId: current.childUserId,
        kind: current.kind,
        status: RemoteSessionStatus.ended,
        requestedAt: current.requestedAt,
        expiresAt: current.expiresAt,
        acceptedAt: current.acceptedAt,
        endedAt: DateTime.now(),
        endedReason: reason,
        consentRecorded: current.consentRecorded,
        parentDisplayName: current.parentDisplayName,
        childDisplayName: current.childDisplayName,
        deviceName: current.deviceName,
      );
    }
    isEnding.value = false;
  }

  Future<void> _autoEndExpired() async {
    if (_autoEndAttempted || _isClosed) return;
    _autoEndAttempted = true;
    try {
      await _remoteSessionRepository.end(
        sessionId: sessionId,
        reason: 'expired',
      );
    } catch (_) {
      // The server cron also expires sessions; this is best effort.
    }
  }

  Future<void> _teardownMedia() async {
    _joinToken++;
    hasActivePeer.value = false;
    isConnected.value = false;
    isRemoteVideoActive.value = false;
    _pendingOffer = null;
    final peer = _peer;
    _peer = null;
    final local = _localStream;
    _localStream = null;
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {
        // Connection already gone.
      }
      await _disposePeer(peer);
    }
    await _stopTracks(local);
    if (_rendererInitialized) {
      try {
        remoteRenderer.srcObject = null;
      } catch (_) {
        // Renderer may already be disposed.
      }
    }
  }

  Future<void> _disposePeer(RTCPeerConnection? peer) async {
    if (peer == null) return;
    try {
      await peer.dispose();
    } catch (_) {
      // Already closed.
    }
  }

  Future<void> _stopTracks(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {
        // Track already ended.
      }
    }
    try {
      await stream.dispose();
    } catch (_) {
      // Stream already released.
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
      final current = session.value;
      if (current != null &&
          current.status.isOpen &&
          DateTime.now().isAfter(current.expiresAt)) {
        _stopTicker();
        _stopSignalWatch();
        unawaited(_teardownMedia());
        unawaited(_autoEndExpired());
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void onClose() {
    _isClosed = true;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = null;
    _stopSignalWatch();
    _stopTicker();
    unawaited(_shutdown());
    super.onClose();
  }

  Future<void> _shutdown() async {
    await _teardownMedia();
    await remoteRenderer.dispose();
  }
}
