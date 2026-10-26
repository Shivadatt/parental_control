import '../../core/utils/json_utils.dart';

class PairingCode {
  const PairingCode({
    required this.code,
    required this.qrPayload,
    required this.expiresAt,
  });

  final String code;
  final String qrPayload;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory PairingCode.fromJson(Map<String, dynamic> json) => PairingCode(
        code: jsonStringOr(json['code']),
        qrPayload: jsonStringOr(json['qr_payload']),
        expiresAt: jsonDateOr(
          json['expires_at'],
          DateTime.now().add(const Duration(minutes: 10)),
        ),
      );
}

enum PairingRequestStatus {
  pendingChild,
  approved,
  rejected,
  cancelled,
  expired;

  static PairingRequestStatus fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'approved':
        return PairingRequestStatus.approved;
      case 'rejected':
        return PairingRequestStatus.rejected;
      case 'cancelled':
        return PairingRequestStatus.cancelled;
      case 'expired':
        return PairingRequestStatus.expired;
      default:
        return PairingRequestStatus.pendingChild;
    }
  }

  String get wireName {
    switch (this) {
      case PairingRequestStatus.pendingChild:
        return 'pending_child';
      case PairingRequestStatus.approved:
        return 'approved';
      case PairingRequestStatus.rejected:
        return 'rejected';
      case PairingRequestStatus.cancelled:
        return 'cancelled';
      case PairingRequestStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case PairingRequestStatus.pendingChild:
        return 'Waiting for child approval';
      case PairingRequestStatus.approved:
        return 'Approved';
      case PairingRequestStatus.rejected:
        return 'Declined';
      case PairingRequestStatus.cancelled:
        return 'Cancelled';
      case PairingRequestStatus.expired:
        return 'Expired';
    }
  }
}

class PairingRequest {
  const PairingRequest({
    required this.id,
    required this.tokenId,
    required this.familyId,
    required this.familyName,
    required this.parentUserId,
    required this.parentDisplayName,
    required this.childUserId,
    required this.childDisplayName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  final String id;
  final String tokenId;
  final String familyId;
  final String familyName;
  final String parentUserId;
  final String parentDisplayName;
  final String childUserId;
  final String childDisplayName;
  final PairingRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  bool get isPending =>
      status == PairingRequestStatus.pendingChild && !isExpired;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory PairingRequest.fromJson(Map<String, dynamic> json) {
    final parentProfile = jsonMap(json['parent_profile']);
    final childProfile = jsonMap(json['child_profile']);
    final family = jsonMap(json['families']);
    return PairingRequest(
      id: jsonStringOr(json['id']),
      tokenId: jsonStringOr(json['token_id']),
      familyId: jsonStringOr(json['family_id']),
      familyName: jsonStringOr(family['name'], 'Family'),
      parentUserId: jsonStringOr(json['parent_user_id']),
      parentDisplayName: jsonStringOr(
        parentProfile['display_name'] ?? json['parent_display_name'],
        'Guardian',
      ),
      childUserId: jsonStringOr(json['child_user_id']),
      childDisplayName: jsonStringOr(
        childProfile['display_name'] ?? json['child_display_name'],
        'Child account',
      ),
      status: PairingRequestStatus.fromWire(json['status']),
      createdAt: jsonDateOr(json['created_at'], DateTime.now()),
      expiresAt: jsonDateOr(
        json['expires_at'],
        DateTime.now().add(const Duration(minutes: 10)),
      ),
      respondedAt: jsonDate(json['responded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'token_id': tokenId,
        'family_id': familyId,
        'family_name': familyName,
        'parent_user_id': parentUserId,
        'parent_display_name': parentDisplayName,
        'child_user_id': childUserId,
        'child_display_name': childDisplayName,
        'status': status.wireName,
        'created_at': createdAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'responded_at': respondedAt?.toUtc().toIso8601String(),
      };
}
