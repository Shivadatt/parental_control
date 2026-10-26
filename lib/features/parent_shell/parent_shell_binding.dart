import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';
import 'package:parent_control/features/devices/devices_controller.dart';
import 'package:parent_control/features/parent_shell/parent_shell_controller.dart';

class ParentShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ParentShellController>(
      () => ParentShellController(),
      fenix: true,
    );
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        deviceRepository: Get.find<DeviceRepository>(),
        familyRepository: Get.find<FamilyRepository>(),
        policyRepository: Get.find<PolicyRepository>(),
        session: Get.find<SessionService>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<DevicesController>(
      () => DevicesController(
        deviceRepository: Get.find<DeviceRepository>(),
        familyRepository: Get.find<FamilyRepository>(),
        session: Get.find<SessionService>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
