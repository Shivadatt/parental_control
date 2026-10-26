import '../../core/utils/formatters.dart';
import '../../core/utils/json_utils.dart';

class ScheduleWindow {
  const ScheduleWindow({
    required this.daysOfWeek,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// ISO weekday numbers: 1 = Monday … 7 = Sunday.
  final List<int> daysOfWeek;

  /// Minutes after local midnight, 0–1439.
  final int startMinutes;
  final int endMinutes;

  bool get spansMidnight => endMinutes <= startMinutes;

  bool isActiveAt(DateTime localTime) {
    if (daysOfWeek.isEmpty) return false;
    final day = localTime.weekday;
    final minute = localTime.hour * 60 + localTime.minute;
    if (!spansMidnight) {
      return daysOfWeek.contains(day) &&
          minute >= startMinutes &&
          minute < endMinutes;
    }
    if (daysOfWeek.contains(day) && minute >= startMinutes) return true;
    final previousDay = day == 1 ? 7 : day - 1;
    return daysOfWeek.contains(previousDay) && minute < endMinutes;
  }

  String get label =>
      '${formatTimeOfDayMinutes(startMinutes)} – ${formatTimeOfDayMinutes(endMinutes)}';

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) => ScheduleWindow(
        daysOfWeek: jsonList(json['days_of_week'])
            .map((value) => jsonInt(value))
            .whereType<int>()
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList(growable: false),
        startMinutes: (jsonIntOr(json['start_minutes'], 0)).clamp(0, 1439),
        endMinutes: (jsonIntOr(json['end_minutes'], 0)).clamp(0, 1439),
      );

  Map<String, dynamic> toJson() => {
        'days_of_week': daysOfWeek,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
      };
}

class AppRule {
  const AppRule({
    required this.packageName,
    required this.label,
    required this.blocked,
    this.windows = const [],
  });

  final String packageName;
  final String label;
  final bool blocked;
  final List<ScheduleWindow> windows;

  bool get isAlwaysBlocked => blocked && windows.isEmpty;

  bool isBlockActiveAt(DateTime localTime) {
    if (!blocked) return false;
    if (windows.isEmpty) return true;
    return windows.any((window) => window.isActiveAt(localTime));
  }

  factory AppRule.fromJson(Map<String, dynamic> json) => AppRule(
        packageName: jsonStringOr(json['package_name']),
        label: jsonStringOr(json['label'], jsonStringOr(json['package_name'])),
        blocked: jsonBoolOr(json['blocked']),
        windows: jsonList(json['windows'])
            .map((value) => ScheduleWindow.fromJson(jsonMap(value)))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'package_name': packageName,
        'label': label,
        'blocked': blocked,
        'windows': windows.map((window) => window.toJson()).toList(),
      };

  AppRule copyWith({
    String? packageName,
    String? label,
    bool? blocked,
    List<ScheduleWindow>? windows,
  }) =>
      AppRule(
        packageName: packageName ?? this.packageName,
        label: label ?? this.label,
        blocked: blocked ?? this.blocked,
        windows: windows ?? this.windows,
      );
}

class PolicyPayload {
  const PolicyPayload({
    this.enforceAppBlocks = true,
    this.blockAllExceptAllowed = false,
    this.blockedPackages = const [],
    this.allowedPackages = const [],
    this.appRules = const [],
    this.dailyScreenTimeLimitMinutes,
    this.bedtimeStartMinutes,
    this.bedtimeEndMinutes,
  });

  final bool enforceAppBlocks;
  final bool blockAllExceptAllowed;
  final List<String> blockedPackages;
  final List<String> allowedPackages;
  final List<AppRule> appRules;
  final int? dailyScreenTimeLimitMinutes;
  final int? bedtimeStartMinutes;
  final int? bedtimeEndMinutes;

  bool get hasBedtime =>
      bedtimeStartMinutes != null &&
      bedtimeEndMinutes != null &&
      bedtimeStartMinutes != bedtimeEndMinutes;

