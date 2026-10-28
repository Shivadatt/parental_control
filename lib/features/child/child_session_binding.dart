import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class ChildSessionBinding extends Bindings {
  /// This route is the child device's own session. Anything else fails closed.
  static const String requiredRole = 'child';

  @override
  void dependencies() {
    Get.delete<RemoteSessionController>(force: true);
    Get.lazyPut<RemoteSessionController>(
      () {
        final args = _routeArguments();
        final role = (args['role'] ?? '').trim().toLowerCase();
        if (role != requiredRole) {
          // Fail closed: a route that is not unambiguously the child's own
          // session must not produce a controller that can capture audio.
          // The parent role is receive-only and the empty session id means no
          // session can be loaded, joined, or watched from this screen.
          return RemoteSessionController(
            remoteSessionRepository: Get.find<RemoteSessionRepository>(),
            session: Get.find<SessionService>(),
            deviceAdmin: Get.find<DeviceAdminService>(),
            sessionId: '',
            role: 'parent',
          );
        }
        return RemoteSessionController(
          remoteSessionRepository: Get.find<RemoteSessionRepository>(),
          session: Get.find<SessionService>(),
          deviceAdmin: Get.find<DeviceAdminService>(),
          sessionId: args['sessionId'] ?? '',
          role: requiredRole,
        );
      },
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
