import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';

class ChildRequestsTab extends GetView<ChildShellController> {
  const ChildRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: [
            IconButton(
              tooltip: 'Refresh requests',
              onPressed:
                  controller.isLoading.value ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading.value &&
        controller.lastLoadedAt.value == null) {
      return const LoadingState(label: 'Loading requests…');
    }
    final pendingError = controller.pendingError.value;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (!controller.isOnline) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message:
                  'Requests cannot be accepted or refreshed until the phone is '
                  'online again.',
            ),
            const SizedBox(height: 12),
          ],
          if (pendingError != null) ...[
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Requests could not be fully loaded',
              message: pendingError.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.pendingCount == 0) ...[
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No pending requests',
                message:
                    'Linking requests and assistance requests appear here. '
                    'Accepting anything is always your choice.',
                actionLabel: 'Open requests',
                onAction: () => Get.toNamed(AppRoutes.childRequests),
              ),
            ),
          ] else ...[
            if (controller.pendingPairings.isNotEmpty)
              SectionCard(
                title: 'Linking requests',
                subtitle: 'A guardian wants to link this phone to their family.',
                child: Column(
                  children: [
                    for (final request in controller.pendingPairings) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.family_restroom),
                        title: Text(request.familyName),
                        subtitle: Text(
                          'From ${request.parentDisplayName} · expires '
                          '${relativeTime(request.expiresAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Get.toNamed(AppRoutes.childRequests),
                      ),
                      if (request != controller.pendingPairings.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            if (controller.pendingPairings.isNotEmpty &&
                controller.pendingSessions.isNotEmpty)
              const SizedBox(height: 12),
            if (controller.pendingSessions.isNotEmpty)
              SectionCard(
                title: 'Assistance requests',
                subtitle:
                    'A parent is asking to speak with you. Camera and microphone '
                    'stay off until you accept and then start the session.',
                child: Column(
                  children: [
                    for (final session in controller.pendingSessions) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          session.kind == SessionKind.video
                              ? Icons.videocam_outlined
                              : Icons.mic_none,
                        ),
                        title: Text(
                          session.parentDisplayName ?? 'Your guardian',
                        ),
                        subtitle: Text(
                          '${session.kind.label} · '
                          '${session.expiresAt.isBefore(DateTime.now()) ? 'expired' : 'expires'} '
                          '${relativeTime(session.expiresAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Get.toNamed(AppRoutes.childRequests),
                      ),
                      if (session != controller.pendingSessions.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Review and respond',
              icon: Icons.forum_outlined,
              onPressed: () => Get.toNamed(AppRoutes.childRequests),
            ),
          ],
          if (controller.lastLoadedAt.value != null) ...[
            const SizedBox(height: 16),
            Text(
              'Requests refreshed ${relativeTime(controller.lastLoadedAt.value)}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
