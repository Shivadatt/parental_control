import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/controllers/verify_email_controller.dart';

class VerifyEmailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VerifyEmailController>(
      () => VerifyEmailController(
        authRepository: Get.find<AuthRepository>(),
        familyRepository: Get.find<FamilyRepository>(),
        session: Get.find<SessionService>(),
        settings: Get.find<LocalSettingsService>(),
        connectivity: Get.find<ConnectivityService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
      ),
      fenix: true,
    );
  }
}
