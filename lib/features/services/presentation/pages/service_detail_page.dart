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
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/service_detail_provider.dart';
import 'package:hdhomesproject/features/services/presentation/sections/service_detail_sections.dart';

/// Individual service landing page — Volume 2 Part 8.
class ServiceDetailPage extends ConsumerStatefulWidget {
  const ServiceDetailPage({super.key, required this.serviceSlug});

  final String serviceSlug;

  @override
  ConsumerState<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends ConsumerState<ServiceDetailPage> {
  @override
  void initState() {
    super.initState();
    // Jump PublicShell scroll to top when opening a detail route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scrollable = Scrollable.maybeOf(context);
      scrollable?.position.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(serviceDetailProvider(widget.serviceSlug));

    if (detail == null) {
      return PageContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            children: [
              const Icon(Icons.handyman_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Service not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'This service may have been archived or is not yet published.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(RoutePaths.services),
                child: const Text('Browse services'),
              ),
            ],
          ),
        ),
      );
    }

    final categoryLabel = detail.summary.categoryId.label;

    final seo = SeoMetadata.serviceDetail(
      detail.summary.name,
      detail.summary.shortDescription,
    ).withCanonical(
      SeoConfig.canonicalFor('/services/${detail.summary.slug}'),
    );

    return SeoBinder(
      metadata: seo,
      child: Column(
        children: [
          PageContainer(
            child: WebsiteBreadcrumbs(
              items: [
                const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
                const BreadcrumbItem(
                  label: 'Services',
                  path: RoutePaths.services,
                ),
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
