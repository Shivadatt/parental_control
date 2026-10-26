import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/audit.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';

class AuditLogsController extends GetxController {
  AuditLogsController({
    required this._auditRepository,
    required this._session,
    required this.familyId,
  });

  final AuditRepository _auditRepository;
  final SessionService _session;
  final String familyId;

  static const int pageSize = 50;
  static const int maxEntries = 500;

  final RxList<AuditLogEntry> entries = <AuditLogEntry>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final RxnInt locationDays = RxnInt();
  final RxnInt usageDays = RxnInt();
  final RxBool isSavingRetention = false.obs;
  final RxBool isPurging = false.obs;
  final RxnInt lastPurgeCount = RxnInt();

  int _limit = pageSize;

  bool get hasContext => familyId.isNotEmpty;
  bool get canManage {
    final family = _session.activeFamily.value;
    return family != null &&
        family.id == familyId &&
        family.ownerId == _session.userId.value &&
        _session.userId.value.isNotEmpty;
  }

  bool get atPaginationCap => _limit >= maxEntries;

  @override
  void onInit() {
    super.onInit();
    syncRetentionFromFamily();
    load();
  }

  void syncRetentionFromFamily() {
    final family = _session.activeFamily.value;
    if (family == null || family.id != familyId) return;
    locationDays.value = family.settings.locationRetentionDays;
    usageDays.value = family.settings.usageRetentionDays;
  }

  Future<void> load({bool refresh = false}) async {
    if (!hasContext) {
      isLoading.value = false;
      isRefreshing.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'This screen needs a family. Open it from the family settings.',
      );
      return;
    }
    if (refresh) {
      isRefreshing.value = true;
      _limit = pageSize;
    } else {
      isLoading.value = true;
    }
    error.value = null;
    try {
      final rows = await _auditRepository.fetchAuditLogs(
        familyId: familyId,
        limit: _limit,
      );
      entries.assignAll(rows);
      hasMore.value = rows.length >= _limit && _limit < maxEntries;
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

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || atPaginationCap) return;
    isLoadingMore.value = true;
    actionError.value = null;
    final next = (_limit + pageSize).clamp(pageSize, maxEntries).toInt();
    try {
      final rows = await _auditRepository.fetchAuditLogs(
        familyId: familyId,
        limit: next,
      );
      entries.assignAll(rows);
      _limit = next;
      hasMore.value = rows.length >= _limit && _limit < maxEntries;
    } catch (caught) {
      actionError.value = AppException.from(caught);
    } finally {
      isLoadingMore.value = false;
    }
  }

  String? validateLocationDays(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a whole number of days';
    if (parsed < 1 || parsed > 365) return 'Use 1 to 365 days';
    return null;
  }

  String? validateUsageDays(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a whole number of days';
    if (parsed < 1 || parsed > 730) return 'Use 1 to 730 days';
    return null;
  }

  String? validatePurgeDays(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a whole number of days';
    if (parsed < 1) return 'Must be at least 1 day';
    if (parsed > 3650) return 'Use 3650 days or fewer';
    return null;
  }

  Future<bool> saveRetention({
    required int location,
    required int usage,
  }) async {
    if (!canManage) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the family owner can change retention.',
      );
      return false;
    }
    if (location < 1 || location > 365) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Location retention must be between 1 and 365 days.',
      );
      return false;
    }
    if (usage < 1 || usage > 730) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Usage retention must be between 1 and 730 days.',
      );
      return false;
    }
    if (isSavingRetention.value) return false;
    isSavingRetention.value = true;
    actionError.value = null;
    try {
      await _auditRepository.updateRetention(
        familyId: familyId,
        locationDays: location,
        usageDays: usage,
      );
      locationDays.value = location;
      usageDays.value = usage;
      final family = _session.activeFamily.value;
      if (family != null && family.id == familyId) {
        _session.setActiveFamily(
          Family(
            id: family.id,
            name: family.name,
            ownerId: family.ownerId,
            settings: FamilySettings(
              locationRetentionDays: location,
              usageRetentionDays: usage,
            ),
            createdAt: family.createdAt,
          ),
        );
      }
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isSavingRetention.value = false;
    }
  }

  /// Returns the server-reported deletion count, or null when the purge failed.
  Future<int?> purgeOldData(int olderThanDays) async {
    if (!canManage) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the family owner can purge historical data.',
      );
      return null;
    }
    if (olderThanDays < 1) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Choose at least 1 day of data to keep.',
      );
      return null;
    }
    if (isPurging.value) return null;
    isPurging.value = true;
    actionError.value = null;
    lastPurgeCount.value = null;
    try {
      final deleted = await _auditRepository.purgeOldData(
        familyId: familyId,
        olderThanDays: olderThanDays,
      );
      lastPurgeCount.value = deleted;
      await load(refresh: true);
      return deleted;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return null;
    } finally {
      isPurging.value = false;
    }
  }
}
