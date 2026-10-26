import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

/// Signs in and routes strictly from server state. A local role argument is
/// informational only; it never grants access.
class LoginController extends GetxController {
  LoginController({
    required AuthRepository authRepository,
    required FamilyRepository familyRepository,
    required SessionService session,
    required LocalSettingsService settings,
    required this._connectivity,
  })  : _auth = authRepository,
        _flow = AuthSessionFlow(
          authRepository: authRepository,
          familyRepository: familyRepository,
          session: session,
          settings: settings,
        );

  final AuthRepository _auth;
  final ConnectivityService _connectivity;
  final AuthSessionFlow _flow;

  final RxBool isSubmitting = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rx<ProfileRole> intendedRole = ProfileRole.unset.obs;
  final RxString initialEmail = ''.obs;

  bool get isOnline => _connectivity.isOnline.value;

  void prepare({String? email, ProfileRole? role}) {
    final trimmedEmail = email?.trim() ?? '';
    if (trimmedEmail.isNotEmpty) initialEmail.value = trimmedEmail;
    if (role != null && role.isChosen) intendedRole.value = role;
  }

  void clearError() => error.value = null;

  /// Returns the destination the server state produced, or null on failure.
  /// Navigation happens here only after the repositories answered.
  Future<SignedInDestination?> signIn({
    required String email,
    required String password,
  }) async {
    if (isSubmitting.value) return null;
    error.value = null;

    final emailProblem = Validators.email(email);
    if (emailProblem != null) {
      error.value = AppException(AppErrorCodes.validation, emailProblem);
      return null;
    }
    final passwordProblem = Validators.password(password);
    if (passwordProblem != null) {
      error.value = AppException(AppErrorCodes.validation, passwordProblem);
      return null;
    }
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return null;
    }

    isSubmitting.value = true;
    try {
      await _auth.signIn(email: email.trim(), password: password);
      final userId = _auth.currentUserId;
      if (userId == null || userId.isEmpty) {
        throw const AppException(
          AppErrorCodes.unknown,
          'Sign-in did not establish a session. Try again.',
        );
      }
      final destination = await _flow.resolve();
      openDestination(destination, email: email.trim());
      return destination;
    } on AppException catch (exception) {
      if (exception.code == 'email_not_confirmed') {
        openDestination(
          SignedInDestination.verifyEmail,
          email: email.trim(),
        );
        return SignedInDestination.verifyEmail;
      }
      error.value = exception;
      return null;
    } catch (exception) {
      error.value = AppException.from(exception);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }
}
