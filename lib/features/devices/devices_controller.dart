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
    this.refreshInterval = const Duration(seconds: 60),
  });

  final DeviceRepository _deviceRepository;
  final FamilyRepository _familyRepository;
  final SessionService _session;
  final ConnectivityService _connectivity;

  /// `null` disables the periodic refresh (used by controller tests).
  final Duration? refreshInterval;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<Family> family = Rxn<Family>();
  final RxList<Device> devices = <Device>[].obs;
  final RxBool isOffline = false.obs;
  final Rxn<DateTime> lastRefreshedAt = Rxn<DateTime>();

  Timer? _refreshTimer;
  Worker? _connectivityWorker;
  bool _reloadRequested = false;
  bool _isClosed = false;

  // Monotonic id of the newest fetch that owns the shared UI state; a fetch
  // whose id is no longer the newest must not write error/loading/reload.
  int _generation = 0;

  // Family id the currently-running fetch belongs to, so a reload for the same
  // family coalesces while a request for a different family supersedes it.
  String? _runningFamilyId;

  bool get hasFamily => family.value != null;
  bool get isEmpty => devices.isEmpty;
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
    _isClosed = true;
    _refreshTimer?.cancel();
    _connectivityWorker?.dispose();
    super.onClose();
  }

  Future<void> load() => _fetch(showLoading: true);

  @override
  Future<void> refresh() => _fetch(showLoading: false);

  /// False once the controller is closed or the active family changed, so a
  /// response for an older family cannot overwrite newer state.
  bool _isStillCurrent(String? familyId) =>
      !_isClosed && _session.activeFamily.value?.id == familyId;

  /// True only for the newest fetch started: a superseded fetch must not touch
  /// the shared error / loading / reload state on its way out.
  bool _owns(int generation) => !_isClosed && _generation == generation;

  Future<void> _fetch({required bool showLoading}) async {
    if (_isClosed) return;
    final requestedFamilyId = _session.activeFamily.value?.id;
    if (isLoading.value && _runningFamilyId == requestedFamilyId) {
      _reloadRequested = true;
      return;
    }
    final generation = ++_generation;
    _runningFamilyId = requestedFamilyId;
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
        final resolved = families.isEmpty ? null : families.first;
        // Another path may have chosen a family while this fetch was in flight;
        // prefer what the session holds now instead of clobbering it with the
        // list this (possibly stale) request returned.
        activeFamily = _session.activeFamily.value ?? resolved;
        if (activeFamily != null && _session.activeFamily.value == null) {
          _session.setActiveFamily(activeFamily);
        }
      }
      if (!_isStillCurrent(activeFamily?.id)) return;
      family.value = activeFamily;
      if (activeFamily == null) {
        devices.clear();
        return;
      }
      final loaded = await _deviceRepository.fetchDevices(activeFamily.id);
      if (!_isStillCurrent(activeFamily.id)) return;
      devices.assignAll(loaded);
      lastRefreshedAt.value = DateTime.now();
    } on AppException catch (exception) {
      // Only the newest fetch may paint an error: a superseded request failing
      // after a newer one succeeded must leave the newer state intact.
      if (_owns(generation)) error.value = exception;
    } catch (exception) {
      if (_owns(generation)) error.value = AppException.from(exception);
    } finally {
      if (_owns(generation)) {
        isLoading.value = false;
        isOffline.value = !_connectivity.isOnline.value;
        final retry = _reloadRequested;
        _reloadRequested = false;
        if (retry) {
          await _fetch(showLoading: false);
        }
      }
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
