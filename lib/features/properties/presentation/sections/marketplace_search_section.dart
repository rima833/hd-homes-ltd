import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 2–3 — AI smart search + advanced filters.
class MarketplaceSearchSection extends HookConsumerWidget {
  const MarketplaceSearchSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(marketplaceFiltersProvider);
    final cms = ref.watch(marketplaceCmsProvider);
    final controller = useTextEditingController(text: filters.query);
    final showAdvanced = useState(false);

    return Transform.translate(
      offset: const Offset(0, -32),
      child: SectionWrapper(
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
        animate: false,
        child: Material(
          elevation: 12,
          borderRadius: AppRadius.cardBorder,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Search by name, estate, location, code…',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'AI Recommend',
                          icon: const Icon(LucideIcons.sparkles, color: AppColors.gold),
                          onPressed: () {
                            ref.read(marketplaceFiltersProvider.notifier).state =
                                filters.copyWith(sort: MarketplaceSort.bestMatch);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            showAdvanced.value
                                ? Icons.expand_less_rounded
                                : Icons.tune_rounded,
                          ),
                          onPressed: () => showAdvanced.value = !showAdvanced.value,
                        ),
                      ],
                    ),
                  ),
                  onChanged: (v) {
                    ref.read(marketplaceFiltersProvider.notifier).state =
                        filters.copyWith(query: v);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: cms.searchSuggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s),
                          onPressed: () {
                            controller.text = s;
                            ref.read(marketplaceFiltersProvider.notifier).state =
                                filters.copyWith(query: s);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.base),
                _QuickFilters(ref: ref, filters: filters),
                if (showAdvanced.value) ...[
                  const Divider(height: AppSpacing.xl),
                  _AdvancedFilters(ref: ref, filters: filters),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.ref, required this.filters});

  final WidgetRef ref;
  final MarketplaceFilters filters;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Buy', filters.purpose == PropertyPurpose.buy, () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  purpose: PropertyPurpose.buy,
                  clearPurpose: filters.purpose == PropertyPurpose.buy,
                );
          }),
          _chip('Invest', filters.purpose == PropertyPurpose.invest, () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  purpose: PropertyPurpose.invest,
                  clearPurpose: filters.purpose == PropertyPurpose.invest,
                );
          }),
          _chip('Lagos', filters.state == 'Lagos', () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  state: 'Lagos',
                  clearState: filters.state == 'Lagos',
                );
          }),
          _chip('Abuja', filters.state == 'FCT', () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  state: 'FCT',
                  clearState: filters.state == 'FCT',
                );
          }),
          _chip('Ready', filters.completionStatus == CompletionStatus.readyToMove, () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  completionStatus: CompletionStatus.readyToMove,
                  clearCompletion: filters.completionStatus == CompletionStatus.readyToMove,
                );
          }),
          _chip('Off-plan', filters.completionStatus == CompletionStatus.offPlan, () {
            ref.read(marketplaceFiltersProvider.notifier).state = filters.copyWith(
                  completionStatus: CompletionStatus.offPlan,
                  clearCompletion: filters.completionStatus == CompletionStatus.offPlan,
                );
          }),
          if (filters.activeCount > 0)
            TextButton(
              onPressed: () {
                ref.read(marketplaceFiltersProvider.notifier).state =
                    const MarketplaceFilters();
              },
              child: Text('Clear (${filters.activeCount})'),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
      ),
    );
  }
}

class _AdvancedFilters extends StatelessWidget {
  const _AdvancedFilters({required this.ref, required this.filters});

  final WidgetRef ref;
  final MarketplaceFilters filters;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int?>(
                value: filters.minBedrooms,
                decoration: const InputDecoration(labelText: 'Bedrooms'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 1, child: Text('1+')),
                  DropdownMenuItem(value: 2, child: Text('2+')),
                  DropdownMenuItem(value: 3, child: Text('3+')),
                  DropdownMenuItem(value: 4, child: Text('4+')),
                ],
                onChanged: (v) {
                  ref.read(marketplaceFiltersProvider.notifier).state =
                      filters.copyWith(minBedrooms: v);
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<MarketplaceSort>(
                value: filters.sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(value: MarketplaceSort.newest, child: Text('Newest')),
                  DropdownMenuItem(
                    value: MarketplaceSort.priceLowHigh,
                    child: Text('Price: Low–High'),
                  ),
                  DropdownMenuItem(
                    value: MarketplaceSort.priceHighLow,
                    child: Text('Price: High–Low'),
                  ),
                  DropdownMenuItem(value: MarketplaceSort.popular, child: Text('Popular')),
                  DropdownMenuItem(
                    value: MarketplaceSort.bestInvestment,
                    child: Text('Best Investment'),
                  ),
                  DropdownMenuItem(
                    value: MarketplaceSort.bestMatch,
                    child: Text('Best Match'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref.read(marketplaceFiltersProvider.notifier).state =
                        filters.copyWith(sort: v);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            'Swimming Pool',
            'Gym',
            'Security',
            'Smart Home',
            'Parking',
          ].map((a) {
            final selected = filters.amenities.contains(a);
            return FilterChip(
              label: Text(a),
              selected: selected,
              onSelected: (_) {
                final next = [...filters.amenities];
                if (selected) {
                  next.remove(a);
                } else {
                  next.add(a);
                }
                ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(amenities: next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            'Family Living',
            'Luxury Living',
            'Investment Focus',
            'Waterfront Living',
            'Eco-Friendly Living',
          ].map((l) {
            final selected = filters.lifestyle == l;
            return FilterChip(
              label: Text(l),
              selected: selected,
              onSelected: (_) {
                ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(
                  lifestyle: selected ? null : l,
                  clearLifestyle: selected,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
