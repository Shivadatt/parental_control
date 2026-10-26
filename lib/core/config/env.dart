import 'dart:convert';

/// Compile-time configuration.
///
/// Secrets must be supplied with `--dart-define` (or a gitignored
/// `--dart-define-from-file` file). Only the publishable Supabase anon key is
/// ever shipped to the client; service-role and TURN secrets stay server-side.
class Env {
  Env._();

  static const String appName = 'Parent Control';
  static const String qrScheme = 'parentcontrol';
  static const String authRedirectUrl = 'parentcontrol://auth-callback';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String defaultStunUrl = String.fromEnvironment(
    'STUN_URL',
    defaultValue: 'stun:stun.l.google.com:19302',
  );

  static String? get configurationProblem => backendConfigurationProblem(
        url: supabaseUrl,
        key: supabaseAnonKey,
      );

  static bool get isBackendConfigured => configurationProblem == null;

  /// Rejects URLs that would send credentials in clear text and keys that are
  /// privileged. The service-role and secret keys must never reach the APK.
  static String? backendConfigurationProblem({
    required String url,
    required String key,
  }) {
    if (url.trim().isEmpty) {
      return 'SUPABASE_URL is not set.';
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) {
      return 'SUPABASE_URL is not a valid absolute URL.';
    }
    final local = _isLocalHost(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      return 'SUPABASE_URL must use https (http is allowed only for a local '
          'development host such as localhost or 10.0.2.2).';
    }
    if (key.trim().isEmpty) {
      return 'SUPABASE_ANON_KEY is not set.';
    }
    final trimmedKey = key.trim();
    if (trimmedKey.startsWith('sb_secret_') ||
        _jwtRole(trimmedKey) == 'service_role') {
      return 'SUPABASE_ANON_KEY contains a privileged server key. Use only the '
          'publishable/anon key; rotate the server key if it was shipped.';
    }
    return null;
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '10.0.2.2';
  }

  static String? _jwtRole(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['role'] is String) {
        return decoded['role'] as String;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
