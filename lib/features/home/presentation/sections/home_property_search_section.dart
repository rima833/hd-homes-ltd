import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/components/web_safe_backdrop.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';
import 'package:hdhomesproject/features/properties/data/providers/popular_searches_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum PropertySearchIntent { buy, invest, rent, land, commercial }

const _budgetOptions = <String>[
  'Under ₦30M',
  '₦30M – ₦60M',
  '₦60M – ₦100M',
  '₦100M+',
];

const _typeChoices = <String>[
  'Duplex',
  'Terrace',
  'Apartment',
  'Bungalow',
  'Commercial',
];

/// Section 5 — Glassmorphism property search (dark premium panel).
/// Backed by live published listings from Supabase (with realtime refresh).
class HomePropertySearchSection extends HookConsumerWidget {
  const HomePropertySearchSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep catalog fresh when admin publishes / edits properties.
    ref.watch(publishedPropertiesRealtimeProvider);
    final catalogAsync = ref.watch(publishedPropertiesCatalogProvider);
    final listings = ref.watch(marketplaceListingsProvider);
    final intent = useState(PropertySearchIntent.buy);
    final location = useState<String?>(null);
    final budget = useState<String?>(null);
    final propertyType = useState<String?>(null);
    final bedrooms = useState<String?>(null);
    final locationQuery = useTextEditingController();

    useEffect(() {
      void sync() {
        final text = locationQuery.text.trim();
        if (text.isEmpty) {
          location.value = null;
        } else {
          location.value = text;
        }
      }

      locationQuery.addListener(sync);
      return () => locationQuery.removeListener(sync);
    }, [locationQuery]);

