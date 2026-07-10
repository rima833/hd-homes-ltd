import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/search/data/models/search_intelligence.dart';
import 'package:hdhomesproject/features/search/data/providers/search_cms_provider.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';
import 'package:hdhomesproject/features/search/presentation/widgets/search_results_panel.dart';
import 'package:hdhomesproject/features/search/presentation/widgets/search_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Hub sections — quick filters, advanced, map, lifestyle, commute, AI search, results.
class SearchHubSections extends HookConsumerWidget {
  const SearchHubSections({
    super.key,
    this.advancedKey,
    this.resultsKey,
  });

  final GlobalKey? advancedKey;
  final GlobalKey? resultsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(searchHubCmsProvider);
    final filters = ref.watch(marketplaceFiltersProvider);
    final controller = useTextEditingController(text: filters.query);
    final showAdvanced = useState(false);
    final aiQuery = useState('');
    final aiResult = useState<AiSearchParseResult?>(null);
    final commuteMinutes = useState<int?>(null);

    void applyFilters(MarketplaceFilters next) {
      ref.read(marketplaceFiltersProvider.notifier).state = next;
      final count = ref.read(filteredPropertiesProvider).length;
      recordSearch(ref, query: next.query, resultsCount: count);
    }

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'QUICK FILTERS',
                title: 'One-click discovery',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: cms.quickFilters.map((q) {
                  return ActionChip(
                    avatar: Icon(SearchIcons.resolve(q.iconName), size: 16, color: AppColors.gold),
                    label: Text(q.label),
                    onPressed: () => applyFilters(_quickFilter(filters, q.label)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: advancedKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: AnimatedSectionTitle(
                      overline: 'ADVANCED',
                      title: 'Advanced search',
                      alignment: TextAlign.start,
                    ),
                  ),
                  IconButton(
                    icon: Icon(showAdvanced.value ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => showAdvanced.value = !showAdvanced.value,
                  ),
                ],
              ),
              if (showAdvanced.value) ...[
                const SizedBox(height: AppSpacing.lg),
                _AdvancedFilterPanel(filters: filters, cms: cms, onApply: applyFilters),
              ],
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LIFESTYLE',
                title: 'Lifestyle search',
                subtitle: 'Find homes that match how you want to live.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.lifestyleOptions.map((l) {
                  return SizedBox(
                    width: context.isMobile ? double.infinity : 260,
                    child: Card(
                      child: ListTile(
                        leading: Icon(SearchIcons.resolve(l.iconName), color: AppColors.gold),
                        title: Text(l.title),
                        subtitle: Text(l.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => applyFilters(
                          filters.copyWith(lifestyle: l.filterTag, clearLifestyle: false, sort: MarketplaceSort.bestMatch),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'COMMUTE',
                title: 'Commute search',
                subtitle: 'Find homes within your travel time — traffic integration in future.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: cms.commutePresets.map((c) {
                  final selected = commuteMinutes.value == c.minutes;
                  return FilterChip(
                    label: Text('${c.label}\n→ ${c.destination}'),
                    selected: selected,
                    onSelected: (_) => commuteMinutes.value = selected ? null : c.minutes,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'AI SEARCH',
                title: 'AI Smart Search',
                subtitle: 'Describe what you want in plain language.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'e.g. 4-bedroom duplex in Abuja under ₦180M with pool',
                  prefixIcon: Icon(LucideIcons.sparkles, color: AppColors.gold),
                ),
                maxLines: 2,
                onChanged: (v) => aiQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: cms.aiExampleQueries
                    .map((e) => ActionChip(label: Text(e, style: const TextStyle(fontSize: 11)), onPressed: () {
                          aiQuery.value = e;
                          final parsed = parseAiSearchQuery(e);
                          aiResult.value = parsed;
                          applyFilters(parsed.filters);
                        }))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.base),
              PrimaryButton(
                label: 'Run AI Search',
                icon: LucideIcons.sparkles,
                onPressed: () {
                  final parsed = parseAiSearchQuery(aiQuery.value.isEmpty ? controller.text : aiQuery.value);
                  aiResult.value = parsed;
                  controller.text = parsed.filters.query;
                  applyFilters(parsed.filters);
                },
              ),
              if (aiResult.value != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI extracted (${aiResult.value!.confidence}% confidence)',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        ...aiResult.value!.extractedCriteria.map((c) => Text('• $c')),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SectionWrapper(
          key: resultsKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'RESULTS',
                title: 'Search results',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SearchResultsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  MarketplaceFilters _quickFilter(MarketplaceFilters f, String label) {
    return switch (label) {
      'Houses' => f.copyWith(category: PropertyCategory.residential, type: 'House'),
      'Apartments' => f.copyWith(type: 'Apartment'),
      'Duplexes' => f.copyWith(type: 'Duplex'),
      'Terraces' => f.copyWith(type: 'Terrace'),
      'Land' => f.copyWith(category: PropertyCategory.land, clearType: true),
      'Commercial' => f.copyWith(category: PropertyCategory.commercial),
      'Luxury' => f.copyWith(lifestyle: 'Luxury Living'),
      'New Listings' => f.copyWith(sort: MarketplaceSort.newest),
      'Featured' => f.copyWith(sort: MarketplaceSort.popular),
      'Ready to Move' => f.copyWith(completionStatus: CompletionStatus.readyToMove),
      'Under Construction' => f.copyWith(completionStatus: CompletionStatus.underConstruction),
      'Investment' => f.copyWith(purpose: PropertyPurpose.invest, sort: MarketplaceSort.bestInvestment),
      _ => f,
    };
  }
}

class _AdvancedFilterPanel extends ConsumerWidget {
  const _AdvancedFilterPanel({
    required this.filters,
    required this.cms,
    required this.onApply,
  });

  final MarketplaceFilters filters;
  final SearchHubCms cms;
  final void Function(MarketplaceFilters) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: [
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                value: filters.minBedrooms,
                decoration: const InputDecoration(labelText: 'Bedrooms'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 2, child: Text('2+')),
                  DropdownMenuItem(value: 3, child: Text('3+')),
                  DropdownMenuItem(value: 4, child: Text('4+')),
                ],
                onChanged: (v) => onApply(filters.copyWith(minBedrooms: v)),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<MarketplaceSort>(
                isExpanded: true,
                value: filters.sort,
                decoration: const InputDecoration(labelText: 'Sort'),
                items: const [
                  DropdownMenuItem(value: MarketplaceSort.bestMatch, child: Text('Best match')),
                  DropdownMenuItem(value: MarketplaceSort.newest, child: Text('Newest')),
                  DropdownMenuItem(value: MarketplaceSort.bestInvestment, child: Text('Investment')),
                  DropdownMenuItem(value: MarketplaceSort.priceLowHigh, child: Text('Price ↑')),
                ],
                onChanged: (v) {
                  if (v != null) onApply(filters.copyWith(sort: v));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Text('Amenities', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.xs,
          children: cms.amenityFilters.map((a) {
            final selected = filters.amenities.contains(a);
            return FilterChip(
              label: Text(a),
              selected: selected,
              onSelected: (_) {
                final next = [...filters.amenities];
                selected ? next.remove(a) : next.add(a);
                onApply(filters.copyWith(amenities: next));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.base),
        Text('Investment', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.xs,
          children: cms.investmentFilters.map((tag) {
            return ActionChip(
              label: Text(tag),
              onPressed: () => onApply(
                filters.copyWith(purpose: PropertyPurpose.invest, sort: MarketplaceSort.bestInvestment),
              ),
            );
          }).toList(),
        ),
        if (filters.activeCount > 0)
          TextButton(
            onPressed: () => onApply(const MarketplaceFilters()),
            child: Text('Clear all filters (${filters.activeCount})'),
          ),
      ],
    );
  }
}
