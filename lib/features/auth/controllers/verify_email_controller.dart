import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

/// Verification gate. Nothing past this screen is opened until the server
/// reports `email_confirmed_at`.
class VerifyEmailController extends GetxController {
  VerifyEmailController({
    required AuthRepository authRepository,
    required FamilyRepository familyRepository,
    required SessionService session,
    required LocalSettingsService settings,
    required this._connectivity,
    required this._deviceAdmin,
  })  : _auth = authRepository,
        _session = session,
        _settings = settings,
        _flow = AuthSessionFlow(
          authRepository: authRepository,
          familyRepository: familyRepository,
          session: session,
          settings: settings,
        );

  final AuthRepository _auth;
  final SessionService _session;
  final LocalSettingsService _settings;
  final ConnectivityService _connectivity;
  final DeviceAdminService _deviceAdmin;
  final AuthSessionFlow _flow;

  final RxString email = ''.obs;
  final RxBool isResending = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isSigningOut = false.obs;
  final RxInt resendSeconds = 0.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final RxnString info = RxnString();

  Timer? _cooldownTimer;
  StreamSubscription<void>? _authSubscription;
  bool _disposed = false;
  bool _navigated = false;

  bool get isOnline => _connectivity.isOnline.value;
  bool get canResend =>
      !isResending.value && resendSeconds.value == 0 && !_disposed;
  bool get hasSession => _auth.currentUserId != null;

  @override
  void onInit() {
    super.onInit();
    // The confirmation link redirects to this app and the SDK exchanges the
    // code for a session; navigate as soon as the server reports verification.
    _authSubscription = _auth.authChanges.listen(
      (_) => unawaited(_resolveIfVerified()),
    );
  }

  Future<void> _resolveIfVerified() async {
    if (_disposed || _navigated || isRefreshing.value) return;
    if (!_auth.isEmailVerified) return;
    isRefreshing.value = true;
    try {
      final destination = await _flow.resolve();
      if (_disposed || _navigated) return;
      _navigated = true;
      openDestination(destination, email: email.value);
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isRefreshing.value = false;
    }
  }

  void prepare({String? emailAddress}) {
    final trimmed = emailAddress?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      email.value = trimmed;
      return;
    }
    if (_session.email.value.isNotEmpty) {
      email.value = _session.email.value;
      return;
    }
    email.value = _auth.currentEmail ?? '';
  }

  void clearMessages() {
    error.value = null;
    info.value = null;
  }

  Future<void> resend() async {
    if (!canResend) return;
    error.value = null;
    info.value = null;
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return;
    }
    isResending.value = true;
    try {
      await _auth.resendVerificationEmail(email: email.value);
      info.value =
          'A new verification email was requested. Check the inbox for '
          '${email.value.isEmpty ? 'your address' : email.value} and the spam '
          'folder.';
      _startCooldown();
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isResending.value = false;
    }
  }

  Future<void> refreshVerification() async {
    if (isRefreshing.value) return;
    error.value = null;
    info.value = null;
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return;
    }
    isRefreshing.value = true;
    try {
      final verified = await _auth.refreshEmailVerification();
      if (!verified) {
        info.value =
            'The server still reports this email as unverified. Open the newest '
            'verification email and try again. Nothing is unlocked yet.';
        return;
      }
      if (_disposed || _navigated) return;
      final destination = await _flow.resolve();
      _navigated = true;
      openDestination(destination, email: email.value);
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isRefreshing.value = false;
    }
  }

  /// For devices where the confirmation link was opened elsewhere: no local
  /// session exists, so the user must sign in before the app can check the
  /// server's `email_confirmed_at`.
  void signInInstead() {
    if (_disposed) return;
    _navigated = true;
    Get.offAllNamed(AppRoutes.login, arguments: {'email': email.value});
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;
    isSigningOut.value = true;
    String? warning;
    try {
      if (_session.isChild) {
        try {
          await _deviceAdmin.stopGuardianService();
        } catch (_) {
          warning =
              'The device guardian service could not be stopped on this '
              'device. Check the notification and stop it manually.';
        }
      }
      try {
        await _auth.signOut();
      } on AppException {
        warning =
            'The server sign-out could not be confirmed. This device was '
            'signed out locally; sign in again to retry.';
      }
      _session.clear();
      try {
        await _settings.clearOnSignOut();
      } catch (_) {
        warning ??=
            'Some local preferences could not be cleared on this device.';
      }
      openDestination(SignedInDestination.signedOut);
      if (warning != null) {
        Get.snackbar(
          'Signed out with a warning',
          warning,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      isSigningOut.value = false;
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    resendSeconds.value = 60;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_disposed && resendSeconds.value > 1) {
        resendSeconds.value -= 1;
      } else {
        resendSeconds.value = 0;
        timer.cancel();
        _cooldownTimer = null;
      }
    });
  }

  @override
  void onClose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    super.onClose();
  }
}
