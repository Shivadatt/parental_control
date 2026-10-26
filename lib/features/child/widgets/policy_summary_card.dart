import 'package:flutter/material.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/features/child/models/child_enforcement.dart';

/// Read-only summary of the newest policy downloaded to this phone.
///
/// When [enforcementApps] is provided, each entry carries the result of a
/// DevicePolicyManager check. Without it, this card only describes what was
/// configured and never says an app is blocked.
class ChildPolicySummaryCard extends StatelessWidget {
  const ChildPolicySummaryCard({
    super.key,
    required this.policy,
    this.enforcementApps,
    this.maxListedApps = 50,
  });

  final DevicePolicy policy;
  final List<ChildEnforcedApp>? enforcementApps;
  final int maxListedApps;

  bool get _showVerification => enforcementApps != null;

  List<ChildEnforcedApp> get _apps {
    final verified = enforcementApps;
    if (verified != null) return verified;
    final payload = policy.payload;
    final byPackage = <String, ChildEnforcedApp>{};
    for (final packageName in payload.blockedPackages) {
      byPackage[packageName] = ChildEnforcedApp(
        packageName: packageName,
        label: packageName,
        isScheduleRule: false,
      );
    }
    for (final rule in payload.appRules.where((item) => item.blocked)) {
      byPackage[rule.packageName] = ChildEnforcedApp(
        packageName: rule.packageName,
        label: rule.label,
        isScheduleRule: rule.windows.isNotEmpty,
        rule: rule,
      );
    }
    final result = byPackage.values.toList();
    result.sort(
      (left, right) =>
          left.label.toLowerCase().compareTo(right.label.toLowerCase()),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final payload = policy.payload;
    final apps = _apps;
    final visibleApps = apps.take(maxListedApps).toList(growable: false);
    final notified = apps.length - visibleApps.length;
    return SectionCard(
      title: 'Rules from your guardian',
      subtitle:
          'Version ${policy.version} · received ${formatDateTime(policy.createdAt)}',
      trailing: StatusChip(
        label: policy.status.label,
        tone: _statusTone(policy.status),
        icon: policy.status == PolicyEnforcementStatus.enforced
            ? Icons.shield_outlined
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'App blocking',
            value: payload.enforceAppBlocks ? 'On' : 'Off in these rules',
          ),
          KeyValueRow(
            label: 'Mode',
            value: payload.blockAllExceptAllowed
                ? 'All apps except ${payload.allowedPackages.length} allowed'
                : 'Selected apps only',
          ),
          KeyValueRow(
            label: 'Named blocked apps',
            value: apps.isEmpty
                ? 'None named'
                : '${apps.length} app${apps.length == 1 ? '' : 's'}',
          ),
          if (payload.dailyScreenTimeLimitMinutes != null)
            KeyValueRow(
              label: 'Daily screen time',
              value: formatMinutes(payload.dailyScreenTimeLimitMinutes!),
            ),
          if (payload.hasBedtime)
            KeyValueRow(
              label: 'Bedtime',
              value:
                  '${formatTimeOfDayMinutes(payload.bedtimeStartMinutes!)} – ${formatTimeOfDayMinutes(payload.bedtimeEndMinutes!)}',
            ),
          if (policy.lastError != null && policy.lastError!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InfoBanner(
                tone: BannerTone.warning,
                title: 'Last device report',
                message: policy.lastError!,
              ),
            ),
          if (!payload.enforceAppBlocks)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: InfoBanner(
                tone: BannerTone.info,
                message:
                    'App blocking is disabled in the newest rules, so no apps are suspended for the named blocks.',
              ),
            ),
          if (payload.dailyScreenTimeLimitMinutes != null || payload.hasBedtime)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: InfoBanner(
                tone: BannerTone.info,
                message:
                    'Daily screen-time limits and bedtime are shown for information only. This Android build enforces app blocks and their schedules, not a system-wide time limit.',
              ),
            ),
          if (payload.blockAllExceptAllowed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Every installed app outside the allowed list is configured as blocked. '
                'The list below shows the apps this screen can name.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted, height: 1.4),
              ),
            ),
          if (visibleApps.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final app in visibleApps) ...[
              const Divider(height: 20),
              _AppRow(app: app, showVerification: _showVerification),
            ],
          ],
          if (notified > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing first $maxListedApps of ${apps.length} apps.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  static StatusTone _statusTone(PolicyEnforcementStatus status) {
    switch (status) {
      case PolicyEnforcementStatus.enforced:
        return StatusTone.success;
      case PolicyEnforcementStatus.failed:
        return StatusTone.danger;
      case PolicyEnforcementStatus.unsupported:
        return StatusTone.neutral;
      case PolicyEnforcementStatus.pending:
        return StatusTone.warning;
    }
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.showVerification});

  final ChildEnforcedApp app;
  final bool showVerification;

  @override
  Widget build(BuildContext context) {
    final rule = app.rule;
    final schedule = rule == null || rule.windows.isEmpty
        ? 'Always, while app blocking is on'
        : rule.windows
            .map((window) =>
                '${_daysLabel(window.daysOfWeek)} ${window.label}')
            .join('\n');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.apps, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                app.packageName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 3),
              Text(
                schedule,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted, height: 1.35),
              ),
              if (app.isScheduleRule)
                const Text(
                  'Scheduled app rule',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
            ],
          ),
        ),
        if (showVerification) ...[
          const SizedBox(width: 8),
          StatusChip(
            label: app.statusLabel,
            tone: app.suspended == null
                ? StatusTone.neutral
                : (app.isConfirmed ? StatusTone.success : StatusTone.warning),
          ),
        ],
      ],
    );
  }

  static String _daysLabel(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'No days';
    const names = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final sorted = days.toList()..sort();
    return sorted.map((day) => names[day] ?? '?').join(', ');
  }
}
