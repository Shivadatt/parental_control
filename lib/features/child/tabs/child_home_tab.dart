import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';

class ChildHomeTab extends GetView<ChildShellController> {
  const ChildHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text(controller.isEnrolled ? controller.familyName : 'My phone'),
          actions: [
            IconButton(
              tooltip: 'Refresh this phone',
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
      return const LoadingState(label: 'Checking this phone…');
    }
    final fatal = controller.error.value;
    if (fatal != null && controller.lastLoadedAt.value == null) {
      return ErrorState(error: fatal, onRetry: () => controller.load());
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (controller.isRefreshing.value) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (!controller.isOnline) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message:
                  'Server rules and requests cannot be refreshed right now. '
                  'Android permission states below are still read from this '
                  'phone.',
            ),
            const SizedBox(height: 12),
          ],
          if (fatal != null && controller.lastLoadedAt.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not refresh',
              message: fatal.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.actionError.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Action failed',
              message: controller.actionError.value!.message,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.actionMessage.value != null) ...[
            InfoBanner(
              tone: BannerTone.success,
              title: 'Done',
              message: controller.actionMessage.value!,
              actionLabel: 'Dismiss',
              onAction: controller.clearNotices,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.activeSession.value != null) ...[
            _activeSessionCard(),
            const SizedBox(height: 12),
          ],
          if (!controller.isEnrolled)
            _enrollmentCard()
          else ...[
            _familyCard(context),
            const SizedBox(height: 12),
            _deviceCard(context),
            if (!controller.isManaged) ...[
              const SizedBox(height: 12),
              const InfoBanner(
                tone: BannerTone.warning,
                icon: Icons.gpp_maybe_outlined,
                title: 'App blocking is not enforced on this phone',
                message:
                    'This phone is not set up as a managed Device Owner device. '
                    'A normal app install cannot suspend other apps. A guardian '
                    'can provision it through Android managed-device or Device '
                    'Owner setup.',
              ),
            ],
            const SizedBox(height: 12),
            _guardianCard(context),
            const SizedBox(height: 12),
            _locationCard(context),
            if (controller.pendingCount > 0 || controller.pendingError.value != null) ...[
              const SizedBox(height: 12),
              _requestsSummaryCard(context),
            ],
            const SizedBox(height: 12),
            _quickActionsCard(context),
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
      ),
    );
  }

  /// Server state of the newest accepted/active assistance session for this
  /// phone. It never claims that media is connected or that the guardian can
  /// hear the phone; only the live session screen can say that.
  Widget _activeSessionCard() {
    final session = controller.activeSession.value!;
    final video = session.kind == SessionKind.video;
    final started = session.status == RemoteSessionStatus.active;
    final String title;
    if (started) {
      title = video
          ? 'Video assistance session is active'
          : 'Audio assistance session is active';
    } else {
      title = video
          ? 'Video assistance session accepted'
          : 'Audio assistance session accepted';
    }
    final String body;
    if (started) {
      body = video
          ? 'This session is open. Open the session screen to check whether '
              'this phone is sharing its camera and microphone. Only your '
              'guardian can end the session. Nothing is recorded.'
          : 'This session is open. Open the session screen to check whether '
              'this phone is sharing its microphone. Only your guardian can '
              'end the session. Nothing is recorded.';
    } else {
      body = video
          ? 'You accepted this request, but this phone has not joined it yet. '
              'Open the session to turn on the camera and microphone. Nothing '
              'is recorded.'
          : 'You accepted this request, but this phone has not joined it yet. '
              'Open the session to turn on the microphone. Nothing is recorded.';
    }
    return SectionCard(
      title: title,
      trailing: StatusChip(
        label: session.status.label,
        tone: started ? StatusTone.success : StatusTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 14),
          AppButton(
            label: 'Open session',
            icon: Icons.open_in_new,
            onPressed: controller.openActiveSession,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Stop sharing',
            icon: Icons.call_end,
            outlined: true,
            destructive: true,
            isLoading: controller.isStoppingActiveSession.value,
            onPressed: controller.isStoppingActiveSession.value
                ? null
                : controller.stopActiveSession,
          ),
        ],
      ),
    );
  }

  Widget _enrollmentCard() {
    final familyLinked = controller.hasFamily;
    return SectionCard(
      title: familyLinked ? 'Family linked — finish this phone' : 'Link this phone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            familyLinked
                ? 'Your account belongs to ${controller.familyName}, but this '
                    'phone is not registered yet. Background protection and '
                    'location sharing stay off until setup finishes.'
                : 'Create a linking code and show it to your guardian. Nothing '
                    'about this phone is shared until you approve their request '
                    'and finish setup.',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: familyLinked ? 'Finish phone setup' : 'Set up linking',
            icon: Icons.qr_code_2,
            onPressed: () => Get.toNamed(AppRoutes.childEnrollment),
          ),
          if (controller.pendingCount > 0) ...[
            const SizedBox(height: 10),
            AppButton(
              label:
                  'Open ${controller.pendingCount} pending request${controller.pendingCount == 1 ? '' : 's'}',
              icon: Icons.forum_outlined,
              outlined: true,
              onPressed: () => Get.toNamed(AppRoutes.childRequests),
            ),
          ],
        ],
      ),
    );
  }

  Widget _familyCard(BuildContext context) {
    return SectionCard(
      title: controller.familyName,
      subtitle: 'This account is linked as a child',
      trailing: const StatusChip(
        label: 'Linked',
        tone: StatusTone.success,
        icon: Icons.link,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Signed in as',
            value: controller.displayName,
          ),
          KeyValueRow(
            label: 'Email',
            value: controller.email.isEmpty ? 'Unknown' : controller.email,
          ),
          KeyValueRow(
            label: 'Device setup',
            value: controller.hasDevice ? 'Registered' : 'Not registered',
            valueColor:
                controller.hasDevice ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(BuildContext context) {
    final current = controller.device.value;
    if (current == null) {
      return SectionCard(
        title: 'This phone',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No active device row is visible for this account.'),
            const SizedBox(height: 12),
            AppButton(
              label: 'Open phone setup',
              outlined: true,
              onPressed: () => Get.toNamed(AppRoutes.childEnrollment),
            ),
          ],
        ),
      );
    }
    return SectionCard(
      title: 'This phone',
      trailing: StatusChip(
        label: current.statusLabel,
        tone: _deviceTone(current),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(label: 'Name', value: current.displayName),
          KeyValueRow(
            label: 'Last seen',
            value: current.lastSeenAt == null
                ? 'Never reported'
                : '${relativeTime(current.lastSeenAt)} · ${formatDateTime(current.lastSeenAt)}',
          ),
          KeyValueRow(
            label: 'Battery',
            value: formatBattery(current.batteryLevel, current.isCharging),
          ),
          KeyValueRow(
            label: 'Android control',
            value: controller.enforcementLabel,
            valueColor: controller.isManaged
                ? AppColors.success
                : AppColors.warning,
          ),
          KeyValueRow(
            label: 'Policy version',
            value: controller.policy.value == null
                ? 'No rules downloaded'
                : 'v${controller.policy.value!.version}',
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'View rules and permissions',
            icon: Icons.shield_outlined,
            outlined: true,
            onPressed: () => Get.toNamed(AppRoutes.childRestrictions),
          ),
        ],
      ),
    );
  }

  Widget _guardianCard(BuildContext context) {
    final status = controller.guardian.value;
    return SectionCard(
      title: 'Background protection',
      subtitle: 'A visible Android notification appears while this runs.',
      trailing: StatusChip(
        label: controller.guardianRunning ? 'Running' : 'Not running',
        tone: controller.guardianRunning
            ? StatusTone.success
            : StatusTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(label: 'Service', value: controller.guardianStatusLabel),
          KeyValueRow(
            label: 'Last command check',
            value: status?.lastPollAt == null
                ? 'No check yet'
                : relativeTime(status!.lastPollAt),
          ),
          if (status != null && status.lastError != null)
            KeyValueRow(
              label: 'Last error',
              value: status.lastError!,
              valueColor: AppColors.warning,
            ),
          if (controller.syncWarning.value != null) ...[
            const SizedBox(height: 8),
            InfoBanner(
              tone: BannerTone.warning,
              message: controller.syncWarning.value!,
            ),
          ],
          const SizedBox(height: 10),
          AppButton(
            label: 'Retry background protection',
            icon: Icons.sync,
            outlined: true,
            isLoading: controller.isStartingGuardian.value,
            onPressed: controller.retryBackgroundSync,
          ),
        ],
      ),
    );
  }

  Widget _locationCard(BuildContext context) {
    final caps = controller.capabilities.value;
    final locationReady = caps?.fineLocationGranted ?? false;
    return SectionCard(
      title: 'Location sharing',
      subtitle:
          'Your choice. The parent app can only request a location while this is on.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.locationSharingEnabled.value
                  ? 'Sharing location'
                  : 'Location sharing is off',
            ),
            subtitle: Text(
              locationReady
                  ? 'Uses the visible Android location service.'
                  : 'Precise location permission is not granted yet. Turning '
                      'this on asks for it.',
            ),
            value: controller.locationSharingEnabled.value,
            onChanged: controller.isUpdatingLocation.value
                ? null
                : controller.setLocationSharing,
          ),
          if (controller.isUpdatingLocation.value) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
          ],
          if (controller.locationWarning.value != null)
            InfoBanner(
              tone: BannerTone.warning,
              message: controller.locationWarning.value!,
            ),
          const SizedBox(height: 6),
          Text(
            'Turning this off stops the Android location service. No location '
            'is recorded by this app itself; uploads are short-lived fixes.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _requestsSummaryCard(BuildContext context) {
    return SectionCard(
      title: 'Waiting for you',
      trailing: StatusChip(
        label: '${controller.pendingCount} pending',
        tone: StatusTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.pendingPairings.isNotEmpty)
            KeyValueRow(
              label: 'Linking requests',
              value: '${controller.pendingPairings.length}',
            ),
          if (controller.pendingSessions.isNotEmpty)
            KeyValueRow(
              label: 'Assistance requests',
              value: '${controller.pendingSessions.length}',
            ),
          if (controller.pendingError.value != null)
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Some requests could not be loaded',
              message: controller.pendingError.value!.message,
            ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Review requests',
            icon: Icons.forum_outlined,
            onPressed: () => Get.toNamed(AppRoutes.childRequests),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context) {
    return SectionCard(
      title: 'More',
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.shield_outlined, color: AppColors.primary),
            title: const Text('Rules and permissions'),
            subtitle: const Text(
              'What is enforced and what this phone can verify',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.toNamed(AppRoutes.childRestrictions),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.forum_outlined, color: AppColors.primary),
            title: const Text('Requests'),
            subtitle: const Text('Linking and assistance requests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.toNamed(AppRoutes.childRequests),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.settings_outlined,
                color: AppColors.primary),
            title: const Text('This phone settings'),
            subtitle: const Text('Account, permissions and unlink'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => controller.selectTab(3),
          ),
        ],
      ),
    );
  }

  static StatusTone _deviceTone(Device current) {
    if (current.isRevoked) return StatusTone.danger;
    if (!current.isActive) return StatusTone.warning;
    return current.isOnline ? StatusTone.success : StatusTone.warning;
  }
}
