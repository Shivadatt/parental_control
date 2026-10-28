import 'dart:async';
import 'dart:io';

import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/json_utils.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/edge_api.dart';
import 'package:parent_control/data/services/supabase_service.dart';

/// Pairing goes through the `pairing` Edge Function only. The server decides
/// every outcome; this repository never marks a code redeemed or a request
/// approved on its own.
class SupabasePairingRepository implements PairingRepository {
  SupabasePairingRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<ChildContactId> fetchChildContactId() async {
    try {
      final map = await _invokeMap('get_contact_id');
      final contact = ChildContactId.fromJson(map);
      if (!contact.isUsable || !Validators.isChildId(contact.canonicalId)) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server did not return a usable Child ID. Try again.',
        );
      }
      return contact;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PairingRequest> inviteChild({
    required String childId,
    required String familyId,
  }) async {
    final normalized = Validators.normalizePairingCode(childId);
    if (!Validators.isChildId(normalized)) {
      throw const AppException(
        AppErrorCodes.validation,
        'Enter the Child ID shown on the child device, for example '
        'PC-7K4M2QRX.',
      );
    }
    if (familyId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'Open this screen from a family before linking a child.',
      );
    }
    try {
      final map = await _invokeMap(
        'invite',
        body: {'child_id': normalized, 'family_id': familyId.trim()},
      );
      return _pairingRequest(map);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PairingCode> createLinkingCode() async {
    try {
      final map = await _invokeMap('create');
      final code = PairingCode.fromJson(map);
      if (code.code.isEmpty ||
          code.qrPayload.isEmpty ||
          jsonDate(map['expires_at']) == null) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server did not return a usable linking code. Try again.',
        );
      }
      return code;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PairingRequest> redeemLinkingCode({
    required String code,
    required String familyId,
  }) async {
    final normalized = Validators.normalizePairingCode(code);
    final validation = Validators.pairingCode(normalized);
    if (validation != null) {
      throw AppException(AppErrorCodes.validation, validation);
    }
    if (familyId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'Open this screen from a family before redeeming a code.',
      );
    }
    try {
      final map = await _invokeMap(
        'redeem',
        body: {'code': normalized, 'family_id': familyId.trim()},
      );
      return _pairingRequest(map);
    } catch (error) {
      throw _mapError(error);
    }
  }

  PairingRequest _pairingRequest(Map<String, dynamic> map) {
    final request = PairingRequest.fromJson(map);
    if (request.id.isEmpty ||
        request.childUserId.isEmpty ||
        request.familyId.isEmpty) {
      throw const AppException(
        AppErrorCodes.unknown,
        'The server did not return a valid pairing request. Refresh and try '
            'again.',
      );
    }
    return request;
  }

  @override
  Future<List<PairingRequest>> fetchPendingForChild() =>
      _fetchList('pending_child');

  @override
  Future<List<PairingRequest>> fetchForFamily(String familyId) {
    if (familyId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A family id is required.',
      );
    }
    return _fetchList('list_family', body: {'family_id': familyId.trim()});
  }

  @override
  Future<void> respond({
    required String requestId,
    required bool approve,
  }) async {
    if (requestId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A pairing request id is required.',
      );
    }
    try {
      await _invokeMap(
        'respond',
        body: {'request_id': requestId.trim(), 'approve': approve},
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A pairing request id is required.',
      );
    }
    try {
      await _invokeMap('cancel', body: {'request_id': requestId.trim()});
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> unlink({
    required String familyId,
    required String childUserId,
  }) async {
    if (familyId.trim().isEmpty || childUserId.trim().isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'A family id and child account are required to unlink a device.',
      );
    }
    try {
      await _invokeMap(
        'unlink',
        body: {
          'family_id': familyId.trim(),
          'child_user_id': childUserId.trim(),
        },
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> _invokeMap(
    String action, {
    Map<String, dynamic> body = const {},
  }) {
    // The caller must be signed in for the Edge Function gateway to attach a
    // user JWT. A missing local user is reported before any request is made.
    final user = _supabase.currentUser;
    if (user == null) {
      throw const AppException(
        AppErrorCodes.sessionExpired,
        'Sign in again before using pairing.',
      );
    }
    return _edgeApi.invokeMap('pairing', action: action, body: body);
  }

  Future<List<PairingRequest>> _fetchList(
    String action, {
    Map<String, dynamic> body = const {},
  }) async {
    try {
      final data = await _invoke('pairing', action: action, body: body);
      final List<dynamic> rows;
      if (data is List) {
        rows = data;
      } else {
        final map = jsonMap(data);
        rows = jsonList(map['requests'] ?? map['data']);
      }
      return List<PairingRequest>.unmodifiable(
        rows.map((row) => PairingRequest.fromJson(jsonMap(row))),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> _invoke(
    String function, {
    required String action,
    Map<String, dynamic> body = const {},
  }) {
    final user = _supabase.currentUser;
    if (user == null) {
      throw const AppException(
        AppErrorCodes.sessionExpired,
        'Sign in again before using pairing.',
      );
    }
    return _edgeApi.invoke(function, action: action, body: body);
  }

  AppException _mapError(Object error) {
    if (error is AppException) return error;
    if (error is TimeoutException) return AppException.timeout(error);
    if (error is SocketException) return AppException.network(error);
    if (error is HttpException) return AppException.network(error);
    return AppException.unexpected(error);
  }
}
