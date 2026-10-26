import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

/// Pre-login this screen records an *intended* role locally. After sign-in it
/// can lock the initial server role exactly once. A local choice is never
/// authorization; the Edge Function enforces verification and validity.
class RoleSelectionController extends GetxController {
  RoleSelectionController({
    required AuthRepository authRepository,
    required FamilyRepository familyRepository,
    required SessionService session,
    required LocalSettingsService settings,
    required this._connectivity,
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
  final AuthSessionFlow _flow;

  final RxBool isLockMode = false.obs;
  final RxBool isSubmitting = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final RxString cachedRole = ''.obs;
  final RxString displayNamePrefill = ''.obs;

  bool _roleSubmitted = false;

  bool get isOnline => _connectivity.isOnline.value;
  bool get isAuthenticated => _session.isAuthenticated;
  bool get hasServerRole => _session.hasChosenRole;
  ProfileRole get intendedRole => ProfileRole.fromWire(cachedRole.value);
  ProfileRole get serverRole => _session.profile.value?.role ?? ProfileRole.unset;

  void prepare({bool lockRequested = false}) {
    cachedRole.value = _settings.cachedRole ?? '';
    if (!_session.isAuthenticated) {
      isLockMode.value = false;
      displayNamePrefill.value = '';
      return;
    }
    displayNamePrefill.value = _session.profile.value?.displayName ?? '';
    isLockMode.value = _session.needsRoleSelection ||
        (lockRequested && !_session.hasChosenRole);
  }

  void clearError() => error.value = null;

  Future<bool> continueToLogin(ProfileRole role) =>
      _rememberAndOpen(role, register: false);

  Future<bool> createAccount(ProfileRole role) =>
      _rememberAndOpen(role, register: true);

  Future<bool> _rememberAndOpen(
    ProfileRole role, {
    required bool register,
  }) async {
    if (isLockMode.value) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'Your role is already being set for this account.',
      );
      return false;
    }
    if (!role.isChosen) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'Choose Parent mode or Child mode.',
      );
      return false;
    }
    error.value = null;
    try {
      await _settings.setCachedRole(role.wireName);
      cachedRole.value = role.wireName;
    } catch (exception) {
      error.value = AppException.from(exception);
      return false;
    }
    Get.toNamed(
      register ? AppRoutes.register : AppRoutes.login,
      arguments: {'role': role.wireName},
    );
    return true;
  }

  /// Calls `auth-bootstrap set_role` at most once for a successful assignment.
  Future<bool> setInitialRole({
    required ProfileRole role,
    required String displayName,
  }) async {
    if (!isLockMode.value) {
      error.value = const AppException(
        AppErrorCodes.forbidden,
        'Sign in with an unassigned account before setting a role.',
      );
      return false;
    }
    if (_roleSubmitted || isSubmitting.value) return false;
    if (!role.isChosen) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'Choose Parent mode or Child mode.',
      );
      return false;
    }
    final nameProblem = Validators.displayName(displayName);
    if (nameProblem != null) {
      error.value = AppException(AppErrorCodes.validation, nameProblem);
      return false;
    }
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return false;
    }

    _roleSubmitted = true;
    isSubmitting.value = true;
    error.value = null;
    try {
      final profile = await _auth.setInitialRole(
        role: role,
        displayName: displayName.trim(),
      );
      if (!profile.role.isChosen) {
        throw const AppException(
          AppErrorCodes.unknown,
          'The server did not confirm a role. Try again.',
        );
      }
      _session.setProfile(profile);
      try {
        await _settings.setCachedRole(profile.role.wireName);
      } catch (_) {
        // The server already assigned the role; a local cache failure must not
        // trigger a second assignment attempt.
      }
      if (profile.role.isParent) {
        Get.offAllNamed(AppRoutes.familySetup);
      } else {
        Get.offAllNamed(AppRoutes.childEnrollment);
      }
      return true;
    } on AppException catch (exception) {
      _roleSubmitted = false;
      error.value = exception;
      return false;
    } catch (exception) {
      _roleSubmitted = false;
      error.value = AppException.from(exception);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Used when the account already has a server role (for example after a
  /// process restart) so the screen does not pretend a new choice is possible.
  Future<void> resume() async {
    if (isSubmitting.value) return;
    error.value = null;
    isSubmitting.value = true;
    try {
      final destination = await _flow.resolve();
      if (destination == SignedInDestination.chooseRole) {
        isLockMode.value = true;
        displayNamePrefill.value =
            _session.profile.value?.displayName ?? displayNamePrefill.value;
        return;
      }
      openDestination(destination);
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isSubmitting.value = false;
    }
  }
}
