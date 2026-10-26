import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class ScreenTimeController extends GetxController {
  ScreenTimeController({
    required this.deviceId,
    required this._usageRepository,
    required this._deviceRepository,
    required this._policyRepository,
    required this._connectivity,
  });

  static const _uuid = Uuid();

  final String deviceId;
  final UsageRepository _usageRepository;
  final DeviceRepository _deviceRepository;
  final PolicyRepository _policyRepository;
  final ConnectivityService _connectivity;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final RxBool policyReady = false.obs;
  final Rxn<AppException> usageError = Rxn<AppException>();
  final Rxn<Device> device = Rxn<Device>();
  final Rxn<DevicePolicy> latestPolicy = Rxn<DevicePolicy>();
  final Rxn<DevicePolicy> savedPolicy = Rxn<DevicePolicy>();
  final RxList<UsageDaily> entries = <UsageDaily>[].obs;
  final Rxn<DateTime> lastUpload = Rxn<DateTime>();
  final RxInt rangeDays = 7.obs;
  final Rxn<int> dailyLimitMinutes = Rxn<int>();
  final Rxn<int> bedtimeStartMinutes = Rxn<int>();
  final Rxn<int> bedtimeEndMinutes = Rxn<int>();
  final RxBool saving = false.obs;
  final Rxn<AppException> saveError = Rxn<AppException>();
  final RxString validationMessage = ''.obs;
  final RxString statusMessage = ''.obs;
  final RxBool isOffline = false.obs;

  Timer? _ackTimer;
  bool _polling = false;
  int _pollAttempts = 0;

  bool get usageAccessDenied => device.value?.usageAccessGranted == false;
  bool get usageAccessUnknown => device.value?.usageAccessGranted == null;
  bool get hasUsageData => entries.isNotEmpty;
  DevicePolicy? get currentPolicy => savedPolicy.value ?? latestPolicy.value;
  PolicyEnforcementStatus? get currentStatus => currentPolicy?.status;
  int? get currentVersion => currentPolicy?.version;
  bool get awaitingAcknowledgement =>
      currentStatus == PolicyEnforcementStatus.pending;
  bool get hasLimit => dailyLimitMinutes.value != null;
  bool get hasBedtime =>
      bedtimeStartMinutes.value != null && bedtimeEndMinutes.value != null;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get rangeStart => _today.subtract(
        Duration(days: rangeDays.value.clamp(1, 7).toInt() - 1),
      );

  List<UsageDaily> get rangeEntries => entries
      .where((entry) {
        final day = DateTime(entry.day.year, entry.day.month, entry.day.day);
        return !day.isBefore(rangeStart) && !day.isAfter(_today);
      })
      .toList(growable: false);

  int get todayTotalMs => entries
      .where((entry) {
        final day = DateTime(entry.day.year, entry.day.month, entry.day.day);
        return day == _today;
      })
      .fold(0, (total, entry) => total + entry.totalMs);

  int get weekTotalMs => entries
      .where((entry) {
        final day = DateTime(entry.day.year, entry.day.month, entry.day.day);
        final start = _today.subtract(const Duration(days: 6));
        return !day.isBefore(start) && !day.isAfter(_today);
      })
      .fold(0, (total, entry) => total + entry.totalMs);

  int get rangeTotalMs =>
      rangeEntries.fold(0, (total, entry) => total + entry.totalMs);

  List<UsageStat> get appBreakdown {
    final totals = <String, int>{};
    final labels = <String, String>{};
    final lastUsed = <String, DateTime>{};
    for (final entry in rangeEntries) {
      totals.update(
        entry.packageName,
        (value) => value + entry.totalMs,
        ifAbsent: () => entry.totalMs,
      );
      labels[entry.packageName] = entry.appLabel;
      final used = entry.lastUsedAt;
      if (used != null) {
        final existing = lastUsed[entry.packageName];
        if (existing == null || used.isAfter(existing)) {
          lastUsed[entry.packageName] = used;
        }
      }
    }
    final stats = totals.entries
        .map(
          (entry) => UsageStat(
            packageName: entry.key,
            label: labels[entry.key] ?? entry.key,
            totalMs: entry.value,
            lastUsedAt: lastUsed[entry.key],
          ),
        )
        .toList()
      ..sort((a, b) => b.totalMs.compareTo(a.totalMs));
    return stats;
  }

  int get maxAppTotalMs => appBreakdown.isEmpty ? 0 : appBreakdown.first.totalMs;

  DateTime? get effectiveLastUpload {
    var stamp = lastUpload.value;
    for (final entry in entries) {
      final uploaded = entry.uploadedAt;
      if (uploaded == null) continue;
      if (stamp == null || uploaded.isAfter(stamp)) stamp = uploaded;
    }
    return stamp;
  }

  bool get isUploadStale {
    final stamp = effectiveLastUpload;
    if (stamp == null) return false;
    return DateTime.now().difference(stamp) > const Duration(hours: 24);
  }

  String get lastUploadText {
    final stamp = effectiveLastUpload;
    if (stamp == null) return 'No usage upload has been reported yet.';
    return '${formatDateTime(stamp)} · ${relativeTime(stamp)}';
  }

  String get usagePermissionText {
    if (usageAccessDenied) {
      return 'Usage Access has not been granted on the child device. Open Android Settings > '
          'Special app access > Usage access on the child phone, allow Parent Control, then '
          'request a device sync. No usage numbers are shown until then.';
    }
    if (usageAccessUnknown) {
      return 'The device has not reported its Usage Access status yet. Stored usage may be incomplete.';
    }
    return 'Usage Access is granted on the child device.';
  }

  String get policyStateText => describePolicy(currentPolicy);

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  @override
  void onClose() {
    _ackTimer?.cancel();
    super.onClose();
  }

  Future<void> load() => _load(showLoading: true);

  @override
  Future<void> refresh() => _load(showLoading: false);

  Future<void> _load({required bool showLoading}) async {
    if (isLoading.value) return;
    if (deviceId.trim().isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No device was selected. Open this screen from the device list.',
      );
      return;
    }
    isOffline.value = !_connectivity.isOnline.value;
    if (!_connectivity.isOnline.value && device.value == null) {
      error.value = AppException.network();
      return;
    }

    isLoading.value = true;
    error.value = null;
    usageError.value = null;
    policyReady.value = false;
    try {
      device.value = await _deviceRepository.fetchDevice(deviceId);
      latestPolicy.value = await _policyRepository.fetchLatestPolicy(deviceId);
      savedPolicy.value = null;
      policyReady.value = true;
      _applyPolicyToDraft(
        latestPolicy.value?.payload ?? const PolicyPayload(),
      );
    } on AppException catch (exception) {
      error.value = exception;
      isLoading.value = false;
      return;
    } catch (exception) {
      error.value = AppException.from(exception);
      isLoading.value = false;
      return;
    }

    if (usageAccessDenied) {
      entries.clear();
      lastUpload.value = null;
    } else {
      await _loadUsage();
    }
    isLoading.value = false;
    isOffline.value = !_connectivity.isOnline.value;
  }

  Future<void> _loadUsage() async {
    final from = _today.subtract(const Duration(days: 6));
    try {
      final loaded = await _usageRepository.fetchUsage(
        deviceId: deviceId,
        from: from,
        to: _today,
      );
      entries.assignAll(loaded);
      usageError.value = null;
    } on AppException catch (exception) {
      usageError.value = exception;
    } catch (exception) {
      usageError.value = AppException.from(exception);
    }
    try {
      lastUpload.value = await _usageRepository.fetchLastUpload(deviceId);
    } on AppException catch (exception) {
      usageError.value ??= exception;
    } catch (exception) {
      usageError.value ??= AppException.from(exception);
    }
  }

  void _applyPolicyToDraft(PolicyPayload payload) {
    dailyLimitMinutes.value = payload.dailyScreenTimeLimitMinutes;
    bedtimeStartMinutes.value = payload.bedtimeStartMinutes;
    bedtimeEndMinutes.value = payload.bedtimeEndMinutes;
  }

  void setRangeDays(int days) {
    if (days != 1 && days != 7) return;
    rangeDays.value = days;
  }

  void setDailyLimit(int? minutes) {
    if (minutes == null) {
      dailyLimitMinutes.value = null;
      return;
    }
    dailyLimitMinutes.value = minutes.clamp(0, 1440).toInt();
  }

  void adjustDailyLimit(int deltaMinutes) {
    final current = dailyLimitMinutes.value;
    if (current == null) {
      setDailyLimit(60);
      return;
    }
    setDailyLimit(current + deltaMinutes);
    validationMessage.value = '';
  }

  void setBedtimeStart(int minutes) {
    bedtimeStartMinutes.value = minutes.clamp(0, 1439).toInt();
    validationMessage.value = '';
  }

  void setBedtimeEnd(int minutes) {
    bedtimeEndMinutes.value = minutes.clamp(0, 1439).toInt();
    validationMessage.value = '';
  }

  void clearBedtime() {
    bedtimeStartMinutes.value = null;
    bedtimeEndMinutes.value = null;
    validationMessage.value = '';
  }

  void clearDailyLimit() {
    dailyLimitMinutes.value = null;
    validationMessage.value = '';
  }

  PolicyPayload get draftPayload {
    final base =
        (savedPolicy.value ?? latestPolicy.value)?.payload ?? const PolicyPayload();
    final limit = dailyLimitMinutes.value;
    final start = bedtimeStartMinutes.value;
    final end = bedtimeEndMinutes.value;
    return base.copyWith(
      dailyScreenTimeLimitMinutes: limit,
      clearDailyLimit: limit == null,
      bedtimeStartMinutes: start,
      bedtimeEndMinutes: end,
      clearBedtime: start == null || end == null,
    );
  }

  Future<bool> savePolicy() async {
    if (saving.value) return false;
    if (!policyReady.value) {
      saveError.value = const AppException(
        AppErrorCodes.unknown,
        'The current policy could not be loaded. Refresh before saving so existing restrictions are preserved.',
      );
      return false;
    }
    final start = bedtimeStartMinutes.value;
    final end = bedtimeEndMinutes.value;
    if (start != null && end != null && start == end) {
      validationMessage.value =
          'Bedtime start and end must differ. An end earlier than the start spans midnight.';
      return false;
    }
    validationMessage.value = '';
    saving.value = true;
    saveError.value = null;
    try {
      final result = await _policyRepository.updatePolicy(
        deviceId: deviceId,
        payload: draftPayload,
        idempotencyKey: _uuid.v4(),
      );
      latestPolicy.value = result.policy;
      savedPolicy.value = result.policy;
      statusMessage.value = describePolicy(result.policy);
      _startAckPolling();
      return true;
    } on AppException catch (exception) {
      saveError.value = exception;
      return false;
    } catch (exception) {
      saveError.value = AppException.from(exception);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<void> refreshPolicy() async {
    try {
      final policy = await _policyRepository.fetchLatestPolicy(deviceId);
      if (policy == null) return;
      latestPolicy.value = policy;
      savedPolicy.value = policy;
      _applyPolicyToDraft(policy.payload);
      if (policy.status != PolicyEnforcementStatus.pending) {
        _ackTimer?.cancel();
      }
    } on AppException catch (exception) {
      saveError.value = exception;
    } catch (exception) {
      saveError.value = AppException.from(exception);
    }
  }

  void _startAckPolling() {
    _ackTimer?.cancel();
    _pollAttempts = 0;
    _ackTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_polling) return;
      _pollAttempts += 1;
      if (_pollAttempts > 6) {
        timer.cancel();
        return;
      }
      _polling = true;
      try {
        final policy = await _policyRepository.fetchLatestPolicy(deviceId);
        if (policy != null) {
          latestPolicy.value = policy;
          savedPolicy.value = policy;
          if (policy.status != PolicyEnforcementStatus.pending) {
            statusMessage.value = describePolicy(policy);
            timer.cancel();
          }
        }
      } catch (_) {
        // Keep the last known state; manual refresh remains available.
      } finally {
        _polling = false;
      }
    });
  }

  String describePolicy(DevicePolicy? policy) {
    if (policy == null) {
      return 'No policy has been saved for this device yet.';
    }
    switch (policy.status) {
      case PolicyEnforcementStatus.pending:
        return 'Policy v${policy.version} saved. Pending device acknowledgement — the limit and '
            'bedtime are not active on the child device yet.';
      case PolicyEnforcementStatus.enforced:
        return 'Policy v${policy.version} acknowledged by the device. Enforcement depends on the '
            'guardian service running on the child phone.';
      case PolicyEnforcementStatus.failed:
        final error = policy.lastError == null ? '' : ': ${policy.lastError}';
        return 'Policy v${policy.version} failed on the device$error.';
      case PolicyEnforcementStatus.unsupported:
        return 'Policy v${policy.version} is unsupported on this device.';
    }
  }
}
