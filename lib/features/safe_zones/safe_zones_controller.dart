import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/telemetry.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';

class SafeZonesController extends GetxController {
  SafeZonesController({
    required this._locationRepository,
    required this._familyRepository,
    required this._session,
    required this.familyId,
    this.deviceId,
  });

  final LocationRepository _locationRepository;
  final FamilyRepository _familyRepository;
  final SessionService _session;
  final String familyId;
  final String? deviceId;

  final RxList<SafeZone> zones = <SafeZone>[].obs;
  final Rxn<Family> family = Rxn<Family>();
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString savingZoneId = RxnString();
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> familyError = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();

  bool get hasContext => familyId.isNotEmpty;
  bool get canManage =>
      family.value != null &&
      _session.userId.value.isNotEmpty &&
      family.value!.ownerId == _session.userId.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (!hasContext) {
      isLoading.value = false;
      isRefreshing.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'This screen needs a family. Open it from a family screen.',
      );
      return;
    }
    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    error.value = null;
    familyError.value = null;
    await Future.wait([_loadZones(), _loadFamily()]);
    if (refresh) {
      isRefreshing.value = false;
    } else {
      isLoading.value = false;
    }
  }

  Future<void> _loadZones() async {
    try {
      final rows = await _locationRepository.fetchSafeZones(familyId);
      zones.assignAll(rows);
    } catch (caught) {
      zones.clear();
      error.value = AppException.from(caught);
    }
  }

  Future<void> _loadFamily() async {
    try {
      family.value = await _familyRepository.fetchFamily(familyId);
    } catch (caught) {
      family.value = null;
      familyError.value = AppException.from(caught);
    }
  }

  String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Zone name is required';
    if (name.length > 60) return 'Keep the name under 60 characters';
    return null;
  }

  String? validateLatitude(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a latitude between -90 and 90';
    if (parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  String? validateLongitude(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a longitude between -180 and 180';
    if (parsed < -180 || parsed > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  String? validateRadius(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a radius in metres';
    if (parsed < 50 || parsed > 5000) {
      return 'Radius must be between 50 and 5000 metres';
    }
    return null;
  }

  Future<bool> saveZone({
    String? zoneId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusM,
    required bool active,
  }) async {
    if (!canManage) {
      actionError.value = const AppException(
        AppErrorCodes.forbidden,
        'Only the family owner can manage safe zones.',
      );
      return false;
    }
    if (isSaving.value) return false;
    actionError.value = null;
    isSaving.value = true;
    try {
      final saved = await _locationRepository.upsertSafeZone(
        familyId: familyId,
        zone: SafeZone(
          id: zoneId ?? '',
          familyId: familyId,
          name: name.trim(),
          latitude: latitude,
          longitude: longitude,
          radiusM: radiusM,
          active: active,
        ),
      );
      final index = zones.indexWhere((zone) => zone.id == saved.id);
      if (index >= 0) {
        zones[index] = saved;
      } else {
        zones.add(saved);
      }
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> setActive(SafeZone zone, bool active) async {
    if (isSaving.value || savingZoneId.value != null) return false;
    actionError.value = null;
    savingZoneId.value = zone.id;
    try {
      final saved = await _locationRepository.upsertSafeZone(
        familyId: familyId,
        zone: SafeZone(
          id: zone.id,
          familyId: zone.familyId,
          name: zone.name,
          latitude: zone.latitude,
          longitude: zone.longitude,
          radiusM: zone.radiusM,
          active: active,
        ),
      );
      final index = zones.indexWhere((item) => item.id == saved.id);
      if (index >= 0) zones[index] = saved;
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      savingZoneId.value = null;
    }
  }

  Future<bool> deleteZone(SafeZone zone) async {
    if (isSaving.value || savingZoneId.value != null) return false;
    actionError.value = null;
    savingZoneId.value = zone.id;
    try {
      await _locationRepository.deleteSafeZone(zone.id);
      zones.removeWhere((item) => item.id == zone.id);
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      savingZoneId.value = null;
    }
  }
}
