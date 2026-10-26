/// Small, tolerant JSON helpers for Supabase/Edge Function payloads.
Map<String, dynamic> jsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
  return const <String, dynamic>{};
}

List<dynamic> jsonList(Object? raw) => raw is List ? raw : const <dynamic>[];

String? jsonString(Object? raw) {
  if (raw == null) return null;
  if (raw is String) return raw;
  return raw.toString();
}

String jsonStringOr(Object? raw, [String fallback = '']) => jsonString(raw) ?? fallback;

int? jsonInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

int jsonIntOr(Object? raw, [int fallback = 0]) => jsonInt(raw) ?? fallback;

double? jsonDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

bool? jsonBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    if (raw.toLowerCase() == 'true') return true;
    if (raw.toLowerCase() == 'false') return false;
  }
  return null;
}

bool jsonBoolOr(Object? raw, [bool fallback = false]) => jsonBool(raw) ?? fallback;

DateTime? jsonDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = jsonString(raw);
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

DateTime jsonDateOr(Object? raw, DateTime fallback) => jsonDate(raw) ?? fallback;

DateTime? jsonDateFromMillis(Object? raw) {
  final millis = jsonInt(raw);
  if (millis == null || millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: false);
}

List<String> jsonStringList(Object? raw) =>
    jsonList(raw).map(jsonString).whereType<String>().toList(growable: false);

Map<String, dynamic> withoutNulls(Map<String, dynamic> map) =>
    Map<String, dynamic>.fromEntries(map.entries.where((entry) => entry.value != null));
