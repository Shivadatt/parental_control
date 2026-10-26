import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

/// Creates the auth account only. The permanent role is assigned later, after
/// the email is verified, through the role-lock screen.
class RegisterController extends GetxController {
  RegisterController({
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

  bool get isOnline => _connectivity.isOnline.value;

  void prepare({ProfileRole? role}) {
    if (role != null && role.isChosen) intendedRole.value = role;
  }

  void clearError() => error.value = null;

  Future<SignedInDestination?> signUp({
    required String displayName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (isSubmitting.value) return null;
    error.value = null;

    final nameProblem = Validators.displayName(displayName);
    if (nameProblem != null) {
      error.value = AppException(AppErrorCodes.validation, nameProblem);
      return null;
    }
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
    if (password != confirmPassword) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'The passwords do not match.',
      );
      return null;
    }
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return null;
    }

    isSubmitting.value = true;
    try {
      await _auth.signUp(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );
      final userId = _auth.currentUserId;
      if (userId == null || userId.isEmpty || !_auth.isEmailVerified) {
        // Supabase may require email confirmation, in which case there is no
        // session yet. Neither case may assign a role.
        openDestination(
          SignedInDestination.verifyEmail,
          email: email.trim(),
        );
        return SignedInDestination.verifyEmail;
      }
      final destination = await _flow.resolve();
      openDestination(destination, email: email.trim());
      return destination;
    } on AppException catch (exception) {
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
