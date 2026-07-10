import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';

/// SEO engine extensions — sitemap, robots, and programmatic SEO helpers.
abstract final class SeoEngine {
  static const publicRoutes = [
    RoutePaths.home,
    RoutePaths.about,
    RoutePaths.properties,
    RoutePaths.estates,
    RoutePaths.services,
    RoutePaths.blog,
    RoutePaths.gallery,
    RoutePaths.trust,
    RoutePaths.contact,
    RoutePaths.bookInspection,
    RoutePaths.search,
    RoutePaths.investment,
    RoutePaths.careers,
  ];

  static String robotsTxt() => '''
User-agent: *
Allow: /

Sitemap: ${SeoConfig.siteUrl}/sitemap.xml
''';

  static List<String> sitemapUrls() {
    final base = SeoConfig.siteUrl;
    return publicRoutes.map((r) => '$base${r == '/' ? '' : r}').toList();
  }

  static String sitemapXml() {
    final urls = sitemapUrls();
    final entries = urls
        .map(
          (url) => '''
  <url>
    <loc>$url</loc>
    <changefreq>weekly</changefreq>
    <priority>${url.endsWith('/') || url.endsWith('.ng') ? '1.0' : '0.8'}</priority>
  </url>''',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$entries
</urlset>''';
  }

  static SeoMetadata forProperty(String title, String description, {String? imageUrl}) =>
      SeoMetadata.propertyDetail(title, description).copyWithOgImage(imageUrl);

  static SeoMetadata forCityLanding(String city, String description) => SeoMetadata(
        title: 'Properties in $city | HD Homes',
        description: description,
        keywords: ['$city properties', '$city real estate', 'HD Homes $city'],
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'RealEstateListing',
          'name': 'HD Homes — $city',
          'description': description,
        },
      );
}

extension SeoMetadataOg on SeoMetadata {
  SeoMetadata copyWithOgImage(String? imageUrl) => SeoMetadata(
        title: title,
        description: description,
        canonicalUrl: canonicalUrl,
        ogImageUrl: imageUrl ?? ogImageUrl,
        keywords: keywords,
        robots: robots,
        structuredData: structuredData,
      );
}
