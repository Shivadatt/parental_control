import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/features/auth/controllers/verify_email_controller.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  late final VerifyEmailController _controller =
      Get.find<VerifyEmailController>();

  @override
  void initState() {
    super.initState();
    _controller.prepare(emailAddress: routeString('email'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Obx(() {
                final error = _controller.error.value;
                final info = _controller.info.value;
                final busy = _controller.isSigningOut.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OfflineNotice(),
                    Icon(
                      Icons.verified_user_outlined,
                      size: 56,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Confirm your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF172033),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _controller.email.value.isEmpty
                          ? 'This account has no verified email address yet.'
                          : 'The server reports '
                              '${_controller.email.value} as unverified. Open '
                              'the verification link, then check again here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 18),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          title: 'Verification action failed',
                          message: error.message,
                          actionLabel: 'Dismiss',
                          onAction: _controller.clearMessages,
                        ),
                      ),
                    if (info != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InfoBanner(
                          tone: BannerTone.info,
                          title: 'Still waiting for the server',
                          message: info,
                          actionLabel: 'Dismiss',
                          onAction: _controller.clearMessages,
                        ),
                      ),
                    SectionCard(
                      title: 'What to do',
                      child: Column(
                        children: const [
                          _StepRow(
                            number: '1',
                            text:
                                'Open the newest verification email for this '
                                'address. Check the spam folder if needed.',
                          ),
                          SizedBox(height: 10),
                          _StepRow(
                            number: '2',
                            text:
                                'Return here and tap “I verified my email”. The '
                                'app asks the server, not the device.',
                          ),
                          SizedBox(height: 10),
                          _StepRow(
                            number: '3',
                            text:
                                'Only after the server confirms the address '
                                'does the role and family step unlock.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'I verified my email',
                      icon: Icons.refresh,
                      isLoading: _controller.isRefreshing.value,
                      onPressed: busy || _controller.isRefreshing.value
                          ? null
                          : _controller.refreshVerification,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: _controller.resendSeconds.value > 0
                          ? 'Resend available in '
                              '${_controller.resendSeconds.value}s'
                          : 'Resend verification email',
                      icon: Icons.mark_email_unread_outlined,
                      outlined: true,
                      isLoading: _controller.isResending.value,
                      onPressed: busy || !_controller.canResend
                          ? null
                          : _controller.resend,
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: busy ? null : _controller.signOut,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: _controller.isSigningOut.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign out'),
                    ),
                    TextButton.icon(
                      onPressed: busy || _controller.isRefreshing.value
                          ? null
                          : _controller.signInInstead,
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'Already verified? Sign in to continue',
                      ),
                    ),
                    Text(
                      'Open the confirmation link on this phone and the app '
                      'signs in automatically. If it was opened on another '
                      'device, use the sign-in button above. No parent or child '
                      'feature is available until the email is verified. '
                      'Signing out clears this device’s local family selection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.45,
                ),
          ),
        ),
      ],
    );
  }
}
