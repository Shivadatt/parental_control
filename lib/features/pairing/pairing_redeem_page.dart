import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';
import 'package:parent_control/features/pairing/controllers/pairing_redeem_controller.dart';
import 'package:parent_control/features/pairing/pairing_qr_payload.dart';

class PairingRedeemPage extends StatefulWidget {
  const PairingRedeemPage({super.key});

  @override
  State<PairingRedeemPage> createState() => _PairingRedeemPageState();
}

class _PairingRedeemPageState extends State<PairingRedeemPage> {
  late final PairingRedeemController _controller =
      Get.find<PairingRedeemController>();
  final TextEditingController _code = TextEditingController();
  String? _scanMessage;
  int _scannerEpoch = 0;

  @override
  void initState() {
    super.initState();
    _controller.start(routeString('familyId'));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        _scanMessage =
            'Enter the Child ID or linking code shown on the child device.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await _controller.redeem(input);
    if (!mounted) return;
    setState(() {
      _scanMessage = ok ? null : _scanMessage;
    });
  }

  void _onScanned(String value) {
    _code.text = value;
    unawaited(_redeem(value));
  }

  void _onRejected(String message) {
    if (!mounted) return;
    setState(() => _scanMessage = message);
  }

  void _restartScanner() {
    _controller.clearError();
    setState(() {
      _scanMessage = null;
      _scannerEpoch += 1;
    });
  }

  void _linkAnother() {
    _controller.reset();
    _code.clear();
    setState(() => _scanMessage = null);
  }

