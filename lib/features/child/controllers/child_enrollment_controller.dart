import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';

/// Links this child account to a family and registers this Android phone.
///
/// The linking code is created on this device and approved here; no family can
/// attach the account without that approval. Device registration only happens
/// after the server confirms the child membership.
class ChildEnrollmentController extends GetxController {
  ChildEnrollmentController({
    required FamilyRepository familyRepository,
    required PairingRepository pairingRepository,
    required DeviceRepository deviceRepository,
    required this._session,
    required this._settings,
    required this._connectivity,
    required this._deviceAdmin,
  })  : _families = familyRepository,
        _pairing = pairingRepository,
        _devices = deviceRepository;

  final FamilyRepository _families;
  final PairingRepository _pairing;
  final DeviceRepository _devices;
  final SessionService _session;
  final LocalSettingsService _settings;
  final ConnectivityService _connectivity;
  final DeviceAdminService _deviceAdmin;

  static const Duration pollInterval = Duration(seconds: 15);

  final RxBool isLoading = true.obs;
  final RxBool isCreatingCode = false.obs;
  final RxBool isCheckingRequests = false.obs;
  final RxBool isResponding = false.obs;
  final RxBool isRegistering = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final RxnString actionMessage = RxnString();
  final Rxn<PairingCode> linkingCode = Rxn<PairingCode>();
  final RxList<PairingRequest> pendingRequests = <PairingRequest>[].obs;
  final Rxn<Family> family = Rxn<Family>();
  final Rxn<Device> device = Rxn<Device>();
  final Rxn<DeviceCapabilities> capabilities = Rxn<DeviceCapabilities>();
  final RxString displayName = 'This Android phone'.obs;
  final Rxn<DateTime> lastCheckedAt = Rxn<DateTime>();

  Timer? _pollTimer;

  bool get isOnline => _connectivity.isOnline.value;
  bool get isLinked => family.value != null;
  bool get hasDevice => device.value != null;
  bool get isReady => isLinked && hasDevice;
  bool get needsDeviceRegistration => isLinked && !hasDevice;
  bool get isNativeAvailable => _deviceAdmin.isAvailable;

  @override
  void onInit() {
    super.onInit();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_connectivity.isOnline.value && !isLoading.value) {
        unawaited(checkRequests(silent: true));
      }
    });
    unawaited(load());
  }

  Future<void> load({bool showLoading = true}) async {
    if (!showLoading && isLoading.value) return;
    if (showLoading) isLoading.value = true;
    error.value = null;
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      isLoading.value = false;
      return;
    }
    try {
      final membership = await _families.fetchMyMembership();
      if (membership != null &&
          membership.isActive &&
          membership.role == FamilyMemberRole.child) {
        final loadedFamily = await _families.fetchFamily(membership.familyId);
        family.value = loadedFamily;
        if (loadedFamily != null) {
          _session.setActiveFamily(loadedFamily);
          await _settings.setActiveFamilyId(loadedFamily.id);
        }
      } else {
        family.value = null;
      }
      final loadedDevice = await _devices.fetchMyDevice();
      device.value = loadedDevice;
      _session.setActiveDevice(loadedDevice);
      capabilities.value = await _readCapabilities();
      final suggested = loadedDevice?.displayName.trim() ?? '';
      if (suggested.isNotEmpty) {
        displayName.value = suggested;
      } else {
        final label = capabilities.value?.deviceLabel ?? '';
        if (label.trim().isNotEmpty) displayName.value = label.trim();
      }
      await _loadPending();
      lastCheckedAt.value = DateTime.now();
    } catch (caught) {
      error.value = AppException.from(caught);
    } finally {
      isLoading.value = false;
    }
  }

  Future<DeviceCapabilities> _readCapabilities() async {
    try {
      return await _deviceAdmin.getCapabilities();
    } catch (_) {
      return DeviceCapabilities.empty();
    }
  }

  Future<void> _loadPending() async {
    pendingRequests.assignAll(await _pairing.fetchPendingForChild());
  }

  Future<void> createCode() async {
    if (isCreatingCode.value) return;
    actionError.value = null;
    actionMessage.value = null;
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return;
    }
    isCreatingCode.value = true;
    try {
      linkingCode.value = await _pairing.createLinkingCode();
      await checkRequests(silent: true);
    } catch (caught) {
      actionError.value = AppException.from(caught);
    } finally {
      isCreatingCode.value = false;
    }
  }

  Future<void> checkRequests({bool silent = false}) async {
    if (isCheckingRequests.value) return;
    if (!_connectivity.isOnline.value) {
      if (!silent) actionError.value = AppException.network();
      return;
    }
    if (!silent) {
      actionError.value = null;
      actionMessage.value = null;
    }
    isCheckingRequests.value = true;
    try {
      await _loadPending();
      lastCheckedAt.value = DateTime.now();
      if (!isLinked &&
          pendingRequests.isNotEmpty &&
          silent &&
          actionMessage.value == null) {
        actionMessage.value =
            'A guardian is waiting for approval. Review the request below.';
      }
    } catch (caught) {
      if (!silent) actionError.value = AppException.from(caught);
    } finally {
      isCheckingRequests.value = false;
    }
  }

  Future<bool> respondTo(PairingRequest request, {required bool approve}) async {
    if (isResponding.value) return false;
    actionError.value = null;
    actionMessage.value = null;
    if (!request.isPending) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'This request has already been answered or has expired.',
      );
      return false;
    }
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return false;
    }
    isResponding.value = true;
    try {
      await _pairing.respond(requestId: request.id, approve: approve);
      actionMessage.value = approve
          ? 'Family linked. Finish registering this phone below.'
          : 'Request declined. No family was linked.';
      if (approve) linkingCode.value = null;
      await load(showLoading: false);
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isResponding.value = false;
    }
  }

  Future<bool> registerDevice() async {
    if (isRegistering.value) return false;
    actionError.value = null;
    actionMessage.value = null;
    final currentFamily = family.value;
    if (currentFamily == null) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Link a family before registering this phone.',
      );
      return false;
    }
    if (device.value != null) {
      actionMessage.value = 'This phone is already registered.';
      return true;
    }
    final name = displayName.value.trim();
    if (name.isEmpty) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Enter a name for this phone.',
      );
      return false;
    }
    if (!_deviceAdmin.isAvailable) {
      actionError.value = const AppException(
        AppErrorCodes.unsupported,
        'Device registration is available only in the Android app.',
      );
      return false;
    }
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return false;
    }
    isRegistering.value = true;
    try {
      capabilities.value = await _readCapabilities();
      final identity = await _deviceAdmin.getIdentity();
      final registered = await _devices.registerDevice(
        familyId: currentFamily.id,
        identity: identity,
        displayName: name,
        androidVersion: capabilities.value?.androidVersion,
        appVersion: capabilities.value?.appVersion,
      );
      device.value = registered;
      _session.setActiveDevice(registered);
      _session.setDeviceIdentity(
        identity.copyWith(serverDeviceId: registered.id),
      );
      actionMessage.value =
          'This phone is registered. Open My phone to review rules, '
          'permissions and requests.';
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isRegistering.value = false;
    }
  }

  void clearNotices() {
    actionError.value = null;
    actionMessage.value = null;
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }
}
