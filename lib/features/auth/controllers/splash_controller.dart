import 'dart:async';

import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

/// Decides the first destination from real auth/profile/family state.
class SplashController extends GetxController {
  SplashController({
    required this._supabase,
    required AuthRepository authRepository,
    required FamilyRepository familyRepository,
    required SessionService session,
    required LocalSettingsService settings,
    required this._connectivity,
  })  : _auth = authRepository,
        _flow = AuthSessionFlow(
          authRepository: authRepository,
          familyRepository: familyRepository,
          session: session,
          settings: settings,
        );

  final SupabaseService _supabase;
  final AuthRepository _auth;
  final ConnectivityService _connectivity;
  final AuthSessionFlow _flow;

  final RxBool isResolving = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  StreamSubscription<void>? _authSubscription;
  Worker? _connectivityWorker;
  bool _hasNavigated = false;
  bool _disposed = false;

  bool get isOnline => _connectivity.isOnline.value;

  @override
  void onInit() {
    super.onInit();
    _connectivityWorker = ever<bool>(_connectivity.isOnline, (online) {
      if (online && !_hasNavigated && error.value != null) {
        unawaited(resolve());
      }
    });
    _authSubscription = _auth.authChanges.listen(
      (_) {
        if (!_hasNavigated) unawaited(resolve());
      },
      onError: (Object streamError, StackTrace stackTrace) {
        if (!_hasNavigated) {
          error.value = AppException.from(streamError);
        }
      },
    );
    unawaited(resolve());
  }

  Future<void> resolve() async {
    if (_disposed || _hasNavigated || isResolving.value) return;
    isResolving.value = true;
    error.value = null;
    try {
      if (!_supabase.isConfigured) {
        await _leave();
        Get.offAllNamed(AppRoutes.configuration);
        return;
      }
      if (!_supabase.isReady) {
        error.value =
            _supabase.initError ?? AppException.backendNotConfigured();
        return;
      }
      if (!_connectivity.isOnline.value) {
        error.value = AppException.network();
        return;
      }
      final destination = await _flow.resolve();
      if (_disposed || _hasNavigated) return;
      final email = _auth.currentEmail ?? '';
      await _leave();
      openDestination(destination, email: email);
    } on AppException catch (exception) {
      error.value = exception;
    } catch (exception) {
      error.value = AppException.from(exception);
    } finally {
      isResolving.value = false;
    }
  }

  Future<void> retry() => resolve();

  Future<void> _leave() async {
    _hasNavigated = true;
    final subscription = _authSubscription;
    _authSubscription = null;
    await subscription?.cancel();
  }

  @override
  void onClose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    _connectivityWorker?.dispose();
    _connectivityWorker = null;
    super.onClose();
  }
}
