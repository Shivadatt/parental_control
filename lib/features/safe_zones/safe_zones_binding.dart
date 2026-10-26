import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';
import 'safe_zones_controller.dart';

class SafeZonesBinding extends Bindings {
  @override
  void dependencies() {
    final args = _routeArguments();
    Get.lazyPut<SafeZonesController>(
      () => SafeZonesController(
        locationRepository: Get.find<LocationRepository>(),
        familyRepository: Get.find<FamilyRepository>(),
        session: Get.find<SessionService>(),
        familyId: args['familyId'] ?? '',
        deviceId: args['deviceId'],
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