    final locationOptions = _locationOptions(listings);
    final typeOptions = _typeOptions(listings);
    final bedroomOptions = _bedroomOptions(listings);
    final budgetOptions = _budgetOptions;
    final popularAsync = ref.watch(popularPropertySearchesProvider);
    final popular = popularAsync.valueOrNull
            ?.map((e) => e.term)
            .where((t) => t.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    final draftFilters = _buildFilters(
      intent: intent.value,
      location: location.value,
      budget: budget.value,
      propertyType: propertyType.value,
      bedrooms: bedrooms.value,
    );
    final matchCount = filterProperties(listings, draftFilters).length;
    final isLoading = catalogAsync.isLoading && listings.isEmpty;
    final countLabel = isLoading
        ? 'Loading properties…'
        : matchCount == 0
            ? (listings.isEmpty
                ? 'No published properties yet'
                : 'No matching properties')
            : matchCount == 1
                ? '1 Property Available'
                : matchCount >= 100
                    ? '$matchCount+ Properties Available'
                    : '$matchCount Properties Available';

    void applyAndGo({MarketplaceFilters? overrides}) {
      final next = overrides ?? draftFilters;
      ref.read(marketplaceFiltersProvider.notifier).state = next;
      final term = popularSearchTermFromFilters(
        query: next.query,
        location: location.value,
        city: next.city,
        estate: next.estate,
        state: next.state,
      );
      if (term != null) {
        unawaited(recordPopularPropertySearch(ref, term: term));
      }
      context.go(RoutePaths.properties);
    }

    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchHeader(propertyCountLabel: countLabel),
          const SizedBox(height: AppSpacing.lg),
          _IntentPills(
            selected: intent.value,
            onSelected: (value) => intent.value = value,
            counts: {
              for (final i in PropertySearchIntent.values)
                i: filterProperties(
                  listings,
                  _buildFilters(
                    intent: i,
                    location: location.value,
                    budget: budget.value,
                    propertyType: propertyType.value,
                    bedrooms: bedrooms.value,
                  ),
                ).length,
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _GlassSearchPanel(
            locationController: locationQuery,
            locationOptions: locationOptions,
            budget: budget.value,
            propertyType: propertyType.value,
            bedrooms: bedrooms.value,
            budgetOptions: budgetOptions,
            typeOptions: typeOptions,
            bedroomOptions: bedroomOptions,
            onBudgetChanged: (v) => budget.value = v,
            onPropertyTypeChanged: (v) => propertyType.value = v,
            onBedroomsChanged: (v) => bedrooms.value = v,
            onLocationSelected: (v) {
              location.value = v;
              locationQuery.text = v ?? '';
            },
            onSearch: applyAndGo,
            onRecommended: () => applyAndGo(
              overrides: draftFilters.copyWith(sort: MarketplaceSort.bestMatch),
            ),
            onAdvanced: () => applyAndGo(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PopularSearches(
            tags: popular,
            onTagTap: (tag) {
              location.value = tag;
              locationQuery.text = tag;
              applyAndGo(
                overrides: _buildFilters(
                  intent: intent.value,
                  location: tag,
                  budget: budget.value,
                  propertyType: propertyType.value,
                  bedrooms: bedrooms.value,
                ),
              );
            },
            onViewAll: () {
              ref.read(marketplaceFiltersProvider.notifier).state =
                  const MarketplaceFilters();
              context.go(RoutePaths.properties);
            },
          ),
        ],
      ),
    );
  }

  static List<String> _locationOptions(List<MarketplaceProperty> listings) {
    final set = <String>{};
    for (final p in listings) {
      if (p.city.trim().isNotEmpty) set.add(p.city.trim());
      if (p.state.trim().isNotEmpty) set.add(p.state.trim());
      if (p.estate.trim().isNotEmpty) set.add(p.estate.trim());
      if (p.location.trim().isNotEmpty) {
        for (final part in p.location.split(',')) {
          final t = part.trim();
          if (t.isNotEmpty) set.add(t);
        }
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> _typeOptions(List<MarketplaceProperty> listings) {
    final extras = <String>[];
    for (final p in listings) {
      final t = p.type.trim();
      if (t.isEmpty || t.toLowerCase() == 'property') continue;
      final known = _typeChoices.any((choice) => choice.toLowerCase() == t.toLowerCase());
      if (!known && !extras.any((choice) => choice.toLowerCase() == t.toLowerCase())) {
        extras.add(t);
      }
    }
    extras.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [..._typeChoices, ...extras];
  }

  static List<String> _bedroomOptions(List<MarketplaceProperty> listings) {
    final beds = listings.map((p) => p.bedrooms).where((b) => b > 0);
    var maxBed = 5;
    for (final bedsCount in beds) {
      if (bedsCount > maxBed) maxBed = bedsCount.clamp(1, 8);
    }
    return [for (var i = 1; i <= maxBed; i++) '$i+'];
  }

  static MarketplaceFilters _buildFilters({
    required PropertySearchIntent intent,
    String? location,
    String? budget,
    String? propertyType,
    String? bedrooms,
  }) {
    final loc = location?.trim() ?? '';
    int? minPrice;
    int? maxPrice;
    switch (budget) {
      case 'Under ₦30M':
        maxPrice = 30000000;
      case 'Under ₦50M':
        maxPrice = 50000000;
      case '₦30M – ₦60M':
        minPrice = 30000000;
        maxPrice = 60000000;
      case '₦50M – ₦100M':
        minPrice = 50000000;
        maxPrice = 100000000;
      case '₦60M – ₦100M':
        minPrice = 60000000;
        maxPrice = 100000000;
      case '₦100M – ₦200M':
        minPrice = 100000000;
        maxPrice = 200000000;
      case '₦100M+':
        minPrice = 100000000;
      case '₦200M – ₦500M':
        minPrice = 200000000;
        maxPrice = 500000000;
      case '₦500M+':
        minPrice = 500000000;
    }

    int? minBeds;
    if (bedrooms != null) {
      minBeds = int.tryParse(bedrooms.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    PropertyCategory? category;
    PropertyPurpose? purpose;
    switch (intent) {
      case PropertySearchIntent.buy:
        // Homes for purchase — exclude explicit rentals.
        purpose = PropertyPurpose.buy;
      case PropertySearchIntent.invest:
        purpose = PropertyPurpose.invest;
      case PropertySearchIntent.rent:
        purpose = PropertyPurpose.rent;
      case PropertySearchIntent.land:
        category = PropertyCategory.land;
      case PropertySearchIntent.commercial:
        category = PropertyCategory.commercial;
    }

    return MarketplaceFilters(
      query: loc,
      type: propertyType,
      minBedrooms: minBeds,
      minPrice: minPrice,
      maxPrice: maxPrice,
      category: category,
      purpose: purpose,
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.propertyCountLabel});

  final String propertyCountLabel;

  @override
  Widget build(BuildContext context) {
    final isNarrow = context.isMobile;

    final title = Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
        children: const [
          TextSpan(text: 'Find Your '),
          TextSpan(
            text: 'Dream Property',
            style: TextStyle(color: AppColors.gold),
          ),
        ],
      ),
    );

    final subtitle = Text(
      'Explore the finest properties that match your lifestyle and investment goals.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.home, size: 14, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Text(
            propertyCountLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.sm),
          subtitle,
          const SizedBox(height: AppSpacing.md),
          badge,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppSpacing.sm),
              subtitle,
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        badge,
      ],
    );
  }
}

class _IntentPills extends StatelessWidget {
  const _IntentPills({
    required this.selected,
    required this.onSelected,
    this.counts = const {},
  });

