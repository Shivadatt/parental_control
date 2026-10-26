import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/telemetry.dart';
import 'safety_alerts_controller.dart';

class AlertsBody extends StatelessWidget {
  const AlertsBody({super.key, required this.controller, this.compact = false});

  final SafetyAlertsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const LoadingState(label: 'Loading safety alerts…');
      }
      final fatalError = controller.error.value;
      if (fatalError != null && controller.alerts.isEmpty) {
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
            if (fatalError != null)
              PageSection(
                child: InfoBanner(
                  tone: BannerTone.danger,
                  title: 'Refresh failed',
                  message: fatalError.message,
                  actionLabel: 'Retry',
                  onAction: () => controller.load(refresh: true),
                ),
              ),
            Obx(
              () => controller.realtimeError.value == null
                  ? const SizedBox.shrink()
                  : PageSection(
                      child: InfoBanner(
                        tone: BannerTone.warning,
                        title: 'Live updates offline',
                        message:
                            '${controller.realtimeError.value!.message} The list '
                            'below is the last data loaded on this phone.',
                        actionLabel: 'Reconnect',
                        onAction: () => controller.retryRealtime(),
                      ),
                    ),
            ),
            Obx(
              () => controller.actionError.value == null
                  ? const SizedBox.shrink()
                  : PageSection(
                      child: InfoBanner(
                        tone: BannerTone.danger,
                        title: 'Could not acknowledge',
                        message: controller.actionError.value!.message,
                      ),
                    ),
            ),
            PageSection(
              child: _FilterHeader(controller: controller, compact: compact),
            ),
            if (controller.alerts.isEmpty)
              PageSection(
                child: SectionCard(
                  child: EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No safety alerts',
                    message:
                        'Geofence, battery, offline, and permission alerts from '
                        'the child device will appear here. Nothing is generated '
                        'by this screen.',
                  ),
                ),
              )
            else if (controller.visibleAlerts.isEmpty)
              PageSection(
                child: SectionCard(
                  child: EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No alerts with this severity',
                    message: 'Choose another filter to see the rest.',
                  ),
                ),
              )
            else
              ...controller.visibleAlerts.map(
                (alert) => PageSection(
                  child: _AlertCard(
                    alert: alert,
                    busy: controller.acknowledgingIds.contains(alert.id),
                    onAcknowledge: () => _acknowledge(context, alert),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _acknowledge(BuildContext context, SafetyAlert alert) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Acknowledge this alert?',
      message:
          'This marks “${alert.type.label}” as seen for the whole family. It '
          'does not change the child device or fix the underlying issue.',
      confirmLabel: 'Acknowledge',
    );
    if (!confirmed) return;
    final success = await controller.acknowledge(alert);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert acknowledged on the server.')),
      );
    }
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.controller, required this.compact});

  final SafetyAlertsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compact ? 'Alerts' : 'Safety alerts',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${controller.unacknowledgedCount} unacknowledged · '
                    '${controller.alerts.length} total',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.isRefreshing.value
                  ? null
                  : () => controller.load(refresh: true),
              icon: controller.isRefreshing.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: controller.severityFilter.value == null,
              onSelected: (_) => controller.severityFilter.value = null,
            ),
            ...AlertSeverity.values.map(
              (severity) => ChoiceChip(
                label: Text(_severityLabel(severity)),
                selected: controller.severityFilter.value == severity,
                onSelected: (_) =>
                    controller.severityFilter.value = severity,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _severityLabel(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.busy,
    required this.onAcknowledge,
  });

  final SafetyAlert alert;
  final bool busy;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(alert.type), color: _toneColor(alert.severity)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusChip(
                          label: alert.type.label,
                          tone: StatusTone.info,
                          icon: _iconFor(alert.type),
                        ),
                        StatusChip(
                          label: _severityLabel(alert.severity),
                          tone: _tone(alert.severity),
                        ),
                        if (alert.isAcknowledged)
                          const StatusChip(
                            label: 'Acknowledged',
                            tone: StatusTone.success,
                            icon: Icons.done_all,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          KeyValueRow(
            label: 'Device',
            value: alert.deviceName ?? 'Unknown device',
          ),
          KeyValueRow(
            label: 'Time',
            value:
                '${formatDateTime(alert.createdAt)} · ${relativeTime(alert.createdAt)}',
          ),
          if (!alert.isAcknowledged) ...[
            const SizedBox(height: 8),
            AppButton(
              label: busy ? 'Acknowledging…' : 'Acknowledge',
              icon: Icons.done,
              outlined: true,
              isLoading: busy,
              onPressed: busy ? null : onAcknowledge,
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(SafetyAlertType type) {
    switch (type) {
      case SafetyAlertType.lowBattery:
        return Icons.battery_alert_outlined;
      case SafetyAlertType.deviceOffline:
        return Icons.cloud_off_outlined;
      case SafetyAlertType.geofenceEnter:
        return Icons.login_outlined;
      case SafetyAlertType.geofenceExit:
        return Icons.logout_outlined;
      case SafetyAlertType.appBlocked:
        return Icons.block_outlined;
      case SafetyAlertType.permissionMissing:
        return Icons.lock_outline;
      case SafetyAlertType.other:
        return Icons.notification_important_outlined;
    }
  }

  static StatusTone _tone(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return StatusTone.info;
      case AlertSeverity.warning:
        return StatusTone.warning;
      case AlertSeverity.critical:
        return StatusTone.danger;
    }
  }

  static Color _toneColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return AppColors.primary;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.critical:
        return AppColors.danger;
    }
  }

  static String _severityLabel(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
}
