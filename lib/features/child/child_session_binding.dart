import 'package:get/get.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';
import 'package:parent_control/features/remote_assistance/remote_session_registry.dart';

class ChildSessionBinding extends Bindings {
  /// This route is the child device's own session. Anything else fails closed.
  static const String requiredRole = 'child';

  @override
  void dependencies() {
    final args = _routeArguments();
    final requestedRole = (args['role'] ?? '').trim().toLowerCase();
    final isChildSession = requestedRole == requiredRole;
    // Fail closed: a route that is not unambiguously the child's own session
    // must not produce a controller that can capture audio. The parent role
    // is receive-only and the empty session id means no session can be
    // loaded, joined, or watched from this screen.
    final sessionId = isChildSession ? (args['sessionId'] ?? '') : '';
    final role = isChildSession ? requiredRole : 'parent';
    // The controller is owned by the registry, not by this route, so pressing
    // Back or leaving the screen cannot end a live, consented session.
    _registry().acquire(
      sessionId: sessionId,
      role: role,
      create: () => RemoteSessionController(
        remoteSessionRepository: Get.find<RemoteSessionRepository>(),
        session: Get.find<SessionService>(),
        deviceAdmin: Get.find<DeviceAdminService>(),
        sessionId: sessionId,
        role: role,
      ),
    );
  }

  RemoteSessionRegistry _registry() {
    if (Get.isRegistered<RemoteSessionRegistry>()) {
      return Get.find<RemoteSessionRegistry>();
    }
    // Deep links and older tests may reach the route before `main()` has
    // registered the service. Binding it permanently is the same lifetime.
    return Get.put<RemoteSessionRegistry>(
      RemoteSessionRegistry(),
      permanent: true,
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
