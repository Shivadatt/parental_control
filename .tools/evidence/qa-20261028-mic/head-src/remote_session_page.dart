import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/remote_session.dart';
import 'remote_session_controller.dart';

class RemoteSessionPage extends GetView<RemoteSessionController> {
  const RemoteSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance session'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh status',
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.load(showLoading: false),
              icon: const Icon(Icons.refresh),
            ),
          ),
          Obx(() {
            if (!controller.canEnd) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: controller.isEnding.value
                    ? null
                    : () => _requestEnd(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(
                  controller.session.value?.status == RemoteSessionStatus.requested
                      ? 'Cancel'
                      : 'End',
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingState(label: 'Loading assistance session…');
        }
        final fatalError = controller.error.value;
        if (fatalError != null) {
          return ErrorState(
            error: fatalError,
            onRetry: () => controller.load(),
          );
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
            PageSection(child: _StatusCard(session: session, controller: controller)),
            ..._banners(),
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
              ..._parentControls(context, session),
            if (controller.canEnd)
              PageSection(
                child: AppButton(
                  label: session.status == RemoteSessionStatus.requested
                      ? 'Cancel request'
                      : 'End session',
                  icon: Icons.call_end,
                  destructive: true,
                  isLoading: controller.isEnding.value,
                  onPressed: () => _requestEnd(context),
                ),
              )
            else
              PageSection(
                child: AppButton(
                  label: 'Close',
                  outlined: true,
                  onPressed: () => Get.back<void>(),
                ),
              ),
            const PageSection(
              child: Text(
                'This app does not record audio or video, take screenshots, '
                'or capture the screen. Ending or leaving stops the media '
                'tracks immediately.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _banners() {
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
      if (controller.turnWarning != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Relay not configured',
            message: controller.turnWarning!,
          ),
        ),
      if (controller.iceError.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Connection setup failed',
            message: controller.iceError.value!.message,
          ),
        ),
      if (controller.permissionDenied.value)
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
      if (controller.actionError.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.danger,
            title: 'Session action failed',
            message: controller.actionError.value!.message,
          ),
        ),
      if (controller.connectionWarning.value != null)
        PageSection(
          child: InfoBanner(
            tone: BannerTone.warning,
            title: 'Media connection',
            message: controller.connectionWarning.value!,
          ),
        ),
    ];
  }

  List<Widget> _parentControls(BuildContext context, RemoteSession session) {
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
        PageSection(child: _mediaStage(context, session)),
        PageSection(
          child: Row(
            children: [
              StatusChip(
                label: controller.isConnected.value ? 'Connected' : 'Connecting…',
                tone: controller.isConnected.value
                    ? StatusTone.success
                    : StatusTone.warning,
              ),
              const Spacer(),
              const Text(
                'Ending stops camera and microphone.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                    ? 'The child accepted. Tapping the button below opens your '
                        'camera and microphone and starts a short-lived live '
                        'session.'
                    : 'The child accepted. Tapping the button below opens your '
                        'microphone and starts a short-lived live audio session.',
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
                onPressed: controller.canJoin ? () => _join(context, session) : null,
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

  Widget _mediaStage(BuildContext context, RemoteSession session) {
    if (session.kind == SessionKind.audio) {
      return SectionCard(
        child: Column(
          children: [
            const Icon(Icons.graphic_eq, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'Audio session live',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              controller.isConnected.value
                  ? 'Connected to the child device.'
                  : 'Connecting to the child device…',
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
                  child: const Text(
                    'Waiting for the child’s video…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, RemoteSession session) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Start the live session?',
      message: session.kind == SessionKind.video
          ? 'Your camera and microphone will be used until you end the session. '
              'The child has already accepted. Nothing is recorded.'
          : 'Your microphone will be used until you end the session. The child '
              'has already accepted. Nothing is recorded.',
      confirmLabel: 'Join now',
    );
    if (!confirmed) return;
    await controller.join();
  }

  Future<void> _requestEnd(BuildContext context) async {
    final current = controller.session.value;
    final isRequest = current?.status == RemoteSessionStatus.requested;
    final confirmed = await ConfirmDialog.show(
      context,
      title: isRequest ? 'Cancel assistance request?' : 'End assistance session?',
      message: isRequest
          ? 'The child will no longer see this request.'
          : 'This stops your camera and microphone and ends the session for both '
              'participants.',
      confirmLabel: isRequest ? 'Cancel request' : 'End session',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.endSession(
      reason: isRequest ? 'cancelled_by_parent' : 'ended_by_parent',
    );
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
            valueColor:
                session.consentRecorded ? AppColors.success : AppColors.warning,
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
