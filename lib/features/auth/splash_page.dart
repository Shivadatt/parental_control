import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/features/auth/controllers/splash_controller.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final SplashController _controller = Get.find<SplashController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
              child: Obx(() {
                final error = _controller.error.value;
                return Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 38,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      Env.appName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF172033),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consent-based parental controls. Only server-confirmed '
                      'accounts, roles and families are ever opened.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: error != null
                          ? ErrorState(
                              error: error,
                              onRetry: _controller.retry,
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Checking your session…'),
                                ],
                              ),
                            ),
                    ),
                    const OfflineNotice(),
                    Text(
                      'A local role choice never grants access. RLS and Edge '
                      'Function checks decide permissions.',
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
