import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';

class SupabaseService extends GetxService {
  bool _initialized = false;
  AppException? _initError;

  bool get isConfigured => Env.isBackendConfigured;
  bool get isReady => _initialized;
  AppException? get initError => _initError;

  Future<SupabaseService> init() async {
    if (!isConfigured) {
      _initError = AppException.backendNotConfigured();
      return this;
    }
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      _initialized = true;
      _initError = null;
    } catch (error) {
      _initError = const AppException(
        'backend_init_failed',
        'The Supabase client could not start. Check SUPABASE_URL and '
        'SUPABASE_ANON_KEY, then restart the app.',
      );
    }
    return this;
  }

  SupabaseClient get client {
    if (!_initialized) {
      throw _initError ?? AppException.backendNotConfigured();
    }
    return Supabase.instance.client;
  }

  User? get currentUser => _initialized ? client.auth.currentUser : null;
  Session? get currentSession => _initialized ? client.auth.currentSession : null;
  Stream<AuthState> get authStateChanges {
    if (!_initialized) return const Stream<AuthState>.empty();
    return client.auth.onAuthStateChange;
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await client.auth.signOut();
  }
}
