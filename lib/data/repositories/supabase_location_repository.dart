import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../models/telemetry.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

/// Location history and safe zones backed by Supabase/Edge Functions.
///
/// Reads rely on the table RLS policies (family parent or child owner). The
/// child-side upload is authenticated with device credentials and never with a
/// user JWT alone.
class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<LocationEvent?> fetchLatestLocation(String deviceId) async {
    try {
      final row = await _supabase.client
          .from('location_events')
          .select()
          .eq('device_id', deviceId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : LocationEvent.fromJson(row);
    } catch (error) {
      throw _mapError(
        error,
        'The latest location could not be loaded.',
      );
    }
  }

  @override
  Future<List<LocationEvent>> fetchHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _supabase.client
          .from('location_events')
          .select()
          .eq('device_id', deviceId)
          .gte('recorded_at', from.toUtc().toIso8601String())
          .lte('recorded_at', to.toUtc().toIso8601String())
          .order('recorded_at', ascending: false)
          .limit(500);
      return rows
          .map((row) => LocationEvent.fromJson(jsonMap(row)))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(
        error,
        'The location history could not be loaded.',
      );
    }
  }

  @override
  Future<void> uploadLocation({
    required DeviceIdentity identity,
    required String deviceId,
    required LocationFix fix,
  }) async {
    try {
      await _edgeApi.invoke(
        'device-telemetry',
        action: 'location_upload',
        body: fix.toUploadJson(),
        headers: identity.authHeaders(),
      );
    } on AppException {
      rethrow;
    } on StateError {
      throw const AppException(
        AppErrorCodes.deviceNotTrusted,
        'This device has no registered identity. Enroll it before sharing location.',
      );
    } catch (error) {
      throw _mapError(error, 'The location could not be uploaded.');
    }
  }

  @override
  Future<List<SafeZone>> fetchSafeZones(String familyId) async {
    try {
      final rows = await _supabase.client
          .from('safe_zones')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: true);
      return rows
          .map((row) => SafeZone.fromJson(jsonMap(row)))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error, 'Safe zones could not be loaded.');
    }
  }

  @override
  Future<SafeZone> upsertSafeZone({
    required String familyId,
    required SafeZone zone,
  }) async {
    final payload = zone.toUpsertJson(familyId);
    try {
      final Map<String, dynamic> row;
      if (zone.id.isEmpty) {
        row = await _supabase.client
            .from('safe_zones')
            .insert(payload)
            .select()
            .single();
      } else {
        row = await _supabase.client
            .from('safe_zones')
            .update(payload)
            .eq('id', zone.id)
            .eq('family_id', familyId)
            .select()
            .single();
      }
      return SafeZone.fromJson(row);
    } catch (error) {
      throw _mapError(error, 'The safe zone could not be saved.');
    }
  }

  @override
  Future<void> deleteSafeZone(String zoneId) async {
    try {
      await _supabase.client.from('safe_zones').delete().eq('id', zoneId);
    } catch (error) {
      throw _mapError(error, 'The safe zone could not be deleted.');
    }
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
