import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local preferences only. Credentials live in the platform
/// keystore via the native device identity service.
class LocalSettingsService extends GetxService {
  static const _cachedRoleKey = 'cached_role';
  static const _activeFamilyKey = 'active_family_id';
  static const _lastSyncKey = 'last_sync_at';
  static const _notificationsKey = 'notifications_enabled';
  static const _locationSharingKey = 'location_sharing_enabled';
  static const _childContactPrefix = 'child_contact_id_';

  SharedPreferences? _prefs;

  Future<LocalSettingsService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalSettingsService.init() was not awaited');
    }
    return prefs;
  }

  String? get cachedRole => _store.getString(_cachedRoleKey);
  Future<void> setCachedRole(String? role) async {
    if (role == null) {
      await _store.remove(_cachedRoleKey);
    } else {
      await _store.setString(_cachedRoleKey, role);
    }
  }

  String? get activeFamilyId => _store.getString(_activeFamilyKey);
  Future<void> setActiveFamilyId(String? familyId) async {
    if (familyId == null) {
      await _store.remove(_activeFamilyKey);
    } else {
      await _store.setString(_activeFamilyKey, familyId);
    }
  }

  DateTime? get lastSyncAt {
    final millis = _store.getInt(_lastSyncKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastSyncAt(DateTime value) =>
      _store.setInt(_lastSyncKey, value.millisecondsSinceEpoch);

  bool get notificationsEnabled => _store.getBool(_notificationsKey) ?? true;
  Future<void> setNotificationsEnabled(bool value) =>
      _store.setBool(_notificationsKey, value);

  bool get locationSharingEnabled => _store.getBool(_locationSharingKey) ?? true;
  Future<void> setLocationSharingEnabled(bool value) =>
      _store.setBool(_locationSharingKey, value);

  /// Raw JSON so this service keeps no dependency on the pairing models.
  String? cachedChildContactId(String userId) {
    if (userId.isEmpty) return null;
    return _store.getString('$_childContactPrefix$userId');
  }

  Future<void> setCachedChildContactId(String userId, String json) async {
    if (userId.isEmpty) return;
    await _store.setString('$_childContactPrefix$userId', json);
  }

  Future<void> clearCachedChildContactId(String userId) async {
    if (userId.isEmpty) return;
    await _store.remove('$_childContactPrefix$userId');
  }

  Future<void> clearOnSignOut() async {
    await _store.remove(_activeFamilyKey);
    await _store.remove(_lastSyncKey);
    // The Child ID is only an identifier, but it names the account that was
    // signed in on a shared phone, so signing out forgets every cached copy.
    for (final key in _store.getKeys().toList()) {
      if (key.startsWith(_childContactPrefix)) {
        await _store.remove(key);
      }
    }
    // Keep the cached role to preselect the role card next time; it is not
    // security-relevant and the server decides the actual permissions.
  }
}
