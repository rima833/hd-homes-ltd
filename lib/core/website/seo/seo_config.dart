/// Public site URL for canonical links and Open Graph.
abstract final class SeoConfig {
  static const siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://hdhomes.ng',
  );

  static String canonicalFor(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$siteUrl$normalized';
  }
}
