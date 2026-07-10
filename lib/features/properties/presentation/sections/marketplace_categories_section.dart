import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 4 — Quick category cards + lifestyle discovery.
class MarketplaceCategoriesSection extends ConsumerWidget {
  const MarketplaceCategoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(marketplaceCmsProvider).categories;

    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'DISCOVER',
            title: 'Browse by category',
            subtitle: 'Or explore by lifestyle — family, luxury, investment, and more.',
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: context.isMobile ? 200 : 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.base),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _CategoryCard(
                  card: cat,
                  onTap: () => _applyCategory(ref, cat.filterKey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyCategory(WidgetRef ref, String key) {
    final filters = ref.read(marketplaceFiltersProvider);
    final next = switch (key) {
      'commercial' => filters.copyWith(category: PropertyCategory.commercial),
      'land' => filters.copyWith(category: PropertyCategory.land),
      'investment' => filters.copyWith(
          category: PropertyCategory.investment,
          purpose: PropertyPurpose.invest,
        ),
      'new' => filters.copyWith(sort: MarketplaceSort.newest),
      'hot' => filters.copyWith(sort: MarketplaceSort.popular),
      'luxury' => filters.copyWith(lifestyle: 'Luxury Living'),
      'family' => filters.copyWith(lifestyle: 'Family Living'),
      'affordable' => filters.copyWith(maxPrice: 35000000),
      _ => filters,
    };
    ref.read(marketplaceFiltersProvider.notifier).state = next;
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.card, required this.onTap});

  final MarketplaceCategoryCard card;
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 180,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.charcoal,
                AppColors.gold.withValues(alpha: _hovered ? 0.25 : 0.12),
              ],
            ),
            borderRadius: AppRadius.cardBorder,
            boxShadow: _hovered ? AppShadows.lg : AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon(widget.card.iconName), color: AppColors.gold),
              const Spacer(),
              Text(
                widget.card.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                    ),
              ),
              Text(
                '${widget.card.count} listings',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(String name) => switch (name) {
        'crown' => LucideIcons.crown,
        'building' => LucideIcons.building2,
        'map' => LucideIcons.map,
        'trending' => LucideIcons.trendingUp,
        'sparkles' => LucideIcons.sparkles,
        'flame' => LucideIcons.flame,
        _ => LucideIcons.home,
      };
}
