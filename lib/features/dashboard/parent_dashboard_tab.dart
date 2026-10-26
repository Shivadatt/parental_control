import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class ParentDashboardTab extends GetView<DashboardController> {
  const ParentDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text(controller.familyName),
          actions: [
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: controller.isLoading.value ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(context, controller),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DashboardController controller) {
    if (controller.isLoading.value && controller.family.value == null) {
      return const LoadingState(label: 'Loading dashboard…');
    }
    if (controller.error.value != null && controller.family.value == null) {
      return ErrorState(error: controller.error.value!, onRetry: controller.load);
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
            InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message:
                  'Showing the last data loaded on this device. Refresh once the connection returns.',
              actionLabel: 'Try again',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.error.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not refresh',
              message: controller.error.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.isEmpty)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: _buildEmptyState(controller),
            )
          else ...[
            _buildDeviceSection(controller),
            const SizedBox(height: 16),
            _buildQuickLinks(controller),
            if (controller.lastRefreshedAt.value != null) ...[
              const SizedBox(height: 12),
              Text(
                'Updated ${relativeTime(controller.lastRefreshedAt.value)}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(DashboardController controller) {
    if (!controller.hasFamily) {
      return EmptyState(
        icon: Icons.family_restroom,
        title: 'No family set up yet',
        message:
            'Create your family first, then pair your child so their device can report here.',
        actionLabel: 'Set up family',
        onAction: () => Get.toNamed(AppRoutes.familySetup),
      );
    }
    return EmptyState(
      icon: Icons.phonelink_erase,
      title: 'No child linked yet',
      message:
          'Create a linking code on your child\'s device and redeem it here to link a phone. '
          'Nothing is shown until a child accepts the link.',
      actionLabel: 'Open family & pairing',
      onAction: () => Get.toNamed(
        AppRoutes.family,
        arguments: {'familyId': controller.familyId ?? ''},
      ),
    );
  }

  Widget _buildDeviceSection(DashboardController controller) {
    final orphanChildren = controller.childrenWithoutDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.hasDevices)
          ...controller.devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceCard(
                controller: controller,
                device: device,
              ),
            ),
          ),
        if (orphanChildren.isNotEmpty)
          SectionCard(
            title: 'Linked children',
            subtitle: 'These children do not have a registered device yet.',
            child: Column(
              children: orphanChildren
                  .map(
                    (child) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(child.displayName),
                      subtitle: const Text('No device enrolled yet'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickLinks(DashboardController controller) {
    final familyId = controller.familyId;
    if (familyId == null) return const SizedBox.shrink();
    return SectionCard(
      title: 'Quick links',
      child: Column(
        children: [
          _QuickLinkTile(
            icon: Icons.family_restroom,
            title: 'Family',
            subtitle: 'Members, devices and linking codes',
            onTap: () => Get.toNamed(
              AppRoutes.family,
              arguments: {'familyId': familyId},
            ),
          ),
          const Divider(height: 1),
          _QuickLinkTile(
            icon: Icons.qr_code_2,
            title: 'Pair a device',
            subtitle: 'Redeem the linking code shown on your child\'s phone',
            onTap: () => Get.toNamed(
              AppRoutes.pairingRedeem,
              arguments: {'familyId': familyId},
            ),
          ),
          const Divider(height: 1),
          _QuickLinkTile(
            icon: Icons.notifications_outlined,
            title: 'Alerts',
            subtitle: 'Review safety alerts for this family',
            onTap: () => Get.toNamed(
              AppRoutes.alerts,
              arguments: {'familyId': familyId},
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.controller, required this.device});

  final DashboardController controller;
  final Device device;

  StatusTone get _tone {
    if (device.isRevoked) return StatusTone.danger;
    return device.isOnline ? StatusTone.success : StatusTone.warning;
  }

  @override
  Widget build(BuildContext context) {
    final lastSeen = device.lastSeenAt;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: (device.isOnline
                        ? AppColors.success
                        : AppColors.muted)
                    .withValues(alpha: 0.12),
                child: Icon(
                  Icons.smartphone,
                  color: device.isOnline ? AppColors.success : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.displayNameFor(device),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              StatusChip(label: device.statusLabel, tone: _tone),
            ],
          ),
          const SizedBox(height: 12),
          KeyValueRow(
            label: 'Last seen',
            value: lastSeen == null
                ? 'Never reported'
                : '${relativeTime(lastSeen)} · ${formatDateTime(lastSeen)}',
          ),
          KeyValueRow(
            label: 'Battery',
            value: formatBattery(device.batteryLevel, device.isCharging),
          ),
          KeyValueRow(
            label: 'Enforcement',
            value: controller.enforcementLabelFor(device),
          ),
          KeyValueRow(
            label: 'Policy',
            value: controller.policySummaryFor(device),
          ),
          if (permissionGapsFor(device).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissionGapsFor(device)
                  .map(
                    (gap) => StatusChip(
                      label: '$gap missing',
                      tone: StatusTone.warning,
                      icon: Icons.warning_amber,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Get.toNamed(
                AppRoutes.deviceDetail,
                arguments: {'deviceId': device.id},
              ),
              icon: const Icon(Icons.chevron_right),
              label: const Text('Open device'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
