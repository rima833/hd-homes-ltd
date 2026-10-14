import 'package:hdhomesproject/core/constants/route_paths.dart';

/// Crawl/index rules for public vs authenticated surfaces.
abstract final class PublicSeoPolicy {
  /// Paths that must never be treated as primary index targets.
  static const _noIndexPrefixes = <String>[
    RoutePaths.dashboard,
    RoutePaths.client,
    RoutePaths.investor,
    '/account',
    '/mfa',
    RoutePaths.authCallback,
  ];

  static const _noIndexExact = <String>{
    RoutePaths.login,
    RoutePaths.register,
    RoutePaths.forgotPassword,
    RoutePaths.resetPassword,
    RoutePaths.verifyEmail,
    RoutePaths.welcome,
    RoutePaths.trust,
    RoutePaths.bookConsultation,
  };

  /// Robots.txt disallow lines (relative paths, no host).
  static const robotsDisallowPaths = <String>[
    '/dashboard',
    '/dashboard/',
    '/client',
    '/client/',
    '/investor',
    '/investor/',
    '/account',
    '/account/',
    '/mfa',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/verify-email',
    '/welcome',
    '/auth/',
    '/trust',
  ];

  static String normalizePath(String path) {
    var p = path.trim();
    if (p.isEmpty) return RoutePaths.home;
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  static bool shouldNoIndex(String path) {
    final p = normalizePath(path);
    if (_noIndexExact.contains(p)) return true;
    for (final prefix in _noIndexPrefixes) {
      if (p == prefix || p.startsWith('$prefix/')) return true;
    }
    return false;
  }

  static String robotsForPath(String path) {
    if (shouldNoIndex(path)) return 'noindex, nofollow';
    return 'index, follow';
  }

  static bool isSitemapEligible(String path) {
    if (shouldNoIndex(path)) return false;
    if (path.contains('?')) return false;
    return true;
  }
}
