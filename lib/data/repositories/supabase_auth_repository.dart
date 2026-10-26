import 'dart:async';
import 'dart:io';

import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/json_utils.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/edge_api.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed authentication. Every operation goes through the public
/// Supabase client; tokens, passwords and secrets are never logged.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  static const String _emailNotConfirmedCode = 'email_not_confirmed';
  static const String _invalidCredentialsCode = 'invalid_credentials';
  static const String _userExistsCode = 'user_already_exists';
  static const String _weakPasswordCode = 'weak_password';
  static const String _samePasswordCode = 'same_password';

  @override
  String? get currentUserId => _supabase.currentUser?.id;

  @override
  String? get currentEmail => _supabase.currentUser?.email;

  @override
  bool get isEmailVerified =>
      _supabase.currentUser?.emailConfirmedAt != null;

  @override
  Stream<void> get authChanges =>
      _supabase.authStateChanges.map<void>((_) {});

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedName = displayName?.trim() ?? '';
    final metadata = <String, dynamic>{
      if (trimmedName.isNotEmpty) 'display_name': trimmedName,
    };
    try {
      await _supabase.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.authRedirectUrl,
        data: metadata.isEmpty ? null : metadata,
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.signOut();
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> resendVerificationEmail({String? email}) async {
    final address = (email ?? currentEmail)?.trim() ?? '';
    if (address.isEmpty) {
      throw const AppException(
        AppErrorCodes.validation,
        'Enter the email address that needs a new verification message.',
      );
    }
    try {
      await _supabase.client.auth.resend(
        email: address,
        type: OtpType.signup,
        emailRedirectTo: Env.authRedirectUrl,
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<bool> refreshEmailVerification() async {
    if (_supabase.currentSession == null) return false;
    try {
      final response = await _supabase.client.auth.refreshSession();
      var user = response.user ?? _supabase.client.auth.currentUser;
      user ??= (await _supabase.client.auth.getUser()).user;
      return user?.emailConfirmedAt != null;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Profile?> fetchProfile() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) return null;
    try {
      final row = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return Profile.fromJson(jsonMap(row));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Profile> setInitialRole({
    required ProfileRole role,
    String? displayName,
  }) async {
    if (!role.isChosen) {
      throw const AppException(
        AppErrorCodes.validation,
        'Choose whether this account is a parent or a child account.',
      );
    }
    final trimmedName = displayName?.trim() ?? '';
    try {
      final data = await _edgeApi.invokeMap(
        'auth-bootstrap',
        action: 'set_role',
        body: {
          'role': role.wireName,
          if (trimmedName.isNotEmpty) 'display_name': trimmedName,
        },
      );
      final profile = Profile.fromJson(data);
      if (profile.id.isEmpty || !profile.role.isChosen) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server did not confirm the role assignment. Try again.',
        );
      }
      return profile;
    } catch (error) {
      throw _mapError(error);
    }
  }

  AppException _mapError(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) return _mapAuthException(error);
    if (error is PostgrestException) return _mapPostgrestException(error);
    if (error is TimeoutException) return AppException.timeout(error);
    if (error is SocketException) return AppException.network(error);
    if (error is HttpException) return AppException.network(error);
    return AppException.unexpected(error);
  }

  AppException _mapAuthException(AuthException error) {
    final status = int.tryParse(error.statusCode ?? '');
    final code = error.code ?? '';
    switch (code) {
      case _emailNotConfirmedCode:
        return AppException(
          _emailNotConfirmedCode,
          'This email is not verified yet. Open the verification link, then '
              'try again.',
          statusCode: status,
        );
      case _invalidCredentialsCode:
        return AppException(
          _invalidCredentialsCode,
          'The email or password is incorrect.',
          statusCode: status,
        );
      case _userExistsCode:
      case 'email_exists':
        return AppException(
          _userExistsCode,
          'An account already exists for this email. Sign in instead.',
          statusCode: status,
        );
      case _weakPasswordCode:
        return AppException(
          _weakPasswordCode,
          'Choose a stronger password with at least 8 characters.',
          statusCode: status,
        );
      case _samePasswordCode:
        return AppException(
          _samePasswordCode,
          'The new password must be different from the current password.',
          statusCode: status,
        );
      case 'session_not_found':
      case 'refresh_token_not_found':
      case 'session_expired':
        return AppException(
          AppErrorCodes.sessionExpired,
          'Your session has expired. Sign in again.',
          statusCode: status,
        );
      case 'otp_expired':
        return AppException(
          AppErrorCodes.expired,
          'The verification link has expired. Request a new email.',
          statusCode: status,
        );
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return AppException(
          AppErrorCodes.rateLimited,
          'Too many attempts. Wait a moment before trying again.',
          statusCode: status,
        );
      case 'signup_disabled':
        return AppException(
          AppErrorCodes.forbidden,
          'New accounts are disabled for this project. Contact the owner.',
          statusCode: status,
        );
      default:
        break;
    }
    if (status == 429) {
      return AppException(
        AppErrorCodes.rateLimited,
        'Too many attempts. Wait a moment before trying again.',
        statusCode: status,
      );
    }
    if (error is AuthSessionMissingException) {
      return const AppException(
        AppErrorCodes.sessionExpired,
        'Your session has expired. Sign in again.',
      );
    }
    if (error is AuthRetryableFetchException || status == null) {
      return AppException.network(error);
    }
    if (status == 403) {
      return AppException(
        AppErrorCodes.forbidden,
        'You do not have permission to perform this action.',
        statusCode: status,
      );
    }
    if (status == 401) {
      return AppException(
        AppErrorCodes.unauthorized,
        'Authentication failed. Sign in again.',
        statusCode: status,
      );
    }
    return AppException(
      AppErrorCodes.unknown,
      'Authentication failed. Check your details and try again.',
      statusCode: status,
    );
  }

  AppException _mapPostgrestException(PostgrestException error) {
    switch (error.code) {
      case 'PGRST116':
        return const AppException(
          AppErrorCodes.notFound,
          'The requested record was not found or is not visible to this '
              'account.',
        );
      case '42501':
        return const AppException(
          AppErrorCodes.forbidden,
          'You do not have permission to read this data.',
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
