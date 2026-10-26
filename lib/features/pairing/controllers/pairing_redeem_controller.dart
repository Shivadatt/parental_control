import 'package:get/get.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';

/// Parent-side redemption. The request shown always comes from the server; the
/// screen never approves a child on the parent's behalf.
class PairingRedeemController extends GetxController {
  PairingRedeemController({
    required PairingRepository pairingRepository,
    required this._connectivity,
  })  : _pairing = pairingRepository;

  final PairingRepository _pairing;
  final ConnectivityService _connectivity;

  final RxBool isRedeeming = false.obs;
  final RxBool isCheckingStatus = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();
  final Rxn<PairingRequest> request = Rxn<PairingRequest>();

  String _familyId = '';

  String get familyId => _familyId;
  bool get isOnline => _connectivity.isOnline.value;
  bool get hasRequest => request.value != null;

  void start(String? familyId) {
    _familyId = familyId?.trim() ?? '';
    error.value = null;
    request.value = null;
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'Open this screen from a family before redeeming a code.',
      );
    }
  }

  void clearError() => error.value = null;

  void reset() {
    request.value = null;
    error.value = null;
  }

  Future<bool> redeem(String code) async {
    if (isRedeeming.value) return false;
    error.value = null;
    if (_familyId.isEmpty) {
      error.value = const AppException(
        AppErrorCodes.validation,
        'Open this screen from a family before redeeming a code.',
      );
      return false;
    }
    final normalized = Validators.normalizePairingCode(code);
    final problem = Validators.pairingCode(normalized);
    if (problem != null) {
      error.value = AppException(AppErrorCodes.validation, problem);
      return false;
    }
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return false;
    }

    isRedeeming.value = true;
    request.value = null;
    try {
      final redeemed = await _pairing.redeemLinkingCode(
        code: normalized,
        familyId: _familyId,
      );
      request.value = redeemed;
      return true;
    } on AppException catch (exception) {
      error.value = exception;
      return false;
    } catch (exception) {
      error.value = AppException.from(exception);
      return false;
    } finally {
      isRedeeming.value = false;
    }
  }

  Future<void> checkStatus() async {
    final current = request.value;
    if (current == null || isCheckingStatus.value || _familyId.isEmpty) return;
    error.value = null;
    if (!_connectivity.isOnline.value) {
      error.value = AppException.network();
      return;
    }
    isCheckingStatus.value = true;
    try {
      final requests = await _pairing.fetchForFamily(_familyId);
      PairingRequest? latest;
      for (final candidate in requests) {
        if (candidate.id == current.id) {
          latest = candidate;
          break;
        }
      }
      if (latest == null) {
        error.value = const AppException(
          AppErrorCodes.notFound,
          'The server did not return this pairing request. Open the pairing '
          'requests list to see its current state.',
        );
        return;
      }
      request.value = latest;
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isCheckingStatus.value = false;
    }
  }
}
