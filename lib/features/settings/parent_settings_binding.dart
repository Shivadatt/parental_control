import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/session_service.dart';
import 'parent_settings_controller.dart';

class ParentSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ParentSettingsController>(
      () => ParentSettingsController(
        authRepository: Get.find<AuthRepository>(),
        session: Get.find<SessionService>(),
        localSettings: Get.find<LocalSettingsService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
      ),
      fenix: true,
    );
  }
}
