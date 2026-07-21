import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/auth/auth.dart';
import 'package:hdhomesproject/core/config/supabase_config.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hdhomesproject/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  if (dataSource == null) return null;
  return AuthRepositoryImpl(dataSource);
});

final permissionEngineProvider = Provider<PermissionEngine>((ref) {
  return const PermissionEngine();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return SecurityService(configured ? ref.watch(supabaseClientProvider) : null);
});

final sessionServiceProvider = Provider<SessionService?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final auth = ref.watch(supabaseClientProvider).auth;
  final service = SessionService(auth: auth);
  service.onInactivityWarning = () {
    ref.read(identitySessionProvider.notifier).onInactivityWarning();
  };
  service.onInactivityTimeout = () {
    unawaited(ref.read(identitySessionProvider.notifier).signOut(reason: 'inactivity'));
  };
  ref.onDispose(service.stopMonitoring);
  return service;
});

final tokenServiceProvider = Provider<TokenService?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return TokenService(ref.watch(supabaseClientProvider).auth);
});

/// Whether Supabase auth is available in this build.
final isAuthAvailableProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured;
});

/// Global Identity Platform session — single source of truth for auth UI & guards.
final identitySessionProvider =
    NotifierProvider<IdentitySessionNotifier, AuthSessionSnapshot>(
  IdentitySessionNotifier.new,
);

class IdentitySessionNotifier extends Notifier<AuthSessionSnapshot> {
  StreamSubscription<AuthState>? _authSub;
  bool _inactivityWarning = false;

  @override
  AuthSessionSnapshot build() {
    ref.onDispose(() {
      _authSub?.cancel();
      ref.read(sessionServiceProvider)?.stopMonitoring();
    });

    final repository = ref.watch(authRepositoryProvider);
    if (repository == null) {
      return AuthSessionSnapshot.empty;
    }

    // Do not assign [state] during build — that notifies listeners mid-tree rebuild.
    unawaited(_bootstrap(repository));

    final dataSource = ref.read(authRemoteDataSourceProvider);
    _authSub?.cancel();
    _authSub = dataSource?.authStateChanges.listen((event) {
      unawaited(_onAuthEvent(event, repository));
    });

    return const AuthSessionSnapshot(status: AuthStatus.authenticating);
  }

  Future<void> _bootstrap(AuthRepository repository) async {
    try {
      final profile = await repository.fetchCurrentProfile();
      state = _snapshotFromProfile(
        profile,
        permissions: repository.currentPermissions,
      );
      if (profile != null) {
        ref.read(sessionServiceProvider)?.startMonitoring();
      }
    } catch (_) {
      state = AuthSessionSnapshot.empty;
    }
  }

  Future<void> _onAuthEvent(AuthState event, AuthRepository repository) async {
    final session = event.session;
    if (session == null) {
      ref.read(sessionServiceProvider)?.stopMonitoring();
      state = AuthSessionSnapshot.empty;
      return;
    }

    state = state.copyWith(status: AuthStatus.authenticating);
    final profile = await repository.fetchCurrentProfile();
    state = _snapshotFromProfile(
      profile,
      permissions: repository.currentPermissions,
      session: session,
    );
    ref.read(sessionServiceProvider)?.startMonitoring();
  }

  AuthSessionSnapshot _snapshotFromProfile(
    UserProfile? profile, {
    Set<String> permissions = const {},
    Session? session,
  }) {
    final engine = ref.read(permissionEngineProvider);
    final hasSession = profile != null;
    final status = resolveAuthStatus(
      hasSession: hasSession,
      isLoading: false,
      accountStatus: profile?.accountStatus,
      emailConfirmed: profile?.emailConfirmed ?? true,
    );

    final expiresAt = session?.expiresAt == null
        ? ref.read(tokenServiceProvider)?.accessTokenExpiresAt
        : DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000);

    var snapshot = AuthSessionSnapshot(
      status: status,
      userId: profile?.id,
      email: profile?.email,
      emailConfirmed: profile?.emailConfirmed ?? false,
      profile: profile,
      permissions: permissions,
      accessTokenExpiresAt: expiresAt,
      lastActivityAt: DateTime.now(),
      sessionId: session?.accessToken.hashCode.toString(),
    );

    if (permissions.isEmpty && profile != null) {
      snapshot = engine.attachPermissions(snapshot);
    } else {
      snapshot = engine.attachPermissions(snapshot, fromServer: permissions);
    }
    return snapshot;
  }

  void onInactivityWarning() {
    _inactivityWarning = true;
  }

  bool get showInactivityWarning => _inactivityWarning;

  void clearInactivityWarning() {
    _inactivityWarning = false;
    ref.read(sessionServiceProvider)?.recordActivity();
  }

  void recordActivity() {
    ref.read(sessionServiceProvider)?.recordActivity();
    state = state.copyWith(lastActivityAt: DateTime.now());
  }

  Future<void> refreshPermissions() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository == null || state.profile == null) return;
    final perms = await repository.refreshPermissions();
    state = ref.read(permissionEngineProvider).attachPermissions(
          state,
          fromServer: perms,
        );
  }

  /// Reloads business profile from PostgreSQL (e.g. after Profile Center edits).
  Future<void> reloadProfile() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    try {
      final profile = await repository.fetchCurrentProfile();
      state = _snapshotFromProfile(
        profile,
        permissions: repository.currentPermissions,
      );
    } catch (_) {}
  }

  Future<void> refreshSessionIfNeeded() async {
    final sessionService = ref.read(sessionServiceProvider);
    if (sessionService == null) return;
    final updated = await sessionService.refreshIfNeeded(state);
    if (updated != null) state = updated;
  }

  Future<void> signOut({bool everywhere = false, String? reason}) async {
    final repository = ref.read(authRepositoryProvider);
    final security = ref.read(securityServiceProvider);
    security.recordLogout(userId: state.userId);
    if (reason != null) {
      security.record(
        SecurityEvent(
          type: SecurityEventType.sessionRevoked,
          timestamp: DateTime.now(),
          userId: state.userId,
          metadata: {'reason': reason},
        ),
      );
    }
    await repository?.signOut(everywhere: everywhere);
    ref.read(sessionServiceProvider)?.stopMonitoring();
    state = AuthSessionSnapshot.empty;
  }
}

/// Compatibility stream used by GoRouter refresh / legacy consumers.
final authStateProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final snapshot = ref.watch(identitySessionProvider);
  if (snapshot.status == AuthStatus.authenticating) {
    return const AsyncLoading();
  }
  if (snapshot.profile == null) {
    return const AsyncData(null);
  }
  return AsyncData(snapshot.profile);
});

final currentUserProvider = Provider<UserProfile?>((ref) {
  return ref.watch(identitySessionProvider).profile;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(identitySessionProvider).isAuthenticated;
});

final currentPermissionsProvider = Provider<Set<String>>((ref) {
  return ref.watch(identitySessionProvider).permissions;
});

final hasPermissionProvider = Provider.family<bool, String>((ref, slug) {
  return ref.watch(identitySessionProvider).hasPermission(slug);
});
