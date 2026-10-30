import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/session_service.dart';
import 'remote_session_controller.dart';
import 'remote_session_registry.dart';

class RemoteSessionBinding extends Bindings {
  @override
  void dependencies() {
    final args = _routeArguments();
    final sessionId = args['sessionId'] ?? '';
    final role = _resolveRole(args['role']);
    // The controller is owned by the registry, not by this route, so popping
    // the session screen cannot end a live, consented session.
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

  /// Roles are deny-by-default. A missing or invalid role used to fall back to
  /// `''`, which made [RemoteSessionController.isViewOnly] true but still let
  /// the screen take the mic-capable branch. Unknown roles now resolve to a
  /// literal view-only value that can never capture audio.
  String _resolveRole(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'parent' || normalized == 'child') return normalized;
    return 'view-only';
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
