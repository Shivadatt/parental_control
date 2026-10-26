import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/device.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/session_service.dart';

class ParentSettingsController extends GetxController {
  ParentSettingsController({
    required this._authRepository,
    required this._session,
    required this._localSettings,
    required this._deviceAdmin,
  });

  final AuthRepository _authRepository;
  final SessionService _session;
  final LocalSettingsService _localSettings;
  final DeviceAdminService _deviceAdmin;

  final RxString email = ''.obs;
  final RxString displayName = ''.obs;
  final RxString roleLabel = 'Unknown'.obs;
  final RxBool emailVerified = false.obs;
  final RxString familyName = ''.obs;
  final RxString familyRole = 'No active family'.obs;
  final Rxn<FamilySettings> retention = Rxn<FamilySettings>();
  final RxBool notificationsEnabled = true.obs;
  final RxBool locationReminderEnabled = true.obs;
  final RxBool isSavingNotifications = false.obs;
  final RxBool isSavingLocationReminder = false.obs;
  final RxString appVersion = 'Unknown'.obs;
  final RxBool isLoadingVersion = false.obs;
  final RxBool isSigningOut = false.obs;
  final Rxn<AppException> actionError = Rxn<AppException>();

  Device? get activeDevice => _session.activeDevice.value;
  String? get familyId => _session.activeFamily.value?.id;
  bool get isFamilyOwner {
    final family = _session.activeFamily.value;
    return family != null &&
        _session.userId.value.isNotEmpty &&
        family.ownerId == _session.userId.value;
  }

  @override
  void onInit() {
    super.onInit();
    syncFromServices();
    _loadAppVersion();
  }

  void syncFromServices() {
    email.value = _session.email.value;
    displayName.value = _session.displayName;
    emailVerified.value = _session.emailVerified.value;
    final profile = _session.profile.value;
    roleLabel.value = profile == null
        ? 'Unknown'
        : (profile.role == ProfileRole.parent
            ? 'Parent'
            : profile.role == ProfileRole.child
                ? 'Child'
                : 'Not set');
    final family = _session.activeFamily.value;
    familyName.value = family?.name ?? 'No active family';
    familyRole.value = family == null
        ? 'No active family'
        : (family.ownerId == _session.userId.value
            ? 'Owner'
            : 'Parent member');
    retention.value = family?.settings;
    try {
      notificationsEnabled.value = _localSettings.notificationsEnabled;
      locationReminderEnabled.value = _localSettings.locationSharingEnabled;
    } catch (_) {
      actionError.value = const AppException(
        AppErrorCodes.unknown,
        'Local preferences could not be read on this phone.',
      );
    }
  }

  @override
  Future<void> refresh() async {
    syncFromServices();
    await _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    if (!_deviceAdmin.isAvailable) {
      appVersion.value = 'Unavailable outside Android';
      return;
    }
    isLoadingVersion.value = true;
    try {
      final capabilities = await _deviceAdmin.getCapabilities();
      appVersion.value =
          capabilities.appVersion.isEmpty ? 'Unknown' : capabilities.appVersion;
    } catch (_) {
      appVersion.value = 'Unavailable';
    } finally {
      isLoadingVersion.value = false;
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (isSavingNotifications.value) return;
    isSavingNotifications.value = true;
    actionError.value = null;
    try {
      await _localSettings.setNotificationsEnabled(value);
      notificationsEnabled.value = value;
    } catch (_) {
      actionError.value = const AppException(
        AppErrorCodes.unknown,
        'The local notification preference could not be saved on this phone.',
      );
    } finally {
      isSavingNotifications.value = false;
    }
  }

  Future<void> setLocationReminderEnabled(bool value) async {
    if (isSavingLocationReminder.value) return;
    isSavingLocationReminder.value = true;
    actionError.value = null;
    try {
      await _localSettings.setLocationSharingEnabled(value);
      locationReminderEnabled.value = value;
    } catch (_) {
      actionError.value = const AppException(
        AppErrorCodes.unknown,
        'The local location reminder preference could not be saved on this '
        'phone.',
      );
    } finally {
      isSavingLocationReminder.value = false;
    }
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;
    isSigningOut.value = true;
    actionError.value = null;
    String? localWarning;
    try {
      await _authRepository.signOut();
    } catch (caught) {
      actionError.value = AppException.from(caught);
      isSigningOut.value = false;
      return;
    }

    _session.clear();
    try {
      await _localSettings.clearOnSignOut();
    } catch (_) {
      localWarning = 'Some local preferences could not be cleared.';
    }
    try {
      if (_deviceAdmin.isAvailable) {
        await _deviceAdmin.stopGuardianService();
      }
    } catch (_) {
      localWarning ??=
          'The background guardian service could not be stopped on this phone.';
    }
    isSigningOut.value = false;
    Get.offAllNamed(AppRoutes.roleSelection);
    if (localWarning != null) {
      Get.snackbar('Signed out', localWarning);
    }
  }
}
