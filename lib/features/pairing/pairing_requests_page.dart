import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';
import 'package:parent_control/features/pairing/controllers/pairing_requests_controller.dart';

class PairingRequestsPage extends StatefulWidget {
  const PairingRequestsPage({super.key});

  @override
  State<PairingRequestsPage> createState() => _PairingRequestsPageState();
}

class _PairingRequestsPageState extends State<PairingRequestsPage> {
  late final PairingRequestsController _controller =
      Get.find<PairingRequestsController>();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start(routeString('familyId')));
  }

  Future<void> _confirmCancel(PairingRequest request) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel the request for ${request.childDisplayName}?',
      message:
          'The server will mark this request cancelled and revoke the linking '
          'code. The child will not be able to approve it afterwards.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep request',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final success = await _controller.cancel(request);
    if (!mounted) return;
    final message = success
        ? 'The server confirmed the cancellation.'
        : _controller.actionError.value?.message ??
            'The cancellation was not confirmed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openRedeem() {
    Get.toNamed(
      AppRoutes.pairingRedeem,
      arguments: {'familyId': _controller.familyId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing requests'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh now',
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
                  Text(
                    'This list refreshes from the server every '
                    '${PairingRequestsController.pollInterval.inSeconds} '
                    'seconds while the screen is open, and whenever you pull '
                    'down.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 12),
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
                          isLoading: _controller.isLoading.value &&
                              _controller.requests.isEmpty,
                          error: _controller.error.value,
                          isEmpty: false,
                          onRetry: () => unawaited(_controller.refresh()),
                          loadingLabel: 'Loading pairing requests…',
                          child: _controller.requests.isEmpty
                              ? EmptyState(
                                  icon: Icons.pending_actions_outlined,
                                  title: 'No pairing requests',
                                  message:
                                      'No one has redeemed a linking code in '
                                      'this family yet. Ask the child to show '
                                      'the code on their device, then redeem it '
                                      'here.',
                                  actionLabel: 'Redeem a code',
                                  onAction: _openRedeem,
                                )
                              : Column(
                                  children: [
                                    for (final request
                                        in _controller.requests)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _RequestCard(
                                          request: request,
                                          isCancelling:
                                              _controller.isCancelling.value,
                                          onCancel: () =>
                                              _confirmCancel(request),
                                        ),
                                      ),
                                  ],
                                ),
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
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isCancelling,
    required this.onCancel,
  });

  final PairingRequest request;
  final bool isCancelling;
  final VoidCallback onCancel;

  bool get _expiredPending =>
      request.status == PairingRequestStatus.pendingChild && request.isExpired;

  PairingRequestStatus get _effectiveStatus =>
      _expiredPending ? PairingRequestStatus.expired : request.status;

  @override
  Widget build(BuildContext context) {
    final status = _effectiveStatus;
    final statusLabel = switch (status) {
      PairingRequestStatus.pendingChild => 'Pending',
      PairingRequestStatus.approved => 'Approved',
      PairingRequestStatus.rejected => 'Declined',
      PairingRequestStatus.cancelled => 'Cancelled',
      PairingRequestStatus.expired => 'Expired',
    };
    final tone = switch (status) {
      PairingRequestStatus.pendingChild => StatusTone.info,
      PairingRequestStatus.approved => StatusTone.success,
      PairingRequestStatus.rejected => StatusTone.danger,
      PairingRequestStatus.cancelled => StatusTone.neutral,
      PairingRequestStatus.expired => StatusTone.warning,
    };
    final canCancel =
        request.status == PairingRequestStatus.pendingChild && !request.isExpired;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.child_care, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.childDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.familyName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 10),
          KeyValueRow(
            label: 'Status',
            value: _expiredPending
                ? '${request.status.label} — expiry passed'
                : request.status.label,
          ),
          KeyValueRow(
            label: 'Requested by',
            value: request.parentDisplayName,
          ),
          KeyValueRow(
            label: 'Requested',
            value: formatDateTime(request.createdAt),
          ),
          KeyValueRow(
            label: 'Expires',
            value: formatDateTime(request.expiresAt),
          ),
          if (request.respondedAt != null)
            KeyValueRow(
              label: 'Responded',
              value: formatDateTime(request.respondedAt),
            ),
          if (canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isCancelling ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel pending request'),
              ),
            ),
          if (_expiredPending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'The expiry timestamp supplied by the server has passed. The '
                'server may still list the status as pending until it updates '
                'the row.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