  bool isWithinBedtime(DateTime localTime) {
    if (!hasBedtime) return false;
    final minute = localTime.hour * 60 + localTime.minute;
    final start = bedtimeStartMinutes!;
    final end = bedtimeEndMinutes!;
    if (start < end) return minute >= start && minute < end;
    return minute >= start || minute < end;
  }

  bool isPackageBlockedNow(String packageName, DateTime localTime) {
    if (!enforceAppBlocks) return false;
    for (final rule in appRules) {
      if (rule.packageName == packageName) {
        return rule.isBlockActiveAt(localTime);
      }
    }
    if (blockedPackages.contains(packageName)) {
      return !blockAllExceptAllowed || !allowedPackages.contains(packageName);
    }
    if (blockAllExceptAllowed) return !allowedPackages.contains(packageName);
    return false;
  }

  PolicyPayload copyWith({
    bool? enforceAppBlocks,
    bool? blockAllExceptAllowed,
    List<String>? blockedPackages,
    List<String>? allowedPackages,
    List<AppRule>? appRules,
    int? dailyScreenTimeLimitMinutes,
    bool clearDailyLimit = false,
    int? bedtimeStartMinutes,
    int? bedtimeEndMinutes,
    bool clearBedtime = false,
  }) =>
      PolicyPayload(
        enforceAppBlocks: enforceAppBlocks ?? this.enforceAppBlocks,
        blockAllExceptAllowed:
            blockAllExceptAllowed ?? this.blockAllExceptAllowed,
        blockedPackages: blockedPackages ?? this.blockedPackages,
        allowedPackages: allowedPackages ?? this.allowedPackages,
        appRules: appRules ?? this.appRules,
        dailyScreenTimeLimitMinutes: clearDailyLimit
            ? null
            : (dailyScreenTimeLimitMinutes ??
                this.dailyScreenTimeLimitMinutes),
        bedtimeStartMinutes: clearBedtime
            ? null
            : (bedtimeStartMinutes ?? this.bedtimeStartMinutes),
        bedtimeEndMinutes:
            clearBedtime ? null : (bedtimeEndMinutes ?? this.bedtimeEndMinutes),
      );

  factory PolicyPayload.fromJson(Map<String, dynamic> json) => PolicyPayload(
        enforceAppBlocks: jsonBoolOr(json['enforce_app_blocks'], true),
        blockAllExceptAllowed: jsonBoolOr(json['block_all_except_allowed']),
        blockedPackages: jsonStringList(json['blocked_packages']),
        allowedPackages: jsonStringList(json['allowed_packages']),
        appRules: jsonList(json['app_rules'])
            .map((value) => AppRule.fromJson(jsonMap(value)))
            .toList(growable: false),
        dailyScreenTimeLimitMinutes: jsonInt(json['daily_screen_time_limit_minutes']),
        bedtimeStartMinutes: jsonInt(json['bedtime_start_minutes']),
        bedtimeEndMinutes: jsonInt(json['bedtime_end_minutes']),
      );

  Map<String, dynamic> toJson() => withoutNulls({
        'enforce_app_blocks': enforceAppBlocks,
        'block_all_except_allowed': blockAllExceptAllowed,
        'blocked_packages': blockedPackages,
        'allowed_packages': allowedPackages,
        'app_rules': appRules.map((rule) => rule.toJson()).toList(),
        'daily_screen_time_limit_minutes': dailyScreenTimeLimitMinutes,
        'bedtime_start_minutes': bedtimeStartMinutes,
        'bedtime_end_minutes': bedtimeEndMinutes,
      });
}

enum PolicyEnforcementStatus {
  pending,
  enforced,
  failed,
  unsupported;

  static PolicyEnforcementStatus fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'enforced':
        return PolicyEnforcementStatus.enforced;
      case 'failed':
        return PolicyEnforcementStatus.failed;
      case 'unsupported':
        return PolicyEnforcementStatus.unsupported;
      default:
        return PolicyEnforcementStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case PolicyEnforcementStatus.pending:
        return 'Waiting for device';
      case PolicyEnforcementStatus.enforced:
        return 'Enforced on device';
      case PolicyEnforcementStatus.failed:
        return 'Enforcement failed';
      case PolicyEnforcementStatus.unsupported:
        return 'Not supported on device';
    }
  }
}