  void _openFamily() {
    Get.toNamed(
      AppRoutes.family,
      arguments: {'familyId': _controller.familyId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link a child')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Obx(() {
                final request = _controller.request.value;
                if (request != null) return _buildResult(context, request);
                return _buildForm(context);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final error = _controller.error.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OfflineNotice(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InfoBanner(
              tone: BannerTone.danger,
              title: _errorTitle(error.code),
              message: '${error.message}${_errorGuidance(error.code)}',
              actionLabel: 'Scan again',
              onAction: _restartScanner,
            ),
          ),
        if (_scanMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InfoBanner(
              tone: BannerTone.warning,
              title: 'Only Parent Control pairing codes are accepted',
              message: _scanMessage!,
              actionLabel: 'Dismiss',
              onAction: () => setState(() => _scanMessage = null),
            ),
          ),
        SectionCard(
          title: 'Scan the child’s QR code',
          subtitle:
              'The child device shows a QR code containing their permanent '
              'Child ID. Both parentcontrol://pair?id=…&v=2 and the older '
              'parentcontrol://pair?code=…&v=1 are accepted; other QR content '
              'is ignored.',
          child: Column(
            children: [
              SizedBox(
                height: 260,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _LinkingScanner(
                    key: ValueKey<int>(_scannerEpoch),
                    onDetected: _onScanned,
                    onRejected: _onRejected,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Android may ask for camera permission the first time. The '
                'camera stream is only used to read the pairing code.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Or enter the Child ID or linking code',
          subtitle: 'Dashes and spaces are ignored. Older child builds may '
              'still show a short-lived 8-character code.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _code,
                label: 'Child ID or linking code',
                hint: 'PC-7K4M2QRX or 4K9M2QRT',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.badge_outlined,
                onFieldSubmitted: (_) => _redeem(_code.text),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Send pairing request',
                icon: Icons.verified_user_outlined,
                isLoading: _controller.isRedeeming.value,
                onPressed: _controller.isRedeeming.value
                    ? null
                    : () => _redeem(_code.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          tone: BannerTone.info,
          icon: Icons.how_to_reg_outlined,
          title: 'The child must approve',
          message:
              'Sending the request notifies the child account. The child sees '
              'the family and parent name and approves on their own device. '
              'Knowing the Child ID alone does not grant access to the child’s '
              'device or data, and nothing is shared before the child '
              'approves. This screen never approves on the child’s behalf.',
        ),
        const SizedBox(height: 12),
        Text(
          'The server validates the Child ID or code and rate-limits attempts. '
          'Failures are shown exactly as reported; no request is invented '
          'locally.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, PairingRequest request) {
    final isPending = request.status == PairingRequestStatus.pendingChild &&
        !request.isExpired;
    final tone = switch (request.status) {
      PairingRequestStatus.pendingChild => BannerTone.info,
      PairingRequestStatus.approved => BannerTone.success,
      PairingRequestStatus.rejected => BannerTone.warning,
      PairingRequestStatus.cancelled => BannerTone.warning,
      PairingRequestStatus.expired => BannerTone.warning,
    };
    final title = isPending
        ? 'Waiting for child approval'
        : request.status.label;
    final message = isPending
        ? 'The request is pending on the server. The child must approve it on '
            'their own device. Nothing is linked yet, and this app never '
            'approves it for them.'
        : request.status == PairingRequestStatus.approved
            ? 'The server reports this request approved. The child membership '
                'is now active for this family.'
            : 'The server reports this request as '
                '${request.status.label.toLowerCase()}. No family membership '
                'was created by this request.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Server response',
          subtitle: 'These values come from the pairing Edge Function.',
          child: Column(
            children: [
              KeyValueRow(
                label: 'Child',
                // Before approval the server returns a neutral label instead of
                // the child's name, so confirm with the identifier the guardian
                // actually entered.
                value: request.status == PairingRequestStatus.pendingChild
                    ? _controller.lastIdentifier
                    : request.childDisplayName,
              ),
              KeyValueRow(
                label: 'Family',
                value: request.familyName,
              ),
              KeyValueRow(
                label: 'Status',
                value: request.status.label,
              ),
              KeyValueRow(
                label: 'Requested',
                value: formatDateTime(request.createdAt),
              ),
              KeyValueRow(
                label: 'Expires',
                value: formatDateTime(request.expiresAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InfoBanner(
          tone: tone,
          title: title,
          message: message,
        ),
        const SizedBox(height: 16),
        if (isPending)
          AppButton(
            label: 'Check status',
            icon: Icons.refresh,
            isLoading: _controller.isCheckingStatus.value,
            onPressed: _controller.isCheckingStatus.value
                ? null
                : () => unawaited(_controller.checkStatus()),
          ),
        if (!isPending && request.status == PairingRequestStatus.approved)
          AppButton(
            label: 'Open family',
            icon: Icons.family_restroom,
            onPressed: _openFamily,
          ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Link another child',
          icon: Icons.qr_code_scanner,
          outlined: true,
          onPressed: _linkAnother,
        ),
        const SizedBox(height: 12),
        Text(
          'The request status is refreshed only when you ask the server. '
          'Closing this screen does not change it.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }

  String _errorTitle(String code) {
    switch (code) {
      case 'invalid_code':
        return 'Child ID or code not recognised';
      case 'code_expired':
        return 'Linking code expired';
      case 'rate_limited':
        return 'Too many attempts';
      case 'child_already_linked':
        return 'Child already linked';
      case 'not_configured':
        return 'Pairing is not configured';
      case AppErrorCodes.network:
      case AppErrorCodes.timeout:
        return 'Connection problem';
      case AppErrorCodes.validation:
        return 'Check the Child ID or code';
      default:
        return 'Pairing request failed';
    }
  }

  String _errorGuidance(String code) {
    switch (code) {
      case 'invalid_code':
        return ' Check the Child ID (for example PC-7K4M2QRX) or the '
            '8-character code. Ask the child to read it from their setup '
            'screen; their ID is shown there automatically.';
      case 'code_expired':
        return ' That linking code has expired. Use the child’s permanent '
            'Child ID instead, or ask them for a fresh code.';
      case 'rate_limited':
        return ' Wait before trying again; the server limits lookup attempts '
            'for this account.';
      case 'child_already_linked':
        return ' A child account can be in one active family at a time.';
      case 'not_configured':
        return ' The backend owner must deploy the pairing function and its '
            'secrets.';
      case AppErrorCodes.network:
      case AppErrorCodes.timeout:
        return ' Check this device’s connection and try again.';
      default:
        return '';
    }
  }
}

class _LinkingScanner extends StatefulWidget {
  const _LinkingScanner({
    super.key,
    required this.onDetected,
    required this.onRejected,
  });

  final ValueChanged<String> onDetected;
  final ValueChanged<String> onRejected;

  @override
  State<_LinkingScanner> createState() => _LinkingScannerState();
}

class _LinkingScannerState extends State<_LinkingScanner> {
  late final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  String? _permissionNote;
  bool _handled = false;
  String? _lastRejected;

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final payload = PairingQrPayload.tryParse(raw);
      if (payload == null) {
        if (_lastRejected != raw) {
          _lastRejected = raw;
          widget.onRejected(
            'This QR code is not a Parent Control pairing code. Scan the QR '
            'code shown inside the app on the child device, or enter the Child '
            'ID below.',
          );
        }
        continue;
      }
      _handled = true;
      unawaited(_scanner.stop());
      widget.onDetected(payload.value);
      return;
    }
  }

  Future<void> _retryCamera() async {
    setState(() => _permissionNote = null);
    try {
      final result = await Get.find<DeviceAdminService>()
          .requestPermissions(camera: true);
      final granted = result['camera'] ?? false;
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _permissionNote =
              'Camera permission is still denied. Open Android Settings → Apps '
              '→ Parent Control → Permissions → Camera, allow access, then tap '
              '“Start camera” again.';
        });
        return;
      }
      await _scanner.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _permissionNote =
            'The camera could not be started. Check the permission and try '
            'again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _scanner,
      builder: (context, scannerState, _) {
        return Stack(
          children: [
            MobileScanner(
              controller: _scanner,
              onDetect: _handleCapture,
              errorBuilder: (context, error) {
                final permissionDenied = error.errorCode ==
                    MobileScannerErrorCode.permissionDenied;
                return ColoredBox(
                  color: const Color(0xFF0F172A),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          permissionDenied
                              ? Icons.no_photography_outlined
                              : Icons.videocam_off_outlined,
                          color: Colors.white70,
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          permissionDenied
                              ? 'Camera permission required'
                              : 'Camera unavailable',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          permissionDenied
                              ? 'Scanning needs camera access. The app cannot '
                                  'open system settings for you; use the Android '
                                  'Settings app if the button below is refused.'
                              : 'The scanner could not start. You can still '
                                  'enter the Child ID or code below.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        if (_permissionNote != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _permissionNote!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD37A),
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _retryCamera,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Start camera'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // The caption describes a live viewfinder, so it must not sit on top
            // of the permission-denied panel and imply a working preview.
            if (scannerState.error == null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Point the camera at the child’s QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
