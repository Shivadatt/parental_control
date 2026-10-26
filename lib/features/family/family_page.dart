import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';
import 'package:parent_control/features/family/controllers/family_controller.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  late final FamilyController _controller = Get.find<FamilyController>();

  @override
  void initState() {
    super.initState();
    final familyId = routeString('familyId');
    // Keep an already loaded family when the page is reopened without an
    // argument; otherwise load (or explain why no family was selected).
    if (familyId != null || !_controller.hasFamily) {
      unawaited(_controller.start(familyId));
    }
  }

  Future<void> _openRedeem() async {
    await Get.toNamed(
      AppRoutes.pairingRedeem,
      arguments: {'familyId': _controller.familyId},
    );
    if (mounted) unawaited(_controller.refresh());
  }

  Future<void> _openRequests() async {
    await Get.toNamed(
      AppRoutes.pairingRequests,
      arguments: {'familyId': _controller.familyId},
    );
    if (mounted) unawaited(_controller.refresh());
  }

  Future<void> _openAudit() async {
    await Get.toNamed(
      AppRoutes.auditLogs,
      arguments: {'familyId': _controller.familyId},
    );
  }

  Future<void> _confirmUnlink(FamilyMember member) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Unlink ${member.displayName}?',
      message:
          'The server will mark this child membership removed and revoke that '
          'child’s device credentials. Re-linking needs a new code and the '
          'child’s approval. This cannot be undone from here.',
      confirmLabel: 'Unlink',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final success = await _controller.unlink(member);
    if (!mounted) return;
    final message = success
        ? 'The server confirmed the removal. The list was reloaded.'
        : _controller.actionError.value?.message ??
            'The removal was not confirmed by the server.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_controller.family.value?.name ?? 'Family')),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Reload family',
              onPressed: _controller.isRefreshing.value
                  ? null
                  : () => unawaited(_controller.refresh()),
              icon: _controller.isRefreshing.value
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: _controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const OfflineNotice(),
                  Obx(() {
                    final actionError = _controller.actionError.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (actionError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InfoBanner(
                              tone: BannerTone.danger,
                              title: 'Action not confirmed',
                              message: actionError.message,
                              actionLabel: 'Dismiss',
                              onAction: _controller.clearActionError,
                            ),
                          ),
                        AsyncStateView(
                          isLoading:
                              _controller.isLoading.value && !_controller.hasFamily,
                          error: _controller.error.value,
                          isEmpty: false,
                          onRetry: () => unawaited(_controller.load()),
                          loadingLabel: 'Loading family…',
                          child: _controller.family.value == null
                              ? const SizedBox.shrink()
                              : _buildContent(context, _controller.family.value!),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Family family) {
    final guardians = _controller.guardians;
    final children = _controller.children;
    final owner = _controller.guardianFor(family);
    final ownerLabel = owner == null
        ? (_controller.isOwner(family) ? 'You' : 'Owner account')
        : '${owner.displayName}${_controller.isOwner(family) ? ' (you)' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: family.name,
          subtitle: 'Family overview',
          child: Column(
            children: [
              KeyValueRow(label: 'Family name', value: family.name),
              KeyValueRow(label: 'Owner', value: ownerLabel),
              KeyValueRow(
                label: 'Created',
                value: formatDate(family.createdAt),
              ),
              KeyValueRow(
                label: 'Location retention',
                value: '${family.settings.locationRetentionDays} days',
              ),
              KeyValueRow(
                label: 'Usage retention',
                value: '${family.settings.usageRetentionDays} days',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Family actions',
          subtitle: 'These actions call the server; nothing is simulated.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'Link a child',
                icon: Icons.qr_code_scanner,
                outlined: true,
                onPressed: _openRedeem,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Pairing requests',
                icon: Icons.pending_actions,
                outlined: true,
                onPressed: _openRequests,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Audit log (read-only)',
                icon: Icons.history,
                outlined: true,
                onPressed: _openAudit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Guardians',
          subtitle: 'Accounts that can manage this family.',
          child: guardians.isEmpty
              ? Text(
                  'No guardian profiles are visible for this family.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                )
              : Column(
                  children: [
                    for (final member in guardians)
                      _GuardianRow(
                        member: member,
                        isCurrentUser: _controller.isCurrentUser(member),
                        isOwner: member.userId == family.ownerId,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Children',
          subtitle:
              'Only accounts that joined this family through pairing appear '
              'here. There is no child directory search.',
          child: children.isEmpty
              ? EmptyState(
                  icon: Icons.child_care_outlined,
                  title: 'No children linked yet',
                  message:
                      'On the child device, open Pairing to show a linking '
                      'code. Redeem it on this device; the child must then '
                      'approve the request before the account appears here.',
                  actionLabel: 'Link a child',
                  onAction: _openRedeem,
                )
              : Column(
                  children: [
                    for (final member in children)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ChildCard(
                          member: member,
                          isUnlinking: _controller.isUnlinking.value,
                          onUnlink: () => _confirmUnlink(member),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unlinking is confirmed by the server before the list changes. '
          'This screen never shows a child account that has not joined.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow({
    required this.member,
    required this.isCurrentUser,
    required this.isOwner,
  });

  final FamilyMember member;
  final bool isCurrentUser;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.person_outline, color: AppColors.primary),
      ),
      title: Text(
        '${member.displayName}${isCurrentUser ? ' (you)' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isOwner ? 'Family owner' : 'Guardian',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
            ),
      ),
      trailing: StatusChip(
        label: member.isActive ? 'Active' : 'Removed',
        tone: member.isActive ? StatusTone.success : StatusTone.neutral,
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.member,
    required this.isUnlinking,
    required this.onUnlink,
  });

  final FamilyMember member;
  final bool isUnlinking;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        color: AppColors.background.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                child: const Icon(Icons.child_care, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: member.isActive ? 'Active' : 'Removed',
                tone: member.isActive ? StatusTone.success : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyValueRow(label: 'Role', value: 'Child'),
          KeyValueRow(
            label: 'Joined',
            value: formatDateTime(member.joinedAt),
          ),
          if (member.isActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isUnlinking ? null : onUnlink,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Unlink child'),
              ),
            ),
        ],
      ),
    );
  }
}