class DevicePolicy {
  const DevicePolicy({
    required this.id,
    required this.deviceId,
    required this.version,
    required this.payload,
    required this.createdAt,
    required this.status,
    this.createdBy,
    this.acknowledgedAt,
    this.lastError,
  });

  final String id;
  final String deviceId;
  final int version;
  final PolicyPayload payload;
  final DateTime createdAt;
  final PolicyEnforcementStatus status;
  final String? createdBy;
  final DateTime? acknowledgedAt;
  final String? lastError;

  bool get isAcknowledged => acknowledgedAt != null;

  factory DevicePolicy.fromJson(Map<String, dynamic> json) => DevicePolicy(
        id: jsonStringOr(json['id']),
        deviceId: jsonStringOr(json['device_id']),
        version: jsonIntOr(json['version'], 1),
        payload: PolicyPayload.fromJson(jsonMap(json['policy'])),
        createdAt: jsonDateOr(json['created_at'], DateTime.now()),
        status: PolicyEnforcementStatus.fromWire(json['enforcement_status']),
        createdBy: jsonString(json['created_by']),
        acknowledgedAt: jsonDate(json['acknowledged_at']),
        lastError: jsonString(json['last_error']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'version': version,
        'policy': payload.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'enforcement_status': status.name,
        'created_by': createdBy,
        'acknowledged_at': acknowledgedAt?.toUtc().toIso8601String(),
        'last_error': lastError,
      };
}

enum DeviceStatus {
  pending,
  active,
  revoked;

  static DeviceStatus fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'active':
        return DeviceStatus.active;
      case 'revoked':
        return DeviceStatus.revoked;
      default:
        return DeviceStatus.pending;
    }
  }

  String get wireName => name;
}

class Device {
  const Device({
    required this.id,
    required this.familyId,
    required this.childUserId,
    required this.displayName,
    required this.status,
    this.platform = 'android',
    this.androidVersion,
    this.appVersion,
    this.lastSeenAt,
    this.batteryLevel,
    this.isCharging,
    this.enforcementMode,
    this.policyVersion,
    this.usageAccessGranted,
    this.locationGranted,
    this.backgroundLocationGranted,
    this.cameraGranted,
    this.microphoneGranted,
    this.notificationsGranted,
    this.createdAt,
    this.credentialIssuedAt,
  });

  final String id;
  final String familyId;
  final String childUserId;
  final String displayName;
  final DeviceStatus status;
  final String platform;
  final String? androidVersion;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final int? batteryLevel;
  final bool? isCharging;
  final String? enforcementMode;
  final int? policyVersion;
  final bool? usageAccessGranted;
  final bool? locationGranted;
  final bool? backgroundLocationGranted;
  final bool? cameraGranted;
  final bool? microphoneGranted;
  final bool? notificationsGranted;
  final DateTime? createdAt;
  final DateTime? credentialIssuedAt;

  bool get isActive => status == DeviceStatus.active;
  bool get isRevoked => status == DeviceStatus.revoked;

  bool get isOnline {
    final seen = lastSeenAt;
    if (seen == null) return false;
    return DateTime.now().difference(seen) < const Duration(minutes: 3);
  }

  bool get isFullyManaged => enforcementMode == 'device_owner';