  final PropertySearchIntent selected;
  final ValueChanged<PropertySearchIntent> onSelected;
  final Map<PropertySearchIntent, int> counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: PropertySearchIntent.values.map((item) {
        final isSelected = selected == item;
        final count = counts[item];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(item),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.goldGradient : null,
                color: isSelected
                    ? null
                    : AppColors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.white.withValues(alpha: 0.18),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? LucideIcons.check : _intentIcon(item),
                    size: 15,
                    color: isSelected ? AppColors.deepBlack : AppColors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    count == null
                        ? _intentLabel(item)
                        : '${_intentLabel(item)} ($count)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color:
                              isSelected ? AppColors.deepBlack : AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _intentLabel(PropertySearchIntent intent) => switch (intent) {
        PropertySearchIntent.buy => 'Buy',
        PropertySearchIntent.invest => 'Invest',
        PropertySearchIntent.rent => 'Rent',
        PropertySearchIntent.land => 'Land',
        PropertySearchIntent.commercial => 'Commercial',
      };

  IconData _intentIcon(PropertySearchIntent intent) => switch (intent) {
        PropertySearchIntent.buy => LucideIcons.shoppingBag,
        PropertySearchIntent.invest => LucideIcons.trendingUp,
        PropertySearchIntent.rent => LucideIcons.key,
        PropertySearchIntent.land => LucideIcons.map,
        PropertySearchIntent.commercial => LucideIcons.building2,
      };
}

class _GlassSearchPanel extends StatelessWidget {
  const _GlassSearchPanel({
    required this.locationController,
    required this.locationOptions,
    required this.budget,
    required this.propertyType,
    required this.bedrooms,
    required this.budgetOptions,
    required this.typeOptions,
    required this.bedroomOptions,
    required this.onBudgetChanged,
    required this.onPropertyTypeChanged,
    required this.onBedroomsChanged,
    required this.onLocationSelected,
    required this.onSearch,
    required this.onRecommended,
    required this.onAdvanced,
  });

  final TextEditingController locationController;
  final List<String> locationOptions;
  final String? budget;
  final String? propertyType;
  final String? bedrooms;
  final List<String> budgetOptions;
  final List<String> typeOptions;
  final List<String> bedroomOptions;
  final ValueChanged<String?> onBudgetChanged;
  final ValueChanged<String?> onPropertyTypeChanged;
  final ValueChanged<String?> onBedroomsChanged;
  final ValueChanged<String?> onLocationSelected;
  final VoidCallback onSearch;
  final VoidCallback onRecommended;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: webSafeBackdropBlur(
        sigma: 18,
        child: Container(
          padding: EdgeInsets.all(context.isMobile ? AppSpacing.lg : AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlack.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 720;
                  final fields = [
                    _LocationField(
                      controller: locationController,
                      options: locationOptions,
                      onSelected: onLocationSelected,
                    ),
                    _SearchDropdownField(
                      label: 'Budget Range',
                      hint: 'Select your budget range',
                      icon: LucideIcons.wallet,
                      value: budget,
                      items: budgetOptions,
                      onChanged: onBudgetChanged,
                    ),
                    _SearchDropdownField(
                      label: 'Property Type',
                      hint: 'Select property type',
                      icon: LucideIcons.home,
                      value: propertyType,
                      items: typeOptions,
                      onChanged: onPropertyTypeChanged,
                    ),
                    _SearchDropdownField(
                      label: 'Bedrooms',
                      hint: 'Select number of bedrooms',
                      icon: LucideIcons.bed,
                      value: bedrooms,
                      items: bedroomOptions,
                      onChanged: onBedroomsChanged,
                    ),
                  ];

                  if (stacked) {
                    return Column(
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.base),
                          fields[i],
                        ],
                      ],
                    );
                  }

                  final gap = AppSpacing.base;
                  final width = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: fields
                        .map((f) => SizedBox(width: width, child: f))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SearchActions(
                onAdvanced: onAdvanced,
                onSearch: onSearch,
                onRecommended: onRecommended,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchActions extends StatelessWidget {
  const _SearchActions({
    required this.onAdvanced,
    required this.onSearch,
    required this.onRecommended,
  });

  final VoidCallback onAdvanced;
  final VoidCallback onSearch;
  final VoidCallback onRecommended;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isMobile;

    final advanced = _GhostActionButton(
      label: 'Advanced Filters',
      icon: LucideIcons.slidersHorizontal,
      showChevron: true,
      onPressed: onAdvanced,
    );

    final search = _PrimarySearchButton(onPressed: onSearch);

    final recommended = _GhostActionButton(
      label: 'Recommended For You',
      icon: LucideIcons.sparkles,
      onPressed: onRecommended,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: advanced),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: recommended),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Flexible(child: advanced),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: search),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: recommended),
      ],
    );
  }
}

