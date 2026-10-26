import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class DeviceDetailController extends GetxController {
  DeviceDetailController({
    required this.deviceId,
    required this._deviceRepository,
    required this._policyRepository,
    required this._connectivity,
  });

  final String deviceId;
  final DeviceRepository _deviceRepository;
  final PolicyRepository _policyRepository;
  final ConnectivityService _connectivity;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<Device> device = Rxn<Device>();
  final Rxn<DevicePolicy> latestPolicy = Rxn<DevicePolicy>();
  final RxList<DeviceCommand> recentCommands = <DeviceCommand>[].obs;
  final Rxn<AppException> policyError = Rxn<AppException>();
  final Rxn<AppException> commandsError = Rxn<AppException>();
  final RxBool isRevoking = false.obs;
  final Rxn<AppException> revokeError = Rxn<AppException>();
  final RxBool isOffline = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  bool get suspensionUnsupported =>
      device.value != null && appSuspensionUnsupported(device.value!);

  bool get awaitingAcknowledgement =>
      latestPolicy.value?.status == PolicyEnforcementStatus.pending;

  bool get isDeviceOffline => device.value != null && !device.value!.isOnline;

  String get enforcementLabel =>
      enforcementModeLabel(device.value?.enforcementMode);

  String get policySummaryText => policySummary(
        devicePolicyVersion: device.value?.policyVersion,
        policy: latestPolicy.value,
      );

  Future<void> load() async {
    if (isLoading.value) return;
    if (deviceId.trim().isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No device was selected. Open this screen from the device list.',
      );
      return;
    }
    isOffline.value = !_connectivity.isOnline.value;
    if (!_connectivity.isOnline.value) {
      if (device.value == null) error.value = AppException.network();
      return;
    }

    isLoading.value = true;
    error.value = null;
    policyError.value = null;
    commandsError.value = null;
    revokeError.value = null;
    try {
      device.value = await _deviceRepository.fetchDevice(deviceId);
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isLoading.value = false;
      isOffline.value = !_connectivity.isOnline.value;
    }
    if (device.value == null) return;
    await _loadPolicyAndCommands();
  }

  @override
  Future<void> refresh() => load();

  Future<void> _loadPolicyAndCommands() async {
    try {
      latestPolicy.value = await _policyRepository.fetchLatestPolicy(deviceId);
      policyError.value = null;
    } on AppException catch (exception) {
      policyError.value = exception;
    } catch (exception) {
      policyError.value = AppException.from(exception);
    }
    try {
      final commands =
          await _policyRepository.fetchRecentCommands(deviceId, limit: 10);
      recentCommands.assignAll(commands);
      commandsError.value = null;
    } on AppException catch (exception) {
      commandsError.value = exception;
    } catch (exception) {
      commandsError.value = AppException.from(exception);
    }
  }

  Future<void> refreshPolicy() async {
    try {
      latestPolicy.value = await _policyRepository.fetchLatestPolicy(deviceId);
      policyError.value = null;
    } on AppException catch (exception) {
      policyError.value = exception;
    } catch (exception) {
      policyError.value = AppException.from(exception);
    }
  }

  /// Revokes only after the server confirms; a local flag is never treated as
  /// proof that the device is revoked.
  Future<bool> revokeDevice() async {
    if (isRevoking.value) return false;
    isRevoking.value = true;
    revokeError.value = null;
    try {
      await _deviceRepository.revokeDevice(deviceId);
      return true;
    } on AppException catch (exception) {
      revokeError.value = exception;
      return false;
    } catch (exception) {
      revokeError.value = AppException.from(exception);
      return false;
    } finally {
      isRevoking.value = false;
    }
  }
}
