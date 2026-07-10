import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/supabase_config.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hdhomesproject/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  if (dataSource == null) return null;
  return AuthRepositoryImpl(dataSource);
});

/// Stream of the current authenticated user profile.
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return const Stream.empty();
  return repository.authStateChanges();
});

/// Synchronous access to current profile (may be null while loading).
final currentUserProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Whether Supabase auth is available in this build.
final isAuthAvailableProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured;
});
