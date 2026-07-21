import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';

/// Resolves static SEO metadata from the current route.
///
/// Dynamic pages (property, estate, service detail) return `null` and set SEO
/// via [SeoBinder] once CMS content is loaded.
abstract final class SeoResolver {
  static SeoMetadata? resolve(GoRouterState state) => resolvePath(state.uri.path);

  static SeoMetadata? resolvePath(String path) {
    final SeoMetadata? base = switch (path) {
      '/' || '' => SeoMetadata.home,
      RoutePaths.about => SeoMetadata.about,
      RoutePaths.properties => SeoMetadata.marketplace,
      RoutePaths.estates => SeoMetadata.estates,
      RoutePaths.services => SeoMetadata.servicesHub,
      RoutePaths.blog => SeoMetadata.blogHub,
      RoutePaths.contact => SeoMetadata.contactHub,
      RoutePaths.bookInspection => SeoMetadata.contactHub,
      RoutePaths.search => SeoMetadata.searchHub,
      RoutePaths.gallery => SeoMetadata.mediaHub,
      RoutePaths.trust => SeoMetadata.trustHub,
      RoutePaths.investment => SeoMetadata.investmentHub,
      RoutePaths.careers => SeoMetadata.careersHub,
      RoutePaths.register => SeoMetadata.register,
      RoutePaths.login => SeoMetadata.login,
      RoutePaths.verifyEmail => SeoMetadata.verifyEmail,
      RoutePaths.welcome => SeoMetadata.welcome,
      RoutePaths.forgotPassword => SeoMetadata.forgotPassword,
      RoutePaths.resetPassword => SeoMetadata.resetPassword,
      _ when _isDynamicDetail(path) => null,
      _ => null,
    };

    if (base == null) return null;
    return base.withCanonical(SeoConfig.canonicalFor(path));
  }

  static bool _isDynamicDetail(String path) {
    if (path.startsWith('${RoutePaths.properties}/') && path != RoutePaths.properties) {
      return true;
    }
    if (path.startsWith('${RoutePaths.estates}/') && path != RoutePaths.estates) {
      return true;
    }
    if (path.startsWith('${RoutePaths.services}/') && path != RoutePaths.services) {
      return true;
    }
    if (path.startsWith('${RoutePaths.blog}/') && path != RoutePaths.blog) {
      return true;
    }
    if (path.startsWith('${RoutePaths.gallery}/') && path != RoutePaths.gallery) {
      return true;
    }
    return false;
  }
}

extension SeoMetadataCanonical on SeoMetadata {
  SeoMetadata withCanonical(String canonicalUrl) => SeoMetadata(
        title: title,
        description: description,
        canonicalUrl: canonicalUrl,
        ogImageUrl: ogImageUrl,
        keywords: keywords,
        robots: robots,
        structuredData: structuredData,
      );
}
