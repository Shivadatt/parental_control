import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/controllers/child_enrollment_controller.dart';

class ChildEnrollmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChildEnrollmentController>(
      () => ChildEnrollmentController(
        familyRepository: Get.find<FamilyRepository>(),
        pairingRepository: Get.find<PairingRepository>(),
        deviceRepository: Get.find<DeviceRepository>(),
        session: Get.find<SessionService>(),
        settings: Get.find<LocalSettingsService>(),
        connectivity: Get.find<ConnectivityService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
      ),
      fenix: true,
    );
  }
}
