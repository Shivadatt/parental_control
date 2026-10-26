import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import 'supabase_service.dart';

/// Thin client for the project's Edge Functions. Every function uses the same
/// `{ok, data}` / `{ok, error}` envelope and validates its caller server-side.
class EdgeApi extends GetxService {
  EdgeApi(this._supabase);

  final SupabaseService _supabase;

  Future<dynamic> invoke(
    String function, {
    required String action,
    Map<String, dynamic> body = const {},
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_supabase.isConfigured) throw AppException.backendNotConfigured();
    if (!_supabase.isReady) {
      throw _supabase.initError ?? AppException.backendNotConfigured();
    }

    try {
      final response = await _supabase.client.functions
          .invoke(
            function,
            headers: headers,
            body: {'action': action, ...body},
          )
          .timeout(timeout);
      final envelope = jsonMap(response.data);
      if (envelope['ok'] == false) {
        throw _errorFromPayload(envelope['error'], response.status);
      }
      return envelope['data'] ?? <String, dynamic>{};
    } on AppException {
      rethrow;
    } on FunctionException catch (error) {
      throw _errorFromFunction(error);
    } on TimeoutException catch (error) {
      throw AppException.timeout(error);
    } on SocketException catch (error) {
      throw AppException.network(error);
    } on HttpException catch (error) {
      throw AppException.network(error);
    } catch (error) {
      throw AppException.unexpected(error);
    }
  }

  Future<Map<String, dynamic>> invokeMap(
    String function, {
    required String action,
    Map<String, dynamic> body = const {},
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final data = await invoke(
      function,
      action: action,
      body: body,
      headers: headers,
      timeout: timeout,
    );
    return jsonMap(data);
  }

  Future<List<dynamic>> invokeList(
    String function, {
    required String action,
    Map<String, dynamic> body = const {},
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final data = await invoke(
      function,
      action: action,
      body: body,
      headers: headers,
      timeout: timeout,
    );
    return jsonList(data);
  }

  AppException _errorFromFunction(FunctionException error) {
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
    return _errorFromPayload(
      nested.isNotEmpty ? nested : details,
      error.status,
    );
  }

  AppException _errorFromPayload(Object? payload, int status) {
    final map = jsonMap(payload);
    final code = jsonString(map['code']) ?? _codeForStatus(status);
    final message = jsonString(map['message']) ?? _messageForStatus(status);
    return AppException(code, message, statusCode: status);
  }

  String _codeForStatus(int status) {
    switch (status) {
      case 400:
        return AppErrorCodes.validation;
      case 401:
        return AppErrorCodes.unauthorized;
      case 403:
        return AppErrorCodes.forbidden;
      case 404:
        return AppErrorCodes.notFound;
      case 409:
        return AppErrorCodes.conflict;
      case 410:
        return AppErrorCodes.expired;
      case 429:
        return AppErrorCodes.rateLimited;
      default:
        return AppErrorCodes.unknown;
    }
  }

  String _messageForStatus(int status) {
    switch (status) {
      case 400:
        return 'The request was rejected. Check the submitted values.';
      case 401:
        return 'Your session has expired. Sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested item was not found.';
      case 409:
        return 'This action conflicts with the current state.';
      case 410:
        return 'This link or request has expired.';
      case 429:
        return 'Too many attempts. Wait a moment and try again.';
      default:
        return 'The server could not complete the request. Try again.';
    }
  }
}
