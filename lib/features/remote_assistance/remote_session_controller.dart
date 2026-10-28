// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json_utils.dart';
import '../../data/models/remote_session.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/session_service.dart';

typedef SpeakerphoneHandler = Future<void> Function(bool enabled);
typedef PeerConnectionFactory = Future<RTCPeerConnection> Function(
  Map<String, dynamic> configuration,
);
typedef UserMediaCapture = Future<MediaStream> Function(
  Map<String, dynamic> constraints,
);

/// Numeric, non-content media counters sampled from WebRTC statistics.
///
/// Only counters and timestamp deltas are kept; payloads, audio and any other
/// media content are never read or stored.
class MediaStatsSnapshot {
  const MediaStatsSnapshot({
    required this.sampledAt,
    this.packetsSent = 0,
    this.bytesSent = 0,
    this.packetsReceived = 0,
    this.bytesReceived = 0,
    this.rtpTimestamp,
    this.rtpTimestampDelta = 0,
  });

  final DateTime sampledAt;
  final int packetsSent;
  final int bytesSent;
  final int packetsReceived;
  final int bytesReceived;

  /// Last RTP timestamp reported by the active audio reports, if any.
  final int? rtpTimestamp;
  final int rtpTimestampDelta;
}

/// One side of a consented assistance session.
///
/// The parent creates the offer; the child answers from its own visible screen.
/// Media is opened only from [join], which first verifies that the child has
/// accepted (or the session is already active) and has not expired. Nothing is
/// recorded, captured, or sent before that tap.
///
/// Capture ordering on the child device is strict: permissions (including the
/// Android 13 notification permission) and the microphone foreground service
/// are confirmed *before* `getUserMedia`, so audio can never run without the
/// visible microphone notification Android requires.
///
/// For audio assistance, the Parent is strictly receive-only: the Parent never
/// requests microphone permission or captures local audio. Incoming audio from
/// the Child is routed to the Parent loudspeaker.
class RemoteSessionController extends GetxController {
  RemoteSessionController({
    required RemoteSessionRepository remoteSessionRepository,
    required SessionService session,
    required DeviceAdminService deviceAdmin,
    required this.sessionId,
    required this.role,
    SpeakerphoneHandler? speakerphoneHandler,
    PeerConnectionFactory? peerConnectionFactory,
    UserMediaCapture? userMediaCapture,
    Duration serviceStartTimeout = const Duration(seconds: 5),
    Duration permissionPollInterval = const Duration(seconds: 2),
    Duration iceDisconnectGrace = const Duration(seconds: 3),
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
    Duration statsSampleInterval = const Duration(seconds: 5),
  })  : _remoteSessionRepository = remoteSessionRepository,
        _session = session,
        _deviceAdmin = deviceAdmin,
        _speakerphoneHandler = speakerphoneHandler,
        _peerConnectionFactory = peerConnectionFactory,
        _userMediaCapture = userMediaCapture,
        _serviceStartTimeout = serviceStartTimeout,
        _permissionPollInterval = permissionPollInterval,
        _iceDisconnectGrace = iceDisconnectGrace,
        _iceRestartBackoff = List<Duration>.unmodifiable(iceRestartBackoff),
        _iceRestartAttemptCap = iceRestartAttemptCap,
        _signalRetryBackoff = List<Duration>.unmodifiable(signalRetryBackoff),
        _statsSampleInterval = statsSampleInterval {
    // Subscribe here as well as in [onInit]: tests and route transitions can
    // construct the controller without GetX calling onInit, and the service
    // start handshake must never miss its confirmation event.
    _subscribeNativeEvents();
  }

  final RemoteSessionRepository _remoteSessionRepository;
  final SessionService _session;
  final DeviceAdminService _deviceAdmin;
  final SpeakerphoneHandler? _speakerphoneHandler;
  final PeerConnectionFactory? _peerConnectionFactory;
  final UserMediaCapture? _userMediaCapture;
  final String sessionId;
  final String role;

  final Duration _serviceStartTimeout;
  final Duration _permissionPollInterval;
  final Duration _iceDisconnectGrace;
  final List<Duration> _iceRestartBackoff;
  final Duration _iceRestartAttemptCap;
  final List<Duration> _signalRetryBackoff;
  final Duration _statsSampleInterval;

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

  /// Last numeric media counters. Never contains media content.
  final Rx<MediaStatsSnapshot?> mediaStats =
      Rx<MediaStatsSnapshot?>(null);

  /// Truthful terminal error for a failed [endSession] server confirmation.
  final RxnString endErrorText = RxnString();

  StreamSubscription<RemoteSession>? _sessionSubscription;
  StreamSubscription<List<WebRtcSignal>>? _signalSubscription;
  StreamSubscription<Map<String, dynamic>>? _nativeEventSubscription;
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  RTCSessionDescription? _pendingOffer;
  final List<RTCIceCandidate> _pendingIce = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  Timer? _ticker;
  Timer? _permissionTimer;
  Timer? _statsTimer;
  Timer? _iceGraceTimer;
  Timer? _iceRetryTimer;
  Timer? _iceAttemptTimer;
  Timer? _signalRetryTimer;
  final Set<String> _processedSignals = <String>{};
  bool _rendererInitialized = false;
  bool _speakerphoneActive = false;
  bool _iceLoading = false;
  bool _autoEndAttempted = false;
  bool _isClosed = false;
  bool _nativeEventsSubscribed = false;
  int _joinToken = 0;
  int _signalGeneration = 0;
  int _signalRetryAttempt = 0;
  bool _signalTerminal = false;
  int _iceRestartAttempts = 0;
  bool _permissionCheckInFlight = false;
  bool _fatalCaptureFailure = false;