  String get statusLabel {
    if (isRevoked) return 'Revoked';
    if (!isActive) return 'Pending enrollment';
    return isOnline ? 'Online' : 'Offline';
  }

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: jsonStringOr(json['id']),
        familyId: jsonStringOr(json['family_id']),
        childUserId: jsonStringOr(json['child_user_id']),
        displayName: jsonStringOr(json['display_name'], 'Android device'),
        status: DeviceStatus.fromWire(json['status']),
        platform: jsonStringOr(json['platform'], 'android'),
        androidVersion: jsonString(json['android_version']),
        appVersion: jsonString(json['app_version']),
        lastSeenAt: jsonDate(json['last_seen_at']),
        batteryLevel: jsonInt(json['battery_level']),
        isCharging: jsonBool(json['is_charging']),
        enforcementMode: jsonString(json['enforcement_mode']),
        policyVersion: jsonInt(json['policy_version']),
        usageAccessGranted: jsonBool(json['usage_access_granted']),
        locationGranted: jsonBool(json['location_granted']),
        backgroundLocationGranted: jsonBool(json['background_location_granted']),
        cameraGranted: jsonBool(json['camera_granted']),
        microphoneGranted: jsonBool(json['microphone_granted']),
        notificationsGranted: jsonBool(json['notifications_granted']),
        createdAt: jsonDate(json['created_at']),
        credentialIssuedAt: jsonDate(json['credential_issued_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'child_user_id': childUserId,
        'display_name': displayName,
        'status': status.wireName,
        'platform': platform,
        'android_version': androidVersion,
        'app_version': appVersion,
        'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
        'battery_level': batteryLevel,
        'is_charging': isCharging,
        'enforcement_mode': enforcementMode,
        'policy_version': policyVersion,
        'usage_access_granted': usageAccessGranted,
        'location_granted': locationGranted,
        'background_location_granted': backgroundLocationGranted,
        'camera_granted': cameraGranted,
        'microphone_granted': microphoneGranted,
        'notifications_granted': notificationsGranted,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'credential_issued_at': credentialIssuedAt?.toUtc().toIso8601String(),
      };
}

class PolicyUpdateResult {
  const PolicyUpdateResult({required this.policy, required this.command});

  final DevicePolicy policy;
  final DeviceCommand command;
}

enum DeviceCommandType {
  applyPolicy,
  syncPolicy,
  requestUsage,
  requestLocation,
  endSession,
  custom;

  static DeviceCommandType fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'apply_policy':
        return DeviceCommandType.applyPolicy;
      case 'sync_policy':
        return DeviceCommandType.syncPolicy;
      case 'request_usage':
        return DeviceCommandType.requestUsage;
      case 'request_location':
        return DeviceCommandType.requestLocation;
      case 'end_session':
        return DeviceCommandType.endSession;
      default:
        return DeviceCommandType.custom;
    }
  }

  String get wireName {
    switch (this) {
      case DeviceCommandType.applyPolicy:
        return 'apply_policy';
      case DeviceCommandType.syncPolicy:
        return 'sync_policy';
      case DeviceCommandType.requestUsage:
        return 'request_usage';
      case DeviceCommandType.requestLocation:
        return 'request_location';
      case DeviceCommandType.endSession:
        return 'end_session';
      case DeviceCommandType.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case DeviceCommandType.applyPolicy:
        return 'Apply policy';
      case DeviceCommandType.syncPolicy:
        return 'Sync policy';
      case DeviceCommandType.requestUsage:
        return 'Request usage';
      case DeviceCommandType.requestLocation:
        return 'Request location';
      case DeviceCommandType.endSession:
        return 'End session';
      case DeviceCommandType.custom:
        return 'Command';
    }
  }
}

enum DeviceCommandStatus {
  pending,
  delivered,
  succeeded,
  failed,
  expired;

  static DeviceCommandStatus fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'delivered':
        return DeviceCommandStatus.delivered;
      case 'succeeded':
      case 'acked':
        return DeviceCommandStatus.succeeded;
      case 'failed':
        return DeviceCommandStatus.failed;
      case 'expired':
        return DeviceCommandStatus.expired;
      default:
        return DeviceCommandStatus.pending;
    }
  }

  String get wireName {
    switch (this) {
      case DeviceCommandStatus.pending:
        return 'pending';
      case DeviceCommandStatus.delivered:
        return 'delivered';
      case DeviceCommandStatus.succeeded:
        return 'succeeded';
      case DeviceCommandStatus.failed:
        return 'failed';
      case DeviceCommandStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case DeviceCommandStatus.pending:
        return 'Queued';
      case DeviceCommandStatus.delivered:
        return 'Delivered';
      case DeviceCommandStatus.succeeded:
        return 'Succeeded';
      case DeviceCommandStatus.failed:
        return 'Failed';
      case DeviceCommandStatus.expired:
        return 'Expired';
    }
  }
}

