import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/child/controllers/child_requests_controller.dart';

class ChildRequestsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChildRequestsController>(
      () => ChildRequestsController(
        pairingRepository: Get.find<PairingRepository>(),
        remoteSessionRepository: Get.find<RemoteSessionRepository>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
