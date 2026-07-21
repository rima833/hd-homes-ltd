import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';

/// Smart Login Router™ — picks the most relevant post-auth destination.
///
/// Priority:
/// 1. Account status resolution flows (verify email, suspended, etc.)
/// 2. Safe deep-link `redirect` (same-origin relative path only)
/// 3. Pending actions (e.g. KYC / incomplete profile)
/// 4. Role-based default dashboard
abstract final class SmartLoginRouter {
  static const _blockedPrefixes = [
    '//',
    'http:',
    'https:',
    'javascript:',
  ];

  /// Returns a path suitable for `GoRouter.go`.
  static String resolve(SmartLoginContext context) {
    final profile = context.profile;
    final status = profile.status;

    if (!profile.emailConfirmed || status == AccountStatus.pendingVerification) {
      final email = Uri.encodeComponent(profile.email);
      final type = profile.primaryRole == AppRole.investor ? 'investor' : 'client';
      return '${RoutePaths.verifyEmail}?email=$email&type=$type';
    }

    if (status == AccountStatus.suspended ||
        status == AccountStatus.inactive ||
        status == AccountStatus.deleted) {
      return RoutePaths.login;
    }

    final safeRedirect = sanitizeRedirect(context.redirectPath);
    if (safeRedirect != null) {
      return safeRedirect;
    }

    if (context.pendingKyc && profile.primaryRole == AppRole.investor) {
      // Investor KYC screen lands in Volume 3+; portal is the holding surface.
      return RoutePaths.investor;
    }

    if (!context.profileComplete) {
      return profile.primaryRole == AppRole.investor
          ? RoutePaths.investorSettings
          : RoutePaths.clientSettings;
    }

    return destinationForRole(profile.primaryRole);
  }

  static String destinationForRole(AppRole? role) {
    return role?.defaultRoute ?? RoutePaths.home;
  }

  /// Accepts only relative same-app paths under known prefixes.
  static String? sanitizeRedirect(String? raw) {
    if (raw == null) return null;
    final path = Uri.decodeComponent(raw.trim());
    if (path.isEmpty || !path.startsWith('/')) return null;
    final lower = path.toLowerCase();
    for (final blocked in _blockedPrefixes) {
      if (lower.startsWith(blocked)) return null;
    }
    // Disallow auth bounce loops
    if (RoutePaths.authRoutes.any((r) => path == r || path.startsWith('$r?'))) {
      return null;
    }
    if (path.startsWith(RoutePaths.mfaSetup)) {
      return null;
    }
    return path;
  }
}
