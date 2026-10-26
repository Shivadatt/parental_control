import 'package:get/get.dart';

/// Reads page arguments supplied through `Get.arguments` first and falls back
/// to query parameters (`Get.parameters`). Pages only use this for presentation
/// values; authorization always happens on the server.
Object? routeValue(String key) {
  final arguments = Get.arguments;
  if (arguments is Map && arguments.containsKey(key)) {
    return arguments[key];
  }
  return Get.parameters[key];
}

String? routeString(String key) {
  final value = routeValue(key);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool routeFlag(String key) {
  final value = routeValue(key);
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == 'true' || normalized == '1' ||
        normalized == 'lock';
  }
  return false;
}
