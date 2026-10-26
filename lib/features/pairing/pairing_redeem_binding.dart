import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/pairing/controllers/pairing_redeem_controller.dart';

class PairingRedeemBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PairingRedeemController>(
      () => PairingRedeemController(
        pairingRepository: Get.find<PairingRepository>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