  /// True only after Android confirmed the microphone foreground service.
  bool _serviceConfirmed = false;

  /// True while local capture tracks owned by this controller are running.
  bool _captureActive = false;

  Completer<bool>? _serviceStartCompleter;
  String? _serviceStartFailureReason;

  bool get hasContext => sessionId.isNotEmpty;

  /// Strict role checks. An empty/unknown role is treated as view-only and is
  /// never allowed to capture audio (fail closed).
  bool get isParentRole => role.trim().toLowerCase() == 'parent';
  bool get isChildRole => role.trim().toLowerCase() == 'child';
  bool get isValidRole => isParentRole || isChildRole;
  bool get isViewOnly => !isValidRole;

  bool get isExpired => session.value?.isExpired ?? false;
  bool get canJoin =>
      isValidRole &&
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

  /// True only while local tracks are live *and* (on the child) Android has
  /// confirmed the microphone foreground service. The UI must use this rather
  /// than [hasActivePeer] to claim that the microphone is on.
  bool get isMediaLive {
    if (isParentRole) return hasActivePeer.value && isConnected.value;
    if (!isChildRole) return false;
    return hasActivePeer.value &&
        _captureActive &&
        _serviceConfirmed &&
        _localStream != null;
  }

  /// User-visible reason when the server could not confirm the end.
  String? get endError => endErrorText.value;

