import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/widgets/media_self_test_sheet.dart';

class ChildSettingsTab extends GetView<ChildShellController> {
  const ChildSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('This phone settings'),
          actions: [
            IconButton(
              tooltip: 'Refresh settings',
              onPressed: controller.isLoading.value
                  ? null
                  : controller.refreshCapabilities,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (controller.actionError.value != null) ...[
              InfoBanner(
                tone: BannerTone.danger,
                title: 'Action failed',
                message: controller.actionError.value!.message,
                actionLabel: 'Dismiss',
                onAction: controller.clearNotices,
              ),
              const SizedBox(height: 12),
            ],
            if (controller.actionMessage.value != null) ...[
              InfoBanner(
                tone: BannerTone.success,
                title: 'Done',
                message: controller.actionMessage.value!,
                actionLabel: 'Dismiss',
                onAction: controller.clearNotices,
              ),
              const SizedBox(height: 12),
            ],
            _accountCard(),
            const SizedBox(height: 12),
            _permissionsCard(context),
            if (controller.isEnrolled) ...[
              const SizedBox(height: 12),
              _mediaTestCard(context),
            ],
            const SizedBox(height: 12),
            _enforcementCard(),
            const SizedBox(height: 12),
            _backgroundCard(),
            const SizedBox(height: 12),
            _actionsCard(context),
            const SizedBox(height: 16),
            Text(
              'This app never records audio or video, takes screenshots, reads '
              'messages, or captures passwords. Camera and microphone are used '
              'only during an assistance session you accept and start, and a '
              'visible notification stays on while background services run.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard() {
    return SectionCard(
      title: 'Account',
      child: Column(
        children: [
          KeyValueRow(label: 'Name', value: controller.displayName),
          KeyValueRow(
            label: 'Email',
            value: controller.email.isEmpty ? 'Unknown' : controller.email,
          ),
          KeyValueRow(
            label: 'Family',
            value: controller.familyName,
            valueColor:
                controller.hasFamily ? AppColors.success : AppColors.warning,
          ),
          KeyValueRow(
            label: 'Device',
            value: controller.deviceName,
            valueColor:
                controller.hasDevice ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _permissionsCard(BuildContext context) {
    final caps = controller.capabilities.value;
    if (caps == null) {
      return const SectionCard(
        title: 'Android permissions',
        child: LoadingState(label: 'Reading Android permission state…'),
      );
    }
    if (!caps.available) {
      return const SectionCard(
        title: 'Android permissions',
        child: InfoBanner(
          tone: BannerTone.warning,
          message:
              'Android permission state is unavailable in this build. The app '
              'does not guess whether a permission is granted.',
        ),
      );
    }
    return SectionCard(
      title: 'Android permissions',
      subtitle:
          'These states are read from Android. Denying a permission only '
          'disables the related feature; it never hides an existing rule.',
      child: Column(
        children: [
          PermissionStatusTile(
            title: 'Usage access',
            subtitle: 'Required to report app usage on this phone.',
            granted: caps.usageAccessGranted,
            actionLabel: caps.usageAccessGranted ? null : 'Open settings',
            onAction: controller.openUsageAccessSettings,
          ),
          PermissionStatusTile(
            title: 'Precise location',
            subtitle: 'Used while you have location sharing turned on.',
            granted: caps.fineLocationGranted,
            actionLabel: caps.fineLocationGranted ? null : 'Allow',
            onAction: () => controller.requestPermissions(location: true),
          ),
          PermissionStatusTile(
            title: 'Background location',
            subtitle:
                'Lets the visible location service continue while this screen '
                'is closed.',
            granted: caps.backgroundLocationGranted,
            actionLabel:
                caps.backgroundLocationGranted ? null : 'Open settings',
            onAction: controller.openBackgroundLocationSettings,
          ),
          PermissionStatusTile(
            title: 'Camera',
            subtitle: 'Only during a video assistance session you accept.',
            granted: caps.cameraGranted,
            actionLabel: caps.cameraGranted ? null : 'Allow',
            onAction: () => controller.requestPermissions(camera: true),
          ),
          // Microphone access is only offered once this phone is linked to a
          // parent, so an unlinked device never asks for capture permission.
          if (controller.isEnrolled)
            PermissionStatusTile(
              title: 'Microphone',
              subtitle: 'Only during an audio or video session you accept.',
              granted: caps.microphoneGranted,
              actionLabel: caps.microphoneGranted ? null : 'Allow',
              onAction: () => controller.requestPermissions(microphone: true),
            )
          else
            const InfoBanner(
              tone: BannerTone.info,
              icon: Icons.mic_off_outlined,
              title: 'Microphone access',
              message:
                  'Microphone access is enabled after this phone is linked to a '
                  'parent. Finish phone setup first.',
            ),
          PermissionStatusTile(
            title: 'Notifications',
            subtitle:
                'Required for the visible background and location services.',
            granted: caps.notificationsGranted,
            actionLabel: caps.notificationsGranted ? null : 'Allow',
            onAction: () => controller.requestPermissions(notifications: true),
          ),
          PermissionStatusTile(
            title: 'Device admin',
            subtitle: caps.isDeviceOwner
                ? 'This phone is a managed Device Owner device.'
                : 'Device admin alone cannot suspend apps. A guardian must '
                    'provision Device Owner for app blocking.',
            granted: caps.isAdminActive || caps.isDeviceOwner,
            actionLabel:
                caps.isAdminActive || caps.isDeviceOwner ? null : 'Enable',
            onAction: controller.requestDeviceAdmin,
          ),
        ],
      ),
    );
  }

  Widget _mediaTestCard(BuildContext context) {
    return SectionCard(
      title: 'Camera and microphone test',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open the main or front camera and the microphone for a few '
            'seconds on this phone. The preview stays on this screen and is '
            'not recorded, saved, or sent.',
            style: TextStyle(height: 1.45, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Test camera and microphone',
            icon: Icons.videocam_outlined,
            outlined: true,
            onPressed: () => MediaSelfTestSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _enforcementCard() {
    return SectionCard(
      title: 'Android control',
      trailing: StatusChip(
        label: controller.isManaged ? 'Managed' : 'Not managed',
        tone: controller.isManaged ? StatusTone.success : StatusTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(controller.enforcementLabel, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          Text(
            controller.canVerifySuspension
                ? 'This screen can ask Android whether a configured app is '
                    'actually suspended.'
                : 'Without Device Owner control this app cannot suspend other '
                    'apps. Rules stay configured but are not described as '
                    'enforced.',
            style: const TextStyle(height: 1.45, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'View rules and verification',
            icon: Icons.verified_user_outlined,
            outlined: true,
            onPressed: () => Get.toNamed(AppRoutes.childRestrictions),
          ),
        ],
      ),
    );
  }

  Widget _backgroundCard() {
    final status = controller.guardian.value;
    return SectionCard(
      title: 'Background protection',
      trailing: StatusChip(
        label: controller.guardianRunning ? 'Running' : 'Not running',
        tone: controller.guardianRunning
            ? StatusTone.success
            : StatusTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(label: 'Service', value: controller.guardianStatusLabel),
          KeyValueRow(
            label: 'Last command check',
            value: status?.lastPollAt == null
                ? 'No check yet'
                : relativeTime(status!.lastPollAt),
          ),
          if (status?.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InfoBanner(
                tone: BannerTone.warning,
                message: status!.lastError!,
              ),
            ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Retry background protection',
            icon: Icons.sync,
            outlined: true,
            isLoading: controller.isStartingGuardian.value,
            onPressed: controller.retryBackgroundSync,
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    return SectionCard(
      title: 'Account actions',
      child: Column(
        children: [
          if (controller.hasFamily) ...[
            AppButton(
              label: 'Unlink this phone from the family',
              icon: Icons.link_off,
              outlined: true,
              destructive: true,
              isLoading: controller.isUnlinking.value,
              onPressed: () => _confirmUnlink(context),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlinking stops background protection and location sharing on '
              'this phone. Your guardian can no longer see this device.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
          ],
          AppButton(
            label: 'Sign out',
            icon: Icons.logout,
            outlined: true,
            isLoading: controller.isSigningOut.value,
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Unlink this phone?',
      message:
          'This removes your account from the family on this phone and stops '
          'background protection and location sharing. You will need a new '
          'linking code to join again.',
      confirmLabel: 'Unlink',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.unlink();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message:
          'Background protection and location sharing stop on this phone. You '
          'can sign in again later.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.signOut();
  }
}
