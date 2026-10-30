import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/remote_session.dart';
import '../../data/services/connectivity_service.dart';
import 'remote_assistance_controller.dart';

/// Title for the pre-request consent dialog.
String requestDialogTitle(SessionKind kind) =>
    'Request ${kind == SessionKind.video ? 'video' : 'audio'} assistance?';

/// Copy for the pre-request consent dialog.
///
/// Exposed so tests can pin the wording: sending the request does not open
/// anything, and the parent joining alone never opens the child's microphone.
String requestDialogMessage(SessionKind kind) {
  final childMedia = kind == SessionKind.video
      ? 'camera and microphone open'
      : 'microphone opens';
  return 'Sending this request notifies the child. The child must accept it, '
      'then tap Join on their own phone to start the session. You join from '
      'the session screen afterwards. This phone\'s camera and microphone are '
      'never opened; the child\'s $childMedia only after the child accepts and '
      'joins. The request expires in 10 minutes.';
}

class RemoteAssistancePage extends GetView<RemoteAssistanceController> {
  const RemoteAssistancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote assistance'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh',
              onPressed: controller.isRefreshing.value
                  ? null
                  : () => controller.load(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingState(label: 'Loading assistance sessions…');
        }
        final fatalError = controller.error.value;
        if (fatalError != null) {
          return ErrorState(
            error: fatalError,
            onRetry: () => controller.load(refresh: true),
          );
        }
        return RefreshIndicator(
          onRefresh: () => controller.load(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              Obx(
                () => connectivity.isOnline.value
                    ? const SizedBox.shrink()
                    : const PageSection(
                        child: InfoBanner(
                          tone: BannerTone.warning,
                          title: 'Offline',
                          message:
                              'A consent request cannot be sent while offline. '
                              'Reconnect before starting an assistance session.',
                        ),
                      ),
              ),
              const PageSection(
                child: SectionCard(
                  title: 'Assistance with explicit consent',
                  child: Text(
                    'A request is delivered to the child account. Nothing opens '
                    'until the child accepts it and then taps Join on their own '
                    'session screen; you join from the session screen on this '
                    'phone. This phone\'s camera and microphone are never opened '
                    'by the app. Nothing is recorded, and no screenshots or '
                    'screen capture are taken. A pending request expires if it '
                    'is not answered; once accepted, the session stays open '
                    'until the guardian ends it. The status on each card is the '
                    'server\'s session status, not a media indicator.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ),
              Obx(
                () => controller.actionError.value == null
                    ? const SizedBox.shrink()
                    : PageSection(
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          title: 'Request failed',
                          message: controller.actionError.value!.message,
                        ),
                      ),
              ),
              PageSection(
                child: Obx(
                  () => Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Request audio',
                          icon: Icons.mic_none_outlined,
                          outlined: true,
                          isLoading:
                              controller.requestingKind.value == SessionKind.audio,
                          onPressed: !connectivity.isOnline.value ||
                                  controller.isRequesting
                              ? null
                              : () => _request(context, SessionKind.audio),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Request video',
                          icon: Icons.videocam_outlined,
                          isLoading:
                              controller.requestingKind.value == SessionKind.video,
                          onPressed: !connectivity.isOnline.value ||
                                  controller.isRequesting
                              ? null
                              : () => _request(context, SessionKind.video),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PageSection(
                child: Text(
                  'Audio and video come from the child device only, after the '
                  'child accepts and joins. This phone\'s camera and microphone '
                  'are never opened, so audio assistance is listen-only.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              PageSection(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent sessions',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${controller.sessions.length}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (controller.sessions.isEmpty)
                const PageSection(
                  child: SectionCard(
                    child: EmptyState(
                      icon: Icons.support_agent,
                      title: 'No assistance sessions',
                      message:
                          'Sessions requested from this family appear here with '
                          'their server status.',
                    ),
                  ),
                )
              else
                ...controller.sessions.map(
                  (session) => PageSection(
                    child: _SessionCard(
                      session: session,
                      statusLabel: controller.statusLabel(session),
                      expiryLabel: controller.expiryLabel(session),
                      onOpen: () => _openSession(context, session),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _request(BuildContext context, SessionKind kind) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: requestDialogTitle(kind),
      message: requestDialogMessage(kind),
      confirmLabel: 'Send request',
    );
    if (!confirmed) return;
    final created = await controller.requestSession(kind);
    if (!context.mounted || created == null) return;
    await Get.toNamed(
      AppRoutes.remoteSession,
      arguments: {'sessionId': created.id, 'role': 'parent'},
    );
    if (!context.mounted) return;
    await controller.load(refresh: true);
  }

  Future<void> _openSession(BuildContext context, RemoteSession session) async {
    await Get.toNamed(
      AppRoutes.remoteSession,
      arguments: {'sessionId': session.id, 'role': 'parent'},
    );
    if (!context.mounted) return;
    await controller.load(refresh: true);
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.statusLabel,
    required this.expiryLabel,
    required this.onOpen,
  });

  final RemoteSession session;
  final String statusLabel;
  final String expiryLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  session.kind == SessionKind.video
                      ? Icons.videocam_outlined
                      : Icons.mic_none_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.kind.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                StatusChip(
                  label: statusLabel,
                  tone: _tone(session, statusLabel),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KeyValueRow(
              label: 'Device',
              value: session.deviceName ?? 'Unknown device',
            ),
            if (session.childDisplayName != null)
              KeyValueRow(label: 'Child', value: session.childDisplayName!),
            KeyValueRow(label: 'Media', value: session.mediaNote),
            KeyValueRow(
              label: 'Requested',
              value:
                  '${formatDateTime(session.requestedAt)} · ${relativeTime(session.requestedAt)}',
            ),
            if (session.status.isOpen && !session.isExpired)
              KeyValueRow(
                label: session.isParentControlled
                    ? 'Session duration'
                    : 'Expires',
                value: expiryLabel,
              ),
            const SizedBox(height: 6),
            const Text(
              'Tap to open the session screen',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static StatusTone _tone(RemoteSession session, String statusLabel) {
    if (statusLabel.endsWith('expired')) return StatusTone.warning;
    switch (session.status) {
      case RemoteSessionStatus.requested:
        return StatusTone.info;
      case RemoteSessionStatus.accepted:
        return StatusTone.info;
      case RemoteSessionStatus.active:
        // Server state only. A success tone would imply healthy live media,
        // which this screen cannot know.
        return StatusTone.info;
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
