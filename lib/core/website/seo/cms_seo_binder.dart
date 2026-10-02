import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

/// Applies static [SeoResolver] metadata, then overlays CMS `seo_metadata`
/// rows from Admin → Website → SEO when present for the current path.
/// Falls back to Platform Settings SEO defaults (`app_settings.seo`).
class CmsSeoBinder extends ConsumerWidget {
  const CmsSeoBinder({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staticSeo = SeoResolver.resolvePath(path);
    final cmsAsync = ref.watch(publishedSeoByPathProvider(path));
    final cms = cmsAsync.valueOrNull;
    final platform = ref.watch(publishedPlatformSettingsProvider).valueOrNull;

    final platformTitle = platform?.seoTitle.trim() ?? '';
    final platformDescription = platform?.seoDescription.trim() ?? '';
    final platformOg = platform?.ogImageUrl.trim() ?? '';
    final platformSiteUrl = platform?.siteUrl.trim() ?? '';

    String pickTitle(String? preferred, String? fallback) {
      final a = preferred?.trim();
      if (a != null && a.isNotEmpty) return a;
      final b = fallback?.trim();
      if (b != null && b.isNotEmpty) return b;
      if (platformTitle.isNotEmpty) return platformTitle;
      return 'HD Homes Limited';
    }

    String pickDescription(String? preferred, String? fallback) {
      final a = preferred?.trim();
      if (a != null && a.isNotEmpty) return a;
      final b = fallback?.trim();
      if (b != null && b.isNotEmpty) return b;
      return platformDescription;
    }

    String? pickOg(String? preferred, String? fallback) {
      final a = preferred?.trim();
      if (a != null && a.isNotEmpty) return a;
      final b = fallback?.trim();
      if (b != null && b.isNotEmpty) return b;
      return platformOg.isNotEmpty ? platformOg : null;
    }

    String canonicalFor(String? preferred, String? fallback) {
      final a = preferred?.trim();
      if (a != null && a.isNotEmpty) return a;
      final b = fallback?.trim();
      if (b != null && b.isNotEmpty) return b;
      if (platformSiteUrl.isNotEmpty) {
        final base = platformSiteUrl.endsWith('/')
            ? platformSiteUrl.substring(0, platformSiteUrl.length - 1)
            : platformSiteUrl;
        final normalized = path.startsWith('/') ? path : '/$path';
        return '$base$normalized';
      }
      return SeoConfig.canonicalFor(path);
    }

    SeoMetadata? merged = staticSeo;
    if (cms != null) {
      merged = SeoMetadata(
        title: pickTitle(cms.metaTitle, staticSeo?.title),
        description: pickDescription(cms.metaDescription, staticSeo?.description),
        canonicalUrl: canonicalFor(cms.canonicalUrl, staticSeo?.canonicalUrl),
        ogImageUrl: pickOg(cms.ogImageUrl, staticSeo?.ogImageUrl),
        keywords: staticSeo?.keywords ?? const [],
        robots: staticSeo?.robots ?? 'index, follow',
        structuredData: staticSeo?.structuredData,
      );
    } else if (staticSeo != null) {
      merged = SeoMetadata(
        title: pickTitle(staticSeo.title, null),
        description: pickDescription(staticSeo.description, null),
        canonicalUrl: canonicalFor(staticSeo.canonicalUrl, null),
        ogImageUrl: pickOg(staticSeo.ogImageUrl, null),
        keywords: staticSeo.keywords,
        robots: staticSeo.robots,
        structuredData: staticSeo.structuredData,
      );
    } else if (platformTitle.isNotEmpty || platformDescription.isNotEmpty) {
      // Dynamic routes without static SEO still get platform defaults.
      merged = SeoMetadata(
        title: platformTitle.isNotEmpty ? platformTitle : 'HD Homes Limited',
        description: platformDescription,
        canonicalUrl: canonicalFor(null, null),
        ogImageUrl: platformOg.isNotEmpty ? platformOg : null,
        robots: 'index, follow',
      );
    }

    if (merged == null) return child;
    return SeoBinder(metadata: merged, child: child);
  }
}

/// Convenience for GoRouter shell builders.
Widget bindRouteSeo(GoRouterState state, Widget page) {
  return CmsSeoBinder(path: state.uri.path, child: page);
}
