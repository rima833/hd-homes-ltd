import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/features/construction/presentation/widgets/construction_updates_hub.dart';

/// Dedicated public page for construction updates (under Properties).
class ConstructionUpdatesPage extends ConsumerWidget {
  const ConstructionUpdatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeoBinder(
      metadata: SeoMetadata.constructionHub.withCanonical(
        SeoConfig.canonicalFor(RoutePaths.construction),
      ),
      child: const SingleChildScrollView(
        child: Column(
          children: [
            PageContainer(
              child: WebsiteBreadcrumbs(
                items: [
                  BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                  BreadcrumbItem(
                    label: 'Properties',
                    path: RoutePaths.properties,
                  ),
                  BreadcrumbItem(label: 'Construction Updates'),
                ],
              ),
            ),
            ConstructionUpdatesHub(),
          ],
        ),
      ),
    );
  }
}
