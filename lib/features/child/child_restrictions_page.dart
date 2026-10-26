import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/models/child_enforcement.dart';
import 'package:parent_control/features/child/widgets/policy_summary_card.dart';

class ChildRestrictionsPage extends GetView<ChildShellController> {
  const ChildRestrictionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.policy.value != null) {
        controller.ensureVerification();
      }
    });
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Rules and permissions'),
          actions: [
            IconButton(
              tooltip: 'Refresh rules',
              onPressed: controller.isLoading.value
                  ? null
                  : () async {
                      await controller.refreshPolicy();
                      await controller.retryVerification();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading.value && controller.lastLoadedAt.value == null) {
      return const LoadingState(label: 'Loading rules…');
    }
    final policy = controller.policy.value;
    return RefreshIndicator(
      onRefresh: () async {
        await controller.refreshPolicy();
        await controller.retryVerification();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (!controller.isOnline) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              title: 'You are offline',
              message:
                  'The rules shown were downloaded earlier. Android '
                  'verification below is read live from this phone.',
            ),
            const SizedBox(height: 12),
          ],
          if (controller.policyError.value != null) ...[
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Rules could not be refreshed',
              message: controller.policyError.value!.message,
              actionLabel: 'Retry',
              onAction: controller.refreshPolicy,
            ),
            const SizedBox(height: 12),
          ],
          _enforcementBanner(),
          if (controller.isVerifyingEnforcement.value) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (policy == null)
            EmptyState(
              icon: Icons.rule_folder_outlined,
              title: 'No rules on this phone yet',
              message: controller.hasDevice
                  ? 'Rules appear after your guardian saves them for this phone '
                      'and the background service downloads them. Nothing is '
                      'blocked until Android applies and confirms them.'
                  : 'Register this phone first. Rules are sent to a registered '
                      'device.',
              actionLabel: controller.hasDevice ? 'Refresh' : 'Open phone setup',
              onAction: controller.hasDevice
                  ? controller.refreshPolicy
                  : () => Get.toNamed(AppRoutes.childEnrollment),
            )
          else ...[
            ChildPolicySummaryCard(
              policy: policy,
              enforcementApps: _enforcementApps(policy),
            ),
            const SizedBox(height: 12),
            _permissionsCard(context),
            const SizedBox(height: 12),
            _androidCard(context),
          ],
        ],
      ),
    );
  }

  List<ChildEnforcedApp>? _enforcementApps(DevicePolicy policy) {
    final hasConfigured =
        policy.payload.blockedPackages.isNotEmpty ||
            policy.payload.appRules.any((rule) => rule.blocked);
    if (!controller.canVerifySuspension) return null;
    if (!hasConfigured) return controller.verifiedApps;
    if (controller.verifiedApps.isEmpty) return null;
    return controller.verifiedApps;
  }

  Widget _enforcementBanner() {
    if (!controller.canVerifySuspension) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: InfoBanner(
          tone: BannerTone.warning,
          icon: Icons.gpp_maybe_outlined,
          title: 'Enforcement cannot be verified on this phone',
          message:
              'This app is not a Device Owner here, so it cannot suspend other '
              'apps. Rules are shown as configured, not as blocked. A guardian '
              'must provision Android managed-device or Device Owner setup.',
        ),
      );
    }
    if (controller.verificationError.value != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InfoBanner(
          tone: BannerTone.warning,
          title: 'Android verification failed',
          message: controller.verificationError.value!.message,
          actionLabel: 'Retry',
          onAction: controller.retryVerification,
        ),
      );
    }
    final verified = controller.verifiedApps;
    if (verified.isEmpty) return const SizedBox.shrink();
    final notSuspended = verified.where((app) => app.suspended == false).length;
    final unknown = verified.where((app) => app.suspended == null).length;
    if (notSuspended == 0 && unknown == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: InfoBanner(
          tone: BannerTone.success,
          icon: Icons.verified_user_outlined,
          title: 'Android confirms the configured blocks',
          message:
              'DevicePolicyManager reports every configured app as currently '
              'suspended on this phone. Scheduled rules only apply while their '
              'window is active.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoBanner(
        tone: BannerTone.warning,
        icon: Icons.report_outlined,
        title: 'Not every configured block is confirmed',
        message:
            '$notSuspended configured '
            'app${notSuspended == 1 ? ' is' : 's are'} not currently suspended '
            'and $unknown could not be verified. A schedule may not be active '
            'right now, or the rule has not been applied. This screen does not '
            'describe them as blocked.',
      ),
    );
  }

  Widget _permissionsCard(BuildContext context) {
    final caps = controller.capabilities.value;
    if (caps == null || !caps.available) {
      return const SectionCard(
        title: 'Permissions needed for background features',
        child: InfoBanner(
          tone: BannerTone.warning,
          message:
              'Android permission state is unavailable in this build. The app '
              'does not guess whether a permission is granted.',
        ),
      );
    }
    return SectionCard(
      title: 'Permissions needed for background features',
      subtitle:
          'Rules can be configured without these, but background enforcement, '
          'usage reporting and location need the related Android permission.',
      child: Column(
        children: [
          PermissionStatusTile(
            title: 'Usage access',
            subtitle: 'Usage reports come from Android UsageStatsManager.',
            granted: caps.usageAccessGranted,
            actionLabel: caps.usageAccessGranted ? null : 'Open settings',
            onAction: controller.openUsageAccessSettings,
          ),
          PermissionStatusTile(
            title: 'Background location',
            subtitle:
                'Needed only while location sharing is on and the app is not '
                'visible.',
            granted: caps.backgroundLocationGranted,
            actionLabel:
                caps.backgroundLocationGranted ? null : 'Open settings',
            onAction: controller.openBackgroundLocationSettings,
          ),
          PermissionStatusTile(
            title: 'Notifications',
            subtitle:
                'Android requires a visible notification for background '
                'services.',
            granted: caps.notificationsGranted,
            actionLabel: caps.notificationsGranted ? null : 'Allow',
            onAction: () => controller.requestPermissions(notifications: true),
          ),
        ],
      ),
    );
  }

  Widget _androidCard(BuildContext context) {
    final caps = controller.capabilities.value;
    final policy = controller.policy.value;
    return SectionCard(
      title: 'Android control on this phone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Device admin',
            value: (caps?.isAdminActive ?? false) ? 'Active' : 'Not active',
            valueColor: (caps?.isAdminActive ?? false)
                ? AppColors.success
                : AppColors.warning,
          ),
          KeyValueRow(
            label: 'Device Owner',
            value: (caps?.isDeviceOwner ?? false)
                ? 'Provisioned'
                : 'Not provisioned',
            valueColor: (caps?.isDeviceOwner ?? false)
                ? AppColors.success
                : AppColors.warning,
          ),
          KeyValueRow(
            label: 'Policy version',
            value: policy == null ? 'None' : 'v${policy.version}',
          ),
          KeyValueRow(
            label: 'Server status',
            value: policy?.status.label ?? 'No policy',
          ),
          KeyValueRow(
            label: 'Last device report',
            value: policy?.createdAt == null
                ? 'Unknown'
                : formatDateTime(policy!.createdAt),
          ),
          if (policy?.lastError != null &&
              policy!.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoBanner(
              tone: BannerTone.warning,
              title: 'Last enforcement error',
              message: policy.lastError!,
            ),
          ],
          if (caps != null && caps.available) ...[
            const SizedBox(height: 10),
            Text(
              '${caps.manufacturer} ${caps.model} · Android '
              '${caps.androidVersion} · app ${caps.appVersion}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Daily screen-time limits and bedtime are not enforced system-wide '
            'by this Android build. Only app blocks and their schedules are '
            'applied through DevicePolicyManager. Nothing here bypasses '
            'Android security or hides from you.',
            style: TextStyle(color: AppColors.muted, height: 1.45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