  /// Read-only numeric snapshot for diagnostics/tests.
  MediaStatsSnapshot? get mediaStatsSnapshot => mediaStats.value;

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
    _subscribeNativeEvents();
    load();
  }

  void _subscribeNativeEvents() {
    if (_nativeEventsSubscribed) return;
    _nativeEventsSubscribed = true;
    _nativeEventSubscription = _deviceAdmin.events.listen((event) {
      // The microphone service belongs to the child capture path only. A
      // parent/view-only screen must never react to (or end because of) local
      // service events.
      if (!isChildRole) return;
      final type = jsonString(event['type']);
      switch (type) {
        case 'audio_assistance_started':
          _handleServiceStarted(event);
          break;
        case 'audio_assistance_start_failed':
          _handleServiceFailed(event);
          break;
        case 'audio_assistance_stopped':
          _handleServiceStopped(event);
          break;
      }
    });
  }

  void _handleServiceStarted(Map<String, dynamic> event) {
    final eventSessionId = jsonString(event['sessionId']);
    if (eventSessionId != null &&
        eventSessionId.isNotEmpty &&
        eventSessionId != sessionId) {
      return;
    }
    final waiter = _serviceStartCompleter;
    if (waiter != null && !waiter.isCompleted) {
      _serviceConfirmed = true;
      waiter.complete(true);
      return;
    }
    // A late/unsolicited event must not make an aborted join look live.
    if (_captureActive) _serviceConfirmed = true;
  }

  void _handleServiceFailed(Map<String, dynamic> event) {
    _serviceConfirmed = false;
    final reason = jsonString(event['reason']) ?? 'unknown';
    _serviceStartFailureReason = reason;
    final waiter = _serviceStartCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(false);
      return;
    }
    if (!hasActivePeer.value && !isJoining.value && !_captureActive) return;
    unawaited(
      _terminateForFailure(
        reason: 'microphone_service_failed',
        code: 'microphone_service_failed',
        message:
            'The microphone foreground service stopped ($reason). The session '
            'was ended so audio is not captured without its visible '
            'notification.',
      ),
    );
  }

  void _handleServiceStopped(Map<String, dynamic> event) {
    _serviceConfirmed = false;
    final reason = jsonString(event['reason']) ?? 'unknown';
    final waiter = _serviceStartCompleter;
    if (waiter != null && !waiter.isCompleted) {
      // Abort the start handshake; no capture has begun yet.
      _serviceStartFailureReason = reason;
      waiter.complete(false);
      return;
    }
    if (!hasActivePeer.value && !isJoining.value && !_captureActive) return;

    switch (reason) {
      case 'permission_denied':
      case 'permission_revoked':
        unawaited(
          _terminateForFailure(
            reason: 'permission_revoked',
            code: 'permission_revoked',
            permission: true,
            message:
                'Microphone permission was revoked, so the session was ended. '
                'The microphone will not be re-opened automatically.',
          ),
        );
        break;
      case 'service_destroyed':
        unawaited(
          _terminateForFailure(
            reason: 'service_destroyed',
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service stopped unexpectedly. The '
                'session was ended and audio capture stopped.',
          ),
        );
        break;
      case 'task_removed':
        unawaited(
          _terminateForFailure(
            reason: 'task_removed',
            code: 'session_ended',
            message:
                'The assistance screen was closed, so the session was ended '
                'and the microphone was released.',
          ),
        );
        break;
      case 'child_stopped':
        unawaited(
          _terminateForFailure(
            reason: 'ended_by_child',
            code: 'session_ended',
            message: 'The session was ended from the microphone notification.',
          ),
        );
        break;
      default:
        unawaited(
          _terminateForFailure(
            reason: 'ended_by_child',
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service stopped ($reason). The '
                'session was ended and audio capture stopped.',
          ),
        );
        break;
    }
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
    _sessionSubscription = _remoteSessionRepository
        .watchSession(sessionId)
        .listen(
          (updated) {
            final existing = session.value;
            // A late realtime update must not resurrect a session that already
            // ended locally (for example while end() was in flight).
            if (existing != null &&
                existing.status.isTerminal &&
                !updated.status.isTerminal) {
              return;
            }
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
    if (!isChildRole) {
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
      _stopPermissionWatch();
      _stopStatsSampling();
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
      iceConfig.value = await _remoteSessionRepository.fetchIceConfig(
        sessionId,
      );
    } catch (caught) {
      iceError.value = AppException.from(caught);
    } finally {
      _iceLoading = false;
    }
  }

  /// Opens the signaling stream. A stream error is retried with exponential
  /// backoff; every subscription gets a generation so callbacks from a stale
  /// subscription cannot mutate current state.
  void _ensureSignalWatch() {
    if (_isClosed || _signalTerminal) return;
    if (_signalSubscription != null || _signalRetryTimer != null) return;
    _openSignalWatch();
  }

  void _openSignalWatch() {
    final generation = ++_signalGeneration;
    _signalSubscription = _remoteSessionRepository
        .watchSignals(sessionId)
        .listen(
          (signals) {
            if (_isClosed || generation != _signalGeneration) return;
            realtimeError.value = null;
            _signalRetryAttempt = 0;
            for (final signal in signals) {
              _handleSignal(signal);
            }
          },
          onError: (Object caught) {
            _onSignalError(generation, caught);
          },
        );
  }

  void _onSignalError(int generation, Object caught) {
    if (_isClosed || generation != _signalGeneration) return;
    unawaited(_signalSubscription?.cancel());
    _signalSubscription = null;
    realtimeError.value = AppException.from(caught);
    if (_signalRetryAttempt >= _signalRetryBackoff.length) {
      _signalTerminal = true;
      realtimeError.value = const AppException(
        AppErrorCodes.network,
        'Live session signaling could not be restored after 5 attempts. End '
        'the session and request a new one; the microphone is not being '
        'reconnected.',
      );
      return;
    }
    final delay = _signalRetryBackoff[_signalRetryAttempt];
    _signalRetryAttempt += 1;
    _signalRetryTimer?.cancel();
    _signalRetryTimer = Timer(delay, () {
      _signalRetryTimer = null;
      if (_isClosed || _signalTerminal) return;
      _openSignalWatch();
    });
  }

  void _stopSignalWatch() {
    _signalRetryTimer?.cancel();
    _signalRetryTimer = null;
    _signalGeneration += 1;
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
      // The child may still be starting capture when the parent's offer
      // arrives. Keep the newest offer so join() can answer it instead of
      // losing the negotiation.
      if (isChildRole && signal.kind == SignalKind.offer) {
        final sdp = jsonString(signal.payload['sdp']);
        if (sdp != null && sdp.isNotEmpty) {
          _pendingOffer = RTCSessionDescription(
            sdp,
            jsonStringOr(signal.payload['type'], 'offer'),
          );
        }
      } else if (signal.kind == SignalKind.ice) {
        // Candidates can arrive before this side has a peer connection.
        // Dropping them would stall the connection on some networks.
        _bufferIce(signal.payload);
      }
      return;
    }
    unawaited(_applySignal(peer, signal));
  }

  Future<void> _applySignal(RTCPeerConnection peer, WebRtcSignal signal) async {
    try {
      switch (signal.kind) {
        case SignalKind.answer:
          final sdp = jsonString(signal.payload['sdp']);
          if (sdp == null || sdp.isEmpty) return;
          final type = jsonStringOr(signal.payload['type'], 'answer');
          await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
          _remoteDescriptionSet = true;
          await _flushPendingIce(peer);
          break;
        case SignalKind.ice:
          if (!_remoteDescriptionSet) {
            _bufferIce(signal.payload);
            return;
          }
          final candidate = _iceFrom(signal.payload);
          if (candidate == null) return;
          await peer.addCandidate(candidate);
          break;
        case SignalKind.offer:
          final sdp = jsonString(signal.payload['sdp']);
          if (sdp == null || sdp.isEmpty) return;
          // Either role may renegotiate (ICE restart), so both sides answer an
          // inbound offer. If this side was also restarting, the remote offer
          // wins and our pending restart is abandoned.
          _cancelIceRecovery();
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

  RTCIceCandidate? _iceFrom(Map<String, dynamic> payload) {
    final candidate = jsonString(payload['candidate']);
    if (candidate == null || candidate.isEmpty) return null;
    return RTCIceCandidate(
      candidate,
      jsonString(payload['sdpMid']),
      jsonInt(payload['sdpMLineIndex']),
    );
  }

  void _bufferIce(Map<String, dynamic> payload) {
    final candidate = _iceFrom(payload);
    if (candidate == null) return;
    if (_pendingIce.length >= 64) return;
    _pendingIce.add(candidate);
  }

  Future<void> _flushPendingIce(RTCPeerConnection peer) async {
    if (_pendingIce.isEmpty) return;
    final pending = List<RTCIceCandidate>.of(_pendingIce);
    _pendingIce.clear();
    for (final candidate in pending) {
      try {
        await peer.addCandidate(candidate);
      } catch (_) {
        connectionWarning.value =
            'Some network candidates could not be applied. The call may still '
            'connect on this network.';
      }
    }
  }

  Future<void> _answerOffer(
    RTCPeerConnection peer,
    RTCSessionDescription offer,
  ) async {
    await peer.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await _remoteSessionRepository.sendSignal(
      sessionId: sessionId,
      kind: SignalKind.answer,
      payload: {'sdp': answer.sdp, 'type': answer.type ?? 'answer'},
    );
    await _flushPendingIce(peer);
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
    if (!isValidRole) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'This screen has no valid assistance role, so the microphone and '
        'camera stay off. Return to the assistance list and open the session '
        'again.',
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
                  ? 'The child has not accepted this session. Media stays '
                        'off until the child consents.'
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
    _fatalCaptureFailure = false;
    _captureActive = false;
    _serviceConfirmed = false;

    MediaStream? local;
    RTCPeerConnection? peer;
    var serviceStarted = false;
    try {
      if (isChildRole) {
        final preflight = await _preflightChildCapture(token);
        if (!preflight) return;
        if (token != _joinToken || _isClosed) return;
        final serviceReady = await _startConfirmedAudioService(token);
        if (!serviceReady) return;
        serviceStarted = true;
        if (token != _joinToken || _isClosed) {
          await _cleanupFailedJoin(
            local: local,
            peer: peer,
            stopService: serviceStarted,
          );
          return;
        }
      }

      final config =
          iceConfig.value ??
          await _remoteSessionRepository.fetchIceConfig(sessionId);
      if (token != _joinToken || _isClosed) {
        await _cleanupFailedJoin(
          local: local,
          peer: peer,
          stopService: serviceStarted,
        );
        return;
      }
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

      MediaStream? localStream;
      if (isChildRole) {
        final constraints = <String, dynamic>{
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
            'highpassFilter': true,
          },
          if (latest.kind == SessionKind.video)
            'video': {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            },
        };
        final stream = await _captureUserMedia(constraints);
        local = stream;
        if (token != _joinToken || _isClosed) {
          await _cleanupFailedJoin(
            local: local,
            peer: peer,
            stopService: serviceStarted,
          );
          return;
        }
        localStream = stream;
        _localStream = stream;
        _captureActive = true;
      }

      final peerConnection = await _createPeer({
        'iceServers': config.iceServers
            .map((server) => server.toWebRtcMap())
            .toList(),
      });
      if (token != _joinToken || _isClosed) {
        await _cleanupFailedJoin(
          local: local,
          peer: peerConnection,
          stopService: serviceStarted,
        );
        return;
      }
      peer = peerConnection;
      _peer = peerConnection;
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        unawaited(_sendIce(candidate));
      };
      peerConnection.onIceConnectionState = (state) {
        _handleIceConnectionState(state);
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
        _handlePeerConnectionState(state);
      };

      if (localStream != null) {
        for (final track in localStream.getTracks()) {
          await peerConnection.addTrack(track, localStream);
        }
      }
      if (isParentRole) {
        final offerConstraints = <String, dynamic>{
          'mandatory': {
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': latest.kind == SessionKind.video,
          },
          'optional': [],
        };
        final offer = await peerConnection.createOffer(offerConstraints);
        await peerConnection.setLocalDescription(offer);
        if (token != _joinToken || _isClosed) {
          await _cleanupFailedJoin(
            local: local,
            peer: peer,
            stopService: serviceStarted,
          );
          return;
        }
        await _remoteSessionRepository.sendSignal(
          sessionId: sessionId,
          kind: SignalKind.offer,
          payload: {'sdp': offer.sdp, 'type': offer.type ?? 'offer'},
        );
      } else {
        final pending = _pendingOffer;
        _pendingOffer = null;
        if (pending != null) {
          await _answerOffer(peerConnection, pending);
        }
      }
      if (token != _joinToken || _isClosed) {
        await _cleanupFailedJoin(
          local: local,
          peer: peer,
          stopService: serviceStarted,
        );
        return;
      }
      hasActivePeer.value = true;
      if (isChildRole) {
        _startPermissionWatch();
      }
      _startStatsSampling();
      if (isChildRole &&
          session.value?.status == RemoteSessionStatus.accepted) {
        unawaited(_markActiveStarted());
      }
    } catch (caught) {
      await _cleanupFailedJoin(
        local: local,
        peer: peer,
        stopService: serviceStarted,
      );
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

  /// Child preflight: role is already validated, and no media may start until
  /// microphone permission, notification visibility and a non-one-time
  /// microphone grant are confirmed.
  Future<bool> _preflightChildCapture(int token) async {
    // Recording permission is confirmed first. Only after the OS grant does
    // the API 33+ notification requirement matter, because the foreground
    // service cannot present its mandatory privacy indicator without it.
    final permitted = await _requestMediaPermissions(
      needsCamera: session.value?.kind == SessionKind.video,
    );
    if (token != _joinToken || _isClosed) return false;
    if (!permitted) {
      permissionDenied.value = true;
      actionError.value = const AppException(
        'permission_denied',
        _permissionMessage,
      );
      return false;
    }

    final notificationsGranted = await _notificationsGranted();
    if (token != _joinToken || _isClosed) return false;
    if (!notificationsGranted) {
      actionError.value = const AppException(
        'notifications_required',
        'Notifications are turned off for this app, so Android cannot show '
        'the microphone status notification. Allow notifications for Parent '
        'Control, then try joining again. The microphone stays off.',
      );
      return false;
    }

    if (await _isOneTimeMicrophoneGrant()) {
      if (token != _joinToken || _isClosed) return false;
      actionError.value = const AppException(
        'microphone_one_time',
        'Android allowed the microphone only for this one time. Open Android '
        'Settings > Apps > Parent Control > Permissions > Microphone and '
        'choose "While using the app" (not "Only this time"), then join '
        'again. No audio was captured.',
      );
      return false;
    }
    return true;
  }

  /// Starts the microphone foreground service and waits for Android to confirm
  /// that it (and therefore the visible notification) is actually running.
  Future<bool> _startConfirmedAudioService(int token) async {
    final previous = _serviceStartCompleter;
    if (previous != null && !previous.isCompleted) previous.complete(false);
    final completer = Completer<bool>();
    _serviceStartCompleter = completer;
    _serviceStartFailureReason = null;

    bool started;
    try {
      started = await _deviceAdmin.startAudioAssistanceService(
        sessionId: sessionId,
      );
    } catch (caught) {
      if (identical(_serviceStartCompleter, completer)) {
        _serviceStartCompleter = null;
      }
      await _stopAudioAssistanceService();
      actionError.value = AppException.from(caught);
      return false;
    }

    if (token != _joinToken || _isClosed) {
      if (identical(_serviceStartCompleter, completer)) {
        _serviceStartCompleter = null;
      }
      await _stopAudioAssistanceService();
      return false;
    }

    if (!started) {
      if (identical(_serviceStartCompleter, completer)) {
        _serviceStartCompleter = null;
      }
      await _stopAudioAssistanceService();
      actionError.value = const AppException(
        'microphone_service_failed',
        'Android could not start the microphone status service, so the '
        'microphone stayed off. Check microphone and notification permission, '
        'then try again.',
      );
      return false;
    }

    bool confirmed;
    try {
      confirmed = await completer.future.timeout(_serviceStartTimeout);
    } on TimeoutException {
      confirmed = false;
    } finally {
      if (identical(_serviceStartCompleter, completer)) {
        _serviceStartCompleter = null;
      }
    }

    if (token != _joinToken || _isClosed) {
      await _stopAudioAssistanceService();
      return false;
    }

    if (!confirmed) {
      await _stopAudioAssistanceService();
      final failure = _serviceStartFailureReason;
      actionError.value = AppException(
        'microphone_service_failed',
        failure == null
            ? 'Android did not confirm the microphone status notification, so '
                  'the microphone stayed off. Check notification permission '
                  'and try again.'
            : 'Android could not start the microphone status service '
                  '($failure), so the microphone stayed off.',
      );
      return false;
    }

    _serviceConfirmed = true;
    return true;
  }

  Future<void> _cleanupFailedJoin({
    required MediaStream? local,
    required RTCPeerConnection? peer,
    required bool stopService,
  }) async {
    _captureActive = false;
    _serviceConfirmed = false;
    _stopPermissionWatch();
    _stopStatsSampling();
    if (local != null) {
      await _stopTracks(local);
      if (identical(_localStream, local)) _localStream = null;
    }
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {
        // Connection already gone.
      }
      await _disposePeer(peer);
      if (identical(_peer, peer)) _peer = null;
    }
    if (stopService) await _stopAudioAssistanceService();
    hasActivePeer.value = false;
    isConnected.value = false;
    _cancelIceRecovery();
    _pendingOffer = null;
    _pendingIce.clear();
    _remoteDescriptionSet = false;
  }

  static const _permissionMessage =
      'Camera or microphone permission was denied on this phone. Grant it in '
      'Android settings, then try joining again.';

  Future<bool> _notificationsGranted() async {
    // Newer native builds expose a dedicated check. When the bridge does not
    // have it yet, fall back to the capability snapshot, which already reports
    // the POST_NOTIFICATIONS state (and true on Android < 13).
    try {
      final dynamic admin = _deviceAdmin;
      final dynamic result = await admin.areNotificationsGranted();
      if (result is bool) return result;
    } on NoSuchMethodError {
      // Older bridge; use capabilities below.
    } catch (_) {
      // A native failure is not proof that notifications are blocked.
      return true;
    }
    try {
      final capabilities = await _deviceAdmin.getCapabilities();
      if (!capabilities.available) return true;
      return capabilities.notificationsGranted;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _isOneTimeMicrophoneGrant() async {
    try {
      final dynamic admin = _deviceAdmin;
      final dynamic result = await admin.isMicrophoneOneTimeGrant();
      return result == true;
    } on NoSuchMethodError {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Records the child-side start on the server once media is open. The call
  /// itself keeps running if this bookkeeping fails.
  Future<void> _markActiveStarted() async {
    try {
      final updated = await _remoteSessionRepository.markActive(sessionId);
      if (_isClosed || _fatalCaptureFailure) return;
      final current = session.value;
      if (current != null && current.status.isTerminal) return;
      session.value = updated;
    } catch (_) {
      connectionWarning.value =
          'The call is connected, but the server could not record that it '
          'started.';
    }
  }

  Future<MediaStream> _captureUserMedia(Map<String, dynamic> constraints) {
    final capture = _userMediaCapture;
    if (capture != null) return capture(constraints);
    return navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<RTCPeerConnection> _createPeer(Map<String, dynamic> configuration) {
    final factory = _peerConnectionFactory;
    if (factory != null) return factory(configuration);
    return createPeerConnection(configuration);
  }

  Future<void> _enableSpeakerphone(bool enable) async {
    try {
      final handler = _speakerphoneHandler;
      if (handler != null) {
        await handler(enable);
      } else {
        await Helper.setSpeakerphoneOn(enable);
      }
    } catch (_) {
      // Platform or device audio layer may not support speakerphone toggle.
    }
  }

  /// Asks Android for camera/microphone access before WebRTC opens either.
  ///
  /// For parent role, the parent is strictly receive-only, so no camera or
  /// microphone permissions are requested. An unknown role never reaches this
  /// method because [join] refuses it.
  ///
  /// An empty result means the native bridge is unavailable (for example on a
  /// test host); the media request is then left to report the real failure.
  Future<bool> _requestMediaPermissions({required bool needsCamera}) async {
    if (!isChildRole) return false;
    final result = await _deviceAdmin.requestPermissions(
      camera: needsCamera,
      microphone: true,
    );
    if (result.isEmpty) return true;
    final cameraOk = !needsCamera || result['camera'] == true;
    final microphoneOk = result['microphone'] == true;
    return cameraOk && microphoneOk;
  }

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
      if (stream.getVideoTracks().isNotEmpty) {
        if (!_rendererInitialized) {
          await remoteRenderer.initialize();
          _rendererInitialized = true;
        }
        if (_isClosed) return;
        remoteRenderer.srcObject = stream;
        isRemoteVideoActive.value = true;
      } else {
        isRemoteVideoActive.value = false;
      }
      if (isParentRole && stream.getAudioTracks().isNotEmpty) {
        await _enableSpeakerphone(true);
        _speakerphoneActive = true;
      }
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

  // ---------------------------------------------------------------------------
  // Network recovery
  // ---------------------------------------------------------------------------

  void _handleIceConnectionState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _onMediaConnected();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _onMediaDisconnected();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _onMediaFailed();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        _cancelIceRecovery();
        isConnected.value = false;
        break;
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
      case RTCIceConnectionState.RTCIceConnectionStateNew:
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        break;
    }
  }

  void _handlePeerConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _onMediaConnected();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _onMediaFailed();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _onMediaDisconnected();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _cancelIceRecovery();
        isConnected.value = false;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        isConnected.value = false;
        break;
    }
  }

  void _onMediaConnected() {
    _cancelIceRecovery();
    isConnected.value = true;
    connectionWarning.value = null;
  }

  void _onMediaDisconnected() {
    isConnected.value = false;
    if (_isClosed || !hasActivePeer.value) return;
    connectionWarning.value =
        'Network connection interrupted. Attempting to reconnect...';
    _startDisconnectGrace();
  }

  void _onMediaFailed() {
    isConnected.value = false;
    if (_isClosed || !hasActivePeer.value) return;
    connectionWarning.value =
        'The media connection failed. Trying to recover...';
    _cancelDisconnectGrace();
    _scheduleIceRecovery();
  }

  void _startDisconnectGrace() {
    if (_iceGraceTimer != null) return;
    _iceGraceTimer = Timer(_iceDisconnectGrace, () {
      _iceGraceTimer = null;
      if (_isClosed || isConnected.value || !hasActivePeer.value) return;
      _scheduleIceRecovery();
    });
  }

  void _cancelDisconnectGrace() {
    _iceGraceTimer?.cancel();
    _iceGraceTimer = null;
  }

  void _scheduleIceRecovery() {
    if (_isClosed || _peer == null || !hasActivePeer.value) return;
    if (isConnected.value) return;
    if (_iceRetryTimer != null || _iceAttemptTimer != null) return;
    if (_iceRestartAttempts >= _iceRestartBackoff.length) {
      _exhaustIceRecovery();
      return;
    }
    final delay = _iceRestartBackoff[_iceRestartAttempts];
    _iceRetryTimer = Timer(delay, () {
      _iceRetryTimer = null;
      if (_isClosed || isConnected.value || !hasActivePeer.value) return;
      unawaited(_attemptIceRestart());
    });
  }

  Future<void> _attemptIceRestart() async {
    final peer = _peer;
    if (peer == null || _isClosed || isConnected.value) return;
    _iceRestartAttempts += 1;
    Timer? capTimer;
    capTimer = Timer(_iceRestartAttemptCap, () {
      if (!identical(_iceAttemptTimer, capTimer)) return;
      _iceAttemptTimer = null;
      if (_isClosed || isConnected.value) return;
      _scheduleIceRecovery();
    });
    _iceAttemptTimer = capTimer;
    try {
      await peer.restartIce();
      final offer = await peer.createOffer(<String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo':
              session.value?.kind == SessionKind.video,
        },
        'optional': [],
      });
      await peer.setLocalDescription(offer);
      if (_isClosed ||
          isConnected.value ||
          !identical(_peer, peer)) {
        return;
      }
      await _remoteSessionRepository.sendSignal(
        sessionId: sessionId,
        kind: SignalKind.offer,
        payload: {'sdp': offer.sdp, 'type': offer.type ?? 'offer'},
      );
    } catch (_) {
      if (!identical(_iceAttemptTimer, capTimer)) return;
      capTimer.cancel();
      _iceAttemptTimer = null;
      if (_isClosed || isConnected.value) return;
      _scheduleIceRecovery();
    }
  }

  void _exhaustIceRecovery() {
    _cancelIceRecovery();
    if (_isClosed) return;
    const message =
        'The audio connection could not be recovered after two attempts. The '
        'session was ended and the microphone was released.';
    iceError.value = const AppException('media_connection_failed', message);
    connectionWarning.value =
        'The media connection could not be recovered. The session was ended.';
    unawaited(
      _terminateForFailure(
        reason: 'connection_failed',
        code: 'media_connection_failed',
        message: message,
      ),
    );
  }

  void _cancelIceRecovery() {
    _cancelDisconnectGrace();
    _iceRetryTimer?.cancel();
    _iceRetryTimer = null;
    _iceAttemptTimer?.cancel();
    _iceAttemptTimer = null;
    _iceRestartAttempts = 0;
  }

  // ---------------------------------------------------------------------------
  // Permission lifecycle
  // ---------------------------------------------------------------------------

  void _startPermissionWatch() {
    if (!isChildRole || _permissionTimer != null) return;
    _permissionTimer = Timer.periodic(_permissionPollInterval, (_) {
      unawaited(_checkMicrophoneStillGranted());
    });
  }

  void _stopPermissionWatch() {
    _permissionTimer?.cancel();
    _permissionTimer = null;
  }

  Future<void> _checkMicrophoneStillGranted() async {
    if (_isClosed || !_captureActive || _permissionCheckInFlight) return;
    _permissionCheckInFlight = true;
    try {
      final capabilities = await _deviceAdmin.getCapabilities();
      // An unavailable bridge is not proof of revocation; native service
      // events still cover permission loss.
      if (!capabilities.available) return;
      if (!capabilities.microphoneGranted && _captureActive && !_isClosed) {
        unawaited(
          _terminateForFailure(
            reason: 'permission_revoked',
            code: 'permission_revoked',
            permission: true,
            message:
                'Microphone permission is no longer granted, so the session '
                'was ended and the microphone was released. It will not be '
                're-opened automatically.',
          ),
        );
        return;
      }
      final serviceRunning =
          await _deviceAdmin.isAudioAssistanceServiceRunning();
      if (!serviceRunning && _captureActive && !_isClosed) {
        unawaited(
          _terminateForFailure(
            reason: 'service_destroyed',
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service is no longer running, so '
                'the session was ended and audio capture stopped.',
          ),
        );
      }
    } catch (_) {
      // A failed probe is not proof of revocation.
    } finally {
      _permissionCheckInFlight = false;
    }
  }

  /// Stops media and ends the session after a confirmed capture/permission or
  /// connection failure. Never re-acquires the microphone.
  Future<void> _terminateForFailure({
    required String reason,
    required String code,
    required String message,
    bool permission = false,
  }) async {
    if (_isClosed || _fatalCaptureFailure) return;
    _fatalCaptureFailure = true;
    _serviceConfirmed = false;
    _captureActive = false;
    _stopPermissionWatch();
    _stopStatsSampling();
    if (permission) permissionDenied.value = true;
    final ended = await endSession(reason: reason);
    if (permission) permissionDenied.value = true;
    if (ended) {
      actionError.value = AppException(code, message);
    } else if (actionError.value == null) {
      actionError.value = AppException(code, message);
    } else if (endErrorText.value != null) {
      actionError.value = AppException(
        code,
        '$message The server could not confirm the end: ${endErrorText.value}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  void _startStatsSampling() {
    if (_statsTimer != null) return;
    _statsTimer = Timer.periodic(_statsSampleInterval, (_) {
      unawaited(_sampleMediaStats());
    });
  }

  void _stopStatsSampling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _sampleMediaStats() async {
    final peer = _peer;
    if (peer == null || _isClosed) return;
    try {
      final reports = await peer.getStats();
      if (_isClosed) return;
      var packetsSent = 0;
      var bytesSent = 0;
      var packetsReceived = 0;
      var bytesReceived = 0;
      int? rtpTimestamp;
      for (final report in reports) {
        if (report.type == 'outbound-rtp') {
          packetsSent += _statInt(report.values['packetsSent']);
          bytesSent += _statInt(report.values['bytesSent']);
          rtpTimestamp ??= _statIntOrNull(report.values['timestamp']);
        } else if (report.type == 'inbound-rtp') {
          packetsReceived += _statInt(report.values['packetsReceived']);
          bytesReceived += _statInt(report.values['bytesReceived']);
          rtpTimestamp ??= _statIntOrNull(report.values['timestamp']);
        }
      }
      final previous = mediaStats.value;
      final delta = rtpTimestamp != null && previous?.rtpTimestamp != null
          ? rtpTimestamp - previous!.rtpTimestamp!
          : 0;
      mediaStats.value = MediaStatsSnapshot(
        sampledAt: DateTime.now(),
        packetsSent: packetsSent,
        bytesSent: bytesSent,
        packetsReceived: packetsReceived,
        bytesReceived: bytesReceived,
        rtpTimestamp: rtpTimestamp,
        rtpTimestampDelta: delta,
      );
    } catch (_) {
      // Statistics are diagnostic only; never affect the call.
    }
  }

  int _statInt(Object? raw) => _statIntOrNull(raw) ?? 0;

  int? _statIntOrNull(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Retrieves WebRTC stats (jitter, packet loss, RTT) for audio connection.
  Future<Map<String, dynamic>> getMediaStats() async {
    final peer = _peer;
    if (peer == null) return const {};
    try {
      final reports = await peer.getStats();
      final result = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'reportsCount': reports.length,
      };
      for (final report in reports) {
        if (report.type == 'inbound-rtp' ||
            report.type == 'outbound-rtp' ||
            report.type == 'candidate-pair') {
          result[report.id] = report.values;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  // ---------------------------------------------------------------------------
  // Termination
  // ---------------------------------------------------------------------------

  /// Ends the session locally and on the server.
  ///
  /// Returns `true` only when the server confirmed the end (or the session was
  /// already terminal). Local teardown failure never skips the server call;
  /// when the server end fails, [endError] stays populated, the local state is
  /// not presented as ended, and `false` is returned.
  Future<bool> endSession({String? reason}) async {
    if (isEnding.value) return false;
    final resolvedReason =
        reason ?? (isParentRole ? 'ended_by_parent' : 'ended_by_child');
    final alreadyTerminal = session.value?.status.isTerminal ?? false;
    isEnding.value = true;
    endErrorText.value = null;
    actionError.value = null;
    _fatalCaptureFailure = true;
    _stopSignalWatch();
    _stopTicker();
    _stopPermissionWatch();
    _stopStatsSampling();
    try {
      await _teardownMedia();
    } catch (_) {
      // Local teardown errors must not prevent the server termination attempt.
    }
    if (alreadyTerminal) {
      isEnding.value = false;
      return true;
    }
    try {
      await _remoteSessionRepository.end(
        sessionId: sessionId,
        reason: resolvedReason,
      );
    } catch (caught) {
      final failure = AppException.from(caught);
      endErrorText.value = failure.message;
      actionError.value = failure;
      isEnding.value = false;
      return false;
    }
    _applyLocalEnded(resolvedReason);
    // The end RPC succeeded, so a loaded session must be terminal locally too.
    // This guards against a UI that would otherwise keep presenting it live.
    final endedSession = session.value;
    if (endedSession != null && endedSession.status.isTerminal != true) {
      endErrorText.value =
          'The server accepted the end, but this screen could not confirm the '
          'session state. Refresh before continuing.';
      actionError.value = AppException(
        AppErrorCodes.unknown,
        endErrorText.value!,
      );
      isEnding.value = false;
      return false;
    }
    isEnding.value = false;
    return true;
  }

  void _applyLocalEnded(String reason) {
    final current = session.value;
    if (current == null || !current.status.isOpen) return;
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
    _cancelIceRecovery();
    _stopPermissionWatch();
    _stopStatsSampling();
    _serviceConfirmed = false;
    _captureActive = false;
    final waiter = _serviceStartCompleter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(false);
    _serviceStartCompleter = null;
    if (isChildRole) {
      await _stopAudioAssistanceService();
    }
    _joinToken += 1;
    hasActivePeer.value = false;
    isConnected.value = false;
    isRemoteVideoActive.value = false;
    _pendingOffer = null;
    _pendingIce.clear();
    _remoteDescriptionSet = false;
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
    if (_speakerphoneActive) {
      _speakerphoneActive = false;
      await _enableSpeakerphone(false);
    }
    if (_rendererInitialized) {
      try {
        remoteRenderer.srcObject = null;
      } catch (_) {
        // Renderer may already be disposed.
      }
    }
  }

  Future<void> _stopAudioAssistanceService() async {
    try {
      await _deviceAdmin.stopAudioAssistanceService();
    } catch (_) {
      // Service already stopped or bridge unavailable.
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
    _cancelIceRecovery();
    _stopPermissionWatch();
    _stopStatsSampling();
    _signalRetryTimer?.cancel();
    _signalRetryTimer = null;
    unawaited(_nativeEventSubscription?.cancel());
    _nativeEventSubscription = null;
    _nativeEventsSubscribed = false;
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
