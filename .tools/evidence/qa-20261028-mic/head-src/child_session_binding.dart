import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class ChildSessionBinding extends Bindings {
  @override
  void dependencies() {
    final args = _routeArguments();
    Get.lazyPut<RemoteSessionController>(
      () => RemoteSessionController(
        remoteSessionRepository: Get.find<RemoteSessionRepository>(),
        session: Get.find<SessionService>(),
        sessionId: args['sessionId'] ?? '',
        role: 'child',
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
