import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

/// Policies and commands are written through Edge Functions so the server can
/// validate schema, family membership and idempotency.
class SupabasePolicyRepository implements PolicyRepository {
  SupabasePolicyRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<DevicePolicy?> fetchLatestPolicy(String deviceId) => _guard(() async {
        final row = await _supabase.client
            .from('device_policies')
            .select()
            .eq('device_id', deviceId)
            .order('version', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : DevicePolicy.fromJson(row);
      });

  @override
  Future<PolicyUpdateResult> updatePolicy({
    required String deviceId,
    required PolicyPayload payload,
    required String idempotencyKey,
  }) =>
      _guard(() async {
        final data = await _edgeApi.invokeMap(
          'device-policy',
          action: 'update',
          body: {
            'device_id': deviceId,
            'policy': payload.toJson(),
            'idempotency_key': idempotencyKey,
          },
        );
        final policyMap = jsonMap(data['policy']);
        final commandMap = jsonMap(data['command']);
        if (policyMap.isEmpty || commandMap.isEmpty) {
          throw const AppException(
            AppErrorCodes.unknown,
            'The policy update response was incomplete. Refresh and try again.',
          );
        }
        return PolicyUpdateResult(
          policy: DevicePolicy.fromJson(policyMap),
          command: DeviceCommand.fromJson(commandMap),
        );
      });

  @override
  Future<List<DeviceCommand>> fetchRecentCommands(
    String deviceId, {
    int limit = 20,
  }) =>
      _guard(() async {
        final rows = await _supabase.client
            .from('device_commands')
            .select()
            .eq('device_id', deviceId)
            .order('created_at', ascending: false)
            .limit(limit);
        return rows
            .map((row) => DeviceCommand.fromJson(jsonMap(row)))
            .toList(growable: false);
      });

  @override
  Future<DeviceCommand> createCommand({
    required String deviceId,
    required DeviceCommandType type,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    int ttlSeconds = 300,
  }) =>
      _guard(() async {
        final data = await _edgeApi.invokeMap(
          'device-command',
          action: 'create',
          body: {
            'device_id': deviceId,
            'type': type.wireName,
            'payload': payload,
            'idempotency_key': idempotencyKey,
            'ttl_seconds': ttlSeconds,
          },
        );
        final commandMap = jsonMap(data['command']);
        if (commandMap.isEmpty) {
          throw const AppException(
            AppErrorCodes.unknown,
            'The command response was incomplete. Try again.',
          );
        }
        return DeviceCommand.fromJson(commandMap);
      });

  @override
  Future<DeviceCommand> acknowledgeCommand({
    required DeviceIdentity identity,
    required String commandId,
    required bool success,
    required Map<String, dynamic> result,
  }) =>
      _guard(() async {
        final serverDeviceId = identity.serverDeviceId;
        if (serverDeviceId == null || serverDeviceId.isEmpty) {
          throw const AppException(
            AppErrorCodes.unauthorized,
            'This device is not registered with the backend yet.',
          );
        }
        final data = await _edgeApi.invokeMap(
          'device-command',
          action: 'ack',
          headers: identity.authHeaders(),
          body: {
            'command_id': commandId,
            'status': success ? 'succeeded' : 'failed',
            'result': result,
          },
        );
        final commandMap = jsonMap(data['command']);
        if (commandMap.isEmpty) {
          throw const AppException(
            AppErrorCodes.unknown,
            'The acknowledgement response was incomplete.',
          );
        }
        return DeviceCommand.fromJson(commandMap);
      });

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
        'You do not have permission to view policies for this device.',
        cause: error,
      );
    }
    if (error.code == 'PGRST116') {
      return AppException(
        AppErrorCodes.notFound,
        'The requested policy data is not available.',
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
