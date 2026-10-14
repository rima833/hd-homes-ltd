import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/seo/seo_engine.dart';
import 'package:hdhomesproject/core/website/seo/public_seo_policy.dart';

void main() {
  test('private portal and auth paths are noindex', () {
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.dashboard), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex('${RoutePaths.client}/payments'), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.investor), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.login), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.register), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.trust), isTrue);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.properties), isFalse);
    expect(PublicSeoPolicy.shouldNoIndex(RoutePaths.about), isFalse);
  });

  test('robots.txt blocks private areas and references sitemap', () {
    final robots = SeoEngine.robotsTxt();
    expect(robots, contains('Disallow: /dashboard'));
    expect(robots, contains('Disallow: /client'));
    expect(robots, contains('Disallow: /investor'));
    expect(robots, contains('Sitemap: https://hdhomesltd.com/sitemap.xml'));
  });

  test('sitemap omits trust and includes core hubs', () {
    final xml = SeoEngine.sitemapXml();
    expect(xml, isNot(contains('/trust')));
    expect(xml, contains('/properties'));
    expect(xml, contains('/estates'));
    expect(xml, contains('/blog'));
  });
}
