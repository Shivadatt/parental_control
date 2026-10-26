import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/family/controllers/family_controller.dart';

class FamilyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FamilyController>(
      () => FamilyController(
        familyRepository: Get.find<FamilyRepository>(),
        pairingRepository: Get.find<PairingRepository>(),
        session: Get.find<SessionService>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
