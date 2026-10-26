import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:parent_control/features/auth/controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(
      () => SplashController(
        supabase: Get.find<SupabaseService>(),
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
