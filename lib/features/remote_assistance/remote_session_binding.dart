import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/session_service.dart';
import 'remote_session_controller.dart';

class RemoteSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.delete<RemoteSessionController>(force: true);
    Get.lazyPut<RemoteSessionController>(
      () {
        final args = _routeArguments();
        return RemoteSessionController(
          remoteSessionRepository: Get.find<RemoteSessionRepository>(),
          session: Get.find<SessionService>(),
          deviceAdmin: Get.find<DeviceAdminService>(),
          sessionId: args['sessionId'] ?? '',
          role: _resolveRole(args['role']),
        );
      },
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
