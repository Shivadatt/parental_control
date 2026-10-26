import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class DevicesController extends GetxController {
  DevicesController({
    required this._deviceRepository,
    required this._familyRepository,
    required this._session,
    required this._connectivity,
  });

  final DeviceRepository _deviceRepository;
  final FamilyRepository _familyRepository;
  final SessionService _session;
  final ConnectivityService _connectivity;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<Family> family = Rxn<Family>();
  final RxList<Device> devices = <Device>[].obs;
  final RxBool isOffline = false.obs;
  final Rxn<DateTime> lastRefreshedAt = Rxn<DateTime>();

  bool get hasFamily => family.value != null;
  bool get isEmpty => devices.isEmpty;
  String? get familyId => family.value?.id;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() => _fetch(showLoading: true);

  @override
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (isLoading.value) return;
    isOffline.value = !_connectivity.isOnline.value;
    if (!_connectivity.isOnline.value) {
      if (family.value == null && devices.isEmpty) {
        error.value = AppException.network();
      }
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    error.value = null;
    try {
      var activeFamily = _session.activeFamily.value;
      if (activeFamily == null) {
        final families = await _familyRepository.fetchMyFamilies();
        activeFamily = families.isEmpty ? null : families.first;
        if (activeFamily != null) _session.setActiveFamily(activeFamily);
      }
      family.value = activeFamily;
      if (activeFamily == null) {
        devices.clear();
        return;
      }
      final loaded = await _deviceRepository.fetchDevices(activeFamily.id);
      devices.assignAll(loaded);
      lastRefreshedAt.value = DateTime.now();
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isLoading.value = false;
      isOffline.value = !_connectivity.isOnline.value;
    }
  }

  String enforcementLabelFor(Device device) =>
      enforcementModeLabel(device.enforcementMode);

  List<String> permissionGapsForDevice(Device device) =>
      permissionGapsFor(device);

  String policySummaryFor(Device device) {
    final version = device.policyVersion;
    if (version == null || version <= 0) return 'No policy applied yet';
    return 'Policy v$version';
  }
}
