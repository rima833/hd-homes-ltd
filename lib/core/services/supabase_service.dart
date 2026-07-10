import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseClientProvider));
});

/// Centralized Supabase communication layer.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;
  SupabaseStorageClient get storage => _client.storage;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signOut() async {
    AppLogger.info('Signing out user');
    await _client.auth.signOut();
  }
}
