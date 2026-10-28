import '../../core/utils/json_utils.dart';

enum SessionKind {
  audio,
  video;

  static SessionKind fromWire(Object? raw) =>
      jsonString(raw) == 'audio' ? SessionKind.audio : SessionKind.video;

  String get wireName => name;
  String get label => this == SessionKind.video ? 'Video assistance' : 'Audio assistance';
}

enum RemoteSessionStatus {
  requested,
  accepted,
  active,
  declined,
  ended,
  expired,
  failed;

  static RemoteSessionStatus fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'accepted':
        return RemoteSessionStatus.accepted;
      case 'active':
        return RemoteSessionStatus.active;
      case 'declined':
        return RemoteSessionStatus.declined;
      case 'ended':
        return RemoteSessionStatus.ended;
      case 'expired':
        return RemoteSessionStatus.expired;
      case 'failed':
        return RemoteSessionStatus.failed;
      default:
        return RemoteSessionStatus.requested;
    }
  }

  String get wireName => name;

  bool get isOpen =>
      this == RemoteSessionStatus.requested ||
      this == RemoteSessionStatus.accepted ||
      this == RemoteSessionStatus.active;

  bool get isTerminal => !isOpen;

  /// The server's status, worded so it never claims media is flowing.
  ///
  /// `active` means the server considers the session started, not that any
  /// audio or video track is connected.
  String get label {
    switch (this) {
      case RemoteSessionStatus.requested:
        return 'Waiting for consent';
      case RemoteSessionStatus.accepted:
        return 'Accepted';
      case RemoteSessionStatus.active:
        return 'Session active';
      case RemoteSessionStatus.declined:
        return 'Declined';
      case RemoteSessionStatus.ended:
        return 'Ended';
      case RemoteSessionStatus.expired:
        return 'Expired';
      case RemoteSessionStatus.failed:
        return 'Failed';
    }
  }
}

