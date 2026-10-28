import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/models/child_enforcement.dart';
import 'package:parent_control/features/child/services/child_preferences.dart';

/// Drives the child shell: linked family, this device's registration, the
/// latest downloaded policy and the visible background services.
///
/// Server rows and native DevicePolicyManager results are shown separately; a
/// configured rule is never described as enforced until Android confirms it.
class ChildShellController extends GetxController {
  ChildShellController({
    required this._familyRepository,
    required this._pairingRepository,
    required this._deviceRepository,
    required this._remoteSessionRepository,
    required this._policyRepository,
    required this._authRepository,
    required this._session,
    required this._localSettings,
    required this._connectivity,
    required this._deviceAdmin,
    required this._preferences,
  });

  final FamilyRepository _familyRepository;
  final PairingRepository _pairingRepository;
  final DeviceRepository _deviceRepository;
  final RemoteSessionRepository _remoteSessionRepository;
  final PolicyRepository _policyRepository;
  final AuthRepository _authRepository;
  final SessionService _session;
  final LocalSettingsService _localSettings;
  final ConnectivityService _connectivity;
  final DeviceAdminService _deviceAdmin;
  final ChildPreferences _preferences;

  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final RxnString actionMessage = RxnString();
  final RxnString syncWarning = RxnString();
  final RxnString locationWarning = RxnString();
  final Rxn<Family> family = Rxn<Family>();
  final Rxn<Device> device = Rxn<Device>();
  final Rxn<DevicePolicy> policy = Rxn<DevicePolicy>();
  final Rxn<AppException> policyError = Rxn<AppException>();
  final Rxn<DeviceCapabilities> capabilities = Rxn<DeviceCapabilities>();
  final Rxn<GuardianServiceStatus> guardian = Rxn<GuardianServiceStatus>();
  final RxList<PairingRequest> pendingPairings = <PairingRequest>[].obs;
  final RxList<RemoteSession> pendingSessions = <RemoteSession>[].obs;
  static const int tabCount = 4;
  final RxInt tabIndex = 0.obs;
  final Rxn<AppException> pendingError = Rxn<AppException>();
  final RxBool locationSharingEnabled = false.obs;
  final RxBool isStartingGuardian = false.obs;
  final RxBool isUpdatingLocation = false.obs;
  final RxBool isUnlinking = false.obs;
  final RxBool isSigningOut = false.obs;
  final RxBool isVerifyingEnforcement = false.obs;
  final Rxn<AppException> verificationError = Rxn<AppException>();
  final RxList<ChildEnforcedApp> verifiedApps = <ChildEnforcedApp>[].obs;
  final Rxn<DateTime> lastLoadedAt = Rxn<DateTime>();

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  bool _syncConfigured = false;
  bool _verificationRan = false;
  bool _loadInFlight = false;

  bool get isEnrolled => family.value != null && device.value != null;
  bool get hasFamily => family.value != null;
  bool get hasDevice => device.value != null;
  bool get needsEnrollment => family.value == null;
  bool get isOnline => _connectivity.isOnline.value;
  bool get isManaged => capabilities.value?.isFullyManaged ?? false;
  bool get canVerifySuspension => isManaged;
  bool get guardianRunning => guardian.value?.running ?? false;
  int get pendingCount => pendingPairings.length + pendingSessions.length;

  String get displayName => _session.displayName;
  String get email => _session.email.value;
  String get familyName => family.value?.name ?? 'No family linked';
  String get deviceName => device.value?.displayName ?? 'This Android device';

  String get guardianStatusLabel {
    if (!_deviceAdmin.isAvailable) return 'Unavailable on this platform';
    if (guardianRunning) return 'Running with a visible notification';
    final lastError = guardian.value?.lastError;
    if (lastError != null && lastError.trim().isNotEmpty) {
      return 'Not running — $lastError';
    }
    return 'Not running';
  }

