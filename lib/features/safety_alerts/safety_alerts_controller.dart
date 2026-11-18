import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/telemetry.dart';
import '../../data/repositories/repository_contracts.dart';

class SafetyAlertsController extends GetxController with WidgetsBindingObserver {
  SafetyAlertsController({
    required this._alertRepository,
    required this.familyId,
    this.retryDelayProvider,
  });

  final AlertRepository _alertRepository;
  final String familyId;
  final Duration Function(int attempt)? retryDelayProvider;

  static const int maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final RxList<SafetyAlert> alerts = <SafetyAlert>[].obs;
  final Rxn<AlertSeverity> severityFilter = Rxn<AlertSeverity>();
  final RxList<String> acknowledgingIds = <String>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isWatching = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> realtimeError = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();

  StreamSubscription<List<SafetyAlert>>? _subscription;

  bool get hasContext => familyId.isNotEmpty;
  bool get isEmpty => alerts.isEmpty;
  int get unacknowledgedCount => alerts.where((a) => !a.isAcknowledged).length;
  int get reconnectAttempts => _reconnectAttempts;

  List<SafetyAlert> get visibleAlerts {
    final severity = severityFilter.value;
    if (severity == null) return alerts;
    return alerts.where((alert) => alert.severity == severity).toList();
  }

  @override
  void onInit() {
    super.onInit();
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In tests without full binding, observer registration is gracefully skipped.
    }
    load();
    _subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!hasContext) return;
    if (!isWatching.value || realtimeError.value != null) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _subscribe();
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (!hasContext) {
      isLoading.value = false;
      isRefreshing.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'This screen needs a family. Open it from the family screen.',
      );
      return;
    }
    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    error.value = null;
    try {
      final rows = await _alertRepository.fetchAlerts(familyId: familyId);
      alerts.assignAll(rows);
      _sortAlerts();
    } catch (caught) {
      error.value = AppException.from(caught);
    } finally {
      if (refresh) {
        isRefreshing.value = false;
      } else {
        isLoading.value = false;
      }
    }
  }

  void _subscribe({bool isRetry = false}) {
    if (!hasContext || isClosed) return;
    _reconnectTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = _alertRepository.watchAlerts(familyId).listen(
      (incoming) {
        _reconnectAttempts = 0;
        isWatching.value = true;
        realtimeError.value = null;
        _merge(incoming);
      },
      onError: (Object caught) {
        isWatching.value = false;
        if (_reconnectAttempts < maxReconnectAttempts) {
          _reconnectAttempts++;
          final delay = retryDelayProvider?.call(_reconnectAttempts) ??
              Duration(seconds: 1 << _reconnectAttempts);
          _reconnectTimer = Timer(delay, () {
            if (!isClosed) {
              _subscribe(isRetry: true);
            }
          });
        } else {
          realtimeError.value = AppException.from(caught);
        }
      },
    );
    isWatching.value = true;
  }

  Future<void> retryRealtime() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    realtimeError.value = null;
    _subscribe();
  }

  Future<bool> acknowledge(SafetyAlert alert) async {
    if (alert.isAcknowledged || acknowledgingIds.contains(alert.id)) {
      return false;
    }
    actionError.value = null;
    acknowledgingIds.add(alert.id);
    try {
      await _alertRepository.acknowledgeAlert(alert.id);
      final index = alerts.indexWhere((item) => item.id == alert.id);
      if (index >= 0) {
        alerts[index] = _acknowledgedCopy(alerts[index]);
      }
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      acknowledgingIds.remove(alert.id);
    }
  }

  void _merge(List<SafetyAlert> incoming) {
    if (incoming.isEmpty) return;
    for (final alert in incoming) {
      final index = alerts.indexWhere((item) => item.id == alert.id);
      if (index < 0) {
        alerts.add(alert);
        continue;
      }
      final existing = alerts[index];
      final deviceName = alert.deviceName ?? existing.deviceName;
      alerts[index] = _copyWith(alert, deviceName: deviceName);
    }
    _sortAlerts();
  }

  void _sortAlerts() {
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  SafetyAlert _acknowledgedCopy(SafetyAlert alert) => SafetyAlert(
        id: alert.id,
        familyId: alert.familyId,
        deviceId: alert.deviceId,
        type: alert.type,
        severity: alert.severity,
        message: alert.message,
        createdAt: alert.createdAt,
        payload: alert.payload,
        acknowledgedAt: alert.acknowledgedAt ?? DateTime.now(),
        acknowledgedBy: alert.acknowledgedBy,
        deviceName: alert.deviceName,
      );

  SafetyAlert _copyWith(SafetyAlert alert, {String? deviceName}) => SafetyAlert(
        id: alert.id,
        familyId: alert.familyId,
        deviceId: alert.deviceId,
        type: alert.type,
        severity: alert.severity,
        message: alert.message,
        createdAt: alert.createdAt,
        payload: alert.payload,
        acknowledgedAt: alert.acknowledgedAt,
        acknowledgedBy: alert.acknowledgedBy,
        deviceName: deviceName,
      );

  @override
  void onClose() {
    _reconnectTimer?.cancel();
    unawaited(_subscription?.cancel());
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.onClose();
  }
}
