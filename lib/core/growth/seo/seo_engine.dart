import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/seo/public_seo_policy.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';

/// SEO engine extensions — sitemap, robots, and programmatic SEO helpers.
abstract final class SeoEngine {
  static const publicRoutes = [
    RoutePaths.home,
    RoutePaths.about,
    RoutePaths.properties,
    RoutePaths.paymentCalculator,
    RoutePaths.estates,
    RoutePaths.services,
    RoutePaths.blog,
    RoutePaths.gallery,
    RoutePaths.contact,
    RoutePaths.bookInspection,
    RoutePaths.search,
    RoutePaths.investment,
    RoutePaths.roiCalculator,
    RoutePaths.careers,
    RoutePaths.construction,
    '/pages/privacy',
    '/pages/terms',
    '/pages/cookies',
    '/pages/refund-policy',
  ];

  static String robotsTxt() {
    final disallow = PublicSeoPolicy.robotsDisallowPaths
        .map((p) => 'Disallow: $p')
        .join('\n');
    return '''
User-agent: *
Allow: /
$disallow

Sitemap: ${SeoConfig.siteUrl}/sitemap.xml''';
  }

  static List<String> sitemapUrls() {
    final base = SeoConfig.siteUrl;
    return publicRoutes
        .where(PublicSeoPolicy.isSitemapEligible)
        .map((r) => '$base${r == '/' ? '' : r}')
        .toList();
  }

  static String sitemapXml({List<String> extraUrls = const []}) {
    final seen = <String>{};
    final urls = <String>[
      for (final url in [...sitemapUrls(), ...extraUrls])
        if (seen.add(url)) url,
    ];

    String priorityFor(String url) {
      if (url.endsWith('/') || url == SeoConfig.siteUrl) return '1.0';
      if (url.contains('/properties/') ||
          url.contains('/estates/') ||
          url.contains('/blog/')) {
        return '0.7';
      }
      if (url.contains('/properties') ||
          url.contains('/estates') ||
          url.contains('/investment')) {
        return '0.9';
      }
      return '0.8';
    }

    String changefreqFor(String url) {
      if (url.contains('/blog/')) return 'monthly';
      if (url.contains('/properties/') || url.contains('/estates/')) {
        return 'weekly';
      }
      if (url.contains('/properties') || url.contains('/blog')) {
        return 'daily';
      }
      return 'weekly';
    }

    final entries = urls
        .map(
          (url) => '''
  <url>
    <loc>$url</loc>
    <changefreq>${changefreqFor(url)}</changefreq>
    <priority>${priorityFor(url)}</priority>
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
        title: 'Properties in $city | HD Homes Limited',
        description: description,
        keywords: ['$city properties', '$city real estate', 'HD Homes $city'],
        structuredData: {
          '@context': 'https://schema.org',
          '@type': 'CollectionPage',
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

  SeoMetadata withRobots(String robotsDirective) => SeoMetadata(
        title: title,
        description: description,
        canonicalUrl: canonicalUrl,
        ogImageUrl: ogImageUrl,
        keywords: keywords,
        robots: robotsDirective,
        structuredData: structuredData,
      );
}
