import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/auth/models/auth_status.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Result of evaluating whether a navigation target is allowed.
class RouteAuthDecision {
  const RouteAuthDecision.allow()
      : allowed = true,
        redirectLocation = null,
        reason = null;

  const RouteAuthDecision.redirect(this.redirectLocation, {this.reason})
      : allowed = false;

  final bool allowed;
  final String? redirectLocation;
  final String? reason;
}

/// Dynamic route authorization — roles/permissions, not hardcoded page lists.
abstract final class RouteAuthorization {
  static bool isPublicPath(String path) {
    if (path == RoutePaths.home || path.isEmpty) return true;
    if (RoutePaths.authRoutes.contains(path)) return true;
    const publicExact = {
      RoutePaths.about,
      RoutePaths.properties,
      RoutePaths.estates,
      RoutePaths.investment,
      RoutePaths.services,
      RoutePaths.blog,
      RoutePaths.gallery,
      RoutePaths.trust,
      RoutePaths.careers,
      RoutePaths.contact,
      RoutePaths.bookInspection,
      RoutePaths.search,
    };
    if (publicExact.contains(path)) return true;
    if (path.startsWith('${RoutePaths.properties}/')) return true;
    if (path.startsWith('${RoutePaths.estates}/')) return true;
    if (path.startsWith('${RoutePaths.services}/')) return true;
    if (path.startsWith('${RoutePaths.blog}/')) return true;
    if (path.startsWith('${RoutePaths.gallery}/')) return true;
    return false;
  }

  static bool isProtectedPath(String path) {
    return RoutePaths.protectedPrefixes.any((p) => path.startsWith(p));
  }

  static RouteAuthDecision evaluate({
    required String path,
    required AuthSessionSnapshot session,
    required bool supabaseConfigured,
  }) {
    final isAuthRoute = RoutePaths.authRoutes.contains(path);
    final isProtected = isProtectedPath(path);

    if (!supabaseConfigured && isProtected) {
      return RouteAuthDecision.redirect(
        RoutePaths.login,
        reason: 'Authentication service unavailable',
      );
    }

    if (session.status == AuthStatus.authenticating && isProtected) {
      return const RouteAuthDecision.allow();
    }

    if (session.status.isTerminalBlocked) {
      if (isProtected || isAuthRoute) {
        return RouteAuthDecision.redirect(
          RoutePaths.login,
          reason: session.status.userMessage,
        );
      }
      return const RouteAuthDecision.allow();
    }

    if (session.status == AuthStatus.emailPending && isProtected) {
      return RouteAuthDecision.redirect(
        '${RoutePaths.verifyEmail}?email=${Uri.encodeComponent(session.profile?.email ?? '')}',
        reason: AuthStatus.emailPending.userMessage,
      );
    }

    if (isProtected && !session.isAuthenticated) {
      return RouteAuthDecision.redirect(
        '${RoutePaths.login}?redirect=${Uri.encodeComponent(path)}',
        reason: AuthStatus.unauthenticated.userMessage,
      );
    }

    // MFA challenge requires an authenticated session.
    if (path == RoutePaths.mfaChallenge && !session.isAuthenticated) {
      return RouteAuthDecision.redirect(
        RoutePaths.login,
        reason: AuthStatus.unauthenticated.userMessage,
      );
    }

    if (session.isAuthenticated && isAuthRoute) {
      // Allow password recovery and MFA challenge while session is active.
      if (path == RoutePaths.resetPassword ||
          path == RoutePaths.mfaChallenge) {
        return const RouteAuthDecision.allow();
      }
      return RouteAuthDecision.redirect(
        _homeForSession(session),
        reason: 'Already signed in',
      );
    }

    if (session.isAuthenticated && path.startsWith(RoutePaths.dashboard)) {
      final role = session.primaryRole;
      if (role != null && !role.canAccessDashboard && !role.isStaff) {
        return RouteAuthDecision.redirect(
          role.defaultRoute,
          reason: 'Insufficient role for admin dashboard',
        );
      }
    }

    if (session.isAuthenticated && path.startsWith(RoutePaths.investor)) {
      if (!session.isInvestor && !session.isStaff && session.primaryRole != AppRole.client) {
        // Clients may access investor portal when linked; staff always can.
        // Default: allow client + investor + staff (portal stubs for Volume 3+).
      }
    }

    return const RouteAuthDecision.allow();
  }

  static String _homeForSession(AuthSessionSnapshot session) {
    return session.primaryRole?.defaultRoute ?? RoutePaths.home;
  }

  /// Whether the session may perform an action gated by [permissionSlug].
  static bool canPerform(AuthSessionSnapshot session, String permissionSlug) {
    if (!session.isAuthenticated) return false;
    if (session.hasRole(AppRole.superAdmin)) return true;
    return session.hasPermission(permissionSlug);
  }
}
