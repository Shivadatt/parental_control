import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';
import 'remote_assistance_controller.dart';

class RemoteAssistanceBinding extends Bindings {
  @override
  void dependencies() {
    final args = _routeArguments();
    Get.lazyPut<RemoteAssistanceController>(
      () => RemoteAssistanceController(
        remoteSessionRepository: Get.find<RemoteSessionRepository>(),
        session: Get.find<SessionService>(),
        deviceId: args['deviceId'] ?? '',
      ),
      fenix: true,
    );
  }

  Map<String, String> _routeArguments() {
    final result = <String, String>{};
    final raw = Get.arguments;
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value != null) {
          result[entry.key.toString()] = value.toString();
        }
      }
    }
    for (final entry in Get.parameters.entries) {
      final value = entry.value;
      if (value != null) {
        result.putIfAbsent(entry.key, () => value);
      }
    }
    return result;
  }
}
