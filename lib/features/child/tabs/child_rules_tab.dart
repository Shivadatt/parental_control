import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/widgets/policy_summary_card.dart';

class ChildRulesTab extends GetView<ChildShellController> {
  const ChildRulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Rules on this phone'),
          actions: [
            IconButton(
              tooltip: 'Refresh rules',
              onPressed:
                  controller.isLoading.value ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading.value &&
        controller.lastLoadedAt.value == null) {
      return const LoadingState(label: 'Loading rules…');
    }
    final policy = controller.policy.value;
    return RefreshIndicator(
      onRefresh: controller.refresh,
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
                  'The rules shown here were downloaded earlier. The device '
                  'reports below come from Android on this phone.',
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
          if (!controller.isManaged) ...[
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.gpp_maybe_outlined,
              title: 'Not enforceable on this phone',
              message:
                  'This phone is not a Device Owner, so the app cannot suspend '
                  'other apps. Rules below are only what your guardian has '
                  'configured; this screen does not claim they are applied. A '
                  'guardian must provision the phone for managed enforcement.',
            ),
            const SizedBox(height: 12),
          ],
          if (policy == null)
            EmptyState(
              icon: Icons.rule_folder_outlined,
              title: 'No rules have arrived yet',
              message: controller.hasDevice
                  ? 'Rules appear after your guardian saves them for this phone '
                      'and the background service downloads them.'
                  : 'Register this phone first. Rules are sent to a registered '
                      'device.',
              actionLabel: controller.hasDevice
                  ? 'Open rules and permissions'
                  : 'Open phone setup',
              onAction: () => Get.toNamed(
                controller.hasDevice
                    ? AppRoutes.childRestrictions
                    : AppRoutes.childEnrollment,
              ),
            )
          else ...[
            ChildPolicySummaryCard(policy: policy),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Does Android confirm enforcement?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.isManaged
                        ? 'Open the full rules screen to see each configured app '
                            'with the DevicePolicyManager result. A downloaded '
                            'rule is not the same as a suspended app.'
                        : 'Without Device Owner control, no package can be '
                            'suspended by this app. Nothing on this phone should '
                            'be described as blocked.',
                    style: const TextStyle(height: 1.45, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Open full rules and permissions',
                    icon: Icons.verified_user_outlined,
                    outlined: true,
                    onPressed: () => Get.toNamed(AppRoutes.childRestrictions),
                  ),
                ],
              ),
            ),
          ],
          if (controller.lastLoadedAt.value != null) ...[
            const SizedBox(height: 16),
            Text(
              'Rules refreshed ${relativeTime(controller.lastLoadedAt.value)}',
              textAlign: TextAlign.center,
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
}
