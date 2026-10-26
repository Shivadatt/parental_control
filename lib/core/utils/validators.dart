class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _pairingCode = RegExp(r'^[A-Z0-9]{8,12}$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (!_email.hasMatch(input)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Password is required';
    if (input.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  static String? familyName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Family name is required';
    if (input.length > 80) return 'Keep the name under 80 characters';
    return null;
  }

  static String? displayName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Display name is required';
    if (input.length > 60) return 'Keep the name under 60 characters';
    return null;
  }

  static String? pairingCode(String? value) {
    final normalized = normalizePairingCode(value ?? '');
    if (normalized.isEmpty) return 'Linking code is required';
    if (!_pairingCode.hasMatch(normalized)) {
      return 'Enter the 8-character code shown on the child device';
    }
    return null;
  }

  static String normalizePairingCode(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
