import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/session_service.dart';
import 'parent_settings_controller.dart';
import 'settings_body.dart';

/// Shell tab used by Agent C's ParentShellPage.
class ParentSettingsTab extends StatelessWidget {
  const ParentSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ParentSettingsController>(
      tag: 'parent-settings-tab',
      init: ParentSettingsController(
        authRepository: Get.find<AuthRepository>(),
        session: Get.find<SessionService>(),
        localSettings: Get.find<LocalSettingsService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
      ),
      builder: (controller) => SettingsBody(controller: controller),
    );
  }
}
