import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/remote_session.dart';
import 'remote_session_controller.dart';

class RemoteSessionPage extends StatefulWidget {
  const RemoteSessionPage({super.key});

  @override
  State<RemoteSessionPage> createState() => _RemoteSessionPageState();
}

class _RemoteSessionPageState extends State<RemoteSessionPage> {
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
        await _leave(context);
      },
      child: Obx(() {
        final controller = _controller;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Assistance session'),
            actions: [
              IconButton(
                tooltip: 'Refresh status',
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.load(showLoading: false),
                icon: const Icon(Icons.refresh),
              ),
              if (controller.canEnd)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _ending ? null : () => _requestEnd(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: Text(
                      controller.session.value?.status ==
                              RemoteSessionStatus.requested
                          ? 'Cancel'
                          : 'End',
                    ),
                  ),
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
    if (controller.isLoading.value) {
      return const LoadingState(label: 'Loading assistance session…');
    }
    final fatalError = controller.error.value;
    if (fatalError != null) {
      return ErrorState(error: fatalError, onRetry: () => controller.load());
    }
    final session = controller.session.value;
    if (session == null) {
      return const EmptyState(
        icon: Icons.help_outline,
        title: 'Session unavailable',
        message: 'This session could not be found or you cannot read it.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        PageSection(
          child: _StatusCard(session: session, controller: controller),
        ),
        if (_endFailure != null)
          PageSection(child: _endFailureCard(context)),
        ..._banners(controller, session),
        if (controller.isViewOnly)
          const PageSection(
            child: InfoBanner(
              tone: BannerTone.info,
              title: 'Parent viewer',
              message:
                  'This screen joins as the parent. The child joins from the '
                  'child device session screen; no media controls are shown '
                  'here for that role.',
            ),
          )
        else
          ..._parentControls(context, session, controller),
        if (controller.canEnd)
          PageSection(
            child: AppButton(
              label: session.status == RemoteSessionStatus.requested
                  ? 'Cancel request'
                  : 'End session',
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
              onPressed: _ending ? null : () => _leave(context),
            ),
          ),
        const PageSection(
          child: Text(
            'This app does not record audio or video, take screenshots, or '
            'capture the screen. Ending or leaving stops the media tracks '
            'immediately.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Leaving a session that is still open on the server must end it first.
  /// Popping the route only stops local playback, which would leave the other
  /// participant in a call with a dead peer.
  Future<void> _leave(BuildContext context) async {
    if (_ending) return;
    final controller = _controller;
    final session = controller.session.value;
    if (session == null || !session.status.isOpen) {
      _pop(context);
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'End the session and leave?',
      message:
          'Leaving ends this session for both of you. The child device stops '
          'sending audio and camera, and you stop receiving it. Nothing is '
          'recorded.',
      confirmLabel: 'End and leave',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _attemptEnd(context, popOnSuccess: true);
  }

  /// Banners that describe live media are hidden for a session that already
  /// ended or expired: "waiting" or "connecting" advice would be false there.
  List<Widget> _banners(
    RemoteSessionController controller,
    RemoteSession session,
  ) {
    final live = session.status.isOpen && !session.isExpired;
    return [
      if (controller.realtimeError.value != null && !controller.isLoading.value)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Live updates interrupted',
            message:
                '${controller.realtimeError.value!.message} Refresh to check '
                'the current server status.',
            actionLabel: 'Refresh',
            onAction: () => controller.load(showLoading: false),
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
                'sent. Grant the permission in Android settings, then join '
                'again.',
          ),
        ),
      if (controller.actionError.value != null && _endFailure == null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Session action failed',
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

  /// Shown when the server did not confirm the end. The parent stays on this
  /// screen with a retry, and nothing here claims that the child stopped.
  Widget _endFailureCard(BuildContext context) {
    return SectionCard(
      title: 'The session may still be live',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_endFailure!, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 6),
          const Text(
            'The server has not confirmed that this session ended. The child '
            'device may still be sending audio, and it may still appear live to '
            'the other participant.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: _ending
                ? null
                : () => _attemptEnd(context, popOnSuccess: false),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Leave without ending',
            outlined: true,
            destructive: true,
            onPressed: _ending ? null : () => _confirmLeaveAnyway(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _parentControls(
    BuildContext context,
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    if (session.isExpired && session.status.isOpen) {
      return [
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Session expired',
            message:
                'This session is past its short-lived expiry. No camera or '
                'microphone was opened. Request a new session when needed.',
          ),
        ),
      ];
    }
    if (session.status == RemoteSessionStatus.requested) {
      return const [
        PageSection(
          child: InfoBanner(
            tone: BannerTone.info,
            title: 'Waiting for consent',
            message:
                'The child must accept this request. Camera and microphone are '
                'off. This request expires shortly; you can cancel it below.',
          ),
        ),
      ];
    }
    if (session.status.isTerminal) {
      return [
        PageSection(
          child: InfoBanner(
            tone: session.status == RemoteSessionStatus.failed
                ? BannerTone.danger
                : BannerTone.warning,
            title: _terminalTitle(session),
            message: _terminalMessage(session),
          ),
        ),
      ];
    }
    if (controller.hasActivePeer.value) {
      return [
        PageSection(child: _mediaStage(context, session, controller)),
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                    label: controller.isConnected.value
                        ? 'Media connected'
                        : 'Connecting media…',
                    tone: controller.isConnected.value
                        ? StatusTone.success
                        : StatusTone.warning,
                  ),
                  StatusChip(
                    label: _mediaChipLabel(session, controller),
                    tone: controller.isMediaLive
                        ? StatusTone.success
                        : StatusTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.kind == SessionKind.video
                    ? 'Ending stops video streaming.'
                    : 'Ending stops audio listening.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      PageSection(
        child: SectionCard(
          title: 'Join with explicit consent',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.kind == SessionKind.video
                    ? 'The child accepted. Tapping the button below connects to '
                          'the child device for a short-lived live video session. '
                          'Your microphone will not be used.'
                    : 'The child accepted. Tapping the button below connects to '
                          'the child device for a short-lived one-way audio session. '
                          'Your microphone will not be used.',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: session.kind == SessionKind.video
                    ? 'Start video session'
                    : 'Listen to audio',
                icon: session.kind == SessionKind.video
                    ? Icons.videocam
                    : Icons.volume_up,
                isLoading: controller.isJoining.value,
                onPressed: controller.canJoin
                    ? () => _join(context, session)
                    : null,
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
        ),
      ),
    ];
  }

  /// The headline only claims live audio when the controller confirms it.
  Widget _mediaStage(
    BuildContext context,
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    if (session.kind == SessionKind.audio) {
      final live = controller.isMediaLive;
      return SectionCard(
        child: Column(
          children: [
            Icon(
              live ? Icons.volume_up : Icons.volume_off_outlined,
              size: 56,
              color: live ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              live
                  ? 'One-way audio live'
                  : _audioStateTitle(session, controller),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              live
                  ? 'Listening to the child device (loudspeaker enabled).'
                  : _audioStateDetail(session, controller),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    return SectionCard(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: controller.isRemoteVideoActive.value
              ? RTCVideoView(
                  controller.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    controller.isMediaLive
                        ? 'Waiting for the child’s video…'
                        : 'The child device is not sending video.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      ),
    );
  }

  static String _audioStateTitle(
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    if (!session.status.isOpen) return 'Session ended';
    if (controller.isJoining.value || !controller.isConnected.value) {
      return 'Connecting to the child device…';
    }
    return 'Audio unavailable';
  }

  static String _audioStateDetail(
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    if (!session.status.isOpen) {
      return 'This session is over. No audio is being received or recorded.';
    }
    if (controller.isJoining.value || !controller.isConnected.value) {
      return 'Waiting for the media connection to the child device.';
    }
    return 'The connection is up, but this phone is not receiving audio from '
        'the child device.';
  }

  static String _mediaChipLabel(
    RemoteSession session,
    RemoteSessionController controller,
  ) {
    final subject =
        session.kind == SessionKind.video ? 'Video' : 'Audio';
    if (controller.isMediaLive) return '$subject live';
    if (controller.isJoining.value) return '$subject connecting…';
    return '$subject not live';
  }

  Future<void> _join(BuildContext context, RemoteSession session) async {
    final controller = _controller;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Start the live session?',
      message: session.kind == SessionKind.video
          ? 'You will view the child device. Your microphone will not be used. '
                'The child has already accepted. Nothing is recorded.'
          : 'You will listen to the child device through the loudspeaker. Your '
                'microphone will not be used. The child has already accepted. '
                'Nothing is recorded.',
      confirmLabel: 'Join now',
    );
    if (!confirmed || !mounted) return;
    await controller.join();
  }

  Future<void> _requestEnd(BuildContext context) async {
    final controller = _controller;
    final current = controller.session.value;
    final isRequest = current?.status == RemoteSessionStatus.requested;
    final confirmed = await ConfirmDialog.show(
      context,
      title: isRequest
          ? 'Cancel assistance request?'
          : 'End assistance session?',
      message: isRequest
          ? 'The child will no longer see this request.'
          : 'This stops audio playback and ends the session for both '
                'participants.',
      confirmLabel: isRequest ? 'Cancel request' : 'End session',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _attemptEnd(context, popOnSuccess: false);
  }

  /// Ends the session and only reports success when the server confirms it.
  /// On failure the page stays, shows the real error, and offers Retry plus an
  /// explicit, warned way out.
  Future<void> _attemptEnd(
    BuildContext context, {
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
      ended = await controller.endSession(
        reason: controller.isParentRole ? 'ended_by_parent' : 'ended_by_child',
      );
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

  /// A second, explicit confirmation is the only way to leave while the server
  /// still holds the session open. The user is warned, not told it succeeded.
  Future<void> _confirmLeaveAnyway(BuildContext context) async {
    if (_ending) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Leave without ending the session?',
      message:
          'The server has not confirmed this session ended, so the child '
          'device may still be sending audio. Leaving only stops playback on '
          'this phone. End the session from the assistance list once you can.',
      confirmLabel: 'Leave anyway',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    _pop(context);
  }

  void _pop(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  static String _terminalTitle(RemoteSession session) {
    if (session.isExpired && session.status.isOpen) return 'Session expired';
    switch (session.status) {
      case RemoteSessionStatus.declined:
        return 'Request declined';
      case RemoteSessionStatus.expired:
        return 'Session expired';
      case RemoteSessionStatus.ended:
        return 'Session ended';
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
      return 'This session is past its expiry time. No camera or microphone '
          'was opened. Request a new session when needed.';
    }
    switch (session.status) {
      case RemoteSessionStatus.declined:
        return 'The child declined. No media was opened.';
      case RemoteSessionStatus.expired:
        return 'The consent request or session expired. No media was opened.';
      case RemoteSessionStatus.ended:
        final reason = session.endedReason;
        return 'This session is over.${reason == null ? '' : ' Reason: $reason'}';
      case RemoteSessionStatus.failed:
        return 'The server reported that this session failed. Check the child '
            'device and try a new request.';
      case RemoteSessionStatus.requested:
      case RemoteSessionStatus.accepted:
      case RemoteSessionStatus.active:
        return session.status.label;
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.session, required this.controller});

  final RemoteSession session;
  final RemoteSessionController controller;

  @override
  Widget build(BuildContext context) {
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
            label: 'Device',
            value: session.deviceName ?? 'Unknown device',
          ),
          if (session.childDisplayName != null)
            KeyValueRow(label: 'Child', value: session.childDisplayName!),
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
            label: 'Child consent',
            value: session.consentRecorded ? 'Recorded' : 'Not recorded',
            valueColor: session.consentRecorded
                ? AppColors.success
                : AppColors.warning,
          ),
          if (session.acceptedAt != null)
            KeyValueRow(
              label: 'Accepted',
              value: formatDateTime(session.acceptedAt),
            ),
          if (session.endedAt != null)
            KeyValueRow(label: 'Ended', value: formatDateTime(session.endedAt)),
          if (session.isExpired)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: InfoBanner(
                tone: BannerTone.warning,
                title: 'Expired',
                message:
                    'This session is past its short-lived expiry. Media cannot '
                    'be opened.',
              ),
            ),
        ],
      ),
    );
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
}

/// Blocking state while the server end call is in flight.
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
                  'Stopping playback on this phone and ending the session for '
                  'both of you.',
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
