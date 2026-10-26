import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/devices/device_detail_controller.dart';

class DeviceDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeviceDetailController>(
      () => DeviceDetailController(
        deviceId: readDeviceIdArgument(),
        deviceRepository: Get.find<DeviceRepository>(),
        policyRepository: Get.find<PolicyRepository>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}

String readDeviceIdArgument() {
  final arguments = Get.arguments;
  if (arguments is Map) {
    final value = arguments['deviceId'];
    if (value is String && value.isNotEmpty) return value;
  }
  return Get.parameters['deviceId'] ?? '';
}
