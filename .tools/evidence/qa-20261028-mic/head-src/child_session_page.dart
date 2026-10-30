import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class ChildSessionPage extends GetView<RemoteSessionController> {
  const ChildSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
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
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
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
        PageSection(child: _statusCard(session)),
        ..._banners(),
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
          PageSection(child: _consentCard(context))
        else if (session.status.isTerminal)
          PageSection(child: _terminalCard(session))
        else if (controller.hasActivePeer.value)
          PageSection(child: _mediaCard(session))
        else
          PageSection(child: _joinCard(context, session)),
        if (controller.canEnd)
          PageSection(
            child: AppButton(
              label: 'End session',
              icon: Icons.call_end,
              destructive: true,
              isLoading: controller.isEnding.value,
              onPressed: () => _confirmEnd(context),
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
            'Nothing is recorded. Camera and microphone are used only during '
            'this session and stop when you end it or leave this screen. The '
            'app never takes screenshots or reads messages.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }

  List<Widget> _banners() {
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

  Widget _statusCard(RemoteSession session) {
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

  Widget _consentCard(BuildContext context) {
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

  Widget _joinCard(BuildContext context, RemoteSession session) {
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

  Widget _mediaCard(RemoteSession session) {
    final waiting = !controller.isConnected.value;
    return SectionCard(
      child: Column(
        children: [
          if (session.kind == SessionKind.video && controller.isRemoteVideoActive.value)
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
                    session.kind == SessionKind.video
                        ? Icons.videocam
                        : Icons.graphic_eq,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.isConnected.value
                        ? (session.kind == SessionKind.video
                            ? 'Camera and microphone are on'
                            : 'Microphone is on')
                        : (session.kind == SessionKind.video
                            ? 'Camera and microphone on — waiting for the parent'
                            : 'Microphone on — waiting for the parent'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
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

  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'End this session?',
      message:
          'This stops your camera and microphone immediately and ends the '
          'session for both participants.',
      confirmLabel: 'End session',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.endSession(reason: 'ended_by_child');
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
