import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/controllers/login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(
      () => LoginController(
        authRepository: Get.find<AuthRepository>(),
        familyRepository: Get.find<FamilyRepository>(),
        session: Get.find<SessionService>(),
        settings: Get.find<LocalSettingsService>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
