import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';

/// Creates the parent's first family through the Edge Function. A 409 means an
/// active family already exists; it is reloaded instead of creating a second.
class FamilySetupController extends GetxController {
  FamilySetupController({
    required FamilyRepository familyRepository,
    required this._session,
    required this._settings,
    required this._connectivity,
  })  : _family = familyRepository;

  final FamilyRepository _family;
  final SessionService _session;
  final LocalSettingsService _settings;
  final ConnectivityService _connectivity;

  final RxBool isSubmitting = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<Family> createdFamily = Rxn<Family>();

  bool get isOnline => _connectivity.isOnline.value;

  void clearError() => error.value = null;

  Future<bool> create(String name) async {
    if (isSubmitting.value) return false;
    error.value = null;
    final problem = Validators.familyName(name);
    if (problem != null) {
      error.value = AppException(AppErrorCodes.validation, problem);
      return false;
    }
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return false;
    }

    isSubmitting.value = true;
    try {
      final family = await _family.createFamily(name.trim());
      createdFamily.value = family;
      await _applyFamily(family);
      return true;
    } on AppException catch (exception) {
      if (_isExistingFamilyConflict(exception)) {
        return _loadExistingFamily();
      }
      error.value = exception;
      return false;
    } catch (exception) {
      error.value = AppException.from(exception);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> _loadExistingFamily() async {
    try {
      final families = await _family.fetchMyFamilies();
      if (families.isEmpty) {
        error.value = const AppException(
          AppErrorCodes.conflict,
          'The server reports an existing family, but this account cannot read '
          'it yet. Refresh and try again.',
        );
        return false;
      }
      final family = families.first;
      createdFamily.value = family;
      await _applyFamily(family);
      return true;
    } on AppException catch (exception) {
      error.value = exception;
      return false;
    } catch (exception) {
      error.value = AppException.from(exception);
      return false;
    }
  }

  Future<void> _applyFamily(Family family) async {
    _session.setActiveFamily(family);
    try {
      await _settings.setActiveFamilyId(family.id);
    } catch (_) {
      // The server-confirmed family is still usable; the local hint only
      // preselects it next launch.
    }
    Get.offAllNamed(AppRoutes.parentShell);
  }

  bool _isExistingFamilyConflict(AppException exception) =>
      exception.statusCode == 409 ||
      exception.code == AppErrorCodes.conflict ||
      exception.code == 'family_exists' ||
      exception.code == 'already_exists';
}
