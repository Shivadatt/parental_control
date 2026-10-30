import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote_session.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';

class RemoteAssistanceController extends GetxController {
  RemoteAssistanceController({
    required this._remoteSessionRepository,
    required this._session,
    required this.deviceId,
  });

  final RemoteSessionRepository _remoteSessionRepository;
  final SessionService _session;
  final String deviceId;

  final RxList<RemoteSession> sessions = <RemoteSession>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<SessionKind> requestingKind = Rxn<SessionKind>();
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();

  String get familyId => _session.activeFamily.value?.id ?? '';
  bool get hasDevice => deviceId.isNotEmpty;
  bool get hasFamily => familyId.isNotEmpty;
  bool get isRequesting => requestingKind.value != null;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (!hasFamily || !hasDevice) {
      isLoading.value = false;
      isRefreshing.value = false;
      error.value = const AppException(
        AppErrorCodes.validation,
        'Open this screen from a device in your family to request assistance.',
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
      final rows = await _remoteSessionRepository.fetchForFamily(familyId);
      sessions.assignAll(rows);
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

  Future<RemoteSession?> requestSession(SessionKind kind) async {
    if (isRequesting) return null;
    actionError.value = null;
    requestingKind.value = kind;
    try {
      final created = await _remoteSessionRepository.request(
        deviceId: deviceId,
        kind: kind,
      );
      sessions.removeWhere((session) => session.id == created.id);
      sessions.insert(0, created);
      return created;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return null;
    } finally {
      requestingKind.value = null;
    }
  }

  /// The server may not have run its pending-expiry job yet. Showing a
  /// client-side expiry label is honest and never writes a status.
  ///
  /// Only a pending request can expire; a consented session is parent-
  /// controlled. The label reflects server session state only; it never claims
  /// that audio or video is connected.
  String statusLabel(RemoteSession session) {
    if (session.status == RemoteSessionStatus.requested && session.isExpired) {
      return 'Request expired';
    }
    return session.status.label;
  }

  /// Lifetime wording for the list. A pending request counts down; a consented
  /// session states who controls when it ends.
  String expiryLabel(RemoteSession session) {
    if (session.status == RemoteSessionStatus.requested) {
      final deadline = session.expiresAt;
      if (session.isExpired || deadline == null) return 'Expired';
      return relativeTime(deadline);
    }
    if (session.isParentControlled) return 'Until you end it';
    return '—';
  }
}
