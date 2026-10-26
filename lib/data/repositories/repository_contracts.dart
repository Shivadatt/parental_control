import '../models/models.dart';

abstract class AuthRepository {
  String? get currentUserId;
  String? get currentEmail;
  bool get isEmailVerified;
  Stream<void> get authChanges;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
  Future<void> resendVerificationEmail();
  Future<bool> refreshEmailVerification();
  Future<Profile?> fetchProfile();
  Future<Profile> setInitialRole({
    required ProfileRole role,
    String? displayName,
  });
}

abstract class FamilyRepository {
  Future<Family> createFamily(String name);
  Future<List<Family>> fetchMyFamilies();
  Future<Family?> fetchFamily(String familyId);
  Future<List<FamilyMember>> fetchMembers(String familyId);
  Future<FamilyMember?> fetchMyMembership();
  Future<void> updateSettings({
    required String familyId,
    required FamilySettings settings,
  });
}

abstract class PairingRepository {
  Future<PairingCode> createLinkingCode();
  Future<PairingRequest> redeemLinkingCode({
    required String code,
    required String familyId,
  });
  Future<List<PairingRequest>> fetchPendingForChild();
  Future<List<PairingRequest>> fetchForFamily(String familyId);
  Future<void> respond({required String requestId, required bool approve});
  Future<void> cancel(String requestId);
  Future<void> unlink({
    required String familyId,
    required String childUserId,
  });
}

abstract class DeviceRepository {
  Future<List<Device>> fetchDevices(String familyId);
  Future<Device> fetchDevice(String deviceId);
  Future<Device?> fetchMyDevice();
  Future<Device> registerDevice({
    required String familyId,
    required DeviceIdentity identity,
    required String displayName,
  });
  Future<void> revokeDevice(String deviceId);
  Future<List<InstalledApp>> fetchReportedApps(String deviceId);
  Future<int> uploadReportedApps({
    required DeviceIdentity identity,
    required String deviceId,
    required List<InstalledApp> apps,
  });
  Future<void> heartbeat({
    required DeviceIdentity identity,
    required BatteryStatus battery,
    required bool online,
    required DeviceCapabilities capabilities,
    int? policyVersion,
  });
}

abstract class PolicyRepository {
  Future<DevicePolicy?> fetchLatestPolicy(String deviceId);
  Future<PolicyUpdateResult> updatePolicy({
    required String deviceId,
    required PolicyPayload payload,
    required String idempotencyKey,
  });
  Future<List<DeviceCommand>> fetchRecentCommands(
    String deviceId, {
    int limit = 20,
  });
  Future<DeviceCommand> createCommand({
    required String deviceId,
    required DeviceCommandType type,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    int ttlSeconds = 300,
  });
  Future<DeviceCommand> acknowledgeCommand({
    required String commandId,
    required bool success,
    required Map<String, dynamic> result,
  });
}

abstract class UsageRepository {
  Future<List<UsageDaily>> fetchUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<DateTime?> fetchLastUpload(String deviceId);
  Future<int> uploadUsage({
    required DeviceIdentity identity,
    required String deviceId,
    required List<UsageDaily> entries,
  });
}

abstract class LocationRepository {
  Future<LocationEvent?> fetchLatestLocation(String deviceId);
  Future<List<LocationEvent>> fetchHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<void> uploadLocation({
    required DeviceIdentity identity,
    required String deviceId,
    required LocationFix fix,
  });
  Future<List<SafeZone>> fetchSafeZones(String familyId);
  Future<SafeZone> upsertSafeZone({
    required String familyId,
    required SafeZone zone,
  });
  Future<void> deleteSafeZone(String zoneId);
}

abstract class AlertRepository {
  Future<List<SafetyAlert>> fetchAlerts({
    required String familyId,
    int limit = 100,
  });
  Future<void> acknowledgeAlert(String alertId);
  Stream<List<SafetyAlert>> watchAlerts(String familyId);
}

abstract class RemoteSessionRepository {
  Future<RemoteSession> request({
    required String deviceId,
    required SessionKind kind,
  });
  Future<List<RemoteSession>> fetchPendingForChild();
  Future<RemoteSession?> fetchById(String sessionId);
  Future<List<RemoteSession>> fetchForFamily(String familyId, {int limit = 30});
  Future<RemoteSession> respond({
    required String sessionId,
    required bool accept,
  });
  Future<RemoteSession> markActive(String sessionId);
  Future<void> end({required String sessionId, String? reason});
  Future<IceConfig> fetchIceConfig(String sessionId);
  Future<void> sendSignal({
    required String sessionId,
    required SignalKind kind,
    required Map<String, dynamic> payload,
  });
  Stream<RemoteSession> watchSession(String sessionId);
  Stream<List<WebRtcSignal>> watchSignals(String sessionId);
  Stream<List<RemoteSession>> watchFamilySessions(String familyId);
}

abstract class AuditRepository {
  Future<List<AuditLogEntry>> fetchAuditLogs({
    required String familyId,
    int limit = 200,
  });
  Future<void> updateRetention({
    required String familyId,
    required int locationDays,
    required int usageDays,
  });
  Future<int> purgeOldData({
    required String familyId,
    required int olderThanDays,
  });
}
