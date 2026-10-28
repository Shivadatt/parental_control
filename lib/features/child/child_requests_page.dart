import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/child/controllers/child_requests_controller.dart';

class ChildRequestsPage extends GetView<ChildRequestsController> {
  const ChildRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: [
            IconButton(
              tooltip: 'Refresh requests',
              onPressed: controller.isRefreshing.value
                  ? null
                  : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading.value && controller.lastLoadedAt.value == null) {
      return const LoadingState(label: 'Loading your requests…');
    }
    final fatal = controller.error.value;
    if (fatal != null && controller.lastLoadedAt.value == null) {
      return ErrorState(error: fatal, onRetry: () => controller.load());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (!controller.isOnline) ...[
          const InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.wifi_off,
            title: 'You are offline',
            message:
                'Requests cannot be answered until this phone is online again.',
          ),
          const SizedBox(height: 12),
        ],
        if (controller.actionError.value != null) ...[
          InfoBanner(
            tone: BannerTone.danger,
            title: 'Action failed',
            message: controller.actionError.value!.message,
            actionLabel: 'Dismiss',
            onAction: controller.clearActionError,
          ),
          const SizedBox(height: 12),
        ],
        if (controller.actionMessage.value != null) ...[
          InfoBanner(
            tone: BannerTone.success,
            title: 'Done',
            message: controller.actionMessage.value!,
          ),
          const SizedBox(height: 12),
        ],
        if (controller.isRefreshing.value) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        if (controller.pendingCount == 0)
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No pending requests',
              message:
                  'Linking and assistance requests appear here. Nothing is '
                  'accepted automatically, and camera or microphone stays off '
                  'until you accept and start a session.',
            ),
          )
        else ...[
          if (controller.pairingRequests.isNotEmpty)
            SectionCard(
              title: 'Linking requests',
              subtitle:
                  'Approving links your account to this family. Only approve a '
                  'guardian you recognise.',
              child: Column(
                children: [
                  for (final request in controller.pairingRequests) ...[
                    _PairingRequestTile(
                      request: request,
                      busy: controller.isResponding.value,
                      onApprove: () => _confirmApprove(context, request),
                      onDecline: () => controller.declinePairing(request),
                    ),
                    if (request != controller.pairingRequests.last)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
          if (controller.pairingRequests.isNotEmpty &&
              controller.sessionRequests.isNotEmpty)
            const SizedBox(height: 12),
          if (controller.sessionRequests.isNotEmpty)
            SectionCard(
              title: 'Assistance requests',
              subtitle:
                  'Accepting a request does not turn on the camera or '
                  'microphone. You can review and start the session on the next '
                  'screen, and end it at any time.',
              child: Column(
                children: [
                  for (final session in controller.sessionRequests) ...[
                    _SessionRequestTile(
                      session: session,
                      busy: controller.isResponding.value,
                      onAccept: () => _confirmAccept(context, session),
                      onDecline: () => controller.declineSession(session),
                    ),
                    if (session != controller.sessionRequests.last)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
        ],
        if (controller.lastLoadedAt.value != null) ...[
          const SizedBox(height: 16),
          Text(
            'Updated ${relativeTime(controller.lastLoadedAt.value)}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    PairingRequest request,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Join ${request.familyName}?',
      message:
          'Approving links your account to this family. You can unlink later '
          'from This phone settings.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    await controller.approvePairing(request);
  }

  Future<void> _confirmAccept(
    BuildContext context,
    RemoteSession session,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Accept assistance from ${session.parentDisplayName ?? 'your guardian'}?',
      message: session.kind == SessionKind.video
          ? 'The next screen lets you start a live video call. Your camera and '
              'microphone stay off until you tap Join there. Nothing is '
              'recorded.'
          : 'The next screen lets you start a live audio call. Your microphone '
              'stays off until you tap Join there. Nothing is recorded.',
      confirmLabel: 'Accept request',
    );
    if (!confirmed) return;
    await controller.acceptSession(session);
  }
}

class _PairingRequestTile extends StatelessWidget {
  const _PairingRequestTile({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final PairingRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.family_restroom, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.familyName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'From ${request.parentDisplayName} · expires '
                    '${relativeTime(request.expiresAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Decline',
                outlined: true,
                destructive: true,
                onPressed: busy ? null : onDecline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Approve',
                isLoading: busy,
                onPressed: busy ? null : onApprove,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionRequestTile extends StatelessWidget {
  const _SessionRequestTile({
    required this.session,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final RemoteSession session;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              session.kind == SessionKind.video
                  ? Icons.videocam_outlined
                  : Icons.mic_none,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.parentDisplayName ?? 'Your guardian',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${session.kind.label} · '
                    '${session.expiresAt.isBefore(DateTime.now()) ? 'expired' : 'expires'} '
                    '${relativeTime(session.expiresAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const StatusChip(
              label: 'Waiting',
              tone: StatusTone.warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Decline',
                outlined: true,
                destructive: true,
                onPressed: busy ? null : onDecline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Accept',
                isLoading: busy,
                onPressed: busy ? null : onAccept,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
