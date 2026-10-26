import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';

/// The child device's own inbox. Every action here is an explicit choice made
/// on the child's visible screen; nothing is accepted automatically.
class ChildRequestsController extends GetxController {
  ChildRequestsController({
    required PairingRepository pairingRepository,
    required RemoteSessionRepository remoteSessionRepository,
    required this._connectivity,
  })  : _pairing = pairingRepository,
        _remoteSessions = remoteSessionRepository;

  final PairingRepository _pairing;
  final RemoteSessionRepository _remoteSessions;
  final ConnectivityService _connectivity;

  static const Duration pollInterval = Duration(seconds: 15);

  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isResponding = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final RxnString actionMessage = RxnString();
  final RxList<PairingRequest> pairingRequests = <PairingRequest>[].obs;
  final RxList<RemoteSession> sessionRequests = <RemoteSession>[].obs;
  final Rxn<DateTime> lastLoadedAt = Rxn<DateTime>();

  Timer? _pollTimer;

  bool get isOnline => _connectivity.isOnline.value;
  int get pendingCount => pairingRequests.length + sessionRequests.length;

  @override
  void onInit() {
    super.onInit();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_connectivity.isOnline.value && !isLoading.value) {
        unawaited(refresh());
      }
    });
    unawaited(load());
  }

  Future<void> load({bool showLoading = true}) async {
    if (!showLoading && isLoading.value) return;
    if (isRefreshing.value || isResponding.value) return;
    if (showLoading) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }
    error.value = null;
    if (!_connectivity.isOnline.value) {
      final offline = AppException.network();
      if (pairingRequests.isEmpty && sessionRequests.isEmpty) {
        error.value = offline;
      } else {
        actionError.value = offline;
      }
      isLoading.value = false;
      isRefreshing.value = false;
      return;
    }
    AppException? pairingFailure;
    AppException? sessionFailure;
    try {
      final pairings = await _pairing.fetchPendingForChild();
      pairingRequests.assignAll(
        pairings.where((request) => request.isPending).toList(growable: false),
      );
    } catch (caught) {
      pairingFailure = AppException.from(caught);
    }
    try {
      final sessions = await _remoteSessions.fetchPendingForChild();
      sessionRequests.assignAll(
        sessions
            .where(
              (session) =>
                  session.status == RemoteSessionStatus.requested &&
                  !session.isExpired,
            )
            .toList(growable: false),
      );
    } catch (caught) {
      sessionFailure = AppException.from(caught);
    }
    if (pairingFailure != null && sessionFailure != null) {
      error.value = pairingFailure;
    } else if (pairingFailure != null || sessionFailure != null) {
      actionError.value = pairingFailure ?? sessionFailure;
    }
    lastLoadedAt.value = DateTime.now();
    isLoading.value = false;
    isRefreshing.value = false;
  }

  @override
  Future<void> refresh() => load(showLoading: false);

  bool get _busy => isResponding.value;

  Future<bool> approvePairing(PairingRequest request) async {
    return _respondPairing(request, approve: true);
  }

  Future<bool> declinePairing(PairingRequest request) async {
    return _respondPairing(request, approve: false);
  }

  Future<bool> _respondPairing(
    PairingRequest request, {
    required bool approve,
  }) async {
    if (_busy) return false;
    actionError.value = null;
    actionMessage.value = null;
    if (!request.isPending) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'This request has already been answered or has expired.',
      );
      return false;
    }
    if (!isOnline) {
      actionError.value = AppException.network();
      return false;
    }
    isResponding.value = true;
    try {
      await _pairing.respond(requestId: request.id, approve: approve);
      if (approve) {
        actionMessage.value = 'Family linked. Register this phone next.';
        Get.offAllNamed(AppRoutes.childEnrollment);
        return true;
      }
      actionMessage.value = 'Request declined. No family was linked.';
      isResponding.value = false;
      await load(showLoading: false);
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      return false;
    } finally {
      isResponding.value = false;
    }
  }

  Future<bool> acceptSession(RemoteSession session) async {
    return _respondSession(session, accept: true);
  }

  Future<bool> declineSession(RemoteSession session) async {
    return _respondSession(session, accept: false);
  }

  Future<bool> _respondSession(
    RemoteSession session, {
    required bool accept,
  }) async {
    if (_busy) return false;
    actionError.value = null;
    actionMessage.value = null;
    if (session.status != RemoteSessionStatus.requested || session.isExpired) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'This assistance request is no longer open.',
      );
      return false;
    }
    if (!isOnline) {
      actionError.value = AppException.network();
      return false;
    }
    isResponding.value = true;
    try {
      final updated = await _remoteSessions.respond(
        sessionId: session.id,
        accept: accept,
      );
      isResponding.value = false;
      if (accept) {
        Get.toNamed(
          AppRoutes.childSession,
          arguments: {'sessionId': updated.id, 'role': 'child'},
        );
      } else {
        actionMessage.value = 'Assistance request declined.';
        isResponding.value = false;
        await load(showLoading: false);
      }
      return true;
    } catch (caught) {
      actionError.value = AppException.from(caught);
      isResponding.value = false;
      return false;
    }
  }

  void clearActionError() => actionError.value = null;

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }
}
