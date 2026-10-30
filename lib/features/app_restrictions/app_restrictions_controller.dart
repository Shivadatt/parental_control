import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class AppRestrictionsController extends GetxController {
  AppRestrictionsController({
    required this.deviceId,
    required this._deviceRepository,
    required this._policyRepository,
    required this._connectivity,
  });

  static const instagramPackage = 'com.instagram.android';
  static const _uuid = Uuid();
  static final RegExp _packagePattern =
      RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$');
  static const _pickerLimit = 30;

  final String deviceId;
  final DeviceRepository _deviceRepository;
  final PolicyRepository _policyRepository;
  final ConnectivityService _connectivity;

  final RxBool isLoading = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final RxBool policyReady = false.obs;
  final Rxn<Device> device = Rxn<Device>();
  final Rxn<DevicePolicy> latestPolicy = Rxn<DevicePolicy>();
  final Rxn<PolicyEnforcementReport> enforcementReport =
      Rxn<PolicyEnforcementReport>();
  final RxList<InstalledApp> reportedApps = <InstalledApp>[].obs;
  final RxBool hasLoadedSnapshot = false.obs;
  final Rxn<AppException> appsError = Rxn<AppException>();
  final RxList<AppRule> blockedRules = <AppRule>[].obs;
  final RxList<String> allowedPackages = <String>[].obs;
  final RxBool blockAllExceptAllowed = false.obs;
  final RxBool enforceAppBlocks = true.obs;
  final RxBool saving = false.obs;
  final Rxn<AppException> saveError = Rxn<AppException>();
  final Rxn<DevicePolicy> savedPolicy = Rxn<DevicePolicy>();
  final RxString statusMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxString validationMessage = ''.obs;
  final RxBool requestingSync = false.obs;
  final RxString syncMessage = ''.obs;
  final Rxn<AppException> syncError = Rxn<AppException>();
  final RxBool isOffline = false.obs;

  int? _dailyLimit;
  int? _bedtimeStart;
  int? _bedtimeEnd;
  Timer? _ackTimer;
  bool _polling = false;
  int _pollAttempts = 0;

  bool get appsReported => reportedApps.isNotEmpty;
  bool get deviceCanSuspendApps =>
      device.value?.enforcementMode == 'device_owner';
  DevicePolicy? get currentPolicy => savedPolicy.value ?? latestPolicy.value;
  PolicyEnforcementStatus? get currentStatus => currentPolicy?.status;
  int? get currentVersion => currentPolicy?.version;
  bool get awaitingAcknowledgement =>
      currentStatus == PolicyEnforcementStatus.pending;

  /// The device said it cannot suspend packages, or the server recorded it.
  bool get enforcementUnsupported =>
      currentStatus == PolicyEnforcementStatus.unsupported ||
      (enforcementReport.value?.isUnsupported ?? false);

  /// A green "enforced" claim requires counts that prove it.
  bool get enforcementProven =>
      currentStatus == PolicyEnforcementStatus.enforced &&
      (enforcementReport.value?.provesFullEnforcement ?? false);

  /// "Applied to N of M apps", or null when the device reported no counts.
  String? get appliedCountsText => enforcementReport.value?.appliedSummary;

  String get appsSnapshotMessage {
    if (appsError.value != null) {
      return 'Installed apps could not be loaded. Refresh to try again.';
    }
    if (!hasLoadedSnapshot.value) return 'Installed apps have not been loaded yet.';
    if (reportedApps.isEmpty) {
      return 'This device has not reported its installed apps yet. '
          'An empty snapshot is not the same as "no apps installed".';
    }
    return '${reportedApps.length} installed apps reported by the device.';
  }

  List<InstalledApp> get filteredApps {
    final query = searchQuery.value.trim().toLowerCase();
    final matches = reportedApps.where((app) {
      if (query.isEmpty) return true;
      return app.label.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList(growable: false);
    return matches.take(query.isEmpty ? _pickerLimit : 50).toList(growable: false);
  }

  bool get filteredAppsTruncated =>
      filteredApps.length <
      reportedApps
          .where((app) {
            final query = searchQuery.value.trim().toLowerCase();
            if (query.isEmpty) return true;
            return app.label.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query);
          })
          .length;

  bool get instagramAvailable =>
      reportedApps.any((app) => app.packageName == instagramPackage);

  bool get instagramBlocked => isBlocked(instagramPackage);

  List<InstalledApp> get blockedSystemApps => reportedApps
      .where((app) => app.isSystem && isBlocked(app.packageName))
      .toList(growable: false);

  List<String> get blockedUnreportedPackages => blockedRules
      .map((rule) => rule.packageName)
      .where((packageName) => !reportedApps
          .any((app) => app.packageName == packageName))
      .toList(growable: false);

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
    appsError.value = null;
    policyReady.value = false;
    try {
      device.value = await _deviceRepository.fetchDevice(deviceId);
      latestPolicy.value = await _policyRepository.fetchLatestPolicy(deviceId);
      policyReady.value = true;
      await _loadEnforcementReport(latestPolicy.value);
      try {
        final apps = await _deviceRepository.fetchReportedApps(deviceId);
        reportedApps.assignAll(apps);
        hasLoadedSnapshot.value = true;
      } on AppException catch (exception) {
        appsError.value = exception;
        hasLoadedSnapshot.value = false;
      } catch (exception) {
        appsError.value = AppException.from(exception);
        hasLoadedSnapshot.value = false;
      }
      _applyPolicyToDraft(
        latestPolicy.value?.payload ?? const PolicyPayload(),
      );
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isLoading.value = false;
      isOffline.value = !_connectivity.isOnline.value;
    }
  }

  void _applyPolicyToDraft(PolicyPayload payload) {
    enforceAppBlocks.value = payload.enforceAppBlocks;
    blockAllExceptAllowed.value = payload.blockAllExceptAllowed;
    allowedPackages.assignAll(payload.allowedPackages);
    _dailyLimit = payload.dailyScreenTimeLimitMinutes;
    _bedtimeStart = payload.bedtimeStartMinutes;
    _bedtimeEnd = payload.bedtimeEndMinutes;

    final merged = <String, AppRule>{};
    for (final rule in payload.appRules) {
      if (!rule.blocked || !isValidPackageName(rule.packageName)) continue;
      merged[rule.packageName] = rule;
    }
    for (final packageName in payload.blockedPackages) {
      if (!isValidPackageName(packageName)) continue;
      merged.putIfAbsent(
        packageName,
        () => AppRule(
          packageName: packageName,
          label: labelFor(packageName),
          blocked: true,
        ),
      );
    }
    blockedRules.assignAll(merged.values);
  }

  PolicyPayload get draftPayload => PolicyPayload(
        enforceAppBlocks: enforceAppBlocks.value,
        blockAllExceptAllowed: blockAllExceptAllowed.value,
        blockedPackages:
            blockedRules.map((rule) => rule.packageName).toList(growable: false),
        allowedPackages: allowedPackages.toList(growable: false),
        appRules: blockedRules.toList(growable: false),
        dailyScreenTimeLimitMinutes: _dailyLimit,
        bedtimeStartMinutes: _bedtimeStart,
        bedtimeEndMinutes: _bedtimeEnd,
      );

  static bool isValidPackageName(String value) =>
      _packagePattern.hasMatch(value.trim());

  String labelFor(String packageName) {
    for (final app in reportedApps) {
      if (app.packageName == packageName) return app.label;
    }
    return packageName;
  }

  bool isBlocked(String packageName) =>
      blockedRules.any((rule) => rule.packageName == packageName);

  bool isAllowed(String packageName) => allowedPackages.contains(packageName);

  void setSearchQuery(String value) => searchQuery.value = value;

  bool toggleAppBlocked(InstalledApp app, bool blocked) {
    if (blocked) {
      return addBlockedPackage(app.packageName, label: app.label);
    }
    removeBlockedPackage(app.packageName);
    return true;
  }

  bool addBlockedPackage(String packageName, {String? label}) {
    final normalized = packageName.trim();
    if (!isValidPackageName(normalized)) {
      validationMessage.value =
          'Enter a valid Android package name, for example com.example.app.';
      return false;
    }
    validationMessage.value = '';
    if (!isBlocked(normalized)) {
      blockedRules.add(
        AppRule(
          packageName: normalized,
          label: label ?? labelFor(normalized),
          blocked: true,
        ),
      );
    }
    allowedPackages.remove(normalized);
    return true;
  }

  void removeBlockedPackage(String packageName) {
    blockedRules.removeWhere((rule) => rule.packageName == packageName);
    validationMessage.value = '';
  }

  bool setAllowed(String packageName, bool allowed) {
    final normalized = packageName.trim();
    if (!isValidPackageName(normalized)) {
      validationMessage.value =
          'Enter a valid Android package name, for example com.example.app.';
      return false;
    }
    validationMessage.value = '';
    if (allowed) {
      if (!allowedPackages.contains(normalized)) {
        allowedPackages.add(normalized);
      }
      blockedRules.removeWhere((rule) => rule.packageName == normalized);
    } else {
      allowedPackages.remove(normalized);
    }
    return true;
  }

  void setBlockAllExceptAllowed(bool value) {
    blockAllExceptAllowed.value = value;
  }

  void selectInstagram() {
    final app = reportedApps.firstWhere(
      (candidate) => candidate.packageName == instagramPackage,
      orElse: () => const InstalledApp(
        packageName: instagramPackage,
        label: 'Instagram',
      ),
    );
    toggleAppBlocked(app, true);
  }

  List<ScheduleWindow> windowsFor(String packageName) {
    for (final rule in blockedRules) {
      if (rule.packageName == packageName) return rule.windows;
    }
    return const [];
  }

  bool addWindow(String packageName, ScheduleWindow window) {
    if (window.daysOfWeek.isEmpty) {
      validationMessage.value =
          'Choose at least one day for a schedule window.';
      return false;
    }
    if (window.startMinutes == window.endMinutes) {
      validationMessage.value =
          'Start and end times must differ. An end before the start spans midnight.';
      return false;
    }
    validationMessage.value = '';
    final index =
        blockedRules.indexWhere((rule) => rule.packageName == packageName);
    if (index == -1) return false;
    final rule = blockedRules[index];
    blockedRules[index] = rule.copyWith(
      windows: [...rule.windows, window],
    );
    return true;
  }

  void removeWindow(String packageName, int index) {
    final ruleIndex =
        blockedRules.indexWhere((rule) => rule.packageName == packageName);
    if (ruleIndex == -1) return;
    final rule = blockedRules[ruleIndex];
    if (index < 0 || index >= rule.windows.length) return;
    final windows = [...rule.windows]..removeAt(index);
    blockedRules[ruleIndex] = rule.copyWith(windows: windows);
  }

  bool updateWindow(
    String packageName,
    int index,
    ScheduleWindow window,
  ) {
    if (window.daysOfWeek.isEmpty) {
      validationMessage.value =
          'Choose at least one day for a schedule window.';
      return false;
    }
    if (window.startMinutes == window.endMinutes) {
      validationMessage.value =
          'Start and end times must differ. An end before the start spans midnight.';
      return false;
    }
    final ruleIndex =
        blockedRules.indexWhere((rule) => rule.packageName == packageName);
    if (ruleIndex == -1) return false;
    final rule = blockedRules[ruleIndex];
    if (index < 0 || index >= rule.windows.length) return false;
    validationMessage.value = '';
    final windows = [...rule.windows];
    windows[index] = window;
    blockedRules[ruleIndex] = rule.copyWith(windows: windows);
    return true;
  }

  Future<bool> savePolicy() async {
    if (saving.value) return false;
    if (!policyReady.value) {
      saveError.value = const AppException(
        AppErrorCodes.unknown,
        'The current policy could not be loaded. Refresh before saving so existing settings are preserved.',
      );
      return false;
    }
    if (blockedRules.any((rule) => !isValidPackageName(rule.packageName))) {
      validationMessage.value =
          'Remove the invalid package names before saving.';
      return false;
    }
    saving.value = true;
    saveError.value = null;
    syncMessage.value = '';
    try {
      final result = await _policyRepository.updatePolicy(
        deviceId: deviceId,
        payload: draftPayload,
        idempotencyKey: _uuid.v4(),
      );
      latestPolicy.value = result.policy;
      savedPolicy.value = result.policy;
      await _loadEnforcementReport(result.policy);
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
      await _loadEnforcementReport(policy);
      if (policy.status != PolicyEnforcementStatus.pending) {
        _ackTimer?.cancel();
      }
    } on AppException catch (exception) {
      saveError.value = exception;
    } catch (exception) {
      saveError.value = AppException.from(exception);
    }
  }

  Future<void> requestSync() async {
    if (requestingSync.value) return;
    requestingSync.value = true;
    syncMessage.value = '';
    syncError.value = null;
    try {
      await _policyRepository.createCommand(
        deviceId: deviceId,
        type: DeviceCommandType.syncPolicy,
        payload: const <String, dynamic>{},
        idempotencyKey: _uuid.v4(),
      );
      syncMessage.value =
          'Sync requested. The device will apply its saved policy on its next check-in.';
    } on AppException catch (exception) {
      syncError.value = exception;
    } catch (exception) {
      syncError.value = AppException.from(exception);
    } finally {
      requestingSync.value = false;
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
          await _loadEnforcementReport(policy);
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

  /// Loads the ack counters from the matching apply_policy command.
  ///
  /// `device_policies` stores the status but no counts, and Phase 1 adds no
  /// columns, so the command result is the only provable evidence. Failures
  /// leave the report empty instead of reusing another version's counts.
  Future<void> _loadEnforcementReport(DevicePolicy? policy) async {
    if (policy == null) {
      enforcementReport.value = null;
      return;
    }
    try {
      final commands = await _policyRepository.fetchRecentCommands(
        deviceId,
        limit: 10,
      );
      for (final command in commands) {
        if (command.type != DeviceCommandType.applyPolicy) continue;
        final result = command.result;
        if (result == null) continue;
        final commandPolicyId = command.payload['policy_id']?.toString();
        if (commandPolicyId != null &&
            commandPolicyId.isNotEmpty &&
            commandPolicyId != policy.id) {
          continue;
        }
        enforcementReport.value = PolicyEnforcementReport.fromJson(result);
        return;
      }
      enforcementReport.value = null;
    } catch (_) {
      // Counts are optional evidence; never invent them when unreadable.
      enforcementReport.value = null;
    }
  }

  String describePolicy(DevicePolicy? policy) {
    if (policy == null) {
      return 'No policy has been saved for this device yet.';
    }
    switch (policy.status) {
      case PolicyEnforcementStatus.pending:
        return policy.isAcknowledged
            ? 'Policy v${policy.version} was acknowledged, but the device did not confirm enforcement.'
            : 'Policy v${policy.version} saved. Pending device acknowledgement — no restriction is active on the device yet.';
      case PolicyEnforcementStatus.enforced:
        final counts = appliedCountsText;
        if (counts == null) {
          return 'Policy v${policy.version} is marked enforced, but the device did not '
              'report how many apps it suspended.';
        }
        final acknowledged = policy.acknowledgedAt == null
            ? ''
            : ' (acknowledged ${formatDateTime(policy.acknowledgedAt)})';
        return 'Policy v${policy.version} enforced on the device — $counts$acknowledged.';
      case PolicyEnforcementStatus.failed:
        final error =
            policy.lastError == null ? '' : ': ${policy.lastError}';
        return 'Policy v${policy.version} failed on the device$error.';
      case PolicyEnforcementStatus.unsupported:
        return 'Policy v${policy.version} cannot be enforced on this device. '
            'App blocking requires Device Owner.';
    }
  }
}