class _PrimarySearchButton extends StatelessWidget {
  const _PrimarySearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md + 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 18,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Search Property',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
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

class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.showChevron = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularSearches extends StatelessWidget {
  const _PopularSearches({
    required this.tags,
    required this.onTagTap,
    required this.onViewAll,
  });

  final List<String> tags;
  final ValueChanged<String> onTagTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flame, size: 14, color: AppColors.gold),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Popular Searches',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        ...tags.map(
          (tag) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTagTap(tag),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 12,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      tag,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View All'),
              SizedBox(width: 4),
              Icon(LucideIcons.arrowRight, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationField extends StatefulWidget {
  const _LocationField({
    required this.controller,
    required this.options,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search by Location',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) return widget.options.take(8);
            return widget.options
                .where((o) => o.toLowerCase().contains(q))
                .take(8);
          },
          onSelected: (value) {
            widget.controller.text = value;
            widget.onSelected(value);
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textController,
              focusNode: focusNode,
              style: const TextStyle(color: AppColors.white),
              cursorColor: AppColors.gold,
              onChanged: (v) =>
                  widget.onSelected(v.trim().isEmpty ? null : v.trim()),
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: InputDecoration(
                hintText: widget.options.isEmpty
                    ? 'Enter city, estate or area'
                    : 'e.g. ${widget.options.first}',
                hintStyle: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.35),
                ),
                prefixIcon: const Icon(
                  LucideIcons.mapPin,
                  size: 18,
                  color: AppColors.gold,
                ),
                suffixIcon: widget.options.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Choose location',
                        color: AppColors.darkElevated,
                        icon: Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: AppColors.white.withValues(alpha: 0.45),
                        ),
                        onSelected: (value) {
                          textController.text = value;
                          widget.onSelected(value);
                        },
                        itemBuilder: (context) => [
                          for (final option in widget.options.take(12))
                            PopupMenuItem(
                              value: option,
                              child: Text(
                                option,
                                style: const TextStyle(color: AppColors.white),
                              ),
                            ),
                        ],
                      ),
                filled: true,
                fillColor: AppColors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, optionsIterable) {
            final opts = optionsIterable.toList();
            if (opts.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: AppColors.darkElevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 220, maxWidth: 420),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: opts.length,
                    itemBuilder: (context, index) {
                      final option = opts[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          LucideIcons.mapPin,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        title: Text(
                          option,
                          style: const TextStyle(color: AppColors.white),
                        ),
                        onTap: () => onSelectedOption(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SearchDropdownField extends StatelessWidget {
  const _SearchDropdownField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = value != null && items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('${label}_${effectiveValue ?? 'empty'}'),
          initialValue: effectiveValue,
          icon: Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.white.withValues(alpha: 0.45),
          ),
          dropdownColor: AppColors.darkElevated,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.white.withValues(alpha: 0.35),
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.gold),
            filled: true,
            fillColor: AppColors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: AppColors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
