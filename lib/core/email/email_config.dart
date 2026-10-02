import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/email/email_models.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads public-safe email brand + site URL for Auth redirects.
///
/// **Local development (default in debug Flutter web):**
/// Uses the live browser origin (`http://localhost:<port>/verify-email`) so
/// Confirm returns into the running app. Open the email link on the **same PC**
/// where Flutter is running — phones cannot open localhost.
///
/// **Production (release / after deploy):**
/// Uses `https://hdhomesltd.com/verify-email`.
///
/// Optional overrides:
/// - `AUTH_REDIRECT_ORIGIN`
/// - `AUTH_VERIFIED_LANDING_URL`
class EmailConfig {
  EmailConfig(this._client);

  final SupabaseClient? _client;

  static const String productionSiteFallback = 'https://hdhomesltd.com';

  /// Pinned local port recommended for Supabase Site URL while developing.
  /// Start Flutter with: `flutter run -d chrome --web-port=56512`
  static const int recommendedLocalWebPort = 56512;

  /// Optional override for Auth email origin (must be reachable where the
  /// email is opened).
  static const String redirectOriginOverride = String.fromEnvironment(
    'AUTH_REDIRECT_ORIGIN',
    defaultValue: '',
  );

  /// Optional full landing URL after Auth email confirmation / recovery.
  static const String verifiedLandingOverride = String.fromEnvironment(
    'AUTH_VERIFIED_LANDING_URL',
    defaultValue: '',
  );

  /// Force local browser origin even outside [kDebugMode] (same-PC testing).
  static const bool useLocalOriginForAuthEmails = bool.fromEnvironment(
    'AUTH_EMAIL_USE_LOCAL_ORIGIN',
    defaultValue: false,
  );

  Future<EmailBrandConfig> loadBrand() async {
    final client = _client;
    if (client == null) return const EmailBrandConfig();
    try {
      final row = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'email_brand')
          .maybeSingle();
      if (row == null) return const EmailBrandConfig();
      final value = row['value'];
      return EmailBrandConfig.fromJson(
        value is Map ? Map<String, dynamic>.from(value) : null,
      );
    } catch (_) {
      return const EmailBrandConfig();
    }
  }

  /// Public site URL from Platform Control → SEO, then brand, then fallback.
  Future<String> loadSiteUrl({String? fallback}) async {
    final resolvedFallback = fallback ??
        (SeoConfig.siteUrl.trim().isNotEmpty
            ? SeoConfig.siteUrl
            : productionSiteFallback);
    final client = _client;
    if (client == null) {
      return _stripTrailingSlash(resolvedFallback);
    }
    try {
      final row = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'seo')
          .maybeSingle();
      final value = row?['value'];
      if (value is Map) {
        final siteUrl = '${value['site_url'] ?? ''}'.trim();
        if (siteUrl.isNotEmpty && !isLocalDevOrigin(siteUrl)) {
          return _stripTrailingSlash(siteUrl);
        }
      }
    } catch (_) {}
    final brand = await loadBrand();
    if (brand.websiteUrl.trim().isNotEmpty &&
        !isLocalDevOrigin(brand.websiteUrl)) {
      return _stripTrailingSlash(brand.websiteUrl);
    }
    return _stripTrailingSlash(resolvedFallback);
  }

  /// Origin for Auth emails / transactional CTAs.
  Future<String> authOrigin() async {
    final override = redirectOriginOverride.trim();
    if (override.isNotEmpty) {
      return _stripTrailingSlash(override);
    }

    // Local Flutter web (debug by default): return into the running app.
    if (kIsWeb && (kDebugMode || useLocalOriginForAuthEmails)) {
      final origin = Uri.base.origin.trim();
      if (origin.isNotEmpty &&
          origin != 'null' &&
          !origin.toLowerCase().startsWith('file:') &&
          isLocalDevOrigin(origin)) {
        return _stripTrailingSlash(origin);
      }
    }

    final site = await loadSiteUrl();
    if (!isLocalDevOrigin(site)) {
      return site;
    }
    return productionSiteFallback;
  }

  /// Landing after Supabase confirms the email / recovery token.
  Future<String> authVerifiedLandingUrl() async {
    final override = verifiedLandingOverride.trim();
    if (override.isNotEmpty) return override;

    final base = await authOrigin();
    // Always path-style Flutter route (works with usePathUrlStrategy).
    if (isLocalDevOrigin(base)) {
      return '$base/verify-email';
    }
    // After Flutter is deployed on the domain:
    return '$productionSiteFallback/verify-email';
  }

  /// Builds Auth `emailRedirectTo` / `redirectTo`.
  Future<String> authRedirect(String routePath) async {
    final path = _normalizePath(routePath);
    if (path == '/verify-email' || path == '/auth/callback') {
      return authVerifiedLandingUrl();
    }
    if (path == '/reset-password') {
      final base = await authOrigin();
      return '$base/reset-password';
    }
    final base = await authOrigin();
    return '$base$path';
  }

  /// Public CTA origin. Localhost is never used for mailed links.
  static String composeActionUrl(String site, String path) {
    final base = isLocalDevOrigin(site)
        ? productionSiteFallback
        : _stripTrailingSlash(site.isEmpty ? productionSiteFallback : site);
    final raw = path.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (!isLocalDevOrigin(raw)) return raw;
      final uri = Uri.parse(raw);
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '$base${uri.path}$query';
    }
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return '$base$normalized';
  }

  static String _normalizePath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return '/';
    if (path.startsWith('/#')) {
      path = path.substring(2);
    } else if (path.startsWith('#')) {
      path = path.substring(1);
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    path = path.replaceFirst(RegExp(r'^/+'), '/');
    return path;
  }

  static String _stripTrailingSlash(String url) =>
      url.replaceAll(RegExp(r'/+$'), '');

  /// True when [url] points at a local Flutter web origin.
  static bool isLocalDevOrigin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}
