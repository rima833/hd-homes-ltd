import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/services_catalog_provider.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_card.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_icons.dart';

/// Sections 2–4 — Categories, featured, and full service grid.
class ServicesCatalogSections extends ConsumerWidget {
  const ServicesCatalogSections({
    super.key,
    this.categoriesKey,
    this.gridKey,
    this.selectedCategory,
    this.onCategorySelected,
  });

  final GlobalKey? categoriesKey;
  final GlobalKey? gridKey;
  final ServiceCategoryId? selectedCategory;
  final ValueChanged<ServiceCategoryId?>? onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(servicesCmsProvider);
    final all = ref.watch(servicesCatalogProvider);
    final featured = ref.watch(featuredServicesProvider);
    final filtered = selectedCategory == null
        ? all
        : all.where((s) => s.categoryId == selectedCategory).toList();

    return Column(
      children: [
        KeyedSubtree(
          key: categoriesKey,
          child: SectionWrapper(
            child: PageContainer(
              child: Column(
                children: [
                  const AnimatedSectionTitle(
                    overline: 'CATEGORIES',
                    title: 'Service categories',
                    subtitle: 'Explore solutions by business area.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = context.isMobile ? 1 : context.isTablet ? 2 : 3;
                      final w = (constraints.maxWidth - (cols - 1) * AppSpacing.base) / cols;
                      return Wrap(
                        spacing: AppSpacing.base,
                        runSpacing: AppSpacing.base,
                        children: cms.categories.map((cat) {
                          final count = all.where((s) => s.categoryId == cat.id).length;
                          final selected = selectedCategory == cat.id;
                          return SizedBox(
                            width: w,
                            child: _CategoryCard(
                              category: cat,
                              serviceCount: count,
                              selected: selected,
                              onTap: () {
                                onCategorySelected?.call(selected ? null : cat.id);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (featured.isNotEmpty)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: PageContainer(
              child: Column(
                children: [
                  const AnimatedSectionTitle(
                    overline: 'FEATURED',
                    title: 'Featured services',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.base),
                      itemBuilder: (context, index) => SizedBox(
                        width: context.isMobile ? 280 : 320,
                        child: ServiceCard(service: featured[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        KeyedSubtree(
          key: gridKey,
          child: SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSectionTitle(
                    overline: 'ALL SERVICES',
                    title: selectedCategory == null
                        ? 'Complete service catalog'
                        : '${selectedCategory!.label} services',
                    alignment: TextAlign.start,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = context.gridColumns.clamp(1, 3);
                      final w = (constraints.maxWidth - (cols - 1) * AppSpacing.base) / cols;
                      return Wrap(
                        spacing: AppSpacing.base,
                        runSpacing: AppSpacing.base,
                        children: filtered
                            .map((s) => SizedBox(width: w, child: ServiceCard(service: s, compact: true)))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.serviceCount,
    required this.selected,
    required this.onTap,
  });

  final ServiceCategory category;
  final int serviceCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        child: Material(
          color: widget.selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ServiceIcons.resolve(widget.category.iconName), color: AppColors.gold, size: 28),
                  const SizedBox(height: AppSpacing.base),
                  Text(widget.category.id.label, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(widget.category.description, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${widget.serviceCount} services',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.selected ? 'Showing →' : 'Explore →',
                    style: const TextStyle(color: AppColors.gold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
