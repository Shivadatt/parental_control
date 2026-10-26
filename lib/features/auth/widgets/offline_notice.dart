import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/services/connectivity_service.dart';

/// Honest connectivity banner shown by onboarding screens. It never blocks
/// rendering; server calls still fail with their own error state.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isOnline.value) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: InfoBanner(
          tone: BannerTone.warning,
          icon: Icons.wifi_off,
          title: 'You are offline',
          message:
              'Actions that need the server will fail until the connection '
              'returns. Nothing is saved locally as a substitute.',
        ),
      );
    });
  }
}
