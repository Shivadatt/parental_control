import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/telemetry.dart';
import '../../data/repositories/repository_contracts.dart';

enum LocationHistoryRange {
  last24Hours,
  last7Days;

  Duration get duration => this == LocationHistoryRange.last24Hours
      ? const Duration(hours: 24)
      : const Duration(days: 7);

  String get label => this == LocationHistoryRange.last24Hours
      ? 'Last 24 hours'
      : 'Last 7 days';

  String get shortLabel =>
      this == LocationHistoryRange.last24Hours ? '24h' : '7d';
}

class LocationController extends GetxController {
  LocationController({
    required this._locationRepository,
    required this.deviceId,
    required this.familyId,
  });

  final LocationRepository _locationRepository;
  final String deviceId;
  final String familyId;

  final Rxn<LocationEvent> latest = Rxn<LocationEvent>();
  final RxList<LocationEvent> history = <LocationEvent>[].obs;
  final Rx<LocationHistoryRange> range = LocationHistoryRange.last24Hours.obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isHistoryLoading = true.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> historyError = Rxn<AppException>();
  final Rxn<DateTime> lastLoadedAt = Rxn<DateTime>();

  static const int historyLimit = 500;

  bool get hasContext => deviceId.isNotEmpty && familyId.isNotEmpty;
  bool get hasNeverReported => latest.value == null && error.value == null;
  bool get latestIsStale => latest.value?.isStale ?? false;
  bool get permissionDenied =>
      error.value?.isForbidden == true ||
      error.value?.code == 'permission_denied';
  bool get hasMoreHistoryThanShown =>
      history.length >= historyLimit;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (!hasContext) {
      isLoading.value = false;
      isRefreshing.value = false;
      isHistoryLoading.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'This screen needs a device and family. Open it from the device list.',
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
      latest.value = await _locationRepository.fetchLatestLocation(deviceId);
    } catch (caught) {
      latest.value = null;
      error.value = AppException.from(caught);
    }
    lastLoadedAt.value = DateTime.now();
    if (refresh) {
      isRefreshing.value = false;
    } else {
      isLoading.value = false;
    }
    await loadHistory();
  }

  Future<void> loadHistory() async {
    isHistoryLoading.value = true;
    historyError.value = null;
    final to = DateTime.now();
    try {
      final rows = await _locationRepository.fetchHistory(
        deviceId: deviceId,
        from: to.subtract(range.value.duration),
        to: to,
      );
      history.assignAll(rows);
    } catch (caught) {
      history.clear();
      historyError.value = AppException.from(caught);
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> setRange(LocationHistoryRange value) async {
    if (range.value == value) return;
    range.value = value;
    await loadHistory();
  }
}
