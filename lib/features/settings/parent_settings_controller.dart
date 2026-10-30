import 'dart:async';

import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/device.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/device_admin_service.dart';
import '../../data/services/local_settings_service.dart';
import '../../data/services/session_service.dart';
import '../remote_assistance/remote_session_registry.dart';
import 'account_privacy_repository.dart';
import 'delete_confirmation.dart';

class ParentSettingsController extends GetxController {
  ParentSettingsController({
    required this._authRepository,
    required this._session,
    required this._localSettings,
    required this._deviceAdmin,
    this._privacy,
  });

  final AuthRepository _authRepository;
  final SessionService _session;
  final LocalSettingsService _localSettings;
  final DeviceAdminService _deviceAdmin;
  final AccountPrivacyRepository? _privacy;

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

  // Privacy & data (account export, deletion, retention report).
  final RxBool isExporting = false.obs;
  final Rxn<AccountDataExport> lastExport = Rxn<AccountDataExport>();
  final RxBool isDeletingAccount = false.obs;
  final RxString accountDeletionBlockedReason = ''.obs;
  final Rxn<RetentionReport> retentionReport = Rxn<RetentionReport>();
  final RxBool isLoadingRetention = false.obs;
  final Rxn<AppException> retentionError = Rxn<AppException>();

  Device? get activeDevice => _session.activeDevice.value;
  String? get familyId => _session.activeFamily.value?.id;
  bool get isFamilyOwner {
    final family = _session.activeFamily.value;
    return family != null &&
        _session.userId.value.isNotEmpty &&
        family.ownerId == _session.userId.value;
  }

  /// Server report when loaded; otherwise the family settings already in the
  /// session, so the card never shows a blank window. Counts stay zero until
  /// the report arrives (they are labelled as server-reported).
  List<FamilyRetentionWindow> get retentionWindows {
    final report = retentionReport.value;
    if (report != null && report.families.isNotEmpty) return report.families;
    final family = _session.activeFamily.value;
    if (family == null) return const [];
    return [
      FamilyRetentionWindow(
        familyId: family.id,
        familyName: family.name,
        locationDays: family.settings.locationRetentionDays,
        usageDays: family.settings.usageRetentionDays,
      ),
    ];
  }

  @override
  void onInit() {
    super.onInit();
    syncFromServices();
    _loadAppVersion();
    if (_privacy != null) unawaited(loadRetentionReport());
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
    await loadRetentionReport();
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

  /// Returns the first reason the typed confirmation is not acceptable, or
  /// null. The server repeats the check; this gate prevents accidental taps.
  String? validateAccountDeletionInput({
    required String confirm,
    required String email,
  }) {
    return validateDeleteAccountInput(
      typedWord: confirm,
      typedEmail: email,
      accountEmail: this.email.value,
    );
  }

  /// Real server export; `lastExport` is set only after the server answered.
  Future<AccountDataExport?> exportMyData() async {
    if (isExporting.value) return null;
    final repository = _privacy;
    if (repository == null) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Data export is not available in this build.',
      );
      return null;
    }
    isExporting.value = true;
    actionError.value = null;
    lastExport.value = null;
    try {
      final result = await repository.exportMyData();
      lastExport.value = result;
      return result;
    } on AppException catch (error) {
      actionError.value = error;
      return null;
    } catch (error) {
      actionError.value = AppException.from(error);
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  Future<RetentionReport?> loadRetentionReport() async {
    if (isLoadingRetention.value) return null;
    final repository = _privacy;
    if (repository == null) return null;
    isLoadingRetention.value = true;
    retentionError.value = null;
    try {
      final report = await repository.loadRetentionReport();
      retentionReport.value = report;
      return report;
    } on AppException catch (error) {
      retentionError.value = error;
      return null;
    } catch (error) {
      retentionError.value = AppException.from(error);
      return null;
    } finally {
      isLoadingRetention.value = false;
    }
  }

  /// Two-step confirmation is enforced by the UI; this method re-validates and
  /// never deletes anything unless the server returns `deleted: true`.
  Future<bool> deleteAccount({
    required String confirm,
    required String email,
  }) async {
    if (isDeletingAccount.value) return false;
    accountDeletionBlockedReason.value = '';
    actionError.value = null;

    final validation = validateAccountDeletionInput(
      confirm: confirm,
      email: email,
    );
    if (validation != null) {
      actionError.value = AppException(AppErrorCodes.validation, validation);
      return false;
    }
    final repository = _privacy;
    if (repository == null) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Account deletion is not available in this build.',
      );
      return false;
    }

    isDeletingAccount.value = true;
    try {
      final outcome = await repository.deleteAccount(
        confirm: confirm,
        email: email,
      );
      if (!outcome.deleted) {
        final reason = outcome.blockedReason ??
            'The server did not delete the account. Try again.';
        accountDeletionBlockedReason.value = reason;
        actionError.value = AppException(AppErrorCodes.forbidden, reason);
        return false;
      }
      await _clearAfterAccountDeletion();
      return true;
    } on AppException catch (error) {
      actionError.value = error;
      return false;
    } catch (error) {
      actionError.value = AppException.from(error);
      return false;
    } finally {
      isDeletingAccount.value = false;
    }
  }

  Future<void> _clearAfterAccountDeletion() async {
    final registry = _remoteSessionRegistry;
    try {
      await registry?.releaseActive();
    } catch (_) {
      // Nothing to release; the account and its server rows are already gone.
    }
    _session.clear();
    try {
      await _localSettings.clearOnSignOut();
    } catch (_) {
      // Local preference cleanup is best effort after the server deletion.
    }
    try {
      if (_deviceAdmin.isAvailable) {
        await _deviceAdmin.stopGuardianService();
      }
    } catch (_) {
      // The guardian service stops with the signed-out session.
    }
    try {
      Get.offAllNamed(AppRoutes.roleSelection);
    } catch (_) {
      // The account is already deleted and the session cleared; a navigation
      // failure must not turn a successful deletion into a reported failure.
    }
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;
    isSigningOut.value = true;
    actionError.value = null;
    String? localWarning;
    final registry = _remoteSessionRegistry;
    try {
      // A live assistance session must not outlive the account session. The
      // parent is the end authority, so end it on the server first, best
      // effort: a failed end never blocks sign-out.
      try {
        await registry?.active?.endSession();
      } catch (_) {
        // The repository rejected the end; local teardown still happens below.
      }

      try {
        await _authRepository.signOut();
      } catch (caught) {
        actionError.value = AppException.from(caught);
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
    } finally {
      // Releases (and tears down media for) any assistance controller that is
      // still held before the app navigates away from the signed-in session.
      await registry?.releaseActive();
      isSigningOut.value = false;
    }
    Get.offAllNamed(AppRoutes.roleSelection);
    if (localWarning != null) {
      Get.snackbar('Signed out', localWarning);
    }
  }

  /// Registry only exists when the app booted normally; unit tests that build
  /// this controller without `main()` simply have no live session to release.
  RemoteSessionRegistry? get _remoteSessionRegistry {
    if (!Get.isRegistered<RemoteSessionRegistry>()) return null;
    return Get.find<RemoteSessionRegistry>();
  }
}
