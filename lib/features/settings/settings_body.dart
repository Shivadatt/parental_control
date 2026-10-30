import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import 'delete_account_dialog.dart';
import 'export_result_dialog.dart';
import 'parent_settings_controller.dart';

class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.controller});

  final ParentSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final retention = controller.retentionReport.value;
      final windows = controller.retentionWindows;
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (controller.actionError.value != null)
            PageSection(
              child: InfoBanner(
                tone: BannerTone.danger,
                title: 'Action failed',
                message: controller.actionError.value!.message,
              ),
            ),
          PageSection(
            child: SectionCard(
              title: 'Account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyValueRow(
                    label: 'Email',
                    value: controller.email.value.isEmpty
                        ? 'Unknown'
                        : controller.email.value,
                  ),
                  KeyValueRow(
                    label: 'Display name',
                    value: controller.displayName.value,
                  ),
                  KeyValueRow(label: 'Role', value: controller.roleLabel.value),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Email verification',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      StatusChip(
                        label: controller.emailVerified.value
                            ? 'Verified'
                            : 'Not verified',
                        tone: controller.emailVerified.value
                            ? StatusTone.success
                            : StatusTone.warning,
                      ),
                    ],
                  ),
                  if (!controller.emailVerified.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: InfoBanner(
                        tone: BannerTone.warning,
                        message:
                            'Verify your email to use parent actions. Most Edge '
                            'Function calls reject unverified accounts; privacy '
                            'export and account deletion still work.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          PageSection(
            child: SectionCard(
              title: 'Family',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyValueRow(
                    label: 'Family name',
                    value: controller.familyName.value,
                  ),
                  KeyValueRow(
                    label: 'Your family role',
                    value: controller.familyRole.value,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Family details',
                    icon: Icons.family_restroom,
                    outlined: true,
                    onPressed: controller.familyId == null
                        ? null
                        : () => Get.toNamed(
                              AppRoutes.family,
                              arguments: {'familyId': controller.familyId!},
                            ),
                  ),
                ],
              ),
            ),
          ),
          PageSection(
            child: SectionCard(
              title: 'Notifications and reminders',
              subtitle:
                  'These switches are local to this phone only. They do not '
                  'change server authorization, alert creation, or what the child '
                  'device reports.',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show local notifications'),
                    subtitle: const Text(
                      'A local reminder preference. Safety alerts are still '
                      'recorded by the server.',
                    ),
                    value: controller.notificationsEnabled.value,
                    onChanged: controller.isSavingNotifications.value
                        ? null
                        : controller.setNotificationsEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Location sharing reminder'),
                    subtitle: const Text(
                      'A local reminder only. It does not grant or revoke location '
                      'permission on any device.',
                    ),
                    value: controller.locationReminderEnabled.value,
                    onChanged: controller.isSavingLocationReminder.value
                        ? null
                        : controller.setLocationReminderEnabled,
                  ),
                ],
              ),
            ),
          ),
          PageSection(
            child: SectionCard(
              title: 'Privacy & data',
              subtitle:
                  'Export or delete your own account, and see the retention '
                  'windows the server enforces.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (windows.isEmpty)
                    const Text('No family is linked to this account yet.')
                  else
                    for (final window in windows) ...[
                      KeyValueRow(
                        label: '${window.familyName}: location retention',
                        value: '${window.locationDays} days',
                      ),
                      KeyValueRow(
                        label: '${window.familyName}: usage retention',
                        value: '${window.usageDays} days',
                      ),
                      if (retention != null)
                        KeyValueRow(
                          label: '${window.familyName}: older than the window',
                          value:
                              '${window.locationEventsOlderThanWindow} location '
                              'events · ${window.usageDaysOlderThanWindow} usage days',
                        ),
                    ],
                  const SizedBox(height: 8),
                  if (controller.isLoadingRetention.value)
                    const Row(
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading retention report…'),
                      ],
                    )
                  else if (controller.retentionError.value != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Retention report unavailable: '
                            '${controller.retentionError.value!.message}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.isLoadingRetention.value
                              ? null
                              : () => controller.loadRetentionReport(),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else
                    KeyValueRow(
                      label: 'Last retention sweep',
                      value: retention?.lastSweepAt == null
                          ? 'Not recorded yet'
                          : formatDateTime(retention!.lastSweepAt),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'The sweep deletes signaling rows after 7 days and audit '
                    'rows after 365 days; location and usage follow each '
                    'family’s windows above. It runs from the scheduled cron '
                    'function, not on this phone.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Export my data',
                    icon: Icons.download_outlined,
                    outlined: true,
                    isLoading: controller.isExporting.value,
                    onPressed: controller.isExporting.value ||
                            controller.isDeletingAccount.value
                        ? null
                        : () => _exportData(context),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Downloads your profile, family membership, devices, and '
                    'your own location, usage, alert and audit rows as JSON. '
                    'This device saves a copy in app storage and can copy the '
                    'JSON to the clipboard.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (controller.accountDeletionBlockedReason.value.isNotEmpty) ...[
                    InfoBanner(
                      tone: BannerTone.danger,
                      title: 'Account deletion is blocked',
                      message: controller.accountDeletionBlockedReason.value,
                    ),
                    const SizedBox(height: 10),
                  ],
                  AppButton(
                    label: 'Delete my account',
                    icon: Icons.delete_forever_outlined,
                    outlined: true,
                    destructive: true,
                    isLoading: controller.isDeletingAccount.value,
                    onPressed: controller.isDeletingAccount.value ||
                            controller.isExporting.value
                        ? null
                        : () => _confirmDeleteAccount(context),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Deleting requires two confirmations: a warning, then '
                    'typing DELETE and your account email. Other members’ data '
                    'is never deleted; an owner with remaining members or '
                    'active devices is refused.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Manage retention and audit log',
                    icon: Icons.policy_outlined,
                    outlined: true,
                    onPressed: controller.familyId == null
                        ? null
                        : () => Get.toNamed(
                              AppRoutes.auditLogs,
                              arguments: {'familyId': controller.familyId!},
                            ),
                  ),
                ],
              ),
            ),
          ),
          PageSection(
            child: _DevicePermissionsCard(controller: controller),
          ),
          const PageSection(
            child: SectionCard(
              title: 'Security notes',
              child: Text(
                'Device credentials and TURN secrets are never displayed in this '
                'app; they are held by the server and the platform keystore. '
                'Local toggles and cached roles never grant access on their own. '
                'Row-level security and Edge Function caller checks decide what '
                'this account can read or change. Assistance sessions never '
                'record or capture the child’s screen.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
          PageSection(
            child: SectionCard(
              title: 'App',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyValueRow(
                    label: 'Version',
                    value: controller.isLoadingVersion.value
                        ? 'Loading…'
                        : controller.appVersion.value,
                  ),
                  const KeyValueRow(label: 'Application', value: 'Parent Control'),
                  const SizedBox(height: 8),
                  const Text(
                    'Backend URL and keys are compile-time configuration and are '
                    'not shown here.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          PageSection(
            child: AppButton(
              label: 'Sign out',
              icon: Icons.logout,
              destructive: true,
              outlined: true,
              isLoading: controller.isSigningOut.value,
              onPressed: controller.isSigningOut.value
                  ? null
                  : () => _confirmSignOut(context),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message:
          'This clears the local session and preferences, and stops the guardian '
          'service on this phone if it is running. Server data is not deleted.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.signOut();
  }

  Future<void> _exportData(BuildContext context) async {
    final result = await controller.exportMyData();
    if (result == null || !context.mounted) return;
    await showExportResultDialog(context, result);
  }

  /// Step 1 is a plain warning; step 2 requires typing DELETE and the email.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final understood = await ConfirmDialog.show(
      context,
      title: 'Delete your account?',
      message:
          'This is permanent. You will be asked to type DELETE and your account '
          'email next. Other family members’ data is never deleted.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!understood || !context.mounted) return;
    final request = await showDeleteAccountDialog(
      context,
      accountEmail: controller.email.value,
    );
    if (request == null) return;
    await controller.deleteAccount(
      confirm: request.confirm,
      email: request.email,
    );
  }
}

class _DevicePermissionsCard extends StatelessWidget {
  const _DevicePermissionsCard({required this.controller});

  final ParentSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final device = controller.activeDevice;
    return SectionCard(
      title: 'Device permissions',
      child: device == null
          ? const EmptyState(
              icon: Icons.phone_android,
              title: 'No device selected',
              message:
                  'Open a device from the Devices tab to see its reported '
                  'permission state and enforcement details.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyValueRow(label: 'Device', value: device.displayName),
                KeyValueRow(
                  label: 'Last reported',
                  value: device.lastSeenAt == null
                      ? 'Never'
                      : '${formatDateTime(device.lastSeenAt)} · '
                          '${relativeTime(device.lastSeenAt)}',
                ),
                const SizedBox(height: 4),
                PermissionStatusTile(
                  title: 'Location',
                  granted: device.locationGranted == true,
                  isUnknown: device.locationGranted == null,
                ),
                PermissionStatusTile(
                  title: 'Background location',
                  granted: device.backgroundLocationGranted == true,
                  isUnknown: device.backgroundLocationGranted == null,
                ),
                PermissionStatusTile(
                  title: 'Camera',
                  granted: device.cameraGranted == true,
                  isUnknown: device.cameraGranted == null,
                ),
                PermissionStatusTile(
                  title: 'Microphone',
                  granted: device.microphoneGranted == true,
                  isUnknown: device.microphoneGranted == null,
                ),
                PermissionStatusTile(
                  title: 'Notifications',
                  granted: device.notificationsGranted == true,
                  isUnknown: device.notificationsGranted == null,
                ),
                const SizedBox(height: 10),
                const Text(
                  'These values come from the child device’s last heartbeat. '
                  'Unknown means the device has not reported that permission.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Open device details',
                  icon: Icons.chevron_right,
                  outlined: true,
                  onPressed: () => Get.toNamed(
                    AppRoutes.deviceDetail,
                    arguments: {'deviceId': device.id},
                  ),
                ),
              ],
            ),
    );
  }
}
