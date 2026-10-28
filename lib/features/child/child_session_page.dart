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
/// Leaving this screen is a session-ending action, not just a route pop: the
/// other participant is told the truth instead of being left looking at a
/// "live" session with a dead peer.
class ChildSessionPage extends StatefulWidget {
  const ChildSessionPage({super.key});

  @override
  State<ChildSessionPage> createState() => _ChildSessionPageState();
}

class _ChildSessionPageState extends State<ChildSessionPage> {
  /// A server-confirmed end is in flight. Blocks double taps and route pops.
  bool _ending = false;

  /// Truthful message from the last failed end attempt (server not confirmed).
  String? _endFailure;

  RemoteSessionController get _controller =>
      Get.find<RemoteSessionController>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack(context);
      },
      child: Obx(() {
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
          body: Stack(
            children: [
              _body(context, controller),
              if (_ending) const Positioned.fill(child: _EndingOverlay()),
            ],
          ),
        );
      }),
    );
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
        if (_endFailure != null)
          PageSection(child: _endFailureCard(context)),
        ..._banners(controller, session),
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
          PageSection(child: _mediaCard(session, controller))
        else
          PageSection(child: _joinCard(context, session, controller)),
        if (controller.canEnd)
          PageSection(
            child: AppButton(
              label: _ending ? 'Ending session…' : 'End session',
              icon: Icons.call_end,
              destructive: true,
              isLoading: _ending,
              onPressed: _ending ? null : () => _requestEnd(context),
            ),
          )
        else
          PageSection(
            child: AppButton(
              label: 'Close',
              outlined: true,
              onPressed: _ending ? null : () => _handleBack(context),
            ),
          ),
        const PageSection(
          child: Text(
            'Nothing is recorded. Camera and microphone are used only during '
            'this session and stop when you end it or leave this screen. The '
            'app never takes screenshots or reads messages.',
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
      if (controller.actionError.value != null && _endFailure == null)
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

  /// Shown when the server did not confirm the end. The child must be able to
  /// retry or stay; the page never claims the guardian's view changed.
  Widget _endFailureCard(BuildContext context) {
    return SectionCard(
      title: 'The session is still open',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_endFailure!, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 6),
          const Text(
            'The server has not confirmed that this session ended, so your '
            'guardian may still see it as live. Nothing is recorded.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: _ending
                ? null
                : () => _attemptEnd(
                      context,
                      reason: 'left_screen',
                      popOnSuccess: false,
                    ),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Stay in session',
            outlined: true,
            onPressed: _ending ? null : () => setState(() => _endFailure = null),
          ),
        ],
      ),
    );
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
          KeyValueRow(
            label: 'Expires',
            value: controller.expiresInLabel,
            valueColor: session.isExpired ? AppColors.danger : null,
          ),
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
            'Accepting records your consent for this short-lived request. The '
            'camera and microphone stay off until you tap Join on the next '
            'step. You can decline or end the session at any time.',
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
    return SectionCard(
      title: 'Ready when you are',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.kind == SessionKind.video
                ? 'You accepted this request. Tapping Join turns on your camera '
                    'and microphone and starts the live session.'
                : 'You accepted this request. Tapping Join turns on your '
                    'microphone and starts the live audio session.',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: session.kind == SessionKind.video
                ? 'Join with camera and microphone'
                : 'Join with microphone',
            icon: session.kind == SessionKind.video
                ? Icons.videocam
                : Icons.mic,
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

  /// The media card only claims the microphone is on when the controller can
  /// confirm both live tracks and the visible microphone service.
  Widget _mediaCard(RemoteSession session, RemoteSessionController controller) {
    final video = session.kind == SessionKind.video;
    final mediaLive = controller.isMediaLive;
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
                    color: mediaLive ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _mediaHeadline(
                        video: video,
                        mediaLive: mediaLive,
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
                  connecting: connecting,
                ),
                tone: mediaLive
                    ? StatusTone.success
                    : (connecting ? StatusTone.warning : StatusTone.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ending stops camera and microphone.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          if (waiting) ...[
            const SizedBox(height: 10),
            const Text(
              'Waiting for the media connection to the parent to complete. You '
              'can end this session at any time.',
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
    required bool connecting,
    required bool connected,
  }) {
    if (mediaLive) {
      if (connected) {
        return video ? 'Camera and microphone are on' : 'Microphone is on';
      }
      return video
          ? 'Camera and microphone on — waiting for your guardian'
          : 'Microphone on — waiting for your guardian';
    }
    if (connecting) {
      return video
          ? 'Starting the camera and microphone…'
          : 'Starting the microphone…';
    }
    if (connected) {
      return video
          ? 'Connected, but camera and microphone are not sharing'
          : 'Connected, but not sharing audio';
    }
    return video
        ? 'Camera and microphone are not sharing'
        : 'Microphone is stopped — not sharing audio';
  }

  static String _mediaChipLabel({
    required bool video,
    required bool mediaLive,
    required bool connecting,
  }) {
    final subject = video ? 'Camera and microphone' : 'Microphone';
    if (mediaLive) return '$subject live';
    if (connecting) return '$subject starting…';
    return '$subject off';
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

  /// Back, AppBar up and the Close button all land here. A session that is
  /// still open on the server is ended first; the route is only popped after
  /// the server confirms it, so the parent is never left looking at a live
  /// session that no longer has a peer.
  Future<void> _handleBack(BuildContext context) async {
    if (_ending) return;
    final session = _controller.session.value;
    if (session == null || !session.status.isOpen) {
      _pop(context);
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Leave and end the session?',
      message:
          'Leaving this screen stops your microphone and camera immediately '
          'and ends the session for your guardian. Nothing is recorded.',
      confirmLabel: 'End and leave',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _attemptEnd(context, reason: 'left_screen', popOnSuccess: true);
  }

  Future<void> _requestEnd(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'End this session?',
      message:
          'This stops your camera and microphone immediately and ends the '
          'session for both participants.',
      confirmLabel: 'End session',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _attemptEnd(context, reason: 'ended_by_child', popOnSuccess: false);
  }

  Future<void> _attemptEnd(
    BuildContext context, {
    required String reason,
    required bool popOnSuccess,
  }) async {
    if (_ending) return;
    final controller = _controller;
    setState(() {
      _ending = true;
      _endFailure = null;
    });
    bool ended = false;
    try {
      ended = await controller.endSession(reason: reason);
    } catch (_) {
      ended = false;
    }
    if (!mounted) return;
    if (ended) {
      setState(() => _ending = false);
      if (popOnSuccess && context.mounted) _pop(context);
      return;
    }
    setState(() {
      _ending = false;
      _endFailure = controller.endError ??
          'The server did not confirm that this session ended.';
    });
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

/// Blocking state while the server end call is in flight. It keeps the user on
/// the page and prevents a second tap or a route pop from racing the request.
class _EndingOverlay extends StatelessWidget {
  const _EndingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: 0.97),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Ending session…',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Stopping the microphone and camera, and ending the session '
                  'for both of you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
