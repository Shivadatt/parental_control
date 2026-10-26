import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/screen_time/screen_time_controller.dart';

class ScreenTimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ScreenTimeController>(
      () => ScreenTimeController(
        deviceId: _readDeviceId(),
        usageRepository: Get.find<UsageRepository>(),
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
