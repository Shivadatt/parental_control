import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/features/child/controllers/child_enrollment_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ChildEnrollmentPage extends StatefulWidget {
  const ChildEnrollmentPage({super.key});

  @override
  State<ChildEnrollmentPage> createState() => _ChildEnrollmentPageState();
}

class _ChildEnrollmentPageState extends State<ChildEnrollmentPage> {
  late final ChildEnrollmentController controller;
  late final TextEditingController _name;
  Worker? _nameWorker;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ChildEnrollmentController>();
    _name = TextEditingController(text: controller.displayName.value);
    _nameWorker = ever<String>(controller.displayName, (value) {
      if (value.isNotEmpty && _name.text != value) _name.text = value;
    });
  }

  @override
  void dispose() {
    _nameWorker?.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: const Text('Set up this phone'),
          actions: [
            IconButton(
              tooltip: 'Refresh setup state',
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.load(),
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
        controller.family.value == null &&
        controller.device.value == null) {
      return const LoadingState(label: 'Checking family and phone setup…');
    }
    final fatal = controller.error.value;
    if (fatal != null &&
        controller.family.value == null &&
        controller.device.value == null) {
      return ErrorState(error: fatal, onRetry: () => controller.load());
    }
    final canPop = Navigator.of(context).canPop();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (!controller.isOnline) ...[
          const InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.wifi_off,
            title: 'You are offline',
            message:
                'Linking and registration need a connection. Nothing is sent '
                'until this phone is online again.',
          ),
          const SizedBox(height: 12),
        ],
        if (fatal != null) ...[
          InfoBanner(
            tone: BannerTone.warning,
            title: 'Setup state is incomplete',
            message: fatal.message,
            actionLabel: 'Retry',
            onAction: () => controller.load(),
          ),
          const SizedBox(height: 12),
        ],
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
        if (controller.isReady)
          _readyCard()
        else if (controller.isLinked)
          ..._deviceStep(context)
        else
          ..._linkingStep(context),
        if (canPop) ...[
          const SizedBox(height: 16),
          AppButton(
            label: 'Back',
            outlined: true,
            onPressed: () => Get.back<void>(),
          ),
        ],
      ],
    );
  }

  Widget _readyCard() {
    return SectionCard(
      title: 'This phone is set up',
      trailing: const StatusChip(
        label: 'Registered',
        tone: StatusTone.success,
        icon: Icons.check_circle_outline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(label: 'Family', value: controller.family.value!.name),
          KeyValueRow(
            label: 'Device',
            value: controller.device.value!.displayName,
          ),
          KeyValueRow(
            label: 'Status',
            value: controller.device.value!.statusLabel,
          ),
          const SizedBox(height: 10),
          const Text(
            'Rules and requests are available from My phone. App blocking is '
            'reported only after Android confirms it on this device.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Open My phone',
            icon: Icons.phone_android,
            onPressed: () => Get.offAllNamed(AppRoutes.childShell),
          ),
        ],
      ),
    );
  }

  List<Widget> _linkingStep(BuildContext context) {
    final code = controller.linkingCode.value;
    return [
      SectionCard(
        title: 'Link to your family',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a short-lived linking code and show it to your guardian. '
              'They redeem it from the parent app. You will see their request '
              'below and must approve it before anything is linked.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            if (code == null || code.isExpired)
              AppButton(
                label: code == null
                    ? 'Create linking code'
                    : 'Create a new code',
                icon: Icons.qr_code_2,
                isLoading: controller.isCreatingCode.value,
                onPressed: controller.isCreatingCode.value
                    ? null
                    : controller.createCode,
              ),
            if (code != null && code.isExpired) ...[
              const SizedBox(height: 10),
              const InfoBanner(
                tone: BannerTone.warning,
                message:
                    'This code has expired. Create a new one to continue.',
              ),
            ],
            if (code != null && !code.isExpired) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: code.qrPayload,
                    size: 196,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: SelectableText(
                  code.code,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Expires ${relativeTime(code.expiresAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Check for requests',
                      icon: Icons.refresh,
                      outlined: true,
                      isLoading: controller.isCheckingRequests.value,
                      onPressed: controller.isCheckingRequests.value
                          ? null
                          : () => controller.checkRequests(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Copy code',
                      icon: Icons.copy,
                      outlined: true,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: code.code),
                        );
                        controller.actionMessage.value =
                            'Linking code copied.';
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      if (controller.pendingRequests.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'Waiting for your approval',
          subtitle:
              'Approve only if you recognise the guardian and family below.',
          child: Column(
            children: [
              for (final request in controller.pendingRequests) ...[
                _requestTile(context, request),
                if (request != controller.pendingRequests.last)
                  const Divider(height: 24),
              ],
            ],
          ),
        ),
      ] else if (code != null) ...[
        const SizedBox(height: 12),
        const InfoBanner(
          tone: BannerTone.info,
          message:
              'No guardian request has arrived yet. Keep this screen open or '
              'check again after your guardian enters the code.',
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'No family can attach this account without your approval. A normal app '
        'install is not a Device Owner device; a guardian must provision '
        'managed enforcement separately.',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.muted, height: 1.45),
      ),
    ];
  }

  Widget _requestTile(BuildContext context, PairingRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.family_restroom, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.familyName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'From ${request.parentDisplayName} · expires '
                    '${relativeTime(request.expiresAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Decline',
                outlined: true,
                destructive: true,
                onPressed: controller.isResponding.value
                    ? null
                    : () => controller.respondTo(request, approve: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Approve',
                isLoading: controller.isResponding.value,
                onPressed: controller.isResponding.value
                    ? null
                    : () => _confirmApprove(context, request),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    PairingRequest request,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Join ${request.familyName}?',
      message:
          'Approving links your account to this family and lets your guardian '
          'request the phone setup below. You can unlink later from settings.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    await controller.respondTo(request, approve: true);
  }

  List<Widget> _deviceStep(BuildContext context) {
    final family = controller.family.value!;
    return [
      SectionCard(
        title: 'Register this phone',
        subtitle: 'Family: ${family.name}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This creates a device identity stored by Android and registers '
              'this phone with your family. Background protection and location '
              'sharing stay off until you turn them on in My phone.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            if (!controller.isNativeAvailable) ...[
              const InfoBanner(
                tone: BannerTone.warning,
                title: 'Android only',
                message:
                    'Device registration needs the Android app with its native '
                    'bridge. This build cannot register a phone.',
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _name,
              label: 'Phone name',
              hint: 'For example: Sam’s phone',
              prefixIcon: Icons.phone_android,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              enabled: !controller.isRegistering.value,
              onFieldSubmitted: (value) {
                controller.displayName.value = value;
                controller.registerDevice();
              },
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Register this phone',
              icon: Icons.phonelink_lock,
              isLoading: controller.isRegistering.value,
              onPressed: controller.isRegistering.value
                  ? null
                  : () {
                      controller.displayName.value = _name.text;
                      controller.registerDevice();
                    },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'What happens next',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'After registration, open My phone to see the guardian’s rules, '
              'Android permission state and any assistance requests. A rule is '
              'shown as enforced only when Android confirms it on this device.',
              style: TextStyle(height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Skip for now',
              outlined: true,
              onPressed: () => Get.offAllNamed(AppRoutes.childShell),
            ),
          ],
        ),
      ),
    ];
  }
}