class DeviceCommand {
  const DeviceCommand({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.deliveredAt,
    this.ackedAt,
    this.result,
    this.error,
  });

  final String id;
  final String deviceId;
  final DeviceCommandType type;
  final Map<String, dynamic> payload;
  final DeviceCommandStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? deliveredAt;
  final DateTime? ackedAt;
  final Map<String, dynamic>? result;
  final String? error;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) && status != DeviceCommandStatus.succeeded;

  factory DeviceCommand.fromJson(Map<String, dynamic> json) => DeviceCommand(
        id: jsonStringOr(json['id']),
        deviceId: jsonStringOr(json['device_id']),
        type: DeviceCommandType.fromWire(json['type']),
        payload: jsonMap(json['payload']),
        status: DeviceCommandStatus.fromWire(json['status']),
        createdAt: jsonDateOr(json['created_at'], DateTime.now()),
        expiresAt: jsonDateOr(json['expires_at'], DateTime.now()),
        deliveredAt: jsonDate(json['delivered_at']),
        ackedAt: jsonDate(json['acked_at']),
        result: json['result'] == null ? null : jsonMap(json['result']),
        error: jsonString(json['error_message']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'type': type.wireName,
        'payload': payload,
        'status': status.wireName,
        'created_at': createdAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'delivered_at': deliveredAt?.toUtc().toIso8601String(),
        'acked_at': ackedAt?.toUtc().toIso8601String(),
        'result': result,
        'error_message': error,
      };
}

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.isSystem = false,
    this.isSuspended = false,
    this.versionName,
  });

  final String packageName;
  final String label;
  final bool isSystem;
  final bool isSuspended;
  final String? versionName;

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
        packageName: jsonStringOr(json['packageName'] ?? json['package_name']),
        label: jsonStringOr(json['label'], jsonStringOr(json['packageName'])),
        isSystem: jsonBoolOr(json['isSystem'] ?? json['is_system']),
        isSuspended: jsonBoolOr(json['isSuspended'] ?? json['is_suspended']),
        versionName: jsonString(json['versionName'] ?? json['version_name']),
      );
}

class DeviceCapabilities {
  const DeviceCapabilities({
    this.available = false,
    this.isDeviceOwner = false,
    this.isAdminActive = false,
    this.canSuspendPackages = false,
    this.sdkInt = 0,
    this.manufacturer = '',
    this.model = '',
    this.androidVersion = '',
    this.appVersion = '',
    this.usageAccessGranted = false,
    this.fineLocationGranted = false,
    this.backgroundLocationGranted = false,
    this.cameraGranted = false,
    this.microphoneGranted = false,
    this.notificationsGranted = false,
    this.guardianServiceRunning = false,
  });

  final bool available;
  final bool isDeviceOwner;
  final bool isAdminActive;
  final bool canSuspendPackages;
  final int sdkInt;
  final String manufacturer;
  final String model;
  final String androidVersion;
  final String appVersion;
  final bool usageAccessGranted;
  final bool fineLocationGranted;
  final bool backgroundLocationGranted;
  final bool cameraGranted;
  final bool microphoneGranted;
  final bool notificationsGranted;
  final bool guardianServiceRunning;

  bool get isFullyManaged => isDeviceOwner && canSuspendPackages;
  String get deviceLabel => [manufacturer, model].where((part) => part.isNotEmpty).join(' ');