class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.familyId,
    required this.deviceId,
    required this.parentUserId,
    required this.childUserId,
    required this.kind,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.acceptedAt,
    this.endedAt,
    this.endedReason,
    this.consentRecorded = false,
    this.parentDisplayName,
    this.childDisplayName,
    this.deviceName,
  });

  final String id;
  final String familyId;
  final String deviceId;
  final String parentUserId;
  final String childUserId;
  final SessionKind kind;
  final RemoteSessionStatus status;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final String? endedReason;
  final bool consentRecorded;
  final String? parentDisplayName;
  final String? childDisplayName;
  final String? deviceName;

  bool get isExpired =>
      status != RemoteSessionStatus.ended &&
      DateTime.now().isAfter(expiresAt);

  /// True when the server reports the session active and the local expiry
  /// window has not passed.
  ///
  /// This is session state only. It does not mean audio or video is connected;
  /// that is known only by the live session screen.
  bool get isServerActive =>
      status == RemoteSessionStatus.active && !isExpired;

  @Deprecated(
    'Server state, not media state. Use isServerActive; media liveness is '
    'tracked only by the session screen.',
  )
  bool get isLive => isServerActive;

  Duration get remaining {
    final difference = expiresAt.difference(DateTime.now());
    return difference.isNegative ? Duration.zero : difference;
  }

  /// What this list can honestly say about media for this session.
  ///
  /// The session list receives no live track telemetry, so it never claims a
  /// stream is connected; it only states who still has to act.
  String get mediaNote {
    switch (status) {
      case RemoteSessionStatus.requested:
        return 'Off — waiting for the child to accept';
      case RemoteSessionStatus.accepted:
        return 'Off — waiting for the child to join';
      case RemoteSessionStatus.active:
        return 'Started by the child; not verified here';
      case RemoteSessionStatus.declined:
      case RemoteSessionStatus.expired:
      case RemoteSessionStatus.failed:
        return 'No media was opened';
      case RemoteSessionStatus.ended:
        return 'No media is open';
    }
  }

  factory RemoteSession.fromJson(Map<String, dynamic> json) {
    final device = jsonMap(json['devices']);
    final parentProfile = jsonMap(json['parent_profile']);
    final childProfile = jsonMap(json['child_profile']);
    return RemoteSession(
      id: jsonStringOr(json['id']),
      familyId: jsonStringOr(json['family_id']),
      deviceId: jsonStringOr(json['device_id']),
      parentUserId: jsonStringOr(json['parent_user_id']),
      childUserId: jsonStringOr(json['child_user_id']),
      kind: SessionKind.fromWire(json['kind']),
      status: RemoteSessionStatus.fromWire(json['status']),
      requestedAt: jsonDateOr(json['requested_at'], DateTime.now()),
      expiresAt: jsonDateOr(
        json['expires_at'],
        DateTime.now().add(const Duration(minutes: 10)),
      ),
      acceptedAt: jsonDate(json['accepted_at']),
      endedAt: jsonDate(json['ended_at']),
      endedReason: jsonString(json['ended_reason']),
      consentRecorded: jsonBoolOr(json['consent_recorded']),
      parentDisplayName: jsonString(parentProfile['display_name']),
      childDisplayName: jsonString(childProfile['display_name']),
      deviceName: jsonString(device['display_name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'device_id': deviceId,
        'parent_user_id': parentUserId,
        'child_user_id': childUserId,
        'kind': kind.wireName,
        'status': status.wireName,
        'requested_at': requestedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'accepted_at': acceptedAt?.toUtc().toIso8601String(),
        'ended_at': endedAt?.toUtc().toIso8601String(),
        'ended_reason': endedReason,
        'consent_recorded': consentRecorded,
        'parent_display_name': parentDisplayName,
        'child_display_name': childDisplayName,
        'device_name': deviceName,
      };
}

class IceServerConfig {
  const IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  final List<String> urls;
  final String? username;
  final String? credential;

  factory IceServerConfig.fromJson(Map<String, dynamic> json) => IceServerConfig(
        urls: jsonList(json['urls'])
            .map((value) => jsonStringOr(value))
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        username: jsonString(json['username']),
        credential: jsonString(json['credential']),
      );

  Map<String, dynamic> toWebRtcMap() => withoutNulls({
        'urls': urls,
        'username': username,
        'credential': credential,
      });
}

class IceConfig {
  const IceConfig({
    required this.iceServers,
    this.turnConfigured = false,
    this.warning,
    this.expiresAt,
  });

  final List<IceServerConfig> iceServers;
  final bool turnConfigured;
  final String? warning;
  final DateTime? expiresAt;

  factory IceConfig.fromJson(Map<String, dynamic> json) => IceConfig(
        iceServers: jsonList(json['ice_servers'])
            .map((value) => IceServerConfig.fromJson(jsonMap(value)))
            .toList(growable: false),
        turnConfigured: jsonBoolOr(json['turn_configured']),
        warning: jsonString(json['warning']),
        expiresAt: jsonDate(json['expires_at']),
      );
}

enum SignalKind {
  offer,
  answer,
  ice;

  static SignalKind fromWire(Object? raw) {
    switch (jsonString(raw)) {
      case 'answer':
        return SignalKind.answer;
      case 'ice':
        return SignalKind.ice;
      default:
        return SignalKind.offer;
    }
  }

  String get wireName => name;
}

class WebRtcSignal {
  const WebRtcSignal({
    required this.id,
    required this.sessionId,
    required this.fromUserId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.sequence = 0,
  });

  final String id;
  final String sessionId;
  final String fromUserId;
  final SignalKind kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int sequence;

  factory WebRtcSignal.fromJson(Map<String, dynamic> json) => WebRtcSignal(
        id: jsonStringOr(json['id']),
        sessionId: jsonStringOr(json['session_id']),
        fromUserId: jsonStringOr(json['from_user_id']),
        kind: SignalKind.fromWire(json['kind']),
        payload: jsonMap(json['payload']),
        createdAt: jsonDateOr(json['created_at'], DateTime.now()),
        sequence: jsonIntOr(json['sequence']),
      );
}
