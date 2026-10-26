/// Compile-time configuration.
///
/// Secrets must be supplied with `--dart-define` (or a gitignored
/// `--dart-define-from-file` file). Only the publishable Supabase anon key is
/// ever shipped to the client; service-role and TURN secrets stay server-side.
class Env {
  Env._();

  static const String appName = 'Parent Control';
  static const String qrScheme = 'parentcontrol';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String defaultStunUrl = String.fromEnvironment(
    'STUN_URL',
    defaultValue: 'stun:stun.l.google.com:19302',
  );

  static bool get isBackendConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        supabaseAnonKey.isNotEmpty;
  }
}
