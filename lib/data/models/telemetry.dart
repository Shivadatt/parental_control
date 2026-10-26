import '../../core/utils/json_utils.dart';

class UsageDaily {
  const UsageDaily({
    required this.deviceId,
    required this.day,
    required this.packageName,
    required this.appLabel,
    required this.totalMs,
    this.lastUsedAt,
    this.uploadedAt,
    this.source = 'usage_stats',
  });

  final String deviceId;
  final DateTime day;
  final String packageName;
  final String appLabel;
  final int totalMs;
  final DateTime? lastUsedAt;
  final DateTime? uploadedAt;
  final String source;

  bool get isStale {
    final uploaded = uploadedAt;
    if (uploaded == null) return true;
    return DateTime.now().difference(uploaded) > const Duration(hours: 24);
  }

  factory UsageDaily.fromJson(Map<String, dynamic> json) => UsageDaily(
        deviceId: jsonStringOr(json['device_id']),
        day: jsonDateOr(json['day'], DateTime.now()),
        packageName: jsonStringOr(json['package_name']),
        appLabel: jsonStringOr(
          json['app_label'],
          jsonStringOr(json['package_name']),
        ),
        totalMs: jsonIntOr(json['total_ms']),
        lastUsedAt: jsonDate(json['last_used_at']),
        uploadedAt: jsonDate(json['uploaded_at']),
        source: jsonStringOr(json['source'], 'usage_stats'),
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'day': day.toIso8601String().split('T').first,
        'package_name': packageName,
        'app_label': appLabel,
        'total_ms': totalMs,
        'last_used_at': lastUsedAt?.toUtc().toIso8601String(),
        'uploaded_at': uploadedAt?.toUtc().toIso8601String(),
        'source': source,
      };

  Map<String, dynamic> toUploadJson() => {
        'day': day.toIso8601String().split('T').first,
        'package_name': packageName,
        'app_label': appLabel,
        'total_ms': totalMs,
        'last_used_at': lastUsedAt?.toUtc().toIso8601String(),
      };
}

class UsageStat {
  const UsageStat({
    required this.packageName,
    required this.label,
    required this.totalMs,
    this.lastUsedAt,
  });

  final String packageName;
  final String label;
  final int totalMs;
  final DateTime? lastUsedAt;

  factory UsageStat.fromJson(Map<String, dynamic> json) => UsageStat(
        packageName: jsonStringOr(json['packageName'] ?? json['package_name']),
        label: jsonStringOr(json['label'], jsonStringOr(json['packageName'])),
        totalMs: jsonIntOr(json['totalMs'] ?? json['total_ms']),
        lastUsedAt: jsonDateFromMillis(json['lastUsedAtMillis']) ??
            jsonDate(json['last_used_at']),
      );
}

class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.recordedAt,
    this.source = 'device',
    this.isMock = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime recordedAt;
  final String source;
  final bool isMock;

  bool get isStale =>
      DateTime.now().difference(recordedAt) > const Duration(minutes: 10);

  Map<String, dynamic> toUploadJson() => {
        'lat': latitude,
        'lng': longitude,
        'accuracy_m': accuracyM,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'source': source,
      };

  factory LocationFix.fromJson(Map<String, dynamic> json) => LocationFix(
        latitude: jsonDouble(json['latitude'] ?? json['lat']) ?? 0,
        longitude: jsonDouble(json['longitude'] ?? json['lng']) ?? 0,
        accuracyM: jsonDouble(json['accuracyM'] ?? json['accuracy_m']) ?? 0,
        recordedAt: jsonDateFromMillis(json['timestampMillis']) ??
            jsonDateOr(json['recorded_at'], DateTime.now()),
        source: jsonStringOr(json['source'], 'device'),
        isMock: jsonBoolOr(json['isMock'] ?? json['is_mock']),
      );
}

class LocationEvent {
  const LocationEvent({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.recordedAt,
    required this.receivedAt,
    this.source = 'device',
  });

  final String id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime recordedAt;
  final DateTime receivedAt;
  final String source;

  bool get isStale =>
      DateTime.now().difference(recordedAt) > const Duration(minutes: 10);

