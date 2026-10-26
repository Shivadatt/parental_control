import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/features/devices/devices_controller.dart';

class ParentDevicesTab extends GetView<DevicesController> {
  const ParentDevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Devices'),
          actions: [
            IconButton(
              tooltip: 'Refresh devices',
              onPressed: controller.isLoading.value ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(context, controller),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DevicesController controller) {
    if (controller.isLoading.value && controller.family.value == null) {
      return const LoadingState(label: 'Loading devices…');
    }
    if (controller.error.value != null &&
        controller.family.value == null &&
        controller.devices.isEmpty) {
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
              message: 'Device status may be out of date until the connection returns.',
              actionLabel: 'Try again',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.error.value != null && !controller.isOffline.value) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not load devices',
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
            for (final device in controller.devices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceListCard(
                  controller: controller,
                  device: device,
                ),
              ),
            if (controller.lastRefreshedAt.value != null) ...[
              const SizedBox(height: 4),
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

  Widget _buildEmptyState(DevicesController controller) {
    if (!controller.hasFamily) {
      return EmptyState(
        icon: Icons.family_restroom,
        title: 'No family set up yet',
        message:
            'Create your family and pair a child device to see it listed here.',
        actionLabel: 'Set up family',
        onAction: () => Get.toNamed(AppRoutes.familySetup),
      );
    }
    return EmptyState(
      icon: Icons.phonelink_erase,
      title: 'No devices linked',
      message:
          'Pair a child phone with a linking code. A device appears here only after '
          'the child approves the request and the device registers.',
      actionLabel: 'Open family & pairing',
      onAction: () => Get.toNamed(
        AppRoutes.family,
        arguments: {'familyId': controller.familyId ?? ''},
      ),
    );
  }
}

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({required this.controller, required this.device});

  final DevicesController controller;
  final Device device;

  StatusTone get _tone {
    if (device.isRevoked) return StatusTone.danger;
    return device.isOnline ? StatusTone.success : StatusTone.warning;
  }

  @override
  Widget build(BuildContext context) {
    final gaps = controller.permissionGapsForDevice(device);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatBattery(device.batteryLevel, device.isCharging),
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
            value: device.lastSeenAt == null
                ? 'Never reported'
                : relativeTime(device.lastSeenAt),
          ),
          KeyValueRow(
            label: 'Enforcement',
            value: controller.enforcementLabelFor(device),
          ),
          KeyValueRow(
            label: 'Policy',
            value: controller.policySummaryFor(device),
          ),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: gaps
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
