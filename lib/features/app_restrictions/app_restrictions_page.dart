import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class AppRestrictionsPage extends StatefulWidget {
  const AppRestrictionsPage({super.key});

  @override
  State<AppRestrictionsPage> createState() => _AppRestrictionsPageState();
}

class _AppRestrictionsPageState extends State<AppRestrictionsPage> {
  late final AppRestrictionsController controller =
      Get.find<AppRestrictionsController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
  }

  void _applySearch() => controller.setSearchQuery(_searchController.text);

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final device = controller.device.value;
      return Scaffold(
        appBar: AppBar(
          title: const Text('App restrictions'),
          actions: [
            IconButton(
              tooltip: 'Refresh restrictions',
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
      return const LoadingState(label: 'Loading app restrictions…');
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
              message:
                  'Showing the last loaded policy and app snapshot. Saving needs a connection.',
              actionLabel: 'Try again',
              onAction: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (controller.error.value != null) ...[
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not load app restrictions',
              message: controller.error.value!.message,
              actionLabel: 'Retry',
              onAction: controller.load,
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: device.displayName,
            subtitle: 'Enforcement: ${enforcementModeLabel(device.enforcementMode)}',
            child: Text(
              device.isRevoked
                  ? 'This device is revoked. Restrictions can no longer reach it.'
                  : 'Restrictions are applied by the child device after it acknowledges a policy.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ),
          if (device.isRevoked) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              tone: BannerTone.danger,
              icon: Icons.block,
              title: 'Device revoked',
              message:
                  'The credential was revoked, so no policy can be delivered. Link the phone again first.',
            ),
          ],
          if (device.enforcementMode != 'device_owner') ...[
            const SizedBox(height: 12),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.admin_panel_settings_outlined,
              title: 'App suspension unsupported on this device',
              message:
                  'Android only allows setPackagesSuspended when Parent Control is the Device Owner. '
                  'On this device a saved policy can be acknowledged but apps cannot be suspended.',
            ),
          ],
          const SizedBox(height: 12),
          const InfoBanner(
            tone: BannerTone.info,
            icon: Icons.info_outline,
            title: 'A database flag does not block an app',
            message:
                'Saving only stores the policy and queues a command. The app becomes restricted only after '
                'the child device acknowledges and applies it. Nothing on this screen claims an app is '
                'blocked before that acknowledgement.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(),
          const SizedBox(height: 12),
          _buildAppsSection(context),
          if (controller.instagramAvailable) ...[
            const SizedBox(height: 12),
            _buildInstagramCard(),
          ],
          const SizedBox(height: 12),
          _buildBlockAllCard(context),
          const SizedBox(height: 12),
          _buildBlockedList(context),
          const SizedBox(height: 12),
          _buildAllowedList(context),
          if (controller.validationMessage.value.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Check your selection',
              message: controller.validationMessage.value,
            ),
          ],
          if (controller.blockedSystemApps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.warning_amber,
              title: 'System apps selected',
              message:
                  'Android may refuse to suspend system or critical apps (launcher, settings, system UI). '
                  'They can be saved here, but enforcement can fail on the device.',
            ),
          ],
          if (controller.blockedUnreportedPackages.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.help_outline,
              title: 'Packages not present in the device snapshot',
              message:
                  '${controller.blockedUnreportedPackages.length} selected package(s) were not reported '
                  'by this device. Their existence is unconfirmed.',
            ),
          ],
          if (controller.saveError.value != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not save the policy',
              message: controller.saveError.value!.message,
            ),
          ],
          if (controller.syncError.value != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Could not request a sync',
              message: controller.syncError.value!.message,
            ),
          ],
          if (controller.syncMessage.value.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: BannerTone.success,
              icon: Icons.sync,
              message: controller.syncMessage.value,
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Save restrictions',
            icon: Icons.save_outlined,
            isLoading: controller.saving.value,
            onPressed: device.isRevoked || !controller.policyReady.value
                ? null
                : controller.savePolicy,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Request device sync',
            icon: Icons.sync,
            outlined: true,
            isLoading: controller.requestingSync.value,
            onPressed: device.isRevoked || !controller.policyReady.value
                ? null
                : controller.requestSync,
          ),
          const SizedBox(height: 10),
          Text(
            'The device applies the saved policy on its next check-in. '
            'Requests expire server-side; you can send a new sync request.',
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

  Widget _buildPolicyCard() {
    final status = controller.currentStatus;
    final proven = controller.enforcementProven;
    return SectionCard(
      title: 'Policy state',
      subtitle: 'Server version and device acknowledgement',
      trailing: status == null
          ? null
          : (status == PolicyEnforcementStatus.enforced && !proven
              ? const StatusChip(
                  label: 'Unverified',
                  tone: StatusTone.warning,
                )
              : StatusChip(label: status.label, tone: policyTone(status))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Version',
            value: controller.currentVersion?.toString() ?? 'No version yet',
          ),
          if (controller.appliedCountsText != null) ...[
            const SizedBox(height: 4),
            KeyValueRow(
              label: 'Applied apps',
              value: controller.appliedCountsText!,
            ),
          ],
          const SizedBox(height: 4),
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
                  'The device has not confirmed this policy. No app is blocked by this selection yet.',
            ),
          ],
          if (controller.enforcementUnsupported) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.block,
              title: 'Unsupported on this device',
              message: controller.enforcementReport.value?.isUnsupported == true
                  ? '${PolicyEnforcementReport.unsupportedMessage} '
                      'The device reported 0 applied apps, so no restriction is active.'
                  : 'The device refused enforcement. Fully managed Device Owner provisioning is required to suspend apps.',
            ),
          ],
          if (status == PolicyEnforcementStatus.enforced && proven) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.success,
              icon: Icons.verified_outlined,
              message:
                  '${controller.appliedCountsText}. DevicePolicyManager confirmed every selected app is suspended.',
            ),
          ],
          if (status == PolicyEnforcementStatus.enforced && !proven) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.help_outline,
              title: 'Enforcement not proven by counts',
              message:
                  'This policy is marked enforced, but the device did not report how many apps it suspended. '
                  'Treat the selection as unverified until a new acknowledgement includes applied counts.',
            ),
          ],
          if (status == PolicyEnforcementStatus.failed) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.danger,
              title: 'Enforcement failed',
              message: controller.currentPolicy?.lastError ??
                  'The device reported a failure without an explanation.',
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.refreshPolicy,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh state'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsSection(BuildContext context) {
    return SectionCard(
      title: 'Installed apps',
      subtitle: controller.appsSnapshotMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.appsError.value != null)
            InfoBanner(
              tone: BannerTone.warning,
              title: 'App snapshot unavailable',
              message: controller.appsError.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refresh,
            )
          else if (controller.reportedApps.isEmpty)
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.help_outline,
              title: 'No app snapshot reported',
              message:
                  'The device has not reported its installed apps. This screen cannot list installed apps '
                  'until the child device uploads a snapshot; it does not mean the phone has no apps.',
            )
          else ...[
            AppTextField(
              controller: _searchController,
              label: 'Search installed apps',
              hint: 'App name or package',
              prefixIcon: Icons.search,
              onFieldSubmitted: controller.setSearchQuery,
            ),
            const SizedBox(height: 8),
            ...controller.filteredApps.map(
              (app) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(app.label),
                subtitle: Text(
                  '${app.packageName}${app.isSystem ? ' · System app' : ''}',
                ),
                trailing: Switch(
                  value: controller.isBlocked(app.packageName),
                  onChanged: (value) =>
                      controller.toggleAppBlocked(app, value),
                ),
              ),
            ),
            if (controller.filteredAppsTruncated)
              Text(
                'Showing the first matches. Refine the search to see more apps.',
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

  Widget _buildInstagramCard() {
    return SectionCard(
      title: 'Instagram',
      subtitle: 'Detected in the device app snapshot',
      child: Row(
        children: [
          const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.instagramBlocked
                  ? 'Instagram is in the blocked list. It becomes restricted only after device acknowledgement.'
                  : 'Add Instagram (com.instagram.android) to the blocked list with one tap.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          if (controller.instagramBlocked)
            const StatusChip(label: 'Selected', tone: StatusTone.info)
          else
            TextButton(
              onPressed: controller.selectInstagram,
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockAllCard(BuildContext context) {
    return SectionCard(
      title: 'Block all except allowed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.blockAllExceptAllowed.value,
            onChanged: controller.setBlockAllExceptAllowed,
            title: const Text('Block every app except the allowed list'),
            subtitle: const Text(
              'The allowed list must include launchers and essential apps or the phone may become unusable.',
            ),
          ),
          if (controller.blockAllExceptAllowed.value) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.warning_amber,
              title: 'Strict setting',
              message:
                  'After the device acknowledges, every app not on the allowed list is a candidate for blocking. '
                  'System-critical apps are refused by Android and may leave gaps.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAllowedApp(context),
                icon: const Icon(Icons.add),
                label: const Text('Add allowed app'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedList(BuildContext context) {
    return SectionCard(
      title: 'Blocked apps',
      subtitle:
          'A selection is not enforcement. Apps become restricted only after the device acknowledges.',
      child: controller.blockedRules.isEmpty
          ? Text(
              'No apps selected for blocking.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            )
          : Column(
              children: controller.blockedRules
                  .map(
                    (rule) => _BlockedRuleTile(
                      controller: controller,
                      rule: rule,
                      onAddWindow: () =>
                          _editWindow(context, rule.packageName, null),
                      onEditWindow: (index) => _editWindow(
                        context,
                        rule.packageName,
                        index,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildAllowedList(BuildContext context) {
    return SectionCard(
      title: 'Allowed apps',
      subtitle:
          'Only used when "block all except allowed" is on. System-critical apps still need to stay available.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.allowedPackages.isEmpty)
            Text(
              'No apps are allowed yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: controller.allowedPackages
                  .map(
                    (packageName) => InputChip(
                      label: Text(controller.labelFor(packageName)),
                      onDeleted: () => controller.setAllowed(packageName, false),
                    ),
                  )
                  .toList(growable: false),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _pickAllowedApp(context),
              icon: const Icon(Icons.add),
              label: const Text('Add allowed app'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAllowedApp(BuildContext context) async {
    if (controller.reportedApps.isEmpty) {
      controller.validationMessage.value =
          'No installed-app snapshot is available, so allowed apps cannot be picked yet.';
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _AllowedAppDialog(
        apps: controller.reportedApps,
        blocked: controller.blockedRules
            .map((rule) => rule.packageName)
            .toSet(),
        allowed: controller.allowedPackages.toSet(),
      ),
    );
    if (selected == null) return;
    controller.setAllowed(selected, true);
  }

  Future<void> _editWindow(
    BuildContext context,
    String packageName,
    int? index,
  ) async {
    final existing =
        index == null ? null : controller.windowsFor(packageName)[index];
    final window = await showDialog<ScheduleWindow>(
      context: context,
      builder: (_) => _ScheduleWindowDialog(initial: existing),
    );
    if (window == null) return;
    if (index == null) {
      controller.addWindow(packageName, window);
    } else {
      controller.updateWindow(packageName, index, window);
    }
  }
}

class _BlockedRuleTile extends StatelessWidget {
  const _BlockedRuleTile({
    required this.controller,
    required this.rule,
    required this.onAddWindow,
    required this.onEditWindow,
  });

  final AppRestrictionsController controller;
  final AppRule rule;
  final VoidCallback onAddWindow;
  final ValueChanged<int> onEditWindow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
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
                      rule.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      rule.packageName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from blocked apps',
                onPressed: () =>
                    controller.removeBlockedPackage(rule.packageName),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (rule.windows.isEmpty)
            Text(
              'No schedule — blocked all day once enforced.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rule.windows.asMap().entries.map((entry) {
                return InputChip(
                  label: Text(
                    '${_daysLabel(entry.value.daysOfWeek)} · ${entry.value.label}',
                  ),
                  onPressed: () => onEditWindow(entry.key),
                  onDeleted: () =>
                      controller.removeWindow(rule.packageName, entry.key),
                );
              }).toList(growable: false),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAddWindow,
              icon: const Icon(Icons.schedule),
              label: const Text('Add schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllowedAppDialog extends StatefulWidget {
  const _AllowedAppDialog({
    required this.apps,
    required this.blocked,
    required this.allowed,
  });

  final List<InstalledApp> apps;
  final Set<String> blocked;
  final Set<String> allowed;

  @override
  State<_AllowedAppDialog> createState() => _AllowedAppDialogState();
}

class _AllowedAppDialogState extends State<_AllowedAppDialog> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _query.removeListener(_refresh);
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final candidates = widget.apps.where((app) {
      if (widget.allowed.contains(app.packageName)) return false;
      if (query.isEmpty) return true;
      return app.label.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList(growable: false);

    return AlertDialog(
      title: const Text('Allow an app'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            AppTextField(
              controller: _query,
              label: 'Search apps',
              prefixIcon: Icons.search,
              onFieldSubmitted: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(
                      child: Text('No matching apps in the device snapshot.'),
                    )
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final app = candidates[index];
                        return ListTile(
                          title: Text(app.label),
                          subtitle: Text(
                            '${app.packageName}'
                            '${widget.blocked.contains(app.packageName) ? ' · currently blocked' : ''}',
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(app.packageName),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ScheduleWindowDialog extends StatefulWidget {
  const _ScheduleWindowDialog({this.initial});

  final ScheduleWindow? initial;

  @override
  State<_ScheduleWindowDialog> createState() => _ScheduleWindowDialogState();
}

class _ScheduleWindowDialogState extends State<_ScheduleWindowDialog> {
  late final Set<int> _days = {
    ...(widget.initial?.daysOfWeek ?? const [1, 2, 3, 4, 5]),
  };
  late int _start = widget.initial?.startMinutes ?? 21 * 60;
  late int _end = widget.initial?.endMinutes ?? 7 * 60;
  String? _error;

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(start ? _start : _end),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked.hour * 60 + picked.minute;
      } else {
        _end = picked.hour * 60 + picked.minute;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add schedule' : 'Edit schedule'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Days'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (index) {
                final day = index + 1;
                return FilterChip(
                  label: Text(_dayLabel(day)),
                  selected: _days.contains(day),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(start: true),
                    child: Text('Start ${_timeLabel(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(start: false),
                    child: Text('End ${_timeLabel(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _end <= _start
                  ? 'The end time is at or before the start, so this window spans midnight.'
                  : 'The window ends on the same day.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_days.isEmpty) {
              setState(() => _error = 'Choose at least one day.');
              return;
            }
            if (_start == _end) {
              setState(() => _error = 'Start and end times must differ.');
              return;
            }
            Navigator.of(context).pop(
              ScheduleWindow(
                daysOfWeek: _days.toList(growable: false)..sort(),
                startMinutes: _start,
                endMinutes: _end,
              ),
            );
          },
          child: const Text('Save window'),
        ),
      ],
    );
  }
}

TimeOfDay _timeOfDay(int minutes) {
  final normalized = ((minutes % 1440) + 1440) % 1440;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

String _timeLabel(int minutes) {
  final time = _timeOfDay(minutes);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

String _dayLabel(int day) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (day < 1 || day > 7) return '';
  return labels[day - 1];
}

String _daysLabel(List<int> days) {
  if (days.length == 7) return 'Every day';
  final sorted = [...days]..sort();
  return sorted.map(_dayLabel).join(', ');
}
