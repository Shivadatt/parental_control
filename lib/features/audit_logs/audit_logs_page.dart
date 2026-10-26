import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/audit.dart';
import 'audit_logs_controller.dart';

class AuditLogsPage extends GetView<AuditLogsController> {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit & retention'),
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
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingState(label: 'Loading audit history…');
        }
        final fatalError = controller.error.value;
        if (fatalError != null) {
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
              const PageSection(
                child: SectionCard(
                  title: 'Append-only history',
                  child: Text(
                    'Audit events are written by the server and cannot be edited '
                    'or deleted from this app. Times are shown in your local '
                    'timezone.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ),
              if (!controller.canManage)
                PageSection(
                  child: InfoBanner(
                    tone: BannerTone.info,
                    title: 'Read-only',
                    message: controller.hasContext
                        ? 'Only the family owner can change retention or purge '
                            'historical data. The server enforces this.'
                        : 'No family was supplied, so retention controls are '
                            'unavailable.',
                  ),
                ),
              Obx(
                () => controller.actionError.value == null
                    ? const SizedBox.shrink()
                    : PageSection(
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          title: 'Action failed',
                          message: controller.actionError.value!.message,
                        ),
                      ),
              ),
              PageSection(
                child: _RetentionSection(controller: controller),
              ),
              if (controller.canManage)
                PageSection(
                  child: _PurgeSection(controller: controller),
                ),
              Obx(
                () => controller.lastPurgeCount.value == null
                    ? const SizedBox.shrink()
                    : PageSection(
                        child: InfoBanner(
                          tone: BannerTone.success,
                          title: 'Purge completed',
                          message:
                              'The server deleted '
                              '${controller.lastPurgeCount.value} record(s).',
                        ),
                      ),
              ),
              PageSection(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Events',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${controller.entries.length} shown',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (controller.entries.isEmpty)
                const PageSection(
                  child: SectionCard(
                    child: EmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'No audit events',
                      message:
                          'Actions such as pairing, policy changes, assistance '
                          'sessions, and retention updates appear here once the '
                          'server records them.',
                    ),
                  ),
                )
              else
                ...controller.entries.map(
                  (entry) => PageSection(child: _AuditEntryCard(entry: entry)),
                ),
              if (controller.hasMore.value)
                PageSection(
                  child: AppButton(
                    label: controller.isLoadingMore.value
                        ? 'Loading…'
                        : 'Load more',
                    icon: Icons.expand_more,
                    outlined: true,
                    isLoading: controller.isLoadingMore.value,
                    onPressed: controller.isLoadingMore.value
                        ? null
                        : () => controller.loadMore(),
                  ),
                ),
              if (controller.atPaginationCap)
                const PageSection(
                  child: Text(
                    'Showing up to 500 recent events. Older events remain on the '
                    'server until its retention policy removes them.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _RetentionSection extends StatelessWidget {
  const _RetentionSection({required this.controller});

  final AuditLogsController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Retention',
      subtitle:
          'How long the server keeps location and usage history for this family.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Column(
              children: [
                KeyValueRow(
                  label: 'Location',
                  value: controller.locationDays.value == null
                      ? 'Unknown'
                      : '${controller.locationDays.value} days',
                ),
                KeyValueRow(
                  label: 'Usage',
                  value: controller.usageDays.value == null
                      ? 'Unknown'
                      : '${controller.usageDays.value} days',
                ),
              ],
            ),
          ),
          if (controller.canManage) ...[
            const SizedBox(height: 12),
            _RetentionForm(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _RetentionForm extends StatefulWidget {
  const _RetentionForm({required this.controller});

  final AuditLogsController controller;

  @override
  State<_RetentionForm> createState() => _RetentionFormState();
}

class _RetentionFormState extends State<_RetentionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _location;
  late final TextEditingController _usage;

  @override
  void initState() {
    super.initState();
    _location = TextEditingController(
      text: widget.controller.locationDays.value?.toString() ?? '',
    );
    _usage = TextEditingController(
      text: widget.controller.usageDays.value?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _location.dispose();
    _usage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await widget.controller.saveRetention(
      location: int.parse(_location.text.trim()),
      usage: int.parse(_usage.text.trim()),
    );
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retention saved on the server.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppTextField(
            controller: _location,
            label: 'Location retention (days)',
            hint: '1 to 365',
            keyboardType: TextInputType.number,
            validator: widget.controller.validateLocationDays,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _usage,
            label: 'Usage retention (days)',
            hint: '1 to 730',
            keyboardType: TextInputType.number,
            validator: widget.controller.validateUsageDays,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          Obx(
            () => AppButton(
              label: 'Save retention',
              icon: Icons.save_outlined,
              outlined: true,
              isLoading: widget.controller.isSavingRetention.value,
              onPressed: widget.controller.isSavingRetention.value
                  ? null
                  : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurgeSection extends StatefulWidget {
  const _PurgeSection({required this.controller});

  final AuditLogsController controller;

  @override
  State<_PurgeSection> createState() => _PurgeSectionState();
}

class _PurgeSectionState extends State<_PurgeSection> {
  final _formKey = GlobalKey<FormState>();
  final _days = TextEditingController(text: '30');

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _purge() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final days = int.parse(_days.text.trim());
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Purge data older than $days days?',
      message:
          'The server will delete matching location, usage, and related '
          'historical records for this family. This cannot be undone. The audit '
          'log itself is append-only and is not purged by this action.',
      confirmLabel: 'Purge',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.controller.purgeOldData(days);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Purge old data',
      subtitle:
          'Request server-side deletion of history older than a chosen number of '
          'days. Only the server-reported count is shown.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              controller: _days,
              label: 'Delete data older than (days)',
              keyboardType: TextInputType.number,
              validator: widget.controller.validatePurgeDays,
            ),
            const SizedBox(height: 12),
            Obx(
              () => AppButton(
                label: 'Purge old data',
                icon: Icons.delete_sweep_outlined,
                destructive: true,
                outlined: true,
                isLoading: widget.controller.isPurging.value,
                onPressed: widget.controller.isPurging.value ? null : _purge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.readableEvent,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyValueRow(
            label: 'Actor',
            value: entry.actorDisplayName ?? 'Unknown actor',
          ),
          KeyValueRow(
            label: 'Device',
            value: entry.deviceId == null || entry.deviceId!.isEmpty
                ? 'Not device-specific'
                : _shortId(entry.deviceId!),
          ),
          KeyValueRow(
            label: 'Time',
            value:
                '${formatDateTime(entry.createdAt)} · ${relativeTime(entry.createdAt)}',
          ),
          if (entry.targetType != null)
            KeyValueRow(
              label: 'Target',
              value: entry.targetId == null || entry.targetId!.isEmpty
                  ? entry.targetType!
                  : '${entry.targetType} · ${_shortId(entry.targetId!)}',
            ),
        ],
      ),
    );
  }

  static String _shortId(String value) =>
      value.length <= 12 ? value : '${value.substring(0, 8)}…';
}
