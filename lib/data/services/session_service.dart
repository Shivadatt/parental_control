import 'package:get/get.dart';

import '../models/account.dart';
import '../models/device.dart';

/// Holds the signed-in user's *display* state only.
///
/// The selected role and active family never grant access on their own: RLS,
/// Edge Function caller checks and device credentials are authoritative.
class SessionService extends GetxService {
  final Rxn<Profile> profile = Rxn<Profile>();
  final Rxn<Family> activeFamily = Rxn<Family>();
  final Rxn<Device> activeDevice = Rxn<Device>();
  final Rxn<DeviceIdentity> deviceIdentity = Rxn<DeviceIdentity>();

  final RxString userId = ''.obs;
  final RxString email = ''.obs;
  final RxBool emailVerified = false.obs;

  bool get isAuthenticated => userId.value.isNotEmpty;
  bool get isParent => profile.value?.role == ProfileRole.parent;
  bool get isChild => profile.value?.role == ProfileRole.child;
  bool get hasChosenRole => profile.value?.role.isChosen ?? false;
  bool get needsRoleSelection => isAuthenticated && !hasChosenRole;

  String get displayName =>
      profile.value?.displayName ?? (email.value.isEmpty ? 'Account' : email.value);

  void setAuthenticated({
    required String id,
    required String address,
    required bool verified,
  }) {
    userId.value = id;
    email.value = address;
    emailVerified.value = verified;
  }

  void setProfile(Profile? value) {
    profile.value = value;
  }

  void setActiveFamily(Family? value) {
    activeFamily.value = value;
  }

  void setActiveDevice(Device? value) {
    activeDevice.value = value;
  }

  void setDeviceIdentity(DeviceIdentity? value) {
    deviceIdentity.value = value;
  }

  void clear() {
    profile.value = null;
    activeFamily.value = null;
    activeDevice.value = null;
    deviceIdentity.value = null;
    userId.value = '';
    email.value = '';
    emailVerified.value = false;
  }
}
