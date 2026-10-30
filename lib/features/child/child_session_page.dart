import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

/// The child side of a consented assistance session.
///
/// Leaving this screen only pops the route. Once the child has accepted and
/// joined, the session and the visible microphone foreground service keep
/// running until the parent ends the session, the child taps Stop sharing,
/// permission is lost, or the phone is unlinked/signed out. Stop sharing only
/// releases this phone's capture; it does not end the server session. Back is
/// never an implicit stop.
class ChildSessionPage extends StatefulWidget {
  const ChildSessionPage({super.key});

  @override
  State<ChildSessionPage> createState() => _ChildSessionPageState();
}

class _ChildSessionPageState extends State<ChildSessionPage> {
  /// Local capture shutdown is in flight (no server call is made).
  bool _stopping = false;

  RemoteSessionController get _controller =>
      Get.find<RemoteSessionController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = _controller;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Assistance'),
          actions: [
            IconButton(
              tooltip: 'Refresh status',
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.load(showLoading: false),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _body(context, controller),
      );
    });
  }

  Widget _body(BuildContext context, RemoteSessionController controller) {
    if (!controller.isChildRole) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Not available for this account',
        message:
            'This screen is only for the child device. Open the assistance '
            'request from the child account.',
      );
    }
    if (controller.isLoading.value) {
      return const LoadingState(label: 'Loading assistance request…');
    }
    final fatal = controller.error.value;
    if (fatal != null) {
      return ErrorState(error: fatal, onRetry: () => controller.load());
    }
    final session = controller.session.value;
    if (session == null) {
      return const EmptyState(
        icon: Icons.help_outline,
        title: 'Session unavailable',
        message: 'This session could not be found or does not belong to you.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        PageSection(child: _statusCard(session, controller)),
        ..._banners(controller, session),
        if (controller.sharingStopped.value && session.status.isOpen)
          const PageSection(
            child: InfoBanner(
              tone: BannerTone.warning,
              title: 'Sharing stopped on this phone',
              message:
                  'Camera and microphone are off. The session itself stays '
                  'open until your guardian ends it; the app will not reopen '
                  'the microphone by itself.',
            ),
          ),
        if (session.isExpired && session.status.isOpen)
          const PageSection(
            child: InfoBanner(
              tone: BannerTone.warning,
              title: 'Request expired',
              message:
                  'This request is past its short expiry. Camera and microphone '
                  'were not opened. Ask your guardian to send a new request if '
                  'you still want to talk.',
            ),
          )
        else if (session.status == RemoteSessionStatus.requested)
          PageSection(child: _consentCard(context, controller))
        else if (session.status.isTerminal)
          PageSection(child: _terminalCard(session))
        else if (controller.hasActivePeer.value)
          PageSection(child: _mediaCard(context, session, controller))
        else
          PageSection(child: _joinCard(context, session, controller)),
        if (session.status.isOpen && !session.isExpired)
          PageSection(child: _leaveNote(session, controller)),
        if (controller.canStopSharing)
          PageSection(
            child: AppButton(
              label: _stopping ? 'Stopping…' : 'Stop sharing',
              icon: Icons.mic_off,
              destructive: true,
              isLoading: _stopping,
              onPressed: _stopping ? null : () => _requestStop(context),
            ),
          ),
        if (session.isParentControlled)
          const PageSection(
            child: Text(
              'Only your guardian can end this session. Stop sharing turns off '
              'this phone\'s camera and microphone and leaves the session open.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45),
            ),
          ),
        PageSection(
          child: AppButton(
            label: 'Close',
            outlined: true,
            onPressed: () => _pop(context),
          ),
        ),
        const PageSection(
          child: Text(
            'Nothing is recorded. Camera and microphone are used only while you '
            'are sharing and stop when you tap Stop sharing, when the session '
            'ends, or when this phone loses camera or microphone permission. '
            'The app never takes screenshots or reads messages.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }

  /// Banners that describe live media are suppressed once the session is over
  /// or expired: a stopped session must not keep showing "connecting" advice.
  List<Widget> _banners(
    RemoteSessionController controller,
    RemoteSession session,
  ) {
    final live = session.status.isOpen && !session.isExpired;
    return [
      if (controller.realtimeError.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Live updates interrupted',
            message:
                '${controller.realtimeError.value!.message} Refresh to check '
                'the current status.',
          ),
        ),
      if (live && controller.turnWarning != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Relay not configured',
            message: controller.turnWarning!,
          ),
        ),
      if (live && controller.iceError.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Connection setup failed',
            message: controller.iceError.value!.message,
          ),
        ),
      if (live && controller.permissionDenied.value)
        const PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Permission denied',
            message:
                'Camera or microphone permission was denied. No media is being '
                'sent. Allow the permission in This phone settings, then try '
                'again.',
          ),
        ),
      if (controller.actionError.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Action failed',
            message: controller.actionError.value!.message,
          ),
        ),
      if (live && controller.connectionWarning.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Media connection',
            message: controller.connectionWarning.value!,
          ),
        ),
    ];
  }

  Widget _statusCard(RemoteSession session, RemoteSessionController controller) {
    return SectionCard(
      title: session.kind.label,
      trailing: StatusChip(
        label: controller.statusLabel,
        tone: _tone(session),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'From',
            value: session.parentDisplayName ?? 'Your guardian',
          ),
          KeyValueRow(
            label: 'Requested',
            value:
                '${formatDateTime(session.requestedAt)} · ${relativeTime(session.requestedAt)}',
          ),
          if (session.status == RemoteSessionStatus.requested)
            KeyValueRow(
              label: 'Expires',
              value: controller.sessionDurationLabel,
              valueColor: session.isExpired ? AppColors.danger : null,
            ),
          if (session.isParentControlled) ...[
            KeyValueRow(
              label: 'Session duration',
              value: controller.sessionDurationLabel,
            ),
            KeyValueRow(label: 'Elapsed', value: controller.elapsedLabel),
          ],
          KeyValueRow(
            label: 'Consent',
            value: session.consentRecorded ? 'Recorded' : 'Not given',
            valueColor:
                session.consentRecorded ? AppColors.success : AppColors.warning,
          ),
          if (session.acceptedAt != null)
            KeyValueRow(
              label: 'Accepted',
              value: formatDateTime(session.acceptedAt),
            ),
        ],
      ),
    );
  }

  Widget _consentCard(
    BuildContext context,
    RemoteSessionController controller,
  ) {
    return SectionCard(
      title: 'Your guardian is asking to talk',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accepting records your consent for this request. The camera and '
            'microphone stay off until you tap Join on the next step. You can '
            'decline now, or stop sharing at any time after joining.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Decline',
                  outlined: true,
                  destructive: true,
                  onPressed: controller.isResponding.value
                      ? null
                      : () => controller.respond(accept: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Accept',
                  isLoading: controller.isResponding.value,
                  onPressed: controller.isResponding.value
                      ? null
                      : () => _confirmAccept(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _joinCard(
    BuildContext context,
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    final video = session.kind == SessionKind.video;
    // A server-active session with no peer on this phone means the media got
    // disconnected, not that the session is over: the child can reconnect.
    final reconnect = session.status == RemoteSessionStatus.active;
    final String body;
    if (reconnect) {
      body = video
          ? 'This session is still live, but this phone is not connected to it. '
              'Tapping Reconnect turns your camera and microphone back on for '
              'the same session.'
          : 'This session is still live, but this phone is not connected to it. '
              'Tapping Reconnect turns your microphone back on for the same '
              'session.';
    } else {
      body = video
          ? 'You accepted this request. Tapping Join turns on your camera and '
              'microphone and starts the live session.'
          : 'You accepted this request. Tapping Join turns on your microphone '
              'and starts the live audio session.';
    }
    final String label;
    if (reconnect) {
      label =
          video ? 'Reconnect camera and microphone' : 'Reconnect microphone';
    } else {
      label = video ? 'Join with camera and microphone' : 'Join with microphone';
    }
    return SectionCard(
      title: reconnect ? 'Session is still live' : 'Ready when you are',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 14),
          AppButton(
            label: label,
            icon: reconnect
                ? Icons.refresh
                : (video ? Icons.videocam : Icons.mic),
            isLoading: controller.isJoining.value,
            onPressed:
                controller.canJoin ? () => _join(context, session) : null,
          ),
          if (!controller.canJoin && !controller.isJoining.value)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Joining is unavailable for this session state.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// Explains what leaving this screen does while the session is still open.
  ///
  /// This note claims the microphone keeps running only when the controller
  /// confirms local capture and the visible microphone service. It makes no
  /// claim about the parent receiving audio; that is the media card's job.
  Widget _leaveNote(
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    final video = session.kind == SessionKind.video;
    final captureRunning = controller.isCaptureActive;
    if (!captureRunning) {
      return InfoBanner(
        tone: BannerTone.info,
        title: 'You can leave this screen',
        message:
            'Leaving does not end this session. It ends only when your guardian '
            'ends it. Stop sharing turns off this phone\'s '
            '${video ? 'camera and microphone' : 'microphone'} without ending '
            'the session.',
      );
    }
    return InfoBanner(
      tone: BannerTone.info,
      title: 'You can leave this screen',
      message: video
          ? 'Your camera and microphone keep running while you use other '
              'screens. Tap Stop sharing to turn them off, or leave it to your '
              'guardian to end the session.'
          : 'Your microphone keeps running while you use other screens. Tap '
              'Stop sharing to turn it off, or leave it to your guardian to end '
              'the session.',
    );
  }

  /// The media card separates two facts. "Microphone is on" comes from local
  /// capture state; "audio is live" comes only from actual RTP, so an open
  /// microphone with a not-yet-established connection is never reported as
  /// off and an established connection is never reported as audio live.
  Widget _mediaCard(
    BuildContext context,
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    final video = session.kind == SessionKind.video;
    final mediaLive = controller.isMediaFlowing.value;
    final captureOn = controller.isCaptureActive;
    final checking = controller.isCheckingAudio;
    final unavailable = controller.audioUnavailable;
    final connecting = controller.isJoining.value;
    final waiting = !controller.isConnected.value;
    return SectionCard(
      child: Column(
        children: [
          if (video && controller.isRemoteVideoActive.value)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  controller.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    video ? Icons.videocam : Icons.graphic_eq,
                    size: 52,
                    color: mediaLive
                        ? AppColors.primary
                        : (captureOn ? AppColors.warning : AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _mediaHeadline(
                        video: video,
                        mediaLive: mediaLive,
                        captureOn: captureOn,
                        checking: checking,
                        unavailable: unavailable,
                        connecting: connecting,
                        connected: !waiting,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: waiting ? 'Connecting media…' : 'Media connected',
                tone: waiting ? StatusTone.warning : StatusTone.success,
              ),
              StatusChip(
                label: _mediaChipLabel(
                  video: video,
                  mediaLive: mediaLive,
                  captureOn: captureOn,
                  checking: checking,
                  unavailable: unavailable,
                  connecting: connecting,
                ),
                tone: mediaLive
                    ? StatusTone.success
                    : (captureOn || connecting
                        ? StatusTone.warning
                        : StatusTone.danger),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _rtpDebugLabel(controller),
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Stop sharing turns off camera and microphone on this phone.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          if (!captureOn && controller.canJoin) ...[
            const SizedBox(height: 12),
            AppButton(
              label: video
                  ? 'Join with camera and microphone'
                  : 'Join with microphone',
              icon: video ? Icons.videocam : Icons.mic,
              isLoading: controller.isJoining.value,
              onPressed: () => _join(context, session),
            ),
          ],
          if (captureOn && waiting) ...[
            const SizedBox(height: 10),
            const Text(
              'The microphone is on. Waiting for the media connection to the '
              'parent to complete. You can stop sharing at any time; the '
              'session stays open until your guardian ends it.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  static String _mediaHeadline({
    required bool video,
    required bool mediaLive,
    required bool captureOn,
    required bool checking,
    required bool unavailable,
    required bool connecting,
    required bool connected,
  }) {
    if (captureOn) {
      if (mediaLive) {
        return video ? 'Camera and microphone are live' : 'Microphone is live';
      }
      if (connecting) {
        return video
            ? 'Camera and microphone are on — starting the connection…'
            : 'Microphone is on — starting the connection…';
      }
      if (connected && unavailable) {
        return video
            ? 'Camera and microphone are on, but audio is not reaching your '
                'guardian'
            : 'Microphone is on, but audio is not reaching your guardian';
      }
      if (connected) {
        return video
            ? 'Camera and microphone are on — checking audio…'
            : 'Microphone is on — checking audio…';
      }
      return video
          ? 'Camera and microphone are on — reconnecting…'
          : 'Microphone is on — reconnecting…';
    }
    if (connecting) {
      return video
          ? 'Starting the camera and microphone…'
          : 'Starting the microphone…';
    }
    if (connected) {
      return video
          ? 'Connected, but the camera and microphone are off on this phone'
          : 'Connected, but the microphone is off on this phone';
    }
    return video
        ? 'Camera and microphone are off on this phone'
        : 'Microphone is off on this phone';
  }

  static String _mediaChipLabel({
    required bool video,
    required bool mediaLive,
    required bool captureOn,
    required bool checking,
    required bool unavailable,
    required bool connecting,
  }) {
    final subject = video ? 'Camera and microphone' : 'Microphone';
    if (mediaLive) return '$subject live';
    if (connecting) return '$subject starting…';
    if (!captureOn) return '$subject off';
    if (checking) return '$subject on · checking…';
    if (unavailable) return '$subject on · not flowing';
    return '$subject on · connecting…';
  }

  /// Debug-only numeric proof that RTP counters advance. Never shown in a
  /// release build and never contains media content.
  static String _rtpDebugLabel(RemoteSessionController controller) {
    final stats = controller.mediaStats.value;
    if (stats == null) return 'DEBUG RTP: no sample yet';
    return 'DEBUG RTP: out ${stats.packetsSent} pkts / '
        '${stats.bytesSent} B · in ${stats.packetsReceived} pkts / '
        '${stats.bytesReceived} B';
  }

  Widget _terminalCard(RemoteSession session) {
    final message = _terminalMessage(session);
    return InfoBanner(
      tone: session.status == RemoteSessionStatus.failed
          ? BannerTone.danger
          : BannerTone.warning,
      title: _terminalTitle(session),
      message: message,
    );
  }

  Future<void> _confirmAccept(BuildContext context) async {
    final controller = _controller;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Accept this assistance request?',
      message:
          'Accepting records your consent. The camera and microphone stay off '
          'until you tap Join on the next step. Nothing is recorded.',
      confirmLabel: 'Accept',
    );
    if (!confirmed) return;
    await controller.respond(accept: true);
  }

  Future<void> _join(BuildContext context, RemoteSession session) async {
    final controller = _controller;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Start the live session?',
      message: session.kind == SessionKind.video
          ? 'Your camera and microphone will be used until you end the session. '
              'The parent requested this session and you already accepted. '
              'Nothing is recorded.'
          : 'Your microphone will be used until you end the session. The parent '
              'requested this session and you already accepted. Nothing is '
              'recorded.',
      confirmLabel: 'Join now',
    );
    if (!confirmed) return;
    await controller.join();
  }

  /// Child consent withdrawal. This only releases this phone's camera and
  /// microphone; the server session stays open and only the parent ends it.
  /// Back and the AppBar up button only pop the route.
  Future<void> _requestStop(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Stop sharing?',
      message:
          'This turns off your camera and microphone on this phone immediately. '
          'The session stays open until your guardian ends it.',
      confirmLabel: 'Stop sharing',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    setState(() => _stopping = true);
    try {
      await _controller.withdrawConsent();
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  void _pop(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  static StatusTone _tone(RemoteSession session) {
    if (session.status.isOpen && session.isExpired) return StatusTone.warning;
    switch (session.status) {
      case RemoteSessionStatus.requested:
        return StatusTone.info;
      case RemoteSessionStatus.accepted:
        return StatusTone.info;
      case RemoteSessionStatus.active:
        return StatusTone.success;
      case RemoteSessionStatus.declined:
      case RemoteSessionStatus.expired:
        return StatusTone.warning;
      case RemoteSessionStatus.ended:
        return StatusTone.neutral;
      case RemoteSessionStatus.failed:
        return StatusTone.danger;
    }
  }

  static String _terminalTitle(RemoteSession session) {
    if (session.isExpired && session.status.isOpen) return 'Request expired';
    switch (session.status) {
      case RemoteSessionStatus.declined:
        return 'Request declined';
      case RemoteSessionStatus.ended:
        return 'Session ended';
      case RemoteSessionStatus.expired:
        return 'Session expired';
      case RemoteSessionStatus.failed:
        return 'Session failed';
      case RemoteSessionStatus.requested:
      case RemoteSessionStatus.accepted:
      case RemoteSessionStatus.active:
        return session.status.label;
    }
  }

  static String _terminalMessage(RemoteSession session) {
    if (session.isExpired && session.status.isOpen) {
      return 'The request expired before media started. No camera or microphone '
          'was opened.';
    }
    switch (session.status) {
      case RemoteSessionStatus.declined:
        return 'You declined this request. No media was opened.';
      case RemoteSessionStatus.ended:
        final reason = session.endedReason;
        return 'This session is over.${reason == null ? '' : ' Reason: $reason'}';
      case RemoteSessionStatus.expired:
        return 'The request expired. No media was opened.';
      case RemoteSessionStatus.failed:
        return 'The server reported that this session failed. No media is '
            'being sent.';
      case RemoteSessionStatus.requested:
      case RemoteSessionStatus.accepted:
      case RemoteSessionStatus.active:
        return session.status.label;
    }
  }
}
