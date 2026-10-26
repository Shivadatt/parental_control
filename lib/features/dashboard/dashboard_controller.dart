import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/devices/device_presentation.dart';

class DashboardController extends GetxController {
  DashboardController({
    required this._deviceRepository,
    required this._familyRepository,
    required this._policyRepository,
    required this._session,
    required this._connectivity,
    this.refreshInterval = const Duration(seconds: 60),
  });

  final DeviceRepository _deviceRepository;
  final FamilyRepository _familyRepository;
  final PolicyRepository _policyRepository;
  final SessionService _session;
  final ConnectivityService _connectivity;

  /// `null` disables the periodic refresh (used by controller tests).
  final Duration? refreshInterval;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<Family> family = Rxn<Family>();
  final RxList<FamilyMember> children = <FamilyMember>[].obs;
  final RxList<Device> devices = <Device>[].obs;
  final RxMap<String, DevicePolicy> policies = <String, DevicePolicy>{}.obs;
  final RxBool isOffline = false.obs;
  final Rxn<DateTime> lastRefreshedAt = Rxn<DateTime>();

  Timer? _refreshTimer;
  Worker? _connectivityWorker;

  bool get hasFamily => family.value != null;
  bool get hasLinkedChildren => children.isNotEmpty;
  bool get hasDevices => devices.isNotEmpty;
  bool get isEmpty => family.value == null || (devices.isEmpty && children.isEmpty);
  String get familyName => family.value?.name ?? 'No family yet';
  String? get familyId => family.value?.id;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    _connectivityWorker = ever<bool>(_connectivity.isOnline, (online) {
      isOffline.value = !online;
      if (online) unawaited(refresh());
    });
    final interval = refreshInterval;
    if (interval != null) {
      _refreshTimer = Timer.periodic(interval, (_) {
        if (_connectivity.isOnline.value) unawaited(refresh());
      });
    }
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _connectivityWorker?.dispose();
    super.onClose();
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
        children.clear();
        devices.clear();
        policies.clear();
        lastRefreshedAt.value = DateTime.now();
        return;
      }

      final members = await _familyRepository.fetchMembers(activeFamily.id);
      children.assignAll(
        members.where((member) => member.isActive && member.isChild),
      );

      final loadedDevices = await _deviceRepository.fetchDevices(activeFamily.id);
      devices.assignAll(loadedDevices);

      final resolvedPolicies = <String, DevicePolicy>{};
      for (final device in loadedDevices) {
        try {
          final policy = await _policyRepository.fetchLatestPolicy(device.id);
          if (policy != null) resolvedPolicies[device.id] = policy;
        } on AppException {
          // The card falls back to "status not available"; no value is invented.
        }
      }
      policies.assignAll(resolvedPolicies);
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

  String displayNameFor(Device device) {
    for (final child in children) {
      if (child.userId == device.childUserId) return child.displayName;
    }
    return device.displayName;
  }

  List<Device> get devicesWithoutChildren => devices
      .where((device) => !children.any((child) => child.userId == device.childUserId))
      .toList(growable: false);

  List<FamilyMember> get childrenWithoutDevice => children
      .where((child) => !devices.any((device) => device.childUserId == child.userId))
      .toList(growable: false);

  String policySummaryFor(Device device) => policySummary(
        devicePolicyVersion: device.policyVersion,
        policy: policies[device.id],
      );

  String enforcementLabelFor(Device device) =>
      enforcementModeLabel(device.enforcementMode);
}