  factory DeviceCapabilities.empty() => const DeviceCapabilities();

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) {
    final permissions = jsonMap(json['permissions']);
    return DeviceCapabilities(
      available: jsonBoolOr(json['available'], true),
      isDeviceOwner: jsonBoolOr(json['isDeviceOwner']),
      isAdminActive: jsonBoolOr(json['isAdminActive']),
      canSuspendPackages: jsonBoolOr(json['canSuspendPackages']),
      sdkInt: jsonIntOr(json['sdkInt']),
      manufacturer: jsonStringOr(json['manufacturer']),
      model: jsonStringOr(json['model']),
      androidVersion: jsonStringOr(json['androidVersion']),
      appVersion: jsonStringOr(json['appVersion']),
      usageAccessGranted: jsonBoolOr(
        json['usageAccessGranted'] ?? permissions['usageAccess'],
      ),
      fineLocationGranted: jsonBoolOr(
        json['fineLocationGranted'] ?? permissions['fineLocation'],
      ),
      backgroundLocationGranted: jsonBoolOr(
        json['backgroundLocationGranted'] ?? permissions['backgroundLocation'],
      ),
      cameraGranted:
          jsonBoolOr(json['cameraGranted'] ?? permissions['camera']),
      microphoneGranted:
          jsonBoolOr(json['microphoneGranted'] ?? permissions['microphone']),
      notificationsGranted: jsonBoolOr(
        json['notificationsGranted'] ?? permissions['notifications'],
      ),
      guardianServiceRunning: jsonBoolOr(json['guardianServiceRunning']),
    );
  }
}

class DeviceIdentity {
  const DeviceIdentity({
    required this.installationId,
    required this.secret,
    required this.secretHash,
    this.serverDeviceId,
  });

  final String installationId;

  /// Raw credential. Kept in the platform keystore by the native layer and
  /// only sent to Edge Functions over TLS.
  final String secret;

  /// SHA-256 hex digest registered with the server; the raw value is never stored.
  final String secretHash;
  final String? serverDeviceId;

  DeviceIdentity copyWith({String? serverDeviceId}) => DeviceIdentity(
        installationId: installationId,
        secret: secret,
        secretHash: secretHash,
        serverDeviceId: serverDeviceId ?? this.serverDeviceId,
      );

  Map<String, String> authHeaders() {
    final id = serverDeviceId;
    if (id == null || id.isEmpty) {
      throw StateError('Device is not registered with the backend yet');
    }
    return {
      'x-device-id': id,
      'x-device-secret': secret,
    };
  }
}

class NativePolicyApplyResult {
  const NativePolicyApplyResult({
    required this.success,
    required this.appliedAt,
    this.suspendedPackages = const [],
    this.unsupportedPackages = const [],
    this.errors = const [],
    this.serviceRunning = false,
  });

  final bool success;
  final DateTime appliedAt;
  final List<String> suspendedPackages;
  final List<String> unsupportedPackages;
  final List<String> errors;
  final bool serviceRunning;

  Map<String, dynamic> toJson() => {
        'success': success,
        'applied_at': appliedAt.toUtc().toIso8601String(),
        'suspended_packages': suspendedPackages,
        'unsupported_packages': unsupportedPackages,
        'errors': errors,
      };

  factory NativePolicyApplyResult.fromJson(Map<String, dynamic> json) =>
      NativePolicyApplyResult(
        success: jsonBoolOr(json['success']),
        appliedAt: jsonDateOr(json['applied_at'], DateTime.now()),
        suspendedPackages: jsonStringList(json['suspended_packages']),
        unsupportedPackages: jsonStringList(json['unsupported_packages']),
        errors: jsonStringList(json['errors']),
        serviceRunning: jsonBoolOr(json['service_running']),
      );
}

class GuardianServiceStatus {
  const GuardianServiceStatus({
    this.running = false,
    this.lastPollAt,
    this.lastError,
    this.queuedCommands = 0,
  });

  final bool running;
  final DateTime? lastPollAt;
  final String? lastError;
  final int queuedCommands;

  factory GuardianServiceStatus.fromJson(Map<String, dynamic> json) =>
      GuardianServiceStatus(
        running: jsonBoolOr(json['running']),
        lastPollAt: jsonDateFromMillis(json['lastPollAtMillis']) ??
            jsonDate(json['last_poll_at']),
        lastError: jsonString(json['lastError'] ?? json['last_error']),
        queuedCommands: jsonIntOr(json['queuedCommands']),
      );
}

class BatteryStatus {
  const BatteryStatus({this.level, this.isCharging});

  final int? level;
  final bool? isCharging;

  factory BatteryStatus.fromJson(Map<String, dynamic> json) => BatteryStatus(
        level: jsonInt(json['level']),
        isCharging: jsonBool(json['isCharging']),
      );

  factory BatteryStatus.unknown() => const BatteryStatus();
}
