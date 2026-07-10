import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';

void main() {
  group('SeoResolver', () {
    test('resolves home SEO with canonical URL', () {
      final seo = SeoResolver.resolvePath('/');
      expect(seo, isNotNull);
      expect(seo!.title, SeoMetadata.home.title);
      expect(seo.canonicalUrl, 'https://hdhomes.ng/');
    });

    test('resolves static public pages', () {
      expect(SeoResolver.resolvePath(RoutePaths.about)!.title, SeoMetadata.about.title);
      expect(SeoResolver.resolvePath(RoutePaths.properties)!.title, SeoMetadata.marketplace.title);
      expect(SeoResolver.resolvePath(RoutePaths.estates)!.title, SeoMetadata.estates.title);
      expect(SeoResolver.resolvePath(RoutePaths.services)!.title, SeoMetadata.servicesHub.title);
      expect(SeoResolver.resolvePath(RoutePaths.blog)!.title, SeoMetadata.blogHub.title);
      expect(SeoResolver.resolvePath(RoutePaths.contact)!.title, SeoMetadata.contactHub.title);
      expect(SeoResolver.resolvePath(RoutePaths.search)!.title, SeoMetadata.searchHub.title);
    });

    test('returns null for dynamic detail routes', () {
      expect(SeoResolver.resolvePath('/properties/h001'), isNull);
      expect(SeoResolver.resolvePath('/estates/horizon-gardens'), isNull);
      expect(SeoResolver.resolvePath('/services/property-sales'), isNull);
      expect(SeoResolver.resolvePath('/blog/first-time-buyers-guide-nigeria-2026'), isNull);
    });

    test('withCanonical preserves metadata fields', () {
      final enriched = SeoMetadata.servicesHub.withCanonical('https://hdhomes.ng/services');
      expect(enriched.title, SeoMetadata.servicesHub.title);
      expect(enriched.canonicalUrl, 'https://hdhomes.ng/services');
      expect(enriched.structuredData, SeoMetadata.servicesHub.structuredData);
    });
  });
}
