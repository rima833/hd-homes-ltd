import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/auth/auth.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/router/shell_routes.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/routes/auth_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Stable GoRouter — never recreate on session/theme changes (avoids
/// Duplicate GlobalKey + `_dependents.isEmpty` crashes on web).
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.home,
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
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

/// Notifies GoRouter when auth-relevant identity fields change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<AuthSessionSnapshot>(identitySessionProvider, (previous, next) {
      if (previous?.status == next.status &&
          previous?.userId == next.userId &&
          previous?.emailConfirmed == next.emailConfirmed &&
          previous?.primaryRole == next.primaryRole) {
        return;
      }
      notifyListeners();
    });
  }

  final Ref _ref;
}
