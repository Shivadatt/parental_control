import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import 'parent_settings_controller.dart';

class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.controller});

  final ParentSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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
                            'Verify your email to use parent actions. The server '
                            'rejects unverified accounts for Edge Function calls.',
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
              title: 'Privacy and retention',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyValueRow(
                    label: 'Location retention',
                    value: controller.retention.value == null
                        ? 'Unknown'
                        : '${controller.retention.value!.locationRetentionDays} days',
                  ),
                  KeyValueRow(
                    label: 'Usage retention',
                    value: controller.retention.value == null
                        ? 'Unknown'
                        : '${controller.retention.value!.usageRetentionDays} days',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Retention is enforced by the server. Audit history is '
                    'append-only.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
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
