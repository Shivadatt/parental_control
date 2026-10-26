import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/telemetry.dart';
import '../../data/services/connectivity_service.dart';
import 'location_controller.dart';

class LocationPage extends GetView<LocationController> {
  const LocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
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
          IconButton(
            tooltip: 'Safe zones',
            onPressed: () => _openSafeZones(),
            icon: const Icon(Icons.fence_outlined),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingState(label: 'Loading latest location…');
        }
        final latestError = controller.error.value;
        return RefreshIndicator(
          onRefresh: () => controller.load(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Obx(
                () => connectivity.isOnline.value
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: InfoBanner(
                          tone: BannerTone.warning,
                          title: 'Offline',
                          message:
                              'Showing the last data loaded on this phone. '
                              'A live location cannot be fetched until the '
                              'connection returns.',
                        ),
                      ),
              ),
              PageSection(
                child: _LatestFixCard(
                  latest: controller.latest.value,
                  error: latestError,
                  permissionDenied: controller.permissionDenied,
                  isStale: controller.latestIsStale,
                  onRetry: () => controller.load(refresh: true),
                  onOpenSafeZones: _openSafeZones,
                ),
              ),
              PageSection(child: _historyHeader(context)),
              Obx(() => _historyBody(context)),
              if (controller.hasMoreHistoryThanShown)
                const PageSection(
                  child: Text(
                    'Showing the most recent 500 points in this range.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _historyHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'History',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Obx(
          () => Wrap(
            spacing: 8,
            children: LocationHistoryRange.values.map((value) {
              return ChoiceChip(
                label: Text(value.shortLabel),
                selected: controller.range.value == value,
                onSelected: (_) => controller.setRange(value),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _historyBody(BuildContext context) {
    if (controller.isHistoryLoading.value) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final historyError = controller.historyError.value;
    if (historyError != null) {
      return InfoBanner(
        tone: BannerTone.danger,
        title: 'History unavailable',
        message: historyError.message,
        actionLabel: 'Retry',
        onAction: () => controller.loadHistory(),
      );
    }
    if (controller.history.isEmpty) {
      return SectionCard(
        child: EmptyState(
          icon: Icons.timeline,
          title: 'No location history',
          message:
              'No fixes were recorded in the ${controller.range.value.label.toLowerCase()}.',
        ),
      );
    }
    return Column(
      children: controller.history.map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SectionCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _coordinates(event.latitude, event.longitude),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDateTime(event.recordedAt)} · '
                        '${relativeTime(event.recordedAt)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '±${event.accuracyM.round()} m',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  void _openSafeZones() {
    Get.toNamed(
      AppRoutes.safeZones,
      arguments: {
        'familyId': controller.familyId,
        'deviceId': controller.deviceId,
      },
    );
  }

  static String _coordinates(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

class _LatestFixCard extends StatelessWidget {
  const _LatestFixCard({
    required this.latest,
    required this.error,
    required this.permissionDenied,
    required this.isStale,
    required this.onRetry,
    required this.onOpenSafeZones,
  });

  final LocationEvent? latest;
  final AppException? error;
  final bool permissionDenied;
  final bool isStale;
  final VoidCallback onRetry;
  final VoidCallback onOpenSafeZones;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return SectionCard(
        title: 'Latest fix',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoBanner(
              tone: BannerTone.danger,
              title: permissionDenied ? 'Permission or access denied' : 'Unavailable',
              message: permissionDenied
                  ? 'Location may not be granted on the child device, or this '
                      'account cannot read it. Ask the child to allow location '
                      'access, then refresh.'
                  : error!.message,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Try again',
              icon: Icons.refresh,
              outlined: true,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    final fix = latest;
    if (fix == null) {
      return SectionCard(
        title: 'Latest fix',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No location reported yet',
              message:
                  'This device has not uploaded a location. Check that location '
                  'permission is granted and tracking is enabled on the child '
                  'device.',
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Manage safe zones',
              icon: Icons.fence_outlined,
              outlined: true,
              onPressed: onOpenSafeZones,
            ),
          ],
        ),
      );
    }

    return SectionCard(
      title: 'Latest fix',
      trailing: isStale
          ? const StatusChip(
              label: 'STALE',
              tone: StatusTone.danger,
              icon: Icons.warning_amber_rounded,
            )
          : const StatusChip(
              label: 'Recent',
              tone: StatusTone.success,
              icon: Icons.check_circle_outline,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStale) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              title: 'STALE LOCATION',
              message:
                  'This fix is older than 10 minutes. It is not the child’s '
                  'current position.',
            ),
            const SizedBox(height: 12),
          ],
          Text(
            '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          KeyValueRow(
            label: 'Recorded',
            value: '${formatDateTime(fix.recordedAt)} '
                '(${relativeTime(fix.recordedAt)})',
            valueColor: isStale ? AppColors.danger : null,
          ),
          KeyValueRow(
            label: 'Received',
            value: formatDateTime(fix.receivedAt),
          ),
          KeyValueRow(
            label: 'Accuracy',
            value: '±${fix.accuracyM.toStringAsFixed(1)} m',
          ),
          KeyValueRow(label: 'Source', value: fix.source),
          const SizedBox(height: 12),
          AppButton(
            label: 'Manage safe zones',
            icon: Icons.fence_outlined,
            outlined: true,
            onPressed: onOpenSafeZones,
          ),
        ],
      ),
    );
  }
}
