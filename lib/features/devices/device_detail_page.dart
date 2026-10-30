import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/features/devices/device_detail_controller.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class DeviceDetailPage extends GetView<DeviceDetailController> {
  const DeviceDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final device = controller.device.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(device?.displayName ?? 'Device'),
          actions: [
            IconButton(
              tooltip: 'Refresh device',
              onPressed: controller.isLoading.value ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(context, device),
      );
    });
  }

  Widget _buildBody(BuildContext context, Device? device) {
    if (controller.isLoading.value && device == null) {
      return const LoadingState(label: 'Loading device…');
    }
    if (controller.error.value != null && device == null) {
      return ErrorState(
        error: controller.error.value!,
        onRetry: controller.load,
      );
    }
    if (device == null) {
      return const EmptyState(
        icon: Icons.phonelink_erase,
        title: 'Device not available',
        message: 'This device is no longer part of your family.',
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (controller.isLoading.value) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (controller.isOffline.value) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message:
                  'Showing the last loaded details. Updates and commands need a connection.',
            ),
            const SizedBox(height: 12),
          ],
          if (controller.error.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not refresh this device',
              message: controller.error.value!.message,
              actionLabel: 'Retry',
              onAction: controller.load,
            ),
            const SizedBox(height: 12),
          ],
          if (device.isRevoked) ...[
            const InfoBanner(
              tone: BannerTone.danger,
              icon: Icons.block,
              title: 'Device revoked',
              message:
                  'This device credential is revoked and it can no longer report or receive policies. '
                  'The child must link the device again.',
            ),
            const SizedBox(height: 12),
          ],
          _buildIdentityCard(context, device),
          if (controller.suspensionUnsupported) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.admin_panel_settings_outlined,
              title: 'App suspension is not supported here',
              message:
                  'This device is not a fully managed Device Owner device. Parent Control cannot '
                  'suspend or block apps until the phone is provisioned as fully managed. '
                  'A policy flag on its own does not block an app.',
            ),
          ],
          const SizedBox(height: 12),
          _buildPolicyCard(context),
          const SizedBox(height: 12),
          _buildPermissionsCard(device),
          const SizedBox(height: 12),
          _buildCommandsCard(context),
          const SizedBox(height: 12),
          _buildLinksCard(device),
          const SizedBox(height: 20),
          if (controller.revokeError.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not revoke this device',
              message: controller.revokeError.value!.message,
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: 'Revoke device',
            icon: Icons.link_off,
            outlined: true,
            destructive: true,
            isLoading: controller.isRevoking.value,
            onPressed: device.isRevoked ? null : () => _confirmRevoke(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Revoking invalidates the device credential and stops reports. '
            'Linking the phone again is required.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (controller.recoveryError.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not start recovery',
              message: controller.recoveryError.value!.message,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.recoveryStarted.value) ...[
            const InfoBanner(
              tone: BannerTone.info,
              icon: Icons.sync_alt,
              title: 'Recovery started on the server',
              message:
                  'The old credential is revoked and the family link is removed. On the child '
                  'phone, sign in, create a new linking code, then open Link a child here, '
                  'redeem the code and have the child approve the request. Recovery is not '
                  'complete until that approval.',
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: 'Lost or reinstalled phone',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use recovery when the child reinstalled Parent Control or the phone lost '
                  'its device credential. The server revokes the old credential and removes '
                  'the family link, so the old phone stops reporting. A new device is only '
                  'linked after a fresh one-time pairing code and the child approves it.',
                  style: TextStyle(height: 1.45, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Start device recovery',
                  icon: Icons.settings_backup_restore,
                  outlined: true,
                  isLoading: controller.isRecovering.value,
                  onPressed: controller.recoveryStarted.value
                      ? null
                      : () => _confirmRecovery(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, Device device) {
    return SectionCard(
      title: 'Device identity',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusChip(
            label: device.statusLabel,
            tone: device.isRevoked
                ? StatusTone.danger
                : (device.isOnline ? StatusTone.success : StatusTone.warning),
          ),
          if (device.isSyncStalled) ...[
            const SizedBox(height: 6),
            const StatusChip(
              label: 'Sync stalled',
              tone: StatusTone.warning,
              icon: Icons.sync_problem,
            ),
          ],
        ],
      ),
      child: Column(
        children: [
          KeyValueRow(label: 'Name', value: device.displayName),
          KeyValueRow(label: 'Platform', value: device.platform),
          KeyValueRow(
            label: 'Android',
            value: device.androidVersion ?? 'Not reported',
          ),
          KeyValueRow(
            label: 'App version',
            value: device.appVersion ?? 'Not reported',
          ),
          KeyValueRow(
            label: 'Last seen',
            value: device.lastSeenAt == null
                ? 'Never synced'
                : '${device.lastSeenAgeLabel} · ${formatDateTime(device.lastSeenAt)}',
          ),
          KeyValueRow(
            label: 'Battery',
            value: formatBattery(device.batteryLevel, device.isCharging),
          ),
          KeyValueRow(
            label: 'Enforcement mode',
            value: controller.enforcementLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context) {
    final policy = controller.latestPolicy.value;
    return SectionCard(
      title: 'Policy',
      subtitle: 'Saved policy version and the device acknowledgement',
      trailing: policy == null
          ? null
          : StatusChip(
              label: policy.status.label,
              tone: policyTone(policy.status),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Version',
            value: policy?.version.toString() ??
                controller.device.value?.policyVersion?.toString() ??
                'Not reported',
          ),
          KeyValueRow(
            label: 'Enforcement status',
            value: policy?.status.label ?? 'No policy acknowledgement reported',
          ),
          KeyValueRow(
            label: 'Acknowledged',
            value: policy?.acknowledgedAt == null
                ? 'Not yet acknowledged'
                : formatDateTime(policy?.acknowledgedAt),
          ),
          if (policy?.lastError != null) ...[
            const SizedBox(height: 6),
            Text(
              policy!.lastError!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          if (controller.awaitingAcknowledgement) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.hourglass_top,
              title: 'Pending device acknowledgement',
              message:
                  'The policy is saved on the server but this device has not confirmed applying it yet. '
                  'No restriction is active until the device acknowledges.',
            ),
          ],
          if (policy?.status == PolicyEnforcementStatus.unsupported) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.block,
              title: 'Unsupported on this device',
              message:
                  'The device refused this policy because enforcement is not available. '
                  'Set the phone up as a fully managed device to suspend apps.',
            ),
          ],
          if (policy?.status == PolicyEnforcementStatus.failed) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Enforcement failed',
              message: policy?.lastError ??
                  'The device reported a failure without an explanation.',
            ),
          ],
          if (controller.policyError.value != null) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Policy state unavailable',
              message: controller.policyError.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refreshPolicy,
            ),
          ] else ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.refreshPolicy,
                icon: const Icon(Icons.sync),
                label: const Text('Refresh policy state'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(Device device) {
    return SectionCard(
      title: 'Device permissions',
      subtitle: 'Reported by the child device. Unknown means it has not reported.',
      child: Column(
        children: [
          PermissionStatusTile(
            title: 'Usage access',
            subtitle: 'Required for screen-time reports',
            granted: device.usageAccessGranted ?? false,
            isUnknown: device.usageAccessGranted == null,
          ),
          PermissionStatusTile(
            title: 'Location',
            granted: device.locationGranted ?? false,
            isUnknown: device.locationGranted == null,
          ),
          PermissionStatusTile(
            title: 'Background location',
            granted: device.backgroundLocationGranted ?? false,
            isUnknown: device.backgroundLocationGranted == null,
          ),
          PermissionStatusTile(
            title: 'Camera',
            granted: device.cameraGranted ?? false,
            isUnknown: device.cameraGranted == null,
          ),
          PermissionStatusTile(
            title: 'Microphone',
            granted: device.microphoneGranted ?? false,
            isUnknown: device.microphoneGranted == null,
          ),
          PermissionStatusTile(
            title: 'Notifications',
            granted: device.notificationsGranted ?? false,
            isUnknown: device.notificationsGranted == null,
          ),
        ],
      ),
    );
  }

  Widget _buildCommandsCard(BuildContext context) {
    return SectionCard(
      title: 'Recent commands',
      subtitle: 'Delivery is confirmed by the device, not by this screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.commandsError.value != null)
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Commands unavailable',
              message: controller.commandsError.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            )
          else if (controller.recentCommands.isEmpty)
            Text(
              'No commands have been sent to this device yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            )
          else
            ...controller.recentCommands.map(
              (command) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  command.status == DeviceCommandStatus.succeeded
                      ? Icons.check_circle_outline
                      : Icons.hourglass_empty,
                  color: command.status == DeviceCommandStatus.failed
                      ? AppColors.danger
                      : AppColors.muted,
                ),
                title: Text(command.type.label),
                subtitle: Text(
                  '${command.status.label} · ${relativeTime(command.createdAt)}'
                  '${command.error == null ? '' : ' · ${command.error}'}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinksCard(Device device) {
    final familyId = device.familyId;
    return SectionCard(
      title: 'Manage',
      child: Column(
        children: [
          _LinkTile(
            icon: Icons.apps,
            title: 'App restrictions',
            onTap: () => Get.toNamed(
              AppRoutes.appRestrictions,
              arguments: {'deviceId': device.id},
            ),
          ),
          _LinkTile(
            icon: Icons.timelapse,
            title: 'Screen time',
            onTap: () => Get.toNamed(
              AppRoutes.screenTime,
              arguments: {'deviceId': device.id},
            ),
          ),
          _LinkTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            onTap: () => Get.toNamed(
              AppRoutes.location,
              arguments: {'deviceId': device.id, 'familyId': familyId},
            ),
          ),
          _LinkTile(
            icon: Icons.shield_outlined,
            title: 'Safe zones',
            onTap: () => Get.toNamed(
              AppRoutes.safeZones,
              arguments: {'familyId': familyId, 'deviceId': device.id},
            ),
          ),
          _LinkTile(
            icon: Icons.notifications_outlined,
            title: 'Safety alerts',
            onTap: () => Get.toNamed(
              AppRoutes.alerts,
              arguments: {'familyId': familyId},
            ),
          ),
          _LinkTile(
            icon: Icons.support_agent,
            title: 'Remote assistance',
            onTap: () => Get.toNamed(
              AppRoutes.remoteAssistance,
              arguments: {'deviceId': device.id},
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRecovery(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Start device recovery?',
      message:
          'This revokes the current credential and removes the child from the family. '
          'The child must sign in, create a new linking code and approve the new pairing '
          'before this phone can report again. Only start recovery for a phone you still '
          'control or that was reinstalled.',
      confirmLabel: 'Start recovery',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await controller.recoverDevice();
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke this device?',
      message:
          'The device credential is invalidated on the server, reports stop and the child '
          'must link the phone again. This cannot be undone from the app.',
      confirmLabel: 'Revoke device',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final revoked = await controller.revokeDevice();
    if (!context.mounted) return;
    if (revoked) {
      Get.back();
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
