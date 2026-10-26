import '../../core/utils/json_utils.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.familyId,
    this.actorUserId,
    this.actorDisplayName,
    this.deviceId,
    this.targetType,
    this.targetId,
    this.metadata = const {},
  });

  final String id;
  final String? familyId;
  final String? actorUserId;
  final String? actorDisplayName;
  final String? deviceId;
  final String eventType;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  String get readableEvent {
    switch (eventType) {
      case 'family_created':
        return 'Family created';
      case 'member_joined':
        return 'Child account linked';
      case 'member_removed':
        return 'Child account unlinked';
      case 'pairing_code_created':
        return 'Linking code generated';
      case 'pairing_redeemed':
        return 'Linking code redeemed';
      case 'pairing_approved':
        return 'Pairing approved';
      case 'pairing_rejected':
        return 'Pairing declined';
      case 'device_registered':
        return 'Device enrolled';
      case 'device_revoked':
        return 'Device credential revoked';
      case 'policy_updated':
        return 'Restriction policy updated';
      case 'command_acked':
        return 'Device acknowledged command';
      case 'command_failed':
        return 'Device reported command failure';
      case 'session_requested':
        return 'Assistance requested';
      case 'session_accepted':
        return 'Assistance accepted';
      case 'session_declined':
        return 'Assistance declined';
      case 'session_started':
        return 'Assistance session started';
      case 'session_ended':
        return 'Assistance session ended';
      case 'alert_acknowledged':
        return 'Alert acknowledged';
      case 'data_purged':
        return 'Historical data purged';
      case 'settings_updated':
        return 'Settings updated';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = jsonMap(json['actor_profile']);
    return AuditLogEntry(
      id: jsonStringOr(json['id']),
      familyId: jsonString(json['family_id']),
      actorUserId: jsonString(json['actor_user_id']),
      actorDisplayName: jsonString(actor['display_name'] ?? json['actor_display_name']),
      deviceId: jsonString(json['device_id']),
      eventType: jsonStringOr(json['event_type'], 'event'),
      targetType: jsonString(json['target_type']),
      targetId: jsonString(json['target_id']),
      metadata: jsonMap(json['metadata']),
      createdAt: jsonDateOr(json['created_at'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'actor_user_id': actorUserId,
        'actor_display_name': actorDisplayName,
        'device_id': deviceId,
        'event_type': eventType,
        'target_type': targetType,
        'target_id': targetId,
        'metadata': metadata,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
