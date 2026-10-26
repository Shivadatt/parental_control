import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive preferences for the child experience.
///
/// Location sharing is off by default and only changes when the child turns it
/// on from a visible screen. The value is a preference, not proof that the
/// native location service is running; callers must still start and verify the
/// Android service.
class ChildPreferences {
  static const String locationSharingKey = 'child_location_sharing_enabled';

  Future<SharedPreferences> get _store => SharedPreferences.getInstance();

  Future<bool> locationSharingEnabled() async {
    final prefs = await _store;
    return prefs.getBool(locationSharingKey) ?? false;
  }

  Future<void> setLocationSharingEnabled(bool value) async {
    final prefs = await _store;
    await prefs.setBool(locationSharingKey, value);
  }

  Future<void> clear() async {
    final prefs = await _store;
    await prefs.remove(locationSharingKey);
  }
}
