import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/edge_api.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/supabase_service.dart';
import 'account_privacy_repository.dart';
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
        privacy: SupabaseAccountPrivacyRepository(
          supabase: Get.find<SupabaseService>(),
          edgeApi: Get.find<EdgeApi>(),
        ),
      ),
      fenix: true,
    );
  }
}
