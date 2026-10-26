import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/features/devices/device_presentation.dart';
import 'package:parent_control/features/screen_time/screen_time_controller.dart';

class ScreenTimePage extends GetView<ScreenTimeController> {
  const ScreenTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final device = controller.device.value;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Screen time'),
          actions: [
            IconButton(
              tooltip: 'Refresh screen time',
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
      return const LoadingState(label: 'Loading screen time…');
    }
    if (controller.error.value != null && device == null) {
      return ErrorState(error: controller.error.value!, onRetry: controller.load);
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
            InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message: 'Showing stored usage. New uploads and saves need a connection.',
              actionLabel: 'Try again',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.error.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not refresh screen time',
              message: controller.error.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          _buildPermissionCard(context, device),
          if (controller.usageAccessDenied)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: InfoBanner(
                tone: BannerTone.warning,
                icon: Icons.bar_chart,
                title: 'No usage numbers available',
                message:
                    'Usage Access is not granted, so screen-time data cannot be read or shown. '
                    'Follow the setup steps above, then request a device sync from App restrictions.',
              ),
            ),
          if (!controller.usageAccessDenied) ...[
            const SizedBox(height: 12),
            _buildUploadCard(context),
            if (controller.usageError.value != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                tone: BannerTone.danger,
                title: 'Usage data unavailable',
                message: controller.usageError.value!.message,
                actionLabel: 'Retry',
                onAction: controller.refresh,
              ),
            ],
            const SizedBox(height: 12),
            _buildUsageCard(context),
          ],
          const SizedBox(height: 12),
          _buildPolicyCard(context),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save screen-time policy',
            icon: Icons.save_outlined,
            isLoading: controller.saving.value,
            onPressed: device.isRevoked || !controller.policyReady.value
                ? null
                : controller.savePolicy,
          ),
          const SizedBox(height: 8),
          Text(
            'A saved limit is not enforcement. The child device must acknowledge this policy, '
            'Usage Access must be granted and the guardian service must be running.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, Device device) {
    final granted = device.usageAccessGranted;
    final tone = granted == null
        ? StatusTone.neutral
        : (granted ? StatusTone.success : StatusTone.warning);
    final label = granted == null
        ? 'Not reported'
        : (granted ? 'Granted' : 'Required');
    return SectionCard(
      title: 'Usage Access',
      subtitle: 'Reported by the child device',
      trailing: StatusChip(label: label, tone: tone),
      child: Text(
        controller.usagePermissionText,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context) {
    final hasUpload = controller.effectiveLastUpload != null;
    return SectionCard(
      title: 'Last usage upload',
      trailing: !hasUpload
          ? const StatusChip(label: 'No upload', tone: StatusTone.neutral)
          : (controller.isUploadStale
              ? const StatusChip(
                  label: 'Stale',
                  tone: StatusTone.warning,
                  icon: Icons.schedule,
                )
              : const StatusChip(
                  label: 'Recent',
                  tone: StatusTone.success,
                )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(controller.lastUploadText),
          if (controller.isUploadStale) ...[
            const SizedBox(height: 8),
            const InfoBanner(
              tone: BannerTone.warning,
              title: 'Usage data is older than 24 hours',
              message:
                  'The device has not uploaded recent usage. Totals below may be out of date.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context) {
    if (!controller.hasUsageData) {
      return SectionCard(
        title: 'Usage',
        child: SizedBox(
          height: 240,
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'No usage reported yet',
            message:
                'The device has not uploaded usage data for the last 7 days. '
                'This is not zero usage — it is missing data.',
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Usage',
      subtitle: 'From usage_daily rows uploaded by the device',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Today',
                  value: formatDurationMs(controller.todayTotalMs),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Last 7 days',
                  value: formatDurationMs(controller.weekTotalMs),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Today')),
              ButtonSegment(value: 7, label: Text('7 days')),
            ],
            selected: {controller.rangeDays.value},
            onSelectionChanged: (values) {
              if (values.isNotEmpty) controller.setRangeDays(values.first);
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${controller.rangeDays.value == 1 ? 'Today' : 'Last 7 days'} · '
            '${formatDurationMs(controller.rangeTotalMs)} total',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (controller.appBreakdown.isEmpty)
            const Text('No per-app usage in this range.')
          else
            ...controller.appBreakdown.map(
              (stat) => _UsageBar(stat: stat, maxMs: controller.maxAppTotalMs),
            ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context) {
    final status = controller.currentStatus;
    return SectionCard(
      title: 'Screen-time policy',
      subtitle: 'Daily limit, bedtime and device acknowledgement',
      trailing: status == null
          ? null
          : StatusChip(label: status.label, tone: policyTone(status)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.policyStateText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (controller.awaitingAcknowledgement) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.hourglass_top,
              title: 'Pending device acknowledgement',
              message:
                  'This version is saved on the server but the child device has not applied it. '
                  'The limit and bedtime are not active yet.',
            ),
          ],
          if (controller.currentStatus == PolicyEnforcementStatus.enforced) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.success,
              icon: Icons.verified_outlined,
              message:
                  'The device acknowledged this policy version. It must keep Usage Access and the '
                  'guardian service running for limits to be enforced.',
            ),
          ],
          if (controller.currentStatus == PolicyEnforcementStatus.failed) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Enforcement failed',
              message: controller.currentPolicy?.lastError ??
                  'The device reported a failure without an explanation.',
            ),
          ],
          if (controller.currentStatus ==
              PolicyEnforcementStatus.unsupported) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.block,
              title: 'Not supported on this device',
              message:
                  'The device refused this policy. Screen-time enforcement depends on device support and permissions.',
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Daily screen-time limit',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Decrease limit',
                onPressed: controller.hasLimit
                    ? () => controller.adjustDailyLimit(-15)
                    : () => controller.setDailyLimit(60),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  controller.hasLimit
                      ? formatMinutes(controller.dailyLimitMinutes.value!)
                      : 'No daily limit',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Increase limit',
                onPressed: () => controller.adjustDailyLimit(15),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (controller.hasLimit)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.clearDailyLimit,
                child: const Text('Remove limit'),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Bedtime',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            controller.hasBedtime
                ? '${formatTimeOfDayMinutes(controller.bedtimeStartMinutes.value!)} – '
                    '${formatTimeOfDayMinutes(controller.bedtimeEndMinutes.value!)}'
                    '${controller.bedtimeEndMinutes.value! <= controller.bedtimeStartMinutes.value! ? ' (crosses midnight)' : ''}'
                : 'No bedtime window set.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickBedtime(context, start: true),
                  child: const Text('Set start'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickBedtime(context, start: false),
                  child: const Text('Set end'),
                ),
              ),
            ],
          ),
          if (controller.hasBedtime)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.clearBedtime,
                child: const Text('Clear bedtime'),
              ),
            ),
          if (controller.validationMessage.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              controller.validationMessage.value,
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          if (controller.saveError.value != null) ...[
            const SizedBox(height: 8),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not save the policy',
              message: controller.saveError.value!.message,
            ),
          ],
          if (controller.statusMessage.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoBanner(
              tone: BannerTone.info,
              icon: Icons.info_outline,
              message: controller.statusMessage.value,
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.refreshPolicy,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh policy state'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBedtime(BuildContext context, {required bool start}) async {
    final current = start
        ? controller.bedtimeStartMinutes.value
        : controller.bedtimeEndMinutes.value;
    final initial = current == null
        ? (start ? const TimeOfDay(hour: 21, minute: 0) : const TimeOfDay(hour: 7, minute: 0))
        : TimeOfDay(hour: current ~/ 60, minute: current % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (start) {
      controller.setBedtimeStart(minutes);
    } else {
      controller.setBedtimeEnd(minutes);
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.stat, required this.maxMs});

  final UsageStat stat;
  final int maxMs;

  @override
  Widget build(BuildContext context) {
    final fraction = maxMs <= 0
        ? 0.0
        : (stat.totalMs / maxMs).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(stat.label)),
              Text(
                formatDurationMs(stat.totalMs),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
          ),
          if (stat.lastUsedAt != null)
            Text(
              'Last used ${relativeTime(stat.lastUsedAt)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}
