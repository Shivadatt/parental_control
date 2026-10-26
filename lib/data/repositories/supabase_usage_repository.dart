import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../models/telemetry.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

class SupabaseUsageRepository implements UsageRepository {
  SupabaseUsageRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<List<UsageDaily>> fetchUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) =>
      _guard(() async {
        final rows = await _supabase.client
            .from('usage_daily')
            .select()
            .eq('device_id', deviceId)
            .gte('day', _dayString(from))
            .lte('day', _dayString(to))
            .order('day', ascending: false);
        return rows
            .map((row) => UsageDaily.fromJson(jsonMap(row)))
            .toList(growable: false);
      });

  @override
  Future<DateTime?> fetchLastUpload(String deviceId) => _guard(() async {
        final row = await _supabase.client
            .from('usage_daily')
            .select('uploaded_at')
            .eq('device_id', deviceId)
            .order('uploaded_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row == null) return null;
        return jsonDate(row['uploaded_at']);
      });

  @override
  Future<int> uploadUsage({
    required DeviceIdentity identity,
    required String deviceId,
    required List<UsageDaily> entries,
  }) =>
      _guard(() async {
        final serverDeviceId = identity.serverDeviceId;
        if (serverDeviceId == null || serverDeviceId.isEmpty) {
          throw const AppException(
            AppErrorCodes.unauthorized,
            'This device is not registered with the backend yet.',
          );
        }
        const maxEntries = 500;
        if (entries.isEmpty || entries.length > maxEntries) {
          throw const AppException(
            AppErrorCodes.validation,
            'Send between 1 and 500 usage entries per upload.',
          );
        }
        final data = await _edgeApi.invokeMap(
          'device-telemetry',
          action: 'usage_upload',
          headers: identity.authHeaders(),
          body: {
            'entries': entries
                .map((entry) => entry.toUploadJson())
                .toList(growable: false),
          },
        );
        return jsonIntOr(data['accepted']);
      });

  String _dayString(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
        'You do not have permission to view usage for this device.',
        cause: error,
      );
    }
    if (error.code == 'PGRST116') {
      return AppException(
        AppErrorCodes.notFound,
        'The requested usage data is not available.',
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