  String get enforcementLabel {
    final caps = capabilities.value;
    if (caps == null) return 'Checking this phone…';
    if (!caps.available) return 'Unavailable on this platform';
    if (caps.isDeviceOwner) return 'Managed by Device Owner';
    if (caps.isAdminActive) {
      return 'Device admin only — app blocking is not available';
    }
    return 'Not managed — app blocking is not available';
  }

  String get lastLoadedLabel {
    final value = lastLoadedAt.value;
    if (value == null) return 'Not loaded yet';
    return 'Updated ${value.toLocal()}';
  }

  bool get showPendingWarning =>
      pendingError.value != null ||
      pendingPairings.isNotEmpty ||
      pendingSessions.isNotEmpty;

  void selectTab(int index) {
    if (index < 0 || index >= tabCount) return;
    tabIndex.value = index;
  }

  @override
  void onInit() {
    super.onInit();
    _listenToNativeEvents();
    unawaited(load());
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    final firstLoad = lastLoadedAt.value == null;
    if (showLoading && firstLoad) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }
    error.value = null;
    try {
      if (!_connectivity.isOnline.value) {
        if (firstLoad) {
          error.value = AppException.network();
        } else {
          actionError.value = AppException.network();
        }
        return;
      }
      await _loadMembershipAndDevice();
      await _loadPendingRequests();
      await _loadLocationPreference();
      lastLoadedAt.value = DateTime.now();
    } catch (caught) {
      final mapped = AppException.from(caught);
      if (firstLoad || (family.value == null && device.value == null)) {
        error.value = mapped;
      } else {
        actionError.value = mapped;
      }
    } finally {
      _loadInFlight = false;
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  @override
  Future<void> refresh() => load(showLoading: false);

  Future<void> _loadMembershipAndDevice() async {
    final member = await _familyRepository.fetchMyMembership();
    if (member == null ||
        !member.isActive ||
        member.role != FamilyMemberRole.child) {
      await _clearLinkedState(stopServices: true);
      capabilities.value = await _readCapabilities();
      guardian.value = await _readGuardianStatus();
      policy.value = null;
      return;
    }
    final loadedFamily = await _familyRepository.fetchFamily(member.familyId);
    if (loadedFamily == null) {
      throw const AppException(
        AppErrorCodes.notFound,
        'Your family is no longer available to this account. Ask your guardian '
        'to link this phone again.',
      );
    }
    family.value = loadedFamily;
    _session.setActiveFamily(loadedFamily);
    await _localSettings.setActiveFamilyId(loadedFamily.id);

    final loadedDevice = await _deviceRepository.fetchMyDevice();
    if (loadedDevice != null &&
        loadedDevice.familyId.isNotEmpty &&
        loadedDevice.familyId != loadedFamily.id) {
      throw const AppException(
        AppErrorCodes.conflict,
        'This account has a device in another family. This screen will not '
        'present it as linked to the family above.',
      );
    }
    device.value = loadedDevice;
    _session.setActiveDevice(loadedDevice);
    capabilities.value = await _readCapabilities();
    guardian.value = await _readGuardianStatus();

    if (loadedDevice == null) {
      policy.value = null;
      await _stopNativeServices(clearPreference: false);
      return;
    }

    await _ensureIdentityAndSync(loadedDevice, loadedFamily);
    await _loadPolicy(loadedDevice);
    guardian.value = await _readGuardianStatus();
    await _loadLocationPreference();
    await _resumeBackgroundWork();
    guardian.value = await _readGuardianStatus();
  }

  Future<void> _clearLinkedState({required bool stopServices}) async {
    family.value = null;
    device.value = null;
    policy.value = null;
    pendingPairings.clear();
    pendingSessions.clear();
    _session.setActiveFamily(null);
    _session.setActiveDevice(null);
    _session.setDeviceIdentity(null);
    try {
      await _localSettings.setActiveFamilyId(null);
    } catch (_) {
      // The server state still decides access; a stale local label is harmless.
    }
    if (stopServices) {
      await _stopNativeServices(clearPreference: true);
    }
  }

  Future<void> _stopNativeServices({
    required bool clearPreference,
    bool stopMicrophone = true,
  }) async {
    if (clearPreference) {
      locationSharingEnabled.value = false;
      try {
        await _preferences.setLocationSharingEnabled(false);
      } catch (_) {
        // The service is stopped below regardless of the preference write.
      }
    }
    if (!_deviceAdmin.isAvailable) return;
    if (stopMicrophone) {
      await _stopMicrophoneService();
    }
    try {
      await _deviceAdmin.stopLocationTracking();
    } catch (_) {
      // Reported through the service status or the next visible action.
    }
    try {
      await _deviceAdmin.stopGuardianService();
    } catch (_) {
      // Reported through the service status or the next visible action.
    }
  }

  /// Stops the visible microphone foreground service. A stopped enrolment must
  /// never leave an audio assistance service capturing on this phone.
  Future<void> _stopMicrophoneService() async {
    if (!_deviceAdmin.isAvailable) return;
    try {
      await _deviceAdmin.stopAudioAssistanceService();
    } catch (_) {
      // Best effort: the next load reports what Android still runs.
    }
  }

  /// Ends any assistance session that is still open for this phone. Called
  /// before the enrolment is removed so a dead peer never stays "live" on the
  /// guardian's screen. Best effort, like the other teardown steps.
  Future<void> _endOpenAssistanceSessions({required String reason}) async {
    final currentFamily = family.value;
    final currentDevice = device.value;
    if (currentFamily == null || currentDevice == null) return;
    if (!_connectivity.isOnline.value) return;
    List<RemoteSession> sessions;
    try {
      sessions = await _remoteSessionRepository.fetchForFamily(
        currentFamily.id,
        limit: 10,
      );
    } catch (_) {
      return;
    }
    final userId = _session.userId.value;
    for (final entry in sessions) {
      if (!entry.status.isOpen) continue;
      if (entry.deviceId != currentDevice.id) continue;
      if (userId.isNotEmpty && entry.childUserId != userId) continue;
      try {
        await _remoteSessionRepository.end(
          sessionId: entry.id,
          reason: reason,
        );
      } catch (_) {
        // Local capture and the microphone service are already stopped.
      }
    }
  }

  Future<DeviceCapabilities> _readCapabilities() async {
    try {
      return await _deviceAdmin.getCapabilities();
    } catch (_) {
      syncWarning.value =
          'Android settings could not be read on this phone. Capabilities and '
          'permission states are unknown.';
      return DeviceCapabilities.empty();
    }
  }

  Future<GuardianServiceStatus?> _readGuardianStatus() async {
    if (!_deviceAdmin.isAvailable) return null;
    try {
      return await _deviceAdmin.getGuardianServiceStatus();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPolicy(Device loadedDevice) async {
    try {
      policy.value = await _policyRepository.fetchLatestPolicy(loadedDevice.id);
      policyError.value = null;
      verifiedApps.clear();
      verificationError.value = null;
      _verificationRan = false;
    } catch (caught) {
      policyError.value = AppException.from(caught);
    }
  }

  Future<void> ensureVerification() async {
    if (_verificationRan || policy.value == null) return;
    _verificationRan = true;
    await verifyEnforcement();
  }

  Future<void> retryVerification() async {
    _verificationRan = true;
    await verifyEnforcement();
  }

  /// Asks Android, package by package, whether the configured blocks are
  /// actually suspended. Without Device Owner control the result stays
  /// "not verified" instead of claiming enforcement.
  Future<void> verifyEnforcement() async {
    final current = policy.value;
    if (current == null || isVerifyingEnforcement.value) return;
    isVerifyingEnforcement.value = true;
    verificationError.value = null;
    try {
      final rules = <String, AppRule>{};
      for (final rule in current.payload.appRules.where((item) => item.blocked)) {
        rules[rule.packageName] = rule;
      }
      for (final packageName in current.payload.blockedPackages) {
        rules.putIfAbsent(
          packageName,
          () => AppRule(
            packageName: packageName,
            label: packageName,
            blocked: true,
          ),
        );
      }
      if (rules.isEmpty) {
        verifiedApps.clear();
        return;
      }
      Map<String, String> labels = const {};
      final managed = capabilities.value?.isFullyManaged ?? false;
      if (managed) {
        try {
          final installed = await _deviceAdmin.getInstalledApps();
          labels = {
            for (final app in installed) app.packageName: app.label,
          };
        } catch (_) {
          // Labels are cosmetic; the suspension check below is what matters.
        }
      }
      final results = <ChildEnforcedApp>[];
      for (final entry in rules.entries) {
        bool? suspended;
        if (managed) {
          try {
            suspended =
                await _deviceAdmin.isPackageSuspended(entry.key);
          } catch (_) {
            suspended = null;
          }
        }
        results.add(
          ChildEnforcedApp(
            packageName: entry.key,
            label: labels[entry.key] ?? entry.value.label,
            isScheduleRule: entry.value.windows.isNotEmpty,
            rule: entry.value,
            suspended: suspended,
          ),
        );
      }
      results.sort(
        (left, right) =>
            left.label.toLowerCase().compareTo(right.label.toLowerCase()),
      );
      verifiedApps.assignAll(results);
    } catch (caught) {
      verificationError.value = AppException.from(caught);
    } finally {
      isVerifyingEnforcement.value = false;
    }
  }

  Future<void> _ensureIdentityAndSync(
    Device loadedDevice,
    Family loadedFamily,
  ) async {
    if (!_deviceAdmin.isAvailable) {
      syncWarning.value =
          'Background protection is available only in the Android app.';
      return;
    }
    DeviceIdentity identity;
    try {
      final nativeIdentity = await _deviceAdmin.getIdentity();
      identity = nativeIdentity.copyWith(serverDeviceId: loadedDevice.id);
      _session.setDeviceIdentity(identity);
    } catch (caught) {
      syncWarning.value = AppException.from(caught).message;
      return;
    }
    final uri = Uri.tryParse(Env.supabaseUrl);
    if (!Env.isBackendConfigured ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      syncWarning.value =
          'Background sync needs an HTTPS backend URL and a publishable key '
          'compiled into this build. It is not configured here.';
      return;
    }
    try {
      final configured = await _deviceAdmin.configureBackgroundSync(
        supabaseUrl: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
        deviceId: loadedDevice.id,
        deviceSecret: identity.secret,
        familyId: loadedFamily.id,
      );
      _syncConfigured = configured;
      if (!configured) {
        syncWarning.value =
            'Android could not save the background sync configuration.';
      }
    } catch (caught) {
      _syncConfigured = false;
      syncWarning.value = AppException.from(caught).message;
    }
  }

  Future<void> _resumeBackgroundWork() async {
    final caps = capabilities.value;
    if (caps == null || !caps.available) return;
    final notifications = caps.notificationsGranted;
    if (_syncConfigured) {
      if (!notifications) {
        syncWarning.value ??=
            'Notifications are blocked, so Android will not run the visible '
            'background guardian service. Allow notifications in Rules & '
            'permissions.';
      } else {
        try {
          final started = await _deviceAdmin.startGuardianService();
          if (!started) {
            syncWarning.value ??=
                'The background guardian service did not start. Android may '
                'have blocked it or the sync configuration is incomplete.';
          }
        } catch (caught) {
          syncWarning.value ??= AppException.from(caught).message;
        }
      }
    }
    if (locationSharingEnabled.value) {
      if (!caps.fineLocationGranted || !caps.notificationsGranted) {
        locationWarning.value =
            'Location sharing is on in this app, but Android location or '
            'notification permission is missing. The location service is not '
            'running.';
      } else {
        try {
          final started = await _deviceAdmin.startLocationTracking(
            intervalSeconds: 60,
          );
          if (!started) {
            locationWarning.value =
                'Android did not start the visible location service.';
          }
        } catch (caught) {
          locationWarning.value = AppException.from(caught).message;
        }
      }
    } else {
      try {
        await _deviceAdmin.stopLocationTracking();
      } catch (_) {
        // Stopping is best effort when sharing is already off.
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    AppException? pairingFailure;
    AppException? sessionFailure;
    try {
      final requests = await _pairingRepository.fetchPendingForChild();
      pendingPairings.assignAll(requests.where((request) => request.isPending));
    } catch (caught) {
      pairingFailure = AppException.from(caught);
    }
    try {
      final sessions =
          await _remoteSessionRepository.fetchPendingForChild();
      pendingSessions.assignAll(
        sessions.where(
          (session) =>
              session.status == RemoteSessionStatus.requested &&
              !session.isExpired,
        ),
      );
    } catch (caught) {
      sessionFailure = AppException.from(caught);
    }
    if (pairingFailure != null && sessionFailure != null) {
      pendingError.value = pairingFailure;
    } else if (pairingFailure != null || sessionFailure != null) {
      pendingError.value = pairingFailure ?? sessionFailure;
    } else {
      pendingError.value = null;
    }
  }

  Future<void> _loadLocationPreference() async {
    try {
      locationSharingEnabled.value =
          await _preferences.locationSharingEnabled();
    } catch (_) {
      locationSharingEnabled.value = false;
      locationWarning.value =
          'The local location-sharing preference could not be read, so it is '
          'treated as off.';
    }
  }

  void _listenToNativeEvents() {
    if (!_deviceAdmin.isAvailable) return;
    _eventSubscription = _deviceAdmin.events.listen((event) {
      final type = event['type'];
      if (type == 'service_status') {
        final previous = guardian.value;
        guardian.value = GuardianServiceStatus(
          running: event['running'] == true,
          lastError: event['lastError']?.toString(),
          lastPollAt: previous?.lastPollAt,
          queuedCommands: previous?.queuedCommands ?? 0,
        );
      } else if (type == 'command') {
        final commandType = event['commandType']?.toString();
        final status = event['status']?.toString();
        if (status == 'succeeded' &&
            (commandType == 'apply_policy' || commandType == 'sync_policy')) {
          unawaited(refreshPolicy());
        }
      }
    });
  }

  Future<void> refreshPolicy() async {
    final current = device.value;
    if (current == null) return;
    await _loadPolicy(current);
  }

  void clearNotices() {
    actionError.value = null;
    actionMessage.value = null;
  }

  Future<void> refreshCapabilities() async {
    capabilities.value = await _readCapabilities();
    guardian.value = await _readGuardianStatus();
  }

  Future<void> requestPermissions({
    bool camera = false,
    bool microphone = false,
    bool location = false,
    bool backgroundLocation = false,
    bool notifications = false,
  }) async {
    actionError.value = null;
    actionMessage.value = null;
    if (!_deviceAdmin.isAvailable) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Android permissions can only be requested from the Android app.',
      );
      return;
    }
    try {
      await _deviceAdmin.requestPermissions(
        camera: camera,
        microphone: microphone,
        location: location,
        backgroundLocation: backgroundLocation,
        notifications: notifications,
      );
      await refreshCapabilities();
    } catch (caught) {
      actionError.value = AppException.from(caught);
    }
  }

  Future<void> openUsageAccessSettings() async {
    actionError.value = null;
    actionMessage.value = null;
    try {
      final opened = await _deviceAdmin.openUsageAccessSettings();
      if (!opened) {
        actionError.value = const AppException(
          AppErrorCodes.unsupported,
          'Android did not open the Usage Access screen on this phone.',
        );
      }
    } catch (caught) {
      actionError.value = AppException.from(caught);
    }
  }

  Future<void> openBackgroundLocationSettings() async {
    actionError.value = null;
    actionMessage.value = null;
    try {
      final opened = await _deviceAdmin.openBackgroundLocationSettings();
      if (!opened) {
        actionError.value = const AppException(
          AppErrorCodes.unsupported,
          'Android did not open the background location screen on this phone.',
        );
      }
    } catch (caught) {
      actionError.value = AppException.from(caught);
    }
  }

  Future<void> requestDeviceAdmin() async {
    actionError.value = null;
    actionMessage.value = null;
    try {
      await _deviceAdmin.requestDeviceAdmin();
      await refreshCapabilities();
    } catch (caught) {
      actionError.value = AppException.from(caught);
    }
  }

  Future<void> retryBackgroundSync() async {
    if (isStartingGuardian.value) return;
    actionError.value = null;
    actionMessage.value = null;
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return;
    }
    final currentDevice = device.value;
    final currentFamily = family.value;
    if (currentDevice == null || currentFamily == null) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Link this phone before starting background protection.',
      );
      return;
    }
    if (!_deviceAdmin.isAvailable) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Background protection is available only in the Android app.',
      );
      return;
    }
    isStartingGuardian.value = true;
    try {
      var caps = await _readCapabilities();
      if (!caps.notificationsGranted) {
        await _deviceAdmin.requestPermissions(notifications: true);
        caps = await _readCapabilities();
      }
      capabilities.value = caps;
      if (!caps.notificationsGranted) {
        actionError.value = const AppException(
          'permission_denied',
          'Android needs notification permission for the visible background '
          'service. Allow notifications, then try again.',
        );
        return;
      }
      if (!_syncConfigured) {
        await _ensureIdentityAndSync(currentDevice, currentFamily);
      }
      if (!_syncConfigured) {
        actionError.value = AppException(
          AppErrorCodes.nativeError,
          syncWarning.value ??
              'The background sync configuration is incomplete on this phone.',
        );
        return;
      }
      final started = await _deviceAdmin.startGuardianService();
      guardian.value = await _readGuardianStatus();
      if (!started) {
        actionError.value = const AppException(
          AppErrorCodes.nativeError,
          'Android did not start the guardian service. Check battery '
          'restrictions and notifications for this app.',
        );
        return;
      }
      actionMessage.value =
          'Background protection started. Android shows a persistent '
          'notification while it runs.';
    } catch (caught) {
      actionError.value = AppException.from(caught);
    } finally {
      isStartingGuardian.value = false;
    }
  }

  Future<void> setLocationSharing(bool enabled) async {
    if (isUpdatingLocation.value) return;
    actionError.value = null;
    actionMessage.value = null;
    if (locationSharingEnabled.value == enabled) return;
    if (!enabled) {
      await _disableLocationSharing();
      return;
    }
    if (!_deviceAdmin.isAvailable) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Location sharing is available only in the Android app.',
      );
      return;
    }
    if (device.value == null) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Link this phone before turning on location sharing.',
      );
      return;
    }
    isUpdatingLocation.value = true;
    try {
      await _deviceAdmin.requestPermissions(
        location: true,
        notifications: true,
      );
      final caps = await _readCapabilities();
      capabilities.value = caps;
      if (!caps.fineLocationGranted) {
        actionError.value = const AppException(
          'permission_denied',
          'Precise location permission is required. Nothing is being shared. '
          'Grant location access, then try again.',
        );
        return;
      }
      if (!caps.notificationsGranted) {
        actionError.value = const AppException(
          'permission_denied',
          'Android requires a visible notification for the location service. '
          'Allow notifications, then try again.',
        );
        return;
      }
      await _preferences.setLocationSharingEnabled(true);
      locationSharingEnabled.value = true;
      final started = await _deviceAdmin.startLocationTracking(
        intervalSeconds: 60,
      );
      if (!started) {
        await _preferences.setLocationSharingEnabled(false);
        locationSharingEnabled.value = false;
        actionError.value = const AppException(
          AppErrorCodes.nativeError,
          'Android did not start the location service, so location sharing is '
          'still off.',
        );
        return;
      }
      locationWarning.value = caps.backgroundLocationGranted
          ? null
          : 'Allow background location in Android settings if you want updates '
              'while this app is not on screen. The visible location '
              'notification stays on whenever sharing is active.';
      actionMessage.value =
          'Location sharing is on. A visible notification appears while the '
          'location service runs. You can turn it off here at any time.';
    } catch (caught) {
      actionError.value = AppException.from(caught);
    } finally {
      isUpdatingLocation.value = false;
    }
  }

  Future<void> _disableLocationSharing() async {
    isUpdatingLocation.value = true;
    try {
      if (_deviceAdmin.isAvailable) {
        final stopped = await _deviceAdmin.stopLocationTracking();
        if (!stopped) {
          actionError.value = const AppException(
            AppErrorCodes.nativeError,
            'Android did not confirm that the location service stopped, so the '
            'switch remains on.',
          );
          return;
        }
      }
      await _preferences.setLocationSharingEnabled(false);
      locationSharingEnabled.value = false;
      locationWarning.value = null;
      actionMessage.value = 'Location sharing is off.';
    } catch (caught) {
      actionError.value = AppException.from(caught);
    } finally {
      isUpdatingLocation.value = false;
    }
  }

  Future<bool> unlink() async {
    final currentFamily = family.value;
    final userId = _session.userId.value;
    if (currentFamily == null || userId.isEmpty) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'There is no linked family to remove from this account.',
      );
      return false;
    }
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return false;
    }
    if (isUnlinking.value) return false;
    isUnlinking.value = true;
    actionError.value = null;
    actionMessage.value = null;
    try {
      // Stop capture and end any live assistance session before the server
      // link is removed, so the microphone cannot outlive the enrolment and
      // the guardian does not keep seeing a live session with no peer.
      await _stopMicrophoneService();
      await _endOpenAssistanceSessions(reason: 'unlinked');
      await _pairingRepository.unlink(
        familyId: currentFamily.id,
        childUserId: userId,
      );
      await _stopNativeServices(
        clearPreference: true,
        stopMicrophone: false,
      );
      try {
        await _deviceAdmin.clearBackgroundSync();
      } catch (_) {
        // The visible services are already stopped; this also restores tracked
        // suspensions when Android accepts the request.
      }
      _syncConfigured = false;
      try {
        await _preferences.clear();
      } catch (_) {
        // Preference cleanup is not security-relevant; services are stopped.
      }
      await _clearLinkedState(stopServices: false);
      locationSharingEnabled.value = false;
      policyError.value = null;
      guardian.value = await _readGuardianStatus();
      await _loadPendingRequests();
      lastLoadedAt.value = DateTime.now();
      actionMessage.value =
          'This phone is no longer linked. Background protection and location '
          'sharing were stopped on this device.';
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isUnlinking.value = false;
    }
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;
    isSigningOut.value = true;
    actionError.value = null;
    // Stop the microphone service and end any open assistance session while
    // the credentials are still valid: after sign-out the session end call
    // would be rejected and the guardian would keep seeing a live session.
    await _stopMicrophoneService();
    await _endOpenAssistanceSessions(reason: 'signed_out');
    try {
      await _authRepository.signOut();
    } catch (caught) {
      actionError.value = AppException.from(caught);
      isSigningOut.value = false;
      return;
    }
    String? warning;
    try {
      await _stopNativeServices(
        clearPreference: true,
        stopMicrophone: false,
      );
      if (_deviceAdmin.isAvailable) {
        await _deviceAdmin.clearBackgroundSync();
      }
    } catch (_) {
      warning =
          'Some background services could not be stopped on this phone.';
    }
    _syncConfigured = false;
    try {
      await _preferences.clear();
    } catch (_) {
      warning ??= 'The local location preference could not be cleared.';
    }
    _session.clear();
    try {
      await _localSettings.clearOnSignOut();
    } catch (_) {
      warning ??= 'Some local preferences could not be cleared.';
    }
    isSigningOut.value = false;
    Get.offAllNamed(AppRoutes.roleSelection);
    if (warning != null) {
      Get.snackbar('Signed out', warning);
    }
  }

  @override
  void onClose() {
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    super.onClose();
  }
}
