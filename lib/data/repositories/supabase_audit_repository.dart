import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/audit.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

/// Append-only audit log reads plus owner-only retention/purge actions.
class SupabaseAuditRepository implements AuditRepository {
  SupabaseAuditRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<List<AuditLogEntry>> fetchAuditLogs({
    required String familyId,
    int limit = 200,
  }) async {
    try {
      final rows = await _supabase.client
          .from('audit_logs')
          .select('*, actor_profile:profiles!actor_user_id(display_name)')
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => AuditLogEntry.fromJson(jsonMap(row)))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error, 'The audit history could not be loaded.');
    }
  }

  @override
  Future<void> updateRetention({
    required String familyId,
    required int locationDays,
    required int usageDays,
  }) async {
    try {
      await _edgeApi.invoke(
        'family-admin',
        action: 'update_retention',
        body: {
          'family_id': familyId,
          'location_days': locationDays,
          'usage_days': usageDays,
        },
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The retention settings could not be saved.');
    }
  }

  @override
  Future<int> purgeOldData({
    required String familyId,
    required int olderThanDays,
  }) async {
    try {
      final data = await _edgeApi.invokeMap(
        'family-admin',
        action: 'purge_data',
        body: {
          'family_id': familyId,
          'older_than_days': olderThanDays,
        },
      );
      return _extractDeletedCount(data);
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'Old data could not be purged.');
    }
  }

  /// The contract only promises "counts". Accept the documented envelope
  /// shapes and refuse to invent a number when the server omits them.
  int _extractDeletedCount(Map<String, dynamic> data) {
    final direct = jsonInt(
      data['deleted_count'] ?? data['deletedCount'] ?? data['count'] ?? data['total'],
    );
    if (direct != null) return direct;

    final deleted = data['deleted'];
    if (deleted is num) return deleted.toInt();
    final deletedMap = jsonMap(deleted);
    if (deletedMap.isNotEmpty) {
      var sum = 0;
      var found = false;
      for (final value in deletedMap.values) {
        final count = jsonInt(value);
        if (count != null) {
          found = true;
          sum += count;
        }
      }
      if (found) return sum;
    }

    final counts = jsonMap(data['counts']);
    if (counts.isNotEmpty) {
      var sum = 0;
      var found = false;
      for (final value in counts.values) {
        final count = jsonInt(value);
        if (count != null) {
          found = true;
          sum += count;
        }
      }
      if (found) return sum;
    }

    throw const AppException(
      AppErrorCodes.unknown,
      'The server did not report how many records were deleted.',
    );
  }

  AppException _mapError(Object error, String fallbackMessage) {
    if (error is AppException) return error;
    if (error is PostgrestException) {
      final code = switch (error.code) {
        '42501' => AppErrorCodes.forbidden,
        'PGRST116' => AppErrorCodes.notFound,
        _ => AppErrorCodes.unknown,
      };
      return AppException(
        code,
        error.message.trim().isEmpty ? fallbackMessage : error.message,
      );
    }
    return AppException.from(error);
  }
}
