import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/services/child_preferences.dart';

class ChildShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChildShellController>(
      () => ChildShellController(
        familyRepository: Get.find<FamilyRepository>(),
        pairingRepository: Get.find<PairingRepository>(),
        deviceRepository: Get.find<DeviceRepository>(),
        remoteSessionRepository: Get.find<RemoteSessionRepository>(),
        policyRepository: Get.find<PolicyRepository>(),
        authRepository: Get.find<AuthRepository>(),
        session: Get.find<SessionService>(),
        localSettings: Get.find<LocalSettingsService>(),
        connectivity: Get.find<ConnectivityService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
        preferences: ChildPreferences(),
      ),
      fenix: true,
    );
  }
}
