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
typedef PeerConnectionFactory =
    Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);
typedef UserMediaCapture =
    Future<MediaStream> Function(Map<String, dynamic> constraints);

/// What [RemoteSessionController.join] must do with media that may already
/// exist when it is asked to connect.
///
/// Extracted as a pure value so the single-peer guarantee can be tested without
/// a real `RTCPeerConnection`.
enum PeerJoinDecision {
  /// No peer and no local media: build a fresh connection.
  create,

  /// A previous peer and/or local stream survived an earlier attempt but no
  /// capture is live (for example an interrupted child share): release them
  /// first, then build.
  replace,

  /// A live peer already exists (or a parent peer that is never replaced):
  /// this join is a no-op and must not create a second connection.
  noOp,
}

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
    Duration audioFlowGrace = const Duration(seconds: 12),
    Duration audioIdleTimeout = const Duration(seconds: 8),
    Duration captureHeartbeatInterval = const Duration(seconds: 10),
    Duration childReadyCooldown = const Duration(seconds: 3),
    Duration rejoinDebounce = const Duration(seconds: 2),
  }) : _remoteSessionRepository = remoteSessionRepository,
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
       _statsSampleInterval = statsSampleInterval,
       _audioFlowGrace = audioFlowGrace,
       _audioIdleTimeout = audioIdleTimeout,
       _captureHeartbeatInterval = captureHeartbeatInterval,
       _childReadyCooldown = childReadyCooldown,
       _rejoinDebounce = rejoinDebounce {
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
  final Duration _audioFlowGrace;
  final Duration _audioIdleTimeout;
  final Duration _captureHeartbeatInterval;
  final Duration _childReadyCooldown;

  /// Minimum spacing between two child rejoin ("this phone is ready") offers.
  /// Recovery retries that are already spaced by [iceRestartBackoff] are
  /// normally outside this window; this guard exists so a flapping network
  /// cannot emit duplicate offers back to back.
  final Duration _rejoinDebounce;

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

  /// True only while audio RTP packets are actually moving (outbound on the
  /// child, inbound on the parent). ICE/DTLS "connected" is not proof that
  /// media flows, so every "live" label in the UI requires this.
  final RxBool isMediaFlowing = false.obs;
  final RxBool isRemoteVideoActive = false.obs;
  final RxBool permissionDenied = false.obs;

  /// Mirrors the private capture flag for the UI. The microphone can be open
  /// while audio RTP has not started yet, so "mic on" must never be derived
  /// from [isMediaFlowing].
  final RxBool isCapturing = false.obs;

  /// True when Android reported that the assistance task was removed (Recents
  /// swipe, or the old `task_removed` stop reason) while the microphone
  /// foreground service kept running. The UI is gone but the consented session
  /// and capture are still live; this is not a termination signal.
  final RxBool childUiDetached = false.obs;

  final RxnString connectionWarning = RxnString();
  final Rx<DateTime> now = DateTime.now().obs;

  /// Last numeric media counters. Never contains media content.
  final Rx<MediaStatsSnapshot?> mediaStats = Rx<MediaStatsSnapshot?>(null);

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
  bool _rendererDisposed = false;
  bool _speakerphoneActive = false;
  bool _iceLoading = false;
  bool _isClosed = false;
  bool _nativeEventsSubscribed = false;
  int _joinToken = 0;
  int _signalGeneration = 0;
  int _signalRetryAttempt = 0;
  bool _signalTerminal = false;
  int _iceRestartAttempts = 0;
  bool _permissionCheckInFlight = false;
  bool _fatalCaptureFailure = false;

  /// True between sending an offer and applying its answer. An answer that
  /// arrives while no local offer is pending belongs to a previous negotiation
  /// (for example one replayed from the signaling table) and must not replace
  /// the current remote description.
  bool _localOfferPending = false;
  DateTime? _localOfferSentAt;

  /// Monotonic negotiation id carried in offer/answer payloads. Stored rows
  /// are replayed on every subscribe, so an answer must be matched to the
  /// offer it actually belongs to; timestamps would depend on clock skew.
  int _negotiationGeneration = 0;
  int? _pendingOfferGeneration;

  /// Signals created before this controller existed describe an earlier
  /// negotiation (a dead peer, a previous process). The signaling repository
  /// replays stored rows on every subscribe, so offers older than this horizon
  /// are ignored instead of being answered by a fresh peer. Ten seconds of
  /// slack absorbs small client/server clock differences.
  final DateTime _signalHorizon = DateTime.now().subtract(
    const Duration(seconds: 10),
  );

  DateTime? _lastChildReadyAt;
  bool _childReadyRecoveryInFlight = false;
  int _recoveryJoinAttempts = 0;
  int _readyRestartAttempts = 0;
  static const int _maxRecoveryJoins = 6;
  static const int _maxReadyRestarts = 4;

  /// Grace between ICE connection and the first RTP packet before the UI may
  /// say audio is unavailable. A short probe is not proof of a dead call.
  DateTime? _connectedAt;
  DateTime? _lastAudioPacketAt;
  Timer? _captureHeartbeatTimer;

  /// True only after Android confirmed the microphone foreground service.
  bool _serviceConfirmed = false;

  /// True from a confirmed native service start until it is stopped once.
  ///
  /// Teardown uses this snapshot to release the service exactly once, even when
  /// `_serviceConfirmed` was already cleared by the failure path that triggered
  /// the teardown.
  bool _nativeServiceRunning = false;

  /// Serializes [_teardownMedia] so a second caller awaits the first release
  /// instead of stopping the same tracks and peer twice.
  Future<void>? _teardownFuture;

  /// Child rejoin-offer debounce state. `_rejoinOfferInFlight` covers an offer
  /// whose `sendSignal` has not completed yet, so a duplicate cannot be queued
  /// behind it.
  bool _rejoinOfferInFlight = false;
  DateTime? _lastRejoinOfferAt;

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

  /// Pure single-peer decision for a `join`/`reconnect` request.
  ///
  /// - Nothing owned yet: [PeerJoinDecision.create].
  /// - A peer or local stream survived but no capture is live: the child may
  ///   rebuild, and the old media is released first
  ///   ([PeerJoinDecision.replace]).
  /// - Capture is still live, or this is the receive-only parent: never create a
  ///   second peer ([PeerJoinDecision.noOp]).
  static PeerJoinDecision decidePeerJoin({
    required bool hasPeer,
    required bool hasLocalMedia,
    required bool isChild,
    required bool captureActive,
  }) {
    if (!hasPeer && !hasLocalMedia) return PeerJoinDecision.create;
    if (captureActive) return PeerJoinDecision.noOp;
    if (!isChild) return PeerJoinDecision.noOp;
    return PeerJoinDecision.replace;
  }

  /// Consent withdrawn locally: the microphone/camera are off on this phone
  /// while the server session may still be open.
  final RxBool sharingStopped = false.obs;

  bool get canJoin =>
      isValidRole &&
      !isJoining.value &&
      // The child may take the microphone again on an open session after a
      // previous share was stopped; the parent never replaces a live peer.
      (!hasActivePeer.value || (isChildRole && !isCaptureActive)) &&
      session.value != null &&
      (session.value!.status == RemoteSessionStatus.accepted ||
          session.value!.status == RemoteSessionStatus.active);

  /// Ending the server session is the parent's authority. The child can only
  /// stop local capture ([withdrawConsent]).
  bool get canEnd {
    final current = session.value;
    return isParentRole && current != null && current.status.isOpen;
  }

  /// True for any consented session this child can withdraw consent from.
  ///
  /// The control must not disappear just because ICE recovery already tore the
  /// media down or because the peer was never established: the session stays
  /// open until the parent ends it, and the child must always be able to see
  /// and use its consent-withdrawal control. [withdrawConsent] is idempotent
  /// when nothing is capturing.
  bool get canStopSharing {
    final current = session.value;
    return isChildRole &&
        current != null &&
        (current.status == RemoteSessionStatus.accepted ||
            current.status == RemoteSessionStatus.active) &&
        !current.isExpired;
  }

  /// True only while local tracks are live *and* (on the child) Android has
  /// confirmed the microphone foreground service. The UI must use
  /// [isMediaFlowing] rather than this getter to claim that audio is live.
  bool get isMediaLive {
    if (isParentRole) return hasActivePeer.value && isConnected.value;
    if (!isChildRole) return false;
    return hasActivePeer.value &&
        _captureActive &&
        _serviceConfirmed &&
        _localStream != null;
  }

  /// True while this child phone owns live microphone (and camera) tracks.
  ///
  /// This is local capture state only: it is true as soon as `getUserMedia`
  /// returned and the microphone service is confirmed, even if no audio RTP
  /// has reached the parent yet. The UI must use this — never [isMediaFlowing]
  /// — to say whether the microphone is on.
  bool get isCaptureActive =>
      isChildRole && isCapturing.value && _serviceConfirmed;

  void _setCaptureActive(bool value) {
    _captureActive = value;
    if (isCapturing.value != value) isCapturing.value = value;
  }

  /// ICE is up but no audio RTP has arrived yet, and the grace period has not
  /// elapsed. The UI shows "Checking audio…" instead of claiming live audio.
  bool get isCheckingAudio {
    if (!hasActivePeer.value || !isConnected.value || isMediaFlowing.value) {
      return false;
    }
    final since = _connectedAt;
    if (since == null) return true;
    return now.value.difference(since) < _audioFlowGrace;
  }

  /// ICE reports connected, the grace period elapsed, and still no audio RTP.
  /// The session stays open; the device is not receiving or sending audio.
  bool get audioUnavailable {
    if (!hasActivePeer.value || !isConnected.value || isMediaFlowing.value) {
      return false;
    }
    final since = _connectedAt;
    if (since == null) return false;
    return now.value.difference(since) >= _audioFlowGrace;
  }

  /// User-visible reason when the server could not confirm the end.
  String? get endError => endErrorText.value;

  /// Read-only numeric snapshot for diagnostics/tests.
  MediaStatsSnapshot? get mediaStatsSnapshot => mediaStats.value;

  /// What the status chip says.
  ///
  /// Only the branch for a server-active session can ever say anything that
  /// implies live media, and each of those labels requires
  /// [hasActivePeer] — a lone server status never reads as "live". A terminal
  /// server state always wins (it can only come from the server, never from a
  /// local reconnect in progress), so this never says "ended" while a
  /// reconnect window is still open, and never hides an end behind
  /// "Sharing stopped".
  String get statusLabel {
    final current = session.value;
    if (current == null) return 'Unknown';
    if (current.status == RemoteSessionStatus.requested && current.isExpired) {
      return 'Request expired';
    }
    if (current.status.isTerminal) return current.status.label;
    if (sharingStopped.value) return 'Sharing stopped';
    if (current.status == RemoteSessionStatus.active) {
      if (isJoining.value) return 'Connecting';
      if (hasActivePeer.value) {
        if (!isConnected.value) return 'Reconnecting';
        if (isMediaFlowing.value) return 'Active';
        return audioUnavailable ? 'Audio unavailable' : 'Checking audio…';
      }
      return 'Session active';
    }
    return current.status.label;
  }

  /// Lifetime of the session, worded per policy.
  ///
  /// Only a pending request counts down; a consented session has no deadline
  /// and lasts until the parent ends it.
  String get sessionDurationLabel {
    final current = session.value;
    if (current == null) return '—';
    if (current.status == RemoteSessionStatus.requested) {
      final remaining = current.remaining;
      if (remaining == null || remaining == Duration.zero) return 'Expired';
      return 'Waiting for consent (${formatDurationMs(remaining.inMilliseconds)} left)';
    }
    if (current.isParentControlled) {
      return isParentRole
          ? 'Until you end the session'
          : 'Until your guardian ends the session';
    }
    return '—';
  }

  /// Informational elapsed time since consent. Never a termination trigger.
  String get elapsedLabel {
    final current = session.value;
    final start = current?.acceptedAt;
    if (start == null) return '—';
    final elapsed = now.value.difference(start);
    if (elapsed.isNegative) return '—';
    return formatDurationMs(elapsed.inMilliseconds);
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
        case 'audio_assistance_detached':
          _handleUiDetached(event);
          break;
      }
    });
  }

  /// The native side reports that the child's task was removed from Recents
  /// while the microphone foreground service (and capture) kept running. This
  /// must never end the session: only an explicit stop, a permission loss or a
  /// destroyed service may do that.
  void _handleUiDetached(Map<String, dynamic> event) {
    final eventSessionId = jsonString(event['sessionId']);
    if (eventSessionId != null &&
        eventSessionId.isNotEmpty &&
        eventSessionId != sessionId) {
      return;
    }
    childUiDetached.value = true;
  }

  void _handleServiceStarted(Map<String, dynamic> event) {
    final eventSessionId = jsonString(event['sessionId']);
    if (eventSessionId != null &&
        eventSessionId.isNotEmpty &&
        eventSessionId != sessionId) {
      return;
    }
    _nativeServiceRunning = true;
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
    _nativeServiceRunning = false;
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
        code: 'microphone_service_failed',
        message:
            'The microphone foreground service stopped ($reason), so sharing '
            'ended on this phone. The session stays open until your guardian '
            'ends it.',
      ),
    );
  }

  void _handleServiceStopped(Map<String, dynamic> event) {
    final reason = jsonString(event['reason']) ?? 'unknown';
    if (reason == 'task_removed') {
      // An older APK reports a Recents swipe as a service stop even though the
      // microphone service keeps running. That is a detached UI, never a
      // reason to end a live consented session or release the microphone.
      childUiDetached.value = true;
      return;
    }
    _serviceConfirmed = false;
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
            code: 'permission_revoked',
            permission: true,
            message:
                'Microphone permission was revoked, so sharing stopped on this '
                'phone. The microphone will not be re-opened automatically; the '
                'session stays open until your guardian ends it.',
          ),
        );
        break;
      case 'service_destroyed':
        unawaited(
          _terminateForFailure(
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service stopped unexpectedly, so '
                'sharing stopped on this phone. The session stays open until '
                'your guardian ends it.',
          ),
        );
        break;
      case 'capture_lost':
        unawaited(
          _terminateForFailure(
            code: 'microphone_service_failed',
            message:
                'The microphone service stopped because this phone could no '
                'longer confirm live audio capture. Sharing stopped; the '
                'session stays open until your guardian ends it.',
          ),
        );
        break;
      case 'child_stopped':
        unawaited(
          _terminateForFailure(
            code: 'sharing_stopped',
            message:
                'Sharing was stopped from the microphone notification. The '
                'session stays open until your guardian ends it.',
          ),
        );
        break;
      default:
        unawaited(
          _terminateForFailure(
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service stopped ($reason), so '
                'sharing stopped on this phone. The session stays open until '
                'your guardian ends it.',
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
    _resetSignalRetry();
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
      // A successful read proves the server state is current; a banner left
      // over from an earlier channel error must not outlive it.
      realtimeError.value = null;
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
      // Only a pending request can reach this: it lapsed before consent, so
      // there is no media and nothing to end. The server owns the expiry.
      _stopSignalWatch();
      _stopTicker();
      unawaited(_teardownMedia());
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

  /// Re-arms signaling after the bounded retry budget was exhausted.
  ///
  /// An explicit refresh or join is a user-initiated new attempt, so it must
  /// not stay blocked forever by the previous attempt's terminal state.
  void _resetSignalRetry() {
    if (!_signalTerminal && _signalRetryTimer == null) return;
    _signalRetryTimer?.cancel();
    _signalRetryTimer = null;
    _signalRetryAttempt = 0;
    _signalTerminal = false;
    _signalGeneration += 1;
    unawaited(_signalSubscription?.cancel());
    _signalSubscription = null;
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
        'Live session signaling could not be restored after 5 attempts. The '
        'session is still open on the server; refresh to retry, or let the '
        'parent end it.',
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
    if (signal.kind != SignalKind.ice &&
        signal.createdAt.isBefore(_signalHorizon)) {
      // Stored rows from an earlier negotiation (a dead peer, a previous
      // process). Answering them binds a fresh peer to a stale offer, and a
      // replayed "ready" row would ask the parent to negotiate again.
      return;
    }
    // An offer with no SDP is our cross-version "this phone is ready" request.
    // It asks the offerer to negotiate again and is never applied as SDP.
    if (_isReadyRequest(signal)) {
      if (isParentRole) unawaited(_handleChildReady());
      return;
    }
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
          _pendingOfferGeneration = jsonInt(signal.payload['gen']);
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

  static bool _isReadyRequest(WebRtcSignal signal) {
    if (signal.kind != SignalKind.offer) return false;
    if (signal.payload['ready'] != true) return false;
    final sdp = jsonString(signal.payload['sdp']);
    return sdp == null || sdp.isEmpty;
  }

  Future<void> _applySignal(RTCPeerConnection peer, WebRtcSignal signal) async {
    if (_isClosed || !identical(_peer, peer)) return;
    try {
      switch (signal.kind) {
        case SignalKind.answer:
          if (!_localOfferPending) return;
          final generation = jsonInt(signal.payload['gen']);
          if (generation != null &&
              _pendingOfferGeneration != null &&
              generation != _pendingOfferGeneration) {
            return;
          }
          final sdp = jsonString(signal.payload['sdp']);
          if (sdp == null || sdp.isEmpty) return;
          final type = jsonStringOr(signal.payload['type'], 'answer');
          await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
          _localOfferPending = false;
          _localOfferSentAt = null;
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
          if (isParentRole && _localOfferPending) {
            // The parent is the sole offerer. libwebrtc refuses a remote offer
            // while it holds a local one, so answering would only fail; the
            // child answers our pending offer instead.
            return;
          }
          // Either role may renegotiate (ICE restart), so both sides answer an
          // inbound offer. If this side was also restarting, the remote offer
          // wins and our pending restart is abandoned.
          _cancelIceRecovery();
          _localOfferPending = false;
          _localOfferSentAt = null;
          // A healthy child ignores a replayed offer; renegotiation is only
          // meaningful while the connection is down.
          if (isChildRole && _remoteDescriptionSet && isConnected.value) {
            return;
          }
          await _answerOffer(
            peer,
            RTCSessionDescription(
              sdp,
              jsonStringOr(signal.payload['type'], 'offer'),
            ),
            jsonInt(signal.payload['gen']),
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
    RTCSessionDescription offer, [
    int? generation,
  ]) async {
    await peer.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await _remoteSessionRepository.sendSignal(
      sessionId: sessionId,
      kind: SignalKind.answer,
      payload: {
        'sdp': answer.sdp,
        'type': answer.type ?? 'answer',
        'gen': ?generation,
      },
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
    if (current.status != RemoteSessionStatus.accepted &&
        current.status != RemoteSessionStatus.active) {
      actionError.value = AppException(
        'consent_required',
        isParentRole
            ? 'The child has not accepted this session. Media stays off until '
                  'the child consents.'
            : 'Accept this request before turning on your camera or microphone.',
      );
      return;
    }
    if (isJoining.value) return;
    // Single peer guarantee: a second join/reconnect while media exists either
    // replaces it (child rebuild after a stop) or is a no-op. It never creates
    // a second live peer or a second capture.
    final decision = decidePeerJoin(
      hasPeer: _peer != null,
      hasLocalMedia: _localStream != null,
      isChild: isChildRole,
      captureActive: _captureActive,
    );
    if (decision == PeerJoinDecision.noOp) return;
    if (decision == PeerJoinDecision.replace) {
      isJoining.value = true;
      try {
        await _teardownMedia();
      } catch (_) {
        isJoining.value = false;
        actionError.value = const AppException(
          'media_connection_failed',
          'The previous media connection could not be closed. Try again.',
        );
        return;
      }
    }

    final token = ++_joinToken;
    isJoining.value = true;
    permissionDenied.value = false;
    actionError.value = null;
    connectionWarning.value = null;
    // A retry starts a new attempt: the previous attempt's failure banner must
    // not describe the connection that is being rebuilt.
    iceError.value = null;
    _fatalCaptureFailure = false;
    _setCaptureActive(false);
    _serviceConfirmed = false;
    _resetAudioFlow();
    sharingStopped.value = false;
    _resetSignalRetry();
    _ensureSignalWatch();

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
            token: token,
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
          token: token,
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
          (latest.status != RemoteSessionStatus.accepted &&
              latest.status != RemoteSessionStatus.active)) {
        throw const AppException(
          'consent_required',
          'The session is no longer accepted. No camera or microphone was '
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
            token: token,
          );
          return;
        }
        localStream = stream;
        _localStream = stream;
        _setCaptureActive(true);
        _startCaptureHeartbeat();
      }

      final peerConnection = await _createExclusivePeer({
        'iceServers': config.iceServers
            .map((server) => server.toWebRtcMap())
            .toList(),
      });
      if (token != _joinToken || _isClosed) {
        await _cleanupFailedJoin(
          local: local,
          peer: peerConnection,
          stopService: serviceStarted,
          token: token,
        );
        return;
      }
      peer = peerConnection;
      _peer = peerConnection;
      _localOfferPending = false;
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        if (!identical(_peer, peerConnection)) return;
        unawaited(_sendIce(peerConnection, candidate));
      };
      peerConnection.onIceConnectionState = (state) {
        if (!identical(_peer, peerConnection)) return;
        _handleIceConnectionState(state);
      };
      peerConnection.onTrack = (event) {
        if (!identical(_peer, peerConnection)) return;
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
        if (!identical(_peer, peerConnection)) return;
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
        final generation = ++_negotiationGeneration;
        _localOfferPending = true;
        _localOfferSentAt = DateTime.now();
        _pendingOfferGeneration = generation;
        if (token != _joinToken || _isClosed) {
          await _cleanupFailedJoin(
            local: local,
            peer: peer,
            stopService: serviceStarted,
            token: token,
          );
          return;
        }
        await _remoteSessionRepository.sendSignal(
          sessionId: sessionId,
          kind: SignalKind.offer,
          payload: {
            'sdp': offer.sdp,
            'type': offer.type ?? 'offer',
            'gen': generation,
          },
        );
      } else {
        final pending = _pendingOffer;
        final pendingGeneration = _pendingOfferGeneration;
        _pendingOffer = null;
        _pendingOfferGeneration = null;
        if (pending != null) {
          await _answerOffer(peerConnection, pending, pendingGeneration);
        } else {
          // The child has capture and a peer but no offer to answer. Ask the
          // parent to negotiate now instead of waiting for a manual join on
          // both devices. Sent only after consent, capture and the visible
          // microphone service are all confirmed.
          unawaited(_announceChildReady(token));
        }
      }
      if (token != _joinToken || _isClosed) {
        await _cleanupFailedJoin(
          local: local,
          peer: peer,
          stopService: serviceStarted,
          token: token,
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
        token: token,
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
    _nativeServiceRunning = true;
    return true;
  }

  Future<void> _cleanupFailedJoin({
    required MediaStream? local,
    required RTCPeerConnection? peer,
    required bool stopService,
    int? token,
  }) async {
    // A cleanup that belongs to a superseded attempt must release only its own
    // objects; clearing the shared flags would blind a newer join that is
    // already running.
    final ownsState = token == null || token == _joinToken;
    if (ownsState) {
      _setCaptureActive(false);
      _serviceConfirmed = false;
      _stopCaptureHeartbeat();
      _stopPermissionWatch();
      _stopStatsSampling();
      _resetAudioFlow();
    }
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
    if (stopService && ownsState) await _stopAudioServiceOnce();
    if (!ownsState) return;
    hasActivePeer.value = false;
    isConnected.value = false;
    _cancelIceRecovery();
    _pendingOffer = null;
    _pendingIce.clear();
    _remoteDescriptionSet = false;
    _localOfferPending = false;
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

  /// Creates the one peer connection this controller may own.
  ///
  /// The join-level [decidePeerJoin] already released replaced media. This is
  /// the last line of the single-peer invariant: if a peer nevertheless survived
  /// an earlier attempt, it is closed and disposed *before* the new one is
  /// created, so two live connections can never coexist.
  Future<RTCPeerConnection> _createExclusivePeer(
    Map<String, dynamic> configuration,
  ) async {
    final previous = _peer;
    if (previous != null) {
      _peer = null;
      try {
        await previous.close();
      } catch (_) {
        // Connection already gone.
      }
      await _disposePeer(previous);
    }
    return _createPeer(configuration);
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

  Future<void> _sendIce(
    RTCPeerConnection peer,
    RTCIceCandidate candidate,
  ) async {
    if (_isClosed || !identical(_peer, peer)) return;
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

  // ---------------------------------------------------------------------------
  // Automatic recovery
  // ---------------------------------------------------------------------------

  /// Tells the other side that this phone has live capture but no negotiated
  /// media. It reuses the `offer` kind with no SDP so it stays inside the
  /// existing signaling schema and policy; a receiver treats it as a request
  /// to negotiate, never as an answerable offer.
  Future<void> _announceChildReady(int token) async {
    if (_isClosed ||
        token != _joinToken ||
        !isChildRole ||
        !_captureActive ||
        !_serviceConfirmed ||
        sharingStopped.value) {
      return;
    }
    final current = session.value;
    if (current == null ||
        (current.status != RemoteSessionStatus.accepted &&
            current.status != RemoteSessionStatus.active)) {
      return;
    }
    // Rejoin debounce: a flapping network can trigger several recovery paths at
    // once. While one offer is still being sent, or inside the debounce window
    // of the last one, this request is dropped instead of duplicating the
    // payload. The signaling schema is unchanged: the same `offer` kind with an
    // empty SDP.
    if (_rejoinOfferInFlight) return;
    final now = DateTime.now();
    final last = _lastRejoinOfferAt;
    if (last != null && now.difference(last) < _rejoinDebounce) return;
    _lastRejoinOfferAt = now;
    _rejoinOfferInFlight = true;
    try {
      await _remoteSessionRepository.sendSignal(
        sessionId: sessionId,
        kind: SignalKind.offer,
        payload: const {'ready': true, 'sdp': '', 'type': 'offer'},
      );
    } catch (_) {
      connectionWarning.value =
          'The other device could not be told that this phone is ready. The '
          'session is still open.';
    } finally {
      _rejoinOfferInFlight = false;
    }
  }

  /// Parent-side answer to [_announceChildReady].
  ///
  /// The child only sends this after it has consent, capture and the
  /// microphone service, so negotiating again is authorized. Renegotiation is
  /// idempotent: a pending local offer is reused, and repeated requests are
  /// rate-limited and bounded.
  Future<void> _handleChildReady() async {
    if (_isClosed || !isParentRole || _childReadyRecoveryInFlight) return;
    final current = session.value;
    if (current == null ||
        (current.status != RemoteSessionStatus.accepted &&
            current.status != RemoteSessionStatus.active) ||
        current.isExpired) {
      return;
    }
    final now = DateTime.now();
    final last = _lastChildReadyAt;
    if (last != null && now.difference(last) < _childReadyCooldown) return;
    _lastChildReadyAt = now;
    // The answer to an offer that is already in flight is the best response;
    // sending another offer in parallel would create two negotiations. An
    // offer that stayed unanswered for longer than a negotiation can take is
    // treated as lost, so a dead peer cannot hide the Join control forever.
    final offerSentAt = _localOfferSentAt;
    final offerStillPending =
        _localOfferPending &&
        offerSentAt != null &&
        now.difference(offerSentAt) < const Duration(seconds: 10);
    if (offerStillPending) return;
    _localOfferPending = false;

    _childReadyRecoveryInFlight = true;
    try {
      final peer = _peer;
      if (peer != null && hasActivePeer.value) {
        if (isMediaFlowing.value) return;
        if (_iceAttemptTimer != null || _iceRetryTimer != null) return;
        if (_readyRestartAttempts >= _maxReadyRestarts) {
          _exhaustIceRecovery();
          return;
        }
        _readyRestartAttempts += 1;
        // A restarted child is a new negotiation generation: give the ICE
        // restart a fresh bounded budget instead of inheriting the budget
        // spent on the dead peer.
        _iceRestartAttempts = 0;
        _cancelDisconnectGrace();
        await _attemptIceRestart(force: true);
        return;
      }
      if (isJoining.value) return;
      if (_recoveryJoinAttempts >= _maxRecoveryJoins) {
        iceError.value = const AppException(
          'media_connection_failed',
          'The media connection could not be restored after several attempts. '
              'The session is still open; reconnect the network or reopen this '
              'screen to try again.',
        );
        return;
      }
      _recoveryJoinAttempts += 1;
      await join();
    } finally {
      _childReadyRecoveryInFlight = false;
    }
  }

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
        _resetAudioFlow();
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
        _resetAudioFlow();
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
    if (!isConnected.value) {
      // A new connection must prove media flow again before the UI claims
      // audio is live.
      _resetAudioFlow();
      _connectedAt = DateTime.now();
      now.value = _connectedAt!;
    }
    isConnected.value = true;
    connectionWarning.value = null;
    // The failure banner describes the connection that was lost; once the peer
    // is connected again it must not outlive the failure.
    iceError.value = null;
    unawaited(_sampleMediaStats());
  }

  void _onMediaDisconnected() {
    _resetAudioFlow();
    isConnected.value = false;
    if (_isClosed || !hasActivePeer.value) return;
    connectionWarning.value =
        'Network connection interrupted. Attempting to reconnect...';
    _startDisconnectGrace();
  }

  void _onMediaFailed() {
    _resetAudioFlow();
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
      if (isChildRole) {
        // Only the parent negotiates. Two simultaneous offers put both peers
        // in have-local-offer, and libwebrtc then rejects both remote SDPs.
        unawaited(_requestParentRenegotiation());
        return;
      }
      unawaited(_attemptIceRestart());
    });
  }

  /// Child-side recovery: ask the parent to negotiate again instead of
  /// creating a competing offer.
  Future<void> _requestParentRenegotiation() async {
    if (_isClosed || isConnected.value || !hasActivePeer.value) return;
    _iceRestartAttempts += 1;
    Timer? capTimer;
    capTimer = Timer(_iceRestartAttemptCap, () {
      if (!identical(_iceAttemptTimer, capTimer)) return;
      _iceAttemptTimer = null;
      if (_isClosed || isConnected.value) return;
      _scheduleIceRecovery();
    });
    _iceAttemptTimer = capTimer;
    await _announceChildReady(_joinToken);
  }

  Future<void> _attemptIceRestart({bool force = false}) async {
    final peer = _peer;
    if (!isParentRole ||
        peer == null ||
        _isClosed ||
        (isConnected.value && !force)) {
      return;
    }
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
      // TURN credentials are short-lived and independent of session lifetime.
      // Reissues them through the authorized backend before every restart so a
      // connection is never attempted with an expired credential.
      final iceServers = await _refreshIceServers();
      if (iceServers != null && iceServers.isNotEmpty) {
        try {
          await peer.setConfiguration({'iceServers': iceServers});
        } catch (_) {
          // Older platform implementations may reject setConfiguration; the
          // restart below still uses the original servers.
        }
      }
      await peer.restartIce();
      final offer = await peer.createOffer(<String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': session.value?.kind == SessionKind.video,
        },
        'optional': [],
      });
      await peer.setLocalDescription(offer);
      if (_isClosed ||
          (isConnected.value && !force) ||
          !identical(_peer, peer)) {
        return;
      }
      final generation = ++_negotiationGeneration;
      _localOfferPending = true;
      _localOfferSentAt = DateTime.now();
      _pendingOfferGeneration = generation;
      await _remoteSessionRepository.sendSignal(
        sessionId: sessionId,
        kind: SignalKind.offer,
        payload: {
          'sdp': offer.sdp,
          'type': offer.type ?? 'offer',
          'gen': generation,
        },
      );
    } catch (_) {
      if (!identical(_iceAttemptTimer, capTimer)) return;
      capTimer.cancel();
      _iceAttemptTimer = null;
      if (_isClosed || isConnected.value) return;
      _scheduleIceRecovery();
    }
  }

  /// Connection loss is never a session termination. After the retry budget the
  /// device stops sharing (so no microphone stays open with a dead peer) and
  /// the server session stays open for the parent to end.
  void _exhaustIceRecovery() {
    _cancelIceRecovery();
    if (_isClosed) return;
    _localOfferPending = false;
    iceError.value = const AppException(
      'media_connection_failed',
      'The media connection could not be restored. Sharing is paused on this '
          'device; the session stays open until the parent ends it. Reconnect to '
          'try again.',
    );
    connectionWarning.value =
        'The media connection could not be recovered. The session is still open.';
    unawaited(_pauseMediaAfterConnectionLoss());
  }

  Future<void> _pauseMediaAfterConnectionLoss() async {
    _serviceConfirmed = false;
    _setCaptureActive(false);
    if (isChildRole) sharingStopped.value = true;
    try {
      await _teardownMedia();
    } catch (_) {
      // Local release is best effort; the session record is unaffected.
    }
  }

  /// Returns ICE servers for a restart, reissuing credentials when the cached
  /// ones are missing or about to expire. A failed refresh falls back to the
  /// cached list; it never blocks the reconnect attempt or ends the session.
  Future<List<Map<String, dynamic>>?> _refreshIceServers() async {
    final cached = iceConfig.value;
    final expires = cached?.expiresAt;
    final needsRefresh =
        cached == null ||
        cached.iceServers.isEmpty ||
        (expires != null &&
            expires.isBefore(DateTime.now().add(const Duration(seconds: 30))));
    if (!needsRefresh) return _iceServersMap(cached);
    try {
      final fresh = await _remoteSessionRepository.fetchIceConfig(sessionId);
      if (fresh.iceServers.isEmpty) return _iceServersMap(cached);
      iceConfig.value = fresh;
      return _iceServersMap(fresh);
    } catch (_) {
      return _iceServersMap(cached);
    }
  }

  static List<Map<String, dynamic>>? _iceServersMap(IceConfig? config) {
    if (config == null || config.iceServers.isEmpty) return null;
    return config.iceServers.map((server) => server.toWebRtcMap()).toList();
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
            code: 'permission_revoked',
            permission: true,
            message:
                'Microphone permission is no longer granted, so sharing stopped '
                'and the microphone was released. It will not be re-opened '
                'automatically; the session stays open until your guardian ends '
                'it.',
          ),
        );
        return;
      }
      final serviceRunning = await _deviceAdmin
          .probeAudioAssistanceServiceRunning();
      // A null probe means the bridge could not be read. Only an explicit
      // "not running" may terminate local capture.
      if (serviceRunning == false && _captureActive && !_isClosed) {
        unawaited(
          _terminateForFailure(
            code: 'microphone_service_failed',
            message:
                'The microphone foreground service is no longer running, so '
                'sharing stopped on this phone. The session stays open until '
                'your guardian ends it.',
          ),
        );
      }
    } catch (_) {
      // A failed probe is not proof of revocation.
    } finally {
      _permissionCheckInFlight = false;
    }
  }

  /// Stops this phone's capture after a confirmed permission/capture failure.
  ///
  /// The server session is *not* ended: only the parent may do that, and a
  /// permission problem on one device is not proof that consent was withdrawn
  /// by the account. Re-opening requires a new visible action. Never
  /// re-acquires the microphone automatically.
  Future<void> _terminateForFailure({
    required String code,
    required String message,
    bool permission = false,
  }) async {
    if (_isClosed || _fatalCaptureFailure) return;
    _fatalCaptureFailure = true;
    _serviceConfirmed = false;
    _setCaptureActive(false);
    if (isChildRole) sharingStopped.value = true;
    _stopPermissionWatch();
    _stopStatsSampling();
    if (permission) permissionDenied.value = true;
    try {
      await _teardownMedia();
    } catch (_) {
      // Local release is best effort; the session record is unaffected.
    }
    if (permission) permissionDenied.value = true;
    actionError.value = AppException(code, message);
    _fatalCaptureFailure = false;
  }

  /// Child "Stop sharing": releases this phone's camera and microphone.
  ///
  /// This is consent withdrawal on the device, not session termination. The
  /// parent remains the only authority that ends the server session.
  Future<bool> withdrawConsent() async {
    if (!isChildRole) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the child device can stop sharing. The parent ends the session.',
      );
      return false;
    }
    final current = session.value;
    if (current == null || current.status.isTerminal) return false;
    if (!_captureActive && !hasActivePeer.value) {
      // The stop action is idempotent: the desired state (no local capture)
      // is already true. Do not report an error for a successful withdrawal,
      // but still make sure a lingering foreground service cannot outlive it.
      sharingStopped.value = true;
      actionError.value = null;
      try {
        await _stopAudioAssistanceService();
      } catch (_) {
        // Local cleanup is best effort; the control remains available.
      }
      return true;
    }
    _fatalCaptureFailure = true;
    _serviceConfirmed = false;
    _setCaptureActive(false);
    sharingStopped.value = true;
    _stopPermissionWatch();
    _stopStatsSampling();
    try {
      await _teardownMedia();
    } catch (_) {
      // The service stop below is the important part and is also attempted.
      await _stopAudioAssistanceService();
    }
    _fatalCaptureFailure = false;
    actionError.value = null;
    connectionWarning.value = null;
    iceError.value = null;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Capture heartbeat
  // ---------------------------------------------------------------------------

  /// Confirms to the native foreground service that this isolate still owns a
  /// live microphone track. The service stops its notification after 45 s
  /// without a confirmation, so the microphone indicator can never outlive the
  /// WebRTC capture it describes.
  void _startCaptureHeartbeat() {
    if (!isChildRole || _captureHeartbeatTimer != null) return;
    _sendCaptureHeartbeat();
    _captureHeartbeatTimer = Timer.periodic(
      _captureHeartbeatInterval,
      (_) => _sendCaptureHeartbeat(),
    );
  }

  void _sendCaptureHeartbeat() {
    if (_isClosed || !_captureActive) return;
    unawaited(_deviceAdmin.notifyAudioCaptureHeartbeat(sessionId: sessionId));
  }

  void _stopCaptureHeartbeat() {
    _captureHeartbeatTimer?.cancel();
    _captureHeartbeatTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  void _startStatsSampling() {
    if (_statsTimer != null) return;
    // A baseline sample now makes the next periodic delta meaningful within
    // one interval instead of two.
    unawaited(_sampleMediaStats());
    _statsTimer = Timer.periodic(_statsSampleInterval, (_) {
      unawaited(_sampleMediaStats());
    });
  }

  void _stopStatsSampling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  /// Clears the "audio is flowing" evidence. Called on every connection loss
  /// and on teardown so a stale positive sample can never report live audio.
  void _resetAudioFlow() {
    isMediaFlowing.value = false;
    _connectedAt = null;
    _lastAudioPacketAt = null;
    // Counters belong to the connection that just went away. Keeping them
    // would let a new peer's cumulative totals read as a positive delta.
    mediaStats.value = null;
  }

  Future<void> _sampleMediaStats() async {
    final peer = _peer;
    if (peer == null || _isClosed) return;
    try {
      final reports = await peer.getStats();
      if (_isClosed || !identical(_peer, peer)) return;
      var packetsSent = 0;
      var bytesSent = 0;
      var packetsReceived = 0;
      var bytesReceived = 0;
      for (final report in reports) {
        final kind = report.values['kind']?.toString().toLowerCase();
        // Only RTP media counters count as flow evidence; candidate-pair and
        // transport reports are not proof that audio is moving.
        if (kind != null && kind != 'audio') continue;
        if (report.type == 'outbound-rtp') {
          packetsSent += _statInt(report.values['packetsSent']);
          bytesSent += _statInt(report.values['bytesSent']);
        } else if (report.type == 'inbound-rtp') {
          packetsReceived += _statInt(report.values['packetsReceived']);
          bytesReceived += _statInt(report.values['bytesReceived']);
        }
      }
      final previous = mediaStats.value;
      final sentDelta = previous == null
          ? 0
          : packetsSent - previous.packetsSent;
      final receivedDelta = previous == null
          ? 0
          : packetsReceived - previous.packetsReceived;
      final relevantDelta = isParentRole ? receivedDelta : sentDelta;
      final sampledAt = DateTime.now();
      if (isConnected.value) {
        if (relevantDelta > 0) {
          if (!isMediaFlowing.value) {
            // Real RTP progress resets the automatic-recovery budget.
            _recoveryJoinAttempts = 0;
            _readyRestartAttempts = 0;
          }
          isMediaFlowing.value = true;
          _lastAudioPacketAt = sampledAt;
        } else {
          final lastPacket = _lastAudioPacketAt;
          if (lastPacket != null &&
              sampledAt.difference(lastPacket) > _audioIdleTimeout) {
            // Connected, but audio RTP stopped. Never keep a live label.
            isMediaFlowing.value = false;
          }
        }
      }
      mediaStats.value = MediaStatsSnapshot(
        sampledAt: sampledAt,
        packetsSent: packetsSent,
        bytesSent: bytesSent,
        packetsReceived: packetsReceived,
        bytesReceived: bytesReceived,
        rtpTimestampDelta: relevantDelta > 0 ? relevantDelta : 0,
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
  /// Parent-only: the requesting parent is the single authority that ends a
  /// server session. The child's control is [withdrawConsent], which only stops
  /// capture on its own phone. The end reason is chosen by the server, so no
  /// caller string is sent.
  ///
  /// Returns `true` only when the server confirmed the end (or the session was
  /// already terminal). Local teardown failure never skips the server call;
  /// when the server end fails, [endError] stays populated, the local state is
  /// not presented as ended, and `false` is returned.
  Future<bool> endSession() async {
    if (!isParentRole) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the parent who requested this session can end it. On the child '
        'device, Stop sharing turns off the camera and microphone.',
      );
      return false;
    }
    if (isEnding.value) return false;
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
      await _remoteSessionRepository.end(sessionId: sessionId);
    } catch (caught) {
      final failure = AppException.from(caught);
      endErrorText.value = failure.message;
      actionError.value = failure;
      isEnding.value = false;
      return false;
    }
    _applyLocalEnded('ended_by_parent');
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

  /// Deterministic, idempotent release of everything this controller owns.
  ///
  /// One routine: timers and signaling buffers, the peer connection, the local
  /// audio/video tracks, the native microphone service, the speakerphone and the
  /// remote renderer. The controller's local media state is terminal afterwards
  /// ([hasActivePeer], [isConnected], [isMediaFlowing] and [isCapturing] are all
  /// false) while the server session is untouched.
  ///
  /// Concurrent calls await the same release; a later call finds nothing to
  /// release. Tracks and the peer are detached synchronously before the first
  /// `await`, so each is stopped/disposed exactly once. The native service is
  /// stopped only when this controller had a confirmed start, and at most once.
  Future<void> _teardownMedia() {
    final inFlight = _teardownFuture;
    if (inFlight != null) return inFlight;
    final future = _teardownMediaOnce();
    _teardownFuture = future;
    return future.whenComplete(() {
      if (identical(_teardownFuture, future)) _teardownFuture = null;
    });
  }

  Future<void> _teardownMediaOnce() async {
    _cancelIceRecovery();
    _stopPermissionWatch();
    _stopStatsSampling();
    _stopCaptureHeartbeat();
    _serviceConfirmed = false;
    _setCaptureActive(false);
    _resetAudioFlow();
    final waiter = _serviceStartCompleter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(false);
    _serviceStartCompleter = null;
    _joinToken += 1;
    hasActivePeer.value = false;
    isConnected.value = false;
    isRemoteVideoActive.value = false;
    _pendingOffer = null;
    _pendingOfferGeneration = null;
    _pendingIce.clear();
    _remoteDescriptionSet = false;
    _localOfferPending = false;
    _localOfferSentAt = null;
    // A rebuilt media path is a new attempt: its readiness offer may be sent
    // without waiting out the previous attempt's debounce window.
    _lastRejoinOfferAt = null;
    // Detach first so a second call (or an event callback) cannot see, or
    // release, the same objects twice.
    final peer = _peer;
    _peer = null;
    final local = _localStream;
    _localStream = null;
    final releaseService = _nativeServiceRunning;
    _nativeServiceRunning = false;
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {
        // Connection already gone.
      }
      await _disposePeer(peer);
    }
    // Tracks are the microphone itself: release them before the (possibly
    // slow) platform service call, so a hung binder cannot keep capture alive.
    await _stopTracks(local);
    if (isChildRole && releaseService) {
      await _stopAudioAssistanceService();
    }
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

  /// Stops the native microphone service at most once per confirmed start.
  Future<void> _stopAudioServiceOnce() async {
    if (!_nativeServiceRunning) return;
    _nativeServiceRunning = false;
    await _stopAudioAssistanceService();
  }

  Future<void> _stopAudioAssistanceService() async {
    if (!isChildRole) return;
    // Every stop path goes through here, so the local mirror of the native
    // state is cleared even when the call below is scoped out.
    _nativeServiceRunning = false;
    try {
      // A teardown belonging to a replaced controller must not stop the
      // foreground service of a newer session.
      final activeSession = await _deviceAdmin
          .getActiveAudioSessionId()
          .timeout(const Duration(seconds: 5));
      if (activeSession != null &&
          activeSession.isNotEmpty &&
          activeSession != sessionId) {
        return;
      }
      await _deviceAdmin.stopAudioAssistanceService().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Service already stopped, bridge unavailable, or a slow binder.
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

  /// Drives the informational clock only. Elapsed time never ends a session:
  /// a pending request expires on the server, and a consented session lasts
  /// until the parent ends it.
  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Detaches this controller from UI-driven timers and subscriptions.
  ///
  /// It deliberately does NOT stop the microphone foreground service, dispose
  /// the peer connection or end the server session: ordinary route/controller
  /// disposal must not interrupt an authorized session. Explicit account
  /// teardown (logout/unlink/session replacement) calls
  /// [releaseNativeResources] first.
  @override
  void onClose() {
    _isClosed = true;
    _cancelIceRecovery();
    _stopPermissionWatch();
    _stopStatsSampling();
    _stopCaptureHeartbeat();
    _signalRetryTimer?.cancel();
    _signalRetryTimer = null;
    unawaited(_nativeEventSubscription?.cancel());
    _nativeEventSubscription = null;
    _nativeEventsSubscribed = false;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = null;
    _stopSignalWatch();
    _stopTicker();
    super.onClose();
  }

  /// Explicit local release for logout, unlinking or replacing the session.
  ///
  /// Stops this phone's capture, the microphone foreground service, signaling
  /// and the renderer. It never ends the server session: only the parent may.
  Future<void> releaseNativeResources() async {
    _stopCaptureHeartbeat();
    _stopPermissionWatch();
    _stopStatsSampling();
    _stopTicker();
    _stopSignalWatch();
    unawaited(_nativeEventSubscription?.cancel());
    _nativeEventSubscription = null;
    _nativeEventsSubscribed = false;
    unawaited(_sessionSubscription?.cancel());
    _sessionSubscription = null;
    await _shutdown();
  }

  /// Re-reads the server session and the true native state after the UI
  /// returns, then resumes an authorized connection without a manual join on
  /// the other device.
  ///
  /// It never creates a server session and never re-opens the microphone after
  /// a consent withdrawal or a permission loss. A child whose capture is still
  /// live in this process rebuilds a lost peer; a parent resumes receiving.
  Future<void> reconcileAfterResume() async {
    if (_isClosed) return;
    // A foreground return is a new attempt: signaling that hit its retry
    // budget must not stay blocked for the rest of the process.
    _resetSignalRetry();
    final current = session.value;
    if (current == null) {
      await load(showLoading: false);
      return;
    }
    if (!current.status.isOpen || current.isExpired) return;
    _ensureSignalWatch();
    if (!hasActivePeer.value) {
      await load(showLoading: false);
      if (_isClosed) return;
      final refreshed = session.value;
      if (refreshed == null ||
          !refreshed.status.isOpen ||
          refreshed.isExpired) {
        return;
      }
      if (isJoining.value) return;
      final canRebuild =
          refreshed.status == RemoteSessionStatus.accepted ||
          refreshed.status == RemoteSessionStatus.active;
      if (!canRebuild) return;
      if (isChildRole) {
        // Only a capture that was already live in this process may be
        // rebuilt. A closed UI or a previous process needs the visible join.
        if (_captureActive && _peer == null) {
          await join();
        }
        return;
      }
      // Parent media is receive-only and the child already consented, so
      // re-subscribing needs no local permission and no manual join.
      _recoveryJoinAttempts += 1;
      if (_recoveryJoinAttempts > _maxRecoveryJoins) return;
      await join();
      return;
    }
    if (!isConnected.value) {
      // The app was not alive to run the bounded retries. Give the current
      // peer a fresh budget before falling back to a readiness handshake.
      _iceRestartAttempts = 0;
      _scheduleIceRecovery();
    }
    if (!isChildRole) return;
    bool? running;
    try {
      running = await _deviceAdmin.probeAudioAssistanceServiceRunning();
    } catch (_) {
      running = null;
    }
    if (_isClosed || !_captureActive) return;
    if (running == false) {
      await _terminateForFailure(
        code: 'microphone_service_failed',
        message:
            'The microphone foreground service is no longer running, so '
            'sharing stopped on this phone. The session stays open until your '
            'guardian ends it.',
      );
    }
  }

  Future<void> _shutdown() async {
    await _teardownMedia();
    if (_rendererDisposed) return;
    _rendererDisposed = true;
    try {
      await remoteRenderer.dispose();
    } catch (_) {
      // Renderer already disposed by a previous release.
    }
  }
}
