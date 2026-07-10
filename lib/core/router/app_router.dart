import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/router/shell_routes.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/routes/auth_routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final isSupabaseConfigured = ref.watch(supabaseConfiguredProvider);
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = RoutePaths.authRoutes.contains(location);

      final isProtected = RoutePaths.protectedPrefixes.any(
        (prefix) => location.startsWith(prefix),
      );

      if (!isSupabaseConfigured && isProtected) {
        AppLogger.warning('Protected route without Supabase: $location');
        return RoutePaths.login;
      }

      final user = authState.valueOrNull;
      final isAuthenticated = user != null;

      if (isProtected && !isAuthenticated) {
        return '${RoutePaths.login}?redirect=${Uri.encodeComponent(location)}';
      }

      if (isAuthenticated && isAuthRoute) {
        return user.primaryRole?.defaultRoute ?? RoutePaths.home;
      }

      if (isAuthenticated && location.startsWith(RoutePaths.dashboard)) {
        final role = user.primaryRole;
        if (role != null && !role.canAccessDashboard && !role.isStaff) {
          return RoutePaths.client;
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
