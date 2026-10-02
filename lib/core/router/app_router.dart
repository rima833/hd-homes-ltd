import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/auth/auth.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/router/shell_routes.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_confirmation_link.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/routes/auth_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Stable GoRouter — never recreate on session/theme changes (avoids
/// Duplicate GlobalKey + `_dependents.isEmpty` crashes on web).
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: kIsWeb ? _browserInitialLocation() : RoutePaths.home,
    debugLogDiagnostics: kDebugMode && !kIsWeb,
    refreshListenable: refresh,
    redirect: (context, state) {
      final isSupabaseConfigured = ref.read(supabaseConfiguredProvider);
      final session = ref.read(identitySessionProvider);
      final location = state.matchedLocation;
      final decision = RouteAuthorization.evaluate(
        path: location,
        session: session,
        supabaseConfigured: isSupabaseConfigured,
      );

      if (!decision.allowed && decision.redirectLocation != null) {
        return decision.redirectLocation;
      }

      // Avoid thrashing while identity is still bootstrapping.
      if (session.status == AuthStatus.authenticating) {
        return null;
      }

      // Keep the confirmed-email screen on screen. A new session must not
      // bounce this page into MFA before the user sees the result.
      if (location == RoutePaths.verifyEmail) {
        return null;
      }

      if (session.isAuthenticated && location.startsWith(RoutePaths.investor)) {
        final role = session.primaryRole;
        if (role != null && !role.canAccessInvestorPortal) {
          return role.defaultRoute;
        }
      }

      if (session.isAuthenticated && location.startsWith(RoutePaths.client)) {
        final role = session.primaryRole;
        if (role != null && !role.canAccessClientPortal) {
          return role.defaultRoute;
        }
      }

      // MFA gate — resolve BEFORE portals so the dashboard never flashes.
      if (session.isAuthenticated) {
        final mfaAsync = ref.read(mfaStatusProvider);
        final holdingInvite =
            (state.uri.queryParameters['invite'] ?? '').trim().isNotEmpty &&
            (location == RoutePaths.login || location == RoutePaths.register);
        final mfaRedirect = _mfaPortalRedirect(
          location: location,
          session: session,
          mfaAsync: mfaAsync,
          preserveAuthRoute: holdingInvite,
        );
        if (mfaRedirect != null) return mfaRedirect;
      }

      return null;
    },
    routes: [
      publicShellRoute,
      ...authRoutes,
      adminShellRoute,
      clientShellRoute,
      investorShellRoute,
    ],
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorWidget(
        message: 'We could not find that page.',
        retryLabel: 'Go to Home',
        onRetry: () => context.go('/'),
      ),
    ),
  );
});

/// Keeps `?invite=` on the first web load. Path-only initial locations drop it.
String _browserInitialLocation() {
  final confirmedLanding = AuthConfirmationLink.launch?.verifyEmailLocation();
  if (confirmedLanding != null) return confirmedLanding;

  final uri = Uri.base;
  var path = uri.path;
  if (path.isEmpty || path == '/') return RoutePaths.home;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!uri.hasQuery) return path;
  return '$path?${uri.query}';
}

String? _mfaPortalRedirect({
  required String location,
  required AuthSessionSnapshot session,
  required AsyncValue<MfaStatusSnapshot> mfaAsync,
  bool preserveAuthRoute = false,
}) {
  if (!session.isAuthenticated) return null;

  final onMfaFlow =
      location.startsWith(RoutePaths.mfaSetup) ||
      location.startsWith(RoutePaths.mfaChallenge);
  final onLogin =
      location == RoutePaths.login || location == RoutePaths.register;

  final protected =
      location.startsWith(RoutePaths.dashboard) ||
      location.startsWith(RoutePaths.client) ||
      location.startsWith(RoutePaths.investor);

  // While MFA status is still loading, do NOT bounce protected routes to the
  // challenge screen — that caused a spinner loop after successful verify
  // (dashboard → challenge → dashboard). Login already navigates to MFA first;
  // hard refresh waits for status then redirects via needsChallenge below.
  final mfaReady =
      mfaAsync.hasValue && (mfaAsync.valueOrNull?.statusKnown ?? false);
  if (!mfaReady) {
    return null;
  }

  final mfa = mfaAsync.requireValue;

  if (mfa.needsSetup) {
    if (onMfaFlow && location.startsWith(RoutePaths.mfaSetup)) return null;
    final dest = protected
        ? location
        : (session.primaryRole?.defaultRoute ?? RoutePaths.home);
    final enc = Uri.encodeComponent(dest);
    return '${RoutePaths.mfaSetup}?required=1&redirect=$enc';
  }

  if (mfa.needsChallenge) {
    if (onMfaFlow && location.startsWith(RoutePaths.mfaChallenge)) {
      return null;
    }
    final dest = protected
        ? location
        : (session.primaryRole?.defaultRoute ?? RoutePaths.home);
    final enc = Uri.encodeComponent(dest);
    return '${RoutePaths.mfaChallenge}?redirect=$enc';
  }

  // MFA clear — leave login for the role home.
  // Invite links must stay on login/register so acceptance can finish.
  if (onLogin) {
    if (preserveAuthRoute) return null;
    return session.primaryRole?.defaultRoute ?? RoutePaths.home;
  }

  return null;
}

/// Notifies GoRouter when auth-relevant identity / MFA gate fields change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<AuthSessionSnapshot>(identitySessionProvider, (previous, next) {
      // Ignore authenticating flicker (bootstrap / token refresh) — it caused
      // the whole dashboard shell to rebuild/blink.
      if (next.status == AuthStatus.authenticating &&
          previous?.status == AuthStatus.authenticated &&
          previous?.userId == next.userId) {
        return;
      }
      if (previous?.status == next.status &&
          previous?.userId == next.userId &&
          previous?.emailConfirmed == next.emailConfirmed &&
          previous?.primaryRole == next.primaryRole &&
          previous?.permissions == next.permissions) {
        return;
      }
      notifyListeners();
    });
    _ref.listen(mfaStatusProvider, (previous, next) {
      final prevGate = _mfaGateKey(previous);
      final nextGate = _mfaGateKey(next);
      if (prevGate == nextGate) return;
      notifyListeners();
    });
  }

  final Ref _ref;

  static String _mfaGateKey(AsyncValue<MfaStatusSnapshot>? async) {
    if (async == null) return 'none';
    if (!async.hasValue) return 'loading';
    final s = async.valueOrNull;
    if (s == null) return 'loading';
    return '${s.statusKnown}|${s.needsSetup}|${s.needsChallenge}|${s.enabled}|${s.currentDeviceTrusted}';
  }
}