  factory LocationEvent.fromJson(Map<String, dynamic> json) => LocationEvent(
        id: jsonStringOr(json['id']),
        deviceId: jsonStringOr(json['device_id']),
        latitude: jsonDouble(json['lat']) ?? 0,
        longitude: jsonDouble(json['lng']) ?? 0,
        accuracyM: jsonDouble(json['accuracy_m']) ?? 0,
        recordedAt: jsonDateOr(json['recorded_at'], DateTime.now()),
        receivedAt: jsonDateOr(json['received_at'], DateTime.now()),
        source: jsonStringOr(json['source'], 'device'),
      );
}

class SafeZone {
  const SafeZone({
    required this.id,
    required this.familyId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String familyId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;
  final bool active;
  final DateTime? createdAt;

  factory SafeZone.fromJson(Map<String, dynamic> json) => SafeZone(
        id: jsonStringOr(json['id']),
        familyId: jsonStringOr(json['family_id']),
        name: jsonStringOr(json['name'], 'Safe zone'),
        latitude: jsonDouble(json['lat']) ?? 0,
        longitude: jsonDouble(json['lng']) ?? 0,
        radiusM: jsonDouble(json['radius_m']) ?? 100,
        active: jsonBoolOr(json['active'], true),
        createdAt: jsonDate(json['created_at']),
      );

  Map<String, dynamic> toUpsertJson(String familyId) => {
        'family_id': familyId,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'radius_m': radiusM,
        'active': active,
      };
}

enum SafetyAlertType {
  lowBattery,
  deviceOffline,
  geofenceEnter,
  geofenceExit,
  appBlocked,
  permissionMissing,
  other;

  static SafetyAlertType fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'low_battery':
        return SafetyAlertType.lowBattery;
      case 'offline':
        return SafetyAlertType.deviceOffline;
      case 'geofence_enter':
        return SafetyAlertType.geofenceEnter;
      case 'geofence_exit':
        return SafetyAlertType.geofenceExit;
      case 'app_blocked':
        return SafetyAlertType.appBlocked;
      case 'permission_missing':
        return SafetyAlertType.permissionMissing;
      default:
        return SafetyAlertType.other;
    }
  }

  String get label {
    switch (this) {
      case SafetyAlertType.lowBattery:
        return 'Low battery';
      case SafetyAlertType.deviceOffline:
        return 'Device offline';
      case SafetyAlertType.geofenceEnter:
        return 'Entered safe zone';
      case SafetyAlertType.geofenceExit:
        return 'Left safe zone';
      case SafetyAlertType.appBlocked:
        return 'App blocked';
      case SafetyAlertType.permissionMissing:
        return 'Permission missing';
      case SafetyAlertType.other:
        return 'Alert';
    }
  }
}

enum AlertSeverity {
  info,
  warning,
  critical;

  static AlertSeverity fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }
}

class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.familyId,
    required this.deviceId,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.payload = const {},
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.deviceName,
  });

  final String id;
  final String familyId;
  final String deviceId;
  final SafetyAlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final String? deviceName;

  bool get isAcknowledged => acknowledgedAt != null;

  factory SafetyAlert.fromJson(Map<String, dynamic> json) {
    final device = jsonMap(json['devices']);
    return SafetyAlert(
      id: jsonStringOr(json['id']),
      familyId: jsonStringOr(json['family_id']),
      deviceId: jsonStringOr(json['device_id']),
      type: SafetyAlertType.fromWire(json['type']),
      severity: AlertSeverity.fromWire(json['severity']),
      message: jsonStringOr(json['message'], 'Safety alert'),
      createdAt: jsonDateOr(json['created_at'], DateTime.now()),
      payload: jsonMap(json['payload']),
      acknowledgedAt: jsonDate(json['acknowledged_at']),
      acknowledgedBy: jsonString(json['acknowledged_by']),
      deviceName: jsonString(device['display_name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'device_id': deviceId,
        'type': type.name,
        'severity': severity.name,
        'message': message,
        'created_at': createdAt.toUtc().toIso8601String(),
        'payload': payload,
        'acknowledged_at': acknowledgedAt?.toUtc().toIso8601String(),
        'acknowledged_by': acknowledgedBy,
        'device_name': deviceName,
      };
}
