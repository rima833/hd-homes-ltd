import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/router/app_router.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_provider.dart';

/// Handles sign-in, sign-up, sign-out, and post-auth navigation.
class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    if (repository == null) return null;
    return repository.fetchCurrentProfile();
  }

  AuthRepository? get _repository => ref.read(authRepositoryProvider);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final repository = _repository;
    if (repository == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await repository.signInWithEmail(
        email: email,
        password: password,
      );
      _redirectAfterAuth(profile);
      return profile;
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final repository = _repository;
    if (repository == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await repository.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      return profile;
    });
  }

  Future<void> signOut() async {
    await _repository?.signOut();
    state = const AsyncData(null);
    ref.read(goRouterProvider).go('/');
  }

  Future<void> resetPassword(String email) async {
    final repository = _repository;
    if (repository == null) return;
    await repository.resetPassword(email);
  }

  void _redirectAfterAuth(UserProfile profile) {
    final role = profile.primaryRole;
    final route = role?.defaultRoute ?? '/';
    ref.read(goRouterProvider).go(route);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);
