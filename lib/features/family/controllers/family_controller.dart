import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';

/// Shows one family loaded from RLS-protected rows. Unlink is only considered
/// done after the Edge Function confirms it and the rows are reloaded.
class FamilyController extends GetxController {
  FamilyController({
    required this._familyRepository,
    required this._pairingRepository,
    required this._session,
    required this._connectivity,
  });

  final FamilyRepository _familyRepository;
  final PairingRepository _pairingRepository;
  final SessionService _session;
  final ConnectivityService _connectivity;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final Rxn<Family> family = Rxn<Family>();
  final RxList<FamilyMember> members = <FamilyMember>[].obs;
  final RxBool isUnlinking = false.obs;

  String _familyId = '';

  String get familyId => _familyId;
  bool get isOnline => _connectivity.isOnline.value;
  bool get hasFamily => family.value != null;
  bool get isEmpty => family.value == null;

  List<FamilyMember> get guardians =>
      members.where((member) => !member.isChild).toList(growable: false);
  List<FamilyMember> get children =>
      members.where((member) => member.isChild).toList(growable: false);

  bool isOwner(Family value) => value.ownerId == _session.userId.value;
  bool isCurrentUser(FamilyMember member) =>
      member.userId == _session.userId.value;

  FamilyMember? guardianFor(Family value) {
    for (final member in members) {
      if (member.userId == value.ownerId) return member;
    }
    return null;
  }

  void clearActionError() => actionError.value = null;

  Future<void> start(String? familyId) async {
    final nextId = familyId?.trim() ?? '';
    if (nextId != _familyId) {
      family.value = null;
      members.clear();
      error.value = null;
    }
    _familyId = nextId;
    actionError.value = null;
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No family was selected. Go back and open the family again.',
      );
      return;
    }
    await load();
  }

  Future<void> load({bool refresh = false}) async {
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No family was selected. Go back and open the family again.',
      );
      return;
    }
    if (isLoading.value || isRefreshing.value) return;
    if (!_connectivity.isOnline.value) {
      final offline = AppException.network();
      if (family.value == null) {
        error.value = offline;
      } else {
        actionError.value = offline;
      }
      return;
    }
    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    error.value = null;
    try {
      final loadedFamily = await _familyRepository.fetchFamily(_familyId);
      if (loadedFamily == null) {
        family.value = null;
        members.clear();
        error.value = const AppException(
          AppErrorCodes.notFound,
          'This family was not found or is no longer visible to this account.',
        );
        return;
      }
      final loadedMembers = await _familyRepository.fetchMembers(_familyId);
      family.value = loadedFamily;
      members.assignAll(loadedMembers);
      _session.setActiveFamily(loadedFamily);
    } on AppException catch (exception) {
      if (family.value == null) {
        error.value = exception;
      } else {
        actionError.value = exception;
      }
    } catch (exception) {
      final mapped = AppException.from(exception);
      if (family.value == null) {
        error.value = mapped;
      } else {
        actionError.value = mapped;
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  @override
  Future<void> refresh() => load(refresh: true);

  Future<bool> unlink(FamilyMember member) async {
    final currentFamily = family.value;
    if (currentFamily == null || _familyId.isEmpty) {
      actionError.value = const AppException(
        AppErrorCodes.notFound,
        'This family is not loaded. Refresh before removing a child.',
      );
      return false;
    }
    if (!member.isChild || !member.isActive) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Only an active child account can be unlinked.',
      );
      return false;
    }
    if (isUnlinking.value) return false;
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return false;
    }

    isUnlinking.value = true;
    actionError.value = null;
    try {
      await _pairingRepository.unlink(
        familyId: currentFamily.id,
        childUserId: member.userId,
      );
      // Only the reloaded rows are presented; no optimistic removal.
      await load(refresh: true);
      return true;
    } on AppException catch (exception) {
      actionError.value = exception;
      return false;
    } catch (exception) {
      actionError.value = AppException.from(exception);
      return false;
    } finally {
      isUnlinking.value = false;
    }
  }
}
