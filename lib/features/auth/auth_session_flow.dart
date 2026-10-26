import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';

/// Where a signed-in account has to go next, derived only from server state.
enum SignedInDestination {
  signedOut,
  verifyEmail,
  chooseRole,
  familySetup,
  parentShell,
  childShell,
}

/// Loads the authoritative profile and family state after an auth change and
/// stores it on [SessionService] for display. It never assigns a role, invents
/// a family or treats a local choice as authorization.
class AuthSessionFlow {
  AuthSessionFlow({
    required AuthRepository authRepository,
    required FamilyRepository familyRepository,
    required this._session,
    required this._settings,
  })  : _auth = authRepository,
        _family = familyRepository;

  final AuthRepository _auth;
  final FamilyRepository _family;
  final SessionService _session;
  final LocalSettingsService _settings;

  Future<SignedInDestination> resolve() async {
    final userId = _auth.currentUserId;
    if (userId == null || userId.isEmpty) {
      _session.clear();
      await _settings.setActiveFamilyId(null);
      return SignedInDestination.signedOut;
    }

    final email = _auth.currentEmail ?? '';
    final verified = _auth.isEmailVerified;
    _session.setAuthenticated(id: userId, address: email, verified: verified);
    // Drop display state from a previous account before loading fresh rows.
    _session.setProfile(null);
    _session.setActiveFamily(null);
    _session.setActiveDevice(null);
    _session.setDeviceIdentity(null);

    if (!verified) return SignedInDestination.verifyEmail;

    final profile = await _auth.fetchProfile();
    if (profile == null || !profile.role.isChosen) {
      _session.setProfile(profile);
      return SignedInDestination.chooseRole;
    }
    _session.setProfile(profile);
    await _settings.setCachedRole(profile.role.wireName);

    if (profile.role.isChild) return SignedInDestination.childShell;

    final families = await _family.fetchMyFamilies();
    if (families.isEmpty) {
      await _settings.setActiveFamilyId(null);
      return SignedInDestination.familySetup;
    }

    final preferredId = _settings.activeFamilyId;
    var active = families.first;
    for (final family in families) {
      if (family.id == preferredId) {
        active = family;
        break;
      }
    }
    _session.setActiveFamily(active);
    await _settings.setActiveFamilyId(active.id);
    return SignedInDestination.parentShell;
  }
}

String routeForDestination(SignedInDestination destination) {
  switch (destination) {
    case SignedInDestination.signedOut:
    case SignedInDestination.chooseRole:
      return AppRoutes.roleSelection;
    case SignedInDestination.verifyEmail:
      return AppRoutes.verifyEmail;
    case SignedInDestination.familySetup:
      return AppRoutes.familySetup;
    case SignedInDestination.parentShell:
      return AppRoutes.parentShell;
    case SignedInDestination.childShell:
      return AppRoutes.childShell;
  }
}

/// Navigates with the route arguments each destination expects. Controllers
/// call this only after the server state has been loaded.
void openDestination(SignedInDestination destination, {String? email}) {
  final route = routeForDestination(destination);
  switch (destination) {
    case SignedInDestination.verifyEmail:
      Get.offAllNamed(route, arguments: {'email': email ?? ''});
      return;
    case SignedInDestination.chooseRole:
      Get.offAllNamed(route, arguments: {'mode': 'lock'});
      return;
    case SignedInDestination.signedOut:
    case SignedInDestination.familySetup:
    case SignedInDestination.parentShell:
    case SignedInDestination.childShell:
      Get.offAllNamed(route);
      return;
  }
}

/// Convenience for screens that already know the intended local role.
String roleArgument(ProfileRole role) => role.wireName;
