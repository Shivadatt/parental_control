import 'dart:async';
import 'dart:io';

import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/json_utils.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/edge_api.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads families and memberships through RLS-protected PostgREST queries and
/// creates/updates through the user-authenticated Edge Functions. The client
/// never bypasses RLS and never assumes a write succeeded before the server
/// answers.
class SupabaseFamilyRepository implements FamilyRepository {
  SupabaseFamilyRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<Family> createFamily(String name) async {
    final trimmed = name.trim();
    final validation = Validators.familyName(trimmed);
    if (validation != null) {
      throw AppException(AppErrorCodes.validation, validation);
    }
    try {
      final data = await _edgeApi.invokeMap(
        'auth-bootstrap',
        action: 'create_family',
        body: {'name': trimmed},
      );
      final family = Family.fromJson(data);
      if (family.id.isEmpty) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server did not return the created family. Refresh and try '
              'again.',
        );
      }
      return family;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<Family>> fetchMyFamilies() async {
    final userId = _requireUserId();
    try {
      final rows = await _supabase.client
          .from('family_members')
          .select(
            'family_id, status, families!inner(id, name, owner_id, settings, '
            'created_at, deleted_at)',
          )
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: true);
      final byId = <String, Family>{};
      for (final row in rows) {
        final map = jsonMap(row);
        if (FamilyMemberStatus.fromWire(map['status']) !=
            FamilyMemberStatus.active) {
          continue;
        }
        final familyMap = jsonMap(map['families']);
        if (familyMap['deleted_at'] != null) continue;
        final family = Family.fromJson(familyMap);
        if (family.id.isEmpty) continue;
        byId[family.id] = family;
      }
      return List<Family>.unmodifiable(byId.values);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Family?> fetchFamily(String familyId) async {
    final id = familyId.trim();
    if (id.isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A family id is required.',
      );
    }
    try {
      final row = await _supabase.client
          .from('families')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return Family.fromJson(jsonMap(row));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<FamilyMember>> fetchMembers(String familyId) async {
    final id = familyId.trim();
    if (id.isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A family id is required.',
      );
    }
    try {
      final rows = await _supabase.client
          .from('family_members')
          .select('*, profiles(display_name)')
          .eq('family_id', id)
          .order('created_at', ascending: true);
      return List<FamilyMember>.unmodifiable(
        rows.map((row) => FamilyMember.fromJson(jsonMap(row))),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<FamilyMember?> fetchMyMembership() async {
    final userId = _requireUserId();
    try {
      final row = await _supabase.client
          .from('family_members')
          .select('*, profiles(display_name)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return FamilyMember.fromJson(jsonMap(row));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> updateSettings({
    required String familyId,
    required FamilySettings settings,
  }) async {
    final id = familyId.trim();
    if (id.isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A family id is required.',
      );
    }
    if (settings.locationRetentionDays < 1 ||
        settings.locationRetentionDays > 365) {
      throw const AppException(
        AppErrorCodes.validation,
        'Location retention must be between 1 and 365 days.',
      );
    }
    if (settings.usageRetentionDays < 1 || settings.usageRetentionDays > 730) {
      throw const AppException(
        AppErrorCodes.validation,
        'Usage retention must be between 1 and 730 days.',
      );
    }
    try {
      await _edgeApi.invokeMap(
        'family-admin',
        action: 'update_retention',
        body: {
          'family_id': id,
          'location_days': settings.locationRetentionDays,
          'usage_days': settings.usageRetentionDays,
        },
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  String _requireUserId() {
    final userId = _supabase.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppException(
        AppErrorCodes.sessionExpired,
        'Your session has expired. Sign in again.',
      );
    }
    return userId;
  }

  AppException _mapError(Object error) {
    if (error is AppException) return error;
    if (error is PostgrestException) return _mapPostgrestException(error);
    if (error is TimeoutException) return AppException.timeout(error);
    if (error is SocketException) return AppException.network(error);
    if (error is HttpException) return AppException.network(error);
    return AppException.unexpected(error);
  }

  AppException _mapPostgrestException(PostgrestException error) {
    switch (error.code) {
      case 'PGRST116':
        return const AppException(
          AppErrorCodes.notFound,
          'This family was not found or is not visible to this account.',
        );
      case '42501':
        return const AppException(
          AppErrorCodes.forbidden,
          'You do not have permission to read this family.',
        );
      case '23505':
        return const AppException(
          AppErrorCodes.conflict,
          'This action conflicts with the current state. Refresh and try '
              'again.',
        );
      case '23503':
        return const AppException(
          AppErrorCodes.conflict,
          'The related record is missing or already changed.',
        );
      case '23502':
      case '23514':
      case '22P02':
        return const AppException(
          AppErrorCodes.validation,
          'The submitted values were rejected by the server.',
        );
      default:
        return const AppException(
          AppErrorCodes.unknown,
          'The server could not complete the request. Try again.',
        );
    }
  }
}
