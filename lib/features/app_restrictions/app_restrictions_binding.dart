import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';

class AppRestrictionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppRestrictionsController>(
      () => AppRestrictionsController(
        deviceId: _readDeviceId(),
        deviceRepository: Get.find<DeviceRepository>(),
        policyRepository: Get.find<PolicyRepository>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }

  String _readDeviceId() {
    final arguments = Get.arguments;
    if (arguments is Map) {
      final value = arguments['deviceId'];
      if (value is String && value.isNotEmpty) return value;
    }
    return Get.parameters['deviceId'] ?? '';
  }
}
