import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<ConnectivityService> init() async {
    final connectivity = Connectivity();
    try {
      _apply(await connectivity.checkConnectivity());
    } catch (_) {
      isOnline.value = true;
    }
    _subscription = connectivity.onConnectivityChanged.listen(_apply);
    return this;
  }

  void _apply(List<ConnectivityResult> results) {
    isOnline.value = results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
