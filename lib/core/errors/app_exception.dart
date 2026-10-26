import 'dart:async';
import 'dart:io';

/// Stable error codes shared by the Flutter client and Edge Functions.
class AppErrorCodes {
  AppErrorCodes._();

  static const backendNotConfigured = 'backend_not_configured';
  static const network = 'network_error';
  static const timeout = 'timeout';
  static const unauthorized = 'unauthorized';
  static const sessionExpired = 'session_expired';
  static const forbidden = 'forbidden';
  static const notFound = 'not_found';
  static const conflict = 'conflict';
  static const validation = 'validation_error';
  static const rateLimited = 'rate_limited';
  static const expired = 'expired';
  static const unsupported = 'unsupported';
  static const deviceNotTrusted = 'device_not_trusted';
  static const nativeError = 'native_error';
  static const unknown = 'unknown';
}

class AppException implements Exception {
  const AppException(this.code, this.message, {this.statusCode, this.cause});

  final String code;
  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isConfiguration => code == AppErrorCodes.backendNotConfigured;
  bool get isNetwork => code == AppErrorCodes.network || code == AppErrorCodes.timeout;
  bool get isAuth =>
      code == AppErrorCodes.unauthorized || code == AppErrorCodes.sessionExpired;
  bool get isForbidden => code == AppErrorCodes.forbidden;
  bool get isUnsupported => code == AppErrorCodes.unsupported;
  bool get isExpired => code == AppErrorCodes.expired;
  bool get isRateLimited => code == AppErrorCodes.rateLimited;

  factory AppException.backendNotConfigured() => const AppException(
        AppErrorCodes.backendNotConfigured,
        'The backend is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY '
        'as --dart-define values, then restart the app.',
      );

  factory AppException.network([Object? cause]) => AppException(
        AppErrorCodes.network,
        'The network is unavailable. Check your connection and try again.',
        cause: cause,
      );

  factory AppException.timeout([Object? cause]) => AppException(
        AppErrorCodes.timeout,
        'The request timed out. Try again.',
        cause: cause,
      );

  factory AppException.native(String message, [Object? cause]) => AppException(
        AppErrorCodes.nativeError,
        message,
        cause: cause,
      );

  factory AppException.unexpected(Object cause) => AppException(
        AppErrorCodes.unknown,
        'Something went wrong. Please try again.',
        cause: cause,
      );

  /// Maps transport-level failures to a user-safe exception.
  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is TimeoutException) return AppException.timeout(error);
    if (error is SocketException) return AppException.network(error);
    return AppException.unexpected(error);
  }

  @override
  String toString() => 'AppException($code): $message';
}
