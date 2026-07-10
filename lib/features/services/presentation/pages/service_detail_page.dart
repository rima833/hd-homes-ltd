import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/service_detail_provider.dart';
import 'package:hdhomesproject/features/services/presentation/sections/service_detail_sections.dart';

/// Individual service landing page — Volume 2 Part 8.
class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceSlug});

  final String serviceSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(serviceSlug));

    if (detail == null) {
      return EmptyState(
        title: 'Service not found',
        message: 'This service may have been archived or is not yet published.',
        icon: Icons.handyman_outlined,
        actionLabel: 'Browse services',
        onAction: () => context.go(RoutePaths.services),
      );
    }

    final categoryLabel = detail.summary.categoryId.label;

    final seo = SeoMetadata.serviceDetail(
      detail.summary.name,
      detail.summary.shortDescription,
    ).withCanonical(SeoConfig.canonicalFor('/services/${detail.summary.slug}'));

    return SeoBinder(
      metadata: seo,
      child: Column(
        children: [
          PageContainer(
            child: WebsiteBreadcrumbs(
              items: [
                const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                const BreadcrumbItem(label: 'Services', path: RoutePaths.services),
                BreadcrumbItem(label: categoryLabel),
                BreadcrumbItem(label: detail.summary.name),
              ],
            ),
          ),
          ServiceDetailSections(detail: detail),
        ],
      ),
    );
  }
}
