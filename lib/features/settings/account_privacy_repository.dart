import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../../data/services/edge_api.dart';
import '../../data/services/supabase_service.dart';

/// Result of `account` action `export`. The payload is the server document
/// (profile, families, memberships, devices, table rows and `truncated` flags).
class AccountDataExport {
  const AccountDataExport({
    required this.payload,
    required this.fileName,
    required this.byteCount,
    this.savedPath,
  });

  final Map<String, dynamic> payload;
  final String fileName;
  final int byteCount;

  /// Absolute path of the written JSON file, or null when the platform refused
  /// the write (the in-memory payload and clipboard copy still work).
  final String? savedPath;

  Map<String, int> get rowCounts {
    final tables = jsonMap(payload['tables']);
    return {
      for (final entry in tables.entries)
        entry.key: jsonIntOr(jsonMap(entry.value)['row_count']),
    };
  }

  List<String> get truncatedTables {
    final tables = jsonMap(payload['tables']);
    return [
      for (final entry in tables.entries)
        if (jsonBoolOr(jsonMap(entry.value)['truncated'])) entry.key,
    ];
  }

  String get prettyJson => const JsonEncoder.withIndent('  ').convert(payload);
}

class FamilyRetentionWindow {
  const FamilyRetentionWindow({
    required this.familyId,
    required this.familyName,
    required this.locationDays,
    required this.usageDays,
    this.locationEventsOlderThanWindow = 0,
    this.usageDaysOlderThanWindow = 0,
  });

  final String familyId;
  final String familyName;
  final int locationDays;
  final int usageDays;
  final int locationEventsOlderThanWindow;
  final int usageDaysOlderThanWindow;

  factory FamilyRetentionWindow.fromJson(Map<String, dynamic> json) {
    return FamilyRetentionWindow(
      familyId: jsonStringOr(json['family_id']),
      familyName: jsonStringOr(json['name'], 'Family'),
      locationDays: jsonIntOr(json['location_retention_days'], 30),
      usageDays: jsonIntOr(json['usage_retention_days'], 90),
      locationEventsOlderThanWindow:
          jsonIntOr(json['location_events_older_than_window']),
      usageDaysOlderThanWindow: jsonIntOr(json['usage_days_older_than_window']),
    );
  }
}

class RetentionReport {
  const RetentionReport({
    required this.families,
    this.generatedAt,
    this.lastSweepAt,
  });

  final DateTime? generatedAt;
  final DateTime? lastSweepAt;
  final List<FamilyRetentionWindow> families;

  factory RetentionReport.fromJson(Map<String, dynamic> json) {
    return RetentionReport(
      generatedAt: jsonDate(json['generated_at']),
      lastSweepAt: jsonDate(json['last_sweep_at']),
      families: jsonList(json['families'])
          .map((row) => FamilyRetentionWindow.fromJson(jsonMap(row)))
          .toList(growable: false),
    );
  }
}

class AccountDeletionOutcome {
  const AccountDeletionOutcome({
    required this.deleted,
    this.blockedReason,
  });

  final bool deleted;
  final String? blockedReason;
}

/// The privacy actions are isolated behind an interface so the settings
/// controller can be tested without a Supabase client or platform files.
abstract class AccountPrivacyRepository {
  Future<AccountDataExport> exportMyData();

  /// [confirm] must be `DELETE`; [email] must match the signed-in account.
  Future<AccountDeletionOutcome> deleteAccount({
    required String confirm,
    required String email,
  });

  Future<RetentionReport> loadRetentionReport();
}

class SupabaseAccountPrivacyRepository implements AccountPrivacyRepository {
  SupabaseAccountPrivacyRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  static const Duration _exportTimeout = Duration(seconds: 90);

  @override
  Future<AccountDataExport> exportMyData() async {
    if (!_supabase.isConfigured) throw AppException.backendNotConfigured();
    if (!_supabase.isReady) {
      throw _supabase.initError ?? AppException.backendNotConfigured();
    }
    try {
      // The export is a raw JSON attachment (not the {ok,data} envelope), so
      // the response body itself is the document. `functions.invoke` parses it
      // and attaches the caller's access token.
      final response = await _supabase.client.functions.invoke(
        'account',
        body: const {'action': 'export'},
      ).timeout(_exportTimeout);
      final payload = jsonMap(response.data);
      if (payload.isEmpty) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server returned an empty data export.',
        );
      }

      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      final fileName =
          'parent-control-export-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}.json';
      String? savedPath;
      try {
        final directory =
            Directory('${Directory.systemTemp.path}/parent_control_exports');
        await directory.create(recursive: true);
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(encoded, flush: true);
        savedPath = file.path;
      } catch (_) {
        // The export is still valid; the UI offers a clipboard copy.
        savedPath = null;
      }

      return AccountDataExport(
        payload: payload,
        fileName: fileName,
        byteCount: utf8.encode(encoded).length,
        savedPath: savedPath,
      );
    } on AppException {
      rethrow;
    } on FunctionException catch (error) {
      throw _mapFunctionError(error);
    } on TimeoutException catch (error) {
      throw AppException.timeout(error);
    } on SocketException catch (error) {
      throw AppException.network(error);
    } catch (error) {
      throw AppException.unexpected(error);
    }
  }

  @override
  Future<AccountDeletionOutcome> deleteAccount({
    required String confirm,
    required String email,
  }) async {
    try {
      final data = await _edgeApi.invokeMap(
        'account',
        action: 'delete_account',
        body: {'confirm': confirm, 'email': email},
        timeout: const Duration(seconds: 60),
      );
      if (jsonBoolOr(data['deleted'])) {
        // The auth user is gone; drop the local token so the next launch does
        // not try to restore a deleted session. Best effort only.
        try {
          await _supabase.client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          // The controller also clears the in-memory session.
        }
        return const AccountDeletionOutcome(deleted: true);
      }
      return const AccountDeletionOutcome(deleted: false);
    } on AppException catch (error) {
      if (error.code == 'account_deletion_blocked') {
        return AccountDeletionOutcome(
          deleted: false,
          blockedReason: error.message,
        );
      }
      rethrow;
    }
  }

  @override
  Future<RetentionReport> loadRetentionReport() async {
    final data = await _edgeApi.invokeMap(
      'account',
      action: 'retention_report',
    );
    return RetentionReport.fromJson(data);
  }

  AppException _mapFunctionError(FunctionException error) {
    if (error.status == 0) return AppException.network(error);
    var payload = error.details;
    if (payload is String && payload.isNotEmpty) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        payload = null;
      }
    }
    final details = jsonMap(payload);
    final nested = jsonMap(details['error']);
    final source = nested.isNotEmpty ? nested : details;
    return AppException(
      jsonString(source['code']) ?? AppErrorCodes.unknown,
      jsonString(source['message']) ??
          'The server could not complete the data export.',
      statusCode: error.status,
    );
  }
}