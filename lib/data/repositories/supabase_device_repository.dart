import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

// secret_hash and installation_id are service-only column grants.
const _deviceColumns =
    'id, family_id, child_user_id, display_name, platform, android_version, '
    'app_version, status, credential_issued_at, credential_revoked_at, '
    'last_seen_at, battery_level, is_charging, enforcement_mode, policy_version, '
    'usage_access_granted, location_granted, background_location_granted, '
    'camera_granted, microphone_granted, notifications_granted, '
    'created_at, updated_at';

/// Reads devices and reported apps from Supabase and performs the
/// device-authenticated telemetry calls through Edge Functions.
class SupabaseDeviceRepository implements DeviceRepository {
  SupabaseDeviceRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<List<Device>> fetchDevices(String familyId) => _guard(() async {
        final rows = await _supabase.client
            .from('devices')
            .select(_deviceColumns)
            .eq('family_id', familyId)
            .order('created_at', ascending: true);
        return rows
            .map((row) => Device.fromJson(jsonMap(row)))
            .toList(growable: false);
      });

  @override
  Future<Device> fetchDevice(String deviceId) => _guard(() async {
        final row = await _supabase.client
            .from('devices')
            .select(_deviceColumns)
            .eq('id', deviceId)
            .maybeSingle();
        if (row == null) {
          throw const AppException(
            AppErrorCodes.notFound,
            'This device is not available in your family.',
          );
        }
        return Device.fromJson(row);
      });

  @override
  Future<Device?> fetchMyDevice() => _guard(() async {
        final userId = _supabase.currentUser?.id;
        if (userId == null || userId.isEmpty) return null;
        final row = await _supabase.client
            .from('devices')
            .select(_deviceColumns)
            .eq('child_user_id', userId)
            .eq('status', 'active')
            .maybeSingle();
        return row == null ? null : Device.fromJson(row);
      });

  @override
  Future<Device> registerDevice({
    required String familyId,
    required DeviceIdentity identity,
    required String displayName,
    String platform = 'android',
    String? androidVersion,
    String? appVersion,
  }) =>
      _guard(() async {
        final data = await _edgeApi.invokeMap(
          'device-register',
          action: 'register',
          body: withoutNulls({
            'family_id': familyId,
            'installation_id': identity.installationId,
            'secret_hash': identity.secretHash,
            'display_name': displayName,
            'platform': platform,
            'android_version': androidVersion,
            'app_version': appVersion,
          }),
        );
        final nested = jsonMap(data['device']);
        final device = Device.fromJson(nested.isNotEmpty ? nested : data);
        if (device.id.isEmpty) {
          throw const AppException(
            AppErrorCodes.unknown,
            'The device registration response was incomplete. Try again.',
          );
        }
        return device;
      });

  @override
  Future<void> revokeDevice(String deviceId) => _guard(() async {
        await _edgeApi.invoke(
          'family-admin',
          action: 'revoke_device',
          body: {'device_id': deviceId},
        );
      });

  @override
  Future<List<InstalledApp>> fetchReportedApps(String deviceId) =>
      _guard(() async {
        final rows = await _supabase.client
            .from('device_apps')
            .select()
            .eq('device_id', deviceId)
            .order('label', ascending: true);
        return rows
            .map((row) => InstalledApp.fromJson(jsonMap(row)))
            .toList(growable: false);
      });

  @override
  Future<int> uploadReportedApps({
    required DeviceIdentity identity,
    required String deviceId,
    required List<InstalledApp> apps,
  }) =>
      _guard(() async {
        _requireRegistered(identity);
        const maxEntries = 500;
        if (apps.isEmpty || apps.length > maxEntries) {
          throw const AppException(
            AppErrorCodes.validation,
            'Send between 1 and 500 installed apps per upload.',
          );
        }
        final entries = apps
            .map((app) => withoutNulls({
                  'package_name': app.packageName,
                  'label': app.label,
                  'is_system': app.isSystem,
                  'is_suspended': app.isSuspended,
                  'version_name': app.versionName,
                }))
            .toList(growable: false);
        final data = await _edgeApi.invokeMap(
          'device-telemetry',
          action: 'apps_upload',
          headers: identity.authHeaders(),
          body: {'apps': entries},
        );
        return jsonIntOr(data['accepted']);
      });

  @override
  Future<void> heartbeat({
    required DeviceIdentity identity,
    required BatteryStatus battery,
    required bool online,
    required DeviceCapabilities capabilities,
  }) =>
      _guard(() async {
        _requireRegistered(identity);
        final capabilityMap = <String, dynamic>{
          'enforcement_mode': capabilities.isDeviceOwner
              ? 'device_owner'
              : (capabilities.isAdminActive ? 'device_admin' : 'none'),
          'usage_access_granted': capabilities.usageAccessGranted,
          'location_granted': capabilities.fineLocationGranted,
          'background_location_granted': capabilities.backgroundLocationGranted,
          'camera_granted': capabilities.cameraGranted,
          'microphone_granted': capabilities.microphoneGranted,
          'notifications_granted': capabilities.notificationsGranted,
        };
        await _edgeApi.invoke(
          'device-telemetry',
          action: 'heartbeat',
          headers: identity.authHeaders(),
          body: withoutNulls({
            'battery_level': battery.level,
            'is_charging': battery.isCharging,
            'online': online,
            'capabilities': capabilityMap,
          }),
        );
      });

  void _requireRegistered(DeviceIdentity identity) {
    final id = identity.serverDeviceId;
    if (id == null || id.isEmpty) {
      throw const AppException(
        AppErrorCodes.unauthorized,
        'This device is not registered with the backend yet.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrest(error);
    } on AuthException catch (error) {
      throw AppException(
        AppErrorCodes.unauthorized,
        'Your session has expired. Sign in again.',
        cause: error,
      );
    } catch (error) {
      throw AppException.from(error);
    }
  }

  AppException _mapPostgrest(PostgrestException error) {
    if (error.code == '42501') {
      return AppException(
        AppErrorCodes.forbidden,
        'You do not have permission to view this device data.',
        cause: error,
      );
    }
    if (error.code == 'PGRST116') {
      return AppException(
        AppErrorCodes.notFound,
        'The requested device data is not available.',
        cause: error,
      );
    }
    return AppException(
      AppErrorCodes.unknown,
      'The server could not load this data. Try again.',
      cause: error,
    );
  }
}
