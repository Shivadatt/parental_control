import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';

/// Family pairing requests with a user-visible poll. The timer only refreshes
/// from the server and is cancelled with the controller.
class PairingRequestsController extends GetxController {
  PairingRequestsController({
    required PairingRepository pairingRepository,
    required this._connectivity,
  })  : _pairing = pairingRepository;

  final PairingRepository _pairing;
  final ConnectivityService _connectivity;

  static const Duration pollInterval = Duration(seconds: 20);

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isCancelling = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<AppException> actionError = Rxn<AppException>();
  final RxList<PairingRequest> requests = <PairingRequest>[].obs;

  Timer? _pollTimer;
  String _familyId = '';

  String get familyId => _familyId;
  bool get isOnline => _connectivity.isOnline.value;
  bool get isEmpty => requests.isEmpty;

  Future<void> start(String? familyId) async {
    _familyId = familyId?.trim() ?? '';
    error.value = null;
    actionError.value = null;
    requests.clear();
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No family was selected. Go back and open the family again.',
      );
      return;
    }
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_connectivity.isOnline.value) {
        unawaited(_load(silent: true));
      }
    });
    await _load();
  }

  void clearActionError() => actionError.value = null;

  @override
  Future<void> refresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'No family was selected. Go back and open the family again.',
      );
      return;
    }
    if (isLoading.value || isRefreshing.value || isCancelling.value) return;
    if (!_connectivity.isOnline.value) {
      final offline = AppException.network();
      if (requests.isEmpty) {
        error.value = offline;
      } else {
        actionError.value = offline;
      }
      return;
    }
    if (silent) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    error.value = null;
    try {
      final loaded = await _pairing.fetchForFamily(_familyId);
      final sorted = List<PairingRequest>.of(loaded)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      requests.assignAll(sorted);
    } on AppException catch (exception) {
      if (requests.isEmpty) {
        error.value = exception;
      } else {
        actionError.value = exception;
      }
    } catch (exception) {
      final mapped = AppException.from(exception);
      if (requests.isEmpty) {
        error.value = mapped;
      } else {
        actionError.value = mapped;
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<bool> cancel(PairingRequest request) async {
    if (isCancelling.value) return false;
    actionError.value = null;
    if (request.status != PairingRequestStatus.pendingChild ||
        request.isExpired) {
      actionError.value = const AppException(
        AppErrorCodes.validation,
        'Only a request that is still waiting for the child can be cancelled.',
      );
      return false;
    }
    if (!_connectivity.isOnline.value) {
      actionError.value = AppException.network();
      return false;
    }
    isCancelling.value = true;
    try {
      await _pairing.cancel(request.id);
      isCancelling.value = false;
      // Refresh from the server; no local status change is assumed.
      await _load(silent: true);
      return true;
    } on AppException catch (exception) {
      actionError.value = exception;
      return false;
    } catch (exception) {
      actionError.value = AppException.from(exception);
      return false;
    } finally {
      isCancelling.value = false;
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }
}
