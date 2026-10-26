import '../../core/utils/json_utils.dart';

enum ProfileRole {
  unset,
  parent,
  child;

  static ProfileRole fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'parent':
        return ProfileRole.parent;
      case 'child':
        return ProfileRole.child;
      default:
        return ProfileRole.unset;
    }
  }

  String get wireName => name;
  bool get isParent => this == ProfileRole.parent;
  bool get isChild => this == ProfileRole.child;
  bool get isChosen => this != ProfileRole.unset;
}

class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.displayName,
    this.createdAt,
  });

  final String id;
  final ProfileRole role;
  final String displayName;
  final DateTime? createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: jsonStringOr(json['id']),
        role: ProfileRole.fromWire(json['role']),
        displayName: jsonStringOr(json['display_name'], 'Unnamed account'),
        createdAt: jsonDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.wireName,
        'display_name': displayName,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };
}

class FamilySettings {
  const FamilySettings({
    this.locationRetentionDays = 30,
    this.usageRetentionDays = 90,
  });

  final int locationRetentionDays;
  final int usageRetentionDays;

  factory FamilySettings.fromMap(Object? raw) {
    final map = jsonMap(raw);
    return FamilySettings(
      locationRetentionDays: jsonIntOr(map['location_retention_days'], 30),
      usageRetentionDays: jsonIntOr(map['usage_retention_days'], 90),
    );
  }

  Map<String, dynamic> toJson() => {
        'location_retention_days': locationRetentionDays,
        'usage_retention_days': usageRetentionDays,
      };
}

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.settings,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final FamilySettings settings;
  final DateTime? createdAt;

  factory Family.fromJson(Map<String, dynamic> json) => Family(
        id: jsonStringOr(json['id']),
        name: jsonStringOr(json['name'], 'Family'),
        ownerId: jsonStringOr(json['owner_id']),
        settings: FamilySettings.fromMap(json['settings']),
        createdAt: jsonDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'settings': settings.toJson(),
        'created_at': createdAt?.toUtc().toIso8601String(),
      };
}

enum FamilyMemberRole {
  parent,
  child;

  static FamilyMemberRole fromWire(Object? raw) =>
      jsonString(raw) == 'child' ? FamilyMemberRole.child : FamilyMemberRole.parent;

  String get wireName => name;
}

enum FamilyMemberStatus {
  active,
  removed;

  static FamilyMemberStatus fromWire(Object? raw) =>
      jsonString(raw) == 'removed' ? FamilyMemberStatus.removed : FamilyMemberStatus.active;

  String get wireName => name;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    required this.displayName,
    this.joinedAt,
  });

  final String id;
  final String familyId;
  final String userId;
  final FamilyMemberRole role;
  final FamilyMemberStatus status;
  final String displayName;
  final DateTime? joinedAt;

  bool get isActive => status == FamilyMemberStatus.active;
  bool get isChild => role == FamilyMemberRole.child;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final profile = jsonMap(json['profiles']);
    return FamilyMember(
      id: jsonStringOr(json['id']),
      familyId: jsonStringOr(json['family_id']),
      userId: jsonStringOr(json['user_id']),
      role: FamilyMemberRole.fromWire(json['role']),
      status: FamilyMemberStatus.fromWire(json['status']),
      displayName: jsonStringOr(
        profile['display_name'] ?? json['display_name'],
        'Family member',
      ),
      joinedAt: jsonDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'user_id': userId,
        'role': role.wireName,
        'status': status.wireName,
        'display_name': displayName,
        'created_at': joinedAt?.toUtc().toIso8601String(),
      };
}
